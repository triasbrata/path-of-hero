#!/usr/bin/env python3
"""Nothing private in what git tracks (docs/dev-workflow.md "What stays private"): the repository is public.

    python3 tool/privacy_check.py                 # every tracked file, as it is in the working tree
    python3 tool/privacy_check.py --staged        # what the next commit takes (the pre-commit hook)
    python3 tool/privacy_check.py --rev REV       # every file of a commit (the pre-push hook, CI)
    python3 tool/privacy_check.py --dir DIR       # every file under a folder (no git)
    python3 tool/privacy_check.py --message FILE  # a commit message (the commit-msg hook; git's # lines skipped)
    python3 tool/privacy_check.py --messages REV.. # the messages of `git rev-list REV..` (the pre-push hook)

It refuses, naming each file and line (a match is shown by its first 4 characters only):
- a private-notes marker left in a doc (the private notes live outside this repository);
- an IPv4 address other than loopback, 0.0.0.0 and the documentation ranges (192.0.2.x, 198.51.100.x, 203.0.113.x);
- an e-mail address other than a GitHub noreply or example.com/.org/.net one (licence texts and notices are exempt);
- an absolute home folder with a real user name (macOS's, Linux's or Windows's users' folder followed by a name; the
  made-up names p, user, runner, me and you are fine);
- a token's shape: GitHub, AWS, Anthropic, OpenAI, Google, Slack, Stripe, a PEM private key, a JWT;
- a key file by name: *.jks, *.keystore, *.p12, *.pem, *.key, key.properties, .env, .envrc, service-account JSON;
- the private terms (machine names, the agents' folders, key and password file names, a device's ids): one per line,
  matched without case, read from the file POH_PRIVACY_TERMS names, else from the private notes' branch
  (`git config poh.privateRef`, default refs/heads/private: its privacy-terms.txt). The list itself is never in this
  repository, so CI checks only the shapes above.
Commit messages are as public as the files, so the same rules hold for them.
A line holding `privacy-check: allow` is skipped (for a deliberate example). Binary files are skipped. Stdlib only.
"""
import ipaddress
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ALLOW = "privacy-check: " + "allow"
MARKERS = ["<!-- " + "private", "private" + ":begin", "private" + ":end", "<!-- " + "public"]
IPV4 = re.compile(r"(?<![\w.])(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(?![\w.]*\d)")
EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}")
EMAIL_OK = re.compile(r"(@users\.noreply\.github\.com|@example\.(com|org|net)|^noreply@[a-z.]+)$", re.I)
EMAIL_EXEMPT = re.compile(r"(^|/)(THIRD_PARTY_NOTICES\.txt|LICENSE[^/]*|OFL[^/]*\.txt|licences\.dart)$")
# The users' folders, written in pieces so this file holds none of them whole.
HOME = re.compile("(" + "/" + "Users/|/" + "home/|[A-Za-z]:" + r"\\\\?" + "Us" + r"ers\\\\?)([A-Za-z0-9._-]+)")
HOME_OK = {"p", "user", "runner", "me", "you", "name", "shared"}
TOKENS = [
    ("a GitHub token", r"\b(gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})"),
    ("an AWS key id", r"\bAKIA[0-9A-Z]{16}\b"),
    ("an Anthropic key", r"\bsk-ant-[A-Za-z0-9_-]{20,}"),
    ("an OpenAI key", r"\bsk-(proj-)?[A-Za-z0-9]{32,}"),
    ("a Google API key", r"\bAIza[0-9A-Za-z_-]{35}"),
    ("a Slack token", r"\bxox[abprs]-[A-Za-z0-9-]{10,}"),
    ("a Stripe key", r"\b[sr]k_live_[A-Za-z0-9]{16,}"),
    ("a PEM private key", r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    ("a JWT", r"\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"),
]
KEY_FILES = re.compile(r"(^|/)([^/]+\.(jks|keystore|p12|pem|key)|key\.properties|\.env|\.envrc|"
                       r"[^/]*service[-_]?account[^/]*\.json)$", re.I)


def git(*args, data=None):
    kw = {"input": data} if data is not None else {"stdin": subprocess.DEVNULL}
    r = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, **kw)
    if r.returncode:
        sys.exit(f"privacy_check: git {' '.join(args)}: {r.stderr.decode(errors='replace').strip()}")
    return r.stdout


def private_terms():
    path = os.environ.get("POH_PRIVACY_TERMS")
    if path:
        text = Path(path).expanduser().read_text()
    else:
        ref = "refs/heads/private"
        r = subprocess.run(["git", "config", "--get", "poh.privateRef"], cwd=ROOT, capture_output=True, text=True,
                           stdin=subprocess.DEVNULL)
        if r.returncode == 0 and r.stdout.strip():
            ref = r.stdout.strip()
        r = subprocess.run(["git", "show", f"{ref}:privacy-terms.txt"], cwd=ROOT, capture_output=True,
                           stdin=subprocess.DEVNULL)
        if r.returncode:
            return []
        text = r.stdout.decode()
    return [t.strip().lower() for t in text.splitlines() if t.strip() and not t.lstrip().startswith("#")]


def show(m):
    return (m[:4] + "…") if len(m) > 4 else m


def ip_problem(m):
    try:
        ip = ipaddress.IPv4Address(".".join(m.groups()))
    except ValueError:
        return None
    if ip.is_loopback or ip.is_unspecified or any(ip in ipaddress.ip_network(n) for n in (
            "192.0.2.0/24", "198.51.100.0/24", "203.0.113.0/24")):
        return None
    return "an IP address"


def check_text(path, text, terms):
    out = []
    for n, line in enumerate(text.splitlines(), 1):
        if ALLOW in line:
            continue
        low = line.lower()
        for mk in MARKERS:
            if mk in line:
                out.append((path, n, "a private-notes marker", mk))
        for m in IPV4.finditer(line):
            why = ip_problem(m)
            if why:
                out.append((path, n, why, m.group(0)))
        if not EMAIL_EXEMPT.search(path):
            for m in EMAIL.finditer(line):
                if not EMAIL_OK.search(m.group(0)):
                    out.append((path, n, "an e-mail address", m.group(0)))
        for m in HOME.finditer(line):
            if m.group(2).lower() not in HOME_OK and not m.group(2).startswith(("<", "$", "{")):
                out.append((path, n, "a home folder", m.group(0)))
        for what, rx in TOKENS:
            for m in re.finditer(rx, line):
                out.append((path, n, what, m.group(0)))
        for t in terms:
            if t in low:
                out.append((path, n, "a private term", t))
    return out


def files_tracked():
    names = [p for p in git("ls-files", "-z").decode().split("\0") if p]
    return [(p, lambda p=p: (ROOT / p).read_bytes() if (ROOT / p).is_file() else None) for p in names]


def files_staged():
    names = [p for p in git("diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z").decode().split("\0") if p]
    return [(p, lambda p=p: git("show", f":{p}")) for p in names]


def files_rev(rev):
    out = []
    for entry in git("ls-tree", "-r", "-z", rev).decode().split("\0"):
        if not entry:
            continue
        meta, path = entry.split("\t", 1)
        mode, kind, obj = meta.split()
        if kind == "blob" and mode != "160000":
            out.append((path, lambda obj=obj: git("cat-file", "blob", obj)))
    return out


def files_dir(base):
    base = Path(base).resolve()
    out = []
    for dirpath, dirs, names in os.walk(base):
        dirs[:] = sorted(d for d in dirs if d not in (".git", ".dart_tool", "build"))
        for n in sorted(names):
            p = Path(dirpath) / n
            if p.is_file() and not p.is_symlink():
                out.append((p.relative_to(base).as_posix(), lambda p=p: p.read_bytes()))
    return out


def message_text(text):
    # What git keeps of a message being written: no comment lines, nothing below the scissors line.
    out = []
    for line in text.splitlines():
        if line.startswith("# ------------------------ >8 ------------------------"):
            break
        if not line.startswith("#"):
            out.append(line)
    return "\n".join(out).encode()


def files_message(path):
    return [("commit message", lambda: message_text(Path(path).read_text(errors="replace")))]


def files_messages(revs):
    shas = git("rev-list", *revs).decode().split()
    return [(f"commit {sha[:12]}", lambda sha=sha: git("log", "-1", "--format=%B", sha)) for sha in shas]


def run(files, terms):
    problems = []
    for path, read in files:
        if KEY_FILES.search(path):
            problems.append((path, 0, "a key file", Path(path).name))
            continue
        data = read()
        if data is None or b"\0" in data[:8192]:
            continue
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            continue
        problems += check_text(path, text, terms)
        problems += [(path, 0, "a private term in its path", t) for t in terms if t in path.lower()]
    return problems


def main(argv):
    if argv[:1] == ["--staged"]:
        files = files_staged()
    elif argv[:1] == ["--rev"] and len(argv) == 2:
        files = files_rev(argv[1])
    elif argv[:1] == ["--dir"] and len(argv) == 2:
        files = files_dir(argv[1])
    elif argv[:1] == ["--message"] and len(argv) == 2:
        files = files_message(argv[1])
    elif argv[:1] == ["--messages"] and len(argv) > 1:
        files = files_messages(argv[1:])
    elif not argv:
        files = files_tracked()
    else:
        sys.exit(__doc__)
    terms = private_terms()
    problems = run(files, terms)
    for path, n, what, m in problems:
        print(f"{path}:{n}: {what} ({show(m)})")
    if problems:
        print(f"privacy check: {len(problems)} problem(s) in {len(files)} file(s). Reword the line (a private note "
              f"goes to the private notes), or mark a deliberate example with `{ALLOW}`", file=sys.stderr)
        return 1
    print(f"privacy check: ok ({len(files)} files, {len(terms)} private terms)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
