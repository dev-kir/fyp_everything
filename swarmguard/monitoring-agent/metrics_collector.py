#!/usr/bin/env python3
"""Metrics Collector - Collects CPU, memory, network from Docker"""

import os
import time
import logging
from typing import Dict
import docker
import psutil

logger = logging.getLogger(__name__)


class MetricsCollector:
    def __init__(self, node_name: str, net_iface: str):
        self.node_name = node_name
        self.net_iface = net_iface
        self.docker_client = docker.DockerClient(base_url='unix://var/run/docker.sock')
        self.prev_net_stats = {}
        self.prev_timestamp = time.time()
        logger.info("Docker client initialized")

    async def collect_metrics(self) -> Dict:
        current_time = time.time()
        time_delta = current_time - self.prev_timestamp
        node_metrics = self.get_node_metrics(time_delta)
        container_metrics = []

        try:
            containers = self.docker_client.containers.list()
            for container in containers:
                try:
                    metrics = self.get_container_metrics(container, time_delta)
                    if metrics:
                        container_metrics.append(metrics)
                except Exception as e:
                    logger.error(f"Error collecting metrics for {container.id[:12]}: {e}")
        except Exception as e:
            logger.error(f"Error listing containers: {e}")

        self.prev_timestamp = current_time
        return {"node": node_metrics, "containers": container_metrics, "timestamp": int(current_time)}

    def get_node_metrics(self, time_delta: float) -> Dict:
        try:
            cpu_percent = psutil.cpu_percent(interval=0.1)
            mem = psutil.virtual_memory()

            # Read network stats from /sys/class/net (host's mounted /sys)
            net_stats = self.read_host_network_stats()

            if self.net_iface in net_stats:
                current_bytes_recv, current_bytes_sent = net_stats[self.net_iface]
                if self.net_iface in self.prev_net_stats:
                    prev_bytes_recv, prev_bytes_sent = self.prev_net_stats[self.net_iface]
                    bytes_recv_delta = current_bytes_recv - prev_bytes_recv
                    bytes_sent_delta = current_bytes_sent - prev_bytes_sent
                    rx_mbps = (bytes_recv_delta / time_delta) * 8 / 1_000_000 if time_delta > 0 else 0
                    tx_mbps = (bytes_sent_delta / time_delta) * 8 / 1_000_000 if time_delta > 0 else 0
                else:
                    rx_mbps = tx_mbps = 0
                self.prev_net_stats[self.net_iface] = (current_bytes_recv, current_bytes_sent)
            else:
                rx_mbps = tx_mbps = 0
                logger.warning(f"Network interface {self.net_iface} not found in /sys/class/net")

            return {"cpu_percent": cpu_percent, "memory_percent": mem.percent, "network_rx_mbps": rx_mbps, "network_tx_mbps": tx_mbps}
        except Exception as e:
            logger.error(f"Error collecting node metrics: {e}")
            return {"cpu_percent": 0, "memory_percent": 0, "network_rx_mbps": 0, "network_tx_mbps": 0}

    def read_host_network_stats(self) -> Dict:
        """Read network stats from /sys/class/net (works with Docker network namespaces)"""
        stats = {}
        try:
            # /sys is mounted as /host/sys in the container
            net_dir = '/host/sys/class/net'
            for iface in os.listdir(net_dir):
                rx_path = f'{net_dir}/{iface}/statistics/rx_bytes'
                tx_path = f'{net_dir}/{iface}/statistics/tx_bytes'
                if os.path.exists(rx_path) and os.path.exists(tx_path):
                    try:
                        with open(rx_path) as f:
                            bytes_recv = int(f.read().strip())
                        with open(tx_path) as f:
                            bytes_sent = int(f.read().strip())
                        stats[iface] = (bytes_recv, bytes_sent)
                    except (ValueError, IOError) as e:
                        logger.debug(f"Could not read stats for {iface}: {e}")
        except Exception as e:
            logger.error(f"Error reading /sys/class/net: {e}")
        return stats

    def get_container_metrics(self, container, time_delta: float) -> Dict:
        try:
            stats = container.stats(stream=False)
            container_id = container.id
            container_name = container.name
            service_name = container.labels.get('com.docker.swarm.service.name', container_name)

            cpu_percent = self.calculate_cpu_percent(stats)
            memory_stats = self.calculate_memory_usage(stats)
            network_stats = self.calculate_network_usage(stats, container_id, time_delta)

            return {
                "container_id": container_id, "container_name": container_name, "service_name": service_name,
                "cpu_percent": cpu_percent, "memory_mb": memory_stats['usage_mb'],
                "memory_percent": memory_stats['usage_percent'],
                "network_rx_mbps": network_stats['rx_mbps'], "network_tx_mbps": network_stats['tx_mbps']
            }
        except Exception as e:
            logger.error(f"Error collecting container metrics: {e}")
            return None

    def calculate_cpu_percent(self, stats: Dict) -> float:
        try:
            cpu_stats = stats['cpu_stats']
            precpu_stats = stats['precpu_stats']
            cpu_delta = cpu_stats['cpu_usage']['total_usage'] - precpu_stats['cpu_usage']['total_usage']
            system_delta = cpu_stats['system_cpu_usage'] - precpu_stats['system_cpu_usage']
            cpu_count = cpu_stats.get('online_cpus', len(cpu_stats['cpu_usage'].get('percpu_usage', [1])))

            if system_delta > 0 and cpu_delta > 0:
                # Normalize to 0-100% by dividing by cpu_count
                cpu_percent = (cpu_delta / system_delta) * cpu_count * 100.0
                return min(cpu_percent / cpu_count, 100.0)
            return 0.0
        except:
            return 0.0

    def calculate_memory_usage(self, stats: Dict) -> Dict:
        try:
            mem_stats = stats['memory_stats']
            usage = mem_stats['usage']
            limit = mem_stats['limit']
            return {"usage_mb": usage / (1024 * 1024), "usage_percent": (usage / limit) * 100.0 if limit > 0 else 0.0}
        except:
            return {"usage_mb": 0.0, "usage_percent": 0.0}

    def calculate_network_usage(self, stats: Dict, container_id: str, time_delta: float) -> Dict:
        try:
            networks = stats.get('networks', {})
            total_rx = sum(net.get('rx_bytes', 0) for net in networks.values())
            total_tx = sum(net.get('tx_bytes', 0) for net in networks.values())

            if container_id in self.prev_net_stats:
                prev_rx, prev_tx = self.prev_net_stats[container_id]
                rx_mbps = max(0, ((total_rx - prev_rx) / time_delta) * 8 / 1_000_000 if time_delta > 0 else 0)
                tx_mbps = max(0, ((total_tx - prev_tx) / time_delta) * 8 / 1_000_000 if time_delta > 0 else 0)
            else:
                rx_mbps = tx_mbps = 0

            self.prev_net_stats[container_id] = (total_rx, total_tx)
            return {"rx_mbps": rx_mbps, "tx_mbps": tx_mbps}
        except:
            return {"rx_mbps": 0.0, "tx_mbps": 0.0}
