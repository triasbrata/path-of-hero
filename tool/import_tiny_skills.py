"""Copies the Tiny RPG pack's skill strips into assets/images (decisions-log 299): the attack 2 / attack 3 strips (and a
few others) that the troops', Heroes' and monsters' skill casts play (lib/skill_strips.dart; docs/assets.md "Packs →
files", docs/units-and-combat.md "Skill strips"). And the Wizard's two magic effect sheets (decisions-log 313): its
plain shot's fireball and Arcane Blast's ice shards (lib/wizard_fx.dart; docs/units-and-combat.md "The wizard's
magic").

The pack's other strips came in long ago, one attack strip a character (tool/split_shadows.py); these are the ones it
left out. Each file is the pack's plain strip ("<Char>/<Char>/", not "<Char> with shadows/"), byte for byte: 100x100
frames facing right, feet on row 59, like every tiny_* strip. The Soldier's keep the shadow the pack bakes into all its
strips (the game clears it in memory, as for its others). The magic sheets are the pack's "<Char>/Magic(projectile)/"
files, byte for byte, named for what they show (tiny_fx_wizard_<look>.png).

Stdlib only:  python3 tool/import_tiny_skills.py [--pack DIR] [--check]
(--pack: the unpacked pack's "Characters(100x100 split)" folder, by default the one under the pack's root in
tool/asset_packs/index.json, slug SLUG, where the asset vault unpacks it; --check writes nothing and exits 1 naming each
file that is missing or differs from the pack's.)
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IMAGES = ROOT / "assets/images"
INDEX = ROOT / "tool/asset_packs/index.json"  # the packs' metadata: where each one is (docs/assets.md "Asset packs")
SLUG = "tiny-rpg-character-pack-01"
SPLIT = "Characters(100x100 split)"

# tiny_<key>_<anim>.png <- <Char>/<Char>/<Char>_<file>.png. attack2 / attack3 are the pack's Attack02 / Attack03 (the
# Swordsman's third is named "Attack3"); the priest's attack2 is the pack's Attack (its game "attack" is its Heal).
STRIPS = [
    ("soldier", "Soldier", {"attack2": "Attack02"}),
    ("knight", "Knight", {"attack2": "Attack02", "attack3": "Attack03"}),
    ("swordsman", "Swordsman", {"attack2": "Attack02", "attack3": "Attack3"}),
    ("archer", "Archer", {"attack2": "Attack02"}),
    ("lancer", "Lancer", {"attack2": "Attack02", "attack3": "Attack03"}),
    ("priest", "Priest", {"attack2": "Attack"}),
    ("armored_axeman", "Armored Axeman", {"attack2": "Attack02", "attack3": "Attack03"}),
    ("wizard", "Wizard", {"attack2": "Attack02"}),
    ("knight_templar", "Knight Templar", {"attack2": "Attack02", "attack3": "Attack03"}),
    ("slime", "Slime", {"attack2": "Attack02"}),
    ("bat", "Bat", {"attack2": "Attack02"}),
    ("skeleton", "Skeleton", {"attack2": "Attack02", "block": "Block"}),
    ("orc", "Orc", {"attack2": "Attack02"}),
    ("werewolf", "Werewolf", {"attack2": "Attack02"}),
    ("armored_skeleton", "Armored Skeleton", {"attack2": "Attack02"}),
    ("orc_rider", "Orc rider", {"attack2": "Attack02", "attack3": "Attack03"}),
    ("elite_orc", "Elite Orc", {"attack2": "Attack02", "attack3": "Attack03"}),
    ("armored_orc", "Armored Orc", {"attack3": "Attack03"}),
    ("greatsword_skeleton", "Greatsword Skeleton", {"attack2": "Attack02", "attack3": "Attack03"}),
    ("werebear", "Werebear", {"attack2": "Attack02", "attack3": "Attack03"}),
    ("necromancer", "Necromancer", {"attack2": "Attack02"}),
]


# tiny_fx_<key>_<look>.png <- <Char>/Magic(projectile)/<file>.png. The pack's names say which attack strip each goes
# with, not what it shows: its Attack01 effect is the ice shards, its Attack02 effect the fireball.
MAGIC = [
    ("wizard", "Wizard", {"fireball": "Wizard_Attack02_Effect", "shards": "Wizard_Attack01_Effect"}),
]


def pairs(pack):
    for key, char, anims in STRIPS:
        for anim, name in anims.items():
            yield pack / char / char / f"{char}_{name}.png", IMAGES / f"tiny_{key}_{anim}.png"
    for key, char, looks in MAGIC:
        for look, name in looks.items():
            yield pack / char / "Magic(projectile)" / f"{name}.png", IMAGES / f"tiny_fx_{key}_{look}.png"


def pack_home():
    """The pack's root by its index.json entry (a bought pack lives outside every checkout, decisions-log 157), or None."""
    try:
        packs = json.loads(INDEX.read_text())["packs"]
    except (OSError, ValueError, KeyError):
        return None
    root = next((p["root"] for p in packs if p.get("slug") == SLUG), None)
    return Path(root).expanduser() if root else None


def main(args):
    pack, check = None, False
    while args:
        if args[0] == "--pack" and len(args) > 1:
            pack, args = Path(args[1]).expanduser(), args[2:]
        elif args[0] == "--check":
            check, args = True, args[1:]
        else:
            sys.exit(__doc__)
    home = pack_home()
    pack = pack or (home / SPLIT if home else None)
    if pack is None:
        sys.exit(f"where is the pack? give its \"{SPLIT}\" folder with --pack DIR")
    if not pack.is_dir():
        sys.exit(f"{pack}: not found (give the pack's \"{SPLIT}\" folder with --pack DIR)")
    bad = []
    for src, out in pairs(pack):
        if not src.is_file():
            sys.exit(f"{src}: not in the pack")
        data = src.read_bytes()
        if check:
            if not out.is_file() or out.read_bytes() != data:
                bad.append(out.relative_to(ROOT).as_posix())
        elif not out.is_file() or out.read_bytes() != data:
            out.write_bytes(data)
            print("wrote", out.relative_to(ROOT).as_posix())
    if bad:
        sys.exit("differs from the pack: " + ", ".join(bad))


if __name__ == "__main__":
    main(sys.argv[1:])
