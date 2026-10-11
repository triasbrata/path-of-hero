# How a change gets in

Purpose: the development process in one page: the branches, what a change carries, the checks before main, the
decisions log, the art's vault and its hooks, and what never goes into this public repository.

## Branches

- **main** is clean: only what passed the checks below. It is the one branch pushed to the public repository
  (github.com/triasbrata/path-of-hero), with the release tags `v<version>`.
- **develop** is main plus work in flight, merged before its tests so the owner sees it in the game at once. It is never
  pushed, and never merged into a work branch (it carries other people's unchecked work).
- **Work branches** start from main and take only main into them. A finished branch merges the latest main first; main
  then fast-forwards to it.
- The tower-defense repository is the private archive this one started from (its old history, the issues), and its
  `private` branch holds the maintainers' private notes (below).

## What a change carries

- The code, its tests, the documents in `docs/` that describe the behaviour it changes (in the same commit), and an
  entry in [decisions-log.md](decisions-log.md): the number it was given, in numeric order, with the owner's request
  quoted and why things are the way they are.
- Player-facing text in simple English; the mechanics' names come from `lib/words.dart` (ui-hud.md "In-game text").
- Visuals from the game's existing sprite sheets (`assets/`), mapped before use, never shapes drawn in code where a
  sheet fits.

## Checks before main

- `flutter analyze lib test` (the known infos only) and the test files the change touches: the files it adds or changes
  and those that cover the code it changes. The whole suite runs on main after each merge; a failure traced to a merge
  goes back to its branch.
- CI (`.github/workflows/ci.yml`) runs the privacy check, the tools' tests, analyze and a fast set on every pull
  request, and the whole suite on every push to main.
- Balance is measured after the merge, by replaying saved waves, never on the way to main.

## The decisions log merges entry by entry

`.gitattributes` has `docs/decisions-log.md merge=decisions`; `scripts/merge-decisions.py` is that driver: it splits
base, ours and theirs into entries by number, takes the side that changed an entry, merges an entry both changed on
its own, and writes them in numeric order. A real collision (one new number on both sides) falls back to conflict
markers. Once per clone: `git config merge.decisions.driver "python3 scripts/merge-decisions.py %O %A %B %L"` and
`git config merge.decisions.name "decisions log, entry by entry"` (`--selftest` checks it).

## The art: the vault and its hooks

The licensed art is git-ignored; git holds it encrypted, one vault per pack, in `assets-vault/` (assets.md "The asset
vault"). With the key, once per clone: `python3 tool/asset_vault.py install-hooks`. Then:

- a commit re-packs the vault whose art you changed (`python3 tool/asset_vault.py commit -m ...` when only art changed),
  and refuses when that vault changed in git since your art was last synced;
- a checkout, a merge or `git worktree add` unpacks every vault whose art you didn't edit;
- a `git archive` copy of a commit has no art: `python3 tool/asset_vault.py unpack --only game` in it;
- two branches that changed the same vault: after the stopped `git merge`, `python3 tool/asset_vault.py resolve`.
  Without the key: `python3 tool/gen_placeholders.py`, and `flutter test -x art`.

## What never goes in

This repository is public. No home folders, IP addresses, e-mail addresses, tokens, key or password files (nor their
names), a device's ids, nor the agents' own folders and prompts, in a file or in a commit message (it is as public):
`python3 tool/privacy_check.py` refuses them, in the pre-commit and commit-msg hooks, before a push to the public
repository and in CI. The maintainers' private notes (the machine, the
signing keys' places, the store page, the agents' setup) are in the private notes, checked out as `private/`
(git-ignored) where needed; a doc here may point at them ("the private notes"), never copy them.
