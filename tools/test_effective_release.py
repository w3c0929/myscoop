#!/usr/bin/env python3
"""单测：release 预检（pick_effective_release）与预发布版本串检测（_version_looks_prerelease）

覆盖：rc/beta 版本串判定、prerelease 标志、无 Windows 资产、draft/untagged、平台过滤、
allow_prerelease 放行（更新路径行为）。fetch_json 用 monkeypatch 替换为离线夹具。
"""
import importlib.util

spec = importlib.util.spec_from_file_location("mu", "myscoop-update.py")
mu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mu)

# 1) 预发布版本串检测
TRUE = ["0.16.0-rc3", "2.0-beta.1", "1.0.0-alpha", "3.0.0-preview2",
        "1.0-pre", "1.0.0-dev", "1.2.3-rc.1", "7.0-nightly"]
FALSE = ["1.0.0", "2.1.3", "5.0.1", "2026.6.850.0", "prism-b10743-adfffbe",
         "premium-1.0", "search-2.0", "1.0-arch"]
for v in TRUE:
    assert mu._version_looks_prerelease(v) is True, v
for v in FALSE:
    assert mu._version_looks_prerelease(v) is False, v
print("预发布版本串检测 OK")

# 2) _ver_of_tag
assert mu._ver_of_tag("v1.2.3") == "1.2.3"
assert mu._ver_of_tag("windows-v0.1.0") == "0.1.0"
assert mu._ver_of_tag("prism-b10743-adfffbe") == "prism-b10743-adfffbe"
print("_ver_of_tag OK")


def rel(tag, pre=False, assets=("app-1.0-win-x64.zip",), draft=False):
    return {"tag_name": tag, "prerelease": pre, "draft": draft,
            "assets": [{"name": n} for n in assets]}


WIN = ("app-1.0-win-x64.zip",)
NONWIN = ("app-1.0-linux-x64.tar.gz",)

orig = mu.fetch_json
try:
    # 3) 跳过 prerelease 标志为真的，取最新稳定版
    mu.fetch_json = lambda url: [rel("v2.0.0-rc1", True), rel("v1.9.0")]
    assert mu.pick_effective_release("o", "r")["tag_name"] == "v1.9.0"
    print("跳过 prerelease 标志 OK")

    # 4) rc 版本串即使 prerelease=False 也跳过（kvllama 情形），回退到老稳定版
    mu.fetch_json = lambda url: [rel("v0.16.0-rc3", False), rel("v0.15.0")]
    assert mu.pick_effective_release("o", "r")["tag_name"] == "v0.15.0"
    print("rc 版本串拦截（kvllama 情形）OK")

    # 5) 只有 rc → None（--add 会跳过）
    mu.fetch_json = lambda url: [rel("v0.16.0-rc3", False)]
    assert mu.pick_effective_release("o", "r") is None
    print("仅预发布 → None OK")

    # 6) allow_prerelease=True（更新路径）→ 取最新，含 rc
    mu.fetch_json = lambda url: [rel("v0.16.0-rc3", False), rel("v0.15.0")]
    assert mu.pick_effective_release("o", "r", allow_prerelease=True)["tag_name"] == "v0.16.0-rc3"
    print("allow_prerelease 放行 OK")

    # 7) 最新 release 无 Windows 资产 → 跳到下一个
    mu.fetch_json = lambda url: [rel("v3.0.0", False, NONWIN), rel("v2.0.0", False, WIN)]
    assert mu.pick_effective_release("o", "r")["tag_name"] == "v2.0.0"
    print("无 Windows 资产跳过 OK")

    # 8) draft / untagged 跳过
    mu.fetch_json = lambda url: [rel("v9", False, WIN, draft=True), rel("untagged-abc", False, WIN),
                                 rel("v8.0.0")]
    assert mu.pick_effective_release("o", "r")["tag_name"] == "v8.0.0"
    print("draft/untagged 跳过 OK")

    # 9) 平台过滤：外平台 tag 跳过
    mu.fetch_json = lambda url: [rel("macos-v3.0"), rel("v2.0.0")]
    assert mu.pick_effective_release("o", "r", want_platform="windows")["tag_name"] == "v2.0.0"
    print("平台过滤 OK")

    # 10) 传入 rels 时不重复抓取（fetch_json 不被调用）
    def boom(url):
        raise AssertionError("不应再调用 fetch_json")
    mu.fetch_json = boom
    assert mu.pick_effective_release("o", "r", rels=[rel("v1.0.0")])["tag_name"] == "v1.0.0"
    print("rels 复用 OK")
finally:
    mu.fetch_json = orig

print("ALL PASS")
