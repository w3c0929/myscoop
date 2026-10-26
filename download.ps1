# Description: Functions for downloading files
# myscoop 补丁基线：Scoop v0.6.0（e6aa3b36）。低版本 Scoop 用 patches/ 下对应版本文件，symlink.bat 自动按版本分发。

# ========== GitHub 镜像加速补丁开始 ==========
# GitHub Release 下载优先走镜像（aria2 与默认下载器共用），**按速度选源**：
# 依次对 config.json "aria2-mirrors" 列表（可写完整 URL 或裸域名，自动补 https://）逐个**测速**——
# 在 WINDOW 秒（默认 6，`MYSCOOP_MIRROR_WINDOW`）内实测平均速度 ≥ MIN（默认 1MB/s，
# `MYSCOOP_MIRROR_MIN_SPEED_MB`）才采用；不达标/不可达 → 立即换下一个；
# **全部不达标兜底直链**（原 URL）。测速用系统自带 curl.exe：`-r 0-8388607`（最多 8MB，
# ≥ 阈值×窗口，防高速镜像下满整个文件）+ `--max-time WINDOW`，`%{speed_download}` 读实测速率。
function Measure-UrlSample {
    param(
        [string]$Url,
        [int]$Ms = 1200,
        [int]$MaxBytes = 8388608,
        [int]$TimeoutMs = 4000
    )
    $req = [Net.WebRequest]::Create($Url)
    $req.Method = 'GET'
    $req.Timeout = $TimeoutMs
    if ($PSVersionTable.PSVersion.Major -le 5) {
        try { $req.ReadWriteTimeout = $Ms } catch {}
    } else {
        try { $req.ReadWriteTimeout = $TimeoutMs } catch {}
    }
    $req.UserAgent = Get-UserAgent
    try { $req.AddRange(0, $MaxBytes - 1) } catch {}

    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $resp = $req.GetResponse()
        $ttfb = $sw.Elapsed.TotalMilliseconds
        $proto = $resp.ProtocolVersion.ToString()
        $status = [int]$resp.StatusCode
        $stream = $resp.GetResponseStream()
        $buf = New-Object byte[] 65536
        $total = 0
        $timedOut = $false
        $sw2 = [Diagnostics.Stopwatch]::StartNew()
        if ($PSVersionTable.PSVersion.Major -le 5) {
            try {
                while ($sw2.Elapsed.TotalMilliseconds -lt $Ms -and $total -lt $MaxBytes) {
                    $n = $stream.Read($buf, 0, $buf.Length)
                    if ($n -le 0) { break }
                    $total += $n
                }
            } catch { $timedOut = $true }
        } else {
            $cts = New-Object System.Threading.CancellationTokenSource($Ms)
            try {
                while ($total -lt $MaxBytes) {
                    $task = $stream.ReadAsync($buf, 0, $buf.Length, $cts.Token)
                    try { $n = $task.GetAwaiter().GetResult() } catch { $timedOut = $true; break }
                    if ($n -le 0) { break }
                    $total += $n
                }
            } finally { if ($cts) { $cts.Dispose() } }
        }
        $sw2.Stop()
        try { $resp.Close() } catch {}
        $secs = [Math]::Max($sw2.Elapsed.TotalSeconds, 0.001)
        return [pscustomobject]@{
            Ok = ($status -in 200, 206 -and $total -gt 0)
            Status = $status; Proto = $proto
            TtfbMs = [math]::Round($ttfb, 0); Bytes = $total
            Seconds = [math]::Round($secs, 2)
            MBps = [math]::Round(($total / 1MB) / $secs, 2)
            TimedOut = $timedOut; Error = ''
        }
    } catch {
        $sw.Stop()
        return [pscustomobject]@{
            Ok = $false; Status = 0; Proto = '-'
            TtfbMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 0)
            Bytes = 0; Seconds = 0; MBps = 0; TimedOut = $false
            Error = $_.Exception.Message
        }
    }
}

function Measure-MirrorMedian {
    param([string]$Url, [int]$Samples = 3, [int]$Ms = 1200, [int]$MaxBytes = 8388608)
    $vals = @()
    $last = $null
    for ($i = 0; $i -lt $Samples; $i++) {
        $s = Measure-UrlSample -Url $Url -Ms $Ms -MaxBytes $MaxBytes
        $last = $s
        if ($i -eq 0 -and -not $s.Ok) {
            return [pscustomobject]@{ Ok = $false; MBps = 0; Good = 0; Status = $s.Status; Proto = $s.Proto; Error = $s.Error; Detail = @() }
        }
        if ($s.Ok) { $vals += [double]$s.MBps }
    }
    if ($vals.Count -eq 0) {
        return [pscustomobject]@{ Ok = $false; MBps = 0; Good = 0; Status = $last.Status; Proto = $last.Proto; Error = $last.Error; Detail = @() }
    }
    $sorted = @($vals | Sort-Object)
    if ($sorted.Count % 2 -eq 1) {
        $median = $sorted[[int]($sorted.Count / 2)]
    } else {
        $median = ($sorted[[int]($sorted.Count / 2 - 1)] + $sorted[[int]($sorted.Count / 2)]) / 2
    }
    return [pscustomobject]@{ Ok = $true; MBps = [math]::Round($median, 2); Good = $sorted.Count; Status = $last.Status; Proto = $last.Proto; Error = ''; Detail = $sorted }
}

function Read-MirrorRank {
    param([string]$Path)
    $h = @{}
    if (Test-Path $Path) {
        try {
            $o = Get-Content $Path -Raw | ConvertFrom-Json
            if ($o.mirrors) {
                foreach ($p in $o.mirrors.PSObject.Properties) {
                    $h[$p.Name] = @{ ewma = [double]$p.Value.ewma; fails = [int]$p.Value.fails; cooldown_until = [long]$p.Value.cooldown_until; last = [long]$p.Value.last }
                }
            }
        } catch {}
    }
    return $h
}

function Write-MirrorRank {
    param([string]$Path, [hashtable]$Rank)
    $mirrors = @{}
    foreach ($k in $Rank.Keys) { $mirrors[$k] = $Rank[$k] }
    $obj = [ordered]@{ version = 2; mirrors = $mirrors }
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    ($obj | ConvertTo-Json -Depth 6) | Set-Content -Path $Path -Encoding UTF8
}

if (-not $script:MirrorPlanMemo) { $script:MirrorPlanMemo = @{} }

function Get-GitHubMirrorPlan([string]$url) {
    if ($url -notmatch '^https://github\.com/') {
        return [pscustomobject]@{ Urls = @($url); MinMBps = 0.0; BestMBps = 0.0 }
    }
    $mirrors = get_config 'aria2-mirrors'
    if (-not $mirrors) {
        return [pscustomobject]@{ Urls = @($url); MinMBps = 0.0; BestMBps = 0.0 }
    }
    if ($mirrors -is [string]) { $mirrors = $mirrors.Split(' ') }

    $bases = @()
    foreach ($m in $mirrors) {
        $b = "$m".TrimEnd('/')
        if ($b -notmatch '^https?://') { $b = "https://$b" }
        if ($bases -notcontains $b) { $bases += $b }
    }
    if ($bases.Count -eq 0) {
        return [pscustomobject]@{ Urls = @($url); MinMBps = 0.0; BestMBps = 0.0 }
    }

    $cacheFile = if ($env:MYSCOOP_RANK_FILE) { $env:MYSCOOP_RANK_FILE } else { Join-Path $env:LOCALAPPDATA 'myscoop\mirror-rank.json' }
    $now = [DateTimeOffset]::Now.ToUnixTimeSeconds()
    $memoKey = ($bases -join '|')
    if ($script:MirrorPlanMemo.ContainsKey($memoKey)) {
        $mm = $script:MirrorPlanMemo[$memoKey]
        if (($now - [long]$mm.ts) -lt 300) {
            $urls = @(); foreach ($b in $mm.order) { $urls += "$b/$url" }
            return [pscustomobject]@{ Urls = $urls; MinMBps = [double]$mm.min; BestMBps = [double]$mm.best }
        }
    }

    $rank = Read-MirrorRank -Path $cacheFile
    if ($rank.Count -eq 0) {
        $old = Join-Path $env:LOCALAPPDATA 'myscoop\mirror-cache.json'
        if (Test-Path $old) {
            try {
                $oc = Get-Content $old -Raw | ConvertFrom-Json
                if ($oc.mirror -and $oc.speed) {
                    $rank[("$($oc.mirror)".TrimEnd('/'))] = @{ ewma = [double]$oc.speed; fails = 0; cooldown_until = 0; last = [long]$oc.ts }
                }
            } catch {}
        }
    }

    $fresh = @($rank.Keys | Where-Object {
        $rank[$_].cooldown_until -le $now -and $rank[$_].ewma -gt 0 -and
        ($now - [long]$rank[$_].last) -le 600 -and ($bases -contains $_)
    } | Sort-Object { $rank[$_].ewma } -Descending)
    if ($fresh.Count -gt 0) {
        $bestBase = $fresh[0]
        $bestSpeed = [double]$rank[$bestBase].ewma
        $min = [math]::Round([Math]::Max(1.0, [Math]::Min(4.0, 0.2 * $bestSpeed)), 2)
        $orderBases = @($bestBase)
        foreach ($b in $bases) { if ($orderBases -notcontains $b) { $orderBases += $b } }
        $urls = @(); foreach ($b in $orderBases) { $urls += "$b/$url" }
        Write-Host ("  [mirror] fast path {0} (ewma {1:N2} MB/s, threshold {2:N2})" -f ($bestBase -replace '^https?://', ''), $bestSpeed, $min) -ForegroundColor DarkCyan
        $script:MirrorPlanMemo[$memoKey] = [pscustomobject]@{ order = $orderBases; best = $bestSpeed; min = $min; ts = $now }
        return [pscustomobject]@{ Urls = $urls; MinMBps = $min; BestMBps = $bestSpeed }
    }

    $ordered = @()
    $cached = @($rank.Keys | Where-Object { $rank[$_].cooldown_until -le $now -and $rank[$_].ewma -gt 0 -and ($bases -contains $_) } | Sort-Object { $rank[$_].ewma } -Descending)
    foreach ($b in $cached) {
        if ($ordered.Count -ge 2) { break }
        $ordered += $b
    }
    foreach ($b in $bases) {
        if ($ordered.Count -ge 3) { break }
        if ($ordered -notcontains $b) { $ordered += $b }
    }

    $res = @()
    foreach ($b in $ordered) {
        $u = "$b/$url"
        $m = Measure-MirrorMedian -Url $u -Samples 3 -Ms 1200 -MaxBytes 8388608
        Write-Host ("  [mirror] {0,-32} {1,7:N2} MB/s  {2}" -f ($b -replace '^https?://', ''), $m.MBps, $m.Proto) -ForegroundColor DarkCyan
        $res += [pscustomobject]@{ Base = $b; Url = $u; Ok = $m.Ok; MBps = $m.MBps; Status = $m.Status; Proto = $m.Proto }
    }

    $good = @($res | Where-Object { $_.Ok } | Sort-Object MBps -Descending)
    $best = if ($good.Count -gt 0) { $good[0] } else { $null }

    foreach ($r in $res) {
        $e = if ($rank.ContainsKey($r.Base)) { $rank[$r.Base] } else { @{ ewma = 0.0; fails = 0; cooldown_until = 0; last = 0 } }
        if ($r.Ok) {
            if ($e.ewma -gt 0) { $e.ewma = [math]::Round(0.6 * $e.ewma + 0.4 * $r.MBps, 2) } else { $e.ewma = [double]$r.MBps }
            $e.fails = 0
        } else {
            $e.fails = [int]$e.fails + 1
            if ($e.fails -ge 3) { $e.cooldown_until = $now + 1800 }
        }
        $e.last = $now
        $rank[$r.Base] = $e
    }
    Write-MirrorRank -Path $cacheFile -Rank $rank

    $orderBases = @()
    foreach ($r in $good) { if ($orderBases -notcontains $r.Base) { $orderBases += $r.Base } }
    foreach ($r in ($res | Sort-Object { if ($_.Ok) { -$_.MBps } else { 9999 } })) { if ($orderBases -notcontains $r.Base) { $orderBases += $r.Base } }
    foreach ($b in $bases) { if ($orderBases -notcontains $b) { $orderBases += $b } }

    $urls = @(); foreach ($b in $orderBases) { $urls += "$b/$url" }
    $bestSpeed = if ($best) { [double]$best.MBps } else { 0.0 }
    $min = if ($bestSpeed -gt 0) { [math]::Round([Math]::Max(1.0, [Math]::Min(4.0, 0.2 * $bestSpeed)), 2) } else { 0.0 }
    if ($best) { Write-Host ("  [mirror] using {0} ({1:N2} MB/s, switch threshold {2:N2} MB/s)" -f ($best.Base -replace '^https?://', ''), $bestSpeed, $min) -ForegroundColor DarkCyan }
    else { Write-Host "  [mirror] no usable mirror, falling back to direct URL" }

    $script:MirrorPlanMemo[$memoKey] = [pscustomobject]@{ order = $orderBases; best = $bestSpeed; min = $min; ts = $now }
    return [pscustomobject]@{ Urls = $urls; MinMBps = $min; BestMBps = $bestSpeed }
}

function Get-GitHubMirrorUrl([string]$url) {
    return (Get-GitHubMirrorPlan $url).Urls[0]
}

# ========== GitHub 镜像加速补丁结束 ==========

## Meta downloader

function Invoke-ScoopDownload ($app, $version, $manifest, $bucket, $architecture, $dir, $use_cache = $true, $check_hash = $true) {
    # we only want to show this warning once
    if (!$use_cache) { warn 'Cache is being ignored.' }

    # can be multiple urls: if there are, then installer should go first to make 'installer.args' section work
    $urls = @(script:url $manifest $architecture)

    # can be multiple cookies: they will be used for all HTTP requests.
    $cookies = $manifest.cookie

    # download first
    if (Test-Aria2Enabled) {
        Invoke-CachedAria2Download $app $version $manifest $architecture $dir $cookies $use_cache $check_hash
    } else {
        foreach ($url in $urls) {
            $fname = url_filename $url

            try {
                Invoke-CachedDownload $app $version $url "$dir\$fname" $cookies $use_cache
            } catch {
                Write-Host -ForegroundColor DarkRed $_
                error "URL $url is not valid"
                abort $(new_issue_msg $app $bucket 'download failed')
            }

            if ($check_hash) {
                $manifest_hash = hash_for_url $manifest $url $architecture
                $ok, $err = check_hash "$dir\$fname" $manifest_hash $(show_app $app $bucket)
                if (!$ok) {
                    error $err
                    $cached = cache_path $app $version $url
                    if (Test-Path $cached) {
                        # rm cached file
                        Remove-Item -Force $cached
                    }
                    if ($url.Contains('sourceforge.net')) {
                        Write-Host -ForegroundColor Yellow 'SourceForge.net is known for causing hash validation fails. Please try again before opening a ticket.'
                    }
                    abort $(new_issue_msg $app $bucket 'hash check failed')
                }
            }
        }
    }

    return $urls.ForEach({ url_filename $_ })
}

## [System.Net] downloader

function Invoke-CachedDownload ($app, $version, $url, $to, $cookies = $null, $use_cache = $true, $plan = $null) {
    $cached = cache_path $app $version $url

    if (!(Test-Path $cached) -or !$use_cache) {
        ensure $cachedir | Out-Null
        if ($null -eq $plan) { $plan = Get-GitHubMirrorPlan $url }
        $downloaded = $false
        $lastErr = $null
        foreach ($alt in $plan.Urls) {
            try {
                Start-Download $alt "$cached.download" $cookies
                $downloaded = $true
                break
            } catch {
                $lastErr = $_
                Remove-Item "$cached.download" -Force -ErrorAction SilentlyContinue
                Write-Host ("  [mirror] failed {0}: {1}" -f (($alt -split '/')[2]), $_.Exception.Message)
            }
        }
        if (-not $downloaded) { throw "All mirror downloads failed: $lastErr" }
        Move-Item "$cached.download" $cached -Force
    } else { Write-Host "Loading $(url_remote_filename $url) from cache" }

    if (!($null -eq $to)) {
        if ($use_cache) {
            Copy-Item $cached $to
        } else {
            Move-Item $cached $to -Force
        }
    }
}

function Start-Download ($url, $to, $cookies) {
    $progress = [console]::isoutputredirected -eq $false -and
    $host.name -ne 'Windows PowerShell ISE Host'

    try {
        $url = handle_special_urls $url
        Invoke-Download $url $to $cookies $progress
    } catch {
        $e = $_.exception
        if ($e.Response.StatusCode -eq 'Unauthorized') {
            warn 'Token might be misconfigured.'
        }
        if ($e.innerexception) { $e = $e.innerexception }
        throw $e
    }
}

function Invoke-Download ($url, $to, $cookies, $progress) {
    # download with filesize and progress indicator
    $reqUrl = ($url -split '#')[0]
    $wreq = [Net.WebRequest]::Create($reqUrl)
    if ($wreq -is [Net.HttpWebRequest]) {
        $wreq.UserAgent = Get-UserAgent
        if (-not ($url -match 'sourceforge\.net' -or $url -match 'portableapps\.com')) {
            $wreq.Referer = strip_filename $url
        }
        if ($url -match '^https://api\.github\.com/repos') {
            $wreq.Accept = 'application/octet-stream'
            $wreq.Headers['Authorization'] = "Bearer $(Get-GitHubToken)"
            $wreq.Headers['X-GitHub-Api-Version'] = '2022-11-28'
        }
        if ($cookies) {
            $wreq.Headers.Add('Cookie', (cookie_header $cookies))
        }

        get_config PRIVATE_HOSTS | Where-Object { $_ -ne $null -and $url -match $_.match } | ForEach-Object {
            (ConvertFrom-StringData -StringData $_.Headers).GetEnumerator() | ForEach-Object {
                $wreq.Headers[$_.Key] = $_.Value
            }
        }
    }

    $stallMs = if ($env:MYSCOOP_STALL_TIMEOUT_MS) { [int]$env:MYSCOOP_STALL_TIMEOUT_MS } else { 10000 }
    if ($PSVersionTable.PSVersion.Major -le 5) { try { $wreq.ReadWriteTimeout = $stallMs } catch {} }

    try {
        $wres = $wreq.GetResponse()
    } catch [System.Net.WebException] {
        $exc = $_.Exception
        $handledCodes = @(
            [System.Net.HttpStatusCode]::MovedPermanently, # HTTP 301
            [System.Net.HttpStatusCode]::Found, # HTTP 302
            [System.Net.HttpStatusCode]::SeeOther, # HTTP 303
            [System.Net.HttpStatusCode]::TemporaryRedirect  # HTTP 307
        )

        # Only handle redirection codes
        $redirectRes = $exc.Response
        if ($handledCodes -notcontains $redirectRes.StatusCode) {
            throw $exc
        }

        # Get the new location of the file
        if ((-not $redirectRes.Headers) -or ($redirectRes.Headers -notcontains 'Location')) {
            throw $exc
        }

        $newUrl = $redirectRes.Headers['Location']
        info "Following redirect to $newUrl..."

        # Handle manual file rename
        if ($url -like '*#/*') {
            $null, $postfix = $url -split '#/'
            $newUrl = "$newUrl`#/$postfix"
        }

        Invoke-Download $newUrl $to $cookies $progress
        return
    }

    $total = $wres.ContentLength
    if ($total -eq -1 -and $wreq -is [net.ftpwebrequest]) {
        $total = ftp_file_size($url)
    }

    if ($progress -and ($total -gt 0)) {
        [console]::CursorVisible = $false
        function Trace-DownloadProgress ($read) {
            Write-DownloadProgress $read $total $url
        }
    } else {
        Write-Host "Downloading $url ($(filesize $total))..."
        function Trace-DownloadProgress {
            #no op
        }
    }

    try {
        $s = $wres.getresponsestream()
        $fs = [io.file]::openwrite($to)
        $buffer = New-Object byte[] 2048
        $totalRead = 0
        $sw = [diagnostics.stopwatch]::StartNew()
        $readCts = $null
        if ($PSVersionTable.PSVersion.Major -gt 5) { $readCts = New-Object System.Threading.CancellationTokenSource($stallMs) }

        Trace-DownloadProgress $totalRead
        while ($true) {
            if ($readCts) {
                $rt = $s.ReadAsync($buffer, 0, $buffer.length, $readCts.Token)
                try { $read = $rt.GetAwaiter().GetResult() } catch { throw "Download stalled (no data for $($stallMs)ms)" }
                $readCts.CancelAfter($stallMs)
            } else {
                $read = $s.read($buffer, 0, $buffer.length)
            }
            if ($read -le 0) { break }
            $fs.write($buffer, 0, $read)
            $totalRead += $read
            if ($sw.elapsedmilliseconds -gt 100) {
                $sw.restart()
                Trace-DownloadProgress $totalRead
            }
        }
        $sw.stop()
        Trace-DownloadProgress $totalRead
    } finally {
        if ($readCts) { $readCts.Dispose() }
        if ($progress) {
            [console]::CursorVisible = $true
            Write-Host
        }
        if ($fs) {
            $fs.close()
        }
        if ($s) {
            $s.close()
        }
        $wres.close()
    }
}

function Format-DownloadProgress ($url, $read, $total, $console) {
    $filename = url_remote_filename $url

    # calculate current percentage done
    $p = [math]::Round($read / $total * 100, 0)

    # pre-generate LHS and RHS of progress string
    # so we know how much space we have
    $left = "$filename ($(filesize $total))"
    $right = [string]::Format('{0,3}%', $p)

    # calculate remaining width for progress bar
    $midwidth = $console.BufferSize.Width - ($left.Length + $right.Length + 8)

    # calculate how many characters are completed
    $completed = [math]::Abs([math]::Round(($p / 100) * $midwidth, 0) - 1)

    # generate dashes to symbolise completed
    if ($completed -gt 1) {
        $dashes = [string]::Join('', ((1..$completed) | ForEach-Object { '=' }))
    }

    # this is why we calculate $completed - 1 above
    $dashes += switch ($p) {
        100 { '=' }
        default { '>' }
    }

    # the remaining characters are filled with spaces
    $spaces = switch ($dashes.Length) {
        $midwidth { [string]::Empty }
        default {
            [string]::Join('', ((1..($midwidth - $dashes.Length)) | ForEach-Object { ' ' }))
        }
    }

    "$left [$dashes$spaces] $right"
}

function Write-DownloadProgress ($read, $total, $url) {
    $console = $Host.UI.RawUI
    $left = $console.CursorPosition.X
    $top = $console.CursorPosition.Y
    $width = $console.BufferSize.Width

    if ($read -eq 0) {
        $maxOutputLength = $(Format-DownloadProgress $url 100 $total $console).Length
        if (($left + $maxOutputLength) -gt $width) {
            # not enough room to print progress on this line
            # print on new line
            Write-Host
            $left = 0
            $top = $top + 1
            if ($top -gt $console.CursorPosition.Y) { $top = $console.CursorPosition.Y }
        }
    }

    Write-Host $(Format-DownloadProgress $url $read $total $console) -NoNewline
    [console]::SetCursorPosition($left, $top)
}

## Aria2 downloader

function Test-Aria2Enabled {
    return (Test-HelperInstalled -Helper Aria2) -and (get_config 'aria2-enabled' $true)
}

function aria_exit_code($exitcode) {
    $codes = @{
        0  = 'All downloads were successful'
        1  = 'An unknown error occurred'
        2  = 'Timeout'
        3  = 'Resource was not found'
        4  = 'Aria2 saw the specified number of "resource not found" error. See --max-file-not-found option'
        5  = 'Download aborted because download speed was too slow. See --lowest-speed-limit option'
        6  = 'Network problem occurred.'
        7  = 'There were unfinished downloads. This error is only reported if all finished downloads were successful and there were unfinished downloads in a queue when aria2 exited by pressing Ctrl-C by an user or sending TERM or INT signal'
        8  = 'Remote server did not support resume when resume was required to complete download'
        9  = 'There was not enough disk space available'
        10 = 'Piece length was different from one in .aria2 control file. See --allow-piece-length-change option'
        11 = 'Aria2 was downloading same file at that moment'
        12 = 'Aria2 was downloading same info hash torrent at that moment'
        13 = 'File already existed. See --allow-overwrite option'
        14 = 'Renaming file failed. See --auto-file-renaming option'
        15 = 'Aria2 could not open existing file'
        16 = 'Aria2 could not create new file or truncate existing file'
        17 = 'File I/O error occurred'
        18 = 'Aria2 could not create directory'
        19 = 'Name resolution failed'
        20 = 'Aria2 could not parse Metalink document'
        21 = 'FTP command failed'
        22 = 'HTTP response header was bad or unexpected'
        23 = 'Too many redirects occurred'
        24 = 'HTTP authorization failed'
        25 = 'Aria2 could not parse bencoded file (usually ".torrent" file)'
        26 = '".torrent" file was corrupted or missing information that aria2 needed'
        27 = 'Magnet URI was bad'
        28 = 'Bad/unrecognized option was given or unexpected option argument was given'
        29 = 'The remote server was unable to handle the request due to a temporary overloading or maintenance'
        30 = 'Aria2 could not parse JSON-RPC request'
        31 = 'Reserved. Not used'
        32 = 'Checksum validation failed'
    }
    if ($null -eq $codes[$exitcode]) {
        return 'An unknown error occurred'
    }
    return $codes[$exitcode]
}

function get_filename_from_metalink($file) {
    $bytes = get_magic_bytes_pretty $file ''
    # check if file starts with '<?xml'
    if (!($bytes.StartsWith('3c3f786d6c'))) {
        return $null
    }

    # Add System.Xml for reading metalink files
    Add-Type -AssemblyName 'System.Xml'
    $xr = [System.Xml.XmlReader]::Create($file)
    $filename = $null
    try {
        $xr.ReadStartElement('metalink')
        if ($xr.ReadToFollowing('file') -and $xr.MoveToFirstAttribute()) {
            $filename = $xr.Value
        }
    } catch [System.Xml.XmlException] {
        return $null
    } finally {
        $xr.Close()
    }

    return $filename
}

function Invoke-CachedAria2Download ($app, $version, $manifest, $architecture, $dir, $cookies = $null, $use_cache = $true, $check_hash = $true) {
    $data = @{}
    $urls = @(script:url $manifest $architecture)

    # aria2 input file
    $urlstxt = Join-Path $cachedir "$app.txt"
    $urlstxt_content = ''
    $download_finished = $true

    # aria2 options
    $options = @(
        "--input-file='$urlstxt'"
        "--user-agent='$(Get-UserAgent)'"
        '--allow-overwrite=true'
        '--auto-file-renaming=false'
        "--retry-wait=$(get_config 'aria2-retry-wait' 2)"
        "--split=$(get_config 'aria2-split' 5)"
        "--max-connection-per-server=$(get_config 'aria2-max-connection-per-server' 5)"
        "--min-split-size=$(get_config 'aria2-min-split-size' '5M')"
        '--console-log-level=warn'
        '--enable-color=false'
        '--no-conf=true'
        '--follow-metalink=true'
        '--metalink-preferred-protocol=https'
        '--min-tls-version=TLSv1.2'
        "--stop-with-process=$PID"
        '--continue'
        '--summary-interval=0'
        '--auto-save-interval=1'
    )

    if ($cookies) {
        $options += "--header='Cookie: $(cookie_header $cookies)'"
    }

    $proxy = get_config PROXY
    if ($proxy -ne 'none') {
        if ([Net.Webrequest]::DefaultWebProxy.Address) {
            $options += "--all-proxy='$([Net.Webrequest]::DefaultWebProxy.Address.Authority)'"
        }
        if ([Net.Webrequest]::DefaultWebProxy.Credentials.UserName) {
            $options += "--all-proxy-user='$([Net.Webrequest]::DefaultWebProxy.Credentials.UserName)'"
        }
        if ([Net.Webrequest]::DefaultWebProxy.Credentials.Password) {
            $options += "--all-proxy-passwd='$([Net.Webrequest]::DefaultWebProxy.Credentials.Password)'"
        }
    }

    $more_options = get_config 'aria2-options'
    if ($more_options) {
        $options += $more_options
    }

    foreach ($url in $urls) {
        $data.$url = @{
            'target'    = Join-Path $dir (url_filename $url)
            'cachename' = fname (cache_path $app $version $url)
            'source'    = cache_path $app $version $url
        }

        if ((Test-Path $data.$url.source) -and -not((Test-Path "$($data.$url.source).aria2") -or (Test-Path $urlstxt)) -and $use_cache) {
            Write-Host "Loading $([char]0x1b)[36m$(url_remote_filename $url)$([char]0x1b)[0m from cache."
        } else {
            $download_finished = $false
            # create aria2 input file content
            try {
                $try_url = handle_special_urls $url
            } catch {
                if ($_.Exception.Response.StatusCode -eq 'Unauthorized') {
                    warn 'Token might be misconfigured.'
                }
            }
            $urlstxt_content += "$(Get-GitHubMirrorUrl $try_url)`n"
            if (!$url.Contains('sourceforge.net')) {
                $urlstxt_content += "    referer=$(strip_filename $url)`n"
            }
            $urlstxt_content += "    dir=$cachedir`n"
            $urlstxt_content += "    out=$($data.$url.cachename)`n"
        }
    }

    if (-not($download_finished)) {
        # write aria2 input file
        if ($urlstxt_content -ne '') {
            ensure $cachedir | Out-Null
            # Write aria2 input-file with UTF8NoBOM encoding
            $urlstxt_content | Out-UTF8File -FilePath $urlstxt
        }

        # build aria2 command
        $aria2 = "& '$(Get-HelperPath -Helper Aria2)' $($options -join ' ')"

        # handle aria2 console output
        Write-Host 'Starting download with aria2...'

        # Set console output encoding to UTF8 for non-ASCII characters printing
        $oriConsoleEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding

        Invoke-Command ([scriptblock]::Create($aria2)) | ForEach-Object {
            # Skip blank lines
            if ([String]::IsNullOrWhiteSpace($_)) { return }

            # Prevent potential overlapping of text when one line is shorter
            $len = $Host.UI.RawUI.WindowSize.Width - $_.Length - 20
            $blank = if ($len -gt 0) { ' ' * $len } else { '' }
            $color = 'Gray'

            if ($_.StartsWith('(OK):')) {
                $noNewLine = $true
                $color = 'Green'
            } elseif ($_.StartsWith('[') -and $_.EndsWith(']')) {
                $noNewLine = $true
                $color = 'Cyan'
            } elseif ($_.StartsWith('Download Results:')) {
                $noNewLine = $false
            }

            Write-Host "`rDownload: $_$blank" -ForegroundColor $color -NoNewline:$noNewLine
        }
        Write-Host ''

        if ($lastexitcode -gt 0) {
            # Values containing "'" would break the aria2 command itself, so '...' spans are safe redaction boundaries
            $aria2Diag = $aria2 -replace "--all-proxy-passwd='[^']*'", "--all-proxy-passwd='***'" -replace "--header='Cookie:[^']*'", "--header='Cookie: ***'"
            $urlstxtDiag = $urlstxt_content -replace '(?<u>(?:https?|ftp)\S*?)\?\S*', '${u}?***'
            if (-not (get_config ARIA2-FALLBACK-ENABLED $true)) {
                error "Download failed! (Error $lastexitcode) $(aria_exit_code $lastexitcode)"
                error $urlstxtDiag
                error $aria2Diag
                abort $(new_issue_msg $app $bucket 'download via aria2 failed')
            }

            warn "Download failed! (Error $lastexitcode) $(aria_exit_code $lastexitcode)"
            warn $urlstxtDiag
            warn $aria2Diag

            Write-Host 'Fallback to default downloader...'

            try {
                foreach ($url in $urls) {
                    Invoke-CachedDownload $app $version $url "$($data.$url.target)" $cookies $use_cache
                }
            } catch {
                Write-Host $_ -ForegroundColor DarkRed
                error "URL $url is not valid"
                abort $(new_issue_msg $app $bucket 'download failed')
            }
        }

        # remove aria2 input file when done
        if (Test-Path $urlstxt, "$($data.$url.source).aria2*") {
            Remove-Item $urlstxt -Force -ErrorAction SilentlyContinue
            Remove-Item "$($data.$url.source).aria2*" -Force -ErrorAction SilentlyContinue
        }

        # Revert console encoding
        [Console]::OutputEncoding = $oriConsoleEncoding
    }

    foreach ($url in $urls) {

        $metalink_filename = get_filename_from_metalink $data.$url.source
        if ($metalink_filename) {
            Remove-Item $data.$url.source -Force
            Rename-Item -Force (Join-Path -Path $cachedir -ChildPath $metalink_filename) $data.$url.source
        }

        # run hash checks
        if ($check_hash) {
            $manifest_hash = hash_for_url $manifest $url $architecture
            $ok, $err = check_hash $data.$url.source $manifest_hash $(show_app $app $bucket)
            if (!$ok) {
                error $err
                if (Test-Path $data.$url.source) {
                    # rm cached file
                    Remove-Item $data.$url.source -Force -ErrorAction SilentlyContinue
                    Remove-Item "$($data.$url.source).aria2*" -Force -ErrorAction SilentlyContinue
                }
                if ($url.Contains('sourceforge.net')) {
                    Write-Host -f yellow 'SourceForge.net is known for causing hash validation fails. Please try again before opening a ticket.'
                }
                abort $(new_issue_msg $app $bucket 'hash check failed')
            }
        }

        # copy or move file to target location
        if (!(Test-Path $data.$url.source) ) {
            abort $(new_issue_msg $app $bucket 'cached file not found')
        }

        if (!($dir -eq $cachedir)) {
            if ($use_cache) {
                Copy-Item $data.$url.source $data.$url.target
            } else {
                Move-Item $data.$url.source $data.$url.target -Force
            }
        }
    }
}

## Helper functions

### Downloader parameters

function cookie_header($cookies) {
    if (!$cookies) { return }

    $vals = $cookies.psobject.properties | ForEach-Object {
        "$($_.name)=$($_.value)"
    }

    [string]::join(';', $vals)
}

function Get-Encoding($wc) {
    if ($null -ne $wc.ResponseHeaders -and $wc.ResponseHeaders['Content-Type'] -match 'charset=([^;]*)') {
        return [System.Text.Encoding]::GetEncoding($Matches[1])
    } else {
        return [System.Text.Encoding]::GetEncoding('utf-8')
    }
}

function Get-UserAgent() {
    return "Scoop/1.0 (+http://scoop.sh/) PowerShell/$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor) (Windows NT $([System.Environment]::OSVersion.Version.Major).$([System.Environment]::OSVersion.Version.Minor); $(if(${env:ProgramFiles(Arm)}){'ARM64; '}elseif($env:PROCESSOR_ARCHITECTURE -eq 'AMD64'){'Win64; x64; '})$(if($env:PROCESSOR_ARCHITEW6432 -in 'AMD64','ARM64'){'WOW64; '})$PSEdition)"
}

function setup_proxy() {
    # note: '@' and ':' in password must be escaped, e.g. 'p@ssword' -> p\@ssword'
    $proxy = get_config PROXY
    if (!$proxy) {
        return
    }
    try {
        $credentials, $address = $proxy -split '(?<!\\)@'
        if (!$address) {
            $address, $credentials = $credentials, $null # no credentials supplied
        }

        if ($address -eq 'none') {
            [net.webrequest]::defaultwebproxy = $null
        } elseif ($address -ne 'default') {
            [net.webrequest]::defaultwebproxy = New-Object net.webproxy "http://$address"
        }

        if ($credentials -eq 'currentuser') {
            [net.webrequest]::defaultwebproxy.credentials = [net.credentialcache]::defaultcredentials
        } elseif ($credentials) {
            $username, $password = $credentials -split '(?<!\\):' | ForEach-Object { $_ -replace '\\([@:])', '$1' }
            [net.webrequest]::defaultwebproxy.credentials = New-Object net.networkcredential($username, $password)
        }
    } catch {
        warn "Failed to use proxy '$proxy': $($_.exception.message)"
    }
}

function Get-GitHubToken {
    return $env:SCOOP_GH_TOKEN, (get_config GH_TOKEN), $env:GH_TOKEN, $env:GITHUB_TOKEN | Where-Object -Property Length -Value 0 -GT | Select-Object -First 1
}

function github_ratelimit_reached {
    $api_link = 'https://api.github.com/rate_limit'
    $ret = (download_json $api_link).rate.remaining -eq 0
    if ($ret) {
        Write-Host "GitHub API rate limit reached.`r`nPlease try again later or configure your API token using 'scoop config gh_token <your token>'."
    }
    $ret
}

### URL handling

function handle_special_urls($url) {
    # FossHub.com
    if ($url -match '^(?:.*fosshub.com\/)(?<name>.*)(?:\/|\?dwl=)(?<filename>.*)$') {
        $Body = @{
            projectUri      = $Matches.name
            fileName        = $Matches.filename
            source          = 'CF'
            isLatestVersion = $true
        }
        if ((Invoke-RestMethod -Uri $url) -match '"p":"(?<pid>[a-f0-9]{24}).*?"r":"(?<rid>[a-f0-9]{24})') {
            $Body.Add('projectId', $Matches.pid)
            $Body.Add('releaseId', $Matches.rid)
        }
        $url = Invoke-RestMethod -Method Post -Uri 'https://api.fosshub.com/download/' -ContentType 'application/json' -Body (ConvertTo-Json $Body -Compress)
        if ($null -eq $url.error) {
            $url = $url.data.url
        }
    }

    # Sourceforge.net
    if ($url -match '(?:downloads\.)?sourceforge.net\/projects?\/(?<project>[^\/]+)\/(?:files\/)?(?<file>.*?)(?:$|\/download|\?)') {
        # Reshapes the URL to avoid redirections
        $url = "https://downloads.sourceforge.net/project/$($matches['project'])/$($matches['file'])"
    }

    # Github.com
    if ($url -match 'github.com/(?<owner>[^/]+)/(?<repo>[^/]+)/releases/download/(?<tag>[^/]+)/(?<file>[^/#]+)(?<filename>.*)' -and ($token = Get-GitHubToken)) {
        $headers = @{ 'Authorization' = "token $token" }
        $privateUrl = "https://api.github.com/repos/$($Matches.owner)/$($Matches.repo)"
        $assetUrl = "https://api.github.com/repos/$($Matches.owner)/$($Matches.repo)/releases/tags/$($Matches.tag)"

        if ((Invoke-RestMethod -Uri $privateUrl -Headers $headers).Private) {
            $url = ((Invoke-RestMethod -Uri $assetUrl -Headers $headers).Assets | Where-Object -Property Name -EQ -Value $Matches.file).Url, $Matches.filename -join ''
        }
    }

    return $url
}

### Remote file information

function download_json($url) {
    $githubtoken = Get-GitHubToken
    $authheader = @{}
    if ($githubtoken) {
        $authheader = @{'Authorization' = "token $githubtoken" }
    }
    $ProgressPreference = 'SilentlyContinue'
    $result = Invoke-WebRequest $url -UseBasicParsing -Headers $authheader | Select-Object -ExpandProperty content | ConvertFrom-Json
    $ProgressPreference = 'Continue'
    $result
}

function get_magic_bytes($file) {
    if (!(Test-Path $file)) {
        return ''
    }

    if ((Get-Command Get-Content).parameters.ContainsKey('AsByteStream')) {
        # PowerShell Core (6.0+) '-Encoding byte' is replaced by '-AsByteStream'
        return Get-Content $file -AsByteStream -TotalCount 8
    } else {
        return Get-Content $file -Encoding byte -TotalCount 8
    }
}

function get_magic_bytes_pretty($file, $glue = ' ') {
    if (!(Test-Path $file)) {
        return ''
    }

    return (get_magic_bytes $file | ForEach-Object { $_.ToString('x2') }) -join $glue
}

Function Get-RemoteFileSize ($Uri) {
    $response = Invoke-WebRequest -Uri $Uri -Method HEAD -UseBasicParsing
    if (!$response.Headers.StatusCode) {
        $response.Headers.'Content-Length' | ForEach-Object { [int]$_ }
    }
}

function ftp_file_size($url) {
    $request = [net.ftpwebrequest]::create($url)
    $request.method = [net.webrequestmethods+ftp]::getfilesize
    $request.getresponse().contentlength
}

function url_filename($url) {
    (Split-Path $url -Leaf).split('?') | Select-Object -First 1
}

function url_remote_filename($url) {
    # Unlike url_filename which can be tricked by appending a
    # URL fragment (e.g. #/dl.7z, useful for coercing a local filename),
    # this function extracts the original filename from the URL.
    $uri = (New-Object URI $url)
    $basename = Split-Path $uri.PathAndQuery -Leaf
    If ($basename -match '.*[?=]+([\w._-]+)') {
        $basename = $matches[1]
    }
    If (($basename -notlike '*.*') -or ($basename -match '^[v.\d]+$')) {
        $basename = Split-Path $uri.AbsolutePath -Leaf
    }
    If (($basename -notlike '*.*') -and ($uri.Fragment -ne '')) {
        $basename = $uri.Fragment.Trim('/', '#')
    }
    return $basename
}

### Hash-related functions

function hash_for_url($manifest, $url, $arch) {
    $hashes = @(hash $manifest $arch) | Where-Object { $_ -ne $null }

    if ($hashes.length -eq 0) { return $null }

    $urls = @(script:url $manifest $arch)

    $index = [array]::IndexOf($urls, $url)
    if ($index -eq -1) { abort "Couldn't find hash in manifest for '$url'." }

    @($hashes)[$index]
}

function check_hash($file, $hash, $app_name) {
    # returns (ok, err)
    if (!$hash) {
        warn "Warning: No hash in manifest. SHA256 for '$(fname $file)' is:`n    $((Get-FileHash -Path $file -Algorithm SHA256).Hash.ToLower())"
        return $true, $null
    }

    Write-Host "Checking hash of $([char]0x1b)[36m$(url_remote_filename $url)$([char]0x1b)[0m... " -NoNewline
    $algorithm, $expected = get_hash $hash
    if ($null -eq $algorithm) {
        return $false, "Hash type '$algorithm' isn't supported."
    }

    $actual = (Get-FileHash -Path $file -Algorithm $algorithm).Hash.ToLower()
    $expected = $expected.ToLower()

    if ($actual -ne $expected) {
        $msg = "Hash check failed!`n"
        $msg += "App:         $app_name`n"
        $msg += "URL:         $url`n"
        if (Test-Path $file) {
            $msg += "First bytes: $((get_magic_bytes_pretty $file ' ').ToUpper())`n"
        }
        if ($expected -or $actual) {
            $msg += "Expected:    $expected`n"
            $msg += "Actual:      $actual"
        }
        return $false, $msg
    }
    Write-Host 'OK.' -f Green
    return $true, $null
}

function get_hash([String] $multihash) {
    $type, $hash = $multihash -split ':'
    if (!$hash) {
        # no type specified, assume sha256
        $type, $hash = 'sha256', $multihash
    }

    if (@('md5', 'sha1', 'sha256', 'sha512') -notcontains $type) {
        return $null, "Hash type '$type' isn't supported."
    }

    return $type, $hash.ToLower()
}

# Setup proxy globally
setup_proxy
