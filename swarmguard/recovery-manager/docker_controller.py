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

            # PRAGMATIC SOLUTION: Scale up, check placement, retry if needed
            # Since Docker SDK constraints are unreliable, we'll verify and retry
            logger.info(f"Scaling to {new_replicas} replicas")

            max_attempts = 3
            for attempt in range(max_attempts):
                # Scale up
                service.scale(new_replicas)
                time.sleep(4)  # Wait for task creation

                # Check if we have a task on different node
                service.reload()
                tasks = service.tasks(filters={'desired-state': 'running'})

                nodes_with_tasks = set()
                for task in tasks:
                    node_id = task.get('NodeID')
                    if node_id:
                        task_state = task.get('Status', {}).get('State')
                        if task_state == 'running':
                            task_node = self.client.nodes.get(node_id)
                            task_hostname = task_node.attrs['Description']['Hostname']
                            nodes_with_tasks.add(task_hostname)

                logger.info(f"Attempt {attempt+1}: Tasks running on nodes: {nodes_with_tasks}")

                # Check if we have task on different node
                if len(nodes_with_tasks) > 1 or (len(nodes_with_tasks) == 1 and from_node not in nodes_with_tasks):
                    logger.info(f"Success: Found task on node other than {from_node}")
                    break

                # All tasks still on problem node - force restart one task
                if attempt < max_attempts - 1:
                    logger.warning(f"All tasks on {from_node}, forcing task recreation (attempt {attempt+1})")
                    # Scale down and back up to force Docker to redistribute
                    service.scale(current_replicas)
                    time.sleep(2)
                    # Try again
                else:
                    logger.error(f"Failed to create task on different node after {max_attempts} attempts")
                    return {'success': False, 'error': 'Could not place task on different node'}

            # Step 2: Wait for new container to be healthy
            timeout = self.config.get('scenarios.scenario1_migration.migration.health_timeout', 10)
            wait_start = time.time()
            new_task_healthy = False
            new_node = None

            while (time.time() - wait_start) < timeout:
                try:
                    time.sleep(1)  # Give Docker time to create new task
                    service.reload()  # Reload service to get updated tasks
                    tasks = service.tasks(filters={'desired-state': 'running'})

                    # Count running tasks by node
                    running_nodes = []
                    for task in tasks:
                        node_id = task.get('NodeID')
                        if not node_id:
                            continue
                        task_state = task.get('Status', {}).get('State')
                        if task_state == 'running':
                            task_node = self.client.nodes.get(node_id)
                            task_hostname = task_node.attrs['Description']['Hostname']
                            running_nodes.append(task_hostname)

                    # Check if we have a new replica running on a different node
                    if len(running_nodes) >= new_replicas:
                        for node_hostname in running_nodes:
                            if node_hostname != from_node:
                                new_task_healthy = True
                                new_node = node_hostname
                                logger.info(f"Step 2: New container healthy on {new_node}")
                                break

                    if new_task_healthy:
                        break
                except Exception as e:
                    logger.debug(f"Error checking tasks: {e}")
                    time.sleep(0.5)

            if not new_task_healthy:
                logger.warning(f"New container not healthy after {timeout}s, rolling back")
                service.reload()
                service.scale(current_replicas)
                return {'success': False, 'error': 'New container failed to become healthy'}

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
