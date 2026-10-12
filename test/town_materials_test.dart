// The Towns' materials (decisions-log 221; lib/town.dart; docs/loot-items-relics.md "Town and Smithy"): the shipped
// town.json is the defaults, every number written out; the 30 and their names, grades and sources, each in a recipe;
// the file's names the game doesn't know left out; a kill's materials into the wave's tally and the bag at the win, never
// from a raised monster; relics and items no longer dropping (the loot dice drawing as before them:
// forge_drops_test.dart); the save; the telemetry. Each rank's list of drops (town.json `drops.forge`; the
// table from before the forge went with the forge-off build, decisions-log 296): forge_drops_test.dart.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/telemetry.dart';

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

/// A sink that keeps the records, through JSON.
class _Kept implements TelemetrySink {
  final records = <Map<String, dynamic>>[];

  @override
  void add(Map<String, Object?> record) => records.add(jsonDecode(jsonEncode(record)) as Map<String, dynamic>);

  @override
  Future<void> flush() async {}
}

/// The monster types that drop parts: the twelve, the healer and the Necromancer.
final types = [...enemyTypes.keys, necroHealer, boss];

/// A game with no skills cast, its materials on [mats] and its loot on [loot].
Game townGame({Random? mats, Random? loot}) => bareGame(Random(1))
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false
  ..matDice = mats ?? Random(5)
  ..loot = loot ?? Random(9);

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
  for (var n = 0; n < 400 && units.any((u) => u.alive); n++) {
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

void main() {
  test('the shipped town.json is the defaults, every number written out, and nothing in it is left out', () {
    final text = File('assets/config/town.json').readAsStringSync(), file = TownRules.parse(text);
    expect(file.toJson(), jsonDecode(text), reason: 'every number of the defaults is in the file, and only those');
    expect(const TownRules().toJson(), jsonDecode(text));
    expect(file.skipped, isEmpty);
    expect((TownRules.version, Game().townRules.toJson()['version']), (3, 3));
    expect(TownRules.versions, [2, 3], reason: 'a version-2 file still reads (decisions-log 245)');
    // The design's numbers (docs/loot-items-relics.md "Town and Smithy"), spot-checked.
    const r = TownRules();
    expect([r.forgeDrops[Tier.miniBoss]!.last.plus, r.forgeDrops[Tier.boss]!.last.plus, r.necromancerPlus], [{Mat.evilEye: 1}, {Mat.soulOrb: 1}, {Mat.lichOrb: 1}]);
    expect([for (final m in [Mat.slimeGel, Mat.bearFur, Mat.slimeCore, Mat.bearClaw, Mat.darkGem, Mat.lichOrb]) r.materials[m]!.sell], [10, 50, 40, 200, 200, 800]);
    expect([for (final k in townRelics) r.recipes[k]!.gold], [300, 300, 400, 400, 1000, 1000, 1000, 1000, 3000, 3500, 3000]);
    expect(r.recipes['giantSlayer']!.items, {Item.gloves: 1});
    expect([for (final t in RelicTier.values) r.tiers[t]!.shop], [12000, 20000, 32000]);
    expect((r.shop.from, r.shop.itemPrice, r.shop.itemRise), (1, 2000, 200)); // open in every Town (decisions-log 253)
    expect(r.relics['fury'], {'every': 3, 'hit': 2.0});
  });

  test('the 30: each named, Common / Rare / Trophy in the enum\'s order, a part of one type or a Trophy, and in a recipe', () {
    const r = TownRules();
    expect(droppedMats.length, 30);
    expect(Mat.values, [...droppedMats, ...craftedMats], reason: 'the forge\'s stones after the 30');
    expect({for (final m in Mat.values) m.name}, Words.materialNames.keys.toSet());
    expect([for (final m in droppedMats) r.materials[m]!.grade.index], [...List.filled(13, 0), ...List.filled(14, 1), ...List.filled(3, 2)]);
    // Each type its own two parts (the Necromancer no Common), every part a different material.
    expect(r.parts.keys.toSet(), types.toSet());
    final parts = [for (final t in types) ...[?r.partOf(t, MatGrade.common), ?r.partOf(t, MatGrade.rare)]];
    expect((parts.length, parts.toSet().length, r.partOf(boss, MatGrade.common)), (27, 27, null));
    for (final m in droppedMats) {
      final trophy = r.materials[m]!.grade == MatGrade.trophy;
      expect(r.sourcesOf(m).length, trophy ? 0 : 1, reason: '$m');
      if (!trophy) expect(r.partOf(r.sourcesOf(m).single, r.materials[m]!.grade), m, reason: '$m: its grade is its part\'s');
      expect(r.recipesWith(m), isNotEmpty, reason: '$m is in no recipe');
    }
    expect({for (final d in [for (final ds in r.forgeDrops.values) for (final d in ds) d.plus, r.necromancerPlus]) ...d.keys}, {Mat.evilEye, Mat.soulOrb, Mat.lichOrb});
    expect(r.recipes.keys, [...townRelics, for (final f in forgeRelics) f.name], reason: 'the forge\'s nine after the eleven');
    expect([for (final k in townRelics) townRelicName(k)], // the owner's names for cleave, lastStand, blessing (decisions-log 227)
        ['Fang', 'Thorns', 'Fury', 'Guard', 'Sweep', 'Venom', 'Mana Siphon', 'Spirit Ward', 'Iron Will', 'Giant Slayer', 'Holy Charm']);
    expect(townRelics, [for (final r in smallRelics) r.name], reason: 'every small relic has a recipe, in Relic order');
  });

  test('the file: an unknown name is left out where it stands and noted; a number out of range or of the wrong kind keeps its '
      'default; another version gives every default; a patch puts numbers in', () {
    final odd = TownRules.parse(jsonEncode({
      'version': 2,
      'drops': {
        'normal': {'chance': 2, 'count': -1, 'part': 'trophy'},
        'elite': {'chance': 0.5, 'count': 2, 'plus': {'goo': 1, 'evilEye': 1}},
        'champion': {},
      },
      'parts': {'slime': ['slimeGel', 'goo'], 'dragon': ['skull', null], 'bat': 'wing'},
      'materials': {'goo': {'grade': 'rare'}, 'skull': {'grade': 'epic', 'sell': 75}},
      'recipes': {'fang': {'materials': {'goo': 1, 'batWing': 3}, 'items': {'axe': 1, 'sword': 0}, 'gold': 1.5, 'tier': 'mighty'}, 'crown': {}},
      'tiers': {'basic': {'shop': 9000, 'sellShare': 3}},
      'relics': {'fury': {'every': 2.5, 'hit': 3}, 'thorns': {'share': -1}},
      'shop': {'from': 0, 'itemPrice': 2500},
    }));
    expect(odd.forgeDrops, const TownRules().forgeDrops, reason: 'the drops from before the forge: noted, never read');
    expect((odd.parts['slime'], odd.parts['bat'], odd.parts.containsKey('dragon')), ((Mat.slimeGel, null), (Mat.batWing, Mat.batFang), false));
    expect((odd.materials[Mat.skull]!.grade, odd.materials[Mat.skull]!.sell), (MatGrade.rare, 75));
    final fang = odd.recipes['fang']!;
    expect([fang.materials, fang.items], [{Mat.batWing: 3}, <Item, int>{}]);
    expect((fang.gold, fang.tier), (300, RelicTier.mighty));
    expect((odd.tiers[RelicTier.basic]!.shop, odd.tiers[RelicTier.basic]!.sellShare), (9000, 0.5));
    expect([odd.relics['fury'], odd.relics['thorns']], [{'every': 3, 'hit': 3.0}, {'share': 0.30}]);
    expect((odd.shop.from, odd.shop.itemPrice), (1, 2500));
    expect(odd.skipped, [
      'drops: no normal',
      'drops: no elite',
      'drops: no champion',
      'parts: no dragon',
      'materials: no goo',
      'recipes: no crown',
      'parts.slime: no goo',
      'recipes.fang.materials: goo 1',
      'recipes.fang.items: axe 1',
      'recipes.fang.items: sword 0',
    ]);
    expect(TownRules.parse('{"version": 1, "drops": {"normal": {"chance": 0.9}}}').toJson(), const TownRules().toJson());
    final p = TownRules.patch({
      'drops': {
        'forge': {
          'normal': [
            {'chance': 1.0},
          ],
        },
      },
      'recipes': {
        'fang': {
          'materials': {'batWing': 5},
        },
      },
    });
    expect((p.forgeDrops[Tier.normal]!.single.chance, p.forgeDrops[Tier.highElite]!.last.chance), (1.0, 0.50));
    expect(p.recipes['fang']!.materials, {Mat.batWing: 5, Mat.slimeGel: 2});
  });

  test('a kill drops into the wave\'s tally and pops; the win puts them in the bag; a raised monster drops none (no draw); '
      'no relic or item drops; a lost tally is gone with the game', () {
    final mats = _Dice([0.0, 0.0], 0.5);
    final on = townGame(mats: mats, loot: Random(4));
    kill(on, [('slime', Tier.normal, false), ('bat', Tier.highElite, false), ('orc', Tier.miniBoss, false), ('skeleton', Tier.normal, true)]);
    expect(mats.used, 2, reason: 'one draw for the slime, one for the bat\'s Rare; none for the mini boss and the raised one');
    expect([on.relicDrops, on.drops], everyElement(isEmpty));
    final tally = {Mat.slimeGel: 1, Mat.batWing: 1, Mat.batFang: 1, Mat.orcTooth: 3, Mat.orcTusk: 3, Mat.evilEye: 1};
    expect(on.waveMaterials, tally);
    expect([for (final (_, m, n) in on.matPops) (m, n)],
        unorderedEquals([(Mat.slimeGel, 1), (Mat.batWing, 1), (Mat.batFang, 1), (Mat.orcTooth, 3), (Mat.orcTusk, 3), (Mat.evilEye, 1)]));
    expect(on.materials, isEmpty, reason: 'not in the bag before the win');
    winNow(on);
    expect([on.materials, on.lastMaterials], [tally, tally]);
    expect(on.waveMaterials, isEmpty);
    // The next win adds to the bag, and its own tally is the last.
    on.matDice = _Dice([]); // the elite's Common always drops: no draw
    kill(on, [('slime', Tier.elite, false)]);
    winNow(on);
    expect(on.materials[Mat.slimeGel], 2);
    expect(on.lastMaterials, {Mat.slimeGel: 1});
  });

  test('relics and items never drop, on dice that always drop', () {
    final g = townGame(loot: _Dice([], 0.0), mats: _Dice([], 0.0));
    kill(g, [('orc', Tier.highElite, false), ('orc', Tier.miniBoss, false)]);
    expect([g.relicDrops, g.drops], everyElement(isEmpty));
    winNow(g);
    expect(g.relicBag, isEmpty);
  });

  test('the save: materials by name, only when any; a name this build doesn\'t know is skipped', () {
    final g = townGame()
      ..materials.addAll({Mat.slimeGel: 4, Mat.lichOrb: 1})
      ..wave = 9;
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect(j['materials'], {'slimeGel': 4, 'lichOrb': 1});
    expect(Game.fromJson(j).materials, {Mat.slimeGel: 4, Mat.lichOrb: 1});
    j['materials'] = {'slimeGel': 2, 'dragonScale': 5, 'skull': 0};
    expect(Game.fromJson(j).materials, {Mat.slimeGel: 2});
    expect(Game().toJson().containsKey('materials'), isFalse);
    expect(Game.fromJson(Game().toJson()).materials, isEmpty);
  });

  test('the telemetry: a won wave\'s record has the materials it dropped and its start the ones held', () {
    final kept = _Kept(), tel = TelemetryAdapter([kept], installId: 'i', session: 's', platform: 'test', now: () => DateTime.utc(2026, 10, 4));
    final g = townGame(mats: _Dice([], 0.0))..materials[Mat.skull] = 2;
    tel.attach(g);
    kill(g, [('slime', Tier.normal, false)]);
    winNow(g);
    final w = [for (final r in kept.records) if (r['rec'] == 'wave') r].single;
    expect([w['materials'], (w['start'] as Map)['materials']], [{'slimeGel': 1}, {'skull': 2}]);
    tel.detach();
  });
}
