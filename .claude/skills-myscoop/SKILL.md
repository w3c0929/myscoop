---
name: myscoop
description: 将 GitHub 上的 Windows 软件收录到 myscoop bucket。分析目标项目的 release 资产，选择合适的安装方式，生成 manifest 并验证。
type: project
---

# Scoop Manifest 制作技能

## 触发条件

当用户说"添加这个软件到 myscoop"、"收录"、"把 xxx 加到 bucket"等，或给出一个仓库/下载链接时触发。

## 执行流程

### 第零步：链接类型自动判断

用户提供链接时，先自动判断链接类型，决定后续流程：

| 链接类型 | 判断规则 | 处理方式 |
|---------|---------|---------|
| GitHub 仓库链接 | 域名含 `github.com/{owner}/{repo}`（或 gitee.com） | **必须**执行 `python3 myscoop-update.py --add <链接> [--name 应用名]` 自动生成 manifest（脚本内部完成 API 收集与资产分析；zip 等内部的 bin/shortcuts 仍需手动确认） |
| 直接下载链接 | 以 `.exe` / `.zip` / `.7z` / `.msi` 结尾的文件直链 | 跳过第一步（GitHub API 收集），直接进入第二步，**必须由用户确认收录方式**后才能继续 |
| 其他网页链接 | 官网、网盘、论坛等非直链页面 | 先向用户确认最终下载地址；确认后按"直接下载链接"处理 |

> 判断规则：URL 路径包含 `github.com/` 且后面跟 `{owner}/{repo}`（或 `{owner}/{repo}/releases/...`）视为 GitHub 链接；否则按下载链接或网页链接处理。

### 第一步：信息收集（并行请求）

> 仅 GitHub 链接执行本步；直接下载链接跳过本步。

同时执行以下查询，获取项目基本信息：

```bash
# 项目元信息（描述、License）
curl -s "https://api.github.com/repos/{owner}/{repo}" | python3 -c "
import sys,json; r=json.load(sys.stdin)
print('Description:', r.get('description'))
print('License:', r.get('license',{}).get('spdx_id','unknown'))
print('Homepage:', r.get('homepage',''))
"

# 最新 Release 资产（文件名、大小、下载 URL）
curl -s "https://api.github.com/repos/{owner}/{repo}/releases/latest" | python3 -c "
import sys,json; r=json.load(sys.stdin)
print('Tag:', r['tag_name'])
for a in r['assets']:
    print(f'  {a[\"name\"]}  ({a[\"size\"]} bytes)  {a[\"browser_download_url\"]}')
"
```

### 第二步：分析资产类型

> **下载链接强制确认**：当用户提供的是直接下载链接（非 GitHub 链接）时，必须先列出本 SKILL 的全部收录方式（情况 A-I，见下），由用户选择确认采用哪种方式；**用户未确认前禁止进入下一步（生成 manifest）**。
>
> 列出格式（示例）：
> ```
> 检测到下载链接（非 GitHub 链接），请选择收录方式：
> A. portable zip/7z 便携（首选）
> B. 单 exe 直链
> C. zip 内含 MSI（lessmsi 解包）
> D. Setup.exe 解包/静默安装
> E. framework-dependent（加 depends）
> F. 上游停更自托管便携
> G. 单 exe 手动安装（post_install 自动启动）
> H. Choco/SourceForge 迁移
> I. MSI 手动安装
> 请回复对应字母。
> ```
>
> GitHub 链接无需此确认，直接按下方资产类型判断。

根据 release 资产判断采用哪种方案：

#### 情况 A：有 portable .zip/.7z（首选）

> 条件：release 中包含 `portable.zip`、`.7z` 或普通 `.zip` 文件（非 Setup.exe）
> 参考：ContextMenuMgr（多架构 zip）、MyKeymap（单包 7z）
>
> Scoop 原生支持 .zip 和 .7z 格式，无需额外工具。

1. **下载并查看 zip 内部结构**（确定有无顶层目录）：

```bash
curl -L -o _temp.zip "{url}" && 7z l _temp.zip | head -40
```

2. 判断 `extract_dir`：
   - 有顶层目录 `app-v1.0/app.exe` → 设为 `"extract_dir": "app-v1.0"`
   - 扁平结构 `app.exe` → 不设 extract_dir

3. 判断架构覆盖：
   - 有 `x64`/`x86`/`arm64` 分别的 zip → 使用 `architecture` 块
   - 只有一个通用 zip → 使用顶层 `url`/`hash`

4. **获取 SHA256**（按优先级）：
   - **方法1（推荐）**：从 GitHub API 的 asset `digest` 字段直接读取——无需下载文件
     ```bash
     curl -s "https://api.github.com/repos/{owner}/{repo}/releases/latest" | python3 -c "
     import sys,json; r=json.load(sys.stdin)
     for a in r['assets']:
         print(a['name'], '→', a.get('digest',''))
     "
     ```
   - **方法2**：从 release 页面文本中提取（如果作者贴了 sha256）
   - **方法3**：下载后 `certutil -hashfile _temp.zip SHA256`（兜底）

5. Manifest 模板（多架构 portable zip）：

```json
{
    "version": "{version}",
    "description": "{英文一句话描述}",
    "homepage": "https://github.com/{owner}/{repo}",
    "license": "{spdx_id}",
    "architecture": {
        "64bit": {
            "url": "https://github.com/{owner}/{repo}/releases/download/v{version}/{asset}-x64-portable.zip",
            "hash": "sha256:{hash}"
        },
        "32bit": { ... },
        "arm64": { ... }
    },
    "bin": "{main_exe}",
    "shortcuts": [["{main_exe}", "{Display Name}"]],
    "checkver": { "github": "https://github.com/{owner}/{repo}" },
    "autoupdate": {
        "architecture": {
            "64bit": { "url": "https://github.com/{owner}/{repo}/releases/download/v$version/{asset}-$version-x64-portable.zip" },
            "32bit": { ... },
            "arm64": { ... }
        }
    }
}
```

#### 情况 B：单 exe 直链（次选）

> 条件：release 中直接提供 `.exe` 文件（非安装包），无 zip
> 参考：WindowsClear

1. 下载 exe 并计算 SHA256：

```bash
curl -L -o _temp.exe "{url}" && certutil -hashfile _temp.exe SHA256
```

2. Manifest 模板：

```json
{
    "version": "{version}",
    "description": "{英文一句话描述}",
    "homepage": "https://github.com/{owner}/{repo}",
    "license": "{spdx_id}",
    "url": "https://github.com/{owner}/{repo}/releases/download/v{version}/{asset}.exe",
    "hash": "sha256:{hash}",
    "bin": "{asset}.exe",
    "shortcuts": [["{asset}.exe", "{Display Name}"]],
    "checkver": { "github": "https://github.com/{owner}/{repo}" },
    "autoupdate": {
        "url": "https://github.com/{owner}/{repo}/releases/download/v$version/{asset}.exe"
    }
}
```

#### 情况 C：zip 内含 MSI 安装包

> 条件：release 提供 .zip，但解压后只有 .msi 文件（非直接可执行文件）
> 参考：WGestures

1. 下载 zip 并查看内部结构：

```bash
curl -L -o _temp.zip "{url}" && 7z l _temp.zip | head -30
```

2. 如果 zip 内只有一个 .msi，用 `lessmsi` 查看 MSI 文件清单：

```bash
# 先解压 zip 得到 msi
7z x _temp.zip -o_temp_dir
# 用 lessmsi 查看 MSI 文件表，找出主 exe 名称
lessmsi l -t File _temp_dir/xxx.msi | head -40
```

3. 安装 `lessmsi`（Scoop 解包 .msi 的工具）：

```bash
scoop install lessmsi
```

4. 用 lessmsi 提取 MSI，确认输出结构：

```bash
cd _temp_dir && lessmsi xo "xxx.msi"
# 输出路径: ./<ProductName>/SourceDir/<AppName>/
```

5. 计算 zip 的 SHA256（不是 msi 的）：

```bash
certutil -hashfile _temp.zip SHA256
```

6. Manifest 模板：

```json
{
    "version": "{version}",
    "description": "{英文一句话描述}",
    "homepage": "https://github.com/{owner}/{repo}",
    "license": "{spdx_id}",
    "url": "https://github.com/{owner}/{repo}/releases/download/$version/$version.zip",
    "hash": "sha256:{hash}",
    "depends": "lessmsi",
    "installer": {
        "script": [
            "Push-Location \"$dir\"",
            "lessmsi xo \"{msi_filename}.msi\"",
            "Get-ChildItem \".\\{ProductName}\\SourceDir\\{AppName}\\*\" -Recurse | Move-Item -Destination \"$dir\" -Force",
            "Remove-Item \".\\{ProductName}\" -Recurse -Force -ErrorAction SilentlyContinue",
            "Remove-Item \"{msi_filename}.msi\" -Force -ErrorAction SilentlyContinue",
            "Pop-Location"
        ]
    },
    "bin": "{main_exe}",
    "shortcuts": [["{main_exe}", "{Display Name}"]],
    "checkver": { "github": "https://github.com/{owner}/{repo}" },
    "autoupdate": {
        "url": "https://github.com/{owner}/{repo}/releases/download/$version/$version.zip"
    }
}
```

> **关键**：必须用 `installer.script` 而非 `post_install`。因为 Scoop 的执行顺序是 `pre_install → installer.script → 创建shim → post_install`。如果提取放在 `post_install`，shim 创建时 exe 还不存在，会报 `File doesn't exist`。
>
> `<ProductName>` 和 `<AppName>` 来自 lessmsi 实际提取的目录名，必须通过实测确定。`checkver` 的 `$version` 不带 `v` 前缀则 tag 也不带 `v`。

#### 情况 D：只有 Setup.exe 安装包

> 条件：release 只有 Setup.exe，没有 portable/zip/msi
> 参考：Bandizip 6.18

1. 先用 7z 检测安装器类型：

```bash
7z l Setup.exe 2>&1 | grep "Type = "
```

2. 分类型处理：

| 7z 检测结果 | 处理方式 |
|------------|---------|
| `Type = 7z` | **NSIS 安装器 → 直接 7z 提取**，打包为 portable zip，参照情况 F 自托管 |
| `Type = PE` 且无 `7z` | 可能是 Inno Setup → 尝试 `innounp` 解包；若加密则改用静默安装 |
| 无法识别 | 告知用户等待 portable 版，或考虑 `lessmsi`（如果是 MSI 内嵌） |

3. **NSIS 解包流程**（7z 可直接提取）：

```bash
7z l Setup.exe | tail -30          # 确认 Type = 7z
7z x Setup.exe -o_output -y         # 直接提取
ls output/                           # Main exe: app.exe
cd output && 7z a -tzip ../app-portable.zip * -r -mx9
certutil -hashfile ../app-portable.zip SHA256
```

4. **Inno Setup 解包流程**（需 innounp，`7z l` 显示 `Type = PE` 无嵌入 7z，含 "Inno Setup" 注释）：

```bash
# 安装 innounp
scoop install innounp
# 解包（文件通常在 {app}/ 子目录）
innounp -x -d_output Setup.exe
ls _output/{app}/
```

> **组装便携目录（模仿安装器行为，bcompare 方式）**：
> - ⚠️ **不要保留 `,1/,2` 后缀变体文件**！它们是安装器的 32/64 位源文件，安装器只输出无后缀的最终文件（看 install_script.iss 的 DestName 确认）。保留会导致目录错乱
> - 复制 64 位主程序为无后缀名：`cp "BCompare,2.exe" BCompare.exe`（安装器在 64 位系统会这样做）
> - 复制对应汉化翻译：`cp "BCompare,2.tr" BCompare.tr`；其余 64 位文件同理（7z,2.dll→7z.dll 等）
> - 加入注册文件（BC5Key.txt），程序启动时读取；若有汉化 DLL（version.dll）一并放入
> - 保留 Patch.exe 等辅助程序
> - ⚠️ `7z a` 到已存在 zip 是**追加不是覆盖**，打包前必须删除旧 zip，否则内容混合
> - 打包后验证：`7z l zip | grep -c ",1\.\|,2\."` 应为 0
> - 示例：bcompare 5.2.5.32528（21MB，19 文件含 BC5Key.txt + version.dll）

```bash
# 从 {app} 内打包
cd _output/{app} && 7z a -tzip ../../app-portable.zip * -r -mx9
certutil -hashfile ../../app-portable.zip SHA256
```

> **注册/汉化补丁获取**：注册信息常在独立补丁安装器里（如 BCompare-5.2.5_汉化补丁.exe）。Inno 7.0+ innounp/innoextract 均无法解包（"not supported version"），只能**运行 GUI 安装**，从安装目录提取注册文件（BC5Key.txt）+ 汉化 DLL（version.dll）。也可请求用户自行安装汉化后打包。

5. **加密 Inno Setup 兜底流程**（密码破解失败时）：

```bash
# 静默安装到临时目录
installer.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR="output"
# 清理卸载残留（unins000.*, *.lnk）
find output -name "unins*" -delete
# 打包便携 zip
cd output && 7z a -tzip ../app-portable.zip . -r -mx9
```

> 密码枚举：先用 `innoextract --show-password` 获取 hash/salt，再用 `--check-password` 逐个测试。常见密码：产品名（含空格）、公司名全小写、版本号。

6. 如果所有方式都无法解包且静默安装也失败 → 告知用户该软件不适合 Scoop 收录

#### 情况 E：framework-dependent 额外依赖

如果 zip 内有 `runtimes/` 目录（如 .NET runtime），说明是 framework-dependent：
- 对于 framework-dependent zip，需要在 manifest 中加 `"depends": ["dotnet-sdk"]` 或类似依赖
- 优先推荐用户使用 self-contained 版本

#### 情况 F：上游停更，自托管便携 zip

> 条件：上游项目已归档/停更，但用户有更新的安装包（如 MSI）
> 参考：WGestures 1.8.5.0

1. 用 `lessmsi` 提取 MSI 内容，查看输出目录结构：

```bash
lessmsi xo "xxx.msi"
# 记录输出路径: ./<ProductName>/SourceDir/<AppName>/
```

2. 打包为便携 zip（从提取的目录内打包，确保扁平结构）：

```bash
cd "<ProductName>/SourceDir/<AppName>"
7z a -tzip "<appname>-<version>-portable.zip" * -r -mx9
```

3. 计算 SHA256：

```bash
certutil -hashfile "<appname>-<version>-portable.zip" SHA256
```

4. 上传为 bucket 仓库的 Release：

```bash
gh release create v<version> "<appname>-<version>-portable.zip" \
  --title "<AppName> <version>" \
  --notes "Community-maintained portable release. Upstream project archived."
```

5. Manifest 模板（无 checkver/autoupdate）：

```json
{
    "version": "{version}",
    "description": "{描述} (community-maintained, upstream archived)",
    "homepage": "https://github.com/{upstream_owner}/{upstream_repo}",
    "license": "{spdx_id}",
    "url": "https://github.com/w3c0929/myscoop/releases/download/v{version}/{appname}-{version}-portable.zip",
    "hash": "sha256:{hash}",
    "bin": "{main_exe}",
    "shortcuts": [["{main_exe}", "{Display Name}"]]
}
```

> **注意**：自托管不设置 `checkver`/`autoupdate`。清理上游原有的 MSI 相关字段（`depends: lessmsi`、`installer.script`）。manifest 回归到最简单的 portable zip 模式。

#### 情况 G：单 exe 手动安装（用户明确要求时）

> 条件：用户说"手动安装"或要求 exe 直接上传不做解包
> 参考：Apollo

1. 直接上传原始 exe 到 GitHub Release：

```bash
gh release create v<version> "<appname>-<version>.exe" \
  --title "<AppName> <version>" \
  --notes "<AppName> <version> installer. Manual installation."
```

2. Manifest 模板（无 `bin`，用 `post_install` 自动启动）：

```json
{
    "version": "{version}",
    "description": "{英文一句话描述}",
    "homepage": "https://github.com/{owner}/{repo}",
    "license": "{spdx_id}",
    "url": "https://github.com/w3c0929/myscoop/releases/download/v{version}/{appname}-{version}.exe",
    "hash": "sha256:{hash}",
    "post_install": "Start-Process \"$dir\\{appname}-{version}.exe\""
}
```

流程：`gh release create exe → scoop install 下载 → post_install 自动启动 → 用户手动完成安装向导`。不设 `bin`/`shortcuts`/`checkver`/`autoupdate`。

#### 情况 H：从 Choco/SourceForge 获取便携包

> 条件：软件只存在于 Chocolatey 或 SourceForge，无 GitHub Release
> 参考：DropIt 8.5.1

1. 用 `choco info <包名>` 查看包的源码仓库

2. 从源码获取下载 URL：

```bash
# 方法1：从 chocolatey GitHub 源码找 tools/chocolateyInstall.ps1
curl -s "https://raw.githubusercontent.com/{owner}/chocolatey-packages/master/automatic/{pkg}/tools/chocolateyInstall.ps1"

# 方法2：从 SourceForge 项目页找 portable zip
curl -s "https://sourceforge.net/projects/{project}/files/{name}/v{version}/" | grep -i portable
```

3. 下载 portable zip 并计算 hash：

```bash
curl -L -o _temp.zip "{sourceforge_or_choco_url}"
certutil -hashfile _temp.zip SHA256
```

4. 上传到 GitHub Release 并创建 manifest（自托管，无 checkver/autoupdate）

> 优先找 `.portable` 包名，其次是直接在 SourceForge 搜 `_Portable.zip`。如无 portable 版则尝试静默安装。

#### 情况 I：MSI 手动安装（用户明确要求保留 MSI 时）

> 条件：release 中只有 `.msi` 安装包，用户要求仅下载自启动，手动选择安装目录（非 scoop 目录）
> 参考：FileConverter 2.2

**关键问题**：Scoop 对 `.msi` 文件有硬编码的 `extract_archive`（执行 `msiexec /a` 管理员安装），在 `pre_install` / `installer` / `post_install` 之前就会解包。无法通过 manifest 字段禁止。

**解决方案**：利用 `pre_install` 从 Scoop 缓存复制 MSI 到 `$dir`，然后再 `post_install` 启动。

```bash
# 1. 获取 MSI 的 SHA256（直接从 GitHub API digest 读取）
curl -s "https://api.github.com/repos/{owner}/{repo}/releases/latest" | python3 -c "
import sys,json; r=json.load(sys.stdin)
for a in r['assets']:
    if a['name'].endswith('.msi'):
        print(a['name'], '→', a.get('digest',''))
"
```

2. Manifest 模板：

```json
{
    "version": "{version}",
    "description": "{英文一句话描述}",
    "homepage": "https://github.com/{owner}/{repo}",
    "license": "{spdx_id}",
    "url": "https://github.com/{owner}/{repo}/releases/download/v{version}/{asset}.msi",
    "hash": "sha256:{hash}",
    "pre_install": [
        "$appname = Split-Path (Split-Path $dir -Parent) -Leaf",
        "$cachedir = $dir -replace '\\\\apps\\\\.*$', '\\cache'",
        "$msi = Get-ChildItem $cachedir -Filter \"$appname#*.msi\" | Sort-Object LastWriteTime -Descending | Select-Object -First 1",
        "if ($msi) { Copy-Item $msi.FullName \"$dir\\setup.msi\" }"
    ],
    "post_install": "Start-Process \"$dir\\setup.msi\"",
    "notes": "MSI 手动安装包，scoop install 下载后自动启动，用户手动选择安装目录。"
}
```

> **原理**：Scoop 下载 → 缓存文件重命名为 `{appname}#{version}#{hash}.msi` → Scoop 执行 `msiexec /a` 解包到 `$dir` → `pre_install` 从缓存复制原始 MSI → `post_install` 启动安装向导。
>
> `$appname` 从 `$dir` 推导（`$dir` = `...\scoop\apps\{appname}\{version}`）。Scoop 缓存文件名格式为 `{appname}#{version}#{hash}.msi`，不是原始文件名，所以必须用 `$appname#*.msi` 通配符匹配。
>
> 不设 `bin`/`shortcuts`/`checkver`/`autoupdate`。

### 第三步：生成 Manifest 文件

文件名规则：**小写 + 连字符，尽量简短**（超长名会改短，如 `music-source-separation-training-gui` → `msst-gui`），如 `cmm-plus.json`、`windowsclear.json`

写入 `bucket/{appname}.json`

### 第四步：验证

```bash
# 1. JSON 语法
python3 -m json.tool bucket/{appname}.json

# 2. Scoop 解析
powershell -NoProfile -Command "scoop cat myscoop/{appname}"

# 3. 搜索可见
powershell -NoProfile -Command "scoop search {appname}"
```

### 第五步：清理与报告

- 删除临时下载文件（`_temp.zip`、`_temp.exe` 等）
- 报告用户：manifest 文件路径、安装命令、关键字段摘要

### 第六步：更新第三方 manifest（免下载）

收录完成后，第三方软件需要定期检查更新。使用 `myscoop-update.py` 脚本，通过 GitHub API digest 免下载获取新版本号和哈希：

```bash
# 检查更新
python3 myscoop-update.py --all --dry-run

# 自动更新全部（顺带同步 README 的版本列与创建/更新日期列，无需再单独跑同步脚本）
python3 myscoop-update.py --all

# 提交
git add bucket/ README.md && git commit -m "批量更新第三方软件" && git push
```

**原理**：GitHub Release API 返回的每个 asset 包含 `digest: sha256:xxx`，脚本直接读取，无需下载文件。

**README 自动同步（内置，`sync_readme_after_update`）**：`--all` 与单清单更新结束后自动刷新 README 软件表——版本列（第三方表 = 清单 `version` 原样）、创建列（清单首次提交日期）、更新列（**本次真正变更的清单取当天**——这些文件随后即被提交，日期与提交日一致；其余取最近提交日期）。幂等（无差异不写），`--dry-run` 不触发；失败只警告不影响清单更新。与 CI 内联的同名步骤逻辑等价——CI 行为不变（其内联步骤变为幂等空操作）。

## 关键规则

1. **优先 portable/zip**：上游同时提供便携版（portable/zip/7z）与安装包时选便携（打分见规则 20 / README 收录策略）；**仅发安装包时照用**——能解包就解包便携化（NSIS/Inno 7z 解包，如 bdl/vtracer/dsh），注册型（输入法/驱动/右键菜单）走 `installer` 模式完成系统注册（如 qingjian）。安装包在打分中**降级 -10（排后，非排除）**
2. **优先 self-contained**（自带运行时），少用 framework-dependent（需额外依赖）
3. **Hash 格式固定**：`sha256:xxxx`（全小写）
4. **版本号去 v 前缀**：tag `v1.2.3` → version `1.2.3`
5. **autoupdate 中的 URL**：tag 部分用 `v$version`（如果 tag 带 v），文件名部分用 `$version`（单版本、每版本独立 release 的情形）。**多版本共用一个 release 的情形见规则 15**
6. **autoupdate 不需要 hash 规则**：hash 由 **API digest（免下载，见规则 8）**或自有脚本（`myscoop-update.py --all`）计算；Scoop 侧 `@版本` 安装也走 GitHub Mode digest。实测 bucket 中 **0 个清单**使用 `autoupdate.hash`——旧指引（`$url.sha256` / `checksums.txt`+`$baseurl` / `checkver -u`）已废弃：流程不再调用 Scoop 的 checkver 工具
7. **description 用英文（限本地维护 manifest）**，保持国际通用性；**第三方官方保持上游原样**（上游为中文则保留，如 kazumi），见规则 10
8. **Hash 优先使用 GitHub API digest**：`curl -s api.github.com/repos/{o}/{r}/releases/latest` 直接读取 asset 的 `digest: sha256:xxx`，无需下载。仅 API 不可用时才下载计算
9. **manifest 提交前必须验证**，确保 scoop 能正确解析
10. **Release 命名规范（本地维护 manifest）**：**包名（文件名）必须用英文**（中文会导致 URL 下载失败）；**标题必须中英结合**（如"压缩工具 Bandizip 6.18"）；**描述必须纯中文**。本地维护 manifest 中 `description` 用英文，`shortcuts` 名称用中文。**第三方官方 manifest 不需要处理此规则**，保持上游原样不动。
11. **禁止敏感字样**：git commit 信息、Release 标题/描述、manifest description、README 等所有对外文本**不得出现"破解"等敏感字样**。涉及此类版本时用中性词替代（如"汉化版"、"精简优化版"、"便携版"）。
12. **每次制作/更新完成后**，提交前必须同步更新 `README.md`、`.claude/skills-myscoop/progress.md`（项目进展，含收录总数/版本）和 SKILL.md。
13. **每次提交完成后**，运行 `git log --oneline --decorate --graph --decorate-refs-exclude=refs/tags/*`，将完整输出更新到 `progress.md` 的"提交历史"章节。**必须排除标签装饰**——95 个 release 锚点标签全指向同一快照提交，不排除时该行可达数千字符（实测最长 1759 字符 → 排除后 123）
14. **下载方式优先用 `curl.exe -L`**：Windows 系统自带 `C:\Windows\System32\curl.exe`（Win10 1803+），无需安装、无需额外工具。下载文件一律使用：
    ```powershell
    curl.exe -L -o "文件名" "下载地址"
    ```
    - **必须写 `curl.exe`**（不能写 `curl`）：PowerShell 中 `curl` 是 `Invoke-WebRequest` 的别名，行为不同、不支持 `-L -o` 参数
    - `-L` 必须带：自动跟随重定向（aka.ms / GitHub / lanzou 等短链都会 302）
    - `-o` 指定本地保存文件名，保持文件名与 Release 包名一致（英文）
    - 下载完成后用 `certutil -hashfile 文件 SHA256` 计算哈希（同为系统自带）
    - 仅在 curl.exe 不可用时（如旧版系统）才退化为其他下载方式
    - **GitHub release 资产可经镜像加速**：下载慢/失败时用镜像前缀拼接（如 `https://hk.gh-proxy.org/https://github.com/…`；列表见 `config.json` 的 `aria2-mirrors`，与脚本 / `download.ps1` 同一套机制）。只认"release 资产代理"型镜像（写法只有"镜像前缀 + 完整 URL"一种），失败自动回退直连
15. **多版本软件资产（自托管）**：同一软件需保留多个历史版本时，**用一个 release（固定 tag）下挂多个资产**（文件名含版本号区分，如 `sublime-text-4200-x64.zip`、`sublime-text-4207-x64.zip`），**不要**每版本各建一个 release。
    - manifest 的 `version` 固定为**默认（最新）版本**；`url`/`hash` 字段**硬编码默认版本的具体地址**，**不要**在 `url` 里写 `$version`——Scoop 普通安装不会替换它，会直接 404
    - `autoupdate.url` 中 **tag 固定**，仅文件名部分用 `$version` 模板（供 Scoop 动态生成其他版本）
    - 安装默认版：`scoop install myscoop/<app>`；指定版本：`scoop install myscoop/<app>@<版本>`（触发 autoupdate 即时生成用户 manifest，hash 自动用 GitHub digest：`7218ed7e... using Github Mode`）；切换已装版本：`scoop reset myscoop/<app>@<版本>`
    - 搜索工具（`scoop search` / `scoop-search`）只显示 manifest 的默认版本，`@版本` 备份在运行时才生成、搜索不可见——必须在 README 标注多版本及 `@版本` 用法，否则用户不知道还存在其他版本
    - 示例：Sublime Text（`sublime-text.json`，release `vSublimeText` 下挂 4200 / 4207 两个资产）
16. **改动文件必须全部提交推送**：任务中凡**内容发生改动的需提交文件**（manifest、README.md、progress.md、SKILL.md、LICENSE 等仓库内跟踪文件）一律 `git add` + `git commit` + `git push` 提交推送，**不得遗留未提交改动**；即使该改动与本任务无关（如历史遗留的各种文件改动），只要其内容已变也一并提交推送。未跟踪文件（如 portable zip 等发布资产、临时文件）不在此列。
17. **用户给出仓库链接时必须用脚本操作**：用户要求收录并提供 GitHub/Gitee **仓库链接**时（如 `https://github.com/NanmiCoder/cc-haha.git`、`https://gitee.com/fasterthanlight/automatic_clicker_2.git`，或 `https://github.com/owner/repo --name reponame` 指定应用名），**必须**使用 `python3 myscoop-update.py --add <链接> [--name 应用名]` 完成操作，**不得**绕过脚本手动 curl 查询 + 手写 manifest。脚本自动完成仓库信息获取、Windows 资产打分排序、架构检测、manifest 生成与 autoupdate 模板，产物为 `bucket/{应用名}.json`；仅当链接是**直接下载链接/网页链接**（非仓库链接）时才走手动流程。
    - **`--add` 增强参数**：
      - `--more`：主程序 + cudart 运行时配对合并收录（同架构同 CUDA 版本成对生成 url/hash 数组，Scoop 解压合并到同一目录；同架构多 CUDA 版本取最高，如 13.3 > 12.4）
      - `--dl`：生成 json 后**必须下载**（清空 API digest 强制实测下载重算 hash）自动探测补全——zip/7z 列 exe 交互选主程序（`--select 编号|exe名` 免交互）；exe（portable/setup 统一）Inno/NSIS 解包探测内部主程序并自动补 pre_install；msi 实测下载回填 hash；多架构自动下载 64bit 主架构；不带此参数时行为与旧版完全一致
18. **README 软件表必须与 bucket/ 全量对齐（缺一不可）**：每次新增/更新 manifest 后，提交前必须核对 README 两张表（第三方官方 + 本地维护）**行数之和 = `bucket/` 清单总数**；缺漏的清单**必须补进对应表**（最新收录置顶 + 全表重新编号），总数计数（收录总数/第三方数/本地数）同步修正——任何已入库 manifest 不得在 README 表中缺席（教训：rayburst.json 入库后 README 漏收，实测缺 1 行）。
19. **自动更新资产守卫与配对资产支持**：`myscoop-update.py` 更新单个第三方清单时的三道防线——
    - **预检回退**：`/releases/latest` 返回的 release 若**无可下载的 Windows 资产**（典型：monorepo/changesets 子包发布产生的 `@scope/pkg@x.y.z` 噪音 tag，其 `assets` 为空），自动在 releases 列表中回退到**最近的、带 Windows 资产的** release（兼顾平台过滤）；仍找不到则跳过不更新。
    - **全架构失败不写入**：架构分支中若**所有架构都未匹配到任何资产**，直接 `return None` 跳过，不写入文件——防止"空架构 → 规则③删架构块 → 写入垃圾 version"把整份清单改坏。
    - **配对资产（`--more` 数组型 url/hash）**：`update_manifest`/`heal_url_drift` 对数组型 url/hash 走**独立 `isinstance(..., list)` 分支**，由 `_update_pair_block` 逐项处理（`$version` 替换 → `match_asset` → 回写同下标 url/hash）；cudart 项名不含版本号，**强制精确匹配**防跨 CUDA 版本误配；配对 tag 内嵌版本、同版本无 `+N` 漂移，故不做 drift 处理。标量清单走原路径、行为字节级不变（回归测试 `tools/test_pair_update.py`）。背景：`prllama.json`（llama.cpp Prism fork 的 `--more` 配对）曾因数组型 url 使 nightly `--all` 抛 `'list' object has no attribute 'split'` 并被静默吞掉、长期不更新。
    - **`--add` 收录预检（与更新共用 `pick_effective_release`）**：收录新清单时只在 **非 draft/untagged 且含可下载 Windows 资产**的 release 里取**最新**一个——**只按"资产"判定，不看 prerelease/rc**（上游常把发布标成预发布但资产完整；且最新版可能恰是**零资产的空 release**，需往下探到最近一个带 Windows 资产的：如 `kvmem-llama.cpp` 的 `v0.17.0` 为空 → 自动取 `v0.16.0-rc3-prism.3`）。完全没有带 Windows 资产的 release → 打印**候选表**（tag/预发布?/win资产数）后跳过、**不写文件**。archived/fork 仓库默认**警告**（`--allow-archived` 静音）。直链/模板入口（`--add 直链`、下载页、`--from`、`--fill-bin`）无 release 列表可选，只做预发布**提示**、不阻断（回归测试 `tools/test_effective_release.py`）。
    - 背景：`CherryHQ/cherry-studio` 的 `latest` 长期指向子包噪音 tag `@cherrystudio/remote-transport@0.1.1`（assets 为空），曾把 `cherry.json` 的 2.1.3 双架构块整体删成空 `autoupdate.architecture`（提交 8134b2a）。
20. **收录质量与一致性护栏**：
    - **资产筛选**：`is_windows_asset` 排除源码包（`-source`/`-src` 独立段）、脚本（`.ps1/.sh/.bat/.cmd/.py` 等）、校验与元数据；generic 兜底仅限"可安装包"——防源码包被规则②兜底进缺失架构（教训：`kvllama` 的 `-source.zip` 曾被塞进 32bit/arm64）。`description` 为 null 时回退为 **`<仓库名> - from github`**（实测实现 `f"{repo} - from {platform}"`，如 `TaskbarPopup - from github`）。
    - **"隐身"的 macOS/Linux 资产排除（`foreign_platform_assets`，两条规则叠加）**：① 权威——release 含 `latest-mac.yml`/`latest-linux.yml`（electron-builder 平台清单）时解析其列出的文件名排除；② 启发式——与同名 `.dmg` 成对的 `.zip`（去扩展名后相同）视为 macOS。接入 `--add` 候选筛选 + `_release_has_windows_asset` 资产守卫两个判断点（后者防"只发 mac 包"的 release 被误判为有 Windows 资产）。教训：`freellmapi` 的 `-x64.zip`/`-arm64.zip` 实为 macOS 包（名字无 mac 标记）被当 Windows 资产选走 → `--dl` 探测"未发现 exe"（里面是 .app）、真 Windows 包 `-win.zip` 反被通用兜底塞进 32bit 槽位。识别信号：electron-builder 的 mac zip 与 .dmg 同名成对、且列在 latest-mac.yml。
    - **便携资产不做 installer 模式（`_is_portable_asset`）**：`--dl` 走 NSIS 分支时，若**资产名明示 portable**（`-portable`/`_portable` 独立段，如 `Xtranslate-portable.exe`），即使描述命中"输入法/驱动/右键菜单"等注册型关键词（`needs_registration`）也**不套 `installer` 模式**，改走 `NSIS_PRE_INSTALL`（7z 解包 `app-*.7z` 到 `$dir`）。原因：installer 模式会让 Scoop 把**便携 exe 当安装器执行**（`/S /D=$dir` 不被识别）→ **程序被直接启动**、而 `$dir` 里没有 `bin` 指向的文件 → 建 shim 失败（教训：`xtranslate` 上游改发 `Xtranslate-portable.exe` 后，`--add --dl` 误套 installer 模式；此前本地维护的 zip 版无 installer 块故正常）。判据只认"名字里的 portable 段"，不误伤 `myportableapp.exe` 这类词中匹配。
    - **installer 模式卸载脚本三级回退 + 自管理式安装器（自动判定 / `--select 0`）**：`post_uninstall` 三级回退——① `$dir\unins*.exe` ② **注册表 `Uninstall` 键搜索**（`InstallLocation`/`InstallBaseLocation`/`DisplayIcon` 含应用名 → 定位 `unins*.exe` RunAs 运行；`unins*` 同时覆盖 Inno 的 `unins000.exe` 与 NSIS 的 `uninstall.exe`）③ 找不到则打印提示（防静默空转）。**自管理式安装器自动判定**：`probe_nsis_exes` 检测 NSIS 载荷含 `*installer-helper.exe` 时返回标记 → 自动**不建 bin/shortcuts**（免提示）+ 生成 `self_managing_installer_fields` 的 **script 形态**（`RunAs` 提权 + `/D=$persist_dir\<应用名>`——persist 下**全新稳定**目录；安装器尊重 `/D` 后指向**已存在**目录会直接 exit 1，Scoop args 形态的 `/D=$dir`（已存在且含安装器副本）正是 zhiyiime 1.4.0 安装失败根因，实测 exit 1/1.1s vs script 形态通过）。手动场景探针处仍可输入 **`0`**（`--select 0` 免交互，zip 路径同样支持）——**三层防占位回填**：清模板占位 + `merge_existing_manifest(drop=…)` 阻止旧占位合并 + `_bin_skipped` 标记阻止 `--dl` finally 恢复（否则占位 bin=安装器 exe 会在安装器自删后建 shim 报 File doesn't exist）。教训：`Uninstall\<AppName>` 键**仅成功安装后写入**（曾据失败安装误判"网友卸载脚本不成立"）；`Start-Process -Wait` 等**整个进程树**——安装器启动的常驻服务会让它"假挂起"（脚本里用 `$p.WaitForExit()` 只等直接进程）；**`/D` 目标必须装前清空**（2026-10-12 补）——script 形态只解决**首次安装**，**更新/重装**时 `/D=$persist_dir\<应用名>` 已存在（上次安装残留）→ 安装器照样 exit 1（症状：`scoop update <app>` 每次必失败、卸载后重装也失败）→ 清单须在装前 `if (Test-Path "$persist_dir\<应用名>") { Remove-Item "$persist_dir\<应用名>" -Recurse -Force }`（persist 只装程序文件、用户配置在 `%USERPROFILE%\zhiyi`，删除安全；重装由安装器重建）。**占用时改名绕过**：残留目录里的 TSF/资源 DLL 常被 explorer 等进程加载 → `Remove-Item` 报 Access denied（**管理员也删不掉**：文件锁而非权限）→ 脚本须「先删；删不掉则 `Rename-Item` 成 `<app>.busy-<时间戳>`」（Windows 允许重命名正在使用的 DLL 所在目录，实测通过），装完再清残留。**升级先停服务**（更彻底，参考 zhiyuime.json）：清理前 ① 调旧版 `*-installer-helper.exe force-stop-server`（注册表 InstallLocation 下找，没有则跳过）② 兜底 `Get-Process | Where Path -like "$persist_dir\*" | Stop-Process -Force`（按路径杀进程，通用，不依赖进程名/键名）③ sleep 800ms——停服务后多数可直接删（rename 只作兜底）；`post_uninstall` 同样先停服务、注册表搜索含 **HKCU**；装后校验 InstallLocation。自管理式安装器收录时（`--add --dl`）由生成器默认带上这套步骤。
    - **校验和文件的"其他写法"也要排除**：原来的后缀匹配只覆盖 `.sum`/`.sha256`/`.sig`，`*.SHA256SUMS`（点后是 `SHA256SUMS`）会漏——且带 `x64` 时还能拿 +2 分，若 release 只发校验文件和 mac/linux 包就会被当成主资产选走。现用正则统一排除 `\.(?:sha\d{0,3}sums?|md5sums?|checksums?|digests?|sums?)$`（大小写不敏感；教训：`vtracer` 的 `VTracer_1.0.0-alpha.4_x64.SHA256SUMS` 曾进候选，实测修复后 19 个资产只剩真包与安装器）。
    - **一致性校验 `--check`**：校验 README 两表行数之和 == `bucket/` 清单数、逐条一一对应、`progress.md` 计数一致，**外加表格结构**——数据行必须**紧随分隔行之后**（表头→分隔行→数据行）、序号必须 **1..N 连续**；任一不符**非零退出**。已挂 CI（`.github/workflows/auto-update.yml`，异常不阻断提交推送，但在末尾让 job 变红）。结构校验补的是旧盲点：只数行数时，"新行被插到表头之前"（行数对得上但表已破）与"序号 `| 0 |`"都曾被漏过（`_parse_readme_table`，回归测试 `tools/test_check_struct.py`）。
    - **`--all` 异常可见**：逐文件异常打印 traceback 并汇总，末尾非零退出（修掉"异常被 `except Exception` 静默吞掉"）。
    - **重复来源检测**：`--add` 时若同一来源已存在于其它清单 → 警告（防重复收录 / 上游改名）。扫描 `checkver.github`、`checkver.url`（含 `api.github.com/repos/o/r` 的 API 形式，会先归一掉 `/repos/` 段）与 `homepage` 三处。
    - **`checkver.tag_regex`（GitHub 分支的可选 tag 过滤 —— 首选方案）**：给 `{"github": …}` 再加一个 `tag_regex`，即在 releases 列表里**按 tag 形态选 release**（可含 prerelease），**正则带捕获组时版本取该组**（如 `^aivault-v([\d.]+)$` → `0.3.0`，顺带去掉产品前缀）。三类场景都用它：① **多产品共仓**（`aivault-v*` / `ergemd-v*`，避免 `/releases/latest` 被别的产品抢走版本）② **tag 命名特殊或方案变更**（`windows-v*` → `v*`，旧模板 `windows-v$version` 实测 404）③ **要跟 beta/rc**（`^v([\d.]+(?:-(?:beta|rc)\.\d+)?)$`）。**仍走 GitHub 分支 → 保留 API digest 免下载与资产匹配**（优于退到"文本正则分支"下载算 hash：qingjian 133MB / updist 7MB）。**tag_regex 分支同样有资产守卫**：最新匹配 tag 无 Windows 资产（如空 release）时回退到下一个"匹配 tag 且有资产"的 release，与常规分支对称。已迁移：`updist`、`qingjian`、`kvninfer`。
    - **前缀重选（`repick_by_prefix`，第三重资产匹配）**：资产名含**每版变化的非数字标记**（如构建 sha：`…-ui-938c2f1.zip` → `…-ui-ae48ec0.zip`）时，数字归一化匹配失效（字母段不同）——在"模板匹配 + 旧 URL 回退"都失败后按**公共前缀最长**重选，并**刷新 autoupdate 模板里的文件名**（`refresh_filename_in_template`，模板保活、Scoop 客户端不 404）。护栏（全满足才采用）：仅同扩展名家族 Windows 资产 + 前缀 **≥12 字符且止于分隔符 `-_./`** + **唯一最优**（严格大于次优）+ **架构判定一致**（防 x64→arm64 误切）。实测：`kvninfer` sha 漂移自动重选 rtx40 资产 ✓；`anclicker` 上游改名（`-windows-x64`→`-Portable`，多候选平手/平台过滤）被**正确拒绝** → 需人工改模板（安全优先）。教训：`kvllama` 上游拆双产品线（`-llamacpp-rc*`/`-ninfer-rc*` 混仓）+ 资产名去版本号改挂 sha → 仅加 `tag_regex` 不够，需前缀重选兜底。
    - **文本正则分支（`{"url": …, "regex": …}`）只在"包不在 GitHub Release"时用**：如 `dsh`（包在 download.deepseek.com，**根本不存在 API digest**）。它把 checkver url 当纯文本取版本，**hash 只能靠下载计算**；若上游在 GitHub 有 release，优先用上面的 `tag_regex`。
    - 教训：`updist` 的版本曾被写成 `aivault-v0.3.0`（tag 前缀未剥离）→ 模板代入后 URL 不存在 → 回退分支靠数字归一化命中新资产 → 被 `handle_build_drift` 误判为"构建号漂移" → `sync_build_asset` 删除 `autoupdate`；改用 `tag_regex` 后版本直接得 `0.3.0`，主匹配精确命中，模板保得住。
    - **API 健壮性**：`fetch_json` 支持 `GH_TOKEN`/`GITHUB_TOKEN`（GitHub 配额 60→5000/时）并对 429/5xx 与网络错误退避重试；`arch_url_hash` 支持数组型 url（配对清单取主资产，修 `--fill-bin` 对 prllama 这类清单崩溃）。
    - **GPU 资产优先级（`score_asset`）**：NVIDIA 通用(+8) > 指定 CUDA(+6) > 通用包(0) > **非 N 卡专用(-4：AMD HIP / ROCm / Radeon)**。非 N 卡专用构建降级到通用包之下——历史案例（清单已不在 bucket，不可复现）：`Strata` 的 `strata-windows-x64-hip.zip` 曾因名字不含 GPU 关键词而与通用包同为 7 分、平手后被顺序选中（非 N 卡包反而优先）。仅当上游只发非 N 卡包时才会选中它（降级≠排除）。
    - **CLI / 裸二进制降级（`score_asset`，-20）**：名字含独立段 `cli`/`msvc`/`gnu`（`(?:^|[-_.])(?:cli|msvc|gnu)(?:[-_.]|$)`）的资产**降到安装器之后**（-20 低于 installer 档 -10）——GUI 应用常同时发 CLI 包与安装器，CLI/裸二进制不是桌面应用的替代品。教训：`bdl` 曾选中 `bdl-cli-0.8.4-windows-x64.zip`、`vtracer` 曾选中 `vtracer-x86_64-pc-windows-msvc.zip`，把 GUI 应用装成了命令行工具。降级≠排除：上游只发 CLI 包时仍会选中（全 bucket 扫描仅 `moonup` 唯一候选、`beellama-cpp` 的 `bin` 字段命中，均无功能影响）。
    - **源码包（拼音标记）降级（`score_asset`，-20）**：名字含独立段 `daima`/`yuanma`（`(?:^|[-_.])(?:daima|yuanma)(?:[-_.]|$)`，大小写不敏感）的资产**降到 CLI 档**——中文项目常用拼音命名源码包（与 `-source`/`-src` 同义），不是可安装的 Windows 包。**只降级不排除**（与 `is_windows_asset` 对 `src`/`source` 的排除不同：上游仅发源码包时仍可兜底选中）。教训：`anclicker` 的 `AnClicker-v1.5.2-win-DaiMa.zip` 与 `AnClicker-v1.5.2-win.zip` 同为 5 分，平手后按列表顺序被选中（源码包反被优先）；回归测试 `tools/test_guards.py` 6b 段。
    - **静态 latest 直链 + 文本正则 checkver**：上游只发**免版本别名**、且安装包**不在 GitHub Release** 时（如 `dsh`：包在 `download.deepseek.com/.../dsh-latest-windows-x64.exe`，版本取自 `deepseek-ai/deepseek-harness` 的 release tag）——`checkver` 用 `url`(接口/页面)+`regex` 取版本；**显式 `url`+`regex` 优先走"文本正则分支"**（即使 url 指向 GitHub API，也不走仓库 release 分支，因为 Release 无资产）；`autoupdate.url` 写**静态直链**（无 `$version`），版本变化时**原样下载重算 hash，内容未变则不提升版本**（防"幽灵更新"）。`fetch_text` 与 `fetch_json` 一样只在 GitHub 官方 API 上附带 token（回归测试 `tools/test_static_au.py`）。
    - **NSIS 双层探测修复（`probe_nsis_exes`）**：**只要存在 `app-*.7z` 就二次解包，并只用内层 exe 作候选**（内层为空则留空、不用外层）——因为配套的 `pre_install` 会把 `app-*.7z` 解到 `$dir` 并丢弃外层，外层 exe 安装后并不存在；同时排除助手 exe（`7z/7za/uninstall/updater/vc_redist/crashpad` 等）并**优先取根级 exe**（滤掉 `resources/` 下的依赖）。教训：`dsh`（DeepSeek Harness）安装器自带 7z 助手 `dsh-7za.exe` 被误当主程序 → 装后该文件已被删 → 建 shim 失败；修复后实测得到单候选 `DeepSeek Harness.exe`。
21. **Scoop 库补丁的版本耦合与多基线分发**：仓库三件套（`manifest.ps1` bucketlist 优先级 / `download.ps1` 镜像加速 / `config.json`）注入 Scoop 本体——两个 `.ps1` 用**软链接**（`git pull` 即生效），`config.json` 用**镜像拷贝**（真实文件：Scoop 自身会重写 config.json——`scoop config` 写入、更新时写 `last_update`——会把软链接删掉重建为普通文件，故每次运行 symlink.bat 重新拷贝同步）；**补丁与 Scoop 版本强耦合**——Scoop 大版本更新会改这两个文件的内部结构，旧补丁直接失效（教训：v0.6.0 把 `Get-Manifest` 的桶遍历抽到新函数 `Find-AppBucket`、`$buckets` 变量消失，v0.5.3 基线的 bucketlist 补丁整段失效；`download.ps1` 镜像补丁 3 处插入点则未变、可原样迁移）。
    - **多基线（数据驱动）**：仓库根 = **最新 Scoop 基线**（版本号记录在 `patches\baseline.txt`）；`patches\<版本>\` = 该版本冻结补丁（现 `patches\v0.5.3\`）。`symlink.bat` 用 `git describe --tags --abbrev=0` 读 Scoop 版本后分发：版本==基线 → 根；`patches\<版本>\` 存在 → 专用补丁；否则 → 根 + 警告（Scoop 比补丁新，提示更新仓库）；git 不可用/无标签 → 根 + 警告。**已废弃特征嗅探判据**（`findstr Get-PEMachine` / 更早的 `buckets.ps1`）——判据函数每个版本都要重新研究，且 `buckets.ps1` 在 v0.5.3 也存在曾致误判；版本号匹配无需研究。
    - **升级流程（symlink.bat 零改动）**：Scoop 大版本更新后 → ① 当前根两个补丁复制到 `patches\<旧基线>\` 冻结 ② 用新官方文件重建根补丁（最小插入：只保留 `# ========== …补丁开始/结束 ==========` 标记段 + 调用点替换，**不要把旧版整个函数搬过来**）③ 改 `patches\baseline.txt` 为新版本号 → 实跑 symlink.bat 验证（含沙盒分支测试）→ 更新 README/progress/SKILL。
    - **大版本还会改文件命名，读安装信息的脚本要兼容新旧名**：v0.6.0 把 `install.json` 改名 `scoop-install.json`（旧文件在应用更新时被删）。教训：`智能模式Scoop(3).ps1` 的桶名匹配只读旧名 → 升级后更新过的应用丢失桶前缀。现改为优先用 `scoop export` 的 `Source` 字段（校验桶名，排除 `<auto-generated>`），文件读取仅作回退。
    - **编码硬要求**：补丁 `.ps1` = **UTF-8 带 BOM** + CRLF（PS 5.1 无 BOM 按 GBK 读 → 中文注释乱码）；`symlink.bat` = **UTF-8 无 BOM** + CRLF + `chcp 65001`（bat 加 BOM 使首行 `@echo off` 失效）。验证低版本分支用**沙盒脚本**（把判据路径与目标路径替换为临时目录后运行，不触碰真实 Scoop）。
22. **README 第三方表跳转链接必须指向"引用项目地址"**：第三方官方表每行的软件名链接必须是**清单实际引用的项目仓库**（`checkver.github` → `https://github.com/<owner>/<repo>`），**不要用官网/产品页/文档站**（反例：`ccswitch.io`、`kazumi.app`、`switchhosts.app`、`moonup.csu.moe`；`BongoCat` 曾误指 `ayangweb/Awesome-BongoCat` 文档仓而非引用的 `ayangweb/BongoCat`）。**例外**：无 GitHub 仓库的官方直链/站点型（`dsh`→deepseek.com、`winsdk`→Microsoft Learn、`pixpin`→官网）保持其官网/项目页（`fileconv`/`keyviz` 等本就指向其仓库的也不动）。**审计方法**：解析每行 `[名](链接)` 与对应清单的 `checkver.github` 逐一比对（2026-10-12 全表审计：54 行 → 35 一致 / 14 修正 / 5 例外）。
