#!/usr/bin/env python3
"""
SwarmGuard Intelligent Load Balancer
Supports three algorithms: lease-based, metrics-based, and hybrid
"""

import asyncio
import time
import uuid
import os
import logging
from typing import Dict, List, Optional, Tuple
from collections import defaultdict
from aiohttp import web, ClientSession, ClientTimeout
import docker
import docker.transport

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class LeaseManager:
    """Manages leases for lease-based load balancing"""

    def __init__(self, lease_duration: int = 30):
        self.lease_duration = lease_duration
        # Structure: {replica_id: [{'id': 'req-123', 'expires_at': timestamp}, ...]}
        self.active_leases: Dict[str, List[Dict]] = defaultdict(list)
        self.lock = asyncio.Lock()

    async def acquire_lease(self, replica_id: str) -> str:
        """Acquire a lease for a replica, returns lease ID"""
        async with self.lock:
            lease_id = str(uuid.uuid4())
            expires_at = time.time() + self.lease_duration

            self.active_leases[replica_id].append({
                'id': lease_id,
                'expires_at': expires_at,
                'acquired_at': time.time()
            })

            logger.debug(f"Lease {lease_id[:8]} acquired for {replica_id}, expires at {expires_at}")
            return lease_id

    async def release_lease(self, replica_id: str, lease_id: str):
        """Release a specific lease"""
        async with self.lock:
            if replica_id in self.active_leases:
                self.active_leases[replica_id] = [
                    lease for lease in self.active_leases[replica_id]
                    if lease['id'] != lease_id
                ]
                logger.debug(f"Lease {lease_id[:8]} released for {replica_id}")

    async def cleanup_expired_leases(self):
        """Remove all expired leases"""
        async with self.lock:
            now = time.time()
            expired_count = 0

            for replica_id in list(self.active_leases.keys()):
                before_count = len(self.active_leases[replica_id])
                self.active_leases[replica_id] = [
                    lease for lease in self.active_leases[replica_id]
                    if lease['expires_at'] > now
                ]
                after_count = len(self.active_leases[replica_id])
                expired_count += (before_count - after_count)

                # Remove replica entry if no leases
                if not self.active_leases[replica_id]:
                    del self.active_leases[replica_id]

            if expired_count > 0:
                logger.debug(f"Cleaned up {expired_count} expired leases")

    def get_lease_count(self, replica_id: str) -> int:
        """Get number of active leases for a replica"""
        return len(self.active_leases.get(replica_id, []))

    def get_all_lease_counts(self) -> Dict[str, int]:
        """Get lease counts for all replicas"""
        return {replica_id: len(leases) for replica_id, leases in self.active_leases.items()}


class LoadBalancer:
    """Intelligent load balancer with multiple routing algorithms"""

    def __init__(self):
        # Configuration from environment variables
        self.worker_nodes = os.getenv('WORKER_NODES', 'worker-1,worker-2,worker-3').split(',')
        self.lb_port = int(os.getenv('LB_PORT', '8081'))
        self.target_service = os.getenv('TARGET_SERVICE', 'web-stress')

        # Algorithm selection
        self.algorithm = os.getenv('LB_ALGORITHM', 'lease')

        # Lease configuration
        self.lease_duration = int(os.getenv('LEASE_DURATION', '30'))
        self.lease_cleanup_interval = int(os.getenv('LEASE_CLEANUP_INTERVAL', '1'))
        self.lease_manager = LeaseManager(self.lease_duration)

        # Metrics configuration
        self.metrics_port = int(os.getenv('METRICS_PORT', '8082'))
        self.cache_ttl = int(os.getenv('CACHE_TTL', '1'))
        self.cpu_weight = float(os.getenv('CPU_WEIGHT', '0.5'))
        self.memory_weight = float(os.getenv('MEMORY_WEIGHT', '0.3'))
        self.network_weight = float(os.getenv('NETWORK_WEIGHT', '0.2'))

        # Hybrid configuration
        self.lease_count_weight = float(os.getenv('LEASE_COUNT_WEIGHT', '10.0'))

        # Health & fallback
        self.health_check_interval = int(os.getenv('HEALTH_CHECK_INTERVAL', '5'))
        self.fallback_enabled = os.getenv('FALLBACK_ENABLED', 'true').lower() == 'true'

        # Logging
        self.debug_routing = os.getenv('DEBUG_ROUTING', 'false').lower() == 'true'
        self.log_every_n = int(os.getenv('LOG_EVERY_N_REQUESTS', '100'))

        # State
        self.metrics_cache: Dict = {}
        self.metrics_cache_timestamp = 0
        self.healthy_replicas: Dict[str, Dict] = {}
        self.round_robin_index = 0
        self.request_count = 0

        # Docker client - connect to Docker daemon
        try:
            socket_path = '/var/run/docker.sock'

            # Check if socket exists
            if not os.path.exists(socket_path):
                raise Exception(f"Docker socket not found at {socket_path}")

            logger.info(f"Docker socket found at {socket_path}")

            # Use docker.from_env() which reads DOCKER_HOST from environment
            # We already set DOCKER_HOST=unix:///var/run/docker.sock in deployment
            self.docker_client = docker.from_env()

            # Test connection
            self.docker_client.ping()
            logger.info("Docker client connected successfully")
        except Exception as e:
            logger.warning(f"Docker client not available: {e}")
            logger.exception("Full traceback:")
            self.docker_client = None

        logger.info(f"Load Balancer initialized with algorithm: {self.algorithm}")
        logger.info(f"Worker nodes: {self.worker_nodes}")
        logger.info(f"Target service: {self.target_service}")

    async def start_background_tasks(self):
        """Start background tasks"""
        # Lease cleanup task
        asyncio.create_task(self.lease_cleanup_loop())

        # Health check task
        asyncio.create_task(self.health_check_loop())

        # Metrics cache refresh (for metrics and hybrid algorithms)
        if self.algorithm in ['metrics', 'hybrid']:
            asyncio.create_task(self.metrics_refresh_loop())

    async def lease_cleanup_loop(self):
        """Periodically clean up expired leases"""
        while True:
            try:
                await self.lease_manager.cleanup_expired_leases()
            except Exception as e:
                logger.error(f"Error in lease cleanup: {e}")
            await asyncio.sleep(self.lease_cleanup_interval)

    async def health_check_loop(self):
        """Periodically check health of all replicas"""
        while True:
            try:
                await self.discover_and_check_replicas()
            except Exception as e:
                logger.error(f"Error in health check: {e}")
            await asyncio.sleep(self.health_check_interval)

    async def metrics_refresh_loop(self):
        """Periodically refresh metrics cache"""
        while True:
            try:
                await self.fetch_all_metrics()
            except Exception as e:
                logger.error(f"Error refreshing metrics: {e}")
            await asyncio.sleep(self.cache_ttl)

    async def discover_and_check_replicas(self):
        """Discover service replicas and check their health"""
        if not self.docker_client:
            logger.warning("Docker client not available, using static replica list")
            return

        try:
            # Get service - try exact match first, then fallback to list all
            try:
                service = self.docker_client.services.get(self.target_service)
            except docker.errors.NotFound:
                # Fallback: list all services and find by name
                all_services = self.docker_client.services.list()
                matching = [s for s in all_services if s.name == self.target_service]
                if not matching:
                    logger.warning(f"Service {self.target_service} not found")
                    return
                service = matching[0]
            tasks = service.tasks(filters={'desired-state': 'running'})

            new_replicas = {}
            async with ClientSession(timeout=ClientTimeout(total=2)) as session:
                for task in tasks:
                    task_id = task['ID'][:12]
                    node_id = task['NodeID']

                    # Get node info
                    try:
                        node = self.docker_client.nodes.get(node_id)
                        node_hostname = node.attrs['Description']['Hostname']

                        # Get container IP from task networks
                        networks = task.get('NetworksAttachments', [])
                        container_ip = None
                        for network in networks:
                            addresses = network.get('Addresses', [])
                            if addresses:
                                container_ip = addresses[0].split('/')[0]
                                break

                        if not container_ip:
                            continue

                        # Check health
                        health_url = f"http://{container_ip}:8080/health"
                        try:
                            async with session.get(health_url) as resp:
                                is_healthy = resp.status == 200
                        except:
                            is_healthy = False

                        replica_id = f"{node_hostname}:{self.target_service}.{task_id}"
                        new_replicas[replica_id] = {
                            'node': node_hostname,
                            'task_id': task_id,
                            'container_ip': container_ip,
                            'healthy': is_healthy
                        }

                    except Exception as e:
                        logger.error(f"Error processing task {task_id}: {e}")

            self.healthy_replicas = {k: v for k, v in new_replicas.items() if v['healthy']}
            logger.debug(f"Discovered {len(self.healthy_replicas)} healthy replicas")

        except Exception as e:
            logger.error(f"Error discovering replicas: {e}")

    async def fetch_all_metrics(self):
        """Fetch metrics from all monitoring-agents"""
        if not self.worker_nodes:
            return

        new_cache = {}
        async with ClientSession(timeout=ClientTimeout(total=2)) as session:
            for worker in self.worker_nodes:
                try:
                    url = f"http://{worker}:{self.metrics_port}/metrics/containers"
                    async with session.get(url) as resp:
                        if resp.status == 200:
                            data = await resp.json()
                            for container in data.get('containers', []):
                                service_name = container.get('service_name')
                                if service_name == self.target_service:
                                    container_name = container.get('container_name', '')
                                    replica_id = f"{worker}:{container_name}"
                                    new_cache[replica_id] = container
                except Exception as e:
                    logger.debug(f"Error fetching metrics from {worker}: {e}")

        self.metrics_cache = new_cache
        self.metrics_cache_timestamp = time.time()
        logger.debug(f"Metrics cache updated with {len(new_cache)} replicas")

    async def select_replica_lease(self) -> Optional[Tuple[str, Dict, str]]:
        """Select replica using lease-based algorithm"""
        if not self.healthy_replicas:
            logger.warning("No healthy replicas available")
            return None

        # Get lease counts for all replicas
        lease_counts = {replica_id: self.lease_manager.get_lease_count(replica_id)
                       for replica_id in self.healthy_replicas.keys()}

        # Select replica with minimum leases
        min_replica = min(lease_counts.items(), key=lambda x: x[1])
        replica_id, lease_count = min_replica

        # Acquire lease
        lease_id = await self.lease_manager.acquire_lease(replica_id)

        if self.debug_routing:
            logger.info(f"[LEASE] Selected {replica_id} (leases: {lease_count}) - lease_id: {lease_id[:8]}")

        return replica_id, self.healthy_replicas[replica_id], lease_id

    async def select_replica_metrics(self) -> Optional[Tuple[str, Dict, None]]:
        """Select replica using metrics-based algorithm"""
        if not self.metrics_cache:
            logger.warning("Metrics cache empty, falling back to round-robin")
            return await self.select_replica_round_robin()

        # Calculate load scores
        scores = {}
        for replica_id, metrics in self.metrics_cache.items():
            if replica_id in self.healthy_replicas:
                cpu_pct = metrics.get('cpu_percent', 0)
                mem_pct = metrics.get('memory_percent', 0)
                # Simplified network percentage (assume max 100 Mbps)
                net_rx = metrics.get('network_rx_mbps', 0)
                net_tx = metrics.get('network_tx_mbps', 0)
                net_pct = ((net_rx + net_tx) / 100.0) * 100  # Normalize to percentage

                score = (cpu_pct * self.cpu_weight +
                        mem_pct * self.memory_weight +
                        net_pct * self.network_weight)
                scores[replica_id] = score

        if not scores:
            return await self.select_replica_round_robin()

        # Select replica with minimum score
        min_replica = min(scores.items(), key=lambda x: x[1])
        replica_id, score = min_replica

        if self.debug_routing:
            logger.info(f"[METRICS] Selected {replica_id} (score: {score:.2f})")

        return replica_id, self.healthy_replicas[replica_id], None

    async def select_replica_hybrid(self) -> Optional[Tuple[str, Dict, str]]:
        """Select replica using hybrid (lease + metrics) algorithm"""
        if not self.healthy_replicas:
            return None

        # Get lease counts
        lease_counts = {replica_id: self.lease_manager.get_lease_count(replica_id)
                       for replica_id in self.healthy_replicas.keys()}

        # Calculate hybrid scores
        scores = {}
        for replica_id in self.healthy_replicas.keys():
            # Lease component
            lease_count = lease_counts.get(replica_id, 0)
            lease_score = lease_count * self.lease_count_weight

            # Metrics component
            metrics = self.metrics_cache.get(replica_id, {})
            cpu_pct = metrics.get('cpu_percent', 0)
            mem_pct = metrics.get('memory_percent', 0)
            net_rx = metrics.get('network_rx_mbps', 0)
            net_tx = metrics.get('network_tx_mbps', 0)
            net_pct = ((net_rx + net_tx) / 100.0) * 100

            metrics_score = (cpu_pct * self.cpu_weight +
                           mem_pct * self.memory_weight +
                           net_pct * self.network_weight)

            # Combined score
            total_score = lease_score + metrics_score
            scores[replica_id] = total_score

        # Select replica with minimum score
        min_replica = min(scores.items(), key=lambda x: x[1])
        replica_id, score = min_replica

        # Acquire lease
        lease_id = await self.lease_manager.acquire_lease(replica_id)

        if self.debug_routing:
            leases = lease_counts.get(replica_id, 0)
            logger.info(f"[HYBRID] Selected {replica_id} (score: {score:.2f}, leases: {leases}) - lease_id: {lease_id[:8]}")

        return replica_id, self.healthy_replicas[replica_id], lease_id

    async def select_replica_round_robin(self) -> Optional[Tuple[str, Dict, None]]:
        """Fallback round-robin selection"""
        if not self.healthy_replicas:
            return None

        replicas = list(self.healthy_replicas.items())
        replica_id, replica_info = replicas[self.round_robin_index % len(replicas)]
        self.round_robin_index += 1

        if self.debug_routing:
            logger.info(f"[ROUND-ROBIN] Selected {replica_id}")

        return replica_id, replica_info, None

    async def select_replica(self) -> Optional[Tuple[str, Dict, Optional[str]]]:
        """Select replica based on configured algorithm"""
        if self.algorithm == 'lease':
            return await self.select_replica_lease()
        elif self.algorithm == 'metrics':
            return await self.select_replica_metrics()
        elif self.algorithm == 'hybrid':
            return await self.select_replica_hybrid()
        elif self.algorithm == 'round-robin':
            return await self.select_replica_round_robin()
        else:
            logger.error(f"Unknown algorithm: {self.algorithm}, using round-robin")
            return await self.select_replica_round_robin()

    async def proxy_request(self, request: web.Request) -> web.Response:
        """Proxy incoming request to selected replica"""
        self.request_count += 1

        # Log periodically
        if self.request_count % self.log_every_n == 0:
            lease_counts = self.lease_manager.get_all_lease_counts()
            logger.info(f"Processed {self.request_count} requests. Active leases: {lease_counts}")

        # Select replica
        selection = await self.select_replica()
        if not selection:
            return web.Response(status=503, text="No healthy replicas available")

        replica_id, replica_info, lease_id = selection
        container_ip = replica_info['container_ip']

        # Proxy the request
        target_url = f"http://{container_ip}:8080{request.path_qs}"

        try:
            async with ClientSession(timeout=ClientTimeout(total=30)) as session:
                async with session.request(
                    method=request.method,
                    url=target_url,
                    headers={k: v for k, v in request.headers.items()
                            if k.lower() not in ['host', 'connection']},
                    data=await request.read()
                ) as resp:
                    body = await resp.read()
                    response = web.Response(
                        status=resp.status,
                        body=body,
                        headers={k: v for k, v in resp.headers.items()
                                if k.lower() not in ['connection', 'transfer-encoding']}
                    )
        except Exception as e:
            logger.error(f"Error proxying request to {replica_id}: {e}")
            response = web.Response(status=502, text=f"Bad Gateway: {str(e)}")
        finally:
            # Release lease if applicable
            if lease_id:
                await self.lease_manager.release_lease(replica_id, lease_id)

        return response

    async def health_handler(self, request: web.Request) -> web.Response:
        """Health check endpoint"""
        return web.json_response({
            'status': 'healthy',
            'algorithm': self.algorithm,
            'healthy_replicas': len(self.healthy_replicas),
            'total_requests': self.request_count
        })

    async def metrics_handler(self, request: web.Request) -> web.Response:
        """Metrics endpoint"""
        lease_counts = self.lease_manager.get_all_lease_counts()

        # Calculate request distribution
        # Note: This would require tracking per-replica request counts

        return web.json_response({
            'total_requests': self.request_count,
            'algorithm': self.algorithm,
            'healthy_replicas': len(self.healthy_replicas),
            'active_leases': lease_counts,
            'replica_details': self.healthy_replicas
        })

    async def run(self):
        """Run the load balancer"""
        # Start background tasks
        await self.start_background_tasks()

        # Initial replica discovery
        await self.discover_and_check_replicas()

        # Setup web application
        app = web.Application()
        app.router.add_route('*', '/health', self.health_handler)
        app.router.add_route('GET', '/metrics', self.metrics_handler)
        app.router.add_route('*', '/{path:.*}', self.proxy_request)

        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, '0.0.0.0', self.lb_port)

        logger.info(f"Load Balancer starting on port {self.lb_port}")
        await site.start()

        # Keep running
        while True:
            await asyncio.sleep(3600)


async def main():
    """Main entry point"""
    lb = LoadBalancer()
    await lb.run()


if __name__ == '__main__':
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Load Balancer stopped")
