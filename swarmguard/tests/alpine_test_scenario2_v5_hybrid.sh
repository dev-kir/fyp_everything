#!/bin/bash

#######################################################################
# Scenario 2 Testing Script v5 - Hybrid (Best of Both Worlds)
#######################################################################
#
# This version uses SEPARATE stress endpoints for better control:
# - CPU/Memory: Uses /stress/combined (works well with v2 parameters)
# - Network: Uses /stress/incremental (stays stable at high bandwidth)
#
# Parameters:
#   CPU_PER_USER     - CPU% contribution per user (default: 1)
#   MEMORY_PER_USER  - Memory MB contribution per user (default: 1)
#   NETWORK_PER_USER - Network Mbps contribution per user (default: 30)
#   RAMP_TIME        - Seconds to ramp from 0 to max users (default: 90)
#   TEST_DURATION    - Total test duration in seconds (default: 180)
#   USERS_PER_ALPINE - Users to simulate per Alpine (default: 15)
#
# Example:
#   ./alpine_test_scenario2_v5_hybrid.sh 1 1 60 90 180 15
#
#######################################################################

set -e

# Parameters
CPU_PER_USER=${1:-1}
MEMORY_PER_USER=${2:-1}
NETWORK_PER_USER=${3:-60}
RAMP_TIME=${4:-90}
TEST_DURATION=${5:-180}
USERS_PER_ALPINE=${6:-15}

# Alpine nodes
ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4")

# Service URL
SERVICE_URL="http://192.168.2.50:8080"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Scenario 2 v5: Hybrid Approach${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Configuration:"
echo "  CPU per user:     ${CPU_PER_USER}%"
echo "  Memory per user:  ${MEMORY_PER_USER}MB"
echo "  Network per user: ${NETWORK_PER_USER}Mbps"
echo "  Ramp time:        ${RAMP_TIME}s"
echo "  Test duration:    ${TEST_DURATION}s"
echo "  Users per Alpine: ${USERS_PER_ALPINE}"
echo ""

TOTAL_USERS=$((${#ALPINE_NODES[@]} * USERS_PER_ALPINE))
TOTAL_CPU=$((TOTAL_USERS * CPU_PER_USER))
TOTAL_MEMORY=$((TOTAL_USERS * MEMORY_PER_USER))
TOTAL_NETWORK=$((TOTAL_USERS * NETWORK_PER_USER))

echo "Expected Peak Load:"
echo "  Total users:   ${TOTAL_USERS}"
echo "  Total CPU:     ${TOTAL_CPU}%"
echo "  Total Memory:  ${TOTAL_MEMORY}MB"
echo "  Total Network: ${TOTAL_NETWORK}Mbps"
echo ""

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Stopping all Alpine traffic...${NC}"
    for alpine in "${ALPINE_NODES[@]}"; do
        ssh "$alpine" "pkill -f 'wget.*stress' || true" 2>/dev/null &
    done
    wait

    # Stop stress on containers
    curl -s "${SERVICE_URL}/stress/stop" > /dev/null || true

    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

trap cleanup EXIT INT TERM

# Check service
echo -e "${YELLOW}Checking service...${NC}"
if ! curl -s -f "${SERVICE_URL}/health" > /dev/null; then
    echo -e "${RED}ERROR: Service not reachable${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Service healthy${NC}"
echo ""

# Start hybrid simulation
echo -e "${YELLOW}Starting hybrid load simulation...${NC}"
echo ""

for alpine in "${ALPINE_NODES[@]}"; do
    echo -e "${GREEN}Starting ${USERS_PER_ALPINE} users on ${alpine}...${NC}"

    ssh "$alpine" "sh -s" <<-EOF &
        # Calculate delay between user startups
        if [ ${USERS_PER_ALPINE} -gt 1 ]; then
            USER_DELAY=\$(awk "BEGIN {print ${RAMP_TIME} / (${USERS_PER_ALPINE} - 1)}")
        else
            USER_DELAY=0
        fi

        for user_id in \$(seq 1 ${USERS_PER_ALPINE}); do
            (
                # Staggered start
                START_DELAY=\$(awk "BEGIN {print (\$user_id - 1) * \$USER_DELAY}" user_id=\$user_id USER_DELAY=\$USER_DELAY)
                sleep \$START_DELAY

                # Calculate times
                START_TIME=\$(date +%s)
                END_TIME=\$((START_TIME + ${TEST_DURATION}))
                REMAINING_DURATION=\$(awk "BEGIN {print int(${TEST_DURATION} - \$START_DELAY)}" START_DELAY=\$START_DELAY)

                # Start network stress ONCE using /stress/incremental (stable for high bandwidth)
                wget -q -O /dev/null \
                    "${SERVICE_URL}/stress/incremental?cpu=0&memory=0&network=${NETWORK_PER_USER}&duration=\${REMAINING_DURATION}&ramp=0" \
                    2>/dev/null &
                NETWORK_PID=\$!

                # Start CPU/Memory stress loop using /stress/combined (works well with low values)
                while [ \$(date +%s) -lt \$END_TIME ]; do
                    wget -q -O /dev/null \
                        "${SERVICE_URL}/stress/combined?cpu=${CPU_PER_USER}&memory=${MEMORY_PER_USER}&network=0&duration=10&ramp=2" \
                        2>/dev/null || true
                    sleep 2
                done

                # Wait for network stress to finish
                wait \$NETWORK_PID 2>/dev/null || true
            ) &
        done

        wait
EOF
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Hybrid Load Started${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Timeline:"
echo "  T+0s:        User 1 starts on each Alpine (4 users) → $(( 4 * CPU_PER_USER ))% CPU, $(( 4 * NETWORK_PER_USER ))Mbps"
echo "  T+${RAMP_TIME}s: All ${TOTAL_USERS} users active → ${TOTAL_CPU}% CPU, ${TOTAL_NETWORK}Mbps"
echo "  T+${TEST_DURATION}s: Test completes"
echo ""
echo "Expected Behavior:"
echo "  1. CPU/Memory: Smooth controlled ramp using /stress/combined"
echo "  2. Network: Stable high bandwidth using /stress/incremental"
echo "  3. All three resources work well together"
echo "  4. Scenario 2 triggers → Scale 1→2 replicas"
echo ""
echo -e "${YELLOW}Monitor: http://192.168.2.61:3000${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Wait for test duration
sleep ${TEST_DURATION}

echo ""
echo -e "${GREEN}Test completed!${NC}"
