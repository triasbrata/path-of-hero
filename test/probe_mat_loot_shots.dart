// The materials lying on the field (decisions-log 262; docs/ui-hud.md "A kill's pop", "Win popup"): offscreen shots into
// <probe root>/shots/mat-loot/ (`OUT`) and what the piles cost a frame. A probe, not part of the suite (no
// `_test.dart`): queue `["test", "test/probe_mat_loot_shots.dart"]` with the worktree as `dir`. It never touches the real
// save (flutter_test_config.dart's temp dir); the dice are seeded.
//
// The owner's w89 save (the fixture) with the Towns and the forge on fights wave 90 for `MID` s of game time (the board
// draining its drops every update, no frame drawn), then at 1266x713 and 412x860 (<size>): mid-<size> (the materials
// lying), hop-<size> and spread-<size> (24 drops of four kinds on the open grass ahead of the brawl, the tally with them:
// hopping, then lying in piles with their counts), win1-<size> and win2-<size> (the wave won: 0.45 s and 0.75 s on, the
// piles flying to the Bag) and won-<size> (1.6 s on: all in the Bag, the "VICTORY!" line). Then at 1266x713 the same fight again for the cost: the board's
// render of that frame recorded 40 times with the piles and 40 without (the tally cleared, which takes them off), the
// median of each, and how many piles and count capsules it drew.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/mat-loot');
const seed = int.fromEnvironment('SEED', defaultValue: 3);
const mid = int.fromEnvironment('MID', defaultValue: 40);
const _save = 'test/fixtures/save-20261002-2222-w89-sellbug.json';

/// The w89 save with its dice seeded, the Towns and the forge on.
Game w89() =>
    Game.fromJson(jsonDecode(File(_save).readAsStringSync()) as Map<String, dynamic>, Random(seed), Random(seed + 100), Random(seed + 300))
      ..loot = Random(seed + 200)
      ..slots = Random(seed + 400)
      ..draft = Random(seed + 500)
      ..townDice = Random(seed + 600)
      ..matDice = Random(seed + 700);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

String piles(Board b) {
  final n = b.matLoot.fold(0, (a, p) => a + p.$2), counted = b.matLoot.where((p) => p.$2 > 1).length;
  return 'piles ${b.matLoot.length} (count capsules $counted) holding $n, flying ${b.matLoot.where((p) => p.$3).length}';
}

void main() {
  Future<(Board, GlobalKey)> boot(WidgetTester tester, Size size) async {
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
    return (b, key);
  }

  /// Wave 90 on [b]'s w89 game, [mid] s of it with no frame drawn (a foe skill's splash waits out its time).
  Future<Game> fight(WidgetTester tester, Board b) async {
    final g = b.state = w89();
    await frames(tester, 30);
    if (b.messageBox != Rect.zero) {
      await tester.tapAt(b.messageBox.center);
      await frames(tester, 3);
    }
    g.startWave();
    final end = g.t + mid;
    for (var i = 0; i < 200000 && g.t < end && !g.over; i++) {
      b.update(1 / 30);
    }
    // ignore: avoid_print
    print('wave ${g.wave} at ${g.t.toStringAsFixed(1)} s: kills ${g.kills}, tally ${g.waveMaterials.values.fold(0, (a, n) => a + n)} '
        'in ${g.waveMaterials.length} kinds, over ${g.over}; ${piles(b)}');
    return g;
  }

  for (final size in const [Size(1266, 713), Size(412, 860)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('mat loot shots $tag', (tester) async {
      final (b, key) = await boot(tester, size);
      Future<void> shot(String name) async {
        await frames(tester, 1);
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = (await tester.runAsync(() => boundary.toImage()))!;
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name-$tag.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        // ignore: avoid_print
        print('wrote $out/$name-$tag.png  ${piles(b)} victory ${b.victoryLoot}');
      }

      final g = await fight(tester, b);
      await frames(tester, 4);
      await shot('mid');
      // The open grass ahead of the brawl: 24 drops of four kinds as kills would make them (the tally with them),
      // some on one spot, landed.
      final kinds = [Mat.slimeGel, Mat.wolfClaw, Mat.boneShard, Mat.evilEye];
      for (var i = 0; i < 24; i++) {
        final at = Point(b.camX + g.viewW * (0.66 + 0.05 * (i % 6)), 16.0 + 26 * (i ~/ 6 % 4)), m = kinds[i % 4], n = 1 + i % 3;
        g.waveMaterials[m] = (g.waveMaterials[m] ?? 0) + n;
        g.matPops.add((at, m, n));
      }
      await frames(tester, 12);
      await shot('hop');
      await frames(tester, 40);
      await shot('spread');
      // The win: what is left of the wave goes.
      g.queue.clear();
      for (final u in g.enemies) {
        u.gone = true;
      }
      for (var i = 0; i < 20 && g.waveActive; i++) {
        await frames(tester, 1);
      }
      expect(g.waveActive, isFalse);
      for (final (name, at) in const [('win1', 0.45), ('win2', 0.75), ('won', 1.6)]) {
        for (var i = 0; i < 400 && g.t - g.victoryAt < at - 0.016; i++) {
          await frames(tester, 1);
        }
        await shot(name);
      }
    });
  }

  testWidgets('mat loot frame cost 1266x713', (tester) async {
    final (b, _) = await boot(tester, const Size(1266, 713));
    final g = await fight(tester, b);
    await frames(tester, 4);
    double median() {
      final times = <int>[];
      for (var i = 0; i < 40; i++) {
        final rec = ui.PictureRecorder(), sw = Stopwatch()..start();
        b.render(Canvas(rec));
        sw.stop();
        rec.endRecording().dispose();
        times.add(sw.elapsedMicroseconds);
      }
      times.sort();
      return times[times.length ~/ 2] / 1000;
    }

    median(); // warm up
    final drawn = piles(b), withPiles = median();
    final tally = {...g.waveMaterials};
    g.waveMaterials.clear(); // the piles leave with their tally
    b.update(0);
    final without = median();
    g.waveMaterials.addAll(tally);
    // ignore: avoid_print
    print('COST frame ${withPiles.toStringAsFixed(2)} ms with $drawn; ${without.toStringAsFixed(2)} ms without '
        '(${b.matLoot.length} piles); the piles ${(withPiles - without).toStringAsFixed(2)} ms');
  });
}
