// The game's font seen (decisions-log 158, ui-hud.md "The font"): offscreen shots of the main screens,
// into <probe root>/shots/font-pixelify/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_font_shots.dart"]` with the worktree as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir); the dice are seeded, so a rerun gives the same shots.
//
// At 1266x713 (device pixel ratio 2, a Retina Mac) and 412x860 (ratio 3, a phone), shot at the device's own pixels so
// the font's edges show as they would: welcome, chest (the owner's w86 save: its first catch-up chest), pasukan, tas,
// toko, tooltip (a Pusaka badge's), menang, battle (a wave of w86 under way) and log (its battle log open), lisensi.
// Then `weights`: the HUD's sizes in 400 / 500 / 700, and the widths each weight lays out (the wght axis applied, not
// a synthetic bold: 700's advances are wider), and `sweep`: how many of a line's inked pixels are only partly covered
// at 1.5 to 4 device pixels per font pixel (the crispness rule).
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/hud_font.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/save.dart' show Welcome;

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/font-pixelify');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The fixture (the owner's w86 save: five types, its Pusaka bound by default, 3 catch-up chests).
Game load() {
  final save = jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>;
  return Game.fromJson(save, Random(seed), Random(seed + 100), Random(seed + 300))
    ..loot = Random(seed + 200)
    ..draft = Random(seed + 500)
    ..boardRules();
}

Future<void> savePng(WidgetTester tester, ui.Image img, String name) async {
  await tester.runAsync(() async {
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
  // ignore: avoid_print
  print('wrote $out/$name.png ${img.width}x${img.height}');
}

/// [text] laid out in the game's font at drawn size [px], weight [w] (no HUD scale: the sweep sets the drawn size).
TextPainter painter(String text, double px, FontWeight w, [Color color = const Color(0xFF000000)]) => TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontFamily: hudFont, fontSize: px, fontWeight: w, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();

void main() {
  for (final (size, ratio) in const [(Size(1266, 713), 2.0), (Size(412, 860), 3.0)]) {
    final tag = '${size.width.round()}';
    testWidgets('font shots $tag', (tester) async {
      tester.view
        ..physicalSize = size * ratio
        ..devicePixelRatio = ratio;
      addTearDown(tester.view.reset);
      await loadHudFont(tester);
      final game = TdGame();
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: GameWidget(game: game)));
      for (var i = 0; i < 3000 && !game.isLoaded; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(game.isLoaded, isTrue);
      final b = game.board..miniMapOpen = false;

      Future<void> shot(String name, [int settle = 20]) async {
        await frames(tester, settle);
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = (await tester.runAsync(() => boundary.toImage(pixelRatio: ratio)))!;
        await savePng(tester, img, '$name-$tag');
      }

      Future<void> tap(Offset p) async {
        await tester.tapAt(p);
        await frames(tester, 2);
      }

      Future<void> tab(String name) async {
        final t = b.bookTabs.where((t) => t.$1 == name);
        if (t.isNotEmpty) await tap(t.first.$2.center);
      }

      b.welcome = Welcome(Game()..wave = 3, discard: () {});
      await shot('welcome', 30);
      b.welcome = null;

      b.state = load();
      await frames(tester, 3);
      await tap(const Offset(2, 2)); // the save's notes go, the popup stays
      await shot('chest', 30);

      final g = b.state = load()..chests.clear();
      await frames(tester, 3);
      if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
      await frames(tester, 60); // the book floats in
      await tab('troops');
      await shot('pasukan', 30);

      final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      final badge = b.pusakaBadge('knight_templar');
      if (badge != Rect.zero) {
        await mouse.moveTo(badge.center);
        await frames(tester, 30);
        // ignore: avoid_print
        print('tooltip: ${b.tooltipShown}');
        await shot('tooltip', 2);
      }
      await mouse.moveTo(Offset.zero);
      await frames(tester, 4);

      await tab('bag');
      await shot('tas', 30);
      await tab('store');
      await shot('toko', 30);
      b.showSettings();
      await frames(tester, 10);
      if (b.licenceButton != Rect.zero) {
        await tap(b.licenceButton.center);
        await shot('lisensi', 30);
        if (b.licenceBack != Rect.zero) await tap(b.licenceBack.center);
      }
      await tab('troops');

      final won = b.state = load()
        ..wave = 90
        ..chests.clear();
      won.victoryAt = won.t;
      await shot('menang', 30);

      b.state = g;
      await frames(tester, 3);
      g.startWave();
      for (var t = 0.0; t < 12; t += 0.5) {
        for (var i = 0; i < 15 && !g.over; i++) {
          g.tick(1 / 30);
        }
        g.heroCasts.clear();
        await frames(tester, 1);
      }
      await shot('battle', 4);
      await tap(b.logButton.center);
      await shot('log', 4);
    });
  }

  testWidgets('weights and the crispness sweep', (tester) async {
    await loadHudFont(tester);
    const line = 'Gelombang 12 Pasukan Ksatria';
    // The wght axis: at one size, 700 lays out wider than 500 and 500 than 400, as the font's advances do (H: 586, 592,
    // 603 units); a synthetic bold would keep 400's widths.
    final widths = {for (final w in [FontWeight.w400, FontWeight.w500, FontWeight.w700]) w.value: painter(line, 22, w).width};
    // ignore: avoid_print
    print('widths at 22 px: $widths');
    expect(widths[500]!, greaterThan(widths[400]!));
    expect(widths[700]!, greaterThan(widths[500]!));

    // A sample: the HUD's common sizes in each weight, at 2 device pixels per logical pixel.
    const ratio = 2.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec)..scale(ratio);
    c.drawRect(const Rect.fromLTWH(0, 0, 640, 300), Paint()..color = const Color(0xFFF6CA9F));
    var y = 6.0;
    for (final hud in [11.0, 14.0, 18.0, 22.0]) {
      var x = 6.0;
      for (final w in [FontWeight.w400, FontWeight.w500, FontWeight.w700]) {
        final p = painter('${hud.round()} Pasukan ${w.value}', hud * hudFontScale, w, const Color(0xFF3F2832))..paint(c, Offset(x, y));
        x += p.width + 14;
      }
      y += hud + 10;
    }
    final sample = await tester.runAsync(() => rec.endRecording().toImage((640 * ratio).round(), (300 * ratio).round()));
    await savePng(tester, sample!, 'weights');

    // The sweep: the share of a line's inked device pixels that are only partly covered, by device pixels per font
    // pixel (drawn size = that × 11 / ratio), at a whole-pixel origin and at a quarter-pixel one.
    final rows = <String>[];
    for (final fpx in [1.5, 1.75, 2.0, 2.25, 2.5, 2.62, 2.75, 3.0, 3.5, 4.0]) {
      final cols = <String>[];
      for (final w in [FontWeight.w500, FontWeight.w700]) {
        for (final dx in [0.0, 0.25]) {
          final px = fpx * hudFontGrid / ratio, p = painter(line, px, w);
          final wide = ((p.width + 8) * ratio).ceil(), high = ((p.height + 8) * ratio).ceil();
          final r = ui.PictureRecorder();
          p.paint(Canvas(r)..scale(ratio), Offset(4 + dx / ratio, 4));
          final img = (await tester.runAsync(() => r.endRecording().toImage(wide, high)))!;
          final bytes = (await tester.runAsync(() => img.toByteData()))!;
          var ink = 0, soft = 0;
          for (var i = 3; i < bytes.lengthInBytes; i += 4) {
            final a = bytes.getUint8(i);
            if (a > 5) ink++;
            if (a > 5 && a < 250) soft++;
          }
          cols.add('${w.value}${dx == 0 ? '' : '+¼'} ${(soft / ink).toStringAsFixed(2)}');
        }
      }
      rows.add('fpx $fpx (drawn ${(fpx * hudFontGrid / ratio).toStringAsFixed(2)} px): ${cols.join('  ')}');
    }
    // ignore: avoid_print
    print('sweep (soft share of inked pixels):\n${rows.join('\n')}');
  });
}
