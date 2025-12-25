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

# Clean any existing load first
echo "Cleaning existing load..."
curl -s "http://192.168.2.50:8080/stress/stop" > /dev/null 2>&1 || true
for alpine in alpine-1 alpine-2 alpine-3 alpine-4 alpine-5; do
    ssh "$alpine" "pkill -9 -f wget" 2>/dev/null || true
    ssh "$alpine" "pkill -9 -f scenario2_alpine_user.sh" 2>/dev/null || true
done

# Reset: Deploy fresh web-stress service for clean state
echo "Deploying fresh web-stress service..."
ssh master "docker service rm web-stress" || true
sleep 10
cd /Users/amirmuz/fyp_everything/swarmguard
./tests/deploy_web_stress.sh 1 30
sleep 30
cd /Users/amirmuz/fyp_everything/fyp-report/03-chapter4-evidence/scripts

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

# Trigger Scenario 2 load test using scenario2_ultimate.sh (HYBRID APPROACH)
echo "Triggering Scenario 2 high-traffic load test using scenario2_ultimate.sh..."
echo "Parameters: 12 users/alpine, CPU=2%, Memory=8MB, Network=12Mbps per user"
echo "Total: 60 simulated users (5 Alpines × 12 users)"
echo "Expected: ~200 Mbps Network, ~70% CPU, ~20% Memory (sustained, distributed load)"
echo "HYBRID: Each user runs continuous downloads (network) + /stress/combined (CPU/Memory)"
echo "Network threshold: 65 Mbps | CPU threshold: 75%"
echo "Test $TEST_NUM - LOAD_STARTED: $(date -Iseconds)" >> "$OUTPUT_DIR/04_scenario2_test${TEST_NUM}.log"

# Start the scenario2_ultimate script in background
cd /Users/amirmuz/fyp_everything/swarmguard
nohup ./tests/scenario2_ultimate.sh 12 2 8 12 2 60 900 > "$OUTPUT_DIR/04_scenario2_ultimate_output_test${TEST_NUM}.log" 2>&1 &
SCENARIO2_PID=$!
cd /Users/amirmuz/fyp_everything/fyp-report/03-chapter4-evidence/scripts

echo "✓ Scenario 2 ultimate script started (PID: $SCENARIO2_PID)"
echo "Expected: 60 users creating sustained network load (downloads + stress requests)"
echo "Expected: Load distribution ~50/50 across replicas after scaling 1→2"

echo "SwarmGuard should detect increased load and scale replicas..."
echo "Waiting for load to ramp up (2 minutes)..."
sleep 120

echo "Load should be building now. Monitoring for 10 minutes to capture scaling..."
# Monitor for 10 minutes (600 seconds) to capture scale-up
sleep 600

# Stop load
echo "Stopping load test..."
echo "Killing scenario2_ultimate processes..."

# Kill the scenario2 script if still running
kill $SCENARIO2_PID 2>/dev/null || true

# Cleanup Alpine nodes (scenario2_ultimate.sh cleanup)
curl -s "http://192.168.2.50:8080/stress/stop" > /dev/null || true
for alpine in alpine-1 alpine-2 alpine-3 alpine-4 alpine-5; do
    ssh "$alpine" "pkill -9 -f wget" 2>/dev/null || true
    ssh "$alpine" "pkill -9 -f scenario2_alpine_user.sh" 2>/dev/null || true
done
echo "✓ Stopped all Alpine load generation"

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
