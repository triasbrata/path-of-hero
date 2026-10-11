// The "Cara Main" page seen (docs/ui-hud.md "Cara Main page", lib/guide_page.dart): offscreen shots into
// <probe root>/shots/guide-page/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_guide_page_shots.dart"]` with a mirror as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir).
//
// At 412x860, 915x412 and 1266x713: settings-<size> (Pengaturan, "Cara Main" under the volume bars), items-<size> and
// items-end-<size> ("Items & Awaken" at its top and scrolled to its end: the items' own texts), pusaka-<size> and
// pusaka-end-<size> ("Boss Chest & Artifacts", the same), replay-<size> ("Ulang panduan": the intro over the page).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/guide-page');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  for (final size in const [Size(412, 860), Size(915, 412), Size(1266, 713)]) {
    final tag = '${size.width.round()}';
    testWidgets('guide page shots $tag', (tester) async {
      tester.view
        ..physicalSize = size
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
        ..miniMapOpen = false
        ..guideSeen = {'intro', 'P1', 'P2', 'P3', 'P4', 'P5'};
      b.state = Game().boardRules();
      final mouse = TestPointer(1, PointerDeviceKind.mouse);

      Future<void> shot(String name, [int settle = 30]) async {
        await tester.sendEventToBinding(mouse.hover(const Offset(1, 1))); // no row lit under the pointer
        await frames(tester, settle);
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = (await tester.runAsync(() => boundary.toImage()))!;
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        // ignore: avoid_print
        print('wrote $out/$name.png ${img.width}x${img.height} topic ${b.howToTopic} columns ${b.howToColumns} '
            'button ${b.howToButton} volumes ${b.volumeRows}');
      }

      Future<void> tap(Rect r) async {
        await tester.tapAt(r.center);
        await frames(tester, 5);
      }

      Future<void> wheel(Offset at, double dy, int n) async {
        await tester.sendEventToBinding(mouse.hover(at));
        for (var i = 0; i < n; i++) {
          await tester.sendEventToBinding(mouse.scroll(Offset(0, dy)));
          await frames(tester);
        }
      }

      Future<void> topic(String title) async {
        await wheel(b.howToColumns[0].center, -2000, 1);
        for (var i = 0; i < 40 && !b.howToTopics.any((t) => t.$1 == title && t.$2.height > 8); i++) {
          await wheel(b.howToColumns[0].center, 20, 1);
        }
        await tap(b.howToTopics.firstWhere((t) => t.$1 == title).$2);
      }

      b.showSettings();
      await shot('settings-$tag', 40);
      await tap(b.howToButton);
      for (final (title, name) in const [('Items & Awaken', 'items'), ('Boss Chest & Artifacts', 'pusaka')]) {
        await topic(title);
        await shot('$name-$tag', 10);
        await wheel(b.howToColumns[1].center, 60, 80);
        await shot('$name-end-$tag', 10);
      }
      await tap(b.howToReplay);
      await shot('replay-$tag');
    });
  }
}
