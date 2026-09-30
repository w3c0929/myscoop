#!/usr/bin/env python3
"""单测：release 预检 pick_effective_release（只按资产判定）与 _version_looks_prerelease

规则：候选 = 非 draft/untagged，且**含 Windows 资产**；取最新一个（不看 prerelease/rc）。
fetch_json 用 monkeypatch 替换为离线夹具。
"""
import importlib.util

spec = importlib.util.spec_from_file_location("mu", "myscoop-update.py")
mu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mu)

# 1) 预发布版本串检测（仍用于候选表标注与直链提示；不再用于 --add 拦截）
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
    # 3) kvllama 情形：最新 v0.17.0 是零资产空 release → 往下取最新带 Windows 资产的
    mu.fetch_json = lambda url: [rel("v0.17.0", False, ()),
                                 rel("v0.16.0-rc3-prism.3", True),
                                 rel("v0.16.0-rc2", True)]
    assert mu.pick_effective_release("o", "r")["tag_name"] == "v0.16.0-rc3-prism.3"
    print("空 release 跳过、自动取最新带资产的（kvllama 情形）OK")

    # 4) 不看 prerelease/rc：最新带资产的即便标了 pre 也直接选中
    mu.fetch_json = lambda url: [rel("v2.0.0-rc1", True), rel("v1.9.0", False)]
    assert mu.pick_effective_release("o", "r")["tag_name"] == "v2.0.0-rc1"
    print("只看资产（pre/rc 不拦截）OK")

    # 5) 最新有非 Windows 资产但无 Windows 资产 → 跳过它，取下一个带 Windows 资产的
    mu.fetch_json = lambda url: [rel("v3.0.0", False, NONWIN), rel("v2.0.0", False, WIN)]
    assert mu.pick_effective_release("o", "r")["tag_name"] == "v2.0.0"
    print("无 Windows 资产跳过 OK")

    # 6) 全都没有 Windows 资产 → None
    mu.fetch_json = lambda url: [rel("v3.0.0", False, NONWIN), rel("v2.0.0", False, ())]
    assert mu.pick_effective_release("o", "r") is None
    print("全无 Windows 资产 → None OK")

    # 7) draft / untagged 跳过
    mu.fetch_json = lambda url: [rel("v9", False, WIN, draft=True),
                                 rel("untagged-abc", False, WIN), rel("v8.0.0")]
    assert mu.pick_effective_release("o", "r")["tag_name"] == "v8.0.0"
    print("draft/untagged 跳过 OK")

    # 8) 平台过滤：外平台 tag 跳过
    mu.fetch_json = lambda url: [rel("macos-v3.0"), rel("v2.0.0")]
    assert mu.pick_effective_release("o", "r", want_platform="windows")["tag_name"] == "v2.0.0"
    print("平台过滤 OK")

    # 9) 传入 rels 时不重复抓取
    def boom(url):
        raise AssertionError("不应再调用 fetch_json")
    mu.fetch_json = boom
    assert mu.pick_effective_release("o", "r", rels=[rel("v1.0.0")])["tag_name"] == "v1.0.0"
    print("rels 复用 OK")
finally:
    mu.fetch_json = orig

print("ALL PASS")
