#!/bin/bash

#######################################################################
# Scenario 2 Testing Script - Gradual Load with Distribution Visualization
#######################################################################
#
# Purpose: Demonstrate Scenario 2 autoscaling and load distribution
#
# Parameters:
#   CPU        - CPU% per user (default: 2)
#   MEMORY     - Memory MB per user (default: 50)
#   NETWORK    - Network Mbps per user (default: 5)
#   RAMP       - Seconds to reach target load (default: 60)
#   DURATION   - Seconds to hold target load (default: 120)
#   USERS      - Simulated users per Alpine (default: 10)
#
# Example Usage:
#   ./alpine_test_scenario2.sh 2 50 5 60 120 10
#
# Expected Behavior:
#   - 4 Alpines × 10 users = 40 users total
#   - 40 users × 2% CPU = 80% CPU aggregate
#   - Load ramps 0% → 80% over 60 seconds (gradual increase)
#   - Holds at 80% for 120 seconds
#   - When scale-up occurs (1→2 replicas), load distributes automatically
#   - Grafana shows: 80% → 40% + 40% (distributed)
#
#######################################################################

set -e

# Parameters with defaults
CPU_PER_USER=${1:-2}
MEMORY_PER_USER=${2:-50}
NETWORK_PER_USER=${3:-5}
RAMP_TIME=${4:-60}
DURATION=${5:-120}
USERS_PER_ALPINE=${6:-10}

# Alpine nodes
ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4")

# Service URL (via published port on master)
SERVICE_URL="http://192.168.2.50:8080"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Scenario 2 Testing: Gradual Load + Distribution${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Configuration:"
echo "  CPU per user:     ${CPU_PER_USER}%"
echo "  Memory per user:  ${MEMORY_PER_USER}MB"
echo "  Network per user: ${NETWORK_PER_USER}Mbps"
echo "  Ramp time:        ${RAMP_TIME}s"
echo "  Duration:         ${DURATION}s"
echo "  Users per Alpine: ${USERS_PER_ALPINE}"
echo ""
echo "Total Load:"
TOTAL_USERS=$((${#ALPINE_NODES[@]} * USERS_PER_ALPINE))
TOTAL_CPU=$((TOTAL_USERS * CPU_PER_USER))
TOTAL_MEMORY=$((TOTAL_USERS * MEMORY_PER_USER))
TOTAL_NETWORK=$((TOTAL_USERS * NETWORK_PER_USER))
echo "  Total users:      ${TOTAL_USERS}"
echo "  Total CPU:        ${TOTAL_CPU}%"
echo "  Total Memory:     ${TOTAL_MEMORY}MB"
echo "  Total Network:    ${TOTAL_NETWORK}Mbps"
echo ""

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Stopping all Alpine traffic...${NC}"
    for alpine in "${ALPINE_NODES[@]}"; do
        ssh "$alpine" "pkill -f 'stress/combined' || true" 2>/dev/null &
    done
    wait
    echo -e "${GREEN}✓ All Alpine nodes stopped${NC}"
}

trap cleanup EXIT INT TERM

# Check service availability
echo -e "${YELLOW}Checking service availability...${NC}"
if ! curl -s -f "${SERVICE_URL}/health" > /dev/null; then
    echo -e "${RED}ERROR: Service not reachable at ${SERVICE_URL}${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Service is healthy${NC}"
echo ""

# Start Alpine traffic
echo -e "${YELLOW}Starting continuous traffic from Alpine nodes...${NC}"
echo ""

for alpine in "${ALPINE_NODES[@]}"; do
    echo -e "${GREEN}Starting ${USERS_PER_ALPINE} users on ${alpine}...${NC}"

    ssh "$alpine" "sh -s" <<-EOF &
        # Staggered user startup for gradual ramp
        # Each user starts at different times, spreading load over ramp period

        START_TIME=\$(date +%s)
        END_TIME=\$((START_TIME + ${RAMP_TIME} + ${DURATION}))

        # Calculate delay between user startups
        USER_DELAY=\$(awk "BEGIN {print ${RAMP_TIME} / ${USERS_PER_ALPINE}}")

        for user_id in \$(seq 1 ${USERS_PER_ALPINE}); do
            (
                # Staggered start: User 1 at T+0s, User 2 at T+USER_DELAY, etc.
                DELAY=\$(awk "BEGIN {print (\$user_id - 1) * \$USER_DELAY}" user_id=\$user_id USER_DELAY=\$USER_DELAY)
                sleep \$DELAY

                # Now send continuous requests until test ends
                while [ \$(date +%s) -lt \$END_TIME ]; do
                    # Send 10-second stress request (no ramp per request)
                    # Ramp is achieved by staggered user startup
                    wget -q -O /dev/null \\
                        "${SERVICE_URL}/stress/combined?cpu=${CPU_PER_USER}&memory=${MEMORY_PER_USER}&network=${NETWORK_PER_USER}&duration=10&ramp=1" \\
                        2>/dev/null || true

                    # Small delay before next request
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
echo "  T+0s:              Load starts ramping up (0% → ${TOTAL_CPU}%)"
echo "  T+${RAMP_TIME}s:   Target load reached (${TOTAL_CPU}% CPU)"
echo "  T+${RAMP_TIME}-$((RAMP_TIME + DURATION))s: Load sustained at ${TOTAL_CPU}%"
echo ""
echo "Expected Scenario 2 Behavior:"
echo "  1. Container reaches high CPU + MEM + NET"
echo "  2. Recovery manager detects → Scale 1→2 replicas"
echo "  3. Load distributes: ${TOTAL_CPU}% → ~$((TOTAL_CPU / 2))% + ~$((TOTAL_CPU / 2))%"
echo "  4. If still high → Scale 2→3 replicas"
echo "  5. Grafana shows distribution across all replicas"
echo ""
echo -e "${YELLOW}Monitor in Grafana: http://192.168.2.61:3000${NC}"
echo -e "${YELLOW}Monitor replicas: ssh master 'watch docker service ps web-stress'${NC}"
echo ""
echo "Press Ctrl+C to stop traffic and exit"
echo ""

# Wait for test duration
sleep $((RAMP_TIME + DURATION))

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Test completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Check Grafana for load distribution visualization"
echo "  2. Verify replicas: ssh master 'docker service ps web-stress'"
echo "  3. Check recovery manager logs: ssh master 'docker service logs recovery-manager --tail 50'"
