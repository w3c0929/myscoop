#!/usr/bin/env python3
"""
myscoop 管理脚本
通过 GitHub API 免下载获取版本和哈希。

用法:
  # 从 GitHub 链接添加新软件
  python3 myscoop-update.py --add https://github.com/NanmiCoder/cc-haha.git
  python3 myscoop-update.py --add https://github.com/owner/repo --name my-app-name

  # 更新指定 manifest
  python3 myscoop-update.py bucket/contextmenumgr-plus.json

  # 更新所有含 checkver 的 manifest
  python3 myscoop-update.py --all

  # 仅检查，不写入
  python3 myscoop-update.py --all --dry-run
"""

import json
import re
import sys
import os
import urllib.request
import urllib.error
from pathlib import Path

BUCKET_DIR = Path(__file__).parent / "bucket"


def fetch_json(url):
    """获取 JSON 数据"""
    req = urllib.request.Request(url, headers={"User-Agent": "myscoop-updater"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode())


def get_latest_release(owner, repo):
    """获取最新 release 信息"""
    url = f"https://api.github.com/repos/{owner}/{repo}/releases/latest"
    return fetch_json(url)


def get_repo_info(owner, repo):
    """获取仓库信息"""
    url = f"https://api.github.com/repos/{owner}/{repo}"
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
    # 明确排除非 Windows 平台标识
    if re.search(r'[-.]mac(?:os)?[-.]', lower) or re.search(r'[-.]mac$', lower.rsplit('.', 1)[0] if '.' in lower else ''):
        return False
    if "darwin" in lower or "macos" in lower:
        return False
    if "linux" in lower and "windows" not in lower:
        return False
    if "android" in lower or "ios" in lower:
        return False
    if name.endswith(".yml") or name.endswith(".blockmap"):
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
        # 有 setup 字样的是安装包，扣分
        if "setup" in lower or "install" in lower:
            score -= 5
    # MSI 保留但降低优先级，避免 Scoop 自动解包执行完整安装到系统
    # 如需恢复 MSI 正常优先级，删除下面两行即可
    elif name.endswith(".msi"):
        score -= 10
    # 中文版优先（_zh、-zh、chs、cn）
    if re.search(r'[._\-]zh[._\-]|_zh$|-zh$|[._\-]chs[._\-]|[._\-]cn[._\-]', lower):
        score += 3
    # x64 优先
    if "x64" in lower or "64bit" in lower or "amd64" in lower:
        score += 2
    return score


def generate_autoupdate_url(asset_name, tag, has_v_prefix):
    """根据 asset 文件名和 tag 生成 autoupdate URL 模板"""
    tag_with_v = f"v{tag}" if not has_v_prefix else tag
    version = tag.lstrip("v")

    # 找到文件名中的版本号
    ver_match = re.search(r"[\d]+(?:\.[\d]+)+", asset_name)
    if ver_match:
        asset_ver_in_file = ver_match.group(0)
        new_name = asset_name.replace(asset_ver_in_file, "$version")
    else:
        new_name = asset_name

    v_prefix = "v" if re.match(r"^v", tag) else ""
    return f"https://github.com/{{owner}}/{{repo}}/releases/download/{v_prefix}$version/{new_name}"


def add_manifest(github_url, app_name=None):
    """从 GitHub 链接添加新 manifest"""
    # 解析 URL
    github_url = github_url.rstrip("/").rstrip(".git")
    m = re.match(r"https?://github\.com/([^/]+)/([^/]+?)(?:\.git)?$", github_url)
    if not m:
        print(f"[错误] 无法解析 GitHub URL: {github_url}")
        return None
    owner, repo = m.group(1), m.group(2)

    if not app_name:
        app_name = repo.lower()
    manifest_path = BUCKET_DIR / f"{app_name}.json"
    if manifest_path.exists():
        print(f"[错误] manifest 已存在: {manifest_path.name}")
        return None

    print(f"仓库: {owner}/{repo}")
    print(f"应用名: {app_name}")

    # 获取仓库信息
    try:
        info = get_repo_info(owner, repo)
    except Exception as e:
        print(f"[错误] 获取仓库信息失败: {e}")
        return None

    description = info.get("description", f"{repo} - from GitHub")
    homepage = info.get("homepage", "") or f"https://github.com/{owner}/{repo}"
    license_spdx = info.get("license", {})
    license_val = license_spdx.get("spdx_id", "unknown") if license_spdx else "unknown"

    print(f"描述: {description}")
    print(f"License: {license_val}")

    # 获取 release
    try:
        release = get_latest_release(owner, repo)
    except urllib.error.HTTPError as e:
        print(f"[错误] 获取 release 失败 (HTTP {e.code})，将创建无 checkver 的占位 manifest")
        print("  该项目可能没有 GitHub Release，需要手动处理。")
        # 创建占位 manifest（自托管模式）
        manifest = {
            "version": "1.0",
            "description": description,
            "homepage": homepage,
            "license": license_val,
            "url": f"https://github.com/{owner}/{repo}/releases",
            "hash": "sha256:0000000000000000000000000000000000000000000000000000000000000000",
            "notes": "需要手动设置下载地址和 hash，该项目无 GitHub Release。"
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

    # 检测是否为多架构
    arch_assets = {}
    for a, s in win_assets:
        arch = detect_arch(a["name"])
        if arch:
            if arch not in arch_assets:
                arch_assets[arch] = a
            elif score_asset(a["name"]) > score_asset(arch_assets[arch]["name"]):
                arch_assets[arch] = a

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

    if len(arch_assets) >= 2:
        # 多架构 manifest
        print(f"检测到多架构: {list(arch_assets.keys())}")
        manifest["architecture"] = {}
        au_arch = {}
        for arch, a in sorted(arch_assets.items()):
            url = a["browser_download_url"]
            digest = a.get("digest", "")
            manifest["architecture"][arch] = {
                "url": url,
                "hash": digest
            }
            # 生成 autoupdate URL
            au_url = generate_autoupdate_url(a["name"], tag, has_v_prefix)
            au_url = au_url.format(owner=owner, repo=repo)
            au_arch[arch] = {"url": au_url}
            print(f"  {arch}: {a['name']}")

        manifest["checkver"] = {"github": f"https://github.com/{owner}/{repo}"}
        manifest["autoupdate"] = {"architecture": au_arch}
    else:
        # 单架构 manifest
        best, best_score = win_assets[0]
        url = best["browser_download_url"]
        digest = best.get("digest", "")

        manifest["url"] = url
        manifest["hash"] = digest

        au_url = generate_autoupdate_url(best["name"], tag, has_v_prefix)
        au_url = au_url.format(owner=owner, repo=repo)

        manifest["checkver"] = {"github": f"https://github.com/{owner}/{repo}"}
        manifest["autoupdate"] = {"url": au_url}

        print(f"使用: {best['name']}")

    # 添加 bin 和 shortcuts
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


def update_manifest(manifest_path, dry_run=False):
    """更新单个 manifest"""
    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    if "checkver" not in manifest:
        return None

    cv = manifest["checkver"]
    github_url = cv.get("github")
    custom_url = cv.get("url", "")

    if github_url:
        m = re.match(r"https?://github\.com/([^/]+)/([^/]+)", github_url)
    elif "api.github.com/repos" in custom_url:
        m = re.match(r"https?://api\.github\.com/repos/([^/]+)/([^/]+)", custom_url)
    else:
        print(f"  [跳过] {manifest_path.name}: 非 github checkver")
        return None

    if not m:
        print(f"  [跳过] {manifest_path.name}: 无法解析 repo 地址")
        return None
    owner, repo = m.group(1), m.group(2)

    current_version = manifest["version"]

    try:
        release = get_latest_release(owner, repo)
    except urllib.error.HTTPError as e:
        print(f"  [HTTP {e.code}] {manifest_path.name}: {owner}/{repo}")
        return None
    except Exception as e:
        print(f"  [错误] {manifest_path.name}: {e}")
        return None

    latest_tag = release["tag_name"]
    latest_version = latest_tag.lstrip("v")

    if latest_version == current_version:
        return None
    print(f"  {manifest_path.name}: {current_version} → {latest_version}")

    assets = release.get("assets", [])

    if dry_run:
        return {"manifest": manifest_path.name, "old": current_version, "new": latest_version}

    au = manifest.get("autoupdate", {})

    if "architecture" in manifest:
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
                    print(f"    [警告] {arch}: 无法匹配")
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

    manifest["version"] = latest_version

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=4, ensure_ascii=False)
        f.write("\n")

    return {"manifest": manifest_path.name, "old": current_version, "new": latest_version}


def main():
    args = sys.argv[1:]
    dry_run = "--dry-run" in args
    all_mode = "--all" in args
    add_idx = args.index("--add") if "--add" in args else -1
    name_idx = args.index("--name") if "--name" in args else -1
    args = [a for a in args if not a.startswith("--")]

    # --add 模式
    if add_idx >= 0:
        # 找到 --add 后的 URL
        add_args = sys.argv[1:]
        add_pos = add_args.index("--add")
        if add_pos + 1 >= len(add_args):
            print("用法: python3 myscoop-update.py --add <github-url> [--name app-name]")
            sys.exit(1)
        github_url = add_args[add_pos + 1]
        app_name = None
        if "--name" in add_args:
            name_pos = add_args.index("--name")
            if name_pos + 1 < len(add_args):
                app_name = add_args[name_pos + 1]
        result = add_manifest(github_url, app_name)
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
