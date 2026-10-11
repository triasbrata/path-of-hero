// The redrawn glyphs seen (decisions-log 168 and 179, docs/ui-hud.md "The font"): offscreen shots into
// <probe root>/shots/glyph/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_glyph_shots.dart"]` with a mirror as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir); the dice are seeded, so a rerun gives the same shots.
//
// At 1266x713 (`desk-`) and 412x860 (`phone-`): page (the "Cara Main" page: its bold title, its topics in the body
// weight) and page-zoom (its left page 2x); curse (a necromancer high elite's Curse of Frailty splash, its ribbon bold)
// and curse-zoom (the panel 2x). Then lines: test lines in the game's style at body and title sizes, 3x.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/hud_font.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/glyph');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> savePng(ui.Image img, String file) async {
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File('$out/$file.png')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote $out/$file.png ${img.width}x${img.height}');
}

/// [src] cut to [crop] and scaled [k]x, pixel for pixel.
Future<ui.Image> zoomed(ui.Image src, Rect crop, [double k = 2]) {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawImageRect(src, crop, Offset.zero & (crop.size * k), Paint()..filterQuality = FilterQuality.none);
  return rec.endRecording().toImage((crop.width * k).round(), (crop.height * k).round());
}

/// The game at [size], loaded, with no welcome screen, no minimap and the guide's first cards seen.
Future<(TdGame, GlobalKey)> boot(WidgetTester tester, Size size) async {
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
  game.board
    ..welcome = null
    ..miniMapOpen = false
    ..guideSeen = {'intro', 'P1', 'P2', 'P3', 'P4', 'P5'}
    ..state = Game().boardRules();
  return (game, key);
}

/// The screen (the pointer parked in a corner, so no row is lit) as [name]-[file], and [crop] of it 2x as -zoom.
Future<void> shot(WidgetTester tester, GlobalKey key, String name, String file, [Rect? crop]) async {
  await tester.sendEventToBinding(TestPointer(1, PointerDeviceKind.mouse).hover(const Offset(1, 1)));
  await frames(tester, 2);
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final img = await boundary.toImage();
    await savePng(img, '$name-$file');
    if (crop != null) {
      await savePng(await zoomed(img, crop.intersect(Offset.zero & Size(img.width.toDouble(), img.height.toDouble()))),
          '$name-$file-zoom');
    }
  });
}

void main() {
  for (final (name, size) in [('desk', const Size(1266, 713)), ('phone', const Size(412, 860))]) {
    testWidgets('glyph shots: the Cara Main page ($name)', (tester) async {
      final (game, key) = await boot(tester, size);
      final b = game.board..showSettings();
      await frames(tester, 40);
      await tester.tapAt(b.howToButton.center);
      await frames(tester, 30);
      final left = b.howToColumns[0];
      await shot(tester, key, name, 'page', Rect.fromLTRB(left.left - 16, left.top - 50, left.right + 16, left.bottom));
    });

    testWidgets('glyph shots: the Curse of Frailty splash ($name)', (tester) async {
      final (game, key) = await boot(tester, size);
      // The w86 fixture on wave 60, 2 s played with no casts kept, then the caster beside the front monster.
      final b = game.board..guideSeen = null;
      final save = jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync());
      final g = b.state = Game.fromJson(save as Map<String, dynamic>, Random(7), Random(107), Random(307))
        ..loot = Random(207)
        ..wave = 59;
      await frames(tester, 30);
      b.showMessage('', time: 0);
      g.startWave();
      for (var i = 0; i < 60 && !g.over; i++) {
        g.tick(1 / 30);
        g.heroCasts.clear();
        g.monsterCasts.clear();
      }
      await frames(tester, 2);
      b.guideSeen = {};
      final front = g.enemies.where((u) => u.alive).fold<Unit?>(null, (a, u) => a == null || u.pos.x < a.pos.x ? u : a);
      final at = front == null ? Point(g.cam + g.viewW * 0.6, 60.0) : Point(front.pos.x + 14, front.pos.y);
      g.monsterCasts.add((g.monster(boss, Tier.highElite, at), MonsterSkill.curseOfFrailty));
      await frames(tester, 25);
      final f = b.foeSplash;
      // ignore: avoid_print
      print('$name curse: ${f?.title} at ${f?.panel}');
      await shot(tester, key, name, 'curse', f?.panel.inflate(16));
    });
  }

  testWidgets('glyph shots (lines)', (tester) async {
    await loadHudFont(tester);
    const lines = [
      'Cara Main  Curse of Frailty  Crushing Blow',
      'Controls  Items & Bangkit  Peti Bos & Pusaka',
      'Gelombang 12  Cost: troop price +10%  Kocok ulang',
      'CC 55  BG 8B  OCO GBG  Circle Slash  Chain Hook',
      'Pindah  Pilih ini  cocok  lilin  ilmu  Zirah',
      'The fight  at first  fire  flag  official  coffee',
      'Pasukan Ksatria  tanah  1.552.505  69 96 2026 3/8',
    ];
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(const Rect.fromLTWH(0, 0, 640, 560), Paint()..color = const Color(0xFFF3C99B));
    var y = 6.0;
    for (final (size, bold) in [(14.0, false), (18.0, false), (18.0, true), (26.0, true)]) {
      for (final s in lines) {
        final p = TextPainter(
            text: TextSpan(text: s, style: hudStyle(size, bold: bold, color: const Color(0xFF4A2A1A))),
            textDirection: TextDirection.ltr)
          ..layout();
        p.paint(c, Offset(6, y));
        y += p.height + 1;
      }
      y += 4;
    }
    await tester.runAsync(() async {
      final img = await rec.endRecording().toImage(640, y.ceil());
      await savePng(await zoomed(img, Rect.fromLTWH(0, 0, 640, y.ceilToDouble()), 3), 'lines');
    });
  });
}
