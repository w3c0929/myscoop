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
:: 第一部分：Scoop 库文件软链接 链接方式替代覆盖 
:: 格式："目标文件路径|仓库真实源文件路径"
:: ==============================================
echo.
echo ==============================================
echo 【1/3】Scoop 库文件软链接（manifest/download）
echo ==============================================

set "REPO=D:\scoop\buckets\myscoop"
set "SCOOP_VER="
for /f "delims=" %%v in ('git -C "D:\scoop\apps\scoop\current" describe --tags --abbrev^=0 2^>nul') do set "SCOOP_VER=%%v"
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
"D:\scoop\apps\scoop\current\lib\manifest.ps1|!PATCH_SRC!\manifest.ps1"
"D:\scoop\apps\scoop\current\lib\download.ps1|!PATCH_SRC!\download.ps1"
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

:: 让 git 忽略这两个文件的 类型变更file symlink
:: 否则 scoop update 自更新时 git diff 会检测到改动，可能中止或报 CommitHash 为空而失败
git -C "D:\scoop\apps\scoop\current" update-index --skip-worktree lib\manifest.ps1 lib\download.ps1 >nul 2>&1
if errorlevel 1 (
    echo  [提示] git skip-worktree 设置失败（补丁仍生效，但 scoop update 可能报错）
) else (
    echo  [成功] 已设置 git skip-worktree（scoop update 不再受补丁链接影响）
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
echo 【3/3】仓库 .bat -^> D:\scoop\shims 链接
echo ==============================================
set "SOURCE_DIR=D:\scoop\buckets\myscoop"
set "TARGET_DIR=D:\scoop\shims"

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
