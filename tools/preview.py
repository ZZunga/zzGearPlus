"""zzGearPlus 화면 미리보기 렌더러 (스토어 이미지용).
   source/Layout.mc · zzGearPlusView.mc 와 같은 크기표·같은 배치 규칙을 파이썬으로 옮긴 것.
   store/make_assets.py 에서 쓴다.
"""
import io, os, math
import cairosvg
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
TTF = os.path.join(HERE, "ttf", "TitilliumWeb-Bold.ttf")
SVG = open(os.path.join(HERE, "gear.svg"), "rb").read()

# ---- 색 (앱과 같음) ----------------------------------------------------------
OR = (255, 85, 0)
RED_D = (170, 0, 0)
RED_L = (255, 0, 0)
BLUE_D = (0, 0, 170)
BLUE_L = (0, 85, 255)
INK = (49, 49, 82)
WHITE = (255, 255, 255)
NIGHT = (23, 24, 29)

# ---- 크기표 (Layout.mc) -------------------------------------------------------
FAM_W = [246, 282, 420, 480]
C10_MCAP = [34, 42, 65, 74]
C10_SCAP = [20, 24, 36, 41]
C10_DCAP = [12, 15, 22, 25]
C10_HCAP = [24, 29, 46, 52]
WIDE_TCAP = [13, 15, 23, 26]
WIDE_LCAP = [10, 12, 18, 21]
ICON_K = 1.08

CAS = [11, 12, 13, 14, 15, 17, 19, 21, 24, 27, 30, 34]
LANG = ["ko"]      # 크로스체인 문구 언어


def fam_of(sw):
    if sw >= 470: return 3
    if sw >= 400: return 2
    if sw >= 270: return 1
    return 0


_fc = {}
def cap_font(cap):
    cap = max(6, int(cap))
    if cap not in _fc:
        p = 6
        while True:
            f = ImageFont.truetype(TTF, p)
            if -f.getbbox("0", anchor="ls")[1] >= cap:
                break
            p += 1
        _fc[cap] = f
    return _fc[cap]


def wd(d, s, f):
    return d.textlength(s, font=f)


def tx(d, x, y, s, f, c, a="ls"):
    d.text((x, y), s, font=f, fill=c, anchor=a)


_ic = {}
def gear_icon(img, x, y, px, color):
    """아이콘 글리프 (왼쪽 위 기준)"""
    px = max(6, int(px))
    if px not in _ic:
        png = cairosvg.svg2png(bytestring=SVG, output_width=px * 4, output_height=px * 4)
        _ic[px] = Image.open(io.BytesIO(png)).convert("RGBA").split()[3].resize((px, px), Image.LANCZOS)
    layer = Image.new("RGB", (px, px), color)
    img.paste(layer, (int(x), int(y)), _ic[px])


def pct(v, p, lo):
    r = int(v * p + 0.5)
    return lo if r < lo else r


# ---- 그림 요소 ---------------------------------------------------------------
def cassette(d, cx, cy, R, cur, n, use, cross, dark):
    """간격·굵기 균일한 동심원. 사용 시간이 많은 링은 진하게"""
    shown = n if (R * 2 >= 64 or n <= 6) else 6
    hole = R * 0.34
    sp = (R - hole) / (shown - 1)
    w0 = max(1, int(sp * 0.40))
    wc = max(2, int(sp))
    base = (58, 58, 64) if dark else (198, 198, 204)
    used = (138, 138, 146) if dark else (128, 128, 134)
    curShown = int(round(cur * (shown - 1) / float(n - 1))) if n > 1 else 0
    for i in range(shown):
        if i == curShown:
            continue
        col = base
        if use:
            j = int(round(i * (n - 1) / float(shown - 1)))
            t = min(1.0, use[j] / max(use)) if max(use) > 0 else 0
            col = tuple(int(base[k] + (used[k] - base[k]) * t) for k in range(3))
        r = hole + sp * i
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=col, width=w0)
    r = hole + sp * curShown
    acc = (RED_L if dark else RED_D) if cross else OR
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=acc, width=wc)


def front(d, cx, cy, R, cur, n, dark):
    base = (58, 58, 64) if dark else (198, 198, 204)
    blue = BLUE_L if dark else BLUE_D
    w0 = max(1, int(R * 0.07))
    wc = max(2, int(R * 0.11))
    rad = [R * 0.68, R] if n == 2 else [R]
    for i, r in enumerate(rad):
        col, w = (blue, wc) if i == cur else (base, w0)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=col, width=w)


def battery(d, right, cy, w, h, status, dark):
    """ANT+ 5단계 (1 새것 ~ 5 위험)"""
    if status <= 2:
        col, fill = ((0, 255, 0) if dark else (0, 128, 0)), 100
    elif status == 3:
        col, fill = ((0, 255, 0) if dark else (0, 128, 0)), 65
    elif status == 4:
        col, fill = (255, 170, 0), 35
    else:
        col, fill = ((255, 0, 0) if dark else (170, 0, 0)), 12
    tip = max(1, h // 5)
    x = right - w - tip
    y = cy - h / 2
    pen = max(1, h // 8)
    d.rectangle([x, y, x + w, y + h], outline=col, width=pen)
    d.rectangle([x + w, y + h * 0.3, x + w + tip, y + h * 0.7], fill=col)
    ins = pen * 2
    fw = (w - 2 * ins) * fill / 100.0
    if fw > 0:
        d.rectangle([x + ins, y + ins, x + ins + fw, y + h - ins], fill=col)


# ---- 칸 ----------------------------------------------------------------------
def render(w, h, sw, gear=(2, 8), gmax=(2, 12), teeth=(50, 19), use=None,
           batt=3, dark=False, cross=False, show_batt=True):
    """앱과 같은 판정: 칸 폭이 화면 폭의 75% 를 넘으면 넓은 칸"""
    k = fam_of(sw)
    bg = (NIGHT if sw >= 480 else (0, 0, 0)) if dark else WHITE
    fg = WHITE if dark else (INK if sw >= 480 else (0, 0, 0))
    dim = (200, 200, 200) if dark else (85, 85, 85)
    img = Image.new("RGB", (w, h), bg)
    d = ImageDraw.Draw(img)
    acc = (RED_L if dark else RED_D) if cross else OR
    col = (RED_L if dark else RED_D) if cross else (BLUE_L if dark else BLUE_D)
    f_i, r_i = gear
    f_n, r_n = gmax
    ratio = "%.1f" % (teeth[0] / float(teeth[1]))
    wide = w > sw * 0.75
    if not wide:
        _narrow(img, d, w, h, k, fg, dim, acc, col, f_i, r_i, f_n, r_n, ratio,
                use, batt if show_batt else None, dark, cross)
    elif h >= w * 0.45:
        _tall(img, d, w, h, k, fg, dim, acc, col, f_i, r_i, f_n, r_n, ratio, teeth,
              use, batt if show_batt else None, dark, cross)
    else:
        _wide(img, d, w, h, k, fg, dim, acc, col, f_i, r_i, f_n, r_n, ratio,
              use, batt if show_batt else None, dark, cross)
    return img


def _top_icon_ratio(img, d, L, T, R, sc, ug, acc, col, ratio, batt, dark, icon_px):
    gear_icon(img, L, T + (sc - icon_px) / 2, icon_px, acc)
    xr = R
    if batt is not None:
        bw = int(sc * 0.62 * 0.95 + 0.5)
        bh = max(5, int(sc * 0.62 * 0.52 + 0.5))
        battery(d, R, T + sc / 2, bw, bh, batt, dark)
        xr = R - bw - max(1, bh // 5) - ug * 2
    f = cap_font(sc)
    tx(d, xr, T + sc, ratio, f, col, "rs")


def _narrow(img, d, w, h, k, fg, dim, acc, col, f_i, r_i, f_n, r_n, ratio, use, batt, dark, cross):
    m = pct(w, 0.03, 2); mv = pct(h, 0.05, 2); ug = pct(w, 0.02, 2)
    L, T, R, B = m, mv, w - m, h - mv
    sc = C10_SCAP[k]
    topBase = T + sc
    areaTop = topBase
    # 1) 동심원 (크기 고정, 오른쪽 10%)
    rr = (B - areaTop) / 2
    cx = L + rr + w * 0.10
    if cx + rr > R:
        cx = R - rr
    cassette(d, cx, (areaTop + B) / 2, rr, r_i - 1, r_n, use, cross, dark)
    # 2) 기어 숫자 (앞기어 70%)
    avail = R - (cx + rr) - ug * 2
    ft, ct = cap_font(C10_MCAP[k]), C10_MCAP[k]
    fh, ch = cap_font(C10_HCAP[k]), C10_HCAP[k]
    if wd(d, str(r_n), ft) + wd(d, "%d-" % f_n, fh) > avail:
        ft, ct = cap_font(C10_SCAP[k]), C10_SCAP[k]
        fh, ch = cap_font(C10_DCAP[k]), C10_DCAP[k]
    tail = str(r_i)
    tx(d, R, B, tail, ft, fg, "rs")
    tx(d, R - wd(d, tail, ft), B, "%d-" % f_i, fh, fg, "rs")
    # 3) 윗줄
    _top_icon_ratio(img, d, L, T, R, sc, ug, acc, col, ratio, batt, dark, int(sc * ICON_K + 0.5))


def _title_row(img, d, w, h, k, L, T, R, fg, acc, batt, dark, ug, name):
    tcap = WIDE_TCAP[k]
    isz = int(C10_SCAP[k] * ICON_K + 0.5)
    tline = max(int(tcap * 1.25 + 0.5), isz)
    titleY = T + (tline - tcap) / 2
    gear_icon(img, L, T + (tline - isz) / 2, isz, acc)
    x = L + isz + ug
    ft = cap_font(tcap)
    tx(d, x, titleY + tcap, name, ft, fg, "ls")
    xr = R
    if batt is not None:
        bw = int(tcap * 0.95 + 0.5); bh = max(5, int(tcap * 0.52 + 0.5))
        battery(d, R, T + tline / 2, bw, bh, batt, dark)
        xr = R - bw - max(1, bh // 5) - ug * 2
    return tline, titleY, x + wd(d, name, ft), xr


def _wide(img, d, w, h, k, fg, dim, acc, col, f_i, r_i, f_n, r_n, ratio, use, batt, dark, cross):
    m = pct(w, 0.04, 3); mv = pct(h, 0.05, 2); ug = pct(w, 0.02, 2)
    L, T, R, B = m, mv, w - m, h - mv
    name = "zzGear+" if w < 300 else "zzGearPlus"
    tline, titleY, leftEnd, xr = _title_row(img, d, w, h, k, L, T, R, fg, acc, batt, dark, ug, name)
    sc = C10_SCAP[k]
    # 오른쪽 위 기어비
    tx(d, xr, T + (tline - sc) / 2 + sc, ratio, cap_font(sc), col, "rs")
    # 왼쪽 아래 기어 숫자
    fm = cap_font(sc)
    s = "%d-%d" % (f_i, r_i)
    tx(d, L, B, s, fm, fg, "ls")
    leftEnd = max(leftEnd, L + wd(d, "%d-%d" % (f_n, r_n), fm))
    _train(d, L=leftEnd + ug * 2, R=R, T=T + tline, B=B, k=k, r_i=r_i, r_n=r_n, f_i=f_i, f_n=f_n,
           use=use, dark=dark, cross=cross, scale=1.0)


def _tall(img, d, w, h, k, fg, dim, acc, col, f_i, r_i, f_n, r_n, ratio, teeth, use, batt, dark, cross):
    m = pct(w, 0.04, 3); mv = pct(h, 0.05, 2); ug = pct(w, 0.02, 2)
    L, T, R, B = m, mv, w - m, h - mv
    name = "zzGear+" if w < 300 else "zzGearPlus"
    tline, titleY, leftEnd, xr = _title_row(img, d, w, h, k, L, T, R, fg, acc, batt, dark, ug, name)
    sc = C10_SCAP[k]
    top = T + tline + pct(h, 0.04, 2)
    bot = B - sc - pct(h, 0.02, 2)
    if cross:
        msg = "크로스체인 · 앞을 바꾸세요" if LANG[0] == "ko" else "Cross-chain - shift the front"
        fw = (ImageFont.truetype(_KR[0], int(WIDE_LCAP[k] * 1.5), index=_KR[1]) if LANG[0] == "ko"
              else cap_font(int(WIDE_LCAP[k] * 1.1)))
        tx(d, w / 2, top + WIDE_LCAP[k] * 1.4, msg, fw, acc, "ms")
        top += int(WIDE_LCAP[k] * 2.0)
    _train(d, L=L, R=R, T=top, B=bot, k=k, r_i=r_i, r_n=r_n, f_i=f_i, f_n=f_n,
           use=use, dark=dark, cross=cross, scale=0.95)
    fm = cap_font(sc)
    s = "%d-%d" % (f_i, r_i)
    tx(d, L, B, s, fm, fg, "ls")
    x2 = L + wd(d, "%d-%d" % (f_n, r_n), fm) + ug * 2
    tx(d, x2, B, ratio, fm, col, "ls")
    lf = cap_font(WIDE_LCAP[k])
    tx(d, R, B, "%d / %d T" % teeth, lf, dim, "rs")


def _train(d, L, R, T, B, k, r_i, r_n, f_i, f_n, use, dark, cross, scale):
    availH = B - T
    areaW = R - L
    if availH <= 16 or areaW <= 16:
        return
    cy = (T + B) / 2
    if f_n <= 1:
        rc = min(availH / 2, areaW / 2) * scale
        cassette(d, (L + R) / 2, cy, rc, r_i - 1, r_n, use, cross, dark)
        return
    rf = min(availH / 2, areaW * 0.25) * scale
    rc2 = rf * 10 / 12.0
    gap = rf * 0.22
    gw = 2 * rf + gap + 2 * rc2
    fx = (L + R) / 2 - gw / 2 + rf
    front(d, fx, cy, rf, f_i - 1, f_n, dark)
    cassette(d, fx + rf + gap + rc2, cy, rc2, r_i - 1, r_n, use, cross, dark)


# 한글 글꼴 (크로스체인 문구)
def _find_kr():
    for p in ["/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
              "/usr/share/fonts/truetype/noto/NotoSansCJK-Bold.ttc",
              "C:/Windows/Fonts/malgunbd.ttf"]:
        if os.path.exists(p):
            if p.endswith(".ttc"):
                for i in range(10):
                    try:
                        f = ImageFont.truetype(p, 20, index=i)
                        if "KR" in " ".join(f.getname()):
                            return p, i
                    except OSError:
                        break
            else:
                return p, 0
    raise SystemExit("한글 글꼴 없음")

_KR = _find_kr()
