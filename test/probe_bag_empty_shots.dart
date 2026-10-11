// The Bag with nothing picked (decisions-log 241; ui-hud.md "Bag"): offscreen shots into
// <probe root>/shots/bag-empty/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_bag_empty_shots.dart"]` with the worktree as `dir`. It never touches the real save.
//
// At 1266x713, 1164x777, 915x412 and 412x860 (<size>): empty-<size> (the Bag, nothing picked, a troop holding a relic:
// the facing page is blank paper), picked-<size> (a cell picked), shop-<size> (the Town's Shop, nothing picked).
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/bag-empty');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game between waves at wave 20 with the Towns on, seeded, a mixed army, items, small relics, materials and a
/// Vault Artifact; in the Town ([inTown]) or on the field.
Game board({bool inTown = true}) {
  final g = Game(Random(seed), Random(seed + 100)).boardRules()
    ..slots = Random(seed + 300)
    ..loot = Random(seed + 200)
    ..draft = Random(seed + 500)
    ..townDice = Random(seed + 600)
    ..matDice = Random(seed + 700)
    ..towns = true
    ..armyMax = null
    ..gold = 40000
    ..wave = 20;
  if (inTown) {
    g
      ..townAt = 21
      ..inTown = true;
  }
  for (final type in ['knight', 'archer', 'priest', 'wizard', 'soldier', 'lancer']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.inventory.addAll({Item.sword: 4, Item.bow: 2, Item.shield: 12});
  g.relicBag.addAll({droppedRelics.first: 3, droppedRelics[2]: 1});
  g.materials.addAll({Mat.wolfClaw: 7, Mat.slimeGel: 14, Mat.orcTusk: 2});
  g.pusaka[Relic.titanBane] = OwnedPusaka(stars: 2);
  return g;
}

void main() {
  for (final size in const [Size(1266, 713), Size(1164, 777), Size(915, 412), Size(412, 860)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('shop shots $tag', (tester) async {
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
        // ignore: avoid_print
        print('wrote $out/$name-$tag.png  page ${b.bookPage} cells ${b.bagCells.length} actions ${[for (final a in b.bagActions) a.$1.name]} '
            'texts ${[for (final k in ['buy', 'sell', 'sellAll', 'vaultSell', 'smithy', 'note', 'empty']) b.bagDetailText(k)]} '
            'msg ${b.message}');
      }

      Future<void> tap(Rect r) async {
        expect(r, isNot(Rect.zero));
        await tester.tapAt(r.center);
        await frames(tester, 3);
      }

      final g = b.state = board(inTown: false);
      g.troops.first.relics.add(Relic.fang);
      await frames(tester, 40);
      if (b.messageBox != Rect.zero) await tap(b.messageBox);
      if (b.bookPage != 'bag') await tap(b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2);
      expect((b.picked, b.assignRows.length, b.assignSlots.length, b.bagActions.length), (null, 0, 0, 0));
      await shot('empty');
      await tap(b.bagSlot(Item.sword));
      await shot('picked');
      await tap(b.bagSlot(Item.sword));
      expect(b.picked, isNull);

      b.state = board();
      await frames(tester, 40);
      if (b.messageBox != Rect.zero) await tap(b.messageBox);
      await tap(b.bookTabs.firstWhere((t) => t.$1 == 'store').$2);
      await shot('shop');
    });
  }
}
