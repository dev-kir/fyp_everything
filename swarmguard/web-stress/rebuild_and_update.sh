#!/bin/bash
# Rebuild and update web-stress service with latest changes

set -e

REGISTRY="docker-registry.amirmuz.com"
IMAGE="${REGISTRY}/swarmguard-web-stress:latest"

echo "==========================================="
echo "Rebuilding web-stress Docker image"
echo "==========================================="
echo ""

cd /Users/amirmuz/code/claude_code/fyp_everything/swarmguard/web-stress

echo "Step 1: Building Docker image..."
docker build -t ${IMAGE} .

echo ""
echo "Step 2: Pushing to registry..."
docker push ${IMAGE}

echo ""
echo "Step 3: Updating service to use new image..."
ssh master "docker service update --image ${IMAGE} --force web-stress"

echo ""
echo "Step 4: Waiting for service to update..."
sleep 10

echo ""
echo "Step 5: Verifying service..."
ssh master "docker service ps web-stress --filter 'desired-state=running'"

echo ""
echo "Step 6: Testing new /compute/pi endpoint..."
echo "Testing with 100k iterations:"
curl -s "http://192.168.2.50:8080/compute/pi?iterations=100000" | jq .

echo ""
echo "✅ Web-stress service updated successfully!"
echo ""
echo "New endpoint available:"
echo "  - http://192.168.2.50:8080/compute/pi?iterations=1000000"
echo ""
