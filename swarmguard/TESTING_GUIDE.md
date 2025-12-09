# SwarmGuard Testing Guide
## Comprehensive Validation of PRD Objectives

**Version:** 1.0
**Date:** December 9, 2025
**Purpose:** Step-by-step guide to validate all PRD requirements

---

## Overview

This guide will help you systematically test and validate that SwarmGuard achieves all objectives stated in the PRD. We'll test:

1. **Network Metrics Collection** (✅ Already verified working)
2. **Scenario 1: Container Migration** (Pending)
3. **Scenario 2: Horizontal Scaling** (Pending)
4. **MTTR < 10 seconds** (Pending)
5. **Zero Downtime** (Pending)
6. **Alert Latency < 1 second** (Pending)

---

## Pre-Test Checklist

Before starting tests, verify all components are running:

```bash
# 1. Check all monitoring agents (should see 5)
ssh master "docker service ls | grep monitoring-agent"

# 2. Check recovery manager
ssh master "docker service ls | grep recovery-manager"

# 3. Check InfluxDB connectivity
curl -s "http://192.168.2.61:8086/health"

# 4. Check Grafana dashboards
open http://192.168.2.61:3000

# 5. Verify network metrics are being collected (non-zero values)
curl -s "http://192.168.2.61:8086/api/v2/query?org=swarmguard" \
  -H "Authorization: Token iNCff-dYnCY8oiO_mDIn3tMIEdl5D1Z4_KFE2vwTMFtQoTqGh2SbL5msNB30DIOKE2wwj-maBW5lTZVJ3f9ONA==" \
  -H "Content-Type: application/vnd.flux" \
  -d 'from(bucket: "metrics") |> range(start: -2m) |> filter(fn: (r) => r._measurement == "nodes" and (r._field == "net_in" or r._field == "net_out")) |> limit(n: 5)'
```

**Expected Results:**
- 5 monitoring agents running (master + 4 workers)
- Recovery manager running on master
- InfluxDB returns `{"status":"pass"}`
- Network metrics show non-zero values

---

## Test Phase 1: Baseline Metrics Verification

### Objective
Verify all metrics (CPU, Memory, Network) are being collected correctly.

### Steps

1. **Deploy test application:**
   ```bash
   cd /path/to/swarmguard
   ./tests/deploy_web_stress.sh
   ```

2. **Wait for deployment:**
   ```bash
   ssh master "docker service ps web-stress"
   # Wait until state is "Running"
   ```

3. **Identify which node is hosting the container:**
   ```bash
   ssh master "docker service ps web-stress --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}'"
   # Note the node name (e.g., worker-3)
   ```

4. **Run light stress test to generate metrics:**
   ```bash
   # Test CPU stress (should see spike in Grafana)
   curl "http://192.168.2.50:8080/stress/cpu?target=30&duration=60&ramp=10"

   # Wait 20 seconds, then check Grafana
   # You should see CPU rise from ~5% to ~30% over 10 seconds

   # Test memory stress
   curl "http://192.168.2.50:8080/stress/memory?target=512&duration=60&ramp=10"

   # Test network stress
   curl "http://192.168.2.50:8080/stress/network?bandwidth=20&duration=60&ramp=10"
   ```

5. **Verify in Grafana:**
   - Open http://192.168.2.61:3000
   - Select the node hosting web-stress
   - Verify you see:
     - CPU spike to ~30%
     - Memory increase to ~512MB
     - Network traffic increase to ~20 Mbps

### Success Criteria
- ✅ All three metric types (CPU, Memory, Network) show expected values
- ✅ Metrics update every 5-10 seconds
- ✅ Ramp-up is smooth and gradual (not sudden spike)

---

## Test Phase 2: Scenario 1 Validation (Container Migration)

### Objective
**PRD Section 3.1:** Verify proactive migration when container has resource problem (high CPU/Memory, low Network).

### Expected Behavior
- **Detection:** (CPU > 75% OR Memory > 80%) AND Network < 35%
- **Action:** Migrate container to different node
- **Target MTTR:** < 10 seconds
- **Target Downtime:** 0 seconds (zero downtime)

### Test Steps

#### Step 1: Deploy Test Application
```bash
# Ensure web-stress is running with 1 replica
ssh master "docker service ls | grep web-stress"

# If not running, deploy it
./tests/deploy_web_stress.sh
```

#### Step 2: Check Recovery Manager Configuration
```bash
# Check if recovery manager is configured with correct thresholds
ssh master "docker service logs recovery-manager --tail 20"

# Look for threshold values in logs:
# - CPU_THRESHOLD: 75%
# - MEMORY_THRESHOLD: 80%
# - NETWORK_THRESHOLD: 35% (for Scenario 1)
```

#### Step 3: Trigger Scenario 1 (High CPU/Memory, Low Network)
```bash
# Stress CPU to 80% and Memory to 1GB, but keep network low
curl "http://192.168.2.50:8080/stress/combined?cpu=80&memory=1024&network=0&duration=180&ramp=30"

# Response should be:
# {"status":"started","type":"combined",...}
```

#### Step 4: Monitor Recovery Process
```bash
# Terminal 1: Watch recovery manager logs
ssh master "docker service logs -f recovery-manager"

# Terminal 2: Watch service tasks
watch -n 1 "ssh master 'docker service ps web-stress --format \"table {{.Name}}\t{{.Node}}\t{{.DesiredState}}\t{{.CurrentState}}\"'"

# Terminal 3: Monitor Grafana dashboard
# Open http://192.168.2.61:3000
# Watch for:
# - CPU rising to 80%
# - Memory rising to 1024MB
# - Network staying low (< 10 Mbps)
```

#### Step 5: Verify Migration Occurred
After ~30-40 seconds (ramp-up complete), recovery manager should detect threshold breach and trigger migration.

**What to look for:**
1. **Recovery manager logs should show:**
   ```
   [ALERT] Threshold breach detected: service=web-stress, cpu=80%, mem=1024MB, net=5Mbps
   [SCENARIO] Detected: Scenario 1 (Migration) - High CPU/Mem, Low Network
   [ACTION] Initiating migration: service=web-stress, from=worker-3, to=worker-1
   [SUCCESS] New container ready on worker-1
   [SUCCESS] Old container removed from worker-3
   [MTTR] Total recovery time: 7.5 seconds
   ```

2. **Docker service ps should show:**
   - Old task on worker-3: state "Shutdown"
   - New task on different worker: state "Running"

3. **Grafana should show:**
   - Brief period where both containers exist (overlap)
   - Load shifts from old to new container
   - NO gap in metrics (continuous availability)

#### Step 6: Record Metrics
```bash
# Extract timing from recovery manager logs
ssh master "docker service logs recovery-manager | grep MTTR"

# Record:
# - T0: Threshold breach time
# - T1: Alert sent time
# - T2: Decision made time
# - T3: New container ready time
# - T4: Old container removed time
# - Total MTTR: T4 - T0 (should be < 10 seconds)
```

### Success Criteria
- ✅ Recovery manager detected Scenario 1 correctly
- ✅ Container migrated to different node
- ✅ MTTR < 10 seconds (ideally 5-8 seconds)
- ✅ Zero downtime (no failed requests)
- ✅ Old container removed AFTER new container healthy

### Troubleshooting
**If migration does NOT trigger:**
- Check recovery manager logs for errors
- Verify thresholds in config.yaml
- Ensure consecutive breach count is met (usually requires 2-3 data points)
- Check cooldown period hasn't been triggered recently

---

## Test Phase 3: Scenario 2 Validation (Horizontal Scaling)

### Objective
**PRD Section 3.2:** Verify horizontal scaling when service under high traffic (high CPU/Memory/Network).

### Expected Behavior
- **Detection:** CPU > 75% AND Memory > 80% AND Network > 65%
- **Action:** Scale up by adding 1 replica
- **Target MTTR:** < 10 seconds (to new replica serving traffic)
- **Target Downtime:** 0 seconds

### Test Steps

#### Step 1: Reset to 1 Replica
```bash
ssh master "docker service scale web-stress=1"
ssh master "docker service ps web-stress"
```

#### Step 2: Trigger Scenario 2 (High CPU/Memory/Network)
```bash
# Stress all three resources simultaneously
curl "http://192.168.2.50:8080/stress/combined?cpu=80&memory=1024&network=70&duration=180&ramp=30"

# Expected response:
# {"status":"started","type":"combined","targets":{"cpu":80,"memory":1024,"network":70}}
```

#### Step 3: Monitor Scale-Up
```bash
# Terminal 1: Watch recovery manager
ssh master "docker service logs -f recovery-manager"

# Terminal 2: Watch replica count
watch -n 1 "ssh master 'docker service ls | grep web-stress'"

# Terminal 3: Monitor Grafana
# Watch load distribution:
# - Before scale: 1 container at 80% CPU
# - After scale: 2 containers each at ~40% CPU (load split)
```

#### Step 4: Verify Load Distribution
**Critical PRD Requirement:** After scaling, load should split proportionally.

**Formula:** `new_utilization_per_replica ≈ old_total_utilization / new_replica_count`

**Example:**
- Before scale-up: 1 replica at 80% CPU
- After scale-up: 2 replicas, each should be ~40% CPU
- If scales to 3: each should be ~26-27% CPU

**Verification in Grafana:**
1. Open node monitoring dashboard
2. Select multiple nodes (to see both containers)
3. Verify CPU usage splits:
   - Old container: drops from 80% to ~40%
   - New container: starts serving traffic, reaches ~40%

#### Step 5: Test Scale-Down
```bash
# Stop stress test
curl "http://192.168.2.50:8080/stress/stop"

# Wait for cooldown period (usually 180 seconds)
# Watch for recovery manager to scale down

# Expected log:
# [SCALE_DOWN] All containers idle for 180s, scaling web-stress from 2 to 1
```

### Success Criteria
- ✅ Recovery manager detected Scenario 2 correctly
- ✅ Service scaled from 1 to 2 replicas within 5-10 seconds
- ✅ Load distributed evenly (each container ~40% CPU instead of 80%)
- ✅ Zero downtime during scale-up
- ✅ Service scaled back down after traffic subsided

---

## Test Phase 4: MTTR Comparison (Proactive vs Reactive)

### Objective
**PRD Section 5.2 Test Case 3:** Demonstrate improvement over Docker Swarm's reactive recovery.

### Baseline Test (Reactive Recovery)

#### Step 1: Disable Proactive Recovery
```bash
# Stop recovery manager temporarily
ssh master "docker service scale recovery-manager=0"

# Verify it's stopped
ssh master "docker service ls | grep recovery-manager"
```

#### Step 2: Deploy Test App and Kill Container
```bash
# Deploy web-stress
./tests/deploy_web_stress.sh

# Find container ID
CONTAINER_ID=$(ssh master "docker ps --filter 'name=web-stress' --format '{{.ID}}'")
NODE=$(ssh master "docker ps --filter 'name=web-stress' --format '{{.Names}}' | cut -d. -f2")

echo "Container: $CONTAINER_ID on node: $NODE"

# Start continuous availability monitoring
./tests/validate_zero_downtime.sh \
  --target http://192.168.2.50:8080/health \
  --interval 0.1 \
  --output baseline_downtime.txt &

MONITOR_PID=$!

# Wait 5 seconds for monitoring to start
sleep 5

# Record start time and kill container
START_TIME=$(date +%s)
ssh $NODE "docker kill $CONTAINER_ID"

# Wait for Docker Swarm to detect and restart
sleep 15

# Stop monitoring
kill $MONITOR_PID

# Record end time
END_TIME=$(date +%s)
BASELINE_MTTR=$((END_TIME - START_TIME))

echo "Baseline MTTR (Reactive): $BASELINE_MTTR seconds"

# Count downtime
DOWNTIME=$(grep "FAILED" baseline_downtime.txt | wc -l)
echo "Baseline Downtime: $DOWNTIME failed requests"
```

**Expected Baseline:** 10-12 seconds MTTR, 10-12 seconds downtime

### Proactive Test

#### Step 1: Re-enable Recovery Manager
```bash
ssh master "docker service scale recovery-manager=1"
sleep 10  # Wait for startup
```

#### Step 2: Run Scenario 1 with Timing
```bash
# Start monitoring
./tests/validate_zero_downtime.sh \
  --target http://192.168.2.50:8080/health \
  --interval 0.1 \
  --output proactive_downtime.txt &

MONITOR_PID=$!

# Trigger stress
START_TIME=$(date +%s)
curl "http://192.168.2.50:8080/stress/combined?cpu=80&memory=1024&network=0&duration=120&ramp=30"

# Wait for migration to complete (monitor logs)
ssh master "docker service logs -f recovery-manager" | grep -m 1 "MTTR"

END_TIME=$(date +%s)
PROACTIVE_MTTR=$((END_TIME - START_TIME))

kill $MONITOR_PID

echo "Proactive MTTR: $PROACTIVE_MTTR seconds"

# Count downtime
DOWNTIME=$(grep "FAILED" proactive_downtime.txt | wc -l)
echo "Proactive Downtime: $DOWNTIME failed requests (target: 0)"
```

#### Step 3: Compare Results
```bash
echo "=== MTTR Comparison ==="
echo "Baseline (Reactive):  $BASELINE_MTTR seconds"
echo "Proactive:            $PROACTIVE_MTTR seconds"
echo "Improvement:          $((BASELINE_MTTR - PROACTIVE_MTTR)) seconds"
echo "Percentage:           $((100 * (BASELINE_MTTR - PROACTIVE_MTTR) / BASELINE_MTTR))%"
echo ""
echo "PRD Target: > 50% improvement, MTTR < 10 seconds"
```

### Success Criteria
- ✅ Proactive MTTR < 10 seconds
- ✅ Proactive MTTR < Reactive MTTR (at least 50% reduction)
- ✅ Proactive downtime = 0 requests (vs reactive 10+ seconds)
- ✅ Clear improvement demonstrated

---

## Test Phase 5: Performance & Overhead Validation

### Objective
**PRD Section 4.1:** Verify monitoring overhead < 5% CPU, < 100MB RAM per node.

### Steps

#### Step 1: Measure Monitoring Agent Resource Usage
```bash
# For each node, get monitoring agent stats
for node in master worker-1 worker-3 worker-4; do
  echo "=== $node ==="
  ssh $node "docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' | grep monitoring-agent"
done
```

**Expected Output (per agent):**
```
monitoring-agent-master    2.5%    45MB / 15.5GB
monitoring-agent-worker1   3.1%    52MB / 7.6GB
...
```

#### Step 2: Verify Alert Latency < 1 Second
```bash
# Check recovery manager logs for alert timing
ssh master "docker service logs recovery-manager | grep 'Alert latency'"

# Should show:
# [PERF] Alert latency: 0.12s (from agent to manager)
# [PERF] Decision latency: 0.05s (from alert to action)
```

### Success Criteria
- ✅ Each monitoring agent uses < 5% CPU
- ✅ Each monitoring agent uses < 100MB RAM
- ✅ Alert latency < 1 second
- ✅ Decision latency < 1 second

---

## Test Phase 6: Concurrent Scenarios

### Objective
**PRD Section 5.2 Test Case 5:** Verify system handles multiple simultaneous issues.

### Steps

#### Step 1: Deploy Multiple Services
```bash
# Deploy 3 instances of web-stress
ssh master "docker service create --name web-stress-a --replicas 1 --network swarmguard-net docker-registry.amirmuz.com/swarmguard-web-stress:latest"
ssh master "docker service create --name web-stress-b --replicas 1 --network swarmguard-net docker-registry.amirmuz.com/swarmguard-web-stress:latest"
ssh master "docker service create --name web-stress-c --replicas 1 --network swarmguard-net docker-registry.amirmuz.com/swarmguard-web-stress:latest"
```

#### Step 2: Find Published Ports
```bash
ssh master "docker service ls | grep web-stress"
# Note the published ports (e.g., 8080, 8081, 8082)
```

#### Step 3: Trigger Different Scenarios Simultaneously
```bash
# Terminal 1: Scenario 1 on service A (migration - high CPU/Mem, low Net)
curl "http://192.168.2.50:8080/stress/combined?cpu=80&memory=1024&network=0&duration=120&ramp=30" &

# Terminal 2: Scenario 2 on service B (scaling - high CPU/Mem/Net)
curl "http://192.168.2.50:8081/stress/combined?cpu=80&memory=1024&network=70&duration=120&ramp=30" &

# Terminal 3: Scenario 1 on service C (migration - high Mem, low CPU/Net)
curl "http://192.168.2.50:8082/stress/combined?cpu=30&memory=1500&network=0&duration=120&ramp=30" &
```

#### Step 4: Monitor Recovery Manager
```bash
ssh master "docker service logs -f recovery-manager"

# Should show:
# [SCENARIO1] Detected on web-stress-a: migrating...
# [SCENARIO2] Detected on web-stress-b: scaling up...
# [SCENARIO1] Detected on web-stress-c: migrating...
```

### Success Criteria
- ✅ All three scenarios detected correctly
- ✅ Service A migrated
- ✅ Service B scaled up
- ✅ Service C migrated
- ✅ No conflicts or race conditions
- ✅ All services remain available

---

## Final Validation Checklist

Use this checklist to confirm all PRD objectives are met:

### Core Objectives
- [ ] **Zero Downtime:** < 2-3 seconds downtime demonstrated (PRD 1.1)
- [ ] **MTTR < 10 seconds:** Proactive recovery faster than baseline (PRD 1.2)
- [ ] **Scenario 1 Works:** Container migration with high CPU/Mem, low Net (PRD 3.1)
- [ ] **Scenario 2 Works:** Horizontal scaling with high CPU/Mem/Net (PRD 3.2)
- [ ] **Load Distribution:** After scaling, load splits proportionally (PRD 5.2)

### Performance Requirements
- [ ] **Monitoring Overhead:** < 5% CPU, < 100MB RAM per agent (PRD 4.1)
- [ ] **Alert Latency:** < 1 second from threshold to manager (PRD 4.1)
- [ ] **Decision Latency:** < 1 second from alert to action (PRD 4.1)
- [ ] **Metric Collection:** Every 5-10 seconds (PRD 4.1)

### System Capabilities
- [ ] **Multi-Node Support:** Works across 5 nodes (PRD 4.3)
- [ ] **20+ Containers:** Can monitor many containers per node (PRD 4.3)
- [ ] **Concurrent Scenarios:** Handles multiple issues simultaneously (PRD 5.2)
- [ ] **Grafana Dashboards:** All metrics visualized clearly (PRD 4.5)

### Testing & Validation
- [ ] **Baseline Comparison:** Proactive vs Reactive MTTR measured (PRD 5.2)
- [ ] **Network Metrics:** Upload/download traffic collected (PRD 2.2.1)
- [ ] **Continuous Availability:** No failed requests during recovery (PRD 8)
- [ ] **MTTR Improvement:** > 50% reduction vs baseline (PRD 8)

---

## Troubleshooting Common Issues

### Issue: Recovery manager not detecting thresholds
**Solution:**
```bash
# Check config.yaml thresholds
ssh master "docker exec $(ssh master 'docker ps -q --filter name=recovery-manager') cat /app/config.yaml"

# Verify monitoring agents are sending alerts
ssh master "docker service logs monitoring-agent-master | grep 'Alert sent'"

# Check recovery manager received alert
ssh master "docker service logs recovery-manager | grep 'Alert received'"
```

### Issue: Migration/scaling not triggering
**Solution:**
```bash
# Check cooldown period
ssh master "docker service logs recovery-manager | grep cooldown"

# Verify consecutive breach count
# Need 2-3 consecutive breaches (30-45 seconds above threshold)

# Manually trigger action for testing
ssh master "docker service update --force web-stress"
```

### Issue: Network metrics still showing zero
**Solution:**
```bash
# Re-read the network fix section from previous conversation
# Verify /sys/class/net mount
ssh master "docker exec $(ssh master 'docker ps -q --filter name=monitoring-agent') ls /host/sys/class/net"

# Should show: enp5s0f0 (not eth0)
```

---

## Next Steps

1. **Run baseline verification** (Phase 1)
2. **Test Scenario 1** (Phase 2) - Record MTTR
3. **Test Scenario 2** (Phase 3) - Verify load distribution
4. **Compare MTTR** (Phase 4) - Demonstrate improvement
5. **Measure overhead** (Phase 5) - Verify < 5% CPU, < 100MB RAM
6. **Test concurrency** (Phase 6) - Multiple scenarios

7. **Generate final report** with:
   - MTTR comparison table
   - Downtime analysis
   - Load distribution graphs
   - Performance metrics
   - Screenshots from Grafana

---

**End of Testing Guide**
