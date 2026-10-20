<#
.SYNOPSIS
    Chrome → ego lite 一键同步：数据（书签/Cookie/历史/密码/表单）+ 扩展，然后启动 ego。

.DESCRIPTION
    顺序执行：
      1) 关闭 ego（数据同步与扩展加载都需要）
      2) 数据同步（需 Chrome 已关闭；自动备份 ego 数据；书签为空时跳过保护 ego）
      3) 扩展同步（复制扩展 + 重建纯 ASCII 短路径链接；Chrome 可以开着）
      4) 启动 ego 并加载全部扩展（--load-extension，每次启动有效）

    注意：
    - Chrome 运行中会自动跳过数据同步（文件被锁），仅做扩展同步 + 启动
    - 不能靠复制 Secure Preferences 迁移扩展（HMAC 完整性校验会丢弃）
    - 扩展必须通过 --load-extension 每次启动加载（Chromium 的 location=8 特性）

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\sync-chrome-to-ego.ps1
    powershell -ExecutionPolicy Bypass -File .\sync-chrome-to-ego.ps1 -NoData   # 只同步扩展并启动
    powershell -ExecutionPolicy Bypass -File .\sync-chrome-to-ego.ps1 -NoLaunch # 只同步不启动
#>
param(
    [string]$ChromeRoot = (Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data'),
    [string]$ChromeProfile = 'Default',
    [string]$EgoRoot = (Join-Path $env:LOCALAPPDATA 'Citro Labs\ego\User Data'),
    [string]$EgoProfile = 'Default',
    [string]$EgoExe = 'D:\scoop\apps\egolite\current\ego.exe',
    [string]$StoreDir = 'D:\scoop\persist\egolite-exts',
    [string]$LinkDir = 'D:\scoop\persist\egolite-ext',
    [int]$KeepBackups = 3,
    [switch]$NoData,
    [switch]$NoExt,
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
function W($m, $c = 'Cyan') { Write-Host $m -ForegroundColor $c }

W "=== Chrome → ego lite 一键同步 ==="
Write-Host "  Chrome: $ChromeRoot\$ChromeProfile"
Write-Host "  ego   : $EgoRoot\$EgoProfile"
Write-Host ""

# ---------- 0) 路径校验 ----------
$chromeProf = Join-Path $ChromeRoot $ChromeProfile
if (-not (Test-Path $chromeProf)) { W "[错误] 未找到 Chrome 配置：$chromeProf" Red; exit 1 }
if (-not (Test-Path $EgoRoot)) {
    W "[错误] 未找到 ego 数据目录：$EgoRoot" Red
    W "        请先启动一次 ego lite 生成数据目录" Yellow
    exit 1
}
if (-not (Test-Path $EgoExe)) { W "[错误] 未找到 ego.exe：$EgoExe" Red; exit 1 }

# ---------- 1) 关闭 ego ----------
if (Get-Process ego -ErrorAction SilentlyContinue) {
    W "[1/3] 关闭 ego …" Yellow
    Get-Process ego -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
} else {
    W "[1/3] ego 未运行（OK）" DarkGray
}

# ---------- 2) 数据同步 ----------
if (-not $NoData) {
    if (Get-Process chrome -ErrorAction SilentlyContinue) {
        W "[2/3] 数据同步：Chrome 正在运行 → 跳过（关闭 Chrome 后重跑可同步书签/Cookie/历史/密码）" Yellow
    } else {
        W "[2/3] 数据同步 …"
        $egoProf = Join-Path $EgoRoot $EgoProfile

        # 备份 ego 数据（保留最近 N 个）
        $bak = "$EgoRoot.bak-$(Get-Date -Format yyyyMMddHHmmss)"
        Copy-Item $EgoRoot $bak -Recurse -Force
        W "  备份: $bak" DarkGray
        $old = @(Get-ChildItem (Split-Path $EgoRoot -Parent) -Directory -Filter 'User Data.bak-*' -ErrorAction SilentlyContinue |
                 Sort-Object Name -Descending | Select-Object -Skip $KeepBackups)
        if ($old.Count -gt 0) { $old | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }

        # 文件映射（相对路径）
        $fileMap = @(
            @{ Src = 'Local State'; Dst = 'Local State'; Note = 'Cookie/密码解密密钥' },
            @{ Src = "$ChromeProfile\Bookmarks"; Dst = "$EgoProfile\Bookmarks"; Note = '书签' },
            @{ Src = "$ChromeProfile\Bookmarks.bak"; Dst = "$EgoProfile\Bookmarks.bak"; Note = '' },
            @{ Src = "$ChromeProfile\Network\Cookies"; Dst = "$EgoProfile\Network\Cookies"; Note = 'Cookie' },
            @{ Src = "$ChromeProfile\Login Data"; Dst = "$EgoProfile\Login Data"; Note = '密码' },
            @{ Src = "$ChromeProfile\History"; Dst = "$EgoProfile\History"; Note = '历史' },
            @{ Src = "$ChromeProfile\Favicons"; Dst = "$EgoProfile\Favicons"; Note = '网站图标' },
            @{ Src = "$ChromeProfile\Top Sites"; Dst = "$EgoProfile\Top Sites"; Note = '常用站点' },
            @{ Src = "$ChromeProfile\Web Data"; Dst = "$EgoProfile\Web Data"; Note = '表单/自动填充' }
        )
        $copied = 0
        foreach ($m in $fileMap) {
            $s = Join-Path $ChromeRoot $m.Src
            $d = Join-Path $EgoRoot $m.Dst
            if (-not (Test-Path $s)) { continue }
            # 书签护栏：Chrome 本地书签为 0 时跳过（账号书签不在文件里，避免覆盖 ego 已导入的书签）
            if ($m.Src -eq "$ChromeProfile\Bookmarks") {
                $cnt = 0
                try {
                    $j = Get-Content $s -Raw -Encoding UTF8 | ConvertFrom-Json
                    foreach ($k in 'bookmark_bar', 'other', 'synced') {
                        $root = $j.roots.$k
                        if ($root) { $cnt += (Get-BmNode $root) }
                    }
                } catch { $cnt = 0 }
                if ($cnt -le 0) {
                    W "  [跳过] Bookmarks（Chrome 本地 0 个 → 可能是账号书签；如需要请导出 HTML 到 ego 导入）" Yellow
                    continue
                }
            }
            $dd = Split-Path $d -Parent
            if (-not (Test-Path $dd)) { New-Item -ItemType Directory -Force $dd | Out-Null }
            Copy-Item $s $d -Force
            W ("  [复制] {0,-28} {1,8:N1} KB" -f $m.Src, ((Get-Item $s).Length / 1KB)) Green
            $copied++
        }
        W "  数据同步完成：$copied 项" Green
    }
} else {
    W "[2/3] 数据同步：已跳过（-NoData）" DarkGray
}

# ---------- 3) 扩展同步 ----------
$links = @()
if (-not $NoExt) {
    W "[3/3] 扩展同步 …"
    $securePref = Join-Path $chromeProf 'Secure Preferences'
    $extRoot = Join-Path $chromeProf 'Extensions'
    if (-not (Test-Path $securePref)) {
        W "  [跳过] 找不到 Chrome 的 Secure Preferences" Yellow
    } else {
        $d = Get-Content $securePref -Raw -Encoding UTF8 | ConvertFrom-Json
        $settings = $d.extensions.settings
        $list = @()
        foreach ($prop in $settings.PSObject.Properties) {
            $v = $prop.Value
            if (-not $v -or $v.location -ne 1) { continue }
            $rel = $v.path
            if (-not $rel) { continue }
            $src = Join-Path $extRoot $rel
            if (-not (Test-Path $src)) { continue }
            $name = [string]$v.manifest.name
            if (-not $name) { $name = $prop.Name }
            $safe = ($name -replace '[\\/:*?"<>|]', '_')
            if ($safe.Length -gt 40) { $safe = $safe.Substring(0, 40) }
            $safe = ($safe -replace '\s+', ' ').Trim()
            if (-not $safe) { $safe = $prop.Name }
            $list += [pscustomobject]@{ Name = $safe; Src = $src }
        }
        if ($list.Count -eq 0) {
            W "  [跳过] 没有找到用户扩展" Yellow
        } else {
            New-Item -ItemType Directory -Force $StoreDir | Out-Null
            Get-ChildItem $StoreDir -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            $i = 0
            foreach ($e in ($list | Sort-Object Name)) {
                $i++
                $target = Join-Path $StoreDir ('{0:D2}-{1}' -f $i, $e.Name)
                robocopy $e.Src $target /E /NFL /NDL /NJH /NJS /NP | Out-Null
            }
            if (Test-Path $LinkDir) { Remove-Item $LinkDir -Recurse -Force -ErrorAction SilentlyContinue }
            New-Item -ItemType Directory -Force $LinkDir | Out-Null
            $i = 0
            foreach ($dir in (Get-ChildItem $StoreDir -Directory | Sort-Object Name)) {
                $i++
                $link = Join-Path $LinkDir ('ext{0:D2}' -f $i)
                cmd /c mklink /J "$link" "$($dir.FullName)" | Out-Null
                $links += $link
            }
            W "  扩展同步完成：$($links.Count) 个 → $LinkDir" Green
        }
    }
} else {
    W "[3/3] 扩展同步：已跳过（-NoExt）" DarkGray
}

# 没同步扩展时，也读取现有链接用于启动
if ($links.Count -eq 0 -and (Test-Path $LinkDir)) {
    $links = @(Get-ChildItem $LinkDir -Directory -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object { $_.FullName })
}

# ---------- 4) 启动 ----------
if (-not $NoLaunch) {
    if ($links.Count -eq 0) {
        W "[警告] 没有可加载的扩展，直接启动 ego" Yellow
        Start-Process $EgoExe -ErrorAction SilentlyContinue
    } else {
        W "启动 ego（加载 $($links.Count) 个扩展）…"
        $joined = $links -join ','
        Start-Process $EgoExe -ArgumentList "--load-extension=$joined" -ErrorAction SilentlyContinue
    }
}
W ""
W "[完成] 数据与扩展已处理。ego 启动后可在 ego://extensions 确认扩展。" Green
exit 0
