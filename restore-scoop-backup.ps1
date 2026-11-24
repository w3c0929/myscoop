# 先设置执行策略，避免后续 $ErrorActionPreference="Stop" 导致脚本崩溃
try {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
} catch {
    Write-Host "注意：无法设置执行策略（可能被组策略覆盖）" -ForegroundColor Yellow
    Write-Host "当前 CurrentUser 策略：$(Get-ExecutionPolicy -Scope CurrentUser)" -ForegroundColor Cyan
}

$ErrorActionPreference = "Stop"
try {
  Clear-Host
  Write-Host "==================== Scoop 恢复工具 ====================" -ForegroundColor Cyan
  $scoopPath = "D:\scoop"

  # ---- 修复：用子进程执行官方安装脚本，避免其内部 exit 导致闪退 ----
  function Invoke-ScoopInstaller {
    param([switch]$RunAsAdmin)

    Write-Host "正在下载 Scoop 安装脚本..." -ForegroundColor Cyan
    $installerUrls = @("https://raw.githubusercontent.com/ScoopInstaller/Install/master/install.ps1", "https://get.scoop.sh")
    $installerContent = $null
    foreach ($u in $installerUrls) {
      try { $installerContent = Invoke-RestMethod $u -UseBasicParsing; break } catch { }
    }
    if (-not $installerContent) { Write-Host "所有安装脚本源均不可用" -ForegroundColor Red; return }

    $tmpInstaller = Join-Path $env:TEMP ("scoop-installer-{0}.ps1" -f ([guid]::NewGuid().ToString('N')))
    try {
      [System.IO.File]::WriteAllText($tmpInstaller, $installerContent, (New-Object System.Text.UTF8Encoding $false))

      $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$tmpInstaller`"")
      if ($RunAsAdmin) { $argList += "-RunAsAdmin" }

      $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

      if ($RunAsAdmin -and -not $isAdmin) {
        Write-Host "需要管理员权限，正在请求 UAC 提权..." -ForegroundColor Yellow
        Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Wait -Verb RunAs
      } else {
        Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Wait -NoNewWindow
      }
    } finally {
      Remove-Item $tmpInstaller -Force -ErrorAction SilentlyContinue
    }
  }

  # 检测Scoop是否已安装
  if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "未检测到Scoop，请先选择安装模式：" -ForegroundColor Yellow
    Write-Host "1. 管理员身份全局安装（所有用户共用，需要管理员权限）"
    Write-Host "2. 当前普通用户安装（仅本账号可用，无需管理员）"
    Write-Host "3. 退出"
    Write-Host "========================================================" -ForegroundColor Cyan
    $installSelect = Read-Host "输入数字 1、2 或 3"

    if ($installSelect -eq "1") {
      Write-Host "`n【已选择：管理员全局安装】" -ForegroundColor Green
      [Environment]::SetEnvironmentVariable("SCOOP", $scoopPath, "User")
      $env:SCOOP = $scoopPath
      # 修复：子进程执行官方安装脚本（管理员全局模式）
      Invoke-ScoopInstaller -RunAsAdmin
      $env:PATH = [Environment]::GetEnvironmentVariable("PATH","User") + ";" + [Environment]::GetEnvironmentVariable("PATH","Machine")
    }
    elseif ($installSelect -eq "2") {
      Write-Host "`n【已选择：普通用户安装】" -ForegroundColor Green
      [Environment]::SetEnvironmentVariable("SCOOP", $scoopPath, "User")
      $env:SCOOP = $scoopPath
      # 修复：子进程执行官方安装脚本（普通用户模式）
      Invoke-ScoopInstaller
      $env:PATH = [Environment]::GetEnvironmentVariable("PATH","User") + ";" + [Environment]::GetEnvironmentVariable("PATH","Machine")
    }
    elseif ($installSelect -eq "3") {
      Write-Host "`n【已选择：退出】" -ForegroundColor Yellow
      exit 0
    }
    else {
      Write-Host "输入错误，仅支持 1 / 2 / 3，脚本退出" -ForegroundColor Red
      pause
      exit 1
    }

    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
      Write-Host "错误：Scoop安装失败或环境变量未生效，请手动检查" -ForegroundColor Red
      pause
      exit 1
    }
  } else {
    Write-Host "已检测到Scoop，跳过安装步骤" -ForegroundColor Green
  }

  Write-Host "设置 Scoop 本体更新源（优先南京大学镜像）..." -ForegroundColor Cyan
  $mirror = "https://mirror.nju.edu.cn/git/scoop.git"
  $official = "https://github.com/ScoopInstaller/Scoop.git"
  scoop config SCOOP_REPO $mirror 2>&1 | Out-Null
  Write-Host "已设置为本体源：$mirror" -ForegroundColor Gray
  # 测试镜像可达性（需要 Git）
  if (Get-Command git -ErrorAction SilentlyContinue) {
    $testResult = git ls-remote $mirror 2>&1
    if ($LASTEXITCODE -ne 0) {
      Write-Host "镜像源不可达，自动回退到官方源：$official" -ForegroundColor Yellow
      scoop config SCOOP_REPO $official 2>&1 | Out-Null
    } else {
      Write-Host "镜像源测试通过，保持当前配置。" -ForegroundColor Green
    }
  } else {
    Write-Host "未检测到 Git，跳过镜像可达性测试，配置已设置为镜像。" -ForegroundColor Yellow
  }

  Write-Host "[前置] 检查 Git 是否可用..." -ForegroundColor Cyan
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "未检测到 Git，将使用 Scoop 安装 Git..." -ForegroundColor Yellow
    try {
      scoop install git
      if ($LASTEXITCODE -ne 0) { throw "scoop install git 失败，退出码 $LASTEXITCODE" }
      # 刷新环境变量，使 Git 立即可用
      $env:PATH = [Environment]::GetEnvironmentVariable("PATH","User") + ";" + [Environment]::GetEnvironmentVariable("PATH","Machine")
      Write-Host "Git 安装成功！" -ForegroundColor Green
    } catch {
      Write-Host "Git 安装失败：$_" -ForegroundColor Red
      Write-Host "请手动安装 Git（https://git-scm.com）后重新运行本脚本。" -ForegroundColor Yellow
      pause
      exit 1
    }
  } else {
    Write-Host "Git 已就绪，继续。" -ForegroundColor Green
  }

  Write-Host "[步骤1] 恢复所有Bucket仓库（每个最多重试3次，全部成功才继续软件安装）" -ForegroundColor Cyan
  # --- Bucket: main (镜像优先，失败自动回退官方) ---
  $retryCount = 0
  $bucketAddSuccess = $false
  $mirrorUrl = 'https://mirror.nju.edu.cn/git/scoop-main.git'
  $useOfficial = $false

  while ($retryCount -lt 3 -and !$bucketAddSuccess) {
    $retryCount++
    if ($useOfficial) {
      Write-Host "尝试添加Bucket[main]（官方源），第$retryCount/3次"
    } else {
      Write-Host "尝试添加Bucket[main]（镜像源），第$retryCount/3次"
    }
    try {
      $existingList = scoop bucket list 2>&1
      if ((Test-Path (Join-Path $scoopPath "buckets\main")) -or ($existingList -match [regex]::Escape('main'))) {
        Write-Host 'Bucket main 已存在，无需重复添加' -ForegroundColor Green
        $bucketAddSuccess = $true
        continue
      }
      if ($useOfficial) {
        $output = scoop bucket add main 2>&1   # 不指定URL，使用官方
      } else {
        $output = scoop bucket add main "$mirrorUrl" 2>&1
      }
      Write-Host $output
      if ($LASTEXITCODE -ne 0) {
        if ($output -match 'already exists') {
          Write-Host 'Bucket main 已存在（并发添加），视为成功' -ForegroundColor Green
          $bucketAddSuccess = $true
          continue
        }
        # 如果镜像失败且尚未切换官方，则切换到官方（不计入重试）
        if (!$useOfficial) {
          $useOfficial = $true
          $retryCount--  # 不计入重试次数
          Write-Host '镜像源连接失败，自动切换到官方源重试...' -ForegroundColor Yellow
          continue
        }
        throw "scoop 退出码: $LASTEXITCODE"
      }
      $bucketList = scoop bucket list 2>&1
      if (-not ($bucketList -match [regex]::Escape('main'))) {
        if (!$useOfficial) {
          $useOfficial = $true
          $retryCount--
          Write-Host '镜像源验证失败，自动切换到官方源重试...' -ForegroundColor Yellow
          continue
        }
        throw "Bucket 'main' 不在列表中，添加无效"
      }
      $bucketAddSuccess = $true
      Write-Host 'Bucket main 添加成功' -ForegroundColor Green
    } catch {
      Write-Host "Bucket main 添加失败，错误原因：$($_.Exception.Message)" -ForegroundColor Red
      if (!$useOfficial) {
        $useOfficial = $true
        $retryCount--
        Write-Host '自动切换到官方源重试...' -ForegroundColor Yellow
      }
      if ($retryCount -lt 3) {
        Write-Host "剩余重试次数：$(3 - $retryCount)" -ForegroundColor Yellow
        Start-Sleep -Seconds 2
      }
    }
  }
  if (!$bucketAddSuccess) {
    Write-Host '
致命错误：Bucket main 连续3次添加失败，终止整个恢复流程！' -ForegroundColor Red
    pause
    exit 1
  }

  # --- Bucket: extras (镜像优先，失败自动回退官方) ---
  $retryCount = 0
  $bucketAddSuccess = $false
  $mirrorUrl = 'https://mirror.nju.edu.cn/git/scoop-extras.git'
  $useOfficial = $false

  while ($retryCount -lt 3 -and !$bucketAddSuccess) {
    $retryCount++
    if ($useOfficial) {
      Write-Host "尝试添加Bucket[extras]（官方源），第$retryCount/3次"
    } else {
      Write-Host "尝试添加Bucket[extras]（镜像源），第$retryCount/3次"
    }
    try {
      $existingList = scoop bucket list 2>&1
      if ((Test-Path (Join-Path $scoopPath "buckets\extras")) -or ($existingList -match [regex]::Escape('extras'))) {
        Write-Host 'Bucket extras 已存在，无需重复添加' -ForegroundColor Green
        $bucketAddSuccess = $true
        continue
      }
      if ($useOfficial) {
        $output = scoop bucket add extras 2>&1   # 不指定URL，使用官方
      } else {
        $output = scoop bucket add extras "$mirrorUrl" 2>&1
      }
      Write-Host $output
      if ($LASTEXITCODE -ne 0) {
        if ($output -match 'already exists') {
          Write-Host 'Bucket extras 已存在（并发添加），视为成功' -ForegroundColor Green
          $bucketAddSuccess = $true
          continue
        }
        # 如果镜像失败且尚未切换官方，则切换到官方（不计入重试）
        if (!$useOfficial) {
          $useOfficial = $true
          $retryCount--  # 不计入重试次数
          Write-Host '镜像源连接失败，自动切换到官方源重试...' -ForegroundColor Yellow
          continue
        }
        throw "scoop 退出码: $LASTEXITCODE"
      }
      $bucketList = scoop bucket list 2>&1
      if (-not ($bucketList -match [regex]::Escape('extras'))) {
        if (!$useOfficial) {
          $useOfficial = $true
          $retryCount--
          Write-Host '镜像源验证失败，自动切换到官方源重试...' -ForegroundColor Yellow
          continue
        }
        throw "Bucket 'extras' 不在列表中，添加无效"
      }
      $bucketAddSuccess = $true
      Write-Host 'Bucket extras 添加成功' -ForegroundColor Green
    } catch {
      Write-Host "Bucket extras 添加失败，错误原因：$($_.Exception.Message)" -ForegroundColor Red
      if (!$useOfficial) {
        $useOfficial = $true
        $retryCount--
        Write-Host '自动切换到官方源重试...' -ForegroundColor Yellow
      }
      if ($retryCount -lt 3) {
        Write-Host "剩余重试次数：$(3 - $retryCount)" -ForegroundColor Yellow
        Start-Sleep -Seconds 2
      }
    }
  }
  if (!$bucketAddSuccess) {
    Write-Host '
致命错误：Bucket extras 连续3次添加失败，终止整个恢复流程！' -ForegroundColor Red
    pause
    exit 1
  }

  # --- Bucket: versions (镜像优先，失败自动回退官方) ---
  $retryCount = 0
  $bucketAddSuccess = $false
  $mirrorUrl = 'https://mirror.nju.edu.cn/git/scoop-versions.git'
  $useOfficial = $false

  while ($retryCount -lt 3 -and !$bucketAddSuccess) {
    $retryCount++
    if ($useOfficial) {
      Write-Host "尝试添加Bucket[versions]（官方源），第$retryCount/3次"
    } else {
      Write-Host "尝试添加Bucket[versions]（镜像源），第$retryCount/3次"
    }
    try {
      $existingList = scoop bucket list 2>&1
      if ((Test-Path (Join-Path $scoopPath "buckets\versions")) -or ($existingList -match [regex]::Escape('versions'))) {
        Write-Host 'Bucket versions 已存在，无需重复添加' -ForegroundColor Green
        $bucketAddSuccess = $true
        continue
      }
      if ($useOfficial) {
        $output = scoop bucket add versions 2>&1   # 不指定URL，使用官方
      } else {
        $output = scoop bucket add versions "$mirrorUrl" 2>&1
      }
      Write-Host $output
      if ($LASTEXITCODE -ne 0) {
        if ($output -match 'already exists') {
          Write-Host 'Bucket versions 已存在（并发添加），视为成功' -ForegroundColor Green
          $bucketAddSuccess = $true
          continue
        }
        # 如果镜像失败且尚未切换官方，则切换到官方（不计入重试）
        if (!$useOfficial) {
          $useOfficial = $true
          $retryCount--  # 不计入重试次数
          Write-Host '镜像源连接失败，自动切换到官方源重试...' -ForegroundColor Yellow
          continue
        }
        throw "scoop 退出码: $LASTEXITCODE"
      }
      $bucketList = scoop bucket list 2>&1
      if (-not ($bucketList -match [regex]::Escape('versions'))) {
        if (!$useOfficial) {
          $useOfficial = $true
          $retryCount--
          Write-Host '镜像源验证失败，自动切换到官方源重试...' -ForegroundColor Yellow
          continue
        }
        throw "Bucket 'versions' 不在列表中，添加无效"
      }
      $bucketAddSuccess = $true
      Write-Host 'Bucket versions 添加成功' -ForegroundColor Green
    } catch {
      Write-Host "Bucket versions 添加失败，错误原因：$($_.Exception.Message)" -ForegroundColor Red
      if (!$useOfficial) {
        $useOfficial = $true
        $retryCount--
        Write-Host '自动切换到官方源重试...' -ForegroundColor Yellow
      }
      if ($retryCount -lt 3) {
        Write-Host "剩余重试次数：$(3 - $retryCount)" -ForegroundColor Yellow
        Start-Sleep -Seconds 2
      }
    }
  }
  if (!$bucketAddSuccess) {
    Write-Host '
致命错误：Bucket versions 连续3次添加失败，终止整个恢复流程！' -ForegroundColor Red
    pause
    exit 1
  }

  # --- Bucket: sysinternals (known, official) ---
  $retryCount = 0
  $bucketAddSuccess = $false
  while ($retryCount -lt 3 -and !$bucketAddSuccess) {
    $retryCount++
    Write-Host "尝试添加Bucket[sysinternals]，第$retryCount/3次"
    try {
      $existingList = scoop bucket list 2>&1
      if ((Test-Path (Join-Path $scoopPath "buckets\sysinternals")) -or ($existingList -match [regex]::Escape('sysinternals'))) {
        Write-Host 'Bucket sysinternals 已存在，无需重复添加' -ForegroundColor Green
        $bucketAddSuccess = $true
        continue
      }
      $output = scoop bucket add sysinternals 2>&1
      Write-Host $output
      if ($LASTEXITCODE -ne 0) {
        if ($output -match 'already exists') {
          Write-Host 'Bucket sysinternals 已存在（并发添加），视为成功' -ForegroundColor Green
          $bucketAddSuccess = $true
          continue
        }
        throw "scoop 退出码: $LASTEXITCODE"
      }
      $bucketList = scoop bucket list 2>&1
      if (-not ($bucketList -match [regex]::Escape('sysinternals'))) {
        throw "Bucket 'sysinternals' 不在列表中，添加无效"
      }
      $bucketAddSuccess = $true
      Write-Host 'Bucket sysinternals 添加成功' -ForegroundColor Green
    } catch {
      Write-Host "Bucket sysinternals 添加失败，错误原因：$($_.Exception.Message)" -ForegroundColor Red
      if ($retryCount -lt 3) {
        Write-Host "剩余重试次数：$(3 - $retryCount)" -ForegroundColor Yellow
        Start-Sleep -Seconds 2
      }
    }
  }
  if (!$bucketAddSuccess) {
    Write-Host '
致命错误：Bucket sysinternals 连续3次添加失败，终止整个恢复流程！' -ForegroundColor Red
    pause
    exit 1
  }

  # --- Bucket: myscoop (custom, SSH→HTTPS auto-fallback) ---
  $retryCount = 0
  $bucketAddSuccess = $false
  $source = 'git@github.com:w3c0929/myscoop.git'
  $httpsSource = ''
  if ($source -match '^git@([^:]+):(.+)$') {
    $httpsSource = 'https://' + $Matches[1] + '/' + $Matches[2]
    Write-Host "检测到SSH源，已准备HTTPS备选: $httpsSource" -ForegroundColor Cyan
  }
  $currentSource = $source
  $sshTried = $false

  while ($retryCount -lt 3 -and !$bucketAddSuccess) {
    $retryCount++
    Write-Host "尝试添加Bucket[myscoop]，第$retryCount/3次（源: $currentSource）"
    try {
      $existingList = scoop bucket list 2>&1
      if ((Test-Path (Join-Path $scoopPath "buckets\myscoop")) -or ($existingList -match [regex]::Escape('myscoop'))) {
        Write-Host 'Bucket myscoop 已存在，无需重复添加' -ForegroundColor Green
        $bucketAddSuccess = $true
        continue
      }
      $output = scoop bucket add myscoop "$currentSource" 2>&1
      Write-Host $output
      if ($LASTEXITCODE -ne 0) {
        if ($output -match 'already exists') {
          Write-Host 'Bucket myscoop 已存在（并发添加），视为成功' -ForegroundColor Green
          $bucketAddSuccess = $true
          continue
        }
        if (!$sshTried -and $httpsSource -and $currentSource -eq $source) {
          $sshTried = $true
          $currentSource = $httpsSource
          $retryCount--
          Write-Host 'SSH源连接失败，自动切换到HTTPS源重试...' -ForegroundColor Yellow
          continue
        }
        throw "scoop 退出码: $LASTEXITCODE"
      }
      $bucketList = scoop bucket list 2>&1
      if (-not ($bucketList -match [regex]::Escape('myscoop'))) {
        if (!$sshTried -and $httpsSource -and $currentSource -eq $source) {
          $sshTried = $true
          $currentSource = $httpsSource
          $retryCount--
          Write-Host 'SSH源验证失败，自动切换到HTTPS源重试...' -ForegroundColor Yellow
          continue
        }
        throw "Bucket 'myscoop' 不在列表中，添加无效"
      }
      $bucketAddSuccess = $true
      Write-Host 'Bucket myscoop 添加成功' -ForegroundColor Green
    } catch {
      Write-Host "Bucket myscoop 添加失败，错误原因：$($_.Exception.Message)" -ForegroundColor Red
      if (!$sshTried -and $httpsSource -and $currentSource -eq $source) {
        $sshTried = $true
        $currentSource = $httpsSource
        $retryCount--
        Write-Host '自动切换到HTTPS源重试...' -ForegroundColor Yellow
      }
      if ($retryCount -lt 3) {
        Write-Host "剩余重试次数：$(3 - $retryCount)" -ForegroundColor Yellow
        Start-Sleep -Seconds 2
      }
    }
  }
  if (!$bucketAddSuccess) {
    Write-Host '
致命错误：Bucket myscoop 连续3次添加失败，终止整个恢复流程！' -ForegroundColor Red
    pause
    exit 1
  }

  # --- Bucket: official (custom, SSH→HTTPS auto-fallback) ---
  $retryCount = 0
  $bucketAddSuccess = $false
  $source = 'https://gitee.com/cmontage/scoopbucket.git'
  $httpsSource = ''
  if ($source -match '^git@([^:]+):(.+)$') {
    $httpsSource = 'https://' + $Matches[1] + '/' + $Matches[2]
    Write-Host "检测到SSH源，已准备HTTPS备选: $httpsSource" -ForegroundColor Cyan
  }
  $currentSource = $source
  $sshTried = $false

  while ($retryCount -lt 3 -and !$bucketAddSuccess) {
    $retryCount++
    Write-Host "尝试添加Bucket[official]，第$retryCount/3次（源: $currentSource）"
    try {
      $existingList = scoop bucket list 2>&1
      if ((Test-Path (Join-Path $scoopPath "buckets\official")) -or ($existingList -match [regex]::Escape('official'))) {
        Write-Host 'Bucket official 已存在，无需重复添加' -ForegroundColor Green
        $bucketAddSuccess = $true
        continue
      }
      $output = scoop bucket add official "$currentSource" 2>&1
      Write-Host $output
      if ($LASTEXITCODE -ne 0) {
        if ($output -match 'already exists') {
          Write-Host 'Bucket official 已存在（并发添加），视为成功' -ForegroundColor Green
          $bucketAddSuccess = $true
          continue
        }
        if (!$sshTried -and $httpsSource -and $currentSource -eq $source) {
          $sshTried = $true
          $currentSource = $httpsSource
          $retryCount--
          Write-Host 'SSH源连接失败，自动切换到HTTPS源重试...' -ForegroundColor Yellow
          continue
        }
        throw "scoop 退出码: $LASTEXITCODE"
      }
      $bucketList = scoop bucket list 2>&1
      if (-not ($bucketList -match [regex]::Escape('official'))) {
        if (!$sshTried -and $httpsSource -and $currentSource -eq $source) {
          $sshTried = $true
          $currentSource = $httpsSource
          $retryCount--
          Write-Host 'SSH源验证失败，自动切换到HTTPS源重试...' -ForegroundColor Yellow
          continue
        }
        throw "Bucket 'official' 不在列表中，添加无效"
      }
      $bucketAddSuccess = $true
      Write-Host 'Bucket official 添加成功' -ForegroundColor Green
    } catch {
      Write-Host "Bucket official 添加失败，错误原因：$($_.Exception.Message)" -ForegroundColor Red
      if (!$sshTried -and $httpsSource -and $currentSource -eq $source) {
        $sshTried = $true
        $currentSource = $httpsSource
        $retryCount--
        Write-Host '自动切换到HTTPS源重试...' -ForegroundColor Yellow
      }
      if ($retryCount -lt 3) {
        Write-Host "剩余重试次数：$(3 - $retryCount)" -ForegroundColor Yellow
        Start-Sleep -Seconds 2
      }
    }
  }
  if (!$bucketAddSuccess) {
    Write-Host '
致命错误：Bucket official 连续3次添加失败，终止整个恢复流程！' -ForegroundColor Red
    pause
    exit 1
  }

  Write-Host "`n✅ 所有Bucket仓库全部添加成功（此版本仅恢复 Bucket，不含软件安装）" -ForegroundColor Green
} catch {
  Write-Host "`n脚本发生致命错误：$_" -ForegroundColor Red
  Write-Host "错误堆栈：$($_.Exception.StackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nBucket 恢复完成，按任意键关闭窗口..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
