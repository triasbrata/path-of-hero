// Shadow batch G-2B seen (decisions-log 236; ui-hud.md "Shadows"): offscreen shots with [omensOn] forced on, into
// <probe root>/shots/cat-G2B/ (`OUT`), built on test/probe_g1b_shots.dart. A probe, not part of the suite (no
// `_test.dart`): queue `["test", "test/probe_g2b_shots.dart"]` with the worktree as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir); the dice are seeded, so a rerun gives the same shots.
//
// At 412x860 and 1266x713 (<size>): reveal1-<size> (a Boss Chest of three Legendary cards hiding Cover, Deathless and
// Spree, the first taken: "Cover 3", the other two "Dodged"), message1-<size> (after it: what the monsters got),
// reveal2-<size> and message2-<size> (a second chest hiding Warlord, Vultures and Backlash, its middle card taken:
// Vultures), chips<n>-<size> and tip<n>-<size> (between waves, three or four of the ten held: their icons and levels,
// then their tooltip, tapped): 1 Cover, Renewal, Side Swing, Deathless; 2 Adapt, Warlord, Spree; 3 Vultures, Mana Burn,
// Backlash.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/cat-G2B');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game between waves at wave 89 (the next a boss's), seeded, a mixed army of eight types, gold to spare.
Game board() {
  final g = Game(Random(seed), Random(seed + 100)).boardRules()
    ..slots = Random(seed + 300)
    ..loot = Random(seed + 200)
    ..draft = Random(seed + 500)
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

void main() {
  setUp(() => omensOn = true);
  tearDown(() => omensOn = false);

  for (final size in const [Size(412, 860), Size(1266, 713)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('G-2B shots $tag', (tester) async {
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
        print('wrote $out/$name-$tag.png');
      }

      Future<void> tap(Offset p) async {
        await tester.tapAt(p);
        await frames(tester, 2);
      }

      /// Takes card [i] of the chest on screen and shoots the reveal and the message after it as [n].
      Future<void> take(int i, int n) async {
        await tap(b.chestCards[i].center);
        await tap(b.chestButtons['take']!.center);
        await shot('reveal$n', 30);
        await frames(tester, (omenRevealFor * 60).ceil());
        await shot('message$n', 2);
        // ignore: avoid_print
        print('message$n: ${b.message}');
        await tap(b.messageBox.center);
        await frames(tester, 3);
      }

      final g = b.state = board()..chestsGiven = 1;
      g.chests.addAll([
        Chest(ChestKind.boss, 90,
            cards: [Relic.dragonCrown, Relic.oathOfOne, Relic.alliance], omens: [OmenKind.cover, OmenKind.deathless, OmenKind.spree]),
        Chest(ChestKind.boss, 90,
            cards: [Relic.oathOfOne, Relic.alliance, Relic.dragonCrown], omens: [OmenKind.warlord, OmenKind.vultures, OmenKind.backlash]),
      ]);
      await frames(tester, 40);
      await take(0, 1);
      await take(1, 2);
      if (b.messageBox != Rect.zero) await tap(b.messageBox.center);

      // Between waves: three or four of the ten held at a time; the chips and their tooltip each time.
      for (final (n, held) in [
        (1, [...List.filled(4, OmenKind.cover), ...List.filled(3, OmenKind.renewal), ...List.filled(4, OmenKind.sideSwing), //
          ...List.filled(3, OmenKind.deathless)]),
        (2, [...List.filled(4, OmenKind.adapt), ...List.filled(3, OmenKind.warlord), ...List.filled(4, OmenKind.spree)]),
        (3, [...List.filled(3, OmenKind.vultures), ...List.filled(4, OmenKind.manaBurn), ...List.filled(4, OmenKind.backlash)]),
      ]) {
        g.omens
          ..clear()
          ..addAll(held);
        if (n > 1) await tap(b.omenRow.center); // a tap on the row hides the last tooltip
        await shot('chips$n', 20);
        await tap(b.omenRow.center);
        await shot('tip$n', 30);
        // ignore: avoid_print
        print('tip$n: ${g.omenTip.$2.join(' | ')}');
      }
    });
  }
}
