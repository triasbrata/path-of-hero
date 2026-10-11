// The Shop in every Town seen (decisions-log 253; ui-hud.md "Town"): offscreen shots into <probe root>/shots/town-polish/
// (`OUT`). A probe, not part of the suite (no `_test.dart`): queue `["test", "test/probe_town_shop_tabs_shots.dart"]` with
// the worktree or a mirror as `dir` (`--dart-define=SIZES=1266x713` for some sizes only). It never touches the real save
// (flutter_test_config.dart's temp dir); every dice is seeded.
//
// At 1266x713 and 412x860 (<size>), a board game with the Towns on and the shipped town.json:
// - shoptabs-field-<size>: the field between waves at wave 3, the book on the Army page (its tabs: no Shop);
// - shoptabs-fieldbag-<size>: the same book on the Bag;
// - shoptabs-town-<size>: the first Town (after wave 3), the book on the Smithy (its tabs: the Shop's);
// - shoptabs-townshop-<size>: that Town's Shop page, open.
// It prints each book's tabs and page.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/town-polish');
const only = String.fromEnvironment('SIZES');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  final shipped = TownRules.parse(File('assets/config/town.json').readAsStringSync());
  final sizes = [
    for (final s in const [Size(1266, 713), Size(412, 860)])
      if (only.isEmpty || only.split(',').contains('${s.width.round()}x${s.height.round()}')) s,
  ];
  for (final size in sizes) {
    final name = '${size.width.round()}x${size.height.round()}';
    testWidgets('shop tabs shots $name', (tester) async {
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

      Future<void> shot(String file) async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = (await tester.runAsync(() => boundary.toImage()))!;
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/shoptabs-$file-$name.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        // ignore: avoid_print
        print('wrote $out/shoptabs-$file-$name.png: page ${b.bookPage}, tabs ${[for (final (t, _) in b.bookTabs) t]}');
      }

      Future<void> tab(String name) async {
        await tester.tapAt(b.bookTabs.firstWhere((x) => x.$1 == name).$2.center);
        await frames(tester, 40);
      }

      // A board game between waves, wave 3 won, its first Town marked before wave 5.
      Game board() => Game(Random(1), Random(2)).boardRules()
        ..armyMax = null
        ..towns = true
        ..townRules = shipped
        ..townDice = Random(3)
        ..gold = 5000
        ..wave = 3
        ..townAt = 5;

      // The field: the book on the Army page, then the Bag.
      var g = b.state = board();
      await frames(tester, 60);
      // ignore: avoid_print
      print('$name: towns ${g.towns} storeOpen ${g.storeOpen} armyBuysOpen ${g.armyBuysOpen}');
      await shot('field');
      await tab('bag');
      await shot('fieldbag');

      // Wave 4 won, in a game afresh (on a phone the wave started under the open Bag never ended here): the first
      // Town, its book on the Smithy, then the Shop.
      await tab('troops');
      g = b.state = board();
      await frames(tester, 10);
      g
        ..startWave()
        ..queue.clear()
        ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
      for (var i = 0; i < 600 && !g.inTown; i++) {
        await frames(tester, 1);
      }
      expect(g.inTown, isTrue);
      for (var i = 0; i < 120 && b.townFade > 0; i++) {
        await frames(tester, 1);
      }
      await frames(tester, 60);
      await shot('town');
      await tab('store');
      await shot('townshop');
      expect(b.bookPage, 'store');
    });
  }
}
