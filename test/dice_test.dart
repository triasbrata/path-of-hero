// The game's dice (decisions-log 319, code-audit R1): [Game.dice] lists every `Random` the game holds, and
// [Game.seedDice] seeds all of them after rng and names, so a probe's seeded run (the Shadows' faces too) replays the
// same.
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

void main() {
  test('Game.dice holds every Random field of the game, each its own', () {
    final fields = RegExp(r'^\s+(?:final\s+)?Random\??\s+(\w+)\s*(?:=|;)', multiLine: true)
        .allMatches(File('lib/game.dart').readAsStringSync())
        .map((m) => m[1]!)
        .toSet();
    final g = Game();
    expect(fields, hasLength(g.dice.length), reason: 'a new die goes in Game.dice and Game.seedDice: $fields');
    expect(g.dice.toSet(), hasLength(g.dice.length), reason: 'no die shared');
  });

  test('seedDice seeds every die after rng and names at the probes\' offsets, so two runs roll alike', () {
    List<double> draws(Game g) => [for (final d in g.dice) d.nextDouble()];
    final a = Game(Random(7), Random(107))..seedDice(7), b = Game(Random(7), Random(107))..seedDice(7);
    expect(draws(a), draws(b));
    final c = Game()..seedDice(7);
    expect(draws(c).skip(2), [for (final k in [200, 300, 400, 500, 900, 800, 600, 700, 1000]) Random(7 + k).nextDouble()],
        reason: 'loot, heroes, slots, draft, omenDice, tavernDice, townDice, matDice, dungeonDice');
  });

  test('a seeded game with the Shadows on draws the same faces each run', () {
    final was = omensOn;
    omensOn = true;
    addTearDown(() => omensOn = was);
    List<OmenKind?> faces() {
      final g = Game(Random(3), Random(103)).boardRules()
        ..seedDice(3)
        ..wave = 40
        ..giveChests(2);
      return [for (final c in g.chests) ...?c.omens];
    }

    final first = faces();
    expect(first.whereType<OmenKind>(), isNotEmpty);
    expect(faces(), first);
  });
}
