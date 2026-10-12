// The materials lying on the field (decisions-log 262; docs/ui-hud.md "A kill's pop", "Win popup"): a kill's materials
// hop onto the ground where it fell and lie there, the same kind close by in one pile with its count, until the wave is
// won; then they fly to the Bag and are gone. Visual only: the tally ([Game.waveMaterials]) and the bag
// ([Game.materials]) move as before, and the piles lying always hold the tally, so a lost game's never carry over into the
// next one. One TdGame per widget test. A won wave saves into the test's own folder (flutter_test_config.dart), never the
// real save.
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hero_skill_helpers.dart';
import 'hud_font.dart';

const desk = Size(1266, 713), phone = Size(915, 412);

/// Dice that always roll 0: every chance of a drop comes up.
class _Zero implements Random {
  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

/// Boots one TdGame in a [size] window, past the welcome screen, with the game's font, the minimap folded and Auto off. A
/// game over asks for the score's name ([main]'s `overlayBuilderMap`): an empty overlay stands in for its text field.
Future<Board> boot(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadHudFont(tester);
  final game = TdGame();
  await tester.pumpWidget(GameWidget(game: game, overlayBuilderMap: {'name': (_, TdGame g) => const SizedBox.shrink()}));
  for (var i = 0; i < 3000 && !game.isLoaded; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(game.isLoaded, isTrue);
  final b = game.board
    ..welcome = null
    ..miniMapOpen = false;
  b.autoStart.set(false);
  return b;
}

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A game with the Towns on, a knight at cell (2, 3), no skills cast, every drop's chance coming up, and a few
/// materials in the bag already.
Game towns() {
  final g = bareGame(Random(1))
    ..skills = false
    ..heroSkills = false
    ..awakenSkills = false
    ..matDice = _Zero()
    ..wave = 20;
  placeNow(g, 'knight', 2, 3);
  g.materials.addAll({Mat.slimeGel: 4, Mat.evilEye: 1});
  return g;
}

/// A monster of [type] and [tier] standing stunned at [at] (drawn mid-flinch; a held one, hero_skill_helpers.dart's
/// `foeAt`, is busy forever, which the board can't draw).
Unit held(Game g, String type, Point<double> at, [Tier tier = Tier.normal]) {
  final u = g.monster(type, tier, at)
    ..entered = true
    ..stunUntil = 1e9;
  g.units.add(u);
  return u;
}

/// Starts a wave on [g] with nothing to spawn (a slime held far off keeps it on) and kills each of [foes] (type, rank,
/// where) with the knight, ticking the game itself; the board drains the drops on its next frames.
void killAll(Game g, List<(String, Tier, Point<double>)> foes) {
  if (!g.waveActive) {
    g
      ..startWave()
      ..queue.clear();
    held(g, 'slime', const Point(2000, 10));
  }
  final k = g.troops.first, units = [for (final (type, tier, at) in foes) held(g, type, k.pos + at, tier)..hp = 1];
  for (var n = 0; n < 400 && units.any((u) => u.alive); n++) {
    g.tick(0.05);
  }
  expect([for (final u in units) u.alive], everyElement(isFalse));
}

/// Each kind's count over the piles [b] has lying (not flying).
Map<Mat, int> lying(Board b) {
  final out = <Mat, int>{};
  for (final (m, n, flies) in b.matLoot) {
    if (!flies) out[m] = (out[m] ?? 0) + n;
  }
  return out;
}

void main() {
  for (final size in const [desk, phone]) {
    testWidgets('a kill\'s materials lie where it fell, the same kind in one pile, until the win; then they fly to the Bag and '
        'are gone, the tally and the bag as before (${size.width.round()}x${size.height.round()})', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = towns();
      await frames(tester, 10);
      final before = {...g.materials};
      // Two orc mini bosses fall on one spot, a slime far from them.
      killAll(g, [('orc', Tier.miniBoss, const Point(12, 0)), ('orc', Tier.miniBoss, const Point(14, 1)), ('slime', Tier.normal, const Point(12, 60))]);
      final tally = {...g.waveMaterials};
      expect(tally.keys, containsAll([Mat.evilEye, Mat.slimeGel]), reason: 'a mini boss always drops a Trophy; the slime its gel');
      expect(tally[Mat.evilEye], 2);
      await frames(tester, 2);
      expect(b.fieldFx, greaterThan(0), reason: 'the drops hop onto their piles');
      await frames(tester, 45); // past the hop (0.6 s)
      expect(lying(b), tally, reason: 'the piles hold the wave\'s tally');
      expect([for (final (m, _, _) in b.matLoot) m].where((m) => m == Mat.evilEye), hasLength(1), reason: 'the two Trophies stack');
      expect(b.matLoot.firstWhere((p) => p.$1 == Mat.evilEye).$2, 2);
      expect(b.matLoot.length, tally.length, reason: 'each kind in one pile: the orcs\' together, the slime\'s alone');
      expect(g.materials, before, reason: 'not in the bag before the win');
      await frames(tester, 60); // they lie on through the wave
      expect(lying(b), tally);

      // The win: the bag gets the tally at once, as before; the piles fly.
      for (final u in g.enemies) {
        u.gone = true;
      }
      await frames(tester, 2);
      expect(g.waveActive, isFalse);
      expect(g.materials, {for (final m in {...before.keys, ...tally.keys}) m: (before[m] ?? 0) + (tally[m] ?? 0)});
      expect(g.lastMaterials, tally);
      expect(g.waveMaterials, isEmpty);
      expect(b.matLoot, isNotEmpty);
      expect([for (final (_, _, flies) in b.matLoot) flies], everyElement(isTrue), reason: 'every pile is off to the Bag');
      await frames(tester, 90); // the wait, the gaps, the flight and the bag's linger: under 1.3 s
      expect(b.matLoot, isEmpty, reason: 'in the Bag');
      expect(b.fieldFx, 0);
    });
  }

  testWidgets('a lost game\'s materials lie on as its other loot does, and never carry over: Play again, a save loaded or a '
      'tally reset takes them off the field', (tester) async {
    final b = await boot(tester, desk);
    var g = b.state = towns();
    await frames(tester, 10);
    killAll(g, [('orc', Tier.miniBoss, const Point(12, 0))]);
    await frames(tester, 45);
    final tally = {...g.waveMaterials};
    expect(lying(b), tally);
    // Lost: the lives are gone. The piles lie on under the game-over screen, like the items lying there.
    g.lives = 0;
    await frames(tester, 30);
    expect(g.over, isTrue);
    expect(lying(b), tally);
    expect([for (final (_, _, flies) in b.matLoot) flies], everyElement(isFalse));
    // Play again (a fresh game; a save loaded is another game too): none of the last game's piles.
    g = b.state = towns();
    await frames(tester, 2);
    expect(b.matLoot, isEmpty);
    expect(b.fieldFx, 0);
    // The next attempt's own drops lie, and only they.
    killAll(g, [('slime', Tier.normal, const Point(12, 0))]);
    await frames(tester, 45);
    expect(lying(b), g.waveMaterials);
    expect(lying(b), {Mat.slimeGel: 1});
    // A tally dropped without a win takes its piles with it.
    g.waveMaterials.clear();
    await frames(tester, 2);
    expect(b.matLoot, isEmpty);
  });

  testWidgets('drops close together stack, far apart lie apart, and past 40 piles the oldest join their kind\'s nearest; '
      'the counts always the tally', (tester) async {
    final b = await boot(tester, desk);
    final g = b.state = towns();
    await frames(tester, 10);
    void drop(Point<double> at, Mat m, [int n = 1]) {
      g.waveMaterials[m] = (g.waveMaterials[m] ?? 0) + n;
      g.matPops.add((at, m, n));
    }

    drop(const Point(100, 40), Mat.batWing);
    drop(const Point(110, 44), Mat.batWing, 2); // 11 units off: the same pile
    drop(const Point(160, 40), Mat.batWing); // 60 off: a pile of its own
    drop(const Point(104, 40), Mat.skull); // another kind never joins it
    await frames(tester, 45);
    expect(b.matLoot, [(Mat.batWing, 3, false), (Mat.batWing, 1, false), (Mat.skull, 1, false)]);

    // 120 more over the field, three kinds 30 units apart: never more than 40 piles, every count kept.
    for (var i = 0; i < 120; i++) {
      drop(Point(20 + (i % 10) * 30.0, 10 + (i ~/ 10 % 4) * 30.0), [Mat.boneShard, Mat.orcTooth, Mat.wolfClaw][i % 3]);
    }
    await frames(tester, 45);
    expect(b.matLoot.length, lessThanOrEqualTo(40));
    expect(lying(b), g.waveMaterials);
    expect(g.waveMaterials.values.fold(0, (a, n) => a + n), 125);
  });
}
