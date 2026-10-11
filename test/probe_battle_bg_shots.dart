// The battle's backdrop (decisions-log 228, 244): offscreen shots of the band above the field, the props line and the
// floor, before and after, into <probe root>/shots/battle-bg/ (`OUT`, `TAG` = before|after|...). A probe, not
// part of the suite (no `_test.dart`): queue `["test", "test/probe_battle_bg_shots.dart", "--dart-define=TAG=after"]`.
// It never touches the real save (flutter_test_config.dart's temp dir).
//
// At 1266x713, 1164x777 (the owner's tablet), 412x860 and 2560x1440: the welcome screen; a fresh game between waves
// (the camera at the near end, cam 0) and mid-wave with units on the floor; the w89 save (cam ~243,000, the far end)
// between waves and mid-wave. <TAG>-<w>x<h>-<scene>.png. Then at 1266x713: troops in the first lane mid-wave, right
// in front of the props line (lane0-wave), and a still field 3 s apart eight times, the clouds drifting (clouds-<i>).
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
import 'package:tower_defense/save.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/battle-bg');
const tag = String.fromEnvironment('TAG', defaultValue: 'after');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Game army() {
  final g = Game(Random(7), Random(107))..gold = 480;
  for (final (type, col, row) in const [('knight', 2, 2), ('knight', 2, 4), ('archer', 1, 3), ('priest', 0, 3), ('lancer', 1, 5)]) {
    g.place(type, col, row);
  }
  return g;
}

Game w89() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>,
    Random(89), Random(189), Random(389));

void main() {
  testWidgets('battle bg shots $tag', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await loadHudFontNow();
    });
    tester.view.physicalSize = const Size(1266, 713);
    final game = TdGame();
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: GameWidget(game: game)));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue);
    final b = game.board
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
      print('wrote $out/$tag-$name.png ${img.width}x${img.height} cam ${b.state.cam.toStringAsFixed(1)} viewW ${b.state.viewW.toStringAsFixed(1)}');
    }

    for (final size in const [Size(1266, 713), Size(1164, 777), Size(412, 860), Size(2560, 1440)]) {
      tester.view.physicalSize = size;
      final s = '${size.width.round()}x${size.height.round()}';
      b.welcome = Welcome(null, discard: () {});
      await frames(tester, 30);
      await shot('$s-welcome');
      b.welcome = null;
      var g = b.state = army();
      await frames(tester, 60);
      await shot('$s-near');
      g.startWave();
      await frames(tester, 220); // the first monsters come into view
      await shot('$s-near-wave');
      g = b.state = w89();
      await frames(tester, 60);
      await shot('$s-far');
      g.startWave();
      await frames(tester, 220);
      await shot('$s-far-wave');
    }
    tester.view.physicalSize = const Size(1266, 713);
    final lane0 = b.state = Game(Random(7), Random(107))..gold = 480;
    for (final (type, col, row) in const [('knight', 3, 0), ('archer', 1, 0), ('lancer', 2, 1), ('priest', 0, 1), ('knight', 3, 2)]) {
      lane0.place(type, col, row);
    }
    await frames(tester, 60);
    lane0.startWave();
    await frames(tester, 260);
    await shot('1266x713-lane0-wave');
    b.state = army();
    await frames(tester, 60);
    for (var i = 0; i < 8; i++) {
      await shot('1266x713-clouds-$i');
      await tester.pump(const Duration(seconds: 3));
      await frames(tester);
    }
  });
}
