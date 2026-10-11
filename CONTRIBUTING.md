# Contributing to Path of Hero

Thank you for wanting to help. Read this before you open a pull request: Path of Hero is source-available, not under
a licence that lets anyone share it, so a contribution comes with a grant.

## The grant (LICENSE §3)

You may change the source code to propose a contribution, for example as a pull request. In the licence's words:

> By submitting a contribution you confirm that you have the right to submit it, and you grant the Licensor a
> perpetual, worldwide, irrevocable, royalty-free licence to use, copy, change, sublicense and distribute it under
> any terms, including in official builds that are sold.

The Licensor is Trias BYM, the game's author. In practice:

- Send only work you made yourself, or work whose licence lets you grant the above. If your employer or a client owns
  what you write, ask them first.
- Your contribution may ship in the official builds on itch.io, including builds sold or offered for a donation, and
  it stays under the Path of Hero License in this repository.
- Opening a pull request is the act of submitting: nothing else to sign.

## What to send

- **Code and tests.** Keep `flutter analyze` clean and `flutter test -x art` green on the placeholder art (README.md,
  "Build it"). A change in behaviour comes with its test, and updates the document in `docs/` that describes it.
- **No art from the packs, ever.** The characters, effects, UI and backdrops are licensed to the author only and are
  not in this repository ([CREDITS.md](CREDITS.md)). Don't add their files, nor anything traced, recoloured, cropped
  or resized from them, nor from any other pack or game. New art has to be your own drawing, made from scratch, and it
  comes under the grant like code.
- **No generated placeholders, no plain art.** `tool/gen_placeholders.py` writes them into `assets/`, and `.gitignore`
  keeps them and the real art out of git; never force-add them (the pre-commit hook and CI refuse it).
- **Nothing private**: no home folders, IP addresses, e-mail addresses, tokens or key files, in a file or a commit
  message (`python3 tool/privacy_check.py`, run by CI).
- **The game's text is English**, as the players see it (lib/words.dart for the mechanics' names). Code, comments and
  the docs are in English.

## Before you start

[docs/README.md](docs/README.md) indexes how the game works, one purpose per document; [docs/architecture.md](docs/architecture.md)
shows where each system lives (the game logic in pure Dart, the drawing in Flame) and [docs/testing.md](docs/testing.md)
how the tests are written. For a bigger change, open an issue first, so we can agree on the direction before you
spend the time.

## What the licence doesn't allow

A fork on GitHub stays under the Path of Hero License: you may build it and use your build yourself, but you may not
publish builds of it, nor use the name Path of Hero or its icon for them (LICENSE §4 and §5).
