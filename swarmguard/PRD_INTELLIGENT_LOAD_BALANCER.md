# PRD: Intelligent Load Balancer for SwarmGuard

## 1. Overview

**Feature Name**: Metrics-Based Intelligent Load Balancer
**Status**: Proposed (Not Yet Implemented)
**Estimated Effort**: 3-4 hours
**Priority**: Medium (Enhancement)

### Purpose
Add an intelligent load balancer that routes traffic to the least-utilized container replica based on real-time metrics from the monitoring-agent, replacing Docker Swarm's default round-robin algorithm.

### Business Value
- **Better resource utilization**: Routes requests to least-loaded replicas
- **Enterprise-grade architecture**: Demonstrates proper separation of concerns
- **FYP differentiation**: Shows both proactive (LB) and reactive (recovery-manager) strategies
- **No application changes**: Uses existing infrastructure (monitoring-agent)

---

## 2. Current State vs. Proposed State

### Current Architecture (Round-Robin)
```
Alpine Nodes
    ↓
Master Node (192.168.2.50:8080)
    ↓
Docker Swarm IPVS (round-robin - NOT resource-aware)
    ↓
    ├──→ Worker-1: web-stress replica 1 (CPU: 80%)
    ├──→ Worker-2: web-stress replica 2 (CPU: 45%)
    └──→ Worker-3: web-stress replica 3 (CPU: 60%)
```

**Problem**: Round-robin doesn't consider current load. May route to an already-busy replica.

### Proposed Architecture (Metrics-Based)
```
Alpine Nodes
    ↓
Intelligent Load Balancer (192.168.2.50:8081)
    ├─ Queries worker-1 monitoring-agent:8082 → "web-stress.1 CPU=80%"
    ├─ Queries worker-2 monitoring-agent:8082 → "web-stress.2 CPU=45%" ✅ CHOOSE
    └─ Queries worker-3 monitoring-agent:8082 → "web-stress.3 CPU=60%"
    ↓
Routes to worker-2 (least-utilized)
```

**Solution**: Load balancer queries monitoring-agents every 1 second, routes to least-loaded replica.

---

## 3. Technical Architecture

### 3.1 Components

#### Component 1: Monitoring-Agent HTTP API (NEW)
**File**: `swarmguard/monitoring-agent/api_server.py`

**Purpose**: Expose container metrics via HTTP endpoint

**API Endpoint**:
```
GET http://<worker-ip>:8082/metrics/containers

Response:
{
  "node": "worker-1",
  "timestamp": 1734567890,
  "containers": [
    {
      "container_id": "abc123...",
      "container_name": "web-stress.1.xyz",
      "service_name": "web-stress",
      "cpu_percent": 45.2,
      "memory_mb": 128.5,
      "memory_percent": 12.8,
      "network_rx_mbps": 15.3,
      "network_tx_mbps": 12.1
    }
  ]
}
```

**Technology**:
- `aiohttp` (lightweight async HTTP server)
- Runs alongside existing monitoring loop
- Port: 8082 (configurable)

**Changes to Existing Code**:
```python
# In agent.py - add ~10 lines
from api_server import MetricsAPIServer

class MonitoringAgent:
    def __init__(self):
        # ... existing code ...
        self.api_server = MetricsAPIServer(port=8082)

    async def run(self):
        # Start API server in background
        await self.api_server.start(self.get_latest_metrics)
        # ... existing monitoring loop ...
```

**Estimated Lines of Code**: ~50 lines new, ~10 lines modified

---

#### Component 2: Intelligent Load Balancer (NEW)
**Directory**: `swarmguard/load-balancer/`

**Files**:
- `lb.py` - Main load balancer logic
- `Dockerfile` - Container image
- `requirements.txt` - Python dependencies

**Core Logic**:
```python
class LoadBalancer:
    def __init__(self):
        self.worker_nodes = ['worker-1', 'worker-2', 'worker-3']
        self.metrics_cache = {}  # Cached metrics from workers
        self.cache_ttl = 1  # Refresh every 1 second

    async def get_least_loaded_replica(self, service_name='web-stress'):
        # Query all worker monitoring-agents
        all_metrics = await self.fetch_all_metrics()

        # Filter for target service
        replicas = [
            m for m in all_metrics
            if m['service_name'] == service_name
        ]

        # Find replica with lowest CPU
        best_replica = min(replicas, key=lambda x: x['cpu_percent'])
        return best_replica['node_ip'], best_replica['container_ip']

    async def proxy_request(self, request):
        # Get least-loaded replica
        node_ip, container_ip = await self.get_least_loaded_replica()

        # Proxy request to that replica
        async with aiohttp.ClientSession() as session:
            async with session.request(
                method=request.method,
                url=f"http://{container_ip}:8080{request.path}",
                headers=request.headers,
                data=await request.read()
            ) as response:
                return web.Response(
                    status=response.status,
                    body=await response.read(),
                    headers=response.headers
                )
```

**Routing Algorithms**:

SwarmGuard supports **three load balancing algorithms**:

### Algorithm 1: Lease-Based (NEW - Primary Algorithm)
1. **Lease Assignment**: When a request arrives, assign it to the replica with the fewest active leases
2. **Lease Tracking**: Track active leases per replica with expiration timestamps
3. **Lease Expiration**: Leases expire after `LEASE_DURATION` seconds (default: 30s)
4. **Lease Renewal**: Automatically clean up expired leases every 1 second
5. **Benefits**: Fast decision (no metrics query needed), request-count aware, low overhead

**Lease Logic**:
```python
# Pseudo-code
active_leases = {
    'worker-1:web-stress.1': [
        {'request_id': 'req-123', 'expires_at': 1734568920},
        {'request_id': 'req-456', 'expires_at': 1734568925}
    ],  # 2 active leases
    'worker-2:web-stress.2': [
        {'request_id': 'req-789', 'expires_at': 1734568930}
    ],  # 1 active lease ✅ CHOOSE THIS
    'worker-3:web-stress.3': []  # 0 active leases (but may be unhealthy)
}

# Route to replica with minimum active leases (after filtering unhealthy)
```

### Algorithm 2: Least-Loaded (Metrics-Based)
1. Every 1 second: Query all monitoring-agents for container metrics
2. For incoming request: Find all replicas of target service
3. Calculate load score: `score = (cpu_percent * 0.5) + (memory_percent * 0.3) + (network_percent * 0.2)`
4. Route to replica with lowest score
5. Fallback: If metrics unavailable, use round-robin

### Algorithm 3: Hybrid (Lease + Metrics) - Best of Both Worlds
1. Query metrics every 1 second (background task)
2. For each replica, calculate combined score:
   ```python
   score = (active_lease_count * 10) + (cpu_percent * 0.5) + (memory_percent * 0.3) + (network_percent * 0.2)
   ```
3. Route to replica with lowest combined score
4. This balances both request count AND resource utilization

### Algorithm Selection
Configurable via environment variable:
```bash
LB_ALGORITHM="lease"       # Lease-based (default, fastest)
LB_ALGORITHM="metrics"     # Metrics-based (resource-aware)
LB_ALGORITHM="hybrid"      # Lease + Metrics (best accuracy)
LB_ALGORITHM="round-robin" # Fallback (no intelligence)
```

**Health Checking**:
- Monitor /health endpoint of each replica
- Remove unhealthy replicas from pool
- Re-add when healthy again

**Estimated Lines of Code**: ~150 lines

---

### 3.2 Deployment

#### Monitoring-Agent Changes
```bash
# Add new dependency
echo "aiohttp==3.9.0" >> swarmguard/monitoring-agent/requirements.txt

# Rebuild and redeploy
cd swarmguard/monitoring-agent
docker build -t docker-registry.amirmuz.com/swarmguard-monitoring-agent:latest .
docker push docker-registry.amirmuz.com/swarmguard-monitoring-agent:latest

# Redeploy monitoring-agent on all workers (will add HTTP API on port 8082)
./deploy_monitoring_agent.sh
```

#### Load Balancer Deployment
```bash
# New deployment script
cd swarmguard/tests
./deploy_load_balancer.sh

# What it does:
# 1. Builds load balancer Docker image
# 2. Pushes to registry
# 3. Deploys as Docker Swarm service on master node
# 4. Publishes port 8081
```

**Docker Service Configuration**:
```bash
docker service create \
  --name intelligent-lb \
  --replicas 1 \
  --constraint 'node.role==manager' \
  --network swarmguard-net \
  --publish 8081:8081 \
  --env WORKER_NODES="worker-1,worker-2,worker-3" \
  --env METRICS_PORT=8082 \
  --env LB_PORT=8081 \
  docker-registry.amirmuz.com/swarmguard-load-balancer:latest
```

---

### 3.3 Integration with Existing System

**No Changes Required**:
- ✅ Recovery-manager: Continues to work independently
- ✅ Prometheus: Continues to collect node-level metrics
- ✅ Grafana: Continues to display dashboards
- ✅ Web-stress: No changes needed

**Alpine Node Configuration** (Optional):
```bash
# OLD: Alpine nodes send to Docker ingress
SERVICE_URL="http://192.168.2.50:8080"

# NEW: Alpine nodes send to intelligent LB
SERVICE_URL="http://192.168.2.50:8081"
```

**Can Run Both Simultaneously**:
- Port 8080: Docker Swarm ingress (round-robin)
- Port 8081: Intelligent LB (metrics-based)
- Tests can compare both approaches!

---

## 4. Testing Strategy

### 4.1 Unit Tests
```python
# test_load_balancer.py
async def test_least_loaded_selection():
    lb = LoadBalancer()
    lb.metrics_cache = {
        'worker-1': {'cpu_percent': 80},
        'worker-2': {'cpu_percent': 45},  # Should choose this
        'worker-3': {'cpu_percent': 60}
    }
    replica = await lb.get_least_loaded_replica()
    assert replica['node'] == 'worker-2'

async def test_fallback_on_metrics_unavailable():
    lb = LoadBalancer()
    lb.metrics_cache = {}  # No metrics
    replica = await lb.get_least_loaded_replica()
    assert replica is not None  # Should use round-robin fallback
```

### 4.2 Integration Tests
```bash
# Test 1: Verify monitoring-agent API
curl http://worker-1:8082/metrics/containers | jq
# Expected: JSON with container metrics

# Test 2: Verify LB routing
for i in {1..10}; do
    curl http://192.168.2.50:8081/health
done
# Expected: Requests distributed to least-loaded replicas

# Test 3: Scenario 2 with intelligent LB
cd swarmguard/tests
./alpine_test_scenario2_v4_incremental.sh 1 1 60 90 180 10
# Monitor Grafana: Load should be more evenly distributed
```

### 4.3 Performance Tests
```bash
# Compare round-robin vs. intelligent LB

# Test A: Round-robin (port 8080)
SERVICE_URL="http://192.168.2.50:8080" ./tests/alpine_test_scenario2_v4_incremental.sh 1 1 60 90 180 10

# Test B: Intelligent LB (port 8081)
SERVICE_URL="http://192.168.2.50:8081" ./tests/alpine_test_scenario2_v4_incremental.sh 1 1 60 90 180 10

# Compare:
# - Max CPU across replicas (should be lower with intelligent LB)
# - Load distribution variance (should be lower with intelligent LB)
# - Response times (should be similar or better)
```

---

## 5. Metrics & Observability

### 5.1 Load Balancer Metrics
Add `/metrics` endpoint to LB:

```
GET http://192.168.2.50:8081/metrics

{
  "total_requests": 12543,
  "requests_per_second": 45.2,
  "routing_decisions": {
    "worker-1": 3200,
    "worker-2": 5100,  # More requests to least-loaded
    "worker-3": 4243
  },
  "avg_routing_time_ms": 2.3,
  "cache_hit_rate": 0.98
}
```

### 5.2 Grafana Dashboard (NEW)
Create "Intelligent Load Balancer" dashboard:
- Panel 1: Requests per replica (bar chart)
- Panel 2: Routing decision time (line chart)
- Panel 3: Replica load distribution (heatmap)
- Panel 4: Comparison: Round-robin vs. Intelligent (side-by-side)

---

## 6. File Structure

```
swarmguard/
├── monitoring-agent/
│   ├── agent.py                    # MODIFIED: Add API server initialization
│   ├── api_server.py               # NEW: HTTP API for metrics
│   ├── metrics_collector.py        # NO CHANGE
│   ├── Dockerfile                  # MODIFIED: Expose port 8082
│   └── requirements.txt            # MODIFIED: Add aiohttp
│
├── load-balancer/                  # NEW DIRECTORY
│   ├── lb.py                       # NEW: Main load balancer logic
│   ├── Dockerfile                  # NEW: LB container image
│   ├── requirements.txt            # NEW: aiohttp, docker, requests
│   └── config.py                   # NEW: Configuration management
│
├── tests/
│   ├── deploy_load_balancer.sh     # NEW: Deploy LB service
│   ├── test_load_balancer.py       # NEW: Unit tests for LB
│   └── compare_lb_algorithms.sh    # NEW: Compare round-robin vs intelligent
│
└── PRD_INTELLIGENT_LOAD_BALANCER.md  # THIS FILE
```

---

## 7. Implementation Checklist

### Phase 1: Monitoring-Agent API (1 hour)
- [ ] Create `api_server.py` with `/metrics/containers` endpoint
- [ ] Modify `agent.py` to start API server
- [ ] Add `aiohttp` to requirements.txt
- [ ] Update Dockerfile to expose port 8082
- [ ] Build and test locally
- [ ] Deploy to one worker node and test: `curl http://worker-1:8082/metrics/containers`

### Phase 2: Load Balancer Core (1.5 hours)
- [ ] Create `load-balancer/` directory structure
- [ ] Implement `lb.py` with:
  - [ ] Metrics fetching from monitoring-agents
  - [ ] Least-loaded replica selection
  - [ ] HTTP request proxying
  - [ ] Fallback to round-robin
- [ ] Create `Dockerfile` for load balancer
- [ ] Create `requirements.txt`
- [ ] Build and test locally with mock monitoring-agents

### Phase 3: Deployment (1 hour)
- [ ] Create `deploy_load_balancer.sh` script
- [ ] Build and push LB image to registry
- [ ] Deploy LB service to master node
- [ ] Verify LB is reachable: `curl http://192.168.2.50:8081/health`
- [ ] Test routing: Send 10 requests, verify they go to least-loaded replica

### Phase 4: Integration Testing (30 mins)
- [ ] Update Alpine test scripts to support both ports (8080 and 8081)
- [ ] Run scenario 2 with round-robin (port 8080)
- [ ] Run scenario 2 with intelligent LB (port 8081)
- [ ] Compare results in Grafana
- [ ] Create comparison script: `compare_lb_algorithms.sh`

### Phase 5: Documentation (30 mins)
- [ ] Update main README.md with LB architecture diagram
- [ ] Add usage examples
- [ ] Document configuration options
- [ ] Add troubleshooting guide

---

## 8. Configuration Options

### Environment Variables (Load Balancer)
```bash
# === Core Configuration ===
# Worker nodes to query (comma-separated)
WORKER_NODES="worker-1,worker-2,worker-3"

# Load balancer listening port
LB_PORT=8081

# Target service name to load balance
TARGET_SERVICE="web-stress"

# === Algorithm Selection ===
# Load balancing algorithm: lease, metrics, hybrid, round-robin
LB_ALGORITHM="lease"

# === Lease-Based Algorithm Configuration ===
# Lease duration in seconds (how long a request "reserves" a replica)
LEASE_DURATION=30

# Lease cleanup interval in seconds (remove expired leases)
LEASE_CLEANUP_INTERVAL=1

# === Metrics-Based Algorithm Configuration ===
# Port where monitoring-agents expose metrics
METRICS_PORT=8082

# Metrics cache TTL (seconds)
CACHE_TTL=1

# Load calculation weights (for metrics and hybrid algorithms)
CPU_WEIGHT=0.5
MEMORY_WEIGHT=0.3
NETWORK_WEIGHT=0.2

# === Hybrid Algorithm Configuration ===
# Weight for active lease count in hybrid score calculation
LEASE_COUNT_WEIGHT=10.0

# === Health & Fallback ===
# Health check interval (seconds)
HEALTH_CHECK_INTERVAL=5

# Fallback to round-robin if primary algorithm fails
FALLBACK_ENABLED=true

# === Logging & Debugging ===
# Enable detailed routing decision logging
DEBUG_ROUTING=false

# Log every Nth request (to avoid log spam)
LOG_EVERY_N_REQUESTS=100
```

### Environment Variables (Monitoring-Agent)
```bash
# NEW: API server port
API_PORT=8082

# NEW: Enable/disable API server
API_ENABLED=true
```

---

## 9. Risks & Mitigation

### Risk 1: Single Point of Failure
**Risk**: Load balancer runs as single replica on master
**Impact**: If LB crashes, no traffic routing
**Mitigation**:
- Add health monitoring
- Docker Swarm auto-restarts unhealthy containers
- Can fall back to port 8080 (Docker ingress)

### Risk 2: Metrics Lag
**Risk**: 1-second cache means routing decisions use slightly stale data
**Impact**: May route to replica that just became busy
**Mitigation**:
- 1-second lag is acceptable for this use case
- Can reduce cache TTL if needed (at cost of more queries)

### Risk 3: Network Overhead
**Risk**: LB queries 3 monitoring-agents every second = extra network calls
**Impact**: Minimal (<1KB per query × 3 × 1/sec = 3KB/s)
**Mitigation**: Already negligible, can batch queries if needed

### Risk 4: Complexity
**Risk**: Adds another component to maintain
**Impact**: More moving parts in the system
**Mitigation**:
- Well-documented
- Can be disabled (fall back to port 8080)
- Clear separation from existing components

---

## 10. Success Criteria

### Must Have
- ✅ Load balancer successfully queries monitoring-agents
- ✅ Routes requests to least-loaded replica (verified in logs)
- ✅ Handles replica failures gracefully (fallback to healthy replicas)
- ✅ Performance: Routing decision < 5ms
- ✅ Load distribution: Variance < 15% across replicas

### Nice to Have
- ✅ Grafana dashboard showing LB metrics
- ✅ Comparison tests showing improvement over round-robin
- ✅ Documentation with architecture diagrams
- ✅ Configurable routing algorithm (not just CPU-based)

---

## 11. Future Enhancements (Out of Scope)

### v2.0 Features (Not in Initial Release)
- **Weighted load balancing**: Admin can set replica weights
- **Geographic routing**: Route based on client location
- **Session affinity**: Sticky sessions for stateful apps
- **Circuit breaker**: Temporarily remove failing replicas
- **Rate limiting**: Per-replica request limits
- **Dynamic discovery**: Auto-detect new replicas (no manual config)
- **Multiple services**: Load balance multiple services, not just web-stress

---

## 12. Timeline & Effort

| Phase | Task | Time | Total |
|-------|------|------|-------|
| 1 | Monitoring-Agent API | 1h | 1h |
| 2 | Load Balancer Core Logic | 1.5h | 2.5h |
| 3 | Deployment & Docker | 1h | 3.5h |
| 4 | Integration Testing | 30m | 4h |

**Total Estimated Effort**: 4 hours (can be done in one focused session)

---

## 13. Decision: Go / No-Go

### Reasons to Implement
- ✅ **FYP value**: Shows advanced understanding of distributed systems
- ✅ **Enterprise architecture**: Demonstrates proper separation of concerns
- ✅ **Reuses existing infrastructure**: No wasted resources (uses monitoring-agent)
- ✅ **Quick to build**: Only 4 hours of work
- ✅ **Can compare**: Run both LB algorithms side-by-side

### Reasons to Skip
- ⚠️ **Not critical**: Round-robin works fine for current tests
- ⚠️ **Scope creep**: FYP focus is recovery/scaling, not load balancing
- ⚠️ **Time constraint**: 4 hours could be spent on other features
- ⚠️ **Complexity**: Adds another component to maintain

### Recommendation
**DEFER until core system is fully tested and validated.**

Current priority:
1. ✅ Test Scenario 1 & 2 thoroughly with current setup
2. ✅ Validate recovery-manager scaling/migration
3. ✅ Document and finalize thesis results
4. **THEN** consider adding intelligent LB if time permits

---

## 14. Contact & Questions

**Implementation Lead**: Claude (AI Assistant)
**Project Owner**: Amir (FYP Student)
**Review Status**: Pending - waiting for core system validation

**Questions?**
- How does this integrate with existing recovery-manager? → No changes needed, they work independently
- Will this break existing tests? → No, runs on different port (8081), can run both simultaneously
- Can we A/B test both algorithms? → Yes! That's a key benefit

---

**Document Version**: 1.0
**Last Updated**: 2025-12-17
**Status**: Ready for implementation when needed
