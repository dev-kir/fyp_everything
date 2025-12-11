#!/bin/bash
# SwarmGuard MTTR Measurement - Precision Timing
# Measures Mean Time To Recovery with millisecond precision

set -e

echo "=========================================="
echo "SwarmGuard MTTR Measurement"
echo "=========================================="
echo ""

# Configuration
SERVICE_URL="http://192.168.2.50:8080"
INFLUXDB_URL="http://192.168.2.61:8086"
INFLUXDB_TOKEN="iNCff-dYnCY8oiO_mDIn3tMIEdl5D1Z4_KFE2vwTMFtQoTqGh2SbL5msNB30DIOKE2wwj-maBW5lTZVJ3f9ONA=="

# Detect scenario from command line
SCENARIO=${1:-scenario1}

if [ "$SCENARIO" = "scenario1" ]; then
    echo "Scenario: 1 - Proactive Failover (Migration)"
    STRESS_PARAMS="cpu=90&memory=900&network=5"
    echo "Stress: CPU=90%, Memory=900MB, Network=5Mbps (LOW)"
elif [ "$SCENARIO" = "scenario2" ]; then
    echo "Scenario: 2 - Autoscaling (Scale-Up)"
    STRESS_PARAMS="cpu=90&memory=900&network=70"
    echo "Stress: CPU=90%, Memory=900MB, Network=70Mbps (HIGH)"
else
    echo "Usage: $0 [scenario1|scenario2]"
    exit 1
fi

echo "Duration: 180s, Ramp: 10s"
echo ""

# Record initial state
echo "[1/6] Recording initial state..."
INITIAL_NODE=$(ssh master "docker service ps web-stress --format '{{.Node}}' | head -1")
INITIAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo "✓ Initial node: $INITIAL_NODE"
echo "✓ Initial replicas: $INITIAL_REPLICAS"
echo ""

# Start continuous health monitoring in background
echo "[2/6] Starting health monitoring..."
HEALTH_LOG="/tmp/mttr_health_$(date +%s).log"
(
    while true; do
        TIMESTAMP=$(date +%s.%N)
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 "$SERVICE_URL/health" 2>/dev/null || echo "000")
        echo "$TIMESTAMP,$HTTP_CODE" >> "$HEALTH_LOG"
        sleep 0.5
    done
) &
HEALTH_PID=$!
echo "✓ Health monitoring started (PID: $HEALTH_PID)"
echo ""

# Trigger stress test and record start time
echo "[3/6] Triggering stress test..."
STRESS_START=$(date +%s.%N)
curl -s "$SERVICE_URL/stress/combined?${STRESS_PARAMS}&duration=180&ramp=10" > /dev/null
echo "✓ Stress test started at $(date +%H:%M:%S.%3N)"
echo ""

# Wait for ramp-up
echo "[4/6] Waiting 15s for ramp-up..."
sleep 15
echo "✓ Ramp-up complete"
echo ""

# Wait for recovery action
echo "[5/6] Waiting for recovery action (up to 60s)..."
RECOVERY_DETECTED=0
for i in {1..120}; do
    sleep 0.5

    if [ "$SCENARIO" = "scenario1" ]; then
        # Check for node change
        CURRENT_NODE=$(ssh master "docker service ps web-stress --format '{{.Node}}' | head -1")
        if [ "$CURRENT_NODE" != "$INITIAL_NODE" ]; then
            RECOVERY_END=$(date +%s.%N)
            RECOVERY_DETECTED=1
            echo "✓ Migration detected at $(date +%H:%M:%S.%3N)"
            echo "  $INITIAL_NODE → $CURRENT_NODE"
            break
        fi
    else
        # Check for replica increase
        CURRENT_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
        if [ "$CURRENT_REPLICAS" -gt "$INITIAL_REPLICAS" ]; then
            RECOVERY_END=$(date +%s.%N)
            RECOVERY_DETECTED=1
            echo "✓ Scale-up detected at $(date +%H:%M:%S.%3N)"
            echo "  $INITIAL_REPLICAS → $CURRENT_REPLICAS replicas"
            break
        fi
    fi
done
echo ""

# Stop health monitoring
kill $HEALTH_PID 2>/dev/null
wait $HEALTH_PID 2>/dev/null || true

# Calculate MTTR
echo "[6/6] Calculating MTTR..."
if [ "$RECOVERY_DETECTED" -eq 1 ]; then
    # MTTR = time from stress start to recovery completion
    MTTR=$(awk "BEGIN {printf \"%.3f\", $RECOVERY_END - $STRESS_START}")
    MTTR_MS=$(awk "BEGIN {printf \"%.0f\", $MTTR * 1000}")

    echo "✓ MTTR calculated"
    echo ""

    # Analyze health check logs for downtime
    echo "Analyzing health checks..."
    TOTAL_CHECKS=$(wc -l < "$HEALTH_LOG")
    FAILED_CHECKS=$(grep -c ",000\|,500\|,502\|,503" "$HEALTH_LOG" || echo "0")
    SUCCESS_RATE=$(awk "BEGIN {printf \"%.2f\", (($TOTAL_CHECKS - $FAILED_CHECKS) / $TOTAL_CHECKS) * 100}")

    # Find first and last failure times for downtime window
    if [ "$FAILED_CHECKS" -gt 0 ]; then
        FIRST_FAILURE=$(grep ",000\|,500\|,502\|,503" "$HEALTH_LOG" | head -1 | cut -d',' -f1)
        LAST_FAILURE=$(grep ",000\|,500\|,502\|,503" "$HEALTH_LOG" | tail -1 | cut -d',' -f1)
        DOWNTIME=$(awk "BEGIN {printf \"%.3f\", $LAST_FAILURE - $FIRST_FAILURE}")
        DOWNTIME_MS=$(awk "BEGIN {printf \"%.0f\", $DOWNTIME * 1000}")
    else
        DOWNTIME=0
        DOWNTIME_MS=0
    fi

    echo "✓ Health analysis complete"
    echo ""

    # Print results
    echo "=========================================="
    echo "MTTR MEASUREMENT RESULTS"
    echo "=========================================="
    echo "Scenario:        $SCENARIO"
    echo ""
    echo "MTTR:            ${MTTR}s (${MTTR_MS}ms)"
    echo "Target:          < 10s"
    if (( $(awk "BEGIN {print ($MTTR < 10) ? 1 : 0}") )); then
        echo "Status:          ✓ PASS"
    else
        echo "Status:          ✗ FAIL"
    fi
    echo ""
    echo "Health Checks:"
    echo "  Total:         $TOTAL_CHECKS"
    echo "  Failed:        $FAILED_CHECKS"
    echo "  Success rate:  ${SUCCESS_RATE}%"
    echo "  Downtime:      ${DOWNTIME}s (${DOWNTIME_MS}ms)"
    echo ""

    if [ "$FAILED_CHECKS" -eq 0 ]; then
        echo "✓ ZERO DOWNTIME ACHIEVED"
    else
        echo "⚠ DOWNTIME DETECTED: ${DOWNTIME_MS}ms"
    fi
    echo "=========================================="

    # Clean up
    rm -f "$HEALTH_LOG"

    # Exit code based on MTTR target
    if (( $(awk "BEGIN {print ($MTTR < 10) ? 1 : 0}") )); then
        exit 0
    else
        exit 1
    fi
else
    echo "✗ Recovery not detected within 60s"
    echo ""
    echo "=========================================="
    echo "MTTR MEASUREMENT FAILED"
    echo "=========================================="
    echo "No recovery action detected"
    echo ""

    # Show debugging info
    echo "Recovery Manager logs:"
    ssh master "docker service logs recovery-manager --tail 20"

    # Clean up
    rm -f "$HEALTH_LOG"
    exit 1
fi
