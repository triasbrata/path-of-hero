// The top band with the hearts and the gold in one panel, Start and Pause one toggle at the top centre, and x2, Auto
// and the wave meter one group at the top right (decisions-log 220, docs/ui-hud.md "Layouts"): offscreen shots into
// <probe root>/shots/hud-merge/ (`OUT`), named `TAG` (before / after). A probe, not part of the suite (no
// `_test.dart`): queue `["test", "test/probe_hud_merge_shots.dart", "--dart-define=TAG=after"]`. It never touches the
// real save (flutter_test_config.dart's temp dir).
//
// As on a touch device (Android), at 1164x777 (the owner's tablet), 1266x713, 915x412, 412x860 and 777x1164, each
// between waves (the book open, Auto counting down), in a wave and paused in a wave: <tag>-<w>x<h>-<between|wave|paused>.png;
// and at 1164x777 and 1266x713 the minimap open between waves and in a wave: <tag>-<w>x<h>-map-<between|wave>.png; and
// in a Town with Auto on ("Leave town", no countdown: decisions-log 328): <tag>-<w>x<h>-town.png.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/hud-merge');
const tag = String.fromEnvironment('TAG', defaultValue: 'after');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A small army of five types, some gold and a few waves behind it, so the rows and the field look played.
Game army() {
  final g = Game(Random(7), Random(107))
    ..gold = 1480
    ..wave = 3;
  for (final (type, col, row) in const [('knight', 2, 2), ('knight', 2, 4), ('archer', 1, 3), ('priest', 0, 3), ('lancer', 1, 5)]) {
    g.place(type, col, row);
  }
  return g;
}

void main() {
  testWidgets('hud merge shots $tag', (tester) async {
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
        File('$out/$tag-$name.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
      // ignore: avoid_print
      print('wrote $out/$tag-$name.png k ${b.hudScale} meter ${b.waveMeter} counter ${b.troopCounter} hearts ${b.livesBar} '
          'gold ${b.goldPanel} panel ${b.heartsGoldPanel} x2 ${b.speedButton} toggle ${b.toggleButton} pause ${b.pauseButton} '
          'start ${b.startButton} auto ${b.autoButton} '
          'book ${b.bookButton} map ${b.miniMap} chip ${b.chestChip}');
    }

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      for (final size in const [Size(1164, 777), Size(1266, 713), Size(915, 412), Size(412, 860), Size(777, 1164)]) {
        tester.view.physicalSize = size;
        final name = '${size.width.round()}x${size.height.round()}';
        final maps = size == const Size(1164, 777) || size == const Size(1266, 713);
        for (final map in [false, if (maps) true]) {
          b.miniMapOpen = map;
          final g = b.state = army();
          await frames(tester, 3); // the board takes the game in (a new game ends any countdown)
          b.autoStart
            ..set(true)
            ..won(); // counting down, as after a win: "Start 4" by the shot
          await frames(tester, 60);
          await shot(map ? '$name-map-between' : '$name-between');
          b.autoStart.set(false);
          g.startWave();
          await frames(tester, 220); // the first monsters come into view
          await shot(map ? '$name-map-wave' : '$name-wave');
          if (map) continue;
          g.paused = true;
          await frames(tester, 20);
          await shot('$name-paused');
          g.paused = false;
        }
        // In a Town (decisions-log 216) with Auto on: the toggle's Start is "Leave town", no countdown (decisions-log 328).
        final town = b.state = army()
          ..townAt = 4;
        await frames(tester, 3); // the board goes into the due Town by itself once the game is calm
        if (!town.inTown) expect(town.enterTown(auto: true), isTrue);
        b.autoStart.set(true);
        await frames(tester, 60);
        await shot('$name-town');
        b.autoStart.set(false);
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
      b.miniMapOpen = false;
    }
  });
}
