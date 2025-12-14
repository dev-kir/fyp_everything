#!/bin/bash
# Alpine Scenario 2 - Organic Request Load Test
# Strategy: Generate load through HIGH REQUEST RATE rather than resource parameters
# Each request creates small CPU/Memory/Network load → aggregate creates total load
#
# Usage:
#   ./alpine_scenario2_organic.sh [USERS] [REQUESTS_PER_SEC] [DURATION]
#
# Examples:
#   ./alpine_scenario2_organic.sh 20 10 300    # 80 users, 10 req/sec each = 800 req/sec total
#   ./alpine_scenario2_organic.sh 30 15 300    # 120 users, 15 req/sec each = 1800 req/sec total

set -e

echo "=========================================="
echo "Scenario 2: Organic Request Load Test"
echo "=========================================="
echo ""

# Configuration from command-line arguments
USERS_PER_NODE=${1:-20}         # Default: 20 users per Alpine
REQUESTS_PER_SECOND=${2:-10}    # Default: 10 requests/sec per user
TOTAL_DURATION=${3:-300}        # Default: 300 seconds

SERVICE_URL="http://192.168.2.50:8080"
ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4")
TOTAL_USERS=$((USERS_PER_NODE * ${#ALPINE_NODES[@]}))
TOTAL_REQUESTS_PER_SEC=$((TOTAL_USERS * REQUESTS_PER_SECOND))

# Calculate request delay
REQUEST_DELAY=$(echo "scale=4; 1 / $REQUESTS_PER_SECOND" | bc)

echo "Configuration:"
echo "  Users per Alpine node: $USERS_PER_NODE"
echo "  Total Alpine nodes:    ${#ALPINE_NODES[@]}"
echo "  Total simulated users: $TOTAL_USERS"
echo "  Requests per user:     ${REQUESTS_PER_SECOND}/sec"
echo "  Request delay:         ${REQUEST_DELAY}s"
echo "  Test duration:         ${TOTAL_DURATION}s"
echo ""
echo "Expected aggregate load:"
echo "  Total requests:   ${TOTAL_REQUESTS_PER_SEC} req/sec"
echo "  Network:          ~$((TOTAL_REQUESTS_PER_SEC / 10)) Mbps (from request/response traffic)"
echo "  CPU:              Variable (from request handling)"
echo "  Memory:           Variable (from concurrent connections)"
echo ""
echo "How it works:"
echo "  - Each user sends ${REQUESTS_PER_SECOND} requests/sec to /health"
echo "  - Total: ${TOTAL_REQUESTS_PER_SEC} requests/sec → high network throughput"
echo "  - Docker Swarm distributes requests across replicas"
echo "  - High request rate creates CPU + Memory + Network load organically"
echo ""

# Get initial state
echo "[1/3] Initial state:"
INITIAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo "  web-stress replicas: $INITIAL_REPLICAS"
echo ""

# Create Alpine user simulation script
cat > /tmp/alpine_organic.sh << 'EOF'
#!/bin/sh
# Simulates N users continuously making requests

SERVICE_URL="$1"
DURATION="$2"
USERS="$3"
REQ_DELAY="$4"

echo "[$HOSTNAME] Starting $USERS users for ${DURATION}s..."
echo "[$HOSTNAME] Request delay: ${REQ_DELAY}s between requests"
END_TIME=$(($(date +%s) + DURATION))

# Launch N user processes
for user_id in $(seq 1 $USERS); do
    (
        USER_REQUESTS=0
        while [ $(date +%s) -lt $END_TIME ]; do
            # Simple GET request - creates network traffic + server CPU/memory usage
            wget -q -O /dev/null --timeout=2 "$SERVICE_URL/health" 2>&1 && USER_REQUESTS=$((USER_REQUESTS + 1))

            # Sleep to control request rate
            sleep $REQ_DELAY
        done
        echo "  User $user_id: $USER_REQUESTS requests"
    ) &
done

# Wait for all users
wait
echo "[$HOSTNAME] All $USERS users completed"
EOF

# Deploy to Alpine nodes
echo "[2/3] Deploying to Alpine nodes..."
for node in "${ALPINE_NODES[@]}"; do
    # Kill any existing processes
    ssh $node "pkill -f alpine_organic.sh 2>/dev/null" || true
    sleep 1
    # Deploy new script
    scp -q /tmp/alpine_organic.sh ${node}:/tmp/
    ssh $node "chmod +x /tmp/alpine_organic.sh"
done
echo "✓ Deployed to ${#ALPINE_NODES[@]} nodes"
echo ""

# Start simulation
echo "=========================================="
echo "Starting Organic Load Simulation"
echo "=========================================="
echo ""
echo "Launching $TOTAL_USERS users across ${#ALPINE_NODES[@]} Alpine nodes..."
echo "Total request rate: ${TOTAL_REQUESTS_PER_SEC} req/sec"
echo ""
echo "📊 OPEN GRAFANA NOW:"
echo "   → http://192.168.2.61:3000"
echo "   → Dashboard: Container Metrics"
echo ""
echo "What to expect:"
echo "  T+0s:   ${TOTAL_REQUESTS_PER_SEC} req/sec → 1 replica → high load"
echo "  T+30s:  System detects high load → scale 1→2"
echo "  T+60s:  Requests distributed → ~$((TOTAL_REQUESTS_PER_SEC / 2)) req/sec per replica"
echo "  T+90s:  If still high → scale 2→3"
echo "  T+120s: Requests distributed → ~$((TOTAL_REQUESTS_PER_SEC / 3)) req/sec per replica"
echo ""

PIDS=()
for node in "${ALPINE_NODES[@]}"; do
    echo "  Starting $USERS_PER_NODE users on $node..."
    ssh $node "/tmp/alpine_organic.sh $SERVICE_URL $TOTAL_DURATION $USERS_PER_NODE $REQUEST_DELAY" > /tmp/${node}_organic.log 2>&1 &
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
        echo "✅ SCALE EVENT: $LAST_REPLICAS → $CURRENT replicas"
        echo "   → ${TOTAL_REQUESTS_PER_SEC} req/sec now distributed across $CURRENT replicas"
        echo "   → Per-replica: ~$((TOTAL_REQUESTS_PER_SEC / CURRENT)) req/sec"
        echo "   → Check Grafana for distribution visualization"
        echo ""
        LAST_REPLICAS=$CURRENT
    else
        echo "[+${ELAPSED}s] Replicas: $CURRENT | Request rate: ${TOTAL_REQUESTS_PER_SEC} req/sec | Check Grafana"
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
echo "  Initial replicas:    $INITIAL_REPLICAS"
echo "  Final replicas:      $FINAL_REPLICAS"
echo "  Total users:         $TOTAL_USERS"
echo "  Request rate:        ${TOTAL_REQUESTS_PER_SEC} req/sec"
echo "  Duration:            ${TOTAL_DURATION}s"
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
    tail -5 /tmp/${node}_organic.log 2>/dev/null || echo "  (no output)"
done

echo ""
echo "✅ Test complete!"
echo ""
echo "Next steps:"
echo "  1. Review Grafana to see load distribution across replicas"
echo "  2. Wait ~4 minutes for scale-down to return to baseline"
echo "  3. Try different request rates:"
echo "     ./alpine_scenario2_organic.sh 30 15 300    # Higher request rate"
echo "     ./alpine_scenario2_organic.sh 40 20 300    # Even higher"
echo ""

# Cleanup
rm -f /tmp/alpine_organic.sh
rm -f /tmp/alpine-*_organic.log

exit 0
