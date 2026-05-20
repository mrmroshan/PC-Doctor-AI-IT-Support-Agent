@echo off
setlocal
set "ROOT=%~dp0"
if "%ROOT%"=="" set "ROOT=%CD%\"
if not "%ROOT:~-1%"=="\" set "ROOT=%ROOT%\"
set "APP=%ROOT%App\"
set "OUTPUTS=%ROOT%outputs"
set "PC_DOCTOR_ROOT=%ROOT%"
if not exist "%OUTPUTS%" mkdir "%OUTPUTS%"
if not exist "%APP%launcher.bat" (
  echo [ERROR] App\launcher.bat not found.
  pause
  exit /b 1
)
call "%APP%launcher.bat" %*
endlocal
exit /b %ERRORLEVEL%
