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
ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4" "alpine-5")

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
        # Kill wget processes (both foreground and background)
        ssh "$alpine" "pkill -9 -f 'wget' 2>/dev/null || true" &
        # Kill the Alpine script itself
        ssh "$alpine" "pkill -9 -f 'scenario2_alpine_user.sh' 2>/dev/null || true" &
    done
    wait

    # Stop stress on containers
    echo -e "${YELLOW}[Cleanup] Stopping stress on containers...${NC}"
    curl -s "${SERVICE_URL}/stress/stop" > /dev/null 2>&1 || true

    # Wait for all processes to die
    sleep 3

    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

trap cleanup EXIT INT TERM

# Pre-cleanup: Ensure no leftover processes from previous runs
echo -e "${YELLOW}[0/5] Pre-cleanup: Killing any leftover processes...${NC}"
for alpine in "${ALPINE_NODES[@]}"; do
    ssh "$alpine" "pkill -9 -f 'wget' 2>/dev/null || true" &
    ssh "$alpine" "pkill -9 -f 'scenario2_alpine_user.sh' 2>/dev/null || true" &
done
wait
curl -s "${SERVICE_URL}/stress/stop" > /dev/null 2>&1 || true
sleep 3
echo -e "${GREEN}✓ Pre-cleanup complete${NC}"
echo ""

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
# Run on Alpine node to simulate staggered users with continuous traffic

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

        # Send continuous overlapping requests to maintain sustained load
        # Strategy: Send requests that overlap heavily to ensure no gaps in resource usage
        # This keeps load continuous AND allows new replicas to receive requests
        TEST_END_TIME=$(($(date +%s) + REMAINING_DURATION))
        REQUEST_COUNT=0

        echo "  [$NODE_NAME] User $user_id: starting continuous traffic (T+${USER_DELAY}s)"

        # HYBRID APPROACH: Combine /stress/combined (CPU/Memory) + continuous downloads (Network)
        # This creates sustained network load while maintaining CPU/Memory control

        # Start continuous download worker in background for sustained network load
        (
            while [ $(date +%s) -lt $TEST_END_TIME ]; do
                # Download 50MB files continuously - creates sustained network traffic
                # Each download at 100Mbps takes ~4 seconds, creating overlapping downloads
                wget -q -O /dev/null --timeout=60 \
                    "$SERVICE_URL/download/data?size_mb=50&cpu_work=0" \
                    2>&1
                # No sleep - start next download immediately after one finishes
            done
        ) &
        DOWNLOAD_PID=$!

        # Keep sending CPU/Memory stress requests until test duration ends
        while [ $(date +%s) -lt $TEST_END_TIME ]; do
            # Calculate time left
            TIME_LEFT=$((TEST_END_TIME - $(date +%s)))

            # Exit if no time left
            if [ $TIME_LEFT -le 0 ]; then
                break
            fi

            # For first request only, use the ramp period
            if [ $REQUEST_COUNT -eq 0 ]; then
                CURRENT_RAMP=$RAMP
            else
                CURRENT_RAMP=0  # No ramp for subsequent requests
            fi

            # Use 60-second request duration for CPU/Memory stress
            REQUEST_DURATION=60
            if [ $TIME_LEFT -lt $REQUEST_DURATION ]; then
                REQUEST_DURATION=$TIME_LEFT
            fi

            # Send CPU/Memory stress request (network=0 since downloads handle that)
            wget -q -O /dev/null --timeout=$((CURRENT_RAMP + REQUEST_DURATION + 10)) \
                "$SERVICE_URL/stress/combined?cpu=$CPU&memory=$MEMORY&network=0&duration=$REQUEST_DURATION&ramp=$CURRENT_RAMP" \
                2>&1 &

            REQUEST_COUNT=$((REQUEST_COUNT + 1))

            # Wait 15 seconds before next stress request
            sleep 15
        done

        # Stop download worker
        kill $DOWNLOAD_PID 2>/dev/null || true

        echo "  [$NODE_NAME] User $user_id: completed ${REQUEST_COUNT} requests"
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
