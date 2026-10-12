// The Bag's grid (decisions-log 187; docs/ui-hud.md "Tas"): one cell per kind owned, every cell the same size (44x44 on
// the desk, 36x36 on the phone, 915x412), inside the left page and apart, in a fixed order that only owning changes; a kind used up
// or a Pusaka not owned has none; the cells close up when one goes and the pick goes with it, nothing picked in its
// place; a tap picks only the kind its press went down on; the board, a slot at every place of the page (its "B1
// slots"), the cells in the first ones; pages of 36 (desk) and 12 (915x412) cells, 30/12 above the pager
// and 24/8 with the pager and the note's strip both (inside the book's padding, decisions-log 198), turned by the pager or the wheel; the category chips, which put
// back a pick they hide; NEW and the ▲; the marks; the empty texts; and the taps each Bag action takes (the design's
// §3.12). One TdGame per widget test.
//
// Never let a wave be won or the game end here: the board saves after a pick, into the queue's temp HOME
// (flutter_test_config.dart), never the real save.
import 'dart:math';
import 'dart:ui' show PointerDeviceKind;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'bag_detail_test.dart' show wheelUntil;
import 'hud_font.dart';

const desk = Size(1266, 713), wide = Size(915, 412), mid = Size(1164, 777), owner = Size(1600, 947);

/// Boots one TdGame in a [size] window, past the welcome screen, with the game's font and the minimap folded.
Future<Board> boot(WidgetTester tester, [Size size = desk]) async {
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
    ..miniMapOpen = false;
}

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> tapOn(WidgetTester tester, Offset p) async {
  await tester.tapAt(p);
  await frames(tester);
}

/// Closes the message window if it shows (a press on it does nothing else).
Future<void> quiet(WidgetTester tester, Board b) async {
  if (b.messageBox != Rect.zero) await tapOn(tester, b.messageBox.center);
}

/// Turns the open book to its Bag page.
Future<void> openBag(WidgetTester tester, Board b) async {
  await quiet(tester, b);
  await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
  expect(b.bagOpen, isTrue);
}

/// A board game between waves at [wave] (the Shop open from 16) with no army cap, gold to spare, and a soldier and a
/// knight beside the free priest, standing at their posts.
Game bagGame({int wave = 30}) {
  final g = Game(Random(1)).boardRules()
    ..armyMax = null
    ..gold = 5000000
    ..wave = wave;
  for (final type in ['soldier', 'knight']) {
    expect(g.autoPlace(type), isTrue);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  return g;
}

/// [bagGame] with a bag like a long run's: five kinds of item (one of them a single shield, 1200 potions), three small
/// relics, and Pusaka bound (Dragon Heart ★2 on the knight; Void Eye on the wizard, of whom none lives: asleep), in the
/// Gudang (the Grail) and an oath's.
Game stocked() {
  final g = bagGame();
  g.inventory.addAll({Item.sword: 86, Item.shield: 1, Item.bow: 3, Item.potion: 1200, Item.staff: 2});
  g.relicBag.addAll({Relic.fang: 1, Relic.fury: 5, Relic.guard: 2});
  g
    ..givePusaka(Relic.dragonHeart, type: 'knight', stars: 2)
    ..givePusaka(Relic.voidEye, type: 'wizard')
    ..givePusaka(Relic.grail)
    ..givePusaka(Relic.oathOfOne);
  return g;
}

/// The Bag's order (the design's §3.2): items, small relics, then the Pusaka owned, the rarest first.
List<Enum> allOrder(Game g) => [
      for (final i in droppedItems)
        if ((g.inventory[i] ?? 0) > 0) i,
      for (final r in droppedRelics)
        if ((g.relicBag[r] ?? 0) > 0) r,
      for (final rarity in [Rarity.legenda, Rarity.epik, Rarity.langka])
        for (final r in Relic.values)
          if (r.pusaka && r.rarity == rarity && g.pusaka.containsKey(r)) r,
    ];

List<Enum> kindsOf(Board b) => [for (final (kind, _) in b.bagCells) kind];

/// [kind]'s cell, the grid turned by the wheel to its page first (no tap: 915x412's page holds 12): back to the first
/// page, then on until it shows.
Future<Rect> cellOf(WidgetTester tester, Board b, Enum kind) async {
  final mouse = TestPointer(9, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(mouse.hover(b.bagCells.first.$2.center));
  for (final dy in const [-100.0, 100.0]) {
    for (var i = 0; i < 20 && b.bagSlot(kind) == Rect.zero; i++) {
      final was = b.bagPage;
      await tester.sendEventToBinding(mouse.scroll(Offset(0, dy)));
      await frames(tester, 20); // past the wheel's 0.25 s between turns
      if (b.bagPage == was) break; // at that end
    }
  }
  await tester.sendEventToBinding(mouse.hover(b.bookArea.topLeft)); // off the cells: a touch tap under a tooltip is no tap
  await frames(tester);
  return b.bagSlot(kind);
}

/// Each cell shown and where, from the first cell's corner: the book bobs, the grid in it doesn't move.
List<(Enum, Offset)> cellsAt(Board b) => [for (final (kind, r) in b.bagCells) (kind, r.topLeft - b.bagCells.first.$2.topLeft)];

/// [who]'s row on the facing page's list, the list wheeled down until it shows (the rows are in the book's order).
Future<Rect> rowOf(WidgetTester tester, Board b, Object who) async {
  final wheel = TestPointer(9, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(wheel.hover(b.assignList.center));
  for (var i = 0; i < 80 && !b.assignRows.any((r) => r.$1 == who && r.$2.height >= 12); i++) {
    await tester.sendEventToBinding(wheel.scroll(const Offset(0, 40)));
    await frames(tester);
  }
  await tester.sendEventToBinding(wheel.hover(b.bookArea.topLeft)); // off the rows: a touch tap under a tooltip is no tap
  await frames(tester);
  return b.assignRows.firstWhere((r) => r.$1 == who).$2;
}

/// The Pusaka the Gudang can hold (no oath), in [Relic] order.
final arts = [for (final r in Relic.values) if (r.pusaka && !r.oath) r];

void main() {
  for (final (size, cell) in const [(desk, Size(44, 44)), (wide, Size(36, 36))]) {
    final at = '${size.width.round()}x${size.height.round()}';
    testWidgets('at $at: a cell per kind owned, all ${cell.width.round()}x${cell.height.round()}, inside the left page and '
        'apart, in the All order; none for a kind used up or a Pusaka not owned; the count from 2; a Pusaka\'s stars and '
        'its type\'s mark, an oath\'s swords, none in the Gudang', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = stocked();
      await frames(tester, 50);
      await openBag(tester, b);
      expect(kindsOf(b), allOrder(g));
      expect(kindsOf(b), bagKinds(g, BagCategory.all));
      expect((b.bagPages, b.bagPager('on')), (1, Rect.zero));
      expect(b.bagEmpty, isEmpty);
      final book = b.bookArea, left = Rect.fromLTRB(book.left, book.top, b.bagDetail('page').left, book.bottom);
      final cells = [for (final (_, r) in b.bagCells) r];
      for (final (i, r) in cells.indexed) {
        expect(r.size, cell, reason: '$at cell $i');
        expect(left.contains(r.topLeft) && left.contains(r.bottomRight - const Offset(0.5, 0.5)), isTrue, reason: '$at $r in $left');
        for (final o in cells.skip(i + 1)) {
          expect(r.overlaps(o), isFalse, reason: '$at $r over $o');
        }
      }
      // Reading order: left to right, then down.
      for (final (i, r) in cells.skip(1).indexed) {
        expect(r.top > cells[i].top || (r.top == cells[i].top && r.left > cells[i].left), isTrue, reason: '$at cell ${i + 1}');
      }
      for (final kind in [Item.boots, Item.gloves, Relic.thorns, Relic.dawnStar, Relic.dragonCrown]) {
        expect((b.bagSlot(kind), b.bagMarks(kind)), (Rect.zero, null), reason: '$at $kind: none, no cell');
      }
      int? count(Enum kind) => b.bagMarks(kind)!.count;
      expect([count(Item.sword), count(Item.shield), count(Item.potion), count(Item.staff), count(Relic.fang), count(Relic.fury)],
          [86, null, 1200, 2, null, 5]);
      expect(shortCount(1200), '1.2k');
      final heart = b.bagMarks(Relic.dragonHeart)!, eye = b.bagMarks(Relic.voidEye)!, grail = b.bagMarks(Relic.grail)!;
      final oath = b.bagMarks(Relic.oathOfOne)!;
      expect((heart.stars, heart.bound, heart.oath, heart.asleep, heart.count), (2, 'knight', false, false, null));
      expect((eye.bound, eye.asleep), ('wizard', true));
      expect((grail.stars, grail.bound, grail.oath), (1, null, false));
      expect((oath.bound, oath.oath), (null, true));
      // A loaded game shows no NEW.
      expect(kindsOf(b).where((k) => b.bagMarks(k)!.isNew), isEmpty);
      await frames(tester, 10);
    });
  }

  testWidgets('binding, moving, unbinding and Asah never move a cell; the last gift and Lebur\'s fodder take '
      'theirs away (the Bag sells nothing, decisions-log 296), the cells close up and the pick goes, nothing picked in its place', (tester) async {
    final b = await boot(tester);
    final g = b.state = stocked();
    g.relicBag.addAll({Relic.fang: 12, Relic.thorns: 12, Relic.fury: 12, Relic.guard: 12}); // Asah takes 10, none runs out
    g.givePusaka(Relic.dawnStar); // a second in the Gudang: the Grail's Lebur target
    await frames(tester, 50);
    await openBag(tester, b);
    final order = kindsOf(b), rects = cellsAt(b);
    Future<void> same(String why) async {
      await frames(tester);
      expect(cellsAt(b), rects, reason: why);
    }

    g.bindPusaka(Relic.grail, 'soldier');
    await same('bound');
    g.bindPusaka(Relic.grail, 'knight'); // moved: Dragon Heart goes to the Gudang
    await same('moved');
    g.unbindPusaka(Relic.grail);
    await same('unbound');
    expect(g.asah(Relic.dawnStar), isTrue);
    await same('Asah');
    expect(order, allOrder(g));

    // The last shield given from its row: its cell goes, the next ones close up, the pick goes with it.
    await tapOn(tester, b.bagSlot(Item.shield).center);
    expect(b.picked, Item.shield);
    final shieldAt = b.bagSlot(Item.shield).topLeft - b.bagCells.first.$2.topLeft;
    await tapOn(tester, b.bagAction(BagAction.giveTroops).center); // its "Give to troops" (decisions-log 202)
    final (who, row, _) = b.assignRows.firstWhere((r) => r.$3);
    await tapOn(tester, row.center);
    await frames(tester);
    expect((g.inBag(Item.shield), b.picked, b.bagSlot(Item.shield)), (0, null, Rect.zero), reason: 'given to $who');
    expect(b.bagSlot(Item.bow).topLeft - b.bagCells.first.$2.topLeft, shieldAt, reason: 'the bow closes up into its place');
    expect(kindsOf(b), [...order]..remove(Item.shield));
    await quiet(tester, b);

    // Lebur: the Grail melts into Dawn Star; the Grail's cell goes, the pick moves to Dawn Star.
    await tapOn(tester, b.bagSlot(Relic.grail).center);
    await tapOn(tester, b.leburButton.center);
    final target = await rowOf(tester, b, Relic.dawnStar);
    await tapOn(tester, target.center);
    await tapOn(tester, target.center);
    await frames(tester);
    expect((g.pusaka.containsKey(Relic.grail), b.bagSlot(Relic.grail), b.picked), (false, Rect.zero, Relic.dawnStar));
    expect(kindsOf(b), allOrder(g));
    await quiet(tester, b);
    await frames(tester, 10);
  });

  testWidgets('a tap picks only the kind its press went down on: a cell that slides under the finger is not picked', (tester) async {
    final b = await boot(tester);
    final g = b.state = stocked();
    await frames(tester, 50);
    await openBag(tester, b);
    final [(first, _), (second, at), (third, _), ...] = b.bagCells;
    final press = await tester.startGesture(at.center);
    g.inventory[first as Item] = 0; // the first kind runs out while the finger is down: the cells close up under it
    await frames(tester);
    expect((b.bagCells.first.$1, b.bagSlot(third).contains(at.center), b.bagMarks(first)), (second, true, null)); // under the finger now
    await press.up();
    await frames(tester);
    expect(b.picked, isNull);
    await tapOn(tester, b.bagSlot(third).center);
    expect(b.picked, third);
    await tapOn(tester, b.bagSlot(third).center); // again: put back
    expect(b.picked, isNull);
    await frames(tester, 10);
  });

  for (final (size, gap) in const [(desk, 4.0), (wide, 2.0)]) {
    final at = '${size.width.round()}x${size.height.round()}';
    testWidgets('at $at the board: a slot at every place a page holds, each a cell\'s size and $gap px (2 sprite px) from the '
        'next across and down, centred on the page; the cells in the first slots in order, the rest empty', (tester) async {
      final b = await boot(tester, size);
      // At 915x412 a page holds 12 on the shorter landscape book (decisions-log 283): a kind fewer, so a slot stays empty.
      b.state = stocked()..inventory.remove(size == wide ? Item.staff : null);
      await frames(tester, 50);
      await openBag(tester, b);
      final slots = b.bagSlots, cells = [for (final (_, r) in b.bagCells) r];
      expect((b.bagPages, slots.length), (1, b.bagPageSizes.$1), reason: at);
      expect(slots.take(cells.length).toList(), cells, reason: at);
      expect(cells.length, lessThan(slots.length), reason: '$at: empty slots past the last kind');
      final cols = slots.where((r) => r.top == slots.first.top).length;
      expect(slots.length % cols, 0, reason: '$at: whole rows');
      for (final (i, r) in slots.indexed) {
        expect(r.size, cells.first.size, reason: '$at slot $i');
        if (i % cols > 0) expect((r.top, r.left - slots[i - 1].right), (slots[i - 1].top, gap), reason: '$at slot $i');
        if (i >= cols) expect((r.left, r.top - slots[i - cols].bottom), (slots[i - cols].left, gap), reason: '$at slot $i');
      }
      // Centred between the left page's chips' ends (the chips span the page's writing).
      final chips = [for (final cat in BagCategory.values) b.bagChip(cat)].where((r) => r != Rect.zero);
      final from = chips.map((r) => r.left).reduce(min), to = chips.map((r) => r.right).reduce(max);
      expect(((slots.first.left - from) - (to - slots[cols - 1].right)).abs(), lessThanOrEqualTo(1), reason: at);
      await frames(tester, 10);
    });
  }

  // On the shorter landscape book (decisions-log 283) a page holds fewer: 48 and 20 before it.
  for (final (size, one, paged, noteOne, notePaged) in const [(desk, 36, 30, 30, 24), (wide, 12, 12, 12, 8)]) {
    final at = '${size.width.round()}x${size.height.round()}';
    testWidgets('at $at a page holds $one cells, $paged above the pager; with the note\'s strip $noteOne and $notePaged, the '
        'strip under the cells', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = stocked();
      await frames(tester, 50);
      await openBag(tester, b);
      expect(b.bagPageSizes, (one, paged), reason: at);
      // The same all through the book's bob (a 3.9 s cycle): the rows are counted from the unrounded top, whose room
      // doesn't move with it (at 915x412 a sixth row misses by under half a pixel, and the rounded top's room flickered).
      for (var i = 0; i < 25; i++) {
        await frames(tester, 10);
        expect(b.bagPageSizes, (one, paged), reason: '$at, frame ${10 * i}');
      }
      g.pusaka[Relic.grail]!.suggested = true; // the save's suggestion: its strip at the bottom
      await frames(tester);
      expect(b.bagPageSizes, (noteOne, notePaged), reason: at);
      final ok = b.pusakaNoteButton('ok'), undo = b.pusakaNoteButton('batal'), book = b.bookArea;
      expect((ok.height >= 20, ok.right <= undo.left, b.bagCells.last.$2.bottom <= ok.top), (true, true, true), reason: at);
      expect(book.contains(ok.bottomRight - const Offset(0.5, 0.5)), isTrue, reason: '$at $ok in $book');
      await frames(tester, 10);
    });
  }

  testWidgets('at 915x412 everything owned takes pages: the pager (faded at the ends) and the wheel turn them, a notch '
      'a page; the Artifacts chip has its own; a page turn hiding the pick puts it back', (tester) async {
    final b = await boot(tester, wide);
    final g = b.state = bagGame();
    for (final i in droppedItems) {
      g.inventory[i] = 2;
    }
    for (final r in droppedRelics) {
      g.relicBag[r] = 2;
    }
    for (final r in Relic.values) {
      if (r.pusaka) g.givePusaka(r);
    }
    await frames(tester, 50);
    await openBag(tester, b);
    // As many pages as the catalog fills (each batch of Artifacts adds kinds): walked to the last.
    final kinds = bagKinds(g, BagCategory.all), per = b.bagPageSizes.$2, last = (kinds.length + per - 1) ~/ per - 1;
    expect(kinds.length, greaterThan(b.bagPageSizes.$1));
    expect((b.bagPages, b.bagPage, last >= 1), (last + 1, 0, true));
    expect(kindsOf(b), kinds.take(per));
    await tapOn(tester, b.bagPager('back').center); // faded: nothing
    expect(b.bagPage, 0);
    for (var p = 1; p <= last; p++) {
      await tapOn(tester, b.bagPager('on').center);
      expect(b.bagPage, p);
      expect(kindsOf(b), kinds.skip(p * per).take(per));
    }
    expect(b.bagSlots.length, per, reason: 'the last page\'s board is whole');
    expect(b.bagSlots.take(b.bagCells.length).toList(), [for (final (_, r) in b.bagCells) r], reason: 'its slots past the last kind empty');
    await tapOn(tester, b.bagPager('on').center); // faded at the last page
    expect(b.bagPage, last);
    final pager = b.bagPager('on');
    expect((pager.height >= 20, pager.top >= b.bagCells.last.$2.bottom), (true, true));
    // The wheel over the grid: up a page; a second notch at once (a swipe's next event) does nothing; later, down.
    final mouse = TestPointer(1, PointerDeviceKind.mouse), over = b.bagCells.first.$2.center;
    await tester.sendEventToBinding(mouse.hover(over));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
    await frames(tester);
    expect(b.bagPage, last - 1);
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 100)));
    await frames(tester);
    expect(b.bagPage, last - 1, reason: 'within 0.25 s of the last turn');
    await frames(tester, 20);
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 100)));
    await frames(tester);
    expect(b.bagPage, last);
    // The mouse off the cells: resting on one, its tooltip shows, and a touch tap under a tooltip is no tap (tooltip.dart).
    await tester.sendEventToBinding(mouse.hover(b.bookArea.topLeft));
    await frames(tester);
    // A pick, then a page turn that would hide it: it goes back first.
    final picked = b.bagCells.first.$1;
    await tapOn(tester, b.bagCells.first.$2.center);
    expect(b.picked, picked);
    await tapOn(tester, b.bagPager('back').center);
    expect((b.bagPage, b.picked), (last - 1, null));
    // The Artifacts chip: its own pages, from its first; All keeps its page.
    await tapOn(tester, b.bagChip(BagCategory.artifacts).center);
    final arts = Relic.values.where((r) => r.pusaka).length;
    expect((b.bagCategory, b.bagPages, b.bagPage, b.bagCells.length), (BagCategory.artifacts, (arts + per - 1) ~/ per, 0, kindsOf(b).length));
    expect(kindsOf(b).every((k) => k is Relic && k.pusaka), isTrue);
    await frames(tester, 10);
  });

  // At 915x412 a finger's height exactly: the chips' places are on whole pixels as drawn, where the book's bob once left
  // them a hair under 20 px (decisions-log 291). The tablet's 1164x777 too.
  for (final size in const [wide, mid]) {
    final at = '${size.width.round()}x${size.height.round()}';
    testWidgets('at $at the chips show each category and the one on is lit; a chip hiding the pick puts it back; Artifacts '
        'only once the Shop opens or one is owned', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = stocked();
      await frames(tester, 50);
      await openBag(tester, b);
      expect(b.bagCategory, BagCategory.all);
      for (final (cat, test) in [
        (BagCategory.items, (Enum k) => k is Item),
        (BagCategory.relics, (Enum k) => k is Relic && !k.pusaka),
        (BagCategory.artifacts, (Enum k) => k is Relic && k.pusaka),
        (BagCategory.all, (Enum k) => true),
      ]) {
        await tapOn(tester, b.bagChip(cat).center);
        expect(b.bagCategory, cat);
        expect(kindsOf(b), [for (final k in allOrder(g)) if (test(k)) k], reason: '$cat');
      }
      // The five chips in one row over the grid, apart, a finger's height, inside the left page.
      expect(b.bagChip(BagCategory.materials), isNot(Rect.zero));
      final chips = [for (final cat in BagCategory.values) b.bagChip(cat)], left = b.bagDetail('page').left;
      for (final (i, r) in chips.indexed) {
        expect((r.height >= 20, r.top, r.bottom <= b.bagCells.first.$2.top, r.right <= left), (true, chips.first.top, true, true), reason: '$at chip $i');
        expect([r.left, r.top, r.right, r.bottom].every((v) => v == v.roundToDouble()), isTrue, reason: '$at chip $i: $r as drawn');
        if (i > 0) expect(r.left, greaterThanOrEqualTo(chips[i - 1].right), reason: '$at chip $i');
      }
      // A sword picked, then Relics: the sword goes back; a relic picked stays through All.
      await tapOn(tester, b.bagSlot(Item.sword).center);
      await tapOn(tester, b.bagChip(BagCategory.relics).center);
      expect((b.bagCategory, b.picked), (BagCategory.relics, null));
      await tapOn(tester, b.bagSlot(Relic.fury).center);
      await tapOn(tester, b.bagChip(BagCategory.all).center);
      expect((b.bagCategory, b.picked, b.bagSlot(Relic.fury) == Rect.zero), (BagCategory.all, Relic.fury, false));
      await tapOn(tester, b.bagSlot(Relic.fury).center);

      // Before the Shop opens (a new game: town.json's `shop.from` 1), with no Pusaka: no Artifacts chip.
      b.state = bagGame(wave: 0)..inventory[Item.sword] = 1;
      await frames(tester, 50);
      await openBag(tester, b);
      expect((b.bagChip(BagCategory.artifacts), b.bagChip(BagCategory.relics) == Rect.zero), (Rect.zero, false));
      await frames(tester, 10);
    });
  }

  testWidgets('at 915x412 a pick Lebur makes turns the grid to its target\'s page', (tester) async {
    final b = await boot(tester, wide);
    final g = b.state = bagGame();
    for (final i in droppedItems) {
      g.inventory[i] = 2;
    }
    for (final r in droppedRelics) {
      g.relicBag[r] = 2;
    }
    // Of the Legenda only Dragon Crown (they go first: batch G-1P's ten would push Dragon Heart off the first page).
    for (final r in arts.where((r) => r.rarity != Rarity.legenda || r == Relic.dragonCrown)) {
      g.givePusaka(r, stars: 3); // ★3: no target but the one below
    }
    g.givePusaka(Relic.oathOfOne);
    final target = bagKinds(g, BagCategory.all).lastWhere((k) => k is Relic && k.rarity != Rarity.legenda) as Relic;
    g.pusaka[target]!.stars = 1;
    g.pusaka[Relic.dragonHeart]!.stars = 1;
    await frames(tester, 50);
    await openBag(tester, b);
    final per = b.bagPageSizes.$2;
    int pageOf([Enum? kind]) => bagKinds(g, BagCategory.all).indexOf(kind ?? target) ~/ per;
    // Dragon Heart on a page before the target's (on the shorter landscape book, decisions-log 283, not the first): the
    // grid turned to it.
    final heart = pageOf(Relic.dragonHeart);
    expect((b.bagPages >= 2, pageOf(), heart < pageOf()), (true, b.bagPages - 1, true), reason: 'the target on the last page');
    for (var p = 0; p < heart; p++) {
      await tapOn(tester, b.bagPager('on').center);
    }
    await tapOn(tester, b.bagSlot(Relic.dragonHeart).center);
    expect((b.picked, b.bagPage), (Relic.dragonHeart, heart));
    await tapOn(tester, b.leburButton.center);
    expect(b.leburOpen, Relic.dragonHeart);
    final row = await rowOf(tester, b, target);
    await tapOn(tester, row.center);
    await tapOn(tester, row.center);
    await frames(tester);
    expect((b.picked, g.pusaka[target]!.stars, g.pusaka.containsKey(Relic.dragonHeart)), (target, 2, false));
    final page = pageOf(); // Dragon Heart eaten: one kind fewer before the target
    expect((page > heart, b.bagCategory, b.bagPage, b.bagSlot(target) == Rect.zero), (true, BagCategory.all, page, false));
    await frames(tester, 10);
  });

  testWidgets('NEW marks a kind gained since the Bag was last left, until it is picked or the page left; a relic taken off '
      'comes back NEW; the ▲ marks the items a fielded type can awaken with', (tester) async {
    final b = await boot(tester);
    final g = b.state = stocked();
    await frames(tester, 50);
    await openBag(tester, b);
    bool isNew(Enum k) => b.bagMarks(k)!.isNew;
    expect(kindsOf(b).any(isNew), isFalse);
    g.inventory[Item.gloves] = 2;
    g.givePusaka(Relic.dawnStar);
    await frames(tester);
    expect([for (final k in kindsOf(b)) if (isNew(k)) k], [Item.gloves, Relic.dawnStar]);
    await tapOn(tester, b.bagSlot(Item.gloves).center); // picked: its NEW goes
    expect((isNew(Item.gloves), isNew(Relic.dawnStar)), (false, true));
    await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2.center); // the page left: every NEW goes
    await openBag(tester, b);
    expect(kindsOf(b).any(isNew), isFalse);
    // The last fang on a troop, then taken off: its cell comes back NEW.
    g.relicBag[Relic.fang] = 0;
    await frames(tester);
    expect(b.bagMarks(Relic.fang), isNull);
    g.relicBag[Relic.fang] = 1;
    await frames(tester);
    expect(isNew(Relic.fang), isTrue);

    // ▲: what the soldier lacks for its next Awaken (its grade set) in the bag: every kind of it marked, nothing else.
    final recipe = g.awakenShort('soldier');
    for (final MapEntry(key: item, value: need) in recipe.entries) {
      g.inventory[item] = need;
    }
    await frames(tester);
    expect(g.bagLevel('soldier'), greaterThan(g.itemLevel('soldier')));
    bool ready(Item i) => [
          for (final type in {for (final u in g.troops) if (u.alive) u.type})
            if (g.bagLevel(type) > g.itemLevel(type) && g.awakenShort(type).containsKey(i)) type,
        ].isNotEmpty;
    for (final i in Item.values.where((i) => (g.inventory[i] ?? 0) > 0)) {
      expect(b.bagMarks(i)!.ready, ready(i), reason: '$i');
    }
    expect(recipe.keys.every((i) => b.bagMarks(i)!.ready), isTrue);
    // One kind short again: the ▲ goes.
    g.inventory[recipe.keys.first] = 0;
    await frames(tester);
    expect(recipe.keys.skip(1).every((i) => b.bagMarks(i)?.ready != true || ready(i)), isTrue);
    expect(kindsOf(b).whereType<Relic>().any((r) => b.bagMarks(r)!.ready), isFalse);
    await frames(tester, 10);
  });

  // 1164x777: at 915x412 the text's card covers every row of the page's board (decisions-log 289).
  for (final size in const [desk, mid]) {
    final at = '${size.width.round()}x${size.height.round()}';
    testWidgets('at $at the empty texts: All\'s bag, Items, Relics with those worn, Artifacts and where they come from', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = bagGame();
      await frames(tester, 50);
      await openBag(tester, b);
      expect(b.bagCells, isEmpty, reason: at);
      // The Towns' words.
      expect(b.bagEmpty.join(' '), 'Your bag is empty. Monsters drop materials. Make items at the Smithy in a Town.', reason: at);
      // The board stands, but for the whole rows the text's card covers.
      final slots = b.bagSlots, cols = slots.where((r) => r.top == slots.first.top).length;
      expect((slots.isNotEmpty, slots.length < b.bagPageSizes.$1, slots.length % cols), (true, true, 0), reason: at);
      g.relicBag[Relic.fang] = 1;
      g.troops.firstWhere((u) => u.alive).relics.add(Relic.guard);
      await frames(tester);
      await tapOn(tester, b.bagChip(BagCategory.items).center);
      expect(b.bagEmpty, ['No items yet.'], reason: at);
      g.relicBag[Relic.fang] = 0;
      await tapOn(tester, b.bagChip(BagCategory.relics).center);
      expect(b.bagEmpty, ['No relics in the bag.', '1 worn by troops.'], reason: at);
      await tapOn(tester, b.bagChip(BagCategory.artifacts).center);
      expect(b.bagEmpty, ['No Artifacts yet.', 'Boss Chests give them.', if (g.storeOpen && g.shelfOpen) "A Town's Shop sells some."],
          reason: at);
      g.inventory[Item.sword] = 1;
      await tapOn(tester, b.bagChip(BagCategory.all).center);
      expect(kindsOf(b), [Item.sword], reason: at);
      expect(b.bagEmpty, isEmpty, reason: at);
      await frames(tester, 10);
    });
  }

  // What drops, true to the build (decisions-log 292): with the Towns (and the forge) on, the board's, monsters drop no
  // item, only materials, and the Smithy makes the items.
  for (final size in const [owner, desk, mid, wide]) {
    final at = '${size.width.round()}x${size.height.round()}';
    testWidgets('at $at the empty Bag with the Towns on says monsters drop materials and the Smithy makes items, whole and '
        'inside its card', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = bagGame()..towns = true;
      expect(g.towns, isTrue, reason: "the board's");
      await frames(tester, 50);
      await openBag(tester, b);
      expect(b.bagCells, isEmpty, reason: at);
      expect(b.bagEmpty.join(' '), 'Your bag is empty. Monsters drop materials. Make items at the Smithy in a Town.',
          reason: '$at: every word, none cut (a long line goes on over two)');
      final (card, text) = b.bagEmptyCard;
      expect((card.isEmpty, card.top <= text.top, text.bottom <= card.bottom), (false, true, true), reason: '$at: $text inside $card');
      await frames(tester, 10);
    });
  }

  for (final size in const [desk, wide]) {
    final at = '${size.width.round()}x${size.height.round()}';
    testWidgets('at $at the Bag\'s actions take the design\'s taps (§3.12, decisions-log 202): an item 3 then 1 a copy, '
        'a relic 3, Take off 2, bind / move 3, to the Vault 2, Lebur 4, Asah 3, a chip 1, '
        'the note 1', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = stocked();
      g.relicBag.addAll({Relic.fang: 12, Relic.thorns: 12, Relic.fury: 12, Relic.guard: 12});
      g
        ..givePusaka(Relic.dawnStar)
        ..givePusaka(Relic.godThunder);
      g.pusaka[Relic.dragonHeart]!.suggested = true; // the save's suggestion: the note's strip
      await frames(tester, 50);
      await openBag(tester, b);
      var taps = 0;
      Future<void> tap(Rect r) async {
        expect(r, isNot(Rect.zero));
        taps++;
        await tapOn(tester, r.center);
      }

      Future<int> done() async {
        final n = taps;
        taps = 0;
        await quiet(tester, b);
        if (b.picked case final p?) await tapOn(tester, b.bagSlot(p).center); // put back: the next starts from none
        return n;
      }

      Rect okRow() => b.assignRows.firstWhere((r) => r.$3 && b.assignList.contains(r.$2.center)).$2;
      // decisions-log 202: a type or a troop is one tap further, on the action that opens their list.
      Future<Rect> row(Object who) => rowOf(tester, b, who);

      // The note's OK: 1.
      await tap(b.pusakaNoteButton('ok'));
      expect((g.pusakaSuggested, await done()), (false, 1));
      // An item on a type: its cell, "Give to troops" and a row, then 1 a copy.
      await tap(await cellOf(tester, b, Item.sword));
      await tap(b.bagAction(BagAction.giveTroops));
      final (type, first, _) = b.assignRows.firstWhere((r) => r.$3 && b.assignList.contains(r.$2.center));
      await tap(first);
      expect((g.countOf(type as String, Item.sword), taps), (1, 3));
      await tap(b.assignRows.firstWhere((r) => r.$1 == type).$2);
      expect((g.countOf(type, Item.sword), await done()), (2, 4));
      // A relic to a troop: its cell, "Equip on a troop" and a row: 3.
      final fury = g.inBag(Relic.fury);
      await tap(await cellOf(tester, b, Relic.fury));
      await tap(b.bagAction(BagAction.equip));
      await tap(okRow());
      expect((g.inBag(Relic.fury), await done()), (fury - 1, 3));
      // Bind and move the Grail: its cell, "Equip on a type" / "Move to a type" and a row: 3 each; back to the Vault
      // from its "Take it off" row: 2.
      await tap(await cellOf(tester, b, Relic.grail));
      await tap(b.bagAction(BagAction.types));
      await tap(await row('soldier'));
      expect((g.pusaka[Relic.grail]!.type, await done()), ('soldier', 3));
      await tap(await cellOf(tester, b, Relic.grail));
      await tap(b.bagAction(BagAction.types));
      await tap(await row('knight'));
      expect((g.pusaka[Relic.grail]!.type, await done()), ('knight', 3));
      await tap(await cellOf(tester, b, Relic.grail));
      await wheelUntil(tester, b, () => b.bagDetail('toVault')); // the action rows wheeled to it (915x412): no tap
      await tap(b.bagDetail('toVault'));
      expect((g.pusaka[Relic.grail]!.type, await done()), (null, 2));
      // Lebur God's Thunder into the Grail: 4 (the list wheeled to its row is no tap).
      await tap(await cellOf(tester, b, Relic.godThunder));
      await wheelUntil(tester, b, () => b.leburButton);
      await tap(b.leburButton);
      final into = await row(Relic.grail);
      await tap(into);
      await tap(into);
      expect((g.pusaka.containsKey(Relic.godThunder), g.pusaka[Relic.grail]!.stars, await done()), (false, 2, 4));
      // Asah: 3.
      await tap(await cellOf(tester, b, Relic.grail));
      await wheelUntil(tester, b, () => b.asahButton);
      await tap(b.asahButton);
      await tap(b.asahButton);
      expect((g.pusaka[Relic.grail]!.stars, await done()), (3, 3));
      // A category chip: 1.
      await tap(b.bagChip(BagCategory.relics));
      expect((b.bagCategory, await done()), (BagCategory.relics, 1));
      await frames(tester, 10);
    });
  }
}
