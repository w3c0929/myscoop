#!/usr/bin/env python3
"""单测：构建号漂移处理（sync_build_asset / heal_url_drift / 去模板化）"""
import importlib.util
import json
import os
import tempfile

spec = importlib.util.spec_from_file_location("mu", "myscoop-update.py")
mu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mu)

ASSETS = [
    {"name": "Cinetry_0.8.4+48_windows.zip",
     "browser_download_url": "https://x/Cinetry_0.8.4%2B48_windows.zip",
     "digest": "sha256:aaaa"},
    {"name": "Cinetry_0.8.4+48_linux.AppImage",
     "browser_download_url": "https://x/Cinetry_0.8.4+48_linux.AppImage",
     "digest": "sha256:bbbb"},
]

# 1) sync_build_asset：顶层漂移 → 回写真实名 + 整体移除 autoupdate + extract_dir 同步
m = {"url": "https://x/Cinetry_0.8.4+47_windows.zip",
     "extract_dir": "Cinetry_0.8.4+47_windows",
     "autoupdate": {"url": "https://x/Cinetry_$version+47_windows.zip",
                    "extract_dir": "Cinetry_$version+47_windows"}}
res = mu.sync_build_asset(m, ASSETS[0], "https://x/Cinetry_0.8.4+47_windows.zip")
assert res is True
assert "autoupdate" not in m, "顶层应整体移除 autoupdate"
assert m["extract_dir"] == "Cinetry_0.8.4+48_windows"
print("sync_build_asset 顶层 OK")

# 2) 同名（无漂移）→ False 且不动
m2 = {"url": "https://x/Cinetry_0.8.4+48_windows.zip", "autoupdate": {"url": "t"}}
assert mu.sync_build_asset(m2, ASSETS[0], "https://x/Cinetry_0.8.4+48_windows.zip") is False
assert m2["autoupdate"] == {"url": "t"}
print("sync_build_asset 无漂移 OK")

# 3) 架构块漂移：移除该 arch 的 autoupdate，其他架构保留
m3 = {"architecture": {"64bit": {"url": "https://x/A_1.0+1_win.zip", "hash": "h1"}},
      "autoupdate": {"architecture": {
          "64bit": {"url": "https://x/A_$version+1_win.zip"},
          "32bit": {"url": "https://x/A_$version+1_win32.zip"}}}}
a1 = {"name": "A_1.0+2_win.zip", "browser_download_url": "https://x/A_1.0+2_win.zip", "digest": "sha256:n1"}
res3 = mu.sync_build_asset(m3, a1, "https://x/A_1.0+1_win.zip", arch="64bit")
assert res3 is True
assert "64bit" not in m3["autoupdate"]["architecture"]
assert "32bit" in m3["autoupdate"]["architecture"], "其他架构模板保留"
print("sync_build_asset 架构 OK")

# 4) heal_url_drift：版本未变时 URL 漂移自愈
m4 = {"url": "https://x/Cinetry_0.8.4+47_windows.zip",
      "hash": "sha256:old",
      "extract_dir": "Cinetry_0.8.4+47_windows",
      "autoupdate": {"url": "tpl"}}
assert mu.heal_url_drift(m4, ASSETS) is True
assert m4["url"] == ASSETS[0]["browser_download_url"]
assert m4["hash"] == "sha256:aaaa"
assert "autoupdate" not in m4
print("heal_url_drift OK")

# 5) heal 无漂移 → False
m5 = {"url": ASSETS[0]["browser_download_url"], "hash": "sha256:aaaa"}
assert mu.heal_url_drift(m5, ASSETS) is False
print("heal 无漂移 OK")

print("ALL PASS")