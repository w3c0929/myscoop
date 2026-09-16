#!/usr/bin/env python3
"""封面标签补足：v4 脚本曾只提取 1 个标签，本脚本把每篇封面标签行替换为 ≥5 个话题标签。"""
import io
import re

JOBS = {
    "gzh/magpie/magpie_排版_摸鱼票据风(moyu-ticket).html":
        ["#游戏画质", "#老游戏", "#免费软件", "#开源", "#DLSS", "#FSR2"],
    "gzh/finch/finch_排版_摸鱼票据风(moyu-ticket).html":
        ["#AI助手", "#免费软件", "#开源", "#模型自由", "#桌面应用"],
    "gzh/cc-haha/cc-haha_排版_摸鱼票据风(moyu-ticket).html":
        ["#AI编程", "#ClaudeCode", "#多智能体", "#开源软件", "#效率工具", "#工作台"],
}

PAT = re.compile(r'<section style="display:flex;align-items:center;gap:8px;">.*?</section>\n      </section>', re.S)


def main():
    for path, tags in JOBS.items():
        c = io.open(path, encoding="utf-8").read()
        tags_html = "".join(
            f'<section style="font-size:11px;color:#059669;border:1px solid #059669;'
            f'padding:3px 10px;border-radius:999px;"><span leaf="">{t}</span></section>'
            for t in tags)
        new = ('<section style="display:flex;align-items:center;gap:8px;">' +
               tags_html + "</section>\n      </section>")
        replaced = PAT.subn(lambda m: new, c, count=1)
        c = replaced[0]
        io.open(path, "w", encoding="utf-8", newline="").write(c)
        print(f"[OK] {path}: 替换 {replaced[1]} 处，标签 {len(tags)} 个")


if __name__ == "__main__":
    main()