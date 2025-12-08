# Product Requirements Document (PRD)
## SwarmGuard: Rule-Based Proactive Recovery Mechanism for Containerized Applications Using Docker Swarm

**Project Title:** Design and Implementation of a Rule-Based Proactive Recovery Mechanism for Containerized Applications Using Docker Swarm

**Project Name:** SwarmGuard (Proactive Recovery Framework)

**Version:** 5.0
**Date:** December 8, 2025
**Author:** Final Year Project Specification

---

## 1. Executive Summary

This project implements a **proactive recovery framework** for Docker Swarm that monitors containerized applications and takes preventive action **before** failures occur. Unlike Docker Swarm's default reactive recovery (which waits for container failure), this system analyzes CPU, memory, and network metrics in real-time to predict issues and trigger intelligent recovery actions, achieving **zero-downtime** recovery.

### Key Objectives
1. **Achieve zero-downtime or near-zero downtime (< 2-3 seconds)** during proactive recovery operations
2. **Significantly reduce MTTR** compared to Docker Swarm's reactive recovery baseline (typically 10+ seconds)
3. Implement **intelligent rule-based decisions** for two distinct failure scenarios
4. **Efficient resource utilization** through smart scaling and migration strategies
5. **Time-sensitive operations**: Every component must be optimized for minimal latency

---

## 2. System Architecture Overview

### 2.1 Infrastructure Components

#### Development Environment
- **Development Machine:** macOS (for code development only)
- **Version Control:** GitHub repository
- **Build Pipeline:**
  - Develop on macOS → Push to GitHub
  - Pull on Ubuntu build server → Build and push to private registry
  - Private Docker Registry: `docker-registry.amirmuz.com` (no authentication)

#### Production Lab Environment

**Docker Swarm Cluster (x86_64):**
- **Master Node:** `master@192.168.2.50` (Ubuntu 24.04.3 LTS)
  - 8 CPU cores, 15.56 GB RAM, 215.99 GB disk
  - Network Interface: `enp5s0f0`

- **Worker Node 1:** `worker-1@192.168.2.51` (Ubuntu 24.04.3 LTS)
  - 4 CPU cores, 7.64 GB RAM, 106.47 GB disk
  - Network Interface: `eno1`

- **Worker Node 2:** `worker-2@192.168.2.52` (Ubuntu 24.04.3 LTS)
  - Status: Currently down, Network Interface: `enp0s25`

- **Worker Node 3:** `worker-3@192.168.2.53` (Ubuntu 24.04.3 LTS)
  - 8 CPU cores, 15.58 GB RAM, 114.84 GB disk
  - Network Interface: `enp2s0`

- **Worker Node 4:** `worker-4@192.168.2.54` (Ubuntu 24.04.3 LTS)
  - 8 CPU cores, 15.54 GB RAM, 912.81 GB disk
  - Network Interface: `eno1`

**Monitoring Infrastructure:**
- **Monitoring Node:** `worker-11@192.168.2.61` (Raspberry Pi, Ubuntu 24.04.3 LTS, aarch64)
  - Runs InfluxDB (port 8086) for time-series metrics storage
  - Runs Grafana (port 3000) for visualization dashboards

**Load Testing Infrastructure:**
- **4x Raspberry Pi 1.2B+** running Alpine Linux
  - Accessible via: `ssh alpine-1` through `ssh alpine-4`
  - Purpose: Simulate user traffic, perform stress testing via curl

**Control Machine:**
- **Old macOS machine** for SSH access and testing orchestration
  - Can SSH to all nodes: `ssh master`, `ssh worker-1`, etc.
  - Used for executing test scripts and MTTR measurement
  - NOT used for running recovery framework (recovery runs on master node)

---

### 2.2 System Components

The complete system consists of the following containerized components:

#### Component Overview

| Component | Purpose | Deployment Location | Count |
|-----------|---------|---------------------|-------|
| **Monitoring Agent** | Collect metrics from each node | All swarm nodes (master + 4 workers) | 5 |
| **Recovery Manager** | Central decision engine for recovery | Master node only | 1 |
| **Web Stress App** | Test application for stress testing | Swarm (any available node) | 1-N (scales) |
| **InfluxDB** | Time-series metrics storage | worker-11 (Raspberry Pi) | 1 |
| **Grafana** | Metrics visualization | worker-11 (Raspberry Pi) | 1 |

**Total Containers:** 8-12+ depending on scaling tests

**Additional Infrastructure (Non-Containerized):**
- **Control macOS:** Test orchestration scripts
- **4x Alpine Raspberry Pis:** Load generation (curl traffic)

---

### 2.2.1 Container Component Details

The system consists of five main containerized components:

#### A. Monitoring Agents (Deployed on Each Node)
**Purpose:** Collect real-time metrics from each Docker Swarm node

**Deployment Model:**
- One monitoring agent per swarm node (master + 4 workers)
- Deployed as Docker Swarm services with node constraints
- Each agent pinned to specific node using hostname constraints

**Data Collection Responsibilities:**
- **CPU Metrics:** Per-container CPU usage percentage
- **Memory Metrics:** Per-container memory usage (MB/GB and percentage)
- **Network Metrics:** Per-container network I/O (bytes in/out, packets in/out)
- **Container Metadata:** Container ID, service name, node hostname, task ID

**Technical Requirements:**
- Mount `/var/run/docker.sock` to query Docker API
- Mount `/proc` (read-only) for system-level CPU/memory stats
- Mount `/sys` (read-only) for additional system metrics
- Configure specific network interface per node (via `NET_IFACE` environment variable)
- Join Docker overlay network for communication with recovery manager
- Minimize resource footprint (avoid installing heavy monitoring tools)

**Data Output Options - Choose One Approach:**

**Option A: Direct Communication to Recovery Manager (Recommended for Efficiency)**
- Send metrics directly to recovery manager via HTTP POST or message queue
- Only send data when thresholds are exceeded (event-driven)
- Reduces network traffic and InfluxDB load
- Recovery manager receives immediate notifications of problems
- Additionally send all metrics to InfluxDB for historical analysis and Grafana visualization

**Option B: Continuous Data Streaming**
- Continuously send all metrics to InfluxDB every N seconds
- Recovery manager polls InfluxDB or monitoring agent HTTP endpoints
- Simple architecture but higher network overhead
- Suitable for comprehensive historical analysis

**Recommended Approach (Hybrid - Optimized for Speed):**
- Monitoring agents collect metrics every 5-10 seconds (configurable, lower = faster detection)
- Send all metrics to InfluxDB for Grafana dashboards and historical analysis
- When threshold exceeded, **immediately** send alert/event to recovery manager via direct HTTP POST
- Recovery manager maintains in-memory cache of recent metrics for instant decision-making
- **Critical for time-sensitivity**: Direct alert path ensures sub-second notification to recovery manager
- This balances efficiency (event-driven recovery) with observability (continuous metrics)

#### B. Recovery Manager (Central Decision Engine)
**Purpose:** Analyze metrics, detect threshold violations, and execute recovery actions

**Deployment Model:**
- Deployed as Docker Swarm service on master node with node constraint
- Requires access to Docker socket for executing Swarm commands
- Runs with elevated privileges to manage cluster

**Core Responsibilities:**

**A. Metrics Collection & Analysis (Optimized for Low Latency)**
- Receive real-time alerts from monitoring agents via HTTP endpoint (< 1 second latency)
- Maintain in-memory cache of recent metrics (last 5 minutes) for instant access
- Optionally use simple moving average over 2-3 data points to avoid false positives
- **Avoid heavy computation**: Keep detection logic simple and fast (< 100ms decision time)
- Detect threshold violations based on configurable rules
- **Time Budget**: From alert received to decision made should be < 1 second

**B. Rule Engine - Scenario Detection**
Implement two distinct scenarios with different recovery strategies:

**Scenario 1: Container/Node Problem (Migration)**
- **Detection Rule:** `(CPU > threshold OR Memory > threshold) AND Network < threshold`
- **Interpretation:** Container or node experiencing resource exhaustion but low network activity
- **Assumption:** The container/node itself has a problem (resource leak, inefficient code, hardware issue)

**Scenario 2: High Traffic (Horizontal Scaling)**
- **Detection Rule:** `CPU > threshold AND Memory > threshold AND Network > threshold`
- **Interpretation:** Container experiencing high load due to heavy user traffic
- **Assumption:** Legitimate high demand requiring additional capacity

**C. Recovery Action Execution (Time-Critical Operations)**
- Execute Docker Swarm API commands directly (avoid SSH overhead)
- Use Docker Engine API over Unix socket for fastest response
- All recovery actions must complete within target time window
- **Performance targets:**
  - Scenario 1 (Migration): Complete within 5-8 seconds (new container up, old removed)
  - Scenario 2 (Scale-Up): Complete within 3-5 seconds (new replica running)
  - **Total MTTR target**: Alert → Decision → Action → Recovery = **< 10 seconds**
  - **Downtime target**: **Zero downtime** (new container serves traffic before old removed)

#### C. Web Stress Application (Test Application)
**Purpose:** Containerized application for stress testing with controllable resource usage

**Deployment Model:**
- Deployed as Docker Swarm service
- Initial deployment: 1 replica
- Scales up/down during Scenario 2 testing
- Can be deployed on any worker node (let Swarm scheduler decide)

**Technical Requirements:**
- Expose HTTP endpoints for stress control
- Gradual resource increase capability (ramp-up)
- Real-time metrics reporting
- Lightweight when idle (< 5% CPU, < 100MB RAM)
- Fast startup time (< 3 seconds)

**API Endpoints:**
- `GET /health` - Health check (200 OK)
- `GET /metrics` - Current resource usage (JSON)
- `GET /stress/cpu?target=<percent>&duration=<sec>&ramp=<sec>`
- `GET /stress/memory?target=<mb>&duration=<sec>&ramp=<sec>`
- `GET /stress/network?bandwidth=<mbps>&duration=<sec>&ramp=<sec>`
- `GET /stress/combined?cpu=<percent>&memory=<mb>&network=<mbps>&duration=<sec>&ramp=<sec>`

**Container Image:**
- Registry: `docker-registry.amirmuz.com/web-stress:latest`
- Base: Lightweight Linux (Alpine or Ubuntu minimal)
- Language: Python/Node.js/Go (choose based on performance)
- Network: Attached to `swarmguard-net` overlay network
- Published Port: 8080 (accessible from control macOS and Alpine Pis)

#### D. InfluxDB + Grafana (Monitoring & Visualization)
**Purpose:** Store historical metrics and provide real-time dashboards

**Deployment:**
- InfluxDB and Grafana run on Raspberry Pi (`worker-11@192.168.2.61`)
- InfluxDB stores time-series data from all monitoring agents
- Grafana provides visualization dashboards for operators

**InfluxDB Configuration:**
- **URL:** `http://192.168.2.61:8086/api/v2/write?org=swarmguard&bucket=metrics&precision=s`
- **Authentication Token:** `ks0cnTPipvphipQIuKT7w7gHAYMZx4GoxvN_3vSGAQd7o1UmcKD64WPYiIFwEteNnRuohJYqsj_4qO5Nr9yvMw==`
- **Organization:** `swarmguard`
- **Bucket:** `metrics`
- **Precision:** seconds

**HTTP Headers for InfluxDB Writes:**
```
Authorization: Token ks0cnTPipvphipQIuKT7w7gHAYMZx4GoxvN_3vSGAQd7o1UmcKD64WPYiIFwEteNnRuohJYqsj_4qO5Nr9yvMw==
Content-Type: text/plain; charset=utf-8
```

**Data Schema (InfluxDB Line Protocol):**
Store measurements with tags and fields:
- **Measurement:** `container_metrics`
- **Tags:** `node`, `service_name`, `container_id`, `task_id`
- **Fields:** `cpu_percent`, `memory_mb`, `memory_percent`, `network_rx_bytes`, `network_tx_bytes`

**In-Memory State (Recovery Manager):**
The recovery manager should maintain recent metrics in memory for fast access:
```python
MAX_AGE_MIN = 5  # Keep node history in memory for last 5 minutes

# In-memory data structures
nodes = {}        # { node: [ { cpu, mem, timestamp, ... } ] }
containers = {}   # { node: [ { container, cpu, mem, net_in, net_out, timestamp } ] }
```

**Grafana Dashboard:**
- A Grafana dashboard JSON file will be provided separately as `grafana_dashboard.json`
- This file defines the visualization structure and queries
- Import this file into Grafana to visualize container metrics, node metrics, and recovery events

---

## 3. Functional Requirements

### 3.1 Scenario 1: Container/Node Problem - Migration Strategy

#### Detection Logic
```
IF (CPU_usage > CPU_THRESHOLD OR Memory_usage > MEMORY_THRESHOLD)
   AND Network_usage < NETWORK_THRESHOLD
THEN trigger Scenario 1
```

**Recommended Thresholds:**
- CPU_THRESHOLD: 70-80%
- MEMORY_THRESHOLD: 75-85%
- NETWORK_THRESHOLD: 30-40% (low network indicates not traffic-related)

#### Recovery Actions (Migration with Zero Downtime)

**Step 1: Identify Target Node**
- Query Docker Swarm to find healthy nodes (exclude node hosting problematic container)
- Select node with lowest resource utilization (CPU + Memory score)
- Ensure node is reachable and in "Ready" state

**Step 2: Deploy New Container Instance**
- Use Docker Swarm API: `docker service update --force <service-name>`
- OR manually create new task with node constraint:
  ```bash
  docker service update \
    --constraint-add 'node.hostname != <problematic-node>' \
    <service-name>
  ```
- Wait for new container to reach "Running" state
- Verify new container is healthy (health check endpoint or Docker health status)

**Step 3: Remove Old Container (After New One is Healthy)**
- Identify specific task ID of problematic container on old node
- Remove old task:
  ```bash
  docker service scale <service-name>=<new-replica-count>
  ```
- OR use task-level removal if supported
- Log migration event with timestamp, old node, new node

**Expected Outcome:**
- Zero downtime: new container serves traffic before old one removed
- Efficient resource usage: only 1 replica maintained
- MTTR improvement: proactive migration before complete failure

---

### 3.2 Scenario 2: High Traffic - Horizontal Scaling Strategy

#### Detection Logic
```
IF CPU_usage > CPU_THRESHOLD
   AND Memory_usage > MEMORY_THRESHOLD
   AND Network_usage > NETWORK_THRESHOLD
THEN trigger Scenario 2
```

**Recommended Thresholds:**
- CPU_THRESHOLD: 70-80%
- MEMORY_THRESHOLD: 75-85%
- NETWORK_THRESHOLD: 60-70% (high network indicates traffic-related)

#### Recovery Actions (Incremental Scale-Up)

**Scale-Up Logic:**
- Current replicas: N
- If ANY container exceeds all thresholds → Scale to N+1
- Add **one replica at a time** for resource efficiency
- Continue monitoring; if still overloaded, add another replica

**Scale-Up Command:**
```bash
docker service scale <service-name>=$((current_replicas + 1))
```

**Placement Strategy:**
- Let Docker Swarm's scheduler decide placement (spread strategy)
- OR implement custom node selection (choose node with most available resources)

**Scale-Down Logic:**
- Prevent premature scale-down (avoid flapping)
- Scale down only when **all containers are idle** for sustained period
- Formula for scale-down decision:
  ```
  Total_usage_all_containers < THRESHOLD × (current_replicas - 1)
  ```
- This ensures remaining replicas can handle load after removing one

**Scale-Down Command:**
```bash
docker service scale <service-name>=$((current_replicas - 1))
```

**Minimum Replica Count:**
- Never scale below 1 replica
- Optionally set minimum of 2 for high availability

**Expected Outcome:**
- Zero downtime: new replicas added before old ones overloaded
- Efficient resource usage: scale one-by-one, not all-at-once
- Automatic scale-down when traffic decreases

---

### 3.3 Configurable Thresholds

All thresholds should be configurable via:
- Configuration file (YAML only)
- Environment variables
- Command-line arguments

**Example Configuration Structure (Time-Optimized):**
```yaml
scenarios:
  scenario1_migration:
    cpu_threshold: 75
    memory_threshold: 80
    network_threshold_max: 35
    cooldown_period: 30  # seconds before re-evaluating (reduced for faster re-action)
    consecutive_breaches: 2  # require 2 consecutive threshold breaches to avoid false positives

  scenario2_scaling:
    cpu_threshold: 75
    memory_threshold: 80
    network_threshold_min: 65
    scale_up_cooldown: 60  # seconds before adding another replica (reduced)
    scale_down_cooldown: 180  # seconds of idle before removing replica (reduced)
    min_replicas: 1
    max_replicas: 10
    consecutive_breaches: 2  # require 2 consecutive breaches

monitoring:
  poll_interval: 5  # seconds between metric collection (reduced for faster detection)
  metric_window: 15  # seconds of data to consider (reduced for faster reaction)
  alert_immediately: true  # send alert to recovery manager immediately on breach

performance:
  max_decision_time_ms: 1000  # maximum time for recovery manager to make decision
  target_mttr_seconds: 10  # target total recovery time
  max_downtime_seconds: 3  # maximum acceptable downtime (aim for 0)
```

---

### 3.4 Recovery Manager Core Logic Flow (Time-Optimized)

**Event-Driven Architecture (Recommended for Speed):**

```
INITIALIZATION:
  1. Start HTTP server to receive alerts from monitoring agents (port 5000)
  2. Load configuration (thresholds, cooldowns, etc.)
  3. Initialize in-memory cache: nodes{}, containers{}, cooldowns{}
  4. Connect to Docker Engine API via Unix socket

MAIN EVENT LOOP:
  On receiving HTTP POST /alert from monitoring agent:
    START_TIMER (target: < 1 second for entire decision + action)

    1. Parse alert payload (node, container_id, service_name, cpu, mem, net)

    2. Update in-memory cache with latest metrics

    3. Check consecutive breach count:
       - If first breach: increment counter, return (wait for confirmation)
       - If consecutive_breaches met: proceed to decision

    4. Determine scenario (< 10ms):
       - If (CPU high OR MEM high) AND NET low → Scenario 1
       - If CPU high AND MEM high AND NET high → Scenario 2

    5. Check cooldown period (< 1ms):
       - If recent action on this service/container, skip (avoid flapping)

    6. Execute recovery action ASYNCHRONOUSLY (don't block):
       - Scenario 1: Trigger migration (spawn new, wait health, remove old)
       - Scenario 2: Trigger scale-up (increment replicas by 1)
       - Update cooldown timestamp

    7. Log action to stdout and optionally InfluxDB

    STOP_TIMER (log if > 1 second)

    Return 200 OK to monitoring agent

BACKGROUND THREAD (scale-down monitoring):
  Every 60 seconds:
    1. Check all services for scale-down eligibility
    2. If all containers idle for > scale_down_cooldown:
       - Scale down by 1 replica
       - Update cooldown
```

**Performance Optimizations:**
- Use async/concurrent operations for non-blocking execution
- Keep decision logic simple (avoid complex algorithms)
- Use Docker API directly (no shell commands)
- Maintain in-memory state to avoid database queries during decisions
- Log asynchronously to avoid I/O blocking

---

## 4. Non-Functional Requirements

### 4.1 Performance (Strict Time Requirements)
- **Monitoring overhead:** Agents should use < 5% CPU and < 100MB memory per node
- **Metric collection interval:** 5-10 seconds (configurable, lower = faster detection)
- **Alert latency:** Alert sent to recovery manager within < 1 second of threshold breach
- **Decision latency:** Recovery manager makes decision within < 1 second of receiving alert
- **Action execution time:**
  - Scenario 1 (Migration): 5-8 seconds to deploy new container and remove old
  - Scenario 2 (Scale-Up): 3-5 seconds to add new replica
- **Total MTTR (Proactive):** < 10 seconds from threshold breach to full recovery
- **Baseline MTTR (Reactive):** 10-30 seconds (Docker Swarm's default)
- **Target improvement:** 50%+ reduction in MTTR compared to reactive recovery
- **Downtime target:** **Zero downtime** (or < 2-3 seconds maximum)
- **Service availability:** Service must remain available throughout recovery actions

### 4.2 Network Optimization for 100Mbps Constraint

**Infrastructure Limitation:**
- All nodes connected via 100Mbps network (12.5 MB/s theoretical max)
- Old hardware with limited processing power
- Must optimize all monitoring and communication for bandwidth efficiency
- Reliable real-time data transmission is critical despite constraints

**Data Payload Optimization:**

**1. Alert Payload Size (Monitoring Agent → Recovery Manager):**
- Keep alert messages < 500 bytes for fast transmission
- Use compact JSON format without whitespace
- Send only essential fields (no redundant metadata)
- Example optimized alert (< 400 bytes):
  ```json
  {"t":1638360000,"n":"worker-1","c":"abc123","s":"web","m":{"cpu":85.5,"mem_mb":1024,"mem_pct":75.3,"net_rx":15.2,"net_tx":10.5}}
  ```
- At 100Mbps, 500 bytes = ~4ms transmission time (negligible)
- Priority: Alerts MUST reach recovery manager within < 1 second

**2. InfluxDB Writes (Monitoring Agent → InfluxDB):**
- Use InfluxDB Line Protocol (more compact than JSON)
- Batch metrics: collect 5-10 seconds of data, send in single HTTP request
- Compress payloads with gzip if supported by InfluxDB API
- Example batched write (5 containers, 10 data points = ~1-2KB compressed):
  ```
  container_metrics,node=master,service=web cpu=75.5,mem=512,net_rx=1048576 1638360000
  container_metrics,node=master,service=web cpu=76.0,mem=515,net_rx=1058576 1638360001
  ...
  ```
- Batch size: 10-20 metrics per HTTP request (balance latency vs bandwidth)

**3. Communication Priority:**
- **High Priority (Real-Time):** Alerts to recovery manager (event-driven, < 1s)
- **Medium Priority (Background):** Continuous metrics to InfluxDB (5-10s intervals)
- **Low Priority (Async):** Recovery manager logs to InfluxDB (non-blocking)

**4. Network Traffic Management:**
- Use HTTP keepalive connections to avoid TCP handshake overhead
- Reuse connections between monitoring agents and recovery manager
- Set reasonable timeouts (1-2 seconds) to avoid blocking
- Consider connection pooling for InfluxDB writes

**5. Bandwidth Budget (Per Node):**
Assuming 5 nodes with monitoring agents:
- **Per-node alert traffic:** 1 alert every 10s @ 500 bytes = 50 bytes/s = 0.4 Kbps
- **Per-node InfluxDB traffic:** 20 containers × 200 bytes/10s = 400 bytes/s = 3.2 Kbps
- **Total monitoring traffic:** 5 nodes × (0.4 + 3.2) Kbps = 18 Kbps (< 0.02% of 100Mbps)
- **Remaining bandwidth:** 99.98% available for application traffic

**Conclusion:** Monitoring overhead is negligible even on 100Mbps network.

**6. Reliability Strategies for Old Hardware:**
- **Retry logic:** If alert fails to send, retry once after 100ms delay
- **Timeout handling:** Set 1-second timeout on HTTP requests
- **Async I/O:** Use non-blocking HTTP clients to avoid blocking collection loop
- **Error logging:** Log failed transmissions but don't stop monitoring
- **Connection health checks:** Periodically verify recovery manager and InfluxDB reachable

**7. Implementation Recommendations:**
- Use lightweight HTTP libraries (avoid heavy frameworks)
- Prefer binary protocols if possible (Protocol Buffers, MessagePack) over JSON
- Enable HTTP/2 for multiplexing (if supported by all components)
- Use Docker overlay network (built-in encryption won't add significant overhead)
- Monitor monitoring agent resource usage (should be < 5% CPU, < 100MB RAM)

**8. Testing Network Performance:**
- Measure actual network throughput between nodes using `iperf3`
- Monitor network interface statistics (`/sys/class/net/<iface>/statistics/`)
- Track packet loss and retransmissions
- Verify alert delivery time (T1 - T0) stays < 1 second under load

### 4.3 Scalability
- Support 5 swarm nodes initially, extensible to 10+ nodes
- Support monitoring 20+ containers per node

### 4.4 Reliability
- **Monitoring agent resilience:** Auto-restart if agent crashes
- **Recovery manager resilience:** Handle partial cluster failures (some nodes unreachable)
- **Idempotency:** Recovery actions should be safe to retry if interrupted

### 4.5 Observability
- **Logging:** All recovery actions logged with timestamp, trigger, and outcome
- **Metrics:** Store all collected metrics in InfluxDB for historical analysis
- **Dashboards:** Grafana dashboards showing:
  - Real-time CPU/Memory/Network per container
  - Recovery action timeline (annotations)
  - MTTR comparison (proactive vs reactive)

---

## 5. Testing Strategy

### 5.1 Test Environment Setup

**Prerequisites:**
- Docker Swarm cluster operational (master + 4 workers)
- Monitoring agents deployed on all nodes
- Recovery manager running on master node
- InfluxDB and Grafana accessible on `worker-11@192.168.2.61`
- Alpine Raspberry Pis ready for load generation
- Control macOS ready for SSH access to all nodes for test execution

**Deploy Test Application (Web Stress Application):**
- Create a web service specifically designed for stress testing with gradual resource increase
- Deploy as Docker Swarm service with 1 initial replica
- Service must have endpoints for:
  - **Health check:** `/health` - Returns 200 OK if healthy
  - **CPU stress:** `/stress/cpu?target=<percent>&duration=<seconds>&ramp=<seconds>`
    - Gradually increases CPU usage to target percentage over ramp period
    - Maintains target load for duration
  - **Memory stress:** `/stress/memory?target=<mb>&duration=<seconds>&ramp=<seconds>`
    - Gradually allocates memory to target MB over ramp period
    - Maintains allocation for duration
  - **Network stress:** `/stress/network?bandwidth=<mbps>&duration=<seconds>&ramp=<seconds>`
    - Gradually increases network traffic to target bandwidth over ramp period
    - Maintains traffic for duration
  - **Combined stress:** `/stress/combined?cpu=<percent>&memory=<mb>&network=<mbps>&duration=<seconds>&ramp=<seconds>`
    - Stresses CPU, memory, and network simultaneously with gradual ramp-up
  - **Current load:** `/metrics` - Returns current CPU/memory/network usage in JSON format

**Example Deployment Command:**
```bash
docker service create \
  --name web-stress \
  --replicas 1 \
  --network swarmguard-net \
  --publish 8080:8080 \
  docker-registry.amirmuz.com/web-stress:latest
```

**Why Gradual Increase:**
- Allows clear observation in Grafana dashboards as metrics ramp up
- Avoids sudden spikes that might trigger false positives
- Mimics realistic application behavior under increasing load
- Enables precise threshold testing

---

### 5.2 Test Scenarios

#### Test Case 1: Scenario 1 Validation (Migration)
**Objective:** Verify migration strategy when container has resource problem

**Test Steps:**
1. Deploy test application with 1 replica
2. Use `docker exec` to artificially stress CPU and memory inside container:
   ```bash
   # SSH to node hosting container
   docker exec <container-id> stress-ng --cpu 4 --vm 2 --vm-bytes 1G --timeout 300s
   ```
3. Verify network usage remains low (no external traffic)
4. Observe monitoring agents detect high CPU/Memory, low Network
5. Wait for recovery manager to detect Scenario 1
6. Verify recovery manager:
   - Deploys new container on different node
   - Waits for new container to be healthy
   - Removes old container
7. Verify service remained available throughout (use Alpine Pis to continuously curl service)
8. Record MTTR (time from threshold breach to full recovery)

**Expected Results:**
- Container migrated to new node within **5-10 seconds**
- **Zero downtime** (no failed requests during migration)
- Old container removed only after new one healthy
- Record precise timing: alert_time, decision_time, action_start, new_container_ready, old_container_removed
- Total MTTR should be < 10 seconds

---

#### Test Case 2: Scenario 2 Validation (Scale-Up)
**Objective:** Verify horizontal scaling when service under high traffic

**Test Steps:**
1. Deploy test application with 1 replica
2. Use Alpine Raspberry Pis to generate high traffic:
   ```bash
   # On each alpine-1 through alpine-4
   while true; do curl http://192.168.2.50:8080/api/endpoint; done
   ```
3. Verify high CPU, Memory, and Network usage on container
4. Observe monitoring agents detect all three metrics high
5. Wait for recovery manager to detect Scenario 2
6. Verify recovery manager scales service to 2 replicas
7. If load continues, verify additional scale-up to 3, 4, etc.
8. Stop traffic from Alpine Pis
9. Wait for cooldown period
10. Verify recovery manager scales down incrementally (one replica at a time)

**Expected Results:**
- Service scales up within **5-10 seconds** of sustained high load
- **Load distributed evenly across multiple replicas:**
  - 1 replica at 75% CPU → scales to 2 replicas → each should be ~37.5% CPU
  - 2 replicas at 75% CPU → scales to 3 replicas → each should be ~50% CPU
  - Verify load distribution in Grafana (should see clear split of resources)
- Service scales down after traffic subsides (after cooldown)
- **Zero downtime** during scaling operations
- Record precise timing for each scale-up/down event
- Total time from threshold breach to new replica serving traffic < 10 seconds

**Load Distribution Verification:**
After each scale-up, verify in Grafana that resource utilization splits proportionally:
- Formula: `new_utilization_per_replica ≈ old_total_utilization / new_replica_count`
- Example: 70% on 1 replica → scales to 2 → expect ~35% on each
- Example: 75% on 2 replicas → scales to 3 → expect ~50% on each
- This confirms Docker Swarm load balancer is distributing traffic correctly

---

#### Test Case 3: MTTR Comparison (Proactive vs Reactive)
**Objective:** Demonstrate improvement over Docker Swarm's reactive recovery

**Baseline Test (Reactive Recovery):**
1. Disable proactive recovery manager
2. Deploy test application with 1 replica
3. Use `docker exec` to crash the container:
   ```bash
   docker exec <container-id> kill -9 1
   ```
4. Measure time from container crash to new container running and healthy
5. Record downtime (time when service unavailable)

**Proactive Test:**
1. Enable proactive recovery manager
2. Deploy test application with 1 replica
3. Stress container (Scenario 1) to trigger proactive migration
4. Measure time from threshold breach to migration complete
5. Record downtime (should be zero)

**Comparison Metrics:**
- **Baseline MTTR (Reactive):** 10-12 seconds (Docker Swarm's default - measure actual)
- **Proactive MTTR Target:** < 10 seconds (beat reactive baseline)
- **Best Case Target:** 0-3 seconds maximum MTTR
- **Baseline Downtime (Reactive):** 10-12 seconds (service unavailable during container restart)
- **Proactive Downtime Target:** 0 seconds (absolute zero downtime)
- **Maximum Acceptable Downtime:** < 3 seconds
- **Success Criteria:** Proactive recovery must demonstrate:
  - MTTR faster than reactive baseline (< 10-12 seconds)
  - Ideally achieve 0-3 seconds total recovery time
  - Zero or near-zero downtime (< 3 seconds maximum)
  - No failed requests during proactive recovery

---

#### Test Case 4: Node Failure Handling
**Objective:** Verify system handles node failures gracefully

**Test Steps:**
1. Deploy test application across multiple nodes
2. Simulate node failure:
   ```bash
   # SSH to worker-3
   sudo systemctl stop docker
   ```
3. Verify monitoring agent on that node becomes unreachable
4. Verify recovery manager detects node failure
5. Verify Docker Swarm reschedules containers from failed node
6. Verify recovery manager continues monitoring remaining nodes

**Expected Results:**
- Recovery manager logs warning about unreachable node
- System continues operating with remaining nodes
- Containers rescheduled by Swarm, then monitored by recovery manager

---

#### Test Case 5: Concurrent Scenarios
**Objective:** Verify system handles multiple simultaneous issues

**Test Steps:**
1. Deploy 3 different services on swarm
2. Trigger Scenario 1 on service A (CPU stress)
3. Trigger Scenario 2 on service B (high traffic)
4. Trigger Scenario 1 on service C (memory stress)
5. Verify recovery manager handles all three concurrently

**Expected Results:**
- Service A migrated
- Service B scaled up
- Service C migrated
- No conflicts or race conditions
- All services remain available

---

### 5.3 Test Scripts

**Location:** All test scripts should be stored in `tests/` directory

**Execution Environment:** All test orchestration scripts run on control macOS

**Required Test Scripts:**

#### Script 1: `deploy_web_stress.sh`
- Deploys web-stress application to Docker Swarm
- Accepts parameters: replicas, network, ports
- Verifies deployment successful
- Example: `./deploy_web_stress.sh --replicas 1 --port 8080`

#### Script 2: `stress_scenario1.sh` - CPU/Memory High, Network Low
**Purpose:** Trigger Scenario 1 (migration) by stressing CPU and memory while keeping network low

**Execution from Control macOS:**
```bash
./stress_scenario1.sh \
  --service web-stress \
  --cpu-target 80 \
  --memory-target 1024 \
  --ramp-time 30 \
  --duration 120
```

**Script Actions:**
1. Call web-stress API endpoint: `GET http://192.168.2.50:8080/stress/combined?cpu=80&memory=1024&network=0&ramp=30&duration=120`
2. Monitor Grafana/InfluxDB for threshold breach
3. Wait for recovery manager to detect and migrate
4. Record MTTR timestamps (T0-T6)
5. Verify new container on different node
6. Verify old container removed
7. Output MTTR and downtime metrics

#### Script 3: `stress_scenario2.sh` - CPU/Memory/Network All High
**Purpose:** Trigger Scenario 2 (scaling) by generating high traffic from Alpine Pis

**Execution from Control macOS:**
```bash
./stress_scenario2.sh \
  --service web-stress \
  --alpine-nodes "alpine-1,alpine-2,alpine-3,alpine-4" \
  --requests-per-second 100 \
  --ramp-time 30 \
  --duration 180
```

**Script Actions:**
1. SSH to each Alpine node and start curl loop:
   ```bash
   ssh alpine-1 "while true; do curl -s http://192.168.2.50:8080/api/data; sleep 0.01; done" &
   ssh alpine-2 "while true; do curl -s http://192.168.2.50:8080/api/data; sleep 0.01; done" &
   ssh alpine-3 "while true; do curl -s http://192.168.2.50:8080/api/data; sleep 0.01; done" &
   ssh alpine-4 "while true; do curl -s http://192.168.2.50:8080/api/data; sleep 0.01; done" &
   ```
2. Gradually increase request rate to reach target RPS over ramp period
3. Maintain load for duration
4. Monitor Grafana for threshold breach and scale-up events
5. Verify load distribution after each scale-up (e.g., 75% → 2 replicas → ~37.5% each)
6. Stop traffic and wait for scale-down
7. Record all timing metrics and load distribution data
8. Kill all background Alpine curl processes

#### Script 4: `alpine_load_orchestrator.sh`
**Purpose:** Centralized script to control all Alpine Pis for load generation

**Execution from Control macOS:**
```bash
./alpine_load_orchestrator.sh \
  --target http://192.168.2.50:8080/api/data \
  --alpine-nodes "alpine-1,alpine-2,alpine-3,alpine-4" \
  --rps 100 \
  --ramp-time 30 \
  --hold-time 120 \
  --ramp-down-time 30
```

**Script Features:**
- Connects to all Alpine Pis via SSH
- Starts curl loops on each Alpine with calculated delay to achieve target RPS
- Ramps up: Gradually increases RPS from 0 to target over ramp-time
- Holds: Maintains target RPS for hold-time
- Ramps down: Gradually decreases RPS from target to 0 over ramp-down-time
- Real-time monitoring of actual RPS achieved
- Cleanup: Kills all remote curl processes when done

#### Script 5: `measure_mttr.sh`
**Purpose:** Measure precise MTTR with T0-T6 timestamps

**Execution from Control macOS:**
```bash
./measure_mttr.sh --service web-stress --scenario 1
```

**Script Actions:**
1. Subscribe to recovery manager logs (via SSH or Docker logs)
2. Trigger stress test (scenario 1 or 2)
3. Record T0 (threshold breach detected by monitoring agent)
4. Record T1 (alert sent to recovery manager)
5. Record T2 (alert received by recovery manager)
6. Record T3 (decision made)
7. Record T4 (action initiated)
8. Record T5 (new container ready)
9. Record T6 (old container removed, if applicable)
10. Calculate and output all latencies and total MTTR
11. Write results to InfluxDB for visualization

#### Script 6: `baseline_reactive_test.sh`
**Purpose:** Measure Docker Swarm's reactive recovery baseline

**Execution from Control macOS:**
```bash
./baseline_reactive_test.sh --service web-stress
```

**Script Actions:**
1. Disable proactive recovery manager (stop the service)
2. Deploy web-stress with 1 replica
3. Start continuous availability monitoring (curl loop)
4. Kill container: `docker exec <container-id> kill -9 1`
5. Measure time until new container healthy
6. Count failed requests during recovery
7. Record MTTR and downtime
8. Re-enable proactive recovery manager

**Expected Baseline:** 10-12 seconds MTTR, 10-12 seconds downtime

#### Script 7: `validate_zero_downtime.sh`
**Purpose:** Continuously monitor service availability during recovery

**Execution from Control macOS (runs in background during tests):**
```bash
./validate_zero_downtime.sh \
  --target http://192.168.2.50:8080/health \
  --interval 0.1 \
  --output downtime_log.txt &
```

**Script Actions:**
- Curl service endpoint every 100ms
- Log timestamp and response status for each request
- Count and log any failed requests (timeout, connection refused, 5xx errors)
- Calculate total downtime (sum of periods with failed requests)
- Output to file and InfluxDB

#### Script 8: `cleanup.sh`
**Purpose:** Reset environment to clean state

**Execution from Control macOS:**
```bash
./cleanup.sh --full
```

**Script Actions:**
1. SSH to master node
2. Remove all test services: `docker service rm web-stress`
3. Kill any running Alpine curl processes: `ssh alpine-{1..4} "pkill -f curl"`
4. Optionally clear InfluxDB test data
5. Verify swarm is in clean state

#### Script 9: `run_full_test_suite.sh`
**Purpose:** Execute complete test suite automatically

**Execution from Control macOS:**
```bash
./run_full_test_suite.sh --scenarios all --iterations 3
```

**Script Actions:**
1. Deploy all services (monitoring agents, recovery manager, web-stress)
2. Wait for all services healthy
3. Run baseline reactive test (measure Docker Swarm default)
4. Run Scenario 1 test (migration) - 3 iterations
5. Run Scenario 2 test (scaling) - 3 iterations
6. Run concurrent scenarios test
7. Collect all metrics and generate summary report
8. Cleanup environment

**Output:** Comprehensive test report with MTTR comparisons, downtime analysis, and load distribution verification

---

### 5.4 Test Data Collection

**Metrics to Record (High-Precision Timing):**
- **T0**: Threshold breach detected by monitoring agent (timestamp)
- **T1**: Alert sent to recovery manager (timestamp)
- **T2**: Alert received by recovery manager (timestamp)
- **T3**: Decision made by recovery manager (timestamp)
- **T4**: Recovery action initiated (Docker API call) (timestamp)
- **T5**: New container/replica becomes ready (timestamp)
- **T6**: Old container removed (for Scenario 1) (timestamp)
- **Alert Latency**: T2 - T1 (target: < 1 second)
- **Decision Latency**: T3 - T2 (target: < 1 second)
- **Action Execution Time**: T5 - T4 (target: 3-8 seconds depending on scenario)
- **Total MTTR**: T5 - T0 or T6 - T0 (target: < 10 seconds)
- **Downtime Duration**: Time when no healthy containers available (target: 0 seconds)
- **Failed Requests**: Number of HTTP requests that failed during recovery (target: 0)
- **Resource Overhead**: Monitoring agent CPU/memory usage (target: < 5% CPU, < 100MB RAM)

**Data Storage:**
- Store test results in InfluxDB with measurement `test_results`
- Tags: `test_case`, `scenario`, `timestamp`
- Fields: `mttr_seconds`, `downtime_seconds`, `failed_requests`

**Visualization:**
- Create Grafana dashboard for test results
- Show MTTR comparison chart (proactive vs reactive)
- Show downtime comparison chart
- Show recovery action timeline

---

## 6. Deployment Instructions

### 6.1 Build and Push Workflow

**On Development macOS:**
```bash
# Develop code locally
git add .
git commit -m "Update recovery manager logic"
git push origin main
```

**On Ubuntu Build Server:**
```bash
# Pull latest code
cd /path/to/repo
git pull origin main

# Build monitoring agent image
docker build -t docker-registry.amirmuz.com/monitoring-agent:latest ./monitoring-agent
docker push docker-registry.amirmuz.com/monitoring-agent:latest

# Build recovery manager image (if containerized)
docker build -t docker-registry.amirmuz.com/recovery-manager:latest ./recovery-manager
docker push docker-registry.amirmuz.com/recovery-manager:latest

# Build test application image
docker build -t docker-registry.amirmuz.com/test-app:latest ./test-app
docker push docker-registry.amirmuz.com/test-app:latest
```

### 6.2 Deploy Monitoring Agents

**From Control macOS (via SSH to master):**

Create Docker overlay network:
```bash
ssh master "docker network create --driver overlay swarmguard-net"
```

Deploy agents to each node:
```bash
# Master node
ssh master "docker service create \
  --name monitoring-agent-master \
  --constraint 'node.hostname == master' \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  --mount type=bind,src=/proc,dst=/host/proc,ro=true \
  --mount type=bind,src=/sys,dst=/host/sys,ro=true \
  --network swarmguard-net \
  -e NET_IFACE=enp5s0f0 \
  -e INFLUXDB_URL=http://192.168.2.61:8086/api/v2/write?org=swarmguard&bucket=metrics&precision=s \
  -e INFLUXDB_TOKEN=ks0cnTPipvphipQIuKT7w7gHAYMZx4GoxvN_3vSGAQd7o1UmcKD64WPYiIFwEteNnRuohJYqsj_4qO5Nr9yvMw== \
  docker-registry.amirmuz.com/monitoring-agent:latest"

# Worker 1
ssh master "docker service create \
  --name monitoring-agent-worker1 \
  --constraint 'node.hostname == worker-1' \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  --mount type=bind,src=/proc,dst=/host/proc,ro=true \
  --mount type=bind,src=/sys,dst=/host/sys,ro=true \
  --network swarmguard-net \
  -e NET_IFACE=eno1 \
  -e INFLUXDB_URL=http://192.168.2.61:8086/api/v2/write?org=swarmguard&bucket=metrics&precision=s \
  -e INFLUXDB_TOKEN=ks0cnTPipvphipQIuKT7w7gHAYMZx4GoxvN_3vSGAQd7o1UmcKD64WPYiIFwEteNnRuohJYqsj_4qO5Nr9yvMw== \
  docker-registry.amirmuz.com/monitoring-agent:latest"

# Worker 2 (enp0s25)
ssh master "docker service create \
  --name monitoring-agent-worker2 \
  --constraint 'node.hostname == worker-2' \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  --mount type=bind,src=/proc,dst=/host/proc,ro=true \
  --mount type=bind,src=/sys,dst=/host/sys,ro=true \
  --network swarmguard-net \
  -e NET_IFACE=enp0s25 \
  -e INFLUXDB_URL=http://192.168.2.61:8086/api/v2/write?org=swarmguard&bucket=metrics&precision=s \
  -e INFLUXDB_TOKEN=ks0cnTPipvphipQIuKT7w7gHAYMZx4GoxvN_3vSGAQd7o1UmcKD64WPYiIFwEteNnRuohJYqsj_4qO5Nr9yvMw== \
  docker-registry.amirmuz.com/monitoring-agent:latest"

# Worker 3 (enp2s0)
ssh master "docker service create \
  --name monitoring-agent-worker3 \
  --constraint 'node.hostname == worker-3' \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  --mount type=bind,src=/proc,dst=/host/proc,ro=true \
  --mount type=bind,src=/sys,dst=/host/sys,ro=true \
  --network swarmguard-net \
  -e NET_IFACE=enp2s0 \
  -e INFLUXDB_URL=http://192.168.2.61:8086/api/v2/write?org=swarmguard&bucket=metrics&precision=s \
  -e INFLUXDB_TOKEN=ks0cnTPipvphipQIuKT7w7gHAYMZx4GoxvN_3vSGAQd7o1UmcKD64WPYiIFwEteNnRuohJYqsj_4qO5Nr9yvMw== \
  docker-registry.amirmuz.com/monitoring-agent:latest"

# Worker 4 (eno1)
ssh master "docker service create \
  --name monitoring-agent-worker4 \
  --constraint 'node.hostname == worker-4' \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  --mount type=bind,src=/proc,dst=/host/proc,ro=true \
  --mount type=bind,src=/sys,dst=/host/sys,ro=true \
  --network swarmguard-net \
  -e NET_IFACE=eno1 \
  -e INFLUXDB_URL=http://192.168.2.61:8086/api/v2/write?org=swarmguard&bucket=metrics&precision=s \
  -e INFLUXDB_TOKEN=ks0cnTPipvphipQIuKT7w7gHAYMZx4GoxvN_3vSGAQd7o1UmcKD64WPYiIFwEteNnRuohJYqsj_4qO5Nr9yvMw== \
  docker-registry.amirmuz.com/monitoring-agent:latest"
```

Verify all agents running:
```bash
ssh master "docker service ls | grep monitoring-agent"
```

### 6.3 Deploy Recovery Manager

**Deploy as Docker Service on Master Node:**
```bash
ssh master "docker service create \
  --name recovery-manager \
  --constraint 'node.hostname == master' \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  --network swarmguard-net \
  --publish 5000:5000 \
  -e INFLUXDB_URL=http://192.168.2.61:8086/api/v2/write?org=swarmguard&bucket=metrics&precision=s \
  -e INFLUXDB_TOKEN=ks0cnTPipvphipQIuKT7w7gHAYMZx4GoxvN_3vSGAQd7o1UmcKD64WPYiIFwEteNnRuohJYqsj_4qO5Nr9yvMw== \
  docker-registry.amirmuz.com/recovery-manager:latest"
```

Verify recovery manager is running:
```bash
ssh master "docker service ps recovery-manager"
ssh master "docker service logs recovery-manager"
```

### 6.4 Access Monitoring Dashboards

**InfluxDB:**
- URL: `http://192.168.2.61:8086`
- Organization: `swarmguard`
- Bucket: `metrics`
- Token: `ks0cnTPipvphipQIuKT7w7gHAYMZx4GoxvN_3vSGAQd7o1UmcKD64WPYiIFwEteNnRuohJYqsj_4qO5Nr9yvMw==`

**Grafana:**
- URL: `http://192.168.2.61:3000`
- Add InfluxDB data source with above credentials
- Import dashboard from `grafana_dashboard.json` file
- Dashboard will show:
  - Container CPU/Memory/Network metrics
  - Node-level resource utilization
  - Recovery action timeline (when recovery manager logs actions)

---

## 7. Technical Implementation Guidelines

### 7.1 Monitoring Agent Implementation

**Responsibilities:**
- Discover all containers on local node via Docker API
- Collect metrics every N seconds (configurable, recommended: 10 seconds)
- Calculate CPU percentage from `/proc/stat` or Docker stats
- Calculate memory usage from Docker stats
- Calculate network I/O from `/sys/class/net/<interface>/statistics/`
- Send metrics to InfluxDB using line protocol or HTTP API
- Send threshold breach alerts to recovery manager (if using event-driven approach)

**Communication Strategy (Event-Driven for Minimal Latency):**

1. **Continuous Metrics to InfluxDB:**
   - Every 5-10 seconds, send all container metrics to InfluxDB
   - Use InfluxDB Line Protocol over HTTP POST (async, non-blocking)
   - This provides historical data for Grafana dashboards
   - **Important**: Don't let InfluxDB writes slow down alert sending

2. **Immediate Alerts to Recovery Manager (CRITICAL for Time-Sensitivity):**
   - When container metrics exceed thresholds, **immediately** send alert to recovery manager
   - Recovery manager listens on HTTP endpoint: `POST http://recovery-manager:5000/alert`
   - Alert must be sent within < 1 second of threshold detection
   - Alert payload (JSON):
     ```json
     {
       "timestamp": 1638360000,
       "node": "worker-1",
       "container_id": "abc123",
       "service_name": "web",
       "metrics": {
         "cpu_percent": 85.5,
         "memory_mb": 1024,
         "memory_percent": 75.3,
         "network_rx_mbps": 15.2,
         "network_tx_mbps": 10.5
       }
     }
     ```
   - Use HTTP keepalive connections to reduce connection overhead
   - Implement timeout (1 second) and retry (1 attempt) for reliability

3. **Performance Optimizations:**
   - Use async HTTP client for non-blocking I/O
   - Send alert before sending to InfluxDB (priority to recovery)
   - Keep alert payload small (< 1KB) for fast transmission
   - Use Docker overlay network for low-latency communication between agent and recovery manager

**Key Docker API Calls:**
- `GET /containers/json` - List all containers
- `GET /containers/{id}/stats?stream=false` - Get container stats
- Parse JSON response for CPU, memory, network metrics

**InfluxDB Write Example (Line Protocol):**
```
container_metrics,node=master,service=web,container=abc123 cpu_percent=75.5,memory_mb=512,network_rx_bytes=1048576 1638360000000000000
```

**Technology Suggestions:**
- Python: `docker` library, `requests` for InfluxDB, `psutil` for system stats
- Go: `docker/docker/client`, lightweight and performant
- Shell script: Use `docker stats --no-stream` and `curl` to InfluxDB (simplest but less flexible)

---

### 7.2 Recovery Manager Implementation

**Responsibilities:**
- Fetch metrics from InfluxDB or directly from monitoring agents
- Maintain state of all services and containers
- Evaluate rules for Scenario 1 and Scenario 2
- Execute Docker Swarm API calls for migration and scaling
- Implement cooldown timers to avoid flapping
- Log all decisions and actions
- Handle errors gracefully (retry logic, alerting)

**Key Docker API Calls:**
- `GET /services` - List all services
- `GET /services/{id}` - Get service details (replicas, constraints)
- `POST /services/{id}/update` - Update service (scale, constraints)
- `GET /tasks?filters={"service":["<service-id>"]}` - List tasks for service
- `DELETE /tasks/{id}` - Remove specific task (if needed)

**State Management:**
- Track last action timestamp per service/container (for cooldown)
- Track current replica count per service
- Track which containers are currently in recovery

**Configuration Management:**
- Load thresholds and settings from YAML file
- Support hot-reload of configuration (watch file for changes)

**Logging:**
- Use structured logging (JSON format)
- Include: timestamp, service name, container ID, action taken, reason, outcome

**Technology Suggestions:**
- Python: `docker` library, `PyYAML`, `requests`, `schedule` for periodic tasks
- Go: `docker/docker/client`, `yaml` library, goroutines for concurrency
- Node.js: `dockerode`, `js-yaml`, `node-schedule`

---

### 7.3 Web Stress Application Implementation

**Requirements:**
- Web service specifically designed for controllable stress testing
- Must support gradual resource increase (ramp-up) for realistic load patterns
- Real-time metrics reporting for verification
- Lightweight and fast startup

**Core Functionality:**

**1. CPU Stress:**
- Spawn worker threads/processes to consume CPU
- Gradually increase CPU usage from 0% to target over ramp period
- Use busy loops or mathematical computations (prime calculation, hashing)
- Maintain target CPU usage for duration
- Gracefully release resources after duration

**2. Memory Stress:**
- Allocate memory in chunks
- Gradually increase allocation from 0 to target MB over ramp period
- Hold allocated memory for duration
- Prevent OS from swapping (touch/write to allocated pages)
- Release memory after duration

**3. Network Stress:**
- Generate network traffic (send/receive data)
- Gradually increase bandwidth from 0 to target Mbps over ramp period
- Use localhost loopback or external endpoint for traffic generation
- Maintain bandwidth for duration
- Options: HTTP requests in tight loop, UDP packet generation, or socket streaming

**4. Combined Stress:**
- Run CPU, memory, and network stress simultaneously
- Synchronize ramp-up periods for all resources
- Each resource independently controllable

**Required API Endpoints:**
```
GET /health
  Response: {"status": "healthy", "uptime": 123}

GET /metrics
  Response: {
    "cpu_percent": 45.5,
    "memory_mb": 512,
    "memory_percent": 25.0,
    "network_rx_mbps": 10.2,
    "network_tx_mbps": 8.5,
    "active_stress": ["cpu", "memory"]
  }

GET /stress/cpu?target=80&duration=120&ramp=30
  Ramps CPU from 0% to 80% over 30 seconds
  Maintains 80% for 120 seconds
  Response: {"status": "started", "target_cpu": 80}

GET /stress/memory?target=1024&duration=120&ramp=30
  Ramps memory from 0 to 1024MB over 30 seconds
  Maintains 1024MB for 120 seconds
  Response: {"status": "started", "target_memory_mb": 1024}

GET /stress/network?bandwidth=50&duration=120&ramp=30
  Ramps network to 50 Mbps over 30 seconds
  Maintains 50 Mbps for 120 seconds
  Response: {"status": "started", "target_bandwidth_mbps": 50}

GET /stress/combined?cpu=80&memory=1024&network=50&duration=120&ramp=30
  Ramps all resources simultaneously
  Response: {"status": "started", "targets": {"cpu": 80, "memory": 1024, "network": 50}}

GET /stress/stop
  Stops all active stress tests immediately
  Response: {"status": "stopped", "stopped_tests": ["cpu", "memory"]}
```

**Implementation Details:**

**Gradual Ramp-Up Logic:**
```python
def ramp_up_cpu(target_percent, ramp_seconds):
    steps = ramp_seconds * 10  # 10 steps per second
    increment = target_percent / steps
    current = 0

    for i in range(steps):
        current += increment
        adjust_cpu_load(current)
        sleep(0.1)

    # Maintain target load
    adjust_cpu_load(target_percent)
```

**CPU Load Control:**
- Use process affinity to control CPU usage
- Busy loop with sleep to fine-tune percentage
- Monitor actual CPU usage and adjust dynamically

**Memory Load Control:**
- Allocate memory in chunks (e.g., 10MB increments)
- Write to allocated pages to prevent lazy allocation
- Hold references to prevent garbage collection

**Network Load Control:**
- Generate HTTP requests to self or external endpoint
- Calculate delay between requests to achieve target bandwidth
- Monitor actual bandwidth and adjust request rate

**Technology Recommendations:**
- **Python (Flask/FastAPI):** Easy to implement, good for rapid development
  - Libraries: `psutil` for metrics, `multiprocessing` for CPU stress, `requests` for network
- **Go:** High performance, efficient resource usage, fast startup
  - Built-in concurrency with goroutines
  - Excellent network performance
- **Node.js (Express):** Good event-driven architecture
  - Worker threads for CPU stress
  - Buffers for memory stress

**Container Considerations:**
- Base image: Alpine Linux (small size, fast pull)
- Include monitoring tools: `ps`, `top`, `free`, `netstat` (for debugging)
- Set resource limits in Dockerfile (to test limit scenarios)
- Health check: `HEALTHCHECK CMD curl -f http://localhost:8080/health || exit 1`

**Example Docker Deployment:**
```bash
docker service create \
  --name web-stress \
  --replicas 1 \
  --network swarmguard-net \
  --publish 8080:8080 \
  --health-cmd "curl -f http://localhost:8080/health || exit 1" \
  --health-interval 5s \
  --health-timeout 3s \
  docker-registry.amirmuz.com/web-stress:latest
```

**Testing the Web Stress App:**
Before using in actual tests, verify:
1. Ramp-up is smooth and linear (check in Grafana)
2. Target load is reached accurately (±5%)
3. Load is maintained stable for duration
4. Resources are released cleanly after duration
5. Multiple simultaneous stresses work correctly
6. API is responsive even under stress

---

## 8. Success Criteria

The project is successful if:

1. **Proactive recovery achieves < 10 seconds MTTR** (at least 50% reduction compared to reactive baseline)
2. **Zero downtime or < 2-3 seconds downtime** demonstrated in at least 90% of test cases
3. **No failed HTTP requests** during proactive recovery (continuous availability)
4. **Scenario 1 (migration)** correctly identifies and migrates problematic containers within 5-8 seconds
5. **Scenario 2 (scaling)** correctly scales up within 3-5 seconds and scales down when idle
6. **Alert latency < 1 second** from threshold breach to recovery manager notification
7. **Decision latency < 1 second** from alert received to action initiated
8. **Monitoring overhead** remains under 5% CPU and < 100MB RAM per node
9. **System handles 5 nodes with 20+ containers** without performance degradation
10. **Test scripts successfully automate** validation of all scenarios with precise timing measurements
11. **Grafana dashboards** provide clear visibility into metrics, recovery actions, and performance timings

---

## 9. Future Enhancements (Optional)

- **Machine learning-based prediction:** Use historical data to predict failures before thresholds breached
- **Multi-service orchestration:** Handle dependencies between services during recovery
- **Auto-tuning thresholds:** Dynamically adjust thresholds based on workload patterns
- **Integration with alerting:** Send notifications (Slack, email) when recovery actions taken
- **Support for other orchestrators:** Extend to Kubernetes, Docker Compose, etc.
- **Chaos engineering integration:** Automatically inject faults to validate recovery

---

## 10. Appendix

### 10.1 Docker Swarm Commands Reference

**Service Management:**
```bash
# List services
docker service ls

# Inspect service
docker service inspect <service-name>

# Scale service
docker service scale <service-name>=<replicas>

# Update service (force re-deploy)
docker service update --force <service-name>

# Update service with constraint
docker service update --constraint-add 'node.hostname == worker-3' <service-name>

# Remove service
docker service rm <service-name>
```

**Task Management:**
```bash
# List tasks for a service
docker service ps <service-name>

# List all tasks
docker node ps $(docker node ls -q)

# Inspect task
docker inspect <task-id>
```

**Node Management:**
```bash
# List nodes
docker node ls

# Inspect node
docker node inspect <node-name>

# Drain node (move containers off node)
docker node update --availability drain <node-name>

# Activate node
docker node update --availability active <node-name>
```

### 10.2 InfluxDB Query Examples

**Query container metrics:**
```sql
SELECT mean("cpu_percent")
FROM "container_metrics"
WHERE "service" = 'web' AND time > now() - 5m
GROUP BY time(10s), "container_id"
```

**Query for threshold breaches:**
```sql
SELECT *
FROM "container_metrics"
WHERE "cpu_percent" > 75 AND time > now() - 1h
```

### 10.3 Network Interface Mapping

| Node | Hostname | Network Interface |
|------|----------|-------------------|
| Master | master | enp5s0f0 |
| Worker 1 | worker-1 | eno1 |
| Worker 2 | worker-2 | enp0s25 |
| Worker 3 | worker-3 | enp2s0 |
| Worker 4 | worker-4 | eno1 |

### 10.4 Glossary

- **MTTR:** Mean Time To Recovery - average time to restore service after failure
- **Proactive Recovery:** Taking action before failure occurs
- **Reactive Recovery:** Taking action after failure detected (Docker Swarm default)
- **Zero Downtime:** Service remains available during recovery operations
- **Docker Swarm:** Container orchestration platform built into Docker
- **InfluxDB:** Time-series database for storing metrics
- **Grafana:** Visualization and dashboards for metrics

---

## Document Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-08 | Initial | Initial PRD creation |
| 2.0 | 2025-12-08 | Updated | - Recovery manager runs on master node (not control macOS)<br>- Added worker-11 IP: 192.168.2.61<br>- Added InfluxDB credentials and configuration<br>- Added hybrid communication strategy (continuous + event-driven)<br>- Added in-memory state structure for recovery manager<br>- Added reference to grafana_dashboard.json<br>- Clarified control macOS is only for SSH and testing |
| 3.0 | 2025-12-08 | Performance Focus | **Major Update: Time-Sensitive Operations**<br>- Added strict performance requirements: MTTR < 10s, downtime < 2-3s<br>- Reduced metric collection interval to 5-10 seconds<br>- Added event-driven alert architecture for sub-second latency<br>- Added consecutive breach requirement to avoid false positives<br>- Specified precise timing measurements (T0-T6) for all recovery stages<br>- Added performance targets: alert < 1s, decision < 1s, action 3-8s<br>- Optimized recovery manager logic for async/concurrent operations<br>- Added HTTP keepalive and async optimizations for alerts<br>- Updated success criteria with quantifiable time targets<br>- Emphasized zero-downtime requirement throughout document |
| 4.0 | 2025-12-08 | Testing & Components | **Major Update: Complete Testing Framework**<br>- Added comprehensive component overview table (5 containers + infrastructure)<br>- Added Web Stress Application specification with gradual ramp-up<br>- Added detailed API endpoints for stress testing (CPU/memory/network)<br>- Added 9 test scripts with detailed execution instructions<br>- Added Alpine Pi orchestration scripts for load generation<br>- Added load distribution verification requirements<br>- Clarified baseline MTTR: 10-12 seconds (Docker Swarm default)<br>- Added gradual ramp-up rationale and implementation details<br>- Added load splitting verification (75% → 2 nodes → 37.5% each)<br>- Comprehensive web-stress implementation guide with pseudo-code<br>- All scripts executed from control macOS for centralized testing |
| 5.0 | 2025-12-08 | Rebranding & Network Optimization | **Major Update: SwarmGuard Branding & 100Mbps Optimization**<br>- Rebranded project from "pymonnet" to "SwarmGuard"<br>- Updated all network references: `pymonnet-net` → `swarmguard-net`<br>- Updated InfluxDB organization: `pymonnet` → `swarmguard`<br>- Configuration format: YAML only (removed JSON references)<br>- Added comprehensive network optimization section (4.2) for 100Mbps constraint<br>- Documented bandwidth budget and payload optimization strategies<br>- Added reliability strategies for old hardware and limited network<br>- Alert payload size optimization (< 500 bytes for < 1s delivery)<br>- InfluxDB batching and compression recommendations<br>- HTTP keepalive and connection pooling guidance<br>- Network performance testing requirements |

---

**End of Product Requirements Document**
