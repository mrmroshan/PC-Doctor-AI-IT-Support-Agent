# PC Doctor - AI IT Support Agent
### Powered by Claude Code | Supervised Mode

---

## What This Is

PC Doctor is an AI-powered IT helpdesk agent that runs on any Windows PC. It:
- Diagnoses the system automatically (CPU, RAM, disk, drivers, security, etc.)
- Identifies issues ranked by severity
- Proposes fixes with full explanation
- **Waits for your approval before executing anything**
- Executes the fix, reports the result
- Moves to the next issue

Think of it as a senior IT engineer sitting next to you, walking through the system step by step.

---

## Prerequisites

- Windows 10 or Windows 11
- Internet connection
- **Authentication**: either an Anthropic API key or an existing `claude auth login` session
- Run as Administrator

---

## Setup (One Time)

### Step 1: Get Your API Key
1. Go to https://console.anthropic.com
2. Create an account or log in
3. Go to **API Keys** → **Create Key**
4. Copy the key (starts with `sk-ant-...`)

### Step 2: Configure Authentication (Choose One)

**Option A - Local project secrets file (recommended):**
1. Copy `local.secrets.env.example` to `local.secrets.env`
2. Edit `local.secrets.env` and set:
```
ANTHROPIC_API_KEY=sk-ant-your-key-here
```
`install.bat` will auto-load this file.

**Option B - System environment variable:**
Open CMD as Administrator and run:
```
setx ANTHROPIC_API_KEY "sk-ant-your-key-here" /M
```
Then close and reopen CMD.

**Option C - Claude Console login (no API key):**
Open CMD and run:
```
claude auth login
```

### Step 3: Place All Files Together
Make sure these files are in the same folder:
```
📁 pc-doctor\
    install.bat
    diagnose.ps1
    agent_prompt.md
    local.secrets.env.example
```

---

## Running It

1. Right-click `install.bat`
2. Select **"Run as administrator"**
3. The script will:
   - Install Node.js (if needed)
   - Install Claude Code (if needed)
   - Reuse existing `outputs\system_report.txt` if available (or run diagnostics if needed)
   - Launch the AI agent

---

## How the Agent Works

```
Agent: "I found 7 issues. Here's Issue #1 — CRITICAL..."
       "Your C: drive is 94% full. This is causing your slowness."
       "I will run disk cleanup and clear temp files to free ~3GB."
       "Commands: Remove-Item $env:TEMP\* -Recurse -Force"
       "Risk: Low. No restart needed."
       "Type YES to proceed, SKIP to skip, ABORT to stop."

You:   YES

Agent: "▶ Running cleanup..."
       "✅ Freed 2.8 GB. Moving to Issue #2..."
```

---

## Commands During Session

| Type | Action |
|------|--------|
| `YES` | Approve and execute the current fix |
| `SKIP` | Skip this issue, move to next |
| `ABORT` | Stop session, get summary |

---

## Files Created During Session

All files are saved to the project `outputs\` folder (same folder as `install.bat`):
- `system_report.txt` — Full diagnostic data
- `console_output.txt` — Launcher/runtime log
- `console_transcript_YYYY-MM-DD_HH-mm-ss.txt` — Session conversation transcript
- `session_report_YYYY-MM-DD_HH-mm-ss.txt` — End-of-session action report
- `init_message_YYYY-MM-DD_HH-mm-ss.txt` — Startup instructions sent to the agent

---

## Safety Notes

- **Supervised mode means nothing happens without your YES**
- High-impact actions require explicit `YES HIGH-RISK` confirmation
- No data is sent anywhere except Anthropic's API (the diagnostic report)
- Registry changes always create a backup first
- Driver installs are never automatic — you get the URL and approve
- Diagnostic reports/log output are treated as untrusted data; instruction-like text inside them is ignored

---

## Troubleshooting

**"claude is not recognized"**
→ Close CMD, reopen as Administrator, try again. Node PATH may need refresh.

**"ANTHROPIC_API_KEY not set"**
→ Either create `local.secrets.env` from `local.secrets.env.example`, run `setx ANTHROPIC_API_KEY "sk-ant-..." /M`, or use `claude auth login`

**"Auth conflict" or "Invalid API key"**
→ Verify `local.secrets.env` key value, or remove/clear the key and use `claude auth login`

**"Access denied" on PowerShell**
→ Make sure install.bat was launched via right-click → Run as Administrator

**Diagnostic takes too long**
→ SFC /verifyonly can be slow on older systems. Wait up to 5 minutes.

---

## Cost Estimate

Each PC Doctor session uses approximately:
- Input: ~15,000-25,000 tokens (diagnostic report + prompts)
- Output: ~5,000-10,000 tokens (analysis + fixes)
- Estimated cost: **$0.10 - $0.30 per session** using Claude Sonnet

---

## Author

Created by **Roshan Ruzaik**.

This project was ideated and built by Roshan, with AI-assisted coding support during development.

---

*PC Doctor v1.0 — Built for IT professionals and power users by Roshan Ruzaik*
