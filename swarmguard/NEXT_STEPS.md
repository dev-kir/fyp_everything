# SwarmGuard - Next Steps

## ✅ Completed
- All monitoring agents deployed (master, worker-1, worker-3, worker-4)
- Recovery manager deployed and healthy
- Web-stress application deployed
- InfluxDB receiving metrics
- Grafana dashboard JSON configured

## 🔧 Immediate Fix Required

### 1. Rebuild and Redeploy Web-Stress (CPU Stress Fix)

The CPU stress test was not generating enough load. I've fixed the algorithm to be more intensive.

**On your build server:**
```bash
cd web-stress
docker build -t docker-registry.amirmuz.com/swarmguard-web-stress:latest .
docker push docker-registry.amirmuz.com/swarmguard-web-stress:latest
```

**On your Mac:**
```bash
# Remove old service
ssh master "docker service rm web-stress"

# Wait 5 seconds
sleep 5

# Redeploy with new image
./tests/deploy_web_stress.sh
```

### 2. Import Grafana Dashboard

The dashboard JSON has been fixed with the correct datasource UID: `bf6isq46kqpkwb`

**In Grafana (http://192.168.2.61:3000):**
1. Delete existing "SwarmGuard Node Monitoring" dashboard (if any)
2. Go to **Dashboards** → **New** → **Import**
3. Upload: `dev_resources/grafana_dashboard_swarmguard.json`
4. Click **Import**

## 🧪 Testing Scenarios

Once web-stress is redeployed with the fix:

### Scenario 1: Migration (High CPU/MEM, Low Network)
```bash
curl "http://192.168.2.50:8080/stress/cpu?target=85&duration=120&ramp=30"
```

**Expected behavior:**
- CPU usage rises to 85% on worker-3 (where web-stress runs)
- Network stays low (< 35 Mbps)
- After 2 consecutive breaches (10 seconds), recovery manager should:
  - Detect Scenario 1
  - Migrate container to a different node
  - Log: "RECOVERY ACTION: Migrating container..."

### Scenario 2: Scaling (High CPU+MEM+NET)
```bash
curl "http://192.168.2.50:8080/stress/combined?cpu=85&memory=1024&network=70&duration=120&ramp=30"
```

**Expected behavior:**
- CPU: 85%, Memory: increases to 1GB+, Network: 70 Mbps
- After 2 consecutive breaches, recovery manager should:
  - Detect Scenario 2
  - Scale up web-stress service
  - Log: "RECOVERY ACTION: Scaling up service..."

## 📊 Monitoring

### Watch Recovery Manager Logs
```bash
ssh master "docker service logs recovery-manager -f"
```

### Watch Monitoring Agent Logs
```bash
ssh master "docker service logs monitoring-agent-worker3 -f"
```

### Check Service Status
```bash
ssh master "docker service ls"
ssh master "docker service ps web-stress"
```

### Grafana Dashboard
- URL: http://192.168.2.61:3000
- Dashboard: "SwarmGuard Node Monitoring"
- Select node: master, worker-1, worker-3, worker-4
- Auto-refresh: 5 seconds

## 📝 Configuration Reference

### Active Nodes
- master: 192.168.2.50 (enp5s0f0)
- worker-1: 192.168.2.51 (eno1)
- worker-2: 192.168.2.52 (enp0s25) - configured but not deployed
- worker-3: 192.168.2.53 (enp2s0)
- worker-4: 192.168.2.54 (eno1)

### Thresholds (config/swarmguard.yaml)
```yaml
scenario1_migration:
  cpu_threshold: 75
  memory_threshold: 80
  network_threshold_max: 35
  consecutive_breaches: 2

scenario2_scaling:
  cpu_threshold: 75
  memory_threshold: 80
  network_threshold_min: 65
  consecutive_breaches: 2
```

### Services
- **Monitoring Agents**: Poll every 5 seconds, write to InfluxDB in batches
- **Recovery Manager**: HTTP server on port 5000, receives alerts from agents
- **Web-Stress**: HTTP server on port 8080, generates CPU/MEM/NET load

## 🎯 Success Criteria

- ✅ Alert Latency < 1 second
- ✅ Decision Latency < 1 second
- ✅ Total MTTR < 10 seconds
- ✅ Zero downtime recovery
- ✅ Monitoring overhead < 5% CPU, < 100MB RAM

## 🐛 Troubleshooting

### If CPU stress still doesn't work after rebuild:
Check container CPU limit:
```bash
ssh master "docker service inspect web-stress --format '{{.Spec.TaskTemplate.Resources.Limits.NanoCPUs}}'"
```

If limited, update deployment script to remove limits.

### If no alerts are sent to recovery manager:
1. Check monitoring agent logs for "Alert sent" messages
2. Verify recovery manager is accessible: `curl http://192.168.2.50:5000/health`
3. Check thresholds aren't too high in config/swarmguard.yaml

### If Grafana still shows "No data":
1. Verify datasource UID: `bf6isq46kqpkwb`
2. Test InfluxDB query directly:
   ```bash
   curl -s "http://192.168.2.61:8086/api/v2/query?org=swarmguard" \
     -H "Authorization: Token iNCff-dYnCY8oiO_mDIn3tMIEdl5D1Z4_KFE2vwTMFtQoTqGh2SbL5msNB30DIOKE2wwj-maBW5lTZVJ3f9ONA==" \
     -H "Content-Type: application/vnd.flux" \
     -d 'from(bucket: "metrics") |> range(start: -5m) |> limit(n: 5)'
   ```

## 📚 Documentation Files

- [README.md](README.md) - Project overview
- [GETTING_STARTED.md](GETTING_STARTED.md) - Step-by-step setup
- [BUILD_AND_PUSH.md](BUILD_AND_PUSH.md) - Build instructions
- [GRAFANA_SETUP.md](GRAFANA_SETUP.md) - Grafana configuration
- [PROJECT_STATUS.md](PROJECT_STATUS.md) - Implementation status

---

**Status**: Ready for testing after web-stress rebuild
**Last Updated**: December 8, 2025
