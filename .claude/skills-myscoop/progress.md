# myscoop 项目进展

## 项目概述

个人 Scoop Bucket 仓库，收集 Windows 软件制作便携安装包。

```powershell
scoop bucket add myscoop https://github.com/w3c0929/myscoop.git
```

GitHub: https://github.com/w3c0929/myscoop

## 当前状态（截至 2026-10-10）

- **收录软件总数**: 138 款
- **本地维护（自托管 Release）**: 87 款
- **第三方官方（引用原项目 Release）**: 51 款

## 脚本能力（myscoop-update.py 最新）

- `--add <仓库链接> [--name 应用名]`：仓库模式一键收录（信息/评分/架构/autoupdate 模板自动生成）
  - **`--more`**：主程序 + cudart 运行时配对合并收录——同架构同 CUDA 版本成对生成 url/hash 数组（Scoop 依次解压合并到同一目录），同架构多 CUDA 版本取最高（13.3 > 12.4），cudart 文件名保持写死与 tag 解耦；无配对回退常规流程（示例：prllama / llama.cpp Prism fork）
  - **`--dl`**：生成 json 后**必须下载**（清空 API digest 强制实测下载重算 hash）自动探测补全——zip/7z 列 exe 交互选主程序（`--select 编号|exe名` 免交互，列表去重+编号）；exe（portable/setup 统一）Inno/NSIS 解包探测内部主程序并自动补 pre_install（cherry 实测 102 exe）；msi 实测下载回填 hash；多架构自动下载 64bit 主架构
  - autoupdate 模板：文件名中非语义 tag 子串自动模板化为 `$version`（防下版 404）
  - 资产判定：x86_64/amd64 正确判 64bit（修复含 x86 子串误判），i686/i386 → 32bit；平台裸二进制（.arm/.x86_64/.s390x 等无 .exe 跨平台产物）与无扩展名校验文件（SHA256SUMS）不再混入 Windows 资产
- `--add <直链|下载页|模板>`：直链/下载页/模板新增强（含 Inno/NSIS 探测、--fill-bin URL 模式）
- `--installer-mode`：注册型软件存量清单迁移 installer 模式
- `--all` / 单清单更新：GitHub API digest 免下载更新；CI 每晚 1 点自动执行；**资产守卫**：latest 无可下载 Windows 资产（如 monorepo 子包噪音 tag，assets 为空）时回退 releases 列表取带资产者，全架构匹配失败则跳过不写入
- **配对资产自动更新**（`--more` 生成的数组型 url/hash，如 prllama）：`_update_pair_block` 逐项 `$version` 替换 → `match_asset` → 回写同下标 url/hash；cudart 项（名不含版本）强制精确匹配，防跨 CUDA 版本误配。数组走独立分支，标量清单行为不变（回归测试 `tools/test_pair_update.py`）
- **收录预检（`--add`，与更新共用 `pick_effective_release`）**：只取"非 draft/untagged + 含 Windows 资产"的**最新** release——**只按资产判定，不看 prerelease/rc**；最新版若是零资产空 release 会自动往下探到最近带 Windows 资产的（如 kvllama `v0.17.0` 空 → 取 `v0.16.0-rc3-prism.3`）；全无则打印候选表后跳过、不写文件。archived/fork 默认警告（`--allow-archived` 静音）；直链/`--from`/`--fill-bin` 只提示不阻断（回归测试 `tools/test_effective_release.py`）
- **便携资产不做 installer 模式**（`_is_portable_asset`）：`--dl` 的 NSIS 分支里，资产名明示 portable（`-portable`/`_portable` 段）时，即便描述命中"输入法/驱动"等注册型关键词也不套 `installer` 模式，改走 `NSIS_PRE_INSTALL` 7z 解包——否则 Scoop 把便携 exe 当安装器执行（`/S /D=$dir` 不识别）→ 程序被直接启动、`$dir` 无 bin 目标 → 建 shim 失败（修 `xtranslate`；实测解包产出 `Xtranslate.exe` 可达；回归测试 `tools/test_guards.py`）
- **资产筛选加固**：`is_windows_asset` 排除源码包（`-source`/`-src` 独立段）、脚本（`.ps1/.sh/.bat/.cmd/.py` 等）、校验/元数据；**校验和文件的其他写法**（`*.SHA256SUMS`/`*.sha512sums`/`*.md5sums`/`*.checksums`/`*.digest`/`*.sums`，正则大小写不敏感）也排除——原后缀匹配只覆盖 `.sum`/`.sha256`，`…x64.SHA256SUMS` 会漏且带 x64 时得 +2 分，可能被当成主资产（修 `vtracer`；回归测试 `tools/test_guards.py`）；generic 兜底仅限可安装包（防源码包被兜底进缺失架构）；`description` 为 null 时回退；`--add` 检测同一 checkver 来源重复（防重复收录/上游改名）；`arch_url_hash` 支持数组型 url（配对清单取主资产）
- **一致性校验 `--check`**：校验 README 两表行数之和 == `bucket/` 清单数、逐条一一对应、`progress.md` 计数一致，**外加表格结构**（数据行须紧随分隔行之后、序号须 1..N 连续）；不一致非零退出（已挂 CI）。结构校验补旧盲点：只数行数时"新行插到表头之前"与"序号 | 0 |"都会被漏过（`_parse_readme_table`，回归测试 `tools/test_check_struct.py`）。`--all` 逐文件异常打印 traceback + 汇总并以非零退出码报告（不再静默）；`fetch_json` 支持 `GH_TOKEN`/`GITHUB_TOKEN` 并对 429/5xx 退避重试（回归测试 `tools/test_guards.py`）
- **静态 latest 直链 + 文本正则 checkver**：安装包不在 GitHub Release 且只有免版本别名时（如 dsh），`checkver` 用 `url`+`regex` 取版本（**显式 url+regex 优先走文本分支**，即使 url 是 GitHub API）；`autoupdate.url` 写静态直链，版本变化时原样下载重算 hash、**内容未变不提升版本**（防幽灵更新）；`fetch_text` 支持 GitHub token（回归测试 `tools/test_static_au.py`）
- **NSIS 双层探测修复**：`probe_nsis_exes` 只要存在 `app-*.7z` 就二次解包并**只用内层 exe**（内层为空则留空），排除 7z/卸载/更新器/vc_redist 等助手 exe，并**优先根级 exe**（滤掉 resources 下依赖）——修 `dsh` 把 7z 助手 `dsh-7za.exe` 当主程序导致建 shim 失败（实测该安装器现得到单候选 `DeepSeek Harness.exe`）
- **GPU 资产优先级**：`score_asset` 非 N 卡专用（**HIP/ROCm/Radeon**）**降一级（-4）**，通用 x64 包优先——优先级为 NVIDIA 通用(+8) > 指定 CUDA(+6) > 通用包(0) > 非 N 卡(-4)；降级≠排除，仅当上游只发非 N 卡包时才选中（修 `strata` 选中 `strata-windows-x64-hip.zip`；回归测试 `tools/test_guards.py`）
- **CLI / 裸二进制降级**：`score_asset` 名字含独立段 `cli`/`msvc`/`gnu` 的资产 **-20（低于 installer 档 -10）**，排到安装器之后——GUI 应用常同时发 CLI 包/裸二进制与安装器，前者不是桌面应用的替代品（修 `bdl` 曾选中 `bdl-cli-…zip`、`vtracer` 曾选中 `vtracer-x86_64-pc-windows-msvc.zip` 把 GUI 装成命令行工具）；降级≠排除，全 bucket 扫描仅 `moonup`（唯一候选）与 `beellama-cpp`（`bin` 字段，非资产名）命中，均无功能影响
- **GitHub 下载镜像加速**：`download_to` 对 GitHub release 资产优先走镜像——顺序探测取第一个可达（1KB range + 8s 超时），全部不可达回退原 URL；列表来源：环境变量 `MYSCOOP_GH_MIRRORS` > Scoop config.json 的 `aria2-mirrors`（与 download.ps1 补丁同一套）。**拼接方式仅支持一种**：镜像前缀 + 完整 `https://github.com/…` URL；git 克隆加速器（`gitclone.com` 等，写法 `镜像/github.com/owner/repo`）不代理 release 路径，实测 404/500，勿加。2026-10-10 实测 31 项 → 去重 + 删 5 个死/类别不符镜像 → **24 项按实测速度排序**（前 3：`hk.gh-proxy.org` / `cdn.gh-proxy.com` / `git.yylx.win`，稳定 3.7–5.3 MB/s；中段镜像轮间抖动 6–9 倍，排序仅概率上更优）；测速工具 `tools/mirror_speed.py`（本地专用，可复跑）
- **`checkver.tag_regex`（GitHub 分支可选 tag 过滤，首选）**：`{"github": …}` 再加 `tag_regex` → 在 releases 列表里按 tag 形态选 release（可含 prerelease），**捕获组即版本**（`^aivault-v([\d.]+)$` → `0.3.0`，自动去产品前缀）。覆盖三场景：多产品共仓 / tag 命名特殊或方案变更（`windows-v*`→`v*`）/ 跟 beta·rc（`^v([\d.]+(?:-(?:beta|rc)\.\d+)?)$`）。**仍走 GitHub 分支 → API digest 免下载**（实测 qingjian `0.1.4→0.1.5-beta.1`、updist `0.3.0→0.3.1` 均无 `[下载]` 行、hash 与上游 digest 一致）。已迁移 `updist`/`qingjian`；文本正则分支只在"包不在 GitHub Release"（如 dsh）时用
- **`find_duplicate_source` 增强**：也扫描 `checkver.url` 的 API 形式（归一 `/repos/` 段）——修"改用文本正则后重复来源检测失效"的副作用；`updist` 迁回 `checkver.github` 后该项也恢复

## 核心规则

1. **Release 命名规范**：包名（文件名）必须英文 → 标题中英结合 → 描述纯中文
2. **git commit 信息必须用中文**
3. **每次制作/更新后，提交前必须同步更新 README.md、progress.md（本项目进展）和 SKILL.md**
4. **Hash 获取优先使用 GitHub API**：GitHub Release API 返回的每个 asset 包含 `digest: sha256:xxx` 字段，可直接读取无需下载文件。仅在 API 不可用时才下载计算。
5. **每次提交完成后**，必须运行 `git log --oneline --decorate --graph` 并将完整输出更新到本文件的"提交历史"章节。
6. **多版本软件资产（自托管）**：同一软件需保留多个版本时，用一个 release（固定 tag）下挂多个资产（文件名含版本号区分），不要每版本各建一个 release。manifest 的 `version` 为默认（最新）版本，`url`/`hash` 硬编码默认版具体地址（`url` 里写 `$version` 会导致 Scoop 普通安装 404），`autoupdate.url` 仅文件名用 `$version` 模板。安装默认版 `scoop install myscoop/<app>`；指定版 `scoop install myscoop/<app>@<版本>`（触发 autoupdate 动态生成、GitHub digest 取 hash）；切换 `scoop reset myscoop/<app>@<版本>`。搜索工具只显示默认版，必须同步 README 标注多版本及 `@版本` 用法。示例：Sublime Text（release `vSublimeText` 挂 4200/4207）。详见 SKILL 规则 15。
7. **改动文件必须全部提交推送**：所有内容改动过的需提交文件（含 README.md、progress.md、SKILL.md 及仓库内其他跟踪文件）一律提交推送，不得遗留未提交改动；即使改动与本任务无关（如历史遗留改动）也一并提交。未跟踪文件（发布资产、临时文件）不在此列。
8. **README 软件表必须与 bucket/ 全量对齐**：每次新增/更新 manifest 后，提交前必须核对 README 两张表（第三方官方 + 本地维护）的行数之和等于 `bucket/` 清单总数，**缺漏必须补上**（含记录在 top 且重新编号）；总量计数（收录总数/第三方/本地）同步修正，不允许任何已入库 manifest 在 README 表中缺席。
9. **自动更新资产守卫**：`myscoop-update.py` 更新单清单时，latest release 无可下载 Windows 资产（如 monorepo 子包噪音 tag，assets 为空）→ 自动回退 releases 列表找带资产的 release，仍无则跳过；架构分支所有架构都匹配失败时跳过不写入（防删架构块 + 写垃圾 version 改坏清单）。详见 SKILL 规则 19。

## 标准处理流程

### 模式 1：官方 portable zip/7z
- 直接引用官方 GitHub Release URL
- 设置 checkver + autoupdate
- 示例：cmm-plus, mykeymap, litemonitor, amcfy-music, floral, baulk（多架构 zip 官方 release）

### 模式 2：单 exe / zip 便携（自托管）
- 本地文件上传到 GitHub Release
- 示例：windowsclear, tinytask, 360bwtest, btsou（更新 26.08.26.01）, hibituninstaller, gzh-formatter（单 exe 便携）, bcompare（汉化便携 zip）, easytshark（便携 zip）, switchhosts（便携 zip）

### 模式 5：安装器解包/静默安装 → 自托管
- NSIS: `7z l file.exe | grep "Type = 7z"` → 7z x 直接提取
- Inno Setup: innounp 解包 或 /VERYSILENT 静默安装
- MSI: lessmsi 解包 或 Install-Tickeys 类直接上传
- 示例：uninstalltool, termius, 2345pic, gstarcad

#### 模式 5b：Inno Setup 解包组装完整便携目录（bcompare 汉化版方式）

汉化/破解安装器通常是 Inno Setup，直接解包可得完整程序集，组装便携目录：

```bash
# 1. 检测 Inno Setup（7z 打不开的 exe 用字符串特征确认）
python3 -c "print('Inno' if b'Inno Setup' in open('Setup.exe','rb').read() else 'other')"

# 2. innounp 解包（输出到 {app} 目录 = 完整程序集）
innounp -x -d_output "Setup.exe"

# 3. 组装便携目录（模仿安装器行为，看 install_script.iss 确认）：
#    - 只保留安装器最终输出的文件（无 ,1/,2 后缀变体！）
#    - 复制 64 位主程序为无后缀名：cp "BCompare,2.exe" BCompare.exe
#    - 复制 64 位汉化翻译：cp "BCompare,2.tr" BCompare.tr
#    - 其余 64 位文件同理：7z,2.dll→7z.dll、PdfToText,2.exe→PdfToText.exe 等
#    - 通用文件直接保留（BCClipboard/BComp/BCShellEx/Patch.exe 等）

# 4. 打包 + 计算 hash
7z a -tzip app-portable.zip * -r -mx9
certutil -hashfile app-portable.zip SHA256
```

**关键要点（踩坑教训）**：
- ⚠️ **不要保留 `,1/,2` 后缀变体文件**！它们只是安装器的 32/64 位源文件，安装器只输出无后缀的最终文件。保留会导致目录错乱（bcompare 5.2.5 教训）
- ⚠️ **7z a 到已存在 zip 是追加不是覆盖**！打包前必须删除旧 zip，否则新旧内容混合（bcompare 混合包教训）
- 打包后必须验证：`7z l zip | grep -c ",1\.\|,2\."` 应为 0
- Inno 6.x 可解包；**Inno 7.0+ innounp/innoextract 均不支持**（报 "not supported version"）

**注册/汉化补丁获取**（注册信息常在独立补丁安装器里）：
- 补丁安装器（如 BCompare-5.2.5_汉化补丁.exe）若无法解包，只能**运行 GUI 安装**提取：
  - 运行补丁安装器 → 安装到 BCompare 目录（或临时目录）
  - 从安装目录提取：注册文件（BC5Key.txt）+ 汉化 DLL（version.dll）等
- 最终便携包必须包含：程序文件 + 注册文件（BC5Key.txt）+ 汉化 DLL（version.dll，若存在）
- 示例：bcompare（5.2.5.32528 汉化便携版，21MB：19 文件含 BC5Key.txt + version.dll）

### 模式 6：单 exe 手动安装
- exe 直传 GitHub Release，post_install 自动启动
- 不设 bin/shortcuts/checkver/autoupdate
- 示例：apollo, iobit, idm, bandizip6, hcsstudio, wps, sougoupy, easytshark, windowsappruntime 等

### 模式 7：MSI 手动安装
- MSI 直引上游 GitHub Release
- Scoop 对 .msi 硬编码自动解包（msiexec /a），无法禁止
- pre_install 从缓存复制 MSI 到 $dir 保存，post_install 自动启动
- Scoop 缓存文件已重命名为 `{app}#{ver}#{hash}.msi`，需用 `{appname}#*.msi` 通配符查找
- 缓存路径通过 `$dir -replace '\\apps\\.*$', '\\cache'` 推导
- 不设 bin/shortcuts/checkver/autoupdate
- 示例：fileconv, cfwarp, keyviz

### 模式 8：qlplugin 插件自启动安装
- .qlplugin 文件直引上游 GitHub Release（或自托管）
- post_install 自动打开文件，用户手动确认安装到 QuickLook
- 设置 checkver + autoupdate
- `myscoop-update.py --add` 已支持 .qlplugin 自动生成 post_install
- 示例：qlcad, qloffice, qlgit

### 中文文件名编码问题（重要）

Windows 下 zip 包内中文文件名在 Scoop 解压后会出现编码损坏（乱码），导致 `bin`/`shortcuts` 找不到文件。**解决方案**：用 `installer.script` 在解压后通过通配匹配 exe 并重命名为 ASCII 名称。

```json
"installer": {
    "script": [
        "$exe = Get-ChildItem \"$dir\" -Filter '*-win-portable.exe' | Select-Object -First 1",
        "if ($exe) { Rename-Item -Path $exe.FullName -NewName 'app-name.exe' }"
    ]
},
"bin": "app-name.exe",
"shortcuts": [["app-name.exe", "中文显示名称"]]
```

> `installer.script` 在 Scoop 解压后、shim 创建前执行。示例：btseed（BT种子转磁力链工具）。

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

# 每次本地提交后重建 progress.md 的"提交历史"章节（rebuild_progress.py 位于 tools/，仅本地维护未入库）
python3 tools/rebuild_progress.py && git add .claude/skills-myscoop/progress.md && git commit -m "progress.md 更新提交历史"

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

## 提交历史

每次提交完成后，将 `git log --oneline --decorate --graph` 输出更新到此处：

```
* 748f7d2 (HEAD -> main, origin/main, origin/HEAD) 新增收录 CC Switch 4.0.7（多 AI 编程助手桌面配置切换器，多架构 portable zip 官方 release）：README 第三方表置顶补行并重编号（50→51），progress 计数 137→138
* e4b02ec progress.md 更新提交历史
* 7202d10 镜像列表去重并按实测速度重排：31 项 → 24 项
* dacf399 (tag: vWujin, tag: vWinHex, tag: vWPS26899, tag: vVBA7.0.1590, tag: vVAM1.22, tag: vTickeys1.2.0, tag: vSystemCleaner, tag: vSysHelper3.0, tag: vSublimeText, tag: vStudioOne7.1, tag: vSogouWubi, tag: vRobocopyGUI1.3, tag: vRDI, tag: vPointerStick, tag: vPDFMergeSplit, tag: vPDF24Converter, tag: vNumpadPractice, tag: vMdxBuilder, tag: vKeyCastOW, tag: vGstarCAD2022, tag: vGoogleTranslateChecker, tag: vGoldenDict, tag: vGIFTool, tag: vFolderEncrypt, tag: vEpicPen3.7.31, tag: vDriverGenius9.70, tag: vDnsTools1.2.3, tag: vDisableGamebar, tag: vCutSilence, tag: vBeatEdit2.1, tag: vBOOTICE1.3.4, tag: vAudioRecorder4.2.3, tag: vAnytxt1.3.1952, tag: v9.9.31-qq, tag: v9.7.0, tag: v9.40.1, tag: v9.0, tag: v8.5.2, tag: v8.5.1, tag: v8.2.2.2531, tag: v8.0.28, tag: v6.4.3, tag: v6.18, tag: v6.0.11.0, tag: v5.6.6.174a-hipc, tag: v5.2.5.32528, tag: v5.2.3, tag: v5.0.9.6029-wecom, tag: v5.0.1, tag: v42.3.0, tag: v4.30.1, tag: v4.13-athena, tag: v4.1.11-wechat, tag: v4.0.10, tag: v360bw, tag: v360DriverMaster2.0, tag: v3.9.3.5, tag: v3.7.3, tag: v3.7.2, tag: v3.4.3, tag: v3.3.0, tag: v3.2.3.1, tag: v26.08.26.01, tag: v25.11.12, tag: v2026.6.850.0, tag: v2.4.5-miaomi, tag: v2.4.0, tag: v2.1.2, tag: v2.0-edgeblock, tag: v2.0-beta33-mykeymap, tag: v18.7.11925.98, tag: v16.6.0.4385, tag: v147.0.7703.0, tag: v10.8.0.9683, tag: v1.8.5.0, tag: v1.3.3-video-captioner, tag: v1.3.213.7, tag: v1.3.0.11, tag: v1.2.0, tag: v1.0.9.0, tag: v1.0.9, tag: v1.0.50481.0, tag: v1.0.260708, tag: v1.0.2, tag: v1.0.0.10-dingtalk-downloader, tag: v1.0.0.0, tag: v1.0-wcap, tag: v1.0-waifu2x-caffe, tag: v1.0-pcmaster, tag: v1.0-getdict, tag: v1.0-fps-keeper, tag: v1.0-btseed, tag: v1.0, tag: v0.9.2, tag: v0.4.6) myscoop 快照：137 款 Windows 软件 Scoop 清单（历史重写为单 commit）
```

## 新会话启动指南

1. 告诉 AI：`/skills-myscoop` 加载收录技能
2. 当前项目路径：`E:\09.同步\06.配置\myscoop`
3. 上传新软件：把文件放到该目录下，告诉 AI 文件名和类型
4. 阅读 `SKILL.md` 了解完整制作流程
5. 阅读 `README.md` 查看已收录软件列表
