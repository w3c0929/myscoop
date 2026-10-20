@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

rem ============================================================
rem  ego lite 一键启动：自动加载 D:\scoop\persist\egolite-ext 下全部扩展
rem  （Chromium 的 --load-extension 是临时加载，必须每次启动带参数；
rem    本脚本拼接全部扩展路径并启动，避免逐个手动"加载未打包"）
rem  扩展文件更新：单独运行 sync-chrome-extensions.ps1
rem ============================================================

set "EXTDIR=D:\scoop\persist\egolite-ext"
set "EGO=D:\scoop\apps\egolite\current\ego.exe"

if not exist "%EGO%" (
    echo [错误] 未找到 ego.exe: %EGO%
    pause
    exit /b 1
)
if not exist "%EXTDIR%" (
    echo [错误] 未找到扩展目录: %EXTDIR%
    echo        请先运行 sync-chrome-extensions.ps1 同步 Chrome 扩展
    pause
    exit /b 1
)

set "EXTS="
for /d %%d in ("%EXTDIR%\*") do (
    if defined EXTS (
        set "EXTS=!EXTS!,%%~fd"
    ) else (
        set "EXTS=%%~fd"
    )
)
if not defined EXTS (
    echo [错误] %EXTDIR% 下没有扩展目录
    pause
    exit /b 1
)

echo 关闭正在运行的 ego（如有）...
taskkill /f /im ego.exe >nul 2>&1
rem 用 ping 代替 timeout（timeout 在输入被重定向时会直接报错）
ping -n 3 127.0.0.1 >nul

echo 启动 ego lite（加载 %EXTDIR% 下全部扩展）...
rem 用 PowerShell 启动：参数（逗号分隔长列表）传递最可靠，避免 start 的引号处理问题
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%EGO%' -ArgumentList '--load-extension=%EXTS%'"
echo 已启动。扩展可能需要几秒加载完成。
ping -n 3 127.0.0.1 >nul
endlocal
