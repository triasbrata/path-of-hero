// The Army detail's Awaken needs by grade (decisions-log 249; docs/ui-hud.md "Army"): offscreen shots into
// <probe root>/shots/forge-F3/ (`OUT`), to set beside the design's mockup 14 (shots/forge-design/
// 14-army-awaken-by-grade-1266x713.png). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_forge_f3_shots.dart"]` with a mirror as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir) and wins no wave.
//
// At 1266x713 and 412x860 (`desk-` / `phone-`), a board game with the forge on and the knight picked: `a0` (Awaken 0,
// grade I: a Sword in the Bag, Shields the Bag makes, an Amulet short of Orc Tooth), `a1` (Awaken 1, grade II: the
// mockup's rows, In Bag, can make, needs, Done), `a2` (Awaken 2, grade III two thirds: Royal Gloves held, a Royal Sword
// the Bag makes); each at the body's top, its middle and its end (`-s0`, `-s1`, `-s2`).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/forge-F3');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game with the forge on, the knight fielded with its grade sets up to [level], and what the Bag holds toward
/// the next one.
Game knight(int level) {
  final g = Game().boardRules()
    ..gold = 5000;
  List<Item> set(int l) => [for (final MapEntry(key: item, value: n) in g.gradeSet('knight', l).entries) ...List.filled(n, item)];
  g.upgrades['knight'] = [for (var l = 1; l <= level; l++) ...set(l)];
  switch (level) {
    case 0:
      g.inventory[Item.sword] = 1;
      g.materials.addAll({Mat.orcTooth: 4, Mat.boneShard: 2, Mat.slimeGel: 2}); // shields 2; boots short of Bat Wing
    case 1:
      g.upgrades['knight']!.addAll([Item.steelSword, Item.steelGloves, Item.steelGloves]);
      g.inventory[Item.steelSword] = 1;
      g.materials.addAll({Mat.rustyPlate: 6, Mat.leatherStrap: 3}); // Tower Shields 3; Swift Boots short of Wolf Claw
    default:
      g.upgrades['knight']!.addAll([Item.royalGloves, Item.royalGloves, Item.royalSword]);
      g.materials.addAll({Mat.bigBone: 2, Mat.orcEar: 1}); // a Royal Sword
  }
  expect(g.autoPlace('knight'), isTrue);
  expect(g.awakenLevel('knight'), level);
  return g;
}

void main() {
  testWidgets('army detail by grade shots', (tester) async {
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
      print('wrote $out/$name.png ${img.width}x${img.height}; next: ${b.troopDetailWords('next').join(' | ')}');
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860))]) {
      tester.view.physicalSize = size;
      for (final level in [0, 1, 2]) {
        b.state = knight(level);
        await frames(tester, 50);
        if (b.messageBox != Rect.zero) {
          await tester.tapAt(b.messageBox.center);
          await frames(tester);
        }
        await tester.tapAt(b.troopRow('knight').center);
        await frames(tester, 4);
        final most = (b.troopDetailContent - b.troopDetailBody.height).clamp(0.0, double.infinity);
        for (final (i, f) in const [(0, 0.0), (1, 0.5), (2, 1.0)].indexed) {
          b.troopDetailScroll = most * f.$2;
          await shot('$tag-a$level-s$i');
        }
        b.state = Game(); // leave no wave to win
        await frames(tester, 5);
      }
    }
    await frames(tester, 10);
  });
}
