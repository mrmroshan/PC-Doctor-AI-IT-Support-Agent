# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Added

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

### Changed

- `README.md`: project documentation table, `diagnose.ps1` parameters, current capabilities, portable / `system_report` behavior, post-restart resume, `install.bat` option reference, and cross-links
- `CONTRIBUTING.md`: short “Documentation” section pointing to the doc-update skill and what to change for significant PRs
- License migrated from MIT to AGPL-3.0 in `LICENSE`
- `README.md` license section updated for AGPL obligations
