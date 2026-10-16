# myscoop 项目进展

## 项目概述

个人 Scoop Bucket 仓库，收集 Windows 软件制作便携安装包。

```powershell
scoop bucket add myscoop https://github.com/w3c0929/myscoop.git
```

GitHub: https://github.com/w3c0929/myscoop

## 当前状态（截至 2026-10-15）

- **收录软件总数**: 148 款
- **本地维护（自托管 Release）**: 86 款
- **第三方官方（引用原项目 Release）**: 62 款

## 脚本能力（myscoop-update.py 最新）

- `--add <仓库链接> [--name 应用名]`：仓库模式一键收录（信息/评分/架构/autoupdate 模板自动生成）
  - **`--more`**：主程序 + cudart 运行时配对合并收录——同架构同 CUDA 版本成对生成 url/hash 数组（Scoop 依次解压合并到同一目录），同架构多 CUDA 版本取最高（13.3 > 12.4），cudart 文件名保持写死与 tag 解耦；无配对回退常规流程（示例：prllama / llama.cpp Prism fork）
  - **`--dl`**：生成 json 后**必须下载**（清空 API digest 强制实测下载重算 hash）自动探测补全——zip/7z 列 exe 交互选主程序（`--select 编号|exe名` 免交互，列表去重+编号）；exe（portable/setup 统一）Inno/NSIS 解包探测内部主程序并自动补 pre_install（cherry 实测 102 exe）；msi 实测下载回填 hash；多架构自动下载 64bit 主架构
  - autoupdate 模板：文件名中非语义 tag 子串自动模板化为 `$version`（防下版 404）
  - 资产判定：x86_64/amd64 正确判 64bit（修复含 x86 子串误判），i686/i386 → 32bit；平台裸二进制（.arm/.x86_64/.s390x 等无 .exe 跨平台产物）与无扩展名校验文件（SHA256SUMS）不再混入 Windows 资产
- `--add <直链|下载页|模板>`：直链/下载页/模板新增强（含 Inno/NSIS 探测、--fill-bin URL 模式）
- `--installer-mode`：注册型软件存量清单迁移 installer 模式
- `--all` / 单清单更新：GitHub API digest 免下载更新；CI 每晚 1 点自动执行；**资产守卫**：latest 无可下载 Windows 资产（如 monorepo 子包噪音 tag，assets 为空）时回退 releases 列表取带资产者，全架构匹配失败则跳过不写入
  - **更新后自动同步 README**（2026-10-12，`sync_readme_after_update` 内置）：版本列（第三方表=清单 version）+ 创建列（git 首次提交日期）+ 更新列（**本次真正变更的清单取当天**——随后即提交，与提交日一致；其余取最近提交日期）；幂等、`--dry-run` 不写、异常只警告。原先需单独跑 `tools/sync_readme_versions.py`（CI 用其内联副本），现本地一条 `--all` 到位；与 CI 内联步骤逻辑等价 → **CI 行为不变**（其内联步骤变幂等空操作）。首次实跑修正了 4 处 README 落后（zhiyiime 1.4.2 / anclicker 1.4.9 / bongocat 2.3.0 / kvninfer 创建日）
- **配对资产自动更新**（`--more` 生成的数组型 url/hash，如 prllama）：`_update_pair_block` 逐项 `$version` 替换 → `match_asset` → 回写同下标 url/hash；cudart 项（名不含版本）强制精确匹配，防跨 CUDA 版本误配。数组走独立分支，标量清单行为不变（回归测试 `tools/test_pair_update.py`）
- **收录预检（`--add`，与更新共用 `pick_effective_release`）**：只取"非 draft/untagged + 含 Windows 资产"的**最新** release——**只按资产判定，不看 prerelease/rc**；最新版若是零资产空 release 会自动往下探到最近带 Windows 资产的（如 kvllama `v0.17.0` 空 → 取 `v0.16.0-rc3-prism.3`）；全无则打印候选表后跳过、不写文件。archived/fork 默认警告（`--allow-archived` 静音）；直链/`--from`/`--fill-bin` 只提示不阻断（回归测试 `tools/test_effective_release.py`）
- **便携资产不做 installer 模式**（`_is_portable_asset`）：`--dl` 的 NSIS 分支里，资产名明示 portable（`-portable`/`_portable` 段）时，即便描述命中"输入法/驱动"等注册型关键词也不套 `installer` 模式，改走 `NSIS_PRE_INSTALL` 7z 解包——否则 Scoop 把便携 exe 当安装器执行（`/S /D=$dir` 不识别）→ 程序被直接启动、`$dir` 无 bin 目标 → 建 shim 失败（修 `xtranslate`；实测解包产出 `Xtranslate.exe` 可达；回归测试 `tools/test_guards.py`）
- **installer 模式卸载脚本三级回退 + 自管理式安装器支持**（2026-10-12，`_uninstall_script`）：`post_uninstall` 不再只找 `$dir\unins*.exe`——① `$dir\unins*.exe` ② 注册表 `Uninstall` 键搜索（`InstallLocation`/`InstallBaseLocation`/`DisplayIcon` 含应用名 → 定位 `unins*.exe` RunAs 运行；Inno 的 `unins000.exe` 与 NSIS 的 `uninstall.exe` 同被 `unins*` 覆盖）③ 找不到则打印提示（防静默空转）。**自管理式安装器自动判定**（`self_managing_installer_fields` + `probe_nsis_exes` 返回标记）：NSIS 载荷含 `*installer-helper.exe`（如 zhiyi 的 `zhiyi-installer-helper.exe`）时——自动不建 bin/shortcuts（免提示）+ 生成 **script 形态 installer**（`RunAs` 提权 + `/D=$persist_dir\<应用名>`：persist 下**全新稳定**目录；1.4.0 起安装器尊重 `/D`，指向**已存在**目录会直接 exit 1——Scoop args 形态的 `/D=$dir`（已存在且含安装器副本）正是 1.4.0 安装失败的根因，实测复现 exit 1/1.1s，改 script 形态实测通过）。手动场景探针处仍可输入 **`0`**（不建 bin/shortcuts；`--select 0` 免交互；zip 路径同样支持）——三层防占位回填：清模板占位 + `merge_existing_manifest(drop=…)` 阻止旧占位合并 + `_bin_skipped` 标记阻止 `--dl` finally 恢复。教训：`Uninstall\<AppName>` 键**仅成功安装后才写入**（早期失败安装时不存在，曾误判"网友卸载脚本不成立"）；`Start-Process -Wait` 会等**整个进程树**——安装器启动的常驻服务进程会让它"假挂起"（用 `$p.WaitForExit()` 只等直接进程）；**`/D` 目标必须装前清空**（2026-10-12 补）——script 形态只解决**首次安装**，**更新/重装**时 `/D=$persist_dir\zhiyiime` 已存在（上次安装残留）→ 安装器照样 exit 1（症状：`scoop update zhiyiime` 每次必失败，卸载后仍失败）→ 清单在装前加 `if (Test-Path "$persist_dir\zhiyiime") { Remove-Item "$persist_dir\zhiyiime" -Recurse -Force }`（persist 只装程序文件、用户配置与学习数据在 `%USERPROFILE%\zhiyi`，删除安全；重装由安装器重建）；**占用时改名绕过**（同日再补）——残留目录里的 `zhiyi_tsf_x64.dll` / `zhiyi-resources.dll` 常被 explorer 等进程加载 → `Remove-Item` 报 Access denied（**管理员也删不掉**：是文件锁不是权限）→ 脚本改「先删；删不掉则 `Rename-Item` 成 `<app>.busy-<时间戳>`」（Windows 允许重命名正在使用的 DLL 所在目录，**实测通过**），装完再清残留；`self_managing_installer_fields` 生成器同步带上这三步
  - **升级先停服务（2026-10-14，参考 zhiyuime.json 形态）**：清理前加三步——① 注册表 InstallLocation 下旧版 `*-installer-helper.exe force-stop-server`（优雅停服务；不存在或不支持该子命令则静默跳过）② 兜底 `Get-Process | Where-Object { $_.Path -like "$persist_dir\*" } | Stop-Process -Force`（杀掉所有从 persist 运行的进程，**通用**：不依赖进程名/注册表键名）③ `Start-Sleep -Milliseconds 800`；停服务后多数情况**直接删即可**（rename 仅作兜底）；`post_uninstall`（`_uninstall_script`）同样先停服务，注册表搜索补 **HKCU**（自管理式安装器写 HKCU 的情形）；装后再**校验注册表 InstallLocation**（未变则黄字警告"安装可能没生效"）。zhiyiime.json 与生成器均已切换为该形态
- **资产筛选加固**：`is_windows_asset` 排除源码包（`-source`/`-src` 独立段）、脚本（`.ps1/.sh/.bat/.cmd/.py` 等）、校验/元数据；**校验和文件的其他写法**（`*.SHA256SUMS`/`*.sha512sums`/`*.md5sums`/`*.checksums`/`*.digest`/`*.sums`，正则大小写不敏感）也排除——原后缀匹配只覆盖 `.sum`/`.sha256`，`…x64.SHA256SUMS` 会漏且带 x64 时得 +2 分，可能被当成主资产（修 `vtracer`；回归测试 `tools/test_guards.py`）；generic 兜底仅限可安装包（防源码包被兜底进缺失架构）；`description` 为 null 时回退；`--add` 检测同一 checkver 来源重复（防重复收录/上游改名）；`arch_url_hash` 支持数组型 url（配对清单取主资产）
- **"隐身"的 macOS/Linux 资产排除（`foreign_platform_assets`，两条规则叠加）**：① 权威——release 含 `latest-mac.yml` / `latest-linux.yml`（electron-builder 平台清单）时解析其列出的文件名排除；② 启发式——与同名 `.dmg` 成对的 `.zip`（去扩展名后相同）视为 macOS。接入两个判断点：`--add` 的 Windows 候选筛选 + `_release_has_windows_asset`（资产守卫，防"只发 mac 包"的 release 被误判为有 Windows 资产）。教训：`freellmapi` 的 `-x64.zip`/`-arm64.zip` 实为 macOS 包（名字无 mac 标记）被当 Windows 资产 → `--dl` 探测"未发现 exe"、真 Windows 包 `-win.zip` 被兜底塞进 32bit。影响实测：47 个 GitHub-release 型清单全扫，仅 freellmapi 受影响、0 误伤
- **一致性校验 `--check`**：校验 README 两表行数之和 == `bucket/` 清单数、逐条一一对应、`progress.md` 计数一致，**外加表格结构**（数据行须紧随分隔行之后、序号须 1..N 连续）；不一致非零退出（已挂 CI）。结构校验补旧盲点：只数行数时"新行插到表头之前"与"序号 | 0 |"都会被漏过（`_parse_readme_table`，回归测试 `tools/test_check_struct.py`）。`--all` 逐文件异常打印 traceback + 汇总并以非零退出码报告（不再静默）；`fetch_json` 支持 `GH_TOKEN`/`GITHUB_TOKEN` 并对 429/5xx 退避重试（回归测试 `tools/test_guards.py`）
- **清单编码（BOM）防线**（2026-10-14）：`bucket/*.json` 必须 **UTF-8 无 BOM**——BOM 会让 Python 工具链报 `Unexpected UTF-8 BOM (decode using utf-8-sig)` → **CI 每晚报异常**（`[异常] zhiyuime.json` → `##[error]`；教训：commit `9e1be96` 给 zhiyuime.json 带了 BOM）。`myscoop-update.py` **读取端统一 `utf-8-sig`**（11 处：`read_text` / `open(..., "r")` / `json.load(open(...))`，容忍 BOM），**写入端保持 `utf-8`（不写 BOM）**。实测：带 BOM 文件跑 `--dry-run` 不再报错
- **静态 latest 直链 + 文本正则 checkver**：安装包不在 GitHub Release 且只有免版本别名时（如 dsh），`checkver` 用 `url`+`regex` 取版本（**显式 url+regex 优先走文本分支**，即使 url 是 GitHub API）；`autoupdate.url` 写静态直链，版本变化时原样下载重算 hash、**内容未变不提升版本**（防幽灵更新）；`fetch_text` 支持 GitHub token（回归测试 `tools/test_static_au.py`）
- **NSIS 双层探测修复**：`probe_nsis_exes` 只要存在 `app-*.7z` 就二次解包并**只用内层 exe**（内层为空则留空），排除 7z/卸载/更新器/vc_redist 等助手 exe，并**优先根级 exe**（滤掉 resources 下依赖）——修 `dsh` 把 7z 助手 `dsh-7za.exe` 当主程序导致建 shim 失败（实测该安装器现得到单候选 `DeepSeek Harness.exe`）
- **GPU 资产优先级**：`score_asset` 非 N 卡专用（**HIP/ROCm/Radeon**）**降一级（-4）**，通用 x64 包优先——优先级为 NVIDIA 通用(+8) > 指定 CUDA(+6) > 通用包(0) > 非 N 卡(-4)；降级≠排除，仅当上游只发非 N 卡包时才选中（修 `strata` 选中 `strata-windows-x64-hip.zip`；回归测试 `tools/test_guards.py`）
- **CLI / 裸二进制降级**：`score_asset` 名字含独立段 `cli`/`msvc`/`gnu` 的资产 **-20（低于 installer 档 -10）**，排到安装器之后——GUI 应用常同时发 CLI 包/裸二进制与安装器，前者不是桌面应用的替代品（修 `bdl` 曾选中 `bdl-cli-…zip`、`vtracer` 曾选中 `vtracer-x86_64-pc-windows-msvc.zip` 把 GUI 装成命令行工具）；降级≠排除，全 bucket 扫描仅 `moonup`（唯一候选）与 `beellama-cpp`（`bin` 字段，非资产名）命中，均无功能影响
- **源码包（拼音标记）降级**（2026-10-12）：`score_asset` 名字含独立段 `daima`/`yuanma` 的资产同样 **-20**（中文项目用拼音命名源码包，与 `-source`/`-src` 同义），**只降级不排除**——上游仅发源码包时仍兜底选中（与 `is_windows_asset` 对 `src`/`source` 的排除策略不同）。教训：`anclicker` 的 `AnClicker-v1.5.2-win-DaiMa.zip` 与 `AnClicker-v1.5.2-win.zip` 同为 5 分、平手后按列表顺序被选中；回归测试 `tools/test_guards.py` 6b 段
- **GitHub 下载镜像加速**：`download_to` 对 GitHub release 资产优先走镜像——顺序探测取第一个可达（1KB range + 8s 超时），全部不可达回退原 URL；列表来源：环境变量 `MYSCOOP_GH_MIRRORS` > Scoop config.json 的 `aria2-mirrors`（与 download.ps1 补丁同一套）。**拼接方式仅支持一种**：镜像前缀 + 完整 `https://github.com/…` URL；git 克隆加速器（`gitclone.com` 等，写法 `镜像/github.com/owner/repo`）不代理 release 路径，实测 404/500，勿加。2026-10-10 实测 31 项 → 去重 + 删 5 个死/类别不符镜像 → **24 项按实测速度排序**（前 3：`hk.gh-proxy.org` / `cdn.gh-proxy.com` / `git.yylx.win`，稳定 3.7–5.3 MB/s；中段镜像轮间抖动 6–9 倍，排序仅概率上更优）；测速工具 `tools/mirror_speed.py`（本地专用，可复跑）
- **`checkver.tag_regex`（GitHub 分支可选 tag 过滤，首选）**：`{"github": …}` 再加 `tag_regex` → 在 releases 列表里按 tag 形态选 release（可含 prerelease），**捕获组即版本**（`^aivault-v([\d.]+)$` → `0.3.0`，自动去产品前缀）。覆盖三场景：多产品共仓 / tag 命名特殊或方案变更（`windows-v*`→`v*`）/ 跟 beta·rc（`^v([\d.]+(?:-(?:beta|rc)\.\d+)?)$`）。**仍走 GitHub 分支 → API digest 免下载**（实测 qingjian `0.1.4→0.1.5-beta.1`、updist `0.3.0→0.3.1` 均无 `[下载]` 行、hash 与上游 digest 一致）。已迁移 `updist`/`qingjian`；文本正则分支只在"包不在 GitHub Release"（如 dsh）时用
- **`find_duplicate_source` 增强**：也扫描 `checkver.url` 的 API 形式（归一 `/repos/` 段）——修"改用文本正则后重复来源检测失效"的副作用；`updist` 迁回 `checkver.github` 后该项也恢复
- **前缀重选 + tag_regex 资产守卫**（2026-10-12，修 CI 两个"无法匹配"）：① `tag_regex` 分支补齐**资产守卫**（最新匹配 tag 空资产 → 回退下一个匹配且有资产的 tag，与常规分支对称）；② 新增 `repick_by_prefix` **第三重匹配**——资产名含每版变化的非数字标记（构建 sha：`ui-938c2f1`→`ui-ae48ec0`）时数字归一化失效，按**公共前缀最长**重选并 `refresh_filename_in_template` 刷新模板文件名（护栏：同扩展名家族 + 前缀≥12 且止于 `-_./` + 唯一最优 + 架构一致）。实测：`kvninfer` sha 漂移自动重选 rtx40 资产 + 模板刷新 ✓；`anclicker` 改名（多候选平手/平台过滤）被安全拒绝 ✓
- **后缀骨架重选（`repick_by_suffix`，第四重，2026-10-15）**：上游**调整产品前缀段**（增删非版本标记，如 `cherry` 2.1.6 去 `-CN`）时前三重全失败——按**与旧名公共后缀最长**重选。护栏：同扩展名家族 + 公共后缀 ≥15 字符且首字符是分隔符（不截断词中）+ 唯一最优 + 架构一致；命中后 `refresh_filename_in_template` 刷模板。**模板刷新同步增强**："版本段 → `$version`"配对形态（`…CN-$version-…` → `…$version-…`），否则含具体版本的旧名在模板里找不到（cherry 首轮实测模板未刷新即此因）。实测：cherry.json 还原成"2.1.4 + `-CN` 模板"坏状态 → 跑更新自动修回，**与人工修正逐字一致**（`git diff` 空）；回归 `tools/test_guards.py` 6c 段（含平手/后缀过短/架构不一致拒绝）
- **解包类清单入口路径修复**（2026-10-15）：`sunpack`（Inno Setup + 嵌入式 Python）真实入口在 **`bin\sunpack.exe`**（根目录 `sunpack-runtime.exe` 是 21MB 的 Python 运行时，非入口），原清单写 `bin: "sunpack.exe"` → shim 失败（`Can't shim 'sunpack.exe': File doesn't exist`）；改 `bin\\sunpack.exe`（shortcuts 同步）后 `scoop install` shim 成功。教训：解包类（Inno/NSIS/Tauri）清单写 `bin` 前**先列解包目录（含子目录）确认入口真实路径**。另：上游 v1.1.8 只有 x64/arm64 两个 setup.exe（无便携包），清单选 x64 正确
- **根因与工具修复（同日）**：问题出在 `--dl` 的探测函数——`probe_installer_exes`（Inno 静默安装探测）与 `probe_nsis_exes`（7z 解包探测）都用 `p.name` **只取文件名**，子目录入口（`bin\sunpack.exe`）被写成顶级 `bin=sunpack.exe` → shim 失败。两处改为 **`str(p.relative_to(root))` 相对路径**（顶层即文件名，子目录形如 `bin\xxx.exe`；排序键同步改为"有无子目录 + 小写名"）。实跑 `--add https://github.com/Qinjingxue/Sunpack.git --name sunpack --dl --select "bin\sunpack.exe"` 验证：探测输出 `bin=bin\sunpack.exe`，重新生成的清单与手工修正**逐字一致**（`git diff` 空）
- **注册型 installer 模式不建 bin/shortcuts**（2026-10-15）：Inno + 注册型（输入法/驱动/右键菜单）自动采用 installer 模式（真安装）时**必须置 `skip_bin = True`**——安装后安装器自删、应用本体不在 `$dir`，写 bin 会让 scoop 建 shim 失败。教训：`msime`（水杉输入法）的 bin 被写成 `MetasequoiaIME_Setup_v0.10.1.exe`（安装器名）并被 merge 从旧清单保留 → `Can't shim …: File doesn't exist`。修复（`finalize_direct_manifest` 注册型分支加 `skip_bin = True`，走既有"清模板 + drop 阻止 merge 带回"机制）后重跑 `--add --dl`：产出无 bin/shortcuts（`[跳过] 0：不建立 bin/shortcuts`）✓
- **cherry 资产改名适配**（2026-10-15）：上游 2.1.6 起去掉资产名里的 `-CN` 段（`Cherry-Studio-CN-2.1.4-win-x64-portable.exe` → `Cherry-Studio-2.1.6-win-x64-portable.exe`），清单 autoupdate 模板同步去 `-CN` 并升到 2.1.6（hash 取 API digest）——dry-run 验证匹配成功（"共 0 个可更新"）。**repick_by_prefix 未介入是正确的**：`-win-x64-portable.exe` 与 `-win-x64-setup.exe` 的共同前缀平手（均止于 `Cherry-Studio-`），"唯一最优"护栏正确拒绝——命名结构变化属人工确认场景（同 anclicker 改名案例）
- **清单修复**：**`kvllama` → `kvninfer`**（上游拆双产品线：llamacpp 线已无 sm89 构建、v0.17.0 空 release；改跟 ninfer 线 `tag_regex ^v([\d.]+-ninfer-rc\d+)$` + rtx40-sm89 资产 + `pre_install` 拍平 sha 顶层目录 + `bin=workers/ninfer/ninfer-kvmem-server.exe`；notes 注明 .ninfer 模型需另备、路径必须纯英文）。**`anclicker`**：上游 v1.4.0 起资产改名 `-windows-x64.zip`→`-Portable.zip`（Squirrel 便携布局：根 `An Clicker.exe` 启动器 + `current/` 本体），清单改 url/hash/bin（A/B 实测旧命名无法匹配、新命名正确更新）

## Scoop 库补丁与版本分发（symlink.bat）

- **三件套部署（软链接 + 拷贝混合）**：`manifest.ps1`（bucketlist 桶优先级）+ `download.ps1`（GitHub 镜像加速）以**软链接**部署到 `D:\scoop\apps\scoop\current\lib\`；`config.json`（数据）以**镜像拷贝**部署到 `~\.config\scoop\`——原因：Scoop 自身会重写 config.json（`scoop config` 写入、更新时写 `last_update`），会把软链接删掉重建为普通文件 → 链接失效；拷贝则每次运行 symlink.bat 重新同步为仓库版本（源为权威）。`symlink.bat`（需管理员）分三段：①库文件软链接 ②config.json 镜像拷贝 ③仓库 .bat → shims 链接；Scoop 自更新重建 current 后需重跑一次。
- **多基线版本分发（数据驱动）**：Scoop v0.6.0 大改 `manifest.ps1`——`Get-Manifest` 的桶遍历抽到新函数 `Find-AppBucket`（`$buckets` 变量消失），旧补丁直接失效；`download.ps1` 的镜像补丁 3 处插入点未变（仅需重挂到新基线）。现维护：**仓库根 = 最新基线**（版本号记录在 `patches\baseline.txt`），**`patches\<版本>\` = 该版本冻结补丁**（现有 `patches\v0.5.3`）。
- **分发逻辑**：`git describe --tags --abbrev=0` 取 Scoop 版本 → 版本==基线 → 根补丁；`patches\<版本>\` 存在 → 专用补丁；否则 → 根补丁 + 警告（Scoop 比补丁新）；git 不可用/无标签 → 根 + 警告。实测四分支：v0.6.0→根、v0.5.3→专用、v0.9.9→根+警告、无 git→根+警告（沙盒脚本 + 假 tag 仓库）。**已废弃特征嗅探判据**（`Get-PEMachine` / 更早的 `buckets.ps1`）——判据函数每版本都要重新研究，且 `buckets.ps1` 在 v0.5.3 也存在曾致误判；版本号匹配无需研究。
- **Scoop 大版本更新维护三步（symlink.bat 零改动）**：① 根补丁两个文件复制到 `patches\<旧基线>\` 冻结 ② 用新官方文件重建根补丁 ③ 改 `patches\baseline.txt` 为新版本号。
- **编码**：补丁 ps1 = UTF-8 **带 BOM** + CRLF（PS 5.1 无 BOM 按 GBK 读，中文注释乱码）；`symlink.bat` = UTF-8 **无 BOM** + CRLF + 开头 `chcp 65001`（bat 加 BOM 会使首行 `@echo off` 失效）。
- **验证方法**：功能复验 `Find-AppBucket cc-switch` → 选中 myscoop/4.0.8（bucketlist 生效，无补丁时首个是 extras）、`Get-GitHubMirrorUrl` → 返回镜像 URL；分发分支用沙盒脚本（git 路径指向假 tag 仓库、目标路径替换为临时目录，不触碰真实 Scoop）。

## Scoop 工具箱脚本（智能模式Scoop(3).ps1）

- **桶名匹配修复（2026-10-11）**：Scoop v0.6.0 把 `install.json` 改名为 **`scoop-install.json`**（应用更新时旧文件被删除），原逻辑只读旧名 → 升级后安装/更新过的应用丢失桶前缀 → 恢复脚本无前缀安装可能装错桶/旧版（如 cc-switch 在 extras 是 4.0.6、myscoop 是 4.0.8）。现改为：**优先用 `scoop export` 的 `Source` 字段**（校验必须是已存在的桶名，排除 `<auto-generated>`——本机 2 个：python/sublime-text），回退读 `scoop-install.json` → `install.json`。实测映射 167 → 170（cc-switch/prllama/qingjian 补回）。
- **恢复脚本补丁提示**：生成的恢复脚本末尾新增提示——myscoop 桶补丁不随恢复部署，如需镜像加速与桶优先级需以管理员运行 `<Scoop>\buckets\myscoop\symlink.bat`。
- 头部注释同步更名（自动更新Scoop → 智能模式Scoop），清理编辑笔记残留。

## 核心规则

1. **Release 命名规范**：包名（文件名）必须英文 → 标题中英结合 → 描述纯中文
2. **git commit 信息必须用中文**
3. **每次制作/更新后，提交前必须同步更新 README.md、progress.md（本项目进展）和 SKILL.md**
4. **Hash 获取优先使用 GitHub API**：GitHub Release API 返回的每个 asset 包含 `digest: sha256:xxx` 字段，可直接读取无需下载文件。仅在 API 不可用时才下载计算。
5. **每次提交完成后**，必须运行 `git log --oneline --decorate --graph --decorate-refs-exclude=refs/tags/*` 并将完整输出更新到本文件的"提交历史"章节（必须排除标签装饰，防超长行）。
6. **多版本软件资产（自托管）**：同一软件需保留多个版本时，用一个 release（固定 tag）下挂多个资产（文件名含版本号区分），不要每版本各建一个 release。manifest 的 `version` 为默认（最新）版本，`url`/`hash` 硬编码默认版具体地址（`url` 里写 `$version` 会导致 Scoop 普通安装 404），`autoupdate.url` 仅文件名用 `$version` 模板。安装默认版 `scoop install myscoop/<app>`；指定版 `scoop install myscoop/<app>@<版本>`（触发 autoupdate 动态生成、GitHub digest 取 hash）；切换 `scoop reset myscoop/<app>@<版本>`。搜索工具只显示默认版，必须同步 README 标注多版本及 `@版本` 用法。示例：Sublime Text（release `vSublimeText` 挂 4200/4207）。详见 SKILL 规则 15。
7. **改动文件必须全部提交推送**：所有内容改动过的需提交文件（含 README.md、progress.md、SKILL.md 及仓库内其他跟踪文件）一律提交推送，不得遗留未提交改动；即使改动与本任务无关（如历史遗留改动）也一并提交。未跟踪文件（发布资产、临时文件）不在此列。
8. **README 软件表必须与 bucket/ 全量对齐**：每次新增/更新 manifest 后，提交前必须核对 README 两张表（第三方官方 + 本地维护）的行数之和等于 `bucket/` 清单总数，**缺漏必须补上**（含记录在 top 且重新编号）；总量计数（收录总数/第三方/本地）同步修正，不允许任何已入库 manifest 在 README 表中缺席。
9. **自动更新资产守卫**：`myscoop-update.py` 更新单清单时，latest release 无可下载 Windows 资产（如 monorepo 子包噪音 tag，assets 为空）→ 自动回退 releases 列表找带资产的 release，仍无则跳过；架构分支所有架构都匹配失败时跳过不写入（防删架构块 + 写垃圾 version 改坏清单）。详见 SKILL 规则 19。
10. **README 第三方表跳转链接必须指向"引用项目地址"**：每行软件名链接 = 清单实际引用的项目仓库（`checkver.github` → `https://github.com/<owner>/<repo>`），不用官网/产品页/文档站；无 GitHub 仓库的官方直链型（dsh/winsdk/pixpin）保持其官网/项目页。详见 SKILL 规则 22。

## 标准处理流程

### 模式 1：官方 portable zip/7z
- 直接引用官方 GitHub Release URL
- 设置 checkver + autoupdate
- 示例：cmm-plus, mykeymap, litemonitor, amcfy-music, floral, baulk（多架构 zip 官方 release）

### 模式 2：单 exe / zip 便携（自托管）
- 本地文件上传到 GitHub Release
- 示例：windowsclear, tinytask, 360bwtest, btsou（更新 26.08.26.01）, hibituninstaller, gzh-formatter（单 exe 便携）, bcompare（汉化便携 zip）, easytshark（便携 zip）
- **模式 2b：自建独立构建仓库**（2026-10-11 起）：个别应用不再挂在 myscoop 仓库 release，而是上传到**独立构建仓库**（如 `switchhosts` → `w3c0929/SwitchHosts`，自建 zip 便携 + 完整 checkver/autoupdate）——清单按**第三方官方**管理（README 第三方表），myscoop 侧的自托管资产/release 一并移除

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

每次提交完成后，将 `git log --oneline --decorate --graph --decorate-refs-exclude=refs/tags/*` 输出更新到此处（必须排除标签装饰——95 个 release 锚点标签全指向同一快照提交，不排除时该行可达数千字符）：

```
* 213a39d (HEAD -> main, origin/main, origin/HEAD) zhiyuime 1.7.56 test build (local only)
* e49afc3 zhiyuime 1.7.55 test build (local only)
* 8aee2f8 zhiyuime 1.7.32 test build (local only)
* 47eebe6 zhiyuime 1.7.31 test build (local only)
* 8f712d8 zhiyuime 1.7.31 test build (local only)
* 6c9477c zhiyuime 1.7.30 test build (local only)
* f97500c zhiyuime 1.7.29 test build (local only)
* 4d8a150 zhiyuime 1.7.28 test build (local only)
* f1d38b5 zhiyuime 1.7.27 test build (local only)
* 8e6de36 progress.md 更新提交历史
* 65eb187 同步 README 第三方版本与日期列
* 9c3107b 自动更新第三方软件
* 21c84b2 progress.md 更新提交历史
* ffe22b8 README 更新第58条 cc-haha 描述：改为本地优先的跨平台 Claude Code / AI Agent 桌面工作台（去敏感表述）
* b59ec58 progress.md 更新提交历史
* d601b6c 新增第四重资产匹配「后缀骨架重选」（repick_by_suffix）：上游调整产品前缀段（如 cherry 2.1.6 去 -CN）时按公共后缀最长重选（护栏：同扩展名家族 + 后缀 ≥15 且首字符为分隔符 + 唯一最优 + 架构一致）；refresh_filename_in_template 增强「版本段→\」配对形态（模板保活）；实测 cherry 坏状态自动修回与人工修正逐字一致；回归 test_guards 6c 段
* 38bf54c progress.md 更新提交历史
* ba5f3a0 修 cherry 更新失败：上游 2.1.6 起资产名去掉 -CN 段，autoupdate 模板同步去 -CN 并升到 2.1.6（hash 取 API digest）——dry-run 验证匹配成功；repick 前缀重选因'唯一最优'护栏正确拒绝（portable/setup 平手，命名结构变化属人工确认场景）
* e2f87dc mypsh推送
* ae226c6 progress.md 更新提交历史
* a5e5cfb 修注册型 installer 模式误建 bin：Inno+注册型自动采用 installer 模式时置 skip_bin（安装后安装器自删、应用本体不在 \，写 bin 导致 Can't shim）；新增收录 水杉输入法 msime 0.10.1（README 置顶补行并重编号 61→62，progress 计数 147→148）；重跑 --add --dl 验证产出无 bin/shortcuts
* 3f543a6 zhiyuime 1.7.26 test build (local only)
* 858e111 progress.md 更新提交历史
* b564509 myscoop-update.py 顶部用法：补全「六、可选参数速查」（新增模式入口/--dl/--allow-archived/--probe-exe 等，29 个参数全覆盖，脚本核对无缺失）；修正示例笔误 --prllama → --name prllama
* 7142899 progress.md 更新提交历史
* fd4c750 myscoop-update.py 顶部用法补 --check 一致性速查（README ↔ bucket ↔ progress；不一致非零退出）；镜像项编号顺延为 11
* 7eaacec progress.md 更新提交历史
* 6723b4b progress.md 更新提交历史
* f2490fb 修 --dl 探测丢子目录路径：probe_installer_exes / probe_nsis_exes 改用相对路径（str(p.relative_to(root))）——原用 p.name 只取文件名，Inno/NSIS 子目录入口（如 sunpack 的 bin\\sunpack.exe）被写成顶级 bin=sunpack.exe → 建 shim 失败；实跑 --add --dl 验证重新生成的清单与手改逐字一致
* 941c002 progress.md 更新提交历史
* 74ca969 文档：记录解包类清单 bin 入口路径教训（sunpack 真实入口在 bin\\sunpack.exe；写 bin 前先列解包目录含子目录）
* 2fe479e 修 sunpack 清单：bin/shortcuts 指向 bin\\sunpack.exe——实际入口在 bin/ 子目录（根目录 sunpack-runtime.exe 是嵌入式 Python 运行时，非入口），修 shim 创建失败（Can't shim 'sunpack.exe': File doesn't exist）
* 2f99e25 progress.md 更新提交历史
* d47aec9 新增收录 Sunpack 1.1.8（Windows 全自动压缩包处理工具：后台监控/解压/递归/崩溃恢复，多架构 Inno Setup 解包）：README 第三方表置顶补行并重编号（60→61），progress 计数 146→147；顺带同步 README 版本列（zhiyuime 1.7.25）
* 9bc59c9 zhiyuime 1.7.25 test build (local only)
* 630881a zhiyuime: the manifest without a BOM
* 0ef39b1 zhiyuime 1.7.24 test build (local only)
* a66fa87 progress.md 更新提交历史
* faff223 同步 README 第三方版本与日期列
* 88446ca 自动更新第三方软件
* 6763aed progress.md 更新提交历史
* 738d686 progress.md 更新提交历史
* 868b869 CI 给更新脚本注入 GITHUB_TOKEN（Actions 自带临时令牌，配额 5000/h）——消除 --all 查 140+ 清单时的 403 rate limit；无新增 secret、仅本仓库运行期权限
* d51b07d progress.md 更新提交历史
* 66c3c4e progress.md 更新提交历史
* b02ce8a 文档：记录清单 BOM 防线（bucket/*.json 必须 UTF-8 无 BOM；工具读取端 utf-8-sig 容错 11 处）
* 4240ca4 progress.md 更新提交历史
* c7b7c49 同步 README 第三方版本与日期列
* db28d6c 修 zhiyuime.json 带 UTF-8 BOM 导致 CI 每晚报异常（Unexpected UTF-8 BOM）：① 去 BOM ② myscoop-update.py 读取端统一 utf-8-sig 容错（11 处读；写入仍 utf-8、不写 BOM）——实测带 BOM 文件不再报错
* 8ee61ed progress.md 更新提交历史
* 0afa7ca mypsh推送
* dc8cb26 zhiyuime 1.7.23 test build (local only)
* 9af5723 mypsh推送
* fbe6532 zhiyuime 1.7.22 test build (local only)
* c536986 zhiyuime 1.7.21 test build (local only)
* 7f2dd35 zhiyuime 1.7.20 test build (local only)
* 8b60215 zhiyuime 1.7.18 test build (local only)
* e8dfe2f zhiyuime 1.7.17 test build (local only)
* 85e00ac zhiyuime 1.7.16 test build (local only)
* f0e9476 zhiyuime 1.7.15 test build (local only)
* 5f8ad11 zhiyuime 1.7.14 test build (local only)
* 84d937f zhiyuime 1.7.12 test build (local only)
* f8016d9 zhiyuime 1.7.11 test build (local only)
* 746f962 zhiyuime 1.7.10 test build (local only)
* 12dbde3 zhiyuime 1.7.9 test build (local only)
* a253e3f zhiyuime 1.7.8 test build (local only)
* ab43791 progress.md 更新提交历史
* a1a012a 自管理式安装器升级为「停服务」形态（参考 zhiyuime.json）：装前 ① 旧版 *-installer-helper force-stop-server ② 按路径杀掉 persist 内进程 ③ sleep 800ms——停服务后可直接删（rename 仅兜底）；post_uninstall 同样先停服务 + 注册表搜索补 HKCU；装后校验 InstallLocation；zhiyiime.json 与生成器同步
* 9e1be96 zhiyuime manifest: UTF-8 with a BOM
* 3c7f798 zhiyuime 1.7.7 test build (local only)
* a3d6817 zhiyuime 1.7.6 test build (local only)
* a85be0d zhiyuime: smarter upgrade (stop the old service first, verify it took)
* aebed92 zhiyuime 1.7.5 test build (local only)
* 4913042 zhiyuime 1.7.4 test build (local only)
* 674e456 zhiyuime 1.7.3 test build (local only)
* be581ba zhiyuime 1.7.2 test build (local only)
* ad15eb7 zhiyuime 1.7.1 test build (local only)
* cb77183 zhiyuime 1.7.0 test build 2 (local only)
* 9311e2e zhiyuime 1.7.0 (local test build; do not push until the release is published)
* d42d1eb mypsh推送
* 38b5dbd progress.md 更新提交历史
* 6a67021 新增收录 SVCode 0.3.2（轻量的编辑优先文本与代码编辑器，Tauri 解包）：README 第三方表置顶补行并重编号（59→60），progress 计数 145→146
* 249a9e8 zhiyuime 1.6.6
* a132fcb zhiyuime 1.6.5
* 52d6a92 zhiyuime 1.6.4
* 9145f86 mypsh推送
* 5ce07c0 progress.md 更新提交历史
* af20294 新增收录 知语输入法 zhiyuime 1.6.3（zhiyi_ime 的自研进阶版：语音输入 / 划词翻译，与知意输入法共存；自管理式安装器 script 形态 + 装前清 /D 目标）：README 第三方表置顶补行并重编号（58→59），progress 计数 144→145
* c235790 zhiyuime 1.6.3
* fe1fcf7 zhiyuime 1.6.2
* a998dc8 bucket: zhiyuime 1.6.1; zhiyiime also looks under HKCU for the uninstaller
* 3fd737c progress.md 更新提交历史
* 6f2673c 同步 README 第三方版本与日期列
* ffee9cf 自动更新第三方软件
* 9723b84 mypsh推送
* 3e974e5 progress.md 更新提交历史
* b902bc5 新增收录 StarPie 1.8.0-beta.7（现代化 Windows 鼠标轮盘手势系统，Lightweight 便携 zip 官方 release）：README 第三方表置顶补行并重编号（57→58），progress 计数 143→144
* be7c272 progress.md 更新提交历史
* 3cdff3b 新增收录 Ludusavi 0.31.0（PC 游戏存档备份与恢复工具，多架构 zip 官方 release）：README 第三方表置顶补行并重编号（56→57），progress 计数 142→143
* c66ec38 progress.md 更新提交历史（含用户更新的 filee 1.10.2）
* 774ad41 修 zhiyiime 更新失败（DLL 占用场景）：/D 清理改「先删，删不掉则 Rename-Item 改名绕过」——残留 TSF/资源 DLL 被 explorer 等加载时 Remove-Item 报 Access denied（管理员亦然，属文件锁非权限），重命名目录实测可行；生成器同步 + SKILL/progress 记录
* 793ce61 progress.md 更新提交历史
* 0173e74 同步 README 第三方版本与日期列
* c32121a 自动更新第三方软件
* e812d1c progress.md 更新提交历史
* 9b947c1 progress.md 更新提交历史
* c5ebbeb 同步 README 第三方版本与日期列
* af8ffe8 自动更新第三方软件
* 25bc0cf progress.md 更新提交历史
* e3a82fb 修 zhiyiime 更新必失败：自管理式安装器 /D 目标装前清空（更新/重装时 persist 残留目录 → 安装器 exit 1）——清单加 Remove-Item，self_managing_installer_fields 生成器同步（以后收录自动带此步）；SKILL/progress 记录教训
* 64c3d51 myps推送
* ee11d8b mypsh推送
* edbbf9c progress.md 更新提交历史
* 6f54195 更新第三方软件：anclicker 1.5.2 / filee 1.10.1 / freellmapi 0.13.10 / taskbarpopup 1.1.1 / zhiyiime 1.4.4（--all 更新，README 版本列由内置同步自动跟随）
* a80bd48 资产打分新增源码包（拼音标记）降级：score_asset 对独立段 daima/yuanma 记 -20（与 CLI 档同级、只降级不排除）——修 anclicker 的 -win-DaiMa.zip 与 -win.zip 同分被顺序选中；README 打分表 / SKILL 规则 20 / progress 同步，test_guards 加 6b 回归
* 046891e progress.md 更新提交历史
* 242e33a 同步遗留改动：anclicker 1.4.9（上游资产再改名 -win.zip）/ bongocat 2.3.0
* 6a025f6 myscoop-update 更新后自动同步 README（内置 sync_readme_after_update：版本列 + 创建/更新日期列，本次变更清单取当天，本地 --all 一步到位；与 CI 内联步骤逻辑等价、CI 行为不变）；顺带同步 4 处 README 落后项，zhiyiime 1.4.2
* f8c1eb8 progress.md 更新提交历史
* 3312f4c 新增收录 Filee 1.10.0（免费开源文件转换器：拖拽即转 180+ 格式，全程离线无需上传）：README 第三方表置顶补行并重编号（55→56），progress 计数 141→142
* 194467a progress.md 更新提交历史
* ab10d9c README 知意输入法行描述同步：自管理式安装器 script 形态（装到 persist），非'固定装 Program Files'
* b63e9a8 修复 CI 两个'无法匹配'：anclicker 资产改名适配 + kvllama→kvninfer（上游双产品线拆分）；新增前缀重选第三重匹配 + tag_regex 资产守卫
* 3338e0c progress.md 更新提交历史
* 9a9d9ff 同步 README 第三方版本与日期列
* 48eef51 自动更新第三方软件
* c3bd99d progress.md 更新提交历史
* 585c8ae CI 提交历史重建对齐铁律 13：log 命令加 --decorate-refs-exclude=refs/tags/*
* 2a93c0c progress.md 更新提交历史
* 1619fbc 自管理式安装器自动判定：installer-helper 标记 → script 形态（RunAs + persist /D）；zhiyiime 清单修复为 script 形态
* 8ad73d1 progress.md 更新提交历史
* 6b94699 同步 README 第三方版本与日期列
* c1dcf59 自动更新第三方软件
* a5e97ad progress.md 更新提交历史
* fb7e96a installer 模式适配：卸载脚本三级回退 + 探针 0 跳过 bin（自管理式安装器）；收录知意输入法 zhiyiime
* ce0aaa6 progress.md 更新提交历史
* 7bf4fd1 铁律清理：修订 8 处与现状不符的条目（规则 1/6/7/13/14/20/21）
* 332e86b progress.md 更新提交历史
* ba20693 铁律新增第 22 条：README 第三方表跳转链接必须指向'引用项目地址'（清单 checkver.github 仓库）
* 5c594d9 progress.md 更新提交历史
* e4e9a1f README 第三方表跳转链接修正：14 行改为清单引用的项目地址（GitHub 仓库）
* 0776562 progress.md 更新提交历史
* 84ca7ef 同步 README 第三方版本与日期列
* 667b4ee progress.md 更新提交历史
* 8794903 progress.md 更新提交历史
* d5d6bbf SwitchHosts 改归第三方官方：迁移到自建构建仓库 w3c0929/SwitchHosts
* c154302 progress.md 更新提交历史
* 333f642 同步 README 第三方版本与日期列
* 0eec077 自动更新第三方软件
* 3429767 progress.md 更新提交历史
* 50eeea4 新增收录 TaskbarPopup 1.1.0（Windows 11 任务栏增强：最大化隐藏任务栏 + 长按 Win 迷你任务栏）：README 第三方表置顶补行并重编号（52→53），progress 计数 139→140
* f13ab3b progress.md 更新提交历史
* d0562bd Windows 资产判断修复：排除'隐身'的 macOS/Linux 资产（平台清单 + 同名 .dmg 成对）；收录 freellmapi
* 349fb1e progress.md 更新提交历史
* 2aa401e 智能模式Scoop(3).ps1 桶名匹配修复：兼容 Scoop v0.6.0 的 scoop-install.json 改名
* ec09b75 progress.md 更新提交历史
* ee372ca symlink.bat 版本分发改为数据驱动：git describe 取版本 + baseline.txt 比对，Scoop 新版本零改动
* b180775 progress.md 更新提交历史
* 9d796a9 symlink.bat 精简注释：移除版本分发说明（README 已有完整说明）
* 8f0ff71 progress.md 更新提交历史
* e391d1a symlink.bat 改造：config.json 改用镜像拷贝（真实文件），避免 Scoop 重写配置破坏软链接
* 361558d progress.md 更新提交历史
* 608bb88 补丁双基线分发：根补丁升级 v0.6.0 基线，新增 patches/v0.5.3，symlink.bat 按版本自动分发
* 30ed684 progress.md 更新提交历史
* f74797e 同步 README 第三方版本与日期列
* e22de33 自动更新第三方软件
* 4af5f36 progress.md 更新提交历史
* 748f7d2 新增收录 CC Switch 4.0.7（多 AI 编程助手桌面配置切换器，多架构 portable zip 官方 release）：README 第三方表置顶补行并重编号（50→51），progress 计数 137→138
* e4b02ec progress.md 更新提交历史
* 7202d10 镜像列表去重并按实测速度重排：31 项 → 24 项
* dacf399 myscoop 快照：137 款 Windows 软件 Scoop 清单（历史重写为单 commit）
```

## 新会话启动指南

1. 告诉 AI：`/skills-myscoop` 加载收录技能
2. 当前项目路径：`E:\09.同步\06.配置\myscoop`
3. 上传新软件：把文件放到该目录下，告诉 AI 文件名和类型
4. 阅读 `SKILL.md` 了解完整制作流程
5. 阅读 `README.md` 查看已收录软件列表
