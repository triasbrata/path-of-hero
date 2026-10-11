"""Copies the on-hit effects and the loot icons into assets/images.

- fx_hit_<attacker>.png: what a hit by that troop/monster looks like, a strip of square frames (the
  game draws it at 32/frame size, 15 fps). F = "Effect and FX Pixel All Free" (64x64 frames, 9 colour
  rows: we cut one row); G = "Super Pixel Effects Gigapack" (strips, used as they are).
- fx_upgrade.png: shown on a troop that takes an item.
- The loot icons (item_<name>.png, relic_<name>.png) and the Artifacts' atlas (artifact_icons.png): single icons of
  Kenmi's "Cute Fantasy Icons Premium" (LOOT and ARTIFACTS below; decisions-log 194). A bought pack never goes into
  raw_assets/ (decisions-log 157), so this step reads the unpacked pack from wherever it is given and runs on its own:
  python3 tool/import_fx.py icons <the unpacked pack> [--out DIR]   (default DIR: assets/images)
- ui_tooltip.png: the tooltips' frame, from Cute Fantasy UI (TIP_* below).
- ui_ribbons.png: Cute Fantasy UI's six tan ribbons, copied whole (a new Hero's splash title).
- ui_buttons.png: the buttons' normal / hover / pressed looks, from Cute Fantasy UI (BUTTONS below).
- ui_hotbar.png: the spawn bar's hotbar, from Cute Fantasy UI's premade hotbar (HOTBAR below).
Stdlib only:  python3 tool/import_fx.py   (only the tooltip frame: python3 tool/import_fx.py tooltip;
only the ribbons: python3 tool/import_fx.py ribbons; only the buttons: python3 tool/import_fx.py buttons;
only the hotbar: python3 tool/import_fx.py hotbar)
"""
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from build_atlas import read_png, write_png  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/images"
F = ROOT / "raw_assets/Effect and FX Pixel All Free/Free"
G = ROOT / "raw_assets/Super Pixel Effects Gigapack (Free Version) v2.9.0/Super Pixel Effects Gigapack (Free Version)/spritesheet"
# The open orange book of "Cute Fantasy UI" (the HUD): its 240x144 cell at the sheet's top left. The
# sheet's own 9-slice guide cuts it at x 31/96/143/208 and y 31/112 (lib/main.dart `_bookSlices`).
BOOK = (ROOT / "raw_assets/Cute_Fantasy_UI/UI/Book_UI.png", (0, 0, 240, 144))
# Book_UI.png's bookmarks, cut as one block (lib/main.dart `_bookmarks`, rects in docs/ui-hud.md): the page
# tabs (tan / grey, short and tall; the peach and light grey ones under them) and the ribbon flags (7
# colours, two sets, a short open-ended row and a long closed-ended row under it).
BOOK_MARKS = (ROOT / "raw_assets/Cute_Fantasy_UI/UI/Book_UI.png", (588, 26, 816, 74))
BARS = ROOT / "raw_assets/Cute_Fantasy_UI/UI/UI_Bars.png"  # copied whole: the HP bars in lib/main.dart
# The top of UI_ALL.png: 9-patch buttons (7 colour rows, 48px apart) and the rounded page frames.
UI_ALL = (ROOT / "raw_assets/Cute_Fantasy_UI/UI/UI_ALL.png", (0, 0, 1300, 340))
# The tooltips' frame (lib/tooltip.dart): UI_Frames.png's tan panels with a pointer (row 0; the six rows
# under it are the same in other colours). One 42x26 sheet: the body of the bottom-pointer panel with the
# pointer's columns of its lip filled from a plain column (24x26 at 0,0, 9-sliced l 3, t 3, r 3, b 5), that
# pointer (9x10 at 24,0: its top 5 rows lie over the lip, the tip hangs 5 below) and the left-pointer
# panel's pointer (9x13 at 33,0: its column 6 is the body's left edge, the tip at column 0, rows 5-7).
FRAMES = ROOT / "raw_assets/Cute_Fantasy_UI/UI/UI_Frames.png"
TIP_BODY = (780, 12, 24, 26)  # the bottom-pointer panel, in the cell at x 768
TIP_DOWN = (790, 33, 9, 10)  # its pointer, from the lip down to the tip
TIP_PLAIN = 786  # a column of that lip with no pointer
TIP_SIDE = (726, 21, 9, 13)  # the pointer of the panel in the cell at x 720
# A new Hero's splash title (lib/hero_splash.dart `_ribbon`): the flat small ribbon at (8, 1), 64x20.
RIBBONS = ROOT / "raw_assets/Cute_Fantasy_UI/UI/UI_Ribbons.png"
# The buttons (lib/button_fx.dart): UI_Buttons.png's first three columns, 32x16 cells: normal, hover (its
# face 1 px lower, a thin shade), pressed (2 px lower, darker, no shade). Three shapes a colour (cut
# corners, square, round), 9 colours 48 px apart: light brown, white, green, blue, orange, red, purple,
# peach, grey.
BUTTONS = (ROOT / "raw_assets/Cute_Fantasy_UI/UI/UI_Buttons.png", (0, 0, 96, 432))
# The spawn bar's hotbar (lib/spawn_bar.dart; the owner, 2026-10-09, with a picture of it): UI_Premade.png's flat
# hotbar, sprite 2 of its map (tool/sprite_map.py: 108, 154, 120x28; sprite 3 beside it is the same with a lip), a tan
# panel (a 2-px rim, its corners rounded, 5 px of tan round the slots) holding five 18x18 inset brown slots 23 px
# apart. One 30x28 sheet: the panel without its slots (11x28 at 0,0: its columns 0-4, a plain one between two slots
# (23) and 115-119; 9-sliced 3 all round, the middle plain tan) and one slot (18x18 at 12,0: its 5..22 square;
# 9-sliced l 2, t 3, r 2, b 1: the outline and the inner shade on its top).
HOTBAR = (ROOT / "raw_assets/Cute_Fantasy_UI/UI/UI_Premade.png", (108, 154, 120, 28))
HOTBAR_COLS = [*range(0, 5), 23, *range(115, 120)]  # the panel's columns kept, of the sprite's
HOTBAR_SLOT = (5, 5, 18, 18)  # a slot's square in the sprite

# F colour rows: 0 fire, 1 violet, 2 ice, 3 poison, 4 earth, 5 steel, 6 mauve, 7 blood, 8 dark
HITS = {
    # troops
    "soldier": ("F", "Part 8/377", 5),
    "knight": ("G", "Impacts/symmetrical_impact_003/symmetrical_impact_003_small_yellow"),
    "swordsman": ("F", "Part 5/232", 5),
    "archer": ("G", "Impacts/directional_impact_001/directional_impact_001_small_blue"),
    "lancer": ("F", "Part 8/395", 5),
    "armored_axeman": ("F", "Part 5/242", 7),
    "wizard": ("G", "Explosions/stylized_explosion_002/stylized_explosion_002_small_violet"),
    "knight_templar": ("G", "Impacts/symmetrical_impact_004/symmetrical_impact_004_small_yellow"),
    # monsters
    "slime": ("F", "Part 9/428", 3),
    "bat": ("F", "Part 8/385", 1),
    "skeleton": ("F", "Part 6/273", 5),
    "orc": ("G", "Impacts/directional_impact_004/directional_impact_004_small_yellow"),
    "skeleton_archer": ("F", "Part 8/397", 5),
    "werewolf": ("F", "Part 9/447", 7),
    "armored_skeleton": ("G", "Impacts/symmetrical_impact_001/symmetrical_impact_001_small_yellow"),
    "orc_rider": ("F", "Part 5/231", 4),
    "elite_orc": ("F", "Part 7/324", 7),
    "armored_orc": ("G", "Smoke Bursts/symmetrical_smoke_burst_001/symmetrical_smoke_burst_001_small_brown"),
    "greatsword_skeleton": ("F", "Part 12/589", 5),
    "werebear": ("G", "Splatters/directional_splatter_001/directional_splatter_001_small_red"),
    "necromancer": ("G", "Smoke Bursts/stylized_skull_smoke_burst_001/stylized_skull_smoke_burst_001_large_white"),
}
UPGRADE = ("G", "Fantasy Spells/spell_attack_up_001/spell_attack_up_001_small_red")
# The loot icons: (category, number) of a single icon of "Cute Fantasy Icons Premium" (Kenmi; decisions-log 194),
# its file Cute_Fantasy_Icons_<category>/32x32/single_icons_32x32/<category>_32x32_Icon_<number>.png: the 16 px art
# doubled, as the game drew its loot icons before. The pack has no crown, scroll, banner, drum or bell, so those
# relics take the nearest thing by name and effect (docs/loot-items-relics.md "The icons"). Until decisions-log 136
# the dropped ones came from "Free - Raven Fantasy Icons" (free games only), then tool/draw_icons.py drew all 18;
# its drawings are now the public repo's placeholders for these files (tool/gen_placeholders.py). An entry may name a
# third value, a tint (r, g, b) multiplied into every pixel (decisions-log 245): a tinted variant of an icon another
# entry uses, which may then repeat that (category, number).
LOOT = {
    # Items (Item in game.dart)
    "item_sword": ("Weapons", 1),  # a steel blade, a gold guard
    "item_shield": ("Weapons", 1381),  # a round wooden shield, a steel rim
    "item_boots": ("Armor", 1783),  # a pair of leather boots
    "item_bow": ("Weapons", 1093),  # a wooden bow and its string
    "item_gloves": ("Armor", 1753),  # a leather glove
    "item_potion": ("Potions", 55),  # a round flask of red potion, corked
    "item_staff": ("Weapons", 1256),  # a wooden staff, a gold claw holding a blue orb
    # The forge's twenty items (decisions-log 245; the singles mapped first with tool/sprite_map.py, each whole in its
    # 32 px cell): grades II and III of the seven, then the helm's and the ring's three grades
    "item_steelSword": ("Weapons", 282),  # a broad steel blade
    "item_towerShield": ("Weapons", 1442),  # a tall wooden shield, a steel rim
    "item_swiftBoots": ("Armor", 1792),  # tall steel boots
    "item_longBow": ("Weapons", 1122),  # a long steel bow
    "item_steelGloves": ("Armor", 1732),  # a steel gauntlet
    "item_bigPotion": ("Potions", 263),  # a big round flask of red potion
    "item_magicStaff": ("Weapons", 1269),  # a staff, a violet crystal at its head
    "item_royalSword": ("Weapons", 284),  # a broad gold blade
    "item_royalShield": ("Weapons", 1564),  # a gold square shield, a cross
    "item_windBoots": ("Armor", 1804),  # gold winged boots
    "item_greatBow": ("Weapons", 1164),  # a heavy gold bow
    "item_royalGloves": ("Armor", 1714),  # a gold gauntlet
    "item_elixir": ("Potions", 289),  # a big round flask of orange elixir
    "item_crystalStaff": ("Weapons", 1276),  # a staff, a cyan crystal at its head
    "item_leatherCap": ("Armor", 303),  # a round leather cap
    "item_steelHelm": ("Armor", 12),  # a steel visored helm
    "item_royalHelm": ("Armor", 64),  # a gold full helm
    "item_ring": ("Resources", 513),  # a bronze ring
    "item_gemRing": ("Resources", 526),  # a cyan ring
    "item_royalRing": ("Resources", 528),  # a red ring
    # The forge's five new kinds in three grades (decisions-log 245, round 2; mapped first like the twenty): each grade
    # the same design in the pack's own bronze, steel and gold
    "item_amulet": ("Treasure&Keys", 82),  # a bronze medal, a brown gem: max HP
    "item_silverAmulet": ("Treasure&Keys", 86),  # a steel medal, a dark gem
    "item_goldAmulet": ("Treasure&Keys", 83),  # a gold medal, an amber gem
    "item_prayerBeads": ("Treasure&Keys", 122),  # three bronze beads: a healer's heals
    "item_holyBeads": ("Treasure&Keys", 121),  # three steel beads
    "item_saintBeads": ("Treasure&Keys", 123),  # three gold beads
    "item_torch": ("Tools", 542),  # a steel torch, an orange flame: damage to the undead
    "item_holyTorch": ("Tools", 543),  # a gold torch, an orange flame
    "item_sunTorch": ("Tools", 546),  # a gold torch, a violet flame
    "item_spear": ("Weapons", 663),  # a plain spear, a bronze head: melee reach
    "item_wingedSpear": ("Weapons", 672),  # a steel winged spear
    "item_royalSpear": ("Weapons", 724),  # a gold spear set with a red gem
    "item_prism": ("Resources", 43),  # a bronze crystal: splash area
    "item_arcanePrism": ("Resources", 49),  # a violet crystal
    "item_royalPrism": ("Resources", 44),  # a gold crystal
    # Relics monsters drop (droppedRelics in game.dart)
    "relic_fang": ("Monster_Drops", 55),  # a white fang: heals on every hit
    "relic_thorns": ("Weapons", 1638),  # a red shield, its rim jagged: hits back
    "relic_fury": ("Monster_Drops", 89),  # a burning skull: every third blow doubled
    "relic_guard": ("Weapons", 1626),  # a blue shield: takes less damage
    # The Smithy's seven small relics (relics.dart, decisions-log 227; the sheet mapped first: each single is its whole
    # 32 px cell of <category>_all_32x32.png)
    "relic_cleave": ("Weapons", 871),  # a steel axe on a long haft: Sweep, hits one more monster near the target
    "relic_venom": ("Weapons", 535),  # a short green blade: Venom, poisons
    "relic_manaSiphon": ("Resources", 26),  # a cyan crystal: Mana Siphon, MP on each hit or heal
    "relic_spiritWard": ("Resources", 511),  # a silver ring: Spirit Ward, a shield each wave
    "relic_lastStand": ("Monster_Drops", 81),  # a red heart: Iron Will, once a wave a heal when low
    "relic_giantSlayer": ("Weapons", 1321),  # a steel war hammer: Giant Slayer, more damage to mini bosses and the boss
    "relic_blessing": ("Treasure&Keys", 667),  # a gold cross: Holy Charm, heals on it bigger
    # The forge's nine small relics (relics.dart, decisions-log 245; mapped first, as the items above)
    "relic_chill": ("Resources", 46),  # cyan crystals: Chill, frost that slows
    "relic_sharkTooth": ("Monster_Drops", 52),  # a tooth red with blood: Shark Tooth, more on a bleeding monster
    "relic_grit": ("Weapons", 1292),  # a steel war pick: Grit, harder when hurt
    "relic_ambush": ("Weapons", 550),  # a dark dagger: Ambush, more on a held monster
    "relic_weakSpot": ("Monster_Drops", 199),  # an orange slit eye: Weak Spot, marks a monster
    "relic_hotStreak": ("Monster_Drops", 174),  # glowing embers: Hot Streak, each kill hotter
    "relic_avalanche": ("Resources", 13),  # two boulders: Avalanche, more with a crowd
    "relic_afterglow": ("Treasure&Keys", 640),  # a glowing violet vial: Afterglow, hits after a skill
    "relic_reaper": ("Tools", 408),  # a red sickle: Reaper, ends a monster near death
    # The chest's Langka Pusaka (draft.dart)
    "relic_ironBanner": ("Armor", 571),  # steel plate under a red war cloak: takes less damage
    "relic_bloodFang": ("Monster_Drops", 56),  # a fang red with blood: heals from every hit
    "relic_warDrum": ("Resources", 646),  # a red drum between wooden hoops: every third blow harder
    "relic_mourningBell": ("Treasure&Keys", 77),  # a blue tear: when one falls, those near heal
    # The chest's Legenda (pusaka.dart)
    "relic_dragonCrown": ("Armor", 324),  # a gold horned helm, a crest between the horns: no blow over 60% of HP
    "relic_oathOfOne": ("Treasure&Keys", 694),  # a gold padlock: the oath, two types at most
    "relic_alliance": ("Resources", 484),  # a gold chain: the oath of many types together
    # The Towns (lib/town_look.dart, decisions-log 216)
    "town_mark": ("Tools", 351),  # a hammer: the wave meter's "Town after wave 12" chip, the Smithy
    "town_mug": ("Food", 3),  # a mug of amber ale, its foam spilling: the wave meter in a Town (a safe time)
    # The Towns' 30 materials (Mat in lib/town.dart, decisions-log 221): each monster's Common part, its Rare part, the Trophies;
    # then the forge's two stones
    "mat_slimeGel": ("Monster_Drops", 132),  # a green slime drop: Slime Gel, the slime's Common part
    "mat_batWing": ("Monster_Drops", 108),  # a violet wing: Bat Wing, the bat's Common part
    "mat_boneShard": ("Monster_Drops", 167),  # white bone shards: Bone Shard, the skeleton's Common part
    "mat_orcTooth": ("Monster_Drops", 51),  # a white tooth: Orc Tooth, the orc's Common part
    "mat_boneArrow": ("Weapons", 1171),  # a white arrow: Bone Arrow, the skeleton archer's Common part
    "mat_wolfClaw": ("Monster_Drops", 136),  # a dark claw: Wolf Claw, the werewolf's Common part
    "mat_rustyPlate": ("Resources", 573),  # a bronze plate: Rusty Plate, the armored skeleton's Common part
    "mat_leatherStrap": ("Resources", 896),  # a leather piece: Leather Strap, the orc rider's Common part
    "mat_orcEar": ("Monster_Drops", 142),  # a green ear: Orc Ear, the veteran orc's Common part
    "mat_ironScrap": ("Resources", 572),  # a steel plate: Iron Scrap, the armored orc's Common part
    "mat_bigBone": ("Monster_Drops", 98),  # a yellow bone: Big Bone, the greatsword skeleton's Common part
    "mat_bearFur": ("Resources", 882),  # a tan fleece: Bear Fur, the werebear's Common part
    "mat_tealCloth": ("Resources", 855),  # a cyan cloth: Teal Cloth, the necro healer's Common part
    # Rare parts
    "mat_slimeCore": ("Monster_Drops", 122),  # a green ball: Slime Core, the slime's Rare part
    "mat_batFang": ("Monster_Drops", 58),  # a red fang: Bat Fang, the bat's Rare part
    "mat_skull": ("Monster_Drops", 86),  # a white skull: Skull, the skeleton's Rare part
    "mat_orcTusk": ("Monster_Drops", 147),  # a white tusk: Orc Tusk, the orc's Rare part
    "mat_boneBow": ("Weapons", 1091),  # a white bow: Bone Bow, the skeleton archer's Rare part
    "mat_wolfFang": ("Monster_Drops", 57),  # a gold fang: Wolf Fang, the werewolf's Rare part
    "mat_crackedSkull": ("Monster_Drops", 90),  # a cracked skull: Cracked Skull, the armored skeleton's Rare part
    "mat_wargFang": ("Monster_Drops", 59),  # a cracked tooth: Warg Fang, the orc rider's Rare part
    "mat_orcHeart": ("Monster_Drops", 82),  # a green heart: Orc Heart, the veteran orc's Rare part
    "mat_ironTusk": ("Monster_Drops", 148),  # a steel tusk: Iron Tusk, the armored orc's Rare part
    "mat_graveSteel": ("Resources", 150),  # a black ingot: Grave Steel, the greatsword skeleton's Rare part
    "mat_bearClaw": ("Monster_Drops", 139),  # a gold claw: Bear Claw, the werebear's Rare part
    "mat_tealGem": ("Treasure&Keys", 61),  # a cyan gem: Teal Gem, the necro healer's Rare part
    "mat_darkGem": ("Treasure&Keys", 64),  # a violet gem: Dark Gem, the necromancer's Rare part
    # Trophies
    "mat_evilEye": ("Monster_Drops", 6),  # a big red eye: Evil Eye, every mini boss
    "mat_soulOrb": ("Monster_Drops", 204),  # an orange orb, gold rim: Soul Orb, every boss
    "mat_lichOrb": ("Monster_Drops", 205),  # a violet orb, gold rim: Lich Orb, the Necromancer as a mini boss or boss
    # The forge's Enhance stones (decisions-log 245): made at the Smithy, never dropped
    "mat_mithril": ("Resources", 146),  # a cyan ingot: Mithril
    "mat_starmetal": ("Resources", 149),  # a violet ingot: Starmetal
}
# The Artifacts' (Pusaka) icons: one atlas, assets/images/artifact_icons.png, a 32 px cell each (the pack's 32 px
# icons, as LOOT), ARTIFACT_COLS a row, in this order: the catalog's 30 Langka, 30 Epik, 30 Legenda (kind = the
# Relic's name, or its catalog constant's stem for one not built yet). lib/artifact_icons.dart reads a cell by the
# same order (test/pusaka_catalog_test.dart checks the two agree). Every kind its own icon, none an item's or a
# small relic's look; rarity shows by the frame, so no tint. The seven that had a relic_<name>.png keep that icon.
ARTIFACT_COLS = 10
ARTIFACTS = [
    # Langka
    ("ironBanner", "Armor", 571),  # = relic_ironBanner
    ("bloodFang", "Monster_Drops", 56),  # = relic_bloodFang
    ("warDrum", "Resources", 646),  # = relic_warDrum
    ("mourningBell", "Treasure&Keys", 77),  # = relic_mourningBell
    ("titanBane", "Weapons", 1288),  # a red pole axe: more damage to the boss
    ("finishingBlade", "Weapons", 641),  # a steel dagger, a red gem: the last blow
    ("firstCut", "Tools", 391),  # a cleaver: the first blow
    ("shellCracker", "Tools", 1),  # a pickaxe: cracks armor
    ("momentum", "Weapons", 1181),  # a steel arrow in flight
    ("twinFury", "Weapons", 897),  # an orange double axe
    ("bleedingEdge", "Weapons", 488),  # a red curved blade: bleeds
    ("shatterShard", "Treasure&Keys", 9),  # a white gem split in two
    ("painCrystal", "Treasure&Keys", 23),  # a long red crystal
    ("steadyStance", "Armor", 1521),  # steel greaves: stands firm
    ("turtleShell", "Weapons", 1505),  # a round green shield, a cross: the shell
    ("watchShield", "Weapons", 1591),  # a silver shield
    ("boneBuckler", "Weapons", 1601),  # a small white buckler
    ("dullingMail", "Armor", 1041),  # steel plate with shoulders
    ("challengeLetter", "Resources", 851),  # a white sheet: the letter
    ("riposte", "Weapons", 272),  # a steel rapier, a ring guard: the fencer's answer
    ("saltCharm", "Resources", 41),  # white crystals: salt
    ("wolfFeast", "Farming", 145),  # a raw steak
    ("fullCup", "Food", 1),  # a full mug
    ("hiddenFlask", "Potions", 118),  # a slim green vial
    ("livingMoss", "Monster_Drops", 162),  # a green clump of moss
    ("pureWater", "Tools", 481),  # a bucket of clear water
    ("manaLeech", "Monster_Drops", 158),  # a blue-grey grub
    ("lootersPouch", "Treasure&Keys", 139),  # a pile of gold coins
    ("spellCutter", "Tools", 421),  # scissors: cuts a spell
    ("snareCord", "Resources", 631),  # a ball of cord
    # Epik
    ("grail", "Treasure&Keys", 627),  # a gold chalice
    ("dragonHeart", "Monster_Drops", 91),  # a dark red heart
    ("voidEye", "Monster_Drops", 200),  # a purple slit eye
    ("godThunder", "Weapons", 1334),  # a gold hammer
    ("dawnStar", "Weapons", 1274),  # a gold morning star
    ("healerBane", "Tools", 410),  # a dark sickle
    ("bullyClub", "Weapons", 1253),  # a wooden club
    ("emberBrand", "Monster_Drops", 119),  # a glowing ember
    ("funeralPyre", "Tools", 541),  # a burning torch
    ("unityRing", "Resources", 514),  # a gold ring
    ("runeGauntlet", "Resources", 109),  # a rock veined with violet runes
    ("hawkFeather", "Monster_Drops", 11),  # a brown feather
    ("nullStone", "Treasure&Keys", 54),  # a dark round stone, a grey rim: takes good effects away
    ("fallenFlag", "Resources", 856),  # a red cloth hanging
    ("manaHymn", "Treasure&Keys", 669),  # a blue cross: a hymn that gives MP
    ("witherroot", "Resources", 932),  # a grey dead twig
    ("aegisSeal", "Weapons", 1514),  # a round gold shield, a shining cross: the seal
    ("arrowCatcher", "Tools", 461),  # a net
    ("wardensHorn", "Monster_Drops", 149),  # a gold horn
    ("stoneCoat", "Resources", 1),  # grey rocks
    ("anchor", "Resources", 491),  # a steel hook
    ("heroCloak", "Armor", 1421),  # a red cape, a steel collar
    ("saintTear", "Treasure&Keys", 73),  # a white tear
    ("braveSong", "Monster_Drops", 36),  # a red plume: courage
    ("haloLantern", "Treasure&Keys", 643),  # a gold oil lamp
    ("hearth", "Food", 6),  # a bowl of hot soup
    ("heartbeat", "Monster_Drops", 92),  # a green heart: heals
    ("mercyLily", "Farming", 49),  # a white flower
    ("brightSpring", "Farming", 29),  # a green sprout
    ("moonwell", "Treasure&Keys", 81),  # a pale pearl like a moon
    # Legenda
    ("dragonCrown", "Armor", 324),  # = relic_dragonCrown
    ("oathOfOne", "Treasure&Keys", 694),  # = relic_oathOfOne
    ("alliance", "Resources", 484),  # = relic_alliance
    ("fewOath", "Treasure&Keys", 684),  # a small green padlock: the few
    ("wallOath", "Treasure&Keys", 689),  # a big steel padlock
    ("bloodOath", "Treasure&Keys", 695),  # a red padlock
    ("vanguardOath", "Treasure&Keys", 690),  # a bronze padlock
    ("kingsOath", "Treasure&Keys", 701),  # a royal blue padlock, a gold shackle
    ("spellOath", "Treasure&Keys", 696),  # a violet padlock
    ("loneWolf", "Resources", 881),  # a tuft of grey wolf fur
    ("martyrFlame", "Tools", 548),  # a torch of blue flame
    ("wideBlows", "Weapons", 511),  # a wide white scimitar
    ("champion", "Armor", 1432),  # a long gold mantle
    ("rageTotem", "Armor", 178),  # a red tusked beast helm
    ("vengeance", "Monster_Drops", 196),  # a red slit eye: the mark
    ("mirror", "Weapons", 1581),  # a silver round shield
    ("guardianChain", "Resources", 471),  # a steel chain and hook
    ("ghostStep", "Monster_Drops", 21),  # a white feather
    ("phalanx", "Weapons", 1541),  # a steel square shield, a cross
    ("vampireKiss", "Monster_Drops", 109),  # a dark bat wing
    ("wrathPsalm", "Treasure&Keys", 671),  # a red cross
    ("phoenix", "Monster_Drops", 186),  # a wing of fire
    ("soulShelter", "Monster_Drops", 203),  # a blue soul orb in a ring: shelter
    ("manaFont", "Treasure&Keys", 637),  # a blue ewer: a font of MP
    ("iceGrip", "Treasure&Keys", 5),  # a blue ice gem
    ("graveSeal", "Monster_Drops", 96),  # a white bone
    ("relicAltar", "Resources", 891),  # a stone pillar: the altar
    ("hexBlade", "Weapons", 659),  # a violet dagger
    ("vowSilence", "Treasure&Keys", 681),  # a small steel padlock: no skills
    ("glorySeeker", "Treasure&Keys", 91),  # a gold medal
]


def crop(px, w, x, y, cw, ch):
    return b"".join(bytes(px[((y + r) * w + x) * 4:((y + r) * w + x + cw) * 4]) for r in range(ch))


def tooltip():
    fw, _, fpx = read_png(FRAMES)
    x, _, w, h = TIP_BODY
    body = bytearray(crop(fpx, fw, *TIP_BODY))
    for r in range(h - 5, h):  # the lip: the pointer's columns take the plain column's pixels
        for cx in range(TIP_DOWN[0] - x, TIP_DOWN[0] - x + TIP_DOWN[2]):
            p = (r * w + TIP_PLAIN - x) * 4
            body[(r * w + cx) * 4:(r * w + cx + 1) * 4] = body[p:p + 4]
    sw = w + TIP_DOWN[2] + TIP_SIDE[2]
    sheet = bytearray(sw * h * 4)
    for at, (pw, ph, px) in [(0, (w, h, body)), (w, (*TIP_DOWN[2:], crop(fpx, fw, *TIP_DOWN))),
                             (w + TIP_DOWN[2], (*TIP_SIDE[2:], crop(fpx, fw, *TIP_SIDE)))]:
        for r in range(ph):
            sheet[(r * sw + at) * 4:(r * sw + at + pw) * 4] = px[r * pw * 4:(r + 1) * pw * 4]
    write_png(OUT / "ui_tooltip.png", sw, h, bytes(sheet))


def buttons():
    w, _, px = read_png(BUTTONS[0])
    write_png(OUT / "ui_buttons.png", BUTTONS[1][2], BUTTONS[1][3], crop(px, w, *BUTTONS[1]))


def hotbar():
    src = HOTBAR[0]
    if not src.exists():  # raw_assets/ is the main checkout's (not in git): a worktree reads it there
        main = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--path-format=absolute", "--git-common-dir"],
                              capture_output=True, text=True, check=True).stdout.strip()
        src = Path(main).parent / src.relative_to(ROOT)
    w, _, px = read_png(src)
    hx, hy, hw, hh = HOTBAR[1]
    sprite = crop(px, w, hx, hy, hw, hh)
    sw = len(HOTBAR_COLS) + 1 + HOTBAR_SLOT[2]
    sheet = bytearray(sw * hh * 4)
    for r in range(hh):
        for i, cx in enumerate(HOTBAR_COLS):
            sheet[(r * sw + i) * 4:(r * sw + i + 1) * 4] = sprite[(r * hw + cx) * 4:(r * hw + cx + 1) * 4]
    sx, sy, s_w, s_h = HOTBAR_SLOT
    at = len(HOTBAR_COLS) + 1
    for r in range(s_h):
        sheet[(r * sw + at) * 4:(r * sw + at + s_w) * 4] = sprite[((sy + r) * hw + sx) * 4:((sy + r) * hw + sx + s_w) * 4]
    write_png(OUT / "ui_hotbar.png", sw, hh, bytes(sheet))


if sys.argv[1:] == ["hotbar"]:  # just the hotbar
    hotbar()
    sys.exit()
if sys.argv[1:] == ["tooltip"]:  # just the tooltip frame (the other packs may not be here)
    tooltip()
    sys.exit()
if sys.argv[1:] == ["ribbons"]:  # just the ribbons, likewise
    shutil.copyfile(RIBBONS, OUT / "ui_ribbons.png")
    sys.exit()
if sys.argv[1:] == ["buttons"]:  # just the buttons
    buttons()
    sys.exit()


def icon32(pack, cat, n):
    """The pack's 32 px single icon (category, number), checked."""
    src = pack / f"Cute_Fantasy_Icons_{cat}/32x32/single_icons_32x32/{cat}_32x32_Icon_{n}.png"
    if not src.is_file():
        sys.exit(f"{src}: not found (give the folder the pack's zip unpacks to)")
    if read_png(src)[:2] != (32, 32):
        sys.exit(f"{src}: not 32x32")
    return src


def tinted(px, rgb):
    """[px] (RGBA bytes) with every pixel's colour multiplied by [rgb] (0-255 each), its alpha kept."""
    out = bytearray(px)
    for i in range(0, len(out), 4):
        for c in range(3):
            out[i + c] = out[i + c] * rgb[c] // 255
    return bytes(out)


def loot(pack, out):
    """Copies LOOT's icons from the unpacked pack [pack] into [out] and writes the Artifacts' atlas there: every file
    checked first, so a missing or misshapen one writes nothing."""
    files = {name: (icon32(pack, cat, n), tint) for name, (cat, n, *tint) in LOOT.items()}
    plain = [(cat, n) for cat, n, *tint in LOOT.values() if not tint]
    if len(set(plain)) != len(plain):
        sys.exit("LOOT: an icon twice (only a tinted entry may repeat one)")
    arts = [icon32(pack, cat, n) for _, cat, n in ARTIFACTS]
    keys = [kind for kind, _, _ in ARTIFACTS]
    if len(set(keys)) != len(keys) or len({(c, n) for _, c, n in ARTIFACTS}) != len(keys):
        sys.exit("ARTIFACTS: a kind or an icon twice")
    for kind, cat, n in ARTIFACTS:  # an item's or a small relic's icon: only a Pusaka's own relic_<kind> may repeat
        if any(icon == (cat, n) and name != f"relic_{kind}" for name, icon in LOOT.items()):
            sys.exit(f"ARTIFACTS: {kind} draws a loot icon")
    out.mkdir(parents=True, exist_ok=True)
    for name, (src, tint) in files.items():
        if tint:
            write_png(out / f"{name}.png", 32, 32, tinted(read_png(src)[2], tint[0]))
        else:
            shutil.copyfile(src, out / f"{name}.png")
    w, h = ARTIFACT_COLS * 32, -(-len(arts) // ARTIFACT_COLS) * 32
    sheet = bytearray(w * h * 4)
    for i, src in enumerate(arts):
        px, x, y = read_png(src)[2], i % ARTIFACT_COLS * 32, i // ARTIFACT_COLS * 32
        for r in range(32):
            sheet[((y + r) * w + x) * 4:((y + r) * w + x + 32) * 4] = px[r * 128:(r + 1) * 128]
    write_png(out / "artifact_icons.png", w, h, bytes(sheet))
    print(len(files), "loot icons and", len(arts), "Artifact icons (artifact_icons.png) into", out)


if sys.argv[1:2] == ["icons"]:  # just the icons, from the bought pack (never in raw_assets/)
    args = sys.argv[2:]
    if len(args) not in (1, 3) or (len(args) == 3 and args[1] != "--out"):
        sys.exit("python3 tool/import_fx.py icons <the unpacked pack> [--out DIR]")
    loot(Path(args[0]).expanduser(), Path(args[2]) if len(args) == 3 else OUT)
    sys.exit()


def effect(spec, out):
    if spec[0] == "G":
        shutil.copyfile(G / spec[1] / "spritesheet.png", out)
        return
    _, part, row = spec
    w, h, px = read_png(F / f"{part}.png")
    write_png(out, w, 64, crop(px, w, 0, row * 64, w, 64))


for who, spec in HITS.items():
    effect(spec, OUT / f"fx_hit_{who}.png")
effect(UPGRADE, OUT / "fx_upgrade.png")
bw, _, bpx = read_png(BOOK[0])
write_png(OUT / "ui_book.png", BOOK[1][2], BOOK[1][3], crop(bpx, bw, *BOOK[1]))
write_png(OUT / "ui_book_marks.png", BOOK_MARKS[1][2], BOOK_MARKS[1][3], crop(bpx, bw, *BOOK_MARKS[1]))
shutil.copyfile(BARS, OUT / "ui_bars.png")
UI = ROOT / "raw_assets/Cute_Fantasy_UI/UI"
shutil.copyfile(UI / "UI_Icons.png", OUT / "ui_icons.png")  # cursors (y 224), book icons (y 16), 16px cells
shutil.copyfile(UI / "Loading_Icon.png", OUT / "ui_loading.png")  # row 0: 16 frames of 16px
shutil.copyfile(UI / "Pointer_Click_Anim.png", OUT / "ui_click.png")  # 4 frames of 16px
aw, _, apx = read_png(UI_ALL[0])
write_png(OUT / "ui_all.png", UI_ALL[1][2], UI_ALL[1][3], crop(apx, aw, *UI_ALL[1]))
tooltip()
shutil.copyfile(RIBBONS, OUT / "ui_ribbons.png")
buttons()
hotbar()
print(len(HITS), "hit effects, 1 upgrade effect (loot icons: python3 tool/import_fx.py icons <pack>)")
