#!/usr/bin/env python3
"""SwarmGuard Recovery Manager - Central decision engine"""

import os
import time
import logging
import json
from flask import Flask, request, jsonify
from threading import Lock, Thread

from config_loader import ConfigLoader
from rule_engine import RuleEngine
from docker_controller import DockerController

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

app = Flask(__name__)


class RecoveryManager:
    def __init__(self, config_path: str = None):
        self.lock = Lock()
        if config_path is None:
            config_path = os.getenv('CONFIG_PATH', '/app/config.yaml')
        self.config = ConfigLoader(config_path)
        self.rule_engine = RuleEngine(self.config)
        self.docker_controller = DockerController(self.config)
        self.metrics_cache = {}
        self.cooldowns = {}
        self.breach_counts = {}
        self.scale_down_last_checked = {}
        self.running = False
        self.monitor_thread = None
        logger.info("Recovery Manager initialized")

    def handle_alert(self, alert_data: dict) -> dict:
        start_time = time.time()
        try:
            container_id = alert_data.get('container_id')
            service_name = alert_data.get('service_name', alert_data.get('container_name'))
            node = alert_data.get('node')
            scenario = alert_data.get('scenario')
            metrics = alert_data.get('metrics', {})

            logger.info(f"Alert: {service_name} on {node} - {scenario} - CPU={metrics.get('cpu_percent')}% MEM={metrics.get('memory_percent')}%")

            if container_id not in self.breach_counts:
                self.breach_counts[container_id] = 0
            self.breach_counts[container_id] += 1

            required_breaches = 2
            if self.breach_counts[container_id] < required_breaches:
                logger.info(f"Breach {self.breach_counts[container_id]}/{required_breaches} for {service_name} - waiting")
                return {'status': 'waiting', 'breach_count': self.breach_counts[container_id]}

            self.breach_counts[container_id] = 0

            current_time = int(time.time())
            if service_name in self.cooldowns:
                # Different cooldown periods for different scenarios:
                # - Migration: 60s (prevent rapid re-migrations)
                # - Scale-up: 60s (PRD requirement: scale_up_cooldown)
                # - Scale-down: 180s (PRD requirement: scale_down_cooldown, must be conservative)
                if scenario == 'scenario1_migration':
                    cooldown_period = 60
                elif scenario == 'scenario2_scale_up' or scenario == 'scenario2_scaling':
                    cooldown_period = self.config.get('scenarios.scenario2_scaling.scale_up_cooldown', 60)
                elif scenario == 'scenario2_scale_down':
                    cooldown_period = self.config.get('scenarios.scenario2_scaling.scale_down_cooldown', 180)
                else:
                    cooldown_period = 30  # Default

                time_since_last = current_time - self.cooldowns[service_name]
                if time_since_last < cooldown_period:
                    logger.info(f"Cooldown active for {service_name}: {time_since_last}s < {cooldown_period}s")
                    return {'status': 'cooldown', 'message': f'Cooldown active ({time_since_last}s/{cooldown_period}s)'}

            with self.lock:
                if scenario == 'scenario1_migration':
                    result = self.execute_migration(service_name, container_id, node, alert_data)
                elif scenario == 'scenario2_scale_up':
                    result = self.execute_scale_up(service_name, alert_data)
                elif scenario == 'scenario2_scale_down':
                    result = self.execute_scale_down(service_name, alert_data)
                elif scenario == 'scenario2_scaling':
                    # Legacy support for old scenario name (defaults to scale-up)
                    result = self.execute_scale_up(service_name, alert_data)
                else:
                    return {'status': 'error', 'message': 'Unknown scenario'}

                self.cooldowns[service_name] = current_time
                total_time = (time.time() - start_time) * 1000
                logger.info(f"Alert processed in {total_time:.0f}ms")
                if total_time > 1000:
                    logger.warning(f"Alert processing exceeded 1 second: {total_time:.0f}ms")
                return result

        except Exception as e:
            logger.error(f"Error handling alert: {e}", exc_info=True)
            return {'status': 'error', 'message': str(e)}

    def execute_migration(self, service_name: str, container_id: str, node: str, alert_data: dict) -> dict:
        logger.info(f"Executing migration for {service_name} from {node}")
        try:
            # CRITICAL: Verify container is actually on the reported node before migrating
            # This prevents stale alerts from triggering duplicate migrations
            actual_node = self.docker_controller.get_service_node(service_name)
            if actual_node != node:
                logger.warning(f"Stale alert ignored: {service_name} reported on {node}, actually on {actual_node}")
                return {'status': 'ignored', 'reason': 'stale_alert', 'reported_node': node, 'actual_node': actual_node}

            result = self.docker_controller.migrate_container(service_name, node)

            # SUCCESS: Extend cooldown to 60s after successful migration
            if result.get('success'):
                self.cooldowns[service_name] = int(time.time())  # Reset cooldown after success
                logger.info(f"Migration succeeded - cooldown extended to 60s")

            return {'status': 'success', 'action': 'migration', 'service': service_name, 'from_node': node, 'result': result}
        except Exception as e:
            logger.error(f"Migration failed for {service_name}: {e}")
            return {'status': 'error', 'action': 'migration', 'message': str(e)}

    def execute_scale_up(self, service_name: str, alert_data: dict) -> dict:
        logger.info(f"Executing scale-up for {service_name}")
        try:
            result = self.docker_controller.scale_up(service_name)
            return {'status': 'success', 'action': 'scale_up', 'service': service_name, 'result': result}
        except Exception as e:
            logger.error(f"Scale-up failed for {service_name}: {e}")
            return {'status': 'error', 'action': 'scale_up', 'message': str(e)}

    def execute_scale_down(self, service_name: str, alert_data: dict) -> dict:
        logger.info(f"Executing scale-down for {service_name}")
        try:
            result = self.docker_controller.scale_down(service_name)
            return {'status': 'success', 'action': 'scale_down', 'service': service_name, 'result': result}
        except Exception as e:
            logger.error(f"Scale-down failed for {service_name}: {e}")
            return {'status': 'error', 'action': 'scale_down', 'message': str(e)}

    def monitor_scale_down_thread(self):
        """
        Background thread that monitors services for scale-down eligibility
        PRD Requirement: Scale down when total_usage_all_containers < threshold * (N_containers - 1)
        """
        logger.info("Scale-down monitoring thread started")
        check_interval = 60  # Check every 60 seconds (PRD: scale_up_cooldown)

        while self.running:
            try:
                time.sleep(check_interval)
                if not self.running:
                    break

                # Get list of services to monitor for autoscaling
                # For now, we'll monitor all services that have >1 replica
                services_to_check = self.docker_controller.get_autoscaling_services()

                for service_name in services_to_check:
                    try:
                        # Get all tasks and their aggregate metrics
                        aggregate = self.docker_controller.get_service_aggregate_metrics(service_name)
                        if not aggregate:
                            continue

                        current_replicas = aggregate['replica_count']
                        if current_replicas <= 1:
                            continue  # Cannot scale below 1

                        # PRD Formula: Scale down if total_usage < threshold * (N - 1)
                        # This ensures remaining replicas can handle the load
                        cpu_threshold = self.config.get('scenarios.scenario2_scaling.cpu_threshold', 75)
                        mem_threshold = self.config.get('scenarios.scenario2_scaling.memory_threshold', 80)

                        total_cpu = aggregate['total_cpu_percent']
                        total_mem = aggregate['total_memory_percent']

                        # Calculate if we can safely scale down
                        # After removing 1 replica, the load would be distributed across (N-1) replicas
                        can_scale_down_cpu = total_cpu < (cpu_threshold * (current_replicas - 1))
                        can_scale_down_mem = total_mem < (mem_threshold * (current_replicas - 1))

                        if can_scale_down_cpu and can_scale_down_mem:
                            # Check cooldown (180s for scale-down per PRD)
                            current_time = int(time.time())
                            scale_down_cooldown = self.config.get('scenarios.scenario2_scaling.scale_down_cooldown', 180)

                            if service_name in self.cooldowns:
                                time_since_last = current_time - self.cooldowns[service_name]
                                if time_since_last < scale_down_cooldown:
                                    logger.debug(f"Scale-down cooldown active for {service_name}: {time_since_last}s < {scale_down_cooldown}s")
                                    continue

                            # Also check scale_down_last_checked to ensure idle for sustained period
                            if service_name not in self.scale_down_last_checked:
                                # First time seeing idle state, mark the time
                                self.scale_down_last_checked[service_name] = current_time
                                logger.info(f"Scale-down candidate: {service_name} idle detected (will scale down after {scale_down_cooldown}s)")
                                continue
                            else:
                                # Check if idle for full cooldown period
                                idle_duration = current_time - self.scale_down_last_checked[service_name]
                                if idle_duration >= scale_down_cooldown:
                                    # Scale down!
                                    logger.info(f"Scale-down triggered: {service_name} idle for {idle_duration}s (threshold: {scale_down_cooldown}s)")
                                    logger.info(f"Current: {current_replicas} replicas, CPU={total_cpu:.1f}%, MEM={total_mem:.1f}%")
                                    logger.info(f"After scale-down: {current_replicas-1} replicas can handle load (CPU<{cpu_threshold*(current_replicas-1):.1f}%, MEM<{mem_threshold*(current_replicas-1):.1f}%)")

                                    with self.lock:
                                        result = self.docker_controller.scale_down(service_name)
                                        if result.get('success'):
                                            self.cooldowns[service_name] = current_time
                                            self.scale_down_last_checked.pop(service_name, None)
                                            logger.info(f"✅ Scale-down successful: {service_name} {current_replicas} → {current_replicas-1}")
                                else:
                                    logger.debug(f"Scale-down candidate: {service_name} idle for {idle_duration}s (need {scale_down_cooldown}s)")
                        else:
                            # Not eligible for scale-down, reset idle timer
                            if service_name in self.scale_down_last_checked:
                                self.scale_down_last_checked.pop(service_name)
                                logger.debug(f"Scale-down reset: {service_name} no longer idle (CPU={total_cpu:.1f}%, MEM={total_mem:.1f}%)")

                    except Exception as e:
                        logger.error(f"Error checking scale-down for {service_name}: {e}")

            except Exception as e:
                logger.error(f"Error in scale-down monitoring thread: {e}", exc_info=True)

        logger.info("Scale-down monitoring thread stopped")

    def start_background_monitoring(self):
        """Start background thread for scale-down monitoring"""
        self.running = True
        self.monitor_thread = Thread(target=self.monitor_scale_down_thread, daemon=True)
        self.monitor_thread.start()
        logger.info("Background monitoring started")

    def stop_background_monitoring(self):
        """Stop background thread"""
        self.running = False
        if self.monitor_thread:
            self.monitor_thread.join(timeout=5)
        logger.info("Background monitoring stopped")


recovery_manager = None


@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy', 'service': 'recovery-manager'})


@app.route('/alert', methods=['POST'])
def receive_alert():
    try:
        alert_data = request.get_json()
        if not alert_data:
            return jsonify({'status': 'error', 'message': 'No data provided'}), 400
        result = recovery_manager.handle_alert(alert_data)
        return jsonify(result), 200
    except Exception as e:
        logger.error(f"Error processing alert: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500


@app.route('/metrics', methods=['GET'])
def get_metrics():
    return jsonify({'metrics_cache_size': len(recovery_manager.metrics_cache), 'active_cooldowns': len(recovery_manager.cooldowns)})


def main():
    global recovery_manager
    logger.info("Starting SwarmGuard Recovery Manager")
    recovery_manager = RecoveryManager()

    # Start background monitoring thread for scale-down detection
    recovery_manager.start_background_monitoring()

    host = os.getenv('FLASK_HOST', '0.0.0.0')
    port = int(os.getenv('FLASK_PORT', '5000'))
    logger.info(f"Starting HTTP server on {host}:{port}")
    try:
        app.run(host=host, port=port, threaded=True)
    finally:
        recovery_manager.stop_background_monitoring()


if __name__ == '__main__':
    main()
