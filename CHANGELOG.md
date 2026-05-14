# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Added

- **DeepSeek via Claude Code:** `local.secrets.env` can supply DeepSeek’s Anthropic-compatible settings (`ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, optional model env vars per [DeepSeek coding-agents guide](https://api-docs.deepseek.com/guides/coding_agents#integrate-with-claude-code)); `install.bat` whitelists those keys, shows DeepSeek auth mode when the base URL matches, and maps `ANTHROPIC_API_KEY` → `ANTHROPIC_AUTH_TOKEN` when the base URL is DeepSeek’s
- **Deeper network + printer diagnostics in `diagnose.ps1`:** extended **NETWORK ANALYSIS** (adapters, gateway, DNS, per-user proxy hint, ICMP to gateway and public IPs, `Resolve-DnsName` checks, TCP 443 to 1.1.1.1, Microsoft NCSI HTTP probe) and new **PRINTERS & PRINT SPOOLER** section (spooler service, installed queues via `Get-Printer` with **Win32_Printer** fallback, job counts, status heuristics). `pc-doctor_metrics.json` now includes **`network`** and **`printers`** summaries for tooling and baselines.
- **`diagnose.ps1 -SkipExternalNetworkProbes`** (and **`PC_DOCTOR_SKIP_EXTERNAL_NETWORK_PROBES=1`** for `install.bat`): skips public ICMP, internet DNS resolution tests, TCP to `1.1.1.1:443`, and NCSI HTTP; **JSON** `network.externalProbesSkipped` records this; local adapter/IP/DNS-server-lines and default-gateway ICMP remain
- **`tests\Run-TempCleanupContractTests.ps1`:** systematic checks for `install.bat` cwd vs `..\Invoke-TempCleanup.ps1`, parser clean, WhatIf run + audit log shape, and project-root invocation (`-File .\Invoke-TempCleanup.ps1 -OutputDir outputs`). Run: `powershell -NoProfile -ExecutionPolicy Bypass -File tests\Run-TempCleanupContractTests.ps1`
- **`Invoke-TempCleanup.ps1`:** audited temp-folder cleanup with before/after sizes, per-target removed/failed counts, sample lock errors, and `outputs\temp_cleanup_audit_*.txt`; agent protocol in `agent_prompt.md` requires this path instead of silent `Remove-Item` for temp cleanup
- **`.gitattributes`:** `*.bat` and `*.cmd` use CRLF on checkout so `cmd.exe` does not mis-parse LF-only batch files
- **Session usage estimates for technicians:** `session_usage_estimate.ps1` runs after each `install.bat` session and writes `session_usage_estimate_<run-stamp>.txt` (approximate token counts from report/prompt/init/transcript and a USD band). Optional `pc-doctor-pricing.env` overrides per-million-token rates; defaults are clearly labeled as non-authoritative vs Anthropic Console billing
- **HTML diagnostic report:** `diagnose.ps1` writes `system_report.html` next to `system_report.txt` (sticky sidebar TOC, section cards, scrollable `<pre>` blocks, highlighted `[OK]` / `[WARNING]` / `[CRITICAL]` / `[!]` tags). Use `-NoHtml` to skip. `install.bat` prints the path when the file exists.
- **Post-restart session resume:** `register_reboot_resume.cmd`, `pc_doctor_resume.cmd`, `install.bat --register-reboot` and `--clear-reboot-hook` (one-time `RunOnce` under the current user); `install.bat --post-restart` relaunches the agent after logon with a fresh `system_report.txt` and `outputs\resume_bootstrap.txt` pointing at the latest pre-reboot `session_report_*.txt` and `console_transcript_*.txt` for handoff
- **Portable `system_report.txt` handling:** the launcher reads the `Hostname` line in an existing report and compares it to the current computer name; foreign or unparseable reports are regenerated. On the same PC, reusing a prior report defaults to **no** (`[y/N]`) so copies of the app with another user’s `outputs\` are safe
- **Cursor project skill** (`.cursor/skills/update-docs-on-significant-changes/SKILL.md`): agent workflow to keep README, CHANGELOG, and related docs aligned with user-facing or significant code changes
- Before/after metric comparison in `diagnose.ps1`: writes `pc-doctor_metrics.json` each run; optional `-SaveAsBaseline`, `-CompareWithMetricsPath`, and `-CompareWithBaseline` with a summary section in the text report
- Storage optimization section in `diagnose.ps1` (HDD vs SSD aware): `Optimize-Volume -Analyze` only; suggests `-Defrag` for high HDD fragmentation and `-ReTrim` for SSD/flash after user approval
- `CONTRIBUTING.md` with contributor and PR guidance
- `NOTICE` file with copyright and license notice
- `SECURITY.md` responsible disclosure policy
- AGPL badge and expanded legal references in `README.md`
- Roadmap section in `README.md`
- AGPL copyright headers in `install.bat` and `diagnose.ps1`

### Fixed

- **`Invoke-TempCleanup.ps1` / docs:** session commands corrected to **`..\Invoke-TempCleanup.ps1` + `-OutputDir .`** because `install.bat` sets cwd to `outputs\`; relative `-OutputDir` is resolved against the process working directory
- `install.bat`: `:Log` now uses a proper `if defined CONSOLE_LOG (` … `)` block for appending to the launcher log (the old one-line `if … >> … echo` form broke `cmd` parsing)
- `install.bat`: optional `local.secrets.env` loading moved to `:LoadSecrets` so nested `setlocal` / `endlocal` cannot accidentally pop the main launcher scope and wipe paths
- `install.bat` / `pc_doctor_resume.cmd` / `register_reboot_resume.cmd`: normalized to **CRLF** line endings for reliable parsing on Windows
- `install.bat`: `:REGISTER_REBOOT` now saves `ERRORLEVEL` immediately after PowerShell (before `set PC_REBOOT_TGT=`), so a failed `RunOnce` registration is detected instead of being masked
- `install.bat`: capture Claude exit code before running the usage-estimate script so ERRORLEVEL is not lost; run usage estimates even when Claude exits non-zero; use delayed expansion when checking for zero-byte `system_report.txt`
- `session_usage_estimate.ps1`: validate `WorkDir`; avoid pricing file overwriting explicit `-InputUsdPerMtok` / `-OutputUsdPerMtok`; skip malformed `KEY` lines without `=`; use `[long]` token counts for large reports

### Changed

- **`PC_DOCTOR_LLM_PROVIDER`:** optional `anthropic` \| `deepseek` key in `local.secrets.env` (whitelisted by `install.bat`) presets **`ANTHROPIC_BASE_URL`** for DeepSeek or clears a leftover DeepSeek URL when switching back to Anthropic
- `agent_prompt.md`: **SESSION TRANSCRIPT FILE** rules—the agent must append **verbatim** user and assistant text after each turn (full audit trail); session report may still summarize
- `install.bat`: init message and `INIT_PROMPT` stress verbatim transcript logging per `agent_prompt.md`
- `README.md` / `CONTRIBUTING.md`: transcript audit-trail expectations, CRLF / batch troubleshooting, contributor note on line endings
- License migrated from MIT to AGPL-3.0 in `LICENSE`
- `README.md` license section updated for AGPL obligations
