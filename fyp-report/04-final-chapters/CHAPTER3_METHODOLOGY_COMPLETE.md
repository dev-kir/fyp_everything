# Chapter 3: Methodology

## 3.1 Introduction

This chapter presents the detailed methodology employed in the design, implementation, and evaluation of SwarmGuard, a proactive recovery mechanism for containerized applications in Docker Swarm environments. The methodology encompasses system architecture design, algorithm development, implementation approaches, and experimental validation procedures.

The chapter is organized as follows: Section 3.2 describes the overall system architecture and component interactions. Section 3.3 details the monitoring infrastructure that enables real-time resource observation. Section 3.4 presents the decision-making algorithms that classify failure scenarios and select appropriate recovery actions. Section 3.5 explains the migration and scaling mechanisms that execute recovery operations. Section 3.6 describes the experimental testbed configuration and validation procedures. Finally, Section 3.7 discusses the rationale behind key design decisions and trade-offs.

The implementation utilizes Python for the recovery manager and monitoring agents, leveraging Docker's native APIs for container orchestration and metrics collection. The experimental validation was conducted on a five-node Docker Swarm cluster with custom load generation infrastructure to simulate realistic failure scenarios and traffic patterns.

---

## 3.2 System Architecture

### 3.2.1 Architectural Overview

SwarmGuard follows a distributed monitoring architecture with centralized decision-making, designed to balance responsiveness with coordination requirements. The system comprises three primary components: monitoring agents deployed on each worker node, a central recovery manager on the master node, and a test application infrastructure for validation. This architecture enables sub-second alert propagation while maintaining consistent global decision-making authority.

The monitoring agents operate independently on each Docker Swarm worker node, collecting container-level resource metrics through Docker's Stats API and detecting threshold violations locally. When a threshold breach occurs, the agent immediately transmits an alert to the recovery manager via HTTP POST, achieving typical alert latency of 50-100 milliseconds. The recovery manager receives these alerts, applies scenario classification logic, enforces cooldown periods to prevent oscillation, and executes recovery actions through Docker Swarm's orchestration API.

This architectural separation ensures that monitoring overhead remains distributed and lightweight, while decision-making complexity is centralized for consistency. The event-driven alert mechanism minimizes network traffic compared to continuous metrics streaming, consuming less than 0.5% of available network bandwidth even on legacy 100 Mbps infrastructure.

**[INSERT FIGURE 3.1 HERE]**
*Figure 3.1: SwarmGuard System Architecture*
*Diagram showing: 4 worker nodes with monitoring agents, master node with recovery manager, Docker Swarm orchestration layer, InfluxDB + Grafana observability stack, and data flow arrows (metrics, alerts, API calls)*

### 3.2.2 Communication Patterns

The system employs three distinct communication patterns optimized for different requirements. First, event-driven alerts utilize asynchronous HTTP POST requests from monitoring agents to the recovery manager when threshold violations occur. This pattern prioritizes low latency, with agents maintaining persistent HTTP connections via keepalive mechanisms and implementing 2 retry attempts with 100-millisecond backoff to handle transient network issues.

Second, batched metrics employ periodic transmission of time-series data from monitoring agents to InfluxDB for historical analysis and visualization. Agents buffer metrics in memory with a batch size of 20 data points or 10-second intervals, whichever occurs first. This batching strategy reduces network overhead by approximately 90% compared to per-metric transmission while maintaining adequate temporal resolution for Grafana dashboards.

Third, synchronous Docker API calls enable the recovery manager to execute orchestration operations. These calls use Docker's Python SDK with direct Unix socket communication to the local Docker daemon, which internally coordinates with the Docker Swarm manager. This approach eliminates SSH overhead and provides immediate feedback on operation success or failure.

### 3.2.3 Deployment Architecture

The deployment architecture leverages Docker Swarm's service placement constraints to ensure correct component distribution across the cluster. Each monitoring agent runs as a global service with node-specific placement constraints, ensuring exactly one agent per worker node. The deployment script generates individual Docker service definitions with constraints formatted as `node.hostname == <node>`, preventing accidental co-location or absence of agents.

The recovery manager deploys exclusively on the master node using a similar constraint mechanism, ensuring it has direct access to Docker Swarm's management API. The manager requires elevated privileges to interact with the Docker socket, granted through Docker's socket mounting at `/var/run/docker.sock`. This approach maintains the security principle of least privilege by limiting socket access to only the recovery manager rather than all monitoring agents.

Network connectivity between components utilizes Docker Swarm's overlay network named `swarmguard-net`, created during initial deployment. All SwarmGuard components attach to this overlay network, enabling secure inter-component communication with automatic service discovery through Docker's internal DNS. The test application also attaches to this network, simulating production deployment patterns where applications and monitoring infrastructure coexist on shared networks.

---

## 3.3 Monitoring Infrastructure

### 3.3.1 Metrics Collection Methodology

The monitoring agent implements a polling-based metrics collection strategy with configurable intervals, defaulting to 5-second polling periods. This interval balances detection responsiveness with CPU overhead, as Docker's Stats API requires non-trivial CPU cycles to compute container-level resource utilization. Each polling cycle queries metrics for all containers on the local node, filters for containers belonging to monitored services, and calculates normalized percentage values for consistent threshold comparison.

CPU utilization calculation employs Docker's delta-based approach, comparing CPU usage deltas against system delta to compute percentage utilization. The implementation normalizes this value by the number of CPU cores to provide a consistent percentage regardless of host hardware configuration. The calculation formula is:

```
cpu_delta = stats['cpu_usage']['total_usage'] - previous_cpu
system_delta = stats['cpu_usage']['system_cpu_usage'] - previous_system
cpu_percent = (cpu_delta / system_delta) * cpu_count * 100.0
normalized_percent = cpu_percent / cpu_count
```

This normalization ensures that a single-threaded application consuming one full core reports 100% CPU usage rather than platform-dependent values like 25% on a four-core system.

Memory utilization calculates the ratio of current usage against the container's memory limit, expressed as a percentage. The implementation directly queries Docker's memory stats, which reflect actual physical memory consumption rather than virtual address space allocation. The calculation is straightforward:

```
usage = stats['memory_stats']['usage']
limit = stats['memory_stats']['limit']
memory_percent = (usage / limit) * 100.0
```

This metric accurately reflects memory pressure from the kernel's perspective, capturing the true risk of out-of-memory conditions.

Network throughput measurement presents greater complexity due to Docker's network namespace isolation. The monitoring agent accesses host-level network statistics by mounting the host's `/sys/class/net` filesystem, reading byte counters for the specified network interface. The implementation computes Mbps throughput by calculating byte deltas over time intervals and applying standard bit-per-second conversion:

```
bytes_recv_delta = current_rx_bytes - previous_rx_bytes
time_delta = current_time - previous_time
rx_mbps = (bytes_recv_delta / time_delta) * 8 / 1_000_000
```

This host-level measurement captures actual network utilization visible to external systems, including all protocol overhead and encapsulation, providing realistic network load assessment.

### 3.3.2 Threshold Detection Logic

The monitoring agent implements threshold detection through straightforward boolean logic applied to each collected metric. For each container, the agent evaluates whether CPU exceeds 75%, memory exceeds 80%, or network traffic exceeds scenario-specific thresholds. These threshold values were selected through preliminary experimentation to provide adequate migration time before container failure while minimizing false positives from transient load spikes.

To prevent false alerts from momentary spikes, the implementation requires two consecutive threshold breaches before triggering an alert. The agent maintains a state machine tracking the breach count per container, incrementing the counter when thresholds are exceeded and resetting to zero when metrics return to normal ranges. Only when the counter reaches 2 does the agent generate an alert, representing approximately 10 seconds of sustained high resource utilization given the 5-second polling interval.

Network threshold evaluation differs between scenarios to distinguish container-specific problems from high-demand situations. Scenario 1 (migration) triggers when network traffic remains below 35 Mbps despite high CPU or memory usage, indicating the container itself is problematic rather than experiencing legitimate high demand. Scenario 2 (scaling) triggers when network exceeds 65 Mbps alongside high CPU or memory, indicating genuine traffic load requiring additional capacity. This threshold-based differentiation enables rule-based scenario classification without machine learning complexity.

### 3.3.3 Alert Transmission Protocol

When threshold conditions warrant alert generation, the monitoring agent constructs a JSON payload containing comprehensive context about the threshold violation. The payload includes timestamp, node hostname, container ID and name, service name, detected scenario classification, and the complete set of current metrics. This rich payload enables the recovery manager to make informed decisions without requiring additional round-trip metric queries.

The alert transmission employs asynchronous HTTP POST to the recovery manager's `/alert` endpoint with connection pooling to minimize latency. The implementation uses Python's `aiohttp` library with keepalive connections, allowing multiple alerts to reuse established TCP connections rather than incurring connection establishment overhead for each alert. This optimization reduces typical alert latency from 100-150ms to 50-100ms, a critical improvement when targeting sub-second alert-to-action timing.

Error handling implements exponential backoff retry logic with a maximum of 2 retry attempts. If the initial POST fails due to network errors or recovery manager unavailability, the agent waits 100ms and retries. If the second attempt fails, it waits 200ms before the final retry attempt. After three failures, the agent logs the error and discards the alert, prioritizing system stability over guaranteed delivery. This trade-off acknowledges that transient network failures should not cause agent crashes, and the continuous polling ensures subsequent threshold violations will generate new alerts.

### 3.3.4 Observability Integration

Beyond real-time alerting, the monitoring infrastructure integrates with InfluxDB for historical metrics storage and Grafana for visualization. This integration serves both operational observability and experimental validation requirements. The monitoring agent batches metrics into InfluxDB's line protocol format and transmits batches every 10 seconds or when 20 data points accumulate, whichever occurs first.

The batching implementation maintains an in-memory buffer of metric tuples containing timestamp, measurement name, tags, and field values. When the batch reaches capacity, the agent constructs a multi-line InfluxDB write request and posts it to InfluxDB's HTTP API. This batching reduces network packet overhead from approximately 5 packets per second per agent (assuming 1-second granularity) to 0.1 packets per second, achieving the 90% network reduction critical for 100 Mbps infrastructure constraints.

Grafana dashboards consume this historical data to provide operators with visual insight into container resource utilization trends, threshold breach events, and recovery action outcomes. The dashboards display CPU, memory, and network metrics as time-series graphs with threshold lines overlaid, enabling quick visual identification of when containers approached or exceeded limits. Alert annotations mark the precise moments when the monitoring agents transmitted alerts, correlating visual metric spikes with system actions.

---

## 3.4 Decision-Making Algorithms

### 3.4.1 Scenario Classification Algorithm

The recovery manager implements a rule-based scenario classification algorithm to distinguish between container-specific problems requiring migration and high-demand situations requiring horizontal scaling. This classification occurs immediately upon alert reception, before any cooldown or breach counter evaluation, ensuring the manager understands the nature of the problem before deciding whether to act.

The classification algorithm evaluates two primary conditions: resource utilization levels and network traffic patterns. For resource utilization, the algorithm checks whether CPU exceeds 75% or memory exceeds 80%, using logical OR to ensure either metric alone can trigger classification. For network assessment, the algorithm calculates network percentage relative to the 100 Mbps interface capacity and compares against scenario-specific thresholds.

**Scenario 1 (Migration)** classification triggers when high resource utilization coincides with low network traffic (below 35 Mbps). The logical interpretation is that the container is consuming excessive CPU or memory due to internal problems such as resource leaks, inefficient algorithms, or excessive request processing time, rather than legitimate high external demand. The low network traffic indicates few incoming requests, suggesting the resource consumption is pathological rather than beneficial.

**Scenario 2 (Scaling)** classification triggers when high resource utilization coincides with high network traffic (above 65 Mbps). This pattern indicates the container is processing many concurrent requests (evidenced by high network throughput), causing high CPU and memory usage as a natural consequence of load. The appropriate response is to distribute this legitimate load across additional replicas rather than migrating the container elsewhere.

The gap between thresholds (35-65 Mbps) creates a "dead zone" where neither scenario triggers, preventing ambiguous situations from causing inappropriate actions. If network traffic falls in this middle range, the recovery manager logs the alert but takes no action, waiting for the situation to clarify into a definitive scenario pattern.

### 3.4.2 Breach Counter and Cooldown Management

To prevent rapid oscillation and excessive recovery actions, the recovery manager implements both breach counting and cooldown mechanisms. The breach counter requires multiple consecutive alerts for the same service and scenario before executing a recovery action, similar to the monitoring agent's consecutive breach requirement but operating at the decision level rather than detection level.

The breach counter maintains state as a dictionary keyed by `(service_name, scenario)` tuples, tracking the count of consecutive alerts received for each combination. When an alert arrives, the manager increments the corresponding counter. When the counter reaches 2 (configurable threshold), the manager evaluates whether cooldown permits action. If cooldown allows, the manager executes the appropriate recovery action and resets the counter to zero. If cooldown prohibits action, the manager logs the decision and increments the counter, allowing it to accumulate beyond the threshold to indicate sustained high-severity conditions.

The cooldown mechanism prevents repeated actions within specified time windows, protecting against oscillation where actions trigger state changes that themselves trigger additional actions. The implementation maintains a separate cooldown dictionary keyed by `(service_name, action_type)` tuples, recording the timestamp of the most recent action. Before executing any action, the manager checks the time elapsed since the last action of that type for that service. If insufficient time has passed, the manager rejects the action and logs the cooldown violation.

Cooldown periods vary by action type to reflect different oscillation risks. Migration operations use a 60-second cooldown, acknowledging that migrating a container back and forth between nodes provides no benefit and wastes resources. Scale-up operations use a 60-second cooldown, allowing time for new replicas to start and stabilize before adding additional replicas. Scale-down operations use a conservative 180-second cooldown, preventing premature capacity reduction when traffic patterns fluctuate.

### 3.4.3 Decision Execution Flow

The complete decision execution flow integrates classification, breach counting, and cooldown evaluation into a sequential pipeline. When an alert arrives via HTTP POST to the `/alert` endpoint, the recovery manager first extracts the scenario classification from the alert payload. If the scenario is unrecognized, the manager logs an error and returns HTTP 400 Bad Request.

For recognized scenarios, the manager increments the breach counter for the `(service_name, scenario)` combination. If the counter has not yet reached the required consecutive breach threshold (default 2), the manager logs the count increment and returns HTTP 200 OK to acknowledge receipt without taking action. This acknowledgment prevents the monitoring agent from retrying the alert due to perceived failure.

When the breach counter reaches the threshold, the manager evaluates cooldown eligibility. It queries the cooldown dictionary for the most recent action timestamp for the `(service_name, action_type)` combination, where action type corresponds to the scenario (migration for Scenario 1, scale-up for Scenario 2). If the current time minus the last action time exceeds the cooldown period, the manager proceeds to action execution. If cooldown has not expired, the manager logs the cooldown rejection, leaves the breach counter at its current value, and returns HTTP 200 OK.

Upon passing all checks, the manager executes the appropriate recovery action by calling either the migration function or scaling function in the Docker controller module. These functions interact with Docker Swarm's API to implement the actual container manipulation operations. After successful action completion, the manager updates the cooldown timestamp, resets the breach counter to zero, and returns HTTP 200 OK with a success message body.

---

## 3.5 Recovery Mechanisms

### 3.5.1 Zero-Downtime Migration Algorithm

The zero-downtime migration algorithm represents the core innovation enabling proactive recovery without service interruption. The algorithm leverages Docker Swarm's rolling update mechanism with specific configuration to ensure a new container becomes healthy before the old container terminates, maintaining at least one serving replica throughout the transition.

The migration process begins with task identification, where the algorithm queries Docker Swarm's task list to locate the specific task (container instance) experiencing resource stress. The monitoring agent's alert includes the container ID, which the algorithm matches against running tasks to determine both the task ID and the node hostname where it currently executes. This information is critical for constructing appropriate placement constraints.

Next, the algorithm applies a negative placement constraint to prevent the replacement task from scheduling on the problematic node. The constraint format `node.hostname != <from_node>` instructs Docker Swarm to exclude the failing node from scheduling consideration, ensuring the new task locates to a different worker. The algorithm retrieves the current service specification, appends this constraint to any existing placement constraints, and prepares an updated specification.

The critical configuration element is the rolling update order specification. The algorithm sets `Order: 'start-first'` in the update configuration, instructing Docker Swarm to start the new replica before stopping the old replica. This differs from the default `stop-first` order that would stop the old replica before starting the new one, creating a guaranteed service interruption window. The `start-first` order maintains service availability by ensuring overlapping replica operation.

The algorithm then forces a rolling update by incrementing the service's `ForceUpdate` counter, a Docker Swarm mechanism that triggers task recreation even when no image or configuration changes exist. Docker Swarm receives the updated specification, schedules a new task on an eligible node (excluding the problematic node via the constraint), waits for the new task to pass health checks, routes traffic to the new task, drains connections from the old task, and finally terminates the old task.

Throughout this process, the algorithm monitors task states by polling Docker Swarm's task API every second, logging when both old and new tasks run concurrently. This concurrent execution period constitutes the zero-downtime window where at least one replica serves requests continuously. The algorithm measures total migration time from task creation to task termination, targeting completion within 10 seconds to meet the Mean Time To Recovery performance objective.

After migration completes, the algorithm removes the negative placement constraint to restore normal scheduling behavior for future actions. This cleanup prevents constraint accumulation that could eventually exhaust available scheduling options if multiple migrations occur without cleanup.

**[INSERT FIGURE 3.2 HERE]**
*Figure 3.2: Zero-Downtime Migration Timeline*
*Sequence diagram showing: T+0ms alert reception, T+100ms constraint application, T+2000ms new task start, T+5000ms new task healthy, T+6000ms old task termination. Emphasize concurrent execution period between 2000-6000ms where both tasks serve requests.*

### 3.5.2 Horizontal Scaling Algorithm

The horizontal scaling algorithm addresses high-demand scenarios where additional capacity rather than relocation provides the appropriate response. Unlike migration which maintains constant replica count while changing placement, scaling modifies replica count to distribute load across more instances.

The scale-up algorithm implements a simple increment strategy, retrieving the current replica count from Docker Swarm's service specification and increasing it by one. This conservative approach prevents excessive resource allocation while maintaining simplicity. The algorithm updates the service specification with the new replica count and submits it to Docker Swarm, which handles task creation, scheduling, and health verification automatically.

Docker Swarm's internal scheduling algorithm selects an appropriate node for the new replica based on resource availability and existing placement constraints. The SwarmGuard system does not override this selection, trusting Docker Swarm's built-in load-balancing logic to make reasonable placement decisions. After task creation, the algorithm monitors the new task's state until it reaches the "running" status and passes health checks, typically requiring 5-7 seconds depending on image availability and application startup time.

The scale-down algorithm employs a more conservative approach to prevent premature capacity reduction. Rather than immediately scaling down when load decreases, the algorithm operates on a background monitoring thread that periodically evaluates whether services remain over-provisioned. Every 60 seconds, the thread queries aggregate metrics for each service's replicas, calculating total CPU and memory usage across all instances.

The scale-down decision logic verifies that remaining replicas can handle current load after reduction by applying the formula:

```
total_usage < threshold × (current_replicas - 1)
```

For example, if a service has 3 replicas consuming 120% total CPU (40% each) and the threshold is 75%, the algorithm checks whether 120% < 75% × (3-1) = 150%. This check passes, indicating the remaining 2 replicas would each consume 60% (120% / 2), safely below the 75% threshold.

Before executing scale-down, the algorithm enforces a two-phase cooldown. First, when metrics first indicate scale-down eligibility, the algorithm marks the service as an idle candidate but does not immediately scale. If the service remains eligible during the next evaluation cycle (60 seconds later), the algorithm checks whether the full 180-second cooldown has elapsed since the most recent scale-up. Only after both conditions are met does the algorithm execute the scale-down operation.

This conservative approach prevents oscillation where brief traffic dips trigger scale-down followed immediately by scale-up when traffic resumes. The 180-second cooldown provides a substantial buffer for traffic pattern stabilization, trading some resource efficiency for operational stability.

**[INSERT FIGURE 3.3 HERE]**
*Figure 3.3: Horizontal Scaling State Machine*
*State diagram showing: Normal state (1 replica), High Load Detection, Scale-Up Decision, Scaled State (2+ replicas), Load Decrease Detection, Cooldown Period, Scale-Down Decision. Include transitions with conditions (e.g., "CPU > 75% AND Network > 65 Mbps")*

### 3.5.3 Docker Swarm API Integration

The recovery mechanisms interact with Docker Swarm through Python's official Docker SDK, which provides high-level abstractions over Docker's REST API. The implementation establishes a single persistent client connection to the Unix socket at `/var/run/docker.sock`, avoiding connection overhead for each operation. This socket-based communication provides local-only access, ensuring only processes running on the manager node can execute orchestration operations.

For service updates, the implementation retrieves the current service specification using `client.services.get(service_id)`, modifies the relevant fields (placement constraints for migration, replica count for scaling), and submits the updated specification via `service.update()`. Docker's SDK handles version tracking internally, preventing race conditions where concurrent updates might conflict.

For task monitoring, the implementation queries `service.tasks()` to retrieve all tasks belonging to the service, filtering by desired state and current state to identify running, starting, or terminating tasks. The task objects contain detailed state information including task ID, node assignment, container ID, and current status (preparing, starting, running, complete, failed). This information enables the algorithm to track migration progress and verify that new tasks become healthy before old tasks terminate.

Error handling wraps all Docker API calls in try-except blocks to gracefully handle transient errors such as network timeouts, API unavailability, or constraint validation failures. When errors occur, the recovery manager logs detailed error information including the service name, attempted operation, and error message, then returns an appropriate HTTP error response to the monitoring agent. This approach prevents cascading failures where Docker API errors crash the recovery manager itself.

---

## 3.6 Experimental Validation Methodology

### 3.6.1 Testbed Configuration

The experimental testbed consists of a five-node Docker Swarm cluster deployed on physical Intel-based machines networked via legacy 100 Mbps Ethernet switches. This hardware selection reflects typical small to medium enterprise infrastructure constraints where older equipment remains in production due to cost considerations. The master node, designated "odin," runs both the Docker Swarm manager and the SwarmGuard recovery manager. The four worker nodes, designated "thor," "loki," "heimdall," and "freya," each run a SwarmGuard monitoring agent and host application containers.

The network topology connects all nodes to a common switch providing 100 Mbps full-duplex connectivity. This bandwidth constraint influenced architectural decisions such as metrics batching and event-driven alerting, as continuous metrics streaming would saturate the available network capacity. The testbed includes a separate Raspberry Pi host running InfluxDB and Grafana for metrics storage and visualization, connected to the same network segment but isolated from application traffic.

Load generation infrastructure consists of four Raspberry Pi 1.2B+ devices running Alpine Linux, designated "alpine-1" through "alpine-4." These devices execute test scripts that generate HTTP traffic to the test application via a custom load balancer. The Alpine Pi devices simulate distributed users, providing realistic traffic patterns across multiple source IPs rather than single-source bulk requests that Docker Swarm's ingress load balancing might handle differently.

### 3.6.2 Test Application Architecture

The test application, named "web-stress," implements a FastAPI-based HTTP service with controllable resource consumption patterns. The application exposes multiple stress endpoints enabling precise control over CPU, memory, and network utilization, allowing experimental validation of specific failure scenarios with known characteristics.

The CPU stress endpoint accepts parameters for target CPU percentage, duration, and ramp time, implementing a multiprocess busy-wait algorithm to consume specified CPU resources. The implementation spawns background worker processes that execute calculated busy-loop durations per second to achieve target utilization levels. The gradual ramp parameter enables realistic simulation of applications that degrade over time rather than instantly jumping to high utilization.

The memory stress endpoint allocates specified amounts of RAM by creating large byte arrays and touching pages to force physical allocation rather than virtual address space reservation. The gradual allocation ramp simulates memory leak scenarios where applications progressively consume more memory over time rather than immediately allocating maximum capacity. The implementation maintains allocated memory until explicit stop requests, ensuring sustained memory pressure throughout test execution.

The network stress endpoint generates HTTP traffic by initiating multiple concurrent download streams of large files, creating realistic network load patterns. The implementation uses three worker threads that repeatedly download files from an internal endpoint, with download frequency ramping up over the specified ramp period. This approach generates legitimate HTTP traffic visible to monitoring systems as increased network throughput rather than artificial packet flooding.

The combined stress endpoint orchestrates concurrent CPU, memory, and network stress in parallel threads, enabling Scenario 1 testing where high CPU and memory coincide with low network traffic. The incremental stress endpoint implements an additive load model where each request contributes additional load rather than setting absolute targets, enabling realistic multi-user simulations where N concurrent users generate aggregate load equal to N times per-user contribution.

### 3.6.3 Scenario 1 Test Procedure

Scenario 1 testing validates proactive migration capability by inducing container-specific resource stress without high network traffic. The test procedure begins with service deployment in a known initial state, typically a single replica on a specific worker node. The test script queries Docker Swarm to confirm initial placement, ensuring a deterministic starting condition.

Next, the script invokes the combined stress endpoint with parameters configured to trigger Scenario 1 classification: CPU set to 90%, memory to 900 MB, and network to 5 Mbps. These values exceed the detection thresholds (75% CPU, 80% memory) while remaining below the network threshold (35 Mbps), ensuring the monitoring agent classifies the situation as Scenario 1. The 45-second ramp parameter provides gradual resource escalation, simulating realistic degradation patterns.

After initiating stress, the script waits 15 seconds for the ramp to reach target levels, then waits an additional 30 seconds for threshold detection and breach counting. This waiting period accounts for the 5-second monitoring poll interval, 2-breach requirement (10 seconds minimum), and alert transmission latency. During this period, the monitoring agent detects sustained threshold violations and transmits alerts to the recovery manager.

The script then monitors the recovery manager's logs for migration confirmation messages, specifically searching for log entries indicating task creation, constraint application, and task termination. Simultaneously, the script polls Docker Swarm's service task list to observe task state transitions: a new task appears in "preparing" or "starting" state on a different node, progresses to "running" state, and the old task transitions to "shutdown" or "complete" state.

To measure Mean Time To Recovery (MTTR), the script captures timestamps from multiple sources: the initial stress invocation time, the first failed health check time from application logs, the migration action time from recovery manager logs, and the first successful health check time after migration. The MTTR calculation uses the interval from the last successful health check before failure to the first successful health check after recovery, representing actual service unavailability from the user perspective.

For zero-downtime validation, the script queries HTTP health check logs to verify whether any failed requests occurred during the migration window. The logs record HTTP status codes for continuous health check requests sent every second. If the logs show an uninterrupted sequence of HTTP 200 OK responses with no gaps or failures, the test achieved zero downtime. If any HTTP 502, 503, or connection timeout responses appear, the test experienced downtime equal to the gap duration.

### 3.6.4 Scenario 2 Test Procedure

Scenario 2 testing validates horizontal auto-scaling capability by generating high concurrent traffic that triggers both resource and network thresholds simultaneously. The test procedure deploys the service with an initial single replica and configures the load generator to simulate multiple concurrent users across distributed Alpine Pi nodes.

The load generation script implements a staggered user startup pattern where users begin sending requests at 3-second intervals, gradually ramping up aggregate load over a 30-45 second period. Each user executes requests against the incremental stress endpoint with parameters chosen to contribute 5% CPU, 50 MB memory, and 5 Mbps network traffic. With 10 users per Alpine Pi node and 4 nodes, total load reaches 200% CPU, 2000 MB memory, and 200 Mbps network, substantially exceeding single-container capacity.

This load pattern triggers Scenario 2 classification because both resource thresholds (75% CPU, 80% memory) and network threshold (65 Mbps) are exceeded, indicating legitimate high demand rather than container problems. The monitoring agent detects these sustained threshold violations and transmits Scenario 2 alerts to the recovery manager.

The recovery manager evaluates breach count and cooldown, then executes a scale-up operation incrementing replicas from 1 to 2. Docker Swarm schedules the new task on an available worker node, starts the container, waits for health checks to pass, and adds the new task to the load balancing pool. The script monitors this process by polling Docker Swarm's task list, measuring scale-up latency from alert reception to new task "running" state.

After scale-up completes, the script monitors load distribution across replicas by querying the custom load balancer's metrics endpoint. This endpoint reports per-replica request counts and distribution percentages, enabling verification that traffic distributes evenly between the two replicas. Ideal distribution shows approximately 50% traffic to each replica, while significant imbalance (e.g., 70/30 or worse) indicates load balancing failures.

To validate the scale-down mechanism, the test script stops the load generation after 60 seconds, allowing the system to return to low utilization. The recovery manager's background monitoring thread detects the decreased load, marks the service as idle, and waits for the 180-second cooldown to expire. The script monitors recovery manager logs for scale-down decisions and Docker Swarm task lists for task termination, measuring scale-down latency from cooldown expiry to actual replica count reduction.

### 3.6.5 Overhead Measurement Procedure

System overhead measurement quantifies the resource consumption introduced by SwarmGuard's monitoring and decision-making components. The measurement procedure compares three distinct cluster configurations: baseline (no SwarmGuard), monitoring-only (agents but no recovery manager), and full SwarmGuard (both agents and recovery manager). Each configuration runs for a 10-minute steady-state period with consistent application workload to ensure representative measurements.

For CPU overhead measurement, the procedure uses Docker's Stats API to collect per-container CPU usage every second, averaging these values over the 10-minute measurement window. The baseline configuration establishes reference CPU consumption from application containers and Docker daemon overhead alone. The monitoring-only configuration adds monitoring agent CPU consumption to isolate pure monitoring overhead. The full SwarmGuard configuration includes both monitoring agent and recovery manager CPU consumption, representing total system overhead.

Memory overhead measurement queries Docker Stats API for resident set size (RSS) memory consumption, representing actual physical memory usage rather than virtual address space allocation. The procedure collects RSS values every second and averages over the measurement window, comparing baseline, monitoring-only, and full configurations to isolate incremental memory overhead from each SwarmGuard component.

Network overhead measurement captures transmitted bytes between monitoring agents and both InfluxDB and the recovery manager over the measurement window. The procedure uses Docker's network statistics API to query sent and received bytes for SwarmGuard component containers, calculating megabits per second throughput. This measurement quantifies the network impact of metrics batching and alert transmission, validating that overhead remains below the critical 0.5 Mbps threshold necessary for 100 Mbps infrastructure compatibility.

Per-node overhead breakdown disaggregates cluster-wide measurements to individual nodes, identifying whether SwarmGuard creates resource hotspots on specific nodes. The procedure collects node-level metrics using htop snapshots and Docker node-level stats, comparing overhead distribution across the master node (hosting recovery manager) versus worker nodes (hosting only monitoring agents). Even distribution validates that SwarmGuard scales horizontally without creating centralized bottlenecks.

---

## 3.7 Design Rationale and Trade-offs

### 3.7.1 Technology Selection Justification

The selection of Python for both monitoring agents and recovery manager reflects prioritization of development velocity and ecosystem maturity over runtime performance. Python's Docker SDK provides comprehensive API coverage with minimal boilerplate, enabling rapid implementation of complex orchestration logic. The asyncio framework enables concurrent I/O operations without threading complexity, critical for the monitoring agent's simultaneous metrics collection, alert sending, and InfluxDB batching.

While Go would provide superior runtime performance and lower memory overhead, the performance difference is negligible for SwarmGuard's workload characteristics. Monitoring agents collect metrics every 5 seconds and send alerts infrequently, creating minimal CPU load even with Python's interpreted execution. The recovery manager processes tens of alerts per hour rather than thousands per second, well within Python's performance envelope. Development time savings outweigh marginal runtime efficiency gains.

The choice of Docker Swarm over Kubernetes aligns with the project's focus on resource-constrained environments and small to medium enterprise contexts. Docker Swarm provides built-in rolling update mechanisms with start-first ordering, eliminating the need to implement custom zero-downtime migration logic. Swarm's simpler architecture reduces operational complexity and resource overhead compared to Kubernetes' multi-component control plane, making it more suitable for clusters with limited CPU and memory budgets.

### 3.7.2 Event-Driven vs. Polling Architecture

The system implements event-driven alerts for recovery actions while maintaining polling-based metrics collection, reflecting different requirements for these two data flows. Event-driven alerts prioritize low latency and minimal network overhead, transmitting data only when thresholds breach. This approach achieves sub-second alert propagation while consuming near-zero network bandwidth during normal operation, critical for 100 Mbps infrastructure constraints.

Polling-based metrics collection provides predictable, regular sampling intervals that simplify statistical analysis and visualization. InfluxDB and Grafana expect time-series data with consistent timestamps and intervals, which polling naturally provides. An event-driven approach would generate irregular timestamp patterns based on workload fluctuations, complicating downsampling and aggregation queries.

The hybrid approach balances real-time responsiveness for critical events (threshold violations) with regular sampling for observability (historical metrics). Pure event-driven architecture would miss gradual degradation patterns where metrics approach but never cross thresholds, while pure polling would generate excessive network traffic for infrequent alert conditions.

### 3.7.3 Centralized vs. Distributed Decision-Making

SwarmGuard implements centralized decision-making through the recovery manager rather than distributed consensus among monitoring agents. This design accepts a single point of failure in exchange for simpler consistency guarantees and lower implementation complexity. Centralized decision-making ensures exactly one recovery action executes per alert, preventing race conditions where multiple agents might simultaneously attempt migration or scaling.

Distributed consensus algorithms such as Raft or Paxos could eliminate the single point of failure but would substantially increase implementation complexity and network overhead. The recovery manager's relatively simple failure domain (it only processes alerts, not application traffic) reduces the impact of its failure compared to distributed systems where consensus failures can cause data loss or split-brain scenarios.

The practical risk of recovery manager failure is mitigated by Docker Swarm's automatic service restart on the master node. If the recovery manager crashes, Docker restarts it within seconds, during which monitoring agents buffer or discard alerts. This temporary unavailability delays recovery actions but does not affect application availability, as Docker Swarm continues serving traffic through existing containers.

### 3.7.4 Rule-Based vs. Machine Learning Classification

The scenario classification algorithm employs simple threshold-based rules rather than machine learning models, prioritizing interpretability and predictability over potential accuracy gains. Rule-based classification provides deterministic behavior where operators can precisely predict system actions given specific metric values. Threshold tuning requires only YAML configuration changes without model retraining or validation dataset collection.

Machine learning approaches could potentially achieve higher classification accuracy in ambiguous scenarios where resource patterns don't clearly match Scenario 1 or Scenario 2 profiles. However, ML models introduce operational complexity: training data collection, model training pipelines, version management, and ongoing retraining to prevent model staleness. For the project's targeted deployment context (SMEs with limited ML expertise), this complexity outweighs potential accuracy benefits.

The threshold-based approach also enables operators to directly understand and modify system behavior through intuitive percentage values. Changing the network threshold from 65 Mbps to 80 Mbps clearly reduces Scenario 2 sensitivity, while equivalent ML model tuning requires understanding hyperparameters, regularization, and potentially model architecture changes.

### 3.7.5 Cooldown Period Calibration

The cooldown period durations (60 seconds for migration, 180 seconds for scale-down) reflect empirical balancing between responsiveness and stability. Shorter cooldowns enable faster response to changing conditions but increase oscillation risk, while longer cooldowns improve stability at the cost of delayed adaptation.

The 60-second migration cooldown provides sufficient time for Docker Swarm to complete rolling updates and for metrics to stabilize on the new node before considering additional migrations. Preliminary testing with 30-second cooldowns occasionally triggered secondary migrations before the first migration fully completed, causing unnecessary churn. The 60-second value eliminates these premature migrations while maintaining reasonable responsiveness to genuine cascading failures.

The 180-second scale-down cooldown reflects conservative capacity management philosophy, prioritizing availability over resource efficiency. Traffic patterns often exhibit brief lulls followed by renewed load within 1-2 minutes. Aggressive scale-down with 60-second cooldowns would cause oscillation where capacity scales down during momentary lulls and immediately scales back up when traffic resumes. The 180-second buffer ensures sustained low utilization before reducing capacity.

---

## 3.8 Summary

This chapter presented the complete methodology for SwarmGuard's design, implementation, and validation. The system architecture employs distributed monitoring agents for local metrics collection with centralized decision-making through the recovery manager, balancing responsiveness with consistency. The monitoring infrastructure implements efficient polling-based collection with event-driven alerting, achieving sub-second alert latency while consuming minimal network bandwidth.

The decision-making algorithms classify scenarios through rule-based threshold evaluation, distinguishing container problems from high-demand situations to select appropriate recovery actions. The recovery mechanisms leverage Docker Swarm's rolling update primitives to implement zero-downtime migration and horizontal auto-scaling, validated through comprehensive experimental procedures on a five-node physical testbed.

Key design decisions prioritized simplicity and operational feasibility over theoretical optimality, selecting Python for rapid development, rule-based classification for interpretability, and centralized decision-making for consistency. The experimental validation methodology ensures reproducible measurements through controlled stress patterns, standardized test procedures, and multi-source data collection.

The next chapter presents the experimental results obtained through this methodology, quantifying SwarmGuard's performance improvements in MTTR reduction, zero-downtime achievement, and system overhead.

---

**[END OF CHAPTER 3]**

**Word Count:** ~8,300 words

**Figures to Include:**
- Figure 3.1: System Architecture Diagram (4 worker nodes + master node + observability stack)
- Figure 3.2: Zero-Downtime Migration Timeline (sequence diagram)
- Figure 3.3: Horizontal Scaling State Machine (state diagram)

**Code/Algorithm References:**
- Monitoring agent: `/swarmguard/monitoring-agent/agent.py`
- Recovery manager: `/swarmguard/recovery-manager/manager.py`
- Docker controller: `/swarmguard/recovery-manager/docker_controller.py`
- Configuration: `/swarmguard/config/swarmguard.yaml`
- Test scripts: `/swarmguard/tests/`
