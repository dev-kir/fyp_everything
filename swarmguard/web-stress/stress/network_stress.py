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
        """Worker thread that generates HTTP traffic by downloading large files"""
        # Target via published port to force traffic through eth0 (not loopback)
        # Using master node IP ensures traffic goes through container's network interface
        base_url = "http://192.168.2.50:8080"

        # Use large downloads for sustained bandwidth
        # Calculate download size based on target bandwidth to ensure continuous transfers

        while not stop_event.is_set():
            try:
                with self.mbps_lock:
                    target_mbps = self.current_mbps

                if target_mbps > 0:
                    # Calculate download size to sustain bandwidth for ~10 seconds
                    # This ensures overlapping transfers when multiple workers run
                    # target_mbps * 10 seconds / 8 bits per byte = MB to download
                    download_mb = max(5, int(target_mbps * 10 / 8))

                    # Download large file to sustain bandwidth
                    # At 10 Mbps: downloads 12.5 MB, takes ~10 seconds
                    # Multiple workers create overlapping downloads = sustained traffic
                    try:
                        download_url = f"{base_url}/download/data?size_mb={download_mb}&cpu_work=0"
                        response = requests.get(download_url, timeout=30, stream=True)

                        # Consume the stream to ensure full download
                        # This creates REAL network traffic measured by monitoring agents
                        for chunk in response.iter_content(chunk_size=1024*1024):  # 1MB chunks
                            if stop_event.is_set():
                                break

                        logger.debug(f"Downloaded {download_mb}MB at target {target_mbps}Mbps")
                    except Exception as e:
                        logger.debug(f"Download error: {e}")
                        time.sleep(1)

                    # Brief pause before next download (allows ramping control)
                    time.sleep(1)
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
