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
        if self.active:
            logger.warning("Memory stressor already active, stopping previous instance")
        self.stop()
        self.active = True
        self.stop_event.clear()

        try:
            chunk_size_mb = 10
            total_chunks = target_mb // chunk_size_mb
            chunks_per_step = max(1, total_chunks // ramp_seconds)

            logger.info(f"Starting memory allocation: target={target_mb}MB, ramp={ramp_seconds}s")

            for step in range(ramp_seconds):
                if self.stop_event.is_set():
                    logger.info(f"Memory stress stopped during ramp at {len(self.allocated_memory) * chunk_size_mb}MB")
                    break

                for _ in range(chunks_per_step):
                    try:
                        chunk = bytearray(chunk_size_mb * 1024 * 1024)
                        for i in range(0, len(chunk), 4096):
                            chunk[i] = 1
                        self.allocated_memory.append(chunk)
                    except MemoryError:
                        logger.error(f"MemoryError: Cannot allocate more memory at {len(self.allocated_memory) * chunk_size_mb}MB")
                        return

                current_mb = len(self.allocated_memory) * chunk_size_mb
                logger.info(f"Memory allocated: {current_mb}MB / {target_mb}MB")
                time.sleep(1)

            final_mb = len(self.allocated_memory) * chunk_size_mb
            logger.info(f"Memory stress maintaining {final_mb}MB for {duration_seconds}s")
            time.sleep(duration_seconds)
        except Exception as e:
            logger.error(f"Memory stress error: {e}", exc_info=True)
        finally:
            self.stop()

    def stop(self):
        self.stop_event.set()
        self.allocated_memory.clear()
        self.active = False
        logger.info("Memory stress stopped")
