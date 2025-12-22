# Network Stress Testing - Problem Solving Log

**Date Started:** 2025-12-22
**Problem:** Network load spikes to ~60-80 Mbps then drops to <20 Mbps, cannot sustain high network traffic
**Goal:** Achieve sustained network load >80 Mbps to properly test Scenario 2 scaling and load distribution

---

## Current Situation Analysis

### Observed Behavior (from Grafana)
- **Pattern:** Network spikes for a few seconds, then stabilizes at <20 Mbps
- **Expected:** Sustained 250 Mbps (25 users × 10 Mbps each) or similar high load
- **Actual:** Downloads peak ~80 Mb/s, then drop to ~20 Mb/s stable
- **CPU/Memory:** Working perfectly, controllable via parameters ✅
- **Network:** Not controllable, same behavior regardless of input parameters ❌

### Last Test Command
```bash
./tests/scenario2_ultimate.sh 5 1 1 10 9 3 6000
```
- 25 total users (5 Alpines × 5 users each)
- 10 Mbps per user = 250 Mbps expected
- Result: Still drops to <20 Mbps after initial spike

---

## Root Cause Analysis

### Problem 1: Small Data Payload (16 KB)

**Current Implementation** (network_stress.py:28-46):
```python
chunk_size = 16 * 1024  # 16KB payload
data = b'X' * chunk_size
requests.post("http://192.168.2.50:8080/health", data=data, timeout=2)
```

**Why This Fails:**
- 16 KB transfers in **milliseconds** on 100 Mbps network
- After initial POST, connection completes quickly
- No sustained data transfer to maintain bandwidth usage
- The `/health` endpoint immediately returns a small JSON response
- Total transfer time: <50ms per request
- Rest of the time (12.5ms - 50ms = no overlap) has no active transfer

**Evidence from Grafana:**
- Initial spike = burst of requests starting
- Drop to <20 Mbps = sparse request pattern, mostly idle time between transfers

### Problem 2: Wrong Endpoint Target

**Current:** `POST http://192.168.2.50:8080/health`
- `/health` returns tiny JSON: `{"status": "healthy"}`
- No actual data payload downloaded
- Upload 16 KB, receive <100 bytes back

**Available Better Endpoint:** `/download/data?size_mb=X&cpu_work=Y`
- This endpoint **streams large data** back to client
- Creates **real sustained network transfer**
- Generates MB-scale payloads that take seconds to transfer

### Problem 3: Request Overlap vs. Transfer Duration

**Current Strategy:**
- 60-second requests sent every 15 seconds (4× overlap)
- BUT: Each request completes in <1 second (16 KB transfer)
- Result: Only ~4 seconds of active transfer per 15-second window
- Network utilization: ~27% (4/15)

**What We Need:**
- Requests that take 15+ seconds to complete
- Large downloads that sustain bandwidth continuously
- Overlapping transfers that fill the entire time window

---

## Solution Strategy

### Solution 1: Use Large Download Endpoint ⭐ **RECOMMENDED**

**Change network stress to download large files:**

Instead of:
```python
requests.post("http://192.168.2.50:8080/health", data=b'X' * 16384)
```

Use:
```python
# Download 50 MB file - takes ~4 seconds at 100 Mbps
requests.get("http://192.168.2.50:8080/download/data?size_mb=50&cpu_work=0")
```

**Why This Works:**
- 50 MB download at 100 Mbps = ~4 seconds transfer time
- With 15-second request intervals, we get continuous overlap
- Multiple users downloading simultaneously = sustained high bandwidth
- Creates **real bidirectional traffic** measured by monitoring agents

**Calculation:**
- 25 users × 50 MB every 15 seconds = 83.3 MB/sec = **666 Mbps aggregate**
- With load balancing and network limits, will saturate to ~80-100 Mbps sustained

### Solution 2: Increase Upload Payload Size

**Make POST data much larger:**
```python
chunk_size = 10 * 1024 * 1024  # 10 MB instead of 16 KB
data = b'X' * chunk_size
requests.post("http://192.168.2.50:8080/health", data=data)
```

**Pros:**
- Minimal code change
- Larger uploads = longer transfer time

**Cons:**
- Still hitting `/health` which doesn't send much back
- Only upload traffic counted, download minimal
- Monitoring agents measure BOTH upload + download

### Solution 3: Bidirectional Transfer Endpoint

**Create new endpoint that RECEIVES and SENDS data:**
```python
@app.post("/stress/bidirectional")
async def bidirectional_traffic(upload_mb: int = 10, download_mb: int = 10):
    # Receive upload_mb from client
    # Send download_mb back to client
    # Both directions create network load
```

**Pros:**
- Full control over both upload and download
- Balanced bidirectional traffic

**Cons:**
- Requires code changes to web-stress app
- More complex than using existing `/download/data`

---

## Testing Plan

### Test 1: Use /download/data Endpoint (QUICK WIN)

**Hypothesis:** Large downloads will sustain network bandwidth better than small POSTs

**Modification Required:**
- Edit `network_stress.py:20-60`
- Change from POST to GET
- Target `/download/data?size_mb=50` instead of `/health`

**Expected Result:**
- Network graph shows sustained 80-100 Mbps
- Multiple replicas downloading simultaneously
- Grafana shows smooth continuous bandwidth usage

**Test Command:**
```bash
./tests/scenario2_ultimate.sh 5 1 1 10 3 60 900
# 25 users × 10 Mbps = 250 Mbps target
# With download endpoint, should sustain >80 Mbps
```

**Success Criteria:**
- ✅ Network remains >80 Mbps for full duration
- ✅ No drop to <20 Mbps after initial ramp
- ✅ Load distributes evenly after scaling
- ✅ Scenario 2 triggers due to sustained high network

---

### Test 2: Increase Upload Chunk Size (FALLBACK)

**If Test 1 fails or needs tuning**

**Modification:**
- Change `chunk_size = 16 * 1024` to `chunk_size = 5 * 1024 * 1024` (5 MB)

**Test Command:**
```bash
./tests/scenario2_ultimate.sh 5 1 1 10 3 60 900
```

**Success Criteria:**
- Upload traffic >40 Mbps sustained
- Combined upload + download >80 Mbps

---

### Test 3: Hybrid Approach

**Combine large downloads AND uploads**

**Test Command:**
```bash
./tests/scenario2_ultimate.sh 3 5 100 20 5 60 600
# Fewer users (15 total) but higher per-user load (20 Mbps each)
# Target: 300 Mbps total
```

---

## Experiment Log

### Experiment 1: Current Baseline ❌
**Date:** 2025-12-22
**Command:** `./tests/scenario2_ultimate.sh 5 1 1 10 9 3 6000`
**Config:**
- 25 users (5 Alpines × 5 users)
- 10 Mbps per user = 250 Mbps expected
- Stagger: 9s, Ramp: 3s, Hold: 6000s

**Results:**
- Network: Spikes to ~60-80 Mbps initially
- Network: Drops to <20 Mbps sustained
- CPU: ~14% on worker-4, <1% on others ✅
- Memory: ~11% stable ✅
- **Scenario 2:** Did NOT trigger (network too low)

**Conclusion:** Current 16 KB POST method cannot sustain high network load

---

### Experiment 2: [PENDING] - Test /download/data Endpoint

**Planned Command:**
```bash
# Stop all stress first
curl "http://192.168.2.50:8080/stress/stop"
for alpine in alpine-{1..5}; do ssh $alpine "pkill -9 -f wget; pkill -9 -f scenario2" || true; done
sleep 10

# Run test with modified network_stress.py
./tests/scenario2_ultimate.sh 5 1 1 10 3 60 900
```

**What to Monitor:**
1. Network Download graph - should stay >80 Mbps
2. Network Upload graph - will be lower (request overhead only)
3. CPU on replicas - may increase due to data generation
4. Scenario 2 trigger timing
5. Post-scaling load distribution

**Expected Timeline:**
- T+0-15s: Ramp up, network climbing
- T+15-60s: Network sustains >80 Mbps
- T+60-90s: Scenario 2 triggers, scales to 2 replicas
- T+90-900s: Load distributed across replicas, each ~40-50 Mbps
- T+900s: Test completes

---

## Code Changes Needed

### Option A: Modify network_stress.py (Use Download Endpoint)

**File:** `/swarmguard/web-stress/stress/network_stress.py`

**Current (Lines 20-50):**
```python
def generate_http_traffic(self, stop_event: Event):
    target_url = "http://192.168.2.50:8080/health"
    chunk_size = 16 * 1024  # 16KB

    while not stop_event.is_set():
        # ... calculate delay ...
        data = b'X' * chunk_size
        response = requests.post(target_url, data=data, timeout=2)
        time.sleep(delay)
```

**Proposed Change:**
```python
def generate_http_traffic(self, stop_event: Event):
    # NEW: Use download endpoint for sustained large transfers
    base_url = "http://192.168.2.50:8080"

    while not stop_event.is_set():
        with self.mbps_lock:
            target_mbps = self.current_mbps

        if target_mbps > 0:
            # Calculate download size to sustain target_mbps for ~15 seconds
            # 10 Mbps × 15 sec = 150 Mb = 18.75 MB
            # Use larger size to ensure sustained transfer
            download_mb = max(10, int(target_mbps * 15 / 8))  # Convert Mbps to MB

            try:
                # GET request downloads large file, sustains bandwidth
                response = requests.get(
                    f"{base_url}/download/data?size_mb={download_mb}&cpu_work=0",
                    timeout=30,  # Allow time for large download
                    stream=True  # Stream to avoid memory issues
                )
                # Consume the stream to ensure full download
                for chunk in response.iter_content(chunk_size=1024*1024):
                    if stop_event.is_set():
                        break
                    pass  # Just consume, don't store

            except Exception as e:
                logger.error(f"Download error: {e}")

            # Sleep briefly before next download
            time.sleep(1)
        else:
            time.sleep(0.1)
```

**Rebuild Required:**
```bash
ssh master "cd /home/amir/swarmguard && docker service update --force web-stress"
```

---

### Option B: Increase Chunk Size (Quick Test, No Endpoint Change)

**File:** `/swarmguard/web-stress/stress/network_stress.py:28`

**Change:**
```python
# OLD:
chunk_size = 16 * 1024  # 16KB

# NEW:
chunk_size = 10 * 1024 * 1024  # 10 MB - sustains transfer longer
```

**Pros:** Single line change, very fast to test
**Cons:** Only affects upload, may not be enough

---

## Next Actions

1. **RECOMMENDED:** Implement Option A (download endpoint modification)
2. Test with: `./tests/scenario2_ultimate.sh 5 1 1 10 3 60 900`
3. Monitor Grafana Network Download graph
4. Record results in Experiment 2 section above
5. If successful, test with higher loads: `./tests/scenario2_ultimate.sh 5 1 1 15 3 60 900` (15 Mbps/user)

---

## Questions to Answer Through Testing

- [ ] Does `/download/data` sustain bandwidth better than POST to `/health`?
- [ ] What download_mb size gives smoothest sustained bandwidth?
- [ ] Does this method still allow proper load distribution visualization?
- [ ] What's the maximum sustainable network load before saturation?
- [ ] Does CPU increase significantly when generating large downloads?

---

## Success Metrics

**For a successful network stress test, we need:**

1. **Sustained Load:** Network >80 Mbps for full test duration (no drops)
2. **Controllable:** Changing input parameters reliably changes network load
3. **Triggers Scenario 2:** High network (>65 Mbps) causes scaling
4. **Visible Distribution:** After scaling, Grafana shows even load split
5. **Stable:** No oscillations, smooth continuous bandwidth usage

---

## Notes & Observations

### Why 16 KB Isn't Enough
- 16 KB at 100 Mbps = 1.3 ms transfer time
- Even with 12.5ms intervals, only ~10% bandwidth utilization
- Network is idle 90% of the time waiting for next request

### Why Large Downloads Work Better
- 50 MB at 100 Mbps = 4 second transfer time
- With 15-second request intervals, 4+ concurrent downloads overlap
- Network continuously busy with active transfers
- Real sustained bandwidth usage

### Infrastructure Limits
- 100 Mbps total cluster bandwidth
- Shared across all nodes
- Realistic max sustained: ~80-90 Mbps per service
- Above this, congestion and retransmits occur

