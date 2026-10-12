// The open book's shadow seen (decisions-log 275; ui-hud.md "Layouts"): offscreen shots into
// <probe root>/shots/town-ground/ (`OUT`), named `<TAG>-field-<size>` and `<TAG>-town-<size>` (`TAG`, default
// "after"). A probe, not part of the suite (no `_test.dart`): queue `["test", "test/probe_book_shadow_shots.dart"]` with
// the worktree or a `git archive` mirror as `dir` (on a mirror of a base without the pixel shadow too: it reads only
// the book's box). It never touches the real save (flutter_test_config.dart's temp dir); every dice is seeded.
//
// At 1600x947 (the owner's window), 1266x713 and 915x412 (`--dart-define=SIZES=1600x947,915x412` for some only): the
// field between waves (the Towns off) and a Town, the book open; each shot at the bob's top and at its bottom (`-up`,
// `-down`). It prints the book's box and the shadow's rows (none in a Town since decisions-log 304).
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/town-ground');
const tag = String.fromEnvironment('TAG', defaultValue: 'after');
const only = String.fromEnvironment('SIZES');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game between waves, seeded; with [town] its Town due after the next win, else none marked.
Game board(bool town) => Game(Random(1), Random(2)).boardRules()
  ..townDice = Random(3)
  ..armyMax = null
  ..gold = 5000
  ..wave = 5
  ..townAt = town ? 7 : null;

void main() {
  final sizes = [
    for (final s in const [Size(1600, 947), Size(1266, 713), Size(915, 412)])
      if (only.isEmpty || only.split(',').contains('${s.width.round()}x${s.height.round()}')) s,
  ];
  for (final size in sizes) {
    final name = '${size.width.round()}x${size.height.round()}';
    testWidgets('book shadow shots $name', (tester) async {
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
      b.autoStart.set(false);

      Future<void> shot(String file) async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = (await tester.runAsync(() => boundary.toImage()))!;
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$tag-$file-$name.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        // ignore: avoid_print
        print('$tag-$file-$name book ${b.bookArea} shadow rows ${b.bookShadow.rows.length}');
      }

      /// Shots at the bob's top and bottom: the book's highest and lowest top over a whole bob (4 s).
      Future<void> bobShots(String file) async {
        var hi = double.infinity, lo = double.negativeInfinity;
        for (var i = 0; i < 250; i++) {
          await frames(tester, 1);
          hi = min(hi, b.bookArea.top);
          lo = max(lo, b.bookArea.top);
        }
        for (final (at, which) in [(hi, 'up'), (lo, 'down')]) {
          for (var i = 0; i < 300 && (b.bookArea.top - at).abs() > 0.3; i++) {
            await frames(tester, 1);
          }
          await shot('$file-$which');
        }
      }

      b.state = board(false);
      await frames(tester, 60);
      await bobShots('field');

      final g = b.state = board(true);
      g
        ..startWave()
        ..queue.clear()
        ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
      for (var i = 0; i < 600 && !b.townShown; i++) {
        await frames(tester, 1);
      }
      expect(b.townShown, isTrue);
      await frames(tester, 80); // the fade and the pan
      await bobShots('town');
    });
  }
}
