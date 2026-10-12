// Batch L-3 seen (decisions-log 209; loot-items-relics.md "Pusaka", ui-hud.md "Shadows"): offscreen shots into
// <probe root>/shots/cat-L3/ (`OUT`), built on test/probe_l2p_shots.dart and test/probe_l3b_shots.dart. A probe, not
// part of the suite (no `_test.dart`): queue `["test", "test/probe_l3_shots.dart"]` with the worktree as `dir`. It never
// touches the real save (flutter_test_config.dart's temp dir); the dice are seeded, so a rerun gives the same shots.
//
// The six Artifacts, the Shadows off, on the owner's wave-89 save (the fixture) at wave 90: chest-<tag>-<n> (two boss
// chests of three cards that deal the six, n 1..2, at 412x860 and 1266x713, the tag desk or phone) and at 1266x713
// bag-fullcup (the Bag, Full Cup ★2 on the priests picked: its detail on the right page, the longest of the six).
// The Bayangan Sap, the Shadows forced on, at 412x860 and 1266x713 (<size>): reveal-<size> (a Boss Chest of three Rare
// cards hiding Sap, Thorns and Haste, the first taken: "Sap 1", the other two "Dodged"), message-<size> (after it) and
// tip-<size> (between waves, Sap held with five other Langka kinds: their tooltip, tapped: each kind's HUD line).
import 'dart:convert';
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/cat-L3');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

/// The six, three a chest.
const hands = [
  [Relic.saltCharm, Relic.wolfFeast, Relic.fullCup],
  [Relic.hiddenFlask, Relic.livingMoss, Relic.pureWater],
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

/// A board game between waves at wave 89 (the next a boss's), seeded, a mixed army of eight types, gold to spare.
Game board() {
  final g = Game(Random(seed), Random(seed + 100)).boardRules()
    ..seedDice(seed) // every die, the Shadows' faces too (decisions-log 319)
    ..armyMax = null
    ..gold = 400000
    ..wave = 89;
  for (final type in ['knight', 'knight_templar', 'archer', 'priest', 'wizard', 'soldier', 'lancer', 'swordsman']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  return g;
}

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
  testWidgets('L-3 artifact shots', (tester) async {
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

    tester.view.physicalSize = const Size(1266, 713);
    b.state = load()..givePusaka(Relic.fullCup, type: 'priest', stars: 2);
    await frames(tester, 30);
    await page('troops');
    await page('bag');
    await tap(b.bagSlot(Relic.fullCup).center);
    await shot(tester, key, 'bag-fullcup', 30);
    b.state = Game();
    await frames(tester, 10);
  });

  group('the Bayangan Sap', () {
    setUp(() => omensOn = true);
    tearDown(() => omensOn = false);

    for (final size in const [Size(412, 860), Size(1266, 713)]) {
      final tag = '${size.width.round()}x${size.height.round()}';
      testWidgets('Sap shots $tag', (tester) async {
        final key = GlobalKey();
        final b = await boot(tester, size, key);

        Future<void> tap(Offset p) async {
          await tester.tapAt(p);
          await frames(tester, 2);
        }

        final g = b.state = board()..chestsGiven = 1;
        g.chests.add(Chest(ChestKind.boss, 90,
            cards: [Relic.saltCharm, Relic.pureWater, Relic.wolfFeast], omens: [OmenKind.sap, OmenKind.thorns, OmenKind.haste]));
        await frames(tester, 40);
        await tap(b.chestCards[0].center);
        await tap(b.chestButtons['take']!.center);
        await shot(tester, key, 'reveal-$tag', 30);
        await frames(tester, (omenRevealFor * 60).ceil());
        await shot(tester, key, 'message-$tag', 2);
        // ignore: avoid_print
        print('message: ${b.message}');
        await tap(b.messageBox.center);
        await frames(tester, 3);
        if (b.messageBox != Rect.zero) await tap(b.messageBox.center);

        // Between waves: Sap held with five other Langka kinds, the chips' tooltip.
        g.omens
          ..clear()
          ..addAll([
            ...List.filled(3, OmenKind.sap), OmenKind.haste, ...List.filled(2, OmenKind.wound), OmenKind.pummel, //
            ...List.filled(2, OmenKind.scar), OmenKind.drag,
          ]);
        await frames(tester, 20);
        await tap(b.omenRow.center);
        await shot(tester, key, 'tip-$tag', 30);
        // ignore: avoid_print
        print('tip: ${g.omenTip.$2.join(' | ')}');
      });
    }
  });
}
