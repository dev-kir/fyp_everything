#!/usr/bin/env python3
"""Network Stressor - Generate HTTP traffic for measurable network load"""

import time
import logging
import requests
from threading import Thread, Event, Lock

logger = logging.getLogger(__name__)


class NetworkStressor:
    def __init__(self):
        self.active = False
        self.stop_event = Event()
        self.workers = []
        self.current_mbps = 0
        self.mbps_lock = Lock()

    def generate_http_traffic(self, stop_event: Event):
        """Worker thread that generates HTTP traffic by uploading/downloading data"""
        # Target self (web-stress container) to generate measurable network traffic
        target_url = "http://127.0.0.1:8080/health"

        # Create payload for upload (1MB = generates ~8 Mbps per request if sent in 1 second)
        chunk_size = 1024 * 1024  # 1MB payload

        while not stop_event.is_set():
            try:
                with self.mbps_lock:
                    target_mbps = self.current_mbps

                if target_mbps > 0:
                    # Calculate requests per second needed to achieve target bandwidth
                    # 1MB payload = 8 Mbits, so for 70 Mbps we need ~9 requests/sec
                    requests_per_second = max(1, target_mbps / 8)
                    delay = 1.0 / requests_per_second

                    # Generate traffic by making HTTP request with large payload
                    try:
                        # POST with 1MB body generates upload traffic
                        # Response generates download traffic
                        data = b'X' * chunk_size
                        response = requests.post(target_url, data=data, timeout=2)
                    except:
                        pass  # Ignore errors, just keep generating traffic

                    time.sleep(delay)
                else:
                    time.sleep(0.1)

            except Exception as e:
                logger.error(f"Network stress error: {e}")
                time.sleep(0.1)

    def start_stress(self, target_mbps: int, duration_seconds: int, ramp_seconds: int):
        self.stop()
        self.active = True
        self.stop_event.clear()

        try:
            # Start 3 worker threads for parallel traffic generation
            num_workers = 3
            for i in range(num_workers):
                worker = Thread(target=self.generate_http_traffic, args=(self.stop_event,))
                worker.start()
                self.workers.append(worker)

            logger.info(f"Network stress: {num_workers} workers started, ramping to {target_mbps}Mbps over {ramp_seconds}s")

            # Ramp up traffic gradually
            steps = max(1, ramp_seconds)
            for step in range(steps + 1):
                if self.stop_event.is_set():
                    break

                with self.mbps_lock:
                    self.current_mbps = (step / steps) * target_mbps

                logger.info(f"Network stress: {self.current_mbps:.1f}Mbps (step {step}/{steps})")
                time.sleep(1)

            # Maintain target rate
            logger.info(f"Network stress maintaining {target_mbps}Mbps for {duration_seconds}s")
            time.sleep(duration_seconds)
        finally:
            self.stop()

    def stop(self):
        logger.info("Stopping network stress...")
        self.stop_event.set()
        with self.mbps_lock:
            self.current_mbps = 0
        for worker in self.workers:
            worker.join(timeout=2)
        self.workers = []
        self.active = False
        logger.info("Network stress stopped")
