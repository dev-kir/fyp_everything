# SwarmGuard FYP Defense Playbook
# Complete guide: Setup, Demo, Presentation, Q&A

---

## PART 1: FIX CLUSTER (Run Before Defense Day)

The monitoring agents and recovery-manager are at 0/0 replicas.
Now that Cloudflare tunnel is fixed, force-update them to pull fresh images.

```bash
# Step 1: Force-update recovery-manager (pulls fresh image)
ssh master "docker service update --force recovery-manager"

# Step 2: Force-update ALL monitoring agents
ssh master "docker service update --force monitoring-agent-master"
ssh master "docker service update --force monitoring-agent-worker1"
ssh master "docker service update --force monitoring-agent-worker2"
ssh master "docker service update --force monitoring-agent-worker3"
ssh master "docker service update --force monitoring-agent-worker4"

# Step 3: Verify everything is 1/1
ssh master "docker service ls"
# Expected: ALL services should show 1/1 (except web-stress which may be 1/1 already)

# Step 4: Verify health endpoints
curl -s http://192.168.2.50:5000/health    # recovery-manager
curl -s http://192.168.2.50:8080/health    # web-stress
curl -s http://192.168.2.50:8081/health    # load-balancer

# Step 5: Check InfluxDB is receiving metrics (Raspberry Pi)
curl -s "http://192.168.2.61:8086/api/v2/query?org=swarmguard" \
  -H "Authorization: Token iNCff-dYnCY8oiO_mDIn3tMIEdl5D1Z4_KFE2vwTMFtQoTqGh2SbL5msNB30DIOKE2wwj-maBW5lTZVJ3f9ONA==" \
  -H "Content-Type: application/vnd.flux" \
  -d 'from(bucket: "metrics") |> range(start: -1m) |> limit(n: 5)'

# Step 6: Open Grafana and verify dashboards show data
# http://192.168.2.61:3000
```

### If services still show 0/0 after force-update:
```bash
# Check service logs for errors
ssh master "docker service logs recovery-manager --tail 20"
ssh master "docker service logs monitoring-agent-worker1 --tail 20"

# If image pull fails, try pulling manually on master first
ssh master "docker pull docker-registry.amirmuz.com/swarmguard-manager:latest"
ssh master "docker pull docker-registry.amirmuz.com/swarmguard-agent:latest"
```

### Pre-defense checklist:
```
[ ] All 5 monitoring agents at 1/1
[ ] Recovery-manager at 1/1
[ ] Web-stress at 1/1
[ ] Intelligent-lb at 1/1
[ ] Grafana showing live metrics at http://192.168.2.61:3000
[ ] InfluxDB receiving data
[ ] web-stress /health returns 200
[ ] recovery-manager /health returns 200
```

---

## PART 2: PRESENTATION STRUCTURE (15-20 min)

### Slide 1: Title
- "SwarmGuard: Rule-Based Proactive Recovery Mechanism for Docker Swarm Containerized Applications"
- Your name, supervisor, date

### Slide 2: Problem Statement (2 min)
- Container failures in production cause downtime
- Docker Swarm default: Only REACTIVE recovery (restart after crash)
- Manual intervention: Average 23.1 seconds MTTR (from your baseline test)
- No proactive detection = no prevention
- KEY STAT: "Our baseline testing showed 23.1s mean time to recovery with Docker Swarm's native mechanism"

### Slide 3: Objectives (1 min)
1. Design a rule-based proactive monitoring and recovery system
2. Implement two recovery scenarios (migration + auto-scaling)
3. Achieve near-zero downtime during recovery actions
4. Evaluate with quantitative metrics (MTTR, downtime, success rate)

### Slide 4: Architecture Overview (3 min)
Show the 4-component architecture:

```
+------------------+      Alerts (HTTP)      +-------------------+
| Monitoring Agent |  ------------------>    | Recovery Manager  |
| (per node)       |                         | (master node)     |
+------------------+                         +-------------------+
       |                                            |
       | Metrics (HTTP POST)                        | Docker API
       v                                            v
+------------------+                         +-------------------+
| InfluxDB         |                         | Docker Swarm      |
| (Raspberry Pi)   |                         | (rolling update/  |
+------------------+                         |  scale commands)  |
                                             +-------------------+
```

- Monitoring Agent: Deployed on each node, polls CPU/MEM/NET every 5 seconds
- Recovery Manager: Central decision engine on master node
- InfluxDB + Grafana: Visualization and historical metrics
- Docker Swarm API: Executes recovery actions

### Slide 5: Decision Logic - Two Scenarios (3 min)
```
         CPU > 75% OR Memory > 80%
                    |
            +-------+-------+
            |               |
    Network < 35%     Network >= 65%
            |               |
     SCENARIO 1       SCENARIO 2
     Migration        Auto-scaling
```

- Scenario 1: High compute, low network = node overload, migrate container
- Scenario 2: High compute, high network = genuine demand, add replicas
- WHY network is the discriminator: High network = real user traffic = need more capacity

### Slide 6: Safety Mechanisms (2 min)
- Breach counting: 2 consecutive breaches before action (prevents false positives)
- Cooldown timers: 60s migration, 60s scale-up, 180s scale-down
- 3:1 asymmetry: Scale-down waits 3x longer (prevents oscillation)
- Start-first rolling update: New container healthy before old stops (zero downtime)

### Slide 7: Infrastructure (1 min)
- 5 Intel Core i5 servers (master + 4 workers)
- Raspberry Pi for InfluxDB/Grafana monitoring
- Docker Swarm overlay network
- Private Docker registry (docker-registry.amirmuz.com)

### Slide 8-10: Results (3 min)
| Metric | Baseline | SwarmGuard | Improvement |
|--------|----------|------------|-------------|
| MTTR | 23.10s | 0.60s | 97.4% reduction |
| Zero downtime | N/A | 80% of migrations | - |
| Auto-scale success | N/A | 100% (10/10) | - |
| Alert latency | N/A | 7-9ms | - |
| CPU overhead | N/A | <5% | Minimal |

### Slide 11: Live Demo (see Part 3 below)

### Slide 12: Conclusion
- Rule-based approach: Simple, deterministic, low overhead
- Achieved sub-second MTTR (97.4% improvement)
- Zero downtime possible with start-first strategy
- Future: Predictive scaling, CRIU integration, multi-cluster

---

## PART 3: LIVE DEMO SCRIPT (The Most Important Part)

### Before starting demo:
```bash
# Ensure everything is running
ssh master "docker service ls"
# Open Grafana in browser: http://192.168.2.61:3000
```

### Demo 1: Show Architecture Running (1 min)
```bash
# Show all SwarmGuard services
ssh master "docker service ls"

# Show cluster nodes
ssh master "docker node ls"

# Show web-stress running on a worker node
ssh master "docker service ps web-stress --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}'"

# Show recovery-manager health
curl -s http://192.168.2.50:5000/health | python3 -m json.tool

# Show web-stress health
curl -s http://192.168.2.50:8080/health | python3 -m json.tool

# Show real-time metrics
curl -s http://192.168.2.50:8080/metrics | python3 -m json.tool
```

**SAY:** "Here we can see SwarmGuard running on our 5-node cluster. Web-stress is our test application running on [node]. All monitoring agents are collecting metrics every 5 seconds."

### Demo 2: Scenario 1 - Proactive Migration (3 min)
```bash
# Note which node web-stress is on
ssh master "docker service ps web-stress --format '{{.Node}}' | head -1"
# Example output: worker-2

# Trigger Scenario 1: HIGH CPU + HIGH MEM + LOW NETWORK
curl -s "http://192.168.2.50:8080/stress/combined?cpu=90&memory=900&network=5&duration=180&ramp=10"

# SAY: "I'm triggering high CPU (90%) and high memory (900MB) with LOW network (5Mbps).
#       Low network means this is a node problem, not user demand.
#       SwarmGuard should MIGRATE the container to a healthier node."

# Wait ~30-40 seconds, then check
# Show Grafana: CPU spike visible in dashboard

# After ~30s, check if migration happened
ssh master "docker service ps web-stress --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}'"
# Expected: Container moved from worker-2 to worker-3 (different node)

# SAY: "The container has been migrated from [old-node] to [new-node].
#       This happened in under 1 second with zero downtime because we use
#       start-first rolling update -- the new container was healthy before
#       the old one stopped."
```

### Demo 3: Scenario 2 - Auto-scaling (3 min)
```bash
# First, stop any ongoing stress
curl -s "http://192.168.2.50:8080/stress/stop"
sleep 5

# Verify back to 1 replica
ssh master "docker service ls --filter name=web-stress"

# Trigger Scenario 2: HIGH CPU + HIGH MEM + HIGH NETWORK
curl -s "http://192.168.2.50:8080/stress/combined?cpu=90&memory=900&network=70&duration=180&ramp=10"

# SAY: "Now I'm triggering the same CPU and memory, but with HIGH network (70Mbps).
#       High network means real user demand. SwarmGuard should ADD replicas
#       instead of migrating."

# Wait ~30-40 seconds
ssh master "docker service ls --filter name=web-stress"
# Expected: REPLICAS shows 2/2

ssh master "docker service ps web-stress --filter 'desired-state=running' --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}'"
# Expected: 2 containers on different worker nodes

# SAY: "SwarmGuard detected high demand and scaled from 1 to 2 replicas.
#       The load balancer now distributes traffic across both replicas."

# Show load balancer metrics
curl -s http://192.168.2.50:8081/metrics | python3 -m json.tool
# Shows 2 healthy replicas with request distribution

# Stop stress and wait for scale-down
curl -s "http://192.168.2.50:8080/stress/stop"

# SAY: "After the load drops, SwarmGuard will automatically scale back down
#       to 1 replica after the 180-second cooldown period."
```

### Demo 4: Show Grafana Dashboard (1 min)
- Show browser with Grafana dashboard
- Point to CPU/Memory/Network graphs
- Show the spike during stress test
- Show the migration or scaling event in the timeline

### Demo 5 (Optional): Recovery Manager Logs
```bash
# Show recovery manager decision logs
ssh master "docker service logs recovery-manager --tail 30 --no-trunc" 2>&1 | grep -E "(scenario|Migration|scale|breach|alert)"

# SAY: "Here you can see the recovery manager's decision log:
#       - Alert received at [time]
#       - Breach count: 2/2 (required 2 consecutive)
#       - Scenario 1/2 classified based on network threshold
#       - Recovery action executed"
```

---

## PART 4: KEY DEFENSE ARGUMENTS

### Why your project is valuable:

1. **Practical, working system** -- Not theoretical. Runs on real hardware, tested with real stress.

2. **97.4% MTTR improvement** -- From 23.1s to 0.6s. This is measurable, reproducible.

3. **Rule-based is the right choice** -- ML-based alternatives (cited in your literature review) require training data, add latency, and are harder to debug. Your system makes decisions in 7-9ms.

4. **Two-scenario intelligence** -- Not just restart-on-failure. Your system DISTINGUISHES between node overload (migrate) and genuine demand (scale). This is the key innovation.

5. **Zero downtime** -- 80% of migrations had zero failed health checks. Achieved through Docker Swarm's start-first update order.

6. **Low overhead** -- <5% CPU overhead means the monitoring doesn't cause the problems it's trying to detect.

### Common examiner questions and answers:

**Q: "Why not use Kubernetes instead of Docker Swarm?"**
A: Docker Swarm provides sufficient orchestration for our 5-node cluster while being simpler to deploy and manage. Kubernetes adds operational complexity (etcd, API server, controller manager, scheduler) that would obscure the actual contribution -- the rule-based recovery logic. The principles transfer to any orchestrator.

**Q: "Why not machine learning?"**
A: ML requires labeled training data of failure scenarios we don't have a priori. Our rule-based approach achieves 7-9ms decision latency -- ML inference would add 50-200ms. Rule-based decisions are deterministic, auditable, and reproducible. Literature (Rattanapoka 2023, Blinowski 2022) shows ML adds complexity without proportional benefit for container recovery.

**Q: "How do you prevent false positives?"**
A: Two mechanisms: (1) Breach counting -- requires 2 consecutive threshold violations 10 seconds apart before triggering recovery. A single transient spike is ignored. (2) Cooldown timers -- after any recovery action, the system waits 60-180 seconds before acting again, preventing oscillation.

**Q: "What happens if recovery-manager itself fails?"**
A: This is a known limitation. Recovery-manager is a single point of failure running on the master node. Docker Swarm will restart it if it crashes, but during that restart window, no recovery actions occur. Future work: implement Raft-based leader election for recovery-manager replication.

**Q: "Why is scale-down cooldown 3x longer than scale-up?"**
A: Asymmetric by design. Scaling up is urgent (users experiencing degradation). Scaling down is not urgent and carries risk -- if we scale down too soon during intermittent load, we'd need to scale back up immediately, causing oscillation. The 3:1 ratio (180s vs 60s) provides stability.

**Q: "How does the network threshold distinguish the two scenarios?"**
A: Network bandwidth indicates the TYPE of problem. Low network + high CPU = the node itself is struggling (hardware issue, noisy neighbor) -- solution is migration. High network + high CPU = real user demand generating traffic -- solution is horizontal scaling. The 35% and 65% thresholds create a dead zone (35-65%) where no action is taken, preventing ambiguous classifications.

**Q: "What if all nodes are overloaded?"**
A: For Scenario 1 (migration), the docker_controller selects the node with the lowest current load. If ALL nodes are overloaded, migration still moves to the "least bad" node. For Scenario 2 (scaling), new replicas can land on any available worker. In a truly saturated cluster, the correct solution would be adding hardware -- which is outside scope.

**Q: "Is 10 test runs enough for statistical significance?"**
A: For MTTR measurement (Scenario 1), 10 runs with consistent sub-second results (0.60s average, 0.058s standard deviation) demonstrates reliability. The low standard deviation indicates consistent behavior, not luck. For Scenario 2, 10/10 success rate (100%) is definitive for a binary outcome.

**Q: "How does this compare to existing solutions?"**
A: Docker Swarm native: Only restarts after crash (reactive), 23.1s MTTR. Kubernetes HPA: Scales based on CPU only, no migration logic. Our contribution: Proactive detection + dual-scenario classification + zero-downtime migration. No existing Swarm solution combines all three.

---

## PART 5: THINGS TO PREPARE BEFORE DEFENSE DAY

1. **Test the full demo flow** at least twice before defense day
   - Run Scenario 1, verify migration
   - Run Scenario 2, verify scale-up
   - Check Grafana shows the events
   - Time yourself -- demo should be under 5 minutes

2. **Have Grafana open** in browser before starting

3. **Have two terminal windows ready:**
   - Terminal 1: For running commands
   - Terminal 2: For monitoring (`watch -n2 'ssh master "docker service ls"'`)

4. **Backup plan if live demo fails:**
   - Have screenshots/recordings of successful test runs ready
   - Have the Grafana dashboard screenshots from your thesis
   - Have the recovery-manager logs from a successful run saved

5. **Know your numbers by heart:**
   - 23.1s baseline MTTR
   - 0.60s SwarmGuard MTTR
   - 97.4% improvement
   - 80% zero-downtime rate
   - 100% autoscale success
   - 7-9ms alert latency
   - <5% CPU overhead
   - 2 breach count before action
   - 60/60/180s cooldowns

6. **Reset cluster after each demo run:**
   ```bash
   # Stop stress
   curl -s http://192.168.2.50:8080/stress/stop

   # Scale back to 1 replica (if scaled up)
   ssh master "docker service scale web-stress=1"

   # Wait for cooldown (60s minimum)
   sleep 60

   # Verify clean state
   ssh master "docker service ls --filter name=web-stress"
   ssh master "docker service ps web-stress --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}'"
   ```
