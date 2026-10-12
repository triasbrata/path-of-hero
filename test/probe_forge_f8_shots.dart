// Enhance's UI (decisions-log 255; ui-hud.md "The Smithy" and the Bag's "Enhanced stacks"): offscreen shots into
// <probe root>/shots/forge-F8/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_forge_f8_shots.dart"]` with a mirror as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir), and wins no wave. The Towns and the forge on, the dice seeded.
//
// At 1266x713, 1164x777 and 412x860 (`<size>`), in the Town before wave 31 with a mixed army (the knight holding a Sword
// at +2 and a Shield at +4), Royal Swords at +0 to +5, a Sword at +1, a Gold Amulet at +2, two Mithril and a
// Starmetal: enhance-<size> (the Enhance tab, the Royal Sword +3 picked), stone-<size> (Mithril picked), enhanced-<size>
// (after a press: "Royal Sword enhanced to +4!"), top-<size> (the +5: "Max: +5"), bag-<size> (the Bag's Items, the +0 to
// +5 tints and tags, the +3 picked), give-<size> (its types listed), army-<size> (the knight's detail: the tinted Sword
// and Shield, "+2" and "+4"), shop-<size> (the Town's Shop selling the Sword +1).
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/forge-F8');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game in the Town before wave 31 with the Towns and the forge on, seeded: a mixed army (the knight holding a
/// Sword +2 and a Shield +4), 40,000 gold, Royal Swords at +0 (two) to +5, a Sword +1, a Gold Amulet +2, a Prayer
/// Beads, two Mithril, a Starmetal and a few materials.
Game board() {
  final g = Game(Random(seed), Random(seed + 100)).boardRules()
    ..slots = Random(seed + 300)
    ..loot = Random(seed + 200)
    ..draft = Random(seed + 500)
    ..townDice = Random(seed + 600)
    ..matDice = Random(seed + 700)
    ..armyMax = null
    ..gold = 40000
    ..wave = 30
    ..townAt = 31
    ..inTown = true;
  for (final type in ['knight', 'archer', 'priest', 'wizard', 'soldier', 'lancer']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.enhancedBag.addAll({(Item.sword, 2): 1, (Item.shield, 4): 1});
  expect(g.useItem(Item.sword, 'knight', plus: 2), isTrue);
  expect(g.useItem(Item.shield, 'knight', plus: 4), isTrue, reason: '${g.whyNot(Item.shield, 'knight', plus: 4)}');
  g.inventory.addAll({Item.royalSword: 2, Item.prayerBeads: 1});
  g.enhancedBag.addAll({
    for (var p = 1; p <= 5; p++) (Item.royalSword, p): 1,
    (Item.sword, 1): 1,
    (Item.goldAmulet, 2): 1,
  });
  g.materials.addAll({Mat.mithril: 2, Mat.starmetal: 1, Mat.evilEye: 2, Mat.ironScrap: 5, Mat.graveSteel: 1, Mat.wolfClaw: 4});
  return g;
}

void main() {
  for (final size in const [Size(1266, 713), Size(1164, 777), Size(412, 860)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets(tag, (tester) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(loadHudFontNow);
      final game = TdGame();
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: GameWidget(game: game)));
      for (var i = 0; i < 3000 && !game.isLoaded; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(game.isLoaded, isTrue);
      final b = game.board
        ..welcome = null
        ..miniMapOpen = false
        ..autoStart.set(false);

      Future<void> shot(String name) async {
        await frames(tester, 20);
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = (await tester.runAsync(() => boundary.toImage()))!;
        final file = '$out/$name-$tag.png';
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File(file)
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        final (left, right) = b.bookPages;
        // ignore: avoid_print
        print('wrote $file; page ${b.bookPage} tab ${b.smithyTab} pick ${b.smithyEnhancePick} small ${b.smithySmallBoard}; '
            'pages $left $right; board ${b.smithyEnhanceCells.length} cells ${b.smithyEnhanceCells.map((c) => c.$2).firstOrNull}; '
            'name "${b.bagDetailText('name')}" count ${b.bagDetailText('count')}; effect "${b.smithyText('effect')?.replaceAll('\n', ' / ')}"; '
            'tier "${b.smithyText('tier')?.replaceAll('\n', ' / ')}"; recipe "${b.smithyText('recipe')}"; '
            'enhance "${b.smithyText('enhance')}" ${b.smithyAt('enhance')}; craft "${b.smithyText('craft')}"; '
            'next "${b.smithyText('next')}"; give "${b.smithyText('give')}" ${b.smithyAt('give')}; '
            'bag ${b.bagLootCells.length} cells; picked ${b.picked} +${b.pickedPlus}; message ${b.message}');
      }

      Future<void> tap(Rect r) async {
        expect(r, isNot(Rect.zero));
        await tester.tapAt(r.center);
        await frames(tester, 3);
      }

      Future<void> quiet() async {
        if (b.messageBox != Rect.zero) await tap(b.messageBox);
      }

      Rect cell(Enum kind, [int plus = 0]) => b.smithyEnhanceCells.firstWhere((c) => c.$1 == (kind: kind, plus: plus)).$2;

      final g = b.state = board();
      await frames(tester, 40);
      await quiet();
      await tap(b.smithyAt('tab:enhance'));
      await tap(cell(Item.royalSword, 3));
      await shot('enhance');
      await tap(cell(Mat.mithril));
      await shot('stone');
      await tap(cell(Item.royalSword, 3));
      await tap(b.smithyAt('enhance'));
      await shot('enhanced');
      await quiet();
      await tap(cell(Item.royalSword, 5));
      await shot('top');

      await tap(b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2);
      await tap(b.bagChip(BagCategory.items));
      await tap(b.bagStackSlot(Item.royalSword, 2));
      await shot('bag');
      await tap(b.bagAction(BagAction.giveTroops));
      await shot('give');

      await tap(b.bookTabs.firstWhere((t) => t.$1 == 'store').$2);
      await tap(b.shopTabAt(ShopTab.sell));
      await tap(b.bagStackSlot(Item.sword, 1));
      await shot('shop');
      // ignore: avoid_print
      print('shop $tag: basket ${b.shopBasketLines.map((l) => l.$3)} price ${g.sellPriceAt(Item.sword, 1)}');

      // Out of the Town (its book has no Army page).
      expect(g.leaveTown(), isTrue);
      for (var i = 0; i < 300 && !b.bookTabs.any((t) => t.$1 == 'troops'); i++) {
        await frames(tester, 1); // the Town fades out, the book floats in on the field
      }
      await frames(tester, 20);
      await tap(b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2);
      await tap(b.troopRow('knight'));
      await shot('army');
      // ignore: avoid_print
      print('army $tag: stats ${b.troopDetailWords('stats')}; knight pluses sword ${g.plusesOn('knight', Item.sword)} '
          'shield ${g.plusesOn('knight', Item.shield)}');

      await frames(tester, 40);
    });
  }
}
