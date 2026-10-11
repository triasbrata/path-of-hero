// The Smithy's Wishlist tab, where wishes are made, and the places that add them (decisions-log 300, 302, 303; ui-hud.md
// "The Smithy", "The Bag", "Army"): offscreen shots into <probe root>/shots/wishlist-tab/ (`OUT`). A probe, not part
// of the suite (no `_test.dart`): queue `["test", "test/probe_smithy_wish_shots.dart"]` with a mirror as `dir`
// (`--plain-name <size>` for one size). It never touches the real save (the queue's temp HOME); the dice are seeded.
//
// At 1600x947, 1266x713, 1164x777 and 915x412 (<size>), a board game after wave 20 in a Town: the knight holds a Sword,
// the Bag an Amulet; whole sets wished for the knight, the archer and the priest, a Royal Helm for the knight, and free
// lines for the first small relic (×2) and a Steel Sword: wish-<size> (the Wishlist tab the Smithy opens on: a group per
// type, a row per thing to make), wish-p2-<size> (its next page), wish-crafted-<size> (the knight's Shield crafted from
// its row: "Give to Knight" in it), wish-given-<size> (given), wish-armed-<size> (the knight's Remove tapped once),
// wish-empty-<size> (no wishes); craft-page-<size> and relic-page-<size> (an item's and a relic's Smithy page: no types'
// chips, the status and the free line), bag-page-<size> (an item's Bag page with its free line), army-plus-<size> (the
// soldier's Army detail by its needs: "Wishlist all" and the rows' "+").
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
import 'page_scroll.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/wishlist-tab');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Game board({bool wishes = true, int wave = 20}) {
  final g = Game(Random(7), Random(107)).boardRules()
    ..townDice = Random(3)
    ..armyMax = null
    ..wave = wave
    ..gold = 4450
    ..townAt = wave + 1
    ..inTown = true;
  for (final type in ['soldier', 'knight', 'archer', 'priest', 'lancer', 'wizard']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.materials.addAll({
    for (final (i, m) in Mat.values.indexed)
      if (i < 22) m: 1 + i * 5 % 13,
  });
  g.materials.addAll({Mat.wolfClaw: 3, Mat.orcEar: 2, Mat.boneArrow: 1});
  g.materials.remove(Mat.leatherStrap);
  g.upgrades['knight'] = [Item.sword];
  g.inventory[Item.amulet] = 1;
  if (wishes) {
    g
      ..wishSet('knight')
      ..wishSet('archer')
      ..wishSet('priest')
      ..wish('knight', Item.royalHelm)
      ..wishFreeAdd(smithyRelics(g).first, 2)
      ..wishFreeAdd(Item.steelSword);
  }
  return g;
}

void main() {
  for (final size in const [Size(1600, 947), Size(1266, 713), Size(1164, 777), Size(915, 412)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('smithy wish shots $tag', (tester) async {
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
        ..miniMapOpen = false;
      b.autoStart.set(false);

      Future<void> shot(String name, [int settle = 20]) async {
        await frames(tester, settle);
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = (await tester.runAsync(() => boundary.toImage()))!;
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name-$tag.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        final shown = (b.smithyText('wishPage') ?? '').split('|').where((k) => k.isNotEmpty);
        // ignore: avoid_print
        print('SHOT $name-$tag page ${b.bookPage} tab ${b.smithyTab.name} needed "${b.smithyText('wishNeeded')}" '
            'pages ${b.smithyWishPage + 1}/${b.smithyWishPages} per "${b.smithyText('wishPer')}" left ${b.bookPages.$1} right ${b.bookPages.$2} '
            'rows ${[for (final k in shown) '$k "${b.smithyText('wishTitle:$k')}" [${b.smithyText('wishParts:$k')}] "${b.smithyText('wishStatus:$k')}" '
                'craft "${b.smithyText('wishCraft:$k')}" give "${b.smithyText('wishGive:$k')}" ${b.smithyAt('wishRow:$k')}']} '
            'empty "${b.smithyText('wishEmpty')}" free "${b.smithyText('free')}" / "${b.bagDetailText('free')}" '
            'missing "${b.smithyText('wishMissing')}" wishlist "${b.smithyText('wishlist')}" chips "${b.smithyText('wishTypes')}" '
            'msg "${b.message}" wishAll ${b.troopDetailWords('wishAll')} plus ${b.troopDetail('wishOne:sword')}');
      }

      Future<void> tap(Rect r) async {
        expect(r, isNot(Rect.zero));
        await tester.tapAt(r.center);
        await frames(tester, 3);
      }

      Future<void> shut() async {
        if (b.messageBox != Rect.zero) await tap(b.messageBox);
      }

      Future<void> scrollTo(String key) async {
        b.troopDetailScroll = 0;
        await frames(tester, 2);
        for (var i = 0; i < 80 && (b.troopDetail(key) == Rect.zero || b.troopDetail(key).bottom > b.troopDetailBody.bottom - 1); i++) {
          final was = b.troopDetailScroll;
          b.troopDetailScroll = was + 16;
          await frames(tester, 2);
          if (b.troopDetailScroll == was) break;
        }
      }

      final g = b.state = board();
      await frames(tester, 40);
      await shut();
      expect((b.bookPage, b.smithyTab), ('smithy', SmithyTab.wishlist));
      await shot('wish');
      if (b.smithyWishPages > 1) {
        await tap(b.smithyWishPager('on'));
        await shot('wish-p2');
        await tap(b.smithyWishPager('back'));
      }
      // The knight's Shield from its row: Craft, then Give to Knight.
      while (b.smithyAt('wishCraft:knight:shield') == Rect.zero && b.smithyWishPage < b.smithyWishPages - 1) {
        await tap(b.smithyWishPager('on'));
      }
      await tap(b.smithyAt('wishCraft:knight:shield'));
      await shut();
      await shot('wish-crafted');
      await tap(b.smithyAt('wishGive:knight:shield'));
      expect(g.countOf('knight', Item.shield), 1);
      await shot('wish-given');
      await shut();
      await tap(b.smithyAt('wishOffAll:knight'));
      await shot('wish-armed', 3);
      await frames(tester, 200);

      // The pages that add: an item's and a relic's Smithy page, an item's Bag page.
      await tap(b.smithyAt('tab:items'));
      await shot('craft-page');
      await tap(b.smithyAt('tab:relics'));
      final relic = smithyRelics(g).first;
      while (!b.smithyCells.any((c) => c.$1 == relic) && b.smithyBoardPage < b.smithyBoardPages - 1) {
        await tap(b.smithyBoardPager('on'));
      }
      await tap(b.smithyCells.firstWhere((c) => c.$1 == relic).$2);
      await scrolledTo(tester, b, 'smithy', () => b.smithyAt('freeAdd'));
      await shot('relic-page');
      b.setPageScroll('smithy', 0);
      await tap(b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2);
      await tap(b.bagChip(BagCategory.items));
      final amulet = b.bagCells.firstWhere((c) => c.$1 == Item.amulet).$2;
      await tap(amulet);
      await shot('bag-page');
      await tap(b.bookTabs.firstWhere((t) => t.$1 == 'smithy').$2);
      await tap(b.smithyAt('tab:wishlist'));

      b.state = board(wishes: false);
      await frames(tester, 40);
      await shut();
      await shot('wish-empty');

      final h = b.state = board(wishes: false);
      h.leaveTown();
      await frames(tester, 40);
      await shut();
      await tap(b.troopRow('soldier'));
      await scrollTo('wishAll');
      await shot('army-plus');
      b.state = Game();
      await frames(tester, 5);
    });
  }
}
