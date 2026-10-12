// Batch E-3 seen (decisions-log 223; loot-items-relics.md "Pusaka" and "Bayangan", ui-hud.md "Shadows"): offscreen shots
// into <probe root>/shots/cat-E3/ (`OUT`), built on test/probe_e2p_shots.dart and test/probe_e3b_shots.dart. A
// probe, not part of the suite (no `_test.dart`): queue `["test", "test/probe_e3_shots.dart"]` with the worktree as `dir`.
// It never touches the real save (flutter_test_config.dart's temp dir); the dice are seeded, so a rerun gives the same
// shots.
//
// The eight Epik Artifacts on the owner's wave-89 save (the fixture) at wave 90, the Shadows off: chest-<tag>-<n> (three
// boss chests of three purple Epik cards that deal the eight, the third with Mercy Lily and Hearth beside the Grail, n
// 1..3, at 412x860 and 1266x713, the tag phone or desk); bag-sainttear at 1266x713 and bag-sainttear-phone at 412x860
// (the Bag's Artifacts, Saint's Tear ★2 on the templars picked: its detail, the longest first sentence of the eight,
// whole, the action rows under it). Then with the Shadows forced on, at 412x860 and 1266x713 (<size>): venom-reveal-<size>
// (a Boss Chest of three Epic cards hiding Bat Venom, Prey and Heal Siphon, the first taken: "Bat Venom 2", the other two
// "Dodged"), venom-message-<size> (after it), venom-chips-<size> and venom-tip-<size> (between waves, Bat Venom at L4 with
// two others held: their icons and levels, then their tooltip, tapped).
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/cat-E3');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

/// The eight, three a chest (the longest together first), and Mercy Lily and Hearth beside the Grail.
const hands = [
  [Relic.saintTear, Relic.brightSpring, Relic.heartbeat],
  [Relic.manaHymn, Relic.braveSong, Relic.haloLantern],
  [Relic.mercyLily, Relic.hearth, Relic.grail],
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
  testWidgets('E-3P artifact shots', (tester) async {
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

    for (final (name, size) in const [('bag-sainttear', Size(1266, 713)), ('bag-sainttear-phone', Size(412, 860))]) {
      tester.view.physicalSize = size;
      b.state = load()..givePusaka(Relic.saintTear, type: 'knight_templar', stars: 2);
      await frames(tester, 30);
      await page('troops');
      await page('bag');
      await tap(b.bagChip(BagCategory.artifacts).center);
      for (var i = 0; i < 5 && b.bagSlot(Relic.saintTear) == Rect.zero && b.bagPager('on') != Rect.zero; i++) {
        await tap(b.bagPager('on').center);
      }
      await tap(b.bagSlot(Relic.saintTear).center);
      // ignore: avoid_print
      print('$name: picked ${b.picked}, desc ${b.bagDetailText('desc')?.replaceAll('\n', ' | ')}');
      await shot(tester, key, name, 30);
    }
    b.state = Game();
    await frames(tester, 10);
  });

  for (final size in const [Size(412, 860), Size(1266, 713)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('E-3 Bat Venom shots $tag', (tester) async {
      omensOn = true;
      addTearDown(() => omensOn = omensDefault);
      final key = GlobalKey();
      final b = await boot(tester, size, key);

      Future<void> tap(Offset p) async {
        await tester.tapAt(p);
        await frames(tester, 2);
      }

      final g = b.state = board()..chestsGiven = 1;
      g.chests.add(Chest(ChestKind.boss, 90,
          cards: [Relic.grail, Relic.voidEye, Relic.godThunder], omens: [OmenKind.batVenom, OmenKind.prey, OmenKind.healSiphon]));
      await frames(tester, 40);
      await tap(b.chestCards[0].center);
      await tap(b.chestButtons['take']!.center);
      await shot(tester, key, 'venom-reveal-$tag', 30);
      await frames(tester, (omenRevealFor * 60).ceil());
      await shot(tester, key, 'venom-message-$tag', 2);
      // ignore: avoid_print
      print('venom message: ${b.message}');
      await tap(b.messageBox.center);
      await frames(tester, 3);
      if (b.messageBox != Rect.zero) await tap(b.messageBox.center);

      g.omens
        ..clear()
        ..addAll([...List.filled(4, OmenKind.batVenom), ...List.filled(2, OmenKind.prey), ...List.filled(2, OmenKind.healSiphon)]);
      await shot(tester, key, 'venom-chips-$tag', 20);
      await tap(b.omenRow.center);
      await shot(tester, key, 'venom-tip-$tag', 30);
      // ignore: avoid_print
      print('venom tip: ${g.omenTip.$2.join(' | ')}');
      b.state = Game();
      await frames(tester, 10);
    });
  }
}
