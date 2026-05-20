# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (c) 2026 Roshan Ruzaik
# Part of PC Doctor - AI IT Support Agent

param(
    [switch]$AsJson
)

$ErrorActionPreference = "SilentlyContinue"

$os = Get-CimInstance Win32_OperatingSystem
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$ramPct = 0
if ($os.TotalVisibleMemorySize -gt 0) {
    $used = $os.TotalVisibleMemorySize - $os.FreePhysicalMemory
    $ramPct = [math]::Round(($used / $os.TotalVisibleMemorySize) * 100, 1)
}

$defender = Get-MpComputerStatus
$firewallProfiles = Get-NetFirewallProfile
$spooler = Get-Service -Name Spooler

$snapshot = [ordered]@{
    Timestamp = (Get-Date).ToString("s")
    Hostname = $env:COMPUTERNAME
    OS = $os.Caption
    Build = $os.BuildNumber
    LastBoot = $os.LastBootUpTime
    CpuModel = $cpu.Name
    CDriveFreeGB = if ($disk.Size -gt 0) { [math]::Round($disk.FreeSpace / 1GB, 2) } else { 0 }
    CDriveUsedPct = if ($disk.Size -gt 0) { [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 1) } else { 0 }
    RamUsedPct = $ramPct
    DefenderRealtime = if ($null -ne $defender) { [bool]$defender.RealTimeProtectionEnabled } else { $false }
    FirewallEnabledProfiles = ($firewallProfiles | Where-Object Enabled -eq "True" | Select-Object -ExpandProperty Name)
    SpoolerStatus = if ($null -ne $spooler) { $spooler.Status.ToString() } else { "Unknown" }
}

if ($AsJson) {
    $snapshot | ConvertTo-Json -Depth 4
    exit 0
}

Write-Host "PC Doctor quick health snapshot" -ForegroundColor Cyan
Write-Host "Hostname       : $($snapshot.Hostname)"
Write-Host "OS             : $($snapshot.OS) (Build $($snapshot.Build))"
Write-Host "Last boot      : $($snapshot.LastBoot)"
Write-Host "CPU            : $($snapshot.CpuModel)"
Write-Host "C: free        : $($snapshot.CDriveFreeGB) GB"
Write-Host "C: used        : $($snapshot.CDriveUsedPct)%"
Write-Host "RAM used       : $($snapshot.RamUsedPct)%"
Write-Host "Defender RT    : $($snapshot.DefenderRealtime)"
Write-Host "Firewall       : $(([string]::Join(', ', $snapshot.FirewallEnabledProfiles)))"
Write-Host "Print spooler  : $($snapshot.SpoolerStatus)"
