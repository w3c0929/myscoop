---
name: scoop-add
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

#### 情况 A：有 portable .zip（首选）

> 条件：release 中包含 `portable.zip` 或普通 `.zip` 文件（非 Setup.exe）
> 参考：ContextMenuMgr

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

4. **获取 SHA256**：
   - 优先从 release 页面文本中提取（如果作者贴了）
   - 否则下载后 `certutil -hashfile _temp.zip SHA256`

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

#### 情况 D：只有 Setup.exe 安装包（最后手段）

> 条件：release 只有 Setup.exe，没有 portable/zip/msi

1. 先尝试用 7-Zip 直接解压 Setup.exe：

```bash
7z l Setup.exe | head -30
```

2. 如果 7-Zip 能解压 → 参照情况 A 处理
3. 如果不能解压 → 告知用户需要等作者发布 portable 版，或考虑用 `innounp`

#### 情况 E：framework-dependent 额外依赖

如果 zip 内有 `runtimes/` 目录（如 .NET runtime），说明是 framework-dependent：
- 对于 framework-dependent zip，需要在 manifest 中加 `"depends": ["dotnet-sdk"]` 或类似依赖
- 优先推荐用户使用 self-contained 版本

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

## 关键规则

1. **永远优先 portable/zip**，避免使用安装包
2. **优先 self-contained**（自带运行时），少用 framework-dependent（需额外依赖）
3. **Hash 格式固定**：`sha256:xxxx`（全小写）
4. **版本号去 v 前缀**：tag `v1.2.3` → version `1.2.3`
5. **autoupdate 中的 URL**：tag 部分用 `v$version`，文件名部分用 `$version`
6. **description 用英文**，保持国际通用性
7. **不要猜测 hash**，必须从 release 页或下载计算获取
8. **manifest 提交前必须验证**，确保 scoop 能正确解析
