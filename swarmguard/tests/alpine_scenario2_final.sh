#!/bin/bash
# Alpine Scenario 2 - Final Working Test
# Uses /stress/combined endpoint triggered from Alpine nodes
#
# Usage:
#   ./alpine_scenario2_final.sh [CPU%] [MEMORY_MB] [NETWORK_MBPS] [DURATION]
#
# Examples:
#   ./alpine_scenario2_final.sh 85 1200 80 180

set -e

echo "=========================================="
echo "Scenario 2: Final Test (stress/combined)"
echo "=========================================="
echo ""

# Configuration
TARGET_CPU=${1:-85}           # Target CPU% (default: 85%)
TARGET_MEMORY=${2:-1200}      # Target Memory MB (default: 1200MB)
TARGET_NETWORK=${3:-80}       # Target Network Mbps (default: 80Mbps)
DURATION=${4:-180}            # Duration in seconds (default: 180s)
RAMP=${5:-30}                 # Ramp-up time (default: 30s)

SERVICE_URL="http://192.168.2.50:8080"

echo "Configuration:"
echo "  Target CPU:     ${TARGET_CPU}%"
echo "  Target Memory:  ${TARGET_MEMORY}MB"
echo "  Target Network: ${TARGET_NETWORK}Mbps"
echo "  Ramp-up time:   ${RAMP}s"
echo "  Duration:       ${DURATION}s"
echo ""

# Get initial state
echo "[1/2] Initial state:"
INITIAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo "  web-stress replicas: $INITIAL_REPLICAS"
echo ""

# Start stress test
echo "[2/2] Triggering stress/combined endpoint..."
echo ""
echo "📊 OPEN GRAFANA NOW:"
echo "   → http://192.168.2.61:3000"
echo "   → Dashboard: Container Metrics"
echo ""
echo "Expected behavior:"
echo "  T+0s:    Stress starts ramping up"
echo "  T+${RAMP}s:  CPU=${TARGET_CPU}%, MEM=${TARGET_MEMORY}MB, NET=${TARGET_NETWORK}Mbps (peak load)"
echo "  T+60s:   Recovery manager detects HIGH CPU+MEM+NET → Scenario 2"
echo "  T+90s:   System scales 1→2 replicas"
echo "  T+120s:  Load visible across 2 replicas in Grafana"
echo ""

# Trigger stress in background
curl -s "http://192.168.2.50:8080/stress/combined?cpu=${TARGET_CPU}&memory=${TARGET_MEMORY}&network=${TARGET_NETWORK}&duration=${DURATION}&ramp=${RAMP}" | jq . &
STRESS_PID=$!

echo "✓ Stress test started (PID: $STRESS_PID)"
echo ""

# Monitor
echo "Monitoring for ${DURATION}s..."
echo ""
START_TIME=$(date +%s)
LAST_REPLICAS=$INITIAL_REPLICAS

while true; do
    sleep 15
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    if [ $ELAPSED -ge $DURATION ]; then
        break
    fi

    CURRENT=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")

    if [ "$CURRENT" != "$LAST_REPLICAS" ]; then
        echo ""
        echo "✅ SCALE EVENT: $LAST_REPLICAS → $CURRENT replicas"
        echo "   → Check Grafana to see load distribution"
        echo ""
        LAST_REPLICAS=$CURRENT
    else
        echo "[+${ELAPSED}s] Replicas: $CURRENT | Check Grafana: CPU/MEM/NET"
    fi
done

# Wait for stress to complete
wait $STRESS_PID 2>/dev/null || true

echo ""
echo "=========================================="
echo "Test Complete"
echo "=========================================="
echo ""

FINAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")

echo "Results:"
echo "  Initial replicas: $INITIAL_REPLICAS"
echo "  Final replicas:   $FINAL_REPLICAS"
echo "  Duration:         ${DURATION}s"
echo "  Peak load:        CPU=${TARGET_CPU}%, MEM=${TARGET_MEMORY}MB, NET=${TARGET_NETWORK}Mbps"
echo ""

ssh master "docker service ps web-stress --filter 'desired-state=running' --format 'table {{.Name}}\t{{.Node}}'"
echo ""

echo "✅ Scenario 2 test complete!"
echo ""
echo "Note: Wait ~4 minutes for automatic scale-down to baseline"
echo ""

exit 0
