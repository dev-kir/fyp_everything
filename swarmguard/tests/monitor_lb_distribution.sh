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

# Store previous values to calculate deltas
declare -A prev_counts

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

  # Parse replica stats
  echo "$response" | jq -r '.replica_stats | to_entries[] |
    "\(.key)|\(.value.request_count)|\(.value.active_leases)"' | \
  while IFS='|' read -r replica_id req_count active_leases; do
    # Extract node name (e.g., worker-2)
    node=$(echo "$replica_id" | cut -d':' -f1)

    # Calculate delta (new requests since last check)
    prev_count=${prev_counts[$node]:-0}
    delta=$((req_count - prev_count))
    prev_counts[$node]=$req_count

    # Calculate percentage of total
    if [ "$total_requests" -gt 0 ]; then
      percentage=$(awk "BEGIN {printf \"%.1f\", ($req_count / $total_requests) * 100}")
    else
      percentage="0.0"
    fi

    # Display with color based on delta
    if [ "$delta" -gt 0 ]; then
      printf "  %-12s: %6d requests (%5s%%) | +%-4d new | leases: %d\n" \
        "$node" "$req_count" "$percentage" "$delta" "$active_leases"
    else
      printf "  %-12s: %6d requests (%5s%%) |  %-4s    | leases: %d\n" \
        "$node" "$req_count" "$percentage" "-" "$active_leases"
    fi
  done

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
