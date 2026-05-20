# PC Doctor - AI IT Support Agent

PC Doctor is a supervised Windows IT assistant powered by Claude Code.

## Root layout

- `start.bat` - one-click launcher.
- `outputs/` - session-generated artifacts only (reports, logs, audits, and optional saved conversation files).
- `App/` - app code, prompts, scripts, templates, tests, and documentation.
  - Agent runtime files are stored in `App\.runtime\` (not in `outputs/`).

## Quick start

1. Copy `App\local.secrets.env.example` to `App\local.secrets.env`.
2. Fill your provider credentials (`ANTHROPIC_API_KEY` or DeepSeek-compatible values).
3. Right-click `start.bat` and run as Administrator for first-time setup.

The launcher checks dependencies (Node.js, Claude Code CLI, Git Bash) and installs missing ones. It then starts Claude as PC Doctor.

## Session saving

- Conversation capture is **off by default**.
- PC Doctor asks whether you want this PC support session saved to files.
- Transcript/report files are created only if you explicitly opt in.

## Live diagnostics behavior

- Startup does not trust old machine state files.
- PC Doctor greets first.
- When you say `ready` (or ask to start), the agent runs:
  - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "..\App\scripts\Collect-SystemReport.ps1" -OutputPath ".\system_report.txt" -Quiet`
- Analysis and fixes are based on that fresh report.

## Reboot resume

- Register one-time auto-resume before restart:
  - `App\register_reboot_resume.cmd`
  - or `start.bat --register-reboot`
- If restart is cancelled:
  - `start.bat --clear-reboot-hook`

## Scripts

See `App\scripts\README.md` for available assessment and remediation scripts.

## Docs

Operational and project docs are in `App\docs\`:

- `CHANGELOG.md`
- `CONTRIBUTING.md`
- `SECURITY.md`
- `LICENSE`
- `NOTICE`
