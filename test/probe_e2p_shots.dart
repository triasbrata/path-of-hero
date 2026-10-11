// Batch E-2P seen (decisions-log 214; loot-items-relics.md "Pusaka"): offscreen shots into <probe root>/shots/cat-E2P/
// (`OUT`), built on test/probe_e1p_shots.dart. A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_e2p_shots.dart"]` with the worktree as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir); nothing is rolled, so a rerun gives the same shots.
//
// The seven Epik Artifacts on the owner's wave-89 save (the fixture) at wave 90, the Shadows off: chest-<tag>-<n> (three
// boss chests of three purple Epik cards that deal the seven, the third with Anchor beside the Grail and Ember Brand, n
// 1..3, at 412x860 and 1266x713, the tag phone or desk); bag-emberbrand at 1266x713, bag-emberbrand-phone at 412x860
// and bag-emberbrand-wide at 915x412 (the Bag's Artifacts, Ember Brand ★2 on the archers picked: its detail on the right
// page, the longest first sentence of the seven, whole, the action rows under it); and at 1266x713 army-templar (the
// Army page, the templars with Anchor ★2 picked: "Anchored Templar", its walk speed down in the detail).
import 'dart:convert';
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/cat-E2P');

/// The seven, three a chest (the longest together first), and Anchor with two others.
const hands = [
  [Relic.funeralPyre, Relic.nullStone, Relic.wardensHorn],
  [Relic.emberBrand, Relic.fallenFlag, Relic.aegisSeal],
  [Relic.anchor, Relic.grail, Relic.emberBrand],
];

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Game load() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>)
    .boardRules()
  ..chests.clear()
  ..wave = 90;

/// Boots one TdGame in [size] under a [RepaintBoundary] of [key], past the welcome screen.
Future<Board> boot(WidgetTester tester, Size size, GlobalKey key) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(loadHudFontNow);
  final game = TdGame();
  await tester.pumpWidget(RepaintBoundary(key: key, child: GameWidget(game: game)));
  for (var i = 0; i < 3000 && !game.isLoaded; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(game.isLoaded, isTrue);
  return game.board
    ..welcome = null
    ..miniMapOpen = false;
}

/// Shoots the boundary of [key] into `$out/$name.png` after [settle] frames.
Future<void> shot(WidgetTester tester, GlobalKey key, String name, [int settle = 20]) async {
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
  print('wrote $out/$name.png ${img.width}x${img.height}');
}

void main() {
  testWidgets('E-2P artifact shots', (tester) async {
    final key = GlobalKey();
    final b = await boot(tester, const Size(1266, 713), key);

    Future<void> tap(Offset p) async {
      await tester.tapAt(p);
      await frames(tester);
    }

    Future<void> page(String name) async {
      if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
      await tap(b.bookTabs.firstWhere((t) => t.$1 == name).$2.center);
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860))]) {
      tester.view.physicalSize = size;
      for (final (i, hand) in hands.indexed) {
        final g = b.state = load()..chests.add(Chest(ChestKind.boss, 90, cards: hand));
        await frames(tester, 3);
        await tap(const Offset(2, 2)); // the save's notes go, the popup stays
        // ignore: avoid_print
        print('chest ${i + 1}: ${g.chest?.cards}; cards ${b.chestCards}');
        await shot(tester, key, 'chest-$tag-${i + 1}', 30);
      }
    }

    for (final (name, size) in const [('bag-emberbrand', Size(1266, 713)), ('bag-emberbrand-phone', Size(412, 860)),
      ('bag-emberbrand-wide', Size(915, 412))]) {
      tester.view.physicalSize = size;
      b.state = load()
        ..givePusaka(Relic.anchor, type: 'knight_templar', stars: 2)
        ..givePusaka(Relic.emberBrand, type: 'archer', stars: 2);
      await frames(tester, 30);
      await page('troops');
      await page('bag');
      await tap(b.bagChip(BagCategory.artifacts).center);
      for (var i = 0; i < 5 && b.bagSlot(Relic.emberBrand) == Rect.zero && b.bagPager('on') != Rect.zero; i++) {
        await tap(b.bagPager('on').center);
      }
      await tap(b.bagSlot(Relic.emberBrand).center);
      // ignore: avoid_print
      print('$name: picked ${b.picked}, desc ${b.bagDetailText('desc')?.replaceAll('\n', ' | ')}');
      await shot(tester, key, name, 30);
    }
    tester.view.physicalSize = const Size(1266, 713);
    await page('troops');
    await tap(b.troopRow('knight_templar').center);
    await shot(tester, key, 'army-templar', 30);
    b.state = Game();
    await frames(tester, 10);
  });
}
