#!/usr/bin/env python3
"""Git merge driver for docs/decisions-log.md: merges the log entry by entry, keyed by the entry's number.

Why (decisions-log 129): the log is in almost every real merge conflict, since each branch appends its entry at the
same place. `merge=union` was tried on the 149 past conflicting merges and silently moved lines between entries (3),
left entries out of numeric order (46) and would have landed a number taken twice without a conflict (123).

How: the base, ours and theirs are split into a header (the text before entry 1) and entries (a line starting
"<n>. **" up to the next one). Each entry, and the header, takes the side that changed it. An entry both sides changed
the same way is taken once; one both changed differently is merged 3-way on its own text (`git merge-file`). The
entries are written in numeric order. A real collision falls back to git's own 3-way merge of the whole file, with
conflict markers, and exits 1: two new entries with one number, an entry both sides changed on the same lines, an
entry deleted on one side and changed on the other, a number twice in one version.

Install (once per clone: .git/config is shared by every worktree), with `docs/decisions-log.md merge=decisions` in
.gitattributes:
  git config merge.decisions.name "decisions-log entries by number"
  git config merge.decisions.driver "python3 <repo>/scripts/merge-decisions.py %O %A %B %L"
A clone without that config falls back to git's normal text merge.

By hand: merge-decisions.py <base> <ours> <theirs> [<marker size>] writes the result into <ours>.
--selftest checks built-in cases, then replays past merges of this repo's history (skipped outside a clone).
Python 3.9+, standard library and git only.
"""
import os
import re
import subprocess
import sys
import tempfile

ENTRY = re.compile(r'^(\d+)\. \*\*')


class Collision(Exception):
    pass


def parse(text):
    """(header, {number: entry text}) of a log; an entry's text has no trailing newline."""
    head, entries, cur = [], {}, None
    for line in text.split('\n'):
        m = ENTRY.match(line)
        if m:
            cur = int(m.group(1))
            if cur in entries:
                raise Collision(f'entry {cur} twice in one version')
            entries[cur] = [line]
        elif cur is None:
            head.append(line)
        else:
            entries[cur].append(line)
    return '\n'.join(head), {k: '\n'.join(v).rstrip('\n') for k, v in entries.items()}


def merge_text(base, ours, theirs):
    """3-way merge of one piece of text; None when it conflicts."""
    with tempfile.TemporaryDirectory() as d:
        paths = []
        for name, text in (('ours', ours), ('base', base), ('theirs', theirs)):
            paths.append(os.path.join(d, name))
            with open(paths[-1], 'w') as f:
                f.write(text + '\n')
        r = subprocess.run(['git', 'merge-file', '-p', *paths], capture_output=True, text=True)
        return r.stdout[:-1] if r.returncode == 0 else None


def pick(base, ours, theirs, what):
    if ours == theirs:
        return ours
    if ours == base:
        return theirs
    if theirs == base:
        return ours
    if ours is None or theirs is None:
        raise Collision(f'{what} deleted on one side and changed on the other')
    merged = merge_text(base or '', ours, theirs)
    if merged is None:
        raise Collision(f'{what} changed on the same lines on both sides')
    return merged


def merge(base, ours, theirs):
    """The merged log, or Collision."""
    (hb, eb), (ho, eo), (ht, et) = parse(base), parse(ours), parse(theirs)
    head = pick(hb, ho, ht, 'the header')
    out = {}
    for k in sorted(set(eb) | set(eo) | set(et)):
        text = pick(eb.get(k), eo.get(k), et.get(k), f'entry {k}')
        if text is not None:
            out[k] = text
    return head + '\n' + '\n'.join(out[k] for k in sorted(out)) + '\n'


def read(path):
    with open(path) as f:
        return f.read()


def driver(base_path, ours_path, theirs_path, marker='7'):
    try:
        result = merge(read(base_path), read(ours_path), read(theirs_path))
    except Collision as e:
        sys.stderr.write(f'merge-decisions: {e}; falling back to a plain 3-way merge\n')
        r = subprocess.run(['git', 'merge-file', f'--marker-size={marker}', '-L', 'ours', '-L', 'base', '-L', 'theirs',
                            ours_path, base_path, theirs_path])
        return 1 if r.returncode != 0 else 0
    with open(ours_path, 'w') as f:
        f.write(result)
    return 0


# --- selftest ---------------------------------------------------------------------------------------------------

LOG = '# Decisions log\n\nPurpose: a test.\n\n'


def log(*entries):
    return LOG + ''.join(e if e.endswith('\n') else e + '\n' for e in entries)


def run_driver(base, ours, theirs):
    with tempfile.TemporaryDirectory() as d:
        paths = [os.path.join(d, n) for n in ('base', 'ours', 'theirs')]
        for p, text in zip(paths, (base, ours, theirs)):
            with open(p, 'w') as f:
                f.write(text)
        with open(os.devnull, 'w') as null:
            old, sys.stderr = sys.stderr, null
            try:
                code = driver(*paths)
            finally:
                sys.stderr = old
        return code, read(paths[1])


def check_merge(result, base, ours, theirs):
    """What is wrong with a clean result: every entry from a side, every change kept, numbers ascending."""
    (_, er), (_, eb), (_, eo), (_, et) = parse(result), parse(base), parse(ours), parse(theirs)
    wrong = []
    for k, text in er.items():
        if text not in (eo.get(k), et.get(k)) and not (k in eo and k in et and eo[k] != eb.get(k) != et[k]):
            wrong.append(f'entry {k} is in neither side')
    for side in (eo, et):
        for k, text in side.items():
            if text != eb.get(k) and er.get(k) != text and not (k in eo and k in et and eo[k] != eb.get(k) != et[k]):
                wrong.append(f'entry {k}: a change was lost')
    nums = [int(ENTRY.match(l).group(1)) for l in result.split('\n') if ENTRY.match(l)]
    if nums != sorted(set(nums)):
        wrong.append('numbers not ascending and unique')
    return wrong


def selftest():
    a = '1. **One.**\n   more of one.'
    b = '2. **Two.**\n   more of two.'
    base = log(a, b)
    cases = []

    def case(name, ours, theirs, conflict=False, want=None, base=base):
        code, out = run_driver(base, ours, theirs)
        bad = []
        if conflict:
            if code == 0 or '<<<<<<<' not in out:
                bad.append(f'expected conflict markers, got exit {code}')
        else:
            if code != 0:
                bad.append(f'exit {code}')
            else:
                bad += check_merge(out, base, ours, theirs)
                if want is not None and out != want:
                    bad.append('not the expected file')
        cases.append((name, bad))

    c5 = '5. **Five.**\n   five.'
    c3 = '3. **Three.**\n   three.'
    case('two new entries, ours the higher number: both, in numeric order', log(a, b, c5), log(a, b, c3),
         want=log(a, b, c3, c5))
    case('one side edits the last line of an entry, the other appends one (union moved lines here)',
         log(a, '2. **Two.**\n   more of two, amended.'), log(a, b, c3),
         want=log(a, '2. **Two.**\n   more of two, amended.', c3))
    a3 = '1. **One.**\n   more of one.\n   and the end of one.'
    case('both edit different lines of one entry: merged', log(a3.replace('One.', 'One, renamed.'), b),
         log(a3.replace('the end', 'the very end'), b), want=log(a3.replace('One.', 'One, renamed.').replace(
             'the end', 'the very end'), b), base=log(a3, b))
    case('both make the same change: taken once', log(a, b, c3), log(a, b, c3), want=log(a, b, c3))
    case('a header edit and a new entry', log(a, b).replace('a test', 'a test, edited'), log(a, b, c3),
         want=log(a, b, c3).replace('a test', 'a test, edited'))
    case('the same new number on both sides: conflict', log(a, b, c3), log(a, b, '3. **Another three.**\n   other.'),
         conflict=True)
    case('the same line changed differently: conflict', log('1. **One, A.**\n   more of one.', b),
         log('1. **One, B.**\n   more of one.', b), conflict=True)
    case('deleted on one side, changed on the other: conflict', log(b), log('1. **One, changed.**\n   more of one.', b),
         conflict=True)

    # Past merges of this repo (read-only): the three that `merge=union` corrupted, and a real collision.
    here = os.path.dirname(os.path.abspath(__file__))

    def git(*args):
        r = subprocess.run(['git', '-C', here, *args], capture_output=True, text=True)
        return r.stdout if r.returncode == 0 else None

    # 29a2902 and 1b47a97: union moved an entry's last line into the next branch's new entry; ae50fbd: union did
    # that and kept two entries 106 (a real collision); 0c4a400: two entries 25.
    history = [('29a2902', False), ('1b47a97', False), ('ae50fbd', True), ('0c4a400', True)]
    skipped = []
    for sha, conflict in history:
        parents = (git('rev-list', '--parents', '-1', sha) or '').split()[1:]
        mbase = git('merge-base', *parents) if len(parents) == 2 else None
        texts = [git('show', f'{c}:docs/decisions-log.md') for c in ([mbase.strip()] + parents if mbase else [])]
        if len(texts) != 3 or None in texts:
            skipped.append(sha)
            continue
        hb, ho, ht = texts
        code, out = run_driver(hb, ho, ht)
        bad = []
        if conflict:
            if code == 0 or '<<<<<<<' not in out:
                bad.append(f'expected conflict markers, got exit {code}')
        elif code != 0:
            bad.append(f'exit {code}')
        else:
            bad += check_merge(out, hb, ho, ht)
        cases.append((f'history {sha} ' + ('(a collision: conflict)' if conflict else '(clean)'), bad))

    failed = [c for c in cases if c[1]]
    for name, bad in cases:
        print(('FAIL ' if bad else 'ok   ') + name + (': ' + '; '.join(bad) if bad else ''))
    if skipped:
        print(f'skipped (not in this clone\'s history): {" ".join(skipped)}')
    print(f'{len(cases) - len(failed)}/{len(cases)} passed')
    return 1 if failed else 0


if __name__ == '__main__':
    if sys.argv[1:] == ['--selftest']:
        sys.exit(selftest())
    if len(sys.argv) not in (4, 5):
        sys.exit(__doc__)
    sys.exit(driver(*sys.argv[1:]))
