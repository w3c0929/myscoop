#!/usr/bin/env python3
"""单测：资产筛选（source/脚本排除）、arch_url_hash 数组支持、重复来源检测、一致性校验"""
import importlib.util

spec = importlib.util.spec_from_file_location("mu", "myscoop-update.py")
mu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mu)

# 1) is_windows_asset：新增排除源码包 / 脚本 / 元数据
FALSE = ["kvmem-v0.16.0-rc3-prism.3-source.zip", "tool-1.0-src.zip", "app-1.0-src.7z",
         "start-bonsai-cli.ps1", "build.sh", "run.bat", "helper.py", "SHA256SUMS",
         "RELEASE-NOTES.md", "app-1.0-linux-x86_64.tar.gz", "app-1.0-macos.dmg",
         "app-1.0+48_windows.zip.sha256"]
TRUE = ["app-1.0-win-x64.zip", "tool-2.0-win64.7z", "setup-1.0-x64.exe", "pkg-1.0-x64.msi",
        "opensource-tool-1.0-win.zip", "sourceforge-app-1.0-win.zip"]
for n in FALSE:
    assert mu.is_windows_asset(n) is False, f"应排除: {n}"
for n in TRUE:
    assert mu.is_windows_asset(n) is True, f"应保留: {n}"
print("is_windows_asset 排除 source/脚本 OK")

# 2) arch_url_hash：数组型 url/hash 取首项（主程序）
m = {"architecture": {"64bit": {"url": ["https://x/main.zip", "https://x/cudart.zip"],
                                "hash": ["sha256:AA", "sha256:BB"]}}}
u, h = mu.arch_url_hash(m)
assert u == "https://x/main.zip" and h == "aa", (u, h)
m2 = {"url": ["https://x/a.exe", "https://x/b.exe"], "hash": ["sha256:CC", "sha256:DD"]}
u2, h2 = mu.arch_url_hash(m2)
assert u2 == "https://x/a.exe" and h2 == "cc", (u2, h2)
print("arch_url_hash 数组支持 OK")

# 3) find_duplicate_source：prllama 的 checkver 指向 PrismML-Eng/llama.cpp
hits = mu.find_duplicate_source("PrismML-Eng", "llama.cpp")
assert "prllama" in hits, hits
assert mu.find_duplicate_source("PrismML-Eng", "llama.cpp", exclude_app="prllama") == []
print("find_duplicate_source OK")

# 4) check_consistency：当前仓库 README/bucket/progress 应一致
assert mu.check_consistency() is True
print("check_consistency OK")

print("ALL PASS")
