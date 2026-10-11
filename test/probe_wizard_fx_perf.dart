// What the wizard's magic costs a frame (decisions-log 313): the owner's wave-30 save (a copy, `SAVE`) fought for 40 s
// of its wave on a booted board at 1600x947, the board stepped at 30 fps (`Board.update`), and each frame's drawing
// (`Board.render` into a picture) timed; every 10th frame also rasterised (`toImage`) and timed. As saved (4 wizards),
// and with 16 wizards more set down behind the line past the caps (`+16`). Prints the mean, median, 95th percentile and worst of both, and how
// many wizard shots flew and bursts played. A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_wizard_fx_perf.dart", "--dart-define=TAG=after"]` with the worktree (or a `git archive` mirror
// of a base, `TAG=before`) as `dir`. It reads the save copy only and never touches the real save (flutter_test_config.dart's
// temp dir); the dice are seeded.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const save = String.fromEnvironment('SAVE', defaultValue: '$probeRoot/shots/mage-fx/save-w30-copy.json');
const tag = String.fromEnvironment('TAG', defaultValue: 'after');

String stats(List<double> ms) {
  if (ms.isEmpty) return 'none';
  final s = [...ms]..sort();
  double at(double q) => s[min(s.length - 1, (q * s.length).floor())];
  return 'n ${s.length} mean ${(s.reduce((a, b) => a + b) / s.length).toStringAsFixed(2)} p50 ${at(0.5).toStringAsFixed(2)} '
      'p95 ${at(0.95).toStringAsFixed(2)} max ${s.last.toStringAsFixed(2)} ms';
}

void main() {
  testWidgets('wizard fx perf', (tester) async {
    await tester.runAsync(() async {
      await loadHudFontNow();
    });
    tester.view
      ..physicalSize = const Size(1600, 947)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = TdGame();
    await tester.pumpWidget(GameWidget(game: game));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue);
    final b = game.board
      ..welcome = null
      ..miniMapOpen = false;
    final json = jsonDecode(File(save).readAsStringSync()) as Map<String, dynamic>;

    for (final extra in [0, 16]) {
      final g = b.state = Game.fromJson(json, Random(30), Random(130), Random(330))
        ..loot = Random(230)
        ..slots = Random(430);
      await tester.pump(const Duration(milliseconds: 16));
      if (b.messageBox != Rect.zero) {
        await tester.tapAt(b.messageBox.center); // the save's notes over the field
        await tester.pump(const Duration(milliseconds: 16));
      }
      var added = 0;
      for (; added < extra; added++) {
        // Past the army's and the type's caps: set down behind the line, four to a column.
        final at = Point(g.baseX + tile * (2 + added ~/ 4), tile * (1 + 2 * (added % 4)));
        g.units.add(Unit(Side.troop, 'wizard', g.statsOf('wizard'), at)
          ..post = at
          ..entered = true
          ..arriving = false);
      }
      g.startWave();
      final draw = <double>[], raster = <double>[];
      var frames = 0, shotsSeen = 0, wizards = 0;
      final sw = Stopwatch();
      while (g.t < 40 && g.waveActive && !g.over && frames < 4000) {
        b.update(1 / 30);
        frames++;
        final rec = ui.PictureRecorder();
        sw
          ..reset()
          ..start();
        b.render(Canvas(rec));
        sw.stop();
        draw.add(sw.elapsedMicroseconds / 1000);
        final pic = rec.endRecording();
        if (frames % 10 == 0) {
          final ms = await tester.runAsync(() async {
            final t = Stopwatch()..start();
            final img = await pic.toImage(1600, 947);
            t.stop();
            img.dispose();
            return t.elapsedMicroseconds / 1000;
          });
          raster.add(ms!);
        }
        pic.dispose();
        shotsSeen += g.shots.where((s) => s.from.type == 'wizard').length;
        wizards = max(wizards, g.troops.where((u) => u.alive && u.type == 'wizard').length);
      }
      // ignore: avoid_print
      print('$tag +$extra (added $added): wave ${g.wave} t ${g.t.toStringAsFixed(1)} frames $frames wizards $wizards '
          'wizard shots in flight a frame ${(shotsSeen / max(1, frames)).toStringAsFixed(2)}');
      // ignore: avoid_print
      print('$tag +$extra draw: ${stats(draw)}');
      // ignore: avoid_print
      print('$tag +$extra raster: ${stats(raster)}');
    }
    b.state = Game();
    await tester.pump(const Duration(milliseconds: 16));
  });
}
