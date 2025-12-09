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

            # Step 1: Scale up by 1 with constraints (deploy new container on different worker)
            constraints = [
                f'node.hostname != {from_node}',
                'node.hostname != master',
                'node.role == worker'
            ]
            new_replicas = current_replicas + 1
            logger.info(f"Step 1: Scaling up {service_name} to {new_replicas} replicas with constraints")

            # Update with only the fields we need to change
            version = service.version
            service.update(
                version=version,
                mode={'Replicated': {'Replicas': new_replicas}},
                task_template=spec['TaskTemplate']
            )

            # Add constraints after initial scale
            spec['TaskTemplate']['Placement'] = {'Constraints': constraints}
            service.reload()
            service.update(
                version=service.version,
                mode={'Replicated': {'Replicas': new_replicas}},
                task_template=spec['TaskTemplate']
            )

            # Step 2: Wait for new container to be healthy
            timeout = self.config.get('scenarios.scenario1_migration.migration.health_timeout', 10)
            wait_start = time.time()
            new_task_healthy = False
            new_node = None

            while (time.time() - wait_start) < timeout:
                tasks = service.tasks(filters={'desired-state': 'running'})
                for task in tasks:
                    node_id = task.get('NodeID')
                    task_node = self.client.nodes.get(node_id)
                    task_hostname = task_node.attrs['Description']['Hostname']

                    if task_hostname != from_node:
                        task_state = task.get('Status', {}).get('State')
                        if task_state == 'running':
                            new_task_healthy = True
                            new_node = task_hostname
                            logger.info(f"Step 2: New container healthy on {new_node}")
                            break

                if new_task_healthy:
                    break
                time.sleep(0.5)

            if not new_task_healthy:
                logger.warning(f"New container not healthy after {timeout}s, rolling back")
                service.reload()
                service.update(
                    version=service.version,
                    mode={'Replicated': {'Replicas': current_replicas}},
                    task_template=spec['TaskTemplate']
                )
                return {'success': False, 'error': 'New container failed to become healthy'}

            # Step 3: Remove old container by scaling back to original count
            logger.info(f"Step 3: Scaling down to {current_replicas} replicas (removing old container)")
            service.reload()
            service.update(
                version=service.version,
                mode={'Replicated': {'Replicas': current_replicas}},
                task_template=spec['TaskTemplate']
            )

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
