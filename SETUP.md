# SETUP · Environment Guide

## Claude Code (Windows) — 开箱即用

Clone the repo and start using. Audit gates auto-register via `.claude/settings.json`.

The gate scripts use `${CLAUDE_PROJECT_DIR}` (built-in) and `$PSScriptRoot` (PowerShell) for all paths. No manual configuration needed.

## Claude Code (macOS / Linux)

Install [PowerShell Core](https://learn.microsoft.com/powershell/scripting/install/installing-powershell):

```bash
# macOS
brew install powershell/tap/powershell

# Linux (Ubuntu)
sudo apt install powershell
```

Then edit `.claude/settings.json` — change `powershell.exe` to `pwsh` in hook commands.

## Codex

`AGENTS.md` serves as the Codex entry adapter. The core workflows (deep reading, batch ingestion, KB management) work identically.

**Audit gates**: Codex does not have the Claude Code hook system. Instead, manually run quality checks after modifying KB/wiki files:

1. Self-review against `kb/REVIEWER.md`'s checklist
2. Run receipt generation: `powershell .claude/scripts/New-AuditReceipt.ps1`
3. Append reviewer summary to `kb/REVIEWER_LOG.md`

## Combined setup with computer-kb-workflow

If you also need computational software knowledge management:

```bash
# 1. Clone companion repo
git clone https://github.com/YOUR_USERNAME/computer-kb-workflow.git

# 2. Merge computer_kb/ into this project
cp -r computer-kb-workflow/computer_kb/ ./computer_kb/

# 3. Merge settings.json hooks (add computer_kb_review_gate)
#    Or copy from computer-kb-workflow/.claude/settings.json

# 4. Merge CLAUDE.md routing tables
#    Or use the full CLAUDE.md from your original project
```

The two gate systems run independently — a pass on one does not pass the other.
