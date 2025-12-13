#!/usr/bin/env python3
"""
SwarmGuard Monitoring Agent
Collects metrics from Docker containers and sends alerts to recovery manager
"""

import os
import sys
import time
import logging
import signal
from datetime import datetime
import asyncio

from metrics_collector import MetricsCollector
from influxdb_writer import InfluxDBWriter
from alert_sender import AlertSender

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class MonitoringAgent:
    def __init__(self):
        self.running = False
        self.node_name = os.getenv('NODE_NAME', 'unknown')
        self.net_iface = os.getenv('NET_IFACE', 'eth0')
        self.poll_interval = int(os.getenv('POLL_INTERVAL', '5'))
        self.influxdb_url = os.getenv('INFLUXDB_URL')
        self.influxdb_token = os.getenv('INFLUXDB_TOKEN')
        self.recovery_manager_url = os.getenv('RECOVERY_MANAGER_URL', 'http://recovery-manager:5000')
        self.cpu_threshold = float(os.getenv('CPU_THRESHOLD', '75.0'))
        self.memory_threshold = float(os.getenv('MEMORY_THRESHOLD', '80.0'))
        self.network_threshold_low = float(os.getenv('NETWORK_THRESHOLD_LOW', '35.0'))
        self.network_threshold_high = float(os.getenv('NETWORK_THRESHOLD_HIGH', '65.0'))

        logger.info(f"Initializing monitoring agent for node: {self.node_name}")
        logger.info(f"Network interface: {self.net_iface}, Poll interval: {self.poll_interval}s")

        self.metrics_collector = MetricsCollector(self.node_name, self.net_iface)
        self.influxdb_writer = InfluxDBWriter(self.influxdb_url, self.influxdb_token)
        self.alert_sender = AlertSender(self.recovery_manager_url)

        self.metrics_batch = []
        self.last_flush = time.time()
        self.batch_size = int(os.getenv('BATCH_SIZE', '20'))
        self.flush_interval = int(os.getenv('FLUSH_INTERVAL', '10'))

    def signal_handler(self, signum, frame):
        logger.info(f"Received signal {signum}, shutting down...")
        self.running = False

    async def check_thresholds_and_alert(self, container_metrics: dict):
        cpu = container_metrics.get('cpu_percent', 0)
        mem = container_metrics.get('memory_percent', 0)
        net_in = container_metrics.get('network_rx_mbps', 0)
        net_out = container_metrics.get('network_tx_mbps', 0)

        # Calculate network percentage based on 100Mbps interface capacity (12.5 MB/s)
        # Average of RX and TX as percentage of capacity
        interface_capacity_mbps = 100.0  # 100Mbps network (PRD section 4.2)
        net_total_mbps = net_in + net_out
        net_percent = (net_total_mbps / interface_capacity_mbps) * 100

        should_alert = False
        scenario = None

        if (cpu > self.cpu_threshold or mem > self.memory_threshold) and net_percent < self.network_threshold_low:
            should_alert = True
            scenario = "scenario1_migration"
            logger.warning(f"Scenario 1 detected: {container_metrics['container_name']} - CPU={cpu:.1f}%, MEM={mem:.1f}%, NET={net_percent:.1f}%")
        elif (cpu > self.cpu_threshold or mem > self.memory_threshold) and net_percent > self.network_threshold_high:
            should_alert = True
            scenario = "scenario2_scaling"
            logger.warning(f"Scenario 2 detected: {container_metrics['container_name']} - CPU={cpu:.1f}%, MEM={mem:.1f}%, NET={net_percent:.1f}%")

        if should_alert:
            alert_data = {
                "timestamp": int(time.time()),
                "node": self.node_name,
                "container_id": container_metrics['container_id'],
                "container_name": container_metrics['container_name'],
                "service_name": container_metrics.get('service_name', ''),
                "scenario": scenario,
                "metrics": {
                    "cpu_percent": round(cpu, 2),
                    "memory_mb": container_metrics['memory_mb'],
                    "memory_percent": round(mem, 2),
                    "network_rx_mbps": round(net_in, 2),
                    "network_tx_mbps": round(net_out, 2),
                    "network_percent": round(net_percent, 2)
                }
            }
            await self.alert_sender.send_alert(alert_data)

    async def process_metrics(self, metrics: dict):
        node_metrics = metrics.get('node', {})
        containers = metrics.get('containers', [])
        timestamp = int(time.time())

        if node_metrics:
            node_line = (f"nodes,node={self.node_name} "
                        f"cpu={node_metrics['cpu_percent']:.2f},"
                        f"mem={node_metrics['memory_percent']:.2f},"
                        f"net_in={node_metrics['network_rx_mbps']:.3f},"
                        f"net_out={node_metrics['network_tx_mbps']:.3f} {timestamp}")
            self.metrics_batch.append(node_line)

        for container in containers:
            await self.check_thresholds_and_alert(container)
            container_line = (f"containers,node={self.node_name},"
                            f"container={container['container_name']},"
                            f"cid={container['container_id'][:12]} "
                            f"cpu={container['cpu_percent']:.2f},"
                            f"mem={container['memory_percent']:.2f},"
                            f"mem_mb={container['memory_mb']:.2f},"
                            f"net_in={container['network_rx_mbps']:.3f},"
                            f"net_out={container['network_tx_mbps']:.3f} {timestamp}")
            self.metrics_batch.append(container_line)

        current_time = time.time()
        if len(self.metrics_batch) >= self.batch_size or (current_time - self.last_flush) >= self.flush_interval:
            await self.flush_metrics()

    async def flush_metrics(self):
        if not self.metrics_batch:
            return
        success = await self.influxdb_writer.write_batch(self.metrics_batch)
        if success:
            logger.debug(f"Flushed {len(self.metrics_batch)} metrics to InfluxDB")
        else:
            logger.error(f"Failed to flush metrics to InfluxDB")
        self.metrics_batch = []
        self.last_flush = time.time()

    async def run(self):
        self.running = True
        logger.info(f"Starting monitoring agent on {self.node_name}")

        while self.running:
            try:
                loop_start = time.time()
                metrics = await self.metrics_collector.collect_metrics()
                await self.process_metrics(metrics)
                loop_duration = time.time() - loop_start
                sleep_time = max(0, self.poll_interval - loop_duration)
                if loop_duration > self.poll_interval:
                    logger.warning(f"Collection took {loop_duration:.2f}s (> {self.poll_interval}s)")
                await asyncio.sleep(sleep_time)
            except KeyboardInterrupt:
                break
            except Exception as e:
                logger.error(f"Error in monitoring loop: {e}", exc_info=True)
                await asyncio.sleep(5)

        await self.flush_metrics()
        logger.info("Monitoring agent stopped")


async def main():
    agent = MonitoringAgent()
    signal.signal(signal.SIGINT, agent.signal_handler)
    signal.signal(signal.SIGTERM, agent.signal_handler)
    await agent.run()


if __name__ == '__main__':
    asyncio.run(main())
