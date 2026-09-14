#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Rebuild the '提交历史' code block in .claude/skills-myscoop/progress.md
from fresh `git log --oneline --decorate --graph` output.

用法（每次本地提交完成后）：
    python3 tools/rebuild_progress.py
    git add .claude/skills-myscoop/progress.md
    git commit -m "progress.md 更新提交历史"
"""
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PROG = REPO / ".claude" / "skills-myscoop" / "progress.md"

r = subprocess.run(
    ["git", "log", "--oneline", "--decorate", "--graph"],
    cwd=str(REPO), capture_output=True,
)
if r.returncode != 0:
    raise SystemExit(r.stderr.decode("utf-8", "replace"))
log_lines = [ln + "\n" for ln in r.stdout.decode("utf-8", "replace").rstrip().splitlines()]

lines = PROG.read_text(encoding="utf-8").splitlines(keepends=True)

head_idx = next(i for i, ln in enumerate(lines) if ln.strip() == "## 提交历史")
first_fence = next(i for i in range(head_idx + 1, len(lines)) if lines[i].strip() == "```")

tail_idx = len(lines)
for i in range(first_fence + 1, len(lines)):
    if lines[i].strip().startswith("## "):
        tail_idx = i
        break
last_fence = next(i for i in range(tail_idx - 1, first_fence, -1) if lines[i].strip() == "```")

out = lines[: first_fence + 1] + log_lines + lines[last_fence:]
PROG.write_text("".join(out), encoding="utf-8")
print(f"OK: first_fence={first_fence+1} last_fence={last_fence+1} tail_start={tail_idx+1} lines_in={len(log_lines)}")