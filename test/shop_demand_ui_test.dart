// The Shop's Sell tab with High demand (decisions-log 335; ui-hud.md "The Town's Shop", "The Sell Basket"), booted TdGames
// in Millbrook at 1600x947, 1266x713, 1164x777 and 915x412: the left page's two headed sections (High demand over Items in
// Bag), each demand cell its price here; a product the Bag doesn't hold picked (its demand, Add to wishlist, "None in
// your Bag.", no basket line), put on the Wishlist ("On wishlist", its star); a held one picked (into the basket, its
// price row); the board paged at 915x412 and opening on its first page; a flooded product gone; the empty Bag's line.
// The rules: shop_demand_test.dart. One TdGame per widget test.
//
// Never let a wave be won or the game end here (the Board then saves).
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';

Future<Board> boot(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadHudFont(tester);
  final game = TdGame();
  await tester.pumpWidget(GameWidget(game: game));
  for (var i = 0; i < 3000 && !game.isLoaded; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(game.isLoaded, isTrue);
  return game.board
    ..welcome = null
    ..miniMapOpen = false
    ..autoStart.set(false);
}

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Taps [r]'s middle (never Rect.zero).
Future<void> tapOn(WidgetTester tester, Rect r, [String why = '']) async {
  expect(r, isNot(Rect.zero), reason: why);
  await tester.tapAt(r.center);
  await frames(tester, 3);
}

Future<void> shutMessage(WidgetTester tester, Board b) async {
  if (b.messageBox != Rect.zero) await tapOn(tester, b.messageBox);
}

/// The book open on its [page] tab.
Future<void> turnTo(WidgetTester tester, Board b, String page) async {
  await shutMessage(tester, b);
  await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == page).$2, page);
}

/// [r] wholly inside [area].
bool inside(Rect r, Rect area) => r.left >= area.left - 0.5 && r.top >= area.top - 0.5 && r.right <= area.right + 0.5 && r.bottom <= area.bottom + 0.5;

const sizes = [Size(1600, 947), Size(1266, 713), Size(1164, 777), Size(915, 412)];

/// A board game in Millbrook (the first Town: Boots, Potion, Gloves and Prayer Beads wanted) after wave 20: a mixed army,
/// Swift Boots and Swords in the Bag, some materials, 40,000 gold.
Game demandGame() {
  final g = Game(Random(1), Random(2)).boardRules()
    ..townDice = Random(3)
    ..armyMax = null
    ..gold = 40000
    ..wave = 20
    ..townAt = 21
    ..inTown = true;
  for (final type in ['knight', 'archer', 'priest', 'soldier']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.inventory.addAll({Item.swiftBoots: 2, Item.sword: 3});
  g.materials.addAll({Mat.wolfClaw: 4, Mat.slimeGel: 9});
  return g;
}

void main() {
  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('$tag: High demand over Items in Bag; a product picked shows its demand and Add to wishlist; a held one '
        'goes in the basket', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = demandGame();
      await frames(tester, 40);
      await turnTo(tester, b, 'store');
      await tapOn(tester, b.shopTabAt(ShopTab.sell), 'Sell');
      expect(g.townIdentity.key, 'millbrook');
      final book = b.bookArea, left = Rect.fromLTRB(book.left, book.top, book.center.dx, book.bottom);
      final demand = shopDemandLoot(g);

      // The first page: High demand's heading over its cells, from the board's leftmost slot, its cells in its order,
      // each its price here in the capsule (no basket count, no arrow: its heading says it).
      final head = b.shopAt('head:${Words.highDemand}'), cells = b.shopDemandCells;
      expect((b.bagPage, head != Rect.zero, cells.isNotEmpty), (0, true, true), reason: tag);
      expect(head.left, cells.first.$2.left, reason: '$tag: the heading over the leftmost slot');
      expect(head.bottom <= cells.first.$2.top + 0.5, isTrue, reason: '$tag: the heading over the cells');
      expect([for (final (l, _) in cells) l], demand.take(cells.length), reason: '$tag: by price, most first');
      for (final (l, r) in cells) {
        expect(inside(r, left), isTrue, reason: '$tag ${l.kind}: on the left page');
        if (l.kind == Item.swiftBoots) continue; // held: its Items in Bag cell keeps the marks' key
        expect((b.bagMarks(l.kind)!.price, b.bagMarks(l.kind)!.basket), (g.sellPrice(l.kind), null), reason: '$tag ${l.kind}');
      }
      expect(b.shopArrows.keys.where((l) => cells.any((c) => c.$1 == l && b.shopArrows[l]!.$2.overlaps(c.$2))), isEmpty,
          reason: '$tag: no arrow on a High demand cell');

      // Items in Bag under it, on this page or the next ones: its heading under High demand's, its cells the Sell grid's.
      var bagHead = b.shopAt('head:${Words.itemsInBag}');
      while (bagHead == Rect.zero && b.bagPage < b.bagPages - 1) {
        await tapOn(tester, b.bagPager('on'), '$tag: on to Items in Bag');
        bagHead = b.shopAt('head:${Words.itemsInBag}');
      }
      expect(bagHead, isNot(Rect.zero), reason: tag);
      if (b.bagPage == 0) expect(bagHead.top > cells.last.$2.bottom, isTrue, reason: '$tag: under High demand');
      final bagCells = [for (final (l, r) in b.bagLootCells) if (r.top > bagHead.top) l];
      expect(bagCells, shopSellLoot(g).skipWhile((l) => l != bagCells.first).take(bagCells.length), reason: '$tag: the Bag in its order');
      expect(tag == '915x412' ? b.bagPages > 1 : true, isTrue, reason: '$tag: a phone page turns pages');

      // Back to the first page; a product the Bag doesn't hold: picked, not in the basket; the detail says its demand
      // and price, Add to wishlist; "None in your Bag." in the price row's place.
      while (b.bagPage > 0) {
        await tapOn(tester, b.bagPager('back'));
      }
      final none = b.shopDemandCells.firstWhere((c) => g.inventory[c.$1.kind] == null);
      final item = none.$1.kind as Item, price = shortPrice(g.sellPrice(item));
      await tapOn(tester, none.$2, '$tag $item');
      expect((b.shopPickAt, b.shopBasket.length, b.bagPage), (none.$1, 0, 0), reason: '$tag: picked, not in the basket, the page kept');
      expect(b.shopText('kind'), 'Grade ${Words.gradeNumerals[item.grade - 1]} item · ${Words.hotIn} Millbrook', reason: tag);
      expect(b.shopText('demand'), '${Words.demand}: 16 more, $price ${Words.each}', reason: tag);
      expect([Words.addToWishlist, Words.add], contains(b.shopText('wish')), reason: tag);
      expect((b.shopText('none'), b.shopAt('price')), ('${Words.noneInBag}.', Rect.zero), reason: tag);
      expect((b.bagDetailText('count'), b.bagDetail('count')), ('', Rect.zero), reason: '$tag: no "x0" (the owner: "Sembunyikan x0")');
      final detail = b.shopAt('detail');
      for (final key in ['demand', 'wish']) {
        expect(inside(b.shopAt(key), detail.inflate(1)), isTrue, reason: '$tag $key in the detail');
      }

      // Add to wishlist: a free line for one; the tag reads "On wishlist", the cell carries the star.
      await tapOn(tester, b.shopAt('wish'), '$tag wish');
      expect((g.wished(item), g.freeCount(item), b.message), (true, (0, 1), '${itemNames[item]} ×1: on the wishlist'), reason: tag);
      await shutMessage(tester, b);
      expect((b.shopText('wish'), b.bagMarks(item)!.wished), (Words.onWishlist, true), reason: tag);
      await tapOn(tester, b.shopAt('wish'), '$tag on wishlist');
      expect((g.freeCount(item), b.message), ((0, 1), '${itemNames[item]}: on the wishlist. Craft it at the ${Words.smithy}.'), reason: tag);
      await shutMessage(tester, b);

      // A held one (Swift Boots, two in the Bag): into the basket at 1, the price row under its demand line.
      final held = b.shopDemandCells.firstWhere((c) => c.$1.kind == Item.swiftBoots);
      await tapOn(tester, held.$2, '$tag Swift Boots');
      final each = g.sellPrice(Item.swiftBoots);
      const BagLoot swift = (kind: Item.swiftBoots, plus: 0);
      expect([b.shopPickAt, b.shopBasket], [swift, {swift: 1}], reason: tag);
      expect((b.shopText('demand'), b.shopText('price'), b.shopText('none')),
          ('${Words.demand}: 16 more, $each ${Words.each}', '$each x 1 = $each', null), reason: tag);
      expect(b.bagDetailText('count'), 'x2', reason: '$tag: held, its count');
      expect(b.shopAt('price').top >= b.shopAt('demand').bottom, isTrue, reason: '$tag: the price row under the detail');

      // Out of the Shop and back: Buy, then Sell on its first page.
      await turnTo(tester, b, 'smithy');
      await turnTo(tester, b, 'store');
      await tapOn(tester, b.shopTabAt(ShopTab.sell));
      expect((b.bagPage, b.shopBasket.length), (0, 0), reason: tag);
    });
  }

  testWidgets('a product sold until flooded leaves High demand; an empty Bag says so under Items in Bag', (tester) async {
    final b = await boot(tester, const Size(1266, 713));
    final g = b.state = demandGame();
    await frames(tester, 40);
    await turnTo(tester, b, 'store');
    await tapOn(tester, b.shopTabAt(ShopTab.sell));
    expect(b.shopDemandCells.any((c) => c.$1.kind == Item.boots), isTrue);
    g.market[g.marketKey(Item.boots)] = 16;
    await frames(tester, 3);
    expect(b.shopDemandCells.any((c) => c.$1.kind == Item.boots), isFalse);
    expect(b.shopDemandCells.length, 11);

    g
      ..inventory.clear()
      ..materials.clear();
    await frames(tester, 3);
    expect(b.shopText('note:${Words.itemsInBag}'), '$shopNothingToSell ${Words.monstersDropMats}.');
    expect(b.bagLootCells.length, b.shopDemandCells.length, reason: 'only High demand has cells');
  });
}
