# 📤 Upload Guide for Claude Chat Deep Research

## 🎯 Purpose

This guide tells you **exactly which files** to upload to Claude Chat to perform deep research and find real academic papers (2020-2025) for your FYP report citations.

---

## ✅ Files to Upload (In This Order)

### **1. Context Files** (Give Claude background understanding)

Upload these **first** so Claude understands your project:

```
📁 00-project-context/
  ├── COMPLETE_SYSTEMS_OVERVIEW.md          ⭐ START HERE (most important!)
  ├── project_overview.md                    (backup context)
  └── objectives.md                          (3 consolidated objectives)
```

**Why**: These explain what SwarmGuard is, what problem it solves, and what papers you need.

---

### **2. Chapter Files** (Chapters needing citations)

Upload these **second** - these contain the `[NEED REAL PAPER: topic]` placeholders:

```
📁 04-final-chapters/
  ├── CHAPTER1_INTRODUCTION.md                    (~20 citations needed)
  ├── CHAPTER2_LITERATURE_REVIEW_ENHANCED.md      (~60 citations needed)
  └── CHAPTER5_CONCLUSION_ENHANCED.md             (~22 citations needed)
```

**Note**: Chapter 3 (Methodology) and Chapter 4 (Results) don't need many citations - they're mostly self-referential.

---

### **3. Results Summary** (For Chapter 5 context)

Upload this **third** so Claude understands your performance results:

```
📁 04-final-chapters/
  └── CHAPTER4_FINAL_COMPLETE.md                  (first 150 lines are enough)
```

**Why**: Chapter 5 discusses findings, so Claude needs to know your actual results.

---

## 📋 Upload Checklist

Copy this list to check off as you upload:

- [ ] `00-project-context/COMPLETE_SYSTEMS_OVERVIEW.md` ⭐ **START HERE**
- [ ] `00-project-context/project_overview.md`
- [ ] `00-project-context/objectives.md`
- [ ] `04-final-chapters/CHAPTER1_INTRODUCTION.md`
- [ ] `04-final-chapters/CHAPTER2_LITERATURE_REVIEW_ENHANCED.md`
- [ ] `04-final-chapters/CHAPTER5_CONCLUSION_ENHANCED.md`
- [ ] `04-final-chapters/CHAPTER4_FINAL_COMPLETE.md` (first 150 lines)

**Total**: 7 files

---

## 🔍 How to Use Claude Chat for Deep Research

### Step 1: Upload Files

1. Go to **Claude Chat** (chat.claude.ai or your preferred interface)
2. **Attach files** using the paperclip icon
3. Upload all 7 files listed above

### Step 2: Give Claude Instructions

**Copy-paste this prompt** into Claude Chat:

```
I need you to perform DEEP RESEARCH to find real academic papers (2020-2025)
for my Final Year Project thesis on SwarmGuard (proactive container recovery
for Docker Swarm).

I've uploaded:
- COMPLETE_SYSTEMS_OVERVIEW.md (project context + search queries)
- Chapter 1, 2, 5 markdown files (with [NEED REAL PAPER: topic] placeholders)

TASK:
1. Read COMPLETE_SYSTEMS_OVERVIEW.md section "Deep Research Queries"
2. For EACH query, use your Deep Research feature to find 2-3 papers
3. For EACH paper found:
   ✅ Verify published 2020-2025 (within 5 years)
   ✅ Verify peer-reviewed (IEEE, ACM, Springer, Elsevier, arXiv)
   ✅ Verify DOI or accessible URL exists
   ✅ Format in APA 7th Edition
   ✅ Provide brief 1-2 sentence summary of relevance

OUTPUT FORMAT for each paper:

**Citation**:
Author, A. A., & Author, B. B. (2023). Paper title. Conference/Journal,
volume(issue), pages. https://doi.org/xxx

**Relevance**:
[1-2 sentences explaining how this paper relates to SwarmGuard's topic]

**Where to cite in thesis**:
Chapter X, Section Y.Z (e.g., "Chapter 2, Section 2.4.1")

---

START with Chapter 1 citations, then Chapter 2, then Chapter 5.
Prioritize the most cited/recent papers from top-tier venues (IEEE, ACM).
```

### Step 3: Process Claude's Results

Claude will give you papers like this:

```
EXAMPLE OUTPUT FROM CLAUDE:

**Topic**: "Docker Swarm vs Kubernetes market share SME"

**Citation**:
Pahl, C., Brogi, A., Soldani, J., & Jamshidi, P. (2022). Cloud container
technologies: A state-of-the-art review. IEEE Transactions on Cloud Computing,
10(3), 1435-1452. https://doi.org/10.1109/TCC.2020.2989103

**Relevance**:
Compares Docker Swarm and Kubernetes adoption patterns across enterprise
segments, specifically highlighting Docker Swarm's 10% market share in SME
contexts due to lower complexity.

**Where to cite**:
Chapter 1, Section 1.2 (Problem Statement - when discussing Docker Swarm
adoption)
```

**You then**:
1. Open the chapter markdown file
2. Find `[NEED REAL PAPER: Docker Swarm vs Kubernetes market share SME, 2020-2025]`
3. Replace with: `(Pahl et al., 2022)`
4. Add full citation to References section at end of chapter

---

## 🎓 Example: Replacing Citations in Markdown

### Before:

```markdown
Docker Swarm maintains significant adoption among SMEs despite Kubernetes
dominance [NEED REAL PAPER: Docker Swarm adoption SME 2020-2025].
```

### After:

```markdown
Docker Swarm maintains significant adoption among SMEs despite Kubernetes
dominance (Pahl et al., 2022).
```

**Then add to References section at end of chapter**:

```markdown
## References

Pahl, C., Brogi, A., Soldani, J., & Jamshidi, P. (2022). Cloud container
technologies: A state-of-the-art review. IEEE Transactions on Cloud Computing,
10(3), 1435-1452. https://doi.org/10.1109/TCC.2020.2989103
```

---

## 📊 Citation Tracking

Use this table to track your progress:

| Chapter | Total Citations Needed | Citations Found | Progress |
|---------|------------------------|-----------------|----------|
| Chapter 1 | ~20 | 0 | ⬜️⬜️⬜️⬜️⬜️ 0% |
| Chapter 2 | ~60 | 0 | ⬜️⬜️⬜️⬜️⬜️ 0% |
| Chapter 5 | ~22 | 0 | ⬜️⬜️⬜️⬜️⬜️ 0% |
| **Total** | **~102** | **0** | **0%** |

Update this as you find papers!

---

## ⚠️ Common Mistakes to Avoid

### ❌ DON'T DO THIS:

1. **Don't cite papers you haven't read** - At minimum, read the abstract
2. **Don't use papers older than 2020** (unless seminal work like original Docker paper)
3. **Don't cite blog posts** (exception: official Docker/Kubernetes docs)
4. **Don't fabricate DOIs** - Every DOI must be real and accessible
5. **Don't use Wikipedia** - Use the sources Wikipedia cites instead

### ✅ DO THIS:

1. **Verify every DOI link** - Click it to make sure it works
2. **Check author names** - Ensure spelling is correct
3. **Use Google Scholar** to verify citation count (higher = more credible)
4. **Cross-reference claims** - Make sure the paper actually supports what you're saying
5. **Keep APA format consistent** - Use a citation manager (Zotero, Mendeley) if available

---

## 🔗 Useful Resources

### For Finding Papers:

- **Google Scholar**: https://scholar.google.com (filter 2020-2025)
- **IEEE Xplore**: https://ieeexplore.ieee.org
- **ACM Digital Library**: https://dl.acm.org
- **arXiv CS.DC**: https://arxiv.org/list/cs.DC/recent

### For Formatting APA Citations:

- **APA Style Guide**: https://apastyle.apa.org
- **Citation Machine**: https://citationmachine.net (set to APA 7th)
- **Zotero** (free citation manager): https://www.zotero.org

### For Verifying DOIs:

- **DOI Resolver**: https://doi.org/<DOI> (paste DOI to verify)
- Example: https://doi.org/10.1109/TCC.2020.2989103

---

## 💡 Pro Tips

### Tip 1: Start with Survey Papers

Survey papers cite MANY other papers. Find 2-3 good survey papers first:
- "Container orchestration survey 2020-2024"
- "Self-healing systems distributed computing survey"
- "Proactive fault tolerance cloud computing review"

Then mine their references for specific topics!

### Tip 2: Use Citation Chains

If you find a great paper from 2021:
1. Check papers it cites (older, foundational work)
2. Check papers that cite IT (newer, follow-up work)
3. Use Google Scholar's "Cited by" feature

### Tip 3: Prioritize Top Venues

**Tier 1** (most credible):
- IEEE Transactions on Cloud Computing
- ACM Symposium on Cloud Computing (SoCC)
- USENIX ATC
- IEEE CLOUD

**Tier 2** (still very good):
- Springer Journal of Cloud Computing
- IEEE International Conference on Autonomic Computing (ICAC)
- ACM Middleware

**Tier 3** (acceptable):
- arXiv preprints (if no journal version exists)
- Industry white papers (Docker, Kubernetes official blogs)

---

## 📝 Final Checklist Before Submission

Before you finalize your thesis:

- [ ] All `[NEED REAL PAPER: ...]` placeholders replaced
- [ ] All citations have corresponding References entries
- [ ] All DOI links verified (clicked and checked)
- [ ] APA 7th Edition format consistent throughout
- [ ] Reference lists alphabetically sorted (by first author's last name)
- [ ] No duplicate citations (same paper cited multiple times → merge)
- [ ] In-text citations match reference list (every cited paper has full reference)
- [ ] All papers published 2020-2025 (except seminal works)

---

## 🎯 Expected Timeline

**Realistic time estimate for finding all ~100 citations**:

- **Using Claude Chat Deep Research**: 4-6 hours total
  - Chapter 1 (20 citations): 1-1.5 hours
  - Chapter 2 (60 citations): 2-3 hours
  - Chapter 5 (22 citations): 1-1.5 hours

- **Manual Google Scholar search**: 10-15 hours total

**Recommendation**: Use Claude Chat Deep Research feature to save time!

---

## ❓ FAQ

**Q: Can I cite the same paper in multiple chapters?**
A: Yes! Just make sure it's relevant to each context. Add to References once per chapter.

**Q: What if a perfect paper exists but is from 2019?**
A: If it's the BEST source and nothing newer exists, cite it with justification:
"(Smith, 2019) - seminal work on [topic]"

**Q: What if I can't find a paper for a specific placeholder?**
A: Try broader search terms, check survey papers, or ask your supervisor if the claim
is necessary (maybe remove it if unsupported).

**Q: Can I cite Docker/Kubernetes official documentation?**
A: Yes, for technical specifics (API details, architecture). Format as:
```
Docker, Inc. (2024). Docker Swarm mode overview. Retrieved from
https://docs.docker.com/engine/swarm/
```

---

**Good luck with your research! 🎓**

If you get stuck, re-read `COMPLETE_SYSTEMS_OVERVIEW.md` section
"Deep Research Queries" for specific search terms to use.
