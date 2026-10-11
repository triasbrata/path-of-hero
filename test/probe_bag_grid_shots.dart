// The Bag's grid seen (decisions-log 187; ui-hud.md "Tas"): offscreen shots into <probe root>/shots/bag-grid/
// (`OUT`). A probe, not part of the suite (no `_test.dart`): queue `["test", "test/probe_bag_grid_shots.dart"]` with the
// worktree as `dir`. It never touches the real save (flutter_test_config.dart's temp dir), and wins no wave. The lines
// marked `grid only` need the grid's getters: a copy without them runs on a checkout from before it (the before shots).
//
// It writes, at 1266x713, 412x860 and 915x412 (`desk-` / `phone-` / `wide-`): bag (a long run's bag: five items, three
// small relics, Pusaka bound, asleep, in the Gudang and an oath, nothing picked), bag-item (the sword picked: its Give
// rows), bag-vault (the Grail in the Gudang picked: its Asah and Lebur), bag-bound (Dragon Heart picked), bag-empty
// (nothing owned; the Bag sells nothing, decisions-log 296); and with the grid:
// bag-items (the Items chip), bag-hover (the mouse on the bow's cell), bag-relics-empty (the Relics chip, none in the
// bag, one worn), bag-new (NEW and ▲), bag-note (the save's suggestion strip), bag-lebur (the Grail's Lebur picker),
// bag-all (every Pusaka: page 1), bag-all-last (its last page), bag-artifacts (the Artifacts chip), bag-pressed (a press
// held on a Legenda cell, beside the pick). The catalog's 12 Pusaka and the bag's 11 kinds (23 cells) fill two pages
// only at 915x412 (20 a page, 16 with the pager).
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui' show PointerDeviceKind;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/bag-grid');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game between waves at wave 30 (the Shop open), no army cap, gold to spare, a soldier and a knight beside the
/// free priest at their posts.
Game bagGame() {
  final g = Game(Random(1)).boardRules()
    ..armyMax = null
    ..gold = 5000000
    ..wave = 30;
  for (final type in ['soldier', 'knight']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  return g;
}

/// [bagGame] with a long run's bag (as bag_grid_test.dart's).
Game stocked() {
  final g = bagGame();
  g.inventory.addAll({Item.sword: 86, Item.shield: 1, Item.bow: 3, Item.potion: 1200, Item.staff: 2});
  g.relicBag.addAll({Relic.fang: 1, Relic.fury: 5, Relic.guard: 2});
  g
    ..givePusaka(Relic.dragonHeart, type: 'knight', stars: 2)
    ..givePusaka(Relic.voidEye, type: 'wizard')
    ..givePusaka(Relic.grail)
    ..givePusaka(Relic.dawnStar, stars: 3)
    ..givePusaka(Relic.oathOfOne);
  return g;
}

void main() {
  testWidgets('bag grid shots', (tester) async {
    tester.view
      ..physicalSize = const Size(1266, 713)
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

    Future<void> shot(String name, [int settle = 20]) async {
      await frames(tester, settle);
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = (await tester.runAsync(() => boundary.toImage()))!;
      await tester.runAsync(() async {
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
      // ignore: avoid_print
      print('wrote $out/$name.png ${img.width}x${img.height}; picked ${b.picked}, message ${b.message}');
    }

    Future<void> tap(Offset p) async {
      await tester.tapAt(p);
      await frames(tester);
    }

    Future<void> quiet() async {
      if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
    }

    Future<void> page(String name) async {
      await quiet();
      await tap(b.bookTabs.firstWhere((t) => t.$1 == name).$2.center);
    }

    Future<void> start(Game g) async {
      b.state = g;
      await frames(tester, 50);
      await page('troops');
      await page('bag');
      await tap(b.bagChip(BagCategory.all).center); // grid only: the chip is the session's
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860)), ('wide', Size(915, 412))]) {
      tester.view.physicalSize = size;
      var g = stocked();
      await start(g);
      await shot('$tag-bag');
      await tap(b.bagSlot(Item.sword).center);
      await shot('$tag-bag-item');
      await tap(b.bagSlot(Relic.grail).center);
      await shot('$tag-bag-vault');
      await tap(b.bagSlot(Relic.dragonHeart).center);
      await shot('$tag-bag-bound');
      await start(bagGame());
      await shot('$tag-bag-empty');

      // The grid's own (grid only, every line to the loop's end).
      g = bagGame()..relicBag[Relic.fang] = 0; // grid only
      g.troops.firstWhere((u) => u.alive).relics.add(Relic.guard); // grid only
      g.inventory[Item.sword] = 2; // grid only
      await start(stocked()); // grid only
      await tap(b.bagChip(BagCategory.items).center); // grid only
      await shot('$tag-bag-items'); // grid only
      await tap(b.bagChip(BagCategory.all).center); // grid only
      final mouse = TestPointer(7, PointerDeviceKind.mouse); // grid only
      await tester.sendEventToBinding(mouse.hover(b.bagSlot(Item.bow).center)); // grid only
      await shot('$tag-bag-hover', 3); // grid only: before the tooltip's delay
      await tester.sendEventToBinding(mouse.hover(b.bookArea.topLeft)); // grid only
      await frames(tester, 10); // grid only
      await start(g); // grid only
      await tap(b.bagChip(BagCategory.relics).center); // grid only
      await shot('$tag-bag-relics-empty'); // grid only
      await tap(b.bagChip(BagCategory.all).center); // grid only
      g = stocked(); // grid only
      await start(g); // grid only
      for (final MapEntry(key: item, value: need) in g.recipeOf('soldier').entries) { // grid only
        g.inventory[item] = need + 1; // grid only
      } // grid only
      g.inventory[Item.gloves] = 4; // grid only
      g.givePusaka(Relic.godThunder); // grid only
      await shot('$tag-bag-new'); // grid only
      g.pusaka[Relic.dragonHeart]!.suggested = true; // grid only
      await shot('$tag-bag-note'); // grid only
      g.pusaka[Relic.dragonHeart]!.suggested = false; // grid only
      await tap(b.bagSlot(Relic.grail).center); // grid only
      await tap(b.leburButton.center); // grid only
      await shot('$tag-bag-lebur'); // grid only
      g = stocked(); // grid only
      for (final r in Relic.values) { // grid only
        if (r.pusaka && !g.pusaka.containsKey(r)) g.givePusaka(r, stars: 1 + r.index % 3); // grid only
        if (!r.pusaka) g.relicBag[r] = (g.relicBag[r] ?? 0) + 1; // grid only
      } // grid only
      for (final i in Item.values) { // grid only: every kind, 23 cells
        g.inventory[i] = (g.inventory[i] ?? 0) + 1; // grid only
      } // grid only
      await start(g); // grid only
      await shot('$tag-bag-all'); // grid only
      while (b.bagPage < b.bagPages - 1) { // grid only
        await tap(b.bagPager('on').center); // grid only
      } // grid only
      await shot('$tag-bag-all-last'); // grid only
      await tap(b.bagChip(BagCategory.artifacts).center); // grid only
      await shot('$tag-bag-artifacts'); // grid only
      final legend = b.bagCells.firstWhere((c) => (c.$1 as Relic).rarity == Rarity.legenda); // grid only
      final next = b.bagCells.firstWhere((c) => c.$1 != legend.$1 && (c.$1 as Relic).rarity == Rarity.legenda); // grid only
      await tap(next.$2.center); // grid only
      final press = await tester.startGesture(legend.$2.center); // grid only
      await shot('$tag-bag-pressed', 3); // grid only
      await press.cancel(); // grid only
      await frames(tester, 10); // grid only
    }
    b.state = Game();
    await frames(tester, 10);
  });
}
