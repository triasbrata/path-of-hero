// The Towns' schedule on the board (decisions-log 216; a behaviour probe, not a balance one): the board's games roll
// Towns (decisions-log 237; always, decisions-log 296); over waves 1-30 (each won at once) it lists
// where each seed's Towns came, the gaps, and seed 7's waves in the design's notation (`T|7`: a Town before wave 7; `m`
// a mini boss, `B` the boss, from the wave's queue, untouched by the Towns). A probe (no `_test.dart`): queue
// `["test", "test/probe_town_slots.dart"]`; `SEEDS` (10) and `WAVES` (30) change it.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

const seeds = int.fromEnvironment('SEEDS', defaultValue: 10), waves = int.fromEnvironment('WAVES', defaultValue: 30);

/// A board game of [seed] going through each Town at once ([Game.townPolicy] 'leave'), its dice seeded as the probes do.
Game board(int seed) => Game(Random(seed), Random(seed + 100)).boardRules()
  ..heroes = Random(seed + 300)
  ..loot = Random(seed + 200)
  ..slots = Random(seed + 400)
  ..draft = Random(seed + 500)
  ..townDice = Random(seed + 600)
  ..townPolicy = 'leave';

/// Wins [g]'s next wave at once; its queue's slots as 'm' / 'B'.
String winWave(Game g) {
  final town = g.townDue ? g.townAt : null;
  g.startWave();
  final mark = [if (g.queue.any((s) => s.$2 == Tier.miniBoss)) 'm', if (g.queue.any((s) => s.$2 == Tier.boss)) 'B'].join();
  g.queue
    ..clear()
    ..add(('slime', Tier.normal));
  g.tick(0.05);
  g.enemies.single.gone = true;
  g.tick(0.05);
  return '${town == null ? '' : 'T|'}${g.wave}$mark';
}

void main() {
  test('Town slots on the board over $waves waves, $seeds seeds', () {
    final counts = <int>[];
    for (var seed = 1; seed <= seeds; seed++) {
      final g = board(seed);
      final line = [for (var w = 0; w < waves; w++) winWave(g)];
      final slots = [for (final e in g.log.entries.whereType<TownLeft>()) e.slot];
      final gaps = [for (var i = 1; i < slots.length; i++) slots[i] - slots[i - 1]];
      counts.add(slots.length);
      expect(slots.every((s) => s >= 7), isTrue, reason: 'seed $seed: $slots');
      expect(gaps.every((d) => d >= 5), isTrue, reason: 'seed $seed: $slots');
      for (var w = 1; w <= waves; w++) {
        final m = line[w - 1].replaceFirst('T|', '').replaceAll(RegExp(r'^\d+'), '');
        expect(m, '${w % miniBossEvery == 0 ? 'm' : ''}${w % bossEvery == 0 ? 'B' : ''}', reason: 'seed $seed wave $w');
      }
      // ignore: avoid_print
      print('seed $seed: Towns before waves $slots (gaps $gaps), next marked ${g.townAt}, chance ${g.townChance.toStringAsFixed(2)}');
      // ignore: avoid_print
      if (seed == 7) print('seed 7: ${line.join(' ')}');
    }
    // ignore: avoid_print
    print('Towns by wave $waves: mean ${(counts.reduce((a, b) => a + b) / counts.length).toStringAsFixed(2)}, '
        'min ${counts.reduce(min)}, max ${counts.reduce(max)}');
  });
}
