// The forge's Smithy strip and boards (decisions-log 254 and 277; ui-hud.md "The Smithy"; forge-design §11-13, mockups
// 12 and 15), booted TdGames in a Town with the Towns and the forge on, at 1266x713, 1164x777, 915x412 and the
// owner's 1600x947: under "Smithy" the strip Wishlist | Items | Relics | Enhance (decisions-log 302: the Smithy first
// opens on the Wishlist, its tab smithy_wish_ui_test.dart's), Enhance greyed before wave 30 is won (a tap says "Opens
// after wave 30"; once open a tap turns to it, its board and page forge_enhance_ui_test.dart's); the Items tab with no
// grade strip: every grade's 14 items at once in [Item] order, a section per grade under its "Grade I" heading (its words
// from the board's leftmost slot), paged together by the pager and the wheel where they don't fit, opening on the pick's
// page (the ▲ on one that can be crafted, faded when not, the pick lit), the whole page under the strip with no
// materials under it (decisions-log 302; the rows and pages at each size pinned), the item's facing page (its grade line,
// recipe, Craft, the Give row) all inside the book; nothing on the left page moving against the rest while the book bobs
// (the materials' rows and pager blinked at 1600x947); a craft by a tap ("Steel Sword crafted!"), refused with why; the
// Cap's grade II taking a Leather Cap; Give opening the Bag on the item's types; the Relics tab's 20 relics as before, its
// board at the small slot where the Bag's would page it. The rules: town_craft_test.dart, forge_awaken_test.dart; the
// Smithy's other pages: town_smithy_ui_test.dart. One TdGame per test.
//
// Never let a wave be won or the game end here (the Board then saves).
import 'dart:math';
import 'dart:ui' show PointerDeviceKind;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'bag_pages.dart';
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

/// Shuts the message window (it can lie over the tabs or the cells).
Future<void> shutMessage(WidgetTester tester, Board b) async {
  if (b.messageBox != Rect.zero) await tapOn(tester, b.messageBox);
}

/// Turns the open book to [page] by its tab.
Future<void> turnTo(WidgetTester tester, Board b, String page) async {
  await shutMessage(tester, b);
  await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == page).$2, page);
}

/// Taps the Smithy's segment [key] ('tab:relics').
Future<void> segment(WidgetTester tester, Board b, String key) async {
  await shutMessage(tester, b);
  await tapOn(tester, b.smithyAt(key), key);
}

/// The Items board's pages, from the first: each page's cells in order, its grade headings drawn and where they are. The
/// pager turns them (and back to the first after).
Future<List<({List<(Item, Rect)> cells, String heads, List<Rect> at})>> itemPages(WidgetTester tester, Board b) async {
  await shutMessage(tester, b);
  while (b.smithyItemPage > 0) {
    await tapOn(tester, b.smithyItemPager('back'));
  }
  final pages = <({List<(Item, Rect)> cells, String heads, List<Rect> at})>[];
  for (var p = 0; p < b.smithyItemPages; p++) {
    if (p > 0) await tapOn(tester, b.smithyItemPager('on'));
    expect(b.smithyItemPage, p);
    pages.add((cells: b.smithyItemCells, heads: b.smithyText('grades')!, at: [for (final n in [1, 2, 3]) b.smithyAt('grade:$n')]));
  }
  while (b.smithyItemPage > 0) {
    await tapOn(tester, b.smithyItemPager('back'));
  }
  return pages;
}

/// Picks [item] on the Items board: the pager turns to its page, then a tap on its cell.
/// The Smithy's facing page scrolled until its part [key] shows ([scrolledTo]; it scrolls where it doesn't fit,
/// decisions-log 283), and that part there.
Future<Rect> facing(WidgetTester tester, Board b, String key) => scrolledTo(tester, b, 'smithy', () => b.smithyAt(key));

Future<void> pickItem(WidgetTester tester, Board b, Item item) async {
  await shutMessage(tester, b);
  while (!b.smithyItemCells.any((c) => c.$1 == item) && b.smithyItemPage < b.smithyItemPages - 1) {
    await tapOn(tester, b.smithyItemPager('on'));
  }
  await tapOn(tester, b.smithyItemCells.firstWhere((c) => c.$1 == item).$2, '$item');
  expect(b.smithyItem, item);
}

/// The left page's layout this frame, every place from the board's first cell (the Wishlist tab's first row's;
/// decisions-log 302, 303) (the book bobs; nothing in it may move): the board's cells, the Wishlist tab's rows on both
/// pages and its groups' first headings, the pagers, the headings, and the page sizes.
String leftLayout(Board b) {
  final board = [...b.smithyItemCells.map((c) => c.$2), ...b.smithyCells.map((c) => c.$2), ...b.smithyWishCells.map((c) => c.$3)];
  final o = board.first.topLeft;
  String at(Rect r) => r == Rect.zero ? '-' : '${r.shift(-o)}';
  return [
    for (final r in board) at(r),
    '| wishes ${b.smithyWishPages} ${at(b.smithyWishPager('back'))} ${at(b.smithyWishPager('on'))} ${at(b.smithyAt('wishHead'))} ${at(b.smithyAt('add'))}',
    for (final t in ['knight', 'archer', 'priest']) at(b.smithyAt('wishType:$t')),
    '| items ${b.smithyItemPages} ${at(b.smithyItemPager('back'))} ${at(b.smithyItemPager('on'))}',
    '| board ${b.smithyBoardPages} ${at(b.smithyBoardPager('back'))} ${at(b.smithyBoardPager('on'))}',
    '| heads ${[for (final n in [1, 2, 3]) at(b.smithyAt('grade:$n'))]} small ${b.smithySmallBoard}',
  ].join(' ');
}

/// [r] wholly inside [area].
bool inside(Rect r, Rect area) => r.left >= area.left - 0.5 && r.top >= area.top - 0.5 && r.right <= area.right + 0.5 && r.bottom <= area.bottom + 0.5;

const sizes = [Size(1266, 713), Size(1164, 777), Size(915, 412), Size(1600, 947)];

/// A board game after wave [wave] with the Towns and the forge on, in the Town before the next: a soldier, a knight, an
/// archer and a priest (none holding an item: each still needs grade I), 40,000 gold, the Prayer Beads' recipe twice over
/// and the Steel Sword's once (in grade I nothing else craftable; in grade II the Arcane Prism too, after it).
Game forgeGame({int wave = 20}) {
  final g = Game(Random(1), Random(2)).boardRules()
    ..townDice = Random(3)
    ..armyMax = null
    ..wave = wave;
  for (final type in ['soldier', 'knight', 'archer', 'priest']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g
    ..gold = 40000
    ..townAt = wave + 1
    ..inTown = true;
  giveRecipe(g, Item.prayerBeads, 2);
  giveRecipe(g, Item.steelSword);
  return g;
}

/// Puts [item]'s recipe [times] over in [g]'s bag: its materials and items (not its gold).
void giveRecipe(Game g, Item item, [int times = 1]) {
  final r = g.itemRecipe(item)!;
  for (final MapEntry(key: m, value: n) in r.materials.entries) {
    g.materials[m] = (g.materials[m] ?? 0) + n * times;
  }
  for (final MapEntry(key: i, value: n) in r.items.entries) {
    g.inventory[i] = (g.inventory[i] ?? 0) + n * times;
  }
}

/// What a craft may change in [g], written out: the materials, items, gold and the relic bag.
String bags(Game g) => '${g.materials} ${g.inventory} ${g.gold} ${g.relicBag}';

/// The grade's items in [Item] order.
List<Item> gradeItems(int grade) => [for (final i in Item.values) if (i.grade == grade) i];

/// Gives [g] [kinds] kinds of the dropped materials, 1 to 13 of each.
void giveMats(Game g, int kinds) {
  for (final (i, m) in Mat.values.where((m) => !m.crafted).take(kinds).indexed) {
    g.materials[m] = 1 + i * 5 % 13;
  }
}

void main() {
  test('every grade has 14 items, the Cap and the Ring last', () {
    for (final grade in [1, 2, 3]) {
      expect(gradeItems(grade), hasLength(14), reason: 'grade $grade');
      expect(gradeItems(grade).skip(12).map((i) => i.slot), [ItemSlot.helm, ItemSlot.ring]);
    }
  });

  test('Enhance opens once wave 30 is won; the grade line says what a grade is for', () {
    final g = forgeGame();
    expect((g.townRules.enhance.from, g.enhanceOpen, enhanceLocked(g)), (30, false, 'Opens after wave 30'));
    g.wave = 30;
    expect(g.enhanceOpen, isTrue, reason: 'in the Town after wave 30');
    expect(smithyGradeLine(g, Item.steelSword), 'Grade II: for ${Words.awaken} 2 (Soldier 2, Knight 3, Archer 2).');
    expect(smithyGradeLine(g, Item.prayerBeads), 'Grade I: for ${Words.awaken} 1 (Priest 2).');
    expect(smithyGradeLine(g, Item.prism), 'Grade I: for ${Words.awaken} 1. No type here takes it.');
    expect(smithyGradeLine(g, Item.steelHelm), startsWith('Grade II: not for ${Words.awaken}.'));
  });

  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('the forge Smithy at $tag: the strip, Enhance greyed, every grade\'s items by grade with no grade strip, the '
        'item page; it fits', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = forgeGame();
      await frames(tester, 40);
      expect(b.bookPage, 'smithy');
      final book = b.bookArea;
      final (left, _) = b.bookPages;

      // The strip: Wishlist | Items | Relics | Enhance across the left page, under the title, the Smithy on the Wishlist
      // (decisions-log 302); Enhance greyed (wave 20).
      expect((b.smithyTab, b.smithyText('tabs'), b.smithyText('locked')), (SmithyTab.wishlist, 'Wishlist|Items|Relics|Enhance', 'enhance'));
      final tabs = [for (final t in SmithyTab.values) b.smithyAt('tab:${t.name}')];
      for (final (i, r) in tabs.indexed) {
        expect(inside(r, left), isTrue, reason: '$tag tab $i: $r on the left page $left');
        if (i > 0) expect(r.left, closeTo(tabs[i - 1].right, 0.5), reason: '$tag: one strip');
      }
      await segment(tester, b, 'tab:items');
      expect(b.smithyTab, SmithyTab.items);

      // The board right under the strip, no grade strip: every grade's 14 items in Item order, a section per grade under
      // its heading, the headings' words from the board's leftmost slot; paged together where they don't all fit, the
      // first page the pick's (grade I: none holds an item). The Prayer Beads (grade I's only craftable) picked and lit.
      expect(b.smithyItem, Item.prayerBeads);
      expect([for (final (item, _) in b.smithyItemCells) item], contains(Item.prayerBeads), reason: '$tag: on the pick\'s page');
      final pages = await itemPages(tester, b);
      expect([for (final p in pages) ...p.cells.map((c) => c.$1)], [...gradeItems(1), ...gradeItems(2), ...gradeItems(3)]);
      // Grade I first; a grade going on to the next page starts it with its heading again.
      expect(pages.first.heads.split('|').first, 'Grade I', reason: '$tag: ${pages.first.heads}');
      for (final (p, page) in pages.indexed) {
        final grades = {for (final (item, _) in page.cells) item.grade};
        expect(page.heads, [for (final n in grades) gradeTitle(n)].join('|'), reason: '$tag page $p: a heading for each grade on it');
      }
      final strip = tabs.first.bottom;
      for (final (p, page) in pages.indexed) {
        if (page.cells.isEmpty) continue; // a page of the Pocket section's alone, after the grades' (decisions-log 332)
        final x0 = page.cells.map((c) => c.$2.left).reduce(min);
        for (final (item, r) in page.cells) {
          expect(inside(r, left) && r.top >= strip, isTrue, reason: '$tag page $p $item: $r under the strip, on the page');
          // Each cell under its grade's heading on its page.
          final head = page.at[item.grade - 1];
          expect(head != Rect.zero && head.bottom <= r.top, isTrue, reason: '$tag page $p $item: under "${gradeTitle(item.grade)}" $head');
        }
        for (final h in page.at.where((h) => h != Rect.zero)) {
          expect(h.left, closeTo(x0, 0.01), reason: '$tag page $p: a heading from the leftmost slot');
          expect(h.top, greaterThanOrEqualTo(strip), reason: '$tag page $p: under the strip');
        }
        // Grades in order down the page, each heading over its own rows only.
        final tops = [for (final h in page.at) if (h != Rect.zero) h.top];
        expect(tops, [...tops]..sort(), reason: '$tag page $p');
      }
      if (pages.length > 1) {
        final on = b.smithyItemPager('on');
        expect(inside(on, left), isTrue, reason: '$tag: the Items pager $on on the page');
      } else {
        expect(b.smithyItemPager('on'), Rect.zero, reason: '$tag: one page, no pager');
      }
      expect((g.canCraftItem(Item.prayerBeads), g.canCraftItem(Item.steelSword)), (true, true));
      for (final (item, _) in b.smithyItemCells) {
        final m = b.smithyItemMarks(item)!, can = g.canCraftItem(item);
        expect((m.ready, m.faded, m.lit), (can, !can, item == Item.prayerBeads), reason: '$item');
        expect(m.count, null, reason: '$item: none in the Bag');
      }

      // Nothing under the board (decisions-log 302): no materials and no Wishlist on this tab (the recipe rows say what an
      // item takes; the Wishlist has its own tab).
      final beads = g.itemRecipe(Item.prayerBeads)!.materials;
      expect((b.smithyAt('kinds'), b.smithyAt('wishHead')), (Rect.zero, Rect.zero), reason: tag);
      expect([...b.bagCells, ...b.bagSlots, ...b.smithyWishCells], isEmpty, reason: tag);

      // The facing page: the Prayer Beads' heading, effect, grade line, recipe rows, Craft, then Give; on a short page each
      // reached by its scroll (decisions-log 283), inside the page, down it in order.
      expect((b.bagDetailText('name'), b.bagDetailText('count')), ('Prayer Beads', 'x0'));
      expect(b.smithyText('effect')!.replaceAll('\n', ' '), '${g.itemEffect(Item.prayerBeads).first} for one troop type.');
      expect(b.smithyText('tier')!.replaceAll('\n', ' '), 'Grade I: for ${Words.awaken} 1 (Priest 2).');
      final rows = b.smithyRows;
      expect([for (final r in rows) r.kind], [...beads.keys, null]);
      expect(rows.last.count, '40,000 / 20');
      var above = 0.0;
      for (var i = 0; i < rows.length; i++) {
        final r = await scrolledDown(tester, b, 'smithy', () => b.smithyRows[i].at), page = b.bookPages.$2;
        expect(r.at != Rect.zero && inside(r.at, page) && !rows[i].short && r.top >= above - 0.5, isTrue,
            reason: '$tag ${rows[i].kind}: ${r.at} on the right page $page, under the one above');
        above = r.bottom;
      }
      final craft = await scrolledDown(tester, b, 'smithy', () => b.smithyAt('craft'));
      expect(craft.at != Rect.zero && inside(craft.at, b.bookPages.$2) && craft.top >= above, isTrue, reason: '$tag: Craft ${craft.at}');
      expect(b.smithyText('craft'), 'Craft (20 gold)');
      final give = await scrolledDown(tester, b, 'smithy', () => b.smithyAt('give'));
      expect(give.at != Rect.zero && inside(give.at, b.bookPages.$2) && give.top >= craft.bottom, isTrue, reason: '$tag: Give ${give.at}');
      expect(b.bagDetailText('title:giveTroops'), '${Words.give} to troops');
      expect(b.bagActions.firstWhere((a) => a.$1 == BagAction.giveTroops).$3, isFalse, reason: 'none in the Bag');
      expect(inside(left, book), isTrue);

      // A grade II item picked from its section: its page stays, the grade line its own.
      await pickItem(tester, b, Item.steelSword);
      final swordPage = b.smithyItemPage;
      expect(swordPage, pages.indexWhere((p) => p.cells.any((c) => c.$1 == Item.steelSword)));
      expect(b.smithyText('tier')!.replaceAll('\n', ' '), smithyGradeLine(g, Item.steelSword));
      expect(b.smithyText('craft'), 'Craft (60 gold)');
      expect(b.smithyItemMarks(Item.steelSword)!.lit, isTrue);

      // The Relics tab: every small relic in play (20 with the forge) in tier order, no grade headings.
      await segment(tester, b, 'tab:relics');
      expect(b.smithyTab, SmithyTab.relics);
      expect(b.smithyAt('grade:1'), Rect.zero, reason: 'no grade headings on the Relics tab');
      expect(b.smithyItemCells, isEmpty, reason: 'no Items board on the Relics tab');
      // Paged where they don't all fit on the page (decisions-log 283: the landscape book shorter).
      final relicPages = await smithyBoardPages(tester, b);
      expect([for (final p in relicPages) for (final c in p.cells) c.$1], smithyRelics(g));
      expect(smithyRelics(g), hasLength(20));
      for (final (:cells, book: _, :left) in relicPages) {
        for (final (relic, r, _) in cells) {
          expect(inside(r, left), isTrue, reason: '$tag $relic: $r on the left page $left');
        }
      }
      final relicStrip = b.smithyAt('tab:relics').bottom; // this frame's: the book bobs
      expect(b.smithyCells.every((c) => c.$2.top >= relicStrip), isTrue, reason: '$tag: the board under the strip ($relicStrip)');
      expect([...b.bagSlots, ...b.bagCells], isEmpty, reason: '$tag: no materials under it (decisions-log 302)');
      expect(b.bagDetailText('name'), relicNames[b.smithyPick]);
      expect(b.smithyAt('give'), Rect.zero);
      await segment(tester, b, 'tab:items');
      expect((b.smithyItem, b.smithyItemPage), (Item.steelSword, swordPage), reason: 'the pick and its page kept');
      await frames(tester, 40);
    });

    testWidgets('at $tag nothing on the Smithy\'s left page moves against the rest while the book bobs (the materials\' rows '
        'and pager blinked)', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = forgeGame();
      giveMats(g, 27);
      for (final type in ['knight', 'archer', 'priest']) {
        g.wishSet(type); // the Wishlist tab's lines and pager (decisions-log 300, 302)
      }
      g.wishFreeAdd(smithyRelics(g).first, 2); // a free line (decisions-log 302)
      await frames(tester, 40);
      await shutMessage(tester, b);
      for (final tab in ['tab:wishlist', 'tab:items', 'tab:relics']) {
        await segment(tester, b, tab);
        await frames(tester, 4);
        final first = leftLayout(b), tops = <double>{};
        // A whole bob (3.93 s) at 160 ms a frame; the book moves, the page's layout in it doesn't.
        for (var i = 0; i < 25; i++) {
          await tester.pump(const Duration(milliseconds: 160));
          tops.add(b.bookArea.top);
          expect(leftLayout(b), first, reason: '$tag $tab, frame $i');
        }
        expect(tops.length, greaterThan(10), reason: '$tag: the book bobbed');
      }
      await frames(tester, 40);
    });
  }

  // The rows and pages of the boards with the materials out of every tab (decisions-log 302; the owner: "materials di
  // takeout dari semua tabs jadi list itemnya bisa lebih banyak"): each board takes the page under the strip, at the Bag's
  // slot unless that would page it (decisions-log 283's small slot). Until then (286) the materials kept two rows (one at
  // 1164x777's Items and 915x412) and the Items board had 2, 2, 2 and 1 rows a page, the Relics 2, 2, 2 and 3.
  for (final (size, items, itemPages, relics, relicPages) in const [
    (Size(1600, 947), 4, 3, 4, 1),
    (Size(1266, 713), 4, 3, 4, 1),
    (Size(1164, 777), 4, 3, 4, 1),
    (Size(915, 412), 3, 3, 3, 1), // the Pocket section after grade III its own page (decisions-log 332)
  ]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('at $tag with no materials the Items board shows $items rows a page over $itemPages page(s), the Relics $relics '
        'over $relicPages', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = forgeGame();
      giveMats(g, 26);
      await frames(tester, 40);
      await segment(tester, b, 'tab:items');
      int rows(Iterable<Rect> cells) => {for (final r in cells) r.top}.length;
      expect(b.smithyItemPage, 0);
      final got = <int>[rows([for (final (_, r) in b.smithyItemCells) r]), b.smithyItemPages];
      await segment(tester, b, 'tab:relics');
      expect(b.smithyBoardPage, 0);
      got.addAll([rows([for (final (_, r) in b.smithyCells) r]), b.smithyBoardPages]);
      expect(got, [items, itemPages, relics, relicPages], reason: '$tag: the Items board\'s rows a page and pages, the Relics\'');
      await frames(tester, 40);
    });
  }

  testWidgets('the Items board\'s pages: its pager and the wheel over it turn them, a notch a page, the pick kept', (tester) async {
    final b = await boot(tester);
    final g = b.state = forgeGame();
    giveMats(g, 27);
    await frames(tester, 40);
    await segment(tester, b, 'tab:items');
    expect(b.smithyItemPages, greaterThan(1), reason: 'the desk takes pages: every grade\'s 42');
    expect((b.smithyItemPage, b.smithyItemPager('back') != Rect.zero), (0, true));
    final first = b.smithyItemCells.first.$1, pick = b.smithyItem;
    expect(b.smithyItemCells.any((c) => c.$1 == pick), isTrue, reason: 'it opens on the pick\'s page');
    await tapOn(tester, b.smithyItemPager('on'));
    expect((b.smithyItemPage, b.smithyItem), (1, pick), reason: 'the pick stays off its page');
    expect(b.smithyItemCells.any((c) => c.$1 == first), isFalse);
    await tapOn(tester, b.smithyItemPager('back'));
    expect(b.smithyItemPage, 0);

    final wheel = TestPointer(9, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(wheel.hover(b.smithyItemCells.first.$2.center));
    await tester.sendEventToBinding(wheel.scroll(const Offset(0, 40)));
    await frames(tester, 20);
    expect(b.smithyItemPage, 1, reason: 'a notch over the board turns its page');
    await tester.sendEventToBinding(wheel.scroll(const Offset(0, -40)));
    await frames(tester, 20);
    expect(b.smithyItemPage, 0);
    await tester.sendEventToBinding(wheel.hover(b.bookArea.topLeft));
    await frames(tester, 40);
  });

  testWidgets('Enhance: greyed before wave 30 (a tap says when it opens, the tab stays); at wave 30 not greyed, a tap turns '
      'to it', (tester) async {
    final b = await boot(tester);
    b.state = forgeGame();
    await frames(tester, 40);
    await segment(tester, b, 'tab:enhance');
    expect((b.message, b.smithyTab, b.bookPage), ('Opens after wave 30', SmithyTab.wishlist, 'smithy'));
    await segment(tester, b, 'tab:relics');
    await segment(tester, b, 'tab:enhance');
    expect((b.message, b.smithyTab), ('Opens after wave 30', SmithyTab.relics));

    b.state = forgeGame(wave: 30);
    await frames(tester, 40);
    await shutMessage(tester, b);
    expect(b.smithyText('locked'), '');
    await segment(tester, b, 'tab:enhance');
    expect((b.message, b.smithyTab), (null, SmithyTab.enhance));
    await frames(tester, 40);
  });

  testWidgets('a craft by a tap: one into the Bag, its recipe and gold taken, "Steel Sword crafted!"; then refused with why',
      (tester) async {
    final b = await boot(tester);
    final g = b.state = forgeGame();
    await frames(tester, 40);
    await segment(tester, b, 'tab:items');
    await pickItem(tester, b, Item.steelSword);
    await tapOn(tester, await facing(tester, b, 'craft'));
    expect((g.inventory[Item.steelSword], g.gold, g.materials[Mat.wolfClaw], g.materials[Mat.orcEar]), (1, 39940, null, null));
    expect(b.message, 'Steel Sword crafted!');
    expect((b.bagDetailText('count'), b.smithyItemMarks(Item.steelSword)?.count), ('x1', 1));
    expect(b.smithyItemMarks(Item.steelSword)!.faded, isTrue, reason: 'nothing left to make another');
    expect(b.smithyText('craft'), 'Need 2 Wolf Claw');
    await shutMessage(tester, b);
    final before = bags(g);
    await tapOn(tester, await facing(tester, b, 'craft'));
    expect((b.message, bags(g)), ('Need 2 Wolf Claw', before));
    await frames(tester, 40);
  });

  testWidgets("the Cap's grade II takes a Leather Cap (its row, short then held), and Give opens the Bag on the item's types",
      (tester) async {
    final b = await boot(tester);
    final g = b.state = forgeGame();
    giveRecipe(g, Item.steelHelm);
    g.inventory.remove(Item.leatherCap);
    await frames(tester, 40);
    await segment(tester, b, 'tab:items');
    await pickItem(tester, b, Item.steelHelm);
    final cap = b.smithyRows.firstWhere((r) => r.kind == Item.leatherCap);
    expect((cap.count, cap.short), ('0 / 1', true));
    expect(b.smithyText('craft'), 'Need 1 Leather Cap');

    g.inventory[Item.leatherCap] = 1;
    await frames(tester, 3);
    await tapOn(tester, await facing(tester, b, 'craft'));
    expect((g.inventory[Item.steelHelm], g.inventory[Item.leatherCap] ?? 0, b.message), (1, 0, 'Steel Helm crafted!'));
    await shutMessage(tester, b);
    expect(b.bagActions.firstWhere((a) => a.$1 == BagAction.giveTroops).$3, isTrue);
    expect(b.bagDetailText('hint:giveTroops'), '1 in ${Words.bag}. Opens the ${Words.bag}');
    await facing(tester, b, 'give');
    await tapOn(tester, b.bagAction(BagAction.giveTroops));
    expect((b.bookPage, b.picked, b.bagChooser), ('bag', Item.steelHelm, BagAction.giveTroops));
    await frames(tester, 40);
  });

  testWidgets('the ways in: a material\'s "Craft at the Smithy" lands on the Relics tab with its relic; the Items tab opens on '
      'its first pick\'s page again', (tester) async {
    final b = await boot(tester);
    final g = b.state = forgeGame();
    g.materials[Mat.slimeCore] = 1;
    await frames(tester, 40);
    expect(b.smithyTab, SmithyTab.wishlist, reason: 'the Smithy first opens on the Wishlist (decisions-log 302)');
    await segment(tester, b, 'tab:items');
    // A grade III item picked (the last page where they take more than one): it goes with the book's turn.
    await pickItem(tester, b, gradeItems(3).last);
    expect(b.smithyItemPage, b.smithyItemPages - 1);
    await turnTo(tester, b, 'bag');
    await tapOn(tester, b.bagChip(BagCategory.materials));
    await tapOn(tester, b.bagCells.firstWhere((c) => c.$1 == Mat.slimeCore).$2);
    await tapOn(tester, b.bagAction(BagAction.smithy));
    final first = Relic.values.asNameMap()[g.townRules.recipesWith(Mat.slimeCore).first];
    expect((b.bookPage, b.smithyTab, b.smithyPick), ('smithy', SmithyTab.relics, first));
    await segment(tester, b, 'tab:items');
    expect((b.smithyItem, b.smithyItemPage), (Item.prayerBeads, 0));
    await frames(tester, 40);
  });
}
