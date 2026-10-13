"""Tests tool/import_dungeon.py (decisions-log 337; docs/assets.md "Packs -> files"): every box lies inside its sheet
and on the sheet's mapped sprites, the atlases' cells don't overlap, lib/dungeon_art.dart names every cell at its rect,
and --check passes (assets/ and lib/dungeon_art.dart are what the tool writes). It needs the unpacked pack
(raw_sprites/gandalfhardcore-platformer in this checkout or the main one): without it, it skips.
Stdlib only:  python3 tool/test_import_dungeon.py
"""
import re
import subprocess
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import import_dungeon as imp  # noqa: E402
from build_atlas import read_png  # noqa: E402


def find():
    from import_town import main_checkout
    for base in (imp.ROOT, main_checkout()):
        p = base / "raw_sprites/gandalfhardcore-platformer" if base else None
        if p and p.is_dir():
            return p
    return None


PACK = find()


@unittest.skipIf(PACK is None, "the pack isn't unpacked here")
class ImportDungeon(unittest.TestCase):
    def test_every_box_is_inside_its_sheet_and_holds_pixels(self):
        for name, src, x, y, w, h, *rest in imp.TILES + imp.PROPS:
            frames = rest[0] if isinstance(rest[0], int) and not isinstance(rest[0], bool) else 1
            sw, sh, px = read_png(PACK / src)
            for f in range(frames):
                fx = x + f * imp.FRAME_STEP
                self.assertTrue(0 <= fx and 0 <= y and fx + w <= sw and y + h <= sh, f"{name} frame {f} outside {src}")
                opaque = sum(1 for r in range(h) for c in range(w) if px[((y + r) * sw + fx + c) * 4 + 3])
                self.assertGreater(opaque, 0, f"{name} frame {f}: an empty box")

    def test_the_atlases_cells_never_overlap(self):
        for layout in (imp.tiles_layout, imp.props_layout):
            at, (aw, ah) = layout()
            rects = list(at.items())
            for i, (a, (ax, ay, aw_, ah_)) in enumerate(rects):
                self.assertTrue(ax + aw_ <= aw and ay + ah_ <= ah, a)
                for b, (bx, by, bw, bh) in rects[i + 1:]:
                    self.assertFalse(ax < bx + bw and bx < ax + aw_ and ay < by + bh and by < ay + ah_, f"{a} and {b}")

    def test_the_dart_file_names_every_cell_at_its_rect(self):
        text = (imp.ROOT / "lib/dungeon_art.dart").read_text()
        cells = {m[1]: tuple(map(int, m.groups()[1:])) for m in
                 re.finditer(r"'(\w+)': \(x: (\d+), y: (\d+), w: (\d+), h: (\d+)\)", text)}
        for name, rect in imp.tiles_layout()[0].items():
            self.assertEqual(cells[name], rect, name)
        props = {n: f for n, *_, f in imp.PROPS}
        for name, (x, y, w, h) in imp.props_layout()[0].items():
            self.assertEqual(cells[name], (x, y, w // props[name], h), name)

    def test_check_passes(self):
        r = subprocess.run([sys.executable, str(HERE / "import_dungeon.py"), "--check", "--pack", str(PACK)],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr + r.stdout)


if __name__ == "__main__":
    unittest.main()
