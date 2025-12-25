#!/usr/bin/env python3
"""
System Overhead Analysis Script
Analyzes resource usage overhead of SwarmGuard components
"""

import csv
import statistics
from pathlib import Path

def load_measurements(csv_file):
    """Load measurements from CSV file"""
    measurements = {'master': [], 'worker-1': [], 'worker-2': [], 'worker-3': [], 'worker-4': []}

    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            node = row['node']
            cpu = float(row['cpu_percent'])
            mem = float(row['memory_mb'])
            measurements[node].append({'cpu': cpu, 'memory': mem})

    return measurements

def calculate_stats(measurements):
    """Calculate average CPU and Memory per node"""
    stats = {}
    for node, data in measurements.items():
        if data:
            cpu_vals = [d['cpu'] for d in data]
            mem_vals = [d['memory'] for d in data]
            stats[node] = {
                'cpu_mean': statistics.mean(cpu_vals),
                'cpu_stdev': statistics.stdev(cpu_vals) if len(cpu_vals) > 1 else 0,
                'mem_mean': statistics.mean(mem_vals),
                'mem_stdev': statistics.stdev(mem_vals) if len(mem_vals) > 1 else 0
            }
    return stats

def main():
    data_dir = Path(__file__).parent.parent / "data" / "overhead"

    if not data_dir.exists():
        # Fallback to RESULT_FYP_EVERYTHING
        data_dir = Path("/Users/amirmuz/RESULT_FYP_EVERYTHING/overhead")

    print("="*60)
    print("SYSTEM OVERHEAD ANALYSIS")
    print("="*60)
    print()

    # Load measurements
    print("Loading measurements...")
    baseline = load_measurements(data_dir / "overhead_baseline.csv")
    monitoring = load_measurements(data_dir / "overhead_monitoring_only.csv")
    full = load_measurements(data_dir / "overhead_full_swarmguard.csv")

    # Calculate stats
    baseline_stats = calculate_stats(baseline)
    monitoring_stats = calculate_stats(monitoring)
    full_stats = calculate_stats(full)

    # Calculate cluster-wide totals
    def cluster_total(stats):
        cpu_total = sum(s['cpu_mean'] for s in stats.values())
        mem_total = sum(s['mem_mean'] for s in stats.values())
        return cpu_total, mem_total

    base_cpu, base_mem = cluster_total(baseline_stats)
    mon_cpu, mon_mem = cluster_total(monitoring_stats)
    full_cpu, full_mem = cluster_total(full_stats)

    # Calculate overhead
    monitoring_cpu_overhead = mon_cpu - base_cpu
    monitoring_mem_overhead = mon_mem - base_mem

    recovery_cpu_overhead = full_cpu - mon_cpu
    recovery_mem_overhead = full_mem - mon_mem

    total_cpu_overhead = full_cpu - base_cpu
    total_mem_overhead = full_mem - base_mem

    # Calculate percentages
    monitoring_cpu_pct = (monitoring_cpu_overhead / base_cpu) * 100 if base_cpu > 0 else 0
    monitoring_mem_pct = (monitoring_mem_overhead / base_mem) * 100 if base_mem > 0 else 0

    recovery_cpu_pct = (recovery_cpu_overhead / mon_cpu) * 100 if mon_cpu > 0 else 0
    recovery_mem_pct = (recovery_mem_overhead / mon_mem) * 100 if mon_mem > 0 else 0

    total_cpu_pct = (total_cpu_overhead / base_cpu) * 100 if base_cpu > 0 else 0
    total_mem_pct = (total_mem_overhead / base_mem) * 100 if base_mem > 0 else 0

    # Print results
    print(f"\n{'='*60}")
    print("CLUSTER-WIDE RESOURCE USAGE")
    print(f"{'='*60}\n")

    print(f"Baseline (No SwarmGuard):")
    print(f"  Total CPU: {base_cpu:.1f}%")
    print(f"  Total Memory: {base_mem:.0f} MB")

    print(f"\nMonitoring-Agents Only:")
    print(f"  Total CPU: {mon_cpu:.1f}%")
    print(f"  Total Memory: {mon_mem:.0f} MB")

    print(f"\nFull SwarmGuard:")
    print(f"  Total CPU: {full_cpu:.1f}%")
    print(f"  Total Memory: {full_mem:.0f} MB")

    print(f"\n{'='*60}")
    print("OVERHEAD ANALYSIS")
    print(f"{'='*60}\n")

    print(f"Monitoring-Agents Overhead:")
    print(f"  CPU: +{monitoring_cpu_overhead:.1f}% ({monitoring_cpu_pct:.1f}% increase)")
    print(f"  Memory: +{monitoring_mem_overhead:.0f} MB ({monitoring_mem_pct:.1f}% increase)")

    print(f"\nRecovery-Manager Overhead:")
    print(f"  CPU: +{recovery_cpu_overhead:.1f}% ({recovery_cpu_pct:.1f}% increase)")
    print(f"  Memory: +{recovery_mem_overhead:.0f} MB ({recovery_mem_pct:.1f}% increase)")

    print(f"\nTotal SwarmGuard Overhead:")
    print(f"  CPU: +{total_cpu_overhead:.1f}% ({total_cpu_pct:.1f}% increase)")
    print(f"  Memory: +{total_mem_overhead:.0f} MB ({total_mem_pct:.1f}% increase)")

    # Per-node breakdown
    print(f"\n{'='*60}")
    print("PER-NODE BREAKDOWN")
    print(f"{'='*60}\n")

    for node in ['master', 'worker-1', 'worker-2', 'worker-3', 'worker-4']:
        print(f"{node}:")
        print(f"  Baseline:   CPU={baseline_stats[node]['cpu_mean']:.1f}%, Mem={baseline_stats[node]['mem_mean']:.0f}MB")
        print(f"  Monitoring: CPU={monitoring_stats[node]['cpu_mean']:.1f}%, Mem={monitoring_stats[node]['mem_mean']:.0f}MB")
        print(f"  Full:       CPU={full_stats[node]['cpu_mean']:.1f}%, Mem={full_stats[node]['mem_mean']:.0f}MB")

        cpu_diff = full_stats[node]['cpu_mean'] - baseline_stats[node]['cpu_mean']
        mem_diff = full_stats[node]['mem_mean'] - baseline_stats[node]['mem_mean']
        print(f"  Overhead:   CPU=+{cpu_diff:.1f}%, Mem=+{mem_diff:.0f}MB")
        print()

    # Generate LaTeX table
    print(f"{'='*60}")
    print("LATEX TABLE (for thesis)")
    print(f"{'='*60}")
    print("""
\\begin{table}[h]
\\centering
\\caption{SwarmGuard System Overhead}
\\label{tab:system_overhead}
\\begin{tabular}{lccc}
\\hline
\\textbf{Measurement} & \\textbf{CPU Usage} & \\textbf{Memory (MB)} & \\textbf{Overhead} \\\\
\\hline
Baseline (No SwarmGuard) & %.1f\\%% & %.0f & - \\\\
Monitoring-Agents Only & %.1f\\%% & %.0f & +%.1f\\%% \\\\
Full SwarmGuard & %.1f\\%% & %.0f & +%.1f\\%% \\\\
\\hline
\\textbf{Total Overhead} & \\textbf{+%.1f\\%%} & \\textbf{+%.0f MB} & \\textbf{%.1f\\%%} \\\\
\\hline
\\end{tabular}
\\end{table}
    """ % (
        base_cpu, base_mem,
        mon_cpu, mon_mem, monitoring_cpu_pct,
        full_cpu, full_mem, total_cpu_pct,
        total_cpu_overhead, total_mem_overhead, total_cpu_pct
    ))

if __name__ == "__main__":
    main()
