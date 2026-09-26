#!/usr/bin/env python3
"""同步 README 软件表：版本列（第三方表 = 清单 version 原样）+ 时间列（两表 = git 提交日期）。
- 版本列：仅第三方官方表（本地维护表版本人工维护，不触碰）；= bucket 清单 version 原样
- 时间列：两表每行"创建/更新" = bucket/{app}.json 的首次提交日期 / 最近提交日期（git log
  --date=short）；文件无 git 历史（未提交/浅克隆）时降级为当天日期
- 幂等：无差异零 diff（CI '无变更跳过提交' 天然兼容）；--check 只报告不写
用法: python tools/sync_readme_versions.py [--check]
"""
import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
README = ROOT / "README.md"
BUCKET = ROOT / "bucket"


def git_date(app, first):
    """清单首次提交（创建）或最近提交（更新）日期 YYYY-MM-DD；无历史返回 None"""
    args = ["git", "log"]
    if first:
        args += ["--diff-filter=A", "-1"]
    else:
        args += ["-1"]
    args += ["--format=%ad", "--date=short", "--", str(BUCKET / f"{app}.json")]
    try:
        out = subprocess.run(args, capture_output=True, text=True, cwd=ROOT,
                             timeout=30).stdout.strip()
        return out or None
    except Exception:
        return None


def main():
    check = "--check" in sys.argv[1:]
    lines = README.read_text(encoding="utf-8").splitlines()
    new_lines = list(lines)
    in_third = False
    changed = 0
    for i, line in enumerate(lines):
        if line.startswith("### 第三方官方"):
            in_third = True
            continue
        if line.startswith("### 本地维护"):
            in_third = False
            continue
        if not re.match(r"^\|\s*\d+\s*\|", line):
            continue
        m = re.search(r"`scoop install ([a-z0-9._-]+)(?:@[^`\s]+)?`", line)
        if not m:
            continue
        app = m.group(1)
        mp = BUCKET / f"{app}.json"
        if not mp.exists():
            continue
        cells = [c.strip() for c in line.split("|")]
        while len(cells) < 8:
            cells.append("")
        edits = []
        # 版本列（仅第三方表）
        if in_third:
            try:
                ver = str(json.loads(mp.read_text(encoding="utf-8")).get("version") or "")
            except Exception:
                ver = ""
            if ver and cells[5] != ver:
                edits.append((5, ver))
        # 时间列（两表）：创建 cells[6]、更新 cells[7]
        created = git_date(app, first=True) or date.today().isoformat()
        updated = git_date(app, first=False) or date.today().isoformat()
        if cells[6] != created:
            edits.append((6, created))
        if cells[7] != updated:
            edits.append((7, updated))
        if edits:
            tag = "第三方" if in_third else "本地"
            print(f"[{'待同步' if check else '同步'}] {tag} {app}: "
                  + ", ".join(f"{'版本' if idx == 5 else '创建' if idx == 6 else '更新'}→{v}" for idx, v in edits))
            changed += 1
            if not check:
                for idx, v in edits:
                    cells[idx] = v
                new_lines[i] = "| " + " | ".join(cells[1:8]) + " |"
    if changed and not check:
        README.write_text("\n".join(new_lines) + "\n", encoding="utf-8")
    print(f"共 {changed} 行{'待' if check else ''}更新")
    return changed


if __name__ == "__main__":
    main()