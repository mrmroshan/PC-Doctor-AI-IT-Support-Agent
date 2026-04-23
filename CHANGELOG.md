# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Added

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

- `install.bat`: `:REGISTER_REBOOT` now saves `ERRORLEVEL` immediately after PowerShell (before `set PC_REBOOT_TGT=`), so a failed `RunOnce` registration is detected instead of being masked
- `install.bat`: capture Claude exit code before running the usage-estimate script so ERRORLEVEL is not lost; run usage estimates even when Claude exits non-zero; use delayed expansion when checking for zero-byte `system_report.txt`
- `session_usage_estimate.ps1`: validate `WorkDir`; avoid pricing file overwriting explicit `-InputUsdPerMtok` / `-OutputUsdPerMtok`; skip malformed `KEY` lines without `=`; use `[long]` token counts for large reports

### Changed

- `README.md`: project documentation table, `diagnose.ps1` parameters, current capabilities, portable / `system_report` behavior, post-restart resume, `install.bat` option reference, and cross-links
- `CONTRIBUTING.md`: “Documentation” section (doc-update skill)
- License migrated from MIT to AGPL-3.0 in `LICENSE`
- `README.md` license section updated for AGPL obligations
