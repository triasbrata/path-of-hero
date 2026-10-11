// The Wishlist on the book (decisions-log 282; lib/wishlist_look.dart, lib/smithy_page.dart; docs/ui-hud.md "The Smithy"
// and "Army"), booted TdGames with the Towns and the forge on. The Smithy at 1266x713, 1164x777, 915x412 and the
// owner's 1600x947: an item's page has no types' chips and no "Wishlist: <types>" line (decisions-log 303: until then a
// chip per type that can take it put it on that type's list or took it off), its free line, the recipe and Craft inside
// the page, in order; a wished item carries the star on the Items board and comes first in its grade and stands on the
// Wishlist tab (decisions-log 302, 303), the materials its recipe takes carry it in the Bag's Materials (their tooltip
// "Needed for your wishlist"), and its page says "Ready to craft" or what is missing; Give gives it to its one wishing type
// in a tap (decisions-log 300), or opens the Bag's chooser on the wished types. The Army detail at 1266x713 and 915x412:
// its Wishlist section, the picker by grade (a tap puts one on or off), the ✕ taking one off, a wish tapped outside a
// Town saying where it is made and what it lacks, the ▲ while the Bag pays for one; the Smithy's Wishlist tab shows the
// same list and takes a wish off it. Nothing crafts or gives by itself. One TdGame per test.
//
// Never let a wave be won or the game end here (the Board then saves).
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'page_scroll.dart';

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

/// Shuts the message window (it can lie over the cells).
Future<void> shutMessage(WidgetTester tester, Board b) async {
  if (b.messageBox != Rect.zero) await tapOn(tester, b.messageBox);
}

/// Picks [item] on the Smithy's Items board (its tab first: the Smithy opens on the Wishlist, decisions-log 302): the
/// pager turns to its page, then a tap on its cell.
Future<void> pickItem(WidgetTester tester, Board b, Item item) async {
  await shutMessage(tester, b);
  if (b.smithyTab != SmithyTab.items) await tapOn(tester, b.smithyAt('tab:items'), 'the Items tab');
  while (!b.smithyItemCells.any((c) => c.$1 == item) && b.smithyItemPage < b.smithyItemPages - 1) {
    await tapOn(tester, b.smithyItemPager('on'));
  }
  await tapOn(tester, b.smithyItemCells.firstWhere((c) => c.$1 == item).$2, '$item');
  expect(b.smithyItem, item);
}

/// The Items board's cells over all its pages, in order (its tab first; the pager turns them, back to the first after).
Future<List<Item>> boardOrder(WidgetTester tester, Board b) async {
  await shutMessage(tester, b);
  if (b.smithyTab != SmithyTab.items) await tapOn(tester, b.smithyAt('tab:items'), 'the Items tab');
  while (b.smithyItemPage > 0) {
    await tapOn(tester, b.smithyItemPager('back'));
  }
  final all = <Item>[];
  for (var p = 0; p < b.smithyItemPages; p++) {
    if (p > 0) await tapOn(tester, b.smithyItemPager('on'));
    all.addAll(b.smithyItemCells.map((c) => c.$1));
  }
  while (b.smithyItemPage > 0) {
    await tapOn(tester, b.smithyItemPager('back'));
  }
  return all;
}

/// [r] wholly inside [area].
bool inside(Rect r, Rect area) => r.left >= area.left - 0.5 && r.top >= area.top - 0.5 && r.right <= area.right + 0.5 && r.bottom <= area.bottom + 0.5;

const sizes = [Size(1266, 713), Size(1164, 777), Size(915, 412), Size(1600, 947)];

/// The Smithy's facing page scrolled until its part [key] shows ([scrolledTo]; it scrolls where it doesn't fit,
/// decisions-log 283), and that part there.
Future<Rect> seen(WidgetTester tester, Board b, String key) => scrolledTo(tester, b, 'smithy', () => b.smithyAt(key));

/// A board game after wave 20 with the Towns and the forge on: a soldier, a knight, an archer and a priest, 40,000 gold,
/// the Steel Sword's recipe once (Wolf Claw 2, Orc Ear 1) and the Prayer Beads' twice; [inTown]: in the Town before
/// wave 21.
Game forgeGame({bool inTown = true}) {
  final g = Game(Random(1), Random(2)).boardRules()
    ..townDice = Random(3)
    ..towns = true
    ..armyMax = null
    ..wave = 20
    ..gold = 40000;
  for (final type in ['soldier', 'knight', 'archer', 'priest']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  if (inTown) {
    g
      ..townAt = 21
      ..inTown = true;
  }
  g.materials.addAll({Mat.wolfClaw: 2, Mat.orcEar: 1, Mat.tealCloth: 4, Mat.batWing: 2});
  return g;
}

/// What a craft or a gift would change in [g], written out (each map in its keys' order, whatever order they came in).
String bags(Game g) {
  String sorted(Map<Object, Object?> m) => (m.entries.map((e) => '${e.key}: ${e.value}').toList()..sort()).join(', ');
  return '${sorted(g.materials)} | ${sorted(g.inventory)} | ${g.gold} | ${sorted(g.upgrades)} | ${sorted(g.relicBag)}';
}

/// The Army detail's [key] in the body's view: scrolled down a step at a time from the top until its bottom shows (or the
/// body is scrolled to its end).
Future<Rect> detailSeen(WidgetTester tester, Board b, String key) async {
  b.troopDetailScroll = 0;
  await frames(tester, 2);
  for (var i = 0; i < 80; i++) {
    final r = b.troopDetail(key);
    if (r != Rect.zero && r.bottom < b.troopDetailBody.bottom - 1) return r;
    final was = b.troopDetailScroll;
    b.troopDetailScroll = was + 16;
    await frames(tester, 2);
    if (b.troopDetailScroll == was) break; // at its end
  }
  final r = b.troopDetail(key);
  expect(r, isNot(Rect.zero), reason: key);
  return r;
}

void main() {
  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('the Smithy at $tag: an item\'s page has no types\' chips and no "Wishlist: <types>" (decisions-log 303); a '
        'wish put on from the Army: its star, its place first in its grade, "Ready to craft", its row on the Wishlist tab; it fits',
        (tester) async {
      final b = await boot(tester, size);
      final g = b.state = forgeGame();
      await frames(tester, 40);
      expect(b.bookPage, 'smithy');
      final before = bags(g);

      // Nothing wished: the board in Item order, no star anywhere.
      final plain = await boardOrder(tester, b);
      expect(plain, [for (final n in [1, 2, 3]) ...g.smithyItems(n)]);
      await pickItem(tester, b, Item.steelSword);
      // No types' chips and no "Wishlist: …" line, wished or not (the owner: "list trops dan whitelist disini di takeout
      // aja untuk page detail item yang mau di craft"): a type's wishes go on from the Army detail.
      void noChips(String why) {
        for (final type in troopTypes.keys) {
          expect(b.smithyAt('wish:$type'), Rect.zero, reason: '$tag $why: no $type chip');
        }
        expect((b.smithyText('wishlist'), b.smithyText('wishTypes'), b.smithyText('wishOn'), b.smithyAt('wishlist')), (null, null, null, Rect.zero),
            reason: '$tag $why');
      }

      noChips('unwished');
      expect(b.smithyText('wishMissing'), isNull, reason: '$tag: no status while unwished');
      // Each part inside the page, reached by its scroll where the page is short; down the page in order: the free line
      // under the grade line, over the Recipe.
      final down = <String, (double, double)>{}; // each part's top and bottom down what the page holds
      for (final key in ['freeAdd', 'recipe', 'craft']) {
        final r = await seen(tester, b, key), page = b.bookPages.$2; // the book bobs: this frame's page
        expect(r != Rect.zero && inside(r, page) && inside(r, b.pageScrollView('smithy')), isTrue, reason: '$tag $key $r in $page');
        final y = b.pageScroll('smithy') - b.pageScrollView('smithy').top;
        down[key] = (r.top + y, r.bottom + y);
      }
      expect(down['freeAdd']!.$2 <= down['recipe']!.$1 && down['recipe']!.$2 <= down['craft']!.$1, isTrue, reason: '$tag: $down');
      expect(b.smithyItemMarks(Item.steelSword)!.wished, isFalse);

      // On the knight's list (the Army detail's way): the board's star, first in grade II, "Ready to craft"; no chips still.
      expect(g.wish('knight', Item.steelSword), isTrue);
      await frames(tester, 2);
      noChips('wished');
      // Never left out: on a short page reached by its scroll (decisions-log 283).
      expect(b.smithyText('wishMissing'), Words.readyToCraft, reason: '$tag: the Bag pays for one');
      final missing = await seen(tester, b, 'wishMissing');
      expect(missing != Rect.zero && inside(missing, b.bookPages.$2), isTrue, reason: '$tag $missing');
      expect(b.smithyItemMarks(Item.steelSword)!.wished, isTrue);
      for (final (item, _) in b.smithyItemCells) {
        if (item != Item.steelSword) expect(b.smithyItemMarks(item)!.wished, isFalse, reason: '$item');
      }
      final order = await boardOrder(tester, b);
      expect(order, [...g.smithyItems(1), Item.steelSword, ...g.smithyItems(2).where((i) => i != Item.steelSword), ...g.smithyItems(3)]);
      expect(b.smithyItem, Item.steelSword, reason: 'the pick stays');
      // The Wishlist tab lists it under the knight (decisions-log 303): one row, "×1"; the Items tab's pick kept.
      await tapOn(tester, b.smithyAt('tab:wishlist'));
      expect(b.smithyText('wishLines'), 'knight:steelSword ×1', reason: tag);
      final row = b.smithyAt('wishRow:knight:steelSword');
      expect(row != Rect.zero && inside(row, b.bookPages.$1), isTrue, reason: '$tag $row on the left page');
      await tapOn(tester, b.smithyAt('tab:items'));
      expect(b.smithyItem, Item.steelSword, reason: 'the pick kept');

      // Off it: no star, no status.
      g.unwish('knight', Item.steelSword);
      await pickItem(tester, b, Item.steelSword); // its page again (the board stayed on the first)
      expect((b.smithyItemMarks(Item.steelSword)!.wished, b.smithyText('wishMissing')), (false, null));
      expect(bags(g), before, reason: '$tag: a wish crafts nothing');
      b.state = Game();
      await frames(tester, 5);
    });
  }

  testWidgets('the Smithy: what a wish lacks, the materials\' tooltip, and Give: greyed with why for one type that can\'t take it '
      'yet, the chooser on the wished types for two', (tester) async {
    final b = await boot(tester);
    final g = b.state = forgeGame()..materials.remove(Mat.orcEar);
    g.wish('archer', Item.steelSword);
    await frames(tester, 40);
    await pickItem(tester, b, Item.steelSword);
    expect(b.smithyText('wishMissing'), 'Missing: ${Mat.orcEar.label} 0/1');
    // The Wolf Claw's tooltip says a wish takes it (the Bag's Materials: the Smithy's went, decisions-log 302).
    await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2, 'the Bag');
    await tapOn(tester, b.bagChip(BagCategory.materials));
    final claw = b.bagCells.firstWhere((c) => c.$1 == Mat.wolfClaw).$2;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(claw.center);
    await frames(tester, 40);
    expect(b.tooltipShown?.$1, Mat.wolfClaw.label);
    expect(b.tooltipShown!.$2.last, Words.neededForWishlist);
    // Off it, so no tooltip stays up (a tap while one shows is taken for a long press).
    await mouse.moveTo(const Offset(2, 2));
    await frames(tester, 10);
    await mouse.removePointer();
    await frames(tester, 10);
    expect(b.tooltipShown, isNull);
    await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'smithy').$2, 'the Smithy');
    await pickItem(tester, b, Item.steelSword); // the book's turn let the pick go

    // Crafted: one type wishes for it, so Give is "Give to Archer" (decisions-log 300); grade II doesn't open before
    // Awaken 1, so it is greyed with why, and a tap says it.
    g.materials[Mat.orcEar] = 1;
    await frames(tester, 2);
    expect(b.smithyText('wishMissing'), Words.readyToCraft);
    await tapOn(tester, await seen(tester, b, 'craft'));
    await shutMessage(tester, b);
    expect(g.inventory[Item.steelSword], 1);
    expect(b.bagDetailText('title:giveTroops'), '${Words.give} to Archer');
    expect(b.bagDetailText('hint:giveTroops'), g.itemRefusal(Item.steelSword, 'archer', g.whyNot(Item.steelSword, 'archer')!));
    await tapOn(tester, await seen(tester, b, 'give'));
    expect((b.bookPage, b.message), ('smithy', g.itemRefusal(Item.steelSword, 'archer', g.whyNot(Item.steelSword, 'archer')!)));
    await shutMessage(tester, b);
    expect(g.upgrades['archer'], isNull);
    // Two types wish for it: Give's line names both, and its tap opens the chooser on them (All shows the rest).
    g.wish('knight', Item.steelSword);
    await frames(tester, 2);
    expect(b.bagDetailText('hint:giveTroops'), '1 in ${Words.bag}. For Knight, Archer');
    await tapOn(tester, await seen(tester, b, 'give'));
    expect((b.bookPage, b.picked, b.bagChooser), ('bag', Item.steelSword, BagAction.giveTroops));
    expect(b.assignFilter, {'knight', 'archer'});
    expect((g.upgrades['archer'], g.upgrades['knight']), (null, null), reason: 'giving stays a tap');
    b.state = Game();
    await frames(tester, 5);
  });

  for (final size in [const Size(1266, 713), const Size(915, 412)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('the Army detail at $tag: the Wishlist section, its picker by grade, the ✕, a wish tapped outside a Town; '
        'the Smithy\'s Wishlist tab shows the same list and takes one off', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = forgeGame(inTown: false);
      await frames(tester, 40);
      await tapOn(tester, b.troopRow('knight'));
      expect((b.bookPage, b.troopPicked), ('troops', 'knight'));
      final (_, right) = b.bookPages;
      final before = bags(g);

      // Nothing on it: the heading, "No items yet" and the tag that opens the picker.
      await detailSeen(tester, b, 'wishlist');
      expect(b.troopDetailWords('wishlist'), [Words.wishlist, 'No items yet']);
      final add = await detailSeen(tester, b, 'wishEdit');
      expect(b.troopDetailWords('wishEdit').single, anyOf(Words.addToWishlist, 'Add'));
      await tapOn(tester, add);
      expect(b.troopDetailWords('wishEdit').single, Words.done);
      // The picker: the knight's products by grade, each grade under its heading.
      expect(b.troopDetailWords('wishPicker'), [for (final n in [1, 2, 3]) gradeTitle(n)]);
      for (final item in g.wishable('knight')) {
        final r = await detailSeen(tester, b, 'pick:${item.name}');
        expect(inside(r, right), isTrue, reason: '$tag $item $r in $right');
      }
      expect(b.troopDetail('pick:bow'), Rect.zero, reason: 'not the knight\'s');

      // A tap puts one on, another tap takes it off; a second one stays.
      await tapOn(tester, await detailSeen(tester, b, 'pick:steelSword'));
      expect(b.message, 'Steel Sword: on Knight\'s ${Words.wishlist.toLowerCase()}');
      await shutMessage(tester, b);
      await tapOn(tester, await detailSeen(tester, b, 'pick:royalHelm'));
      await shutMessage(tester, b);
      expect(g.wishesOf('knight'), [Item.steelSword, Item.royalHelm]);
      await tapOn(tester, await detailSeen(tester, b, 'pick:royalHelm'));
      await shutMessage(tester, b);
      expect(g.wishesOf('knight'), [Item.steelSword]);
      // The row's ✕ (the picker open) takes one off too.
      await tapOn(tester, await detailSeen(tester, b, 'pick:leatherCap'));
      await shutMessage(tester, b);
      await tapOn(tester, await detailSeen(tester, b, 'wish:leatherCap'));
      await shutMessage(tester, b);
      expect(g.wishesOf('knight'), [Item.steelSword]);
      await tapOn(tester, await detailSeen(tester, b, 'wishEdit'));
      expect(b.troopDetail('pick:steelSword'), Rect.zero, reason: 'Done: the picker closes');

      // The wish: the ▲ while the Bag pays for one; a tap outside a Town says where and what.
      final wish = await detailSeen(tester, b, 'wish:steelSword');
      expect(inside(wish, right), isTrue, reason: tag);
      expect(b.troopDetailWords('wishReady'), [itemNames[Item.steelSword]]);
      await tapOn(tester, wish);
      expect(b.message, '${Words.craftInTown}\nSteel Sword: ${Words.readyToCraft}');
      expect(b.bookPage, 'troops');
      await shutMessage(tester, b);
      g.materials.remove(Mat.wolfClaw);
      await tapOn(tester, await detailSeen(tester, b, 'wish:steelSword'));
      expect(b.message, '${Words.craftInTown}\nSteel Sword: Need 2 Wolf Claw');
      expect(b.troopDetailWords('wishReady'), isEmpty);
      await shutMessage(tester, b);
      g.materials[Mat.wolfClaw] = 2;

      // Another type's detail shows its own, closed.
      await tapOn(tester, b.troopRow('archer'));
      await detailSeen(tester, b, 'wishlist');
      expect(b.troopDetailWords('wishlist'), [Words.wishlist, 'No items yet']);

      // The same list on the Smithy's Wishlist tab (decisions-log 303): in a Town the knight's wish is its row there (no
      // chips on the item's page), and its ✕ there takes it off here too.
      g
        ..townAt = 21
        ..inTown = true;
      await frames(tester, 40);
      expect((b.bookPage, b.smithyTab), ('smithy', SmithyTab.wishlist));
      expect(b.smithyText('wishLines'), 'knight:steelSword ×1');
      await pickItem(tester, b, Item.steelSword);
      expect((b.smithyAt('wish:knight'), b.smithyAt('wish:archer')), (Rect.zero, Rect.zero), reason: '$tag: no chips');
      await tapOn(tester, b.smithyAt('tab:wishlist'));
      await tapOn(tester, b.smithyAt('wishOff:knight:steelSword'));
      expect(b.message, 'Steel Sword: off Knight\'s ${Words.wishlist.toLowerCase()}');
      await shutMessage(tester, b);
      g.leaveTown();
      await frames(tester, 40);
      expect(b.bookPage, 'troops');
      await tapOn(tester, b.troopRow('knight'));
      await detailSeen(tester, b, 'wishlist');
      expect(b.troopDetailWords('wishlist'), [Words.wishlist, 'No items yet']);
      expect(g.wishlist, isEmpty);
      expect(bags(g), before, reason: '$tag: a wish crafts and gives nothing');
      b.state = Game();
      await frames(tester, 5);
    });
  }

  testWidgets('the Towns off (tests only): no Wishlist on the Army detail', (tester) async {
    final b = await boot(tester);
    b.state = forgeGame(inTown: false)..towns = false;
    await frames(tester, 40);
    await tapOn(tester, b.troopRow('knight'));
    for (var i = 0; i < 30; i++) {
      b.troopDetailScroll = 20.0 * i;
      await frames(tester, 2);
      expect(b.troopDetail('wishlist'), Rect.zero, reason: 'scrolled ${20 * i}');
      expect(b.troopDetailWords('wishlist'), isEmpty, reason: 'scrolled ${20 * i}');
    }
    b.state = Game();
    await frames(tester, 5);
  });
}
