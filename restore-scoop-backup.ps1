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
  # Scoop 根目录动态解析（兼容任意机器：不写死盘符/用户名）：
  #   %SCOOP% 环境变量 → scoop 命令安装位置推断 → 常见默认位置 → 全新安装回退 D:\scoop
  $scoopPath = $env:SCOOP
  if ($scoopPath -and -not (Test-Path (Join-Path $scoopPath 'apps\scoop\current'))) { $scoopPath = $null }
  if (-not $scoopPath) {
    $scoopCmd = Get-Command scoop -ErrorAction SilentlyContinue
    if ($scoopCmd -and $scoopCmd.Source) {
      $candidate = Split-Path (Split-Path $scoopCmd.Source -Parent) -Parent
      if (Test-Path (Join-Path $candidate 'apps\scoop\current')) { $scoopPath = $candidate }
    }
  }
  if (-not $scoopPath) {
    foreach ($c in @("$env:USERPROFILE\scoop", "C:\ProgramData\scoop", "D:\scoop")) {
      if (Test-Path (Join-Path $c 'apps\scoop\current')) { $scoopPath = $c; break }
    }
  }
  if (-not $scoopPath) { $scoopPath = "D:\scoop" }
  Write-Host "Scoop 根目录：$scoopPath" -ForegroundColor Gray

  # 跨用户使用兜底：当前账号 PATH 中没有 scoop 或 git（如 Administrator 使用普通用户安装的
  # Scoop：git 由 scoop 安装，shim 位于 <Scoop根>\shims，不在该账号 PATH）时，
  # 把 shims 临时加入当前进程 PATH。
  # 必须放在 safe.directory 修复之前：否则下面的 Set-GitSafeDirectory 会因找不到 git 直接跳过。
  if ((-not (Get-Command scoop -ErrorAction SilentlyContinue)) -or (-not (Get-Command git -ErrorAction SilentlyContinue))) {
    $shimsPath = Join-Path $scoopPath 'shims'
    if (Test-Path $shimsPath) {
      $env:PATH = "$shimsPath;$env:PATH"
      Write-Host "  已将 $shimsPath 加入当前进程 PATH（scoop/git 命令可用）" -ForegroundColor DarkGray
    }
  }

  # git "dubious ownership" 兼容：Scoop 目录由其他用户创建（如普通用户装好后切到
  # Administrator 使用）时，git 2.35.2+ 会拒绝操作（fatal: detected dubious ownership），
  # 导致 Scoop 内部 git 命令全部失败（scoop install 报 CommitHash 空绑定等次生错误）。
  # 实测 git 只支持精确路径或整值 *（不支持 D:/scoop/* 这类前缀通配），
  # 这里写入整值 *（一次配置，当前账号所有仓库放行；幂等，已有则跳过）。
  # 封装为函数：脚本开头调用一次；Git 检查段之后再统一调用一次（幂等），
  # 覆盖"全新机器装完 git"与"已装 git 但开头 PATH 未就绪"两种场景。
  function Set-GitSafeDirectory {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return }
    $safeList = @()
    try { $safeList = @(git config --global --get-all safe.directory 2>$null) } catch { }
    if ($safeList -notcontains '*') {
      git config --global --add safe.directory '*' 2>$null
      Write-Host "  已添加 git safe.directory: *（解决跨用户 dubious ownership）" -ForegroundColor DarkGray
    }
  }
  Set-GitSafeDirectory

  # GitHub 加速镜像：与 scoop config.json 的 aria2-mirrors 一致，按序尝试；全部失败再直连
  # （安装脚本下载与 git 缓存预下载共用）
  $ghMirrors = @(
    "https://gh-proxy.org",
    "https://hk.gh-proxy.org",
    "https://cdn.gh-proxy.com",
    "https://git.yylx.win",
    "https://gh.monlor.com",
    "https://gh.my-website.ccwu.cc",
    "https://tvv.tw",
    "https://ghfast.top",
    "https://gh.acmsz.top",
    "https://github.ednovas.xyz",
    "https://gh.sixyin.com",
    "https://ghproxy.imciel.com",
    "https://cdn.akaere.online",
    "https://gh-proxy.com",
    "https://free.cn.eu.org",
    "https://fastgit.cc",
    "https://github.mxw.qzz.io",
    "https://xsadwsd.kdns.fr",
    "https://ghproxy.felicity.land",
    "https://down.mxw.qzz.io",
    "https://gh.07150721.xyz",
    "https://github.tbap.top",
    "https://gh.noki.icu",
    "https://ghproxy.net"
  )

  # ============================================================
  # 交互式选择下载加速代理（列表来自上面 $ghMirrors）。
  # 回车保持当前；输入编号切换；输入 0 表示不使用加速代理（全程直连）。
  # 选择持久化到 %LOCALAPPDATA%\myscoop\mirror-choice.txt（URL 或 direct），
  # 下次运行自动作为默认；变更方式：再次运行重新选择，或删除该文件回到默认。
  # 选中项重排到列表首位（其余代理仍作为失败兜底）。
  # ============================================================
  $mirrorChoiceFile = Join-Path ($env:LOCALAPPDATA, $env:USERPROFILE | Where-Object { $_ } | Select-Object -First 1) 'myscoop\mirror-choice.txt'
  $savedMirror = $null
  if (Test-Path $mirrorChoiceFile) {
    try { $savedMirror = (Get-Content -LiteralPath $mirrorChoiceFile -TotalCount 1).Trim() } catch { }
  }
  $defaultMirror = if ($savedMirror -eq 'direct') { 'direct' }
                   elseif ($savedMirror -and ($ghMirrors -contains $savedMirror)) { $savedMirror }
                   else { $ghMirrors[0] }
  $defaultText = if ($defaultMirror -eq 'direct') { '不使用加速代理（直连）' } else { $defaultMirror }
  Write-Host "`n[代理选择] 下载加速代理（回车保持当前：$defaultText；输入编号切换；输入 0 直连）" -ForegroundColor Cyan
  for ($i = 0; $i -lt $ghMirrors.Count; $i++) {
    $mark = if ($ghMirrors[$i] -eq $defaultMirror) { '  ← 当前' } else { '' }
    Write-Host ("  {0,2}. {1}{2}" -f ($i + 1), $ghMirrors[$i], $mark) -ForegroundColor Gray
  }
  $directMark = if ($defaultMirror -eq 'direct') { '  ← 当前' } else { '' }
  Write-Host ("   0. 不使用加速代理（直连）{0}" -f $directMark) -ForegroundColor Gray
  $mirrorAns = Read-Host "输入编号（直接回车保持不变）"
  $selectedMirror = $defaultMirror
  if ($mirrorAns -match '^\d+$') {
    $num = [int]$mirrorAns
    if ($num -eq 0) {
      $selectedMirror = 'direct'
    } elseif (($num - 1) -ge 0 -and ($num - 1) -lt $ghMirrors.Count) {
      $selectedMirror = $ghMirrors[$num - 1]
    } else {
      Write-Host "  编号无效，保持当前选择" -ForegroundColor Yellow
    }
  }
  try {
    New-Item -ItemType Directory -Force (Split-Path $mirrorChoiceFile -Parent) | Out-Null
    Set-Content -LiteralPath $mirrorChoiceFile -Value $selectedMirror -Encoding UTF8
  } catch { }
  if ($selectedMirror -eq 'direct') {
    $ghMirrors = @()
    Write-Host "  已选择: 不使用加速代理（全部直连）" -ForegroundColor Green
  } else {
    $ghMirrors = @($selectedMirror) + @($ghMirrors | Where-Object { $_ -ne $selectedMirror })
    Write-Host "  已选择: $selectedMirror（其余代理仍作为失败兜底）" -ForegroundColor Green
  }

  # 浅克隆源辅助：选中代理优先 + 其余代理兜底 + 官方直连（浅克隆块统一用它拼源列表）
  function Get-GitProxyUrls {
    param([string]$GitUrl)
    $list = @()
    foreach ($m in @($ghMirrors | Select-Object -First 3)) { $list += "$m/$GitUrl" }
    $list += $GitUrl
    return $list
  }

  # ============================================================
  # 已存在 bucket 的 remote 自检：当前 remote（可能是 nju 镜像/某个加速代理）
  # 不可达时，按候选链（镜像 → 选中代理 → 其余代理 → 官方）逐个探测，
  # 用 git remote set-url 原地切换（保留本地历史，无需重新克隆），
  # 避免后续 scoop update 卡在失效代理上报 Connection was reset。
  # 探测用 ls-remote + 8 秒低速中止，黑洞代理不会长时间卡住自检。
  # ============================================================
  function Repair-BucketRemote {
    param([string]$Name, [string[]]$Candidates)

    $dir = Join-Path $scoopPath "buckets\$Name"
    if (-not (Test-Path (Join-Path $dir '.git'))) { return }
    $current = (git -C $dir remote get-url origin 2>$null)
    if (-not $current) { return }
    git -c http.lowSpeedLimit=1024 -c http.lowSpeedTime=8 ls-remote --heads $current 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { return }
    Write-Host "  [自检] Bucket $Name 的 remote 不可用，尝试切换: $current" -ForegroundColor Yellow
    foreach ($url in $Candidates) {
      if (-not $url -or $url -eq $current) { continue }
      git -c http.lowSpeedLimit=1024 -c http.lowSpeedTime=8 ls-remote --heads $url 2>$null | Out-Null
      if ($LASTEXITCODE -eq 0) {
        git -C $dir remote set-url origin $url 2>$null
        Write-Host "  已切换 remote → $url" -ForegroundColor Green
        return
      }
    }
    Write-Host "  [警告] Bucket $Name 所有候选源均不可达，保留原 remote（scoop update 可能失败）" -ForegroundColor Red
  }

  # ---- 修复：用子进程执行官方安装脚本，避免其内部 exit 导致闪退 ----
  function Invoke-ScoopInstaller {
    param([switch]$RunAsAdmin)

    Write-Host "正在下载 Scoop 安装脚本..." -ForegroundColor Cyan
    # 启用 TLS 1.2（Win7/WMF 5.1 默认可能只开 TLS 1.0，多数加速镜像不支持）
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

    $installerSrc = "https://raw.githubusercontent.com/ScoopInstaller/Install/master/install.ps1"
    $installerUrls = @()
    foreach ($m in $ghMirrors) { $installerUrls += "$m/$installerSrc" }
    $installerUrls += @($installerSrc, "https://get.scoop.sh")   # 兜底：直连 + 官方短链
    $installerContent = $null
    foreach ($u in $installerUrls) {
      try {
        Write-Host "  尝试下载: $u" -ForegroundColor DarkGray
        $installerContent = Invoke-RestMethod $u -UseBasicParsing -TimeoutSec 15
        # 简单内容校验：防止镜像返回错误页/说明页被当作安装脚本执行
        if ($installerContent -and $installerContent -match 'ScoopInstaller') {
          Write-Host "  下载成功" -ForegroundColor Green
          break
        }
        $installerContent = $null
      } catch { }
    }
    if (-not $installerContent) { Write-Host "所有安装脚本源均不可用" -ForegroundColor Red; return }

    # 安装器内部会直连 GitHub 下载 Scoop 本体（Scoop/archive/master.zip）与 main bucket
    # （Main/archive/master.zip；检测到 git 时改为 *.git clone）——国内直连经常被重置
    # （实测 WebException"基础连接已经关闭"）。这里把脚本内的 GitHub 地址统一改写为
    # 加速镜像前缀（gh-proxy 支持 zip/raw/git clone），下载链路全程走镜像。
    # 用户选择"直连"时 $ghMirrors 为空 → 不改写，保持官方地址。
    if ($ghMirrors.Count -gt 0) {
      $dlMirror = $ghMirrors[0]
      $patched = $installerContent -replace '(?<!gh-proxy\.org/)https://github\.com/ScoopInstaller/', "$dlMirror/https://github.com/ScoopInstaller/"
      if ($patched -ne $installerContent) {
        $installerContent = $patched
        Write-Host "  已将安装器内部 Scoop/Main 下载地址替换为加速镜像: $dlMirror" -ForegroundColor Gray
      }
    } else {
      Write-Host "  [直连模式] 安装器内部下载保持官方 GitHub 地址" -ForegroundColor Yellow
    }

    # 安装前清理残留：目标目录存在但没有有效的 Scoop（上次删除不完整 / 失败安装残留）时，
    # 安装器会以 "'D:\scoop' exists and is not empty" 拒绝安装。此处先备份 persist，
    # 再清理整个残留目录，让安装器可以正常初始化。
    if (Test-Path $scoopPath) {
      if (-not (Test-Path (Join-Path $scoopPath 'apps\scoop\current'))) {
        Write-Host "检测到 $scoopPath 存在残留文件（上次删除/安装不完整），准备清理..." -ForegroundColor Yellow
        $persistDir = Join-Path $scoopPath 'persist'
        if (Test-Path $persistDir) {
          $persistBak = "$scoopPath.persist-backup-$(Get-Date -Format 'yyyyMMddHHmmss')"
          Move-Item -LiteralPath $persistDir -Destination $persistBak -Force -ErrorAction SilentlyContinue
          if (Test-Path $persistBak) { Write-Host "  已备份 persist 到 $persistBak" -ForegroundColor Yellow }
        }
        Remove-Item -LiteralPath $scoopPath -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $scoopPath) {
          Write-Host "  清理失败：部分文件被占用。请关闭相关程序（或重启）后手动删除 $scoopPath 再重试。" -ForegroundColor Red
          return
        }
        Write-Host "  残留目录已清理，继续安装" -ForegroundColor Green
      }
    }

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

  # ============================================================
  # 判断 bucket 是否已存在（目录存在即视为已存在，避免上次中断留下的
  # 不完整 .git 触发重新 add 时报 "current branch appears to be broken"）。
  # 目录存在但 git 仓库不完整时打印修复提示（不阻断流程）。
  # ============================================================
  function Test-BucketAlreadyPresent {
    param([string]$Name)

    $dir = Join-Path $scoopPath "buckets\$Name"
    if (-not (Test-Path $dir)) { return $false }
    git -C $dir rev-parse --verify HEAD 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Write-Host "  警告：Bucket $Name 目录存在但 git 仓库不完整（可能上次运行中断）。已跳过添加；如需修复请删除该目录后重新运行。" -ForegroundColor Yellow
    }
    return $true
  }

  # ============================================================
  # 浅克隆 bucket 仓库到 Scoop 的 buckets 目录（--depth 1，只取最新快照，
  # 避免完整历史带来数倍流量/时间）。
  # - 目录已是完整 git 仓库 → 直接返回 $true
  # - 目录不存在 → 逐源浅克隆
  # - 目录存在但不是完整 git 仓库（zip 方式安装的 bucket、上次中断残留）→
  #   备份到 <Scoop 根>\buckets_backup\ 后重建。否则 Scoop 在下次
  #   scoop install/update 时会把非 git 的 bucket "Converting to git repo"：
  #   先删除目录再从 GitHub 直连 clone，一旦失败 bucket 就彻底丢失
  #   （实测事故：main 就是这样被 Scoop 删除的）。
  # 成功返回 $true，目录已就绪（后续 scoop bucket add 会检测"已存在"并跳过）；
  # 全部源失败返回 $false，调用方回退原有完整 add 流程。
  # ============================================================
  function Clone-BucketToDir {
    param([string]$Name, [string[]]$Sources)

    $dir = Join-Path $scoopPath "buckets\$Name"
    $bak = $null
    if (Test-Path $dir) {
      git -C $dir rev-parse --verify HEAD 2>$null | Out-Null
      if ($LASTEXITCODE -eq 0) { return $true }
      $bakDir = Join-Path $scoopPath 'buckets_backup'
      New-Item -ItemType Directory -Force $bakDir | Out-Null
      $bak = Join-Path $bakDir ("$Name-" + (Get-Date -Format 'yyyyMMddHHmmss'))
      Write-Host "  检测到 Bucket $Name 不是完整 git 仓库（zip 安装/中断残留），已备份到 $bak 并重建" -ForegroundColor Yellow
      Move-Item -LiteralPath $dir -Destination $bak -Force -ErrorAction SilentlyContinue
      if (Test-Path $dir) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    New-Item -ItemType Directory -Force (Split-Path $dir -Parent) | Out-Null
    foreach ($src in $Sources) {
      if (-not $src) { continue }
      if (Test-Path $dir) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
      Write-Host "  尝试浅克隆: $src" -ForegroundColor DarkGray
      git clone --depth 1 --quiet $src $dir 2>$null
      if ($LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $dir '.git'))) {
        Write-Host "  浅克隆完成: $Name" -ForegroundColor Green
        # 重建成功：旧备份已无价值，直接删除（避免留下 buckets_backup 目录）
        if ($bak -and (Test-Path $bak)) {
          Remove-Item -LiteralPath $bak -Recurse -Force -ErrorAction SilentlyContinue
          if (-not (Test-Path $bak)) { Write-Host "  已清理旧目录备份" -ForegroundColor Gray }
        }
        return $true
      }
      if (Test-Path $dir) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    if ($bak -and (Test-Path $bak)) {
      Write-Host "  [提示] 重建失败，旧目录已保留在 $bak（可手动还原）" -ForegroundColor Yellow
    }
    Write-Host "  [提示] 所有浅克隆源均失败，回退完整添加流程" -ForegroundColor Yellow
    return $false
  }

  # ============================================================
  # 通用：从 main bucket 清单动态读取下载信息（版本/URL/hash，不硬编码），
  # 用加速镜像下载并校验 sha256，按 Scoop 的缓存命名规则放入 cache，
  # 随后 scoop install <app> 直接命中缓存（只需解包，不再等待下载）。
  # 缓存命名与 Scoop v0.6.0 core.ps1 的 cache_path 完全一致：
  #   <app>#<version>#<sha256(清单原始URL)前7位><扩展名>
  # 任一步失败都回退为 scoop 直接下载，不影响原有流程。
  # ============================================================
  function Install-ScoopAppWithMirrorCache {
    param([string]$AppName)

    $manifestPath = Join-Path $scoopPath "buckets\main\bucket\$AppName.json"
    if (-not (Test-Path $manifestPath)) {
      Write-Host "  [提示] 未找到 main bucket 的 $AppName.json，跳过预下载（Scoop 将直接下载）" -ForegroundColor Yellow
      return
    }
    try {
      $manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
      $ver = [string]$manifest.version
      $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } elseif ([Environment]::Is64BitOperatingSystem) { '64bit' } else { '32bit' }
      $block = if ($manifest.architecture) { $manifest.architecture.$arch } else { $manifest }
      if (-not $block -or -not $block.url) {
        Write-Host "  [提示] $AppName.json 中没有 $arch 架构的下载地址，跳过预下载" -ForegroundColor Yellow
        return
      }
      $url = [string]$block.url
      $hash = ([string]$block.hash) -replace '^sha256:', ''
      $sha256Obj = [Security.Cryptography.SHA256]::Create()
      $shaHex = [BitConverter]::ToString($sha256Obj.ComputeHash([Text.Encoding]::UTF8.GetBytes($url))).Replace('-', '').ToLower()
      $sha256Obj.Dispose()
      $cacheName = "$AppName#$ver#$($shaHex.Substring(0, 7))$([IO.Path]::GetExtension($url))"
      $cacheDir = Join-Path $scoopPath 'cache'
      $cacheFile = Join-Path $cacheDir $cacheName
      New-Item -ItemType Directory -Force $cacheDir | Out-Null

      if (Test-Path $cacheFile) {
        if (-not $hash -or (Get-FileHash -Algorithm SHA256 $cacheFile).Hash.ToLower() -eq $hash) {
          Write-Host "  缓存已存在且校验通过: $cacheName" -ForegroundColor Green
          return
        }
        Write-Host "  缓存文件 hash 不符，已删除重新下载" -ForegroundColor Yellow
        Remove-Item $cacheFile -Force -ErrorAction SilentlyContinue
      }

      # GitHub 资产优先走加速镜像；其他域名直连
      $urls = @()
      if ($url -match '^https://github\.com/') {
        foreach ($m in $ghMirrors) { $urls += "$m/$url" }
      }
      $urls += $url
      $tmpDl = "$cacheFile.download"
      foreach ($u in $urls) {
        try {
          Write-Host "  尝试下载: $u" -ForegroundColor DarkGray
          if (Test-Path $tmpDl) { Remove-Item $tmpDl -Force -ErrorAction SilentlyContinue }
          Invoke-WebRequest -Uri $u -OutFile $tmpDl -UseBasicParsing -TimeoutSec 600
          if ($hash) {
            $actualHash = (Get-FileHash -Algorithm SHA256 $tmpDl).Hash.ToLower()
            if ($actualHash -ne $hash) {
              Write-Host "  hash 不匹配（文件异常），尝试下一个源" -ForegroundColor Yellow
              continue
            }
          }
          Move-Item -Path $tmpDl -Destination $cacheFile -Force
          Write-Host ("  下载完成并校验通过（{0:N1} MB）" -f ((Get-Item $cacheFile).Length / 1MB)) -ForegroundColor Green
          return
        } catch {
          Write-Host "  下载失败: $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
      }
      if (Test-Path $tmpDl) { Remove-Item $tmpDl -Force -ErrorAction SilentlyContinue }
      Write-Host "  所有下载源均失败，回退为 scoop 直接下载（可能较慢）" -ForegroundColor Yellow
    } catch {
      Write-Host "  [提示] 预下载跳过：$($_.Exception.Message)" -ForegroundColor Yellow
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

  # TLS 1.2：若走"已装 Scoop"分支，安装脚本下载段不会执行，这里补设一次（Win7 默认只有 TLS 1.0）
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

  Write-Host "[前置] 检查 7zip 是否可用..." -ForegroundColor Cyan
  if (-not (Get-Command 7z -ErrorAction SilentlyContinue)) {
    Write-Host "未检测到 7zip，将使用 Scoop 安装 7zip（镜像预下载加速）..." -ForegroundColor Yellow
    try {
      Install-ScoopAppWithMirrorCache -AppName '7zip'
      # --no-update-scoop：跳过安装前的 Scoop/全 bucket 更新（全新机器刚装完无需更新；
      # 也避免更新 bucket 时的网络失败把安装带崩）
      scoop install 7zip --no-update-scoop
      if ($LASTEXITCODE -ne 0) { throw "scoop install 7zip 失败，退出码 $LASTEXITCODE" }
      # 刷新环境变量，使 7z 立即可用
      $env:PATH = [Environment]::GetEnvironmentVariable("PATH","User") + ";" + [Environment]::GetEnvironmentVariable("PATH","Machine")
      Write-Host "7zip 安装成功！" -ForegroundColor Green
    } catch {
      Write-Host "7zip 安装失败：$_" -ForegroundColor Red
      Write-Host "7zip 是解压 .7z 包（如 git）的依赖，请手动安装后重新运行本脚本。" -ForegroundColor Yellow
      pause
      exit 1
    }
  } else {
    Write-Host "7zip 已就绪，继续。" -ForegroundColor Green
  }

  Write-Host "[前置] 检查 Git 是否可用..." -ForegroundColor Cyan
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "未检测到 Git，将使用 Scoop 安装 Git（镜像预下载加速）..." -ForegroundColor Yellow
    try {
      Install-ScoopAppWithMirrorCache -AppName 'git'
      # --no-update-scoop：同上
      scoop install git --no-update-scoop
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
  # 统一再写一次 safe.directory（幂等）：覆盖"全新机器刚装完 git"与
  # "已装 git 但脚本开头 PATH 未就绪"的跨账号场景
  Set-GitSafeDirectory

  Write-Host "[步骤1] 恢复所有Bucket仓库（每个最多重试3次，全部成功才继续软件安装）" -ForegroundColor Cyan
  # 步骤1 期间临时放宽错误偏好：某个 bucket 目录损坏（如上次运行中断留下不完整 .git）时，
  # Scoop 内部 git 的 stderr（fatal: not a git repository）在 Stop 偏好下会被放大成异常，
  # 导致 scoop bucket list/add 被误判失败。Continue 下仅打印错误，成败仍由 $LASTEXITCODE 判断。
  $ErrorActionPreference = "Continue"
  # --- Bucket: main (镜像优先，失败自动回退官方) ---
  # 浅克隆加速：nju 镜像优先 → 加速代理 GitHub 回退（失败走下方完整 add 流程）
  Clone-BucketToDir 'main' (@('https://mirror.nju.edu.cn/git/scoop-main.git') + (Get-GitProxyUrls 'https://github.com/ScoopInstaller/Main.git')) | Out-Null
  Repair-BucketRemote 'main' (@('https://mirror.nju.edu.cn/git/scoop-main.git') + (Get-GitProxyUrls 'https://github.com/ScoopInstaller/Main.git'))

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
      $existingList = ""
      try { $existingList = scoop bucket list 2>&1 } catch { }
      if ((Test-BucketAlreadyPresent 'main') -or ($existingList -match [regex]::Escape('main'))) {
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
  # 浅克隆加速：nju 镜像优先 → 加速代理 GitHub 回退（失败走下方完整 add 流程）
  Clone-BucketToDir 'extras' (@('https://mirror.nju.edu.cn/git/scoop-extras.git') + (Get-GitProxyUrls 'https://github.com/ScoopInstaller/Extras.git')) | Out-Null
  Repair-BucketRemote 'extras' (@('https://mirror.nju.edu.cn/git/scoop-extras.git') + (Get-GitProxyUrls 'https://github.com/ScoopInstaller/Extras.git'))

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
      $existingList = ""
      try { $existingList = scoop bucket list 2>&1 } catch { }
      if ((Test-BucketAlreadyPresent 'extras') -or ($existingList -match [regex]::Escape('extras'))) {
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
  # 浅克隆加速：nju 镜像优先 → 加速代理 GitHub 回退（失败走下方完整 add 流程）
  Clone-BucketToDir 'versions' (@('https://mirror.nju.edu.cn/git/scoop-versions.git') + (Get-GitProxyUrls 'https://github.com/ScoopInstaller/Versions.git')) | Out-Null
  Repair-BucketRemote 'versions' (@('https://mirror.nju.edu.cn/git/scoop-versions.git') + (Get-GitProxyUrls 'https://github.com/ScoopInstaller/Versions.git'))

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
      $existingList = ""
      try { $existingList = scoop bucket list 2>&1 } catch { }
      if ((Test-BucketAlreadyPresent 'versions') -or ($existingList -match [regex]::Escape('versions'))) {
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
  # 浅克隆加速：加速代理 GitHub 优先（nju 无 sysinternals 镜像）→ 官方直连回退
  Clone-BucketToDir 'sysinternals' (Get-GitProxyUrls 'https://github.com/niheaven/scoop-sysinternals.git') | Out-Null
  Repair-BucketRemote 'sysinternals' (Get-GitProxyUrls 'https://github.com/niheaven/scoop-sysinternals.git')

  $retryCount = 0
  $bucketAddSuccess = $false
  while ($retryCount -lt 3 -and !$bucketAddSuccess) {
    $retryCount++
    Write-Host "尝试添加Bucket[sysinternals]，第$retryCount/3次"
    try {
      $existingList = ""
      try { $existingList = scoop bucket list 2>&1 } catch { }
      if ((Test-BucketAlreadyPresent 'sysinternals') -or ($existingList -match [regex]::Escape('sysinternals'))) {
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
  # 浅克隆加速：加速代理 HTTPS 优先 → 官方 HTTPS 回退（SSH 密钥场景交给下方完整 add 流程）
  Clone-BucketToDir 'myscoop' (Get-GitProxyUrls 'https://github.com/w3c0929/myscoop.git') | Out-Null
  Repair-BucketRemote 'myscoop' (Get-GitProxyUrls 'https://github.com/w3c0929/myscoop.git')

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
      $existingList = ""
      try { $existingList = scoop bucket list 2>&1 } catch { }
      if ((Test-BucketAlreadyPresent 'myscoop') -or ($existingList -match [regex]::Escape('myscoop'))) {
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
  # 浅克隆加速：gitee 源（国内直连）
  Clone-BucketToDir 'official' @(
    'https://gitee.com/cmontage/scoopbucket.git'
  ) | Out-Null
  Repair-BucketRemote 'official' @('https://gitee.com/cmontage/scoopbucket.git')

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
      $existingList = ""
      try { $existingList = scoop bucket list 2>&1 } catch { }
      if ((Test-BucketAlreadyPresent 'official') -or ($existingList -match [regex]::Escape('official'))) {
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

  $ErrorActionPreference = "Stop"
  Write-Host "`n✅ 所有Bucket仓库全部添加成功（此版本仅恢复 Bucket，不含软件安装）" -ForegroundColor Green

  # 清理 buckets_backup：对应 bucket 已恢复为完整 git 仓库的旧备份直接删除
  # （重建成功即无保留价值）；仅保留"对应 bucket 尚未恢复"的备份供手动还原。
  $bakRoot = Join-Path $scoopPath 'buckets_backup'
  if (Test-Path $bakRoot) {
    foreach ($bakItem in (Get-ChildItem -LiteralPath $bakRoot -Directory -ErrorAction SilentlyContinue)) {
      $bucketName = $bakItem.Name -replace '-\d{14}$', ''
      $bucketDir = Join-Path $scoopPath "buckets\$bucketName"
      $restored = $false
      if (Test-Path $bucketDir) {
        git -C $bucketDir rev-parse --verify HEAD 2>$null | Out-Null
        $restored = ($LASTEXITCODE -eq 0)
      }
      if ($restored) {
        Remove-Item -LiteralPath $bakItem.FullName -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  已清理重建成功的旧备份: $($bakItem.Name)" -ForegroundColor Gray
      } else {
        Write-Host "  [保留] 旧备份 $($bakItem.Name)（对应 bucket 尚未恢复，可手动还原）" -ForegroundColor Yellow
      }
    }
    if ((Get-ChildItem -LiteralPath $bakRoot -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) {
      Remove-Item -LiteralPath $bakRoot -Force -ErrorAction SilentlyContinue
      if (-not (Test-Path $bakRoot)) { Write-Host "  已移除空的 buckets_backup 目录" -ForegroundColor Gray }
    }
  }

  # 自动应用 myscoop 镜像补丁：bucket 恢复完成后运行 symlink.bat
  # （manifest.ps1/download.ps1 链接或拷贝），让后续 scoop install 的 GitHub 资产下载
  # 自动走加速镜像。symlink.bat 在非管理员下自动降级拷贝模式；--no-pause 跳过其结尾按键。
  $symlinkBat = Join-Path $scoopPath 'buckets\myscoop\symlink.bat'
  if (Test-Path $symlinkBat) {
    Write-Host "`n[补丁] 应用 myscoop 镜像补丁（symlink.bat）..." -ForegroundColor Cyan
    try {
      # 直接调用（不经 PowerShell 管道），避免 UTF-8 输出被按系统代码页解码导致乱码
      cmd /c "`"$symlinkBat`" --no-pause"
      if ($LASTEXITCODE -ne 0) {
        Write-Host "  [提示] symlink.bat 返回码 $LASTEXITCODE（可能部分链接/拷贝失败）" -ForegroundColor Yellow
      }
      $dlPatch = Join-Path $scoopPath 'apps\scoop\current\lib\download.ps1'
      if ((Test-Path $dlPatch) -and ((Get-Content -LiteralPath $dlPatch -Raw -ErrorAction SilentlyContinue) -match 'myscoop 补丁|GitHub 镜像加速补丁')) {
        Write-Host "  补丁已生效：后续 scoop install 的 GitHub 下载将自动走镜像" -ForegroundColor Green
      } else {
        Write-Host "  [提示] 补丁验证未通过，可手动右键以管理员运行 symlink.bat" -ForegroundColor Yellow
      }
    } catch {
      Write-Host "  [提示] 应用补丁失败：$($_.Exception.Message)；可手动运行 symlink.bat" -ForegroundColor Yellow
    }
  } else {
    Write-Host "`n[提示] 未找到 myscoop\symlink.bat，跳过镜像补丁" -ForegroundColor Yellow
  }
} catch {
  Write-Host "`n脚本发生致命错误：$_" -ForegroundColor Red
  Write-Host "错误堆栈：$($_.Exception.StackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nBucket 恢复完成，按任意键关闭窗口..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
