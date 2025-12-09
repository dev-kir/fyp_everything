#!/usr/bin/env python3
"""CPU Stressor - Gradual CPU load generation"""

import time
import logging
import multiprocessing
from threading import Thread, Event

logger = logging.getLogger(__name__)


def cpu_burn_process(duration):
    """Burn 100% CPU in a separate process"""
    end_time = time.time() + duration
    while time.time() < end_time:
        # Maximum CPU burn - pure computation
        for _ in range(100000):
            _ = 2 ** 1000


class CPUStressor:
    def __init__(self):
        self.active = False
        self.processes = []

    def cpu_burn(self, target_percent: float, stop_event: Event):
        """Burn CPU cycles to achieve target percentage (legacy threading version)"""
        while not stop_event.is_set():
            start_time = time.time()
            # Busy-wait for target_percent of each second
            end_time = start_time + (target_percent / 100.0)
            while time.time() < end_time:
                # Maximum intensity calculation
                for _ in range(100000):
                    _ = 2 ** 1000
            # Sleep for the remaining time
            sleep_time = max(0, 1.0 - (time.time() - start_time))
            if sleep_time > 0:
                time.sleep(sleep_time)

    def start_stress(self, target_percent: int, duration_seconds: int, ramp_seconds: int):
        self.stop()
        self.active = True

        try:
            # Use multiprocessing for TRUE parallel CPU usage (bypasses Python GIL)
            num_cores = multiprocessing.cpu_count()
            # Calculate number of processes needed
            num_processes = max(1, int((target_percent / 100.0) * num_cores))

            logger.info(f"Starting {num_processes} CPU processes (cores={num_cores}) for {target_percent}% target")

            # Start CPU-burning processes
            for i in range(num_processes):
                p = multiprocessing.Process(target=cpu_burn_process, args=(duration_seconds + ramp_seconds,))
                p.start()
                self.processes.append(p)
                logger.info(f"Started CPU process {i+1}/{num_processes}")

            logger.info(f"CPU stress maintaining {target_percent}% for {duration_seconds}s")
            time.sleep(duration_seconds)
        finally:
            self.stop()

    def stop(self):
        logger.info(f"Stopping {len(self.processes)} CPU processes...")
        for p in self.processes:
            if p.is_alive():
                p.terminate()
                p.join(timeout=2)
                if p.is_alive():
                    p.kill()
        self.processes = []
        self.active = False
        logger.info("CPU stress stopped")
