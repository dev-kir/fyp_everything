# Raw Outputs Directory

**🎯 PURPOSE:** Store all raw data collected from running SwarmGuard tests.

---

## Instructions

1. Run commands from `../commands_template.md`
2. Save outputs here with the specified filenames
3. Do NOT edit raw outputs - keep them exactly as produced
4. Use `../analysis_notes.md` for your interpretations

---

## Expected Files

### System Configuration
- `01_cluster_nodes.txt`
- `02_services_status.txt`
- `03_configuration.txt`

### Baseline Testing
- `04_baseline_mttr.txt`

### Scenario 1 (Migration)
- `05_scenario1_recovery_logs.txt`
- `06_scenario1_migration_timeline.txt`
- `07_scenario1_grafana.png`
- `08_scenario1_mttr_breakdown.txt`

### Scenario 2 (Scaling)
- `09_scenario2_scaling_timeline.txt`
- `10_scenario2_ab_results.txt`
- `11_scenario2_recovery_logs.txt`
- `12_scenario2_scaling_speed.txt`

### Performance Metrics
- `13_network_overhead.txt`
- `14_monitoring_agent_resources.txt`
- `15_recovery_manager_resources.txt`
- `16_alert_latency.txt`
- `17_influxdb_metrics.csv`

### Visualizations
- `18_grafana_cpu_memory.png`
- `19_grafana_alerts.png`
- `20_grafana_migration_timeline.png`
- `21_grafana_scaling_events.png`
- `22_grafana_mttr_comparison.png`

### Analysis
- `23_comparison_table.txt`
- `24_cooldown_validation.txt`
- `25_node_failure_test.txt`

---

## Notes

- Keep filenames exactly as specified for automation
- Screenshots should be high-resolution (for inclusion in thesis)
- CSV files should be comma-separated for easy parsing
- Include timestamps in all outputs where possible

---

**This directory will be used by Claude Chat when writing Chapter 4.**
