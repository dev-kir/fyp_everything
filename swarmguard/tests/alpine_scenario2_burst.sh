#!/bin/bash
# Alpine Scenario 2 - Burst Load Test with Existing Endpoints
# Strategy: Create SHORT stress bursts from many users simultaneously
# The aggregate of many small bursts creates sustained high load
#
# Usage:
#   ./alpine_scenario2_burst.sh [USERS] [CPU_TARGET] [MEM_TARGET] [DURATION]
#
# Examples:
#   ./alpine_scenario2_burst.sh 10 80 1000 300    # 40 users, each triggers 80% CPU burst
#   ./alpine_scenario2_burst.sh 15 90 1500 300    # 60 users, each triggers 90% CPU burst

set -e

echo "=========================================="
echo "Scenario 2: Burst Load Test"
echo "=========================================="
echo ""

# Configuration
USERS_PER_NODE=${1:-10}      # Users per Alpine node
CPU_TARGET=${2:-80}          # CPU% per burst
MEM_TARGET=${3:-1000}        # Memory MB per burst
TOTAL_DURATION=${4:-300}     # Total test duration

SERVICE_URL="http://192.168.2.50:8080"
ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4")
TOTAL_USERS=$((USERS_PER_NODE * ${#ALPINE_NODES[@]}))

# Burst configuration
BURST_DURATION=10            # Each stress burst lasts 10s
BURST_RAMP=2                 # Ramp up in 2s
BURST_GAP=3                  # 3s gap between bursts

echo "Configuration:"
echo "  Users per Alpine:      $USERS_PER_NODE"
echo "  Total users:           $TOTAL_USERS"
echo "  Test duration:         ${TOTAL_DURATION}s"
echo ""
echo "Burst pattern (per user):"
echo "  CPU target:            ${CPU_TARGET}%"
echo "  Memory target:         ${MEM_TARGET}MB"
echo "  Burst duration:        ${BURST_DURATION}s"
echo "  Gap between bursts:    ${BURST_GAP}s"
echo "  Cycle time:            $((BURST_DURATION + BURST_GAP))s"
echo ""
echo "Expected behavior:"
echo "  - ${TOTAL_USERS} users create overlapping stress bursts"
echo "  - Aggregate creates sustained high CPU + Memory load"
echo "  - Docker Swarm distributes stress across replicas"
echo "  - Should trigger Scenario 2 scaling"
echo ""

# Get initial state
echo "[1/3] Initial state:"
INITIAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo "  web-stress replicas: $INITIAL_REPLICAS"
echo ""

# Create Alpine burst script
cat > /tmp/alpine_burst.sh << 'EOF'
#!/bin/sh
# Each user creates periodic stress bursts

SERVICE_URL="$1"
DURATION="$2"
USERS="$3"
CPU_TARGET="$4"
MEM_TARGET="$5"
BURST_DUR="$6"
BURST_RAMP="$7"
BURST_GAP="$8"

echo "[$HOSTNAME] Starting $USERS burst users for ${DURATION}s..."
END_TIME=$(($(date +%s) + DURATION))

# Launch N user processes
for user_id in $(seq 1 $USERS); do
    (
        BURSTS=0
        while [ $(date +%s) -lt $END_TIME ]; do
            # Trigger stress burst
            wget -q -O /dev/null --timeout=$((BURST_DUR + 5)) \
                "$SERVICE_URL/stress/combined?cpu=$CPU_TARGET&memory=$MEM_TARGET&duration=$BURST_DUR&ramp=$BURST_RAMP" \
                2>&1 && BURSTS=$((BURSTS + 1))

            # Gap before next burst
            sleep $BURST_GAP
        done
        echo "  User $user_id: $BURSTS bursts"
    ) &
done

wait
echo "[$HOSTNAME] All users completed"
EOF

# Deploy to Alpine nodes
echo "[2/3] Deploying to Alpine nodes..."
for node in "${ALPINE_NODES[@]}"; do
    ssh $node "pkill -f alpine_burst.sh 2>/dev/null" || true
    sleep 1
    scp -q /tmp/alpine_burst.sh ${node}:/tmp/
    ssh $node "chmod +x /tmp/alpine_burst.sh"
done
echo "✓ Deployed"
echo ""

# Start simulation
echo "=========================================="
echo "Starting Burst Load Test"
echo "=========================================="
echo ""
echo "📊 OPEN GRAFANA: http://192.168.2.61:3000"
echo ""
echo "Expected timeline:"
echo "  T+0s:   ${TOTAL_USERS} users → overlapping stress bursts → HIGH load"
echo "  T+30s:  System detects sustained high load → scale 1→2"
echo "  T+60s:  Load distributed across 2 replicas"
echo "  T+90s:  If still high → scale 2→3"
echo ""

PIDS=()
for node in "${ALPINE_NODES[@]}"; do
    echo "  Starting $USERS_PER_NODE users on $node..."
    ssh $node "/tmp/alpine_burst.sh $SERVICE_URL $TOTAL_DURATION $USERS_PER_NODE $CPU_TARGET $MEM_TARGET $BURST_DURATION $BURST_RAMP $BURST_GAP" > /tmp/${node}_burst.log 2>&1 &
    PIDS+=($!)
done

echo ""
echo "✓ $TOTAL_USERS users generating burst load"
echo ""

# Monitor
echo "[3/3] Monitoring..."
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
        echo ""
        LAST_REPLICAS=$CURRENT
    else
        echo "[+${ELAPSED}s] Replicas: $CURRENT | Users: $TOTAL_USERS"
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
echo ""

ssh master "docker service ps web-stress --filter 'desired-state=running' --format 'table {{.Name}}\t{{.Node}}'"

# Cleanup
rm -f /tmp/alpine_burst.sh
rm -f /tmp/alpine-*_burst.log

exit 0
