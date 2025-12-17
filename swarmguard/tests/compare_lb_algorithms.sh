#!/bin/bash
# Compare load balancing algorithms
#
# This script runs scenario 2 tests with different load balancing algorithms
# and compares their performance
#
# Usage:
#   ./compare_lb_algorithms.sh

set -e

RESULTS_DIR="/tmp/lb_comparison_$(date +%Y%m%d_%H%M%S)"
mkdir -p ${RESULTS_DIR}

echo "==========================================="
echo "Load Balancer Algorithm Comparison"
echo "==========================================="
echo ""
echo "Results will be saved to: ${RESULTS_DIR}"
echo ""

# Test parameters
CPU_INCREMENT=2
MEM_INCREMENT=50
NET_INCREMENT=5
RAMP_DURATION=60
HOLD_DURATION=120

echo "Test parameters:"
echo "  - CPU increment: ${CPU_INCREMENT}%"
echo "  - Memory increment: ${MEM_INCREMENT} MB"
echo "  - Network increment: ${NET_INCREMENT} Mbps"
echo "  - Ramp duration: ${RAMP_DURATION}s"
echo "  - Hold duration: ${HOLD_DURATION}s"
echo ""

# Function to run test
run_test() {
    local algorithm=$1
    local port=$2
    local test_name=$3

    echo "==========================================="
    echo "Testing: ${test_name}"
    echo "==========================================="
    echo ""

    # Deploy load balancer with specific algorithm (skip for round-robin which uses Docker Swarm)
    if [ "${algorithm}" != "round-robin-swarm" ]; then
        echo "Deploying load balancer with ${algorithm} algorithm..."
        ./deploy_load_balancer.sh ${algorithm}
        sleep 15
    fi

    # Run test
    echo ""
    echo "Running scenario 2 test..."
    SERVICE_URL="http://192.168.2.50:${port}" \
        ./alpine_test_scenario2_v4_incremental.sh \
        ${CPU_INCREMENT} ${MEM_INCREMENT} ${NET_INCREMENT} \
        ${RAMP_DURATION} ${HOLD_DURATION} 10 \
        > ${RESULTS_DIR}/${test_name}.log 2>&1

    echo "✅ Test completed for ${test_name}"
    echo ""
    sleep 30  # Cool down between tests
}

# Ensure web-stress is deployed
echo "Checking web-stress deployment..."
if ! ssh master "docker service ls | grep -q web-stress"; then
    echo "Deploying web-stress..."
    ./deploy_web_stress.sh 1
fi

echo ""
echo "Starting comparison tests..."
echo ""

# Test 1: Docker Swarm native round-robin (baseline)
run_test "round-robin-swarm" 8080 "01_docker_swarm_roundrobin"

# Test 2: Lease-based algorithm
run_test "lease" 8081 "02_intelligent_lb_lease"

# Test 3: Metrics-based algorithm
run_test "metrics" 8081 "03_intelligent_lb_metrics"

# Test 4: Hybrid algorithm
run_test "hybrid" 8081 "04_intelligent_lb_hybrid"

echo "==========================================="
echo "✅ All tests completed!"
echo "==========================================="
echo ""
echo "Results saved to: ${RESULTS_DIR}"
echo ""
echo "To analyze results:"
echo "  - View logs: ls -lh ${RESULTS_DIR}/"
echo "  - Compare in Grafana: Check load distribution variance"
echo "  - Check InfluxDB: Query max CPU per replica for each test"
echo ""
echo "Key metrics to compare:"
echo "  1. Load distribution variance (lower is better)"
echo "  2. Max CPU across all replicas (lower is better)"
echo "  3. Number of scale-up events (should be similar)"
echo "  4. Response time (should be similar or better)"
echo ""
