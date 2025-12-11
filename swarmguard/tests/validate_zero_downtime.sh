#!/bin/bash
# SwarmGuard Zero-Downtime Validation
# Continuously monitors service health during recovery actions

set -e

echo "=========================================="
echo "SwarmGuard Zero-Downtime Validator"
echo "=========================================="
echo ""

# Configuration
SERVICE_URL="http://192.168.2.50:8080"
CHECK_INTERVAL=0.5  # Check every 500ms
TOTAL_CHECKS=0
FAILED_CHECKS=0
START_TIME=$(date +%s)

echo "Target: $SERVICE_URL/health"
echo "Check interval: ${CHECK_INTERVAL}s"
echo ""
echo "Press Ctrl+C to stop monitoring"
echo ""
echo "Time      | Status | Response Time | Uptime"
echo "----------|--------|---------------|--------"

# Trap Ctrl+C to show summary
trap 'show_summary' INT

show_summary() {
    echo ""
    echo "=========================================="
    echo "ZERO-DOWNTIME VALIDATION SUMMARY"
    echo "=========================================="

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    SUCCESS_RATE=$(awk "BEGIN {printf \"%.2f\", (($TOTAL_CHECKS - $FAILED_CHECKS) / $TOTAL_CHECKS) * 100}")

    echo "Duration:        ${DURATION}s"
    echo "Total checks:    $TOTAL_CHECKS"
    echo "Failed checks:   $FAILED_CHECKS"
    echo "Success rate:    ${SUCCESS_RATE}%"
    echo ""

    if [ "$FAILED_CHECKS" -eq 0 ]; then
        echo "✓ ZERO DOWNTIME ACHIEVED"
        echo "No failed health checks detected"
    else
        echo "✗ DOWNTIME DETECTED"
        echo "$FAILED_CHECKS failed health checks"
        DOWNTIME_MS=$(awk "BEGIN {printf \"%.0f\", $FAILED_CHECKS * $CHECK_INTERVAL * 1000}")
        echo "Estimated downtime: ~${DOWNTIME_MS}ms"
    fi
    echo "=========================================="

    exit 0
}

# Continuous health check loop
while true; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    REQUEST_START=$(date +%s.%N)

    # Make health check request
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 "$SERVICE_URL/health" 2>/dev/null || echo "000")

    REQUEST_END=$(date +%s.%N)
    RESPONSE_TIME=$(awk "BEGIN {printf \"%.0f\", ($REQUEST_END - $REQUEST_START) * 1000}")
    CURRENT_TIME=$(date +%H:%M:%S)
    UPTIME=$(($(date +%s) - START_TIME))

    # Check if request succeeded
    if [ "$HTTP_CODE" = "200" ]; then
        STATUS="✓ OK "
    else
        STATUS="✗ FAIL"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    # Print status line
    printf "%s | %s   | %4dms         | %4ds\n" "$CURRENT_TIME" "$STATUS" "$RESPONSE_TIME" "$UPTIME"

    # Sleep before next check
    sleep "$CHECK_INTERVAL"
done
