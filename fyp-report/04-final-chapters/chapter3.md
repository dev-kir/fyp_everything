# Chapter 3: Methodology

**Status:** 🚧 To be written in Claude Chat

**Target Length:** 20-25 pages

---

## Instructions for Claude Chat

### Input Context Required:
1. Read `../00-project-context/technical_summary.md` (architecture details)
2. Read root directory:
   - `FYP_2_SYSTEM_ARCHITECTURE_AND_DESIGN.txt`
   - `FYP_3_IMPLEMENTATION_DETAILS_AND_METHODOLOGY.txt`

### Research Citations Required:
- See `../01-research-requirements/papers_needed_ch3.md`
- Use Deep Research to find 10-15 papers justifying design decisions

### Output:
Write Chapter 3 in this file using academic style (IEEE format)

---

## Chapter 3 Structure

### 3.1 Introduction (0.5-1 page)
- Overview of methodology approach
- Design science research framework (cite)

### 3.2 Research Methodology Framework (1-2 pages)
- Design science research (cite framework)
- Iterative development approach (28 attempts)
- Build-and-evaluate cycle

### 3.3 System Architecture Design (4-5 pages)

#### 3.3.1 Overall Architecture
- High-level system diagram
- Component interactions
- Data flow

#### 3.3.2 Event-Driven Architecture
- Why event-driven vs polling (cite)
- Alert propagation mechanism
- Latency optimization

#### 3.3.3 Centralized vs Distributed Decision-Making
- Trade-offs (cite)
- Justification for centralized Recovery Manager
- Acknowledgment of SPOF

#### 3.3.4 Monitoring Architecture
- Agent-based monitoring (cite)
- Push vs pull model justification (cite)
- Network optimization strategy

### 3.4 Component Design (5-6 pages)

#### 3.4.1 Monitoring Agent
- Docker Stats API integration (cite technical docs)
- Metrics collection (CPU, memory, network)
- Threshold detection logic
- Implementation in Go (justification)

#### 3.4.2 Recovery Manager
- Alert receiver
- Rule-based decision engine
- Docker Swarm API client
- Implementation in Python (justification)

#### 3.4.3 Observability Stack
- InfluxDB for time-series storage (cite, justify choice)
- Grafana for visualization
- Batched metrics vs real-time alerts

### 3.5 Rule-Based Decision Engine (3-4 pages)

#### 3.5.1 Scenario Classification Algorithm
```
Algorithm 1: Scenario Classification
Input: cpu_percent, memory_percent, network_mbps
Output: recovery_scenario

1: resource_violation ← (cpu_percent > 70) OR (memory_percent > 70)
2: if NOT resource_violation then
3:     return NO_ACTION
4: end if
5: high_network ← (network_mbps >= 10)
6: if resource_violation AND NOT high_network then
7:     return SCENARIO_1_MIGRATION
8: else if resource_violation AND high_network then
9:     return SCENARIO_2_SCALING
10: end if
```

- Justification for rule-based approach (cite ML comparison)
- Threshold selection rationale
- OR-logic for CPU/Memory (cite)

#### 3.5.2 Cooldown Management
- Flapping prevention (cite control systems)
- Migration cooldown: 60s
- Scale-down cooldown: 180s
- Consecutive breach requirement: 2

### 3.6 Zero-Downtime Migration Technique (3-4 pages)

#### 3.6.1 Docker Swarm Rolling Update Mechanism
- Cite Docker documentation
- Update configuration: start-first ordering
- Placement constraints

#### 3.6.2 Migration Algorithm
```
Algorithm 2: Zero-Downtime Migration
Input: container_id, service_name
Output: migration_success

1: current_node ← get_node(container_id)
2: available_nodes ← get_cluster_nodes() - current_node
3: target_node ← select_healthy_node(available_nodes)
4: constraint ← "node.hostname==" + target_node
5: docker_service_update(service_name, constraint, force=True)
6: wait_for_new_container_healthy()
7: return migration_time
```

- Connection draining (cite)
- Health check verification
- Constraint-based placement

### 3.7 Auto-Scaling Implementation (2-3 pages)

#### 3.7.1 Scale-Up Strategy
- Incremental scaling (one replica at a time)
- No cooldown for scale-up (justification)

#### 3.7.2 Scale-Down Strategy
- 180-second cooldown (cite hysteresis)
- Idle detection threshold
- Gradual scale-down

### 3.8 Testing Methodology (4-5 pages)

#### 3.8.1 Experimental Setup
- 5-node Docker Swarm cluster (physical hardware)
- Network constraints (100Mbps legacy switches)
- Monitoring infrastructure (Raspberry Pi)

#### 3.8.2 Load Testing Infrastructure
- 4 Raspberry Pi 1.2B+ load generators (distributed)
- Apache Bench tool (cite)
- Test scenarios designed

#### 3.8.3 Performance Metrics Defined
- MTTR (cite standard definition)
- Alert latency (measurement method)
- Resource overhead (CPU, memory, network)
- Downtime (zero-downtime criterion)

#### 3.8.4 Baseline Measurement
- Docker Swarm reactive recovery baseline
- Controlled experiments (A/B testing approach)

#### 3.8.5 Validation Procedures
- Scenario 1 testing (CPU stress, low network)
- Scenario 2 testing (high concurrent load)
- Cooldown validation
- Edge cases (node failure)

### 3.9 Implementation Challenges and Solutions (2-3 pages)

#### 3.9.1 Zero-Downtime Migration Challenge (Attempts 10-17)
- Problem: How to migrate without downtime?
- Failed approaches: [briefly mention]
- Solution: Docker Swarm rolling updates with start-first

#### 3.9.2 Network Optimization Challenge (Attempts 18-22)
- Problem: Metrics saturating 100Mbps network
- Solution: Event-driven alerts + batched observability

#### 3.9.3 False Positive Prevention
- Problem: Single spikes causing unnecessary recovery
- Solution: Consecutive breach requirement (2 breaches)

### 3.10 Summary (0.5 page)
- Recap of methodology
- Justification of approach
- Transition to results (Chapter 4)

---

## Figures and Diagrams to Include

1. **Figure 3.1:** Overall System Architecture Diagram
2. **Figure 3.2:** Data Flow Diagram (Normal Operation)
3. **Figure 3.3:** Data Flow Diagram (Scenario 1 - Migration)
4. **Figure 3.4:** Data Flow Diagram (Scenario 2 - Scaling)
5. **Figure 3.5:** Monitoring Agent Component Diagram
6. **Figure 3.6:** Recovery Manager Component Diagram
7. **Figure 3.7:** Scenario Classification Flowchart
8. **Figure 3.8:** Migration Algorithm Flowchart
9. **Figure 3.9:** Experimental Setup (Hardware Topology)

**Note:** Create these diagrams using draw.io, Lucidchart, or similar tools
Save to `../02-latex-figures/` directory

---

## Algorithms to Include (Pseudocode)

1. **Algorithm 1:** Scenario Classification
2. **Algorithm 2:** Zero-Downtime Migration
3. **Algorithm 3:** Cooldown Check
4. **Algorithm 4:** Auto-Scaling Decision

**Format:** Use algorithm environment in LaTeX or structured pseudocode in markdown

---

## Technology Stack Citations

Make sure to cite:
- Docker / Docker Swarm (official docs)
- InfluxDB (technical docs or whitepaper)
- Grafana (docs)
- Go programming language
- Python Docker SDK
- Apache Bench (ab tool)

---

## Design Decision Justification Checklist

For each major design decision, provide:
1. **What** - The decision made
2. **Why** - Justification (cite supporting literature)
3. **Alternatives** - What else you considered
4. **Trade-offs** - Acknowledged limitations

Example:
> "The monitoring agent was implemented in Go [cite] due to its lightweight concurrency model and low memory footprint [cite performance comparison]. While Python was considered for consistency with the Recovery Manager, Go's superior performance for I/O-bound tasks [cite] made it the preferred choice for per-node agents."

---

## Academic Writing Guidelines

- Use **passive voice** for scientific descriptions
- Define technical terms before using them
- Justify every design choice with either:
  - Citation to literature
  - Empirical evidence from your testing
  - Logical reasoning based on requirements
- Use figures and algorithms to clarify complex concepts
- Transitions between sections should be smooth

---

## Integration with Other Chapters

- **Chapter 2** reviewed monitoring approaches → **Chapter 3** justifies InfluxDB choice
- **Chapter 2** reviewed recovery mechanisms → **Chapter 3** implements proactive recovery
- **Chapter 3** defines testing methodology → **Chapter 4** presents results

Every design decision should reference Chapter 2 literature.

---

**Write this chapter using Claude Chat, then paste the final version here.**

**Important:** Include actual code snippets sparingly - use pseudocode/algorithms instead.
Full code belongs in appendices, not methodology chapter.
