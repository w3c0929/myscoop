#!/usr/bin/env python3
"""单测：_update_by_regex —— 文本正则 checkver 的"静态 latest 直链"与"$version 模板"

覆盖：静态直链内容变化→提升版本；内容未变→不提升（防幽灵更新）；$version 模板→URL 替换；
版本相同→无操作。fetch_text/download_to/sha256_hex 全部 monkeypatch 为离线夹具。
"""
import importlib.util
import json
import tempfile
from pathlib import Path

spec = importlib.util.spec_from_file_location("mu", "myscoop-update.py")
mu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mu)

STATIC = "https://download.deepseek.com/desktop/dsh-latest-windows-x64.exe"
TPL = "https://download.deepseek.com/desktop/dsh-$version-windows-x64.exe"

_orig = (mu.fetch_text, mu.download_to, mu.sha256_hex)
try:
    def case(cur_ver, cur_hash, page_ver, file_hash, tpl):
        m = {
            "version": cur_ver,
            "url": STATIC,
            "hash": "sha256:" + cur_hash,
            "checkver": {"url": "https://api.example/releases",
                         "regex": r'"tag_name":\s*"dsh-v([^"]+)"'},
            "autoupdate": {"url": tpl},
        }
        p = Path(tempfile.mkdtemp()) / "dsh.json"
        p.write_text(json.dumps(m, ensure_ascii=False, indent=4), encoding="utf-8")
        mu.fetch_text = lambda url, timeout=60, headers=None: '{"tag_name": "dsh-v%s"}' % page_ver
        mu.download_to = lambda url, dest, timeout=180: Path(dest).write_bytes(b"x")
        mu.sha256_hex = lambda path: file_hash
        man = json.loads(p.read_text(encoding="utf-8"))
        res = mu._update_by_regex(man, man["checkver"], p, False)
        return json.loads(p.read_text(encoding="utf-8")), res

    # 1) 静态直链 + 版本变化 + 内容变化 → 提升版本、刷新 hash
    after, res = case("0.1.0", "OLD", "0.2.0", "NEW", STATIC)
    assert res and after["version"] == "0.2.0" and after["hash"] == "sha256:NEW", (res, after)
    assert after["url"] == STATIC
    print("静态直链 内容变化 → 提升 OK")

    # 2) 静态直链 + 版本变化 + 内容未变 → 不提升（防幽灵更新）
    after, res = case("0.1.0", "SAME", "0.2.0", "SAME", STATIC)
    assert res is None and after["version"] == "0.1.0" and after["hash"] == "sha256:SAME", (res, after)
    print("静态直链 内容未变 → 不提升 OK")

    # 3) $version 模板 → URL 替换（无"内容未变"抑制）
    after, res = case("0.1.0", "OLD", "0.2.0", "NEW", TPL)
    assert res and after["version"] == "0.2.0", (res, after)
    assert after["url"] == TPL.replace("$version", "0.2.0"), after["url"]
    print("$version 模板替换 OK")

    # 4) 版本相同 → 直接返回 None、不改动
    after, res = case("0.2.0", "OLD", "0.2.0", "OLD", STATIC)
    assert res is None and after["version"] == "0.2.0", (res, after)
    print("版本相同 → 无操作 OK")
finally:
    mu.fetch_text, mu.download_to, mu.sha256_hex = _orig

print("ALL PASS")
