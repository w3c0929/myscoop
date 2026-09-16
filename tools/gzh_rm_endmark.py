#!/usr/bin/env python3
"""删除三篇文章底部的 end-mark（/ 结束符）：<p style="text-align:center;color:#D1D5DB…">…/…</p>"""
import io
import re

FILES = [
    "gzh/magpie/magpie_排版_摸鱼票据风(moyu-ticket).html",
    "gzh/finch/finch_排版_摸鱼票据风(moyu-ticket).html",
    "gzh/cc-haha/cc-haha_排版_摸鱼票据风(moyu-ticket).html",
]

PAT = re.compile(
    r'<p style="text-align:center;color:#D1D5DB;font-size:14px;margin:24px 0 0 0;">\n'
    r'\s*<span leaf="">/</span>\n\s*</p>\n+', re.M)


def main():
    for p in FILES:
        c = io.open(p, encoding="utf-8").read()
        c, n = PAT.subn("", c)
        io.open(p, "w", encoding="utf-8", newline="").write(c)
        print(f"[OK] {p}: 删除 end-mark {n} 处")


if __name__ == "__main__":
    main()