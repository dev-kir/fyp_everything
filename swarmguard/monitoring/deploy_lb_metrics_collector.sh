#!/bin/bash
# Deploy LB Metrics Collector to push load balancer metrics to InfluxDB for Grafana visualization

set -e

REGISTRY="docker-registry.amirmuz.com"
IMAGE="${REGISTRY}/lb-metrics-collector:latest"

echo "==========================================="
echo "Deploying LB Metrics Collector"
echo "==========================================="
echo ""

echo "[1/2] Deploying to Docker Swarm (master node)..."

# Remove existing service if it exists
ssh master "docker service rm lb-metrics-collector 2>/dev/null || true"
sleep 2

# Remove cached image on master to force fresh pull
echo "Removing cached image..."
ssh master "docker rmi ${IMAGE} 2>/dev/null || true"

ssh master "docker service create \
  --name lb-metrics-collector \
  --replicas 1 \
  --constraint 'node.role==manager' \
  --network swarmguard-net \
  --env LB_METRICS_URL=http://192.168.2.50:8081/metrics \
  --env INFLUXDB_URL=http://192.168.2.61:8086 \
  --env INFLUXDB_ORG=swarmguard \
  --env INFLUXDB_BUCKET=metrics \
  --env INFLUXDB_TOKEN=iNCff-dYnCY8oiO_mDIn3tMIEdl5D1Z4_KFE2vwTMFtQoTqGh2SbL5msNB30DIOKE2wwj-maBW5lTZVJ3f9ONA== \
  --env COLLECTION_INTERVAL=5 \
  ${IMAGE}"

echo ""
echo "[2/2] Waiting for service to be ready..."
sleep 5

echo ""
echo "Verifying deployment..."
ssh master "docker service ls | grep lb-metrics-collector"
ssh master "docker service ps lb-metrics-collector"

echo ""
echo "==========================================="
echo "✅ LB Metrics Collector deployed!"
echo "==========================================="
echo ""
echo "This service collects metrics from the intelligent-lb and pushes them to InfluxDB."
echo ""
echo "Metrics available in Grafana:"
echo "  - lb_metrics: Overall LB stats (total_requests, healthy_replicas)"
echo "  - lb_replica_metrics: Per-replica stats (request_count, active_leases by node)"
echo ""
echo "To view logs:"
echo "  ssh master 'docker service logs -f lb-metrics-collector'"
echo ""
echo "To import Grafana dashboard:"
echo "  http://192.168.2.61:3000 → Import → Upload monitoring/SwarmGuard_LB_Dashboard.json"
echo ""
