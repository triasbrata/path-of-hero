# Credits

Path of Hero is made by Trias BYM. Its code is under the Path of Hero License (LICENSE). The art below is not: each
pack stays under its author's terms, is licensed to Trias BYM only, and is not in the public repository. To build
the game with the real art, get the packs from their authors (links below) on their terms. In the game, "Lisensi"
on the book's Pengaturan page shows these credits too.

## Art: third-party packs

| The game uses it for | Pack | Author | Terms (summary; the pack's own licence decides) |
|---|---|---|---|
| Every troop and monster, the arrows, the small effects (`tiny_*`) | [Tiny RPG Character Asset Pack 01 v2.0](https://zerie.itch.io/tiny-rpg-character-asset-pack) ("Full 22 Characters") | Zerie | Paid. Personal and commercial games, may be modified. No redistributing, reselling or re-uploading the assets, no AI training, no NFTs. Credit appreciated. |
| The book, buttons, bars, icons, the spawn bar's hotbar and the loading dial. Its font (CuteFantasy 5×9) is no longer used: the game's font is Poh Sans (below) | [Cute Fantasy UI](https://kenmi-art.itch.io/cute-fantasy-ui) | Kenmi | Paid. Commercial and non-commercial projects, may be modified. No redistributing or reselling, even modified. |
| The loot icons: the items, the relics and the Artifacts (`item_*`, `relic_*`, `artifact_icons.png`) | [Cute Fantasy Icons Premium](https://kenmi-art.itch.io/cute-fantasy-icons) | Kenmi | Paid. Commercial and non-commercial projects, may be modified. No redistributing or reselling, even modified. |
| 9 hit effects and the upgrade burst (`fx_hit_*`, `fx_upgrade`) | [Super Pixel Effects Gigapack (Free Version) v2.9.0](https://untiedgames.itch.io/super-pixel-effects-gigapack) | unTied Games | Commercial and non-commercial use. Attribution required (this credit), no reselling the asset itself. |
| 13 hit effects (`fx_hit_*`) | [Effect and FX Pixel All Free](https://bdragon1727.itch.io/750-effect-and-fx-pixel-all) | BDragon1727 | Free for non-commercial games; a commercial game (a price or donations) contributes to the author first, any amount. No resale or redistribution. |
| The battle's backdrop: the sky, mountains and pines above the field (`town_bg_*`), the clouds (`battle_clouds`), the trunks, trees, boulders, bushes and ferns along the horizon (`battle_props`) and its floor, the grass, the flowers along its top, rocks and the grass-topped earth along its front (`battle_floor`); the spawn bar's step, its rock slopes and earth (`battle_step`). The Town: its sky, mountains, castle and pines, the street, the Smithy, the Tavern and the Shop (rebuilt from the pack's house tiles), the Smithy's furnace and sawmill, the troops' tent, the campfire and the props (`town_bg_*`, `town_castle`, `town_ground`, `town_house`, `town_smithy`, `town_campfire`, `town_tent`, `town_ore`, `town_pine`, `town_props`) | GandalfHardcore FREE Platformer Assets (<https://gandalfhardcore.itch.io/>) | GandalfHardcore | Free. Commercial and non-commercial games and projects, may be modified. No reselling, repackaging or redistributing the assets, no AI training or NFT projects, not in game-making tools or printed materials. No credit asked. |
| The Town's smith hammering in the Smithy (`town_smith`) | [Mana Seed Character Base demo](https://seliel-the-shaper.itch.io/character-base) | Seliel the Shaper | Free demo: "You may use this demo asset commercially or non-commercially." No other terms stated; its files are not shared. |
| The smith's anvil (in `town_smith`) | [Pixel Crawler - Free Pack](https://www.patreon.com/Anokolisa/) | Anokolisa | Free. Commercial products, may be altered in any way; never sold as the art itself, even altered. Credit not required. |

## The font

Every text in the game is drawn in **Poh Sans**, a Modified Version of **Pixelify Sans** by Stefie Justprince
(<https://github.com/eifetx/Pixelify-Sans>), the Google Font the itch page's headers use
(<https://fonts.google.com/specimen/Pixelify+Sans>). Pixelify Sans is under the SIL Open Font License 1.1, which lets it
and a modified copy ship in the game and sit in a public repository, under the same licence and, for the copy, under
a name of its own (Pixelify Sans declares no Reserved Font Name). Pixelify Sans draws its pixels so close that, at the
game's text sizes, its 5 read as an S, its C and c as an O and o, its B and G as an 8 and each other, its i as an l and
its a, 6, 9 and Z close to another glyph. Poh Sans redraws those ten on the font's own pixel grid and keeps everything
else: every other glyph, the kerning, the metrics. Its licence, `assets/fonts/OFL-PohSans.txt`, says what was changed
and from what, then the OFL with Pixelify Sans's copyright and a line for the change; it is bundled in every build,
also in THIRD_PARTY_NOTICES.txt and on the Lisensi page.

| File | From | sha256 |
|---|---|---|
| `assets/fonts/PohSans.ttf` (variable, wght 400-700) | `tool/fonts/PixelifySans.ttf` with its 2, 3, 5, 6, 9, B, C, G, S, Z, a, c and i redrawn and its names changed; `python3 tool/make_poh_sans.py` writes it from that file, byte for byte | `f011cc3f1a78b0f912b3301dcde9360b60677b4ad8c19ce9a8b5886b6a08ed30` |
| `assets/fonts/OFL-PohSans.txt` | what was changed and from what, then the OFL text below with a copyright line for the change | `6131edb98966229c2ffc74ea0345cc8f76d882d019a9fc4541e082863918ae24` |
| `tool/fonts/PixelifySans.ttf` (the source, unmodified; not in the game) | `ofl/pixelifysans/PixelifySans[wght].ttf` in [google/fonts](https://github.com/google/fonts/tree/9710da1eacb3be272583c3224dcb70f9da6eadbb/ofl/pixelifysans) at commit `9710da1e` (2026-09-30), built from the upstream at `39df74ab` | `9ba86cd010a4de309d263ceff8e8044092c9db7efda869620cb9ff1c4389e8a5` |
| `tool/fonts/OFL-PixelifySans.txt` | `ofl/pixelifysans/OFL.txt`, the same commit | `b66ba46f511a851ab09998b5a5a9fdbb102545a3864cb993095e1745996873a7` |

## Made for the game

All rights reserved by Trias BYM (LICENSE §6c):

- the music and the sound effects, synthesised by `tool/gen_music.py` and `tool/gen_sfx.py`;
- the loot icons the public repository draws in place of the pack's (`tool/draw_icons.py`): the game showed them
  until it took Kenmi's Cute Fantasy Icons Premium;
- the app icon's background (the sunrise, its rays and rim), drawn by `tool/make_app_icon.py`. The figure on it is
  Zerie's knight (Tiny RPG Character Asset Pack) with Kenmi's crown (Cute Fantasy UI), so the icon as a whole is
  also under those two packs' terms.

## Software

| What | Author | Licence |
|---|---|---|
| [Flutter](https://flutter.dev) | The Flutter Authors (Google) | BSD-3-Clause |
| [Flame](https://flame-engine.org) | Blue Fire | MIT |
| [flutter_soloud](https://pub.dev/packages/flutter_soloud) | The flutter_soloud Authors | MIT |
| [SoLoud](https://solhsa.com/soloud/) | Jari Komppa | zlib/libpng |
| miniaudio and dr_libs | David Reid | Public domain or MIT No Attribution |
| libogg, libvorbis, libopus, libFLAC: the binaries of [alnitak/flutter_soloud_prebuilds](https://github.com/alnitak/flutter_soloud_prebuilds) release v1.0.2, which pubspec.yaml pins | Xiph.Org Foundation and contributors | BSD-3-Clause |

Every package's licence text is in THIRD_PARTY_NOTICES.txt, and in the game on the Lisensi page.
