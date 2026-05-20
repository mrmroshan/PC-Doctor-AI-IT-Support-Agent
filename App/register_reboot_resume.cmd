@echo off
REM Register a one-time launch of PC Doctor after the next user logon (used before Restart-Computer).
setlocal
cd /d "%~dp0"
call "%~dp0..\start.bat" --register-reboot
endlocal
exit /b %ERRORLEVEL%
