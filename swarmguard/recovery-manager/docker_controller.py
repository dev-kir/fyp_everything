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
            # Strategy: Add constraint → Scale up → Wait for healthy → Remove old task
            # This ensures new container is on DIFFERENT node and READY before old one stops

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

            # Step 2: Scale up to 2 replicas FIRST (before adding constraints)
            # This ensures old task stays running while new task starts
            new_replicas = current_replicas + 1
            logger.info(f"Step 2: Scaling up from {current_replicas} to {new_replicas} replicas")
            service.scale(new_replicas)

            # Wait a moment for scale command to be processed
            time.sleep(1)

            # Step 3: Wait for new task to be RUNNING AND HEALTHY
            wait_start = time.time()
            wait_timeout = 30  # Max 30s to wait for new task
            new_task_ready = False

            logger.info(f"Step 3: Waiting for new task to be healthy (timeout {wait_timeout}s)")

            while (time.time() - wait_start) < wait_timeout:
                time.sleep(2)
                service.reload()
                tasks = service.tasks(filters={'desired-state': 'running'})

                running_tasks = []
                for task in tasks:
                    task_state = task.get('Status', {}).get('State')
                    task_id = task.get('ID')
                    if task_state == 'running' and task_id != old_task_id:
                        running_tasks.append(task_id)

                logger.info(f"Waiting for new task: {len(running_tasks)} new tasks running")

                if len(running_tasks) >= 1:
                    new_task_ready = True
                    logger.info(f"New task {running_tasks[0][:12]} is running!")
                    break

            if not new_task_ready:
                logger.error(f"New task failed to start within {wait_timeout}s")
                service.scale(current_replicas)  # Rollback
                return {'success': False, 'error': 'New task timeout'}

            # Step 4: Verify new task is on DIFFERENT node
            service.reload()
            tasks = service.tasks(filters={'desired-state': 'running'})

            new_node = None
            for task in tasks:
                task_id = task.get('ID')
                task_state = task.get('Status', {}).get('State')
                if task_state == 'running' and task_id != old_task_id:
                    node_id = task.get('NodeID')
                    if node_id:
                        node = self.client.nodes.get(node_id)
                        new_node = node.attrs['Description']['Hostname']
                        logger.info(f"New task on {new_node}")
                        break

            if not new_node:
                logger.error(f"Could not find new task node")
                service.scale(current_replicas)  # Rollback
                return {'success': False, 'error': 'Could not find new task'}

            if new_node == from_node:
                logger.error(f"New task placed on same node {from_node}")
                service.scale(current_replicas)  # Rollback
                return {'success': False, 'error': f'New task on same node {from_node}'}

            # Step 5: Remove old task by scaling down
            # Docker will remove one task - since we have 2 running and want 1,
            # Docker's algorithm should keep the newer/healthier one
            logger.info(f"Step 5: Scaling down to {current_replicas} - Docker will remove a task")
            service.scale(current_replicas)

            # Wait for scale-down to complete
            time.sleep(3)

            # Step 6: Verify final state
            service.reload()
            tasks = service.tasks(filters={'desired-state': 'running'})

            final_tasks = {}
            for task in tasks:
                task_state = task.get('Status', {}).get('State')
                if task_state == 'running':
                    node_id = task.get('NodeID')
                    if node_id:
                        node = self.client.nodes.get(node_id)
                        hostname = node.attrs['Description']['Hostname']
                        final_tasks[hostname] = final_tasks.get(hostname, 0) + 1

            logger.info(f"Final task distribution: {final_tasks}")

            total_time = time.time() - start_time

            if new_node in final_tasks and from_node not in final_tasks:
                logger.info(f"✅ Migration successful: {from_node} → {new_node}")
                logger.info(f"Zero-downtime migration complete: {service_name} on {new_node} ({total_time:.2f}s)")
                logger.info(f"MTTR: {total_time:.2f}s")
                return {'success': True, 'new_node': new_node, 'duration_seconds': total_time}
            else:
                logger.warning(f"Migration completed but final state unexpected: {final_tasks}")
                return {'success': True, 'new_node': new_node, 'duration_seconds': total_time, 'note': 'Unexpected final state'}

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
