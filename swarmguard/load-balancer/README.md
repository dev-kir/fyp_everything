# SwarmGuard Intelligent Load Balancer

An intelligent, metrics-aware load balancer for Docker Swarm that supports multiple routing algorithms.

## Overview

Unlike Docker Swarm's default round-robin load balancing (which doesn't consider container resource usage), this load balancer makes intelligent routing decisions based on:
- **Active request count** (lease-based algorithm)
- **Real-time resource metrics** (CPU, Memory, Network from monitoring-agents)
- **Hybrid approach** (combining both lease and metrics)

## Supported Algorithms

### 1. Lease-Based (Default)
Routes requests to the replica with the fewest active "leases" (in-flight requests).

**How it works:**
- When a request arrives, the LB assigns a "lease" to the selected replica
- Leases expire after `LEASE_DURATION` seconds (default: 30s)
- Next request goes to the replica with the fewest active leases
- Fast decision-making (no metrics queries needed)

**Best for:** Uniform request workloads where all requests take similar time

**Configuration:**
```bash
LB_ALGORITHM=lease
LEASE_DURATION=30              # Seconds
LEASE_CLEANUP_INTERVAL=1       # Cleanup frequency
```

### 2. Metrics-Based
Routes requests to the replica with the lowest resource utilization score.

**How it works:**
- Queries monitoring-agents every `CACHE_TTL` seconds
- Calculates score: `(CPU% × 0.5) + (Memory% × 0.3) + (Network% × 0.2)`
- Routes to replica with minimum score
- Resource-aware routing

**Best for:** Workloads where resource consumption varies significantly

**Configuration:**
```bash
LB_ALGORITHM=metrics
CACHE_TTL=1                    # Metrics refresh interval (seconds)
CPU_WEIGHT=0.5                 # CPU weight in score calculation
MEMORY_WEIGHT=0.3              # Memory weight
NETWORK_WEIGHT=0.2             # Network weight
```

### 3. Hybrid (Lease + Metrics)
Combines lease count AND resource metrics for best accuracy.

**How it works:**
- Tracks both active leases AND real-time metrics
- Score: `(lease_count × 10) + (CPU% × 0.5) + (Memory% × 0.3) + (Network% × 0.2)`
- Routes to replica with lowest combined score
- Balances request count AND resource utilization

**Best for:** Production environments requiring optimal load distribution

**Configuration:**
```bash
LB_ALGORITHM=hybrid
LEASE_COUNT_WEIGHT=10.0        # Weight for lease count in score
# Plus all metrics-based config
```

### 4. Round-Robin (Fallback)
Simple sequential distribution (same as Docker Swarm default).

**When used:**
- Explicitly configured: `LB_ALGORITHM=round-robin`
- Automatic fallback when metrics unavailable
- Debugging/testing

## Architecture

```
Alpine Nodes (Load Generators)
    ↓
Intelligent Load Balancer (192.168.2.50:8081)
    ├─ Query monitoring-agents for metrics (if needed)
    ├─ Track active leases (if using lease/hybrid)
    ├─ Calculate routing decision
    ↓
Route to selected replica:
    ├→ Worker-1: web-stress.1 (CPU: 30%, leases: 2)
    ├→ Worker-2: web-stress.2 (CPU: 75%, leases: 8)
    └→ Worker-3: web-stress.3 (CPU: 45%, leases: 4) ✅ SELECTED
```

## Deployment

### Prerequisites

1. **Monitoring agents** must be running on all worker nodes with API server enabled:
   ```bash
   API_ENABLED=true
   API_PORT=8082
   ```

2. **Web-stress service** (or target service) must be deployed

3. **Docker Swarm network** `swarmguard-net` must exist

### Deploy Load Balancer

```bash
cd /Users/amirmuz/code/claude_code/fyp_everything/swarmguard/tests

# Deploy with lease-based algorithm (default)
./deploy_load_balancer.sh lease

# Deploy with metrics-based algorithm
./deploy_load_balancer.sh metrics

# Deploy with hybrid algorithm
./deploy_load_balancer.sh hybrid

# Deploy with round-robin (testing only)
./deploy_load_balancer.sh round-robin
```

### Verify Deployment

```bash
# Check service status
ssh master "docker service ps intelligent-lb"

# View logs
ssh master "docker service logs -f intelligent-lb"

# Test health endpoint
curl http://192.168.2.50:8081/health

# Test metrics endpoint
curl http://192.168.2.50:8081/metrics
```

## Testing

### Manual Testing

```bash
# Send requests through load balancer
for i in {1..100}; do
    curl http://192.168.2.50:8081/health
done

# View routing decisions in logs
ssh master "docker service logs intelligent-lb | grep 'Selected'"
```

### Scenario 2 Testing (Scaling)

```bash
# Test with intelligent LB (port 8081)
SERVICE_URL='http://192.168.2.50:8081' \
    ./alpine_test_scenario2_v4_incremental.sh 2 50 5 60 120 10

# Compare with Docker Swarm (port 8080)
SERVICE_URL='http://192.168.2.50:8080' \
    ./alpine_test_scenario2_v4_incremental.sh 2 50 5 60 120 10
```

### Algorithm Comparison

```bash
# Run comprehensive comparison of all algorithms
./compare_lb_algorithms.sh

# Results saved to /tmp/lb_comparison_<timestamp>/
```

## Configuration Reference

### Core Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `LB_ALGORITHM` | `lease` | Algorithm: `lease`, `metrics`, `hybrid`, `round-robin` |
| `LB_PORT` | `8081` | Load balancer listening port |
| `TARGET_SERVICE` | `web-stress` | Service name to load balance |
| `WORKER_NODES` | `worker-1,worker-2,worker-3` | Comma-separated worker node hostnames |

### Lease Algorithm

| Variable | Default | Description |
|----------|---------|-------------|
| `LEASE_DURATION` | `30` | Lease expiration time (seconds) |
| `LEASE_CLEANUP_INTERVAL` | `1` | Expired lease cleanup frequency (seconds) |

### Metrics Algorithm

| Variable | Default | Description |
|----------|---------|-------------|
| `METRICS_PORT` | `8082` | Monitoring-agent API port |
| `CACHE_TTL` | `1` | Metrics cache refresh interval (seconds) |
| `CPU_WEIGHT` | `0.5` | CPU weight in score calculation |
| `MEMORY_WEIGHT` | `0.3` | Memory weight in score calculation |
| `NETWORK_WEIGHT` | `0.2` | Network weight in score calculation |

### Hybrid Algorithm

| Variable | Default | Description |
|----------|---------|-------------|
| `LEASE_COUNT_WEIGHT` | `10.0` | Weight for active lease count |
| (All metrics settings above) | - | Used for resource scoring |

### Health & Logging

| Variable | Default | Description |
|----------|---------|-------------|
| `HEALTH_CHECK_INTERVAL` | `5` | Replica health check interval (seconds) |
| `FALLBACK_ENABLED` | `true` | Fallback to round-robin on errors |
| `DEBUG_ROUTING` | `false` | Log every routing decision |
| `LOG_EVERY_N_REQUESTS` | `100` | Log summary every N requests |

## API Endpoints

### Load Balancer Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check (returns algorithm, replica count, request count) |
| `/metrics` | GET | Load balancer metrics (lease counts, replica details) |
| `/*` | ANY | Proxy to selected replica |

**Example:**

```bash
# Health check
curl http://192.168.2.50:8081/health
# {
#   "status": "healthy",
#   "algorithm": "lease",
#   "healthy_replicas": 3,
#   "total_requests": 1523
# }

# Metrics
curl http://192.168.2.50:8081/metrics
# {
#   "total_requests": 1523,
#   "algorithm": "lease",
#   "healthy_replicas": 3,
#   "active_leases": {
#     "worker-1:web-stress.1": 5,
#     "worker-2:web-stress.2": 2,
#     "worker-3:web-stress.3": 8
#   },
#   "replica_details": { ... }
# }
```

### Monitoring-Agent API Endpoints

The load balancer queries monitoring-agents on each worker node:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `http://<worker>:8082/metrics/containers` | GET | Container metrics for load balancing |
| `http://<worker>:8082/health` | GET | Agent health check |

## Comparison: Ports 8080 vs 8081

| Port | Load Balancer | Algorithm | Resource-Aware | Request-Aware |
|------|---------------|-----------|----------------|---------------|
| 8080 | Docker Swarm (native) | Round-robin | ❌ No | ❌ No |
| 8081 | SwarmGuard Intelligent LB | Configurable (lease/metrics/hybrid) | ✅ Yes (metrics/hybrid) | ✅ Yes (lease/hybrid) |

**Benefits of port 8081 (Intelligent LB):**
- Routes to least-loaded replicas (better resource utilization)
- Reduces max CPU across replicas (more even distribution)
- Adapts to varying workloads
- Supports multiple algorithms for different use cases

## Performance Characteristics

### Lease-Based
- **Decision time:** < 1ms (just count leases)
- **Network overhead:** None (no metrics queries per request)
- **Accuracy:** Medium-High (assumes uniform request duration)

### Metrics-Based
- **Decision time:** < 5ms (lookup cached metrics)
- **Network overhead:** Low (queries every 1s, cached)
- **Accuracy:** High (real resource utilization)

### Hybrid
- **Decision time:** < 5ms (lookup cache + count leases)
- **Network overhead:** Low (queries every 1s, cached)
- **Accuracy:** Very High (both request count AND resources)

## Troubleshooting

### Load balancer not routing

```bash
# Check service is running
ssh master "docker service ls | grep intelligent-lb"

# Check logs for errors
ssh master "docker service logs intelligent-lb | tail -50"

# Verify monitoring-agents have API enabled
curl http://worker-1:8082/metrics/containers
```

### Metrics unavailable

```bash
# Check monitoring-agent API
for worker in worker-1 worker-2 worker-3; do
    echo "Testing $worker..."
    curl -s http://$worker:8082/health | jq .
done

# Verify API_ENABLED=true in monitoring-agent deployment
ssh master "docker service inspect monitoring-agent-worker1 | grep API"
```

### All requests go to one replica

```bash
# Check if using round-robin fallback
ssh master "docker service logs intelligent-lb | grep fallback"

# Verify metrics are being fetched
ssh master "docker service logs intelligent-lb | grep 'Metrics cache updated'"

# Check lease counts
curl http://192.168.2.50:8081/metrics | jq '.active_leases'
```

## Development

### Local Testing

```bash
# Build image
cd /Users/amirmuz/code/claude_code/fyp_everything/swarmguard/load-balancer
docker build -t swarmguard-load-balancer:latest .

# Run locally (mock environment)
docker run -it --rm \
    -p 8081:8081 \
    -e LB_ALGORITHM=lease \
    -e DEBUG_ROUTING=true \
    swarmguard-load-balancer:latest
```

### Code Structure

```
load-balancer/
├── lb.py              # Main load balancer implementation
│   ├── LeaseManager   # Lease tracking & cleanup
│   └── LoadBalancer   # Routing algorithms & HTTP proxy
├── Dockerfile         # Container image
├── requirements.txt   # Python dependencies
└── README.md         # This file
```

## References

- **PRD:** `/Users/amirmuz/code/claude_code/fyp_everything/swarmguard/PRD_INTELLIGENT_LOAD_BALANCER.md`
- **Deployment Script:** `/Users/amirmuz/code/claude_code/fyp_everything/swarmguard/tests/deploy_load_balancer.sh`
- **Comparison Script:** `/Users/amirmuz/code/claude_code/fyp_everything/swarmguard/tests/compare_lb_algorithms.sh`
- **Monitoring Agent:** `/Users/amirmuz/code/claude_code/fyp_everything/swarmguard/monitoring-agent/`

## License

Part of the SwarmGuard project - FYP 2025
