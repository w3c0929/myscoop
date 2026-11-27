@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: 检查管理员权限 mklink 需要
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 请以管理员身份运行此脚本！
    echo 右键该 bat 文件 - "以管理员身份运行"
    pause
    exit /b 1
)

:: ==============================================
:: 路径自动解析（兼容任意机器：不写死盘符与用户名）
::   Scoop 根目录：优先 %SCOOP% 环境变量 → 用户目录默认位置 → 全局默认位置
::   仓库根目录：本脚本所在目录（symlink.bat 位于 myscoop 仓库根）
::   config.json：%USERPROFILE%\.config\scoop\config.json
:: ==============================================
set "SCOOP_ROOT=%SCOOP%"
if not defined SCOOP_ROOT if exist "%USERPROFILE%\scoop\apps\scoop\current" set "SCOOP_ROOT=%USERPROFILE%\scoop"
if not defined SCOOP_ROOT if exist "%ProgramData%\scoop\apps\scoop\current" set "SCOOP_ROOT=%ProgramData%\scoop"
if not defined SCOOP_ROOT set "SCOOP_ROOT=%USERPROFILE%\scoop"
if "%SCOOP_ROOT:~-1%"=="\" set "SCOOP_ROOT=%SCOOP_ROOT:~0,-1%"

set "REPO=%~dp0"
if "%REPO:~-1%"=="\" set "REPO=%REPO:~0,-1%"
:: 从 shims 等处调用（非仓库根）时，回退到 Scoop 的标准 bucket 目录
if not exist "%REPO%\config.json" if exist "%SCOOP_ROOT%\buckets\myscoop\config.json" set "REPO=%SCOOP_ROOT%\buckets\myscoop"

set "SCOOP_CURRENT=%SCOOP_ROOT%\apps\scoop\current"
set "SCOOP_CONFIG=%USERPROFILE%\.config\scoop\config.json"
set "SHIMS_DIR=%SCOOP_ROOT%\shims"

echo.
echo Scoop 根目录：%SCOOP_ROOT%
echo 仓库根目录：%REPO%

:: ==============================================
:: 第一部分：Scoop 库文件软链接 链接方式替代覆盖
:: 格式："目标文件路径|仓库真实源文件路径"
:: ==============================================
echo.
echo ==============================================
echo 【1/3】Scoop 库文件软链接（manifest/download）
echo ==============================================

set "SCOOP_VER="
for /f "delims=" %%v in ('git -C "%SCOOP_CURRENT%" describe --tags --abbrev^=0 2^>nul') do set "SCOOP_VER=%%v"
set "BASELINE=unknown"
if exist "%REPO%\patches\baseline.txt" for /f "usebackq delims=" %%b in ("%REPO%\patches\baseline.txt") do set "BASELINE=%%b"

set "PATCH_SRC=%REPO%"
if not defined SCOOP_VER (
    echo 警告：未检测到 Scoop 版本（git 不可用或无标签），按最新基线使用根补丁
) else if /i "!SCOOP_VER!"=="!BASELINE!" (
    echo 使用根补丁（基线 !BASELINE!）
) else if exist "%REPO%\patches\!SCOOP_VER!\manifest.ps1" (
    set "PATCH_SRC=%REPO%\patches\!SCOOP_VER!"
    echo 使用 !SCOOP_VER! 专用补丁
) else (
    echo 警告：Scoop !SCOOP_VER! 无专用补丁（根补丁基线 !BASELINE!），可能不适用，建议更新仓库后重跑
)

for %%i in (
"%SCOOP_CURRENT%\lib\manifest.ps1|!PATCH_SRC!\manifest.ps1"
"%SCOOP_CURRENT%\lib\download.ps1|!PATCH_SRC!\download.ps1"
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
            )
            mklink "!DEST_FILE!" "!SRC_FILE!"
            if errorlevel 1 (
                echo  [失败] !DEST_FILE! 创建失败
            ) else (
                echo  [成功] 文件软链接生成完成
            )
        )
    )
)


:: ==============================================
:: 第二部分：config.json 镜像拷贝 真实文件，避免软链接崩溃
:: 目标文件以源为权威，每次运行脚本都把源当前内容覆盖到目标
:: 会把软链接删掉重建为普通文件 链接失效 拷贝则每次运行都重新同步为仓库版本
:: ==============================================
echo.
echo ==============================================
echo 【2/3】config.json 镜像拷贝（真实文件，避免软链接崩溃）
echo ==============================================
for %%i in (
"%SCOOP_CONFIG%|%REPO%\config.json"
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
            )
            copy /Y "!SRC_FILE!" "!DEST_FILE!" >nul
            if errorlevel 1 (
                echo  [失败] !DEST_FILE! 拷贝失败
            ) else (
                echo  [成功] !DEST_FILE! 镜像拷贝完成
            )
        )
    )
)

:: ==============================================
:: 第三部分：仓库 .bat → shims 链接
:: ==============================================
echo.
echo ==============================================
echo 【3/3】仓库 .bat -^> %SHIMS_DIR% 链接
echo ==============================================
set "SOURCE_DIR=%REPO%"
set "TARGET_DIR=%SHIMS_DIR%"

for %%F in ("%SOURCE_DIR%\*.bat") do (
    rem 跳过脚本自身
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
