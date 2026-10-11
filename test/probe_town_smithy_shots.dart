// The Town's Smithy pages (decisions-log 235; ui-hud.md "The Smithy"): offscreen shots into
// <probe root>/shots/town-T6b/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_town_smithy_shots.dart"]` with the worktree as `dir` (`--plain-name <size>` for one size). It never
// touches the real save (flutter_test_config.dart's temp dir); the dice are seeded.
//
// At 1266x713, 1164x777, 915x412 and 412x860 (<size>), a bag of 27 kinds of materials: craftable-<size> (Venom picked:
// Craft), short-mat-<size> (Sweep: 2 of 4 Wolf Claw), short-item-<size> (Giant Slayer: no Gloves), short-gold-<size>
// (Giant Slayer: the gold short), crafted-<size> (after a Craft: "Venom crafted!"); then all 30 held: full-<size> (the
// grid's first page) and at 915x412 full-p2-<size> (its second).
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/town-T6b');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game in the Town before wave 21 with the Towns on, seeded: a mixed army, 4,450 gold, a few items and small
/// relics, and 27 kinds of materials (none of the Trophies but a Soul Orb), Venom's recipe covered, Sweep 2 Wolf Claw
/// short, Giant Slayer without its Gloves.
Game board() {
  final g = Game(Random(seed), Random(seed + 100)).boardRules()
    ..slots = Random(seed + 300)
    ..loot = Random(seed + 200)
    ..draft = Random(seed + 500)
    ..townDice = Random(seed + 600)
    ..matDice = Random(seed + 700)
    ..towns = true
    ..armyMax = null
    ..gold = 4450
    ..wave = 20
    ..townAt = 21
    ..inTown = true;
  for (final type in ['knight', 'archer', 'priest', 'wizard', 'soldier', 'lancer']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.inventory.addAll({Item.sword: 3, Item.bow: 2, Item.shield: 2});
  g.relicBag.addAll({Relic.fang: 2, Relic.thorns: 1, Relic.cleave: 1});
  g.materials.addAll({
    for (final (i, m) in Mat.values.indexed)
      if (i < 26) m: 1 + i * 5 % 13,
    Mat.boneArrow: 8,
    Mat.slimeCore: 5,
    Mat.batFang: 6,
    Mat.boneBow: 2,
    Mat.wolfClaw: 2,
    Mat.leatherStrap: 3,
    Mat.orcTusk: 3,
    Mat.wolfFang: 2,
    Mat.ironScrap: 4,
    Mat.orcEar: 3,
    Mat.ironTusk: 1,
    Mat.soulOrb: 1,
  });
  return g;
}

void main() {
  for (final size in const [Size(1266, 713), Size(1164, 777), Size(915, 412), Size(412, 860)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('smithy shots $tag', (tester) async {
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
        print('wrote $out/$name-$tag.png  page ${b.bookPage} pick ${b.smithyPick} relics ${b.smithyCells.length} '
            'mats ${b.bagCells.length} (page ${b.bagPage + 1}/${b.bagPages}) craft "${b.smithyText('craft')}" '
            'rows ${[for (final r in b.smithyRows) '${r.count}${r.short ? '!' : ''}${r.from.isEmpty ? '' : ' ${r.from}'}${r.warn.isEmpty ? '' : ' ${r.warn}'}']} '
            'noLimit ${b.smithyAt('noLimit') != Rect.zero} equip ${b.smithyAt('equip') != Rect.zero} msg ${b.message}');
      }

      Future<void> tap(Rect r) async {
        expect(r, isNot(Rect.zero));
        await tester.tapAt(r.center);
        await frames(tester, 3);
      }

      Future<void> pick(Relic relic) async {
        if (b.messageBox != Rect.zero) await tap(b.messageBox);
        await tap(b.smithyCells.firstWhere((c) => c.$1 == relic).$2);
      }

      final g = b.state = board();
      await frames(tester, 40);
      if (b.messageBox != Rect.zero) await tap(b.messageBox);
      expect(b.bookPage, 'smithy');
      await pick(Relic.venom);
      await shot('craftable');
      await pick(Relic.cleave);
      await shot('short-mat');
      await pick(Relic.giantSlayer);
      await shot('short-item');
      g
        ..inventory[Item.gloves] = 1
        ..gold = 2000;
      await shot('short-gold');
      g.gold = 4450;
      await pick(Relic.venom);
      await tap(b.smithyAt('craft'));
      await shot('crafted', 6);

      g.materials.addAll({for (final (i, m) in Mat.values.indexed) m: i + 1});
      if (b.messageBox != Rect.zero) await tap(b.messageBox);
      await shot('full');
      if (b.bagPages > 1) {
        await tap(b.bagPager('on'));
        await shot('full-p2');
      }
    });
  }
}
