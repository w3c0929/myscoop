@echo off
chcp 65001 >nul
setlocal
rem One-click: sync Chrome data (bookmarks/cookies/history/passwords) and extensions
rem to ego lite, then launch ego with all extensions.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync-chrome-to-ego.ps1" %*
echo.
pause
endlocal
