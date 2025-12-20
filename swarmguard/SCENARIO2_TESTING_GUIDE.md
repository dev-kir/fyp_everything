# Scenario 2 Testing Guide - Smooth Gradual Resource Increase

## 🎯 Purpose
This document contains the **minimal changes** needed to enable smooth, gradual CPU/Memory/Network increase for Scenario 2 testing with clear Grafana visualization.

## ✅ What You Tested and Confirmed Working

You tested on `alpine-1` and confirmed:
```bash
for i in $(seq 1 10); do
    (
        sleep $(($i * 3))  # Stagger: user 1 at 0s, user 2 at 3s, etc.
        wget -q -O /dev/null \
            "http://192.168.2.50:8081/stress/combined?cpu=5&memory=50&network=5&duration=180&ramp=20" &
    ) &
done
```

**Result**:
- ✅ Memory gradually increased (visible in Grafana)
- ✅ Network gradually increased to ~35Mbps (visible in Grafana)
- ⚠️ CPU might not have shown up clearly (needs fix below)

---

## 🔧 Required Changes

### Change 1: Fix CPU Stress Calculation (web-stress)

**File**: `swarmguard/web-stress/stress/cpu_stress.py`

**Problem**: The CPU burn uses `_ = 2 ** 1000` which is too lightweight and might be optimized away by Python.

**Fix**: Replace lines 32-36 and 53-59:

**OLD CODE (lines 32-36)**:
```python
        # Busy loop for burn_duration seconds
        while (time.time() - cycle_start) < burn_duration:
            _ = 2 ** 1000
```

**NEW CODE**:
```python
        # Busy loop for burn_duration seconds (CPU-intensive work)
        result = 0
        while (time.time() - cycle_start) < burn_duration:
            for _ in range(10000):
                result += (_ * 0.5) ** 2  # Force actual computation
```

**OLD CODE (lines 53-59)**:
```python
            while time.time() < end_time:
                # Maximum intensity calculation
                for _ in range(100000):
                    _ = 2 ** 1000
```

**NEW CODE**:
```python
            while time.time() < end_time:
                # Maximum intensity calculation
                result = 0
                for i in range(100000):
                    result += (i * 0.5) ** 2  # Force actual computation
```

---

### Change 2: Fix CPU Stress in /stress/incremental Endpoint (web-stress)

**File**: `swarmguard/web-stress/app.py`

**Problem**: Same issue - CPU burn might be optimized away.

**Fix**: Replace lines 200-204:

**OLD CODE**:
```python
                    while time.time() - cycle_start < burn_duration:
                        _ = 2 ** 1000  # CPU-intensive calculation
```

**NEW CODE**:
```python
                    # CPU-intensive work (prevent optimization)
                    result = 0
                    while time.time() - cycle_start < burn_duration:
                        for _ in range(10000):
                            result += (_ * 0.5) ** 2  # Force actual computation
```

---

### Change 3: Add Ultimate Testing Script

**File**: `swarmguard/tests/scenario2_ultimate.sh` (NEW FILE)

**Create this file with the complete script below**:

```bash
#!/bin/bash
#######################################################################
# SwarmGuard Scenario 2 - Ultimate Test Script
#######################################################################
#
# Purpose: Demonstrate smooth, gradual resource increase that triggers
#          Scenario 2 scaling, followed by visible load distribution
#
# Based on successful testing showing /stress/combined works for all
# three resources (CPU, Memory, Network) simultaneously
#
# Usage:
#   ./scenario2_ultimate.sh [USERS_PER_ALPINE] [CPU%] [MEM_MB] [NET_MBPS] [STAGGER] [RAMP] [HOLD]
#
# Examples:
#   ./scenario2_ultimate.sh 10 5 50 5 3 20 180    # Default: smooth gradual increase
#   ./scenario2_ultimate.sh 3 50 200 1 3 60 900   # Your confirmed working config
#   ./scenario2_ultimate.sh 15 4 40 4 2 15 240    # Faster ramp, longer hold
#
# Parameters:
#   USERS_PER_ALPINE  - Number of simulated users per Alpine node (default: 10)
#   USER_CPU         - CPU% contribution per user (default: 5)
#   USER_MEMORY      - Memory MB contribution per user (default: 50)
#   USER_NETWORK     - Network Mbps contribution per user (default: 5)
#   STAGGER_DELAY    - Seconds between each user starting (default: 3)
#   RAMP_TIME        - Seconds for each user to ramp resources 0→max (default: 20)
#   HOLD_TIME        - Seconds to maintain peak load (default: 180)
#
#######################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
USERS_PER_ALPINE=${1:-10}
USER_CPU=${2:-5}
USER_MEMORY=${3:-50}
USER_NETWORK=${4:-5}
STAGGER_DELAY=${5:-3}
RAMP_TIME=${6:-20}
HOLD_TIME=${7:-180}

SERVICE_URL="http://192.168.2.50:8081"  # Intelligent LB
ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4")

# Calculate totals
TOTAL_USERS=$((${#ALPINE_NODES[@]} * USERS_PER_ALPINE))
TOTAL_CPU=$((TOTAL_USERS * USER_CPU))
TOTAL_MEMORY=$((TOTAL_USERS * USER_MEMORY))
TOTAL_NETWORK=$((TOTAL_USERS * USER_NETWORK))
RAMP_COMPLETE_TIME=$((STAGGER_DELAY * (USERS_PER_ALPINE - 1) + RAMP_TIME))

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}SwarmGuard Scenario 2 - Ultimate Test${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Alpine nodes:       ${#ALPINE_NODES[@]}"
echo "  Users per Alpine:   ${USERS_PER_ALPINE}"
echo "  Total users:        ${TOTAL_USERS}"
echo "  Stagger delay:      ${STAGGER_DELAY}s (between user starts)"
echo "  Ramp time:          ${RAMP_TIME}s (per user, 0→max)"
echo "  Hold time:          ${HOLD_TIME}s (maintain peak load)"
echo ""
echo -e "${BLUE}Per-User Resource Contribution:${NC}"
echo "  CPU:     ${USER_CPU}%"
echo "  Memory:  ${USER_MEMORY}MB"
echo "  Network: ${USER_NETWORK}Mbps"
echo ""
echo -e "${BLUE}Expected Peak Load (All Users Active):${NC}"
echo "  Total CPU:     ${TOTAL_CPU}% ${YELLOW}(Scenario 2 threshold: 75%)${NC}"
echo "  Total Memory:  ${TOTAL_MEMORY}MB ${YELLOW}(Scenario 2 threshold: 80% node memory)${NC}"
echo "  Total Network: ${TOTAL_NETWORK}Mbps ${YELLOW}(Scenario 2 threshold: 65Mbps)${NC}"
echo ""
echo -e "${BLUE}Timeline:${NC}"
echo "  T+0s:      User 1 starts on each Alpine (4 users total)"
echo "  T+${STAGGER_DELAY}s:     User 2 starts on each Alpine (8 users total)"
echo "  T+${RAMP_COMPLETE_TIME}s:  All ${TOTAL_USERS} users active, ramping complete"
echo "  T+??s:     Scenario 2 triggers → Scale 1 → 2+ replicas"
echo "  T+$((RAMP_COMPLETE_TIME + HOLD_TIME))s:  Test completes, resources release"
echo "  T+$((RAMP_COMPLETE_TIME + HOLD_TIME + 180))s: Scale-down cooldown → Back to 1 replica"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}[Cleanup] Stopping all Alpine traffic...${NC}"
    for alpine in "${ALPINE_NODES[@]}"; do
        ssh "$alpine" "pkill -f 'wget.*stress' 2>/dev/null || true" &
    done
    wait

    # Stop stress on containers
    curl -s "${SERVICE_URL}/stress/stop" > /dev/null 2>&1 || true

    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

trap cleanup EXIT INT TERM

# Check initial state
echo -e "${YELLOW}[1/5] Checking initial state...${NC}"
INITIAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1" 2>/dev/null || echo "?")
echo "  Current web-stress replicas: ${INITIAL_REPLICAS}"

if [ "$INITIAL_REPLICAS" != "1" ]; then
    echo -e "${YELLOW}  Warning: Expected 1 replica, found ${INITIAL_REPLICAS}${NC}"
    read -p "  Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo ""

# Check service health
echo -e "${YELLOW}[2/5] Checking service health...${NC}"
if ! curl -s -f "${SERVICE_URL}/health" > /dev/null; then
    echo -e "${RED}ERROR: Service not reachable at ${SERVICE_URL}${NC}"
    echo "  Make sure intelligent-lb is running on port 8081"
    exit 1
fi
echo -e "${GREEN}✓ Service healthy${NC}"
echo ""

# Create Alpine simulation script
echo -e "${YELLOW}[3/5] Creating Alpine simulation script...${NC}"
cat > /tmp/scenario2_alpine_user.sh << 'ALPINE_SCRIPT'
#!/bin/sh
# Run on Alpine node to simulate staggered users

SERVICE_URL="$1"
USERS="$2"
CPU="$3"
MEMORY="$4"
NETWORK="$5"
STAGGER="$6"
RAMP="$7"
DURATION="$8"
NODE_NAME="$9"

echo "[$NODE_NAME] Starting $USERS users with staggered timing..."
echo "[$NODE_NAME] Per-user: CPU=${CPU}%, MEM=${MEMORY}MB, NET=${NETWORK}Mbps"
echo "[$NODE_NAME] Stagger=${STAGGER}s, Ramp=${RAMP}s, Hold=${DURATION}s"

for user_id in $(seq 1 $USERS); do
    (
        # Stagger start: user 1 at 0s, user 2 at STAGGER, user 3 at 2*STAGGER, etc.
        USER_DELAY=$(awk "BEGIN {print ($user_id - 1) * $STAGGER}")
        sleep $USER_DELAY

        # Calculate remaining duration (account for staggered start)
        REMAINING_DURATION=$(awk "BEGIN {print int($DURATION - $USER_DELAY)}")
        if [ $REMAINING_DURATION -le 0 ]; then
            echo "  [$NODE_NAME] User $user_id: skipped (would start after test end)"
            exit 0
        fi

        # Trigger /stress/combined endpoint
        # This creates CPU + Memory + Network load simultaneously
        wget -q -O /dev/null --timeout=$((RAMP + REMAINING_DURATION + 10)) \
            "$SERVICE_URL/stress/combined?cpu=$CPU&memory=$MEMORY&network=$NETWORK&duration=$REMAINING_DURATION&ramp=$RAMP" \
            2>&1 && echo "  [$NODE_NAME] User $user_id: stress activated (T+${USER_DELAY}s)"
    ) &
done

wait
echo "[$NODE_NAME] All $USERS users completed"
ALPINE_SCRIPT

echo -e "${GREEN}✓ Script created${NC}"
echo ""

# Deploy to Alpine nodes
echo -e "${YELLOW}[4/5] Deploying to Alpine nodes...${NC}"
for alpine in "${ALPINE_NODES[@]}"; do
    echo "  Deploying to ${alpine}..."

    # Kill any existing processes
    ssh "$alpine" "pkill -f scenario2_alpine_user.sh 2>/dev/null" || true
    sleep 1

    # Copy script
    scp -q /tmp/scenario2_alpine_user.sh "${alpine}:/tmp/"
    ssh "$alpine" "chmod +x /tmp/scenario2_alpine_user.sh"
done
echo -e "${GREEN}✓ Deployed to ${#ALPINE_NODES[@]} Alpine nodes${NC}"
echo ""

# Start the test!
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}[5/5] Starting Scenario 2 Test${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}📊 OPEN GRAFANA NOW:${NC}"
echo -e "   ${BLUE}http://192.168.2.61:3000${NC}"
echo -e "   Dashboard: ${BLUE}SwarmGuard_All_Sum${NC}"
echo ""
echo -e "${YELLOW}Expected Behavior:${NC}"
echo "  Phase 1: Gradual resource ramp-up (${RAMP_COMPLETE_TIME}s)"
echo "    - CPU, Memory, Network all increase smoothly"
echo "    - Each user adds load in staggered fashion"
echo ""
echo "  Phase 2: Scenario 2 triggers (around T+60-90s)"
echo "    - Recovery manager detects: CPU > 75% AND Network > 65Mbps"
echo "    - Scales web-stress: 1 → 2 replicas"
echo ""
echo "  Phase 3: Load distribution visible in Grafana"
echo "    - Before: 1 replica at ~${TOTAL_CPU}% CPU, ~${TOTAL_MEMORY}MB RAM"
echo "    - After:  2 replicas at ~$((TOTAL_CPU / 2))% CPU each, ~$((TOTAL_MEMORY / 2))MB RAM each"
echo "    - LB Dashboard shows requests distributed across both replicas"
echo ""
echo "  Phase 4: Hold peak load (${HOLD_TIME}s)"
echo "    - Maintain distributed load to show stability"
echo ""
echo "  Phase 5: Cool down and scale-down"
echo "    - After test completes, resources release"
echo "    - Recovery manager waits 180s cooldown"
echo "    - Scales back: 2 → 1 replica"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop early${NC}"
echo ""

START_TIME=$(date +%s)
PIDS=()

# Launch on all Alpine nodes simultaneously
for alpine in "${ALPINE_NODES[@]}"; do
    echo -e "${BLUE}  Starting ${USERS_PER_ALPINE} users on ${alpine}...${NC}"

    ssh "$alpine" "/tmp/scenario2_alpine_user.sh \
        '$SERVICE_URL' \
        $USERS_PER_ALPINE \
        $USER_CPU \
        $USER_MEMORY \
        $USER_NETWORK \
        $STAGGER_DELAY \
        $RAMP_TIME \
        $HOLD_TIME \
        $alpine" > "/tmp/${alpine}_scenario2.log" 2>&1 &

    PIDS+=($!)
done

echo ""
echo -e "${GREEN}✓ ${TOTAL_USERS} users triggered across ${#ALPINE_NODES[@]} Alpine nodes${NC}"
echo ""

# Monitor progress
echo -e "${YELLOW}Monitoring for $((RAMP_COMPLETE_TIME + HOLD_TIME))s...${NC}"
echo ""

LAST_REPLICAS=$INITIAL_REPLICAS
SCALE_UP_TIME=""

while true; do
    sleep 10
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    # Check if test should be complete
    if [ $ELAPSED -ge $((RAMP_COMPLETE_TIME + HOLD_TIME)) ]; then
        break
    fi

    # Get current replica count
    CURRENT_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1" 2>/dev/null || echo "?")

    # Detect scale events
    if [ "$CURRENT_REPLICAS" != "$LAST_REPLICAS" ]; then
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ✅ SCALE EVENT DETECTED!                              ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
        echo -e "  Time:      T+${ELAPSED}s"
        echo -e "  Change:    ${LAST_REPLICAS} → ${CURRENT_REPLICAS} replicas"
        echo ""
        echo -e "${YELLOW}  Expected load distribution:${NC}"
        echo -e "    - Each replica now handles ~$((TOTAL_CPU / CURRENT_REPLICAS))% CPU"
        echo -e "    - Each replica now handles ~$((TOTAL_MEMORY / CURRENT_REPLICAS))MB Memory"
        echo -e "    - Each replica now handles ~$((TOTAL_NETWORK / CURRENT_REPLICAS))Mbps Network"
        echo ""
        echo -e "${YELLOW}  Check Grafana to verify distribution!${NC}"
        echo ""

        LAST_REPLICAS=$CURRENT_REPLICAS
        SCALE_UP_TIME=$ELAPSED
    else
        # Status update
        if [ $ELAPSED -lt $RAMP_COMPLETE_TIME ]; then
            ACTIVE_USERS=$(awk "BEGIN {print int(($ELAPSED / $STAGGER_DELAY + 1) * ${#ALPINE_NODES[@]})}")
            ACTIVE_USERS=$((ACTIVE_USERS > TOTAL_USERS ? TOTAL_USERS : ACTIVE_USERS))
            echo "[T+${ELAPSED}s] Ramping... | Active users: ~${ACTIVE_USERS}/${TOTAL_USERS} | Replicas: ${CURRENT_REPLICAS}"
        else
            echo "[T+${ELAPSED}s] Peak load | Replicas: ${CURRENT_REPLICAS} | Monitoring for scale events..."
        fi
    fi
done

echo ""
echo -e "${YELLOW}Waiting for Alpine nodes to complete...${NC}"

# Wait for all background jobs
for pid in "${PIDS[@]}"; do
    wait $pid 2>/dev/null || true
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Test Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Final state
FINAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1" 2>/dev/null || echo "?")

echo -e "${BLUE}Summary:${NC}"
echo "  Initial replicas:  ${INITIAL_REPLICAS}"
echo "  Final replicas:    ${FINAL_REPLICAS}"
echo "  Total users:       ${TOTAL_USERS}"
echo "  Expected peak:     ${TOTAL_CPU}% CPU, ${TOTAL_MEMORY}MB RAM, ${TOTAL_NETWORK}Mbps NET"
if [ -n "$SCALE_UP_TIME" ]; then
    echo "  Scale-up time:     T+${SCALE_UP_TIME}s"
fi
echo ""

# Show replica distribution
echo -e "${BLUE}Current replica distribution:${NC}"
ssh master "docker service ps web-stress --filter 'desired-state=running' --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}'"
echo ""

# Show LB metrics
echo -e "${BLUE}Load Balancer Metrics:${NC}"
curl -s "${SERVICE_URL}/metrics" | jq '{
    total_requests: .total_requests,
    healthy_replicas: .healthy_replicas,
    algorithm: .algorithm,
    distribution: [.replica_stats | to_entries[] | {node: .value.node, requests: .value.request_count, leases: .value.active_leases}]
}'
echo ""

# Show logs from Alpine nodes
echo -e "${BLUE}Alpine Node Summary:${NC}"
for alpine in "${ALPINE_NODES[@]}"; do
    echo "  [${alpine}]"
    tail -3 "/tmp/${alpine}_scenario2.log" 2>/dev/null | sed 's/^/    /'
done
echo ""

echo -e "${GREEN}✅ Scenario 2 Ultimate Test Complete!${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Review Grafana dashboards:"
echo "     - SwarmGuard_All_Sum: Overall CPU/Memory/Network distribution"
echo "     - SwarmGuard Load Balancer Visualization: Request distribution"
echo ""
echo "  2. Wait ~3-4 minutes for scale-down cooldown"
echo "     - Recovery manager will scale back to 1 replica when idle"
echo ""
echo "  3. Try different configurations:"
echo "     ./scenario2_ultimate.sh 15 4 40 4 2 15 240   # Faster ramp"
echo "     ./scenario2_ultimate.sh 8 7 70 7 4 25 300    # Higher load per user"
echo ""
echo "  4. Check recovery manager logs:"
echo "     ssh master 'docker service logs recovery-manager --tail 50'"
echo ""

# Cleanup
rm -f /tmp/scenario2_alpine_user.sh
rm -f /tmp/alpine-*_scenario2.log

exit 0
```

**After creating this file, make it executable**:
```bash
chmod +x swarmguard/tests/scenario2_ultimate.sh
```

---

## 🚀 Deployment Steps (On Your Build Server)

After making the changes above:

```bash
# 1. Rebuild web-stress with CPU fixes
cd swarmguard/web-stress
docker build -t docker-registry.amirmuz.com/swarmguard-web-stress:latest .
docker push docker-registry.amirmuz.com/swarmguard-web-stress:latest

# 2. Redeploy web-stress (from control macOS)
cd swarmguard/tests
./deploy_web_stress.sh 1  # Start with 1 replica

# 3. Make the test script executable
chmod +x scenario2_ultimate.sh
```

---

## 🧪 How to Run the Test

### Basic Test (Recommended)
```bash
cd swarmguard/tests
./scenario2_ultimate.sh
```

**This uses default parameters**:
- 10 users per Alpine node (40 total users)
- 5% CPU per user (200% total)
- 50MB Memory per user (2000MB total)
- 5Mbps Network per user (200Mbps total)
- 3s stagger between users
- 20s ramp time per user
- 180s hold time at peak

### Custom Test
```bash
./scenario2_ultimate.sh [USERS] [CPU%] [MEM_MB] [NET_MBPS] [STAGGER] [RAMP] [HOLD]

# Example: Your successful command (confirmed working)
./scenario2_ultimate.sh 3 50 200 1 3 60 900
# → 3 users per Alpine (12 total)
# → 50% CPU per user (600% total → triggers heavy scaling)
# → 200MB Memory per user (2400MB total)
# → 1Mbps Network per user (12Mbps total)
# → 3s stagger, 60s ramp, 900s (15 min) hold time

# Example: Faster ramp, higher load
./scenario2_ultimate.sh 15 6 60 6 2 15 240
```

**Parameter Explanation**:
1. `USERS_PER_ALPINE`: Users per Alpine node (×4 nodes = total users)
2. `USER_CPU`: CPU% each user adds
3. `USER_MEMORY`: Memory MB each user adds
4. `USER_NETWORK`: Network Mbps each user adds
5. `STAGGER_DELAY`: Seconds between each user starting
6. `RAMP_TIME`: Seconds for each user to ramp 0→max
7. `HOLD_TIME`: Seconds to maintain peak load

---

## 📊 Expected Results in Grafana

**Open**: http://192.168.2.61:3000
**Dashboard**: SwarmGuard_All_Sum

### Phase 1: Gradual Ramp-Up (0-47s)
- CPU increases smoothly: 0% → 200%
- Memory increases smoothly: 0MB → 2000MB
- Network increases smoothly: 0Mbps → 200Mbps

### Phase 2: Scenario 2 Triggers (~60-90s)
- Recovery Manager detects: CPU > 75% AND Network > 65%
- Scales: 1 → 2 replicas

### Phase 3: Load Distribution (after scaling)
- Before: 1 replica at ~200% CPU (overloaded)
- After: 2 replicas at ~100% CPU each
- Memory: 2 replicas at ~1000MB each
- Network: 2 replicas at ~100Mbps each

### Phase 4: Cool Down (after test ends)
- Wait 180s cooldown
- Scales back: 2 → 1 replica

---

## 🐛 Troubleshooting

### If Scenario 2 doesn't trigger:

**Check recovery manager logs**:
```bash
ssh master "docker service logs recovery-manager --tail 100" | grep -i "scenario\|scale"
```

**Check monitoring agent logs**:
```bash
ssh master "docker service logs monitoring-agent-worker3 --tail 100" | grep -i "scenario\|threshold"
```

**Check if agent is detecting high load**:
```bash
# During the test, check if alerts are being sent
ssh master "docker service logs monitoring-agent-worker3 --follow" | grep -i "scenario 2"
```

### If CPU doesn't show up in Grafana:

1. Verify web-stress was rebuilt with CPU fix
2. Check web-stress logs for stress activation:
```bash
ssh master "docker service logs web-stress --tail 50"
```

3. Test CPU stress manually:
```bash
curl "http://192.168.2.50:8081/stress/combined?cpu=50&memory=200&network=10&duration=60&ramp=15"
# Watch Grafana - CPU should increase smoothly
```

---

## 📝 Timeline Example (Default Parameters)

```
T+0s:   User 1 starts on each Alpine (4 users)
        → 4 × 5% = 20% CPU, 200MB, 20Mbps

T+3s:   User 2 starts (8 users total)
        → 8 × 5% = 40% CPU, 400MB, 40Mbps

T+6s:   User 3 starts (12 users total)
        → 12 × 5% = 60% CPU, 600MB, 60Mbps

T+27s:  User 10 starts (40 users total)
        → 40 × 5% = 200% CPU, 2000MB, 200Mbps

T+47s:  All users fully ramped to peak load

T+60-90s: ⚡ Scenario 2 triggers
        → Scales 1 → 2 replicas
        → Load splits: 2 × 100% CPU each

T+227s: Test completes, resources release

T+407s: Cooldown complete → Scales 2 → 1 replica
```

---

## ✅ Success Criteria

You know Scenario 2 testing is working when:

1. ✅ **Smooth gradual increase** visible in Grafana (not spiky)
2. ✅ **All three resources increase together**: CPU + Memory + Network
3. ✅ **Scenario 2 triggers** around T+60-90s
4. ✅ **Load distributes** proportionally after scaling
5. ✅ **LB Dashboard** shows requests distributed across replicas
6. ✅ **Recovery manager logs** show scaling decisions
7. ✅ **Automatic scale-down** after cooldown period

---

## 📚 Related Files

- **Test Script**: `swarmguard/tests/scenario2_ultimate.sh`
- **CPU Fix 1**: `swarmguard/web-stress/stress/cpu_stress.py`
- **CPU Fix 2**: `swarmguard/web-stress/app.py`
- **Config**: `swarmguard/recovery-manager/config.yaml`
- **PRD Reference**: `dev_resources/PRD.md` (Section 5.2 - Test Case 2)

---

## 🎓 Key Insights

### Why `/stress/combined` works best:
- Runs CPU + Memory + Network simultaneously in background threads
- Doesn't block health checks
- Smooth, controllable ramp-up
- Works with staggered Alpine requests for gradual load buildup

### Why staggered users create smooth visualization:
- Each user starts 3s apart (configurable)
- Each user ramps 0→max over 20s
- Combined effect: Very smooth curves in Grafana
- Easy to see exactly when Scenario 2 triggers

### Why this demonstrates your FYP well:
1. Shows **proactive** recovery (before failure)
2. Shows **lease-based LB** distributing load
3. Shows **smooth resource management** (not reactive spikes)
4. Shows **complete lifecycle**: 1 → scale up → distribute → scale down → 1
5. Validates **both Scenario 1 and Scenario 2** work correctly

---

## 🔄 Reverting to This Working Version

If you need to revert your working code and apply only these changes:

```bash
# 1. Go back to your working branch
git checkout <your-working-branch>

# 2. Apply only the CPU fixes to cpu_stress.py and app.py
#    (manually copy the NEW CODE sections above)

# 3. Copy scenario2_ultimate.sh to tests/
cp /path/to/scenario2_ultimate.sh swarmguard/tests/

# 4. Rebuild and redeploy web-stress
#    (follow deployment steps above)

# 5. Run the test
cd swarmguard/tests
./scenario2_ultimate.sh
```

---

**End of Scenario 2 Testing Guide**
