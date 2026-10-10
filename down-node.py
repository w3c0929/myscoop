#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""down-node.py — ComfyUI 插件批量安装器（Python 版，替代 down-node.bat 全部功能）

=========================== 快速开始 ===========================
  1) 双击 down-node.bat（入口）即可，或命令行直接：
       python -X utf8 down-node.py                # 批量安装 PLUGINS 中启用的插件
       python -X utf8 down-node.py --list         # 只列出启用的插件（不执行）
       python -X utf8 down-node.py --dir <路径>   # 指定 custom_nodes 目录（默认见下方 NODES_DIR）
  2) 安装时会先自动探测 GitHub 加速镜像（见下），clone 失败自动回退直连重试。

=========================== 镜像加速（机制与 myscoop-update.py 一致） ===========================
  镜像列表来源（优先级从高到低）：
    1) 环境变量 MYSCOOP_GH_MIRRORS —— 逗号或空格分隔，可写完整 URL 或裸域名：
         set MYSCOOP_GH_MIRRORS=hk.gh-proxy.org,gh-proxy.com,gh-proxy.org
    2) Scoop config.json 的 aria2-mirrors 数组（C:/Users/<用户>/.config/scoop/config.json，
       与 Scoop download.ps1 补丁共用同一套镜像）
    3) 本文件内置 DEFAULT_MIRRORS 默认列表
  探测方式：用真实小文件（range 1KB）逐个探测镜像（GitHub 首页探测不可靠——
  镜像常对首页返回 403/404 但对真实文件正常）；取第一个可达镜像；
  全部不可达自动回退直连；git clone 镜像失败也会回退直连重试一次。
  格式不兼容的镜像（如 gitclone.com 的 /github.com/ 型 URL）会在探测时被自动过滤。
  可选环境变量：TO=6（探测超时秒数）  VB=1（1 显示探测过程，0 静默）

=========================== 插件清单编辑 ===========================
  编辑下方 PLUGINS 列表：取消注释即安装，注释即跳过（与 down-node.bat 的 rem 开关习惯一致）。
  约定：目标文件夹名 = 仓库名（最后一个斜杠后的部分）；已存在的插件自动跳过。
  勾选示例：克隆 "yolain/ComfyUI-Easy-Use" 会创建 custom_nodes/ComfyUI-Easy-Use/

=========================== 三类下载函数（按需调用） ===========================
  除插件 clone 外，本脚本提供三个通用下载函数（均自动走镜像 + 直连回退）：
      download_raw("owner/repo/path/file.ext", "本地文件名", mirror)      # raw 文件
      download_release("owner/repo", "v1.0.8", "本地.zip", mirror)        # Release 包并解压
      download_gist("gist_id", "文件名", "本地文件名", mirror)             # Gist 内容
  也可在其它脚本中 import 复用：
      import importlib.util
      spec = importlib.util.spec_from_file_location("dn", "down-node.py")
      dn = importlib.util.module_from_spec(spec); spec.loader.exec_module(dn)
      m = dn.pick_mirror()                     # 返回 "https://镜像域名/" 或 ""（直连）
      dn.download_raw("octocat/Hello-World/master/README", "readme.txt", m)

=========================== 其他说明 ===========================
  · 需要 Python 3（脚本自带 utf-8 模式运行，Windows 控制台中文不乱码）
  · 会自动创建 .disabled 插件禁用目录（与旧 bat 行为一致）
  · 全部路径建议使用正斜杠（Windows 兼容且免转义）
"""
import json
import os
import re
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

# ========== 基础路径与默认镜像（可改） ==========
NODES_DIR = "D:/scoop/apps/comfyui/current/ComfyUI/custom_nodes"
GH_HOME = "https://github.com/"
DEFAULT_MIRRORS = ["https://hk.gh-proxy.org", "https://gh-proxy.com", "https://gh-proxy.org"]

# ========== 插件安装列表（取消注释即安装，注释即跳过） ==========
# 格式与 down-node.bat 的"文件夹名必须与仓库名一致"约定一致。
PLUGINS = [
    # "Dontdrunk/ComfyUI-DD-Translation",
    # "FNGarvin/ComfyUI-AutoModelDownloader",
    # "Fannovel16/comfyui_controlnet_aux",
    "yolain/ComfyUI-Easy-Use",
    # "fancyfeast/ComfyUI-Img_Tag",
    # "stepfun-ai/ComfyUI-StepAudioTTS",
    # "zzz40500/ComfyUI-EdgeTTS",
    # "voicepaw/ComfyUI-FreeVC_wrapper",
    # "ltdrdata/ComfyUI-Manager",
    # "Kijai/ComfyUI-WanVideoWrapper",
    # "fancyfeast/ComfyUI-StartPatch",
    # "Tencent/HunyuanLoom-ComfyUI",
    # "city96/ComfyUI-GGUF",
    # "fancyfeast/ComfyUI-Fluxtapoz",
    # "fancyfeast/ComfyUI-Florence2",
    # "pythongosssss/ComfyUI-Custom-Scripts",
    # "crystian/ComfyUI-Crystools",
    # "PowerHouseMan/ComfyUI-AdvancedLivePortrait",
    # "ssitu/ComfyUI_UltimateSDUpscale",
    # "TinyTerra/ComfyUI_TTP_Toolset",
    # "ksm26/ComfyUI_Sonic",
    # "fancyfeast/ComfyUI-SLK-Joy-Caption",
    # "RyanOnTheInside/ComfyUI-RyanOnTheInside",
    # "guoyww/ComfyUI-PuLID-Flux-Enhanced",
    # "chflame163/ComfyUI_LayerStyle",
    # "chflame163/ComfyUI_LayerStyle_Advance",
    # "cubiq/ComfyUI_IPAdapter_plus",
    # "cubiq/ComfyUI_essentials",
    # "Suzie1/ComfyUI_Comfyroll_CustomNodes",
    # "fancyfeast/ComfyUI-bnb-nf4-fp4-Loaders",
    # "fancyfeast/ComfyUI-AdvancedRefluxControl",
    # "melMass/comfy_mtb",
    # "XLabs-AI/x-flux-comfyui",
    # "WASasquatch/was-node-suite-comfyui",
    # "rgthree/rgthree-comfy",
    # "jmchilton/efficiency-nodes-comfyui",
    # "Kosinkadink/ComfyUI-VideoHelperSuite",
    # "fancyfeast/comfyui-tooling-nodes",
    # "kijai/ComfyUI-SUPIR",
    "thisjam/comfyui-sixgod_prompt",
    # "benjiamin104/comfyui-ollama",
    # "fancyfeast/comfyui-nettools",
    # "Kijai/ComfyUI-MVAdapter",
    # "Kijai/ComfyUI-MMAudio",
    # "ming007/ComfyUI-MingNodes",
    # "Lightricks/ComfyUI-LTXTricks",
    # "kjhuanhao/comfyui-liveportraitkj",
    # "kjhuanhao/KJNodes",
    # "cubiq/ComfyUI-IPAdapter-Flux",
    # "ltdrdata/comfyui-inpaint-nodes",
    # "fancyfeast/ComfyUI-Inpaint-CropAndStitch",
    # "ltdrdata/ComfyUI-Impact-Pack",
    # "ltdrdata/comfyui-impact-subpack",
    # "fancyfeast/ComfyUI-IC-Light",
    # "11cafe/comfyui-workspace-manager",
    # "fancyfeast/quick-connections",
    # "fancyfeast/ComfyUI-NodeAligner",
]


# ========== 镜像加速（机制与 myscoop-update.py 一致） ==========
# 探测用真实文件（range 1KB）而不是 GitHub 首页：镜像对首页常返回 403/301/404 但代理真实文件正常；
# 探测即验证拼接格式——不同格式的镜像（如 gitclone.com/github.com/...）会自然被过滤。
PROBE_URL = "https://github.com/octocat/Hello-World/archive/refs/heads/master.zip"


def gh_mirror_list():
    """镜像列表：MYSCOOP_GH_MIRRORS 环境变量（逗号/空格分隔，完整 URL 或裸域名）优先，
    其次 Scoop config.json 的 aria2-mirrors 数组（与 download.ps1 补丁共用），最后内置默认。"""
    env = os.environ.get("MYSCOOP_GH_MIRRORS", "").strip()
    if env:
        return [m.strip() for m in env.replace(",", " ").split() if m.strip()]
    try:
        cfg = json.loads((Path.home() / ".config" / "scoop" / "config.json").read_text(encoding="utf-8"))
        ms = cfg.get("aria2-mirrors", [])
        if isinstance(ms, str):
            ms = [x for x in ms.replace(",", " ").split() if x]
        ms = [str(m).strip() for m in ms if str(m).strip()]
        if ms:
            return ms
    except Exception:
        pass
    return list(DEFAULT_MIRRORS)


def pick_mirror(timeout=None):
    """探测第一个可达镜像（range 1KB 真实文件），返回前缀（https://镜像域名/）；
    全部不可达返回 ""（直连）。"""
    timeout = timeout or int(os.environ.get("TO", "6"))
    quiet = os.environ.get("VB", "1") != "1"
    for m in gh_mirror_list():
        base = m.strip().rstrip("/")
        if not re.match(r"^https?://", base):
            base = "https://" + base
        test_url = f"{base}/{PROBE_URL}"
        if not quiet:
            print(f"[检测] 镜像 {base} ...")
        try:
            req = urllib.request.Request(test_url, headers={
                "User-Agent": "down-node", "Range": "bytes=0-1023"})
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                if resp.status in (200, 206):
                    if not quiet:
                        print(f"[信息] 使用镜像: {base}")
                    return base + "/"
        except Exception:
            if not quiet:
                print(f"[警告] 镜像 {base} 不可用")
    print("[警告] 所有镜像不可用，将使用直连（可能较慢）")
    return ""


# ========== 下载函数（均自动走选中镜像，失败回退直连） ==========
def _download(url, dest, mirror, timeout=None):
    """下载到本地文件；镜像失败自动回退直连。返回 True/False。"""
    timeout = timeout or int(os.environ.get("TO", "6")) * 3
    candidates = [f"{mirror}{url}"] if mirror else []
    candidates.append(url)  # 最后直连兜底
    for u in candidates:
        try:
            req = urllib.request.Request(u, headers={"User-Agent": "down-node"})
            with urllib.request.urlopen(req, timeout=timeout) as resp, open(dest, "wb") as f:
                while True:
                    chunk = resp.read(65536)
                    if not chunk:
                        break
                    f.write(chunk)
            return True
        except Exception:
            continue
    return False


def download_raw(owner_repo_path, dest, mirror):
    """下载 raw 文件: owner/repo/path/file → 本地"""
    url = f"https://raw.githubusercontent.com/{owner_repo_path}"
    ok = _download(url, dest, mirror)
    print(f"[raw] {owner_repo_path} -> {dest} {'√' if ok else '× 失败'}")
    return ok


def download_release(owner_repo, tag, dest, mirror):
    """下载 Release 压缩包并解压到当前目录: owner/repo → archive/refs/tags/tag.zip"""
    url = f"{GH_HOME}{owner_repo}/archive/refs/tags/{tag}.zip"
    tmp = Path(dest).with_suffix(".zip")
    ok = _download(url, tmp, mirror)
    if ok:
        try:
            with zipfile.ZipFile(tmp) as z:
                z.extractall(".")
            print(f"[release] {owner_repo}@{tag} 已下载并解压到当前目录")
        except Exception as e:
            print(f"[release] 解压失败: {e}")
            return False
        tmp.unlink(missing_ok=True)
    else:
        print(f"[release] {owner_repo}@{tag} 下载失败")
    return ok


def download_gist(gist_id, filename, dest, mirror):
    """下载 Gist 内容: gist_id/raw/filename → 本地"""
    url = f"https://gist.githubusercontent.com/{gist_id}/raw/{filename}"
    ok = _download(url, dest, mirror)
    print(f"[gist] {gist_id}/{filename} -> {dest} {'√' if ok else '× 失败'}")
    return ok


# ========== 插件克隆 ==========
def clone_plugin(repo, nodes_dir, mirror):
    """镜像 clone，失败回退直连；已存在则跳过。返回 True/False。"""
    dest = nodes_dir / repo.split("/")[-1]
    if dest.exists():
        print(f"[跳过] {dest.name} 已存在")
        return True
    ok = False
    if mirror:
        r = subprocess.run(["git", "clone", f"{mirror}{GH_HOME}{repo}.git", str(dest)],
                           capture_output=True)
        if r.returncode == 0:
            ok = True
        else:
            print(f"[回退] 镜像 clone 失败（{repo}），改直连重试 ...")
    if not ok:
        r = subprocess.run(["git", "clone", f"{GH_HOME}{repo}.git", str(dest)],
                           capture_output=True)
        ok = r.returncode == 0
    print(f"[克隆] {repo} -> {dest.name} {'√' if ok else '× 失败'}")
    return ok


def main():
    args = sys.argv[1:]
    nodes_dir = Path(NODES_DIR)
    if "--dir" in args:
        nodes_dir = Path(args[args.index("--dir") + 1])
    if not nodes_dir.exists():
        print(f"[错误] 目录不存在: {nodes_dir}")
        sys.exit(1)

    dots = (nodes_dir / ".disabled")
    dots.mkdir(exist_ok=True)
    print(f"[√] 目标目录: {nodes_dir}")
    print(f"[√] .disabled 插件禁用目录就绪")

    if "--list" in args:
        print(f"\n启用的插件（{len(PLUGINS)} 个）:")
        for p in PLUGINS:
            print(f"  - {p}")
        return

    mirror = pick_mirror()
    print()
    ok_cnt = 0
    for repo in PLUGINS:
        if clone_plugin(repo, nodes_dir, mirror):
            ok_cnt += 1
    print(f"\n===== 全部执行完毕（成功 {ok_cnt}/{len(PLUGINS)}） =====")


if __name__ == "__main__":
    main()