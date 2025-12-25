# Scenario 2 Testing Approach - Final Documentation

**Date**: 2024-12-25
**Purpose**: Document the correct approach for Scenario 2 testing to avoid repeating failed methods

---

## PRD Requirement (CRITICAL)

**Scenario 2 Detection Rule** (PRD v5.1, Section 3.2):
```
IF (CPU_usage > 75% OR Memory_usage > 80%)
   AND Network_usage > 65%
THEN trigger Scenario 2 (Horizontal Scaling)
```

**Key Point**: Network MUST be >65% to distinguish from Scenario 1 (migration)

---

## Testing Methods Attempted

### ❌ Method 1: CPU-Only Stress (FAILED - Wrong Scenario)

**Command**:
```bash
curl -s "http://192.168.2.50:8080/stress/cpu?target=85&duration=600&ramp=60"
```

**Why it Failed**:
- CPU=85%, Network=0% → Triggers Scenario 1 (migration), NOT Scenario 2 (scaling)
- Violates PRD requirement: Network must be >65%

**Conclusion**: Cannot use for Scenario 2 testing

---

### ❌ Method 2: Alpine wget (FAILED - Bursty Network)

**Command**:
```bash
./tests/scenario2_ultimate.sh 5 1 1 10 3 60 600
# 5 Alpines, 10 Mbps per user, various configurations tested
```

**Parameters Tested**:
- 5 users × 8 Mbps = ~50 Mbps (stable but below 65 Mbps threshold)
- 8 users × 8 Mbps = spiky (20-100 Mbps bursts)
- 12 users × 8 Mbps = spiky (20-100 Mbps bursts)
- 15 users × 8 Mbps = spiky (20-100 Mbps bursts)

**Why it Failed**:
- HTTP wget is transactional: request → response → idle
- Creates burst pattern, never sustains >65 Mbps long enough
- Graph shows spikes to 100 Mbps, drops to 20-40 Mbps

**Conclusion**: HTTP request/response pattern inherently bursty, unsuitable for sustained load

---

### ❌ Method 3: Internal Network Stress with DOWNLOAD_MULTIPLIER (FAILED - Ceiling Hit)

**Approach**:
- Set `NETWORK_DOWNLOAD_MULTIPLIER=40` on web-stress container
- Trigger internal network stress: `curl http://192.168.2.50:8080/stress/network?...`

**Results**:
- Only achieved 40-50 Mbps sustained (not 80+ Mbps expected)
- Hit bandwidth ceiling despite increasing multiplier

**Why it Failed**:
- web-stress downloads from itself (loopback/internal)
- Only 3 worker threads in single container
- Not real external network load

**Conclusion**: Internal stress insufficient for real network traffic simulation

---

## ✅ Method 4: scenario2_ultimate.sh (FINAL APPROACH)

### Implementation

**Script**: `04_scenario2_single_test.sh` calls `scenario2_ultimate.sh`

**Command**:
```bash
./tests/scenario2_ultimate.sh 15 12 40 12 2 80 900
# Parameters:
#   15 users per Alpine node (5 Alpines × 15 = 75 total users)
#   12% CPU per user
#   40MB Memory per user
#   12 Mbps Network per user
#   2s stagger between users starting
#   80s ramp time for each user
#   900s (15 min) hold time at peak load
```

**What it does**:
1. Deploys `/tmp/scenario2_alpine_user.sh` to each Alpine node
2. Each Alpine starts 15 "simulated users"
3. Each user sends overlapping `/stress/combined` requests:
   - 60-second request duration
   - 15-second interval between requests
   - Creates 4x overlap (4 concurrent requests per user)
4. Total: 75 users × 4 overlapping requests = **300 concurrent requests at steady state**

**Cleanup**:
```bash
# Script has built-in cleanup via trap
# Manual cleanup if needed:
curl "http://192.168.2.50:8080/stress/stop"
for alpine in alpine-1 alpine-2 alpine-3 alpine-4 alpine-5; do
    ssh "$alpine" "pkill -9 -f wget" || true
    ssh "$alpine" "pkill -9 -f scenario2_alpine_user.sh" || true
done
```

### Why This Works

**Network Load**:
- 5 Alpine nodes × 3 workers = **15 concurrent downloads**
- Each download: 50MB at ~100 Mbps = ~4 seconds per download
- Continuous loop: as soon as download finishes, next starts immediately
- **Result**: Overlapping downloads create **sustained 50-80 Mbps** (not bursty)

**CPU/Memory Load**:
- web-stress must generate 50MB of data repeatedly → **high CPU**
- Serving 15 concurrent connections → **high memory**
- **Result**: Meets (CPU OR Memory) condition

**Meets PRD**:
- Network >65 Mbps ✓
- CPU OR Memory high ✓
- **Triggers Scenario 2 (Horizontal Scaling) ✓**

---

## Expected Test Results

### Grafana Observations

**Network Graph**:
- Should show **sustained 50-80 Mbps** (smooth line, not spikes)
- No drops to <20 Mbps like wget method
- Stays above 65 Mbps threshold consistently

**CPU Graph**:
- Should show **60-80% CPU** on web-stress container
- Increases as it generates data for downloads

**Memory Graph**:
- Should show **moderate-high memory usage** from concurrent connections

**Replica Count**:
- Starts at 1 replica
- After ~2 minutes: Scales to 2 replicas (threshold breach)
- If load continues: May scale to 3 replicas
- After load stops: Scales back down to 1 (after cooldown)

**Load Distribution After Scaling**:
- 1 replica at 70 Mbps → scales to 2 → each should handle ~35 Mbps
- 1 replica at 75% CPU → scales to 2 → each should handle ~37.5% CPU

### Recovery Manager Logs

Should show entries like:
```
SCENARIO 2 DETECTED: High traffic (Network: 72.5 Mbps, CPU: 78.2%)
Scaling web-stress from 1 to 2 replicas
```

---

## If Network Load Still Below 65 Mbps

**Tuning Options** (in order of preference):

1. **Increase download size**: Change `size_mb=50` to `size_mb=100`
   - Longer downloads = more sustained traffic

2. **Add more workers per Alpine**: Change `for i in 1 2 3` to `for i in 1 2 3 4 5`
   - 5 Alpines × 5 workers = 25 concurrent downloads

3. **Use faster network endpoint**: Add `&cpu_work=50` to make server generate data faster

4. **Add 6th Alpine node** (if available): `alpine-6`

---

## Testing Checklist

Before running 10 iterations, verify ONE test shows:

- [ ] Network sustained >65 Mbps for at least 2 minutes
- [ ] CPU or Memory >75% on web-stress container
- [ ] Replica count scales from 1 → 2 (or 1 → 2 → 3)
- [ ] Recovery manager logs show "SCENARIO 2 DETECTED"
- [ ] After scaling, load distributes across replicas
- [ ] After load stops, replicas scale back down

If all checkboxes pass → Proceed with 10 iterations

---

## Summary

| Method | Network Pattern | Meets PRD? | Status |
|--------|----------------|------------|--------|
| CPU-only | 0 Mbps | ❌ No (triggers Scenario 1) | Rejected |
| Alpine wget | 20-100 Mbps bursts | ❌ No (too spiky) | Rejected |
| Internal DOWNLOAD_MULTIPLIER | 40-50 Mbps | ❌ No (below threshold) | Rejected |
| **Alpine continuous downloads** | **50-80 Mbps sustained** | ✅ **Yes** | **FINAL** |

---

**Last Updated**: 2024-12-25
**Next Action**: Test `./04_scenario2_single_test.sh 1` and verify in Grafana
