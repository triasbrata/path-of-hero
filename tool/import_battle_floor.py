"""Builds the battle's backdrop pictures (decisions-log 228, 244; docs/camera-and-field.md "Backdrop") from
GandalfHardcore's FREE Platformer Assets only (the owner, 2026-10-04: option B, "murni Gandalf"), unpacked in the main
checkout's raw_sprites/gandalfhardcore-platformer/: never raw_assets/, never another pack.

- assets/images/battle_floor.png: the field's floor, the lanes' meadow from the horizon down with a ground line of
  flower tufts, ferns and rocks along its top and a grass top over dark earth along the front, under the field's bottom
  (decisions-log 263).
- assets/images/battle_props.png: the props line at the horizon (the owner, 2026-10-04: no "grass fence" between the
  ground and the parallax, "pakai asset pohon atau batu", his forest example): Pine forest sheet's big trunks, its pine
  and a log, Tree1 and Tree2, Decor's boulders, rocks, bushes and ferns, standing in front of the parallax pines.
- assets/images/battle_clouds.png: cloud1..cloud6 scattered over a strip of sky.
- assets/images/battle_step.png: the spawn bar's step (decisions-log 287, 295): one strip of ground, a little hill
  ___/top\\___ (lib/spawn_bar.dart cuts its pieces from it), every column Floor Tiles1's grass-topped cell's (32, 0)
  column, lowered to the hill's height there, the cell's earth under it.

All at the parallax layers' scale (5 px a world unit: lib/main.dart `_layerK`), each tiled sideways. A y below is in
band units: 0 the band's top (the screen's), HORIZON = 64 the field's top, 192 its bottom. The parallax layers' row 0
is at band y BAND_TOP (lib/main.dart `_bandTop`), so layer 1's pines' feet (its rows 230-263) stand round the horizon.
Every sheet was mapped first (tool/sprite_map.py; the numbered maps in the shots), and every piece is cut from that
map at its exact box (cut() refuses a box that slices a neighbour). Pieces marked 2 in PIECES are doubled, each pixel
2x2 (the props line and its ground stand nearer than the layers: at 1x a trunk is a pole a fifth of a knight wide);
Tree1 and Tree2, 255 px wide, stay 1x, the size of trees a little further back.

- The floor (1024x746, row 0 at band y FLOOR_TOP, its last FOOT under the field's bottom): Tall Grass.png's strip of
  blades (0, 12, 96x20), in rows STEP px apart, each row lower over the one above it, from GRASS_FROM on (opaque from
  the horizon, OPAQUE_FROM, checked; above it the first rows' blade tips). A row is COPIES of the strip side by side, overlapping (its ends taper),
  shifted sideways by a fixed LCG (lcg(); a regular shift lines the blades up in diagonal streaks) and wrapping at the
  picture's edges. Its colours step through RAMP over the first rows (RAMP_IN: the forest's edge a little darker),
  then stay one step lighter than the pack draws them (LIGHT): the lanes' meadow. RAMP is the pack's grass greens,
  Tall Grass's and Floor Tiles' grass tops', darkest first. The ground line (GROUND, doubled): the flower tufts,
  ferns, small bushes and rocks side by side along the horizon, their feet planted between the grass rows (the rows
  after them cover their bottoms), so the props line's feet, which move at another parallax factor, never show.
  The meadow's pebbles: Decor's small rocks and mossy rocks, a few small bushes and ferns (MEADOW, 1x, a fixed LCG,
  none overlapping, above the field's last rows). The front edge: Floor Tiles1.png's grass top over its brown-black
  earth, the solid block's top middle cell (32, 0, 32x32), its first EDGE_ROWS rows (the grass top, the roots, a few
  rows of earth) side by side along the picture's last rows, its top (the grass lip) at field y LIP: under the field's
  bottom, below the lowest a unit's shadow reaches by at least 10 screen px at every size (decisions-log 263). The
  game frames the scene FOOT world units higher (lib/main.dart fieldFoot), so the screen shows it.
- The props line (2048x330, row 0 at band y 0, the screen's top): PROPS, back to front, each standing on PROPS_FEET
  (band y 65.6, under the meadow's opaque grass), so the trunks run up off the top of the screen as in the example.
- The clouds (3072x130, row 0 at band y 0): CLOUDS, each at its own height; the parallax layers' mountains and pines
  hide their lower parts.

Every pixel is a pack pixel (or, in the meadow, a pack colour put in its place); nothing is drawn.

Stdlib only:  python3 tool/import_battle_floor.py [--pack DIR] [--check]
(--pack: the unpacked pack, by default raw_sprites/gandalfhardcore-platformer in this checkout or the main one;
--check writes nothing and exits 1 while any of the three pictures differs from what it would write)
"""
import math
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from build_atlas import read_png, write_png  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
PACK = "raw_sprites/gandalfhardcore-platformer"
FLOOR, PROPS_OUT, CLOUDS_OUT, STEP_OUT = (ROOT / f"assets/images/battle_{n}.png" for n in ("floor", "props", "clouds", "step"))

PX = 5  # px a world unit
HORIZON = 64  # band y of the field's top (lib/main.dart backdropH): the meadow is opaque from here down
BAND_TOP = 14  # band y of the parallax layers' row 0 (lib/main.dart _bandTop): layer 1's pines' feet at 60-66.6

FLOOR_TOP = 56  # band y of its row 0 (lib/main.dart _floorTop): room for the ground line over the horizon
FIELD_END = (HORIZON + 128 - FLOOR_TOP) * PX  # its row at the field's bottom (band y 192, lib/game.dart fieldH 128)
# The front edge's top, the grass lip, in field y (lib/main.dart frontLip): a unit stands at y 126 at the lowest
# (lib/game.dart's clamp, fieldH - 2), its feet 5 under that and its shadow's last row 1 more (field y 132); the lip 6
# under it is 11 screen px or more at every size the game is checked at (a phone in portrait, 1.88 px a unit, the least).
LIP = 146
EDGE_ROWS = 16  # of the edge's cell: its grass top (rows 0-4), the roots (5-11) and 4 rows of earth
W, H = 1024, (HORIZON + LIP - FLOOR_TOP) * PX + EDGE_ROWS  # the floor: one repeat, from band y FLOOR_TOP to its edge's last row
FOOT = H / PX - (HORIZON + 128 - FLOOR_TOP)  # world units of it under the field's bottom (lib/main.dart fieldFoot, 13.2)
OPAQUE_FROM = (HORIZON - FLOOR_TOP) * PX  # every pixel from this row down is opaque (checked)
GRASS_FROM = OPAQUE_FROM - 24  # the first row of blades: four rows of tips over the horizon
STEP = 6  # between two rows of grass
COPIES = 13  # of the strip a row, 78-79 px apart: each copy's opaque body (columns 7-89) covers its neighbours' tapered ends
BLADES = ("Tall Grass.png", 0, 12, 96, 20)  # the strip's sprite (sprite_map: one island, its exact box)
EDGE = ("Floor Tiles1.png", 32, 0, 32, 32)  # the solid block's top middle cell: grass top over earth
# The step under the spawn bar (lib/spawn_bar.dart; decisions-log 287, 295; the owner, 2026-10-09: "bagian sininya
# sambungannya tidak seamless"). The pack has no diagonal ground tile (its only slope, Other Tiles1's rock pile, leans on
# a sheer cliff), so the slopes are built from EDGE: a strip STEP_W x STEP_H of ground, from the left: STEP_FLAT columns
# of low ground, the slope up "/" (STEP_RUN), STEP_TOP columns of the step's top, the slope down "\" and low ground
# again. Each column is EDGE's column x % 32 (every piece starts on a multiple of 32, so the grass runs on unbroken from
# piece to piece) lowered to the ground's height there: the top at 0, the low ground STEP_DROP under it (the floor's
# lip, frontLip 146, under the step's top, stepLip 134), and on a slope a half cosine between the two (its shoulders
# round, about 45 degrees in its middle); EDGE's earth to the strip's bottom. Every neighbour of a piece in the strip is
# the ground that goes on from it, so the smoothed paint that draws the step reads no wrong pixel at a piece's edge.
STEP_LIP = 134  # field y (lib/spawn_bar.dart stepLip)
STEP_DROP = (LIP - STEP_LIP) * PX  # 60
STEP_RUN, STEP_FLAT, STEP_TOP = 96, 32, 96
STEP_H = STEP_DROP + EDGE_ROWS  # 76: the low ground's grass and roots, then earth
STEP_W = 2 * STEP_FLAT + 2 * STEP_RUN + STEP_TOP

# The pack's grass greens, darkest first: Tall Grass's and Floor Tiles' grass tops' (where both have one, it is one).
RAMP = [(62, 66, 34), (72, 82, 28), (73, 97, 29), (95, 101, 52), (107, 120, 36), (123, 127, 59), (118, 148, 61),
        (150, 145, 50), (148, 160, 53), (166, 181, 83)]
LIGHT = 1  # the meadow: each colour this many RAMP steps lighter
RAMP_IN = [-3, -2, -1, 0]  # the first rows of blades: RAMP steps, then LIGHT

# Every piece: (sheet, x, y, w, h, scale), its exact box on the sheet's map (tool/sprite_map.py, the shots'
# map-1 .. map-5): Pine forest sheet.png's sprites 0-2 (the trunks), 4-6 (the flower tufts), 7 (the pine) and 8's
# lower log (sprite 8 is two logs, one island: they touch at one corner, row 175 over row 176, so the lower one is its
# own rows 176-207, SPLIT; map-6); Tree1.png's and Tree2.png's one sprite each; Decor.png's sprites 52, 55, 63, 79, 82 (rocks), 86 (the boulders), 96-98 (bushes
# and the fern).
PIECES = {
    "trunk0": ("Pine forest sheet.png", 10, 0, 42, 208, 2), "trunk1": ("Pine forest sheet.png", 73, 0, 44, 208, 2),
    "trunk2": ("Pine forest sheet.png", 138, 0, 43, 208, 2), "pine": ("Pine forest sheet.png", 201, 38, 43, 90, 2),
    "tuft0": ("Pine forest sheet.png", 230, 23, 20, 9, 2), "tuft1": ("Pine forest sheet.png", 263, 24, 19, 8, 2),
    "tuft2": ("Pine forest sheet.png", 295, 24, 18, 8, 2),
    "log": ("Pine forest sheet.png", 196, 176, 88, 32, 2),
    "tree1": ("Tree1.png", 0, 7, 255, 201, 1), "tree2": ("Tree2.png", 0, 7, 255, 201, 1),
    "boulder": ("Decor.png", 4, 280, 88, 40, 2),
    "bush": ("Decor.png", 3, 424, 57, 24, 2), "bushSmall": ("Decor.png", 64, 431, 32, 17, 2),
    "fern": ("Decor.png", 98, 432, 28, 16, 2),
    "rocks": ("Decor.png", 35, 177, 26, 15, 2), "rocksLow": ("Decor.png", 66, 181, 26, 11, 2),
    "mossyRocks": ("Decor.png", 36, 237, 52, 19, 2), "mossyRocksSmall": ("Decor.png", 1, 241, 30, 15, 2),
    # The meadow's pebbles, 1x.
    "pebbles": ("Decor.png", 35, 177, 26, 15, 1), "pebblesLow": ("Decor.png", 66, 181, 26, 11, 1),
    "pebblesFlat": ("Decor.png", 41, 210, 46, 14, 1), "mossy": ("Decor.png", 36, 237, 52, 19, 1),
    "mossySmall": ("Decor.png", 1, 241, 30, 15, 1), "tuftBush": ("Decor.png", 64, 431, 32, 17, 1),
    "tuftFern": ("Decor.png", 98, 432, 28, 16, 1),
}
# The two logs' island splits between rows 175 and 176: the lower log's box meets the upper one over it.
SPLIT = {"log": "top"}

# The ground line: these in turn along the horizon, a gap of GROUND_GAP px or less between two (lcg), each one's feet
# GROUND_FEET px under the horizon or less, sunk between the grass rows.
GROUND = ["tuft0", "fern", "tuft1", "rocksLow", "tuft2", "tuft0", "bushSmall", "tuft1", "fern", "tuft2",
          "mossyRocksSmall", "tuft0", "tuft1", "rocks", "tuft2", "fern"]
GROUND_GAP, GROUND_FEET = 26, 9
# The meadow's pebbles: (pieces, how many, first row of their feet, last row of their feet). Decor's grass tufts
# (sprites 37, 38, 39, 58, 67) are left out: they are the grass's own colours, lost in it.
MEADOW = (["pebbles", "tuftBush", "pebblesLow", "mossy", "tuftFern", "pebblesFlat", "mossySmall", "pebbles"], 16,
          OPAQUE_FROM + 80, FIELD_END - 40)

PROPS_W, PROPS_H = 2048, (HORIZON + 2) * PX  # the props line: one repeat, from the band's top to under the horizon
PROPS_FEET = PROPS_H - 2  # where every prop stands: band y 65.6, 8 px under the meadow's opaque top
# Back to front: (piece, x of its box's left, mirrored). Varied, a few of each, with gaps where the parallax pines show.
PROPS = [
    ("tree1", 300, False), ("tree2", 1290, True), ("pine", 1010, False), ("pine", 1880, True), ("pine", 520, True),
    ("trunk0", 70, False), ("bush", 10, False), ("fern", 160, False),
    ("boulder", 420, False), ("rocks", 380, False),
    ("trunk1", 700, False), ("trunk2", 830, True), ("fern", 790, False), ("mossyRocksSmall", 905, False),
    ("bushSmall", 1080, False), ("log", 1150, False),
    ("boulder", 1440, True), ("bush", 1360, True),
    ("trunk2", 1640, False), ("fern", 1610, False), ("bushSmall", 1730, True),
    ("trunk0", 1960, True), ("rocksLow", 1915, False),
]

CLOUDS_W, CLOUDS_H = 3072, 130  # the clouds: one repeat, from the band's top down to band y 26
CLOUD = ("cloud1.png", "cloud2.png", "cloud3.png", "cloud4.png", "cloud5.png", "cloud6.png")  # one sprite each, 1x
# (cloud n, x, y of its top): the big ones low (the mountains and pines hide their feet), the small ones higher.
CLOUDS = [(6, 140, 26), (2, 520, 58), (4, 760, 20), (1, 1010, 74), (5, 1190, 44), (3, 1560, 14), (2, 1820, 66),
          (4, 2060, 38), (1, 2290, 18), (5, 2480, 56), (3, 2800, 30), (1, 2960, 82)]


def pack_dir(arg):
    if arg:
        return Path(arg)
    here = ROOT / PACK
    if here.is_dir():
        return here
    main = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--path-format=absolute", "--git-common-dir"],
                          capture_output=True, text=True, check=True).stdout.strip()
    return Path(main).parent / PACK


def cut(sheet, x, y, w, h, cell=False, split=None):
    """(w, h, rgba) of a box of [sheet]. A sprite's box must have a clear 1 px ring on the sheet (it slices no
    neighbour); a tileset's [cell] meets its neighbours by design, and a [split] island ("top"/"bottom") the other
    half of itself on that side."""
    sw, sh, px = sheet
    ring = [(i, j) for i in range(x - 1, x + w + 1) for j in (y - 1, y + h)] + \
        [(i, j) for j in range(y, y + h) for i in (x - 1, x + w)]
    for i, j in ring:
        if split == "top" and j == y - 1 or split == "bottom" and j == y + h:
            continue
        if not cell and 0 <= i < sw and 0 <= j < sh and px[(j * sw + i) * 4 + 3]:
            raise SystemExit(f"box {(x, y, w, h)} slices a neighbour at ({i}, {j})")
    out = bytearray()
    for j in range(h):
        out += px[((y + j) * sw + x) * 4:((y + j) * sw + x + w) * 4]
    return w, h, out


def doubled(piece, k):
    """[piece] with each pixel k x k."""
    w, h, px = piece
    if k == 1:
        return piece
    out = bytearray()
    for j in range(h):
        row = bytearray()
        for i in range(w):
            row += px[(j * w + i) * 4:(j * w + i) * 4 + 4] * k
        out += row * k
    return w * k, h * k, out


def mirrored(piece):
    w, h, px = piece
    out = bytearray()
    for j in range(h):
        for i in range(w - 1, -1, -1):
            out += px[(j * w + i) * 4:(j * w + i) * 4 + 4]
    return w, h, out


def recolour(piece, to):
    """[piece] with each opaque pixel's colour through [to] (a colour -> a colour)."""
    w, h, px = piece
    px = bytearray(px)
    for i in range(0, len(px), 4):
        if px[i + 3]:
            px[i:i + 3] = bytes(to(tuple(px[i:i + 3])))
    return w, h, px


def step(n):
    return lambda c: RAMP[max(0, min(len(RAMP) - 1, RAMP.index(c) + n))] if c in RAMP else c


def over(dst, dw, dh, piece, x, y):
    """[piece] over [dst] (dw x dh) at (x, y), wrapping sideways; only opaque pixels (the pack's alpha is 0 or 255)."""
    w, h, px = piece
    for j in range(h):
        if not 0 <= y + j < dh:
            continue
        for i in range(w):
            k = (j * w + i) * 4
            if px[k + 3]:
                d = ((y + j) * dw + (x + i) % dw) * 4
                dst[d:d + 4] = px[k:k + 4]


def lcg(seed):
    """A fixed sequence: rnd(m) is the next number in [0, m) (the same on every Python, unlike random's)."""
    s = seed

    def rnd(m):
        nonlocal s
        s = (s * 1103515245 + 12345) % 2 ** 31
        return (s >> 8) % m
    return rnd


class Pieces:
    """The pack's pieces, cut from their sheets as PIECES maps them, at their scale."""

    def __init__(self, pack):
        self.pack, self.sheets = pack, {}

    def sheet(self, name):
        if name not in self.sheets:
            self.sheets[name] = read_png(self.pack / name)
        return self.sheets[name]

    def __call__(self, name, mirror=False):
        sheet, x, y, w, h, k = PIECES[name]
        piece = doubled(cut(self.sheet(sheet), x, y, w, h, split=SPLIT.get(name)), k)
        return mirrored(piece) if mirror else piece


def place(pieces, piece, n, top, bottom, seed, taken):
    """[n] of [pieces] in turn, feet between rows [top] and [bottom], x from lcg(seed); no two overlap (with a 12 px
    margin, sideways wrapping), a try that would is moved on. [(name, x, feet row)]."""
    rnd, out = lcg(seed), []
    for k in range(n):
        name = pieces[k % len(pieces)]
        w, h = piece(name)[:2]
        for _ in range(200):
            x, feet = rnd(W), top + rnd(bottom - top)
            box = (x - 12, feet - h - 12, x + w + 12, feet + 12)
            if not any(box[1] < b[3] and b[1] < box[3] and any(box[0] + o < b[2] and b[0] < box[2] + o
                                                               for o in (-W, 0, W)) for b in taken):
                taken.append(box)
                out.append((name, x, feet))
                break
    return out


def ground_line(piece):
    """GROUND's pieces side by side along the horizon, once round the floor: [(piece, x, feet row)]."""
    rnd, out, x, k = lcg(244), [], 0, 0
    while True:
        p = piece(GROUND[k % len(GROUND)])
        if x + p[0] > W - 4 and k:  # the last one leaves a gap before the first, as the others do
            return out
        out.append((p, x, OPAQUE_FROM + 2 + rnd(GROUND_FEET - 1)))
        x, k = x + p[0] + 2 + rnd(GROUND_GAP - 1), k + 1


def floor(piece):
    img = bytearray(W * H * 4)
    blades = cut(piece.sheet(BLADES[0]), *BLADES[1:])
    looks = {"light": recolour(blades, step(LIGHT))}
    for n in RAMP_IN:
        looks[n] = recolour(blades, step(n))
    ground, rnd = sorted(ground_line(piece), key=lambda g: g[2]), lcg(89)
    for i, y in enumerate(range(GRASS_FROM, H, STEP)):
        while ground and ground[0][2] - STEP <= y:  # its feet go under this row's blades and the next ones'
            p, x, feet = ground.pop(0)
            over(img, W, H, p, x, feet - p[1])
        look = looks[RAMP_IN[i]] if i < len(RAMP_IN) else looks["light"]
        off = rnd(W)
        for c in range(COPIES):
            over(img, W, H, look, (off + c * W // COPIES) % W, y)
    for name, x, feet in place(*MEADOW[:1], piece, *MEADOW[1:], 16, []):
        p = piece(name)
        over(img, W, H, p, x, feet - p[1])
    edge = cut(piece.sheet(EDGE[0]), *EDGE[1:3], EDGE[3], EDGE_ROWS, cell=True)  # the cell's first rows
    for x in range(0, W, edge[0]):
        over(img, W, H, edge, x, H - EDGE_ROWS)
    holes = [(i % W, i // W) for i in range(W * OPAQUE_FROM, W * H) if not img[i * 4 + 3]]
    if holes:
        raise SystemExit(f"{len(holes)} clear pixels below row {OPAQUE_FROM}, e.g. {holes[:5]}")
    return W, H, bytes(img)


def props(piece):
    img = bytearray(PROPS_W * PROPS_H * 4)
    for name, x, mirror in PROPS:
        p = piece(name, mirror)
        over(img, PROPS_W, PROPS_H, p, x, PROPS_FEET - p[1])
    return PROPS_W, PROPS_H, bytes(img)


def clouds(piece):
    img = bytearray(CLOUDS_W * CLOUDS_H * 4)
    for n, x, y in CLOUDS:
        sheet = piece.sheet(CLOUD[n - 1])
        p = cut(sheet, 0, 0, sheet[0], sheet[1])  # the file is the cloud: one island, its box the whole file
        if y + p[1] > CLOUDS_H:
            raise SystemExit(f"cloud{n} at y {y} runs past the strip's bottom")
        over(img, CLOUDS_W, CLOUDS_H, p, x, y)
    return CLOUDS_W, CLOUDS_H, bytes(img)


def step_heights():
    """The ground's top in each column of the step's strip, in rows under the step's top."""
    down = [round(STEP_DROP * (1 - math.cos(math.pi * (i + 0.5) / STEP_RUN)) / 2) for i in range(STEP_RUN)]
    return [STEP_DROP] * STEP_FLAT + down[::-1] + [0] * STEP_TOP + down + [STEP_DROP] * STEP_FLAT


def step_sheet(piece):
    ew, eh, epx = cut(piece.sheet(EDGE[0]), *EDGE[1:], cell=True)
    img = bytearray(STEP_W * STEP_H * 4)
    for x, top in enumerate(step_heights()):
        for y in range(top, STEP_H):
            k = (min(y - top, eh - 1) * ew + x % ew) * 4
            img[(y * STEP_W + x) * 4:(y * STEP_W + x) * 4 + 4] = epx[k:k + 4]
    return STEP_W, STEP_H, bytes(img)


def main():
    args = sys.argv[1:]
    check = "--check" in args
    piece = Pieces(pack_dir(args[args.index("--pack") + 1] if "--pack" in args else None))
    stale = []
    for out, build in ((FLOOR, floor), (PROPS_OUT, props), (CLOUDS_OUT, clouds), (STEP_OUT, step_sheet)):
        w, h, img = build(piece)
        if check:
            if not out.exists() or read_png(out) != (w, h, img):
                stale.append(out.relative_to(ROOT).as_posix())
            continue
        write_png(out, w, h, img)
        print(f"wrote {out.relative_to(ROOT)} {w}x{h}")
    if stale:
        sys.exit(f"out of date: {', '.join(stale)} (run python3 tool/import_battle_floor.py)")
    if check:
        print("battle_floor.png, battle_props.png, battle_clouds.png and battle_step.png up to date")


if __name__ == "__main__":
    main()
