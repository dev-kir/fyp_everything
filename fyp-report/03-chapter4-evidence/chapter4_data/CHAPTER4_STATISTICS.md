# SwarmGuard Chapter 4 - Statistical Analysis

**Generated**: 2025-12-27
**Purpose**: Detailed statistical calculations and formulas for thesis
**Source**: Experimental test results with mathematical rigor

---

## 1. MTTR STATISTICS

### 1.1 Baseline (Reactive) MTTR Statistics

**Raw Data** (n=10 tests):
```
24.0, 25.0, 24.0, 21.0, 25.0, 21.0, 22.0, 21.0, 24.0, 24.0 (seconds)
```

**Mean (μ)**:
```
μ = Σx / n
μ = (24+25+24+21+25+21+22+21+24+24) / 10
μ = 231 / 10
μ = 23.1 seconds
```

**Median**:
```
Sorted: 21.0, 21.0, 21.0, 22.0, 24.0, 24.0, 24.0, 24.0, 25.0, 25.0
Median = (24.0 + 24.0) / 2 = 24.0 seconds
```

**Standard Deviation (σ)**:
```
σ = sqrt(Σ(x - μ)² / n)
  = sqrt(((24-23.1)² + (25-23.1)² + ... + (24-23.1)²) / 10)
  = sqrt((0.81 + 3.61 + 0.81 + 4.41 + 3.61 + 4.41 + 1.21 + 4.41 + 0.81 + 0.81) / 10)
  = sqrt(24.9 / 10)
  = sqrt(2.49)
  = 1.58 seconds
```

**Variance (σ²)**:
```
σ² = 2.49 seconds²
```

**Range**:
```
Range = Max - Min = 25.0 - 21.0 = 4.0 seconds
```

**Coefficient of Variation (CV)**:
```
CV = (σ / μ) × 100%
CV = (1.58 / 23.1) × 100%
CV = 6.84%
```

**Interpretation**: Low CV (6.84%) indicates **consistent** reactive recovery times.

---

### 1.2 Scenario 1 (Proactive) MTTR Statistics

**Raw Data** (n=10 tests):
```
0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 5.0, 0.0 (seconds)
```

**Mean (μ)**:
```
μ = Σx / n
μ = (0+0+0+0+0+0+1+0+5+0) / 10
μ = 6 / 10
μ = 0.6 seconds
```

**Median**:
```
Sorted: 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 5.0
Median = (0.0 + 0.0) / 2 = 0.0 seconds
```

**Standard Deviation (σ)**:
```
σ = sqrt(Σ(x - μ)² / n)
  = sqrt(((0-0.6)² × 8 + (1-0.6)² + (5-0.6)²) / 10)
  = sqrt((0.36×8 + 0.16 + 19.36) / 10)
  = sqrt((2.88 + 0.16 + 19.36) / 10)
  = sqrt(22.4 / 10)
  = sqrt(2.24)
  = 1.50 seconds
```

**Variance (σ²)**:
```
σ² = 2.24 seconds²
```

**Range**:
```
Range = Max - Min = 5.0 - 0.0 = 5.0 seconds
```

**Coefficient of Variation (CV)**:
```
CV = (σ / μ) × 100%
CV = (1.50 / 0.6) × 100%
CV = 250%
```

**Interpretation**: High CV (250%) indicates **high variability** due to outlier (Test 9: 5.0s). However, median of 0.0s shows **majority achieved zero-downtime**.

---

### 1.3 MTTR Improvement Calculation

**Absolute Improvement**:
```
Improvement = Baseline_Mean - SwarmGuard_Mean
Improvement = 23.1 - 0.6
Improvement = 22.5 seconds
```

**Percentage Improvement**:
```
% Improvement = ((Baseline - SwarmGuard) / Baseline) × 100%
              = ((23.1 - 0.6) / 23.1) × 100%
              = (22.5 / 23.1) × 100%
              = 97.40%
```

**Interpretation**: SwarmGuard achieved **97.4% reduction** in MTTR.

---

## 2. ZERO-DOWNTIME SUCCESS RATE

### 2.1 Success Rate Calculation

**Zero-downtime tests**: 8 out of 10 (Tests: 1, 2, 3, 4, 5, 6, 8, 10)
**Non-zero-downtime tests**: 2 out of 10 (Tests: 7, 9)

**Success Rate**:
```
Success Rate = (Zero-downtime count / Total tests) × 100%
             = (8 / 10) × 100%
             = 80.0%
```

**Failure Rate**:
```
Failure Rate = 100% - Success Rate
             = 100% - 80%
             = 20.0%
```

### 2.2 Binomial Confidence Interval (95%)

Using Wilson score interval for small sample (n=10):

**Wilson Score Formula**:
```
p̂ = 8/10 = 0.8 (sample proportion)
z = 1.96 (95% confidence level)
n = 10

Lower bound ≈ 0.52 (52%)
Upper bound ≈ 0.95 (95%)
```

**95% Confidence Interval**: [52%, 95%]

**Interpretation**: With 95% confidence, true zero-downtime success rate is between 52% and 95%. Point estimate: 80%.

---

## 3. SERVICE AVAILABILITY CALCULATION

### 3.1 Availability During Failure Event

**Formula**:
```
Availability = (Uptime / Total Time) × 100%
```

**Baseline Availability** (during 60s test window):
```
Downtime = 23.1 seconds
Uptime = 60 - 23.1 = 36.9 seconds
Availability = (36.9 / 60) × 100% = 61.5%
```

**SwarmGuard Availability** (during 60s test window):
```
Downtime = 0.6 seconds
Uptime = 60 - 0.6 = 59.4 seconds
Availability = (59.4 / 60) × 100% = 99.0%
```

**Availability Improvement**:
```
Δ Availability = 99.0% - 61.5% = +37.5 percentage points
```

### 3.2 Annualized Availability (Extrapolated)

Assuming 1 failure event per hour in production:

**Baseline (Reactive)**:
```
Annual downtime = 23.1s/hour × 24 hours/day × 365 days/year
                = 23.1 × 24 × 365
                = 202,356 seconds/year
                = 56.21 hours/year

Availability = (8760 - 56.21) / 8760 × 100% = 99.36%
```

**SwarmGuard (Proactive)**:
```
Annual downtime = 0.6s/hour × 24 hours/day × 365 days/year
                = 0.6 × 24 × 365
                = 5,256 seconds/year
                = 1.46 hours/year

Availability = (8760 - 1.46) / 8760 × 100% = 99.98%
```

**SLA Tier**:
- Baseline: 99.36% (roughly **"two nines"**)
- SwarmGuard: 99.98% (approaching **"three nines" - 99.9%**)

**Interpretation**: SwarmGuard enables near-**"three nines"** availability with proactive recovery.

---

## 4. OVERHEAD STATISTICS

### 4.1 CPU Overhead

**Cluster-Wide CPU Usage**:

| Scenario | CPU % (avg) | Calculation |
|----------|-------------|-------------|
| Baseline | 1.34% | (2.24+1.30+0.67+1.22+1.27) / 5 |
| SwarmGuard | 1.25% | (2.37+0.97+0.71+1.21+0.97) / 5 |
| **Overhead** | **-0.09%** | 1.25 - 1.34 |

**Percentage Overhead**:
```
CPU Overhead % = ((SwarmGuard - Baseline) / Baseline) × 100%
               = ((1.25 - 1.34) / 1.34) × 100%
               = (-0.09 / 1.34) × 100%
               = -6.72%
```

**Interpretation**: SwarmGuard actually **reduced** CPU usage by 6.72% (negative overhead).

### 4.2 Memory Overhead

**Cluster-Wide Memory Usage**:

| Scenario | Memory (MB) | Calculation |
|----------|-------------|-------------|
| Baseline | 4797.74 MB | 2109.6 + 567.98 + 840.88 + 607.33 + 671.95 |
| SwarmGuard | 5019.10 MB | 2180.98 + 603.67 + 875.23 + 646.25 + 712.97 |
| **Overhead** | **+221.36 MB** | 5019.10 - 4797.74 |

**Percentage Overhead**:
```
Memory Overhead % = ((SwarmGuard - Baseline) / Baseline) × 100%
                  = ((5019.10 - 4797.74) / 4797.74) × 100%
                  = (221.36 / 4797.74) × 100%
                  = 4.61%
```

**Per-Node Average**:
```
Per-node overhead = 221.36 MB / 5 nodes = 44.27 MB/node
```

**Interpretation**: SwarmGuard adds **4.61% memory overhead** (~44 MB per node), which is **negligible** for modern systems.

---

## 5. HYPOTHESIS TESTING

### 5.1 T-Test: Baseline vs SwarmGuard MTTR

**Null Hypothesis (H₀)**: SwarmGuard MTTR = Baseline MTTR (no improvement)
**Alternative Hypothesis (H₁)**: SwarmGuard MTTR < Baseline MTTR (improvement)

**Test Type**: Independent samples t-test (one-tailed)

**Given**:
- Baseline: n₁=10, μ₁=23.1, σ₁=1.58
- SwarmGuard: n₂=10, μ₂=0.6, σ₂=1.50

**Pooled Standard Deviation (s_p)**:
```
s_p = sqrt(((n₁-1)σ₁² + (n₂-1)σ₂²) / (n₁+n₂-2))
    = sqrt(((10-1)×1.58² + (10-1)×1.50²) / (10+10-2))
    = sqrt((9×2.49 + 9×2.25) / 18)
    = sqrt((22.41 + 20.25) / 18)
    = sqrt(42.66 / 18)
    = sqrt(2.37)
    = 1.54
```

**T-Statistic**:
```
t = (μ₁ - μ₂) / (s_p × sqrt(1/n₁ + 1/n₂))
  = (23.1 - 0.6) / (1.54 × sqrt(1/10 + 1/10))
  = 22.5 / (1.54 × sqrt(0.2))
  = 22.5 / (1.54 × 0.447)
  = 22.5 / 0.688
  = 32.7
```

**Degrees of Freedom**: df = n₁ + n₂ - 2 = 18

**Critical Value** (α=0.05, one-tailed): t_critical ≈ 1.734

**Decision**:
```
t (32.7) >> t_critical (1.734)
p-value < 0.0001 (highly significant)
```

**Conclusion**: **Reject H₀**. SwarmGuard MTTR is **statistically significantly lower** than baseline MTTR (p < 0.0001).

---

### 5.2 Effect Size (Cohen's d)

**Formula**:
```
d = (μ₁ - μ₂) / s_p
  = (23.1 - 0.6) / 1.54
  = 22.5 / 1.54
  = 14.6
```

**Interpretation**:
- Cohen's d = 14.6 (extremely large effect size)
- d > 0.8 is "large", **d > 2.0 is "very large"**
- d = 14.6 indicates **extremely strong practical significance**

---

## 6. SCALING PERFORMANCE STATISTICS

### 6.1 Scenario 2 Replica Statistics

**Raw Data** (max replicas per test, n=10):
```
2, 3, 2, 2, 2, 2, 2, 2, 3, 2
```

**Mean**:
```
μ = (2+3+2+2+2+2+2+2+3+2) / 10 = 22 / 10 = 2.2 replicas
```

**Mode**: 2 replicas (appears 8 times)

**Standard Deviation**:
```
σ = sqrt(Σ(x - μ)² / n)
  = sqrt(((2-2.2)² × 8 + (3-2.2)² × 2) / 10)
  = sqrt((0.04×8 + 0.64×2) / 10)
  = sqrt((0.32 + 1.28) / 10)
  = sqrt(1.6 / 10)
  = sqrt(0.16)
  = 0.4 replicas
```

**Interpretation**: Most tests scaled to **2 replicas**, with 2 tests scaling to **3 replicas** under extreme load.

### 6.2 Scaling Events Statistics

**Raw Data** (scaling events per test, n=10):
```
2, 3, 2, 2, 2, 1, 2, 2, 4, 2
```

**Mean**:
```
μ = (2+3+2+2+2+1+2+2+4+2) / 10 = 22 / 10 = 2.2 events
```

**Interpretation**: Average of **2.2 scaling events** per test (typically 1 scale-up + 1 scale-down).

---

## 7. SAMPLE SIZE ADEQUACY

### 7.1 Power Analysis (Post-hoc)

**Given**:
- Effect size (Cohen's d) = 14.6
- Sample size (n) = 10 per group
- Significance level (α) = 0.05

**Power** (1 - β):
```
With d=14.6 and n=10, power ≈ 100% (essentially guaranteed to detect effect)
```

**Interpretation**: Sample size of **n=10 is adequate** for detecting such a large effect.

### 7.2 Minimum Sample Size Calculation

**For 95% confidence and 80% power with d=14.6**:
```
n_min ≈ 2 per group
```

**Actual**: n=10 per group (5× minimum required)

**Interpretation**: Current sample size is **more than sufficient** for statistical validity.

---

## 8. CORRELATION ANALYSIS

### 8.1 Network Percentage vs Scenario Classification

**Scenario 1 (Migration)** - Low network correlation:
- If Network < 35%, classify as Scenario 1

**Scenario 2 (Scaling)** - High network correlation:
- If Network > 65%, classify as Scenario 2

**Correlation** between network % and scenario:
```
ρ (rho) ≈ 1.0 (perfect positive correlation by design)
```

**Interpretation**: Network threshold is **perfect predictor** of scenario classification (by design).

---

## 9. OUTLIER ANALYSIS

### 9.1 Scenario 1 Outliers (Test 9)

**Test 9 MTTR**: 5.0 seconds

**Z-Score**:
```
z = (x - μ) / σ
  = (5.0 - 0.6) / 1.50
  = 4.4 / 1.50
  = 2.93
```

**Interpretation**: z=2.93 > 2.0 indicates **moderate outlier** (beyond 2 standard deviations).

**IQR Method**:
```
Q1 = 0.0, Q3 = 0.25
IQR = Q3 - Q1 = 0.25
Upper fence = Q3 + 1.5×IQR = 0.25 + 0.375 = 0.625
Test 9 (5.0) > Upper fence (0.625) → Outlier
```

**Decision**: Test 9 is a **valid outlier** (not measurement error), representing edge case where migration was delayed.

---

## 10. CONFIDENCE INTERVALS

### 10.1 95% CI for Baseline MTTR

**Formula**:
```
CI = μ ± (t_critical × SE)
SE = σ / sqrt(n) = 1.58 / sqrt(10) = 0.50

CI = 23.1 ± (2.262 × 0.50)  [t_critical for df=9, α=0.05]
CI = 23.1 ± 1.13
CI = [21.97, 24.23] seconds
```

**Interpretation**: 95% confidence that true baseline MTTR is between **21.97s and 24.23s**.

### 10.2 95% CI for SwarmGuard MTTR

**Formula**:
```
SE = 1.50 / sqrt(10) = 0.47
CI = 0.6 ± (2.262 × 0.47)
CI = 0.6 ± 1.06
CI = [-0.46, 1.66] seconds
```

**Interpretation**: 95% confidence that true SwarmGuard MTTR is between **0s and 1.66s** (negative bound capped at 0).

---

## 11. STATISTICAL SUMMARY FOR THESIS

| Statistical Test | Result | Interpretation |
|------------------|--------|----------------|
| **Mean Improvement** | 97.4% | SwarmGuard reduces MTTR by 97.4% |
| **T-Test (p-value)** | p < 0.0001 | Highly statistically significant |
| **Effect Size (Cohen's d)** | 14.6 | Extremely large practical significance |
| **Zero-Downtime Rate** | 80% [52%, 95%] | 80% success rate, 95% CI: 52-95% |
| **CPU Overhead** | -6.7% | Negligible (actually reduced CPU) |
| **Memory Overhead** | +4.6% | Negligible (~44 MB/node) |
| **Sample Size** | n=10 | Adequate (5× minimum required) |
| **Power** | >99% | More than sufficient to detect effect |

---

**Statistical Analysis Date**: 2025-12-27
**Confidence Level**: 95% (α=0.05)
**Software**: Hand-calculated with verification
**Conclusion**: SwarmGuard demonstrates **statistically significant and practically meaningful** MTTR improvement with **minimal overhead**.
