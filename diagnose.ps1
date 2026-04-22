# ============================================================
#  PC DOCTOR - System Diagnostics Collector
#  Collects comprehensive system health data
#  Output: system_report.txt
# ============================================================

param(
    [string]$OutputPath = "$env:TEMP\pc-doctor\system_report.txt"
)

$ErrorActionPreference = "SilentlyContinue"
$report = @()

function Add-Section($title) {
    $script:report += ""
    $script:report += "=" * 60
    $script:report += "  $title"
    $script:report += "=" * 60
}

function Add-Line($line) {
    $script:report += $line
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
#  WRITE REPORT
# ============================================================
Add-Section "END OF DIAGNOSTIC REPORT"
Add-Line "Report generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add-Line "PC Doctor v1.0 - AI IT Support Agent"

$outputDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir -Force | Out-Null }

$report | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
Write-Host "  Diagnostic report saved to: $OutputPath" -ForegroundColor Green
