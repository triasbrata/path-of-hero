// The Towns' materials seen (decisions-log 221; ui-hud.md "The Bag's Materials"): offscreen shots into
// <probe root>/shots/town-T1/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_town_materials_shots.dart"]` with the worktree as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir); the dice are seeded.
//
// At 1266x713, 915x412 and 412x860 (<size>): bag-<size> (the Bag on its Materials chip, all 30 held, Wolf Fang picked:
// its facing page), bag2-<size> (915x412's second page), tip-<size> (the Lich Orb's tooltip under the mouse), pop-<size>
// (a wave on with the Towns on: a high elite and a mini boss just killed, their materials hopping onto the field) and
// victory-<size> (the "VICTORY!" line: two items, then the wave's materials).
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/town-T1');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game between waves at wave 20 with the Towns on, seeded, a mixed army, two items and every one of the 30
/// materials (a run's late counts).
Game board() {
  final g = Game(Random(seed), Random(seed + 100)).boardRules()
    ..slots = Random(seed + 300)
    ..loot = Random(seed + 200)
    ..draft = Random(seed + 500)
    ..townDice = Random(seed + 600)
    ..matDice = Random(seed + 700)
    ..armyMax = null
    ..gold = 40000
    ..wave = 20;
  for (final type in ['knight', 'archer', 'priest', 'wizard', 'soldier', 'lancer']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.inventory.addAll({Item.sword: 4, Item.bow: 2});
  g.materials.addAll({for (final (i, m) in Mat.values.indexed) m: [14, 13, 9, 11, 8, 6, 5, 3, 4, 2, 1, 3][i % 12] + (i ~/ 12)});
  return g;
}

void main() {
  for (final size in const [Size(1266, 713), Size(915, 412), Size(412, 860)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('materials shots $tag', (tester) async {
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
        print('wrote $out/$name-$tag.png  cells ${b.bagCells.length} pages ${b.bagPages} victory ${b.victoryLoot}');
      }

      Future<void> tap(Offset p) async {
        await tester.tapAt(p);
        await frames(tester, 3);
      }

      final g = b.state = board();
      await frames(tester, 30);
      if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
      await tap(b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
      await tap(b.bagChip(BagCategory.materials).center);
      await tap(b.bagCells.firstWhere((c) => c.$1 == Mat.wolfFang).$2.center);
      await shot('bag');
      if (b.bagPages > 1) {
        await tap(b.bagPager('on').center);
        await shot('bag2');
      }
      // A material's tooltip under the mouse (the Lich Orb, on the last page).
      final mouse = TestPointer(7, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(b.bagCells.firstWhere((c) => c.$1 == Mat.lichOrb).$2.center));
      await shot('tip', 90);
      await tester.sendEventToBinding(mouse.hover(Offset.zero));

      // A wave on, the book shut (in portrait it stays, on its troops page, which doesn't pause the wave): a high elite
      // and a mini boss fall at once, their materials hopping onto the field.
      await tap(b.bookTabs.firstWhere((t) => t.$1 == (size.height > size.width ? 'troops' : 'bag')).$2.center);
      g
        ..startWave()
        ..queue.clear();
      final k = g.troops.first;
      final foes = [
        for (final (i, (type, tier)) in [('werewolf', Tier.highElite), ('orc', Tier.miniBoss)].indexed)
          g.monster(type, tier, k.pos + Point(60.0 + i * 30, 0))
            ..entered = true
            ..stunUntil = 1e9, // held, drawn mid-flinch
      ];
      g.units.addAll([...foes, g.monster('slime', Tier.normal, const Point(2000, 40))..entered = true..stunUntil = 1e9]);
      await frames(tester, 3);
      g.matDice = Random(1); // whatever it rolls: the mini boss's always drop
      for (final f in foes) {
        f.hp = 0.001;
      }
      for (var i = 0; i < 400 && foes.any((f) => f.alive); i++) {
        await frames(tester, 1);
      }
      await shot('pop', 6);

      // The win's "VICTORY!" with the materials the wave dropped.
      for (final u in g.enemies) {
        u.gone = true;
      }
      await frames(tester, 2);
      g.lastMaterials = {Mat.wolfFang: 1, Mat.orcTusk: 2, Mat.evilEye: 1, Mat.slimeGel: 3};
      await shot('victory', 40);
    });
  }
}
