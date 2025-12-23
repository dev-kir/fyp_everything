# SwarmGuard - Project Overview for Claude Chat

**🎯 PURPOSE:** This document provides context for Claude Chat to understand your FYP project when writing research-heavy chapters (1, 2, 3, 5).

---

## Project Title

**Design and Implementation of a Rule-Based Proactive Recovery Mechanism for Containerized Applications Using Docker Swarm**

**System Name:** SwarmGuard

---

## The Core Problem

Docker Swarm (and most container orchestrators) use **reactive failure recovery**:
1. Wait for container to completely fail
2. Detect the failure (health check timeout)
3. Kill the failed container
4. Start a replacement
5. Result: **10-30 seconds of downtime**

This reactive approach causes:
- Service unavailability during recovery
- Failed user requests
- Poor user experience
- SLA violations

---

## The Solution: Proactive Recovery

SwarmGuard monitors containers in real-time and takes **preventive action BEFORE complete failure**:

### Two Intelligent Recovery Scenarios:

**Scenario 1: Container/Node Problem → Migration**
- **Detection:** High CPU/Memory + Low Network
- **Interpretation:** The container or underlying node has a problem
- **Action:** Migrate container to a different healthy node (zero-downtime)
- **Result:** Problem isolated, service continues on healthy infrastructure

**Scenario 2: High Traffic → Horizontal Scaling**
- **Detection:** High CPU/Memory + High Network
- **Interpretation:** Legitimate traffic surge requiring more capacity
- **Action:** Scale up replicas incrementally, auto-scale down when idle
- **Result:** Load distributed, service remains responsive

---

## Key Achievements

### Performance Results:
- **Migration MTTR:** 6.08 seconds (55% faster than Docker Swarm's 10-15s)
- **Zero downtime:** 0-3 seconds maximum service interruption
- **Alert latency:** 7-9 milliseconds (sub-second detection)
- **Network overhead:** < 0.5 Mbps (optimized for 100Mbps legacy networks)
- **Monitoring overhead:** < 5% CPU, < 100MB RAM per node

### Technical Innovation:
1. **Event-driven architecture** (sub-second alert propagation)
2. **Zero-downtime migration** using Docker Swarm's rolling update mechanism
3. **Context-aware recovery** (different strategies for different failure types)
4. **Network-optimized** for resource-constrained environments

---

## System Architecture (High-Level)

```
[Monitoring Agent] (each worker node)
    ↓ Collects CPU/Memory/Network metrics
    ↓ Detects threshold violations
    ↓
[Recovery Manager] (central decision engine)
    ↓ Analyzes metrics + network state
    ↓ Determines recovery scenario
    ↓ Executes recovery action
    ↓
[Docker Swarm] (orchestrator)
    ↓ Performs migration or scaling
    ↓
[InfluxDB + Grafana] (observability)
```

**Key Components:**
1. **Monitoring Agent (Go):** Runs on each worker node, collects real-time metrics
2. **Recovery Manager (Python):** Central brain, makes recovery decisions
3. **Test Application (Node.js):** Controllable web app for testing scenarios
4. **Observability Stack:** InfluxDB for metrics, Grafana for visualization

---

## Testing Infrastructure

- **5-node Docker Swarm cluster:**
  - 1 master node (odin)
  - 4 worker nodes (thor, loki, heimdall, freya)

- **Monitoring infrastructure:**
  - Raspberry Pi running InfluxDB + Grafana

- **Distributed load testing:**
  - 4 Raspberry Pi 1.2B+ nodes (Alpine Linux)
  - Simulates realistic traffic patterns from different network locations

---

## Technology Stack

- **Container Orchestration:** Docker Swarm
- **Monitoring Agent:** Go (lightweight, concurrent)
- **Recovery Manager:** Python (Docker SDK, Flask API)
- **Test Application:** Node.js (Express)
- **Metrics Storage:** InfluxDB (time-series database)
- **Visualization:** Grafana
- **Load Testing:** Apache Bench (ab), custom bash scripts

---

## Development Journey

- **28 iterative attempts** over development period
- **Key milestones:**
  - Attempts 1-9: Architecture exploration (Redis vs InfluxDB, polling vs events)
  - Attempts 10-17: Zero-downtime migration challenge (constraint-based placement)
  - Attempts 18-28: Network optimization, scenario refinement, validation

---

## Research Context

### Academic Contributions:
1. Empirical evidence of proactive vs reactive recovery benefits
2. Practical implementation of zero-downtime migration in Docker Swarm
3. Rule-based decision engine for context-aware recovery
4. Performance benchmarks for distributed systems research

### Industrial Relevance:
1. Practical solution for SMEs using Docker Swarm (Kubernetes alternative)
2. Low-complexity implementation (minimal DevOps overhead)
3. Cost-effective (runs on existing infrastructure)
4. Real-world validated (physical hardware, realistic network constraints)

---

## Scope and Boundaries

### ✅ In Scope:
- Proactive monitoring (CPU, memory, network)
- Two recovery scenarios (migration, scaling)
- Docker Swarm environment
- Zero-downtime recovery
- Performance validation

### ❌ Out of Scope:
- Machine learning / AI-based predictions
- Kubernetes or other orchestrators
- Multi-cluster / multi-cloud deployments
- Production-grade HA for SwarmGuard itself
- Security mechanisms (authentication, authorization)

---

## Key Files in Actual Codebase

- **`FYP_1_PROJECT_OVERVIEW_AND_BACKGROUND.txt`** - Detailed problem statement
- **`FYP_2_SYSTEM_ARCHITECTURE_AND_DESIGN.txt`** - Architecture deep-dive
- **`FYP_3_IMPLEMENTATION_DETAILS_AND_METHODOLOGY.txt`** - Implementation journey
- **`FYP_4_RESULTS_AND_FINDINGS.txt`** - Performance results and analysis
- **`FYP_5_ACADEMIC_CHAPTER_MAPPING.txt`** - Guide for writing academic chapters

- **Code:**
  - `swarmguard/monitoring-agent/` - Go monitoring agent
  - `swarmguard/recovery-manager/` - Python recovery manager
  - `swarmguard/web-stress/` - Node.js test application
  - `swarmguard/tests/` - Load testing scripts

---

## When Using This Context in Claude Chat

**For Chapter 1 (Introduction):**
- Use the problem statement and motivation sections
- Reference the research gap analysis
- Cite the performance achievements as objectives met

**For Chapter 2 (Literature Review):**
- Research topics: container orchestration, proactive recovery, self-healing systems
- Compare SwarmGuard's approach to existing solutions
- Position work relative to Docker Swarm, Kubernetes alternatives

**For Chapter 3 (Methodology):**
- Focus on architecture design decisions
- Explain the rule-based decision engine
- Document the testing methodology

**For Chapter 5 (Conclusions):**
- Summarize contributions and achievements
- Discuss limitations honestly
- Propose future work (see FYP_5 for specific directions)

---

## Quick Reference: Key Metrics

| Metric | Target | Achieved | Notes |
|--------|--------|----------|-------|
| Migration MTTR | < 10s | 6.08s | 55% improvement over baseline |
| Alert Latency | < 1s | 7-9ms | Sub-second detection |
| Downtime | 0s | 0-3s | Zero-downtime achieved |
| Network Overhead | < 1 Mbps | < 0.5 Mbps | Optimized for 100Mbps |
| Monitoring CPU | < 5% | ~3% | Minimal overhead |
| Monitoring RAM | < 100MB | ~50MB | Lightweight agents |

---

**Last Updated:** Based on actual implementation as of December 2024
