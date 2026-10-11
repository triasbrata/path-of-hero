// The spawn bar's step and its slopes (decisions-log 295; ui-hud.md "Spawn bar"): offscreen shots into
// <probe root>/shots/step-seam/new (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_step_seam_shots.dart"]` with a mirror as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir).
//
// At each size (`SIZES`, default the owner's 1600x947, 1266x713, 1164x777 and 915x412): the w89 save two seconds into
// its wave, the book shut. A line `SEAM {json}` a shot: the step's area, its top, the floor's lip, the floor's pixels on
// the screen (q), the hotbar, +Room's and Auto Buy's press areas and the battle log's button.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/step-seam/new');
const sizes = String.fromEnvironment('SIZES', defaultValue: '1600x947,1266x713,1164x777,915x412');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Game w89() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>,
    Random(89), Random(189), Random(389));

void main() {
  testWidgets('step seam shots', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 947)
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
      ..guideSeen = null
      ..miniMapOpen = false;

    Future<void> shot(String name) async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = (await tester.runAsync(() => boundary.toImage()))!;
      await tester.runAsync(() async {
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
      // ignore: avoid_print
      print('SEAM ${jsonEncode({
            'shot': '$name.png',
            'area': _r(b.spawnBarArea),
            'stepTop': b.toScreen(0, stepLip).dy,
            'lip': b.toScreen(0, frontLip).dy,
            'q': (b.toScreen(0, 1).dy - b.toScreen(0, 0).dy) / 5,
            'room': _r(b.capacityButton),
            'auto': _r(b.autoReplaceButton),
            'log': _r(b.logButton),
            'panel': _r(b.spawnBarPanel),
          })}');
    }

    for (final spec in sizes.split(',')) {
      final [w, h] = [for (final n in spec.split('x')) double.parse(n)];
      tester.view.physicalSize = Size(w, h);
      final g = b.state = w89();
      await frames(tester, 2);
      g.startWave();
      await frames(tester, 120);
      await shot(spec);
    }
    await frames(tester, 10);
  });
}

List<int> _r(Rect r) => [r.left.round(), r.top.round(), r.right.round(), r.bottom.round()];
