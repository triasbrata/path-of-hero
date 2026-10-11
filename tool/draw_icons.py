"""The public repo's placeholder loot icons: 16 px art with a dark outline, doubled to 32x32 (decisions-log 136, 194).
The game's own loot icons, item_<name>.png for every Item and relic_<name>.png for the dropped relics and the chest's
Langka and Legenda Pusaka, are Kenmi's "Cute Fantasy Icons Premium" since decisions-log 194 (tool/import_fx.py LOOT):
a bought pack, so a public repo can't hold them. tool/gen_placeholders.py draws these in their place (the manifest's
kind "icon"). They are the icons the game showed from decisions-log 136 to 194: drawn here from scratch when the six
items and four relics from "Free - Raven Fantasy Icons" (free games only) had to go, the staff and the Pusaka in the
same style.

Add an icon: one ICONS entry, 16 rows of 16 PALETTE keys ("." is clear, "o" the outline, the light from the
top left). A new colour is one more PALETTE key. A licensed icon without an entry gets a plain placeholder.
Stdlib only:  python3 tool/draw_icons.py --out DIR [name ...]   (to look at them; never into assets/images, where
the real icons are: tool/gen_placeholders.py writes a public clone's)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from build_atlas import write_png  # noqa: E402

ASSETS = Path(__file__).resolve().parent.parent / "assets/images"

PALETTE = {
    ".": (0, 0, 0, 0),
    "o": (0x2B, 0x1D, 0x2B, 255),  # outline
    "h": (0xFF, 0xFF, 0xFF, 255),  # shine
    "s": (0xC8, 0xF4, 0xFF, 255),  # sparkle
    # wood, and leather
    "l": (0xD0, 0x8E, 0x4E, 255),  # lit
    "w": (0x96, 0x55, 0x2C, 255),
    "d": (0x5E, 0x34, 0x20, 255),  # grain, shade
    # tan leather
    "t": (0xEB, 0xC4, 0x8C, 255),  # lit
    "T": (0xC9, 0x91, 0x58, 255),
    "u": (0x8E, 0x5A, 0x33, 255),  # shade
    # gold
    "Y": (0xFF, 0xD8, 0x6A, 255),  # lit
    "y": (0xE0, 0x9A, 0x22, 255),
    "g": (0xA8, 0x5E, 0x18, 255),  # shade
    # steel
    "L": (0xE4, 0xEC, 0xF2, 255),  # lit
    "m": (0xA3, 0xB1, 0xC2, 255),
    "n": (0x66, 0x71, 0x8A, 255),  # shade
    # red (blood, cloth, the thorns shield)
    "R": (0xFF, 0x7A, 0x6A, 255),  # lit
    "r": (0xD8, 0x32, 0x3A, 255),
    "e": (0x8C, 0x1C, 0x30, 255),  # shade
    # blue (the staff's gem, the guard shield)
    "c": (0x9E, 0xE8, 0xFF, 255),  # lit
    "b": (0x4D, 0xA6, 0xFF, 255),
    "B": (0x2B, 0x5B, 0xC8, 255),  # shade
    "v": (0x6A, 0x4B, 0xD8, 255),  # violet shade
    # bone
    "i": (0xF2, 0xE8, 0xD2, 255),
    "j": (0xBF, 0xAE, 0x8E, 255),  # shade
    # fire
    "f": (0xFF, 0x8C, 0x2A, 255),
    "F": (0xE0, 0x46, 0x1E, 255),  # deep
    # glass
    "G": (0xC8, 0xDC, 0xEC, 255),
}

ICONS = {
    # Items (Item in game.dart)
    "item_sword": [  # a steel blade, a gold guard and pommel, a leather grip
        ".............ooo",
        "............ooLo",
        "...........ooLmo",
        "..........ooLmno",
        ".........ooLmnoo",
        "........ooLmnoo.",
        "....oooooLmnoo..",
        "....oYooLmnoo...",
        "....oyYLmnoo....",
        "....ooyYooo.....",
        "...oowdyYoo.....",
        "..oowdoogyo.....",
        "ooowdoooooo.....",
        "oYyooo..........",
        "oygo............",
        "oooo............",
    ],
    "item_shield": [  # a round wooden shield: steel rim and boss
        "....oooooooo....",
        "...ooLLLLLLoo...",
        "..ooLLLllLmmoo..",
        ".ooLLdlllldmmoo.",
        "ooLLldlllwdwmmoo",
        "oLLlldllwwdwwmno",
        "oLLlldlmmwdwwnno",
        "oLllldmhmmdwwwno",
        "oLllldmmnmdwwwno",
        "oLLlwdwmmwdwwnno",
        "oLmwwdwwwwdwwnno",
        "oommwdwwwwdwnnoo",
        ".oommdwwwwdnnoo.",
        "..oommnwwnnnoo..",
        "...oonnnnnnoo...",
        "....oooooooo....",
    ],
    "item_boots": [  # a leather boot: a tan cuff, a gold strap, a heel
        "..ooooooooo.....",
        "..ottttttto.....",
        "..oTTTTTTTo.....",
        "..oolwwwdoo.....",
        "...olwwwdo......",
        "...olwwwdo......",
        "...ogYyggo......",
        "...olwwwdo......",
        "...olwwwdooo....",
        "...olwwwwllooo..",
        "...olwwwwwllwoo.",
        "...olwwwwwwwwwo.",
        "...oddddddddddo.",
        "...odddoooooooo.",
        "...ooooo........",
        "................",
    ],
    "item_bow": [  # a wooden bow, a red grip, gold tips, its string
        ".....oooooooooo.",
        "...ooollllllyyo.",
        "..ooRllwwwwwyyo.",
        ".ooRRwwoooooioo.",
        ".oRReooo.ooioo..",
        "oolwoo..ooioo...",
        "ollwo..ooioo....",
        "olwoo.ooioo.....",
        "olwo.ooioo......",
        "olwoooioo.......",
        "olwooioo........",
        "olwoioo.........",
        "oyyioo..........",
        "oyyoo...........",
        "oooo............",
        "................",
    ],
    "item_gloves": [  # a tan leather glove, a red cuff with gold studs
        "................",
        "......ooooooo...",
        "......otTotTo...",
        "...ooootTotToooo",
        "ooootTotTotTotTo",
        "ottotTotTotTotTo",
        "ottotTTTTTTTuuuo",
        "otTotTTTTTTTuuuo",
        "ootttTTTTTTTuuuo",
        ".ooTtTTTTTTTuuuo",
        "..ottTTTTTTTuuuo",
        "..oRRRRRRRRRRRRo",
        "..orryryryryryeo",
        "..orrrrrrrrrrreo",
        "..oeeeeeeeeeeeeo",
        "..oooooooooooooo",
    ],
    "item_potion": [  # a round flask of red potion, corked
        ".....oooooo.....",
        ".....ollwwo.....",
        ".....ollwwo.....",
        ".....oGGGGo.....",
        "....ooGGGGoo....",
        "...ooGGGGGGoo...",
        "..ooGGhGGGGGoo..",
        "..oGGhGGGGGGGo..",
        "..oRhRRRRRRRRo..",
        "..orhrrrrrrreo..",
        "..orrRrrrrreeo..",
        "..orrrrrrreeeo..",
        "..orrrrrreeeeo..",
        "..oorrrreeeeoo..",
        "...oorreeeeoo...",
        "....oooooooo....",
    ],
    "item_staff": [  # the magic staff (Tongkat Sihir): wood, a gold claw holding a glowing gem
        ".........ooooo..",
        "........oobbvoos",
        "......s.obbhbvo.",
        ".......oobhcbvo.",
        ".......oyvbbvvo.",
        ".......oyYvvvvo.",
        ".......ooyyoooo.",
        "......oolyoo....",
        ".....oolwoo.....",
        "....oolwoo......",
        "...ooldoo.....s.",
        "..oolwoo........",
        ".oolwoo.........",
        "ooldoo..........",
        "oyYoo...........",
        "oyoo............",
    ],
    # Relics monsters drop (droppedRelics in game.dart)
    "relic_fang": [  # a drop of blood: heals on every hit
        ".......oo.......",
        "......orro......",
        ".....orrreo.....",
        ".....orrreo.....",
        "....orrrrreo....",
        "...oorrrrreoo...",
        "...orRRrrrreo...",
        "..ooRRhRrrreoo..",
        "..orRhRRRrrreo..",
        "..orRhRRRrrreo..",
        "..orRRRRrrrreo..",
        "..orrRRrrrreeo..",
        "..oorrrrrreeoo..",
        "...oorrrreeoo...",
        "....ooreeeoo....",
        ".....oooooo.....",
    ],
    "relic_thorns": [  # a red shield with a spiked rim and a steel boss: hits back
        "................",
        ".....o....o.....",
        "..oooeooooeooo..",
        "..oRRRrrrreeeo..",
        ".oeRRRrrrreeeeo.",
        "..oRRRrrrreeeo..",
        "..oRRRrLmreeeo..",
        "..oRRRLhmneeeo..",
        ".oeRRRmmnneeeeo.",
        "..oRRRrnnreeeo..",
        "..ooRRrrrreeoo..",
        "...ooRrrrreoo...",
        "...oeRrrrreeo...",
        "....oorrrroo....",
        ".....oorroo.....",
        "......oooo......",
    ],
    "relic_fury": [  # a burning skull: every third blow doubled
        "...oooofooooo...",
        "...ofooffooFo...",
        "..oofooffofFoo..",
        "..oYYYoYYoYYYo..",
        "..oYYYYYYYYYYo..",
        "..ooiiiiiiiioo..",
        "..oiiiiiiiijjo..",
        "..oiiiiiiijjjo..",
        "..oiiYFiiYFjjo..",
        "..oiiFfijFfjjo..",
        "..oiiiijjjjjjo..",
        "..oiiijoojjjjo..",
        "..ooiiiiiiijoo..",
        "...oojojojjoo...",
        "....oooooooo....",
        "................",
    ],
    "relic_guard": [  # a blue shield with a gold cross: takes less damage
        "................",
        ".oooooooooooooo.",
        ".occcccbbbbBBBo.",
        ".occcccbbbbBBBo.",
        ".occcccYybbBBBo.",
        ".occcccYybbBBBo.",
        ".occYYYYyyyyBBo.",
        ".occcccYybbBBBo.",
        ".occcccYybbBBBo.",
        ".ooccccYybbBBoo.",
        "..oocccYybbBoo..",
        "...occcYybbBo...",
        "...ooccbbbboo...",
        "....oocbbboo....",
        ".....oobboo.....",
        "......oooo......",
    ],
    # The chest's Langka Pusaka (draft.dart): bound to a troop type, never dropped
    "relic_ironBanner": [  # a red war banner on a steel pole, an iron boss on it: takes less damage
        "..ooo...........",
        "..oYo...........",
        "..oyoooooooooo..",
        "..oLoRRrrrrreo..",
        "..oLoRrrLLrreo..",
        "..oLoRrLhmnreo..",
        "..omoRrLmmnreo..",
        "..omoRrrmnreeo..",
        "..omoRrrrrreeo..",
        "..omoRrrrrreeo..",
        "..omorreooreeo..",
        "..omoeeo..oeeo..",
        "..omooo....ooo..",
        "..omo...........",
        "..ono...........",
        "..ooo...........",
    ],
    "relic_bloodFang": [  # a white fang dripping blood: heals from every hit
        "........oooo....",
        ".......oiiijo...",
        "......oiiiijo...",
        "......oiihijo...",
        ".....oiihiijo...",
        ".....oiiiijjo...",
        ".....oiiiijo....",
        "....oiiiijjo....",
        "....oiiijjo.....",
        "....oiijjoo.....",
        "....orijo.......",
        "...oRroo........",
        "...orreo........",
        "..oRrreo........",
        "..orreeo........",
        "...oooo.........",
    ],
    "relic_warDrum": [  # a war drum, its two sticks over it: every third blow harder
        "..oo........oo..",
        "..oyo......oyo..",
        "...owo....owo...",
        "....owo..owo....",
        ".....owoowo.....",
        "..oooooooooooo..",
        ".ottttttttttTTo.",
        ".oTTttttttTTTuo.",
        ".oooooooooooooo.",
        ".oYyyyyyyyyyygo.",
        ".orllwwrrwwddro.",
        ".olrlwrwwrwdrdo.",
        ".ollrrwwwwrrddo.",
        ".oyyyyyyyyygggo.",
        ".oooooooooooooo.",
        "................",
    ],
    "relic_mourningBell": [  # a gold bell and its clapper: tolls when one falls, healing those near
        "......oooo......",
        "......oYgo......",
        ".....ooyyoo.....",
        "....oYYyyygo....",
        "...oYhYyyyygo...",
        "...oYhYyyyygo...",
        "...oYYyyyyygo...",
        "...oYYyyyyygo...",
        "..oYYyyyyyyggo..",
        "..oYyyyyyyyggo..",
        ".oYYyyyyyyyyggo.",
        ".oyyyyyyyyyyggo.",
        ".oooooooooooooo.",
        "......oLmo......",
        "......onno......",
        ".......oo.......",
    ],
    # The chest's Legenda (pusaka.dart): from wave 20, each once a run
    "relic_dragonCrown": [  # a gold crown, a red gem on top: no blow takes more than 60% of the HP
        "................",
        "................",
        ".......oo.......",
        ".o....oRro....o.",
        "oYo...oreo...oYo",
        "oyo..oooooo..oyo",
        "oyyooYYyyyyoogyo",
        "oyYyYyyyyyyyyggo",
        "oyYyyyyyyyyyyggo",
        "oYyyyyyyyyyyyggo",
        "oooooooooooooooo",
        "oYyRryycbyyRrygo",
        "oyyreyyBByyreggo",
        "oggggggggggggggo",
        "oooooooooooooooo",
        "................",
    ],
    "relic_oathOfOne": [  # a scroll sealed in red wax: the oath, two types at most
        "................",
        "..oooooooooooo..",
        ".oijjjjjjjjjjjo.",
        ".oooooooooooooo.",
        "..oiiiiiiiiijo..",
        "..oiooooooojjo..",
        "..oiiiiiiiijjo..",
        "..oiooooojjjjo..",
        "..oiiiiiiijjjo..",
        "..oioooooojooo..",
        "..oiiiiiijooRRo.",
        ".oooooooooRhrreo",
        ".oijjjjjjjoRrreo",
        ".ooooooooooerreo",
        "............eeo.",
        "............oo..",
    ],
    "relic_alliance": [  # two swords crossed: the oath of many types together
        ".oo..........oo.",
        "oLho........ohLo",
        ".oLmo......omLo.",
        "..oLmo....omLo..",
        "...oLmo..omLo...",
        "....oLmoomLo....",
        ".....oLmmLo.....",
        "...o..oLmo..o...",
        "..oYoomLLmooYo..",
        "...oymLooLmyo...",
        "....oYo..oYo....",
        "...owoyooyowo...",
        ".oodo.oggo.odoo.",
        "ogYo...oo...oYgo",
        "oggo........oggo",
        ".oo..........oo.",
    ],
    # The Towns (lib/town_look.dart)
    "town_mark": [  # a steel hammer on a wooden handle: a Town marked, the Smithy
        "..........oo....",
        ".........oLLo...",
        "........oLLmmo..",
        ".......oLLmmmno.",
        "......oLmmmmnno.",
        ".....oommmmnno..",
        "....olwonmnno...",
        "...olwdoonno....",
        "..olwdo..oo.....",
        ".olwdo..........",
        "olwdo...........",
        "owdo............",
        "odo.............",
        "oo..............",
        "................",
        "................",
    ],
    "town_mug": [  # a wooden mug of beer, its foam spilling over: the wave meter in a Town
        "................",
        "...oooooooo.....",
        "..ohhhhhhhho....",
        ".ohhhhhhhhhho...",
        ".ohhYhhhhYhhooo.",
        ".oyhYyhhYyyowwo.",
        ".oYyyyyyyyyoo.wo",
        ".oYyyyyyyygo..wo",
        ".oYyyyyyyygo..wo",
        ".oYyyyyyyygo..wo",
        ".oYYyyyyyggoowo.",
        ".oYYyyyyyggowwo.",
        ".omLmmmmmnnooo..",
        ".oommmmmnnno....",
        "..oooooooooo....",
        "................",
    ],
}


def pixels(art):
    """The 32x32 RGBA bytes of a 16x16 ASCII icon, each pixel doubled across and down."""
    assert len(art) == 16 and all(len(row) == 16 for row in art), "an icon is 16 rows of 16"
    px = bytearray()
    for row in art:
        line = b"".join(bytes(PALETTE[ch]) * 2 for ch in row)
        px += line * 2
    return bytes(px)


def main(args):
    if args[:1] != ["--out"] or len(args) < 2:
        sys.exit(__doc__)
    out, names = Path(args[1]), args[2:] or list(ICONS)
    if out.resolve() == ASSETS.resolve():
        sys.exit("refused: assets/images holds the game's real loot icons (tool/import_fx.py icons)")
    out.mkdir(parents=True, exist_ok=True)
    for name in names:
        write_png(out / f"{name}.png", 32, 32, pixels(ICONS[name]))
    print(len(names), "drawn icons into", out)


if __name__ == "__main__":
    main(sys.argv[1:])
