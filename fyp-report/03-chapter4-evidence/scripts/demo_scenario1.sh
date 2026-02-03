#!/bin/bash
# ============================================================================
# DEMO: Scenario 1 (Proactive Migration)
# ============================================================================
# SwarmGuard is ENABLED - Detects degradation and migrates BEFORE crash
# Duration: ~3-4 minutes (shortened for demo)
# ============================================================================

set -e

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║           DEMO: SCENARIO 1 (Proactive Migration)                     ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  SwarmGuard: ENABLED                                                 ║"
echo "║  Expected: Degradation detected → Proactive migration (no crash)     ║"
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
echo ""
ssh master "docker service ls | grep -E '(recovery-manager|monitoring-agent)'"

# Check all are running
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
) > "$OUTPUT_DIR/demo_scenario1_${TIMESTAMP}.log" &
MONITOR_PID=$!

echo "Monitor started (PID: $MONITOR_PID)"
echo "Log: $OUTPUT_DIR/demo_scenario1_${TIMESTAMP}.log"
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
echo "  ✅ SwarmGuard is ENABLED"
echo "  ✅ Should detect degradation and migrate BEFORE crash"
echo ""

STRESS_START=$(date -Iseconds)
echo "STRESS_STARTED: $STRESS_START" >> "$OUTPUT_DIR/demo_scenario1_${TIMESTAMP}.log"

curl -s "http://192.168.2.50:8080/stress/combined?cpu=95&memory=25000&network=0&duration=90&ramp=30" > /dev/null
echo "✅ Stress test triggered at $STRESS_START"
echo ""

# ============================================================================
# STEP 5: Monitor for proactive migration
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 5: Monitoring for proactive migration..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Watch for: SwarmGuard detects high CPU/Memory → Migrates to healthy node"
echo ""

# Monitor with live status updates
MIGRATION_DETECTED=false
for i in {1..24}; do
    STATUS=$(curl -sf --connect-timeout 0.5 -m 1 -o /dev/null -w '%{http_code}' http://192.168.2.50:8080/health 2>/dev/null || echo "DOWN")
    CURRENT_NODE=$(ssh master "docker service ps web-stress --filter 'desired-state=running' --format '{{.Node}}' 2>/dev/null | head -n 1" || echo "unknown")

    # Check if migration happened
    if [ "$CURRENT_NODE" != "$INITIAL_NODE" ] && [ "$MIGRATION_DETECTED" = false ]; then
        MIGRATION_DETECTED=true
        echo ""
        echo "  🚀 MIGRATION DETECTED! Moved from $INITIAL_NODE → $CURRENT_NODE"
        echo ""
    fi

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
ssh master "docker service ps web-stress --no-trunc" > "$OUTPUT_DIR/demo_scenario1_timeline_${TIMESTAMP}.txt"

# Capture recovery manager logs
ssh master "docker service logs recovery-manager --tail 50" > "$OUTPUT_DIR/demo_scenario1_recovery_logs_${TIMESTAMP}.txt" 2>&1

# Get final node
FINAL_NODE=$(ssh master "docker service ps web-stress --filter 'desired-state=running' --format '{{.Node}}' | head -n 1")

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                       SCENARIO 1 DEMO COMPLETE                       ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  Initial Node: $INITIAL_NODE"
echo "║  Final Node:   $FINAL_NODE"
echo "║  SwarmGuard:   ENABLED (proactive migration)"
if [ "$INITIAL_NODE" != "$FINAL_NODE" ]; then
echo "║  Migration:    ✅ YES - Proactive migration occurred!"
else
echo "║  Migration:    ⚠️  No migration (may need threshold tuning)"
fi
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  Results saved to:                                                   ║"
echo "║    $OUTPUT_DIR/demo_scenario1_${TIMESTAMP}.log"
echo "║    $OUTPUT_DIR/demo_scenario1_timeline_${TIMESTAMP}.txt"
echo "║    $OUTPUT_DIR/demo_scenario1_recovery_logs_${TIMESTAMP}.txt"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Key observation: Compare downtime with BASELINE - should be minimal/zero"
echo ""
