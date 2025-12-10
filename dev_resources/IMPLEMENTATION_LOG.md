# SwarmGuard Implementation Log

**Date Started:** December 10, 2025
**Current Status:** In Progress - Scenario 1 Testing
**Last Updated:** December 10, 2025 14:15 UTC

---

## Objective

Implement zero-downtime proactive recovery for Docker Swarm with two scenarios:
1. **Scenario 1 (Migration):** CPU/memory high, network low → Migrate container to different node (0 downtime)
2. **Scenario 2 (Scaling):** CPU/memory/network all high → Scale up/down dynamically (0 downtime)

**Target MTTR:** < 10 seconds (better than Docker's reactive ~10-15s)

---

## Implementation Attempts

### Attempt 1: Docker SDK service.update() with Constraints
**Approach:** Use `service.update()` to add placement constraints excluding problem node
**Result:** FAILED
**Error:** `update() got unexpected keyword arguments 'EndpointSpec', 'Labels'...`
**Issue:** Docker Python SDK doesn't accept full spec dict in update()
**Lesson:** Cannot update constraints via Python SDK reliably

---

### Attempt 2: Docker CLI via Subprocess
**Approach:** Install Docker CLI in recovery-manager container, use subprocess
**Result:** FAILED
**Error:** `/bin/sh: 1: docker: not found`
**Fix Attempted:** Added Docker CLI to Dockerfile (173MB layer)
**New Issue:** Push took hours, user got stuck
**Lesson:** Docker CLI approach too heavy and slow

---

### Attempt 3: Scale Up + Scale Down (Rely on Docker Scheduler)
**Approach:** Scale 1→2, let Docker place on different node, then scale 2→1
**Result:** FAILED
**Issue:** Docker's scale-down removes **oldest** tasks first, keeping **newest** task (on problem node)
**Expected:** Task migrates from worker-3 to worker-4
**Actual:** After scale 1→2→1, container back on worker-3
**Lesson:** Cannot control which specific task Docker removes during scale-down

---

### Attempt 4: Task-Level Deletion via requests-unixsocket
**Approach:** Use `DELETE /tasks/{id}` API via requests-unixsocket library
**Result:** FAILED
**Error:** `Invalid URL 'http+unix:///var/run/docker.sock/tasks/...'`
**Issue:** URL encoding wrong for unix socket
**Fix Attempted:** Used `urllib.parse.quote()` to encode socket path
**New Error:** `Not supported URL scheme http+unix`
**Lesson:** requests-unixsocket doesn't work as expected with Docker API

---

### Attempt 5: Docker SDK Low-Level API (remove_task)
**Approach:** Use `self.client.api.remove_task(task_id)` from Docker SDK
**Result:** IN PROGRESS - Currently testing
**Code:** Line 152 in docker_controller.py
**Status:** Rebuilt recovery-manager, deployed, testing now

---

### Attempt 6: Increase Wait Timeout for Health Checks
**Issue:** Scale-up times out after 15s, but health check takes ~20s to pass
**Evidence:** Task shows "Ready" state for 15+ seconds before becoming "Running"
**Fix:** Increased wait_timeout from 15s to 30s (line 57 in docker_controller.py)
**Status:** ✅ FIXED - Timeout increased successfully

---

### Attempt 7: Docker Swarm Rolling Update with Constraints
**Approach:** Use `service.update()` with task_template and update_config
**Implementation:** Lines 19-167 in docker_controller.py

**Initial Error:** `update() got an unexpected keyword argument 'update_order'`
**Root Cause:** Docker Python SDK doesn't accept `update_order`, `constraints`, or `rollback_config` as direct kwargs

**Fixed Strategy:**
1. Add placement constraint: `node.hostname != {from_node}`
2. Update TaskTemplate with new placement constraints
3. Pass `task_template` and `update_config` to `service.update()`
4. UpdateConfig with `Order: 'start-first'` ensures zero downtime
5. `force_update=True` forces task recreation
6. Wait for update to complete (max 30s)
7. Verify task is on different node

**Key Parameters:**
```python
service.update(
    task_template=task_template,  # Contains Placement.Constraints
    update_config={
        'Parallelism': 1,
        'FailureAction': 'pause',
        'Monitor': 5000000000,
        'MaxFailureRatio': 0.0,
        'Order': 'start-first'  # Zero downtime
    },
    force_update=True
)
```

**Expected Result:**
- Task migrates from node A to node B
- Zero downtime (new task starts before old one stops)
- MTTR < 10 seconds
- Constraint ensures task doesn't return to problem node

**Status:** 🔄 FIXED API CALL - Ready to rebuild and test

**Code Reference:** [docker_controller.py:53-89](../swarmguard/recovery-manager/docker_controller.py#L53-L89)

---

## Current Blockers

### Blocker 1: Scale-Down Removes Wrong Task → SOLVED with Rolling Update
**Problem:** After scale 1→2→1, Docker keeps the OLDEST task, not the NEWEST one
**Evidence:**
- First migration: worker-3 → worker-1 ✅ SUCCESS (23.2s MTTR)
- Second migration: worker-1 → worker-3 ❌ FAILED (task stays on worker-1)

**Root Cause:** Task `lfl9wpssh7m3...` on worker-1 is the oldest, so `service.scale(1)` always keeps it and removes newer tasks on worker-3.

**Docker Behavior:**
- `service.scale(2)`: Creates new task (e.g., on worker-3)
- `service.scale(1)`: Removes NEWEST task (worker-3), keeps OLDEST (worker-1)

**Solution (Attempt 7):** Use Docker Swarm's rolling update mechanism instead of scale up/down:
- `service.update(force_update=True, constraints=[...], update_order='start-first')`
- This forces Docker to recreate the task while following the new constraint
- start-first ensures new task starts before old one stops (zero downtime)
- Constraint `node.hostname != {from_node}` prevents placement on problem node

**Status:** 🔄 Code implemented, ready for testing

**Health Check Config:**
```yaml
health-cmd: 'curl -f http://localhost:8080/health || exit 1'
health-interval: 5s
health-timeout: 3s
```

**Timeline:**
- T+0s: service.scale(2) called
- T+2-6s: Container starts, FastAPI initializing
- T+6-20s: Health checks running every 5s
- T+20s: Task becomes "Running" (healthy)

---

## Code Changes Summary

### Files Modified

1. **[recovery-manager/docker_controller.py](../swarmguard/recovery-manager/docker_controller.py)**
   - Line 57: Increased wait_timeout from 15s to 30s
   - Line 152: Changed to `self.client.api.remove_task(old_task_id)`
   - Removed requests-unixsocket dependency

2. **[recovery-manager/requirements.txt](../swarmguard/recovery-manager/requirements.txt)**
   - Removed `requests-unixsocket==0.3.0`
   - Using only Docker SDK built-in methods

3. **[monitoring-agent/metrics_collector.py](../swarmguard/monitoring-agent/metrics_collector.py)**
   - Line 126: Fixed CPU normalization to 0-100%
   - Previously allowed up to 800% (8 cores × 100%)

4. **[web-stress/stress/cpu_stress.py](../swarmguard/web-stress/stress/cpu_stress.py)**
   - Lines 54-62: Added gradual ramp-up with delays
   - Processes start one-by-one with `delay_per_process` intervals

5. **[tests/deploy_web_stress.sh](../swarmguard/tests/deploy_web_stress.sh)**
   - Line 16: Added `--constraint 'node.hostname!=master'`
   - Prevents master node from running application containers

---

## Testing Status

### Scenario 1: Migration (CPU/Memory High, Network Low)
**Status:** ⚠️ IN PROGRESS
**Test Command:**
```bash
curl "http://192.168.2.53:8080/stress/cpu?target=80&duration=180&ramp=20"
```

**Expected Behavior:**
1. Container on worker-3 hits 75% CPU threshold
2. Recovery manager detects Scenario 1 (high CPU, low network)
3. Scale from 1→2 replicas (new task on worker-4 or worker-1)
4. Wait for new task to become healthy (~20s)
5. Remove old task on worker-3 via `remove_task()` API
6. Final state: 1 replica on different node (worker-4 or worker-1)
7. MTTR < 10 seconds

**Current Issue:** Timeout at step 4 (need 30s wait, had 15s)

---

### Scenario 2: Horizontal Scaling (All Metrics High)
**Status:** ❌ NOT STARTED
**Requirements:**
- Scale up one replica at a time when all metrics high
- Scale down when `all_container_usage < threshold * (replicas - 1)`
- Maintain zero downtime during scale operations

---

## Next Steps

1. ✅ **Fix wait timeout** - Changed to 30s
2. ✅ **Implement rolling update approach** - service.update() with constraints
3. 🔄 **Rebuild recovery-manager** - User to execute rebuild commands
4. 🔄 **Test Scenario 1 migration** - Verify task migrates and STAYS on different node
5. ⏳ **Measure MTTR** - Target < 10 seconds
6. ⏳ **Implement Scenario 2** - Horizontal scaling logic (scale up/down one at a time)
7. ⏳ **Full system test** - Both scenarios with load testing

---

## Commands for User to Run

### Rebuild Recovery Manager
```bash
cd /Users/amirmuz/code/claude_code/fyp_everything/swarmguard/recovery-manager
docker build -t docker-registry.amirmuz.com/swarmguard-recovery:latest .
docker push docker-registry.amirmuz.com/swarmguard-recovery:latest
```

### Deploy Updated Recovery Manager
```bash
curl "http://192.168.2.53:8080/stress/stop"  # Stop current stress
ssh master "docker service scale web-stress=1"  # Reset to 1 replica
sleep 10
ssh master "docker service update --force recovery-manager"  # Deploy new version
sleep 5
ssh master "docker service logs recovery-manager --tail 10"  # Verify
```

### Test Scenario 1
```bash
# Check which node web-stress is on
ssh master "docker service ps web-stress --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}'"

# Trigger stress (adjust IP to match node)
curl "http://192.168.2.53:8080/stress/cpu?target=80&duration=180&ramp=20"

# Monitor migration
watch -n 2 "ssh master 'docker service ps web-stress --format \"table {{.Name}}\t{{.Node}}\t{{.CurrentState}}\"'"

# Check logs for MTTR
ssh master "docker service logs recovery-manager --tail 50 | grep -E 'Zero-downtime|duration|Step|Final|Verified'"
```

---

## Lessons Learned

1. **Docker SDK Limitations:** Cannot reliably update service constraints via Python SDK's service.update() kwargs
2. **Scale-Down Behavior:** Docker removes newest tasks first, keeps oldest - not controllable via scale()
3. **Health Check Timing:** FastAPI containers take 15-20s to become healthy, must account for this in wait timeouts
4. **Task Deletion:** Docker Swarm doesn't support deleting individual tasks within a service
5. **Timeout Values:** Always add buffer for health checks (30s safer than 15s)
6. **Rolling Updates:** The proper Docker Swarm way for zero-downtime migration is `service.update(force_update=True)` with constraints
7. **Constraint Application:** Placement constraints only apply during task creation/recreation, not to existing tasks
8. **Update Order:** `update_order='start-first'` creates new task before stopping old one (critical for zero downtime)

---

## Performance Targets

| Metric | Target | Current Status |
|--------|--------|----------------|
| Alert Latency | < 1 second | ⚠️ 16s (needs optimization) |
| Migration MTTR | < 10 seconds | 🔄 Testing |
| Zero Downtime | 0 seconds | 🔄 Testing |
| CPU Overhead | < 5% | ✅ Minimal |
| Network Overhead | < 1 Mbps | ✅ < 0.5 Mbps |

---

## References

- [PRD.md](PRD.md) - Original requirements
- [docker_controller.py](../swarmguard/recovery-manager/docker_controller.py) - Migration logic
- [Docker Swarm API Docs](https://docs.docker.com/engine/api/v1.43/)
