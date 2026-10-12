// The two Autos named apart (decisions-log 290; docs/ui-hud.md "Start/Pause toggle", "Spawn bar"; the owner, 2026-10-09:
// "auto yang di bawah sama auto yang di atas membingungkan karna sama sama tulisan auto", then his pick "Auto Wave + Auto
// Buy"): the top band's starts the next wave and says "Auto Wave" (Words.autoWave), the spawn bar's buys the fallen back
// and says "Auto Buy" (Words.autoBuy). No string in lib/ names either "Auto" alone. At the owner's 1600x947, the desk's
// 1266x713, the tablet's 1164x777 and the landscape phone's 915x412 each button is as wide as its words with the
// button's margins, nothing of the top band lies over another piece (Auto Wave on: its countdown running, its hold line
// "Army 1/6 · Auto Wave waits" showing, a wave, a Town's "Leave town", no countdown there: decisions-log 328), and their
// taps do what they did. One TdGame
// per widget test; no wave is won here (the Board would save).
import 'package:flame/components.dart' show TextPaint;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/hud_font.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/settings.dart';

import 'lib_literals.dart';
import 'touch_hud_test.dart' show boot, frames, pieces;

const sizes = [Size(1600, 947), Size(1266, 713), Size(1164, 777), Size(915, 412)];

/// [t]'s width in the game's font at [size] px, as the HUD measures it.
double textW(String t, double size) => TextPaint(style: hudStyle(size)).getLineMetrics(t).width;

/// A `_button` as wide as [label] on it at [height] px tall: the words at 0.42 of the height (14 to 28 px) and the
/// frame's margins, 4·k + 6 a side (k = ⌊height / 16⌋, 1 to 3), as the top band's Auto and the spawn bar's.
double buttonW(String label, double height, {bool whole = false}) {
  final k = (height / 16).floorToDouble().clamp(1.0, 3.0), font = (height * 0.42).clamp(14.0, 28.0);
  return (textW(label, whole ? font.roundToDouble() : font) + 2 * (4 * k + 6)).roundToDouble();
}

/// The top band's pieces this frame, Auto Wave's hold line with them (Rect.zero ones left out), and any two that overlap.
List<String> overlaps(Board b) {
  final at = {...pieces(b), 'held': b.autoHeldLine}..removeWhere((_, r) => r == Rect.zero);
  final names = at.keys.toList();
  return [
    for (var i = 0; i < names.length; i++)
      for (var j = i + 1; j < names.length; j++)
        if (at[names[i]]!.overlaps(at[names[j]]!)) '${names[i]} over ${names[j]}',
  ];
}

Future<void> tapOn(WidgetTester tester, Rect r) async {
  expect(r, isNot(Rect.zero));
  await tester.tapAt(r.center);
  await frames(tester);
}

void main() {
  test('no string in lib/ names an Auto alone: the top band\'s is "Auto Wave", the spawn bar\'s "Auto Buy"', () {
    expect((Words.autoWave, Words.autoBuy), ('Auto Wave', 'Auto Buy'));
    final alone = RegExp(r'(?<![A-Za-z])Auto(?![A-Za-z]| Wave| Buy)');
    final found = [
      for (final f in libFiles())
        for (final s in dartLiterals(f.readAsStringSync()))
          if (alone.hasMatch(s)) '${f.path}: "$s"',
    ];
    expect(found, isEmpty);
    // The finder itself: an Auto alone is found, the two names aren't.
    expect([for (final s in ['Auto', '"Auto" leaves', 'Auto waits', 'Auto Wave', 'Auto Buy: x', 'Autos']) alone.hasMatch(s)],
        [true, true, true, false, false, false]);
  });

  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('$tag: "Auto Wave" in the top band and "Auto Buy" on the spawn bar, each as wide as its words; nothing '
        'of the top band over another piece with the countdown, the hold line, a wave, a Town; the taps as before',
        (tester) async {
      final b = await boot(tester);
      tester.view.physicalSize = size;
      addTearDown(() => b.autoStart.set(false));

      // Between waves, Auto Wave on, its countdown running: a full army, so it isn't held.
      var g = b.state = Game().boardRules()..gold = 99999;
      while (!g.typeFull('soldier') && g.autoPlace('soldier')) {}
      await frames(tester, 40);
      b.autoStart
        ..set(true)
        ..won();
      await frames(tester, 70); // over a second: "Start 4"
      expect(b.autoStart.shown, lessThan(5), reason: '$tag: counting down');
      expect((g.autoHeld, b.autoHeldLine), (false, Rect.zero), reason: tag);
      final auto = b.autoButton, x2 = b.speedButton, meter = b.waveMeter;
      expect(auto.width, buttonW(Words.autoWave, auto.height), reason: '$tag: as wide as "Auto Wave" on it, $auto');
      expect(auto.width, greaterThan(buttonW('Auto', auto.height)), reason: tag);
      expect(overlaps(b), isEmpty, reason: '$tag: countdown');
      expect((x2.right < auto.left, auto.right < meter.left, b.toggleButton.right < x2.left), (true, true, true), reason: tag);

      // Held: one troop of six, the line under the toggle in Auto Wave's name, on the screen and clear of the band.
      g = b.state = Game().boardRules()..gold = 99999;
      await frames(tester, 40);
      b.autoStart.won();
      await frames(tester, 20);
      final line = b.autoHeldLine, font = (b.toggleButton.height * 0.42).clamp(14.0, 28.0) * 0.7;
      expect((g.autoHeld, line == Rect.zero), (true, false), reason: '$tag: held');
      expect(line.width, closeTo(textW('${Words.army} ${g.armySize}/${g.armyCap} · ${Words.autoWave} waits', font), 0.01),
          reason: '$tag: "Army 1/6 · Auto Wave waits"');
      expect(line.left >= 0 && line.right <= size.width && line.top >= b.toggleButton.bottom, isTrue, reason: '$tag: $line');
      expect(overlaps(b), isEmpty, reason: '$tag: held');
      expect(b.autoButton, auto, reason: '$tag: Auto Wave stays put');

      // The spawn bar's Auto Buy, on the step right of the hotbar (decisions-log 287): its face (the press area less k each
      // way) a slot tall and as wide as its words.
      final press = b.autoReplaceButton, face = press.deflate(b.hudScale);
      expect(face.width, buttonW(Words.autoBuy, face.height, whole: true), reason: '$tag: as wide as "Auto Buy" on it, $face');
      expect(b.spawnBarArrows, (Rect.zero, Rect.zero), reason: '$tag: all nine cards still fit beside it');
      expect(press.overlaps(b.capacityButton), isFalse, reason: tag);

      // The taps: Auto Buy turns autoReplace on and off; Auto Wave turns the countdown's switch off (kept in settings.json)
      // and on.
      await tapOn(tester, press);
      expect(g.autoReplace, isTrue, reason: tag);
      await tapOn(tester, press);
      expect(g.autoReplace, isFalse, reason: tag);
      await tapOn(tester, b.autoButton);
      expect((b.autoStart.on, b.autoStart.left, loadSettings().autoStart), (false, null, false), reason: tag);
      await tapOn(tester, b.autoButton);
      expect((b.autoStart.on, loadSettings().autoStart), (true, true), reason: tag);

      // A wave: the book button comes; nothing moves or overlaps.
      g.startWave();
      await frames(tester, 10);
      expect(overlaps(b), isEmpty, reason: '$tag: wave');
      expect((b.autoButton, b.speedButton, b.waveMeter), (auto, x2, meter), reason: '$tag: wave');

      // A Town, Auto Wave on: "Leave town" on the toggle (no countdown there, decisions-log 328), no overlap.
      g = b.state = Game()
        ..gold = 99999
        ..wave = 99
        ..townAt = 100;
      expect(g.enterTown(), isTrue);
      await frames(tester, 3);
      expect(overlaps(b), isEmpty, reason: '$tag: Town');
      expect(b.autoButton.width, auto.width, reason: '$tag: Town');
      b.state = Game();
      await frames(tester, 3);
    });
  }
}
