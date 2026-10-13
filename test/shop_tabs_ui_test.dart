// The Town's Shop split into Buy and Sell (decisions-log 269; ui-hud.md "The Town's Shop"), booted TdGames in a Town with
// the forge on (the shipped game's Shop) at 1266x713, 1164x777 and 915x412: the strip Buy | Sell opening on
// Buy; Buy's one section Materials (the shelf, each cell its price; Items and Relics, none on the forge's shelf, not drawn:
// decisions-log 280), every heading's words starting at its board's leftmost cell; a material bought; Sell's one grid of everything in
// the Bag nothing uses (each enhanced stack its own cell; a bound Artifact, an oath, a worn relic absent); the Sell Basket
// page as reworked in decisions-log 278, top to bottom the pick's detail, its price row "1500 x [-] 2 [+] [All] = 3000"
// under the detail's words, the basket's lines (no divider over them, decisions-log 305: as far under the price row as
// over the bar) and the bottom bar, Sell across it with the coin and the total on it (decisions-log 306; no total left of
// it; greyed "Sell" alone with the basket empty): a tap adds a cell
// at 1 and picks it (the top shows it), the stepper sets the count (from 1 to what is held; at 0 the line leaves and the
// top shows the last line), the price row's math per stack (an enhanced stack, a relic, a material, an Artifact), a long
// basket scrolling under a fixed top and bar; a basket of an item stack, an enhanced stack, a relic, an Artifact and a
// material sold in one press, its gold the sum of each piece's price; the empty page; the facing page per tab; the
// basket's life (a tab switch keeps it, leaving the Shop or another game empties it, a stack that shrinks clamps it); the
// Smithy's "Materials" heading over its leftmost cell; the Town's Bag keeps its chips. The basket's math without a page.
// The rules: store_test.dart, forge_shop_test.dart.
//
// Never let a wave be won or the game end here (the Board then saves).
import 'dart:math';
import 'dart:ui' show PointerDeviceKind;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';

Future<Board> boot(WidgetTester tester, [Size size = const Size(1266, 713)]) async {
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

/// Shuts the message window (it can lie over the tabs or the cells).
Future<void> shutMessage(WidgetTester tester, Board b) async {
  if (b.messageBox != Rect.zero) await tapOn(tester, b.messageBox);
}

/// Turns the open book to [page] by its tab.
Future<void> turnTo(WidgetTester tester, Board b, String page) async {
  await shutMessage(tester, b);
  await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == page).$2, page);
}

/// Taps [kind]'s cell at +[plus] on the shown grid, turning its pages to it.
Future<void> cell(WidgetTester tester, Board b, Enum kind, [int plus = 0]) async {
  final loot = (kind: kind, plus: plus);
  bool shown() => b.bagLootCells.any((c) => c.$1 == loot);
  while (!shown() && b.bagPage > 0) {
    await tapOn(tester, b.bagPager('back'));
  }
  while (!shown() && b.bagPage < b.bagPages - 1) {
    await tapOn(tester, b.bagPager('on'));
  }
  await tapOn(tester, b.bagLootCells.firstWhere((c) => c.$1 == loot).$2, '$kind +$plus');
}

/// The Sell basket's list wheeled from its top a step at a time (it scrolls where its lines don't all fit: 4 of 6 at
/// 1266x713 on the shorter landscape book, decisions-log 283) until [stop] holds or the list is at its end; each line's
/// words as drawn on the way ([seen]). The mouse left off the list.
Future<void> wheelLines(WidgetTester tester, Board b, {bool Function()? stop, Map<BagLoot, String>? seen}) async {
  final mouse = TestPointer(9, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(mouse.hover(b.shopAt('lines').center));
  await tester.sendEventToBinding(mouse.scroll(const Offset(0, -2000)));
  await frames(tester);
  for (var i = 0; i < 40; i++) {
    for (final (l, _, t) in b.shopBasketLines) {
      seen?[l] = t;
    }
    if (stop?.call() ?? false) break;
    final was = b.shopBasketLines.first.$2;
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 24)));
    await frames(tester);
    if (b.shopBasketLines.first.$2 == was) break; // at its end
  }
  await tester.sendEventToBinding(mouse.hover(const Offset(2, 2)));
  await frames(tester);
}

/// [loot]'s line in the Sell basket, the list wheeled until it shows whole ([wheelLines]).
Future<Rect> lineOf(WidgetTester tester, Board b, BagLoot loot) async {
  bool whole() => b.shopBasketLines.any((l) => l.$1 == loot && l.$2.height >= b.shopBasketLines.map((x) => x.$2.height).reduce(max) - 0.5);
  await wheelLines(tester, b, stop: whole);
  return b.shopBasketLines.firstWhere((l) => l.$1 == loot).$2;
}

/// [r] wholly inside [area].
bool inside(Rect r, Rect area) => r.left >= area.left - 0.5 && r.top >= area.top - 0.5 && r.right <= area.right + 0.5 && r.bottom <= area.bottom + 0.5;

const sizes = [Size(1266, 713), Size(1164, 777), Size(915, 412)];

/// The Sell Basket page's parts (decisions-log 278), each on the right page and the screen, top to bottom: the detail's
/// band (its icon and name in it), with a pick its price row (under the name's words, the "`<space>`": its parts left to
/// right, the unit price, -, the count, +, All, the subtotal), the lines, then the bottom bar: Sell across the page's
/// writing, with a basket the coin on it (decisions-log 306). No divider over the lines (decisions-log 305): with a pick
/// they start as far under the price row as they end over Sell; no total beside Sell (306).
void expectSellPage(Board b, Size size, String tag, {bool picked = true}) {
  final book = b.bookArea, screen = Offset.zero & size;
  bool onRight(Rect r) => r != Rect.zero && inside(r, book) && inside(r, screen) && r.left >= book.center.dx - 0.5;
  final order = [for (final key in ['detail', if (picked) 'price', 'lines']) (key, b.shopAt(key))];
  final lines = b.shopAt('lines'), sell = b.shopAt('sell');
  for (final (key, r) in [...order, ('sell', sell)]) {
    expect(onRight(r), isTrue, reason: '$tag $key: $r on the right page');
  }
  for (var i = 1; i < order.length; i++) {
    expect(order[i].$2.top >= order[i - 1].$2.bottom - 0.5, isTrue, reason: '$tag: ${order[i].$1} under ${order[i - 1].$1}');
  }
  expect([b.shopAt('divider'), b.shopAt('total'), b.shopText('total')], [Rect.zero, Rect.zero, isNull],
      reason: '$tag: no divider (decisions-log 305), no total left of Sell (306)');
  expect([sell.top >= lines.bottom - 0.5, sell.left, sell.right], [true, lines.left, lines.right],
      reason: '$tag: Sell under the lines, across the page; $lines $sell');
  final coin = b.shopAt('sellCoin');
  if (coin != Rect.zero) {
    expect([inside(coin, sell), (coin.center.dy - sell.center.dy).abs() <= 4], [true, true], reason: '$tag: the coin on Sell, $coin $sell');
  }
  if (!picked) return;
  final price = b.shopAt('price');
  expect(lines.top - price.bottom, closeTo(sell.top - lines.bottom, 1),
      reason: '$tag: the lines as far under the price row as over Sell, no divider between; $price $lines $sell');
  final detail = b.shopAt('detail'), name = b.bagDetail('name'), icon = b.bagDetail('icon');
  expect([inside(icon, detail), inside(name, detail)], [true, true], reason: '$tag: $icon $name in $detail');
  expect([price.left, price.left >= icon.right], [name.left.roundToDouble(), true], reason: '$tag: the price row under the words');
  final parts = [for (final key in ['unit', 'minus', 'count', 'plus', 'all', 'subtotal']) (key, b.shopAt(key))];
  for (final (i, (key, r)) in parts.indexed) {
    expect(r != Rect.zero && inside(r, price), isTrue, reason: '$tag $key: $r in the price row $price');
    if (i > 0) expect(r.left >= parts[i - 1].$2.right - 0.5, isTrue, reason: '$tag: $key right of ${parts[i - 1].$1}');
  }
}

/// The materials seen, in the order they first dropped.
const seen = [Mat.wolfClaw, Mat.slimeGel, Mat.boneShard];

/// A board game in a Town after wave 30 (the Towns, and with them the forge, on): a mixed army, Swords (+0, two at
/// +2, one at +3) and Shields, a small relic (and another worn, none in the Bag), Wolf Claws and Slime Gel, a Vault
/// Artifact, one bound to the knights and an oath, 40,000 gold, the materials [seen].
Game tabsGame() {
  final g = Game(Random(1), Random(2)).boardRules()
    ..townDice = Random(3)
    ..armyMax = null
    ..gold = 40000
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
  g.inventory.addAll({Item.sword: 3, Item.shield: 12});
  g.enhancedBag.addAll({(Item.sword, 2): 2, (Item.sword, 3): 1});
  g.relicBag[droppedRelics.first] = 2;
  g.materials.addAll({Mat.wolfClaw: 4, Mat.slimeGel: 9});
  g.matsSeen.addAll(seen);
  g.pusaka[Relic.titanBane] = OwnedPusaka(stars: 2);
  g.pusaka[Relic.dragonCrown] = OwnedPusaka(type: 'knight');
  g.pusaka[Relic.oathOfOne] = OwnedPusaka();
  g.troops.firstWhere((u) => u.type == 'archer').relics.add(Relic.fury);
  return g;
}

/// [loot]'s name as the page's heading has it.
String shopNameOf(BagLoot loot) => switch (loot.kind) {
      final Item i => itemNames[i]!,
      final Relic r => relicNames[r]!,
      final Mat m => m.label,
      _ => '',
    };

/// What one [loot] sells for.
int each(Game g, BagLoot loot) => loot.kind is Item ? g.sellPriceAt(loot.kind as Item, loot.plus) : g.sellPrice(loot.kind);

void main() {
  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets("the Shop at $tag with the forge: Buy | Sell opening on Buy; Buy's Materials alone, its heading over its "
        "leftmost cell; a material bought; Sell's grid, nothing in use on it; the Sell Basket: an item stack, an "
        'enhanced stack, a relic, an Artifact and a material sold in one press; it fits', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = tabsGame();
      await frames(tester, 40);
      await turnTo(tester, b, 'store');
      expect((b.bookPage, b.storeShown, b.shopTab, b.shopPick), ('store', true, ShopTab.buy, null));
      final book = b.bookArea, leftPage = Rect.fromLTRB(book.left, book.top, book.center.dx, book.bottom), screen = Offset.zero & size;

      // The strip: Buy | Sell on one paper strip on the left page; none of the Bag's chips.
      final buy = b.shopTabAt(ShopTab.buy), sell = b.shopTabAt(ShopTab.sell);
      expect((buy.top, buy.bottom, buy.right <= sell.left + 0.5), (sell.top, sell.bottom, true), reason: tag);
      expect(inside(buy.expandToInclude(sell), leftPage), isTrue, reason: '$tag: $buy $sell on the left page');
      expect([for (final c in BagCategory.values) b.bagChip(c)], everyElement(Rect.zero), reason: tag);
      expect([b.bagDetailText('name'), b.bagActions, b.shopAt('detail')], [null, isEmpty, Rect.zero], reason: '$tag: blank');

      // Buy: Materials alone (decisions-log 280: Items and Relics, which the forge's shelf has none of, are not drawn), the
      // shelf in drop order at its prices; every heading's words start at the board's leftmost cell.
      expect(shopBuySections(g), [BagCategory.materials]);
      final heads = <BagCategory>[], cells = <Enum>[];
      for (var p = 0; p < b.bagPages; p++) {
        if (p > 0) await tapOn(tester, b.bagPager('on'));
        final edge = b.bagSlots.isEmpty ? null : b.bagSlots.map((r) => r.left).reduce(min);
        for (final (s, r) in b.shopSections) {
          if (!heads.contains(s)) heads.add(s);
          expect(inside(r, leftPage), isTrue, reason: '$tag $s: $r');
          if (edge != null) expect(r.left, edge, reason: '$tag $s: its words at the leftmost cell');
        }
        for (final (kind, r) in b.bagCells) {
          expect(inside(r, leftPage) && inside(r, screen), isTrue, reason: '$tag $kind: $r');
          expect((b.bagMarks(kind)!.price, b.bagMarks(kind)!.count), (g.buyPrice(kind), null), reason: '$tag $kind');
          cells.add(kind);
        }
      }
      expect(heads, [BagCategory.materials], reason: tag);
      expect(cells, seen, reason: tag);
      expect(b.shopText('nothing'), isNull, reason: tag);

      // A Buy pick: its heading and Buy alone; a buy fills the Bag.
      await cell(tester, b, Mat.wolfClaw);
      expect((b.shopPick, b.bagDetailText('name'), b.bagDetailText('count')), (Mat.wolfClaw, 'Wolf Claw', 'x4'));
      expect([for (final a in b.bagActions) a.$1], [BagAction.buy]);
      expect((b.shopAt('detail'), b.shopAt('sell')), (Rect.zero, Rect.zero), reason: 'no Sell Basket on Buy');
      var gold = g.gold;
      final price = g.buyPrice(Mat.wolfClaw);
      await tapOn(tester, b.bagDetail('buy'));
      expect((g.materials[Mat.wolfClaw], g.gold), (5, gold - price), reason: tag);

      // Sell: the pick goes back; one grid of everything in the Bag nothing uses, in the Bag's order, each stack its own
      // cell with its count, no price; the Sell Basket page, empty (decisions-log 278): on top what to do, no price row, no
      // lines, Sell greyed with no coin and no total (decisions-log 306; a press says what to do).
      await tapOn(tester, b.shopTabAt(ShopTab.sell));
      expect((b.shopTab, b.shopPick, b.bagDetailText('name')), (ShopTab.sell, null, null), reason: tag);
      expect([b.shopText('empty'), b.shopText('price'), b.shopText('sell'), b.shopAt('sellCoin'), b.shopBasketLines],
          [shopTapToAdd, null, Words.sell, Rect.zero, isEmpty], reason: tag);
      expect([b.shopAt('price'), b.shopAt('minus')], [Rect.zero, Rect.zero], reason: tag);
      expectSellPage(b, size, tag, picked: false);
      gold = g.gold;
      await tapOn(tester, b.shopAt('sell'));
      expect((g.gold, b.message), (gold, shopTapToAdd), reason: '$tag: greyed, a press says what to do');
      await shutMessage(tester, b);
      final sold = <BagLoot>[];
      while (b.bagPage > 0) {
        await tapOn(tester, b.bagPager('back'));
      }
      for (var p = 0; p < b.bagPages; p++) {
        if (p > 0) await tapOn(tester, b.bagPager('on'));
        for (final (loot, r) in b.shopBagCells) {
          // Items in Bag's (High demand over them: shop_demand_ui_test.dart).
          expect(inside(r, leftPage), isTrue, reason: '$tag $loot');
          expect(b.bagMarks(loot.kind, loot.plus)!.price, isNull, reason: '$tag $loot');
          sold.add(loot);
        }
      }
      expect(sold, shopSellLoot(g));
      final sword0 = (kind: Item.sword, plus: 0), sword2 = (kind: Item.sword, plus: 2), relic = (kind: droppedRelics.first, plus: 0);
      final bane = (kind: Relic.titanBane, plus: 0), claw = (kind: Mat.wolfClaw, plus: 0);
      expect(sold.take(5), [sword0, sword2, (kind: Item.sword, plus: 3), (kind: Item.shield, plus: 0), relic]);
      expect(sold.last, bane, reason: 'the Vault Artifact; the bound one and the oath are in use');
      expect(sold.map((l) => l.kind), isNot(anyOf(contains(Relic.dragonCrown), contains(Relic.oathOfOne), contains(Relic.fury))));
      while (!b.shopBagCells.any((c) => c.$1 == (kind: Item.shield, plus: 0)) && b.bagPage > 0) {
        await tapOn(tester, b.bagPager('back')); // back to its page (a phone's pages: High demand's first, decisions-log 335)
      }
      expect(b.bagMarks(Item.shield)!.count, 12);

      // A tap puts a cell in the basket at 1 and picks it: the top shows it (its heading, its grade), its price row "5522 x
      // 1 = 5522"; the cell's count turns green; the page's parts in order, the price row under the name's words.
      await cell(tester, b, Item.sword, 2);
      expect([b.shopPickAt, b.shopBasket, b.shopText('count')], [sword2, {sword2: 1}, '1'], reason: tag);
      expect((b.bagDetailText('name'), b.shopText('kind')), ('${itemNames[Item.sword]} +2', 'Grade I item'), reason: tag);
      expect(b.shopText('price'), '${shortPrice(each(g, sword2))} x 1 = ${shortPrice(each(g, sword2))}', reason: tag);
      expect(b.shopBasketLines.single.$3, '1 x ${shortPrice(each(g, sword2))} = ${shortPrice(each(g, sword2))}');
      expect((b.bagMarks(Item.sword, 2)!.basket, b.bagMarks(Item.sword, 2)!.count), (1, null));
      expectSellPage(b, size, tag);
      await tapOn(tester, b.shopAt('all'));
      await tapOn(tester, b.shopAt('plus'));
      expect([b.shopBasket, b.shopText('count'), b.shopText('subtotal')], [{sword2: 2}, '2', shortPrice(shopSubtotal(g, sword2, 2))],
          reason: 'never past what is held');

      // The rest of the basket: two Swords at +0, the small relic, the Vault Artifact (one: + greyed), four Wolf Claws
      // less one. A cell already in the basket is only picked again, its count kept.
      await cell(tester, b, Item.sword);
      await tapOn(tester, b.shopAt('plus'));
      await cell(tester, b, droppedRelics.first);
      expect(b.shopText('kind'), g.relicTierLine(droppedRelics.first), reason: tag);
      await cell(tester, b, Relic.titanBane);
      expect((b.shopText('count'), b.shopText('kind')), ('1', '${Words.rare} · in ${Words.vault}'), reason: tag);
      await tapOn(tester, b.shopAt('plus'));
      expect(b.shopBasket[bane], 1);
      await cell(tester, b, Mat.wolfClaw);
      expect([b.shopText('kind'), b.shopText('desc')], [null, isNotEmpty], reason: '$tag: what drops it says what it is');
      for (var i = 0; i < 3; i++) {
        await tapOn(tester, b.shopAt('plus'));
      }
      await tapOn(tester, b.shopAt('minus'));
      await cell(tester, b, Item.sword);
      expect([b.shopPickAt, b.shopBasket[sword0], b.bagDetailText('name')], [sword0, 2, itemNames[Item.sword]], reason: tag);
      // A cell's count to sell at its bottom right; the Artifact's at its top right, its stars keeping the bottom right. Each
      // turned to first (a phone's pages: High demand's first, decisions-log 335).
      Future<Rect> at(BagLoot loot) async {
        while (!b.shopBagCells.any((c) => c.$1 == loot) && b.bagPage > 0) {
          await tapOn(tester, b.bagPager('back'));
        }
        while (!b.shopBagCells.any((c) => c.$1 == loot) && b.bagPage < b.bagPages - 1) {
          await tapOn(tester, b.bagPager('on'));
        }
        return b.shopBagCells.firstWhere((c) => c.$1 == loot).$2;
      }

      final clawAt = await at(claw);
      expect([b.shopCountAt(claw).top > clawAt.center.dy, b.shopCountAt(claw).right <= clawAt.right], [true, true], reason: tag);
      final baneAt = await at(bane);
      expect([b.shopCountAt(bane).bottom < baneAt.center.dy, b.shopCountAt(bane).right <= baneAt.right], [true, true], reason: tag);
      var basket = {sword2: 2, sword0: 2, relic: 1, bane: 1, claw: 3};
      expect(b.shopBasket, basket, reason: '$tag: in the order added');

      // A line picks its stack: the top shows it. "-" at 1 takes the line out, and the top shows the last line; its cell
      // puts it back in at the end.
      await tapOn(tester, b.shopBasketLines.firstWhere((l) => l.$1 == relic).$2);
      expect((b.shopPickAt, b.bagDetailText('name')), (relic, relicNames[droppedRelics.first]), reason: tag);
      await tapOn(tester, b.shopAt('minus'));
      expect((b.shopBasket.containsKey(relic), b.shopPickAt, b.bagDetailText('name')), (false, claw, 'Wolf Claw'), reason: tag);
      await cell(tester, b, droppedRelics.first);
      basket = {sword2: 2, sword0: 2, bane: 1, claw: 3, relic: 1};
      expect(b.shopBasket, basket);
      final total = [for (final MapEntry(key: l, value: n) in basket.entries) shopSubtotal(g, l, n)].reduce((x, y) => x + y);
      expect(shopBasketGold(g, b.shopBasket), total);
      // Sell reads "Sell", the coin and the total (decisions-log 306; the owner: "total coinnya di pindah ke button aja,
      // dan di tabahin icon coin"), at every size.
      expect((b.shopText('sell'), inside(b.shopAt('sellCoin'), b.shopAt('sell'))), ('${Words.sell} ${shortPrice(total)}', true), reason: tag);
      expect(b.shopAt('sellCoin').left, greaterThan(b.shopAt('sell').left + b.shopAt('sell').width * 0.2), reason: '$tag: in the middle, after "Sell"');
      for (final (l, r, _) in b.shopBasketLines) {
        expect(inside(r, b.shopAt('lines')) && inside(r, screen), isTrue, reason: '$tag $l: $r');
      }
      expectSellPage(b, size, tag);

      // One press sells the whole basket: the gold is its total, the stacks go, the basket empties, the top says what to do.
      gold = g.gold;
      await tapOn(tester, b.shopAt('sell'));
      expect((g.gold, g.bagOf(Item.sword), g.bagOf(Item.sword, 2), g.inBag(droppedRelics.first)), (gold + total, 1, 0, 1), reason: tag);
      expect((g.pusaka.containsKey(Relic.titanBane), g.materials[Mat.wolfClaw]), (false, 2), reason: tag);
      expect([b.shopBasket, b.message], [isEmpty, 'Sold 9 pieces: +${shortPrice(total)} gold']);
      await shutMessage(tester, b);
      expect([b.shopPick, b.shopText('empty'), b.shopBasketLines, b.shopText('sell'), b.shopAt('sellCoin')],
          [null, shopTapToAdd, isEmpty, Words.sell, Rect.zero]);
      await frames(tester, 10);
    });
  }

  testWidgets('the price row per stack (decisions-log 278): what one sells for, an enhanced stack its own, a small relic, '
      'a material and an Artifact, x the count = the subtotal; the stepper from 1 to what is held ("+" and All stop there, '
      '"-" at 1 takes the line out and the top shows the last line); a line or a cell picks a stack and the top shows it, a '
      'cell already in keeps its count; Sell sells exactly the basket', (tester) async {
    final b = await boot(tester);
    final g = b.state = tabsGame();
    await frames(tester, 40);
    await turnTo(tester, b, 'store');
    await tapOn(tester, b.shopTabAt(ShopTab.sell));
    const sword0 = (kind: Item.sword, plus: 0), sword2 = (kind: Item.sword, plus: 2), sword3 = (kind: Item.sword, plus: 3);
    final relic = (kind: droppedRelics.first, plus: 0);
    const shield = (kind: Item.shield, plus: 0), claw = (kind: Mat.wolfClaw, plus: 0), bane = (kind: Relic.titanBane, plus: 0);
    expect([each(g, sword3) > each(g, sword2), each(g, sword2) > each(g, sword0)], [true, true], reason: 'a stack its own price');
    String row(BagLoot loot, int n) => '${shortPrice(each(g, loot))} x $n = ${shortPrice(shopSubtotal(g, loot, n))}';
    for (final loot in [sword0, sword2, sword3, shield, relic, claw, bane]) {
      final held = shopHeld(g, loot);
      await cell(tester, b, loot.kind, loot.plus);
      expect([b.shopPickAt, b.shopBasket[loot], b.shopText('count'), b.shopText('price')], [loot, 1, '1', row(loot, 1)], reason: '$loot');
      await tapOn(tester, b.shopAt('plus'));
      expect([b.shopBasket[loot], b.shopText('price')], [min(2, held), row(loot, min(2, held))], reason: '$loot +');
      await tapOn(tester, b.shopAt('all'));
      expect([b.shopBasket[loot], b.shopText('subtotal')], [held, shortPrice(shopSubtotal(g, loot, held))], reason: '$loot All');
      await tapOn(tester, b.shopAt('plus'));
      expect(b.shopBasket[loot], held, reason: '$loot: never past what is held, ${shopHeld(g, loot)}');
      if (held > 1) {
        await tapOn(tester, b.shopAt('minus'));
        expect([b.shopBasket[loot], b.shopText('price')], [held - 1, row(loot, held - 1)], reason: '$loot -');
      }
    }
    // The Artifact (one held) went to 1 and back; "-" at 1 takes its line out: the top shows the last line (the claws).
    expect(b.shopPickAt, bane);
    await tapOn(tester, b.shopAt('minus'));
    expect([b.shopBasket.containsKey(bane), b.shopPickAt, b.bagDetailText('name')], [false, claw, 'Wolf Claw']);
    final basket = {sword0: 2, sword2: 1, sword3: 1, shield: 11, relic: 1, claw: 3};
    expect(b.shopBasket, basket);
    final lines = <BagLoot, String>{};
    await wheelLines(tester, b, seen: lines);
    // The Smithy's goods fall piece by piece (decisions-log 326): a line says their average and their sum.
    expect(lines, {
      for (final MapEntry(key: l, value: n) in basket.entries)
        l: '$n x ${shortPrice((shopSubtotal(g, l, n) / n).round())} = ${shortPrice(shopSubtotal(g, l, n))}',
    });

    // A line picks its stack: the top shows it, its price row its own.
    for (final loot in [shield, sword2, relic]) {
      await tapOn(tester, await lineOf(tester, b, loot), '$loot line');
      expect([b.shopPickAt, b.bagDetailText('name'), b.shopText('price')],
          [loot, '${shopNameOf(loot)}${loot.plus > 0 ? ' +${loot.plus}' : ''}', row(loot, basket[loot]!)], reason: '$loot');
    }
    // A cell already in: picked, its count kept.
    await cell(tester, b, Item.shield);
    expect([b.shopPickAt, b.shopBasket[shield]], [shield, 11]);

    // Sell: exactly the basket, nothing else; the basket empties.
    final gold = g.gold, worth = shopBasketGold(g, basket), before = {for (final l in shopSellLoot(g)) l: shopHeld(g, l)};
    await tapOn(tester, b.shopAt('sell'));
    expect(g.gold, gold + worth);
    for (final MapEntry(key: l, value: n) in before.entries) {
      expect(shopHeld(g, l), n - (basket[l] ?? 0), reason: '$l');
    }
    expect([b.shopBasket, b.shopPick, b.shopText('empty')], [isEmpty, null, shopTapToAdd]);
    await shutMessage(tester, b);
    await frames(tester, 10);
  });

  for (final size in [sizes[2]]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('a long basket at $tag (decisions-log 278): its lines scroll under the price row, the pick\'s line in view, '
        'the bottom bar stays; a cell picked brings its line back into view', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = tabsGame();
      g.inventory.addAll({for (final i in droppedItems) i: 2});
      g.materials.addAll({for (final m in droppedMats.take(10)) m: 2});
      await frames(tester, 40);
      await turnTo(tester, b, 'store');
      await tapOn(tester, b.shopTabAt(ShopTab.sell));
      final all = shopSellLoot(g);
      for (final loot in all) {
        await cell(tester, b, loot.kind, loot.plus);
      }
      expect(b.shopBasket.keys, all);
      final lines = b.shopAt('lines');
      expect(all.length * b.shopBasketLines.first.$2.height, greaterThan(lines.height), reason: '$tag: more than fit');
      expect(b.shopBasketLines.length, lessThan(all.length), reason: '$tag: some scrolled away');
      Rect lineOf(BagLoot loot) => b.shopBasketLines.where((l) => l.$1 == loot).firstOrNull?.$2 ?? Rect.zero;
      final whole = b.shopBasketLines.map((l) => l.$2.height).reduce(max);
      expect([inside(lineOf(all.last), lines), lineOf(all.last).height], [true, whole], reason: '$tag: the pick wholly in view');
      expectSellPage(b, size, tag);
      await cell(tester, b, all.first.kind, all.first.plus);
      // (The book bobs: the page's rects read again after the tap.)
      expect([b.shopPickAt, b.shopBasket[all.first], inside(lineOf(all.first), b.shopAt('lines')), lineOf(all.first).height],
          [all.first, 1, true, whole], reason: '$tag: back in view');
      expectSellPage(b, size, tag);
      await frames(tester, 10);
    });
  }

  test('the basket: mixed kinds and pluses, an Artifact among them; its gold is what selling them one by one brings; every '
      'kind has a price; it keeps to what is held, and nothing in use stays', () {
    final basket = {
      (kind: Item.sword, plus: 0): 2,
      (kind: Item.sword, plus: 2): 2,
      (kind: Item.sword, plus: 3): 1,
      (kind: droppedRelics.first, plus: 0): 1,
      (kind: Mat.wolfClaw, plus: 0): 3,
      (kind: Relic.titanBane, plus: 0): 1,
    };
    final a = tabsGame(), one = tabsGame();
    final gold = shopBasketGold(a, basket), before = a.gold;
    expect(shopBasketPieces(basket), 10);
    expect(gold, [for (final MapEntry(key: l, value: n) in basket.entries) shopSubtotal(a, l, n)].reduce((x, y) => x + y));
    expect(each(a, (kind: Item.sword, plus: 3)), greaterThan(each(a, (kind: Item.sword, plus: 2))));
    expect(shopSellBasket(a, basket), (pieces: 10, gold: gold));
    expect(a.gold, before + gold);
    final start = one.gold;
    for (final MapEntry(key: (:kind, :plus), value: n) in basket.entries) {
      for (var i = 0; i < n; i++) {
        expect(kind is Item ? one.sellAt(kind, plus) : one.sell(kind), 1, reason: '$kind +$plus');
      }
    }
    expect(one.gold - start, gold, reason: 'the same gold as one by one');
    expect((a.inventory[Item.sword], a.bagOf(Item.sword, 2), a.bagOf(Item.sword, 3), a.materials[Mat.wolfClaw]), (1, 0, 0, 1));
    expect(a.pusaka.containsKey(Relic.titanBane), isFalse);

    // Every kind in the Bag has a price: the items at every grade, the small relics, the materials (the forge's stones
    // too) and every Artifact rarity.
    for (final kind in <Enum>[...Item.values, ...a.relicsInPlay, ...Mat.values, for (final r in Relic.values) if (r.pusaka && !r.oath) r]) {
      expect(a.sellPrice(kind), greaterThan(0), reason: '$kind');
    }

    // Kept to the Bag: a count over what is held comes down, a stack gone leaves, an Artifact bound to a type (in use)
    // leaves.
    final g = tabsGame(), kept = {(kind: Item.sword, plus: 2): 5, (kind: Item.shield, plus: 0): 3, (kind: Relic.titanBane, plus: 0): 1};
    shopBasketFit(g, kept);
    expect(kept, {(kind: Item.sword, plus: 2): 2, (kind: Item.shield, plus: 0): 3, (kind: Relic.titanBane, plus: 0): 1});
    g.enhancedBag.remove((Item.sword, 2));
    g.inventory[Item.shield] = 1;
    g.pusaka[Relic.titanBane] = OwnedPusaka(type: 'knight');
    shopBasketFit(g, kept);
    expect(kept, {(kind: Item.shield, plus: 0): 1});
    expect(shopSellBasket(g, {}), (pieces: 0, gold: 0));
  });

  testWidgets("the basket's life: a tab switch puts the pick back and keeps it; leaving the Shop empties it and the Shop "
      'opens on Buy; another game empties it and opens on Buy; a stack that shrinks clamps it; the Town\'s Bag keeps its chips', (tester) async {
    final b = await boot(tester);
    var g = b.state = tabsGame();
    await frames(tester, 40);
    await turnTo(tester, b, 'store');
    await tapOn(tester, b.shopTabAt(ShopTab.sell));
    await cell(tester, b, Item.shield);
    await tapOn(tester, b.shopAt('all'));
    expect(b.shopBasket, {(kind: Item.shield, plus: 0): 12});

    // The picked cell tapped again (decisions-log 278): still picked, its count kept, its price row shown; Sell green.
    const shield = (kind: Item.shield, plus: 0);
    await cell(tester, b, Item.shield);
    expect([b.shopPickAt, b.shopBasket, b.shopText('count'), b.shopBasketLines.length], [shield, {shield: 12}, '12', 1]);
    expect(b.shopText('sell'), startsWith(Words.sell));

    // A tab switch: the pick back, the basket kept; Buy's page shows no basket; back on Sell its last line is picked.
    await tapOn(tester, b.shopTabAt(ShopTab.buy));
    expect((b.shopTab, b.shopPick, b.shopBasket.length, b.shopAt('lines'), b.shopAt('price')), (ShopTab.buy, null, 1, Rect.zero, Rect.zero));
    await tapOn(tester, b.shopTabAt(ShopTab.sell));
    expect((b.shopBasket.length, b.shopPickAt, b.shopText('count')), (1, shield, '12'));

    // A stack that shrinks while in the basket comes down to what is held.
    g.inventory[Item.shield] = 5;
    await frames(tester);
    expect(b.shopBasket, {(kind: Item.shield, plus: 0): 5});

    // Leaving the Shop: the basket empties, the Shop opens on Buy. The Town's Bag keeps all its chips (Pocket only while
    // a pocket item is held, decisions-log 332: none here).
    await turnTo(tester, b, 'bag');
    expect([for (final c in BagCategory.values) b.bagChip(c) != Rect.zero], [true, true, true, true, false, true]);
    await turnTo(tester, b, 'store');
    expect([b.shopTab, b.shopBasket], [ShopTab.buy, isEmpty]);

    // Another game: empty again.
    await tapOn(tester, b.shopTabAt(ShopTab.sell));
    await cell(tester, b, Item.shield);
    expect(b.shopBasket, isNotEmpty);
    g = b.state = tabsGame();
    await frames(tester, 3);
    expect([b.shopTab, b.shopBasket, b.shopPick], [ShopTab.buy, isEmpty, null], reason: 'another game opens on Buy');
    await frames(tester, 10);
  });

  for (final size in [sizes.first, sizes.last]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets("the Smithy's \"Wishlist\" heading at $tag: its words start at the first line's head (decisions-log 302: the "
        'materials\' heading went with them)', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = tabsGame();
      await frames(tester, 40);
      if (b.bookPage != 'smithy') await turnTo(tester, b, 'smithy');
      final type = g.troops.map((u) => u.type).firstWhere((t) => g.wishSetOf(t).isNotEmpty);
      g.wishSet(type);
      await frames(tester, 3);
      final first = b.smithyAt('wishType:$type');
      expect(first, isNot(Rect.zero), reason: tag);
      expect(b.smithyAt('wishHead').left, first.left, reason: tag);
      await frames(tester, 10);
    });
  }
}
