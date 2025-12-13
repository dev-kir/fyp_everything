#!/bin/bash
# SwarmGuard Distributed Load Test using Alpine Pi Cluster
# Purpose: Simulate real user traffic to visualize load distribution across replicas in Grafana
# Runs on: Control macOS machine (orchestrates Alpine Pi 1-4)

set -e

echo "=========================================="
echo "Alpine Pi Distributed Load Test"
echo "=========================================="
echo ""

# Configuration
SERVICE_URL="http://192.168.2.50:8080"
ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4")
REQUESTS_PER_NODE=100
CONCURRENT_REQUESTS=5
DURATION_SECONDS=300  # 5 minutes of sustained traffic

echo "Service: $SERVICE_URL"
echo "Alpine nodes: ${ALPINE_NODES[@]}"
echo "Requests per node: $REQUESTS_PER_NODE"
echo "Concurrent: $CONCURRENT_REQUESTS"
echo "Duration: ${DURATION_SECONDS}s"
echo ""

# Check service is up
echo "[1/5] Checking web-stress service..."
REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}'")
echo "✓ web-stress service: $REPLICAS"
echo ""

# Create load test script for Alpine nodes
echo "[2/5] Creating load generator script..."
cat > /tmp/alpine_load_worker.sh << 'EOF'
#!/bin/sh
# Alpine Pi Load Worker
# Generates continuous HTTP traffic to simulate real users

SERVICE_URL="$1"
DURATION="$2"
CONCURRENT="$3"

echo "Starting load generation..."
echo "Target: $SERVICE_URL"
echo "Duration: ${DURATION}s"
echo "Concurrent: $CONCURRENT"

END_TIME=$(($(date +%s) + DURATION))
REQUEST_COUNT=0

# Function to make single request
make_request() {
    START=$(date +%s%3N)
    RESPONSE=$(wget -q -O - "$SERVICE_URL/compute/pi?iterations=1000000" 2>&1)
    END=$(date +%s%3N)
    LATENCY=$((END - START))

    if echo "$RESPONSE" | grep -q "pi"; then
        echo "[$REQUEST_COUNT] OK ${LATENCY}ms"
        return 0
    else
        echo "[$REQUEST_COUNT] FAIL ${LATENCY}ms"
        return 1
    fi
}

# Run requests in parallel
while [ $(date +%s) -lt $END_TIME ]; do
    # Launch concurrent requests
    for i in $(seq 1 $CONCURRENT); do
        make_request &
    done

    # Wait for batch to complete
    wait

    REQUEST_COUNT=$((REQUEST_COUNT + CONCURRENT))

    # Small delay between batches (adjust for desired load)
    sleep 1
done

echo "Completed $REQUEST_COUNT requests"
EOF

echo "✓ Load generator script created"
echo ""

# Deploy script to all Alpine nodes
echo "[3/5] Deploying to Alpine nodes..."
for node in "${ALPINE_NODES[@]}"; do
    echo "  → $node"
    scp -q /tmp/alpine_load_worker.sh ${node}:/tmp/
    ssh $node "chmod +x /tmp/alpine_load_worker.sh"
done
echo "✓ Deployed to ${#ALPINE_NODES[@]} nodes"
echo ""

# Start distributed load test
echo "[4/5] Starting distributed load test..."
echo "Traffic will run for ${DURATION_SECONDS}s from ${#ALPINE_NODES[@]} Alpine Pi nodes"
echo ""
echo "Monitor in Grafana:"
echo "  → http://192.168.2.61:3000"
echo "  → Check 'Container Metrics' dashboard"
echo "  → Look for load distribution across replicas"
echo ""

# Launch load on all Alpine nodes in parallel
PIDS=()
for i in "${!ALPINE_NODES[@]}"; do
    node="${ALPINE_NODES[$i]}"
    echo "[$((i+1))/${#ALPINE_NODES[@]}] Launching load from $node..."

    ssh $node "/tmp/alpine_load_worker.sh $SERVICE_URL $DURATION_SECONDS $CONCURRENT_REQUESTS" > /tmp/alpine_${i}_output.log 2>&1 &
    PIDS+=($!)
done

echo "✓ All Alpine nodes generating traffic"
echo ""

# Monitor progress
echo "[5/5] Monitoring load test progress..."
echo "Press Ctrl+C to stop early (or wait ${DURATION_SECONDS}s)"
echo ""

# Show progress every 30 seconds
for i in $(seq 1 $((DURATION_SECONDS / 30))); do
    sleep 30

    # Check service replicas
    CURRENT_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")

    # Count active Alpine workers
    ACTIVE=0
    for pid in "${PIDS[@]}"; do
        if kill -0 $pid 2>/dev/null; then
            ACTIVE=$((ACTIVE + 1))
        fi
    done

    echo "[$(date +%H:%M:%S)] Active nodes: $ACTIVE/${#ALPINE_NODES[@]} | Replicas: $CURRENT_REPLICAS"
done

# Wait for all Alpine nodes to complete
echo ""
echo "Waiting for all Alpine nodes to complete..."
for i in "${!PIDS[@]}"; do
    wait ${PIDS[$i]}
    node="${ALPINE_NODES[$i]}"
    echo "  ✓ $node completed"
done

echo ""
echo "=========================================="
echo "Distributed Load Test Complete"
echo "=========================================="

# Show summary from each Alpine node
echo ""
echo "Summary from each Alpine node:"
for i in "${!ALPINE_NODES[@]}"; do
    node="${ALPINE_NODES[$i]}"
    echo ""
    echo "[$node]"
    tail -5 /tmp/alpine_${i}_output.log
done

# Final replica count
echo ""
echo "Final state:"
FINAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}'")
echo "  web-stress: $FINAL_REPLICAS"

echo ""
echo "✓ Check Grafana to see load distribution across replicas"
echo "  → http://192.168.2.61:3000"
echo ""

# Cleanup
rm -f /tmp/alpine_load_worker.sh
rm -f /tmp/alpine_*_output.log

exit 0
