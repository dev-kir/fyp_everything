#!/usr/bin/env python3
"""Network Stressor - Gradual network traffic generation"""

import time
import logging
import socket
import os
from threading import Thread, Event, Lock

logger = logging.getLogger(__name__)


class NetworkStressor:
    def __init__(self):
        self.active = False
        self.stop_event = Event()
        self.workers = []
        self.current_mbps = 0
        self.mbps_lock = Lock()

    def generate_traffic(self, stop_event: Event):
        """Worker thread that generates traffic based on self.current_mbps"""
        # Try to find external gateway or use broadcast
        try:
            # Get default gateway or use broadcast address
            # This ensures traffic goes through the network interface being monitored
            target_ip = os.getenv('STRESS_TARGET_IP', '192.168.2.1')  # Default to gateway
            target_port = 9999
            logger.info(f"Network stress targeting {target_ip}:{target_port}")
        except:
            target_ip = '192.168.2.1'
            target_port = 9999

        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        chunk_size = 1024
        data = b'X' * chunk_size

        while not stop_event.is_set():
            try:
                with self.mbps_lock:
                    target_mbps = self.current_mbps

                if target_mbps > 0:
                    bytes_per_second = (target_mbps * 1_000_000) / 8
                    chunks_per_second = int(bytes_per_second / chunk_size)
                    delay = 1.0 / chunks_per_second if chunks_per_second > 0 else 1.0

                    sock.sendto(data, (target_ip, target_port))
                    time.sleep(delay)
                else:
                    time.sleep(0.1)  # Sleep when rate is 0
            except Exception as e:
                logger.error(f"Network stress error: {e}")
                time.sleep(0.1)
        sock.close()

    def start_stress(self, target_mbps: int, duration_seconds: int, ramp_seconds: int):
        self.stop()
        self.active = True
        self.stop_event.clear()

        try:
            # Start worker thread
            worker = Thread(target=self.generate_traffic, args=(self.stop_event,))
            worker.start()
            self.workers.append(worker)
            logger.info(f"Network stress worker started, ramping to {target_mbps}Mbps over {ramp_seconds}s")

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
