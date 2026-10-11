// The Bag's right page seen, for each pick (decisions-log 187; ui-hud.md "Tas"): offscreen shots into
// <probe root>/shots/bag-detail/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_bag_detail_shots.dart"]` with the worktree as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir), and wins no wave. The lines marked `detail only` need the detail's own getters:
// a copy without them runs on a checkout from before it (the before shots).
//
// It writes, at 1266x713, 412x860 and 915x412 (`desk-` / `phone-` / `wide-`): none (nothing picked: blank page; the troops that
// wear relics), none-empty (nothing picked, no relic worn), item (the sword: its Give rows),
// relic (Fury), vault (the Grail in the Gudang: Sharpen and Melt; the Bag sells nothing, decisions-log 296), bound (Dragon Heart on the knight), asleep (Void Eye on the wizard, none alive),
// oath (Oath of One), melt (the Grail's Melt picker), item-midwave and vault-midwave (a wave on: greyed, why); and with
// the detail: vault-ukir and item-ukir (Carve's strip, the Give rows at the list's end; decisions-log 196, and
// test/probe_carve_shots.dart).
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/bag-detail');

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

/// [bagGame] with a long run's bag (as bag_grid_test.dart's), and the soldier wearing a Fang.
Game stocked() {
  final g = bagGame();
  g.inventory.addAll({Item.sword: 86, Item.shield: 1, Item.bow: 3, Item.potion: 1200, Item.staff: 2});
  g.relicBag.addAll({Relic.fang: 1, Relic.fury: 5, Relic.guard: 2, Relic.thorns: 12});
  g
    ..givePusaka(Relic.dragonHeart, type: 'knight', stars: 2)
    ..givePusaka(Relic.voidEye, type: 'wizard')
    ..givePusaka(Relic.grail)
    ..givePusaka(Relic.dawnStar, stars: 3)
    ..givePusaka(Relic.oathOfOne);
  g.troops.firstWhere((u) => u.alive && u.type == 'soldier').relics.add(Relic.fang);
  return g;
}

void main() {
  testWidgets('bag detail shots', (tester) async {
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
    }

    Future<void> pick(Enum kind) async {
      if (b.picked != kind) await tap(b.bagSlot(kind).center);
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860)), ('wide', Size(915, 412))]) {
      tester.view.physicalSize = size;
      await start(stocked());
      await shot('$tag-none');
      await pick(Item.sword);
      await shot('$tag-item');
      await pick(Relic.fury);
      await shot('$tag-relic');
      await pick(Relic.grail);
      await shot('$tag-vault');
      await pick(Relic.dragonHeart);
      await shot('$tag-bound');
      await pick(Relic.voidEye);
      await shot('$tag-asleep');
      await pick(Relic.oathOfOne);
      await shot('$tag-oath');
      await pick(Relic.grail);
      await tap(b.leburButton.center);
      await shot('$tag-melt');
      await start(bagGame()..inventory[Item.sword] = 3);
      await shot('$tag-none-empty');

      // A wave on: the book opened by hand, Sell / Melt greyed with why.
      final g = stocked();
      await start(g);
      g.startWave();
      await frames(tester, 40); // the book shuts for the wave
      for (var i = 0; i < 3 && b.bookTabs.isEmpty; i++) {
        await quiet();
        await tap(b.bookButton.center);
        await frames(tester, 40);
      }
      if (b.bookTabs.isNotEmpty) {
        if (!b.bagOpen) await page('bag');
        await pick(Item.sword);
        await shot('$tag-item-midwave');
        await pick(Relic.grail);
        await shot('$tag-vault-midwave');
      } else {
        // ignore: avoid_print
        print('$tag: the book did not open mid-wave (bookButton ${b.bookButton}); no mid-wave shots');
      }

      // Carve's strip and the Give rows (detail only, to the loop's end).
      await start(stocked()); // detail only
      await pick(Relic.grail); // detail only
      await shot('$tag-vault-ukir'); // detail only
      await pick(Item.sword); // detail only
      final wheel = TestPointer(9, PointerDeviceKind.mouse); // detail only
      await tester.sendEventToBinding(wheel.hover(b.assignList.center)); // detail only
      for (var i = 0; i < 30; i++) { // detail only: the list wheeled to its end
        await tester.sendEventToBinding(wheel.scroll(const Offset(0, 60))); // detail only
        await frames(tester); // detail only
      } // detail only
      await tester.sendEventToBinding(wheel.hover(b.bookArea.topLeft)); // detail only
      await shot('$tag-item-ukir'); // detail only
    }
    b.state = Game();
    await frames(tester, 10);
  });
}
