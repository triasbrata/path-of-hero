"""Draws a placeholder for every licensed image in tool/asset_manifest.json, at its exact path and image size
(decisions-log 157), so that a clone of the public repo, which can't hold the packs, builds and runs: `python3
tool/gen_placeholders.py && flutter run`. The output is gitignored there (tool/placeholders.gitignore).

It reads ONLY the manifest (paths, image sizes, the frame grid the code cuts, the feet): never assets/ or raw_assets/,
so nothing it draws comes from a pack. Every shape is drawn from scratch, here or in tool/draw_icons.py:
- characters: a coloured figure per character (its hue from its name), facing right, the feet on the manifest's row
  (59), posed per strip (idle bob, walk steps, attack reach, hurt flash, death fall, summon); a strip marked
  baked_shadow (the Soldier's) has the ground shadow under the figure, as the pack's does;
- shadows: the shadow colour (83,69,69) in rows 55-59, the only place it is used;
- arrows, bursts (a ring that grows and fades), the UI sheets (parchment panels, the nine button colours, round
  icons per cell);
- the Town scene's pieces: its parallax layers (sky, mountains, a castle, rows of pines, the ground), the street's
  grassy lip, a brick per house cell, a furnace and a sawmill per frame, a pot over a fire, a tent, an ore rock, a
  pine, and a crate per prop cell (the manifest's `cells`);
- the battle's floor, props line, clouds and the spawn bar's step: a meadow under a ground line, trunks, crowns,
  rocks and bushes, puffs, a slope of earth and rocks;
- the loot icons (item_*, relic_*, mat_*): the game's own drawing of each from before it took the pack's
  (tool/draw_icons.py), or a round token of its own hue for a name that has none; the Artifacts' atlas
  (artifact_icons.png): a round token per 32x32 cell, each its own colour.

It also draws the platform app icons' placeholder (tool/make_app_icon.py --placeholder: a figure of our own), which
are git-ignored too (the real ones are a pack derivative).

It never overwrites the real art: it refuses a file that git tracks (wherever --out points and through symlinks), and
any file already there that isn't one of its own placeholders (the real art unpacked from the asset vault is
git-ignored too). It lists what it drew, with each file's sha256, in DIR/assets/.placeholders: tool/asset_vault.py
never packs those files, and unpacking the vault replaces them (and drops the list).
Stdlib only:  python3 tool/gen_placeholders.py [--out DIR] [--dry-run] [--no-icons]
(default DIR: the repo; files go to DIR/<manifest path>; --dry-run checks and lists, writes nothing)
"""
import colorsys
import hashlib
import json
import math
import re
import shutil
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from build_atlas import write_png  # noqa: E402
from draw_icons import ICONS as DRAWN, PALETTE as DRAWN_INK  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = Path(__file__).resolve().parent / "asset_manifest.json"

SHADOW = (83, 69, 69, 255)  # the pack's shadow colour; nothing else uses it (lib/main.dart _unshadowed)
CLEAR = (0, 0, 0, 0)
INK = (43, 29, 43, 255)  # outlines
PAPER = (232, 214, 172, 255)
BROWN = (120, 72, 40, 255)
# ui_buttons.png's rows, 48 px apart, by the colours lib/main.dart names (0 light brown .. 8 grey).
BUTTONS = [(200, 160, 110), (236, 236, 230), (110, 180, 90), (90, 140, 210), (230, 150, 60),
           (210, 80, 70), (150, 100, 200), (240, 190, 160), (150, 150, 150)]
# ui_bars.png: bands of 8 rows, so the HP and MP strips the code cuts show a colour each.
BARS = [(70, 130, 220), (90, 190, 80), (240, 190, 60), (40, 32, 36), (200, 205, 215), (210, 60, 60)]


class Img:
    def __init__(self, w, h, fill=CLEAR):
        self.w, self.h = w, h
        self.px = bytearray(bytes(fill) * (w * h))

    def get(self, x, y):
        i = (y * self.w + x) * 4
        return tuple(self.px[i:i + 4])

    def put(self, x, y, c, clip=None):
        x0, y0, x1, y1 = clip or (0, 0, self.w, self.h)
        if x0 <= x < x1 and y0 <= y < y1:
            i = (y * self.w + x) * 4
            self.px[i:i + 4] = bytes(c)

    def rect(self, x0, y0, x1, y1, c, clip=None):
        """Fills x0..x1, y0..y1 (both inclusive)."""
        for y in range(round(y0), round(y1) + 1):
            for x in range(round(x0), round(x1) + 1):
                self.put(x, y, c, clip)

    def ellipse(self, cx, cy, rx, ry, c, clip=None):
        for y in range(math.floor(cy - ry), math.ceil(cy + ry) + 1):
            dy = (y - cy) / ry if ry else 0
            if abs(dy) > 1:
                continue
            half = rx * math.sqrt(1 - dy * dy)
            for x in range(math.ceil(cx - half), math.floor(cx + half) + 1):
                self.put(x, y, c, clip)

    def ring(self, cx, cy, rx, ry, width, c, clip=None):
        for y in range(math.floor(cy - ry - 1), math.ceil(cy + ry) + 2):
            for x in range(math.floor(cx - rx - 1), math.ceil(cx + rx) + 2):
                d = math.hypot((x - cx) / max(rx, .5), (y - cy) / max(ry, .5))
                if abs(d - 1) * max(rx, ry) <= width / 2:
                    self.put(x, y, c, clip)

    def outline(self, box, c, keep=()):
        """A 1 px [c] rim round every opaque pixel inside box (x0, y0, x1, y1), on clear pixels only."""
        x0, y0, x1, y1 = box
        solid = {(x, y) for y in range(y0, y1) for x in range(x0, x1)
                 if self.get(x, y)[3] and self.get(x, y) not in keep}
        for x, y in solid:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) not in solid and x0 <= nx < x1 and y0 <= ny < y1 and not self.get(nx, ny)[3]:
                    self.put(nx, ny, c)


def hue_of(name):
    return zlib.crc32(name.encode()) % 360 / 360


def hsl(h, s, l, a=255):
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return round(r * 255), round(g * 255), round(b * 255), a


def lighter(c, k):
    return tuple(round(v + (255 - v) * k) for v in c[:3]) + (c[3],)


def darker(c, k):
    return tuple(round(v * (1 - k)) for v in c[:3]) + (c[3],)


def faded(c, a):
    return c[:3] + (max(1, min(255, round(a))),)


# --- characters -------------------------------------------------------------------------------------------------


def figure(img, ox, feet, body, pose, t, f):
    """One frame's figure at frame x [ox], the feet's bottom row on feet[1]; [pose] is the strip's animation."""
    fx, fy = feet
    cx, clip = ox + fx, (ox, 0, ox + img.h, img.h)
    head, dark, light = lighter(body, .35), darker(body, .35), lighter(body, .6)
    if pose == "death":
        # Falls back and lies down: the figure tips over towards its back, then flat on the ground.
        lean = min(1, t * 1.4)
        tall, wide = round(22 - 17 * lean), round(10 + 12 * lean)
        img.rect(cx - wide // 2 - 3 * lean, fy - tall + 1, cx + wide // 2 - 3 * lean, fy, body, clip)
        hx = cx - wide // 2 - 3 * lean - 1 if lean > .6 else cx
        img.ellipse(hx, fy - tall - 3 + (3 if lean > .6 else 0), 4, 4, head, clip)
        return
    bob = -1 if pose in ("idle", "walk") and f % 2 else 0
    back = -2 if pose == "hurt" else 0  # knocked back
    if pose == "hurt" and f % 2 == 0:
        body, head = lighter(body, .55), lighter(head, .55)
    step = (-2, 0, 2, 0)[f % 4] if pose == "walk" else 0
    x = cx + back
    img.rect(x - 4 + step, fy - 3, x - 2 + step, fy, dark, clip)  # legs
    img.rect(x + 2 - step, fy - 3, x + 4 - step, fy, dark, clip)
    img.rect(x - 5, fy - 13 + bob, x + 5, fy - 4 + bob, body, clip)  # torso
    img.ellipse(x, fy - 18 + bob, 4.5, 4.5, head, clip)  # head
    img.rect(x + 2, fy - 19 + bob, x + 3, fy - 18 + bob, light, clip)  # the eye: it faces right
    if pose in ("attack", "attack2", "attack3"):  # the skill strips' (attack 2 / 3, decisions-log 299) thrust the same
        reach = round(2 + 9 * math.sin(math.pi * t))
        img.rect(x + 6, fy - 10, x + 6 + reach, fy - 9, light, clip)
        img.rect(x + 6 + reach, fy - 12, x + 7 + reach, fy - 7, light, clip)
    elif pose == "block":  # the arm raised in front, a guard
        img.rect(x + 6, fy - 15, x + 8, fy - 6, light, clip)
    elif pose == "summon":
        lift = round(4 * math.sin(math.pi * t))
        img.rect(x - 7, fy - 17 - lift, x - 6, fy - 10, light, clip)  # arms raised
        img.rect(x + 6, fy - 17 - lift, x + 7, fy - 10, light, clip)
        for hx in (x - 7, x + 7):  # a glow over each hand
            img.ellipse(hx, fy - 20 - lift, 1 + 2 * t, 1 + 2 * t, faded(light, 255 * (1 - .5 * t)), clip)
    else:
        img.rect(x + 6, fy - 11 + bob, x + 7, fy - 7 + bob, dark, clip)  # the arm in front


def character(e):
    w, h, (fw, _), n = e["width"], e["height"], e["frame"], e["frames"]
    name = Path(e["path"]).stem  # tiny_<who>_<anim>
    who, pose = name[len("tiny_"):].rsplit("_", 1)
    img, feet = Img(w, h), e["feet"]
    body = hsl(hue_of(who), .55, .45)
    for f in range(n):
        ox = f * fw
        if e.get("baked_shadow"):
            shadow(img, ox, feet)
        figure(img, ox, feet, body, pose, f / max(1, n - 1), f)
        img.outline((ox, 0, ox + fw, feet[1] + 1), INK, keep=(SHADOW,))  # none below the feet
    return img


def shadow(img, ox, feet):
    """The ground shadow, rows feet-4 .. feet (55-59)."""
    img.ellipse(ox + feet[0], feet[1] - 2, 9, 2.5, SHADOW)


def shadow_file(e):
    img = Img(e["width"], e["height"])
    for f in range(e["frames"]):
        shadow(img, f * e["frame"][0], e["feet"])
    return img


def arrow(e):
    w, h = e["width"], e["height"]
    img, y = Img(w, h), h // 2
    shaft, tip = hsl(hue_of(e["path"]), .45, .4), (200, 205, 215, 255)
    img.rect(w * .2, y - 1, w * .75, y, shaft)
    for i in range(5):  # the head, pointing right
        img.rect(w * .75 + i, y - 3 + i * .6, w * .75 + i, y + 2 - i * .6, tip)
    img.rect(w * .12, y - 3, w * .22, y - 2, (236, 236, 230, 255))  # the fletching
    img.rect(w * .12, y + 1, w * .22, y + 2, (236, 236, 230, 255))
    img.outline((0, 0, w, h), INK)
    return img


# --- effects ----------------------------------------------------------------------------------------------------


def burst(e):
    w, h, (fs, _), n = e["width"], e["height"], e["frame"], e["frames"]
    name = Path(e["path"]).stem
    img = Img(w, h)
    colour = {"tiny_fx_heal": (110, 220, 120, 255), "tiny_fx_summon": (170, 110, 230, 255),
              "tiny_fx_wizard_fireball": (240, 140, 60, 255), "tiny_fx_wizard_shards": (70, 150, 230, 255),
              "fx_upgrade": (250, 210, 80, 255)}.get(name) or hsl(hue_of(name), .75, .6)
    on_feet = name.startswith("tiny_fx_")
    for f in range(n):
        t, ox = (f + 1) / n, f * fs
        clip = (ox, 0, ox + fs, h)
        c = faded(colour, 255 * (1 - .65 * t))
        if name == "tiny_fx_summon":  # a circle on the ground at the feet
            img.ring(ox + 50, 58, 6 + 18 * t, 2 + 5 * t, 1.5, c, clip)
            continue
        cx, cy = (ox + 50, 46) if on_feet else (ox + fs / 2, fs / 2)
        r = (8 + 10 * t) if on_feet else fs * (.12 + .3 * t)
        img.ring(cx, cy, r, r, max(1, fs / 20), c, clip)
        for k in range(6):  # sparks, turning
            a = k * math.pi / 3 + f * .4
            for d in range(max(1, round(fs / 16))):
                img.put(round(cx + math.cos(a) * (r + 2 + d)), round(cy + math.sin(a) * (r + 2 + d)), c, clip)
    return img


# --- the loot icons ----------------------------------------------------------------------------------------------


def icon(e):
    """tool/draw_icons.py's 16 px drawing of it, scaled to the file's size; else a round token of its hue; a sheet of
    icons (artifact_icons.png) a token a cell, each its own colour."""
    w, h = e["width"], e["height"]
    if e.get("frames", 1) > 1:
        img, (cw, ch) = Img(w, h), e["frame"]
        for i, (y0, x0) in enumerate((y, x) for y in range(0, h, ch) for x in range(0, w, cw)):
            c = hsl(i * .618 % 1, .6, .55)
            img.ellipse(x0 + (cw - 1) / 2, y0 + (ch - 1) / 2, cw * .34, ch * .34, c)
            img.ellipse(x0 + (cw - 1) / 2 - cw * .1, y0 + (ch - 1) / 2 - ch * .1, cw * .08, ch * .08, lighter(c, .5))
            img.outline((x0, y0, x0 + cw, y0 + ch), INK)
        return img
    img, art = Img(w, h), DRAWN.get(Path(e["path"]).stem)
    if art:
        for y in range(h):
            for x in range(w):
                img.put(x, y, DRAWN_INK[art[y * 16 // h][x * 16 // w]])
        return img
    c = hsl(hue_of(e["path"]), .6, .55)
    img.ellipse((w - 1) / 2, (h - 1) / 2, w * .34, h * .34, c)
    img.ellipse((w - 1) / 2 - w * .1, (h - 1) / 2 - h * .1, w * .08, h * .08, lighter(c, .5))
    img.outline((0, 0, w, h), INK)
    return img


# --- the UI sheets ----------------------------------------------------------------------------------------------


def panel(img, x0, y0, x1, y1, fill, rim=INK):
    img.rect(x0, y0, x1, y1, rim)
    img.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, fill)


def ui(e):
    w, h, name = e["width"], e["height"], Path(e["path"]).name
    cell = e.get("frame")
    if name == "ui_buttons.png":
        img = Img(w, h)
        cw, ch = cell
        for y0 in range(0, h, ch):
            base = BUTTONS[min(len(BUTTONS) - 1, y0 // 48)] + (255,)
            for col, x0 in enumerate(range(0, w, cw)):
                fill = (base, lighter(base, .25), darker(base, .2))[col % 3]
                panel(img, x0, y0, x0 + cw - 1, y0 + ch - 1, fill)
                img.rect(x0 + 2, y0 + 1, x0 + cw - 3, y0 + 1, lighter(fill, .4))
        return img
    if name == "ui_icons.png":  # a round icon per 16x16 cell, each its own colour
        img = Img(w, h)
        cw, ch = cell
        for i, (y0, x0) in enumerate((y, x) for y in range(0, h, ch) for x in range(0, w, cw)):
            c = hsl(i * .618 % 1, .6, .55)
            img.ellipse(x0 + cw / 2 - .5, y0 + ch / 2 - .5, cw / 2 - 2, ch / 2 - 2, c)
            img.outline((x0, y0, x0 + cw, y0 + ch), INK)
        return img
    if name == "ui_click.png":  # sparks flying out
        img = Img(w, h)
        for f in range(w // cell[0]):
            for k in range(4):
                a, d = k * math.pi / 2 + math.pi / 4, 2 + 2 * f
                img.put(round(f * 16 + 7.5 + math.cos(a) * d), round(7.5 + math.sin(a) * d), (255, 240, 170, 255))
        return img
    if name == "ui_loading.png":  # a dial: eight dots, one lit, turning frame by frame
        img = Img(w, h)
        cw, ch = cell
        for y0 in range(0, h, ch):
            for f, x0 in enumerate(range(0, w, cw)):
                for k in range(8):
                    a = k * math.pi / 4 - math.pi / 2
                    lit = k == f % 8
                    img.rect(x0 + 7 + round(math.cos(a) * 5), y0 + 7 + round(math.sin(a) * 5),
                             x0 + 8 + round(math.cos(a) * 5), y0 + 8 + round(math.sin(a) * 5),
                             (255, 230, 140, 255) if lit else (120, 110, 90, 255))
        return img
    if name == "ui_bars.png":
        img = Img(w, h)
        for y in range(h):
            img.rect(0, y, w - 1, y, BARS[y // 8 % len(BARS)] + (255,))
        return img
    if name == "ui_book_marks.png":  # tabs and ribbons in colour columns
        img = Img(w, h)
        for i, x0 in enumerate(range(0, w, 16)):
            img.rect(x0, 0, min(w, x0 + 16) - 1, h - 1, hsl(i * .618 % 1, .45, .6))
        return img
    if name == "ui_book.png":  # covers round parchment pages, the spine in the middle
        img = Img(w, h, BROWN)
        img.rect(4, 4, w - 5, h - 5, PAPER)
        img.rect(w // 2 - 2, 0, w // 2 + 1, h - 1, BROWN)
        return img
    if name == "ui_ribbons.png":
        return Img(w, h, (190, 80, 70, 255))
    img = Img(w, h, PAPER)  # ui_all, ui_tooltip and any other sheet: plain parchment with a rim
    if name == "ui_tooltip.png":
        panel(img, 0, 0, w - 1, h - 1, PAPER, BROWN)
    return img


# --- hills and rows, shared by the scenes ----------------------------------------------------------------------------------------------


def hills(w, top, depth, seed):
    """A hill line per column, between rows top and top + depth; it repeats every w columns."""
    waves = [(k, (seed * 7 + k * 13) % 10 / 10 * math.tau) for k in (1, 2, 3, 5)]
    return [top + depth * (.5 + sum(math.sin(math.tau * k * x / w + p) / (k + 1) for k, p in waves) / 2.2)
            for x in range(w)]


def rows_from(w, h, colour_at):
    """An image from colour_at(x, y) -> RGBA bytes."""
    img = Img(w, h)
    img.px = bytearray(b"".join(colour_at(x, y) for y in range(h) for x in range(w)))
    return img


# --- the Town scene ------------------------------------------------------------------------------------------------

STONE, WOOD, FIRE, CANVAS = (128, 128, 136, 255), (126, 84, 50, 255), (250, 150, 40, 255), (236, 226, 200, 255)


def pines(img, w, h, top, base, spacing, colour, seed, slope=2.2):
    """A row of pine triangles, peaks round row [top], solid from row [base] down, [slope] rows down a column out;
    repeats every w columns."""
    n = max(1, round(w / spacing))
    step = w / n
    for x in range(w):
        edge = base
        for k in range(-1, n + 1):
            cx = (k + .5) * step
            peak = top + (seed * 7 + k * 13) % 5 * h * .02
            edge = min(edge, peak + abs(x - cx) * slope)
        img.rect(x, max(0, edge), x, h - 1, colour)


def town(e):
    # The Towns' seasons (town_autumn_bg_1, town_winter_castle, town_ground_autumn ...) are drawn as the Normal set's.
    w, h, name = e["width"], e["height"], re.sub(r"_(autumn|winter)", "", Path(e["path"]).stem)
    img = Img(w, h)
    if name == "town_bg_5":  # the sky, opaque
        for y in range(h):
            img.rect(0, y, w - 1, y, lighter((110, 170, 215, 255), y / h * .6))
    elif name == "town_bg_4":  # far mountains
        line = hills(w, h * .35, h * .3, 4)
        for x in range(w):
            img.rect(x, line[x], x, h - 1, (150, 165, 190, 255))
    elif name == "town_castle":  # a castle on its hill
        cx, base = w * .55, h * .62
        img.ellipse(cx, base + h * .1, w * .09, h * .12, (140, 155, 180, 255))
        for dx, tall in ((-30, .22), (-12, .3), (6, .36), (24, .26)):
            img.rect(cx + dx, base - h * tall, cx + dx + 12, base, (150, 160, 185, 255))
            for c in range(0, 12, 4):
                img.rect(cx + dx + c, base - h * tall - 3, cx + dx + c + 1, base - h * tall, (150, 160, 185, 255))
    elif name in ("town_bg_3", "town_bg_2"):  # far and middle pines
        far = name == "town_bg_3"
        pines(img, w, h, h * (.42 if far else .38), h * (.7 if far else .65), 40 if far else 56,
              (120, 160, 130, 255) if far else (70, 120, 80, 255), 3 if far else 2)
    elif name == "town_bg_1":  # near pines and the ground (the street lies on its band)
        pines(img, w, h, h * .25, h - 95, 128, (40, 80, 50, 255), 1, 4)
        img.rect(0, h - 95, w - 1, h - 1, (52, 62, 40, 255))
        img.rect(0, h - 95, w - 1, h - 92, (80, 130, 60, 255))
    elif name == "town_ground":  # the street: a green top with blades hanging into dark earth, tiling along x
        img.rect(0, 0, w - 1, h - 1, (19, 17, 22, 255))
        img.rect(0, 0, w - 1, 5, (110, 145, 60, 255))
        for x in range(0, w, 2):
            img.rect(x, 6, x, 6 + x * 5 % 7, (60, 70, 35, 255))
    elif name == "town_house":  # a brick per cell, a little lighter or darker by its place
        cw, ch = e["frame"]
        for i, (y0, x0) in enumerate((y, x) for y in range(0, h, ch) for x in range(0, w, cw)):
            brick = lighter((150, 110, 90, 255), i % 5 * .06)
            img.rect(x0, y0, x0 + cw - 1, y0 + ch - 1, brick)
            for y in range(y0 + 3, y0 + ch, 4):  # mortar
                img.rect(x0, y, x0 + cw - 1, y, darker(brick, .3))
    elif name == "town_smithy":  # row 0 a furnace, row 1 a sawmill; the fire and the saw move frame by frame
        fs = e["frame"][0]
        for f in range(e["frames"]):
            x0, y0, t = f % (w // fs) * fs, f // (w // fs) * fs, f % (w // fs)
            if y0 == 0:
                img.ellipse(x0 + fs / 2, y0 + fs * .55, fs * .3, fs * .4, STONE)
                img.rect(x0 + fs * .2, y0 + fs * .55, x0 + fs * .8, y0 + fs - 1, STONE)
                img.ellipse(x0 + fs / 2, y0 + fs * .75, fs * .1 + t % 3, fs * .1 + t % 2, FIRE)
            else:
                img.rect(x0 + 4, y0 + fs * .6, x0 + fs - 5, y0 + fs * .68, WOOD)
                img.rect(x0 + 8, y0 + fs * .68, x0 + 11, y0 + fs - 1, WOOD)
                img.rect(x0 + fs - 12, y0 + fs * .68, x0 + fs - 9, y0 + fs - 1, WOOD)
                img.ellipse(x0 + fs * .3 + t * 3, y0 + fs * .52, 4, 4, (200, 205, 215, 255))
            img.outline((x0, y0, x0 + fs, y0 + fs), INK)
    elif name == "town_campfire":  # a pot over a fire, the flame flickering frame by frame
        fs = e["frame"][0]
        for f in range(e["frames"]):
            x0, y0 = f % (w // fs) * fs, f // (w // fs) * fs
            img.rect(x0 + 6, y0 + 8, x0 + fs - 7, y0 + 9, (50, 50, 56, 255))
            img.ellipse(x0 + fs / 2, y0 + 15, 6, 5, (40, 40, 46, 255))
            img.ellipse(x0 + fs / 2, y0 + fs - 6, 4 + f % 3, 3 + f % 2, FIRE)
            img.outline((x0, y0, x0 + fs, y0 + fs), INK)
    elif name == "town_tent":
        for y in range(h):
            half = w / 2 * min(1, .15 + y / h)
            img.rect(w / 2 - half, y, w / 2 + half - 1, y, CANVAS)
        img.rect(w * .38, h * .55, w * .62, h - 1, WOOD)
        img.outline((0, 0, w, h), INK)
    elif name == "town_ore":
        img.ellipse(w / 2, h * .6, w * .45, h * .4, STONE)
        for k in range(5):
            img.ellipse(w * (.25 + k * .12), h * (.45 + k % 2 * .2), 2, 3, (110, 200, 240, 255))
        img.outline((0, 0, w, h), INK)
    elif name == "town_pine":
        img.rect(w / 2 - 3, h * .45, w / 2 + 2, h - 1, WOOD)
        for k in range(2):  # the cone and one tier over a tall trunk, as the pine
            top, base = h * (.02 + k * .5), h * (.5 + k * .25)
            for y in range(round(top), round(base)):
                half = (y - top) / (base - top) * w * (.33 + k * .16)
                img.rect(w / 2 - half, y, w / 2 + half, y, (60, 120, 60, 255))
        img.outline((0, 0, w, h), INK)
    else:  # an atlas of props: a crate in each cell
        for x0, y0, cw, ch in e.get("cells", [[0, 0, w, h]]):
            img.rect(x0, y0, x0 + cw - 1, y0 + ch - 1, WOOD)
            img.rect(x0 + 1, y0 + ch // 2, x0 + cw - 2, y0 + ch // 2, darker(WOOD, .35))
            img.outline((x0, y0, x0 + cw, y0 + ch), INK)
            img.rect(x0, y0, x0 + cw - 1, y0, darker(WOOD, .5))
    return img


def npc(e):
    """The Town's smith: a figure facing right with a hammer, at an anvil on his right, the hammer back, up, forward,
    down on the anvil and lowered frame by frame (tool/import_smith.py's FRAMES); his feet on the bottom row."""
    w, h, (fw, fh), n = e["width"], e["height"], e["frame"], e["frames"]
    img, body = Img(w, h), hsl(hue_of("smith"), .5, .4)
    poses = [(-7, -14), (2, -22), (8, -18), (12, -10), (6, -4)]  # the hammer's head from the hand, per frame
    for f in range(n):
        ox, clip = f * fw, (f * fw, 0, (f + 1) * fw, fh)
        fx, fy = round(fw * .36), fh - 1
        figure(img, ox, (fx, fy), body, "idle", 0, 0)
        ax = ox + fx + 9  # the anvil: a horn, a face and a foot, standing on the feet's row
        img.rect(ax + 4, fy - 4, ax + 10, fy, STONE, clip)
        img.rect(ax, fy - 10, ax + 16, fy - 5, STONE, clip)
        img.rect(ax - 4, fy - 9, ax, fy - 7, STONE, clip)
        hx, hy = ox + fx + 6, fy - 11  # the hand
        dx, dy = poses[f % len(poses)]
        for k in range(9):  # the handle, from the hand to the head
            img.put(round(hx + dx * k / 8), round(hy + dy * k / 8 / 2), WOOD, clip)
        img.rect(hx + dx - 2, hy + dy // 2 - 2, hx + dx + 2, hy + dy // 2 + 1, (200, 205, 215, 255), clip)
        img.outline((ox, 0, ox + fw, fh), INK)
    return img


def floor(e):
    """The battle's floor (battle_floor): clear over the horizon (its row 40 of 786) but for a ground line of small red
    and green tufts and the first rows' blade tips, a meadow in rows of a darker and a lighter green from the horizon,
    a grass top over earth along its last 16 rows (the field's front edge, decisions-log 263, 287); the same every 32
    columns, so it tiles."""
    w, h = e["width"], e["height"]
    img = Img(w, h)
    opaque, front = round(h * 40 / 786), h - round(h * 16 / 786)
    for y in range(opaque, front, 6):
        img.rect(0, y, w - 1, min(front, y + 6) - 1, (118, 148, 61, 255) if y // 6 % 2 else (107, 120, 36, 255))
    for x in range(0, w, 3):  # the first rows' blade tips
        img.rect(x, opaque - 4, x, opaque - 1, (107, 120, 36, 255))
    for x in range(0, w, 32):  # the ground line: a flower tuft and a fern
        img.ellipse(x + 8, opaque - 3, 6, 4, (190, 60, 50, 255))
        img.ellipse(x + 22, opaque - 5, 5, 6, (70, 110, 40, 255))
    img.rect(0, front, w - 1, h - 1, (34, 31, 25, 255))
    img.rect(0, front, w - 1, front + 4, (118, 148, 61, 255))
    return img


def props(e):
    """The battle's props line (battle_props): trunks from the top down to the feet (two rows over the bottom),
    a broad tree's crown on a trunk, rocks and bushes at the feet, clear between them; it tiles."""
    w, h = e["width"], e["height"]
    img = Img(w, h)
    feet = h - 2
    for k, x in enumerate(range(w // 16, w, w // 5)):
        if k % 3 == 1:  # a broad tree
            img.rect(x - 8, feet - h // 3, x + 8, feet, (110, 72, 44, 255))
            img.ellipse(x, feet - h // 2, w // 20, h // 5, (60, 110, 40, 255))
        else:  # a trunk off the top
            img.rect(x - 18, 0, x + 18, feet, (92, 58, 36, 255))
            img.rect(x - 30, feet - 16, x + 30, feet, (92, 58, 36, 255))
        img.ellipse(x + w // 12, feet - 18, 40, 18, (128, 120, 110, 255))  # a boulder
        img.ellipse(x - w // 14, feet - 14, 30, 14, (80, 130, 50, 255))  # a bush
    return img


def clouds(e):
    """The battle's clouds (battle_clouds): white puffs of a few sizes at a few heights over a clear strip; it tiles."""
    w, h = e["width"], e["height"]
    img = Img(w, h)
    for k, x in enumerate(range(w // 24, w, w // 12)):
        r = (12, 24, 40, 18)[k % 4]
        cy = (h // 5, h // 2, h // 3, h // 6)[k % 4] + r // 2
        img.ellipse(x, cy, r * 2, r // 2 + 4, (214, 230, 240, 255))
        img.ellipse(x - r // 2, cy - r // 3, r, r // 2 + 2, (250, 250, 250, 255))
    return img


def step(e):
    """The spawn bar's step (battle_step, decisions-log 287, 295): a strip of ground, a little hill: 32 columns of low
    ground (its grass 60 rows under the top), a slope up over 96, 96 of the step's top, a slope down over 96 and low
    ground again; a grass band along its top, earth under it to the bottom."""
    w, h = e["width"], e["height"]
    img = Img(w, h)
    earth, grass = (34, 31, 25, 255), (118, 148, 61, 255)
    for x in range(w):
        t = min(max(x - 32, 0), 96) if x < w // 2 else min(max(w - 33 - x, 0), 96)  # how far up the slope it is
        top = 60 - t * 60 // 96
        img.rect(x, top, x, h - 1, earth)
        img.rect(x, top, x, min(top + 4, h - 1), grass)
    return img


DRAW = {"character": character, "shadow": shadow_file, "arrow": arrow, "burst": burst, "ui": ui,
        "icon": icon, "town": town, "npc": npc, "floor": floor, "props": props, "clouds": clouds, "step": step}


# --- writing ----------------------------------------------------------------------------------------------------


def tracked(paths):
    """The paths git tracks, each asked in the repo of its own real folder (so a symlink can't hide the private
    repo's assets/). A folder in no repo tracks nothing."""
    out, by_dir = [], {}
    for p in paths:
        real = p.resolve()
        by_dir.setdefault(real.parent, []).append((p, real))
    for folder, items in by_dir.items():
        probe = folder
        while not probe.exists():
            probe = probe.parent
        r = subprocess.run(["git", "-C", str(probe), "rev-parse", "--show-toplevel"], capture_output=True, text=True)
        if r.returncode != 0:
            continue  # not in a git repo
        top = Path(r.stdout.strip()).resolve()
        rels = [real.relative_to(top).as_posix() for _, real in items]
        r = subprocess.run(["git", "-C", str(top), "ls-files", "--", *rels], capture_output=True, text=True, check=True)
        known = set(r.stdout.split("\n"))
        out += [p for (p, real), rel in zip(items, rels) if rel in known]
    return out


MARKER = "assets/.placeholders"  # tool/asset_vault.py reads it: {repo path: sha256} of every placeholder drawn


def sha256(b):
    return hashlib.sha256(b).hexdigest()


def icon_placeholders():
    """{repo path: bytes} of the platform icons' placeholder, drawn by tool/make_app_icon.py --placeholder in a temp
    folder (it reads no file)."""
    with tempfile.TemporaryDirectory(prefix="poh-icons-") as tmp:
        subprocess.run([sys.executable, str(Path(__file__).with_name("make_app_icon.py")), "--placeholder", "--out",
                        tmp], check=True, capture_output=True, stdin=subprocess.DEVNULL)
        base = Path(tmp)
        return {p.relative_to(base).as_posix(): p.read_bytes() for p in sorted(base.rglob("*")) if p.is_file()}


def main(args):
    out, dry, icons = ROOT, False, True
    while args:
        if args[0] == "--out" and len(args) > 1:
            out, args = Path(args[1]), args[2:]
        elif args[0] == "--dry-run":
            dry, args = True, args[1:]
        elif args[0] == "--no-icons":
            icons, args = False, args[1:]
        else:
            sys.exit(__doc__)
    manifest = json.loads(MANIFEST.read_text())
    todo = manifest["files"]
    undrawn = sorted({e["kind"] for e in todo} - DRAW.keys())
    if undrawn:
        sys.exit(f"no placeholder for the kind {', '.join(undrawn)}: add its drawer to DRAW")
    icon_files = icon_placeholders() if icons else {}
    targets = [out / e["path"] for e in todo] + [out / p for p in icon_files]
    try:
        real = tracked(targets)
    except (OSError, subprocess.CalledProcessError) as err:
        sys.exit(f"refused: can't ask git which files it tracks ({err})")
    if real:
        sys.exit(f"refused: git tracks {len(real)} of these files, e.g. {real[0]}: this is the private repo's real "
                 "art, never overwritten. Write the placeholders elsewhere: --out <dir>")
    try:
        drawn = json.loads((out / MARKER).read_text())
    except (OSError, ValueError):
        drawn = {}
    rel = {t: t.relative_to(out).as_posix() for t in targets}
    there = [t for t in targets if t.is_file() and drawn.get(rel[t]) != sha256(t.read_bytes())]
    if there:
        sys.exit(f"refused: {len(there)} of these files are already there and aren't placeholders drawn here, e.g. "
                 f"{there[0]}: the real art (from the asset vault), never overwritten. To go back to placeholders, "
                 "delete those files first")
    for e, target in zip(todo, targets):
        if dry:
            print("would write", target)
            continue
        img = DRAW[e["kind"]](e)
        assert (img.w, img.h) == (e["width"], e["height"]), e["path"]
        write_png(target, img.w, img.h, img.px)
        drawn[rel[target]] = sha256(target.read_bytes())
    for path, data in icon_files.items():
        target = out / path
        if dry:
            print("would write", target)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        drawn[path] = sha256(data)
    if not dry:
        (out / MARKER).parent.mkdir(parents=True, exist_ok=True)
        (out / MARKER).write_text(json.dumps(drawn, indent=1, sort_keys=True) + "\n")
    print(len(todo), "placeholders and", len(icon_files), "placeholder icons",
          "checked (dry run)" if dry else f"written under {out} (listed in {MARKER})")


if __name__ == "__main__":
    main(sys.argv[1:])
