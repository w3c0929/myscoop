#!/usr/bin/env python3
"""单测 sync_bin_version：版本化 bin 更正 / 固定名零影响 / pre_install 硬编码更正"""
import importlib.util

spec = importlib.util.spec_from_file_location("mu", "myscoop-update.py")
mu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mu)

# 场景1：bin 硬编码旧版本 → 应更正
m1 = {"bin": "Finch-1.6.3-setup-x64.exe",
      "shortcuts": [["Finch-1.6.3-setup-x64.exe", "finch-releases"]]}
r1 = mu.sync_bin_version(m1, "1.6.3", "1.7.1")
print("场景1 更正字段:", r1, "→ bin =", m1["bin"])
assert m1["bin"] == "Finch-1.7.1-setup-x64.exe"
assert m1["shortcuts"][0][0] == "Finch-1.7.1-setup-x64.exe"

# 场景2：固定名（Finch.exe）→ 零影响
m2 = {"bin": "Finch.exe", "shortcuts": [["Finch.exe", "Finch"]]}
r2 = mu.sync_bin_version(m2, "1.6.3", "1.7.1")
print("场景2 更正字段:", r2, "→ bin =", m2["bin"])
assert r2 == [] and m2["bin"] == "Finch.exe"

# 场景3：pre_install 硬编码旧版本文件名 → 更正
m3 = {"pre_install": [
    'Expand-7zipArchive "$dir\\Claude-Code-Haha-0.6.3-win-x64.exe" "$dir\\_extract"']}
r3 = mu.sync_bin_version(m3, "0.6.3", "0.6.4")
print("场景3 更正字段:", r3, "→", m3["pre_install"][0])
assert "0.6.4" in m3["pre_install"][0] and "0.6.3" not in m3["pre_install"][0]

# 场景4：architecture 下的 bin？bin 不在架构子块，但 shortcuts 数组嵌套保持正确
m4 = {"bin": ["Rapr-something.exe"], "shortcuts": [["x-1.0.26.exe", "X"]]}
r4 = mu.sync_bin_version(m4, "1.0.26", "1.0.27")
print("场景4 更正字段:", r4)
assert m4["shortcuts"][0][0] == "x-1.0.27.exe"

print("ALL PASS")