#!/bin/bash
# Deploy web-stress test application

set -e

REGISTRY="docker-registry.amirmuz.com"
IMAGE="${REGISTRY}/swarmguard-web-stress:latest"
REPLICAS=${1:-1}  # Default to 1 replica

echo "Deploying web-stress application with ${REPLICAS} replica(s)..."

ssh master "docker service create \
  --name web-stress \
  --replicas ${REPLICAS} \
  --constraint 'node.role==worker' \
  --constraint 'node.hostname!=master' \
  --network swarmguard-net \
  --publish 8080:8080 \
  --limit-memory 2G \
  --reserve-memory 512M \
  --health-cmd 'curl -f http://localhost:8080/health || exit 1' \
  --health-interval 5s \
  --health-timeout 3s \
  ${IMAGE}"

echo "✅ Web-stress application deployed!"
echo "Waiting for service to be ready..."
sleep 10

echo "Verifying deployment..."
ssh master "docker service ls | grep web-stress"
ssh master "docker service ps web-stress"

echo ""
echo "Testing application endpoints..."
echo "Health: "
curl -s http://192.168.2.50:8080/health | jq .
echo ""
echo "Metrics:"
curl -s http://192.168.2.50:8080/metrics | jq .

echo ""
echo "✅ Web-stress application is ready!"
echo "Available endpoints:"
echo "  - http://192.168.2.50:8080/health"
echo "  - http://192.168.2.50:8080/metrics"
echo "  - http://192.168.2.50:8080/stress/cpu?target=80&duration=120&ramp=30"
echo "  - http://192.168.2.50:8080/stress/memory?target=1024&duration=120&ramp=30"
echo "  - http://192.168.2.50:8080/stress/network?bandwidth=50&duration=120&ramp=30"
echo "  - http://192.168.2.50:8080/stress/combined?cpu=80&memory=1024&network=50&duration=120&ramp=30"
echo "  - http://192.168.2.50:8080/stress/stop"
