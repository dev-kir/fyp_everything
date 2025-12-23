# Chapter 3: Methodology - Research Requirements

**🎯 For use with Claude Chat Deep Research**

---

## Overview

Chapter 3 is **20-25 pages** covering your methodology (design + implementation). Most content comes from your actual work (FYP_2, FYP_3), but you need citations to:
1. Justify design decisions
2. Reference methodologies you followed
3. Cite tools and frameworks used

**Target:** 10-15 papers for Chapter 3

---

## Section 3.1: Research Methodology Framework (1-2 pages)

### Topic: Design Science Research / Systems Research

**What to find:**
- Design science research methodology
- Build-and-evaluate research approach
- Iterative development methodologies
- Systems research frameworks

**Why needed:**
- Justify your iterative development (28 attempts)
- Frame your work as "design science" (build + evaluate)
- Academic legitimacy for implementation-focused research

**Suggested sources:**
- Hevner et al. "Design Science in Information Systems Research"
- Systems research methodology papers
- Software engineering research methodologies

**Target papers:** 2-3 papers

**How this will be used:**
```
"This research follows a design science methodology [X], involving
iterative design, implementation, and evaluation cycles. The system
was developed through 28 iterative attempts, refining the architecture
based on experimental results."
```

---

## Section 3.2: System Architecture Design (3-4 pages)

### Topic 3.2.1: Event-Driven Architecture

**What to find:**
- Event-driven architecture patterns
- Event-driven microservices
- Publish-subscribe vs request-response
- Benefits of event-driven systems (low latency)

**Why needed:**
- Justify your choice of event-driven alerts over polling
- Support claim that event-driven reduces latency

**Target papers:** 2-3 papers

---

### Topic 3.2.2: Centralized vs Distributed Decision-Making

**What to find:**
- Centralized vs distributed control in systems
- Master-slave vs peer-to-peer architectures
- Trade-offs: single point of failure vs complexity

**Why needed:**
- Justify centralized Recovery Manager design
- Acknowledge SPOF trade-off

**Target papers:** 1-2 papers

---

### Topic 3.2.3: Monitoring Architecture Patterns

**What to find:**
- Push vs pull monitoring models
- Agent-based monitoring architectures
- Monitoring overhead reduction techniques

**Why needed:**
- Justify monitoring agent on each node
- Support batched metrics approach

**Target papers:** 2-3 papers

---

## Section 3.3: Rule-Based Decision Engine (2-3 pages)

### Topic 3.3.1: Rule-Based Systems

**What to find:**
- Rule-based expert systems
- Threshold-based decision making
- When to use rules vs machine learning

**Why needed:**
- Justify NOT using ML (complexity, overhead, interpretability)
- Support rule-based approach for simple scenarios

**Target papers:** 2-3 papers

**Key argument:**
```
"For well-defined scenarios with clear thresholds, rule-based systems
offer simplicity, interpretability, and low overhead compared to
machine learning approaches [citation]."
```

---

### Topic 3.3.2: Cooldown and Hysteresis in Control Systems

**What to find:**
- Cooldown periods in auto-scaling systems
- Hysteresis in control theory
- Flapping prevention in distributed systems

**Why needed:**
- Justify 60s migration cooldown, 180s scale-down cooldown
- Support consecutive breach requirement (2 breaches)

**Target papers:** 1-2 papers

---

## Section 3.4: Zero-Downtime Migration Technique (3-4 pages)

### Topic 3.4.1: Docker Swarm Rolling Updates

**What to find:**
- Docker Swarm rolling update mechanism
- Docker service update configurations
- Placement constraints in Docker Swarm

**Why needed:**
- Cite official documentation for rolling updates
- Explain how you leveraged existing Swarm features

**Suggested sources:**
- Docker official documentation
- Docker Swarm internals papers/blogs
- DockerCon presentations

**Target papers:** 1-2 official docs + 1-2 technical blogs/papers

---

### Topic 3.4.2: Start-First vs Stop-First Update Ordering

**What to find:**
- Update ordering strategies in orchestration
- Blue-green deployment patterns
- Connection draining in load balancers

**Why needed:**
- Justify `update_config.order: start-first`
- Explain how this achieves zero downtime

**Target papers:** 1-2 papers

---

## Section 3.5: Monitoring Implementation (2-3 pages)

### Topic 3.5.1: Docker Stats API and cgroups

**What to find:**
- Docker stats API documentation
- Linux cgroups for resource monitoring
- Container resource isolation mechanisms

**Why needed:**
- Technical foundation for metrics collection
- Explain what you're monitoring and how

**Suggested sources:**
- Docker API documentation
- Linux kernel cgroups documentation
- Container internals papers

**Target papers:** 1-2 technical references

---

### Topic 3.5.2: InfluxDB and Time-Series Storage

**What to find:**
- InfluxDB architecture and design
- Time-series database performance
- Write optimization for time-series data

**Why needed:**
- Justify InfluxDB choice over alternatives
- Explain batching strategy (10-second intervals)

**Target papers:** 1-2 papers/whitepapers

---

## Section 3.6: Testing Methodology (3-4 pages)

### Topic 3.6.1: Load Testing and Benchmarking

**What to find:**
- Load testing methodologies for web services
- Apache Bench (ab) tool usage
- Distributed load testing approaches

**Why needed:**
- Justify your testing approach
- Cite ab tool as standard benchmarking tool

**Target papers:** 1-2 papers on load testing

---

### Topic 3.6.2: Controlled Experiments and Validation

**What to find:**
- Experimental design for systems research
- A/B testing in distributed systems
- Performance benchmarking methodologies

**Why needed:**
- Frame your testing as rigorous experimental validation
- Justify comparison with baseline (Docker Swarm reactive)

**Target papers:** 1-2 papers on experimental methodology

---

## Section 3.7: Performance Metrics and Measurement (2-3 pages)

### Topic 3.7.1: MTTR, MTTD, and Availability Metrics

**What to find:**
- Mean Time To Detect (MTTD)
- Mean Time To Recover (MTTR)
- System availability calculations
- Service reliability metrics

**Why needed:**
- Cite standard definitions of metrics you measured
- Academic credibility for performance claims

**Target papers:** 1-2 papers on reliability metrics

**Example usage:**
```
"Mean Time To Recover (MTTR) is defined as the average time required
to restore service after a failure [citation]. SwarmGuard achieved an
MTTR of 6.08 seconds compared to Docker Swarm's baseline of 10-15 seconds."
```

---

### Topic 3.7.2: Latency Measurement in Distributed Systems

**What to find:**
- Latency measurement techniques
- End-to-end latency breakdown
- Clock synchronization in distributed systems

**Why needed:**
- Justify your latency measurements (7-9ms alert latency)
- Explain methodology for measuring sub-second performance

**Target papers:** 1-2 papers

---

## Technology Stack Citations

### Required Technical References:

1. **Docker and Docker Swarm**
   - Docker official documentation
   - Cite: https://docs.docker.com/engine/swarm/

2. **InfluxDB**
   - InfluxDB documentation or whitepaper
   - Cite: https://docs.influxdata.com/

3. **Grafana**
   - Grafana documentation
   - Cite: https://grafana.com/docs/

4. **Go Programming Language**
   - Go official documentation (for monitoring agent)
   - Cite: https://go.dev/doc/

5. **Python Docker SDK**
   - Docker SDK for Python documentation
   - Cite: https://docker-py.readthedocs.io/

6. **Apache Bench (ab)**
   - Apache HTTP server benchmarking tool
   - Cite: https://httpd.apache.org/docs/current/programs/ab.html

---

## Design Decision Justification Map

Each design decision needs a citation to support it:

| Design Decision | Justification Needed | Citation Type |
|----------------|---------------------|---------------|
| Event-driven alerts | Lower latency than polling | Academic paper |
| Centralized recovery manager | Simpler than distributed consensus | Architecture paper |
| Rule-based (not ML) | Simplicity, interpretability, low overhead | ML comparison paper |
| InfluxDB | Optimized for time-series data | Technical whitepaper |
| Go for agents | Low overhead, concurrency | Language comparison |
| 70% CPU threshold | Industry standard for high utilization | Best practices paper |
| 60s migration cooldown | Prevent flapping | Control systems paper |
| Start-first ordering | Zero-downtime requirement | Deployment strategy paper |

---

## Iterative Development Narrative

**Challenge:** How to present 28 attempts academically?

**Solution:** Frame as design science research with iterative refinement

**Need citation for:**
- Agile/iterative development methodologies
- Prototyping in systems research
- Value of failed experiments in research

**Search query:** "iterative development systems research design science"

**Target:** 1-2 methodological papers

---

## Search Queries for Claude Chat Deep Research

### High Priority:

1. **"design science research methodology information systems"**
   - Framework for your research approach

2. **"event-driven architecture microservices latency performance"**
   - Justify event-driven design

3. **"rule-based systems vs machine learning when to use"**
   - Justify NOT using ML

4. **"Docker Swarm rolling updates placement constraints"**
   - Technical foundation for migration

5. **"MTTR MTTD reliability metrics distributed systems"**
   - Standard definitions for your metrics

### Medium Priority:

6. **"cooldown periods auto-scaling flapping prevention"**
   - Justify cooldown design

7. **"load testing methodology web services Apache Bench"**
   - Testing approach

8. **"time-series database monitoring overhead InfluxDB"**
   - InfluxDB justification

9. **"monitoring architecture patterns push pull agent-based"**
   - Monitoring design

10. **"zero-downtime deployment blue-green rolling updates"**
    - Migration strategy

---

## Output Format for Claude Chat

For each paper found, provide:

1. **Citation** (IEEE format)
2. **Relevance** (which design decision it supports)
3. **Key quote** (if applicable - for direct use in thesis)

Example:
```
[12] M. Author et al., "Event-Driven Microservices," in Proc. IEEE Cloud, 2022.

Relevance: Supports event-driven architecture choice (Section 3.2.1)

Key quote: "Event-driven architectures achieve 10x lower latency compared
to polling-based approaches in distributed systems."

Usage: Cite when justifying direct HTTP alerts over polling InfluxDB.
```

---

## Chapter 3 Structure Reminder

Your Chapter 3 should follow this flow:

1. **Introduction** - Overview of methodology
2. **Research Methodology** - Design science framework (cite here)
3. **System Architecture** - High-level design decisions (cite here)
4. **Component Design** - Each component's design (cite here)
5. **Implementation Details** - Algorithms and code logic (cite here)
6. **Testing Methodology** - Experimental setup (cite here)
7. **Performance Metrics** - What you measured and why (cite here)

**Total estimated citations:** 10-15 papers + 5-8 technical documentation references

---

**Next Steps for Claude Chat:**
1. Use Deep Research for priority queries above
2. Find papers justifying design decisions
3. Get official documentation links for tools used
4. Return citations organized by section (3.1 - 3.7)
