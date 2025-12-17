#!/bin/bash
# Deploy web-stress test application (pulls from registry)
#
# Healthcheck settings configured for load testing:
#   --health-interval 30s: Check every 30s (very lenient)
#   --health-timeout 15s: Allow 15s for response (tolerates heavy load)
#   --health-retries 10: Require 10 consecutive failures before restart
#   --health-start-period 60s: 60s grace period on startup
#
# This gives SwarmGuard 5+ minutes (30s × 10 retries = 300s) to handle issues
# before Docker intervenes. Prevents interference during load testing.

set -e

REGISTRY="docker-registry.amirmuz.com"
IMAGE="${REGISTRY}/swarmguard-web-stress:latest"
REPLICAS=${1:-1}  # Default to 1 replica

echo "==========================================="
echo "Deploying web-stress"
echo "==========================================="
echo ""

echo "[1/2] Deploying to Docker Swarm..."
ssh master "docker service create \
  --name web-stress \
  --replicas ${REPLICAS} \
  --constraint 'node.role==worker' \
  --constraint 'node.hostname!=master' \
  --network swarmguard-net \
  --publish 8080:8080 \
  --health-cmd 'curl -f http://localhost:8080/health || exit 1' \
  --health-interval 30s \
  --health-timeout 15s \
  --health-retries 10 \
  --health-start-period 60s \
  ${IMAGE}"

echo ""
echo "[2/2] Waiting for service to be ready..."
sleep 15

echo ""
echo "Verifying deployment..."
ssh master "docker service ls | grep web-stress"
ssh master "docker service ps web-stress"

echo ""
echo "Testing application endpoints..."
echo ""
echo "Test 1: Health check"
curl -s http://192.168.2.50:8080/health | jq .

echo ""
echo "Test 2: Metrics"
curl -s http://192.168.2.50:8080/metrics | jq .

echo ""
echo "Test 3: New /stress/incremental endpoint"
curl -s "http://192.168.2.50:8080/stress/incremental?cpu=1&memory=10&network=1&duration=5&ramp=2" | jq .

echo ""
echo "==========================================="
echo "✅ Web-stress deployed successfully!"
echo "==========================================="
echo ""
echo "Available endpoints:"
echo "  - http://192.168.2.50:8080/health"
echo "  - http://192.168.2.50:8080/metrics"
echo "  - http://192.168.2.50:8080/stress/cpu?target=80&duration=120&ramp=30"
echo "  - http://192.168.2.50:8080/stress/memory?target=1024&duration=120&ramp=30"
echo "  - http://192.168.2.50:8080/stress/network?bandwidth=50&duration=120&ramp=30"
echo "  - http://192.168.2.50:8080/stress/combined?cpu=80&memory=1024&network=50&duration=120&ramp=30"
echo "  - http://192.168.2.50:8080/stress/incremental?cpu=2&memory=50&network=5&duration=120&ramp=60  ← NEW!"
echo "  - http://192.168.2.50:8080/stress/stop"
echo ""
echo "Test Scenario 2 with:"
echo "  cd /Users/amirmuz/code/claude_code/fyp_everything/swarmguard/tests"
echo "  ./alpine_scenario2_incremental.sh 10 2 50 5 60 120"
echo ""
