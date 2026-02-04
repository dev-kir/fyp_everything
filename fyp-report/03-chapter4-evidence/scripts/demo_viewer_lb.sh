#!/bin/bash
# ============================================================================
# VIEWER: Load Balancer Distribution (for Scenario 2)
# ============================================================================
# Shows traffic distribution across replicas
# Use: Run in a separate terminal during Scenario 2 demo
# ============================================================================

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                 LOAD BALANCER DISTRIBUTION VIEWER                    ║"
echo "║  Watch for: Traffic splits ~50/50 when 2 replicas are running        ║"
echo "║  Press Ctrl+C to stop                                                ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if monitor script exists
if [ -f "/Users/amirmuz/fyp_everything/swarmguard/tests/monitor_lb_distribution.sh" ]; then
    cd /Users/amirmuz/fyp_everything/swarmguard
    ./tests/monitor_lb_distribution.sh
else
    echo "Fallback: Using direct metrics query..."
    echo ""
    echo "TIME      BACKENDS  DISTRIBUTION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    while true; do
      ts=$(date '+%H:%M:%S')
      metrics=$(curl -s http://192.168.2.50:8081/metrics 2>/dev/null)

      if [ -z "$metrics" ]; then
        echo "$ts  ❌ LB not responding"
      else
        backends=$(echo "$metrics" | jq -r '.active_backends // "N/A"' 2>/dev/null)
        echo "$ts  $backends backends active"
      fi

      sleep 3
    done
fi
