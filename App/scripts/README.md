# App scripts

All scripts are designed to be run from the session `outputs\` folder.

## Scripts

- `Collect-SystemReport.ps1`
  - Purpose: full diagnostic report and metrics for PC Doctor analysis.
  - Typical command:
    - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "..\App\scripts\Collect-SystemReport.ps1" -OutputPath ".\system_report.txt" -Quiet`

- `Get-QuickHealth.ps1`
  - Purpose: fast triage snapshot before a full scan.
  - Typical command:
    - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "..\App\scripts\Get-QuickHealth.ps1"`

- `Invoke-TempCleanup.ps1`
  - Purpose: audited temp cleanup with before/after metrics and failure details.
  - Typical command:
    - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "..\App\scripts\Invoke-TempCleanup.ps1" -OutputDir "."`
