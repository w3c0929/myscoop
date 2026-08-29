<#
.SYNOPSIS
Scoop 工具箱：安装（管理员全局/普通用户）/ 导出备份 / 退出
默认安装路径：D:\scoop
导出恢复脚本规则：
1. 安装 Scoop 后自动安装 Git（使用 scoop install git）← 根据您的建议修改
2. 每个 Bucket 最多重试 3 次添加（含退出码+列表双重校验）
3. 任意 Bucket 3 次失败则脚本直接终止，不安装软件
4. 全部 Bucket 添加成功后，才执行软件恢复（带 bucket/软件名格式）
5. Scoop 本体和 main/extras/versions 仓库优先使用南京大学镜像，失败自动回退官方
#>

Clear-Host
Write-Host "==================== Scoop 工具箱 ====================" -ForegroundColor Cyan
Write-Host "请选择操作："
Write-Host "1. 管理员身份全局安装Scoop（所有用户共用，需要管理员权限）"
Write-Host "2. 当前普通用户安装Scoop（仅本账号可用，无需管理员）"
Write-Host "3. 导出当前Scoop备份（Bucket + 已装软件，自动带bucket前缀）"
Write-Host "4. 退出"
Write-Host "======================================================" -ForegroundColor Cyan
$select = Read-Host "输入数字 1、2、3 或 4"

$scoopPath = "D:\scoop"

# 公共前置：设置执行策略（当前用户）
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue

# ---- 辅助函数：设置 Scoop 本体仓库（镜像优先，失败回退官方） ----
function Set-ScoopRepoWithFallback {
    $mirror = "https://mirror.nju.edu.cn/git/scoop.git"
    $official = "https://github.com/ScoopInstaller/Scoop.git"
    Write-Host "正在设置 Scoop 本体更新源..." -ForegroundColor Cyan

    # 先设置镜像
    scoop config SCOOP_REPO $mirror 2>&1 | Out-Null
    Write-Host "已设置为本体源：$mirror" -ForegroundColor Gray

    # 简单测试镜像是否可达（使用 git ls-remote 检测）
    $testResult = git ls-remote $mirror 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "镜像源不可达，自动回退到官方源：$official" -ForegroundColor Yellow
        scoop config SCOOP_REPO $official 2>&1 | Out-Null
    } else {
        Write-Host "镜像源测试通过，保持当前配置。" -ForegroundColor Green
    }
}

if ($select -eq "1") {
    Write-Host "`n【已选择：管理员全局安装】" -ForegroundColor Green
    [Environment]::SetEnvironmentVariable('SCOOP', $scoopPath, 'User')
    $env:SCOOP = $scoopPath
    iex "& {$(Invoke-RestMethod get.scoop.sh)} -RunAsAdmin"
    # 设置本体仓库（带回退）
    Set-ScoopRepoWithFallback
    Write-Host "`n安装流程执行完毕，关闭终端重新打开即可使用 scoop 命令" -ForegroundColor Green
    pause
}
elseif ($select -eq "2") {
    Write-Host "`n【已选择：普通用户安装】" -ForegroundColor Green
    [Environment]::SetEnvironmentVariable('SCOOP', $scoopPath, 'User')
    $env:SCOOP = $scoopPath
    iex (Invoke-RestMethod get.scoop.sh)
    # 设置本体仓库（带回退）
    Set-ScoopRepoWithFallback
    Write-Host "`n安装流程执行完毕，关闭终端重新打开即可使用 scoop 命令" -ForegroundColor Green
    pause
}
elseif ($select -eq "3") {
    Write-Host "`n【已选择：导出Scoop备份，读取本地安装记录匹配Bucket】" -ForegroundColor Green

    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "错误：未检测到 scoop 命令，请先安装Scoop再导出备份" -ForegroundColor Red
        pause
        exit 1
    }

    Write-Host "1. 读取 scoop export 清单..." -ForegroundColor Cyan
    try {
        $exportRaw = scoop export 2>$null
        $exportData = $exportRaw | Out-String | ConvertFrom-Json
    } catch {
        Write-Host "导出失败：无法解析 scoop export 输出。错误：$_" -ForegroundColor Red
        pause
        exit 1
    }

    Write-Host "2. 遍历已安装软件，读取install.json获取所属Bucket..." -ForegroundColor Cyan
    $appBucketMap = @{}
    $userAppsPath = Join-Path $scoopPath "apps"
    $globalAppsPath = Join-Path $scoopPath "global\apps"

    Get-ChildItem $userAppsPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $appName = $_.Name
        $installJsonPath = Join-Path $_.FullName "current\install.json"
        if (Test-Path $installJsonPath) {
            try {
                $installInfo = Get-Content $installJsonPath -Raw | ConvertFrom-Json
                if ($installInfo.bucket) {
                    $appBucketMap[$appName] = $installInfo.bucket
                }
            } catch {}
        }
    }
    Get-ChildItem $globalAppsPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $appName = $_.Name
        $installJsonPath = Join-Path $_.FullName "current\install.json"
        if (Test-Path $installJsonPath) {
            try {
                $installInfo = Get-Content $installJsonPath -Raw | ConvertFrom-Json
                if ($installInfo.bucket) {
                    $appBucketMap[$appName] = $installInfo.bucket
                }
            } catch {}
        }
    }

    $outputLines = @()

    # ========== 优化后的恢复脚本头部（执行策略安全处理）==========
    $outputLines += '# 先设置执行策略，避免后续 $ErrorActionPreference="Stop" 导致脚本崩溃'
    $outputLines += 'try {'
    $outputLines += '    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop'
    $outputLines += '} catch {'
    $outputLines += '    Write-Host "注意：无法设置执行策略（可能被组策略覆盖）" -ForegroundColor Yellow'
    $outputLines += '    Write-Host "当前 CurrentUser 策略：$(Get-ExecutionPolicy -Scope CurrentUser)" -ForegroundColor Cyan'
    $outputLines += '}'
    $outputLines += ''
    $outputLines += '$ErrorActionPreference = "Stop"'
    $outputLines += "try {"
    $outputLines += '  Clear-Host'
    $outputLines += '  Write-Host "==================== Scoop 恢复工具 ====================" -ForegroundColor Cyan'
    $outputLines += '  $scoopPath = "D:\scoop"'
    $outputLines += ""
    $outputLines += '  # 检测Scoop是否已安装'
    $outputLines += '  if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {'
    $outputLines += '    Write-Host "未检测到Scoop，请先选择安装模式：" -ForegroundColor Yellow'
    $outputLines += '    Write-Host "1. 管理员身份全局安装（所有用户共用，需要管理员权限）"'
    $outputLines += '    Write-Host "2. 当前普通用户安装（仅本账号可用，无需管理员）"'
    $outputLines += '    Write-Host "3. 退出"'
    $outputLines += '    Write-Host "========================================================" -ForegroundColor Cyan'
    $outputLines += '    $installSelect = Read-Host "输入数字 1、2 或 3"'
    $outputLines += ""
    $outputLines += '    if ($installSelect -eq "1") {'
    $outputLines += '      Write-Host "`n【已选择：管理员全局安装】" -ForegroundColor Green'
    $outputLines += '      [Environment]::SetEnvironmentVariable("SCOOP", $scoopPath, "User")'
    $outputLines += '      $env:SCOOP = $scoopPath'
    $outputLines += '      iex "& {$(Invoke-RestMethod get.scoop.sh)} -RunAsAdmin"'
    $outputLines += '      $env:PATH = [Environment]::GetEnvironmentVariable("PATH","User") + ";" + [Environment]::GetEnvironmentVariable("PATH","Machine")'
    $outputLines += '    }'
    $outputLines += '    elseif ($installSelect -eq "2") {'
    $outputLines += '      Write-Host "`n【已选择：普通用户安装】" -ForegroundColor Green'
    $outputLines += '      [Environment]::SetEnvironmentVariable("SCOOP", $scoopPath, "User")'
    $outputLines += '      $env:SCOOP = $scoopPath'
    $outputLines += '      iex (Invoke-RestMethod get.scoop.sh)'
    $outputLines += '      $env:PATH = [Environment]::GetEnvironmentVariable("PATH","User") + ";" + [Environment]::GetEnvironmentVariable("PATH","Machine")'
    $outputLines += '    }'
    $outputLines += '    elseif ($installSelect -eq "3") {'
    $outputLines += '      Write-Host "`n【已选择：退出】" -ForegroundColor Yellow'
    $outputLines += '      exit 0'
    $outputLines += '    }'
    $outputLines += '    else {'
    $outputLines += '      Write-Host "输入错误，仅支持 1 / 2 / 3，脚本退出" -ForegroundColor Red'
    $outputLines += '      pause'
    $outputLines += '      exit 1'
    $outputLines += '    }'
    $outputLines += ""
    $outputLines += '    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {'
    $outputLines += '      Write-Host "错误：Scoop安装失败或环境变量未生效，请手动检查" -ForegroundColor Red'
    $outputLines += '      pause'
    $outputLines += '      exit 1'
    $outputLines += '    }'
    $outputLines += '  } else {'
    $outputLines += '    Write-Host "已检测到Scoop，跳过安装步骤" -ForegroundColor Green'
    $outputLines += '  }'
    $outputLines += ""
    # ---- 设置本体仓库（带镜像可达性测试和回退） ----
    $outputLines += '  Write-Host "设置 Scoop 本体更新源（优先南京大学镜像）..." -ForegroundColor Cyan'
    $outputLines += '  $mirror = "https://mirror.nju.edu.cn/git/scoop.git"'
    $outputLines += '  $official = "https://github.com/ScoopInstaller/Scoop.git"'
    $outputLines += '  scoop config SCOOP_REPO $mirror 2>&1 | Out-Null'
    $outputLines += '  Write-Host "已设置为本体源：$mirror" -ForegroundColor Gray'
    $outputLines += '  # 测试镜像可达性（需要 Git）'
    $outputLines += '  if (Get-Command git -ErrorAction SilentlyContinue) {'
    $outputLines += '    $testResult = git ls-remote $mirror 2>&1'
    $outputLines += '    if ($LASTEXITCODE -ne 0) {'
    $outputLines += '      Write-Host "镜像源不可达，自动回退到官方源：$official" -ForegroundColor Yellow'
    $outputLines += '      scoop config SCOOP_REPO $official 2>&1 | Out-Null'
    $outputLines += '    } else {'
    $outputLines += '      Write-Host "镜像源测试通过，保持当前配置。" -ForegroundColor Green'
    $outputLines += '    }'
    $outputLines += '  } else {'
    $outputLines += '    Write-Host "未检测到 Git，跳过镜像可达性测试，配置已设置为镜像。" -ForegroundColor Yellow'
    $outputLines += '  }'
    $outputLines += ""

    # ========== 关键改进：安装 Scoop 后立即安装 Git（使用 scoop install git）==========
    $outputLines += '  Write-Host "[前置] 检查 Git 是否可用..." -ForegroundColor Cyan'
    $outputLines += '  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {'
    $outputLines += '    Write-Host "未检测到 Git，将使用 Scoop 安装 Git..." -ForegroundColor Yellow'
    $outputLines += '    try {'
    $outputLines += '      scoop install git'
    $outputLines += '      if ($LASTEXITCODE -ne 0) { throw "scoop install git 失败，退出码 $LASTEXITCODE" }'
    $outputLines += '      # 刷新环境变量，使 Git 立即可用'
    $outputLines += '      $env:PATH = [Environment]::GetEnvironmentVariable("PATH","User") + ";" + [Environment]::GetEnvironmentVariable("PATH","Machine")'
    $outputLines += '      Write-Host "Git 安装成功！" -ForegroundColor Green'
    $outputLines += '    } catch {'
    $outputLines += '      Write-Host "Git 安装失败：$_" -ForegroundColor Red'
    $outputLines += '      Write-Host "请手动安装 Git（https://git-scm.com）后重新运行本脚本。" -ForegroundColor Yellow'
    $outputLines += '      pause'
    $outputLines += '      exit 1'
    $outputLines += '    }'
    $outputLines += '  } else {'
    $outputLines += '    Write-Host "Git 已就绪，继续。" -ForegroundColor Green'
    $outputLines += '  }'
    $outputLines += ""

    # ========== 步骤1：Bucket恢复（镜像优先，失败回退官方）==========
    $outputLines += '  Write-Host "[步骤1] 恢复所有Bucket仓库（每个最多重试3次，全部成功才继续软件安装）" -ForegroundColor Cyan'
    
    # 定义需要镜像优先的仓库列表及其镜像地址
    $mirrorBuckets = @{
        'main'     = 'https://mirror.nju.edu.cn/git/scoop-main.git'
        'extras'   = 'https://mirror.nju.edu.cn/git/scoop-extras.git'
        'versions' = 'https://mirror.nju.edu.cn/git/scoop-versions.git'
    }
    # 定义其他已知仓库（不带URL，使用官方）
    $knownBuckets = @('nirsoft','java','games','nerd-fonts')

    foreach ($bkt in $exportData.buckets) {
        $name = $bkt.Name
        $source = $bkt.Source

        if ($mirrorBuckets.ContainsKey($name)) {
            # ===== 特殊三个仓库：镜像优先，失败回退官方 =====
            $mirrorUrl = $mirrorBuckets[$name]
            $outputLines += "  # --- Bucket: $name (镜像优先，失败自动回退官方) ---"
            $outputLines += "  `$retryCount = 0"
            $outputLines += "  `$bucketAddSuccess = `$false"
            $outputLines += "  `$mirrorUrl = '$mirrorUrl'"
            $outputLines += "  `$useOfficial = `$false"
            $outputLines += ""
            $outputLines += "  while (`$retryCount -lt 3 -and !`$bucketAddSuccess) {"
            $outputLines += "    `$retryCount++"
            $outputLines += "    if (`$useOfficial) {"
            $outputLines += "      Write-Host ""尝试添加Bucket[$name]（官方源），第`$retryCount/3次"""
            $outputLines += "    } else {"
            $outputLines += "      Write-Host ""尝试添加Bucket[$name]（镜像源），第`$retryCount/3次"""
            $outputLines += "    }"
            $outputLines += "    try {"
            $outputLines += "      `$existingList = scoop bucket list 2>&1"
            $outputLines += "      if (`$existingList -match [regex]::Escape('$name')) {"
            $outputLines += "        Write-Host 'Bucket $name 已存在，无需重复添加' -ForegroundColor Green"
            $outputLines += "        `$bucketAddSuccess = `$true"
            $outputLines += "        continue"
            $outputLines += "      }"
            $outputLines += "      if (`$useOfficial) {"
            $outputLines += "        `$output = scoop bucket add $name 2>&1   # 不指定URL，使用官方"
            $outputLines += "      } else {"
            $outputLines += "        `$output = scoop bucket add $name `"`$mirrorUrl`" 2>&1"
            $outputLines += "      }"
            $outputLines += "      Write-Host `$output"
            $outputLines += "      if (`$LASTEXITCODE -ne 0) {"
            $outputLines += "        if (`$LASTEXITCODE -eq 2 -and `$output -match 'already exists') {"
            $outputLines += "          Write-Host 'Bucket $name 已存在（并发添加），视为成功' -ForegroundColor Green"
            $outputLines += "          `$bucketAddSuccess = `$true"
            $outputLines += "          continue"
            $outputLines += "        }"
            $outputLines += "        # 如果镜像失败且尚未切换官方，则切换到官方（不计入重试）"
            $outputLines += "        if (!`$useOfficial) {"
            $outputLines += "          `$useOfficial = `$true"
            $outputLines += "          `$retryCount--  # 不计入重试次数"
            $outputLines += "          Write-Host '镜像源连接失败，自动切换到官方源重试...' -ForegroundColor Yellow"
            $outputLines += "          continue"
            $outputLines += "        }"
            $outputLines += "        throw ""scoop 退出码: `$LASTEXITCODE"""
            $outputLines += "      }"
            $outputLines += "      `$bucketList = scoop bucket list 2>&1"
            $outputLines += "      if (-not (`$bucketList -match [regex]::Escape('$name'))) {"
            $outputLines += "        if (!`$useOfficial) {"
            $outputLines += "          `$useOfficial = `$true"
            $outputLines += "          `$retryCount--"
            $outputLines += "          Write-Host '镜像源验证失败，自动切换到官方源重试...' -ForegroundColor Yellow"
            $outputLines += "          continue"
            $outputLines += "        }"
            $outputLines += "        throw ""Bucket '$name' 不在列表中，添加无效"""
            $outputLines += "      }"
            $outputLines += "      `$bucketAddSuccess = `$true"
            $outputLines += "      Write-Host 'Bucket $name 添加成功' -ForegroundColor Green"
            $outputLines += "    } catch {"
            $outputLines += "      Write-Host ""Bucket $name 添加失败，错误原因：`$(`$_.Exception.Message)"" -ForegroundColor Red"
            $outputLines += "      if (!`$useOfficial) {"
            $outputLines += "        `$useOfficial = `$true"
            $outputLines += "        `$retryCount--"
            $outputLines += "        Write-Host '自动切换到官方源重试...' -ForegroundColor Yellow"
            $outputLines += "      }"
            $outputLines += "      if (`$retryCount -lt 3) {"
            $outputLines += "        Write-Host ""剩余重试次数：`$(3 - `$retryCount)"" -ForegroundColor Yellow"
            $outputLines += "        Start-Sleep -Seconds 2"
            $outputLines += "      }"
            $outputLines += "    }"
            $outputLines += "  }"
            $outputLines += "  if (!`$bucketAddSuccess) {"
            $outputLines += "    Write-Host '`n致命错误：Bucket $name 连续3次添加失败，终止整个恢复流程！' -ForegroundColor Red"
            $outputLines += "    pause"
            $outputLines += "    exit 1"
            $outputLines += "  }"
            $outputLines += ""

        } elseif ($name -in $knownBuckets) {
            # ===== 其他已知Bucket（官方源，不带URL） =====
            $outputLines += "  # --- Bucket: $name (known, official) ---"
            $outputLines += "  `$retryCount = 0"
            $outputLines += "  `$bucketAddSuccess = `$false"
            $outputLines += "  while (`$retryCount -lt 3 -and !`$bucketAddSuccess) {"
            $outputLines += "    `$retryCount++"
            $outputLines += "    Write-Host ""尝试添加Bucket[$name]，第`$retryCount/3次"""
            $outputLines += "    try {"
            $outputLines += "      `$existingList = scoop bucket list 2>&1"
            $outputLines += "      if (`$existingList -match [regex]::Escape('$name')) {"
            $outputLines += "        Write-Host 'Bucket $name 已存在，无需重复添加' -ForegroundColor Green"
            $outputLines += "        `$bucketAddSuccess = `$true"
            $outputLines += "        continue"
            $outputLines += "      }"
            $outputLines += "      `$output = scoop bucket add $name 2>&1"
            $outputLines += "      Write-Host `$output"
            $outputLines += "      if (`$LASTEXITCODE -ne 0) {"
            $outputLines += "        if (`$LASTEXITCODE -eq 2 -and `$output -match 'already exists') {"
            $outputLines += "          Write-Host 'Bucket $name 已存在（并发添加），视为成功' -ForegroundColor Green"
            $outputLines += "          `$bucketAddSuccess = `$true"
            $outputLines += "          continue"
            $outputLines += "        }"
            $outputLines += "        throw ""scoop 退出码: `$LASTEXITCODE"""
            $outputLines += "      }"
            $outputLines += "      `$bucketList = scoop bucket list 2>&1"
            $outputLines += "      if (-not (`$bucketList -match [regex]::Escape('$name'))) {"
            $outputLines += "        throw ""Bucket '$name' 不在列表中，添加无效"""
            $outputLines += "      }"
            $outputLines += "      `$bucketAddSuccess = `$true"
            $outputLines += "      Write-Host 'Bucket $name 添加成功' -ForegroundColor Green"
            $outputLines += "    } catch {"
            $outputLines += "      Write-Host ""Bucket $name 添加失败，错误原因：`$(`$_.Exception.Message)"" -ForegroundColor Red"
            $outputLines += "      if (`$retryCount -lt 3) {"
            $outputLines += "        Write-Host ""剩余重试次数：`$(3 - `$retryCount)"" -ForegroundColor Yellow"
            $outputLines += "        Start-Sleep -Seconds 2"
            $outputLines += "      }"
            $outputLines += "    }"
            $outputLines += "  }"
            $outputLines += "  if (!`$bucketAddSuccess) {"
            $outputLines += "    Write-Host '`n致命错误：Bucket $name 连续3次添加失败，终止整个恢复流程！' -ForegroundColor Red"
            $outputLines += "    pause"
            $outputLines += "    exit 1"
            $outputLines += "  }"
            $outputLines += ""

        } else {
            # ===== 自定义Bucket（保留原有SSH→HTTPS自动回退） =====
            $safeSource = $source -replace "'", "''"
            $outputLines += "  # --- Bucket: $name (custom, SSH→HTTPS auto-fallback) ---"
            $outputLines += "  `$retryCount = 0"
            $outputLines += "  `$bucketAddSuccess = `$false"
            $outputLines += "  `$source = '$safeSource'"
            $outputLines += "  `$httpsSource = ''"
            $outputLines += "  if (`$source -match '^git@([^:]+):(.+)$') {"
            $outputLines += "    `$httpsSource = 'https://' + `$Matches[1] + '/' + `$Matches[2]"
            $outputLines += "    Write-Host ""检测到SSH源，已准备HTTPS备选: `$httpsSource"" -ForegroundColor Cyan"
            $outputLines += "  }"
            $outputLines += "  `$currentSource = `$source"
            $outputLines += "  `$sshTried = `$false"
            $outputLines += ""
            $outputLines += "  while (`$retryCount -lt 3 -and !`$bucketAddSuccess) {"
            $outputLines += "    `$retryCount++"
            $outputLines += "    Write-Host ""尝试添加Bucket[$name]，第`$retryCount/3次（源: `$currentSource）"""
            $outputLines += "    try {"
            $outputLines += "      `$existingList = scoop bucket list 2>&1"
            $outputLines += "      if (`$existingList -match [regex]::Escape('$name')) {"
            $outputLines += "        Write-Host 'Bucket $name 已存在，无需重复添加' -ForegroundColor Green"
            $outputLines += "        `$bucketAddSuccess = `$true"
            $outputLines += "        continue"
            $outputLines += "      }"
            $outputLines += "      `$output = scoop bucket add $name `"`$currentSource`" 2>&1"
            $outputLines += "      Write-Host `$output"
            $outputLines += "      if (`$LASTEXITCODE -ne 0) {"
            $outputLines += "        if (`$LASTEXITCODE -eq 2 -and `$output -match 'already exists') {"
            $outputLines += "          Write-Host 'Bucket $name 已存在（并发添加），视为成功' -ForegroundColor Green"
            $outputLines += "          `$bucketAddSuccess = `$true"
            $outputLines += "          continue"
            $outputLines += "        }"
            $outputLines += "        if (!`$sshTried -and `$httpsSource -and `$currentSource -eq `$source) {"
            $outputLines += "          `$sshTried = `$true"
            $outputLines += "          `$currentSource = `$httpsSource"
            $outputLines += "          `$retryCount--"
            $outputLines += "          Write-Host 'SSH源连接失败，自动切换到HTTPS源重试...' -ForegroundColor Yellow"
            $outputLines += "          continue"
            $outputLines += "        }"
            $outputLines += "        throw ""scoop 退出码: `$LASTEXITCODE"""
            $outputLines += "      }"
            $outputLines += "      `$bucketList = scoop bucket list 2>&1"
            $outputLines += "      if (-not (`$bucketList -match [regex]::Escape('$name'))) {"
            $outputLines += "        if (!`$sshTried -and `$httpsSource -and `$currentSource -eq `$source) {"
            $outputLines += "          `$sshTried = `$true"
            $outputLines += "          `$currentSource = `$httpsSource"
            $outputLines += "          `$retryCount--"
            $outputLines += "          Write-Host 'SSH源验证失败，自动切换到HTTPS源重试...' -ForegroundColor Yellow"
            $outputLines += "          continue"
            $outputLines += "        }"
            $outputLines += "        throw ""Bucket '$name' 不在列表中，添加无效"""
            $outputLines += "      }"
            $outputLines += "      `$bucketAddSuccess = `$true"
            $outputLines += "      Write-Host 'Bucket $name 添加成功' -ForegroundColor Green"
            $outputLines += "    } catch {"
            $outputLines += "      Write-Host ""Bucket $name 添加失败，错误原因：`$(`$_.Exception.Message)"" -ForegroundColor Red"
            $outputLines += "      if (!`$sshTried -and `$httpsSource -and `$currentSource -eq `$source) {"
            $outputLines += "        `$sshTried = `$true"
            $outputLines += "        `$currentSource = `$httpsSource"
            $outputLines += "        `$retryCount--"
            $outputLines += "        Write-Host '自动切换到HTTPS源重试...' -ForegroundColor Yellow"
            $outputLines += "      }"
            $outputLines += "      if (`$retryCount -lt 3) {"
            $outputLines += "        Write-Host ""剩余重试次数：`$(3 - `$retryCount)"" -ForegroundColor Yellow"
            $outputLines += "        Start-Sleep -Seconds 2"
            $outputLines += "      }"
            $outputLines += "    }"
            $outputLines += "  }"
            $outputLines += "  if (!`$bucketAddSuccess) {"
            $outputLines += "    Write-Host '`n致命错误：Bucket $name 连续3次添加失败，终止整个恢复流程！' -ForegroundColor Red"
            $outputLines += "    pause"
            $outputLines += "    exit 1"
            $outputLines += "  }"
            $outputLines += ""
        }
    }

    $outputLines += '  Write-Host "`n✅ 所有Bucket仓库全部添加成功，即将开始安装软件" -ForegroundColor Green'
    $outputLines += ""

    # ========== 步骤2：软件恢复（修复continue和-notmatch）==========
    $outputLines += '  Write-Host "[步骤2] 恢复全部已安装软件（带Bucket前缀）" -ForegroundColor Cyan'
    foreach ($app in $exportData.apps) {
        $name = $app.Name
        $isGlobal = $app.Global

        if ($appBucketMap.ContainsKey($name)) {
            $bucket = $appBucketMap[$name]
            $fullApp = "$bucket/$name"
        } else {
            $bucket = $null
            $fullApp = $name
        }

        if ($bucket) {
            $outputLines += "  Write-Host '验证Bucket: $bucket' -ForegroundColor Cyan"
            $outputLines += "  `$bucketCheck = scoop bucket list 2>&1"
            $outputLines += "  if (-not (`$bucketCheck -match [regex]::Escape('$bucket'))) {"
            $outputLines += "    Write-Host '错误：Bucket $bucket 未找到，跳过软件 $fullApp' -ForegroundColor Red"
            $outputLines += "  } else {"
            $outputLines += "    try {"
            $outputLines += "      Write-Host '安装应用: $fullApp'"
            if ($isGlobal) {
                $outputLines += "      scoop install -g $fullApp"
            } else {
                $outputLines += "      scoop install $fullApp"
            }
            $outputLines += "    } catch {"
            $outputLines += "      Write-Host ""警告：应用 $fullApp 安装失败，错误：`$(`$_.Exception.Message)"" -ForegroundColor Yellow"
            $outputLines += "    }"
            $outputLines += "  }"
        } else {
            $outputLines += "  try {"
            $outputLines += "    Write-Host '安装应用: $fullApp'"
            if ($isGlobal) {
                $outputLines += "    scoop install -g $fullApp"
            } else {
                $outputLines += "    scoop install $fullApp"
            }
            $outputLines += "  } catch {"
            $outputLines += "    Write-Host ""警告：应用 $fullApp 安装失败，错误：`$(`$_.Exception.Message)"" -ForegroundColor Yellow"
            $outputLines += "  }"
        }
    }

    $outputLines += ""
    $outputLines += '  Write-Host "`n全部恢复流程执行完毕！" -ForegroundColor Green'
    $outputLines += "} catch {"
    $outputLines += '  Write-Host "`n脚本发生致命错误：$_" -ForegroundColor Red'
    $outputLines += '  Write-Host "错误堆栈：$($_.Exception.StackTrace)" -ForegroundColor DarkRed'
    $outputLines += "}"
    $outputLines += ""
    $outputLines += 'Write-Host "`n操作完成，按任意键关闭窗口..." -ForegroundColor Gray'
    $outputLines += '$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")'

    # 写入UTF8-BOM脚本
    $savePath = "restore-scoop-backup.ps1"
    try {
        $utf8WithBom = New-Object System.Text.UTF8Encoding $true
        [System.IO.File]::WriteAllLines($savePath, $outputLines, $utf8WithBom)
        Write-Host "`n✅ 导出完成！文件：$savePath" -ForegroundColor Green
        Write-Host "恢复规则说明："
        Write-Host "1. 安装 Scoop 后自动安装 Git（从 main Bucket）← 您的建议已实现"
        Write-Host "2. 每个Bucket最多自动重试3次添加（含退出码+列表双重校验）"
        Write-Host "3. 任意Bucket3次全部失败 → 直接终止脚本，不安装任何软件"
        Write-Host "4. 全部Bucket添加成功后，才会执行软件恢复"
        Write-Host "5. 软件命令自动携带bucket前缀，例：scoop install myscoop/2345pic"
        Write-Host "6. Scoop本体和 main/extras/versions 优先使用南京大学镜像，失败自动回退官方"
    } catch {
        Write-Host "写入文件失败：$_" -ForegroundColor Red
    }

    pause
}
elseif ($select -eq "4") {
    Write-Host "`n【已选择：退出】" -ForegroundColor Yellow
    exit 0
}
else {
    Write-Host "输入错误，仅支持 1 / 2 / 3 / 4，脚本退出" -ForegroundColor Red
    pause
    exit 1
}