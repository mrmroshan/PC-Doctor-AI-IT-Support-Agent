# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (c) 2026 Roshan Ruzaik
# Part of PC Doctor - AI IT Support Agent
#
# Audited temp cleanup: logs before/after sizes, counts successes/failures,
# and does not hide locked-file errors (samples written to the log).

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$OutputDir = "",
    [switch]$IncludeUserTemp = $true,
    [switch]$IncludeWindowsTemp = $true,
    [switch]$IncludePrefetch = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = [Security.Principal.WindowsPrincipal]::new($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-DirectoryUsageBytes {
    param([string]$LiteralPath)
    if (-not (Test-Path -LiteralPath $LiteralPath)) { return 0 }
    try {
        $sum = Get-ChildItem -LiteralPath $LiteralPath -Force -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue
        if ($sum -and $null -ne $sum.Sum) { return [long]$sum.Sum }
    } catch { }
    return 0
}

function Format-Bytes {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function Clear-LiteralPathChildren {
    param(
        [string]$RootLiteralPath,
        [string]$Label,
        [System.Collections.Generic.List[string]]$LogLines,
        [int]$MaxErrorSamples = 40
    )
    $removed = 0
    $failed = 0
    $samples = [System.Collections.Generic.List[string]]::new()

    if (-not (Test-Path -LiteralPath $RootLiteralPath)) {
        $LogLines.Add("$Label : SKIP (path missing): $RootLiteralPath")
        return [pscustomobject]@{ Removed = 0; Failed = 0 }
    }

    $children = @(Get-ChildItem -LiteralPath $RootLiteralPath -Force -ErrorAction SilentlyContinue)
    if ($WhatIfPreference) {
        $LogLines.Add("$Label : WhatIf - would target $($children.Count) top-level item(s) under $RootLiteralPath (nothing removed)")
        return [pscustomobject]@{ Removed = 0; Failed = 0 }
    }

    foreach ($item in $children) {
        try {
            Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
            $removed++
        } catch {
            $failed++
            if ($samples.Count -lt $MaxErrorSamples) {
                $samples.Add("  $($item.FullName): $($_.Exception.Message)")
            }
        }
    }

    $LogLines.Add("$Label : removed $removed item(s), failed $failed")
    foreach ($s in $samples) { $LogLines.Add($s) }
    return [pscustomobject]@{ Removed = $removed; Failed = $failed }
}

# --- Resolve log directory ---
$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $scriptRoot "outputs"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputDir)) {
    $OutputDir = [System.IO.Path]::GetFullPath((Join-Path -Path (Get-Location).Path -ChildPath $OutputDir))
}
if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force -WhatIf:$false | Out-Null
}

$stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logPath = Join-Path $OutputDir "temp_cleanup_audit_$stamp.txt"

$admin = Test-IsAdmin
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("PC Doctor - Temp cleanup audit")
$lines.Add("Started (local): $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$lines.Add("Computer      : $env:COMPUTERNAME")
$lines.Add("User          : $env:USERNAME")
$lines.Add("Elevated      : $admin")
$lines.Add("WhatIf        : $WhatIfPreference")
$lines.Add("")

$userTemp = [Environment]::GetEnvironmentVariable("TEMP", "User")
if ([string]::IsNullOrWhiteSpace($userTemp)) { $userTemp = $env:TEMP }
$winTemp = Join-Path $env:SystemRoot "Temp"
$prefetch = Join-Path $env:SystemRoot "Prefetch"

$beforeUser = Get-DirectoryUsageBytes $userTemp
$beforeWin = Get-DirectoryUsageBytes $winTemp
$beforePf = Get-DirectoryUsageBytes $prefetch

$lines.Add("--- BEFORE ---")
$lines.Add("User TEMP     : $(Format-Bytes $beforeUser)  ($userTemp)")
$lines.Add("Windows Temp  : $(Format-Bytes $beforeWin)  ($winTemp)")
$lines.Add("Prefetch      : $(Format-Bytes $beforePf)  ($prefetch)")
$lines.Add("")

$lines.Add("--- ACTIONS ---")
if ($IncludeUserTemp) {
    Clear-LiteralPathChildren -RootLiteralPath $userTemp -Label "User TEMP" -LogLines $lines | Out-Null
} else {
    $lines.Add("User TEMP : skipped (-IncludeUserTemp:`$false)")
}

if ($IncludeWindowsTemp) {
    if (-not $admin) {
        $lines.Add("Windows Temp : SKIP (not elevated - run as Administrator to clean $winTemp)")
    } else {
        Clear-LiteralPathChildren -RootLiteralPath $winTemp -Label "Windows Temp" -LogLines $lines | Out-Null
    }
} else {
    $lines.Add("Windows Temp : skipped (-IncludeWindowsTemp:`$false)")
}

if ($IncludePrefetch) {
    if (-not $admin) {
        $lines.Add("Prefetch : SKIP (not elevated - run as Administrator to clean $prefetch)")
    } else {
        Clear-LiteralPathChildren -RootLiteralPath $prefetch -Label "Prefetch" -LogLines $lines | Out-Null
    }
} else {
    $lines.Add("Prefetch : skipped (use -IncludePrefetch if user approved)")
}

$lines.Add("")
$afterUser = Get-DirectoryUsageBytes $userTemp
$afterWin = Get-DirectoryUsageBytes $winTemp
$afterPf = Get-DirectoryUsageBytes $prefetch

$lines.Add("--- AFTER ---")
$lines.Add("User TEMP     : $(Format-Bytes $afterUser)  (delta: $(Format-Bytes ($afterUser - $beforeUser)))")
$lines.Add("Windows Temp  : $(Format-Bytes $afterWin)  (delta: $(Format-Bytes ($afterWin - $beforeWin)))")
$lines.Add("Prefetch      : $(Format-Bytes $afterPf)  (delta: $(Format-Bytes ($afterPf - $beforePf)))")
$lines.Add("")
$lines.Add("Log file      : $logPath")

$content = ($lines -join [Environment]::NewLine)
# Always persist the audit file (even when -WhatIf prevented deletes)
Set-Content -LiteralPath $logPath -Value $content -Encoding UTF8 -WhatIf:$false

Write-Host $content
Write-Host ""
Write-Host "Wrote audit log: $logPath" -ForegroundColor Cyan
