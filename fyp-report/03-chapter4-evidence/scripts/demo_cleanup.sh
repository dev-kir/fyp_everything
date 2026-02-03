#!/bin/bash
# ============================================================================
# DEMO: Cleanup - Reset everything after demo
# ============================================================================
# Use this between demos or at the end to clean up
# ============================================================================

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                         DEMO CLEANUP                                 ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# Stop any running stress/load
# ============================================================================
echo "Stopping any running stress tests..."
curl -s "http://192.168.2.50:8080/stress/stop" > /dev/null 2>&1 || true

echo "Stopping any Alpine load generation..."
for alpine in alpine-1 alpine-2 alpine-3 alpine-4 alpine-5; do
    ssh "$alpine" "pkill -9 -f wget" 2>/dev/null || true
    ssh "$alpine" "pkill -9 -f scenario2" 2>/dev/null || true
done

# Kill any lingering background processes
pkill -f "demo_baseline" 2>/dev/null || true
pkill -f "demo_scenario" 2>/dev/null || true
pkill -f "scenario2_ultimate" 2>/dev/null || true

echo "✅ Load stopped"
echo ""

# ============================================================================
# Reset web-stress service
# ============================================================================
echo "Resetting web-stress service to 1 replica..."
ssh master "docker service update --replicas 1 web-stress" 2>/dev/null || true
sleep 5

echo "✅ web-stress reset to 1 replica"
echo ""

# ============================================================================
# Show current state
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Current Docker services:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ssh master "docker service ls"
echo ""

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                       CLEANUP COMPLETE                               ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║  Ready for next demo!                                                ║"
echo "║                                                                      ║"
echo "║  Available demos:                                                    ║"
echo "║    ./demo_baseline.sh   - Baseline (SwarmGuard OFF)                  ║"
echo "║    ./demo_scenario1.sh  - Proactive Migration (SwarmGuard ON)        ║"
echo "║    ./demo_scenario2.sh  - Horizontal Autoscaling (SwarmGuard ON)     ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
