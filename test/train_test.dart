// Train (decisions-log 334, lib/train.dart; docs/loot-items-relics.md "Train"): the gate (every item of the three grade sets
// at +5, the Cap and Ring and extra copies aside, a kept level still asking it, a +5 copy never swapped out), each
// attribute's level, the caps (the attack floor, the walk cap, the reach caps; a Hero's x3, the aura and boots never past
// them), the price and the material taken, the refusals in order, the buy and its refit, Lepas jenis keeping the levels,
// the save, the Army tab's dot, the tooltip, the log and the telemetry. The section on the Army detail: train_hud_test.dart.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show logLine;
import 'package:tower_defense/telemetry.dart';

import 'hero_skill_helpers.dart';
import 'hud_font.dart';
import 'real_rules.dart';

/// Puts [type]'s three grade sets on it in [g], all but [short] of them at +5 (the rest +0).
void fillSets(Game g, String type, {int short = 0}) {
  final sets = g.trainItems(type);
  g.upgrades[type] = [for (final MapEntry(key: i, value: n) in sets.entries) ...List.filled(n, i)];
  var left = sets.values.fold(0, (a, n) => a + n) - short;
  final pluses = <Item, List<int>>{};
  for (final MapEntry(key: i, value: n) in sets.entries) {
    final k = min(n, left);
    left -= k;
    if (k > 0) pluses[i] = List.filled(k, 5);
  }
  g.upgradePlus[type] = pluses;
}

/// A game after wave 90 with [gold] and plenty of every material, [type]'s sets on it at +5: Train open.
Game atGate(String type, [int gold = 100000000]) {
  final g = bareGame()
    ..wave = 90
    ..gold = gold;
  for (final m in trainParts.values) {
    g.materials[m] = 1000;
  }
  fillSets(g, type);
  return g;
}

/// Wins the next wave of [g] at once: begun with nothing to spawn, its one monster gone in the tick (tempa_test.dart).
void win(Game g) {
  g
    ..startWave()
    ..queue.clear()
    ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true)
    ..tick(0.05);
  expect((g.waveActive, g.over), (false, false));
}

/// A sink that keeps the records, through JSON.
class _Kept implements TelemetrySink {
  final records = <Map<String, dynamic>>[];

  @override
  void add(Map<String, Object?> record) => records.add(jsonDecode(jsonEncode(record)) as Map<String, dynamic>);

  @override
  Future<void> flush() async {}
}

/// The levels [stat] takes from [g]'s [type] as it stands until its cap: bought one by one until it is capped.
int levelsToCap(Game g, String type, TrainStat stat) {
  var n = 0;
  while (!g.trainCapped(type, stat) && n < trainMax) {
    (g.train[type] ??= {})[stat] = ++n;
  }
  return n;
}

void main() {
  test('the constants: +5% a level (+2.5 defence, +10% for the capped three), 15% of a purse x1.2 a level, a part a '
      'level and one more every second, a guard at 50, one screen for a shooter\'s reach', () {
    expect((trainPct, trainDef, trainFast, trainMax), (0.05, shieldDef, 0.1, 50));
    expect((trainK, trainRise, trainRound, trainReachMost), (0.15, 1.2, 1000, 320.0));
    expect([for (var n = 0; n < 7; n++) trainPartCount(n)], [1, 1, 2, 2, 3, 3, 4]);
    expect(trainParts, {
      TrainStat.hp: Mat.bearClaw,
      TrainStat.power: Mat.orcHeart,
      TrainStat.defence: Mat.ironTusk,
      TrainStat.mp: Mat.tealGem,
      TrainStat.mpRegen: Mat.darkGem,
      TrainStat.rate: Mat.wolfFang,
      TrainStat.speed: Mat.wargFang,
      TrainStat.range: Mat.boneBow,
    });
    expect([for (final s in TrainStat.values) trainGain(s)], ['+5%', '+5%', '+2.5', '+5%', '+5%', '-9%', '+10%', '+10%']);
    expect([for (final s in TrainStat.values) trainStatName(s)], ['HP', 'Dmg', 'Def', 'MP', 'MP regen', 'Rate', 'Speed', 'Range']);
    expect(trainStatName(TrainStat.power, heals: true), 'Heal');
  });

  test('the prices: wave 90 20k, 23k, 28k, 34k, 40k, 101k at level 10, 623k at 20; wave 60 3k; never under 1k', () {
    expect([for (var n = 0; n < 5; n++) trainPrice(90, n)], [20000, 23000, 28000, 34000, 40000]);
    expect((trainPrice(90, 9), trainPrice(90, 19)), (101000, 623000));
    expect([for (final n in [0, 4, 9]) trainPrice(60, n)], [3000, 7000, 18000]);
    expect(trainPrice(1, 0), trainRound);
    final g = atGate('knight');
    expect(g.trainCostOf('knight', TrainStat.hp), (gold: 20000, mat: Mat.bearClaw, n: 1));
    g.train['knight'] = {TrainStat.hp: 4};
    expect(g.trainCostOf('knight', TrainStat.hp), (gold: 40000, mat: Mat.bearClaw, n: 3));
    expect(g.trainCostOf('knight', TrainStat.power), (gold: 20000, mat: Mat.orcHeart, n: 1), reason: 'each attribute its own ladder');
    g.wave = 100;
    expect(g.trainCostOf('knight', TrainStat.hp)!.gold, trainPrice(100, 4), reason: "the wave's purse, now");
    g.train['knight'] = {TrainStat.hp: trainMax};
    expect(g.trainCostOf('knight', TrainStat.hp), isNull);
  });

  test('the gate: every item of the three grade sets at +5; one short, or +0, keeps it shut; how far it is', () {
    final g = bareGame();
    expect((g.trainOpen('knight'), g.trainProgress('knight')), (false, (0, 31)));
    expect([for (final t in troopTypes.keys) g.trainProgress(t).$2], [27, 31, 31, 31, 32, 36, 32, 34, 32]);
    g.upgrades['knight'] = awakenItems('knight', maxAwaken);
    expect((g.awakenLevel('knight'), g.trainOpen('knight'), g.trainProgress('knight')), (maxAwaken, false, (0, 31)));
    fillSets(g, 'knight', short: 1);
    expect((g.trainOpen('knight'), g.trainProgress('knight')), (false, (30, 31)));
    fillSets(g, 'knight');
    expect((g.trainOpen('knight'), g.trainProgress('knight')), (true, (31, 31)));
    expect(g.awakenLevel('knight'), maxAwaken, reason: 'Awaken 4-5 not asked');
    // A plus under the top (+4) is not +5.
    g.upgradePlus['knight'] = {for (final MapEntry(:key, :value) in g.upgradePlus['knight']!.entries) key: [for (final _ in value) 4]};
    expect((g.trainOpen('knight'), g.trainProgress('knight')), (false, (0, 31)));
  });

  test('the gate leaves out the Cap and the Ring and copies past a set; a kept level still asks for the sets', () {
    final g = bareGame();
    fillSets(g, 'knight');
    g.upgrades['knight'] = [...g.upgrades['knight']!, Item.leatherCap, Item.ring, Item.sword, Item.sword];
    expect(g.trainOpen('knight'), isTrue, reason: 'a +0 Cap, Ring and two more grade-I Swords change nothing');
    // A save from before the grades: Awaken 3 kept from 30 grade-I items, no set held.
    final old = bareGame()
      ..awakenKept['knight'] = maxAwaken
      ..upgrades['knight'] = [for (final MapEntry(key: i, value: n) in awakenRecipe['knight']!.entries) ...List.filled(n * maxAwaken, i)];
    expect((old.awakenLevel('knight'), old.trainOpen('knight')), (maxAwaken, false));
    expect(old.trainProgress('knight'), (0, 31));
    final kept = old.upgrades['knight']!;
    fillSets(old, 'knight');
    old.upgrades['knight'] = [...kept, ...old.upgrades['knight']!];
    expect((old.awakenLevel('knight'), old.trainOpen('knight')), (maxAwaken, true));
  });

  test('once open it stays: no item takes a +5 copy\'s place (Enhance swaps out only a lower plus)', () {
    final g = atGate('knight');
    for (final item in g.trainItems('knight').keys) {
      g.enhancedBag[(item, 5)] = 1;
      expect((g.swapOut('knight', item, 5), g.whyNot(item, 'knight', plus: 5)), (null, Refusal.maxed), reason: '$item');
      expect(g.useItem(item, 'knight', plus: 5), isFalse);
    }
    expect(g.trainOpen('knight'), isTrue);
  });

  test('HP, power, MP and MP regen x1.05 a level, compounding; defence +2.5; nothing else moves; counted only while open', () {
    for (final type in ['knight', 'priest', 'armored_axeman']) {
      final g = atGate(type), own = g.statsOf(type);
      final heavy = heavyTypes.contains(type) ? 1 + heavyBuff : 1.0;
      for (final n in [1, 6, 30]) {
        g.train[type] = {for (final s in [TrainStat.hp, TrainStat.power, TrainStat.defence, TrainStat.mp, TrainStat.mpRegen]) s: n};
        final s = g.statsOf(type), k = pow(1.05, n);
        expect(s.hp, closeTo(own.hp * k, heavy > 1 ? 1.5 + 0.6 * k : 0.5), reason: '$type $n');
        expect(s.dmg, closeTo(own.dmg * k, 1e-6 * own.dmg * k), reason: '$type $n');
        expect(s.def, closeTo(own.def + trainDef * n * heavy, 1e-9), reason: '$type $n: a Shield a level, the heavy +20% after');
        expect(s.mp, closeTo(own.mp * k, 0.5), reason: '$type $n');
        expect(s.mpRegen, closeTo(own.mpRegen * k, 1e-9), reason: '$type $n');
        expect((s.rate, s.speed, s.range, s.regen, s.splash), (own.rate, own.speed, own.range, own.regen, own.splash));
      }
      // Shut again (a town.json raising Enhance's top, say): the levels wait.
      g.upgradePlus[type] = {};
      expect((g.trainOpen(type), g.trainOf(type, TrainStat.hp), g.statsOf(type).hp < own.hp + 1), (false, 0, true));
    }
  });

  test('the caps at the gate: the attack floor (only the Templar has room, 13 levels), the walk cap (8, 19 or none), the '
      'reach caps (melee its reach cap, the rest one screen)', () {
    final rate = <String, int>{}, walk = <String, int>{}, reach = <String, int>{};
    for (final type in troopTypes.keys) {
      for (final (stat, into) in [(TrainStat.rate, rate), (TrainStat.speed, walk), (TrainStat.range, reach)]) {
        into[type] = levelsToCap(atGate(type), type, stat);
      }
    }
    expect(rate, {for (final t in troopTypes.keys) t: t == 'knight_templar' ? 13 : 0});
    expect(walk, {'soldier': 8, 'knight': 0, 'swordsman': 0, 'archer': 8, 'lancer': 0, 'priest': 19, 'armored_axeman': 8, 'wizard': 19, 'knight_templar': 0});
    expect(reach, {'soldier': 0, 'knight': 7, 'swordsman': 8, 'archer': 0, 'lancer': 3, 'priest': 0, 'armored_axeman': 7, 'wizard': 0, 'knight_templar': 0});
    // At the cap the stat stands on it, never past.
    final t = atGate('knight_templar')..train['knight_templar'] = {TrainStat.rate: 13};
    expect(t.statsOf('knight_templar').rate, minAttackInterval);
    t.train['knight_templar'] = {TrainStat.rate: 12};
    expect(t.statsOf('knight_templar').rate, greaterThan(minAttackInterval));
    final p = atGate('priest')..train['priest'] = {TrainStat.speed: 19};
    expect(p.statsOf('priest').speed, walkCap('priest'));
    final k = atGate('knight')..train['knight'] = {TrainStat.range: 7};
    expect(k.statsOf('knight').range, meleeMaxRange);
    final l = atGate('lancer')..train['lancer'] = {TrainStat.range: 3};
    expect(l.statsOf('lancer').range, closeTo(meleeMaxRange * 1.5, 1e-9), reason: "its spears' raised cap");
    // Already past a cap (bows, boots): left as it is, never cut.
    final a = atGate('archer'), before = a.statsOf('archer').range;
    a.train['archer'] = {TrainStat.range: 5};
    expect((a.statsOf('archer').range, before > trainReachMost), (before, true));
    // Levels bought past a cap (a save, say) change nothing more.
    k.train['knight'] = {TrainStat.range: 20};
    expect(k.statsOf('knight').range, meleeMaxRange);
  });

  test('the Range row hides where reach can\'t rise at the gate (the owner: "Sembunyikan baris Range"), by the rule; Rate '
      'and Speed show Max instead', () {
    expect({for (final t in troopTypes.keys) t: atGate(t).trainShown(t, TrainStat.range)},
        {'soldier': false, 'knight': true, 'swordsman': true, 'archer': false, 'lancer': true, 'priest': false, 'armored_axeman': true, 'wizard': false, 'knight_templar': false});
    final k = atGate('knight')..train['knight'] = {TrainStat.range: 7};
    expect((k.trainCapped('knight', TrainStat.range), k.trainShown('knight', TrainStat.range)), (true, true), reason: 'raised to its cap: Max');
    for (final t in troopTypes.keys) {
      for (final stat in TrainStat.values.where((s) => s != TrainStat.range)) {
        expect(atGate(t).trainShown(t, stat), isTrue, reason: '$t $stat');
      }
    }
  });

  test("a Hero's x3, the aura and boots never take a capped stat past its cap", () {
    final g = atGate('priest')..train['priest'] = {TrainStat.speed: 19};
    final h = placeNow(g, 'priest', 0, 3)
      ..hero = true
      ..heroStats = [HeroStat.speed, HeroStat.range];
    g.trainUp('priest', TrainStat.hp); // refits it
    expect(h.stats.speed, greaterThan(walkCap('priest')), reason: 'the stat x3');
    expect(h.walkSpeed, walkCap('priest'), reason: 'its walk stops at the cap');
    final k = atGate('knight')..train['knight'] = {TrainStat.range: 7};
    placeNow(k, 'knight', 2, 3);
    placeNow(k, 'soldier', 2, 4)
      ..hero = true
      ..heroStats = [HeroStat.hp, HeroStat.power];
    expect(k.heroAlive, isTrue);
    expect(k.fieldStats('knight').range, meleeMaxRange, reason: "the aura stops at a melee fighter's reach cap");
    final t = atGate('knight_templar')..train['knight_templar'] = {TrainStat.rate: 13};
    final u = placeNow(t, 'knight_templar', 2, 3);
    placeNow(t, 'soldier', 2, 4)
      ..hero = true
      ..heroStats = [HeroStat.hp, HeroStat.power];
    t.trainUp('knight_templar', TrainStat.hp);
    expect(t.attackEvery(u), minAttackInterval, reason: 'the aura on the floor: still the floor');
  });

  test('the refusals, in order: the store closed (before wave 15, mid-wave, game over), the gate, the cap, the guard, the '
      'material, the gold', () {
    final g = atGate('knight')..wave = storeFrom - 1;
    expect(g.whyNotTrain('knight', TrainStat.hp), storeRefusalNames[StoreRefusal.locked]);
    g.wave = 90;
    expect(g.whyNotTrain('knight', TrainStat.hp), isNull);
    expect(g.whyNotTrain('archer', TrainStat.hp), 'Needs every item +5');
    expect(g.whyNotTrain('knight', TrainStat.rate), 'Max: attack floor');
    expect(g.whyNotTrain('knight', TrainStat.speed), 'Max: walk cap');
    expect(atGate('archer').whyNotTrain('archer', TrainStat.range), 'Max: reach cap');
    g.startWave();
    expect(g.whyNotTrain('knight', TrainStat.hp), storeRefusalNames[StoreRefusal.midWave], reason: 'the store first');
    g.queue.clear();
    g.tick(0.05);
    g.materials[Mat.bearClaw] = 0;
    expect(g.whyNotTrain('knight', TrainStat.hp), 'Need 1 Bear Claw');
    g
      ..train['knight'] = {TrainStat.hp: 2}
      ..materials[Mat.bearClaw] = 1;
    expect(g.whyNotTrain('knight', TrainStat.hp), 'Need 1 more Bear Claw');
    g
      ..materials[Mat.bearClaw] = 2
      ..gold = g.trainCostOf('knight', TrainStat.hp)!.gold - 1;
    expect(g.whyNotTrain('knight', TrainStat.hp), 'Not enough gold');
    final gold = g.gold;
    expect((g.trainUp('knight', TrainStat.hp), g.gold, g.train['knight']![TrainStat.hp], g.materials[Mat.bearClaw], g.sfx.last),
        (false, gold, 2, 2, Sfx.error));
    g
      ..train['knight'] = {TrainStat.hp: trainMax}
      ..gold = 1 << 40;
    expect(g.whyNotTrain('knight', TrainStat.hp), 'Max: Lv 50');
    g.lives = 0;
    expect(g.whyNotTrain('knight', TrainStat.hp), storeRefusalNames[StoreRefusal.over]);
  });

  test("buying: the gold and the material go, every living troop of the type is refit and bursts, it is logged; the "
      'next level costs more', () {
    final g = atGate('knight');
    final k = placeNow(g, 'knight', 2, 3), other = placeNow(g, 'archer', 0, 2);
    final own = g.statsOf('knight'), otherHp = other.maxHp;
    k.hp = k.maxHp - 30.0;
    final gold = g.gold;
    expect(g.trainUp('knight', TrainStat.hp), isTrue);
    expect((g.gold, g.materials[Mat.bearClaw], g.trainOf('knight', TrainStat.hp)), (gold - 20000, 999, 1));
    expect(g.train['knight'], {TrainStat.hp: 1});
    expect(g.statsOf('knight').hp, (own.hp * 1.05).round());
    expect(k.maxHp, g.statsOf('knight').hp);
    expect(k.hp, closeTo(k.maxHp - 30, 1e-9), reason: 'the HP gained comes with it');
    expect(other.maxHp, otherHp, reason: 'another type');
    expect(g.impacts.last, (k.pos, awakeFx('upgrade', maxAwaken)));
    expect(g.sfx.sublist(g.sfx.length - 2), [Sfx.magic, Sfx.clear]);
    final e = g.log.entries.whereType<Trained>().single;
    expect(e.toJson(), {
      'v': eventVersion, 'kind': 'trained', 'wave': 90, 't': g.t, //
      'type': 'knight', 'stat': 'hp', 'level': 1, 'cost': 20000, 'mat': 'bearClaw', 'n': 1,
    });
    expect(eventVersion, 19);
    expect(logLine(e), 'Knight: Train HP Lv 1 (20k gold, 1 Bear Claw)');
    expect(g.trainUp('knight', TrainStat.hp), isTrue);
    expect(g.trainUp('knight', TrainStat.hp), isTrue);
    expect((g.gold, g.materials[Mat.bearClaw], g.trainOf('knight', TrainStat.hp)), (gold - 20000 - 23000 - 28000, 999 - 1 - 2, 3));
    final p = atGate('priest');
    expect(p.trainUp('priest', TrainStat.power), isTrue);
    expect(logLine(p.log.entries.whereType<Trained>().single), 'Priest: Train Heal Lv 1 (20k gold, 1 Orc Heart)');
  });

  test('Lepas jenis keeps the levels and refunds none of them; bought again, the type fights with them', () {
    final g = atGate('knight');
    placeNow(g, 'knight', 2, 3);
    final price = g.priceOf('knight');
    g
      ..trainUp('knight', TrainStat.hp)
      ..trainUp('knight', TrainStat.power);
    expect(g.priceOf('knight'), price, reason: 'no dearer');
    final gold = g.gold, refund = g.releaseRefundOf('knight');
    expect(refund, (price * releaseRefund).round());
    expect(g.releaseType('knight'), refund);
    expect(g.gold, gold + refund);
    expect(g.train['knight'], {TrainStat.hp: 1, TrainStat.power: 1});
    expect(placeNow(g, 'knight', 1, 3).maxHp, g.statsOf('knight').hp);
  });

  test('the save keeps the levels as `train {type: {stat: n}}`, before the troops come in; an old save has none', () {
    final g = atGate('knight');
    final k = placeNow(g, 'knight', 2, 3);
    g
      ..trainUp('knight', TrainStat.hp)
      ..trainUp('knight', TrainStat.hp)
      ..trainUp('knight', TrainStat.range);
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect(j['train'], {
      'knight': {'hp': 2, 'range': 1},
    });
    expect(j['v'], 3, reason: 'additive');
    final back = Game.fromJson(j);
    expect(back.train, {
      'knight': {TrainStat.hp: 2, TrainStat.range: 1},
    });
    expect((back.trainOpen('knight'), back.trainOf('knight', TrainStat.hp)), (true, 2));
    final u = back.troops.single;
    expect((u.maxHp, u.hp), (k.maxHp, k.hp), reason: 'loaded at its Train HP');
    // Written back the same (from the loaded game: a test's materials have no `matsSeen` until a load gives them one).
    expect(jsonEncode(Game.fromJson(jsonDecode(jsonEncode(back.toJson())) as Map<String, dynamic>).toJson()), jsonEncode(back.toJson()));
    expect((back.toJson()['train'] as Map)['knight'], {'hp': 2, 'range': 1});
    final old = Game.fromJson(Map.of(j)..remove('train'));
    expect(old.train, isEmpty);
    expect(old.toJson().containsKey('train'), isFalse);
    expect(bareGame().toJson().containsKey('train'), isFalse);
    final odd = Game.fromJson(Map.of(j)
      ..['train'] = {
        'orc': {'hp': 1},
        'knight': {'hp': 99, 'luck': 3, 'mp': 0, 'power': 'x'},
        'priest': 7,
      });
    expect(odd.train, {
      'knight': {TrainStat.hp: trainMax},
    });
  });

  test("the Army tab's dot: gold at 3 purses and a fielded type that can buy a Train level", () {
    final g = atGate('knight')..ascended['knight'] = maxAscend;
    placeNow(g, 'knight', 2, 3);
    g.tempa['knight'] = tempaMax; // Forge done: only Train is left
    g.gold = nudgePurses * purse(91);
    expect(g.armyNudge, isTrue);
    g.gold -= 1;
    expect(g.armyNudge, isFalse, reason: 'not yet 3 purses');
    g.gold += 1;
    for (final m in trainParts.values) {
      g.materials[m] = 0;
    }
    expect(g.armyNudge, isFalse, reason: 'no material: nothing it can buy');
  });

  test('the tooltip: what a level gives, its cap, the levels, the price or the Max', () {
    final g = atGate('knight');
    expect(g.trainInfo('knight', TrainStat.hp).$1, 'Train HP');
    expect(g.trainInfo('knight', TrainStat.hp).$2, ['+5% HP a level', 'Stacks each level', 'All troops of this type, now and later', 'Price: 20,000 gold, 1 Bear Claw']);
    g.train['knight'] = {TrainStat.range: 2};
    expect(g.trainInfo('knight', TrainStat.range).$2, ['+10% Range a level', 'Stacks up to its cap', 'All troops of this type, now and later', 'Now: Lv 2', 'Price: 28,000 gold, 2 Bone Bow']);
    expect(g.trainInfo('knight', TrainStat.rate).$2.last, 'Max: attack floor');
    expect(g.trainInfo('knight', TrainStat.defence).$2.first, '+2.5 defense a level');
    expect(atGate('priest').trainInfo('priest', TrainStat.power).$1, 'Train Heal');
  });

  test('telemetry: the event is passed on, and the next wave\'s record has gold.trainSpent and the material used', () {
    final g = atGate('knight');
    placeNow(g, 'knight', 2, 3);
    final kept = _Kept();
    TelemetryAdapter([kept], installId: 'i', session: 's', platform: 'test', now: () => DateTime.utc(2026, 10, 13)).attach(g);
    g
      ..trainUp('knight', TrainStat.hp)
      ..trainUp('knight', TrainStat.hp)
      ..trainUp('knight', TrainStat.hp);
    win(g);
    final events = [for (final r in kept.records.where((r) => r['rec'] == 'event')) r['event'] as Map<String, dynamic>];
    expect([for (final e in events.where((e) => e['kind'] == 'trained')) (e['stat'], e['level'], e['cost'], e['n'])],
        [('hp', 1, 20000, 1), ('hp', 2, 23000, 1), ('hp', 3, 28000, 2)]);
    final w = kept.records.lastWhere((r) => r['rec'] == 'wave');
    expect((w['wave'], (w['gold'] as Map)['trainSpent'], (w['materialsUsed'] as Map)['bearClaw'], w['tv']), (91, 71000, 4, telemetryVersion));
    expect(telemetryVersion, 19);
    win(g);
    expect((kept.records.lastWhere((r) => r['rec'] == 'wave')['gold'] as Map)['trainSpent'], 0);
  });

  test("every line Train shows is in the HUD's font", () {
    final font = fontChars();
    final g = atGate('knight')..train['knight'] = {TrainStat.hp: 3};
    final lines = <String>[
      trainRefusals.closed, trainRefusals.floor, trainRefusals.walk, trainRefusals.reach, trainRefusals.maxed,
      'Train: every item +5', 'Train: needs every item +5 (30/34)', 'Train: +5 all (30/34)', 'Max',
      for (final s in TrainStat.values) ...[trainStatName(s), trainGain(s), ...g.trainInfo('knight', s).$2, g.trainInfo('knight', s).$1],
      'Knight: Train HP Lv 4!', 'Lv 0', '20k', '101k',
    ];
    for (final l in lines) {
      expect(l.runes.where((r) => !font.contains(r)).map(String.fromCharCode).toList(), isEmpty, reason: l);
    }
  });
}
