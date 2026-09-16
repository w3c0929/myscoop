#!/usr/bin/env python3
"""票据风封面 v2 改造脚本：把摸鱼票据风文章 HTML 的旧版大封面（~340px 高，含绿条/
撕票线/票根/独立作者行）替换为紧凑版（~220px：头部行=标签+NO，大标题+副标题，简介
圆角单行，标签与作者同行，右侧竖排侧栏）。依据 baoyu-design 工艺：层级合并、纵向压缩。
用法: python3 tools/gzh_cover_v2.py <文章1.html> [文章2.html ...]
"""
import re
import sys

START = re.escape('<section style="background:#fffef8;border:2px solid #1a1a1a;box-shadow:4px 4px 0 #1a1a1a;margin-bottom:32px;">')
END = re.compile(r'ADMIT ONE 🎫</span></section>\s*</section>')


def extract(seg: str):
    def g(p):
        m = re.search(p, seg, re.S)
        return re.sub(r"<[^>]+>", "", m.group(1)).strip() if m else ""

    return {
        "tag": g(r'letter-spacing:4px;font-weight:600;"><span leaf="">([^<]+)</span>'),
        "title": g(r'font-size:24px;font-weight:900[^>]*><span leaf="">([^<]+)</span>'),
        "sub": g(r'font-size:14px;color:#666;letter-spacing:1px;margin-bottom:20px;"><span leaf="">([^<]+)</span>'),
        "intro": g(r'background:#F0FDF4;border:1px solid #A7F3D0;">(.*?)</section>'),
        "no": g(r'<span leaf="">NO\.</span>\s*<section[^>]*><span leaf="">([^<]+)</span>'),
        "tags": [g(r'<span leaf="">(#\S+)</span>')],
        "who": g(r'font-size:15px;color:#1a1a1a;font-weight:700;"><span leaf="">([^<]+)</span>'),
        "role": g(r'font-size:12px;color:#888;"><span leaf="">([^<]+)</span>'),
        "vert": g(r'font-size:9px;color:#888;letter-spacing:2px;"><span leaf="">([^<]+)</span>'),
        "grade": g(r'font-size:14px;font-weight:900;color:#059669;"><span leaf="">([^<]+)</span>'),
    }


def build(f):
    tag = f["tag"] or "OPEN SOURCE"
    title = f["title"] or "TITLE"
    sub = f["sub"] or ""
    intro = f["intro"] or ""
    no = f["no"] or "001"
    tags = [t for t in f["tags"] if t] or ["#软件"]
    who = f["who"] or "谷爱雨"
    role = f["role"] or "软件收藏控"
    vert = f["vert"] or "体验测评"
    grade = f["grade"] or "A"
    tags_html = "".join(
        f'<section style="font-size:11px;color:#059669;border:1px solid #059669;'
        f'padding:3px 10px;border-radius:999px;"><span leaf="">{t}</span></section>'
        for t in tags[:3])
    intro_html = (f'<section style="font-size:12px;color:#555;line-height:1.7;padding:9px 12px;'
                  f'background:#F0FDF4;border:1px solid #A7F3D0;border-radius:8px;margin-bottom:12px;">'
                  f'<span leaf="">{intro}</span></section>') if intro else ""
    return (
        '<section style="background:#fffef8;border:2px solid #1a1a1a;'
        'box-shadow:4px 4px 0 #1a1a1a;margin-bottom:32px;">\n'
        '  <section style="display:flex;align-items:stretch;">\n'
        '    <section style="flex:1;padding:24px 22px 20px;">\n'
        '      <section style="display:flex;align-items:center;justify-content:space-between;margin-bottom:14px;">\n'
        f'        <section style="font-size:11px;color:#059669;font-weight:700;letter-spacing:3px;"><span leaf="">{tag}</span></section>\n'
        f'        <section style="font-size:12px;color:#888;"><span leaf="">{who} · {role}</span></section>\n'
        '      </section>\n'
        f'      <section style="font-size:24px;font-weight:900;color:#1a1a1a;line-height:1.3;margin-bottom:6px;"><span leaf="">{title}</span></section>\n'
        f'      <section style="font-size:13px;color:#666;letter-spacing:1px;margin-bottom:12px;"><span leaf="">{sub}</span></section>\n'
        f'{intro_html}'
        '      <section style="display:flex;align-items:center;gap:8px;">\n'
        f'{tags_html}'
        '      </section>\n'
        '    </section>\n'
        '    <section style="width:40px;background:#F0FDF4;border-left:2px dashed #A7F3D0;'
        'display:flex;flex-direction:column;align-items:center;justify-content:space-between;padding:12px 0;">\n'
        f'      <section style="font-size:9px;color:#888;letter-spacing:3px;"><span leaf="">{vert}</span></section>\n'
        f'      <section style="text-align:center;">\n'
        f'        <section style="font-size:7px;color:#999;letter-spacing:1px;"><span leaf="">NO.</span></section>\n'
        f'        <section style="font-size:16px;font-weight:900;color:#059669;"><span leaf="">{no}</span></section>\n'
        '      </section>\n'
        f'      <section style="text-align:center;">\n'
        f'        <section style="font-size:7px;color:#999;letter-spacing:1px;"><span leaf="">GRADE</span></section>\n'
        f'        <section style="font-size:13px;font-weight:900;color:#059669;"><span leaf="">{grade}</span></section>\n'
        '      </section>\n'
        '    </section>\n'
        '  </section>\n'
        "</section>"
    ).replace("&", "&amp;")


def main():
    for path in sys.argv[1:]:
        html = open(path, encoding="utf-8").read()
        m = re.search(START + r".*?" + END.pattern, html, re.S)
        if not m:
            print(f"[跳过] {path}: 未找到旧版封面")
            continue
        f = extract(m.group(0))
        new_seg = build(f)
        html = html[: m.start()] + new_seg + html[m.end():]
        open(path, "w", encoding="utf-8").write(html)
        print(f"[OK] {path}: 封面已替换（{len(m.group(0))} -> {len(new_seg)} 字符）")


if __name__ == "__main__":
    main()