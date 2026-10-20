@echo off
chcp 65001 >nul
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync-chrome-extensions.ps1" %*
echo.
pause
endlocal
