#!/bin/bash
# Alpine Pi Scenario 2 - User Simulation Load Test
# Purpose: Simulate real users to visualize autoscaling and load distribution
#
# Concept:
#   - Alpine nodes = Simulated users
#   - Each user sends continuous requests (non-stop)
#   - More users = more load → triggers scale-up
#   - Requests automatically distributed across replicas
#   - Watch distribution in Grafana in real-time
#
# Usage:
#   ./alpine_scenario2_simple.sh [USERS] [DURATION]
#
# Examples:
#   ./alpine_scenario2_simple.sh 10 300     # 10 users per Alpine node (40 total), 5 min
#   ./alpine_scenario2_simple.sh 20 600     # 20 users per Alpine node (80 total), 10 min
#   ./alpine_scenario2_simple.sh 30 300     # 30 users per Alpine node (120 total), 5 min

set -e

echo "=========================================="
echo "Scenario 2: User Simulation Load Test"
echo "=========================================="
echo ""

# Configuration
USERS_PER_NODE=${1:-10}      # Default: 10 users per Alpine node
DURATION=${2:-300}            # Default: 5 minutes
PI_ITERATIONS=5000000         # Fixed: 5M iterations per request (moderate CPU load)

SERVICE_URL="http://192.168.2.50:8080"
ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4")
TOTAL_USERS=$((USERS_PER_NODE * ${#ALPINE_NODES[@]}))

echo "Configuration:"
echo "  Users per Alpine node: $USERS_PER_NODE"
echo "  Total simulated users:  $TOTAL_USERS"
echo "  Test duration:          ${DURATION}s"
echo "  Pi iterations/request:  $PI_ITERATIONS"
echo ""
echo "Concept:"
echo "  Each 'user' = continuous request loop"
echo "  More users = more concurrent load"
echo "  System will scale based on actual request load"
echo ""

# Create Alpine user simulation script
cat > /tmp/alpine_users.sh << 'EOF'
#!/bin/sh
# Simulates N users sending continuous requests

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
            wget -q -O /dev/null "$SERVICE_URL/compute/pi?iterations=$ITERATIONS" 2>&1
            USER_REQUESTS=$((USER_REQUESTS + 1))

            # Small delay to simulate human user (adjust for load)
            sleep 0.1
        done
        echo "  User $user_id completed $USER_REQUESTS requests"
    ) &
done

# Wait for all users to complete
wait

echo "[$HOSTNAME] All $USERS users completed"
EOF

# Deploy to Alpine nodes
echo "[1/3] Deploying user simulation script to Alpine nodes..."
for node in "${ALPINE_NODES[@]}"; do
    scp -q /tmp/alpine_users.sh ${node}:/tmp/
    ssh $node "chmod +x /tmp/alpine_users.sh"
done
echo "✓ Deployed to ${#ALPINE_NODES[@]} Alpine nodes"
echo ""

# Get initial state
echo "[2/3] Initial state:"
INITIAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo "  web-stress replicas: $INITIAL_REPLICAS"
echo ""

# Start user simulation
echo "=========================================="
echo "Starting User Simulation"
echo "=========================================="
echo ""
echo "Launching $TOTAL_USERS simulated users across 4 Alpine nodes..."
echo "Each user will send continuous Pi calculation requests"
echo ""
echo "📊 OPEN GRAFANA NOW:"
echo "   → http://192.168.2.61:3000"
echo "   → Dashboard: Container Metrics"
echo ""
echo "What to watch:"
echo "  T+0s:   1 replica handling all $TOTAL_USERS users → CPU/MEM high"
echo "  T+30s:  System detects overload → scale 1→2"
echo "  T+60s:  Requests AUTO-DISTRIBUTED to 2 replicas → CPU/MEM split ~50/50"
echo "  T+90s:  If still overloaded → scale 2→3"
echo "  T+120s: Requests distributed to 3 replicas → CPU/MEM split ~33/33/33"
echo ""
echo "✓ You'll see LIVE distribution in Grafana as requests flow!"
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

# Monitor in real-time
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
        echo "   → Each replica handling ~$((TOTAL_USERS / CURRENT)) concurrent requests"
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
echo "  3. Run again with different user counts to test scaling:"
echo "     - ./alpine_scenario2_simple.sh 20 300  (more load)"
echo "     - ./alpine_scenario2_simple.sh 30 300  (even more load)"
echo ""

# Cleanup
rm -f /tmp/alpine_users.sh
rm -f /tmp/alpine-*_users.log

exit 0
