# Chapter 4: Results and Discussion

**Status:** 🚧 To be written in Claude Code (after evidence collection)

**Target Length:** 20-25 pages

---

## Instructions

### Phase 1: Evidence Collection (YOU do this)
1. Run commands from `../03-chapter4-evidence/commands_template.md`
2. Save all outputs to `../03-chapter4-evidence/raw_outputs/`
3. Fill in `../03-chapter4-evidence/analysis_notes.md`

### Phase 2: Initial Draft (Claude Code)
1. Claude Code reads raw outputs
2. Generates tables, calculates statistics
3. Creates initial draft of results section

### Phase 3: Final Writing (Claude Chat)
1. Claude Chat refines academic language
2. Adds discussion and interpretation
3. Connects to literature (Chapter 2)
4. Polishes final version

### Input Required:
- All files from `../03-chapter4-evidence/raw_outputs/`
- Analysis notes
- Root directory: `FYP_4_RESULTS_AND_FINDINGS.txt`

---

## Chapter 4 Structure

### 4.1 Introduction (0.5-1 page)
- Overview of experimental validation
- Summary of test scenarios
- Performance metrics evaluated

### 4.2 Experimental Setup (Recap from Chapter 3)  (1-2 pages)
- Brief recap of methodology
- Hardware configuration
- Test scenarios

### 4.3 Baseline Performance (Docker Swarm Reactive) (2-3 pages)

#### 4.3.1 Reactive Recovery MTTR
- **Table 4.1:** Baseline MTTR measurements
- Average: [X] seconds (from raw_outputs/04_baseline_mttr.txt)
- Discussion: typical reactive recovery behavior

#### 4.3.2 Downtime Characteristics
- Failed requests during recovery
- User-visible impact

---

### 4.4 Scenario 1: Proactive Migration Results (5-6 pages)

#### 4.4.1 Migration MTTR Performance
- **Table 4.2:** Scenario 1 MTTR results (multiple runs)
- **Average MTTR:** [X] seconds (from raw_outputs/08_scenario1_mttr_breakdown.txt)
- **Standard deviation:** [Y] seconds
- **Min/Max:** [Z] / [W] seconds

#### 4.4.2 MTTR Breakdown Analysis
- **Figure 4.1:** Latency breakdown (detection, transmission, action, execution)
- Alert latency: [X] ms (from raw_outputs/16_alert_latency.txt)
- Migration execution: [Y] seconds

#### 4.4.3 Zero-Downtime Validation
- **Result:** [X] seconds downtime (target: 0 seconds)
- Failed requests: [N] (target: 0)
- **Success:** ✅ / ❌

#### 4.4.4 Migration Timeline Visualization
- **Figure 4.2:** Grafana screenshot showing migration event
- **Figure 4.3:** Container lifecycle during migration

#### 4.4.5 Discussion: Why Migration Works
- Start-first ordering prevents downtime
- Rolling update ensures seamless transition
- Connection draining handled gracefully

---

### 4.5 Scenario 2: Auto-Scaling Results (4-5 pages)

#### 4.5.1 Scale-Up Performance
- **Table 4.3:** Scale-up speed measurements
- **Average scale-up time:** [X] seconds (from raw_outputs/12_scenario2_scaling_speed.txt)
- **Replica count progression:** [initial] → [peak]

#### 4.5.2 Scale-Down Behavior
- **Cooldown validation:** 180 seconds observed? [Y/N]
- **Scale-down time:** [X] seconds
- **Final replica count:** [N]

#### 4.5.3 Load Test Results
- **Figure 4.4:** Replica count over time during load test
- **Table 4.4:** Apache Bench results (from raw_outputs/10_scenario2_ab_results.txt)
  - Total requests: [N]
  - Failed requests: [M]
  - Requests per second: [X]

#### 4.5.4 Discussion: Scaling Effectiveness
- Did scaling prevent service degradation?
- Response time impact
- Resource utilization improvement

---

### 4.6 Resource Overhead Analysis (3-4 pages)

#### 4.6.1 Monitoring Agent Overhead
- **Table 4.5:** Monitoring agent resource usage
- CPU: [X]% (from raw_outputs/14_monitoring_agent_resources.txt)
- Memory: [Y] MB
- Network: [Z] Mbps (from raw_outputs/13_network_overhead.txt)

**Comparison to target:**
- CPU target: < 5% → Actual: [X]% → ✅ / ❌
- Memory target: < 100MB → Actual: [Y] MB → ✅ / ❌
- Network target: < 1 Mbps → Actual: [Z] Mbps → ✅ / ❌

#### 4.6.2 Recovery Manager Overhead
- **Table 4.6:** Recovery manager resource usage
- CPU: [X]%
- Memory: [Y] MB

#### 4.6.3 Discussion: Overhead Acceptability
- Is [X]% CPU overhead acceptable for [Y]% MTTR improvement?
- Trade-off analysis

---

### 4.7 Alert Latency Performance (2-3 pages)

#### 4.7.1 End-to-End Latency Results
- **Figure 4.5:** Alert latency breakdown chart
- **Table 4.7:** Latency components
  - Detection: [X] ms
  - Transmission: [Y] ms
  - Decision: [Z] ms
  - **Total:** [T] ms (from raw_outputs/16_alert_latency.txt)

#### 4.7.2 Discussion: Sub-Second Achievement
- Target: < 1 second → Actual: [X] ms → ✅
- Event-driven architecture benefit
- Comparison to polling-based systems (cite)

---

### 4.8 Comparative Analysis (3-4 pages)

#### 4.8.1 Reactive vs Proactive Comparison
**Table 4.8:** Comprehensive comparison (from raw_outputs/23_comparison_table.txt)

| Metric | Docker Swarm (Reactive) | SwarmGuard (Proactive) | Improvement |
|--------|-------------------------|------------------------|-------------|
| MTTR | [X]s | [Y]s | [Z]% faster |
| Downtime | [X]s | [Y]s | [Z]% reduction |
| Alert Latency | N/A | [X]ms | Sub-second |
| Scale-up Speed | N/A | [X]s | Automatic |
| Network Overhead | 0 | [X] Mbps | [Y]% |
| CPU Overhead | 0 | [X]% | [Y]% |

**Figure 4.6:** Bar chart comparing MTTR (Reactive vs Proactive)

#### 4.8.2 Objectives Achievement Summary
**Table 4.9:** Objectives vs Results

| Objective | Target | Result | Status |
|-----------|--------|--------|--------|
| Migration MTTR | < 10s | [X]s | ✅ / ❌ |
| Alert Latency | < 1s | [X]ms | ✅ / ❌ |
| Zero Downtime | 0s | [X]s | ✅ / ❌ |
| Network Overhead | < 1 Mbps | [X] Mbps | ✅ / ❌ |
| CPU Overhead | < 5% | [X]% | ✅ / ❌ |
| Memory Overhead | < 100MB | [X] MB | ✅ / ❌ |

---

### 4.9 Additional Findings (2-3 pages)

#### 4.9.1 Cooldown Effectiveness
- **From:** raw_outputs/24_cooldown_validation.txt
- Flapping prevented? [Y/N]
- Cooldown periods appropriate? [Y/N]

#### 4.9.2 Edge Cases and Resilience
- **From:** raw_outputs/25_node_failure_test.txt
- Behavior during node failure
- Recovery manager resilience

#### 4.9.3 Unexpected Observations
- [Any surprising findings]
- [Anomalies or interesting patterns]

---

### 4.10 Limitations Observed (2-3 pages)

#### 4.10.1 Single Point of Failure (Recovery Manager)
- Acknowledged limitation
- Impact on production readiness
- Mitigation: Future work (HA recovery manager)

#### 4.10.2 Manual Threshold Configuration
- Static thresholds require tuning
- Workload-specific adjustments needed
- Future work: Adaptive thresholds

#### 4.10.3 Docker Swarm Platform Dependency
- Not portable to Kubernetes
- Swarm-specific API usage

#### 4.10.4 Single-Cluster Limitation
- No multi-cluster support
- Scale limitations

#### 4.10.5 Network Constraint Dependency
- Results validated on 100Mbps network
- Higher bandwidth may show different characteristics

#### 4.10.6 Test Environment Scale
- 5-node cluster, limited concurrent containers
- Production scale validation needed

---

### 4.11 Discussion (3-4 pages)

#### 4.11.1 Interpretation of Results
- Why did proactive recovery achieve 55% faster MTTR?
- What factors contributed to zero-downtime?
- Significance of sub-second alert latency

#### 4.11.2 Comparison to Related Work
- How do these results compare to literature? (reference Chapter 2)
- SwarmGuard vs similar systems
- Novel contributions validated

#### 4.11.3 Implications for Research Question
- RQ1: Can proactive monitoring detect failures early? → **Answered**
- RQ2: Can context-aware strategies differentiate scenarios? → **Answered**
- RQ3: Is zero-downtime achievable in Swarm? → **Answered**

#### 4.11.4 Practical Applicability
- Suitable for production use? (with caveats)
- SME adoption feasibility
- Cost-benefit analysis

---

### 4.12 Summary (0.5-1 page)
- Key results recap
- Objectives achieved
- Transition to conclusions (Chapter 5)

---

## Figures and Tables Summary

### Tables Required:
- Table 4.1: Baseline MTTR
- Table 4.2: Scenario 1 MTTR results
- Table 4.3: Scale-up speed
- Table 4.4: Load test results
- Table 4.5: Monitoring agent overhead
- Table 4.6: Recovery manager overhead
- Table 4.7: Alert latency breakdown
- Table 4.8: Reactive vs Proactive comparison
- Table 4.9: Objectives achievement

### Figures Required:
- Figure 4.1: Latency breakdown chart
- Figure 4.2: Grafana migration screenshot
- Figure 4.3: Container lifecycle diagram
- Figure 4.4: Replica count over time
- Figure 4.5: Alert latency chart
- Figure 4.6: MTTR comparison bar chart
- Additional: Grafana dashboards (18-22 from raw_outputs)

**All figures saved to:** `../02-latex-figures/chapter4/`

---

## Data Visualization Guidelines

- Use bar charts for comparisons (Reactive vs Proactive)
- Use line graphs for time-series (replica count, network traffic)
- Use pie charts sparingly (only for proportions that matter)
- Use tables for exact numbers
- Use screenshots for Grafana (real system evidence)

**Tools:**
- Matplotlib/Seaborn (Python) for graphs
- Excel/Google Sheets for quick charts
- Grafana export for dashboards
- Draw.io for diagrams

---

## Academic Writing Guidelines

### Results Section (4.3-4.8):
- **Objective, factual reporting**
- Present data without interpretation
- Use tables and figures extensively
- State what you observed, not why

**Example:**
> "SwarmGuard achieved an average MTTR of 6.08 seconds across 10 test runs, with a standard deviation of 0.42 seconds (Table 4.2). This represents a 55% improvement over the Docker Swarm baseline of 13.5 seconds."

### Discussion Section (4.11):
- **Interpretation and analysis**
- Explain why results occurred
- Connect to literature (Chapter 2)
- Discuss implications

**Example:**
> "The 55% MTTR improvement can be attributed to proactive detection and event-driven alerts, which eliminate the delay inherent in reactive health check polling. This aligns with findings from [citation] that event-driven architectures achieve significantly lower latency than polling-based approaches."

---

## Integration with Other Chapters

- **Chapter 3** defined methodology → **Chapter 4** presents results
- **Chapter 2** reviewed literature → **Chapter 4** compares to literature
- **Chapter 1** stated objectives → **Chapter 4** shows achievement
- **Chapter 4** shows limitations → **Chapter 5** proposes future work

---

**Write this chapter in THREE phases:**
1. **Evidence collection** (you run commands)
2. **Initial draft** (Claude Code processes data)
3. **Final polish** (Claude Chat academic writing)
