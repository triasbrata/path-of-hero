# Changelog

What each version brought, newest first. The version is `pubspec.yaml`'s (`<major>.<minor>.<patch>+<build>`); a
release is tagged `v<major>.<minor>.<patch>`. The reasons behind each change are in docs/decisions-log.md.

## 0.1.0+1

The first public version of the source code.

- The game: a lane battle in 8 lanes of road, troops bought on the book's Pasukan page that line up, march, chase,
  kite and heal on their own, waves from the right with a mini boss every third wave and the boss every fifth.
- Loot: items per troop type and their awakening (up to Bangkit 5), relics per troop, the Pusaka bound to a type, the
  boss's chest, the store (Toko), and Heroes: one troop every tenth wave won, with a skill of its own.
- The HUD as a book, landscape and portrait (phones), the minimap, the wave meter, the battle log, the scoreboard
  (local) and the balancing log (local, the player may turn it off).
- Desktop (macOS, Windows, Linux) and Android.
- The art packs are not here: `tool/gen_placeholders.py` draws placeholders from `tool/asset_manifest.json`, and the
  platform icons are placeholders from `tool/make_app_icon.py --placeholder` (README.md).
