# Chapter 2: Literature Review

**Status:** 🚧 To be written in Claude Chat

**Target Length:** 15-20 pages

---

## Instructions for Claude Chat

### Input Context Required:
1. Read `../00-project-context/project_overview.md` (to understand what you're reviewing lit for)
2. Read root directory: `FYP_5_ACADEMIC_CHAPTER_MAPPING.txt` (Chapter 2 structure guide)

### Research Required:
- **CRITICAL:** See `../01-research-requirements/papers_needed_ch2.md`
- Use Deep Research to find 25-35 academic papers
- Organize findings by sections 2.1 - 2.7

### Output:
Write Chapter 2 in this file using academic style (IEEE format)

---

## Chapter 2 Structure

### 2.1 Container Orchestration Fundamentals (3-4 pages)
- Docker Swarm architecture and design
- Kubernetes and alternative orchestrators
- Service discovery, load balancing, rolling updates
- **Citations needed:** 5-7 papers

### 2.2 Failure Detection and Recovery (4-5 pages)
- Reactive recovery mechanisms (health checks, restarts)
- Proactive and predictive recovery approaches
- Autonomic computing and self-healing systems (MAPE-K loop)
- **Citations needed:** 9-11 papers

### 2.3 Monitoring and Metrics Collection (3-4 pages)
- Time-series databases (InfluxDB, Prometheus)
- Container metrics and resource monitoring (cgroups, Docker stats API)
- Push vs pull monitoring models
- **Citations needed:** 5-7 papers

### 2.4 Threshold-Based Anomaly Detection (2-3 pages)
- Rule-based vs ML-based detection
- When to use rules vs machine learning
- False positive/negative trade-offs
- **Citations needed:** 3-4 papers

### 2.5 Zero-Downtime Deployment Strategies (2-3 pages)
- Rolling updates, blue-green deployment, canary releases
- Connection draining and graceful shutdown
- **Citations needed:** 3-4 papers

### 2.6 Auto-Scaling and Resource Management (2-3 pages)
- Horizontal and vertical scaling
- Threshold-based vs predictive scaling
- Cooldown periods and flapping prevention
- **Citations needed:** 3-4 papers

### 2.7 Related Work and Similar Systems (3-4 pages)
**CRITICAL SECTION**
- Existing proactive recovery systems
- Academic research prototypes
- Industry solutions
- **Comparison table:** How SwarmGuard differs from existing work
- **Citations needed:** 4-5 papers

### 2.8 Summary and Research Gap (1 page)
- What literature covers
- What's missing (your gap)
- How your work fills the gap

---

## Literature Review Template (for each section)

For each major topic:

1. **Define the concept** (with citations)
   - What is it?
   - Why is it important?

2. **State of the art** (with citations)
   - What's the current best approach?
   - What do leading researchers/companies do?

3. **Limitations** (with citations)
   - What's missing or inadequate?
   - What challenges remain?

4. **Connection to SwarmGuard**
   - How does your work address these limitations?
   - How does your work build on existing research?

---

## Critical Section: 2.7 Related Work

This section must include a **comparison table** like this:

| System/Research | Approach | Platform | Zero-Downtime? | Context-Aware? | Limitations | SwarmGuard Difference |
|-----------------|----------|----------|----------------|----------------|-------------|----------------------|
| Docker Swarm Native | Reactive | Swarm | No | No | 10-15s MTTR, downtime | Proactive, 6.08s MTTR |
| Kubernetes HPA | Reactive | K8s | Partial | No | Metrics-based only | Scenario-aware |
| [Research System A] | Proactive ML | K8s | Yes | Yes | Complex, overhead | Rule-based, simple |
| ... | ... | ... | ... | ... | ... | ... |

---

## Academic Writing Guidelines

- **Do NOT just summarize papers** - synthesize and connect them
- Group papers by theme, not one-by-one
- Show how papers relate to each other
- Connect every section to YOUR research question
- Use transitions between sections
- Critical analysis, not just description

**Example of BAD literature review:**
> "Paper A discusses Docker Swarm. Paper B discusses monitoring. Paper C discusses auto-scaling."

**Example of GOOD literature review:**
> "Container orchestration platforms employ various failure recovery strategies. Docker Swarm utilizes reactive health checks [A], while recent research has explored proactive approaches using machine learning [B,C]. However, these ML-based methods introduce significant computational overhead [D], suggesting that rule-based approaches may be more suitable for resource-constrained environments, as demonstrated by SwarmGuard."

---

## Citation Management

- Use IEEE citation style: [1], [2], etc.
- Citations go **before** the period: "...as shown in [5]."
- Multiple citations: [1], [3], [7] or [1-3]
- Keep bibliography in `../05-references/references.bib`

---

## Integration with Other Chapters

- **Chapter 1** identified the problem → **Chapter 2** reviews existing solutions
- **Chapter 2** reviews approaches → **Chapter 3** justifies your design choices
- **Chapter 2** identifies gaps → **Chapter 4** shows you filled them

Every design decision in Chapter 3 should be supported by literature in Chapter 2.

---

**Write this chapter using Claude Chat with Deep Research, then paste the final version here.**

**Estimated time:** This is the most research-intensive chapter. Budget significant time for Deep Research.
