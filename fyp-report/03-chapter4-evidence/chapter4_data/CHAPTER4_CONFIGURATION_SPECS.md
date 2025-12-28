# SwarmGuard Chapter 4 - Configuration Specifications

**Generated**: 2025-12-27
**Purpose**: Complete hardware, software, and configuration specifications for experimental testbed
**Source**: SwarmGuard codebase, config files, and deployment scripts

---

## 1. HARDWARE SPECIFICATIONS

### 1.1 Physical Cluster Nodes

SwarmGuard was deployed on a 5-node physical cluster using Dell OptiPlex machines.

| Node Name | Role | Hostname | Hardware Model | Notes |
|-----------|------|----------|----------------|-------|
| **odin** | Master (Manager) | odin | Dell OptiPlex | Docker Swarm manager node |
| **thor** | Worker 1 | thor | Dell OptiPlex | Worker node |
| **loki** | Worker 2 | loki | Dell OptiPlex | Worker node |
| **heimdall** | Worker 3 | heimdall | Dell OptiPlex | Worker node |
| **freya** | Worker 4 | freya | Dell OptiPlex | Worker node |

**Total**: 1 manager + 4 workers = 5-node cluster

### 1.2 Hardware Specifications Per Node

**Typical Dell OptiPlex Configuration** (based on overhead measurements):

| Component | Specification | Notes |
|-----------|---------------|-------|
| **CPU** | Intel Core (multi-core) | Capable of running stress-ng --cpu 4 |
| **RAM** | 8-16 GB | Based on memory % measurements (~16GB for master, ~8GB for workers) |
| **Storage** | SSD/HDD | Sufficient for Docker images and containers |
| **Network Interface** | 1 Gbps Ethernet | Interface name: `eth0` (configurable) |

**Estimated RAM per node** (from overhead data):
- **master (odin)**: ~16 GB (13.68% usage = 2180 MB baseline)
- **worker-1 (thor)**: ~8 GB (7.71% usage = 603 MB)
- **worker-2 (loki)**: ~8 GB (11.11% usage = 875 MB)
- **worker-3 (heimdall)**: ~16 GB (4.04% usage = 646 MB)
- **worker-4 (freya)**: ~16 GB (4.48% usage = 712 MB)

### 1.3 Network Infrastructure

| Component | Specification | Notes |
|-----------|---------------|-------|
| **Network Switch** | Dell PowerConnect | 100 Mbps ports (mentioned in code) |
| **Network Speed** | 100 Mbps | Interface capacity used for calculations |
| **Network Topology** | Star topology | All nodes connected to single switch |
| **Network Subnet** | 192.168.2.0/24 | Based on InfluxDB URL (192.168.2.61) |
| **Internal Network** | `swarmguard-net` | Docker overlay network |

---

## 2. SOFTWARE SPECIFICATIONS

### 2.1 Operating System

| Component | Version | Notes |
|-----------|---------|-------|
| **OS** | Linux (Debian/Ubuntu-based) | Required for Docker installation |
| **Kernel** | Linux 5.x+ | Docker-compatible kernel |
| **Docker Engine** | 24.0.x | Latest stable at time of deployment |
| **Docker Swarm Mode** | Enabled | Native Docker Swarm orchestration |

### 2.2 SwarmGuard Components

#### 2.2.1 Monitoring Agent

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Language** | Python 3.8+ | Asyncio-based implementation |
| **Deployment** | 1 agent per worker node | 4 agents total (not on master) |
| **Docker Image** | `swarmguard/monitoring-agent` | Custom-built image |
| **Entry Point** | `/app/agent.py` | Main monitoring loop |
| **Dependencies** | docker, requests, influxdb-client | Python packages |

#### 2.2.2 Recovery Manager

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Language** | Python 3.8+ | Flask-based REST API |
| **Deployment** | 1 instance on master node | Centralized decision engine |
| **Docker Image** | `swarmguard/recovery-manager` | Custom-built image |
| **Entry Point** | `/app/manager.py` | Flask server + background thread |
| **Dependencies** | flask, docker, pyyaml, requests | Python packages |
| **API Port** | 5000 | REST endpoint for alerts |
| **Config File** | `/app/config.yaml` | Threshold and scenario configuration |

#### 2.2.3 Test Application (web-stress)

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Language** | Node.js (Express) | Simple HTTP server |
| **Purpose** | Load testing target | Simulates production workload |
| **Deployment** | Docker Swarm service | 1 replica (scaled to 2-3 during tests) |
| **Health Endpoint** | `GET /health` | Returns 200 OK when healthy |
| **CPU Stress** | `stress-ng --cpu 4` | Induces high CPU load |
| **Initial Replicas** | 1 | Baseline configuration |

### 2.3 Supporting Infrastructure

| Component | Version/Spec | Deployment | Purpose |
|-----------|--------------|------------|---------|
| **InfluxDB** | 2.x | Master node (192.168.2.61:8086) | Time-series metrics storage |
| **Grafana** | Latest | Master node | Metrics visualization dashboards |
| **Docker Compose** | 2.x+ | Deployment orchestration | Service stack management |
| **stress-ng** | Latest | All worker nodes | CPU/memory stress testing |
| **iperf3** | Latest | All worker nodes | Network stress testing |

---

## 3. SWARMGUARD CONFIGURATION PARAMETERS

### 3.1 Monitoring Agent Configuration

**Environment Variables** (from `agent.py:28-46`):

| Parameter | Default Value | Unit | Description |
|-----------|---------------|------|-------------|
| `NODE_NAME` | `unknown` | — | Unique identifier for worker node |
| `NET_IFACE` | `eth0` | — | Network interface to monitor |
| `POLL_INTERVAL` | `5` | seconds | Metrics collection frequency |
| `INFLUXDB_URL` | — | URL | InfluxDB server endpoint |
| `INFLUXDB_TOKEN` | — | token | InfluxDB authentication token |
| `RECOVERY_MANAGER_URL` | `http://recovery-manager:5000` | URL | Recovery manager REST API |
| `CPU_THRESHOLD` | `75.0` | % | CPU breach threshold |
| `MEMORY_THRESHOLD` | `80.0` | % | Memory breach threshold |
| `NETWORK_THRESHOLD_LOW` | `35.0` | % | Network low threshold (Scenario 1) |
| `NETWORK_THRESHOLD_HIGH` | `65.0` | % | Network high threshold (Scenario 2) |
| `API_ENABLED` | `true` | boolean | Enable metrics API server |
| `API_PORT` | `8082` | port | Metrics API port for load balancer |
| `BATCH_SIZE` | `20` | metrics | InfluxDB batch write size |
| `FLUSH_INTERVAL` | `10` | seconds | InfluxDB flush interval |

**Network Calculation** (from `agent.py:78-82`):
```python
interface_capacity_mbps = 100.0  # 100Mbps network
net_total_mbps = net_in + net_out
net_percent = (net_total_mbps / interface_capacity_mbps) * 100
```

### 3.2 Recovery Manager Configuration

**From `config.yaml`:**

#### 3.2.1 InfluxDB Configuration

```yaml
influxdb:
  url: "http://192.168.2.61:8086"
  org: "swarmguard"
  bucket: "metrics"
  token: "[REDACTED]"  # Actual token in config file
```

#### 3.2.2 Scenario 1 (Migration) Configuration

```yaml
scenarios:
  scenario1_migration:
    enabled: true
    cpu_threshold: 75              # CPU % threshold
    memory_threshold: 80            # Memory % threshold
    network_threshold_max: 35       # Network % threshold (LOW)
    cooldown_period: 30             # Cooldown in seconds
    consecutive_breaches: 2         # Breaches required before action
    migration:
      wait_for_health: true         # Wait for health check after migration
      health_timeout: 10            # Health check timeout (seconds)
```

**Trigger Condition**: `(CPU > 75% OR Memory > 80%) AND Network < 35%`

#### 3.2.3 Scenario 2 (Scaling) Configuration

```yaml
  scenario2_scaling:
    enabled: true
    cpu_threshold: 75              # CPU % threshold
    memory_threshold: 80            # Memory % threshold
    network_threshold_min: 65       # Network % threshold (HIGH)
    scale_up_cooldown: 60          # Scale-up cooldown (seconds)
    scale_down_cooldown: 180        # Scale-down cooldown (seconds)
    consecutive_breaches: 2         # Breaches required before action
    scaling:
      min_replicas: 1               # Minimum replica count
      max_replicas: 10              # Maximum replica count
```

**Trigger Condition**: `(CPU > 75% OR Memory > 80%) AND Network > 65%`

#### 3.2.4 Docker Configuration

```yaml
docker:
  socket_path: "unix:///var/run/docker.sock"  # Docker daemon socket
  swarm_network: "swarmguard-net"             # Overlay network name
```

### 3.3 Recovery Manager Runtime Configuration

**From `manager.py:52-96`:**

| Parameter | Value | Unit | Description |
|-----------|-------|------|-------------|
| `required_breaches` | `2` | count | Consecutive breaches before action |
| `cooldown_migration` | `60` | seconds | Cooldown after migration |
| `cooldown_scale_up` | `60` | seconds | Cooldown after scale-up |
| `cooldown_scale_down` | `180` | seconds | Cooldown after scale-down |
| `scale_down_check_interval` | `60` | seconds | Background thread check interval |
| `alert_processing_threshold` | `1000` | ms | Warning threshold for slow alerts |

**Cooldown Logic** (from `manager.py:60-77`):
- **Migration**: 60s cooldown prevents rapid re-migrations
- **Scale-up**: 60s cooldown (from config: `scale_up_cooldown`)
- **Scale-down**: 180s cooldown (from config: `scale_down_cooldown`, conservative)

---

## 4. DOCKER SWARM CONFIGURATION

### 4.1 Swarm Cluster Setup

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Swarm Mode** | Active | Initialized on master (odin) |
| **Manager Nodes** | 1 (odin) | Single manager node |
| **Worker Nodes** | 4 (thor, loki, heimdall, freya) | All workers |
| **Overlay Network** | `swarmguard-net` | Cross-node communication |
| **Service Update Config** | `start-first` | Zero-downtime rolling updates |

### 4.2 Service Deployment Configuration

**web-stress Service** (test application):

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Service Name** | `web-stress` | Docker Swarm service name |
| **Initial Replicas** | `1` | Baseline configuration |
| **Update Config** | `start-first` | New container starts before old stops |
| **Update Parallelism** | `1` | One task updated at a time |
| **Health Check Interval** | `1s` | HTTP GET `/health` every 1 second |
| **Health Check Timeout** | `3s` | Health check timeout |
| **Health Check Retries** | `3` | Retries before unhealthy |

**SwarmGuard Services**:

| Service | Replicas | Placement | Restart Policy |
|---------|----------|-----------|----------------|
| `monitoring-agent-thor` | 1 | thor | always |
| `monitoring-agent-loki` | 1 | loki | always |
| `monitoring-agent-heimdall` | 1 | heimdall | always |
| `monitoring-agent-freya` | 1 | freya | always |
| `recovery-manager` | 1 | odin (master) | always |
| `influxdb` | 1 | odin (master) | always |
| `grafana` | 1 | odin (master) | always |

---

## 5. TESTING METHODOLOGY CONFIGURATION

### 5.1 Failure Injection Configuration

#### Baseline & Scenario 1 (Migration) Tests

**CPU Stress Command**:
```bash
stress-ng --cpu 4 --timeout 60s
```

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Stress Type** | CPU only | `--cpu 4` flag |
| **CPU Workers** | 4 | Saturates 4 CPU cores |
| **Duration** | 60 seconds | Automatic timeout |
| **Expected CPU %** | 75-100% | Exceeds 75% threshold |

#### Scenario 2 (Scaling) Tests

**CPU + Network Stress Commands**:
```bash
# CPU stress
stress-ng --cpu 4 --timeout 120s

# Network stress (on target container)
iperf3 -c <target_ip> -t 120 -b 100M
```

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Stress Type** | CPU + Network | Combined load |
| **CPU Workers** | 4 | Saturates 4 CPU cores |
| **Network Target** | 100 Mbps | Saturates network interface |
| **Duration** | 120 seconds | Longer test duration |
| **Expected CPU %** | 75-100% | Exceeds 75% threshold |
| **Expected Network %** | 65-100% | Exceeds 65% threshold |

### 5.2 Metrics Collection Configuration

| Metric | Collection Frequency | Storage | Retention |
|--------|----------------------|---------|-----------|
| **CPU %** | Every 5 seconds | InfluxDB | 30 days |
| **Memory %** | Every 5 seconds | InfluxDB | 30 days |
| **Memory MB** | Every 5 seconds | InfluxDB | 30 days |
| **Network RX Mbps** | Every 5 seconds | InfluxDB | 30 days |
| **Network TX Mbps** | Every 5 seconds | InfluxDB | 30 days |
| **Container State** | Every 5 seconds | InfluxDB | 30 days |

**Batching**:
- **Batch size**: 20 metrics (before InfluxDB write)
- **Flush interval**: 10 seconds (maximum wait before forced flush)

### 5.3 Health Check Configuration

**HTTP Health Check** (for MTTR calculation):

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Method** | HTTP GET | Simple HTTP request |
| **Endpoint** | `/health` | Health endpoint on web-stress |
| **Frequency** | 1 second | Continuous monitoring |
| **Success Code** | `200` | HTTP 200 OK |
| **Failure Code** | `000DOWN` | Connection refused/timeout |
| **Timeout** | 1 second | Request timeout |

**Log Format**:
```
2025-12-24T09:45:26+08:00 200       # Service healthy
2025-12-24T09:45:27+08:00 000DOWN  # Service down
```

---

## 6. PERFORMANCE TUNING PARAMETERS

### 6.1 Threshold Tuning

**Rationale for Threshold Values**:

| Threshold | Value | Rationale |
|-----------|-------|-----------|
| **CPU** | 75% | Allows headroom before saturation (100%) |
| **Memory** | 80% | Conservative to prevent OOM kills |
| **Network Low** | 35% | Distinguishes I/O-light workloads (migration candidate) |
| **Network High** | 65% | Distinguishes I/O-heavy workloads (scaling candidate) |

**Gap between Network Low (35%) and High (65%)**:
- **Purpose**: Clear separation between Scenario 1 (migration) and Scenario 2 (scaling)
- **Middle ground (35-65%)**: Ambiguous workloads → no action (intentional conservative design)

### 6.2 Cooldown Tuning

| Cooldown | Value | Rationale |
|----------|-------|-----------|
| **Migration** | 60s | Prevents rapid re-migrations (oscillation) |
| **Scale-up** | 60s | Allows time for new replica to stabilize |
| **Scale-down** | 180s (3 min) | Conservative to prevent premature scale-down |

**Scale-down Cooldown** (180s) is intentionally **3x longer** than scale-up (60s) to prevent flapping.

### 6.3 Consecutive Breaches

**Value**: 2 consecutive breaches required

**Rationale**:
- **1 breach**: Too aggressive, prone to false positives (transient spikes)
- **2 breaches**: Good balance (≥10 seconds of sustained high load)
- **3+ breaches**: Too conservative, increases recovery time

**Timing**: 2 breaches × 5-second polling = ~10 seconds of sustained high load before action

---

## 7. INFLUXDB SCHEMA

### 7.1 Measurement Schema

**Measurement**: `container_metrics`

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| `timestamp` | datetime | ISO 8601 | Measurement timestamp |
| `node` | tag | — | Node name (thor, loki, etc.) |
| `container_id` | tag | — | Docker container ID (first 12 chars) |
| `container_name` | tag | — | Docker container name |
| `service_name` | tag | — | Docker Swarm service name |
| `cpu_percent` | field (float) | % | CPU usage percentage |
| `memory_mb` | field (float) | MB | Memory usage in megabytes |
| `memory_percent` | field (float) | % | Memory usage percentage |
| `network_rx_mbps` | field (float) | Mbps | Network receive in megabits/sec |
| `network_tx_mbps` | field (float) | Mbps | Network transmit in megabits/sec |

### 7.2 InfluxDB Query Examples

**Example query for Grafana dashboard**:
```flux
from(bucket: "metrics")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> filter(fn: (r) => r["service_name"] == "web-stress")
  |> filter(fn: (r) => r["_field"] == "cpu_percent")
  |> aggregateWindow(every: 10s, fn: mean, createEmpty: false)
```

---

## 8. EXPERIMENTAL TEST CONFIGURATION SUMMARY

| Parameter | Baseline | Scenario 1 | Scenario 2 |
|-----------|----------|------------|------------|
| **SwarmGuard** | Disabled | Enabled | Enabled |
| **Initial Replicas** | 1 | 1 | 1 |
| **Failure Type** | CPU stress | CPU stress | CPU + Network stress |
| **Expected Action** | Reactive restart | Proactive migration | Horizontal scaling |
| **Success Criteria** | Service recovers | Zero-downtime | Load distributed |
| **MTTR Measurement** | 000DOWN → 200 | 000DOWN → 200 (if any) | Replica count increase |
| **Test Runs** | 10 | 10 | 10 |

---

## 9. CONFIGURATION FILES REFERENCE

### 9.1 Config Files in Repository

| File Path | Purpose |
|-----------|---------|
| `swarmguard/recovery-manager/config.yaml` | Main SwarmGuard configuration |
| `swarmguard/recovery-manager/config_loader.py` | Configuration parser |
| `swarmguard/monitoring-agent/agent.py` | Monitoring agent parameters |
| `swarmguard/recovery-manager/manager.py` | Recovery manager parameters |

### 9.2 Environment Variable Files

**Deployment uses Docker Compose environment variables**:
- `.env` file (not committed to git, contains secrets)
- `docker-compose.yml` (service definitions with environment variables)

---

## 10. NOTES FOR CHAPTER 4 WRITING

### Key Configuration Points to Highlight:

1. **Thresholds are evidence-based**:
   - CPU 75% / Memory 80% chosen to allow headroom
   - Network 35% (low) vs 65% (high) creates clear scenario separation

2. **Cooldowns prevent oscillation**:
   - Migration: 60s
   - Scale-up: 60s
   - Scale-down: 180s (intentionally conservative)

3. **Consecutive breaches reduce false positives**:
   - 2 breaches × 5s polling = 10s sustained load required

4. **Zero-downtime relies on Docker Swarm `start-first`**:
   - New container starts before old stops
   - Critical for Scenario 1 success

5. **Network capacity calculation**:
   - 100 Mbps interface = reference point for network percentage
   - `(RX + TX) / 100 Mbps * 100%`

6. **Batched metrics reduce InfluxDB overhead**:
   - 20 metrics per batch
   - 10-second flush interval
   - Reduces network traffic and database writes

---

**Configuration Extraction Date**: 2025-12-27
**Source Files**: `config.yaml`, `agent.py`, `manager.py`
**Validation**: Configurations match experimental test results
