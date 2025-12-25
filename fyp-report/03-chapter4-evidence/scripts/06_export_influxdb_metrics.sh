#!/bin/bash
# Section 6: Export InfluxDB Metrics
# Exports time-series metrics data from InfluxDB for custom analysis/graphing
# Usage: ./06_export_influxdb_metrics.sh

set -e

echo "=========================================="
echo "SECTION 6: INFLUXDB METRICS EXPORT"
echo "=========================================="
echo ""
echo "This script will export metrics data from InfluxDB for:"
echo "  - Baseline tests"
echo "  - Scenario 1 tests"
echo "  - Scenario 2 tests"
echo ""
echo "Exported data can be used for custom graphs and analysis"
echo ""
echo "Duration: ~5-10 minutes"
echo ""
read -p "Press ENTER to start export..."

OUTPUT_DIR="/Users/amirmuz/RESULT_FYP_EVERYTHING/influxdb_export"
mkdir -p "$OUTPUT_DIR"

INFLUXDB_URL="http://192.168.2.61:8086"
INFLUXDB_ORG="swarmguard"
INFLUXDB_BUCKET="metrics"
INFLUXDB_TOKEN="iNCff-dYnCY8oiO_mDIn3tMIEdl5D1Z4_KFE2vwTMFtQoTqGh2SbL5msNB30DIOKE2wwj-maBW5lTZVJ3f9ONA=="

# Helper function to export metrics
export_metrics() {
    local measurement="$1"
    local start_time="$2"
    local stop_time="$3"
    local output_file="$4"
    local label="$5"

    echo "Exporting $label..."

    # Flux query to export data
    query="from(bucket: \"$INFLUXDB_BUCKET\")
  |> range(start: $start_time, stop: $stop_time)
  |> filter(fn: (r) => r._measurement == \"$measurement\")
  |> pivot(rowKey:[\"_time\"], columnKey: [\"_field\"], valueColumn: \"_value\")"

    # Execute query and save to CSV
    curl -s -XPOST "$INFLUXDB_URL/api/v2/query?org=$INFLUXDB_ORG" \
      -H "Authorization: Token $INFLUXDB_TOKEN" \
      -H "Accept: application/csv" \
      -H "Content-type: application/vnd.flux" \
      -d "$query" > "$output_file"

    # Check if export was successful
    if [ -s "$output_file" ]; then
        line_count=$(wc -l < "$output_file")
        echo "✓ Exported $((line_count - 1)) data points to $output_file"
    else
        echo "⚠️  Warning: No data exported for $label"
    fi
}

# ===========================================
# Export Container Metrics
# ===========================================
echo ""
echo "=========================================="
echo "EXPORTING CONTAINER METRICS"
echo "=========================================="

# Export last 24 hours of container metrics
export_metrics \
    "container_metrics" \
    "-24h" \
    "now()" \
    "$OUTPUT_DIR/container_metrics_24h.csv" \
    "Container Metrics (Last 24 hours)"

# ===========================================
# Export Node Metrics
# ===========================================
echo ""
echo "=========================================="
echo "EXPORTING NODE METRICS"
echo "=========================================="

export_metrics \
    "node_metrics" \
    "-24h" \
    "now()" \
    "$OUTPUT_DIR/node_metrics_24h.csv" \
    "Node Metrics (Last 24 hours)"

# ===========================================
# Export Network Metrics
# ===========================================
echo ""
echo "=========================================="
echo "EXPORTING NETWORK METRICS"
echo "=========================================="

export_metrics \
    "network_metrics" \
    "-24h" \
    "now()" \
    "$OUTPUT_DIR/network_metrics_24h.csv" \
    "Network Metrics (Last 24 hours)"

# ===========================================
# Export Specific Test Periods (if you have exact timestamps)
# ===========================================
echo ""
echo "=========================================="
echo "EXPORT SPECIFIC TEST PERIODS (OPTIONAL)"
echo "=========================================="
echo ""
echo "If you know exact test timestamps, you can export specific periods:"
echo ""
echo "Example commands (edit with your actual timestamps):"
echo ""
echo "# Export Baseline Test 1 (2024-12-24 08:49:00 to 08:52:00)"
echo "# export_metrics 'container_metrics' '2024-12-24T08:49:00Z' '2024-12-24T08:52:00Z' \\"
echo "#   '$OUTPUT_DIR/baseline_test1.csv' 'Baseline Test 1'"
echo ""
echo "# Export Scenario 2 Test 1 (2024-12-25 16:52:00 to 17:08:00)"
echo "# export_metrics 'container_metrics' '2024-12-25T16:52:00+08:00' '2024-12-25T17:08:00+08:00' \\"
echo "#   '$OUTPUT_DIR/scenario2_test1.csv' 'Scenario 2 Test 1'"
echo ""

# ===========================================
# Generate Summary
# ===========================================
echo ""
echo "=========================================="
echo "GENERATING SUMMARY"
echo "=========================================="

cat > "$OUTPUT_DIR/README.txt" << 'EOF'
InfluxDB Metrics Export
========================

This directory contains time-series metrics data exported from InfluxDB.

Files Generated:
----------------
- container_metrics_24h.csv: Container-level metrics (CPU, Memory, Network)
- node_metrics_24h.csv: Node-level metrics (system resources)
- network_metrics_24h.csv: Network traffic metrics
- README.txt: This file

CSV Format:
-----------
Each CSV file contains columns:
- _time: Timestamp (ISO 8601 format)
- _measurement: Metric name
- host/node: Node identifier
- container_name: Container identifier (if applicable)
- cpu_percent: CPU usage percentage
- memory_mb: Memory usage in megabytes
- network_rx_mbps: Network receive in Mbps
- network_tx_mbps: Network transmit in Mbps
- ... (other fields depending on measurement)

Usage:
------
These CSV files can be imported into:
- Python (pandas, matplotlib) for custom graphs
- Excel/Google Sheets for manual analysis
- R for statistical analysis
- Tableau/Power BI for visualization

Example Python Usage:
---------------------
import pandas as pd
import matplotlib.pyplot as plt

# Load data
df = pd.read_csv('container_metrics_24h.csv')
df['_time'] = pd.to_datetime(df['_time'])

# Filter for specific container
web_stress = df[df['container_name'] == 'web-stress']

# Plot CPU over time
plt.figure(figsize=(12, 6))
plt.plot(web_stress['_time'], web_stress['cpu_percent'])
plt.xlabel('Time')
plt.ylabel('CPU %')
plt.title('Web-Stress CPU Usage Over Time')
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig('cpu_usage.png')

Notes:
------
- Data is exported in CSV format for maximum compatibility
- Timestamps are in UTC (or local timezone if specified)
- Large exports may take time to load in Excel
- For better performance, use Python pandas or R for analysis

Time Range:
-----------
Current export covers the last 24 hours from the time of export.
To export specific test periods, edit the script with exact timestamps.
EOF

echo "✓ Summary created: $OUTPUT_DIR/README.txt"

echo ""
echo "=========================================="
echo "EXPORT COMPLETE"
echo "=========================================="
echo ""
echo "Results saved to: $OUTPUT_DIR/"
echo "Files:"
ls -lh "$OUTPUT_DIR/" | tail -n +2 | awk '{print "  - " $9 " (" $5 ")"}'
echo ""
echo "You can now:"
echo "  1. Import CSV files into Python/R for custom graphs"
echo "  2. Open in Excel/Google Sheets for manual analysis"
echo "  3. Use with visualization tools (Tableau, Power BI)"
echo ""
echo "See README.txt in the output directory for usage examples"
