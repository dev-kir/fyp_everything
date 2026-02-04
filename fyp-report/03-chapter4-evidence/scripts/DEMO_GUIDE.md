# SwarmGuard Presentation Demo Guide

## Pre-Demo Setup

### On Lab Mac, open 3-4 terminal windows and arrange them:
```
┌─────────────────────────────────┬─────────────────────────────────┐
│ TERMINAL 1: Demo Runner         │ TERMINAL 2: Service Status      │
│ (run demo scripts here)         │ (viewer)                        │
├─────────────────────────────────┼─────────────────────────────────┤
│ TERMINAL 3: Health Check        │ TERMINAL 4: Logs (Scenario 1&2) │
│ (viewer)                        │ (viewer)                        │
└─────────────────────────────────┴─────────────────────────────────┘
```

### Navigate to scripts folder:
```bash
cd /Users/amirmuz/fyp_everything/fyp-report/03-chapter4-evidence/scripts
chmod +x *.sh
```

---

## DEMO 1: BASELINE (Docker Swarm Reactive Recovery)

### What You're Showing
- Docker Swarm's **default behavior** (reactive only)
- Container **CRASHES** before recovery
- **DOWNTIME** visible in health check

### Terminal Setup

| Terminal | Command | What to Watch |
|----------|---------|---------------|
| T1 | `./demo_baseline.sh` | Main demo runner |
| T2 | `./demo_viewer_service.sh` | Container crashes → restarts |
| T3 | `./demo_viewer_health.sh` | Multiple "DOWN" = downtime |
| T4 | (not needed) | - |

### Step-by-Step

1. **T2**: Start service viewer
   ```bash
   ./demo_viewer_service.sh
   ```

2. **T3**: Start health viewer
   ```bash
   ./demo_viewer_health.sh
   ```

3. **T1**: Run baseline demo
   ```bash
   ./demo_baseline.sh
   ```

4. **Narrate while watching**:
   - "SwarmGuard is DISABLED"
   - "Stress test is ramping up..."
   - "Watch T2 - container will CRASH" (look for error messages)
   - "Watch T3 - see the DOWN status? That's DOWNTIME"
   - "Docker Swarm only restarts AFTER the crash"

5. **Key observation to highlight**:
   - T3 shows many "DOWN" entries = **user-visible downtime**
   - T2 shows "task: non-zero exit" error = **container crashed**

### Cleanup
```bash
./demo_cleanup.sh
```

---

## DEMO 2: SCENARIO 1 (Proactive Migration)

### What You're Showing
- SwarmGuard detects **degradation BEFORE crash**
- Container **MIGRATES** to healthy node
- **MINIMAL/NO DOWNTIME**

### Terminal Setup

| Terminal | Command | What to Watch |
|----------|---------|---------------|
| T1 | `./demo_scenario1.sh` | Main demo runner |
| T2 | `./demo_viewer_service.sh` | Node changes (migration!) |
| T3 | `./demo_viewer_health.sh` | Continuous 200s (no downtime) |
| T4 | `./demo_viewer_logs.sh` | "proactive migration" decision |

### Step-by-Step

1. **T2**: Start service viewer
   ```bash
   ./demo_viewer_service.sh
   ```

2. **T3**: Start health viewer
   ```bash
   ./demo_viewer_health.sh
   ```

3. **T4**: Start logs viewer (wait for SwarmGuard to enable)
   ```bash
   ./demo_viewer_logs.sh
   ```

4. **T1**: Run scenario 1 demo
   ```bash
   ./demo_scenario1.sh
   ```

5. **Narrate while watching**:
   - "SwarmGuard is now ENABLED"
   - "Same stress test as baseline..."
   - "Watch T4 - SwarmGuard detecting high CPU/memory"
   - "Watch T2 - see the Node column? It's CHANGING!"
   - "Watch T3 - still showing 200! No downtime!"
   - "Container migrated BEFORE it crashed"

6. **Key observation to highlight**:
   - T2 shows node change: `worker1` → `worker2` = **migration**
   - T3 shows continuous 200s = **NO DOWNTIME**
   - T4 shows "proactive migration" in logs

### Compare with Baseline
- "In baseline, we saw ~10-30 seconds of DOWN"
- "In scenario 1, we saw 0 or near-0 DOWN"
- "That's the difference proactive migration makes!"

### Cleanup
```bash
./demo_cleanup.sh
```

---

## DEMO 3: SCENARIO 2 (Horizontal Autoscaling)

### What You're Showing
- SwarmGuard detects **high traffic load**
- **Auto-scales** replicas 1 → 2
- **Load balances** traffic across replicas
- **Auto-scales down** when load decreases

### Terminal Setup

| Terminal | Command | What to Watch |
|----------|---------|---------------|
| T1 | `./demo_scenario2.sh` | Main demo runner |
| T2 | `./demo_viewer_replicas.sh` | 1/1 → 2/2 (scale up!) |
| T3 | `./demo_viewer_service.sh` | 2 replicas on different nodes |
| T4 | `./demo_viewer_logs.sh` | "scaling up" decision |

### Step-by-Step

1. **T2**: Start replicas viewer
   ```bash
   ./demo_viewer_replicas.sh
   ```

2. **T3**: Start service viewer
   ```bash
   ./demo_viewer_service.sh
   ```

3. **T4**: Start logs viewer
   ```bash
   ./demo_viewer_logs.sh
   ```

4. **T1**: Run scenario 2 demo
   ```bash
   ./demo_scenario2.sh
   ```

5. **Narrate while watching**:
   - "Starting with 1 replica"
   - "Simulating 60 users hitting the service..."
   - "Watch T2 - replica count is 1/1"
   - "SwarmGuard detecting high load..."
   - "Watch T2 - it's changing to 2/2! Auto-scaled!"
   - "Watch T3 - two replicas on different nodes"
   - "Load is distributed across both replicas"
   - "Now stopping load..."
   - "Watch T2 - scaling back down to 1/1"

6. **Key observation to highlight**:
   - T2 shows `1/1 → 2/2 → 1/1` = **auto-scaling**
   - T3 shows replicas on different nodes = **distribution**
   - T4 shows "scaling up/down" decisions

### Cleanup
```bash
./demo_cleanup.sh
```

---

## Quick Reference - All Commands

### Viewers (run in separate terminals)
```bash
./demo_viewer_service.sh   # Service status + node placement
./demo_viewer_health.sh    # Health check (downtime monitor)
./demo_viewer_logs.sh      # Recovery manager logs
./demo_viewer_replicas.sh  # Replica count (for scenario 2)
./demo_viewer_lb.sh        # Load balancer distribution
```

### Demo Scripts
```bash
./demo_baseline.sh    # Baseline - SwarmGuard OFF
./demo_scenario1.sh   # Scenario 1 - Proactive Migration
./demo_scenario2.sh   # Scenario 2 - Horizontal Autoscaling
./demo_cleanup.sh     # Reset between demos
```

### Manual SwarmGuard Control
```bash
# Disable (for baseline)
docker service scale recovery-manager=0
docker service scale monitoring-agent-master=0
docker service scale monitoring-agent-worker1=0
docker service scale monitoring-agent-worker2=0
docker service scale monitoring-agent-worker3=0
docker service scale monitoring-agent-worker4=0

# Enable (for scenarios)
docker service scale recovery-manager=1
docker service scale monitoring-agent-master=1
docker service scale monitoring-agent-worker1=1
docker service scale monitoring-agent-worker2=1
docker service scale monitoring-agent-worker3=1
docker service scale monitoring-agent-worker4=1
```

---

## Timing Estimates

| Demo | Duration | Key Moment |
|------|----------|------------|
| Baseline | ~3-4 min | Crash at ~1-2 min mark |
| Scenario 1 | ~3-4 min | Migration at ~1-2 min mark |
| Scenario 2 | ~5-6 min | Scale-up at ~2-3 min mark |
| Cleanup | ~10 sec | - |

**Total presentation time**: ~15-20 minutes with explanations

---

## Troubleshooting

### "No logs from recovery-manager"
SwarmGuard is disabled. Run:
```bash
docker service scale recovery-manager=1
```

### "Service not found"
web-stress not deployed. The demo scripts auto-deploy it.

### "Viewers not updating"
Check SSH connection to master:
```bash
ssh master "docker service ls"
```

### "Scale-up not happening in Scenario 2"
May need to adjust thresholds or wait longer. Check logs:
```bash
docker service logs recovery-manager --tail 50
```
