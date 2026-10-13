"""Imports the Dungeon's cave art into assets/images and writes lib/dungeon_art.dart (decisions-log 336, 337;
docs/assets.md "Packs -> files", docs/dungeon-design.md section 8). Everything comes from GandalfHardcore's FREE
Platformer Assets, the pack the Town already uses (the owner, 2026-10-13: not Pixel Crawler), unpacked in the main
checkout's raw_sprites/gandalfhardcore-platformer/: never raw_assets/, never another pack. Each piece was mapped first
(tool/sprite_map.py: every sprite's exact box, the sheets' 32-px grid), and is cut by that box.

- dungeon_tiles.png: the cave's pieces (TILES), packed in rows with a 1 px gap: Floor Tiles2's dark fill cell (the cave
  behind and above), its moss lip (the line at the wall's foot, tiled along x), its moss-topped block (the near ledge),
  its stalactite strip (the ceiling, tiled every 64 px), BG Dirt1's flat earth (the floor band), its slab with two
  tunnel holes and its pillar (the back wall). The slab and the pillar are one island on the sheet, split by the
  column where the pillar ends (x 32). And Floor Tiles2's moss-topped block, its top two rows of 32-px cells (the
  corners, the top, the sides and the fill): the Town's door, a rock mound built cell by cell.
- dungeon_props.png: the props (PROPS), packed the same way: Decor's mossy boulder pile, rocks, a rock and pebbles,
  three gravestones and a cross, Ores.png's four crystal rocks (each cut to its own pixels, its largest island), and
  Torch.png's wall torch, lit, its six frames side by side (each 12x31 cell from its 32-px column, its sparks in it),
  and its standing torch (row 1, 10x31 a frame), the door's two.
- dungeon_portal.png: the Portal sheet as it is (the stairs down): 64x64 frames, ten in a row.
The save point's campfire is the Town's town_campfire.png (tool/import_town.py). Every file is written as 8-bit RGBA
(the pixels unchanged). lib/dungeon_art.dart holds the files' names, the portal's frame grid and each named cell's rect
in its atlas, so the scene draws by name.

Stdlib only:  python3 tool/import_dungeon.py [--pack DIR] [--check]
(--pack: the unpacked pack, by default raw_sprites/gandalfhardcore-platformer in this checkout or the main one;
--check writes nothing and exits 1 while assets/ or lib/dungeon_art.dart differ from what it would write)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from build_atlas import read_png, write_png  # noqa: E402
from import_town import alone, crop, find_pack, packed, png_bytes  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/images"
DART = ROOT / "lib/dungeon_art.dart"
FT2, DIRT1 = "Floor Tiles2.png", "BG Dirt1.png"

# The cave's pieces: (name, pack file, x, y, w, h, whole) — whole: the box's pixels as they are (a tile, a strip that
# tiles); else only the box's largest island.
TILES = [
    ("fill", FT2, 196, 2, 8, 8, True),  # the dark earth's flat fill (inside the big dark column)
    ("moss", FT2, 32, 0, 32, 14, True),  # the moss lip: grass over one row of earth, tiles along x (as town_ground)
    ("ledge", FT2, 32, 0, 32, 32, True),  # the moss-topped block: the near ledge, tiles along x
    ("stalactites", FT2, 224, 96, 64, 40, True),  # the ceiling's strip: the fill and the stalactites under it
    ("earth", DIRT1, 80, 48, 8, 8, True),  # BG Dirt1's flat earth: the floor band
    ("slab", DIRT1, 32, 33, 160, 95, True),  # the back wall's slab, its two holes the tunnels
    ("pillar", DIRT1, 0, 0, 32, 128, True),  # the back wall's pillar
    ("block", FT2, 0, 0, 96, 64, True),  # the moss-topped block's top two rows of 32-px cells: the door's rock mound
]
# The props: (name, pack file, x, y, w, h, frames) — an animation's next frames 32 px along its sheet's row.
PROPS = [
    ("boulder", "Decor.png", 4, 280, 88, 40, 1),  # sprite 86: the mossy boulder pile (a cavern's blocker)
    ("rocks", "Decor.png", 36, 237, 52, 19, 1),  # sprite 79: mossy rocks at the band's foot
    ("rock", "Decor.png", 1, 241, 30, 15, 1),  # sprite 82: a mossy rock
    ("pebbles", "Decor.png", 7, 187, 19, 5, 1),  # sprite 58: pebbles in the grass, on the band
    ("grave0", "Decor.png", 197, 104, 23, 24, 1),  # sprites 25, 26, 28: gravestones; 24: the cross
    ("grave1", "Decor.png", 229, 104, 21, 24, 1),
    ("grave2", "Decor.png", 262, 107, 22, 21, 1),
    ("cross", "Decor.png", 293, 101, 21, 27, 1),
    ("ore0", "Ores.png", 6, 26, 53, 38, 1),  # the four crystal rocks (an ore vein's)
    ("ore1", "Ores.png", 70, 26, 53, 38, 1),
    ("ore2", "Ores.png", 6, 90, 53, 38, 1),
    ("ore3", "Ores.png", 70, 90, 53, 38, 1),
    ("torch", "Torch.png", 0, 97, 12, 31, 6),  # row 3: the wall torch, lit (sprites 21-29, the sparks with them)
    ("standTorch", "Torch.png", 11, 33, 10, 31, 6),  # row 1: the standing torch, lit (sprites 3-11): the door's
]
PORTAL = ("dungeon_portal.png", "Animated Sprites/GandalfHardcore Portal sheet.png", 64)
TILES_W, PROPS_W, FRAME_STEP = 256, 256, 32


def tiles_layout():
    """{name: (x, y, w, h)} in dungeon_tiles.png, and its (width, height)."""
    return packed([(name, w, h) for name, _, _, _, w, h, _ in TILES], TILES_W)


def props_layout():
    """{name: (x, y, w, h)} in dungeon_props.png (an animation's whole row of frames), and its (width, height)."""
    return packed([(name, w * frames, h) for name, _, _, _, w, h, frames in PROPS], PROPS_W)


def images(pack):
    """{out name: (w, h, rgba)} of every file, everything checked before anything is written."""
    sheets = {}

    def sheet(name):
        if name not in sheets:
            if not (pack / name).is_file():
                sys.exit(f"{pack / name}: not found")
            sheets[name] = read_png(pack / name)
        return sheets[name]

    for names in ([t[0] for t in TILES], [p[0] for p in PROPS]):
        if len(set(names)) != len(names):
            sys.exit("TILES / PROPS: a name twice")
    out = {}
    at, (aw, ah) = tiles_layout()
    tiles = bytearray(aw * ah * 4)
    for name, src, x, y, w, h, whole in TILES:
        px = crop(sheet(src), x, y, w, h)
        if not whole:
            px = alone(w, h, px)
        ax, ay, _, _ = at[name]
        for r in range(h):
            o = ((ay + r) * aw + ax) * 4
            tiles[o:o + w * 4] = px[r * w * 4:(r + 1) * w * 4]
    out["dungeon_tiles.png"] = (aw, ah, bytes(tiles))
    at, (aw, ah) = props_layout()
    props = bytearray(aw * ah * 4)
    for name, src, x, y, w, h, frames in PROPS:
        ax, ay, _, _ = at[name]
        for f in range(frames):
            px = crop(sheet(src), x + f * FRAME_STEP, y, w, h)
            if frames == 1:
                px = alone(w, h, px)  # one prop: its own pixels only, never a neighbour's
            for r in range(h):
                o = ((ay + r) * aw + ax + f * w) * 4
                props[o:o + w * 4] = px[r * w * 4:(r + 1) * w * 4]
    out["dungeon_props.png"] = (aw, ah, bytes(props))
    name, src, frame = PORTAL
    w, h, px = sheet(src)
    if w % frame or h % frame:
        sys.exit(f"{src}: {w}x{h} is not a grid of {frame}x{frame} frames")
    out[name] = (w, h, bytes(px))
    return out


def dart_cells(var, at, doc):
    lines = [f"/// {doc}", f"const {var} = <String, DungeonCell>{{"]
    for name, (x, y, w, h) in at.items():
        lines.append(f"  '{name}': (x: {x}, y: {y}, w: {w}, h: {h}),")
    return lines + ["};"]


def dart(made):
    """lib/dungeon_art.dart's text, for the images [made]."""
    tiles, (tw, th) = tiles_layout()
    props, (pw, ph) = props_layout()
    first = {name: (x, y, w // f, h) for (name, (x, y, w, h)), f in
             zip(props.items(), (next(fr for n, *_, fr in PROPS if n == name) for name in props))}
    pwide, phigh, _ = made[PORTAL[0]]
    lines = [
        "// The Dungeon's cave art (decisions-log 336, 337; docs/assets.md \"Packs -> files\"): GandalfHardcore's FREE",
        "// Platformer Assets, cut into assets/images by tool/import_dungeon.py, which writes this file from the same tables.",
        "// Never edit it by hand: `python3 tool/import_dungeon.py --check` fails while it differs. Sizes are in sprite px.",
        "",
        "/// A cell of an atlas: its rect in the file.",
        "typedef DungeonCell = ({int x, int y, int w, int h});",
        "",
        f"/// The cave's pieces ([dungeonTileCells]), {tw}x{th}: the fill, the moss lip, the ledge, the stalactites, the",
        "/// floor band's earth, the back wall's slab and pillar, the door's moss-topped block (its 32-px cells).",
        "const dungeonTiles = 'dungeon_tiles.png';",
        "",
    ]
    lines += dart_cells("dungeonTileCells", tiles, "Each piece's rect in [dungeonTiles].")
    lines += [
        "",
        f"/// The props ([dungeonPropCells]), {pw}x{ph}: an animation's next frames beside its first, [dungeonPropFrames]",
        "/// of them.",
        "const dungeonProps = 'dungeon_props.png';",
        "",
    ]
    lines += dart_cells("dungeonPropCells", first, "Each prop's (first frame's) rect in [dungeonProps].")
    lines += [
        "",
        "/// The props' frames, an animation's (the others one).",
        "const dungeonPropFrames = <String, int>{" + ", ".join(
            f"'{name}': {frames}" for name, *_, frames in PROPS if frames > 1) + "};",
        "",
        f"/// The stairs down: the Portal sheet, [dungeonPortalFrames] frames of [dungeonPortalFrame]x[dungeonPortalFrame] "
        "in a row.",
        "const dungeonPortal = 'dungeon_portal.png';",
        f"const dungeonPortalFrame = {PORTAL[2]}, dungeonPortalFrames = {pwide // PORTAL[2]};",
        "",
        "/// Every file of the Dungeon's cave.",
        "const dungeonImages = [dungeonTiles, dungeonProps, dungeonPortal];",
        "",
    ]
    return "\n".join(lines)


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
            sys.exit("out of date: " + ", ".join(stale) + " (run python3 tool/import_dungeon.py)")
        print("up to date:", len(made), "images and", DART.relative_to(ROOT))
        return
    for name, (w, h, px) in made.items():
        write_png(OUT / name, w, h, px)
    DART.write_text(text)
    print(len(made), "Dungeon images into", OUT.relative_to(ROOT), "and", DART.relative_to(ROOT))


if __name__ == "__main__":
    main(sys.argv[1:])
