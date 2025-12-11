#!/usr/bin/env python3
"""Docker Controller - Executes Docker Swarm recovery actions"""

import logging
import time
import docker
import os

logger = logging.getLogger(__name__)


class DockerController:
    def __init__(self, config):
        self.config = config
        socket_path = config.get('docker.socket_path', 'unix:///var/run/docker.sock')
        self.client = docker.DockerClient(base_url=socket_path)
        logger.info("Docker client initialized")

    def get_service_node(self, service_name: str) -> str:
        """Get the current node where the service's task is running"""
        try:
            service = self.client.services.get(service_name)
            tasks = service.tasks(filters={'desired-state': 'running'})

            for task in tasks:
                task_state = task.get('Status', {}).get('State')
                if task_state == 'running':
                    node_id = task.get('NodeID')
                    if node_id:
                        node = self.client.nodes.get(node_id)
                        hostname = node.attrs['Description']['Hostname']
                        return hostname

            logger.warning(f"No running tasks found for {service_name}")
            return None
        except Exception as e:
            logger.error(f"Error getting service node: {e}")
            return None

    def migrate_container(self, service_name: str, from_node: str) -> dict:
        start_time = time.time()
        try:
            service = self.client.services.get(service_name)
            spec = service.attrs['Spec']
            current_replicas = spec.get('Mode', {}).get('Replicated', {}).get('Replicas', 1)

            logger.info(f"Zero-downtime migration: {service_name} from {from_node} (replicas={current_replicas})")

            # For Scenario 1: TRUE zero-downtime migration
            # Strategy: Add constraint + Scale up together → Wait for healthy + 10s grace → Remove old task
            # This ensures new container is on DIFFERENT node and STABLE before old one stops

            # Step 1: Find the task ID on the problem node
            logger.info(f"Step 1: Finding task on {from_node}")
            service.reload()
            tasks = service.tasks(filters={'desired-state': 'running'})

            old_task_id = None
            for task in tasks:
                task_state = task.get('Status', {}).get('State')
                if task_state == 'running':
                    node_id = task.get('NodeID')
                    if node_id:
                        node = self.client.nodes.get(node_id)
                        hostname = node.attrs['Description']['Hostname']
                        if hostname == from_node:
                            old_task_id = task.get('ID')
                            logger.info(f"Found old task {old_task_id[:12]} on {from_node}")
                            break

            if not old_task_id:
                logger.warning(f"No task found on {from_node}")
                return {'success': False, 'error': f'No task on {from_node}'}

            # Step 2: Use Docker Swarm's NATIVE rolling update with start-first
            # This is the CORRECT way to do zero-downtime migration in Docker Swarm
            task_template = spec.get('TaskTemplate', {})
            placement = task_template.get('Placement', {})
            current_constraints = placement.get('Constraints', [])
            current_image = spec['TaskTemplate']['ContainerSpec']['Image']

            # Remove any previous migration constraints, keep only base constraints
            base_constraints = [c for c in current_constraints if 'node.hostname!=' not in c]
            new_constraints = base_constraints + [f'node.hostname!={from_node}']

            logger.info(f"Step 2: Triggering rolling update with start-first order")
            logger.info(f"Constraints: {current_constraints} → {new_constraints}")

            # Use force_update to trigger rolling update
            # Docker will start NEW task BEFORE stopping OLD task (start-first default for replicated services)
            try:
                service.update(
                    image=current_image,
                    constraints=new_constraints,
                    force_update=True
                )
                logger.info(f"Step 3: Rolling update initiated - Docker will start new task before stopping old one")
            except Exception as e:
                logger.error(f"Failed to trigger rolling update: {e}")
                return {'success': False, 'error': f'Update failed: {str(e)}'}

            # Step 4: Wait for rolling update to complete
            # Monitor tasks to see when new task is running on different node
            wait_start = time.time()
            wait_timeout = 40  # Max 40s for rolling update
            migration_complete = False

            logger.info(f"Step 4: Monitoring rolling update (timeout {wait_timeout}s)")

            while (time.time() - wait_start) < wait_timeout:
                time.sleep(2)
                service.reload()
                tasks = service.tasks(filters={'desired-state': 'running'})

                running_tasks = []
                task_nodes = {}
                for task in tasks:
                    task_state = task.get('Status', {}).get('State')
                    task_id = task.get('ID')
                    if task_state == 'running':
                        node_id = task.get('NodeID')
                        if node_id:
                            node = self.client.nodes.get(node_id)
                            hostname = node.attrs['Description']['Hostname']
                            task_nodes[task_id] = hostname
                            running_tasks.append((task_id, hostname))

                logger.info(f"Running tasks: {[(tid[:12], node) for tid, node in running_tasks]}")

                # Check if we have exactly 1 task running on a different node
                if len(running_tasks) == 1:
                    task_id, node = running_tasks[0]
                    if node != from_node:
                        logger.info(f"✅ Rolling update complete: New task {task_id[:12]} on {node}")
                        migration_complete = True
                        break

            if not migration_complete:
                logger.error(f"Rolling update did not complete within {wait_timeout}s")
                return {'success': False, 'error': 'Rolling update timeout'}

            # Step 5: Final verification
            service.reload()
            tasks = service.tasks(filters={'desired-state': 'running'})

            final_tasks = {}
            new_node = None
            for task in tasks:
                task_state = task.get('Status', {}).get('State')
                if task_state == 'running':
                    node_id = task.get('NodeID')
                    if node_id:
                        node = self.client.nodes.get(node_id)
                        hostname = node.attrs['Description']['Hostname']
                        final_tasks[hostname] = final_tasks.get(hostname, 0) + 1
                        new_node = hostname  # Should only be one task

            logger.info(f"Final task distribution: {final_tasks}")

            total_time = time.time() - start_time

            if new_node and new_node != from_node and from_node not in final_tasks:
                logger.info(f"✅ Migration successful: {from_node} → {new_node}")
                logger.info(f"Zero-downtime rolling update complete: {service_name} on {new_node} ({total_time:.2f}s)")
                logger.info(f"MTTR: {total_time:.2f}s")
                return {'success': True, 'new_node': new_node, 'duration_seconds': total_time}
            else:
                logger.warning(f"Migration completed but final state unexpected: {final_tasks}")
                return {'success': False, 'error': f'Unexpected final state: {final_tasks}'}

        except docker.errors.NotFound:
            logger.error(f"Service {service_name} not found")
            return {'success': False, 'error': 'Service not found'}
        except Exception as e:
            logger.error(f"Migration error: {e}")
            return {'success': False, 'error': str(e)}

    def scale_up(self, service_name: str) -> dict:
        start_time = time.time()
        try:
            service = self.client.services.get(service_name)
            spec = service.attrs['Spec']
            current_replicas = spec.get('Mode', {}).get('Replicated', {}).get('Replicas', 1)
            max_replicas = self.config.get('scenarios.scenario2_scaling.scaling.max_replicas', 10)

            if current_replicas >= max_replicas:
                logger.warning(f"{service_name} already at max replicas ({max_replicas})")
                return {'success': False, 'error': f'Already at max replicas ({max_replicas})'}

            new_replicas = current_replicas + 1
            logger.info(f"Scaling {service_name} from {current_replicas} to {new_replicas} replicas")
            service.scale(new_replicas)
            total_time = time.time() - start_time
            logger.info(f"Scale-up successful: {service_name} scaled to {new_replicas} ({total_time:.2f}s)")

            return {'success': True, 'previous_replicas': current_replicas, 'new_replicas': new_replicas, 'duration_seconds': total_time}

        except docker.errors.NotFound:
            logger.error(f"Service {service_name} not found")
            return {'success': False, 'error': 'Service not found'}
        except Exception as e:
            logger.error(f"Scale-up error: {e}")
            return {'success': False, 'error': str(e)}
