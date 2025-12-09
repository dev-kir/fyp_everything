#!/bin/bash
# Debug network stress test

echo "=== 1. Check web-stress service logs ==="
ssh master "docker service logs web-stress --tail 50 | grep -i 'network\|stress\|mbps\|error'"

echo ""
echo ""
echo "=== 2. Check if UDP traffic is being sent ==="
ssh worker-3 "docker ps --filter 'name=web-stress' --format '{{.ID}}' | xargs -I {} docker exec {} netstat -an | grep 9999"

echo ""
echo ""
echo "=== 3. Check network interface stats on worker-3 BEFORE ==="
ssh worker-3 "cat /sys/class/net/enp2s0/statistics/tx_bytes"

echo ""
echo "Waiting 10 seconds..."
sleep 10

echo ""
echo "=== 4. Check network interface stats on worker-3 AFTER ==="
ssh worker-3 "cat /sys/class/net/enp2s0/statistics/tx_bytes"

echo ""
echo ""
echo "=== 5. Check if stress is actually running ==="
curl -s "http://192.168.2.50:8080/metrics" | grep -i stress

echo ""
echo ""
echo "=== 6. Try starting network stress with verbose logging ==="
curl "http://192.168.2.50:8080/stress/network?bandwidth=50&duration=30&ramp=10"

echo ""
echo "Waiting 5 seconds for startup..."
sleep 5

echo ""
echo "=== 7. Check logs again ==="
ssh master "docker service logs web-stress --tail 20"
