# myscoop 项目进展

## 项目概述

个人 Scoop Bucket 仓库，收集 Windows 软件制作便携安装包。

```powershell
scoop bucket add myscoop https://github.com/w3c0929/myscoop.git
```

GitHub: https://github.com/w3c0929/myscoop

## 当前状态（截至 2026-07-09）

- **收录软件总数**: 100 款
- **本地维护（自托管 Release）**: 82 款
- **第三方官方（引用原项目 Release）**: 18 款

不包含上下文提到的草稿软件。

## 核心规则

1. **Release 命名规范**：包名（文件名）必须英文 → 标题中英结合 → 描述纯中文
2. **git commit 信息必须用中文**
3. **收录新软件后，提交前必须同步更新 README.md 和 SKILL.md**
4. **Hash 获取优先使用 GitHub API**：GitHub Release API 返回的每个 asset 包含 `digest: sha256:xxx` 字段，可直接读取无需下载文件。仅在 API 不可用时才下载计算。

## 标准处理流程

### 模式 1：官方 portable zip/7z
- 直接引用官方 GitHub Release URL
- 设置 checkver + autoupdate
- 示例：contextmenumgr-plus, mykeymap, litemonitor, amcfy-music, floral-notepaper

### 模式 2：单 exe / zip 便携（自托管）
- 本地文件上传到 GitHub Release
- 示例：windowsclear, tinytask, 360bwtest, btsou, hibituninstaller

### 模式 5：安装器解包/静默安装 → 自托管
- NSIS: `7z l file.exe | grep "Type = 7z"` → 7z x 直接提取
- Inno Setup: innounp 解包 或 /VERYSILENT 静默安装
- MSI: lessmsi 解包 或 Install-Tickeys 类直接上传
- 示例：uninstalltool, bcompare, termius, 2345pic, gstarcad

### 模式 6：单 exe 手动安装
- exe 直传 GitHub Release，post_install 自动启动
- 不设 bin/shortcuts/checkver/autoupdate
- 示例：apollo, iobit, idm, bandizip6, pixpin 等

### 模式 7：MSI 手动安装
- MSI 直引上游 GitHub Release
- Scoop 对 .msi 硬编码自动解包（msiexec /a），无法禁止
- pre_install 从缓存复制 MSI 到 $dir 保存，post_install 自动启动
- Scoop 缓存文件已重命名为 `{app}#{ver}#{hash}.msi`，需用 `{appname}#*.msi` 通配符查找
- 缓存路径通过 `$dir -replace '\\apps\\.*$', '\\cache'` 推导
- 不设 bin/shortcuts/checkver/autoupdate
- 示例：fileconverter

## 常用命令

```bash
# 免下载更新所有第三方软件（推荐）
python3 myscoop-update.py --all

# 获取第三方软件 hash（免下载，从 API digest 读取）
curl -s "https://api.github.com/repos/{owner}/{repo}/releases/latest" | python3 -c "
import sys,json; r=json.load(sys.stdin)
for a in r['assets']:
    print(a['name'], '→', a.get('digest',''))
"

# 计算 hash（本地文件）
certutil -hashfile "file.exe" SHA256 | grep -E "^[a-f0-9]{64}"

# 上传 release
gh release create vTag "file.exe" --title "中文标题 / English" --notes "中文描述。"

# 查看 zip 结构
7z l "file.zip" | head -30

# 检测安装器类型
7z l "Setup.exe" | grep "Type = "

# Inno Setup 解包
innounp -x -d_output "Setup.exe"

# NSIS 静默安装
"Setup.exe" /S /D=path

# Inno Setup 静默安装
"Setup.exe" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR=path

# 验证 manifest
python3 -m json.tool bucket/appname.json
scoop cat myscoop/appname
```

## 新会话启动指南

1. 告诉 AI：`/skills-myscoop` 加载收录技能
2. 提及当前项目路径：`D:\scoop\buckets\myscoop`
3. 上传新软件：把文件放到该目录下，告诉 AI 文件名和类型
4. 阅读 `SKILL.md` 了解完整制作流程
5. 阅读 `README.md` 查看已收录软件列表
