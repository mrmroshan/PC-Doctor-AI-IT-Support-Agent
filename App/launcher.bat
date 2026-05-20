REM SPDX-License-Identifier: AGPL-3.0-only
REM Copyright (c) 2026 Roshan Ruzaik
REM Part of PC Doctor - AI IT Support Agent

@echo off
setlocal EnableDelayedExpansion
set "SKIP_ADMIN_CHECK=0"
set "PC_DOCTOR_PREP_ONLY=0"
set "PC_DOCTOR_SKIP_CLAUDE_LAUNCH=0"
if /I "%~1"=="--register-reboot" goto :REGISTER_REBOOT
if /I "%~1"=="--clear-reboot-hook" goto :CLEAR_REBOOT_HOOK
if /I "%~1"=="--prep-only" (
    set "PC_DOCTOR_PREP_ONLY=1"
    set "PC_DOCTOR_SKIP_CLAUDE_LAUNCH=1"
    set "SKIP_ADMIN_CHECK=1"
    shift
)
if /I "%~1"=="--skip-admin-check" set "SKIP_ADMIN_CHECK=1"
if /I "%~1"=="--post-restart" (
    set "PC_DOCTOR_POST_RESTART=1"
    set "PC_DOCTOR_SKIP_ADMIN_CHECK=1"
    set "SKIP_ADMIN_CHECK=1"
    shift
)
if not defined PC_DOCTOR_POST_RESTART set "PC_DOCTOR_POST_RESTART=0"
title PC Doctor - AI-Powered IT Support Agent
chcp 65001 >nul
color 0A

:: ============================================================
::  PC DOCTOR - Powered by Claude Code
::  AI IT Helpdesk Agent (Supervised Mode)
::  Run as Administrator
:: ============================================================

echo.
echo  ================================================================
echo                      PC DOCTOR - IT SUPPORT AGENT
echo  ================================================================
echo.
echo                    AI-Powered IT Support Agent v1.0
echo                    Supervised Mode - Safe ^& Transparent
if "!PC_DOCTOR_POST_RESTART!"=="1" (
    echo  ** RESUMING AFTER RESTART - automatic one-time start **
)
echo  ================================================================
echo.

:: --- Admin check ---
if /I "%PC_DOCTOR_SKIP_ADMIN_CHECK%"=="1" set "SKIP_ADMIN_CHECK=1"
if "%SKIP_ADMIN_CHECK%"=="1" (
    echo  [INFO] Admin check skipped ^(debug mode^).
) else (
    net session >nul 2>&1
    if errorlevel 1 (
        echo  [ERROR] This script must be run as Administrator.
        echo  Right-click the file and select "Run as administrator"
        echo.
        pause
        exit /b 1
    )
    echo  [OK] Running with Administrator privileges.
)

:: --- Set app, project, and output directories ---
if defined PC_DOCTOR_ROOT (
    set "PROJECT_DIR=%PC_DOCTOR_ROOT%"
    set "APP_DIR=%PC_DOCTOR_ROOT%App\"
) else (
    set "APP_DIR=%~dp0"
    if "!APP_DIR!"=="" set "APP_DIR=%CD%\"
    if not "!APP_DIR:~-1!"=="\" set "APP_DIR=!APP_DIR!\"
    for %%I in ("!APP_DIR!..\") do set "PROJECT_DIR=%%~fI\"
)
if not "!PROJECT_DIR:~-1!"=="\" set "PROJECT_DIR=!PROJECT_DIR!\"
set "OUTPUTS_DIR=%PROJECT_DIR%outputs"
set "APP_RUNTIME_DIR=%APP_DIR%.runtime\"
if not exist "%OUTPUTS_DIR%" mkdir "%OUTPUTS_DIR%"
if not exist "%APP_RUNTIME_DIR%" mkdir "%APP_RUNTIME_DIR%"
set "WORK_DIR=%OUTPUTS_DIR%"
cd /d "%WORK_DIR%"

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set "DATESTAMP=%%I"
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "RUNSTAMP=%%I"
set "CONSOLE_LOG=%OUTPUTS_DIR%\console_output.txt"
(
    echo ============================================================
    echo PC Doctor launcher log started: %DATE% %TIME%
    echo Output folder: %OUTPUTS_DIR%
    echo ============================================================
) > "%CONSOLE_LOG%"

set "LOG_MSG=[INFO] Output folder set to: !OUTPUTS_DIR!"
call :Log
if "!PC_DOCTOR_POST_RESTART!"=="1" (
    set "LOG_MSG=[INFO] Post-restart automatic session (RunOnce) - will resume context after fresh diagnostics."
    call :Log
)

echo  [INFO] Working directory: %WORK_DIR%
echo.

:: --- Optional local secrets file (App-local only) ---
set "SECRETS_FILE=%APP_DIR%local.secrets.env"
if exist "%SECRETS_FILE%" (
    echo  [INFO] Loading local secrets from: %SECRETS_FILE%
    call :LoadSecrets "%SECRETS_FILE%"
)

:: --- LLM provider preset: PC_DOCTOR_LLM_PROVIDER=anthropic ^| deepseek (from local.secrets.env or environment) ---
if defined PC_DOCTOR_LLM_PROVIDER (
    if /I "!PC_DOCTOR_LLM_PROVIDER!"=="deepseek" (
        if not defined ANTHROPIC_BASE_URL (
            set "ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic"
            echo  [INFO] PC_DOCTOR_LLM_PROVIDER=deepseek — using DeepSeek gateway ^(!ANTHROPIC_BASE_URL!^).
            set "LOG_MSG=[INFO] PC_DOCTOR_LLM_PROVIDER=deepseek preset (ANTHROPIC_BASE_URL)."
            call :Log
        ) else (
            echo !ANTHROPIC_BASE_URL! | findstr /i "deepseek.com" >nul 2>&1
            if errorlevel 1 (
                echo  [WARN] PC_DOCTOR_LLM_PROVIDER=deepseek but ANTHROPIC_BASE_URL is not a DeepSeek host — leaving BASE_URL unchanged.
                call :Log "[WARN] PC_DOCTOR_LLM_PROVIDER=deepseek with non-DeepSeek ANTHROPIC_BASE_URL."
            )
        )
    ) else if /I "!PC_DOCTOR_LLM_PROVIDER!"=="anthropic" (
        if defined ANTHROPIC_BASE_URL (
            echo !ANTHROPIC_BASE_URL! | findstr /i "deepseek.com" >nul 2>&1
            if not errorlevel 1 (
                set "ANTHROPIC_BASE_URL="
                echo  [INFO] PC_DOCTOR_LLM_PROVIDER=anthropic — cleared DeepSeek ANTHROPIC_BASE_URL for native Anthropic routing.
                call :Log "[INFO] PC_DOCTOR_LLM_PROVIDER=anthropic: cleared DeepSeek ANTHROPIC_BASE_URL."
            )
        )
    ) else (
        echo  [WARN] Unknown PC_DOCTOR_LLM_PROVIDER=!PC_DOCTOR_LLM_PROVIDER! ^(use anthropic or deepseek^). Ignoring.
        call :Log "[WARN] Unknown PC_DOCTOR_LLM_PROVIDER."
    )
)

:: DeepSeek's Claude Code guide uses ANTHROPIC_AUTH_TOKEN; allow ANTHROPIC_API_KEY alone when BASE_URL points at DeepSeek.
if defined ANTHROPIC_BASE_URL (
    echo !ANTHROPIC_BASE_URL! | findstr /i "deepseek.com" >nul 2>&1
    if not errorlevel 1 (
        if not defined ANTHROPIC_AUTH_TOKEN (
            if defined ANTHROPIC_API_KEY set "ANTHROPIC_AUTH_TOKEN=!ANTHROPIC_API_KEY!"
        )
    )
)

if not "!PC_DOCTOR_POST_RESTART!"=="1" if exist "%WORK_DIR%\resume_bootstrap.txt" del /q "%WORK_DIR%\resume_bootstrap.txt" 2^>nul

:: ============================================================
::  STEP 1: Check and Install Node.js
:: ============================================================
echo  [STEP 1/4] Checking Node.js...
node --version >nul 2>&1
if errorlevel 1 (
    echo  [INFO] Node.js not found. Installing via winget...
    winget install --id OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        echo  [ERROR] Failed to install Node.js. Please install manually from https://nodejs.org
        pause
        exit /b 1
    )
    :: Refresh PATH
    call refreshenv >nul 2>&1
    set "PATH=%PATH%;C:\Program Files\nodejs"
    echo  [OK] Node.js installed successfully.
) else (
    for /f "tokens=*" %%v in ('node --version') do echo  [OK] Node.js %%v found.
)

:: ============================================================
::  STEP 2: Check and Install Claude Code
:: ============================================================
echo.
echo  [STEP 2/4] Checking Claude Code...
where claude >nul 2>&1
if errorlevel 1 (
    echo  [INFO] Claude Code not found in PATH. Installing...
    set "NPM_CMD="
    for /f "delims=" %%P in ('where npm.cmd 2^>nul') do (
        if not defined NPM_CMD set "NPM_CMD=%%P"
    )
    if not defined NPM_CMD (
        for /f "delims=" %%P in ('where npm 2^>nul') do (
            if not defined NPM_CMD set "NPM_CMD=%%P"
        )
    )
    if not defined NPM_CMD if exist "C:\Program Files\nodejs\npm.cmd" set "NPM_CMD=C:\Program Files\nodejs\npm.cmd"
    if not defined NPM_CMD if exist "%ProgramFiles%\nodejs\npm.cmd" set "NPM_CMD=%ProgramFiles%\nodejs\npm.cmd"
    if not defined NPM_CMD (
        echo  [ERROR] npm is not available in this shell.
        echo  Close this window, open a new Administrator CMD, then run start.bat again.
        pause
        exit /b 1
    )

    call "!NPM_CMD!" install -g @anthropic-ai/claude-code
    if errorlevel 1 (
        echo  [ERROR] Failed to install Claude Code.
        echo  Try running this manually:
        echo    "!NPM_CMD!" install -g @anthropic-ai/claude-code
        pause
        exit /b 1
    )

    :: Ensure common global npm bin path is visible in current session
    set "PATH=%PATH%;%AppData%\npm"
)

set "CLAUDE_VERSION="
for /f "delims=" %%v in ('claude --version 2^>nul') do (
    if not defined CLAUDE_VERSION set "CLAUDE_VERSION=%%v"
)

if not defined CLAUDE_VERSION (
    echo  [ERROR] Claude CLI is still unavailable after install attempt.
    echo  Run these in Administrator CMD:
    echo    where claude
    echo    npm config get prefix
    echo    set PATH=%%PATH%%;%%AppData%%\npm
    echo    claude --version
    pause
    exit /b 1
)

echo  [OK] Claude Code !CLAUDE_VERSION! found.

:: ============================================================
::  STEP 2.25: Ensure Git Bash for Claude on Windows
:: ============================================================
echo.
echo  [STEP 2.25/4] Checking Git Bash requirement...
set "GIT_BASH_PATH="
if defined CLAUDE_CODE_GIT_BASH_PATH if exist "%CLAUDE_CODE_GIT_BASH_PATH%" set "GIT_BASH_PATH=%CLAUDE_CODE_GIT_BASH_PATH%"
if not defined GIT_BASH_PATH if exist "C:\Program Files\Git\bin\bash.exe" set "GIT_BASH_PATH=C:\Program Files\Git\bin\bash.exe"
if not defined GIT_BASH_PATH if exist "C:\Program Files (x86)\Git\bin\bash.exe" set "GIT_BASH_PATH=C:\Program Files (x86)\Git\bin\bash.exe"
if not defined GIT_BASH_PATH (
    for /f "delims=" %%P in ('where bash.exe 2^>nul') do (
        if not defined GIT_BASH_PATH set "GIT_BASH_PATH=%%P"
    )
)

if not defined GIT_BASH_PATH (
    echo  [INFO] Git Bash not found. Installing Git for Windows via winget...
    winget install --id Git.Git --silent --accept-package-agreements --accept-source-agreements
    if errorlevel 1 (
        echo  [ERROR] Failed to install Git for Windows automatically.
        echo  Install manually from: https://git-scm.com/downloads/win
        echo  Then re-run start.bat.
        pause
        exit /b 1
    )
    if exist "C:\Program Files\Git\bin\bash.exe" set "GIT_BASH_PATH=C:\Program Files\Git\bin\bash.exe"
    if not defined GIT_BASH_PATH if exist "C:\Program Files (x86)\Git\bin\bash.exe" set "GIT_BASH_PATH=C:\Program Files (x86)\Git\bin\bash.exe"
)

if not defined GIT_BASH_PATH (
    echo  [ERROR] Git Bash is required by Claude Code on Windows but was not found.
    echo  Install Git for Windows: https://git-scm.com/downloads/win
    echo  If installed in a custom location, set:
    echo    setx CLAUDE_CODE_GIT_BASH_PATH "C:\Program Files\Git\bin\bash.exe" /M
    pause
    exit /b 1
)

set "CLAUDE_CODE_GIT_BASH_PATH=%GIT_BASH_PATH%"
echo  [OK] Using Git Bash: %CLAUDE_CODE_GIT_BASH_PATH%
set "LOG_MSG=[OK] Git Bash path set for Claude: !CLAUDE_CODE_GIT_BASH_PATH!"
call :Log

:: ============================================================
::  STEP 2.5: Validate API key / auth mode
:: ============================================================
echo.
echo  [STEP 2.5/4] Preparing authentication mode...
set "AUTH_MODE=Claude Console login - if already signed in"
set "DS_URL=0"
if defined ANTHROPIC_BASE_URL (
    echo !ANTHROPIC_BASE_URL! | findstr /i "deepseek.com" >nul 2>&1
    if not errorlevel 1 set "DS_URL=1"
)
if "!DS_URL!"=="1" (
    set "AUTH_MODE=DeepSeek API - Anthropic-compatible endpoint"
) else (
    if defined ANTHROPIC_API_KEY set "AUTH_MODE=Anthropic API key from environment/secrets file"
    if not defined ANTHROPIC_API_KEY if defined ANTHROPIC_AUTH_TOKEN set "AUTH_MODE=API token - ANTHROPIC_AUTH_TOKEN"
)
echo  [INFO] Auth mode: %AUTH_MODE%
if not defined ANTHROPIC_API_KEY if not defined ANTHROPIC_AUTH_TOKEN echo  [INFO] If launch fails, run: claude auth login
if "!DS_URL!"=="1" (
    if defined ANTHROPIC_AUTH_TOKEN if defined ANTHROPIC_API_KEY (
        echo  [INFO] DeepSeek: using ANTHROPIC_AUTH_TOKEN only for this session.
        set "ANTHROPIC_API_KEY="
        set "LOG_MSG=[INFO] Cleared ANTHROPIC_API_KEY to avoid auth conflict with ANTHROPIC_AUTH_TOKEN."
        call :Log
    )
)
set "LOG_MSG=[INFO] Authentication mode selected: !AUTH_MODE!"
call :Log

:: ============================================================
::  STEP 4: Prepare Claude Code session and launch PC Doctor
:: ============================================================
echo.
echo  [STEP 3/3] Starting PC Doctor in Claude Code...

set "PROMPT_FILE=!APP_DIR!agent_prompt.md"
if not exist "%PROMPT_FILE%" (
    echo  [ERROR] agent_prompt.md not found in App folder
    pause
    exit /b 1
)

if exist "%WORK_DIR%\agent_prompt.md" del /q "%WORK_DIR%\agent_prompt.md" >nul 2>&1
if exist "%WORK_DIR%\CLAUDE.md" del /q "%WORK_DIR%\CLAUDE.md" >nul 2>&1
if exist "%WORK_DIR%\.claude" rmdir /s /q "%WORK_DIR%\.claude" >nul 2>&1
if "!PC_DOCTOR_POST_RESTART!"=="1" call :PrepareResumeSession
call :PrepareClaudeSession

if "!PC_DOCTOR_POST_RESTART!"=="1" (
    echo  [INFO] Resuming after restart in 3 seconds... ^(close window to cancel^)
    timeout /t 3 /nobreak >nul
)

cd /d "%WORK_DIR%"
title PC Doctor - Claude Code
cls

:: App runtime instructions + pre-created session files.
if /I "!PC_DOCTOR_SKIP_CLAUDE_LAUNCH!"=="1" (
    echo  [INFO] Claude launch skipped ^(PC_DOCTOR_SKIP_CLAUDE_LAUNCH=1 or --prep-only^).
    set "CLAUDE_EXIT=0"
) else (
    :: cwd is outputs\. Strip trailing \ for --add-dir only (\" at end of path breaks cmd quoting).
    set "ADD_DIR=!PROJECT_DIR!"
    if "!ADD_DIR:~-1!"=="\" set "ADD_DIR=!ADD_DIR:~0,-1!"
    set "APP_ADD_DIR=!APP_DIR!"
    if "!APP_ADD_DIR:~-1!"=="\" set "APP_ADD_DIR=!APP_ADD_DIR:~0,-1!"
    set "APP_RUNTIME_ADD_DIR=!APP_RUNTIME_DIR!"
    if "!APP_RUNTIME_ADD_DIR:~-1!"=="\" set "APP_RUNTIME_ADD_DIR=!APP_RUNTIME_ADD_DIR:~0,-1!"
    set "CLAUDE_START=You are PC Doctor. Read ../App/.runtime/CLAUDE.md and ../App/.runtime/agent_prompt.md now. Follow them strictly. Send the short Phase 1 opening welcome, then wait for user input."
    claude --permission-mode acceptEdits --name "PC Doctor" --add-dir "!ADD_DIR!" --add-dir "!APP_ADD_DIR!" --add-dir "!APP_RUNTIME_ADD_DIR!" -- "!CLAUDE_START!"
    set "CLAUDE_EXIT=!ERRORLEVEL!"
)
if /I "!PC_DOCTOR_PREP_ONLY!"=="1" (
    echo.
    echo  [OK] Prep-only complete. Session outputs are in: %WORK_DIR%
    echo  [OK] Agent runtime files are in: %APP_RUNTIME_DIR%
    exit /b 0
)

if not "!CLAUDE_EXIT!"=="0" (
    echo.
    echo  [ERROR] Claude exited unexpectedly ^(exit code: !CLAUDE_EXIT!^).
    echo  Try one of these:
    echo    1^) Check App\local.secrets.env: Anthropic ANTHROPIC_API_KEY=sk-ant-... OR DeepSeek ANTHROPIC_BASE_URL + ANTHROPIC_AUTH_TOKEN ^(see README^)
    echo    2^) Run: claude auth login
    echo    3^) Run: claude -p "Respond only with: OK"
    pause
    exit /b !CLAUDE_EXIT!
)

echo.
echo  ================================================================
echo   PC Doctor session ended.
echo   Logs: %CONSOLE_LOG%
echo   Folder: %WORK_DIR%
echo  ================================================================
pause
exit /b 0

:: File-only audit log (no console echo — keeps the launcher UI clean).
:: Callers with paths or text containing parentheses must set LOG_MSG first, then call :Log.
:Log
if not defined LOG_MSG if not "%~1"=="" set "LOG_MSG=%~1"
if not defined LOG_MSG exit /b 0
if defined CONSOLE_LOG (
    >> "%CONSOLE_LOG%" echo [%DATE% %TIME%] !LOG_MSG!
)
set "LOG_MSG="
exit /b 0

:: Parse local.secrets.env: whitelist only Claude Code / gateway vars (see README, DeepSeek coding-agents guide).
:: Note: do not use setlocal/endlocal here — variables applied via the temp batch must persist in the launcher scope.
:LoadSecrets
set "SECRETS_PATH=%~1"
if not exist "%SECRETS_PATH%" exit /b 0
set "TMPBAT=%TEMP%\pc_doctor_secrets_%RANDOM%_%RANDOM%.bat"
>"%TMPBAT%" echo @echo off
for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%SECRETS_PATH%") do (
    call :ApplyWhitelistedSecret "%TMPBAT%" "%%~A" "%%~B"
)
call "%TMPBAT%"
del /q "%TMPBAT%" >nul 2>&1
exit /b 0

:ApplyWhitelistedSecret
set "SEC_TMPBAT=%~1"
set "SEC_KEY=%~2"
set "SEC_VAL=%~3"
if /I "%SEC_KEY%"=="ANTHROPIC_API_KEY" goto :ApplySecretWrite
if /I "%SEC_KEY%"=="ANTHROPIC_AUTH_TOKEN" goto :ApplySecretWrite
if /I "%SEC_KEY%"=="ANTHROPIC_BASE_URL" goto :ApplySecretWrite
if /I "%SEC_KEY%"=="ANTHROPIC_MODEL" goto :ApplySecretWrite
if /I "%SEC_KEY%"=="ANTHROPIC_DEFAULT_OPUS_MODEL" goto :ApplySecretWrite
if /I "%SEC_KEY%"=="ANTHROPIC_DEFAULT_SONNET_MODEL" goto :ApplySecretWrite
if /I "%SEC_KEY%"=="ANTHROPIC_DEFAULT_HAIKU_MODEL" goto :ApplySecretWrite
if /I "%SEC_KEY%"=="CLAUDE_CODE_SUBAGENT_MODEL" goto :ApplySecretWrite
if /I "%SEC_KEY%"=="CLAUDE_CODE_EFFORT_LEVEL" goto :ApplySecretWrite
if /I "%SEC_KEY%"=="PC_DOCTOR_LLM_PROVIDER" goto :ApplySecretWrite
if /I "%SEC_KEY%"=="PC_DOCTOR_SKIP_EXTERNAL_NETWORK_PROBES" goto :ApplySecretWrite
exit /b 0
:ApplySecretWrite
>>"%SEC_TMPBAT%" echo set "%SEC_KEY%=%SEC_VAL%"
exit /b 0

:: Newest pre-reboot artifacts in outputs (for resume_bootstrap).
:ResolveLatestResumeFiles
set "PREV_SESSION_REPORT="
set "PREV_TRANSCRIPT="
set "PC_DOCTOR_OUT=%WORK_DIR%"
for /f "usebackq delims=" %%F in (`powershell -NoProfile -Command "$d=$env:PC_DOCTOR_OUT; if ($d -and (Test-Path -LiteralPath $d)) { Get-ChildItem -LiteralPath $d -Filter 'session_report_*.txt' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName }"`) do set "PREV_SESSION_REPORT=%%F"
for /f "usebackq delims=" %%F in (`powershell -NoProfile -Command "$d=$env:PC_DOCTOR_OUT; if ($d -and (Test-Path -LiteralPath $d)) { Get-ChildItem -LiteralPath $d -Filter 'console_transcript_*.txt' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName }"`) do set "PREV_TRANSCRIPT=%%F"
set "PC_DOCTOR_OUT="
exit /b 0

:PrepareResumeSession
call :ResolveLatestResumeFiles
(
  echo # PC Doctor — handoff after planned restart
  echo.
  echo CONTINUITY (from before reboot — newest in outputs\):
  if defined PREV_SESSION_REPORT (
    echo   Previous session report: !PREV_SESSION_REPORT!
  ) else (
    echo   Previous session report: (not found — work from fresh data and the user^)
  )
  if defined PREV_TRANSCRIPT (
    echo   Previous console transcript: !PREV_TRANSCRIPT!
  ) else (
    echo   Previous console transcript: (not found^)
  )
  echo.
  echo   On resume, collect a fresh system_report.txt in this folder before analysis, then verify Hostname matches %COMPUTERNAME%.
  echo.
  echo AGENT TASK: Confirm restart, open previous session notes if available, re-check live metrics, do not repeat fixes already done.
) > "%WORK_DIR%\resume_bootstrap.txt"
set "LOG_MSG=[OK] Wrote resume_bootstrap.txt for post-restart handoff."
call :Log
exit /b 0

:: Claude Code project files in App\.runtime\ (CLAUDE.md, permissions).
:PrepareClaudeSession
set "CLAUDE_DIR=%APP_RUNTIME_DIR%\.claude"
if not exist "%CLAUDE_DIR%" mkdir "%CLAUDE_DIR%"
set "CLAUDE_SETTINGS_SRC=%APP_DIR%templates\claude-settings.json"
if exist "%CLAUDE_SETTINGS_SRC%" (
    copy /Y "%CLAUDE_SETTINGS_SRC%" "%CLAUDE_DIR%\settings.json" >nul
) else (
    set "LOG_MSG=[WARNING] templates\claude-settings.json missing; Claude may prompt for file edits."
    call :Log
)
if "!PC_DOCTOR_POST_RESTART!"=="1" (
    set "CLAUDE_MD_SRC=%APP_DIR%templates\outputs-CLAUDE-post-restart.md"
) else (
    set "CLAUDE_MD_SRC=%APP_DIR%templates\outputs-CLAUDE.md"
)
if exist "!CLAUDE_MD_SRC!" (
    copy /Y "!CLAUDE_MD_SRC!" "%APP_RUNTIME_DIR%\CLAUDE.md" >nul
) else (
    set "LOG_MSG=[WARNING] Claude template missing: !CLAUDE_MD_SRC!"
    call :Log
)
copy /Y "%PROMPT_FILE%" "%APP_RUNTIME_DIR%\agent_prompt.md" >nul
set "LOG_MSG=[OK] Claude session prepared in !WORK_DIR!"
call :Log
exit /b 0

:REGISTER_REBOOT
set "PC_REBOOT_TGT=!PROJECT_DIR!start.bat"
if not exist "%PC_REBOOT_TGT%" (
  echo  [ERROR] start.bat not found in project root.
  set "PC_REBOOT_TGT="
  exit /b 1
)
powershell -NoProfile -Command "try { $p = (Get-Item -LiteralPath $env:PC_REBOOT_TGT -ErrorAction Stop).FullName; $q = [char]34 + $p + [char]34 + ' --post-restart'; Set-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name 'PCDoctorSessionResume' -Value $q -Type String -Force; exit 0 } catch { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }"
set "REG_HOOK_EC=!ERRORLEVEL!"
set "PC_REBOOT_TGT="
if not "!REG_HOOK_EC!"=="0" (
  echo  [ERROR] Could not add RunOnce entry. Check that this account can write to HKCU.
  exit /b 1
)
echo  [OK] One-time start is registered. After the next user logon, this PC will launch PC Doctor again automatically.
echo  If the restart is cancelled, run: start.bat --clear-reboot-hook
exit /b 0

:CLEAR_REBOOT_HOOK
powershell -NoProfile -Command "try { Remove-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name 'PCDoctorSessionResume' -ErrorAction SilentlyContinue } catch { }; exit 0"
echo  [OK] Post-restart hook was cleared (if it had been set).
exit /b 0

