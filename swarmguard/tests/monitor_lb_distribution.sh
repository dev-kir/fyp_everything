#!/bin/bash
# Monitor load balancer request distribution in real-time
# Shows how requests are distributed across replicas after scaling
#
# Usage: ./monitor_lb_distribution.sh

echo "=========================================="
echo "Load Balancer Distribution Monitor"
echo "Press Ctrl+C to stop"
echo "=========================================="
echo ""

# File to store previous counts between iterations
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
  response=$(curl -s http://192.168.2.50:8081/metrics)

  # Extract basic info
  total_requests=$(echo "$response" | jq -r '.total_requests')
  algorithm=$(echo "$response" | jq -r '.algorithm')
  healthy_replicas=$(echo "$response" | jq -r '.healthy_replicas')

  echo "Algorithm: $algorithm"
  echo "Healthy Replicas: $healthy_replicas"
  echo "Total Requests: $total_requests"
  echo ""
  echo "=========================================="
  echo "Per-Replica Distribution:"
  echo "=========================================="

  # Temporary file for new counts
  NEW_FILE="/tmp/lb_monitor_new.txt"
  rm -f "$NEW_FILE"

  # Parse replica stats and display
  echo "$response" | jq -r '.replica_stats | to_entries[] |
    "\(.key)|\(.value.request_count)|\(.value.active_leases)"' | \
  while IFS='|' read -r replica_id req_count active_leases; do
    # Extract node name (e.g., worker-2)
    node=$(echo "$replica_id" | cut -d':' -f1)

    # Save current count for next iteration
    echo "$node:$req_count" >> "$NEW_FILE"

    # Get previous count
    prev_count=0
    if [ -f "$PREV_FILE" ]; then
      prev_count=$(grep "^$node:" "$PREV_FILE" 2>/dev/null | cut -d':' -f2)
      prev_count=${prev_count:-0}
    fi

    # Calculate delta
    delta=$((req_count - prev_count))

    # Calculate percentage of total
    if [ "$total_requests" -gt 0 ]; then
      percentage=$(awk "BEGIN {printf \"%.1f\", ($req_count / $total_requests) * 100}")
    else
      percentage="0.0"
    fi

    # Display
    if [ "$delta" -gt 0 ]; then
      printf "  %-12s: %6d requests (%5s%%) | +%-4d new | leases: %d\n" \
        "$node" "$req_count" "$percentage" "$delta" "$active_leases"
    else
      printf "  %-12s: %6d requests (%5s%%) |  %-4s    | leases: %d\n" \
        "$node" "$req_count" "$percentage" "-" "$active_leases"
    fi
  done

  # Update previous counts file for next iteration
  if [ -f "$NEW_FILE" ]; then
    mv "$NEW_FILE" "$PREV_FILE"
  fi

  echo ""
  echo "=========================================="
  echo "Distribution Analysis:"
  echo "=========================================="

  # Calculate distribution evenness
  if [ "$healthy_replicas" -gt 1 ]; then
    expected_per_replica=$(awk "BEGIN {printf \"%.0f\", $total_requests / $healthy_replicas}")
    echo "  Expected per replica: ~$expected_per_replica requests"
    echo "  (for perfect distribution)"
  fi

  echo ""
  echo "Next update in 2 seconds..."

  sleep 2
done
