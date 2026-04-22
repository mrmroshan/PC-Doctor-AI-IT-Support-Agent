# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Changed
- `README.md`: expanded project documentation table, `diagnose.ps1` parameter reference, current capabilities vs roadmap, and internal cross-links

### Added
- Before/after metric comparison in `diagnose.ps1`: writes `pc-doctor_metrics.json` each run; optional `-SaveAsBaseline`, `-CompareWithMetricsPath`, and `-CompareWithBaseline` with a summary section in the text report
- Storage optimization section in `diagnose.ps1` (HDD vs SSD aware): `Optimize-Volume -Analyze` only; suggests `-Defrag` for high HDD fragmentation and `-ReTrim` for SSD/flash after user approval
- `CONTRIBUTING.md` with contributor and PR guidance
- `NOTICE` file with copyright and license notice
- `SECURITY.md` responsible disclosure policy
- AGPL badge and expanded legal references in `README.md`
- Roadmap section in `README.md`
- AGPL copyright headers in `install.bat` and `diagnose.ps1`

### Changed
- License migrated from MIT to AGPL-3.0 in `LICENSE`
- `README.md` license section updated for AGPL obligations
