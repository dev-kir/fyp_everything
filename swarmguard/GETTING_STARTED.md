# SwarmGuard - Getting Started Guide

## ✅ Setup Complete!

Your InfluxDB is configured:
- **Organization**: swarmguard
- **Bucket**: metrics
- **Token**: `iNCff-dYnCY8oiO_mDIn3tMIEdl5D1Z4_KFE2vwTMFtQoTqGh2SbL5msNB30DIOKE2wwj-maBW5lTZVJ3f9ONA==`

## 📁 Project Structure Created

```
swarmguard/
├── README.md                    # Main project documentation
├── BUILD_AND_PUSH.md            # Build instructions
├── GETTING_STARTED.md           # This file
├── config/
│   └── swarmguard.yaml          # Main configuration file
├── monitoring-agent/            # ✅ COMPLETE
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── agent.py                 # Main agent (event-driven alerts)
│   ├── metrics_collector.py     # Docker metrics collection
│   ├── influxdb_writer.py       # Async InfluxDB writer
│   └── alert_sender.py          # Sub-second alert sender
├── recovery-manager/            # ✅ COMPLETE
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── config.yaml              # Default config
│   ├── manager.py               # Flask HTTP server
│   ├── rule_engine.py           # Scenario detection
│   ├── docker_controller.py     # Docker Swarm operations
│   └── config_loader.py         # YAML config loader
├── web-stress/                  # ✅ COMPLETE
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py                   # FastAPI application
│   ├── metrics.py               # Real-time metrics
│   └── stress/
│       ├── cpu_stress.py        # Gradual CPU load
│       ├── memory_stress.py     # Gradual memory allocation
│       └── network_stress.py    # Gradual network traffic
├── deployment/                  # ✅ SCRIPTS READY
│   ├── create_network.sh
│   ├── deploy_monitoring_agents.sh
│   └── deploy_recovery_manager.sh
└── tests/                       # ✅ SCRIPTS READY
    └── deploy_web_stress.sh
```

## 🚀 Quick Start (Step-by-Step)

### Step 1: Build Docker Images

**On your Ubuntu build server:**

```bash
# Clone/pull the swarmguard project
cd /path/to/swarmguard

# Build all images
./build_all.sh  # See BUILD_AND_PUSH.md for details
```

Or manually:

```bash
cd monitoring-agent
docker build -t docker-registry.amirmuz.com/swarmguard-agent:latest .
docker push docker-registry.amirmuz.com/swarmguard-agent:latest

cd ../recovery-manager
docker build -t docker-registry.amirmuz.com/swarmguard-manager:latest .
docker push docker-registry.amirmuz.com/swarmguard-manager:latest

cd ../web-stress
docker build -t docker-registry.amirmuz.com/swarmguard-web-stress:latest .
docker push docker-registry.amirmuz.com/swarmguard-web-stress:latest
```

### Step 2: Deploy SwarmGuard

**On your macOS control machine:**

```bash
cd swarmguard

# Make scripts executable
chmod +x deployment/*.sh tests/*.sh

# 1. Create overlay network
./deployment/create_network.sh

# 2. Deploy monitoring agents to all nodes
./deployment/deploy_monitoring_agents.sh

# 3. Deploy recovery manager on master
./deployment/deploy_recovery_manager.sh

# 4. Deploy test application
./tests/deploy_web_stress.sh
```

### Step 3: Verify Everything is Running

```bash
# Check all services
ssh master "docker service ls"

# Expected output:
# ID    NAME                          REPLICAS
# ...   monitoring-agent-master       1/1
# ...   monitoring-agent-worker1      1/1
# ...   monitoring-agent-worker3      1/1
# ...   monitoring-agent-worker4      1/1
# ...   recovery-manager              1/1
# ...   web-stress                    1/1

# Check recovery manager health
curl http://192.168.2.50:5000/health

# Check web-stress health
curl http://192.168.2.50:8080/health
```

### Step 4: Test the System

#### Test Scenario 1: Container Migration

```bash
# Trigger CPU stress (high CPU, low network = migration)
curl "http://192.168.2.50:8080/stress/cpu?target=85&duration=120&ramp=30"

# Watch Grafana dashboard at http://192.168.2.61:3000
# You should see:
# 1. CPU spike on one container
# 2. Alert sent to recovery manager
# 3. New container created on different node
# 4. Old container removed
# 5. Total time < 10 seconds
```

#### Test Scenario 2: Horizontal Scaling

```bash
# Trigger combined stress (high CPU+MEM+NET = scaling)
curl "http://192.168.2.50:8080/stress/combined?cpu=85&memory=1024&network=70&duration=120&ramp=30"

# You should see:
# 1. All metrics spike
# 2. Service scales from 1 to 2 replicas
# 3. Load distributed across both replicas
# 4. Total time < 10 seconds
```

## 📊 Monitoring

### Grafana Dashboards

1. Access Grafana: http://192.168.2.61:3000
   - Username: `admin`
   - Password: `admin123`

2. Add InfluxDB data source:
   - URL: `http://192.168.2.61:8086`
   - Organization: `swarmguard`
   - Token: `iNCff-dYnCY8oiO_mDIn3tMIEdl5D1Z4_KFE2vwTMFtQoTqGh2SbL5msNB30DIOKE2wwj-maBW5lTZVJ3f9ONA==`
   - Bucket: `metrics`

3. Import dashboard from `docs/grafana_dashboard.json`

### Viewing Logs

```bash
# Monitoring agent logs
ssh master "docker service logs monitoring-agent-master -f"

# Recovery manager logs
ssh master "docker service logs recovery-manager -f"

# Web-stress logs
ssh master "docker service logs web-stress -f"
```

## 🔧 Configuration

Edit `config/swarmguard.yaml` to adjust:

- **CPU thresholds**: Default 75%
- **Memory thresholds**: Default 80%
- **Network thresholds**: Default 35% (low) / 65% (high)
- **Cooldown periods**: Default 30s (migration) / 60s (scaling)
- **Poll interval**: Default 5 seconds

After changing config:
1. Rebuild recovery-manager image
2. Redeploy: `./deployment/deploy_recovery_manager.sh`

## 🧪 Testing

### Manual Testing

```bash
# Stop all stress
curl http://192.168.2.50:8080/stress/stop

# Test CPU only
curl "http://192.168.2.50:8080/stress/cpu?target=80&duration=60&ramp=20"

# Test memory only
curl "http://192.168.2.50:8080/stress/memory?target=2048&duration=60&ramp=20"

# Check current metrics
curl http://192.168.2.50:8080/metrics
```

### Load Testing with Alpine Pis

```bash
# On each Alpine Pi, generate traffic
for i in {1..4}; do
  ssh alpine-$i "while true; do curl -s http://192.168.2.50:8080/health; sleep 0.1; done" &
done

# Stop all
pkill -f "ssh alpine"
```

## 📈 Success Criteria

Your system is working correctly if:

✅ **Alert Latency < 1 second** (check logs for timing)
✅ **Decision Latency < 1 second** (check recovery manager logs)
✅ **Total MTTR < 10 seconds** (measure from threshold breach to recovery)
✅ **Zero downtime** (no failed requests during recovery)
✅ **Monitoring overhead < 5% CPU, < 100MB RAM per node**

## 🐛 Troubleshooting

### Services Not Starting

```bash
# Check service status
ssh master "docker service ps <service-name> --no-trunc"

# Check logs for errors
ssh master "docker service logs <service-name>"
```

### Metrics Not Appearing in InfluxDB

```bash
# Test InfluxDB write manually
curl -X POST "http://192.168.2.61:8086/api/v2/write?org=swarmguard&bucket=metrics&precision=s" \
  -H "Authorization: Token iNCff-dYnCY8oiO_mDIn3tMIEdl5D1Z4_KFE2vwTMFtQoTqGh2SbL5msNB30DIOKE2wwj-maBW5lTZVJ3f9ONA==" \
  -H "Content-Type: text/plain; charset=utf-8" \
  --data-binary "test,host=test value=1.0"

# Query data
curl "http://192.168.2.61:8086/api/v2/query?org=swarmguard" \
  -H "Authorization: Token iNCff-dYnCY8oiO_mDIn3tMIEdl5D1Z4_KFE2vwTMFtQoTqGh2SbL5msNB30DIOKE2wwj-maBW5lTZVJ3f9ONA==" \
  -H "Content-Type: application/vnd.flux" \
  -d 'from(bucket:"metrics") |> range(start: -5m)'
```

### Recovery Actions Not Triggering

```bash
# Check recovery manager is receiving alerts
ssh master "docker service logs recovery-manager | grep Alert"

# Check thresholds are being exceeded
curl http://192.168.2.50:8080/metrics

# Manually trigger alert (for testing)
curl -X POST http://192.168.2.50:5000/alert \
  -H "Content-Type: application/json" \
  -d '{"node":"test","container_id":"test123","service_name":"web-stress","scenario":"scenario1_migration","metrics":{"cpu_percent":85,"memory_percent":80,"network_percent":20}}'
```

## 📚 Next Steps

1. **Run Full Test Suite** - Create comprehensive test scripts
2. **Measure MTTR** - Compare proactive vs reactive recovery
3. **Tune Thresholds** - Optimize for your workload
4. **Document Results** - Collect metrics for your FYP report

## 📞 Support

For issues:
1. Check logs (see Troubleshooting section)
2. Verify InfluxDB connectivity
3. Ensure Docker Swarm is healthy
4. Review configuration in `config/swarmguard.yaml`
