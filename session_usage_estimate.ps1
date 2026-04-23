# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (c) 2026 Roshan Ruzaik
# Part of PC Doctor - AI IT Support Agent
#
# Post-session ESTIMATES of token volume and USD cost for technicians.
# Billed usage: always verify in the Anthropic Console / usage dashboard.

param(
    [Parameter(Mandatory = $true)]
    [string]$WorkDir,
    [Parameter(Mandatory = $true)]
    [string]$RunStamp,
    [double]$InputUsdPerMtok = 0,
    [double]$OutputUsdPerMtok = 0,
    [int]$CliOverheadTokens = 650
)

$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)

$WorkDirResolved = [System.IO.Path]::GetFullPath($WorkDir)
if (-not (Test-Path -LiteralPath $WorkDirResolved -PathType Container)) {
    Write-Host "  [ERROR] WorkDir is not a directory: $WorkDir" -ForegroundColor Red
    exit 1
}
$WorkDir = $WorkDirResolved

function Get-TextLen([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return 0 }
    return [System.IO.File]::ReadAllText($path, $utf8).Length
}

function Get-TokensFromChars([long]$chars) {
    if ($chars -le 0) { return [long]0 }
    return [long][math]::Ceiling($chars / 4.0)
}

# Optional pricing file: only fills rates that were not set via parameters (> 0)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pricingFile = Join-Path $scriptDir 'pc-doctor-pricing.env'
$fileInput = $null
$fileOutput = $null
if (Test-Path -LiteralPath $pricingFile) {
    foreach ($line in Get-Content -LiteralPath $pricingFile) {
        if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
        $parts = $line -split '=', 2
        if ($parts.Count -lt 2) { continue }
        $k = $parts[0].Trim()
        $v = $parts[1].Trim()
        $d = 0.0
        if (-not [double]::TryParse($v, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { continue }
        if ($k -eq 'PC_DOCTOR_INPUT_USD_PER_MTOK') { $fileInput = $d }
        if ($k -eq 'PC_DOCTOR_OUTPUT_USD_PER_MTOK') { $fileOutput = $d }
    }
}
if ($InputUsdPerMtok -le 0 -and $null -ne $fileInput) { $InputUsdPerMtok = $fileInput }
if ($OutputUsdPerMtok -le 0 -and $null -ne $fileOutput) { $OutputUsdPerMtok = $fileOutput }
if ($InputUsdPerMtok -le 0) { $InputUsdPerMtok = 3.00 }
if ($OutputUsdPerMtok -le 0) { $OutputUsdPerMtok = 15.00 }

$reportPath = Join-Path $WorkDir 'system_report.txt'
$promptPath = Join-Path $WorkDir 'agent_prompt.md'
$initPath   = Join-Path $WorkDir "init_message_$RunStamp.txt"
$transcriptPath = Join-Path $WorkDir "console_transcript_$RunStamp.txt"
$htmlPath   = Join-Path $WorkDir 'system_report.html'

$cReport = Get-TextLen $reportPath
$cPrompt = Get-TextLen $promptPath
$cInit   = Get-TextLen $initPath
$cHtml   = Get-TextLen $htmlPath

$tReport = Get-TokensFromChars $cReport
$tPrompt = Get-TokensFromChars $cPrompt
$tInit   = Get-TokensFromChars $cInit

$ctxChars = $cReport + $cPrompt + $cInit
$ctxTokensFirstTurn = $tReport + $tPrompt + $tInit + $CliOverheadTokens

$cTrans = Get-TextLen $transcriptPath
$tTransRaw = Get-TokensFromChars $cTrans

$rawTrans = ''
if ($cTrans -gt 0) {
    $rawTrans = [System.IO.File]::ReadAllText($transcriptPath, $utf8)
}
$userTurns = 0
if ($rawTrans.Length -gt 0) {
    $userTurns = [regex]::Matches($rawTrans, '\[USER\]').Count
}

# Heuristic: assistant text is most of transcript; use 50-58% as output-ish for cost band
$outLowTok  = [math]::Ceiling($tTransRaw * 0.42)
$outHighTok = [math]::Ceiling($tTransRaw * 0.58)

# Context is re-sent on many turns in a long chat (simplified multiplier)
$ctxMultLow  = 1.0
$ctxMultHigh = 1.0 + [math]::Min(0.22 * [math]::Max(0, $userTurns - 1), 2.5)

$inMTokLow  = ($ctxTokensFirstTurn * $ctxMultLow) / 1.0e6
$inMTokHigh = ($ctxTokensFirstTurn * $ctxMultHigh) / 1.0e6
$outMTokLow  = $outLowTok / 1.0e6
$outMTokHigh = $outHighTok / 1.0e6

$costInOnlyLow  = $inMTokLow * $InputUsdPerMtok
$costInOnlyHigh = $inMTokHigh * $InputUsdPerMtok
if ($cTrans -le 0) {
    $costLow  = $costInOnlyLow
    $costHigh = $costInOnlyHigh
} else {
    $costLow  = $inMTokLow * $InputUsdPerMtok + $outMTokLow * $OutputUsdPerMtok
    $costHigh = $inMTokHigh * $InputUsdPerMtok + $outMTokHigh * $OutputUsdPerMtok
}

$outPath = Join-Path $WorkDir "session_usage_estimate_$RunStamp.txt"

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('============================================================')
[void]$sb.AppendLine('  PC DOCTOR - SESSION USAGE (ESTIMATES)')
[void]$sb.AppendLine('============================================================')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('IMPORTANT: Figures below are HEURISTICS for planning only.')
[void]$sb.AppendLine('Actual billed tokens and cost appear in your Anthropic account')
[void]$sb.AppendLine('(Console / usage / invoices). Claude Code may compact context.')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("Session stamp: $RunStamp")
[void]$sb.AppendLine("Pricing used:  input  `$$InputUsdPerMtok / 1M tokens")
[void]$sb.AppendLine("               output `$$OutputUsdPerMtok / 1M tokens")
[void]$sb.AppendLine('               (copy pc-doctor-pricing.env.example to pc-doctor-pricing.env to override)')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('--- Context files (approx. first full prompt budget) ---')
[void]$sb.AppendLine("  system_report.txt   chars: $cReport  ~tokens: $tReport  $(if (-not (Test-Path $reportPath)) { '(missing)' })")
[void]$sb.AppendLine("  agent_prompt.md     chars: $cPrompt  ~tokens: $tPrompt  $(if (-not (Test-Path $promptPath)) { '(missing)' })")
[void]$sb.AppendLine("  init_message        chars: $cInit   ~tokens: $tInit   $(if (-not (Test-Path $initPath)) { '(missing)' })")
[void]$sb.AppendLine("  nominal CLI overhead:     ~$CliOverheadTokens tokens")
[void]$sb.AppendLine("  SUM (first turn, est.):   ~$ctxTokensFirstTurn tokens")
if ($cHtml -gt 0) {
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("  Note: system_report.html ($cHtml chars) is NOT sent to the model; excluded above.")
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('--- Conversation transcript ---')
if ($cTrans -le 0) {
    [void]$sb.AppendLine('  (no transcript file or empty)')
} else {
    [void]$sb.AppendLine("  console_transcript chars: $cTrans  ~tokens if counted as raw text: $tTransRaw")
    [void]$sb.AppendLine("  [USER] markers (turns):   $userTurns")
    [void]$sb.AppendLine('  Heuristic output band:  ~' + $outLowTok + ' - ~' + $outHighTok + ' tokens')
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('--- Rough USD band (session) ---')
if ($cTrans -le 0) {
    [void]$sb.AppendLine('  No transcript: input-only band (assistant output not estimated).')
    [void]$sb.AppendLine(('  Lower ~$' + [math]::Round($costLow, 4) + '  |  Upper ~$' + [math]::Round($costHigh, 4) + '  (context re-send factor)'))
} else {
    [void]$sb.AppendLine(('  Lower ~$' + [math]::Round($costLow, 4) + '  (1x context send, modest output share)'))
    [void]$sb.AppendLine(('  Upper ~$' + [math]::Round($costHigh, 4) + '  (extra context turns factor up to ' + [math]::Round($ctxMultHigh, 2) + 'x, higher output share)'))
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('Token rule of thumb: ~1 token per 4 characters (English / mixed text).')
[void]$sb.AppendLine('============================================================')

$text = $sb.ToString()
[System.IO.File]::WriteAllText($outPath, $text, $utf8)

Write-Host $text -ForegroundColor Cyan
Write-Host "  Saved: $outPath" -ForegroundColor Green
