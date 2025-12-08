#!/usr/bin/env python3
"""Alert Sender - Sends threshold breach alerts to recovery manager"""

import logging
import json
import asyncio
from typing import Dict
import aiohttp

logger = logging.getLogger(__name__)


class AlertSender:
    def __init__(self, recovery_manager_url: str):
        self.recovery_manager_url = f"{recovery_manager_url}/alert"
        self.headers = {"Content-Type": "application/json"}
        self.session = None
        logger.info(f"Alert sender initialized: {recovery_manager_url}")

    async def send_alert(self, alert_data: Dict) -> bool:
        try:
            payload = json.dumps(alert_data, separators=(',', ':'))
            if len(payload) > 500:
                logger.warning(f"Alert payload size {len(payload)} bytes exceeds 500 bytes")

            if self.session is None or self.session.closed:
                timeout = aiohttp.ClientTimeout(total=1)
                self.session = aiohttp.ClientSession(timeout=timeout)

            for attempt in range(2):
                try:
                    async with self.session.post(self.recovery_manager_url, headers=self.headers, data=payload) as response:
                        if response.status == 200:
                            logger.info(f"Alert sent: {alert_data['container_name']} - {alert_data['scenario']}")
                            return True
                        else:
                            error_text = await response.text()
                            logger.error(f"Recovery manager returned HTTP {response.status}: {error_text}")
                            return False
                except aiohttp.ClientError as e:
                    if attempt < 1:
                        logger.warning(f"Alert send failed (attempt {attempt + 1}), retrying...")
                        await asyncio.sleep(0.1)
                    else:
                        logger.error(f"Alert send failed after 2 attempts: {e}")
                        return False
        except Exception as e:
            logger.error(f"Error sending alert: {e}")
            return False

    async def close(self):
        if self.session and not self.session.closed:
            await self.session.close()
