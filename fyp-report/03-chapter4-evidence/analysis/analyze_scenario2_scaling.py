#!/usr/bin/env python3
"""
Scenario 2 Scaling Analysis Script
Analyzes horizontal scaling metrics from test logs
"""

import re
import json
import statistics
from pathlib import Path
from datetime import datetime

def parse_timestamp(ts_str):
    """Parse ISO timestamp to datetime object"""
    # Handle both formats: with Z or with timezone offset
    ts_str = ts_str.replace('Z', '+00:00')
    return datetime.fromisoformat(ts_str)

def analyze_replica_timeline(replica_log):
    """
    Analyze replica count timeline to find scale-up and scale-down times
    Returns: (scale_up_time, scale_down_time) in seconds
    """
    with open(replica_log, 'r') as f:
        lines = f.readlines()

    # Find when scaling occurred
    scale_up_start = None
    scale_up_end = None
    scale_down_start = None
    scale_down_end = None

    for line in lines:
        parts = line.strip().split()
        if len(parts) < 2:
            continue

        timestamp_str = parts[0]
        replica_str = parts[1]  # Format: "1/1" or "2/2" or "1/2"

        try:
            timestamp = parse_timestamp(timestamp_str)
        except:
            continue

        # Parse replica count (format: "current/desired")
        match = re.search(r'(\d+)/(\d+)', replica_str)
        if not match:
            continue

        current = int(match.group(1))
        desired = int(match.group(2))

        # Detect scale-up: 1/1 → 1/2 → 2/2
        if scale_up_start is None and current == 1 and desired == 2:
            scale_up_start = timestamp
        elif scale_up_start and current == 2 and desired == 2 and scale_up_end is None:
            scale_up_end = timestamp

        # Detect scale-down: 2/2 → 2/1 → 1/1 (after scale-up completed)
        if scale_up_end and scale_down_start is None and current == 2 and desired == 1:
            scale_down_start = timestamp
        elif scale_down_start and current == 1 and desired == 1 and scale_down_end is None:
            scale_down_end = timestamp

    # Calculate durations
    scale_up_time = None
    scale_down_time = None

    if scale_up_start and scale_up_end:
        scale_up_time = (scale_up_end - scale_up_start).total_seconds()

    if scale_down_start and scale_down_end:
        scale_down_time = (scale_down_end - scale_down_start).total_seconds()

    return scale_up_time, scale_down_time

def analyze_load_distribution(lb_metrics_log):
    """
    Analyze load balancer metrics to find request distribution
    Returns: dict with distribution stats
    """
    with open(lb_metrics_log, 'r') as f:
        lines = f.readlines()

    # Find the last metrics entry (after scaling stabilized)
    last_metrics = None
    for line in reversed(lines):
        parts = line.strip().split(maxsplit=1)
        if len(parts) == 2:
            try:
                metrics_json = json.loads(parts[1])
                if 'replica_stats' in metrics_json and len(metrics_json['replica_stats']) >= 2:
                    last_metrics = metrics_json
                    break
            except:
                continue

    if not last_metrics:
        return None

    # Extract request counts per replica
    replica_stats = last_metrics.get('replica_stats', {})
    request_counts = [stats['request_count'] for stats in replica_stats.values()]

    if len(request_counts) < 2:
        return None

    total_requests = sum(request_counts)
    percentages = [(count / total_requests * 100) if total_requests > 0 else 0 for count in request_counts]

    return {
        'total_requests': total_requests,
        'replica_requests': request_counts,
        'replica_percentages': percentages,
        'healthy_replicas': last_metrics.get('healthy_replicas', 0)
    }

def main():
    data_dir = Path(__file__).parent.parent / "data" / "scenario2"

    print("="*60)
    print("SCENARIO 2 SCALING ANALYSIS")
    print("="*60)

    # Collect scaling times
    scale_up_times = []
    scale_down_times = []
    load_distributions = []

    for test_num in range(1, 11):
        replica_log = data_dir / f"04_scenario2_replicas_test{test_num}.log"
        lb_log = data_dir / f"04_scenario2_lb_metrics_test{test_num}.log"

        if not replica_log.exists():
            print(f"⚠️  Test {test_num}: Replica log not found")
            continue

        # Analyze scaling times
        scale_up, scale_down = analyze_replica_timeline(replica_log)

        if scale_up:
            scale_up_times.append(scale_up)
            print(f"  Test {test_num:2d}: Scale-up = {scale_up:6.1f}s", end="")
        else:
            print(f"  Test {test_num:2d}: Scale-up = N/A", end="")

        if scale_down:
            scale_down_times.append(scale_down)
            print(f", Scale-down = {scale_down:6.1f}s", end="")
        else:
            print(f", Scale-down = N/A", end="")

        # Analyze load distribution
        if lb_log.exists():
            dist = analyze_load_distribution(lb_log)
            if dist:
                load_distributions.append(dist)
                print(f", Distribution = {dist['replica_percentages'][0]:.1f}% / {dist['replica_percentages'][1]:.1f}%")
            else:
                print(", Distribution = N/A")
        else:
            print()

    # Calculate statistics
    print(f"\n{'='*60}")
    print("SCALING STATISTICS")
    print(f"{'='*60}")

    if scale_up_times:
        print(f"\nScale-Up Time (1→2 replicas):")
        print(f"  Count:     {len(scale_up_times)}")
        print(f"  Mean:      {statistics.mean(scale_up_times):.2f}s")
        print(f"  Median:    {statistics.median(scale_up_times):.2f}s")
        print(f"  Std Dev:   {statistics.stdev(scale_up_times) if len(scale_up_times) > 1 else 0:.2f}s")
        print(f"  Min:       {min(scale_up_times):.2f}s")
        print(f"  Max:       {max(scale_up_times):.2f}s")

    if scale_down_times:
        print(f"\nScale-Down Time (2→1 replicas):")
        print(f"  Count:     {len(scale_down_times)}")
        print(f"  Mean:      {statistics.mean(scale_down_times):.2f}s")
        print(f"  Median:    {statistics.median(scale_down_times):.2f}s")
        print(f"  Std Dev:   {statistics.stdev(scale_down_times) if len(scale_down_times) > 1 else 0:.2f}s")
        print(f"  Min:       {min(scale_down_times):.2f}s")
        print(f"  Max:       {max(scale_down_times):.2f}s")

    if load_distributions:
        print(f"\nLoad Distribution:")
        print(f"  Tests analyzed: {len(load_distributions)}")
        avg_dist = statistics.mean([abs(50 - d['replica_percentages'][0]) for d in load_distributions])
        print(f"  Average deviation from 50/50: {avg_dist:.1f}%")
        print(f"  Best distribution: {min([abs(50 - d['replica_percentages'][0]) for d in load_distributions]):.1f}% deviation")
        print(f"  Worst distribution: {max([abs(50 - d['replica_percentages'][0]) for d in load_distributions]):.1f}% deviation")

    # Generate LaTeX table
    if scale_up_times:
        print(f"\n{'='*60}")
        print("LATEX TABLE (for thesis)")
        print(f"{'='*60}")
        print("""
\\begin{table}[h]
\\centering
\\caption{Scenario 2 Horizontal Scaling Performance}
\\label{tab:scenario2_scaling}
\\begin{tabular}{lc}
\\hline
\\textbf{Metric} & \\textbf{Value} \\\\
\\hline
Mean Scale-Up Time (s) & %.2f $\\pm$ %.2f \\\\
Median Scale-Up Time (s) & %.2f \\\\
Mean Scale-Down Time (s) & %.2f $\\pm$ %.2f \\\\
Median Scale-Down Time (s) & %.2f \\\\
Load Distribution Accuracy & %.1f\\%% deviation \\\\
\\hline
\\end{tabular}
\\end{table}
        """ % (
            statistics.mean(scale_up_times),
            statistics.stdev(scale_up_times) if len(scale_up_times) > 1 else 0,
            statistics.median(scale_up_times),
            statistics.mean(scale_down_times) if scale_down_times else 0,
            statistics.stdev(scale_down_times) if len(scale_down_times) > 1 else 0,
            statistics.median(scale_down_times) if scale_down_times else 0,
            avg_dist if load_distributions else 0
        ))

if __name__ == "__main__":
    main()
