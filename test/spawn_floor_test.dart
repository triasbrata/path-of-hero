// The spawn floor (decisions-log 225; the owner, 2026-10-04): while a wave's queue still holds monsters, at least one
// monster alive on the field for every 8 living troops ([spawnFloorOf]). Below it the next one comes on at once, one a
// tick; at it the gap's timer runs again, from the spawn that reached it. The queue's order, its slots and escorts, and
// the tide's gap above the floor are as before.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

/// A game without the free healer or monster skills at wave [wave] (the next [Game.startWave] is wave + 1), with
/// [troops] knights standing still (they neither walk nor fight) and lives to spare.
Game withTroops(int troops, {int wave = 9, int seed = 1}) {
  final g = Game(Random(seed))
    ..units.clear()
    ..slots = Random(seed)
    ..monsterSkills = false
    ..lives = 1000
    ..wave = wave;
  for (var i = 0; i < troops; i++) {
    g.units.add(Unit(Side.troop, 'knight', troopTypes['knight']!, Point(g.baseX + tile * (1 + i ~/ rows), (i % rows + 0.5) * tile))
      ..entered = true
      ..busyUntil = 1e9);
  }
  return g;
}

/// [u] killed where it stands: it lies dying, no longer alive.
void kill(Unit u) => u
  ..hp = 0
  ..dying = 0;

void main() {
  test('the floor: one monster for every 8 living troops, rounded up; Heroes count, the fallen don\'t', () {
    expect(spawnFloorPer, 8);
    const want = [(0, 0), (1, 1), (8, 1), (9, 2), (16, 2), (33, 5)];
    expect([for (final (n, _) in want) spawnFloorOf(n)], [for (final (_, f) in want) f]);
    expect([for (final (n, _) in want) withTroops(n).spawnFloor], [for (final (_, f) in want) f]);
    final g = withTroops(9);
    g.troops.first.hero = true;
    expect(g.spawnFloor, 2);
    kill(g.troops.last);
    expect(g.spawnFloor, 1, reason: 'a fallen troop no longer counts');
  });

  test('every living monster counts toward it, a raised minion too; a dying one doesn\'t; none without a queue', () {
    final g = withTroops(9)..startWave(); // the floor is 2
    g.tick(0.05);
    expect((g.waveSpawned, g.belowSpawnFloor), (1, true));
    final first = g.enemies.single;
    final raised = g.monster(minion, Tier.normal, first.pos)..raisedBy = first;
    g.units.add(raised);
    expect(g.belowSpawnFloor, isFalse, reason: 'two alive, one of them raised');
    kill(raised);
    expect(g.belowSpawnFloor, isTrue, reason: 'a dying one is not on the field any more');
    g.queue.clear();
    expect(g.belowSpawnFloor, isFalse, reason: 'nothing left to bring');
  });

  test('below the floor the wave\'s first monsters come on one a tick; at it the gap runs again, from the last', () {
    for (final n in [0, 1, 8, 9, 16, 33]) {
      final g = withTroops(n)..startWave();
      final floor = spawnFloorOf(n), gap = spawnGapOf(g.wave, g.tideStart);
      // The first comes at once with or without troops (the timer starts at 0); then one a tick up to the floor.
      for (var i = 1; i <= max(1, floor); i++) {
        g.tick(0.05);
        expect(g.waveSpawned, i, reason: '$n troops, tick $i');
      }
      expect(g.enemies.where((u) => u.alive).length, max(1, floor), reason: '$n troops');
      g.tick(gap - 0.004);
      expect(g.waveSpawned, max(1, floor), reason: '$n troops: at the floor the gap counts from the last spawn');
      g.tick(0.008);
      expect(g.waveSpawned, max(1, floor) + 1, reason: '$n troops');
    }
  });

  test('a field that empties early gets its next monster on the next tick, not after the gap; then the gap again', () {
    for (final n in [0, 8]) {
      final g = withTroops(n)..startWave();
      final gap = spawnGapOf(g.wave, g.tideStart);
      g.tick(0.05);
      g.tick(0.3); // the gap runs: one alive, at the floor (1 with 8 troops)
      expect(g.waveSpawned, 1, reason: '$n troops');
      kill(g.enemies.single); // 0.35 s after it came on, well before the 0.9 s gap
      g.tick(0.05);
      if (n == 0) {
        expect(g.waveSpawned, 1, reason: 'no troops, no floor: the gap as before');
        g.tick(gap - 0.35 - 0.004);
        expect(g.waveSpawned, 1);
        g.tick(0.008);
        expect(g.waveSpawned, 2);
        continue;
      }
      expect(g.waveSpawned, 2, reason: 'the next tick');
      g.tick(gap - 0.004);
      expect(g.waveSpawned, 2, reason: 'at the floor again: the timer restarted with that spawn');
      g.tick(0.008);
      expect(g.waveSpawned, 3);
    }
  });

  test('above the floor the tide\'s gap still applies: a wave-65 queue every 0.7744 s with 8 troops', () {
    final g = withTroops(8, wave: 64)..startWave();
    expect((g.spawnFloor, g.tideStart), (1, tideFrom));
    g.tick(0.05);
    expect(g.waveSpawned, 1);
    g.tick(spawnGapOf(65) - 0.004);
    expect(g.waveSpawned, 1);
    g.tick(0.008);
    expect(g.waveSpawned, 2);
    expect(spawnGapOf(65), closeTo(0.7744, 1e-4));
  });

  test('a wave brought in by the floor alone keeps the queue\'s order, its slots and escorts, one monster a tick', () {
    for (final w in [10, 50, 60]) {
      final g = withTroops(33, wave: w - 1)..startWave(); // the floor is 5; each one is killed as it comes
      final queued = [...g.queue], spawned = <Unit>[];
      for (var i = 1; g.queue.isNotEmpty; i++) {
        g.tick(0.05);
        final fresh = g.enemies.where((u) => u.alive && u.raisedBy == null && !spawned.contains(u)).toList();
        expect(fresh.length, 1, reason: 'wave $w, tick $i: one a tick');
        spawned.addAll(fresh);
        expect(g.waveSpawned, i, reason: 'wave $w');
        fresh.forEach(kill);
      }
      expect([for (final u in spawned) (u.type, u.tier)], queued, reason: 'wave $w');
      final slots = spawned.where((u) => u.tier == Tier.miniBoss || u.tier == Tier.boss).toList();
      expect(slots, isNotEmpty, reason: 'wave $w');
      for (final s in slots) {
        final escort = spawned.where((u) => u.escortOf == s).toList();
        if (w < escortFrom) {
          expect(escort, isEmpty, reason: 'wave $w');
          continue;
        }
        expect([for (final u in escort) u.type], [necroHealer, necroHealer, necroHealer, boss], reason: 'wave $w');
        expect(spawned.indexOf(escort.first), spawned.indexOf(s) + 1, reason: 'wave $w');
        expect(s.name, isNotEmpty, reason: 'wave $w: the slot is named as it comes');
      }
    }
  });
}
