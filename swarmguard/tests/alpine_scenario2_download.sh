#!/bin/bash
# Alpine Scenario 2 - Organic Load with Real Downloads
# Strategy: Users download data from web-stress → generates REAL CPU + Memory + Network load
#
# Usage:
#   ./alpine_scenario2_download.sh [USERS] [DOWNLOAD_MB] [CPU_WORK] [DURATION]
#
# Examples:
#   ./alpine_scenario2_download.sh 10 5 50000 300      # 40 users, 5MB downloads, light CPU
#   ./alpine_scenario2_download.sh 15 10 100000 300    # 60 users, 10MB downloads, medium CPU
#   ./alpine_scenario2_download.sh 20 15 200000 300    # 80 users, 15MB downloads, heavy CPU

set -e

echo "=========================================="
echo "Scenario 2: Organic Load (Real Downloads)"
echo "=========================================="
echo ""

# Configuration from command-line arguments
USERS_PER_NODE=${1:-10}       # Default: 10 users per Alpine
DOWNLOAD_SIZE_MB=${2:-10}     # Default: 10MB per download
CPU_WORK=${3:-100000}         # Default: 100k Pi iterations per request
TOTAL_DURATION=${4:-300}      # Default: 5 minutes

SERVICE_URL="http://192.168.2.50:8080"
ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4")
TOTAL_USERS=$((USERS_PER_NODE * ${#ALPINE_NODES[@]}))

# Calculate expected load
# Each user downloads continuously → network bandwidth per user
REQUESTS_PER_SECOND=1  # Rough estimate: 1 download every few seconds
NETWORK_PER_USER=$((DOWNLOAD_SIZE_MB / 2))  # Approximate Mbps (varies by download speed)
EXPECTED_NETWORK=$((TOTAL_USERS * NETWORK_PER_USER))

echo "Configuration:"
echo "  Users per Alpine node: $USERS_PER_NODE"
echo "  Total Alpine nodes:    ${#ALPINE_NODES[@]}"
echo "  Total simulated users: $TOTAL_USERS"
echo "  Test duration:         ${TOTAL_DURATION}s"
echo ""
echo "Per-user activity:"
echo "  Download size: ${DOWNLOAD_SIZE_MB}MB per request"
echo "  CPU work:      ${CPU_WORK} Pi iterations per request"
echo "  Pattern:       Continuous downloads until duration expires"
echo ""
echo "Expected load:"
echo "  Network: ~${EXPECTED_NETWORK}Mbps (from actual data transfer)"
echo "  CPU:     Variable (from Pi calculations + data generation)"
echo "  Memory:  Variable (from holding data payloads)"
echo ""
echo "How it works:"
echo "  - Each user continuously downloads ${DOWNLOAD_SIZE_MB}MB from web-stress"
echo "  - Server does CPU work (${CPU_WORK} Pi iterations) per request"
echo "  - Server generates ${DOWNLOAD_SIZE_MB}MB data → real memory usage"
echo "  - Data flows through Docker Swarm → real network traffic"
echo "  - Result: Organic, distributed CPU + Memory + Network load"
echo ""

# Get initial state
echo "[1/3] Initial state:"
INITIAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo "  web-stress replicas: $INITIAL_REPLICAS"
echo ""

# Create Alpine download script
cat > /tmp/alpine_download.sh << 'EOF'
#!/bin/sh
# Simulates N users continuously downloading data

SERVICE_URL="$1"
DURATION="$2"
USERS="$3"
DOWNLOAD_MB="$4"
CPU_WORK="$5"

echo "[$HOSTNAME] Starting $USERS download users for ${DURATION}s..."
echo "[$HOSTNAME] Each download: ${DOWNLOAD_MB}MB with ${CPU_WORK} CPU work"
END_TIME=$(($(date +%s) + DURATION))

# Launch N user processes
for user_id in $(seq 1 $USERS); do
    (
        USER_DOWNLOADS=0
        USER_BYTES=0
        while [ $(date +%s) -lt $END_TIME ]; do
            # User downloads data from web-stress
            # Docker Swarm distributes these requests across replicas
            # Server does CPU work + generates data → creates real load
            BEFORE=$(date +%s)
            if wget -q -O /dev/null --timeout=30 "$SERVICE_URL/download/data?size_mb=$DOWNLOAD_MB&cpu_work=$CPU_WORK" 2>&1; then
                USER_DOWNLOADS=$((USER_DOWNLOADS + 1))
                USER_BYTES=$((USER_BYTES + DOWNLOAD_MB * 1024 * 1024))
            fi
            AFTER=$(date +%s)

            # Small delay between downloads
            sleep 1
        done
        USER_MB=$((USER_BYTES / 1024 / 1024))
        echo "  User $user_id: $USER_DOWNLOADS downloads, ${USER_MB}MB total"
    ) &
done

# Wait for all users to finish
wait
echo "[$HOSTNAME] All $USERS users completed"
EOF

# Deploy to Alpine nodes
echo "[2/3] Deploying download script to Alpine nodes..."
for node in "${ALPINE_NODES[@]}"; do
    # Kill any existing processes
    ssh $node "pkill -f alpine_download.sh 2>/dev/null" || true
    # Deploy new script
    scp -q /tmp/alpine_download.sh ${node}:/tmp/
    ssh $node "chmod +x /tmp/alpine_download.sh"
done
echo "✓ Deployed to ${#ALPINE_NODES[@]} nodes"
echo ""

# Start download simulation
echo "=========================================="
echo "Starting Download Simulation"
echo "=========================================="
echo ""
echo "Launching $TOTAL_USERS simulated users across ${#ALPINE_NODES[@]} Alpine nodes..."
echo "Each user will continuously download ${DOWNLOAD_SIZE_MB}MB for ${TOTAL_DURATION}s"
echo ""
echo "📊 OPEN GRAFANA NOW:"
echo "   → http://192.168.2.61:3000"
echo "   → Dashboard: Container Metrics"
echo ""
echo "What to watch:"
echo "  T+0s:   ${TOTAL_USERS} users downloading → 1 replica → high CPU/MEM/NET"
echo "  T+30s:  System detects high load → scale 1→2"
echo "  T+60s:  Downloads distributed across 2 replicas → load splits evenly"
echo "  T+90s:  If still high → scale 2→3"
echo "  T+120s: Downloads distributed across 3 replicas → ~33% per replica"
echo ""
echo "Why this triggers Scenario 2:"
echo "  ✓ REAL network traffic (actual data download)"
echo "  ✓ CPU load from Pi calculations"
echo "  ✓ Memory load from data generation"
echo "  ✓ All three metrics HIGH simultaneously → Scenario 2 scaling!"
echo ""

PIDS=()
for node in "${ALPINE_NODES[@]}"; do
    echo "  Starting $USERS_PER_NODE download users on $node..."
    ssh $node "/tmp/alpine_download.sh $SERVICE_URL $TOTAL_DURATION $USERS_PER_NODE $DOWNLOAD_SIZE_MB $CPU_WORK" > /tmp/${node}_download.log 2>&1 &
    PIDS+=($!)
done

echo ""
echo "✓ $TOTAL_USERS users actively downloading"
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
        echo "✅ SCALE-UP DETECTED: $LAST_REPLICAS → $CURRENT replicas"
        echo "   → $TOTAL_USERS users now distributed across $CURRENT replicas"
        echo "   → Downloads split: ~$((TOTAL_USERS / CURRENT)) users per replica"
        echo "   → Check Grafana: CPU/MEM/NET should split across $CURRENT replicas"
        echo ""
        LAST_REPLICAS=$CURRENT
    else
        echo "[+${ELAPSED}s] Replicas: $CURRENT | Users: $TOTAL_USERS downloading | Check Grafana"
    fi
done

echo ""
echo "Waiting for downloads to complete..."

# Wait for all Alpine nodes
for pid in "${PIDS[@]}"; do
    wait $pid 2>/dev/null || true
done

echo ""
echo "=========================================="
echo "Download Simulation Complete"
echo "=========================================="
echo ""

FINAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")

echo "Results:"
echo "  Initial replicas:  $INITIAL_REPLICAS"
echo "  Final replicas:    $FINAL_REPLICAS"
echo "  Simulated users:   $TOTAL_USERS"
echo "  Duration:          ${TOTAL_DURATION}s"
echo ""

# Show task distribution
echo "Final task distribution:"
ssh master "docker service ps web-stress --filter 'desired-state=running' --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}'"
echo ""

# Show summary from each Alpine node
echo "Download summary from Alpine nodes:"
for node in "${ALPINE_NODES[@]}"; do
    echo ""
    echo "[$node]"
    tail -10 /tmp/${node}_download.log 2>/dev/null || echo "  (no output)"
done

echo ""
echo "✅ Test complete!"
echo ""
echo "Next steps:"
echo "  1. Review Grafana to see how load distributed across replicas"
echo "  2. Wait ~4 minutes for scale-down to return to baseline"
echo "  3. Run again with different configurations:"
echo "     - ./alpine_scenario2_download.sh 15 10 100000 300   # More users"
echo "     - ./alpine_scenario2_download.sh 10 20 200000 300   # Bigger downloads"
echo ""

# Cleanup
rm -f /tmp/alpine_download.sh
rm -f /tmp/alpine-*_download.log

exit 0
