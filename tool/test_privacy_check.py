"""Tests tool/privacy_check.py (docs/dev-workflow.md "What stays private") on scratch git repos: each kind of private
content planted fails it, naming the file and line; the made-up and allowed shapes pass; --staged, --rev and --dir
read what they say, and so do --message and --messages (commit messages are public too); the private terms come from
POH_PRIVACY_TERMS or the private notes' branch, never this repo.
Stdlib and git:  python3 tool/test_privacy_check.py
"""
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent

# Built from pieces, so this file itself never holds what it plants.
MARK = "<!-- " + "private -->"
PLANTS = {
    "an IP address": "the tablet is at 100.101." + "7.9 over the VPN",
    "a private-notes marker": MARK,
    "an e-mail address": "write to someone" + "@" + "gmail.com",
    "a home folder": "out = '/" + "Users/alice/.cache/x'",
    "a GitHub token": "token ghp_" + "A" * 36,
    "a PEM private key": "-----BEGIN RSA PRIVATE" + " KEY-----",
    "a private term": "the probes write to our-secret-" + "folder/shots",
}
FINE = [
    "listen on 127.0.0.1:8080 or 0.0.0.0, the docs' 192.0.2.10",
    "Flutter 3.47.5 and version 1.2.3-beta",
    "Trias <123+trias@users.noreply.github.com>, test@example.com",
    "save_test: {'HOME': '/" + "Users/p'} and /" + "home/runner/work",
    "a sha256 9ba86cd010a4de309d263ceff8e8044092c9db7efda869620cb9ff1c4389e8a5",
    "an example " + ".".join(["10", "1", "2", "3"]) + " on purpose  privacy-check: " + "allow",
]


class PrivacyCheck(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory(prefix="test-privacy-")
        self.tmp = Path(self._tmp.name)
        self.repo = self.tmp / "repo"
        (self.repo / "tool").mkdir(parents=True)
        shutil.copy(HERE / "privacy_check.py", self.repo / "tool/privacy_check.py")
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(("POH_", "GIT_"))}
        self.env.update(HOME=str(self.tmp), GIT_CONFIG_NOSYSTEM="1", GIT_AUTHOR_NAME="T", GIT_AUTHOR_EMAIL="t@example.com",
                        GIT_COMMITTER_NAME="T", GIT_COMMITTER_EMAIL="t@example.com")
        self.terms = self.tmp / "terms.txt"
        self.terms.write_text("# one per line\nour-secret-folder\n")
        self.git("init", "-q", "-b", "main")
        (self.repo / "fine.md").write_text("\n".join(FINE) + "\n")
        self.git("add", "-A")
        self.git("commit", "-qm", "fine")

    def tearDown(self):
        self._tmp.cleanup()

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.repo, check=True, capture_output=True, text=True,
                              env=self.env, stdin=subprocess.DEVNULL).stdout

    def check(self, *args, terms=True):
        env = dict(self.env)
        if terms:
            env["POH_PRIVACY_TERMS"] = str(self.terms)
        r = subprocess.run([sys.executable, "-B", "tool/privacy_check.py", *args], cwd=self.repo, capture_output=True,
                           text=True, env=env, stdin=subprocess.DEVNULL)
        return r.returncode, r.stdout + r.stderr

    def test_the_fine_shapes_pass(self):
        code, out = self.check()
        self.assertEqual(code, 0, out)
        self.assertIn("1 private terms", out)

    def test_each_plant_fails_with_its_file_and_line(self):
        for what, line in PLANTS.items():
            (self.repo / "doc.md").write_text("first line\n" + line + "\n")
            self.git("add", "doc.md")
            code, out = self.check("--staged")
            self.assertEqual(code, 1, what)
            self.assertIn(f"doc.md:2: {what}", out, what)
            self.assertNotIn(line, out, "the match is shown by its first characters only")
        self.git("rm", "-q", "--cached", "doc.md")

    def test_key_files_by_name(self):
        for name in ("release.jks", "android/key.properties", ".envrc", "ci-service-account.json"):
            p = self.repo / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text("x\n")
            self.git("add", "-f", name)
            code, out = self.check("--staged")
            self.assertEqual(code, 1, name)
            self.assertIn(f"{name}:0: a key file", out)
            self.git("rm", "-q", "--cached", name)

    def test_rev_and_dir_and_the_terms_branch(self):
        (self.repo / "doc.md").write_text(PLANTS["a private term"] + "\n")
        self.git("add", "doc.md")
        self.git("commit", "-qm", "term")
        rev = self.git("rev-parse", "HEAD").strip()
        self.assertEqual(self.check("--rev", rev, terms=False)[0], 0, "no list here: CI checks the shapes alone")
        self.assertEqual(self.check("--rev", rev)[0], 1)
        self.assertEqual(self.check("--rev", "HEAD~1")[0], 0)
        self.assertEqual(self.check("--dir", str(self.repo))[0], 1)
        # The list from the private notes' branch, as a clone with it has it.
        self.git("checkout", "-q", "--orphan", "private")
        self.git("rm", "-rqf", ".")
        shutil.copy(self.terms, self.repo / "privacy-terms.txt")
        self.git("add", "privacy-terms.txt")
        self.git("commit", "-qm", "terms")
        self.git("checkout", "-q", "main")
        code, out = self.check(terms=False)
        self.assertEqual(code, 1, out)
        self.assertIn("doc.md:1: a private term", out)

    def test_commit_messages(self):
        msg = self.tmp / "COMMIT_EDITMSG"
        ip = PLANTS["an IP address"]
        msg.write_text("a fine subject\n\n# " + ip + "\n# ------------------------ >8 ------------------------\n" + ip +
                       "\n")
        code, out = self.check("--message", str(msg))
        self.assertEqual(code, 0, "git's comment lines and what is below the scissors line are dropped: " + out)
        msg.write_text("a subject\n\n" + ip + "\n")
        code, out = self.check("--message", str(msg))
        self.assertEqual(code, 1, out)
        self.assertIn("commit message:3: an IP address", out)
        # The messages of a range of commits (what the pre-push hook checks).
        first = self.git("rev-parse", "HEAD").strip()
        self.git("commit", "-q", "--allow-empty", "-m", "fine too")
        self.assertEqual(self.check("--messages", f"{first}..HEAD")[0], 0)
        self.git("commit", "-q", "--allow-empty", "-m", "about " + PLANTS["a private term"])
        code, out = self.check("--messages", f"{first}..HEAD")
        self.assertEqual(code, 1, out)
        self.assertIn(": a private term", out)
        self.assertEqual(self.check("--messages", f"{first}..HEAD~1")[0], 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
