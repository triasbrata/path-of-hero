// The first-time guide on the board (docs/ui-hud.md "Guide", lib/coach.dart): "Main Baru" opens the intro on a device
// that hasn't seen it (once: then it is in settings.json's seen set); its Lewati, Kembali and Lanjut ("Main!" on its
// last page), a tap anywhere else, Space, Enter and the arrows; Esc closes it without pausing, P does nothing; nothing
// under a card takes a tap, a drag, a right click or a tooltip; Auto's countdown waits while a card shows; "Cara Main"
// on the welcome screen plays the intro over it; the pointers P1-P5 between waves, each ending on its action, and the
// first two or the item ones dropped when not done in two breaks; with no seen set (a widget test's) the guide is off.
// The words: guide_text_test.dart; when the cards are due: guide_rules_test.dart; the fit: coach_fit_test.dart.
// One TdGame per widget test; the board saves settings.json and the game into the test file's temp dir
// (flutter_test_config.dart).
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/auto_start.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/guide_rules.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/save.dart' show Welcome;
import 'package:tower_defense/settings.dart';

import 'hud_font.dart';

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

Future<void> tapOn(WidgetTester tester, Rect r) async {
  expect(r, isNot(Rect.zero));
  await tester.tapAt(r.center);
  await frames(tester);
}

Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await frames(tester);
}

/// "Main Baru" on a welcome screen with no save, on a device whose seen set is [seen].
Future<void> mainBaru(WidgetTester tester, Board b, Set<String>? seen) async {
  b
    ..guideSeen = seen
    ..welcome = Welcome(null, discard: () {});
  await frames(tester);
  await tapOn(tester, b.welcomeButtons['Main Baru']!);
}

/// The book's tab for [page] ('troops', 'bag', ...).
Rect tab(Board b, String page) => b.bookTabs.firstWhere((t) => t.$1 == page).$2;

/// A board game between waves: the board's rules, no army limit (so Auto's countdown waits only for what is tested),
/// gold to spare.
Game boardGame() => Game(Random(1)).boardRules()
  ..armyMax = null
  ..gold = 200000;

/// [g]'s wave started and won at once (its one monster gone), then the cheering over.
Future<void> winWave(WidgetTester tester, Game g) async {
  g
    ..startWave()
    ..queue.clear()
    ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
  await frames(tester, 3);
  expect(g.waveActive, isFalse);
  for (var i = 0; i < 400 && g.t - g.victoryAt < victoryTime; i++) {
    await frames(tester, 1);
  }
  await frames(tester, 30); // the book floats in
}

void main() {
  testWidgets("Main Baru opens the intro on a device that hasn't seen it; its buttons, a tap elsewhere and the keys turn "
      'its pages; Lewati closes it, seen and saved, and the next Main Baru opens none', (tester) async {
    final b = await boot(tester);
    await mainBaru(tester, b, {});
    expect(b.welcome, isNull);
    expect(b.coachCard, (guideIntro, 0));
    await frames(tester, 30);
    expect(b.coachButtons.keys, unorderedEquals(['skip', 'back', 'next']));
    await tapOn(tester, b.coachButtons['back']!);
    expect(b.coachCard, (guideIntro, 0), reason: 'Kembali is greyed on the first page: the tap does nothing');
    await tapOn(tester, b.coachButtons['next']!);
    expect(b.coachCard, (guideIntro, 1));
    await tapOn(tester, b.coachButtons['back']!);
    expect(b.coachCard, (guideIntro, 0));
    await tapOn(tester, const Rect.fromLTWH(4, 700, 4, 4)); // off the card: on
    expect(b.coachCard, (guideIntro, 1));
    await key(tester, LogicalKeyboardKey.space);
    expect(b.coachCard, (guideIntro, 2));
    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(b.coachCard, (guideIntro, 1));
    await key(tester, LogicalKeyboardKey.enter);
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(b.coachCard, (guideIntro, 3));
    expect(b.guideSeen, isEmpty, reason: 'not seen while it shows');
    await tapOn(tester, b.coachButtons['skip']!);
    expect(b.coachCard, isNull);
    expect(b.guideSeen, {guideIntro});
    expect(loadSettings().seen, {guideIntro}, reason: 'kept in settings.json');

    await mainBaru(tester, b, b.guideSeen);
    await frames(tester, 10);
    expect((b.welcome, b.coachCard), (null, null), reason: 'seen: no intro');
  });

  testWidgets('the intro\'s last page says "Main!", which closes it; on the phone too', (tester) async {
    final b = await boot(tester, const Size(915, 412));
    await mainBaru(tester, b, {});
    for (var i = 0; i < 6; i++) {
      await tapOn(tester, b.coachButtons['next']!);
    }
    expect(b.coachCard, (guideIntro, 6));
    await tapOn(tester, b.coachButtons['next']!);
    expect(b.coachCard, isNull);
    expect(b.guideSeen, contains(guideIntro));
    await frames(tester, 30);
  });

  testWidgets('Esc closes a card without pausing the game, and P under it does nothing; after it Esc pauses again',
      (tester) async {
    final b = await boot(tester);
    await mainBaru(tester, b, {});
    final g = b.state;
    await key(tester, LogicalKeyboardKey.keyP);
    expect((b.coachCard, g.paused), ((guideIntro, 0), false));
    await key(tester, LogicalKeyboardKey.escape);
    expect((b.coachCard, g.paused), (null, false));
    expect(b.guideSeen, contains(guideIntro));
    await key(tester, LogicalKeyboardKey.escape);
    expect(g.paused, isTrue, reason: 'the card gone, Esc is the pause again');
  });

  testWidgets('nothing under a card reacts: a row, the top band, a tab, a drag, a tooltip; each tap only turns its page',
      (tester) async {
    final b = await boot(tester);
    final g = b.state = boardGame()..inventory[Item.sword] = 1;
    await frames(tester, 40);
    final row = b.spawnCard('soldier'), hp = b.itemCells.first.$1; // the spawn bar's first card (decisions-log 283)
    final band = {'start': b.startButton, 'auto': b.autoButton, 'speed': b.speedButton}; // the pause: the keys' test
    final bag = tab(b, 'bag'), army = g.armySize, priest = g.troops.single, from = priest.post;
    b
      ..guideSeen = {}
      ..openGuide(guideIntro);
    await frames(tester, 30);
    var page = 0;
    for (final (what, r) in [('row', row), ...band.entries.map((e) => (e.key, e.value)), ('Tas tab', bag)]) {
      expect(b.coachButtons.values.any((btn) => btn.overlaps(r)), isFalse, reason: '$what: clear of the card\'s buttons');
      await tapOn(tester, r);
      expect(b.coachCard, (guideIntro, ++page), reason: '$what: the tap turned the page');
    }
    expect((g.armySize, g.waveActive, b.autoStart.on, b.speed, g.paused), (army, false, false, 1, false));
    expect(page, 5, reason: 'two pages left: the drag and the last');

    // A drag of the free Pendeta to the next cell, and a right click: nothing.
    final step = from.y < fieldH / 2 ? tile : -tile;
    final drag = await tester.startGesture(b.toScreen(from.x, from.y));
    await drag.moveBy(Offset(0, step / 2));
    await frames(tester);
    await drag.moveTo(b.toScreen(from.x, from.y + step));
    await frames(tester);
    await drag.up();
    await frames(tester);
    expect(priest.post, from, reason: 'not moved');
    expect(b.coachCard?.$2, page + 1, reason: 'the drag began as a press on the card');

    // The mouse resting on a row's HP: no tooltip while the card shows, and one once it is gone.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(hp.center);
    await frames(tester, 40);
    expect((b.tooltipShown, b.hovered, b.coveredAt(b.toScreen(from.x, from.y))), (null, null, true));
    await key(tester, LogicalKeyboardKey.escape);
    expect(b.coachCard, isNull);
    await mouse.moveTo(b.itemCells.first.$1.center); // where it is now: the book bobs
    await frames(tester, 25);
    expect(b.tooltipShown, isNotNull, reason: 'the HUD under it works again');
    await mouse.removePointer();
    expect((g.armySize, g.waveActive, b.bagOpen), (army, false, false), reason: 'still on Pasukan');
  });

  testWidgets('under a card a right click and the wheel leave the loot in hand and the list as they are, and Esc closes '
      'the card without putting it back', (tester) async {
    final b = await boot(tester);
    final g = b.state = boardGame()..inventory[Item.sword] = 1;
    await frames(tester, 40);
    await tapOn(tester, tab(b, 'bag'));
    await tapOn(tester, b.bagSlot(Item.sword));
    expect(b.picked, Item.sword);
    await tapOn(tester, b.bagAction(BagAction.giveTroops)); // its type rows (decisions-log 202)
    final rows = [for (final r in b.assignRows) r.$1], list = b.assignList;
    b
      ..guideSeen = {guideIntro, ...guidePointers}
      ..openGuide('K1');
    await frames(tester, 30);
    final mouse = TestPointer(1, PointerDeviceKind.mouse, null, kSecondaryButton);
    await tester.sendEventToBinding(mouse.hover(list.center));
    await tester.sendEventToBinding(mouse.down(list.center));
    await tester.sendEventToBinding(mouse.up());
    await frames(tester);
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 1000)));
    await frames(tester);
    expect((b.coachCard, b.picked), (('K1', 0), Item.sword), reason: 'the card stays, the loot in hand too');
    await key(tester, LogicalKeyboardKey.escape);
    expect((b.coachCard, b.picked), (null, Item.sword));
    expect([for (final r in b.assignRows) r.$1], rows, reason: 'the list not scrolled');
    await tester.sendEventToBinding(mouse.removePointer());
    expect(g.inventory[Item.sword], 1);
  });

  testWidgets("Auto's countdown waits while a card shows, and goes on once it is closed", (tester) async {
    final b = await boot(tester);
    final g = b.state = boardGame();
    b.autoStart.set(true);
    addTearDown(() => b.autoStart.set(false));
    await frames(tester, 10);
    await winWave(tester, g);
    final left = b.autoStart.left!;
    expect(left, lessThan(autoStartDelay), reason: 'counting');
    b
      ..guideSeen = {guideIntro, ...guidePointers}
      ..openGuide('K1');
    await frames(tester, 2);
    final held = b.autoStart.left!;
    await frames(tester, 90);
    expect((b.autoStart.left, g.waveActive), (held, false), reason: 'waits for the card');
    await tapOn(tester, b.coachPanel);
    expect(b.coachCard, isNull);
    expect(b.guideSeen, contains('K1'));
    await frames(tester, 30);
    expect(b.autoStart.left!, lessThan(held), reason: 'counts again');
  });

  testWidgets('"How to Play" (id \'Cara Main\') on the welcome screen plays the intro over it; the buttons under it do nothing, and closed it '
      'leaves the welcome screen as it was', (tester) async {
    final b = await boot(tester);
    b
      ..guideSeen = {}
      ..welcome = Welcome(null, discard: () {});
    await frames(tester);
    final buttons = b.welcomeButtons;
    expect(buttons.keys, containsAll(['Main Baru', 'Papan Skor', 'Cara Main']));
    await tapOn(tester, buttons['Cara Main']!);
    expect(b.coachCard, (guideIntro, 0));
    await frames(tester, 30);
    await tapOn(tester, buttons['Main Baru']!);
    expect(b.welcome, isNotNull, reason: 'Main Baru under it: no new game');
    expect(b.coachCard, (guideIntro, 1), reason: 'only the page turned');
    await tapOn(tester, buttons['Papan Skor']!);
    expect(b.coachCard, (guideIntro, 2), reason: 'nor the scoreboard');
    await key(tester, LogicalKeyboardKey.escape);
    expect(b.welcome, isNotNull);
    expect(b.coachCard, isNull);
    expect(b.guideSeen, {guideIntro}, reason: 'watched there, it is seen');
    await tapOn(tester, b.welcomeButtons['Main Baru']!);
    expect((b.welcome, b.coachCard), (null, null), reason: 'and Main Baru then opens no intro');
    await frames(tester, 30);
  });

  testWidgets('with no seen set (a widget test, before main() gives one) the guide is off: no intro, no pointers; Cara '
      'Main still plays the intro', (tester) async {
    final b = await boot(tester);
    await mainBaru(tester, b, null);
    await frames(tester, 40);
    expect((b.welcome, b.coachCard, b.coachPointer), (null, null, null));
    b.welcome = Welcome(null, discard: () {});
    await frames(tester);
    await tapOn(tester, b.welcomeButtons['Cara Main']!);
    expect(b.coachCard, (guideIntro, 0));
    await key(tester, LogicalKeyboardKey.escape);
    expect((b.coachCard, b.guideSeen), (null, null), reason: 'nothing saved');
  });

  testWidgets('the pointers: P1 at the spawn bar\'s first card that buys until a troop is bought, P2 at Mulai until a wave starts, then '
      'with an item in the bag P3 at the Tas tab, P4 at the item, P5 at its "Give to troops" then at a type that takes it; '
      'the item given, P3-P5 and K0 are seen', (tester) async {
    final b = await boot(tester);
    final g = b.state = boardGame();
    b.guideSeen = {guideIntro};
    await frames(tester, 40);
    expect(b.coachPointer, 'P1');
    final first = troopTypes.keys.firstWhere((t) => g.buyRefusal(t) == null);
    expect(b.coachPointerTarget, b.spawnCard(first), reason: 'the first card that buys (decisions-log 283)');
    expect(b.coachPointerBox.overlaps(b.coachPointerTarget), isFalse);
    final army = g.armySize;
    await tapOn(tester, b.coachPointerTarget);
    expect(g.armySize, army + 1);
    await frames(tester, 3);
    expect(b.guideSeen, contains('P1'));
    expect((b.coachPointer, b.coachPointerTarget), ('P2', b.startButton));
    await tapOn(tester, b.startButton);
    expect(g.waveActive, isTrue);
    await frames(tester);
    expect(b.guideSeen, containsAll(['P1', 'P2']));
    expect(b.coachPointer, isNull, reason: 'none during a wave');

    // The next break, with an item in the bag.
    g
      ..queue.clear()
      ..units.removeWhere((u) => u.side == Side.enemy);
    g.units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
    await frames(tester, 3);
    expect(g.waveActive, isFalse);
    g.inventory[Item.sword] = 1;
    for (var i = 0; i < 400 && g.t - g.victoryAt < victoryTime; i++) {
      await frames(tester, 1);
    }
    await frames(tester, 40);
    expect((b.coachPointer, b.coachPointerTarget), ('P3', tab(b, 'bag')));
    await tapOn(tester, tab(b, 'bag'));
    await frames(tester);
    expect(b.guideSeen, contains('P3'));
    expect((b.coachPointer, b.coachPointerTarget), ('P4', b.bagSlot(Item.sword)));
    await tapOn(tester, b.bagSlot(Item.sword));
    await frames(tester);
    expect(b.picked, Item.sword);
    expect(b.guideSeen, contains('P4'));
    // P5 at its "Give to troops" (decisions-log 202), then at a type that takes it.
    expect((b.coachPointer, b.coachPointerTarget), ('P5', b.bagAction(BagAction.giveTroops)));
    expect(b.coachPointerBox.overlaps(b.coachPointerTarget), isFalse);
    await tapOn(tester, b.coachPointerTarget);
    expect((b.bagChooser, b.coachPointer), (BagAction.giveTroops, 'P5'));
    final row = b.assignRows.firstWhere((r) => r.$2 == b.coachPointerTarget);
    expect((row.$1 is String, row.$3), (true, true), reason: 'a type that takes it');
    expect(b.coachPointerBox.overlaps(b.coachPointerTarget), isFalse);
    await tapOn(tester, row.$2);
    expect(g.countOf(row.$1 as String, Item.sword), 1);
    await frames(tester);
    expect(b.guideSeen, containsAll(['P3', 'P4', 'P5', 'K0']));
    expect(b.coachPointer, isNull);
    expect(loadSettings().seen, containsAll(['P1', 'P2', 'P3', 'P4', 'P5', 'K0']), reason: 'saved');
  });

  testWidgets('P1-P2 not done in two breaks are dropped as seen; so are P3-P5 (K0 then says it), counted from their '
      'first break with an item', (tester) async {
    final b = await boot(tester);
    final g = b.state = boardGame();
    // The cards seen but K0, so none opens at these breaks (waves 2-4 bring K2-K4: coach_cards_test.dart).
    b.guideSeen = {guideIntro, for (final r in guideRules) if (r.key != 'K0') r.key};
    await frames(tester, 40);
    expect(b.coachPointer, 'P1');
    for (var i = 0; i < 2; i++) {
      await winWave(tester, g); // started without buying: a break gone by
    }
    expect(b.guideSeen, containsAll(['P1', 'P2']));
    expect(b.coachPointer, isNull);

    g.inventory[Item.sword] = 1;
    await frames(tester, 5);
    expect(b.coachPointer, 'P3');
    await winWave(tester, g);
    expect(b.guideSeen, isNot(contains('P3')), reason: 'one break');
    await winWave(tester, g);
    expect(b.guideSeen, containsAll(['P3', 'P4', 'P5']));
    expect(b.guideSeen, isNot(contains('K0')), reason: 'K0 still to say it');
    expect(b.coachPointer, isNull);
  });
}
