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

# 9) generate_autoupdate_url：非语义 tag 子串模板化（llama.cpp 主程序场景）
#    tag prism-b10709-9a9394a 无点号 → 旧逻辑漏掉写死；新逻辑整体子串替换为 $version
u9 = mu.generate_autoupdate_url(
    "llama-prism-b10709-9a9394a-bin-win-cuda-13.3-x64.zip",
    "prism-b10709-9a9394a", False, "github", "o", "r")
assert u9 == "https://github.com/{owner}/{repo}/releases/download/$version/" \
             "llama-$version-bin-win-cuda-13.3-x64.zip", u9
print("非语义 tag 子串模板化 OK")

# 10) cudart 运行时：replace_in_name=False → 文件名完全写死（CUDA 版本与 tag 解耦）
u10 = mu.generate_autoupdate_url(
    "cudart-llama-bin-win-cuda-13.3-x64.zip",
    "prism-b10709-9a9394a", False, "github", "o", "r", replace_in_name=False)
assert u10 == "https://github.com/{owner}/{repo}/releases/download/$version/" \
              "cudart-llama-bin-win-cuda-13.3-x64.zip", u10
print("cudart 文件名保持写死 OK")

# 11) 常规语义 tag 回归：tag v1.2.3 + 文件名 app-1.2.3-x64.zip → 与旧逻辑等价
u11 = mu.generate_autoupdate_url("app-1.2.3-x64.zip", "v1.2.3", True, "github", "o", "r")
assert u11 == "https://github.com/{owner}/{repo}/releases/download/v$version/app-$version-x64.zip", u11
u11b = mu.generate_autoupdate_url("app-v1.2.3-x64.zip", "v1.2.3", True, "github", "o", "r")
assert u11b == "https://github.com/{owner}/{repo}/releases/download/v$version/app-v$version-x64.zip", u11b
print("常规语义 tag 回归 OK")

# 12) 短 tag 保护：tag v2 不启用子串替换（防误替换文件名其他位置），无点号版本段 → 原样
u12 = mu.generate_autoupdate_url("app2-x64.zip", "v2", True, "github", "o", "r")
assert u12 == "https://github.com/{owner}/{repo}/releases/download/v$version/app2-x64.zip", u12
# 多版本固定 tag（SublimeText 场景）：tag 不在文件名中 → fallback 点号版本逻辑（无点号 → 原样）
u12b = mu.generate_autoupdate_url("sublime-text-4200-x64.zip", "vSublimeText", True, "github", "o", "r")
assert u12b == "https://github.com/{owner}/{repo}/releases/download/v$version/sublime-text-4200-x64.zip", u12b
print("短 tag / 固定 tag 保护 OK")

print("ALL PASS")