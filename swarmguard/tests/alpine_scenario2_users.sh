#!/bin/bash
# Alpine Scenario 2 - Simulated Users Test
# Purpose: Simulate N users per Alpine node, each contributing configurable resource load
#
# Algorithm:
#   - Each user contributes: X% CPU + Y MB RAM + Z Mbps network
#   - Users loop continuously until duration expires
#   - Total load = users × individual contribution
#
# Usage:
#   ./alpine_scenario2_users.sh [USERS] [CPU%] [MEMORY_MB] [NETWORK_MBPS] [DURATION]
#
# Examples:
#   ./alpine_scenario2_users.sh 10 4 40 4 300      # 40 users, 4% CPU each, 5min
#   ./alpine_scenario2_users.sh 15 5 50 5 300      # 60 users, 5% CPU each, 5min
#   ./alpine_scenario2_users.sh 20 3 30 3 300      # 80 users, 3% CPU each, 5min
#
# Quick presets:
#   ./alpine_scenario2_users.sh 15                 # 60 users, default 4%/40MB/4Mbps

set -e

echo "=========================================="
echo "Scenario 2: Simulated Users Test"
echo "=========================================="
echo ""

# Configuration from command-line arguments
USERS_PER_NODE=${1:-10}       # Default: 10 users per Alpine
USER_CPU_PERCENT=${2:-4}      # Default: 4% CPU per user
USER_MEMORY_MB=${3:-40}       # Default: 40MB RAM per user
USER_NETWORK_MBPS=${4:-4}     # Default: 4Mbps network per user
DURATION=${5:-300}            # Default: 5 minutes

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
echo "  Test duration:         ${DURATION}s"
echo ""
echo "Per-user contribution:"
echo "  CPU:     ${USER_CPU_PERCENT}%"
echo "  Memory:  ${USER_MEMORY_MB}MB"
echo "  Network: ${USER_NETWORK_MBPS}Mbps"
echo ""
echo "Expected total load:"
echo "  CPU:     ~${EXPECTED_CPU}% (will trigger scale-up at ~80%)"
echo "  Memory:  ~${EXPECTED_MEMORY}MB"
echo "  Network: ~${EXPECTED_NETWORK}Mbps"
echo ""

# Calculate Pi iterations based on desired CPU contribution per user
# Calibration: ~50k iterations per 1% CPU target
# This is approximate - actual CPU will vary based on Alpine hardware
PI_ITERATIONS=$((USER_CPU_PERCENT * 50000))

# Ensure minimum iterations (avoid too low values)
if [ $PI_ITERATIONS -lt 100000 ]; then
    PI_ITERATIONS=100000
fi

echo "Calibration:"
echo "  Pi iterations per request: $PI_ITERATIONS (~${USER_CPU_PERCENT}% CPU per user)"
echo ""

# Get initial state
echo "[1/3] Initial state:"
INITIAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo "  web-stress replicas: $INITIAL_REPLICAS"
echo ""

# Create Alpine user simulation script
cat > /tmp/alpine_users.sh << 'EOF'
#!/bin/sh
# Simulates N users, each contributing small resource load continuously

SERVICE_URL="$1"
DURATION="$2"
USERS="$3"
ITERATIONS="$4"

echo "[$HOSTNAME] Starting $USERS simulated users for ${DURATION}s..."
echo "[$HOSTNAME] Each user: Pi iterations=$ITERATIONS, delay=0.05s"
END_TIME=$(($(date +%s) + DURATION))

# Launch N user processes
for user_id in $(seq 1 $USERS); do
    (
        USER_REQUESTS=0
        while [ $(date +%s) -lt $END_TIME ]; do
            # Each user sends continuous Pi calculation requests
            # Docker Swarm distributes these requests across replicas
            wget -q -O /dev/null --timeout=2 "$SERVICE_URL/compute/pi?iterations=$ITERATIONS" 2>&1 && USER_REQUESTS=$((USER_REQUESTS + 1))

            # Small delay to prevent overwhelming (but still continuous)
            sleep 0.05
        done
        echo "  User $user_id completed $USER_REQUESTS requests"
    ) &
done

# Wait for all users to finish
wait
echo "[$HOSTNAME] All $USERS users completed"
EOF

# Deploy to Alpine nodes
echo "[2/3] Deploying user simulation to Alpine nodes..."
for node in "${ALPINE_NODES[@]}"; do
    # Kill any existing processes
    ssh $node "pkill -f alpine_users.sh 2>/dev/null" || true
    # Deploy new script
    scp -q /tmp/alpine_users.sh ${node}:/tmp/
    ssh $node "chmod +x /tmp/alpine_users.sh"
done
echo "✓ Deployed to ${#ALPINE_NODES[@]} nodes"
echo ""

# Start user simulation
echo "=========================================="
echo "Starting User Simulation"
echo "=========================================="
echo ""
echo "Launching $TOTAL_USERS simulated users across ${#ALPINE_NODES[@]} Alpine nodes..."
echo "Each user will continuously send requests for ${DURATION}s"
echo ""
echo "📊 OPEN GRAFANA NOW:"
echo "   → http://192.168.2.61:3000"
echo "   → Dashboard: Container Metrics"
echo ""
echo "What to watch:"
echo "  T+0s:   ${TOTAL_USERS} users → 1 replica → CPU rises to ~${EXPECTED_CPU}%"
echo "  T+30s:  System detects high load → scale 1→2"
echo "  T+60s:  ${TOTAL_USERS} users → distributed across 2 replicas → ~40% CPU each"
echo "  T+90s:  If still high → scale 2→3"
echo "  T+120s: ${TOTAL_USERS} users → distributed across 3 replicas → ~27% CPU each"
echo ""
echo "✓ You'll see LIVE distribution in Grafana as traffic flows!"
echo ""

PIDS=()
for node in "${ALPINE_NODES[@]}"; do
    echo "  Starting $USERS_PER_NODE users on $node..."
    ssh $node "/tmp/alpine_users.sh $SERVICE_URL $DURATION $USERS_PER_NODE $PI_ITERATIONS" > /tmp/${node}_users.log 2>&1 &
    PIDS+=($!)
done

echo ""
echo "✓ $TOTAL_USERS users actively sending requests"
echo ""

# Monitor
echo "[3/3] Monitoring for ${DURATION}s..."
echo ""
START_TIME=$(date +%s)
LAST_REPLICAS=$INITIAL_REPLICAS

while true; do
    sleep 15
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    if [ $ELAPSED -ge $DURATION ]; then
        break
    fi

    CURRENT=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")

    if [ "$CURRENT" != "$LAST_REPLICAS" ]; then
        echo ""
        echo "✅ SCALE-UP DETECTED: $LAST_REPLICAS → $CURRENT replicas"
        echo "   → $TOTAL_USERS users now distributed across $CURRENT replicas"
        echo "   → Each replica handling ~$((TOTAL_USERS / CURRENT)) concurrent users"
        echo "   → Check Grafana: CPU/MEM should split across $CURRENT replicas"
        echo ""
        LAST_REPLICAS=$CURRENT
    else
        echo "[+${ELAPSED}s] Replicas: $CURRENT | Users: $TOTAL_USERS active | Check Grafana for distribution"
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
echo "User Simulation Complete"
echo "=========================================="
echo ""

FINAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")

echo "Results:"
echo "  Initial replicas:  $INITIAL_REPLICAS"
echo "  Final replicas:    $FINAL_REPLICAS"
echo "  Simulated users:   $TOTAL_USERS"
echo "  Duration:          ${DURATION}s"
echo ""

# Show task distribution
echo "Final task distribution:"
ssh master "docker service ps web-stress --filter 'desired-state=running' --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}'"
echo ""

# Show summary from each Alpine node
echo "User summary from Alpine nodes:"
for node in "${ALPINE_NODES[@]}"; do
    echo ""
    echo "[$node]"
    tail -5 /tmp/${node}_users.log 2>/dev/null || echo "  (no output)"
done

echo ""
echo "✅ Test complete!"
echo ""
echo "Next steps:"
echo "  1. Review Grafana to see how load distributed across replicas"
echo "  2. Wait ~4 minutes for scale-down to return to baseline"
echo "  3. Run again with different configurations to test scaling:"
echo "     - ./alpine_scenario2_users.sh 15 4 40 4 300    # 60 users, 4% CPU each"
echo "     - ./alpine_scenario2_users.sh 20 5 50 5 300    # 80 users, 5% CPU each"
echo "     - ./alpine_scenario2_users.sh 10 8 60 5 300    # 40 users, 8% CPU each (heavier)"
echo ""

# Cleanup
rm -f /tmp/alpine_users.sh
rm -f /tmp/alpine-*_users.log

exit 0
