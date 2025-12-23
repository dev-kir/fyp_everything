#!/bin/bash
# Section 2: Disable SwarmGuard for Baseline Testing

set -e

echo "Disabling SwarmGuard for baseline testing..."

# Scale down all SwarmGuard components
ssh master "docker service scale recovery-manager=0"
ssh master "docker service scale monitoring-agent-master=0"
ssh master "docker service scale monitoring-agent-worker1=0"
ssh master "docker service scale monitoring-agent-worker2=0"
ssh master "docker service scale monitoring-agent-worker3=0"
ssh master "docker service scale monitoring-agent-worker4=0"

sleep 10

# Verify SwarmGuard disabled
mkdir -p ../raw_outputs
ssh master "docker service ls" > ../raw_outputs/02_baseline_services_disabled.txt

echo "SwarmGuard disabled. Current services:"
cat ../raw_outputs/02_baseline_services_disabled.txt

echo ""
echo "Ready for baseline testing!"
echo "Run: ./02_baseline_single_test.sh 1"
