// The Wishlist on the book (decisions-log 282; ui-hud.md "The Smithy", "Army"): offscreen shots into
// <probe root>/shots/wishlist/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_wishlist_shots.dart"]` with a mirror as `dir` (`--plain-name <size>` for one size). It never
// touches the real save (the queue's temp HOME); the dice are seeded.
//
// At 1266x713, 1164x777, 915x412, 412x860 and 1600x947 (<size>), a board game after wave 20 with the forge on: the
// knight wishes for a Steel Sword (its recipe held: ready) and a Royal Helm, the archer for a Long Bow (short):
// smithy-<size> (in the Town, the Steel Sword picked: its stars on the board and in the Materials, first in grade II,
// "Wishlist: Knight", the chips, "Ready to craft"), smithy-short-<size> (the Long Bow: "Missing: …"), army-<size> (out of
// the Town, the knight's detail scrolled to its Wishlist) and army-picker-<size> (the picker open).
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/wishlist');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Game board() {
  final g = Game(Random(7), Random(107)).boardRules()
    ..townDice = Random(3)
    ..towns = true
    ..armyMax = null
    ..wave = 20
    ..gold = 4450
    ..townAt = 21
    ..inTown = true;
  for (final type in ['soldier', 'knight', 'archer', 'priest', 'lancer', 'wizard']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.materials.addAll({
    for (final (i, m) in Mat.values.indexed)
      if (i < 22) m: 1 + i * 5 % 13,
  });
  g.materials.addAll({Mat.wolfClaw: 3, Mat.orcEar: 2, Mat.boneArrow: 1});
  g.materials.remove(Mat.leatherStrap);
  g
    ..wish('knight', Item.steelSword)
    ..wish('knight', Item.royalHelm)
    ..wish('archer', Item.longBow);
  return g;
}

void main() {
  for (final size in const [Size(1266, 713), Size(1164, 777), Size(915, 412), Size(412, 860), Size(1600, 947)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('wishlist shots $tag', (tester) async {
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

      Future<void> shot(String name, [int settle = 20]) async {
        await frames(tester, settle);
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = (await tester.runAsync(() => boundary.toImage()))!;
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name-$tag.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        // ignore: avoid_print
        print('wrote $out/$name-$tag.png page ${b.bookPage} item ${b.smithyItem} wishlist "${b.smithyText('wishlist')}" '
            'chips ${b.smithyText('wishTypes')} on ${b.smithyText('wishOn')} missing "${b.smithyText('wishMissing')}" '
            'give "${b.bagDetailText('hint:giveTroops')}" detail ${b.troopDetailWords('wishlist')} ready ${b.troopDetailWords('wishReady')} '
            'pages ${b.bookPages}');
      }

      Future<void> tap(Rect r) async {
        expect(r, isNot(Rect.zero));
        await tester.tapAt(r.center);
        await frames(tester, 3);
      }

      Future<void> shut() async {
        if (b.messageBox != Rect.zero) await tap(b.messageBox);
      }

      Future<void> pick(Item item) async {
        await shut();
        while (!b.smithyItemCells.any((c) => c.$1 == item) && b.smithyItemPage < b.smithyItemPages - 1) {
          await tap(b.smithyItemPager('on'));
        }
        await tap(b.smithyItemCells.firstWhere((c) => c.$1 == item).$2);
      }

      Future<void> scrollTo(String key) async {
        b.troopDetailScroll = 0;
        await frames(tester, 2);
        for (var i = 0; i < 80 && (b.troopDetail(key) == Rect.zero || b.troopDetail(key).bottom > b.troopDetailBody.bottom - 1); i++) {
          final was = b.troopDetailScroll;
          b.troopDetailScroll = was + 16;
          await frames(tester, 2);
          if (b.troopDetailScroll == was) break;
        }
      }

      final g = b.state = board();
      await frames(tester, 40);
      await shut();
      expect(b.bookPage, 'smithy');
      await pick(Item.steelSword);
      await shot('smithy');
      await pick(Item.longBow);
      await shot('smithy-short');

      g.leaveTown();
      await frames(tester, 40);
      await shut();
      await tap(b.troopRow('knight'));
      await scrollTo('wishlist');
      await shot('army');
      await tap(b.troopDetail('wishEdit'));
      await scrollTo('pick:royalRing');
      await shot('army-picker');
      b.state = Game();
      await frames(tester, 5);
    });
  }
}
