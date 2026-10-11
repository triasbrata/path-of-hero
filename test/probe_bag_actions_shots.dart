// The Bag's right page, action first (decisions-log 202; ui-hud.md "Tas"), seen: offscreen shots into
// <probe root>/shots/bag-actions/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_bag_actions_shots.dart"]` with the worktree as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir), and wins no wave. The lines marked `actions only` use the action list's getters:
// a copy without them runs on a checkout from before it (the before shots).
//
// It writes, at 1266x713, 412x860 and 915x412 (`desk-` / `phone-` / `wide-`), at wave 45 (the Shop open, Carve open):
// item (the Sword picked), give (its "Give to troops" chooser), feed (its "Give to an Artifact" chooser; before: the
// list wheeled to the Give rows), relic (Fury), equip (Fury's "Equip on a troop" chooser), vault (the Grail in the
// Vault), bound (Dragon Heart on the knight), types (Dragon Heart's "Move to a type" chooser) and none (nothing picked);
// with the action list also fang (a Fang worn and one in the bag), remove (its Remove from a troop chooser),
// oath (Oath of One) and melt (the Grail's Melt picker).
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/bag-actions');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game between waves at wave 45 (the Shop and Carve open), no army cap, gold to spare, a soldier and a knight
/// beside the free priest at their posts, the soldier wearing a Fang; a long run's bag, and Artifacts: Dragon Heart
/// ★2+3 on the knight, the Grail +2 (40 points on its bar) and Dawn Star in the Vault, God's Thunder on the soldier, Oath
/// of One.
Game stocked() {
  final g = Game(Random(1)).boardRules()
    ..armyMax = null
    ..gold = 5000000
    ..wave = 45;
  for (final type in ['soldier', 'knight']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.inventory.addAll({Item.sword: 86, Item.shield: 14, Item.boots: 9, Item.bow: 3, Item.gloves: 12, Item.potion: 120, Item.staff: 40});
  g.relicBag.addAll({Relic.fang: 1, Relic.fury: 5, Relic.guard: 2, Relic.thorns: 12});
  g
    ..givePusaka(Relic.dragonHeart, type: 'knight', stars: 2, ukir: 3)
    ..givePusaka(Relic.grail, ukir: 2)
    ..givePusaka(Relic.dawnStar)
    ..givePusaka(Relic.godThunder, type: 'soldier')
    ..givePusaka(Relic.oathOfOne);
  g.pusaka[Relic.grail]!.feed = 40;
  g.troops.firstWhere((u) => u.alive && u.type == 'soldier').relics.add(Relic.fang);
  return g;
}

void main() {
  testWidgets('bag actions shots', (tester) async {
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

    Future<void> tap(Rect r) async {
      if (r == Rect.zero) return;
      await tester.tapAt(r.center);
      await frames(tester);
    }

    Future<void> quiet() async {
      if (b.messageBox != Rect.zero) await tap(b.messageBox);
    }

    Future<void> page(String name) async {
      await quiet();
      await tap(b.bookTabs.firstWhere((t) => t.$1 == name).$2);
    }

    Future<void> start(Game g) async {
      b.state = g;
      await frames(tester, 50);
      await page('troops');
      await page('bag');
    }

    Future<void> pick(Enum kind) async {
      await quiet();
      if (b.picked != kind) await tap(b.bagSlot(kind));
    }

    Future<void> wheelDown() async {
      final wheel = TestPointer(9, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(wheel.hover(b.assignList.center));
      for (var i = 0; i < 40; i++) {
        await tester.sendEventToBinding(wheel.scroll(const Offset(0, 60)));
        await frames(tester);
      }
      await tester.sendEventToBinding(wheel.hover(b.bookArea.topLeft));
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860)), ('wide', Size(915, 412))]) {
      tester.view.physicalSize = size;
      await start(stocked());
      await shot('$tag-none');
      await pick(Item.sword);
      await shot('$tag-item');
      await tap(b.bagAction(BagAction.giveTroops)); // actions only
      await shot('$tag-give');
      await tap(b.bagBack); // actions only
      await tap(b.bagAction(BagAction.giveArtifact)); // actions only
      await wheelDown(); // actions only
      await shot('$tag-feed');
      await pick(Relic.fury);
      await shot('$tag-relic');
      await tap(b.bagAction(BagAction.equip)); // actions only
      await shot('$tag-equip');
      await pick(Relic.fang); // actions only: worn by the soldier, one in the bag
      await shot('$tag-fang'); // actions only
      await tap(b.bagAction(BagAction.takeOff)); // actions only: the wearer's row and its Remove tag
      await shot('$tag-remove'); // actions only
      await pick(Relic.grail);
      await shot('$tag-vault');
      await pick(Relic.dragonHeart);
      await shot('$tag-bound');
      await tap(b.bagAction(BagAction.types)); // actions only
      await shot('$tag-types');
      await pick(Relic.oathOfOne); // actions only
      await shot('$tag-oath'); // actions only
      await pick(Relic.grail); // actions only
      await tap(b.bagAction(BagAction.melt)); // actions only
      await shot('$tag-melt'); // actions only
      b.state = Game();
      await frames(tester, 5);
    }
    await frames(tester, 10);
  });
}
