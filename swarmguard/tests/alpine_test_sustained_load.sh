#!/bin/bash
# Sustained load test that shows CPU distribution clearly
# Uses /compute/pi endpoint to create actual CPU load per request

set -e

# Configuration
SERVICE_URL="${SERVICE_URL:-http://192.168.2.50:8081}"
REQUESTS_PER_SECOND=${1:-20}  # Steady rate: 20 req/s
TEST_DURATION=${2:-300}        # 5 minutes to allow scaling to happen
PI_ITERATIONS=${3:-5000000}    # CPU work per request (adjust for visible CPU usage)

# Alpine nodes
ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4")

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Sustained Load Test for Scenario 2${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Configuration:"
echo -e "  Service URL: ${SERVICE_URL}"
echo -e "  Requests/sec: ${REQUESTS_PER_SECOND}"
echo -e "  Test duration: ${TEST_DURATION}s"
echo -e "  CPU work per request: ${PI_ITERATIONS} iterations"
echo ""
echo -e "${YELLOW}Expected behavior:${NC}"
echo -e "  1. Initial: 2 replicas, each ~75% CPU"
echo -e "  2. Scenario 2 triggers: Scales to 4-5 replicas"
echo -e "  3. After scaling: Each replica ~37-40% CPU"
echo ""

# Calculate delay between requests for steady rate
DELAY=$(awk "BEGIN {print 1.0 / ${REQUESTS_PER_SECOND}}")
echo -e "  Delay between requests: ${DELAY}s"
echo ""

# Kill any existing bombardier processes on Alpine nodes
echo -e "${YELLOW}[1/3] Cleaning up existing processes...${NC}"
for NODE in "${ALPINE_NODES[@]}"; do
    ssh ${NODE} "pkill -9 bombardier || true" 2>/dev/null || true
done
sleep 2

# Start sustained load from each Alpine node
echo -e "${YELLOW}[2/3] Starting sustained load from Alpine nodes...${NC}"
PIDS=()

for NODE in "${ALPINE_NODES[@]}"; do
    echo -e "  Starting bombardier on ${NODE}..."

    # Use bombardier with:
    # - Steady rate per node: divide total rate by number of nodes
    # - Target the /compute/pi endpoint with CPU work
    # - Run for specified duration
    RATE_PER_NODE=$((REQUESTS_PER_SECOND / ${#ALPINE_NODES[@]}))

    ssh ${NODE} "bombardier \
        --method GET \
        --rate ${RATE_PER_NODE} \
        --duration ${TEST_DURATION}s \
        --timeout 30s \
        --print r \
        '${SERVICE_URL}/compute/pi?iterations=${PI_ITERATIONS}' \
        > /tmp/bombardier_${NODE}.log 2>&1" &

    PIDS+=($!)
done

echo ""
echo -e "${GREEN}[3/3] Load test running!${NC}"
echo ""
echo -e "${YELLOW}What to watch in Grafana:${NC}"
echo -e "  1. Open: http://192.168.2.61:3000"
echo -e "  2. Dashboard: SwarmGuard_All_Sum"
echo -e ""
echo -e "${YELLOW}Expected pattern:${NC}"
echo -e "  Phase 1 (0-2 min): CPU spikes on 2 nodes as load builds up"
echo -e "  Phase 2 (2-3 min): Scenario 2 triggers, scales to 4-5 replicas"
echo -e "  Phase 3 (3-5 min): CPU distributed evenly across all replicas"
echo -e ""
echo -e "${YELLOW}CPU metrics should show:${NC}"
echo -e "  Before: worker-1 ~75%, worker-3 ~75% (2 containers)"
echo -e "  After:  worker-1 ~37%, worker-3 ~37%, worker-2 ~37%, worker-4 ~37% (4 containers)"
echo ""
echo -e "${YELLOW}LB Dashboard (SwarmGuard Load Balancer Visualization):${NC}"
echo -e "  - Request distribution graph shows even split"
echo -e "  - Cumulative requests show parallel lines"
echo ""
echo -e "${GREEN}Test will run for ${TEST_DURATION} seconds...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop early${NC}"
echo ""

# Wait for test to complete
for PID in "${PIDS[@]}"; do
    wait $PID
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Test completed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Collect results
echo -e "${YELLOW}Collecting results...${NC}"
TOTAL_REQUESTS=0
for NODE in "${ALPINE_NODES[@]}"; do
    REQS=$(ssh ${NODE} "grep -oP '(?<=Reqs/sec\\s{5})\\d+' /tmp/bombardier_${NODE}.log | tail -1" 2>/dev/null || echo "0")
    echo -e "  ${NODE}: ${REQS} req/s"
    TOTAL_REQUESTS=$((TOTAL_REQUESTS + REQS))
done

echo ""
echo -e "${GREEN}Total sustained rate: ${TOTAL_REQUESTS} req/s${NC}"
echo ""

# Check LB metrics
echo -e "${YELLOW}Load Balancer Statistics:${NC}"
curl -s ${SERVICE_URL}/metrics | jq '{
    total_requests: .total_requests,
    healthy_replicas: .healthy_replicas,
    request_distribution: [.replica_stats | to_entries[] | {node: .value.node, requests: .value.request_count}]
}'

echo ""
echo -e "${GREEN}Check Grafana dashboards to see:${NC}"
echo -e "  1. CPU/Memory distribution across nodes"
echo -e "  2. LB request distribution graphs"
echo -e "  3. Network metrics (lower due to LB proxying)"
echo ""
