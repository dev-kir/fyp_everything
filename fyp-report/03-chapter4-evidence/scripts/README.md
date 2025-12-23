# Testing Scripts - Usage Guide

**Location:** Run all scripts from this directory (`fyp-report/03-chapter4-evidence/scripts/`)

**All results** will be saved to `../raw_outputs/`

---

## 📋 **Testing Order**

### **Step 1: Environment Info (Once)**
```bash
chmod +x *.sh
./00_environment_info.sh
```

### **Step 2: Deploy Clean System**
```bash
./01_deploy_and_verify.sh
```

### **Step 3: Baseline Testing (Docker Swarm Reactive)**

**Disable SwarmGuard first:**
```bash
./02_baseline_disable_swarmguard.sh
```

**Run 10 baseline tests:**
```bash
for i in {1..10}; do
  ./02_baseline_single_test.sh $i
  sleep 30  # Cooldown between tests
done
```

**Or run them one at a time:**
```bash
./02_baseline_single_test.sh 1
./02_baseline_single_test.sh 2
# ... etc
```

### **Step 4: Scenario 1 Testing (Proactive Migration)**

**Enable SwarmGuard:**
```bash
./03_enable_swarmguard.sh
```

**Run scenario 1 tests:**
```bash
# TODO: Create scenario 1 script
# For now, refer to ACTUAL_COMMANDS.md Section 3
```

### **Step 5: Scenario 2 Testing (Horizontal Autoscaling)**

**Run scenario 2 tests:**
```bash
# TODO: Create scenario 2 script
# For now, refer to ACTUAL_COMMANDS.md Section 4
```

---

## 📊 **Quick Commands**

### **Check current state:**
```bash
ssh master "docker service ls"
```

### **Check if SwarmGuard is enabled:**
```bash
ssh master "docker service ls | grep -E '(recovery-manager|monitoring-agent)'"
```

### **View latest results:**
```bash
ls -lht ../raw_outputs/ | head -20
```

### **Check a specific log:**
```bash
tail -f ../raw_outputs/02_baseline_mttr_test1.log
```

---

## 🔧 **Troubleshooting**

### **Script permission denied:**
```bash
chmod +x *.sh
```

### **SSH connection issues:**
```bash
# Test SSH to master
ssh master "hostname"
```

### **Service deployment fails:**
```bash
# Check Docker logs
ssh master "docker service logs recovery-manager --tail 50"
```

### **Clean slate (start over):**
```bash
./01_deploy_and_verify.sh
```

---

## 📁 **Expected Output Files**

After all testing, you should have ~60 files in `../raw_outputs/`:

- `00_*.txt` - Environment info (6 files)
- `01_*.txt` - Deployment logs (1 file)
- `02_baseline_*.{log,txt}` - Baseline tests (20 files: 10 logs + 10 timelines)
- `03_scenario1_*.{log,txt,json}` - Scenario 1 tests (20 files)
- `04_scenario2_*.{log,jsonl,txt,json}` - Scenario 2 tests (21 files)
- `05_*.txt` - Overhead measurements (2 files)
- `06_*.csv` - InfluxDB exports (3 files)
- `07_*.png` - Grafana screenshots (3 files)

---

## ⚠️ **Important Notes**

1. **Always run from `scripts/` directory**
2. **Don't interrupt tests mid-run** - let them complete
3. **Keep all outputs** - even failed tests (for discussion)
4. **Check logs** after each test to verify data collected
5. **Cooldown between tests** - 30-60 seconds minimum

---

**For full command details, see:** `../ACTUAL_COMMANDS.md`
