#!/bin/bash
# Alpine Pi Scenario 2 Load Test - Visualize Resource Distribution
# Purpose: Simulate continuous user traffic to trigger scale-up and observe load distribution in Grafana
# Each user = infinite request loop until duration expires (no batches, truly continuous)
#
# Usage:
#   ./alpine_scenario2_visualize.sh [CPU] [MEMORY] [NETWORK] [RAMP] [USERS]
#
# Examples:
#   ./alpine_scenario2_visualize.sh                        # Default: 85% CPU, 800MB, 70Mbps, 10s ramp, 10 users/node
#   ./alpine_scenario2_visualize.sh 90 1200 80 60 20       # Heavy: 90% CPU, 1.2GB, 80Mbps, 60s ramp, 20 users/node
#   ./alpine_scenario2_visualize.sh 95 1500 85 60 30       # Very heavy: More replicas, 30 users/node

set -e

echo "=========================================="
echo "Scenario 2: Load Distribution Visualization"
echo "=========================================="
echo ""

# Configuration from command-line arguments
TARGET_CPU=${1:-85}        # Default 85%
TARGET_MEMORY=${2:-800}    # Default 800MB
TARGET_NETWORK=${3:-70}    # Default 70Mbps
RAMP_TIME=${4:-10}         # Default 10s
SIMULATED_USERS=${5:-10}   # Default 10 simulated users

SERVICE_URL="http://192.168.2.50:8080"
ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4")
TOTAL_DURATION=300  # 5 min continuous traffic
USERS_PER_NODE=$SIMULATED_USERS  # Simulated users per Alpine node

echo "Stress Configuration:"
echo "  CPU Target:     ${TARGET_CPU}%"
echo "  Memory Target:  ${TARGET_MEMORY}MB"
echo "  Network Target: ${TARGET_NETWORK}Mbps"
echo "  Ramp Time:      ${RAMP_TIME}s"
echo "  Simulated Users: $SIMULATED_USERS"
echo ""

echo "Test approach:"
echo "  Duration: ${TOTAL_DURATION}s continuous traffic from Alpine nodes"
echo "  Alpine nodes: 4 (alpine-1, alpine-2, alpine-3, alpine-4)"
echo "  Users per node: $USERS_PER_NODE"
echo "  Total simulated users: $((USERS_PER_NODE * 4))"
echo ""
echo "What happens:"
echo "  1. Alpine sends CONTINUOUS CPU-intensive traffic (20 req/sec per user)"
echo "  2. High sustained load → triggers scale-up based on CPU/Memory"
echo "  3. Traffic CONTINUES after scale-up → AUTOMATICALLY distributes across replicas"
echo "  4. Grafana shows CPU/MEM/NET distributed in real-time"
echo ""

# Create Alpine load script with CPU-intensive distributed traffic
cat > /tmp/alpine_scenario2.sh << 'EOF'
#!/bin/sh
# Simulates N concurrent users sending CONTINUOUS requests
# Each user = infinite loop until duration expires
# No batches, no gaps - truly continuous traffic for distribution visibility
SERVICE_URL="$1"
DURATION="$2"
USERS="$3"
ITERATIONS="$4"

echo "[$HOSTNAME] Starting $USERS simulated users for ${DURATION}s..."
END_TIME=$(($(date +%s) + DURATION))
TOTAL_REQUESTS=0

# Launch N users (background processes)
for user_id in $(seq 1 $USERS); do
    (
        USER_REQUESTS=0
        while [ $(date +%s) -lt $END_TIME ]; do
            # User sends Pi calculation request
            # Docker Swarm distributes across replicas
            if wget -q -O /dev/null --timeout=10 "$SERVICE_URL/compute/pi?iterations=$ITERATIONS" 2>&1; then
                USER_REQUESTS=$((USER_REQUESTS + 1))
            fi

            # Small sleep to prevent Alpine from overwhelming itself (0.05s = 20 req/sec per user)
            sleep 0.05
        done
        echo "  User $user_id completed $USER_REQUESTS requests"
    ) &
done

# Wait for all users to complete
wait

echo "[$HOSTNAME] All $USERS users completed"
EOF

# Deploy to Alpine nodes
echo "[1/4] Deploying to Alpine nodes..."
for node in "${ALPINE_NODES[@]}"; do
    # Kill any existing test processes
    ssh $node "pkill -f alpine_scenario2.sh || true"
    # Deploy new script
    scp -q /tmp/alpine_scenario2.sh ${node}:/tmp/
    ssh $node "chmod +x /tmp/alpine_scenario2.sh"
done
echo "✓ Deployed to ${#ALPINE_NODES[@]} nodes"
echo ""

# Get initial state
echo "[2/4] Initial state:"
INITIAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo "  Replicas: $INITIAL_REPLICAS"
echo ""

# Calculate Pi iterations based on target CPU
# Balanced for sustained load without timeouts
case "$TARGET_CPU" in
    [0-9]|[1-6][0-9]|7[0-4])  # 0-74%: Light load
        PI_ITERATIONS=10000000
        ;;
    7[5-9]|8[0-4])  # 75-84%: Medium load
        PI_ITERATIONS=20000000
        ;;
    8[5-9])  # 85-89%: Heavy load
        PI_ITERATIONS=30000000
        ;;
    9[0-9]|100)  # 90-100%: Very heavy load
        PI_ITERATIONS=40000000
        ;;
esac

echo "=========================================="
echo "Starting Continuous Load Test"
echo "=========================================="
echo ""

echo "[3/4] Starting CONTINUOUS CPU-intensive traffic from Alpine nodes..."
echo "        Pi iterations: $PI_ITERATIONS per request"
echo "        Simulated users: $((USERS_PER_NODE * 4)) (${USERS_PER_NODE} per Alpine node)"
echo "        Duration: ${TOTAL_DURATION}s"
echo ""
echo "What to observe:"
echo "  - Initial: All $((USERS_PER_NODE * 4)) users → 1 replica → high CPU on one node"
echo "  - After scale-up: Same users → distributed across replicas → CPU split evenly"
echo "  - Continuous requests = immediate distribution visibility in Grafana"
echo "  - Each user sends non-stop requests until ${TOTAL_DURATION}s expires"
echo ""

PIDS=()
for node in "${ALPINE_NODES[@]}"; do
    ssh $node "/tmp/alpine_scenario2.sh $SERVICE_URL $TOTAL_DURATION $USERS_PER_NODE $PI_ITERATIONS" > /tmp/${node}_traffic.log 2>&1 &
    PIDS+=($!)
done

echo "✓ Continuous traffic started from 4 Alpine nodes"
echo ""

echo "📊 OPEN GRAFANA NOW TO SEE REAL-TIME DISTRIBUTION:"
echo "   → http://192.168.2.61:3000"
echo "   → Dashboard: Container Metrics"
echo ""
echo "   What you'll see:"
echo "   ✓ Initially: Single web-stress.1 with high CPU (~80%)"
echo "   ✓ After scale-up: Multiple lines (web-stress.1, .2, .3, etc.)"
echo "   ✓ CPU AUTOMATICALLY distributed across replicas"
echo "   ✓ Memory + Network also distributed"
echo "   ✓ Load balancing in action!"
echo ""

# Monitor scale-up and distribution
echo "Monitoring (${TOTAL_DURATION}s)..."
START_TIME=$(date +%s)

while true; do
    sleep 15
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    if [ $ELAPSED -ge $TOTAL_DURATION ]; then
        break
    fi

    CURRENT=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
    echo "[+${ELAPSED}s] Replicas: $CURRENT (check Grafana for CPU/MEM/NET distribution)"

    if [ "$CURRENT" -gt "$INITIAL_REPLICAS" ] && [ -z "$SCALE_UP_ANNOUNCED" ]; then
        echo ""
        echo "✓ SCALE-UP DETECTED: $INITIAL_REPLICAS → $CURRENT replicas"
        echo "  → Traffic now distributed across $CURRENT replicas"
        echo "  → Check Grafana to see CPU split evenly"
        echo ""
        SCALE_UP_ANNOUNCED=1
    fi
done

# Wait for Alpine traffic to complete
for pid in "${PIDS[@]}"; do
    wait $pid 2>/dev/null || true
done

echo ""
echo "Continuous load test complete"
echo ""

# Show final state
echo "=========================================="
echo "Test Complete"
echo "=========================================="
FINAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo ""
echo "Replica progression:"
echo "  Initial:  $INITIAL_REPLICAS"
echo "  Scaled:   $PHASE1_REPLICAS"
echo "  Final:    $FINAL_REPLICAS"
echo ""

# Show task distribution
echo "Task distribution across nodes:"
ssh master "docker service ps web-stress --filter 'desired-state=running' --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}'"
echo ""

echo "Next steps:"
echo "  1. Check Grafana to verify load was distributed evenly"
echo "  2. Wait ~4 minutes for scale-down to return to baseline"
echo "  3. Verify scale-down in Grafana metrics"
echo ""

# Cleanup
rm -f /tmp/alpine_scenario2.sh
rm -f /tmp/alpine-*_phase*.log

exit 0
