#!/usr/bin/env python3
"""The asset vault: the licensed art in the repository only encrypted, so a CI build can use it and nobody without
the key can (docs/assets.md "The asset vault", decisions-log 232).

    python3 tool/asset_vault.py check  [--only NAME ...] [--dest DIR]
    python3 tool/asset_vault.py pack   [--only NAME ...] [--force] [--key-file PATH]
    python3 tool/asset_vault.py unpack [--only NAME ...] [--dest DIR] [--force] [--key-file PATH]
    python3 tool/asset_vault.py list
    python3 tool/asset_vault.py sync   [--keep-mine] [--key-file PATH]   (what the post-checkout/post-merge hooks run)
    python3 tool/asset_vault.py resolve [--take ours|theirs] [--key-file PATH]   (after `git merge` stopped)
    python3 tool/asset_vault.py prune  [--force]
    python3 tool/asset_vault.py commit [git commit's arguments]   (a commit of the git-ignored art alone)
    python3 tool/asset_vault.py install-hooks
    python3 tool/asset_vault.py hook pre-commit|post-update|pre-push [ARGS]   (.githooks/ call these)
    --root DIR (before the command) works on another checkout's vault, e.g. the private notes' pack vaults.

NAME is a vault's name or a group's: "game" (what a build needs: the packs' files under assets/ and the platform app
icons) or "packs" (the art packs as they came, for the import tools). tool/asset_vault.json is the one source of
truth: per vault its pack, licence and files (path, bytes, sha256, needed_by_build), the plaintext tar's sha256 and
the ciphertext parts' sha256s. The vaults are assets-vault/<name>.tar.gz.enc, or .partNN when split.

- check: every file a build needs is at its path with its sha256, every licensed file (tool/assets.sha256) and every
  file under a game vault's patterns is in its vault, and every part is there with its sha256. It names each problem
  and exits 1 if any. It needs no key. A vault never packed is noted, not failed.
- pack: rebuilds only the vaults whose plaintext changed (the salt makes every encryption differ, so an unchanged
  vault is never rewritten: the tar's sha256 is compared with the JSON's) and updates the JSON. --force encrypts
  every selected vault again (after a new key).
- unpack: per vault, checks the parts' sha256s, decrypts, checks the tar's sha256 and every file against the JSON,
  then writes the files to their places (game: their repo paths; a pack: its root in tool/asset_packs/index.json, else
  raw_sprites/<slug>/). A file already there with other bytes is never overwritten without --force: nothing is written
  then. --dest DIR puts the files under DIR instead (only for game vaults, or for one vault).
- list: the vaults, their files and sizes.

The format: a deterministic ustar tar (names sorted, mode 0644, uid/gid 0, no owner names, mtime 2026-01-01, no
extended headers) -> gzip without name or time -> `openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 -salt`
-> parts of at most 45,000,000 bytes. A member opens one with a single command (the JSON's format.open):
    cat assets-vault/<name>.tar.gz.enc* | openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 \\
        -pass file:<key file> | tar -xzf - -C <dest>

The key: openssl reads it itself (`-pass file:<path>`, or `-pass env:POH_VAULT_KEY`); this tool never reads, prints or
passes it on a command line. Where it is: --key-file PATH, else the env var POH_VAULT_KEY_FILE (a path), else the env
var POH_VAULT_KEY (the key itself, for CI's secret), else the clone's `git config poh.vaultKeyFile` (a path; a
machine's own setting, never in the repository), else ~/.config/path-of-hero/asset-vault.key. A key file must be mode
600 (no access for group or others), outside the repository and not empty. openssl is POH_OPENSSL or the one on the
PATH. Stdlib only, Python 3.8+.

The git-ignored art (the public repository, docs/assets.md "The asset vault"): the plain licensed files are git-ignored
and only the vaults are tracked. The hooks keep both in step, per game vault, with a state file per worktree
(`git rev-parse --git-path asset_vault.synced`: the tar sha256 each vault's files were last made equal to):
- pre-commit: files equal to the staged JSON's vault: in step. Else, when that vault changed in git since the files
  were last synced (a merge brought a newer one), it refuses (packing would undo the newer vault: `sync`, or `resolve`
  after a stopped merge). Else it re-packs only that vault and stages its parts and the JSON. It never packs
  tool/gen_placeholders.py's placeholders, packs nothing without a key (it says so), and refuses a licensed file that
  was forced into the index past .gitignore.
- post-checkout / post-merge (`sync`): a vault whose files are unedited since the last sync (or absent, or
  placeholders) is unpacked; files with edits of their own are left alone, with a warning. It never fails. Files that
  left a vault are deleted in a linked worktree and only listed in the main checkout, where the game may be running
  (`prune` deletes them later).
- pre-push: with `git config poh.publicRoot <sha>` set, a push to the public repository (`git config poh.publicUrl`,
  or the remote named `public`) takes only main and v* tags whose history starts at that root commit; a push of that
  history anywhere else is refused unless POH_PUSH_PUBLIC_HISTORY=1.
"""
import argparse
import gzip
import hashlib
import io
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JSON_PATH = ROOT / "tool/asset_vault.json"
VAULT_DIR = "assets-vault"
HASHES = ROOT / "tool/assets.sha256"  # the licensed files under assets/ (tool/asset_manifest.py)
PACK_INDEX = ROOT / "tool/asset_packs/index.json"  # the art packs' roots (tool/asset_meta.py)
DEFAULT_KEY = "~/.config/path-of-hero/asset-vault.key"  # the public default; a clone names its own (poh.vaultKeyFile)
GROUPS = ("game", "packs")

CIPHER = ["-aes-256-cbc", "-pbkdf2", "-iter", "600000", "-md", "sha256"]
PART_BYTES = 45_000_000  # GitHub warns at 50 MB and refuses 100
MTIME = 1767225600  # 2026-01-01 00:00:00 UTC: fixed, and not 0 (GNU tar calls 1970 "implausibly old")
FORMAT = {
    "tar": "ustar; names sorted (UTF-8 bytes); mode 0644, uid/gid 0, no owner names, mtime 2026-01-01; regular files "
           "only, no extended headers",
    "gzip": "no name, no time (gzip -n), level 9",
    "cipher": "openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 -salt",
    "part_bytes": PART_BYTES,
    "parts": "assets-vault/<name>.tar.gz.enc when it fits one part, else <name>.tar.gz.enc.part01, .part02, ...",
    "open": "cat assets-vault/<name>.tar.gz.enc* | openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 "
            "-pass file:<key file> | tar -xzf - -C <dest>",
}
ABOUT = ("The asset vault (docs/assets.md \"The asset vault\"): every vault's pack, licence and files, its tar's and "
         "parts' sha256s. Written by tool/asset_vault.py pack (the hand-written fields kept: name, group, pack, "
         "licence, needed_by_build, match or slug); read by its check and unpack.")
HAND = ("name", "group", "pack", "licence", "needed_by_build", "match", "slug")


class VaultError(Exception):
    pass


def die(msg):
    raise VaultError(msg)


def sha256(b):
    return hashlib.sha256(b).hexdigest()


def rel_to_root(p):
    try:
        return Path(p).relative_to(ROOT).as_posix()
    except ValueError:
        return str(p)


# --- The JSON -------------------------------------------------------------------------------------------------------
def safe_path(p, what):
    """A relative posix path inside its base: no absolute path, no `..`, no backslash, no empty or hidden part."""
    if not isinstance(p, str) or not p or p.startswith("/") or "\\" in p or re.match(r"^[A-Za-z]:", p):
        die(f"{what}: {p!r} isn't a relative path")
    for part in p.split("/"):
        if part in ("", ".", "..") or part.startswith("."):
            die(f"{what}: {p!r} has an empty, '.', '..' or hidden part")
    return p


def load():
    if not JSON_PATH.is_file():
        die(f"no {rel_to_root(JSON_PATH)}")
    doc = json.loads(JSON_PATH.read_text())
    names = set()
    for v in doc.get("vaults", []):
        n = v.get("name", "")
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", n) or n in names or n in GROUPS:
            die(f"tool/asset_vault.json: vault name {n!r} is not a unique lower-case slug")
        names.add(n)
        if v.get("group") not in GROUPS:
            die(f"vault {n}: group {v.get('group')!r} isn't one of {', '.join(GROUPS)}")
        if v["group"] == "game" and not v.get("match"):
            die(f"vault {n}: a game vault needs its match patterns")
        if v["group"] == "packs" and not re.fullmatch(r"[a-z0-9][a-z0-9-]*", v.get("slug", "")):
            die(f"vault {n}: a pack vault needs its slug")
        for f in v.get("files", []):
            safe_path(f.get("path"), f"vault {n}'s file")
        for part in v.get("parts", []):
            if not re.fullmatch(rf"{VAULT_DIR}/{re.escape(n)}\.tar\.gz\.enc(\.part\d\d)?", part.get("path", "")):
                die(f"vault {n}: part {part.get('path')!r} isn't {VAULT_DIR}/{n}.tar.gz.enc[.partNN]")
    return doc


def dump(doc):
    """The JSON with one file per line, so a diff shows which file changed."""
    out = ["{", f'  "about": {json.dumps(doc["about"], ensure_ascii=False)},',
           '  "format": ' + json.dumps(doc["format"], indent=2, ensure_ascii=False).replace("\n", "\n  ") + ",",
           '  "vaults": [']
    for i, v in enumerate(doc["vaults"]):
        head = {k: v[k] for k in v if k != "files"}
        line = "    " + json.dumps(head, ensure_ascii=False)[:-1]
        files = v.get("files")
        if files is not None:
            line += ', "files": [\n' + ",\n".join("      " + json.dumps(f, ensure_ascii=False) for f in files)
            line += "\n    ]"
        out.append(line + "}" + ("," if i < len(doc["vaults"]) - 1 else ""))
    out += ["  ]", "}", ""]
    text = "\n".join(out)
    json.loads(text)
    return text


def select(doc, only):
    vaults = doc["vaults"]
    if not only:
        return list(vaults)
    known = {v["name"] for v in vaults}
    for n in only:
        if n not in known and n not in GROUPS:
            die(f"no vault or group {n!r} (vaults: {', '.join(sorted(known))}; groups: {', '.join(GROUPS)})")
    return [v for v in vaults if v["name"] in only or v["group"] in only]


def packed(v):
    return bool(v.get("parts")) and "tar" in v and "files" in v


# --- Where each vault's files are -----------------------------------------------------------------------------------
def glob_re(pattern):
    out, i = "", 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out, i = out + "(?:.*/)?", i + 3
        elif pattern[i] == "*":
            out, i = out + "[^/]*", i + 1
        elif pattern[i] == "?":
            out, i = out + "[^/]", i + 1
        else:
            out, i = out + re.escape(pattern[i]), i + 1
    return re.compile(out + r"\Z")


def game_vault_of(doc, path):
    """The first game vault (in the JSON's order) one of whose match patterns the repo path fits, or None."""
    for v in doc["vaults"]:
        if v["group"] == "game" and any(glob_re(p).match(path) for p in v["match"]):
            return v
    return None


def walk(base):
    """Every regular file under base, as sorted relative posix paths; hidden files and folders left out."""
    out = []
    for dirpath, dirs, names in os.walk(base):
        dirs[:] = sorted(d for d in dirs if not d.startswith("."))
        for n in names:
            p = Path(dirpath) / n
            if n.startswith(".") or not p.is_file() or p.is_symlink():
                continue
            out.append(p.relative_to(base).as_posix())
    return sorted(out, key=lambda s: s.encode())


def game_files(doc, base):
    """{vault name: [repo path]} for the files under base that the game vaults' patterns take, each in its first."""
    tops = set()
    for v in doc["vaults"]:
        if v["group"] == "game":
            for p in v["match"]:
                fixed = re.split(r"[*?]", p)[0]
                tops.add(fixed.rsplit("/", 1)[0] if "/" in fixed else "")
    out = {}
    seen = set()
    for top in sorted(tops):
        d = base / top
        if not d.is_dir():
            continue
        for rel in walk(d):
            path = f"{top}/{rel}" if top else rel
            if path in seen:
                continue
            seen.add(path)
            v = game_vault_of(doc, path)
            if v:
                out.setdefault(v["name"], []).append(path)
    return {k: sorted(ps, key=lambda s: s.encode()) for k, ps in out.items()}


def licensed_hashes():
    """tool/assets.sha256 as {path: sha256}: the licensed files under assets/ a build needs."""
    if not HASHES.is_file():
        return {}
    out = {}
    for line in HASHES.read_text().splitlines():
        if line.strip():
            h, p = line.split(None, 1)
            out[p.strip().lstrip("*")] = h
    return out


def main_checkout():
    """The main worktree's root (where raw_sprites/ and raw_assets/ hold the packs), or None outside git."""
    try:
        out = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"], cwd=ROOT,
                             capture_output=True, text=True, check=True, stdin=subprocess.DEVNULL).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None
    return Path(out).parent if out else None


def pack_root(v):
    """A pack vault's root as tool/asset_packs/index.json names it (repo-relative or ~/), else raw_sprites/<slug>."""
    root = f"raw_sprites/{v['slug']}"
    if PACK_INDEX.is_file():
        for p in json.loads(PACK_INDEX.read_text()).get("packs", []):
            if p.get("slug") == v["slug"] and p.get("root"):
                root = p["root"]
    return root


def resolve_root(root, for_reading):
    if root.startswith("~"):
        return Path(os.path.expanduser(root))
    if Path(root).is_absolute():
        return Path(root)
    if for_reading:
        for base in (ROOT, main_checkout()):
            if base and (base / root).is_dir():
                return base / root
    return ROOT / root


def dest_of(v, dest=None):
    """Where a vault's files go (and where check looks for them)."""
    if dest:
        return Path(dest).expanduser().resolve()
    if v["group"] == "game":
        return ROOT
    return resolve_root(pack_root(v), for_reading=False)


# --- The format -----------------------------------------------------------------------------------------------------
def ustar_header(name, size):
    raw = name.encode("utf-8")
    prefix, base = b"", raw
    if len(raw) > 100:
        i = raw.rfind(b"/", 0, 156)
        if i <= 0 or len(raw) - i - 1 > 100:
            die(f"{name}: too long for a ustar name (100 bytes, or a 155-byte folder and a 100-byte name)")
        prefix, base = raw[:i], raw[i + 1:]
    h = bytearray(512)
    h[0:len(base)] = base
    h[100:108] = b"0000644\0"
    h[108:116] = b"0000000\0"
    h[116:124] = b"0000000\0"
    h[124:136] = b"%011o\0" % size
    h[136:148] = b"%011o\0" % MTIME
    h[148:156] = b" " * 8
    h[156:157] = b"0"
    h[257:265] = b"ustar\x0000"
    h[329:337] = b"0000000\0"
    h[337:345] = b"0000000\0"
    h[345:345 + len(prefix)] = prefix
    h[148:156] = b"%06o\0 " % sum(h)
    return bytes(h)


def make_tar(entries):
    """A deterministic ustar archive of [(name, bytes)], in name order."""
    chunks, n = [], 0
    for name, data in sorted(entries, key=lambda e: e[0].encode()):
        for c in (ustar_header(name, len(data)), data, b"\0" * (-len(data) % 512)):
            chunks.append(c)
            n += len(c)
    chunks.append(b"\0" * 1024)
    n += 1024
    chunks.append(b"\0" * (-n % 10240))
    return b"".join(chunks)


def read_tar(data):
    """[(name, bytes)] of a vault's tar: regular files only."""
    out = []
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:") as t:
        for m in t:
            if not m.isreg():
                die(f"{m.name}: not a regular file")
            out.append((m.name, t.extractfile(m).read()))
    return out


def part_names(name, n):
    if n == 1:
        return [f"{VAULT_DIR}/{name}.tar.gz.enc"]
    if n > 99:
        die(f"vault {name}: {n} parts, more than .part99")
    return [f"{VAULT_DIR}/{name}.tar.gz.enc.part{i:02d}" for i in range(1, n + 1)]


# --- The key and openssl --------------------------------------------------------------------------------------------
def key_pass(key_file):
    """openssl's -pass value and what to call the key: its file's path, or the env var's name. Never the key."""
    path = key_file or os.environ.get("POH_VAULT_KEY_FILE")
    if not path and os.environ.get("POH_VAULT_KEY"):
        return "env:POH_VAULT_KEY", "the env var POH_VAULT_KEY"
    if not path:
        path = git_config("poh.vaultKeyFile")
    p = Path(os.path.expanduser(path or DEFAULT_KEY)).absolute()
    if not p.is_file():
        die(f"no key file at {p}. The owner gives the key to members; put it in a file there (chmod 600), or name "
            "another with --key-file, POH_VAULT_KEY_FILE or  git config poh.vaultKeyFile <path>")
    st = p.stat()
    if os.name == "posix" and st.st_mode & 0o077:
        die(f"{p} is open to group or others (mode {stat.filemode(st.st_mode)}): run  chmod 600 {p}  and try again")
    if st.st_size == 0:
        die(f"{p} is empty")
    try:
        p.resolve().relative_to(ROOT)
        die(f"{p} is inside the repository: keep the key outside every checkout")
    except ValueError:
        pass
    return f"file:{p}", str(p)


def openssl(args, data, passarg):
    exe = os.environ.get("POH_OPENSSL") or shutil.which("openssl")
    if not exe:
        die("no openssl on the PATH (set POH_OPENSSL)")
    r = subprocess.run([exe, "enc", *args, "-pass", passarg], input=data, capture_output=True)
    return r.returncode, r.stdout, r.stderr.decode(errors="replace").strip().splitlines()[:1]


# --- Commands -------------------------------------------------------------------------------------------------------
def collect(doc, v, skip=None):
    """[(name in the tar, source file)] for a vault, from this machine. skip: {path: sha256} of files left out while
    they still have those bytes (files that left their vault, waiting for prune)."""
    if v["group"] == "game":
        paths = game_files(doc, ROOT).get(v["name"], [])
        if skip:
            paths = [p for p in paths if skip.get(p) != sha256((ROOT / p).read_bytes())]
        return [(p, ROOT / p) for p in paths]
    root = resolve_root(pack_root(v), for_reading=True)
    if not root.is_dir():
        die(f"vault {v['name']}: the pack isn't on this machine ({root})")
    return [(p, root / p) for p in walk(root)]


def cmd_pack(doc, only, key_file, part_bytes, force=False, skip=None):
    lic = licensed_hashes()
    marker = placeholders()
    stray = sorted(p for p in lic if not game_vault_of(doc, p))
    if stray:
        die("tool/assets.sha256 lists files no game vault's match takes: " + ", ".join(stray) +
            ". Add a pattern to a game vault in tool/asset_vault.json")
    passarg, key_name = None, None
    changed = False
    for v in select(doc, only):
        files = collect(doc, v, skip)
        if not files:
            die(f"vault {v['name']}: no files to pack")
        entries, listing = [], []
        for name, src in files:
            data = src.read_bytes()
            h = sha256(data)
            if marker.get(name) == h:
                die(f"{name}: a placeholder tool/gen_placeholders.py drew ({MARKER}), never packed: unpack the "
                    "vault over it first (python3 tool/asset_vault.py sync)")
            if v["group"] == "game" and name in lic and lic[name] != h:
                die(f"{name}: its sha256 isn't tool/assets.sha256's: run python3 tool/asset_manifest.py first")
            entries.append((name, data))
            listing.append({"path": name, "bytes": len(data), "sha256": h, "needed_by_build": v["needed_by_build"]})
        tar = make_tar(entries)
        tsha = sha256(tar)
        if not force and v.get("tar", {}).get("sha256") == tsha and not part_problems(v) and v.get("files") == listing:
            print(f"{v['name']}: unchanged ({len(listing)} files), its parts kept")
            continue
        if passarg is None:
            passarg, key_name = key_pass(key_file)
            print(f"key: {key_name}")
        gz = gzip.compress(tar, compresslevel=9, mtime=0)
        code, enc, err = openssl(CIPHER + ["-salt"], gz, passarg)
        if code or not enc.startswith(b"Salted__"):
            die(f"vault {v['name']}: openssl couldn't encrypt it: {' '.join(err)}")
        code, back, err = openssl(["-d"] + CIPHER, enc, passarg)
        if code or back != gz:
            die(f"vault {v['name']}: the encrypted vault doesn't decrypt back to its plaintext: {' '.join(err)}")
        n = -(-len(enc) // part_bytes)
        names = part_names(v["name"], n)
        old = {p["path"] for p in v.get("parts", [])} | {
            rel_to_root(p) for p in (ROOT / VAULT_DIR).glob(f"{v['name']}.tar.gz.enc*")}
        (ROOT / VAULT_DIR).mkdir(exist_ok=True)
        for p in sorted(old - set(names)):
            (ROOT / p).unlink(missing_ok=True)
        parts = []
        for i, name in enumerate(names):
            chunk = enc[i * part_bytes:(i + 1) * part_bytes]
            tmp = ROOT / (name + ".tmp")
            tmp.write_bytes(chunk)
            os.replace(tmp, ROOT / name)
            parts.append({"path": name, "bytes": len(chunk), "sha256": sha256(chunk)})
        v["tar"] = {"sha256": tsha, "bytes": len(tar)}
        v["parts"] = parts
        v["files"] = listing
        changed = True
        print(f"{v['name']}: packed {len(listing)} files ({len(tar):,} bytes of tar) into {len(parts)} part(s), "
              f"{len(enc):,} bytes")
    if changed:
        doc["about"], doc["format"] = ABOUT, FORMAT
        JSON_PATH.write_text(dump(doc))
        print(f"wrote {rel_to_root(JSON_PATH)}")


def part_problems(v):
    probs = []
    for part in v.get("parts", []):
        p = ROOT / part["path"]
        if not p.is_file():
            probs.append(f"{part['path']}: missing (a part of vault {v['name']})")
        elif sha256(p.read_bytes()) != part["sha256"]:
            probs.append(f"{part['path']}: not the bytes tool/asset_vault.json lists (damaged, or packed elsewhere)")
    return probs


def cmd_check(doc, only, dest):
    sel = select(doc, only) if only else [v for v in doc["vaults"] if v["needed_by_build"]]
    probs, notes = [], []
    checked = 0
    for v in sel:
        if not packed(v):
            notes.append(v["name"])
            continue
        base = dest_of(v, dest)
        for f in v["files"]:
            p = base / f["path"]
            checked += 1
            if not p.is_file():
                probs.append(f"{rel_to_root(p)}: missing (vault {v['name']})")
            elif sha256(p.read_bytes()) != f["sha256"]:
                probs.append(f"{rel_to_root(p)}: not vault {v['name']}'s bytes (changed since the last pack: python3 "
                             f"tool/asset_vault.py pack --only {v['name']}; or damaged: unpack --only {v['name']} "
                             "--force)")
    if any(v["group"] == "game" for v in sel):
        base = Path(dest).expanduser().resolve() if dest else ROOT
        on_disk = game_files(doc, base)
        for p in sorted(licensed_hashes()):
            v = game_vault_of(doc, p)
            if not v:
                probs.append(f"{p}: tool/assets.sha256 lists it, but no game vault's match takes it (add a pattern "
                             "to a game vault in tool/asset_vault.json)")
            elif packed(v) and p not in {f["path"] for f in v["files"]} and p not in on_disk.get(v["name"], []):
                probs.append(f"{p}: missing, and not in vault {v['name']} (packed before it came)")
        for v in doc["vaults"]:
            if v["group"] != "game" or not packed(v) or v not in sel:
                continue
            listed = {f["path"] for f in v["files"]}
            for p in on_disk.get(v["name"], []):
                if p not in listed:
                    probs.append(f"{p}: not in vault {v['name']} (the vault is older than it): python3 "
                                 f"tool/asset_vault.py pack --only {v['name']}")
    for v in doc["vaults"]:
        probs += part_problems(v)
    if notes:
        print(f"NOTE never packed: {', '.join(notes)} (python3 tool/asset_vault.py pack, with the owner's key)")
    if probs:
        print(f"asset vault check: {len(probs)} problem(s)")
        for p in probs:
            print(f"  {p}")
        return 1
    parts = sum(len(v.get("parts", [])) for v in doc["vaults"])
    print(f"asset vault check: ok ({checked} files of {len(sel)} vault(s) at their paths with their sha256, "
          f"{parts} parts with theirs)")
    return 0


def open_vault(v, passarg, rev=None):
    """A vault's files [(path, bytes)], checked against the JSON at every step. rev: read its parts from that git
    revision (e.g. MERGE_HEAD) instead of the working tree."""
    if rev is None:
        bad = part_problems(v)
        if bad:
            die("; ".join(bad))
        enc = b"".join((ROOT / p["path"]).read_bytes() for p in v["parts"])
    else:
        chunks = []
        for part in v["parts"]:
            r = git("show", f"{rev}:{part['path']}", check=False)
            if r.returncode or sha256(r.stdout) != part["sha256"]:
                die(f"{part['path']}: not in {rev} with the sha256 its JSON lists")
            chunks.append(r.stdout)
        enc = b"".join(chunks)
    wrong = f"vault {v['name']}: can't open it: a wrong key, or damaged parts"
    code, gz, err = openssl(["-d"] + CIPHER, enc, passarg)
    if code:
        die(f"{wrong} (openssl: {' '.join(err)})")
    try:
        tar = gzip.decompress(gz)
    except (OSError, EOFError, ValueError, zlib.error) as e:
        die(f"{wrong} ({e})")
    if sha256(tar) != v["tar"]["sha256"]:
        die(f"{wrong} (its tar's sha256 isn't tool/asset_vault.json's)")
    files = read_tar(tar)
    want = [(f["path"], f["bytes"], f["sha256"]) for f in v["files"]]
    got = [(n, len(d), sha256(d)) for n, d in files]
    if got != want:
        die(f"vault {v['name']}: its files aren't the ones tool/asset_vault.json lists")
    return files


def cmd_unpack(doc, only, dest, force, key_file):
    sel = select(doc, only)
    if dest and not (all(v["group"] == "game" for v in sel) or len(sel) == 1):
        die("--dest takes game vaults, or one vault: two packs would land in one folder")
    unpacked = [v["name"] for v in sel if not packed(v)]
    if unpacked:
        die(f"never packed: {', '.join(unpacked)}")
    passarg, key_name = key_pass(key_file)
    print(f"key: {key_name}")
    marker = placeholders() if not dest else {}
    plan, conflicts = [], []
    for v in sel:
        base = dest_of(v, dest)
        for name, data in open_vault(v, passarg):
            target = base / safe_path(name, f"vault {v['name']}")
            if target.is_file():
                there = sha256(target.read_bytes())
                if there == sha256(data):
                    continue
                if not force and marker.get(rel_to_root(target)) != there:
                    conflicts.append(f"{rel_to_root(target)} (vault {v['name']})")
                    continue
            elif target.exists() or target.is_symlink():
                conflicts.append(f"{rel_to_root(target)}: not a regular file")
                continue
            plan.append((v["name"], target, data))
        print(f"{v['name']}: opened, {len(v['files'])} files match tool/asset_vault.json")
    if conflicts:
        die(f"{len(conflicts)} file(s) already there with other bytes; nothing written (--force overwrites them, "
            "or the vault is older than them: pack it): " + ", ".join(conflicts[:20]) +
            (" ..." if len(conflicts) > 20 else ""))
    for _, target, data in plan:
        write_file(target, data)
    if marker:
        forget_placeholders()
    for v in sel:
        n = sum(1 for name, _, _ in plan if name == v["name"])
        print(f"{v['name']}: {n} written, {len(v['files']) - n} already there, in {rel_to_root(dest_of(v, dest))}")
    return 0


# --- The git-ignored art: the hooks, sync, resolve, prune, commit ---------------------------------------------------
STATE = "asset_vault.synced"  # per worktree, in its git dir: {"vaults": {name: tar sha256}, "stale": {path: sha256}}
MARKER = "assets/.placeholders"  # tool/gen_placeholders.py's list of what it drew: {repo path: sha256}


def say(msg):
    print(f"asset_vault: {msg}", file=sys.stderr)


def git(*args, data=None, check=True):
    kw = {"input": data} if data is not None else {"stdin": subprocess.DEVNULL}
    try:
        r = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, **kw)
    except OSError as e:
        die(f"git: {e}")
    if check and r.returncode:
        die(f"git {' '.join(args)}: {r.stderr.decode(errors='replace').strip()}")
    return r


def git_config(name):
    try:
        r = subprocess.run(["git", "config", "--get", name], cwd=ROOT, capture_output=True, text=True,
                           stdin=subprocess.DEVNULL)
    except OSError:
        return None
    return r.stdout.strip() or None if r.returncode == 0 else None


def in_git():
    try:
        return git("rev-parse", "--git-dir", check=False).returncode == 0
    except VaultError:
        return False


def write_file(target, data):
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=target.parent, prefix=".vault-")
    with os.fdopen(fd, "wb") as f:
        f.write(data)
    os.chmod(tmp, 0o644)
    os.replace(tmp, target)


def placeholders():
    try:
        return dict(json.loads((ROOT / MARKER).read_text()))
    except (OSError, ValueError, TypeError):
        return {}


def forget_placeholders():
    """Drops from the marker every file that isn't its placeholder any more; the marker goes when none is left."""
    marker = placeholders()
    left = {p: h for p, h in marker.items() if (ROOT / p).is_file() and sha256((ROOT / p).read_bytes()) == h}
    if left:
        (ROOT / MARKER).write_text(json.dumps(left, indent=1, sort_keys=True) + "\n")
    else:
        (ROOT / MARKER).unlink(missing_ok=True)


def state_path():
    out = git("rev-parse", "--git-path", STATE).stdout.decode().strip()
    return Path(out) if os.path.isabs(out) else ROOT / out


def read_state():
    try:
        s = json.loads(state_path().read_text())
    except (OSError, ValueError):
        s = {}
    st = {"vaults": dict(s.get("vaults", {})), "stale": dict(s.get("stale", {}))}
    # A file waiting for prune stays one only while it still has its bytes.
    st["stale"] = {p: h for p, h in st["stale"].items()
                   if (ROOT / p).is_file() and sha256((ROOT / p).read_bytes()) == h}
    return st


def write_state(st):
    state_path().write_text(json.dumps(st, indent=1, sort_keys=True) + "\n")


def disk_state(doc, skip=None):
    """{game vault: (the tar sha256 its files on disk make, or None when there are none, {path: sha256})}."""
    on_disk = game_files(doc, ROOT)
    out = {}
    for v in doc["vaults"]:
        if v["group"] != "game":
            continue
        entries, shas = [], {}
        for p in on_disk.get(v["name"], []):
            data = (ROOT / p).read_bytes()
            h = sha256(data)
            if skip and skip.get(p) == h:
                continue
            entries.append((p, data))
            shas[p] = h
        out[v["name"]] = (sha256(make_tar(entries)) if entries else None, shas)
    return out


def doc_at(spec):
    """tool/asset_vault.json as git has it at spec (`:tool/asset_vault.json`, `HEAD:...`), or None."""
    r = git("show", spec, check=False)
    return json.loads(r.stdout) if r.returncode == 0 else None


def tar_sha(v):
    return v["tar"]["sha256"] if v and packed(v) else None


def linked_worktree():
    g = git("rev-parse", "--path-format=absolute", "--git-dir").stdout.decode().strip()
    c = git("rev-parse", "--path-format=absolute", "--git-common-dir").stdout.decode().strip()
    return Path(g).resolve() != Path(c).resolve()


def try_key(key_file):
    try:
        return key_pass(key_file)[0]
    except VaultError:
        return None


NO_KEY = ("no key here (POH_VAULT_KEY_FILE, `git config poh.vaultKeyFile`, or ~/.config/path-of-hero/asset-vault.key)."
          " Without it: python3 tool/gen_placeholders.py draws placeholders; members get the key from the owner")


def ignored(paths):
    """The paths .gitignore ignores (whether or not they are in the index)."""
    if not paths:
        return []
    r = git("check-ignore", "--no-index", "--stdin", "-z", data="\0".join(paths).encode() + b"\0", check=False)
    return [p for p in r.stdout.decode().split("\0") if p]


def cmd_sync(key_file, keep_mine=False, quiet=False):
    """post-checkout / post-merge: every game vault whose files are unedited since the last sync (or absent, or
    placeholders) is unpacked. Never fails as a hook (main() turns an error into a note)."""
    if not JSON_PATH.is_file() or not in_git():
        return 0
    doc = load()
    st = read_state()
    marker = placeholders()
    disk = disk_state(doc, st["stale"])
    need, edited = [], []
    for v in doc["vaults"]:
        if v["group"] != "game" or not packed(v):
            continue
        cur, shas = disk[v["name"]]
        want = tar_sha(v)
        if cur == want:
            st["vaults"][v["name"]] = want
            continue
        if keep_mine and cur is not None:
            st["vaults"][v["name"]] = want  # the next commit packs these files over the vault's
            say(f"{v['name']}: your files are kept; the next commit re-packs them over the vault")
            continue
        listing = {f["path"]: f["sha256"] for f in v["files"]}
        own = [p for p, h in shas.items() if listing.get(p) != h and marker.get(p) != h]
        if cur is None or cur == st["vaults"].get(v["name"]) or not own:
            need.append(v)
        else:
            edited.append(v["name"])
    if need:
        passarg = try_key(key_file)
        if not passarg:
            if not marker:
                say(f"{len(need)} vault(s) to unpack ({', '.join(v['name'] for v in need)}), but {NO_KEY}")
            write_state(st)
            return 0
        linked = linked_worktree()
        on_disk = game_files(doc, ROOT)
        for v in need:
            files = open_vault(v, passarg)
            for name, data in files:
                target = ROOT / safe_path(name, f"vault {v['name']}")
                if not target.is_file() or sha256(target.read_bytes()) != sha256(data):
                    write_file(target, data)
            listed = {f["path"] for f in v["files"]}
            gone = [p for p in on_disk.get(v["name"], []) if p not in listed and p not in st["stale"]]
            for p in gone:
                if linked:
                    (ROOT / p).unlink()
                else:
                    st["stale"][p] = sha256((ROOT / p).read_bytes())
            st["vaults"][v["name"]] = tar_sha(v)
            say(f"{v['name']}: unpacked ({len(files)} files)" + (f", {len(gone)} that left it deleted" if gone and
                                                                  linked else ""))
        if st["stale"] and not linked:
            say(f"{len(st['stale'])} file(s) left their vault but stay here while the game may run (deleting one "
                "under assets/ ends a running session): python3 tool/asset_vault.py prune  once it is closed")
        forget_placeholders()
    for name in edited:
        say(f"vault {name} changed in git, and so did your files: not unpacking over your edits. Keep them (python3 "
            f"tool/asset_vault.py sync --keep-mine, and the next commit re-packs them over the new vault), or take "
            f"the vault's (python3 tool/asset_vault.py unpack --only {name} --force)")
    write_state(st)
    return 0


def hook_pre_commit(key_file):
    if not JSON_PATH.is_file():
        return 0
    doc = load()
    staged = [p for p in git("diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z").stdout.decode().split("\0")
              if p]
    forced = ignored([p for p in staged if game_vault_of(doc, p)])
    if forced:
        die(f"{len(forced)} licensed file(s) staged past .gitignore, e.g. {forced[0]}: only the vault may hold them "
            f"in git. Unstage them: git rm --cached -- {' '.join(forced[:5])}")
    idx = doc_at(":tool/asset_vault.json")
    if idx is None:
        return 0
    staged_vaults = {v["name"]: v for v in idx["vaults"]}
    st = read_state()
    marker = placeholders()
    disk = disk_state(doc, st["stale"])
    need = []
    for name, (cur, shas) in disk.items():
        isha = tar_sha(staged_vaults.get(name))
        if cur is None or cur == isha:
            if cur is not None:
                st["vaults"][name] = isha
            continue
        if any(marker.get(p) == h for p, h in shas.items()):
            say(f"{name}: placeholders on disk (tool/gen_placeholders.py): never packed")
            continue
        last = st["vaults"].get(name)
        if last and isha and last != isha:
            die(f"vault {name} changed in git since your files were last synced with it (a merge or a checkout "
                "brought another one), and your files differ from it: packing them would undo that change. Run  "
                "python3 tool/asset_vault.py sync  (it unpacks unedited files), or  resolve  after a stopped merge, "
                "or  sync --keep-mine  to put your files over it on purpose")
        need.append(name)
    if need:
        if not try_key(key_file):
            say(f"the art of {', '.join(need)} changed, but {NO_KEY}: not packed, so this commit leaves the vault as "
                "it was")
            write_state(st)
            return 0
        say(f"the art changed: re-packing {', '.join(need)}")
        cmd_pack(doc, need, key_file, PART_BYTES, skip=st["stale"])
        git("add", "-A", "--", VAULT_DIR, rel_to_root(JSON_PATH))
        for v in load()["vaults"]:
            if v["name"] in need:
                st["vaults"][v["name"]] = tar_sha(v)
    write_state(st)
    return 0


def norm_url(url):
    u = (url or "").strip().lower()
    for pre in ("ssh://", "https://", "http://", "git://"):
        if u.startswith(pre):
            u = u[len(pre):]
    u = re.sub(r"^[^@/]*@", "", u).replace(":", "/", 1) if "@" in u.split("/")[0] else u
    return u[:-4] if u.endswith(".git") else u.rstrip("/")


def hook_pre_push(remote, url, lines):
    root = git_config("poh.publicRoot")
    if not root:
        return 0  # before the switch to the public history: no guard
    public_url = git_config("poh.publicUrl")
    to_public = remote == "public" or (public_url and norm_url(url) == norm_url(public_url))
    zero = "0" * 40
    for line in lines:
        parts = line.split()
        if len(parts) != 4:
            continue
        local_ref, local_sha, remote_ref, remote_sha = parts
        if local_sha.strip("0") == "":
            continue  # a delete
        roots = set(git("rev-list", "--max-parents=0", local_sha).stdout.decode().split())
        if to_public:
            if not (remote_ref == "refs/heads/main" or remote_ref.startswith("refs/tags/v")):
                die(f"{remote_ref}: only main (and v* tags) go to the public repository; develop and the work "
                    "branches stay here")
            if roots != {root}:
                die(f"{local_ref} isn't the public history (its first commit isn't poh.publicRoot {root[:12]}): "
                    "refused, so no old or private commit can reach the public repository")
            check = [sys.executable, str(Path(__file__).with_name("privacy_check.py"))]
            r = subprocess.run(check + ["--rev", local_sha], cwd=ROOT, stdin=subprocess.DEVNULL)
            if r.returncode:
                die("the privacy check failed on what you push (above): refused")
            # The commits' messages go public too: those the remote doesn't have yet.
            known = remote_sha.strip("0") and git("cat-file", "-e", remote_sha, check=False).returncode == 0
            have = [remote_sha] if known else []
            r = subprocess.run(check + ["--messages", local_sha, "--not", f"--remotes={remote}", *have], cwd=ROOT,
                               stdin=subprocess.DEVNULL)
            if r.returncode:
                die("the privacy check failed on a commit message you push (above): refused (reword it before it "
                    "goes public)")
        elif root in roots and not os.environ.get("POH_PUSH_PUBLIC_HISTORY"):
            die(f"{local_ref} is the public history; it goes to the public repository, not to {remote}. If that is "
                "intended: POH_PUSH_PUBLIC_HISTORY=1 git push ...")
    return 0


def cmd_install_hooks():
    git("config", "core.hooksPath", ".githooks")
    st = read_state()
    doc = load()
    for name, (cur, _) in disk_state(doc, st["stale"]).items():
        v = next(x for x in doc["vaults"] if x["name"] == name)
        if cur is not None and cur == tar_sha(v):
            st["vaults"][name] = cur
    write_state(st)
    say("hooks on (core.hooksPath .githooks, for every worktree of this clone): pre-commit re-packs changed art, "
        "pre-commit and commit-msg run the privacy check, "
        "post-checkout/post-merge unpack new vaults, pre-push guards the public history")
    return 0


def cmd_commit(args):
    doc = load()
    head = doc_at("HEAD:" + rel_to_root(JSON_PATH)) or {"vaults": []}
    by_name = {v["name"]: v for v in head["vaults"]}
    changed = [n for n, (cur, _) in disk_state(doc, read_state()["stale"]).items()
               if cur is not None and cur != tar_sha(by_name.get(n))]
    if not changed:
        die("the art didn't change: nothing for this to commit (a normal git commit takes everything else)")
    say(f"committing the art of {', '.join(changed)} (git commit --allow-empty: the hook adds the vault)")
    os.execvp("git", ["git", "commit", "--allow-empty", *args])


def cmd_resolve(key_file, take=None):
    """After `git merge` stopped (or before committing a merge): the game vaults merged file by file. A vault only one
    side changed takes that side; a vault both changed takes, per file, the side that changed it; a file both changed
    differently is a conflict (--take ours|theirs settles them all). Then the manifest is rewritten from the files, the
    changed vaults re-packed, and the JSON, the parts and the manifest staged."""
    jp = rel_to_root(JSON_PATH)
    if git("rev-parse", "-q", "--verify", "MERGE_HEAD", check=False).returncode:
        die("no merge in progress (MERGE_HEAD): resolve is for a `git merge` that stopped")
    base_rev = git("merge-base", "HEAD", "MERGE_HEAD").stdout.decode().split()[0]
    ours, theirs = doc_at(f"HEAD:{jp}"), doc_at(f"MERGE_HEAD:{jp}")
    base = doc_at(f"{base_rev}:{jp}") or {"vaults": []}
    if ours is None or theirs is None:
        die(f"{jp} is missing on one side of the merge")
    by = lambda d: {v["name"]: v for v in d["vaults"] if v["group"] == "game"}  # noqa: E731
    bv, ov, tv = by(base), by(ours), by(theirs)
    st = read_state()
    disk = disk_state(ours, st["stale"])
    files_of = lambda v: {f["path"]: f["sha256"] for f in v["files"]} if v and packed(v) else {}  # noqa: E731
    take_theirs, repack, plan, conflicts = [], [], [], []
    for name in sorted(set(ov) | set(tv)):
        o, t, b = ov.get(name), tv.get(name), bv.get(name)
        if tar_sha(o) == tar_sha(t) or tar_sha(t) == tar_sha(b):
            continue  # same, or only ours changed it
        if disk.get(name, (None,))[0] not in (None, tar_sha(o)):
            die(f"vault {name}: your files differ from your own commit's vault: commit them first (python3 "
                "tool/asset_vault.py commit), then merge again")
        if tar_sha(o) == tar_sha(b):
            take_theirs.append(name)
            continue
        bf, of, tf = files_of(b), files_of(o), files_of(t)
        for p in sorted(set(bf) | set(of) | set(tf)):
            B, O, T = bf.get(p), of.get(p), tf.get(p)
            if O == T or T == B:
                continue
            if O == B or take == "theirs":
                plan.append((name, p, T))
            elif take != "ours":
                conflicts.append(f"{p} (vault {name})")
        repack.append(name)
    if conflicts:
        die(f"{len(conflicts)} file(s) changed differently on both sides: " + ", ".join(conflicts[:20]) +
            ". Look at both, then  resolve --take ours  or  --take theirs  (for all of them), or edit and resolve "
            "--take ours")
    if not take_theirs and not repack:
        say("no vault to merge")
        return 0
    passarg, key_name = key_pass(key_file)
    say(f"key: {key_name}")
    theirs_files = {}
    for name in sorted(set(take_theirs) | {n for n, _, _ in plan}):
        theirs_files[name] = dict(open_vault(tv[name], passarg, rev="MERGE_HEAD"))
    merged = json.loads(json.dumps(ours))
    for i, v in enumerate(merged["vaults"]):
        if v["name"] in take_theirs:
            merged["vaults"][i] = tv[v["name"]]
    merged["vaults"] += [tv[n] for n in take_theirs if n not in ov]
    for name in take_theirs:
        t = tv[name]
        for part in ov.get(name, {}).get("parts", []):
            (ROOT / part["path"]).unlink(missing_ok=True)
        for part in t["parts"]:
            write_file(ROOT / part["path"], git("show", f"MERGE_HEAD:{part['path']}").stdout)
        listed = files_of(t)
        for p in disk.get(name, (None, {}))[1]:
            if p not in listed:
                (ROOT / p).unlink()
        for p, data in theirs_files[name].items():
            write_file(ROOT / p, data)
        st["vaults"][name] = tar_sha(t)
    for name, p, T in plan:
        if T is None:
            (ROOT / p).unlink(missing_ok=True)
        else:
            write_file(ROOT / p, theirs_files[name][p])
    JSON_PATH.write_text(dump(merged))
    manifest = Path(__file__).with_name("asset_manifest.py")
    if manifest.is_file():
        r = subprocess.run([sys.executable, str(manifest)], cwd=ROOT, stdin=subprocess.DEVNULL)
        if r.returncode:
            die("tool/asset_manifest.py failed on the merged files (above)")
        git("add", "--", "tool/asset_manifest.json", "tool/assets.sha256", "tool/placeholders.gitignore")
    if repack:
        cmd_pack(merged, repack, key_file, PART_BYTES, skip=st["stale"])
        for v in load()["vaults"]:
            if v["name"] in repack:
                st["vaults"][v["name"]] = tar_sha(v)
    git("add", "-A", "--", VAULT_DIR, jp)
    write_state(st)
    say(f"merged: {', '.join(take_theirs + repack)}; staged. Check `git status`, then commit the merge")
    return 0


def cmd_prune(force=False):
    doc = load()
    st = read_state() if in_git() else {"vaults": {}, "stale": {}}
    listed = {f["path"] for v in doc["vaults"] if v["group"] == "game" and packed(v) for f in v["files"]}
    gone = [p for ps in game_files(doc, ROOT).values() for p in ps if p not in listed]
    kept = []
    for p in gone:
        if p in st["stale"] or force:
            (ROOT / p).unlink()
            print(f"deleted {p}")
        else:
            kept.append(p)
    if kept:
        print(f"{len(kept)} file(s) in no vault and not left by a sync (new art not packed yet?), kept: "
              + ", ".join(kept[:20]) + " (pack them, or prune --force)")
    st["stale"] = {}
    if in_git():
        write_state(st)
    return 0


def cmd_list(doc):
    for v in doc["vaults"]:
        if packed(v):
            size = sum(p["bytes"] for p in v["parts"])
            what = f"{len(v['files'])} files, {v['tar']['bytes']:,} bytes of tar, {len(v['parts'])} part(s) {size:,} bytes"
        else:
            what = "never packed"
        print(f"{v['name']:<28} {v['group']:<6} {'needed' if v['needed_by_build'] else '      '}  {what}")
    return 0


def set_root(path):
    """Works on another checkout's vault (its tool/asset_vault.json and assets-vault/), e.g. the private notes'."""
    global ROOT, JSON_PATH, HASHES, PACK_INDEX
    ROOT = Path(path).expanduser().resolve()
    JSON_PATH = ROOT / "tool/asset_vault.json"
    HASHES = ROOT / "tool/assets.sha256"
    PACK_INDEX = ROOT / "tool/asset_packs/index.json"


HOOKS = ("pre-commit", "post-update", "pre-push")


def main(argv):
    if len(argv) >= 2 and argv[0] == "--root":
        set_root(argv[1])
        argv = argv[2:]
    if argv[:1] == ["commit"]:
        try:
            return cmd_commit(argv[1:])
        except VaultError as e:
            print(f"asset_vault: {e}", file=sys.stderr)
            return 1
    if argv[:1] == ["hook"]:
        which = argv[1] if len(argv) > 1 else ""
        if which not in HOOKS:
            print(f"usage: asset_vault.py hook {'|'.join(HOOKS)}", file=sys.stderr)
            return 2
        try:
            if which == "pre-commit":
                return hook_pre_commit(None)
            if which == "pre-push":
                return hook_pre_push(argv[2] if len(argv) > 2 else "", argv[3] if len(argv) > 3 else "",
                                     sys.stdin.read().splitlines())
            return cmd_sync(None)
        except VaultError as e:
            print(f"asset_vault: {e}", file=sys.stderr)
            # post-checkout and post-merge can't stop anything: a note, never a failure.
            return 0 if which == "post-update" else 1
    ap = argparse.ArgumentParser(description="The asset vault (docs/assets.md \"The asset vault\").")
    ap.add_argument("command", choices=["check", "pack", "unpack", "list", "sync", "resolve", "prune",
                                        "install-hooks"])
    ap.add_argument("--only", nargs="+", metavar="NAME", default=[])
    ap.add_argument("--dest")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--key-file")
    ap.add_argument("--keep-mine", action="store_true")
    ap.add_argument("--take", choices=["ours", "theirs"])
    ap.add_argument("--part-bytes", type=int, default=PART_BYTES, help=argparse.SUPPRESS)  # tests only
    a = ap.parse_args(argv)
    if a.command not in ("pack", "unpack", "prune") and a.force:
        ap.error("--force is pack's, unpack's and prune's")
    if a.command not in ("check", "unpack") and a.dest:
        ap.error("--dest is check's and unpack's")
    if a.command not in ("pack", "unpack", "sync", "resolve") and a.key_file:
        ap.error("--key-file is pack's, unpack's, sync's and resolve's (check and list need no key)")
    if a.keep_mine and a.command != "sync":
        ap.error("--keep-mine is sync's")
    if a.take and a.command != "resolve":
        ap.error("--take is resolve's")
    try:
        if a.command == "install-hooks":
            return cmd_install_hooks()
        if a.command == "sync":
            return cmd_sync(a.key_file, a.keep_mine)
        if a.command == "resolve":
            return cmd_resolve(a.key_file, a.take)
        doc = load()
        if a.command == "check":
            return cmd_check(doc, a.only, a.dest)
        if a.command == "pack":
            cmd_pack(doc, a.only, a.key_file, a.part_bytes, a.force)
            return 0
        if a.command == "unpack":
            return cmd_unpack(doc, a.only, a.dest, a.force, a.key_file)
        if a.command == "prune":
            return cmd_prune(a.force)
        return cmd_list(doc)
    except VaultError as e:
        print(f"asset_vault: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
