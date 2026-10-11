#!/usr/bin/env python3
"""Builds the game's font, Poh Sans (decisions-log 179; docs/ui-hud.md "The font"): Pixelify Sans with 13 glyphs
redrawn, its kerning and everything else kept.

Pixelify Sans draws on a grid of 1000/11 units and grows bolder by growing every pixel on that grid (one gvar tuple,
peak wght 700), so a one-pixel gap is 80 units at weight 400, 65 at 500 and 34 at 700, and at the HUD's sizes it blurs
shut: "Cara Main" read "Oara Main", "Kocok" "Koook", "Bos" "Gos", the i's dot ran into its stem. Poh Sans redraws the
glyphs whose shapes close up (test/letter_shapes_test.dart: every two of A-Z, a-z, 0-9 drawn apart):
- C, c: open over three rows (the capital) and two (the lower case), where the font's are an O with one pixel out;
- B: a flat left side and a narrower top bowl (the font's read as an 8 or a G); G: the new C with a bar on its fifth
  row;
- i: its dot a row higher, two rows clear of the stem (the font's i was its l with one pixel out);
- a: a square top right and a flat foot, where the font's was an o with a loose tail pixel;
- 5: a flat top and a square corner (the font's was its S with two pixels moved);
- S, 2, 3, 6, 9: the font draws each as its 8 with a pixel or two moved, so in bold they ran into the 8 and each
  other: the S without its terminals, the 2 with a flat foot, the 3 with a short middle bar, the 6 without its top
  terminal and the 9 without its bottom one;
- Z: a straight diagonal, where the font's was its 2 with two square corners.
Each keeps its advance and its left side bearing. A redrawn glyph is its pixels' outline at the default weight (400)
plus one gvar delta set (the same pixels at 700 less those at 400 for every point, and the four phantom points'
deltas copied from the font), on the font's own shared tuple, so it grows on the grid as the font's glyphs do. The composites
built on them (Ç, Ć, Ĝ, Ź, á, ä, ç, …) follow. GPOS (the kerning), GSUB, GDEF, HVAR, MVAR, cmap, post and every other
glyph are the font's bytes. Its names are new (the OFL's Modified Version): family "Poh Sans", PostScript "PohSans"
(name IDs 1, 3, 4, 6 and 25; the font has no 16 or 17); fvar and STAT name only the axis and the weights (name IDs 256-260: Weight,
Regular, Medium, SemiBold, Bold), which stay.

The source is tool/fonts/PixelifySans.ttf, google/fonts' ofl/pixelifysans/PixelifySans[wght].ttf unmodified (its
sha256 is pinned below and in CREDITS.md). For each redrawn glyph the tool first asserts that the pixel model below
rebuilds the font's own outline from the "old" rows at 400 and at 700 (within one unit, the font's interpolated
points), then draws the "new" rows. Only the standard library; no timestamps: a rerun writes the same bytes
(test/poh_sans_test.dart pins their sha256).

Usage: python3 tool/make_poh_sans.py          writes assets/fonts/PohSans.ttf
       python3 tool/make_poh_sans.py --check  only checks that the file on disk is what it would write
       python3 tool/make_poh_sans.py --show   prints each glyph old and new on the pixel grid
"""
import hashlib
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'tool/fonts/PixelifySans.ttf'
SOURCE_SHA256 = '9ba86cd010a4de309d263ceff8e8044092c9db7efda869620cb9ff1c4389e8a5'
OUT = ROOT / 'assets/fonts/PohSans.ttf'
FAMILY, POSTSCRIPT = 'Poh Sans', 'PohSans'

# The font's pixel edges, in units: a column's left and right, a row's bottom and top (row 0 sits on the baseline,
# row 6 is the cap height's, rows -1 and -2 the descenders'), each as (at wght 400, its move to 700). A pixel is about
# 101 units wide at 400 and 127 at 700 on the 1000/11 grid. The font's own glyphs are built on exactly these.
COLUMNS = {0: ((60, 1), (161, 27)), 1: ((151, -2), (251, 25)), 2: ((241, -4), (343, 22)), 3: ((333, -7), (433, 20)),
           4: ((423, -9), (525, 17)), 5: ((515, -12), (616, 15)), 6: ((606, -14), (706, 12))}
ROWS = {-2: ((-193, 11), (-93, 47)), -1: ((-103, 6), (-3, 42)), 0: ((-12, 1), (88, 37)), 1: ((78, -4), (179, 32)),
        2: ((169, -9), (270, 27)), 3: ((260, -14), (359, 22)), 4: ((350, -19), (450, 17)), 5: ((440, -24), (540, 12)),
        6: ((530, -29), (631, 7)), 7: ((617, -34), (718, 2))}

# Each redrawn glyph: its character, its top row, and the font's rows and the new ones on the pixel grid, the top row
# first (the x-height letters' top row is 4, the capitals' and digits' 6).
GLYPHS = [
    ('2', 6, ['.###.', '#...#', '....#', '.###.', '#....', '#...#', '.###.'],
             ['.###.', '#...#', '....#', '.###.', '#....', '#....', '#####']),
    ('3', 6, ['.###.', '#...#', '....#', '.###.', '....#', '#...#', '.###.'],
             ['.###.', '#...#', '....#', '..##.', '....#', '#...#', '.###.']),
    ('5', 6, ['.###.', '#...#', '#...#', '.#...', '..##.', '#...#', '.###.'],
             ['#####', '#....', '####.', '....#', '....#', '#...#', '.###.']),
    ('6', 6, ['.###.', '#...#', '#....', '####.', '#...#', '#...#', '.###.'],
             ['.###.', '#....', '#....', '####.', '#...#', '#...#', '.###.']),
    ('9', 6, ['.###.', '#...#', '#...#', '.####', '....#', '#...#', '.###.'],
             ['.###.', '#...#', '#...#', '.####', '....#', '....#', '.###.']),
    ('B', 6, ['.###.', '#...#', '#...#', '#.##.', '#...#', '#...#', '.###.'],
             ['###..', '#..#.', '#..#.', '####.', '#...#', '#...#', '####.']),
    ('C', 6, ['.###.', '#...#', '#...#', '#....', '#...#', '#...#', '.###.'],
             ['.###.', '#...#', '#....', '#....', '#....', '#...#', '.###.']),
    ('G', 6, ['.###.', '#...#', '#...#', '#.#..', '#..##', '#...#', '.###.'],
             ['.###.', '#...#', '#....', '#....', '#.###', '#...#', '.###.']),
    ('S', 6, ['.###.', '#...#', '#....', '.###.', '....#', '#...#', '.###.'],
             ['.###.', '#....', '#....', '.###.', '....#', '....#', '.###.']),
    ('Z', 6, ['####.', '#...#', '....#', '.###.', '#....', '#...#', '.####'],
             ['#####', '....#', '...#.', '..#..', '.#...', '#....', '#####']),
    ('a', 4, ['.###..', '#...#.', '#...#.', '#...#.', '.###.#'],
             ['.####.', '#...#.', '#...#.', '#...#.', '.#####']),
    ('c', 4, ['.###.', '#...#', '#....', '#...#', '.###.'],
             ['.###.', '#...#', '#....', '#....', '.###.']),
    ('i', 7, ['.', '#', '.', '#', '#', '#', '#', '#'],
             ['#', '.', '.', '#', '#', '#', '#', '#']),
]


class Font:
    """The parts of a TrueType variable font this tool reads."""

    def __init__(self, data):
        self.d = data
        self.tables = {}
        for i in range(self.u16(4)):
            tag, _, off, length = struct.unpack('>4sIII', data[12 + 16 * i:28 + 16 * i])
            self.tables[tag.decode()] = (off, length)
        self.glyphs = self.u16(self.tables['maxp'][0] + 4)
        self.long_loca = self.i16(self.tables['head'][0] + 50) == 1

    def u16(self, o):
        return struct.unpack('>H', self.d[o:o + 2])[0]

    def i16(self, o):
        return struct.unpack('>h', self.d[o:o + 2])[0]

    def u32(self, o):
        return struct.unpack('>I', self.d[o:o + 4])[0]

    def table(self, tag):
        off, length = self.tables[tag]
        return self.d[off:off + length]

    def glyph_of(self, char):
        """The glyph id for [char] from the cmap's format 4 subtable."""
        cm = self.tables['cmap'][0]
        for i in range(self.u16(cm + 2)):
            st = cm + self.u32(cm + 8 + 8 * i)
            if self.u16(st) != 4:
                continue
            segs = self.u16(st + 6) // 2
            ends, starts = st + 14, st + 16 + 2 * segs
            deltas, ranges = starts + 2 * segs, starts + 4 * segs
            c = ord(char)
            for k in range(segs):
                if self.u16(starts + 2 * k) <= c <= self.u16(ends + 2 * k):
                    ro = self.u16(ranges + 2 * k)
                    if ro == 0:
                        return (c + self.i16(deltas + 2 * k)) & 0xFFFF
                    g = self.u16(ranges + 2 * k + ro + 2 * (c - self.u16(starts + 2 * k)))
                    return (g + self.i16(deltas + 2 * k)) & 0xFFFF if g else 0
        raise ValueError(char)

    def glyph_bytes(self, g):
        """Glyph [g]'s bytes in glyf (empty for a glyph without contours)."""
        loca, glyf = self.tables['loca'][0], self.tables['glyf'][0]
        if self.long_loca:
            a, b = self.u32(loca + 4 * g), self.u32(loca + 4 * g + 4)
        else:
            a, b = self.u16(loca + 2 * g) * 2, self.u16(loca + 2 * g + 2) * 2
        return self.d[glyf + a:glyf + b]

    def outline(self, g):
        """Glyph [g]'s contour ends and points (x, y, on curve), at the default instance (wght 400)."""
        b = self.glyph_bytes(g)
        if not b:
            return [], []
        n = struct.unpack('>h', b[:2])[0]
        assert n > 0, 'a simple glyph'
        ends = list(struct.unpack('>%dH' % n, b[10:10 + 2 * n]))
        p = 12 + 2 * n + struct.unpack('>H', b[10 + 2 * n:12 + 2 * n])[0]
        count, flags = ends[-1] + 1, []
        while len(flags) < count:
            f = b[p]
            p += 1
            flags.append(f)
            if f & 8:
                flags += [f] * b[p]
                p += 1
        coords = []
        for short, same in ((2, 16), (4, 32)):
            v, out = 0, []
            for f in flags:
                if f & short:
                    v += b[p] if f & same else -b[p]
                    p += 1
                elif not f & same:
                    v += struct.unpack('>h', b[p:p + 2])[0]
                    p += 2
                out.append(v)
            coords.append(out)
        return ends, [(x, y, f & 1) for x, y, f in zip(*coords, flags)]

    def metric(self, g):
        """Glyph [g]'s advance and left side bearing (hmtx)."""
        n = self.u16(self.tables['hhea'][0] + 34)
        hmtx = self.tables['hmtx'][0]
        adv = self.u16(hmtx + 4 * min(g, n - 1))
        lsb = self.i16(hmtx + 4 * g + 2) if g < n else self.i16(hmtx + 4 * n + 2 * (g - n))
        return adv, lsb

    def gvar_header(self):
        gv = self.tables['gvar'][0]
        axes, shared_n, shared_at = self.u16(gv + 4), self.u16(gv + 6), self.u32(gv + 8)
        count, flags, data_at = self.u16(gv + 12), self.u16(gv + 14), self.u32(gv + 16)
        assert axes == 1 and count == self.glyphs and 'avar' not in self.tables
        return gv, shared_n, shared_at, flags, data_at

    def gvar_bytes(self, g):
        gv, _, _, flags, data_at = self.gvar_header()
        if flags & 1:
            a, b = self.u32(gv + 20 + 4 * g), self.u32(gv + 24 + 4 * g)
        else:
            a, b = self.u16(gv + 20 + 2 * g) * 2, self.u16(gv + 22 + 2 * g) * 2
        return self.d[gv + data_at + a:gv + data_at + b]

    def shared_tuples(self):
        gv, shared_n, shared_at, _, _ = self.gvar_header()
        return [self.i16(gv + shared_at + 2 * i) / 16384 for i in range(shared_n)]

    def tuples(self, g):
        """Glyph [g]'s tuples: (shared tuple index or None, peak, start, end, its x and y deltas for every point and
        the four phantom points, IUP applied to the points it leaves out)."""
        ends, pts = self.outline(g)
        n = len(pts) + 4
        xs, ys = [p[0] for p in pts] + [0] * 4, [p[1] for p in pts] + [0] * 4
        b = self.gvar_bytes(g)
        if not b:
            return []
        shared = self.shared_tuples()
        u16 = lambda o: struct.unpack('>H', b[o:o + 2])[0]
        i16 = lambda o: struct.unpack('>h', b[o:o + 2])[0]
        count, sp, hp = u16(0), u16(2), 4
        shared_pts = None
        if count & 0x8000:
            shared_pts, sp = _points(b, sp)
        out = []
        for _ in range(count & 0x0FFF):
            size, index = u16(hp), u16(hp + 2)
            hp += 4
            if index & 0x8000:
                peak, which = i16(hp) / 16384, None
                hp += 2
            else:
                peak, which = shared[index & 0x0FFF], index & 0x0FFF
            start = end = None
            if index & 0x4000:
                start, end = i16(hp) / 16384, i16(hp + 2) / 16384
                hp += 4
            begin = sp
            touched, q = _points(b, sp) if index & 0x2000 else (shared_pts, sp)
            k = n if touched is None else len(touched)
            ddx, q = _deltas(b, q, k)
            ddy, q = _deltas(b, q, k)
            sp = begin + size
            idx = list(range(n)) if touched is None else touched
            tx, ty, hit = [0.0] * n, [0.0] * n, [False] * n
            for j, i in enumerate(idx):
                tx[i], ty[i], hit[i] = ddx[j], ddy[j], True
            if touched is not None:
                tx, ty = _iup(ends, xs, tx, hit), _iup(ends, ys, ty, hit)
            out.append((which, peak, start, end, tx, ty))
        return out

    def instance(self, g, weight):
        """Glyph [g]'s contours (rounded points) and advance at wght [weight] (400..700, the default 400)."""
        ends, pts = self.outline(g)
        loc = (weight - 400) / 300
        n = len(pts) + 4
        dx, dy = [0.0] * n, [0.0] * n
        for _, peak, start, end, tx, ty in self.tuples(g):
            s = _scalar(loc, peak, start, end)
            for i in range(n):
                dx[i] += s * tx[i]
                dy[i] += s * ty[i]
        contours, s = [], 0
        for e in ends:
            contours.append([(round(pts[i][0] + dx[i]), round(pts[i][1] + dy[i])) for i in range(s, e + 1)])
            s = e + 1
        return contours, self.metric(g)[0] + dx[n - 3] - dx[n - 4]


def _points(b, p):
    n = b[p]
    p += 1
    if n == 0:
        return None, p
    if n & 0x80:
        n = ((n & 0x7F) << 8) | b[p]
        p += 1
    out, last = [], 0
    while len(out) < n:
        ctl = b[p]
        p += 1
        for _ in range((ctl & 0x7F) + 1):
            if ctl & 0x80:
                last += struct.unpack('>H', b[p:p + 2])[0]
                p += 2
            else:
                last += b[p]
                p += 1
            out.append(last)
    return out, p


def _deltas(b, p, n):
    out = []
    while len(out) < n:
        ctl = b[p]
        p += 1
        run = (ctl & 0x3F) + 1
        if ctl & 0x80:
            out += [0] * run
        elif ctl & 0x40:
            out += list(struct.unpack('>%dh' % run, b[p:p + 2 * run]))
            p += 2 * run
        else:
            out += list(struct.unpack('%db' % run, b[p:p + run]))
            p += run
    return out, p


def _scalar(loc, peak, start, end):
    if peak == 0:
        return 1.0
    if start is not None:
        if loc < start or loc > end:
            return 0.0
        if loc < peak:
            return (loc - start) / (peak - start) if peak != start else 1.0
        return (end - loc) / (end - peak) if end != peak else 1.0
    if loc * peak <= 0 or abs(loc) > abs(peak):
        return 0.0
    return loc / peak


def _iup(ends, coords, deltas, hit):
    """The deltas of a contour's untouched points, interpolated from the touched ones around them (gvar's IUP)."""
    out, s = list(deltas), 0
    for e in ends:
        idx = list(range(s, e + 1))
        s = e + 1
        touched = [i for i in idx if hit[i]]
        if not touched or len(touched) == len(idx):
            continue
        if len(touched) == 1:
            for i in idx:
                out[i] = deltas[touched[0]]
            continue
        m = len(idx)
        for k, a in enumerate(touched):
            b = touched[(k + 1) % len(touched)]
            j = (a - idx[0] + 1) % m
            while idx[j] != b:
                i = idx[j]
                c1, c2, d1, d2 = coords[a], coords[b], deltas[a], deltas[b]
                if c1 > c2:
                    c1, c2, d1, d2 = c2, c1, d2, d1
                c = coords[i]
                out[i] = d1 if c <= c1 else d2 if c >= c2 else d1 + (c - c1) * (d2 - d1) / (c2 - c1)
                j = (j + 1) % m
    return out


# The pixel model.

def cells_outline(rows, top, weight):
    """The outline of the pixels [rows] (the top row first, its index [top]) at wght 400 or 700, as clockwise contours:
    the union of each pixel's rectangle on the model's edges, traced round its boundary, each contour from its lowest
    corner. At both weights the edges lie in the same order, so the contours have the same points in the same order."""
    w = 0 if weight == 400 else 1
    assert weight in (400, 700)
    edge = lambda e: e[0][0] + w * e[0][1], lambda e: e[1][0] + w * e[1][1]
    rects = []
    for r, row in enumerate(rows):
        lo, hi = edge[0](ROWS[top - r]), edge[1](ROWS[top - r])
        rects += [(edge[0](COLUMNS[c]), lo, edge[1](COLUMNS[c]), hi) for c, ch in enumerate(row) if ch == '#']
    xs = sorted({v for x0, _, x1, _ in rects for v in (x0, x1)})
    ys = sorted({v for _, y0, _, y1 in rects for v in (y0, y1)})
    filled = {(i, j) for i in range(len(xs) - 1) for j in range(len(ys) - 1)
              if any(x0 < (xs[i] + xs[i + 1]) / 2 < x1 and y0 < (ys[j] + ys[j + 1]) / 2 < y1 for x0, y0, x1, y1 in rects)}
    edges = set()
    for i, j in filled:
        a, b, c, d = (xs[i], ys[j]), (xs[i], ys[j + 1]), (xs[i + 1], ys[j + 1]), (xs[i + 1], ys[j])
        for e in ((a, b), (b, c), (c, d), (d, a)):  # clockwise with y up: up the left, along the top, down the right
            if (e[1], e[0]) in edges:
                edges.remove((e[1], e[0]))
            else:
                edges.add(e)
    nexts = {}
    for s, e in edges:
        assert s not in nexts, 'two contours meet at a corner'
        nexts[s] = e
    contours = []
    while nexts:
        start = min(nexts)
        pts, p = [start], nexts.pop(start)
        while p != start:
            pts.append(p)
            p = nexts.pop(p)
        # Drop the points in the middle of a straight run.
        pts = [q for k, q in enumerate(pts) if not (pts[k - 1][0] == q[0] == pts[(k + 1) % len(pts)][0]
                                                     or pts[k - 1][1] == q[1] == pts[(k + 1) % len(pts)][1])]
        contours.append(pts)
    return sorted(contours)


def same_shape(a, b):
    """Whether outlines [a] and [b] are the same contours, whatever point each starts on (within 1 unit)."""
    def norm(c):
        k = c.index(min(c))
        return c[k:] + c[:k]
    na, nb = sorted(norm(c) for c in a), sorted(norm(c) for c in b)
    return len(na) == len(nb) and all(len(x) == len(y) and all(abs(p[0] - q[0]) <= 1 and abs(p[1] - q[1]) <= 1
                                                              for p, q in zip(x, y)) for x, y in zip(na, nb))


# Writing the font.

def checksum(b):
    b = bytes(b) + b'\0' * (-len(b) % 4)
    return sum(struct.unpack('>%dI' % (len(b) // 4), b)) & 0xFFFFFFFF


def glyf_simple(contours):
    """A simple glyph: every point on the curve, the coordinates as words, no instructions, padded to an even length."""
    pts = [p for c in contours for p in c]
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    out = struct.pack('>hhhhh', len(contours), min(xs), min(ys), max(xs), max(ys))
    end = -1
    for c in contours:
        end += len(c)
        out += struct.pack('>H', end)
    out += struct.pack('>H', 0) + bytes([1] * len(pts))
    for vals in (xs, ys):
        last = 0
        for v in vals:
            out += struct.pack('>h', v - last)
            last = v
    return out + b'\0' * (len(out) % 2)


def packed_deltas(values):
    """gvar's packed deltas: runs of up to 64 zeros, bytes or words."""
    out, i = b'', 0
    kind = lambda v: 0 if v == 0 else 1 if -128 <= v <= 127 else 2
    while i < len(values):
        k, j = kind(values[i]), i
        while j < len(values) and j - i < 64 and kind(values[j]) == k:
            j += 1
        run = values[i:j]
        if k == 0:
            out += bytes([0x80 | (len(run) - 1)])
        elif k == 1:
            out += bytes([len(run) - 1]) + struct.pack('>%db' % len(run), *run)
        else:
            out += bytes([0x40 | (len(run) - 1)]) + struct.pack('>%dh' % len(run), *run)
        i = j
    return out


def glyph_variations(index, dx, dy):
    """A glyph's variation data with one tuple on shared tuple [index] and deltas for every point (no point numbers)."""
    data = packed_deltas(dx) + packed_deltas(dy)
    out = struct.pack('>HHHH', 1, 8, len(data), index) + data
    return out + b'\0' * (len(out) % 2)


def name_table(src):
    """The source's names with the family renamed: the copyright gains a line, the trademark and the vendor's names
    (IDs 7, 8, 11) go, the designer (9, 12) stays credited, and a description (10) says what this is."""
    no = src.tables['name'][0]
    count, strings = src.u16(no + 2), no + src.u16(no + 4)
    records = {}
    for i in range(count):
        pid, eid, lid, nid, length, off = struct.unpack('>HHHHHH', src.d[no + 6 + 12 * i:no + 18 + 12 * i])
        records[(pid, eid, lid, nid)] = src.d[strings + off:strings + off + length]
    win = lambda nid: (3, 1, 0x409, nid)
    old = {nid: records[win(nid)].decode('utf-16-be') for (_, _, _, nid) in records if win(nid) in records}
    assert old[1] == 'Pixelify Sans' and old[6] == 'PixelifySans-Regular' and old[25] == 'PixelifySans', old
    new = {
        0: old[0] + '. Copyright 2026 Trias BYM (the redrawn glyphs).',
        1: FAMILY,
        3: f'1.000;NONE;{POSTSCRIPT}-Regular',
        4: f'{FAMILY} Regular',
        6: f'{POSTSCRIPT}-Regular',
        10: f'{FAMILY} is a Modified Version of Pixelify Sans by Stefie Justprince, made for the game Path of Hero: its '
            '2, 3, 5, 6, 9, B, C, G, S, Z, a, c and i redrawn so they read apart at small sizes.',
        25: POSTSCRIPT,
    }
    for nid in (7, 8, 11):
        del records[win(nid)]
    for nid, s in new.items():
        records[win(nid)] = s.encode('utf-16-be')
    keys = sorted(records)
    head, body = b'', b''
    for k in keys:
        head += struct.pack('>HHHHHH', *k, len(records[k]), len(body))
        body += records[k]
    return struct.pack('>HHH', 0, len(keys), 6 + 12 * len(keys)) + head + body


def build(src):
    """The font, and each redrawn glyph's (char, id, new rows, contours at 400 and at 700)."""
    assert hashlib.sha256(src.d).hexdigest() == SOURCE_SHA256, f'{SOURCE.name} is not the pinned Pixelify Sans'
    shared = src.shared_tuples()
    redrawn = {}
    for char, top, old, new in GLYPHS:
        g = src.glyph_of(char)
        for weight in (400, 700):
            assert same_shape(cells_outline(old, top, weight), src.instance(g, weight)[0]), \
                f'the pixel model misses the font\'s {char} at {weight}'
        (which, peak, start, end, tx, ty), = src.tuples(g)
        assert which is not None and peak == 1.0 and start is None, f'{char}: one tuple, on the shared peak 1.0'
        at400, at700 = cells_outline(new, top, 400), cells_outline(new, top, 700)
        assert [len(c) for c in at400] == [len(c) for c in at700], f'{char}: the same points at both weights'
        pts400, pts700 = [p for c in at400 for p in c], [p for c in at700 for p in c]
        dx = [b[0] - a[0] for a, b in zip(pts400, pts700)] + [round(v) for v in tx[-4:]]
        dy = [b[1] - a[1] for a, b in zip(pts400, pts700)] + [round(v) for v in ty[-4:]]
        assert all(v == round(v) for v in tx[-4:] + ty[-4:]), f'{char}: whole phantom deltas'
        advance, lsb = src.metric(g)
        assert min(x for x, _ in pts400) == lsb, f'{char}: the left side bearing kept'
        assert shared[which] == 1.0
        redrawn[g] = (char, new, at400, at700, glyf_simple(at400), glyph_variations(which, dx, dy))

    # glyf and loca (short offsets, halved: every glyph's bytes are an even length).
    glyf, at = b'', [0]
    for g in range(src.glyphs):
        data = redrawn[g][4] if g in redrawn else src.glyph_bytes(g)
        assert len(data) % 2 == 0
        glyf += data
        at.append(len(glyf))
    assert not src.long_loca and len(glyf) < 0x20000
    loca = struct.pack('>%dH' % len(at), *(a // 2 for a in at))

    # gvar: its header, the offsets, the shared tuples as they are, then each glyph's data.
    gv, shared_n, shared_at, flags, data_at = src.gvar_header()
    old_gvar = src.table('gvar')
    shared_bytes = old_gvar[shared_at:shared_at + 2 * shared_n]
    datas = [redrawn[g][5] if g in redrawn else src.gvar_bytes(g) for g in range(src.glyphs)]
    assert all(len(d) % 2 == 0 for d in datas) and not flags & 1
    offsets, total = [0], 0
    for d in datas:
        total += len(d)
        offsets.append(total)
    assert total < 0x20000
    new_shared_at = 20 + 2 * (src.glyphs + 1)
    new_data_at = new_shared_at + len(shared_bytes)
    new_data_at += -new_data_at % 4
    gvar = old_gvar[:4] + struct.pack('>HHIHHI', 1, shared_n, new_shared_at, src.glyphs, flags, new_data_at)
    gvar += struct.pack('>%dH' % len(offsets), *(o // 2 for o in offsets)) + shared_bytes
    gvar += b'\0' * (new_data_at - len(gvar)) + b''.join(datas)

    # maxp: the most points and contours of a simple glyph (the composites' counts are left as the source's: each
    # redrawn glyph's composites were counted with its old points, which the asserts below keep at or above).
    maxp = bytearray(src.table('maxp'))
    most_pts, most_contours = struct.unpack('>HH', maxp[6:10])
    for g, (char, _, at400, _, _, _) in redrawn.items():
        _, old_pts = src.outline(g)
        assert sum(map(len, at400)) <= max(len(old_pts), most_pts) and len(at400) <= most_contours, char
        assert sum(map(len, at400)) <= len(old_pts) or not composites_of(src, g), f'{char}: its composites grew'

    # head: the bounding box over every glyph (the redrawn ones inside it), checkSumAdjustment set last.
    head = bytearray(src.table('head'))
    x0, y0, x1, y1 = struct.unpack('>hhhh', head[36:44])
    for char, _, at400, at700, _, _ in redrawn.values():
        for c in at400 + at700:
            for x, y in c:
                assert x0 <= x <= x1 and y0 <= y <= y1, f'{char}: outside the font\'s box'
    struct.pack_into('>I', head, 8, 0)

    tables = {tag: src.table(tag) for tag in src.tables}
    tables.update({'glyf': glyf, 'loca': loca, 'gvar': gvar, 'name': name_table(src), 'head': bytes(head),
                   'maxp': bytes(maxp)})
    tags = sorted(tables)
    order = sorted(src.tables, key=lambda t: src.tables[t][0])  # the source's order of the table data
    n = len(tags)
    power = 1 << (n.bit_length() - 1)
    out = bytearray(struct.pack('>IHHHH', 0x00010000, n, power * 16, power.bit_length() - 1, n * 16 - power * 16))
    offset, places = 12 + 16 * n, {}
    for tag in order:
        places[tag] = offset
        offset += len(tables[tag]) + (-len(tables[tag]) % 4)
    for tag in tags:
        out += struct.pack('>4sIII', tag.encode(), checksum(tables[tag]), places[tag], len(tables[tag]))
    for tag in order:
        out += tables[tag] + b'\0' * (-len(tables[tag]) % 4)
    struct.pack_into('>I', out, places['head'] + 8, (0xB1B0AFBA - checksum(out)) & 0xFFFFFFFF)
    return bytes(out), redrawn


def composites_of(src, g):
    """The composite glyphs that use glyph [g]."""
    users = []
    for c in range(src.glyphs):
        b = src.glyph_bytes(c)
        if not b or struct.unpack('>h', b[:2])[0] >= 0:
            continue
        p = 10
        while True:
            flags, gi = struct.unpack('>HH', b[p:p + 4])
            if gi == g:
                users.append(c)
            p += 4 + (4 if flags & 1 else 2) + (2 if flags & 8 else 4 if flags & 0x40 else 8 if flags & 0x80 else 0)
            if not flags & 0x20:
                break
    return users


def show(src):
    _, redrawn = build(src)
    for g, (char, new, at400, _, _, _) in redrawn.items():
        old = next(o for c, _, o, _ in GLYPHS if c == char)
        print(f'{char} (glyph {g}, advance {src.metric(g)[0]}): the font\'s, then the new, {len(at400)} contour(s); '
              f'used by {len(composites_of(src, g))} composite(s)')
        for a, b in zip(old, new):
            print(f'  {a}   {b}')


def main(argv):
    src = Font(SOURCE.read_bytes())
    if '--show' in argv:
        return show(src)
    font, _ = build(src)
    if '--check' in argv:
        if not OUT.exists() or OUT.read_bytes() != font:
            sys.exit(f'stale: {OUT.name} (run python3 tool/make_poh_sans.py)')
        return
    OUT.write_bytes(font)
    print(f'wrote {OUT.relative_to(ROOT)} ({len(font)} bytes, sha256 {hashlib.sha256(font).hexdigest()})')


if __name__ == '__main__':
    main(sys.argv[1:])
