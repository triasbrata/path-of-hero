// The forge's drops (decisions-log 246; lib/town.dart, lib/game.dart's kill block; docs/loot-items-relics.md "The forge:
// drops"): with the Towns on (the forge-off build is gone, decisions-log 296). No item ever drops (the loot dice
// drawing as with the Towns off), each rank drops its list of town.json's `drops.forge` (the
// design's table, ~3x), the Necromancer its Lich Orb; the kinds dropped are remembered in drop order ([Game.matsSeen],
// saved only with the forge and the Towns on, a save without it starting from the materials held, a buy never adding);
// the Shop's material price ([Materials.shopMatPrice]). With the Towns off (a plain Game(), tests only) items fall as
// before the forge.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// A die that gives [draws] in turn (then [rest]) and counts them.
class _Dice implements Random {
  _Dice(this.draws, [this.rest]);

  final List<double> draws;
  final double? rest;
  int used = 0;

  @override
  double nextDouble() {
    final i = used++;
    return i < draws.length ? draws[i] : rest ?? (throw StateError('no draw left'));
  }

  @override
  int nextInt(int max) {
    used++;
    return 0;
  }

  @override
  bool nextBool() => throw UnsupportedError('nextBool');
}

/// A die that counts the draws of [inner], and their kinds in order.
class _Counted implements Random {
  _Counted(this.inner);

  final Random inner;
  final calls = <String>[];

  @override
  double nextDouble() {
    final v = inner.nextDouble();
    calls.add('d$v');
    return v;
  }

  @override
  int nextInt(int max) {
    final v = inner.nextInt(max);
    calls.add('i$max:$v');
    return v;
  }

  @override
  bool nextBool() {
    final v = inner.nextBool();
    calls.add('b$v');
    return v;
  }
}

/// The monster types that drop parts: the twelve, the healer and the Necromancer.
final types = [...enemyTypes.keys, necroHealer, boss];

/// A game with no skills cast, the Towns [towns], its materials on [mats] and its loot on [loot].
Game forgeGame({bool towns = true, Random? mats, Random? loot}) {
  final g = bareGame(Random(1))
    ..skills = false
    ..heroSkills = false
    ..awakenSkills = false
    ..monsterSkills = false
    ..towns = towns
    ..matDice = mats ?? Random(5)
    ..loot = loot ?? Random(9);
  return g;
}

/// Kills each of [foes] (type, rank, raised) in a wave of [g] begun with nothing to spawn, by a knight at cell (2, 3);
/// the wave is still on afterwards (a slime held off the field keeps it), so nothing is won yet.
List<Unit> kill(Game g, List<(String, Tier, bool)> foes) {
  g
    ..startWave()
    ..queue.clear();
  final k = g.troops.where((u) => u.alive).firstOrNull ?? placeNow(g, 'knight', 2, 3);
  final keep = foeAt(g, 'slime', const Point(2000, 10)); // far off: the wave stays on
  final units = [
    for (final (i, (type, tier, raised)) in foes.indexed)
      foeAt(g, type, k.pos + Point(12.0, i * 0.01), tier)
        ..hp = 1
        ..raisedBy = raised ? keep : null,
  ];
  for (var n = 0; n < 2000 && units.any((u) => u.alive); n++) {
    g.tick(0.05);
  }
  expect([for (final u in units) u.alive], everyElement(isFalse));
  expect(keep.alive, isTrue);
  return units;
}

/// Wins [g]'s wave on: its last monster goes.
void winNow(Game g) {
  for (final u in g.enemies) {
    u.gone = true;
  }
  g.tick(0.05);
  expect(g.waveActive, isFalse);
}

/// [g]'s save as text, its troops' names left out (a [bareGame]'s name dice aren't seeded).
String saveText(Game g) {
  final j = g.toJson();
  return jsonEncode({
    ...j,
    'troops': [for (final t in j['troops'] as List) {...t as Map}..remove('name')],
  });
}

/// The design's table (forge-design §2) as (rank, [(grade, chance, count)], always-drops).
const _table = {
  Tier.normal: ([(MatGrade.common, 0.60, 1)], <Mat, int>{}),
  Tier.elite: ([(MatGrade.common, 1.0, 1)], <Mat, int>{}),
  Tier.highElite: ([(MatGrade.common, 1.0, 1), (MatGrade.rare, 0.50, 1)], <Mat, int>{}),
  Tier.miniBoss: ([(MatGrade.common, 1.0, 3), (MatGrade.rare, 1.0, 3)], {Mat.evilEye: 1}),
  Tier.boss: ([(MatGrade.common, 1.0, 4), (MatGrade.rare, 1.0, 4)], {Mat.soulOrb: 1}),
};

void main() {
  test('the forge\'s numbers are the design\'s table, written out in the shipped town.json; the drops from before the '
      'forge are gone (decisions-log 296)', () {
    const r = TownRules();
    for (final MapEntry(key: tier, value: (parts, plus)) in _table.entries) {
      final ds = r.forgeDrops[tier]!;
      expect([for (final d in ds) (d.part, d.chance, d.count)], parts, reason: '$tier');
      expect({for (final d in ds) ...d.plus}, plus, reason: '$tier');
    }
    expect(r.necromancerPlus, {Mat.lichOrb: 1}, reason: 'the Necromancer still adds a Lich Orb');
    expect((r.shop.matMarkup, r.shop.matRise), (2.5, 0.0));
    final j = r.toJson();
    expect((j['drops'] as Map).keys, ['necromancerSlot', 'forge'], reason: 'no drops.normal to drops.boss');
    final old = TownRules.fromJson({...j, 'drops': {...j['drops'] as Map<String, dynamic>, 'normal': {'part': 'common', 'chance': 0.15}}});
    expect(old.toJson()['drops'], j['drops'], reason: 'an old file\'s pre-forge drops ignored');
    expect(old.skipped, ['drops: no normal']);
    expect((j['drops'] as Map)['forge'], {
      'normal': [{'part': 'common', 'chance': 0.60, 'count': 1}],
      'elite': [{'part': 'common', 'chance': 1.0, 'count': 1}],
      'highElite': [{'part': 'common', 'chance': 1.0, 'count': 1}, {'part': 'rare', 'chance': 0.50, 'count': 1}],
      'miniBoss': [{'part': 'common', 'chance': 1.0, 'count': 3}, {'part': 'rare', 'chance': 1.0, 'count': 3, 'plus': {'evilEye': 1}}],
      'boss': [{'part': 'common', 'chance': 1.0, 'count': 4}, {'part': 'rare', 'chance': 1.0, 'count': 4, 'plus': {'soulOrb': 1}}],
    });
  });

  test('the file: drops.forge a list a rank; an entry\'s bad number keeps the shipped entry\'s, one past them drops nothing, '
      'a rank that isn\'t a list keeps its default, an unknown rank or material is noted; a patch puts a list in', () {
    final odd = TownRules.parse(jsonEncode({
      'version': TownRules.version,
      'drops': {
        'forge': {
          'normal': [{'chance': 0.9}, {'part': 'rare', 'chance': 2}, 'x'],
          'elite': {'part': 'rare'},
          'highElite': [{'part': 'rare', 'chance': 0.25, 'count': 2, 'plus': {'goo': 1, 'skull': 1}}],
          'champion': [],
        },
      },
      'shop': {'matMarkup': 3, 'matRise': -1},
    }));
    expect([for (final d in odd.forgeDrops[Tier.normal]!) (d.part, d.chance, d.count)],
        [(MatGrade.common, 0.9, 1), (MatGrade.rare, 0.0, 1)]);
    expect(odd.forgeDrops[Tier.elite], const TownRules().forgeDrops[Tier.elite]);
    expect([for (final d in odd.forgeDrops[Tier.highElite]!) (d.part, d.chance, d.count)], [(MatGrade.rare, 0.25, 2)]);
    expect(odd.forgeDrops[Tier.highElite]!.single.plus, {Mat.skull: 1});
    expect(odd.forgeDrops[Tier.boss], const TownRules().forgeDrops[Tier.boss]);
    expect((odd.shop.matMarkup, odd.shop.matRise), (3.0, 0.0));
    expect(odd.skipped, ['drops.forge: no champion', 'drops.forge.highElite.plus: goo 1']);
    final p = TownRules.patch({
      'drops': {
        'forge': {
          'normal': [{'chance': 1.0}],
        },
      },
    });
    expect([for (final d in p.forgeDrops[Tier.normal]!) (d.part, d.chance, d.count)], [(MatGrade.common, 1.0, 1)]);
    expect([for (final d in p.forgeDrops[Tier.highElite]!) (d.part, d.chance, d.count)], [(MatGrade.common, 1.0, 1), (MatGrade.rare, 0.5, 1)]);
  });

  test('a kill with the forge on drops its rank\'s list, a draw for each part with a chance (a fake die): a normal its Common '
      'at 60%, an elite its Common always, a high elite its Common always and its Rare at 50%, a mini boss 3 + 3 and an '
      'Evil Eye, a boss 4 + 4 and a Soul Orb; the Necromancer (no Common) a Lich Orb on top as either', () {
    const r = TownRules();
    for (final type in types) {
      for (final tier in Tier.values) {
        final (parts, plus) = _table[tier]!;
        final chancy = [for (final (grade, chance, _) in parts) if (r.partOf(type, grade) != null && chance < 1) chance];
        for (final hit in [true, false]) {
          final dice = _Dice([for (final c in chancy) hit ? c - 1e-9 : c]), got = r.dropOf(type, tier, dice);
          expect(dice.used, chancy.length, reason: '$type $tier: one draw per part with a chance');
          final want = <Mat, int>{
            for (final (grade, chance, n) in parts)
              if (r.partOf(type, grade) case final m? when chance >= 1 || hit) m: n,
            ...plus,
            if (type == boss && tier.index >= Tier.miniBoss.index) Mat.lichOrb: 1,
          };
          expect(got, want, reason: '$type $tier, ${hit ? 'under' : 'at'} the chance');
        }
      }
    }
    expect(r.dropOf(boss, Tier.boss, _Dice([])), {Mat.darkGem: 4, Mat.soulOrb: 1, Mat.lichOrb: 1});
    expect(r.dropOf(boss, Tier.miniBoss, _Dice([])), {Mat.darkGem: 3, Mat.evilEye: 1, Mat.lichOrb: 1});
    expect(r.dropOf('werebear', Tier.boss, _Dice([])), {Mat.bearFur: 4, Mat.bearClaw: 4, Mat.soulOrb: 1});
    expect(r.dropOf('orc', Tier.highElite, _Dice([0.4])), {Mat.orcTooth: 1, Mat.orcTusk: 1});
    expect(r.dropOf(boss, Tier.highElite, _Dice([0.6])), isEmpty, reason: 'no Common; its Dark Gem missed');
  });

  test('4,000 seeded kills a rank and a type: each part drops at its rank\'s rate', () {
    const r = TownRules(), n = 4000;
    for (final type in types) {
      for (final tier in Tier.values) {
        final dice = Random(1000 + types.indexOf(type) * 10 + tier.index), got = <Mat, int>{};
        for (var i = 0; i < n; i++) {
          for (final MapEntry(key: m, value: c) in r.dropOf(type, tier, dice).entries) {
            got[m] = (got[m] ?? 0) + c;
          }
        }
        final (parts, plus) = _table[tier]!;
        for (final (grade, chance, count) in parts) {
          final m = r.partOf(type, grade);
          if (m == null) continue;
          expect((got[m] ?? 0) / n, closeTo(chance * count, 0.03 * count), reason: '$type $tier ${m.name}: ${got[m]} of $n');
        }
        for (final MapEntry(key: m, value: c) in plus.entries) {
          expect(got[m], n * c, reason: '$type $tier ${m.name}');
        }
      }
    }
  });

  test('with the Towns on no item ever drops, the loot dice drawing exactly as with them off (items and relics drawn and '
      'thrown away); the materials are the forge\'s; nothing reaches the bag at the win but materials', () {
    const foes = [
      ('slime', Tier.normal, false),
      ('bat', Tier.elite, false),
      ('orc', Tier.highElite, false),
      ('werewolf', Tier.miniBoss, false),
      ('skeleton', Tier.boss, false),
      ('skeleton', Tier.normal, true),
    ];
    (Game, List<String>) run(bool towns) {
      final loot = _Counted(_Dice([], 0.0)); // every roll drops: the most items there can be
      final g = forgeGame(towns: towns, loot: loot, mats: _Dice([], 0.0));
      kill(g, foes);
      return (g, loot.calls);
    }

    final (off, offCalls) = run(false);
    final (on, onCalls) = run(true);
    expect(onCalls, offCalls, reason: 'the same loot draws, in the same order');
    expect(off.drops.length, 1 + 1 + 1 + 1 + bossDrops + 1, reason: 'with the Towns off the items fall (the raised one rolls)');
    expect(on.drops, isEmpty);
    expect(on.relicDrops, isEmpty, reason: 'the Towns take the relics');
    expect(on.waveMaterials, {
      Mat.slimeGel: 1,
      Mat.batWing: 1,
      Mat.orcTooth: 1,
      Mat.orcTusk: 1,
      Mat.wolfClaw: 3,
      Mat.wolfFang: 3,
      Mat.evilEye: 1,
      Mat.boneShard: 4,
      Mat.skull: 4,
      Mat.soulOrb: 1,
    });
    expect(off.waveMaterials, isEmpty, reason: 'no materials with the Towns off');
    winNow(on);
    expect(on.inventory, isEmpty);
    expect(on.lastLoot, isEmpty);
    expect(on.materials[Mat.boneShard], 4);
    winNow(off);
    expect(off.lastLoot, hasLength(off.inventory.values.fold<int>(0, (a, n) => a + n)));
    expect(off.lastLoot, hasLength(1 + 1 + 1 + 1 + bossDrops + 1));
  });

  test('matsSeen: each kind once, in the order it first dropped (a raised monster adds none); one come into the bag another '
      'way (the Shop\'s) or sold never changes it', () {
    final g = forgeGame(mats: _Dice([], 0.0));
    kill(g, [('bat', Tier.normal, false), ('slime', Tier.normal, false), ('bat', Tier.normal, false), ('orc', Tier.normal, true)]);
    expect(g.matsSeen, [Mat.batWing, Mat.slimeGel]);
    expect(g.materials, isEmpty, reason: 'seen at the drop, before the win');
    winNow(g);
    kill(g, [('orc', Tier.miniBoss, false)]);
    expect(g.matsSeen, [Mat.batWing, Mat.slimeGel, Mat.orcTooth, Mat.orcTusk, Mat.evilEye]);
    winNow(g);
    // In a Town's Shop: a kind put in the bag (as its buy will, F6) isn't seen; selling the last of one keeps it seen.
    g
      ..wave = 20
      ..gold = 1000000
      ..townAt = 21;
    expect(g.enterTown(), isTrue);
    g.materials[Mat.bearClaw] = 1;
    expect(g.sell(Mat.batWing, 99), 2);
    expect(g.sell(Mat.bearClaw), 1);
    expect(g.matsSeen, [Mat.batWing, Mat.slimeGel, Mat.orcTooth, Mat.orcTusk, Mat.evilEye]);
  });

  test('the save: matsSeen by name in drop order, only with the Towns on (and any seen); loaded in its order, '
      'an unknown name skipped; a save without it starts from the materials held, in Mat order', () {
    final g = forgeGame()
      ..wave = 9
      ..materials.addAll({Mat.lichOrb: 1, Mat.slimeGel: 4})
      ..matsSeen.addAll([Mat.skull, Mat.slimeGel, Mat.lichOrb]);
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect(j['matsSeen'], ['skull', 'slimeGel', 'lichOrb']);
    expect(Game.fromJson(j).matsSeen, [Mat.skull, Mat.slimeGel, Mat.lichOrb]);
    expect(Game.fromJson({...j, 'matsSeen': ['dragonScale', 'batFang', 'skull', 3]}).matsSeen, [Mat.batFang, Mat.skull]);
    expect(Game.fromJson({...j}..remove('matsSeen')).matsSeen, [Mat.slimeGel, Mat.lichOrb], reason: 'seeded from the bag, in Mat order');
    expect(Game.fromJson({...j}..remove('matsSeen')..remove('materials')).matsSeen, isEmpty);
    // Not written with the Towns off (tests only), nor when none was seen: those saves are as before.
    final h = forgeGame(towns: false)
      ..wave = 9
      ..materials.addAll({Mat.slimeGel: 4});
    final before = jsonEncode(h.toJson());
    h.matsSeen.addAll([Mat.skull, Mat.slimeGel]);
    expect(jsonEncode(h.toJson()), before);
    expect(forgeGame().toJson().containsKey('matsSeen'), isFalse);
  });

  test('the Shop\'s material price: 2.5x its sell price rounded up to 5, the same after a buy (matRise 0); a patched rise '
      'adds its share a buy, also rounded up to 5', () {
    final g = forgeGame();
    const want = {
      Mat.slimeGel: 25, Mat.batWing: 25, Mat.boneShard: 40, Mat.orcTooth: 40, Mat.boneArrow: 50, Mat.wolfClaw: 65, //
      Mat.rustyPlate: 65, Mat.leatherStrap: 75, Mat.orcEar: 90, Mat.ironScrap: 100, Mat.bigBone: 100, Mat.bearFur: 125,
      Mat.tealCloth: 75, Mat.slimeCore: 100, Mat.batFang: 100, Mat.skull: 150, Mat.orcTusk: 150, Mat.boneBow: 200,
      Mat.wolfFang: 250, Mat.crackedSkull: 250, Mat.wargFang: 300, Mat.orcHeart: 350, Mat.ironTusk: 400,
      Mat.graveSteel: 400, Mat.bearClaw: 500, Mat.tealGem: 300, Mat.darkGem: 500, Mat.evilEye: 750, Mat.soulOrb: 1500,
      Mat.lichOrb: 2000,
    };
    expect({for (final m in droppedMats) m: g.shopMatPrice(m)}, want, reason: 'the design\'s out-shop list');
    expect([g.shopMatPrice(Mat.wolfClaw, 3), g.shopMatPrice(Mat.soulOrb, 10)], [65, 1500]);
    g.townRules = TownRules.patch({
      'shop': {'matRise': 0.1, 'matMarkup': 2.2},
    });
    // Slime Gel 10 x 2.2 = 22 -> 25, +2.5 -> 5 a buy; Bear Fur 50 x 2.2 = 110 (not 115: no float creep), +11 -> 15.
    expect([for (var n = 0; n < 3; n++) g.shopMatPrice(Mat.slimeGel, n)], [25, 30, 35]);
    expect([for (var n = 0; n < 3; n++) g.shopMatPrice(Mat.bearFur, n)], [110, 125, 140]);
    expect(const TownShop().matPrice(0), 0);
  });

  test('who drops it: the Common from normal kills on, a mini boss 3 and a boss 4; the Rare from high elites; the '
      'Trophies as before', () {
    final on = forgeGame();
    expect(on.matSource(Mat.slimeGel), 'Common material. Slimes drop it, a slime mini boss 3, a boss 4.');
    expect(on.matSource(Mat.wolfFang), 'Rare material. High elite werewolves drop it, a werewolf mini boss 3, a boss 4.');
    expect(on.matSource(Mat.tealCloth), 'Common material. Necro Healers drop it, a necro healer mini boss 3, a boss 4.');
    expect(on.matSource(Mat.evilEye), 'Trophy. Every mini boss drops one.');
    expect(on.matSource(Mat.soulOrb), 'Trophy. Every boss drops one.');
    expect(on.matSource(Mat.lichOrb), 'Trophy. The Necromancer drops one as a mini boss or boss.');
    for (final m in droppedMats) {
      expect(on.matFrom(m), isNotEmpty, reason: '$m');
    }
    expect([on.matFrom(Mat.evilEye), on.matFrom(Mat.soulOrb)], [tierNames[Tier.miniBoss], tierNames[Tier.boss]]);
  });
}
