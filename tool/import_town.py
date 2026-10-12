"""Imports the Town scene's art into assets/images and writes lib/town_art.dart (decisions-log 222; docs/assets.md
"Packs -> files"). Everything comes from GandalfHardcore's FREE Platformer Assets (the owner, 2026-10-04: the Town
reuses that pack only; the Smithy is its furnace and sawmill; the house is rebuilt from House Tiles.png cell by cell,
never pasted as it is), unpacked in the main checkout's raw_sprites/gandalfhardcore-platformer/: never raw_assets/,
never another pack.

- town_bg_1..5.png: the Normal BG parallax layers, 1 (the near pines and the ground) to 5 (the sky), 1024x346 each,
  tiling sideways (the battle's band above the field draws them too: decisions-log 228, lib/main.dart
  backdropLayers); town_castle.png: its castle layer, drawn between layers 4 and 3.
- town_ground.png: the street (decisions-log 279; the owner's crop of Floor Tiles2.png: its grass top over its dark
  earth), Floor Tiles2.png (32, 0, 32x14): its 32-px grid's cell (1, 0), the green block's top edge, cut to the grass
  (rows 0-12, the blades hanging into the earth) and one row of the earth under it (row 13, the block's fill, the one
  colour 19,17,22 down to its bottom edge). The top repeats every 32 px (columns 11-31 are 43-63), so the cell tiles
  along x as the sheet runs on (its column 63 is the sheet's 31, the column before 32); tool/sprite_map.py maps the
  sheet, and the owner's 57x15 crop is the sheet's (19, 0) exactly (also (115, 0) and (211, 160): the same top).
- town_house.png: the 64 cells of House Tiles.png's left house the scene rebuilds the house from (HOUSE), 16x16 each,
  HOUSE_COLS a row in HOUSE's order (the design's house-tiles picture numbers them the same, from 1); the porch row's
  16x8 cells at the top of their slot.
- town_smithy.png: Furnace and Sawmill.png as it is: 64x64 frames, row 0 the furnace (6 frames: the fire roars, a
  smoke puff), row 1 the sawmill (6 frames: the saw cuts a log).
- town_campfire.png: Campfire with food sheet.png as it is: 32x32 frames, 5 a row, 8 rows (loops of the flame under
  the pot).
- town_tent.png (the Large Tent, the troops' rest), town_ore.png (Ores.png's blue rock): one piece each, cut to its
  pixels (SINGLES).
- town_pine.png: Pine Trees.png's olive pine as the owner drew it (note 2026-10-04): its cone and first tier over a
  tall trunk, stacked from the sprite's row bands (STACKS). The sheet is modular on a 32-px grid (mapped first:
  python3 tool/sprite_map.py "Pine Trees.png" map.png --grid 32): each pine's cone, three tiers and trunk; a bare
  trunk stands inside each pine's box, a sprite of its own, cleared (the sprite's own pixels only).
- town_props.png: Decor.png's props (PROPS), packed in rows with a 1 px gap (props_layout()).
- The Towns' identities (decisions-log 326): town_autumn_bg_1..5.png and town_autumn_castle.png, the Autumn BG set,
  town_winter_bg_1..5.png and town_winter_castle.png, the Winter BG set, laid out as the Normal BG's; town_ground_autumn
  and town_ground_winter.png, Floor Tiles2.png's same cell as town_ground.png's in its autumn band (32, 192) and its
  snowy band (32, 384); town_yards.png, each identity's yard pieces (YARDS) cut to their mapped boxes from the pack's
  trees, Wheat.png, Boat.png, Garden Decorations.png, Alchemy Decor.png, Small Tent.png, Angel Statue.png, Ores.png
  and Torch.png (the lit torch's six frames side by side), packed as town_props.png (yards_layout()).
Every file is written as 8-bit RGBA (the pixels unchanged). lib/town_art.dart holds the files' names, the frame grids
and each named cell's rect in its atlas, so the scene draws by name.

Stdlib only:  python3 tool/import_town.py [--pack DIR] [--check]
(--pack: the unpacked pack, by default raw_sprites/gandalfhardcore-platformer in this checkout or the main one;
--check writes nothing and exits 1 while assets/ or lib/town_art.dart differ from what it would write)
"""
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from build_atlas import read_png, write_png  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/images"
DART = ROOT / "lib/town_art.dart"
PACK = "raw_sprites/gandalfhardcore-platformer"
BG = "GandalfHardcore Background layers/Normal BG"

# The Towns' seasons (decisions-log 326): (season, its BG set's folder, its castle's file), laid out as the Normal BG.
SEASONS = [("autumn", "GandalfHardcore Background layers/Autumn BG", "Background Castle Autumn.png"),
           ("winter", "GandalfHardcore Background layers/Winter BG", "Background Castle  Winter.png")]
# Whole files, as they are: (out name, pack file, frame w, h or None).
WHOLE = [(f"town_bg_{i}.png", f"{BG}/GandalfHardcore Background layers_layer {i}.png", None) for i in range(1, 6)] + [
    (f"town_{season}_bg_{i}.png", f"{folder}/GandalfHardcore Background layers_layer {i}.png", None)
    for season, folder, _ in SEASONS for i in range(1, 6)] + [
    (f"town_{season}_castle.png", f"{folder}/{castle}", None) for season, folder, castle in SEASONS] + [
    ("town_castle.png", f"{BG}/Background Castle .png", None),
    ("town_smithy.png", "Furnace and Sawmill.png", (64, 64)),
    ("town_campfire.png", "Animated Sprites/Campfire with food sheet.png", (32, 32)),
]
# One piece of a sheet, cut to its pixels: (out name, pack file, x, y, w, h).
SINGLES = [
    ("town_ground.png", "Floor Tiles2.png", 32, 0, 32, 14),  # the street, its grass over its earth (decisions-log 279)
    ("town_ground_autumn.png", "Floor Tiles2.png", 32, 192, 32, 14),  # the same cell in the autumn band (326)
    ("town_ground_winter.png", "Floor Tiles2.png", 32, 384, 32, 14),  # and in the snowy one
    ("town_tent.png", "Large Tent.png", 0, 7, 96, 121),  # the troops' rest
    ("town_ore.png", "Ores.png", 70, 90, 53, 38),  # the blue ore rock, beside the furnace
]
# A piece stacked from row bands of one sprite, top to bottom, then cut to its pixels: (out name, pack file, the
# sprite's box (x, y, w, h), [(first row in the box, rows), ...]); only the box's largest sprite is kept.
STACKS = [
    # Pine Trees.png's sprite 3 (the olive pine; tool/sprite_map.py numbers it so): its cone (rows 0-63) and first tier
    # (64-95), then its trunk's last 16 rows twice. Sprite 2, a bare trunk inside the box (97, 0, 29x64), is cleared.
    ("town_pine.png", "Pine Trees.png", (97, 0, 93, 192), [(0, 96), (176, 16), (176, 16)]),
]
# The house's cells: (name, x, y, w, h) on House Tiles.png's left house (x 0-224), in the order the design numbers
# them (each cell's first use over the one-storey n 0, two-storey n 0 and two-storey n 1 houses). The roof's slope is
# exactly 1:1 and its bricks repeat every 16 px, so a slope cell moved one cell down and one across meets the next.
HOUSE = [
    ("apexL", 96, 0, 16, 16), ("apexR", 112, 0, 16, 16),  # the ridge
    ("slopeL1o", 80, 16, 16, 16), ("slopeL1i", 96, 16, 16, 16), ("slopeR1i", 112, 16, 16, 16),
    ("slopeR1o", 128, 16, 16, 16),  # each slope row takes two cells: the strip's top (o) and its underside (i)
    ("slopeL2o", 64, 32, 16, 16), ("slopeL2i", 80, 32, 16, 16), ("slopeR2i", 128, 32, 16, 16),
    ("slopeR2o", 144, 32, 16, 16),
    ("gable", 96, 32, 16, 16),  # the gable's and the upper back wall's bricks
    ("slopeL3o", 48, 48, 16, 16), ("slopeL3i", 64, 48, 16, 16), ("slopeR3i", 144, 48, 16, 16),
    ("slopeR3o", 160, 48, 16, 16),
    ("eaveL1o", 32, 64, 16, 16), ("postL", 48, 64, 16, 16), ("postR", 160, 64, 16, 16), ("eaveR1o", 176, 64, 16, 16),
    ("eaveL0", 16, 80, 16, 16), ("wallL5a", 32, 80, 16, 16), ("wallR5b", 176, 80, 16, 16),
    ("eaveR0", 192, 80, 16, 16),  # the eaves' tips
    ("wallL5b", 48, 80, 16, 16), ("wallR5a", 160, 80, 16, 16),
    ("wallL8a", 32, 128, 16, 16), ("wallL8b", 48, 128, 16, 16),  # the ground floor's left wall, cream stones
    ("brickLow", 80, 176, 16, 16),  # the ground floor's back wall
    ("winTL", 64, 128, 16, 16), ("winTR", 80, 128, 16, 16),  # the window, 2x3 cells
    ("pipeTL", 160, 128, 16, 16), ("pipeTR", 176, 128, 16, 16),  # the right wall: the pipe, then the block
    ("wallL9", 32, 144, 16, 16), ("doorTop", 48, 144, 16, 16),
    ("winBL", 64, 144, 16, 16), ("winBR", 80, 144, 16, 16),
    ("pipeBL", 160, 144, 16, 16), ("pipeBR", 176, 144, 16, 16),
    ("wallL10", 32, 160, 16, 16), ("doorMid", 48, 160, 16, 16),
    ("sillL", 64, 160, 16, 16), ("sillR", 80, 160, 16, 16),
    ("blockTL", 160, 160, 16, 16), ("blockTR", 176, 160, 16, 16),
    ("wallL11", 32, 176, 16, 16), ("doorLow", 48, 176, 16, 16),
    ("blockBL", 160, 176, 16, 16), ("blockBR", 176, 176, 16, 16),
    ("baseL", 32, 192, 16, 8), ("porchL", 48, 192, 16, 8), ("porch", 64, 192, 16, 8),  # the porch, half a row
    ("baseRa", 160, 192, 16, 8), ("baseRb", 176, 192, 16, 8),
    ("creamL6", 32, 96, 16, 16), ("beamL", 48, 96, 16, 16), ("beam", 64, 96, 16, 16),  # the balcony's floor beam
    ("beamJoint", 120, 96, 16, 16), ("beamR", 160, 96, 16, 16), ("beamREnd", 176, 96, 16, 16),
    ("creamL7a", 32, 112, 16, 16), ("creamL7b", 48, 112, 16, 16), ("brick", 96, 112, 16, 16),  # under the beam
    ("creamR7a", 160, 112, 16, 16), ("creamR7b", 176, 112, 16, 16),
]
HOUSE_FILE, HOUSE_CELL, HOUSE_COLS = "House Tiles.png", 16, 8
# Decor.png's props: (name, x, y, w, h), each cut to its pixels.
PROPS = [
    ("table", 262, 21, 18, 11),  # a small table, on the balcony
    ("crate", 2, 16, 27, 16),  # a crate, on the balcony
    ("barrels", 98, 14, 29, 18),  # two barrels: on the balcony, by the Shop
    ("crates2", 34, 0, 27, 32),  # two crates stacked: on the balcony, by the Shop
    ("cauldron", 168, 17, 18, 15),  # an iron pot, on the house's right block
    ("logPile", 201, 75, 47, 21),  # logs before the sawmill
    ("stumpAxe", 231, 11, 21, 21),  # a stump with an axe, by the furnace
    ("clothesLine", 27, 354, 106, 62),  # a clothes line, beside the house
    ("fruitTable", 267, 34, 39, 30),  # a table of fruit and bread, the Shop's
    ("basket", 360, 49, 17, 15),  # a basket of apples, the Shop's
]
DECOR, PROPS_W, GAP = "Decor.png", 128, 1
# The Towns' yards (decisions-log 326): each identity's pieces, (name, pack file, x, y, w, h, frames), cut to the boxes
# tool/sprite_map.py maps; an animation's next frames lie 32 px apart along its sheet's row (Torch.png's lit torch, the
# flame's six frames), packed side by side.
YARDS = [
    ("flowerTree", "Flowering Tree.png", 4, 12, 85, 100, 1),  # Millbrook's: the flowering tree, the wheat, a sack, a sheaf
    ("wheat", "Wheat.png", 133, 0, 19, 32, 1),
    ("sack", "Wheat.png", 198, 12, 20, 20, 1),
    ("sheaf", "Wheat.png", 226, 16, 12, 15, 1),
    ("willow", "Weeping Willow1.png", 4, 1, 216, 191, 1),  # Willowmere's: the willow, a boat pulled up, potted plants
    ("boat", "Boat.png", 1, 7, 78, 25, 1),
    ("potGreen", "Garden Decorations.png", 36, 7, 23, 25, 1),
    ("potOlive", "Garden Decorations.png", 37, 36, 21, 28, 1),
    ("potSmall", "Garden Decorations.png", 71, 48, 18, 16, 1),
    ("birch", "Birch1.png", 2, 5, 75, 107, 1),  # Ironvale's: a birch, the gold ore rock, a torch
    ("oreGold", "Ores.png", 6, 90, 53, 38, 1),
    ("torch", "Torch.png", 11, 33, 10, 31, 6),  # Ironvale's, Frostgate's and Highspire's
    ("smallTent", "Small Tent.png", 0, 0, 64, 64, 1),  # Ambergate's: the market tent, the flower table, sunflowers, grapes
    ("flowerTable", "Alchemy Decor.png", 79, 26, 37, 38, 1),
    ("sunflowers", "Alchemy Decor.png", 163, 21, 27, 43, 1),
    ("grapeBowl", "Alchemy Decor.png", 137, 46, 14, 18, 1),
    ("cypress", "Garden Decorations.png", 130, 26, 28, 102, 1),  # Frostgate's: a cypress, urns on plinths, the angel
    ("urnFern", "Garden Decorations.png", 99, 66, 27, 62, 1),
    ("angel", "Angel Statue.png", 9, 0, 48, 64, 1),
    ("urnRed", "Garden Decorations.png", 65, 74, 29, 54, 1),
    ("bust", "Garden Decorations.png", 5, 83, 21, 45, 1),  # Highspire's: a bust, the alchemy table, an urn, a tree
    ("alchemyTable", "Alchemy Decor.png", 35, 42, 26, 22, 1),
    ("urn", "Garden Decorations.png", 35, 86, 27, 42, 1),
    ("gardenTree", "Garden Decorations.png", 163, 38, 56, 90, 1),
]
YARDS_W, FRAME_STEP = 256, 32


def packed(cells, width):
    """{name: (x, y, w, h)} of cells (name, w, h) packed into an atlas [width] px wide, and its (width, height): the
    cells tallest first (then by name), each row filled left to right, a cell in the first row it fits, GAP px between
    cells and rows."""
    rows, at = [], {}  # rows: [y, height, next x]
    for name, w, h in sorted(cells, key=lambda p: (-p[2], p[0])):
        row = next((r for r in rows if r[2] + w <= width and h <= r[1]), None)
        if row is None:
            row = [rows[-1][0] + rows[-1][1] + GAP if rows else 0, h, 0]
            rows.append(row)
        at[name] = (row[2], row[0], w, h)
        row[2] += w + GAP
    return at, (width, rows[-1][0] + rows[-1][1])


def props_layout():
    """{name: (x, y, w, h)} in town_props.png, and its (width, height)."""
    return packed([(name, w, h) for name, _, _, w, h in PROPS], PROPS_W)


def yards_layout():
    """{name: (x, y, w, h)} in town_yards.png (an animation's whole row of frames), and its (width, height)."""
    return packed([(name, w * frames, h) for name, _, _, _, w, h, frames in YARDS], YARDS_W)


def house_layout():
    """{name: (x, y, w, h)} in town_house.png, and its (width, height)."""
    at = {name: (i % HOUSE_COLS * HOUSE_CELL, i // HOUSE_COLS * HOUSE_CELL, w, h)
          for i, (name, _, _, w, h) in enumerate(HOUSE)}
    return at, (HOUSE_COLS * HOUSE_CELL, -(-len(HOUSE) // HOUSE_COLS) * HOUSE_CELL)


def main_checkout():
    """The main worktree's root (where raw_sprites/ holds the packs), or None outside git."""
    try:
        out = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"], cwd=ROOT,
                             capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None
    return Path(out).parent if out else None


def find_pack():
    for base in (ROOT, main_checkout()):
        if base and (base / PACK).is_dir():
            return base / PACK
    sys.exit(f"{PACK}: not here nor in the main checkout (give the unpacked pack with --pack DIR)")


def crop(img, x, y, w, h):
    sw, sh, px = img
    if x < 0 or y < 0 or x + w > sw or y + h > sh:
        sys.exit(f"({x}, {y}, {w}x{h}) is outside its {sw}x{sh} sheet")
    return b"".join(bytes(px[((y + r) * sw + x) * 4:((y + r) * sw + x + w) * 4]) for r in range(h))


def alone(w, h, px):
    """Only the largest sprite of an image (8-connected opaque pixels): every other pixel cleared."""
    best, seen = [], set()
    for start in range(w * h):
        if not px[start * 4 + 3] or start in seen:
            continue
        seen.add(start)
        todo, island = [start], []
        while todo:
            i = todo.pop()
            island.append(i)
            x, y = i % w, i // w
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    n = (y + dy) * w + x + dx
                    if 0 <= x + dx < w and 0 <= y + dy < h and n not in seen and px[n * 4 + 3]:
                        seen.add(n)
                        todo.append(n)
        best = max(best, island, key=len)
    out = bytearray(w * h * 4)
    for i in best:
        out[i * 4:i * 4 + 4] = px[i * 4:i * 4 + 4]
    return bytes(out)


def stack(img, box, bands):
    """(w, h, rgba): the box's largest sprite, its row bands one under another, cut to the columns they fill."""
    bx, by, bw, bh = box
    px = alone(bw, bh, crop(img, bx, by, bw, bh))
    if any(y < 0 or y + n > bh for y, n in bands):
        sys.exit(f"{box}: a band {bands} outside the box")
    rows = [px[y * bw * 4:(y + 1) * bw * 4] for y0, n in bands for y in range(y0, y0 + n)]
    xs = [x for r in rows for x in range(bw) if r[x * 4 + 3]]
    x0, x1 = min(xs), max(xs) + 1
    return x1 - x0, len(rows), b"".join(bytes(r[x0 * 4:x1 * 4]) for r in rows)


def atlas(sheet, cells, at, size):
    """The cells (name, x, y, w, h) of sheet, each at its rect of at, on a clear size."""
    aw, ah = size
    out = bytearray(aw * ah * 4)
    for name, x, y, w, h in cells:
        ax, ay, _, _ = at[name]
        px = crop(sheet, x, y, w, h)
        for r in range(h):
            out[((ay + r) * aw + ax) * 4:((ay + r) * aw + ax + w) * 4] = px[r * w * 4:(r + 1) * w * 4]
    return aw, ah, bytes(out)


def images(pack):
    """{out name: (w, h, rgba)} of every file, everything checked before anything is written."""
    sheets = {}

    def sheet(name):
        if name not in sheets:
            if not (pack / name).is_file():
                sys.exit(f"{pack / name}: not found")
            sheets[name] = read_png(pack / name)
        return sheets[name]
    out = {}
    for name, src, frame in WHOLE:
        w, h, px = sheet(src)
        if frame and (w % frame[0] or h % frame[1]):
            sys.exit(f"{src}: {w}x{h} is not a grid of {frame[0]}x{frame[1]} frames")
        out[name] = (w, h, bytes(px))
    for name, src, x, y, w, h in SINGLES:
        out[name] = (w, h, crop(sheet(src), x, y, w, h))
    for name, src, box, bands in STACKS:
        out[name] = stack(sheet(src), box, bands)
    for names in ([c[0] for c in HOUSE] + [p[0] for p in PROPS], [y[0] for y in YARDS]):
        if len(set(names)) != len(names):
            sys.exit("HOUSE / PROPS / YARDS: a name twice")
    for name, x, _, w, h in HOUSE:
        if x >= 224 or w != HOUSE_CELL or h not in (HOUSE_CELL, HOUSE_CELL // 2):
            sys.exit(f"HOUSE: {name} is not a 16x16 (or 16x8) cell of the left house")
    out["town_house.png"] = atlas(sheet(HOUSE_FILE), HOUSE, *house_layout())
    out["town_props.png"] = atlas(sheet(DECOR), PROPS, *props_layout())
    at, (aw, ah) = yards_layout()
    yards = bytearray(aw * ah * 4)
    for name, src, x, y, w, h, frames in YARDS:
        ax, ay, _, _ = at[name]
        for f in range(frames):
            px = crop(sheet(src), x + f * FRAME_STEP, y, w, h)
            for r in range(h):
                o = ((ay + r) * aw + ax + f * w) * 4
                yards[o:o + w * 4] = px[r * w * 4:(r + 1) * w * 4]
    out["town_yards.png"] = (aw, ah, bytes(yards))
    return out


def frames_of(name):
    return next(frames for n, *_, frames in YARDS if n == name)


def dart_cells(var, at, doc):
    lines = [f"/// {doc}", f"const {var} = <String, TownCell>{{"]
    for name, (x, y, w, h) in at.items():
        lines.append(f"  '{name}': (x: {x}, y: {y}, w: {w}, h: {h}),")
    return lines + ["};"]


def dart(made):
    """lib/town_art.dart's text, for the images [made]."""
    house, (hw, hh) = house_layout()
    props, (pw, ph) = props_layout()
    single = {name: (w, h) for name, (w, h, _) in made.items()}
    lines = [
        "// The Town scene's art (decisions-log 222; docs/assets.md \"Packs -> files\"): GandalfHardcore's FREE Platformer",
        "// Assets, cut into assets/images by tool/import_town.py, which writes this file from the same tables. Never edit",
        "// it by hand: `python3 tool/import_town.py --check` fails while it differs. Sizes are in sprite px.",
        "",
        "/// A cell of an atlas: its rect in the file.",
        "typedef TownCell = ({int x, int y, int w, int h});",
        "",
        "/// The Normal BG parallax layers, 1 (the near pines and the ground) to 5 (the sky, opaque), each",
        "/// [townLayerW]x[townLayerH], tiling sideways; the castle goes between layers 4 and 3.",
        "const townLayers = [" + ", ".join(f"'town_bg_{i}.png'" for i in range(1, 6)) + "];",
        "const townCastle = 'town_castle.png';",
        "const townLayerW = 1024, townLayerH = 346;",
        "",
        "/// The Towns' seasons (decisions-log 326): the Autumn and the Winter BG, laid out as [townLayers] and [townCastle].",
    ] + [f"const town{season.title()}Layers = [" + ", ".join(f"'town_{season}_bg_{i}.png'" for i in range(1, 6)) +
         f"], town{season.title()}Castle = 'town_{season}_castle.png';" for season, _, _ in SEASONS] + [
        "",
        "/// The street (decisions-log 279): Floor Tiles2's grass top over its dark earth, "
        "[townGroundW]x[townGroundH], one",
        "/// tile of its 32-px repeat, tiled along the street; its last row is the earth's one colour.",
        "const townGroundTile = 'town_ground.png';",
        f"const townGroundW = {single['town_ground.png'][0]}, townGroundH = {single['town_ground.png'][1]};",
        "",
        "/// Their streets: Floor Tiles2's same cell in its autumn and its snowy band, as big as [townGroundTile].",
        "const townGroundAutumn = 'town_ground_autumn.png', townGroundWinter = 'town_ground_winter.png';",
        "",
        f"/// The house's {len(HOUSE)} cells ([townHouseCells]), {HOUSE_COLS} a row of {HOUSE_CELL}x{HOUSE_CELL} "
        f"({hw}x{hh}): the scene rebuilds the",
        "/// house from them cell by cell.",
        "const townHouse = 'town_house.png';",
        "",
    ]
    lines += dart_cells("townHouseCells", house, "Each house cell's rect in [townHouse], in the atlas's order (the "
                                                 "porch row's are 16x8).")
    lines += [
        "",
        "/// The Smithy: the furnace (row [townFurnaceRow]) and the sawmill (row [townSawmillRow]),",
        "/// [townSmithyFrames] frames of [townSmithyFrame]x[townSmithyFrame] each.",
        "const townSmithy = 'town_smithy.png';",
        "const townSmithyFrame = 64, townSmithyFrames = 6, townFurnaceRow = 0, townSawmillRow = 1;",
        "",
        "/// The pot over the campfire: [townCampfireFrames] frames of [townCampfireFrame]x[townCampfireFrame] a row,",
        "/// [townCampfireLoops] rows (loops of the flame).",
        "const townCampfire = 'town_campfire.png';",
        "const townCampfireFrame = 32, townCampfireFrames = 5, townCampfireLoops = 8;",
        "",
        f"/// The troops' rest, the Large Tent ({'x'.join(map(str, single['town_tent.png']))}), the blue ore rock "
        f"({'x'.join(map(str, single['town_ore.png']))}) and the olive",
        f"/// pine ({'x'.join(map(str, single['town_pine.png']))}: its cone and first tier over a tall trunk), each drawn whole.",
        "const townTent = 'town_tent.png', townOre = 'town_ore.png', townPine = 'town_pine.png';",
        "",
        f"/// The props ([townPropCells]), {pw}x{ph}.",
        "const townProps = 'town_props.png';",
        "",
    ]
    lines += dart_cells("townPropCells", props, "Each prop's rect in [townProps].")
    yards, (yw, yh) = yards_layout()
    first = {name: (x, y, w // frames, h) for (name, (x, y, w, h)), frames in zip(yards.items(),
                                                                                    (frames_of(n) for n in yards))}
    lines += [
        "",
        f"/// The Towns' yards' pieces ([townYardCells]), {yw}x{yh} (decisions-log 326): an animation's next frames beside",
        "/// its first, [townYardFrames] of them.",
        "const townYards = 'town_yards.png';",
        "",
    ]
    lines += dart_cells("townYardCells", first, "Each yard piece's (first frame's) rect in [townYards].")
    lines += [
        "",
        "/// The yard pieces' frames, an animation's (the others one).",
        "const townYardFrames = <String, int>{" + ", ".join(
            f"'{name}': {frames}" for name, *_, frames in YARDS if frames > 1) + "};",
        "",
        "/// Every file of the Town scene.",
        "const townImages = [",
        "  ...townLayers,",
        "  ...townAutumnLayers,",
        "  ...townWinterLayers,",
    ] + [f"  {v}," for v in ("townCastle", "townAutumnCastle", "townWinterCastle", "townGroundTile",
                             "townGroundAutumn", "townGroundWinter", "townHouse", "townSmithy", "townCampfire",
                             "townTent", "townOre", "townPine", "townProps", "townYards")] + [
        "];",
        "",
    ]
    return "\n".join(lines)


def png_bytes(w, h, px, at):
    """write_png's bytes for an image, through a scratch file at [at]."""
    write_png(at, w, h, px)
    data = at.read_bytes()
    at.unlink()
    return data


def main(args):
    pack, check = None, False
    while args:
        if args[0] == "--pack" and len(args) > 1:
            pack, args = Path(args[1]).expanduser(), args[2:]
        elif args[0] == "--check":
            check, args = True, args[1:]
        else:
            sys.exit(__doc__)
    made = images(pack or find_pack())
    text = dart(made)
    if check:
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            stale = [name for name, (w, h, px) in made.items()
                     if not (OUT / name).is_file() or (OUT / name).read_bytes() != png_bytes(w, h, px, Path(tmp) / name)]
        if not DART.is_file() or DART.read_text() != text:
            stale.append(DART.relative_to(ROOT).as_posix())
        if stale:
            sys.exit("out of date: " + ", ".join(stale) + " (run python3 tool/import_town.py)")
        print("up to date:", len(made), "images and", DART.relative_to(ROOT))
        return
    for name, (w, h, px) in made.items():
        write_png(OUT / name, w, h, px)
    DART.write_text(text)
    print(len(made), "Town images into", OUT.relative_to(ROOT), "and", DART.relative_to(ROOT))


if __name__ == "__main__":
    main(sys.argv[1:])
