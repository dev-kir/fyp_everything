#!/bin/bash
#######################################################################
# Scenario 2: Simple Continuous Downloads for Sustained Network Load
#######################################################################
#
# Purpose: Create sustained network traffic by continuously downloading
#          large files from multiple Alpine nodes
#
# Usage:
#   ./scenario2_simple_downloads.sh [DOWNLOAD_SIZE_MB] [WORKERS_PER_ALPINE] [DURATION_SECONDS]
#
# Examples:
#   ./scenario2_simple_downloads.sh 50 3 900     # 50MB downloads, 3 workers/alpine, 15 min
#   ./scenario2_simple_downloads.sh 100 5 600    # 100MB downloads, 5 workers/alpine, 10 min
#   ./scenario2_simple_downloads.sh 30 4 1200    # 30MB downloads, 4 workers/alpine, 20 min
#
# Parameters:
#   DOWNLOAD_SIZE_MB     - Size of each download in MB (default: 50)
#                          Larger = more CPU work generating data
#                          Recommended: 30-100 MB
#
#   WORKERS_PER_ALPINE   - Number of concurrent download workers per Alpine (default: 3)
#                          More workers = more network traffic
#                          Total workers = 5 Alpines × WORKERS_PER_ALPINE
#                          Recommended: 3-5 workers
#
#   DURATION_SECONDS     - How long to run the test (default: 900 = 15 minutes)
#
# What it does:
#   1. Each Alpine node runs N workers continuously downloading files
#   2. Each worker downloads DOWNLOAD_SIZE_MB repeatedly
#   3. Web-stress must GENERATE this data (high CPU)
#   4. Creates sustained network RX traffic (high Network)
#   5. Serving multiple concurrent requests (high Memory)
#
# Expected behavior:
#   - Network: Sustained >65 Mbps (depends on workers × download size)
#   - CPU: High on web-stress (generating data)
#   - Memory: Moderate-high (serving concurrent requests)
#   - Triggers: Scenario 2 → scales 1→2+ replicas
#   - Distribution: Load splits across replicas after scaling
#
# Tips for tuning:
#   - Network too low? Increase WORKERS_PER_ALPINE or DOWNLOAD_SIZE_MB
#   - Network too high/spiky? Decrease WORKERS_PER_ALPINE
#   - CPU too low? Increase DOWNLOAD_SIZE_MB (more data to generate)
#   - Want more "users"? Increase WORKERS_PER_ALPINE
#
#######################################################################

set -e

# Parameters
DOWNLOAD_SIZE_MB=${1:-50}
WORKERS_PER_ALPINE=${2:-3}
DURATION_SECONDS=${3:-900}

SERVICE_URL="http://192.168.2.50:8080"
ALPINE_NODES=("alpine-1" "alpine-2" "alpine-3" "alpine-4" "alpine-5")

TOTAL_WORKERS=$((${#ALPINE_NODES[@]} * WORKERS_PER_ALPINE))

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================"
echo "Scenario 2: Continuous Download Test"
echo -e "========================================${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Download size:       ${DOWNLOAD_SIZE_MB} MB per request"
echo "  Workers per Alpine:  ${WORKERS_PER_ALPINE}"
echo "  Alpine nodes:        ${#ALPINE_NODES[@]}"
echo "  Total workers:       ${TOTAL_WORKERS} (simulated users)"
echo "  Duration:            ${DURATION_SECONDS}s ($((DURATION_SECONDS / 60)) minutes)"
echo ""

# Estimate expected network load
# At 100 Mbps, 50MB takes ~4 seconds
# 15 workers × 50MB every ~4s = sustained ~150 Mbps aggregate
# Limited by 100Mbps network = ~80-100 Mbps actual
DOWNLOAD_TIME_SEC=$((DOWNLOAD_SIZE_MB * 8 / 100))  # Rough estimate at 100Mbps
if [ $DOWNLOAD_TIME_SEC -lt 1 ]; then
    DOWNLOAD_TIME_SEC=1
fi
ESTIMATED_NETWORK=$((TOTAL_WORKERS * DOWNLOAD_SIZE_MB * 8 / DOWNLOAD_TIME_SEC))
if [ $ESTIMATED_NETWORK -gt 100 ]; then
    ESTIMATED_NETWORK=100
fi

echo -e "${YELLOW}Expected behavior:${NC}"
echo "  - Network: ~${ESTIMATED_NETWORK} Mbps sustained (target >65 Mbps)"
echo "  - CPU: High on web-stress (generating ${DOWNLOAD_SIZE_MB}MB data)"
echo "  - Memory: Moderate (serving ${TOTAL_WORKERS} concurrent requests)"
echo "  - Triggers: Scenario 2 → scales 1→2+ replicas"
echo "  - Distribution: Load splits ~50/50 after scaling"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Cleaning up Alpine nodes...${NC}"
    for alpine in "${ALPINE_NODES[@]}"; do
        ssh "$alpine" "pkill -9 -f 'curl.*download/data'" 2>/dev/null || true
    done
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

trap cleanup EXIT INT TERM

# Pre-cleanup
echo -e "${YELLOW}Pre-cleanup: Killing any existing download processes...${NC}"
for alpine in "${ALPINE_NODES[@]}"; do
    ssh "$alpine" "pkill -9 -f 'curl.*download/data'" 2>/dev/null || true
done
sleep 2
echo ""

# Check initial replica count
INITIAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1" 2>/dev/null || echo "1")
echo -e "${BLUE}Initial state:${NC}"
echo "  Replicas: ${INITIAL_REPLICAS}"
echo ""

# Start continuous downloads on each Alpine
echo -e "${GREEN}Starting continuous downloads...${NC}"
for alpine in "${ALPINE_NODES[@]}"; do
    echo "  Starting ${WORKERS_PER_ALPINE} workers on ${alpine}..."

    # SSH to Alpine and start multiple background workers
    ssh "$alpine" "
        for i in \$(seq 1 ${WORKERS_PER_ALPINE}); do
            (
                END_TIME=\$(($(date +%s) + ${DURATION_SECONDS}))
                COUNT=0
                while [ \$(date +%s) -lt \$END_TIME ]; do
                    curl -s -m 60 '${SERVICE_URL}/download/data?size_mb=${DOWNLOAD_SIZE_MB}&cpu_work=0' > /dev/null 2>&1
                    COUNT=\$((COUNT + 1))
                done
                echo \"[${alpine}] Worker \$i completed \$COUNT downloads\"
            ) &
        done
    " &
done

echo ""
echo -e "${GREEN}✓ Started ${TOTAL_WORKERS} download workers${NC}"
echo ""
echo -e "${YELLOW}📊 OPEN GRAFANA NOW:${NC}"
echo -e "   ${BLUE}http://192.168.2.61:3000${NC}"
echo ""
echo -e "${YELLOW}Expected to see in Grafana:${NC}"
echo "  1. Network Download: Sustained ~${ESTIMATED_NETWORK} Mbps (not spiky!)"
echo "  2. CPU Usage: Increases on web-stress (generating data)"
echo "  3. Memory Usage: Moderate-high (serving ${TOTAL_WORKERS} requests)"
echo "  4. Scenario 2 triggers → replicas scale 1→2"
echo "  5. After scaling: Load distributes ~50/50 across replicas"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop early${NC}"
echo ""

# Monitor replica count
START_TIME=$(date +%s)
LAST_REPLICAS=$INITIAL_REPLICAS
SCALE_EVENTS=0

while true; do
    sleep 10
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    if [ $ELAPSED -ge $DURATION_SECONDS ]; then
        break
    fi

    CURRENT_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1" 2>/dev/null || echo "?")

    if [ "$CURRENT_REPLICAS" != "$LAST_REPLICAS" ] && [ "$CURRENT_REPLICAS" != "?" ]; then
        SCALE_EVENTS=$((SCALE_EVENTS + 1))
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ✅ SCALE EVENT #${SCALE_EVENTS} DETECTED!${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
        echo "  Time: T+${ELAPSED}s"
        echo "  Change: ${LAST_REPLICAS} → ${CURRENT_REPLICAS} replicas"
        echo ""
        echo -e "${YELLOW}  Expected load distribution:${NC}"
        echo "    - Each replica now handles ~$((ESTIMATED_NETWORK / CURRENT_REPLICAS)) Mbps"
        echo "    - Check Grafana to verify distribution!"
        echo ""
        LAST_REPLICAS=$CURRENT_REPLICAS
    else
        # Progress update
        echo "[T+${ELAPSED}s] Replicas: ${CURRENT_REPLICAS} | Workers: ${TOTAL_WORKERS} active | Monitoring..."
    fi
done

echo ""
echo -e "${YELLOW}Test duration complete. Cleaning up...${NC}"
cleanup

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Test Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Final state
FINAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1" 2>/dev/null || echo "?")

echo -e "${BLUE}Summary:${NC}"
echo "  Initial replicas:  ${INITIAL_REPLICAS}"
echo "  Final replicas:    ${FINAL_REPLICAS}"
echo "  Scale events:      ${SCALE_EVENTS}"
echo "  Total workers:     ${TOTAL_WORKERS}"
echo "  Duration:          ${ELAPSED}s"
echo ""

echo -e "${BLUE}Replica distribution:${NC}"
ssh master "docker service ps web-stress --filter 'desired-state=running' --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}'"
echo ""

echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Check Grafana to verify:"
echo "     - Network sustained >65 Mbps"
echo "     - Load distributed across replicas"
echo "     - CPU/Memory distributed evenly"
echo ""
echo "  2. Check recovery manager logs:"
echo "     ssh master 'docker service logs recovery-manager --tail 50'"
echo ""
echo "  3. Try different configurations:"
echo "     ./scenario2_simple_downloads.sh 100 5 600   # More aggressive"
echo "     ./scenario2_simple_downloads.sh 30 3 900    # More conservative"
echo ""
