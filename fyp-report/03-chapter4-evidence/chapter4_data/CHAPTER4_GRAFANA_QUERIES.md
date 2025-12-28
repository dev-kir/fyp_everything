# SwarmGuard Chapter 4 - Grafana Queries and Visualization

**Generated**: 2025-12-27
**Purpose**: InfluxDB/Flux queries used for Grafana dashboards and thesis figures
**Database**: InfluxDB 2.x with Flux query language

---

## 1. BASIC METRICS QUERIES

### 1.1 CPU Percentage Time Series

**Purpose**: Plot CPU usage over time for a specific service

```flux
from(bucket: "metrics")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> filter(fn: (r) => r["service_name"] == "web-stress")
  |> filter(fn: (r) => r["_field"] == "cpu_percent")
  |> aggregateWindow(every: 10s, fn: mean, createEmpty: false)
  |> yield(name: "cpu_percent")
```

**Parameters**:
- `start: -1h`: Last 1 hour of data
- `every: 10s`: Aggregate to 10-second windows (reduces noise)
- `fn: mean`: Average CPU % in each window

**Visualization**: Line chart (time on X-axis, CPU% on Y-axis)

---

### 1.2 Memory Usage Time Series

**Purpose**: Plot memory usage (MB) over time

```flux
from(bucket: "metrics")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> filter(fn: (r) => r["service_name"] == "web-stress")
  |> filter(fn: (r) => r["_field"] == "memory_mb")
  |> aggregateWindow(every: 10s, fn: mean, createEmpty: false)
  |> yield(name: "memory_mb")
```

**Visualization**: Line chart or area chart

---

### 1.3 Network Traffic (RX + TX) Time Series

**Purpose**: Plot combined network traffic

```flux
from(bucket: "metrics")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> filter(fn: (r) => r["service_name"] == "web-stress")
  |> filter(fn: (r) => r["_field"] == "network_rx_mbps" or r["_field"] == "network_tx_mbps")
  |> aggregateWindow(every: 10s, fn: mean, createEmpty: false)
  |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
  |> map(fn: (r) => ({ r with network_total_mbps: r.network_rx_mbps + r.network_tx_mbps }))
  |> yield(name: "network_total")
```

**Calculation**: `network_total_mbps = RX + TX`

**Visualization**: Stacked area chart (RX and TX) or line chart (total)

---

## 2. MULTI-NODE COMPARISON QUERIES

### 2.1 CPU Usage Across All Nodes

**Purpose**: Compare CPU usage across all worker nodes

```flux
from(bucket: "metrics")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> filter(fn: (r) => r["_field"] == "cpu_percent")
  |> aggregateWindow(every: 30s, fn: mean, createEmpty: false)
  |> group(columns: ["node"])
  |> yield(name: "cpu_by_node")
```

**Grouping**: By node (thor, loki, heimdall, freya)

**Visualization**: Multi-line chart (one line per node)

---

### 2.2 Memory Usage Across All Nodes

**Purpose**: Compare memory usage across all worker nodes

```flux
from(bucket: "metrics")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> filter(fn: (r) => r["_field"] == "memory_mb")
  |> aggregateWindow(every: 30s, fn: mean, createEmpty: false)
  |> group(columns: ["node"])
  |> yield(name: "memory_by_node")
```

**Visualization**: Multi-line chart or stacked area chart

---

## 3. THRESHOLD BREACH DETECTION

### 3.1 CPU Threshold Breaches

**Purpose**: Identify when CPU exceeds 75% threshold

```flux
from(bucket: "metrics")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> filter(fn: (r) => r["_field"] == "cpu_percent")
  |> filter(fn: (r) => r["_value"] > 75.0)
  |> aggregateWindow(every: 5s, fn: mean, createEmpty: false)
  |> yield(name: "cpu_breaches")
```

**Filter**: Only data points where CPU > 75%

**Visualization**: Scatter plot or timeline showing breach events

---

### 3.2 Combined Threshold Breach (Scenario 1)

**Purpose**: Detect Scenario 1 conditions (CPU/Memory high + Network low)

```flux
import "experimental"

from(bucket: "metrics")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> filter(fn: (r) =>
      r["_field"] == "cpu_percent" or
      r["_field"] == "memory_percent" or
      r["_field"] == "network_rx_mbps" or
      r["_field"] == "network_tx_mbps"
  )
  |> aggregateWindow(every: 5s, fn: mean, createEmpty: false)
  |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
  |> map(fn: (r) => ({
      r with
      network_total_percent: (r.network_rx_mbps + r.network_tx_mbps) / 100.0 * 100.0,
      scenario1_breach: (r.cpu_percent > 75.0 or r.memory_percent > 80.0) and (r.network_rx_mbps + r.network_tx_mbps) / 100.0 * 100.0 < 35.0
  }))
  |> filter(fn: (r) => r.scenario1_breach == true)
  |> yield(name: "scenario1_breaches")
```

**Logic**: `(CPU > 75% OR Memory > 80%) AND Network < 35%`

**Visualization**: Timeline showing Scenario 1 breach events

---

### 3.3 Combined Threshold Breach (Scenario 2)

**Purpose**: Detect Scenario 2 conditions (CPU/Memory high + Network high)

```flux
import "experimental"

from(bucket: "metrics")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> filter(fn: (r) =>
      r["_field"] == "cpu_percent" or
      r["_field"] == "memory_percent" or
      r["_field"] == "network_rx_mbps" or
      r["_field"] == "network_tx_mbps"
  )
  |> aggregateWindow(every: 5s, fn: mean, createEmpty: false)
  |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
  |> map(fn: (r) => ({
      r with
      network_total_percent: (r.network_rx_mbps + r.network_tx_mbps) / 100.0 * 100.0,
      scenario2_breach: (r.cpu_percent > 75.0 or r.memory_percent > 80.0) and (r.network_rx_mbps + r.network_tx_mbps) / 100.0 * 100.0 > 65.0
  }))
  |> filter(fn: (r) => r.scenario2_breach == true)
  |> yield(name: "scenario2_breaches")
```

**Logic**: `(CPU > 75% OR Memory > 80%) AND Network > 65%`

---

## 4. AGGREGATION QUERIES

### 4.1 Average CPU by Service

**Purpose**: Calculate average CPU usage per service over time window

```flux
from(bucket: "metrics")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> filter(fn: (r) => r["_field"] == "cpu_percent")
  |> group(columns: ["service_name"])
  |> mean()
  |> yield(name: "avg_cpu_by_service")
```

**Result**: Single value per service (e.g., web-stress: 45.2%)

**Visualization**: Bar chart or gauge

---

### 4.2 Maximum Memory Usage

**Purpose**: Find peak memory usage in time window

```flux
from(bucket: "metrics")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> filter(fn: (r) => r["_field"] == "memory_mb")
  |> max()
  |> yield(name: "max_memory")
```

**Result**: Single maximum value

**Visualization**: Stat panel or single-value display

---

## 5. REPLICA COUNT TRACKING

### 5.1 Replica Count Over Time (Custom Query)

**Note**: Replica count is derived from Docker Swarm API, not stored in InfluxDB metrics. Use custom query or logs.

**Alternative Method**: Parse service state from logs or query Docker Swarm API directly.

**Example Docker API Query**:
```bash
docker service ps web-stress --format "{{.CreatedAt}}\t{{.Replicas}}"
```

**Manual Entry for Grafana**: Create annotations from test logs showing replica changes.

---

## 6. OVERHEAD CALCULATION QUERIES

### 6.1 Cluster-Wide CPU Usage

**Purpose**: Calculate total CPU usage across all nodes

```flux
from(bucket: "metrics")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> filter(fn: (r) => r["_field"] == "cpu_percent")
  |> group(columns: ["node"])
  |> mean()
  |> group()
  |> mean()
  |> yield(name: "cluster_avg_cpu")
```

**Result**: Single average CPU % across cluster

---

### 6.2 Memory Overhead Comparison

**Purpose**: Compare memory usage baseline vs full SwarmGuard

```flux
// Baseline memory
baseline_memory = from(bucket: "metrics")
  |> range(start: 2025-12-25T23:00:00Z, stop: 2025-12-25T23:10:00Z)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> filter(fn: (r) => r["_field"] == "memory_mb")
  |> group(columns: ["node"])
  |> mean()

// SwarmGuard memory
swarmguard_memory = from(bucket: "metrics")
  |> range(start: 2025-12-25T23:30:00Z, stop: 2025-12-25T23:40:00Z)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> filter(fn: (r) => r["_field"] == "memory_mb")
  |> group(columns: ["node"])
  |> mean()

// Join and calculate overhead
join(tables: {baseline: baseline_memory, swarmguard: swarmguard_memory}, on: ["node"])
  |> map(fn: (r) => ({ r with overhead_mb: r._value_swarmguard - r._value_baseline }))
  |> yield(name: "memory_overhead")
```

**Result**: Overhead in MB per node

---

## 7. VISUALIZATION EXAMPLES FOR THESIS FIGURES

### 7.1 Figure: CPU Usage Timeline During Migration

**Query**:
```flux
from(bucket: "metrics")
  |> range(start: 2025-12-24T18:12:00Z, stop: 2025-12-24T18:15:00Z)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> filter(fn: (r) => r["service_name"] == "web-stress")
  |> filter(fn: (r) => r["_field"] == "cpu_percent")
  |> aggregateWindow(every: 1s, fn: mean, createEmpty: false)
  |> yield(name: "cpu_during_migration")
```

**Annotations**:
- Mark "Migration Triggered" at 18:13:00
- Mark "Migration Complete" at 18:13:05

**Visualization**: Line chart with vertical annotations

---

### 7.2 Figure: Replica Count Changes (Scenario 2)

**Data Source**: Test logs (`04_scenario2_replicas_test1.log`)

**Manual Data Entry**:
```csv
timestamp,replicas
2025-12-25T16:52:49,1
2025-12-25T16:57:47,2
2025-12-25T17:03:53,1
```

**Visualization**: Step chart showing discrete replica count changes

---

### 7.3 Figure: MTTR Comparison (Box Plot)

**Data Source**: Extracted from test results (not InfluxDB)

**Manual Data Entry**:
```
Baseline: [24, 25, 24, 21, 25, 21, 22, 21, 24, 24]
SwarmGuard: [0, 0, 0, 0, 0, 0, 1, 0, 5, 0]
```

**Visualization**: Box plot or violin plot (use Python matplotlib or Grafana transformation)

---

## 8. DASHBOARD PANEL CONFIGURATIONS

### 8.1 Real-Time Metrics Dashboard

**Panel 1: CPU Gauge**
```flux
from(bucket: "metrics")
  |> range(start: -5m)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> filter(fn: (r) => r["_field"] == "cpu_percent")
  |> last()
```
- **Visualization**: Gauge
- **Thresholds**: Green (0-75%), Yellow (75-85%), Red (85-100%)

**Panel 2: Memory Gauge**
```flux
from(bucket: "metrics")
  |> range(start: -5m)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> filter(fn: (r) => r["_field"] == "memory_percent")
  |> last()
```
- **Visualization**: Gauge
- **Thresholds**: Green (0-80%), Yellow (80-90%), Red (90-100%)

**Panel 3: Network Traffic**
```flux
from(bucket: "metrics")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> filter(fn: (r) => r["_field"] == "network_rx_mbps" or r["_field"] == "network_tx_mbps")
  |> aggregateWindow(every: 10s, fn: mean, createEmpty: false)
```
- **Visualization**: Time series (stacked area)

---

### 8.2 Overhead Analysis Dashboard

**Panel: CPU Overhead by Node**
```flux
from(bucket: "metrics")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> filter(fn: (r) => r["_field"] == "cpu_percent")
  |> group(columns: ["node"])
  |> mean()
```
- **Visualization**: Bar chart (one bar per node)

---

## 9. EXPORTING DATA FOR THESIS

### 9.1 CSV Export Query

**Purpose**: Export metrics to CSV for offline analysis

```flux
from(bucket: "metrics")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> filter(fn: (r) => r["_field"] == "cpu_percent" or r["_field"] == "memory_mb")
  |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
  |> yield(name: "export")
```

**Export Method**: Grafana UI → "Inspect" → "Data" → "Download CSV"

---

### 9.2 JSON Export for Python Analysis

**Purpose**: Export for matplotlib/seaborn visualization

```flux
from(bucket: "metrics")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> yield(name: "json_export")
```

**Export Method**: InfluxDB CLI or Python influxdb_client library

---

## 10. QUERY PERFORMANCE TIPS

### 10.1 Use Time Bounds

**Good**:
```flux
|> range(start: -1h, stop: now())
```

**Bad**:
```flux
|> range(start: 0)  // Queries all data, very slow
```

### 10.2 Use Filters Early

**Good**:
```flux
from(bucket: "metrics")
  |> range(start: -1h)
  |> filter(fn: (r) => r["service_name"] == "web-stress")  // Early filter
  |> aggregateWindow(every: 10s, fn: mean)
```

**Bad**:
```flux
from(bucket: "metrics")
  |> range(start: -1h)
  |> aggregateWindow(every: 10s, fn: mean)
  |> filter(fn: (r) => r["service_name"] == "web-stress")  // Late filter
```

### 10.3 Use Aggregate Windows

**Good**:
```flux
|> aggregateWindow(every: 10s, fn: mean)  // Reduces data points
```

**Bad**:
```flux
// No aggregation, returns all raw data points
```

---

## 11. TROUBLESHOOTING QUERIES

### 11.1 Check Data Exists

```flux
from(bucket: "metrics")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> limit(n: 10)
```

**Purpose**: Verify data is being written to InfluxDB

### 11.2 List All Services

```flux
from(bucket: "metrics")
  |> range(start: -24h)
  |> filter(fn: (r) => r["_measurement"] == "container_metrics")
  |> keep(columns: ["service_name"])
  |> distinct(column: "service_name")
```

**Purpose**: See all service names in database

---

**Grafana Queries Date**: 2025-12-27
**InfluxDB Version**: 2.x
**Query Language**: Flux
**Dashboard Examples**: Real-time monitoring, overhead analysis, MTTR comparison
