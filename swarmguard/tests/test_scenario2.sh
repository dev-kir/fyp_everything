#!/bin/bash
# Scenario 2 Test Script - User-based load simulation
# Usage: ./test_scenario2.sh <users> <cpu%> <memory_mb> <network_mbps> <ramp_sec> <duration_sec>
#
# Example: ./test_scenario2.sh 10 2 50 5 60 120
#   → 10 users per Alpine (40 total)
#   → Each user: 2% CPU, 50MB RAM, 5Mbps network
#   → Ramp over 60s, hold for 120s
#   → Expected: 80% CPU, 2000MB RAM, 200Mbps NET

set -e

USERS_PER_ALPINE=${1:-10}
CPU_PER_USER=${2:-2}
MEM_PER_USER=${3:-50}
NET_PER_USER=${4:-5}
RAMP_TIME=${5:-60}
DURATION=${6:-120}

ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4")
TOTAL_USERS=$((USERS_PER_ALPINE * ${#ALPINE_NODES[@]}))
SERVICE_URL="http://192.168.2.50:8080"

# Calculate expected aggregate
EXPECTED_CPU=$((TOTAL_USERS * CPU_PER_USER))
EXPECTED_MEM=$((TOTAL_USERS * MEM_PER_USER))
EXPECTED_NET=$((TOTAL_USERS * NET_PER_USER))

# Calculate download parameters to achieve target
# Network: NET Mbps = (download_size_MB × 8) / download_time_sec
# For NET_PER_USER Mbps: download 10MB every (10×8/NET) seconds
DOWNLOAD_SIZE_MB=10
DOWNLOAD_INTERVAL=$(echo "scale=2; ($DOWNLOAD_SIZE_MB * 8) / $NET_PER_USER" | bc)

# CPU work scales with CPU target (rough calibration)
CPU_WORK=$((CPU_PER_USER * 500000))

echo "=========================================="
echo "Scenario 2: User Simulation Test"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Users per Alpine:  $USERS_PER_ALPINE"
echo "  Total users:       $TOTAL_USERS"
echo "  Per-user targets:  ${CPU_PER_USER}% CPU, ${MEM_PER_USER}MB RAM, ${NET_PER_USER}Mbps NET"
echo "  Ramp time:         ${RAMP_TIME}s"
echo "  Hold duration:     ${DURATION}s"
echo ""
echo "Expected aggregate load:"
echo "  CPU:     ${EXPECTED_CPU}%"
echo "  Memory:  ${EXPECTED_MEM}MB"
echo "  Network: ${EXPECTED_NET}Mbps"
echo ""
echo "Implementation:"
echo "  Download size:     ${DOWNLOAD_SIZE_MB}MB per request"
echo "  Download interval: ${DOWNLOAD_INTERVAL}s"
echo "  CPU work:          ${CPU_WORK} iterations per request"
echo ""

# Get initial state
echo "[1/3] Initial state:"
INITIAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo "  web-stress replicas: $INITIAL_REPLICAS"
echo ""

# Create user simulation script
cat > /tmp/user_sim.sh << 'EOF'
#!/bin/sh
SERVICE_URL="$1"
DURATION="$2"
USERS="$3"
SIZE_MB="$4"
CPU_WORK="$5"
INTERVAL="$6"

echo "[$HOSTNAME] Simulating $USERS users for ${DURATION}s"
echo "[$HOSTNAME] Each user: ${SIZE_MB}MB download, ${CPU_WORK} CPU work, ${INTERVAL}s interval"

END_TIME=$(($(date +%s) + DURATION))

# Launch user processes
for user_id in $(seq 1 $USERS); do
    (
        REQUESTS=0
        while [ $(date +%s) -lt $END_TIME ]; do
            wget -q -O /dev/null --timeout=60 \
                "$SERVICE_URL/download/data?size_mb=$SIZE_MB&cpu_work=$CPU_WORK" \
                2>&1 && REQUESTS=$((REQUESTS + 1))
            sleep $INTERVAL
        done
        echo "  User $user_id: $REQUESTS requests"
    ) &
done

wait
echo "[$HOSTNAME] All users completed"
EOF

# Deploy to Alpine nodes
echo "[2/3] Deploying to Alpine nodes..."
for node in "${ALPINE_NODES[@]}"; do
    ssh $node "pkill -f user_sim.sh 2>/dev/null" || true
    scp -q /tmp/user_sim.sh ${node}:/tmp/
    ssh $node "chmod +x /tmp/user_sim.sh"
done
echo "✓ Deployed"
echo ""

# Start test
echo "=========================================="
echo "Starting User Simulation"
echo "=========================================="
echo ""
echo "📊 OPEN GRAFANA: http://192.168.2.61:3000"
echo ""
echo "Timeline:"
echo "  T+0s:       $TOTAL_USERS users start making requests"
echo "  T+${RAMP_TIME}s:  Peak load reached (${EXPECTED_CPU}% CPU, ${EXPECTED_MEM}MB RAM, ${EXPECTED_NET}Mbps NET)"
echo "  T+90s:      If thresholds met → Scenario 2 triggers → scale 1→2"
echo "  T+120s:     Load distributes across replicas"
echo "  T+$((RAMP_TIME + DURATION))s: Test completes"
echo ""

PIDS=()
for node in "${ALPINE_NODES[@]}"; do
    echo "  Starting $USERS_PER_ALPINE users on $node..."
    ssh $node "/tmp/user_sim.sh $SERVICE_URL $((RAMP_TIME + DURATION)) $USERS_PER_ALPINE $DOWNLOAD_SIZE_MB $CPU_WORK $DOWNLOAD_INTERVAL" > /tmp/${node}_sim.log 2>&1 &
    PIDS+=($!)
done

echo ""
echo "✓ $TOTAL_USERS users active"
echo ""

# Monitor
echo "[3/3] Monitoring..."
echo ""
START_TIME=$(date +%s)
LAST_REPLICAS=$INITIAL_REPLICAS

while true; do
    sleep 15
    ELAPSED=$(($(date +%s) - START_TIME))

    if [ $ELAPSED -ge $((RAMP_TIME + DURATION)) ]; then
        break
    fi

    CURRENT=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")

    if [ "$CURRENT" != "$LAST_REPLICAS" ]; then
        echo ""
        echo "✅ SCALE EVENT: $LAST_REPLICAS → $CURRENT replicas"
        echo "   → $TOTAL_USERS users now across $CURRENT replicas"
        echo "   → Per-replica: ~$((EXPECTED_CPU / CURRENT))% CPU, ~$((EXPECTED_MEM / CURRENT))MB RAM"
        echo ""
        LAST_REPLICAS=$CURRENT
    else
        if [ $ELAPSED -lt $RAMP_TIME ]; then
            echo "[+${ELAPSED}s] Ramping... | Replicas: $CURRENT"
        else
            echo "[+${ELAPSED}s] Peak load | Replicas: $CURRENT"
        fi
    fi
done

# Wait for completion
for pid in "${PIDS[@]}"; do
    wait $pid 2>/dev/null || true
done

echo ""
echo "=========================================="
echo "Test Complete"
echo "=========================================="
FINAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo "  Initial: $INITIAL_REPLICAS → Final: $FINAL_REPLICAS"
echo "  Users: $TOTAL_USERS"
echo ""

ssh master "docker service ps web-stress --filter 'desired-state=running' --format 'table {{.Name}}\t{{.Node}}'"
echo ""

# Cleanup
rm -f /tmp/user_sim.sh /tmp/alpine-*_sim.log

exit 0
