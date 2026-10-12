# Assets

Purpose: which asset packs are used, how they are imported, naming, the licence rule, and the public repo's
placeholder art.

## Licence rule

The packs forbid redistribution, so their files are git-ignored here: the repository holds them only encrypted
([The asset vault](#the-asset-vault)), which only the team's key opens, and without the key `tool/gen_placeholders.py`
draws a placeholder in place of each ([Placeholder art](#placeholder-art-the-public-repo)). The game's font, Poh Sans, is
Pixelify Sans with 13 glyphs redrawn, both under the SIL Open Font License 1.1, which allows sharing them with their
licences, so they are here for real (`tool/make_poh_sans.py` writes Poh Sans from Pixelify Sans, in `tool/fonts/`).
Each pack's author, link and terms are in CREDITS.md.

## Licence files

At the repo root (decisions-log 137). The code is source-available: call it that, or "source code on GitHub",
never by the name of an open licence model (itch-page.md "Source code and licence").

| File | What | Change it when |
|---|---|---|
| `LICENSE` | The Path of Hero License (adapted from the owner's Jeansh licence): build it for yourself, no sharing or selling; §6 keeps the packs, the packages, the font (OFL, §6d) and the owner's own art and audio out of it | The owner changes the licence (also README.md's "Licence" and `licenceSummary` in lib/licences.dart) |
| `CREDITS.md` | Every pack with its author, link and terms, the font (its source commit and sha256), what was made for the game, the software | A pack or the font comes or goes (also `credits` in lib/licences.dart; licence_page_test.dart checks they match) |
| `THIRD_PARTY_NOTICES.txt` | Part 1: the Dart packages pubspec.yaml pulls in, with their LICENSE files; part 2: the native libraries inside flutter_soloud (`nativeLicences` in lib/licences.dart), and the release of the Xiph prebuilds pubspec.yaml pins (`prebuild_tag`, itch-page.md "Pinned binaries"); part 3: the font, Poh Sans with `assets/fonts/OFL-PohSans.txt` (`FONTS` in the tool) | A dependency, the pin or the font changes: `python3 tool/third_party_notices.py` (stdlib; reads the pub cache and the Flutter SDK, so `pub get` first). A new native library goes into `nativeLicences` first. A new pin also goes into CREDITS.md's Software row |
| `assets/fonts/OFL-PohSans.txt` | The font's licence: what was changed and from what (the source's sha256), then Pixelify Sans's OFL text (SIL OFL 1.1 with its copyright line, as google/fonts has it) with a copyright line for the redrawn glyphs, CRLF like the source's. pubspec.yaml bundles it, and `registerLicences` reads it into the Licenses page (`fontLicences`) | The font changes |
| `tool/fonts/OFL-PixelifySans.txt` | Pixelify Sans's licence beside the source font, as google/fonts has it; not bundled | The source changes |

In the game, the book's Settings → Licenses shows the licence in short, the credits and every package's licence
(ui-hud.md "Licenses page"): Flutter's NOTICES plus `nativeLicences` and the fonts' licences (`fontLicences`), which
`registerLicences` adds to the LicenseRegistry.

## Layout

| Path | What |
|---|---|
| `raw_assets/<pack>/` | Packs as downloaded and unzipped, what the importers read. Never a bought pack (the owner, decisions-log 157: its store forbids re-sharing it), so `assets/` is the licensed art's source ("Tools on this Mac"). A pack's files are never tracked as they are; encrypted in the asset vault they are (decisions-log 232). |
| `assets-vault/` | The asset vault: the licensed art under `assets/`, the app icons and every pack, encrypted, one `<name>.tar.gz.enc` (or `.partNN`) per vault ([The asset vault](#the-asset-vault)). Tracked. |
| `tool/asset_vault.json` | The vault's one source of truth: every vault's pack, licence, files (path, bytes, sha256, `needed_by_build`) and sha256s; `tool/asset_vault.py` writes and checks it. |
| `raw_sprites/<pack>/` | The owner's art packs unpacked as they came, in the main checkout only: every file ignored but the folder's README.md ([Asset packs](#asset-packs)). Never bundled. |
| `tool/asset_packs/` | What each pack's files are (size, kind, grid, a description, tags, how it fits the game), one JSON per pack and `index.json`; `tool/asset_meta.py` keeps them ([Asset packs](#asset-packs)). |
| `sprites/` | `tool/export_aseprite.py` output: every .aseprite compiled, plus `catalog.json` and `index.html` to browse. Not bundled. |
| `assets/images/` | What the game loads. Flat names; every animation is a strip of square frames (frames = width / height), but the Town scene's sheets, whose grids `lib/town_art.dart` names, and the Town's smith (`town_smith.png`, frames `lib/town_smith_art.dart` names). Everything in it is loaded, the Town scene's files (`townImages`) too, for lib/town_scene.dart (`floors.png`, bundled since the first commit and loaded by nothing, of unknown origin, was removed: decisions-log 136). |
| `assets/ai/retreat.json` | Not art: the troops' fall-back "brain" (`RetreatBrain`, lib/retreat.dart), every threshold of the decision, loaded at start; patch it to retune without a code change (formation-and-navigation.md). Keep it equal to the defaults in code (a test checks). |
| `assets/config/town.json` | Not art: the owner's tuning file for the Towns (`TownRules`, lib/town.dart; loot-items-relics.md "Towns", "Town and Smithy: materials" and "The forge: data"), version 3 (a version-2 file still reads): its `schedule` (the roll's chance, its step and cap, the gap between Towns, the first Town, Auto's wait), the materials' `drops` (and `drops.forge`, the forge's list a rank, decisions-log 246), `parts` and `materials` (with the forge's two stones), `relics` (each small relic's numbers, its `recipe` and the forge's changes to it, `forge`) and `shop` (with the forge's material price, `matMarkup` and `matRise`), and the forge's `items` (every item's recipe and effect), `combos`, `awaken` and `enhance` (decisions-log 245), loaded at start. Keep it equal to the defaults in code (test/town_test.dart and test/town_materials_test.dart check). Our own, public as it is (`OWN` in tool/asset_manifest.py). |

## Packs → files

| Pack | Files | Importer |
|---|---|---|
| Tiny RPG Character packs | `tiny_<key>_{idle,walk,attack,hurt,death}.png`, `tiny_<key>_shadow.png` (drawn fixed on the ground so only the body hops, at `unitShadowAlpha` 0.45 opacity so it blends into the grass; an awakened troop's coloured one keeps `awakenShadowAlpha` 0.65 of its 0.8-1.0 pulse; on the field only: the Town's troops draw none, decisions-log 270), `tiny_<key>_summon.png`, `tiny_arrow_<who>.png`, `tiny_fx_{heal,summon}.png`, `tiny_fx_wizard_{fireball,shards}.png` (decisions-log 313: the pack's `Wizard/Magic(projectile)/Wizard_Attack02_Effect.png` and `Wizard_Attack01_Effect.png` byte for byte, named for what they show, the pack's names saying which attack strip each goes with; the wizard's plain shot and Arcane Blast, units-and-combat.md "The wizard's magic"). 100×100 frames facing right, feet on row 59. The pack's Soldier strips keep their shadow baked in (nothing to split), and its shadow file borrows the knight's; `onLoad` clears the shadow colour from its strips in memory (`_unshadowed`, replacing them in the image cache), so it is drawn with the shadow file like everyone and has one shadow: the baked one would cover an awakened Soldier's coloured shadow, stick out past the ground one in its last death frames, and show under its drag ghost (issue #11; `test/sprites_test.dart` checks every troop strip the game draws). No other troop's strips have a shadow baked in. The in-memory images are built in `onLoad`, so a running game needs a hot restart (not a hot reload) to pick up a change to them. Each troop strip's awakening outline is built in memory at load too (`_outlined`); there are no outline files. And the skill strips (decisions-log 299; units-and-combat.md "Skill strips"): `tiny_<key>_attack2.png` / `tiny_<key>_attack3.png`, the pack's Attack02 / Attack03 (the Swordsman's `Attack3`), `tiny_priest_attack2.png` (the pack's Attack: the game's priest `attack` is its Heal) and `tiny_skeleton_block.png`, 31 files, only those `lib/skill_strips.dart` plays (the Soldier's attack 3, a bow shot, and the Armored Orc's attack 2 are left out), each the pack's plain strip byte for byte (the Soldier's with its baked shadow, cleared in memory like its others; every troop's and monster's outlined at load, the necro healer's recoloured from the boss's) | `tool/split_shadows.py`; the skill strips and the wizard's magic `python3 tool/import_tiny_skills.py` (stdlib; `--pack DIR`, `--check`) |
| Super Pixel Effects Gigapack + Effect and FX Pixel All Free | `fx_hit_<attacker>.png` (one hit look per troop/monster), `fx_upgrade.png`. Awakened troops reuse them tinted at draw time; there are no awakened files. Since decisions-log 173 the skills', zones' and rings' looks are these sheets' frames too (with `tiny_fx_summon.png`, `tiny_fx_heal.png` and the UI pack's), tinted or dyed at draw time; no new file (which frames: ui-hud.md). | `tool/import_fx.py` (`HITS`) |
| Cute Fantasy Icons Premium (Kenmi; bought, decisions-log 194) | The loot icons: `item_<name>.png` for every `Item` (sword, shield, boots, bow, gloves, potion, staff) and `relic_<name>.png` for the dropped relics (fang, thorns, fury, guard), the boss chest's four Langka Pusaka (ironBanner, bloodFang, warDrum, mourningBell) and its three Legenda (dragonCrown, oathOfOne, alliance): one single icon of the pack each, its 32×32 file (the pack's 16 px art doubled, as the game drew its icons before). `LOOT` in the tool names each one's category and number; what each shows, and the stand-ins for the things the pack has no icon of (crown, scroll, banner, drum, bell), is in loot-items-relics.md "The icons". The pack is never in the repo, `raw_assets/` included (decisions-log 157): the step reads it from wherever it was unpacked and runs on its own. Before it, `tool/draw_icons.py` drew these 18, from when "Free - Raven Fantasy Icons" (free games only) had to go (decisions-log 136); those drawings are now the public repo's placeholders for them (Placeholder art). And the Artifacts' (Pusaka) icons: `artifact_icons.png`, one atlas of a 32×32 cell per kind of the catalog's 90 (30 Langka, 30 Epik, 30 Legenda; 10 a row, in `ARTIFACTS`' order, which `lib/artifact_icons.dart` reads by kind), each its own single icon of the pack (the seven Pusaka above keep their `relic_<name>.png` icon in their cell); what each shows is in loot-items-relics.md "The icons". And `town_mark.png`, the Towns' hammer (Tools 351; the wave meter's "Town after wave 11" chip, its tooltip and the battle log's Town lines: ui-hud.md "Towns on the HUD"), and `town_mug.png`, a mug of amber ale (Food 3; the wave meter in a Town; Food 1, the golden one, is the Full Cup Artifact's), each with its own placeholder drawing in `tool/draw_icons.py`. And the Towns' 30 materials, `mat_<key>.png` for every `Mat` (decisions-log 221; loot-items-relics.md "Town and Smithy: materials"): one single icon each, none an item's, relic's or Artifact's (Monster_Drops 6, 51, 57, 58, 59, 82, 86, 90, 98, 108, 122, 132, 136, 139, 142, 147, 148, 167, 204, 205; Resources 150, 572, 573, 855, 882, 896; Weapons 1091, 1171; Treasure&Keys 61, 64; each one's `in_game` in the pack's metadata), placeholders a round token of their hue. And the forge's (decisions-log 245; loot-items-relics.md "The forge: data"): `item_<key>.png` for the 35 crafted items, `relic_<key>.png` for its nine small relics, `mat_mithril.png` and `mat_starmetal.png`, one single icon each (mapped first with tool/sprite_map.py; Armor, Potions, Resources, Tools, Treasure&Keys, Weapons and Monster_Drops singles, each one's `in_game` in the pack's metadata), placeholders a round token of their hue; a `LOOT` entry may name a tint (r, g, b), a tinted variant of an icon another entry uses. And the pocket items' eight (decisions-log 332; loot-items-relics.md "Pocket items"): `pocket_<key>.png` for every `PocketKind`, Potions 77, 155, 99, 256, 141, 89, 51 and Tools 334 (the bottles a pair in red and blue, the bombs a spiked flask, the Pocket Watch a gold watch; mapped first with tool/sprite_map.py), placeholders a round token of their hue | `python3 tool/import_fx.py icons <the unpacked pack> [--out DIR]` |
| Cute Fantasy UI | `ui_book.png`, `ui_book_marks.png` (Book_UI.png's page tabs and ribbon flags, `BOOK_MARKS`), `ui_bars.png`, `ui_all.png`, `ui_icons.png`, `ui_loading.png`, `ui_click.png`, `ui_tooltip.png` (`UI_Frames.png`'s tan pointer panels cut into a body and two pointers; `python3 tool/import_fx.py tooltip` makes only it), `ui_ribbons.png` (`UI_Ribbons.png` whole: a new Hero's splash title; `python3 tool/import_fx.py ribbons` makes only it), `ui_buttons.png` (`UI_Buttons.png` (0, 0, 96×432): the buttons' normal / hover / pressed columns, 32×16 cells, 9 colours 48 px apart; `python3 tool/import_fx.py buttons` makes only it), `ui_hotbar.png` (30×28, decisions-log 287: `UI_Premade.png`'s flat hotbar (108, 154, 120×28), the owner's picture for the spawn bar, cut into the panel without its slots and one slot; `python3 tool/import_fx.py hotbar` makes only it) (rects in ui-hud.md). The pointer's frames (arrow, two press frames, hand) are `UI_Icons.png`'s at y 224, already in `ui_icons.png`; `Pointer_Click_Anim.png` (`ui_click.png`) is the click sparks. The pack's font (CuteFantasy 5×9) is no longer used (decisions-log 158): the game's font is Poh Sans, and the pack's `assets/fonts/font.ttf` was deleted on 2026-10-02. | `tool/import_fx.py` |
| Pixelify Sans (Google Fonts, SIL OFL 1.1) | `tool/fonts/PixelifySans.ttf` (google/fonts `ofl/pixelifysans/PixelifySans[wght].ttf`, unmodified: a variable font, wght 400-700) and its licence `tool/fonts/OFL-PixelifySans.txt`: the source of Poh Sans, not bundled. The source commit and both sha256s are in CREDITS.md "The font" | none: downloaded once, `curl -L -o tool/fonts/PixelifySans.ttf 'https://raw.githubusercontent.com/google/fonts/9710da1eacb3be272583c3224dcb70f9da6eadbb/ofl/pixelifysans/PixelifySans%5Bwght%5D.ttf'` |
| Poh Sans (made for the game from Pixelify Sans, the same OFL; decisions-log 179) | `assets/fonts/PohSans.ttf`: Pixelify Sans with its 2, 3, 5, 6, 9, B, C, G, S, Z, a, c and i redrawn and its names changed, everything else (the kerning included) its bytes; licence `assets/fonts/OFL-PohSans.txt`; pubspec.yaml's family `PohSans`, every text through `hudStyle` (lib/hud_font.dart; ui-hud.md "The font"). sha256 in CREDITS.md | `python3 tool/make_poh_sans.py` (stdlib; byte for byte; `--check`, `--show`) |
| Retired fonts (decisions-log 158, 168, 179) | `assets/fonts/PixelifySans.ttf`, `PohDigits-Medium.ttf`, `PohDigits-Bold.ttf`, `OFL-PixelifySans.txt`, `OFL-PohDigits.txt`: Pixelify Sans and PohDigits, which the game drew before Poh Sans. No longer bundled; left until the owner's game is closed (dev-workflow.md "Traps"; itch-page.md, retired files), then deleted. Their tool, `tool/make_digit_font.py`, is gone | none |
| LudicArts Background_Free_Valley_pack (no longer used) | Was `bg_ground.png`, the field's road, and `bg_valley_{5,4,3}.png`, the band above the field, until decisions-log 228 (the battle's backdrop is GandalfHardcore's, below); the four files and their importer `tool/import_backdrops.py` were deleted in decisions-log 234 | none |
| GandalfHardcore FREE Platformer Assets (decisions-log 222: the Town scene, from this pack only but the smith, 265; 228: its Normal BG layers are the battle's band above the field too, camera-and-field.md "Backdrop") | The Town's pieces, each named in `lib/town_art.dart`, which the tool writes too (rects in sprite px on the named file): `town_bg_1..5.png` the Normal BG layers 1 (the near pines and the ground band) to 5 (the sky, opaque) and `town_castle.png` (`Background Castle .png`, drawn between 4 and 3), 1024×346 each, as they are; `town_ground.png` the street (decisions-log 279: the owner's own crop of `Floor Tiles2.png`, found in it exactly at (19, 0)), `Floor Tiles2.png` (32, 0, 32×14): its 32-px grid's cell (1, 0), the green block's top edge, cut to its grass (rows 0-12, the blades hanging into the earth) and one row of the earth under it (one colour, 19,17,22, the block's fill); the block's top repeats every 32 px (its columns 11-31 are 43-63), so the tile laid side by side is the sheet's own run, seamless; tiled from the street's line, its last row stretched on to the screen's bottom (mapped with `tool/sprite_map.py`); `town_floor.png` (`Floor Tiles1.png`'s grassy lip, the street until decisions-log 274) and `town_grass.png` (`Tall Grass.png`'s strip, 274's tufts), no longer drawn since 279, are deleted (decisions-log 294); `town_house.png` the house's 64 cells, `House Tiles.png`'s left house (x 0-224) 16×16 each (the porch row's 16×8 at the top of their slot), 8 a row (128×128) in the order the design numbers them (`HOUSE` in the tool, the cell names `townHouseCells`): the house is rebuilt from them cell by cell, never the sheet pasted; `town_smithy.png` `Furnace and Sawmill.png` as it is (64×64 frames, row 0 the furnace, row 1 the sawmill, 6 each); `town_campfire.png` `Animated Sprites/Campfire with food sheet.png` as it is (32×32 frames, 5 a row, 8 loops); `town_tent.png` `Large Tent.png` (0, 7, 96×121), the troops' rest; `town_ore.png` `Ores.png`'s blue rock (70, 90, 53×38); `town_pine.png` (50×128) `Pine Trees.png`'s olive pine as the owner drew it (note 2026-10-04): the sheet is modular on a 32-px grid (each pine's cone in rows 0-63, three tiers, the trunk under them; mapped with `tool/sprite_map.py`, its sprite 3, the box (97, 0, 93×192)), and the pine is stacked from that sprite's rows 0-95 (the cone and the first tier) over its rows 176-191 twice (the trunk), cut to its columns (`STACKS` in the tool); the bare trunk the sheet stands inside that box (97, 0, 29×64, sprite 2) is cleared; `town_props.png` (128×114) `Decor.png`'s table (262, 21, 18×11), crate (2, 16, 27×16), barrels (98, 14, 29×18), stacked crates `crates2` (34, 0, 27×32), cauldron (168, 17, 18×15), log pile (201, 75, 47×21), stump with an axe (231, 11, 21×21), clothes line (27, 354, 106×62), fruit-and-bread table (267, 34, 39×30) and apple basket (360, 49, 17×15), packed tallest first with a 1 px gap (`townPropCells`); the Towns' identities (decisions-log 326; ui-hud.md "Town"): `town_autumn_bg_1..5.png` and `town_autumn_castle.png` (`Autumn BG`, its `Background Castle Autumn.png`), `town_winter_bg_1..5.png` and `town_winter_castle.png` (`Winter BG`, `Background Castle  Winter.png`), 1024×346 each as they are, laid out as the Normal set; `town_ground_autumn.png` and `town_ground_winter.png`, `Floor Tiles2.png`'s same cell as the street's in its autumn band (32, 192, 32×14) and its snowy one (32, 384), the same earth row; `town_yards.png` (256×429) the yards' pieces (`YARDS` in the tool, `townYardCells`), each cut to the box `tool/sprite_map.py` maps: `Flowering Tree.png` (4, 12, 85×100), `Wheat.png`'s grown wheat (133, 0, 19×32), sack (198, 12, 20×20) and sheaf (226, 16, 12×15); `Weeping Willow1.png` (4, 1, 216×191), `Boat.png`'s first frame (1, 7, 78×25), `Garden Decorations.png`'s green, olive and small potted plants (36, 7, 23×25; 37, 36, 21×28; 71, 48, 18×16); `Birch1.png` (2, 5, 75×107), `Ores.png`'s gold rock (6, 90, 53×38), `Torch.png`'s lit torch, its row 1's six frames of the flame (11 + 32·i, 33, 10×31), side by side (`townYardFrames`); `Small Tent.png` (0, 0, 64×64), `Alchemy Decor.png`'s flower table (79, 26, 37×38), sunflowers (163, 21, 27×43), bowl of grapes (137, 46, 14×18) and alchemy table (35, 42, 26×22); `Garden Decorations.png`'s cypress (130, 26, 28×102), urns on plinths (99, 66, 27×62; 65, 74, 29×54; 35, 86, 27×42), bust (5, 83, 21×45) and tree (163, 38, 56×90); `Angel Statue.png` (9, 0, 48×64); packed as `town_props.png`. Every file 8-bit RGBA, the pixels unchanged. `test/fixtures/town_house_cells.json` is the design's three houses cell by cell (n 0 one storey, n 0 and n 1 two storeys) with their props, which the scene's house must equal (test/town_art_test.dart) | `python3 tool/import_town.py` (stdlib; reads the main checkout's `raw_sprites/gandalfhardcore-platformer/`, or `--pack DIR`); `--check` writes nothing and fails while a file or `lib/town_art.dart` differs from the pack's pixels |
| GandalfHardcore FREE Platformer Assets: the battle's floor, props line and clouds, and the spawn bar's step (decisions-log 228, 244, 263, 287; camera-and-field.md "Backdrop", ui-hud.md "Spawn bar") | Four pictures at the parallax layers' 5 px a world unit, built from the pack's sheets (each mapped first with `tool/sprite_map.py`; every piece cut at its exact box, the tool refuses a box that slices a neighbour), every pixel a pack pixel or, in the meadow, a pack colour: `battle_floor.png` (1024×786, its last 106 rows under the field's bottom) Tall Grass.png's strip (0, 12, 96×20) in rows 6 px apart, 13 overlapping copies a row shifted by a fixed LCG, a little darker over the first rows and then a step lighter (the lanes' meadow), opaque from its row 40 (the horizon; the tool checks); the ground line along the horizon, doubled: Pine forest sheet.png's flower tufts (its sprites 4-6) and Decor.png's ferns, small bushes and rocks (52, 55, 82, 97, 98); Decor's pebbles at 1x (52, 55, 63, 79, 82, 97, 98); Floor Tiles1.png's cell (32, 0, 32×32), its first 16 rows along the last 16 (its grass lip at field y 146; 138 until decisions-log 287). `battle_props.png` (2048×330) Pine forest sheet.png's trunks (0-2), pine (7) and lower log (8's rows 176-207: the two logs are one island, split there), Decor.png's boulders (86), bushes (96, 97), fern (98) and rocks (52, 55, 82), doubled, and Tree1.png and Tree2.png whole at 1x, each standing on its row 328. `battle_clouds.png` (3072×130) cloud1..cloud6 whole at 1x, twelve of them (the Town's sky draws it too, between its sky and mountains: decisions-log 274). `battle_step.png` (352×76, decisions-log 287, 295) one strip of ground, a little hill `___/top\___`: every column Floor Tiles1.png's grass-topped cell's (32, 0, 32×32) column x % 32 lowered to the ground's height there (the step's top, a half cosine down 60 px over 96 on each slope, the low ground), the cell's earth under it: the spawn bar's step and the earth under the floor. The pack has no diagonal ground tile, so the slopes are built so. Floor Tiles2.png (the same tiles, blue-black earth), Other Tiles1.png (its rock slope was the step's until decisions-log 295), the pack's grass tufts and the upper log are unused | `python3 tool/import_battle_floor.py` (stdlib; the pack as for `import_town.py`, or `--pack DIR`); `--check` writes nothing and fails while any of the four differs |
| Mana Seed Character Base demo 2.0 (Seliel the Shaper) with Pixel Crawler's anvil (Anokolisa) (decisions-log 265: the Town's smith; ui-hud.md "Town") | `town_smith.png` (275×32): the smith hammering at his anvil, facing right, five frames of 55×32 in a row, each cut to the box every frame fits in (the anvil stays put), his feet on the bottom row: slash 1's backswing and its raised hold (page ONE-hand 3, columns 1 and 4), the draw's frame with the mace forward and up (ONE-hand 1, column 2), the parry, whose mace head lands on the anvil's horn (ONE-hand 1, column 4), and the combat idle's first (ONE-hand 2, column 1) as the pause; row 2 of each page (the rows face down, up, right, left). Each frame is the paper doll stacked in the guide's order: `0bas_humn_v05` (the skin), `1out_fstr_v01` (the forester's outfit), `4har_dap1_v11` (brown hair), no hat, and `6tla_mc01_v01` (the mace, the hammer) behind or in front of the body as the page's "layer order (sword)" guide says for that frame; the slash's white swoosh (244, 249, 248, a colour only the tool layer's swing frames use) left out. Then Pixel Crawler's `Environment/Props/Static/Tools.png` sprite 46, the small anvil on its foot (148, 93, 26×19; mapped with `tool/sprite_map.py`, the tool refuses a box that isn't exactly one sprite), whole over each frame at (38, 25) of the 64×64 cell: its foot on the smith's feet row, the strike's head on its horn. Every pixel a pack pixel. `lib/town_smith_art.dart` (written by the tool) names the frame (`townSmithW`, `townSmithH`, `townSmithFrames`), his feet in a frame (`townSmithFeet`) and the loop (`townSmithBeats`, 3000 ms: the backswing 160, three blows of raised 400, swing 80, strike 200, the pause 800: the pack's own numbers, its attacks' 160/65/65/200 and its smithing's 400/400/80/80/80). Drawn at 1 world px a sprite px, the houses' own: at the troops' 2 he would stand 56 px, taller than the Smithy's door (~45) | `python3 tool/import_smith.py` (stdlib; reads the main checkout's `raw_sprites/mana-seed-character-base-demo/` and `raw_sprites/pixel-crawler/`, or `--pack DIR`, `--anvil-pack DIR`); `--check` writes nothing and fails while the file or `lib/town_smith_art.dart` differs |
| Generated audio | `assets/music/{battle,idle}.ogg`, sfx wavs | `tool/gen_music.py`, `tool/gen_sfx.py` |

## Images made in memory (no files)

`TdGame.onLoad` builds some images from loaded ones and adds them to the image cache; they need a hot
restart like any new image (dev-workflow.md).

| Cache key | Built from |
|---|---|
| `book_<troop>_idle` | `tiny_<troop>_idle.png` without its shadow colour (`_unshadowed`), for the book (ui-hud.md). |
| `tiny_necro_healer_{idle,walk,attack,hurt,death}.png` | The necromancer's strips through `_recoloured(…, _necroHealerTint)`: the navy robe teal, the grey-green hood lining and spell gold, the red eyes pale green. |
| `tiny_necro_healer_cast.png` | The necromancer's summon strip, recoloured the same way: it casts its heals with it (`_casters` in main.dart); its attack strip is the scythe swing it makes when it can't heal. |
| `tiny_necro_healer_shadow.png` | The necromancer's shadow as it is. |
| `tiny_wizard_attack2.png` (in the file's place) | The file through `_recoloured(…, _arcaneStaff)`: its staff's orange glow (#C9512E, #EF6E10, #DB955A, colours of that glow only) in the ice star's blues (#086EC7, #43B4DF, #7DDDE1), since it casts Arcane Blast's star, not the pack's fireball (decisions-log 313; lib/wizard_fx.dart). |
| `tiny_fx_holy.png` | `tiny_fx_heal.png` through `_recoloured(…, _holyTint)`: its darker green silver (#C4CCD8), its lighter green white (#FFFFFF). A troop healer's smite on a dark monster (ui-hud.md). |

## The app icon

Every platform's app icon is the Hero knight, drawn by `tool/make_app_icon.py` from the game's own sprites
(decisions-log 135; the owner: "icon game ambil dari sprite knight heronya saja terus di kasi kan background di
belakangnya"). Run `python3 tool/make_app_icon.py` (about 10 s) after changing the knight's idle strip or the crown;
`--preview <dir>` also writes the macOS icon at 1024, 256, 64, 32 and 16 px and `sheet.png`, every file on light and
dark with the small ones zoomed. It only reads `assets/images/`; it writes nothing there. `--out <dir>` writes the
platform files under `<dir>` instead of the repo.

- **The public repo's icon** (`python3 tool/make_app_icon.py --placeholder`, decisions-log 160): the same background,
  shapes and sizes with a figure of our own in place of the knight and the crown, a gold crown over a red heater
  shield with a sword down its middle (`PLACEHOLDER` in the tool: 22×23 knight pixels as ASCII art, standing where the
  knight does, its point on the feet's row). It reads no file. The public export (scripts/export-public.sh) draws it
  at every platform's paths, since the knight's icon is a pack derivative.

- **The figure:** `tiny_knight_idle.png` frame 0, cropped to the knight (x 41..66, y 39..56 of the frame), scaled by
  a whole number with nearest neighbour, in a Hero's look (hero.dart, hero_splash.dart): the splash's white halo
  behind its body (radius 14 round feet − (0, 11)) and `ui_icons.png`'s gold crown (64, 16) above the helmet, half a
  knight pixel per crown pixel as on the field. The figure's box is 26 knight pixels wide.
- **The background is ours, from no pack:** a sunrise radial gradient from the halo's centre (cream, the crown's
  yellow and gold, deep orange, a dark ember at the corners), the Hero splash's 10 light rays (one straight up
  through the crown), a soft ground shadow under the feet, and a dark rim in the crown's outline colour (#3F2832)
  with a thin gold line inside it.
- **The scale:** about 0.62 of the rounded square's side, rounded to a whole number of pixels per knight pixel
  (macOS 1024: 20; 512: 10; 256: 5; 128: 2; 64: 1). Where not one whole pixel fits (macOS 16 and 32, Windows 16, 24
  and 32, the favicon) the figure is area-averaged to 0.8 of the square, then made a sharp silhouette with a darkened
  edge, so at 16 px it is still a dark knight with a sword and a gold crown on the gold.

| Platform | Files (what the tool writes) | Shape |
|---|---|---|
| macOS | `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{16,32,64,128,256,512,1024}.png`; `Contents.json` (Flutter's) already names each size | Apple's icon grid: an 824/1024 rounded square (radius 185), a soft drop shadow below it, clear corners |
| Windows | `windows/runner/resources/app_icon.ico` (`Runner.rc`): 16, 24, 32, 48, 64, 128, 256, PNG entries | The rounded square on nearly the whole canvas (3% inset) |
| Linux | `linux/runner/resources/app_icon.png`, 256 | The same. `linux/CMakeLists.txt` installs it as `data/app_icon.png` in the bundle, and `linux/runner/my_application.cc` sets it as the window icon (title bar, taskbar, switcher), found next to the binary through `/proc/self/exe`. GNOME on Wayland ignores window icons and shows a `.desktop` file's icon instead: that needs an installer (a later job). |
| Android | `android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` (48 dp: 48..192 px), for Android 7 and older | The rounded square |
| | `mipmap-*/ic_launcher_{background,foreground,monochrome}.png` (108 dp: 108..432 px) and `mipmap-anydpi-v26/ic_launcher.xml` (the adaptive icon, Android 8+; the manifest's `@mipmap/ic_launcher` is unchanged) | The sky full bleed; the knight with its halo and shadow inside the 66 dp safe circle; its silhouette for Android 13's themed icons (outline and visor solid, the rest half see-through). `aapt2 link` against android-36 accepted them (2026-10-01). |
| Web | `web/favicon.png` (32), `web/icons/Icon-{192,512}.png`, `web/icons/Icon-maskable-{192,512}.png` (manifest.json) | The rounded square; the maskable ones full bleed with the knight in the 80% safe circle |

`test/app_icon_test.dart` reads each file's PNG/ICO headers for its sizes and checks that none is still Flutter's
logo (`flutter create`'s icons, by hash).

**Licence:** the icon is a derivative of two paid packs: Zerie's Tiny RPG pack (the knight) and Kenmi's Cute Fantasy
UI (the crown). Both allow using and modifying their art in commercial games (itch-page.md, Licences), so the icon
ships in our builds like any sprite. Being a pack derivative, it is under the packs' no-redistribution terms: these
platform files never go into the public repo: the export gives it the placeholder icon instead (above).
The background is our own drawing.

## Adding an image

1. Import it with a tool script (so it can be regenerated), into `assets/images/`.
2. Add it to the list in `TdGame.onLoad`.
3. `touch lib/game.dart` to force a hot restart (dev-workflow.md). Never delete asset files while the
   session runs.
4. A file a build ships needs its line on the release allowlist in both places: `ALLOWED_ASSETS` in
   `scripts/release-build.sh` (`scripts/release-build.sh check` refuses a file under `assets/` that no line takes) and
   the private notes' itch-page.md "What a build ships". `scripts/test-release-build.sh` compares the two where the
   private notes are checked out as `private/`, and skips that check where they aren't.

## The asset vault

The licensed art is git-ignored here: the repository holds it only encrypted, in `assets-vault/`, which only the
team's key opens. The owner gives the key to members; nobody else can open the vaults, nor rebuild the art from this
repository. Without the key, `tool/gen_placeholders.py` draws placeholders ([Placeholder art](#placeholder-art-the-public-repo)).

- **The vaults** (`python3 tool/asset_vault.py list`): one per pack, holding what a build needs (every file
  `tool/assets.sha256` lists, and the platform app icons): `game-tiny-rpg`, `game-effects`, `game-ui`, `game-icons`,
  `game-smith`, `game-town`, `game-app-icon`. A file goes to the first vault whose `match` pattern takes it. Our own
  files (the music, the sfx, `assets/ai/`, `assets/config/`, the OFL fonts) are plain files.
- **`tool/asset_vault.json`**, the one source of truth: per vault its pack, licence and `match` patterns, the
  plaintext tar's sha256, its parts' sha256s and every file (path, bytes, sha256).
- **The format:** a deterministic ustar tar (names sorted, mode 0644, uid and gid 0, a fixed mtime) → gzip without a
  name or time → `openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 -salt` → parts of at most 45,000,000 bytes,
  `assets-vault/<name>.tar.gz.enc` (or `.part01`, ...). One command opens a vault by hand:
  `cat assets-vault/<name>.tar.gz.enc* | openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 -pass file:<key file> | tar -xzf - -C <dest>`.
- **The key** is never read, printed or put on a command line by the tool: openssl reads it itself. Where it is:
  `--key-file PATH`, else `POH_VAULT_KEY_FILE` (a path), else `POH_VAULT_KEY` (the key itself: CI's secret), else the
  clone's `git config poh.vaultKeyFile <path>`, else `~/.config/path-of-hero/asset-vault.key`. A key file must be
  mode 600, outside every checkout and not empty.
- **Once per clone, with the key:** `python3 tool/asset_vault.py unpack --only game`, then
  `python3 tool/asset_vault.py install-hooks` (`git config core.hooksPath .githooks`, for every checkout of the clone).
  The hooks keep the art and the vaults in step, vault by vault, with a state file per checkout
  (`git rev-parse --git-path asset_vault.synced`):
  - **pre-commit:** when a vault's art differs from the staged vault, it re-packs that vault alone and stages its part
    and the JSON; it refuses when that vault changed in git since your art was last synced (a merge brought another):
    run `sync`, or `resolve` after a stopped merge, or `sync --keep-mine` to put your art over it on purpose. It never
    packs placeholders, packs nothing without the key (and says so), refuses a licensed file forced past `.gitignore`,
    and runs `python3 tool/privacy_check.py --staged` (and **commit-msg** runs it on the message: a commit message is
    as public as the files). After changing art, run `python3 tool/asset_manifest.py` first.
    A commit of the art alone: `python3 tool/asset_vault.py commit -m "..."` (git stops at "nothing to commit" before
    a hook could add the vault).
  - **post-checkout and post-merge** (`sync`): a vault whose art you didn't edit since the last sync (or that is
    absent, or placeholders) is unpacked; art with edits of its own is left alone, with a warning. A file that left
    its vault is deleted in a second checkout of the clone and only listed in the main one, where the game may be
    running (deleting a file under `assets/` ends a running session: `prune` deletes it later).
  - **pre-push:** with `git config poh.publicRoot <the first commit>`, a push to the public repository (the remote
    `public`, or `git config poh.publicUrl`) takes only `main` and `v*` tags of that history, after the privacy check
    of its files and of the messages of the commits the remote doesn't have yet; that history goes to no other remote
    unless `POH_PUSH_PUBLIC_HISTORY=1`.
  - **A tree without `tool/asset_vault.py`** (the private notes checked out as `private/`, a branch of the old
    history): every hook exits 0 at once, quietly, but pre-push. `git worktree add` runs the clone's post-checkout in
    the new tree and exits with its status, so before this a checkout of such a branch failed. **pre-push** fails
    closed there instead ("pre-push: no tool/asset_vault.py in this tree; the public-history guard can't run"): push
    from a checkout that has the tool. (A tree without `.githooks/`, like the private notes, runs no hook at all.)
- **A copy without git** (`git archive <commit> | tar -x -C <dir>`): no hooks and no art; `python3
  tool/asset_vault.py unpack --only game --key-file <key file>` in it puts that commit's art there, every file checked
  against that commit's JSON.
- **Two branches that changed one vault:** git can't merge the encrypted parts. After the stopped `git merge`,
  `python3 tool/asset_vault.py resolve` merges file by file (a vault only one side changed takes that side; in one both
  changed, each file takes the side that changed it), rewrites the manifest, re-packs and stages. A file changed
  differently on both sides is named, and `resolve --take ours` or `--take theirs` settles them.
- **`check`** (no key): every file of the game vaults at its path with its sha256, every licensed file in its vault,
  every part whole. The release check runs it, so no build is made while the vault is older than the art.
- **CI** (`.github/workflows/ci.yml`, `release.yml`) opens the vaults with the secret `POH_VAULT_KEY`; without it (a
  fork's pull request) the checks run on placeholders and the art-tagged tests are skipped, and no release is built.
- Tests: `python3 tool/test_asset_vault.py` and `python3 tool/test_asset_vault_hooks.py` (testing.md).

## Tools

- The Python tools in `tool/` use only the standard library (`tool/build_atlas.py` has `read_png` / `write_png`), and
  every path in them is relative to the repo.
- The importers (`split_shadows.py`, `import_fx.py`, `import_backdrops.py`, `export_aseprite.py`, `build_atlas.py`)
  are the record of how each licensed file was made from its pack; the packs are not here, so they can't run.
  `gen_sfx.py` and `gen_music.py` synthesise the audio (`gen_music.py` needs ffmpeg), `gen_placeholders.py` draws the
  placeholder art (the loot icons from `draw_icons.py`'s drawings) and `make_app_icon.py --placeholder` the platform
  icons.
- Map a sheet before using any of its sprites (the owner, 2026-10-04: "selalu petakan sprite dulu sebelum di gunakan"):
  `python3 tool/sprite_map.py <sheet.png> <map.png> [--scale K] [--grid N]` prints every sprite (an 8-connected island
  of opaque pixels) numbered with its exact box and draws them numbered on a picture, with the sheet's N-px grid if
  asked. asset_meta.py's `auto.boxes` cut along clear rows and columns instead, so a stump standing inside a tree's box
  lands in the tree's; never crop from those boxes unmapped.
- `asset_vault.py` keeps the encrypted art and the git-ignored files in step ([The asset vault](#the-asset-vault)).
  `privacy_check.py` refuses what never goes into this public repository: home folders, IP and e-mail addresses,
  tokens and key files, in files and in commit messages (the pre-commit, commit-msg and pre-push hooks and CI run
  it).
- None of them parses `--help`: running one runs it.

## Placeholder art (the public repo)

A public repo can't hold the licensed files under `assets/` in plain (the packs' stores forbid re-sharing them), and
nobody supplies the packs to rebuild them (decisions-log 157). So it carries what the code needs to know about them,
and a clone without the asset vault's key draws a placeholder for each: `python3 tool/gen_placeholders.py && flutter
run`.

| File | What | Kept true by |
|---|---|---|
| `tool/asset_manifest.json` | Every licensed file under `assets/`, one per line: `path`, `bytes`, `kind`, the image's `width` and `height`, the `frame` the code cuts (w, h) and how many `frames`; a character's `feet` (50, 59), and `baked_shadow` on the strips with the shadow colour in rows 55-59 (the Soldier's 5). Its head: what each kind is and where the code cuts it, and the `licensed` and `own` patterns | `python3 tool/asset_manifest.py` (stdlib, ~4 s; it reads `assets/`, never writes there) after any change under `assets/`; `--check` writes nothing and exits 1 while any of its three files is stale |
| `tool/assets.sha256` | Their sha256s, `shasum -a 256 -c tool/assets.sha256` form from the repo root (hashes can be public) | the same |
| `tool/gen_placeholders.py` | Draws the placeholders from the manifest alone (below) | `python3 tool/test_gen_placeholders.py` (testing.md) |
| `tool/placeholders.gitignore` | The public `.gitignore`'s lines for them (and for the real art, git-ignored there too): `/` + each `licensed` pattern | written by `python3 tool/asset_manifest.py` from `LICENSED` (since decisions-log 287); test/asset_manifest_test.dart |

- **Licensed or own.** `LICENSED` in `tool/asset_manifest.py`: `tiny_*`, `fx_*`, `ui_*`, `bg_*`, the loot icons
  `item_*`, `relic_*` and the Artifacts' atlas `artifact_icons.png` (kind `icon`, decisions-log 194), the Towns' icons
  `town_mark.png`, `town_mug.png` and the materials' `mat_*` (kind `icon`, decisions-log 221), the pocket items'
  `pocket_*` (kind `icon`, decisions-log 332) and the Town scene's
  pieces (kind `town`, decisions-log 222: each file by name, so a new `town_*` icon still needs its own line) and the Town's
  smith `town_smith.png` (kind `npc`, decisions-log 265; its frame in `GRID`, read from `lib/town_smith_art.dart`) under
  `assets/images/`: 239 images on 2026-10-04. A
  `town` sheet's grid is in `GRID` (the house's 16×16 cells, the smithy's 64×64 and the campfire's 32×32 frames), and
  the props' atlas lists its rects as `cells` (`CELLS`, from `tool/import_town.py`'s layout). `OWN` is
  public as it is: the music and sfx, `assets/ai/`, and the open fonts Poh Sans (`assets/fonts/PohSans.ttf`) and
  the retired Pixelify Sans (`PixelifySans*.ttf`) and PohDigits (`PohDigits-*.ttf`), with their `OFL-*.txt` (SIL OFL
  1.1; decisions-log 158, 168 and 179). A file under `assets/` that matches neither stops the tool and fails the test: check its licence (itch-page.md "Licences"),
  then add it to one of them.
- **What it draws** (from scratch; it never opens `assets/` or `raw_assets/`, so nothing in it comes from a pack):
  - a character strip: a figure per character, its hue from its name, facing right, the feet's bottom row on 59,
    posed by the strip (idle bob, walk steps, attack reach, hurt flash and knock-back, death fall, summon with raised
    arms), a dark outline; a `baked_shadow` strip gets the shadow under the figure, as the pack's does, so
    `_unshadowed` and test/sprites_test.dart work on it;
  - a shadow file: an ellipse of the shadow colour (83,69,69) in rows 55-59, the only place that colour is used;
  - arrows pointing right; bursts as a ring that grows and fades with sparks (the heal green, the summon a purple
    circle on the ground, `fx_upgrade` gold);
  - the UI sheets: the buttons in the nine colours main.dart names (rows 48 px apart; normal, lit and pushed
    columns), a round icon of its own colour per 16×16 cell of `ui_icons.png`, `ui_bars.png` in 8-row bands of
    colour, the loading dial and click sparks, the book as parchment pages in a brown cover, the rest plain
    parchment (rects the code cuts anywhere: ui-hud.md);
  - the backdrops (kind `backdrop`, drawn no more): a sky with far hills, two layers of nearer hills, the old
    ground's grass and dirt road;
  - the battle's floor (kind `floor`): clear over the horizon (row 40 of 680) but for a ground line of red and green
    tufts and the blade tips, a meadow in rows of two greens, a grass top over earth along its last 32 rows, the same
    every 32 columns so it tiles; the props line (kind `props`): brown trunks from the top to the feet, a crown on a
    trunk, rocks and bushes at the feet; the clouds (kind `clouds`): white puffs of a few sizes over a clear strip;
  - the Town scene's pieces (kind `town`): the parallax layers (a sky, far mountains, a castle on its hill, rows of
    pines, the near pines over the ground band, so the street lies where the pack's does), the street's ground (grass
    over earth, the same in every column so it tiles) and its tufts (blades over a green body), a brick per house cell, a stone furnace and a sawmill bench per
    smithy frame (the fire and the saw moving), a pot over a flickering fire per campfire frame, a tent, an ore rock,
    a pine, and a crate in each of the props' `cells`;
  - the Town's smith (kind `npc`): per frame a figure facing right, a grey anvil on his right on the feet's row, and a
    hammer back, raised, forward, down on the anvil and lowered, frame by frame;
  - the loot icons and the Towns' hammer and beer mug (`town_mark.png`, `town_mug.png`): `tool/draw_icons.py`'s drawing
    of each (the icons the game showed before it took Kenmi's pack, and the hammer and mug drawn for it: 16 px ASCII art
    over one palette, doubled to 32×32), or, for a name it has no drawing of, a round token of the name's
    hue; the Artifacts' atlas a round token of its own colour per 32×32 cell.
- **No placeholder font.** The game's font is the open Poh Sans, committed for real with its source, Pixelify Sans
  (decisions-log 158 and 179), and no licensed font is left under `assets/`: Kenmi's `font.ttf` was deleted on 2026-10-02, so
  every file the manifest lists is an image. A kind the tool can't draw stops it (exit 1, nothing written).
- **Never over the real art.** It refuses (exit 1, nothing written) when git tracks any file it would write, asked
  in the real folder of each, so `--out` and symlinks can't get round it, and when a file it would write is already
  there and isn't one of its own placeholders (the real art, git-ignored in the public repository, unpacked from the
  vault). Where `assets/` is the real art and tracked, write elsewhere: `python3 tool/gen_placeholders.py --out <dir>`
  (files go to `<dir>/assets/...`); `--dry-run` checks and lists. In a public clone the files are git-ignored, and the
  default `--out` is the repo.
- **What it drew** goes in `assets/.placeholders` (git-ignored): each file's path and sha256. `tool/asset_vault.py`
  never packs those files, and unpacking the vault replaces them and drops the list.
- **The platform app icons** are a pack derivative ("The app icon"), outside `assets/`: it draws their placeholder too,
  with `tool/make_app_icon.py --placeholder` (`--no-icons` leaves them).
- **Tests on placeholders:** `flutter test -x art` (testing.md "Placeholder art").
