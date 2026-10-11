// The Army page's header (decisions-log 256, 260, 283; docs/ui-hud.md "Army"): "Army" at the page's left edge, the
// counter at the right one. "+Room", the capacity buy that stood in the detail's foot ([Game.buyCapacity]: 2 more room, 40
// + 10 per buy so far, the zone a column wider), went from the header (decisions-log 260) to the spawn bar's still block
// (283: [Board.capacityButton]), the same button; the foot keeps only "Replace fallen". Greyed (short of gold, at the
// most: the board's 36, at every screen size) a tap says why and nothing moves. 256's separate +1-room ladder (town.json `armyCapUp`, the save's `capBought`) is gone: the
// rooms an old save bought come back as capacity. One TdGame per widget test.
//
// Never let a wave be won or the game end here (the Board then saves): a wave begun runs a few frames only.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';

const desk = Size(1266, 713), phone = Size(915, 412);

/// Boots one TdGame in a [size] window, past the welcome screen, with the game's font and the minimap folded.
Future<Board> boot(WidgetTester tester, [Size size = desk]) async {
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

/// What [g]'s listeners hear from now on of the telemetry's own events (as test/events_test.dart's).
List<TraceEvent> traces(Game g) {
  final heard = <TraceEvent>[];
  g.listeners.add((e) {
    if (e is TraceEvent) heard.add(e);
  });
  return heard;
}

void main() {
  testWidgets('the header: the title at the left edge, the counter at the right one on the title\'s line, no +Room (the spawn '
      'bar\'s since decisions-log 283); the foot holds none either (no separator since decisions-log 288)', (tester) async {
    final b = await boot(tester);
    for (final size in [desk, phone]) {
      tester.view.physicalSize = size;
      final g = b.state = fullPriests();
      await frames(tester, 40); // the book floats in between waves
      final (left, right) = b.bookPages;
      final (title, room, count) = (b.armyTitle, b.capacityButton, b.armyCount);
      expect([title, room, count], everyElement(isNot(Rect.zero)), reason: '$size');
      expect(title.left, greaterThan(left.left), reason: '$size: at the left edge, some padding in');
      expect(title.left, lessThan(left.left + 20), reason: '$size: the left edge (decisions-log 256)');
      expect(title.right, lessThan(count.left), reason: '$size: the title clear of the counter');
      expect(count.right, lessThanOrEqualTo(left.right + 0.5), reason: '$size: the counter at the right edge');
      expect(count.right, greaterThan(left.right - 10), reason: '$size: the right edge');
      expect(count.center.dy, closeTo(title.center.dy, 3), reason: '$size: on the title\'s line');
      expect(room.overlaps(b.bookArea), isFalse, reason: '$size: +Room not in the book: $room');
      expect(room.overlaps(b.spawnBarArea), isTrue, reason: '$size: the spawn bar\'s');
      final grid = b.bookRows.map((r) => r.top).reduce((a, c) => a < c ? a : c);
      expect(count.bottom, lessThan(grid), reason: '$size: over the grid');
      // The foot (decisions-log 288): no separator, and nobody to replace, so its left is bare paper; a tap there, on the
      // line where the army's row and its +Room stood, buys nothing.
      expect((b.troopDetail('separator'), b.replaceButton), (Rect.zero, Rect.zero), reason: '$size');
      final (cap, gold) = (g.capacity, g.gold);
      await tapOn(tester, Offset(right.left + 20, right.bottom - 10));
      expect((g.capacity, g.gold), (cap, gold), reason: '$size: no +Room in the foot');
      await frames(tester, 30); // past the tap's own timer
    }
  });

  testWidgets('a tap on +Room buys what the foot\'s did: its price, 2 more room, the zone a column wider, telemetry\'s '
      'bought capacity; its tooltip says so', (tester) async {
    final b = await boot(tester);
    final g = b.state = Game().boardRules()..gold = 1000; // room for 6
    await frames(tester, 40);
    final heard = traces(g), cols = g.zoneCols;
    expect((g.capacity, g.capacityCost, g.canBuyCapacity, g.whyNotCapacity), (capacityStart, capacityPrice, true, null));
    await tapOn(tester, b.capacityButton.center);
    expect((g.capacity, g.gold, g.zoneCols), (capacityStart + capacityStep, 1000 - capacityPrice, cols + 1));
    expect(heard.map((e) => e.toJson()..remove('t')), [
      {'v': eventVersion, 'kind': 'bought', 'wave': 0, 'type': null, 'cost': capacityPrice},
    ], reason: 'the foot\'s Bought: telemetry counts it as bought.capacity');
    expect(b.message, isNull, reason: 'a buy says nothing');
    await frames(tester, 30);
    await tapOn(tester, b.capacityButton.center);
    expect((g.capacity, g.gold), (capacityStart + 2 * capacityStep, 1000 - 2 * capacityPrice - capacityPriceRise),
        reason: 'the next one 10 dearer');
    // Hover: what it does and costs (decisions-log 292), the room now and after, the zone's column.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(b.capacityButton.center);
    await frames(tester, 30);
    final cost = g.capacityCost;
    expect(b.tooltipShown?.$1, Words.room);
    expect(b.tooltipShown!.$2, [
      '${Words.room}: ${Words.moreRoom} ($cost gold).',
      'Room ${g.capacity} now, ${g.capacity + capacityStep} after.',
      if (g.zoneCols < g.maxZoneCols) 'The deploy zone gets 1 column wider.',
    ]);
    await mouse.moveTo(Offset.zero);
    await frames(tester);
    await mouse.removePointer();
    await frames(tester, 30);
  });

  testWidgets('greyed: short of gold or at the most a tap says why and nothing moves', (tester) async {
    final b = await boot(tester);
    for (final size in [desk, phone]) {
      tester.view.physicalSize = size;
      final g = b.state = fullPriests()..gold = 10;
      await frames(tester, 40);
      // Too poor: the next buy's price (decisions-log 292: 40 + 10 for each of the 3 bought).
      final poor = '${Words.notEnoughGold} (need ${capacityPrice + 3 * capacityPriceRise}).';
      expect((g.canBuyCapacity, g.whyNotCapacity), (false, poor), reason: '$size');
      await tapOn(tester, b.capacityButton.center);
      expect((g.capacity, g.gold, b.message), (12, 10, poor), reason: '$size: refused, says why');
      await frames(tester, 140); // the message goes
      g
        ..gold = 5000
        ..capacity = armyMaxBoard; // the board's most: 36
      await frames(tester, 3);
      final most = '${Words.roomAtMost} ($armyMaxBoard).';
      expect((g.capacityMaxed, g.canBuyCapacity, most), (true, false, 'Army room is at its most (36).'), reason: '$size');
      expect(g.roomTip.$2, ['${Words.room}: ${Words.moreRoom}.', most], reason: '$size');
      await tapOn(tester, b.capacityButton.center);
      expect((g.capacity, g.gold, b.message), (armyMaxBoard, 5000, most), reason: '$size');
      await frames(tester, 140);
    }
  });

  testWidgets('an army over its cap goes red; a +Room takes it in', (tester) async {
    final b = await boot(tester);
    final g = b.state = Game().boardRules()
      ..gold = 100000 // the soldiers' own prices, not this test's subject
      ..capacity = 7
      // the limits' plaque ("Army cap 6. Each troop over it: ...") draws over the header and eats the tap
      ..notes.addAll(const {'army', 'over', 'caps'});
    for (var i = 0; i < 6; i++) {
      expect(g.autoPlace('soldier'), isTrue, reason: '$i'); // and the game's starter soldier makes 7 alive
    }
    for (final u in g.troops) {
      u
        ..pos = u.post
        ..arriving = false;
    }
    g.capacity = 6; // as an old save's army over its cap
    await frames(tester, 40);
    expect((g.armySize, g.armyCap), (7, 6), reason: 'red: 7 alive over 6');
    await tapOn(tester, b.capacityButton.center);
    expect((g.capacity, g.armyCap), (8, 8), reason: 'red clears: 7 alive in room for 8');
    await frames(tester, 140); // past the tap's own timer
  });

  test('roomTip\'s zone line comes while a buy still widens the zone, and the gold line while short', () {
    final g = Game()..gold = 100000;
    while (!g.capacityMaxed) {
      final (title, lines) = g.roomTip;
      final cols = g.zoneCols;
      expect(title, Words.room);
      expect(g.buyCapacity(), isTrue, reason: '${g.capacity}');
      expect(lines.contains('The deploy zone gets 1 column wider.'), g.zoneCols > cols, reason: '${g.capacity}');
    }
    expect((g.whyNotCapacity, g.buyCapacity()), ('${Words.roomAtMost} (${g.capacity}).', false));
    expect(g.capacity, lessThanOrEqualTo(g.maxCapacity));
    final poor = Game()..gold = 1;
    expect(poor.roomTip.$2.last, '${Words.notEnoughGold} (need $capacityPrice).');
    // A save's army room over the most (one from before the cap: 48) says the room it holds, the most.
    expect((Game().boardRules()..capacity = 48).whyNotCapacity, '${Words.roomAtMost} ($armyMaxBoard).');
    expect((Game()..lives = 0).whyNotCapacity, isNull, reason: 'the game over: nothing to say');
  });

  test('256\'s bought rooms (a save\'s capBought) come back as capacity, up to the board\'s most, never lower; never '
      'written again', () {
    Map<String, dynamic> save(int capacity, int? bought) {
      final g = Game().boardRules()
        ..gold = 900
        ..capacity = capacity;
      final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
      expect(j.containsKey('capBought'), isFalse, reason: 'never written');
      return bought == null ? j : (j..['capBought'] = bought);
    }

    // The owner's save of 2026-10-07: capacity 30 and 6 rooms bought, the counter's 36.
    for (final (capacity, bought, after) in [(30, 6, 36), (12, 6, 18), (10, 3, 13), (34, 6, armyMaxBoard), (40, 2, 40), (8, 0, 8)]) {
      final back = Game.fromJson(save(capacity, bought)).boardRules();
      expect((back.capacity, back.armyCap, back.gold), (after, min(after, armyMaxBoard), 900), reason: '$capacity + $bought');
      expect(back.toJson().containsKey('capBought'), isFalse, reason: '$capacity + $bought');
    }
    final j = save(10, null), zero = jsonDecode(jsonEncode(j)) as Map<String, dynamic>..['capBought'] = 0;
    final (plain, none) = (Game.fromJson(j).boardRules(), Game.fromJson(zero).boardRules());
    expect(jsonEncode(none.toJson()), jsonEncode(plain.toJson()), reason: 'none bought: as if the key weren\'t there');
  });

  test('town.json has no armyCapUp; a file that still has one loads the rest as before', () {
    expect(File('assets/config/town.json').readAsStringSync(), isNot(contains('armyCapUp')));
    expect(const TownRules().toJson().containsKey('armyCapUp'), isFalse);
    final old = TownRules.fromJson({'version': TownRules.version, 'armyCapUp': [50, 80]});
    expect(jsonEncode(old.toJson()), jsonEncode(TownRules.fromJson({'version': TownRules.version}).toJson()));
  });
}
