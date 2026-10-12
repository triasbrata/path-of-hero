// The escort of the mini boss and the boss from wave 50 (#90, decisions-log 127): three healing necromancers
// and a high-elite necromancer right behind each of them, the healers healing their boss first.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show logLine;

/// A game without the free healer or monster skills, at wave [wave] (the next [Game.startWave] is wave + 1).
Game bare({int seed = 1, int wave = 0}) => Game(Random(seed))
  ..units.clear()
  ..slots = Random(seed)
  ..monsterSkills = false
  ..wave = wave;

/// The queue of wave [wave] for a game seeded with [seed].
List<(String, Tier)> queueOf(int wave, [int seed = 1]) => [...(bare(seed: seed, wave: wave - 1)..startWave()).queue];

/// Where each monster of [type] and [tier] is in [q].
List<int> at(List<(String, Tier)> q, String type, [Tier? tier]) =>
    [for (final (i, (t, r)) in q.indexed) if (t == type && (tier == null || r == tier)) i];

/// The escort as it is queued: three healers, then the high-elite necromancer.
bool isEscort(List<(String, Tier)> q, int from) =>
    [for (final (t, _) in q.sublist(from, from + 3)) t].every((t) => t == necroHealer) && q[from + 3] == (boss, Tier.highElite);

/// A troop of [type] at [at] that neither walks nor fights.
Unit standing(Game g, String type, Point<double> at) {
  final u = Unit(Side.troop, type, troopTypes[type]!, at)
    ..entered = true
    ..busyUntil = 1e9;
  g.units.add(u);
  return u;
}

/// A monster of [type] and [tier] at [at] that neither walks nor fights, with [hp] left (else full).
Unit still(Game g, String type, Point<double> at, {Tier tier = Tier.normal, double? hp}) {
  final u = g.monster(type, tier, at)..busyUntil = 1e9;
  if (hp != null) u.hp = hp;
  g.units.add(u);
  return u;
}

/// A healing necromancer at [at] with full MP, one of [lead]'s escort if given.
Unit mender(Game g, Point<double> at, [Unit? lead]) {
  final u = g.monster(necroHealer, Tier.normal, at)..escortOf = lead;
  g.units.add(u);
  return u;
}

void ticks(Game g, int n) {
  for (var i = 0; i < n; i++) {
    g.tick(0.05);
  }
}

void main() {
  test('the escort: from wave 50, three healers and a high-elite necromancer right behind the mini boss and the boss', () {
    expect((escortFrom, escortHealers, escortSummoners, escortSummonerTier), (50, 3, 1, Tier.highElite));
    for (var seed = 1; seed <= 5; seed++) {
      // Wave 49 (neither slot) and 48 (the mini boss): none.
      for (final w in [45, 48, 49]) {
        final q = queueOf(w, seed);
        expect(at(q, boss, Tier.highElite), isEmpty, reason: 'seed $seed wave $w');
        expect(at(q, necroHealer).length, necroHealersIn(w), reason: 'seed $seed wave $w');
      }
      // Wave 50: the boss, its escort, and the wave's last healer behind them (as before, #70).
      final fifty = queueOf(50, seed), b = fifty.indexWhere((m) => m.$2 == Tier.boss);
      expect(fifty.where((m) => m.$2 == Tier.boss).length, 1);
      expect(fifty.where((m) => m.$2 == Tier.miniBoss), isEmpty);
      expect(b, fifty.length - 6, reason: 'seed $seed');
      expect(isEscort(fifty, b + 1), isTrue, reason: 'seed $seed: ${fifty.sublist(b)}');
      expect(fifty.last.$1, necroHealer, reason: 'seed $seed');
      expect(at(fifty, necroHealer).length, necroHealersIn(50) + 3, reason: 'seed $seed');
      expect(at(fifty, boss, Tier.highElite).length, 1, reason: 'seed $seed');
      expect(fifty.length, 4 + 2 * 50 + 1 + 4 + necroHealersIn(50), reason: 'seed $seed');
      // Wave 51: the mini boss and its escort last.
      final fiftyOne = queueOf(51, seed), m = fiftyOne.indexWhere((e) => e.$2 == Tier.miniBoss);
      expect(m, fiftyOne.length - 5, reason: 'seed $seed');
      expect(isEscort(fiftyOne, m + 1), isTrue, reason: 'seed $seed');
      expect(at(fiftyOne, necroHealer).length, necroHealersIn(51) + 3, reason: 'seed $seed');
      // Wave 60 has both: two escorts, each behind its own, then the wave's last healer.
      final sixty = queueOf(60, seed), mini = sixty.indexWhere((e) => e.$2 == Tier.miniBoss);
      final top = sixty.indexWhere((e) => e.$2 == Tier.boss);
      expect((mini, top), (sixty.length - 11, sixty.length - 6), reason: 'seed $seed');
      expect((isEscort(sixty, mini + 1), isEscort(sixty, top + 1)), (true, true), reason: 'seed $seed');
      expect(sixty.last.$1, necroHealer, reason: 'seed $seed');
      expect(at(sixty, necroHealer).length, necroHealersIn(60) + 6, reason: 'seed $seed');
      expect(at(sixty, boss, Tier.highElite).length, 2, reason: 'seed $seed');
    }
  });

  test("the escort's healers roll the usual ranks (from the slots' dice), the rest of the wave is the same as without it", () {
    final ranks = <Tier>{};
    for (var seed = 1; seed <= 30; seed++) {
      final q = queueOf(60, seed);
      for (final i in [q.indexWhere((e) => e.$2 == Tier.miniBoss), q.indexWhere((e) => e.$2 == Tier.boss)]) {
        for (final (_, tier) in q.sublist(i + 1, i + 4)) {
          expect(tier.index, lessThanOrEqualTo(Tier.highElite.index), reason: 'seed $seed');
          ranks.add(tier);
        }
      }
    }
    expect(ranks, containsAll([Tier.normal, Tier.elite, Tier.highElite]));
    // Other slot dice change the escort's ranks (and the slots' types) but nothing else of the wave.
    List<(String, Tier)> rest(int slotSeed) {
      final g = bare(seed: 7, wave: 59)..slots = Random(slotSeed);
      g.startWave();
      return [for (final (i, e) in g.queue.indexed) if (i < 4 + 2 * 60 + necroHealersIn(60) - 1) e];
    }

    expect(rest(1), rest(2));
  });

  test('an escort comes on with its boss: the four right behind a mini boss or boss from wave 50 follow it', () {
    for (final w in [50, 51, 60]) {
      final g = bare(seed: 3, wave: w - 1)..startWave();
      g.queue.removeRange(0, g.queue.indexWhere((e) => e.$2 == Tier.miniBoss || e.$2 == Tier.boss)); // the slots on
      final n = g.queue.length, spawned = <Unit>[];
      for (var i = 0; i < 2000 && spawned.length < n; i++) {
        g.tick(0.05);
        for (final u in g.enemies.where((u) => u.raisedBy == null && !spawned.contains(u))) {
          spawned.add(u
            ..busyUntil = 1e9 // stands where it came on: nobody leaks
            ..entered = true);
        }
      }
      expect(spawned.length, n, reason: 'wave $w');
      final slots = spawned.where((u) => u.tier == Tier.miniBoss || u.tier == Tier.boss).toList();
      expect(slots.length, w == 60 ? 2 : 1, reason: 'wave $w');
      for (final s in slots) {
        final escort = spawned.where((u) => u.escortOf == s).toList();
        expect([for (final u in escort) u.type], [necroHealer, necroHealer, necroHealer, boss], reason: 'wave $w');
        expect(escort.last.tier, Tier.highElite, reason: 'wave $w');
        expect(spawned.indexOf(escort.first), spawned.indexOf(s) + 1, reason: 'wave $w');
      }
      // The wave's last healer on a boss wave is not one of it; the high elites have no name and no bar.
      if (w % bossEvery == 0) expect(spawned.last.escortOf, isNull, reason: 'wave $w');
      for (final u in spawned.where((u) => u.type == boss && u.tier == Tier.highElite)) {
        expect(u.name, '', reason: 'wave $w');
        expect(g.bossBarUnits, isNot(contains(u)), reason: 'wave $w');
      }
    }
    // Before wave 50 the same queue brings none.
    final g = bare(wave: 48)..startWave();
    g.queue
      ..clear()
      ..addAll([('werebear', Tier.miniBoss), (necroHealer, Tier.normal), (necroHealer, Tier.normal)]);
    for (var i = 0; i < 100 && g.queue.isNotEmpty; i++) {
      g.tick(0.05);
    }
    expect(g.enemies.map((u) => u.escortOf), [null, null, null]);
  });

  test('the high-elite necromancer: the strongest type\'s HP x3, 0.6 x 1.7 / 2.2 of its damage, no boss buff, '
      'MP 60 (+2/s), a high elite\'s gold', () {
    for (final wave in [10, 22, 50, 60, 80]) {
      final s = enemyStats(boss, Tier.highElite, wave), ref = enemyTypes[poolOf(wave).last]!;
      // The crowd's tide on top from wave 35 (#92): it is no slot.
      final hp = waveGrowth(wave, waveHp, waveHpLate) * tide(wave, tideHp), dmg = waveGrowth(wave, waveDmg, waveDmgLate) * tide(wave, tideDmg);
      expect(s.hp, (ref.hp * Tier.highElite.hp * hp).round(), reason: '$wave');
      expect(s.dmg, closeTo(bossStats.dmg * necroMiniDmg * 1.7 / 2.2 * dmg, 1e-9), reason: '$wave');
      expect((s.mp, s.mpRegen, s.cost), (60, 2.0, killGold(bossStats.cost, Tier.highElite, wave)), reason: '$wave');
      expect(s.speed, closeTo(enemyStats(boss, Tier.boss, wave).speed * Tier.highElite.speed, 1e-9), reason: '$wave');
      if (wave >= 22) expect(s.hp, enemyStats('werebear', Tier.highElite, wave).hp, reason: '$wave'); // a high-elite werebear's
    }
    expect(enemyStats(boss, Tier.highElite, 50).hp, 15470); // 320 x 3 x 13.88 x 1.1610 (the tide; waveHp 0.17, decisions-log 318)
    expect(enemyStats(boss, Tier.highElite, 50).dmg, closeTo(80.0, 0.1)); // 13.9 x 5.34 x 1.0778
    // Below the mini boss necromancer in all of it (the buff's MP included).
    final mini = enemyStats(boss, Tier.miniBoss, 50), high = enemyStats(boss, Tier.highElite, 50);
    expect((high.hp < mini.hp, high.dmg < mini.dmg, high.mp < mini.mp, high.mpRegen < mini.mpRegen), (true, true, true, true));
    expect((summonCeiling(Tier.highElite, 50), summonCeiling(Tier.highElite, 9)), (Tier.elite, Tier.normal));
    expect((killScore[Tier.highElite], relicChance[Tier.highElite]), (50, 0.05));
    expect(logLine(StrongFoe(50, 1, type: boss, tier: Tier.highElite)), '${tierNames[Tier.highElite]} appears: ${monsterTypeNames[boss]}');
  });

  test('the high-elite necromancer comes on with a quarter of its MP and raises up to elites', () {
    final g = bare(wave: 50);
    final u = g.monster(boss, Tier.highElite, const Point(250, 60));
    expect(u.mp, 15);
    g.units.add(u
      ..mp = 60
      ..summonCd = 0);
    g.tick(0.05);
    expect(g.minionsOf(u).map((m) => m.tier), [Tier.elite, Tier.elite]); // nobody near: its best, 2 elites for 44
    expect(u.mp, closeTo(60 - 2 * summonCost[Tier.elite]!, 0.2));
  });

  test("an escort's healer heals its boss first, even when another is more hurt; the others heal as before", () {
    final g = bare(wave: 50);
    final lead = still(g, 'werebear', const Point(200, 60), tier: Tier.boss);
    lead.hp = lead.maxHp * 0.9;
    final orc = still(g, 'orc', const Point(220, 90), hp: 10);
    final own = mender(g, const Point(250, 60), lead), other = mender(g, const Point(250, 100));
    g.tick(0.05);
    expect((lead.healedBy, orc.healedBy), (own, other));
    // Full, it heals the most hurt like any other.
    final h = bare(wave: 50);
    final boss2 = still(h, 'werebear', const Point(200, 60), tier: Tier.boss);
    final orc2 = still(h, 'orc', const Point(220, 90), hp: 10);
    final own2 = mender(h, const Point(250, 60), boss2);
    h.tick(0.05);
    expect((boss2.healedBy, orc2.healedBy), (null, own2));
  });

  test("heals still don't stack (#78): of three escort healers one heals the boss, the others the next most hurt", () {
    final g = bare(wave: 50);
    final lead = still(g, 'werebear', const Point(200, 60), tier: Tier.boss);
    lead.hp = lead.maxHp * 0.5;
    final a = still(g, 'orc', const Point(220, 40), hp: 30), b = still(g, 'orc', const Point(220, 80), hp: 20);
    final escort = [for (final y in [40.0, 60.0, 80.0]) mender(g, Point(250, y), lead)];
    final before = lead.hp;
    g.tick(0.05);
    expect(lead.hp, before + escort.first.stats.dmg); // one heal only
    expect(lead.healedBy, escort.first);
    expect({a.healedBy, b.healedBy}, {escort[1], escort[2]});
  });

  test("an escort's healer heals its boss under archer fire (only melee troops keep it away, #90), from behind it and "
      'within its heal range; a plain healer doesn\'t go there', () {
    expect((escortMeleeOnly, escortReach), (true, 64.0));
    for (final escorting in [true, false]) {
      final g = bare(wave: 50);
      final lead = still(g, 'werebear', const Point(150, 60), tier: Tier.boss);
      lead.hp = lead.maxHp * 0.5;
      final archer = standing(g, 'archer', const Point(130, 60)); // its reach and margin cover every heal spot
      final u = mender(g, const Point(270, 60), escorting ? lead : null);
      for (var i = 0; i < 200 && lead.healedBy == null; i++) {
        g.tick(0.05);
        if (escorting) expect(u.pos.x, greaterThanOrEqualTo(lead.pos.x), reason: 'never past its boss');
      }
      expect(lead.healedBy, escorting ? u : isNull, reason: '$escorting');
      if (escorting) {
        expect(u.pos.distanceTo(lead.pos), lessThanOrEqualTo(u.stats.range));
        expect(u.pos.distanceTo(archer.pos), lessThan(archer.stats.range + necroSafety)); // in its reach
      }
    }
  });

  test("an escort's healer never walks into melee troops to reach its boss: it heals another it can safely reach", () {
    final g = bare(wave: 50);
    final lead = still(g, 'werebear', const Point(100, 60), tier: Tier.boss);
    lead.hp = lead.maxHp * 0.5;
    // Knights round the boss: every heal spot behind it within range is in their reach and margin.
    for (final at in [const Point(125.0, 60.0), const Point(125.0, 30.0), const Point(125.0, 90.0), const Point(140.0, 60.0)]) {
      standing(g, 'knight', at);
    }
    final orc = still(g, 'orc', const Point(240, 100), hp: 10);
    final u = mender(g, const Point(260, 60), lead);
    final hp = lead.hp;
    for (var i = 0; i < 100 && orc.healedBy == null; i++) {
      g.tick(0.05);
    }
    expect((lead.hp, orc.healedBy), (hp, u));
    expect(u.pos.x, greaterThan(140 + troopTypes['knight']!.range + necroSafety - 1));
  });

  test("with nobody to heal an escort's healers rest a tile behind their boss, a lane apart round its lane, out of "
      "the troops' reach; once it falls they rest like any other", () {
    final g = bare(wave: 50);
    final lead = still(g, 'werebear', const Point(150, 60), tier: Tier.boss);
    still(g, 'slime', const Point(220, 100)); // the rearmost monster
    final escort = [for (final y in [20.0, 60.0, 100.0]) mender(g, Point(260, y), lead)];
    final plain = mender(g, const Point(260, 30));
    ticks(g, 200);
    expect([for (final u in escort) u.pos.x], everyElement(closeTo(150 + tile, 1)));
    expect([for (final u in escort) u.pos.y], [closeTo(60 - tile, 1), closeTo(60, 1), closeTo(60 + tile, 1)]);
    expect(plain.pos.x, closeTo(220 + tile, 1)); // behind the rearmost, as before
    // An archer covering them doesn't move them (#90: only melee troops keep an escort's healers away).
    final archer = standing(g, 'archer', const Point(110, 60));
    ticks(g, 200);
    expect([for (final u in escort) u.pos.x], everyElement(closeTo(150 + tile, 1)));
    // A knight near the boss: they rest further back, out of its reach and the margin, within [escortReach].
    archer.gone = true;
    final knight = standing(g, 'knight', const Point(125, 60));
    ticks(g, 200);
    for (final u in escort) {
      expect(u.pos.distanceTo(knight.pos), greaterThan(knight.stats.range + necroSafety - 1));
      expect(u.pos.x - lead.pos.x, inInclusiveRange(tile, escortReach));
    }
    // Its boss gone, they go back behind the rearmost monster.
    lead.gone = true;
    knight.gone = true;
    ticks(g, 300);
    expect([for (final u in escort) u.pos.x], everyElement(closeTo(220 + tile, 3)));
  });
}
