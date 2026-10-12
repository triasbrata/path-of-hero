"""Writes tool/asset_manifest.json and tool/assets.sha256 from the licensed files under assets/ (decisions-log 157),
and tool/placeholders.gitignore from LICENSED (decisions-log 287: a pattern added here and not there failed the suite).

The packs' files can't go into a public repo (their stores forbid re-sharing them), so the public repo carries only
what these two files say about them: every licensed file's path, byte size, image size and the frame grid where the
code cuts it (the manifest, which tool/gen_placeholders.py draws placeholders from), and its sha256 (assets.sha256,
in `shasum -a 256 -c` form, run from the repo root). Our own files and open ones (the music, the sfx, the AI's
thresholds, the OFL fonts) are listed by OWN and left out: they are in the repo themselves.

Run it after any change under assets/; test/asset_manifest_test.dart fails while the three files are out of date.
Stdlib only:  python3 tool/asset_manifest.py [--check]
(--check writes nothing: it exits 1 and names what differs.) It only reads assets/; it never writes there.
"""
import fnmatch
import hashlib
import json
import re
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from build_atlas import read_png  # noqa: E402
from import_town import props_layout, yards_layout  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "tool/asset_manifest.json"
HASHES = ROOT / "tool/assets.sha256"
GITIGNORE = ROOT / "tool/placeholders.gitignore"
IGNORE_HEAD = """\
# What tool/gen_placeholders.py writes: the licensed files, one line per "licensed" pattern of
# tool/asset_manifest.json (test/asset_manifest_test.dart checks they agree). Written by tool/asset_manifest.py from its
# LICENSED. The public export appends these lines to the PUBLIC repo's .gitignore, never to this private repo's, whose
# assets/ are the real art (docs/assets.md "Placeholder art").
"""

# Every file under assets/ is licensed (first matching pattern: its kind) or our own; anything else stops the tool,
# so a new kind of asset gets its licence checked first (docs/itch-page.md "Licences"). A `*` never crosses a `/`.
LICENSED = [
    ("assets/images/tiny_arrow_*.png", "arrow"),
    ("assets/images/tiny_fx_*.png", "burst"),
    ("assets/images/tiny_*_shadow.png", "shadow"),
    ("assets/images/tiny_*.png", "character"),
    ("assets/images/fx_*.png", "burst"),
    ("assets/images/ui_*.png", "ui"),
    ("assets/images/battle_floor.png", "floor"),
    ("assets/images/battle_props.png", "props"),
    ("assets/images/battle_clouds.png", "clouds"),
    ("assets/images/battle_step.png", "step"),
    ("assets/images/item_*.png", "icon"),
    ("assets/images/relic_*.png", "icon"),
    ("assets/images/artifact_icons.png", "icon"),
    ("assets/images/town_mark.png", "icon"),
    ("assets/images/town_mug.png", "icon"),
    ("assets/images/mat_*.png", "icon"),
    ("assets/images/town_bg_*.png", "town"),
    ("assets/images/town_castle.png", "town"),
    ("assets/images/town_ground.png", "town"),
    ("assets/images/town_house.png", "town"),
    ("assets/images/town_smithy.png", "town"),
    ("assets/images/town_campfire.png", "town"),
    ("assets/images/town_tent.png", "town"),
    ("assets/images/town_ore.png", "town"),
    ("assets/images/town_pine.png", "town"),
    ("assets/images/town_props.png", "town"),
    ("assets/images/town_autumn_*.png", "town"),
    ("assets/images/town_winter_*.png", "town"),
    ("assets/images/town_ground_*.png", "town"),
    ("assets/images/town_yards.png", "town"),
    ("assets/images/town_smith.png", "npc"),
]
OWN = [
    "assets/ai/*.json",  # RetreatBrain's thresholds
    "assets/config/*.json",  # the owner's tuning files: TownRules' numbers (lib/town.dart)
    "assets/fonts/PohSans.ttf",  # the game's font: Pixelify Sans redrawn (tool/make_poh_sans.py), SIL OFL 1.1
    "assets/fonts/PixelifySans*.ttf",  # Pixelify Sans, the same OFL: retired, deleted once the game is closed
    "assets/fonts/PohDigits-*.ttf",  # its 5, B, C, G redrawn, the same OFL: retired too
    "assets/fonts/OFL-*.txt",  # their licences
    "assets/music/*.ogg",  # tool/gen_music.py
    "assets/sfx/*.wav",  # tool/gen_sfx.py
]

# What each kind is and where the code cuts it (frame = the cell the code cuts, frames = how many there are).
KINDS = {
    "character": "a Tiny RPG strip of square frames facing right, the feet at `feet` (lib/main.dart _feet, _frame); "
                 "baked_shadow: the strip has the shadow colour (83,69,69) in rows 55-59 (only the Soldier's; "
                 "TdGame.onLoad clears it, test/sprites_test.dart)",
    "shadow": "the ground shadow under a character, the shadow colour (83,69,69) in rows 55-59, one frame",
    "arrow": "a projectile pointing right, one frame (lib/main.dart _arrows)",
    "burst": "an effect strip of square frames: tiny_fx_* sit on the feet, fx_* are centred on the body "
             "(lib/main.dart _burstStrip, hero_skill_fx.dart); tiny_fx_wizard_* are the wizard's shots and their "
             "hits, a frame's point (55, 51) or (53, 50) on the shot (lib/wizard_fx.dart WizardMagic)",
    "ui": "a Cute Fantasy UI sheet: with frame, a grid of cells (icons, buttons, the click and loading frames); "
          "without, the code cuts rects of its own out of it (docs/ui-hud.md)",
    "floor": "the battle field's floor (tool/import_battle_floor.py, decisions-log 228, 244, 263): GandalfHardcore "
             "FREE Platformer pieces (Tall Grass's blades in rows, a ground line of Pine forest's flower tufts and "
             "Decor's ferns, bushes and rocks doubled, Decor's pebbles, a Floor Tiles1 cell's top rows along the "
             "bottom, under the field's) at the parallax layers' 5 px a world unit, drawn whole and tiled sideways with "
             "the field (lib/main.dart floorCopies); opaque from the horizon (row 40) down, clear above it but for the "
             "ground line and the blade tips",
    "props": "the battle's props line at the horizon (tool/import_battle_floor.py, decisions-log 244): GandalfHardcore "
             "FREE Platformer pieces (Pine forest's trunks, pine and log, Decor's boulders, rocks, bushes and ferns, "
             "doubled; Tree1 and Tree2) at the parallax layers' 5 px a world unit, from the band's top down to their "
             "feet two rows over the bottom, drawn whole and tiled sideways (lib/main.dart propsCopies); clear between "
             "the props",
    "clouds": "the battle's clouds (tool/import_battle_floor.py, decisions-log 244): GandalfHardcore FREE Platformer's "
              "cloud1..cloud6 scattered over a clear strip at the parallax layers' 5 px a world unit, drawn whole, "
              "tiled sideways and drifting (lib/main.dart cloudCopies)",
    "step": "the spawn bar's step (tool/import_battle_floor.py, decisions-log 287, 295): a strip of ground at the "
            "parallax layers' 5 px a world unit, a little hill (32 px of low ground, its grass 60 rows down; a slope "
            "up over 96; 96 of the step's top; a slope down over 96; 32 of low ground), every column GandalfHardcore "
            "FREE Platformer's Floor Tiles1 grass-topped cell's lowered to the ground's height there, earth under it; "
            "cut into pieces (lib/spawn_bar.dart _barStep: the slopes, the top's middle cell tiled, the earth "
            "stretched; lib/main.dart _underFloor)",
    "icon": "Cute Fantasy Icons Premium's 16 px art doubled: a loot icon (item_<Item>, relic_<Relic>), one frame drawn "
            "whole (TdGame._icon in lib/main.dart, IconRef in lib/pusaka_catalog.dart); artifact_icons.png, the "
            "Artifacts' icons on a grid of 32x32 cells, one a kind (lib/artifact_icons.dart); town_mark.png and "
            "town_mug.png, the Towns' hammer and beer mug, one frame drawn whole each (lib/town_look.dart); mat_<Mat>, a "
            "material's, one frame drawn whole (TdGame._icon)",
    "town": "a GandalfHardcore FREE Platformer piece of the Town scene (tool/import_town.py, lib/town_art.dart): the "
            "parallax layers and the castle (town_bg_1..5: the near pines and ground .. the sky, also the battle's "
            "band above the field, lib/main.dart backdropLayers; town_castle), drawn whole and tiled sideways; the street (town_ground: a grass top over its earth, tiled along it); the house's 16x16 cells (town_house; the "
            "porch's are 16x8 at the top of theirs); the smithy's 64x64 frames (row 0 the furnace, row 1 the "
            "sawmill) and the campfire's 32x32 ones (a row a loop); single pieces (town_tent, town_ore, town_pine); "
            "and the props' atlas (town_props), its rects in cells; the Towns' identities (decisions-log 326): the "
            "Autumn and Winter sets (town_autumn_bg_1..5, town_autumn_castle, town_winter_*), drawn as the Normal one, "
            "their streets (town_ground_autumn, town_ground_winter) and the yards' atlas (town_yards), its rects in "
            "cells (an animation's frames side by side in its cell)",
    "npc": "the Town's smith (tool/import_smith.py, lib/town_smith_art.dart, decisions-log 265): the Mana Seed "
           "Character Base demo's paper doll (body, outfit, hair, the mace for a hammer) facing right at Pixel "
           "Crawler's anvil, a strip of frames (backswing, raised, swing, strike, rest), the anvil at the same place in "
           "each, his feet on the frame's bottom row; drawn at 1 world px a sprite px",
}


def smith_frame():
    """The smith's frame (w, h), as tool/import_smith.py wrote it into lib/town_smith_art.dart."""
    m = re.search(r"townSmithW = (\d+), townSmithH = (\d+)", (ROOT / "lib/town_smith_art.dart").read_text())
    return int(m[1]), int(m[2])


# The sheets the code cuts on a grid (cell w, h): ui_icons' 16x16 icons, ui_buttons' 32x16 buttons, the click's and
# the loading dial's 16x16 frames; artifact_icons' 32x32 Artifact icons; the Town's house cells, smithy frames and
# campfire frames; the smith's frames.
GRID = {"ui_icons.png": (16, 16), "ui_buttons.png": (32, 16), "ui_click.png": (16, 16), "ui_loading.png": (16, 16),
        "artifact_icons.png": (32, 32), "town_house.png": (16, 16), "town_smithy.png": (64, 64),
        "town_campfire.png": (32, 32), "town_smith.png": smith_frame()}
# The atlases the code cuts by rects of their own ([x, y, w, h] a cell): the Town's props and yards (tool/import_town.py).
CELLS = {"town_props.png": [list(r) for r in props_layout()[0].values()],
         "town_yards.png": [list(r) for r in yards_layout()[0].values()]}
FEET = (50, 59)
SHADOW_INK, SHADOW_ROWS = (83, 69, 69), (55, 59)


def kind_of(rel):
    for pattern, kind in LICENSED:
        if fnmatch.fnmatchcase(rel, pattern) and rel.count("/") == pattern.count("/"):
            return kind
    if any(fnmatch.fnmatchcase(rel, p) and rel.count("/") == p.count("/") for p in OWN):
        return None
    sys.exit(f"{rel}: neither licensed nor our own; add it to LICENSED or OWN in tool/asset_manifest.py "
             "once its licence is checked (docs/itch-page.md \"Licences\")")


def png_size(data):
    assert data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR", "not a PNG"
    return struct.unpack(">II", data[16:24])


def baked_shadow(path):
    w, h, px = read_png(path)
    for y in range(SHADOW_ROWS[0], min(SHADOW_ROWS[1] + 1, h)):
        for x in range(w):
            i = (y * w + x) * 4
            if px[i + 3] and tuple(px[i:i + 3]) == SHADOW_INK:
                return True
    return False


def entry(path, rel, kind, data):
    e = {"path": rel, "bytes": len(data), "kind": kind}
    w, h = png_size(data)
    e.update(width=w, height=h)
    cell = (GRID.get(path.name) if kind in ("ui", "town") else None if kind in ("floor", "props", "clouds", "step")
            else GRID.get(path.name, (h, h)))
    if cell:
        e.update(frame=list(cell), frames=(w // cell[0]) * (h // cell[1]))
    if path.name in CELLS:
        e["cells"] = CELLS[path.name]
    if kind in ("character", "shadow"):
        e["feet"] = list(FEET)
    if kind == "character" and baked_shadow(path):
        e["baked_shadow"] = True
    return e


def build():
    entries, hashes = [], []
    for path in sorted((ROOT / "assets").rglob("*")):
        if not path.is_file() or path.name.startswith("."):
            continue
        rel = path.relative_to(ROOT).as_posix()
        kind = kind_of(rel)
        if kind is None:
            continue
        data = path.read_bytes()
        entries.append(entry(path, rel, kind, data))
        hashes.append(f"{hashlib.sha256(data).hexdigest()}  {rel}\n")
    head = {
        "about": "The licensed files under assets/, which a public repo can't hold: written by tool/asset_manifest.py "
                 "from the private repo's assets/, read by tool/gen_placeholders.py (docs/assets.md \"Placeholder "
                 "art\"). Their sha256s are in tool/assets.sha256.",
        "kinds": KINDS,
        "licensed": [p for p, _ in LICENSED],
        "own": OWN,
    }
    # One file per line, so a diff shows which file changed.
    lines = json.dumps(head, indent=2, ensure_ascii=False)[:-2] + ',\n  "files": [\n'
    lines += ",\n".join("    " + json.dumps(e, ensure_ascii=False) for e in entries) + "\n  ]\n}\n"
    return lines, "".join(hashes)


def ignored():
    """tool/placeholders.gitignore: `/` + each LICENSED pattern, in its order."""
    return IGNORE_HEAD + "".join(f"/{p}\n" for p, _ in LICENSED)


def main(args):
    manifest, hashes = build()
    ignore = ignored()
    if args == ["--check"]:
        stale = [f.relative_to(ROOT).as_posix() for f, text in ((MANIFEST, manifest), (HASHES, hashes), (GITIGNORE, ignore))
                 if not f.exists() or f.read_text() != text]
        if stale:
            sys.exit("out of date: " + ", ".join(stale) + " (run python3 tool/asset_manifest.py)")
        print("up to date")
        return
    if args:
        sys.exit(__doc__)
    MANIFEST.write_text(manifest)
    HASHES.write_text(hashes)
    GITIGNORE.write_text(ignore)
    print(manifest.count('"path"'), "licensed files in", MANIFEST.relative_to(ROOT), "and", HASHES.relative_to(ROOT),
          f"({ignore.count(chr(10) + '/')} patterns in {GITIGNORE.relative_to(ROOT)})")


if __name__ == "__main__":
    main(sys.argv[1:])
