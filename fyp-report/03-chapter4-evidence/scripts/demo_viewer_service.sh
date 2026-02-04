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

watch -n 1 --color 'echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SERVICE: web-stress"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker service ps web-stress --format "table {{.Name}}\t{{.Node}}\t{{.DesiredState}}\t{{.CurrentState}}\t{{.Error}}" | head -n 10
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "REPLICAS:"
docker service ls --filter name=web-stress --format "table {{.Name}}\t{{.Replicas}}\t{{.Image}}"'
