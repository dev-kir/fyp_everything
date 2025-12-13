#!/bin/bash
# Alpine Pi Scenario 2 Load Test - Visualize Resource Distribution
# Purpose: Generate traffic to trigger scale-up, then observe load distribution in Grafana
# Optimized for: Seeing CPU/MEM/NET split across multiple replicas

set -e

echo "=========================================="
echo "Scenario 2: Load Distribution Visualization"
echo "=========================================="
echo ""

# Configuration
SERVICE_URL="http://192.168.2.50:8080"
ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4")
PHASE1_DURATION=120  # 2 min to trigger scale-up
PHASE2_DURATION=180  # 3 min to observe distribution
CONCURRENT=10        # Higher concurrency for CPU+NET load

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
echo "        CPU=85%, Memory=800MB, Network=70Mbps"
curl -s "$SERVICE_URL/stress/combined?cpu=85&memory=800&network=70&duration=$PHASE1_DURATION&ramp=10" > /dev/null
echo "✓ Self-stress activated"
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
echo "Step 1: Activating moderate self-stress to maintain scale..."
echo "        CPU=60%, Memory=500MB, Network=50Mbps"
curl -s "$SERVICE_URL/stress/combined?cpu=60&memory=500&network=50&duration=$PHASE2_DURATION&ramp=5" > /dev/null
echo "✓ Moderate stress activated"
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
