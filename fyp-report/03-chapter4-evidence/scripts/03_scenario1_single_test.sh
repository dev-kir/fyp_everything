#!/bin/bash
# Section 3: Scenario 1 (Proactive Migration) - Single Test
# Usage: ./03_scenario1_single_test.sh [test_number]
# Example: ./03_scenario1_single_test.sh 1

set -e

TEST_NUM=${1:-1}

echo "=== Scenario 1 Test $TEST_NUM (Proactive Migration) ==="

# Create output directory
mkdir -p ../raw_outputs

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
done > ../raw_outputs/03_scenario1_mttr_test${TEST_NUM}.log &
MONITOR_PID=$!

echo "Monitoring started (PID: $MONITOR_PID)"
echo "Waiting 30 seconds for baseline..."
sleep 30

# Get container location and ID
echo "Finding web-stress container..."
NODE=$(ssh master "docker service ps web-stress --filter 'desired-state=running' --format '{{.Node}}' | head -n 1")
echo "Container is running on node: $NODE"

CONTAINER_ID=$(ssh $NODE "docker ps --filter 'name=web-stress' --format '{{.ID}}' | head -n 1")
echo "Target container: $CONTAINER_ID"
echo "Test $TEST_NUM - Node: $NODE" >> ../raw_outputs/03_scenario1_mttr_test${TEST_NUM}.log
echo "Test $TEST_NUM - Container: $CONTAINER_ID" >> ../raw_outputs/03_scenario1_mttr_test${TEST_NUM}.log
echo "Test $TEST_NUM - FAILURE_INJECTED: $(date -Iseconds)" >> ../raw_outputs/03_scenario1_mttr_test${TEST_NUM}.log

echo "Injecting failure (killing container on $NODE)..."
echo "SwarmGuard should proactively migrate BEFORE complete failure..."
ssh $NODE "docker kill $CONTAINER_ID"

echo "Waiting 60 seconds for SwarmGuard proactive recovery..."
sleep 60

# Stop monitoring
kill $MONITOR_PID
echo "Test $TEST_NUM - MONITORING_STOPPED: $(date -Iseconds)" >> ../raw_outputs/03_scenario1_mttr_test${TEST_NUM}.log

# Capture recovery timeline
ssh master "docker service ps web-stress --no-trunc" > ../raw_outputs/03_scenario1_recovery_timeline_test${TEST_NUM}.txt

# Capture recovery manager logs (last 50 lines to see migration decision)
echo "Capturing recovery manager logs..."
ssh master "docker service logs recovery-manager --tail 50" > ../raw_outputs/03_scenario1_recovery_logs_test${TEST_NUM}.txt 2>&1

# Capture monitoring agent logs from the node where failure occurred
echo "Capturing monitoring agent logs from $NODE..."
ssh master "docker service logs monitoring-agent-${NODE} --tail 50" > ../raw_outputs/03_scenario1_monitoring_logs_test${TEST_NUM}.txt 2>&1

echo "Scenario 1 test $TEST_NUM complete!"
echo "Results in:"
echo "  - ../raw_outputs/03_scenario1_mttr_test${TEST_NUM}.log"
echo "  - ../raw_outputs/03_scenario1_recovery_timeline_test${TEST_NUM}.txt"
echo "  - ../raw_outputs/03_scenario1_recovery_logs_test${TEST_NUM}.txt"
echo "  - ../raw_outputs/03_scenario1_monitoring_logs_test${TEST_NUM}.txt"
