// The ingredient wishes on the book (decisions-log 323; ui-hud.md "The Smithy"): offscreen shots into <probe
// root>/shots/wish-chain/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue `["test",
// "test/probe_wish_chain_shots.dart"]` with a mirror as `dir` (`--plain-name <size>` for one size). It never touches the
// real save (the queue's temp HOME); the dice are seeded.
//
// At 1600x947 and 915x412 (<size>), a board game after wave 20 in a Town: the knight wishes for a Royal Ring, the archer
// for a Royal Helm, a free line for Cleave, the Bag holds a Gem Ring's materials: chain-tab-<size> (the Wishlist tab:
// the types' rows, then "Ingredients": Gem Ring for Royal Ring, Ring for Gem Ring, Steel Helm, Leather Cap, Sword for
// Cleave, none with a Give), chain-tab-p2-<size> (its next spread, where there is one), chain-page-<size> (the Royal
// Ring's Smithy page: its Gem Ring row with the green "›"), chain-hover-<size> (the mouse over that row: lit),
// chain-linked-<size> (the row tapped: the Gem Ring's page, Back on its Recipe line, "Needed for Royal Ring" in its Give
// row's place), chain-crafted-<size> (the Gem Ring crafted from its Wishlist row: its row gone, no Give anywhere).
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'page_scroll.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/wish-chain');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Game board() {
  final g = Game(Random(7), Random(107)).boardRules()
    ..townDice = Random(3)
    ..armyMax = null
    ..wave = 20
    ..gold = 9000
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
  g.materials.addAll({Mat.tealGem: 1, Mat.wolfFang: 2, Mat.batFang: 1, Mat.bearClaw: 1, Mat.rustyPlate: 1, Mat.wolfClaw: 4});
  g.inventory[Item.ring] = 1;
  g
    ..wish('knight', Item.royalRing)
    ..wish('archer', Item.royalHelm)
    ..wishFreeAdd(Relic.cleave);
  return g;
}

void main() {
  for (final size in const [Size(1600, 947), Size(915, 412)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('wish chain shots $tag', (tester) async {
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
        final shown = (b.smithyText('wishPage') ?? '').split('|').where((k) => k.isNotEmpty);
        // ignore: avoid_print
        print('SHOT $name-$tag tab ${b.smithyTab.name} item ${b.smithyItem?.name} trail ${b.smithyTrail} '
            'pages ${b.smithyWishPage + 1}/${b.smithyWishPages} per "${b.smithyText('wishPer')}" lines "${b.smithyText('wishLines')}" '
            'rows ${[for (final k in shown) '$k "${b.smithyText('wishTitle:$k')}" [${b.smithyText('wishParts:$k')}] "${b.smithyText('wishStatus:$k')}" '
                'craft ${b.smithyAt('wishCraft:$k') != Rect.zero} give "${b.smithyText('wishGive:$k')}"']} '
            'recipe ${[for (final r in b.smithyRows) '${r.kind?.name ?? 'gold'} ${r.count} ${r.at}']} back ${b.smithyAt('back')} '
            'kept "${b.smithyText('kept')}" ${b.smithyAt('kept')} give ${b.smithyAt('give')} msg "${b.message}"');
      }

      Future<void> tap(Rect r) async {
        expect(r, isNot(Rect.zero));
        await tester.tapAt(r.center);
        await frames(tester, 3);
      }

      Future<void> shut() async {
        if (b.messageBox != Rect.zero) await tap(b.messageBox);
      }

      final g = b.state = board();
      await frames(tester, 40);
      await shut();
      expect((b.bookPage, b.smithyTab), ('smithy', SmithyTab.wishlist));
      await shot('chain-tab');
      if (b.smithyWishPages > 1) {
        await tap(b.smithyWishPager('on'));
        await shot('chain-tab-p2');
        await tap(b.smithyWishPager('back'));
      }

      // The Royal Ring's page (its board cell), then its Gem Ring row.
      await tap(b.smithyAt('tab:items'));
      while (!b.smithyItemCells.any((c) => c.$1 == Item.royalRing)) {
        await tap(b.smithyItemPager('on'));
      }
      await tap(b.smithyItemCells.firstWhere((c) => c.$1 == Item.royalRing).$2);
      final row = await scrolledTo(tester, b, 'smithy', () => b.smithyRows.where((r) => r.kind == Item.gemRing).firstOrNull?.at ?? Rect.zero);
      await shot('chain-page');
      // The mouse over the row: lit.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: row.center);
      await mouse.moveTo(row.center);
      await shot('chain-hover', 4);
      await mouse.removePointer();
      await tap(row);
      expect((b.smithyItem, b.smithyTrail), (Item.gemRing, 1));
      b.setPageScroll('smithy', 0);
      await shot('chain-linked');
      await scrolledTo(tester, b, 'smithy', () => b.smithyAt('kept'));
      await shot('chain-linked-kept');

      // Back to the Wishlist tab; the Gem Ring crafted from its row.
      await tap(b.smithyAt('tab:wishlist'));
      while (b.smithyAt('wishCraft:parts:gemRing') == Rect.zero && b.smithyWishPage < b.smithyWishPages - 1) {
        await tap(b.smithyWishPager('on'));
      }
      await tap(b.smithyAt('wishCraft:parts:gemRing'));
      expect(g.inventory[Item.gemRing], 1);
      await shot('chain-crafted', 4);
      await shut();
      b.state = Game();
      await frames(tester, 5);
    });
  }
}
