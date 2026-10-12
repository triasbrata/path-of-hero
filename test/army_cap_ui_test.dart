// The owner's limits on the board (decisions-log 141, 201; docs/ui-hud.md): its games play with them, the troop counter
// says "48/36" and each type's "17/5", an old save's one-time notes, a full type's Army cell ("x5/5" in red) and its
// detail's Buy refused with why, the detail's two-tap Release, and the Auto hold under the start button. The rules: army_cap_test.dart. One
// TdGame per widget test.
//
// Never let a wave be won or the game end here (the Board then saves): a wave begun runs a few frames only.
import 'dart:convert';
import 'dart:io';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/auto_start.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/save.dart' show Welcome;

import 'hud_font.dart';
import 'spawn_bar_test.dart' show into;

/// Boots one TdGame in a [size] window, past the welcome screen, with the game's font and the minimap folded.
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

Future<void> tapOn(WidgetTester tester, Offset p) async {
  await tester.tapAt(p);
  await frames(tester);
}

/// The owner's wave-86 save from before the limits: 48 troops of 5 types.
Game w86() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>);

/// A game with the limits on, room for 12, the priests at their cap (5/5), a soldier, an archer and a knight.
Game fullPriests() {
  final g = Game().boardRules()
    ..gold = 5000
    ..capacity = 12;
  for (final type in ['priest', 'priest', 'priest', 'priest', 'soldier', 'archer', 'knight']) {
    expect(g.autoPlace(type), isTrue);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  return g;
}

void main() {
  testWidgets('the board plays every game with the limits: its first one and a new one from the welcome screen', (tester) async {
    final b = await boot(tester);
    expect((b.state.armyMax, b.state.typeCap), (armyMaxBoard, typeCapBoard));
    final first = b.state;
    b.welcome = Welcome(null, discard: () {}); // no save: "Main Baru" starts at once
    await frames(tester);
    await tapOn(tester, const Offset(1266 / 2, 713 * 0.38 - 156 + 120 + 28)); // "Main Baru", the panel's first button
    expect((b.welcome, identical(b.state, first)), (null, false));
    expect((b.state.armyMax, b.state.typeCap), (armyMaxBoard, typeCapBoard));
    expect(b.state.troopCounts, {Game.freeHealer: 1});
    // A test's own plain Game() keeps today's rules.
    b.state = Game();
    expect((b.state.armyMax, b.state.typeCap), (null, null));
    await frames(tester, 30); // past the tap's own timer
  });

  testWidgets('the w86 save: the counter says 48/36 and each type against its cap, and its notes show once', (tester) async {
    final b = await boot(tester);
    final g = b.state = w86().boardRules()..chests.clear(); // its catch-up chests' popup would take the taps (draft_hud_test.dart)
    await frames(tester, 3);
    // With the tide's news for a save from before it (#92), Beban's (decisions-log 162), the Pusaka's (decisions-log
    // 151) and the Shadows' catch-up (decisions-log 319: its Artifacts owe 10), in one window.
    expect(b.message, '${tideNews.$1} ${tideNews.$2}\nThe army cap is now 36. You keep your troops;\n'
        'buy more when under 36.\n${overNote(36)}\n${capsNote(['Priest 17/5', 'Wizard 9/8', 'Templar 13/10'])}\n'
        '${[...pusakaNoteLines, pusakaNoteSuggested].join('\n')}\n${g.omenCatchUpNote}');
    expect(g.omenCatchUpNote, 'Monsters answer your ${Words.artifact}s: 10 ${Words.shadow}s come, 2 each wave');
    expect(g.tideCaughtUp, isFalse);
    await frames(tester, 150); // more than a plain message's 2 s
    expect(b.message, isNotNull, reason: 'a note stays longer');
    expect(b.troopCountText, '48/36');
    await tapOn(tester, b.troopCounter.center); // the press closes the note, and opens the list
    expect(b.message, isNull);
    expect(b.troopListTypes, ['archer', 'priest', 'armored_axeman', 'wizard', 'knight_templar']);
    expect(b.troopListCounts, ['3/8', '17/5', '6/10', '9/8', '13/10']);
    b.state = Game(); // another game, then the save again: no note
    await frames(tester);
    b.state = g;
    await frames(tester);
    expect(b.message, isNull);
    await frames(tester, 30); // past the tap's own timer
  });

  testWidgets('the Army page: a full type shows "x5/5" in red and its spawn bar card is refused with why (decisions-log '
      '283), and Release takes two taps on the picked type\'s detail', (tester) async {
    final b = await boot(tester);
    final g = b.state = fullPriests();
    await frames(tester, 40); // the book floats in between waves
    expect((g.typeFull('priest'), g.typeLocked('priest')), (true, false));
    expect((b.troopRowCount('priest').$1, b.troopRowCount('archer').$1, b.troopRowCount('wizard').$1), ('x5/5', 'x1/8', 'x0/8'));
    expect(b.troopRowCount('priest').$2, isNot(b.troopRowCount('archer').$2), reason: 'red at the cap');
    final why = g.buyRefusal('priest');
    expect(why, 'Priests full 5/5');
    expect((b.troopPicked, b.troopDetail('buy')), ('soldier', Rect.zero), reason: 'no Buy in the book (decisions-log 283)');
    await tapOn(tester, b.troopRow('priest').center); // picked: its detail says it too
    expect(b.troopDetailWords('heading'), contains('x5/5'));
    final card = await into(tester, b, 'priest'); // scrolled into view
    expect(b.spawnCardLook('priest'), 'refused', reason: 'the bar\'s card: the forbidden sign');
    await tapOn(tester, card.center);
    expect((b.message, g.troopCounts['priest']), (why, 5));
    await frames(tester, 140); // the message goes (a press on it would only close it)

    // Release on the picked type's detail, while the type has troops alive.
    await tapOn(tester, b.troopRow('wizard').center);
    expect(b.releaseChip('wizard'), Rect.zero);
    for (final type in g.troopCounts.keys) {
      await tapOn(tester, b.troopRow(type).center);
      expect(b.releaseChip(type), isNot(Rect.zero), reason: type);
    }
    final refund = (g.priceOf('soldier') * releaseRefund).round();
    expect(g.releaseRefundOf('soldier'), refund);
    expect(b.releaseConfirm, Rect.zero);
    await tapOn(tester, b.troopRow('soldier').center);
    await tapOn(tester, b.releaseChip('soldier').center);
    expect((b.releaseArmed, b.troopPicked, g.troopCounts['soldier'], g.armySize), ('soldier', 'soldier', 1, 8),
        reason: 'the first tap only arms it');
    expect(b.releaseConfirm.left, greaterThan(b.troopRow('soldier').right), reason: 'its confirm on the right page');
    await tapOn(tester, b.troopRow('archer').center); // any other tap lets it go (and picks the archer)
    expect((b.releaseArmed, b.releaseConfirm, b.troopPicked), (null, Rect.zero, 'archer'));
    await tapOn(tester, b.troopRow('soldier').center);
    final alive = g.armySize - 1, gold = g.gold;
    await tapOn(tester, b.releaseChip('soldier').center);
    await tapOn(tester, b.releaseConfirm.center);
    expect((b.releaseArmed, g.troopCounts['soldier'], g.armySize, g.gold), (null, null, alive, gold + refund));
    expect(b.message, '${troopTypeNames['soldier']} sent home: 1 troop, +${thousands(refund)} gold');
    await frames(tester);
    expect(b.releaseChip('soldier'), Rect.zero);
    await frames(tester, 140); // the message goes

    // A priest sent home frees a place under the cap; a Hero's type can't be released.
    g.troops.firstWhere((u) => u.type == 'priest').hero = true;
    await tapOn(tester, b.troopRow('priest').center);
    await tapOn(tester, b.releaseChip('priest').center);
    expect((b.releaseArmed, b.message, g.troopCounts['priest']), (null, releaseRefusals.hero, 5));
    await frames(tester, 30); // past the tap's own timer
  });

  testWidgets('Auto holds below 75% of the cap and says so under the start button; refilling or Mulai goes on', (tester) async {
    final b = await boot(tester);
    for (final size in const [Size(1266, 713), Size(915, 412)]) {
      tester.view.physicalSize = size;
      final g = b.state = Game().boardRules()..gold = 5000; // 1 of 6
      await frames(tester, 40);
      b.autoStart
        ..set(true)
        ..won(); // as after a win
      await frames(tester, 70); // over a second
      expect((g.autoHeld, b.autoStart.shown, g.waveActive), (true, autoStartDelay.round(), false), reason: '$size');
      final line = b.autoHeldLine;
      expect(line, isNot(Rect.zero), reason: '$size');
      expect(line.left >= 0 && line.right <= size.width && line.top >= b.startButton.top, isTrue, reason: '$size: $line');
      for (var i = 0; i < 4; i++) {
        g.autoPlace('soldier');
      }
      await frames(tester, 70);
      expect((g.autoHeld, b.autoHeldLine), (false, Rect.zero), reason: '$size: 5 of 6');
      expect(b.autoStart.shown, lessThan(autoStartDelay.round()), reason: '$size: the countdown goes on');

      // Gutted again: held, and Mulai starts the wave anyway.
      g.units.removeWhere((u) => u.type == 'soldier');
      b.autoStart.won();
      await frames(tester, 10);
      expect(b.autoStart.shown, autoStartDelay.round());
      await tapOn(tester, b.startButton.center);
      expect((g.wave, g.waveActive), (1, true), reason: '$size');
      b.autoStart.set(false);
    }
    await frames(tester, 30); // past the tap's own timer
  });
}
