# Scenario 2 Testing Guide

## Overview

This guide demonstrates **Scenario 2 (Autoscaling)** with gradual load increase and visual load distribution in Grafana.

---

## What Was Fixed

### Problem 1: CPU Spiked to 100% Immediately
**Before:** CPU jumped straight to 100% regardless of ramp setting
**After:** CPU gradually increases from 0% → target% over ramp period

### Problem 2: Load Didn't Distribute to New Replicas
**Before:** After scale-up, old replica stayed at 100%, new replica idle
**After:** Load automatically distributes across all replicas

---

## Solution Architecture

### Backend Fix: Gradual CPU Ramp
Modified `cpu_stress.py` to increase CPU intensity linearly:
```python
# During ramp period (0 to ramp_seconds):
current_cpu = (elapsed / ramp) × target

# After ramp completes:
current_cpu = target
```

### Frontend Fix: Continuous Short Requests
Alpine script sends 10-second request cycles instead of one long request:
- **Old:** One 120s request → sticks to one container
- **New:** Twelve 10s requests → each can route to different replicas

---

## Test Script Usage

### Basic Command
```bash
cd /Users/amirmuz/code/claude_code/fyp_everything/swarmguard/tests
./alpine_test_scenario2.sh [CPU] [MEMORY] [NETWORK] [RAMP] [DURATION] [USERS]
```

### Parameter Explanation

| Parameter | Description | Example |
|-----------|-------------|---------|
| CPU | CPU% per user | 2 |
| MEMORY | Memory MB per user | 50 |
| NETWORK | Network Mbps per user | 5 |
| RAMP | Seconds to reach target | 60 |
| DURATION | Seconds to hold target | 120 |
| USERS | Simulated users per Alpine | 10 |

### Calculation Example
```
Parameters: cpu=2, memory=50, network=5, users=10
Alpine nodes: 4

Total load:
- Users: 4 × 10 = 40 users
- CPU: 40 × 2% = 80%
- Memory: 40 × 50MB = 2000MB
- Network: 40 × 5Mbps = 200Mbps

Timeline:
T+0s:   0% CPU (ramp starts)
T+60s:  80% CPU (target reached)
T+180s: Test completes
```

---

## Example Test Cases

### Test 1: Light Load (1→2 replicas)
```bash
./alpine_test_scenario2.sh 2 50 5 60 120 10
# 80% CPU → triggers scale-up to 2 replicas
# Grafana: 80% → 40% + 40%
```

### Test 2: Medium Load (2→3 replicas)
```bash
./alpine_test_scenario2.sh 3 80 8 60 120 10
# 120% CPU → triggers multiple scale-ups
# Grafana: 120% → 60% + 60% → 40% + 40% + 40%
```

### Test 3: Heavy Load (3+ replicas)
```bash
./alpine_test_scenario2.sh 5 100 10 60 180 10
# 200% CPU → aggressive scaling
# Grafana: Shows distribution across all replicas
```

---

## Expected Behavior

### Phase 1: Gradual Ramp (0 to 60s)
- CPU increases linearly: 0% → 2% → 4% → ... → 80%
- Memory increases linearly: 0MB → 100MB → ... → 2000MB
- Network increases linearly: 0Mbps → 10Mbps → ... → 200Mbps
- **Grafana:** Smooth diagonal line going up

### Phase 2: Sustained Load (60s to 180s)
- CPU stays at 80%
- Memory stays at 2000MB
- Network stays at 200Mbps
- **Grafana:** Flat horizontal line

### Phase 3: Scale-Up Triggered (~90s)
- Recovery manager detects high CPU + MEM + NET
- Scales from 1 → 2 replicas
- New replica starts receiving requests

### Phase 4: Load Distribution (90s onwards)
- Same 40 users keep sending requests
- Docker Swarm distributes across 2 replicas
- **Grafana shows:**
  - Replica 1: 40% CPU, 1000MB, 100Mbps
  - Replica 2: 40% CPU, 1000MB, 100Mbps

---

## Grafana Visualization

Open: `http://192.168.2.61:3000`

### Panels to Watch

1. **CPU Usage by Container**
   - Before scale-up: One line at 80%
   - After scale-up: Two lines at ~40% each

2. **Memory Usage by Container**
   - Before: One line at 2000MB
   - After: Two lines at ~1000MB each

3. **Network Traffic by Container**
   - Before: One line at 200Mbps
   - After: Two lines at ~100Mbps each

4. **Replica Count**
   - Should show: 1 → 2 → (possibly 3)

---

## Deployment Steps

### 1. Rebuild web-stress Image
```bash
cd /Users/amirmuz/code/claude_code/fyp_everything/swarmguard/web-stress
docker build -t docker-registry.amirmuz.com/web-stress:latest .
docker push docker-registry.amirmuz.com/web-stress:latest
```

### 2. Update Deployed Service
```bash
ssh master "docker service update --force web-stress"
sleep 10  # Wait for update to complete
```

### 3. Verify Service is Running
```bash
curl http://192.168.2.50:8080/health
ssh master "docker service ps web-stress"
```

### 4. Run Test
```bash
cd /Users/amirmuz/code/claude_code/fyp_everything/swarmguard/tests
./alpine_test_scenario2.sh 2 50 5 60 120 10
```

### 5. Monitor Progress
```bash
# Terminal 1: Watch replicas
ssh master "watch -n 2 'docker service ps web-stress'"

# Terminal 2: Watch recovery manager logs
ssh master "docker service logs recovery-manager -f"

# Browser: Open Grafana
open http://192.168.2.61:3000
```

---

## Troubleshooting

### Issue: CPU Still Spikes to 100%
**Cause:** Using old web-stress image without gradual ramp fix
**Solution:** Rebuild and push image, then update service

### Issue: Load Doesn't Distribute
**Cause:** Requests might be too long (sticking to one container)
**Solution:** Script uses 10s cycles by default, should work correctly

### Issue: No Scale-Up Triggered
**Cause:** Total load below threshold (75% CPU or 80% MEM)
**Solution:** Increase users or per-user values:
```bash
./alpine_test_scenario2.sh 3 80 8 60 120 10  # Higher values
```

### Issue: Alpine Nodes Can't Connect
**Cause:** SSH or network connectivity issues
**Solution:**
```bash
# Test SSH to each Alpine
for i in {1..4}; do ssh alpine-$i "echo OK"; done

# Test service reachability from Alpine
ssh alpine-1 "curl -s http://192.168.2.50:8080/health"
```

---

## Success Criteria

✅ **Gradual Ramp:** CPU increases smoothly (not instant spike)
✅ **Sustained Load:** Metrics plateau at target values
✅ **Scale-Up Triggers:** Recovery manager scales 1→2 replicas
✅ **Load Distribution:** Grafana shows even split across replicas
✅ **Zero Downtime:** No failed requests during scale-up

---

## Script Cleanup

Press `Ctrl+C` to stop the test gracefully. The script will:
1. Stop all Alpine traffic
2. Clean up background processes
3. Exit cleanly

Or stop manually:
```bash
for i in {1..4}; do ssh alpine-$i "pkill -f stress/combined"; done
```

---

## Next Steps

After successful Scenario 2 testing:
1. Test scale-down (stop traffic, wait 180s, verify 2→1)
2. Test with different load patterns
3. Measure MTTR for scale-up operations
4. Document findings in final report
