# Grafana Screenshot Guide for Thesis

## Overview

You need screenshots showing all 3 scenarios for Chapter 4 of your thesis. The screenshot helper scripts will guide you through capturing the right moments.

---

## Prerequisites

1. **Lab Mac**: Access to the physical lab Mac
2. **Grafana**: Open http://192.168.2.61:3000
3. **SwarmGuard Dashboard**: Navigate to "SwarmGuard Monitoring" dashboard
4. **Screenshot tool**: macOS built-in (Cmd+Shift+4)

---

## Recommended Order

Run the scripts in this order on your **lab Mac**:

```bash
cd /Users/amirmuz/fyp_everything/fyp-report/03-chapter4-evidence/scripts

# 1. Baseline (Reactive) - ~5 minutes
./screenshot_baseline.sh

# 2. Scenario 1 (Proactive Migration) - ~5 minutes
./screenshot_scenario1.sh

# 3. Scenario 2 (Horizontal Scaling) - ~15 minutes
./screenshot_scenario2.sh
```

---

## What Each Script Does

### 1. `screenshot_baseline.sh` (Baseline - Reactive Recovery)

**Duration**: ~5 minutes

**⚠️ IMPORTANT SETUP**:
- Script will **DISABLE recovery-manager** (to prevent proactive migration)
- Script will **KEEP monitoring-agents RUNNING** (so Grafana still has data)
- This ensures: **Grafana works** + **Container crashes reactively** (no SwarmGuard intervention)

**Screenshots needed** (3 total):
1. **Before crash**: Healthy baseline
2. **During crash**: Container crashed, metrics spiking
3. **After recovery**: Docker Swarm restarted container (VISIBLE DOWNTIME)

**Key metrics to capture**:
- CPU/Memory graphs showing spike before crash
- HTTP health checks: 200 → DOWN → 200 (downtime gap)
- Container restarted on different node
- **MTTR**: ~23 seconds visible in graph

**Save as**:
- `baseline_before_crash.png`
- `baseline_during_crash.png`
- `baseline_after_recovery.png`

---

### 2. `screenshot_scenario1.sh` (Scenario 1 - Proactive Migration)

**Duration**: ~5 minutes

**Screenshots needed** (3 total):
1. **Before stress**: Healthy baseline
2. **During migration**: SwarmGuard migrating container BEFORE crash
3. **After migration**: Container on new node (ZERO DOWNTIME)

**Key metrics to capture**:
- CPU/Memory ramping up (SwarmGuard detects threshold)
- HTTP health checks: CONTINUOUS 200 (no gap!)
- Container migrated to healthier node
- **MTTR**: ~2 seconds (or 0s for most tests)
- **NO VISIBLE DOWNTIME** in metrics graph

**Save as**:
- `scenario1_before_stress.png`
- `scenario1_during_migration.png`
- `scenario1_after_migration.png`

**Key Difference from Baseline**:
- Baseline: Crash → Downtime → Restart
- Scenario 1: Migrate → **ZERO Downtime** → Continue

---

### 3. `screenshot_scenario2.sh` (Scenario 2 - Horizontal Scaling)

**Duration**: ~15 minutes

**Screenshots needed** (4 total):
1. **Before scaling**: 1 replica, low traffic
2. **During scale-up**: High traffic detected, scaling to 2 replicas
3. **After scale-up**: 2 replicas running, load distributed ~50/50
4. **After scale-down**: Back to 1 replica

**Key metrics to capture**:
- Network Download: 0 Mbps → ~200 Mbps → 0 Mbps
- CPU: 10% → 70% (1 replica) → 35% each (2 replicas) → 10%
- Replica count: 1 → 2 → 1
- Load balancer distribution: ~50% / ~50%

**Save as**:
- `scenario2_before_scaling.png`
- `scenario2_during_scaleup.png`
- `scenario2_after_scaleup.png`
- `scenario2_after_scaledown.png`

**Bonus**: Run `./tests/monitor_lb_distribution.sh` in a separate terminal to see real-time load distribution

---

## Grafana Dashboard Tips

### Time Range
- **Baseline & Scenario 1**: Last 15 minutes
- **Scenario 2**: Last 30 minutes
- **Auto-refresh**: 5 seconds

### Panels to Focus On

**For Baseline & Scenario 1**:
- All Nodes - CPU Usage (web-stress container)
- All Nodes - Memory Usage (web-stress container)
- Service Availability Timeline (shows HTTP response codes)
- Container Migration Events (Scenario 1 only)

**For Scenario 2**:
- All Nodes - Network Download/Upload (should spike to ~200 Mbps)
- All Nodes - CPU Usage (should show load distribution after scaling)
- Replica Count Timeline (should show 1→2→1)
- Load Balancer Distribution (if available)

### Screenshot Best Practices

1. **Capture full dashboard** - Include time range and panel titles
2. **Clear labels** - Make sure metric names are visible
3. **Legends visible** - Show which line represents which node/replica
4. **Time markers** - Include timestamps for reference
5. **High resolution** - Use Cmd+Shift+4 (drag to select area)

---

## Screenshot Naming Convention

Save all screenshots in:
```
/Users/amirmuz/fyp_everything/fyp-report/03-chapter4-evidence/screenshots/
```

Create the directory first:
```bash
mkdir -p /Users/amirmuz/fyp_everything/fyp-report/03-chapter4-evidence/screenshots
```

**File naming**:
```
baseline_before_crash.png
baseline_during_crash.png
baseline_after_recovery.png

scenario1_before_stress.png
scenario1_during_migration.png
scenario1_after_migration.png

scenario2_before_scaling.png
scenario2_during_scaleup.png
scenario2_after_scaleup.png
scenario2_after_scaledown.png
```

---

## What Each Screenshot Should Prove

### Baseline Screenshots
**Prove**: Docker Swarm is REACTIVE (waits for crash, has downtime)
- Visible downtime in HTTP health checks
- Container restarted after crash
- MTTR ~23 seconds

### Scenario 1 Screenshots
**Prove**: SwarmGuard is PROACTIVE (migrates before crash, zero downtime)
- NO downtime in HTTP health checks
- Container migrated while still healthy
- MTTR ~2 seconds (91% improvement)

### Scenario 2 Screenshots
**Prove**: SwarmGuard handles HIGH TRAFFIC with horizontal scaling
- Scales from 1→2 replicas when traffic high
- Load distributed evenly (~50/50)
- Scales back down when traffic drops
- Scale-up time ~11 seconds

---

## After Taking Screenshots

1. **Organize screenshots** into the screenshots/ directory
2. **Verify quality** - Can you clearly see the metrics?
3. **Add to thesis**:
   - LaTeX: Use `\includegraphics{screenshots/baseline_before_crash.png}`
   - Word: Insert → Picture
4. **Add captions** explaining what each screenshot shows

---

## Troubleshooting

### "Script says container not found"
- Wait 30 seconds for deployment to complete
- Check: `ssh master "docker service ls"`

### "Grafana not showing data"
- Check time range (should be "Last 15/30 minutes")
- Verify auto-refresh is ON (5s interval)
- Check InfluxDB is running: `ssh master "docker ps | grep influxdb"`

### "SwarmGuard not triggering"
- Check recovery-manager is running: `ssh master "docker service ls | grep recovery"`
- Check logs: `ssh master "docker service logs recovery-manager --tail 50"`

### "Scenario 2 not scaling"
- Verify network threshold: Config requires >65 Mbps network + >75% CPU
- Check if load is actually high: `curl http://192.168.2.50:8081/metrics`

---

## Timeline

**Total time needed**: ~30-40 minutes

1. Baseline: 5-7 minutes
2. Scenario 1: 5-7 minutes
3. Scenario 2: 15-20 minutes
4. Organize screenshots: 5 minutes

**Recommendation**: Do this in one session while Grafana data is fresh.

---

**Last Updated**: 2024-12-25
**Purpose**: Chapter 4 (Results) visual evidence
