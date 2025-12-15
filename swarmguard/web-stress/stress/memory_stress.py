#!/usr/bin/env python3
"""Memory Stressor - Gradual memory allocation"""

import time
import logging
from threading import Event

logger = logging.getLogger(__name__)


class MemoryStressor:
    def __init__(self):
        self.active = False
        self.allocated_memory = []
        self.stop_event = Event()

    def start_stress(self, target_mb: int, duration_seconds: int, ramp_seconds: int):
        # DO NOT STOP - allow memory to accumulate across requests
        if not self.active:
            self.active = True
            self.stop_event.clear()

        current_mb = len(self.allocated_memory) * 10  # chunk_size_mb = 10
        logger.info(f"Memory stress - current: {current_mb}MB, adding: {target_mb}MB")

        try:
            chunk_size_mb = 10
            total_chunks = target_mb // chunk_size_mb
            chunks_per_step = max(1, total_chunks // ramp_seconds)

            logger.info(f"Adding memory: +{target_mb}MB (ramp={ramp_seconds}s)")

            # Allocate immediately (ramp_seconds is now ignored for simplicity)
            for _ in range(total_chunks):
                if self.stop_event.is_set():
                    logger.info(f"Memory stress stopped at {len(self.allocated_memory) * chunk_size_mb}MB")
                    return

                try:
                    chunk = bytearray(chunk_size_mb * 1024 * 1024)
                    for i in range(0, len(chunk), 4096):
                        chunk[i] = 1
                    self.allocated_memory.append(chunk)
                except MemoryError:
                    logger.error(f"MemoryError: Cannot allocate more memory at {len(self.allocated_memory) * chunk_size_mb}MB")
                    return

            final_mb = len(self.allocated_memory) * chunk_size_mb
            logger.info(f"Memory allocated: {final_mb}MB total (will persist until explicit stop)")
            # DO NOT auto-release after duration - memory should persist
            # Only release on explicit stop() call
        except Exception as e:
            logger.error(f"Memory stress error: {e}", exc_info=True)

    def stop(self):
        self.stop_event.set()
        self.allocated_memory.clear()
        self.active = False
        logger.info("Memory stress stopped")
