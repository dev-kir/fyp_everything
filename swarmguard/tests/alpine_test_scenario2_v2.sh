#!/bin/bash

#######################################################################
# Scenario 2 Testing Script v2 - Truly Gradual Ramp
#######################################################################
#
# This version uses staggered user startup where each user contributes
# a fixed amount of CPU/MEM/NET for the full test duration.
#
# Parameters:
#   CPU_PER_USER     - CPU% contribution per user (default: 2)
#   MEMORY_PER_USER  - Memory MB contribution per user (default: 10)
#   NETWORK_PER_USER - Network Mbps contribution per user (default: 5)
#   RAMP_TIME        - Seconds to ramp from 0 to max users (default: 60)
#   TEST_DURATION    - Total test duration in seconds (default: 180)
#   USERS_PER_ALPINE - Users to simulate per Alpine (default: 10)
#
# Example:
#   ./alpine_test_scenario2_v2.sh 2 10 5 60 180 10
#
#   - 40 users total (10 per Alpine × 4 Alpines)
#   - Each user: 2% CPU, 10MB RAM, 5Mbps NET
#   - Ramp: Users start over 60 seconds (User 1 at T+0, User 10 at T+54s)
#   - Each user runs for full 180 seconds once started
#   - Expected: Gradual increase to 80% CPU, 400MB RAM, 200Mbps NET
#
#######################################################################

set -e

# Parameters
CPU_PER_USER=${1:-2}
MEMORY_PER_USER=${2:-10}
NETWORK_PER_USER=${3:-5}
RAMP_TIME=${4:-60}
TEST_DURATION=${5:-180}
USERS_PER_ALPINE=${6:-10}

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
echo -e "${GREEN}Scenario 2 Testing v2: Gradual Ramp${NC}"
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
        ssh "$alpine" "pkill -f 'wget.*stress/incremental' || true" 2>/dev/null &
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

# Start staggered user simulation
echo -e "${YELLOW}Starting staggered user simulation...${NC}"
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

                # Calculate end time
                END_TIME=\$((START_TIME + ${TEST_DURATION}))

                # Send continuous short requests (10s cycles)
                # This allows Docker Swarm to distribute across replicas
                while [ \$(date +%s) -lt \$END_TIME ]; do
                    wget -q -O /dev/null \\
                        "${SERVICE_URL}/stress/combined?cpu=${CPU_PER_USER}&memory=${MEMORY_PER_USER}&network=${NETWORK_PER_USER}&duration=10&ramp=2" \\
                        2>/dev/null || true
                    sleep 0.5
                done
            ) &
        done

        wait
EOF
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Traffic Generation Started${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Timeline:"
echo "  T+0s:        User 1 starts on each Alpine (4 users) → $(( 4 * CPU_PER_USER ))% CPU"
echo "  T+${RAMP_TIME}s: All ${TOTAL_USERS} users active → ${TOTAL_CPU}% CPU"
echo "  T+${TEST_DURATION}s: Test completes"
echo ""
echo "Expected Behavior:"
echo "  1. Gradual linear ramp: 0% → ${TOTAL_CPU}% over ${RAMP_TIME}s"
echo "  2. Sustained load: ${TOTAL_CPU}% for $((TEST_DURATION - RAMP_TIME))s"
echo "  3. Scenario 2 triggers → Scale 1→2 replicas"
echo "  4. Load distributes evenly across replicas"
echo ""
echo -e "${YELLOW}Monitor: http://192.168.2.61:3000${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Wait for test duration
sleep ${TEST_DURATION}

echo ""
echo -e "${GREEN}Test completed!${NC}"
