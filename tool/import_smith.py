"""Imports the Smithy's smith into assets/images/town_smith.png and writes lib/town_smith_art.dart (decisions-log 265;
docs/assets.md "Packs -> files"). The owner, 2026-10-07: "di dalam bangunan di kasi 1 npc yang lagi nempa saja"; the
pack, the Mana Seed Character Base demo (Seliel the Shaper), has no smithing page, so the smith is its paper doll
(layers stacked in the guide's order: 0bas the body, 1out the outfit, 4har the hair, 6tla the tool) swinging the
one-hand pages' mace (mc01) as a hammer, facing right (row 2 of each page), at Pixel Crawler's anvil.

- The frames (FRAMES), each the pack's own 64x64 cell with every layer: slash 1's backswing and its raised hold (page
  ONE-hand 3), the draw's frame with the mace forward and up and the parry, whose mace head lands on the anvil's horn
  (page ONE-hand 1), and the combat idle's first frame as the pause (page ONE-hand 2). The tool layer goes behind or in
  front of the body as the pack's "layer order" guide says for that frame. The slash's white swoosh (ARC, a colour of
  its own on the tool layer) is left out: the swing is a hammer's, not a sword's arc.
- The anvil: Pixel Crawler's Environment/Props/Static/Tools.png sprite 46 (python3 tool/sprite_map.py numbers it so),
  its exact box, drawn over each frame at ANVIL_AT (its foot on the smith's feet row, the strike's head on its horn).
  The tool refuses a box that is not one whole sprite.
- town_smith.png: the frames in a row, each cut to the box every frame's pixels fit in (the anvil stays put), 8-bit
  RGBA, every pixel a pack pixel. Drawn at 1 world px a sprite px, the house's own (decisions-log 265: at the troops'
  2 he'd stand taller than the Smithy's door).
- lib/town_smith_art.dart: the file's name, the frame's size, where his feet stand in a frame, and the loop (BEATS:
  each frame's ms, the pack's own timing: its attacks' 160/65/65/200 and its smithing's 400/400/80/80/80).

Stdlib only:  python3 tool/import_smith.py [--pack DIR] [--anvil-pack DIR] [--check]
(--pack: the unpacked demo, by default raw_sprites/mana-seed-character-base-demo in this checkout or the main one;
--anvil-pack: Pixel Crawler, by default raw_sprites/pixel-crawler the same way; --check writes nothing and exits 1
while assets/images/town_smith.png or lib/town_smith_art.dart differ from what it would write)
"""
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from build_atlas import read_png, write_png  # noqa: E402
from sprite_map import sprites  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/images/town_smith.png"
DART = ROOT / "lib/town_smith_art.dart"
PACK = "raw_sprites/mana-seed-character-base-demo"
ANVIL_PACK = "raw_sprites/pixel-crawler"

CELL = 64  # the pack's frame
ROW = 2  # facing right (the rows are down, up, right, left)
# The look, a variant of each layer: the skin (0bas), the forester's outfit (1out), the hair (4har); no hat. The tool
# (6tla) is the mace.
LOOK = [("", "0bas", "humn_v05"), ("1out", "1out", "fstr_v01"), ("4har", "4har", "dap1_v11")]
TOOL = ("6tla", "6tla", "mc01_v01")
# (name, page, column, the tool in front of the body: the page's "layer order ... (sword).png" guide, row 2).
FRAMES = [
    ("backswing", "pONE3", 0, False),  # slash 1's first frame: the hammer back
    ("raised", "pONE3", 3, False),  # slash 1's last: the hammer up before his face
    ("swing", "pONE1", 1, True),  # the draw's middle frame: the hammer forward and up
    ("strike", "pONE1", 3, False),  # the parry: the hammer's head on the anvil's horn
    ("rest", "pONE2", 0, True),  # the combat idle's first: the hammer lowered, the pause
]
ARC = (244, 249, 248)  # the slash's swoosh on the tool layer, left out
ANVIL = ("Environment/Props/Static/Tools.png", (148, 93, 26, 19))  # sprite 46: the small anvil on its foot
ANVIL_AT = (38, 25)  # its top left in the cell: its foot on row 43, the smith's feet's; the strike lands on its horn
FEET_ROW = 43  # the smith's feet's bottom row in every cell (the body's lowest pixel)
# The loop, in ms: a backswing, three blows (the lift held, the swing, the strike), the pause.
BEATS = [("backswing", 160)] + [("raised", 400), ("swing", 80), ("strike", 200)] * 3 + [("rest", 800)]


def main_checkout():
    """The main worktree's root (where raw_sprites/ holds the packs), or None outside git."""
    try:
        out = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"], cwd=ROOT,
                             capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None
    return Path(out).parent if out else None


def find(rel):
    for base in (ROOT, main_checkout()):
        if base and (base / rel).is_dir() and any((base / rel).iterdir()):
            return base / rel
    sys.exit(f"{rel}: not here nor in the main checkout (give the unpacked pack with --pack / --anvil-pack DIR)")


def layer_file(pack, page, folder, kind, variant):
    sub = pack / f"char_a_{page}" / folder if folder else pack / f"char_a_{page}"
    path = sub / f"char_a_{page}_{kind}_{variant}.png"
    if not path.is_file():
        sys.exit(f"{path}: not found")
    return path


def cell_of(img, col, row):
    """A cell's pixels (CELL x CELL rgba); the pack's alpha is all or nothing, which compositing relies on."""
    w, h, px = img
    if w % CELL or h % CELL:
        sys.exit(f"a {w}x{h} sheet is not a grid of {CELL}-px cells")
    out = bytearray()
    for y in range(CELL):
        i = ((row * CELL + y) * w + col * CELL) * 4
        out += px[i:i + CELL * 4]
    if any(a not in (0, 255) for a in out[3::4]):
        sys.exit("a layer with partial alpha: compose it with a real blend first")
    return out


def over(dst, dw, src, sw, sh, dx, dy, skip=None):
    """src's opaque pixels onto dst (dw wide) at (dx, dy); a pixel of colour [skip] is left out."""
    for y in range(sh):
        for x in range(sw):
            j = (y * sw + x) * 4
            if src[j + 3] and (skip is None or tuple(src[j:j + 3]) != skip):
                i = ((dy + y) * dw + dx + x) * 4
                dst[i:i + 4] = src[j:j + 4]


def anvil(pack):
    """The anvil's pixels (w, h, rgba): its box, checked to be exactly one whole sprite of the sheet."""
    name, (x, y, w, h) = ANVIL
    path = pack / name
    if not path.is_file():
        sys.exit(f"{path}: not found")
    sw, sh, px = read_png(path)
    found = [s[:4] for s in sprites(sw, sh, px)
             if s[0] < x + w and x < s[0] + s[2] and s[1] < y + h and y < s[1] + s[3]]
    if found != [(x, y, w, h)]:
        sys.exit(f"{name} {(x, y, w, h)}: not one whole sprite (the sprites there: {found})")
    out = bytearray()
    for r in range(h):
        i = ((y + r) * sw + x) * 4
        out += px[i:i + w * 4]
    return w, h, out


def frames(pack, anvil_pack):
    """[(name, CELL x CELL rgba)] of every frame: the smith's layers, then the anvil over them."""
    sheets = {}

    def sheet(path):
        if path not in sheets:
            sheets[path] = read_png(path)
        return sheets[path]
    aw, ah, apx = anvil(anvil_pack)
    out = []
    for name, page, col, front in FRAMES:
        body = [layer_file(pack, page, *spec) for spec in LOOK]
        tool = layer_file(pack, page, *TOOL)
        cell = bytearray(CELL * CELL * 4)
        for path in (body + [tool]) if front else ([tool] + body):
            over(cell, CELL, cell_of(sheet(path), col, ROW), CELL, CELL, 0, 0, ARC if path == tool else None)
        feet = max(i // 4 // CELL for i in range(3, len(cell), 4) if cell[i])
        if feet != FEET_ROW:
            sys.exit(f"{name}: the feet on row {feet}, not {FEET_ROW}")
        over(cell, CELL, apx, aw, ah, *ANVIL_AT)
        out.append((name, cell))
    return out


def strip(made):
    """(w, h, rgba, box): the frames in a row, each cut to the box all of them fit in, and that box in the cell."""
    xs, ys = [], []
    for _, cell in made:
        for i in range(3, len(cell), 4):
            if cell[i]:
                xs.append(i // 4 % CELL)
                ys.append(i // 4 // CELL)
    x0, y0, x1, y1 = min(xs), min(ys), max(xs) + 1, max(ys) + 1
    fw, fh = x1 - x0, y1 - y0
    w = fw * len(made)
    px = bytearray(w * fh * 4)
    for n, (_, cell) in enumerate(made):
        for y in range(fh):
            i = ((y0 + y) * CELL + x0) * 4
            px[(y * w + n * fw) * 4:(y * w + (n + 1) * fw) * 4] = cell[i:i + fw * 4]
    return w, fh, bytes(px), (x0, y0, fw, fh)


def feet_x(made):
    """The middle of the smith's body in the raised frame (the anvil's columns left out)."""
    cell = dict(made)["raised"]
    ax0 = ANVIL_AT[0]
    xs = [i // 4 % CELL for i in range(3, len(cell), 4) if cell[i] and i // 4 % CELL < ax0]
    return (min(xs) + max(xs) + 1) // 2


def dart(made, box):
    x0, y0, fw, fh = box
    names = [f[0] for f in FRAMES]
    fx, fy = feet_x(made) - x0, FEET_ROW + 1 - y0
    beats = [f"  (frame: {names.index(n)}, ms: {ms}), // {n}" for n, ms in BEATS]
    loop = sum(ms for _, ms in BEATS)
    lines = [
        "// The Smithy's smith (decisions-log 265; docs/assets.md \"Packs -> files\"): the Mana Seed Character Base demo's",
        "// paper doll with its mace for a hammer, at Pixel Crawler's anvil, cut into assets/images by tool/import_smith.py,",
        "// which writes this file from the same tables. Never edit it by hand: `python3 tool/import_smith.py --check` fails",
        "// while it differs. Sizes are in sprite px, drawn at 1 world px a sprite px (the house's).",
        "",
        f"/// The smith hammering at his anvil, facing right: [townSmithFrames] frames of [townSmithW]x[townSmithH] in a row",
        "/// (" + ", ".join(f"{n} {i}" for i, n in enumerate(names)) + "), the anvil in each.",
        "const townSmith = 'town_smith.png';",
        f"const townSmithW = {fw}, townSmithH = {fh}, townSmithFrames = {len(FRAMES)};",
        "",
        "/// Where his feet stand in a frame: the middle of his body, on the row under his feet (the anvil's foot is on it",
        "/// too).",
        f"const townSmithFeet = (x: {fx}, y: {fy});",
        "",
        "/// The loop, each frame in turn for its ms (the pack's own timing): the backswing, three blows (the hammer up, the",
        f"/// swing, the strike on the horn), the pause; [townSmithLoopMs] in all.",
        "const townSmithBeats = [",
        *beats,
        "];",
        f"const townSmithLoopMs = {loop};",
        "",
    ]
    return "\n".join(lines)


def png_bytes(w, h, px):
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "x.png"
        write_png(path, w, h, px)
        return path.read_bytes()


def main(args):
    pack, anvil_pack, check = None, None, False
    while args:
        if args[0] in ("--pack", "--anvil-pack") and len(args) > 1:
            if args[0] == "--pack":
                pack = Path(args[1]).expanduser()
            else:
                anvil_pack = Path(args[1]).expanduser()
            args = args[2:]
        elif args[0] == "--check":
            check, args = True, args[1:]
        else:
            sys.exit(__doc__)
    made = frames(pack or find(PACK), anvil_pack or find(ANVIL_PACK))
    w, h, px, box = strip(made)
    text = dart(made, box)
    if check:
        stale = [p.relative_to(ROOT).as_posix() for p, ok in (
            (OUT, OUT.is_file() and OUT.read_bytes() == png_bytes(w, h, px)),
            (DART, DART.is_file() and DART.read_text() == text)) if not ok]
        if stale:
            sys.exit("out of date: " + ", ".join(stale) + " (run python3 tool/import_smith.py)")
        print("up to date:", OUT.relative_to(ROOT), "and", DART.relative_to(ROOT))
        return
    write_png(OUT, w, h, px)
    DART.write_text(text)
    print(f"{OUT.relative_to(ROOT)} ({w}x{h}: {len(made)} frames of {box[2]}x{box[3]}) and {DART.relative_to(ROOT)}")


if __name__ == "__main__":
    main(sys.argv[1:])
