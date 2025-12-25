#!/bin/bash
# Screenshot Helper: Scenario 2 (Horizontal Scaling)
# This script runs ONE scenario 2 test with pause points for screenshots

set -e

echo "=========================================="
echo "SCENARIO 2 SCREENSHOT HELPER"
echo "=========================================="
echo ""
echo "This script will:"
echo "  1. Ensure SwarmGuard is enabled"
echo "  2. Deploy fresh web-stress service (1 replica)"
echo "  3. Wait for you to prepare Grafana"
echo "  4. Trigger high network traffic load"
echo "  5. Show you when to take screenshots during scaling"
echo ""
echo "GRAFANA SETUP:"
echo "  - Open: http://192.168.2.61:3000"
echo "  - Dashboard: SwarmGuard Monitoring"
echo "  - Time range: Last 30 minutes (auto-refresh: 5s)"
echo "  - Focus on:"
echo "    * Network Download/Upload (should spike to ~200 Mbps)"
echo "    * CPU usage (should reach ~70%)"
echo "    * Replica count (1 → 2 → 1)"
echo ""
read -p "Press ENTER when Grafana is ready..."

# Ensure SwarmGuard is enabled
echo ""
echo "Step 1: Ensuring SwarmGuard is enabled..."
cd /Users/amirmuz/fyp_everything/swarmguard
ssh master "docker service ls | grep recovery-manager" || ./deploy_recovery_manager.sh
sleep 10

# Clean any existing load
echo ""
echo "Step 2: Cleaning any existing load..."
curl -s "http://192.168.2.50:8080/stress/stop" > /dev/null 2>&1 || true
for alpine in alpine-1 alpine-2 alpine-3 alpine-4 alpine-5; do
    ssh "$alpine" "pkill -9 -f wget" 2>/dev/null || true
    ssh "$alpine" "pkill -9 -f scenario2_alpine_user.sh" 2>/dev/null || true
done

# Deploy fresh web-stress
echo ""
echo "Step 3: Deploying fresh web-stress service (1 replica)..."
ssh master "docker service rm web-stress" || true
sleep 10
./tests/deploy_web_stress.sh 1 30
sleep 30

echo "✓ Service deployed"
echo ""
echo "Step 4: Baseline established (30 seconds)..."
sleep 30

# Check initial state
INITIAL_REPLICAS=$(ssh master "docker service ls --format '{{.Replicas}}' --filter name=web-stress")
echo "✓ Initial replicas: $INITIAL_REPLICAS"
echo ""

echo "=========================================="
echo "📸 SCREENSHOT #1: BEFORE SCALING"
echo "=========================================="
echo "Take screenshot showing:"
echo "  - 1 replica running"
echo "  - Low network traffic (~0-20 Mbps)"
echo "  - Low CPU usage (~5-10%)"
echo "  - Normal baseline metrics"
echo ""
read -p "Press ENTER after taking screenshot..."

# Trigger Scenario 2 load
echo ""
echo "Step 5: Triggering Scenario 2 high-traffic load..."
echo "Parameters: 12 users/alpine, 60 total users"
echo "Expected Network: ~200 Mbps sustained"
echo "Expected CPU: ~70%"
echo "Expected: Scale 1→2 replicas in ~60-120 seconds"
echo ""

cd /Users/amirmuz/fyp_everything/swarmguard
nohup ./tests/scenario2_ultimate.sh 12 2 8 12 2 60 900 > /tmp/screenshot_scenario2_load.log 2>&1 &
LOAD_PID=$!
cd /Users/amirmuz/fyp_everything/fyp-report/03-chapter4-evidence/scripts

echo "✓ Load test started (PID: $LOAD_PID)"
echo ""
echo "Waiting 2 minutes for load to ramp up and trigger scaling..."
echo "(Watch Grafana: Network should climb to ~200 Mbps, CPU to ~70%)"
sleep 120

echo ""
echo "=========================================="
echo "📸 SCREENSHOT #2: DURING SCALE-UP"
echo "=========================================="
echo "Take screenshot showing:"
echo "  - Network traffic: ~200 Mbps sustained"
echo "  - CPU usage: ~70%"
echo "  - Replicas: 1/2 or 2/2 (scaling in progress)"
echo "  - SwarmGuard detected high traffic and scaling"
echo ""
read -p "Press ENTER after taking screenshot..."

echo ""
echo "Waiting 3 more minutes for scaling to stabilize..."
echo "(Watch: Load should distribute across 2 replicas)"
sleep 180

# Check scaled state
SCALED_REPLICAS=$(ssh master "docker service ls --format '{{.Replicas}}' --filter name=web-stress")
echo "✓ Current replicas: $SCALED_REPLICAS"

echo ""
echo "=========================================="
echo "📸 SCREENSHOT #3: AFTER SCALE-UP (2 replicas)"
echo "=========================================="
echo "Take screenshot showing:"
echo "  - 2 replicas running"
echo "  - Network: ~200 Mbps distributed across both replicas (~100 Mbps each)"
echo "  - CPU: ~35-40% per replica (total load distributed)"
echo "  - Load balancer showing ~50/50 distribution"
echo ""
read -p "Press ENTER after taking screenshot..."

# Stop load
echo ""
echo "Step 6: Stopping load test..."
kill $LOAD_PID 2>/dev/null || true
curl -s "http://192.168.2.50:8080/stress/stop" > /dev/null || true
for alpine in alpine-1 alpine-2 alpine-3 alpine-4 alpine-5; do
    ssh "$alpine" "pkill -9 -f wget" 2>/dev/null || true
    ssh "$alpine" "pkill -9 -f scenario2_alpine_user.sh" 2>/dev/null || true
done
echo "✓ Load stopped"

echo ""
echo "Waiting 3 minutes for scale-down (2→1 replicas)..."
echo "(Watch Grafana: Network drops, SwarmGuard should scale down)"
sleep 180

# Check final state
FINAL_REPLICAS=$(ssh master "docker service ls --format '{{.Replicas}}' --filter name=web-stress")
echo "✓ Final replicas: $FINAL_REPLICAS"

echo ""
echo "=========================================="
echo "📸 SCREENSHOT #4: AFTER SCALE-DOWN (1 replica)"
echo "=========================================="
echo "Take screenshot showing:"
echo "  - Back to 1 replica"
echo "  - Network: Low (~0-20 Mbps)"
echo "  - CPU: Normal (~5-10%)"
echo "  - Complete scaling cycle visible: 1→2→1"
echo ""
read -p "Press ENTER after taking screenshot..."

# Check recovery manager logs
echo ""
echo "Step 7: Checking SwarmGuard logs..."
echo ""
ssh master "docker service logs recovery-manager --tail 30 | grep -E 'SCENARIO 2|SCALING|web-stress'" || echo "(No scenario 2 logs found - check full logs)"

echo ""
echo "=========================================="
echo "SCREENSHOTS COMPLETE"
echo "=========================================="
echo ""
echo "You should have 4 screenshots:"
echo "  1. Before scaling (1 replica, low traffic)"
echo "  2. During scale-up (high traffic detected, scaling triggered)"
echo "  3. After scale-up (2 replicas, load distributed)"
echo "  4. After scale-down (back to 1 replica)"
echo ""
echo "Save screenshots as:"
echo "  - scenario2_before_scaling.png"
echo "  - scenario2_during_scaleup.png"
echo "  - scenario2_after_scaleup.png"
echo "  - scenario2_after_scaledown.png"
echo ""
echo "BONUS: Monitor load balancer distribution"
echo "  ssh lab-mac 'cd /Users/amirmuz/fyp_everything/swarmguard && ./tests/monitor_lb_distribution.sh'"
echo ""
echo "Load test log saved: /tmp/screenshot_scenario2_load.log"
