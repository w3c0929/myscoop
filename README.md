# myscoop

个人 Scoop Bucket 仓库，收集 GitHub 上的 Windows 软件，支持一键安装和自动更新。

## 快速安装（推荐）

不想逐条执行下面的命令时，用一键恢复脚本：

> **首次运行脚本前（必做）**：打开 PowerShell 执行一次 `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`（允许本地脚本，远程脚本仍需签名）。

**Windows 10 / 11**

1. 下载 [`restore-scoop-backup.ps1`](https://github.com/w3c0929/myscoop/raw/main/restore-scoop-backup.ps1)（右键 → 另存为）
2. 右键脚本 → **使用 PowerShell 运行**
3. 脚本自动安装 Scoop、Git 并添加全部 bucket
4. 完成后进入 `D:\scoop\buckets\myscoop`，**以管理员身份运行 `symlink.bat`** 完成部署

**Windows 7**

Windows 7 自带的 PowerShell 版本过旧，需先安装 WMF 5.1：

1. 下载 [Win7-WMF5.1-x64.zip](https://github.com/w3c0929/myscoop/releases/download/vWin7WMF/Win7-WMF5.1-x64.zip)
2. 解压后双击运行 `Win7AndW2K8R2-KB3191566-x64.msu`，**重启电脑**
3. 再按上面 Windows 10/11 的第 1–4 步操作


> **Fork 后如何配置企业微信通知**
>
> 自动更新工作流会把各清单的 `[警告]` / `[错误]` / `[跳过]` 等异常推送到企业微信机器人。通知地址通过仓库 Secret 读取，**不会写进仓库或日志**：
>
> 1. 在自己 fork 的仓库进入 **Settings → Secrets and variables → Actions → New repository secret**
> 2. Name 填 `WECHAT_WEBHOOK_URL`
> 3. Value 填你自己的企业微信群机器人地址（群设置 → 群机器人 → 添加 → 复制 Webhook）：
>    `https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=你的KEY`
> 4. 未配置该 Secret 时，工作流会自动跳过推送，不影响更新与提交。
>
> ⚠️ 请勿把 Webhook key 写进任何文件或提交记录；GitHub 会自动在 Actions 日志中脱敏 Secret。

## 收录软件

> 共收录 **182** 款 Windows 软件，其中 **97** 款引用第三方官方 Release，**85** 款为本地维护（自托管 Release）。

### 第三方官方（引用原项目 Release）

| # | 软件 | 安装命令 | 类型 | 版本 | 创建 | 更新 |
|--|------|---------|------|------|------|------|
| 1 | [Nectarlink](https://github.com/thtbee/nectarlink) — Android 手机与 PC 协同一体（本地优先、端到端加密、无账号） | `scoop install nectarlink` | 官方 release NSIS 安装包（解包，nightly 通道） | 0.1.6-nightly.12 | 2026-11-23 | 2026-11-23 |
| 2 | [MisterDownloadManager](https://github.com/anefzaoui/misterdownloadmanager) — 开源下载管理器（Rust 编写，跨平台，含 CLI/MCP 入口） | `scoop install mdm` | 官方 release 便携 zip | 0.5.2 | 2026-11-22 | 2026-11-22 |
| 3 | [CrossDesk](https://github.com/kunkundi/crossdesk) — 轻量级跨平台远程桌面（支持 Web 客户端访问） | `scoop install crossdesk` | 官方 release 便携 zip（仅 x64） | 1.7.7-20261124 | 2026-11-22 | 2026-11-24 |
| 4 | [Winc](https://winc.si) — Rust 编写的极速文本编辑器（自研渲染引擎：0.1 秒启动、10 万行仅 52MB） | `scoop install winc` | 官方 release 便携 zip（仅 x64） | 0.1.857 | 2026-11-22 | 2026-11-22 |
| 5 | [MyKeymap](https://github.com/w3c0929/MyKeymap) — 键盘映射效率工具（AutoHotkey） | `scoop install mykeymap` | 官方 release 便携 zip（自建构建仓库 w3c0929/MyKeymap） | 2.0-beta34 | 2026-10-10 | 2026-11-21 |
| 6 | [Quiet.md](https://github.com/s1dashu/quiet-md) — 极速原生笔记与富文本编辑器（Rust + GPUI），本地优先 | `scoop install quietmd` | 官方 release Inno 安装包（解包为便携） | 0.1.14 | 2026-11-21 | 2026-11-22 |
| 7 | [Atrium Desktop](https://github.com/wynter-yaxley/atrium-desktop) — Windows 11 原生玻璃质感桌面：浮动任务栏与桌面小组件，实时折射效果 | `scoop install atrium` | 官方 release 便携 zip（仅 x64） | 2.7.0 | 2026-11-20 | 2026-11-20 |
| 8 | [MoJian3D](https://github.com/LingCore/MoJian3D-Downloads) — 3D 模型查看器（Qt 桌面应用）：支持 AI Agent 通过内置 mojian3d-control 技能检查并控制当前模型 | `scoop install mojian3d` | 官方 release 便携 zip（仅 x64） | 0.1.6 | 2026-11-20 | 2026-11-20 |
| 9 | [清风输入法 (WindInput)](https://github.com/huanfeng/WindInput) — 轻量、快速、可定制的开源中文输入法，专为五笔和码表方案设计，支持全拼/双拼 | `scoop install windinput` | 官方 release 便携 zip（TSF 需 wind_portable -start 注册） | 0.133.0 | 2026-11-17 | 2026-11-23 |
| 10 | [Argus](https://github.com/Ray-lea/Argus) — 现代 Windows 任务管理器（Rust + GPUI） | `scoop install argus` | 单 exe 官方 release（仅 x64） | 0.6.0 | 2026-11-12 | 2026-11-23 |
| 11 | [Snow Shot](https://github.com/mg-chao/snow-shot) — 截图、标注、钉图、离线 OCR 与录屏工具 | `scoop install snowshot` | 多架构便携 zip 官方 release（x64 / arm64） | 1.6.4 | 2026-11-11 | 2026-11-25 |
| 12 | [AltSnap](https://github.com/w3c0929/AltSnap) — 按住 Alt 拖动窗口（AltDrag 的维护延续版） | `scoop install altsnap` | 便携 zip 官方 release（仅 x64） | 1.68 | 2026-11-10 | 2026-11-10 |
| 13 | [ELYTerminal](https://github.com/ELY-Open-Source/ELYTerminal) — 基于 GPUI 与 Ely 组件的终端 | `scoop install elyterminal` | 多架构便携 zip 官方 release（x64 / arm64） | 0.2.7 | 2026-11-09 | 2026-11-25 |
| 14 | [WhoShitsonMyC](https://github.com/Kami958/WhoShitsonMyC) — 磁盘空间变化对比轻量小工具 | `scoop install whoshitsonmyc` | 单 exe 官方 release | 1.2.0 | 2026-11-09 | 2026-11-16 |
| 15 | [VMware Workstation](https://github.com/201853910/VMwareWorkstation) — 官网 VMware Workstation 安装包镜像（Windows x64，手动安装） | `scoop install vmware` | 单 exe 官方 release（手动安装，仅 x64） | 26H1 | 2026-11-09 | 2026-11-09 |
| 16 | [LiveZoom](https://github.com/w3c0929/live-screen-studio) — 直播用的屏幕平滑放大工具（Windows 版）：中键放大、平滑跟随 | `scoop install livezoom` | portable zip 官方 release（仅 x64） | 0.9.4 | 2026-11-08 | 2026-11-16 |
| 17 | [TodoCue](https://github.com/NanmiCoder/TodoCue) — 本地优先的任务管理客户端：原生 UI + CLI + MCP，供 AI Agent 使用 | `scoop install todocue` | 多架构 NSIS 解包（x64 / arm64） | 0.10.3 | 2026-11-07 | 2026-11-13 |
| 18 | [Win顺 (WinShun)](https://github.com/w3c0929/WinShun) — 文件、文件夹与内容即时搜索 | `scoop install winshun` | portable zip 官方 release（仅 x64） | 0.44.2 | 2026-11-07 | 2026-11-22 |
| 19 | [LibreGet](https://github.com/OpenSelena/libreget)（原 OmniGet） — 开源下载管理器：课程（Udemy/Hotmart）、YouTube、音乐及 1800+ 站点（Tauri 2 + Rust + Svelte） | `scoop install omniget` | 单 exe 官方 release（仅 x64） | 1.0.0 | 2026-11-07 | 2026-11-24 |
| 20 | [Foxmail](https://www.foxmail.com/) — 邮件客户端（myscoop 覆盖 extras 滞后清单） | `scoop install foxmail` | 单 exe 官方直链（7z 解包） | 7.2.25.592 | 2026-11-07 | 2026-11-19 |
| 21 | [NOIR](https://github.com/Verlintas/NOIR) — 手机隐私审计：用 adb 扫出 Android 应用的权限、上报端点与数据流向，并给出可回滚的处置 | `scoop install noir` | portable zip 官方 release | 0.4.5 | 2026-11-05 | 2026-11-22 |
| 22 | [LibreDWG](https://github.com/LibreDWG/libredwg) — GNU LibreDWG：免费开源的 DWG 文件读写 C 库，附带 dwgread / dwg2dxf / dxf2dwg / dwggrep / dwglayers 等命令行工具 | `scoop install libredwg` | 多架构 zip 官方 release（CLI 工具） | 0.14 | 2026-11-05 | 2026-11-05 |
| 23 | [Oink](https://github.com/oinkvm/oink) — 让多台电脑协同工作：跨 Mac/PC 共享键盘、鼠标、触控板、剪贴板、拖放与音频 | `scoop install oink` | MSI 官方 release（手动安装） | 0.3.2 | 2026-11-05 | 2026-11-05 |
| 24 | [Rust-Frp](https://github.com/Nu0vo1212/Rust-Frp) — Rust 版 FRP 客户端/服务端（兼容 Go 原版 frp） | `scoop install rustfrp` | zip 官方 release（shim: rustfrpc/rustfrps；持久化 frpc.toml/frps.toml） | 0.7.10 | 2026-11-04 | 2026-11-21 |
| 25 | [Magpie](https://github.com/yetone/magpie) — AI 模型路由/切换工具：Codex 用 DeepSeek、Claude Code 用 Kimi 等（菜单栏切换） | `scoop install magpie` | 多架构 portable exe 官方 release | 0.1.4777 | 2026-11-03 | 2026-11-25 |
| 26 | [XL Translator](https://github.com/KlaraGraff/XL_Translator) — 大模型文档翻译工具（Excel / Word / PDF / CAD，双语对照 + 翻译记忆库） | `scoop install xltranslator` | 单 exe 官方 release（NSIS 解包） | 10.5.1 | 2026-10-31 | 2026-11-03 |
| 27 | [DashBeam](https://github.com/tonyantony300/dashbeam) — 近距离与跨网络文件分享工具 | `scoop install dashbeam` | 多架构 portable zip 官方 release | 0.7.2 | 2026-10-31 | 2026-10-31 |
| 28 | [EditHere](https://github.com/Inginnng/EditHere) — 截图/标注并直接让 AI 调整布局的桌面工具 | `scoop install edithere` | zip 官方 release（仅 x64） | 0.13.7 | 2026-10-30 | 2026-11-20 |
| 29 | [微信 WeChat](https://github.com/cscnk52/wechat-windows-versions) — 腾讯社交聊天应用（版本镜像：cscnk52/wechat-windows-versions） | `scoop install wechat` | 单 exe 官方 release（7z 解包） | 4.2.1.9 | 2026-10-10 | 2026-11-25 |
| 30 | [BrimDeck](https://github.com/MoFeng2223/BrimDeck) — Windows 11 灵动岛（AI 编程额度/用量、音乐控制等） | `scoop install brimdeck` | 多架构官方 release（x64 便携 zip / Setup） | 1.3.3 | 2026-10-29 | 2026-11-22 |
| 31 | [Inno Setup](https://www.jrsoftware.org/isinfo.php) — Windows 安装程序制作工具（installer 静默安装，覆盖 extras 解包） | `scoop install inno-setup` | 单 exe 官方 release（installer 静默安装） | 7.1.1 | 2026-10-29 | 2026-10-31 |
| 32 | [MiHome-Windows](https://github.com/huanyuejue/MiHome-Windows) — 米家设备 Windows 桌面控制端（扫码登录，本地查看/控制设备） | `scoop install mihome` | portable zip 官方 release | 0.5.0 | 2026-10-28 | 2026-11-02 |
| 33 | [MiniDock](https://github.com/wang01116/MiniDock) — 极简 Windows dock 栏工具 | `scoop install minidock` | 单 exe 官方 release | 2.8.5 | 2026-10-28 | 2026-11-23 |
| 34 | [sdkm](https://github.com/borenchan/sdkmate) — 全栈开发者的跨平台 SDK 版本管理器：Java / Node.js / Python / Maven / Go 等 40+ 工具一键安装与切换（Rust 编写，约 4MB 单文件） | `scoop install sdkm` | zip 官方 release（安装时自动 init） | 0.6.0 | 2026-10-24 | 2026-11-20 |
| 35 | [网易UU远程](https://uuyc.163.com/) — 超低延迟的远程控制工具（Windows / macOS / iOS / Android / TV） | `scoop install uuyc` | NSIS 安装器安装（服务/驱动注册） | 4.48.4 | 2026-10-10 | 2026-11-25 |
| 36 | [evanOCR](https://github.com/duyuanfu/evan-ocr) — C++ 写了一款比 Snipaste/PixPin 更爽的免费截贴图 OCR 神器 | `scoop install evanocr` | portable zip 官方 release | 1.2.1 | 2026-10-18 | 2026-10-21 |
| 37 | [Sunpack](https://github.com/Qinjingxue/Sunpack) — Windows 全自动压缩包处理工具：后台监控文件夹、自动识别并解压、递归处理与崩溃恢复 | `scoop install sunpack` | 多架构 exe 官方 release（Inno Setup 解包） | 1.5.2 | 2026-10-15 | 2026-11-21 |
| 38 | [SVCode](https://github.com/mnigc/SVCode) — 轻量的「编辑优先」文本与代码编辑器（内置预览，Windows 优先） | `scoop install svcode` | 单 exe 官方 release（Tauri 解包） | 0.3.2 | 2026-10-14 | 2026-10-14 |
| 39 | [知语输入法](https://github.com/w3c0929/zhiyi_ime) — 知意输入法的自研进阶版（语音输入 / 划词翻译等，与知意输入法可共存）：自管理式安装器 script 形态装到 persist + 注册 IME | `scoop install zhiyuime` | 单 exe 官方 release（installer 注册） | 1.7.77 | 2026-10-14 | 2026-11-14 |
| 40 | [StarPie](https://github.com/Star-Pie/StarPie) — 现代化 Windows 鼠标轮盘手势系统：按住键呼出轮盘、自定义手势动作与快捷键（Lightweight 便携版 zip） | `scoop install starpie` | zip 官方 release | 2.0.0 | 2026-10-13 | 2026-10-18 |
| 41 | [Ludusavi](https://github.com/mtkennerly/ludusavi) — PC 游戏存档备份与恢复工具：自动扫描识别游戏、批量备份/还原存档、支持 6000+ 游戏清单与多存档槽位 | `scoop install ludusavi` | 多架构 zip 官方 release | 0.31.0 | 2026-10-13 | 2026-10-13 |
| 42 | [Filee](https://github.com/w3c0929/Filee) — 免费开源文件转换器：拖拽即转 180+ 格式（图片 / PDF / Word / Excel / PPT / HWP / 视频 / 音频 / 电子书 / 压缩包），全程离线、无需上传 | `scoop install filee` | portable zip 官方 release | 2.5.9 | 2026-10-12 | 2026-11-17 |
| 43 | [知意输入法](https://github.com/dd1000001000/zhiyi_ime) — 按上文推荐候选的拼音输入法（自管理式安装器：script 形态装到 persist + 注册 IME，自动跳过 bin） | `scoop install zhiyiime` | 单 exe 官方 release（installer 注册） | 1.7.2 | 2026-10-12 | 2026-11-22 |
| 44 | [SwitchHosts](https://github.com/w3c0929/SwitchHosts) — Hosts 文件快速切换管理工具（自建构建仓库） | `scoop install switchhosts` | zip 官方 release（自建构建） | 5.1.4 | 2026-10-10 | 2026-11-16 |
| 45 | [TaskbarPopup](https://github.com/DM74164/TaskbarPopup) — Windows 11 任务栏增强：最大化时隐藏任务栏让窗口铺满屏幕；长按 Win 弹出液态玻璃风格迷你任务栏（窗口缩略图 / 音量亮度 / 打字筛选） | `scoop install taskbarpopup` | zip 官方 release | 1.2.1 | 2026-10-12 | 2026-11-07 |
| 46 | [FreeLLM API](https://github.com/tashfeenahmed/freellmapi) — 免费 LLM API 聚合网关：34 家免费提供商、635 个免费模型端点统一为一个 /v1 接口（智能路由 / 自动故障转移 / 密钥加密） | `scoop install freellmapi` | zip 官方 release | 0.16.43 | 2026-10-11 | 2026-11-25 |
| 47 | [CC Switch](https://github.com/farion1231/cc-switch) — 多 AI 编程助手（Claude Code / Codex / OpenCode 等）的桌面配置切换器（跨平台 All-in-One） | `scoop install cc-switch` | 多架构 portable zip 官方 release | 4.0.40 | 2026-10-10 | 2026-11-24 |
| 48 | [BDL](https://github.com/Yuelioi/bdl) — Bilibili 下载器（Rust 编写；4K、UP 主空间、批量、字幕等） | `scoop install bdl` | 单 exe 官方 release（NSIS 解包） | 0.12.5 | 2026-10-10 | 2026-11-24 |
| 49 | [KeyCrash](https://github.com/Yuelioi/keycrash) — Windows 快捷键冲突检测工具（一按，找到快捷键冲突 / A Windows shortcut conflict detector） | `scoop install keycrash` | zip 官方 release | 0.3.1 | 2026-10-10 | 2026-11-01 |
| 50 | [SuMail](https://github.com/w3c0929/sumail-releases) — SuMail 桌面版（Windows 桌面版安装包与发布资产；源码仓库为私有） | `scoop install sumail` | zip 官方 release | 0.0.1 | 2026-10-10 | 2026-10-10 |
| 51 | [DiskButler](https://github.com/YGTQ3/disk-butler) — C 盘管家：给普通人的 Windows 磁盘与内存维护助手（Tauri 2 + React） | `scoop install diskbutler` | 多架构 exe 官方 release（Tauri 解包） | 0.8.0 | 2026-10-10 | 2026-10-10 |
| 52 | [moonup](https://github.com/chawyehsu/moonup) — MoonBit 多版本管理器（Manage multiple MoonBit installations with ease） | `scoop install moonup` | zip 官方 release | 0.6.1 | 2026-10-10 | 2026-10-10 |
| 53 | [RustMusic](https://github.com/LingyunStudio/RustMusic) — 精美的高性能桌面音乐播放器（Rust + Tauri 2 + React）：本地曲库 / 网易云 / QQ 音乐 / QRC 逐字歌词 / 桌面歌词 / 10 段均衡器 | `scoop install rustmusic` | Inno Setup 官方 release（解包） | 0.7.4 | 2026-10-10 | 2026-11-15 |
| 54 | [Kazumi](https://github.com/Predidit/Kazumi) — 基于自定义规则的番剧采集 APP（流媒体在线观看、弹幕、实时超分辨率） | `scoop install kazumi` | zip 官方 release | 2.4.6 | 2026-10-10 | 2026-11-22 |
| 55 | [VTracer](https://github.com/visioncortex/vtracer) — 位图转矢量图工具（Raster to Vector Graphics Converter） | `scoop install vtracer` | 单 exe 官方 release（NSIS 解包） | 1.0.0-alpha.4 | 2026-10-10 | 2026-10-10 |
| 56 | [OilGit](https://github.com/oil-oil/oil-git) — 面向 AI 项目开发者的只读 Git 可视化桌面应用（Windows / macOS） | `scoop install oilgit` | 单 exe 官方 release（Tauri 解包） | 0.1.0-test.1 | 2026-10-10 | 2026-10-10 |
| 57 | [AnClicker](https://github.com/714248411/AnClicker) — Windows 自动化工作台：表格与流程图双编辑、可拖拽指令、深浅主题和长循环缓存保护 | `scoop install anclicker` | zip 官方 release | 1.9.3 | 2026-10-10 | 2026-11-25 |
| 58 | [Xtranslate](https://github.com/hopechen067/Xtranslate) — 中英互译输入法：热键呼出、打字即译、回车粘贴、口语化 | `scoop install xtranslate` | 单 exe 官方 release（NSIS 解包） | 0.1.6 | 2026-10-10 | 2026-10-10 |
| 59 | [PawnIO](https://github.com/namazso/PawnIO.Setup) — Pawn 语言工具套件（官方安装器） | `scoop install pawnio` | 单 exe 官方 release | 2.2.0 | 2026-10-10 | 2026-10-10 |
| 60 | [EcoPaste](https://github.com/EcoPasteHub/EcoPaste) — 跨平台剪贴板管理工具 | `scoop install ecopaste` | 多架构 exe 官方 release（NSIS 解包） | 1.1.0 | 2026-10-10 | 2026-10-10 |
| 61 | [BongoCat](https://github.com/ayangweb/BongoCat) — 跨平台桌面宠物互动小工具（开源） | `scoop install bongocat` | 单 exe 官方 release（NSIS 解包） | 2.4.1 | 2026-10-10 | 2026-10-29 |
| 62 | [DeepSeek Harness](https://www.deepseek.com/en/harness/) — DeepSeek 桌面客户端（官方直链，NSIS 安装器 7z 解包便携） | `scoop install dsh` | 单 exe 官方 nightly 直链（NSIS 解包） | 0.2.3-alpha.2 | 2026-10-10 | 2026-11-23 |
| 63 | [KVMem / NInfer](https://github.com/kvmem/kvmem-llama.cpp) — 统一版：NInfer + PolyStrata 双后端（.ninfer 三元模型 / GGUF），RTX 40 预编译包，内嵌控制台/聊天 | `scoop install kvninfer` | zip 官方 release | 0.19.1 | 2026-10-12 | 2026-10-31 |
| 64 | [Rayburst](https://github.com/AnInsomniacy/rayburst) — 开源下载管理器（基于 Aria2 Next 引擎，NSIS 安装器解包便携） | `scoop install rayburst` | 多架构 exe 官方 release（NSIS 解包） | 4.1.2 | 2026-10-10 | 2026-11-10 |
| 65 | [ZTools](https://github.com/ZToolsCenter/ZTools) — uTools 的开源实现，高性能可扩展的应用启动器与插件平台 | `scoop install ztools` | zip 官方 release | 3.2.0 | 2026-10-10 | 2026-10-10 |
| 66 | [AI-Vault (updist)](https://github.com/ErgeAIA/updates-dist) — 本地优先的 AI 创作工作台：Skill/Prompt/MCP/工作流统一管理并分发 46+ Agent | `scoop install updist` | exe 官方 release（Tauri 解包） | 0.7.4 | 2026-10-10 | 2026-11-19 |
| 67 | [llama.cpp Prism](https://github.com/PrismML-Eng/llama.cpp) — llama.cpp 分支（CUDA 主程序 + cudart 运行库配对合并，--more 收录） | `scoop install prllama` | 多架构 zip 官方 release | prism-b12178-03ec600 | 2026-10-10 | 2026-11-25 |
| 68 | [图吧工具箱 CE](https://github.com/luolangaga/tubatools) — 图吧工具箱 TubaWinUI3 便携版，45+ 内置工具 | `scoop install tubatools` | zip 官方 release | 1.9.1 | 2026-10-10 | 2026-11-15 |
| 69 | [Finch](https://github.com/finchtoys/finch-releases) — 桌面 AI 社区中心，停在你桌面上的小灵雀，帮你衔来线索、织成脉络 | `scoop install finch` | 单 exe 官方 release | 1.8.2 | 2026-10-10 | 2026-11-24 |
| 70 | [Magpiee (实验版)](https://github.com/SAOG0721/Magpie) — 游戏画面缩放/超分工具的非官方实验 fork（原 magpie 清单改名，与官方 Magpie 区分；shim: magpiee.exe） | `scoop install magpiee` | zip 官方直链 | 0.6.14-experimental | 2026-11-03 | 2026-11-24 |
| 71 | [青简 Qingjian](https://github.com/qingjian-team/qingjian) — Rust 写的拼音输入法，候选词旁多一条正在学的语言的译词 | `scoop install qingjian` | exe 官方 release（installer 注册） | 0.3.5 | 2026-10-10 | 2026-11-20 |
| 72 | [Windows App SDK 运行时](https://learn.microsoft.com/windows/apps/windows-app-sdk/) — Microsoft Windows App Runtime (WindowsAppSDK) 2.7 运行时官方直链（安装时自动静默安装） | `scoop install winsdk` | 单 exe 官方直链（post_install 静默安装） | 2.7.0 | 2026-10-10 | 2026-11-18 |
| 73 | [Netcatty](https://github.com/binaricat/Netcatty) — SSH 工作区、SFTP 与终端一体的跨平台客户端 | `scoop install netcatty` | NSIS 解包便携（Netcatty.exe，data 持久化） | 1.1.90 | 2026-10-10 | 2026-10-26 |
| 74 | [Context Menu Manager Plus](https://github.com/PLFJY/ContextMenuMgr) — Windows 右键菜单管理工具 | `scoop install cmm-plus` | 多架构 portable zip | 1.8.1 | 2026-10-10 | 2026-11-20 |
| 75 | [Floral Notepaper](https://github.com/Achilng/floral-notepaper) — 花笺 Markdown 桌面便签 | `scoop install floral` | 多架构 exe 官方 release | 1.2.0 | 2026-10-10 | 2026-10-10 |
| 76 | [Cherry Studio](https://github.com/CherryHQ/cherry-studio) — AI 智能助手，支持多种大模型 | `scoop install cherry` | 多架构 portable exe | 2.2.3 | 2026-10-10 | 2026-11-20 |
| 77 | [embyToLocalPlayer](https://github.com/kjtsune/embyToLocalPlayer) — Emby/Jellyfin 调用外部播放器 | `scoop install etlp` | 多架构 zip 官方 release | 2026.07.18 | 2026-10-10 | 2026-10-10 |
| 78 | [File Converter](https://github.com/Tichau/FileConverter) — 右键菜单文件转换压缩工具 | `scoop install fileconv` | MSI 官方 release | 2.2 | 2026-10-10 | 2026-10-10 |
| 79 | [TOKENICODE DeepSeek Alpha](https://github.com/mistydew/tokenicode-deepseek-alpha) — DeepSeek/CC Switch TOKENICODE 分支 | `scoop install tokenicode` | 单 exe 官方 release | 1.0.8 | 2026-10-10 | 2026-10-10 |
| 80 | [MSST-GUI](https://github.com/AliceNavigator/Music-Source-Separation-Training-GUI) — 音乐源分离推理工具 | `scoop install msst-gui` | 单 exe 中文版 | 1.4.0 | 2026-10-10 | 2026-10-10 |
| 81 | [Lertaro](https://github.com/Lertaro/Lertaro) — 本地文件搜索与生产力工具（Everything/Listary 替代品，C# WPF + NT 服务，NTFS MFT 解析与实时 USN 监控） | `scoop install lertaro` | 多架构 portable zip 官方 release | 5.13.7 | 2026-10-10 | 2026-11-24 |
| 82 | [BeeLlama](https://github.com/Anbeeld/beellama.cpp) — llama.cpp 分支，KV 缓存精度优化，更长上下文同显存更高精度（Windows CUDA 13.3） | `scoop install beellama-cpp` | portable zip 官方 release (CUDA 13.3) | 0.5.0 | 2026-10-10 | 2026-11-19 |
| 83 | [baulk](https://github.com/baulk/baulk) — Minimal Package Manager for Windows | `scoop install baulk` | 多架构 portable zip | 6.1.0 | 2026-10-10 | 2026-10-10 |
| 84 | [Keyviz](https://github.com/mulaRahul/keyviz) — 键盘/鼠标操作实时可视化 | `scoop install keyviz` | MSI 官方 release | 2.1.1 | 2026-10-10 | 2026-10-10 |
| 85 | [Windows磁盘迁移工具](https://github.com/bjfwan/windows-disk-tool) — 智能扫描、批量迁移、符号链接 | `scoop install windisktool` | 单 exe 官方 release | 2.0 | 2026-10-10 | 2026-10-10 |
| 86 | [QuickLook CAD 插件](https://github.com/emako/QuickLook.Plugin.CADImport) — 预览 CAD 文件格式 | `scoop install qlcad` | qlplugin 官方 release | 1 | 2026-10-10 | 2026-10-10 |
| 87 | [QuickLook Office 插件](https://github.com/QL-Win/QuickLook.Plugin.OfficeViewer) — 预览 Word/Excel/PPT 文件 | `scoop install qloffice` | qlplugin 官方 release | 6 | 2026-10-10 | 2026-10-10 |
| 88 | [QuickLook Git 插件](https://github.com/Chendaqian/QuickLook.Plugin.GitFolderViewer) — 预览 .git 文件夹信息 | `scoop install qlgit` | qlplugin 官方 release | 1.0.1 | 2026-10-10 | 2026-11-05 |
| 89 | [ComfyUI](https://github.com/Comfy-Org/ComfyUI) — AI图像生成扩散模型GUI，支持NVIDIA GPU | `scoop install comfyui` | portable 7z 官方 release | 0.46.0 | 2026-10-10 | 2026-11-19 |
| 90 | [Cinetry](https://github.com/gstory0404/Cinetry) — 多媒体播放器，支持多服务器聚合搜索 | `scoop install cinetry` | zip 官方 release | 0.8.5 | 2026-10-10 | 2026-11-23 |
| 91 | [EServer](https://github.com/xianyunleo/EServer) — Nginx/PHP/MySQL/Redis 集成环境 | `scoop install eserver` | 多架构 zip 官方 release | 6.2.2 | 2026-10-10 | 2026-11-04 |
| 92 | [Windows Terminal](https://github.com/microsoft/terminal) — 微软新一代命令行终端 | `scoop install terminal` | 多架构 portable zip | 1.25.3131.0 | 2026-10-10 | 2026-11-12 |
| 93 | [cc-haha / Claude Code Haha](https://github.com/NanmiCoder/cc-haha) — 本地优先的跨平台 Claude Code / AI Agent 桌面工作台：多 Agent 协作、Git Worktree、代码 Diff、技能市场、多模型、Computer Use、桌面宠物；支持微信、飞书、钉钉及 H5 等远程访问。 | `scoop install cc-haha` | 多架构 portable exe | 0.8.0 | 2026-10-10 | 2026-11-25 |
| 94 | [Amcfy Music](https://github.com/amcfy-music/amcfy-music) — 跨平台音乐播放器 | `scoop install amcfy-music` | portable zip 官方 release | 1.2.15 | 2026-10-10 | 2026-10-25 |
| 95 | [LiteMonitor](https://github.com/Diorser/LiteMonitor) — 桌面硬件性能监控 | `scoop install litemonitor` | portable zip 官方 release | 1.3.6 | 2026-10-10 | 2026-10-10 |
| 96 | [PixPin](https://pixpin.cn/) — 截图标注工具（官方直链，Inno Setup） | `scoop install pixpin` | Inno Setup 官方直链 | 3.6.6.0 | 2026-10-10 | 2026-10-30 |
| 97 | [WindowsClear](https://github.com/tanaer/WindowsClear) — C 盘清理工具 | `scoop install windowsclear` | 单 exe 直链 | 0.1.3 | 2026-10-10 | 2026-10-10 |

### 本地维护（自托管 Release）

| # | 软件 | 安装命令 | 类型 | 版本 | 创建 | 更新 |
|--|------|---------|------|------|------|------|
| 1 | Windows 7 WMF 5.1 (KB3191566) — Windows 管理框架 5.1 更新包（解压即用，含 MSU 与 Install-WMF5.1.ps1） | `scoop install win7wmf` | zip 便携（自托管，解压即用） | 5.1 | 2026-11-24 | 2026-11-24 |
| 2 | [INPHIC HUB](https://www.inphic.com/) — 英菲克外设设置工具 | `scoop install inphic` | 7z 便携解压即用（Inno Setup 解包） | 1.0.1.24 | 2026-10-28 | 2026-10-28 |
| 3 | ego lite — AI Agent 浏览器（Chromium 内核，可导入 Chrome 数据；让 Claude Code / Codex 等在隔离 Space 执行网页自动化） | `scoop install egolite` | 7z 便携（自托管：官方 Web 安装器目录打包） | 0.6.3.17 | 2026-10-20 | 2026-11-17 |
| 4 | [NInfer](https://github.com/w3c0929/myscoop) — 三元推理引擎（Ternary-Bonsai 模型，CUDA 13.3 sm_89，自带运行库） | `scoop install ninfer` | zip 便携（单文件服务端 + 自带运行库） | 1.2.0 | 2026-10-10 | 2026-10-10 |
| 5 | [EasyTSHARK](https://github.com/xuanyuanzhifeng/easytshark) — 网络抓包分析工具（基于 Tshark 内核） | `scoop install easytshark` | zip 便携解压即用 | 1.0.2 | 2026-10-10 | 2026-10-10 |
| 6 | BT种子转磁力链工具 — BT种子转磁力链接 | `scoop install btseed` | zip 便携解压即用 | 1.0 | 2026-10-10 | 2026-10-10 |
| 7 | WPS Office — 办公套件（文字/表格/演示） | `scoop install wps` | 单 exe 手动安装 | 26899 | 2026-10-10 | 2026-10-10 |
| 8 | 公众号排版器 — 微信公众号文章排版工具 | `scoop install gzh-formatter` | 单 exe 便携 | 3.7.3 | 2026-10-10 | 2026-10-10 |
| 9 | [Cloudflare WARP](https://one.one.one.one/) — 网络加速与安全工具 | `scoop install cfwarp` | MSI 手动安装（多版本自托管，固定 tag） | 2026.8.2115.0 | 2026-10-10 | 2026-11-24 |
| 10 | HCSStudio — 汉化工具 | `scoop install hcsstudio` | 多版本自托管 exe（固定 tag + $version 模板） | 1.9.261122 | 2026-10-10 | 2026-11-23 |
| 11 | 卡卡字幕助手 VideoCaptioner — AI视频字幕生成工具 | `scoop install video-captioner` | 单 exe 手动安装 | 1.3.3 | 2026-10-10 | 2026-10-10 |
| 12 | Athena-A 汉化版 — 软件本地化翻译工具 | `scoop install athena-loc` | 7z 便携解压即用 | 4.13 | 2026-10-10 | 2026-10-10 |
| 13 | 软媒PCMaster — 系统工具合集 | `scoop install pcmaster` | zip 便携解压即用 | 1.0 | 2026-10-10 | 2026-10-10 |
| 14 | MusicTag — 音乐标签编辑工具 | `scoop install musictag` | 7z 便携解压即用 | 1.0.9.0 | 2026-10-10 | 2026-10-10 |
| 15 | miaomi — 喵咪客户端 | `scoop install miaomi` | NSIS 解包便携（主程序 clash-verge.exe） | 2.4.5 | 2026-10-10 | 2026-10-23 |
| 16 | Bandicam — 班班录屏，高性能屏幕录制 | `scoop install bandicam` | 7z 便携解压即用 | 8.2.2.2531 | 2026-10-10 | 2026-10-10 |
| 17 | VP9 视频解码器 — Windows VP9 视频编解码扩展 | `scoop install vp9-video-extensions` | Appx 手动安装 | 1.0.50481.0 | 2026-10-10 | 2026-10-10 |
| 18 | Edge WebView2 运行时 — 现代 Windows 应用必备组件 | `scoop install webview2-runtime` | 单 exe 手动安装 | 1.3.213.7 | 2026-10-10 | 2026-10-10 |
| 19 | HardLinkShellExt — Windows 软硬链接 Shell 扩展工具 | `scoop install hardlinkshellext` | 单 exe 手动安装 | 3.9.3.5 | 2026-10-10 | 2026-10-10 |
| 20 | UltraISO Premium — 软碟通光盘映像制作编辑转换工具 | `scoop install ultraiso` | 单 exe 手动安装 | 9.7.0 | 2026-10-10 | 2026-10-10 |
| 21 | [EdgeBlock](https://www.sordum.org/edge-blocker/) — Edge 浏览器禁用/启用工具 | `scoop install edgeblock` | zip 便携解压即用 | 2.0 | 2026-10-10 | 2026-10-10 |
| 22 | DingTalk Downloader — 钉钉下载工具 | `scoop install dingtalk-downloader` | 单 exe 手动安装 | 1.0.0.10 | 2026-10-10 | 2026-10-10 |
| 23 | HiPC — 电脑助手远程控制工具 | `scoop install hipc` | 单 exe 手动安装 | 5.6.6.174a | 2026-10-10 | 2026-10-10 |
| 24 | QQ — 腾讯即时通讯客户端 | `scoop install qq` | 单 exe 手动安装 | 9.9.31 | 2026-10-10 | 2026-10-10 |
| 25 | 企业微信 WeCom — 腾讯企业通讯平台 | `scoop install wecom` | 单 exe 手动安装 | 5.0.9.6029 | 2026-10-10 | 2026-10-10 |
| 26 | waifu2x-caffe — 图片无损放大超分辨率工具 | `scoop install waifu2x-caffe` | zip 便携解压即用 | 1.0 | 2026-10-10 | 2026-10-10 |
| 27 | Visual Studio BuildTools — VS 2026 生成工具安装器 | `scoop install vs-buildtools` | 单 exe 手动安装 | 18.7.11925.98 | 2026-10-10 | 2026-10-10 |
| 28 | GetDict — 字典转化工具，字典格式编码转换 | `scoop install getdict` | 单 exe 手动安装 | 1.0 | 2026-10-10 | 2026-10-10 |
| 29 | ChromeSetup — Google Chrome 安装器 | `scoop install chromesetup` | 单 exe 手动安装 | 147.0.7703.0 | 2026-10-10 | 2026-10-10 |
| 30 | WCAP — Windows 屏幕录制工具 | `scoop install wcap` | zip 便携解压即用 | 1.0 | 2026-10-10 | 2026-10-10 |
| 31 | [DropIt](http://www.dropitproject.com/) — 文件自动分类处理 | `scoop install dropit` | portable zip | 8.5.2 | 2026-10-10 | 2026-10-10 |
| 32 | [GstarCAD Pro 2022](https://www.gstarcad.net/) — DWG 兼容 CAD | `scoop install gstarcad` | portable zip | 2022 | 2026-10-10 | 2026-10-10 |
| 33 | 静音移除工具 — 音视频静音段自动删除 | `scoop install cutsilence` | zip 便携解压即用 | 1.0 | 2026-10-10 | 2026-10-10 |
| 34 | [录音精灵](https://www.apowersoft.cn/streaming-audio-recorder) — 声卡录音工具 | `scoop install audio-recorder` | portable zip | 4.2.3 | 2026-10-10 | 2026-10-10 |
| 35 | HEU KMS Activator — Windows/Office 激活工具 | `scoop install heu-kms` | 单 exe 手动安装 | 42.3.0 | 2026-10-10 | 2026-10-10 |
| 36 | VBA 运行库 — Visual Basic for Application 运行时 | `scoop install vba-runtime` | 单 exe 手动安装 | 7.0.1590 | 2026-10-10 | 2026-10-10 |
| 37 | 驱动精灵 — 驱动管理更新工具绿色版 | `scoop install driver-genius` | 单 exe 手动安装 | 9.70 | 2026-10-10 | 2026-10-10 |
| 38 | 360驱动大师 — 驱动管理工具绿色版 | `scoop install 360-driver-master` | 单 exe 手动安装 | 2.0 | 2026-10-10 | 2026-10-10 |
| 39 | [BOOTICE](http://www.ipauly.com/) — 启动扇区管理/BCD 编辑工具 x64 | `scoop install bootice` | 单 exe 手动安装 | 1.3.4.0 | 2026-10-10 | 2026-10-10 |
| 40 | DNS 工具 DnsTools — 网络 DNS 诊断工具 | `scoop install dnstools` | 单 exe 手动安装 | 1.2.3 | 2026-10-10 | 2026-10-10 |
| 41 | FPS Keeper — 游戏帧率保持工具 | `scoop install fps-keeper` | 单 exe 手动安装 | 1.0 | 2026-10-10 | 2026-10-10 |
| 42 | PDF24 转换器 — 文档转换工具 | `scoop install pdf24-converter` | 单 exe 手动安装 | 1.0 | 2026-10-10 | 2026-10-10 |
| 43 | PDF 合并及分割 — PDF 合并分割工具 | `scoop install pdf-merge-split` | 单 exe 手动安装 | 1.0 | 2026-10-10 | 2026-10-10 |
| 44 | 系统垃圾清理 — 系统垃圾清理工具 | `scoop install system-cleaner` | 单 exe 手动安装 | 1.0 | 2026-10-10 | 2026-10-10 |
| 45 | Robocopy GUI — Windows 文件复制图形界面 | `scoop install robocopy-gui` | 单 exe 手动安装 | 1.3 | 2026-10-10 | 2026-10-10 |
| 46 | WinHex 编译版 — 十六进制编辑器 | `scoop install winhex` | 单 exe 手动安装 | 1.0 | 2026-10-10 | 2026-10-10 |
| 47 | 搜狗五笔 — 中文五笔输入法 | `scoop install sogou-wubi` | 单 exe 手动安装 | 1.0 | 2026-10-10 | 2026-10-10 |
| 48 | 谷歌翻译检查器 — 翻译质量验证工具 | `scoop install google-translate-checker` | 单 exe 手动安装 | 1.0 | 2026-10-10 | 2026-10-10 |
| 49 | 数字键盘练习 — 数字键盘打字练习 | `scoop install numpad-practice` | 单 exe 手动安装 | 1.0 | 2026-10-10 | 2026-10-10 |
| 50 | 文件夹加密 — 文件夹/文件加密工具 | `scoop install folder-encrypt` | 单 exe 手动安装 | 1.0 | 2026-10-10 | 2026-10-10 |
| 51 | GIF 工具 — GIF 制作工具 | `scoop install gif-tool` | 单 exe 手动安装 | 1.0 | 2026-10-10 | 2026-10-10 |
| 52 | 五金工具 — 五金计算工具 | `scoop install wujin` | 单 exe 手动安装 | 1.0 | 2026-10-10 | 2026-10-10 |
| 53 | [GoldenDict](https://github.com/goldendict/goldendict) — 离线词典翻译工具 | `scoop install goldendict` | zip 便携解压即用 | 1.0 | 2026-10-10 | 2026-10-10 |
| 54 | PointerStick — 屏幕教鞭教学工具 | `scoop install pointerstick` | zip 便携解压即用 | 1.0 | 2026-10-10 | 2026-10-10 |
| 55 | [Sublime Text](https://www.sublimetext.com/) — 代码编辑器 x64 | `scoop install sublime-text@4200/@4207` | zip 便携解压即用 | 4200 / 4207 | 2026-10-10 | 2026-11-23 |
| 56 | Epic Pen — 屏幕标注白板教学工具 | `scoop install epicpen` | portable zip | 3.7.31 | 2026-10-10 | 2026-10-10 |
| 57 | Tickeys — 机械键盘打字音效 | `scoop install tickeys` | MSI 手动安装 | 1.2.0 | 2026-10-10 | 2026-10-10 |
| 58 | [Anytxt](https://anytxt.net/) — 图片文字搜索 OCR 工具 | `scoop install anytxt` | 单 exe 手动安装 | 1.3.1952 | 2026-10-10 | 2026-10-10 |
| 59 | Studio One Pro 7.1 — 音乐制作 DAW | `scoop install studio-one` | portable zip | 7.1 | 2026-10-10 | 2026-10-10 |
| 60 | VAM 翻译密钥 — Virt-A-Mate 翻译资源包 | `scoop install vam-resource` | zip 资源包 | 1.22 | 2026-10-10 | 2026-10-10 |
| 61 | BeatEdit Pr — Premiere 节拍编辑插件汉化版 | `scoop install beatedit` | zip 插件包 | 2.1.003 | 2026-10-10 | 2026-10-10 |
| 62 | MdxBuilder — 字典制作转换工具 | `scoop install mdxbuilder` | zip 便携解压即用 | 3.0 | 2026-10-10 | 2026-10-10 |
| 63 | 禁用 Xbox GameBar — 弹窗禁用脚本 | `scoop install disable-gamebar` | zip 脚本 | 1.0 | 2026-10-10 | 2026-10-10 |
| 64 | [IObit Unlocker](https://www.iobit.com/en/iobit-unlocker.php) — 文件解锁删除 | `scoop install iobit` | 单 exe 手动安装 | 1.3.0.11 | 2026-10-10 | 2026-10-10 |
| 65 | [HiBit Uninstaller](https://www.hibitsoft.ir/Uninstaller.html) — 强力卸载工具 | `scoop install hibituninstaller` | 单 exe 便携 | 4.0.10 | 2026-10-10 | 2026-10-10 |
| 66 | [Beyond Compare 5](https://www.scootersoftware.com/) — 文件对比工具（汉化版） | `scoop install bcompare` | portable zip | 5.2.5.32528 | 2026-10-10 | 2026-10-10 |
| 67 | [Termius](https://termius.com/) — SSH 客户端汉化版 | `scoop install termius` | portable zip | 9.40.1 | 2026-10-10 | 2026-10-10 |
| 68 | [Internet Download Manager](https://www.internetdownloadmanager.com/) — 下载加速器 | `scoop install idm` | 单 exe 手动安装 | 6.4.3 | 2026-10-10 | 2026-10-10 |
| 69 | [Bandizip 6.18](https://www.bandisoft.com/bandizip/old/6/) — 压缩工具（最后无广告版） | `scoop install bandizip6` | 单 exe 手动安装 | 6.18 | 2026-10-10 | 2026-11-09 |
| 70 | [2345看图王](https://pic.2345.cc/) — 图片查看编辑工具 | `scoop install 2345pic` | portable zip（安装时注册图片关联） | 10.8.0.9683 | 2026-10-10 | 2026-10-29 |
| 71 | [Apollo](https://github.com/ClassicOldSong/Apollo) — Sunshine 游戏串流服务端 | `scoop install apollo` | 单 exe 手动安装 | 0.4.6 | 2026-10-10 | 2026-10-10 |
| 72 | [KeyCastOW](https://github.com/brookhong/KeyCastOW) — 屏幕按键显示工具 | `scoop install keycastow` | zip 便携+自动启动 | 1.0 | 2026-10-10 | 2026-10-10 |
| 73 | [搜狗拼音](https://pinyin.sogou.com/) — 中文拼音输入法去广告精简优化版 | `scoop install sougoupy` | 单 exe 手动安装 | 16.6.0.4385 | 2026-10-10 | 2026-10-10 |
| 74 | [TinyTask](https://www.tinytask.net/) — 极简宏录制自动化 | `scoop install tinytask` | 单 exe 便携 | 1.0 | 2026-10-10 | 2026-10-10 |
| 75 | [360宽带测速](https://www.360.cn/) — 网络测速工具 | `scoop install 360bwtest` | 单 exe 便携 | 1.0 | 2026-10-10 | 2026-10-10 |
| 76 | [BTSOU](https://www.btsou.io/) — BT 搜索下载工具 | `scoop install btsou` | zip 便携解压即用 | 26.08.26.01 | 2026-10-10 | 2026-10-10 |
| 77 | [火绒系统诊断](https://www.huorong.cn/) — 安全分析与系统检查 | `scoop install sysdiag` | 单 exe 手动安装 | 6.0.11.0 | 2026-10-10 | 2026-10-10 |
| 78 | [.NET Desktop Runtime 8.0](https://dotnet.microsoft.com/) — WPF/WinForms 运行时 | `scoop install dotnet-desktopruntime` | 单 exe 手动安装 | 8.0.28 | 2026-10-10 | 2026-10-10 |
| 79 | [电视时光](https://www.dianshishiguang.com/) — 电视直播软件 | `scoop install dianshishiguang` | 单 exe 手动安装 | 2.1.2 | 2026-10-10 | 2026-10-10 |
| 80 | [R-Drive Image](https://www.drive-image.com/) — 磁盘镜像备份工具 | `scoop install rdriveimage` | zip 便携解压即用 | 7.2 | 2026-10-10 | 2026-10-10 |
| 81 | [WinMTR](https://github.com/White-Tiger/WinMTR) — 网络诊断 Ping+Traceroute | `scoop install winmtr` | zip 便携解压即用 | 0.9.2 | 2026-10-10 | 2026-10-10 |
| 82 | NetworkFixTool — 网络修复工具 | `scoop install networkfixtool` | 单 exe 便携 | 1.0 | 2026-10-10 | 2026-10-10 |
| 83 | 系统常用功能助手 — Windows 系统工具箱 | `scoop install syshelper` | 单 exe 便携 | 3.0 | 2026-10-10 | 2026-10-10 |
| 84 | [WGestures](https://github.com/yingDev/WGestures) — 全局鼠标手势（上游已归档） | `scoop install wgestures` | portable zip | 1.8.5.0 | 2026-10-10 | 2026-10-10 |
| 85 | [Uninstall Tool](https://www.crystalidea.com/uninstall-tool) — 强力卸载工具 | `scoop install uninstalltool` | portable zip | 3.4.3 | 2026-10-10 | 2026-10-10 |

---

## 安装与使用

### 1. 添加 Bucket

```powershell
scoop bucket add myscoop https://github.com/w3c0929/myscoop.git
```

> **重要提示（添加桶后必做）**：上述命令仅将本桶登记到 Scoop，**尚不足以正常使用**。还须进入 myscoop 仓库目录（如 `D:\scoop\buckets\myscoop`），**以管理员身份双击运行 `symlink.bat`**，完成本桶所需的部署——将 `manifest.ps1`、`download.ps1`、`config.json` 三个文件以软链接方式部署到 Scoop 对应位置，并把仓库 `*.bat` 链接到 `D:\scoop\shims` 以提供全局命令。**未完成该步骤前，本桶软件将无法正常安装与更新**；Scoop 自更新后亦需重新运行一次。详见下文「Scoop 辅助文件」章节。
>
> **Scoop 不在默认目录时（额外一步）**：若 Scoop 装在自定义路径（如 `D:\scoop`）而**未设置 `SCOOP` 环境变量**，第三方工具 `scoop-search` 会报 `Could not open the buckets directory: C:\Users\<用户>\scoop\buckets`——它只认 `SCOOP` 变量或默认的 `~\scoop`（`scoop` 命令本身从 shim 路径推断根目录，所以不受影响）。修复（PowerShell，普通权限即可）：
>
> ```powershell
> [Environment]::SetEnvironmentVariable("SCOOP", "D:\scoop", "User")
> ```
>
> 设置后**需重开终端**才生效；验证：`scoop-search <关键词>` 能正常列出结果。

### 2. 安装软件

```powershell
# 查看可用软件列表
scoop search myscoop

# 安装（任选其一）
scoop install cmm-plus
scoop install windowsclear

# 或指定从 myscoop 安装
scoop install myscoop/cmm-plus
```

> **多版本软件（如 Sublime Text）**：默认安装最新版（4207）；需旧版时用 `@版本号` 指定，例如：
> ```powershell
> scoop install myscoop/sublime-text@4200   # 指定安装旧版 4200
> ```
> 同一软件的各版本共存时，用 `scoop reset myscoop/sublime-text@4200` / `@4207` 切换当前版本。

### 3. 更新软件

```powershell
# 更新单个软件
scoop update cmm-plus

# 更新所有已安装的软件
scoop update *
```

### 4. 卸载

```powershell
scoop uninstall cmm-plus
```

---

## 智能模式：Scoop 工具箱文件名预选

`智能模式Scoop(3).ps1` 支持**文件名预选**：复制脚本并改名为末尾带 `(1)`-`(4)` 的形式，双击即自动执行对应菜单并退出。

> **首次运行前（必做）**：先执行一次 `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`（允许本地脚本，远程脚本仍需签名）。

| 文件名 | 自动执行行为 |
|--------|-------------|
| `智能模式Scoop.ps1`（无括号） | 打开菜单手动选择，任务完成后停留等待按键 |
| `智能模式Scoop(1).ps1` | 管理员身份全局安装 Scoop |
| `智能模式Scoop(2).ps1` | 当前用户安装 Scoop |
| `智能模式Scoop(3).ps1` | 导出 Scoop 备份（Bucket + 已装软件） |
| `智能模式Scoop(4).ps1` | 退出 |

> 括号须在文件名末尾（半角/全角均可）；加 `-Menu` 参数可强制进入菜单。

---

## Git 安全目录设置（安装 Git 后必做）

> **⚠️ 必做**：安装完 Git 后，**提前把 buckets 全局加入 Git 安全目录**，永久杜绝"可疑所有权"（dubious ownership）报错：

```powershell
git config --global --add safe.directory D:/scoop/buckets/*
```

---

## Scoop 辅助文件（本机部署）

仓库根目录提供部署到本机 Scoop 的辅助文件，用于调整 bucket 下载优先级与 GitHub 下载加速：

| 文件 | 部署位置 | 作用 |
|------|----------|------|
| `manifest.ps1` | `D:\scoop\apps\scoop\current\lib\manifest.ps1` | 修改同名软件跨 bucket 的选择顺序 |
| `download.ps1` | `D:\scoop\apps\scoop\current\lib\download.ps1` | GitHub Release 下载走加速镜像 |
| `config.json` | `%USERPROFILE%\.config\scoop\config.json` | `bucketlist` 控制仓库优先级 |

**部署方式**：运行仓库根目录的 `symlink.bat`（**需管理员权限**）——两个 `.ps1` 以**软链接**部署（`git pull` 后立即生效），`config.json` 以**镜像拷贝**部署（Scoop 自身会重写该文件，故每次重跑同步）；同时把仓库 `*.bat` 链接到 `D:\scoop\shims`。Scoop 自更新后需重跑一次。

补丁按 Scoop 版本自动分发（根 = 最新基线，`patches\<版本>\` = 冻结补丁）；升级维护流程与镜像测速细节见 `.claude/skills-myscoop/progress.md`「Scoop 库补丁与版本分发」。

### sync-chrome-to-ego.bat（Chrome → ego lite 一键同步）

双击运行，按顺序完成：**① 数据同步**（书签 / Cookie / 历史 / 密码 / 表单）→ **② 扩展同步**（复制 + 重建链接）→ **③ 启动 ego 并加载全部扩展**。

- **数据同步需要 Chrome 已关闭**；Chrome 正在运行时会自动跳过数据、只做扩展 + 启动（并提示）
- 自动备份 ego 数据到 `User Data.bak-<时间戳>`（默认保留最近 3 个），出问题可回滚
- 扩展：复制到 `D:\scoop\persist\egolite-exts\` + 纯 ASCII junction `egolite-ext\ext01…`（长中文路径会导致加载失败）；启动时用 `--load-extension` 加载全部
- **egolite 安装后会自动启动一次**（清单 `post_install`）
- 参数：`-ChromeProfile` / `-EgoProfile`、`-KeepBackups N`、`-NoData`（只做扩展）、`-NoExt`、`-NoLaunch`

原理与限制：
- **只做单向（Chrome → ego）**：ego 运行后会升级数据库 schema，反向同步可能让 Chrome 打不开；**也不能用 symlink/硬链接**——Chromium 保存文件是"写临时文件 + rename"，会替换掉链接本身，且 SQLite 运行时加锁，双进程共用会损坏
- ⚠️ **账号书签不在本地文件里**：Chrome 登录账号后书签可能只存在 `Sync Data`（`Default\Bookmarks` 长期为空）。请用 Chrome `chrome://bookmarks` → ⋮ → **导出书签**（HTML），再在 ego 的 `ego://bookmarks` → **导入书签**
- 🛡️ **书签护栏**：Chrome 本地书签数为 **0** 时跳过 Bookmarks，避免用空文件覆盖 ego 已导入的书签（曾因此丢失过一次，已从备份恢复）
- Chromium 的 `--load-extension` 是**会话级**（`location=8`），必须每次启动带参数才生效 → 所以日常请用本 bat 启动（开始菜单/桌面快捷方式也已写入参数）
- **不能靠复制 `Secure Preferences` 迁移扩展**（HMAC 完整性校验会丢弃，实测 31→3 且扩展文件被删）；扩展页「加载未打包」写 `location=4` 才真正持久，但对话框一次只能选一个目录、无法批量
- 扩展 ID 保留商店 ID；`ego://extensions` 会常驻"开发者模式扩展"提示

### symlink.bat 一键链接部署（用法）

`symlink.bat` 位于仓库根目录，一键完成两个部署文件的软链接 + `config.json` 镜像拷贝 + 仓库 `*.bat` 全局链接。

**使用步骤**：

1. **保持仓库最新**：`git pull` 拉取仓库（链接指向仓库源文件，拉取后自动生效）；
2. **以管理员身份运行**：右键 `symlink.bat` → **以管理员身份运行**（`mklink` 需要管理员权限；脚本开头会自检，无权限时提示后退出）；
3. **等待打印过程完成**，脚本分两段执行：
   - **【1/3】Scoop 库文件软链接**：先按 Scoop 版本选择补丁来源（`git describe` 取版本：版本==基线用仓库根，`patches\<版本>` 存在用专用补丁，否则根+警告，并打印所选来源），再依次处理 `manifest.ps1` / `download.ps1`——目标位置若已有旧文件先删除，再 `mklink` 建立软链接指向仓库源文件；每个文件打印 `处理文件：xxx`，成功显示 `[成功] 文件软链接生成完成`，源文件缺失显示 `跳过`，失败显示 `[失败]`；
   - **【2/3】config.json 镜像拷贝**：源（仓库 `config.json`）为权威，删除目标旧文件后 `copy /Y` 覆盖为**真实文件**（避免 Scoop 重写配置时破坏软链接），成功显示 `[成功] … 镜像拷贝完成`；
   - **【3/3】仓库 .bat → shims 链接**：把仓库根目录所有 `*.bat` 链接到 `D:\scoop\shims`（供 `cd-comfyui`、`cd-models`、`myscoop-update` 等全局命令直接调用）；
   - 结尾打印 `所有任务完成`。
4. **验证**：两个 `.ps1` 目标位置带链接标识即成功（命令行 `dir /A:L` 可列出 `<SYMLINK>`）；`config.json` 为普通文件（无链接标识），其内容应与仓库副本一致（`fc` 或哈希比对）。

**日常维护**：

- 仓库 `git pull` 更新后两个 `.ps1` 补丁**立即生效**（链接指向仓库文件）；**改过 `config.json` 后需重跑一次 `symlink.bat`**（拷贝部署，非链接）；
- **Scoop 自更新后** `current` 目录重建、链接失效——**重新以管理员身份运行一次 `symlink.bat`** 即可恢复；
- **还原为官方原版**：删除目标位置的链接文件，再 `scoop update scoop` 让 Scoop 恢复官方文件；或改用上文"部署方式一（覆盖）"。

> 注：`symlink.bat` 为 **UTF-8 无 BOM** 编码（与仓库其他 `.bat` 一致），开头自带 `chcp 65001` 切换到 UTF-8 代码页，中文在中文控制台与 UTF-8 控制台（Windows Terminal 默认）下均正常显示。
---

## 右键菜单工具（可选）

仓库根目录附带两个右键菜单小工具，与本仓库 Scoop 功能无关，按需取用：

| 文件 | 作用 | 使用方法 |
|------|------|----------|
| `添加gitbash右键菜单.reg` | 给文件夹空白处、文件夹图标、文件右键菜单添加 **Git Bash Here** 入口（路径按本机 scoop 版 Git 配置，`D:\scoop\apps\git\current\git-bash.exe`） | 双击运行，确认导入注册表即可；重启资源管理器后生效 |
| `win11右键菜单转win10菜单.bat` | **Win11 右键菜单切换工具**：1 = 转 Win10 经典右键菜单；2 = 恢复 Win11 默认菜单；0 = 退出 | 双击运行，按提示输入数字，自动重启资源管理器生效 |
---

## 获取所有权（可选）

`获取所有权.ps1` 是 Windows 全盘权限体检修复工具（源自《智能模式Scoop.ps1》的 `.ssh` 权限体检功能改造），处理旧机器/旧账号迁移数据盘遗留的权限垃圾：

| 问题 | 处理 |
|---|---|
| 残留 SID（资源管理器显示 `UNKNOWN\S-1-5-21-...`） | 只清**无法解析的孤儿 SID**，Everyone/Users/SYSTEM 等正常账号一毫不动 |
| 所有者仍是旧机器账号 | `takeown` 全盘收归当前用户 |
| 当前用户无访问权 | 补授完全控制 |

**文件名预选启动**（与智能模式同款机制）：`获取所有权(1).ps1` = 只读体检、`(2)` = 正式修复、`(3)` = 选择目录/文件（`(3e2)` 直达 E 盘第 2 项，大小写均可）、`(4)` = 粘贴路径处理；任意预选 + `-Menu` 强制显示菜单。

**常用参数**：`-DryRun` 只检测不做任何修改；`-Log` 生成 `.log` 日志 + `.acl` ACL 备份（含整体回滚命令）；`-Roots E:\` 指定目标盘/目录；`-SkipNames` 临时替换跳过清单（默认 `node_modules,.git,.svn,.hg,__pycache__,.venv,venv,site-packages,envs,pkgs` 等）；`-Rescan` 修复成功后**强制**全盘重扫验证（默认修复 0 失败时自动跳过复扫，大幅省时）。

**安全机制**：只清无法解析的孤儿 SID、不砍继承链（不做 `/inheritance:r`）、跳过 junction/符号链接/`$RECYCLE.BIN`/`System Volume Information`、修复前 Y/N 双重确认、修复后逐项复核（0 失败时跳过全盘复扫，有失败项自动复扫兜底定位残留）、非管理员拒绝修复模式。

完整使用手册见 `获取所有权.ps1使用说明.md`。

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
---

## 目录结构约定

```
myscoop/
├── .github/workflows/
│   └── auto-update.yml             ← 外部服务器每 4 小时触发；GitHub cron 每天 1 次兜底
├── bucket/                         ← 所有 manifest JSON（清单见上方收录表）
├── .claude/skills-myscoop/
│   ├── SKILL.md                    ← AI 收录技能与全部制作规则
│   └── progress.md                 ← 项目进展与决策记录
├── myscoop-update.py               ← 免下载自动更新脚本
├── patches/                        ← Scoop 库补丁（按版本分发：baseline.txt + v0.5.3/）
├── manifest.ps1 / download.ps1     ← Scoop 库补丁（最新基线）
├── config.json                     ← Scoop 配置（bucketlist 优先级）
├── symlink.bat                     ← 一键部署补丁与 shim
├── 智能模式Scoop(3).ps1            ← Scoop 工具箱（文件名预选）
├── 获取所有权.ps1                  ← Windows 权限体检修复（附使用说明.md）
├── myscoop-update.bat              ← 更新脚本的快捷入口（chcp 65001）
├── sync-chrome-to-ego.bat/.ps1     ← Chrome 数据/扩展到 ego lite 同步
├── 右键菜单/字体/ComfyUI 辅助脚本    ← 添加gitbash右键菜单.reg、win11右键菜单转win10菜单.bat、
│                                     Install-FontSystemWide.ps1、cd-comfyui.bat 等，按需取用
└── README.md                       ← 此文件
```

---

## 制作 Manifest

完整流程、资产选择规则（`score_asset` 打分、架构分组兜底）与全部教训见 **`.claude/skills-myscoop/SKILL.md`**（规则 17/20）。最小手动步骤：

```bash
python3 myscoop-update.py --add https://github.com/owner/repo --name appname   # 生成（仓库链接必须用脚本）
python3 -m json.tool bucket/appname.json && scoop cat myscoop/appname          # 验证
python3 tools/rebuild_progress.py                                              # 重建提交历史
git add bucket/ README.md .claude/skills-myscoop/progress.md && git commit -m "add appname" && git push
```

`--dl` 生成后强制下载探测（Inno/NSIS 解包、自动补 bin/shortcuts、hash 实测）；`--more` 主程序 + 运行时配对收录。字段含义见下文「附录：Manifest 字段速查」。

---

## 自动更新机制

CI 由外部定时器每 4 小时触发（GitHub 自家 cron 每天 1 次兜底），运行 `myscoop-update.py --all`：通过 GitHub Release API 的 `digest` 字段**免下载**获取新版本与 hash，自动同步 README 版本/日期列并提交推送。

- **checkver**：`{"github": "https://github.com/owner/repo"}`（自动去 `v` 前缀）；特殊 tag 用 `tag_regex`；包不在 GitHub Release 时用 `url` + `regex`。详见 SKILL 规则 5/6/20。
- **autoupdate**：新版本 URL 模板，`$version` 替换（tag 带 v 时写 `v$version`）；hash 默认不写，由 API digest 或脚本计算。
- **CI 告警**：更新/校验出现 `[警告]`/`[错误]`/`[跳过]` 时推送到企业微信。Webhook 只从仓库 Secret `WECHAT_WEBHOOK_URL` 读取，未配置则自动跳过。

维护者本地操作：

```bash
python3 myscoop-update.py --all --dry-run   # 只检查
python3 myscoop-update.py --all             # 更新（自动同步 README）
git add bucket/ README.md && git commit -m "批量更新第三方软件" && git push
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

依次尝试：7-Zip 直接解压（部分 setup 是自解压包）→ `innounp` 解 Inno Setup → 最后才考虑静默安装。判断与探测细节见 SKILL 情况 D。

### Q: zip 内文件名含中文，解压后乱码/找不到文件？

用 `installer.script` 通配匹配后重命名为 ASCII（在解压后、建 shim 前执行）：

```json
"installer": { "script": ["$exe = Get-ChildItem \"$dir\" -Filter '*-win-portable.exe' | Select-Object -First 1", "if ($exe) { Rename-Item -Path $exe.FullName -NewName 'app-name.exe' }"] },
"bin": "app-name.exe"
```

示例：gzh-formatter。

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

### Q: 注册型软件（输入法/驱动/右键菜单类）装完没生效？

输入法（TSF）需要两层登记：系统级注册 + 当前用户登记。第三方安装器常只做前者，装完语言栏里看不到。正确做法是用 `InstallLayoutOrTip` **增量**登记（**绝不要用 `Set-WinUserLanguageList`**，它是全量覆盖，会清空用户其他输入法），并重启 `ctfmon`。完整方案（含卸载清理、DLL 文件锁与 rename 兜底）见 SKILL 规则 23。

### Q: self-contained 还是 framework-dependent？

|                | self-contained        | framework-dependent     |
| -------------- | --------------------- | ----------------------- |
| 文件大小       | 大（~100MB+）         | 小（~5-10MB）           |
| 用户依赖       | 无需安装运行时        | 需预装对应运行时        |
| 推荐场景       | **推荐**，开箱即用    | 用户确认有运行时时使用   |

### Q: 软件只在 Choco 上有，如何迁移到 Scoop？

```powershell
# 1. 查看包的源码仓库
choco info <包名>
# 2. 从 GitHub 源码找 tools/chocolateyInstall.ps1 中的下载 URL
# 3. 如果没有，去 SourceForge 搜 Portable.zip
curl -s "https://sourceforge.net/projects/<项目>/files/" | grep -i portable
# 4. 下载 → 算 hash → gh release create → 创建 manifest（自托管）
```

示例：DropIt 8.5.1 — 从 `choco info dropit.portable` 追踪到 SourceForge portable zip，最终自托管到 GitHub。

---
