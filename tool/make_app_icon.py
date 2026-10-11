"""Builds the game's app icon for every platform from the Hero knight's own sprite (decisions-log 135; the owner:
"icon game ambil dari sprite knight heronya saja terus di kasi kan background di belakangnya").

The figure: the knight's idle frame 0 (tiny_knight_idle.png), cropped to the knight, scaled up by a whole number with
nearest neighbour, in a Hero's look (lib/hero.dart, lib/hero_splash.dart): the soft white halo behind its body and
ui_icons.png's gold crown floating above its helmet, at half a knight pixel per crown pixel as on the field. Where not
one whole knight pixel fits (macOS 16 and 32, the others' 16, 24 and 32) the figure is area-averaged into a sharp
silhouette with a dark edge.
The background is drawn here, not taken from a pack: a sunrise radial gradient in the crown's golds behind the knight
with the Hero splash's 10 light rays, a soft ground shadow under its feet, and a dark rim in the crown's outline colour.

Writes (it only reads assets/images):
  macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{16,32,64,128,256,512,1024}.png  (Apple's icon grid)
  windows/runner/resources/app_icon.ico            16, 24, 32, 48, 64, 128 and 256 (PNG entries)
  linux/runner/resources/app_icon.png              256: the window icon (linux/runner/my_application.cc)
  android/app/src/main/res/mipmap-<dpi>/ic_launcher.png, and the adaptive icon's layers
      ic_launcher_{foreground,background,monochrome}.png (mipmap-anydpi-v26/ic_launcher.xml)
  web/favicon.png, web/icons/Icon-{192,512}.png, web/icons/Icon-maskable-{192,512}.png
Stdlib only:  python3 tool/make_app_icon.py [--placeholder] [--out DIR] [--preview DIR]
  --placeholder draws a figure of our own instead of the knight (a crowned shield with a sword, pixel art in
  PLACEHOLDER below) on the same background: the public repo's icon, since the knight and the crown are pack art
  (docs/assets.md "The app icon"). It reads no file at all.
  --out DIR writes the platform files under DIR instead of the repo (DIR/macos/..., DIR/web/...).
  --preview DIR also writes the macOS icon at 1024, 256, 64, 32 and 16 px and a contact sheet of every file to DIR.
"""
import math
import struct
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from build_atlas import read_png, write_png  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
IMAGES = ROOT / "assets/images"

# The figure, in the knight's frame pixels (100x100 frames, feet at (50, 59)): its visible box is x 41..66, y 39..56.
# The crown is ui_icons.png's 16x16 one at (64, 16) (hero.dart `_icCrown`), half a knight pixel per pixel as on the
# field (8 units over a unit), centred over the helmet with its visible bottom half a pixel above the plume.
CROWN_SRC = (64, 16)
CROWN_AT = (44.0, 31.0)  # the crown cell's top left
HALO = (50.0, 48.0, 14.0)  # hero.dart `_heroHalo`: feet - (0, 11), radius 14
SHADOW = (50.0, 57.5, 9.5, 2.8)  # under the feet: centre, radii (the pack's own shadow is 15x5 at (50, 57))

# Colours: the crown's golds and its outline (ui_icons.png), the splash's halo stops (hero_splash.dart).
SKY = [  # the sunrise, by distance from the sun (the halo's centre) over the gradient's radius
    (0.00, (255, 248, 214)),
    (0.18, (255, 231, 120)),
    (0.40, (254, 174, 52)),
    (0.68, (221, 90, 8)),
    (1.00, (122, 38, 20)),
]
RAY = (255, 244, 184)
RIM = (0x3F, 0x28, 0x32)
GLINT = (255, 228, 140)  # the thin light line inside the rim
SHADE = (0x2B, 0x1D, 0x2B)


def load_figure():
    """The figure's pixels as (x, y, size, rgba) squares in knight pixels: the knight's frame 0, then the crown."""
    w, _, px = read_png(IMAGES / "tiny_knight_idle.png")
    cells = []
    for y in range(100):
        for x in range(100):
            i = (y * w + x) * 4
            if px[i + 3]:
                cells.append((float(x), float(y), 1.0, tuple(px[i:i + 4])))
    iw, _, ipx = read_png(IMAGES / "ui_icons.png")
    for y in range(16):
        for x in range(16):
            i = ((CROWN_SRC[1] + y) * iw + CROWN_SRC[0] + x) * 4
            if ipx[i + 3]:
                cells.append((CROWN_AT[0] + x / 2, CROWN_AT[1] + y / 2, 0.5, tuple(ipx[i:i + 4])))
    return cells


# The public repo's figure, drawn here from scratch (no pack): a gold crown over a red heater shield with a sword
# down its middle, one character per knight pixel, its top left at PLACEHOLDER_AT. It stands where the knight does:
# the shield's middle on the halo, its point on the feet's row, so the halo and the ground shadow sit as they do
# behind the knight.
PLACEHOLDER = [
    "......K...KK...K......",
    ".....KGK.KGGK.KGK.....",
    ".....KGGKGGGGKGGK.....",
    ".....KGGGGGGGGGGK.....",
    ".....KgRgGWWGgRgK.....",
    ".....KKKKKKKKKKKK.....",
    "......................",
    "..KKKKKKKKKKKKKKKKKK..",
    "..KGGGGGGGGGGGGGGGGK..",
    "..KGRRRRRRWSrrrrrrGK..",
    "..KGRRRRRRWSrrrrrrGK..",
    "..KGRRRRRRWSrrrrrrGK..",
    "..KGRRRgGGGGGGgrrrGK..",
    "..KGRRRRRRWSrrrrrrGK..",
    "..KGRRRRRRWSrrrrrrGK..",
    "...KGRRRRRWSrrrrrGK...",
    "...KGRRRRRWSrrrrrGK...",
    "....KGRRRRWSrrrrGK....",
    ".....KGRRRWSrrrGK.....",
    "......KGRRWSrrGK......",
    ".......KGGWSGGK.......",
    ".........KGGK.........",
    "..........KK..........",
]
PLACEHOLDER_AT = (39, 34)  # 22 x 23 knight pixels: x 39..61 round the feet's 50, the point's row on 56
PLACEHOLDER_INK = {
    "K": (0x2B, 0x1D, 0x2B), "G": (250, 200, 60), "g": (190, 130, 30), "R": (196, 52, 52), "r": (140, 30, 44),
    "W": (245, 245, 250), "S": (170, 180, 200),
}


def placeholder_figure():
    """[PLACEHOLDER] as figure squares (x, y, size, rgba) in knight pixels."""
    return [(float(PLACEHOLDER_AT[0] + x), float(PLACEHOLDER_AT[1] + y), 1.0, PLACEHOLDER_INK[ch] + (255,))
            for y, row in enumerate(PLACEHOLDER) for x, ch in enumerate(row) if ch != "."]


def set_figure(cells):
    """Makes [cells] the figure every icon draws, with its box, middle and reach."""
    global FIGURE, X0, Y0, X1, Y1, FIG_W, FIG_MID, FIG_REACH
    FIGURE = cells
    X0 = min(c[0] for c in FIGURE)
    Y0 = min(c[1] for c in FIGURE)
    X1 = max(c[0] + c[2] for c in FIGURE)
    Y1 = max(c[1] + c[2] for c in FIGURE)
    FIG_W = X1 - X0  # the knight: 26 knight pixels; the placeholder: 22
    FIG_MID = ((X0 + X1) / 2, (Y0 + Y1) / 2)
    # How far the figure reaches from its box's middle (for the Android and web safe circles).
    FIG_REACH = max(math.hypot(cx - FIG_MID[0], cy - FIG_MID[1])
                    for x, y, s, _ in FIGURE for cx in (x, x + s) for cy in (y, y + s))


class Layout:
    """Where everything goes on an icon of [size] px: the body (the rounded square, or None for a full-bleed layer),
    and the figure at [q] output pixels per knight pixel with its frame's origin at (ox, oy)."""

    def __init__(self, size, kind):
        self.size, self.kind = size, kind
        s = size
        if kind == "mac":  # Apple's grid: an 824 px rounded square (radius 185) centred on 1024
            b = s * 824 / 1024
            self.body = ((s - b) / 2, (s - b) / 2, b, b * 185.4 / 824)
        elif kind == "square":  # Windows, Linux, the Android legacy launcher, web: nearly the whole canvas
            inset = round(s * 0.03)
            b = s - 2 * inset
            self.body = (inset, inset, b, b * 0.19)
        else:  # "full", "fg", "bg", "mono": full bleed, the figure inside a safe circle
            self.body = None
        if self.body:
            b = self.body[2]
            want = 0.62 * b / FIG_W
            if want >= 0.95:
                q = max(1, round(want))
            elif FIG_W <= 0.88 * b - 2:
                q = 1
            else:
                q = 0.80 * b / FIG_W  # the smallest sizes: no whole pixel fits, area-averaged
            self.sky = 0.8 * b
        else:
            # Android's adaptive icon: 108 dp with a 66 dp safe circle; web maskable: an 80% safe circle.
            safe = s * (66 / 108 if kind in ("fg", "bg", "mono") else 0.8) / 2
            q = max(1, math.floor(0.85 * safe / FIG_REACH))
            self.sky = 0.62 * s
        self.q = q
        ox, oy = s / 2 - FIG_MID[0] * q, s / 2 - FIG_MID[1] * q
        if q == int(q):  # whole knight pixels land on whole output pixels
            ox, oy = round(ox), round(oy)
        self.ox, self.oy = ox, oy

    def at(self, x, y):
        """A knight-pixel point in output pixels."""
        return self.ox + x * self.q, self.oy + y * self.q


def figure_layer(lay, mono=False):
    """The figure's premultiplied pixels {(x, y): [r, g, b, a]} (0..1): each square's exact area on each output
    pixel, so whole-pixel scales stay crisp and the smallest sizes are area-averaged (then [crisp])."""
    out = {}
    q = lay.q
    for x, y, s, (r, g, b, a) in FIGURE:
        if mono:  # Android's themed icon tints the alpha: solid outline and visor, the lighter parts see-through
            dark = 0.299 * r + 0.587 * g + 0.114 * b < 0.3 * 255
            r = g = b = 255
            a = a if dark else round(a * 0.5)
        x0, y0 = lay.at(x, y)
        x1, y1 = x0 + s * q, y0 + s * q
        al = a / 255
        for py in range(math.floor(y0), math.ceil(y1)):
            hy = min(y1, py + 1) - max(y0, py)
            if hy <= 0:
                continue
            for px in range(math.floor(x0), math.ceil(x1)):
                hx = min(x1, px + 1) - max(x0, px)
                if hx <= 0:
                    continue
                k = hx * hy * al
                p = out.setdefault((px, py), [0.0, 0.0, 0.0, 0.0])
                p[0] += r / 255 * k
                p[1] += g / 255 * k
                p[2] += b / 255 * k
                p[3] += k
    return crisp(out) if q < 1 else out


def crisp(fig):
    """The smallest sizes' figure, which can't keep the knight's 1 px outline: a sharp silhouette (a pixel more
    than a third covered is whole), its averaged colours kept inside and darkened on its edge, so it stays a
    dark-rimmed shape on the gold instead of a soft smudge."""
    keep = {k: v for k, v in fig.items() if v[3] >= 0.35}
    out = {}
    for (x, y), (r, g, b, a) in keep.items():
        rgb = (r / a, g / a, b / a)
        if any((x + dx, y + dy) not in keep for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            rgb = tuple(c * 0.45 + o * 0.55 for c, o in zip(rgb, (0.08, 0.06, 0.08)))
        out[(x, y)] = [rgb[0], rgb[1], rgb[2], 1.0]
    return out


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def sky(t):
    if t >= 1:
        return SKY[-1][1]
    for (t0, c0), (t1, c1) in zip(SKY, SKY[1:]):
        if t <= t1:
            return mix(c0, c1, (t - t0) / (t1 - t0))


def rounded_box(px, py, body):
    """The signed distance from a point to the rounded square [body] (x, y, side, radius): < 0 inside."""
    x, y, b, r = body
    hx = hy = b / 2 - r
    dx, dy = abs(px - (x + b / 2)) - hx, abs(py - (y + b / 2)) - hy
    return math.hypot(max(dx, 0), max(dy, 0)) + min(max(dx, dy), 0) - r


def over(base, rgb, a):
    """[rgb] (0..255) at alpha [a] over the opaque colour [base]."""
    return tuple(base[i] + (rgb[i] - base[i]) * a for i in range(3))


def comp(col, alpha, rgb, a):
    """[rgb] at alpha [a] over [col] at alpha [alpha] (straight colours): the new colour and alpha."""
    out = a + alpha * (1 - a)
    if out <= 0:
        return col, 0.0
    return tuple((rgb[i] * a + col[i] * alpha * (1 - a)) / out for i in range(3)), out


def clamp01(v):
    return 0.0 if v < 0 else 1.0 if v > 1 else v


def render(size, kind):
    """One icon as RGBA bytes. Kinds: "mac", "square" (shaped, with rim), "full" (the web's maskable: full bleed),
    "fg" / "bg" / "mono" (Android's adaptive layers: the figure with its halo and shadow; the sky; the silhouette)."""
    lay = Layout(size, kind)
    q, s = lay.q, size
    fig = figure_layer(lay, mono=kind == "mono")
    sun_x, sun_y = lay.at(HALO[0], HALO[1])
    halo_r = HALO[2] * q
    sh_x, sh_y = lay.at(SHADOW[0], SHADOW[1])
    sh_rx, sh_ry = SHADOW[2] * q, SHADOW[3] * q
    body = lay.body
    if body:
        rim = max(1.0, 0.024 * body[2])
        glint = 0.010 * body[2] if body[2] >= 60 else 0
    blur, drop = 0.022 * s, 0.010 * s  # macOS's drop shadow
    with_sky = kind in ("mac", "square", "full", "bg")
    with_glow = kind in ("mac", "square", "full", "fg")
    out = bytearray(s * s * 4)
    for py in range(s):
        cy = py + 0.5
        for px in range(s):
            cx = px + 0.5
            if body:
                d = rounded_box(cx, cy, body)
                cover = clamp01(0.5 - d)
                if cover <= 0:
                    if kind == "mac":  # only the drop shadow out here
                        ds = rounded_box(cx, cy - drop, body)
                        a = 0.30 * clamp01(1 - ds / blur) ** 2
                        if a > 0:
                            o = (py * s + px) * 4
                            out[o:o + 4] = bytes((0, 0, 0, round(a * 255)))
                    continue
            else:
                cover = 1.0
            col, alpha = (0.0, 0.0, 0.0), 0.0
            if with_sky:
                dx, dy = cx - sun_x, cy - sun_y
                dist = math.hypot(dx, dy)
                t = dist / lay.sky
                col, alpha = sky(t), 1.0
                # The splash's 10 rays, one straight up through the crown, faint near the sun and at the edge.
                if dist > 0:
                    ang = (math.atan2(dy, dx) + math.pi / 2) % (math.pi / 5)
                    off = min(ang, math.pi / 5 - ang)
                    ray = clamp01(0.5 + (0.12 - off) * dist)
                    if ray > 0:
                        fade = clamp01((t - 0.12) / 0.15) * (1 - 0.45 * clamp01(t))
                        col = over(col, RAY, 0.24 * ray * fade)
            if with_glow:
                e = math.hypot((cx - sh_x) / sh_rx, (cy - sh_y) / sh_ry)
                a = 0.5 * clamp01(1 - e) ** 0.8
                if a > 0:
                    col, alpha = comp(col, alpha, SHADE, a)
                t = math.hypot(cx - sun_x, cy - sun_y) / halo_r
                if t < 1:  # 0xDDFFFFFF, 0x66FFF3C0, 0x00FFFFFF at 0, 0.6, 1
                    if t < 0.6:
                        k = t / 0.6
                        rgb, a = mix((255, 255, 255), (255, 243, 192), k), 0.867 + (0.4 - 0.867) * k
                    else:
                        rgb, a = (255, 243, 192), 0.4 * (1 - (t - 0.6) / 0.4)
                    col, alpha = comp(col, alpha, rgb, a)
            f = fig.get((px, py))
            if f is not None and f[3] > 0:
                fa = min(1.0, f[3])
                frgb = (f[0] / f[3] * 255, f[1] / f[3] * 255, f[2] / f[3] * 255)
                col, alpha = comp(col, alpha, frgb, fa)
            if body:
                if glint:
                    g = clamp01(0.5 + glint / 2 - abs(d + rim + glint / 2))
                    if g > 0:
                        col = over(col, GLINT, 0.45 * g)
                r = clamp01(d + rim + 0.5)
                if r > 0:
                    col = over(col, RIM, r)
            if alpha <= 0:
                continue
            a = alpha * cover
            o = (py * s + px) * 4
            if kind == "mac" and cover < 1:  # the edge's antialiasing over the drop shadow
                ds = rounded_box(cx, cy - drop, body)
                sa = 0.30 * clamp01(1 - ds / blur) ** 2
                ta = a + sa * (1 - a)
                col = tuple(c * a / ta for c in col) if ta > 0 else col
                a = ta
            out[o:o + 4] = bytes((round(col[0]), round(col[1]), round(col[2]), round(a * 255)))
    return bytes(out)


def save(path, size, kind, cache):
    key = (size, kind)
    if key not in cache:
        cache[key] = render(size, kind)
    write_png(path, size, size, cache[key])
    return cache[key]


def write_ico(path, sizes, cache):
    """A Windows .ico of PNG entries (Vista and later read them at every size)."""
    pngs = []
    with tempfile.TemporaryDirectory() as tmp:
        for s in sizes:
            f = Path(tmp) / f"{s}.png"
            save(f, s, "square", cache)
            pngs.append((s, f.read_bytes()))
    head = struct.pack("<HHH", 0, 1, len(pngs))
    offset, dirs, data = 6 + 16 * len(pngs), b"", b""
    for s, png in pngs:
        dirs += struct.pack("<BBBBHHII", s % 256, s % 256, 0, 0, 1, 32, len(png), offset + len(data))
        data += png
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(head + dirs + data)


MAC_SIZES = [16, 32, 64, 128, 256, 512, 1024]
WIN_SIZES = [16, 24, 32, 48, 64, 128, 256]
LINUX_SIZE = 256
ANDROID = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}  # x 48 dp legacy, x 108 dp adaptive
WEB = {"favicon.png": (32, "square"), "icons/Icon-192.png": (192, "square"), "icons/Icon-512.png": (512, "square"),
       "icons/Icon-maskable-192.png": (192, "full"), "icons/Icon-maskable-512.png": (512, "full")}


def build(cache, root=ROOT):
    mac = root / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for s in MAC_SIZES:
        save(mac / f"app_icon_{s}.png", s, "mac", cache)
    write_ico(root / "windows/runner/resources/app_icon.ico", WIN_SIZES, cache)
    save(root / "linux/runner/resources/app_icon.png", LINUX_SIZE, "square", cache)
    res = root / "android/app/src/main/res"
    for dpi, k in ANDROID.items():
        save(res / f"mipmap-{dpi}/ic_launcher.png", round(48 * k), "square", cache)
        for layer, kind in (("foreground", "fg"), ("background", "bg"), ("monochrome", "mono")):
            save(res / f"mipmap-{dpi}/ic_launcher_{layer}.png", round(108 * k), kind, cache)
    for name, (s, kind) in WEB.items():
        save(root / "web" / name, s, kind, cache)


# A 3x5 pixel font for the contact sheet's labels.
FONT = {
    "0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111",
    "4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001001010010",
    "8": "111101111101111", "9": "111101111001111", "A": "010101111101101", "B": "110101110101110",
    "C": "011100100100011", "D": "110101101101110", "E": "111100110100111", "F": "111100110100100",
    "G": "011100101101011", "H": "101101111101101", "I": "111010010010111", "K": "101101110101101",
    "L": "100100100100111", "M": "101111111101101", "N": "110101101101101", "O": "010101101101010",
    "P": "110101110100100", "R": "110101110101101", "S": "011100010001110", "T": "111010010010010",
    "U": "101101101101111", "W": "101101111111101", "X": "101101010101101", "Y": "101101010010010",
    "V": "101101101101010", "Q": "010101101110011", "Z": "111001010100111", "J": "001001001101010",
    " ": "000000000000000", "-": "000000111000000", "/": "001001010100100",
}


class Sheet:
    def __init__(self, w, h, bg):
        self.w, self.h = w, h
        self.px = bytearray(bytes(bg) * (w * h))

    def fill(self, x, y, w, h, rgb):
        n = min(self.w, x + w) - max(0, x)
        for yy in range(max(0, y), min(self.h, y + h)):
            o = (yy * self.w + max(0, x)) * 4
            self.px[o:o + 4 * n] = bytes(tuple(rgb[:3]) + (255,)) * n

    def blit(self, rgba, size, x, y, zoom=1):
        for sy in range(size * zoom):
            for sx in range(size * zoom):
                i = ((sy // zoom) * size + sx // zoom) * 4
                a = rgba[i + 3] / 255
                if a == 0:
                    continue
                o = ((y + sy) * self.w + x + sx) * 4
                for k in range(3):
                    self.px[o + k] = round(rgba[i + k] * a + self.px[o + k] * (1 - a))

    def text(self, s, x, y, rgb, k=3):
        for ch in s.upper():
            glyph = FONT.get(ch, FONT[" "])
            for i, bit in enumerate(glyph):
                if bit == "1":
                    self.fill(x + (i % 3) * k, y + (i // 3) * k, k, k, rgb)
            x += 4 * k


def previews(out, cache):
    """The macOS icon at 1024, 256, 64, 32 and 16 px, and a contact sheet of every platform's files at their own size,
    on light (left) and dark (right), with the small ones also zoomed (nearest neighbour) to show their pixels."""
    out.mkdir(parents=True, exist_ok=True)
    for s in (1024, 256, 64, 32, 16):
        save(out / f"icon_{s}.png", s, "mac", cache)
    rows = [
        ("MACOS", [(s, "mac") for s in (256, 128, 64, 32, 16)]),
        ("WINDOWS ICO", [(s, "square") for s in (256, 128, 64, 48, 32, 24, 16)]),
        ("LINUX / WEB / ANDROID LEGACY", [(256, "square"), (192, "square"), (96, "square"), (48, "square"),
                                          (32, "square")]),
        ("ANDROID ADAPTIVE BG FG MONO / WEB MASKABLE", [(216, "bg"), (216, "fg"), (216, "mono"), (192, "full")]),
        ("ZOOMED MACOS", [(16, "mac", 8), (32, "mac", 4), (64, "mac", 2)]),
        ("ZOOMED SQUARE", [(16, "square", 8), (24, "square", 6), (32, "square", 4), (48, "square", 3)]),
    ]
    pad, label, under = 24, 30, 20
    half = 990
    height = pad + sum(label + max(it[0] * (it[2] if len(it) > 2 else 1) for it in items) + under + pad
                       for _, items in rows)
    sheet = Sheet(half * 2, height, (0, 0, 0, 255))
    for side, (bg, ink) in enumerate((((236, 230, 220), (40, 30, 40)), ((28, 24, 32), (230, 220, 200)))):
        left = side * half
        sheet.fill(left, 0, half, height, bg)
        y = pad
        for title, items in rows:
            sheet.text(title, left + pad, y, ink)
            y += label
            x = left + pad
            tallest = 0
            for it in items:
                s, kind, z = it[0], it[1], it[2] if len(it) > 2 else 1
                if (s, kind) not in cache:
                    cache[(s, kind)] = render(s, kind)
                rgba = cache[(s, kind)]
                if kind in ("fg", "mono"):  # transparent layers: shown on a lighter square, the silhouette in ink
                    sheet.fill(x, y, s, s, tuple(min(255, c + 24) for c in bg))
                if kind == "mono":
                    rgba = b"".join(bytes(ink) + rgba[i + 3:i + 4] for i in range(0, len(rgba), 4))
                sheet.blit(rgba, s, x, y, z)
                sheet.text(str(s), x, y + s * z + 4, ink, 2)
                x += s * z + pad
                tallest = max(tallest, s * z)
            y += tallest + under + pad
    write_png(out / "sheet.png", half * 2, height, bytes(sheet.px))


def arg(name):
    return Path(sys.argv[sys.argv.index(name) + 1]).expanduser() if name in sys.argv else None


if __name__ == "__main__":
    set_figure(placeholder_figure() if "--placeholder" in sys.argv else load_figure())
    cache = {}
    build(cache, (arg("--out") or ROOT).resolve())
    if "--preview" in sys.argv:
        previews(arg("--preview"), cache)
    print(len(cache), "icons drawn")
