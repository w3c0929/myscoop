#!/usr/bin/env python3
"""单测：--more 主程序+运行时（cudart）配对（同架构同 CUDA 版本；多版本取最高；无配对回退）"""
import importlib.util

spec = importlib.util.spec_from_file_location("mu", "myscoop-update.py")
mu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mu)


def A(name):
    return {"name": name}


# llama.cpp（PrismML fork）实测资产：64bit 有 12.4/13.3 两套，arm64 有 13.4 一套，
# 32bit 无 cuda 配对（xcframework），另含 cpu/vulkan/hip/cpu-arm64 等非 cuda 包
LLAMA_ASSETS = [A(n) for n in [
    "cudart-llama-bin-win-cuda-12.4-x64.zip",
    "cudart-llama-bin-win-cuda-13.3-x64.zip",
    "llama-prism-b10709-9a9394a-bin-win-cuda-12.4-x64.zip",
    "llama-prism-b10709-9a9394a-bin-win-cuda-13.3-x64.zip",
    "llama-prism-b10709-9a9394a-bin-win-hip-radeon-x64.zip",
    "llama-prism-b10709-9a9394a-bin-win-cpu-x64.zip",
    "llama-prism-b10709-9a9394a-bin-win-vulkan-x64.zip",
    "cudart-llama-bin-win-cuda-13.4-arm64.zip",
    "llama-prism-b10709-9a9394a-bin-win-cuda-13.4-arm64.zip",
    "llama-prism-b10709-9a9394a-xcframework.zip",
    "llama-prism-b10709-9a9394a-bin-win-cpu-arm64.zip",
]]
WIN = [(a, 0) for a in LLAMA_ASSETS]

# 1) llama.cpp 实测：64bit 配对 13.3（13.3 > 12.4 优先），arm64 配对 13.4
pairs = mu.build_runtime_pairs(WIN)
assert set(pairs) == {"64bit", "arm64"}, set(pairs)
assert "13.3" in pairs["64bit"]["main"]["name"], pairs["64bit"]
assert "13.3" in pairs["64bit"]["runtime"]["name"], pairs["64bit"]
assert pairs["64bit"]["cuda_str"] == "13.3"
assert "13.4" in pairs["arm64"]["main"]["name"]
assert "13.4" in pairs["arm64"]["runtime"]["name"]
print("llama.cpp 实测资产配对 OK")

# 2) 无 cudart 运行时 → 空配对
assert mu.build_runtime_pairs([(A("app-1.0-win-x64.zip"), 0)]) == {}
print("无运行时包返回空 OK")

# 3) 只有 runtime 或只有 main → 不落单配对
assert mu.build_runtime_pairs([(A("cudart-app-bin-win-cuda-13.3-x64.zip"), 0)]) == {}
assert mu.build_runtime_pairs([(A("app-bin-win-cuda-13.3-x64.zip"), 0)]) == {}
print("单边缺失不配对 OK")

# 4) CUDA 版本不交集 → 空配对
assert mu.build_runtime_pairs([
    (A("app-bin-win-cuda-13.3-x64.zip"), 0),
    (A("cudart-app-bin-win-cuda-12.4-x64.zip"), 0),
]) == {}
print("版本不匹配不配对 OK")

# 5) 同架构多 CUDA 版本 → 取最高
multi = [
    (A("app-bin-win-cuda-12.4-x64.zip"), 0),
    (A("app-bin-win-cuda-12.8-x64.zip"), 0),
    (A("app-bin-win-cuda-13.3-x64.zip"), 0),
    (A("cudart-app-bin-win-cuda-12.8-x64.zip"), 0),
    (A("cudart-app-bin-win-cuda-13.3-x64.zip"), 0),
]
p5 = mu.build_runtime_pairs(multi)
assert set(p5) == {"64bit"}, set(p5)
assert "13.3" in p5["64bit"]["main"]["name"], p5["64bit"]
assert "13.3" in p5["64bit"]["runtime"]["name"], p5["64bit"]
print("多 CUDA 版本取最高 OK")

# 6) parse_cuda_asset 单元检查
assert mu.parse_cuda_asset("cudart-llama-bin-win-cuda-13.3-x64.zip") == ("64bit", (13, 3), "runtime")
assert mu.parse_cuda_asset("llama-prism-b10709-9a9394a-bin-win-cuda-13.4-arm64.zip") == ("arm64", (13, 4), "main")
assert mu.parse_cuda_asset("llama-prism-b10709-9a9394a-xcframework.zip") is None  # 无架构标记
assert mu.parse_cuda_asset("llama-prism-b10709-9a9394a-bin-win-cpu-x64.zip") is None  # 无 cuda 版本
assert mu.parse_cuda_asset("llama-prism-b10709-9a9394a-bin-win-hip-radeon-x64.zip") is None
assert mu.parse_cuda_asset("llama-prism-b10709-9a9394a-bin-win-vulkan-x64.zip") is None
print("parse_cuda_asset 单元 OK")

# 7) 回归：不带 --more 的常规路径行为不变——64bit 组 pick_asset 仍选 cudart-13.3
g = {}
for arch_key in ("64bit", "32bit", "arm64", "generic"):
    g[arch_key] = [a for a, _ in WIN if (mu.detect_arch(a["name"]) or "generic") == arch_key]
best = mu.pick_asset(g["64bit"])
assert best["name"] == "cudart-llama-bin-win-cuda-13.3-x64.zip", best
print("常规路径回归 OK")

print("ALL PASS")