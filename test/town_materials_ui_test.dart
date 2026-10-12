// The Towns' materials on screen (decisions-log 221; docs/ui-hud.md "The Bag's Materials"): the Bag's Materials chip
// (its page empty with none held), its cells in the game's order, all 30 on one page on the desk and on three at 915x412
// (12 a page on the shorter landscape book, decisions-log 283),
// a material's facing page (what drops it, what it is for, the Smithy's row, no Sell) and its tooltip; the "VICTORY!"
// line's materials (no item drops); a dropped material's hop onto the field. One TdGame per widget test.
//
// Never let a wave be won or the game end here: the board saves after a pick, into the queue's temp HOME
// (flutter_test_config.dart), never the real save.
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'bag_pages.dart';
import 'hud_font.dart';

const desk = Size(1266, 713), wide = Size(915, 412);

/// Boots one TdGame in a [size] window, past the welcome screen, with the game's font and the minimap folded.
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

/// Turns the open book to its Bag page.
Future<void> openBag(WidgetTester tester, Board b) async {
  if (b.messageBox != Rect.zero) await tapOn(tester, b.messageBox.center);
  await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
  expect(b.bagOpen, isTrue);
}

/// A board game between waves at wave 20, a soldier beside the free priest, a few items and, with [materials], every one
/// of the 30 dropped materials (the n-th n of it; the forge's two stones are forge_smithy_ui_test.dart's).
Game matsGame({bool materials = true}) {
  final g = Game(Random(1)).boardRules()
    ..armyMax = null
    ..gold = 50000
    ..wave = 20;
  expect(g.autoPlace('soldier'), isTrue);
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.inventory.addAll({Item.sword: 3, Item.bow: 1});
  if (materials) g.materials.addAll({for (final (i, m) in droppedMats.indexed) m: i + 1});
  return g;
}

void main() {
  for (final (size, pages) in const [(desk, 1), (wide, 3)]) {
    final at = '${size.width.round()}x${size.height.round()}';

    testWidgets('at $at the Materials chip shows the 30 in the game\'s order on $pages page(s); a pick\'s facing page says '
        'what drops it and what it is for, its one row the Smithy\'s, no Sell', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = matsGame();
      await frames(tester, 30);
      await openBag(tester, b);
      expect(b.bagChip(BagCategory.materials), isNot(Rect.zero));
      // All: the items, then the materials (no relic, no Artifact here).
      expect(bagKinds(g, BagCategory.all), [Item.sword, Item.bow, ...droppedMats]);
      await tapOn(tester, b.bagChip(BagCategory.materials).center);
      await frames(tester, 3);
      expect((b.bagCategory, b.bagPages), (BagCategory.materials, pages));
      final shown = [for (final (k, _) in b.bagCells) k];
      expect(shown, droppedMats.take(pages == 1 ? 30 : b.bagPageSizes.$2).toList(), reason: at);
      if (pages > 1) {
        await tapOn(tester, b.bagPager('on').center);
        await frames(tester, 3);
        final per = b.bagPageSizes.$2;
        expect([for (final (k, _) in b.bagCells) k], droppedMats.skip(per).take(per).toList());
        await tapOn(tester, b.bagPager('back').center);
        await frames(tester, 3);
      }
      await bagTo(tester, b, Mat.slimeGel);
      expect(b.bagMarks(Mat.slimeGel)!.count, null, reason: 'one: no capsule');
      await bagTo(tester, b, Mat.batWing);
      expect(b.bagMarks(Mat.batWing)!.count, 2);
      // Slime Gel picked: what it is, what drops it, what it is for; the Smithy's row; never a Sell.
      final gel = b.bagCells.firstWhere((c) => c.$1 == Mat.batWing).$2;
      await tapOn(tester, gel.center);
      await frames(tester, 3);
      expect(b.picked, Mat.batWing);
      expect((b.bagDetailText('name'), b.bagDetailText('count')), ('Bat Wing', 'x2'));
      expect(b.bagDetailText('desc')!.replaceAll('\n', ' '), 'Common material. Bats drop it, a bat mini boss 3, a boss 4.');
      expect(b.bagDetailText('use')!.replaceAll('\n', ' '), matUseLine);
      expect([for (final (a, _, _) in b.bagActions) a], [BagAction.smithy]);
      expect(b.bagDetailText('title:smithy'), 'Craft at the ${Words.smithy}');
      expect(['Fang, Fury. ${Words.onlyInTown}', Words.onlyInTown, 'Fang, Fury'], contains(b.bagDetailText('hint:smithy')));
      if (size == desk) expect(b.bagDetailText('hint:smithy'), 'Fang, Fury. ${Words.onlyInTown}');
      // A Trophy says who drops it (every material's words: forge_drops_test.dart).
      expect(g.matSource(Mat.evilEye), 'Trophy. Every mini boss drops one.');
      expect(g.matSource(Mat.lichOrb), 'Trophy. The Necromancer drops one as a mini boss or boss.');
    });
  }

  testWidgets('a game holding no materials comes in: the Bag has its Materials chip all the same, and a Materials page left '
      'on stays, empty: "No materials yet."', (tester) async {
    final b = await boot(tester, desk);
    b.state = matsGame();
    await frames(tester, 30);
    await openBag(tester, b);
    await tapOn(tester, b.bagChip(BagCategory.materials).center);
    expect(b.bagCategory, BagCategory.materials);
    b.state = matsGame(materials: false); // another game comes in, the Materials page left on
    await frames(tester, 30);
    if (!b.bagOpen) await openBag(tester, b);
    expect(b.bagChip(BagCategory.materials), isNot(Rect.zero));
    expect(b.bagChip(BagCategory.artifacts), isNot(Rect.zero), reason: 'the Shop is open at wave 20');
    expect(b.bagCategory, BagCategory.materials, reason: 'no reset to All');
    expect(b.bagCells, isEmpty, reason: 'no material held');
    expect(b.bagEmpty, ['No ${Words.materials.toLowerCase()} yet.', 'Monsters drop them.']);
    await tapOn(tester, b.bagChip(BagCategory.all).center);
    expect([for (final (k, _) in b.bagCells) k], [Item.sword, Item.bow]);
    await frames(tester, 40); // the last tap's gesture timer runs out
  });

  testWidgets('"VICTORY!" lists the materials the wave dropped, each kind once with its count, in their order', (tester) async {
    final b = await boot(tester, desk);
    final g = b.state = matsGame();
    await frames(tester, 10);
    g
      ..lastMaterials = {Mat.evilEye: 1, Mat.slimeGel: 3}
      ..victoryAt = g.t;
    await frames(tester, 10);
    expect(b.victoryLoot, [(Mat.slimeGel, 3), (Mat.evilEye, 1)]);
  });

  testWidgets('a dropped material hops onto the field, and lies there (mat_loot_test.dart)', (tester) async {
    final b = await boot(tester, desk);
    final g = b.state = matsGame();
    await frames(tester, 10);
    final before = b.fieldFx;
    g.waveMaterials[Mat.soulOrb] = 1; // the kill's tally ([Game.matPops] comes with it)
    g.matPops.add((const Point(200.0, 60.0), Mat.soulOrb, 1));
    await frames(tester, 2);
    expect(b.fieldFx, before + 1);
    expect(g.matPops, isEmpty);
    expect(b.matLoot, [(Mat.soulOrb, 1, false)]);
  });
}
