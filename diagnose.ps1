# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (c) 2026 Roshan Ruzaik
# Part of PC Doctor - AI IT Support Agent

# ============================================================
#  PC DOCTOR - System Diagnostics Collector
#  Collects comprehensive system health data
#  Output: system_report.txt (+ system_report.html unless -NoHtml)
# ============================================================

param(
    [string]$OutputPath = "$env:TEMP\pc-doctor\system_report.txt",
    [string]$CompareWithMetricsPath = "",
    [switch]$CompareWithBaseline,
    [switch]$SaveAsBaseline,
    [switch]$NoHtml
)

# If requested, compare this run to the last saved baseline next to the report (pc-doctor_metrics_baseline.json).
if ($CompareWithBaseline) {
    $outDirEarly = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($outDirEarly)) {
        $baselineCandidate = Join-Path $outDirEarly "pc-doctor_metrics_baseline.json"
        if (Test-Path -LiteralPath $baselineCandidate) {
            if ([string]::IsNullOrWhiteSpace($CompareWithMetricsPath)) {
                $CompareWithMetricsPath = $baselineCandidate
            }
        } else {
            Write-Host "  [INFO] -CompareWithBaseline: no file at $baselineCandidate (run with -SaveAsBaseline first)." -ForegroundColor Yellow
        }
    }
}

$ErrorActionPreference = "SilentlyContinue"
$report = @()

# Collected in one pass for JSON export and before/after comparison (no duplicate heavy work).
$script:volMetrics = @{}
$script:compareFromJson = $null
if ($CompareWithMetricsPath -and (Test-Path -LiteralPath $CompareWithMetricsPath)) {
    try {
        $raw = Get-Content -LiteralPath $CompareWithMetricsPath -Raw -Encoding UTF8
        $script:compareFromJson = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        $script:compareFromJson = $null
    }
}

function Add-Section($title) {
    $script:report += ""
    $script:report += "=" * 60
    $script:report += "  $title"
    $script:report += "=" * 60
}

function Add-Line($line) {
    $script:report += $line
}

function Split-ReportIntoSections([string[]]$lines) {
    $sections = [System.Collections.ArrayList]@()
    $usedSlugs = @{}
    $i = 0
    while ($i -lt $lines.Count) {
        if ($lines[$i] -match '^=+$') {
            $i++
            if ($i -ge $lines.Count) { break }
            if ($lines[$i] -match '^\s{2}(.+?)\s*$') {
                $title = $Matches[1].Trim()
                $i++
                if ($i -lt $lines.Count -and $lines[$i] -match '^=+$') { $i++ }
                $body = [System.Collections.ArrayList]@()
                while ($i -lt $lines.Count) {
                    if ($lines[$i] -match '^=+$') { break }
                    [void]$body.Add($lines[$i])
                    $i++
                }
                $base = ($title.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
                if (-not $base) { $base = 'section' }
                $slug = $base
                $n = 2
                while ($usedSlugs.ContainsKey($slug)) {
                    $slug = "$base-$n"
                    $n++
                }
                $usedSlugs[$slug] = $true
                [void]$sections.Add([pscustomobject]@{ Title = $title; Slug = $slug; Body = ($body -as [string[]]) })
                continue
            }
        }
        $i++
    }
    return $sections
}

function Format-ReportLineHtml([string]$line) {
    if ($null -eq $line) { return '' }
    $e = [System.Net.WebUtility]::HtmlEncode($line)
    $e = $e -replace '\[(OK)\]', '<span class="st-ok">[OK]</span>'
    $e = $e -replace '\[(CRITICAL)\]', '<span class="st-crit">[CRITICAL]</span>'
    $e = $e -replace '\[(WARNING)\]', '<span class="st-warn">[WARNING]</span>'
    $e = $e -replace '\[(CAUTION)\]', '<span class="st-warn">[CAUTION]</span>'
    $e = $e -replace '\[(INFO)\]', '<span class="st-info">[INFO]</span>'
    $e = $e -replace '\[(ERROR)\]', '<span class="st-err">[ERROR]</span>'
    $e = $e -replace '\[\!\]', '<span class="st-warn">[!]</span>'
    return $e
}

function Write-PcDoctorHtmlReport {
    param(
        [string[]]$Lines,
        [string]$HtmlPath,
        [string]$GeneratedLocal
    )
    $sections = Split-ReportIntoSections $Lines
    if ($sections.Count -eq 0) {
        Write-Host "  [WARNING] Could not parse report sections for HTML; skipping HTML export." -ForegroundColor Yellow
        return
    }
    $navSb = [System.Text.StringBuilder]::new()
    [void]$navSb.AppendLine('<ul class="toc-list">')
    foreach ($s in $sections) {
        $tEnc = [System.Net.WebUtility]::HtmlEncode($s.Title)
        [void]$navSb.AppendLine(('  <li><a href="#{0}">{1}</a></li>' -f $s.Slug, $tEnc))
    }
    [void]$navSb.AppendLine('</ul>')
    $mainSb = [System.Text.StringBuilder]::new()
    foreach ($s in $sections) {
        $tEnc = [System.Net.WebUtility]::HtmlEncode($s.Title)
        [void]$mainSb.AppendLine(('  <section class="card" id="{0}" aria-labelledby="h-{0}">' -f $s.Slug))
        [void]$mainSb.AppendLine(('    <h2 id="h-{0}"><a class="anchor" href="#{0}" aria-hidden="true">#</a> {1}</h2>' -f $s.Slug, $tEnc))
        [void]$mainSb.AppendLine('    <div class="sec-body"><pre class="report-pre" tabindex="0">')
        foreach ($bl in $s.Body) {
            [void]$mainSb.AppendLine((Format-ReportLineHtml $bl))
        }
        [void]$mainSb.AppendLine('    </pre></div>')
        [void]$mainSb.AppendLine('    <p class="back-top"><a href="#top">Back to top</a></p>')
        [void]$mainSb.AppendLine('  </section>')
    }
    $css = @'
:root {
  --bg: #0f1419;
  --surface: #1a2332;
  --border: #2d3d52;
  --text: #e7ecf3;
  --muted: #8b9cb3;
  --accent: #3d8bfd;
  --ok: #3fb950;
  --warn: #d4a72c;
  --crit: #f85149;
  --info: #58a6ff;
}
* { box-sizing: border-box; }
html { scroll-behavior: smooth; }
body {
  margin: 0;
  font-family: "Segoe UI", system-ui, sans-serif;
  background: var(--bg);
  color: var(--text);
  line-height: 1.45;
  font-size: 15px;
}
a { color: var(--accent); text-decoration: none; }
a:hover { text-decoration: underline; }
.site-header {
  position: sticky; top: 0; z-index: 100;
  background: linear-gradient(180deg, var(--surface) 0%, rgba(26,35,50,.97) 100%);
  border-bottom: 1px solid var(--border);
  padding: 0.85rem 1.25rem;
  display: flex; flex-wrap: wrap; align-items: center; gap: 1rem;
}
.site-header h1 { margin: 0; font-size: 1.15rem; font-weight: 600; }
.site-header .meta { color: var(--muted); font-size: 0.88rem; }
.layout {
  display: grid;
  grid-template-columns: minmax(200px, 260px) 1fr;
  gap: 1.25rem;
  max-width: 1400px;
  margin: 0 auto;
  padding: 1rem 1.25rem 2.5rem;
}
@media (max-width: 900px) {
  .layout { grid-template-columns: 1fr; }
  .toc-wrap { position: static !important; max-height: none !important; }
}
.toc-wrap {
  position: sticky; top: 56px; align-self: start;
  max-height: calc(100vh - 64px); overflow: auto;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 0.75rem 0.5rem;
}
.toc-wrap h2 { margin: 0 0 0.5rem 0.6rem; font-size: 0.72rem; text-transform: uppercase; letter-spacing: .06em; color: var(--muted); font-weight: 600; }
.toc-list { list-style: none; margin: 0; padding: 0; }
.toc-list li { margin: 0; border-radius: 6px; }
.toc-list a {
  display: block; padding: 0.35rem 0.6rem; border-radius: 6px;
  color: var(--text); font-size: 0.88rem;
}
.toc-list a:hover { background: rgba(61,139,253,.12); text-decoration: none; }
main { min-width: 0; }
.card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  margin-bottom: 1rem;
  overflow: hidden;
}
.card h2 {
  margin: 0; padding: 0.65rem 1rem;
  font-size: 1.02rem; font-weight: 600;
  background: rgba(0,0,0,.2);
  border-bottom: 1px solid var(--border);
  scroll-margin-top: 64px;
}
.anchor { opacity: .45; font-weight: 400; margin-right: .35rem; }
.anchor:hover { opacity: 1; }
.sec-body { padding: 0; }
.report-pre {
  margin: 0; padding: 0.9rem 1rem;
  font-family: "Cascadia Code", "Consolas", "Segoe UI Mono", monospace;
  font-size: 12.5px;
  line-height: 1.4;
  white-space: pre-wrap; word-break: break-word;
  overflow-x: auto;
  max-height: 70vh;
  overflow-y: auto;
}
.back-top { margin: 0; padding: 0.4rem 1rem 0.75rem; font-size: 0.82rem; color: var(--muted); }
.st-ok { color: var(--ok); font-weight: 600; }
.st-warn { color: var(--warn); font-weight: 600; }
.st-crit { color: var(--crit); font-weight: 600; }
.st-info { color: var(--info); }
.st-err { color: var(--crit); }
.site-footer { text-align: center; padding: 1.5rem; color: var(--muted); font-size: 0.85rem; }
'@
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PC Doctor - System Report</title>
<style>
$css
</style>
</head>
<body id="top">
<header class="site-header">
  <h1>PC Doctor - System diagnostic report</h1>
  <span class="meta">Generated: $([System.Net.WebUtility]::HtmlEncode($GeneratedLocal)) · Open <code>system_report.txt</code> for the same data (AI/agent use)</span>
</header>
<div class="layout">
  <nav class="toc-wrap" aria-label="Report sections">
    <h2>Navigate</h2>
$( $navSb.ToString().TrimEnd() )
  </nav>
  <main>
$( $mainSb.ToString().TrimEnd() )
  </main>
</div>
<footer class="site-footer">PC Doctor v1.0 - AI IT Support Agent</footer>
</body>
</html>
"@
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($HtmlPath, $html, $utf8NoBom)
}

Write-Host "  Collecting system info..." -ForegroundColor Cyan

# ============================================================
#  SECTION 1: SYSTEM OVERVIEW
# ============================================================
Add-Section "SYSTEM OVERVIEW"

$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS

Add-Line "Hostname         : $($cs.Name)"
Add-Line "Manufacturer     : $($cs.Manufacturer)"
Add-Line "Model            : $($cs.Model)"
Add-Line "OS               : $($os.Caption) Build $($os.BuildNumber)"
Add-Line "OS Architecture  : $($os.OSArchitecture)"
Add-Line "OS Install Date  : $($os.InstallDate)"
Add-Line "Last Boot        : $($os.LastBootUpTime)"
$uptime = (Get-Date) - $os.LastBootUpTime
Add-Line "System Uptime    : $([math]::Round($uptime.TotalHours, 1)) hours"
Add-Line "BIOS Version     : $($bios.SMBIOSBIOSVersion)"
Add-Line "BIOS Release     : $($bios.ReleaseDate)"

# ============================================================
#  SECTION 2: CPU ANALYSIS
# ============================================================
Write-Host "  Analyzing CPU..." -ForegroundColor Cyan
Add-Section "CPU ANALYSIS"

$cpu = Get-CimInstance Win32_Processor
Add-Line "CPU              : $($cpu.Name)"
Add-Line "Cores            : $($cpu.NumberOfCores) physical / $($cpu.NumberOfLogicalProcessors) logical"
Add-Line "Max Speed        : $($cpu.MaxClockSpeed) MHz"

$cpuLoad = (Get-CimInstance Win32_Processor).LoadPercentage
Add-Line "Current Load     : $cpuLoad%"

if ($cpuLoad -gt 80) {
    Add-Line "STATUS           : [WARNING] CPU load is critically high"
} elseif ($cpuLoad -gt 60) {
    Add-Line "STATUS           : [CAUTION] CPU load is elevated"
} else {
    Add-Line "STATUS           : [OK] CPU load is normal"
}

# Top CPU processes
Add-Line ""
Add-Line "Top 10 CPU-Consuming Processes:"
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 | ForEach-Object {
    Add-Line ("  {0,-35} CPU: {1,8:F1}s   RAM: {2,6} MB" -f $_.ProcessName, $_.CPU, [math]::Round($_.WorkingSet64/1MB, 1))
}

# ============================================================
#  SECTION 3: MEMORY ANALYSIS
# ============================================================
Write-Host "  Analyzing RAM..." -ForegroundColor Cyan
Add-Section "MEMORY (RAM) ANALYSIS"

$totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
$freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
$usedRAM = [math]::Round($totalRAM - $freeRAM, 2)
$ramPct = [math]::Round(($usedRAM / $totalRAM) * 100, 1)

Add-Line "Total RAM        : $totalRAM GB"
Add-Line "Used RAM         : $usedRAM GB ($ramPct%)"
Add-Line "Free RAM         : $freeRAM GB"

if ($ramPct -gt 90) {
    Add-Line "STATUS           : [CRITICAL] Memory critically low - system likely swapping"
} elseif ($ramPct -gt 75) {
    Add-Line "STATUS           : [WARNING] Memory usage is high"
} else {
    Add-Line "STATUS           : [OK] Memory usage is normal"
}

# Virtual memory / page file
$pf = Get-CimInstance Win32_PageFileUsage
if ($pf) {
    Add-Line ""
    Add-Line "Page File        : $($pf.Name)"
    Add-Line "Page File Used   : $($pf.CurrentUsage) MB of $($pf.AllocatedBaseSize) MB"
}

# RAM sticks detail
Add-Line ""
Add-Line "RAM Modules:"
Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
    $speed = if ($_.Speed) { "$($_.Speed) MHz" } else { "Unknown speed" }
    Add-Line ("  Slot: {0}  Size: {1} GB  Speed: {2}  Type: {3}" -f $_.DeviceLocator, [math]::Round($_.Capacity/1GB,0), $speed, $_.MemoryType)
}

# Top RAM processes
Add-Line ""
Add-Line "Top 10 Memory-Consuming Processes:"
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 | ForEach-Object {
    Add-Line ("  {0,-35} RAM: {1,6} MB" -f $_.ProcessName, [math]::Round($_.WorkingSet64/1MB, 1))
}

# ============================================================
#  SECTION 4: DISK HEALTH & ANALYSIS
# ============================================================
Write-Host "  Analyzing disks..." -ForegroundColor Cyan
Add-Section "DISK HEALTH & STORAGE ANALYSIS"

# Disk space
Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Used -gt 0} | ForEach-Object {
    $total = [math]::Round(($_.Used + $_.Free) / 1GB, 1)
    $used = [math]::Round($_.Used / 1GB, 1)
    $free = [math]::Round($_.Free / 1GB, 1)
    $pct = if ($total -gt 0) { [math]::Round(($used / $total) * 100, 1) } else { 0 }
    $dk = [string]$_.Name
    $script:volMetrics[$dk] = [ordered]@{
        letter      = $dk
        usedPercent = $pct
        freeGB      = $free
        totalGB     = $total
    }
    Add-Line "Drive $($_.Name):  Total: $total GB  Used: $used GB ($pct%)  Free: $free GB"
    if ($pct -gt 90) {
        Add-Line "  STATUS: [CRITICAL] Drive is nearly full - will cause slowness"
    } elseif ($pct -gt 80) {
        Add-Line "  STATUS: [WARNING] Drive space is low"
    } else {
        Add-Line "  STATUS: [OK]"
    }
}

# Physical disk info
Add-Line ""
Add-Line "Physical Disks:"
Get-PhysicalDisk | ForEach-Object {
    $sizeGB = [math]::Round($_.Size / 1GB, 1)
    Add-Line ("  {0}  Size: {1} GB  Type: {2}  Health: {3}  Status: {4}" -f $_.FriendlyName, $sizeGB, $_.MediaType, $_.HealthStatus, $_.OperationalStatus)
    if ($_.HealthStatus -ne "Healthy") {
        Add-Line "  STATUS: [CRITICAL] Disk health issue detected!"
    }
}

# Temp folder sizes
Add-Line ""
$tempSize = [math]::Round((Get-ChildItem $env:TEMP -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB, 1)
$winTempSize = [math]::Round((Get-ChildItem "C:\Windows\Temp" -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB, 1)
Add-Line "User Temp Folder Size    : $tempSize MB  ($env:TEMP)"
Add-Line "Windows Temp Folder Size : $winTempSize MB  (C:\Windows\Temp)"

# Recycle bin
$recycleBin = (New-Object -ComObject Shell.Application).Namespace(0xA)
$rbSize = [math]::Round(($recycleBin.Items() | Measure-Object -Property Size -Sum).Sum / 1MB, 1)
Add-Line "Recycle Bin Size         : $rbSize MB"

$script:storageMetrics = [ordered]@{
    userTempMB     = $tempSize
    windowsTempMB  = $winTempSize
    recycleBinMB   = $rbSize
}

# ============================================================
#  SECTION 4B: STORAGE OPTIMIZATION (ANALYZE ONLY)
#  Read-only: Optimize-Volume -Analyze. No defrag/trim is performed here.
# ============================================================
Write-Host "  Analyzing storage optimization (fragmentation/trim)..." -ForegroundColor Cyan
Add-Section "STORAGE OPTIMIZATION (ANALYZE -- FRAGMENTATION / TRIM)"
Add-Line "This section runs read-only analysis (PowerShell: Optimize-Volume -Analyze)."
Add-Line "It does not defragment, retrim, or change volumes. Suggested fix commands are for the supervised session only."
Add-Line ""

$fixedVols = Get-Volume -ErrorAction SilentlyContinue | Where-Object {
    $null -ne $_.DriveLetter -and $_.DriveType -eq "Fixed" -and $_.Size -gt 0
} | Sort-Object { $_.DriveLetter }

if (-not $fixedVols) {
    Add-Line "No fixed volumes with drive letters were found to analyze."
} else {
    foreach ($vol in $fixedVols) {
        $letter = $vol.DriveLetter
        $lk = [string]$letter
        if (-not $script:volMetrics.ContainsKey($lk)) {
            $script:volMetrics[$lk] = [ordered]@{ letter = $lk }
        }
        $fs = if ($vol.FileSystemType) { $vol.FileSystemType } else { "Unknown" }
        $sizeGB = if ($vol.Size) { [math]::Round($vol.Size / 1GB, 1) } else { 0 }
        $freeGB = if ($vol.SizeRemaining) { [math]::Round($vol.SizeRemaining / 1GB, 1) } else { 0 }

        $part = $null
        $dsk = $null
        $media = "Unknown"
        try {
            $part = Get-Partition -DriveLetter $letter -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($part) {
                $dsk = Get-Disk -Number $part.DiskNumber -ErrorAction SilentlyContinue
                if ($dsk -and $dsk.PSObject.Properties["MediaType"]) { $media = [string]$dsk.MediaType }
            }
        } catch { }
        $script:volMetrics[$lk].fileSystem     = $fs
        $script:volMetrics[$lk].sizeGB          = $sizeGB
        $script:volMetrics[$lk].freeGB         = $freeGB
        $script:volMetrics[$lk].mediaType      = $media

        Add-Line "Drive ${letter}:\  FS: $fs  Size: $sizeGB GB  Free: $freeGB GB  Backing media: $media"
        if ($part -and $dsk) {
            Add-Line ("  Partition #{0}  Disk# {1}  {2}" -f $part.PartitionNumber, $dsk.Number, $dsk.FriendlyName)
        }

        try {
            $an = Optimize-Volume -DriveLetter $letter -Analyze -ErrorAction Stop
        } catch {
            $script:volMetrics[$lk].analyzeError = $_.Exception.Message
            Add-Line ("  [ANALYZE FAILED] {0}" -f $_.Exception.Message)
            if ($_.Exception.Message -match "Access is denied" -or $_.Exception.Message -match "elevation") {
                Add-Line "  [HINT] Run the launcher as Administrator for this analysis, or re-run install.bat as Administrator."
            }
            Add-Line ""
            continue
        }

        $frag = $an.FragmentPercent
        if ($null -ne $frag) {
            $script:volMetrics[$lk].fragmentPercent = [double]$frag
        } else {
            $script:volMetrics[$lk].fragmentPercent = $null
        }
        if ($null -ne $frag) {
            Add-Line ("  Fragmentation  : {0}%" -f $frag)
        } else {
            Add-Line "  Fragmentation  : (not reported by this volume)"
        }

        $fragN = if ($null -ne $frag) { [double]$frag } else { $null }
        $isHdd = ($media -eq "HDD")
        $isSsd = ($media -eq "SSD" -or $media -eq "SCM")
        $isUnknownMedia = ($media -eq "Unspecified" -or $media -eq "Unknown")

        if ($isHdd) {
            if ($null -ne $fragN -and $fragN -ge 10) {
                Add-Line "  STATUS         : [WARNING] High fragmentation for an HDD; scheduled defrag/optimize can help I/O."
            } elseif ($null -ne $fragN -and $fragN -ge 5) {
                Add-Line "  STATUS         : [INFO] Moderate fragmentation; consider optimize during off-hours."
            } else {
                Add-Line "  STATUS         : [OK] Fragmentation is not elevated for a typical hard disk check."
            }
        } elseif ($isSsd) {
            Add-Line "  STATUS         : [INFO] On SSD/flash, prefer trim/retrim. Windows may still run a scheduled optimize for NTFS; follow Storage Optimizer guidance, not an old defrag-for-all habit."
        } else {
            if ($null -ne $fragN -and $fragN -ge 10) {
                Add-Line "  STATUS         : [INFO] Fragmentation is reported as high, but media type is unknown. Confirm HDD vs SSD in Disk Management before defrag; SSDs use trim instead."
            } else {
                Add-Line "  STATUS         : [INFO] Media is Unspecified/unknown. Use Disk Management or Storage properties to identify HDD vs SSD, then follow HDD (defrag) or SSD (retrim) guidance below."
            }
        }

        if ($isHdd -and $null -ne $fragN -and $fragN -ge 10) {
            Add-Line "  SUGGESTED FIX  : (after user approves)  Optimize-Volume -DriveLetter $letter -Defrag -Verbose"
        } elseif ($isSsd) {
            Add-Line "  SUGGESTED FIX  : (after user approves)  Optimize-Volume -DriveLetter $letter -ReTrim -Verbose"
        } elseif ($isUnknownMedia) {
            Add-Line "  SUGGESTED FIX  : (after user approves) if confirmed HDD: -Defrag; if confirmed SSD: -ReTrim. Example: Optimize-Volume -DriveLetter $letter -Analyze -Verbose; then the matching action only after confirmation."
        }

        Add-Line ""
    }
}
Add-Line "To analyze again manually:  Optimize-Volume -DriveLetter <Letter> -Analyze -Verbose"
Add-Line 'HDD: use -Defrag on spinning disks when fragmentation is high. SSD/flash: use -ReTrim; Windows 10/11 may schedule optimize for NTFS (including retrim) — that is not the same as a classic "defrag everything" habit.'

# ============================================================
#  SECTION 5: STARTUP PROGRAMS
# ============================================================
Write-Host "  Checking startup programs..." -ForegroundColor Cyan
Add-Section "STARTUP PROGRAMS"

Add-Line "Registry Startup (HKCU):"
Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue | 
    Get-Member -MemberType NoteProperty | 
    Where-Object {$_.Name -notmatch "^PS"} | 
    ForEach-Object { Add-Line "  $($_.Name)" }

Add-Line ""
Add-Line "Registry Startup (HKLM):"
Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue | 
    Get-Member -MemberType NoteProperty | 
    Where-Object {$_.Name -notmatch "^PS"} | 
    ForEach-Object { Add-Line "  $($_.Name)" }

Add-Line ""
Add-Line "Task Manager Startup Items:"
Get-CimInstance Win32_StartupCommand | ForEach-Object {
    Add-Line ("  [{0}] {1} -> {2}" -f $_.Location, $_.Name, $_.Command)
}

# ============================================================
#  SECTION 6: WINDOWS UPDATES
# ============================================================
Write-Host "  Checking Windows Updates..." -ForegroundColor Cyan
Add-Section "WINDOWS UPDATE STATUS"

$updateSession = New-Object -ComObject Microsoft.Update.Session
$updateSearcher = $updateSession.CreateUpdateSearcher()

try {
    $pendingUpdates = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
    Add-Line "Pending Updates  : $($pendingUpdates.Updates.Count)"
    if ($pendingUpdates.Updates.Count -gt 0) {
        Add-Line "STATUS           : [WARNING] System has pending updates"
        Add-Line ""
        Add-Line "Pending Update List:"
        $pendingUpdates.Updates | Select-Object -First 15 | ForEach-Object {
            Add-Line "  - $($_.Title)"
        }
    } else {
        Add-Line "STATUS           : [OK] System is up to date"
    }
} catch {
    Add-Line "STATUS           : [INFO] Could not query Windows Update (may need manual check)"
}

# Last update installed
$lastUpdate = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1
if ($lastUpdate) {
    Add-Line ""
    Add-Line "Last Update Installed: $($lastUpdate.InstalledOn) - $($lastUpdate.HotFixID)"
}

# ============================================================
#  SECTION 7: DRIVER ANALYSIS
# ============================================================
Write-Host "  Analyzing drivers..." -ForegroundColor Cyan
Add-Section "DRIVER ANALYSIS"

Add-Line "Devices with Issues (Error/Warning state):"
$problemDevices = Get-PnpDevice | Where-Object {$_.Status -ne "OK"}
if ($problemDevices) {
    $problemDevices | ForEach-Object {
        Add-Line ("  [!] {0,-50} Status: {1}  Class: {2}" -f $_.FriendlyName, $_.Status, $_.Class)
    }
} else {
    Add-Line "  [OK] No device errors found"
}

Add-Line ""
Add-Line "Key Driver Versions:"
# Display adapters
Get-CimInstance Win32_VideoController | ForEach-Object {
    Add-Line ("  GPU: {0}" -f $_.Name)
    Add-Line ("    Driver Version: {0}  Date: {1}" -f $_.DriverVersion, $_.DriverDate)
}

# Network adapters
Add-Line ""
Get-CimInstance Win32_NetworkAdapter | Where-Object {$_.PhysicalAdapter -eq $true} | ForEach-Object {
    Add-Line ("  NIC: {0}" -f $_.Name)
    Add-Line ("    Driver Version: {0}" -f $_.DriverVersion)
}

# ============================================================
#  SECTION 8: SYSTEM FILE INTEGRITY
# ============================================================
Write-Host "  Checking system file integrity..." -ForegroundColor Cyan
Add-Section "SYSTEM FILE INTEGRITY"

Add-Line "Running SFC scan (quick check)..."
$sfcResult = sfc /verifyonly 2>&1
if ($sfcResult -match "did not find any integrity violations") {
    Add-Line "SFC Status       : [OK] No integrity violations found"
} elseif ($sfcResult -match "found corrupt files") {
    Add-Line "SFC Status       : [CRITICAL] Corrupt system files detected - repair needed"
} else {
    Add-Line "SFC Status       : [INFO] SFC scan result: $sfcResult"
}

# DISM health check
Add-Line ""
Add-Line "Checking Windows image health (DISM)..."
$dismResult = DISM /Online /Cleanup-Image /CheckHealth 2>&1
if ($dismResult -match "No component store corruption detected") {
    Add-Line "DISM Status      : [OK] Component store is healthy"
} elseif ($dismResult -match "repairable") {
    Add-Line "DISM Status      : [WARNING] Component store corruption detected but repairable"
} elseif ($dismResult -match "not repairable") {
    Add-Line "DISM Status      : [CRITICAL] Component store corruption - not auto-repairable"
} else {
    Add-Line "DISM Status      : [INFO] $dismResult"
}

# ============================================================
#  SECTION 9: EVENT LOG ERRORS (Last 24 Hours)
# ============================================================
Write-Host "  Scanning event logs..." -ForegroundColor Cyan
Add-Section "EVENT LOG - ERRORS & WARNINGS (LAST 24 HOURS)"

$since = (Get-Date).AddHours(-24)

Add-Line "Critical/Error Events (System Log):"
$sysErrors = Get-EventLog -LogName System -EntryType Error,Warning -After $since -ErrorAction SilentlyContinue | 
    Select-Object -First 20
if ($sysErrors) {
    $sysErrors | ForEach-Object {
        Add-Line ("  [{0}] {1,-20} EventID:{2,-6} {3}" -f $_.EntryType, $_.Source, $_.EventID, ($_.Message -split "`n")[0])
    }
} else {
    Add-Line "  [OK] No critical/error events in last 24 hours"
}

Add-Line ""
Add-Line "Critical/Error Events (Application Log):"
$appErrors = Get-EventLog -LogName Application -EntryType Error -After $since -ErrorAction SilentlyContinue | 
    Select-Object -First 15
if ($appErrors) {
    $appErrors | ForEach-Object {
        Add-Line ("  [ERROR] {0,-25} EventID:{1,-6} {2}" -f $_.Source, $_.EventID, ($_.Message -split "`n")[0])
    }
} else {
    Add-Line "  [OK] No application errors in last 24 hours"
}

# ============================================================
#  SECTION 10: NETWORK ANALYSIS
# ============================================================
Write-Host "  Analyzing network..." -ForegroundColor Cyan
Add-Section "NETWORK ANALYSIS"

# IP configuration
Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -notmatch "^127|^169"} | ForEach-Object {
    Add-Line "  Interface: $($_.InterfaceAlias)  IP: $($_.IPAddress)  Prefix: $($_.PrefixLength)"
}

# DNS servers
Add-Line ""
Add-Line "DNS Servers:"
Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object {$_.ServerAddresses} | ForEach-Object {
    Add-Line "  $($_.InterfaceAlias): $($_.ServerAddresses -join ', ')"
}

# Basic connectivity
Add-Line ""
Add-Line "Connectivity Test:"
$pingGoogle = Test-Connection -ComputerName "8.8.8.8" -Count 2 -ErrorAction SilentlyContinue
if ($pingGoogle) {
    $avgLatency = ($pingGoogle | Measure-Object ResponseTime -Average).Average
    Add-Line "  Internet (8.8.8.8) : [OK] Avg latency $([math]::Round($avgLatency,1))ms"
} else {
    Add-Line "  Internet (8.8.8.8) : [WARNING] No response - possible connectivity issue"
}

# ============================================================
#  SECTION 11: SECURITY OVERVIEW
# ============================================================
Write-Host "  Checking security..." -ForegroundColor Cyan
Add-Section "SECURITY OVERVIEW"

# Windows Defender
$defenderStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
if ($defenderStatus) {
    Add-Line "Windows Defender:"
    Add-Line "  Real-time Protection : $(if($defenderStatus.RealTimeProtectionEnabled){'[ON]'}else{'[OFF] WARNING'})"
    Add-Line "  Antivirus Enabled    : $(if($defenderStatus.AntivirusEnabled){'[OK]'}else{'[WARNING] Disabled'})"
    Add-Line "  Antispyware Enabled  : $(if($defenderStatus.AntispywareEnabled){'[OK]'}else{'[WARNING] Disabled'})"
    Add-Line "  Last Scan            : $($defenderStatus.LastFullScanEndTime)"
    Add-Line "  Signature Age        : $($defenderStatus.AntivirusSignatureAge) days"
    if ($defenderStatus.AntivirusSignatureAge -gt 7) {
        Add-Line "  STATUS               : [WARNING] Virus signatures are outdated"
    }
}

# Firewall
$fw = Get-NetFirewallProfile -ErrorAction SilentlyContinue
if ($fw) {
    Add-Line ""
    Add-Line "Firewall Status:"
    $fw | ForEach-Object {
        Add-Line ("  {0,-15}: {1}" -f $_.Name, $(if($_.Enabled){"[ON]"}else{"[OFF] WARNING"}))
    }
}

# UAC
$uac = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -ErrorAction SilentlyContinue
Add-Line ""
Add-Line "UAC Status       : $(if($uac.EnableLUA -eq 1){'[OK] Enabled'}else{'[WARNING] Disabled'})"

# ============================================================
#  SECTION 12: POWER SETTINGS
# ============================================================
Add-Section "POWER CONFIGURATION"

$powerPlan = powercfg /getactivescheme 2>&1
Add-Line "Active Power Plan: $powerPlan"

$batteryReport = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
if ($batteryReport) {
    Add-Line "Battery Status   : $($batteryReport.Caption) - Charge: $($batteryReport.EstimatedChargeRemaining)%"
}

# ============================================================
#  SECTION 13: INSTALLED SOFTWARE SUMMARY
# ============================================================
Add-Section "INSTALLED SOFTWARE (Key Applications)"

$software = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
    Where-Object {$_.DisplayName} |
    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
    Sort-Object DisplayName

Add-Line "Total installed applications: $($software.Count)"
Add-Line ""
$software | Select-Object -First 50 | ForEach-Object {
    Add-Line ("  {0,-50} v{1}" -f ($_.DisplayName -replace "[^\x20-\x7E]",""), $_.DisplayVersion)
}

# ============================================================
#  METRICS SNAPSHOT + BEFORE/AFTER (for JSON + optional compare)
# ============================================================
$volList = @(
    foreach ($k in ($script:volMetrics.Keys | Sort-Object)) {
        $script:volMetrics[$k]
    }
)

$currentMetrics = [ordered]@{
    schemaVersion   = 1
    generatedLocal  = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    generatedUtc    = (Get-Date).ToUniversalTime().ToString("o")
    pcDoctorVersion = "1.0"
    hostname        = $cs.Name
    cpu             = @{ loadPercent = [double]$cpuLoad }
    memory          = @{
        totalGB     = [double]$totalRAM
        usedGB      = [double]$usedRAM
        usedPercent = [double]$ramPct
        freeGB      = [double]$freeRAM
    }
    storage         = $script:storageMetrics
    volumes         = @($volList)
}

function Get-PCDoctorVolumeFromSnapshot($snapshot, $letter) {
    if (-not $snapshot -or -not $snapshot.volumes) { return $null }
    $target = [string]$letter
    foreach ($v in $snapshot.volumes) {
        if ($null -eq $v) { continue }
        if ([string]$v.letter -eq $target) { return $v }
    }
    return $null
}

function Format-MetricDelta($beforeVal, $afterVal, $unit, [int]$dec = 1) {
    if ($null -eq $beforeVal -or $null -eq $afterVal) { return "n/a" }
    try {
        $b = [double]$beforeVal
        $a = [double]$afterVal
        $d = [math]::Round($a - $b, $dec)
        $sign = ""
        if ($d -gt 0) { $sign = "+" }
        return ("{0}{1}{2}" -f $sign, $d, $unit)
    } catch {
        return "n/a"
    }
}

if ($CompareWithMetricsPath) {
    Add-Section "BEFORE / AFTER METRIC COMPARISON"
    if (-not $script:compareFromJson) {
        Add-Line "Compare request failed: the metrics file was missing, unreadable, or not valid JSON."
        Add-Line ("  Path: {0}" -f $CompareWithMetricsPath)
    } else {
        $b = $script:compareFromJson
        $bTime = if ($b.generatedLocal) { [string]$b.generatedLocal } elseif ($b.generatedUtc) { [string]$b.generatedUtc } else { "unknown" }
        Add-Line ("Baseline (before) captured: {0}" -f $bTime)
        Add-Line ("This run (after) captured:      {0}" -f $currentMetrics.generatedLocal)
        Add-Line ""
        if ($b.memory -and $currentMetrics.memory) {
            $mb = $b.memory
            $ma = $currentMetrics.memory
            Add-Line "Memory (RAM)"
            Add-Line ("  Used %     :  {0}%  ->  {1}%  (delta {2})" -f $mb.usedPercent, $ma.usedPercent, (Format-MetricDelta $mb.usedPercent $ma.usedPercent " pp" 1))
            Add-Line ("  Free GB    :  {0}  ->  {1}  (delta {2})" -f $mb.freeGB, $ma.freeGB, (Format-MetricDelta $mb.freeGB $ma.freeGB " GB" 1))
        }
        if ($b.cpu -and $currentMetrics.cpu) {
            $cb = $b.cpu.loadPercent
            $ca = $currentMetrics.cpu.loadPercent
            Add-Line "CPU (snapshot load; noisy metric)"
            Add-Line ("  Load %     :  {0}%  ->  {1}%  (delta {2})" -f $cb, $ca, (Format-MetricDelta $cb $ca " pp" 1))
        }
        if ($b.storage -and $currentMetrics.storage) {
            $sb = $b.storage
            $sa = $currentMetrics.storage
            Add-Line "Space hygiene (MB)"
            Add-Line ("  User temp  :  {0}  ->  {1}  (delta {2})" -f $sb.userTempMB, $sa.userTempMB, (Format-MetricDelta $sb.userTempMB $sa.userTempMB " MB" 0))
            Add-Line ("  Win temp   :  {0}  ->  {1}  (delta {2})" -f $sb.windowsTempMB, $sa.windowsTempMB, (Format-MetricDelta $sb.windowsTempMB $sa.windowsTempMB " MB" 0))
            Add-Line ("  Recycle    :  {0}  ->  {1}  (delta {2})" -f $sb.recycleBinMB, $sa.recycleBinMB, (Format-MetricDelta $sb.recycleBinMB $sa.recycleBinMB " MB" 0))
        }
        Add-Line ""
        Add-Line "Volumes (per drive letter; free space and reported fragmentation when available)"
        $seen = @{}
        foreach ($v in $volList) {
            if ($null -eq $v.letter) { continue }
            $L = [string]$v.letter
            if ($seen[$L]) { continue }
            $seen[$L] = $true
            $ob = Get-PCDoctorVolumeFromSnapshot $b $L
            $fBefore = if ($ob -and $null -ne $ob.freeGB) { $ob.freeGB } else { $null }
            $fAfter  = if ($null -ne $v.freeGB) { $v.freeGB } else { $null }
            $fbShow = if ($null -ne $fBefore) { [string]$fBefore } else { "n/a" }
            $faShow = if ($null -ne $fAfter) { [string]$fAfter } else { "n/a" }
            $fragB = if ($ob) { $ob.fragmentPercent } else { $null }
            $fragA = $v.fragmentPercent
            $fbF = if ($null -ne $fragB) { [string]$fragB } else { "n/a" }
            $faF = if ($null -ne $fragA) { [string]$fragA } else { "n/a" }
            Add-Line ("  Drive {0}:\  free GB   {1}  ->  {2}  (delta {3})" -f $L, $fbShow, $faShow, (Format-MetricDelta $fBefore $fAfter " GB" 1))
            if ($null -ne $fragB -or $null -ne $fragA) {
                Add-Line ("           frag %    {0}  ->  {1}  (delta {2})" -f $fbF, $faF, (Format-MetricDelta $fragB $fragA " pp" 1))
            }
        }
        Add-Line ""
        Add-Line "Note: take a new baseline with -SaveAsBaseline on the first run of a maintenance window, then re-run this script with -CompareWithMetricsPath to compare after changes."
    }
    Add-Line ""
}

# ============================================================
#  WRITE REPORT
# ============================================================
Add-Section "END OF DIAGNOSTIC REPORT"
Add-Line "Report generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add-Line "PC Doctor v1.0 - AI IT Support Agent"

$outputDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir -Force | Out-Null }

$jsonPath     = Join-Path $outputDir "pc-doctor_metrics.json"
$baselinePath = Join-Path $outputDir "pc-doctor_metrics_baseline.json"

$report | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
Write-Host "  Diagnostic report saved to: $OutputPath" -ForegroundColor Green

$htmlPath = Join-Path $outputDir "system_report.html"
if (-not $NoHtml) {
    try {
        $genAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Write-PcDoctorHtmlReport -Lines $report -HtmlPath $htmlPath -GeneratedLocal $genAt
        Write-Host "  HTML report saved to:        $htmlPath" -ForegroundColor Green
    } catch {
        Write-Host "  [WARNING] Could not write HTML report: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

try {
    $currentMetrics | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
    Write-Host "  Metrics JSON saved to:      $jsonPath" -ForegroundColor Green
} catch {
    Write-Host "  [WARNING] Could not write metrics JSON: $($_.Exception.Message)" -ForegroundColor Yellow
}

if ($SaveAsBaseline) {
    try {
        $currentMetrics | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $baselinePath -Encoding UTF8
        Write-Host "  Baseline metrics saved to:  $baselinePath" -ForegroundColor Green
    } catch {
        Write-Host "  [WARNING] Could not write baseline JSON: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
