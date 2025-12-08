#!/usr/bin/env python3
"""Network Stressor - Gradual network traffic generation"""

import time
import logging
import socket
from threading import Thread, Event

logger = logging.getLogger(__name__)


class NetworkStressor:
    def __init__(self):
        self.active = False
        self.stop_event = Event()
        self.workers = []

    def generate_traffic(self, target_mbps: float, stop_event: Event):
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        bytes_per_second = (target_mbps * 1_000_000) / 8
        chunk_size = 1024
        chunks_per_second = int(bytes_per_second / chunk_size)
        delay = 1.0 / chunks_per_second if chunks_per_second > 0 else 1.0
        data = b'X' * chunk_size

        while not stop_event.is_set():
            try:
                sock.sendto(data, ('127.0.0.1', 9999))
                time.sleep(delay)
            except Exception as e:
                logger.error(f"Network stress error: {e}")
                break
        sock.close()

    def start_stress(self, target_mbps: int, duration_seconds: int, ramp_seconds: int):
        self.stop()
        self.active = True
        self.stop_event.clear()

        try:
            steps = ramp_seconds
            for step in range(steps + 1):
                if self.stop_event.is_set():
                    break

                current_mbps = (step / steps) * target_mbps
                if len(self.workers) == 0:
                    worker = Thread(target=self.generate_traffic, args=(current_mbps, self.stop_event))
                    worker.start()
                    self.workers.append(worker)
                time.sleep(1)

            logger.info(f"Network stress maintaining {target_mbps}Mbps for {duration_seconds}s")
            time.sleep(duration_seconds)
        finally:
            self.stop()

    def stop(self):
        self.stop_event.set()
        for worker in self.workers:
            worker.join(timeout=2)
        self.workers = []
        self.active = False
        logger.info("Network stress stopped")
