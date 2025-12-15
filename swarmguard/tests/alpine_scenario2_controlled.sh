#!/bin/bash
# Alpine Scenario 2 - Fully Controlled Load Test
# Full control over users, CPU, memory, network parameters
#
# Usage:
#   ./alpine_scenario2_controlled.sh [USERS_PER_ALPINE] [SIZE_MB] [CPU_WORK] [DELAY] [DURATION]
#
# Examples:
#   ./alpine_scenario2_controlled.sh 5 10 200000 1 300     # 20 users, 10MB downloads, 200k CPU work, 1s delay
#   ./alpine_scenario2_controlled.sh 10 15 300000 0.5 300  # 40 users, 15MB downloads, 300k CPU work, 0.5s delay
#   ./alpine_scenario2_controlled.sh 15 20 400000 0.3 300  # 60 users, 20MB downloads, 400k CPU work, 0.3s delay

set -e

echo "=========================================="
echo "Scenario 2: Controlled Load Test"
echo "=========================================="
echo ""

# Configuration
USERS_PER_ALPINE=${1:-5}      # Users per Alpine (default: 5)
DOWNLOAD_SIZE_MB=${2:-10}     # MB per download (default: 10MB)
CPU_WORK=${3:-200000}         # CPU iterations per download (default: 200k)
DELAY_BETWEEN=${4:-1}         # Delay between requests (default: 1s)
DURATION=${5:-300}            # Total duration (default: 300s)

SERVICE_URL="http://192.168.2.50:8080"
ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4")
TOTAL_USERS=$((USERS_PER_ALPINE * ${#ALPINE_NODES[@]}))

# Calculate expected load
REQUESTS_PER_SEC=$(echo "scale=2; $TOTAL_USERS / $DELAY_BETWEEN" | bc)
NETWORK_MBPS=$(echo "scale=2; $REQUESTS_PER_SEC * $DOWNLOAD_SIZE_MB * 8 / 60" | bc)  # Approximate

echo "Configuration:"
echo "  Users per Alpine:     $USERS_PER_ALPINE"
echo "  Total users:          $TOTAL_USERS (across ${#ALPINE_NODES[@]} Alpines)"
echo "  Download size:        ${DOWNLOAD_SIZE_MB}MB per request"
echo "  CPU work:             ${CPU_WORK} iterations per request"
echo "  Delay between req:    ${DELAY_BETWEEN}s"
echo "  Test duration:        ${DURATION}s"
echo ""
echo "Expected aggregate load:"
echo "  Request rate:         ~${REQUESTS_PER_SEC} req/sec"
echo "  Network throughput:   ~${NETWORK_MBPS} Mbps"
echo "  CPU:                  Depends on worker capacity (higher CPU_WORK = more CPU%)"
echo "  Memory:               Depends on concurrent downloads (each holds ${DOWNLOAD_SIZE_MB}MB)"
echo ""
echo "Tuning guide:"
echo "  • To increase NETWORK: Increase USERS or DOWNLOAD_SIZE, decrease DELAY"
echo "  • To increase CPU: Increase CPU_WORK or USERS, decrease DELAY"
echo "  • To increase MEMORY: Increase USERS or DOWNLOAD_SIZE, decrease DELAY"
echo ""

# Get initial state
echo "[1/3] Initial state:"
INITIAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo "  web-stress replicas: $INITIAL_REPLICAS"
echo ""

# Create Alpine user simulation script
cat > /tmp/alpine_controlled.sh << 'EOF'
#!/bin/sh
# Each user continuously downloads data

SERVICE_URL="$1"
DURATION="$2"
SIZE_MB="$3"
CPU_WORK="$4"
DELAY="$5"
USERS="$6"

echo "[$HOSTNAME] Starting $USERS users for ${DURATION}s..."
echo "[$HOSTNAME] Each user: ${SIZE_MB}MB download, ${CPU_WORK} CPU work, ${DELAY}s delay"

END_TIME=$(($(date +%s) + DURATION))

# Launch N user processes in parallel
for user_id in $(seq 1 $USERS); do
    (
        USER_REQUESTS=0
        while [ $(date +%s) -lt $END_TIME ]; do
            # Each user downloads data - creates CPU + Memory + Network load
            wget -q -O /dev/null --timeout=60 \
                "$SERVICE_URL/download/data?size_mb=$SIZE_MB&cpu_work=$CPU_WORK" \
                2>&1 && USER_REQUESTS=$((USER_REQUESTS + 1))

            # Delay between requests
            sleep $DELAY
        done
        echo "  User $user_id: $USER_REQUESTS downloads"
    ) &
done

# Wait for all users
wait
echo "[$HOSTNAME] All $USERS users completed"
EOF

# Deploy to Alpine nodes
echo "[2/3] Deploying to Alpine nodes..."
for node in "${ALPINE_NODES[@]}"; do
    ssh $node "pkill -f alpine_controlled.sh 2>/dev/null" || true
    sleep 1
    scp -q /tmp/alpine_controlled.sh ${node}:/tmp/
    ssh $node "chmod +x /tmp/alpine_controlled.sh"
done
echo "✓ Deployed to ${#ALPINE_NODES[@]} nodes"
echo ""

# Start load generation
echo "=========================================="
echo "Starting Controlled Load Test"
echo "=========================================="
echo ""
echo "📊 OPEN GRAFANA NOW:"
echo "   → http://192.168.2.61:3000"
echo "   → Dashboard: Container Metrics"
echo ""
echo "Load pattern:"
echo "  • $TOTAL_USERS users downloading continuously"
echo "  • Each download: ${DOWNLOAD_SIZE_MB}MB + ${CPU_WORK} CPU work"
echo "  • Delay: ${DELAY}s between requests per user"
echo "  • Creates sustained CPU + Memory + Network load"
echo ""
echo "Expected behavior:"
echo "  T+0s:   $TOTAL_USERS users → 1 replica → HIGH load"
echo "  T+30s:  System detects high CPU+MEM+NET → Scenario 2 scale-up"
echo "  T+60s:  Load distributes across 2 replicas"
echo "  T+90s:  If still high → scale to 3 replicas"
echo ""

PIDS=()
for node in "${ALPINE_NODES[@]}"; do
    echo "  Starting $USERS_PER_ALPINE users on $node..."
    ssh $node "/tmp/alpine_controlled.sh $SERVICE_URL $DURATION $DOWNLOAD_SIZE_MB $CPU_WORK $DELAY_BETWEEN $USERS_PER_ALPINE" > /tmp/${node}_controlled.log 2>&1 &
    PIDS+=($!)
done

echo ""
echo "✓ $TOTAL_USERS users actively generating load"
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
        echo "   → $TOTAL_USERS users now distributed across $CURRENT replicas"
        echo "   → Check Grafana to see load distribution"
        echo ""
        LAST_REPLICAS=$CURRENT
    else
        echo "[+${ELAPSED}s] Replicas: $CURRENT | Users: $TOTAL_USERS active | Check Grafana"
    fi
done

echo ""
echo "Waiting for users to complete..."
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
echo "  Total users:      $TOTAL_USERS"
echo "  Duration:         ${DURATION}s"
echo ""

ssh master "docker service ps web-stress --filter 'desired-state=running' --format 'table {{.Name}}\t{{.Node}}'"
echo ""

# Show summary
echo "User summary:"
for node in "${ALPINE_NODES[@]}"; do
    echo "  [$node]"
    tail -5 /tmp/${node}_controlled.log 2>/dev/null || echo "    (no output)"
done

echo ""
echo "✅ Controlled load test complete!"
echo ""
echo "Tuning tips:"
echo "  • Network too low?  → Increase USERS or SIZE_MB, decrease DELAY"
echo "  • CPU too low?      → Increase CPU_WORK or USERS, decrease DELAY"
echo "  • Memory too low?   → Increase USERS or SIZE_MB, decrease DELAY"
echo ""
echo "Example commands:"
echo "  ./alpine_scenario2_controlled.sh 10 15 300000 0.5 300   # Higher load"
echo "  ./alpine_scenario2_controlled.sh 15 20 400000 0.3 300   # Very high load"
echo ""

# Cleanup
rm -f /tmp/alpine_controlled.sh
rm -f /tmp/alpine-*_controlled.log

exit 0
