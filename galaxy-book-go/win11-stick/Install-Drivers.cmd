@echo off
rem After Windows is installed: double-click to install every remaining driver, then restart.
net session >nul 2>&1 || (
  powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
  exit /b
)
pnputil /add-driver "%~dp0GBGo-Drivers\*.inf" /subdirs /install
choice /m "Restart now to finish"
if errorlevel 2 exit /b
shutdown /r /t 0
