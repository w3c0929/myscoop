#!/usr/bin/env python3
"""
myscoop-update.py
免下载自动更新 myscoop bucket 中的第三方 manifest。
通过 GitHub API digest 获取新版本号和新哈希，无需下载任何软件包。

用法:
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


def resolve_autoupdate_url(autoupdate_url, version):
    """将 autoupdate URL 模板中的 $version 替换为实际版本号"""
    return autoupdate_url.replace("$version", version)


def match_asset(resolved_url, assets):
    """根据解析后的 URL 匹配对应的 release asset"""
    filename = resolved_url.split("/")[-1]
    # 先精确匹配文件名
    for a in assets:
        if a["name"] == filename:
            return a
    # 再去掉 v 前缀后匹配（有些项目 tag 带 v 但文件名不带）
    # 尝试模糊匹配：用文件扩展名和关键部分
    for a in assets:
        aname = a["name"].lower()
        fname = filename.lower()
        if aname == fname:
            return a
        # 忽略大小写
        if aname == fname.lower():
            return a
    # 尝试用正则：相同扩展名，且版本号位置匹配
    ext = filename.rsplit(".", 1)[-1] if "." in filename else ""
    for a in assets:
        if a["name"].endswith("." + ext):
            # 用模糊比较：去掉版本号后比较前缀
            a_base = re.sub(r"[\d.]+", "VER", a["name"].lower())
            f_base = re.sub(r"[\d.]+", "VER", filename.lower())
            if a_base == f_base:
                return a
    return None


def update_manifest(manifest_path, dry_run=False):
    """更新单个 manifest"""
    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    if "checkver" not in manifest:
        return None

    cv = manifest["checkver"]

    # 方式1：标准 github 模式
    github_url = cv.get("github")
    # 方式2：自定义 URL（从 api.github.com 提取）
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
    home = manifest.get("homepage", github_url)

    try:
        release = get_latest_release(owner, repo)
    except urllib.error.HTTPError as e:
        print(f"  [HTTP {e.code}] {manifest_path.name}: {owner}/{repo}")
        return None
    except Exception as e:
        print(f"  [错误] {manifest_path.name}: {e}")
        return None

    latest_tag = release["tag_name"]
    latest_version = latest_tag.lstrip("v")  # 去掉 v 前缀

    if latest_version == current_version:
        return None  # 已是最新
    print(f"  {manifest_path.name}: {current_version} → {latest_version}")

    assets = release.get("assets", [])

    if dry_run:
        return {"manifest": manifest_path.name, "old": current_version, "new": latest_version}

    # 构建新 manifest
    au = manifest.get("autoupdate", {})

    if "architecture" in manifest:
        # 多架构 manifest
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
                # 保持旧 URL 模式，只替换版本号
                new_url2 = resolve_autoupdate_url(old_url, latest_version)
                asset2 = match_asset(new_url2, assets)
                if asset2:
                    digest2 = asset2.get("digest", "")
                    manifest["architecture"][arch]["url"] = new_url2
                    manifest["architecture"][arch]["hash"] = digest2
                    print(f"    {arch}: {digest2[:16]}... (fallback URL)")
                else:
                    print(f"    [警告] {arch}: 无法匹配 asset: {new_url}")
    else:
        # 单架构 manifest
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
                print(f"    hash: {digest2[:16]}... (fallback URL)")
            else:
                print(f"    [警告] 无法匹配 asset: {new_url}")

    manifest["version"] = latest_version

    # 写入更新后的 manifest
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=4, ensure_ascii=False)
        f.write("\n")

    # 更新 checkver 的 jsonpath/regex（处理非标准 github 模式）
    # 对于非标准项目，保留原有 checkver 不变

    return {"manifest": manifest_path.name, "old": current_version, "new": latest_version}


def main():
    args = sys.argv[1:]
    dry_run = "--dry-run" in args
    all_manifests = "--all" in args
    args = [a for a in args if not a.startswith("--")]

    if all_manifests:
        paths = sorted(BUCKET_DIR.glob("*.json"))
    elif args:
        paths = [Path(a) for a in args]
        for p in paths:
            if not p.exists():
                # 尝试在 bucket 目录查找
                alt = BUCKET_DIR / p.name
                if alt.exists():
                    paths[paths.index(p)] = alt
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
