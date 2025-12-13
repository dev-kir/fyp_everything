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

# Create Alpine load script with CPU-intensive distributed traffic
cat > /tmp/alpine_scenario2.sh << 'EOF'
#!/bin/sh
# Generates CPU-intensive distributed HTTP traffic to trigger load balancing
# Each request causes CPU load on the container that handles it
SERVICE_URL="$1"
DURATION="$2"
CONCURRENT="$3"
ITERATIONS="$4"

echo "[$HOSTNAME] Starting CPU-intensive distributed traffic..."
END_TIME=$(($(date +%s) + DURATION))
COUNT=0

while [ $(date +%s) -lt $END_TIME ]; do
    # Launch concurrent CPU-intensive requests in background
    for i in $(seq 1 $CONCURRENT); do
        (
            # CPU-intensive Pi calculation - Docker Swarm distributes to replicas
            # Each replica that handles request will show CPU spike
            wget -q -O /dev/null "$SERVICE_URL/compute/pi?iterations=$ITERATIONS" 2>&1
        ) &
    done

    # Wait for batch
    wait
    COUNT=$((COUNT + CONCURRENT))

    # Brief pause between batches
    sleep 0.1
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
# Calculate Pi iterations based on target CPU
# Higher iterations = more CPU load per request
# Estimate: 10M iterations ≈ 20-30% CPU on x86_64 for 1 second
case "$TARGET_CPU" in
    [0-9]|[1-6][0-9]|7[0-4])  # 0-74%: Light load
        PI_ITERATIONS=5000000
        ;;
    7[5-9]|8[0-4])  # 75-84%: Medium load
        PI_ITERATIONS=10000000
        ;;
    8[5-9])  # 85-89%: Heavy load
        PI_ITERATIONS=15000000
        ;;
    9[0-9]|100)  # 90-100%: Very heavy load
        PI_ITERATIONS=20000000
        ;;
esac

echo "Step 1: Triggering memory+network stress on replicas..."
echo "        Memory=${TARGET_MEMORY}MB, Network=${TARGET_NETWORK}Mbps, Ramp=${RAMP_TIME}s"
echo ""

# Trigger memory + network stress (NOT CPU - that comes from Alpine traffic)
echo "  Sending memory+network stress to replicas..."
for i in $(seq 1 10); do
    curl -s "$SERVICE_URL/stress/memory?target=$TARGET_MEMORY&duration=$PHASE1_DURATION&ramp=$RAMP_TIME" > /dev/null &
    curl -s "$SERVICE_URL/stress/network?bandwidth=$TARGET_NETWORK&duration=$PHASE1_DURATION&ramp=$RAMP_TIME" > /dev/null &
    sleep 0.5
done
wait

echo "✓ Memory+Network stress activated (will ramp up over ${RAMP_TIME}s)"
echo ""

echo "Step 2: Generating CPU-intensive traffic from ${#ALPINE_NODES[@}} Alpine nodes..."
echo "        Pi iterations: $PI_ITERATIONS per request"
echo "        This traffic will be DISTRIBUTED across replicas → CPU split evenly"
echo "Expected: CPU+MEM+NET high on all replicas → Scenario 2 scale-up"
echo ""

PIDS=()
for node in "${ALPINE_NODES[@]}"; do
    ssh $node "/tmp/alpine_scenario2.sh $SERVICE_URL $PHASE1_DURATION $CONCURRENT $PI_ITERATIONS" > /tmp/${node}_phase1.log 2>&1 &
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
PHASE2_MEMORY=$((TARGET_MEMORY * 70 / 100))
PHASE2_NETWORK=$((TARGET_NETWORK * 70 / 100))
PHASE2_RAMP=$((RAMP_TIME / 2))
PHASE2_PI_ITERATIONS=$((PI_ITERATIONS * 70 / 100))

echo "Step 1: Activating moderate memory+network stress to maintain scale..."
echo "        Memory=${PHASE2_MEMORY}MB, Network=${PHASE2_NETWORK}Mbps, Ramp=${PHASE2_RAMP}s"
echo ""

# Moderate memory + network stress
echo "  Sending moderate memory+network stress to $PHASE1_REPLICAS replicas..."
for i in $(seq 1 $((PHASE1_REPLICAS * 2))); do
    curl -s "$SERVICE_URL/stress/memory?target=$PHASE2_MEMORY&duration=$PHASE2_DURATION&ramp=$PHASE2_RAMP" > /dev/null &
    curl -s "$SERVICE_URL/stress/network?bandwidth=$PHASE2_NETWORK&duration=$PHASE2_DURATION&ramp=$PHASE2_RAMP" > /dev/null &
    sleep 0.3
done
wait

echo "✓ Moderate memory+network stress activated (70% of Phase 1 load)"
echo ""

echo "Step 2: Generating moderate CPU-intensive traffic from Alpine nodes..."
echo "        Pi iterations: $PHASE2_PI_ITERATIONS per request (70% of Phase 1)"
echo "        Traffic will be load-balanced across $PHASE1_REPLICAS replicas"
echo ""
echo "📊 OPEN GRAFANA NOW TO SEE DISTRIBUTION:"
echo "   → http://192.168.2.61:3000"
echo "   → Dashboard: Container Metrics"
echo ""
echo "   What you'll see in Grafana:"
echo "   ✓ Multiple lines: web-stress.1, web-stress.2, web-stress.3, etc."
echo "   ✓ Each replica on different worker node"
echo "   ✓ CPU EVENLY DISTRIBUTED across $PHASE1_REPLICAS replicas (~${TARGET_CPU}%/$PHASE1_REPLICAS each)"
echo "   ✓ Memory split across replicas"
echo "   ✓ Network traffic distributed to all replicas"
echo "   ✓ Docker Swarm load balancing in action!"
echo ""

# Sustained CPU-intensive traffic to show distribution
SUSTAINED_CONCURRENT=12  # Higher to ensure continuous load

PIDS=()
for node in "${ALPINE_NODES[@]}"; do
    ssh $node "/tmp/alpine_scenario2.sh $SERVICE_URL $PHASE2_DURATION $SUSTAINED_CONCURRENT $PHASE2_PI_ITERATIONS" > /tmp/${node}_phase2.log 2>&1 &
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
