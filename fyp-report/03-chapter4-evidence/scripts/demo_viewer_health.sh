#!/bin/bash
# ============================================================================
# VIEWER: Health Check (Downtime Monitor)
# ============================================================================
# Shows real-time health status - DOWN = service unavailable
# Use: Run in a separate terminal during demos
# ============================================================================

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                    HEALTH CHECK VIEWER                               ║"
echo "║  200 = OK | DOWN = Service Unavailable                               ║"
echo "║  Press Ctrl+C to stop                                                ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "TIME      STATUS"
echo "━━━━━━━━━━━━━━━━━"

while true; do
  ts=$(date '+%H:%M:%S')
  code=$(curl -sf --connect-timeout 0.5 -m 1 -o /dev/null -w '%{http_code}' http://192.168.2.50:8080/health 2>/dev/null || echo "DOWN")

  if [ "$code" = "DOWN" ]; then
    echo -e "$ts  \033[31m❌ DOWN\033[0m"
  else
    echo -e "$ts  \033[32m✅ $code\033[0m"
  fi

  sleep 0.5
done
