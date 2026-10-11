// The spawn floor's behaviour probe (decisions-log 225): the owner's w89 save (the fixture) plays waves 90-92 with
// seeded dice, and for each wave prints how the monsters came on: the floor (one for every 8 living troops, counted
// here so the probe runs on a base from before the floor too), the fewest monsters alive while the queue still held
// more, how long the field stood empty (and below the floor) meanwhile, the first spawn times and the last, the wave's
// length, the troops that fell and the lives lost. A probe, not part of the suite (no `_test.dart`), and no balance
// measure: two seeds, three waves, to see the floor work. Run it on a base (a `git archive` mirror) and on the branch:
// `["test", "test/probe_spawn_floor.dart"]`. It never touches the real save (flutter_test_config.dart's temp dir).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

const _save = 'test/fixtures/save-20261002-2222-w89-sellbug.json';

/// The w89 save with its dice seeded ([seed]), as the probes load it; a due Town is entered and left at once.
Game _load(int seed) =>
    Game.fromJson(jsonDecode(File(_save).readAsStringSync()) as Map<String, dynamic>, Random(seed), Random(seed + 100), Random(seed + 300))
      ..loot = Random(seed + 200)
      ..slots = Random(seed + 400)
      ..draft = Random(seed + 500)
      ..townPolicy = 'leave';

String _s(double v) => v.toStringAsFixed(2);

/// Plays [waves] waves of [g] (settling 10 s before each, the boss chest's first card taken), one line each.
List<String> _play(Game g, int seed, {int waves = 3}) {
  const dt = 1 / 30;
  final out = <String>[];
  for (var w = 0; w < waves && !g.over; w++) {
    while (g.chest != null && g.takeCard(0)) {}
    for (var i = 0; i < 300; i++) {
      g.viewW = 341;
      g.tick(dt);
    }
    final lives = g.lives, troopsAt = g.troops.where((u) => u.alive).length;
    g.startWave();
    final start = g.t, total = g.waveTotal, spawns = <double>[];
    var minAlive = 1 << 30, minFloor = 1 << 30, empty = 0.0, below = 0.0, spawned = 0;
    for (var i = 0; i < 30 * 300 && g.waveActive && !g.over; i++) {
      g.viewW = 341;
      g.tick(dt);
      while (spawned < g.waveSpawned) {
        spawned++;
        spawns.add(g.t - start);
      }
      if (spawned == 0 || g.queue.isEmpty) continue; // from the first spawn while the queue holds more
      final alive = g.enemies.where((u) => u.alive).length;
      final floor = (g.troops.where((u) => u.alive).length / 8).ceil();
      minAlive = min(minAlive, alive);
      minFloor = min(minFloor, floor);
      if (alive == 0) empty += dt;
      if (alive < floor) below += dt;
    }
    out.add('seed $seed wave ${g.wave}: troops $troopsAt floor ${(troopsAt / 8).ceil()} (lowest $minFloor) | '
        'monsters $total, spawned $spawned, min alive $minAlive, empty ${_s(empty)} s, below floor ${_s(below)} s | '
        'spawns ${[for (final s in spawns.take(8)) _s(s)]} .. last ${spawns.isEmpty ? '-' : _s(spawns.last)} | '
        'wave ${_s(g.t - start)} s, ${g.waveActive ? 'unfinished' : g.over ? 'LOST' : 'won'}, fell ${g.fallen.length}, '
        'lives -${lives - g.lives}, kills ${g.kills}');
  }
  return out;
}

void main() {
  test('the spawn floor on the w89 save: per wave the fewest monsters alive and the field\'s empty time', () {
    for (final seed in [89, 90]) {
      for (final line in _play(_load(seed), seed)) {
        // ignore: avoid_print
        print(line);
      }
    }
  });
}
