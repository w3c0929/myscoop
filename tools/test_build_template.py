#!/usr/bin/env python3
"""单测：C 组合策略（模板构建号刷新 A / 去模板回退 B）+ --add 已存在清单合并保留"""
import importlib.util
import json
import os
import tempfile

spec = importlib.util.spec_from_file_location("mu", "myscoop-update.py")
mu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mu)

A48 = {"name": "Cinetry_0.8.4+48_windows.zip",
       "browser_download_url": "https://x/Cinetry_0.8.4%2B48_windows.zip",
       "digest": "sha256:aaaa"}
A49 = {"name": "Cinetry_0.8.5+49_windows.zip",
       "browser_download_url": "https://x/Cinetry_0.8.5%2B49_windows.zip",
       "digest": "sha256:bbbb"}

# 1) refresh：模板 +48 → 资产 +49 → 模板与 extract_dir 刷新为新构建号，返回 True
m = {"url": "https://x/Cinetry_0.8.5+48_windows.zip",
     "extract_dir": "Cinetry_0.8.5+48_windows",
     "autoupdate": {"url": "https://x/Cinetry_$version+48_windows.zip",
                    "extract_dir": "Cinetry_$version+48_windows"}}
r = mu.refresh_build_in_template(m, A49, "https://x/Cinetry_0.8.5+48_windows.zip")
assert r is True
assert m["autoupdate"]["url"] == "https://x/Cinetry_$version+49_windows.zip"
assert m["autoupdate"]["extract_dir"] == "Cinetry_$version+49_windows"
assert m["extract_dir"] == "Cinetry_0.8.5+49_windows"
print("refresh 模板构建号 OK")

# 2) refresh：无 +build 段的资产 → False（无法反推）
m2 = {"url": "https://x/a_1.0_win.zip", "autoupdate": {"url": "https://x/a_$version_win.zip"}}
r2 = mu.refresh_build_in_template(m2, {"name": "a_1.1_win.zip"}, "https://x/a_1.0_win.zip")
assert r2 is False
print("无法反推 → False OK")

# 3) handle_build_drift 组合：有模板可刷新 → 'refresh'（保留模板）
m3 = {"url": "https://x/Cinetry_0.8.5+48_windows.zip",
      "autoupdate": {"url": "https://x/Cinetry_$version+48_windows.zip"}}
r3 = mu.handle_build_drift(m3, A49, "https://x/Cinetry_0.8.5+48_windows.zip")
assert r3 == "refresh" and "autoupdate" in m3
print("组合策略 refresh OK")

# 4) handle_build_drift：无模板可刷新 → 'removed'（去模板化回退）
m4 = {"url": "https://x/Cinetry_0.8.5+48_windows.zip",
      "autoupdate": {"url": "https://x/Cinetry_$version+48_windows.zip"}}
# 构造无法反推：资产名无 +build
r4 = mu.handle_build_drift(m4, {"name": "Cinetry_0.8.5_other.zip",
                                "browser_download_url": "https://x/Cinetry_0.8.5_other.zip"},
                           "https://x/Cinetry_0.8.5+48_windows.zip")
assert r4 == "removed" and "autoupdate" not in m4
print("组合策略回退 removed OK")

# 5) heal：%2B 编码 URL vs 同名资产 → 不误判漂移
m5 = {"url": "https://x/Cinetry_0.8.4%2B48_windows.zip",
      "hash": "sha256:old", "autoupdate": {"url": "t"}}
assert mu.heal_url_drift(m5, [A48]) is False
print("heal %2B 不误判 OK")

# 6) heal：同 tag build 前进（+48 → +49，模板可刷新）→ 模板保留并刷新
m6 = {"url": "https://x/Cinetry_0.8.4%2B48_windows.zip",
      "hash": "sha256:old",
      "extract_dir": "Cinetry_0.8.4+48_windows",
      "autoupdate": {"url": "https://x/Cinetry_$version+48_windows.zip"}}
a49b = {"name": "Cinetry_0.8.4+49_windows.zip",
        "browser_download_url": "https://x/Cinetry_0.8.4%2B49_windows.zip",
        "digest": "sha256:c1c1c1"}
assert mu.heal_url_drift(m6, [a49b]) is True
assert m6["url"] == "https://x/Cinetry_0.8.4%2B49_windows.zip"
assert m6["hash"] == "sha256:c1c1c1"
assert m6["autoupdate"]["url"] == "https://x/Cinetry_$version+49_windows.zip"
assert m6["extract_dir"] == "Cinetry_0.8.4+49_windows"
print("heal build 前进刷新模板 OK")

# 7) merge_existing_manifest：旧清单人工字段保留，新模板字段覆盖
d = tempfile.mkdtemp()
p = os.path.join(d, "cinetry.json")
json.dump({"version": "0.8.4", "url": "old-url", "hash": "sha256:old",
           "bin": "cinetry.exe", "shortcuts": [["cinetry.exe", "Cinetry"]],
           "extract_dir": "old_dir"}, open(p, "w", encoding="utf-8"))
tpl = {"version": "0.8.4", "url": "new-url", "hash": "sha256:new"}
kept = mu.merge_existing_manifest(p, tpl)
assert kept == ["bin", "shortcuts", "extract_dir"], kept
assert tpl["url"] == "new-url" and tpl["bin"] == "cinetry.exe"
print("merge 合并保留 OK")

# 8) merge：目标不存在 → 空保留
tpl2 = {"version": "1.0"}
assert mu.merge_existing_manifest(os.path.join(d, "nope.json"), tpl2) == []
print("merge 不存在 OK")

print("ALL PASS")