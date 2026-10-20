<#
.SYNOPSIS
    单向同步 Chrome 用户数据 → ego lite（书签 / Cookie / 历史 / 密码 / 表单等）。

.DESCRIPTION
    为什么是单向：ego 运行后会把数据库升级到自己的 schema，反向同步可能让 Chrome 打不开。
    为什么不能 symlink：Chromium 保存文件是"写临时文件 + rename"，会替换掉链接本身；
    且 SQLite（Cookies/History/Login Data）运行时会加锁，两进程共用会损坏数据库。
    所以采用「关闭浏览器时一次性复制」的方式。

    复制内容：Local State（Cookie/密码解密密钥，关键）、Bookmarks、Network\Cookies、
    Login Data、History、Favicons、Top Sites、Web Data。
    不复制 Preferences（避免覆盖 ego 自己的界面/设置）。

.PARAMETER ChromeRoot    Chrome 用户数据根目录（默认 %LOCALAPPDATA%\Google\Chrome\User Data）
.PARAMETER EgoRoot       ego 用户数据根目录（默认 %LOCALAPPDATA%\Citro Labs\ego\User Data）
.PARAMETER ChromeProfile Chrome 的 profile 目录名（默认 Default）
.PARAMETER EgoProfile    ego 的 profile 目录名（默认 Default）
.PARAMETER KeepBackups   保留最近几个 ego 备份（默认 3）
.PARAMETER NoBackup      跳过备份（不建议）

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\sync-chrome-to-ego.ps1
#>
param(
    [string]$ChromeRoot = (Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data'),
    [string]$EgoRoot    = (Join-Path $env:LOCALAPPDATA 'Citro Labs\ego\User Data'),
    [string]$ChromeProfile = 'Default',
    [string]$EgoProfile = 'Default',
    [int]$KeepBackups = 3,
    [switch]$NoBackup,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Write-Step($msg) { Write-Host $msg -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host $msg -ForegroundColor Green }
function Write-Skip($msg) { Write-Host $msg -ForegroundColor DarkGray }
function Write-Warn($msg) { Write-Host $msg -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host $msg -ForegroundColor Red }

function Get-BmNode($node) {
    if (-not $node) { return 0 }
    if ($node.type -eq 'url') { return 1 }
    $n = 0
    foreach ($ch in @($node.children)) { if ($ch) { $n += (Get-BmNode $ch) } }
    return $n
}

function Get-BookmarkCount([string]$path) {
    # 统计 Chromium Bookmarks 文件里的 URL 书签数；解析失败返回 -1
    try {
        $j = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
        $sum = 0
        foreach ($k in 'bookmark_bar', 'other', 'synced') {
            $root = $j.roots.$k
            if ($root) { $sum += (Get-BmNode $root) }
        }
        return $sum
    } catch { return -1 }
}

Write-Step "=== Chrome → ego lite 单向同步 ==="
Write-Host "  Chrome: $ChromeRoot"
Write-Host "  ego   : $EgoRoot"
Write-Host ""

# 1) 源/目标目录检查
if (-not (Test-Path $ChromeRoot)) {
    Write-Err "[错误] 未找到 Chrome 用户数据目录：$ChromeRoot"
    exit 1
}
if (-not (Test-Path $EgoRoot)) {
    Write-Err "[错误] 未找到 ego 用户数据目录：$EgoRoot"
    Write-Warn "        请先启动一次 ego lite（生成 %LOCALAPPDATA%\Citro Labs\ego\User Data）后重试。"
    exit 1
}

# 2) 浏览器必须完全退出（否则文件锁 + 数据不一致）
$running = @(Get-Process chrome, ego -ErrorAction SilentlyContinue)
if ($running.Count -gt 0 -and -not $Force) {
    Write-Err "[错误] 浏览器仍在运行，请先完全退出："
    $running | Group-Object ProcessName | ForEach-Object {
        Write-Host ("        {0}（{1} 个进程）" -f $_.Name, $_.Count) -ForegroundColor Red
    }
    Write-Warn "        Chrome 关窗口后可能仍在后台停留：设置 → 系统 → 关闭「关闭 Google Chrome 后继续运行后台应用」，"
    Write-Warn "        或从任务管理器结束所有 chrome.exe。"
    exit 1
}

# 3) 备份 ego 数据（可回滚）
if (-not $NoBackup) {
    $bak = "$EgoRoot.bak-$(Get-Date -Format yyyyMMddHHmmss)"
    Copy-Item $EgoRoot $bak -Recurse -Force
    Write-Skip "[备份] $bak"
    $parent = Split-Path $EgoRoot -Parent
    $old = @(Get-ChildItem $parent -Directory -Filter 'User Data.bak-*' -ErrorAction SilentlyContinue |
             Sort-Object Name -Descending | Select-Object -Skip $KeepBackups)
    if ($old.Count -gt 0) {
        $old | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Skip "[清理] 删除旧备份 $($old.Count) 个（保留最近 $KeepBackups 个）"
    }
}

# 4) 逐项复制（只复制源存在的；缺目录自动创建）
$fileMap = @(
    @{ Src = 'Local State';                         Dst = 'Local State';                         Note = 'Cookie/密码解密密钥' },
    @{ Src = "$ChromeProfile\Bookmarks";            Dst = "$EgoProfile\Bookmarks";               Note = '书签' },
    @{ Src = "$ChromeProfile\Bookmarks.bak";        Dst = "$EgoProfile\Bookmarks.bak";           Note = '' },
    @{ Src = "$ChromeProfile\Network\Cookies";      Dst = "$EgoProfile\Network\Cookies";         Note = 'Cookie' },
    @{ Src = "$ChromeProfile\Login Data";           Dst = "$EgoProfile\Login Data";              Note = '密码' },
    @{ Src = "$ChromeProfile\History";              Dst = "$EgoProfile\History";                 Note = '历史' },
    @{ Src = "$ChromeProfile\Favicons";             Dst = "$EgoProfile\Favicons";                Note = '网站图标' },
    @{ Src = "$ChromeProfile\Top Sites";            Dst = "$EgoProfile\Top Sites";               Note = '常用站点' },
    @{ Src = "$ChromeProfile\Web Data";             Dst = "$EgoProfile\Web Data";                Note = '表单/自动填充' }
)

$copied = 0
$skipped = 0
foreach ($m in $fileMap) {
    $s = Join-Path $ChromeRoot $m.Src
    $d = Join-Path $EgoRoot $m.Dst
    if (-not (Test-Path $s)) {
        Write-Skip ("  [跳过] {0}（源不存在）" -f $m.Src)
        $skipped++
        continue
    }
    # 书签护栏：Chrome 本地 Bookmarks 为空时跳过 —— Chrome 登录账号后书签可能只存在同步库
    # （Sync Data），本地文件长期为空。直接复制会用空书签覆盖 ego 里已有的书签（曾发生）。
    if ($m.Src -eq "$ChromeProfile\Bookmarks") {
        $bmCount = Get-BookmarkCount $s
        if ($bmCount -le 0) {
            Write-Warn ("  [跳过] {0}（Chrome 本地书签 {1} 个 → 很可能在账号里；跳过以免覆盖 ego 已有书签）" -f $m.Src, $bmCount)
            Write-Warn "         账号书签：Chrome 打开 chrome://bookmarks → ⋮ → 导出书签；再到 ego 的 ego://bookmarks → 导入书签"
            $skipped++
            continue
        }
        Write-Host ("  [书签] Chrome 本地共 {0} 个书签，将覆盖 ego 的书签栏" -f $bmCount) -ForegroundColor DarkCyan
    }
    $dDir = Split-Path $d -Parent
    if (-not (Test-Path $dDir)) { New-Item -ItemType Directory -Force $dDir | Out-Null }
    Copy-Item $s $d -Force
    $size = (Get-Item $s).Length
    $label = if ($m.Note) { "$($m.Src)（$($m.Note)）" } else { $m.Src }
    Write-Ok ("  [复制] {0,-42} {1,9:N1} KB" -f $label, ($size / 1KB))
    $copied++
}

Write-Host ""
if ($copied -eq 0) {
    Write-Warn "[完成] 没有可复制的项（请确认 Chrome 用的是 $ChromeProfile 配置）。"
    exit 1
}
Write-Step "[完成] 共复制 $copied 项，跳过 $skipped 项。"
Write-Host "       现在启动 ego lite 即可看到书签 / Cookie / 历史。"
Write-Host "       提示：ego 首次启动会升级数据库 schema，之后不要把 ego 的数据反向往 Chrome 同步。"

exit 0
