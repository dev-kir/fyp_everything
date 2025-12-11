#!/bin/bash
# SwarmGuard Scenario 1 Test - Proactive Failover (Migration)
# Tests migration when CPU+MEM high, NET low

set -e

echo "=========================================="
echo "SwarmGuard Scenario 1 Test - Proactive Failover"
echo "=========================================="
echo ""

# Configuration
TARGET_NODE="192.168.2.52"  # worker-1
SERVICE_URL="http://192.168.2.50:8080"
RECOVERY_MANAGER="192.168.2.50:5000"
INFLUXDB_URL="http://192.168.2.61:8086"
INFLUXDB_TOKEN="iNCff-dYnCY8oiO_mDIn3tMIEdl5D1Z4_KFE2vwTMFtQoTqGh2SbL5msNB30DIOKE2wwj-maBW5lTZVJ3f9ONA=="

echo "Target: $TARGET_NODE (worker-1)"
echo "Service: $SERVICE_URL"
echo "Recovery Manager: $RECOVERY_MANAGER"
echo ""

# Check service is running
echo "[1/6] Checking web-stress service..."
INITIAL_NODE=$(ssh master "docker service ps web-stress --format '{{.Node}}' | head -1")
echo "✓ Service running on: $INITIAL_NODE"
echo ""

# Trigger Scenario 1: HIGH CPU, HIGH MEM, LOW NETWORK
echo "[2/6] Triggering Scenario 1 stress test..."
echo "Parameters: CPU=90%, Memory=900MB, Network=5Mbps (LOW)"
echo "Duration: 180s, Ramp: 10s"
curl -s "$SERVICE_URL/stress/combined?cpu=90&memory=900&network=5&duration=180&ramp=10"
echo ""
echo "✓ Stress test started"
echo ""

# Wait for ramp-up
echo "[3/6] Waiting 15s for stress ramp-up..."
sleep 15
echo "✓ Ramp-up complete"
echo ""

# Check metrics in InfluxDB
echo "[4/6] Verifying metrics in InfluxDB..."
METRICS=$(curl -s "$INFLUXDB_URL/api/v2/query?org=swarmguard" \
  -H "Authorization: Token $INFLUXDB_TOKEN" \
  -H "Content-Type: application/vnd.flux" \
  -d "from(bucket: \"metrics\") |> range(start: -1m) |> filter(fn: (r) => r._measurement == \"containers\" and r.service_name == \"web-stress\") |> filter(fn: (r) => r._field == \"cpu_percent\" or r._field == \"memory_percent\" or r._field == \"network_mbps\") |> last()")

echo "$METRICS" | grep -q "cpu_percent" && echo "✓ CPU metrics found" || echo "✗ CPU metrics missing"
echo "$METRICS" | grep -q "memory_percent" && echo "✓ Memory metrics found" || echo "✗ Memory metrics missing"
echo ""

# Wait for breach detection and migration
echo "[5/6] Waiting 30s for breach detection (requires 2 breaches @ 10s interval)..."
sleep 30
echo "✓ Breach window complete"
echo ""

# Check if migration occurred
echo "[6/6] Verifying migration occurred..."
sleep 5
FINAL_NODE=$(ssh master "docker service ps web-stress --format '{{.Node}}' | head -1")

echo "Initial node: $INITIAL_NODE"
echo "Final node:   $FINAL_NODE"
echo ""

if [ "$INITIAL_NODE" != "$FINAL_NODE" ]; then
    echo "=========================================="
    echo "✓ SCENARIO 1 TEST PASSED"
    echo "=========================================="
    echo "Migration successful: $INITIAL_NODE → $FINAL_NODE"
    echo ""

    # Show recovery manager logs
    echo "Recovery Manager logs:"
    ssh master "docker service logs recovery-manager --tail 10 --no-trunc" | grep -E "(Migration|scenario1)"

    exit 0
else
    echo "=========================================="
    echo "✗ SCENARIO 1 TEST FAILED"
    echo "=========================================="
    echo "No migration detected - service still on $INITIAL_NODE"
    echo ""

    # Show debugging info
    echo "Recovery Manager logs:"
    ssh master "docker service logs recovery-manager --tail 20"

    echo ""
    echo "Monitoring Agent logs:"
    ssh master "docker service logs monitoring-agent-worker1 --tail 20"

    exit 1
fi
