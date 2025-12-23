# Chapter 4: ACTUAL Commands for SwarmGuard Testing
## Based on Your Real Setup

**Environment:**
- Master node: `master` (192.168.2.50)
- Worker nodes: `worker-1`, `worker-2`, `worker-3`, `worker-4`
- Alpine load generators: `alpine-1` to `alpine-5`
- Control machine: macOS in lab network
- Registry: `docker-registry.amirmuz.com`

---

## 🔧 SECTION 0: SETUP AND VERIFICATION

### 0.1 Environment Information (Run Once at Start)

**Purpose:** Document your test environment for Chapter 4

```bash
# === RUN ON CONTROL MACOS ===

# Create output directory
mkdir -p raw_outputs
cd raw_outputs

# Docker Swarm cluster info
ssh master "docker version" > 00_docker_version.txt
ssh master "docker info | grep -A 20 'Swarm:'" > 00_swarm_info.txt
ssh master "docker node ls" > 00_cluster_nodes.txt

# Network info
ssh master "docker network ls" > 00_networks.txt

# Current branch/version
git branch --show-current > 00_git_branch.txt
git log -1 --oneline > 00_git_commit.txt

echo "Environment info collected in raw_outputs/"
```

**Expected files created:**
- `00_docker_version.txt`
- `00_swarm_info.txt`
- `00_cluster_nodes.txt`
- `00_networks.txt`
- `00_git_branch.txt`
- `00_git_commit.txt`

---

## 🚀 SECTION 1: CLEAN DEPLOYMENT (Before Each Test Session)

### 1.1 Clean Deployment Script

**Purpose:** Ensure clean state before testing

```bash
# === ON CONTROL MACOS ===

# Record deployment start time
echo "Deployment started: $(date -Iseconds)" > raw_outputs/01_deployment_log.txt

# Remove all services
ssh master "docker service rm \
  monitoring-agent-master \
  monitoring-agent-worker1 \
  monitoring-agent-worker2 \
  monitoring-agent-worker3 \
  monitoring-agent-worker4 \
  recovery-manager \
  intelligent-lb \
  lb-metrics-collector \
  web-stress"

echo "Services removed: $(date -Iseconds)" >> raw_outputs/01_deployment_log.txt
ssh master "docker service ls" >> raw_outputs/01_deployment_log.txt
sleep 10

# Deploy in order
git fetch origin
git reset --hard fix-testing-method-v2
git checkout -f fix-testing-method-v2
git pull

./deployment/create_network.sh
echo "Network created: $(date -Iseconds)" >> raw_outputs/01_deployment_log.txt

./deployment/deploy_recovery_manager.sh
sleep 30
echo "Recovery manager deployed: $(date -Iseconds)" >> raw_outputs/01_deployment_log.txt

./deployment/deploy_monitoring_agents.sh
sleep 30
echo "Monitoring agents deployed: $(date -Iseconds)" >> raw_outputs/01_deployment_log.txt

./tests/deploy_load_balancer.sh lease
sleep 15
echo "Load balancer deployed: $(date -Iseconds)" >> raw_outputs/01_deployment_log.txt

./monitoring/deploy_lb_metrics_collector.sh
sleep 10
echo "LB metrics collector deployed: $(date -Iseconds)" >> raw_outputs/01_deployment_log.txt

./tests/deploy_web_stress.sh 1 30
echo "Web-stress deployed: $(date -Iseconds)" >> raw_outputs/01_deployment_log.txt

# Final service list
ssh master "docker service ls" >> raw_outputs/01_deployment_log.txt
echo "Deployment completed: $(date -Iseconds)" >> raw_outputs/01_deployment_log.txt

# Verify all services healthy
echo "=== Health Checks ===" >> raw_outputs/01_deployment_log.txt
curl -s http://192.168.2.50:8081/health | jq . >> raw_outputs/01_deployment_log.txt
curl -s http://192.168.2.50:8081/metrics | jq .replica_stats >> raw_outputs/01_deployment_log.txt
curl -s http://192.168.2.50:8080/health | jq . >> raw_outputs/01_deployment_log.txt
curl -s http://worker-1:8082/health | jq . >> raw_outputs/01_deployment_log.txt

echo "All services deployed and verified!"
```

**File created:** `01_deployment_log.txt`

---

## 📊 SECTION 2: BASELINE (Docker Swarm Reactive Recovery)

### 2.1 Test Reactive Recovery WITHOUT SwarmGuard

**Purpose:** Establish baseline MTTR for comparison

**Step 1: Disable SwarmGuard**
```bash
# === ON CONTROL MACOS ===

# Scale down recovery manager (disables proactive recovery)
ssh master "docker service scale recovery-manager=0"
ssh master "docker service scale monitoring-agent-master=0"
ssh master "docker service scale monitoring-agent-worker1=0"
ssh master "docker service scale monitoring-agent-worker2=0"
ssh master "docker service scale monitoring-agent-worker3=0"
ssh master "docker service scale monitoring-agent-worker4=0"

# Verify SwarmGuard disabled
ssh master "docker service ls" > raw_outputs/02_baseline_services_disabled.txt
echo "SwarmGuard disabled for baseline testing"
```

**Step 2: Continuous Availability Monitor**
```bash
# Start availability monitoring in background
while sleep 0.1; do
  ts=$(date -Iseconds)
  code=$(curl -sf --connect-timeout 0.5 -m 1 -o /dev/null -w '%{http_code}' http://192.168.2.50:8080/health 2>/dev/null || echo "DOWN")
  echo "$ts $code"
done | tee raw_outputs/02_baseline_mttr_test1.log &

# Save PID
echo $! > /tmp/mttr_monitor.pid
echo "Availability monitoring started (PID: $(cat /tmp/mttr_monitor.pid))"
```

**Step 3: Inject Failure (Container Kill)**
```bash
# Wait 30 seconds for baseline
sleep 30

# Get container ID
CONTAINER_ID=$(ssh master "docker ps | grep web-stress | head -n 1 | awk '{print \$1}'")
echo "Target container: $CONTAINER_ID" >> raw_outputs/02_baseline_mttr_test1.log

# Record failure injection time
echo "FAILURE_INJECTED: $(date -Iseconds)" >> raw_outputs/02_baseline_mttr_test1.log

# Kill container
ssh master "docker kill $CONTAINER_ID"

# Wait for Docker Swarm to recover (reactive)
echo "Waiting for Docker Swarm reactive recovery..."
sleep 60

# Stop monitoring
kill $(cat /tmp/mttr_monitor.pid)
echo "MONITORING_STOPPED: $(date -Iseconds)" >> raw_outputs/02_baseline_mttr_test1.log
```

**Step 4: Capture Service Events**
```bash
# Get service recovery timeline
ssh master "docker service ps web-stress --no-trunc" > raw_outputs/02_baseline_recovery_timeline.txt
```

**Step 5: Repeat 10 Times for Statistical Validity**
```bash
# Run baseline test 10 times
for i in {1..10}; do
  echo "=== Baseline Test $i/10 ==="

  # Reset: Deploy fresh web-stress
  ssh master "docker service rm web-stress"
  sleep 10
  ./tests/deploy_web_stress.sh 1 30
  sleep 30

  # Start monitoring
  while sleep 0.1; do
    ts=$(date -Iseconds)
    code=$(curl -sf --connect-timeout 0.5 -m 1 -o /dev/null -w '%{http_code}' http://192.168.2.50:8080/health 2>/dev/null || echo "DOWN")
    echo "$ts $code"
  done > raw_outputs/02_baseline_mttr_test${i}.log &
  MONITOR_PID=$!

  sleep 30

  # Kill container
  CONTAINER_ID=$(ssh master "docker ps | grep web-stress | head -n 1 | awk '{print \$1}'")
  echo "Test $i - FAILURE_INJECTED: $(date -Iseconds)" >> raw_outputs/02_baseline_mttr_test${i}.log
  ssh master "docker kill $CONTAINER_ID"

  # Wait for recovery
  sleep 60

  # Stop monitoring
  kill $MONITOR_PID
  echo "Test $i - MONITORING_STOPPED: $(date -Iseconds)" >> raw_outputs/02_baseline_mttr_test${i}.log

  # Capture timeline
  ssh master "docker service ps web-stress --no-trunc" > raw_outputs/02_baseline_recovery_timeline_test${i}.txt

  sleep 30  # Cooldown
done

echo "Baseline testing complete! Check raw_outputs/02_baseline_*"
```

**Files created:**
- `02_baseline_services_disabled.txt`
- `02_baseline_mttr_test1.log` through `02_baseline_mttr_test10.log`
- `02_baseline_recovery_timeline_test1.txt` through `02_baseline_recovery_timeline_test10.txt`

**What to calculate later:**
- MTTR = Time between "FAILURE_INJECTED" and first "200" after "DOWN"
- Average MTTR across 10 tests
- Standard deviation

---

## 🔄 SECTION 3: SCENARIO 1 - PROACTIVE MIGRATION (Node/Container Problem)

### 3.1 Re-enable SwarmGuard

```bash
# === ON CONTROL MACOS ===

# Scale up recovery manager and monitoring agents
ssh master "docker service scale recovery-manager=1"
ssh master "docker service scale monitoring-agent-master=1"
ssh master "docker service scale monitoring-agent-worker1=1"
ssh master "docker service scale monitoring-agent-worker2=1"
ssh master "docker service scale monitoring-agent-worker3=1"
ssh master "docker service scale monitoring-agent-worker4=1"

sleep 60  # Wait for all agents to be healthy

# Verify SwarmGuard enabled
ssh master "docker service ls" > raw_outputs/03_scenario1_services_enabled.txt
echo "SwarmGuard enabled for Scenario 1 testing"
```

### 3.2 Scenario 1 Test: High CPU/Memory, Low Network (Proactive Migration)

**Purpose:** Test proactive container migration

**Step 1: Start Monitoring**
```bash
# Continuous availability monitor
while sleep 0.1; do
  ts=$(date -Iseconds)
  code=$(curl -sf --connect-timeout 0.5 -m 1 -o /dev/null -w '%{http_code}' http://192.168.2.50:8080/health 2>/dev/null || echo "DOWN")
  echo "$ts $code"
done > raw_outputs/03_scenario1_availability_test1.log &
AVAIL_PID=$!

# Service status monitor
watch -n 1 'docker service ps web-stress --format "table {{.Name}}\t{{.Node}}\t{{.DesiredState}}\t{{.CurrentState}}\t{{.Error}}" | head -n 30' > raw_outputs/03_scenario1_service_status_test1.log &
STATUS_PID=$!

echo "Monitoring started (Availability PID: $AVAIL_PID, Status PID: $STATUS_PID)"
```

**Step 2: Trigger High CPU (Low Network)**
```bash
# Baseline period
sleep 30

# Record trigger time
echo "SCENARIO1_TRIGGERED: $(date -Iseconds)" >> raw_outputs/03_scenario1_availability_test1.log

# Trigger high CPU stress (this should cause MIGRATION, not scaling)
# Use internal stress endpoint (low network traffic)
curl "http://192.168.2.50:8080/stress/cpu?duration=120&intensity=high"

# Note: Your monitoring agents should detect high CPU + low network
# Recovery manager should decide: MIGRATE (not scale)
```

**Step 3: Monitor Recovery Manager Logs**
```bash
# Capture recovery manager decision logs
ssh master "docker service logs recovery-manager --since 5m" > raw_outputs/03_scenario1_recovery_logs_test1.txt &

# Wait for migration to complete
sleep 180
```

**Step 4: Stop Monitoring and Capture Results**
```bash
# Stop monitoring
kill $AVAIL_PID
kill $STATUS_PID
echo "MONITORING_STOPPED: $(date -Iseconds)" >> raw_outputs/03_scenario1_availability_test1.log

# Final service state
ssh master "docker service ps web-stress --no-trunc" > raw_outputs/03_scenario1_final_state_test1.txt

# Load balancer distribution
curl -s http://192.168.2.50:8081/metrics | jq . > raw_outputs/03_scenario1_lb_metrics_test1.json
```

**Step 5: Repeat 5 Times**
```bash
for i in {1..5}; do
  echo "=== Scenario 1 Test $i/5 ==="

  # Clean state
  curl "http://192.168.2.50:8080/stress/stop"
  sleep 30

  # Start monitoring
  while sleep 0.1; do
    ts=$(date -Iseconds)
    code=$(curl -sf --connect-timeout 0.5 -m 1 -o /dev/null -w '%{http_code}' http://192.168.2.50:8080/health 2>/dev/null || echo "DOWN")
    echo "$ts $code"
  done > raw_outputs/03_scenario1_availability_test${i}.log &
  AVAIL_PID=$!

  sleep 30

  # Trigger
  echo "Test $i - SCENARIO1_TRIGGERED: $(date -Iseconds)" >> raw_outputs/03_scenario1_availability_test${i}.log
  curl "http://192.168.2.50:8080/stress/cpu?duration=120&intensity=high"

  # Capture logs
  ssh master "docker service logs recovery-manager --since 5m" > raw_outputs/03_scenario1_recovery_logs_test${i}.txt &

  sleep 180

  # Stop and capture
  kill $AVAIL_PID
  echo "Test $i - MONITORING_STOPPED: $(date -Iseconds)" >> raw_outputs/03_scenario1_availability_test${i}.log
  ssh master "docker service ps web-stress --no-trunc" > raw_outputs/03_scenario1_final_state_test${i}.txt
  curl -s http://192.168.2.50:8081/metrics | jq . > raw_outputs/03_scenario1_lb_metrics_test${i}.json

  sleep 60  # Cooldown
done

echo "Scenario 1 testing complete!"
```

**Files created:**
- `03_scenario1_services_enabled.txt`
- `03_scenario1_availability_test1.log` to `test5.log`
- `03_scenario1_recovery_logs_test1.txt` to `test5.txt`
- `03_scenario1_final_state_test1.txt` to `test5.txt`
- `03_scenario1_lb_metrics_test1.json` to `test5.json`

**What to analyze later:**
- Did migration occur? (check recovery logs for "MIGRATE" decision)
- MTTR for migration
- Downtime during migration (should be 0-3 seconds)
- Which node → which node migration

---

## 📈 SECTION 4: SCENARIO 2 - HORIZONTAL AUTOSCALING (High Traffic)

### 4.1 Scenario 2 Test: High CPU/Memory + High Network (Scale Up)

**Purpose:** Test proactive horizontal autoscaling

**Step 1: Clean State**
```bash
# === ON CONTROL MACOS ===

# Stop all stress
curl "http://192.168.2.50:8080/stress/stop"

# Kill all wget on Alpine nodes
for alpine in alpine-1 alpine-2 alpine-3 alpine-4 alpine-5; do
  echo "Cleaning $alpine..."
  ssh "$alpine" "pkill -9 -f wget" || true
  ssh "$alpine" "pkill -9 -f scenario2" || true
done

# Wait for traffic to stop
sleep 20

# Verify baseline: 1 replica
ssh master "docker service ls | grep web-stress" > raw_outputs/04_scenario2_baseline_state.txt
```

**Step 2: Start Monitoring**
```bash
# Availability monitor
while sleep 0.1; do
  ts=$(date -Iseconds)
  code=$(curl -sf --connect-timeout 0.5 -m 1 -o /dev/null -w '%{http_code}' http://192.168.2.50:8080/health 2>/dev/null || echo "DOWN")
  echo "$ts $code"
done > raw_outputs/04_scenario2_availability_test1.log &
AVAIL_PID=$!

# Replica count monitor (captures scaling events)
while sleep 2; do
  ts=$(date -Iseconds)
  replicas=$(ssh master "docker service ls | grep web-stress | awk '{print \$4}'")
  echo "$ts REPLICAS=$replicas"
done > raw_outputs/04_scenario2_replica_timeline_test1.log &
REPLICA_PID=$!

# Load balancer metrics (distribution across replicas)
while sleep 5; do
  ts=$(date -Iseconds)
  curl -s http://192.168.2.50:8081/metrics | jq -c "{time: \"$ts\", stats: .replica_stats}"
done > raw_outputs/04_scenario2_lb_timeline_test1.jsonl &
LB_PID=$!

echo "Monitoring started (Avail: $AVAIL_PID, Replicas: $REPLICA_PID, LB: $LB_PID)"
```

**Step 3: Trigger High Traffic Load**
```bash
# Baseline period
sleep 30

# Record trigger time
echo "SCENARIO2_TRIGGERED: $(date -Iseconds)" >> raw_outputs/04_scenario2_availability_test1.log
echo "SCENARIO2_TRIGGERED: $(date -Iseconds)" >> raw_outputs/04_scenario2_replica_timeline_test1.log

# Run balanced load scenario (high network traffic)
./tests/scenario2_ultimate.sh 10 2 1 25 2 5 6000
#                             │  │  │  │  │  │  │
#                             │  │  │  │  │  │  └─ Hold: 100 min (6000s)
#                             │  │  │  │  │  └─ Ramp: 5s
#                             │  │  │  │  └─ Stagger: 2s between Alpines
#                             │  │  │  └─ Network: 25 Mbps (HIGH)
#                             │  │  └─ Memory: 1%
#                             │  └─ CPU: 2%
#                             └─ Users: 10 per Alpine (50 total)

# Note: High network should trigger SCALING, not migration
```

**Step 4: Capture Recovery Manager Logs**
```bash
# Monitor recovery decisions in real-time
ssh master "docker service logs recovery-manager --follow" > raw_outputs/04_scenario2_recovery_logs_test1.txt &
RECOVERY_LOG_PID=$!
```

**Step 5: Wait for Scaling Events**
```bash
# Let test run for 10 minutes to observe:
# - Scale-up events
# - Load distribution
# - Scale-down after traffic stops

echo "Waiting 10 minutes for scaling behavior..."
sleep 600

# Stop traffic
curl "http://192.168.2.50:8080/stress/stop"
for alpine in alpine-1 alpine-2 alpine-3 alpine-4 alpine-5; do
  ssh "$alpine" "pkill -9 -f wget" || true
done

echo "Traffic stopped. Waiting for scale-down..."
sleep 300  # Wait 5 more minutes to observe scale-down
```

**Step 6: Stop Monitoring and Capture Final State**
```bash
# Stop all monitoring
kill $AVAIL_PID
kill $REPLICA_PID
kill $LB_PID
kill $RECOVERY_LOG_PID

echo "MONITORING_STOPPED: $(date -Iseconds)" >> raw_outputs/04_scenario2_availability_test1.log
echo "MONITORING_STOPPED: $(date -Iseconds)" >> raw_outputs/04_scenario2_replica_timeline_test1.log

# Final state
ssh master "docker service ps web-stress --no-trunc" > raw_outputs/04_scenario2_final_state_test1.txt
ssh master "docker service ls | grep web-stress" >> raw_outputs/04_scenario2_final_state_test1.txt
curl -s http://192.168.2.50:8081/metrics | jq . > raw_outputs/04_scenario2_final_lb_metrics_test1.json
```

**Step 7: Repeat 3 Times**
```bash
for i in {1..3}; do
  echo "=== Scenario 2 Test $i/3 ==="

  # Clean
  curl "http://192.168.2.50:8080/stress/stop"
  for alpine in alpine-1 alpine-2 alpine-3 alpine-4 alpine-5; do
    ssh "$alpine" "pkill -9 -f wget" || true
  done
  sleep 60

  # Start monitoring
  while sleep 0.1; do
    ts=$(date -Iseconds)
    code=$(curl -sf --connect-timeout 0.5 -m 1 -o /dev/null -w '%{http_code}' http://192.168.2.50:8080/health 2>/dev/null || echo "DOWN")
    echo "$ts $code"
  done > raw_outputs/04_scenario2_availability_test${i}.log &
  AVAIL_PID=$!

  while sleep 2; do
    ts=$(date -Iseconds)
    replicas=$(ssh master "docker service ls | grep web-stress | awk '{print \$4}'")
    echo "$ts REPLICAS=$replicas"
  done > raw_outputs/04_scenario2_replica_timeline_test${i}.log &
  REPLICA_PID=$!

  while sleep 5; do
    ts=$(date -Iseconds)
    curl -s http://192.168.2.50:8081/metrics | jq -c "{time: \"$ts\", stats: .replica_stats}"
  done > raw_outputs/04_scenario2_lb_timeline_test${i}.jsonl &
  LB_PID=$!

  sleep 30

  # Trigger
  echo "Test $i - SCENARIO2_TRIGGERED: $(date -Iseconds)" >> raw_outputs/04_scenario2_availability_test${i}.log
  ./tests/scenario2_ultimate.sh 10 2 1 25 2 5 600  # 10 min hold

  ssh master "docker service logs recovery-manager --follow" > raw_outputs/04_scenario2_recovery_logs_test${i}.txt &
  RECOVERY_LOG_PID=$!

  sleep 600

  # Stop traffic
  curl "http://192.168.2.50:8080/stress/stop"
  for alpine in alpine-1 alpine-2 alpine-3 alpine-4 alpine-5; do
    ssh "$alpine" "pkill -9 -f wget" || true
  done

  sleep 300  # Scale-down observation

  # Stop monitoring
  kill $AVAIL_PID $REPLICA_PID $LB_PID $RECOVERY_LOG_PID

  # Capture final
  ssh master "docker service ps web-stress --no-trunc" > raw_outputs/04_scenario2_final_state_test${i}.txt
  curl -s http://192.168.2.50:8081/metrics | jq . > raw_outputs/04_scenario2_final_lb_metrics_test${i}.json

  sleep 120  # Cooldown
done

echo "Scenario 2 testing complete!"
```

**Files created:**
- `04_scenario2_baseline_state.txt`
- `04_scenario2_availability_test1.log` to `test3.log`
- `04_scenario2_replica_timeline_test1.log` to `test3.log`
- `04_scenario2_lb_timeline_test1.jsonl` to `test3.jsonl`
- `04_scenario2_recovery_logs_test1.txt` to `test3.txt`
- `04_scenario2_final_state_test1.txt` to `test3.txt`
- `04_scenario2_final_lb_metrics_test1.json` to `test3.json`

**What to analyze later:**
- Did scaling occur? (check recovery logs for "SCALE_UP" decision)
- Time from trigger to first scale-up
- Peak replica count reached
- Scale-down behavior (cooldown period observed?)
- Load distribution across replicas (from LB metrics)

---

## 📊 SECTION 5: METRICS COLLECTION (For Performance Analysis)

### 5.1 Resource Overhead Measurement

**Purpose:** Measure SwarmGuard's own resource consumption

```bash
# === ON CONTROL MACOS ===

# Measure SwarmGuard components resource usage
ssh master "docker stats --no-stream --format 'table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}'" | grep -E "(recovery-manager|monitoring-agent)" > raw_outputs/05_swarmguard_overhead.txt

# Measure for 5 minutes with sampling
for i in {1..60}; do
  ts=$(date -Iseconds)
  ssh master "docker stats --no-stream --format 'table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}'" | grep -E "(recovery-manager|monitoring-agent)" | sed "s/^/$ts /"
  sleep 5
done > raw_outputs/05_swarmguard_overhead_timeseries.txt

echo "Resource overhead data collected!"
```

### 5.2 Alert Latency Measurement

**Purpose:** Measure time from threshold breach to recovery action

**This data comes from recovery manager logs:**
```bash
# Extract timestamps from recovery logs (do this AFTER tests)
# Format: [timestamp] ALERT_RECEIVED → [timestamp] ACTION_EXECUTED
# We'll analyze this later
```

---

## 📋 SECTION 6: DATA EXPORT FROM GRAFANA/INFLUXDB

### 6.1 Export InfluxDB Metrics

**Purpose:** Export time-series data for graphs in Chapter 4

```bash
# === ON CONTROL MACOS (or wherever InfluxDB is accessible) ===

# Assuming InfluxDB at 192.168.2.51:8086 (adjust if different)
INFLUX_HOST="192.168.2.51"
INFLUX_PORT="8086"
INFLUX_DB="swarmguard"

# Export CPU metrics
curl -G "http://${INFLUX_HOST}:${INFLUX_PORT}/query" \
  --data-urlencode "db=${INFLUX_DB}" \
  --data-urlencode "q=SELECT time, container_name, value FROM cpu_usage WHERE time > now() - 1h" \
  --data-urlencode "format=csv" > raw_outputs/06_influx_cpu_metrics.csv

# Export memory metrics
curl -G "http://${INFLUX_HOST}:${INFLUX_PORT}/query" \
  --data-urlencode "db=${INFLUX_DB}" \
  --data-urlencode "q=SELECT time, container_name, value FROM memory_usage WHERE time > now() - 1h" \
  --data-urlencode "format=csv" > raw_outputs/06_influx_memory_metrics.csv

# Export network metrics
curl -G "http://${INFLUX_HOST}:${INFLUX_PORT}/query" \
  --data-urlencode "db=${INFLUX_DB}" \
  --data-urlencode "q=SELECT time, container_name, value FROM network_io WHERE time > now() - 1h" \
  --data-urlencode "format=csv" > raw_outputs/06_influx_network_metrics.csv

echo "InfluxDB metrics exported!"
```

### 6.2 Grafana Screenshots

**Manual step:**
1. Open Grafana dashboard
2. Set time range to your test period
3. Take screenshots:
   - CPU/Memory/Network graph → `07_grafana_metrics.png`
   - Scaling events timeline → `07_grafana_scaling.png`
   - Load balancer distribution → `07_grafana_lb_distribution.png`

---

## ✅ FINAL CHECKLIST

After running all commands, verify you have:

### Baseline (Section 2):
- [ ] `02_baseline_services_disabled.txt`
- [ ] `02_baseline_mttr_test1.log` through `test10.log` (10 files)
- [ ] `02_baseline_recovery_timeline_test1.txt` through `test10.txt` (10 files)

### Scenario 1 (Section 3):
- [ ] `03_scenario1_services_enabled.txt`
- [ ] `03_scenario1_availability_test1.log` through `test5.log` (5 files)
- [ ] `03_scenario1_recovery_logs_test1.txt` through `test5.txt` (5 files)
- [ ] `03_scenario1_final_state_test1.txt` through `test5.txt` (5 files)
- [ ] `03_scenario1_lb_metrics_test1.json` through `test5.json` (5 files)

### Scenario 2 (Section 4):
- [ ] `04_scenario2_baseline_state.txt`
- [ ] `04_scenario2_availability_test1.log` through `test3.log` (3 files)
- [ ] `04_scenario2_replica_timeline_test1.log` through `test3.log` (3 files)
- [ ] `04_scenario2_lb_timeline_test1.jsonl` through `test3.jsonl` (3 files)
- [ ] `04_scenario2_recovery_logs_test1.txt` through `test3.txt` (3 files)
- [ ] `04_scenario2_final_state_test1.txt` through `test3.txt` (3 files)
- [ ] `04_scenario2_final_lb_metrics_test1.json` through `test3.json` (3 files)

### Metrics (Section 5-6):
- [ ] `05_swarmguard_overhead.txt`
- [ ] `05_swarmguard_overhead_timeseries.txt`
- [ ] `06_influx_cpu_metrics.csv`
- [ ] `06_influx_memory_metrics.csv`
- [ ] `06_influx_network_metrics.csv`
- [ ] `07_grafana_metrics.png`
- [ ] `07_grafana_scaling.png`
- [ ] `07_grafana_lb_distribution.png`

**Total expected files:** ~60 files

---

## 🎯 NEXT STEPS AFTER DATA COLLECTION

Once you have all files in `raw_outputs/`:

1. **Compress and share:**
   ```bash
   cd fyp-report/03-chapter4-evidence
   tar -czf raw_outputs.tar.gz raw_outputs/
   ```

2. **Tell Claude Code:** "I have collected all experimental data. Analyze `raw_outputs/` and generate Chapter 4."

3. **Claude Code will:**
   - Parse all log files
   - Calculate MTTR statistics
   - Generate comparison tables
   - Create LaTeX graphs
   - Write Chapter 4 with REAL data (no hallucination!)

---

**Ready to start testing? Begin with Section 0 (environment info), then Section 2 (baseline)!**
