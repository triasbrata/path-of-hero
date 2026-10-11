// #76: a game run from the same seeds is the same run, so balance probes can compare numbers. Every die a
// game rolls is one of its own ([Game.rng], names, loot, heroes, slots); nothing else (a clock, an unseeded
// Random, hash order) may feed play. Two runs from the same seeds are compared wave by wave.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

/// A game's state after a wave, as one line: the numbers, every unit, the bag and who fell.
String digest(Game g) => [
      'wave ${g.wave} t ${g.t} gold ${g.gold} lives ${g.lives} kills ${g.kills} score ${g.score} over ${g.over} '
          'cam ${g.cam} mid ${g.viewMid}',
      for (final u in g.units)
        '${u.side.name} ${u.type} ${u.tier.name} ${u.alive} hp ${u.hp}/${u.maxHp} mp ${u.mp} at ${u.pos.x},${u.pos.y} '
            '${u.heroSkill?.name} ${u.heroStats.map((s) => s.name).join('+')} ${u.relics.map((r) => r.name).join('+')}',
      '${g.inventory} ${g.relicBag} fell ${g.fallen.map((u) => u.name).join(',')}',
    ].join('\n');

/// Plays [waves] waves of [g] as a player who only buys and gives: before each wave it buys [buy] as gold and
/// room allow and gives every item to the first type that takes it, then lets the army settle. A digest a wave;
/// [each] runs after every tick.
List<String> play(Game g, int waves, List<String> buy, [void Function(Game)? each]) {
  final out = <String>[];
  for (var w = 0; w < waves && !g.over; w++) {
    for (final t in buy) {
      if (g.gold >= g.priceOf(t)) g.autoPlace(t);
    }
    for (final item in Item.values) {
      final type = troopTypes.keys.where((t) => g.canUse(item, t)).firstOrNull;
      while (type != null && (g.inventory[item] ?? 0) > 0 && g.useItem(item, type)) {}
    }
    for (var i = 0; i < 300; i++) {
      g.tick(1 / 30); // walk in and settle
      each?.call(g);
    }
    g.startWave();
    for (var i = 0; i < 30 * 600 && g.waveActive && !g.over; i++) {
      g.tick(1 / 30);
      each?.call(g);
    }
    out.add(digest(g));
  }
  return out;
}

/// A save at wave [wave] with two of every troop type, 20 of each item in the bag, and three Heroes from before
/// the skills and #69: attack rate among their attributes and no skill, so loading rolls both.
Map<String, dynamic> oldSave(int wave) {
  final g = Game(Random(1), Random(2))
    ..gold = 1000000
    ..capacity = 20
    ..wave = wave;
  for (var i = 0; i < 2; i++) {
    for (final t in troopTypes.keys) {
      expect(g.autoPlace(t), isTrue, reason: t);
    }
  }
  for (final t in ['knight', 'archer', 'priest']) {
    g.troops.firstWhere((u) => u.type == t)
      ..hero = true
      ..heroStats = [HeroStat.rate, heroPoolOf(t).first];
  }
  for (final item in Item.values) {
    g.inventory[item] = 20;
  }
  g.gold = 3000;
  return jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
}

void main() {
  test('a Hero from an older save rolls its missing attribute and skill on load with the dice passed to fromJson: the same dice, the same picks', () {
    final save = oldSave(20);
    String picks(Game g) => [for (final u in g.troops.where((u) => u.hero)) '${u.type} ${u.heroStats} ${u.heroSkill}'].join('; ');
    for (final seed in [1, 2, 3]) {
      final a = Game.fromJson(save, Random(seed), Random(seed + 100), Random(seed + 300));
      final b = Game.fromJson(save, Random(seed), Random(seed + 100), Random(seed + 300));
      final heroes = a.troops.where((u) => u.hero);
      expect(heroes, hasLength(3));
      expect(heroes.every((u) => u.heroSkill != null && !u.heroStats.contains(HeroStat.rate)), isTrue);
      expect(picks(b), picks(a), reason: 'seed $seed');
    }
  });

  test('the battle point keeps its rules every tick of real play (#85): the view glides no faster than its cap, '
      'without a fight the front stays inside the view, and no monster spawns on top of the front', () {
    const army = ['soldier', 'archer', 'knight', 'priest', 'wizard', 'lancer', 'swordsman'];
    for (final seed in [1, 2, 3]) {
      final g = Game(Random(seed), Random(seed + 100))
        ..loot = Random(seed + 200)
        ..heroes = Random(seed + 300)
        ..slots = Random(seed + 400)
        ..gold = 3000
        ..capacity = 16;
      var mid = double.nan, front = double.negativeInfinity, ticks = 0, spawns = 0;
      final seen = <Unit>{};
      play(g, 10, army, (g) {
        ticks++;
        final why = 'seed $seed wave ${g.wave} t ${g.t.toStringAsFixed(2)} ${g.meetMode.name}';
        // Between waves the only move is the capped glide back: the rest view is the back line at the left edge.
        if (!mid.isNaN) expect((g.viewMid - mid).abs(), lessThanOrEqualTo(focusSpeed / 30 + 1e-9), reason: why);
        if (g.waveActive && g.meetMode != MeetMode.contact) {
          final ft = g.troopFront;
          if (ft != null && g.meetX != null && g.viewW / 2 > frontIn) {
            expect(g.meetX!, inInclusiveRange(ft - g.viewW / 2 + frontIn - 1e-9, ft + g.viewW / 2 - frontIn + 1e-9), reason: why);
          }
        }
        for (final m in g.enemies) {
          if (m.raisedBy != null || !seen.add(m)) continue;
          spawns++; // its first step, and a shove, may already have taken it back a little
          expect(m.pos.x, greaterThanOrEqualTo(front + spawnClear - m.stats.speed / 30 - 6 - 1e-9), reason: '$why ${m.type}');
        }
        mid = g.viewMid;
        front = g.troops.where((o) => o.alive && o.entered).fold(double.negativeInfinity, (x, o) => max(x, o.pos.x));
      });
      expect((ticks, spawns > 50), (ticks, true), reason: 'seed $seed');
    }
  });

  test('two runs from the same seeds are the same wave by wave: a new game through its first Hero, and a loaded save with old Heroes', () {
    Game fresh(int seed) => Game(Random(seed), Random(seed + 100))
      ..loot = Random(seed + 200)
      ..heroes = Random(seed + 300)
      ..slots = Random(seed + 400)
      ..gold = 3000 // enough to live to its first Hero
      ..capacity = 16;
    const army = ['soldier', 'archer', 'knight', 'priest', 'wizard', 'lancer'];
    final first = fresh(7), made = <HeroMade>[];
    first.listeners.add((e) {
      if (e is HeroMade) made.add(e);
    });
    final a = play(first, heroEvery + 1, army), b = play(fresh(7), heroEvery + 1, army);
    expect(a.length, heroEvery + 1);
    expect(made, hasLength(1)); // on the heroEvery-th win, with the heroes dice
    for (var i = 0; i < a.length; i++) {
      expect(b[i], a[i], reason: 'a new game, wave ${i + 1}');
    }

    final save = oldSave(11);
    Game loaded(int seed) => Game.fromJson(save, Random(seed), Random(seed + 100), Random(seed + 300))
      ..loot = Random(seed + 200)
      ..slots = Random(seed + 400);
    final la = play(loaded(7), 4, army), lb = play(loaded(7), 4, army);
    expect(la, hasLength(4)); // waves 12-15: a mini boss at 12, a mini boss and the boss at 15
    for (var i = 0; i < la.length; i++) {
      expect(lb[i], la[i], reason: 'the loaded save, wave ${12 + i}');
    }
  });
}
