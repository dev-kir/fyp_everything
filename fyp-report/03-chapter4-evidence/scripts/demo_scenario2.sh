#!/bin/bash
# ============================================================================
# DEMO: Scenario 2 (Horizontal Autoscaling)
# ============================================================================
# SwarmGuard is ENABLED - Detects high load and scales replicas
# Duration: ~5-6 minutes (shortened for demo)
# ============================================================================

set -e

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║           DEMO: SCENARIO 2 (Horizontal Autoscaling)                  ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  SwarmGuard: ENABLED                                                 ║"
echo "║  Expected: High traffic → Auto scale-up → Load balancing             ║"
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

# Scale up all SwarmGuard components
ssh master "docker service scale recovery-manager=1"
ssh master "docker service scale monitoring-agent-master=1"
ssh master "docker service scale monitoring-agent-worker1=1"
ssh master "docker service scale monitoring-agent-worker2=1"
ssh master "docker service scale monitoring-agent-worker3=1"
ssh master "docker service scale monitoring-agent-worker4=1"

echo ""
echo "Waiting 30 seconds for all agents to be healthy..."
sleep 30

# Verify SwarmGuard is enabled
echo ""
echo "Verifying SwarmGuard status..."
ssh master "docker service ls | grep -E '(recovery-manager|monitoring-agent)'"

AGENTS_RUNNING=$(ssh master "docker service ls | grep -E '(recovery-manager|monitoring-agent)' | awk '{print \$4}' | grep '1/1' | wc -l")

if [ "$AGENTS_RUNNING" -ge 5 ]; then
    echo ""
    echo "✅ SwarmGuard is ENABLED ($AGENTS_RUNNING/6 agents running)"
else
    echo ""
    echo "⚠️  Warning: Only $AGENTS_RUNNING/6 agents running. Waiting more..."
    sleep 30
fi
echo ""

# ============================================================================
# STEP 2: Deploy fresh web-stress service (1 replica)
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Deploying fresh web-stress service (1 replica)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Clean any existing load first
echo "Cleaning existing load..."
curl -s "http://192.168.2.50:8080/stress/stop" > /dev/null 2>&1 || true
for alpine in alpine-1 alpine-2 alpine-3 alpine-4 alpine-5; do
    ssh "$alpine" "pkill -9 -f wget" 2>/dev/null || true
    ssh "$alpine" "pkill -9 -f scenario2" 2>/dev/null || true
done

ssh master "docker service rm web-stress" 2>/dev/null || true
sleep 5

cd /Users/amirmuz/fyp_everything/swarmguard
./tests/deploy_web_stress.sh 1 30
sleep 20
cd /Users/amirmuz/fyp_everything/fyp-report/03-chapter4-evidence/scripts

echo ""
echo "✅ web-stress deployed with 1 replica"
ssh master "docker service ls | grep web-stress"
echo ""

# ============================================================================
# STEP 3: Start replica monitoring
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Starting replica count monitor..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Start replica count monitoring in background
(
while true; do
  ts=$(date -Iseconds)
  replicas=$(ssh master "docker service ls --format '{{.Replicas}}' --filter name=web-stress" | head -n 1)
  echo "$ts $replicas"
  sleep 2
done
) > "$OUTPUT_DIR/demo_scenario2_replicas_${TIMESTAMP}.log" &
REPLICA_MONITOR_PID=$!

echo "Replica monitor started (PID: $REPLICA_MONITOR_PID)"
echo "Log: $OUTPUT_DIR/demo_scenario2_replicas_${TIMESTAMP}.log"
echo ""

sleep 10

# ============================================================================
# STEP 4: Trigger high traffic load
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 4: TRIGGERING HIGH TRAFFIC LOAD"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Using scenario2_ultimate.sh to simulate 60 users"
echo "  Parameters: 12 users/alpine × 5 alpines = 60 total users"
echo ""
echo "  ✅ SwarmGuard should detect high load"
echo "  ✅ Should scale replicas 1 → 2 (or more)"
echo ""

LOAD_START=$(date -Iseconds)
echo "LOAD_STARTED: $LOAD_START" >> "$OUTPUT_DIR/demo_scenario2_replicas_${TIMESTAMP}.log"

# Start the scenario2_ultimate script in background (shorter duration for demo)
# Use 'yes' to auto-answer any prompts, and higher load parameters
# Parameters: USERS_PER_ALPINE CPU% MEM_MB NET_MBPS STAGGER RAMP HOLD
# Using higher values to actually trigger scaling: 10 users × 5% CPU = 50% per alpine, × 5 alpines = 250% total
cd /Users/amirmuz/fyp_everything/swarmguard
yes | nohup ./tests/scenario2_ultimate.sh 10 5 50 10 2 30 300 > "$OUTPUT_DIR/demo_scenario2_ultimate_${TIMESTAMP}.log" 2>&1 &
SCENARIO2_PID=$!
cd /Users/amirmuz/fyp_everything/fyp-report/03-chapter4-evidence/scripts

echo "✅ Load test started (PID: $SCENARIO2_PID)"
echo "   Parameters: 10 users/alpine × 5 alpines = 50 users"
echo "   Expected: ~250% CPU, ~2500MB Memory, ~500Mbps Network"
echo "   Duration: 5 minutes"
echo ""

# ============================================================================
# STEP 5: Monitor for autoscaling
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 5: Monitoring for autoscaling..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Watch for: Replica count increasing from 1/1 to 2/2 (or more)"
echo ""

INITIAL_REPLICAS="1/1"
SCALE_DETECTED=false

# Monitor for 4 minutes with live updates
for i in {1..48}; do
    REPLICAS=$(ssh master "docker service ls --format '{{.Replicas}}' --filter name=web-stress" 2>/dev/null | head -n 1)
    LB_STATUS=$(curl -s "http://192.168.2.50:8081/metrics" 2>/dev/null | jq -r '.active_backends // "N/A"' 2>/dev/null || echo "N/A")

    # Check if scaling happened
    if [ "$REPLICAS" != "$INITIAL_REPLICAS" ] && [ "$SCALE_DETECTED" = false ]; then
        SCALE_DETECTED=true
        echo ""
        echo "  🚀 SCALE-UP DETECTED! Replicas: $INITIAL_REPLICAS → $REPLICAS"
        echo ""
    fi

    echo "  [$(date +%H:%M:%S)] Replicas: $REPLICAS | LB Backends: $LB_STATUS"
    sleep 5
done

# ============================================================================
# STEP 6: Stop load and observe scale-down
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 6: Stopping load, observing scale-down..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Stop load
kill $SCENARIO2_PID 2>/dev/null || true
curl -s "http://192.168.2.50:8080/stress/stop" > /dev/null || true
for alpine in alpine-1 alpine-2 alpine-3 alpine-4 alpine-5; do
    ssh "$alpine" "pkill -9 -f wget" 2>/dev/null || true
    ssh "$alpine" "pkill -9 -f scenario2" 2>/dev/null || true
done

echo "✅ Load stopped"
echo ""
echo "Waiting 90 seconds for scale-down..."

# Monitor scale-down for 90 seconds
for i in {1..18}; do
    REPLICAS=$(ssh master "docker service ls --format '{{.Replicas}}' --filter name=web-stress" 2>/dev/null | head -n 1)
    echo "  [$(date +%H:%M:%S)] Replicas: $REPLICAS"
    sleep 5
done

# ============================================================================
# STEP 7: Capture results
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 7: Capturing results..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Stop monitoring
kill $REPLICA_MONITOR_PID 2>/dev/null || true

# Capture final state
ssh master "docker service ls" > "$OUTPUT_DIR/demo_scenario2_final_${TIMESTAMP}.txt"
ssh master "docker service ps web-stress --no-trunc" > "$OUTPUT_DIR/demo_scenario2_timeline_${TIMESTAMP}.txt"
ssh master "docker service logs recovery-manager --tail 100" > "$OUTPUT_DIR/demo_scenario2_recovery_logs_${TIMESTAMP}.txt" 2>&1

FINAL_REPLICAS=$(ssh master "docker service ls --format '{{.Replicas}}' --filter name=web-stress" | head -n 1)

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                       SCENARIO 2 DEMO COMPLETE                       ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  Initial Replicas: 1/1"
echo "║  Final Replicas:   $FINAL_REPLICAS"
echo "║  SwarmGuard:       ENABLED (horizontal autoscaling)"
if [ "$SCALE_DETECTED" = true ]; then
echo "║  Autoscaling:      ✅ YES - Scale-up occurred!"
else
echo "║  Autoscaling:      ⚠️  No scaling (may need threshold tuning)"
fi
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  Results saved to:                                                   ║"
echo "║    $OUTPUT_DIR/demo_scenario2_replicas_${TIMESTAMP}.log"
echo "║    $OUTPUT_DIR/demo_scenario2_timeline_${TIMESTAMP}.txt"
echo "║    $OUTPUT_DIR/demo_scenario2_recovery_logs_${TIMESTAMP}.txt"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Key observation: Replicas should have scaled up under load, then down"
echo ""
