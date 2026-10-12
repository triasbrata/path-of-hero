// The Town checkpoint on the HUD (decisions-log 333; lib/wipe_ask.dart): after a wipe that left hearts, once the swept
// monsters' hop is over, the "Your army fell!" dialog with the hearts left, the way back and the weakened foes, and its
// two buttons (Enter is Try again, Esc Give up; a tap on either); "Try again" goes into the checkpoint's Town, "Give up"
// ends the game. The "Weakened foes" chip under the wave meter, in the Town and on the field, with its tooltip. Booted
// TdGames (town_hud_test.dart's), the player choosing ([autoTryAgain] off).
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'town_hud_test.dart' show frames, townGame;

/// A board game at wave 20 whose Town before wave 21 was gone into and left (the checkpoint), a soldier on the field;
/// wave 21 begun and its army cut down (wipe_test.dart's way).
Game wipedAfterTown(Board b) {
  final g = townGame()
    ..wave = 20
    ..townAt = 21;
  expect((g.enterTown(), g.leaveTown()), (true, true));
  g.autoPlace('soldier');
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  b.state = g;
  g.startWave();
  for (final u in g.troops.where((u) => u.alive).toList()) {
    u.hp = 1;
    g.units.add(Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, u.pos + const Point(10, 0))..entered = true);
  }
  for (var i = 0; i < 100 && !g.wipedOut; i++) {
    g.tick(0.05);
  }
  expect((g.wipedOut, g.wipeAsk, g.wave, g.townAgain), (true, true, 20, true));
  return g;
}

/// The board booted (town_hud_test.dart's way) with no guide card nor foe splash over it; a game over asks for the
/// score's name ([main]'s `overlayBuilderMap`): an empty overlay stands in for its text field (mat_loot_test.dart's).
Future<Board> quietBoot(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadHudFont(tester);
  final game = TdGame();
  await tester.pumpWidget(GameWidget(game: game, overlayBuilderMap: {'name': (_, TdGame g) => const SizedBox.shrink()}));
  for (var i = 0; i < 3000 && !game.isLoaded; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(game.isLoaded, isTrue);
  return game.board
    ..welcome = null
    ..miniMapOpen = false
    ..guideSeen = null;
}

void main() {
  setUp(() => autoTryAgain = false);
  tearDown(() => autoTryAgain = true);

  for (final size in const [Size(1600, 947), Size(1266, 713), Size(915, 412)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('the dialog at $tag: after the hop, on the screen, its lines, 44-px buttons; Enter tries again into the '
        'Town, where the chip shows; on the field after it too', (tester) async {
      final b = await quietBoot(tester, size);
      b.autoStart.set(false);
      final g = wipedAfterTown(b);
      await frames(tester, 10);
      expect((b.wipeAskPanel, b.message), (Rect.zero, null), reason: 'not during the hop, and no message: the dialog says it');
      await frames(tester, 200); // the hop is over
      final panel = b.wipeAskPanel, buttons = b.wipeAskButtons, screen = Offset.zero & size;
      expect(panel, isNot(Rect.zero));
      for (final r in [panel, b.wipeAskRibbon, ...buttons.values]) {
        expect(screen.contains(r.topLeft) && screen.contains(r.bottomRight - const Offset(1, 1)), isTrue, reason: '$r on the screen');
      }
      expect(buttons.keys, ['giveUp', 'tryAgain']);
      for (final r in buttons.values) {
        expect(r.height, greaterThanOrEqualTo(44), reason: 'the tap rule');
        expect(panel.contains(r.center), isTrue);
      }
      expect(buttons['giveUp']!.right, lessThan(buttons['tryAgain']!.left));
      expect(g.wipeBack, 'Back to ${g.sceneIdentity.name}: wave 21 again');
      expect((g.inTown, g.canStartWave), (false, false), reason: 'the game waits on the choice');
      // A press beside the buttons does nothing; Enter is Try again.
      await tester.tapAt(panel.topLeft + const Offset(4, 4));
      await frames(tester, 3);
      expect(g.wipeAsk, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await frames(tester, 2);
      expect((g.wipeAsk, b.wipeAskPanel), (false, Rect.zero));
      for (var i = 0; i < 600 && !g.inTown; i++) {
        await frames(tester, 1);
      }
      expect((g.inTown, g.townCount, g.weakened), (true, 1, 1), reason: 'back in the same Town');
      await frames(tester, 60);
      // The chip in the Town: under the meter, its tooltip.
      final chip = b.weakChip, meter = b.waveMeter;
      expect(chip, isNot(Rect.zero));
      expect((chip.right, chip.top >= meter.bottom + 6, screen.contains(chip.bottomRight - const Offset(1, 1))), (meter.right, true, true));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(chip.center);
      await frames(tester, 30);
      expect(b.tooltipShown?.$1, Words.weakenedFoes);
      expect(b.tooltipShown?.$2, ['Monsters: -20% HP, -15% damage.', 'Until next Town.']);
      await mouse.moveTo(Offset.zero);
      // On the field after the Town: the chip stays, under the meter.
      expect(g.leaveTown(), isTrue);
      await frames(tester, 90);
      g.startWave();
      await frames(tester, 3);
      expect((g.wave, b.weakChip == Rect.zero), (21, false));
      expect(b.weakChip.right, b.waveMeter.right);
    });
  }

  testWidgets('Esc gives up: the game over, its screen and the furthest wave', (tester) async {
    final b = await quietBoot(tester, const Size(1600, 947));
    b.autoStart.set(false);
    final g = wipedAfterTown(b);
    await frames(tester, 200);
    expect(b.wipeAskPanel, isNot(Rect.zero));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await frames(tester, 5);
    expect((g.over, g.lives, g.wipeAsk, g.waveReached, b.wipeAskPanel, g.paused), (true, 0, false, 21, Rect.zero, false));
  });

  testWidgets('a tap on Try again, and on Give up', (tester) async {
    final b = await quietBoot(tester, const Size(915, 412));
    b.autoStart.set(false);
    var g = wipedAfterTown(b);
    await frames(tester, 200);
    await tester.tapAt(b.wipeAskButtons['tryAgain']!.center);
    await frames(tester, 3);
    expect((g.wipeAsk, g.over), (false, false));
    g = wipedAfterTown(b);
    await frames(tester, 200);
    await tester.tapAt(b.wipeAskButtons['giveUp']!.center);
    await frames(tester, 3);
    expect((g.wipeAsk, g.over), (false, true));
  });
}
