#!/bin/bash
# Alpine Scenario 2 - Per-User Resource Load Test
# Purpose: Simulate N users, each contributing X% CPU + Y MB RAM + Z Mbps network
#
# Usage:
#   ./alpine_scenario2.sh [USERS] [CPU%] [MEMORY_MB] [NETWORK_MBPS] [DURATION]
#
# Examples:
#   ./alpine_scenario2.sh 10 2 50 2 120     # 40 total users: 2% CPU, 50MB RAM, 2Mbps each
#   ./alpine_scenario2.sh 15 4 100 5 300    # 60 total users: 4% CPU, 100MB RAM, 5Mbps each
#   ./alpine_scenario2.sh 20 5 150 8 300    # 80 total users: 5% CPU, 150MB RAM, 8Mbps each

set -e

echo "=========================================="
echo "Scenario 2: Per-User Resource Load Test"
echo "=========================================="
echo ""

# Configuration from command-line arguments
USERS_PER_NODE=${1:-10}       # Default: 10 users per Alpine
USER_CPU_PERCENT=${2:-2}      # Default: 2% CPU per user
USER_MEMORY_MB=${3:-50}       # Default: 50MB RAM per user
USER_NETWORK_MBPS=${4:-2}     # Default: 2Mbps network per user
TOTAL_DURATION=${5:-120}      # Default: 120 seconds

SERVICE_URL="http://192.168.2.50:8080"
ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4")
TOTAL_USERS=$((USERS_PER_NODE * ${#ALPINE_NODES[@]}))

# Calculate expected total load
EXPECTED_CPU=$((TOTAL_USERS * USER_CPU_PERCENT))
EXPECTED_MEMORY=$((TOTAL_USERS * USER_MEMORY_MB))
EXPECTED_NETWORK=$((TOTAL_USERS * USER_NETWORK_MBPS))

echo "Configuration:"
echo "  Users per Alpine node: $USERS_PER_NODE"
echo "  Total Alpine nodes:    ${#ALPINE_NODES[@]}"
echo "  Total simulated users: $TOTAL_USERS"
echo "  Test duration:         ${TOTAL_DURATION}s"
echo ""
echo "Per-user resource contribution:"
echo "  CPU:     ${USER_CPU_PERCENT}%"
echo "  Memory:  ${USER_MEMORY_MB}MB"
echo "  Network: ${USER_NETWORK_MBPS}Mbps"
echo ""
echo "Expected aggregate load:"
echo "  Total CPU:     ~${EXPECTED_CPU}% (triggers scale-up at ~80%)"
echo "  Total Memory:  ~${EXPECTED_MEMORY}MB"
echo "  Total Network: ~${EXPECTED_NETWORK}Mbps (triggers scale-up at ~70Mbps)"
echo ""

# Get initial state
echo "[1/3] Initial state:"
INITIAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo "  web-stress replicas: $INITIAL_REPLICAS"
echo ""

# Create Alpine user simulation script
# Each "user" triggers /stress/combined with their allocated resources
cat > /tmp/alpine_scenario2_user.sh << 'EOF'
#!/bin/sh
# Simulates N users, each triggering continuous stress with fixed resource allocation

SERVICE_URL="$1"
DURATION="$2"
USERS="$3"
CPU_PER_USER="$4"
MEM_PER_USER="$5"
NET_PER_USER="$6"

echo "[$HOSTNAME] Starting $USERS simulated users for ${DURATION}s"
echo "[$HOSTNAME] Per-user: CPU=${CPU_PER_USER}%, MEM=${MEM_PER_USER}MB, NET=${NET_PER_USER}Mbps"

END_TIME=$(($(date +%s) + DURATION))

# Launch N user processes
for user_id in $(seq 1 $USERS); do
    (
        USER_CYCLES=0
        while [ $(date +%s) -lt $END_TIME ]; do
            # Each user triggers stress/combined with SHORT duration
            # Docker Swarm load-balances these requests across replicas
            # Server creates REAL CPU/Memory/Network load for this user

            # Use 8s stress cycles (6s work + 2s gap)
            # This creates sustained but not overwhelming load
            wget -q -O /dev/null --timeout=10 \
                "$SERVICE_URL/stress/combined?cpu=$CPU_PER_USER&memory=$MEM_PER_USER&network=$NET_PER_USER&duration=6&ramp=1" \
                2>&1 && USER_CYCLES=$((USER_CYCLES + 1))

            # Small gap between cycles
            sleep 2
        done
        echo "  User $user_id completed $USER_CYCLES stress cycles"
    ) &
done

# Wait for all users
wait
echo "[$HOSTNAME] All $USERS users completed"
EOF

# Deploy to Alpine nodes
echo "[2/3] Deploying user simulation to Alpine nodes..."
for node in "${ALPINE_NODES[@]}"; do
    # Kill any existing processes
    ssh $node "pkill -f alpine_scenario2_user.sh 2>/dev/null" || true
    sleep 1
    # Deploy new script
    scp -q /tmp/alpine_scenario2_user.sh ${node}:/tmp/
    ssh $node "chmod +x /tmp/alpine_scenario2_user.sh"
done
echo "✓ Deployed to ${#ALPINE_NODES[@]} nodes"
echo ""

# Start user simulation
echo "=========================================="
echo "Starting User Simulation"
echo "=========================================="
echo ""
echo "Launching $TOTAL_USERS simulated users across ${#ALPINE_NODES[@]} Alpine nodes..."
echo ""
echo "📊 OPEN GRAFANA NOW:"
echo "   → http://192.168.2.61:3000"
echo "   → Dashboard: Container Metrics"
echo ""
echo "What to expect:"
echo "  T+0s:   ${TOTAL_USERS} users → 1 replica"
echo "          Load: ${EXPECTED_CPU}% CPU, ${EXPECTED_MEMORY}MB RAM, ${EXPECTED_NETWORK}Mbps NET"
echo "  T+30s:  High load detected → system scales 1→2 replicas"
echo "  T+60s:  ${TOTAL_USERS} users → distributed across 2 replicas"
echo "          Each replica: ~$((EXPECTED_CPU / 2))% CPU, ~$((EXPECTED_MEMORY / 2))MB RAM, ~$((EXPECTED_NETWORK / 2))Mbps NET"
echo "  T+90s:  If still high → scale 2→3 replicas"
echo "  T+120s: Load distributed across all replicas"
echo ""
echo "✓ Watch Grafana for LIVE distribution as users get balanced!"
echo ""

PIDS=()
for node in "${ALPINE_NODES[@]}"; do
    echo "  Starting $USERS_PER_NODE users on $node..."
    ssh $node "/tmp/alpine_scenario2_user.sh $SERVICE_URL $TOTAL_DURATION $USERS_PER_NODE $USER_CPU_PERCENT $USER_MEMORY_MB $USER_NETWORK_MBPS" > /tmp/${node}_scenario2.log 2>&1 &
    PIDS+=($!)
done

echo ""
echo "✓ $TOTAL_USERS users actively generating load"
echo ""

# Monitor
echo "[3/3] Monitoring for ${TOTAL_DURATION}s..."
echo ""
START_TIME=$(date +%s)
LAST_REPLICAS=$INITIAL_REPLICAS

while true; do
    sleep 15
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    if [ $ELAPSED -ge $TOTAL_DURATION ]; then
        break
    fi

    CURRENT=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")

    if [ "$CURRENT" != "$LAST_REPLICAS" ]; then
        echo ""
        echo "✅ SCALE EVENT: $LAST_REPLICAS → $CURRENT replicas"
        echo "   → ${TOTAL_USERS} users now distributed across $CURRENT replicas"
        echo "   → Per-replica load: ~$((EXPECTED_CPU / CURRENT))% CPU, ~$((EXPECTED_MEMORY / CURRENT))MB RAM, ~$((EXPECTED_NETWORK / CURRENT))Mbps NET"
        echo "   → Check Grafana for distribution visualization"
        echo ""
        LAST_REPLICAS=$CURRENT
    else
        echo "[+${ELAPSED}s] Replicas: $CURRENT | Active users: $TOTAL_USERS | Grafana: CPU/MEM/NET distribution"
    fi
done

echo ""
echo "Waiting for users to complete..."

# Wait for all Alpine nodes
for pid in "${PIDS[@]}"; do
    wait $pid 2>/dev/null || true
done

echo ""
echo "=========================================="
echo "Test Complete"
echo "=========================================="
echo ""

FINAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")

echo "Results:"
echo "  Initial replicas:  $INITIAL_REPLICAS"
echo "  Final replicas:    $FINAL_REPLICAS"
echo "  Total users:       $TOTAL_USERS"
echo "  Duration:          ${TOTAL_DURATION}s"
echo "  Per-user load:     ${USER_CPU_PERCENT}% CPU, ${USER_MEMORY_MB}MB RAM, ${USER_NETWORK_MBPS}Mbps NET"
echo ""

# Show task distribution
echo "Final replica distribution:"
ssh master "docker service ps web-stress --filter 'desired-state=running' --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}'"
echo ""

# Show summary from each Alpine node
echo "User summary from Alpine nodes:"
for node in "${ALPINE_NODES[@]}"; do
    echo ""
    echo "[$node]"
    tail -5 /tmp/${node}_scenario2.log 2>/dev/null || echo "  (no output)"
done

echo ""
echo "✅ Scenario 2 test complete!"
echo ""
echo "Next steps:"
echo "  1. Review Grafana to verify load was distributed evenly across replicas"
echo "  2. Wait ~4 minutes for scale-down to return to baseline"
echo "  3. Try different configurations:"
echo "     ./alpine_scenario2.sh 15 3 75 4 300     # More users, moderate load"
echo "     ./alpine_scenario2.sh 20 5 100 6 300    # Heavy load, more scaling"
echo ""

# Cleanup
rm -f /tmp/alpine_scenario2_user.sh
rm -f /tmp/alpine-*_scenario2.log

exit 0
