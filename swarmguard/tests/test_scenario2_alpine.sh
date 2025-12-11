#!/bin/bash
# SwarmGuard Scenario 2 Test - Autoscaling
# Tests scale-up when CPU+MEM+NET all high, scale-down when low

set -e

echo "=========================================="
echo "SwarmGuard Scenario 2 Test - Autoscaling"
echo "=========================================="
echo ""

# Configuration
SERVICE_URL="http://192.168.2.50:8080"
RECOVERY_MANAGER="192.168.2.50:5000"
INFLUXDB_URL="http://192.168.2.61:8086"
INFLUXDB_TOKEN="iNCff-dYnCY8oiO_mDIn3tMIEdl5D1Z4_KFE2vwTMFtQoTqGh2SbL5msNB30DIOKE2wwj-maBW5lTZVJ3f9ONA=="

echo "Service: $SERVICE_URL"
echo "Recovery Manager: $RECOVERY_MANAGER"
echo ""

# Part 1: Scale-Up Test
echo "=========================================="
echo "PART 1: SCALE-UP TEST"
echo "=========================================="
echo ""

# Check initial replicas
echo "[1/7] Checking initial replica count..."
INITIAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")
echo "✓ Initial replicas: $INITIAL_REPLICAS"
echo ""

# Trigger Scenario 2 Scale-Up: HIGH CPU, HIGH MEM, HIGH NETWORK
echo "[2/7] Triggering Scenario 2 scale-up stress test..."
echo "Parameters: CPU=90%, Memory=900MB, Network=70Mbps (HIGH)"
echo "Duration: 180s, Ramp: 10s"
curl -s "$SERVICE_URL/stress/combined?cpu=90&memory=900&network=70&duration=180&ramp=10"
echo ""
echo "✓ Stress test started"
echo ""

# Wait for ramp-up
echo "[3/7] Waiting 15s for stress ramp-up..."
sleep 15
echo "✓ Ramp-up complete"
echo ""

# Check metrics show high network
echo "[4/7] Verifying HIGH network metrics in InfluxDB..."
METRICS=$(curl -s "$INFLUXDB_URL/api/v2/query?org=swarmguard" \
  -H "Authorization: Token $INFLUXDB_TOKEN" \
  -H "Content-Type: application/vnd.flux" \
  -d "from(bucket: \"metrics\") |> range(start: -1m) |> filter(fn: (r) => r._measurement == \"containers\" and r.service_name == \"web-stress\") |> filter(fn: (r) => r._field == \"network_mbps\") |> last()")

echo "$METRICS" | grep -q "network_mbps" && echo "✓ Network metrics found" || echo "✗ Network metrics missing"
echo ""

# Wait for breach detection and scale-up
echo "[5/7] Waiting 30s for breach detection and scale-up..."
sleep 30
echo "✓ Breach window complete"
echo ""

# Check if scale-up occurred
echo "[6/7] Verifying scale-up occurred..."
sleep 5
NEW_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")

echo "Initial replicas: $INITIAL_REPLICAS"
echo "Current replicas: $NEW_REPLICAS"
echo ""

if [ "$NEW_REPLICAS" -gt "$INITIAL_REPLICAS" ]; then
    echo "✓ SCALE-UP SUCCESSFUL: $INITIAL_REPLICAS → $NEW_REPLICAS replicas"
    SCALE_UP_SUCCESS=1
else
    echo "✗ SCALE-UP FAILED: Still at $INITIAL_REPLICAS replicas"
    SCALE_UP_SUCCESS=0
fi
echo ""

# Show recovery manager logs for scale-up
echo "Recovery Manager logs (scale-up):"
ssh master "docker service logs recovery-manager --tail 10 --no-trunc" | grep -E "(scale|scenario2)"
echo ""

# Part 2: Scale-Down Test
echo "=========================================="
echo "PART 2: SCALE-DOWN TEST"
echo "=========================================="
echo ""

# Stop stress test
echo "[7/7] Stopping stress test to trigger scale-down..."
curl -s "$SERVICE_URL/stress/stop"
echo ""
echo "✓ Stress test stopped"
echo ""

# Wait for cooldown and metrics to drop
echo "Waiting 200s for:"
echo "  - Metrics to drop below thresholds"
echo "  - Scale-down cooldown (180s)"
echo "  - Breach detection (2 breaches @ 10s interval)"
for i in {1..20}; do
    echo -n "."
    sleep 10
done
echo ""
echo "✓ Wait complete"
echo ""

# Check if scale-down occurred
echo "Verifying scale-down occurred..."
FINAL_REPLICAS=$(ssh master "docker service ls --filter name=web-stress --format '{{.Replicas}}' | cut -d'/' -f1")

echo "After scale-up:  $NEW_REPLICAS replicas"
echo "After scale-down: $FINAL_REPLICAS replicas"
echo ""

if [ "$FINAL_REPLICAS" -lt "$NEW_REPLICAS" ]; then
    echo "✓ SCALE-DOWN SUCCESSFUL: $NEW_REPLICAS → $FINAL_REPLICAS replicas"
    SCALE_DOWN_SUCCESS=1
else
    echo "✗ SCALE-DOWN FAILED: Still at $NEW_REPLICAS replicas"
    SCALE_DOWN_SUCCESS=0
fi
echo ""

# Show recovery manager logs for scale-down
echo "Recovery Manager logs (scale-down):"
ssh master "docker service logs recovery-manager --tail 10 --no-trunc" | grep -E "(scale|scenario2)"
echo ""

# Final result
echo "=========================================="
if [ "$SCALE_UP_SUCCESS" -eq 1 ] && [ "$SCALE_DOWN_SUCCESS" -eq 1 ]; then
    echo "✓ SCENARIO 2 TEST PASSED"
    echo "=========================================="
    echo "Scale-up:   $INITIAL_REPLICAS → $NEW_REPLICAS ✓"
    echo "Scale-down: $NEW_REPLICAS → $FINAL_REPLICAS ✓"
    exit 0
elif [ "$SCALE_UP_SUCCESS" -eq 1 ]; then
    echo "⚠ SCENARIO 2 TEST PARTIAL"
    echo "=========================================="
    echo "Scale-up:   $INITIAL_REPLICAS → $NEW_REPLICAS ✓"
    echo "Scale-down: FAILED ✗"
    exit 1
else
    echo "✗ SCENARIO 2 TEST FAILED"
    echo "=========================================="
    echo "Scale-up:   FAILED ✗"
    echo "Scale-down: SKIPPED"
    exit 1
fi
