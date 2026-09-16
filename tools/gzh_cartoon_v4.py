#!/usr/bin/env python3
"""卡通封面 v4（抗锯齿）：2x 超采样绘制（1800x766）后 LANCZOS 缩回 900x383。
重写 gen_cartoon（增 scale 参数，全部坐标/字号缩放）并改造 generate 的 cartoon 分支。
"""
import io

p = "gzh/cover_900.py"
c = io.open(p, encoding="utf-8").read()

# ---- 1) 替换 gen_cartoon ----
start = c.index("def gen_cartoon(")
end = c.index("def generate(", start)
new_fn = '''def gen_cartoon(img, d, line1, line2, subtitle, tag, footer, chips, scale=1):
    """卡通海报风 v4（孟菲斯拼贴，2x 超采样抗锯齿）。scale=2 时全部坐标/字号乘 2。"""
    S = scale
    w, h = img.size
    d.rectangle((0, 0, w, h), fill=(255, 248, 238, 255))
    d.ellipse((-120 * S, 300 * S, 460 * S, 460 * S), fill=(173, 216, 255, 55))
    d.ellipse((560 * S, 300 * S, 1040 * S, 452 * S), fill=(150, 206, 180, 55))

    # 右侧孟菲斯拼贴（全部乘 S）
    cx, cy, r = 732 * S, 200 * S, 60 * S
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 255, 255, 255),
              outline=(255, 138, 150, 255), width=16 * S)
    d.ellipse((cx - 20 * S, cy - 20 * S, cx + 20 * S, cy + 20 * S), fill=(255, 217, 102, 255))
    d.pieslice((672 * S, 262 * S, 792 * S, 368 * S), 0, 180, fill=(125, 179, 248, 255),
               outline=(58, 46, 57, 255), width=4 * S)
    d.polygon([(548 * S, 92 * S), (594 * S, 92 * S), (548 * S, 132 * S)],
              fill=(255, 176, 59, 255), outline=(58, 46, 57, 255))
    d.polygon([(826 * S, 318 * S), (794 * S, 366 * S), (830 * S, 372 * S)],
              fill=(150, 206, 180, 255), outline=(58, 46, 57, 255))
    d.polygon([(872 * S, 96 * S), (902 * S, 100 * S), (898 * S, 128 * S), (868 * S, 124 * S)],
              fill=(255, 243, 176, 255), outline=(58, 46, 57, 255))
    d.ellipse((508 * S, 150 * S, 528 * S, 170 * S), fill=(167, 139, 250, 255))
    d.ellipse((880 * S, 212 * S, 898 * S, 230 * S), fill=(255, 176, 59, 255))
    d.ellipse((608 * S, 336 * S, 626 * S, 354 * S), fill=(125, 179, 248, 255))

    # 左侧文字区（坐标/字号乘 S）
    x0 = 46 * S
    tag_font = fit_single(tag, 20 * S, 15 * S, 260 * S, bold=True)
    box_h = 40 * S
    box_w = tw_(tag, tag_font) + 34 * S
    rrect(d, (x0, 44 * S, x0 + box_w, 44 * S + box_h), 20 * S, fill=(255, 255, 255, 255),
          outline=(255, 184, 77, 255), lw=3 * S)
    d.text((x0 + 17 * S, 44 * S + (box_h - line_h(tag_font)) // 2), tag,
           fill=ca((58, 46, 57), 255), font=tag_font)
    title = line1 if not line2 else line1 + "\\n" + line2
    font, lines = fit_wrapped(title, 50 * S, 34 * S, 430 * S, 2, bold=True)
    ty = 106 * S
    draw_lines(d, x0, ty, lines, font, ca((58, 46, 57), 255), gap=10 * S)
    end_y = ty + block_h(lines, font, 10 * S)
    d.line((x0, end_y + 8 * S, x0 + min(360 * S, 240 * S + len(lines[0]) * 12 * S), end_y + 8 * S),
           fill=(255, 138, 150, 255), width=7 * S)
    if subtitle:
        sf, sl = fit_wrapped(subtitle, 19 * S, 14 * S, 400 * S, 1, bold=False)
        draw_lines(d, x0, end_y + 26 * S, sl, sf, ca((110, 96, 110), 255), gap=0)
    ccy = 296 * S
    ccx = x0
    for chip in chips[:3]:
        cf = fit_single(chip, 16 * S, 13 * S, 130 * S, bold=True)
        cw = tw_(chip, cf) + 26 * S
        chh = 32 * S
        rrect(d, (ccx, ccy, ccx + cw, ccy + chh), 16 * S, fill=(255, 255, 255, 255),
              outline=(255, 138, 150, 255), lw=3 * S)
        d.text((ccx + 13 * S, ccy + (chh - line_h(cf)) // 2), chip,
               fill=ca((58, 46, 57), 255), font=cf)
        ccx += cw + 12 * S
    fy = h - 42 * S
    d.line((x0, fy, x0 + 330 * S, fy), fill=(120, 110, 120, 150), width=2 * S)
    d.ellipse((x0, fy - 6 * S, x0 + 12 * S, fy + 6 * S), fill=(255, 138, 150, 255))
    ff = fit_single(footer, 17 * S, 13 * S, 300 * S, bold=False)
    d.text((x0 + 22 * S, fy + 8 * S), footer, fill=ca((120, 110, 120), 255), font=ff)
    d.ellipse((w - 62 * S, fy + 14 * S, w - 48 * S, fy + 28 * S), fill=(255, 217, 102, 255))


'''
c = c[:start] + new_fn + c[end:]

# ---- 2) 改造 generate 的 cartoon 分支（2x 超采样 + LANCZOS 回缩） ----
old_branch = '''    if style == "cartoon":
        gen_cartoon(img, d, line1, line2, subtitle, tag, footer, chips)
        output = os.path.abspath(output)
        os.makedirs(os.path.dirname(output) or os.getcwd(), exist_ok=True)
        img.convert("RGB").save(output, quality=95)
        print(f"Cover saved: {output} ({W}x{H}) style=cartoon")
        return output
'''
new_branch = '''    if style == "cartoon":
        # 2x 超采样抗锯齿：在 1800x766 绘制后 LANCZOS 缩回 900x383
        S = 2
        hi = Image.new("RGBA", (W * S, H * S), (255, 248, 238, 255))
        hd = ImageDraw.Draw(hi, "RGBA")
        gen_cartoon(hi, hd, line1, line2, subtitle, tag, footer, chips, scale=S)
        img = hi.resize((W, H), Image.LANCZOS).convert("RGB")
        output = os.path.abspath(output)
        os.makedirs(os.path.dirname(output) or os.getcwd(), exist_ok=True)
        img.save(output, quality=95)
        print(f"Cover saved: {output} ({W}x{H}) style=cartoon (supersampled x{S})")
        return output
'''
assert old_branch in c
c = c.replace(old_branch, new_branch, 1)
io.open(p, "w", encoding="utf-8", newline="").write(c)
print("[OK] cartoon v4（2x 超采样抗锯齿）已就位")