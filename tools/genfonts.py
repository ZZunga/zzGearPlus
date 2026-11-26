"""zzGearPlus 비트맵 폰트 생성 (숫자 폰트).
   WideTitle(영문 글자 포함)은 FntGen.java 로 만든다 — 글자가 들어간 폰트는 그쪽이 안전하다:
     java FntGen.java ttf/TitilliumWeb-Bold.ttf ../resources/fonts widetitle " +.0123456789GPaelrsuz" - 17
     (1040=20, 550/850=32, 1050/1060=36)
   TitilliumWeb-Bold 에서 기기별 크기의 BMFont 를 만들고, '@' 글리프를 기어 아이콘(SVG)으로 바꾼다.
   python3 genfonts.py <out dir>
"""
import io, os, re, sys
import cairosvg
from PIL import Image
sys.path.insert(0, "/home/claude/fontgen")
from gen import gen

OUT = sys.argv[1] if len(sys.argv) > 1 else "/home/claude/zzGearPlus"
SVG = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "gear.svg"), "rb").read()

# 폴더, (메인, 보조, 소수, 넓은값, 타이틀, 라벨)
FAM = [
    (["resources"],                              34, 20, 12, 35, 13, 10, 24),
    (["resources-edge1040"],                     42, 24, 15, 42, 15, 12, 29),
    (["resources-edge550", "resources-edge850"], 65, 36, 22, 63, 23, 18, 46),
    (["resources-edge1050", "resources-edge1060"], 74, 41, 25, 72, 26, 21, 52),
]

CH_MAIN  = " -.0123456789"
CH_HEAD  = " -0123456789"      # 앞기어 (메인의 70% 크기)
CH_SUB   = " -.0123456789"
CH_DEC   = " -.0123456789"
CH_WVAL  = " -.0123456789"
CH_TITLE = " +-.0123456789GPaelrsuz"
CH_LABEL = " -./0123456789T"


def gear_mask(px):
    png = cairosvg.svg2png(bytestring=SVG, output_width=px * 4, output_height=px * 4)
    im = Image.open(io.BytesIO(png)).convert("RGBA").split()[3]
    return im.resize((px, px), Image.LANCZOS)


def put_icon(fnt_path, px):
    """'@' 글리프를 px x px 기어 아이콘으로 바꾼다.
       '@' 가 문자셋 맨 앞이라 시트 왼쪽에 자리가 있다 — 그 자리를 넓혀서 그린다"""
    t = open(fnt_path).read()
    lh = int(re.search(r"lineHeight=(\d+)", t).group(1))
    png = os.path.join(os.path.dirname(fnt_path), re.search(r'file="([^"]+)"', t).group(1))
    m = re.search(r"char id=64 x=(\d+) y=(\d+) width=(\d+) height=(\d+) xoffset=(-?\d+) yoffset=(-?\d+) xadvance=(\d+) page=0 chnl=15", t)
    X, Y, W, H = map(int, m.groups()[:4])
    sheet = Image.open(png).convert("L")
    SW, SH = sheet.size
    g = gear_mask(px)
    # 아이콘 폭이 기존 '@' 폭보다 넓으면 그만큼 시트를 넓히고 오른쪽 글리프들을 민다
    shift = max(0, px - W)
    nw, nh = SW + shift, max(SH, px)
    na = Image.new("L", (nw, nh), 0)
    left = sheet.crop((0, 0, X, SH))
    right = sheet.crop((X + W, 0, SW, SH))
    na.paste(left, (0, 0))
    na.paste(right, (X + W + shift, 0))
    na.paste(g, (X, 0))
    if shift:
        def bump(mo):
            x = int(mo.group(1))
            return "x=%d" % (x + shift) if x > X else mo.group(0)
        lines = t.split("\n")
        for i, ln in enumerate(lines):
            if ln.startswith("char id=") and "id=64 " not in ln:
                lines[i] = re.sub(r"x=(\d+)", bump, ln, count=1)
        t = "\n".join(lines)
    adv = px + max(2, round(px * 0.12))
    line = "char id=64 x=%d y=%d width=%d height=%d xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15" % (X, 0, px, px, adv)
    t = re.sub(r"char id=64 [^\n]*", line, t)
    t = re.sub(r"scaleW=\d+", "scaleW=%d" % nw, t)
    t = re.sub(r"scaleH=\d+", "scaleH=%d" % nh, t)
    if px > lh:
        t = re.sub(r"lineHeight=\d+", "lineHeight=%d" % px, t)
    open(fnt_path, "w").write(t)
    na.save(png, optimize=True)


FONTS_XML = """<fonts>
    <!-- TitilliumWeb Bold. tools/genfonts.py 로 생성 (C10Sub / WideTitle 의 '@' 는 기어 아이콘) -->
    <font id="C10Main" filename="c10main_%d.fnt" antialias="true"/>
    <font id="C10Sub" filename="c10sub_%d.fnt" antialias="true"/>
    <font id="C10Dec" filename="c10dec_%d.fnt" antialias="true"/>
    <font id="C10Head" filename="c10head_%d.fnt" antialias="true"/>
    <font id="WideVal" filename="wideval_%d.fnt" antialias="true"/>
    <font id="WideTitle" filename="widetitle_%d.fnt" antialias="true"/>
    <font id="WideLabel" filename="widelabel_%d.fnt" antialias="true"/>
</fonts>
"""

for dirs, mc, sc, dcap, wv, wt, wl, hc in FAM:
    first = None
    for d in dirs:
        od = os.path.join(OUT, d, "fonts")
        os.makedirs(od, exist_ok=True)
        if first is None:
            gen(od, "c10main_%d" % mc, CH_MAIN, mc)
            gen(od, "c10sub_%d" % sc, CH_SUB, sc)
            gen(od, "c10dec_%d" % dcap, CH_DEC, dcap)
            gen(od, "c10head_%d" % hc, CH_HEAD, hc)
            gen(od, "wideval_%d" % wv, CH_WVAL, wv)
            gen(od, "widelabel_%d" % wl, CH_LABEL, wl)
            first = od
        else:
            for f in os.listdir(first):
                open(os.path.join(od, f), "wb").write(open(os.path.join(first, f), "rb").read())
        open(os.path.join(od, "fonts.xml"), "w").write(FONTS_XML % (mc, sc, dcap, hc, wv, wt, wl))
        print(d, "fonts ok")
