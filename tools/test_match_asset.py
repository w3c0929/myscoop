#!/usr/bin/env python3
"""单测：match_asset 扩展名家族分级（压缩包互通 / 安装包严格 / 精确优先 / 归一兜底）"""
import importlib.util

spec = importlib.util.spec_from_file_location("mu", "myscoop-update.py")
mu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mu)

ASSETS = [
    {"name": "Cinetry_0.8.4+48_windows.7z"},
    {"name": "Cinetry_0.8.4+48_windows.zip"},
    {"name": "Cinetry_0.8.4+48_windows.exe"},
    {"name": "Cinetry_0.8.4+48_linux.tar.gz"},
    {"name": "Other_1.0_win.zip"},
]

# 1) 同扩展名优先：请求 zip，资产里 zip/7z 都在 → 必须选中 zip
r = mu.match_asset("https://x/Cinetry_0.8.4+48_windows.zip", ASSETS)
assert r["name"] == "Cinetry_0.8.4+48_windows.zip", r
print("同扩展名优先 OK")

# 2) 压缩包家族互通：请求 zip，只有 7z 在 → 选 7z（发布方换容器不再卡更新）
r2 = mu.match_asset("https://x/Cinetry_0.8.4+48_windows.zip",
                    [{"name": "Cinetry_0.8.4+48_windows.7z"}])
assert r2["name"] == "Cinetry_0.8.4+48_windows.7z", r2
print("zip→7z 压缩包互通 OK")

# 3) tar.gz → tar.xz 互通
r3 = mu.match_asset("https://x/app_1.0_linux.tar.gz",
                    [{"name": "app_1.0_linux.tar.xz"}])
assert r3["name"] == "app_1.0_linux.tar.xz", r3
print("tar.gz→tar.xz 互通 OK")

# 4) zip↔exe 不同家族：拒绝（防形态误配）
r4 = mu.match_asset("https://x/Cinetry_0.8.4+48_windows.zip",
                    [{"name": "Cinetry_0.8.4+48_windows.exe"}])
assert r4 is None, r4
print("zip→exe 拒绝 OK")

# 5) 基础名不同（版本段外差异）→ None
r5 = mu.match_asset("https://x/Cinetry_1.0_win.zip",
                    [{"name": "Other_1.0_win.zip"}])
assert r5 is None
print("基础名不同拒绝 OK")

# 6) 精确同名仍然第一时间命中
r6 = mu.match_asset("https://x/Cinetry_0.8.4+48_windows.7z", ASSETS)
assert r6["name"] == "Cinetry_0.8.4+48_windows.7z"
print("精确匹配优先 OK")

# 7) 回归：构建号漂移（+47→+48）仍能靠归一匹配
r7 = mu.match_asset("https://x/Cinetry_0.8.4+47_windows.zip", ASSETS)
assert r7["name"] == "Cinetry_0.8.4+48_windows.zip", r7
print("构建号漂移回归 OK")

print("ALL PASS")