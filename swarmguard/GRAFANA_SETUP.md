# Grafana Setup Guide for SwarmGuard

## Step 1: Configure InfluxDB Datasource in Grafana

1. **Open Grafana** at http://192.168.2.61:3000
2. Login with your credentials (admin/admin123)
3. Go to **Connections** → **Data sources** (or click the gear icon ⚙️ → Data sources)
4. Click **Add data source**
5. Select **InfluxDB**

### Configure the datasource with these settings:

**Query Language**: `Flux`

**HTTP**:
- URL: `http://192.168.2.61:8086`
- Access: `Server (default)`

**Auth**:
- Leave all switches OFF (no basic auth, TLS, etc.)

**InfluxDB Details**:
- Organization: `swarmguard`
- Token: `iNCff-dYnCY8oiO_mDIn3tMIEdl5D1Z4_KFE2vwTMFtQoTqGh2SbL5msNB30DIOKE2wwj-maBW5lTZVJ3f9ONA==`
- Default Bucket: `metrics`
- Min time interval: `5s`

**Custom HTTP Headers** (optional):
- Leave empty

6. Click **Save & Test**
7. You should see: ✅ "datasource is working. 1 buckets found"

## Step 2: Import the Dashboard

### Method 1: Import JSON directly in Grafana UI

1. Go to **Dashboards** → **New** → **Import**
2. Click **Upload JSON file**
3. Select the file: `/Users/amirmuz/code/claude_code/fyp_everything/dev_resources/grafana_dashboard.json`
4. On the import screen:
   - **Name**: SwarmGuard Node Monitoring
   - **Folder**: General (or create a new folder)
   - **DS_INFLUXDB**: Select the InfluxDB datasource you just created
5. Click **Import**

### Method 2: Use Grafana API to import (from your Mac)

```bash
# First, get your Grafana API key or use basic auth
curl -X POST http://192.168.2.61:3000/api/dashboards/db \
  -u admin:admin123 \
  -H "Content-Type: application/json" \
  -d @/Users/amirmuz/code/claude_code/fyp_everything/dev_resources/grafana_dashboard.json
```

## Step 3: Verify Data is Flowing

Once imported, you should see:

1. **Node Selector** dropdown at the top showing: master, worker-1, worker-3, worker-4
2. **Individual Node Metrics** showing CPU, Memory, Network graphs for selected node
3. **All Nodes Overview** showing all nodes' metrics
4. **Current Status Table** showing real-time CPU/Memory for all nodes
5. **Container Details** showing container-level metrics

### If you still see "No data":

**Check the time range:**
- Top right corner, make sure time range is "Last 5 minutes" (default)
- The dashboard auto-refreshes every 5 seconds

**Check the datasource:**
- Click on any panel → Edit
- Look at the query tab
- Make sure the datasource shows your InfluxDB connection

**Verify data in InfluxDB:**
```bash
# Check if data exists (run from your Mac)
curl -s "http://192.168.2.61:8086/api/v2/query?org=swarmguard" \
  -H "Authorization: Token iNCff-dYnCY8oiO_mDIn3tMIEdl5D1Z4_KFE2vwTMFtQoTqGh2SbL5msNB30DIOKE2wwj-maBW5lTZVJ3f9ONA==" \
  -H "Content-Type: application/vnd.flux" \
  -d 'from(bucket: "metrics")
  |> range(start: -5m)
  |> filter(fn: (r) => r._measurement == "nodes")
  |> limit(n: 5)'
```

## Step 4: Dashboard Features

### Panel Descriptions:

1. **CPU Usage - ${node}**: Shows CPU percentage for selected node with thresholds (yellow at 70%, red at 90%)

2. **Memory Usage - ${node}**: Shows memory percentage with thresholds (yellow at 75%, red at 90%)

3. **Network Traffic - ${node}**: Shows both upload and download in Mbps

4. **All Nodes - CPU/Memory/Network**: Overview of all nodes simultaneously

5. **Current Status Table**: Real-time table showing latest CPU and memory values for all nodes

6. **Container Details**: Shows individual container metrics filtered by selected node

### Understanding the Metrics:

- **CPU (%)**: 0-100% per node
- **Memory (%)**: 0-100% per node
- **Network (Mbps)**: Upload/Download traffic on configured interface
  - master: enp5s0f0
  - worker-1: eno1
  - worker-3: enp2s0
  - worker-4: eno1

## Troubleshooting

### Problem: "No data" in all panels

**Solution:**
1. Check monitoring agents are running:
   ```bash
   ssh master "docker service ls | grep monitoring-agent"
   ```

2. Check agent logs:
   ```bash
   ssh master "docker service logs monitoring-agent-master --tail 50"
   ```

3. Verify InfluxDB connection from agent:
   ```bash
   ssh master "docker service logs monitoring-agent-master | grep -i influx"
   ```

### Problem: "Datasource is not working"

**Solution:**
1. Verify InfluxDB is accessible:
   ```bash
   curl -i http://192.168.2.61:8086/health
   ```

2. Verify organization exists:
   ```bash
   curl -s http://192.168.2.61:8086/api/v2/orgs \
     -H "Authorization: Token iNCff-dYnCY8oiO_mDIn3tMIEdl5D1Z4_KFE2vwTMFtQoTqGh2SbL5msNB30DIOKE2wwj-maBW5lTZVJ3f9ONA=="
   ```

### Problem: Node selector is empty

**Solution:**
- This means no data has been written to InfluxDB with the "node" tag
- Check that monitoring agents are writing data
- Wait 5-10 seconds for first data points to arrive

## Dashboard Settings

- **Auto-refresh**: 5 seconds (configurable in top-right)
- **Default time range**: Last 5 minutes
- **Refresh intervals available**: 5s, 10s, 30s, 1m, 5m, 15m, 30m, 1h, 2h, 1d

## Success Verification

After completing the setup, you should see:
- ✅ Real-time metrics updating every 5 seconds
- ✅ Node selector showing all active nodes
- ✅ CPU/Memory graphs showing current values
- ✅ Network traffic graphs showing activity
- ✅ Status table with current values
- ✅ Container details when containers are running
