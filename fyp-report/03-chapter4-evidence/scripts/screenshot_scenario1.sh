#!/bin/bash
# Screenshot Helper: Scenario 1 (Proactive Migration)
# This script runs ONE scenario 1 test with pause points for screenshots

set -e

echo "=========================================="
echo "SCENARIO 1 SCREENSHOT HELPER"
echo "=========================================="
echo ""
echo "This script will:"
echo "  1. Enable SwarmGuard recovery-manager"
echo "  2. Deploy fresh web-stress service"
echo "  3. Wait for you to prepare Grafana"
echo "  4. Trigger gradual stress (SwarmGuard will migrate BEFORE crash)"
echo "  5. Show you when to take screenshots"
echo ""
echo "GRAFANA SETUP:"
echo "  - Open: http://192.168.2.61:3000"
echo "  - Dashboard: SwarmGuard Monitoring"
echo "  - Time range: Last 15 minutes (auto-refresh: 5s)"
echo "  - Focus on: web-stress container metrics"
echo ""
read -p "Press ENTER when Grafana is ready..."

# Ensure SwarmGuard is enabled
echo ""
echo "Step 1: Ensuring SwarmGuard is enabled..."
cd /Users/amirmuz/fyp_everything/swarmguard
ssh master "docker service ls | grep recovery-manager" || ./deploy_recovery_manager.sh
sleep 10

# Reset: Deploy fresh web-stress
echo ""
echo "Step 2: Deploying fresh web-stress service..."
ssh master "docker service rm web-stress" || true
sleep 10
./tests/deploy_web_stress.sh 1 30
sleep 30
cd /Users/amirmuz/fyp_everything/fyp-report/03-chapter4-evidence/scripts

# Start monitoring
echo ""
echo "Step 3: Starting availability monitoring..."
OUTPUT_DIR="/Users/amirmuz/RESULT_FYP_EVERYTHING"
mkdir -p "$OUTPUT_DIR"

while sleep 0.1; do
  ts=$(date -Iseconds)
  code=$(curl -sf --connect-timeout 0.5 -m 1 -o /dev/null -w '%{http_code}' http://192.168.2.50:8080/health 2>/dev/null || echo "DOWN")
  echo "$ts $code"
done > "$OUTPUT_DIR/screenshot_scenario1.log" &
MONITOR_PID=$!

echo "✓ Monitoring started"
echo ""
echo "Step 4: Baseline established (30 seconds)..."
sleep 30

# Get initial node
INITIAL_NODE=$(ssh master "docker service ps web-stress --filter 'desired-state=running' --format '{{.Node}}' | head -n 1")
echo "✓ Container running on: $INITIAL_NODE"
echo ""

echo "=========================================="
echo "📸 SCREENSHOT #1: BEFORE STRESS"
echo "=========================================="
echo "Take screenshot showing:"
echo "  - CPU/Memory/Network graphs (normal, healthy)"
echo "  - Container status: Running"
echo "  - Node: $INITIAL_NODE"
echo "  - SwarmGuard recovery-manager: Running"
echo ""
read -p "Press ENTER after taking screenshot..."

# Trigger stress
echo ""
echo "Step 5: Triggering gradual stress test..."
echo "Parameters: CPU=95%, Memory=25000MB, Duration=120s, Ramp=45s"
echo "Expected: SwarmGuard will MIGRATE container BEFORE it crashes (~60-75s)"
echo ""
curl -s "http://192.168.2.50:8080/stress/combined?cpu=95&memory=25000&network=0&duration=120&ramp=45" > /dev/null &
STRESS_PID=$!

echo "✓ Stress started"
echo ""
echo "Waiting 60 seconds for SwarmGuard detection..."
echo "(Watch Grafana: CPU/Memory ramping up, SwarmGuard will detect threshold breach)"
sleep 60

echo ""
echo "=========================================="
echo "📸 SCREENSHOT #2: DURING MIGRATION"
echo "=========================================="
echo "Take screenshot showing:"
echo "  - CPU/Memory elevated (approaching threshold)"
echo "  - SwarmGuard detected the issue"
echo "  - Container migrating to healthier node"
echo "  - HTTP health checks STILL 200 (no downtime!)"
echo ""
read -p "Press ENTER after taking screenshot..."

echo ""
echo "Waiting 30 seconds for migration to complete..."
sleep 30

# Check new node
NEW_NODE=$(ssh master "docker service ps web-stress --filter 'desired-state=running' --format '{{.Node}}' | head -n 1")

echo ""
echo "=========================================="
echo "📸 SCREENSHOT #3: AFTER MIGRATION"
echo "=========================================="
echo "Take screenshot showing:"
echo "  - Container successfully migrated"
echo "  - New node: $NEW_NODE (different from $INITIAL_NODE)"
echo "  - HTTP health checks CONTINUOUS 200 (zero downtime!)"
echo "  - CPU/Memory back to normal on new node"
echo "  - NO GAP in metrics (seamless migration)"
echo ""
read -p "Press ENTER after taking screenshot..."

# Stop monitoring
kill $MONITOR_PID 2>/dev/null || true
wait $STRESS_PID 2>/dev/null || true

# Check recovery manager logs
echo ""
echo "Step 6: Checking SwarmGuard logs..."
echo ""
ssh master "docker service logs recovery-manager --tail 20 | grep -E 'SCENARIO 1|MIGRATION|web-stress'" || echo "(No scenario 1 logs found - check full logs)"

echo ""
echo "=========================================="
echo "SCREENSHOTS COMPLETE"
echo "=========================================="
echo ""
echo "You should have 3 screenshots:"
echo "  1. Before stress (healthy baseline)"
echo "  2. During migration (proactive action)"
echo "  3. After migration (zero downtime, seamless)"
echo ""
echo "Save screenshots as:"
echo "  - scenario1_before_stress.png"
echo "  - scenario1_during_migration.png"
echo "  - scenario1_after_migration.png"
echo ""
echo "KEY DIFFERENCE FROM BASELINE:"
echo "  - Baseline: Container crashes → downtime → restart"
echo "  - Scenario 1: SwarmGuard migrates BEFORE crash → ZERO downtime"
echo ""
echo "Monitoring log saved: $OUTPUT_DIR/screenshot_scenario1.log"
