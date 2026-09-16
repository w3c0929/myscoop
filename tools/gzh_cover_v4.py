#!/usr/bin/env python3
"""封面 v4 改造：去票据化——移除编号行与标签位，主标题顶格醒目（28px/900），
副标题+简介圆角卡保留，作者移到底部标签行右侧。枢纽：好看优先。"""
import io
import re

FILES = [
    "gzh/magpie/magpie_排版_摸鱼票据风(moyu-ticket).html",
    "gzh/finch/finch_排版_摸鱼票据风(moyu-ticket).html",
    "gzh/cc-haha/cc-haha_排版_摸鱼票据风(moyu-ticket).html",
]

START = re.escape('<section style="background:#fffef8;border:2px solid #1a1a1a;box-shadow:4px 4px 0 #1a1a1a;margin-bottom:32px;">')
END = re.compile(r'</section>\n</section>')


def g(p, pat):
    m = re.search(pat, p, re.S)
    return re.sub(r"<[^>]+>", "", m.group(1)).strip() if m else ""


def rebuild(seg):
    def g(p, pat):
        m = re.search(pat, p, re.S)
        return re.sub(r"<[^>]+>", "", m.group(1)).strip() if m else ""

    title = g(seg, r'font-size:24px;font-weight:900[^>]*><span leaf="">([^<]+)</span>') or "TITLE"
    sub = g(seg, r'font-size:13px;color:#666;letter-spacing:1px;margin-bottom:12px;"><span leaf="">([^<]+)</span>')
    intro = g(seg, r'background:#F0FDF4;border:1px solid #A7F3D0;border-radius:8px;margin-bottom:12px;">(.*?)</section>')
    who = g(seg, r'font-size:12px;color:#888;"><span leaf="">([^<]+)</span>') or "谷爱雨 · 软件收藏控"
    tags = re.findall(r'<span leaf="">(#\S+)</span>', seg)
    tags = [t for t in tags if t][:6] or ["#软件"]
    tag_html = "".join(
        f'<section style="font-size:11px;color:#059669;border:1px solid #059669;padding:3px 10px;border-radius:999px;"><span leaf="">{t}</span></section>'
        for t in tags)
    intro_html = (f'<section style="font-size:12px;color:#555;line-height:1.7;padding:9px 12px;'
                  f'background:#F0FDF4;border:1px solid #A7F3D0;border-radius:8px;margin-bottom:14px;">'
                  f'<span leaf="">{intro}</span></section>') if intro else ""
    sub_html = (f'<section style="font-size:13px;color:#666;letter-spacing:1px;margin-bottom:14px;">'
                f'<span leaf="">{sub}</span></section>') if sub else ""
    return (
        '<section style="background:#fffef8;border:2px solid #1a1a1a;'
        'box-shadow:4px 4px 0 #1a1a1a;margin-bottom:32px;">\n'
        '  <section style="padding:26px 24px 20px;">\n'
        f'    <section style="font-size:28px;font-weight:900;color:#1a1a1a;line-height:1.3;margin-bottom:8px;"><span leaf="">{title}</span></section>\n'
        f'{sub_html}'
        f'{intro_html}'
        '    <section style="display:flex;align-items:center;gap:8px;justify-content:space-between;">\n'
        f'      <section style="display:flex;align-items:center;gap:8px;">{tag_html}</section>\n'
        f'      <section style="font-size:12px;color:#888;"><span leaf="">{who}</span></section>\n'
        '    </section>\n'
        '  </section>\n'
        "</section>"
    ).replace("&", "&amp;")


for path in FILES:
    html = io.open(path, encoding="utf-8").read()
    m = re.search(START + r".*?" + END.pattern, html, re.S)
    if not m:
        print(f"[跳过] {path}")
        continue
    new_seg = rebuild(m.group(0))
    html = html[: m.start()] + new_seg + html[m.end():]
    io.open(path, "w", encoding="utf-8", newline="").write(html)
    print(f"[OK] {path}: 封面 v4 完成（{len(m.group(0))} → {len(new_seg)} 字符）")