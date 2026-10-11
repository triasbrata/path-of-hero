// The forge's Smithy strip and boards (decisions-log 254 and 277; ui-hud.md "The Smithy"): offscreen shots into
// <probe root>/shots/forge-F5/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_forge_f5_shots.dart"]` with a mirror as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir), and wins no wave. The Towns and the forge on, the dice seeded.
//
// At 1266x713, 1164x777, 915x412, 412x860 and 1600x947 (`<size>`), in the Town before wave 21 with a mixed army and 26
// kinds of materials: items-p1-<size> (the Items tab's first page, every grade by section, Enhance greyed), items-p2-<size>
// (its next page, where it takes more than one), helm-<size> (grade II's Steel Helm: its Leather Cap row), crafted-<size>
// (after a Craft: "Steel Sword crafted!"), relics-<size> (the Relics tab's 20); then in the Town after wave 30:
// open-<size> (Enhance no longer greyed).
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/forge-F5');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game in the Town before wave [wave] + 1 with the Towns and the forge on, seeded: a mixed army, 4,450 gold, a
/// few items and small relics, and 26 kinds of materials (the Steel Sword's covered).
Game board({int wave = 20}) {
  final g = Game(Random(seed), Random(seed + 100)).boardRules()
    ..slots = Random(seed + 300)
    ..loot = Random(seed + 200)
    ..draft = Random(seed + 500)
    ..townDice = Random(seed + 600)
    ..matDice = Random(seed + 700)
    ..towns = true
    ..armyMax = null
    ..gold = 4450
    ..wave = wave
    ..townAt = wave + 1
    ..inTown = true;
  for (final type in ['knight', 'archer', 'priest', 'wizard', 'soldier', 'lancer']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.inventory.addAll({Item.sword: 3, Item.bow: 2, Item.prayerBeads: 1});
  g.relicBag.addAll({Relic.fang: 2, Relic.thorns: 1, Relic.cleave: 1});
  g.materials.addAll({
    for (final (i, m) in Mat.values.indexed)
      if (i < 26) m: 1 + i * 5 % 13,
  });
  g.materials
    ..[Mat.wolfClaw] = 2
    ..[Mat.orcEar] = 1;
  return g;
}

void main() {
  for (final size in const [Size(1266, 713), Size(1164, 777), Size(915, 412), Size(412, 860), Size(1600, 947)]) {
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
        print('wrote $file; tab ${b.smithyTab} items page ${b.smithyItemPage + 1}/${b.smithyItemPages} grades '
            '"${b.smithyText('grades')}" item ${b.smithyItem} relic ${b.smithyPick} '
            'small ${b.smithySmallBoard}; tabs ${b.smithyText('tabs')} locked "${b.smithyText('locked')}"; '
            'pages $left $right; board ${b.smithyItemCells.length + b.smithyCells.length} cells, first '
            '${(b.smithyItemCells.isEmpty ? b.smithyCells.map((c) => c.$2) : b.smithyItemCells.map((c) => c.$2)).firstOrNull}; '
            'mats ${b.bagCells.length} on ${b.bagPage + 1}/${b.bagPages} (${b.bagPageSizes}); kinds ${b.smithyAt('kinds')}; '
            'craft "${b.smithyText('craft')}" ${b.smithyAt('craft')}; give ${b.smithyAt('give')} equip ${b.smithyAt('equip')}; '
            'tier "${b.smithyText('tier')?.replaceAll('\n', ' / ')}"; message ${b.message}');
      }

      Future<void> tap(Rect r) async {
        await tester.tapAt(r.center);
        await frames(tester, 3);
      }

      Future<void> quiet() async {
        if (b.messageBox != Rect.zero) await tap(b.messageBox);
      }

      b.state = board();
      await frames(tester, 40);
      await quiet();
      await shot('items-p1');
      if (b.smithyItemPages > 1) {
        await tap(b.smithyItemPager('on'));
        await shot('items-p2');
        await tap(b.smithyItemPager('back'));
      }
      Future<void> pick(Item item) async {
        while (b.smithyItemPage > 0) {
          await tap(b.smithyItemPager('back'));
        }
        while (!b.smithyItemCells.any((c) => c.$1 == item) && b.smithyItemPage < b.smithyItemPages - 1) {
          await tap(b.smithyItemPager('on'));
        }
        await tap(b.smithyItemCells.firstWhere((c) => c.$1 == item).$2);
      }

      await pick(Item.steelHelm);
      await shot('helm');
      await pick(Item.steelSword);
      await tap(b.smithyAt('craft'));
      await shot('crafted');
      await quiet();
      await tap(b.smithyAt('tab:relics'));
      await shot('relics');
      await tap(b.smithyAt('tab:enhance'));
      await shot('enhance-tap');
      await quiet();

      b.state = board(wave: 30);
      await frames(tester, 40);
      await quiet();
      await tap(b.smithyAt('tab:items'));
      await shot('open');
      await frames(tester, 40);
    });
  }
}
