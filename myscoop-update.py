#!/usr/bin/env python3
"""
myscoop 管理脚本
通过 GitHub / Gitee API 免下载获取版本和哈希。

用法（所有模式一览）:

  # 1) 新增：GitHub / Gitee 仓库（自动解析仓库与 release，生成完整 manifest）,[pya][pyn]
  python3 myscoop-update.py --add https://github.com/NanmiCoder/cc-haha.git
  python3 myscoop-update.py --add https://gitee.com/fasterthanlight/automatic_clicker_2.git
  python3 myscoop-update.py --add https://github.com/owner/repo --name my-app-name

  # 2) 新增：安装包直链（自动下载实测 SHA256、Inno Setup 检测、生成 autoupdate；
  #    GitHub 直链还会自动补全 description/homepage/license/checkver）[pyl]
  python3 myscoop-update.py --add "https://down.pixpin.cn/PixPin_win_3.5.5.1.exe" --name pixpin --version 3.5.5.1
  #    可选参数：--exe-name 主程序名（补 bin/shortcuts） --shortcut-name 快捷方式名
  #              --checkver-url / --checkver-regex 网页版本检查  --homepage / --description / --license
  python3 myscoop-update.py --add "https://github.com/SAOG0721/Magpie/releases/download/v0.6.8-experimental.1/Magpie-Experimental-x64.zip" --name magpie --version 0.6.8 --exe-name Magpie.exe

  # 3) 新增：官网下载页（自动提取安装包链接与版本号，生成 checkver/autoupdate；href 抓不到时回退 JS 裸 URL）[pyk]
  python3 myscoop-update.py --add "https://pixpin.cn/download/" --name pixpin

  # 4) 新增：manifest 模板补全（模板已有 hash 时自动跳过重复下载，秒级完成；--force-download 可强制重算）[pym]
  python3 myscoop-update.py --from ./pixpin.template.json --name pixpin
  python3 myscoop-update.py --from staging/magpie.json --name magpie --out-dir bucket/
  python3 myscoop-update.py --from staging/magpie.json --name magpie --out-dir bucket/ --force-download

  # 5) 补全：zip 清单下载探测 exe，由用户指定主程序，写入 bin/shortcuts（自动处理 extract_dir 与模板）[pyb]
  python3 myscoop-update.py --fill-bin staging/magpie.json --name magpie --out-dir bucket/          # 交互选择
  python3 myscoop-update.py --fill-bin staging/magpie.json --name magpie --select 1 --out-dir bucket/  # 非交互
  python3 myscoop-update.py --fill-bin staging/magpie.json --name magpie --select Magpie.exe --out-dir bucket/

  # 注意：模式 2/3/4/5 生成的清单默认输出到仓库内 staging/（FALLBACK_OUT_DIR），
  #       确认无误后用 --out-dir 指定正式目录（如 bucket/）

  # 6) 更新：单个 manifest,[pyd]
  python3 myscoop-update.py bucket/contextmenumgr-plus.json
  python3 myscoop-update.py bucket/contextmenumgr-plus.json --dry-run

  # 7) 更新：全部含 checkver 的 manifest,[pyp][pys]
  python3 myscoop-update.py --all
  python3 myscoop-update.py --all --dry-run

  # 8) 环境变量：GH_TOKEN（或 GITHUB_TOKEN）可提升 GitHub API 配额（仅对 api.github.com 生效）
  $env:GH_TOKEN = "ghp_xxx"   # PowerShell；Linux/macOS: export GH_TOKEN=ghp_xxx

"""

import json
import re
import sys
import os
import urllib.request
import urllib.error
from pathlib import Path

BUCKET_DIR = Path(__file__).parent / "bucket"
# 直链/模板/页面新增模式的默认输出目录（staging/ 草稿区，已被 .gitignore 忽略）：
# 未经 --out-dir 指定时，清单落在 staging/，避免误写仓库 bucket；
# 确认无误后再用 --out-dir 指向 bucket 目录落实
FALLBACK_OUT_DIR = Path(__file__).resolve().parent / "staging"


def parse_repo_url(url):
    """解析仓库 URL，返回 (platform, owner, repo)"""
    url = url.rstrip("/")
    if url.endswith(".git"):
        url = url[:-4]
    for platform, host in [("github", r"github\.com"), ("gitee", r"gitee\.com")]:
        m = re.match(rf"https?://{host}/([^/]+)/([^/]+?)$", url)
        if m:
            return platform, m.group(1), m.group(2)
    return None, None, None


def api_base(platform):
    """获取 API 基地址"""
    if platform == "gitee":
        return "https://gitee.com/api/v5/repos"
    return "https://api.github.com/repos"


def download_base(platform, owner, repo):
    """获取下载基地址"""
    if platform == "gitee":
        return f"https://gitee.com/{owner}/{repo}/releases/download"
    return f"https://github.com/{owner}/{repo}/releases/download"


def fetch_json(url):
    """获取 JSON 数据

    可选认证：设置环境变量 GH_TOKEN 或 GITHUB_TOKEN 后，仅对 GitHub
    官方 API（https://api.github.com/*）附加 Authorization 头，配额从
    60 次/时提升到 5000 次/时；未设置时自动退回匿名请求。
    绝不把 token 发给其他域名（Gitee / 镜像 / 代理 / 自定义 checkver.url），
    防止公开仓库场景下 token 外泄。
    """
    headers = {"User-Agent": "myscoop-updater"}
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token and url.startswith("https://api.github.com/"):
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode())


def get_latest_release(owner, repo, platform="github"):
    """获取最新 release 信息。
    兼容"只发布 prerelease"的仓库（/releases/latest 会 404，如 SAOG0721/Magpie）：
    404 时回退到 releases 列表，取最新一个非 draft、非 untagged 的 release。"""
    base = api_base(platform)
    url = f"{base}/{owner}/{repo}/releases/latest"
    try:
        return fetch_json(url)
    except urllib.error.HTTPError as e:
        if e.code != 404:
            raise
        rels = fetch_json(f"{base}/{owner}/{repo}/releases?per_page=20")
        for r in rels:
            if r.get("draft"):
                continue
            if str(r.get("tag_name", "")).startswith("untagged-"):
                continue
            return r
        raise urllib.error.HTTPError(url, 404, "no usable release", None, None)


def get_repo_info(owner, repo, platform="github"):
    """获取仓库信息"""
    base = api_base(platform)
    url = f"{base}/{owner}/{repo}"
    return fetch_json(url)


def resolve_autoupdate_url(autoupdate_url, version):
    """将 autoupdate URL 模板中的 $version 替换为实际版本号"""
    return autoupdate_url.replace("$version", version)


def match_asset(resolved_url, assets):
    """根据解析后的 URL 匹配对应的 release asset"""
    filename = resolved_url.split("/")[-1]
    for a in assets:
        if a["name"] == filename:
            return a
    for a in assets:
        if a["name"].lower() == filename.lower():
            return a
    ext = filename.rsplit(".", 1)[-1] if "." in filename else ""
    for a in assets:
        if a["name"].endswith("." + ext):
            a_base = re.sub(r"[\d.]+", "VER", a["name"].lower())
            f_base = re.sub(r"[\d.]+", "VER", filename.lower())
            if a_base == f_base:
                return a
    return None


def is_windows_asset(name):
    """判断是否为 Windows 平台资产"""
    lower = name.lower()
    # 明确排除非 Windows 格式
    if any(m in lower for m in [".dmg", ".appimage", ".rpm", ".deb", ".apk"]):
        return False
    # 排除源码包/校验与元数据文件
    if name.lower().endswith((".tar", ".tar.gz", ".tar.xz", ".txt", ".json",
                             ".md", ".sum", ".sha256", ".asc", ".list", ".html",
                             ".yml", ".blockmap", ".sig")):
        return False
    # 明确排除非 Windows 平台标识
    if re.search(r'[-.]mac(?:os)?[-.]', lower) or re.search(r'[-.]mac$', lower.rsplit('.', 1)[0] if '.' in lower else ''):
        return False
    if "darwin" in lower or "macos" in lower:
        return False
    if any(d in lower for d in ["linux", "ubuntu", "debian", "fedora", "centos",
                                "freebsd", "openbsd", "netbsd", "archlinux",
                                "manjaro", "gentoo", "rhel", "suse", "alpine"]):
        return False
    if "android" in lower or "ios" in lower:
        return False
    return True


def detect_arch(name):
    """从文件名检测架构"""
    lower = name.lower()
    if "arm64" in lower or "aarch64" in lower:
        return "arm64"
    if "x86" in lower or "32bit" in lower or "ia32" in lower:
        return "32bit"
    if "x64" in lower or "64bit" in lower or "amd64" in lower or "win64" in lower:
        return "64bit"
    return None


def score_asset(name):
    """给 Windows asset 打分，分数越高越好"""
    lower = name.lower()
    score = 0
    # 优先便携版
    if "portable" in lower:
        score += 10
    # zip/7z 优先于 exe（zip 可解压）
    if name.endswith(".zip") or name.endswith(".7z"):
        score += 5
    elif name.endswith(".exe"):
        # 有 setup/install 字样的是安装包，降到最低档（与 MSI 同档），
        # 免安装直用版（如 floral-notepaper_1.2.0.exe）优先
        if "setup" in lower or "install" in lower:
            score -= 10
    # MSI 保留但降低优先级，避免 Scoop 自动解包执行完整安装到系统
    # 如需恢复 MSI 正常优先级，删除下面两行即可
    elif name.endswith(".msi"):
        score -= 10
    # 中文版优先（_zh、-zh、chs、cn）
    if re.search(r'[._\-]zh[._\-]|_zh$|-zh$|[._\-]chs[._\-]|[._\-]cn[._\-]', lower):
        score += 3
    # GPU 优先：NVIDIA > AMD > Intel
    has_nvidia = re.search(r'[._\-]nvidia|nvidia', lower)
    has_cuda_ver = re.search(r'[._\-]cu\d{2,3}|cuda[._\-]?\d', lower)  # 兼容 cuda13 / cuda-13.3 / cu12 写法
    has_amd = re.search(r'[._\-]amd[._\-]|rocm|radeon', lower)
    has_intel = re.search(r'[._\-]intel[._\-]|intel', lower)
    if has_nvidia and not has_cuda_ver:
        score += 8  # NVIDIA 通用版最高优先
    elif has_cuda_ver:
        score += 6  # NVIDIA 指定 CUDA 版本
    elif has_amd:
        score += 4  # AMD GPU
    elif has_intel:
        score += 0  # Intel（不额外加分，排在 GPU 之后）
    # x64 优先
    if "x64" in lower or "64bit" in lower or "amd64" in lower:
        score += 2
    # arm64 降级：通用版（无架构标记）应优先于 arm64 专版
    if "arm64" in lower or "aarch64" in lower:
        score -= 5
    return score


def max_num(name):
    """文件名中最大的版本号（用于同分 tie-breaker：最新=数字最大）。
    只取点号版本（如 13.3、1.2.11），忽略 x64/32 这类架构数字。"""
    nums = re.findall(r"\d+\.\d+(?:\.\d+)*", name)
    if nums:
        return max(tuple(int(x) for x in n.split(".")) for n in nums)
    runs = [int(x) for x in re.findall(r"\d+", name)]
    return (max(runs),) if runs else (0,)


def pick_asset(group):
    """组内择优：score_asset 最高；同分取文件名版本号最大（规则①）"""
    best = None
    bscore, bnum = -1 << 30, None
    for a in group:
        sc = score_asset(a["name"])
        nm = max_num(a["name"])
        if sc > bscore or (sc == bscore and (bnum is None or nm > bnum)):
            best, bscore, bnum = a, sc, nm
    return best


def generate_autoupdate_url(asset_name, tag, has_v_prefix, platform="github", owner=None, repo=None):
    """根据 asset 文件名和 tag 生成 autoupdate URL 模板"""
    ver_match = re.search(r"[\d]+(?:\.[\d]+)+", asset_name)
    if ver_match:
        asset_ver_in_file = ver_match.group(0)
        new_name = asset_name.replace(asset_ver_in_file, "$version")
    else:
        new_name = asset_name

    v_prefix = "v" if re.match(r"^v", tag) else ""
    if platform == "gitee" and owner and repo:
        return f"{download_base(platform, owner, repo)}/{v_prefix}$version/{new_name}"
    return f"https://github.com/{{owner}}/{{repo}}/releases/download/{v_prefix}$version/{new_name}"


def add_manifest(repo_url, app_name=None):
    """从 GitHub / Gitee 链接添加新 manifest"""
    platform, owner, repo = parse_repo_url(repo_url)
    if not platform:
        print(f"[错误] 无法解析仓库 URL: {repo_url}")
        return None

    if not app_name:
        app_name = repo.lower()
    manifest_path = BUCKET_DIR / f"{app_name}.json"
    if manifest_path.exists():
        print(f"[错误] manifest 已存在: {manifest_path.name}")
        return None

    print(f"平台: {platform}")
    print(f"仓库: {owner}/{repo}")
    print(f"应用名: {app_name}")

    # 获取仓库信息
    try:
        info = get_repo_info(owner, repo, platform)
    except Exception as e:
        print(f"[错误] 获取仓库信息失败: {e}")
        return None

    description = info.get("description", f"{repo} - from {platform}")
    homepage = info.get("homepage", "") or f"https://{platform}.com/{owner}/{repo}"
    license_info = info.get("license", {})
    if isinstance(license_info, dict):
        license_val = license_info.get("spdx_id", license_info.get("name", "unknown"))
    else:
        license_val = license_info or "unknown"

    print(f"描述: {description}")
    print(f"License: {license_val}")

    # 获取 release
    try:
        release = get_latest_release(owner, repo, platform)
    except urllib.error.HTTPError as e:
        print(f"[错误] 获取 release 失败 (HTTP {e.code})，将创建无 checkver 的占位 manifest")
        print("  该项目可能没有 Release，需要手动处理。")
        manifest = {
            "version": "1.0",
            "description": description,
            "homepage": homepage,
            "license": license_val,
            "url": f"https://{platform}.com/{owner}/{repo}/releases",
            "hash": "sha256:0000000000000000000000000000000000000000000000000000000000000000",
            "notes": "需要手动设置下载地址和 hash，该项目无 Release。"
        }
        manifest_path_str = str(manifest_path)
        with open(manifest_path_str, "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=4, ensure_ascii=False)
            f.write("\n")
        print(f"\n[占位] manifest 已创建: {manifest_path_str}")
        print("  请手动补充 url 和 hash 后替换。")
        return manifest_path_str

    tag = release["tag_name"]
    version = tag.lstrip("v")
    has_v_prefix = tag.startswith("v")
    assets = release.get("assets", [])

    print(f"Tag: {tag} → version: {version}")
    print(f"Assets 数量: {len(assets)}")

    # 筛选 Windows 资产并排序
    win_assets = [(a, score_asset(a["name"])) for a in assets if is_windows_asset(a["name"])]
    win_assets.sort(key=lambda x: -x[1])

    if not win_assets:
        print("\n[警告] 未找到 Windows 平台资产。可用资产:")
        for a in assets:
            print(f"  {a['name']}")
        print("\n  请手动处理或等待项目提供 Windows 版本。")
        return None

    print("\nWindows 资产（按优先级）:")
    for a, score in win_assets:
        digest = a.get("digest", "N/A")
        print(f"  [{score}] {a['name']}")
        print(f"       digest: {digest}")
        print(f"       url: {a['browser_download_url']}")

    # 按架构分组（64bit/32bit/arm64/通用），组内择优（规则①同分取数字最大）
    arch_groups = {"64bit": [], "32bit": [], "arm64": [], "generic": []}
    for a, s in win_assets:
        arch_groups[detect_arch(a["name"]) or "generic"].append(a)

    # 检查是否有提取目录
    # 无法下载检查，先提示
    needs_extract_dir = False  # 默认不设置

    print()

    # 构建 manifest
    manifest = {
        "version": version,
        "description": description,
        "homepage": homepage,
        "license": license_val,
    }

    # 根据平台设置 checkver
    if platform == "gitee":
        manifest["checkver"] = {
            "url": f"https://gitee.com/api/v5/repos/{owner}/{repo}/releases/latest",
            "jsonpath": "$.tag_name",
            "regex": "v([\\d.]+)"
        }
    else:
        manifest["checkver"] = {"github": f"https://github.com/{owner}/{repo}"}

    # 候选架构：专用组优先；缺专用组时用通用组最优兜底（规则②；纯通用项目不做兜底）
    generic_best = pick_asset(arch_groups["generic"]) if arch_groups["generic"] else None
    has_special = any(arch_groups[g] for g in ("64bit", "32bit", "arm64"))
    arch_sel = {}
    for arch in ("64bit", "32bit", "arm64"):
        if arch_groups[arch]:
            arch_sel[arch] = pick_asset(arch_groups[arch])
        elif generic_best and has_special:
            arch_sel[arch] = generic_best

    if len(arch_sel) >= 2:
        print(f"检测到多架构: {list(arch_sel.keys())}")
        manifest["architecture"] = {}
        au_arch = {}
        for arch, a in sorted(arch_sel.items()):
            url = a["browser_download_url"]
            digest = a.get("digest", "")
            manifest["architecture"][arch] = {
                "url": url,
                "hash": digest
            }
            au_url = generate_autoupdate_url(a["name"], tag, has_v_prefix, platform, owner, repo)
            if platform != "gitee":
                au_url = au_url.format(owner=owner, repo=repo)
            au_arch[arch] = {"url": au_url}
            print(f"  {arch}: {a['name']}")

        manifest["autoupdate"] = {"architecture": au_arch}
    else:
        if arch_sel:
            best = list(arch_sel.values())[0]
        elif generic_best:
            best = generic_best
        else:
            best, _ = win_assets[0]
        url = best["browser_download_url"]
        digest = best.get("digest", "")

        manifest["url"] = url
        manifest["hash"] = digest

        au_url = generate_autoupdate_url(best["name"], tag, has_v_prefix, platform, owner, repo)
        if platform != "gitee":
            au_url = au_url.format(owner=owner, repo=repo)

        manifest["autoupdate"] = {"url": au_url}

        print(f"使用: {best['name']}")

    # 添加 bin 和 shortcuts（与架构选择保持一致：多架构用 64bit 选定项）
    if arch_sel:
        best_asset = list(arch_sel.values())[0]
    elif generic_best:
        best_asset = generic_best
    else:
        best_asset, _ = win_assets[0]
    best_name = best_asset["name"]

    if best_name.endswith(".msi"):
        # MSI 手动安装：Scoop 对 .msi 始终先执行 extract_archive（msiexec /a），
        # installer 字段在解包之后才执行，无法阻止。
        # 因此用 pre_install 在解包前从缓存复制 MSI 到 $dir 保存，再 post_install 启动
        # 不设 bin/shortcuts/checkver/autoupdate
        # 注意：Scoop 缓存文件名格式为 {appname}#{version}#{hash}.msi，不是原始文件名
        # 如需恢复 Scoop 默认 MSI 自动解包行为，删除此分支即可
        print("[MSI] 检测到 MSI 安装包，将使用 pre_install 保存 + post_install 启动")
        manifest["pre_install"] = [
            "$appname = Split-Path (Split-Path $dir -Parent) -Leaf",
            "$cachedir = $dir -replace '\\\\apps\\\\.*$', '\\cache'",
            "$msi = Get-ChildItem $cachedir -Filter \"$appname#*.msi\" | Sort-Object LastWriteTime -Descending | Select-Object -First 1",
            "if ($msi) { Copy-Item $msi.FullName \"$dir\\setup.msi\" }"
        ]
        manifest["post_install"] = "Start-Process \"$dir\\setup.msi\""
        if "checkver" in manifest:
            del manifest["checkver"]
        if "autoupdate" in manifest:
            del manifest["autoupdate"]
        manifest["notes"] = "MSI 手动安装包，scoop install 下载后自动启动，用户手动选择安装目录。"
    elif best_name.endswith(".exe"):
        exe_name = best_name
        # 去掉版本号得到更通用的名字（用于 bin/shortcuts）
        clean_name = re.sub(r"[-_]v?[\d]+(?:\.[\d]+)+", "", best_name)
        clean_name = clean_name.replace(".exe", ".exe")  # 确保后缀
        manifest["bin"] = exe_name
        manifest["shortcuts"] = [[exe_name, repo]]
        print(f"bin: {exe_name}")
    elif best_name.endswith(".qlplugin"):
        # .qlplugin 插件：下载后自启动，用户手动确认安装
        manifest["post_install"] = f"Start-Process \"$dir\\{best_name}\""
        print(f"[qlplugin] 将添加 post_install 自启动: {best_name}")
    elif best_name.endswith((".zip", ".7z")):
        # 无法确定内部 exe 名，跳过 bin/shortcuts
        manifest["notes"] = "请手动添加 bin 和 shortcuts，或运行脚本后补充。"
        print("[提示] zip/7z 格式无法自动推测 exe 名，请手动添加 bin/shortcuts")

    # 写入 manifest
    manifest_path_str = str(manifest_path)
    with open(manifest_path_str, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=4, ensure_ascii=False)
        f.write("\n")

    print(f"\n[成功] manifest 已创建: {manifest_path_str}")
    print(f"  安装命令: scoop install {app_name}")
    print(f"\n  下一步：")
    if best_name.endswith((".zip", ".7z")):
        print(f"  1. 下载并查看 zip 内部结构: curl -L -o _temp.zip \"{url}\" && 7z l _temp.zip | head -30")
        print(f"  2. 确认主 exe 名，添加到 manifest 的 bin 和 shortcuts 字段")
        print(f"  3. 如有顶层目录，添加 extract_dir 字段")
    print(f"  4. 验证: python3 -m json.tool {manifest_path_str}")
    print(f"  5. 安装测试: scoop install {app_name}")
    print(f"  6. git add . && git commit -m '添加 {app_name}' && git push")

    return manifest_path_str


def substitute_version(value, version):
    """递归替换结构中的 $version 模板为实际版本号"""
    if isinstance(value, str):
        return value.replace("$version", version)
    if isinstance(value, list):
        return [substitute_version(v, version) for v in value]
    if isinstance(value, dict):
        return {k: substitute_version(v, version) for k, v in value.items()}
    return value


def sync_autoupdate_fields(au_block, target, version):
    """把 autoupdate 块内除 url/hash/architecture/note 外的模板字段
    （如 bin、shortcuts、extract_dir）替换 $version 后写回主清单对应位置，
    与 scoop 官方 autoupdate 行为保持一致：仅同步主清单中已存在的字段；
    note 在 scoop 中是特殊追加语义，不在此同步。"""
    changed = []
    for key in au_block:
        if key in ("url", "hash", "architecture", "note"):
            continue
        if key not in target:
            continue  # 与 scoop 一致：主清单没有该字段则不同步
        new_val = substitute_version(au_block[key], version)
        if target[key] != new_val:
            target[key] = new_val
            changed.append(key)
    return changed


def update_manifest(manifest_path, dry_run=False):
    """更新单个 manifest"""
    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    if "checkver" not in manifest:
        return None

    cv = manifest["checkver"]
    github_url = cv.get("github")
    custom_url = cv.get("url", "")
    platform = "github"

    if github_url:
        m = re.match(r"https?://github\.com/([^/]+)/([^/]+)", github_url)
    elif "api.github.com/repos" in custom_url or "github.com" in custom_url:
        m = re.match(r"https?://(?:api\.)?github\.com/repos/([^/]+)/([^/]+)", custom_url)
    elif "gitee.com/api" in custom_url or "gitee.com" in custom_url:
        m = re.match(r"https?://gitee\.com/api/v5/repos/([^/]+)/([^/]+)", custom_url)
        if m:
            platform = "gitee"
    else:
        # 通用网页 checkver（非 GitHub/Gitee：url + regex）：页面取版本，直链下载算 hash
        if not (cv.get("url") and cv.get("regex")):
            print(f"  [跳过] {manifest_path.name}: 无法识别的 checkver")
            return None
        try:
            page = fetch_text(cv["url"], headers=PAGE_UA)
            rm = re.search(cv["regex"], page)
        except Exception as e:
            print(f"  [错误] {manifest_path.name}: checkver 页面抓取失败: {e}")
            return None
        if not rm:
            print(f"  [跳过] {manifest_path.name}: checkver 正则 {cv['regex']} 未匹配")
            return None
        latest_version = rm.group(1) if rm.groups() else rm.group(0)
        current_version = manifest["version"]
        if latest_version == current_version:
            return None
        print(f"  {manifest_path.name}: {current_version} → {latest_version}")
        if dry_run:
            return {"manifest": manifest_path.name, "old": current_version, "new": latest_version}
        au = manifest.get("autoupdate", {})
        tpl = au.get("url", manifest.get("url", ""))
        if "$version" not in tpl:
            print(f"  [警告] {manifest_path.name}: autoupdate 无 $version 模板，跳过")
            return None
        new_url = tpl.replace("$version", latest_version)
        tmp = manifest_path.parent / f".{manifest_path.stem}_dl.tmp"
        try:
            print(f"  [下载] {new_url.split('#')[0]}")
            download_to(new_url, tmp)
            size = tmp.stat().st_size
            digest = sha256_hex(tmp)
            tmp.unlink(missing_ok=True)
            print(f"  [下载完成] {size / 1048576:.1f}MB  sha256:{digest[:16]}...")
        except Exception as e:
            tmp.unlink(missing_ok=True)
            print(f"  [错误] {manifest_path.name}: 下载失败 {e}")
            return None
        manifest["url"] = new_url
        manifest["hash"] = "sha256:" + digest
        chg = sync_autoupdate_fields(au, manifest, latest_version)
        if chg:
            print(f"    同步字段: {', '.join(chg)}")
        manifest["version"] = latest_version
        with open(manifest_path, "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=4, ensure_ascii=False)
            f.write("\n")
        return {"manifest": manifest_path.name, "old": current_version, "new": latest_version}

    if not m:
        print(f"  [跳过] {manifest_path.name}: 无法解析 repo 地址")
        return None
    owner, repo = m.group(1), m.group(2)

    current_version = manifest["version"]

    try:
        release = get_latest_release(owner, repo, platform)
    except urllib.error.HTTPError as e:
        print(f"  [HTTP {e.code}] {manifest_path.name}: {owner}/{repo}")
        return None
    except Exception as e:
        print(f"  [错误] {manifest_path.name}: {e}")
        return None

    latest_tag = release["tag_name"]
    latest_version = latest_tag.lstrip("v")

    # 兼容"tag 带后缀而清单 version 只写主版本"的项目（如 v0.6.8-experimental.1 vs 0.6.8）：
    # 视为同一版本，不触发伪更新（仅当后缀不同时）
    if latest_version.startswith(current_version + "-"):
        return None
    if latest_version == current_version:
        return None
    print(f"  {manifest_path.name}: {current_version} → {latest_version}")

    assets = release.get("assets", [])

    if dry_run:
        return {"manifest": manifest_path.name, "old": current_version, "new": latest_version}

    au = manifest.get("autoupdate", {})

    if "architecture" in manifest:
        to_del = []
        for arch in manifest["architecture"]:
            old_url = manifest["architecture"][arch]["url"]
            au_arch = au.get("architecture", {}).get(arch, {})
            au_url_template = au_arch.get("url", old_url)
            new_url = resolve_autoupdate_url(au_url_template, latest_version)
            asset = match_asset(new_url, assets)
            if asset:
                digest = asset.get("digest", "")
                manifest["architecture"][arch]["url"] = new_url
                manifest["architecture"][arch]["hash"] = digest
                print(f"    {arch}: {digest[:16]}...")
            else:
                new_url2 = resolve_autoupdate_url(old_url, latest_version)
                asset2 = match_asset(new_url2, assets)
                if asset2:
                    digest2 = asset2.get("digest", "")
                    manifest["architecture"][arch]["url"] = new_url2
                    manifest["architecture"][arch]["hash"] = digest2
                    print(f"    {arch}: {digest2[:16]}... (fallback)")
                else:
                    to_del.append(arch)
        # 规则③：上游缺失该架构资产 → 删除该架构块（该架构用户自动回退 64bit/通用包）
        for arch in to_del:
            print(f"    [删除架构] {arch}: 上游缺少该架构资产（规则③）")
            del manifest["architecture"][arch]
            if isinstance(au.get("architecture"), dict):
                au["architecture"].pop(arch, None)
        if not manifest["architecture"]:
            del manifest["architecture"]
            print("    [提示] architecture 块已清空，已整体移除")
        elif len(manifest["architecture"]) == 1:
            print("    [提示] 仅剩 1 个架构，可考虑转顶层 url")

        # 同步 autoupdate 模板字段（bin/shortcuts/extract_dir 等）到各架构块，
        # 与 scoop 官方 autoupdate 的 arch_specific 行为一致
        for arch in manifest.get("architecture", {}):
            au_arch_block = au.get("architecture", {}).get(arch, {})
            chg = sync_autoupdate_fields(au_arch_block, manifest["architecture"][arch], latest_version)
            if chg:
                print(f"    {arch} 同步: {', '.join(chg)}")
    else:
        old_url = manifest["url"]
        au_url_template = au.get("url", old_url)
        new_url = resolve_autoupdate_url(au_url_template, latest_version)
        asset = match_asset(new_url, assets)
        if asset:
            digest = asset.get("digest", "")
            manifest["url"] = new_url
            manifest["hash"] = digest
            print(f"    hash: {digest[:16]}...")
        else:
            new_url2 = resolve_autoupdate_url(old_url, latest_version)
            asset2 = match_asset(new_url2, assets)
            if asset2:
                digest2 = asset2.get("digest", "")
                manifest["url"] = new_url2
                manifest["hash"] = digest2
                print(f"    hash: {digest2[:16]}... (fallback)")
            else:
                print(f"    [警告] 无法匹配")

        # 同步顶层 autoupdate 模板字段（bin/shortcuts/extract_dir 等）
        chg = sync_autoupdate_fields(au, manifest, latest_version)
        if chg:
            print(f"    同步字段: {', '.join(chg)}")

    manifest["version"] = latest_version

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=4, ensure_ascii=False)
        f.write("\n")

    return {"manifest": manifest_path.name, "old": current_version, "new": latest_version}


def arg_value(flag, default=None):
    """从 sys.argv 取 --flag 的值"""
    argv = sys.argv[1:]
    if flag in argv:
        i = argv.index(flag)
        if i + 1 < len(argv):
            return argv[i + 1]
    return default


PAGE_UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"}


def fetch_text(url, timeout=60, headers=None):
    """抓取网页文本（用于 checkver 页面验证等）"""
    req = urllib.request.Request(url, headers=headers or {"User-Agent": "myscoop-updater"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", "replace")


def download_to(url, dest, timeout=180):
    """下载文件到 dest（自动去除 #fragment）"""
    clean = url.split("#", 1)[0]
    req = urllib.request.Request(clean, headers={"User-Agent": "myscoop-updater"})
    with urllib.request.urlopen(req, timeout=timeout) as resp, open(dest, "wb") as f:
        while True:
            chunk = resp.read(65536)
            if not chunk:
                break
            f.write(chunk)


def sha256_hex(path):
    """计算文件 sha256"""
    import hashlib
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(65536)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def is_innosetup(path, max_scan=64 * 1024 * 1024):
    """检测 Inno Setup 安装器特征串（可能出现在文件深处，流式扫描，最多前 64MB）"""
    sigs = (b"Inno Setup Setup Data", b"This installation was built with Inno Setup")
    prev = b""
    read = 0
    with open(path, "rb") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            read += len(chunk)
            buf = prev + chunk
            if any(s in buf for s in sigs):
                return True
            if read >= max_scan:
                break
            prev = chunk[-64:]  # 防止特征串跨块
    return False


def make_url_template(url, version):
    """把下载 URL 中的版本号替换成 $version（query 参数值优先，其次路径段）。
    手动拼接 query 以免 urlencode 把 $version 编码成 %24version。"""
    clean, frag = url.split("#", 1)[0], ("#" + url.split("#", 1)[1]) if "#" in url else ""
    from urllib.parse import parse_qsl, urlsplit, urlunsplit
    parts = urlsplit(clean)
    q = parse_qsl(parts.query, keep_blank_values=True)
    if any(v == version for _, v in q):
        nq = [(k, "$version" if v == version else v) for k, v in q]
        return urlunsplit((parts.scheme, parts.netloc, parts.path,
                           "&".join(f"{k}={v}" for k, v in nq), "")) + frag
    if version in parts.path:
        return urlunsplit((parts.scheme, parts.netloc,
                           parts.path.replace(version, "$version", 1), parts.query, "")) + frag
    return None


def finalize_direct_manifest(template, out_dir, app_name):
    """非 GitHub 直链模板补全：下载算 hash + Inno Setup 检测 + checkver/autoupdate 校验"""
    url = template.get("url", "")
    if not url:
        print("[错误] 模板缺少 url")
        return None
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    tmp = out_dir / f".{app_name}_dl.tmp"
    existing_hash = template.get("hash")
    force_dl = "--force-download" in sys.argv[1:]
    if existing_hash and not force_dl:
        # 模板已含 hash：跳过重复下载，直接信任既有值（--force-download 可强制重算）
        given = str(existing_hash).lower()
        digest = given[7:] if given.startswith("sha256:") else given
        size = 0
        print(f"[跳过下载] 模板已含 hash（{given[:24]}...），如需重算请加 --force-download")
    else:
        print(f"[下载] {url.split('#')[0]}")
        try:
            download_to(url, tmp)
        except Exception as e:
            print(f"[错误] 下载失败: {e}")
            return None
        size = tmp.stat().st_size
        digest = sha256_hex(tmp)
        print(f"[下载完成] {size / 1048576:.1f}MB  sha256:{digest[:16]}...")
        # zip 且未指定 bin 时：探测压缩包顶层 exe，提示补 bin/shortcuts
        if url.lower().endswith(".zip") and not template.get("bin"):
            try:
                import zipfile
                with zipfile.ZipFile(tmp) as z:
                    names = z.namelist()
                exes = sorted({n for n in names if n.lower().endswith(".exe")
                               and "/" not in n and "\\" not in n})
                if exes:
                    print(f"[zip探测] 顶层 exe: {', '.join(exes[:6])}"
                          f"{'...' if len(exes) > 6 else ''}")
                    print(f"          如需补 bin/shortcuts，可用 --exe-name {exes[0]} 重新生成，或手动添加")
            except Exception:
                pass

    if template.get("hash"):
        given = str(template["hash"]).lower()
        given = given[7:] if given.startswith("sha256:") else given
        if given == digest:
            print("[hash] 与模板提供的 hash 一致 (OK)")
        else:
            print(f"[hash] 不一致！模板给出 {given[:16]}...，已改用实测值")
            template["hash"] = "sha256:" + digest
    else:
        template["hash"] = "sha256:" + digest
        print(f"[hash] 已自动填充 sha256:{digest[:16]}...")

    if "--force-download" not in sys.argv[1:]:
        # 未下载文件：跳过 Inno Setup 检测（无文件可查）
        print("[InnoSetup] 跳过检测（未下载文件，模板已 hash 齐备）")
    else:
        inno = is_innosetup(tmp)
        if inno:
            print("[InnoSetup] 检测到 Inno Setup 安装器特征")
            if template.get("innosetup") is not True:
                template["innosetup"] = True
                print("            已自动添加 \"innosetup\": true")
        elif template.get("innosetup") is True:
            print("[警告] 模板声明 innosetup:true 但文件中未检测到 Inno Setup 特征，请人工确认")
    tmp.unlink(missing_ok=True)

    cv = template.get("checkver") or {}
    if cv.get("github"):
        print(f"[checkver] 使用 GitHub 官方 API（{cv['github']}），--all 每晚自动更新")
    elif cv.get("url") and cv.get("regex"):
        try:
            page = fetch_text(cv["url"])
            m = re.search(cv["regex"], page)
            if m:
                got = m.group(1)
                ver = str(template.get("version", ""))
                if got == ver:
                    print(f"[checkver] {cv['url']} -> V{got} 与 version 一致 (OK)")
                else:
                    print(f"[checkver] 页面版本 V{got} 与清单 version={ver} 不一致，请确认")
            else:
                print(f"[checkver] 正则未匹配到内容: {cv['regex']}")
        except Exception as e:
            print(f"[checkver] 抓取失败: {e}")
    else:
        print("[checkver] 模板无 checkver（如需自动更新请补充 url+regex）")

    au = template.get("autoupdate") or {}
    ver = str(template.get("version", ""))
    if au.get("url"):
        tpl = au["url"]
        if "$version" in tpl:
            sub = tpl.replace("$version", ver)
            ok = sub.split("#", 1)[0] == url.split("#", 1)[0]
            print(f"[autoupdate] 替换后{'与 url 一致 (OK)' if ok else '与 url 不一致，请检查'}: {sub}")
        else:
            print("[autoupdate] 模板不含 $version，无法自动更新")
    elif ver:
        tpl = make_url_template(url, ver)
        if tpl:
            # 保留模板中已有的其他键（如 extract_dir 模板），只补充 url
            au_new = dict(template.get("autoupdate") or {})
            au_new["url"] = tpl
            template["autoupdate"] = au_new
            print(f"[autoupdate] 已自动生成模板: {tpl}")
        else:
            print("[autoupdate] URL 中未找到版本号，无法生成模板（可手动补充）")

    out_path = out_dir / f"{app_name}.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(template, f, indent=4, ensure_ascii=False)
        f.write("\n")
    print(f"\n[成功] 已写入: {out_path}")
    return out_path


def fill_bin_manifest(tpath, out_dir, app_name=None, select=None):
    """补全命令：下载 zip 探测 exe -> 列出供用户挑选主程序 -> 写入 bin/shortcuts。
    用法: myscoop-update.py --fill-bin <manifest.json> [--out-dir 目录] [--select 编号|exe名]
    不带 --select 时交互式提问（回车=第 1 个）。"""
    template = json.loads(Path(tpath).read_text(encoding="utf-8"))
    url = template.get("url", "")
    if not url:
        print("[错误] 清单缺少 url")
        return None
    if not url.lower().endswith(".zip"):
        print("[错误] --fill-bin 仅支持 zip 类清单（exe 直链请用 --exe-name 重新 --add）")
        return None
    if not app_name:
        app_name = arg_value("--name") or Path(tpath).stem
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    tmp = out_dir / f".{app_name}_fill.tmp"
    print(f"[下载] {url.split('#')[0]}")
    try:
        download_to(url, tmp)
    except Exception as e:
        print(f"[错误] 下载失败: {e}")
        return None
    digest = sha256_hex(tmp)
    try:
        import zipfile
        with zipfile.ZipFile(tmp) as z:
            names = [n for n in z.namelist() if not n.endswith("/")]
    except Exception as e:
        tmp.unlink(missing_ok=True)
        print(f"[错误] 无法读取 zip: {e}")
        return None
    tmpl_digest = str(template.get("hash", "")).lower()
    tmpl_digest = tmpl_digest[7:] if tmpl_digest.startswith("sha256:") else tmpl_digest
    if tmpl_digest and tmpl_digest != digest:
        print(f"[警告] 实测 hash 与清单不一致（{digest[:16]}...），将按实测值更新")
    elif tmpl_digest:
        print(f"[hash] 与清单 hash 一致 (OK)  sha256:{digest[:16]}...")

    # 列出全部 exe（顶层优先 + 名称排序）
    exes = [n for n in names if n.lower().endswith(".exe")]
    exes.sort(key=lambda n: (("/" in n), n.lower()))
    if not exes:
        tmp.unlink(missing_ok=True)
        print("[提示] zip 内未发现 exe（可能是脚本类应用），无法自动补 bin")
        return None
    print(f"[探测] zip 内可执行文件（共 {len(exes)} 个）:")
    for i, e in enumerate(exes, 1):
        print(f"    {i}: {e}")

    choice = None
    if select:
        if select.isdigit():
            idx = int(select) - 1
            if 0 <= idx < len(exes):
                choice = exes[idx]
            else:
                print(f"[错误] 编号超出范围（1-{len(exes)}）")
        else:
            low = select.lower()
            choice = next((e for e in exes if low in e.lower()), None)
            if not choice:
                print(f"[错误] 未找到包含 '{select}' 的 exe")
    else:
        try:
            ans = input(f"请选择主程序编号（1-{len(exes)}，回车默认 1）: ").strip()
            if ans:
                if ans.isdigit() and 1 <= int(ans) <= len(exes):
                    choice = exes[int(ans) - 1]
                else:
                    choice = next((e for e in exes if ans.lower() in e.lower()), None)
            else:
                choice = exes[0]
        except EOFError:
            choice = exes[0]
    if not choice:
        tmp.unlink(missing_ok=True)
        return None
    print(f"[选择] {choice}")

    # 若 exe 在子目录且该目录是唯一顶层目录 -> 自动补 extract_dir（version 模板化）
    bin_name = choice
    if "/" in choice:
        top = choice.split("/", 1)[0]
        top_files = [n for n in names if "/" not in n]
        top_dirs = {n.split("/", 1)[0] for n in names if "/" in n}
        if not top_files and top_dirs == {top}:
            template["extract_dir"] = top
            bin_name = choice.split("/", 1)[1]
            au = template.setdefault("autoupdate", {})
            tpl = re.sub(r"\d+(?:\.\d+)+", "$version", top, count=1)
            if tpl != top:
                au["extract_dir"] = tpl
            print(f"[extract_dir] {top}（已设置模板: {au.get('extract_dir', top)}）")
        else:
            print(f"[警告] zip 结构较复杂（多目录/顶层散文件），未自动设置 extract_dir，"
                  f"bin 将使用完整相对路径 {choice}")
    template["bin"] = bin_name
    template["shortcuts"] = [[bin_name, arg_value("--shortcut-name") or app_name]]
    print(f"[写入] bin = {bin_name} | shortcuts 显示名 = {arg_value('--shortcut-name') or app_name}")

    tmp.unlink(missing_ok=True)
    if not template.get("hash"):
        template["hash"] = "sha256:" + digest
    return finalize_direct_manifest(template, out_dir, app_name)


def add_direct_url(url, app_name=None):
    """非 GitHub 直链新增：由下载链接 + 可选参数组装模板后补全。
    支持 --version / --checkver-url / --checkver-regex / --exe-name /
        --shortcut-name / --homepage / --description / --license / --out-dir"""
    if not app_name:
        base = url.split("?")[0].rstrip("/").split("/")[-1].split("#")[0]
        app_name = re.sub(r"[^0-9a-zA-Z._-]", "-", base) or "app"
    template = {
        "version": arg_value("--version") or "1.0",
        "description": arg_value("--description") or "",
        "homepage": arg_value("--homepage") or "",
        "license": arg_value("--license") or "unknown",
        "url": url,
    }
    cv_url, cv_regex = arg_value("--checkver-url"), arg_value("--checkver-regex")
    if cv_url and cv_regex:
        template["checkver"] = {"url": cv_url, "regex": cv_regex}

    # 若直链属于 GitHub 仓库（github.com/{owner}/{repo}/releases/...），自动获取仓库信息补全
    # （description/homepage/license/checkver.github），网络失败时保持用户字段不阻断
    gm = re.match(r"https?://github\.com/([^/]+)/([^/]+?)(?:/|$)", url)
    if gm and not (cv_url and cv_regex):
        owner, repo = gm.group(1), gm.group(2)
        try:
            info = get_repo_info(owner, repo, "github")
            if not template["description"]:
                template["description"] = info.get("description") or ""
            if not template["homepage"]:
                template["homepage"] = info.get("homepage") or f"https://github.com/{owner}/{repo}"
            lic = info.get("license") or {}
            spdx = lic.get("spdx_id") if isinstance(lic, dict) else lic
            if spdx and spdx != "NOASSERTION" and template["license"] == "unknown":
                template["license"] = spdx
            if "checkver" not in template:
                template["checkver"] = {"github": f"https://github.com/{owner}/{repo}"}
            print(f"[仓库信息] {owner}/{repo}：已自动补全 description/homepage/license/checkver")
        except Exception as e:
            print(f"[提示] GitHub 仓库信息获取失败（保持用户字段）: {e}")
    exe_name = arg_value("--exe-name")
    if exe_name:
        template["bin"] = exe_name
        template["shortcuts"] = [[exe_name, arg_value("--shortcut-name") or app_name]]
    out_dir = arg_value("--out-dir") or FALLBACK_OUT_DIR
    return finalize_direct_manifest(template, out_dir, app_name)


def extract_installer_links(html, page_url):
    """从下载页提取安装包直链（绝对化），按 exe > zip > 其他 排序。
    href 抓不到时回退扫描裸 URL（搜狗等站的链接写在 JS 字符串里）。"""
    from urllib.parse import urljoin
    found = re.findall(r'href=["\']([^"\']+\.(?:exe|msi|zip|7z))(?:\?[^"\']*)?["\']', html, re.I)
    if not found:
        found = re.findall(r'https?://[^\s"\'<>]+\.(?:exe|msi|zip|7z)(?:\?[^\s"\'<>]*)?', html)
    seen, out = set(), []
    for l in found:
        absl = urljoin(page_url, l.strip())
        if absl not in seen:
            seen.add(absl)
            out.append(absl)

    def key(u):
        e = u.rsplit(".", 1)[-1].lower()
        return (0 if e == "exe" else 1 if e == "zip" else 2, u)

    return sorted(out, key=key)


def version_from_link(url):
    """从安装包链接/文件名提取版本号，如 PixPin_win_3.5.5.1.exe -> 3.5.5.1。
    拒绝\"前后都是字母数字\"的伪版本（如 lzma2603.7z 里的 2603.7）。"""
    for m in re.finditer(r"\d+\.\d+(?:\.\d+)*", url):
        before = url[m.start() - 1] if m.start() > 0 else ""
        after = url[m.end()] if m.end() < len(url) else ""
        if before.isalnum() and after.isalnum():
            continue  # 前/后夹在字符中间，如 2603.7z 的 2603.7
        return m.group(1) if m.groups() else m.group(0)
    return None


def checkver_regex_from_link(url, version):
    r"""由链接生成 checkver 正则，按优先级：文件名版本 > URL 路径版本 > 通用。
    PixPin_win_3.5.5.1.exe -> PixPin_win_([\d.]+)\.exe
    .../download/26.03/7z2603-x64.exe -> .../download/([\d.]+)/7z2603-x64.exe"""
    fname = url.rsplit("/", 1)[-1]
    if version in fname:
        pos = fname.find(version)
        return re.escape(fname[:pos]) + r"([\d.]+)" + re.escape(fname[pos + len(version):])
    pos = url.find(version)
    if pos >= 0:
        return re.escape(url[:pos]) + r"([\d.]+)" + re.escape(url[pos + len(version):])
    return r"([\d.]+)"


def best_link(links):
    """择优：版本最大优先；同版本时 exe > zip、通用/x64 > x86 > arm64"""
    best = None
    for l in links:
        v = version_from_link(l)
        if not v:
            continue
        vt = tuple(int(x) for x in v.split("."))
        lower = l.lower()
        arch = 2 if re.search(r"arm64|aarch64|(?:^|[-._])arm(?:[-._]|$)", lower) else (
            1 if ("x86" in lower or "32bit" in lower or "ia32" in lower) else 0)
        ext = 0 if lower.rsplit(".", 1)[-1] in ("exe", "msi") else 1
        # 版本越大越好；ext/arch 偏好越小越好 → 取负参与比较
        rank = (vt, -ext, -arch)
        if best is None or rank > best[0]:
            best = (rank, l)
    return best[1] if best else links[0]


def add_page_mode(page_url, app_name=None):
    """下载页新增：抓页面 -> 提取安装包链接与版本 -> 组装模板生成 manifest"""
    try:
        html = fetch_text(page_url, headers=PAGE_UA)
    except Exception as e:
        print(f"[错误] 页面抓取失败: {e}")
        return None
    links = extract_installer_links(html, page_url)
    if not links:
        print("[错误] 页面中未找到安装包链接（.exe/.msi/.zip/.7z）")
        return None
    print(f"[页面] {page_url}")
    for i, l in enumerate(links, 1):
        print(f"        链接{i}: {l}")

    link = best_link(links)  # exe 优先 + 版本最大（页面常含历史多版本，如 Vivaldi）
    version = version_from_link(link) or arg_value("--version") or "1.0"
    print(f"[提取] 选用: {link}")
    print(f"[提取] 版本: {version}")
    if not app_name:
        base = link.split("?")[0].split("#")[0].rstrip("/").split("/")[-1]
        app_name = re.sub(r"[^0-9a-zA-Z._-]", "-", base) or "app"
    template = {
        "version": version,
        "description": arg_value("--description") or "",
        "homepage": arg_value("--homepage") or page_url,
        "license": arg_value("--license") or "unknown",
        "url": link,
        "checkver": {
            "url": page_url,
            "regex": checkver_regex_from_link(link, version),
        },
    }
    exe_name = arg_value("--exe-name")
    if exe_name:
        template["bin"] = exe_name
        template["shortcuts"] = [[exe_name, arg_value("--shortcut-name") or app_name]]
    out_dir = arg_value("--out-dir") or FALLBACK_OUT_DIR
    return finalize_direct_manifest(template, out_dir, app_name)


def main():
    args = sys.argv[1:]
    dry_run = "--dry-run" in args
    all_mode = "--all" in args
    add_idx = args.index("--add") if "--add" in args else -1

    # --fill-bin <清单.json>：下载 zip 探测 exe，由用户指定主程序，补全 bin/shortcuts
    if "--fill-bin" in args:
        fb_pos = args.index("--fill-bin")
        tpath = args[fb_pos + 1] if fb_pos + 1 < len(args) else None
        if not tpath:
            print("用法: python3 myscoop-update.py --fill-bin <manifest.json> [--name 应用名] "
                  "[--select 编号|exe名] [--out-dir 输出目录]")
            sys.exit(1)
        result = fill_bin_manifest(tpath, arg_value("--out-dir") or FALLBACK_OUT_DIR,
                                   arg_value("--name"), arg_value("--select"))
        sys.exit(0 if result else 1)

    # --from <模板.json>：非 GitHub 直链模板补全（下载算 hash + 检测 + 校验）
    if "--from" in args:
        from_pos = args.index("--from")
        tpath = args[from_pos + 1] if from_pos + 1 < len(args) else None
        if not tpath:
            print("用法: python3 myscoop-update.py --from <manifest模板.json> [--name 应用名] [--out-dir 输出目录]")
            sys.exit(1)
        try:
            template = json.loads(Path(tpath).read_text(encoding="utf-8"))
        except Exception as e:
            print(f"[错误] 模板解析失败: {e}")
            sys.exit(1)
        app_name = arg_value("--name") or Path(tpath).stem
        out_dir = arg_value("--out-dir") or FALLBACK_OUT_DIR
        result = finalize_direct_manifest(template, out_dir, app_name)
        sys.exit(0 if result else 1)

    args = [a for a in args if not a.startswith("--")]

    # --add 模式：GitHub/Gitee 仓库 → 原有流程；非仓库 http(s) 链接 → 直链模式
    if add_idx >= 0:
        add_args = sys.argv[1:]
        add_pos = add_args.index("--add")
        if add_pos + 1 >= len(add_args):
            print("用法: python3 myscoop-update.py --add <github-url|下载链接> [--name 应用名] [...其他选项]")
            sys.exit(1)
        target = add_args[add_pos + 1]
        app_name = arg_value("--name")
        platform, _o, _r = parse_repo_url(target)
        if platform:
            result = add_manifest(target, app_name)
        elif target.startswith(("http://", "https://")):
            if re.search(r"\.(?:exe|msi|zip|7z)(?:[?#]|$)", target, re.I):
                result = add_direct_url(target, app_name)
            else:
                result = add_page_mode(target, app_name)
        else:
            print(f"[错误] 无法解析 URL: {target}")
            result = None
        sys.exit(0 if result else 1)

    # 更新模式
    if all_mode:
        paths = sorted(BUCKET_DIR.glob("*.json"))
    elif args:
        paths = [Path(a) for a in args]
        for i, p in enumerate(paths):
            if not p.exists():
                alt = BUCKET_DIR / p.name
                if alt.exists():
                    paths[i] = alt
                else:
                    print(f"文件不存在: {p}")
                    sys.exit(1)
    else:
        print(__doc__)
        sys.exit(0)

    updated = []
    for path in paths:
        try:
            result = update_manifest(path, dry_run=dry_run)
            if result:
                updated.append(result)
        except Exception as e:
            print(f"  [异常] {path.name}: {e}")

    print()
    if dry_run:
        print(f"=== 共 {len(updated)} 个可更新 ===")
    else:
        print(f"=== 已更新 {len(updated)} 个 ===")
    for u in updated:
        print(f"  {u['manifest']}: {u['old']} → {u['new']}")


if __name__ == "__main__":
    main()
