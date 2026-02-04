#!/bin/bash
# ============================================================================
# VIEWER: Recovery Manager Logs
# ============================================================================
# Shows real-time logs from recovery-manager (SwarmGuard decisions)
# Use: Run in a separate terminal during Scenario 1 & 2 demos
# NOTE: SwarmGuard must be ENABLED (recovery-manager=1) for logs to appear
# ============================================================================

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                 RECOVERY MANAGER LOGS VIEWER                         ║"
echo "║  Shows SwarmGuard decisions (migration, scaling)                     ║"
echo "║  Press Ctrl+C to stop                                                ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if recovery-manager is running
REPLICAS=$(docker service ls --filter name=recovery-manager --format "{{.Replicas}}" 2>/dev/null)

if [ "$REPLICAS" = "0/0" ] || [ -z "$REPLICAS" ]; then
    echo "⚠️  WARNING: recovery-manager is NOT running (0/0 replicas)"
    echo ""
    echo "To enable SwarmGuard, run:"
    echo "  docker service scale recovery-manager=1"
    echo "  docker service scale monitoring-agent-master=1"
    echo "  docker service scale monitoring-agent-worker1=1"
    echo "  docker service scale monitoring-agent-worker2=1"
    echo "  docker service scale monitoring-agent-worker3=1"
    echo "  docker service scale monitoring-agent-worker4=1"
    echo ""
    echo "Or run: ./03_enable_swarmguard.sh"
    echo ""
    exit 1
fi

echo "SwarmGuard is ENABLED. Streaming logs..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

docker service logs -f recovery-manager --tail 30
