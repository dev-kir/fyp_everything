# FYP Report Writing Workflow

**SwarmGuard: Proactive Recovery Mechanism for Docker Swarm**

---

## 🎯 The Complete Workflow

This structured workflow optimizes your FYP report writing by:
1. **Claude Code** generates project-specific context and commands
2. **YOU** run actual tests and collect evidence
3. **Claude Chat** does deep research and academic writing
4. **Claude Code** formats final results and figures

---

## 📁 Directory Structure

```
fyp-report/
├── 00-project-context/          # For Claude Chat to understand your project
│   ├── project_overview.md      # High-level overview
│   ├── objectives.md            # Fixed research objectives
│   └── technical_summary.md     # Architecture and implementation
│
├── 01-research-requirements/    # What papers to find
│   ├── papers_needed_ch1.md     # Chapter 1 citations (5-8 papers)
│   ├── papers_needed_ch2.md     # Chapter 2 citations (25-35 papers)
│   ├── papers_needed_ch3.md     # Chapter 3 citations (10-15 papers)
│   └── papers_needed_ch5.md     # Chapter 5 citations (5-8 papers)
│
├── 02-latex-figures/            # Diagrams and visualizations
│   └── (Generated based on your architecture)
│
├── 03-chapter4-evidence/        # Actual test results
│   ├── commands_template.md     # Commands to run
│   ├── raw_outputs/             # Paste command outputs here
│   └── analysis_notes.md        # Your analysis notes
│
├── 04-final-chapters/           # Final chapter drafts
│   ├── chapter1.md              # Introduction (5-7 pages)
│   ├── chapter2.md              # Literature Review (15-20 pages)
│   ├── chapter3.md              # Methodology (20-25 pages)
│   ├── chapter4.md              # Results (20-25 pages)
│   └── chapter5.md              # Conclusions (5-7 pages)
│
├── 05-references/               # Bibliography
│   └── references.bib           # All citations (IEEE format)
│
└── README.md                    # This file (workflow guide)
```

---

## 🚀 Step-by-Step Workflow

### Phase 1: Setup (Claude Code) ✅ DONE

**What Claude Code did:**
1. ✅ Analyzed your SwarmGuard codebase
2. ✅ Generated project context documents (00-project-context/)
3. ✅ Created research requirement lists (01-research-requirements/)
4. ✅ Generated Chapter 4 command templates (03-chapter4-evidence/)
5. ✅ Created chapter structure files (04-final-chapters/)

**You are here!**

---

### Phase 2: Chapter 4 Evidence Collection (YOU)

**Why Chapter 4 first?**
- You built SwarmGuard starting from results
- Concrete data before theoretical writing
- Evidence drives the narrative

**Steps:**

#### 2.1 Run Tests and Collect Data
```bash
cd fyp-report/03-chapter4-evidence

# Read the commands template
cat commands_template.md

# Run commands in your actual SwarmGuard environment
# (Ensure cluster is running, SwarmGuard deployed)

# Examples:
docker node ls > raw_outputs/01_cluster_nodes.txt
docker service ls > raw_outputs/02_services_status.txt
# ... (see commands_template.md for full list)
```

#### 2.2 Save All Outputs
- Save command outputs to `raw_outputs/`
- Take Grafana screenshots
- Export InfluxDB metrics to CSV
- Follow naming convention in `commands_template.md`

#### 2.3 Fill in Analysis Notes
```bash
# Edit analysis_notes.md with your observations
vi analysis_notes.md

# Calculate statistics (averages, std dev)
# Note any unexpected results
# Document limitations observed
```

**Checklist:**
- [ ] All 25 output files collected (see `raw_outputs/README.md`)
- [ ] Grafana screenshots taken (high resolution)
- [ ] InfluxDB metrics exported
- [ ] Analysis notes filled in
- [ ] Performance metrics calculated

---

### Phase 3: Research in Claude Chat

**Now that you have evidence, find literature to support it.**

#### 3.1 Start with Chapter 2 (Literature Review)

**In Claude Chat:**
1. Upload `00-project-context/project_overview.md`
2. Upload `01-research-requirements/papers_needed_ch2.md`
3. Use **Deep Research** feature:
   - Query: "proactive failure recovery distributed systems containers"
   - Query: "Docker Swarm failure detection mechanisms"
   - ... (see papers_needed_ch2.md for all queries)

4. Save research findings:
   - Paper citations (IEEE format)
   - Key findings from each paper
   - Relevance to SwarmGuard

5. **Write Chapter 2** in Claude Chat
6. Copy final version to `04-final-chapters/chapter2.md`

**Expected output:**
- 25-35 academic papers cited
- 15-20 pages of literature review
- Related work comparison table

---

#### 3.2 Write Chapter 1 (Introduction)

**In Claude Chat:**
1. Upload `00-project-context/project_overview.md`
2. Upload `00-project-context/objectives.md`
3. Upload `01-research-requirements/papers_needed_ch1.md`
4. Use Deep Research for 5-8 citations
5. Write Chapter 1
6. Copy to `04-final-chapters/chapter1.md`

**Expected output:**
- 5-7 pages
- Clear problem statement
- Fixed objectives from objectives.md
- Significance and scope

---

#### 3.3 Write Chapter 3 (Methodology)

**In Claude Chat:**
1. Upload `00-project-context/technical_summary.md`
2. Upload `01-research-requirements/papers_needed_ch3.md`
3. Read root: `FYP_2_SYSTEM_ARCHITECTURE_AND_DESIGN.txt`
4. Read root: `FYP_3_IMPLEMENTATION_DETAILS_AND_METHODOLOGY.txt`
5. Use Deep Research for 10-15 citations
6. Write Chapter 3
7. Copy to `04-final-chapters/chapter3.md`

**Expected output:**
- 20-25 pages
- Architecture diagrams (save to 02-latex-figures/)
- Algorithm pseudocode
- Design decisions justified with citations

---

#### 3.4 Write Chapter 5 (Conclusions)

**In Claude Chat:**
1. Upload completed Chapter 4 (after Phase 4)
2. Upload `00-project-context/objectives.md`
3. Upload `01-research-requirements/papers_needed_ch5.md`
4. Use Deep Research for 5-8 citations
5. Write Chapter 5
6. Copy to `04-final-chapters/chapter5.md`

**Expected output:**
- 5-7 pages
- Contributions summary
- Honest limitations
- Concrete future work (with citations)

---

### Phase 4: Chapter 4 Results (Claude Code)

**Back to Claude Code for data analysis!**

#### 4.1 Generate Initial Draft

**In Claude Code:**
```bash
# Share the collected evidence
cd fyp-report/03-chapter4-evidence

# Claude Code will:
# 1. Read all files in raw_outputs/
# 2. Parse metrics and calculate statistics
# 3. Generate tables (performance results)
# 4. Create comparison charts
# 5. Draft Results section
```

**Expected output:**
- Tables with actual performance metrics
- Graphs (MTTR comparison, latency breakdown)
- Initial draft of Chapter 4 sections

---

#### 4.2 Refine in Claude Chat

**In Claude Chat:**
1. Upload Claude Code's initial draft
2. Refine academic language
3. Add discussion and interpretation
4. Connect results to Chapter 2 literature
5. Polish final version
6. Copy to `04-final-chapters/chapter4.md`

**Expected output:**
- 20-25 pages
- Results section (objective reporting)
- Discussion section (interpretation)
- Figures and tables integrated

---

### Phase 5: Final Assembly (Claude Code)

**Combine everything into final report.**

#### 5.1 Create Figures Directory
```bash
cd fyp-report/02-latex-figures

# Organize all diagrams:
# - Architecture diagrams (from Chapter 3)
# - Flowcharts and algorithms
# - Results graphs (from Chapter 4)
# - Grafana screenshots
```

#### 5.2 Compile Bibliography
```bash
cd fyp-report/05-references

# Create references.bib with all citations
# IEEE format
# Organized by chapter
```

#### 5.3 LaTeX Compilation (if using LaTeX)
```bash
# Claude Code can help format for LaTeX
# - Convert markdown to LaTeX
# - Include figures
# - Generate table of contents
# - Compile bibliography
```

---

## 📊 Expected Page Count

| Chapter | Title | Pages | Status |
|---------|-------|-------|--------|
| 1 | Introduction | 5-7 | 🚧 To write |
| 2 | Literature Review | 15-20 | 🚧 To write |
| 3 | Methodology | 20-25 | 🚧 To write |
| 4 | Results & Discussion | 20-25 | 🚧 Evidence needed |
| 5 | Conclusions | 5-7 | 🚧 To write |
| Appendices | Code, Figures | 10-15 | 🚧 To compile |
| **Total** | | **75-99** | |

---

## ⏱️ Estimated Timeline

### Week 1: Evidence Collection
- [ ] Run all SwarmGuard tests
- [ ] Collect performance data
- [ ] Take screenshots
- [ ] Fill analysis notes

### Week 2: Research (Claude Chat)
- [ ] Deep Research for Chapter 2 (25-35 papers)
- [ ] Deep Research for Chapters 1, 3, 5 (20-30 more papers)
- [ ] Organize citations in references.bib

### Week 3-4: Writing (Claude Chat)
- [ ] Write Chapter 2 (Literature Review) - Most intensive
- [ ] Write Chapter 1 (Introduction)
- [ ] Write Chapter 3 (Methodology)

### Week 5: Results (Claude Code + Claude Chat)
- [ ] Generate Chapter 4 initial draft (Claude Code)
- [ ] Refine Chapter 4 (Claude Chat)
- [ ] Create all figures and tables

### Week 6: Conclusions and Polish
- [ ] Write Chapter 5 (Conclusions)
- [ ] Review all chapters for consistency
- [ ] Format bibliography
- [ ] Compile appendices

### Week 7: Final Review
- [ ] Proofread entire document
- [ ] Verify all citations
- [ ] Check figure/table numbering
- [ ] Get supervisor feedback
- [ ] Revise based on feedback

---

## 🔑 Key Success Factors

### 1. Use the Right Tool for the Job

**Claude Code (Project Environment):**
- ✅ Understanding your actual codebase
- ✅ Generating project-specific context
- ✅ Creating test commands
- ✅ Processing raw data
- ✅ Formatting final output

**Claude Chat (Research & Writing):**
- ✅ Deep Research for academic papers
- ✅ Understanding research concepts
- ✅ Academic writing (formal style)
- ✅ Literature synthesis
- ✅ Discussion and interpretation

### 2. Work Bottom-Up (Results First)

```
Chapter 4 (Results)     → What you achieved
    ↓
Chapter 3 (Methodology) → How you did it
    ↓
Chapter 1 (Introduction)→ Why you did it
    ↓
Chapter 2 (Lit Review)  → What others did
    ↓
Chapter 5 (Conclusions) → What it means
```

### 3. Context is King

**Always provide context to Claude Chat:**
- Upload relevant files from `00-project-context/`
- Reference research requirements from `01-research-requirements/`
- Share actual results from `03-chapter4-evidence/`

### 4. Iterate and Refine

- Don't expect perfect output on first try
- Use Claude Chat to refine academic language
- Get feedback from supervisors and peers
- Revise based on feedback

---

## 📚 Reference Materials

### In This Repository:

**Root Directory:**
- `FYP_1_PROJECT_OVERVIEW_AND_BACKGROUND.txt` - Detailed project overview
- `FYP_2_SYSTEM_ARCHITECTURE_AND_DESIGN.txt` - Architecture details
- `FYP_3_IMPLEMENTATION_DETAILS_AND_METHODOLOGY.txt` - Implementation journey
- `FYP_4_RESULTS_AND_FINDINGS.txt` - Performance results
- `FYP_5_ACADEMIC_CHAPTER_MAPPING.txt` - Writing guide

**SwarmGuard Code:**
- `swarmguard/monitoring-agent/` - Go agent implementation
- `swarmguard/recovery-manager/` - Python manager implementation
- `swarmguard/tests/` - Testing scripts
- `swarmguard/config/` - Configuration files

### External Resources:

**Academic Writing:**
- Your university's thesis guidelines
- IEEE citation style guide
- LaTeX thesis templates

**Research:**
- Google Scholar (academic papers)
- IEEE Xplore (conference papers)
- ACM Digital Library (journals)
- arXiv (preprints)

**Tools:**
- Overleaf (LaTeX editing)
- Zotero / Mendeley (citation management)
- Draw.io (diagrams)
- Matplotlib (graphs)

---

## ✅ Final Checklist

### Before Submission:

#### Content Completeness
- [ ] All 5 chapters written
- [ ] All objectives addressed (from objectives.md)
- [ ] All results presented with evidence
- [ ] All design decisions justified
- [ ] All limitations acknowledged

#### Citations and References
- [ ] 50-80 total citations (appropriate for 75-99 page thesis)
- [ ] IEEE citation format consistent
- [ ] All claims supported by citations or data
- [ ] Bibliography complete in references.bib

#### Figures and Tables
- [ ] All figures numbered and captioned
- [ ] All tables numbered and captioned
- [ ] All figures referenced in text
- [ ] High-resolution images (min 300 DPI)

#### Formatting
- [ ] Consistent heading styles
- [ ] Page numbers
- [ ] Table of contents
- [ ] List of figures
- [ ] List of tables
- [ ] Appendices organized

#### Quality
- [ ] Spell-checked
- [ ] Grammar-checked
- [ ] Consistent terminology
- [ ] Academic tone throughout
- [ ] No first-person ("I", "we")

#### Supervisor Feedback
- [ ] Draft reviewed by supervisor
- [ ] Revisions incorporated
- [ ] Final approval obtained

---

## 🆘 Troubleshooting

### Problem: Too much data, chapters too long

**Solution:**
- Move detailed results to appendices
- Summarize in main chapters
- Use tables instead of verbose text

### Problem: Not enough citations

**Solution:**
- Use Claude Chat Deep Research more extensively
- Check papers_needed_*.md for specific topics
- Ask supervisor for key papers in your field

### Problem: Chapter 4 - no evidence collected yet

**Solution:**
- Follow `03-chapter4-evidence/commands_template.md`
- Run tests in your actual environment
- Use existing data from `FYP_4_RESULTS_AND_FINDINGS.txt` as fallback

### Problem: Figures look unprofessional

**Solution:**
- Use vector graphics (SVG, EPS) not raster (PNG, JPG)
- Use consistent color schemes
- Label all axes and components
- Use tools like Draw.io, Lucidchart, or TikZ (LaTeX)

### Problem: Writing style too informal

**Solution:**
- Use Claude Chat to refine academic tone
- Read example theses from your department
- Avoid contractions, colloquialisms
- Use passive voice where appropriate

---

## 📞 Getting Help

### From Claude Code:
- Understanding your codebase
- Generating project-specific content
- Processing test results
- Formatting final output

### From Claude Chat:
- Research paper recommendations
- Academic writing refinement
- Literature review synthesis
- Discussion interpretation

### From Your Supervisor:
- Research direction
- Citation recommendations
- Chapter structure feedback
- Final review before submission

---

## 🎓 Final Words

You've built an impressive system (SwarmGuard). The hard technical work is done!

Now your job is to:
1. **Collect evidence** of what you achieved (Chapter 4)
2. **Find literature** that supports your approach (Chapter 2)
3. **Write academically** about your work (all chapters)

This workflow is designed to make the writing process systematic and efficient. Follow the phases, use the right tools, and you'll have a solid thesis.

**You've got this!** 🚀

---

**Generated by Claude Code**
**Based on actual SwarmGuard implementation**
**Last updated:** December 2024

---

## Quick Start Commands

```bash
# Phase 2: Start evidence collection
cd fyp-report/03-chapter4-evidence
cat commands_template.md

# Phase 3: Start research (in Claude Chat)
# Upload: 00-project-context/project_overview.md
# Upload: 01-research-requirements/papers_needed_ch2.md
# Use: Deep Research feature

# Phase 4: Generate results draft (Claude Code)
cd fyp-report/03-chapter4-evidence
# Share raw_outputs/ with Claude Code

# Phase 5: Final assembly
cd fyp-report/04-final-chapters
# Review all chapters
# Compile into final thesis
```

---

**Good luck with your FYP! 📚✨**
