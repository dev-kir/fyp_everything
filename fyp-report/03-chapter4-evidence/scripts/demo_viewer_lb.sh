#!/bin/bash
# ============================================================================
# VIEWER: Load Balancer Distribution (for Scenario 2)
# ============================================================================
# Uses the existing monitor_lb_distribution.sh script which shows:
# - Per-replica request counts
# - Percentage distribution (50/50 when balanced)
# - Delta (new requests per interval)
# - Active leases
# ============================================================================

# Check if the script exists
SCRIPT_PATH="/Users/amirmuz/fyp_everything/swarmguard/tests/monitor_lb_distribution.sh"

if [ -f "$SCRIPT_PATH" ]; then
    echo "Using existing monitor_lb_distribution.sh..."
    echo ""
    exec "$SCRIPT_PATH"
else
    # Fallback: inline version
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                 LOAD BALANCER DISTRIBUTION VIEWER                    ║"
    echo "║  Watch for: Traffic splits ~50/50 when 2 replicas are running        ║"
    echo "║  Press Ctrl+C to stop                                                ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo ""

    PREV_FILE="/tmp/lb_monitor_prev.txt"
    rm -f "$PREV_FILE"

    while true; do
        clear
        echo "=========================================="
        echo "Load Balancer Request Distribution"
        echo "Time: $(date '+%H:%M:%S')"
        echo "=========================================="
        echo ""

        # Fetch metrics
        response=$(curl -s http://192.168.2.50:8081/metrics 2>/dev/null)

        if [ -z "$response" ]; then
            echo "❌ LB not responding at http://192.168.2.50:8081"
            sleep 2
            continue
        fi

        # Extract basic info
        total_requests=$(echo "$response" | jq -r '.total_requests // 0')
        algorithm=$(echo "$response" | jq -r '.algorithm // "unknown"')
        healthy_replicas=$(echo "$response" | jq -r '.healthy_replicas // 0')

        echo "Algorithm: $algorithm"
        echo "Healthy Replicas: $healthy_replicas"
        echo "Total Requests: $total_requests"
        echo ""
        echo "=========================================="
        echo "Per-Replica Distribution:"
        echo "=========================================="

        NEW_FILE="/tmp/lb_monitor_new.txt"
        rm -f "$NEW_FILE"

        # Parse replica stats and display
        echo "$response" | jq -r '.replica_stats | to_entries[] |
            "\(.key)|\(.value.request_count)|\(.value.active_leases)"' 2>/dev/null | \
        while IFS='|' read -r replica_id req_count active_leases; do
            node=$(echo "$replica_id" | cut -d':' -f1)
            echo "$node:$req_count" >> "$NEW_FILE"

            prev_count=0
            if [ -f "$PREV_FILE" ]; then
                prev_count=$(grep "^$node:" "$PREV_FILE" 2>/dev/null | tail -1 | cut -d':' -f2)
                prev_count=${prev_count:-0}
            fi

            req_count=$(echo "$req_count" | tr -d '[:space:]')
            prev_count=$(echo "$prev_count" | tr -d '[:space:]')
            req_count=${req_count:-0}
            prev_count=${prev_count:-0}

            delta=$((req_count - prev_count))

            if [ "$total_requests" -gt 0 ]; then
                percentage=$(awk "BEGIN {printf \"%.1f\", ($req_count / $total_requests) * 100}")
            else
                percentage="0.0"
            fi

            if [ "$delta" -gt 0 ]; then
                printf "  %-12s: %6d requests (%5s%%) | +%-4d new | leases: %d\n" \
                    "$node" "$req_count" "$percentage" "$delta" "$active_leases"
            else
                printf "  %-12s: %6d requests (%5s%%) |  %-4s    | leases: %d\n" \
                    "$node" "$req_count" "$percentage" "-" "$active_leases"
            fi
        done

        if [ -f "$NEW_FILE" ]; then
            mv "$NEW_FILE" "$PREV_FILE"
        fi

        echo ""
        echo "=========================================="
        echo "Distribution Analysis:"
        echo "=========================================="

        if [ "$healthy_replicas" -gt 1 ]; then
            expected_per_replica=$(awk "BEGIN {printf \"%.0f\", $total_requests / $healthy_replicas}")
            echo "  Expected per replica: ~$expected_per_replica requests"
            echo "  (for perfect 50/50 distribution)"
        else
            echo "  Single replica - no distribution yet"
            echo "  (wait for scale-up to see distribution)"
        fi

        echo ""
        echo "Next update in 2 seconds..."
        sleep 2
    done
fi
