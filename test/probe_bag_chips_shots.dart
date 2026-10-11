// The Bag's chips seen (decisions-log 198's "Bag chips"; ui-hud.md "Tas"): offscreen shots into
// <probe root>/shots/bag-chips/after/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_bag_chips_shots.dart"]` with the worktree as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir), and wins no wave. It uses only getters from before the restyle, so the same file
// shoots the before shots on a checkout of main (`--dart-define=OUT=<dir>`).
//
// It writes, at 1266x713, 412x860 and 915x412 (`desk-` / `phone-` / `wide-`): all (a long run's bag, the All chip on),
// items (the Items chip on), hover (the mouse on the Relics chip), paged (every kind: the pager, page 1; two pages only at
// 915x412 with today's catalog), paged-hover (the mouse on its ▸, where it shows), paged-last (its last page, the ▸ at its
// end), chooser (Fury picked, its Equip chooser: the type chips, All on), chooser-filter (two
// types on, the mouse on a third) and chooser-item (the sword's Give to troops: its type chips).
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/bag-chips/after');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game between waves at wave 30 (the Shop open), no army cap, gold to spare, a soldier, a knight and a wizard
/// beside the free priest at their posts.
Game bagGame() {
  final g = Game(Random(1)).boardRules()
    ..armyMax = null
    ..gold = 5000000
    ..wave = 30;
  for (final type in ['soldier', 'knight', 'wizard']) {
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
  testWidgets('bag chips shots', (tester) async {
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
    final mouse = TestPointer(7, PointerDeviceKind.mouse);

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
      print('wrote $out/$name.png ${img.width}x${img.height}; picked ${b.picked}, chips ${b.bagChip(BagCategory.all)} '
          '${b.bagChip(BagCategory.items)}, pager ${b.bagPager('back')} ${b.bagPager('on')}, type chips ${b.assignChip(null)} '
          '${b.assignChip('soldier')}');
    }

    Future<void> tap(Offset p) async {
      await tester.tapAt(p);
      await frames(tester);
    }

    Future<void> away() async {
      await tester.sendEventToBinding(mouse.hover(Offset.zero));
      await frames(tester, 10);
    }

    Future<void> page(String name) async {
      if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
      await tap(b.bookTabs.firstWhere((t) => t.$1 == name).$2.center);
    }

    Future<void> start(Game g) async {
      b.state = g;
      await frames(tester, 50);
      await page('troops');
      await page('bag');
      await tap(b.bagChip(BagCategory.all).center); // the chip is the session's
      await away();
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860)), ('wide', Size(915, 412))]) {
      tester.view.physicalSize = size;
      await start(stocked());
      await shot('$tag-all');
      await tap(b.bagChip(BagCategory.items).center);
      await away();
      await shot('$tag-items');
      await tester.sendEventToBinding(mouse.hover(b.bagChip(BagCategory.relics).center));
      await shot('$tag-hover', 3); // before the tooltip's delay
      await away();
      await tap(b.bagChip(BagCategory.all).center);

      // Every kind: past one page.
      final g = stocked();
      for (final r in Relic.values) {
        if (r.pusaka && !g.pusaka.containsKey(r)) g.givePusaka(r, stars: 1 + r.index % 3);
        if (!r.pusaka) g.relicBag[r] = (g.relicBag[r] ?? 0) + 1;
      }
      for (final i in Item.values) {
        g.inventory[i] = (g.inventory[i] ?? 0) + 1;
      }
      await start(g);
      await shot('$tag-paged');
      if (b.bagPager('on') != Rect.zero) {
        await tester.sendEventToBinding(mouse.hover(b.bagPager('on').center));
        await shot('$tag-paged-hover', 3);
        await away();
      }
      while (b.bagPage < b.bagPages - 1) {
        await tap(b.bagPager('on').center);
      }
      await away();
      await shot('$tag-paged-last');

      // A relic's chooser: the type chips, All on; then two types on and the mouse on a third.
      await start(stocked());
      await tap(b.bagSlot(Relic.fury).center);
      await tap(b.bagAction(BagAction.equip).center);
      if (b.assignFilter.isNotEmpty) await tap(b.assignChip(null).center);
      await away();
      await shot('$tag-chooser');
      await tap(b.assignChip('soldier').center);
      await tap(b.assignChip('wizard').center);
      await tester.sendEventToBinding(mouse.hover(b.assignChip('archer').center));
      await shot('$tag-chooser-filter', 3);
      await away();
      await tap(b.assignChip(null).center);

      // An item's Give to troops: its type chips.
      await tap(b.bagSlot(Item.sword).center);
      await tap(b.bagAction(BagAction.giveTroops).center);
      await away();
      await shot('$tag-chooser-item');
    }
    b.state = Game();
    await frames(tester, 10);
  });
}
