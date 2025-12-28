# Chapter 3 Figures - Beautiful LaTeX Diagrams

## 📊 What You Have

**File:** `chapter3_figures.tex`

**Three Professional TikZ Diagrams:**

### Figure 3.1: System Architecture
- **Shows:** Distributed monitoring + centralized decision-making
- **Components:**
  - 4 worker nodes (thor, loki, heimdall, freya) with monitoring agents
  - Master node (odin) with recovery manager
  - Docker Swarm orchestration layer
  - InfluxDB + Grafana observability stack
- **Data flows:** Alert arrows (red), metric arrows (green dashed), API calls (blue dotted)
- **Features:**
  - Color-coded components
  - Drop shadows for depth
  - Professional color scheme
  - Clear legend

### Figure 3.2: Zero-Downtime Migration Timeline
- **Shows:** Sequential timeline of migration process
- **Events:** T+0ms → T+8000ms
  - Alert reception
  - Constraint application
  - New task starts
  - New task healthy
  - Old task terminates
  - Migration complete
- **Highlight:** GREEN shaded "ZERO-DOWNTIME WINDOW" showing concurrent execution (4 seconds)
- **Features:**
  - Task lifecycle visualization (old task in red, new task in green)
  - Service availability indicator (always green)
  - Professional timeline with milestones

### Figure 3.3: Horizontal Scaling State Machine
- **Shows:** State transitions for auto-scaling
- **States:**
  - Normal (1 replica) - green
  - High Load Detected - orange
  - Scaled (2+ replicas) - blue
  - Load Decreased - orange
  - Cooldown Period (180s) - purple
- **Transitions:** With conditions labeled
- **Features:**
  - Circular states with drop shadows
  - Self-loops for steady states
  - Thick green arrow for scale-up
  - Thick red arrow for scale-down
  - Annotation boxes for key insights
  - Professional legend

---

## 🎨 Color Scheme

**Professional & Modern:**
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

### Option 1: Overleaf (Easiest)
1. Open your Overleaf project
2. Upload `chapter3_figures.tex`
3. Compile with pdfLaTeX
4. You'll get a 3-page PDF with all 3 figures

### Option 2: Local LaTeX (if you have it)
```bash
cd visualizations/
pdflatex chapter3_figures.tex
```

This generates: `chapter3_figures.pdf`

### Option 3: Online LaTeX Compiler
- Go to: https://latexbase.com or https://www.overleaf.com
- Copy-paste the content of `chapter3_figures.tex`
- Compile
- Download the PDF

---

## 📄 Using in Your Thesis

### Method 1: Include the entire PDF
```latex
\documentclass{report}
\usepackage{pdfpages}

\begin{document}
\chapter{Methodology}

% Your text...

% Insert Figure 3.1
\includepdf[pages=1, pagecommand={\thispagestyle{plain}}]{visualizations/chapter3_figures.pdf}

% Your text...

% Insert Figure 3.2
\includepdf[pages=2, pagecommand={\thispagestyle{plain}}]{visualizations/chapter3_figures.pdf}

% Your text...

% Insert Figure 3.3
\includepdf[pages=3, pagecommand={\thispagestyle{plain}}]{visualizations/chapter3_figures.pdf}

\end{document}
```

### Method 2: Copy TikZ code into your main document
Copy each TikZ environment (the code between `\begin{tikzpicture}` and `\end{tikzpicture}`) directly into your thesis at the appropriate location.

**Make sure your preamble includes:**
```latex
\usepackage{tikz}
\usetikzlibrary{shapes.geometric, arrows.meta, positioning, backgrounds, shadows, patterns, decorations.pathmorphing, fit, calc}
\usepackage{xcolor}
```

And copy all the color definitions and TikZ styles from the top of `chapter3_figures.tex`.

---

## 🎯 What Makes These Diagrams Beautiful

### Professional Design Elements:
- ✅ **Drop shadows** on important elements for depth
- ✅ **Rounded corners** for modern look
- ✅ **Consistent color scheme** throughout
- ✅ **Clear visual hierarchy** (bold titles, clear labels)
- ✅ **Appropriate arrow styles** (solid, dashed, dotted) for different data types
- ✅ **Annotations and legends** for clarity
- ✅ **Professional typography** (sans-serif for diagrams)

### Academic Quality:
- ✅ **Publication-ready** resolution
- ✅ **Clear captions** included
- ✅ **Proper labeling** for cross-referencing
- ✅ **Information-dense** without being cluttered
- ✅ **Black-and-white print friendly** (uses patterns and line styles, not just color)

---

## 📐 Diagram Specifications

### Figure 3.1 (System Architecture):
- **Size:** ~15cm × 12cm
- **Nodes:** 13 total (4 workers, 1 master, components, databases)
- **Arrows:** 15+ showing data flows
- **Complexity:** High (full system overview)

### Figure 3.2 (Migration Timeline):
- **Size:** ~14cm × 10cm
- **Events:** 6 milestones
- **Timeline:** 8 seconds
- **Highlight:** Zero-downtime window emphasized

### Figure 3.3 (State Machine):
- **Size:** ~12cm × 12cm
- **States:** 5 distinct states
- **Transitions:** 8 transitions (including self-loops)
- **Annotations:** 3 info boxes

---

## 🔧 Customization

Want to change colors or styling? Edit these sections in `chapter3_figures.tex`:

### Change Colors:
Lines 11-18 define all colors:
```latex
\definecolor{primaryblue}{RGB}{41, 128, 185}
```

### Change Node Styles:
Lines 21-82 define TikZ styles:
```latex
node box/.style={...}
worker node/.style={...}
```

### Adjust Sizes:
In each tikzpicture environment, change:
```latex
node distance=1.5cm and 2cm  % Spacing between nodes
minimum width=3cm            % Node width
```

---

## ✅ Quality Checklist

Before using in your thesis:

- [ ] Compiled successfully in Overleaf/LaTeX
- [ ] All 3 figures visible and clear
- [ ] Colors render correctly
- [ ] Text is readable (not too small)
- [ ] Arrows point to correct targets
- [ ] Captions are appropriate
- [ ] Labels match cross-references in Chapter 3 text
- [ ] PDF quality is high (not pixelated)

---

**Status:** ✅ Ready for thesis integration
**Format:** LaTeX TikZ (vector graphics - infinitely scalable!)
**Quality:** Publication-ready
**Style:** Professional academic

Enjoy your beautiful diagrams! 🎨
