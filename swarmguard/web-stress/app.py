#!/usr/bin/env python3
"""SwarmGuard Web Stress Application - Controllable stress testing"""

import time
import logging
from fastapi import FastAPI, BackgroundTasks
import uvicorn

from stress.cpu_stress import CPUStressor
from stress.memory_stress import MemoryStressor
from stress.network_stress import NetworkStressor
from metrics import get_current_metrics

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="SwarmGuard Web Stress", version="1.0")

cpu_stressor = CPUStressor()
memory_stressor = MemoryStressor()
network_stressor = NetworkStressor()


@app.get("/health")
async def health():
    return {"status": "healthy", "uptime": time.time()}


@app.get("/metrics")
async def metrics():
    return get_current_metrics()


@app.get("/stress/cpu")
async def stress_cpu(target: int = 80, duration: int = 120, ramp: int = 30, background_tasks: BackgroundTasks = BackgroundTasks()):
    logger.info(f"CPU stress: target={target}%, duration={duration}s, ramp={ramp}s")
    background_tasks.add_task(cpu_stressor.start_stress, target, duration, ramp)
    return {"status": "started", "type": "cpu", "target_percent": target, "duration_seconds": duration, "ramp_seconds": ramp}


@app.get("/stress/memory")
async def stress_memory(target: int = 1024, duration: int = 120, ramp: int = 30, background_tasks: BackgroundTasks = BackgroundTasks()):
    logger.info(f"Memory stress: target={target}MB, duration={duration}s, ramp={ramp}s")
    background_tasks.add_task(memory_stressor.start_stress, target, duration, ramp)
    return {"status": "started", "type": "memory", "target_mb": target, "duration_seconds": duration, "ramp_seconds": ramp}


@app.get("/stress/network")
async def stress_network(bandwidth: int = 50, duration: int = 120, ramp: int = 30, background_tasks: BackgroundTasks = BackgroundTasks()):
    logger.info(f"Network stress: bandwidth={bandwidth}Mbps, duration={duration}s, ramp={ramp}s")
    background_tasks.add_task(network_stressor.start_stress, bandwidth, duration, ramp)
    return {"status": "started", "type": "network", "target_mbps": bandwidth, "duration_seconds": duration, "ramp_seconds": ramp}


@app.get("/stress/combined")
async def stress_combined(cpu: int = 80, memory: int = 1024, network: int = 50, duration: int = 120, ramp: int = 30, background_tasks: BackgroundTasks = BackgroundTasks()):
    logger.info(f"Combined stress: CPU={cpu}%, MEM={memory}MB, NET={network}Mbps, duration={duration}s, ramp={ramp}s")
    background_tasks.add_task(cpu_stressor.start_stress, cpu, duration, ramp)
    background_tasks.add_task(memory_stressor.start_stress, memory, duration, ramp)
    background_tasks.add_task(network_stressor.start_stress, network, duration, ramp)
    return {"status": "started", "type": "combined", "targets": {"cpu_percent": cpu, "memory_mb": memory, "network_mbps": network}, "duration_seconds": duration, "ramp_seconds": ramp}


@app.get("/stress/stop")
async def stop_stress():
    cpu_stressor.stop()
    memory_stressor.stop()
    network_stressor.stop()
    logger.info("All stress tests stopped")
    return {"status": "stopped", "stopped_tests": ["cpu", "memory", "network"]}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
