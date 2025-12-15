#!/usr/bin/env python3
"""CPU Stressor - Gradual CPU load generation"""

import time
import logging
import multiprocessing
from threading import Thread, Event

logger = logging.getLogger(__name__)


def cpu_burn_process(target_percent, ramp_seconds, duration_seconds):
    """Burn CPU gradually ramping from 0% to target_percent over ramp_seconds"""
    start_time = time.time()
    end_time = start_time + duration_seconds

    while time.time() < end_time:
        elapsed = time.time() - start_time

        # Calculate current target percentage based on ramp
        if elapsed < ramp_seconds:
            # Gradual ramp: 0% → target_percent over ramp_seconds
            current_percent = (elapsed / ramp_seconds) * target_percent
        else:
            # After ramp, maintain target
            current_percent = target_percent

        # Burn CPU for current_percent of each second
        cycle_start = time.time()
        burn_duration = current_percent / 100.0

        # Busy loop for burn_duration seconds
        while (time.time() - cycle_start) < burn_duration:
            _ = 2 ** 1000

        # Sleep for the rest of the second
        sleep_time = max(0, 1.0 - (time.time() - cycle_start))
        if sleep_time > 0:
            time.sleep(sleep_time)


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
            # Use single process that gradually increases CPU from 0% to target%
            logger.info(f"Starting CPU stress: 0% → {target_percent}% over {ramp_seconds}s, hold for {duration_seconds}s")

            # Start single process with gradual ramp
            p = multiprocessing.Process(
                target=cpu_burn_process,
                args=(target_percent, ramp_seconds, duration_seconds)
            )
            p.start()
            self.processes.append(p)

            logger.info(f"CPU stress: ramping to {target_percent}% over {ramp_seconds}s")

            # Wait for the process to complete
            p.join()
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
