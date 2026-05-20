@echo off
REM One-shot resumer: registered in HKCU RunOnce by start.bat --register-reboot
setlocal
cd /d "%~dp0"
if not exist "%~dp0..\start.bat" (
  echo [ERROR] start.bat not found in project root.
  pause
  exit /b 1
)
call "%~dp0..\start.bat" --post-restart
endlocal
exit /b %ERRORLEVEL%
