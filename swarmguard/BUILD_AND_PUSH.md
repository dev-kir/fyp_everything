# SwarmGuard - Build and Push Instructions

## Overview

This document provides instructions for building Docker images and pushing them to your private registry.

## Prerequisites

- Access to Ubuntu build server with Docker installed
- Push access to `docker-registry.amirmuz.com`
- Git repository with SwarmGuard code

## Build Process

### On your Development Mac:

```bash
# 1. Commit and push code
git add .
git commit -m "SwarmGuard implementation"
git push origin main
```

### On Ubuntu Build Server:

```bash
# 2. Pull latest code
cd /path/to/swarmguard
git pull origin main

# 3. Build monitoring agent
cd monitoring-agent
docker build -t docker-registry.amirmuz.com/swarmguard-agent:latest .
docker push docker-registry.amirmuz.com/swarmguard-agent:latest

# 4. Build recovery manager
cd ../recovery-manager
docker build -t docker-registry.amirmuz.com/swarmguard-manager:latest .
docker push docker-registry.amirmuz.com/swarmguard-manager:latest

# 5. Build web-stress application
cd ../web-stress
docker build -t docker-registry.amirmuz.com/swarmguard-web-stress:latest .
docker push docker-registry.amirmuz.com/swarmguard-web-stress:latest

# 6. Verify images were pushed
curl https://docker-registry.amirmuz.com/v2/_catalog
```

## Quick Build Script

Save this as `build_all.sh` on your build server:

```bash
#!/bin/bash
set -e

REGISTRY="docker-registry.amirmuz.com"

echo "Building SwarmGuard images..."

# Monitoring Agent
echo "Building monitoring agent..."
cd monitoring-agent
docker build -t ${REGISTRY}/swarmguard-agent:latest .
docker push ${REGISTRY}/swarmguard-agent:latest

# Recovery Manager
echo "Building recovery manager..."
cd ../recovery-manager
docker build -t ${REGISTRY}/swarmguard-manager:latest .
docker push ${REGISTRY}/swarmguard-manager:latest

# Web Stress
echo "Building web-stress..."
cd ../web-stress
docker build -t ${REGISTRY}/swarmguard-web-stress:latest .
docker push ${REGISTRY}/swarmguard-web-stress:latest

echo "✅ All images built and pushed successfully!"
```

Make it executable:
```bash
chmod +x build_all.sh
./build_all.sh
```

## Deploy

After building and pushing, deploy from your Mac:

```bash
# Create network
./deployment/create_network.sh

# Deploy agents
./deployment/deploy_monitoring_agents.sh

# Deploy recovery manager
./deployment/deploy_recovery_manager.sh

# Deploy test application
./tests/deploy_web_stress.sh
```

## Troubleshooting

### Image Pull Errors

If you get "manifest not found" errors:
```bash
# On build server, verify push succeeded
docker images | grep swarmguard

# On master node, try pulling manually
ssh master "docker pull docker-registry.amirmuz.com/swarmguard-agent:latest"
```

### Build Errors

Check Python dependencies are correct:
```bash
# Test locally first
cd monitoring-agent
docker build -t test:latest .
docker run --rm test:latest python -c "import docker; print('OK')"
```
