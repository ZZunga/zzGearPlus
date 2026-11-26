"""기어 아이콘을 '폰트'로 만든다 (글리프 하나짜리).
   비트맵(drawBitmap)은 기기에서 알파가 1비트로 깎여 가장자리가 계단처럼 보인다.
   폰트는 antialias="true" 로 8비트 커버리지를 그대로 쓰므로 가장자리가 부드럽고,
   글자색으로 그려지니 크로스체인 빨강 전환도 그대로 된다.
   python3 genicons.py <out dir>
"""
import io, os, sys
import cairosvg
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else "/home/claude/zzGearPlus"
SVG = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "gear.svg"), "rb").read()

# 폴더, 좁은 칸 아이콘 크기, 넓은 칸 타이틀 아이콘 크기 (각각 옆 글자 높이 x 1.08)
FAM = [
    (["resources"], 22, 14),
    (["resources-edge1040"], 26, 16),
    (["resources-edge550", "resources-edge850"], 39, 25),
    (["resources-edge1050", "resources-edge1060"], 44, 28),
]


def gear_mask(px):
    png = cairosvg.svg2png(bytestring=SVG, output_width=px * 4, output_height=px * 4)
    return Image.open(io.BytesIO(png)).convert("RGBA").split()[3].resize((px, px), Image.LANCZOS)


def write_font(outdir, name, px):
    """글리프 하나('@')짜리 BMFont. 숫자 폰트(tools/genfonts.py)와 같은 형식"""
    pad = 2
    g = gear_mask(px)
    im = Image.new("L", (px + pad * 2, px + pad * 2), 0)
    im.paste(g, (pad, pad))
    png = name + ".png"
    im.save(os.path.join(outdir, png), optimize=True)
    adv = px + max(2, round(px * 0.12))
    lines = [
        'info face="gear" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0' % px,
        'common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 alphaChnl=1 redChnl=0 greenChnl=0 blueChnl=0' % (px, px, im.size[0], im.size[1]),
        'page id=0 file="%s"' % png,
        'chars count=1',
        'char id=64 x=%d y=%d width=%d height=%d xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15' % (pad, pad, px, px, adv),
    ]
    open(os.path.join(outdir, name + ".fnt"), "w").write("\n".join(lines) + "\n")


for dirs, sub, title in FAM:
    for d in dirs:
        od = os.path.join(OUT, d, "fonts")
        os.makedirs(od, exist_ok=True)
        write_font(od, "iconsub_%d" % sub, sub)
        write_font(od, "icontitle_%d" % title, title)
        print(d, "icon fonts", sub, title)
