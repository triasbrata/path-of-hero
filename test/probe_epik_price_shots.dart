// The Epik Artifact's own price seen (decisions-log 213): the Bag's detail of Hawk Feather in the Vault, its Sell tag
// "Sell +12.5k", at 1266x713 into <probe root>/shots/epik-price/ (`OUT`). A probe, not part of the suite: queue
// `["test", "test/probe_epik_price_shots.dart"]` with the worktree as `dir`. Never touches the real save.
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui' show PointerDeviceKind;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/epik-price');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('epik price shot', (tester) async {
    tester.view
      ..physicalSize = const Size(1266, 713)
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
    final g = b.state = Game()..boardRules()..wave = storeFrom..gold = 1000;
    g..givePusaka(Relic.hawkFeather)..givePusaka(Relic.ironBanner);
    await frames(tester, 50);
    await tester.tapAt(b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
    await frames(tester);
    for (final (r, tag) in [(Relic.hawkFeather, 'epik'), (Relic.ironBanner, 'langka')]) {
      await tester.tapAt(b.bagSlot(r).center);
      await frames(tester);
      final mouse = TestPointer(9, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(b.assignList.center));
      for (var i = 0; i < 10; i++) {
        await tester.sendEventToBinding(mouse.scroll(const Offset(0, 60)));
        await frames(tester);
      }
      await tester.sendEventToBinding(mouse.hover(b.bookArea.topLeft));
      await frames(tester, 20);
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = (await tester.runAsync(() => boundary.toImage()))!;
      await tester.runAsync(() async {
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/bag-$tag-sell.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
      // ignore: avoid_print
      print('wrote bag-$tag-sell ${img.width}x${img.height}: ${b.bagDetailText('vaultSell')}, gold ${g.gold}');
    }
  });
}
