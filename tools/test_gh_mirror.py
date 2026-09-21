#!/usr/bin/env python3
"""单测：myscoop-update.py GitHub 镜像加速（MYSCOOP_GH_MIRRORS / Scoop config aria2-mirrors；
候选拼接+协议补齐；非 GitHub 链接不镜像；无配置回归）"""
import importlib.util
import json
import os
import tempfile

spec = importlib.util.spec_from_file_location("mu", "myscoop-update.py")
mu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mu)

GH = "https://github.com/owner/repo/releases/download/v1.0/app-1.0-x64.zip"

# 1) mirror_candidates：完整 URL / 裸域名 → 自动补 https://；顺序保持
ms = ["https://hk.gh-proxy.org", "gh-proxy.com", "gh-proxy.org/"]
c = mu.mirror_candidates(GH, ms)
assert c == [
    "https://hk.gh-proxy.org/https://github.com/owner/repo/releases/download/v1.0/app-1.0-x64.zip",
    "https://gh-proxy.com/https://github.com/owner/repo/releases/download/v1.0/app-1.0-x64.zip",
    "https://gh-proxy.org/https://github.com/owner/repo/releases/download/v1.0/app-1.0-x64.zip",
], c
print("候选拼接+协议补齐 OK")

# 2) 非 GitHub release 链接 → 空候选（api.github.com / 官网直链均不镜像）
assert mu.mirror_candidates("https://api.github.com/repos/o/r", ms) == []
assert mu.mirror_candidates("https://down.example.com/app.zip", ms) == []
assert mu.mirror_candidates("https://github.com/o/r/releases/page/1", ms) == []  # 非 /download/
print("非 GitHub 下载链接不镜像 OK")

# 3) 无镜像配置 → 空候选（原行为）
assert mu.mirror_candidates(GH, []) == []
assert mu.mirror_candidates(GH, None) == []
print("无配置回归 OK")

# 4) gh_mirror_list：环境变量优先（逗号/空格分隔，去空）
old = os.environ.get("MYSCOOP_GH_MIRRORS")
os.environ["MYSCOOP_GH_MIRRORS"] = "https://hk.gh-proxy.org, gh-proxy.com ,"
assert mu.gh_mirror_list() == ["https://hk.gh-proxy.org", "gh-proxy.com"], mu.gh_mirror_list()
if old is None:
    del os.environ["MYSCOOP_GH_MIRRORS"]
else:
    os.environ["MYSCOOP_GH_MIRRORS"] = old
print("环境变量列表解析 OK")

# 5) gh_mirror_list：Scoop config.json aria2-mirrors 数组 / 字符串兼容 / 无文件 → []
d = tempfile.mkdtemp()
p = os.path.join(d, "config.json")
with open(p, "w", encoding="utf-8") as f:
    json.dump({"aria2-mirrors": ["https://a.g", "https://b.g"]}, f)
assert mu.gh_mirror_list(config_path=p) == ["https://a.g", "https://b.g"]
with open(p, "w", encoding="utf-8") as f:
    json.dump({"aria2-mirrors": "https://a.g https://b.g"}, f)
assert mu.gh_mirror_list(config_path=p) == ["https://a.g", "https://b.g"]
assert mu.gh_mirror_list(config_path=os.path.join(d, "nope.json")) == []
print("Scoop config 读取 OK")

# 6) probe_mirror_url：依赖网络的函数名存在且无配置时原样返回（快速路径不联网）
assert mu.probe_mirror_url(GH) == GH  # 无镜像配置（环境变量已清理）→ 不联网直接返回
print("无配置 probe 原样返回 OK")

print("ALL PASS")