// The Shadows seen (catalog step 0h, decisions-log 191; ui-hud.md "Shadows"): offscreen shots with [omensOn] forced on,
// into <probe root>/shots/omens/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_omen_shots.dart"]` with the worktree as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir); the dice are seeded, so a rerun gives the same shots.
//
// At 412x860, 915x412 and 1266x713 (<size>): faces-<size> (a boss chest of a Legenda, an Epik and a Langka card at
// wave 90: "?" and 3, 2, 1 "!"), hint-<size> (the first chest's hint, no Shadow held yet), armed-<size> (the Legenda
// lifted, Ambil on it), flip-<size> (the take, mid-flip), reveal-<size> (the flip over: "Armor 3", "Dodged" twice, the
// ribbon), message-<size> (after it: the take's line and what the monsters got), skip-<size> (Skip armed: its note),
// chips-<size> (between waves: 8 chips, the 7 kinds and Skip's "!"), tip-<size> (their tooltip, tapped), boss-<size>
// (wave 90 on: the boss with Barrier 4 and Escort 2, its teal segment and ring, the mini boss, the chips over the
// bars), plate-<size> (a monster's plate: "Armor, Spikes"), log-<size> (the battle log, the Shadows' lines with their
// icons), boss1-<size> (the boss alone: a full bar, its Barrier and "+1 escort"), and w89-<size> (the owner's w89 save coming in: its catch-up note).
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/omens');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game between waves at wave 89 (the next a boss's), seeded, a mixed army of eight types, gold to spare.
Game board() {
  final g = Game(Random(seed), Random(seed + 100)).boardRules()
    ..seedDice(seed) // every die, the Shadows' faces too (decisions-log 319)
    ..armyMax = null
    ..gold = 400000
    ..wave = 89;
  for (final type in ['knight', 'knight_templar', 'archer', 'priest', 'wizard', 'soldier', 'lancer', 'swordsman']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  return g;
}

void main() {
  setUp(() => omensOn = true);
  tearDown(() => omensOn = false);

  for (final size in const [Size(412, 860), Size(915, 412), Size(1266, 713)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('omen shots $tag', (tester) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(loadHudFontNow);
      final game = TdGame();
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: GameWidget(game: game)));
      for (var i = 0; i < 3000 && !game.isLoaded; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(game.isLoaded, isTrue);
      final b = game.board
        ..welcome = null
        ..miniMapOpen = false;

      Future<void> shot(String name, [int settle = 20]) async {
        await frames(tester, settle);
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = (await tester.runAsync(() => boundary.toImage()))!;
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name-$tag.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        // ignore: avoid_print
        print('wrote $out/$name-$tag.png');
      }

      Future<void> tap(Offset p) async {
        await tester.tapAt(p);
        await frames(tester, 2);
      }

      // The chest: three faces, the first chest's hint.
      final g = b.state = board()..chestsGiven = 1;
      g.chests.addAll([
        for (var i = 0; i < 2; i++)
          Chest(ChestKind.boss, 90, cards: [Relic.dragonCrown, Relic.godThunder, Relic.ironBanner], omens: [OmenKind.armor, OmenKind.haste, OmenKind.wound]),
      ]);
      await shot('faces', 40);
      await tap(b.chestCards.first.center);
      await shot('armed', 10);
      await tap(b.chestButtons['take']!.center);
      await shot('flip', 9); // the taken card's marks half over (omenFlip 0.3 s), the others turning
      await shot('reveal', 30);
      await frames(tester, (omenRevealFor * 60).ceil());
      await shot('message', 2);
      await tap(b.messageBox.center);
      await frames(tester, 3);
      await tap(b.chestButtons['skip']!.center);
      await shot('skip', 4);
      await tap(b.chestButtons['skip']!.center);
      if (b.messageBox != Rect.zero) await tap(b.messageBox.center);

      // Between waves: every kind held, Skip owed: 8 chips, and their tooltip.
      g.omens.addAll([...OmenKind.values, OmenKind.armor, OmenKind.wound, OmenKind.guard, OmenKind.shield, OmenKind.shield, OmenKind.shield]);
      await shot('chips', 20);
      await tap(b.omenRow.center);
      await shot('tip', 30);
      await tap(b.omenRow.center);

      // Wave 90: the boss with its Barrier and Escort, the mini boss, the chips over the bars.
      g
        ..startWave()
        ..queue.clear()
        ..waveSpawned = 30;
      final front = g.troops.map((u) => u.pos.x).reduce(max);
      for (final u in g.troops) {
        u.stunUntil = 1e9;
      }
      final lord = g.monster(boss, Tier.boss, Point(front + 120, 60))..name = 'Morgath';
      final bear = g.monster('werebear', Tier.miniBoss, Point(front + 80, 24))..name = 'Grimdor';
      final orc = g.monster('orc', Tier.elite, Point(front + 60, 90));
      for (final u in [lord, bear, orc]) {
        g.units.add(u
          ..entered = true
          ..stunUntil = 1e9);
      }
      // ignore: avoid_print
      print('barrier ${lord.shield.round()} of ${lord.maxHp.round()}, escort ${g.omenGuards}');
      await shot('boss', 40);
      final at = b.toScreen(orc.pos.x, orc.pos.y - 7);
      if (!b.coveredAt(at)) {
        await tap(at); // pins its plate
        await shot('plate', 10);
        await tap(at);
      }
      if (b.logPanel == Rect.zero) await tap(b.logButton.center);
      await shot('log', 10);
      await tap(b.logButton.center);
      g.units.remove(bear); // the boss alone: its full bar, "+1 escort" on its rank line
      await shot('boss1', 10);

      // The owner's w89 save coming in: its catch-up note.
      final save = jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>;
      b.state = Game.fromJson(save, Random(seed), Random(seed + 100)).boardRules()..seedDice(seed);
      await shot('w89', 10);
    });
  }
}
