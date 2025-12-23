# SwarmGuard - Technical Summary

**🎯 PURPOSE:** Quick reference for technical architecture and implementation details. Use this when writing Chapter 3 (Methodology) in Claude Chat.

---

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Swarm Cluster                      │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌──────────┐ │
│  │  Worker 1 │  │  Worker 2 │  │  Worker 3 │  │ Worker 4 │ │
│  │  (thor)   │  │  (loki)   │  │(heimdall) │  │ (freya)  │ │
│  │           │  │           │  │           │  │          │ │
│  │ [Mon Agt] │  │ [Mon Agt] │  │ [Mon Agt] │  │[Mon Agt] │ │
│  │ [App]     │  │ [App]     │  │ [App]     │  │ [App]    │ │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └────┬─────┘ │
│        │              │              │             │        │
│        └──────────────┴──────────────┴─────────────┘        │
│                       │ Metrics + Alerts                    │
│                       ▼                                      │
│        ┌──────────────────────────────────┐                 │
│        │    Recovery Manager (odin)       │                 │
│        │  - Decision Engine               │                 │
│        │  - Docker Swarm API Client       │                 │
│        │  - Alert Receiver                │                 │
│        └────────────┬─────────────────────┘                 │
│                     │ Actions                               │
│                     ▼                                        │
│        ┌──────────────────────────────────┐                 │
│        │   Docker Swarm Manager (odin)    │                 │
│        │  - Service Updates               │                 │
│        │  - Container Placement           │                 │
│        └──────────────────────────────────┘                 │
└─────────────────────────────────────────────────────────────┘

                           │ Metrics (batched)
                           ▼
              ┌─────────────────────────┐
              │  Raspberry Pi           │
              │  ┌──────────────────┐   │
              │  │ InfluxDB         │   │
              │  │ (Time-series DB) │   │
              │  └────────┬─────────┘   │
              │           │              │
              │  ┌────────▼─────────┐   │
              │  │ Grafana          │   │
              │  │ (Visualization)  │   │
              │  └──────────────────┘   │
              └─────────────────────────┘
```

---

## Component Details

### 1. Monitoring Agent (Go)

**Location:** Runs on each Docker Swarm worker node
**Language:** Go (chosen for lightweight concurrency)

**Responsibilities:**
- Collect real-time container metrics (CPU, memory, network I/O)
- Detect threshold violations using rule-based logic
- Send immediate alerts to Recovery Manager (event-driven)
- Batch metrics to InfluxDB for historical analysis

**Key Features:**
- **Docker Stats API:** Uses Docker's native stats stream
- **Sub-second detection:** Continuous monitoring with instant violation detection
- **Event-driven alerts:** Direct HTTP POST to Recovery Manager
- **Low overhead:** ~3% CPU, ~50MB RAM per node
- **Network-optimized:** Alert payloads < 1KB, batched metrics every 10 seconds

**Threshold Configuration (swarmguard.yaml):**
```yaml
thresholds:
  cpu_percent: 70
  memory_percent: 70
  network_mbps: 10
  consecutive_breaches: 2
```

---

### 2. Recovery Manager (Python)

**Location:** Runs on Docker Swarm manager node (odin)
**Language:** Python with Docker SDK

**Responsibilities:**
- Receive alerts from monitoring agents
- Analyze metrics + network state to determine scenario
- Execute recovery actions (migration or scaling)
- Manage cooldown periods to prevent flapping
- Expose health check endpoints

**Decision Logic:**
```python
if (cpu > 70% OR memory > 70%) AND network < 10 Mbps:
    → Scenario 1: Node/Container Problem
    → Action: Migrate to different node

if (cpu > 70% OR memory > 70%) AND network >= 10 Mbps:
    → Scenario 2: High Traffic
    → Action: Scale up replicas
```

**Cooldown Management:**
- Migration cooldown: 60 seconds
- Scale-down cooldown: 180 seconds
- Prevents rapid oscillation between states

**Key API Endpoints:**
- `POST /alert` - Receive alerts from monitoring agents
- `GET /health` - Health check
- `GET /status` - System status and statistics

---

### 3. Test Application (Node.js)

**Location:** Deployed as Docker Swarm service (web-stress)
**Language:** Node.js (Express)

**Purpose:**
- Controllable test application for scenario validation
- Simulates CPU-intensive operations
- Configurable resource consumption
- Health check endpoint

**Key Endpoints:**
- `GET /` - Normal response (low CPU)
- `GET /stress` - CPU-intensive fibonacci calculation
- `GET /health` - Health check (for Docker Swarm)

**Docker Swarm Configuration:**
```yaml
services:
  web-stress:
    image: ghcr.io/username/web-stress:latest
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first
```

---

### 4. Observability Stack

**InfluxDB (Time-series Database):**
- **Location:** Raspberry Pi (separate from Swarm cluster)
- **Purpose:** Store historical metrics for trend analysis
- **Data retention:** Configurable (default: 30 days)
- **Write frequency:** Batched every 10 seconds from agents

**Grafana (Visualization):**
- **Location:** Raspberry Pi (same host as InfluxDB)
- **Purpose:** Real-time dashboards and alerting
- **Dashboards:**
  - Container CPU/Memory/Network metrics
  - Recovery action timeline
  - Alert frequency heatmaps
  - MTTR tracking

---

## Data Flow

### Normal Operation (No Threshold Violation):
```
Monitoring Agent
  ├─> Collect metrics every 1 second (Docker Stats API)
  ├─> Check thresholds (CPU, Memory, Network)
  ├─> NO violation → Continue monitoring
  └─> Batch metrics → InfluxDB every 10 seconds
```

### Scenario 1: Migration (Node/Container Problem):
```
Monitoring Agent
  ├─> Detect: CPU 80%, Memory 75%, Network 0.5 MB/s
  ├─> Consecutive breach count: 2
  └─> HTTP POST alert → Recovery Manager

Recovery Manager
  ├─> Receive alert
  ├─> Analyze: High resources + Low network → Scenario 1
  ├─> Check cooldown: OK (60s elapsed since last action)
  ├─> Action: Migrate container
  └─> Execute:
      1. Get current node (e.g., "thor")
      2. Select target node (e.g., "loki")
      3. Add constraint: node.hostname==loki
      4. Docker service update --force (triggers rolling update)
      5. Docker removes container from thor
      6. Docker starts new container on loki
      7. Start cooldown timer (60s)

Result: MTTR 6.08 seconds, zero downtime
```

### Scenario 2: Scaling (High Traffic):
```
Monitoring Agent
  ├─> Detect: CPU 85%, Memory 80%, Network 15 MB/s
  ├─> Consecutive breach count: 2
  └─> HTTP POST alert → Recovery Manager

Recovery Manager
  ├─> Receive alert
  ├─> Analyze: High resources + High network → Scenario 2
  ├─> Check cooldown: OK
  ├─> Action: Scale up
  └─> Execute:
      1. Get current replicas (e.g., 3)
      2. Increment: replicas = 3 + 1 = 4
      3. Docker service scale web-stress=4
      4. Docker starts new container on available node

When traffic subsides:
  ├─> Detect: All containers below threshold
  ├─> Check scale-down cooldown: OK (180s elapsed)
  ├─> Action: Scale down to 3 replicas
  └─> Docker service scale web-stress=3
```

---

## Key Algorithms

### 1. Zero-Downtime Migration Algorithm

```
Input: container_id, service_name
Output: Migrated container on different node

1. Get current container's node: current_node = get_node(container_id)
2. Get all available nodes: available_nodes = get_cluster_nodes()
3. Select target: target_node = select_target(available_nodes - current_node)
4. Add placement constraint:
   constraint = f"node.hostname=={target_node}"
5. Force rolling update:
   docker service update --force --constraint-add {constraint} {service_name}
6. Docker Swarm executes:
   a. Start new container on target_node (start-first ordering)
   b. Wait for health check to pass
   c. Drain connections from old container
   d. Remove old container from current_node
7. Return: migration_time, target_node
```

**Critical Configuration:**
- `update_config.order: start-first` → New container starts before old one stops
- `update_config.parallelism: 1` → One container at a time
- `update_config.delay: 10s` → Wait between updates

---

### 2. Scenario Classification Algorithm

```
Input: cpu_percent, memory_percent, network_mbps

1. Check resource threshold violation:
   resource_violation = (cpu_percent > 70) OR (memory_percent > 70)

2. If NOT resource_violation:
   return NO_ACTION

3. Classify network state:
   high_network = (network_mbps >= 10)

4. Determine scenario:
   if resource_violation AND NOT high_network:
      return SCENARIO_1_MIGRATION
   elif resource_violation AND high_network:
      return SCENARIO_2_SCALING
   else:
      return NO_ACTION
```

---

### 3. Cooldown Management Algorithm

```
State:
  last_migration_time = None
  last_scale_up_time = None
  last_scale_down_time = None

Constants:
  MIGRATION_COOLDOWN = 60 seconds
  SCALE_DOWN_COOLDOWN = 180 seconds

Function: can_execute_action(action_type):
  current_time = now()

  if action_type == MIGRATION:
    if last_migration_time is None:
      return True
    elapsed = current_time - last_migration_time
    return elapsed >= MIGRATION_COOLDOWN

  elif action_type == SCALE_UP:
    return True  # No cooldown for scale-up

  elif action_type == SCALE_DOWN:
    if last_scale_down_time is None:
      return True
    elapsed = current_time - last_scale_down_time
    return elapsed >= SCALE_DOWN_COOLDOWN
```

---

## Network Optimization Strategies

### Problem: 100Mbps Legacy Network Constraints
Our cluster uses old 100Mbps switches. Continuous metrics streaming would saturate the network.

### Solutions Implemented:

1. **Event-driven alerts (real-time):**
   - Only send alert when threshold violated
   - Payload size: < 1KB per alert
   - Frequency: Only when violations occur (rare)

2. **Batched metrics (observability):**
   - Batch 10 seconds of metrics into single InfluxDB write
   - Compression and aggregation
   - Result: < 0.5 Mbps overhead

3. **Direct HTTP communication:**
   - Agents → Recovery Manager: Direct HTTP POST
   - No polling overhead
   - No message broker intermediary
   - Latency: 7-9 milliseconds

---

## Technology Choices and Justifications

### Go for Monitoring Agent
**Why:** Lightweight, excellent concurrency, low memory footprint
**Alternative considered:** Python (rejected: higher memory, slower)

### Python for Recovery Manager
**Why:** Rich Docker SDK, rapid development, excellent for orchestration logic
**Alternative considered:** Go (rejected: more complex for Docker API interaction)

### InfluxDB for Metrics
**Why:** Purpose-built for time-series data, efficient storage, Grafana integration
**Alternative considered:** Redis (rejected: not optimized for time-series)

### Docker Swarm (not Kubernetes)
**Why:** Project scope, simpler for SMEs, built-in rolling updates
**Note:** SwarmGuard is Swarm-specific, not portable to K8s

---

## Testing Infrastructure

### Physical Hardware:
- **Master node (odin):** Intel machine, Docker Swarm manager
- **Worker nodes (thor, loki, heimdall, freya):** Intel machines, Swarm workers
- **Monitoring Pi:** Raspberry Pi 4, InfluxDB + Grafana
- **Load generators:** 4x Raspberry Pi 1.2B+ (Alpine Linux, Apache Bench)

### Network:
- 100Mbps switches (legacy hardware)
- All nodes on same LAN
- Realistic production-like constraints

### Load Testing:
- Apache Bench (ab) from 4 distributed Pi nodes
- Concurrent requests: 100-500
- Test duration: 60-300 seconds
- Controllable CPU load via /stress endpoint

---

## Configuration Management

**Central config:** `swarmguard/config/swarmguard.yaml`

```yaml
monitoring:
  interval_seconds: 1

thresholds:
  cpu_percent: 70
  memory_percent: 70
  network_mbps: 10
  consecutive_breaches: 2

cooldowns:
  migration_seconds: 60
  scale_down_seconds: 180

influxdb:
  host: "192.168.1.100"
  port: 8086
  database: "swarmguard"
  batch_interval_seconds: 10

recovery_manager:
  host: "odin.local"
  port: 5000
  alert_endpoint: "/alert"
```

---

## Key Implementation Challenges

1. **Zero-downtime migration (Attempts 10-17):**
   - Problem: How to migrate without downtime?
   - Solution: Docker Swarm rolling updates with `start-first` ordering + constraint manipulation

2. **Network optimization (Attempts 18-22):**
   - Problem: Continuous metrics saturating 100Mbps network
   - Solution: Event-driven alerts + batched metrics

3. **False positive prevention:**
   - Problem: Single spike causing unnecessary recovery
   - Solution: Consecutive breach requirement (2 breaches)

4. **Cooldown management:**
   - Problem: Rapid oscillation between states
   - Solution: Different cooldowns for different actions

---

## Performance Characteristics

### Latency Breakdown:
```
Alert Detection:      7-9 ms   (monitoring agent)
Alert Transmission:   50-100 ms (HTTP POST to recovery manager)
Decision Making:      < 100 ms (recovery manager analysis)
Action Execution:     6-8 seconds (Docker Swarm migration)
─────────────────────────────────────────────────────
Total MTTR:          ~6.08 seconds
```

### Resource Usage:
```
Monitoring Agent (per node):
  - CPU: 3% average
  - Memory: 50 MB
  - Network: < 0.5 Mbps

Recovery Manager:
  - CPU: < 5% (idle most of time)
  - Memory: ~100 MB
  - Network: Minimal (receives alerts only)
```

---

**Use This Document For:**
- Chapter 3 architecture diagrams
- Methodology implementation details
- Algorithm pseudocode
- Design decision justifications
