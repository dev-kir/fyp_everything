#!/bin/bash
# Section 1.1: Clean Deployment Script
# Run from: fyp-report/03-chapter4-evidence/scripts/

set -e  # Exit on error

# Create output directory
OUTPUT_DIR="/Users/amirmuz/RESULT_FYP_EVERYTHING"
mkdir -p "$OUTPUT_DIR"

# Record deployment start time
echo "Deployment started: $(date -Iseconds)" > "$OUTPUT_DIR/01_deployment_log.txt"

# Remove all services
echo "Removing existing services..."
ssh master "docker service rm \
  monitoring-agent-master \
  monitoring-agent-worker1 \
  monitoring-agent-worker2 \
  monitoring-agent-worker3 \
  monitoring-agent-worker4 \
  recovery-manager \
  intelligent-lb \
  lb-metrics-collector \
  web-stress" || true  # Don't fail if services don't exist

echo "Services removed: $(date -Iseconds)" >> "$OUTPUT_DIR/01_deployment_log.txt"
ssh master "docker service ls" >> "$OUTPUT_DIR/01_deployment_log.txt"
sleep 10

# Deploy in order
echo "Updating code..."
cd /Users/amirmuz/fyp_everything/swarmguard
git fetch origin
git reset --hard fix-testing-method-v2
git checkout -f fix-testing-method-v2
git pull

echo "Creating network..."
./deployment/create_network.sh
echo "Network created: $(date -Iseconds)" >> "$OUTPUT_DIR/01_deployment_log.txt"

echo "Deploying recovery manager..."
./deployment/deploy_recovery_manager.sh
sleep 30
echo "Recovery manager deployed: $(date -Iseconds)" >> "$OUTPUT_DIR/01_deployment_log.txt"

echo "Deploying monitoring agents..."
./deployment/deploy_monitoring_agents.sh
sleep 30
echo "Monitoring agents deployed: $(date -Iseconds)" >> "$OUTPUT_DIR/01_deployment_log.txt"

echo "Deploying load balancer..."
./tests/deploy_load_balancer.sh lease
sleep 15
echo "Load balancer deployed: $(date -Iseconds)" >> "$OUTPUT_DIR/01_deployment_log.txt"

echo "Deploying LB metrics collector..."
./monitoring/deploy_lb_metrics_collector.sh
sleep 10
echo "LB metrics collector deployed: $(date -Iseconds)" >> "$OUTPUT_DIR/01_deployment_log.txt"

echo "Deploying web-stress..."
./tests/deploy_web_stress.sh 1 30
echo "Web-stress deployed: $(date -Iseconds)" >> "$OUTPUT_DIR/01_deployment_log.txt"

# Return to scripts directory
cd /Users/amirmuz/fyp_everything/fyp-report/03-chapter4-evidence/scripts

# Final service list
echo "Final service list:"
ssh master "docker service ls"
ssh master "docker service ls" >> "$OUTPUT_DIR/01_deployment_log.txt"
echo "Deployment completed: $(date -Iseconds)" >> "$OUTPUT_DIR/01_deployment_log.txt"

# Verify all services healthy
echo ""
echo "=== Health Checks ===" | tee -a "$OUTPUT_DIR/01_deployment_log.txt"

echo "Checking load balancer health..."
curl -s http://192.168.2.50:8081/health | jq . | tee -a "$OUTPUT_DIR/01_deployment_log.txt"

echo "Checking load balancer metrics..."
curl -s http://192.168.2.50:8081/metrics | jq .replica_stats | tee -a "$OUTPUT_DIR/01_deployment_log.txt"

echo "Checking web-stress health..."
curl -s http://192.168.2.50:8080/health | jq . | tee -a "$OUTPUT_DIR/01_deployment_log.txt"

echo "Checking monitoring-agent health..."
curl -s http://worker-1:8082/health | jq . | tee -a "$OUTPUT_DIR/01_deployment_log.txt"

echo ""
echo "All services deployed and verified!"
echo "Check $OUTPUT_DIR/01_deployment_log.txt for details"
