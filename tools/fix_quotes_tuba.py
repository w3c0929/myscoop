#!/usr/bin/env python3
"""修 tubatools 三处半角引号（HTML + md 同步）"""
import io

REPL = [
    ('点 "tubatools" 就能打开', '点「tubatools」就能打开'),
    ("所谓'破解版'、'绿色版'、'精简版'均非官方发布",
     '所谓「破解版」、「绿色版」、「精简版」均非官方发布'),
    ('不想装一桌面零碎小工具"的人', '不想装一桌面零碎小工具」的人'),
]

FILES = [
    r"gzh/tubatools/tubatools_排版_摸鱼票据风(moyu-ticket).html",
    r"gzh/tubatools/tubatools.md",
]

for p in FILES:
    c = io.open(p, encoding="utf-8").read()
    n = 0
    for a, b in REPL:
        if a in c:
            c = c.replace(a, b)
            n += 1
    io.open(p, "w", encoding="utf-8", newline="").write(c)
    print(f"[OK] {p}: 替换 {n} 处")