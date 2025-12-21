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
        # Target via published port to force traffic through eth0 (not loopback)
        # Using master node IP ensures traffic goes through container's network interface
        target_url = "http://192.168.2.50:8080/health"

        # Use very small chunks sent continuously for smooth sustained traffic
        # 16KB chunks sent rapidly = smooth bandwidth curve
        chunk_size = 16 * 1024  # 16KB payload (very small for continuous flow)

        while not stop_event.is_set():
            try:
                with self.mbps_lock:
                    target_mbps = self.current_mbps

                if target_mbps > 0:
                    # Calculate the delay between requests to achieve target bandwidth
                    # 16KB = 0.128 Mbits, so for 10 Mbps we need ~78 requests/sec
                    # This means ~0.0128 second delay (12.8ms) - very rapid, very smooth
                    mbits_per_chunk = (chunk_size * 8) / (1024 * 1024)  # Convert to Mbits
                    chunks_per_second = target_mbps / mbits_per_chunk
                    delay = 1.0 / chunks_per_second if chunks_per_second > 0 else 0.1

                    # Generate traffic by making HTTP request with small payload
                    # Rapid fire small chunks = continuous smooth bandwidth
                    try:
                        data = b'X' * chunk_size
                        response = requests.post(target_url, data=data, timeout=2)
                    except:
                        pass  # Ignore errors, just keep generating traffic

                    # Very short sleep for continuous traffic
                    if delay > 0.01:  # Only sleep if delay is meaningful
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
