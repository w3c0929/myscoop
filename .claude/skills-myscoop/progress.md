# myscoop 项目进展

## 项目概述

个人 Scoop Bucket 仓库，收集 Windows 软件制作便携安装包。

```powershell
scoop bucket add myscoop https://github.com/w3c0929/myscoop.git
```

GitHub: https://github.com/w3c0929/myscoop

## 当前状态（截至 2026-08-14）

- **收录软件总数**: 105 款
- **本地维护（自托管 Release）**: 85 款
- **第三方官方（引用原项目 Release）**: 20 款

不包含上下文提到的草稿软件。

## 核心规则

1. **Release 命名规范**：包名（文件名）必须英文 → 标题中英结合 → 描述纯中文
2. **git commit 信息必须用中文**
3. **每次制作/更新后，提交前必须同步更新 README.md、progress.md（本项目进展）和 SKILL.md**
4. **Hash 获取优先使用 GitHub API**：GitHub Release API 返回的每个 asset 包含 `digest: sha256:xxx` 字段，可直接读取无需下载文件。仅在 API 不可用时才下载计算。
5. **每次提交完成后**，必须运行 `git log --oneline --decorate --graph` 并将完整输出更新到本文件的"提交历史"章节。

## 标准处理流程

### 模式 1：官方 portable zip/7z
- 直接引用官方 GitHub Release URL
- 设置 checkver + autoupdate
- 示例：contextmenumgr-plus, mykeymap, litemonitor, amcfy-music, floral-notepaper

### 模式 2：单 exe / zip 便携（自托管）
- 本地文件上传到 GitHub Release
- 示例：windowsclear, tinytask, 360bwtest, btsou, hibituninstaller, gzh-formatter（单 exe 便携）, bcompare（汉化便携 zip）, easytshark（便携 zip）

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
- 示例：apollo, iobit, idm, bandizip6, pixpin, hcsstudio, wps, sougoupy, easytshark 等

### 模式 7：MSI 手动安装
- MSI 直引上游 GitHub Release
- Scoop 对 .msi 硬编码自动解包（msiexec /a），无法禁止
- pre_install 从缓存复制 MSI 到 $dir 保存，post_install 自动启动
- Scoop 缓存文件已重命名为 `{app}#{ver}#{hash}.msi`，需用 `{appname}#*.msi` 通配符查找
- 缓存路径通过 `$dir -replace '\\apps\\.*$', '\\cache'` 推导
- 不设 bin/shortcuts/checkver/autoupdate
- 示例：fileconverter, cfwarp, keyviz

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
* a05fb0f (HEAD -> main) DropIt 更新：重新上传修改源码后的便携包
* 9a3b729 (origin/main, origin/HEAD) progress.md 更新提交历史
* bdf9491 progress.md 更新提交历史
* b8024dc DropIt 更新：重新上传便携包
* 37b2f72 progress.md 更新提交历史
* 4469fe5 progress.md 更新提交历史
* 6692dde EasyTSHARK 改为便携 zip 版：解压即用
* 07948af progress.md 更新提交历史
* b82be8e progress.md 更新提交历史
* 488a928 progress.md 更新提交历史
* b21de0d 收录 EasyTSHARK 1.0.2 网络抓包分析工具（单 exe 手动安装）
* cdc1995 progress.md 更新提交历史
* 8ebcf62 DropIt 更新至 8.5.2 便携版
* 8f1ae9f BCompare 更新：重新上传去除个人信息的便携包
* 16b3ef0 progress.md 更新提交历史
* 78e21e2 文档更新：模式 5b 补充补丁获取与打包教训
* 59c5303 progress.md 更新提交历史
* ec9d185 BCompare 更新：使用汉化完成的便携包
* b95fb3a progress.md 更新提交历史
* ee16765 BCompare 修复：按安装器行为组装纯净便携包
* b125b3d progress.md 更新提交历史
* c661315 文档新增模式 5b：Inno 解包组装完整便携目录
* aff6793 progress.md 更新提交历史
* 473a60e BCompare 重新制作：完整汉化便携包
* 0ab7efa progress.md 新增提交历史章节
* ee3f248 progress.md 全面校对更新
* 9f66ed2 规则更新：每次制作后必须同步更新 progress.md
* 4eebed6 (origin/main, origin/HEAD) SKILL.md 新增规则：禁止敏感字样
* 61cd256 BCompare 更新至 5.2.5.32528 汉化便携版
* 4074f0a (tag: v5.2.5.32528) btseed-magnet 重命名为 btseed
* 5b0d9f3 新增 Keyviz 按键可视化 + 更新 BT种子转磁力链工具
* 3783dd3 更新搜狗拼音至 16.6.0.4385 去广告精简优化版
* 9c47b23 (tag: v16.6.0.4385) 收录 WPS Office 办公套件
* 8dd0bd1 (tag: vWPS26899) gzh-formatter 更新至 3.7.3
* 255a465 (tag: v3.7.3) 收录 Windows磁盘迁移工具 windisktool
* da21fbb gzh-formatter 更新至 3.7.2
* 6083ff3 (tag: v3.7.2) 文档新增：zip 中文文件名编码损坏解决方案
* 81a4c58 gzh-formatter 中文文件名重命名为 ASCII 解决编码损坏
* 754cc73 修复 gzh-formatter 中文 exe 名 shim 创建失败
* 6de6573 收录 公众号排版器 3.3.0 便携版
* 6f7d100 (tag: v3.3.0) cloudflare-warp 重命名为 cfwarp
* b5742f8 收录 Cloudflare WARP 网络加速工具
* 47a23c0 (tag: v2026.6.850.0) 收录 HCSStudio 汉化工具
* 5aeda6e (tag: v1.0.260708) 更新 Sublime Text 4200 便携包 hash
* 3401f20 收录 QuickLook 插件 + 工具脚本 + qlplugin 自启动支持
* 52465f0 添加 Scoop 工具箱脚本
* 94c0a07 批量更新第三方软件 + 收录 ComfyUI
* e7ec7ca 更新文档：94款软件收录
* ffaf8df score_asset 新增 GPU 优先：NVIDIA > AMD > Intel
* 38186ac 收录 卡卡字幕助手 VideoCaptioner
* b170277 (tag: v1.3.3-video-captioner) 收录 Athena-A、软媒PCMaster、BT种子转磁力链工具
* 8fc57ca (tag: v4.13-athena, tag: v1.0-pcmaster, tag: v1.0-btseed) 修复 rstrip('.git') 误删含 .git 字符的仓库名
* 688e094 新增 Gitee.com 仓库支持
* 03629f8 score_asset 中文版优先；新增 music-source-separation-training-gui
* b1b5ea7 更新文档：新增 MSI 手动安装模式（模式7）
* b69ba0d MSI pre_install 改用 scooped 缓存文件名匹配
* b077420 MSI 用  推导缓存路径修复 pre_install
* 451eedf MSI 改用 installer.file 由 Scoop 原生启动安装向导
* ceea85f MSI 用 pre_install 缓存复制绕过 Scoop 自动解包
* bc2f9f6 MSI 改用 installer.script 防止 Scoop 自动解包
* 772d19a MSI 改为手动安装模式：仅下载+自启动，用户手动装到系统
* 8ee222a MSI 文件禁止自动安装，改用 lessmsi 提取
* 1a7889d 更新 MyKeymap 安装包
* d260f19 更新 MyKeymap 安装包
* 60162ce 更新 MyKeymap 安装包（移除冗余目录）
* 4a44343 修复 MyKeymap extract_dir 路径
* f5fc7f2 更新 MyKeymap 安装包
* d49cb3f 修正 README 本地维护编号连续性
* a3ae739 更新项目进展文档日期
* 32ffbaa 更新 MyKeymap 为自托管便携版
* ca61fde 收录 GetDict 字典转化工具
* 16647d4 收录 Visual Studio BuildTools 2026 安装器
* 7b587b0 (tag: v2.0-beta33-mykeymap, tag: v18.7.11925.98, tag: v1.0-waifu2x-caffe, tag: v1.0-getdict) 收录 waifu2x-caffe 图片无损放大工具
* e496531 更新 Beyond Compare 5.2.2→5.2.3 汉化便携版
* 09aa6b7 (tag: v5.2.3) 更新 Bandicam 8.1.1.2518→8.2.2.2531
* 37cd725 (tag: v9.9.31-qq, tag: v8.2.2.2531, tag: v5.0.9.6029-wecom, tag: v4.1.11-wechat) 收录钉钉下载器、HiPC、QQ、微信、企业微信五款软件
* 4ce8150 (tag: v5.6.6.174a-hipc, tag: v1.0.0.10-dingtalk-downloader) 文档：收录 Windows Terminal，同步更新计数
* d757f22 移除 screen-recorder 录屏工具
* c842fd4 收录 FPS Keeper（更新）、HardLinkShellExt、UltraISO、EdgeBlock 四款软件
* 716a464 (tag: v9.7.0, tag: v3.9.3.5, tag: v2.0-edgeblock, tag: v1.0-fps-keeper) 文档：收录 tokenicode-deepseek-alpha，更新 cc-haha 0.4.4→0.4.5
* 4dac4d9 添加 VP9 视频解码器和 Edge WebView2 运行时两个手动安装软件
* cf1e551 (tag: v1.3.213.7, tag: v1.0.50481.0) 添加 Bandicam 8.1.1.2518 班班录屏便携版
* bac12b0 修正 miaomi 描述和 Release 标题：遵守中英结合规范
* 87e3601 文档：SKILL.md 规则#10 明确区分本地维护与第三方 manifest 适用范围
* faee259 遵守规则#10：MusicTag shortcuts 名称改为中文"音乐标签编辑"
* 621ac57 文档：收录 cinetry/embytolocalplayer/eserver/fileconverter 四个第三方软件
* 0116c2e 添加 MusicTag 和 miaomi 两个软件
* c82e8d7 (tag: v2.4.5-miaomi, tag: v1.0.9.0) 文档：同步 cc-haha 收录，更新总数 67→68，修正 amcfy-music 版本号
* 729daf9 添加 cc-haha
* e22078d 添加 myscoop-update.bat 全局命令包装脚本
* 9be429d myscoop-update.py 新增 --add 模式：粘贴 GitHub 链接自动生成 manifest
* 7e4585f 更新contextmenumgr-plus.json
* eddbcf6 文档：同步 myscoop-update.py 免下载更新流程
* e2ea2fa 添加 myscoop-update.py 免下载自动更新脚本
* e150c7c 更新 contextmenumgr-plus 到 1.7.1，hash 来自 GitHub API digest
* f9406d6 更新 amcfy-music 到 1.2.2，修复 checkver 适配上游命名变更
* 8d89e9d 修正第三方 manifest：移除无效的 $url.sha256 hash 规则
* 4618f33 文档：README 全面同步 autoupdate hash 规则和 SHA256 获取方式
* 2564016 新增 cherry-studio/ChromeSetup/wcap 三个软件，修复第三方 autoupdate hash 规则
* 831da2a (tag: v147.0.7703.0, tag: v1.0-wcap) 添加项目进展文档 progress.md
* 59cbd85 添加 StudioOne/VAM/BeatEdit/MdxBuilder/DisableGamebar 五个软件
* 0e4c8c6 (tag: vVAM1.22, tag: vStudioOne7.1, tag: vMdxBuilder, tag: vDisableGamebar, tag: vBeatEdit2.1) 更新 Sublime Text 4200：重新打包，更新 hash
* 40d4511 (tag: vSublimeText4200) 添加 6 个软件：GoldenDict/PointerStick/SublimeText/EpicPen/Tickeys/Anytxt
* 8b35ecf (tag: vTickeys1.2.0, tag: vPointerStick, tag: vGoldenDict, tag: vEpicPen3.7.31, tag: vAnytxt1.3.1952) 添加 14 个单 exe 手动安装：网络工具/办公效率/系统工具/装机必备等
* ca4bae0 (tag: vWujin, tag: vWinHex, tag: vSystemCleaner, tag: vSogouWubi, tag: vRobocopyGUI1.3, tag: vPDFMergeSplit, tag: vPDF24Converter, tag: vNumpadPractice, tag: vGoogleTranslateChecker, tag: vGIFTool, tag: vFolderEncrypt, tag: vDnsTools1.2.3) 添加 heu-kms/vba-runtime/driver-genius/360-driver-master/bootice 五个单 exe 手动安装
* b4f66a9 (tag: vVBA7.0.1590, tag: vDriverGenius9.70, tag: vBOOTICE1.3.4, tag: v42.3.0, tag: v360DriverMaster2.0) 重构 README 软件表：分为本地维护和第三方官方两个分类，添加序号
* 981908c 修复 README 软件表：恢复缺失的软件名称列，添加序号
* b355e20 规范化所有 Release：标题中英结合、描述纯中文、包名英文
* 79461cf 更新规则：Release 文件名用英文，标题和描述必须用中文
* 281cff2 修复中文文件名导致下载失败：统一改为英文名上传，新增 SKILL 规则
* fcf71dc (tag: vSysHelper3.0, tag: vCutSilence, tag: vAudioRecorder4.2.3) 添加 cutsilence 和 audio-recorder（便携版和 Inno 解包版）
* 6ec9fb3 添加 gstarcad 2022（多层 NSIS 解包便携版）
* f20770d (tag: vGstarCAD2022) 文档更新：新增 Choco 迁移 FAQ 和情况H，更新 manifest 总数
* 27e8efc 添加 dropit 8.5.1（从 Choco/SourceForge 迁移）
* 013fa49 (tag: v8.5.1) 添加 amcfy-music 1.2.0（音乐播放器，官方 release+自动更新）
* c5f841b 添加 networkfixtool 和 syshelper（单 exe 便携工具）
* bd65e44 (tag: v1.0) 添加 winmtr 0.9.2（网络诊断工具，zip 便携版）
* 9131e5b (tag: v0.9.2) 添加 rdriveimage（R-Drive Image 便携版，解压即用）
* f19cc07 (tag: vRDI) 添加 dianshishiguang 2.1.2（电视直播，单 exe 手动安装）
* 9b5104c (tag: v2.1.2) 文档更新：重构目录结构，精简模式分类说明
* 7e55d1c bandizip6：回退到模式6（下载后自动弹出安装向导，用户自行指定安装路径）
* d2e5382 bandizip6：回退到 7z 解包方案（NSIS 不支持 /D= 参数预填路径）
* a49b1cb bandizip6：GUI 模式安装，默认安装目录预填 scoop 路径，用户可自行修改
* 520ece9 bandizip6：改用 NSIS 静默安装到 scoop 目录，完全由 scoop 管理安装卸载
* 5082812 bandizip6：改用 7z 解包到 scoop 目录，由 scoop 完全管理安装卸载
* 2e015af 添加 sysdiag 和 dotnet-desktopruntime（单 exe 手动安装）
* 6989678 (tag: v8.0.28, tag: v6.0.11.0) 添加 btsou 25.11.12（zip 便携版，解压即用）
* 6f9cfe9 (tag: v25.11.12) 添加 pixpin 3.2.3.1（截图工具，单 exe 手动安装）
* 9b409c7 (tag: v3.2.3.1) 添加 360bwtest（360宽带测速，单 exe 便携）
* dd2f54c (tag: v360bw) 添加 tinytask（单 exe 便携工具）
* 8294cc4 (tag: v1.0.0.0) 添加 uuyc 4.30.1（UU远程，单 exe 手动安装）
* 9c0616d (tag: v4.30.1) 添加 litemonitor 1.3.6（便携 zip，官方 release+自动更新）
* be38c7d 添加 sougoupy v9.0（单 exe 手动安装）
* 36e5f6a (tag: v9.0) 添加 keycastow（zip 便携版，post_install 自动启动）
* 1f509a3 (tag: vKeyCastOW) 从 git 跟踪中移除 exe 文件
* 38341d4 iobit: 重命名 manifest，修复 URL 文件名
* 7719532 (tag: v1.3.0.11) 修复 iobitunlocker URL：GitHub 自动将空格替换为点号
* afaf70a 重构 iobitunlocker/idm/bandizip6：改为单 exe 手动安装模式（post_install 自动启动）
* 8f3aa8d (tag: v6.4.3) 文档更新：新增模式6（单 exe 手动安装）和情况G，更新 Apollo 类型描述
* 652c40b apollo：添加 post_install 自动启动安装器
* 9f9d22f 重构 apollo：改用单 exe 直链模式，用户手动运行安装器
* 0cd3bfd (tag: v0.4.6) 添加 apollo 0.4.6（Sunshine 游戏串流，NSIS 解包便携版）
* 5b47155 移除 wps-office：删除 manifest 及 release
* 417bad6 添加 wps-office 12.1.0.26884（去广告精简便携版）
* 8723d1c 添加 2345pic 10.8.0.9683（便携版自托管）
* fa8372f (tag: v10.8.0.9683) 添加 idm 6.4.3（静默安装自托管便携版）
* a4734ab 重做 iobitunlocker：静默安装替代 innounp 解包，修复 DLL 损坏问题
* bb98d73 添加 termius 9.40.1（汉化便携版，NSIS 解包+asar 替换）
* 670b36b (tag: v9.40.1) 添加 bcompare 5.2.2（静默安装自托管便携版）
* 979e8c7 添加 floral-notepaper 1.1.0（单 exe 官方 release，支持自动更新）
* b5be75c 添加 hibituninstaller 4.0.10（单 exe 便携版自托管）
* b0397f2 (tag: v4.0.10) 移除 bandizip6：删除 manifest 及 release，清理相关文档
* dc2cc07 重做 bandizip6：从静默安装打包便携版，修复右键菜单注册
* fb1c947 (tag: v6.18) 修复 bandizip6 右键菜单：手动注册 ShellEx ContextMenuHandlers/DragDropHandlers
* 2af77e1 修复 bandizip6 便携版无右键菜单：添加 shell 扩展注册/注销脚本
* 13899ab 添加 mykeymap 2.0-beta33（portable 7z 官方 release）
* a533e92 add uninstalltool 3.4.3 (encrypted Inno Setup silent install)
* 67fbfe7 (tag: v3.4.3) docs: add iobitunlocker Inno Setup pattern to documentation
* c6fcf25 add iobitunlocker 1.3.0.11 (Inno Setup extraction)
* bc755e7 docs: add bandizip6 NSIS extraction pattern and update software table
* f03a2f3 add bandizip6 6.18 - last ad-free version
* 1e7304f docs: update patterns with self-hosting guide and installer.script fix
* 93e328b (tag: v1.8.5.0) wgestures: update to 1.8.5.0, switch to portable zip
* 5d88419 修正wgestures.json
* 86c855c 修正wgestures.json
* 31dbde1 修正skill
* e88a734 2.[WindowsClear]C 盘清理工具，释放 AppData 大量空间：scoop install windowsclear
* 24857ac 1.Windows 的右键菜单管理工具Context Menu Manager Plus 安装：scoop install contextmenumgr-plus
* 6b210f9 Initial commit
```

## 新会话启动指南

1. 告诉 AI：`/skills-myscoop` 加载收录技能
2. 当前项目路径：`E:\09.同步\06.配置\myscoop`
3. 上传新软件：把文件放到该目录下，告诉 AI 文件名和类型
4. 阅读 `SKILL.md` 了解完整制作流程
5. 阅读 `README.md` 查看已收录软件列表
