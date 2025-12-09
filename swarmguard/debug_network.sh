#!/bin/bash
# Debug network metrics issue

echo "=== 1. Check InfluxDB for network data ==="
curl -s "http://192.168.2.61:8086/api/v2/query?org=swarmguard" \
  -H "Authorization: Token iNCff-dYnCY8oiO_mDIn3tMIEdl5D1Z4_KFE2vwTMFtQoTqGh2SbL5msNB30DIOKE2wwj-maBW5lTZVJ3f9ONA==" \
  -H "Content-Type: application/vnd.flux" \
  -d 'from(bucket: "metrics")
  |> range(start: -5m)
  |> filter(fn: (r) => r._measurement == "nodes")
  |> filter(fn: (r) => r._field == "net_in" or r._field == "net_out")
  |> limit(n: 20)'

echo ""
echo ""
echo "=== 2. Check monitoring agent logs for network errors ==="
ssh master "docker service logs monitoring-agent-master --tail 50 | grep -i 'net\|error\|exception'"

echo ""
echo ""
echo "=== 3. Check actual network interface stats on master ==="
ssh master "cat /proc/net/dev | grep enp5s0f0"

echo ""
echo ""
echo "=== 4. Check if network interface name is correct ==="
ssh master "ip -br link | grep -E '^(enp|eno|eth)'"
