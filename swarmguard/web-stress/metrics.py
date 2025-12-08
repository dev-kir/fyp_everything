#!/usr/bin/env python3
"""Real-time metrics reporting"""

import psutil


def get_current_metrics():
    cpu_percent = psutil.cpu_percent(interval=0.1)
    mem = psutil.virtual_memory()
    net_io = psutil.net_io_counters()

    return {
        "cpu_percent": round(cpu_percent, 2),
        "memory_mb": round(mem.used / (1024 * 1024), 2),
        "memory_percent": round(mem.percent, 2),
        "network_bytes_sent": net_io.bytes_sent,
        "network_bytes_recv": net_io.bytes_recv
    }
