#!/bin/bash
# Deploy recovery manager on master node

set -e

REGISTRY="docker-registry.amirmuz.com"
IMAGE="${REGISTRY}/swarmguard-manager:latest"

echo "Deploying recovery manager on master node..."

ssh master "docker service create \
  --name recovery-manager \
  --constraint 'node.hostname == master' \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  --network swarmguard-net \
  --publish 5000:5000 \
  ${IMAGE}"

echo "✅ Recovery manager deployed!"
echo "Waiting for service to be ready..."
sleep 5

echo "Verifying deployment..."
ssh master "docker service ls | grep recovery-manager"
ssh master "docker service ps recovery-manager"

echo ""
echo "Testing health endpoint..."
curl -s http://192.168.2.50:5000/health || echo "Service not yet ready"
