// The Enhance UI (decisions-log 255; ui-hud.md "The Smithy" and "The Bag"; forge-design §12, mockups 11 and 12), booted
// TdGames in a Town after wave 30 with the Towns and the forge on, at 1266x713, 1164x777 and 915x412: the Smithy's
// Enhance tab (greyed before wave 30, its tap then saying when it opens) with its board, the two stones first and then
// the Bag's items by grade, III first, each enhanced stack its own cell with its "+3" tag; a stack's facing page (its
// "+3", what one does now and at +0, its grade and steps, "Recipe to +4", "Enhance to +4 (2,500 gold)", what one does at
// +4, "Give to a type"), all inside the book; a step up by a tap (the page follows it to its new stack), refused with
// why, and at +5 "Max: +5" and no recipe; a stone made by a tap; Give opening the Bag on the stack's types and a type
// taking it at its plus (the Army detail's "+2"); the Bag's cells (each stack after its item, picked on its own, its
// tooltip its own); on the field a stack in hand given by a tap on a troop at its plus; and the Shop selling a stack at
// its own price. The rules: forge_enhance_test.dart. One TdGame per test.
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

/// Taps the Smithy's segment [key] ('tab:enhance').
Future<void> segment(WidgetTester tester, Board b, String key) async {
  await shutMessage(tester, b);
  await tapOn(tester, b.smithyAt(key), key);
}

/// Taps the Enhance board's cell of [kind] at +[plus].
Future<void> enhanceCell(WidgetTester tester, Board b, Enum kind, [int plus = 0]) async {
  await shutMessage(tester, b);
  await tapOn(tester, b.smithyEnhanceCells.firstWhere((c) => c.$1 == (kind: kind, plus: plus)).$2, '$kind +$plus');
}

/// [r] wholly inside [area].
bool inside(Rect r, Rect area) => r.left >= area.left - 0.5 && r.top >= area.top - 0.5 && r.right <= area.right + 0.5 && r.bottom <= area.bottom + 0.5;

const sizes = [Size(1266, 713), Size(1164, 777), Size(915, 412)];

/// A board game after wave [wave] with the Towns and the forge on, in the Town before the next: a soldier, a knight, an
/// archer and a priest (none holding an item), 40,000 gold; in the Bag two Royal Swords and one at +3, a Sword and one
/// at +2, one Mithril and one Starmetal, and Mithril's recipe once (not its gold).
Game enhanceGame({int wave = 30}) {
  final g = Game(Random(1), Random(2)).boardRules()
    ..townDice = Random(3)
    ..towns = true
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
  g.inventory.addAll({Item.royalSword: 2, Item.sword: 1});
  g.enhancedBag.addAll({(Item.royalSword, 3): 1, (Item.sword, 2): 1});
  g.materials.addAll({Mat.mithril: 1, Mat.starmetal: 1, ...g.stoneRecipe(Mat.mithril)!.materials});
  return g;
}

/// The Enhance board [enhanceGame] starts with: the stones, then grade III's Royal Swords, then grade I's Swords.
const board = <BagLoot>[
  (kind: Mat.mithril, plus: 0),
  (kind: Mat.starmetal, plus: 0),
  (kind: Item.royalSword, plus: 0),
  (kind: Item.royalSword, plus: 3),
  (kind: Item.sword, plus: 0),
  (kind: Item.sword, plus: 2),
];

void main() {
  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('the Enhance tab at $tag: the stones, then the items by grade with each stack its own cell; a stack\'s page '
        'from its "+3" to Give; it fits', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = enhanceGame();
      await frames(tester, 40);
      expect((b.bookPage, b.smithyText('locked')), ('smithy', ''));
      await segment(tester, b, 'tab:enhance');
      expect((b.smithyTab, b.message), (SmithyTab.enhance, null));
      final book = b.bookArea;
      final (left, right) = b.bookPages;

      // The board: the stones, then the items, each stack after its item; the first that can go up picked (Royal Sword).
      final cells = b.smithyEnhanceCells;
      expect([for (final c in cells) c.$1], board);
      expect(b.smithyEnhancePick, (kind: Item.royalSword, plus: 0));
      for (final (cell, r) in cells) {
        expect(inside(r, left) && r.top >= b.smithyAt('tab:enhance').bottom, isTrue, reason: '$tag $cell: $r on the left page');
      }
      final m = b.smithyEnhanceMarks(Item.royalSword, 3)!;
      expect((m.plus, m.count, m.ready, m.faded, m.lit), (3, null, false, false, false), reason: 'the +3 stack');
      expect((b.smithyEnhanceMarks(Item.royalSword)!.count, b.smithyEnhanceMarks(Item.royalSword)!.lit), (2, true));
      expect(b.smithyEnhanceMarks(Item.sword, 2)!.plus, 2);
      // The stones are what the tab makes: Mithril's recipe is held (its ▲), Starmetal's is not (faded); the Royal Sword's
      // step to +1 takes a Mithril (lit).
      final (mithril, starmetal) = (b.smithyEnhanceMarks(Mat.mithril)!, b.smithyEnhanceMarks(Mat.starmetal)!);
      expect((mithril.ready, mithril.faded, mithril.count, mithril.lit), (true, false, 1, true));
      expect((starmetal.ready, starmetal.faded, starmetal.count, starmetal.lit), (false, true, 1, false));

      // The +3 stack's page: its heading with "+3", what one does now and at +0, its grade and steps, Recipe to +4 (a
      // Starmetal, 2,500 gold), Enhance, what one does at +4, then (with room) Give to a type.
      await enhanceCell(tester, b, Item.royalSword, 3);
      expect(b.smithyEnhancePick, (kind: Item.royalSword, plus: 3));
      expect(b.smithyEnhanceMarks(Item.royalSword, 3)!.lit, isTrue);
      expect((b.bagDetailText('name'), b.bagDetailText('count')), ('Royal Sword +3', 'x1'));
      final now = g.itemEffect(Item.royalSword, null, 3).first, base = g.itemEffect(Item.royalSword).first.split(' ').first;
      final phone = size.height < 500, effect = b.smithyText('effect')!.replaceAll('\n', ' '), tier = b.smithyText('tier')!.replaceAll('\n', ' ');
      expect(effect, phone ? startsWith(now) : '$now for one troop type ($base at +0).');
      expect(tier, phone ? startsWith('Grade III') : 'Grade III, ${Words.enhanced} 3 times. Each + adds 10% of its bonus, up to +5. It always works.');
      expect(b.smithyText('recipe'), '${Words.recipe} to +4');
      final rows = b.smithyRows;
      expect([for (final r in rows) (r.kind, r.count, r.short)], [(Mat.starmetal, '1 / 1', false), (null, '40,000 / 2,500', false)]);
      expect(rows.first.from, phone ? anyOf('', Words.smithy) : Words.smithy, reason: 'a stone: made at the Smithy');
      for (final r in rows) {
        expect(inside(r.at, right), isTrue, reason: '$tag ${r.kind}: ${r.at} on the right page');
      }
      final enhance = b.smithyAt('enhance');
      expect(inside(enhance, right) && enhance.top >= rows.last.at.bottom, isTrue, reason: '$tag: Enhance $enhance');
      expect(b.smithyText('enhance'), phone ? startsWith(Words.enhance) : '${Words.enhance} to +4 (2,500 gold)');
      final next = b.smithyText('next');
      if (next != null) expect(next, '${g.itemEffect(Item.royalSword, null, 4).first} at +4');
      final give = b.smithyAt('give');
      if (size.height >= 700) expect(give, isNot(Rect.zero), reason: '$tag: room for Give');
      if (give != Rect.zero) {
        expect(inside(give, right) && give.top >= enhance.bottom, isTrue, reason: '$tag: Give $give');
        expect(b.bagDetailText('title:giveTroops'), '${Words.give} to a type');
        expect(b.smithyText('give'), '1 in ${Words.bag}. Opens the ${Words.bag}');
      }
      expect(inside(left, book) && inside(right, book), isTrue);
      await frames(tester, 40);
    });
  }

  testWidgets('Enhance greyed before wave 30: a tap says when it opens and the tab stays', (tester) async {
    final b = await boot(tester);
    b.state = enhanceGame(wave: 29);
    await frames(tester, 40);
    expect(b.smithyText('locked'), 'enhance');
    await segment(tester, b, 'tab:enhance');
    expect((b.message, b.smithyTab), ('Opens after wave 30', SmithyTab.wishlist), reason: 'the Smithy opens on its Wishlist (302)');
    expect(b.smithyEnhanceCells, isEmpty);
    await frames(tester, 40);
  });

  testWidgets('a step up by a tap: the stone and the gold go, the page follows the new stack; refused with why; at +5 '
      '"Max: +5" and no recipe', (tester) async {
    final b = await boot(tester);
    final g = b.state = enhanceGame();
    await frames(tester, 40);
    await segment(tester, b, 'tab:enhance');
    await enhanceCell(tester, b, Item.royalSword, 3);
    await tapOn(tester, b.smithyAt('enhance'), 'Enhance');
    expect((g.bagOf(Item.royalSword, 3), g.bagOf(Item.royalSword, 4), g.materials[Mat.starmetal] ?? 0, g.gold), (0, 1, 0, 37500));
    expect(b.message, 'Royal Sword ${Words.enhanced} to +4!');
    expect(b.smithyEnhancePick, (kind: Item.royalSword, plus: 4));
    expect((b.bagDetailText('name'), b.smithyText('recipe')), ('Royal Sword +4', '${Words.recipe} to +5'));
    expect(b.smithyEnhanceMarks(Item.royalSword, 4)!.plus, 4);
    expect(b.smithyEnhanceMarks(Item.royalSword, 3), isNull, reason: 'no +3 left');

    // No Starmetal: the white button says why, and a press says it again, nothing changing.
    await shutMessage(tester, b);
    expect(b.smithyText('enhance'), 'Need 1 Starmetal');
    final before = '${g.materials} ${g.gold} ${g.enhancedBag}';
    await tapOn(tester, b.smithyAt('enhance'));
    expect((b.message, '${g.materials} ${g.gold} ${g.enhancedBag}'), ('Need 1 Starmetal', before));

    // To +5: then no recipe, "Max: +5", no line under it.
    g.materials[Mat.starmetal] = 1;
    await shutMessage(tester, b);
    await tapOn(tester, b.smithyAt('enhance'));
    expect((g.bagOf(Item.royalSword, 5), b.smithyEnhancePick), (1, (kind: Item.royalSword, plus: 5)));
    await shutMessage(tester, b);
    expect((b.smithyText('enhance'), b.smithyAt('recipe'), b.smithyText('next')), ('Max: +5', Rect.zero, null));
    expect(b.smithyRows, isEmpty);
    expect(b.bagDetailText('name'), 'Royal Sword +5');
    await frames(tester, 40);
  });

  testWidgets('a stone made by a tap: its recipe and gold go, "Mithril crafted!"', (tester) async {
    final b = await boot(tester);
    final g = b.state = enhanceGame();
    await frames(tester, 40);
    await segment(tester, b, 'tab:enhance');
    await enhanceCell(tester, b, Mat.mithril);
    expect((b.bagDetailText('name'), b.bagDetailText('count')), ('Mithril', 'x1'));
    expect(b.smithyText('effect')!.replaceAll('\n', ' '), 'One for each ${Words.enhance} step to +1, +2 or +3.');
    expect([for (final r in b.smithyRows) r.kind], [...g.stoneRecipe(Mat.mithril)!.materials.keys, null]);
    expect(b.smithyText('craft'), 'Craft (1,000 gold)');
    expect(b.smithyAt('give'), Rect.zero, reason: 'a stone is given to no one');
    await tapOn(tester, b.smithyAt('craft'));
    expect((g.materials[Mat.mithril], g.materials[Mat.evilEye] ?? 0, g.gold, b.message), (2, 0, 39000, 'Mithril crafted!'));
    expect(g.matsSeen, isNot(contains(Mat.mithril)), reason: 'never dropped');
    await frames(tester, 40);
  });

  testWidgets('Give to a type: the Bag on the stack\'s types; a type takes it at its plus, its Army detail says "+2"',
      (tester) async {
    final b = await boot(tester);
    final g = b.state = enhanceGame();
    await frames(tester, 40);
    await segment(tester, b, 'tab:enhance');
    await enhanceCell(tester, b, Item.sword, 2);
    await tapOn(tester, b.smithyAt('give'), 'Give');
    expect((b.bookPage, b.picked, b.pickedPlus, b.bagChooser), ('bag', Item.sword, 2, BagAction.giveTroops));
    expect(b.bagDetailText('name'), 'Sword +2');
    final knight = b.assignRows.firstWhere((r) => r.$1 == 'knight');
    expect(knight.$3, isTrue, reason: 'the knight takes a Sword');
    await tapOn(tester, knight.$2);
    expect((g.countOf('knight', Item.sword), g.bagOf(Item.sword, 2), g.bagOf(Item.sword)), (1, 0, 1));
    expect(g.plusesOn('knight', Item.sword), [2]);
    expect(b.picked, isNull, reason: 'none left at +2: the pick goes');

    // Out of the Town, on the field's book: the knight's Sword cell, tinted, its count and "+2".
    expect(g.leaveTown(), isTrue);
    for (var i = 0; i < 300 && !b.bookTabs.any((t) => t.$1 == 'troops'); i++) {
      await frames(tester, 1); // the Town fades out, the book floats in on the field
    }
    await frames(tester, 20);
    await turnTo(tester, b, 'troops');
    await tapOn(tester, b.troopRow('knight'));
    expect(b.troopDetailWords('stats'), contains(' +2'));
    await frames(tester, 40);
  });

  testWidgets('the Bag: each stack after its item, its "+3", picked on its own with its page; dragged out it gives at its '
      'plus; its tooltip is its own', (tester) async {
    final b = await boot(tester);
    final g = b.state = enhanceGame();
    await frames(tester, 40);
    await turnTo(tester, b, 'bag');
    await tapOn(tester, b.bagChip(BagCategory.items));
    expect([for (final c in b.bagLootCells) c.$1],
        [(kind: Item.sword, plus: 0), (kind: Item.sword, plus: 2), (kind: Item.royalSword, plus: 0), (kind: Item.royalSword, plus: 3)]);
    expect([for (final c in b.bagCells) c.$1], [Item.sword, Item.sword, Item.royalSword, Item.royalSword]);
    final m = b.bagMarks(Item.royalSword, 3)!;
    expect((m.plus, m.count, m.isNew), (3, null, false));
    expect((b.bagMarks(Item.royalSword)!.plus, b.bagMarks(Item.royalSword)!.count), (0, 2));

    await tapOn(tester, b.bagStackSlot(Item.royalSword, 3));
    expect((b.picked, b.pickedPlus), (Item.royalSword, 3));
    expect((b.bagMarks(Item.royalSword, 3)!.lit, b.bagMarks(Item.royalSword)!.lit), (true, false));
    expect((b.bagDetailText('name'), b.bagDetailText('count')), ('Royal Sword +3', 'x1'));
    expect(b.bagDetailText('desc')!.replaceAll('\n', ' '), startsWith(g.itemEffect(Item.royalSword, null, 3).first));
    expect([for (final a in b.bagActions) a.$1], [BagAction.giveTroops], reason: 'no Carve: it takes the +0 ones');
    await tapOn(tester, b.bagSlot(Item.royalSword));
    expect((b.picked, b.pickedPlus), (Item.royalSword, 0), reason: 'the +0 cell picks the +0 ones');

    // Its tooltip: "Royal Sword +3", what one does at +3, how many of that stack.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(b.bagStackSlot(Item.sword, 2).center);
    await frames(tester, 40);
    expect(b.tooltipShown?.$1, 'Sword +2');
    expect(b.tooltipShown!.$2, containsAll([g.itemEffect(Item.sword, null, 2).first, 'In bag: 1']));
    await mouse.removePointer();
    await frames(tester, 40);
  });

  testWidgets('on the field a stack in hand goes on a troop\'s type at its plus: a tap on the troop', (tester) async {
    final b = await boot(tester);
    final g = b.state = enhanceGame()
      ..inTown = false
      ..townAt = null;
    final knight = g.troops.firstWhere((u) => u.type == 'knight')..pos = const Point(40.0, 50.0);
    for (var i = 0; i < 300 && !b.bookTabs.any((t) => t.$1 == 'bag'); i++) {
      await frames(tester, 1); // the book floats in between waves
    }
    await turnTo(tester, b, 'bag');
    await tapOn(tester, b.bagChip(BagCategory.items));
    await tapOn(tester, b.bagStackSlot(Item.sword, 2));
    expect((b.picked, b.pickedPlus), (Item.sword, 2));
    await tester.tapAt(b.toScreen(knight.pos.x, knight.pos.y - 3));
    await frames(tester, 3);
    expect((g.countOf('knight', Item.sword), g.bagOf(Item.sword, 2), g.bagOf(Item.sword)), (1, 0, 1));
    expect(g.plusesOn('knight', Item.sword), [2], reason: 'its plus went with it');
    expect(b.picked, isNull, reason: 'none left at +2');
    await frames(tester, 40);
  });

  testWidgets("the Shop sells a stack at its own price: its steps' gold and stones counted in", (tester) async {
    final b = await boot(tester);
    final g = b.state = enhanceGame();
    await frames(tester, 40);
    await turnTo(tester, b, 'store');
    await tapOn(tester, b.shopTabAt(ShopTab.sell));
    expect([for (final c in b.bagLootCells) c.$1], contains((kind: Item.sword, plus: 2)));
    await tapOn(tester, b.bagStackSlot(Item.sword, 2));
    expect(b.shopBasket, {(kind: Item.sword, plus: 2): 1}, reason: 'in the Sell Basket at 1');
    final price = g.sellPriceAt(Item.sword, 2);
    expect(price, greaterThan(g.sellPrice(Item.sword)));
    expect(b.shopBasketLines.single.$3, '1 x ${shortPrice(price)} = ${shortPrice(price)}');
    final gold = g.gold;
    await tapOn(tester, b.shopAt('sell'));
    expect((g.bagOf(Item.sword, 2), g.gold, g.bagOf(Item.sword)), (0, gold + price, 1));
    expect(b.shopPick, isNull, reason: 'sold out: the pick goes');
    await frames(tester, 40);
  });
}
