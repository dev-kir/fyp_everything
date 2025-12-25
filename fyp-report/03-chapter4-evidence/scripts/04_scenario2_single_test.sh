#!/bin/bash
# Section 4: Scenario 2 (Horizontal Autoscaling) - Single Test
# Usage: ./04_scenario2_single_test.sh [test_number]
# Example: ./04_scenario2_single_test.sh 1

set -e

TEST_NUM=${1:-1}

echo "=== Scenario 2 Test $TEST_NUM (Horizontal Autoscaling) ==="

# Create output directory
OUTPUT_DIR="/Users/amirmuz/RESULT_FYP_EVERYTHING"
mkdir -p "$OUTPUT_DIR"

# Clean any existing load
echo "Cleaning existing load..."
curl -s "http://192.168.2.50:8080/stress/stop" > /dev/null
for alpine in alpine-1 alpine-2 alpine-3 alpine-4 alpine-5; do
    ssh "$alpine" "pkill -9 -f wget" 2>/dev/null || true
    ssh "$alpine" "pkill -9 -f scenario2_alpine_user.sh" 2>/dev/null || true
done
sleep 20

# Record initial state
echo "Recording initial state..."
echo "Test $TEST_NUM - START: $(date -Iseconds)" > "$OUTPUT_DIR/04_scenario2_test${TEST_NUM}.log"
ssh master "docker service ls" > "$OUTPUT_DIR/04_scenario2_initial_services_test${TEST_NUM}.txt"
echo "Initial replica count:" >> "$OUTPUT_DIR/04_scenario2_test${TEST_NUM}.log"
ssh master "docker service ls | grep web-stress" >> "$OUTPUT_DIR/04_scenario2_test${TEST_NUM}.log"

# Start replica count monitoring in background
echo "Starting replica count monitoring..."
(
while true; do
  ts=$(date -Iseconds)
  replicas=$(ssh master "docker service ls --format '{{.Replicas}}' --filter name=web-stress" | head -n 1)
  echo "$ts $replicas"
  sleep 2
done
) > "$OUTPUT_DIR/04_scenario2_replicas_test${TEST_NUM}.log" &
REPLICA_MONITOR_PID=$!

# Start load balancer metrics monitoring in background
echo "Starting load balancer metrics monitoring..."
(
while true; do
  ts=$(date -Iseconds)
  metrics=$(curl -s http://192.168.2.50:8081/metrics 2>/dev/null || echo "{}")
  echo "$ts $metrics"
  sleep 5
done
) > "$OUTPUT_DIR/04_scenario2_lb_metrics_test${TEST_NUM}.log" &
LB_MONITOR_PID=$!

sleep 10

# Trigger Scenario 2 load test (Network + CPU/Memory via Alpine downloads)
echo "Triggering Scenario 2 high-traffic load test..."
echo "Parameters: Continuous 50MB downloads from 5 Alpine nodes (sustained >65 Mbps network)"
echo "This will stress Network (>65Mbps) + CPU/Memory from handling requests"
echo "Test $TEST_NUM - LOAD_STARTED: $(date -Iseconds)" >> "$OUTPUT_DIR/04_scenario2_test${TEST_NUM}.log"

# Start continuous download traffic from Alpine nodes
echo "Starting continuous download traffic from Alpine nodes..."
for alpine in alpine-1 alpine-2 alpine-3 alpine-4 alpine-5; do
    echo "Starting downloads on $alpine..."
    # Each Alpine runs 3 concurrent curl loops downloading 50MB files continuously
    ssh "$alpine" "for i in 1 2 3; do while true; do curl -s 'http://192.168.2.50:8080/download/data?size_mb=50&cpu_work=0' > /dev/null 2>&1; done & done" &
done

echo "✓ Network load triggered from Alpine nodes (5 nodes × 3 workers = 15 concurrent downloads)"
echo "Expected: Sustained >65 Mbps network + high CPU/Memory from serving requests"

echo "SwarmGuard should detect increased load and scale replicas..."
echo "Waiting for load to ramp up (2 minutes)..."
sleep 120

echo "Load should be building now. Monitoring for 10 minutes to capture scaling..."
# Monitor for 10 minutes (600 seconds) to capture scale-up
sleep 600

# Stop load
echo "Stopping load test..."
echo "Killing curl download processes on Alpine nodes..."
for alpine in alpine-1 alpine-2 alpine-3 alpine-4 alpine-5; do
    ssh "$alpine" "pkill -9 -f 'curl.*download/data'" 2>/dev/null || true
    echo "✓ Stopped downloads on $alpine"
done

echo "Test $TEST_NUM - LOAD_STOPPED: $(date -Iseconds)" >> "$OUTPUT_DIR/04_scenario2_test${TEST_NUM}.log"

# Wait for scale-down
echo "Waiting 3 minutes for scale-down to occur..."
sleep 180

# Stop monitoring
kill $REPLICA_MONITOR_PID 2>/dev/null || true
kill $LB_MONITOR_PID 2>/dev/null || true

echo "Test $TEST_NUM - MONITORING_STOPPED: $(date -Iseconds)" >> "$OUTPUT_DIR/04_scenario2_test${TEST_NUM}.log"

# Capture final state
echo "Capturing final state..."
ssh master "docker service ls" > "$OUTPUT_DIR/04_scenario2_final_services_test${TEST_NUM}.txt"
ssh master "docker service ps web-stress --no-trunc" > "$OUTPUT_DIR/04_scenario2_service_history_test${TEST_NUM}.txt"

# Capture recovery manager logs
echo "Capturing recovery manager logs..."
ssh master "docker service logs recovery-manager --tail 100" > "$OUTPUT_DIR/04_scenario2_recovery_logs_test${TEST_NUM}.txt" 2>&1

echo "Scenario 2 test $TEST_NUM complete!"
echo "Results in:"
echo "  - $OUTPUT_DIR/04_scenario2_test${TEST_NUM}.log"
echo "  - $OUTPUT_DIR/04_scenario2_replicas_test${TEST_NUM}.log (replica count timeline)"
echo "  - $OUTPUT_DIR/04_scenario2_lb_metrics_test${TEST_NUM}.log (load balancer metrics)"
echo "  - $OUTPUT_DIR/04_scenario2_recovery_logs_test${TEST_NUM}.txt"
echo "  - $OUTPUT_DIR/04_scenario2_service_history_test${TEST_NUM}.txt"
