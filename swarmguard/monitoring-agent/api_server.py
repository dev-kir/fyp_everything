#!/usr/bin/env python3
"""
HTTP API Server for Monitoring Agent
Exposes container metrics for load balancer to query
"""

import logging
from aiohttp import web

logger = logging.getLogger(__name__)


class MetricsAPIServer:
    """HTTP API server for exposing metrics"""

    def __init__(self, port: int = 8082):
        self.port = port
        self.app = None
        self.runner = None
        self.site = None
        self.get_metrics_func = None
        logger.info(f"Metrics API server initialized on port {port}")

    async def metrics_handler(self, request: web.Request) -> web.Response:
        """Handle GET /metrics/containers"""
        if not self.get_metrics_func:
            return web.json_response({'error': 'Metrics not available'}, status=503)

        try:
            # Get latest metrics from the monitoring agent
            metrics = self.get_metrics_func()

            # Format response
            response_data = {
                'node': metrics.get('node_name', 'unknown'),
                'timestamp': metrics.get('timestamp', 0),
                'containers': metrics.get('containers', [])
            }

            return web.json_response(response_data)

        except Exception as e:
            logger.error(f"Error in metrics handler: {e}")
            return web.json_response({'error': str(e)}, status=500)

    async def health_handler(self, request: web.Request) -> web.Response:
        """Health check endpoint"""
        return web.json_response({'status': 'healthy'})

    async def start(self, get_metrics_func):
        """Start the API server"""
        self.get_metrics_func = get_metrics_func

        # Create aiohttp app
        self.app = web.Application()
        self.app.router.add_get('/metrics/containers', self.metrics_handler)
        self.app.router.add_get('/health', self.health_handler)

        # Setup and start server
        self.runner = web.AppRunner(self.app)
        await self.runner.setup()
        self.site = web.TCPSite(self.runner, '0.0.0.0', self.port)
        await self.site.start()

        logger.info(f"Metrics API server started on port {self.port}")

    async def stop(self):
        """Stop the API server"""
        if self.site:
            await self.site.stop()
        if self.runner:
            await self.runner.cleanup()
        logger.info("Metrics API server stopped")
