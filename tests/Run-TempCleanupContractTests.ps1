# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (c) 2026 Roshan Ruzaik
# Part of PC Doctor - AI IT Support Agent
#
# Systematic contract tests: install.bat cwd vs Invoke-TempCleanup paths.
# Run: powershell -NoProfile -ExecutionPolicy Bypass -File tests\Run-TempCleanupContractTests.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $root "install.bat"))) {
    throw "Run this script from the repo (expected install.bat in parent of tests\). Got root: $root"
}

$out = Join-Path $root "outputs"
if (-not (Test-Path -LiteralPath $out)) {
    New-Item -ItemType Directory -Path $out -Force | Out-Null
}

$results = [System.Collections.Generic.List[object]]::new()
function Add-Result {
    param([string]$Id, [bool]$Ok, [string]$Detail)
    $results.Add([pscustomobject]@{ Id = $Id; Pass = $Ok; Detail = $Detail }) | Out-Null
}

$scriptPath = Join-Path $root "Invoke-TempCleanup.ps1"

$batRaw = Get-Content -LiteralPath (Join-Path $root "install.bat") -Raw
Add-Result "T1_install_cd_outputs" (
    ($batRaw -match 'set "WORK_DIR=%OUTPUTS_DIR%"') -and ($batRaw -match 'cd /d "%WORK_DIR%"')
) "install.bat must set WORK_DIR to outputs and cd there"

Add-Result "T2_script_at_project_root" (Test-Path -LiteralPath $scriptPath) $scriptPath

Push-Location $out
try {
    Add-Result "T3_session_dotdot_script" (Test-Path -LiteralPath "..\Invoke-TempCleanup.ps1") "..\Invoke-TempCleanup.ps1 from outputs"
    Add-Result "T4_no_dot_slash_in_outputs" (-not (Test-Path -LiteralPath ".\Invoke-TempCleanup.ps1")) ".\Invoke-TempCleanup.ps1 must not exist in outputs"
} finally {
    Pop-Location
}

$parseErrs = $null
$tokens = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrs)
$errText = if ($parseErrs) { ($parseErrs | ForEach-Object { $_.ToString() }) -join "; " } else { "" }
Add-Result "T5_parser_clean" (($null -eq $parseErrs) -or ($parseErrs.Count -eq 0)) $errText

Push-Location $out
try {
    $auditBefore = (Get-ChildItem -LiteralPath $out -Filter "temp_cleanup_audit_*.txt" -ErrorAction SilentlyContinue | Measure-Object).Count
    $argList = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "..\Invoke-TempCleanup.ps1",
        "-OutputDir", ".", "-WhatIf"
    )
    $p = Start-Process -FilePath "powershell.exe" -ArgumentList $argList -WorkingDirectory $out -Wait -PassThru
    $auditAfter = (Get-ChildItem -LiteralPath $out -Filter "temp_cleanup_audit_*.txt" -ErrorAction SilentlyContinue | Measure-Object).Count
    $latest = Get-ChildItem -LiteralPath $out -Filter "temp_cleanup_audit_*.txt" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    $raw = if ($latest) {
        Get-Content -LiteralPath $latest.FullName -Raw -Encoding UTF8
    } else {
        ""
    }
    Add-Result "T6_whatif_exit_zero" ($p.ExitCode -eq 0) ("ExitCode=" + $p.ExitCode)
    Add-Result "T7_new_audit_file" ($auditAfter -gt $auditBefore) ("count before=$auditBefore after=$auditAfter")
    Add-Result "T8_audit_markers" (
        ($raw -match "--- BEFORE ---") -and ($raw -match "--- AFTER ---") -and ($raw -match "Log file")
    ) "latest: $($latest.Name)"
    Add-Result "T9_audit_path_in_outputs" (
        ($null -ne $latest) -and ($latest.FullName.StartsWith($out, [System.StringComparison]::OrdinalIgnoreCase))
    ) $(if ($latest) { $latest.FullName } else { "(none)" })
} finally {
    Pop-Location
}

Push-Location $root
try {
    $argList2 = @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ".\Invoke-TempCleanup.ps1",
        "-OutputDir", "outputs", "-WhatIf"
    )
    $p2 = Start-Process -FilePath "powershell.exe" -ArgumentList $argList2 -WorkingDirectory $root -Wait -PassThru
    Add-Result "T10_from_project_root" ($p2.ExitCode -eq 0) ("ExitCode=" + $p2.ExitCode)
} finally {
    Pop-Location
}

$ap = Join-Path $root "agent_prompt.md"
$apRaw = Get-Content -LiteralPath $ap -Raw
$dotDotHits = [regex]::Matches($apRaw, '\.\.\\Invoke-TempCleanup\.ps1').Count
Add-Result "T11_prompt_documents_dotdot_path" ($dotDotHits -ge 3) "..\Invoke-TempCleanup.ps1 occurrences: $dotDotHits (expect >= 3 for session examples)"

$failed = ($results | Where-Object { -not $_.Pass } | Measure-Object).Count
$passed = ($results | Where-Object { $_.Pass } | Measure-Object).Count

Write-Host ""
Write-Host "=== PC Doctor - TempCleanup contract tests ===" -ForegroundColor Cyan
Write-Host "Project root: $root"
Write-Host ""
$results | Format-Table -AutoSize Id, Pass, Detail
Write-Host ("SUMMARY: {0} passed, {1} failed (of {2})" -f $passed, $failed, $results.Count) -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })

if ($failed -ne 0) {
    exit 1
}
