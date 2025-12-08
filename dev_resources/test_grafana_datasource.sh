#!/bin/bash
# Test Grafana datasource configuration

GRAFANA_URL="http://192.168.2.61:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="admin123"

echo "=== Testing Grafana Datasource Configuration ==="
echo

echo "1. Listing all datasources..."
curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/datasources" | python3 -m json.tool

echo
echo "=== Look for the datasource with name 'influxdb-swarmguard' above ==="
echo "=== Copy its 'uid' value and verify it matches what's in your dashboard JSON ==="
echo
echo "If the UID doesn't match 'influxdb-swarmguard', you have two options:"
echo "1. Update the dashboard JSON to use the correct UID"
echo "2. Or update the datasource name in Grafana to 'influxdb-swarmguard'"
