#!/bin/bash
# Complete redeployment script - Run this after fixing master node issue

set -e

echo "=== SwarmGuard Complete Redeployment ==="
echo ""

# Step 1: Drain master node
echo "Step 1: Draining master node to prevent application workloads..."
ssh master "docker node update --availability drain master"
ssh master "docker node ls"
echo "✅ Master node drained"
echo ""

# Step 2: Remove old web-stress service
echo "Step 2: Removing old web-stress service..."
ssh master "docker service rm web-stress" 2>/dev/null || echo "web-stress not running (OK)"
sleep 3
echo "✅ Old service removed"
echo ""

# Step 3: Rebuild recovery-manager
echo "Step 3: Rebuilding recovery-manager with master exclusion fix..."
echo "Please run on your build server:"
echo ""
echo "  cd /path/to/swarmguard/recovery-manager"
echo "  docker build -t docker-registry.amirmuz.com/swarmguard-manager:latest ."
echo "  docker push docker-registry.amirmuz.com/swarmguard-manager:latest"
echo ""
read -p "Press ENTER when rebuild is complete..."

# Step 4: Restart recovery-manager
echo "Step 4: Restarting recovery-manager..."
ssh master "docker service update --force recovery-manager"
sleep 5
ssh master "docker service logs recovery-manager --tail 10"
echo "✅ Recovery manager restarted"
echo ""

# Step 5: Deploy web-stress
echo "Step 5: Deploying web-stress with master exclusion..."
cd "$(dirname "$0")"
./tests/deploy_web_stress.sh
echo ""

# Step 6: Verify deployment
echo "Step 6: Verifying deployment..."
echo ""
echo "=== Docker Node Status ==="
ssh master "docker node ls"
echo ""
echo "=== Web-stress Placement ==="
ssh master "docker service ps web-stress --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}'"
echo ""

# Step 7: Final check
CURRENT_NODE=$(ssh master "docker service ps web-stress --format '{{.Node}}' | head -1")
if [ "$CURRENT_NODE" == "master" ]; then
    echo "❌ ERROR: web-stress is still on master node!"
    echo "Please check constraints and node availability"
    exit 1
else
    echo "✅ SUCCESS: web-stress is on $CURRENT_NODE (not master)"
fi

echo ""
echo "=== Redeployment Complete ==="
echo "You can now proceed with Phase 1 testing:"
echo "  curl 'http://192.168.2.50:8080/stress/cpu?target=30&duration=60&ramp=10'"
echo ""
