#!/bin/bash
# Alpine Pi Scenario 2 Load Test - Visualize Resource Distribution
# Purpose: Generate traffic to trigger scale-up, then observe load distribution in Grafana
# Optimized for: Seeing CPU/MEM/NET split across multiple replicas
#
# Usage:
#   ./alpine_scenario2_visualize.sh [CPU] [MEMORY] [NETWORK] [RAMP]
#
# Examples:
#   ./alpine_scenario2_visualize.sh                    # Default: CPU=85%, MEM=800MB, NET=70Mbps, RAMP=10s
#   ./alpine_scenario2_visualize.sh 90 1200 80 60      # Heavy: CPU=90%, MEM=1.2GB, NET=80Mbps, RAMP=60s
#   ./alpine_scenario2_visualize.sh 95 1500 85 60      # Very heavy: More replicas

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

SERVICE_URL="http://192.168.2.50:8080"
ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4")
PHASE1_DURATION=120  # 2 min to trigger scale-up
PHASE2_DURATION=180  # 3 min to observe distribution
CONCURRENT=10        # Higher concurrency for CPU+NET load

echo "Stress Configuration:"
echo "  CPU Target:     ${TARGET_CPU}%"
echo "  Memory Target:  ${TARGET_MEMORY}MB"
echo "  Network Target: ${TARGET_NETWORK}Mbps"
echo "  Ramp Time:      ${RAMP_TIME}s"
echo ""

echo "Test phases:"
echo "  Phase 1: ${PHASE1_DURATION}s - Trigger scale-up (heavy load)"
echo "  Phase 2: ${PHASE2_DURATION}s - Observe distribution (sustained load)"
echo ""
echo "Alpine nodes: ${#ALPINE_NODES[@]} (${ALPINE_NODES[@]})"
echo "Concurrent per node: $CONCURRENT"
echo ""

# Create Alpine load script with distributed HTTP requests
cat > /tmp/alpine_scenario2.sh << 'EOF'
#!/bin/sh
# Generates distributed HTTP traffic to trigger load balancing
SERVICE_URL="$1"
DURATION="$2"
CONCURRENT="$3"

echo "[$HOSTNAME] Starting distributed traffic..."
END_TIME=$(($(date +%s) + DURATION))
COUNT=0

while [ $(date +%s) -lt $END_TIME ]; do
    # Launch concurrent requests in background
    for i in $(seq 1 $CONCURRENT); do
        (
            # Simple HTTP requests to trigger load balancing
            # Docker Swarm will distribute across replicas
            wget -q -O /dev/null "$SERVICE_URL/compute/pi?iterations=1000000" 2>&1
        ) &
    done

    # Wait for batch
    wait
    COUNT=$((COUNT + CONCURRENT))

    # Brief pause to sustain load without overwhelming Alpine Pi
    sleep 0.2
done

echo "[$HOSTNAME] Completed $COUNT requests"
EOF

# Deploy to Alpine nodes
echo "[1/4] Deploying to Alpine nodes..."
for node in "${ALPINE_NODES[@]}"; do
    scp -q /tmp/alpine_scenario2.sh ${node}:/tmp/
    ssh $node "chmod +x /tmp/alpine_scenario2.sh"
done
echo "✓ Deployed"
echo ""

# Get initial state
echo "[2/4] Initial state:"
INITIAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo "  Replicas: $INITIAL_REPLICAS"
echo ""

# Phase 1: Heavy load to trigger scale-up
echo "=========================================="
echo "PHASE 1: Trigger Scale-Up (${PHASE1_DURATION}s)"
echo "=========================================="
echo ""
echo "Step 1: Triggering built-in stress test on container..."
echo "        CPU=${TARGET_CPU}%, Memory=${TARGET_MEMORY}MB, Network=${TARGET_NETWORK}Mbps, Ramp=${RAMP_TIME}s"
curl -s "$SERVICE_URL/stress/combined?cpu=$TARGET_CPU&memory=$TARGET_MEMORY&network=$TARGET_NETWORK&duration=$PHASE1_DURATION&ramp=$RAMP_TIME" > /dev/null
echo "✓ Self-stress activated (will ramp up over ${RAMP_TIME}s)"
echo ""

echo "Step 2: Generating distributed traffic from ${#ALPINE_NODES[@]} Alpine nodes..."
echo "        This traffic will be load-balanced across replicas after scale-up"
echo "Expected: CPU+MEM+NET high → Scenario 2 scale-up"
echo ""

PIDS=()
for node in "${ALPINE_NODES[@]}"; do
    ssh $node "/tmp/alpine_scenario2.sh $SERVICE_URL $PHASE1_DURATION $CONCURRENT" > /tmp/${node}_phase1.log 2>&1 &
    PIDS+=($!)
done

# Monitor scale-up
echo "Monitoring for scale-up..."
for i in $(seq 1 12); do
    sleep 10
    CURRENT=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
    echo "[+${i}0s] Replicas: $CURRENT"

    if [ "$CURRENT" -gt "$INITIAL_REPLICAS" ]; then
        echo ""
        echo "✓ SCALE-UP DETECTED: $INITIAL_REPLICAS → $CURRENT replicas"
        SCALED_UP=1
        break
    fi
done

# Wait for Phase 1 to complete
for pid in "${PIDS[@]}"; do
    wait $pid 2>/dev/null || true
done

echo ""
echo "Phase 1 complete"
PHASE1_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo "  Current replicas: $PHASE1_REPLICAS"
echo ""

# Phase 2: Sustained load to observe distribution
echo "=========================================="
echo "PHASE 2: Observe Load Distribution (${PHASE2_DURATION}s)"
echo "=========================================="
echo ""
# Phase 2: Reduce stress to 70% of Phase 1 targets to maintain scale without triggering more scale-ups
PHASE2_CPU=$((TARGET_CPU * 70 / 100))
PHASE2_MEMORY=$((TARGET_MEMORY * 70 / 100))
PHASE2_NETWORK=$((TARGET_NETWORK * 70 / 100))
PHASE2_RAMP=$((RAMP_TIME / 2))

echo "Step 1: Activating moderate self-stress to maintain scale..."
echo "        CPU=${PHASE2_CPU}%, Memory=${PHASE2_MEMORY}MB, Network=${PHASE2_NETWORK}Mbps, Ramp=${PHASE2_RAMP}s"
curl -s "$SERVICE_URL/stress/combined?cpu=$PHASE2_CPU&memory=$PHASE2_MEMORY&network=$PHASE2_NETWORK&duration=$PHASE2_DURATION&ramp=$PHASE2_RAMP" > /dev/null
echo "✓ Moderate stress activated (70% of Phase 1 load)"
echo ""

echo "Step 2: Generating distributed traffic from Alpine nodes..."
echo "        Traffic will be load-balanced across $PHASE1_REPLICAS replicas"
echo ""
echo "📊 OPEN GRAFANA NOW TO SEE DISTRIBUTION:"
echo "   → http://192.168.2.61:3000"
echo "   → Dashboard: Container Metrics"
echo ""
echo "   What you'll see in Grafana:"
echo "   ✓ Multiple lines: web-stress.1, web-stress.2, web-stress.3, etc."
echo "   ✓ Each replica on different worker node (worker-1, worker-2, worker-3, worker-4)"
echo "   ✓ CPU/Memory split across $PHASE1_REPLICAS replicas"
echo "   ✓ Network traffic from Alpine distributed to all replicas"
echo "   ✓ Docker Swarm load balancing in action!"
echo ""

# Sustained traffic to show distribution
SUSTAINED_CONCURRENT=8

PIDS=()
for node in "${ALPINE_NODES[@]}"; do
    ssh $node "/tmp/alpine_scenario2.sh $SERVICE_URL $PHASE2_DURATION $SUSTAINED_CONCURRENT" > /tmp/${node}_phase2.log 2>&1 &
    PIDS+=($!)
done

# Monitor distribution
echo "Monitoring load distribution..."
for i in $(seq 1 18); do
    sleep 10
    CURRENT=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
    echo "[+${i}0s] Replicas: $CURRENT (check Grafana for distribution)"
done

# Wait for Phase 2 to complete
for pid in "${PIDS[@]}"; do
    wait $pid 2>/dev/null || true
done

echo ""
echo "Phase 2 complete"
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
