#!/usr/bin/env python3
"""
MTTR Analysis Script
Analyzes Baseline vs Scenario 1 recovery times from test logs
"""

import re
import statistics
from pathlib import Path
from datetime import datetime

def parse_timestamp(ts_str):
    """Parse ISO timestamp to datetime object"""
    return datetime.fromisoformat(ts_str.replace('Z', '+00:00'))

def extract_mttr_from_log(log_file):
    """
    Extract MTTR (Mean Time To Recovery) from test log
    Log format: timestamp HTTP_CODE (200=healthy, DOWN/500/etc=unhealthy)
    Returns recovery time in seconds
    """
    with open(log_file, 'r') as f:
        lines = f.readlines()

    # Find first time service went DOWN and first time it recovered to 200
    downtime_start = None
    downtime_end = None

    for line in lines:
        parts = line.strip().split()
        if len(parts) < 2:
            continue

        timestamp_str = parts[0]
        status_code = parts[1]

        try:
            timestamp = parse_timestamp(timestamp_str)
        except:
            continue

        # Service went down (first non-200 response after being healthy)
        if status_code != "200" and downtime_start is None:
            downtime_start = timestamp

        # Service recovered (first 200 response after being down)
        if status_code == "200" and downtime_start is not None and downtime_end is None:
            downtime_end = timestamp
            break

    if downtime_start is None or downtime_end is None:
        print(f"⚠️  Could not find downtime period in {log_file.name}")
        return None

    recovery_time = (downtime_end - downtime_start).total_seconds()
    return recovery_time

def analyze_scenario(data_dir, pattern, scenario_name):
    """Analyze all tests for a scenario"""
    print(f"\n{'='*60}")
    print(f"{scenario_name}")
    print(f"{'='*60}")

    log_files = sorted(Path(data_dir).glob(pattern))

    if not log_files:
        print(f"⚠️  No log files found matching: {pattern}")
        return None

    recovery_times = []

    for log_file in log_files:
        mttr = extract_mttr_from_log(log_file)
        if mttr is not None:
            test_num = re.search(r'test(\d+)', log_file.name).group(1)
            print(f"  Test {test_num:2s}: {mttr:6.2f}s")
            recovery_times.append(mttr)

    if not recovery_times:
        print(f"⚠️  No valid recovery times extracted")
        return None

    # Calculate statistics
    stats = {
        'mean': statistics.mean(recovery_times),
        'median': statistics.median(recovery_times),
        'stdev': statistics.stdev(recovery_times) if len(recovery_times) > 1 else 0,
        'min': min(recovery_times),
        'max': max(recovery_times),
        'count': len(recovery_times),
        'raw_data': recovery_times
    }

    print(f"\n{scenario_name} Statistics:")
    print(f"  Count:     {stats['count']}")
    print(f"  Mean:      {stats['mean']:.2f}s")
    print(f"  Median:    {stats['median']:.2f}s")
    print(f"  Std Dev:   {stats['stdev']:.2f}s")
    print(f"  Min:       {stats['min']:.2f}s")
    print(f"  Max:       {stats['max']:.2f}s")

    return stats

def main():
    # Paths
    data_dir = Path(__file__).parent.parent / "data"
    baseline_dir = data_dir / "baseline"
    scenario1_dir = data_dir / "scenario1"

    print("="*60)
    print("MTTR ANALYSIS - Baseline vs Scenario 1")
    print("="*60)

    # Analyze Baseline (no SwarmGuard)
    baseline_stats = analyze_scenario(
        baseline_dir,
        "02_baseline_mttr_test*.log",
        "BASELINE (No SwarmGuard)"
    )

    # Analyze Scenario 1 (with SwarmGuard migration)
    scenario1_stats = analyze_scenario(
        scenario1_dir,
        "03_scenario1_mttr_test*.log",
        "SCENARIO 1 (With SwarmGuard - Migration)"
    )

    # Compare results
    if baseline_stats and scenario1_stats:
        print(f"\n{'='*60}")
        print("COMPARISON")
        print(f"{'='*60}")

        improvement = baseline_stats['mean'] - scenario1_stats['mean']
        improvement_pct = (improvement / baseline_stats['mean']) * 100

        print(f"\nMean MTTR:")
        print(f"  Baseline:     {baseline_stats['mean']:.2f}s")
        print(f"  Scenario 1:   {scenario1_stats['mean']:.2f}s")
        print(f"  Improvement:  {improvement:.2f}s ({improvement_pct:.1f}%)")

        print(f"\nMedian MTTR:")
        baseline_median = baseline_stats['median']
        scenario1_median = scenario1_stats['median']
        median_improvement = baseline_median - scenario1_median
        median_improvement_pct = (median_improvement / baseline_median) * 100
        print(f"  Baseline:     {baseline_median:.2f}s")
        print(f"  Scenario 1:   {scenario1_median:.2f}s")
        print(f"  Improvement:  {median_improvement:.2f}s ({median_improvement_pct:.1f}%)")

        # Generate LaTeX table
        print(f"\n{'='*60}")
        print("LATEX TABLE (for thesis)")
        print(f"{'='*60}")
        print("""
\\begin{table}[h]
\\centering
\\caption{MTTR Comparison: Baseline vs Scenario 1}
\\label{tab:mttr_comparison}
\\begin{tabular}{lcc}
\\hline
\\textbf{Metric} & \\textbf{Baseline} & \\textbf{Scenario 1} \\\\
\\hline
Mean MTTR (s) & %.2f & %.2f \\\\
Median MTTR (s) & %.2f & %.2f \\\\
Std Dev (s) & %.2f & %.2f \\\\
Min MTTR (s) & %.2f & %.2f \\\\
Max MTTR (s) & %.2f & %.2f \\\\
\\hline
\\textbf{Improvement} & - & \\textbf{%.1f\\%%} \\\\
\\hline
\\end{tabular}
\\end{table}
        """ % (
            baseline_stats['mean'], scenario1_stats['mean'],
            baseline_stats['median'], scenario1_stats['median'],
            baseline_stats['stdev'], scenario1_stats['stdev'],
            baseline_stats['min'], scenario1_stats['min'],
            baseline_stats['max'], scenario1_stats['max'],
            improvement_pct
        ))

if __name__ == "__main__":
    main()
