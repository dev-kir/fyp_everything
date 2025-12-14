#!/bin/bash
# Alpine Scenario 2 - Combined Stress + Continuous Traffic
# Strategy: Internal stress (CPU+MEM) + External continuous requests for distribution

set -e

echo "=========================================="
echo "Scenario 2: Combined Stress Test"
echo "=========================================="
echo ""

# Configuration
SERVICE_URL="http://192.168.2.50:8080"
ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4")
DURATION=300  # 5 minutes

TARGET_CPU=85
TARGET_MEMORY=800
TARGET_NETWORK=70
RAMP_TIME=10
USERS_PER_NODE=20

echo "Configuration:"
echo "  Duration: ${DURATION}s"
echo "  CPU Target: ${TARGET_CPU}%"
echo "  Memory Target: ${TARGET_MEMORY}MB"
echo "  Network Target: ${TARGET_NETWORK}Mbps"
echo "  Simulated Users: $((USERS_PER_NODE * 4))"
echo ""

# Get initial state
echo "[1/3] Initial state:"
INITIAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo "  Replicas: $INITIAL_REPLICAS"
echo ""

# Step 1: Trigger INTERNAL stress (CPU + MEM + NET) - this runs INSIDE the container
echo "[2/3] Triggering INTERNAL stress on containers..."
echo "  CPU=${TARGET_CPU}%, MEM=${TARGET_MEMORY}MB, NET=${TARGET_NETWORK}Mbps"

# Send stress requests to trigger internal load
for i in $(seq 1 5); do
    curl -s "$SERVICE_URL/stress/cpu?target=$TARGET_CPU&duration=$DURATION&ramp=$RAMP_TIME" > /dev/null &
    curl -s "$SERVICE_URL/stress/memory?target=$TARGET_MEMORY&duration=$DURATION&ramp=$RAMP_TIME" > /dev/null &
    curl -s "$SERVICE_URL/stress/network?bandwidth=$TARGET_NETWORK&duration=$DURATION&ramp=$RAMP_TIME" > /dev/null &
done

echo "✓ Internal stress activated"
echo ""

# Step 2: Generate CONTINUOUS EXTERNAL traffic for distribution visibility
echo "[3/3] Starting CONTINUOUS external traffic from Alpine nodes..."
echo "  This ensures distribution is visible after scale-up"
echo ""

# Create simple health-check loop script
cat > /tmp/alpine_health_loop.sh << 'EOF'
#!/bin/sh
SERVICE_URL="$1"
DURATION="$2"
REQUESTS_PER_SEC="$3"

END_TIME=$(($(date +%s) + DURATION))
COUNT=0

while [ $(date +%s) -lt $END_TIME ]; do
    # Simple health check - Docker Swarm distributes these
    wget -q -O /dev/null --timeout=1 "$SERVICE_URL/health" 2>&1 && COUNT=$((COUNT + 1))

    # Small sleep for rate limiting (10 req/sec)
    sleep 0.1
done

echo "[$HOSTNAME] Completed $COUNT requests"
EOF

# Deploy and run on Alpine nodes
PIDS=()
for node in "${ALPINE_NODES[@]}"; do
    scp -q /tmp/alpine_health_loop.sh ${node}:/tmp/
    ssh $node "chmod +x /tmp/alpine_health_loop.sh"
    ssh $node "/tmp/alpine_health_loop.sh $SERVICE_URL $DURATION 10" > /tmp/${node}_health.log 2>&1 &
    PIDS+=($!)
done

echo "✓ Continuous health-check traffic started from ${#ALPINE_NODES[@]} Alpine nodes"
echo "  → This traffic will distribute across replicas after scale-up"
echo ""

# Monitor
echo "📊 OPEN GRAFANA NOW:"
echo "   → http://192.168.2.61:3000"
echo ""
echo "What to watch:"
echo "  1. Internal stress triggers scale-up (CPU/MEM/NET high)"
echo "  2. System scales 1→2→3 replicas"
echo "  3. Continuous health traffic distributes across all replicas"
echo "  4. See load spread evenly in Grafana"
echo ""

echo "Monitoring (${DURATION}s)..."
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
    echo "[+${ELAPSED}s] Replicas: $CURRENT"

    if [ "$CURRENT" != "$LAST_REPLICAS" ]; then
        echo ""
        echo "✅ SCALE EVENT: $LAST_REPLICAS → $CURRENT replicas"
        echo "   → External traffic now distributed across $CURRENT replicas"
        echo ""
        LAST_REPLICAS=$CURRENT
    fi
done

# Wait for Alpine traffic to complete
for pid in "${PIDS[@]}"; do
    wait $pid 2>/dev/null || true
done

# Show results
echo ""
echo "=========================================="
echo "Test Complete"
echo "=========================================="
FINAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")

echo "Replica progression: $INITIAL_REPLICAS → $FINAL_REPLICAS"
echo ""
echo "External traffic results:"
for node in "${ALPINE_NODES[@]}"; do
    echo "  [$node]"
    tail -1 /tmp/${node}_health.log 2>/dev/null || echo "    (no output)"
done

# Cleanup
rm -f /tmp/alpine_health_loop.sh
rm -f /tmp/alpine-*_health.log

echo ""
echo "✅ Done! Check Grafana to see load distribution across replicas"
echo ""

exit 0
