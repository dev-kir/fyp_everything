# SwarmGuard: Proactive Recovery Framework for Docker Swarm

**Final Year Project - Proactive Recovery Mechanism for Containerized Applications**

## 🎯 Project Overview

SwarmGuard is a proactive recovery framework that monitors Docker Swarm containers and takes preventive action **before** failures occur, achieving **zero-downtime** recovery with **MTTR < 10 seconds**.

### Key Features
- ✅ **Zero-downtime recovery** (< 2-3 seconds maximum)
- ✅ **MTTR < 10 seconds** (50%+ faster than reactive)
- ✅ **Event-driven alerts** (< 1 second latency)
- ✅ **Two intelligent scenarios**: Migration & Scaling
- ✅ **Network optimized** for 100Mbps infrastructure

## 📁 Project Structure

```
swarmguard/
├── config/swarmguard.yaml              # Main configuration
├── monitoring-agent/                   # Runs on each node
│   ├── agent.py                        # Main event loop
│   ├── metrics_collector.py            # Docker metrics
│   ├── influxdb_writer.py              # Batch writer
│   └── alert_sender.py                 # Sub-second alerts
├── recovery-manager/                   # Runs on master
│   ├── manager.py                      # Flask HTTP server
│   ├── docker_controller.py            # Swarm operations
│   ├── rule_engine.py                  # Scenario detection
│   └── config_loader.py                # YAML loader
├── web-stress/                         # Test application
│   ├── app.py                          # FastAPI server
│   ├── metrics.py                      # Real-time metrics
│   └── stress/                         # CPU/MEM/NET stressors
├── deployment/                         # Deployment scripts
└── tests/                              # Test scripts
```

## 🚀 Quick Start

### Step 1: Build Images (Ubuntu Build Server)

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

### Step 2: Deploy (macOS Control Machine)

```bash
chmod +x deployment/*.sh tests/*.sh

./deployment/create_network.sh
./deployment/deploy_monitoring_agents.sh
./deployment/deploy_recovery_manager.sh
./tests/deploy_web_stress.sh
```

### Step 3: Verify

```bash
ssh master "docker service ls"
curl http://192.168.2.50:5000/health
curl http://192.168.2.50:8080/health
```

### Step 4: Test Scenarios

```bash
# Scenario 1: Migration (high CPU, low network)
curl "http://192.168.2.50:8080/stress/cpu?target=85&duration=120&ramp=30"

# Scenario 2: Scaling (high CPU+MEM+NET)
curl "http://192.168.2.50:8080/stress/combined?cpu=85&memory=1024&network=70&duration=120&ramp=30"
```

## 📊 Monitoring

- **Grafana**: http://192.168.2.61:3000 (admin/admin123)
- **InfluxDB**: http://192.168.2.61:8086
- **Organization**: swarmguard
- **Bucket**: metrics

## 📖 Documentation

- [GETTING_STARTED.md](GETTING_STARTED.md) - Complete setup guide
- [BUILD_AND_PUSH.md](BUILD_AND_PUSH.md) - Build instructions
- [PROJECT_STATUS.md](PROJECT_STATUS.md) - Implementation status

## ⚙️ Configuration

Edit [config/swarmguard.yaml](config/swarmguard.yaml):

```yaml
scenarios:
  scenario1_migration:
    cpu_threshold: 75
    memory_threshold: 80
    network_threshold_max: 35

  scenario2_scaling:
    cpu_threshold: 75
    memory_threshold: 80
    network_threshold_min: 65
```

## 🎯 Success Criteria

- ✅ Alert Latency < 1 second
- ✅ Decision Latency < 1 second
- ✅ Total MTTR < 10 seconds
- ✅ Zero downtime recovery
- ✅ Monitoring overhead < 5% CPU, < 100MB RAM

## 📝 License

Final Year Project - Academic Use Only

---

**Version**: 1.0
**Date**: December 8, 2025
**Status**: ✅ Ready for deployment
