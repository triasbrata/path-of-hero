// The forge's Town Shop page (decisions-log 248 and 269; ui-hud.md "The Town's Shop"), booted TdGames in a Town at
// 1266x713, 1164x777 and 915x412: with nothing picked Buy's facing page is blank paper (the owner, 2026-10-04:
// "kalau belum ada item yang di pilih maka di sini cukup kosong"); Buy is the forge's
// Materials alone (Items and Relics, which its shelf has none of, left out and Materials moved up into their place:
// decisions-log 280), the materials seen in first-drop order at 2.5x their sell price (each cell's capsule), every cell's
// tap picking its own kind; a material picked shows Buy ("Buy 65", "65 gold, then 75"), a buy spends the gold and fills the
// Bag and never joins matsSeen; the items and small relics held are on Sell; an empty shelf's Buy has no section, only
// "Nothing to buy here yet." (the Artifact shelf open: Artifacts alone), an empty Bag's Sell "Nothing to sell yet." (the forge-off
// shelf went with the forge-off build, decisions-log 296). The rules:
// forge_shop_test.dart. The Sell Basket: shop_tabs_ui_test.dart.
//
// Never let a wave be won or the game end here (the Board then saves).
import 'dart:math';

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

/// Taps [kind]'s cell on the shown grid, turning its pages to it.
Future<void> cell(WidgetTester tester, Board b, Enum kind) async {
  while (b.bagCells.every((c) => c.$1 != kind) && b.bagPage > 0) {
    await tapOn(tester, b.bagPager('back'));
  }
  while (b.bagCells.every((c) => c.$1 != kind) && b.bagPage < b.bagPages - 1) {
    await tapOn(tester, b.bagPager('on'));
  }
  await tapOn(tester, b.bagCells.firstWhere((c) => c.$1 == kind).$2, '$kind');
}

/// [r] wholly inside [area].
bool inside(Rect r, Rect area) => r.left >= area.left - 0.5 && r.top >= area.top - 0.5 && r.right <= area.right + 0.5 && r.bottom <= area.bottom + 0.5;

/// Nothing is drawn on the facing page: no heading, count, icon, line, rows or actions, and no hint (decisions-log 241,
/// 248); the page itself is still there.
void expectBlank(Board b, String at) {
  for (final key in const ['name', 'count', 'empty', 'where', 'desc', 'buy', 'sell']) {
    expect(b.bagDetailText(key), isNull, reason: '$at: $key');
  }
  expect((b.bagDetail('icon'), b.bagDetail('count'), b.bagDetail('desc'), b.bagDetail('empty')), (Rect.zero, Rect.zero, Rect.zero, Rect.zero), reason: at);
  expect((b.bagActions.length, b.bagChooser, b.assignList), (0, null, Rect.zero), reason: at);
  expect(b.bagDetail('page'), isNot(Rect.zero), reason: '$at: the blank paper is still the page');
}

const sizes = [Size(1266, 713), Size(1164, 777), Size(915, 412)];

/// The materials seen, in the order they first dropped (not [Mat]'s).
const seen = [Mat.wolfClaw, Mat.slimeGel, Mat.boneShard, Mat.evilEye, Mat.soulOrb, Mat.lichOrb];

/// A board game in a Town after wave 20 (the Towns, and with them the forge, on): a mixed army, a Sword and Shields, a
/// small relic, Wolf Claws and a Skull (held, never dropped), a Vault Artifact, 40,000 gold, and the materials [seen].
Game forgeGame() {
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
  g.inventory.addAll({Item.sword: 1, Item.shield: 12});
  g.relicBag[droppedRelics.first] = 2;
  g.materials.addAll({Mat.wolfClaw: 4, Mat.skull: 1});
  g.matsSeen.addAll(seen);
  g.pusaka[Relic.titanBane] = OwnedPusaka(stars: 2);
  return g;
}

/// Buy's cells, page by page from the first (it ends on the last page).
Future<List<Enum>> buyCells(WidgetTester tester, Board b) async {
  while (b.bagPage > 0) {
    await tapOn(tester, b.bagPager('back'));
  }
  final cells = <Enum>[];
  for (var p = 0; p < b.bagPages; p++) {
    if (p > 0) await tapOn(tester, b.bagPager('on'));
    cells.addAll([for (final c in b.bagCells) c.$1]);
  }
  return cells;
}

void main() {
  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets("the forge's Town Shop at $tag: blank with nothing picked; Buy's Materials alone, the materials seen at 2.5x "
        'in drop order, each cell picking its kind; a material bought into the Bag; what is held is on Sell', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = forgeGame();
      await frames(tester, 40);
      await turnTo(tester, b, 'store');
      expect((b.bookPage, b.storeShown, b.shopPick, b.shopTab), ('store', true, null, ShopTab.buy));
      final book = b.bookArea;

      // Nothing picked: the facing page is the book's blank paper.
      expectBlank(b, tag);

      // Buy: Materials alone (decisions-log 280: Items and Relics, which the forge's shelf has none of, are not drawn), its
      // heading the board's first piece and its first row right under it: the shelf in drop order, each its price, on the
      // left page.
      expect([for (final (s, _) in b.shopSections) s], [BagCategory.materials], reason: tag);
      expect((b.shopText('nothing'), b.shopAt('nothing')), (null, Rect.zero), reason: tag);
      final head = b.shopSections.single.$2;
      expect(head.top - b.shopTabAt(ShopTab.buy).bottom, inInclusiveRange(0, 16), reason: '$tag: $head right under the strip');
      expect(b.bagSlots.map((r) => r.top).reduce(min), closeTo(head.bottom, 0.5), reason: '$tag: the first row under it');
      const prices = {Mat.wolfClaw: 65, Mat.slimeGel: 25, Mat.boneShard: 40, Mat.evilEye: 750, Mat.soulOrb: 1500, Mat.lichOrb: 2000};
      for (final (kind, r) in b.bagCells) {
        expect(inside(r, book) && r.right <= book.center.dx + 0.5, isTrue, reason: '$tag $kind: $r on the left page');
        expect((b.bagMarks(kind)!.price, b.bagMarks(kind)!.count), (prices[kind], null), reason: '$tag $kind');
      }
      expect(await buyCells(tester, b), seen, reason: '$tag: the Skull held is not on the shelf');

      // Every cell's tap picks its own kind and a second puts it back: the tap targets are where the cells are drawn.
      while (b.bagPage > 0) {
        await tapOn(tester, b.bagPager('back'));
      }
      for (final kind in [for (final c in b.bagCells) c.$1]) {
        await tapOn(tester, b.bagCells.firstWhere((c) => c.$1 == kind).$2, '$tag $kind');
        expect(b.shopPick, kind, reason: '$tag: $kind picked');
        await tapOn(tester, b.bagCells.firstWhere((c) => c.$1 == kind).$2, '$tag $kind');
        expect(b.shopPick, isNull, reason: '$tag: $kind put back');
      }

      // Wolf Claw: Buy 65 ("65 gold, then 75": the market's 10% a buy, decisions-log 326); a buy spends 65 and fills the
      // Bag, matsSeen as it was.
      await cell(tester, b, Mat.wolfClaw);
      expect(b.shopPick, Mat.wolfClaw);
      expect((b.bagDetailText('name'), b.bagDetailText('count')), ('Wolf Claw', 'x4'));
      expect([for (final a in b.bagActions) a.$1], [BagAction.buy]);
      for (final (act, r, _) in b.bagActions) {
        expect(inside(r, b.assignList) && inside(r, book) && inside(r, Offset.zero & size), isTrue, reason: '$tag $act: $r');
      }
      expect(b.bagDetailText('buy'), '${Words.buy} 65');
      expect(b.bagDetailText('hint:buy'), anyOf('65 gold, then 75', '65 gold'), reason: tag);
      final order = [...g.matsSeen], gold = g.gold;
      await tapOn(tester, b.bagDetail('buy'));
      expect((g.materials[Mat.wolfClaw], g.gold, b.message, b.bagDetailText('count')), (5, gold - 65, null, 'x5'), reason: '$tag: one bought');
      expect([...g.matsSeen], order, reason: 'a buy never joins matsSeen');

      // Slime Gel, none held: Buy, the count x0 then x1.
      await cell(tester, b, Mat.slimeGel);
      expect(b.bagDetailText('count'), 'x0');
      await tapOn(tester, b.bagDetail('buy'));
      expect((g.materials[Mat.slimeGel], g.gold, b.bagDetailText('count')), (1, gold - 90, 'x1'));

      // Not enough gold: greyed, a tap says why, nothing bought.
      g.gold = 100;
      await cell(tester, b, Mat.lichOrb);
      await tapOn(tester, b.bagDetail('buy'));
      expect((b.message, g.materials.containsKey(Mat.lichOrb), g.gold), (Words.notEnoughGold, false, 100));
      await shutMessage(tester, b);
      g.gold = 40000;

      // The pick put back: blank again.
      await cell(tester, b, Mat.lichOrb);
      expect(b.shopPick, isNull);
      expectBlank(b, '$tag: put back');

      // Sell: the items, the small relic, the materials and the Vault Artifact held, their counts and no price.
      await tapOn(tester, b.shopTabAt(ShopTab.sell));
      final kinds = [for (final l in shopSellLoot(g)) l.kind];
      expect([kinds.take(3), kinds.skip(3).take(3).toSet(), kinds.skip(6)],
          [[Item.sword, Item.shield, droppedRelics.first], {Mat.wolfClaw, Mat.slimeGel, Mat.skull}, [Relic.titanBane]], reason: tag);
      while (b.shopBagCells.isEmpty && b.bagPage < b.bagPages - 1) {
        await tapOn(tester, b.bagPager('on')); // a phone's page: Items in Bag past High demand's (decisions-log 335)
      }
      expect([for (final c in b.shopBagCells) c.$1.kind], kinds.take(b.shopBagCells.length)); // Items in Bag's
      expect((b.bagMarks(Item.shield)!.count, b.bagMarks(Item.shield)!.price), (12, null));
      await frames(tester, 10);
    });
  }

  testWidgets('the empty shelf and an empty Bag: Buy has no section, only "Nothing to buy here yet." (the Artifact shelf '
      'open: Artifacts alone); Sell "Nothing to sell yet."', (tester) async {
    final b = await boot(tester);
    for (final size in sizes) {
      tester.view.physicalSize = size;
      final g = b.state = forgeGame()
        ..matsSeen.clear()
        ..inventory.clear()
        ..relicBag.clear()
        ..materials.clear()
        ..pusaka.clear();
      await frames(tester, 40);
      if (b.bookPage != 'store') await turnTo(tester, b, 'store');
      if (b.shopTab != ShopTab.buy) await tapOn(tester, b.shopTabAt(ShopTab.buy));
      expect([shopBuyKinds(g, BagCategory.all), shopSellLoot(g)], [isEmpty, isEmpty]);
      expect([shopBuySections(g), b.shopSections, b.bagCells, b.bagSlots], everyElement(isEmpty), reason: '$size: no heading, no slot');
      expect((b.bagPages, b.bagPager('on')), (1, Rect.zero), reason: '$size: no pager');
      final book = b.bookArea, line = b.shopAt('nothing'), strip = b.shopTabAt(ShopTab.buy);
      expect(b.shopText('nothing'), shopNothingToBuy, reason: '$size: one muted line, whole');
      expect(inside(line, Rect.fromLTRB(book.left, strip.bottom, book.center.dx, book.bottom)), isTrue, reason: '$size: $line under the strip');
      expect(line.height, lessThan(30), reason: '$size: one line');
      expectBlank(b, '$size Buy');

      // The Artifact shelf open: Artifacts alone, the line gone.
      g.offers = false;
      await frames(tester, 3);
      expect([for (final (s, _) in b.shopSections) s], [BagCategory.artifacts], reason: '$size');
      expect((b.shopText('nothing'), b.shopAt('nothing')), (null, Rect.zero), reason: '$size');
      expect([for (final c in b.bagCells) c.$1], shopBuyKinds(g, BagCategory.artifacts).take(b.bagCells.length), reason: '$size');
      g.offers = true;
      await frames(tester, 3);
      expect(b.shopText('nothing'), shopNothingToBuy, reason: '$size: closed again');
      await tapOn(tester, b.shopTabAt(ShopTab.sell));
      // The forge and the Towns on: no item drops, materials do (decisions-log 292). Items in Bag's muted line under its
      // heading, whole (decisions-log 335: until then the grid's card), on a phone's page past High demand's.
      while (b.shopAt('head:${Words.itemsInBag}') == Rect.zero && b.bagPage < b.bagPages - 1) {
        await tapOn(tester, b.bagPager('on'));
      }
      expect((b.shopBagCells.length, b.shopText('note:${Words.itemsInBag}')), (0, '$shopNothingToSell Monsters drop materials.'),
          reason: '$size: whole, none cut');
      expect(b.shopAt('head:${Words.itemsInBag}'), isNot(Rect.zero), reason: '$size');
      expect((b.shopText('empty'), b.shopAt('price'), b.shopText('sell'), b.shopAt('sellCoin')), (shopTapToAdd, Rect.zero, Words.sell, Rect.zero),
          reason: '$size: Sell greyed, no total on it (decisions-log 306)');
      await tapOn(tester, b.shopTabAt(ShopTab.buy));
    }
    await frames(tester, 10);
  });
}
