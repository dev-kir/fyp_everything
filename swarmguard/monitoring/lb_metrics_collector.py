#!/usr/bin/env python3
"""
LB Metrics Collector - Fetches metrics from intelligent-lb and pushes to InfluxDB
This allows visualization of load balancing distribution in Grafana
"""

import requests
import time
import os
import logging
from influxdb_client import InfluxDBClient, Point
from influxdb_client.client.write_api import SYNCHRONOUS

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration from environment
INFLUXDB_URL = os.getenv('INFLUXDB_URL', 'http://192.168.2.61:8086')
INFLUXDB_ORG = os.getenv('INFLUXDB_ORG', 'swarmguard')
INFLUXDB_BUCKET = os.getenv('INFLUXDB_BUCKET', 'metrics')
INFLUXDB_TOKEN = os.getenv('INFLUXDB_TOKEN', 'iNCff-dYnCY8oiO_mDIn3tMIEdl5D1Z4_KFE2vwTMFtQoTqGh2SbL5msNB30DIOKE2wwj-maBW5lTZVJ3f9ONA==')

LB_METRICS_URL = os.getenv('LB_METRICS_URL', 'http://192.168.2.50:8081/metrics')
COLLECTION_INTERVAL = int(os.getenv('COLLECTION_INTERVAL', '5'))  # seconds

def collect_and_push_metrics():
    """Fetch LB metrics and push to InfluxDB"""
    try:
        # Fetch metrics from LB
        response = requests.get(LB_METRICS_URL, timeout=5)
        if response.status_code != 200:
            logger.warning(f"LB metrics endpoint returned status {response.status_code}")
            return

        data = response.json()

        # Connect to InfluxDB
        client = InfluxDBClient(url=INFLUXDB_URL, token=INFLUXDB_TOKEN, org=INFLUXDB_ORG)
        write_api = client.write_api(write_options=SYNCHRONOUS)

        # Write overall LB metrics
        point = Point("lb_metrics") \
            .tag("algorithm", data.get('algorithm', 'unknown')) \
            .field("total_requests", data.get('total_requests', 0)) \
            .field("healthy_replicas", data.get('healthy_replicas', 0))

        write_api.write(bucket=INFLUXDB_BUCKET, record=point)

        # Write per-replica metrics
        replica_stats = data.get('replica_stats', {})
        for replica_id, stats in replica_stats.items():
            node = stats.get('node', 'unknown')

            point = Point("lb_replica_metrics") \
                .tag("replica_id", replica_id) \
                .tag("node", node) \
                .tag("algorithm", data.get('algorithm', 'unknown')) \
                .field("request_count", stats.get('request_count', 0)) \
                .field("active_leases", stats.get('active_leases', 0)) \
                .field("healthy", 1 if stats.get('healthy', False) else 0)

            write_api.write(bucket=INFLUXDB_BUCKET, record=point)

        logger.info(f"Pushed metrics: {data.get('total_requests', 0)} total requests, {len(replica_stats)} replicas")

        client.close()

    except requests.exceptions.RequestException as e:
        logger.warning(f"Error fetching LB metrics: {e}")
    except Exception as e:
        logger.error(f"Error pushing to InfluxDB: {e}")

def main():
    """Main loop"""
    logger.info(f"LB Metrics Collector started")
    logger.info(f"LB URL: {LB_METRICS_URL}")
    logger.info(f"InfluxDB: {INFLUXDB_URL}")
    logger.info(f"Collection interval: {COLLECTION_INTERVAL}s")

    while True:
        collect_and_push_metrics()
        time.sleep(COLLECTION_INTERVAL)

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        logger.info("LB Metrics Collector stopped")
