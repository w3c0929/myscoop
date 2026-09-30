#!/usr/bin/env python3
"""单测：配对资产（--more，数组型 url/hash）的自动更新

覆盖：
- _update_pair_block：逐项 $version 替换 → match_asset → 回写同下标 url/hash
- cudart 项（名不含 $version）强制精确匹配，禁 _norm_base 跨 CUDA 版本误配
- heal_url_drift 数组块：不再崩溃；漂移逐项回写；无漂移 False
- heal_url_drift 标量回归：行为与旧版一致
- 顶层（单架构）数组块
"""
import importlib.util

spec = importlib.util.spec_from_file_location("mu", "myscoop-update.py")
mu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mu)

VER = "prism-b99999-aaaaaaa"
BASE = "https://github.com/PrismML-Eng/llama.cpp/releases/download/" + VER


def A(name, d):
    return {"name": name, "browser_download_url": BASE + "/" + name, "digest": "sha256:" + d}


ASSETS = [
    A(f"llama-{VER}-bin-win-cuda-13.3-x64.zip", "D1"),
    A("cudart-llama-bin-win-cuda-13.3-x64.zip", "D2"),
    A(f"llama-{VER}-bin-win-cuda-13.4-arm64.zip", "D3"),
    A("cudart-llama-bin-win-cuda-13.4-arm64.zip", "D4"),
    A(f"llama-{VER}-xcframework.zip", "D5"),
]

TMPL_64 = [BASE + "/llama-$version-bin-win-cuda-13.3-x64.zip",
           BASE + "/cudart-llama-bin-win-cuda-13.3-x64.zip"]
TMPL_ARM = [BASE + "/llama-$version-bin-win-cuda-13.4-arm64.zip",
            BASE + "/cudart-llama-bin-win-cuda-13.4-arm64.zip"]
OLD = "https://github.com/PrismML-Eng/llama.cpp/releases/download/prism-b10743-adfffbe/"

# 1) 64bit 配对：逐项命中，url/hash 下标对齐
blk = {"url": [OLD + "llama-prism-b10743-adfffbe-bin-win-cuda-13.3-x64.zip",
               OLD + "cudart-llama-bin-win-cuda-13.3-x64.zip"],
       "hash": ["sha256:old1", "sha256:old2"]}
n = mu._update_pair_block(blk, TMPL_64, blk["url"], VER, ASSETS)
assert n == 2, n
assert blk["url"][0] == BASE + f"/llama-{VER}-bin-win-cuda-13.3-x64.zip", blk["url"][0]
assert blk["hash"][0] == "sha256:D1"
assert blk["url"][1] == BASE + "/cudart-llama-bin-win-cuda-13.3-x64.zip"
assert blk["hash"][1] == "sha256:D2"
print("64bit 配对逐项更新 OK")

# 2) arm64 配对（CUDA 13.4）
blk2 = {"url": [OLD + "llama-prism-b10743-adfffbe-bin-win-cuda-13.4-arm64.zip",
                OLD + "cudart-llama-bin-win-cuda-13.4-arm64.zip"],
        "hash": ["sha256:o1", "sha256:o2"]}
n2 = mu._update_pair_block(blk2, TMPL_ARM, blk2["url"], VER, ASSETS)
assert n2 == 2 and blk2["hash"] == ["sha256:D3", "sha256:D4"], blk2
print("arm64 配对逐项更新 OK")

# 3) cudart 严格精确：上游缺 13.3、只有 13.5（归一后同 base）→ 不得误配，保留旧值
A_STRICT = [A(f"llama-{VER}-bin-win-cuda-13.3-x64.zip", "D1"),
            A("cudart-llama-bin-win-cuda-13.5-x64.zip", "DX")]
blk3 = {"url": [OLD + "llama-prism-b10743-adfffbe-bin-win-cuda-13.3-x64.zip",
                OLD + "cudart-llama-bin-win-cuda-13.3-x64.zip"],
        "hash": ["sha256:old1", "sha256:old2"]}
n3 = mu._update_pair_block(blk3, TMPL_64, blk3["url"], VER, A_STRICT)
assert n3 == 1, n3
assert blk3["hash"][0] == "sha256:D1" and blk3["hash"][1] == "sha256:old2", blk3
print("cudart 严格精确匹配（不跨 CUDA 版本误配）OK")

# 4) 全部未匹配 → 返回 0 且不改动
blk4 = {"url": [OLD + "llama-prism-b10743-adfffbe-bin-win-cuda-13.3-x64.zip",
                OLD + "cudart-llama-bin-win-cuda-13.3-x64.zip"],
        "hash": ["sha256:old1", "sha256:old2"]}
n4 = mu._update_pair_block(blk4, TMPL_64, blk4["url"], VER, [A("other-1.0-win-x64.zip", "Z")])
assert n4 == 0 and blk4["hash"] == ["sha256:old1", "sha256:old2"], blk4
print("全未匹配不改动 OK")

# 5) 顶层（单架构）数组块：同样走 _update_pair_block
top = {"url": [OLD + "llama-prism-b10743-adfffbe-bin-win-cuda-13.3-x64.zip",
               OLD + "cudart-llama-bin-win-cuda-13.3-x64.zip"],
       "hash": ["sha256:old1", "sha256:old2"]}
n5 = mu._update_pair_block(top, TMPL_64, top["url"], VER, ASSETS)
assert n5 == 2 and top["hash"] == ["sha256:D1", "sha256:D2"], top
print("顶层数组块更新 OK")

# 6) heal_url_drift 数组块：不再崩溃；无漂移（名同）→ False
h0 = {"architecture": {"64bit": {
    "url": [BASE + f"/llama-{VER}-bin-win-cuda-13.3-x64.zip",
            BASE + "/cudart-llama-bin-win-cuda-13.3-x64.zip"],
    "hash": ["sha256:D1", "sha256:D2"]}}}
assert mu.heal_url_drift(h0, ASSETS) is False, "名同名同 → 无漂移"
print("heal 数组块 无漂移 False OK")

# 7) heal_url_drift 数组块：名有漂移（大小写不同，tag 相同）→ 逐项回写 + hash 同步
h1 = {"architecture": {"64bit": {
    "url": [BASE + f"/LLAMA-{VER.upper()}-BIN-WIN-CUDA-13.3-X64.ZIP",
            BASE + "/CUDART-LLAMA-BIN-WIN-CUDA-13.3-X64.ZIP"],
    "hash": ["sha256:old1", "sha256:old2"]}}}
assert mu.heal_url_drift(h1, ASSETS) is True
assert h1["architecture"]["64bit"]["url"][0] == BASE + f"/llama-{VER}-bin-win-cuda-13.3-x64.zip"
assert h1["architecture"]["64bit"]["hash"] == ["sha256:D1", "sha256:D2"]
print("heal 数组块 漂移逐项回写 OK")

# 8) heal_url_drift 标量回归：与旧行为一致（+47 → +48 自愈）
SASSETS = [{"name": "Cinetry_0.8.4+48_windows.zip",
            "browser_download_url": "https://x/Cinetry_0.8.4%2B48_windows.zip",
            "digest": "sha256:aaaa"}]
sm = {"url": "https://x/Cinetry_0.8.4+47_windows.zip", "hash": "sha256:old",
      "extract_dir": "Cinetry_0.8.4+47_windows", "autoupdate": {"url": "tpl"}}
assert mu.heal_url_drift(sm, SASSETS) is True
assert sm["url"] == SASSETS[0]["browser_download_url"] and sm["hash"] == "sha256:aaaa"
assert "autoupdate" not in sm
sm2 = {"url": SASSETS[0]["browser_download_url"], "hash": "sha256:aaaa"}
assert mu.heal_url_drift(sm2, SASSETS) is False
print("heal 标量回归 OK")

print("ALL PASS")
