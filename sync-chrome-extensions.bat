@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

rem ============================================================
rem  ego lite launcher: start ego and load ALL extensions
rem  from D:\scoop\persist\egolite-ext
rem
rem  - If the extension folder is missing/empty, it auto-syncs
rem    from Chrome first (calls sync-chrome-extensions.ps1).
rem  - Chromium --load-extension is session-only, so every start
rem    needs this bat / the shortcut with arguments.
rem ============================================================

set "EXTDIR=D:\scoop\persist\egolite-ext"
set "EGO=D:\scoop\apps\egolite\current\ego.exe"
set "PS1=%~dp0sync-chrome-extensions.ps1"

if not exist "%EGO%" (
    echo [ERROR] ego.exe not found: %EGO%
    pause
    exit /b 1
)

rem --- check whether extensions are present ---
set "HAS_EXT="
if exist "%EXTDIR%" (
    for /d %%d in ("%EXTDIR%\*") do set "HAS_EXT=1"
)

if not defined HAS_EXT (
    echo [INFO] Extensions not found, syncing from Chrome ...
    if not exist "%PS1%" (
        echo [ERROR] missing: %PS1%
        pause
        exit /b 1
    )
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -NoLaunch
    if errorlevel 1 (
        echo [ERROR] sync failed, see messages above
        pause
        exit /b 1
    )
)

rem --- build extension list ---
set "EXTS="
for /d %%d in ("%EXTDIR%\*") do (
    if defined EXTS (
        set "EXTS=!EXTS!,%%~fd"
    ) else (
        set "EXTS=%%~fd"
    )
)
if not defined EXTS (
    echo [ERROR] no extension folders under %EXTDIR%
    pause
    exit /b 1
)

rem --- restart ego with all extensions ---
echo Closing running ego ...
taskkill /f /im ego.exe >nul 2>&1
ping -n 3 127.0.0.1 >nul

echo Starting ego lite with extensions ...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%EGO%' -ArgumentList '--load-extension=%EXTS%'"
echo Done. Extensions may take a few seconds to load.
ping -n 3 127.0.0.1 >nul
endlocal
