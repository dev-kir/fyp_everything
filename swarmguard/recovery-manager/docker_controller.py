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

    def migrate_container(self, service_name: str, from_node: str) -> dict:
        start_time = time.time()
        try:
            service = self.client.services.get(service_name)
            spec = service.attrs['Spec']
            current_replicas = spec.get('Mode', {}).get('Replicated', {}).get('Replicas', 1)

            logger.info(f"Zero-downtime migration: {service_name} from {from_node}")

            # Step 1: Add constraint to EXCLUDE problem node, then scale up
            new_replicas = current_replicas + 1
            logger.info(f"Step 1: Adding constraint to exclude {from_node}, then scaling to {new_replicas} replicas")

            # Get current constraints from service
            current_constraints = []
            if 'Placement' in spec['TaskTemplate'] and 'Constraints' in spec['TaskTemplate']['Placement']:
                current_constraints = spec['TaskTemplate']['Placement']['Constraints']

            # Build new constraint list with problem node exclusion
            new_constraints = []
            for c in current_constraints:
                # Skip if constraint already excludes this specific node
                if f'node.hostname != {from_node}' not in c and f'node.hostname!={from_node}' not in c:
                    new_constraints.append(c)

            # Add our constraints
            new_constraints.extend([
                f'node.hostname != {from_node}',
                'node.hostname != master',
                'node.role == worker'
            ])

            # Step 1: Scale up (Docker will place new task somewhere)
            logger.info(f"Scaling to {new_replicas} replicas")
            service.scale(new_replicas)

            # Wait for new task to be created and running
            wait_start = time.time()
            wait_timeout = 15  # Max 15s to wait for scale-up
            new_task_started = False

            while (time.time() - wait_start) < wait_timeout:
                time.sleep(2)
                service.reload()
                tasks = service.tasks(filters={'desired-state': 'running'})

                # Count running tasks
                running_count = 0
                for task in tasks:
                    task_state = task.get('Status', {}).get('State')
                    if task_state == 'running':
                        running_count += 1

                logger.info(f"Waiting for scale-up: {running_count}/{new_replicas} tasks running")

                if running_count >= new_replicas:
                    new_task_started = True
                    break

            if not new_task_started:
                logger.error(f"Scale-up failed: timeout waiting for {new_replicas} tasks")
                return {'success': False, 'error': 'Scale-up timeout'}

            # Check where tasks are placed
            service.reload()
            tasks = service.tasks(filters={'desired-state': 'running'})

            tasks_by_node = {}
            for task in tasks:
                node_id = task.get('NodeID')
                if node_id:
                    task_state = task.get('Status', {}).get('State')
                    if task_state == 'running':
                        task_node = self.client.nodes.get(node_id)
                        task_hostname = task_node.attrs['Description']['Hostname']
                        task_id = task.get('ID')

                        if task_hostname not in tasks_by_node:
                            tasks_by_node[task_hostname] = []
                        tasks_by_node[task_hostname].append(task_id)

            logger.info(f"Task placement after scale-up: {dict(tasks_by_node)}")

            # Check if we have task on different node
            if from_node in tasks_by_node and len(tasks_by_node) == 1:
                logger.error(f"All {new_replicas} tasks on same node {from_node} - Docker Swarm not distributing")
                return {'success': False, 'error': f'All tasks placed on {from_node}, cannot migrate'}

            # Step 2: Identify which node has the new task (not on problem node)
            # We already have tasks_by_node from Step 1
            new_node = None
            for node_hostname, task_ids in tasks_by_node.items():
                if node_hostname != from_node:
                    new_node = node_hostname
                    logger.info(f"Step 2: New container running on {new_node}")
                    break

            if not new_node:
                logger.error(f"Could not find task on node other than {from_node}")
                service.scale(current_replicas)
                return {'success': False, 'error': 'All tasks on problem node'}

            # Step 3: Scale down while KEEPING the constraint to exclude problem node
            logger.info(f"Step 3: Scaling down to {current_replicas} while keeping {from_node} excluded")
            time.sleep(2)  # Give new container a moment to stabilize

            # Scale down with constraints still in place
            # This ensures Docker removes the old task from worker-3, not the new one on worker-4
            service.reload()
            service.scale(current_replicas)
            logger.info(f"Scaled down to {current_replicas} replicas")

            # Wait a moment for scale-down to complete
            time.sleep(2)

            # Verify the container is on the new node
            service.reload()
            tasks = service.tasks(filters={'desired-state': 'running'})
            final_node = None
            for task in tasks:
                node_id = task.get('NodeID')
                if node_id:
                    task_node = self.client.nodes.get(node_id)
                    final_node = task_node.attrs['Description']['Hostname']
                    break

            if final_node == from_node:
                logger.error(f"Migration failed! Container returned to {from_node}")
                return {'success': False, 'error': f'Container returned to problem node {from_node}'}

            logger.info(f"Verified: Container is on {final_node} (not {from_node})")

            total_time = time.time() - start_time
            logger.info(f"Zero-downtime migration complete: {service_name} on {new_node} ({total_time:.2f}s)")
            return {'success': True, 'new_node': new_node, 'duration_seconds': total_time}

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
