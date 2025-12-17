#!/bin/bash
# Deploy SwarmGuard Intelligent Load Balancer
#
# Supports three algorithms:
#   - lease: Lease-based (tracks active request count per replica)
#   - metrics: Metrics-based (uses CPU/Memory/Network from monitoring-agents)
#   - hybrid: Combined lease + metrics
#   - round-robin: Simple fallback
#
# Usage:
#   ./deploy_load_balancer.sh [algorithm]
#   Examples:
#     ./deploy_load_balancer.sh lease      # Default
#     ./deploy_load_balancer.sh metrics
#     ./deploy_load_balancer.sh hybrid

set -e

REGISTRY="docker-registry.amirmuz.com"
IMAGE="${REGISTRY}/swarmguard-load-balancer:latest"
ALGORITHM=${1:-lease}  # Default to lease-based algorithm

echo "==========================================="
echo "Building & Deploying Load Balancer"
echo "==========================================="
echo ""

echo "Configuration:"
echo "  - Algorithm: ${ALGORITHM}"
echo "  - Worker nodes: worker-1, worker-2, worker-3, worker-4"
echo "  - Target service: web-stress"
echo "  - LB port: 8081"
echo "  - Metrics port: 8082"
echo ""

echo "[1/4] Building Docker image..."
cd /Users/amirmuz/code/claude_code/fyp_everything/swarmguard/load-balancer
docker build -t ${IMAGE} .

echo ""
echo "[2/4] Pushing to registry..."
docker push ${IMAGE}

echo ""
echo "[3/4] Deploying to Docker Swarm (master node)..."

# Remove existing service if it exists
ssh master "docker service rm intelligent-lb 2>/dev/null || true"
sleep 2

ssh master "docker service create \
  --name intelligent-lb \
  --replicas 1 \
  --constraint 'node.role==manager' \
  --network swarmguard-net \
  --publish 8081:8081 \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  --env WORKER_NODES=worker-1,worker-2,worker-3,worker-4 \
  --env LB_PORT=8081 \
  --env TARGET_SERVICE=web-stress \
  --env LB_ALGORITHM=${ALGORITHM} \
  --env LEASE_DURATION=30 \
  --env LEASE_CLEANUP_INTERVAL=1 \
  --env METRICS_PORT=8082 \
  --env CACHE_TTL=1 \
  --env CPU_WEIGHT=0.5 \
  --env MEMORY_WEIGHT=0.3 \
  --env NETWORK_WEIGHT=0.2 \
  --env LEASE_COUNT_WEIGHT=10.0 \
  --env HEALTH_CHECK_INTERVAL=5 \
  --env FALLBACK_ENABLED=true \
  --env DEBUG_ROUTING=false \
  --env LOG_EVERY_N_REQUESTS=100 \
  ${IMAGE}"

echo ""
echo "[4/4] Waiting for service to be ready..."
sleep 10

echo ""
echo "Verifying deployment..."
ssh master "docker service ls | grep intelligent-lb"
ssh master "docker service ps intelligent-lb"

echo ""
echo "Testing load balancer endpoints..."
echo ""

echo "Test 1: Health check"
curl -s http://192.168.2.50:8081/health | jq . || echo "Health endpoint not ready yet"

echo ""
echo "Test 2: Metrics"
curl -s http://192.168.2.50:8081/metrics | jq . || echo "Metrics endpoint not ready yet"

echo ""
echo "==========================================="
echo "✅ Load Balancer deployed successfully!"
echo "==========================================="
echo ""
echo "Configuration:"
echo "  - Algorithm: ${ALGORITHM}"
echo "  - Load Balancer URL: http://192.168.2.50:8081"
echo "  - Docker Swarm (round-robin): http://192.168.2.50:8080"
echo ""
echo "Available endpoints:"
echo "  - http://192.168.2.50:8081/health   - Load balancer health"
echo "  - http://192.168.2.50:8081/metrics  - Load balancer metrics & stats"
echo "  - http://192.168.2.50:8081/*        - Proxied to web-stress replicas"
echo ""
echo "Comparison:"
echo "  - Port 8080: Docker Swarm native (round-robin)"
echo "  - Port 8081: Intelligent LB (${ALGORITHM}-based)"
echo ""
echo "To test with Alpine nodes, use:"
echo "  SERVICE_URL='http://192.168.2.50:8081' ./alpine_test_scenario2_v4_incremental.sh ..."
echo ""
echo "To view logs:"
echo "  ssh master 'docker service logs -f intelligent-lb'"
echo ""
echo "To redeploy with different algorithm:"
echo "  ./deploy_load_balancer.sh metrics   # Use metrics-based"
echo "  ./deploy_load_balancer.sh hybrid    # Use hybrid (lease + metrics)"
echo ""
