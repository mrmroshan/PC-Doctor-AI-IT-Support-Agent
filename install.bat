@echo off
setlocal EnableDelayedExpansion
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
echo  ================================================================
echo.

:: --- Admin check ---
set "SKIP_ADMIN_CHECK=0"
if /I "%PC_DOCTOR_SKIP_ADMIN_CHECK%"=="1" set "SKIP_ADMIN_CHECK=1"
if /I "%~1"=="--skip-admin-check" set "SKIP_ADMIN_CHECK=1"
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

:: --- Set project and output directories ---
set "PROJECT_DIR=%~dp0"
set "OUTPUTS_DIR=%PROJECT_DIR%outputs"
if not exist "%OUTPUTS_DIR%" mkdir "%OUTPUTS_DIR%"
set "WORK_DIR=%OUTPUTS_DIR%"
cd /d "%WORK_DIR%"

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set "DATESTAMP=%%I"
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "RUNSTAMP=%%I"
set "CONSOLE_LOG=%OUTPUTS_DIR%\console_output.txt"
set "TRANSCRIPT_FILE=%OUTPUTS_DIR%\console_transcript_%RUNSTAMP%.txt"
set "SESSION_REPORT_FILE=%OUTPUTS_DIR%\session_report_%RUNSTAMP%.txt"
set "INIT_MSG_FILE=%OUTPUTS_DIR%\init_message_%RUNSTAMP%.txt"
(
    echo ============================================================
    echo PC Doctor launcher log started: %DATE% %TIME%
    echo Output folder: %OUTPUTS_DIR%
    echo ============================================================
) > "%CONSOLE_LOG%"

call :Log "[INFO] Output folder set to: %OUTPUTS_DIR%"

echo  [INFO] Working directory: %WORK_DIR%
echo.

:: --- Optional local secrets file (project-only) ---
set "SECRETS_FILE=%PROJECT_DIR%local.secrets.env"
if exist "%SECRETS_FILE%" (
    echo  [INFO] Loading local secrets from: %SECRETS_FILE%
    setlocal DisableDelayedExpansion
    for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%SECRETS_FILE%") do (
        if /I "%%A"=="ANTHROPIC_API_KEY" (
            endlocal
            set "ANTHROPIC_API_KEY=%%B"
            setlocal DisableDelayedExpansion
        )
    )
    endlocal
)

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
        echo  Close this window, open a new Administrator CMD, then run install.bat again.
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
::  STEP 2.5: Validate API key / auth mode
:: ============================================================
echo.
echo  [STEP 2.5/4] Preparing authentication mode...
set "AUTH_MODE=Claude Console login ^(if already signed in^)"
if defined ANTHROPIC_API_KEY set "AUTH_MODE=API key from environment/secrets file"
echo  [INFO] Auth mode: %AUTH_MODE%
if not defined ANTHROPIC_API_KEY echo  [INFO] If launch fails, run: claude auth login
call :Log "[INFO] Authentication mode selected: %AUTH_MODE%"

:: ============================================================
::  STEP 3: Run System Diagnostics
:: ============================================================
echo.
echo  [STEP 3/4] Preparing system diagnostic report...

:: Copy the PowerShell diagnostic script to working directory
set "PS_SCRIPT=%~dp0diagnose.ps1"
set "REPORT_PATH=%WORK_DIR%\system_report.txt"
if not exist "%PS_SCRIPT%" (
    echo  [ERROR] diagnose.ps1 not found next to install.bat
    echo  Make sure all 3 files are in the same folder.
    pause
    exit /b 1
)

if exist "%REPORT_PATH%" (
    for %%I in ("%REPORT_PATH%") do set "REPORT_SIZE=%%~zI"
    if !REPORT_SIZE! GTR 0 (
        echo  [INFO] Existing report found: %REPORT_PATH%
        set "REUSE_REPORT=Y"
        set /p REUSE_REPORT=  Reuse existing report and skip diagnostics? [Y/n]: 
        if "!REUSE_REPORT!"=="" set "REUSE_REPORT=Y"
        if /I not "!REUSE_REPORT!"=="N" (
            echo  [OK] Reusing existing system report.
            goto :REPORT_READY
        )
    )
)

echo  [INFO] Collecting system health data...
powershell.exe -ExecutionPolicy Bypass -File "%PS_SCRIPT%" -OutputPath "%REPORT_PATH%"

if not exist "%REPORT_PATH%" (
    echo  [ERROR] Diagnostic report was not generated.
    pause
    exit /b 1
)
for %%I in ("%REPORT_PATH%") do set "REPORT_SIZE=%%~zI"
if "%REPORT_SIZE%"=="0" (
    echo  [ERROR] Diagnostic report file is empty: %REPORT_PATH%
    echo  This usually means diagnostics failed mid-run.
    echo  Re-run install.bat and choose to regenerate the report.
    pause
    exit /b 1
)

:REPORT_READY
echo  [OK] System report ready: %REPORT_PATH%
call :Log "[OK] System report ready: %REPORT_PATH%"
echo.

:: ============================================================
::  STEP 4: Copy Persona Prompt and Launch Agent
:: ============================================================
echo  [STEP 4/4] Launching AI IT Support Agent...

set "PROMPT_FILE=%~dp0agent_prompt.md"
if not exist "%PROMPT_FILE%" (
    echo  [ERROR] agent_prompt.md not found next to install.bat
    pause
    exit /b 1
)

:: Copy prompt to working dir
copy "%PROMPT_FILE%" "%WORK_DIR%\agent_prompt.md" >nul

:: Keep a copy of startup instructions in outputs folder for traceability
(
    echo Read the file agent_prompt.md to understand your role and behavior rules.
    echo Then read system_report.txt which contains the full diagnostic data for this PC.
    echo.
    echo IMPORTANT LOGGING REQUIREMENTS:
    echo 1^) Maintain a running conversation transcript file at:
    echo    %TRANSCRIPT_FILE%
    echo 2^) Include both USER and ASSISTANT messages in chronological order.
    echo 3^) At the end of session ^(or ABORT^), write a session report to:
    echo    %SESSION_REPORT_FILE%
    echo 4^) Session report must include: issues found, actions taken, commands run, results, skipped items, and recommended next steps.
    echo.
    echo Begin your analysis now. Follow the supervised workflow exactly as described in agent_prompt.md.
    echo Start by introducing yourself briefly, then present your first finding.
) > "%INIT_MSG_FILE%"

echo.
echo  ================================================================
echo   LAUNCHING PC DOCTOR AGENT
echo   - The agent will analyze your system report
echo   - It will present issues one by one
echo   - You will approve or skip each fix
echo   - Type YES to fix, SKIP to skip, ABORT to stop
echo  ================================================================
echo.
pause

:: Launch Claude Code with the system prompt and report
cd /d "%WORK_DIR%"

set "INIT_PROMPT=Read the file agent_prompt.md, then read system_report.txt. Maintain a running transcript in %TRANSCRIPT_FILE% with both USER and ASSISTANT messages. At session end, write a full session report to %SESSION_REPORT_FILE% including issues, fixes, commands, results, skipped items, and next steps. Follow supervised workflow exactly and start with your first finding."

:: IMPORTANT: Do not redirect stdin here; Claude's interactive UI requires raw TTY input.
claude "%INIT_PROMPT%"
if errorlevel 1 (
    echo.
    echo  [ERROR] Claude exited unexpectedly.
    echo  Try one of these:
    echo    1^) Check key in local.secrets.env (ANTHROPIC_API_KEY=sk-ant-...)
    echo    2^) Run: claude auth login
    echo    3^) Run: claude -p "Respond only with: OK"
    pause
    exit /b 1
)

if not exist "%TRANSCRIPT_FILE%" (
    call :Log "[WARNING] Transcript file not found after session: %TRANSCRIPT_FILE%"
) else (
    call :Log "[OK] Transcript file created: %TRANSCRIPT_FILE%"
)
if not exist "%SESSION_REPORT_FILE%" (
    call :Log "[WARNING] Session report file not found after session: %SESSION_REPORT_FILE%"
) else (
    call :Log "[OK] Session report file created: %SESSION_REPORT_FILE%"
)

echo.
echo  ================================================================
echo   PC Doctor session ended. Check %WORK_DIR% for logs.
echo  ================================================================
pause
exit /b 0

:Log
set "LOG_MSG=%~1"
echo %LOG_MSG%
>> "%CONSOLE_LOG%" echo [%DATE% %TIME%] %LOG_MSG%
exit /b 0
