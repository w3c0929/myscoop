<#
.SYNOPSIS
    同步 Chrome 的扩展 → ego lite（重新复制 + 重建链接 + 分批加载）。

.DESCRIPTION
    Chrome 更新扩展版本后运行本脚本，让 ego 用上最新版扩展。
    原理（实测有效）：扩展复制到持久目录 → 用 junction 建立纯 ASCII 短路径 →
    分批用 `--load-extension` 启动 ego，扩展会以 location=8 写入配置，之后正常启动持久保留。
    注意：直接复制 Secure Preferences 不可行（HMAC 完整性校验会丢弃跨浏览器配置）。

    运行前会自动关闭 ego（加载需要重启）；Chrome 可以开着（只读取扩展文件）。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\sync-chrome-extensions.ps1
#>
param(
    [string]$ChromeRoot = (Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data'),
    [string]$ChromeProfile = 'Default',
    [string]$EgoExe = 'D:\scoop\apps\egolite\current\ego.exe',
    [string]$StoreDir = 'D:\scoop\persist\egolite-exts',
    [string]$LinkDir = 'D:\scoop\persist\egolite-ext',
    [int]$BatchSize = 11,
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
function W($m, $c = 'Cyan') { Write-Host $m -ForegroundColor $c }

W "=== Chrome 扩展 → ego lite 同步 ==="
Write-Host "  Chrome: $ChromeRoot\$ChromeProfile"
Write-Host "  ego   : $EgoExe"
Write-Host ""

# 1) 路径校验
$profDir = Join-Path $ChromeRoot $ChromeProfile
$securePref = Join-Path $profDir 'Secure Preferences'
$extRoot = Join-Path $profDir 'Extensions'
if (-not (Test-Path $securePref)) { W "[错误] 找不到 $securePref" Red; exit 1 }
if (-not (Test-Path $extRoot)) { W "[错误] 找不到扩展目录 $extRoot" Red; exit 1 }
if (-not (Test-Path $EgoExe)) { W "[错误] 找不到 ego.exe：$EgoExe" Red; exit 1 }

# 2) ego 必须关闭（加载过程会重启它）
if (Get-Process ego -ErrorAction SilentlyContinue) {
    W "[提示] 关闭正在运行的 ego（扩展加载需要重启）" Yellow
    Get-Process ego -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
}

# 3) 解析 Chrome 用户扩展（location=1）
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
if ($list.Count -eq 0) { W "[错误] 没找到用户扩展（location=1）" Red; exit 1 }
W "发现用户扩展: $($list.Count) 个"

# 4) 复制到持久目录（Scoop 卸载不删）
New-Item -ItemType Directory -Force $StoreDir | Out-Null
# 先清空旧内容：扩展改名/数量变化时，旧目录会残留（曾导致链接数 27 > 扩展数 22）
Get-ChildItem $StoreDir -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
$i = 0
foreach ($e in ($list | Sort-Object Name)) {
    $i++
    $target = Join-Path $StoreDir ('{0:D2}-{1}' -f $i, $e.Name)
    if (Test-Path $target) { Remove-Item $target -Recurse -Force -ErrorAction SilentlyContinue }
    robocopy $e.Src $target /E /NFL /NDL /NJH /NJS /NP | Out-Null
    W ("  [{0:D2}] {1}" -f $i, $e.Name) DarkGray
}

# 5) 重建 junction（纯 ASCII 短路径，避免长中文路径导致加载失败）
if (Test-Path $LinkDir) { Remove-Item $LinkDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force $LinkDir | Out-Null
$i = 0
$links = @()
foreach ($dir in (Get-ChildItem $StoreDir -Directory | Sort-Object Name)) {
    $i++
    $link = Join-Path $LinkDir ('ext{0:D2}' -f $i)
    cmd /c mklink /J "$link" "$($dir.FullName)" | Out-Null
    $links += $link
}
W "已创建链接: $($links.Count) 个 → $LinkDir"

# 6) 完成：加载交给 sync-chrome-extensions.bat
#    注意：不能用 `--load-extension` 持久化——它写入 location=8（COMMAND_LINE），
#    只在启动时带该参数才加载；正常启动不加载（曾误判为"持久化"）。
#    Chromium 的"加载未打包的扩展程序"（UI）写 location=4 才真正持久，但对话框一次只能选一个目录、无法批量。
#    因此本项目改用「每次启动带 --load-extension」：由 sync-chrome-extensions.bat 拼接全部扩展路径启动。
W ""
W "[完成] 扩展文件已同步：$($links.Count) 个 → $LinkDir" Green
W "       接下来双击 sync-chrome-extensions.bat 启动 ego（会自动加载全部扩展）。" Green
if (-not $NoLaunch) {
    $bat = Join-Path (Split-Path -Parent $PSCommandPath) 'sync-chrome-extensions.bat'
    if (Test-Path $bat) {
        W "       正在调用启动脚本 …"
        & cmd.exe /c "`"$bat`""
    }
}
exit 0
