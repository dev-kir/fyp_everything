#!/bin/bash
# ============================================================================
# VIEWER: Replica Count (for Scenario 2 - Autoscaling)
# ============================================================================
# Shows real-time replica count for web-stress service
# Use: Run in a separate terminal during Scenario 2 demo
# ============================================================================

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                    REPLICA COUNT VIEWER                              ║"
echo "║  Watch for: 1/1 → 2/2 (scale up) → 1/1 (scale down)                  ║"
echo "║  Press Ctrl+C to stop                                                ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "TIME      REPLICAS"
echo "━━━━━━━━━━━━━━━━━━━━"

while true; do
  ts=$(date '+%H:%M:%S')
  replicas=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}'" 2>/dev/null | head -n 1)

  if [ -z "$replicas" ]; then
    echo "$ts  ❌ Service not found"
  elif [ "$replicas" = "1/1" ]; then
    echo -e "$ts  \033[33m$replicas\033[0m (single replica)"
  elif [[ "$replicas" == "2/"* ]]; then
    echo -e "$ts  \033[32m$replicas\033[0m ← SCALED UP!"
  else
    echo "$ts  $replicas"
  fi

  sleep 2
done
