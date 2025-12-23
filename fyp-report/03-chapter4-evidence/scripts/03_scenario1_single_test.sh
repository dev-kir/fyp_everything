#!/bin/bash
# Section 3: Scenario 1 (Proactive Migration) - Single Test
# Usage: ./03_scenario1_single_test.sh [test_number]
# Example: ./03_scenario1_single_test.sh 1

set -e

TEST_NUM=${1:-1}

echo "=== Scenario 1 Test $TEST_NUM (Proactive Migration) ==="

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
done > "$OUTPUT_DIR/03_scenario1_mttr_test${TEST_NUM}.log" &
MONITOR_PID=$!

echo "Monitoring started (PID: $MONITOR_PID)"
echo "Waiting 30 seconds for baseline..."
sleep 30

# Get initial container location
echo "Finding web-stress container..."
INITIAL_NODE=$(ssh master "docker service ps web-stress --filter 'desired-state=running' --format '{{.Node}}' | head -n 1")
echo "Initial node: $INITIAL_NODE"
echo "Test $TEST_NUM - Initial_Node: $INITIAL_NODE" >> "$OUTPUT_DIR/03_scenario1_mttr_test${TEST_NUM}.log"

# Trigger Scenario 1 gradual stress test (high CPU, high memory, no network)
echo "Triggering Scenario 1 gradual stress test..."
echo "Parameters: CPU=95%, Memory=25000MB, Network=0Mbps, Duration=120s, Ramp=45s"
echo "SwarmGuard is ENABLED - Should proactively migrate as degradation increases"
echo "Test $TEST_NUM - STRESS_STARTED: $(date -Iseconds)" >> "$OUTPUT_DIR/03_scenario1_mttr_test${TEST_NUM}.log"

curl -s "http://192.168.2.50:8080/stress/combined?cpu=95&memory=25000&network=0&duration=120&ramp=45" > /dev/null
echo "✓ Stress test triggered"

echo "SwarmGuard should detect gradual degradation and proactively migrate..."
echo "Waiting 180 seconds for gradual stress + proactive migration..."
sleep 180

# Stop monitoring
kill $MONITOR_PID
echo "Test $TEST_NUM - MONITORING_STOPPED: $(date -Iseconds)" >> "$OUTPUT_DIR/03_scenario1_mttr_test${TEST_NUM}.log"

# Capture recovery timeline
ssh master "docker service ps web-stress --no-trunc" > "$OUTPUT_DIR/03_scenario1_recovery_timeline_test${TEST_NUM}.txt"

# Capture recovery manager logs (last 50 lines to see migration decision)
echo "Capturing recovery manager logs..."
ssh master "docker service logs recovery-manager --tail 50" > "$OUTPUT_DIR/03_scenario1_recovery_logs_test${TEST_NUM}.txt" 2>&1

# Check final node location
FINAL_NODE=$(ssh master "docker service ps web-stress --filter 'desired-state=running' --format '{{.Node}}' | head -n 1")
echo "Final node: $FINAL_NODE" >> "$OUTPUT_DIR/03_scenario1_mttr_test${TEST_NUM}.log"

# Capture monitoring agent logs from initial node
echo "Capturing monitoring agent logs from $INITIAL_NODE..."
ssh master "docker service logs monitoring-agent-${INITIAL_NODE} --tail 50" > "$OUTPUT_DIR/03_scenario1_monitoring_logs_test${TEST_NUM}.txt" 2>&1

echo "Scenario 1 test $TEST_NUM complete!"
echo "Results in:"
echo "  - $OUTPUT_DIR/03_scenario1_mttr_test${TEST_NUM}.log"
echo "  - $OUTPUT_DIR/03_scenario1_recovery_timeline_test${TEST_NUM}.txt"
echo "  - $OUTPUT_DIR/03_scenario1_recovery_logs_test${TEST_NUM}.txt"
echo "  - $OUTPUT_DIR/03_scenario1_monitoring_logs_test${TEST_NUM}.txt"
