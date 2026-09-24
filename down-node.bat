@echo off
chcp 65001 >nul
title ComfyUI node installer (Python)
rem ===================================================================
rem down-node.bat - thin wrapper: delegates to down-node.py
rem All logic (mirrors, plugin list, downloads) lives in down-node.py
rem ===================================================================
cd /d "%~dp0"
where python >nul 2>nul
if errorlevel 1 (
    echo [ERROR] python not found. Please install Python 3 first.
    pause
    exit /b 1
)
python -X utf8 "%~dp0down-node.py" %*
echo.
pause