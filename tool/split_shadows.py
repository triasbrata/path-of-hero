"""Splits the baked-in shadow off the Tiny RPG strips in assets/images.

Each tiny_<key>_<anim>.png is matched (byte for byte) to its "<Char> with shadows" source in raw_assets,
replaced by the shadowless sibling from "<Char>/", and one tiny_<key>_shadow.png (a single 100x100 frame)
is written per character, so the game can draw the shadow on the ground while the body hops.
Stdlib only:  python3 tool/split_shadows.py   (run once; already-split files no longer match and are skipped)
"""
import hashlib
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from build_atlas import read_png, write_png  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
IMAGES = ROOT / "assets/images"
PACK = ROOT / "raw_assets/Tiny RPG Character Asset Pack 01 v2.0 -Full 22 Characters/Characters(100x100 split)"
FS = 100


def md5(p):
    return hashlib.md5(p.read_bytes()).hexdigest()


def main():
    sources = {md5(p): p for p in PACK.glob("*/* with shadows/*.png")}
    shadow = {}  # key -> set of (x, y) shadow pixels, gathered over every frame of every strip
    color = {}
    for asset in sorted(IMAGES.glob("tiny_*.png")):
        m = re.fullmatch(r"tiny_(.+)_(idle|walk|attack|hurt|death|summon)\.png", asset.name)
        if not m or m[1].startswith(("arrow", "fx")):
            continue
        src = sources.get(md5(asset))
        if src is None:
            print("skip (no shadowed source, already split?):", asset.name)
            continue
        plain = src.parent.parent / src.parent.name.removesuffix(" with shadows") / src.name
        w, h, a = read_png(src)
        _, _, b = read_png(plain)
        if m[2] in ("idle", "walk"):
            px = shadow.setdefault(m[1], set())
            for y in range(h):
                for x in range(w):
                    i = (y * w + x) * 4
                    if a[i:i + 4] != b[i:i + 4] and b[i + 3] == 0:
                        px.add((x % FS, y))
                        color[m[1]] = a[i:i + 4]
        asset.write_bytes(plain.read_bytes())
        print("split", asset.name)

    for key, px in shadow.items():
        if not px:  # the pack's "Soldier with shadows" has no shadow: borrow a humanoid one
            px, color[key] = shadow["knight"], color["knight"]
        # Feet hide bits of the shadow in every frame: fill each row between its outermost pixels.
        out = bytearray(FS * FS * 4)
        for y in {y for _, y in px}:
            xs = [x for x, yy in px if yy == y]
            for x in range(min(xs), max(xs) + 1):
                out[(y * FS + x) * 4:(y * FS + x) * 4 + 4] = color[key]
        write_png(IMAGES / f"tiny_{key}_shadow.png", FS, FS, out)
        print("shadow", key, len(px), "px")


main()
