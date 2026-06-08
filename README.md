# Paper Reader Workflow

[中文文档](README_CN.md)

AI-assisted deep reading and knowledge management framework for electrocatalysis and computational electrochemistry research papers.

Built on top of AI coding assistants (Claude Code / Codex), this framework provides structured workflows for:

- **Deep reading**: 10-section analysis covering research questions, methods, key results, mechanisms, innovations, limitations, and transferable knowledge
- **Batch ingestion**: Multi-agent parallel processing for bulk paper import into a structured knowledge base
- **Knowledge base**: Schema-validated storage with automatic source tracking (Fig./Table/Section granularity)
- **Wiki layer**: Obsidian-compatible concept pages derived from KB data with full traceability
- **Audit gates**: Automated quality control with cryptographic tree-hash receipts and independent reviewer checks
- **Paper fetching**: Multi-source academic search tool (Google Scholar, Web of Science, Scopus, CNKI)

## Research-domain agnostic

The framework ships with **electrocatalysis as a built-in example**, but works for **any research field** — lithium batteries, photocatalysis, organic synthesis, biomedicine, materials science, etc.

**One command to configure:** Open this repo with Claude Code or Codex and say:

> "I work on lithium-ion batteries and solid-state electrolytes."

The AI reads `CONFIGURE.md`, finds all domain-specific markers (`<!-- DOMAIN:XXX -->`), and replaces example terms with your field's terminology — sub-domains, performance metrics, characterization techniques, deep-dive modules, and reference data.

**Zero manual edits. 3 seconds. Done.**

See `CONFIGURE.md` for the full list of markers and replacement rules.

## Prerequisites

- [Claude Code](https://claude.ai/code) or [Codex](https://codex.ai) (or any AI coding assistant that reads `CLAUDE.md` / `AGENTS.md` as project instructions)
- Windows (native), macOS/Linux (requires PowerShell Core for audit gate scripts)
- `pdftotext` (for batch text extraction; optional if your AI has native PDF support)

## Quick start

```bash
git clone https://github.com/YOUR_USERNAME/paper-reader-workflow.git
cd paper-reader-workflow
```

Then open this directory with Claude Code or Codex. The AI will automatically read `CLAUDE.md` and understand the workflows.

### First use

1. **Read a paper**: Drop a PDF in the project folder and say "精读这篇论文" (deep-read this paper)
2. **Ingest to KB**: After reading, say "入库这篇论文" (ingest this paper to KB)
3. **Export notes**: Say "导出笔记" (export notes) to generate a Markdown + PDF

### One-command domain setup

No manual editing. Say "I work on XXX direction" and the AI auto-configures routing examples, sub-domain modules, and reference data for your field. See `CONFIGURE.md` for details.

## Combined use with computer-kb-workflow

For computational software knowledge management (DFT/MD/MLFF parameters, error troubleshooting, workflow design), install the companion repo:

```bash
git clone https://github.com/YOUR_USERNAME/computer-kb-workflow.git
cp -r computer-kb-workflow/computer_kb/ ./computer_kb/
```

Then merge the `.claude/settings.json` hooks and restore the full routing table in `CLAUDE.md`. See `SETUP.md` for detailed instructions.

## Directory structure

```
├── CLAUDE.md              # Project instructions + routing rules (Claude Code entry)
├── AGENTS.md              # Codex entry adapter
├── md2pdf.ps1             # PDF export script
├── pdf_style.css           # PDF styling
├── docs/paper-reader/     # Workflow protocols
│   ├── READING.md          #   10-section deep reading protocol
│   ├── BATCH.md            #   Batch ingestion scheduling
│   ├── EXPORT.md           #   Note export protocol
│   ├── GATES.md            #   Audit gate mechanism
│   ├── WIKI_SYNC.md        #   KB-to-wiki sync rules
│   └── ORIGIN_XRD.md       #   XRD graph automation
├── kb/                    # Paper knowledge base (framework only)
│   ├── INDEX.md            #   Routing index + module summary
│   ├── SCHEMA.md           #   Schema v1 field contract
│   ├── REVIEWER.md         #   Review protocol
│   └── reference/          #   Public reference data (Raman/IR/XPS)
├── wiki/                  # Wiki display layer (skeleton)
├── paper-fetcher/         # Multi-source academic search tool
└── .claude/               # Claude Code integration
    ├── settings.json       #   Stop hook registration
    ├── hooks/              #   Audit gate PowerShell scripts
    ├── agents/             #   Independent reviewer agent
    ├── scripts/            #   Receipt generation
    ├── skills/             #   General-purpose workflow skills
    └── commands/opsx/      #   OpenSpec commands
```

## License

MIT
