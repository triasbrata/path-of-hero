// The guide's one-time cards seen (docs/ui-hud.md "Guide", lib/coach.dart): offscreen shots of every page of K0-K22 into
// <probe root>/shots/guide-cards/ (`OUT`), named <key>[-<page>]-<size> (K5-1-412: K5's first page at 412x860).
// Each opened as the board does it between waves, over the book; K5 at a break with a boss chest, over its popup (then
// K5-closed: the chest after it), and K12-chest at a later break over a chest with a Legenda. A
// probe, not part of the suite (no `_test.dart`): queue `["test", "test/probe_coach_cards_shots.dart",
// "--dart-define=SIZE=412"]` (412x860; 915 for 915x412, else 1266x713) with a mirror as `dir`. It never touches the
// real save (flutter_test_config.dart's temp dir).
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/guide_rules.dart';
import 'package:tower_defense/guide_text.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/guide-cards');
const which = int.fromEnvironment('SIZE', defaultValue: 1266);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  final size = switch (which) { 412 => const Size(412, 860), 915 => const Size(915, 412), _ => const Size(1266, 713) };
  final tag = '${size.width.round()}';
  testWidgets('guide card shots $tag', (tester) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await loadHudFontNow();
    });
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
      ..guideSeen = {guideIntro, ...guidePointers};
    final g = b.state = Game(Random(1)).boardRules()
      ..armyMax = null
      ..gold = 1812345
      ..wave = 5;

    Future<void> shot(String name, [int settle = 30]) async {
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
      print('wrote $out/$name.png ${img.width}x${img.height} card ${b.coachCard} panel ${b.coachPanel}');
    }

    await frames(tester, 40); // the book floats in
    for (final k in guideEn.cards.keys.where((k) => k != 'K5')) {
      b.openGuide(k);
      final pages = guideEn.cards[k]!.length;
      for (var p = 0; p < pages; p++) {
        await shot(pages > 1 ? '$k-${p + 1}-$tag' : '$k-$tag');
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await frames(tester);
      }
    }

    // K5 at a break with a boss chest: over its popup.
    b.guideSeen!.remove('K5');
    g
      ..startWave()
      ..queue.clear()
      ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
    await frames(tester, 3);
    g.chests.add(Chest(ChestKind.boss, g.wave, cards: [Relic.ironBanner, Relic.grail, Relic.dragonCrown]));
    for (var i = 0; i < 400 && b.coachCard == null; i++) {
      await frames(tester, 1);
    }
    expect((b.coachCard, b.chestOpen), (('K5', 0), true));
    await shot('K5-1-$tag');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await shot('K5-2-$tag');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await shot('K5-closed-$tag', 10); // the chest with its own ribbon again

    // K12 at a later break, a Legenda in the chest: over its popup.
    b.guideSeen!.remove('K12');
    g
      ..chests.clear()
      ..wave = legendFrom
      ..startWave()
      ..queue.clear()
      ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
    await frames(tester, 3);
    g.chests.add(Chest(ChestKind.boss, g.wave, cards: [Relic.dragonCrown, Relic.ironBanner, Relic.grail]));
    for (var i = 0; i < 400 && b.coachCard == null; i++) {
      await frames(tester, 1);
    }
    expect((b.coachCard, b.chestOpen), (('K12', 0), true));
    await shot('K12-chest-$tag');
  });
}
