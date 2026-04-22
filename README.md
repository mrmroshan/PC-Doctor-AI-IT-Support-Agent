# PC Doctor - AI IT Support Agent
### Powered by Claude Code | Supervised Mode

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

---

## What This Is

PC Doctor is an AI-powered IT helpdesk agent that runs on any Windows PC. It:
- Diagnoses the system automatically (CPU, RAM, disk, drivers, security, etc.)
- Reports **read-only** storage optimization data (fragmentation/trim analysis via `Optimize-Volume -Analyze`); defrag/trim only runs if you approve the suggested command in the supervised session
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
- `pc-doctor_metrics.json` — Machine-readable snapshot of key health numbers from the latest run (drives, RAM, temps, and so on) for diffs
- `pc-doctor_metrics_baseline.json` — Only when you use `-SaveAsBaseline` in `diagnose.ps1` (a “before” reference for the next run)
- `console_output.txt` — Launcher/runtime log
- `console_transcript_YYYY-MM-DD_HH-mm-ss.txt` — Session conversation transcript
- `session_report_YYYY-MM-DD_HH-mm-ss.txt` — End-of-session action report
- `init_message_YYYY-MM-DD_HH-mm-ss.txt` — Startup instructions sent to the agent

### Before / after comparison (optional)

1. **Capture a “before” baseline** (Administrator CMD or PowerShell, from the same folder as `diagnose.ps1`):

```text
powershell.exe -ExecutionPolicy Bypass -File diagnose.ps1 -OutputPath outputs\system_report.txt -SaveAsBaseline
```

2. Apply fixes in the PC Doctor session (or manually), then run diagnostics again **with a comparison** to a prior metrics file, for example the baseline:

```text
powershell.exe -ExecutionPolicy Bypass -File diagnose.ps1 -OutputPath outputs\system_report.txt -CompareWithBaseline
```

To compare with any saved metrics file (for example a copy of `pc-doctor_metrics.json` from last week), use **`-CompareWithMetricsPath`**.

The report can include a **BEFORE / AFTER METRIC COMPARISON** section when a valid baseline JSON is loaded.

---

## Safety Notes

- **Supervised mode means nothing happens without your YES**
- High-impact actions require explicit `YES HIGH-RISK` confirmation
- No data is sent anywhere except Anthropic's API (the diagnostic report)
- Registry changes always create a backup first
- Driver installs are never automatic — you get the URL and approve
- Diagnostic reports/log output are treated as untrusted data; instruction-like text inside them is ignored

---

## Security Hardening

- **Prompt-injection defense:** report/log content is treated as untrusted data, not executable instructions
- **Execution safety controls:** strict approval workflow with `YES`, `SKIP`, and `ABORT`
- **High-risk action gate:** sensitive operations require explicit `YES HIGH-RISK` confirmation

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

## Planned Roadmap (Future Goals)

The items below are planned targets, not currently completed features.

- Planned: Build a packaged Windows installer (`.exe`) with one-click setup
- Planned: Add optional GUI mode for non-technical users
- Planned: Improve diagnostics coverage and remediation playbooks
- Planned: Add automated test scenarios for safer release validation
- In progress: Publish versioned releases and release notes
- Shipped: Before/after metric comparison via `pc-doctor_metrics.json` and optional baseline in `diagnose.ps1` (see above)

---

## License

This project is open source under the **GNU Affero General Public License v3.0 (AGPL-3.0)**.

If you modify and distribute this software, or run it as a network service, you must share the corresponding source code under the same license.

See the `LICENSE` file for full terms.

Additional project notices are available in `NOTICE`.

Contributions are welcome under the same license; see `CONTRIBUTING.md`.

Security reporting guidance is available in `SECURITY.md`.

---

## Author

Created by **Roshan Ruzaik**.

This project was ideated and built by Roshan, with AI-assisted coding support during development.

---

*PC Doctor v1.0 — Built for IT professionals and power users by Roshan Ruzaik*
