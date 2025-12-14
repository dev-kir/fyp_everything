#!/bin/bash
# Alpine Scenario 2 - User Simulation with /stress/combined
# Strategy: Each "user" triggers combined stress (CPU+MEM+NET) with SHORT duration
#           Many concurrent users → many concurrent stress instances → distributed load
#
# Usage:
#   ./alpine_scenario2_stress.sh [USERS] [CPU%] [MEMORY_MB] [NETWORK_MBPS] [DURATION]
#
# Examples:
#   ./alpine_scenario2_stress.sh 10 20 200 15 300    # 40 users, 20% CPU each
#   ./alpine_scenario2_stress.sh 15 15 150 10 300    # 60 users, 15% CPU each

set -e

echo "=========================================="
echo "Scenario 2: User Simulation (Stress API)"
echo "=========================================="
echo ""

# Configuration from command-line arguments
USERS_PER_NODE=${1:-10}       # Default: 10 users per Alpine
USER_CPU_PERCENT=${2:-20}     # Default: 20% CPU per user
USER_MEMORY_MB=${3:-200}      # Default: 200MB RAM per user
USER_NETWORK_MBPS=${4:-15}    # Default: 15Mbps network per user
TOTAL_DURATION=${5:-300}      # Default: 5 minutes

SERVICE_URL="http://192.168.2.50:8080"
ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4")
TOTAL_USERS=$((USERS_PER_NODE * ${#ALPINE_NODES[@]}))

# Each stress call duration (SHORT - so users keep re-triggering)
STRESS_DURATION=10  # 10s per stress call

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
echo "Per-user contribution (per stress call):"
echo "  CPU:     ${USER_CPU_PERCENT}%"
echo "  Memory:  ${USER_MEMORY_MB}MB"
echo "  Network: ${USER_NETWORK_MBPS}Mbps"
echo "  Stress duration: ${STRESS_DURATION}s (then re-trigger)"
echo ""
echo "Expected total load:"
echo "  CPU:     ~${EXPECTED_CPU}% (will trigger scale-up at ~80%)"
echo "  Memory:  ~${EXPECTED_MEMORY}MB"
echo "  Network: ~${EXPECTED_NETWORK}Mbps"
echo ""

# Get initial state
echo "[1/3] Initial state:"
INITIAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo "  web-stress replicas: $INITIAL_REPLICAS"
echo ""

# Create Alpine user simulation script
cat > /tmp/alpine_stress_users.sh << 'EOF'
#!/bin/sh
# Simulates N users, each triggering combined stress continuously

SERVICE_URL="$1"
TOTAL_DURATION="$2"
USERS="$3"
CPU="$4"
MEMORY="$5"
NETWORK="$6"
STRESS_DURATION="$7"

echo "[$HOSTNAME] Starting $USERS simulated users for ${TOTAL_DURATION}s..."
echo "[$HOSTNAME] Each user: CPU=${CPU}%, MEM=${MEMORY}MB, NET=${NETWORK}Mbps"
END_TIME=$(($(date +%s) + TOTAL_DURATION))

# Launch N user processes
for user_id in $(seq 1 $USERS); do
    (
        USER_REQUESTS=0
        while [ $(date +%s) -lt $END_TIME ]; do
            # Each user triggers combined stress
            # Docker Swarm distributes these requests across replicas
            wget -q -O /dev/null --timeout=3 "$SERVICE_URL/stress/combined?cpu=$CPU&memory=$MEMORY&network=$NETWORK&duration=$STRESS_DURATION&ramp=2" 2>&1 && USER_REQUESTS=$((USER_REQUESTS + 1))

            # Small delay before next stress (continuous but not overwhelming)
            sleep 1
        done
        echo "  User $user_id completed $USER_REQUESTS stress cycles"
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
    ssh $node "pkill -f alpine_stress_users.sh 2>/dev/null" || true
    # Deploy new script
    scp -q /tmp/alpine_stress_users.sh ${node}:/tmp/
    ssh $node "chmod +x /tmp/alpine_stress_users.sh"
done
echo "✓ Deployed to ${#ALPINE_NODES[@]} nodes"
echo ""

# Start user simulation
echo "=========================================="
echo "Starting User Simulation"
echo "=========================================="
echo ""
echo "Launching $TOTAL_USERS simulated users across ${#ALPINE_NODES[@]} Alpine nodes..."
echo "Each user will continuously trigger /stress/combined for ${TOTAL_DURATION}s"
echo ""
echo "📊 OPEN GRAFANA NOW:"
echo "   → http://192.168.2.61:3000"
echo "   → Dashboard: Container Metrics"
echo ""
echo "What to watch:"
echo "  T+0s:   ${TOTAL_USERS} users → 1 replica → CPU/MEM/NET rises"
echo "  T+30s:  System detects high load → scale 1→2"
echo "  T+60s:  ${TOTAL_USERS} users → distributed across 2 replicas → load splits"
echo "  T+90s:  If still high → scale 2→3"
echo "  T+120s: ${TOTAL_USERS} users → distributed across 3 replicas"
echo ""
echo "How it works:"
echo "  - Each user = background process sending /stress/combined requests"
echo "  - Docker Swarm distributes requests → stress runs on multiple replicas"
echo "  - Short stress duration (${STRESS_DURATION}s) → users keep re-triggering"
echo "  - Result: Sustained distributed load across all replicas"
echo ""

PIDS=()
for node in "${ALPINE_NODES[@]}"; do
    echo "  Starting $USERS_PER_NODE users on $node..."
    ssh $node "/tmp/alpine_stress_users.sh $SERVICE_URL $TOTAL_DURATION $USERS_PER_NODE $USER_CPU_PERCENT $USER_MEMORY_MB $USER_NETWORK_MBPS $STRESS_DURATION" > /tmp/${node}_stress.log 2>&1 &
    PIDS+=($!)
done

echo ""
echo "✓ $TOTAL_USERS users actively sending requests"
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
        echo "✅ SCALE-UP DETECTED: $LAST_REPLICAS → $CURRENT replicas"
        echo "   → $TOTAL_USERS users now distributed across $CURRENT replicas"
        echo "   → Each replica handling ~$((TOTAL_USERS / CURRENT)) concurrent users"
        echo "   → Check Grafana: CPU/MEM/NET should split across $CURRENT replicas"
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
echo "  Duration:          ${TOTAL_DURATION}s"
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
    tail -5 /tmp/${node}_stress.log 2>/dev/null || echo "  (no output)"
done

echo ""
echo "✅ Test complete!"
echo ""
echo "Next steps:"
echo "  1. Review Grafana to see how load distributed across replicas"
echo "  2. Wait ~4 minutes for scale-down to return to baseline"
echo "  3. Run again with different configurations:"
echo "     - ./alpine_scenario2_stress.sh 15 20 200 15 300    # 60 users"
echo "     - ./alpine_scenario2_stress.sh 20 25 250 20 300    # 80 users, heavier load"
echo ""

# Cleanup
rm -f /tmp/alpine_stress_users.sh
rm -f /tmp/alpine-*_stress.log

exit 0
