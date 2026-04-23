@echo off
REM One-shot resumer: registered in HKCU RunOnce by install.bat --register-reboot
setlocal
cd /d "%~dp0"
if not exist "%~dp0install.bat" (
  echo [ERROR] install.bat not found next to this file.
  pause
  exit /b 1
)
call "%~dp0install.bat" --post-restart
endlocal
exit /b %ERRORLEVEL%
