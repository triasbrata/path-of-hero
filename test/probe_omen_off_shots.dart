// The screens the Shadows touch, with [omensOn] off (catalog step 0h, decisions-log 191): offscreen shots into
// <probe root>/shots/omens-off/ (`OUT`), to compare byte for byte with the same probe in a mirror of main, so
// the Shadows' UI is proved dark. It uses only what main had before the UI step, so the one file runs in both. A probe,
// not part of the suite: queue `["test", "test/probe_omen_off_shots.dart", "--dart-define=OMENS=false",
// "--dart-define=OUT=<dir>"]` with each mirror as `dir` (the Shadows are on by default since decisions-log 319), then
// `cmp` the PNGs. Seeded, so a rerun gives the same shots.
//
// At 412x860, 915x412 and 1266x713 (<size>): chest-<size> (a boss chest at wave 90 whose save holds faces, as one
// written with omens on), armed-<size>, taken-<size> (the take's message), chip-<size> (the second chest's chip in a won
// wave's cheer: no Later since decisions-log 281), boss-<size> (wave 90 on: the boss and the mini boss, their bars),
// plate-<size> (a monster's plate) and log-<size> (the battle log).
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/omens-off');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game between waves at wave 89 (the next a boss's), seeded, a mixed army of eight types, gold to spare.
Game board() {
  final g = Game(Random(seed), Random(seed + 100)).boardRules()
    ..slots = Random(seed + 300)
    ..loot = Random(seed + 200)
    ..draft = Random(seed + 500)
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
  for (final size in const [Size(412, 860), Size(915, 412), Size(1266, 713)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('omens-off shots $tag', (tester) async {
      expect(omensOn, isFalse);
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

      final g = b.state = board()..chestsGiven = 1;
      g.chests.addAll([
        for (var i = 0; i < 2; i++)
          Chest(ChestKind.boss, 90, cards: [Relic.dragonCrown, Relic.godThunder, Relic.ironBanner], omens: [OmenKind.armor, OmenKind.haste, OmenKind.wound]),
      ]);
      await shot('chest', 40);
      await tap(b.chestCards.first.center);
      await shot('armed', 10);
      await tap(b.chestButtons['take']!.center);
      await shot('taken', 10);
      await tap(b.messageBox.center);
      await frames(tester, 3);
      g // a wave won at once: in its cheer the second chest waits as the chip (no Later since decisions-log 281)
        ..startWave()
        ..queue.clear()
        ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
      await shot('chip', 20);

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
      await shot('boss', 40);
      final at = b.toScreen(orc.pos.x, orc.pos.y - 7);
      if (!b.coveredAt(at)) {
        await tap(at);
        await shot('plate', 10);
        await tap(at);
      }
      if (b.logPanel == Rect.zero) await tap(b.logButton.center);
      await shot('log', 10);
    });
  }
}
