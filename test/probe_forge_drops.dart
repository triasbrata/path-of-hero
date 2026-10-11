// The forge's drops on the board (decisions-log 246; a behaviour probe, not a balance one): a board game a seed (the
// Towns on), every wave's monsters (its queue, the real spawn list) killed by four knights at 1 HP each, so every wave is
// won: no item ever drops, and the materials held by wave are printed beside what the game's rules expect for those
// queues (the forge's table) and the design model's numbers (a run that wins every wave: w6 68, w10 156, w20 543). A
// probe (no `_test.dart`): queue `["test", "test/probe_forge_drops.dart"]`; `SEEDS` (4) and `WAVES` (20) change it. It
// never touches the real save (flutter_test_config.dart's temp dir).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

const seeds = int.fromEnvironment('SEEDS', defaultValue: 4), waves = int.fromEnvironment('WAVES', defaultValue: 20);

/// The design model's materials by wave (forge-design out-mats.txt).
const _model = {6: 68, 10: 156, 15: 326, 20: 543};

/// A board game of [seed] with its dice seeded as the probes do, going through each Town at once, no skills cast, and
/// four knights to do the killing.
(Game, List<Unit>) board(int seed) {
  final g = Game(Random(seed), Random(seed + 100)).boardRules()
    ..heroes = Random(seed + 300)
    ..loot = Random(seed + 200)
    ..slots = Random(seed + 400)
    ..draft = Random(seed + 500)
    ..townDice = Random(seed + 600)
    ..matDice = Random(seed + 700)
    ..townPolicy = 'leave'
    ..skills = false
    ..heroSkills = false
    ..awakenSkills = false
    ..monsterSkills = false
    ..capacity = 6 * rows
    ..gold = 1000000;
  return (g, [for (final r in [1, 3, 5, 7]) placeNow(g, 'knight', 3, r)]);
}

/// What one kill of [type] at [tier] drops on average by [r]'s rules (the forge's table).
double expected(TownRules r, String type, Tier tier) {
  var e = 0.0;
  for (final d in r.forgeDrops[tier]!) {
    if (r.partOf(type, d.part) != null) e += min(1.0, d.chance) * d.count;
    e += d.plus.values.fold(0, (a, n) => a + n);
  }
  if (type == boss && (tier == Tier.miniBoss || tier == Tier.boss)) e += r.necromancerPlus.values.fold(0, (a, n) => a + n);
  return e;
}

int _sum(Map<Mat, int> m) => m.values.fold(0, (a, n) => a + n);

void main() {
  test('the forge\'s drops on the board, $seeds seeds x $waves waves, every wave won', () {
    final held = <int, List<int>>{}, rules = <int, double>{}, missed = <String>[];
    for (var seed = 1; seed <= seeds; seed++) {
      final (g, knights) = board(seed);
      expect(g.towns, isTrue);
      var exp = 0.0;
      for (var w = 1; w <= waves; w++) {
        g.startWave();
        final spawn = [...g.queue];
        g.queue.clear();
        final keep = foeAt(g, 'slime', const Point(2000, 10)); // far off: the wave stays on until all are down
        final foes = [
          for (final (i, (type, tier)) in spawn.indexed)
            foeAt(g, type, knights[i % knights.length].pos + Point(12.0, (i ~/ knights.length) * 0.01), tier)..hp = 1,
        ];
        for (var n = 0; n < 6000 && foes.any((u) => u.alive); n++) {
          g.tick(0.05);
        }
        for (final u in foes.where((u) => u.alive)) {
          missed.add('seed $seed w$w ${u.type} ${u.tier.name}');
        }
        for (final (type, tier) in spawn) {
          exp += expected(g.townRules, type, tier);
        }
        expect(keep.alive, isTrue);
        for (final u in g.enemies) {
          u.gone = true; // the wave's leftovers (the keeper, a raised one): never killed, never dropping
        }
        g.tick(0.05);
        expect(g.waveActive, isFalse, reason: 'seed $seed wave $w won');
        expect(g.wave, w);
        expect(g.drops, isEmpty, reason: 'seed $seed wave $w: no item drops with the forge');
        expect(g.inventory.values.fold(0, (a, n) => a + n), 0, reason: 'seed $seed wave $w');
        (held[w] ??= []).add(_sum(g.materials));
        if (seed == 1) rules[w] = exp;
        if (seed == 1 && w <= 3 || w == waves) {
          // ignore: avoid_print
          print('seed $seed w$w: ${spawn.length} spawned, held ${_sum(g.materials)} (${g.materials.length} kinds), seen '
              '${g.matsSeen.length}: ${[for (final m in g.matsSeen.take(8)) m.name].join(' ')}${g.matsSeen.length > 8 ? ' ...' : ''}');
        }
      }
      expect(g.matsSeen.toSet(), g.materials.keys.toSet(), reason: 'nothing bought or spent: every kind held is a kind seen');
    }
    // ignore: avoid_print
    print('missed kills (alive after 300 s): ${missed.length}${missed.isEmpty ? '' : ': ${missed.take(10).join(', ')}'}');
    // ignore: avoid_print
    print('wave  held mean (min-max) | rules on seed 1\'s queues | model');
    for (var w = 1; w <= waves; w++) {
      final h = held[w]!, mean = h.reduce((a, b) => a + b) / h.length;
      // ignore: avoid_print
      print('w${w.toString().padLeft(2)}  ${mean.toStringAsFixed(1).padLeft(6)} (${h.reduce(min)}-${h.reduce(max)}) | '
          '${rules[w]!.toStringAsFixed(1).padLeft(6)}${switch (_model[w]) { final int a => ' | $a', null => '' }}');
    }
    expect(missed, isEmpty);
  });
}
