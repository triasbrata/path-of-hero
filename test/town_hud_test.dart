// The Towns on the HUD (decisions-log 216; lib/town_look.dart; ui-hud.md "The Town chip"): the wave meter's chip from
// the mark until the Town opens (its place and words at the three test sizes, its tooltip; a sweep of window sizes),
// the meter in a Town ("In town", the coming wave, the same panel), the due Town gone into after the win's cheer,
// "Leave town" on the start button, Auto leaving after autoLeave s and the wave starting at once, and a save made in a
// Town reopening in it. Booted TdGames, the Towns turned on per game (dark on the board).
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/save.dart';

import 'hud_font.dart';
import 'touch_hud_test.dart' show on, pieces;

Future<Board> boot(WidgetTester tester, [Size size = const Size(1266, 713)]) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadHudFont(tester);
  final game = TdGame();
  await tester.pumpWidget(GameWidget(game: game));
  for (var i = 0; i < 3000 && !game.isLoaded; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(game.isLoaded, isTrue);
  return game.board
    ..welcome = null
    ..miniMapOpen = false;
}

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game with the Towns on (no army cap, so Auto never holds), seeded.
Game townGame() => Game(Random(1), Random(2)).boardRules()
  ..armyMax = null
  ..townDice = Random(3)
  ..gold = 5000;

const sizes = [Size(1266, 713), Size(915, 412)];

void main() {
  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('the Town chip at $tag: right-aligned under the wave meter, its words, '
        'its tooltip; gone in the Town', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = townGame()
        ..wave = 10
        ..townAt = 12;
      await frames(tester, 40); // the book floats in between waves
      final chip = b.townChip, meter = b.waveMeter;
      expect(chip, isNot(Rect.zero));
      expect(b.townChipLabel, 'Town after wave 11');
      expect(chip.right, meter.right);
      expect(chip.top, greaterThanOrEqualTo(meter.bottom + 6));
      expect((chip.left >= 0, chip.bottom < size.height), (true, true));
      expect(b.bookArea.overlaps(chip), isFalse, reason: 'clear of the open book');
      expect(b.bookTabs.any((t) => t.$2.overlaps(chip)), isFalse, reason: "clear of the book's tabs");
      // The tooltip under the mouse: "Town after wave 11", the Smithy, the Tavern (decisions-log 268) and the Shop (open
      // in every Town, decisions-log 253).
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(chip.center);
      await frames(tester, 30);
      expect(b.tooltipShown?.$1, 'Town after wave 11');
      expect(b.tooltipShown?.$2, ['Smithy: craft items and relics', 'Tavern: buy boosts', 'Shop: buy and sell'],
          reason: 'the forge on (decisions-log 272), the Tavern on (decisions-log 268)');
      await mouse.moveTo(Offset.zero);
      // Mid-wave 11 the chip stays (the Town comes after it).
      g.startWave();
      await frames(tester, 3);
      expect(b.townChip, isNot(Rect.zero));
      // The Town due and gone into: no chip.
      g
        ..queue.clear()
        ..units.removeWhere((u) => u.side == Side.enemy);
      await frames(tester, 3);
      expect(g.waveActive, isFalse);
      for (var i = 0; i < 400 && !g.inTown; i++) {
        await frames(tester, 1);
      }
      expect((g.inTown, b.townChip), (true, Rect.zero));
      await frames(tester, 30); // past the tap's own timer
    });
  }

  testWidgets('the Town chip at every window size, desktop and touch: on the screen, over none of the HUD\'s pieces, '
      'clear of the open book and its tabs', (tester) async {
    final b = await boot(tester);
    final bad = <String>[];
    final sizes = [
      // Landscape only (decisions-log 289): a taller view is letterboxed, the game laid out at 915x610 or wider.
      for (var h = 400; h <= 1400; h += 200)
        for (var w = 900; w <= 2500; w += 200)
          if (w >= h) Size(w.toDouble(), h.toDouble()),
      const Size(915, 610), const Size(1164, 777),
    ];
    for (final platform in [TargetPlatform.macOS, TargetPlatform.android]) {
      await on(platform, () async {
        for (final size in sizes) {
          for (final wave in [false, true]) {
            tester.view.physicalSize = size;
            final g = b.state = townGame()
              ..gold = 99999
              ..wave = 10
              ..townAt = 12;
            if (wave) g.startWave();
            await frames(tester, wave ? 3 : 40); // between waves the book floats in
            final chip = b.townChip, tag = '$size wave $wave on $platform';
            if (chip == Rect.zero) {
              bad.add('$tag: no chip');
              continue;
            }
            if (chip.left < 0 || chip.top < 0 || chip.right > size.width || chip.bottom > size.height) {
              bad.add('$tag: off the screen $chip');
            }
            for (final MapEntry(:key, value: r) in pieces(b).entries) {
              if (r != Rect.zero && r.overlaps(chip)) bad.add('$tag: over $key $r');
            }
            if (!wave && b.bookArea.overlaps(chip)) bad.add('$tag: over the book ${b.bookArea}');
            if (!wave && b.bookTabs.any((t) => t.$2.overlaps(chip))) bad.add('$tag: over a tab');
          }
        }
      });
    }
    expect(bad, isEmpty, reason: '${bad.length}: ${bad.take(30).join('\n')}');
  });

  for (final size in const [Size(1266, 713), Size(915, 412)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('in a Town the wave meter says so at $tag: the beer mug, "In town", the coming wave; the same panel, no '
        'tide badge; the wave again once left', (tester) async {
      final b = await boot(tester, size);
      b.autoStart.set(false);
      final g = b.state = townGame()..wave = 70; // past the tide's start: the badge's room is kept
      await frames(tester, 40);
      final between = b.waveMeter, badge = b.tideBadge;
      expect((b.townMeterText, badge.isNotEmpty), ('', true));
      g.townAt = 71;
      for (var i = 0; i < 100 && !g.inTown; i++) {
        await frames(tester, 1);
      }
      expect(g.inTown, isTrue);
      await frames(tester, 2);
      expect(b.townMeterText, 'In town · next wave 71');
      expect(b.waveMeter, between, reason: 'the same panel: nothing under it moves');
      expect(b.tideBadge, '', reason: 'no tide badge in a Town');
      await tester.tapAt(b.startButton.center); // "Leave town"
      await frames(tester, 3);
      expect((g.inTown, b.townMeterText, b.tideBadge, b.waveMeter), (false, '', badge, between));
      await frames(tester, 30);
    });
  }

  testWidgets('a due Town is gone into after the win\'s cheer and saved; "Leave town" on the start button leaves it and '
      'starts no wave; then Start starts', (tester) async {
    final b = await boot(tester);
    b.autoStart.set(false);
    final g = b.state = townGame()
      ..wave = 5
      ..townAt = 7;
    g
      ..startWave()
      ..queue.clear()
      ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
    await frames(tester, 3);
    expect((g.wave, g.waveActive, g.townDue, g.inTown), (6, false, true, false));
    expect(b.startButton, Rect.zero, reason: 'no Start while the Town is due');
    for (var i = 0; i < 400 && g.t - g.victoryAt < victoryTime; i++) {
      await frames(tester, 1);
    }
    await frames(tester, 3);
    expect(g.inTown, isTrue);
    expect(loadGame()?.inTown, isTrue, reason: 'saved in the Town');
    expect(b.startButton, isNot(Rect.zero), reason: '"Leave town" in its place');
    await tester.tapAt(b.startButton.center);
    await frames(tester, 3);
    expect((g.inTown, g.townLast, g.townAt, g.waveActive, g.wave), (false, 7, null, false, 6));
    expect(loadGame()?.townLast, 7, reason: 'saved as left');
    expect(b.startButton, isNot(Rect.zero));
    await tester.tapAt(b.startButton.center);
    await frames(tester, 3);
    expect((g.waveActive, g.wave), (true, 7));
    await frames(tester, 30);
  });

  testWidgets('Auto in a Town: it counts autoLeave s down on "Leave town", leaves, and the wave starts once the fade back '
      'to the field is over (one wait)',
      (tester) async {
    final b = await boot(tester);
    b.autoStart.set(true);
    addTearDown(() => b.autoStart.set(false));
    final g = b.state = townGame()
      ..townRules = TownRules.patch({
        'schedule': {'autoLeave': 2.0},
      })
      ..wave = 5
      ..townAt = 7;
    g
      ..startWave()
      ..queue.clear()
      ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
    await frames(tester, 3);
    for (var i = 0; i < 400 && !g.inTown; i++) {
      await frames(tester, 1);
    }
    expect(g.inTown, isTrue);
    expect(b.autoStart.shown, 2, reason: '"Leave town 2"');
    await frames(tester, 66); // 1.06 s
    expect((g.inTown, b.autoStart.shown), (true, 1));
    await frames(tester, 66);
    expect((g.inTown, g.townLast), (false, 7), reason: 'left by Auto');
    await frames(tester, 50); // the fade back to the field (decisions-log 224, town_scene.dart)
    expect((g.waveActive, g.wave), (true, 7), reason: 'the wave on');
    final left = g.log.entries.whereType<TownLeft>().single;
    expect(left.auto, isTrue);
    await frames(tester, 30);
  });

  testWidgets('a save made in a Town reopens in it after Continue: "Leave town" waits there', (tester) async {
    final b = await boot(tester);
    b.autoStart.set(false);
    final g = townGame()
      ..wave = 6
      ..townAt = 7;
    expect(g.enterTown(), isTrue);
    saveGame(g);
    final back = loadGame()!;
    expect((back.inTown, back.townDue), (true, true));
    b.state = back;
    await frames(tester, 10);
    expect(b.state.inTown, isTrue);
    expect(b.startButton, isNot(Rect.zero));
    expect(b.state.log.entries.whereType<TownEntered>(), isEmpty, reason: 'not gone into again');
    await frames(tester, 30);
  });
}
