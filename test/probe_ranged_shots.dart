// Where the long range stand in a late fight, seen (decisions-log 199, units-and-combat.md "Long range hold"): offscreen
// shots into <probe root>/shots/ranged/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_ranged_shots.dart"]` with the worktree (or a `git archive` mirror of a base) as `dir`. It never
// touches the real save (flutter_test_config.dart's temp dir); the dice are seeded.
//
// At 1266x713 and 412x860 (`desk-` / `phone-`): the owner's w89 save (the fixture) fighting wave 90, played at a fixed
// step, shot at 30, 50 and 70 s (`<tag>-w90-<t>s`). Each shot's line says where the archers, the wizards and the
// skeleton archers stand: their screen x, and their distance to their nearest foe.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/ranged');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('ranged shots', (tester) async {
    tester.view
      ..physicalSize = const Size(1266, 713)
      ..devicePixelRatio = 1;
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
      print('wrote $out/$name.png ${img.width}x${img.height}');
    }

    final save = jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>;
    for (final (tag, size, viewW) in const [('desk', Size(1266, 713), 341.0), ('phone', Size(412, 860), 219.0)]) {
      tester.view.physicalSize = size;
      final g = b.state = Game.fromJson(save, Random(1), Random(101), Random(301))
        ..loot = Random(201)
        ..slots = Random(401);
      await frames(tester, 2);
      if (b.messageBox != Rect.zero) {
        await tester.tapAt(b.messageBox.center); // the save's notes over the field
        await frames(tester, 1);
      }
      for (var i = 0; i < 300; i++) {
        g.viewW = viewW;
        g.tick(1 / 30);
      }
      g.startWave();
      var t = 0.0;
      for (final at in [30, 50, 70]) {
        while (t < at && g.waveActive && !g.over) {
          g.viewW = viewW;
          g.tick(1 / 30);
          t += 1 / 30;
        }
        await frames(tester, 1); // the board draws it (and plays on 16 ms)
        await shot('$tag-w90-${at}s');
        String where(Unit u) {
          final d = g.units.where((o) => o.side != u.side && o.alive).map((o) => o.pos.distanceTo(u.pos)).fold(double.infinity, min);
          return '${((u.pos.x - g.cam) / g.viewW).toStringAsFixed(2)}/${d.toStringAsFixed(0)}';
        }

        for (final type in ['archer', 'wizard', 'skeleton_archer']) {
          final us = g.units.where((u) => u.alive && u.type == type && (u.side == Side.troop ? u.entered : u.pos.x < g.cam + g.viewW));
          // ignore: avoid_print
          print('$tag t $at $type (screen x / to its nearest foe): ${[for (final u in us) where(u)].join(' ')}');
        }
        // ignore: avoid_print
        print('$tag t $at shots ${g.shots.length} meet ${g.meetMode.name} cam ${g.cam.toStringAsFixed(0)} '
            'meetX ${g.meetX?.toStringAsFixed(0)}');
      }
    }
    await frames(tester, 4);
  });
}
