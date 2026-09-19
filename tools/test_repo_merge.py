#!/usr/bin/env python3
"""单测：仓库模式二跑合并（--exe-name + 扁平化 + merge 保留；幂等）"""
import importlib.util
import json
import os
import tempfile

spec = importlib.util.spec_from_file_location("mu", "myscoop-update.py")
mu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mu)

FLAT = mu.FLATTEN_PRE_INSTALL

# 1) 二跑模拟：旧清单（首跑，无 bin）+ 新模板（zip + --exe-name）
d = tempfile.mkdtemp()
p = os.path.join(d, "tubatools.json")
old = {"version": "1.6.1",
       "architecture": {"64bit": {"url": "u64", "hash": "h64"},
                        "32bit": {"url": "u32", "hash": "h32"}},
       "description": "图吧工具箱 CE",
       "notes": "请手动添加 bin 和 shortcuts"}
json.dump(old, open(p, "w", encoding="utf-8"))

tpl = {"version": "1.6.1",
       "architecture": {"64bit": {"url": "u64", "hash": "h64"},
                        "32bit": {"url": "u32", "hash": "h32"}},
       "description": "图吧工具箱 CE",
       "bin": "图吧工具箱WinUI3.exe",
       "shortcuts": [["图吧工具箱WinUI3.exe", "tubatools"]],
       "pre_install": [FLAT]}
kept = mu.merge_existing_manifest(p, tpl)
assert kept == ["notes"], kept  # notes 保留（模板无），其余由模板覆盖
assert tpl["bin"] == "图吧工具箱WinUI3.exe"
assert tpl["architecture"]["64bit"]["url"] == "u64"
assert tpl["pre_install"] == [FLAT]
print("二跑合并（bin/pre_install 写入 + notes 保留）OK")

# 2) 幂等：同样的模板再 merge → 无新保留、字段不变
kept2 = mu.merge_existing_manifest(p, tpl)
assert kept2 == [], kept2
print("幂等 OK")

# 2b) 模拟二跑落盘（仓库模式写盘），作为三跑的前提
json.dump(tpl, open(p, "w", encoding="utf-8"))

# 3) 三跑无 --exe-name（模板无 bin）→ 旧 bin/shortcuts/pre_install 全部保留
tpl3 = {"version": "1.6.1", "architecture": old["architecture"]}
kept3 = mu.merge_existing_manifest(p, tpl3)
assert "bin" in kept3 and "shortcuts" in kept3 and "pre_install" in kept3, kept3
assert tpl3["bin"] == "图吧工具箱WinUI3.exe"
assert tpl3["pre_install"] == [FLAT]
print("无 exe-name 三跑 → 旧字段全部保留 OK")

# 4) 扁平化脚本自带保护（无目录时不报错）——常量结构断言
assert "Get-ChildItem" in FLAT and "if ($d)" in FLAT and "Move-Item" in FLAT
print("FLATTEN 保护结构 OK")

print("ALL PASS")