"""
make_assets.py - Connect IQ 스토어용 이미지 생성 (zzGearPlus)

    python store/make_assets.py            -> store/images/*.png

  cover.png              앱 아이콘(대표 이미지) 500x500, 둘레 10px 여백, 투명 배경
  hero_ko.png / _en.png  히어로 1440x720 (한국어·영어)
  screen{1..5}.png       화면 이미지 500x500 (영어) (업로드 한도 150KB 이하로 저장)

화면 안의 데이터 필드는 tools/preview.py 렌더러로 그린다
(= 앱과 같은 크기표·같은 배치 계산). Pillow·cairosvg 필요. zzPowerPlus/store/make_assets.py 와 같은 틀.
"""
import io, math, os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "tools"))
import preview as pv  # noqa: E402

OUT = os.path.join(HERE, "images")
os.makedirs(OUT, exist_ok=True)

# ---- 글꼴 -------------------------------------------------------------------
def _find_font(cands, want="KR"):
    for path in cands:
        if not os.path.exists(path):
            continue
        if path.endswith(".ttc"):
            for i in range(10):
                try:
                    f = ImageFont.truetype(path, 20, index=i)
                    if want in " ".join(f.getname()):
                        return path, i
                except OSError:
                    break
        else:
            return path, 0
    raise SystemExit("한글 글꼴을 찾을 수 없음: " + ", ".join(cands))

KR_BOLD = _find_font(["/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc",
                      "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
                      "C:/Windows/Fonts/malgunbd.ttf"])
KR_REG = _find_font(["/usr/share/fonts/opentype/noto/NotoSansCJK-Medium.ttc",
                     "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
                     "C:/Windows/Fonts/malgun.ttf"])
TITILLIUM = os.path.join(ROOT, "tools", "ttf", "TitilliumWeb-Bold.ttf")

def kb(size): return ImageFont.truetype(KR_BOLD[0], size, index=KR_BOLD[1])
def kr(size): return ImageFont.truetype(KR_REG[0], size, index=KR_REG[1])
def ti(size): return ImageFont.truetype(TITILLIUM, size)

RED = (255, 85, 0)
BLUE_LINE = (0, 120, 215)

def device(screen, side=16, top=22, bottom=30, radius=26):
    """화면 둘레에 무광 검정 사이클 컴퓨터 본체를 그린다 (로고 없음)."""
    sw, sh = screen.size
    W, H = sw + side * 2, sh + top + bottom
    ss = 3
    body = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle([0, 0, W * ss - 1, H * ss - 1], radius=radius * ss, fill=(28, 30, 34, 255))
    d.rounded_rectangle([3 * ss, 3 * ss, W * ss - 3 * ss, H * ss - 3 * ss], radius=(radius - 3) * ss,
                        outline=(58, 62, 70, 255), width=2 * ss)
    d.rounded_rectangle([(side - 4) * ss, (top - 4) * ss, (side + sw + 4) * ss, (top + sh + 4) * ss],
                        radius=6 * ss, fill=(8, 9, 11, 255))
    body = body.resize((W, H), Image.LANCZOS)
    body.paste(screen, (side, top))
    # 유리 반사 한 줄
    gl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gl)
    gd.polygon([(side, top), (side + sw * 0.55, top), (side + sw * 0.25, top + sh), (side, top + sh)],
               fill=(255, 255, 255, 14))
    body.alpha_composite(gl)
    return body


def shadowed(img, blur=18, offset=(0, 14), alpha=110):
    pad = blur * 3
    W, H = img.size
    out = Image.new("RGBA", (W + pad * 2, H + pad * 2), (0, 0, 0, 0))
    sh = Image.new("RGBA", out.size, (0, 0, 0, 0))
    mask = img.split()[3].point(lambda a: a * alpha // 255)
    sh.paste(Image.new("RGBA", img.size, (0, 0, 0, 255)), (pad + offset[0], pad + offset[1]), mask)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    out.alpha_composite(sh)
    out.alpha_composite(img, (pad, pad))
    return out, pad


def gradient(W, H, top, bottom):
    g = Image.new("RGB", (1, H))
    for y in range(H):
        t = y / max(1, H - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return g.resize((W, H)).convert("RGBA")


def save_png(img, name, limit_kb):
    path = os.path.join(OUT, name)
    rgb = img
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    if limit_kb and buf.tell() > limit_kb * 1024:
        has_alpha = img.mode == "RGBA"
        for colors in (256, 192, 128):
            q = img.convert("RGBA").quantize(colors=colors, method=Image.FASTOCTREE, dither=Image.FLOYDSTEINBERG)
            buf = io.BytesIO()
            q.save(buf, "PNG", optimize=True)
            if buf.tell() <= limit_kb * 1024:
                break
    with open(path, "wb") as f:
        f.write(buf.getvalue())
    print("  %-18s %4dx%-4d %6.1f KB" % (name, img.size[0], img.size[1], buf.tell() / 1024))




# ---- 화면 합성 ------------------------------------------------------------------
USE = [0.02, 0.04, 0.07, 0.11, 0.16, 0.19, 0.14, 0.10, 0.07, 0.05, 0.03, 0.02]
CAS = [11, 12, 13, 14, 15, 17, 19, 21, 24, 27, 30, 34]
FR = [34, 50]


def cell_args(front, rear, batt=3, cross=False):
    return dict(gear=(front, rear), gmax=(2, 12), teeth=(FR[front - 1], CAS[rear - 1]),
                use=USE, batt=batt, cross=cross)


def page(rows, sw, sh, dark):
    """rows: [ (h, [ (w, front, rear, batt, cross), ... ]), ... ]"""
    bg = (23, 24, 29) if (dark and sw >= 480) else ((0, 0, 0) if dark else (255, 255, 255))
    img = Image.new("RGB", (sw, sh), bg)
    dr = ImageDraw.Draw(img)
    lw = 2 if sw >= 480 else 1
    y = 0
    for ri, (h, cells) in enumerate(rows):
        x = 0
        for ci, c in enumerate(cells):
            w, fr, re, ba, cx = c
            tile = pv.render(w, h, sw, dark=dark, show_batt=(ba is not None),
                             **cell_args(fr, re, ba if ba else 3, cx))
            img.paste(tile, (x, y))
            x += w
            if ci < len(cells) - 1:
                dr.line([x, y, x, y + h - 1], fill=BLUE_LINE, width=lw)
                x += lw
        y += h
        if ri < len(rows) - 1:
            dr.line([0, y, sw, y], fill=BLUE_LINE, width=lw)
            y += lw
    return img


VALS10 = [(2, 8, 3, False), (1, 3, 3, False), (2, 11, 3, False), (2, 5, 3, False),
          (1, 1, 3, True), (2, 7, 3, False), (1, 5, 3, False), (2, 12, 3, True),
          (2, 4, 3, False), (1, 9, 3, False)]


def ten(sw, sh, vals=VALS10):
    lw = 2 if sw >= 480 else 1
    hs = [(sh - 4 * lw) // 5] * 5
    hs[-1] += (sh - 4 * lw) - sum(hs)
    w1 = (sw - lw) // 2
    w2 = sw - lw - w1
    rows = []
    for i, h in enumerate(hs):
        a, b = vals[2 * i], vals[2 * i + 1]
        rows.append((h, [(w1,) + a, (w2,) + b]))
    return rows


def page_ten_840(dark=False):       # 246x322 : 10분할
    return page(ten(246, 322), 246, 322, dark)


def page_ten_850(dark=True):        # 420x600 : 10분할 (검정 배경)
    return page(ten(420, 600), 420, 600, dark)


def page_cells_1040(dark=False):    # 282x470 : 10분할
    return page(ten(282, 470), 282, 470, dark)


def page_big_1050(dark=True):       # 480x800 : 구동계 큰 칸 + 넓은 칸 + 10필드 칸
    return page([
        (399, [(480, 2, 8, 3, False)]),
        (199, [(480, 1, 4, 3, False)]),
        (198, [(239, 2, 12, 4, True), (239, 1, 2, 3, False)]),
    ], 480, 800, dark)


def page_cross_540(dark=False):     # 246x322 : 크로스체인 경고 + 좁은 칸
    return page([
        (160, [(246, 2, 12, 3, True)]),
        (80, [(122, 2, 7, 3, False), (123, 1, 3, 3, False)]),
        (80, [(246, 2, 5, 3, False)]),
    ], 246, 322, dark)


# ---- 1) 대표 이미지 500x500 --------------------------------------------------------
def make_cover():
    S = 4
    W = 500 * S
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    p = 10 * S
    d.rounded_rectangle([p, p, W - p - 1, W - p - 1], radius=34 * S, fill=(26, 30, 39, 255))
    sx0, sy0, sx1, sy1 = 58 * S, 50 * S, 442 * S, 318 * S
    d.rounded_rectangle([sx0, sy0, sx1, sy1], radius=22 * S, fill=(244, 244, 244, 255))
    ink = (20, 20, 20, 255)
    # 동심원 (왼쪽) + 기어 숫자 (오른쪽) — 앱의 10분할 칸 배치
    cy = (sy0 + sy1) / 2 + 10 * S
    R = 104 * S
    cx = sx0 + 24 * S + R
    hole = R * 0.34
    sp = (R - hole) / 11
    for i in range(12):
        r = hole + sp * i
        if i == 7:
            continue
        t = USE[i] / max(USE)
        g = int(198 + (128 - 198) * t)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(g, g, g + 6, 255), width=max(2, int(sp * 0.40)))
    r = hole + sp * 7
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 85, 0, 255), width=int(sp))
    # 기어비 (오른쪽 위) + 기어 숫자
    d.text((sx1 - 24 * S, sy0 + 62 * S), "2.6", font=ti(54 * S), fill=(0, 0, 170, 255), anchor="rs")
    big = ti(132 * S)
    small = ti(92 * S)
    bx = sx1 - 24 * S
    d.text((bx, sy1 - 28 * S), "8", font=big, fill=ink, anchor="rs")
    bw = d.textlength("8", font=big)
    d.text((bx - bw, sy1 - 28 * S), "2-", font=small, fill=ink, anchor="rs")

    d.text((W / 2, 384 * S), "zzGearPlus", font=ti(64 * S), fill=(255, 255, 255, 255), anchor="mm")
    cap = "GEAR  /  RATIO  /  CROSS-CHAIN"
    cf = ti(19 * S)
    spacing = 1.6 * S
    total = sum(d.textlength(ch, font=cf) + spacing for ch in cap) - spacing
    cxp = W / 2 - total / 2
    for ch in cap:
        d.text((cxp, 446 * S), ch, font=cf, fill=(255, 140, 70, 255), anchor="lm")
        cxp += d.textlength(ch, font=cf) + spacing
    img = img.resize((500, 500), Image.LANCZOS)
    save_png(img, "cover.png", 300)


# ---- 2) 히어로 1440x720 ------------------------------------------------------------
HERO_TXT = {
    "ko": dict(kicker="Garmin Edge 데이터 필드",
               title="zz기어", tag="기어 · 기어비 · 동심원 구동계 · 크로스체인",
               bullets=[((255, 85, 0), "지금 기어가 동심원 위에서 바로 보인다"),
                        ((0, 170, 255), "앞·뒤 단수와 기어비, 변속기 배터리까지"),
                        ((255, 170, 0), "크로스체인이면 링이 빨갛게 바뀐다")],
               devices="Edge 540 · 550 · 840 · 850 · 1040 · 1050 · 1060"),
    "en": dict(kicker="Garmin Edge Data Field",
               title="zzGear", tag="Gear · Ratio · Concentric Drivetrain · Cross-chain",
               bullets=[((255, 85, 0), "See your gear on the rings, not just a number"),
                        ((0, 170, 255), "Front and rear gear, ratio and shifting battery"),
                        ((255, 170, 0), "Rings turn red when you cross-chain")],
               devices="Edge 540 · 550 · 840 · 850 · 1040 · 1050 · 1060"),
}


def rings_bg(img, color):
    """배경 장식: 옅은 동심원"""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = 300, 640
    for i in range(9):
        r = 90 + i * 46
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color + (30,), width=3)
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(1)))


def make_hero(lang):
    pv.LANG[0] = lang
    t = HERO_TXT[lang]
    W, H = 1440, 720
    img = gradient(W, H, (34, 20, 12), (12, 9, 8))
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([820, -120, 1620, 700], fill=(230, 90, 20, 60))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(120)))
    rings_bg(img, (255, 140, 60))

    big = device(page_big_1050(dark=True), side=22, top=30, bottom=40, radius=34)
    big = big.resize((int(big.width * 0.70), int(big.height * 0.70)), Image.LANCZOS)
    small = device(page_ten_840(dark=False), side=16, top=22, bottom=30, radius=26)
    small = small.resize((int(small.width * 1.12), int(small.height * 1.12)), Image.LANCZOS)
    b, bp = shadowed(big, blur=22, offset=(0, 18), alpha=150)
    s_, sp = shadowed(small, blur=18, offset=(0, 14), alpha=170)
    img.alpha_composite(b, (1040 - bp, 52 - bp))
    img.alpha_composite(s_, (800 - sp, 222 - sp))

    d = ImageDraw.Draw(img)
    x = 96
    d.text((x, 150), t["kicker"], font=kr(30), fill=(240, 185, 150))
    if lang == "ko":
        f = kb(104)
        d.text((x - 4, 186), t["title"], font=f, fill=(255, 255, 255))
    else:
        f = ti(118)
        d.text((x - 4, 168), t["title"], font=f, fill=(255, 255, 255))
    tw_ = d.textlength(t["title"], font=f)
    d.text((x + tw_ + 2, 168 if lang == "ko" else 160), "+", font=ti(128), fill=RED)
    tag_f = kb(34) if lang == "ko" else ti(38)
    while d.textlength(t["tag"], font=tag_f) > 680:
        tag_f = kb(tag_f.size - 1) if lang == "ko" else ti(tag_f.size - 1)
    d.text((x, 336), t["tag"], font=tag_f, fill=(250, 232, 220))
    y = 418
    for color, line in t["bullets"]:
        d.ellipse([x, y + 12, x + 14, y + 26], fill=color)
        d.text((x + 30, y), line, font=kr(27) if lang == "ko" else ti(30), fill=(248, 236, 228))
        y += 52
    d.text((x, 610), t["devices"], font=kr(22) if lang == "ko" else ti(24), fill=(195, 150, 120))
    save_png(img.convert("RGB"), "hero_%s.png" % lang, 0)


# ---- 3) 화면 이미지 500x500 ----------------------------------------------------------
SCREENS = [
    ("screen1", page_ten_840, False,
     ("동심원으로 보는 지금 기어", "10분할 한 칸에서도 기어와 기어비를 한눈에"),
     ("Your gear, drawn as rings", "Gear and ratio even in one slot of a 10-field layout")),
    ("screen2", page_big_1050, True,
     ("넓은 칸에서는 앞 체인링까지", "앞은 파랑, 뒤는 주황 — 실제처럼 앞이 더 크다"),
     ("Wide fields add the front chainring", "Blue front, orange rear - the front is larger, as on the bike")),
    ("screen3", page_cross_540, False,
     ("크로스체인이면 빨갛게", "현재 링과 아이콘, 기어비가 함께 바뀐다"),
     ("Cross-chain turns it red", "The current ring, the icon and the ratio all change")),
    ("screen4", page_cells_1040, False,
     ("오래 쓴 기어일수록 진하게", "기어별로 보낸 시간이 회색 링에 쌓인다"),
     ("The more you use a gear, the darker it gets", "Time in each gear builds up on the grey rings")),
    ("screen5", page_ten_850, True,
     ("배터리와 기어비는 오른쪽 위에", "ANT+ 변속기 배터리 상태를 색으로"),
     ("Battery and ratio in the top right", "ANT+ shifting battery status, by color")),
]


def make_screen(name, page_fn, dark, cap, lang):
    pv.LANG[0] = lang
    W = 500
    img = gradient(W, W, (242, 245, 250), (222, 229, 240)) if not dark else gradient(W, W, (36, 24, 16), (12, 10, 9))
    d = ImageDraw.Draw(img)
    title_c = (20, 30, 48) if not dark else (255, 255, 255)
    sub_c = (80, 92, 112) if not dark else (215, 185, 165)

    def fit(make, size, text, maxw=468):
        while size > 12 and d.textlength(text, font=make(size)) > maxw:
            size -= 1
        return make(size)
    tf = fit(kb, 25, cap[0]) if lang == "ko" else fit(ti, 28, cap[0])
    sf = fit(kr, 16, cap[1]) if lang == "ko" else fit(ti, 19, cap[1])
    d.text((W / 2, 30), cap[0], font=tf, fill=title_c, anchor="mm")
    d.text((W / 2, 62), cap[1], font=sf, fill=sub_c, anchor="mm")

    scr = page_fn(dark)
    if scr.height > 340:
        dev = device(scr, side=22, top=30, bottom=40, radius=34)
        k = 400 / dev.height
        dev = dev.resize((int(dev.width * k), int(dev.height * k)), Image.LANCZOS)
    else:
        dev = device(scr)
    sh, sp = shadowed(dev, blur=12, offset=(0, 8), alpha=120)
    img.alpha_composite(sh, ((W - dev.width) // 2 - sp, 88 - sp))
    save_png(img.convert("RGB"), "%s.png" % name, 150)


def main():
    print("store/images:")
    make_cover()
    make_hero("ko")
    make_hero("en")
    for name, fn, dark, cko, cen in SCREENS:
        make_screen(name, fn, dark, cen, "en")


if __name__ == "__main__":
    main()
