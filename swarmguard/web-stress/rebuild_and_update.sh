#!/bin/bash
# Rebuild and update web-stress service with latest changes (adds /compute/pi endpoint)

set -e

REGISTRY="docker-registry.amirmuz.com"
IMAGE="${REGISTRY}/swarmguard-web-stress:latest"

echo "==========================================="
echo "Rebuilding web-stress with /compute/pi"
echo "==========================================="
echo ""

cd /Users/amirmuz/code/claude_code/fyp_everything/swarmguard/web-stress

echo "[1/6] Building Docker image..."
docker build -t ${IMAGE} .

echo ""
echo "[2/6] Pushing to registry..."
docker push ${IMAGE}

echo ""
echo "[3/6] Removing old web-stress service..."
ssh master "docker service rm web-stress" || true
sleep 5

echo ""
echo "[4/6] Deploying new web-stress service..."
ssh master "docker service create \
  --name web-stress \
  --replicas 1 \
  --constraint 'node.role==worker' \
  --constraint 'node.hostname!=master' \
  --network swarmguard-net \
  --publish 8080:8080 \
  --limit-memory 4G \
  --reserve-memory 512M \
  --health-cmd 'curl -f http://localhost:8080/health || exit 1' \
  --health-interval 5s \
  --health-timeout 3s \
  ${IMAGE}"

echo ""
echo "[5/6] Waiting for service to be ready..."
sleep 15

echo ""
echo "[6/6] Testing new /compute/pi endpoint..."
echo ""
echo "Test 1: 100k iterations (light)"
time curl -s "http://192.168.2.50:8080/compute/pi?iterations=100000" | jq .

echo ""
echo "Test 2: 250k iterations (5% CPU target)"
time curl -s "http://192.168.2.50:8080/compute/pi?iterations=250000" | jq .

echo ""
echo "✅ Web-stress service rebuilt and deployed!"
echo ""
echo "Service status:"
ssh master "docker service ls | grep web-stress"
ssh master "docker service ps web-stress"

echo ""
echo "All endpoints available:"
echo "  - http://192.168.2.50:8080/health"
echo "  - http://192.168.2.50:8080/metrics"
echo "  - http://192.168.2.50:8080/compute/pi?iterations=100000  ← NEW!"
echo "  - http://192.168.2.50:8080/stress/cpu?target=80&duration=120&ramp=30"
echo "  - http://192.168.2.50:8080/stress/memory?target=1024&duration=120&ramp=30"
echo "  - http://192.168.2.50:8080/stress/network?bandwidth=50&duration=120&ramp=30"
echo "  - http://192.168.2.50:8080/stress/combined?cpu=80&memory=1024&network=50&duration=120&ramp=30"
echo "  - http://192.168.2.50:8080/stress/stop"
echo ""
