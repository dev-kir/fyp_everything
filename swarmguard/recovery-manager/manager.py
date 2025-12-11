#!/usr/bin/env python3
"""SwarmGuard Recovery Manager - Central decision engine"""

import os
import time
import logging
import json
from flask import Flask, request, jsonify
from threading import Lock

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
                # Migration needs longer cooldown (60s) to prevent rapid re-migrations
                # Scale-up can be more frequent (30s) for traffic spikes
                cooldown_period = 60 if scenario == 'scenario1_migration' else 30
                time_since_last = current_time - self.cooldowns[service_name]
                if time_since_last < cooldown_period:
                    logger.info(f"Cooldown active for {service_name}: {time_since_last}s < {cooldown_period}s")
                    return {'status': 'cooldown', 'message': f'Cooldown active ({time_since_last}s/{cooldown_period}s)'}

            with self.lock:
                if scenario == 'scenario1_migration':
                    result = self.execute_migration(service_name, container_id, node, alert_data)
                elif scenario == 'scenario2_scaling':
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
    host = os.getenv('FLASK_HOST', '0.0.0.0')
    port = int(os.getenv('FLASK_PORT', '5000'))
    logger.info(f"Starting HTTP server on {host}:{port}")
    app.run(host=host, port=port, threaded=True)


if __name__ == '__main__':
    main()
