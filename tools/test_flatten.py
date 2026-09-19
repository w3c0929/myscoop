#!/usr/bin/env python3
"""单测：zip 单顶层目录扁平化探测逻辑（常量 + 探测函数）"""
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("mu", "myscoop-update.py")
mu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mu)


def detect(spec_keys, bin_given, no_flatten=False, has_pre=False):
    """模拟 zip 探测核心判定，返回 (should_add, tops)。判据（用户定稿）：
    顶层恰好只有一个文件夹且无散文件 → 扁平化；文件夹+文件并列/多文件夹 → 不扁平。"""
    files = [n for n in spec_keys if not n.endswith("/")]
    tops = sorted({n.split("/")[0] for n in files if "/" in n})
    has_top_files = any("/" not in n for n in files)
    if not (bin_given and not has_pre and not no_flatten):
        return False, tops
    return (len(tops) == 1 and bool(tops[0]) and not has_top_files), tops


# 1) 单顶层目录 + bin → 生成扁平化
ok, tops = detect(["Cinetry_0.8.4+48_windows/cinetry.exe",
                   "Cinetry_0.8.4+48_windows/data/x.bin"], True)
assert ok is True and tops == ["Cinetry_0.8.4+48_windows"], (ok, tops)
print("单顶层目录+bin → 生成 OK")

# 2) 多顶层目录 → 不生成
ok, tops = detect(["a/x.exe", "b/y.exe"], True)
assert ok is False and len(tops) == 2
print("多顶层目录 → 不生成 OK")

# 3) 顶层已有文件（exe 在根）但存在子目录 → 不生成（bin 已在根，无需扁平）
ok, tops = detect(["cinetry.exe", "data/x.bin"], True)
assert ok is False and tops == ["data"]
print("顶层已有文件 → 不生成 OK")

# 3b) 纯顶层文件（无任何目录层）→ 不生成
ok, tops = detect(["cinetry.exe", "lib.bin"], True)
assert ok is False and tops == []
print("无目录层 → 不生成 OK")

# 4) --no-flatten → 不生成
ok, tops = detect(["D/x.exe", "D/y.bin"], True, no_flatten=True)
assert ok is False
print("--no-flatten → 不生成 OK")

# 5) 已有 pre_install → 不覆盖
ok, tops = detect(["D/x.exe"], True, has_pre=True)
assert ok is False
print("已有 pre_install → 不覆盖 OK")

# 6) 未给 bin（--exe-name）→ 不生成（等用户指定后重跑）
ok, tops = detect(["D/x.exe"], False)
assert ok is False
print("未指定 bin → 不生成 OK")

# 7) 常量模板可用（含 Move-Item/Remove-Item 关键动作）
assert "$dir" in mu.FLATTEN_PRE_INSTALL
assert "Move-Item" in mu.FLATTEN_PRE_INSTALL and "Remove-Item" in mu.FLATTEN_PRE_INSTALL
print("FLATTEN_PRE_INSTALL 常量 OK")

# 8) 目录条目不计入文件集合（zip 尾斜杠条目）
ok, tops = detect(["D/x.exe", "D/sub/"], True)
assert ok is True
print("目录条目忽略 OK")

# 9) 单顶层打包目录（含 exe）→ 生成（cinetry 类）
ok, tops = detect(["TubaWinUi3_Portable_1.6.1_x64/图吧工具箱WinUI3.exe",
                   "TubaWinUi3_Portable_1.6.1_x64/src/a.dll"], True)
assert ok is True and tops == ["TubaWinUi3_Portable_1.6.1_x64"]
print("打包目录含 exe → 生成 OK")

# 10) src 资源目录无 exe → 按"唯一文件夹"判据：src+exe 并列（顶层有文件）→ 不生成（tubatools 事故回归）
ok, tops = detect(["src/Accessibility.dll", "src/AssistStudio.Core.dll",
                   "图吧工具箱WinUI3.exe", "图吧工具箱Winui3兼容版.exe"], True)
assert ok is False and tops == ["src"]
print("src+exe 并列 → 不生成 OK")

# 11) 唯一文件夹但目录内无 exe（纯数据目录）→ 仍生成（判据只看顶层结构，用户定稿）
ok, tops = detect(["data/model.qjm", "data/dict.qj"], True)
assert ok is True and tops == ["data"]
print("唯一文件夹（无 exe）→ 生成 OK")

assert "if ($d -and" in mu.FLATTEN_PRE_INSTALL and "-Filter *.exe" in mu.FLATTEN_PRE_INSTALL
print("条件脚本结构 OK")

print("ALL PASS")