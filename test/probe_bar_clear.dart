// Nothing of the battle behind the spawn bar (decisions-log 287; ui-hud.md "Spawn bar"): the w89 save's waves fought on
// the Board at each size (`SIZES`, default the owner's 1600x947, 1266x713, 1164x777 and 915x412), `FRAMES` frames each
// at x2 with 3 more game steps between frames, a wave begun again whenever one ends. Each step, every unit's drawn
// bottom (its shadow's last row, 6 under its y; a dying one's too), every shot's (8) and the pinned plate's (the lowest
// unit pinned every 2 s) against the bar's top (the step), where it overlaps
// the bar across. A probe, not part of the suite (no `_test.dart`): queue `["test", "test/probe_bar_clear.dart"]` with a
// mirror as `dir` (about 2 min; wave 90, a boss's, is about 3 min of the game). It never touches the real save (flutter_test_config.dart's temp dir). A line
// `CLEAR {json}` a size; it fails on any overlap.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';

const sizes = String.fromEnvironment('SIZES', defaultValue: '1600x947,1266x713,1164x777,915x412');
const frameCount = int.fromEnvironment('FRAMES', defaultValue: 1500);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Game w89() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>,
    Random(89), Random(189), Random(389));

void main() {
  testWidgets('nothing of the battle behind the bar', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 947)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadHudFontNow);
    final game = TdGame();
    await tester.pumpWidget(GameWidget(game: game));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue);
    final b = game.board
      ..welcome = null
      ..guideSeen = null
      ..miniMapOpen = false
      ..speed = 2;

    for (final spec in sizes.split(',')) {
      final [w, h] = [for (final n in spec.split('x')) double.parse(n)];
      tester.view.physicalSize = Size(w, h);
      final g = b.state = w89();
      await frames(tester, 2);
      final low = <String, double>{'unit': 0, 'shot': 0, 'plate': 0};
      final over = <String>[];
      var (steps, waves, boss, mini, foes, pins, seconds) = (0, 0, false, false, 0, 0, 0.0);
      Rect bar = Rect.zero;
      void seen(String what, double x, double bottom, [double half = 7]) {
        low[what] = max(low[what]!, bottom);
        if (bottom > bar.top + 0.5 && x + half > bar.left && x - half < bar.right) over.add('$what at ($x, $bottom) under ${bar.top}');
      }

      void check() {
        steps++;
        bar = b.spawnBarArea;
        expect(bar, isNot(Rect.zero), reason: '$spec: the bar');
        final s = b.toScreen(0, 1).dy - b.toScreen(0, 0).dy;
        for (final u in g.units) {
          final p = b.toScreen(u.pos.x, u.pos.y + 6);
          seen('unit', p.dx, p.dy, 7 * s);
        }
        for (final o in g.shots) {
          final p = b.toScreen(o.pos.x, o.pos.y + 8);
          seen('shot', p.dx, p.dy, 8 * s);
        }
        final plate = b.pinnedPlate;
        if (plate != Rect.zero) seen('plate', plate.center.dx, plate.bottom, plate.width / 2);
        boss |= g.bossBarUnits.any((u) => u.alive && u.tier == Tier.boss);
        mini |= g.bossBarUnits.any((u) => u.alive && u.tier == Tier.miniBoss);
        foes = max(foes, g.enemies.where((u) => u.alive).length);
      }

      for (var f = 0; f < frameCount; f++) {
        if (!g.waveActive || g.over) {
          if (g.over) break;
          g.startWave();
          waves++;
        }
        for (var i = 0; i < 3; i++) {
          g.tick(1 / 30);
          seconds += 1 / 30;
          check();
        }
        if (f % 60 == 30) {
          // The lowest unit pinned: a tap on its body.
          final all = [for (final u in g.units) if (u.alive) u]..sort((a, c) => c.pos.y.compareTo(a.pos.y));
          if (all.isNotEmpty) {
            await tester.tapAt(b.toScreen(all.first.pos.x, all.first.pos.y - 7));
            if (b.pinned != null) pins++;
          }
        }
        await frames(tester, 1);
        seconds += 0.016 * b.speed;
        check();
      }
      // ignore: avoid_print
      print('CLEAR ${jsonEncode({
            'size': spec,
            'steps': steps,
            'gameSeconds': seconds.round(),
            'waves': waves,
            'barTop': bar.top,
            'lowest': {for (final e in low.entries) e.key: (e.value * 10).round() / 10},
            'boss': boss,
            'miniBoss': mini,
            'maxFoes': foes,
            'pins': pins,
            'overlaps': over.length,
            'first': over.take(3).toList(),
          })}');
      expect(over, isEmpty, reason: '$spec: drawn behind the bar');
      b.state = Game();
      await frames(tester, 3);
    }
    await frames(tester, 10);
  });
}
