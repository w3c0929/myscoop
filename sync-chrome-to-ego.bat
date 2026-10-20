@echo off
chcp 65001 >nul
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync-chrome-to-ego.ps1" %*
echo.
pause
endlocal
