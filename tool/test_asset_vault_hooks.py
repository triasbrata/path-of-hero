"""Tests the asset vault's git side (tool/asset_vault.py sync, resolve, prune, commit, install-hooks and the .githooks;
docs/assets.md "The asset vault") in scratch git clones of a tiny public-layout repo: the art git-ignored, only its
vaults tracked. Throwaway keys and a HOME of its own: it never reads the owner's key or git config.
- a clone with the key gets the art from the vaults (sync), byte for byte; a worktree (post-checkout) and a
  `git archive` mirror (unpack) too;
- an edit re-packs only its vault (`commit` for the art alone); a touch re-packs nothing and `commit` refuses;
- a pull unpacks the new vault (post-merge); files with edits of their own are left alone and the next commit is
  refused (the vault moved), until `sync --keep-mine` or an unpack;
- two clones editing different files of one vault: `resolve` merges them; the same file both ways is a conflict,
  settled with --take;
- placeholders are never packed; a licensed file forced past .gitignore is refused;
- a file that left its vault is deleted in a linked worktree but only listed in the main checkout, until prune;
- pre-push: only main and v* tags of the public history reach the public remote; that history goes nowhere else
  unless POH_PUSH_PUBLIC_HISTORY=1; the privacy check runs on what goes public, files and commit messages.
Stdlib, git and openssl:  python3 tool/test_asset_vault_hooks.py
"""
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import asset_vault as av  # noqa: E402

GITIGNORE = "/assets/images/*\n/assets/.placeholders\n"


def sha(b):
    return hashlib.sha256(b).hexdigest()


class Scratch:
    def __init__(self, tmp):
        self.tmp = Path(tmp)
        self.home = self.tmp / "home"
        self.home.mkdir()
        self.key = self.tmp / "key.txt"
        subprocess.run(["openssl", "rand", "-base64", "-out", str(self.key), "32"], check=True,
                       stdin=subprocess.DEVNULL)
        os.chmod(self.key, 0o600)
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(("POH_", "GIT_"))}
        self.env.update(HOME=str(self.home), GIT_CONFIG_NOSYSTEM="1", GIT_AUTHOR_NAME="T",
                        GIT_AUTHOR_EMAIL="t@example.com", GIT_COMMITTER_NAME="T", GIT_COMMITTER_EMAIL="t@example.com")
        (self.home / ".gitconfig").write_text("[init]\n\tdefaultBranch = main\n[advice]\n\tdetachedHead = false\n")

    def run(self, cwd, *args, ok=True, env=None):
        r = subprocess.run(list(args), cwd=cwd, capture_output=True, text=True, env={**self.env, **(env or {})},
                           stdin=subprocess.DEVNULL)
        out = r.stdout + r.stderr
        if ok is True:
            assert r.returncode == 0, f"{args} failed:\n{out}"
        elif ok is False:
            assert r.returncode != 0, f"{args} should have failed:\n{out}"
        return out

    def git(self, cwd, *args, **kw):
        return self.run(cwd, "git", *args, **kw)

    def tool(self, cwd, *args, **kw):
        return self.run(cwd, sys.executable, "-B", "tool/asset_vault.py", *args, **kw)

    def origin(self):
        """A bare origin holding a first commit: two game vaults, packed, the art git-ignored."""
        bare = self.tmp / "origin.git"
        self.git(self.tmp, "init", "-q", "--bare", str(bare))
        a = self.tmp / "seed"
        a.mkdir()
        (a / "tool").mkdir()
        for name in ("asset_vault.py", "privacy_check.py"):
            shutil.copy(HERE / name, a / "tool" / name)
        shutil.copytree(HERE.parent / ".githooks", a / ".githooks")
        (a / ".gitignore").write_text(GITIGNORE)
        (a / "README.md").write_text("seed\n")
        doc = {"about": av.ABOUT, "format": av.FORMAT, "vaults": [
            {"name": "game-a", "group": "game", "pack": "A", "licence": "a", "needed_by_build": True,
             "match": ["assets/images/a_*"]},
            {"name": "game-b", "group": "game", "pack": "B", "licence": "b", "needed_by_build": True,
             "match": ["assets/images/b_*"]}]}
        (a / "tool/asset_vault.json").write_text(av.dump(doc))
        self.art = {"assets/images/a_one.png": os.urandom(900), "assets/images/a_two.png": os.urandom(700),
                    "assets/images/b_one.png": os.urandom(800)}
        self.write(a, self.art)
        self.git(a, "init", "-q")
        self.git(a, "config", "poh.vaultKeyFile", str(self.key))
        self.tool(a, "pack")
        self.git(a, "add", "-A")
        self.git(a, "commit", "-q", "-m", "seed")
        self.git(a, "push", "-q", str(bare), "main")
        return bare

    def clone(self, bare, name, key=True, hooks=True):
        c = self.tmp / name
        self.git(self.tmp, "clone", "-q", str(bare), str(c))
        if key:
            self.git(c, "config", "poh.vaultKeyFile", str(self.key))
        if hooks:
            self.tool(c, "install-hooks")
            self.tool(c, "sync")
        return c

    @staticmethod
    def write(base, files):
        for p, data in files.items():
            (base / p).parent.mkdir(parents=True, exist_ok=True)
            (base / p).write_bytes(data)

    @staticmethod
    def art_of(base):
        d = base / "assets/images"
        return {f"assets/images/{p.name}": p.read_bytes() for p in sorted(d.iterdir())} if d.is_dir() else {}

    def changed(self, c, rev="HEAD"):
        return sorted(self.git(c, "show", "--name-only", "--format=", rev).split())


class Hooks(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory(prefix="test-vault-hooks-")
        self.s = Scratch(self._tmp.name)
        self.bare = self.s.origin()

    def tearDown(self):
        key = self.s.key.read_text().strip()
        for p in Path(self._tmp.name).rglob("*"):
            if p.is_file() and p.suffix in (".synced", ".placeholders"):
                self.assertNotIn(key, p.read_text())
        self._tmp.cleanup()

    def test_a_clone_a_worktree_and_a_mirror_get_the_art(self):
        s = self.s
        a = s.clone(self.bare, "a")
        self.assertEqual(s.art_of(a), s.art)
        self.assertEqual(s.git(a, "status", "--porcelain"), "", "the art is git-ignored")
        out = s.git(a, "worktree", "add", "-q", str(s.tmp / "wt"), "-b", "x")
        self.assertIn("unpacked", out)
        self.assertEqual(s.art_of(s.tmp / "wt"), s.art)
        mirror = s.tmp / "mirror"
        mirror.mkdir()
        tar = subprocess.run(["git", "-C", str(a), "archive", "HEAD"], capture_output=True, check=True,
                             env=s.env).stdout
        subprocess.run(["tar", "-x", "-C", str(mirror)], input=tar, check=True)
        self.assertEqual(s.art_of(mirror), {})
        s.tool(mirror, "unpack", "--only", "game", "--key-file", str(s.key))
        self.assertEqual(s.art_of(mirror), s.art)
        self.assertIn("ok", s.tool(mirror, "check"))
        # No key: nothing unpacked, a note, never a failure.
        n = s.clone(self.bare, "nokey", key=False)
        self.assertEqual(s.art_of(n), {})
        self.assertIn("no key here", s.tool(n, "hook", "post-update"))

    def test_an_edit_repacks_its_vault_alone_and_a_touch_nothing(self):
        s = self.s
        a = s.clone(self.bare, "a")
        parts = {p.name: p.read_bytes() for p in (a / "assets-vault").iterdir()}
        os.utime(a / "assets/images/a_one.png", (1, 1))
        s.tool(a, "commit", "-m", "nothing", ok=False)
        (a / "README.md").write_text("other\n")
        s.git(a, "commit", "-qam", "readme")
        self.assertEqual({p.name: p.read_bytes() for p in (a / "assets-vault").iterdir()}, parts)
        self.assertEqual(s.changed(a), ["README.md"])
        (a / "assets/images/a_one.png").write_bytes(b"new one")
        s.tool(a, "commit", "-q", "-m", "art")
        self.assertEqual(s.changed(a), ["assets-vault/game-a.tar.gz.enc", "tool/asset_vault.json"])
        self.assertEqual((a / "assets-vault/game-b.tar.gz.enc").read_bytes(), parts["game-b.tar.gz.enc"])
        self.assertEqual(s.git(a, "status", "--porcelain"), "")
        s.git(a, "push", "-q")
        # The other clone's pull brings it (post-merge).
        b = s.clone(self.bare, "b")
        self.assertEqual((b / "assets/images/a_one.png").read_bytes(), b"new one")

    def test_a_pull_unpacks_unedited_files_and_keeps_edited_ones(self):
        s = self.s
        a, b = s.clone(self.bare, "a"), s.clone(self.bare, "b")
        (a / "assets/images/a_two.png").write_bytes(b"a's two")
        s.tool(a, "commit", "-q", "-m", "a two")
        s.git(a, "push", "-q")
        out = s.git(b, "pull", "-q")
        self.assertIn("game-a: unpacked", out)
        self.assertEqual((b / "assets/images/a_two.png").read_bytes(), b"a's two")
        # Edits of b's own while the vault moves: kept, and the commit refused until b decides.
        (a / "assets/images/a_one.png").write_bytes(b"a's one")
        s.tool(a, "commit", "-q", "-m", "a one")
        s.git(a, "push", "-q")
        (b / "assets/images/a_two.png").write_bytes(b"b's two")
        out = s.git(b, "pull", "-q")
        self.assertIn("not unpacking over your edits", out)
        self.assertEqual((b / "assets/images/a_two.png").read_bytes(), b"b's two")
        (b / "README.md").write_text("b\n")
        out = s.git(b, "commit", "-qam", "b", ok=False)
        self.assertIn("changed in git since your files were last synced", out)
        s.tool(b, "sync", "--keep-mine")
        s.git(b, "commit", "-qam", "b")
        self.assertIn("assets-vault/game-a.tar.gz.enc", s.changed(b))

    def test_resolve_merges_one_vault_edited_on_both_sides(self):
        s = self.s
        a, b = s.clone(self.bare, "a"), s.clone(self.bare, "b")
        (a / "assets/images/a_one.png").write_bytes(b"a's one")
        s.tool(a, "commit", "-q", "-m", "a one")
        s.git(a, "push", "-q")
        (b / "assets/images/a_two.png").write_bytes(b"b's two")
        (b / "assets/images/a_three.png").write_bytes(b"b's new three")
        s.tool(b, "commit", "-q", "-m", "b two")
        s.git(b, "pull", "-q", "--no-rebase", ok=False)  # the part and the JSON conflict
        s.tool(b, "resolve")
        s.git(b, "commit", "-q", "--no-edit")
        art = s.art_of(b)
        self.assertEqual(art["assets/images/a_one.png"], b"a's one")
        self.assertEqual(art["assets/images/a_two.png"], b"b's two")
        self.assertEqual(art["assets/images/a_three.png"], b"b's new three")
        self.assertIn("ok", s.tool(b, "check"))
        s.git(b, "push", "-q")
        s.git(a, "pull", "-q")
        self.assertEqual(s.art_of(a), art)
        # The same file both ways: a conflict, settled for all such files with --take.
        (a / "assets/images/b_one.png").write_bytes(b"a's b")
        s.tool(a, "commit", "-q", "-m", "a b")
        s.git(a, "push", "-q")
        (b / "assets/images/b_one.png").write_bytes(b"b's b")
        s.tool(b, "commit", "-q", "-m", "b b")
        s.git(b, "pull", "-q", "--no-rebase", ok=False)
        self.assertIn("changed differently on both sides", s.tool(b, "resolve", ok=False))
        self.assertEqual((b / "assets/images/b_one.png").read_bytes(), b"b's b", "nothing written")
        s.tool(b, "resolve", "--take", "theirs")
        s.git(b, "commit", "-q", "--no-edit")
        self.assertEqual((b / "assets/images/b_one.png").read_bytes(), b"a's b")

    def test_placeholders_and_forced_files_never_reach_the_vault(self):
        s = self.s
        a = s.clone(self.bare, "a")
        p = a / "assets/images/a_one.png"
        p.write_bytes(b"a placeholder")
        (a / "assets/.placeholders").write_text(json.dumps({"assets/images/a_one.png": sha(b"a placeholder")}))
        (a / "README.md").write_text("x\n")
        out = s.git(a, "commit", "-qam", "x")
        self.assertIn("never packed", out)
        self.assertEqual(s.changed(a), ["README.md"])
        s.tool(a, "pack", "--only", "game-a", ok=False)
        s.tool(a, "sync")  # the vault's art over its own placeholder; the list goes
        self.assertEqual(p.read_bytes(), s.art["assets/images/a_one.png"])
        self.assertFalse((a / "assets/.placeholders").exists())
        s.git(a, "add", "-f", "assets/images/a_two.png")
        self.assertIn("staged past .gitignore", s.git(a, "commit", "-qm", "forced", ok=False))

    def test_a_file_that_left_its_vault(self):
        s = self.s
        a, b = s.clone(self.bare, "a"), s.clone(self.bare, "b")
        wt = s.tmp / "wt"
        s.git(b, "worktree", "add", "-q", str(wt), "-b", "w", "origin/main")
        (a / "assets/images/a_two.png").unlink()
        s.tool(a, "commit", "-q", "-m", "a_two goes")
        s.git(a, "push", "-q")
        s.git(b, "pull", "-q")
        self.assertTrue((b / "assets/images/a_two.png").is_file(), "the main checkout keeps it (the game may run)")
        self.assertIn("a_two.png: not in vault game-a", s.tool(b, "check", ok=False))
        s.git(wt, "fetch", "-q")
        s.git(wt, "merge", "-q", "origin/main")
        self.assertFalse((wt / "assets/images/a_two.png").exists(), "a linked worktree drops it")
        (b / "README.md").write_text("b\n")
        s.git(b, "commit", "-qam", "b")  # the waiting file is never packed back
        self.assertEqual(s.changed(b), ["README.md"])
        s.tool(b, "prune")
        self.assertFalse((b / "assets/images/a_two.png").exists())
        self.assertIn("ok", s.tool(b, "check"))

    def test_pre_push_keeps_the_public_history_apart(self):
        s = self.s
        a = s.clone(self.bare, "a")
        public = s.tmp / "public.git"
        s.git(s.tmp, "init", "-q", "--bare", str(public))
        s.git(a, "remote", "add", "public", str(public))
        root = s.git(a, "rev-list", "--max-parents=0", "HEAD").strip()
        s.git(a, "config", "poh.publicRoot", root)
        s.git(a, "push", "-q", "public", "main")
        s.git(a, "branch", "develop")
        self.assertIn("only main", s.git(a, "push", "public", "develop", ok=False))
        s.git(a, "checkout", "-q", "--orphan", "old")
        s.git(a, "commit", "-qm", "another history")
        self.assertIn("isn't the public history", s.git(a, "push", "--force", "public", "old:main", ok=False))
        s.git(a, "push", "-q", "origin", "old")  # another history goes to origin
        s.git(a, "checkout", "-q", "main")
        (a / "README.md").write_text("more\n")
        s.git(a, "commit", "-qam", "more")
        self.assertIn("goes to the public repository", s.git(a, "push", "origin", "main", ok=False))
        s.git(a, "push", "-q", "origin", "main", env={"POH_PUSH_PUBLIC_HISTORY": "1"})
        # The privacy check runs on what goes public.
        (a / "notes.md").write_text("the tablet at " + ".".join(["100", "101", "1", "2"]) + "\n")
        s.git(a, "add", "notes.md")
        self.assertIn("an IP address", s.git(a, "commit", "-qm", "ip", ok=False))
        s.git(a, "commit", "-qm", "ip", "--no-verify")
        self.assertIn("privacy check failed", s.git(a, "push", "public", "main", ok=False))
        # And on the commit messages: the commit-msg hook, and again on the way out for the ones not on the remote.
        s.git(a, "reset", "-q", "--hard", "HEAD~1")
        s.git(a, "push", "-q", "public", "main")  # "more": its message is fine
        (a / "README.md").write_text("again\n")
        tablet = "the tablet at " + ".".join(["100", "101", "1", "2"])
        self.assertIn("commit message:1: an IP address", s.git(a, "commit", "-qam", tablet, ok=False))
        s.git(a, "commit", "-qam", tablet, "--no-verify")
        out = s.git(a, "push", "public", "main", ok=False)
        self.assertIn("a commit message", out)
        self.assertEqual(s.git(a, "log", "--format=%s", "-1", "public/main").strip(), "more")
        s.git(a, "commit", "-q", "--amend", "-m", "the tablet's address stays in the private notes")
        s.git(a, "push", "-q", "public", "main")


if __name__ == "__main__":
    unittest.main(verbosity=2)
