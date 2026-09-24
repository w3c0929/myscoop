#!/usr/bin/env python3
"""单测：detect_arch x86_64/i686 修复 + is_windows_asset 平台二进制/无扩展名过滤"""
import importlib.util

spec = importlib.util.spec_from_file_location("mu", "myscoop-update.py")
mu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mu)

# 1) x86_64 判 64bit（旧逻辑误判 32bit——含 x86 子串）
assert mu.detect_arch("ttyd.x86_64") == "64bit"
assert mu.detect_arch("app-1.2.3-x86_64.zip") == "64bit"
assert mu.detect_arch("ttyd.i686") == "32bit"
assert mu.detect_arch("ttyd.i386") == "32bit"
print("x86_64/i686 架构修复 OK")

# 2) 常规命名回归（不受影响）
assert mu.detect_arch("app-1.0-win-x64.zip") == "64bit"
assert mu.detect_arch("app-1.0-win-32bit.zip") == "32bit"
assert mu.detect_arch("app-1.0-arm64.zip") == "arm64"
assert mu.detect_arch("app-1.0-x86.zip") == "32bit"
assert mu.detect_arch("app-1.0-amd64.zip") == "64bit"
print("常规架构回归 OK")

# 3) 平台裸二进制过滤（ttyd 场景：无 .exe 跨平台产物）
for n in ["ttyd.arm", "ttyd.armhf", "ttyd.i686", "ttyd.x86_64", "ttyd.aarch64",
          "ttyd.s390x", "ttyd.mips", "ttyd.mips64el", "ttyd.win32.exe"]:
    if n == "ttyd.win32.exe":
        assert mu.is_windows_asset(n), n
    else:
        assert not mu.is_windows_asset(n), n
print("平台裸二进制过滤 OK")

# 4) 无扩展名校验文件过滤（SHA256SUMS）；win 标记的无扩展名保留
assert not mu.is_windows_asset("SHA256SUMS")
assert not mu.is_windows_asset("CHANGELOG")
assert mu.is_windows_asset("windows-helper")  # 含 win 标记的无扩展名
print("无扩展名过滤 OK")

# 5) 正常 Windows 资产不受影响
for n in ["app-1.0-win-x64.zip", "Setup_1.0_x64.exe", "app-1.0_win7.msi", "app-1.0-7z.7z"]:
    assert mu.is_windows_asset(n), n
print("正常 Windows 资产回归 OK")

print("ALL PASS")