#!/usr/bin/env python3
"""单测：注册型关键词收敛、两档 notes、notes 合并、installer 模式迁移带 notes"""
import importlib.util
import json
import os
import tempfile

spec = importlib.util.spec_from_file_location("mu", "myscoop-update.py")
mu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mu)

# 1) 强信号词收敛：弱信号词不再误命中
assert mu.needs_registration({"name": "qingjian", "description": "输入法"}) is True
assert mu.needs_registration({"name": "mytool", "description": "text service helper"}) is False
assert mu.needs_registration({"name": "mytool", "description": "shell extension utils"}) is False
assert mu.needs_registration({"name": "driverstoreexplorer", "description": "驱动管理"}) is True
assert mu.needs_registration({"name": "vim", "description": "编辑器"}) is False
print("needs_registration 强信号词 OK")

# 2) 输入法类 → IME 激活指引
f = mu.installer_mode_fields(True, {"name": "qingjian", "description": "输入法"})
assert f["notes"] == [mu.NOTE_IME_ACTIVATE], f["notes"]
print("IME notes OK")

# 3) 其他注册型 → 通用指引
f2 = mu.installer_mode_fields(True, {"name": "shellex", "description": "右键菜单工具"})
assert f2["notes"] == [mu.NOTE_REG_ACTIVATE], f2["notes"]
print("通用 notes OK")

# 4) 已有 notes 合并（str 与 list 两种）
f3 = mu.installer_mode_fields(True, {"name": "qingjian", "description": "输入法", "notes": "自定义说明"})
assert f3["notes"] == ["自定义说明", mu.NOTE_IME_ACTIVATE]
f4 = mu.installer_mode_fields(True, {"name": "qingjian", "description": "输入法",
                                     "notes": [mu.NOTE_IME_ACTIVATE, "旧条目"]})
assert f4["notes"] == [mu.NOTE_IME_ACTIVATE, "旧条目"], "去重+保留旧条目"
print("notes 合并 OK")

# 5) 迁移命令：存量 Inno 清单 → installer 模式 + notes
d = tempfile.mkdtemp()
p = os.path.join(d, "demo.json")
json.dump({"version": "1.0", "description": "某输入法", "innosetup": True, "bin": "x.exe"},
          open(p, "w", encoding="utf-8"))
assert mu.migrate_installer_mode(p) is True
m = json.load(open(p, encoding="utf-8"))
assert "innosetup" not in m and "installer" in m and "notes" in m
assert m["notes"][0] == mu.NOTE_IME_ACTIVATE
assert mu.migrate_installer_mode(p) is False  # 幂等
print("迁移+notes OK")

# 6) NSIS pre_install 迁移带通用 notes
json.dump({"version": "1.0", "description": "上下文菜单工具", "pre_install": ["x"]},
          open(p, "w", encoding="utf-8"))
assert mu.migrate_installer_mode(p) is True
m = json.load(open(p, encoding="utf-8"))
assert m["notes"] == [mu.NOTE_REG_ACTIVATE] and m["installer"]["args"] == ["/S", "/D=$dir"]
print("NSIS 迁移 notes OK")

print("ALL PASS")