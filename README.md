# myscoop

个人 Scoop Bucket 仓库，收集 GitHub 上的 Windows 软件，支持一键安装和自动更新。

## 快速开始（用户）

### 1. 添加 Bucket

```powershell
scoop bucket add myscoop https://github.com/w3c0929/myscoop.git
```

### 2. 安装软件

```powershell
# 查看可用软件列表
scoop search myscoop

# 安装软件（以 ContextMenuMgr 为例）
scoop install contextmenumgr-plus

# 或指定从 myscoop 安装
scoop install myscoop/contextmenumgr-plus
```

### 3. 更新软件

```powershell
# 更新单个软件
scoop update contextmenumgr-plus

# 更新所有已安装的软件
scoop update *
```

### 4. 卸载

```powershell
scoop uninstall contextmenumgr-plus
```

---

## 维护指南（制作 Manifest）

### 前置条件

- 安装 [Scoop](https://scoop.sh)（Windows 包管理器）
- 一个文本编辑器（VS Code 推荐）
- 7-Zip（查看 zip 内部结构）

### 第一步：分析目标项目

打开目标软件的 GitHub Releases 页面，确认以下信息：

| 关键信息       | 说明                                                              |
| -------------- | ----------------------------------------------------------------- |
| 便携版/安装版  | Scoop 强烈偏好 portable/绿色版（.zip），避免使用安装版（.exe）    |
| 架构支持       | x64 / x86 / arm64，分别对应 64bit / 32bit / arm64                 |
| zip 内部结构   | 解压后是否有顶层目录？主 exe 在哪？                                |
| License        | GitHub 项目主页右侧可查看，或通过 `api.github.com/repos/owner/repo/license` |
| 版本号         | Tag 格式（如 `v1.7.0`），确认 `v` 前缀                            |

**以 ContextMenuMgr 为例：**

```powershell
# 查看 GitHub 项目信息
curl -s "https://api.github.com/repos/PLFJY/ContextMenuMgr" | Select-String -Pattern '"description"|"license"|"homepage"'

# 查看 Release 文件
curl -s "https://api.github.com/repos/PLFJY/ContextMenuMgr/releases/latest" | Select-String -Pattern '"name"|"browser_download_url"'

# 下载并查看 zip 内部结构（关键是确认有没有顶层目录）
curl -L -o temp.zip "https://github.com/owner/repo/releases/download/v1.0/app.zip"
7z l temp.zip
```

**判断 extract_dir（重要）：**

```
# 情况 A：有顶层目录 → 需要设置 extract_dir
app-v1.0/
  ├── app.exe
  └── ...

# 情况 B：扁平结构 → 不需要 extract_dir
app.exe
config.ini
...
```

### 第二步：生成 SHA256

```powershell
# 方式 1：下载后本地计算
curl -L -o temp.zip "<下载链接>"
certutil -hashfile temp.zip SHA256

# 方式 2：如果 release 页面已经贴了 sha256，直接复制使用
```

**Hash 格式**：在 manifest 中写为 `sha256:xxxxxxxx`。

### 第三步：编写 Manifest

在 `bucket/` 目录下创建 JSON 文件，文件名用**小写 + 连字符**命名。完整字段说明见附录。

**极简模板（单架构、无自动更新）：**

```json
{
    "version": "1.0.0",
    "description": "软件一句话描述",
    "homepage": "https://github.com/owner/repo",
    "license": "MIT",
    "url": "https://github.com/owner/repo/releases/download/v1.0.0/app-portable.zip",
    "hash": "sha256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
    "bin": "app.exe",
    "shortcuts": [
        ["app.exe", "App Name"]
    ]
}
```

**完整模板（多架构 + 自动更新）：**

```json
{
    "version": "1.0.0",
    "description": "软件描述",
    "homepage": "https://github.com/owner/repo",
    "license": "MIT",
    "architecture": {
        "64bit": {
            "url": "https://github.com/owner/repo/releases/download/v1.0.0/app-1.0.0-x64-portable.zip",
            "hash": "sha256:xxxx"
        },
        "32bit": {
            "url": "https://github.com/owner/repo/releases/download/v1.0.0/app-1.0.0-x86-portable.zip",
            "hash": "sha256:xxxx"
        },
        "arm64": {
            "url": "https://github.com/owner/repo/releases/download/v1.0.0/app-1.0.0-arm64-portable.zip",
            "hash": "sha256:xxxx"
        }
    },
    "bin": "app.exe",
    "shortcuts": [
        ["app.exe", "App Name"]
    ],
    "checkver": {
        "github": "https://github.com/owner/repo"
    },
    "autoupdate": {
        "architecture": {
            "64bit": {
                "url": "https://github.com/owner/repo/releases/download/v$version/app-$version-x64-portable.zip"
            },
            "32bit": {
                "url": "https://github.com/owner/repo/releases/download/v$version/app-$version-x86-portable.zip"
            },
            "arm64": {
                "url": "https://github.com/owner/repo/releases/download/v$version/app-$version-arm64-portable.zip"
            }
        }
    }
}
```

### 第四步：测试 Manifest

```powershell
# 1. 验证 JSON 格式
scoop checkver <appname>

# 2. 本地安装测试（不提交前先本地验证）
scoop install .\bucket\<appname>.json

# 3. 确认程序可以正常启动
# 如果安装成功，会在 ~\scoop\apps\<appname>\ 下看到文件

# 4. 执行自动检查更新测试
scoop checkver <appname> --update
```

### 第五步：提交到仓库

```bash
git add bucket/<appname>.json
git commit -m "add <appname> manifest"
git push origin main
```

用户只需 `scoop update` 即可获取新 manifest。

---

## 自动更新机制详解

### checkver — 版本检测

`checkver` 定义了如何获取最新版本号。最常用的是 GitHub 模式：

```json
"checkver": {
    "github": "https://github.com/owner/repo"
}
```

这会自动检查 GitHub Releases 的**最新 tag**（自动去掉 `v` 前缀），所以 tag `v1.7.0` 对应的 `$version` 是 `1.7.0`。

**手动指定匹配规则（当 GitHub 默认规则不满足时）：**

```json
"checkver": {
    "url": "https://api.github.com/repos/owner/repo/releases/latest",
    "jsonpath": "$.tag_name",
    "regex": "v([\\d.]+)"
}
```

### autoupdate — 下载地址模板

`autoupdate` 定义新版本发布后，下载 URL 如何拼接。用 `$version` 代替版本号：

```json
"autoupdate": {
    "architecture": {
        "64bit": {
            "url": "https://github.com/owner/repo/releases/download/v$version/app-$version-x64.zip"
        }
    }
}
```

### 更新流程

```
新版本发布 → 用户执行 scoop update → Scoop 运行 checkver 检测新版本
→ 用 autoupdate 模板拼接新 URL → 下载 → 校验 hash → 替换旧版本
```

> **注意**：`autoupdate` 不会自动更新 hash。需要定期运行 `scoop checkver <appname> --update` 来更新 manifest 中的 hash 值并推送到仓库。

### 维护者定期更新步骤

```powershell
# 检查哪些软件有更新
scoop checkver

# 更新特定软件的 manifest（写入新版本号和 hash）
scoop checkver <appname> --update

# 提交更新
git add bucket/<appname>.json
git commit -m "<appname>: update to version x.y.z"
git push origin main
```

---

## 常见问题与技巧

### Q: zip 解压后有顶层目录怎么办？

如果 zip 内部是 `app-v1.0/app.exe` 这种结构，需要加 `extract_dir`：

```json
"url": "...",
"hash": "...",
"extract_dir": "app-v1.0"
```

### Q: 安装版 .exe 没有便携版怎么办？

优先选择方式：
1. 先用 7-Zip 尝试直接解压 setup.exe，有些安装包本身就是自解压包
2. 如果 7-Zip 不行，用 `innounp` 解包 Inno Setup 安装包
3. 实在不行才考虑用安装参数静默安装（不推荐，Scoop 不应静默执行安装包）

### Q: 需要额外依赖怎么办？

```json
"depends": [
    "git",
    "7zip",
    "dotnet-sdk"
]
```

### Q: 需要向 PATH 暴露多个可执行文件？

```json
"bin": [
    "main.exe",
    "cli.exe",
    ["helper.exe", "mytool-helper"]
]
```

> `["helper.exe", "mytool-helper"]` 表示将 `helper.exe` 以别名 `mytool-helper` 加入 PATH。

### Q: 安装后需要额外操作（注册服务/写注册表）？

```json
"post_install": [
    "New-Service -Name 'MyService' -BinaryPathName \"$dir\\service.exe\""
],
"pre_uninstall": [
    "Stop-Service -Name 'MyService' -ErrorAction SilentlyContinue",
    "sc.exe delete MyService"
]
```

### Q: self-contained 还是 framework-dependent？

|                | self-contained        | framework-dependent     |
| -------------- | --------------------- | ----------------------- |
| 文件大小       | 大（~100MB+）         | 小（~5-10MB）           |
| 用户依赖       | 无需安装运行时        | 需预装对应运行时        |
| 推荐场景       | **推荐**，开箱即用    | 用户确认有运行时时使用   |

---

## 附录：Manifest 字段速查

| 字段            | 必须 | 说明                                                               |
| --------------- | ---- | ------------------------------------------------------------------ |
| `version`       | 是   | 软件版本号，与 release tag 一致（去掉 v）                          |
| `description`   | 是   | 一句话描述，建议用英文以保持通用性                                 |
| `homepage`      | 是   | 项目主页 URL                                                       |
| `license`       | 是   | SPDX 标识符（MIT/GPL-3.0/Apache-2.0 等）或带 url 的对象            |
| `url`           | 是   | 下载地址（单架构时放顶层）                                         |
| `hash`          | 是   | SHA256 校验值，格式 `sha256:xxxx`                                  |
| `architecture`  | 否   | 多架构配置，包含 64bit/32bit/arm64 子对象，替代顶层 url/hash       |
| `bin`           | 否   | 暴露到 PATH 的可执行文件，字符串或数组                             |
| `shortcuts`     | 否   | 开始菜单快捷方式，格式 `[["exe", "显示名称"]]`                    |
| `extract_dir`   | 否   | zip 内的子目录名（有顶层目录时设）                                 |
| `depends`       | 否   | 依赖的其他 scoop 包                                                |
| `checkver`      | 否   | 版本检测规则，常用 `"github": "url"`                               |
| `autoupdate`    | 否   | 自动更新 URL 模板，配合 checkver 使用                              |
| `pre_install`   | 否   | 安装前执行的 PowerShell 命令                                       |
| `post_install`  | 否   | 安装后执行的 PowerShell 命令，`$dir` 代表安装目录                  |
| `pre_uninstall` | 否   | 卸载前执行的 PowerShell 命令                                       |
| `persist`       | 否   | 持久化文件/目录（升级时保留），如 `"config.ini"` 或 `["data"]`    |
| `notes`         | 否   | 安装后给用户的提示信息                                             |

### 目录结构约定

```
myscoop/
├── bucket/           ← 所有 manifest JSON 放这里
│   ├── contextmenumgr-plus.json
│   └── your-app.json
├── README.md         ← 这个文件
└── .gitignore        ← 可选
```
