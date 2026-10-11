// The necromancer may be both the mini boss and the boss of one wave again (decisions-log 165, amending 140, qa-4):
// moving the pair's mini boss to any type of the pool made those waves harder. The switch stays: with
// [Game.necroPairAllowed] off, 140's rule holds, the mini boss takes a type of the pool from its own necromancer roll,
// and no die draws more than with it on.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

/// A game seeded with [seed] at wave [wave] (the next [Game.startWave] is wave + 1); [pair] sets the switch (null
/// keeps the game's default; false is 140's rule).
Game bare({int seed = 1, int wave = 0, bool? pair}) {
  final g = Game(Random(seed))
    ..units.clear()
    ..slots = Random(seed)
    ..wave = wave;
  if (pair != null) g.necroPairAllowed = pair;
  return g;
}

/// The queue of wave [wave] for a game seeded from [seed] and the wave (a fresh [Game.slots] would otherwise give
/// every wave of a seed the same boss roll).
List<(String, Tier)> queueOf(int wave, {int seed = 1, bool? pair}) =>
    [...(bare(seed: seed * 1000 + wave, wave: wave - 1, pair: pair)..startWave()).queue];

/// The types in [q]'s mini boss and boss slots.
(String, String) slotsOf(List<(String, Tier)> q) =>
    (q.singleWhere((m) => m.$2 == Tier.miniBoss).$1, q.singleWhere((m) => m.$2 == Tier.boss).$1);

/// The waves with both slots, up to 90.
const both = [15, 30, 45, 60, 75, 90];

void main() {
  test('by default the pair rolls: a necromancer boss\'s mini boss is the necromancer at its 1/3 (165)', () {
    expect(Game(Random(1)).necroPairAllowed, isTrue);
    var necroBosses = 0, pairs = 0;
    for (var seed = 0; seed < 300; seed++) {
      for (final w in both) {
        final q = queueOf(w, seed: seed), why = 'seed $seed wave $w';
        final (mini, b) = slotsOf(q);
        expect(q, queueOf(w, seed: seed, pair: true), reason: why); // the default is the switch on
        if (b != boss) continue;
        necroBosses++;
        if (mini == boss) pairs++;
      }
    }
    expect(necroBosses / (300 * both.length), closeTo(necroBossChance, 0.04));
    expect(pairs / necroBosses, closeTo(necroMiniChance, 0.05));
  });

  test('switched off (140), the necromancer is never both the mini boss and the boss; its mini boss is a type of the pool', () {
    var necroBosses = 0, pairs = 0;
    final seen = <String>{};
    for (var seed = 0; seed < 300; seed++) {
      for (final w in both) {
        final (mini, b) = slotsOf(queueOf(w, seed: seed, pair: false));
        final why = 'seed $seed wave $w';
        expect((mini, b), isNot((boss, boss)), reason: why);
        if (b != boss) continue;
        necroBosses++;
        expect(mini, isIn(poolOf(w)), reason: why);
        if (slotsOf(queueOf(w, seed: seed)).$1 == boss) {
          pairs++; // the default brings the pair: switched off, the mini boss was moved
          seen.add(mini);
        }
      }
    }
    // A third of the bosses are the necromancer, and a third of their mini bosses would have been: ~1/9 of the waves.
    expect(necroBosses / (300 * both.length), closeTo(necroBossChance, 0.04));
    expect(pairs / (300 * both.length), closeTo(necroBossChance * necroMiniChance, 0.03));
    expect(seen.length, greaterThanOrEqualTo(6)); // the moved mini boss is any type of the pool, not always one
  });

  test('switched off, a moved mini boss has any mini boss\'s odds: the stronger types likelier (#58)', () {
    // Wave 90's pool is every type; the moved mini bosses lean to the strong end like any other mini boss.
    final pool = poolOf(90), moved = <String, int>{};
    for (var seed = 0; seed < 1500; seed++) {
      if (slotsOf(queueOf(90, seed: seed)) != (boss, boss)) continue;
      final mini = slotsOf(queueOf(90, seed: seed, pair: false)).$1;
      moved[mini] = (moved[mini] ?? 0) + 1;
    }
    final count = moved.values.fold(0, (a, b) => a + b), half = pool.length ~/ 2;
    expect(count, greaterThan(100));
    final weak = pool.take(half).fold(0, (n, t) => n + (moved[t] ?? 0)), strong = pool.skip(half).fold(0, (n, t) => n + (moved[t] ?? 0));
    expect(strong, greaterThan(2 * weak), reason: '$moved');
  });

  test('either way a necromancer mini boss comes on waves whose boss isn\'t one, at its chance', () {
    for (final pair in [true, false]) {
      var minis = 0, necroMinis = 0, onBossWaves = 0, necroOnBossWaves = 0;
      for (var seed = 0; seed < 300; seed++) {
        // Mini boss waves without a boss.
        for (final w in [9, 12, 18, 48, 51, 93]) {
          final mini = queueOf(w, seed: seed, pair: pair).singleWhere((m) => m.$2 == Tier.miniBoss).$1;
          minis++;
          if (mini == boss) necroMinis++;
        }
        // Waves with both whose boss is another type.
        for (final w in both) {
          final (mini, b) = slotsOf(queueOf(w, seed: seed, pair: pair));
          if (b == boss) continue;
          onBossWaves++;
          if (mini == boss) necroOnBossWaves++;
        }
      }
      expect(necroMinis / minis, closeTo(necroMiniChance, 0.04), reason: 'pair $pair');
      expect(necroOnBossWaves / onBossWaves, closeTo(necroMiniChance, 0.05), reason: 'pair $pair');
    }
  });

  test('switched off, everything else is as by default (main before 140): the other slots, every wave, the dice', () {
    var moved = 0;
    for (var seed = 0; seed < 40; seed++) {
      final fixed = bare(seed: seed, pair: false), main = bare(seed: seed);
      for (var w = 1; w <= 95; w++) {
        fixed.startWave();
        main.startWave();
        final a = fixed.queue, b = main.queue, why = 'seed $seed wave $w';
        expect(a.length, b.length, reason: why);
        final pair = w % 15 == 0 && slotsOf(b) == (boss, boss);
        for (var i = 0; i < a.length; i++) {
          if (pair && b[i].$2 == Tier.miniBoss) {
            expect(a[i].$1, isIn(poolOf(w)), reason: why);
            expect(a[i].$2, Tier.miniBoss, reason: why);
            moved++;
          } else {
            expect(a[i], b[i], reason: '$why at $i');
          }
        }
        fixed.queue.clear();
        main.queue.clear();
      }
      // No die drew more or less: the next draws of each are the same.
      expect((fixed.rng.nextDouble(), fixed.slots.nextDouble()), (main.rng.nextDouble(), main.slots.nextDouble()), reason: 'seed $seed');
    }
    expect(moved, greaterThan(10)); // the case came up
  });

  test('the escort (#90) follows whichever mini boss rolls', () {
    bool isEscort(List<(String, Tier)> q, int from) =>
        [for (final (t, _) in q.sublist(from, from + 3)) t].every((t) => t == necroHealer) && q[from + 3] == (boss, Tier.highElite);
    var pairs = 0;
    for (var seed = 0; seed < 200; seed++) {
      for (final w in [60, 75, 90]) {
        if (slotsOf(queueOf(w, seed: seed)) != (boss, boss)) continue;
        pairs++;
        for (final pair in [true, false]) {
          final q = queueOf(w, seed: seed, pair: pair), m = q.indexWhere((e) => e.$2 == Tier.miniBoss);
          final why = 'seed $seed wave $w pair $pair';
          // By default the necromancer mini boss; switched off a moved one, a type of the pool.
          expect(q[m].$1, pair ? boss : isIn(poolOf(w)), reason: why);
          expect(isEscort(q, m + 1), isTrue, reason: '$why: ${q.sublist(m)}');
          // Then the necromancer boss, its own escort, and the wave's last healer.
          expect(q[m + 5], (boss, Tier.boss), reason: why);
          expect(isEscort(q, m + 6), isTrue, reason: '$why: ${q.sublist(m)}');
          expect((q.length, q.last.$1), (m + 11, necroHealer), reason: why);
        }
      }
    }
    expect(pairs, greaterThan(10));
  });
}
