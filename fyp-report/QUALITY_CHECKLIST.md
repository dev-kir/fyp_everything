# FYP Report Quality Checklist
## Verification Criteria for 90-130 Page Thesis

---

## 📋 PHASE 1: SETUP VERIFICATION (Claude Code)

### Folder Structure:
- [ ] `00-project-context/` exists with 4 files minimum
- [ ] `01-research-requirements/` exists with 4 files (ch1, ch2, ch3, ch5)
- [ ] `02-latex-figures/` exists with subfolders for each chapter
- [ ] `03-chapter4-evidence/` exists with commands_template.md and raw_outputs/
- [ ] `04-final-chapters/` exists with 5 chapter files
- [ ] `05-references/` exists with references.bib
- [ ] MASTER_PROMPT.md, CHAPTER_TEMPLATES.md, QUALITY_CHECKLIST.md exist

### Context Documents Quality:
- [ ] project_overview.md describes **actual project**, not generic
- [ ] technical_summary.md has **real component names** from code
- [ ] objectives.md contains **exact three fixed objectives**
- [ ] implementation_details.md references **actual files/functions**

### Research Requirements Quality:
- [ ] papers_needed_ch1.md has **specific search queries**
- [ ] papers_needed_ch2.md targets **25-35 papers**
- [ ] papers_needed_ch3.md justifies **methodology choices**
- [ ] papers_needed_ch5.md focuses on **recent trends (2023-2025)**

### Chapter 4 Commands Quality:
- [ ] commands_template.md has **actual runnable commands** (not [PLACEHOLDERS])
- [ ] Commands organized by **three objectives**
- [ ] Clear instructions for **data collection**
- [ ] Expected output formats specified

---

## 📋 PHASE 2: RESEARCH VERIFICATION (Claude Chat)

### Paper Quality (Chapter 1):
- [ ] 8-12 papers found
- [ ] All papers **2020-2025**
- [ ] All DOI/URLs **verified and accessible**
- [ ] Mix of journals and conferences
- [ ] All APA 7th format
- [ ] Relevance to problem statement clear

### Paper Quality (Chapter 2):
- [ ] 25-35 papers found
- [ ] **Balanced across themes** (monitoring, detection, recovery, context, scaling, validation)
- [ ] At least **3-5 papers per theme**
- [ ] All papers **2020-2025**
- [ ] All DOI/URLs **verified and accessible**
- [ ] **Comparative tables** possible from papers
- [ ] **Research gaps** identifiable from weaknesses

### Paper Quality (Chapter 3):
- [ ] 10-15 papers found
- [ ] Justify **methodology choices** (SDLC, tools, experimental design)
- [ ] All papers **2020-2025**
- [ ] All DOI/URLs **verified and accessible**

### Paper Quality (Chapter 5):
- [ ] 5-8 papers found
- [ ] Focus on **latest trends (2023-2025 preferred)**
- [ ] Support **future work directions**
- [ ] All DOI/URLs **verified and accessible**

### Citation Management:
- [ ] All papers saved to `references.bib`
- [ ] APA 7th format consistent
- [ ] No duplicate entries
- [ ] Author names formatted correctly

---

## 📋 PHASE 3: CHAPTER WRITING VERIFICATION (Claude Chat)

### Chapter 1 Quality (10-15 pages):
- [ ] **Background** establishes context with citations
- [ ] **Problem statement** clearly identifies gaps
- [ ] **Objectives** are the **three fixed objectives exactly**
- [ ] **Scope** clearly defines in/out of scope
- [ ] **Significance** has academic + practical contributions
- [ ] **Organization** previews rest of report
- [ ] **Formal academic tone** throughout
- [ ] **8-12 citations** properly integrated
- [ ] **Figures** referenced with placeholders

### Chapter 2 Quality (25-35 pages):
- [ ] **Introduction** previews chapter organization
- [ ] **Thematic sections** cover all required topics
- [ ] **Comparative tables** present (Table 2.1, 2.2, 2.3, **2.4 critical**)
- [ ] **Table 2.4 (Related Work)** compares existing solutions to yours
- [ ] **Critical analysis**, not just summaries
- [ ] **Synthesis** across papers, not one-by-one
- [ ] **Research gaps** clearly identified
- [ ] **Transition** to methodology clear
- [ ] **25-35 citations** properly integrated
- [ ] **Formal academic tone** throughout

### Chapter 3 Quality (20-30 pages):
- [ ] **Research methodology** justified with citations
- [ ] **System architecture** reflects **actual implementation**
- [ ] **Component descriptions** match **real code structure**
- [ ] **Technology stack** lists **actual tools used**
- [ ] **Implementation phases** describe **real development**
- [ ] **Algorithms/pseudocode** for key logic (not full code)
- [ ] **Experimental setup** describes **actual test environment**
- [ ] **Data collection methods** match **Chapter 4 commands**
- [ ] **10-15 citations** properly integrated
- [ ] **Figures** for architecture, flowcharts, algorithms
- [ ] **Formal academic tone** throughout

### Chapter 5 Quality (8-12 pages):
- [ ] **Summary** recaps problem, approach, results
- [ ] **Contributions** clearly stated (academic + practical)
- [ ] **Limitations** honestly acknowledged
- [ ] **Future work** is **specific and realistic** (not vague)
- [ ] **Future work** has **citations** supporting directions
- [ ] **Concluding remarks** tie everything together
- [ ] **5-8 citations** properly integrated
- [ ] **Formal academic tone** throughout

---

## 📋 PHASE 4: EVIDENCE COLLECTION VERIFICATION (You)

### Experimental Data Completeness:
- [ ] **All commands** from template executed
- [ ] **All outputs** saved to `raw_outputs/`
- [ ] **Timestamps** captured for all events
- [ ] **At least 10 samples** per metric (statistical validity)
- [ ] **Baseline comparison** data collected
- [ ] **CSV files** formatted correctly
- [ ] **No missing data** or incomplete tests
- [ ] **Screenshots/graphs** from monitoring tools saved

### Data Quality:
- [ ] **No hallucinated data** - all from actual tests
- [ ] **Timestamps** in consistent format (ISO 8601 recommended)
- [ ] **Metric values** reasonable (no NaN, no negative times)
- [ ] **Calculations** documented (MTTR = Recovery - Failure, etc.)
- [ ] **Outliers** identified and explained if present

---

## 📋 PHASE 5: CHAPTER 4 GENERATION VERIFICATION (Claude Code)

### Chapter 4 Content Quality (30-40 pages):
- [ ] **Introduction** previews experimental validation
- [ ] **Organized by three objectives** clearly
- [ ] **All tables** generated from **real data**
- [ ] **All graphs** generated from **real data**
- [ ] **No hallucinated numbers** - all traceable to raw_outputs/
- [ ] **Statistical analysis** included (mean, std dev, confidence)
- [ ] **MTTR results** compared to **target (< 10s)**
- [ ] **Downtime results** compared to **target (near-zero)**
- [ ] **Overhead results** quantified (CPU%, Memory%, Network)
- [ ] **Baseline comparison** included
- [ ] **Literature comparison** included
- [ ] **Discussion** interprets results, not just reports
- [ ] **Limitations** honestly discussed
- [ ] **Formal academic tone** throughout
- [ ] **5-10 citations** supporting interpretation

### Chapter 4 Figures/Tables:
- [ ] Table 4.1, 4.2, ... numbered sequentially
- [ ] Figure 4.1, 4.2, ... numbered sequentially
- [ ] **All tables have captions** above table
- [ ] **All figures have captions** below figure
- [ ] **All figures/tables referenced** in text
- [ ] **LaTeX code** for graphs provided in `02-latex-figures/chapter4/`

---

## 📋 PHASE 6: LATEX FIGURES VERIFICATION (Claude Code)

### Figure Quality:
- [ ] **All figures** based on **actual architecture** (not generic)
- [ ] **All LaTeX code compiles** without errors
- [ ] **Standalone document class** used for portability
- [ ] **TikZ diagrams** for architecture, flowcharts
- [ ] **pgfplots** for graphs and charts
- [ ] **Professional styling** (consistent colors, fonts)
- [ ] **High resolution** (300 DPI or vector)
- [ ] **Readable labels** at thesis font size
- [ ] **Compilation instructions** provided

### Figure Organization:
- [ ] `chapter1/` has intro figures
- [ ] `chapter2/` has literature comparison tables
- [ ] `chapter3/` has architecture/methodology diagrams
- [ ] `chapter4/` has results graphs/charts
- [ ] `chapter5/` has future work diagrams (if any)
- [ ] `compile_instructions.md` exists

---

## 📋 FINAL REPORT ASSEMBLY CHECKLIST

### Content Completeness:
- [ ] **All 5 chapters** written and saved
- [ ] **Chapter lengths** meet targets (10-15, 25-35, 20-30, 30-40, 8-12)
- [ ] **Total length** 90-130 pages (verify)
- [ ] **All figures** compiled and inserted
- [ ] **All tables** formatted correctly
- [ ] **All citations** in references.bib

### Formatting Consistency:
- [ ] **Heading levels** consistent (# ## ### ####)
- [ ] **Figure numbering** sequential within chapters
- [ ] **Table numbering** sequential within chapters
- [ ] **Citation format** APA 7th throughout
- [ ] **Font and spacing** consistent (if using LaTeX)

### Cross-References:
- [ ] **Chapter 1** mentions Chapters 2-5 in organization section
- [ ] **Chapter 2** references gaps filled in later chapters
- [ ] **Chapter 3** references methodology used in Chapter 4
- [ ] **Chapter 4** references objectives from Chapter 1
- [ ] **Chapter 5** summarizes findings from Chapter 4

### Bibliography:
- [ ] **50-80 total citations** (appropriate for 90-130 pages)
- [ ] **All citations appear in text**
- [ ] **All text citations appear in bibliography**
- [ ] **No orphan citations** (in bib but not cited)
- [ ] **No missing citations** (cited but not in bib)
- [ ] **APA 7th format** verified

### Academic Writing Standards:
- [ ] **Formal tone** throughout (no contractions, slang)
- [ ] **Third person / passive voice** (no "I", "we")
- [ ] **Evidence-based claims** (citation or data for every claim)
- [ ] **Clear topic sentences** for paragraphs
- [ ] **Transitions** between sections smooth
- [ ] **Grammar and spelling** checked
- [ ] **No plagiarism** (all paraphrased, cited)

---

## 📋 OBJECTIVE ACHIEVEMENT VERIFICATION

### Objective 1: Monitoring Framework
- [ ] **Chapter 3** describes monitoring design
- [ ] **Chapter 4** validates monitoring accuracy
- [ ] **Data collected** for metric collection accuracy
- [ ] **Data collected** for alert latency
- [ ] **Results show** early warning detection works

### Objective 2: Context-Aware Recovery
- [ ] **Chapter 3** describes context analysis logic
- [ ] **Chapter 3** describes two recovery strategies
- [ ] **Chapter 4** validates context decision accuracy
- [ ] **Data collected** for migration tests
- [ ] **Data collected** for autoscaling tests
- [ ] **Results show** system distinguishes scenarios

### Objective 3: Performance Validation
- [ ] **Chapter 3** describes experimental methodology
- [ ] **Chapter 4** reports MTTR measurements
- [ ] **Chapter 4** reports downtime measurements
- [ ] **Chapter 4** reports overhead measurements
- [ ] **Data collected** for all three metrics
- [ ] **Results compared to targets** (< 10s MTTR, near-zero downtime)

---

## 📋 PRE-SUBMISSION FINAL CHECKS

### Advisor Approval:
- [ ] **Draft shared** with supervisor
- [ ] **Feedback received** and incorporated
- [ ] **Final approval** obtained

### University Requirements:
- [ ] **Format** matches university thesis template
- [ ] **Page numbers** correct
- [ ] **Table of contents** generated
- [ ] **List of figures** generated
- [ ] **List of tables** generated
- [ ] **Abstract** written (if required)
- [ ] **Acknowledgments** written (if required)
- [ ] **Appendices** included (if needed)

### Final Proofread:
- [ ] **Spell check** run on all chapters
- [ ] **Grammar check** run on all chapters
- [ ] **Read-through** completed for flow
- [ ] **All TODO/PLACEHOLDER** removed
- [ ] **Consistent terminology** throughout

### File Submission:
- [ ] **PDF generated** from LaTeX or Word
- [ ] **File size** acceptable (< 50MB recommended)
- [ ] **Fonts embedded** (if PDF)
- [ ] **Hyperlinks working** (if PDF)
- [ ] **Backup copy** saved

---

## ✅ QUALITY SCORE CARD

**Excellent (90-100%):** All checklist items passed, citations verified, data complete
**Good (80-89%):** Minor formatting issues, 1-2 missing citations, data mostly complete
**Acceptable (70-79%):** Some formatting inconsistencies, some data missing
**Needs Work (< 70%):** Major gaps in content, data, or citations

**Target:** Excellent (90-100%)

---

**Use this checklist at each phase to ensure quality standards are met!**
