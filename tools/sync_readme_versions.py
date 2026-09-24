#!/usr/bin/env python3
"""同步 README 第三方表版本列 = bucket 清单 version（幂等；--check 只报告不写）。
CI（auto-update.yml）每晚 --all 更新清单后调用，保证 README 版本列与 bucket 一致。
本地维护表（自托管）不动；多版本/特殊格式行按"清单 version 原样"覆盖（第三方表内无多版本行）。
用法: python tools/sync_readme_versions.py [--check]
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
README = ROOT / "README.md"
BUCKET = ROOT / "bucket"


def main():
    check = "--check" in sys.argv[1:]
    lines = README.read_text(encoding="utf-8").splitlines()
    in_third = False
    changed = []  # (行号, 原行, 新版本)
    for i, line in enumerate(lines):
        if line.startswith("### 第三方官方"):
            in_third = True
            continue
        if in_third and line.startswith("## "):
            break
        if not in_third:
            continue
        m = re.match(r"^\|\s*\d+\s*\|.*?`scoop install ([a-z0-9._-]+)`", line)
        if not m:
            continue
        app = m.group(1)
        mp = BUCKET / f"{app}.json"
        if not mp.exists():
            continue
        try:
            ver = json.loads(mp.read_text(encoding="utf-8")).get("version")
        except Exception:
            continue
        if not ver:
            continue
        ver = str(ver)
        cur = re.search(r"\| ([^|]+) \|\s*$", line)
        cur = cur.group(1).strip() if cur else None
        if cur == ver:
            continue
        changed.append((i, line, ver))
        print(f"[{'待同步' if check else '同步'}] {app}: {cur} → {ver}")

    if changed and not check:
        for i, _old, ver in changed:
            lines[i] = re.sub(r"\| ([^|]+) \|\s*$", f"| {ver} |", lines[i])
        README.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"共 {len(changed)} 处版本{'待' if check else ''}更新")
    return len(changed)


if __name__ == "__main__":
    main()