# PC Doctor - AI IT Support Agent
### Powered by Claude Code | Supervised Mode

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

---

## What This Is

PC Doctor is an AI-powered IT helpdesk agent that runs on any Windows PC. It:
- Diagnoses the system automatically (CPU, RAM, disk, drivers, security, **network path tests**, **printers & spooler**, etc.)
- **Writes a metrics snapshot** (`pc-doctor_metrics.json`) every diagnostic run, with optional **before/after** comparison (baseline + compare flags on `diagnose.ps1` — see [Files created → Before / after](#files-created-during-session)); JSON includes **`network`** and **`printers`** summary objects when the collector runs those sections
- Reports **read-only** storage optimization data (fragmentation/trim analysis via `Optimize-Volume -Analyze`); defrag/trim only runs if you approve the suggested command in the supervised session
- Identifies issues ranked by severity
- Proposes fixes with full explanation
- **Waits for your approval before executing anything**
- Executes the fix, reports the result
- Moves to the next issue

Think of it as a senior IT engineer sitting next to you, walking through the system step by step.

### Project documentation (this repo)

| File / path | Purpose |
|-------------|---------|
| `LICENSE` | AGPL-3.0 full terms |
| `NOTICE` | Copyright and attribution |
| `CONTRIBUTING.md` | How to contribute and PR expectations |
| `SECURITY.md` | How to report security issues |
| `CHANGELOG.md` | Notable changes between versions |
| `agent_prompt.md` | Agent persona and safety rules (loaded for the session) |
| `.cursor/skills/update-docs-on-significant-changes/SKILL.md` | Optional Cursor skill: when to update README/CHANGELOG for significant changes (helpers & maintainers) |

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
    pc_doctor_resume.cmd        (used by the post-restart hook)
    register_reboot_resume.cmd  (run before a planned restart to auto-resume)
    diagnose.ps1
    agent_prompt.md
    local.secrets.env.example
    pc-doctor-pricing.env.example   (optional; copy to pc-doctor-pricing.env for cost estimates)
    session_usage_estimate.ps1
```

---

## Running It

1. Right-click `install.bat`
2. Select **"Run as administrator"**
3. The script will:
   - Install Node.js (if needed)
   - Install Claude Code (if needed)
   - Build `outputs\system_report.txt` for **this** PC. If a previous report exists, the launcher checks that its `Hostname` line matches this computer; if not, it **regenerates** automatically. You can still choose to re-run diagnostics on the same machine (default is to **not** reuse, for safety when sharing a copy of the app).
   - Launch the AI agent

### Optional: resume after a planned restart

If a fix **requires a reboot** and you want the assistant to start again **without** manually running `install.bat` after you log back in:

1. From the same folder as `install.bat`, run **`register_reboot_resume.cmd`** (or `install.bat --register-reboot`) **before** the PC restarts. This stores a **one-time** `RunOnce` entry (current user) that launches `pc_doctor_resume.cmd` on the next logon only.
2. Restart the machine when you are ready.
3. After sign-in, a new session starts with a short countdown, a fresh `system_report.txt`, and a **`resume_bootstrap.txt`** file that points to the most recent pre-reboot session report and transcript.
4. If you **cancel** the restart, run `install.bat --clear-reboot-hook` so the automatic start does not run later by mistake.

**Note:** The hook runs **once** and only for the user who registered it. Some environments restrict `RunOnce` or non–elevated diagnostics; the first full run should still be *Run as administrator* if you rely on the full diagnostic suite. The post-restart path does **not** require admin, but may not be able to perform new global installs; if something is missing, run a full `install.bat` as administrator again.

### Portable copies and `system_report.txt`

When you **copy** or **zip** the project to another computer, do **not** rely on a bundled `outputs\` folder from another machine: the diagnostic file `outputs\system_report.txt` is specific to the PC that generated it. The launcher:

- Compares the `Hostname` line in an existing `system_report.txt` to the **current** computer name; if it does not match, it **regenerates** the report.
- If the report is for the **same** PC, it asks whether to **reuse** it; the default is **not** to reuse (type `Y` only if you want to skip a long re-collection on the same machine).

For the cleanest first run on a new device, ship or copy the app **without** the `outputs\` folder, or delete `outputs\` before first launch (it is not meant to be committed; see `.gitignore`).

### `install.bat` options (reference)

| Argument | Purpose |
|----------|--------|
| *(none)* | Full flow: admin check (unless disabled), dependencies, diagnostics, launch agent |
| `--register-reboot` | Register a **one-time** start after the next user logon (see [resume after restart](#optional-resume-after-a-planned-restart)); then exit |
| `--clear-reboot-hook` | Remove that registration if the restart was cancelled; then exit |
| `--post-restart` | Internal: used by `pc_doctor_resume.cmd` after logon; skips admin, always refreshes `system_report.txt`, resume-oriented prompt |
| `--skip-admin-check` | Skip the administrator check (e.g. debugging) |

---

## How the Agent Works

```
Agent: "I found 7 issues. Here's Issue #1 — CRITICAL..."
       "Your C: drive is 94% full. This is causing your slowness."
       "I will run disk cleanup and clear temp files to free ~3GB."
       "Commands: powershell -File ..\\Invoke-TempCleanup.ps1 -OutputDir ."
       "Risk: Low. No restart needed."
       "Type YES to proceed, SKIP to skip, ABORT to stop."

You:   YES

Agent: "▶ Running cleanup..."
       "✅ Done. See temp_cleanup_audit_<timestamp>.txt in outputs\\ (session cwd is that folder)."
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

All files are saved to the project `outputs\` folder (under the same directory as `install.bat`):
- `system_report.txt` — Full diagnostic data (used by the AI agent)
- `system_report.html` — Same report as a **navigable** single-page HTML (sidebar table of contents, section anchors, syntax highlighting for status tags). Generated beside the `.txt` unless you pass `-NoHtml` to `diagnose.ps1`
- `pc-doctor_metrics.json` — Machine-readable snapshot of key health numbers from the latest run (CPU load, memory, storage hygiene, volumes, **`network`** and **`printers`** summaries, etc.) for diffs and automation
- `pc-doctor_metrics_baseline.json` — Only when you use `-SaveAsBaseline` in `diagnose.ps1` (a “before” reference for the next run)
- `console_output.txt` — Launcher/runtime log
- `console_transcript_YYYY-MM-DD_HH-mm-ss.txt` — Session conversation **audit trail** (see **SESSION TRANSCRIPT FILE** in `agent_prompt.md`): the agent should append **verbatim** user and assistant text after each turn. Compliance is prompt-driven (not automatic TTY capture); the end-of-session report may still summarize.
- `session_report_YYYY-MM-DD_HH-mm-ss.txt` — End-of-session action report
- `init_message_YYYY-MM-DD_HH-mm-ss.txt` — Startup instructions sent to the agent
- `session_usage_estimate_YYYY-MM-DD_HH-mm-ss.txt` — **Estimated** token volume and USD range for the session (heuristic; real usage is in the Anthropic Console)
- `temp_cleanup_audit_YYYY-MM-DD_HH-mm-ss.txt` — Written when the agent runs `Invoke-TempCleanup.ps1` after you approve temp cleanup: before/after folder sizes, removed vs failed counts, sample paths that could not be deleted (e.g. in use)
- `resume_bootstrap.txt` — Only when a session is started by the post-restart hook: paths to the latest prior `session_report_*.txt` and `console_transcript_*.txt` for handoff

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

`diagnose.ps1` **parameters** (all optional except paths you care about):

| Parameter | Meaning |
|----------|--------|
| `-OutputPath` | Where to write `system_report.txt` (default: under `%TEMP%`) |
| `-SaveAsBaseline` | Also write `pc-doctor_metrics_baseline.json` next to that report |
| `-CompareWithMetricsPath` | Path to a previous `pc-doctor_metrics.json` (or copy) to diff against |
| `-CompareWithBaseline` | Shorthand: compare to `pc-doctor_metrics_baseline.json` in the same folder as `-OutputPath` |
| `-NoHtml` | Do not write `system_report.html` (text and JSON are still written) |
| `-SkipExternalNetworkProbes` | Omit public ICMP/DNS/TCP/HTTP checks (8.8.8.8, 1.1.1.1, internet name resolution, Cloudflare:443, Microsoft NCSI). Local adapter/IP/DNS-server listing, proxy registry hint, and ICMP to the **default gateway only** still run. Use for locked-down or air-gapped-friendly runs. |

**Launcher:** set environment variable `PC_DOCTOR_SKIP_EXTERNAL_NETWORK_PROBES=1` before `install.bat` to pass this switch automatically.

**Note:** CPU load and fragmentation are moment-in-time values — best used as hints. Free space, temp/recycle sizes, and RAM pressure tend to be the most meaningful before/after deltas.

### Audited temp cleanup (optional manual run)

From an elevated **Administrator** prompt. **Project root** (folder that contains `outputs\`):

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Invoke-TempCleanup.ps1 -OutputDir outputs
```

During a normal PC Doctor session the shell **cwd is `outputs\`**; the agent uses `..\Invoke-TempCleanup.ps1` with `-OutputDir .` (see `agent_prompt.md`).

Add `-IncludePrefetch` only if you explicitly want Prefetch cleared. Use `-WhatIf` to preview targets without deleting.

---

## Safety Notes

- **Supervised mode means nothing happens without your YES**
- High-impact actions require explicit `YES HIGH-RISK` confirmation
- The **collector** may make **routine connectivity probes** from this PC unless you pass **`-SkipExternalNetworkProbes`** to `diagnose.ps1` (or set **`PC_DOCTOR_SKIP_EXTERNAL_NETWORK_PROBES=1`** before `install.bat`). Full probes use ICMP to your gateway and public IPs, DNS lookups (`dns.google`, `www.microsoft.com`), TCP 443 to `1.1.1.1`, and HTTP to Microsoft's NCSI endpoint. Skipped mode still pings only your **default gateway** (if any) and still lists local IP/DNS-server config — it does not send the diagnostic **report** anywhere by itself; only **Anthropic's API** receives report content when you run the agent
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

**"Claude Code on Windows requires git-bash"**
→ Install Git for Windows: https://git-scm.com/downloads/win
→ If needed, set:
`setx CLAUDE_CODE_GIT_BASH_PATH "C:\Program Files\Git\bin\bash.exe" /M`
→ Close and reopen CMD, then run `install.bat` again.

**"ANTHROPIC_API_KEY not set"**
→ Either create `local.secrets.env` from `local.secrets.env.example`, run `setx ANTHROPIC_API_KEY "sk-ant-..." /M`, or use `claude auth login`

**"Auth conflict" or "Invalid API key"**
→ Verify `local.secrets.env` key value, or remove/clear the key and use `claude auth login`

**"Access denied" on PowerShell**
→ Make sure install.bat was launched via right-click → Run as Administrator

**Weird errors when running `install.bat`** (for example `'cho' is not recognized`, `'else' is not recognized`, empty paths, or `''` is not a command)
→ Windows **`cmd.exe` expects CRLF** in `.bat` / `.cmd` files. If an editor saved them with LF-only, parsing breaks. This repo’s **`.gitattributes`** keeps `*.bat` and `*.cmd` as CRLF on clone/checkout; re-save launchers with CRLF or run `git checkout -- install.bat pc_doctor_resume.cmd register_reboot_resume.cmd` after pull.

**Diagnostic takes too long**
→ SFC /verifyonly can be slow on older systems. Wait up to 5 minutes.

---

## Cost and token estimates (technicians)

**After each session**, `install.bat` runs `session_usage_estimate.ps1`, which writes **`session_usage_estimate_<run-stamp>.txt`** in `outputs\`. It includes:

- Approximate **input** tokens from `system_report.txt`, `agent_prompt.md`, and the session `init_message` (plus a small nominal CLI overhead)
- Approximate **output** band derived from the **transcript** size and `[USER]` turn count (heuristic)
- A **lower / upper USD band** using per-million-token rates (defaults are placeholder Sonnet-class numbers)

**These numbers are not billed amounts.** Claude Code may compact or cache context; use your **Anthropic Console** (usage / invoices) for authoritative token and cost data.

**Customize rates:** copy `pc-doctor-pricing.env.example` to **`pc-doctor-pricing.env`** in the project folder and set `PC_DOCTOR_INPUT_USD_PER_MTOK` and `PC_DOCTOR_OUTPUT_USD_PER_MTOK` to match [current Anthropic pricing](https://docs.anthropic.com/en/docs/about-claude/pricing) for the model you use.

You can also run the script manually:

```text
powershell.exe -ExecutionPolicy Bypass -File session_usage_estimate.ps1 -WorkDir outputs -RunStamp 2026-04-23_12-00-00
```

### Rule-of-thumb (legacy)

Rough order of magnitude if you do not open the estimate file:

- Input: often ~15,000–35,000 tokens depending on report size
- Output: varies with how long the session runs
- Many sessions fall in the **roughly $0.10–$0.50** range at typical Sonnet-tier list prices—**verify with your actual usage**

---

## Current capabilities (recent)

- **Diagnostics:** `diagnose.ps1` collects the full system report and optional [before/after](#files-created-during-session) metrics, plus a **browser-friendly** `system_report.html` for navigation and reading
- **Storage (analyze-only):** per-volume `Optimize-Volume -Analyze` with HDD vs SSD-aware suggestions (remediation only after you approve in the agent session)
- **Portable handoff:** `system_report.txt` is validated against the current PC’s hostname so another machine’s report is not used by mistake; optional reuse on the same PC defaults to re-running diagnostics
- **Post-restart resume:** one-time `RunOnce` registration, automatic relaunch after logon, and `resume_bootstrap.txt` for session continuity (see [above](#optional-resume-after-a-planned-restart))
- **Releases:** version tags (e.g. `v1.0.0`) and release notes; see `CHANGELOG.md` and `RELEASE_NOTES_v1.0.0.md` on the repo

## Planned Roadmap (Future Goals)

The items below are **planned** targets, not a promise of completion date.

- Planned: Build a packaged Windows installer (`.exe`) with one-click setup
- Planned: Add optional GUI mode for non-technical users
- Planned: Improve diagnostics coverage and remediation playbooks
- Planned: Add automated test scenarios for safer release validation
- In progress: Habitual versioned GitHub releases for each tagged version

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
