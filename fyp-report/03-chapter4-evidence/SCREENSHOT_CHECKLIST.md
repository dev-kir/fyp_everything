# Screenshot Verification Checklist

Date: 2024-12-25

## Total Screenshots Needed: 10

### ✅ Baseline (3 screenshots)
- [ ] `baseline_before_crash.png` - Shows healthy service, CPU/Memory normal
- [ ] `baseline_during_crash.png` - Shows CPU spike, container crash
- [ ] `baseline_after_recovery.png` - Shows recovery, visible downtime gap

**What to verify:**
- [ ] Time range visible (Last 15 minutes)
- [ ] HTTP health checks show: 200 → DOWN → 200
- [ ] MTTR visible (~23 seconds downtime)
- [ ] Container moved to different node

---

### ✅ Scenario 1 (3 screenshots)
- [ ] `scenario1_before_stress.png` - Shows healthy service
- [ ] `scenario1_during_migration.png` - Shows SwarmGuard detecting issue
- [ ] `scenario1_after_migration.png` - Shows successful migration, ZERO downtime

**What to verify:**
- [ ] Time range visible (Last 15 minutes)
- [ ] HTTP health checks show: CONTINUOUS 200 (no gap!)
- [ ] CPU/Memory ramping but migration happens before crash
- [ ] Container migrated to different node
- [ ] MTTR ~0-2 seconds (proactive)

---

### ✅ Scenario 2 (4 screenshots)
- [ ] `scenario2_before_scaling.png` - Shows 1 replica, low traffic
- [ ] `scenario2_during_scaleup.png` - Shows high traffic, scaling triggered
- [ ] `scenario2_after_scaleup.png` - Shows 2 replicas, load distributed
- [ ] `scenario2_after_scaledown.png` - Shows back to 1 replica

**What to verify:**
- [ ] Time range visible (Last 30 minutes)
- [ ] Network traffic: 0 → ~200 Mbps → 0
- [ ] CPU: ~10% → ~70% (1 replica) → ~35% each (2 replicas) → ~10%
- [ ] Replica count: 1 → 2 → 1 (full cycle visible)
- [ ] Load distribution ~50/50 when scaled to 2

---

## Quality Checklist

For ALL screenshots, verify:
- [ ] **Resolution**: Clear, readable text
- [ ] **Panel titles**: Visible (e.g., "All Nodes - CPU Usage")
- [ ] **Legends**: Visible (shows which line = which node/container)
- [ ] **Time range**: Visible at top right
- [ ] **Metric values**: Numbers readable on Y-axis
- [ ] **Timestamps**: X-axis shows time progression
- [ ] **No obstructions**: No popup windows, dialogs, or notifications blocking view

---

## Key Differences to Highlight in Thesis

### Baseline vs Scenario 1:
| Metric | Baseline | Scenario 1 |
|--------|----------|------------|
| Approach | Reactive (wait for crash) | Proactive (migrate before crash) |
| Downtime | ~23 seconds | ~0-2 seconds |
| HTTP checks | 200 → DOWN → 200 (gap) | CONTINUOUS 200 (no gap) |
| Improvement | - | **91% faster** |

### Scenario 2:
| Phase | Replicas | Network | CPU (per replica) |
|-------|----------|---------|-------------------|
| Before | 1 | ~0 Mbps | ~10% |
| Scale-up | 1→2 | ~200 Mbps | ~70% → ~35% each |
| Scale-down | 2→1 | ~0 Mbps | ~10% |
| **Scale-up time** | - | - | **~11 seconds** |

---

## Screenshot Organization

### Recommended folder structure:
```
fyp-report/03-chapter4-evidence/
├── screenshots/
│   ├── baseline/
│   │   ├── 01_before_crash.png
│   │   ├── 02_during_crash.png
│   │   └── 03_after_recovery.png
│   ├── scenario1/
│   │   ├── 01_before_stress.png
│   │   ├── 02_during_migration.png
│   │   └── 03_after_migration.png
│   └── scenario2/
│       ├── 01_before_scaling.png
│       ├── 02_during_scaleup.png
│       ├── 03_after_scaleup.png
│       └── 04_after_scaledown.png
```

### Commands to organize:
```bash
cd /Users/amirmuz/fyp_everything/fyp-report/03-chapter4-evidence

# Create directories
mkdir -p screenshots/{baseline,scenario1,scenario2}

# Move screenshots (example - adjust filenames as needed)
mv ~/Desktop/baseline*.png screenshots/baseline/
mv ~/Desktop/scenario1*.png screenshots/scenario1/
mv ~/Desktop/scenario2*.png screenshots/scenario2/
```

---

## Using Screenshots in Thesis

### LaTeX Example:
```latex
\begin{figure}[h]
\centering
\includegraphics[width=0.9\textwidth]{screenshots/baseline/03_after_recovery.png}
\caption{Baseline: Reactive recovery showing 23-second downtime after container crash}
\label{fig:baseline_recovery}
\end{figure}
```

### Caption Guidelines:
- **Baseline**: "Figure X: Baseline reactive recovery showing container crash and 23-second downtime"
- **Scenario 1**: "Figure X: SwarmGuard proactive migration with zero downtime (MTTR: 2s)"
- **Scenario 2**: "Figure X: SwarmGuard horizontal scaling from 1 to 2 replicas under high traffic (200 Mbps)"

---

## What to Do Next

1. **Verify** all 10 screenshots against this checklist
2. **Organize** screenshots into proper folders
3. **Backup** screenshots (copy to cloud/USB)
4. **Review** quality - if any are unclear, retake while Grafana still has data
5. **Proceed** to Chapter 4 writing with statistical analysis + screenshots

---

## If Screenshots Need Retaking

The scripts are still available. You can rerun any scenario:

```bash
cd /Users/amirmuz/fyp_everything/fyp-report/03-chapter4-evidence/scripts

# Retake baseline
./screenshot_baseline.sh

# Retake scenario 1
./screenshot_scenario1.sh

# Retake scenario 2
./screenshot_scenario2.sh
```

**Note**: Grafana data retention depends on InfluxDB settings. Don't wait too long!

---

**Status**: ✅ Screenshots captured
**Next**: Organize, verify quality, then proceed with Chapter 4 writing
