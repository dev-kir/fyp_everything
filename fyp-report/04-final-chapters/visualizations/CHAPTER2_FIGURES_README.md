# Chapter 2 Figures - Beautiful LaTeX Diagrams & Tables

## 📊 What You Have

**File:** `chapter2_figures.tex`

**Four Professional TikZ Visualizations:**

### Figure 2.1: Reactive vs Proactive Recovery Timeline Comparison
- **Shows:** Side-by-side comparison of reactive and proactive recovery
- **Components:**
  - **Top Timeline (Reactive):**
    - Failure → Detection → 23s downtime (red zone) → Service restored
    - MTTR = 23 seconds
  - **Bottom Timeline (Proactive):**
    - Anomaly detected → Decision → Zero-downtime window (green zone) → Old container terminates
    - MTTR = 2 seconds
- **Visual Encoding:**
  - Red shaded zone = Service unavailable (downtime)
  - Green shaded zone = Both containers serving (zero downtime)
  - Color-coded phase boxes (detection, decision, active service)
- **Purpose:** Visually demonstrate SwarmGuard's 91.3% MTTR improvement

### Figure 2.2: MAPE-K Loop Applied to SwarmGuard
- **Shows:** Autonomic computing framework applied to your system
- **Components:**
  - **4 MAPE Phases:**
    - Monitor (blue) → Analyze (orange) → Plan (purple) → Execute (green)
  - **Knowledge Base (center):** InfluxDB cylinder shape
  - **Managed System:** Docker Swarm cluster at bottom
  - **Data flows:** Sensors (Monitor), Effectors (Execute)
- **Annotations:**
  - Left box: SwarmGuard components (agents.py, classifier.py, etc.)
  - Right box: Knowledge types (metrics, rules, thresholds, logs)
- **Purpose:** Position SwarmGuard within established autonomic computing theory

### Table 2.1: Docker Swarm vs Kubernetes Feature Comparison
- **Shows:** 13 features compared across both platforms
- **Key Rows:**
  - Learning curve, scalability, auto-scaling
  - **Self-healing:** Both ✅ reactive, both ❌ proactive
  - Industry adoption: Kubernetes dominates (85-90%)
- **Visual Features:**
  - Alternating row colors (light gray) for readability
  - Professional booktabs formatting
  - ✅/❌ symbols for quick scanning
- **Purpose:** Establish that neither platform has built-in proactive recovery

### Table 2.2: Comparative Analysis of Related Work
- **Shows:** 8 related systems (7 from literature + SwarmGuard)
- **Columns:** System, Platform, Recovery Type, Approach, Key Limitation, Year
- **Key Entries:**
  - Kubernetes HPA (reactive, 2019)
  - ML-based autoscaling (proactive but complex, 2023)
  - FoREST (proactive for VMs, not containers, 2023)
  - **SwarmGuard** (green highlight) - Proactive, rule-based, 2024
- **Research Gap Summary:**
  - Platform gap: Lack of Swarm-focused research
  - Complexity gap: ML approaches too heavy
  - Practicality gap: No zero-downtime demonstrations
- **Purpose:** Justify SwarmGuard's contribution to the field

---

## 🎨 Color Scheme

**Same professional palette as Chapter 3:**
- Primary Blue: RGB(41, 128, 185)
- Secondary Green: RGB(39, 174, 96)
- Accent Orange: RGB(230, 126, 34)
- Alert Red: RGB(192, 57, 43)
- Purple: RGB(142, 68, 173)
- Teal: RGB(22, 160, 133)
- Light Gray: RGB(236, 240, 241)
- Dark Gray: RGB(52, 73, 94)

---

## 🚀 How to Compile

### Option 1: Overleaf (Recommended)
1. Open your Overleaf project
2. Upload `chapter2_figures.tex`
3. Compile with pdfLaTeX
4. You'll get a 4-page PDF:
   - Page 1: Figure 2.1 (Timeline Comparison)
   - Page 2: Figure 2.2 (MAPE-K Loop)
   - Page 3: Table 2.1 (Swarm vs K8s)
   - Page 4: Table 2.2 (Related Work)

### Option 2: Local LaTeX (if you have it)
```bash
cd visualizations/
pdflatex chapter2_figures.tex
```

This generates: `chapter2_figures.pdf`

### Option 3: Online LaTeX Compiler
- Go to: https://latexbase.com or https://www.overleaf.com
- Copy-paste the content of `chapter2_figures.tex`
- Compile
- Download the PDF

---

## 📄 Using in Your Thesis

### Method 1: Include the entire PDF (easiest)
```latex
\documentclass{report}
\usepackage{pdfpages}

\begin{document}
\chapter{Literature Review}

% Your text...

% Insert Figure 2.1
\begin{figure}[H]
\centering
\includegraphics[width=\textwidth, page=1]{visualizations/chapter2_figures.pdf}
\caption{Reactive vs Proactive Recovery Timeline Comparison}
\label{fig:reactive-vs-proactive}
\end{figure}

% Your text...

% Insert Figure 2.2
\begin{figure}[H]
\centering
\includegraphics[width=0.9\textwidth, page=2]{visualizations/chapter2_figures.pdf}
\caption{MAPE-K Loop Applied to SwarmGuard}
\label{fig:mape-k}
\end{figure}

% Your text...

% Insert Table 2.1
\begin{table}[H]
\centering
\includegraphics[width=\textwidth, page=3]{visualizations/chapter2_figures.pdf}
\caption{Docker Swarm vs Kubernetes Feature Comparison}
\label{tab:swarm-vs-k8s}
\end{table}

% Your text...

% Insert Table 2.2
\begin{table}[H]
\centering
\includegraphics[width=\textwidth, page=4]{visualizations/chapter2_figures.pdf}
\caption{Comparative Analysis of Related Work}
\label{tab:related-work}
\end{table}

\end{document}
```

### Method 2: Copy TikZ code into your main document
Copy each TikZ environment directly into your thesis at the appropriate location.

**Make sure your preamble includes:**
```latex
\usepackage{tikz}
\usetikzlibrary{shapes.geometric, arrows.meta, positioning, backgrounds, shadows, patterns, decorations.pathmorphing, fit, calc}
\usepackage{xcolor}
\usepackage{booktabs}      % For professional tables
\usepackage{array}         % For table formatting
\usepackage{colortbl}      % For colored table rows
```

And copy all the color definitions and TikZ styles from the top of `chapter2_figures.tex`.

---

## 🎯 What Makes These Diagrams Beautiful

### Professional Design Elements:
- ✅ **Timeline visualization** with clear phases and time markers
- ✅ **Visual contrast** between reactive (red zone) and proactive (green zone)
- ✅ **MAPE-K circular flow** with bidirectional knowledge connections
- ✅ **Drop shadows** on boxes for depth
- ✅ **Rounded corners** for modern look
- ✅ **Consistent color scheme** across all figures
- ✅ **Clear legends** for interpretation
- ✅ **Professional typography** (sans-serif for diagrams)

### Academic Quality:
- ✅ **Theoretical grounding** (MAPE-K is established autonomic computing framework)
- ✅ **Comprehensive comparisons** (13 features in Table 2.1)
- ✅ **Literature positioning** (8 related systems in Table 2.2)
- ✅ **Publication-ready** resolution
- ✅ **Information-dense** without clutter
- ✅ **Black-and-white print friendly** (uses patterns, not just color)

---

## 📐 Diagram Specifications

### Figure 2.1 (Timeline Comparison):
- **Size:** ~14cm × 10cm
- **Timelines:** 2 (reactive top, proactive bottom)
- **Phases:** 8 total (4 per timeline)
- **Zones:** 2 shaded regions (downtime red, zero-downtime green)
- **Key Metric:** MTTR comparison (23s vs 2s)

### Figure 2.2 (MAPE-K Loop):
- **Size:** ~12cm × 14cm
- **MAPE Boxes:** 4 (Monitor, Analyze, Plan, Execute)
- **Knowledge Base:** 1 cylinder shape (center)
- **Arrows:** 12 total (4 circular flow, 8 knowledge bidirectional)
- **Annotations:** 2 info boxes (components, knowledge types)

### Table 2.1 (Swarm vs K8s):
- **Size:** ~12cm × 10cm
- **Rows:** 14 (1 header + 13 features)
- **Columns:** 3 (Feature, Docker Swarm, Kubernetes)
- **Alternating row colors** for readability

### Table 2.2 (Related Work):
- **Size:** ~14cm × 8cm
- **Rows:** 9 (1 header + 8 systems)
- **Columns:** 6 (System, Platform, Recovery Type, Approach, Limitation, Year)
- **Highlight:** SwarmGuard row in green
- **Research gap summary:** 3 bullet points below table

---

## 🔧 Customization

Want to change colors or styling? Edit these sections in `chapter2_figures.tex`:

### Change Colors:
Lines 11-20 define all colors:
```latex
\definecolor{primaryblue}{RGB}{41, 128, 185}
```

### Change Timeline Events:
For Figure 2.1, adjust time labels and box positions:
```latex
\node[below, font=\tiny\sffamily] at (4.5, 5.2) {T+5s};  % Change time
```

### Change MAPE-K Layout:
For Figure 2.2, adjust node distances:
```latex
\node[mape box, fill=primaryblue!20, above=3cm of K] (M) {...}  % Change "3cm"
```

### Add More Rows to Tables:
Add rows using standard booktabs format:
```latex
\rowcolor{lightgray}  % Optional alternating color
\textbf{New Feature} & Value 1 & Value 2 \\
```

---

## 🔍 Where to Reference These in Chapter 2

### Figure 2.1 (Timeline Comparison):
- **Section 2.3: Failure Recovery Mechanisms**
  - Subsection 2.3.1: Reactive Recovery (explain baseline approach)
  - Subsection 2.3.2: Proactive Recovery (introduce SwarmGuard approach)
  - Reference: "As shown in Figure 2.1, reactive recovery incurs 23 seconds of downtime, whereas proactive recovery achieves zero downtime by starting a new container before the old one fails."

### Figure 2.2 (MAPE-K Loop):
- **Section 2.4: Self-Healing and Autonomic Systems**
  - Subsection 2.4.1: MAPE-K Framework (explain the theory)
  - Subsection 2.4.2: Application to SwarmGuard (map your system to framework)
  - Reference: "Figure 2.2 illustrates how SwarmGuard implements the MAPE-K autonomic loop, with InfluxDB serving as the knowledge base and Docker Swarm as the managed system."

### Table 2.1 (Swarm vs K8s):
- **Section 2.2: Container Orchestration Platforms**
  - Subsection 2.2.3: Docker Swarm vs Kubernetes
  - Reference: "Table 2.1 compares Docker Swarm and Kubernetes across 13 key features. Notably, neither platform provides built-in proactive recovery, highlighting the research gap SwarmGuard addresses."

### Table 2.2 (Related Work):
- **Section 2.6: Related Work and Comparative Analysis**
  - Compare your work to 7 related systems
  - Reference: "Table 2.2 summarizes related work in proactive recovery and autonomic systems. SwarmGuard distinguishes itself by targeting Docker Swarm (an under-studied platform) and achieving zero-downtime recovery with a lightweight rule-based approach."

---

## ✅ Quality Checklist

Before using in your thesis:

- [ ] Compiled successfully in Overleaf/LaTeX
- [ ] All 4 pages (2 figures, 2 tables) visible and clear
- [ ] Timeline events align correctly
- [ ] MAPE-K arrows connect properly
- [ ] Table text is readable (not too small)
- [ ] Colors render correctly
- [ ] No overlapping text or elements
- [ ] Captions are appropriate
- [ ] Labels match cross-references in Chapter 2 text
- [ ] PDF quality is high (vector graphics, not pixelated)

---

## 💡 Integration Tips

1. **Reference figures BEFORE showing them:**
   ```latex
   As illustrated in Figure 2.1, reactive recovery...
   \begin{figure}[H]
   ... % Figure goes here
   \end{figure}
   ```

2. **Use descriptive captions:**
   ```latex
   \caption{Reactive vs Proactive Recovery Timeline Comparison. The red zone indicates 18-23 seconds of service unavailability in reactive recovery, while the green zone shows zero downtime achieved by proactive migration.}
   ```

3. **Cross-reference in text:**
   ```latex
   The MAPE-K loop (Figure \ref{fig:mape-k}) provides a theoretical foundation...
   ```

4. **Discuss tables in detail:**
   ```latex
   Table \ref{tab:swarm-vs-k8s} reveals that while Kubernetes dominates industry adoption (85-90%), Docker Swarm offers simplicity advantages...
   ```

---

## 📌 Key Insights for Literature Review

### From Figure 2.1:
- Reactive recovery is the current state-of-the-art
- Downtime is inevitable with reactive approaches
- Proactive recovery can eliminate downtime by acting before failure

### From Figure 2.2:
- SwarmGuard is grounded in established autonomic computing theory (MAPE-K)
- The system follows a closed feedback loop (monitor → analyze → plan → execute)
- Knowledge base (InfluxDB) is central to decision-making

### From Table 2.1:
- Both Docker Swarm and Kubernetes lack proactive recovery
- Swarm is simpler but less scalable than Kubernetes
- Research gap: Small-medium teams using Swarm have no proactive solution

### From Table 2.2:
- Most research focuses on Kubernetes (platform gap)
- ML-based approaches exist but are complex (complexity gap)
- No prior work demonstrates zero-downtime for Docker Swarm (novelty gap)

---

**Status:** ✅ Ready for thesis integration
**Format:** LaTeX TikZ + booktabs tables (vector graphics - infinitely scalable!)
**Quality:** Publication-ready
**Style:** Professional academic

Enjoy your beautiful Chapter 2 visualizations! 🎨📚
