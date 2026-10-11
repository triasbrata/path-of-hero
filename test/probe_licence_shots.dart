// The Lisensi page seen on the shorter landscape book (decisions-log 283; docs/ui-hud.md "The book", lib/licence_page.dart):
// offscreen shots into <probe root>/shots/spawn-bar/licence (`OUT`). A probe, not part of the suite (no `_test.dart`):
// queue `["test", "test/probe_licence_shots.dart"]` with a mirror as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir).
//
// At 1600x947, 1266x713, 915x412 and 412x860: list-<size> (the licence and credits on the left, the packages on the
// right), font-<size> (Poh Sans's licence at its top) and font-ofl-<size> (the wheel down to the OFL). Each line printed
// gives the two columns, for a crop.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/spawn-bar/licence');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('licence shots', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 947)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await loadHudFont(tester);
    final game = TdGame(), key = GlobalKey(); // one TdGame a file (docs/testing.md): the sizes in turn
    await tester.pumpWidget(RepaintBoundary(key: key, child: GameWidget(game: game)));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue);
    final b = game.board..welcome = null;
    for (final size in const [Size(1600, 947), Size(1266, 713), Size(915, 412), Size(412, 860)]) {
      final tag = '${size.width.round()}x${size.height.round()}';
      tester.view.physicalSize = size;
      b.state = Game();
      await frames(tester, 10);
      Future<void> tap(Rect r) async {
        expect(r, isNot(Rect.zero));
        await tester.tapAt(r.center);
        await frames(tester, 5);
      }

      Future<void> shot(String name) async {
        await frames(tester, 10);
        final img = (await tester.runAsync(() => (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage()))!;
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name-$tag.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        // ignore: avoid_print
        print('LIC $name-$tag columns ${b.licenceColumns} right ${b.licenceRight.length} paragraphs');
      }

      b.showSettings();
      await frames(tester, 40);
      await tap(b.licenceButton);
      for (var i = 0; i < 100 && b.licenceRows.isEmpty; i++) {
        await frames(tester, 1);
      }
      await shot('list');
      await tap({for (final (name, r) in b.licenceRows) name: r}['Poh Sans']!);
      await shot('font');
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(b.licenceColumns[1].center));
      for (var i = 0; i < 20 && !b.licenceRight.any((t) => t.contains('SIL OPEN FONT LICENSE Version 1.1')); i++) {
        await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
        await frames(tester);
      }
      await shot('font-ofl');
      await tap(b.licenceAll);
      await tap(b.licenceBack);
      await frames(tester, 20);
    }
  });
}
