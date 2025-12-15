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
        logger.info(f"Memory stress: 0MB → {target_mb}MB over {ramp_seconds}s, hold for {duration_seconds}s")

        try:
            chunk_size_mb = 10
            total_chunks = target_mb // chunk_size_mb

            # Gradual ramp: allocate chunks over ramp_seconds
            if ramp_seconds > 0 and total_chunks > 0:
                delay_per_chunk = ramp_seconds / total_chunks
                logger.info(f"Ramping memory: {total_chunks} chunks over {ramp_seconds}s ({delay_per_chunk:.2f}s per chunk)")

                for i in range(total_chunks):
                    if self.stop_event.is_set():
                        logger.info(f"Memory stress stopped at {len(self.allocated_memory) * chunk_size_mb}MB")
                        return

                    try:
                        chunk = bytearray(chunk_size_mb * 1024 * 1024)
                        for j in range(0, len(chunk), 4096):
                            chunk[j] = 1
                        self.allocated_memory.append(chunk)

                        # Sleep between allocations for gradual ramp
                        if i < total_chunks - 1:  # Don't sleep after last chunk
                            time.sleep(delay_per_chunk)
                    except MemoryError:
                        logger.error(f"MemoryError: Cannot allocate more memory at {len(self.allocated_memory) * chunk_size_mb}MB")
                        return
            else:
                # No ramp, allocate immediately
                for _ in range(total_chunks):
                    if self.stop_event.is_set():
                        return
                    try:
                        chunk = bytearray(chunk_size_mb * 1024 * 1024)
                        for i in range(0, len(chunk), 4096):
                            chunk[i] = 1
                        self.allocated_memory.append(chunk)
                    except MemoryError:
                        logger.error(f"MemoryError: Cannot allocate more")
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
