#!/bin/bash
# ============================================================================
# DEMO: Scenario 2 SIMPLE (Horizontal Autoscaling)
# ============================================================================
# This is a SIMPLIFIED version that generates load directly from Lab Mac
# No Alpine dependency - more reliable for demos
#
# Duration: ~5-6 minutes
# ============================================================================

set -e

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║      DEMO: SCENARIO 2 SIMPLE (Horizontal Autoscaling)                ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  SwarmGuard: ENABLED                                                 ║"
echo "║  Load: Direct from Lab Mac (no Alpine dependency)                    ║"
echo "║  Expected: High load → Auto scale-up → Load balancing                ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Create output directory
OUTPUT_DIR="/Users/amirmuz/RESULT_FYP_EVERYTHING/demo"
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# ============================================================================
# STEP 1: Ensure SwarmGuard is ENABLED
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1: Ensuring SwarmGuard is ENABLED..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ssh master "docker service scale recovery-manager=1" 2>/dev/null
ssh master "docker service scale monitoring-agent-master=1" 2>/dev/null
ssh master "docker service scale monitoring-agent-worker1=1" 2>/dev/null
ssh master "docker service scale monitoring-agent-worker2=1" 2>/dev/null
ssh master "docker service scale monitoring-agent-worker3=1" 2>/dev/null
ssh master "docker service scale monitoring-agent-worker4=1" 2>/dev/null

echo "Waiting 30 seconds for agents..."
sleep 30
echo "✅ SwarmGuard enabled"
echo ""

# ============================================================================
# STEP 2: Deploy fresh web-stress (1 replica)
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Deploying fresh web-stress (1 replica)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

curl -s "http://192.168.2.50:8080/stress/stop" > /dev/null 2>&1 || true
ssh master "docker service rm web-stress" 2>/dev/null || true
sleep 5

cd /Users/amirmuz/fyp_everything/swarmguard
./tests/deploy_web_stress.sh 1 30
sleep 20
cd /Users/amirmuz/fyp_everything/fyp-report/03-chapter4-evidence/scripts

INITIAL_NODE=$(ssh master "docker service ps web-stress --filter 'desired-state=running' --format '{{.Node}}' | head -n 1")
echo ""
echo "✅ web-stress deployed on: $INITIAL_NODE"
ssh master "docker service ls | grep web-stress"
echo ""

# ============================================================================
# STEP 3: Generate HIGH LOAD directly
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Generating HIGH LOAD directly..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Method 1: CPU + Memory stress on container"
echo "  Method 2: Concurrent network requests through LB"
echo ""
echo "  Thresholds for scaling:"
echo "    - Network > 65 Mbps"
echo "    - CPU > 75%"
echo ""

# Start container stress (CPU + Memory)
echo "Starting CPU + Memory stress on container..."
curl -s "http://192.168.2.50:8080/stress/combined?cpu=85&memory=20000&network=0&duration=240&ramp=30" > /dev/null &
STRESS_PID=$!
echo "✅ Stress started (PID: $STRESS_PID)"
echo ""

# Start concurrent network requests through LB
echo "Starting concurrent network requests through Load Balancer..."
LOAD_PIDS=()

# Function to generate continuous requests
generate_load() {
    local id=$1
    local duration=$2
    local end_time=$(($(date +%s) + duration))

    while [ $(date +%s) -lt $end_time ]; do
        # Send requests through LB (port 8081)
        curl -s -o /dev/null "http://192.168.2.50:8081/health" 2>/dev/null &
        curl -s -o /dev/null "http://192.168.2.50:8081/metrics" 2>/dev/null &
        # Download some data for network load
        curl -s -o /dev/null "http://192.168.2.50:8081/download/data?size_mb=5" 2>/dev/null &
        sleep 0.1
    done
}

# Start 10 parallel load generators
for i in {1..10}; do
    generate_load $i 240 &
    LOAD_PIDS+=($!)
done

echo "✅ Started 10 parallel load generators (240 seconds each)"
echo ""

# ============================================================================
# STEP 4: Monitor for autoscaling
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 4: Monitoring for autoscaling..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Watching for replica count to increase from 1 to 2"
echo "  Check Grafana for CPU/Memory/Network increase"
echo ""

SCALE_DETECTED=false
INITIAL_REPLICAS="1"
START_TIME=$(date +%s)

# Monitor for 4 minutes
for i in {1..48}; do
    ELAPSED=$(($(date +%s) - START_TIME))
    REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}'" 2>/dev/null | head -n 1)

    # Get LB stats
    LB_REQUESTS=$(curl -s "http://192.168.2.50:8081/metrics" 2>/dev/null | jq -r '.total_requests // "N/A"' 2>/dev/null || echo "N/A")
    LB_REPLICAS=$(curl -s "http://192.168.2.50:8081/metrics" 2>/dev/null | jq -r '.healthy_replicas // "N/A"' 2>/dev/null || echo "N/A")

    # Check for scale event
    if [[ "$REPLICAS" == "2/"* ]] && [ "$SCALE_DETECTED" = false ]; then
        SCALE_DETECTED=true
        echo ""
        echo "  ╔════════════════════════════════════════════════════════╗"
        echo "  ║  🚀 SCALE-UP DETECTED! Replicas: 1 → 2                 ║"
        echo "  ╚════════════════════════════════════════════════════════╝"
        echo ""
    fi

    if [ "$SCALE_DETECTED" = true ]; then
        echo -e "  [T+${ELAPSED}s] Replicas: \033[32m$REPLICAS\033[0m | LB: $LB_REPLICAS healthy, $LB_REQUESTS requests"
    else
        echo -e "  [T+${ELAPSED}s] Replicas: \033[33m$REPLICAS\033[0m | LB: $LB_REPLICAS healthy, $LB_REQUESTS requests"
    fi

    sleep 5
done

echo ""

# ============================================================================
# STEP 5: Stop load and observe scale-down
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 5: Stopping load..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Stop stress
curl -s "http://192.168.2.50:8080/stress/stop" > /dev/null 2>&1 || true

# Kill load generators
for pid in "${LOAD_PIDS[@]}"; do
    kill $pid 2>/dev/null || true
done
kill $STRESS_PID 2>/dev/null || true

# Kill any remaining curl processes
pkill -f "curl.*192.168.2.50" 2>/dev/null || true

echo "✅ Load stopped"
echo ""
echo "Waiting 60 seconds to observe scale-down..."

for i in {1..12}; do
    REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}'" 2>/dev/null | head -n 1)
    echo "  [$(date +%H:%M:%S)] Replicas: $REPLICAS"
    sleep 5
done

# ============================================================================
# STEP 6: Capture results
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 6: Capturing results..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ssh master "docker service ls" > "$OUTPUT_DIR/demo_scenario2_simple_final_${TIMESTAMP}.txt"
ssh master "docker service ps web-stress --no-trunc" > "$OUTPUT_DIR/demo_scenario2_simple_timeline_${TIMESTAMP}.txt"
ssh master "docker service logs recovery-manager --tail 100" > "$OUTPUT_DIR/demo_scenario2_simple_logs_${TIMESTAMP}.txt" 2>&1

FINAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}'" | head -n 1)

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                   SCENARIO 2 SIMPLE DEMO COMPLETE                    ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  Initial Replicas: 1/1"
echo "║  Final Replicas:   $FINAL_REPLICAS"
if [ "$SCALE_DETECTED" = true ]; then
echo "║  Autoscaling:      ✅ YES - Scale-up occurred!"
else
echo "║  Autoscaling:      ⚠️  No scaling detected"
fi
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  Results saved to: $OUTPUT_DIR/"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
