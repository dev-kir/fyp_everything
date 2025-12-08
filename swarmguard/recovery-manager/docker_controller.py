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
            logger.info(f"Migrating {service_name} away from {from_node}")

            service.update(force_update=True, constraints=[f'node.hostname != {from_node}'])
            logger.info(f"Migration initiated for {service_name}")

            timeout = self.config.get('scenarios.scenario1_migration.migration.health_timeout', 10)
            wait_start = time.time()

            while (time.time() - wait_start) < timeout:
                tasks = service.tasks(filters={'desired-state': 'running'})
                for task in tasks:
                    node_id = task.get('NodeID')
                    task_node = self.client.nodes.get(node_id)
                    task_hostname = task_node.attrs['Description']['Hostname']

                    if task_hostname != from_node:
                        task_state = task.get('Status', {}).get('State')
                        if task_state == 'running':
                            total_time = time.time() - start_time
                            logger.info(f"Migration successful: {service_name} now on {task_hostname} ({total_time:.2f}s)")
                            return {'success': True, 'new_node': task_hostname, 'duration_seconds': total_time}
                time.sleep(0.5)

            logger.warning(f"Migration timeout for {service_name}")
            return {'success': False, 'error': 'Timeout waiting for new container'}

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
