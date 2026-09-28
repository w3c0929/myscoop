@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: 检查管理员权限（mklink 需要）
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 请以管理员身份运行此脚本！
    echo 右键该 bat 文件 - "以管理员身份运行"
    pause
    exit /b 1
)

:: ==============================================
:: 第一部分：Scoop 部署文件软链接（链接方式替代覆盖）
:: 格式："目标文件路径|仓库真实源文件路径"
:: ==============================================
echo ==============================================
echo 【1/2】Scoop 部署文件软链接（manifest/download/config）
echo ==============================================
for %%i in (
"D:\scoop\apps\scoop\current\lib\manifest.ps1|D:\scoop\buckets\myscoop\manifest.ps1"
"D:\scoop\apps\scoop\current\lib\download.ps1|D:\scoop\buckets\myscoop\download.ps1"
"C:\Users\Administrator\.config\scoop\config.json|D:\scoop\buckets\myscoop\config.json"
) do (
    set "pair=%%~i"
    for /f "tokens=1,2 delims=^|" %%a in ("!pair!") do (
        set "DEST_FILE=%%a"
        set "SRC_FILE=%%b"
        echo.
        echo 处理文件：!SRC_FILE!
        if not exist "!SRC_FILE!" (
            echo  跳过：源文件不存在 !SRC_FILE!
        ) else (
            if exist "!DEST_FILE!" (
                echo  删除旧文件 !DEST_FILE!
                del /f /q "!DEST_FILE!"
                if errorlevel 1 (
                    echo  [警告] 删除失败，请手动清理 !DEST_FILE!
                )
            )
            mklink "!DEST_FILE!" "!SRC_FILE!"
            if errorlevel 1 (
                echo  [失败] !DEST_FILE! 创建失败
            ) else (
                echo  [成功] 文件软链接生成完成：!DEST_FILE!
            )
        )
    )
)

:: ==============================================
:: 第二部分：仓库 .bat → shims 链接
:: ==============================================
echo.
echo ==============================================
echo 【2/2】仓库 .bat -^> D:\scoop\shims 链接
echo ==============================================
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

echo.
echo ==============================================
echo 所有任务完成
echo ==============================================
pause
endlocal