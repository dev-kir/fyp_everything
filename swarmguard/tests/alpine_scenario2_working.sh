#!/bin/bash
# Alpine Scenario 2 - Working Test (Uses existing endpoints)
# Strategy: High CPU + High Memory + High Network to trigger Scenario 2
#
# Usage:
#   ./alpine_scenario2_working.sh [DURATION]
#
# Example:
#   ./alpine_scenario2_working.sh 300

set -e

echo "=========================================="
echo "Scenario 2: High Load Test (Working)"
echo "=========================================="
echo ""

DURATION=${1:-300}
SERVICE_URL="http://192.168.2.50:8080"
ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4")

echo "Configuration:"
echo "  Duration: ${DURATION}s"
echo "  Strategy: Trigger high CPU + Memory + Network simultaneously"
echo ""

# Get initial state
echo "[1/3] Initial state:"
INITIAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo "  web-stress replicas: $INITIAL_REPLICAS"
echo ""

# Create Alpine stress script
cat > /tmp/alpine_scenario2.sh << 'EOF'
#!/bin/sh
SERVICE_URL="$1"
DURATION="$2"

echo "[$HOSTNAME] Generating high load for ${DURATION}s..."

# Strategy: Continuous download requests create REAL network traffic
# Server does CPU work + holds memory for each request
END_TIME=$(($(date +%s) + DURATION))
REQUESTS=0

while [ $(date +%s) -lt $END_TIME ]; do
    # Download 10MB with CPU work - creates real network + CPU + memory load
    wget -q -O /dev/null --timeout=30 \
        "$SERVICE_URL/download/data?size_mb=10&cpu_work=200000" \
        2>&1 && REQUESTS=$((REQUESTS + 1))

    # Small delay to prevent overwhelming
    sleep 0.5
done

echo "[$HOSTNAME] Completed $REQUESTS requests"
EOF

# Deploy to Alpine nodes
echo "[2/3] Deploying to Alpine nodes..."
for node in "${ALPINE_NODES[@]}"; do
    ssh $node "pkill -f alpine_scenario2.sh 2>/dev/null" || true
    scp -q /tmp/alpine_scenario2.sh ${node}:/tmp/
    ssh $node "chmod +x /tmp/alpine_scenario2.sh"
done
echo "✓ Deployed to ${#ALPINE_NODES[@]} nodes"
echo ""

# Start load generation
echo "=========================================="
echo "Starting High Load Test"
echo "=========================================="
echo ""
echo "📊 OPEN GRAFANA NOW:"
echo "   → http://192.168.2.61:3000"
echo "   → Dashboard: Container Metrics"
echo ""
echo "Expected behavior:"
echo "  - All 4 Alpine nodes continuously download 10MB files"
echo "  - Each download triggers CPU work (200k iterations)"
echo "  - Creates REAL network traffic visible in Grafana"
echo "  - High CPU + Memory + Network → triggers Scenario 2"
echo "  - System scales 1→2→3 replicas as load increases"
echo ""

PIDS=()
for node in "${ALPINE_NODES[@]}"; do
    echo "  Starting load on $node..."
    ssh $node "/tmp/alpine_scenario2.sh $SERVICE_URL $DURATION" > /tmp/${node}_scenario2.log 2>&1 &
    PIDS+=($!)
done

echo ""
echo "✓ Load generation active on ${#ALPINE_NODES[@]} nodes"
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
        echo "✅ SCALE EVENT: $LAST_REPLICAS → $CURRENT replicas"
        echo "   → Check Grafana to see load distribution"
        echo ""
        LAST_REPLICAS=$CURRENT
    else
        echo "[+${ELAPSED}s] Replicas: $CURRENT | Check Grafana for CPU/MEM/NET"
    fi
done

echo ""
echo "Waiting for Alpine nodes to complete..."
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
echo "  Initial replicas: $INITIAL_REPLICAS"
echo "  Final replicas:   $FINAL_REPLICAS"
echo "  Duration:         ${DURATION}s"
echo ""

ssh master "docker service ps web-stress --filter 'desired-state=running' --format 'table {{.Name}}\t{{.Node}}'"
echo ""

# Cleanup
rm -f /tmp/alpine_scenario2.sh
rm -f /tmp/alpine-*_scenario2.log

exit 0
