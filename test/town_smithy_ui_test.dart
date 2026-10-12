// The Town's Smithy's relic pages (decisions-log 235; ui-hud.md "The Smithy"; the rules: town_craft_test.dart), booted
// TdGames with the Towns on, in a Town, on the Smithy's Relics tab (the strip, the Items tab, the boards' pages and the
// ways in: forge_smithy_ui_test.dart; the Wishlist tab: smithy_wish_ui_test.dart): the left page's relics on the Bag's
// slots in tier order (the ▲ on a craftable one, the count from 1, faded when not) and no materials under them
// (decisions-log 302: the recipe rows say what each takes); the right page's heading, lines, recipe rows, the one bevelled
// Craft, the grey line and the Equip row, all inside the book at 1266x713, 1164x777 and 915x412, on a short page each
// reached by its scroll; a craft by a tap ("Venom crafted!"), the refusals by a tap (a short material, a short item, the
// gold), the Equip row's taps (greyed with none, else the Bag with the relic picked and its troops listed). One TdGame
// per widget test.
//
// Never let a wave be won or the game end here (the Board then saves).
import 'dart:math';

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

/// The Smithy's facing page scrolled until its part [key] shows ([scrolledTo]; it scrolls where it doesn't fit,
/// decisions-log 283), and that part there.
Future<Rect> facing(WidgetTester tester, Board b, String key) => scrolledTo(tester, b, 'smithy', () => b.smithyAt(key));

/// Turns the Smithy to its Relics tab (it opens on the Wishlist tab, decisions-log 302).
Future<void> toRelics(WidgetTester tester, Board b) async {
  await shutMessage(tester, b);
  await tapOn(tester, b.smithyAt('tab:relics'), 'the Relics tab');
  expect(b.smithyTab, SmithyTab.relics);
}

/// Picks [relic] on the Smithy's board.
Future<void> pick(WidgetTester tester, Board b, Relic relic) async {
  await shutMessage(tester, b);
  await smithyBoardTo(tester, b, relic);
  await tapOn(tester, b.smithyCells.firstWhere((c) => c.$1 == relic).$2, '$relic');
  expect(b.smithyPick, relic);
}

/// [r] wholly inside [area].
bool inside(Rect r, Rect area) => r.left >= area.left - 0.5 && r.top >= area.top - 0.5 && r.right <= area.right + 0.5 && r.bottom <= area.bottom + 0.5;

const sizes = [Size(1266, 713), Size(1164, 777), Size(915, 412)];

/// A board game after wave 20 with the Towns on, in the Town before wave 21: a soldier, a knight, an archer and a
/// priest, 40,000 gold, and Venom's recipe twice over ([giveRecipe]; of the rest only the forge's Chill craftable).
Game smithyGame() {
  final g = Game(Random(1), Random(2)).boardRules()
    ..townDice = Random(3)
    ..armyMax = null
    ..gold = 40000
    ..wave = 20;
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
    ..townAt = 21
    ..inTown = true;
  giveRecipe(g, Relic.venom, 2);
  return g;
}

/// Puts [relic]'s recipe [times] over in [g]'s bag: its materials and items (not its gold).
void giveRecipe(Game g, Relic relic, [int times = 1]) {
  final r = g.craftRecipe(relic)!;
  for (final MapEntry(key: m, value: n) in r.materials.entries) {
    g.materials[m] = (g.materials[m] ?? 0) + n * times;
  }
  for (final MapEntry(key: i, value: n) in r.items.entries) {
    g.inventory[i] = (g.inventory[i] ?? 0) + n * times;
  }
}

/// What a craft may change in [g], written out: the materials, items, gold and the relic bag.
String bags(Game g) => '${g.materials} ${g.inventory} ${g.gold} ${g.relicBag}';

void main() {
  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('the Smithy at $tag: the relics in tier order, the materials grid, the recipe, Craft; it fits', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = smithyGame();
      g.relicBag
        ..[Relic.fang] = 2
        ..[Relic.guard] = 1;
      await frames(tester, 40);
      expect(b.bookPage, 'smithy', reason: 'a Town opens the book on the Smithy');
      await toRelics(tester, b);
      final (left, _) = b.bookPages;

      // The board: every small relic in play (the forge's 20), Basic, Strong, Mighty, on the left page (paged where they
      // don't all fit: decisions-log 283); the first craftable picked (Chill, a Basic one:
      // Venom's materials pay for it too), then Venom.
      expect(b.smithyPick, Relic.chill);
      await pick(tester, b, Relic.venom);
      final pages = await smithyBoardPages(tester, b);
      expect([for (final p in pages) for (final c in p.cells) c.$1], smithyRelics(g));
      expect(smithyRelics(g), hasLength(20));
      expect(b.smithyPick, Relic.venom);
      const ready = {Relic.chill, Relic.venom};
      for (final (:cells, :book, left: _) in pages) {
        for (final (relic, r, m) in cells) {
          expect(inside(r, book) && r.right <= book.center.dx + 0.5, isTrue, reason: '$tag $relic: $r on the left page');
          expect((m.ready, m.faded, m.lit), (ready.contains(relic), !ready.contains(relic), relic == Relic.venom), reason: '$relic');
          expect(m.count, switch (relic) { Relic.fang => 2, Relic.guard => 1, _ => null }, reason: '$relic: its count from 1');
        }
      }
      final board = b.smithyCells.map((c) => c.$2).reduce((a, r) => a.expandToInclude(r));

      // No materials under the board (decisions-log 302): Venom's recipe rows say what it takes.
      expect((b.smithyAt('kinds'), b.smithyText('kinds')), (Rect.zero, null), reason: tag);
      expect([...b.bagCells, ...b.bagSlots], isEmpty, reason: tag);
      expect(board.bottom, lessThanOrEqualTo(left.bottom + 0.5), reason: '$tag: the board on the page');

      // The facing page: Venom's heading, what it does, its tier and who it suits, the recipe's rows, Craft.
      expect((b.bagDetailText('name'), b.bagDetailText('count')), ('Venom', 'x0'));
      expect(b.smithyText('effect')!.replaceAll('\n', ' '), '${g.relicEffect(Relic.venom).first}.');
      expect(b.smithyText('tier')!.replaceAll('\n', ' '), startsWith('Strong relic.'));
      final rows = b.smithyRows;
      expect([for (final r in rows) r.kind], [Mat.boneArrow, Mat.slimeCore, Mat.batFang, Mat.boneBow, Item.bow, null]);
      expect([for (final r in rows) r.count], ['8 / 4', '4 / 2', '2 / 1', '2 / 1', '2 / 1', '40,000 / 700']);
      expect(rows.every((r) => !r.short), isTrue);
      if (size == sizes.first) {
        expect(rows.first.from, 'Skeleton Archer', reason: 'a material\'s monster where the page is wide');
        expect(rows[4].warn, 'Soldier needs 1 for ${Words.awaken} 1', reason: 'the soldier\'s recipe takes a bow');
      }
      // Each row, Craft, the grey "No limit" line and the Equip row inside the page, down it in order: on a short page
      // reached by its scroll (decisions-log 283; until then the page left the grey line and the Equip row out).
      Future<({Rect at, double top, double bottom})> down(String what, Rect Function() at) async {
        final r = await scrolledDown(tester, b, 'smithy', at), page = b.bookPages.$2;
        expect(r.at != Rect.zero && inside(r.at, page), isTrue, reason: '$tag $what: ${r.at} on the right page $page');
        return r;
      }

      var above = 0.0;
      for (var i = 0; i < rows.length; i++) {
        final r = await down('${rows[i].kind}', () => b.smithyRows[i].at);
        expect(r.top, greaterThanOrEqualTo(above), reason: '$tag: the rows apart');
        above = r.bottom;
      }
      final craft = await down('Craft', () => b.smithyAt('craft'));
      expect(craft.top, greaterThanOrEqualTo(above), reason: '$tag: Craft ${craft.at} under the rows');
      expect(b.smithyText('craft'), 'Craft (700 gold)');
      final noLimit = await down('No limit', () => b.smithyAt('noLimit'));
      expect(noLimit.top, greaterThanOrEqualTo(craft.bottom - 0.5), reason: '$tag: "No limit" ${noLimit.at}');
      expect(b.smithyText('noLimit'), startsWith('No limit'));
      final equip = await down('Equip', () => b.smithyAt('equip'));
      expect(equip.top, greaterThanOrEqualTo(noLimit.bottom), reason: '$tag: Equip ${equip.at}');
      expect(b.bagDetailText('title:equip'), 'Equip on a troop');
      expect(b.bagActions.firstWhere((a) => a.$1 == BagAction.equip).$3, isFalse, reason: 'none in the Bag');
      await frames(tester, 40); // the last tap's gesture timer runs out
    });
  }

  testWidgets('a craft by a tap: one into the Bag, its recipe taken, "Venom crafted!"; again; then refused with why',
      (tester) async {
    final b = await boot(tester);
    final g = b.state = smithyGame();
    await frames(tester, 40);
    await toRelics(tester, b);
    await pick(tester, b, Relic.venom);
    await tapOn(tester, await facing(tester, b, 'craft'));
    expect((g.relicBag[Relic.venom], g.gold, g.materials[Mat.boneArrow], g.inventory[Item.bow]), (1, 39300, 4, 1));
    expect(b.message, 'Venom crafted!');
    expect(b.bagDetailText('count'), 'x1');
    expect(b.smithyMarks(Relic.venom)?.count, 1);
    await shutMessage(tester, b);
    await tapOn(tester, await facing(tester, b, 'craft'));
    expect((g.relicBag[Relic.venom], g.gold, g.materials.containsKey(Mat.boneArrow)), (2, 38600, false));
    expect(b.message, 'Venom crafted!');
    // Nothing left of its materials: the white button says why, a tap says it again and nothing changes.
    expect(b.smithyText('craft'), 'Need 4 Bone Arrow');
    expect(b.smithyMarks(Relic.venom)!.faded, isTrue);
    expect(g.materials.containsKey(Mat.boneArrow), isFalse, reason: 'no Bone Arrow left');
    await shutMessage(tester, b);
    final before = bags(g);
    await tapOn(tester, await facing(tester, b, 'craft'));
    expect((b.message, bags(g)), ('Need 4 Bone Arrow', before));
    await frames(tester, 40);
  });

  for (final size in [sizes.first, sizes[2]]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('at $tag the refusals by a tap: a material short, an item short, the gold short; the short one in red',
        (tester) async {
      final b = await boot(tester, size);
      final g = b.state = smithyGame();
      giveRecipe(g, Relic.cleave);
      g.materials[Mat.wolfClaw] = 2; // of 4
      await frames(tester, 40);
      await toRelics(tester, b);
      await pick(tester, b, Relic.cleave);
      expect(b.smithyText('craft'), 'Need 2 more Wolf Claw');
      expect(b.smithyRows.first.short && b.smithyRows.skip(1).every((r) => !r.short), isTrue);
      final before = bags(g);
      await tapOn(tester, await facing(tester, b, 'craft'));
      expect((b.message, bags(g)), ('Need 2 more Wolf Claw', before));

      g
        ..materials[Mat.wolfClaw] = 4
        ..inventory.remove(Item.sword);
      await shutMessage(tester, b);
      await frames(tester, 3);
      expect(b.smithyText('craft'), 'Need 1 Sword');
      expect((b.smithyRows[4].kind, b.smithyRows[4].short), (Item.sword, true));
      final noSword = bags(g);
      await tapOn(tester, await facing(tester, b, 'craft'));
      expect((b.message, bags(g)), ('Need 1 Sword', noSword));

      g
        ..inventory[Item.sword] = 1
        ..gold = 699;
      await shutMessage(tester, b);
      await frames(tester, 3);
      expect(b.smithyText('craft'), Words.notEnoughGold);
      expect((b.smithyRows.last.count, b.smithyRows.last.short), ('699 / 700', true));
      final held = bags(g);
      await tapOn(tester, await facing(tester, b, 'craft'));
      expect((b.message, bags(g)), (Words.notEnoughGold, held));
      expect(g.relicBag[Relic.cleave], isNull);
      await frames(tester, 40);
    });
  }

  testWidgets("the Equip row: greyed with none in the Bag (a tap says why), else the Bag with the relic picked and its "
      'troops listed', (tester) async {
    final b = await boot(tester);
    final g = b.state = smithyGame();
    await frames(tester, 40);
    await toRelics(tester, b);
    await pick(tester, b, Relic.venom);
    expect(b.bagActions.firstWhere((a) => a.$1 == BagAction.equip).$3, isFalse);
    expect(b.bagDetailText('hint:equip'), 'Craft one first');
    await facing(tester, b, 'equip');
    await tapOn(tester, b.bagAction(BagAction.equip));
    expect((b.bookPage, b.message), ('smithy', 'Craft one first'));
    await shutMessage(tester, b);
    await tapOn(tester, await facing(tester, b, 'craft'));
    await shutMessage(tester, b);
    expect(b.bagActions.firstWhere((a) => a.$1 == BagAction.equip).$3, isTrue);
    expect(b.bagDetailText('hint:equip'), '1 in ${Words.bag}. Opens the ${Words.bag}');
    await facing(tester, b, 'equip');
    await tapOn(tester, b.bagAction(BagAction.equip));
    expect((b.bookPage, b.picked, b.bagChooser), ('bag', Relic.venom, BagAction.equip));
    expect(b.assignRows.where((r) => r.$3), isNotEmpty, reason: 'the troops that can wear it');
    expect(g.relicBag[Relic.venom], 1);
    await frames(tester, 40);
  });
}
