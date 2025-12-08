#!/usr/bin/env python3
"""InfluxDB Writer - Async batch writer"""

import logging
from typing import List
import aiohttp

logger = logging.getLogger(__name__)


class InfluxDBWriter:
    def __init__(self, influxdb_url: str, token: str):
        self.influxdb_url = influxdb_url
        self.token = token
        self.headers = {"Authorization": f"Token {token}", "Content-Type": "text/plain; charset=utf-8"}
        logger.info(f"InfluxDB writer initialized: {influxdb_url}")

    async def write_batch(self, lines: List[str]) -> bool:
        if not lines:
            return True

        payload = "\n".join(lines)
        try:
            timeout = aiohttp.ClientTimeout(total=2)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.post(self.influxdb_url, headers=self.headers, data=payload) as response:
                    if response.status == 204:
                        return True
                    else:
                        error_text = await response.text()
                        logger.error(f"InfluxDB write failed: HTTP {response.status} - {error_text}")
                        return False
        except aiohttp.ClientError as e:
            logger.error(f"InfluxDB connection error: {e}")
            return False
        except Exception as e:
            logger.error(f"InfluxDB write error: {e}")
            return False
