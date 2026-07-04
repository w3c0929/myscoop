---
name: myscoop
description: 将 GitHub 上的 Windows 软件收录到 myscoop bucket。分析目标项目的 release 资产，选择合适的安装方式，生成 manifest 并验证。
type: project
---

# Scoop Manifest 制作技能

## 触发条件

当用户说"添加这个软件到 myscoop"、"收录"、"把 xxx 加到 bucket"等，或给出一个 GitHub 仓库链接时触发。

## 执行流程

### 第一步：信息收集（并行请求）

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
# 从 {app} 内打包
cd _output/{app} && 7z a -tzip ../../app-portable.zip * -r -mx9
certutil -hashfile ../../app-portable.zip SHA256
```

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

文件名规则：**小写 + 连字符**，如 `contextmenumgr-plus.json`、`windowsclear.json`

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

# 自动更新全部
python3 myscoop-update.py --all

# 提交
git add bucket/ && git commit -m "批量更新第三方软件" && git push
```

**原理**：GitHub Release API 返回的每个 asset 包含 `digest: sha256:xxx`，脚本直接读取，无需下载文件。

## 关键规则

1. **永远优先 portable/zip**，避免使用安装包
2. **优先 self-contained**（自带运行时），少用 framework-dependent（需额外依赖）
3. **Hash 格式固定**：`sha256:xxxx`（全小写）
4. **版本号去 v 前缀**：tag `v1.2.3` → version `1.2.3`
5. **autoupdate 中的 URL**：tag 部分用 `v$version`（如果 tag 带 v），文件名部分用 `$version`
6. **autoupdate hash 规则**：**不要用 `$url.sha256`**（大部分项目不提供 `.sha256` 文件）。不写 hash 规则时 `checkver -u` 会自动下载计算。如果项目提供 `checksums.txt`，用 `"hash": { "url": "$baseurl/checksums.txt" }` 放在 autoupdate 顶层
7. **description 用英文**，保持国际通用性
8. **Hash 优先使用 GitHub API digest**：`curl -s api.github.com/repos/{o}/{r}/releases/latest` 直接读取 asset 的 `digest: sha256:xxx`，无需下载。仅 API 不可用时才下载计算
9. **manifest 提交前必须验证**，确保 scoop 能正确解析
10. **Release 命名规范（本地维护 manifest）**：**包名（文件名）必须用英文**（中文会导致 URL 下载失败）；**标题必须中英结合**（如"压缩工具 Bandizip 6.18"）；**描述必须纯中文**。本地维护 manifest 中 `description` 用英文，`shortcuts` 名称用中文。**第三方官方 manifest 不需要处理此规则**，保持上游原样不动。
