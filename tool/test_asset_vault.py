"""Tests tool/asset_vault.py (docs/assets.md "The asset vault", decisions-log 232) on a tiny fake repo with throwaway
keys, in temp dirs only: it never reads the owner's key (every run gets a HOME of its own, and a key of its own).
- pack then unpack gives the same bytes; an unchanged vault is never rewritten, and a change rewrites only its vault;
- check fails on a missing or altered file, a file newer than its vault, a licensed file no vault takes, a damaged part;
- parts: a split vault joins, the documented one-command open reads it, a missing part refuses, old parts go;
- a wrong key fails cleanly and writes nothing; the key file's rules (mode 600, missing, empty, inside the repo); the
  env var key; the key's text is never printed;
- a different existing file is never overwritten without --force (and then nothing at all is written);
- the tar is deterministic ustar; unsafe paths in the JSON are refused;
- the repo's own tool/asset_vault.json: every licensed file has a game vault, every pack a slug in the packs' index.
Stdlib and the openssl binary:  python3 tool/test_asset_vault.py
"""
import hashlib
import io
import json
import os
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
sys.path.insert(0, str(HERE))
import asset_vault as av  # noqa: E402


def sha(b):
    return hashlib.sha256(b).hexdigest()


class FakeRepo:
    """A temp repo: tool/asset_vault.py, a JSON of three game vaults and one pack, the licensed files and a pack."""

    def __init__(self, tmp):
        self.tmp = Path(tmp)
        self.root = self.tmp / "repo"
        (self.root / "tool/asset_packs").mkdir(parents=True)
        shutil.copy(HERE / "asset_vault.py", self.root / "tool/asset_vault.py")
        self.home = self.tmp / "home"
        self.home.mkdir()
        self.pack_dir = self.tmp / "packs/Fake_Pack"  # outside the repo, like a bought pack
        self.files = {
            "assets/images/a_one.png": os.urandom(3000),
            "assets/images/a_two.png": b"a two " * 50,
            "assets/images/b_one.png": os.urandom(5000),
            "assets/images/b_mark.png": b"the mark goes to game-a, the first vault that takes it",
            "web/icons/Icon-1.png": os.urandom(800),
        }
        for p, data in self.files.items():
            (self.root / p).parent.mkdir(parents=True, exist_ok=True)
            (self.root / p).write_bytes(data)
        (self.root / "assets/sfx").mkdir(parents=True)
        (self.root / "assets/sfx/own.wav").write_bytes(b"our own sound, never in a vault")
        self.pack_files = {"read_me.txt": b"terms", "Sheets/16x16/One.png": os.urandom(400),
                           "Sheets/16x16/" + "Very_Long_Name_" * 6 + ".png": os.urandom(300)}
        for p, data in self.pack_files.items():
            (self.pack_dir / p).parent.mkdir(parents=True, exist_ok=True)
            (self.pack_dir / p).write_bytes(data)
        (self.root / "tool/asset_packs/index.json").write_text(json.dumps(
            {"packs": [{"slug": "fake-pack", "root": str(self.pack_dir)}]}))
        self.write_hashes()
        doc = {"about": av.ABOUT, "format": av.FORMAT, "vaults": [
            {"name": "game-a", "group": "game", "pack": "A", "licence": "a", "needed_by_build": True,
             "match": ["assets/images/a_*", "assets/images/b_mark.png"]},
            {"name": "game-b", "group": "game", "pack": "B", "licence": "b", "needed_by_build": True,
             "match": ["assets/images/b_*"]},
            {"name": "game-icon", "group": "game", "pack": "I", "licence": "i", "needed_by_build": True,
             "match": ["web/icons/*.png"]},
            {"name": "fake-pack", "group": "packs", "pack": "F", "licence": "f", "needed_by_build": False,
             "slug": "fake-pack"},
        ]}
        (self.root / "tool/asset_vault.json").write_text(av.dump(doc))
        self.key = self.new_key("key.txt")

    def write_hashes(self):
        lines = [f"{sha((self.root / p).read_bytes())}  {p}\n" for p in sorted(self.files) if p.startswith("assets/")]
        (self.root / "tool/assets.sha256").write_text("".join(lines))

    def new_key(self, name, mode=0o600):
        path = self.tmp / name
        subprocess.run(["openssl", "rand", "-base64", "-out", str(path), "32"], check=True, stdin=subprocess.DEVNULL)
        os.chmod(path, mode)
        return path

    def run(self, *args, env=None):
        e = {k: v for k, v in os.environ.items() if not k.startswith("POH_VAULT")}
        e["HOME"] = str(self.home)
        e.update(env or {})
        r = subprocess.run([sys.executable, "-B", str(self.root / "tool/asset_vault.py"), *args], capture_output=True,
                           text=True, env=e, stdin=subprocess.DEVNULL)
        return r.returncode, r.stdout + r.stderr

    def doc(self):
        return json.loads((self.root / "tool/asset_vault.json").read_text())

    def vault(self, name):
        return next(v for v in self.doc()["vaults"] if v["name"] == name)

    def parts(self):
        """{part file: (bytes, inode, mtime_ns)}"""
        out = {}
        for p in sorted((self.root / "assets-vault").iterdir()):
            st = p.stat()
            out[p.name] = (p.read_bytes(), st.st_ino, st.st_mtime_ns)
        return out


class AssetVault(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory(prefix="test-asset-vault-")
        self.r = FakeRepo(self._tmp.name)
        self.outputs = []

    def tearDown(self):
        key_texts = [p.read_text().strip() for p in self.r.tmp.glob("*.txt")]
        for out in self.outputs:
            for k in key_texts + [getattr(self, "env_key", None)]:
                if k:
                    self.assertNotIn(k, out, "a key's text was printed")
        self._tmp.cleanup()

    def run_ok(self, *args, **kw):
        code, out = self.r.run(*args, **kw)
        self.outputs.append(out)
        self.assertEqual(code, 0, out)
        return out

    def run_fail(self, *args, **kw):
        code, out = self.r.run(*args, **kw)
        self.outputs.append(out)
        self.assertEqual(code, 1, out)
        return out

    def pack(self, *extra):
        return self.run_ok("pack", "--key-file", str(self.r.key), *extra)

    def test_pack_then_unpack_gives_the_same_bytes(self):
        out = self.pack()
        self.assertIn("game-a: packed 3 files", out)
        self.assertIn("game-b: packed 1 files", out)  # b_mark.png went to game-a, the first match
        names = sorted(p.name for p in (self.r.root / "assets-vault").iterdir())
        self.assertEqual(names, ["fake-pack.tar.gz.enc", "game-a.tar.gz.enc", "game-b.tar.gz.enc",
                                 "game-icon.tar.gz.enc"])
        a = self.r.vault("game-a")
        self.assertEqual([f["path"] for f in a["files"]],
                         ["assets/images/a_one.png", "assets/images/a_two.png", "assets/images/b_mark.png"])
        self.assertTrue(all(f["needed_by_build"] for f in a["files"]))
        self.assertFalse(any(f["needed_by_build"] for f in self.r.vault("fake-pack")["files"]))
        for part in a["parts"]:
            self.assertEqual(sha((self.r.root / part["path"]).read_bytes()), part["sha256"])
        self.assertIn("asset vault check: ok (5 files", self.run_ok("check"))
        for p in self.r.files:
            (self.r.root / p).unlink()
        out = self.run_fail("check")
        self.assertIn("assets/images/a_one.png: missing (vault game-a)", out)
        self.assertIn("web/icons/Icon-1.png: missing (vault game-icon)", out)
        out = self.run_ok("unpack", "--only", "game", "--key-file", str(self.r.key))
        self.assertIn("game-a: 3 written, 0 already there", out)
        for p, data in self.r.files.items():
            self.assertEqual((self.r.root / p).read_bytes(), data, p)
        self.run_ok("check")
        self.assertFalse((self.r.root / "assets-vault/own.wav").exists())
        # A pack lands at its root (tool/asset_packs/index.json), or with --dest where asked.
        dest = self.r.tmp / "elsewhere"
        self.run_ok("unpack", "--only", "fake-pack", "--dest", str(dest), "--key-file", str(self.r.key))
        for p, data in self.r.pack_files.items():
            self.assertEqual((dest / p).read_bytes(), data, p)
        self.run_ok("check", "--only", "fake-pack", "--dest", str(dest))
        out = self.run_ok("unpack", "--only", "packs", "--key-file", str(self.r.key))
        self.assertIn(f"fake-pack: 0 written, 3 already there, in {self.r.pack_dir}", out)

    def test_an_unchanged_vault_is_never_rewritten(self):
        self.pack()
        before, doc = self.r.parts(), (self.r.root / "tool/asset_vault.json").read_bytes()
        out = self.run_ok("pack")  # nothing to encrypt: no key needed
        self.assertEqual(out.count("unchanged"), 4, out)
        self.assertNotIn("wrote", out)
        self.assertEqual(self.r.parts(), before)
        self.assertEqual((self.r.root / "tool/asset_vault.json").read_bytes(), doc)
        # One file changes: only its vault is encrypted again.
        (self.r.root / "assets/images/b_one.png").write_bytes(b"new b")
        self.r.files["assets/images/b_one.png"] = b"new b"
        self.r.write_hashes()
        out = self.pack()
        self.assertIn("game-b: packed 1 files", out)
        after = self.r.parts()
        self.assertNotEqual(after["game-b.tar.gz.enc"], before["game-b.tar.gz.enc"])
        for name in ("game-a.tar.gz.enc", "game-icon.tar.gz.enc", "fake-pack.tar.gz.enc"):
            self.assertEqual(after[name], before[name], name)
        self.assertEqual(self.r.vault("game-b")["files"][0]["sha256"], sha(b"new b"))
        # --force encrypts every vault again (a new key): new ciphertext, the same plaintext.
        new_key = self.r.new_key("new-key.txt")
        out = self.run_ok("pack", "--force", "--key-file", str(new_key))
        self.assertEqual(out.count("packed"), 4, out)
        self.assertNotEqual(self.r.parts()["game-a.tar.gz.enc"], after["game-a.tar.gz.enc"])
        self.run_fail("unpack", "--only", "game-a", "--force", "--key-file", str(self.r.key))
        self.run_ok("unpack", "--only", "game-a", "--key-file", str(new_key))
        # A licensed file whose bytes aren't tool/assets.sha256's: the manifest first.
        (self.r.root / "assets/images/a_two.png").write_bytes(b"changed without the manifest")
        self.assertIn("run python3 tool/asset_manifest.py first", self.run_fail("pack", "--key-file", str(self.r.key)))

    def test_check_names_every_problem(self):
        self.pack()
        (self.r.root / "assets/images/a_one.png").unlink()
        (self.r.root / "assets/images/b_one.png").write_bytes(b"altered")
        (self.r.root / "assets/images/a_three.png").write_bytes(b"new, never packed")
        (self.r.root / "assets/images/c_new.png").write_bytes(b"licensed, no vault takes it")
        with open(self.r.root / "tool/assets.sha256", "a") as f:
            f.write(f"{sha(b'licensed, no vault takes it')}  assets/images/c_new.png\n")
        with open(self.r.root / "assets-vault/game-icon.tar.gz.enc", "ab") as f:
            f.write(b"x")
        out = self.run_fail("check")
        self.assertIn("assets/images/a_one.png: missing (vault game-a)", out)
        self.assertIn("assets/images/b_one.png: not vault game-b's bytes", out)
        self.assertIn("assets/images/a_three.png: not in vault game-a", out)
        self.assertIn("assets/images/c_new.png: tool/assets.sha256 lists it, but no game vault's match takes it", out)
        self.assertIn("assets-vault/game-icon.tar.gz.enc: not the bytes tool/asset_vault.json lists", out)
        self.assertIn("5 problem(s)", out)
        # pack refuses a licensed file without a vault, before anything is written.
        self.assertIn("no game vault's match takes", self.run_fail("pack", "--key-file", str(self.r.key)))

    def test_a_vault_never_packed_is_noted_not_failed(self):
        out = self.run_ok("check")
        self.assertIn("NOTE never packed: game-a, game-b, game-icon", out)
        self.assertIn("never packed: game-a", self.run_fail("unpack", "--key-file", str(self.r.key)))

    def test_parts_join_and_the_one_command_open(self):
        self.pack("--only", "fake-pack", "--part-bytes", "300")
        parts = [p["path"] for p in self.r.vault("fake-pack")["parts"]]
        self.assertGreaterEqual(len(parts), 2)
        self.assertEqual(parts[0], "assets-vault/fake-pack.tar.gz.enc.part01")
        self.assertTrue(all(p["bytes"] <= 300 for p in self.r.vault("fake-pack")["parts"]))
        dest = self.r.tmp / "joined"
        self.run_ok("unpack", "--only", "fake-pack", "--dest", str(dest), "--key-file", str(self.r.key))
        for p, data in self.r.pack_files.items():
            self.assertEqual((dest / p).read_bytes(), data, p)
        # docs/assets.md's command, the JSON's format.open: the shell joins the parts in name order.
        one = self.r.tmp / "one"
        one.mkdir()
        cmd = self.r.doc()["format"]["open"].replace("<name>", "fake-pack").replace(
            "<key file>", str(self.r.key)).replace("<dest>", str(one))
        r = subprocess.run(["bash", "-c", cmd], cwd=self.r.root, capture_output=True, text=True,
                           stdin=subprocess.DEVNULL)
        self.assertEqual(r.returncode, 0, r.stderr)
        for p, data in self.r.pack_files.items():
            self.assertEqual((one / p).read_bytes(), data, p)
        # A missing part: refused before decrypting, nothing written.
        (self.r.root / parts[1]).unlink()
        dest2 = self.r.tmp / "missing"
        out = self.run_fail("unpack", "--only", "fake-pack", "--dest", str(dest2), "--key-file", str(self.r.key))
        self.assertIn(f"{parts[1]}: missing (a part of vault fake-pack)", out)
        self.assertFalse(dest2.exists())
        # Packed again in one part: the old parts go.
        (self.r.pack_dir / "read_me.txt").write_bytes(b"terms, changed")
        self.pack("--only", "fake-pack")
        self.assertEqual(sorted(p.name for p in (self.r.root / "assets-vault").glob("fake-pack*")),
                         ["fake-pack.tar.gz.enc"])

    def test_a_wrong_key_fails_cleanly_and_writes_nothing(self):
        self.pack()
        (self.r.root / "assets/images/a_one.png").unlink()
        other = self.r.new_key("other.txt")
        out = self.run_fail("unpack", "--only", "game", "--key-file", str(other))
        self.assertIn("can't open it: a wrong key, or damaged parts", out)
        self.assertNotIn("Traceback", out)
        self.assertFalse((self.r.root / "assets/images/a_one.png").exists())

    def test_the_key_file_rules(self):
        self.pack("--only", "game-a")
        loose = self.r.new_key("loose.txt", 0o644)
        out = self.run_fail("unpack", "--only", "game-a", "--key-file", str(loose))
        self.assertIn(f"run  chmod 600 {loose}", out)
        self.assertIn("no key file at", self.run_fail("unpack", "--only", "game-a", "--key-file", str(self.r.tmp / "nope.txt")))
        empty = self.r.tmp / "empty.txt"
        empty.write_bytes(b"")
        os.chmod(empty, 0o600)
        self.assertIn("is empty", self.run_fail("unpack", "--only", "game-a", "--key-file", str(empty)))
        inside = self.r.root / "key-inside.txt"
        shutil.copy(self.r.key, inside)
        os.chmod(inside, 0o600)
        self.assertIn("inside the repository", self.run_fail("unpack", "--only", "game-a", "--key-file", str(inside)))
        inside.unlink()
        # No key named: the default ~/.config/path-of-hero/asset-vault.key, in this run's own HOME.
        self.assertIn(f"no key file at {self.r.home}/.config/path-of-hero/asset-vault.key",
                      self.run_fail("unpack", "--only", "game-a"))
        # A clone names its own key file in its git config (a machine's setting, never in the repository).
        subprocess.run(["git", "init", "-q", str(self.r.root)], check=True, stdin=subprocess.DEVNULL,
                       env={**os.environ, "HOME": str(self.r.home)})
        subprocess.run(["git", "-C", str(self.r.root), "config", "poh.vaultKeyFile", str(self.r.key)], check=True,
                       stdin=subprocess.DEVNULL)
        self.assertIn(f"key: {self.r.key}", self.run_ok("unpack", "--only", "game-a"))
        shutil.rmtree(self.r.root / ".git")
        # POH_VAULT_KEY_FILE names it; POH_VAULT_KEY is the key itself (CI's secret), handed to openssl as env:.
        self.run_ok("unpack", "--only", "game-a", env={"POH_VAULT_KEY_FILE": str(self.r.key)})
        self.env_key = "throwaway-" + os.urandom(12).hex()
        (self.r.root / "assets/images/a_one.png").write_bytes(b"x")
        self.r.files["assets/images/a_one.png"] = b"x"
        self.r.write_hashes()
        out = self.run_ok("pack", "--only", "game-a", env={"POH_VAULT_KEY": self.env_key})
        self.assertIn("key: the env var POH_VAULT_KEY", out)
        (self.r.root / "assets/images/a_one.png").unlink()
        self.run_ok("unpack", "--only", "game-a", env={"POH_VAULT_KEY": self.env_key})
        self.assertEqual((self.r.root / "assets/images/a_one.png").read_bytes(), b"x")
        self.run_fail("unpack", "--only", "game-a", "--key-file", str(self.r.key))  # the file's key isn't it now

    def test_a_different_file_is_never_overwritten_without_force(self):
        self.pack()
        (self.r.root / "assets/images/a_two.png").write_bytes(b"someone's edit")
        (self.r.root / "assets/images/b_one.png").unlink()
        out = self.run_fail("unpack", "--only", "game", "--key-file", str(self.r.key))
        self.assertIn("1 file(s) already there with other bytes; nothing written", out)
        self.assertIn("assets/images/a_two.png (vault game-a)", out)
        self.assertFalse((self.r.root / "assets/images/b_one.png").exists())
        self.assertEqual((self.r.root / "assets/images/a_two.png").read_bytes(), b"someone's edit")
        self.run_ok("unpack", "--only", "game", "--force", "--key-file", str(self.r.key))
        self.assertEqual((self.r.root / "assets/images/a_two.png").read_bytes(), self.r.files["assets/images/a_two.png"])
        self.assertTrue((self.r.root / "assets/images/b_one.png").exists())

    def test_the_tar_is_deterministic_ustar(self):
        long = "Folder_" * 20 + "/" + "x" * 90 + ".png"
        entries = [("b.png", b"bb"), ("a/c.png", b"c" * 700), (long, b"long")]
        one, two = av.make_tar(entries), av.make_tar(list(reversed(entries)))
        self.assertEqual(one, two)
        self.assertEqual(len(one) % 10240, 0)
        with tarfile.open(fileobj=io.BytesIO(one), mode="r:") as t:
            members = t.getmembers()
            self.assertEqual([m.name for m in members], [long, "a/c.png", "b.png"])
            for m in members:
                self.assertEqual((m.mode, m.uid, m.gid, m.uname, m.gname, m.mtime, m.pax_headers),
                                 (0o644, 0, 0, "", "", av.MTIME, {}))
                self.assertTrue(m.isreg())
            self.assertEqual(t.extractfile(long).read(), b"long")
        r = subprocess.run(["tar", "-tf", "-"], input=one, capture_output=True, stdin=None)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.decode().split(), [long, "a/c.png", "b.png"])
        with self.assertRaises(av.VaultError):
            av.make_tar([("x" * 101, b"")])  # no folder to split off

    def test_unsafe_paths_are_refused(self):
        doc = self.r.doc()
        for bad in ("../escape.png", "/abs.png", "a/../b.png", "a\\b.png", ".hidden/x.png", "C:/x.png"):
            doc["vaults"][0]["files"] = [{"path": bad, "bytes": 1, "sha256": "0" * 64, "needed_by_build": True}]
            (self.r.root / "tool/asset_vault.json").write_text(json.dumps(doc))
            self.assertIn("vault game-a's file", self.run_fail("check"), bad)


@unittest.skipUnless((REPO / "tool/asset_vault.json").is_file() and (REPO / "tool/asset_packs/index.json").is_file(),
                     "the private repo's vault listing and packs' index aren't here")
class TheRepoJson(unittest.TestCase):
    """The repo's own tool/asset_vault.json (no key, no vault opened)."""

    def test_every_licensed_file_has_a_game_vault_and_every_pack_a_slug(self):
        doc = json.loads((REPO / "tool/asset_vault.json").read_text())
        self.assertEqual(av.dump(doc), (REPO / "tool/asset_vault.json").read_text(), "not as the tool writes it")
        hashes = [ln.split(None, 1)[1].strip() for ln in (REPO / "tool/assets.sha256").read_text().splitlines() if ln]
        self.assertTrue(hashes)
        self.assertEqual([p for p in hashes if not av.game_vault_of(doc, p)], [])
        slugs = {p["slug"] for p in json.loads((REPO / "tool/asset_packs/index.json").read_text())["packs"]}
        for v in doc["vaults"]:
            self.assertEqual(v["needed_by_build"], v["group"] == "game", v["name"])
            self.assertTrue(v["licence"] and v["pack"], v["name"])
            if v["group"] == "packs":
                self.assertIn(v["slug"], slugs)
            for f in v.get("files", []):
                self.assertEqual(f["needed_by_build"], v["needed_by_build"], f["path"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
