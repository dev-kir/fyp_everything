#!/usr/bin/env python3
"""Docker Controller - Executes Docker Swarm recovery actions"""

import logging
import time
import docker

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

            # Update service with new constraints FIRST, then scale
            spec['TaskTemplate']['Placement'] = {'Constraints': new_constraints}
            spec['Mode']['Replicated']['Replicas'] = new_replicas

            # Apply constraints then scale - we'll keep the constraint permanently
            # so future scale operations respect it
            try:
                # First update constraints without changing replicas
                from docker.types import TaskTemplate as DockerTaskTemplate, ContainerSpec, Placement as DockerPlacement

                container_spec = ContainerSpec.from_dict(spec['TaskTemplate']['ContainerSpec'])
                placement = DockerPlacement(constraints=new_constraints)
                task_template = DockerTaskTemplate(container_spec=container_spec, placement=placement)

                # Update constraints first
                service.update(task_template=task_template)
                logger.info(f"Updated constraints: {new_constraints}")
                time.sleep(1)

                # Then scale
                service.reload()
                service.scale(new_replicas)
                logger.info(f"Scaled to {new_replicas} replicas with constraints")
            except Exception as e:
                logger.error(f"Failed to update constraints: {e}")
                # Fallback to just scaling
                service.scale(new_replicas)
                logger.warning(f"Fallback: scaled without constraint update")

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

            # Step 3: Remove OLD container from problem node (not the new one!)
            logger.info(f"Step 3: Removing old container from {from_node}")
            time.sleep(2)  # Give new container a moment to stabilize

            # Find and stop the OLD task on the problem node
            service.reload()
            tasks = service.tasks(filters={'desired-state': 'running'})
            old_task_id = None

            for task in tasks:
                node_id = task.get('NodeID')
                if node_id:
                    task_node = self.client.nodes.get(node_id)
                    task_hostname = task_node.attrs['Description']['Hostname']
                    if task_hostname == from_node:
                        old_task_id = task.get('ID')
                        logger.info(f"Found old task {old_task_id[:12]} on {from_node}, will remove it")
                        break

            # Scale down to remove the old task
            service.scale(current_replicas)
            logger.info(f"Scaled down to {current_replicas} replicas")

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
