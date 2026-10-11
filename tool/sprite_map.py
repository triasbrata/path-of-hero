#!/usr/bin/env python3
"""Maps a sheet's sprites before any is used (the owner, 2026-10-04: "selalu petakan sprite dulu sebelum di gunakan"):
every sprite as its own 8-connected island of opaque pixels, numbered in reading order with its exact box, drawn on a
numbered picture to look at. Unlike asset_meta.py's boxes (an XY cut along clear rows and columns, which puts a stump
standing inside a tree's box into the tree's), a sprite here is only the pixels that touch.

    python3 tool/sprite_map.py <sheet.png> <map.png> [--scale K] [--grid N] [--min PX]

Prints "n x y w h pixels" per sprite (fewer than --min pixels, default 4: left out) and writes <map.png>: the sheet K
times (default 3) on a checker, each sprite's box outlined and its number above its top left; --grid N also draws the
sheet's N-px grid (a modular sheet's cells), faintly. Stdlib only; reads the sheet, writes only <map.png>.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_atlas import read_png, write_png  # noqa: E402

# 3x5 digits, a row of bits a line, top to bottom.
DIGITS = ["111101101101111", "010110010010111", "111001111100111", "111001111001111", "101101111001001",
          "111100111001111", "111100111101111", "111001010010010", "111101111101111", "111101111001111"]
BOX, INK, GRID = (230, 30, 160), (255, 255, 255), (120, 120, 200)


def sprites(w, h, px, least=4):
    """[(x, y, w, h, pixels)] of every 8-connected island of opaque pixels with at least [least] pixels, in reading
    order (top, then left)."""
    seen, out = bytearray(w * h), []
    for start in range(w * h):
        if seen[start] or not px[start * 4 + 3]:
            continue
        seen[start] = 1
        todo, n, x0, y0, x1, y1 = [start], 0, w, h, 0, 0
        while todo:
            i = todo.pop()
            n += 1
            x, y = i % w, i // w
            x0, y0, x1, y1 = min(x0, x), min(y0, y), max(x1, x), max(y1, y)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    j = (y + dy) * w + x + dx
                    if 0 <= x + dx < w and 0 <= y + dy < h and not seen[j] and px[j * 4 + 3]:
                        seen[j] = 1
                        todo.append(j)
        if n >= least:
            out.append((x0, y0, x1 - x0 + 1, y1 - y0 + 1, n))
    return sorted(out, key=lambda s: (s[1], s[0]))


def draw_map(w, h, px, found, k=3, grid=0):
    """The sheet k times on a checker, each found box outlined and numbered; (width, height, rgba)."""
    top = 8  # room for the numbers over a sprite at the sheet's top
    mw, mh = w * k, h * k + top
    out = bytearray(mw * mh * 4)

    def dot(x, y, c):
        if 0 <= x < mw and 0 <= y < mh:
            out[(y * mw + x) * 4:(y * mw + x) * 4 + 4] = bytes((*c, 255))
    for y in range(mh):
        for x in range(mw):
            sx, sy = x // k, (y - top) // k
            if y >= top and px[(sy * w + sx) * 4 + 3]:
                i, a = (sy * w + sx) * 4, px[(sy * w + sx) * 4 + 3] / 255
                c = 200 if (x // 6 + y // 6) % 2 else 228
                dot(x, y, tuple(round(px[i + j] * a + c * (1 - a)) for j in range(3)))
            else:
                c = 200 if (x // 6 + y // 6) % 2 else 228
                dot(x, y, GRID if grid and y >= top and (sx % grid == 0 and x % k == 0 or sy % grid == 0
                                                         and (y - top) % k == 0) else (c, c, c))
    for n, (x, y, bw, bh, _) in enumerate(found):
        x0, y0, x1, y1 = x * k - 1, y * k + top - 1, (x + bw) * k, (y + bh) * k + top
        for xx in range(x0, x1 + 1):
            dot(xx, y0, BOX)
            dot(xx, y1, BOX)
        for yy in range(y0, y1 + 1):
            dot(x0, yy, BOX)
            dot(x1, yy, BOX)
        label = str(n)
        lx, ly = max(0, x0 + 1), max(0, y0 - 7)
        for d, ch in enumerate(label):  # each digit 3x5 at 1 px, on a dark plate
            for yy in range(7):
                for xx in range(5):
                    dot(lx + d * 4 + xx - 1, ly + yy - 1, (20, 20, 20))
            for b, bit in enumerate(DIGITS[int(ch)]):
                if bit == "1":
                    dot(lx + d * 4 + b % 3, ly + b // 3, INK)
    return mw, mh, bytes(out)


def main(args):
    k, grid, least, files = 3, 0, 4, []
    while args:
        if args[0] in ("--scale", "--grid", "--min") and len(args) > 1:
            v = int(args[1])
            k, grid, least = (v, grid, least) if args[0] == "--scale" else (k, v, least) if args[0] == "--grid" \
                else (k, grid, v)
            args = args[2:]
        else:
            files, args = files + [args[0]], args[1:]
    if len(files) != 2:
        sys.exit(__doc__)
    w, h, px = read_png(Path(files[0]))
    found = sprites(w, h, px, least)
    print(f"{files[0]}: {w}x{h}, {len(found)} sprites (n x y w h pixels)")
    for n, s in enumerate(found):
        print(n, *s)
    write_png(Path(files[1]), *draw_map(w, h, px, found, k, grid))


if __name__ == "__main__":
    main(sys.argv[1:])
