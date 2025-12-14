#!/bin/bash
# Alpine Scenario 2 - Incremental Load Test (Per-User Resource Contributions)
# Purpose: Simulate N users, each adding X% CPU + Y MB RAM + Z Mbps network
#
# Usage:
#   ./alpine_scenario2_incremental.sh [USERS] [CPU%] [MEMORY_MB] [NETWORK_MBPS] [RAMP] [DURATION]
#
# Examples:
#   ./alpine_scenario2_incremental.sh 10 2 50 5 60 120    # 40 users: 2% CPU, 50MB, 5Mbps each
#   ./alpine_scenario2_incremental.sh 15 3 75 8 60 180    # 60 users: 3% CPU, 75MB, 8Mbps each

set -e

echo "=========================================="
echo "Scenario 2: Incremental Load Test"
echo "=========================================="
echo ""

# Configuration from command-line arguments
USERS_PER_NODE=${1:-10}       # Users per Alpine node
USER_CPU_PERCENT=${2:-2}      # CPU% per user
USER_MEMORY_MB=${3:-50}       # Memory MB per user
USER_NETWORK_MBPS=${4:-5}     # Network Mbps per user
RAMP_SECONDS=${5:-60}         # Ramp-up time
TOTAL_DURATION=${6:-120}      # Duration to hold peak load

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
echo "  Ramp-up time:          ${RAMP_SECONDS}s"
echo "  Hold duration:         ${TOTAL_DURATION}s"
echo ""
echo "Per-user resource contribution:"
echo "  CPU:     ${USER_CPU_PERCENT}%"
echo "  Memory:  ${USER_MEMORY_MB}MB"
echo "  Network: ${USER_NETWORK_MBPS}Mbps"
echo ""
echo "Expected aggregate load (at peak):"
echo "  Total CPU:     ${EXPECTED_CPU}% (triggers scale-up at ~80%)"
echo "  Total Memory:  ${EXPECTED_MEMORY}MB"
echo "  Total Network: ${EXPECTED_NETWORK}Mbps (triggers scale-up at ~70Mbps)"
echo ""
echo "Timeline:"
echo "  T+0s:       Users start ramping resources"
echo "  T+${RAMP_SECONDS}s:  Peak load reached"
echo "  T+$((RAMP_SECONDS + 30))s: Scale-up should trigger (if thresholds met)"
echo "  T+$((RAMP_SECONDS + TOTAL_DURATION))s: Test completes, resources release"
echo ""

# Get initial state
echo "[1/4] Initial state:"
INITIAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo "  web-stress replicas: $INITIAL_REPLICAS"
echo ""

# Create Alpine simulation script
cat > /tmp/alpine_incremental.sh << 'EOF'
#!/bin/sh
# Each user triggers incremental stress endpoint once

SERVICE_URL="$1"
USERS="$2"
CPU="$3"
MEM="$4"
NET="$5"
RAMP="$6"
DURATION="$7"

echo "[$HOSTNAME] Starting $USERS users..."
echo "[$HOSTNAME] Per-user: CPU=${CPU}%, MEM=${MEM}MB, NET=${NET}Mbps"
echo "[$HOSTNAME] Ramp=${RAMP}s, Duration=${DURATION}s"

# Launch N user processes (all trigger stress simultaneously)
for user_id in $(seq 1 $USERS); do
    (
        # Each user triggers ONE incremental stress request
        # The request holds resources for DURATION seconds, then auto-releases
        wget -q -O /dev/null --timeout=$((RAMP + DURATION + 10)) \
            "$SERVICE_URL/stress/incremental?cpu=$CPU&memory=$MEM&network=$NET&duration=$DURATION&ramp=$RAMP" \
            2>&1 && echo "  User $user_id: stress activated"
    ) &
done

wait
echo "[$HOSTNAME] All $USERS users triggered"
EOF

# Deploy to Alpine nodes
echo "[2/4] Deploying to Alpine nodes..."
for node in "${ALPINE_NODES[@]}"; do
    ssh $node "pkill -f alpine_incremental.sh 2>/dev/null" || true
    sleep 1
    scp -q /tmp/alpine_incremental.sh ${node}:/tmp/
    ssh $node "chmod +x /tmp/alpine_incremental.sh"
done
echo "✓ Deployed to ${#ALPINE_NODES[@]} nodes"
echo ""

# Start simulation
echo "=========================================="
echo "Starting Incremental Load Test"
echo "=========================================="
echo ""
echo "📊 OPEN GRAFANA NOW:"
echo "   → http://192.168.2.61:3000"
echo "   → Dashboard: Container Metrics"
echo ""
echo "Expected behavior:"
echo "  1. All $TOTAL_USERS users trigger /stress/incremental simultaneously"
echo "  2. Each request adds ${USER_CPU_PERCENT}% CPU, ${USER_MEMORY_MB}MB RAM, ${USER_NETWORK_MBPS}Mbps"
echo "  3. Load ramps up over ${RAMP_SECONDS}s → aggregate reaches ${EXPECTED_CPU}% CPU, ${EXPECTED_MEMORY}MB RAM, ${EXPECTED_NETWORK}Mbps NET"
echo "  4. System detects high load → triggers Scenario 2 scale-up"
echo "  5. Load distributes across replicas (visible in Grafana)"
echo "  6. After ${TOTAL_DURATION}s, resources auto-release"
echo ""

PIDS=()
for node in "${ALPINE_NODES[@]}"; do
    echo "  Triggering $USERS_PER_NODE users on $node..."
    ssh $node "/tmp/alpine_incremental.sh $SERVICE_URL $USERS_PER_NODE $USER_CPU_PERCENT $USER_MEMORY_MB $USER_NETWORK_MBPS $RAMP_SECONDS $TOTAL_DURATION" > /tmp/${node}_incremental.log 2>&1 &
    PIDS+=($!)
done

echo ""
echo "✓ $TOTAL_USERS users triggered incremental stress"
echo ""

# Monitor
echo "[3/4] Monitoring for $((RAMP_SECONDS + TOTAL_DURATION))s..."
echo ""
START_TIME=$(date +%s)
LAST_REPLICAS=$INITIAL_REPLICAS

while true; do
    sleep 15
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    if [ $ELAPSED -ge $((RAMP_SECONDS + TOTAL_DURATION)) ]; then
        break
    fi

    CURRENT=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")

    if [ "$CURRENT" != "$LAST_REPLICAS" ]; then
        echo ""
        echo "✅ SCALE EVENT: $LAST_REPLICAS → $CURRENT replicas"
        echo "   → Load now distributed across $CURRENT replicas"
        echo "   → Check Grafana: each replica should show ~$((EXPECTED_CPU / CURRENT))% CPU, ~$((EXPECTED_MEMORY / CURRENT))MB RAM"
        echo ""
        LAST_REPLICAS=$CURRENT
    else
        if [ $ELAPSED -lt $RAMP_SECONDS ]; then
            echo "[+${ELAPSED}s] Ramping up... | Replicas: $CURRENT | Target: ${EXPECTED_CPU}% CPU at T+${RAMP_SECONDS}s"
        else
            echo "[+${ELAPSED}s] Peak load | Replicas: $CURRENT | Check Grafana for distribution"
        fi
    fi
done

echo ""
echo "Waiting for Alpine nodes to complete..."

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
echo "  Expected peak:     ${EXPECTED_CPU}% CPU, ${EXPECTED_MEMORY}MB RAM, ${EXPECTED_NETWORK}Mbps NET"
echo ""

# Show task distribution
echo "Final replica distribution:"
ssh master "docker service ps web-stress --filter 'desired-state=running' --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}'"
echo ""

# Show summary from each Alpine node
echo "User summary:"
for node in "${ALPINE_NODES[@]}"; do
    echo "  [$node]"
    tail -3 /tmp/${node}_incremental.log 2>/dev/null || echo "    (no output)"
done

echo ""
echo "✅ Incremental load test complete!"
echo ""
echo "Next steps:"
echo "  1. Review Grafana to verify load was distributed across replicas"
echo "  2. Wait ~4 minutes for scale-down to baseline"
echo "  3. Try different configurations:"
echo "     ./alpine_scenario2_incremental.sh 15 3 75 8 60 180"
echo "     ./alpine_scenario2_incremental.sh 20 4 100 10 60 240"
echo ""

# Cleanup
rm -f /tmp/alpine_incremental.sh
rm -f /tmp/alpine-*_incremental.log

exit 0
