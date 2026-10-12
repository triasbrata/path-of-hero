import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';

// The army cap's warning on the board (decisions-log 161, docs/ui-hud.md "Message window" and "Wave meter"): the
// message window between waves while the army is full at the cap and the tide is on, once every 5 waves, held behind
// the "MENANG!" popup and another message; it fits a phone in the HUD's font, every glyph of it in that font; and the
// wave meter's tooltip ends with it. Beban's note and tooltip line (decisions-log 162), and the type caps' note under
// it (decisions-log 201), fit the phone too. One TdGame (its own file: a second TdGame in one file breaks the shared
// image cache, docs/testing.md). The rules: tide_test.dart.

/// Advances the game [n] frames.
Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Wave [won] won (its popup over) with the board's limits on and the army full at the cap: the free priest, 10
/// knights, 10 swordsmen and 10 lancers (each at its type's cap) and a soldier last.
Game atCap({int won = 63}) {
  final g = Game().boardRules()
    ..gold = 1 << 30
    ..wave = won
    ..victoryAt = -victoryTime
    ..capacity = armyMaxBoard;
  for (final type in ['knight', 'swordsman', 'lancer', 'soldier']) {
    while (g.armySize < armyMaxBoard && !g.typeFull(type)) {
      expect(g.autoPlace(type), isTrue);
    }
  }
  expect((g.armySize, g.troops.last.type), (armyMaxBoard, 'soldier'));
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..entered = true
      ..arriving = false;
  }
  return g;
}

/// The owner's w86 save after Beban (decisions-log 162): wave 86 won (its popup over), the tide from 66, 48 alive (the
/// free priest and 47 soldiers) over the board's cap of 36 (decisions-log 260: 12 over; 16 over the 32 it had), over it
/// since wave 82 (ramped in: wave 87's tide from 42),
/// and the "army" note seen.
Game overCap() {
  final g = Game()
    ..gold = 1 << 30
    ..wave = 86
    ..tideStart = 66
    ..overFrom = 82
    ..victoryAt = -victoryTime
    ..capacity = 48;
  for (var i = 0; g.armySize < 48; i++) {
    g.units.add(Unit(Side.troop, 'soldier', troopTypes['soldier']!, Point(i ~/ rows * tile + tile / 2, i % rows * tile + tile / 2))
      ..entered = true);
  }
  g.notes.add('army');
  return g.boardRules();
}

void main() {
  testWidgets('the cap\'s warning: between waves, once every 5 waves, after the win popup and other messages; it fits a '
      'phone; the meter\'s tooltip ends with it', (tester) async {
    tester.view
      ..physicalSize = const Size(1266, 713)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await loadHudFont(tester);
    final game = TdGame();
    await tester.pumpWidget(GameWidget(game: game));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      // onLoad decodes images in real time: let it run, then pump.
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue);
    final b = game.board
      ..welcome = null
      ..miniMapOpen = false;
    b.autoStart.set(false);

    final warning = capWarningText(armyMaxBoard, tidePercent(64));
    expect(warning, startsWith('${Words.army} full: cap 36 - ${Words.tide} +'));
    final font = fontChars();
    for (final line in [capWarningText(armyMaxBoard, 999), capTip(armyMaxBoard), overTip(60, 60), overNote(armyMaxBoard), capsNote(['Soldier 47/10'])]) {
      expect(line.runes.where((c) => c != 10 && !font.contains(c)).map(String.fromCharCode), isEmpty, reason: line);
    }

    // A game that came in without a win this session (a loaded save: its own notes are in the window) says nothing
    // until its first win.
    final loaded = b.state = atCap()..victoryAt = double.negativeInfinity;
    await frames(tester, 5);
    expect((loaded.capPressed, b.message), (true, null));
    // Below the cap nothing is said.
    final g = b.state = atCap();
    g.units.remove(g.troops.last);
    await frames(tester, 5);
    expect(b.message, isNull);
    // Full at the cap with the tide on: the message window says it, and the box is on the screen.
    expect(g.autoPlace('soldier'), isTrue);
    await frames(tester, 3);
    expect(b.message, warning);
    final box = b.messageBox;
    expect((box.left >= 0, box.right <= 1266, box.top >= 0), (true, true, true), reason: '$box');
    // Closed with a press, it doesn't come back in this wave's break, nor the next 4.
    await tester.tapAt(box.center);
    await frames(tester, 3);
    expect(b.message, isNull);
    for (var won = 63; won <= 67; won++) {
      g.wave = won;
      await frames(tester, 10);
      expect(b.message, isNull, reason: 'wave $won won');
    }
    g.wave = 68;
    await frames(tester, 3);
    expect(b.message, capWarningText(armyMaxBoard, tidePercent(69)));
    await tester.tapAt(b.messageBox.center);
    await frames(tester, 3);

    // Another message keeps the window: the warning waits until it closes.
    g.wave = 73;
    b.showMessage(Words.notEnoughGold);
    await frames(tester, 10);
    expect(b.message, Words.notEnoughGold);
    await tester.tapAt(b.messageBox.center);
    await frames(tester, 3);
    expect(b.message, capWarningText(armyMaxBoard, tidePercent(74)));
    await tester.tapAt(b.messageBox.center);
    await frames(tester, 3);

    // Just won: it waits for the "MENANG!" popup (victoryTime) to be over.
    g
      ..wave = 78
      ..victoryAt = g.t;
    await frames(tester, 10);
    expect(b.message, isNull);
    for (var i = 0; i < 400 && g.t - g.victoryAt < victoryTime; i++) {
      await frames(tester, 1);
    }
    await frames(tester, 3);
    expect(b.message, capWarningText(armyMaxBoard, tidePercent(79)));

    // The meter's tooltip ends with the cap's line while the army is full.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(b.tideBadgeAt.center);
    await frames(tester, 30);
    expect(b.tooltipShown?.$1, Words.tide);
    expect(b.tooltipShown!.$2, [...tideInfo(79).$2, capTip(armyMaxBoard)]);
    await mouse.moveTo(Offset.zero);
    await frames(tester);
    await mouse.removePointer();
    await tester.tapAt(b.messageBox.center);
    await frames(tester, 3);

    // On the phone (915x412) the two lines fit the screen with room to spare.
    tester.view.physicalSize = const Size(915, 412);
    g.wave = 83;
    await frames(tester, 40);
    expect(b.message, capWarningText(armyMaxBoard, tidePercent(84)));
    final phone = b.messageBox;
    expect((phone.left >= 8, phone.right <= 915 - 8, phone.bottom <= 412 - 8), (true, true, true), reason: '$phone');
    await tester.tapAt(phone.center);
    await frames(tester, 3);

    // Beban (decisions-log 162), on the phone: a save over the cap comes in with its one-time note, and its soldiers
    // over their type's cap with the type caps' (decisions-log 201) under it; the two fit.
    final over = b.state = overCap();
    await frames(tester, 5);
    expect(b.message, [overNote(armyMaxBoard), capsNote(['Soldier 47/10'])].join('\n'));
    final note = b.messageBox;
    expect((note.left >= 8, note.right <= 915 - 8, note.top >= 0, note.bottom <= 412), (true, true, true, true), reason: '$note');
    expect((over.notes.contains('over'), over.notes.contains('caps')), (true, true));
    await tester.tapAt(note.center);
    await frames(tester, 3);
    // Then the cap's warning, with wave 87's tide counted from 42: +56%.
    expect(tidePercent(87, 42), 56);
    expect(b.message, capWarningText(armyMaxBoard, 56));
    await tester.tapAt(b.messageBox.center);
    await frames(tester, 3);
    // The meter shows it, and its tooltip has Beban's line before the cap's, inside the screen.
    expect(b.tideBadge, '+56%');
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: Offset.zero);
    await pointer.moveTo(b.tideBadgeAt.center);
    await frames(tester, 30);
    expect(b.tooltipShown!.$2, [...tideInfo(87, 42).$2, overTip(12, 24), capTip(armyMaxBoard)]);
    final tip = b.tooltipBox;
    expect((tip.left >= 0, tip.right <= 915, tip.top >= 0, tip.bottom <= 412), (true, true, true, true), reason: '$tip');
    await pointer.moveTo(Offset.zero);
    await frames(tester);
    await pointer.removePointer();
  });
}
