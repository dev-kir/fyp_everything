#!/bin/bash
# Deploy monitoring agents to all swarm nodes

set -e

REGISTRY="docker-registry.amirmuz.com"
IMAGE="${REGISTRY}/swarmguard-agent:latest"
INFLUXDB_URL="http://192.168.2.61:8086/api/v2/write?org=swarmguard&bucket=metrics&precision=s"
INFLUXDB_TOKEN="iNCff-dYnCY8oiO_mDIn3tMIEdl5D1Z4_KFE2vwTMFtQoTqGh2SbL5msNB30DIOKE2wwj-maBW5lTZVJ3f9ONA=="
RECOVERY_MANAGER_URL="http://recovery-manager:5000"

echo "Deploying monitoring agents to all nodes..."

# Master node
echo "Deploying agent on master..."
ssh master "docker service create \
  --name monitoring-agent-master \
  --constraint 'node.hostname == master' \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  --mount type=bind,src=/sys,dst=/host/sys,ro=true \
  --network swarmguard-net \
  -e NODE_NAME=master \
  -e NET_IFACE=enp5s0f0 \
  -e POLL_INTERVAL=5 \
  -e INFLUXDB_URL='${INFLUXDB_URL}' \
  -e INFLUXDB_TOKEN='${INFLUXDB_TOKEN}' \
  -e RECOVERY_MANAGER_URL='${RECOVERY_MANAGER_URL}' \
  ${IMAGE}"

# Worker-1
echo "Deploying agent on worker-1..."
ssh master "docker service create \
  --name monitoring-agent-worker1 \
  --constraint 'node.hostname == worker-1' \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  --mount type=bind,src=/sys,dst=/host/sys,ro=true \
  --network swarmguard-net \
  -e NODE_NAME=worker-1 \
  -e NET_IFACE=eno1 \
  -e POLL_INTERVAL=5 \
  -e INFLUXDB_URL='${INFLUXDB_URL}' \
  -e INFLUXDB_TOKEN='${INFLUXDB_TOKEN}' \
  -e RECOVERY_MANAGER_URL='${RECOVERY_MANAGER_URL}' \
  ${IMAGE}"

# Worker-2
echo "Deploying agent on worker-2..."
ssh master "docker service create \
  --name monitoring-agent-worker2 \
  --constraint 'node.hostname == worker-2' \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  --mount type=bind,src=/sys,dst=/host/sys,ro=true \
  --network swarmguard-net \
  -e NODE_NAME=worker-2 \
  -e NET_IFACE=enp0s25 \
  -e POLL_INTERVAL=5 \
  -e INFLUXDB_URL='${INFLUXDB_URL}' \
  -e INFLUXDB_TOKEN='${INFLUXDB_TOKEN}' \
  -e RECOVERY_MANAGER_URL='${RECOVERY_MANAGER_URL}' \
  ${IMAGE}"

# Worker-3
echo "Deploying agent on worker-3..."
ssh master "docker service create \
  --name monitoring-agent-worker3 \
  --constraint 'node.hostname == worker-3' \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  --mount type=bind,src=/sys,dst=/host/sys,ro=true \
  --network swarmguard-net \
  -e NODE_NAME=worker-3 \
  -e NET_IFACE=enp2s0 \
  -e POLL_INTERVAL=5 \
  -e INFLUXDB_URL='${INFLUXDB_URL}' \
  -e INFLUXDB_TOKEN='${INFLUXDB_TOKEN}' \
  -e RECOVERY_MANAGER_URL='${RECOVERY_MANAGER_URL}' \
  ${IMAGE}"

# Worker-4
echo "Deploying agent on worker-4..."
ssh master "docker service create \
  --name monitoring-agent-worker4 \
  --constraint 'node.hostname == worker-4' \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  --mount type=bind,src=/sys,dst=/host/sys,ro=true \
  --network swarmguard-net \
  -e NODE_NAME=worker-4 \
  -e NET_IFACE=eno1 \
  -e POLL_INTERVAL=5 \
  -e INFLUXDB_URL='${INFLUXDB_URL}' \
  -e INFLUXDB_TOKEN='${INFLUXDB_TOKEN}' \
  -e RECOVERY_MANAGER_URL='${RECOVERY_MANAGER_URL}' \
  ${IMAGE}"

echo "✅ All monitoring agents deployed!"
echo "Verifying deployment..."
ssh master "docker service ls | grep monitoring-agent"
