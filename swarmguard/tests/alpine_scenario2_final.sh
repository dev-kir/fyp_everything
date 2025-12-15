#!/bin/bash
# Alpine Scenario 2 - User-Based Load Test
# Simulates N users, each contributing X% CPU + Y MB RAM + Z Mbps network
#
# Usage:
#   ./alpine_scenario2_final.sh [USERS] [CPU%] [MEMORY_MB] [NETWORK_MBPS] [RAMP] [DURATION]
#
# Examples:
#   ./alpine_scenario2_final.sh 10 2 50 5 60 120
#     → 10 users/Alpine × 4 Alpines = 40 users
#     → Each user: 2% CPU, 50MB RAM, 5Mbps NET
#     → Expected: 80% CPU, 2000MB RAM, 200Mbps NET
#
#   ./alpine_scenario2_final.sh 20 3 75 7 60 180
#     → 80 users total → ~240% CPU, 6000MB RAM, 560Mbps NET

set -e

echo "=========================================="
echo "Scenario 2: User-Based Load Test"
echo "=========================================="
echo ""

# Parse parameters
if [ $# -eq 1 ]; then
    # Single parameter mode: absolute targets (backward compatible)
    TARGET_CPU=${1:-85}
    TARGET_MEMORY=1200
    TARGET_NETWORK=80
    RAMP=30
    DURATION=180
    USER_MODE=false
elif [ $# -ge 6 ]; then
    # User mode: users, cpu/user, mem/user, net/user, ramp, duration
    USERS_PER_ALPINE=$1
    CPU_PER_USER=$2
    MEM_PER_USER=$3
    NET_PER_USER=$4
    RAMP=$5
    DURATION=$6
    USER_MODE=true

    ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4")
    TOTAL_USERS=$((USERS_PER_ALPINE * ${#ALPINE_NODES[@]}))

    # Calculate aggregate targets
    TARGET_CPU=$((TOTAL_USERS * CPU_PER_USER))
    TARGET_MEMORY=$((TOTAL_USERS * MEM_PER_USER))
    TARGET_NETWORK=$((TOTAL_USERS * NET_PER_USER))
else
    # Old format: cpu, memory, network, duration, ramp
    TARGET_CPU=${1:-85}
    TARGET_MEMORY=${2:-1200}
    TARGET_NETWORK=${3:-80}
    DURATION=${4:-180}
    RAMP=${5:-30}
    USER_MODE=false
fi

SERVICE_URL="http://192.168.2.50:8080"

if [ "$USER_MODE" = true ]; then
    echo "User Simulation Mode:"
    echo "  Users per Alpine:  $USERS_PER_ALPINE"
    echo "  Total Alpines:     ${#ALPINE_NODES[@]}"
    echo "  Total users:       $TOTAL_USERS"
    echo ""
    echo "Per-user contribution:"
    echo "  CPU:     ${CPU_PER_USER}%"
    echo "  Memory:  ${MEM_PER_USER}MB"
    echo "  Network: ${NET_PER_USER}Mbps"
    echo ""
    echo "Expected aggregate load:"
    echo "  CPU:     ${TARGET_CPU}%"
    echo "  Memory:  ${TARGET_MEMORY}MB"
    echo "  Network: ${TARGET_NETWORK}Mbps"
else
    echo "Absolute Target Mode:"
    echo "  Target CPU:     ${TARGET_CPU}%"
    echo "  Target Memory:  ${TARGET_MEMORY}MB"
    echo "  Target Network: ${TARGET_NETWORK}Mbps"
fi

echo ""
echo "Timing:"
echo "  Ramp-up:  ${RAMP}s"
echo "  Duration: ${DURATION}s"
echo ""

# Get initial state
echo "[1/2] Initial state:"
INITIAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo "  web-stress replicas: $INITIAL_REPLICAS"
echo ""

# Deploy user simulation script to Alpine nodes
if [ "$USER_MODE" = true ]; then
    echo "[2/4] Deploying user simulation to Alpine nodes..."

    # Calculate per-Alpine aggregate (users × per-user contribution)
    ALPINE_CPU=$((USERS_PER_ALPINE * CPU_PER_USER))
    ALPINE_MEMORY=$((USERS_PER_ALPINE * MEM_PER_USER))
    ALPINE_NETWORK=$((USERS_PER_ALPINE * NET_PER_USER))

    echo "Per-Alpine targets (${USERS_PER_ALPINE} users):"
    echo "  CPU:     ${ALPINE_CPU}%"
    echo "  Memory:  ${ALPINE_MEMORY}MB"
    echo "  Network: ${ALPINE_NETWORK}Mbps"
    echo ""

    # Create Alpine script - Continuous requests to distribute across replicas
    cat > /tmp/alpine_user_sim.sh << 'EOFSCRIPT'
#!/bin/sh
SERVICE_URL="$1"
DURATION="$2"
CPU_PER_USER="$3"
MEM_PER_USER="$4"
NET_PER_USER="$5"
USERS="$6"

echo "[$HOSTNAME] Simulating $USERS users for ${DURATION}s"
echo "[$HOSTNAME] Per-user: CPU=${CPU_PER_USER}%, MEM=${MEM_PER_USER}MB, NET=${NET_PER_USER}Mbps"

STOP_FLAG="/tmp/stop_alpine_sim_$$"
trap 'touch $STOP_FLAG; echo "[$HOSTNAME] Stopping all users..."; exit 0' INT TERM

END_TIME=$(($(date +%s) + DURATION))

# Launch N user processes in parallel
for user_id in $(seq 1 $USERS); do
    (
        REQUESTS=0
        while [ $(date +%s) -lt $END_TIME ] && [ ! -f $STOP_FLAG ]; do
            # Each user makes continuous 30s requests
            wget -q -O /dev/null --timeout=35 \
                "$SERVICE_URL/stress/combined?cpu=$CPU_PER_USER&memory=$MEM_PER_USER&network=$NET_PER_USER&duration=30&ramp=5" \
                2>&1 && REQUESTS=$((REQUESTS + 1))

            # Small delay between requests to avoid overwhelming
            sleep 2
        done
        echo "  [$HOSTNAME] User $user_id: $REQUESTS requests completed"
    ) &
done

# Wait for all user processes
wait
rm -f $STOP_FLAG
echo "[$HOSTNAME] ✓ All $USERS users completed"
EOFSCRIPT

    # Deploy to Alpine nodes
    for node in "${ALPINE_NODES[@]}"; do
        ssh $node "pkill -f alpine_user_sim.sh 2>/dev/null" || true
        scp -q /tmp/alpine_user_sim.sh ${node}:/tmp/
        ssh $node "chmod +x /tmp/alpine_user_sim.sh"
    done
    echo "✓ Deployed to ${#ALPINE_NODES[@]} Alpine nodes"
    echo ""

    # Start user simulation
    echo "[3/4] Starting user simulation on Alpine nodes..."
    echo ""
    echo "📊 OPEN GRAFANA NOW:"
    echo "   → http://192.168.2.61:3000"
    echo "   → Dashboard: Container Metrics"
    echo ""
    echo "Expected behavior:"
    echo "  - ${TOTAL_USERS} users making continuous requests"
    echo "  - Docker Swarm distributes requests across replicas"
    echo "  - T+30s: Peak load (${TARGET_CPU}% CPU, ${TARGET_MEMORY}MB RAM, ${TARGET_NETWORK}Mbps NET)"
    echo "  - T+60s: Scenario 2 triggers → scale 1→2"
    echo "  - T+90s: Load distributes across 2 replicas (visible in Grafana)"
    echo ""
    echo "Press Ctrl+C to stop the test"
    echo ""

    PIDS=()
    for node in "${ALPINE_NODES[@]}"; do
        echo "  Starting $USERS_PER_ALPINE users on $node..."
        ssh $node "/tmp/alpine_user_sim.sh $SERVICE_URL $DURATION $CPU_PER_USER $MEM_PER_USER $NET_PER_USER $USERS_PER_ALPINE" > /tmp/${node}_sim.log 2>&1 &
        PIDS+=($!)
    done

    echo ""
    echo "✓ ${TOTAL_USERS} users actively generating load"
    echo ""
else
    # Absolute mode - single stress trigger (old behavior)
    echo "[2/4] Triggering stress/combined endpoint..."
    echo ""
    echo "📊 OPEN GRAFANA NOW:"
    echo "   → http://192.168.2.61:3000"
    echo ""

    curl -s "http://192.168.2.50:8080/stress/combined?cpu=${TARGET_CPU}&memory=${TARGET_MEMORY}&network=${TARGET_NETWORK}&duration=${DURATION}&ramp=${RAMP}" | jq . &
    STRESS_PID=$!
    echo ""
    echo "✓ Stress test started (PID: $STRESS_PID)"
    echo ""
fi

# Monitor
echo "Monitoring for ${DURATION}s..."
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
        echo "✅ SCALE EVENT: $LAST_REPLICAS → $CURRENT replicas"
        echo "   → Check Grafana to see load distribution"
        echo ""
        LAST_REPLICAS=$CURRENT
    else
        echo "[+${ELAPSED}s] Replicas: $CURRENT | Check Grafana: CPU/MEM/NET"
    fi
done

# Wait for stress to complete
wait $STRESS_PID 2>/dev/null || true

echo ""
echo "=========================================="
echo "Test Complete"
echo "=========================================="
echo ""

FINAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")

echo "Results:"
echo "  Initial replicas: $INITIAL_REPLICAS"
echo "  Final replicas:   $FINAL_REPLICAS"
echo "  Duration:         ${DURATION}s"
echo "  Peak load:        CPU=${TARGET_CPU}%, MEM=${TARGET_MEMORY}MB, NET=${TARGET_NETWORK}Mbps"
echo ""

ssh master "docker service ps web-stress --filter 'desired-state=running' --format 'table {{.Name}}\t{{.Node}}'"
echo ""

echo "✅ Scenario 2 test complete!"
echo ""
echo "Note: Wait ~4 minutes for automatic scale-down to baseline"
echo ""

exit 0
