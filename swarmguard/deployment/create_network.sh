#!/bin/bash
# Create Docker overlay network for SwarmGuard

set -e

echo "Creating swarmguard-net overlay network..."

ssh master "docker network create --driver overlay swarmguard-net || echo 'Network may already exist'"

echo "Verifying network creation..."
ssh master "docker network ls | grep swarmguard-net"

echo "✅ Network created successfully!"
