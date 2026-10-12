// The ingredient wishes on the book (decisions-log 323; lib/smithy_page.dart, lib/wishlist.dart; docs/ui-hud.md "The
// Smithy"): the owner, 2026-10-12, "jika material dari item yang mau di forge, adalah hasil forge ketika user click itu
// akan mengarah ke forge item tersebut ... cuma perlu hati hati karna jangan sampai item requirement untuk forge ini malah
// ada cta untuk give to troops". Booted TdGames in a Town at 1600x947 and 915x412: a recipe row of a product the Smithy
// makes opens its page (from an item's page and a relic's), Back returns, a material's row opens nothing; a Wishlist tab
// row's part opens its page, Back returns to the tab; the Wishlist tab's "Ingredients" group, each row "for <product>"
// with its parts, status, Craft and ✕, and no Give anywhere (no tag, no words, no troop); its Craft says only "crafted",
// its ✕ and the group's Remove take ingredient wishes off and leave their parents; a product kept for its parent's craft
// says "Needed for Royal Ring" in its Give row's place. One TdGame per test.
//
// Never let a wave be won or the game end here (the Board then saves).
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'page_scroll.dart';

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

/// Shuts the message window (it can lie over the rows).
Future<void> shutMessage(WidgetTester tester, Board b) async {
  if (b.messageBox != Rect.zero) await tapOn(tester, b.messageBox);
}

const sizes = [Size(1600, 947), Size(915, 412)];

/// A board game after wave 20 in the Town before wave 21: a soldier, a knight, an archer and a priest, 40,000 gold.
Game townGame() {
  final g = Game(Random(1), Random(2)).boardRules()
    ..townDice = Random(3)
    ..armyMax = null
    ..wave = 20
    ..gold = 40000
    ..townAt = 21
    ..inTown = true;
  for (final type in ['soldier', 'knight', 'archer', 'priest']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  return g;
}

/// Puts [item]'s recipe's materials in [g]'s Bag.
void giveMats(Game g, Item item) {
  for (final MapEntry(key: m, value: n) in g.itemRecipe(item)!.materials.entries) {
    g.materials[m] = (g.materials[m] ?? 0) + n;
  }
}

/// The Smithy's Items tab on [item]'s page (its board's pager turned to it, its cell tapped).
Future<void> pickItem(WidgetTester tester, Board b, Item item) async {
  await tapOn(tester, b.smithyAt('tab:items'));
  while (!b.smithyItemCells.any((c) => c.$1 == item)) {
    await tapOn(tester, b.smithyItemPager('on'));
  }
  await tapOn(tester, b.smithyItemCells.firstWhere((c) => c.$1 == item).$2);
  expect(b.smithyItem, item);
}

/// The facing page's recipe row of [kind], scrolled into view.
Future<Rect> recipeRow(WidgetTester tester, Board b, Enum kind) =>
    scrolledTo(tester, b, 'smithy', () => b.smithyRows.where((r) => r.kind == kind).firstOrNull?.at ?? Rect.zero);

/// The facing page's part [key], scrolled into view.
Future<Rect> seen(WidgetTester tester, Board b, String key) => scrolledTo(tester, b, 'smithy', () => b.smithyAt(key));

/// Every word the Wishlist tab drew for row [key] ([Board.smithyText]'s per-row keys).
String rowWords(Board b, String key) => [
      for (final part in ['wishTitle', 'wishParts', 'wishStatus', 'wishCraft', 'wishGive', 'wishGiveWhy']) b.smithyText('$part:$key') ?? '',
    ].join(' | ');

void main() {
  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('the links at $tag: a recipe row of a product the Smithy makes opens its page, Back returns; a material\'s '
        'opens nothing; a relic\'s item row too', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = townGame();
      await frames(tester, 40);
      await shutMessage(tester, b);
      await pickItem(tester, b, Item.royalRing);
      expect((b.smithyAt('back'), b.smithyTrail), (Rect.zero, 0), reason: '$tag: no Back on a page picked on the board');

      // A material's row: nothing.
      await tapOn(tester, await recipeRow(tester, b, Mat.bearClaw));
      expect((b.smithyTab, b.smithyItem, b.smithyTrail), (SmithyTab.items, Item.royalRing, 0), reason: tag);
      // The Gem Ring's row: its page, with Back.
      await tapOn(tester, await recipeRow(tester, b, Item.gemRing));
      expect((b.smithyTab, b.smithyItem, b.smithyTrail), (SmithyTab.items, Item.gemRing, 1), reason: tag);
      expect(b.smithyRows.map((r) => r.kind), contains(Item.ring), reason: '$tag: the Gem Ring\'s own recipe');
      // On again to the Ring, then Back twice.
      await tapOn(tester, await recipeRow(tester, b, Item.ring));
      expect((b.smithyItem, b.smithyTrail), (Item.ring, 2), reason: tag);
      await tapOn(tester, await seen(tester, b, 'back'));
      expect((b.smithyItem, b.smithyTrail), (Item.gemRing, 1), reason: tag);
      await tapOn(tester, await seen(tester, b, 'back'));
      expect((b.smithyTab, b.smithyItem, b.smithyTrail, b.smithyAt('back')), (SmithyTab.items, Item.royalRing, 0, Rect.zero), reason: tag);
      // A pick on the board drops the trail.
      await tapOn(tester, await recipeRow(tester, b, Item.gemRing));
      await pickItem(tester, b, Item.sword);
      expect((b.smithyTrail, b.smithyAt('back')), (0, Rect.zero), reason: '$tag: a board pick, no Back');

      // A relic's item: Cleave's Sword opens the Sword's page; Back to the Relics tab on Cleave.
      await tapOn(tester, b.smithyAt('tab:relics'));
      while (!b.smithyCells.any((c) => c.$1 == Relic.cleave)) {
        await tapOn(tester, b.smithyBoardPager('on'));
      }
      await tapOn(tester, b.smithyCells.firstWhere((c) => c.$1 == Relic.cleave).$2);
      await tapOn(tester, await recipeRow(tester, b, Item.sword));
      expect((b.smithyTab, b.smithyItem, b.smithyTrail), (SmithyTab.items, Item.sword, 1), reason: tag);
      await tapOn(tester, await seen(tester, b, 'back'));
      expect((b.smithyTab, b.smithyPick, b.smithyTrail), (SmithyTab.relics, Relic.cleave, 0), reason: tag);
      expect(g.wishlist, isEmpty, reason: 'a link wishes nothing');
      b.state = Game();
      await frames(tester, 5);
    });

    testWidgets('the Wishlist tab at $tag: a row\'s part the Smithy makes opens its page, Back returns to the tab; the '
        '"Ingredients" group\'s rows are for a product, never a troop: no Give anywhere, Craft says only "crafted"; ✕ and '
        'Remove leave their parents', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = townGame();
      g
        ..wish('knight', Item.royalRing)
        ..wish('archer', Item.royalRing)
        ..wishFreeAdd(Relic.cleave);
      g.inventory[Item.gemRing] = 1; // the Bag holds one: a type's row would offer Give for it
      await frames(tester, 40);
      await shutMessage(tester, b);
      expect(b.smithyTab, SmithyTab.wishlist);
      expect(b.smithyText('wishLines')!.split('|'),
          ['knight:royalRing ×1', 'archer:royalRing ×1', 'free:cleave ×1', 'parts:gemRing ×1', 'parts:ring ×1', 'parts:sword ×1']);
      expect(b.smithyText('wishType:parts'), Words.ingredients, reason: tag);
      expect([for (final (gr, _) in b.smithyWishHeads) gr].toSet(), containsAll(['knight', 'archer', 'free']));

      // The rows: "for Royal Ring", parts, status, Craft; no Give, no troop's name.
      Future<void> onRow(String key) async {
        while (b.smithyAt('wishRow:$key') == Rect.zero && b.smithyWishPage < b.smithyWishPages - 1) {
          await tapOn(tester, b.smithyWishPager('on'));
        }
        expect(b.smithyAt('wishRow:$key'), isNot(Rect.zero), reason: '$tag $key shown');
      }

      for (final (key, product) in [('parts:gemRing', 'Royal Ring'), ('parts:ring', 'Gem Ring'), ('parts:sword', 'Cleave')]) {
        await onRow(key);
        final words = rowWords(b, key);
        expect(b.smithyText('wishTitle:$key'), anyOf(endsWith('for $product'), isNot(contains('for'))), reason: '$tag $key: $words');
        expect((b.smithyAt('wishGive:$key'), b.smithyText('wishGive:$key')), (Rect.zero, null), reason: '$tag $key: no Give');
        expect(words, isNot(contains(Words.give)), reason: '$tag $key: no give words: $words');
        for (final t in troopTypes.keys) {
          expect(words, isNot(contains(troopTypeNames[t]!)), reason: '$tag $key: no troop: $words');
        }
        expect(b.smithyAt('wishCraft:$key'), isNot(Rect.zero), reason: '$tag $key: Craft');
        expect(b.smithyAt('wishOff:$key'), isNot(Rect.zero), reason: '$tag $key: ✕');
      }
      expect(b.smithyText('wishTitle:parts:gemRing'), anyOf('Gem Ring ×1 for Royal Ring', 'Gem Ring ×1'), reason: tag);
      expect(b.smithyText('wishParts:parts:gemRing'), 'tealGem 0/1,wolfFang 0/1,ring 0/1,gold 600', reason: tag);

      // A part the Smithy makes opens its page; Back returns to the tab on the same spread.
      while (b.smithyWishPage > 0) {
        await tapOn(tester, b.smithyWishPager('back'));
      }
      final part = b.smithyAt('wishPart:knight:royalRing:gemRing');
      expect(part, isNot(Rect.zero), reason: '$tag: the Royal Ring\'s Gem Ring part');
      // A material part opens nothing.
      await tapOn(tester, b.smithyAt('wishPart:knight:royalRing:bearClaw'));
      expect((b.smithyTab, b.smithyTrail), (SmithyTab.wishlist, 0), reason: tag);
      await shutMessage(tester, b);
      await tapOn(tester, part);
      expect((b.smithyTab, b.smithyItem, b.smithyTrail), (SmithyTab.items, Item.gemRing, 1), reason: tag);
      // Kept for the Royal Ring: no Give row on its page, "Needed for Royal Ring" instead.
      final kept = await seen(tester, b, 'kept');
      expect(kept, isNot(Rect.zero), reason: tag);
      expect((b.smithyText('kept'), b.smithyAt('give')), ('${Words.neededFor} Royal Ring', Rect.zero), reason: tag);
      await tapOn(tester, await seen(tester, b, 'back'));
      expect((b.smithyTab, b.smithyTrail, b.smithyWishPage), (SmithyTab.wishlist, 0, 0), reason: tag);

      // Craft from an ingredient row: "crafted", no Give offered after it; the row met drops off, the Ring's goes with it
      // (its Gem Ring needs none now).
      giveMats(g, Item.gemRing);
      g.inventory[Item.ring] = 1;
      await frames(tester, 2);
      await onRow('parts:gemRing');
      await tapOn(tester, b.smithyAt('wishCraft:parts:gemRing'));
      expect(b.message, 'Gem Ring ${Words.crafted}!', reason: tag);
      expect(b.message, isNot(contains(Words.give)));
      await shutMessage(tester, b);
      expect(b.smithyText('wishLines')!.split('|'), ['knight:royalRing ×1', 'archer:royalRing ×1', 'free:cleave ×1', 'parts:sword ×1'], reason: tag);
      expect(g.inventory[Item.gemRing], 2, reason: 'in the Bag, kept for the Royal Rings');

      // Its ✕: the Sword's ingredient wish off, the Cleave stays.
      await onRow('parts:sword');
      await tapOn(tester, b.smithyAt('wishOff:parts:sword'));
      expect(b.message, 'Sword: off the ${Words.wishlist.toLowerCase()}', reason: tag);
      await shutMessage(tester, b);
      expect(g.freeWishes, [Relic.cleave], reason: tag);
      expect(g.wishParts.where((p) => p.kind == Item.sword), isEmpty, reason: tag);
      // The group's Remove (two taps): every ingredient wish, no parent.
      g.inventory[Item.gemRing] = 0;
      await frames(tester, 2);
      while (b.smithyAt('wishOffAll:parts') == Rect.zero && b.smithyWishPage < b.smithyWishPages - 1) {
        await tapOn(tester, b.smithyWishPager('on'));
      }
      await tapOn(tester, b.smithyAt('wishOffAll:parts'));
      expect(b.smithyText('wishOffAll:parts'), Words.sure, reason: tag);
      await tapOn(tester, b.smithyAt('wishOffAll:parts'));
      expect(b.message, '${Words.ingredients}: ${Words.wishlist.toLowerCase()} cleared', reason: tag);
      await shutMessage(tester, b);
      expect(g.wishParts, isEmpty, reason: tag);
      expect((g.wishesOf('knight'), g.wishesOf('archer'), g.freeWishes), ([Item.royalRing], [Item.royalRing], [Relic.cleave]), reason: tag);
      b.state = Game();
      await frames(tester, 5);
    });
  }
}
