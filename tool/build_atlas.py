#!/usr/bin/env python3
"""Packs every NPC (enemies + characters) into one atlas per character: one row per animation.

Reads the sheets tool/export_aseprite.py wrote (sprites/catalog.json), so run that first:
    python3 tool/build_atlas.py              # all characters
    python3 tool/build_atlas.py skeleton-warrior   # only characters whose path contains this
Writes sprites/npc/<pack>/<character>/atlas.png + atlas.json. Every cell has the same size
(the biggest frame of that character); frames sit bottom-centre in their cell, because every
Pixel Crawler character stands on its frame's bottom row, so the feet line up across rows.
"""
import json
import math
import re
import struct
import sys
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from export_aseprite import parse, sheet  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "sprites"
OUT = SPRITES / "npc"

# Row order: stand, move, attack, react, die; then side, down, up.
ACTIONS = ["idle", "walk", "run", "move", "attack", "slice", "pierce", "crush", "collect", "carry",
           "fishing", "watering", "hit", "death"]
DIRS = ["side", "down", "up", "top"]
ANIM_DIR = re.compile(r"^(" + "|".join(ACTIONS) + r")(-|$)")  # run, run-base, attack-01-base, idle-hold


def read_png(path):
    """RGBA rows of an 8-bit RGBA/RGB/palette PNG."""
    d, i, idat = path.read_bytes(), 8, b""
    pal, trns = [], b""
    while i < len(d):
        n, t = struct.unpack(">I4s", d[i:i + 8])
        c = d[i + 8:i + 8 + n]
        i += 12 + n
        if t == b"IHDR":
            w, h, bd, ct = struct.unpack(">IIBB", c[:10])
        elif t == b"PLTE":
            pal = [c[j:j + 3] for j in range(0, len(c), 3)]
        elif t == b"tRNS":
            trns = c
        elif t == b"IDAT":
            idat += c
    bpp = {6: 4, 2: 3, 3: 1}[ct]
    raw, stride, out, prev, o = zlib.decompress(idat), w * bpp, bytearray(), bytearray(w * bpp), 0
    for _ in range(h):
        f, line = raw[o], bytearray(raw[o + 1:o + 1 + stride])
        o += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b, c = prev[x], (prev[x - bpp] if x >= bpp else 0)
            if f == 1:
                line[x] = (line[x] + a) & 255
            elif f == 2:
                line[x] = (line[x] + b) & 255
            elif f == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        prev = line
        if ct == 6:
            out += line
        elif ct == 2:
            for x in range(w):
                out += line[x * 3:x * 3 + 3] + b"\xff"
        else:
            for k in line:
                out += pal[k] + bytes([trns[k] if k < len(trns) else 255])
    return w, h, out


def write_png(path, w, h, rgba):
    def chunk(t, data):
        return struct.pack(">I", len(data)) + t + data + struct.pack(">I", zlib.crc32(t + data))
    rows = b"".join(b"\0" + bytes(rgba[y * w * 4:(y + 1) * w * 4]) for y in range(h))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))


def over(dst, dw, dx, dy, src, sw, sh, clip):
    """Alpha-composites an sw x sh RGBA image onto dst (row stride dw) at dx,dy, inside clip=(x0,y0,x1,y1)."""
    x0, y0, x1, y1 = clip
    for y in range(sh):
        ty = dy + y
        if not y0 <= ty < y1:
            continue
        for x in range(sw):
            tx = dx + x
            s = (y * sw + x) * 4
            sa = src[s + 3] / 255
            if sa == 0 or not x0 <= tx < x1:
                continue
            d = (ty * dw + tx) * 4
            da = dst[d + 3] / 255
            oa = sa + da * (1 - sa)
            for k in range(3):
                dst[d + k] = int((src[s + k] * sa + dst[d + k] * da * (1 - sa)) / oa)
            dst[d + 3] = int(oa * 255)


def content_box(px, stride, x0, fw, fh):
    xs, ys = [], []
    for y in range(fh):
        for x in range(fw):
            if px[(y * stride + x0 + x) * 4 + 3]:
                xs.append(x)
                ys.append(y)
    return (min(xs), min(ys), max(xs), max(ys)) if xs else None


def run_gear(src):
    """Hands + weapons of a layered Run.aseprite (Free Pack style).

    Returns (w, h, behind, front, body_box, run_sheet) or None: behind/front are the gear of the
    first frame, run_sheet the whole Run strip with that gear shown. The body is the centred
    visible layer at most 26px wide with the most area; layers touching the bottom 12px are
    legs/feet; every other layer is gear, even when hidden (the Wizard's staff and book, the
    Skeleton Rogue's bow and torch and the Skeleton Mage's staff ship as hidden layers).
    """
    w, h, layers, shown, frames, _ = parse(src)
    cels = frames[0][1]
    ids = [li for li, L in enumerate(layers) if L["type"] == 0 and li in cels]
    box = {li: (cels[li][0], cels[li][1], cels[li][0] + cels[li][2], cels[li][1] + cels[li][3]) for li in ids}
    upper = [li for li in ids if box[li][1] < h - 12]
    bodies = [li for li in upper if shown[li] and box[li][2] - box[li][0] <= 26
              and abs((box[li][0] + box[li][2]) / 2 - w / 2) <= 8]
    if not bodies:
        return None
    body = max(bodies, key=lambda li: (box[li][2] - box[li][0]) * (box[li][3] - box[li][1]))
    gear = [li for li in upper if li != body]
    if not gear:
        return None
    one = [frames[0]]
    behind = sheet(w, h, one, [li for li in gear if li < body], layers)[2]
    front = sheet(w, h, one, [li for li in gear if li > body], layers)[2]
    run_sheet = sheet(w, h, frames, sorted({li for li in ids if shown[li]} | set(gear)), layers)[2]
    return w, h, behind, front, box[body], run_sheet


def components(buf, w, h):
    """8-connected opaque blobs of an RGBA image, as lists of (x, y)."""
    seen, out = set(), []
    for y in range(h):
        for x in range(w):
            if buf[(y * w + x) * 4 + 3] and (x, y) not in seen:
                stack, pts = [(x, y)], []
                seen.add((x, y))
                while stack:
                    cx, cy = stack.pop()
                    pts.append((cx, cy))
                    for nx in (cx - 1, cx, cx + 1):
                        for ny in (cy - 1, cy, cy + 1):
                            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and buf[(ny * w + nx) * 4 + 3]:
                                seen.add((nx, ny))
                                stack.append((nx, ny))
                out.append(pts)
    return out


def rotate(src, w, h, pivot, angle, to):
    """src (w x h RGBA) turned `angle` degrees clockwise around `pivot`, moved so the pivot lands on `to`."""
    out = bytearray(w * h * 4)
    c, s = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    for y in range(h):
        for x in range(w):
            rx, ry = x - to[0], y - to[1]
            sx, sy = round(c * rx + s * ry + pivot[0]), round(-s * rx + c * ry + pivot[1])  # inverse map, nearest
            if 0 <= sx < w and 0 <= sy < h:
                out[(y * w + x) * 4:(y * w + x) * 4 + 4] = src[(sy * w + sx) * 4:(sy * w + sx) * 4 + 4]
    return out


PAD = 24  # generated attacks get this much extra room each side, so a thrust never leaves the cell
FX = (245, 245, 238)  # effect white


def plot(cell, w, h, x, y, alpha, color=FX):
    x, y = round(x), round(y)
    if 0 <= x < w and 0 <= y < h and cell[(y * w + x) * 4 + 3] < alpha:
        cell[(y * w + x) * 4:(y * w + x) * 4 + 4] = bytes((*color, alpha))


def line(cell, w, h, a, b, alpha, color=FX):
    n = max(1, round(max(abs(b[0] - a[0]), abs(b[1] - a[1]))))
    for i in range(n + 1):
        plot(cell, w, h, a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n, alpha, color)


# How each generated character attacks (default: a stab with its tallest weapon).
ATTACKS = {"skeleton-warrior": ("stab", "bash"), "orc-warrior": ("stab", "bash"),
           "skeleton-rogue": ("shoot",), "orc-rogue": ("shoot",),
           "skeleton-mage": ("cast",), "orc-shaman": ("cast",), "wizzard": ("cast",)}


def split_gear(gear, idle_frame, fw, fh):
    """Idle body + Run gear on a padded canvas, the gear cut into weapon (tallest piece), shield
    (biggest other piece, if any) and the rest (free hands etc.)."""
    w, h, behind, front, body, _ = gear
    W = w + 2 * PAD
    ib = content_box(idle_frame, fw, 0, fw, fh)
    bx = PAD + (w - fw) // 2  # idle frame sits bottom-centre, like the atlas does
    # line the Run gear up with the idle body, the same way the idle row does
    sx = bx + (ib[0] + ib[2]) // 2 - (body[0] + body[2]) // 2
    sy = h - fh + ib[1] - body[1]
    body = (body[0] + sx, body[1] + sy, body[2] + sx, body[3] + sy)
    gearimg = bytearray(W * h * 4)
    over(gearimg, W, sx, sy, behind, w, h, (0, 0, W, h))
    over(gearimg, W, sx, sy, front, w, h, (0, 0, W, h))
    blobs = components(gearimg, W, h)
    if not blobs:
        return None
    weapon = max(blobs, key=lambda b: max(y for _, y in b) - min(y for _, y in b))
    others = [b for b in blobs if b is not weapon]
    shield = max(others, key=len) if others and len(max(others, key=len)) >= 120 else None

    def cut(pts):
        img = bytearray(W * h * 4)
        for x, y in pts:
            img[(y * W + x) * 4:(y * W + x) * 4 + 4] = gearimg[(y * W + x) * 4:(y * W + x) * 4 + 4]
        return img
    base = bytearray(W * h * 4)
    over(base, W, bx, h - fh, idle_frame, fw, fh, (0, 0, W, h))
    rest = cut([p for b in others if b is not shield for p in b])
    return {"W": W, "h": h, "base": base, "body": body, "weapon": weapon, "wimg": cut(weapon),
            "shield": shield, "simg": cut(shield) if shield else None, "rest": rest}


def layer(cell, W, h, img, dx=0, dy=0):
    over(cell, W, dx, dy, img, W, h, (0, 0, W, h))


# stab keyframes: (blade angle, 0 = idle grip .. 1 = chest-ready grip, thrust px, body lean px, effect, ms)
# raise the point level, draw back and hold, drive it out, glint, ease back into the idle pose
STAB = [(0, 0, 0, 0, None, 80), (45, .5, 0, 0, None, 70), (90, 1, 0, 0, None, 80),
        (90, 1, -2, 0, None, 80), (90, 1, -4, -1, None, 90), (90, 1, -5, -1, None, 140),
        (90, 1, 4, 0, "lines", 40), (90, 1, 10, 1, "lines", 40), (90, 1, 12, 2, "glint", 70),
        (90, 1, 12, 2, "glint-fade", 90), (90, 1, 7, 1, None, 80), (90, 1, 2, 0, None, 80),
        (45, .5, 0, 0, None, 70), (0, 0, 0, 0, None, 80)]


def stab_attack(g):
    W, h, body, weapon = g["W"], g["h"], g["body"], g["weapon"]
    # grip: the widest row in the lower half of the weapon, where the hand closes around it
    ys = sorted({y for _, y in weapon})
    rows = {y: [x for x, yy in weapon if yy == y] for y in ys}
    gy = max((y for y in ys if y >= (ys[0] + ys[-1]) / 2), key=lambda y: len(rows[y]))
    grip = (sum(rows[gy]) / len(rows[gy]), gy)
    reach = gy - ys[0]  # blade length above the grip
    ready = (body[2] - 3, body[1] + 15)  # level at the chest, below the face, point forward
    frames = []
    for angle, p, shift, lean, fx, _ in STAB:
        to = (grip[0] + (ready[0] - grip[0]) * p + shift, grip[1] + (ready[1] - grip[1]) * p)
        blade = rotate(g["wimg"], W, h, grip, angle, to)  # 0 and 90 degrees keep every pixel intact
        cell = bytearray(W * h * 4)
        if angle < 90:  # still (or again) at the back, behind the body
            layer(cell, W, h, blade, lean)
        layer(cell, W, h, g["base"], lean)
        layer(cell, W, h, g["rest"], lean)
        if g["simg"]:
            layer(cell, W, h, g["simg"], lean)
        if angle == 90:  # levelled: over the shield, point forward
            layer(cell, W, h, blade, lean)
        x0, y0 = to[0] + lean, to[1]
        tip = x0 + reach
        if fx == "lines":  # speed lines trailing the blade
            for dy, a, b in ((-3, .1, .7), (3, .3, .9), (-6, .4, .8)):
                for t in range(int(reach * a), int(reach * b)):
                    plot(cell, W, h, x0 - 6 + t, y0 + dy, 140)
        if fx and fx.startswith("glint"):  # a four-point star at the point
            big, alpha = (fx == "glint"), (235 if fx == "glint" else 150)
            for k in range(0, 4 if big else 2):
                for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
                    plot(cell, W, h, tip + 3 + dx, y0 + dy, alpha)
        frames.append(cell)
    return frames, [k[-1] for k in STAB]


# shield bash keyframes: (shield shift px, body lean px, effect, ms); brace and hold, slam, burst, ease back
# the shield stays close to the body: the lean carries most of the push, so it reads as a shove, not a throw
BASH = [(0, 0, None, 80), (-1, 0, None, 70), (-2, -1, None, 80), (-3, -1, None, 80), (-3, -2, None, 90),
        (-3, -2, None, 140), (2, 1, "lines", 40), (4, 3, "lines", 40), (5, 4, "burst", 70),
        (5, 4, "burst-fade", 90), (3, 3, None, 80), (2, 2, None, 80), (1, 1, None, 70), (0, 0, None, 80)]


def bash_attack(g):
    W, h, shield = g["W"], g["h"], g["shield"]
    left, right = min(x for x, _ in shield), max(x for x, _ in shield)
    ys = [y for _, y in shield]
    mid = (min(ys) + max(ys)) / 2
    frames = []
    for shift, lean, fx, _ in BASH:
        cell = bytearray(W * h * 4)
        layer(cell, W, h, g["wimg"], lean)  # the sword stays up at the back
        layer(cell, W, h, g["base"], lean)
        layer(cell, W, h, g["rest"], lean)
        layer(cell, W, h, g["simg"], lean + shift)
        edge = right + lean + shift
        if fx == "lines":  # motion lines behind the shield
            for dy in (-7, -2, 3, 8):
                for t in range(3, 11):
                    plot(cell, W, h, left + lean + shift - t, mid + dy, 140)
        if fx and fx.startswith("burst"):  # impact burst off the shield face
            big = fx == "burst"
            for ang in (-70, -40, -12, 12, 40, 70):
                a = math.radians(ang)
                for k in (range(3, 9) if big else range(6, 10)):
                    plot(cell, W, h, edge + math.cos(a) * k, mid + math.sin(a) * k, 235 if big else 140)
        frames.append(cell)
    return frames, [k[-1] for k in BASH]


def others(cell, g, dx=0, dy=0):
    """Everything but the weapon: free hands and the off-hand item (torch, book, second blade...)."""
    layer(cell, g["W"], g["h"], g["rest"], dx, dy)
    if g["simg"]:
        layer(cell, g["W"], g["h"], g["simg"], dx, dy)


ARROW = ("Pixel Crawler - Free Pack/Weapons/Wood/Wood.png", (32, 4, 16, 7))  # points right
# shoot keyframes: (0 = idle bow .. 1 = bow at the chest, draw px, arrow flight px or None, effect, ms)
SHOOT = [(0, 0, None, None, 80), (.5, 0, None, None, 70), (1, 0, None, None, 80),
         (1, 2, None, None, 70), (1, 4, None, None, 70), (1, 6, None, None, 80), (1, 7, None, None, 90),
         (1, 7, None, None, 160), (1, 0, 8, "lines", 40), (1, 0, 22, "lines", 40),
         (1, 0, None, "twang", 80), (1, 0, None, None, 80), (.5, 0, None, None, 70), (0, 0, None, None, 80)]


def shoot_attack(g):
    W, h, body, bow = g["W"], g["h"], g["body"], g["weapon"]
    # the string: the bright leftmost pixel of each row of the bow (it faces right, string at the back)
    rows = {}
    for x, y in bow:
        rows.setdefault(y, []).append(x)
    string, img = set(), g["wimg"]
    for y, xs in rows.items():
        x = min(xs)
        r, gg, b = img[(y * W + x) * 4:(y * W + x) * 4 + 3]
        if (r + gg + b) / 3 > 150 and len(xs) > 1:
            string.add((x, y))
    unstrung = bytearray(img)
    for x, y in string:
        unstrung[(y * W + x) * 4:(y * W + x) * 4 + 4] = b"\0\0\0\0"
    top, bottom = min(rows), max(rows)
    tips = ((min(rows[top]), top), (min(rows[bottom]), bottom))
    mid_y = (top + bottom) / 2
    string_x = sum(x for x, _ in string) / len(string) if string else tips[0][0]
    bx0 = min(x for x, _ in bow)
    to_front = body[2] + 1 - bx0  # bow held just in front of the chest
    _, _, apx = read_png(ROOT / "raw_assets" / ARROW[0])
    aw_full = struct.unpack(">I", (ROOT / "raw_assets" / ARROW[0]).read_bytes()[16:20])[0]
    ax, ay, aw, ah = ARROW[1]
    arrow = bytearray(aw * ah * 4)
    for y in range(ah):
        arrow[y * aw * 4:(y + 1) * aw * 4] = apx[((ay + y) * aw_full + ax) * 4:((ay + y) * aw_full + ax + aw) * 4]
    frames = []
    for p, draw, flight, fx, _ in SHOOT:
        dx = round(to_front * p)
        cell = bytearray(W * h * 4)
        others(cell, g)
        layer(cell, W, h, g["base"])
        nock = (string_x + dx - draw, mid_y)
        if draw or fx == "twang":
            layer(cell, W, h, unstrung, dx)
            wobble = 1 if fx == "twang" else 0
            for tip in tips:
                line(cell, W, h, (tip[0] + dx, tip[1]), (nock[0] - wobble, nock[1]), 255, (222, 214, 196))
        else:
            layer(cell, W, h, img, dx)
        if draw:  # arrow on the string, its tail at the nock
            over(cell, W, round(nock[0]) - 2, round(mid_y - ah / 2), arrow, aw, ah, (0, 0, W, h))
        if flight is not None:
            ax0 = round(string_x + dx - 2 + flight)
            over(cell, W, ax0, round(mid_y - ah / 2), arrow, aw, ah, (0, 0, W, h))
            for dy in (-2, 2):
                line(cell, W, h, (ax0 - 8, mid_y + dy), (ax0 - 2, mid_y + dy), 140)
        frames.append(cell)
    return frames, [k[-1] for k in SHOOT]


# cast keyframes: (staff lift px, staff forward px, charge 0..1 or None, release ring radius or None, ms)
CAST = [(0, 0, None, None, 80), (-2, 0, None, None, 70), (-4, 1, None, None, 80), (-5, 1, 0, None, 80),
        (-5, 1, .25, None, 80), (-5, 1, .5, None, 80), (-5, 1, .75, None, 90), (-5, 1, 1, None, 160),
        (-2, 4, None, 3, 50), (-1, 4, None, 7, 60), (-1, 3, None, 11, 80), (0, 2, None, None, 80),
        (0, 1, None, None, 70), (0, 0, None, None, 80)]


def cast_attack(g):
    W, h, staff = g["W"], g["h"], g["weapon"]
    top = min(y for _, y in staff)
    head = [(x, y) for x, y in staff if y <= top + 6]
    # glow colour: the most saturated pixel of the staff head (the blue gem, the bone, ...)
    def sat(p):
        r, gg, b = g["wimg"][(p[1] * W + p[0]) * 4:(p[1] * W + p[0]) * 4 + 3]
        return max(r, gg, b) - min(r, gg, b)
    best = max(head, key=sat)
    color = tuple(g["wimg"][(best[1] * W + best[0]) * 4:(best[1] * W + best[0]) * 4 + 3])
    if sat(best) < 60:
        color = (255, 236, 150)  # plain staff: a warm gold spark
    light = tuple(min(255, c + 90) for c in color)
    orb = (sum(x for x, _ in head) / len(head), top + 2)
    frames = []
    for lift, fwd, charge, ring, _ in CAST:
        cell = bytearray(W * h * 4)
        others(cell, g)
        layer(cell, W, h, g["base"])
        layer(cell, W, h, g["wimg"], fwd, lift)
        ox, oy = orb[0] + fwd, orb[1] + lift
        if charge is not None:  # motes drawn in towards the staff head, the glow growing
            radius = 12 - 9 * charge
            for k in range(6):
                a = math.radians(k * 60 + charge * 90)
                mx, my = ox + math.cos(a) * radius, oy + math.sin(a) * radius
                for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):  # 2x2 motes, readable at game scale
                    plot(cell, W, h, mx + dx, my + dy, 235, light)
            glow = 1 + round(charge * 1.5)  # 3x3 growing to 5x5, a white core once charged
            for dx in range(-glow, glow + 1):
                for dy in range(-glow, glow + 1):
                    if abs(dx) + abs(dy) <= glow + 1:
                        plot(cell, W, h, ox + dx, oy + dy, int(130 + 100 * charge), light)
            if charge >= .75:
                plot(cell, W, h, ox, oy, 255, (255, 255, 255))
        if ring is not None:  # release: a ring bursting out of the head
            for k in range(0, 360, 12):
                a = math.radians(k)
                plot(cell, W, h, ox + math.cos(a) * ring, oy + math.sin(a) * ring * .8, max(90, 240 - ring * 12), light)
            if ring < 8:
                for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                    plot(cell, W, h, ox + dx, oy + dy, 255, (255, 255, 255))
        frames.append(cell)
    return frames, [k[-1] for k in CAST]


MAKERS = {"stab": stab_attack, "bash": bash_attack, "shoot": shoot_attack, "cast": cast_attack}


def character_of(file):
    """sprites path -> (character dir parts, animation name). Walks up past animation folders."""
    parts = Path(file).with_suffix("").parts  # (category, pack, ..., name)
    anim, dirs = parts[-1], list(parts[2:-1])
    while dirs and ANIM_DIR.search(dirs[-1]):
        dirs.pop()
    return (parts[1], *dirs), anim


def sort_key(anim):
    words = anim.split("-")
    action = next((i for i, a in enumerate(ACTIONS) if a in words), len(ACTIONS))
    direction = next((i for i, d in enumerate(DIRS) if d in words), -1)
    return action, direction, anim


def main(filt):
    catalog = json.loads((SPRITES / "catalog.json").read_text())
    groups = {}
    for e in catalog:
        if e["category"] in ("enemies", "characters") and "frames" in e and filt in e["file"]:
            char, anim = character_of(e["file"])
            groups.setdefault(char, {})
            if anim in groups[char]:  # same stem in two folders (Idle vs Idle_Hold): keep the folder
                anim = f"{Path(e['file']).parent.name}-{anim}"
            groups[char][anim] = e
    for char, anims in sorted(groups.items()):
        names = sorted(anims, key=sort_key)
        cw = max(anims[a]["frameWidth"] for a in names)
        ch = max(anims[a]["frameHeight"] for a in names)
        # Free Pack idles are drawn empty-handed; their Run has the hands + weapons as layers.
        run = next((anims[a] for a in names if a.split("-")[0] == "run"), None)
        gear = run_gear(ROOT / "raw_assets" / run["source"]) if run and run["source"].endswith(".aseprite") else None
        # No attack animation ships for these mobs: build them from the idle body and the Run gear.
        made = {}
        idle = next((anims[a] for a in names if a.split("-")[0] == "idle"), None)
        if gear and idle and not any(a.split("-")[0] in ("attack", "slice") for a in names):
            _, _, ipx = read_png(SPRITES / idle["file"])
            fw, fh = idle["frameWidth"], idle["frameHeight"]
            first = bytearray(b"".join(ipx[y * fw * idle["frames"] * 4:(y * fw * idle["frames"] + fw) * 4] for y in range(fh)))
            g = split_gear(gear, first, fw, fh)
            if g:
                for kind in ATTACKS.get(char[-1], ("stab",)):
                    if kind != "bash" or g["shield"]:
                        made[f"attack-{kind}"] = (*MAKERS[kind](g), g["W"], g["h"])
                names = sorted(names + list(made), key=sort_key)
                cw = max(cw, g["W"])  # the wider attack cell; every other row stays bottom-centred in it
        cols = max(len(made[a][0]) if a in made else anims[a]["frames"] for a in names)
        W, H = cw * cols, ch * len(names)
        atlas, rows = bytearray(W * H * 4), []
        for r, a in enumerate(names):
            if a in made:
                frames, ms, gw, gh = made[a]
                dx, dy = (cw - gw) // 2, ch - gh  # bottom-centre, like every other row
                for f, frame in enumerate(frames):
                    over(atlas, W, f * cw + dx, r * ch + dy, frame, gw, gh, (f * cw, r * ch, (f + 1) * cw, (r + 1) * ch))
                rows.append({"name": a, "row": r, "frames": len(frames), "durations": ms,
                             "sourceFrame": [gw, gh], "offset": [dx, dy], "source": "generated",
                             "generatedFrom": [idle["source"], run["source"]]})
                continue
            e = anims[a]
            fw, fh, n = e["frameWidth"], e["frameHeight"], e["frames"]
            sw, _, px = read_png(SPRITES / e["file"])
            if gear is not None and e is run:  # the Run strip again, hidden gear layers included
                sw, px = fw * n, gear[5]
            dx, dy = (cw - fw) // 2, ch - fh  # bottom-centre in the cell
            armed = gear is not None and a.split("-")[0] == "idle"
            first = content_box(px, sw, 0, fw, fh) if armed else None
            for f in range(n):
                cell = (f * cw, r * ch, (f + 1) * cw, (r + 1) * ch)
                if armed and first:
                    gw, gh, behind, front, body, _ = gear
                    b = content_box(px, sw, f * fw, fw, fh) or first
                    # line the Run body up with this idle frame: centre from frame 0 (no jitter), top follows the breathing
                    gx = cell[0] + dx + (first[0] + first[2]) // 2 - (body[0] + body[2]) // 2
                    gy = cell[1] + dy + b[1] - body[1]
                    over(atlas, W, gx, gy, behind, gw, gh, cell)
                    frame = bytearray(fw * fh * 4)
                    for y in range(fh):
                        frame[y * fw * 4:(y + 1) * fw * 4] = px[(y * sw + f * fw) * 4:(y * sw + f * fw + fw) * 4]
                    over(atlas, W, cell[0] + dx, cell[1] + dy, frame, fw, fh, cell)
                    over(atlas, W, gx, gy, front, gw, gh, cell)
                    continue
                for y in range(fh):
                    src = (y * sw + f * fw) * 4
                    dst = ((r * ch + dy + y) * W + f * cw + dx) * 4
                    atlas[dst:dst + fw * 4] = px[src:src + fw * 4]
            rows.append({"name": a, "row": r, "frames": n, "durations": e["durations"],
                         "sourceFrame": [fw, fh], "offset": [dx, dy], "source": e["source"],
                         **({"gearFrom": run["source"]} if armed and first else {})})
        dest = OUT.joinpath(*char)
        write_png(dest / "atlas.png", W, H, atlas)
        (dest / "atlas.json").write_text(json.dumps(
            {"character": char[-1], "pack": char[0], "cell": [cw, ch], "columns": cols,
             "anchor": "bottom-centre of each cell", "rows": rows}, indent=1))
        print(f"{dest.relative_to(ROOT)}: {len(names)} rows x {cols} cols, cell {cw}x{ch}: {', '.join(names)}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "")
