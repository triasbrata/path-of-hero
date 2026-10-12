// The forge's five new item kinds (decisions-log 251; docs/loot-items-relics.md "The forge"): the Amulet's max HP, the
// Prayer Beads' heals (and a healer's holy damage on the undead), the Torch's blows on the undead (the one new step in
// Game._hurt), the Spear's melee reach and reach cap up to their ceiling (town.json `items.spear.reachMost`), the Prism's
// splash (only a type with splash) up to its ceiling (`items.prism.splashMost`). Each at its three grades from town.json `items`,
// stacked by count, in every game (the forge's own switch went in decisions-log 296, the Towns' in 321).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// A board game (the Towns, and with them the forge, on).
Game board() => Game(Random(1), Random(2))..boardRules();

/// A [bareGame] with no skills of any kind: what happens is the items' doing.
Game field() => bareGame(Random(1))
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false
  ..monsterSkills = false;

/// [type]'s stats in [g] with exactly [items] taken (their caps aside: the recipes and caps are the Smithy's).
Stats holding(Game g, String type, List<Item> items) {
  g.upgrades[type] = [...items];
  return g.statsOf(type);
}

/// [slot]'s three items, grade I to III.
List<Item> grades(ItemSlot slot) => [for (final i in Item.values) if (i.slot == slot) i];

/// [item]'s number in the rules a board game reads (town.json `items.<name>.effect`).
double k(Item item) => board().townRules.items[item]!.effect;

/// Every number of [s], to compare two stats whole.
List<num> whole(Stats s) =>
    [s.hp, s.cost, s.mp, s.speed, s.dmg, s.range, s.rate, s.shotSpeed, s.splash, s.regen, s.def, s.mpRegen, s.reachCap, s.darkK, s.healK];

/// [u] strikes once now: its cooldown cleared, one short tick, then it stands.
void strikeOnce(Game g, Unit u) {
  u
    ..busyUntil = double.negativeInfinity
    ..cd = 0;
  g.tick(0.05);
  u.busyUntil = hold;
}

/// The HP a [type] troop holding [items] takes off a [foe] (a [field] game) with one blow, and the foe's defence and
/// whether it is undead.
(double, double, bool) blow(String type, List<Item> items, String foe) {
  final g = field()..upgrades[type] = [...items];
  final u = placeNow(g, type, 2, 3), f = foeAt(g, foe, u.pos + const Point(12, 0))..hp = 100000;
  final before = f.hp;
  strikeOnce(g, u);
  return (before - f.hp, f.stats.def, f.stats.dark);
}

void main() {
  test('the numbers: each kind at its three grades from town.json `items`, and the spears\' ceiling', () {
    expect([for (final i in grades(ItemSlot.amulet)) k(i)], [1.08, 1.10, 1.12]);
    expect([for (final i in grades(ItemSlot.beads)) k(i)], [1.12, 1.15, 1.18]);
    expect([for (final i in grades(ItemSlot.torch)) k(i)], [1.12, 1.15, 1.18]);
    expect([for (final i in grades(ItemSlot.spear)) k(i)], [1.15, 1.18, 1.22]);
    expect([for (final i in grades(ItemSlot.prism)) k(i)], [1.15, 1.18, 1.22]);
    final g = board();
    expect((g.townRules.items[Item.spear]!.reachMost, spearReachMost), (1.5, 1.5));
    expect([for (final i in Item.values) if (g.townRules.items[i]!.reachMost != null) i], [Item.spear], reason: 'the spear\'s only');
    expect((g.townRules.items[Item.prism]!.splashMost, prismSplashMost), (1.5, 1.5));
    expect([for (final i in Item.values) if (g.townRules.items[i]!.splashMost != null) i], [Item.prism], reason: 'the prism\'s only');
    expect(TownRules.patch({'items': {'prism': {'splashMost': 2.0}}}).items[Item.prism]!.splashMost, 2.0);
    expect(TownRules.patch({'items': {'prism': {'splashMost': 0.9}}}).items[Item.prism]!.splashMost, prismSplashMost);
    expect(TownRules.patch({'items': {'spear': {'reachMost': 1.3}}}).items[Item.spear]!.reachMost, 1.3);
    expect(TownRules.patch({'items': {'spear': {'reachMost': 0.5}}}).items[Item.spear]!.reachMost, spearReachMost,
        reason: 'below 1 would shorten a spear holder: the default stays');
    for (final i in Item.values) {
      expect(g.itemK(i), g.townRules.items[i]!.effect, reason: '$i: the forge on reads town.json');
    }
    expect([for (final i in droppedItems) Game().itemK(i)], [swordDmg, shieldDef, bootsSpeed, bowRange, glovesRate, potionRegen, staffDmg],
        reason: 'the forge off: the seven\'s constants');
  });

  group('Amulet: max HP x1.08 / 1.10 / 1.12', () {
    test('each grade alone raises only the max HP; amulets compound, each one rounded as HP is', () {
      for (final type in ['soldier', 'knight']) {
        final base = holding(board(), type, const []);
        for (final a in grades(ItemSlot.amulet)) {
          final s = holding(board(), type, [a]);
          expect(s.hp, (base.hp * k(a)).round(), reason: '$type $a');
          expect(whole(s)..removeAt(0), whole(base)..removeAt(0), reason: '$type $a: nothing else');
        }
      }
      final set = [Item.amulet, Item.amulet, Item.silverAmulet, Item.goldAmulet];
      expect(holding(board(), 'soldier', set).hp, set.fold(troopTypes['soldier']!.hp, (hp, a) => (hp * k(a)).round()));
      expect(holding(board(), 'soldier', set).hp, closeTo(90 * 1.08 * 1.08 * 1.10 * 1.12, 1));
    });

    test('on top of the awakening\'s HP: what the amulets add stays at Awaken 1, and the MP regen is the awakening\'s', () {
      final g = board(), base = troopTypes['soldier']!;
      final recipe = [for (final MapEntry(key: i, value: n) in awakenRecipe['soldier']!.entries) ...List.filled(n, i)];
      final s = holding(g, 'soldier', [...recipe, Item.amulet]);
      expect(g.awakenLevel('soldier'), 1);
      expect(s.hp, (base.hp * (1 + awakenHp) * ((base.hp * 1.08).round() / base.hp)).round());
      expect(s.hp, greaterThan((base.hp * (1 + awakenHp)).round()));
      expect(s.mpRegen, base.mpRegen * (1 + awakenMp));
    });

    test('a troop on the field gains the HP when its type takes one (refit), and keeps its wound', () {
      final g = field(), u = placeNow(g, 'knight', 2, 3)..hp = 100;
      // useItem refits every troop of the type; the amulet's cap is the Smithy's, so it comes through a sword it can take.
      g
        ..upgrades['knight'] = [Item.goldAmulet]
        ..inventory[Item.sword] = 1;
      expect(g.useItem(Item.sword, 'knight'), isTrue);
      expect(u.maxHp, (140 * 1.12).round());
      expect(u.hp, 100 + (140 * 1.12).round() - 140);
    });
  });

  group('Prayer Beads: a healer\'s heals x1.12 / 1.15 / 1.18', () {
    test('each grade alone: the priest\'s heal, nothing else; on a type that doesn\'t heal, nothing', () {
      final base = holding(board(), 'priest', const []);
      for (final b in grades(ItemSlot.beads)) {
        final s = holding(board(), 'priest', [b]);
        expect(s.dmg, closeTo(base.dmg * k(b), 1e-9), reason: '$b');
        expect((s.healK, s.hp, s.range, s.rate), (k(b), base.hp, base.range, base.rate));
        for (final type in ['soldier', 'archer', 'wizard']) {
          expect(whole(holding(board(), type, [b])), whole(holding(board(), type, const [])), reason: '$type $b');
        }
      }
    });

    test('they compound; a potion\'s and a staff\'s added heal take them too, whatever the order', () {
      final set = [Item.prayerBeads, Item.prayerBeads, Item.holyBeads, Item.holyBeads, Item.saintBeads, Item.saintBeads];
      expect(holding(board(), 'priest', set).dmg, closeTo(12 * pow(1.12 * 1.15 * 1.18, 2), 1e-9));
      final orders = [
        [Item.potion, Item.staff, Item.holyBeads],
        [Item.holyBeads, Item.potion, Item.staff],
        [Item.staff, Item.holyBeads, Item.potion],
      ];
      for (final o in orders) {
        expect(holding(board(), 'priest', o).dmg, closeTo((12 + potionHeal + staffHeal) * 1.15, 1e-9), reason: '$o');
      }
    });

    test('a priest\'s heal lands bigger, and so does its holy damage on the undead', () {
      double heal(List<Item> items) {
        final heard = <double>[];
        final g = field()
          ..upgrades['priest'] = [...items]
          ..onTroopHeal = (u, src, asked, past) => heard.add(asked);
        placeNow(g, 'priest', 0, 3);
        placeNow(g, 'knight', 2, 3)
          ..hp = 50
          ..busyUntil = hold;
        foeAt(g, 'orc', const Point(300, 60)); // mid-wave
        for (var i = 0; i < 60 && heard.isEmpty; i++) {
          g.tick(0.05);
        }
        expect(heard, hasLength(1));
        return heard.single;
      }

      expect(heal(const []), closeTo(12, 1e-9));
      expect(heal([Item.saintBeads]), closeTo(12 * 1.18, 1e-9));

      (double, double) smite(List<Item> items) {
        final g = field()..upgrades['priest'] = [...items];
        final p = placeNow(g, 'priest', 1, 3), s = foeAt(g, 'skeleton', p.pos + const Point(60, 0))..hp = 100000;
        final before = s.hp;
        strikeOnce(g, p);
        return (before - s.hp, s.stats.def);
      }

      final (plain, def) = smite(const []);
      final (beads, _) = smite([Item.saintBeads]);
      expect(plain, closeTo(hitTaken(12 * holyShare, def), 1e-9));
      expect(beads, closeTo(hitTaken(12 * 1.18 * holyShare, def), 1e-9));
    });
  });

  group('Torch: blows on the undead x1.12 / 1.15 / 1.18', () {
    test('each grade alone sets only the factor; torches compound', () {
      for (final type in ['swordsman', 'archer', 'knight_templar']) {
        final base = holding(board(), type, const []);
        for (final t in grades(ItemSlot.torch)) {
          final s = holding(board(), type, [t]);
          expect(s.darkK, k(t), reason: '$type $t');
          expect((whole(s)..removeAt(13)), (whole(base)..removeAt(13)), reason: '$type $t: nothing else');
        }
      }
      expect(holding(board(), 'archer', grades(ItemSlot.torch)).darkK, closeTo(1.12 * 1.15 * 1.18, 1e-12));
    });

    test('a blow on an undead foe lands its factor bigger, before defence; on any other foe, as before', () {
      final dmg = troopTypes['swordsman']!.dmg;
      for (final t in grades(ItemSlot.torch)) {
        final (hp, def, dark) = blow('swordsman', [t], 'skeleton');
        expect(dark, isTrue);
        expect(hp, closeTo(hitTaken(dmg * k(t), def), 1e-9), reason: '$t');
        final (orcHp, orcDef, orcDark) = blow('swordsman', [t], 'orc');
        expect(orcDark, isFalse);
        expect(orcHp, closeTo(hitTaken(dmg, orcDef), 1e-9), reason: '$t on an orc');
      }
      final (hp, def, _) = blow('swordsman', const [], 'skeleton');
      expect(hp, closeTo(hitTaken(dmg, def), 1e-9), reason: 'no torch');
      final (two, def2, _) = blow('swordsman', [Item.torch, Item.sunTorch], 'armored_skeleton');
      expect(two, closeTo(hitTaken(dmg * 1.12 * 1.18, def2), 1e-9));
    });

    test("a monster's blow is never a torch's: an undead monster striking a troop that holds torches hurts as before", () {
      double struck(List<Item> items) {
        final g = field()..upgrades['swordsman'] = [...items];
        final u = placeNow(g, 'swordsman', 2, 3)
          ..hp = 1000
          ..busyUntil = hold;
        final s = foeAt(g, 'skeleton', u.pos + const Point(12, 0))..busyUntil = double.negativeInfinity;
        s.cd = 0;
        g.tick(0.05);
        return 1000 - u.hp;
      }

      expect(struck(const []), greaterThan(0));
      expect(struck([Item.sunTorch]), struck(const []));
    });
  });

  group('Spear: melee reach x1.15 / 1.18 / 1.22, its cap too, up to the ceiling', () {
    test('each grade alone: the lancer\'s reach and reach cap; a type that doesn\'t fight up close, nothing', () {
      final lancer = troopTypes['lancer']!;
      for (final sp in grades(ItemSlot.spear)) {
        final s = holding(board(), 'lancer', [sp]);
        expect(s.range, closeTo(lancer.range * k(sp), 1e-9), reason: '$sp');
        expect(s.reachCap, closeTo(meleeMaxRange * k(sp), 1e-9), reason: '$sp');
        expect((s.hp, s.dmg, s.rate, s.speed), (lancer.hp, lancer.dmg, lancer.rate, lancer.speed));
        for (final type in ['archer', 'priest', 'wizard']) {
          expect(whole(holding(board(), type, [sp])), whole(holding(board(), type, const [])), reason: '$type $sp');
        }
      }
      final two = holding(board(), 'lancer', [Item.spear, Item.wingedSpear]);
      expect(two.range, closeTo(22 * 1.15 * 1.18, 1e-9), reason: 'under the ceiling (33): compounded');
    });

    test('a full set (2 + 2 + 2) stops at the ceiling: 1.5 x its base reach (22 -> 33), its cap 1.5 x meleeMaxRange; '
        'a patched ceiling moves both', () {
      final six = [for (final sp in grades(ItemSlot.spear)) ...[sp, sp]];
      expect(six.fold(1.0, (p, sp) => p * k(sp)), closeTo(2.74, 0.01), reason: 'uncapped it would be x2.74');
      final s = holding(board(), 'lancer', six);
      expect(s.range, closeTo(22 * 1.5, 1e-9));
      expect(s.reachCap, closeTo(meleeMaxRange * 1.5, 1e-9));
      final g = board()..townRules = TownRules.patch({'items': {'spear': {'reachMost': 1.3}}});
      final t = holding(g, 'lancer', six);
      expect(t.range, closeTo(22 * 1.3, 1e-9));
      expect(t.reachCap, closeTo(meleeMaxRange * 1.3, 1e-9));
    });

    test("a bow's clamp reads the raised cap", () {
      const s = Stats(hp: 1, cost: 1, speed: 1, dmg: 1, range: 25, rate: 1);
      expect(s.upgraded(Item.bow).range, meleeMaxRange);
      expect(s.upgraded(Item.spear, 1.15).upgraded(Item.bow).range, closeTo(meleeMaxRange * 1.15, 1e-9));
      expect(s.upgraded(Item.bow).upgraded(Item.spear, 1.15).range, closeTo(meleeMaxRange * 1.15, 1e-9));
      expect(s.upgraded(Item.spear, 1.15).boosted(2).range, closeTo(meleeMaxRange * 1.15, 1e-9), reason: 'the aura\'s, a Hero\'s');
    });

    test('a full-spear lancer with Hawk Feather and the Hero\'s aura never reaches past 1.5 x meleeMaxRange', () {
      final g = field()
        ..upgrades['lancer'] = [for (final sp in grades(ItemSlot.spear)) ...[sp, sp]]
        ..givePusaka(Relic.hawkFeather, type: 'lancer', stars: 3);
      final hawk = g.statsOf('lancer');
      expect(hawk.range, closeTo(meleeMaxRange * 1.5, 1e-9), reason: 'Hawk Feather stops at the ceiling\'s cap');
      placeNow(g, 'soldier', 1, 2).hero = true;
      final u = placeNow(g, 'lancer', 2, 3);
      expect(g.heroAlive, isTrue);
      expect(g.fieldStats('lancer').range, closeTo(meleeMaxRange * 1.5, 1e-9));
      expect(u.stats.range, lessThanOrEqualTo(meleeMaxRange * 1.5 + 1e-9));
      expect(hawk.boosted(heroBoost).range, closeTo(meleeMaxRange * 1.5, 1e-9));
      expect(hawk.heroic(HeroStat.values.toSet(), heroBoost, auraBoost).range, closeTo(meleeMaxRange * 1.5, 1e-9));
    });
  });

  group('Prism: splash x1.15 / 1.18 / 1.22, only for a type with splash, up to the ceiling', () {
    test('each grade alone: the axeman\'s and the wizard\'s splash, nothing else', () {
      for (final type in ['armored_axeman', 'wizard']) {
        final base = holding(board(), type, const []);
        for (final p in grades(ItemSlot.prism)) {
          final s = holding(board(), type, [p]);
          expect(s.splash, closeTo(base.splash * k(p), 1e-9), reason: '$type $p');
          expect(whole(s)..removeAt(8), whole(base)..removeAt(8), reason: '$type $p: nothing else');
        }
      }
    });

    test('they compound up to the ceiling, 1.5 x the base splash (Wizard 30, Axeman 24); a patched ceiling moves it; on a '
        'type without splash a prism does nothing', () {
      expect(holding(board(), 'wizard', [Item.prism, Item.prism]).splash, closeTo(20 * 1.15 * 1.15, 1e-9), reason: 'under 30');
      expect(holding(board(), 'wizard', [Item.prism, Item.prism, Item.arcanePrism]).splash, closeTo(30, 1e-9),
          reason: '20 x 1.15² x 1.18 = 31.2: stopped');
      final set = [for (final p in grades(ItemSlot.prism)) ...[p, p]];
      expect(pow(1.15 * 1.18 * 1.22, 2), closeTo(2.74, 0.01), reason: 'uncapped the whole set would be x2.74');
      expect(holding(board(), 'wizard', set).splash, closeTo(20 * 1.5, 1e-9));
      expect(holding(board(), 'armored_axeman', grades(ItemSlot.prism)).splash, closeTo(16 * 1.5, 1e-9), reason: 'x1.66: stopped');
      final g = board()..townRules = TownRules.patch({'items': {'prism': {'splashMost': 2.0}}});
      expect(holding(g, 'wizard', set).splash, closeTo(40, 1e-9));
      for (final type in troopTypes.keys.where((t) => troopTypes[t]!.splash == 0)) {
        expect(whole(holding(board(), type, set)), whole(holding(board(), type, const [])), reason: type);
      }
    });
  });

  group('Stats.upgraded without a number', () {
    final all = [for (final slot in [ItemSlot.amulet, ItemSlot.beads, ItemSlot.torch, ItemSlot.spear, ItemSlot.prism]) ...grades(slot)];

    test('Stats.upgraded without a number leaves the five alone, and the new fields start at their defaults', () {
      for (final type in troopTypes.keys) {
        final s = troopTypes[type]!;
        expect((s.reachCap, s.darkK, s.healK), (meleeMaxRange, 1.0, 1.0));
        for (final i in all) {
          expect(whole(s.upgraded(i)), whole(s), reason: '$type $i');
        }
      }
    });
  });
}
