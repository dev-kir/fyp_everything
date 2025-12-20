#!/usr/bin/env python3
"""SwarmGuard Web Stress Application - Controllable stress testing"""

import time
import logging
from threading import Thread
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
async def stress_combined(cpu: int = 80, memory: int = 1024, network: int = 50, duration: int = 120, ramp: int = 30):
    logger.info(f"Combined stress: CPU={cpu}%, MEM={memory}MB, NET={network}Mbps, duration={duration}s, ramp={ramp}s")

    # Run all stressors in PARALLEL using threads (not sequential background tasks!)
    cpu_thread = Thread(target=cpu_stressor.start_stress, args=(cpu, duration, ramp), daemon=True)
    memory_thread = Thread(target=memory_stressor.start_stress, args=(memory, duration, ramp), daemon=True)
    network_thread = Thread(target=network_stressor.start_stress, args=(network, duration, ramp), daemon=True)

    cpu_thread.start()
    memory_thread.start()
    network_thread.start()

    logger.info("All 3 stressors started in parallel")
    return {"status": "started", "type": "combined", "targets": {"cpu_percent": cpu, "memory_mb": memory, "network_mbps": network}, "duration_seconds": duration, "ramp_seconds": ramp}


@app.get("/stress/stop")
async def stop_stress():
    cpu_stressor.stop()
    memory_stressor.stop()
    network_stressor.stop()
    logger.info("All stress tests stopped")
    return {"status": "stopped", "stopped_tests": ["cpu", "memory", "network"]}


@app.get("/compute/pi")
async def compute_pi(iterations: int = 1000000):
    """
    Calculate Pi using Monte Carlo method - CPU-intensive operation
    Used for generating distributed load across replicas
    """
    import random

    inside_circle = 0
    total_points = iterations

    for _ in range(total_points):
        x = random.random()
        y = random.random()

        if x*x + y*y <= 1:
            inside_circle += 1

    pi_estimate = (inside_circle / total_points) * 4

    return {
        "pi_estimate": pi_estimate,
        "iterations": iterations,
        "status": "completed"
    }


@app.get("/download/data")
async def download_data(size_mb: int = 10, cpu_work: int = 100000):
    """
    Generate and serve data payload for download - creates REAL network traffic

    Args:
        size_mb: Size of data to generate in MB (creates real network load)
        cpu_work: Number of Pi iterations to do while generating data (CPU load)

    This endpoint:
    - Generates real data that flows through Docker Swarm load balancer
    - Does CPU work (Pi calculation) while generating the payload
    - Consumes memory to hold the payload
    - Creates measurable network traffic when Alpine downloads it
    """
    import random
    from fastapi.responses import StreamingResponse
    import io

    # Do CPU-intensive work (Pi calculation)
    inside_circle = 0
    for _ in range(cpu_work):
        x = random.random()
        y = random.random()
        if x*x + y*y <= 1:
            inside_circle += 1

    # Generate data payload (creates memory + network load)
    # Each MB = 1,048,576 bytes
    chunk_size = 1024 * 1024  # 1 MB chunks

    def generate_data():
        for _ in range(size_mb):
            # Generate random data chunk
            yield b'X' * chunk_size

    return StreamingResponse(
        generate_data(),
        media_type="application/octet-stream",
        headers={
            "Content-Disposition": f"attachment; filename=data_{size_mb}mb.bin",
            "X-CPU-Work": str(cpu_work),
            "X-Data-Size": f"{size_mb}MB"
        }
    )


@app.get("/stress/incremental")
async def incremental_stress(
    cpu: int = 2,        # CPU% to ADD per request
    memory: int = 50,    # MB to ADD per request
    network: int = 5,    # Mbps to ADD per request
    duration: int = 120, # How long to hold resources
    ramp: int = 60       # Ramp-up time in seconds
):
    """
    Incremental stress endpoint - each request ADDS load instead of setting absolute targets.

    This allows simulating N users where aggregate load = N × per-request contribution.

    Example: 40 users each call /stress/incremental?cpu=2&memory=50&network=5&duration=120&ramp=60
    Result: 80% CPU, 2000MB RAM, 200Mbps network (aggregate)

    Each request runs in background thread and auto-releases after duration.
    """
    import requests

    def run_incremental_stress():
        try:
            # Allocate memory
            allocated_memory = []
            chunk_size_mb = 10
            total_chunks = memory // chunk_size_mb
            chunks_per_step = max(1, total_chunks // ramp) if ramp > 0 else total_chunks

            # CPU burn function with gradual ramp
            def cpu_burn(target_percent, stop_at, ramp_duration):
                start_time = time.time()
                while time.time() < stop_at:
                    elapsed = time.time() - start_time

                    # Gradual ramp from 0% → target_percent over ramp_duration
                    if elapsed < ramp_duration:
                        current_percent = (elapsed / ramp_duration) * target_percent
                    else:
                        current_percent = target_percent

                    # Burn CPU for current_percent of each second
                    cycle_start = time.time()
                    burn_duration = current_percent / 100.0

                    # CPU-intensive work (prevent optimization)
                    result = 0
                    while time.time() - cycle_start < burn_duration:
                        for _ in range(10000):
                            result += (_ * 0.5) ** 2  # Force actual computation

                    sleep_time = max(0, 1.0 - (time.time() - cycle_start))
                    if sleep_time > 0:
                        time.sleep(sleep_time)

            # Network traffic function
            def network_traffic(mbps, stop_at):
                target_url = "http://192.168.2.50:8080/health"
                chunk_size = 1024 * 1024  # 1MB
                while time.time() < stop_at:
                    try:
                        requests_per_sec = max(1, mbps / 8)
                        delay = 1.0 / requests_per_sec
                        data = b'X' * chunk_size
                        requests.post(target_url, data=data, timeout=2)
                        time.sleep(delay)
                    except:
                        pass

            stop_time = time.time() + duration

            # Ramp up memory gradually
            if ramp > 0:
                for step in range(ramp):
                    if time.time() >= stop_time:
                        break
                    for _ in range(chunks_per_step):
                        try:
                            chunk = bytearray(chunk_size_mb * 1024 * 1024)
                            for i in range(0, len(chunk), 4096):
                                chunk[i] = 1
                            allocated_memory.append(chunk)
                        except MemoryError:
                            break
                    time.sleep(1)
            else:
                # No ramp, allocate immediately
                for _ in range(total_chunks):
                    try:
                        chunk = bytearray(chunk_size_mb * 1024 * 1024)
                        for i in range(0, len(chunk), 4096):
                            chunk[i] = 1
                        allocated_memory.append(chunk)
                    except MemoryError:
                        break

            # Start CPU and network threads
            cpu_thread = Thread(target=cpu_burn, args=(cpu, stop_time, ramp))
            network_thread = Thread(target=network_traffic, args=(network, stop_time))

            cpu_thread.start()
            network_thread.start()

            # Wait for duration
            time.sleep(duration)

            # Cleanup
            cpu_thread.join(timeout=2)
            network_thread.join(timeout=2)
            allocated_memory.clear()

        except Exception as e:
            logger.error(f"Incremental stress error: {e}")

    # Run in background thread
    thread = Thread(target=run_incremental_stress, daemon=True)
    thread.start()

    return {
        "status": "started",
        "cpu_add": f"{cpu}%",
        "memory_add": f"{memory}MB",
        "network_add": f"{network}Mbps",
        "duration": f"{duration}s",
        "ramp": f"{ramp}s",
        "message": "Incremental stress running in background"
    }


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
