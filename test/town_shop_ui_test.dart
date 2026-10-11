// The Town's Shop on the Bag's code (decisions-log 230 and 269; ui-hud.md "The Town's Shop", "Army"), booted TdGames with
// the Towns on: in a Town the book's Shop tab is the strip Buy | Sell (Buy, the forge's shelf: forge_shop_ui_test.dart);
// Sell's grid of what the Bag holds, a material and a Vault Artifact sold through the Sell Basket, at 1266x713, 1164x777
// and 915x412 (the basket: shop_tabs_ui_test.dart); on the field the Bag sells nothing and says where it sells; the
// Army detail recalls the fallen Heroes (newest first, two and "+1 more", greyed with why, a full army's swap); the gold's
// dot on the Army tab. The rules: town_shop_test.dart. One TdGame per widget test.
//
// Never let a wave be won or the game end here (the Board then saves).
import 'dart:convert';
import 'dart:io';
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

const sizes = [Size(1266, 713), Size(1164, 777), Size(915, 412)];

/// A board game after wave 20 with the Towns on, in a Town ([inTown]) or on the field: a mixed army, items, small relics,
/// materials and a Vault Artifact, 40,000 gold.
Game shopGame({bool inTown = true}) {
  final g = Game(Random(1), Random(2)).boardRules()
    ..townDice = Random(3)
    ..towns = true
    ..armyMax = null
    ..gold = 40000
    ..wave = 20;
  if (inTown) {
    g
      ..townAt = 21
      ..inTown = true;
  }
  for (final type in ['knight', 'archer', 'priest', 'soldier']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.inventory.addAll({Item.sword: 3, Item.shield: 12});
  g.relicBag[droppedRelics.first] = 2;
  g.materials.addAll({Mat.wolfClaw: 4, Mat.slimeGel: 9});
  g.pusaka[Relic.titanBane] = OwnedPusaka(stars: 2);
  return g;
}

void main() {
  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets("the Town's Shop at $tag: Buy | Sell (Buy, the forge's shelf: forge_shop_ui_test.dart); Sell's grid; a "
        'material and a Vault Artifact sold through the basket; it fits', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = shopGame();
      await frames(tester, 40);
      await turnTo(tester, b, 'store');
      expect((b.bookPage, b.storeShown, b.shopPick, b.shopTab), ('store', true, null, ShopTab.buy));
      final book = b.bookArea;

      // The strip: Buy and Sell on one paper strip across the left page, the Shop's title above; no Bag chips.
      final buy = b.shopTabAt(ShopTab.buy), sell = b.shopTabAt(ShopTab.sell);
      expect((buy.top, buy.bottom, buy.right <= sell.left + 0.5), (sell.top, sell.bottom, true));
      expect(inside(buy.expandToInclude(sell), book) && sell.right <= book.center.dx + 0.5, isTrue, reason: '$tag: the strip in the book');
      expect([for (final c in BagCategory.values) b.bagChip(c)], everyElement(Rect.zero));

      // Sell: the Bag's items, small relics, materials and Vault Artifact, their counts.
      await tapOn(tester, b.shopTabAt(ShopTab.sell));
      expect(shopSellLoot(g).map((l) => l.kind), [Item.sword, Item.shield, droppedRelics.first, Mat.slimeGel, Mat.wolfClaw, Relic.titanBane]);
      expect([for (final c in b.bagCells) c.$1], shopSellLoot(g).map((l) => l.kind).take(b.bagCells.length));
      expect((b.bagMarks(Item.shield)!.count, b.bagMarks(Item.shield)!.price), (12, null));

      // A material through the Sell Basket: a tap puts one in, All the rest, one Sell; its last gone, its cell goes.
      await cell(tester, b, Mat.wolfClaw);
      var gold = g.gold;
      expect((b.shopText('count'), b.shopText('price'), b.shopBasketLines.single.$3), ('1', '25 x 1 = 25', '1 x 25 = 25'));
      await tapOn(tester, b.shopAt('all'));
      expect((b.shopText('count'), b.shopText('sell'), b.shopBasketLines.single.$3), ('4', '${Words.sell} 100', '4 x 25 = 100'));
      for (final key in ['lines', 'all', 'sell']) {
        expect(inside(b.shopAt(key), book) && inside(b.shopAt(key), Offset.zero & size), isTrue, reason: '$tag $key');
      }
      await tapOn(tester, b.shopAt('sell'));
      expect((g.materials.containsKey(Mat.wolfClaw), g.gold, b.message), (false, gold + 100, 'Sold Wolf Claw x4: +100 gold'));
      await shutMessage(tester, b);
      expect([b.shopPick, b.bagCells.any((c) => c.$1 == Mat.wolfClaw), b.shopBasket], [null, false, isEmpty]);

      // A Vault Artifact goes through the basket too (one of it).
      await cell(tester, b, Relic.titanBane);
      expect([b.shopBasket, b.shopText('count')], [{(kind: Relic.titanBane, plus: 0): 1}, '1']);
      gold = g.gold;
      final price = g.sellPrice(Relic.titanBane);
      await tapOn(tester, b.shopAt('sell'));
      expect((g.pusaka.containsKey(Relic.titanBane), g.gold, b.message), (false, gold + price, 'Sold ${relicNames[Relic.titanBane]}: +${shortPrice(price)} gold'));
      await shutMessage(tester, b);
      await frames(tester, 10);
    });
  }

  testWidgets('the Bag sells nothing on the field: no Sell row for an item, a small relic, a material or a Vault Artifact, '
      'and the grey line says where (the Towns-off Sell went, decisions-log 296)', (tester) async {
    final b = await boot(tester);
    for (final size in [sizes.first, sizes.last]) {
      tester.view.physicalSize = size;
      final g = b.state = shopGame(inTown: false);
      await frames(tester, 40);
      if (!b.bagOpen) await turnTo(tester, b, 'bag');
      expect([for (final (name, _) in b.bookTabs) name], ['troops', 'bag', 'settings'], reason: 'no Shop tab on the field');
      for (final kind in [Item.shield, droppedRelics.first, Mat.wolfClaw, Relic.titanBane]) {
        await cell(tester, b, kind);
        expect(b.picked, kind, reason: '$size $kind');
        expect(b.bagActions.map((a) => a.$1.name), isNot(contains('sell')), reason: '$size $kind: no Sell');
        final note = b.bagDetailText('note');
        expect(note, kind is Mat ? isNull : Words.soldInTown, reason: '$size $kind');
        if (note != null) expect(inside(b.bagDetail('note'), b.assignList), isTrue, reason: '$size $kind: under the rows');
        await tapOn(tester, b.bagCells.firstWhere((c) => c.$1 == kind).$2); // put back
      }
      expect(g.inBag(Item.shield), 12);
    }
    await frames(tester, 10);
  });

  testWidgets("the Army detail recalls a type's fallen Heroes with the Towns on: newest first, two and \"+1 more\", "
      'greyed with why, a full army\'s swap; it fits the four sizes', (tester) async {
    final b = await boot(tester);

    /// A field game after wave 65 (a recall 57k) with three knights fallen, Hero 1 to Hero 3, and room in the army.
    Game fallen() {
      final g = shopGame(inTown: false)
        ..wave = 65
        ..gold = 1000000;
      for (var i = 1; i <= 3; i++) {
        g.fallenHeroes.add(FallenHero(name: 'Hero $i', type: 'knight', stats: const [HeroStat.hp, HeroStat.power], fell: 60 + i));
      }
      return g;
    }

    /// Scrolls the detail's body until Recall line [i] shows whole, in its upper half where the body scrolls that far.
    Future<Rect> reveal(int i) async {
      final most = max(0.0, b.troopDetailContent - b.troopDetailBody.height);
      double? best;
      for (var s = 0.0; s <= most + 6; s += 6) {
        b.troopDetailScroll = min(s, most);
        await frames(tester, 1);
        final r = b.troopDetail('recall:$i');
        if (r == Rect.zero || r.height < 18 || !inside(r, b.troopDetailBody)) continue;
        best = min(s, most);
        if (r.top <= b.troopDetailBody.center.dy) break;
      }
      expect(best, isNotNull, reason: 'recall:$i never shows whole');
      b.troopDetailScroll = best!;
      await frames(tester);
      return b.troopDetail('recall:$i');
    }

    for (final size in sizes) {
      tester.view.physicalSize = size;
      final g = b.state = fallen();
      await frames(tester, 40);
      if (b.bookPage != 'troops') await turnTo(tester, b, 'troops');
      if (b.troopPicked != 'knight') await tapOn(tester, b.troopRow('knight'));
      final newest = await reveal(2), next = b.troopDetail('recall:1');
      expect((next == Rect.zero, b.troopDetail('recall:0')), (false, Rect.zero), reason: '$size: two shown');
      expect(newest.top, lessThan(next.top), reason: 'the last to fall first');
      expect(b.troopDetailWords('recall'), ['${Words.recall} 57k', '${Words.recall} 57k'], reason: '$size');
      expect(b.troopDetailWords('heroes'), containsAllInOrder(['Fallen: Hero 3', 'Fallen: Hero 2', '+1 more']), reason: '$size');
      expect(inside(newest, b.bookArea) && inside(newest, Offset.zero & size), isTrue, reason: '$size: $newest');
      expect(newest.height, greaterThanOrEqualTo(18), reason: "$size: a finger's");

      if (size == sizes.first) {
        // A tap recalls the Hero: the knight back, the gold paid; Hero 1 shows now and "+1 more" goes.
        final army = g.armySize;
        await tapOn(tester, newest);
        expect((g.fallenHeroes.length, g.armySize, g.gold), (2, army + 1, 1000000 - 57000));
        expect(g.troops.any((u) => u.alive && u.hero && u.name == 'Hero 3'), isTrue);
        expect(b.heroSplash, 'Hero 3 is back!');
        await tester.tapAt(size.center(Offset.zero)); // the splash's tap closes it
        await frames(tester, 3);
        expect(b.heroSplash, isNull);
        await reveal(0);
        expect(b.troopDetailWords('heroes'), isNot(contains('+1 more')));

        // Greyed with why: the gold short; a tap says it and recalls nobody.
        g.gold = 10;
        await frames(tester);
        await tapOn(tester, await reveal(1));
        expect((b.message, g.fallenHeroes.length), (g.whyNotRecall(g.fallenHeroes[1]), 2));
        expect(b.message, isNotNull);
        await shutMessage(tester, b);

        // A full army: the tag says a knight goes home (its gold back is the hover's, decisions-log 237), and the tap
        // swaps it.
        g
          ..gold = 1000000
          ..capacity = g.armySize;
        await frames(tester);
        final f = g.fallenHeroes[1], out = g.recallSwapOf(f)!, refund = g.recallSwapRefundOf('knight');
        await reveal(1);
        expect(b.troopDetailWords('recall').first, '${Words.recall} 57k, swap 1 ${troopTypeNames['knight']}');
        expect(g.recallInfo(f).$2, contains(contains('${out.name} goes home (+${thousands(refund)} gold)')));
        final full = g.armySize;
        await tapOn(tester, b.troopDetail('recall:1'));
        expect((g.armySize, out.alive, g.gold, g.fallenHeroes.length), (full, false, 1000000 - 57000 + refund, 1));
        await tester.tapAt(size.center(Offset.zero)); // its splash
        await frames(tester, 3);
        expect(b.heroSplash, isNull);
      }
    }
    await frames(tester, 10);
  });

  testWidgets("the gold's dot is on the Army tab (no Shop tab on the field), the Towns off too (decisions-log 296: the "
      "Toko's tab, which had it, went)", (tester) async {
    final b = await boot(tester);
    Game rich({required bool towns}) =>
        Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>)
            .boardRules()
          ..chests.clear()
          ..towns = towns
          ..gold = 50000000;
    for (final towns in [true, false]) {
      final g = b.state = rich(towns: towns);
      expect(g.tokoNudge, isTrue);
      await frames(tester, 40);
      final dot = b.storeAt('tokoDot'), tab = b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2;
      expect(dot, isNot(Rect.zero), reason: 'Towns $towns');
      expect(tab.overlaps(dot), isTrue, reason: 'Towns $towns: on the Army tab');
      expect(b.bookTabs.map((t) => t.$1), isNot(contains('store')), reason: 'Towns $towns: no Shop tab on the field');
    }
    await frames(tester, 10);
  });
}
