#!/usr/bin/env python3
"""
Comprehensive data extraction script for SwarmGuard Chapter 4
Extracts all experimental data from test logs and CSV files
"""

import os
import re
import json
import csv
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from collections import defaultdict

# Base data directory
DATA_DIR = Path("/Users/amirmuz/code/claude_code/fyp_everything/fyp-report/03-chapter4-evidence/data")
OUTPUT_DIR = Path("/Users/amirmuz/code/claude_code/fyp_everything/fyp-report/03-chapter4-evidence/chapter4_data")

def parse_mttr_log(filepath: Path) -> Optional[float]:
    """Parse MTTR log to calculate downtime in seconds"""
    try:
        with open(filepath, 'r') as f:
            lines = f.readlines()

        down_start = None
        up_time = None

        for line in lines:
            if '000DOWN' in line:
                if down_start is None:
                    timestamp_str = line.split()[0]
                    down_start = datetime.fromisoformat(timestamp_str)
            elif down_start and '200' in line:
                timestamp_str = line.split()[0]
                up_time = datetime.fromisoformat(timestamp_str)
                break

        if down_start and up_time:
            mttr_seconds = (up_time - down_start).total_seconds()
            return mttr_seconds

        # No downtime detected = zero-downtime success
        return 0.0
    except Exception as e:
        print(f"Error parsing {filepath}: {e}")
        return None

def extract_baseline_mttr() -> Dict:
    """Extract all 10 baseline MTTR measurements"""
    baseline_dir = DATA_DIR / "baseline"
    results = []

    for i in range(1, 11):
        # Try different naming patterns
        possible_files = [
            baseline_dir / f"02_baseline_mttr_test{i}.log",
            baseline_dir / f"baseline_test{i}.log",
            baseline_dir / f"test{i}.log"
        ]

        for filepath in possible_files:
            if filepath.exists():
                mttr = parse_mttr_log(filepath)
                if mttr is not None:
                    results.append({
                        "test_number": i,
                        "mttr_seconds": mttr,
                        "file": filepath.name
                    })
                    break

    # Calculate statistics
    if results:
        mttrs = [r["mttr_seconds"] for r in results]
        stats = {
            "count": len(results),
            "mean": sum(mttrs) / len(mttrs),
            "min": min(mttrs),
            "max": max(mttrs),
            "median": sorted(mttrs)[len(mttrs)//2],
            "tests": results
        }
        return stats
    return {}

def extract_scenario1_mttr() -> Dict:
    """Extract all 10 Scenario 1 MTTR measurements"""
    scenario1_dir = DATA_DIR / "scenario1"
    results = []
    zero_downtime_count = 0

    for i in range(1, 11):
        possible_files = [
            scenario1_dir / f"03_scenario1_mttr_test{i}.log",
            scenario1_dir / f"scenario1_test{i}.log",
            scenario1_dir / f"test{i}.log"
        ]

        for filepath in possible_files:
            if filepath.exists():
                mttr = parse_mttr_log(filepath)
                if mttr is not None:
                    is_zero_downtime = (mttr == 0.0)
                    if is_zero_downtime:
                        zero_downtime_count += 1

                    results.append({
                        "test_number": i,
                        "mttr_seconds": mttr,
                        "zero_downtime": is_zero_downtime,
                        "file": filepath.name
                    })
                    break

    # Calculate statistics
    if results:
        mttrs = [r["mttr_seconds"] for r in results]
        stats = {
            "count": len(results),
            "mean": sum(mttrs) / len(mttrs),
            "min": min(mttrs),
            "max": max(mttrs),
            "median": sorted(mttrs)[len(mttrs)//2],
            "zero_downtime_count": zero_downtime_count,
            "zero_downtime_rate": zero_downtime_count / len(results) * 100,
            "tests": results
        }
        return stats
    return {}

def parse_replica_log(filepath: Path) -> Dict:
    """Parse Scenario 2 replica scaling log"""
    try:
        with open(filepath, 'r') as f:
            lines = f.readlines()

        # Extract replica counts over time
        replica_timeline = []
        for line in lines:
            parts = line.strip().split()
            if len(parts) >= 2:
                timestamp_str = parts[0]
                replica_str = parts[1]  # Format: "current/desired"

                if '/' in replica_str:
                    current, desired = map(int, replica_str.split('/'))
                    replica_timeline.append({
                        "timestamp": timestamp_str,
                        "current": current,
                        "desired": desired
                    })

        # Find scaling events
        scaling_events = []
        prev_desired = None
        for entry in replica_timeline:
            if prev_desired is not None and entry["desired"] != prev_desired:
                scaling_events.append({
                    "timestamp": entry["timestamp"],
                    "from": prev_desired,
                    "to": entry["desired"]
                })
            prev_desired = entry["desired"]

        return {
            "timeline": replica_timeline,
            "scaling_events": scaling_events,
            "max_replicas": max(e["desired"] for e in replica_timeline) if replica_timeline else 0,
            "total_scaling_events": len(scaling_events)
        }
    except Exception as e:
        print(f"Error parsing replica log {filepath}: {e}")
        return {}

def extract_scenario2_scaling() -> Dict:
    """Extract all 10 Scenario 2 scaling measurements"""
    scenario2_dir = DATA_DIR / "scenario2"
    results = []

    for i in range(1, 11):
        filepath = scenario2_dir / f"04_scenario2_replicas_test{i}.log"

        if filepath.exists():
            scaling_data = parse_replica_log(filepath)
            if scaling_data:
                results.append({
                    "test_number": i,
                    "max_replicas": scaling_data.get("max_replicas", 0),
                    "scaling_events": scaling_data.get("total_scaling_events", 0),
                    "file": filepath.name
                })

    # Calculate statistics
    if results:
        max_reps = [r["max_replicas"] for r in results]
        stats = {
            "count": len(results),
            "avg_max_replicas": sum(max_reps) / len(max_reps),
            "min_replicas": min(max_reps),
            "max_replicas": max(max_reps),
            "tests": results
        }
        return stats
    return {}

def extract_overhead_data() -> Dict:
    """Extract overhead measurements from CSV files"""
    overhead_dir = DATA_DIR / "overhead"

    overhead_data = {}

    # Parse each CSV file
    for csv_file in ["overhead_baseline.csv", "overhead_monitoring_only.csv", "overhead_full_swarmguard.csv"]:
        filepath = overhead_dir / csv_file

        if filepath.exists():
            scenario_name = csv_file.replace("overhead_", "").replace(".csv", "")

            node_data = defaultdict(list)

            with open(filepath, 'r') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    node = row['node']
                    node_data[node].append({
                        "cpu_percent": float(row['cpu_percent']),
                        "memory_mb": float(row['memory_mb']),
                        "memory_percent": float(row['memory_percent'])
                    })

            # Calculate averages per node
            node_averages = {}
            for node, measurements in node_data.items():
                cpu_avg = sum(m["cpu_percent"] for m in measurements) / len(measurements)
                mem_avg = sum(m["memory_mb"] for m in measurements) / len(measurements)
                mem_pct_avg = sum(m["memory_percent"] for m in measurements) / len(measurements)

                node_averages[node] = {
                    "cpu_percent": round(cpu_avg, 2),
                    "memory_mb": round(mem_avg, 2),
                    "memory_percent": round(mem_pct_avg, 2),
                    "sample_count": len(measurements)
                }

            overhead_data[scenario_name] = node_averages

    return overhead_data

def calculate_improvements(baseline: Dict, scenario1: Dict) -> Dict:
    """Calculate MTTR improvement statistics"""
    if not baseline or not scenario1:
        return {}

    baseline_mean = baseline.get("mean", 0)
    scenario1_mean = scenario1.get("mean", 0)

    if baseline_mean > 0:
        reduction_seconds = baseline_mean - scenario1_mean
        reduction_percent = (reduction_seconds / baseline_mean) * 100

        return {
            "baseline_mttr": round(baseline_mean, 2),
            "swarmguard_mttr": round(scenario1_mean, 2),
            "reduction_seconds": round(reduction_seconds, 2),
            "reduction_percent": round(reduction_percent, 2)
        }
    return {}

def main():
    """Main extraction function"""
    print("=" * 80)
    print("SwarmGuard Chapter 4 - Comprehensive Data Extraction")
    print("=" * 80)

    # Extract all data
    print("\n[1/5] Extracting Baseline MTTR data...")
    baseline_data = extract_baseline_mttr()
    print(f"   Found {baseline_data.get('count', 0)} baseline tests")

    print("\n[2/5] Extracting Scenario 1 (Migration) MTTR data...")
    scenario1_data = extract_scenario1_mttr()
    print(f"   Found {scenario1_data.get('count', 0)} scenario1 tests")
    print(f"   Zero-downtime success rate: {scenario1_data.get('zero_downtime_rate', 0):.1f}%")

    print("\n[3/5] Extracting Scenario 2 (Scaling) data...")
    scenario2_data = extract_scenario2_scaling()
    print(f"   Found {scenario2_data.get('count', 0)} scenario2 tests")

    print("\n[4/5] Extracting Overhead measurements...")
    overhead_data = extract_overhead_data()
    print(f"   Found {len(overhead_data)} overhead scenarios")

    print("\n[5/5] Calculating improvements...")
    improvements = calculate_improvements(baseline_data, scenario1_data)

    # Save all data to JSON
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_file = OUTPUT_DIR / "extracted_data.json"

    all_data = {
        "baseline": baseline_data,
        "scenario1_migration": scenario1_data,
        "scenario2_scaling": scenario2_data,
        "overhead": overhead_data,
        "improvements": improvements,
        "extraction_timestamp": datetime.now().isoformat()
    }

    with open(output_file, 'w') as f:
        json.dump(all_data, f, indent=2)

    print(f"\n✅ Data extraction complete!")
    print(f"   Output saved to: {output_file}")

    # Print summary
    print("\n" + "=" * 80)
    print("SUMMARY OF RESULTS")
    print("=" * 80)

    if improvements:
        print(f"\n🎯 MTTR IMPROVEMENT:")
        print(f"   Baseline (reactive):  {improvements['baseline_mttr']:.2f}s")
        print(f"   SwarmGuard (proactive): {improvements['swarmguard_mttr']:.2f}s")
        print(f"   Reduction: {improvements['reduction_seconds']:.2f}s ({improvements['reduction_percent']:.1f}%)")

    if scenario1_data:
        print(f"\n🚀 ZERO-DOWNTIME MIGRATION:")
        print(f"   Success rate: {scenario1_data['zero_downtime_count']}/{scenario1_data['count']} tests ({scenario1_data['zero_downtime_rate']:.1f}%)")

    if scenario2_data:
        print(f"\n📈 HORIZONTAL SCALING:")
        print(f"   Average max replicas: {scenario2_data['avg_max_replicas']:.1f}")

    print("\n" + "=" * 80)

if __name__ == "__main__":
    main()
