// A Town takes no wave number (decisions-log 330; the owner, 2026-10-12: "harusnya kota itu tidak di hitung wave, jadi
// setelah wave 7 masuk kota, maka ketika keluar kota adalah wave 8 bukan wave 9"): wave 7 won, the Town marked for it
// is gone into, the meter there says "next wave 8", and the wave started after it is left is 8: left by hand with Auto
// off and on, after a wipe played wave 7 again first (decisions-log 322), from a save made in the Town, and with the
// roll marking it by itself. Booted TdGames (town_hud_test.dart's), the Towns on.
import 'dart:math';

import 'package:flutter/material.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/guide_rules.dart';
import 'package:tower_defense/guide_text.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/save.dart';

import 'town_hud_test.dart' show boot, frames, townGame;

/// The next wave started and won at once on the board (its one monster gone).
Future<void> winNext(WidgetTester tester, Game g) async {
  g
    ..startWave()
    ..queue.clear()
    ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
  await frames(tester, 3);
  expect((g.waveActive, g.over), (false, false));
}

/// Pumps until [g] is in its due Town, and past the fade.
Future<void> intoTown(WidgetTester tester, Board b, Game g) async {
  for (var i = 0; i < 600 && !g.inTown; i++) {
    await frames(tester, 1);
  }
  expect(g.inTown, isTrue,
      reason: 'gone into the Town (wave ${g.wave}, due ${g.townDue}, card ${b.coachCard}, chests ${g.chests.length})');
  await frames(tester, 60);
}

/// "Leave town", then the next wave: by Start with Auto off, by Auto Wave's countdown with it on. The wave it started.
Future<int> leaveAndStart(WidgetTester tester, Board b, Game g) async {
  if (b.messageBox != Rect.zero) await tester.tapAt(b.messageBox.center); // a wipe's note: a tap closes it first
  await frames(tester, 3);
  final before = g.wave;
  await tester.tapAt(b.startButton.center);
  await frames(tester, 3);
  expect((g.inTown, g.waveActive, g.wave), (false, false, before), reason: 'left: the same wave number, none started');
  if (!b.autoStart.on) {
    await frames(tester, 60); // the fade back
    await tester.tapAt(b.startButton.center);
  }
  for (var i = 0; i < 800 && !g.waveActive; i++) {
    await frames(tester, 1);
  }
  expect(g.waveActive, isTrue, reason: 'a wave on');
  return g.wave;
}

void main() {
  for (final auto in [false, true]) {
    testWidgets('wave 7 won, its Town gone into: "next wave 8" there; left by hand (Auto ${auto ? 'on' : 'off'}), the '
        'wave after it is 8', (tester) async {
      final b = await boot(tester);
      b.autoStart.set(auto);
      addTearDown(() => b.autoStart.set(false));
      final g = b.state = townGame()
        ..wave = 6
        ..townAt = 8; // marked after wave 6: "Town after wave 7"
      await frames(tester, 3);
      expect(b.townChipLabel, 'Town after wave 7');
      await winNext(tester, g);
      expect((g.wave, g.townDue), (7, true));
      await intoTown(tester, b, g);
      expect(b.townMeterText, endsWith('next wave 8'));
      expect(g.log.entries.whereType<TownEntered>().single.wave, 7);
      expect(await leaveAndStart(tester, b, g), 8);
      expect(g.log.entries.whereType<TownLeft>().single.wave, 7);
      await frames(tester, 30);
    });
  }

  testWidgets('a wipe first: wave 7 lost and played again, then won, its Town; "next wave 8" there, and wave 8 after it',
      (tester) async {
    final b = await boot(tester);
    b.autoStart.set(false);
    final g = townGame()
      ..wave = 6
      ..townAt = 8;
    g.autoPlace('soldier');
    for (final u in g.troops) {
      u
        ..pos = u.post
        ..arriving = false;
    }
    // Wave 7 begun, its army cut down (wipe_test.dart's way): the wave goes back to 6, its Town not due yet.
    g.startWave();
    for (final u in g.troops.where((u) => u.alive).toList()) {
      u.hp = 1;
      g.units.add(Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, u.pos + const Point(10, 0))..entered = true);
    }
    for (var i = 0; i < 100 && !g.wipedOut; i++) {
      g.tick(0.05);
    }
    expect((g.wipedOut, g.wave, g.lostWave, g.townDue, g.townAt), (true, 6, 7, false, 8));
    b.state = g;
    await frames(tester, 200); // the swept monsters' hop
    await winNext(tester, g);
    expect((g.wave, g.townDue), (7, true));
    await intoTown(tester, b, g);
    expect(b.townMeterText, endsWith('next wave 8'));
    expect(await leaveAndStart(tester, b, g), 8);
    await frames(tester, 30);
  });

  testWidgets('a save made in the Town after wave 7 reopens in it: "next wave 8", and wave 8 after it', (tester) async {
    final b = await boot(tester);
    b.autoStart.set(false);
    final g = b.state = townGame()
      ..wave = 6
      ..townAt = 8;
    await frames(tester, 3);
    await winNext(tester, g);
    await intoTown(tester, b, g);
    final back = loadGame()!; // saved as it went in
    expect((back.wave, back.inTown, back.townAt), (7, true, 8));
    b.state = back;
    await frames(tester, 10);
    expect(b.townMeterText, endsWith('next wave 8'));
    expect(await leaveAndStart(tester, b, back), 8);
    await frames(tester, 30);
  });

  testWidgets('the roll marking it: every roll hitting, the first Town after wave 6 ("Town after wave 6"), "next wave 7" '
      'there, and wave 7 after it', (tester) async {
    final b = await boot(tester);
    b.autoStart.set(false);
    final seen = b.guideSeen;
    addTearDown(() => b.guideSeen = seen);
    b.guideSeen = {guideIntro, ...guideEn.cards.keys}; // the first waves' cards would wait to be closed
    final g = b.state = townGame()
      ..draftPolicy = 'first' // wave 5's boss chest taken at once (on the board Start opens a waiting one first)
      ..townRules = TownRules.patch({
        'schedule': {'chanceStart': 1.0},
      });
    await frames(tester, 3);
    while (!g.townMarked) {
      await winNext(tester, g);
      expect(g.wave, lessThanOrEqualTo(5));
    }
    expect((g.wave, g.townAt), (5, 7), reason: 'the first roll that may hit: after wave 5, for the Town before wave 7');
    await frames(tester, 30);
    expect(b.townChipLabel, 'Town after wave 6');
    await winNext(tester, g);
    await intoTown(tester, b, g);
    expect(b.townMeterText, endsWith('next wave 7'));
    expect(await leaveAndStart(tester, b, g), 7);
    await frames(tester, 30);
  });
}
