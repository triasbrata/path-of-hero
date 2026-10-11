#!/usr/bin/env python3
"""Compiles every .aseprite in raw_assets/ into grouped PNG sheets under sprites/.

Pure standard library (no Aseprite install needed):
    python3 tool/export_aseprite.py
For each .aseprite:
- <name>.png: all visible layers flattened, frames laid out left to right (frame = canvas size).
- <name>.layers/<layer>.png: one sheet per layer, when two or more layers hold pixels
  (e.g. the hands/weapons layer in Castle's Social/Guards).
PNG files with no .aseprite beside them are copied in too, so the library is complete.
Output is grouped as sprites/<category>/<pack>/<sub/path>/, with sprites/catalog.json
(frame size, frame count, durations, tags, layers) and sprites/index.html to browse it.
"""
import json
import re
import shutil
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC, OUT = ROOT / "raw_assets", ROOT / "sprites"

# ---- .aseprite reading (RGBA files, compressed/linked cels, groups, tags) ----


def parse(path):
    d = path.read_bytes()
    w, h, depth = struct.unpack("<HHH", d[8:14])
    if depth != 32:
        raise ValueError(f"{path}: only RGBA supported, got depth {depth}")
    nframes = struct.unpack("<H", d[6:8])[0]
    layers, frames, tags, o = [], [], [], 128
    for fi in range(nframes):
        fsize, _, old, dur = struct.unpack("<IHHH", d[o:o + 10])
        nch = struct.unpack("<I", d[o + 12:o + 16])[0] or old
        co, cels = o + 16, {}
        for _ in range(nch):
            csize, ctype = struct.unpack("<IH", d[co:co + 6])
            c = d[co + 6:co + csize]
            if ctype == 0x2004:  # layer
                flags, ltype, level = struct.unpack("<HHH", c[:6])
                opacity = c[12]
                n = struct.unpack("<H", c[16:18])[0]
                layers.append({"name": c[18:18 + n].decode("utf-8", "replace"), "visible": bool(flags & 1),
                               "type": ltype, "level": level, "opacity": opacity})
            elif ctype == 0x2005:  # cel
                li, x, y, op, ct = struct.unpack("<HhhBH", c[:9])
                if ct == 1:  # linked: reuse another frame's cel
                    cels[li] = ("link", struct.unpack("<H", c[16:18])[0], op)
                elif ct in (0, 2):
                    cw, chh = struct.unpack("<HH", c[16:20])
                    raw = c[20:] if ct == 0 else zlib.decompress(c[20:])
                    cels[li] = (x, y, cw, chh, raw, op)
            elif ctype == 0x2018:  # tags
                n = struct.unpack("<H", c[:2])[0]
                p = 10
                for _ in range(n):
                    a, b = struct.unpack("<HH", c[p:p + 4])
                    ln = struct.unpack("<H", c[p + 17:p + 19])[0]
                    tags.append({"name": c[p + 19:p + 19 + ln].decode("utf-8", "replace"), "from": a, "to": b})
                    p += 19 + ln
            co += csize
        frames.append((dur, cels))
        o += fsize
    # resolve linked cels
    for dur, cels in frames:
        for li, cel in list(cels.items()):
            if cel[0] == "link":
                src = frames[cel[1]][1].get(li)
                if src and src[0] != "link":
                    cels[li] = src[:5] + (cel[2],)
                else:
                    del cels[li]
    # a layer shows only if it and every parent group are visible
    shown, stack = [], []
    for L in layers:
        del stack[L["level"]:]
        vis = L["visible"] and all(stack)
        shown.append(vis and L["type"] == 0)
        stack.append(vis)
    return w, h, layers, shown, frames, tags


def blend(dst, w, h, ox, cel, alpha):
    """Normal-mode alpha blend of one cel into an RGBA bytearray (sheet row stride w)."""
    x, y, cw, ch, raw, op = cel
    a_mul = alpha * op / 255 / 255 / 255  # pixel alpha x layer opacity x cel opacity, as 0..1
    for j in range(ch):
        ty = y + j
        if not 0 <= ty < h:
            continue
        for i in range(cw):
            tx = x + i
            if not 0 <= tx < w - ox and tx >= 0:
                continue
            s = (j * cw + i) * 4
            sa = raw[s + 3] * a_mul
            if sa <= 0:
                continue
            di = (ty * w + ox + tx) * 4
            da = dst[di + 3] / 255
            oa = sa + da * (1 - sa)
            for k in range(3):
                dst[di + k] = int((raw[s + k] * sa + dst[di + k] * da * (1 - sa)) / oa)
            dst[di + 3] = int(oa * 255)


def write_png(path, w, h, rgba):
    def chunk(t, data):
        return struct.pack(">I", len(data)) + t + data + struct.pack(">I", zlib.crc32(t + data))
    rows = b"".join(b"\0" + bytes(rgba[y * w * 4:(y + 1) * w * 4]) for y in range(h))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))


def sheet(w, h, frames, layer_ids, layers):
    n = len(frames)
    buf = bytearray(w * n * h * 4)
    for fi, (_, cels) in enumerate(frames):
        for li in layer_ids:
            if li in cels:
                blend(buf, w * n, h, fi * w, cels[li], layers[li]["opacity"])
    return w * n, h, buf


# ---- grouping ----

CATEGORIES = [  # first match on the lowercased path wins
    ("promo", ("/social/", "mockup", "/cover")),
    ("enemies", ("/enemies/", "/enemy/", "/mobs/", "bat_fur/", "small_bat/")),
    ("characters", ("/characters/", "/npc's/")),
    ("weapons", ("weapon",)),
    ("ui", ("cute_fantasy_ui/",)),
    ("tiles", ("tiles", "tileset", "floor", "wall", "water", "ground", "sand", "roof")),
    ("props", ("props", "/structures/", "/stations/", "tree", "vegetation", "graves", "shadow", "light")),
]
DROP_DIRS = {"enemies", "enemy", "entities", "mobs", "weapons", "weapon", "assets", "environment", "social",
             "ui", "animations", "tilesets"}


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower().replace("'", "")).strip("-")


def place(rel):
    """raw_assets-relative path -> (category, pack, sprites-relative path without extension)."""
    low = "/" + rel.as_posix().lower()
    cat = next((c for c, keys in CATEGORIES if any(k in low for k in keys)), "misc")
    top = rel.parts[0]
    pack = slug(re.sub(r"^Pixel Crawler - ", "", re.sub(r"\s+\d+(\.\d+)*$", "", top)))
    inner = [p for p in rel.parts[1:-1] if slug(p) != slug(top) and slug(p) not in DROP_DIRS]
    name = slug(re.sub(r"-Sheet$", "", rel.stem))
    return cat, pack, Path(cat, pack, *map(slug, inner), name)


def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    catalog = []
    ases = sorted(SRC.rglob("*.aseprite"))
    covered = set()
    for i, p in enumerate(ases):
        rel = p.relative_to(SRC)
        covered |= {p.with_suffix(".png"), p.with_name(p.stem + "-Sheet.png")}
        cat, pack, dest = place(rel)
        w, h, layers, shown, frames, tags = parse(p)
        ids = [li for li, s in enumerate(shown) if s]
        sw, sh, buf = sheet(w, h, frames, ids, layers)
        write_png(OUT / f"{dest}.png", sw, sh, buf)
        entry = {"category": cat, "pack": pack, "name": dest.name, "file": f"{dest.as_posix()}.png",
                 "source": rel.as_posix(), "frameWidth": w, "frameHeight": h, "frames": len(frames),
                 "durations": [f[0] for f in frames], "tags": tags,
                 "layers": [L["name"] for L in layers if L["type"] == 0]}
        with_pixels = [li for li in ids if any(li in cels for _, cels in frames)]
        if len(with_pixels) > 1:
            entry["layerFiles"] = []  # a list: layer names repeat (e.g. several "Flattened")
            for li in with_pixels:
                lw, lh, lbuf = sheet(w, h, frames, [li], layers)
                lp = dest.parent / f"{dest.name}.layers" / f"{li:02d}-{slug(layers[li]['name']) or 'layer'}.png"
                write_png(OUT / lp, lw, lh, lbuf)
                entry["layerFiles"].append({"layer": layers[li]["name"], "file": lp.as_posix()})
        catalog.append(entry)
        if i % 50 == 0:
            print(f"{i}/{len(ases)} {rel}")
    for p in sorted(SRC.rglob("*.png")):
        if p in covered:
            continue
        rel = p.relative_to(SRC)
        cat, pack, dest = place(rel)
        target = OUT / f"{dest}.png"
        if target.exists():  # an aseprite export already sits there
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(p, target)
        w, h = struct.unpack(">II", p.read_bytes()[16:24])
        catalog.append({"category": cat, "pack": pack, "name": dest.name, "file": f"{dest.as_posix()}.png",
                        "source": rel.as_posix(), "width": w, "height": h})
    catalog.sort(key=lambda e: e["file"])
    (OUT / "catalog.json").write_text(json.dumps(catalog, indent=1))
    (OUT / "index.html").write_text(INDEX.replace("__DATA__", json.dumps(catalog)))
    counts = {}
    for e in catalog:
        counts[e["category"]] = counts.get(e["category"], 0) + 1
    print(f"wrote {len(catalog)} sprites to {OUT}: {counts}")


INDEX = """<!doctype html>
<meta charset="utf-8"><title>Sprite Library</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
:root { --bg:#16171d; --card:#22242c; --fg:#e8e6e3; --dim:#9a9aa3; --accent:#e0a84a }
body { margin:0; font:14px system-ui, sans-serif; background:var(--bg); color:var(--fg) }
header { position:sticky; top:0; background:var(--bg); padding:12px 16px; display:flex; gap:12px; flex-wrap:wrap; align-items:center; border-bottom:1px solid #333 }
input, select { background:var(--card); color:var(--fg); border:1px solid #444; border-radius:6px; padding:6px 8px }
main { padding:8px 16px 40px }
h2 { color:var(--accent); margin:24px 0 4px; text-transform:capitalize }
h3 { color:var(--dim); margin:14px 0 6px; font-weight:500 }
.grid { display:flex; flex-wrap:wrap; gap:10px }
.card { background:var(--card); border-radius:8px; padding:8px; max-width:100% }
.card img { image-rendering:pixelated; display:block; max-width:100%; background:repeating-conic-gradient(#2c2e37 0 25%, #262830 0 50%) 0 0/16px 16px }
.card .n { margin-top:4px } .card .m { color:var(--dim); font-size:12px; word-break:break-all }
.layers { display:flex; gap:6px; flex-wrap:wrap; margin-top:6px }
</style>
<header><strong>Sprite Library</strong>
<input id="q" placeholder="filter (name, pack, path)"><select id="cat"><option value="">all categories</option></select>
<label>zoom <select id="z"><option>1</option><option selected>2</option><option>3</option><option>4</option></select></label>
<span id="count" class="m"></span></header>
<main id="out"></main>
<script>
const DATA = __DATA__;
const $ = id => document.getElementById(id);
const cats = [...new Set(DATA.map(e => e.category))];
cats.forEach(c => $('cat').add(new Option(c, c)));
function img(src, w) { const i = new Image(); i.src = src; i.loading = 'lazy';
  i.onload = () => i.style.width = i.naturalWidth * +$('z').value + 'px'; return i; }
function render() {
  const q = $('q').value.toLowerCase(), c = $('cat').value, out = $('out');
  out.textContent = '';
  const list = DATA.filter(e => (!c || e.category === c) && (!q || (e.file + e.source).toLowerCase().includes(q)));
  $('count').textContent = list.length + ' sprites';
  let cat, pack, grid;
  for (const e of list) {
    if (e.category !== cat) { cat = e.category; pack = null; out.append(Object.assign(document.createElement('h2'), {textContent: cat})); }
    if (e.pack !== pack) { pack = e.pack; out.append(Object.assign(document.createElement('h3'), {textContent: pack}));
      grid = out.appendChild(Object.assign(document.createElement('div'), {className: 'grid'})); }
    const card = grid.appendChild(Object.assign(document.createElement('div'), {className: 'card'}));
    card.append(img(e.file));
    const meta = e.frames ? `${e.frames} × ${e.frameWidth}×${e.frameHeight}` + (e.tags.length ? ' · tags: ' + e.tags.map(t => t.name).join(', ') : '')
                          : `${e.width}×${e.height} (png)`;
    card.insertAdjacentHTML('beforeend', `<div class="n">${e.file.replace(/^[^/]+\\/[^/]+\\//, '')}</div><div class="m">${meta}<br>${e.source}</div>`);
    if (e.layerFiles) {
      const d = card.appendChild(document.createElement('details'));
      d.append(Object.assign(document.createElement('summary'), {textContent: e.layerFiles.length + ' layers'}));
      const l = d.appendChild(Object.assign(document.createElement('div'), {className: 'layers'}));
      d.addEventListener('toggle', () => { if (d.open && !l.childElementCount)
        for (const {layer, file} of e.layerFiles) { const i = img(file); i.title = layer; l.append(i); } });
    }
  }
}
['q', 'cat', 'z'].forEach(id => $(id).addEventListener('input', render));
render();
</script>
"""

if __name__ == "__main__":
    main()
