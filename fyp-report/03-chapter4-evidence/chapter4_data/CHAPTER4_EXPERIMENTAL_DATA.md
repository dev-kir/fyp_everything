# SwarmGuard Chapter 4 - Experimental Results Data

**Generated**: 2025-12-27
**Data Source**: Actual test runs from SwarmGuard physical testbed
**Location**: `/fyp-report/03-chapter4-evidence/data/`

---

## 1. BASELINE TESTING RESULTS (Reactive Docker Swarm Recovery)

### 1.1 Individual Test Measurements

All 10 baseline tests measured reactive recovery using Docker Swarm's built-in health check mechanism without SwarmGuard.

| Test # | MTTR (seconds) | Log File | Notes |
|--------|----------------|----------|-------|
| 1 | 24.0s | `02_baseline_mttr_test1.log` | Standard reactive recovery |
| 2 | 25.0s | `02_baseline_mttr_test2.log` | Longest observed downtime |
| 3 | 24.0s | `02_baseline_mttr_test3.log` | Standard reactive recovery |
| 4 | 21.0s | `02_baseline_mttr_test4.log` | Fastest reactive recovery |
| 5 | 25.0s | `02_baseline_mttr_test5.log` | Longest observed downtime |
| 6 | 21.0s | `02_baseline_mttr_test6.log` | Fastest reactive recovery |
| 7 | 22.0s | `02_baseline_mttr_test7.log` | Slightly below average |
| 8 | 21.0s | `02_baseline_mttr_test8.log` | Fastest reactive recovery |
| 9 | 24.0s | `02_baseline_mttr_test9.log` | Standard reactive recovery |
| 10 | 24.0s | `02_baseline_mttr_test10.log` | Standard reactive recovery |

### 1.2 Statistical Summary

| Metric | Value | Unit |
|--------|-------|------|
| **Mean MTTR** | **23.1** | seconds |
| **Median MTTR** | 24.0 | seconds |
| **Minimum MTTR** | 21.0 | seconds |
| **Maximum MTTR** | 25.0 | seconds |
| **Standard Deviation** | ~1.49 | seconds |
| **Sample Size** | 10 | tests |
| **Downtime Rate** | 100% | (all tests experienced downtime) |

**Key Finding**: Reactive Docker Swarm recovery consistently takes 21-25 seconds, with an average of 23.1 seconds of service downtime per failure event.

---

## 2. SCENARIO 1 - PROACTIVE MIGRATION RESULTS

### 2.1 Individual Test Measurements

All 10 Scenario 1 tests measured proactive container migration using SwarmGuard's `start-first` zero-downtime strategy.

| Test # | MTTR (seconds) | Zero-Downtime? | Log File | Notes |
|--------|----------------|----------------|----------|-------|
| 1 | 0.0s | ✅ YES | `03_scenario1_mttr_test1.log` | Perfect zero-downtime |
| 2 | 0.0s | ✅ YES | `03_scenario1_mttr_test2.log` | Perfect zero-downtime |
| 3 | 0.0s | ✅ YES | `03_scenario1_mttr_test3.log` | Perfect zero-downtime |
| 4 | 0.0s | ✅ YES | `03_scenario1_mttr_test4.log` | Perfect zero-downtime |
| 5 | 0.0s | ✅ YES | `03_scenario1_mttr_test5.log` | Perfect zero-downtime |
| 6 | 0.0s | ✅ YES | `03_scenario1_mttr_test6.log` | Perfect zero-downtime |
| 7 | 1.0s | ❌ NO | `03_scenario1_mttr_test7.log` | Brief downtime during migration |
| 8 | 0.0s | ✅ YES | `03_scenario1_mttr_test8.log` | Perfect zero-downtime |
| 9 | 5.0s | ❌ NO | `03_scenario1_mttr_test9.log` | Longest downtime (migration delay) |
| 10 | 0.0s | ✅ YES | `03_scenario1_mttr_test10.log` | Perfect zero-downtime |

### 2.2 Statistical Summary

| Metric | Value | Unit |
|--------|-------|------|
| **Mean MTTR** | **0.6** | seconds |
| **Median MTTR** | 0.0 | seconds |
| **Minimum MTTR** | 0.0 | seconds |
| **Maximum MTTR** | 5.0 | seconds |
| **Zero-Downtime Success Count** | 8 out of 10 | tests |
| **Zero-Downtime Success Rate** | **80.0%** | percentage |
| **Sample Size** | 10 | tests |

**Key Finding**: SwarmGuard achieved true zero-downtime migration in 8 out of 10 tests (80% success rate), with an average MTTR of only 0.6 seconds across all tests.

### 2.3 MTTR Improvement Analysis

| Comparison Metric | Baseline (Reactive) | SwarmGuard (Proactive) | Improvement |
|-------------------|---------------------|------------------------|-------------|
| **Mean MTTR** | 23.1s | 0.6s | **22.5s reduction** |
| **Median MTTR** | 24.0s | 0.0s | **24.0s reduction** |
| **Best Case** | 21.0s | 0.0s | **21.0s reduction** |
| **Worst Case** | 25.0s | 5.0s | **20.0s reduction** |
| **Percentage Improvement** | — | — | **97.4%** |

**Critical Result**: SwarmGuard reduced mean time to recovery by **97.4%**, from 23.1 seconds (reactive) to 0.6 seconds (proactive).

---

## 3. SCENARIO 2 - HORIZONTAL SCALING RESULTS

### 3.1 Individual Test Measurements

All 10 Scenario 2 tests measured horizontal autoscaling using SwarmGuard's replica scaling mechanism.

| Test # | Max Replicas Scaled | Scaling Events | Log File | Notes |
|--------|---------------------|----------------|----------|-------|
| 1 | 2 | 2 | `04_scenario2_replicas_test1.log` | 1→2 scale-up, then scale-down |
| 2 | 3 | 3 | `04_scenario2_replicas_test2.log` | 1→2→3 scale-up, then scale-down |
| 3 | 2 | 2 | `04_scenario2_replicas_test3.log` | 1→2 scale-up, then scale-down |
| 4 | 2 | 2 | `04_scenario2_replicas_test4.log` | 1→2 scale-up, then scale-down |
| 5 | 2 | 2 | `04_scenario2_replicas_test5.log` | 1→2 scale-up, then scale-down |
| 6 | 2 | 1 | `04_scenario2_replicas_test6.log` | Single scale-up event |
| 7 | 2 | 2 | `04_scenario2_replicas_test7.log` | 1→2 scale-up, then scale-down |
| 8 | 2 | 2 | `04_scenario2_replicas_test8.log` | 1→2 scale-up, then scale-down |
| 9 | 3 | 4 | `04_scenario2_replicas_test9.log` | 1→2→3 scale-up, oscillation |
| 10 | 2 | 2 | `04_scenario2_replicas_test10.log` | 1→2 scale-up, then scale-down |

### 3.2 Statistical Summary

| Metric | Value | Unit |
|--------|-------|------|
| **Average Max Replicas** | 2.2 | replicas |
| **Minimum Replicas** | 2 | replicas |
| **Maximum Replicas** | 3 | replicas |
| **Average Scaling Events** | 2.2 | events per test |
| **Sample Size** | 10 | tests |

**Key Finding**: SwarmGuard successfully scaled from 1 replica to 2-3 replicas based on high CPU/memory + high network conditions, with most tests scaling to 2 replicas.

### 3.3 Scaling Behavior Observations

- **Typical Pattern**: 1 replica → 2 replicas (scale-up) → 1 replica (scale-down after load subsides)
- **Aggressive Scaling**: Tests 2 and 9 scaled up to 3 replicas during peak load
- **Scaling Oscillation**: Test 9 showed 4 scaling events (1→2→3→2→1), indicating potential cooldown tuning needed
- **Conservative Scaling**: Test 6 had only 1 scaling event (scale-up without immediate scale-down)

---

## 4. SYSTEM OVERHEAD MEASUREMENTS

### 4.1 Overhead Measurement Scenarios

Three scenarios were measured to isolate SwarmGuard's overhead:

1. **Baseline**: Only Docker Swarm + web-stress application (no SwarmGuard)
2. **Monitoring Only**: Baseline + 5 monitoring-agents (one per node)
3. **Full SwarmGuard**: Baseline + monitoring-agents + recovery-manager

### 4.2 CPU Overhead by Node

| Node | Baseline (%) | Monitoring Only (%) | Full SwarmGuard (%) | Overhead (%) |
|------|--------------|---------------------|---------------------|--------------|
| **master** (odin) | 2.24 | 3.08 | 2.37 | +0.13 |
| **worker-1** (thor) | 1.30 | 1.32 | 0.97 | -0.33 |
| **worker-2** (loki) | 0.67 | 0.68 | 0.71 | +0.04 |
| **worker-3** (heimdall) | 1.22 | 1.15 | 1.21 | -0.01 |
| **worker-4** (freya) | 1.27 | 1.06 | 0.97 | -0.30 |
| **Cluster Average** | 1.34 | 1.46 | 1.25 | **-0.09** |

**Key Finding**: Full SwarmGuard actually shows **lower average CPU usage** (1.25%) compared to baseline (1.34%), with negligible overhead (<0.2% per node).

### 4.3 Memory Overhead by Node

| Node | Baseline (MB) | Monitoring Only (MB) | Full SwarmGuard (MB) | Overhead (MB) |
|------|---------------|----------------------|----------------------|---------------|
| **master** (odin) | 2109.6 | 2144.35 | 2180.98 | +71.38 |
| **worker-1** (thor) | 567.98 | 603.60 | 603.67 | +35.69 |
| **worker-2** (loki) | 840.88 | 874.27 | 875.23 | +34.35 |
| **worker-3** (heimdall) | 607.33 | 648.62 | 646.25 | +38.92 |
| **worker-4** (freya) | 671.95 | 710.90 | 712.97 | +41.02 |
| **Cluster Total** | 4797.74 MB | 4981.74 MB | 5019.10 MB | **+221.36 MB** |

**Key Finding**: SwarmGuard adds approximately **221 MB of memory overhead cluster-wide** (~44 MB per node average).

### 4.4 Memory Overhead Percentage

| Node | Baseline (%) | Full SwarmGuard (%) | Overhead (%) |
|------|--------------|---------------------|--------------|
| **master** | 13.25 | 13.68 | +0.43 |
| **worker-1** | 7.26 | 7.71 | +0.45 |
| **worker-2** | 10.65 | 11.11 | +0.46 |
| **worker-3** | 3.81 | 4.04 | +0.23 |
| **worker-4** | 4.22 | 4.48 | +0.26 |
| **Average** | 7.84 | 8.20 | **+0.36** |

**Key Finding**: Memory overhead is **less than 0.5%** on all nodes, averaging only 0.36% cluster-wide.

### 4.5 Overhead Summary

| Resource | Baseline | SwarmGuard | Overhead | Overhead (%) |
|----------|----------|------------|----------|--------------|
| **CPU (cluster avg)** | 1.34% | 1.25% | -0.09% | **-6.7%** (reduction!) |
| **Memory (cluster total)** | 4797.74 MB | 5019.10 MB | 221.36 MB | **+4.6%** |
| **Memory per node (avg)** | 959.55 MB | 1003.82 MB | 44.27 MB | **+4.6%** |

**Critical Finding**: SwarmGuard has **minimal performance impact**:
- CPU overhead is **negligible** (actually shows slight reduction)
- Memory overhead is **~44 MB per node** (less than 5% increase)
- Both well within acceptable bounds for production systems

---

## 5. NETWORK OVERHEAD MEASUREMENTS

**Note**: Network overhead data is referenced in the project context but detailed measurements need to be extracted from InfluxDB or Grafana dashboards.

**Expected Results** (from project context):
- **Network overhead**: <0.5 Mbps per node
- **Monitoring traffic**: Batched metrics sent every 5 seconds
- **Event traffic**: HTTP POST alerts sent only during threshold breaches

**TODO**: Extract actual network bandwidth measurements from Grafana or tcpdump logs.

---

## 6. SAMPLE SIZE AND STATISTICAL VALIDITY

| Metric Category | Sample Size | Validity Notes |
|----------------|-------------|----------------|
| **Baseline MTTR** | 10 tests | Sufficient for mean/median calculation |
| **Scenario 1 MTTR** | 10 tests | Sufficient for mean/median calculation |
| **Scenario 2 Scaling** | 10 tests | Sufficient for scaling behavior analysis |
| **Overhead Measurements** | 60 samples per node per scenario | High statistical confidence |

**Statistical Confidence**:
- Each MTTR measurement represents a complete failure-recovery cycle
- Overhead measurements averaged over 60 samples (≥5 minutes of monitoring)
- Results show consistent patterns with low variance (except outliers in Scenario 1 tests 7, 9)

---

## 7. EXPERIMENTAL CONDITIONS

### 7.1 Test Environment Consistency

All tests were conducted on the same physical 5-node cluster with identical conditions:
- **Cluster configuration**: 1 master (odin) + 4 workers (thor, loki, heimdall, freya)
- **Network**: 100 Mbps Ethernet (Dell PowerConnect switch)
- **Docker version**: 24.0.x
- **Docker Swarm mode**: Active
- **Load testing**: web-stress application (Node.js Express)
- **Health check frequency**: 1 second HTTP GET `/health`
- **Monitoring frequency**: 3-5 second intervals

### 7.2 Failure Injection Method

- **Baseline & Scenario 1**: CPU stress induced using `stress-ng --cpu 4 --timeout 60s`
- **Scenario 2**: Combined CPU + network stress using `stress-ng` + `iperf3`
- **Failure detection**: HTTP health check returns 000DOWN when service unresponsive
- **Recovery trigger**: SwarmGuard detects 3 consecutive threshold breaches

---

## 8. DATA FILES REFERENCE

### 8.1 Raw Log Files

- **Baseline logs**: `data/baseline/02_baseline_mttr_test{1-10}.log`
- **Scenario 1 logs**: `data/scenario1/03_scenario1_mttr_test{1-10}.log`
- **Scenario 2 logs**: `data/scenario2/04_scenario2_replicas_test{1-10}.log`
- **Overhead CSV**: `data/overhead/overhead_{baseline,monitoring_only,full_swarmguard}.csv`

### 8.2 Processed Data

- **Extracted JSON**: `chapter4_data/extracted_data.json`
- **This document**: `chapter4_data/CHAPTER4_EXPERIMENTAL_DATA.md`

---

## 9. KEY RESULTS SUMMARY (For Chapter 4 Writing)

### 9.1 Primary Research Question: MTTR Reduction

**Question**: Can proactive recovery reduce Mean Time To Recovery?

**Answer**: **YES - 97.4% reduction**
- Baseline (reactive): 23.1 seconds
- SwarmGuard (proactive): 0.6 seconds
- Reduction: 22.5 seconds (97.4%)

### 9.2 Secondary Research Question: Zero-Downtime Achievement

**Question**: Can zero-downtime migration be achieved?

**Answer**: **YES - 80% success rate**
- 8 out of 10 tests achieved perfect zero-downtime (0 seconds)
- 2 tests had minimal downtime (1s, 5s)
- Median MTTR: 0.0 seconds

### 9.3 Tertiary Research Question: System Overhead

**Question**: What is the performance overhead of SwarmGuard?

**Answer**: **Minimal overhead (<5%)**
- CPU: -0.09% (negligible, actually shows reduction)
- Memory: +221 MB cluster-wide (~44 MB per node, <5%)
- Network: <0.5 Mbps per node (estimated)

### 9.4 Quaternary Research Question: Horizontal Scaling

**Question**: Can SwarmGuard effectively autoscale based on load?

**Answer**: **YES - 100% success rate**
- All 10 tests successfully scaled from 1 to 2-3 replicas
- Average max replicas: 2.2
- Scaling events: 2.2 per test (scale-up and scale-down)

---

## 10. IMPORTANT NOTES FOR THESIS WRITING

1. **Use these exact numbers** when writing Chapter 4 - they come from actual test runs
2. **97.4% improvement** is the accurate figure (not 91.3% mentioned in earlier drafts)
3. **Zero-downtime rate is 80%** (8/10 tests), not 70% (7/10) mentioned in context
4. **Overhead is minimal**: <0.1% CPU, ~44 MB memory per node
5. **Sample size**: 10 tests each for baseline, scenario1, scenario2 (statistically valid)
6. **Outliers**: Tests 7 and 9 in Scenario 1 had brief downtime (1s, 5s) - explain in Discussion
7. **Scaling oscillation**: Test 9 in Scenario 2 showed 4 scaling events - discuss cooldown tuning

---

**Data Extraction Date**: 2025-12-27
**Extraction Script**: `extract_all_data.py`
**JSON Output**: `extracted_data.json`
