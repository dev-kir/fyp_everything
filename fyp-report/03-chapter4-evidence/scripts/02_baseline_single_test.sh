#!/bin/bash
# Section 2: Baseline (Docker Swarm Reactive) - Single Test
# Usage: ./02_baseline_single_test.sh [test_number]
# Example: ./02_baseline_single_test.sh 1

set -e

TEST_NUM=${1:-1}

echo "=== Baseline Test $TEST_NUM ==="

# Create output directory
OUTPUT_DIR="/Users/amirmuz/RESULT_FYP_EVERYTHING"
mkdir -p "$OUTPUT_DIR"

# Reset: Deploy fresh web-stress
echo "Deploying fresh web-stress service..."
ssh master "docker service rm web-stress" || true
sleep 10
cd /Users/amirmuz/fyp_everything/swarmguard
./tests/deploy_web_stress.sh 1 30
sleep 30
cd /Users/amirmuz/fyp_everything/fyp-report/03-chapter4-evidence/scripts

# Start availability monitoring in background
echo "Starting availability monitoring..."
while sleep 0.1; do
  ts=$(date -Iseconds)
  code=$(curl -sf --connect-timeout 0.5 -m 1 -o /dev/null -w '%{http_code}' http://192.168.2.50:8080/health 2>/dev/null || echo "DOWN")
  echo "$ts $code"
done > "$OUTPUT_DIR/02_baseline_mttr_test${TEST_NUM}.log" &
MONITOR_PID=$!

echo "Monitoring started (PID: $MONITOR_PID)"
echo "Waiting 30 seconds for baseline..."
sleep 30

# Get initial container location
echo "Finding web-stress container..."
INITIAL_NODE=$(ssh master "docker service ps web-stress --filter 'desired-state=running' --format '{{.Node}}' | head -n 1")
echo "Initial node: $INITIAL_NODE"
echo "Test $TEST_NUM - Initial_Node: $INITIAL_NODE" >> "$OUTPUT_DIR/02_baseline_mttr_test${TEST_NUM}.log"

# Trigger CPU stress test (same as Scenario 1, but SwarmGuard is disabled)
echo "Triggering CPU stress test..."
echo "Parameters: CPU=90%, Memory=900MB, Network=5Mbps, Duration=180s"
echo "SwarmGuard is DISABLED - Docker Swarm will only react AFTER container crashes"
echo "Test $TEST_NUM - STRESS_STARTED: $(date -Iseconds)" >> "$OUTPUT_DIR/02_baseline_mttr_test${TEST_NUM}.log"

curl -s "http://192.168.2.50:8080/stress/combined?cpu=90&memory=900&network=5&duration=180&ramp=10" > /dev/null
echo "✓ Stress test triggered"

echo "Waiting 180 seconds for stress test + reactive recovery..."
sleep 180

# Stop monitoring
kill $MONITOR_PID
echo "Test $TEST_NUM - MONITORING_STOPPED: $(date -Iseconds)" >> "$OUTPUT_DIR/02_baseline_mttr_test${TEST_NUM}.log"

# Capture recovery timeline
ssh master "docker service ps web-stress --no-trunc" > "$OUTPUT_DIR/02_baseline_recovery_timeline_test${TEST_NUM}.txt"

echo "Baseline test $TEST_NUM complete!"
echo "Results in:"
echo "  - $OUTPUT_DIR/02_baseline_mttr_test${TEST_NUM}.log"
echo "  - $OUTPUT_DIR/02_baseline_recovery_timeline_test${TEST_NUM}.txt"
