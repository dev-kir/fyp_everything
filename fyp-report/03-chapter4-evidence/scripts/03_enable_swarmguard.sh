#!/bin/bash
# Section 3: Enable SwarmGuard for Scenario Testing

set -e

echo "Enabling SwarmGuard for scenario testing..."

# Scale up all SwarmGuard components
ssh master "docker service scale recovery-manager=1"
ssh master "docker service scale monitoring-agent-master=1"
ssh master "docker service scale monitoring-agent-worker1=1"
ssh master "docker service scale monitoring-agent-worker2=1"
ssh master "docker service scale monitoring-agent-worker3=1"
ssh master "docker service scale monitoring-agent-worker4=1"

echo "Waiting 60 seconds for all agents to be healthy..."
sleep 60

# Verify SwarmGuard enabled
mkdir -p ../raw_outputs
ssh master "docker service ls" > ../raw_outputs/03_scenario1_services_enabled.txt

echo "SwarmGuard enabled. Current services:"
cat ../raw_outputs/03_scenario1_services_enabled.txt

echo ""
echo "Ready for scenario testing!"
