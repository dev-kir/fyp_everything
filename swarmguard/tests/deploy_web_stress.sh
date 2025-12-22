#!/bin/bash
# Deploy web-stress test application (pulls from registry)
#
# Usage: ./deploy_web_stress.sh [REPLICAS] [NETWORK_MULTIPLIER]
#
# Parameters:
#   REPLICAS: Number of replicas (default: 1)
#   NETWORK_MULTIPLIER: Download size multiplier for network stress (default: 10)
#                       10 = ~40 Mbps, 20 = ~80 Mbps, 30 = ~120 Mbps
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
NETWORK_MULTIPLIER=${2:-10}  # Default to 10 (gives ~40 Mbps)

echo "==========================================="
echo "Deploying web-stress"
echo "  Replicas: ${REPLICAS}"
echo "  Network Multiplier: ${NETWORK_MULTIPLIER}"
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
  --env NETWORK_DOWNLOAD_MULTIPLIER=${NETWORK_MULTIPLIER} \
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
echo "Configuration:"
echo "  - Replicas: ${REPLICAS}"
echo "  - Network Multiplier: ${NETWORK_MULTIPLIER}"
echo "  - Expected Network: ~$((NETWORK_MULTIPLIER * 4)) Mbps per 10 Mbps target"
echo ""
echo "Available endpoints:"
echo "  - http://192.168.2.50:8080/health"
echo "  - http://192.168.2.50:8080/metrics"
echo "  - http://192.168.2.50:8080/stress/cpu?target=80&duration=120&ramp=30"
echo "  - http://192.168.2.50:8080/stress/memory?target=1024&duration=120&ramp=30"
echo "  - http://192.168.2.50:8080/stress/network?bandwidth=50&duration=120&ramp=30"
echo "  - http://192.168.2.50:8080/stress/combined?cpu=80&memory=1024&network=50&duration=120&ramp=30"
echo "  - http://192.168.2.50:8080/stress/stop"
echo ""
echo "Test Scenario 2 with:"
echo "  ./scenario2_ultimate.sh 5 1 1 10 3 60 600"
echo ""
echo "Network Multiplier Guide:"
echo "  Current: ${NETWORK_MULTIPLIER}"
echo "  - 10 = ~40 Mbps sustained (current default)"
echo "  - 20 = ~80 Mbps sustained (recommended for Scenario 2)"
echo "  - 30 = ~120 Mbps sustained (may saturate network)"
echo ""
echo "To change multiplier, redeploy with:"
echo "  ./deploy_web_stress.sh 1 20  # Use multiplier 20 for ~80 Mbps"
echo ""
