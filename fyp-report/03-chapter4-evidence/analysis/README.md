# Analysis Scripts for Chapter 4

This directory contains Python scripts to analyze test results for your thesis Chapter 4 (Results).

## Prerequisites

- Python 3.6+
- Test data must be in `../data/` directory:
  - `baseline/` - Baseline test results (no SwarmGuard)
  - `scenario1/` - Scenario 1 test results (migration)
  - `scenario2/` - Scenario 2 test results (scaling)

## Available Scripts

### 1. `analyze_mttr.py` - MTTR Analysis

Analyzes Mean Time To Recovery (MTTR) for Baseline vs Scenario 1.

**Usage:**
```bash
cd /Users/amirmuz/code/claude_code/fyp_everything/fyp-report/03-chapter4-evidence/analysis
python3 analyze_mttr.py
```

**Output:**
- Individual test recovery times
- Statistical summary (mean, median, std dev, min, max)
- Comparison showing improvement percentage
- LaTeX table ready for thesis

**Example Results:**
```
BASELINE (No SwarmGuard):
  Mean: 23.10s
  Median: 24.00s

SCENARIO 1 (With SwarmGuard):
  Mean: 2.00s
  Median: 1.00s

Improvement: 91.3%
```

---

### 2. `analyze_scenario2_scaling.py` - Horizontal Scaling Analysis

Analyzes horizontal scaling performance for Scenario 2.

**Usage:**
```bash
cd /Users/amirmuz/code/claude_code/fyp_everything/fyp-report/03-chapter4-evidence/analysis
python3 analyze_scenario2_scaling.py
```

**Output:**
- Scale-up times (1→2 replicas)
- Scale-down times (2→1 replicas)
- Load distribution accuracy
- LaTeX table ready for thesis

**Example Results:**
```
Scale-Up Time:
  Mean: 11.40s
  Median: 6.50s

Scale-Down Time:
  Mean: 10.00s
  Median: 13.00s

Load Distribution: 5.4% deviation from 50/50
```

---

## Output Format

Both scripts output:
1. **Console output** - Human-readable statistics
2. **LaTeX tables** - Ready to copy-paste into your thesis

##Example LaTeX Output

The scripts generate LaTeX tables like this:

```latex
\begin{table}[h]
\centering
\caption{MTTR Comparison: Baseline vs Scenario 1}
\label{tab:mttr_comparison}
\begin{tabular}{lcc}
\hline
\textbf{Metric} & \textbf{Baseline} & \textbf{Scenario 1} \\
\hline
Mean MTTR (s) & 23.10 & 2.00 \\
Median MTTR (s) & 24.00 & 1.00 \\
Std Dev (s) & 1.66 & 2.65 \\
Min MTTR (s) & 21.00 & 0.00 \\
Max MTTR (s) & 25.00 & 5.00 \\
\hline
\textbf{Improvement} & - & \textbf{91.3\%} \\
\hline
\end{tabular}
\end{table}
```

---

## Data Interpretation

### MTTR Analysis (Baseline vs Scenario 1)

- **Baseline** measures reactive recovery (Docker Swarm restarts container after crash)
- **Scenario 1** measures proactive migration (SwarmGuard migrates before crash)
- **Goal**: Lower MTTR = less downtime
- **Expected**: Scenario 1 should be significantly faster (70-95% improvement)

### Scenario 2 Scaling Analysis

- **Scale-up time**: How fast SwarmGuard adds replicas under high traffic
- **Scale-down time**: How fast it removes replicas when traffic decreases
- **Load distribution**: How evenly requests are distributed across replicas
- **Goal**: Fast scaling + balanced distribution
- **Expected**: Scale-up/down within 10-20s, distribution near 50/50

---

## Troubleshooting

### "Could not find downtime period"

This is GOOD for Scenario 1! It means SwarmGuard migrated so fast that the service never went down (0s downtime).

### "No log files found"

Check that test data is in the correct directory:
```bash
ls -la ../data/baseline/
ls -la ../data/scenario1/
ls -la ../data/scenario2/
```

### Large variations in scale-up time

This is normal - it depends on:
- How quickly SwarmGuard detects threshold breach
- `consecutive_breaches: 2` requires 2 detection cycles
- Docker Swarm's scheduling speed

---

## Next Steps

After running these scripts:

1. **Copy LaTeX tables** into your Chapter 4
2. **Create graphs** from the raw data (optional)
3. **Write analysis** explaining the results
4. **Compare with PRD requirements** to show SwarmGuard meets objectives

---

**Last Updated**: 2024-12-25
