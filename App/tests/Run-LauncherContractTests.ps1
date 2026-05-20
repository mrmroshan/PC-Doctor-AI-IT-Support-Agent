# SPDX-License-Identifier: AGPL-3.0-only

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$appRoot = Split-Path -Parent $PSScriptRoot
$root = Split-Path -Parent $appRoot
$launcher = Join-Path $appRoot "launcher.bat"

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-True (Test-Path -LiteralPath (Join-Path $root "start.bat")) "Missing root start.bat"
Assert-True (Test-Path -LiteralPath $launcher) "Missing App\launcher.bat"
Assert-True (Test-Path -LiteralPath (Join-Path $appRoot "agent_prompt.md")) "Missing App\agent_prompt.md"
Assert-True (Test-Path -LiteralPath (Join-Path $appRoot "templates\outputs-CLAUDE.md")) "Missing App\templates\outputs-CLAUDE.md"

$launcherRaw = Get-Content -LiteralPath $launcher -Raw
Assert-True (-not ($launcherRaw -match ":COLLECT_SYSTEM_REPORT")) "launcher still contains :COLLECT_SYSTEM_REPORT"
Assert-True (-not ($launcherRaw -match "goto :REPORT_READY")) "launcher still contains goto :REPORT_READY"
Assert-True ($launcherRaw -match "--name ""PC Doctor""") "launcher missing Claude session name"

$sessionPaths = Join-Path $root "outputs\session_paths.txt"
if (Test-Path -LiteralPath $sessionPaths) {
    Remove-Item -LiteralPath $sessionPaths -Force
}

$p = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", """$root\start.bat"" --prep-only" -WorkingDirectory $root -Wait -PassThru
Assert-True ($p.ExitCode -eq 0) "start.bat --prep-only failed with exit code $($p.ExitCode)"

Assert-True (-not (Test-Path -LiteralPath $sessionPaths)) "outputs should not contain session_paths.txt"
Assert-True (-not (Test-Path -LiteralPath (Join-Path $root "outputs\CLAUDE.md"))) "outputs should not contain CLAUDE.md"
Assert-True (-not (Test-Path -LiteralPath (Join-Path $root "outputs\agent_prompt.md"))) "outputs should not contain agent_prompt.md"
Assert-True (Test-Path -LiteralPath (Join-Path $root "App\.runtime\CLAUDE.md")) "Prep-only did not create App\.runtime\CLAUDE.md"
Assert-True (Test-Path -LiteralPath (Join-Path $root "App\.runtime\agent_prompt.md")) "Prep-only did not create App\.runtime\agent_prompt.md"
Assert-True (Test-Path -LiteralPath (Join-Path $root "App\.runtime\.claude\settings.json")) "Prep-only did not create App\.runtime\.claude\settings.json"

Write-Host "Launcher contract tests passed." -ForegroundColor Green
