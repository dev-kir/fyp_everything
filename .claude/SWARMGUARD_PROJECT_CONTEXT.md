# SwarmGuard FYP Project - Context for Claude Code

**Auto-loaded by Claude Code for persistent context across sessions**

---

## 🎯 Quick Project Summary

**Project**: SwarmGuard - Proactive Recovery for Docker Swarm Containers
**Type**: Final Year Project (FYP) / Undergraduate Thesis
**Status**: ✅ All chapters complete, awaiting citation research

---

## 📊 Current Project State

### Completed Work
- ✅ All 5 chapters written (~45,100 words total)
- ✅ 46 visual elements (14 ASCII diagrams + 32 figure descriptions)
- ✅ 3 consolidated research objectives (as specified by lecturer)
- ✅ 4 research questions with detailed answers
- ✅ Comprehensive experimental results (91.3% MTTR improvement)

### Pending Work
- 🔄 ~102 citation placeholders need real papers (2020-2025)
- 🔄 17 diagrams need to be created from descriptions (draw.io)
- 🔄 Format conversion (markdown → LaTeX/Word/PDF)

---

## 🗂️ File Organization

### Key Directories

```
fyp_everything/
├── fyp-report/                          # Main thesis content
│   ├── 00-project-context/              # Project overview & objectives
│   │   ├── COMPLETE_SYSTEMS_OVERVIEW.md ⭐ Most comprehensive context
│   │   ├── project_overview.md
│   │   └── objectives.md
│   │
│   ├── 04-final-chapters/               # All 5 chapters (COMPLETE)
│   │   ├── CHAPTER1_INTRODUCTION.md                    (6,800 words)
│   │   ├── CHAPTER2_LITERATURE_REVIEW_ENHANCED.md     (12,500 words)
│   │   ├── CHAPTER3_METHODOLOGY_COMPLETE.md           (8,300 words)
│   │   ├── CHAPTER4_ENHANCED_WITH_VISUAL_DESCRIPTIONS.md (~10,000 words)
│   │   └── CHAPTER5_CONCLUSION_ENHANCED.md            (7,500 words)
│   │
│   ├── PROJECT_COMPLETION_SUMMARY.md    # Overall status
│   └── UPLOAD_TO_CLAUDE_CHAT_GUIDE.md   # Guide for citation research
│
└── swarmguard/                          # Actual implementation code
    ├── monitoring-agent/                # Go/Python monitoring agents
    ├── recovery-manager/                # Python recovery manager
    ├── web-stress/                      # Node.js test application
    └── tests/                           # Test scripts
```

---

## 🔑 Key Technical Details (For Future Reference)

### System Architecture
- **5-node Docker Swarm cluster**: odin (master) + thor, loki, heimdall, freya (workers)
- **Monitoring agents**: Run on each worker, collect CPU/memory/network every 3-5s
- **Recovery manager**: Centralized decision-maker on master node
- **Communication**: Event-driven HTTP alerts + batched InfluxDB metrics

### Performance Results
- **MTTR Baseline**: 23.10s (Docker Swarm reactive recovery)
- **MTTR SwarmGuard**: 2.00s (91.3% improvement)
- **Zero-downtime rate**: 70% (7 out of 10 tests)
- **Overhead**: <2% CPU, ~50MB memory, <0.5 Mbps network

### Two Recovery Scenarios
1. **Scenario 1 (Migration)**: High CPU/Mem + Low Network → Migrate to healthy node
2. **Scenario 2 (Scaling)**: High CPU/Mem + High Network → Scale replicas

---

## 🎓 Academic Requirements

### Research Objectives (3 consolidated - as specified by lecturer)
1. Design and implement proactive monitoring + decision engine
2. Achieve zero-downtime recovery through migration and scaling
3. Validate performance improvements through empirical evaluation

### Research Questions (4)
1. Can proactive recovery reduce MTTR? → **YES, 91.3% reduction**
2. Can zero-downtime migration be achieved? → **YES, 70% success rate**
3. What is system overhead? → **<2% CPU, ~50MB memory**
4. Can rule-based classification work? → **YES, 100% accuracy**

### Citation Requirements
- **Format**: APA 7th Edition (NOT IEEE)
- **Publication years**: 2020-2025 (within 5 years)
- **Total needed**: ~102 papers across Chapters 1, 2, 5
- **Venues**: IEEE, ACM, Springer, Elsevier, arXiv (peer-reviewed only)

---

## 💡 Common Tasks You Might Help With

### If User Asks to Edit Chapters
- All chapters in `fyp-report/04-final-chapters/`
- Use `Edit` tool to modify existing markdown
- Preserve existing structure and citations
- Maintain APA 7th Edition format

### If User Asks About Citations
- See `fyp-report/00-project-context/COMPLETE_SYSTEMS_OVERVIEW.md` section "Deep Research Queries"
- User should use Claude Chat (not Claude Code) for deep research
- Claude Code can help format found citations in APA 7th Edition

### If User Asks to Create Diagrams
- Chapter 2 needs 14 ASCII diagrams converted to images
- Chapter 3 needs 3 diagrams (architecture, timeline, state machine)
- Suggest draw.io, Lucidchart, or Python matplotlib
- Can generate PlantUML or Mermaid code for diagram-as-code

### If User Asks About Implementation Code
- SwarmGuard code in `swarmguard/` directory
- Monitoring agent: `swarmguard/monitoring-agent/agent.py`
- Recovery manager: `swarmguard/recovery-manager/manager.py`
- Test app: `swarmguard/web-stress/app.js`

---

## 🚫 What NOT to Change

### Don't Modify Without Explicit Request
- ❌ The 3 consolidated objectives (user's lecturer specified exactly 3)
- ❌ APA 7th Edition citation format (user explicitly requested this over IEEE)
- ❌ Word counts (user said "IT'S OKEY TO BE LONG, I DON'T CARE")
- ❌ Chapter structure (matches lecturer's hierarchical example)

### User Preferences (From Previous Conversations)
- ✅ Wants "a lot of diagrams" for "easier, interactive, interesting understanding"
- ✅ Prefers detailed explanations with layman's terms
- ✅ Needs deep hierarchical structure (2.1.1, 2.2.1, etc.)
- ✅ Papers MUST be 2020-2025 with accessible DOI/URLs
- ❌ NO emojis in report chapters (only in guides/summaries)
- ❌ NO heatmaps (user specifically said "no need heatmap ig")

---

## 📚 Quick Reference Links

### For User's Next Steps
1. **Citation Research**: Upload files to Claude Chat (see `UPLOAD_TO_CLAUDE_CHAT_GUIDE.md`)
2. **Diagram Creation**: Use `fyp-report/04-final-chapters/` ASCII descriptions
3. **Format Conversion**: Use Pandoc (markdown → LaTeX/Word/PDF)

### Key Files to Reference
- **Most comprehensive overview**: `fyp-report/00-project-context/COMPLETE_SYSTEMS_OVERVIEW.md`
- **Completion status**: `fyp-report/PROJECT_COMPLETION_SUMMARY.md`
- **Upload guide**: `fyp-report/UPLOAD_TO_CLAUDE_CHAT_GUIDE.md`

---

## 🔄 Session Continuation Tips

### If User Returns After Long Break
1. Read this file first for context
2. Check `PROJECT_COMPLETION_SUMMARY.md` for latest status
3. Ask user: "What do you need help with today?"
   - Citation formatting?
   - Chapter editing?
   - Diagram generation?
   - Code explanation?

### If User Asks "Where Were We?"
- **Writing**: ✅ DONE - All 5 chapters complete
- **Citations**: 🔄 TODO - ~102 papers needed (use Claude Chat, not Claude Code)
- **Diagrams**: 🔄 TODO - 17 diagrams to create
- **Formatting**: 🔄 TODO - Convert markdown to submission format

---

## 📞 User's Typical Communication Style

- Uses lowercase, informal ("okey", "ig" = "I guess")
- Asks for clarification when confused
- Appreciates visual explanations
- Wants things done thoroughly ("all by claude" in git commits)
- Values detailed, comprehensive work

---

**Last Updated**: December 26, 2024
**Project Phase**: Citation research + diagram creation
**Next Session Goal**: Help user format citations or generate diagrams as needed

---

*This file is auto-loaded by Claude Code to maintain context across sessions.*
*Update this file if project status changes significantly.*
