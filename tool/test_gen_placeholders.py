"""Tests tool/gen_placeholders.py (decisions-log 157, docs/testing.md "Placeholder art"), in temp dirs only.
- It draws every licensed image of the manifest at its size from the manifest alone (a copy of tool/ with no
  assets/).
- The characters: every frame drawn, its lowest opaque row the feet row (59), nothing below; the shadow colour
  (83,69,69) only in the shadow files and the baked_shadow strips (the Soldier's), and there only in rows 55-59.
- The loot icons are tool/draw_icons.py's drawings, never the real files (their sha256s in tool/assets.sha256).
- The Town scene's pieces (the smith's strip too) are never the real files either, and every frame of a grid and every
  prop cell is drawn.
- It refuses to write over files git tracks: a private repo of its own (its default --out), the same through a
  symlinked folder, and (a dry run, writing nothing) this checkout when its assets/ are tracked, i.e. the private repo.
- It draws the platform icons' placeholder too, lists every file it drew with its sha256 in assets/.placeholders, runs
  again over its own placeholders, and refuses (writing nothing) where a file that isn't its own is there: the real art
  unpacked from the asset vault, git-ignored in the public repo.
Stdlib only, no flutter (git for the refusals):  python3 tool/test_gen_placeholders.py
"""
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TOOL = Path(__file__).resolve().parent
ROOT = TOOL.parent
sys.path.insert(0, str(TOOL))
from build_atlas import read_png  # noqa: E402

MANIFEST = json.loads((TOOL / "asset_manifest.json").read_text())
FILES = MANIFEST["files"]
SHADOW = (83, 69, 69, 255)


def copy_tool(repo):
    """repo/tool with the generator, its PNG writer (build_atlas.py, which imports export_aseprite.py), the loot
    icons' drawings (draw_icons.py) and the manifest: nothing else of this checkout."""
    (repo / "tool").mkdir(parents=True)
    for name in ("gen_placeholders.py", "build_atlas.py", "export_aseprite.py", "draw_icons.py",
                 "make_app_icon.py", "asset_manifest.json"):
        shutil.copy(TOOL / name, repo / "tool" / name)


def gen(repo, *args):
    return subprocess.run([sys.executable, str(repo / "tool/gen_placeholders.py"), *args], capture_output=True,
                          text=True, cwd=repo)


def private_repo(at):
    """A git repo whose index tracks one licensed path, standing for the private repo's real art."""
    copy_tool(at)
    real = at / FILES[-1]["path"]
    real.parent.mkdir(parents=True)
    real.write_bytes(b"the real art")
    subprocess.run(["git", "init", "-q", str(at)], check=True)
    subprocess.run(["git", "-C", str(at), "add", FILES[-1]["path"]], check=True)
    return real


class Placeholders(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp(prefix="placeholders_"))
        cls.repo = cls.tmp / "public"
        copy_tool(cls.repo)
        cls.run_ = gen(cls.repo)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp)

    def test_every_image_from_the_manifest_alone(self):
        self.assertEqual(self.run_.returncode, 0, self.run_.stderr)
        for e in FILES:
            w, h, _ = read_png(self.repo / e["path"])
            self.assertEqual((w, h), (e["width"], e["height"]), e["path"])
        written = sorted(p.relative_to(self.repo).as_posix() for p in (self.repo / "assets").rglob("*") if p.is_file())
        self.assertEqual(written, sorted([e["path"] for e in FILES] + ["assets/.placeholders"]))

    def test_icons_and_the_list_of_what_it_drew(self):
        drawn = json.loads((self.repo / "assets/.placeholders").read_text())
        icons = [p for p in drawn if not p.startswith("assets/")]
        for want in ("macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png", "web/favicon.png",
                     "windows/runner/resources/app_icon.ico", "linux/runner/resources/app_icon.png",
                     "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"):
            self.assertIn(want, icons)
        self.assertEqual(sorted(p for p in drawn if p.startswith("assets/")), sorted(e["path"] for e in FILES))
        for path, h in drawn.items():
            self.assertEqual(hashlib.sha256((self.repo / path).read_bytes()).hexdigest(), h, path)

    def test_runs_again_over_its_own_and_refuses_the_real_art(self):
        repo = self.tmp / "again"
        copy_tool(repo)
        self.assertEqual(gen(repo, "--no-icons").returncode, 0)
        r = gen(repo, "--no-icons")
        self.assertEqual(r.returncode, 0, r.stderr)
        real = repo / FILES[0]["path"]
        real.write_bytes(b"the real art, unpacked from the vault")
        before = {p: p.read_bytes() for p in (repo / "assets").rglob("*") if p.is_file()}
        r = gen(repo, "--no-icons")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("aren't placeholders", r.stderr)
        self.assertEqual({p: p.read_bytes() for p in (repo / "assets").rglob("*") if p.is_file()}, before,
                         "nothing written")

    def test_characters_stand_on_the_feet_row_and_the_shadow_colour_stays_in_the_shadow(self):
        for e in FILES:
            if e["kind"] not in ("character", "shadow"):
                continue
            w, h, px = read_png(self.repo / e["path"])
            (fw, _), (_, feet) = e["frame"], e["feet"]
            shaded = e["kind"] == "shadow" or e.get("baked_shadow", False)
            seen_shadow = False
            for f in range(e["frames"]):
                rows = set()
                for y in range(h):
                    for x in range(f * fw, (f + 1) * fw):
                        c = tuple(px[(y * w + x) * 4:(y * w + x) * 4 + 4])
                        if not c[3]:
                            continue
                        rows.add(y)
                        if c == SHADOW:
                            self.assertTrue(shaded, f"{e['path']}: the shadow colour at ({x}, {y})")
                            self.assertTrue(55 <= y <= 59, f"{e['path']}: the shadow colour on row {y}")
                            seen_shadow = True
                        else:
                            self.assertNotEqual(e["kind"], "shadow", f"{e['path']}: another colour {c}")
                self.assertTrue(rows, f"{e['path']}: frame {f} is empty")
                self.assertEqual(max(rows), feet, f"{e['path']}: frame {f}'s lowest row")
            self.assertEqual(seen_shadow, shaded, e["path"])
        self.assertTrue(any(e.get("baked_shadow") for e in FILES), "the Soldier's strips have their shadow baked in")

    def test_loot_icons_are_the_drawn_ones_never_the_real_art(self):
        from draw_icons import ICONS, pixels
        real = {line.split()[1]: line.split()[0] for line in (TOOL / "assets.sha256").read_text().splitlines()}
        icons = [e for e in FILES if e["kind"] == "icon"]
        self.assertTrue(icons, "the manifest lists the loot icons")
        for e in icons:
            data = (self.repo / e["path"]).read_bytes()
            self.assertNotEqual(hashlib.sha256(data).hexdigest(), real[e["path"]], e["path"])
            stem = Path(e["path"]).stem
            if stem in ICONS and (e["width"], e["height"]) == (32, 32):
                self.assertEqual(read_png(self.repo / e["path"])[2], pixels(ICONS[stem]), e["path"])

    def test_town_pieces_are_drawn_in_every_frame_and_cell_never_the_real_art(self):
        real = {line.split()[1]: line.split()[0] for line in (TOOL / "assets.sha256").read_text().splitlines()}
        town = [e for e in FILES if e["kind"] in ("town", "npc")]
        self.assertTrue(any("cells" in e for e in town), "the manifest lists the props' cells")
        for e in town:
            data = (self.repo / e["path"]).read_bytes()
            self.assertNotEqual(hashlib.sha256(data).hexdigest(), real[e["path"]], e["path"])
            w, _, px = read_png(self.repo / e["path"])
            if "frame" in e:
                fw, fh = e["frame"]
                cells = [[x, y, fw, fh] for y in range(0, e["height"], fh) for x in range(0, w, fw)]
            else:
                cells = e.get("cells", [[0, 0, w, e["height"]]])
            for x0, y0, cw, ch in cells:
                drawn = any(px[((y0 + y) * w + x0 + x) * 4 + 3] for y in range(ch) for x in range(cw))
                self.assertTrue(drawn, f"{e['path']}: the cell at ({x0}, {y0}) is empty")

    def test_refuses_a_private_repo(self):
        repo = self.tmp / "private"
        real = private_repo(repo)
        r = gen(repo)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("refused", r.stderr)
        self.assertEqual(real.read_bytes(), b"the real art")
        self.assertEqual([p for p in (repo / "assets").rglob("*") if p.is_file()], [real], "nothing written")

    def test_refuses_a_private_repo_through_a_symlink(self):
        repo, out = self.tmp / "private2", self.tmp / "linked"
        real = private_repo(repo)
        folder = Path(FILES[-1]["path"]).parent
        (out / folder).parent.mkdir(parents=True)
        (out / folder).symlink_to(repo / folder, target_is_directory=True)
        r = gen(self.repo, "--out", str(out))
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("refused", r.stderr)
        self.assertEqual(real.read_bytes(), b"the real art")
        self.assertEqual([p for p in (repo / folder).iterdir()], [real], "nothing written")

    def test_refuses_this_checkout_when_it_tracks_the_real_art(self):
        r = subprocess.run(["git", "-C", str(ROOT), "ls-files", "--", *[e["path"] for e in FILES]],
                           capture_output=True, text=True)
        if r.returncode != 0 or not r.stdout.strip():
            self.skipTest("assets/ are not tracked here (the public layout): placeholders belong here")
        r = subprocess.run([sys.executable, str(TOOL / "gen_placeholders.py"), "--dry-run"], capture_output=True,
                           text=True)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("refused", r.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
