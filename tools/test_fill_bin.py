#!/usr/bin/env python3
"""单测：--dl/--fill-bin 多架构资产探测辅助（arch_url_hash：顶层优先 / 64bit / 回退 / 缺省）"""
import importlib.util

spec = importlib.util.spec_from_file_location("mu", "myscoop-update.py")
mu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mu)

# 1) 顶层 url/hash 优先
m1 = {"url": "https://x/app.zip", "hash": "sha256:aaa"}
u, h = mu.arch_url_hash(m1)
assert u == "https://x/app.zip" and h == "aaa", (u, h)
print("顶层优先 OK")

# 2) 多架构：取 64bit url/hash
m2 = {
    "architecture": {
        "64bit": {"url": "https://x/app-x64.zip", "hash": "sha256:bbb"},
        "arm64": {"url": "https://x/app-arm64.zip", "hash": "sha256:ccc"},
    }
}
u, h = mu.arch_url_hash(m2)
assert u == "https://x/app-x64.zip" and h == "bbb", (u, h)
print("多架构 64bit OK")

# 3) 无 64bit → 回退 32bit/arm64 首个
m3 = {"architecture": {"arm64": {"url": "https://x/app-arm64.zip", "hash": "sha256:ddd"},
                       "32bit": {"url": "https://x/app-x86.zip"}}}
u, h = mu.arch_url_hash(m3)
assert u == "https://x/app-x86.zip" and h == "", (u, h)
print("无 64bit 回退 OK")

# 4) 顶层无 url + 多架构无 url → 空
assert mu.arch_url_hash({}) == ("", "")
assert mu.arch_url_hash({"architecture": {"64bit": {"hash": "sha256:eee"}}}) == ("", "")
print("缺省空 OK")

# 5) hash 前缀剥离（sha256: 前缀）
m5 = {"url": "https://x/a.zip", "hash": "sha256:abcdef1234567890"}
_, h5 = mu.arch_url_hash(m5)
assert h5 == "abcdef1234567890", h5
print("hash sha256: 前缀剥离 OK")

print("ALL PASS")