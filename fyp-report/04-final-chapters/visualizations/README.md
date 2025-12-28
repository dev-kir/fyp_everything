# SwarmGuard Thesis Visualization Scripts

This directory contains Python scripts to generate all figures for Chapter 4 (Results) of the SwarmGuard FYP thesis.

## 📁 Files

| File | Description | Figures Generated |
|------|-------------|-------------------|
| `mttr_comparison.py` | MTTR analysis and downtime metrics | 5 figures (4.1 - 4.5) |
| `scaling_timeline.py` | Dynamic scaling visualization | 3 figures (4.6 - 4.8) |
| `resource_overhead.py` | Resource overhead analysis | 5 figures (4.9 - 4.13) |
| `generate_all_figures.py` | Master script to generate all figures | - |
| `requirements.txt` | Python dependencies | - |

## 🚀 Quick Start

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

Or manually:
```bash
pip install matplotlib numpy seaborn
```

### 2. Generate All Figures

```bash
python generate_all_figures.py
```

This will run all three visualization scripts and generate **13 figures** in both PNG and PDF formats.

### 3. Generate Individual Figure Sets

```bash
# MTTR analysis (figures 4.1 - 4.5)
python mttr_comparison.py

# Scaling timeline (figures 4.6 - 4.8)
python scaling_timeline.py

# Resource overhead (figures 4.9 - 4.13)
python resource_overhead.py
```

## 📊 Generated Figures

### MTTR Comparison (5 figures)

1. **figure_4_1_mttr_comparison.png**
   - Bar chart with error bars comparing baseline vs scenarios
   - Shows mean MTTR with standard deviation

2. **figure_4_2_mttr_distribution.png**
   - Box plot distribution analysis
   - Individual data points with jitter

3. **figure_4_3_mttr_consistency.png**
   - Line plot showing MTTR across test runs
   - Demonstrates consistency and reproducibility

4. **figure_4_4_metrics_dashboard.png**
   - 4-panel dashboard (mean, median, std dev, improvement %)
   - Comprehensive metrics comparison

5. **figure_4_5_downtime_analysis.png**
   - Downtime classification (zero, minimal, moderate)
   - Shows 70% zero/minimal downtime achievement

### Scaling Timeline (3 figures)

6. **figure_4_6_scaling_timeline.png**
   - Dual-axis timeline (replicas + load over time)
   - Shows scale-up and scale-down events

7. **figure_4_7_event_timeline.png**
   - Gantt-style phase diagram
   - Event markers and system state transitions

8. **figure_4_8_scaling_metrics.png**
   - 4-panel scaling efficiency analysis
   - Scale-up latency, replica distribution, utilization, cooldown impact

### Resource Overhead (5 figures)

9. **figure_4_9_memory_overhead.png**
   - Memory distribution pie chart and bar comparison
   - Shows 221 MB total overhead

10. **figure_4_10_latency_breakdown.png**
    - Waterfall chart of MTTR components
    - Detection → Transmission → Decision → Execution

11. **figure_4_11_efficiency_dashboard.png**
    - 4-panel resource efficiency analysis
    - CPU, network, memory overhead and latency distribution

12. **figure_4_12_cost_benefit.png**
    - Cost-benefit analysis
    - Performance gains vs resource overhead

13. **figure_4_13_overhead_stability.png**
    - Overhead stability over time
    - Shows consistent resource usage with recovery event spikes

## 📐 Figure Specifications

- **Format:** PNG (for preview) + PDF (for LaTeX)
- **DPI:** 300 (publication quality)
- **Font:** Serif (matches thesis style)
- **Color scheme:** Professional color palette
- **Style:** Seaborn paper style with custom enhancements

## 🔧 Customization

### Modify Data

All test data is embedded in the scripts. To update with new test results, edit the data arrays at the top of each script:

```python
# In mttr_comparison.py
baseline_mttr = [20, 22, 25, 24, 23, 24, 21, 26, 23, 23]
scenario1_mttr = [0, 1, 6, 1, 1, 4, 3, 0, 4, 0]
scenario2_mttr = [7, 6, 8, 7, 6, 8, 7, 6, 8, 7]
```

### Modify Appearance

Edit the matplotlib configuration at the top of each script:

```python
plt.rcParams['figure.dpi'] = 300
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.size'] = 10
```

### Modify Colors

Color definitions can be changed in each script:

```python
colors = ['#c0392b', '#27ae60', '#2980b9']  # Red, Green, Blue
```

## 📝 LaTeX Integration

### Include Figures in Thesis

```latex
\begin{figure}[htbp]
    \centering
    \includegraphics[width=0.9\textwidth]{figure_4_1_mttr_comparison.pdf}
    \caption{MTTR Comparison: Baseline vs SwarmGuard Scenarios}
    \label{fig:mttr_comparison}
\end{figure}
```

### Reference Figures in Text

```latex
As shown in Figure~\ref{fig:mttr_comparison}, SwarmGuard achieved
a 91.3\% improvement in mean MTTR compared to baseline.
```

## 🎨 Figure Naming Convention

Format: `figure_4_X_description.{png,pdf}`

- `4` = Chapter number
- `X` = Figure number within chapter
- `description` = Brief descriptive name
- `.png` = Preview/presentation format
- `.pdf` = LaTeX/publication format

## ⚙️ Requirements

- Python 3.7+
- matplotlib >= 3.5.0
- numpy >= 1.21.0
- seaborn >= 0.11.0

## 📊 Data Sources

All data comes from the SwarmGuard experimental tests documented in:
- `fyp-report/03-chapter4-evidence/CHAPTER4_READY_SUMMARY.md`
- Test results from 30 test runs (10 baseline, 10 scenario1, 10 scenario2)

## 🐛 Troubleshooting

### Import Errors

```bash
# Install all dependencies
pip install -r requirements.txt
```

### Font Warnings

If you see font warnings, install additional fonts or modify the font family:

```python
plt.rcParams['font.family'] = 'sans-serif'  # Instead of 'serif'
```

### File Not Found

Ensure you're running scripts from the `visualizations/` directory:

```bash
cd fyp-report/04-final-chapters/visualizations/
python generate_all_figures.py
```

## 📈 Output Summary

**Total figures:** 13 (each in PNG and PDF format)
**Total files:** 26
**Estimated generation time:** 10-15 seconds
**Combined file size:** ~5-8 MB

## ✅ Quality Checks

Before using figures in thesis:

1. **Visual inspection:** Check all figures render correctly
2. **Data accuracy:** Verify numbers match test results
3. **Label clarity:** Ensure all axes and legends are readable
4. **Color accessibility:** Test grayscale printing if required
5. **File format:** Use PDF for final LaTeX compilation

## 📚 References

These visualizations support Chapter 4 findings:
- **RQ1:** 91.3% MTTR improvement (figures 4.1-4.5)
- **RQ2:** Zero-downtime migration (figures 4.5, 4.7)
- **RQ3:** Dynamic scaling (figures 4.6-4.8)
- **RQ4:** Minimal overhead (figures 4.9-4.13)

## 🎓 Academic Usage

These scripts are part of the SwarmGuard Final Year Project thesis submission.

**Author:** Amir Muzaffar
**Institution:** [Your University]
**Project:** SwarmGuard - Proactive Container Recovery for Docker Swarm
**Academic Year:** 2024/2025

---

**Last Updated:** December 2024
**Version:** 1.0
