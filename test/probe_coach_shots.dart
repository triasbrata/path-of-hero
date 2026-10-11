// The first-time guide seen (docs/ui-hud.md "Guide", lib/coach.dart): offscreen shots of the welcome screen's split row,
// the intro's seven cards and the pointers P1 and P5, into <probe root>/shots/guide/ (`OUT`). A probe, not part
// of the suite (no `_test.dart`): queue `["test", "test/probe_coach_shots.dart"]` with a mirror as `dir`. It never
// touches the real save (flutter_test_config.dart's temp dir).
//
// At 412x860, 915x412 and 1266x713: welcome-<size> (a save to go back to: the tallest panel), I1-<size> .. I7-<size>
// (Main Baru on a device that hasn't seen the intro, then Lanjut), P1-<size> (the intro closed: the first row to buy),
// P5-<size> (an item in the bag, picked on the Tas page: the first row that takes it).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/save.dart' show Welcome;

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/guide');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  for (final size in const [Size(412, 860), Size(915, 412), Size(1266, 713)]) {
    final tag = '${size.width.round()}';
    testWidgets('guide shots $tag', (tester) async {
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
        ..miniMapOpen = false
        ..guideSeen = {};

      Future<void> shot(String name, [int settle = 30]) async {
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
        print('wrote $out/$name.png ${img.width}x${img.height} card ${b.coachCard} panel ${b.coachPanel} '
            'pointer ${b.coachPointer} ${b.coachPointerBox} at ${b.coachPointerTarget}');
      }

      Future<void> tap(Offset p) async {
        await tester.tapAt(p);
        await frames(tester, 2);
      }

      b.welcome = Welcome(Game()..wave = 12, discard: () {});
      await shot('welcome-$tag');
      // ignore: avoid_print
      print('welcome buttons ${b.welcomeButtons}');
      b.welcome = Welcome(null, discard: () {});
      await frames(tester, 2);
      await tap(b.welcomeButtons['Main Baru']!.center);
      for (var i = 1; i <= 7; i++) {
        await shot('I$i-$tag');
        await tap(b.coachButtons['next']!.center);
      }
      await shot('P1-$tag', 60);
      b.guideSeen!.addAll(['P1', 'P2']);
      b.state.inventory[Item.sword] = 1;
      await frames(tester, 4);
      await shot('P3-$tag', 10);
      await tap(b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
      await tap(b.bagSlot(Item.sword).center);
      await shot('P5-$tag', 30);
    });
  }
}
