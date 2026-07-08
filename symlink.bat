@echo off
setlocal enabledelayedexpansion

set "SOURCE_DIR=D:\scoop\buckets\myscoop"
set "TARGET_DIR=D:\scoop\shims"

for %%F in ("%SOURCE_DIR%\*.bat") do (
    :: 跳过脚本自身
    if /i not "%%~fF"=="%~f0" (
        set "link=%TARGET_DIR%\%%~nxF"
        if exist "!link!" del "!link!" 2>nul
        mklink "!link!" "%%F"
        if errorlevel 1 (
            echo %%~nxF
        ) else (
            echo %%~nxF  -^> !link!
        )
    )
)
pause