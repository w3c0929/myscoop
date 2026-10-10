<#
.SYNOPSIS
    把"只给当前用户安装"的字体提升为系统级安装（所有用户可见）。

.DESCRIPTION
    oh-my-posh font install / 双击 TTF 安装 等方式会把字体装到
    %LOCALAPPDATA%\Microsoft\Windows\Fonts 并登记在 HKCU。
    部分 Windows 构建不会把这份用户级字体合并进系统枚举，
    导致 Windows Terminal 等程序报"找不到字体"。

    本脚本把选中的字体复制到 C:\Windows\Fonts、登记到 HKLM、
    公开加载并广播 WM_FONTCHANGE，等同于右键 TTF -> "为所有用户安装"。

    不带任何参数直接运行（双击 / 右键"使用 PowerShell 运行"）会进入交互菜单，
    列出所有可提升的字体家族让你挑；无论成功、失败还是取消，窗口都会停住等你按回车。
    脚本不依赖自身所在目录，放在任何路径、任何盘符都能跑。

.PARAMETER Pattern
    按注册表显示名做通配符匹配，例：Meslo、'JetBrainsMono*'

.PARAMETER Family
    按真实字体家族名精确匹配（可多个），例：-Family 'MesloLGLDZ Nerd Font Mono'

.PARAMETER All
    提升当前用户安装的全部字体

.PARAMETER List
    只读预览，不做任何修改（不需要管理员权限）

.PARAMETER NoPause
    结尾不停顿，供其它脚本 / CI 调用

.EXAMPLE
    .\Install-FontSystemWide.ps1

    交互菜单，最省心的用法。

.EXAMPLE
    .\Install-FontSystemWide.ps1 -Pattern Meslo -List

    只读预览：有哪些、多大、系统当前能不能看见。

.EXAMPLE
    .\Install-FontSystemWide.ps1 -Pattern 'MesloLGLDZ Nerd Font Mono*'

    只提升 Mono 变体的几个字重。

.EXAMPLE
    .\Install-FontSystemWide.ps1 -All -NoPause
#>
[CmdletBinding()]
param(
    [string]$Pattern,
    [string[]]$Family,
    [switch]$All,
    [switch]$List,
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'

# 只有在真正的交互式控制台里才停顿；被重定向 / 被其它脚本调用时自动跳过
$script:IsInteractive = (-not $NoPause) -and
                        ($Host.Name -eq 'ConsoleHost') -and
                        [Environment]::UserInteractive -and
                        (-not [Console]::IsInputRedirected)

function Invoke-Pause {
    if (-not $script:IsInteractive) { return }
    Write-Host ''
    try { [void](Read-Host '按回车键退出') } catch { }
}

# 从字体文件里读出真实家族名（Windows Terminal 认的就是这个名字）
function Get-FontFamily {
    param([string]$Path)
    try {
        $gtf = New-Object System.Windows.Media.GlyphTypeface([Uri]$Path)
        $n = @($gtf.FamilyNames.Values)[0]
        if ($n) { return $n }
    } catch { }
    return [IO.Path]::GetFileNameWithoutExtension($Path)
}

function Main {
    # 让中文输出在重定向到文件时也是 UTF-8，不会变成乱码
    try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

    Write-Host ''
    Write-Host '=== 用户级字体 -> 系统级字体 提升工具 ===' -ForegroundColor Cyan
    Write-Host "脚本位置: $PSCommandPath" -ForegroundColor DarkGray
    Write-Host "管理员权限: $(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))" -ForegroundColor DarkGray

    $userFontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $sysFontDir  = Join-Path $env:WinDir 'Fonts'
    $hkcuPath    = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    $hklmPath    = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

    Add-Type -AssemblyName System.Drawing, PresentationCore, WindowsBase

    if (-not (Test-Path -Path $hkcuPath)) {
        Write-Host ''
        Write-Host '这台机器没有用户级字体登记表，没什么可提升的。' -ForegroundColor Green
        return
    }

    # ---- 读出用户级字体登记表，解析出真实文件路径 ----
    Write-Host ''
    Write-Host '正在扫描用户级字体...' -ForegroundColor DarkGray
    $entries = @(foreach ($p in (Get-ItemProperty -Path $hkcuPath).PSObject.Properties) {
        if ($p.Name -like 'PS*') { continue }
        $raw = [string]$p.Value
        if (-not $raw) { continue }
        $src = if ([IO.Path]::IsPathRooted($raw)) { $raw } else { Join-Path $userFontDir $raw }
        if (-not (Test-Path -LiteralPath $src)) { continue }
        [pscustomobject]@{
            DisplayName = $p.Name
            Source      = $src
            Leaf        = [IO.Path]::GetFileName($src)
            Size        = (Get-Item -LiteralPath $src).Length
            Family      = (Get-FontFamily $src)
        }
    })

    if ($entries.Count -eq 0) {
        Write-Host ''
        Write-Host '当前用户没有安装任何字体文件，没有可提升的内容。' -ForegroundColor Yellow
        Write-Host '提示：先运行  oh-my-posh font install <名字>  装一遍，再跑本脚本。'
        return
    }

    $hklmNames   = @(Get-Item -Path $hklmPath -ErrorAction SilentlyContinue).Property
    $familiesNow = @((New-Object System.Drawing.Text.InstalledFontCollection).Families.Name)
    foreach ($e in $entries) {
        $e | Add-Member -NotePropertyName InSystem -NotePropertyValue ($hklmNames -contains $e.DisplayName) -Force
    }

    Write-Host "找到 $($entries.Count) 个用户级字体文件，共 $(@($entries | Group-Object Family).Count) 个家族。" -ForegroundColor DarkGray
    Write-Host "系统当前可枚举字体族数: $($familiesNow.Count)" -ForegroundColor DarkGray

    # ---- 选出要处理的条目 ----
    if ($All) {
        $selected = @($entries)
        $selLabel = '-All（全部）'
    }
    elseif ($Family -and $Family.Count -gt 0) {
        $selected = @($entries | Where-Object { $Family -contains $_.Family })
        $selLabel = "-Family $($Family -join ', ')"
    }
    elseif ($Pattern) {
        $selected = @($entries | Where-Object { $_.DisplayName -like "*$Pattern*" })
        $selLabel = "-Pattern '$Pattern'"
    }
    else {
        # ================= 交互菜单 =================
        Write-Host ''
        Write-Host '=== 可提升的字体家族 ===' -ForegroundColor Cyan
        $groups = @($entries | Group-Object Family | Sort-Object Name)
        $rows = @()
        for ($i = 0; $i -lt $groups.Count; $i++) {
            $g    = $groups[$i]
            $pend = @($g.Group | Where-Object { -not $_.InSystem })
            $mb   = [math]::Round((($g.Group | Measure-Object Size -Sum).Sum) / 1MB, 1)
            $vis  = $familiesNow -contains $g.Name
            $rows += [pscustomobject]@{
                Index   = $i + 1
                Family  = $g.Name
                Total   = $g.Count
                Pending = $pend.Count
                MB      = $mb
                Visible = $vis
            }

            $idx = '{0,3}' -f ($i + 1)
            $line = "  [$idx] {0,-46} {1,3} 个文件 {2,7} MB" -f $g.Name, $g.Count, $mb
            if ($pend.Count -eq 0) {
                Write-Host "$line   已是系统级" -ForegroundColor DarkGray
            }
            elseif ($vis) {
                Write-Host "$line   系统可见，可补登记" -ForegroundColor Green
            }
            else {
                Write-Host "$line   系统看不见 <== 待提升 $($pend.Count)" -ForegroundColor Red
            }
        }

        $pendingTotal = @($entries | Where-Object { -not $_.InSystem }).Count
        Write-Host ''
        Write-Host "待提升合计: $pendingTotal 个文件" -ForegroundColor Yellow
        Write-Host ''
        Write-Host '  编号    提升选中家族（多个用逗号分隔，例 1,3）'
        Write-Host '  A       提升全部待提升的字体'
        Write-Host '  L       只看明细，不做任何修改'
        Write-Host '  Q       退出'

        $chosen = $null
        while (-not $chosen) {
            Write-Host ''
            $ans = ([string](Read-Host '请输入选择')).Trim()
            if ($ans -eq '') { continue }

            if ($ans -match '^[Qq]$') {
                Write-Host '已取消，没有做任何修改。' -ForegroundColor Yellow
                return
            }
            elseif ($ans -match '^[Aa]$') {
                $chosen   = @($entries)
                $selLabel = '菜单: 全部'
            }
            elseif ($ans -match '^[Ll]$') {
                $chosen   = @($entries)
                $selLabel = '菜单: 明细'
                $List     = $true
            }
            elseif ($ans -match '^[\d,\s]+$') {
                $nums = @($ans -split '[,\s]+' | Where-Object { $_ } | ForEach-Object { [int]$_ })
                $bad  = @($nums | Where-Object { $_ -lt 1 -or $_ -gt $rows.Count })
                if ($bad.Count -gt 0) {
                    Write-Host "编号超出范围（1-$($rows.Count)）: $($bad -join ', ')" -ForegroundColor Red
                    continue
                }
                $names    = @($rows | Where-Object { $nums -contains $_.Index } | ForEach-Object { $_.Family })
                $chosen   = @($entries | Where-Object { $names -contains $_.Family })
                $selLabel = "菜单: $($names -join ', ')"
            }
            else {
                Write-Host "看不懂 '$ans'。请输入编号、A、L 或 Q。" -ForegroundColor Red
            }
        }
        $selected = $chosen
    }

    if (-not $selected -or $selected.Count -eq 0) {
        Write-Host ''
        Write-Host "没有匹配 $selLabel 的条目（共 $($entries.Count) 条）。" -ForegroundColor Red
        return
    }

    # ---- 已经在系统级的跳过 ----
    $pending = @()
    foreach ($e in $selected) {
        if ($e.InSystem) {
            Write-Host "跳过（已在 HKLM）: $($e.DisplayName)" -ForegroundColor DarkGray
        } else {
            $pending += $e
        }
    }

    $totalMB = [math]::Round((($pending | ForEach-Object { $_.Size } | Measure-Object -Sum).Sum) / 1MB, 1)

    Write-Host ''
    Write-Host "选择方式     : $selLabel"
    Write-Host "用户级字体总数 : $($entries.Count)"
    Write-Host "本次选中     : $($selected.Count)"
    Write-Host "待提升       : $($pending.Count)   约 $totalMB MB"

    if ($List) {
        Write-Host ''
        Write-Host '=== 明细（-List 只读，未做任何修改）===' -ForegroundColor Cyan
        foreach ($e in $pending) {
            $size = [math]::Round($e.Size / 1MB, 2)
            $visible = if ($familiesNow -contains $e.Family) { '可见' } else { '不可见 <==' }
            $color = if ($visible -eq '可见') { 'Green' } else { 'Red' }
            Write-Host ("  {0,-52} {1,6} MB  {2}" -f $e.Leaf, $size, $e.Family)
            Write-Host ("  {0,-52} {1,6}      系统: {2}" -f '', '', $visible) -ForegroundColor $color
        }
        if ($pending.Count -eq 0) { Write-Host '  （没有待提升项，全部已是系统级）' -ForegroundColor Green }
        Write-Host ''
        Write-Host '去掉 -List 即执行安装。' -ForegroundColor Yellow
        return
    }

    if ($pending.Count -eq 0) {
        Write-Host ''
        Write-Host '没有需要提升的字体，选中的这些已经是系统级了。' -ForegroundColor Green
        return
    }

    # ---- 到这里才是真正要写系统目录，需要管理员权限 ----
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
               ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host ''
        Write-Host '写入 C:\Windows\Fonts 和 HKLM 需要管理员权限。' -ForegroundColor Yellow
        if ($script:IsInteractive) {
            $go = [string](Read-Host '现在弹出 UAC 提权并重跑本脚本？[Y/n]').Trim()
            if ($go -match '^[Nn]') {
                Write-Host '已取消，没有做任何修改。' -ForegroundColor Yellow
                return
            }
        }

        $selfExe = 'powershell.exe'
        try { $pp = (Get-Process -Id $PID).Path; if ($pp) { $selfExe = $pp } } catch { }

        $names = @($pending | ForEach-Object { $_.Family } | Sort-Object -Unique)
        $psi = @('-NoProfile', '-NoExit', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-NoPause')
        foreach ($n in $names) { $psi += @('-Family', "`"$n`"") }

        Write-Host "提权重跑: $selfExe -Family $($names -join ', ')" -ForegroundColor DarkGray
        try {
            Start-Process -FilePath $selfExe -Verb RunAs -ArgumentList $psi
            Write-Host ''
            Write-Host '已在新窗口继续。本窗口可以关掉了。' -ForegroundColor Green
        } catch {
            Write-Host ''
            Write-Host "提权失败（大概是 UAC 被取消）：$($_.Exception.Message)" -ForegroundColor Red
            Write-Host '可以手动以管理员身份打开终端，再执行：' -ForegroundColor Yellow
            Write-Host "  & `"$PSCommandPath`" -Pattern <通配符>" -ForegroundColor Yellow
        }
        return
    }

    $familiesBefore = $familiesNow
    Write-Host ''
    Write-Host "提升前系统可枚举字体族数: $($familiesBefore.Count)" -ForegroundColor Cyan

    # ---- 1. 复制到 C:\Windows\Fonts ----
    Write-Host ''
    Write-Host '[1/5] 复制字体文件...' -ForegroundColor Cyan
    $copied = @()
    foreach ($e in $pending) {
        $dst = Join-Path $sysFontDir $e.Leaf
        Copy-Item -LiteralPath $e.Source -Destination $dst -Force
        $copied += [pscustomobject]@{
            DisplayName = $e.DisplayName
            Leaf        = $e.Leaf
            Dest        = $dst
            Family      = $e.Family
        }
        Write-Host "  复制 $($e.Leaf)  ($((Get-Item -LiteralPath $dst).Length) bytes)"
    }

    # ---- 2. 登记到 HKLM（值用裸文件名，与 Windows 自带字体的写法一致）----
    Write-Host ''
    Write-Host '[2/5] 写入 HKLM 注册表...' -ForegroundColor Cyan
    foreach ($c in $copied) {
        New-ItemProperty -Path $hklmPath -Name $c.DisplayName -Value $c.Leaf -PropertyType String -Force | Out-Null
        Write-Host "  '$($c.DisplayName)' -> $($c.Leaf)"
    }

    # ---- 3. 公开加载 + 广播 WM_FONTCHANGE，免重启即时生效 ----
    Write-Host ''
    Write-Host '[3/5] 公开加载并广播 WM_FONTCHANGE...' -ForegroundColor Cyan
    if (-not ('FontApi' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class FontApi {
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int AddFontResourceEx(string lpszFilename, uint fl, IntPtr pdv);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam,
        IntPtr lParam, uint fuFlags, uint uTimeout, out IntPtr lpdwResult);
}
'@
    }

    foreach ($c in $copied) {
        # fl = 0 表示公开注册（不是 FR_PRIVATE 的进程私有）
        $rc = [FontApi]::AddFontResourceEx($c.Dest, 0, [IntPtr]::Zero)
        Write-Host "  AddFontResourceEx($($c.Leaf)) -> $rc"
        if ($rc -eq 0) { Write-Warning "    加载失败，Win32 错误码 $([Runtime.InteropServices.Marshal]::GetLastWin32Error())" }
    }

    $result = [IntPtr]::Zero
    [void][FontApi]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero, 0x0002, 1000, [ref]$result)
    Write-Host '  WM_FONTCHANGE 已广播'

    # ---- 4. 验证 ----
    Write-Host ''
    Write-Host '[4/5] 验证...' -ForegroundColor Cyan
    $familiesAfter = @((New-Object System.Drawing.Text.InstalledFontCollection).Families.Name)
    Write-Host "提升后系统可枚举字体族数: $($familiesAfter.Count)  (新增 $($familiesAfter.Count - $familiesBefore.Count))"

    $targets = @($copied | ForEach-Object { $_.Family } | Sort-Object -Unique)

    Write-Host ''
    Write-Host '=== 按家族名解析测试（Windows Terminal 走的就是这条路）===' -ForegroundColor Cyan
    $allOk = $true
    foreach ($fam in $targets) {
        $tf = New-Object System.Windows.Media.Typeface($fam)
        $gt = $null
        $ok = $tf.TryGetGlyphTypeface([ref]$gt)
        if (-not $ok) { $allOk = $false }
        $color = if ($ok) { 'Green' } else { 'Red' }
        Write-Host "  '$fam' -> $ok" -ForegroundColor $color
        if ($ok) {
            Write-Host "      file    = $($gt.FontUri)"
            Write-Host "      face    = $($gt.Style)"
            # U+E0B0 = Powerline 箭头, U+F09B = GitHub logo，用来确认是真正的 Nerd Font
            $nerd = $gt.CharacterToGlyphMap.ContainsKey(0xE0B0) -or $gt.CharacterToGlyphMap.ContainsKey(0xF09B)
            Write-Host "      Nerd Font 图标 = $nerd"
        }
    }

    # ---- 5. HKLM 回读（走 64 位视图，防 WOW64 重定向）----
    Write-Host ''
    Write-Host '[5/5] HKLM 回读（64 位视图）...' -ForegroundColor Cyan
    $reg64 = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
        [Microsoft.Win32.RegistryHive]::LocalMachine,
        [Microsoft.Win32.RegistryView]::Registry64)
    $k = $reg64.OpenSubKey('SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts')
    $regOk = $true
    foreach ($c in $copied) {
        $v = $k.GetValue($c.DisplayName)
        if (-not $v) { $regOk = $false }
        $flag = if ($v) { 'OK' } else { '缺失 <==' }
        Write-Host "  [$flag] '$($c.DisplayName)' = $v"
    }
    $k.Close(); $reg64.Close()

    Write-Host ''
    if ($allOk -and $regOk) {
        Write-Host "完成。共提升 $($copied.Count) 个字体文件。" -ForegroundColor Green
        Write-Host '把 Windows Terminal 完全退出再打开即可生效（不用重启电脑）。' -ForegroundColor Green
    } else {
        Write-Host '有字体仍然解析失败或注册表缺失，请把上面的输出发出来排查。' -ForegroundColor Red
    }
}

try {
    Main
}
catch {
    Write-Host ''
    Write-Host "出错了：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host "位置：$($_.InvocationInfo.PositionMessage)" -ForegroundColor DarkGray
    exit 1
}
finally {
    Invoke-Pause
}
