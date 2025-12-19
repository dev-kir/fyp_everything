# Grafana Panels for Load Balancer Visualization

This guide shows how to add panels to your Grafana dashboard to visualize the lease-based load balancing in action.

## Prerequisites

1. Deploy the LB metrics collector:
   ```bash
   cd /Users/amirmuz/code/claude_code/fyp_everything/swarmguard/monitoring
   ./deploy_lb_metrics_collector.sh
   ```

2. Verify metrics are being collected:
   ```bash
   # Check collector logs
   ssh master 'docker service logs -f lb-metrics-collector'

   # Query InfluxDB directly to verify data
   curl -X POST "http://192.168.2.61:8086/api/v2/query?org=swarmguard" \
     -H "Authorization: Token iNCff-dYnCY8oiO_mDIn3tMIEdl5D1Z4_KFE2vwTMFtQoTqGh2SbL5msNB30DIOKE2wwj-maBW5lTZVJ3f9ONA==" \
     -H "Content-Type: application/vnd.flux" \
     -d 'from(bucket: "metrics") |> range(start: -5m) |> filter(fn: (r) => r._measurement == "lb_replica_metrics")'
   ```

## New Dashboard Section: Load Balancer Metrics

Add these panels to your existing dashboard to visualize load distribution.

---

### Panel 1: Total Requests Over Time

**Type:** Time Series
**Description:** Shows total requests handled by the load balancer

**Flux Query:**
```flux
from(bucket: "metrics")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "lb_metrics")
  |> filter(fn: (r) => r._field == "total_requests")
  |> aggregateWindow(every: 5s, fn: last, createEmpty: false)
  |> yield(name: "total_requests")
```

**Panel Settings:**
- Y-axis label: "Total Requests"
- Line width: 2
- Show points: never
- Fill opacity: 10%

---

### Panel 2: Request Distribution by Node (Bar Chart)

**Type:** Bar Chart
**Description:** Shows how requests are distributed across nodes - THIS IS THE KEY METRIC!

**Flux Query:**
```flux
from(bucket: "metrics")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "lb_replica_metrics")
  |> filter(fn: (r) => r._field == "request_count")
  |> group(columns: ["node"])
  |> last()
  |> group()
  |> yield(name: "request_distribution")
```

**Panel Settings:**
- Orientation: Vertical
- Show values: On
- Legend: Bottom
- Color scheme: By series

**Why this is important:**
- Before Scenario 2: You'll see 1-2 bars (original replicas)
- After scale-up: You'll see 4-5 bars showing load distributed evenly
- This visually demonstrates the lease algorithm working!

---

### Panel 3: Request Distribution Over Time (Time Series)

**Type:** Time Series
**Description:** Shows request count per node over time - watch it distribute!

**Flux Query:**
```flux
from(bucket: "metrics")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "lb_replica_metrics")
  |> filter(fn: (r) => r._field == "request_count")
  |> aggregateWindow(every: 10s, fn: last, createEmpty: false)
  |> yield(name: "requests_per_node")
```

**Panel Settings:**
- Y-axis label: "Cumulative Requests"
- Legend: Show with values (last, max)
- Draw style: Line
- Line width: 2

**What to look for:**
- Lines should start at different times as replicas scale up
- Slopes should be similar (showing even distribution)
- Gap between lines should stay relatively constant

---

### Panel 4: Active Leases by Node

**Type:** Time Series
**Description:** Shows active lease count per node in real-time

**Flux Query:**
```flux
from(bucket: "metrics")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "lb_replica_metrics")
  |> filter(fn: (r) => r._field == "active_leases")
  |> aggregateWindow(every: 5s, fn: last, createEmpty: false)
  |> yield(name: "active_leases")
```

**Panel Settings:**
- Y-axis label: "Active Leases"
- Min: 0
- Draw style: Line
- Line width: 2
- Fill opacity: 20%

**What to look for:**
- Values should be similar across all nodes (load balancing)
- Spikes show bursts of traffic
- Values should rarely exceed 10-20 (with 30s lease duration)

---

### Panel 5: Healthy Replicas Count

**Type:** Stat
**Description:** Shows number of healthy replicas

**Flux Query:**
```flux
from(bucket: "metrics")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "lb_metrics")
  |> filter(fn: (r) => r._field == "healthy_replicas")
  |> last()
  |> yield(name: "healthy_replicas")
```

**Panel Settings:**
- Type: Stat
- Value: Last
- Color mode: Background
- Thresholds:
  - Green: >= 2
  - Yellow: 1
  - Red: 0

---

### Panel 6: Request Rate (Requests per Second)

**Type:** Time Series
**Description:** Shows incoming request rate

**Flux Query:**
```flux
from(bucket: "metrics")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "lb_metrics")
  |> filter(fn: (r) => r._field == "total_requests")
  |> derivative(unit: 1s, nonNegative: true)
  |> yield(name: "request_rate")
```

**Panel Settings:**
- Y-axis label: "Requests/sec"
- Min: 0
- Draw style: Bars
- Fill opacity: 50%

---

### Panel 7: Load Distribution Table

**Type:** Table
**Description:** Current snapshot of load per node

**Flux Query:**
```flux
from(bucket: "metrics")
  |> range(start: -5m)
  |> filter(fn: (r) => r._measurement == "lb_replica_metrics")
  |> pivot(rowKey:["_time"], columnKey:["_field"], valueColumn:"_value")
  |> group(columns:["node", "replica_id"])
  |> last()
  |> group()
  |> keep(columns:["node", "replica_id", "request_count", "active_leases", "healthy"])
  |> sort(columns:["request_count"], desc:true)
```

**Panel Settings:**
- Column renames:
  - node → "Node"
  - replica_id → "Replica ID"
  - request_count → "Total Requests"
  - active_leases → "Active Leases"
  - healthy → "Healthy"

---

## Recommended Dashboard Layout

```
+----------------------------------+----------------------------------+
|                                  |                                  |
|   Total Requests Over Time       |   Healthy Replicas (Stat)       |
|   (Time Series)                  |   Request Rate (Time Series)    |
|                                  |                                  |
+----------------------------------+----------------------------------+
|                                                                     |
|   Request Distribution by Node (Bar Chart) ← MAIN PANEL            |
|   Shows even distribution across nodes                             |
|                                                                     |
+---------------------------------------------------------------------+
|                                                                     |
|   Request Distribution Over Time (Time Series)                     |
|   Watch the lines grow at similar rates                            |
|                                                                     |
+---------------------------------------------------------------------+
|                                  |                                  |
|   Active Leases by Node          |   Load Distribution Table       |
|   (Time Series)                  |   (Table)                        |
|                                  |                                  |
+----------------------------------+----------------------------------+
```

---

## How to Add Panels to Your Dashboard

1. **Open Grafana**: http://192.168.2.61:3000
2. **Navigate to**: Dashboards → SwarmGuard_All_Sum
3. **Add new row**:
   - Click "Add" → "Row"
   - Name it "Load Balancer Distribution"
4. **Add panels**:
   - Click "Add" → "Visualization"
   - Select "InfluxDB - swarmguard" as data source
   - Paste the Flux query
   - Configure panel settings as shown above
   - Click "Apply"

---

## Testing Scenario

### Step 1: Baseline (Before Scaling)
1. Start with 2 replicas of web-stress
2. Run load test with Alpine nodes
3. Observe in Grafana:
   - Bar chart shows 2 bars (2 nodes)
   - Request distribution shows 2 lines growing
   - Both getting ~50% of traffic

### Step 2: During Scaling (Scenario 2 triggers)
1. Recovery manager detects high CPU/memory
2. Scales to 4-5 replicas
3. Observe in Grafana:
   - Bar chart grows to 4-5 bars
   - New lines appear in time series
   - Load redistributes across all replicas
   - Each node gets ~20-25% of traffic

### Step 3: After Scaling
1. Load distributed evenly across all replicas
2. Bar chart heights similar
3. Active leases similar across nodes
4. This proves lease-based LB is working!

---

## Key Metrics to Screenshot for FYP

1. **Request Distribution Bar Chart** - Shows even distribution
2. **Request Distribution Over Time** - Shows parallel growth
3. **Active Leases** - Shows fairness in real-time
4. **Before/After comparison** - 2 nodes → 5 nodes with even split

These visuals will clearly demonstrate that your lease-based load balancer is distributing traffic fairly across all scaled replicas!

---

## Troubleshooting

**No data in panels:**
```bash
# Check if collector is running
ssh master 'docker service ps lb-metrics-collector'

# Check collector logs
ssh master 'docker service logs lb-metrics-collector'

# Check if LB is exposing metrics
curl http://192.168.2.50:8081/metrics | jq

# Query InfluxDB directly
curl -X POST "http://192.168.2.61:8086/api/v2/query?org=swarmguard" \
  -H "Authorization: Token iNCff-dYnCY8oiO_mDIn3tMIEdl5D1Z4_KFE2vwTMFtQoTqGh2SbL5msNB30DIOKE2wwj-maBW5lTZVJ3f9ONA==" \
  -H "Content-Type: application/vnd.flux" \
  -d 'from(bucket: "metrics") |> range(start: -1h) |> filter(fn: (r) => r._measurement == "lb_replica_metrics") |> limit(n: 10)'
```

**Metrics not updating:**
- Check COLLECTION_INTERVAL (default 5s)
- Verify LB is receiving traffic
- Check network connectivity between collector and LB

**Wrong node names:**
- Ensure monitoring-agent is running on all nodes
- Check Docker service discovery is working
