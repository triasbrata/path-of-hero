// The Pusaka seen (decisions-log 149, ui-hud.md "The Pusaka in battle"): offscreen shots of the owner's wave-86 save
// (the fixture, its five Pusaka bound by default) on the wave-90 boss wave, into <probe root>/shots/pusaka-bukti/
// (`OUT`). A probe, not part of the suite (no `_test.dart`): queue `["test", "test/probe_pusaka_shots.dart"]` with the
// worktree as `dir`. It never touches the real save (flutter_test_config.dart's temp dir); the dice are seeded and
// the play is at a fixed step, so a rerun gives the same shots.
//
// It writes, at 1280x720: book-names (the Pasukan rows' build names, between waves), rings (the fight, and
// rings-zoom, a 3x crop round a bound templar), grail-cutin (the wave's first Grail save), menang (the "MENANG!"
// popup with the Pusaka's line, from the fight's counters), log (the battle log on its Pusaka chip).
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/pusaka-bukti');
const seed = int.fromEnvironment('SEED', defaultValue: 7);
const shotSize = Size(1280, 720);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The fixture (the owner's w86 save from before the Pusaka): loaded, it is migrated and its five bound by default.
Game load() {
  final save = jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>;
  return Game.fromJson(save, Random(seed), Random(seed + 100), Random(seed + 300))..loot = Random(seed + 200);
}

void main() {
  testWidgets('pusaka shots', (tester) async {
    tester.view
      ..physicalSize = shotSize
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

    Future<ui.Image> grab() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return (await tester.runAsync(() => boundary.toImage()))!;
    }

    Future<void> save(ui.Image img, String name) async {
      await tester.runAsync(() async {
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
      // ignore: avoid_print
      print('wrote $out/$name.png ${img.width}x${img.height}');
    }

    Future<ui.Image> shot(String name, [int settle = 20]) async {
      await frames(tester, settle);
      final img = await grab();
      await save(img, name);
      return img;
    }

    /// [src] cut to [crop] and scaled [k] times, pixel for pixel.
    Future<void> zoom(ui.Image src, Rect crop, double k, String name) async {
      final img = await tester.runAsync(() {
        final rec = ui.PictureRecorder();
        Canvas(rec).drawImageRect(src, crop, Offset.zero & (crop.size * k), Paint()..filterQuality = FilterQuality.none);
        return rec.endRecording().toImage((crop.width * k).round(), (crop.height * k).round());
      });
      await save(img!, name);
    }

    // Plays [seconds] of the wave at a fixed step, a frame every half second; stops early, right after the frame on
    // which [until] holds.
    Future<void> play(Game g, double seconds, {bool Function()? until}) async {
      for (var t = 0.0; t < seconds; t += 0.5) {
        for (var i = 0; i < 15 && !g.over; i++) {
          g.tick(1 / 30);
        }
        g.heroCasts.clear();
        await frames(tester, 1);
        if (until?.call() ?? false) return;
      }
    }

    // Between waves: the Pasukan rows with their build names.
    final g = b.state = load()..wave = 89;
    await shot('book-names', 60);
    // ignore: avoid_print
    print('bound: ${{for (final MapEntry(key: r, value: p) in g.pusaka.entries) r.name: p.type}}');

    // The wave-90 boss wave: the rings, then the first Grail save's cut-in.
    g.startWave();
    await frames(tester, 2);
    await play(g, 14);
    final fight = await shot('rings', 2);
    final templar = g.troops.where((u) => u.alive && u.type == 'knight_templar').firstOrNull;
    if (templar != null) {
      final at = b.toScreen(templar.pos.x, templar.pos.y);
      final crop = Rect.fromCenter(center: at, width: 320, height: 180).intersect(Offset.zero & shotSize);
      await zoom(fight, crop, 3, 'rings-zoom');
    }
    await play(g, 120, until: () => b.grailCutIn != null);
    // ignore: avoid_print
    print('cut-in: ${b.grailCutIn} at t ${g.t.toStringAsFixed(1)}');
    if (b.grailCutIn != null) await shot('grail-cutin', 12);

    // "MENANG!" with the fight's counters, and the log's Pusaka chip.
    final saves = g.log.entries.whereType<GrailSaved>().length;
    final r = PusakaReport(g.wave, g.t, lines: [
      for (final MapEntry(key: relic, value: p) in g.pusaka.entries)
        if (p.type != null) (relic: relic, type: p.type!, stars: p.stars, uses: g.pusakaWorth[relic]?.uses ?? 0, worth: g.pusakaWorth[relic]?.worth ?? 0),
    ], returned: {...g.relicsBack});
    // ignore: avoid_print
    print('saves $saves; ${logLines(r).join(' | ')}; win line: ${pusakaWinLine(r)}');
    final won = b.state = load()..wave = 90;
    won
      ..lastPusaka = r
      ..victoryAt = won.t;
    await shot('menang', 30);
    b.state = g;
    await frames(tester, 2);
    await tester.tapAt(b.logButton.center);
    await frames(tester, 2);
    // ignore: avoid_print
    print('log open: ${b.logPanel}');
    await shot('log', 4);
  });
}
