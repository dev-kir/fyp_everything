#!/bin/bash
# ============================================================================
# DEMO: Baseline (Docker Swarm Reactive Recovery)
# ============================================================================
# SwarmGuard is DISABLED - Docker Swarm only reacts AFTER container crashes
# Duration: ~3-4 minutes (shortened for demo)
# ============================================================================

set -e

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║           DEMO: BASELINE (Docker Swarm Reactive Recovery)            ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  SwarmGuard: DISABLED                                                ║"
echo "║  Expected: Container crashes → Docker Swarm restarts (slow)          ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Create output directory
OUTPUT_DIR="/Users/amirmuz/RESULT_FYP_EVERYTHING/demo"
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# ============================================================================
# STEP 1: Ensure SwarmGuard is DISABLED
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1: Ensuring SwarmGuard is DISABLED..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Scale down all SwarmGuard components (silent if already at 0)
ssh master "docker service scale recovery-manager=0" 2>/dev/null || true
ssh master "docker service scale monitoring-agent-master=0" 2>/dev/null || true
ssh master "docker service scale monitoring-agent-worker1=0" 2>/dev/null || true
ssh master "docker service scale monitoring-agent-worker2=0" 2>/dev/null || true
ssh master "docker service scale monitoring-agent-worker3=0" 2>/dev/null || true
ssh master "docker service scale monitoring-agent-worker4=0" 2>/dev/null || true

sleep 5

# Verify SwarmGuard is disabled
echo ""
echo "Verifying SwarmGuard status..."
SWARMGUARD_STATUS=$(ssh master "docker service ls | grep -E '(recovery-manager|monitoring-agent)' | awk '{print \$4}' | grep -v '0/0' | wc -l")

if [ "$SWARMGUARD_STATUS" -eq 0 ]; then
    echo "✅ SwarmGuard is DISABLED (all agents at 0/0)"
else
    echo "⚠️  Warning: Some SwarmGuard services still running. Waiting..."
    sleep 10
fi

# Show current services
echo ""
echo "Current Docker services:"
ssh master "docker service ls | grep -E '(recovery-manager|monitoring-agent|web-stress)'"
echo ""

# ============================================================================
# STEP 2: Deploy fresh web-stress service
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Deploying fresh web-stress service..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ssh master "docker service rm web-stress" 2>/dev/null || true
sleep 5

cd /Users/amirmuz/fyp_everything/swarmguard
./tests/deploy_web_stress.sh 1 30
sleep 20
cd /Users/amirmuz/fyp_everything/fyp-report/03-chapter4-evidence/scripts

# Get initial location
INITIAL_NODE=$(ssh master "docker service ps web-stress --filter 'desired-state=running' --format '{{.Node}}' | head -n 1")
echo ""
echo "✅ web-stress deployed on node: $INITIAL_NODE"
echo ""

# ============================================================================
# STEP 3: Start monitoring & trigger stress
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Starting availability monitor..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Start availability monitoring in background
(
while true; do
  ts=$(date -Iseconds)
  code=$(curl -sf --connect-timeout 0.5 -m 1 -o /dev/null -w '%{http_code}' http://192.168.2.50:8080/health 2>/dev/null || echo "DOWN")
  echo "$ts $code"
  sleep 0.5
done
) > "$OUTPUT_DIR/demo_baseline_${TIMESTAMP}.log" &
MONITOR_PID=$!

echo "Monitor started (PID: $MONITOR_PID)"
echo "Log: $OUTPUT_DIR/demo_baseline_${TIMESTAMP}.log"
echo ""

# Baseline period
echo "Waiting 15 seconds for baseline readings..."
sleep 15

# ============================================================================
# STEP 4: Trigger stress test
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 4: TRIGGERING STRESS TEST"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Parameters:"
echo "    CPU:      95%"
echo "    Memory:   25000 MB"
echo "    Duration: 90 seconds"
echo "    Ramp:     30 seconds"
echo ""
echo "  ⚠️  SwarmGuard is DISABLED"
echo "  ⚠️  Container will CRASH before Docker Swarm reacts"
echo ""

STRESS_START=$(date -Iseconds)
echo "STRESS_STARTED: $STRESS_START" >> "$OUTPUT_DIR/demo_baseline_${TIMESTAMP}.log"

curl -s "http://192.168.2.50:8080/stress/combined?cpu=95&memory=25000&network=0&duration=90&ramp=30" > /dev/null
echo "✅ Stress test triggered at $STRESS_START"
echo ""

# ============================================================================
# STEP 5: Monitor for crash and recovery
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 5: Monitoring for crash and recovery..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Watch for: Container crash → Downtime → Docker Swarm restarts"
echo ""

# Monitor with live status updates
for i in {1..24}; do
    STATUS=$(curl -sf --connect-timeout 0.5 -m 1 -o /dev/null -w '%{http_code}' http://192.168.2.50:8080/health 2>/dev/null || echo "DOWN")
    CURRENT_NODE=$(ssh master "docker service ps web-stress --filter 'desired-state=running' --format '{{.Node}}' 2>/dev/null | head -n 1" || echo "unknown")

    if [ "$STATUS" = "DOWN" ]; then
        echo "  [$(date +%H:%M:%S)] Status: ❌ DOWN | Node: $CURRENT_NODE"
    else
        echo "  [$(date +%H:%M:%S)] Status: ✅ $STATUS | Node: $CURRENT_NODE"
    fi
    sleep 5
done

# ============================================================================
# STEP 6: Capture results
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 6: Capturing results..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Stop monitoring
kill $MONITOR_PID 2>/dev/null || true

# Capture recovery timeline
ssh master "docker service ps web-stress --no-trunc" > "$OUTPUT_DIR/demo_baseline_timeline_${TIMESTAMP}.txt"

# Get final node
FINAL_NODE=$(ssh master "docker service ps web-stress --filter 'desired-state=running' --format '{{.Node}}' | head -n 1")

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                         BASELINE DEMO COMPLETE                       ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  Initial Node: $INITIAL_NODE"
echo "║  Final Node:   $FINAL_NODE"
echo "║  SwarmGuard:   DISABLED (reactive only)"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  Results saved to:                                                   ║"
echo "║    $OUTPUT_DIR/demo_baseline_${TIMESTAMP}.log"
echo "║    $OUTPUT_DIR/demo_baseline_timeline_${TIMESTAMP}.txt"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Key observation: Notice the DOWNTIME between crash and recovery"
echo ""
