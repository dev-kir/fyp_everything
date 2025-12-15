# Scenario 2 Test Script Usage

## Overview
The `alpine_scenario2_final.sh` script simulates user-based load to test SwarmGuard's Scenario 2 (autoscaling) behavior.

## Two Modes

### 1. User Simulation Mode (6 parameters)
```bash
./alpine_scenario2_final.sh [USERS_PER_ALPINE] [CPU%] [MEMORY_MB] [NETWORK_MBPS] [RAMP] [DURATION]
```

**Parameters:**
- `USERS_PER_ALPINE` - Number of users to simulate per Alpine node
- `CPU%` - CPU percentage contribution per user
- `MEMORY_MB` - Memory in MB per user
- `NETWORK_MBPS` - Network bandwidth in Mbps per user
- `RAMP` - Ramp-up time in seconds
- `DURATION` - Hold duration in seconds

**Example:**
```bash
./alpine_scenario2_final.sh 10 2 50 5 60 120
```

This means:
- 10 users per Alpine × 4 Alpine nodes = **40 total users**
- Each user contributes: 2% CPU, 50MB RAM, 5Mbps network
- **Expected aggregate load**: 80% CPU, 2000MB RAM, 200Mbps network
- Ramp up over 60 seconds, hold for 120 seconds

### 2. Absolute Target Mode (1 parameter - backward compatible)
```bash
./alpine_scenario2_final.sh [CPU%]
```

**Example:**
```bash
./alpine_scenario2_final.sh 85
```

This sets:
- CPU: 85%
- Memory: 1200MB (fixed)
- Network: 80Mbps (fixed)
- Ramp: 30s, Duration: 180s

## How It Works

1. **User Simulation**: Each Alpine node simulates N users making continuous requests
   - Each user runs in a separate process
   - Makes 30-second requests in a loop
   - 2-second delay between requests to avoid overwhelming

2. **Load Distribution**: Docker Swarm load balancer distributes incoming requests
   - Continuous requests naturally spread across all replicas
   - As new replicas come online, they receive traffic
   - All resources (CPU, Memory, Network) distribute evenly

3. **Ctrl+C Handling**: Press Ctrl+C to gracefully stop all users
   - Trap signal sent to all Alpine nodes
   - All user processes terminate cleanly

4. **Monitoring**: Monitors replica count every 15 seconds and reports scale events

## Expected Behavior

1. **T+0s**: All Alpine nodes start sending requests
2. **T+30-60s**: Load ramps up to target levels
3. **T+90s**: If thresholds met (CPU >80%, MEM >800MB, NET >70Mbps) → Scenario 2 triggers
4. **T+120s**: Scale event: 1 replica → 2 replicas
5. **T+180s**: Load distributes across replicas (visible in Grafana)

## Grafana Visualization

Open Grafana at: http://192.168.2.61:3000

You should see:
- **Before scaling**: One line showing high load on web-stress.1
- **After scaling**: Two lines showing distributed load on web-stress.1 and web-stress.2

## Tuning Examples

### Light Load (Testing)
```bash
./alpine_scenario2_final.sh 5 1 25 3 30 90
# 20 users total: 20% CPU, 500MB RAM, 60Mbps NET
```

### Medium Load (Scenario 2 Threshold)
```bash
./alpine_scenario2_final.sh 10 2 50 5 60 120
# 40 users total: 80% CPU, 2000MB RAM, 200Mbps NET
```

### Heavy Load (Multiple Scale Events)
```bash
./alpine_scenario2_final.sh 15 3 75 7 60 180
# 60 users total: 180% CPU, 4500MB RAM, 420Mbps NET
# Expected: Scale 1→2→3 replicas
```

## Troubleshooting

### No scaling occurs
- Check Grafana - are all 3 metrics (CPU, Memory, Network) above thresholds?
- Scenario 2 requires: CPU >80%, Memory >800MB, Network >70Mbps

### Load not distributing
- Verify replicas actually started: `ssh master "docker service ps web-stress"`
- Check both replicas are running on different worker nodes

### Memory not increasing
- Known issue: memory_stress.py fix not deployed yet
- Rebuild Docker image with latest memory_stress.py changes

### Script hangs or timeouts
- Check Alpine node connectivity: `ssh alpine-1 "wget -q -O /dev/null http://192.168.2.50:8080/health"`
- Verify web-stress service is running: `ssh master "docker service ls"`
