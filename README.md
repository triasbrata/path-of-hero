# Path of Hero

A lane battle where your army marches, chases and fights on its own: recruit troops, give them the loot that drops,
and hold the valley against waves of monsters, a boss every fifth wave. Built with Flutter and Flame.

This repository is where the game is developed. Path of Hero is **source-available** under the
[Path of Hero License](LICENSE): you may read the code, build it and use your build yourself, but you may not give
the code or a build to anyone else, nor sell it. The official builds are on itch.io, free or pay what you want:
<https://triasbrata.itch.io/path-of-hero>.

## The art is encrypted here

The characters, the effects, the user interface and the backdrops of the official builds come from third-party asset
packs, licensed to the game's author only ([CREDITS.md](CREDITS.md) lists each pack with its author and link). Their
licences forbid sharing them, so the files themselves are git-ignored: the repository holds them only encrypted, in
`assets-vault/` (AES-256), which only the team's key opens. Nobody else can rebuild the art from this repository.

Without the key, `tool/gen_placeholders.py` draws a placeholder for every licensed image, at its exact path and size,
from `tool/asset_manifest.json` (what the code needs to know about each file: its size, its frames, where a
character's feet are): coloured figures, rings of light and parchment panels, and placeholder app icons. A build from
this repository plays the same game with that placeholder art.

What is here as plain files: the code, the tests and the tools; the music, the sound effects and the loot icons'
drawings, made for the game; and the game's font, Poh Sans, Pixelify Sans with 13 glyphs redrawn, under the SIL Open
Font License 1.1 (`assets/fonts/OFL-PohSans.txt`; `python3 tool/make_poh_sans.py` writes it from Pixelify Sans, in
`tool/fonts/` with its licence).

## Build it

You need Flutter 3.47 (stable; Dart 3.13), Python 3 (the standard library is enough) and your platform's build tools:
Xcode for macOS, Visual Studio with "Desktop development with C++" for Windows, the GTK 3 development packages,
clang, CMake and Ninja for Linux, or the Android SDK for Android.

```sh
python3 tool/gen_placeholders.py   # the placeholder art and icons (git-ignored)
flutter pub get
flutter run -d macos               # or windows, linux, or an Android device's id
```

With the team's key (members only): `python3 tool/asset_vault.py unpack --only game` puts the real art in place, and
`python3 tool/asset_vault.py install-hooks` keeps it in step with the vault on every commit, checkout and merge
([docs/assets.md](docs/assets.md), "The asset vault").

The first build of each platform downloads the sound library's prebuilt Ogg/Vorbis/Opus/FLAC binaries, the release
pinned in `pubspec.yaml` (flutter_soloud's `prebuild_tag`), so it needs the network.

Check your changes the way the project does:

```sh
flutter analyze
flutter test -x art
```

The tests tagged `art` compare the files under `assets/` with the real art's hashes (`tool/assets.sha256`), so they
pass only with the real art. Everything else runs on the placeholders.

## How the game works

[docs/README.md](docs/README.md) indexes the documents: the rules of a round, the troops and monsters, the loot, how
the army lines up and moves, the camera, the HUD, the tests, how a change gets in ([docs/process.md](docs/process.md))
and why things are the way they are ([docs/decisions-log.md](docs/decisions-log.md)). Each has one purpose, stated in
its first line. [CHANGELOG.md](CHANGELOG.md) lists what each version brought.

## Licence and name

- The code: the [Path of Hero License](LICENSE), source-available. Build it for yourself, never share or sell a build.
- The name Path of Hero, its icon and its logo are reserved (LICENSE §5): a build of yours may not use them, except to
  say truthfully where it comes from.
- The art packs: their authors' terms ([CREDITS.md](CREDITS.md)). They are here only encrypted, and the licence
  grants nothing in them.
- The music, the sound effects and the loot icons: all rights reserved, usable only as part of the game in builds you
  make for yourself (LICENSE §6c).
- The font: SIL Open Font License 1.1. The packages and native libraries the game is built with:
  [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt).

## Contributing

Pull requests are welcome under the licence's contribution terms: read [CONTRIBUTING.md](CONTRIBUTING.md) first.
