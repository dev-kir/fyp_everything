#!/bin/bash
# ============================================================================
# VIEWER: Service Status
# ============================================================================
# Shows web-stress service status with node placement and state
# Use: Run in a separate terminal during demos
# ============================================================================

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                    SERVICE STATUS VIEWER                             ║"
echo "║  Press Ctrl+C to stop                                                ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

while true; do
    clear
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                    SERVICE STATUS VIEWER                             ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "SERVICE: web-stress                          $(date '+%H:%M:%S')"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ssh master "docker service ps web-stress --format 'table {{.Name}}\t{{.Node}}\t{{.DesiredState}}\t{{.CurrentState}}\t{{.Error}}'" 2>/dev/null | head -n 10
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "REPLICAS:"
    ssh master "docker service ls --filter name=web-stress --format 'table {{.Name}}\t{{.Replicas}}\t{{.Image}}'" 2>/dev/null
    sleep 1
done
