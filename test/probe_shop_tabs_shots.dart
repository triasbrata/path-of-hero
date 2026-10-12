// The Town's Shop's Buy | Sell (decisions-log 269; ui-hud.md "The Town's Shop"): offscreen shots into
// <probe root>/shots/shop-tabs/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_shop_tabs_shots.dart"]` with the worktree or a mirror as `dir` (`--dart-define=SIZES=1266x713`
// for some sizes only). It never touches the real save (flutter_test_config.dart's temp dir); every dice is seeded.
//
// At 1266x713, 1164x777, 915x412, 412x860 and 1600x947 (the owner's window) (<size>), a board game in a Town with the forge on (the shipped Shop):
// - shoptabs-buy-<size>: the Shop on Buy, nothing picked (Materials alone: Items and Relics, none on the forge's shelf, not
//   drawn, decisions-log 280);
// - shoptabs-buypick-<size>: a material picked on Buy (its Buy row);
// - shoptabs-sellempty-<size>: Sell, the basket empty (decisions-log 278: the top's hint, Sell greyed);
// - shoptabs-sellone-<size>: Sell with one stack, an enhanced Sword picked (its detail, its price row);
// - shoptabs-sell-<size>: Sell with a basket of an item stack, an enhanced stack, a relic, a carved Artifact and a
//   material, the material picked;
// - shoptabs-sellmany-<size>: the same basket with four more stacks, the Orc Tooth picked, its line scrolled into view;
// - shoptabs-selllong-<size>: everything on the grid in the basket, the first stack picked again (scrolled back up);
// - shoptabs-buyempty-<size>: the forge's shelf empty (no material dropped, the Artifact shelf closed): no section, only
//   "Nothing to buy here yet." (decisions-log 280);
// - shoptabs-buyshelf-<size>: the Artifact shelf open: Buy's Artifacts, then Materials;
// - at 1266x713 and 412x860 shoptabs-smithy-<size>: the Smithy's Items tab, its "Materials" heading over its grid.
// It prints where each section heading's words start and the board's leftmost slot, and the Smithy's.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/shop-tabs');
const only = String.fromEnvironment('SIZES');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game in a Town after wave 30 (the Towns, and with them the forge, on): a mixed army, Swords (+0, at +2, at +3),
/// Shields, small relics, materials (some seen), a Vault Artifact, 400,000 gold.
Game shotGame() {
  final g = Game(Random(1), Random(2)).boardRules()
    ..townDice = Random(3)
    ..armyMax = null
    ..gold = 400000
    ..wave = 30
    ..townAt = 31
    ..inTown = true;
  for (final type in ['knight', 'archer', 'priest', 'soldier']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.inventory.addAll({Item.sword: 3, Item.shield: 12, Item.bow: 2});
  g.enhancedBag.addAll({(Item.sword, 2): 2, (Item.sword, 3): 1});
  g.relicBag.addAll({droppedRelics.first: 2, droppedRelics.last: 1});
  g.materials.addAll({Mat.wolfClaw: 4, Mat.slimeGel: 9, Mat.boneShard: 6, Mat.orcTooth: 3});
  g.matsSeen.addAll([Mat.wolfClaw, Mat.slimeGel, Mat.boneShard, Mat.orcTooth, Mat.evilEye]);
  g.pusaka[Relic.titanBane] = OwnedPusaka(stars: 2, ukir: 2);
  return g;
}

void main() {
  final sizes = [
    for (final s in const [Size(1266, 713), Size(1164, 777), Size(915, 412), Size(412, 860), Size(1600, 947)])
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
        await frames(tester, 20);
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = (await tester.runAsync(() => boundary.toImage()))!;
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/shoptabs-$file-$name.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        // ignore: avoid_print
        print('wrote $out/shoptabs-$file-$name.png: page ${b.bookPage}, tab ${b.shopTab}, basket ${b.shopBasket}');
      }

      Future<void> tap(Rect r) async {
        expect(r, isNot(Rect.zero));
        await tester.tapAt(r.center);
        await frames(tester, 3);
      }

      Future<void> tab(String page) async {
        if (b.messageBox != Rect.zero) await tap(b.messageBox);
        await tap(b.bookTabs.firstWhere((x) => x.$1 == page).$2);
      }

      Future<void> cell(Enum kind, [int plus = 0]) async {
        final loot = (kind: kind, plus: plus);
        bool shown() => b.bagLootCells.any((c) => c.$1 == loot);
        while (!shown() && b.bagPage > 0) {
          await tap(b.bagPager('back'));
        }
        while (!shown() && b.bagPage < b.bagPages - 1) {
          await tap(b.bagPager('on'));
        }
        await tap(b.bagLootCells.firstWhere((c) => c.$1 == loot).$2);
      }

      void edges(String what) {
        final left = b.bagSlots.isEmpty ? null : b.bagSlots.map((r) => r.left).reduce(min);
        // ignore: avoid_print
        print('$name $what: leftmost slot $left; headings ${[for (final (s, r) in b.shopSections) '${s.name} ${r.left}']}; '
            'smithy matsTitle ${b.smithyAt('matsTitle').left} kinds ${b.smithyAt('kinds')}; pages ${b.bagPage + 1}/${b.bagPages}');
      }

      b.state = shotGame();
      await frames(tester, 40);
      await tab('store');
      edges('buy');
      await shot('buy');
      await cell(Mat.wolfClaw);
      await shot('buypick');

      void parts(String what) {
        // ignore: avoid_print
        print('$name $what: ${[for (final k in ['detail', 'empty', 'price', 'unit', 'minus', 'count', 'plus', 'all', 'subtotal', 'lines', 'sell', 'sellCoin']) '$k ${b.shopAt(k)}']} '
            'texts ${[for (final k in ['empty', 'kind', 'lost', 'desc', 'price', 'sell']) '$k ${b.shopText(k)}']} name ${b.bagDetailText('name')} '
            'lines ${[for (final l in b.shopBasketLines) '${l.$3} ${l.$2}']}');
      }

      await tap(b.shopTabAt(ShopTab.sell));
      parts('sellempty');
      await shot('sellempty');
      await cell(Item.sword, 2);
      parts('sellone');
      await shot('sellone');
      await cell(Item.sword);
      await tap(b.shopAt('plus'));
      await cell(Item.sword, 2);
      await tap(b.shopAt('all'));
      await cell(droppedRelics.first);
      await cell(Relic.titanBane);
      await cell(Mat.wolfClaw);
      await tap(b.shopAt('plus'));
      await tap(b.shopAt('plus'));
      parts('sell');
      await shot('sell');
      for (final (kind, plus) in [(Item.shield, 0), (Item.bow, 0), (Mat.slimeGel, 0), (Mat.boneShard, 0)]) {
        await cell(kind, plus);
      }
      await tap(b.shopBasketLines.first.$2);
      await cell(Mat.orcTooth);
      parts('sellmany');
      await shot('sellmany');
      for (final l in shopSellLoot(b.state)) {
        await cell(l.kind, l.plus);
      }
      await cell(Item.sword);
      parts('selllong');
      await shot('selllong');

      if (size == const Size(1266, 713) || size == const Size(412, 860)) {
        await tab('smithy');
        edges('smithy');
        await shot('smithy');
      }

      Future<void> buy(Game g) async {
        b.state = g;
        await frames(tester, 40);
        if (b.bookPage != 'store') await tab('store');
        if (b.shopTab != ShopTab.buy) await tap(b.shopTabAt(ShopTab.buy));
      }

      await buy(shotGame()..matsSeen.clear());
      edges('buyempty');
      // ignore: avoid_print
      print('$name buyempty: nothing ${b.shopAt('nothing')} "${b.shopText('nothing')}" strip ${b.shopTabAt(ShopTab.buy)}');
      await shot('buyempty');
      await buy(shotGame()..offers = false);
      edges('buyshelf');
      await shot('buyshelf');
      await frames(tester, 10);
    });
  }
}
