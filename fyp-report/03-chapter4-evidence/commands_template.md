# Chapter 4: Commands to Run for Evidence Collection

**🎯 PURPOSE:** These commands will generate actual data from your SwarmGuard deployment to include in Chapter 4 (Results).

---

## ⚠️ IMPORTANT WORKFLOW

1. **Claude Code** generates this template with commands based on your actual codebase
2. **YOU** run these commands in your actual environment
3. **YOU** paste outputs into `raw_outputs/` files
4. **Claude Chat** uses these outputs when writing Chapter 4
5. **Claude Code** formats the final results

---

## Prerequisites

Before running these commands, ensure:
- [ ] Docker Swarm cluster is running (5 nodes: odin, thor, loki, heimdall, freya)
- [ ] SwarmGuard services deployed (monitoring-agent, recovery-manager)
- [ ] InfluxDB + Grafana accessible
- [ ] Test application (web-stress) deployed
- [ ] Load testing infrastructure ready (4 Raspberry Pi nodes)

---

## Section 1: System Status and Configuration

### 1.1 Cluster Status
```bash
# List all Docker Swarm nodes
docker node ls

# Save output to: raw_outputs/01_cluster_nodes.txt
```

### 1.2 Service Status
```bash
# List all deployed services
docker service ls

# Get detailed service info
docker service ps --no-trunc swarmguard_monitoring-agent
docker service ps --no-trunc swarmguard_recovery-manager
docker service ps --no-trunc web-stress

# Save output to: raw_outputs/02_services_status.txt
```

### 1.3 SwarmGuard Configuration
```bash
# Show current configuration
cat swarmguard/config/swarmguard.yaml

# Save output to: raw_outputs/03_configuration.txt
```

---

## Section 2: Baseline Performance (Docker Swarm Reactive)

### 2.1 Baseline MTTR Measurement

**Purpose:** Measure Docker Swarm's reactive recovery time WITHOUT SwarmGuard

**Steps:**
1. Disable SwarmGuard (scale recovery-manager to 0)
2. Kill a container manually
3. Measure time until Docker restarts it

```bash
# Scale down SwarmGuard
docker service scale swarmguard_recovery-manager=0

# Get a running container ID
CONTAINER_ID=$(docker ps | grep web-stress | head -n 1 | awk '{print $1}')

# Kill container and measure recovery time
echo "Killing container at $(date +%s.%N)" && \
docker kill $CONTAINER_ID && \
docker service ps web-stress --format "{{.Name}} {{.CurrentState}}"

# Manually observe time until replacement container is running
# Record timestamps

# Save observations to: raw_outputs/04_baseline_mttr.txt
```

---

## Section 3: Scenario 1 Testing (Migration)

### 3.1 Scenario 1: CPU Stress (Low Network)

**Purpose:** Test proactive migration when CPU high, network low

**Steps:**
1. Ensure SwarmGuard is running
2. Generate CPU load on one container (call /stress endpoint)
3. Observe proactive migration
4. Record metrics

```bash
# Re-enable SwarmGuard
docker service scale swarmguard_recovery-manager=1

# Identify web-stress container endpoint
WEB_URL="http://<node-ip>:8080"

# Generate CPU stress (low network traffic)
for i in {1..100}; do
  curl $WEB_URL/stress &
done

# Monitor recovery manager logs
docker service logs -f swarmguard_recovery-manager

# Watch for migration events
docker service ps web-stress --no-trunc

# Check InfluxDB for metrics
# (Use Grafana dashboard or InfluxDB CLI)

# Save:
# - Recovery manager logs: raw_outputs/05_scenario1_recovery_logs.txt
# - Service ps output: raw_outputs/06_scenario1_migration_timeline.txt
# - Grafana screenshots: raw_outputs/07_scenario1_grafana.png
```

### 3.2 Scenario 1 MTTR Calculation

**From logs/metrics, extract:**
- Timestamp: Threshold violation detected
- Timestamp: Migration command issued
- Timestamp: New container started
- Timestamp: Old container removed
- **MTTR = (Container running) - (Violation detected)**

**Save to:** `raw_outputs/08_scenario1_mttr_breakdown.txt`

---

## Section 4: Scenario 2 Testing (Auto-Scaling)

### 4.1 Scenario 2: High Traffic Load

**Purpose:** Test auto-scaling when CPU high, network high

**Steps:**
1. Use distributed load testing (4 Raspberry Pi nodes)
2. Generate high concurrent requests
3. Observe scale-up
4. Stop load and observe scale-down

```bash
# On each Raspberry Pi load generator (run in parallel):

# Pi 1:
ab -n 10000 -c 100 http://<swarm-ip>:8080/stress

# Pi 2:
ab -n 10000 -c 100 http://<swarm-ip>:8080/stress

# Pi 3:
ab -n 10000 -c 100 http://<swarm-ip>:8080/stress

# Pi 4:
ab -n 10000 -c 100 http://<swarm-ip>:8080/stress

# Monitor on master node:
watch -n 1 'docker service ls'

# Record:
# - Initial replica count
# - Scale-up event timestamp
# - Peak replica count
# - Scale-down event timestamp (after load stops)
# - Final replica count

# Save:
# - Scale timeline: raw_outputs/09_scenario2_scaling_timeline.txt
# - Apache Bench outputs: raw_outputs/10_scenario2_ab_results.txt
# - Recovery manager logs: raw_outputs/11_scenario2_recovery_logs.txt
```

### 4.2 Scenario 2 Performance Metrics

```bash
# Get scaling speed metrics from logs
docker service logs swarmguard_recovery-manager | grep "scale"

# Save to: raw_outputs/12_scenario2_scaling_speed.txt
```

---

## Section 5: Network Overhead Measurement

### 5.1 Monitoring Agent Network Usage

**Purpose:** Measure network overhead of SwarmGuard

```bash
# On a worker node, measure network traffic
# Before:
BEFORE=$(cat /proc/net/dev | grep eth0 | awk '{print $2, $10}')

# Wait 60 seconds
sleep 60

# After:
AFTER=$(cat /proc/net/dev | grep eth0 | awk '{print $2, $10}')

# Calculate bytes/sec (do this manually or with script)

# Alternatively, use iftop or vnstat:
sudo iftop -i eth0 -t -s 60

# Save to: raw_outputs/13_network_overhead.txt
```

---

## Section 6: Resource Overhead Measurement

### 6.1 Monitoring Agent Resource Usage

```bash
# Get monitoring-agent container stats
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
  $(docker ps | grep monitoring-agent | awk '{print $1}')

# Save to: raw_outputs/14_monitoring_agent_resources.txt
```

### 6.2 Recovery Manager Resource Usage

```bash
# Get recovery-manager container stats
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" \
  $(docker ps | grep recovery-manager | awk '{print $1}')

# Save to: raw_outputs/15_recovery_manager_resources.txt
```

---

## Section 7: Alert Latency Measurement

### 7.1 End-to-End Alert Latency

**Purpose:** Measure time from threshold violation to recovery action

**Method:**
1. Trigger threshold violation (e.g., /stress endpoint)
2. Check timestamps in:
   - Monitoring agent logs (detection time)
   - Recovery manager logs (alert received time)
   - Docker events (action executed time)

```bash
# Monitoring agent logs
docker service logs swarmguard_monitoring-agent --since 5m | grep "ALERT"

# Recovery manager logs
docker service logs swarmguard_recovery-manager --since 5m | grep "received"

# Calculate latency: (Recovery manager received) - (Agent detected)

# Save to: raw_outputs/16_alert_latency.txt
```

---

## Section 8: InfluxDB Query Results

### 8.1 Historical Metrics (for Chapter 4 graphs)

```bash
# Connect to InfluxDB
influx -host <influxdb-ip> -port 8086

# Switch to database
USE swarmguard

# Query average CPU over test period
SELECT mean("cpu_percent") FROM "container_metrics"
WHERE time > now() - 1h
GROUP BY time(10s), "container_name"

# Query average memory
SELECT mean("memory_percent") FROM "container_metrics"
WHERE time > now() - 1h
GROUP BY time(10s), "container_name"

# Query network throughput
SELECT mean("network_mbps") FROM "container_metrics"
WHERE time > now() - 1h
GROUP BY time(10s), "container_name"

# Export to CSV for graphing
influx -database 'swarmguard' -format csv \
  -execute 'SELECT * FROM container_metrics WHERE time > now() - 1h' \
  > raw_outputs/17_influxdb_metrics.csv
```

---

## Section 9: Grafana Dashboard Screenshots

### 9.1 Export Grafana Visualizations

**Purpose:** Visual evidence for Chapter 4

**Steps:**
1. Open Grafana dashboards
2. Set time range to test period
3. Take screenshots of:
   - CPU/Memory/Network over time
   - Alert frequency heatmap
   - Migration timeline
   - Scaling events
   - MTTR comparison graph

**Save as:**
- `raw_outputs/18_grafana_cpu_memory.png`
- `raw_outputs/19_grafana_alerts.png`
- `raw_outputs/20_grafana_migration_timeline.png`
- `raw_outputs/21_grafana_scaling_events.png`
- `raw_outputs/22_grafana_mttr_comparison.png`

---

## Section 10: Comparative Analysis Data

### 10.1 Side-by-Side Comparison

**Create comparison table:**

| Metric | Docker Swarm (Reactive) | SwarmGuard (Proactive) |
|--------|-------------------------|------------------------|
| MTTR (Migration) | [measure] | [measure] |
| Downtime | [measure] | 0-3 seconds |
| Alert Latency | N/A | [measure] |
| Scale-up Speed | N/A | [measure] |
| Network Overhead | 0 | [measure] |
| CPU Overhead | 0 | [measure] |

**Save to:** `raw_outputs/23_comparison_table.txt`

---

## Section 11: Cooldown Validation

### 11.1 Test Cooldown Prevention

**Purpose:** Verify cooldown prevents rapid oscillation

**Steps:**
1. Trigger migration
2. Immediately trigger another violation
3. Verify second violation ignored (within cooldown)
4. Wait 60 seconds
5. Trigger third violation
6. Verify third violation triggers migration

```bash
# Trigger first violation (CPU stress)
curl http://<swarm-ip>:8080/stress

# Wait for migration
sleep 10

# Trigger second violation immediately
curl http://<swarm-ip>:8080/stress

# Check logs - should see "cooldown active, ignoring"
docker service logs swarmguard_recovery-manager | grep cooldown

# Save to: raw_outputs/24_cooldown_validation.txt
```

---

## Section 12: Failure Scenarios (Edge Cases)

### 12.1 Node Failure Simulation

**Purpose:** Test behavior when entire node fails

```bash
# Gracefully drain a worker node
docker node update --availability drain thor

# Observe container migration
docker service ps web-stress

# Re-enable node
docker node update --availability active thor

# Save to: raw_outputs/25_node_failure_test.txt
```

---

## Summary Checklist

After running all commands, you should have:

- [ ] `01_cluster_nodes.txt` - Swarm cluster configuration
- [ ] `02_services_status.txt` - Deployed services
- [ ] `03_configuration.txt` - SwarmGuard config
- [ ] `04_baseline_mttr.txt` - Docker Swarm baseline
- [ ] `05_scenario1_recovery_logs.txt` - Migration logs
- [ ] `06_scenario1_migration_timeline.txt` - Migration events
- [ ] `07_scenario1_grafana.png` - Grafana screenshot
- [ ] `08_scenario1_mttr_breakdown.txt` - MTTR calculation
- [ ] `09_scenario2_scaling_timeline.txt` - Scaling events
- [ ] `10_scenario2_ab_results.txt` - Load test results
- [ ] `11_scenario2_recovery_logs.txt` - Scaling logs
- [ ] `12_scenario2_scaling_speed.txt` - Scale speed metrics
- [ ] `13_network_overhead.txt` - Network usage
- [ ] `14_monitoring_agent_resources.txt` - Agent CPU/RAM
- [ ] `15_recovery_manager_resources.txt` - Manager CPU/RAM
- [ ] `16_alert_latency.txt` - Latency measurements
- [ ] `17_influxdb_metrics.csv` - Time-series data
- [ ] `18-22_grafana_*.png` - Dashboard screenshots
- [ ] `23_comparison_table.txt` - Reactive vs Proactive
- [ ] `24_cooldown_validation.txt` - Cooldown test
- [ ] `25_node_failure_test.txt` - Edge case test

---

## Next Steps

1. **Run commands** in your actual SwarmGuard environment
2. **Save all outputs** to `raw_outputs/` directory
3. **Take screenshots** of Grafana dashboards
4. **Share context** with Claude Chat when writing Chapter 4
5. **Return to Claude Code** for final formatting

---

## Notes

- Some commands may need adjustment based on your actual node names/IPs
- Replace `<node-ip>` and `<swarm-ip>` with actual values
- Run tests multiple times for statistical significance
- Record exact timestamps for MTTR calculations
- Keep raw logs for appendices

---

**This template is generated by Claude Code based on your actual SwarmGuard implementation.**
