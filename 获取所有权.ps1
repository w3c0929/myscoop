<#
================================================================================
 获取所有权.ps1 —— 全盘权限体检修复：清理旧机器残留 SID + 获取所有权
================================================================================
 来源  ：由《智能模式Scoop.ps1》第 118-185 行「前置体检：.ssh 权限自动检测修复」
         （Repair-SshPermissions）功能改造而来，已去掉全部 Scoop 无关代码。
 适用  ：从旧机器迁移过来的数据盘（默认 D:\、E:\），ACL 上残留旧机器/旧账号的
         SID（资源管理器中显示为 UNKNOWN\S-1-5-21-...），导致文件无法访问或
         权限显示异常。本脚本自动完成：
   1) 扫描    ：遍历全盘，找出 ACL 含「无法解析 SID」（旧机器残留）的文件/目录，
                以及所有者不属于当前用户/Administrators/SYSTEM 的项
   2) 获取所有权：对每个盘执行 takeown /f <盘> /r /d y，所有者统一收归 Administrators
   3) 修复    ：移除残留 SID 的授权/拒绝 ACE；对当前用户无任何访问权的项补授完全控制
   4) 验证    ：重扫一遍，报告仍残留的项（数量 + 示例路径）
 安全设计：
   * 只清理「无法解析为已知账号」的残留 SID；Everyone/Users 等正常账号一概不动
   * 不执行 /inheritance:r，不破坏继承链（残留 SID 只需在其「显式」所在处移除，
     子项继承的会随之消失）
   * 跳过 reparse point（junction/符号链接/云盘占位）、$RECYCLE.BIN、
     System Volume Information
   * 加 -Log 时：写 .log 日志 并 自动备份受影响项的 ACL（.acl，icacls /save），可供回滚；默认均不生成
   * 默认仅输出控制台；正式修复前有 Y/N 确认
   * 跳过清单：node_modules/.git 等同名文件夹任意层级跳过（param 区修改，-SkipNames 可覆盖）
   * 修复0失败自动跳过全盘复扫（-Rescan 强制）；有失败项自动重扫兜底定位残留
 用法（文件名预选，与「智能模式Scoop.ps1」同款）：
   .\获取所有权.ps1                # 打开菜单手动选择，任务完成后停留
   .\获取所有权(1).ps1             # 文件名预选：直接执行第1项「只读体检」
   .\获取所有权(2).ps1             # 文件名预选：直接执行第2项「正式修复」
   .\获取所有权(3).ps1             # 文件名预选：直接执行第3项「选择目录/文件」
   .\获取所有权(3e2).ps1           # 预选直达：第3项并直接选中 E 盘第2个条目（盘符大小写均可，如 (3d1)）
   .\获取所有权(4).ps1             # 文件名预选：直接进入第4项「粘贴路径处理」
   .\获取所有权(5).ps1             # 文件名预选：直接执行第5项「退出」
   .\获取所有权.ps1 -Menu          # 预选模式下也强制显示菜单
   .\获取所有权.ps1 -Roots E:\     # 只处理 E:\（第3项默认列出所有非 C 盘根目录；显式 -Roots 时按指定盘列出）
   .\获取所有权.ps1 -DryRun        # 强制只读体检（不修改）
   .\获取所有权.ps1 -Log           # 生成 .log 日志 + .acl ACL备份（默认均不生成，需要时开启）
   echo Y | .\获取所有权.ps1       # 跳过「正式修复」前的确认提示
 回滚（-Log 开启时，日志末尾会给出每块盘的具体命令）：
   cd D:\ ; icacls D:\ /restore <备份文件.acl> /T /C     （管理员）
================================================================================
#>

[CmdletBinding()]
param(
    [string[]]$Roots   = @("D:\", "E:\"),
    [switch]$DryRun,     # 只检测与预览，不改任何东西
    [switch]$Menu,       # 强制显示菜单（文件名预选模式下也能进入菜单）
    [switch]$Log,        # 生成 .log 日志 + .acl ACL 备份（默认均不生成）
    # ★ 跳过清单（用户设置区）：扫描/验证时跳过任意层级中这些名字的文件夹（大小写不敏感），修改此处即可长期生效
    #   命令行可用 -SkipNames 整体替换，如：.\获取所有权.ps1 -SkipNames node_modules,.git
    [string[]]$SkipNames = @(
        'node_modules', '.git', '.svn', '.hg',           # 依赖 + 版本控制
        '.venv', 'venv', '__pycache__', '.pytest_cache', 'site-packages', 'envs', 'pkgs',  # Python：虚拟环境/字节码/conda 包目录与缓存
        'dist', 'build', 'out', 'target', 'bin', 'obj',  # 构建产物
        '.next', '.nuxt', '.output',                     # 前端产物
        '.pnpm-store', '.npm', '.gradle', '.m2',         # 包/构建缓存
        '.idea', '.vs', '.vscode'                        # IDE 配置
        ),
    [switch]$Rescan,     # 修复成功后强制全盘重扫验证（默认：修复0失败时跳过复扫）
    [string]$LogDir    = ''
)

# -File 启动 + [CmdletBinding()] 时 PS 5.1 的 $PSScriptRoot 可能为空，需兜底
if (-not $LogDir) {
    if ($PSScriptRoot) { $LogDir = $PSScriptRoot }
    elseif ($MyInvocation.MyCommand.Path) { $LogDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
    else { $LogDir = (Get-Location).Path }
}

# ---- 文件名预选：解析自身文件名括号中的菜单序号（如 获取所有权(2).ps1） ----
# 扩展语法：(3e2) = 第3项「选择目录/文件」并直达 E 盘第2个条目（盘符大小写均可，如 (3D1)）
$preSelect = $null
$prePickDrive = $null
$prePickIndex = $null
$myPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
$scriptBaseName = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path -Leaf $myPath))
$fnameMatch = [regex]::Match($scriptBaseName, '[\(（]([^\(\)（）]*)[\)）]\s*$')
if ($fnameMatch.Success) {
    $fnameValue = $fnameMatch.Groups[1].Value.Trim()
    if ($fnameValue -match '^[1-5]$') { $preSelect = $fnameValue }
    elseif ($fnameValue -match '^3([A-Za-z])(\d+)$') {
        $preSelect = '3'
        $prePickDrive = $Matches[1].ToUpper()
        $prePickIndex = [int]$Matches[2]
    }
}

# ---- 菜单（与「智能模式Scoop.ps1」同款：括号数字预选 > -Menu 强制菜单 > 默认开菜单） ----
$select = $null
if ($null -ne $preSelect -and -not $Menu) {
    Write-Host "`n【文件名预选】直接执行第 ${preSelect} 项" -ForegroundColor Cyan
    $select = $preSelect
} else {
    Clear-Host
    Write-Host "==================== 获取所有权工具 ====================" -ForegroundColor Cyan
    Write-Host "请选择操作："
    Write-Host "1. 只读体检：扫描 D:\ E:\ 全盘残留SID与所有者异常，仅报告不修改"
    Write-Host "2. 正式修复：获取所有权 + 清理残留SID + 补授访问权（需管理员）"
    Write-Host "3. 选择目录/文件：列出所有非 C 盘（D/E/F…）的根目录，选中后体检并可修复"
    Write-Host "4. 粘贴路径处理：输入文件夹/文件路径，只处理该路径及其内部全部内容"
    Write-Host "5. 退出"
    Write-Host "======================================================" -ForegroundColor Cyan
    $select = Read-Host "输入数字 1、2、3、4 或 5"
}
if ($select -eq "5") { exit 0 }
if ($select -notmatch '^[1-5]$') { Write-Host "输入错误，仅支持 1 / 2 / 3 / 4 / 5，脚本退出" -ForegroundColor Red; exit 1 }

if ($PSVersionTable.PSVersion.Major -lt 5) { Write-Host "需要 PowerShell 5.0+"; exit 1 }

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# ---------- 常量 ----------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$currentSid = ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
# 允许的所有者白名单：当前用户 / SYSTEM / Administrators / TrustedInstaller
$okOwnerSids = @($currentSid, 'S-1-5-18', 'S-1-5-32-544', 'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464')
# 判定「当前用户是否有访问权」的 SID：当前用户 / Users / Authenticated Users
$userishSids = @($currentSid, 'S-1-5-32-545', 'S-1-5-11')
$REPARSE = 1024  # FileAttributes.ReparsePoint
# 跳过清单正则：路径任意层级出现清单中的目录名即命中（连带其整棵子树），大小写不敏感
$script:skipPattern = '(\\|^)(' + (($SkipNames | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')(\\|$)'

$Roots = @($Roots | ForEach-Object { if ($_ -match '^[A-Za-z]:$') { "$_\" } else { $_ } } | Select-Object -Unique)

# ---------- 日志与 ACL 备份开关（默认关闭：加 -Log 参数开启，或把下行改为 $true 永久开启） ----------
$script:logEnabled = $Log
if (-not (Test-Path -LiteralPath $LogDir)) { try { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null } catch {} }
$logFile = Join-Path $LogDir ("获取所有权_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')

function Write-Log {
    param([string]$Msg, [string]$Color = 'Gray')
    Write-Host $Msg -ForegroundColor $Color
    if ($script:logEnabled) { try { Add-Content -LiteralPath $logFile -Value ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Msg) -Encoding UTF8 } catch {} }
}

# ---------- 工具函数（改造自 Repair-SshPermissions） ----------
# 从 IdentityReference/Owner 提取 SID 字符串；无法提取返回 $null
# 注意：Get-Acl 的 Owner 在不同 PowerShell 版本下可能是 SecurityIdentifier/NTAccount/字符串，
#       不能直接访问 .Value，必须先判断类型
function Get-SidString {
    param($Identity)
    if ($null -eq $Identity) { return $null }
    if ($Identity -is [System.Security.Principal.SecurityIdentifier]) { return $Identity.Value }
    # NTAccount（如 NT AUTHORITY\SYSTEM）必须翻译成 SID；翻译失败的保留原名由调用方判定
    if ($Identity -is [System.Security.Principal.NTAccount]) {
        try { return $Identity.Translate([System.Security.Principal.SecurityIdentifier]).Value } catch { return $Identity.Value }
    }
    $text = ''
    if ($Identity -is [string]) { $text = $Identity } else { try { $text = $Identity.ToString() } catch { return $null } }
    $m = [regex]::Match($text, 'S-\d+(-\d+)+')
    if ($m.Success) { return $m.Value }
    try { return ([Security.Principal.NTAccount]$text).Translate([Security.Principal.SecurityIdentifier]).Value } catch { return $null }
}

# ACL 中「无法解析为已知账号」的残留 SID；默认只看显式 ACE（继承的交给父级修复）
function Get-ResidualSids {
    param($Acl, [switch]$IncludeInherited)
    $bad = @()
    foreach ($ace in $Acl.Access) {
        if ($ace.IsInherited -and -not $IncludeInherited) { continue }
        $sid = Get-SidString $ace.IdentityReference
        if (-not $sid) { $bad += $ace.IdentityReference.ToString(); continue }
        try { $null = ([Security.Principal.SecurityIdentifier]$sid).Translate([Security.Principal.NTAccount]) }
        catch { $bad += $sid }   # 无法解析 → 旧机器残留
    }
    return @($bad | Select-Object -Unique)
}

# 当前用户（或其 Users/Authenticated Users 组）是否已有有效访问权（含继承）
function Test-UserAccess {
    param($Acl)
    foreach ($ace in $Acl.Access) {
        if ($ace.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow) { continue }
        if ([int]$ace.FileSystemRights -eq 0) { continue }   # 注：FileSystemRights 枚举没有 None 成员
        $sid = Get-SidString $ace.IdentityReference
        if ($sid -in $userishSids) { return $true }
    }
    return $false
}

# 菜单项3：生成每个 Root 的顶层目录/文件目标列表（供手动选择与文件名预选直达共用）
function Get-PickerTargets {
    param([string[]]$RootList)
    $targets = New-Object System.Collections.Generic.List[object]
    foreach ($r in $RootList) {
        if (-not (Test-Path -LiteralPath $r)) { continue }
        $items = @(Get-ChildItem -LiteralPath $r -Force -ErrorAction SilentlyContinue | Sort-Object { -not $_.PSIsContainer }, Name)
        $n = 0
        foreach ($it in $items) {
            $n++
            $tag = $r.Substring(0, 1) + $n
            $targets.Add([pscustomobject]@{ Tag = $tag; Path = $it.FullName; IsDir = $it.PSIsContainer; Root = $r; Name = $it.Name })
        }
    }
    return $targets
}

# 菜单项3：列出目标列表，供用户手动输入编号选择
function Show-RootPicker {
    param([string[]]$RootList)
    $targets = Get-PickerTargets -RootList $RootList
    foreach ($r in $RootList) {
        if (-not (Test-Path -LiteralPath $r)) { Write-Host ("[提示] 不存在或不可访问，跳过: " + $r) -ForegroundColor Yellow; continue }
        Write-Host ("============ " + $r + " 根目录 ============") -ForegroundColor Cyan
        $sub = @($targets | Where-Object { $_.Root -eq $r })
        if ($sub.Count -eq 0) { Write-Host "  （空或无权限读取）" -ForegroundColor DarkGray; continue }
        foreach ($it in $sub) {
            $suffix = if ($it.IsDir) { '\' } else { '' }
            Write-Host ("  [{0}] {1}{2}" -f $it.Tag, $it.Name, $suffix) -ForegroundColor Gray
        }
    }
    if ($targets.Count -eq 0) { Write-Host "没有可选择的条目" -ForegroundColor Red; return $null }
    while ($true) {
        $userInput = Read-Host "`n输入要执行的编号（如 D2，忽略大小写），直接回车返回菜单"
        if ([string]::IsNullOrWhiteSpace($userInput)) { return $null }
        $hit = $targets | Where-Object { $_.Tag -ieq $userInput.Trim() } | Select-Object -First 1
        if ($null -ne $hit) { return $hit }
        Write-Host ("无效编号 {0}，格式示例：D1 / E2（忽略大小写）" -f $userInput) -ForegroundColor Red
    }
}

# 跳过项：junction/符号链接/云盘占位（reparse point）、回收站、卷信息目录、
#         以及「跳过清单」命中的目录及其整棵子树（清单见脚本开头 param 区）
function Test-SkipItem {
    param($Item)
    if (($Item.Attributes -band $REPARSE) -ne 0) { return $true }
    if ($Item.FullName -match '(\\|^)(\$RECYCLE\.BIN|System Volume Information)(\\|$)') { return $true }
    if ($Item.FullName -match $script:skipPattern) { return $true }
    return $false
}

# 扫描单项：有残留SID（显式）或所有者异常 → 加入修复计划
function Add-ScanItem {
    param($Item, [bool]$IsDir, [string]$Root, [System.Collections.Generic.List[object]]$Plan)
    $path = $Item.FullName
    try { $acl = Get-Acl -LiteralPath $path -ErrorAction Stop } catch {
        $script:unreadItems++
        if ($script:unreadItems -le 20) { $script:unreadSample.Add($path) }
        return
    }
    $residual = @(Get-ResidualSids $acl)
    $ownerSid = Get-SidString $acl.Owner
    $ownerBad = (-not $ownerSid) -or ($ownerSid -notin $okOwnerSids)
    if ($residual.Count -gt 0 -or $ownerBad) {
        $Plan.Add([pscustomobject]@{ Path = $path; Root = $Root; IsDir = $IsDir; Sids = $residual; OwnerBad = $ownerBad })
    }
}

# 扫描/验证进度反馈：实时进度条（当前路径/已处理数/耗时/速率）+ 每1万项一行控制台日志
$script:progressStart = $null
$script:lastProgressLine = 0
function Update-Progress {
    param([string]$Activity, $Item, [int]$Count, [int]$LineEvery = 10000)
    if ($null -eq $script:progressStart) { $script:progressStart = Get-Date }
    $secs = ((Get-Date) - $script:progressStart).TotalSeconds
    $rate = if ($secs -gt 0) { [int]($Count / $secs) } else { 0 }
    $short = ''
    if ($null -ne $Item) {
        $short = $Item.FullName
        if ($short.Length -gt 60) { $short = $short.Substring(0, 57) + '...' }
    }
    if ($Count % 400 -eq 0) {
        Write-Progress -Id 1 -Activity $Activity -Status $short -CurrentOperation ("已处理 {0} 项 · 用时 {1:N1} 秒 · 平均 {2} 项/秒" -f $Count, $secs, $rate)
    }
    if (($Count - $script:lastProgressLine) -ge $LineEvery) {
        $script:lastProgressLine = $Count
        Write-Log ("[进度] {0} · 已处理 {1} 项 · 当前 {2} · 用时 {3:N1} 秒" -f $Activity, $Count, $short, $secs) 'DarkGray'
    }
}

# 扫描一个盘（含盘根自身）
function Invoke-ScanRoot {
    param([string]$Root, [System.Collections.Generic.List[object]]$Plan)
    $rootItem = Get-Item -LiteralPath $Root -Force -ErrorAction SilentlyContinue
    if ($null -eq $rootItem) { return $false }
    $script:totalItems++
    Add-ScanItem $rootItem $true $Root $Plan
    Get-ChildItem -LiteralPath $Root -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $script:totalItems++
        if (Test-SkipItem $_) { $script:skipItems++; return }   # 先判断跳过，跳过的项不进进度条显示
        Update-Progress -Activity ("扫描 " + $Root) -Item $_ -Count $script:totalItems
        Add-ScanItem $_ $_.PSIsContainer $Root $Plan
    }
    return $true
}

# 单项：备份 ACL → 移除残留 SID → 视需要补授当前用户完全控制
# 注意：icacls /remove:g 无法删除「无法解析」的孤儿 SID（退出码 1332，
#       ERROR_NONE_MAPPED），必须用 .NET ACL 操做，这是本函数的正解。
function Backup-And-Fix {
    param($Rec, [string]$BackupFile, [System.Collections.Generic.List[string]]$FailList)
    $path = $Rec.Path

    # 1) ACL 备份（相对路径，从该盘根目录生成，便于 icacls /restore 回滚；-Log 开启才执行）
    if ($script:logEnabled) {
        $rel = $path.Substring($Rec.Root.Length).TrimStart('\')
        if ($rel -eq '') { $rel = '.' }
        try {
            Push-Location $Rec.Root
            & icacls.exe $rel /save $BackupFile /C 2>&1 | Out-Null
            Pop-Location
        } catch { try { Pop-Location } catch {} }
    }

    # 2) 读取 ACL，移除残留 SID 的 ACE（只动显式 ACE，继承的交给父级修复）
    try { $acl = Get-Acl -LiteralPath $path -ErrorAction Stop } catch { $FailList.Add($path); return $false }
    $changed = $false
    foreach ($ace in @($acl.Access)) {
        if ($ace.IsInherited) { continue }
        $sid = Get-SidString $ace.IdentityReference
        $isBad = $false
        if (-not $sid) { $isBad = $true }
        else {
            try { $null = ([Security.Principal.SecurityIdentifier]$sid).Translate([Security.Principal.NTAccount]) } catch { $isBad = $true }
        }
        if ($isBad) {
            try { $null = $acl.RemoveAccessRuleSpecific($ace); $changed = $true } catch {}
        }
    }

    # 3) 当前用户已无访问权（含继承）→ 补授完全控制（目录带 OI|CI 继承）
    if (-not (Test-UserAccess $acl)) {
        $inherit = [System.Security.AccessControl.InheritanceFlags]::None
        if ($Rec.IsDir) {
            $inherit = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
        }
        try {
            $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
                $currentSid,
                [System.Security.AccessControl.FileSystemRights]::FullControl,
                $inherit,
                [System.Security.AccessControl.PropagationFlags]::None,
                [System.Security.AccessControl.AccessControlType]::Allow)
            $acl.AddAccessRule($rule)
            $changed = $true
        } catch {}
    }

    if (-not $changed) { return $true }   # 无可动项 → 无需写回

    # 4) 写回并复核
    try { Set-Acl -LiteralPath $path -AclObject $acl -ErrorAction Stop } catch { $FailList.Add($path); return $false }
    $still = @(Get-ResidualSids (Get-Acl -LiteralPath $path -ErrorAction SilentlyContinue))
    if ($still.Count -gt 0) { $FailList.Add($path); return $false }
    return $true
}

# ---------- 主流程 ----------
Write-Log "===== 获取所有权.ps1    目标盘: $($Roots -join '  ') =====" 'Cyan'
if (-not $script:logEnabled) { Write-Log "[提示] 日志与 ACL 备份未开启：本次不生成 .log/.acl 文件（需要时加 -Log 参数）" 'DarkGray' }
Write-Log "[提示] 扫描中会实时显示进度条（当前路径 / 已处理数量 / 耗时 / 速率），文件多时请耐心等待" 'DarkGray'
Write-Log ("[提示] 跳过清单已启用（" + ($SkipNames -join '、') + "），匹配的文件夹计入「跳过辅助项」统计；-SkipNames 可临时更换" ) 'DarkGray'
if ($DryRun -or $select -eq "1") {
    Write-Log "[模式] 只读体检：只检测与预览，不修改任何文件" 'Yellow'
} elseif (-not $isAdmin) {
    if ($select -eq "3" -or $select -eq "4") {
        Write-Log "[提示] 当前非管理员：可体检查看，正式修复请以管理员身份重新运行" 'Yellow'
    } else {
        Write-Log "[错误] 修复模式需要管理员权限：请右键「以管理员身份运行」；检测预览请加 -DryRun" 'Red'
        exit 1
    }
} else {
    Write-Log "[前置] 运行身份: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)" 'Cyan'
}

$script:totalItems = 0; $script:skipItems = 0; $script:unreadItems = 0
$script:remainTotal = 0
$script:unreadSample = New-Object System.Collections.Generic.List[string]
$backupMap = @{}
$planTotal = 0; $failTotal = 0

# ---- 菜单项3/4：先挑选目标（列表编号 或 粘贴路径），再对其执行体检（可修复） ----
$picked = $null
if ($select -eq "3") {
    # 默认列出所有非 C 盘（D/E/F…自动发现，含新增盘）；显式 -Roots 则按指定盘列出
    # 同时排除 Temp 这类 Root 指向 C:\ 的别名映射盘，避免 C 盘内容混入列表
    if ($MyInvocation.BoundParameters.ContainsKey('Roots')) {
        $pickerRoots = @($Roots)
    } else {
        $pickerRoots = @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne 'C' -and $_.Root -notlike 'C:\*' } |
            ForEach-Object { $_.Root })
    }
    # 文件名预选直达：如 (3e2).ps1 → 直接选中 E 盘第2个条目
    if ($prePickDrive -and $prePickIndex) {
        $wantedTag = $prePickDrive + $prePickIndex
        $picked = Get-PickerTargets -RootList $pickerRoots | Where-Object { $_.Tag -ieq $wantedTag } | Select-Object -First 1
        if ($null -eq $picked) {
            Write-Log ("[预选] 未找到目标 " + $wantedTag + "（盘不存在或条目数不足），转为手动选择") 'Yellow'
        }
    }
    if ($null -eq $picked) { $picked = Show-RootPicker -RootList $pickerRoots }
} elseif ($select -eq "4") {
    # 菜单项4：直接粘贴文件夹/文件路径，只处理该路径及其内部全部内容
    while ($true) {
        $pathInput = Read-Host "`n请输入要处理的文件夹或文件路径（可直接粘贴，如 E:\09.同步\00.分享），直接回车退出"
        if ([string]::IsNullOrWhiteSpace($pathInput)) { break }
        $pathInput = $pathInput.Trim().Trim('"', "'")
        if (Test-Path -LiteralPath $pathInput) {
            $ti = Get-Item -LiteralPath $pathInput -Force
            $picked = [pscustomobject]@{ Path = $ti.FullName; IsDir = $ti.PSIsContainer }
            break
        }
        Write-Host ("路径不存在：{0}，请重新输入" -f $pathInput) -ForegroundColor Red
    }
}
if ($select -eq "3" -or $select -eq "4") {
    if ($null -eq $picked) { Write-Log "[选择执行] 未选择目标，已退出" 'Yellow'; exit 0 }
    $Roots = @($picked.Path)
    Write-Log ("[选择执行] 目标: " + $picked.Path + $(if ($picked.IsDir) { '（目录）' } else { '（文件）' })) 'Cyan'
}

foreach ($root in $Roots) {
    Write-Log "`n-------- 盘: $root --------" 'Cyan'
    $plan = New-Object System.Collections.Generic.List[object]
    if (-not (Invoke-ScanRoot $root $plan)) { Write-Log "[扫描] 不存在或不可访问，已跳过: $root" 'Yellow'; continue }
    Write-Log "[扫描] 共 $script:totalItems 项；跳过辅助项 $script:skipItems；读取失败 $script:unreadItems（示例见日志）" 'Gray'
    Write-Log "[体检] $root 发现异常项 $($plan.Count) 个（残留SID 或 所有者异常）" 'Yellow'
    if ($script:unreadSample.Count -gt 0) { Write-Log "       读取失败示例: $($script:unreadSample -join ' | ')" 'DarkGray'; $script:unreadSample.Clear() }
    if ($plan.Count -eq 0) { Write-Log "[体检] 无异常，跳过本盘" 'Green'; continue }

    if ($DryRun -or $select -eq "1") {
        foreach ($r in $plan | Select-Object -First 30) {
            $detail = if ($r.Sids.Count -gt 0) { '  ← 残留SID: ' + ($r.Sids -join ', ') } else { '  （仅所有者异常）' }
            Write-Log ('  - ' + $r.Path + $detail) 'DarkGray'
        }
        if ($plan.Count -gt 30) { Write-Log "       ... 其余 $($plan.Count - 30) 项（-Log 可写入日志文件）" 'DarkGray' }
        foreach ($r in $plan) {
            $detail = if ($r.Sids.Count -gt 0) { '  ← ' + ($r.Sids -join ', ') } else { '  （仅所有者异常）' }
            if ($script:logEnabled) { try { Add-Content -LiteralPath $logFile -Value ('  [计划] ' + $r.Path + $detail) -Encoding UTF8 } catch {} }
        }
        $planTotal += $plan.Count
        continue
    }

    # ---- 修复模式的确认 ----
    if ($planTotal -eq 0 -and $failTotal -eq 0) {
        if ($select -eq "3" -or $select -eq "4") {
            # 选择执行：先展示该目标的体检明细，用户再决定是否修复
            Write-Log "[体检] $root 异常项明细：" 'Yellow'
            foreach ($d in $plan | Select-Object -First 30) {
                $detail = if ($d.Sids.Count -gt 0) { '  ← 残留SID: ' + ($d.Sids -join ', ') } else { '  （仅所有者异常）' }
                Write-Log ('  - ' + $d.Path + $detail) 'DarkGray'
            }
            if ($plan.Count -gt 30) { Write-Log "       ... 其余 $($plan.Count - 30) 项（-Log 可写入日志文件）" 'DarkGray' }
            if ($script:logEnabled) { Write-Log "[提示] 明细已写入日志：$logFile" 'DarkGray' } else { Write-Log "[提示] 日志未开启（需要时加 -Log），明细已显示在屏幕" 'DarkGray' }
            if (-not $isAdmin) { Write-Log "[提示] 当前非管理员，无法执行修复，已停止" 'Yellow'; exit 0 }
        }
        $ans = Read-Host "`n将执行：获取所有权 + 清理残留SID + 补授访问权（共 $($plan.Count) 项）。输入 Y 确认开始"
        if ($ans -notmatch '^[Yy]') { Write-Log '[取消] 未确认，未做任何修改，已退出' 'Yellow'; exit 0 }
    }

    # 1) 获取所有权（整盘）
    Write-Log "[所有权] 正在获取整个 $root 的所有权（takeown /r /d y），每处理一批文件显示进度..." 'Yellow'
    $script:takeCount = 0
    $takeStart = Get-Date
    & takeown.exe /f $root /r /d y 2>&1 | ForEach-Object {
        $script:takeCount++   # takeown 每项输出 1-2 行，行数约等于已处理项数
        if ($script:takeCount % 500 -eq 0) {
            $refTotal = [Math]::Max(1, ($script:totalItems - $script:skipItems))
            $pct = [Math]::Min(99, [int](100 * $script:takeCount / $refTotal))
            $secs = ((Get-Date) - $takeStart).TotalSeconds
            Write-Progress -Id 2 -Activity ("获取所有权 " + $root) -Status ("已处理 " + $script:takeCount + " 项 · 用时 " + ("{0:N1}" -f $secs) + " 秒") -CurrentOperation ("约完成 " + $pct + "%") -PercentComplete $pct
            if ($script:takeCount % 2000 -eq 0) {
                Write-Log ("[进度] 获取所有权 · 已处理 {0} 项 · 用时 {1:N1} 秒" -f $script:takeCount, $secs) 'DarkGray'
            }
        }
    }
    Write-Progress -Id 2 -Activity ("获取所有权 " + $root) -Completed
    $script:takeExitCode = $LASTEXITCODE
    Write-Log "[所有权] 完成（takeown 退出码 $script:takeExitCode，个别失败项见下方验证）" 'Green'

    # 2) 备份 + 修复（ACL 备份与 -Log 同开关：默认不生成，-Log 时生成）
    if ($script:logEnabled) {
        # 文件名消毒：盘符路径里的 \ : 不能出现在文件名中（冒号会变成 NTFS 数据流而非普通文件）
        $rootTag = ($root.TrimEnd('\') -replace '[\\:]', '_')
        $backupFile = Join-Path $LogDir ("获取所有权_备份_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + $rootTag + '.acl')
        $backupMap[$root] = $backupFile
        Write-Log "[备份] 本盘改动前 ACL 备份: $backupFile" 'Cyan'
    } else {
        $backupFile = $null
    }
    $failList = New-Object System.Collections.Generic.List[string]
    $i = 0
    foreach ($r in $plan) {
        $i++
        $null = Backup-And-Fix $r $backupFile $failList
        if ($i % 500 -eq 0) {
            Write-Log "[修复] 进度 $i / $($plan.Count)" 'DarkGray'
            Write-Progress -Id 3 -Activity ("修复权限 " + $root) -Status ("已处理 $i / $($plan.Count) 项") -CurrentOperation ((100 * $i / $plan.Count).ToString('N0') + '%') -PercentComplete (100 * $i / $plan.Count)
        }
    }
    Write-Progress -Id 3 -Activity ("修复权限 " + $root) -Completed
    $planTotal += $plan.Count; $failTotal += $failList.Count
    Write-Log "[修复] $root 共处理 $($plan.Count) 项，失败 $($failList.Count) 项" $(if ($failList.Count -gt 0) { 'Red' } else { 'Green' })
    foreach ($f in $failList | Select-Object -First 20) { Write-Log ("       - 失败: " + $f) 'Red' }
}

# ---------- 验证（仅修复模式） ----------
# 结果驱动：修复0失败 + takeown 正常 → 跳过全盘复扫（逐项复核已确认）；有失败项/锁定项 → 自动重扫兜底；-Rescan 可强制复扫
$script:verifySkipped = $false
if (-not ($DryRun -or $select -eq "1") -and $planTotal -gt 0 -and ($script:takeExitCode -ne 0 -or $failTotal -gt 0 -or $Rescan)) {
    $script:remainTotal = 0
    $script:verifyCount = 0
    $remainSample = New-Object System.Collections.Generic.List[string]
    Write-Log "`n-------- [验证] 重扫全盘，确认残留已清零 ---------" 'Cyan'
    foreach ($root in $Roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $rootItem = Get-Item -LiteralPath $root -Force -ErrorAction SilentlyContinue
        if ($null -ne $rootItem) {
            try { $acl = Get-Acl -LiteralPath $rootItem.FullName -ErrorAction Stop
                if (@(Get-ResidualSids $acl -IncludeInherited).Count -gt 0) { $script:remainTotal++ }
            } catch {}
        }
        Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
            if (Test-SkipItem $_) { return }
            $script:verifyCount++
            Update-Progress -Activity ("验证残留 " + $root) -Item $_ -Count $script:verifyCount
            try { $acl = Get-Acl -LiteralPath $_.FullName -ErrorAction Stop } catch { return }
            $residual = @(Get-ResidualSids $acl -IncludeInherited)
            $ownerSid = Get-SidString $acl.Owner
            $ownerBad = (-not $ownerSid) -or ($ownerSid -notin $okOwnerSids)
            if ($residual.Count -gt 0 -or $ownerBad) {
                $script:remainTotal++
                if ($script:remainTotal -le 50) { $remainSample.Add($_.FullName) }
            }
        }
    }
    if ($script:remainTotal -eq 0) {
        Write-Log "[验证] 残留项 0 个，全部清理完成！" 'Green'
    } else {
        Write-Log "[验证] 仍残留 $script:remainTotal 项（多为占用中/只读锁定文件，可稍后重跑），示例:" 'Red'
        foreach ($p in $remainSample) { Write-Log ('       - ' + $p) 'Red' }
    }
} else {
    if (-not ($DryRun -or $select -eq "1") -and $planTotal -gt 0) { $script:verifySkipped = $true }
}

# ---------- 汇总 ----------
Write-Log "`n===== 总结 =====" 'Green'
if ($DryRun -or $select -eq "1") {
    Write-Log "[干跑] 共发现异常项 $planTotal 个（计划见上方；-Log 可写入日志文件）。确认无误后选择第2项或去掉 -DryRun 正式运行。" 'Yellow'
} else {
    if ($script:verifySkipped) {
        Write-Log "统计: 扫描 $script:totalItems 项；计划修复 $planTotal 项；失败 $failTotal 项；残留：未全盘复扫（修复0失败，逐项复核已通过；-Rescan 可强制复扫）" 'Gray'
    } else {
        Write-Log "统计: 扫描 $script:totalItems 项；计划修复 $planTotal 项；失败 $failTotal 项；残留 $script:remainTotal 项" 'Gray'
    }
    if ($backupMap.Count -gt 0) {
        Write-Log "[回滚] 如需回滚 ACL，请对每块盘在「该盘根目录」执行（管理员）：" 'Cyan'
        foreach ($k in $backupMap.Keys) {
            Write-Log ("        cd " + $k + " ; icacls " + $k + " /restore `"" + $backupMap[$k] + "`" /T /C") 'Cyan'
        }
    } else {
        Write-Log "[提示] 未生成 ACL 备份（需要时加 -Log 参数，并会自动生成回滚命令）" 'Yellow'
    }
}
if ($script:logEnabled) { Write-Log "[日志] $logFile ；ACL 备份见上方 [备份] 行" 'Gray' } else { Write-Log "[日志] 已关闭：本次未生成 .log 与 .acl（需要时加 -Log 参数）" 'DarkGray' }
# 任务完成后停留显示结果（菜单与文件名预选模式一致），按任意键退出窗口
Write-Progress -Id 1 -Activity '权限体检' -Completed
pause
exit 0