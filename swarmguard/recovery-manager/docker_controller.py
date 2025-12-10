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

            logger.info(f"Zero-downtime migration: {service_name} from {from_node} (replicas={current_replicas})")

            # For Scenario 1: Migration means moving the container to a different node
            # Strategy: Use Docker Swarm's rolling update with start-first strategy
            # This creates new task FIRST, then removes old one (zero downtime)

            # Step 1: Add placement constraint to exclude problem node
            logger.info(f"Step 1: Adding placement constraint to exclude {from_node}")

            # Get current placement constraints
            current_constraints = []
            placement = spec.get('TaskTemplate', {}).get('Placement', {})
            if 'Constraints' in placement:
                current_constraints = placement['Constraints']

            # Build new constraint list
            new_constraints = []
            for c in current_constraints:
                # Keep constraints that don't conflict with our new constraint
                if f'node.hostname != {from_node}' not in c and f'node.hostname!={from_node}' not in c:
                    new_constraints.append(c)

            # Add constraint to exclude problem node
            new_constraints.append(f'node.hostname != {from_node}')

            logger.info(f"New placement constraints: {new_constraints}")

            # Step 2: Update service spec with new constraints
            # This will force Docker to recreate tasks following the new placement rules
            logger.info(f"Step 2: Updating service spec with new constraints")

            try:
                # Get the full service spec
                task_template = spec.get('TaskTemplate', {})

                # Update placement constraints
                if 'Placement' not in task_template:
                    task_template['Placement'] = {}
                task_template['Placement']['Constraints'] = new_constraints

                # Update the spec with new task template
                spec['TaskTemplate'] = task_template

                # Add UpdateConfig for zero-downtime rolling update
                spec['UpdateConfig'] = {
                    'Parallelism': 1,
                    'FailureAction': 'pause',
                    'Monitor': 5000000000,  # 5s in nanoseconds
                    'MaxFailureRatio': 0.0,
                    'Order': 'start-first'  # Start new task before stopping old one
                }

                # Force update to recreate tasks
                logger.info(f"Calling service.update() with force_update=True")
                service.update(
                    task_template=task_template,
                    update_config=spec['UpdateConfig'],
                    force_update=True
                )
                logger.info(f"Service update initiated - Docker will recreate tasks")

            except Exception as e:
                logger.error(f"Service update failed: {e}")
                return {'success': False, 'error': f'Update failed: {e}'}

            # Step 3: Wait for rolling update to complete
            # Docker will create new task first (start-first), then remove old one
            wait_start = time.time()
            wait_timeout = 30  # Max 30s to wait for update (includes health check time)
            update_completed = False

            logger.info(f"Step 3: Waiting for rolling update to complete (timeout {wait_timeout}s)")

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

                logger.info(f"Waiting for update: {running_count}/{current_replicas} tasks running")

                # Update is complete when we have exactly current_replicas running tasks
                if running_count >= current_replicas:
                    update_completed = True
                    break

            if not update_completed:
                logger.error(f"Update failed: timeout waiting for {current_replicas} running tasks")
                return {'success': False, 'error': 'Update timeout'}

            # Step 4: Verify task placement on different node
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

            logger.info(f"Final task placement: {dict(tasks_by_node)}")

            # Verify migration success
            if not tasks_by_node:
                logger.error(f"Migration failed! No tasks running after update")
                return {'success': False, 'error': 'No running tasks after update'}

            # With force_update and constraints, Docker should have recreated task on different node
            final_node = list(tasks_by_node.keys())[0] if tasks_by_node else None

            if not final_node:
                logger.error(f"Migration failed! No tasks running")
                return {'success': False, 'error': 'No tasks after migration'}

            total_time = time.time() - start_time

            if final_node != from_node:
                # Success: Task migrated to different node
                logger.info(f"✅ Migration successful: {from_node} → {final_node}")
                logger.info(f"Zero-downtime migration complete: {service_name} on {final_node} ({total_time:.2f}s)")
                logger.info(f"MTTR: {total_time:.2f}s")
                return {'success': True, 'new_node': final_node, 'duration_seconds': total_time}
            else:
                # Failure: Task still on same node (constraint didn't work or no other nodes available)
                logger.error(f"❌ Migration failed: task still on {from_node}")
                logger.error(f"Constraint 'node.hostname != {from_node}' did not prevent placement")
                # Check if other nodes are available
                all_nodes = self.client.nodes.list()
                available_nodes = [n.attrs['Description']['Hostname'] for n in all_nodes
                                 if n.attrs['Description']['Hostname'] != from_node
                                 and n.attrs['Status']['State'] == 'ready']
                if not available_nodes:
                    logger.error(f"No other ready nodes available for migration")
                    return {'success': False, 'error': 'No alternative nodes available'}
                else:
                    logger.error(f"Available nodes: {available_nodes}, but Docker placed on {from_node}")
                    return {'success': False, 'error': f'Task still on {from_node} despite constraint'}

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
