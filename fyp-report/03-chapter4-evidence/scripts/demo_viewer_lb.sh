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

echo "TIME      REPLICAS  REQUESTS   DISTRIBUTION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

while true; do
  ts=$(date '+%H:%M:%S')
  metrics=$(curl -s http://192.168.2.50:8081/metrics 2>/dev/null)

  if [ -z "$metrics" ]; then
    echo "$ts  ❌ LB not responding"
  else
    replicas=$(echo "$metrics" | jq -r '.healthy_replicas // "N/A"' 2>/dev/null || echo "N/A")
    requests=$(echo "$metrics" | jq -r '.total_requests // "N/A"' 2>/dev/null || echo "N/A")
    # Get per-replica request counts
    distribution=$(echo "$metrics" | jq -r '.replica_stats | to_entries | map("\(.value.node):\(.value.request_count)") | join(" | ")' 2>/dev/null || echo "N/A")
    echo "$ts  $replicas healthy | $requests total | $distribution"
  fi

  sleep 3
done
