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
        while not stop_event.is_set():
            start_time = time.time()
            while (time.time() - start_time) < (target_percent / 100.0):
                _ = sum(i * i for i in range(1000))
            time.sleep(max(0, 1 - (target_percent / 100.0)))

    def start_stress(self, target_percent: int, duration_seconds: int, ramp_seconds: int):
        self.stop()
        self.active = True
        self.stop_event.clear()

        try:
            steps = ramp_seconds
            for step in range(steps + 1):
                if self.stop_event.is_set():
                    break
                current_target = (step / steps) * target_percent
                desired_workers = max(1, int(current_target / 25))

                while len(self.workers) < desired_workers:
                    worker = Thread(target=self.cpu_burn, args=(current_target / desired_workers, self.stop_event))
                    worker.start()
                    self.workers.append(worker)
                time.sleep(1)

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
