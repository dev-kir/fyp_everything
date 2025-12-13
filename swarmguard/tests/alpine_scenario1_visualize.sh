#!/bin/bash
# Alpine Pi Scenario 1 Test - Visualize Proactive Migration
# Purpose: Trigger migration and observe container move to different node with zero downtime
#
# Usage:
#   ./alpine_scenario1_visualize.sh [CPU] [MEMORY] [RAMP]
#
# Examples:
#   ./alpine_scenario1_visualize.sh                # Default: CPU=80%, MEM=900MB, RAMP=30s
#   ./alpine_scenario1_visualize.sh 85 1200 60     # Heavier load with 60s ramp

set -e

echo "=========================================="
echo "Scenario 1: Proactive Migration Visualization"
echo "=========================================="
echo ""

# Configuration from command-line arguments
TARGET_CPU=${1:-80}        # Default 80%
TARGET_MEMORY=${2:-900}    # Default 900MB
RAMP_TIME=${3:-30}         # Default 30s

SERVICE_URL="http://192.168.2.50:8080"
ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4")
STRESS_DURATION=180        # 3 min stress
SUSTAINED_DURATION=120     # 2 min sustained traffic after migration
CONCURRENT=5               # Moderate concurrency

echo "Stress Configuration:"
echo "  CPU Target:     ${TARGET_CPU}%"
echo "  Memory Target:  ${TARGET_MEMORY}MB"
echo "  Network Target: LOW (triggers migration, not scaling)"
echo "  Ramp Time:      ${RAMP_TIME}s"
echo ""

echo "Test phases:"
echo "  Phase 1: ${STRESS_DURATION}s - Trigger migration (high CPU/MEM, low NET)"
echo "  Phase 2: ${SUSTAINED_DURATION}s - Verify zero-downtime with Alpine traffic"
echo ""

# Create Alpine traffic script
cat > /tmp/alpine_scenario1.sh << 'EOF'
#!/bin/sh
# Generates continuous HTTP traffic to test zero-downtime migration
SERVICE_URL="$1"
DURATION="$2"
CONCURRENT="$3"

echo "[$HOSTNAME] Starting continuous traffic (zero-downtime test)..."
END_TIME=$(($(date +%s) + DURATION))
SUCCESS=0
FAILED=0

while [ $(date +%s) -lt $END_TIME ]; do
    # Launch concurrent requests
    for i in $(seq 1 $CONCURRENT); do
        (
            if wget -q -O /dev/null "$SERVICE_URL/health" 2>&1; then
                SUCCESS=$((SUCCESS + 1))
            else
                FAILED=$((FAILED + 1))
                echo "[$HOSTNAME] REQUEST FAILED at $(date +%H:%M:%S)"
            fi
        ) &
    done

    wait
    sleep 1
done

TOTAL=$((SUCCESS + FAILED))
if [ $TOTAL -gt 0 ]; then
    UPTIME=$(echo "scale=2; $SUCCESS * 100 / $TOTAL" | bc)
    echo "[$HOSTNAME] Success: $SUCCESS/$TOTAL (${UPTIME}% uptime)"
else
    echo "[$HOSTNAME] No requests completed"
fi
EOF

# Deploy to Alpine nodes
echo "[1/5] Deploying traffic script to Alpine nodes..."
for node in "${ALPINE_NODES[@]}"; do
    scp -q /tmp/alpine_scenario1.sh ${node}:/tmp/
    ssh $node "chmod +x /tmp/alpine_scenario1.sh"
done
echo "✓ Deployed"
echo ""

# Get initial state
echo "[2/5] Initial state:"
INITIAL_NODE=$(ssh master "docker service ps web-stress --filter 'desired-state=running' --format '{{.Node}}' | head -1")
echo "  web-stress running on: $INITIAL_NODE"
echo ""

# Phase 1: Trigger migration
echo "=========================================="
echo "PHASE 1: Trigger Migration (${STRESS_DURATION}s)"
echo "=========================================="
echo ""

echo "Step 1: Starting continuous traffic from Alpine nodes..."
echo "        This traffic will continue during migration to verify zero-downtime"
echo ""

# Start Alpine traffic in background
PIDS=()
for node in "${ALPINE_NODES[@]}"; do
    ssh $node "/tmp/alpine_scenario1.sh $SERVICE_URL $((STRESS_DURATION + SUSTAINED_DURATION)) $CONCURRENT" > /tmp/${node}_traffic.log 2>&1 &
    PIDS+=($!)
done
sleep 2
echo "✓ Alpine traffic started from ${#ALPINE_NODES[@]} nodes"
echo ""

echo "Step 2: Triggering Scenario 1 stress (HIGH CPU/MEM, LOW NET)..."
echo "        CPU=${TARGET_CPU}%, Memory=${TARGET_MEMORY}MB, Network=LOW, Ramp=${RAMP_TIME}s"
echo ""

# Trigger Scenario 1: High CPU/MEM, NO network stress (triggers migration, not scaling)
curl -s "$SERVICE_URL/stress/cpu?target=$TARGET_CPU&duration=$STRESS_DURATION&ramp=$RAMP_TIME" > /dev/null &
sleep 1
curl -s "$SERVICE_URL/stress/memory?target=$TARGET_MEMORY&duration=$STRESS_DURATION&ramp=$RAMP_TIME" > /dev/null &

echo "✓ Scenario 1 stress activated (CPU + MEM only, network LOW)"
echo "  Expected: Proactive migration to different node"
echo ""

# Monitor for migration
echo "[3/5] Monitoring for migration..."
echo ""
MIGRATION_DETECTED=0

for i in $(seq 1 18); do
    sleep 10
    CURRENT_NODE=$(ssh master "docker service ps web-stress --filter 'desired-state=running' --format '{{.Node}}' | head -1")
    echo "[+${i}0s] Container on: $CURRENT_NODE"

    if [ "$CURRENT_NODE" != "$INITIAL_NODE" ]; then
        echo ""
        echo "✓ MIGRATION DETECTED: $INITIAL_NODE → $CURRENT_NODE"
        MIGRATION_DETECTED=1

        # Check for failed requests during migration
        echo ""
        echo "Checking Alpine traffic logs for downtime..."
        DOWNTIME_DETECTED=0
        for node in "${ALPINE_NODES[@]}"; do
            if grep -q "FAILED" /tmp/${node}_traffic.log 2>/dev/null; then
                echo "  ⚠️  $node: Detected failed requests"
                DOWNTIME_DETECTED=1
            else
                echo "  ✓ $node: No failed requests"
            fi
        done

        if [ $DOWNTIME_DETECTED -eq 0 ]; then
            echo ""
            echo "✅ ZERO-DOWNTIME CONFIRMED: No failed requests during migration"
        else
            echo ""
            echo "⚠️  DOWNTIME DETECTED: Some requests failed during migration"
        fi

        break
    fi
done

if [ $MIGRATION_DETECTED -eq 0 ]; then
    echo ""
    echo "⚠️  Migration not detected within ${STRESS_DURATION}s"
    echo "   Check recovery-manager logs for issues"
fi

echo ""

# Phase 2: Sustained traffic
echo "=========================================="
echo "PHASE 2: Sustained Traffic (${SUSTAINED_DURATION}s)"
echo "=========================================="
echo ""
echo "Continuing Alpine traffic to verify new node stability..."
echo "Alpine traffic will continue for ${SUSTAINED_DURATION}s more"
echo ""

echo "📊 OPEN GRAFANA NOW:"
echo "   → http://192.168.2.61:3000"
echo "   → Dashboard: Container Metrics"
echo ""
echo "   What you'll see:"
echo "   ✓ Container metrics switching from $INITIAL_NODE to $CURRENT_NODE"
echo "   ✓ No gaps in metrics (zero-downtime proof)"
echo "   ✓ Continuous traffic handling"
echo ""

# Monitor stability
echo "[4/5] Monitoring stability on new node..."
for i in $(seq 1 12); do
    sleep 10
    CURRENT_NODE=$(ssh master "docker service ps web-stress --filter 'desired-state=running' --format '{{.Node}}' | head -1")
    echo "[+${i}0s] Container stable on: $CURRENT_NODE"
done

echo ""

# Stop stress test
echo "Stopping stress test..."
curl -s "$SERVICE_URL/stress/stop" > /dev/null
echo "✓ Stress stopped"
echo ""

# Wait for Alpine traffic to complete
echo "Waiting for Alpine traffic to complete..."
for pid in "${PIDS[@]}"; do
    wait $pid 2>/dev/null || true
done
echo "✓ Alpine traffic completed"
echo ""

# Show results
echo "=========================================="
echo "[5/5] Test Complete"
echo "=========================================="
echo ""

echo "Migration result:"
echo "  Initial node: $INITIAL_NODE"
echo "  Final node:   $CURRENT_NODE"
echo ""

# Show uptime from each Alpine node
echo "Zero-downtime verification (Alpine traffic results):"
for node in "${ALPINE_NODES[@]}"; do
    echo ""
    echo "[$node]"
    tail -2 /tmp/${node}_traffic.log
done

echo ""
echo "Task history:"
ssh master "docker service ps web-stress --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}\t{{.Error}}'"

echo ""
echo "✅ Scenario 1 test complete"
echo ""
echo "Next steps:"
echo "  1. Review Grafana for continuous metrics"
echo "  2. Check recovery-manager logs for MTTR"
echo "  3. Verify 100% uptime in Alpine results above"
echo ""

# Cleanup
rm -f /tmp/alpine_scenario1.sh
rm -f /tmp/alpine-*_traffic.log

exit 0
