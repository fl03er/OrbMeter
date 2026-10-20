# Builds README GIFs from the rendered orb frames.
import sys, os, json
from PIL import Image, ImageDraw, ImageFont
frames_dir, out_dir = sys.argv[1], sys.argv[2]
counts = json.load(open(os.path.join(frames_dir, 'frames.json')))
load = lambda st, i: Image.open(os.path.join(frames_dir, st, f'frame-{i}.png')).convert('RGBA')
SF = '/System/Library/Fonts/SFNS.ttf'
KO = '/System/Library/Fonts/AppleSDGothicNeo.ttc'
FPS, SECONDS = 8, 6.5
T = int(FPS * SECONDS)
os.makedirs(os.path.join(out_dir, 'ko'), exist_ok=True)

def save(frames, path):
    pal = [f.convert('RGB').quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for f in frames]
    pal[0].save(path, save_all=True, append_images=pal[1:], duration=int(1000 / FPS), loop=0, optimize=True, disposal=1)

# 1) Menu bar demo: dark and light bars at real Retina pixels (2x), Working orb at natural pace.
def menubar(mode, orb, label):
    W, H = 760, 60
    bg = (30, 31, 36) if mode == 'dark' else (238, 239, 243)
    fg = (240, 240, 242) if mode == 'dark' else (24, 24, 28)
    im = Image.new('RGBA', (W, H), bg + (255,))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(SF, 26)
    x = W - 24
    for text in [label, '18°C']:
        w = d.textlength(text, font=f); x -= w
        d.text((x, H / 2), text, font=f, fill=fg, anchor='lm'); x -= 36
    im.alpha_composite(orb, (int(x - orb.width), (H - orb.height) // 2))
    return im
demo = []
for t in range(T):
    orb = load('working', t % counts['working'])
    top = menubar('dark', orb, 'Tue 6:30 PM'); bottom = menubar('light', orb, 'Tue 6:30 PM')
    canvas = Image.new('RGBA', (760, 120)); canvas.alpha_composite(top, (0, 0)); canvas.alpha_composite(bottom, (0, 60))
    demo.append(canvas)
save(demo, os.path.join(out_dir, 'menubar.gif'))

# 2) The nine states, 3x3, orbs at 2x their menu bar pixels.
NAMES = {
    'en': {s: s.capitalize() for s in counts},
    'ko': dict(working='작업 중', searching='검색 중', solving='푸는 중', listening='듣는 중', connecting='연결 중',
               weaving='엮는 중', composing='작성 중', breathing='숨쉬기', shaping='모양 바꾸기'),
}
for lang, names in NAMES.items():
    font = ImageFont.truetype(SF if lang == 'en' else KO, 22)
    CELL, ORB, PAD = 200, 88, 12
    out = []
    for t in range(T):
        im = Image.new('RGBA', (CELL * 3, CELL * 3), (22, 23, 27, 255))
        d = ImageDraw.Draw(im)
        for k, st in enumerate(counts):
            cx, cy = (k % 3) * CELL, (k // 3) * CELL
            d.rounded_rectangle((cx + PAD, cy + PAD, cx + CELL - PAD, cy + CELL - PAD), 18, fill=(34, 36, 42))
            orb = load(st, t % counts[st]).resize((ORB, ORB), Image.LANCZOS)
            im.alpha_composite(orb, (cx + (CELL - ORB) // 2, cy + 38))
            d.text((cx + CELL / 2, cy + CELL - 34), names[st], font=font, fill=(222, 224, 230), anchor='mm')
        out.append(im)
    save(out, os.path.join(out_dir, 'states.gif' if lang == 'en' else 'ko/states.gif'))
print('ok')
