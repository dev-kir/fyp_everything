#!/usr/bin/env python3
"""CPU Stressor - Gradual CPU load generation"""

import time
import logging
from threading import Thread, Event

logger = logging.getLogger(__name__)


class CPUStressor:
    def __init__(self):
        self.active = False
        self.stop_event = Event()
        self.workers = []

    def cpu_burn(self, target_percent: float, stop_event: Event):
        """Burn CPU cycles to achieve target percentage"""
        while not stop_event.is_set():
            start_time = time.time()
            # Busy-wait for target_percent of each second
            end_time = start_time + (target_percent / 100.0)
            while time.time() < end_time:
                # More intensive calculation - compute primes
                for i in range(10000):
                    _ = i ** 2 * i ** 3 / (i + 1)
            # Sleep for the remaining time
            sleep_time = max(0, 1.0 - (time.time() - start_time))
            if sleep_time > 0:
                time.sleep(sleep_time)

    def start_stress(self, target_percent: int, duration_seconds: int, ramp_seconds: int):
        self.stop()
        self.active = True
        self.stop_event.clear()

        try:
            # Spawn workers immediately - each targeting full load
            # Number of workers = target_percent / 100 * CPU cores (but at least 2 for visibility)
            import multiprocessing
            num_cores = multiprocessing.cpu_count()
            num_workers = max(2, int((target_percent / 100.0) * num_cores))

            logger.info(f"Starting {num_workers} CPU workers for {target_percent}% target")

            # Start all workers at once
            for _ in range(num_workers):
                worker = Thread(target=self.cpu_burn, args=(100.0, self.stop_event))
                worker.daemon = True
                worker.start()
                self.workers.append(worker)

            logger.info(f"CPU stress maintaining {target_percent}% for {duration_seconds}s")
            time.sleep(duration_seconds)
        finally:
            self.stop()

    def stop(self):
        self.stop_event.set()
        for worker in self.workers:
            worker.join(timeout=2)
        self.workers = []
        self.active = False
        logger.info("CPU stress stopped")
