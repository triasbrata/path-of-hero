// (hud-cap-desk, decisions-log 217: the desktop's shots, RULE=before|after.)
// The HUD on a touch device (decisions-log 215, docs/ui-hud.md "Layouts"): offscreen shots before and after, into
// <probe root>/shots/android-hud/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_android_hud_shots.dart"]`. It never touches the real save (flutter_test_config.dart's temp dir).
//
// "before" is the desktop's rule (the HUD's scale from the field alone, no insets: the code before decisions-log 215,
// which the desktop keeps), "after" a phone's (Android). At the owner's tablet in landscape (1164x777) and portrait
// (777x1164), 915x412, 412x860 and 1266x713, each between waves (the book open) and in a wave:
// <before|after>-<w>x<h>-<book|wave>.png; and after-1164x777-bars-<book|wave>.png with the status bar (33 px) and the
// gesture bar (16) still showing, as if full screen were refused.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/hud-cap-desk');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A small army of five types and some gold, so the rows and the field look played.
Game army() {
  final g = Game(Random(7), Random(107))..gold = 480;
  for (final (type, col, row) in const [('knight', 2, 2), ('knight', 2, 4), ('archer', 1, 3), ('priest', 0, 3), ('lancer', 1, 5)]) {
    g.place(type, col, row);
  }
  return g;
}

void main() {
  const rule = String.fromEnvironment('RULE', defaultValue: 'after');
  for (final platform in const [TargetPlatform.macOS]) {
    testWidgets('android hud shots $rule', (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        await loadHudFontNow();
      });
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
        ..miniMapOpen = false
        ..guideSeen = null;

      Future<void> shot(String name) async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = (await tester.runAsync(() => boundary.toImage()))!;
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        final meter = b.waveMeter;
        // ignore: avoid_print
        print('wrote $out/$name.png ${img.width}x${img.height} k ${b.hudScale} insets ${b.safeInsets} band ${meter.height} '
            '(${(meter.height / img.height * 100).toStringAsFixed(1)}% of the height) meter $meter counter ${b.troopCounter} '
            'x2 ${b.speedButton} pause ${b.pauseButton} start ${b.startButton} auto ${b.autoButton} log ${b.logButton} '
            'book ${b.bookArea}');
      }

      debugDefaultTargetPlatformOverride = platform;
      try {
        final scenes = [
          for (final size in const [Size(1164, 777), Size(1000, 800), Size(1266, 713), Size(1100, 1050)]) (size, ''),
        ];
        for (final (size, bars) in scenes) {
          tester.view.physicalSize = size;
          tester.view.viewPadding = bars.isEmpty ? FakeViewPadding.zero : const FakeViewPadding(top: 33, bottom: 16);
          final tag = '$rule-${size.width.round()}x${size.height.round()}$bars';
          final g = b.state = army();
          await frames(tester, 60);
          await shot('$tag-book');
          g.startWave();
          await frames(tester, 220); // the first monsters come into view
          await shot('$tag-wave');
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetViewPadding();
      }
    });
  }
}
