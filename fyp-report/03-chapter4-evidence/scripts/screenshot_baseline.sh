#!/bin/bash
# Screenshot Helper: Baseline (Reactive Recovery)
# This script runs ONE baseline test with pause points for screenshots

set -e

echo "=========================================="
echo "BASELINE SCREENSHOT HELPER"
echo "=========================================="
echo ""
echo "This script will:"
echo "  1. Deploy fresh web-stress service"
echo "  2. Wait for you to prepare Grafana"
echo "  3. Trigger gradual stress (container will crash)"
echo "  4. Show you when to take screenshots"
echo "  5. Wait for Docker Swarm reactive recovery"
echo ""
echo "GRAFANA SETUP:"
echo "  - Open: http://192.168.2.61:3000"
echo "  - Dashboard: SwarmGuard Monitoring"
echo "  - Time range: Last 15 minutes (auto-refresh: 5s)"
echo "  - Focus on: web-stress container metrics"
echo ""
read -p "Press ENTER when Grafana is ready..."

# Reset: Deploy fresh web-stress
echo ""
echo "Step 1: Deploying fresh web-stress service..."
ssh master "docker service rm web-stress" || true
sleep 10
cd /Users/amirmuz/fyp_everything/swarmguard
./tests/deploy_web_stress.sh 1 30
sleep 30
cd /Users/amirmuz/fyp_everything/fyp-report/03-chapter4-evidence/scripts

# Start monitoring
echo ""
echo "Step 2: Starting availability monitoring..."
OUTPUT_DIR="/Users/amirmuz/RESULT_FYP_EVERYTHING"
mkdir -p "$OUTPUT_DIR"

while sleep 0.1; do
  ts=$(date -Iseconds)
  code=$(curl -sf --connect-timeout 0.5 -m 1 -o /dev/null -w '%{http_code}' http://192.168.2.50:8080/health 2>/dev/null || echo "DOWN")
  echo "$ts $code"
done > "$OUTPUT_DIR/screenshot_baseline.log" &
MONITOR_PID=$!

echo "✓ Monitoring started"
echo ""
echo "Step 3: Baseline established (30 seconds)..."
sleep 30

# Get initial node
INITIAL_NODE=$(ssh master "docker service ps web-stress --filter 'desired-state=running' --format '{{.Node}}' | head -n 1")
echo "✓ Container running on: $INITIAL_NODE"
echo ""

echo "=========================================="
echo "📸 SCREENSHOT #1: BEFORE CRASH"
echo "=========================================="
echo "Take screenshot showing:"
echo "  - CPU/Memory/Network graphs (normal, healthy)"
echo "  - Container status: Running"
echo "  - Node: $INITIAL_NODE"
echo ""
read -p "Press ENTER after taking screenshot..."

# Trigger stress
echo ""
echo "Step 4: Triggering gradual stress test..."
echo "Parameters: CPU=95%, Memory=25000MB, Duration=120s, Ramp=45s"
echo "Expected: Container will crash in ~60-90 seconds"
echo ""
curl -s "http://192.168.2.50:8080/stress/combined?cpu=95&memory=25000&network=0&duration=120&ramp=45" > /dev/null &
STRESS_PID=$!

echo "✓ Stress started"
echo ""
echo "Waiting 60 seconds for gradual degradation..."
echo "(Watch Grafana: CPU/Memory should ramp up slowly)"
sleep 60

echo ""
echo "=========================================="
echo "📸 SCREENSHOT #2: DURING CRASH"
echo "=========================================="
echo "Take screenshot showing:"
echo "  - CPU spiking to 95%"
echo "  - Memory climbing to high levels"
echo "  - Container about to crash / just crashed"
echo "  - HTTP health checks starting to fail (DOWN)"
echo ""
read -p "Press ENTER after taking screenshot..."

echo ""
echo "Waiting for Docker Swarm reactive recovery (60 seconds)..."
echo "(Watch Grafana: Container will restart on a new node)"
sleep 60

# Check new node
sleep 10
NEW_NODE=$(ssh master "docker service ps web-stress --filter 'desired-state=running' --format '{{.Node}}' | head -n 1")

echo ""
echo "=========================================="
echo "📸 SCREENSHOT #3: AFTER RECOVERY"
echo "=========================================="
echo "Take screenshot showing:"
echo "  - Container recovered and running"
echo "  - New node: $NEW_NODE (different from $INITIAL_NODE)"
echo "  - HTTP health checks back to 200"
echo "  - CPU/Memory back to normal"
echo "  - DOWNTIME VISIBLE in graph (gap in metrics)"
echo ""
read -p "Press ENTER after taking screenshot..."

# Stop monitoring
kill $MONITOR_PID 2>/dev/null || true
wait $STRESS_PID 2>/dev/null || true

echo ""
echo "=========================================="
echo "SCREENSHOTS COMPLETE"
echo "=========================================="
echo ""
echo "You should have 3 screenshots:"
echo "  1. Before crash (healthy baseline)"
echo "  2. During crash (degradation visible)"
echo "  3. After recovery (reactive restart, visible downtime)"
echo ""
echo "Save screenshots as:"
echo "  - baseline_before_crash.png"
echo "  - baseline_during_crash.png"
echo "  - baseline_after_recovery.png"
echo ""
echo "Monitoring log saved: $OUTPUT_DIR/screenshot_baseline.log"
