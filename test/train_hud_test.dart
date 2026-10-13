import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'real_rules.dart';

// Train on the Army detail (decisions-log 334, troop_detail.dart's Train section): a type whose items are all +5 shows a
// row per attribute with its level, gain, material and price tag inside the page at the owner's 1600x947 and at
// 915x412; a tap buys (the message, the level), a "Max" tap says why; the Range row is gone where reach can't rise (the
// archer); a type at Awaken 3 short of +5 shows how far. One TdGame (a second in one file breaks the shared image cache,
// docs/testing.md). The rules: train_test.dart.

/// Advances the game [n] frames.
Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Puts [type]'s three grade sets on it in [g], every one at +5.
void fillSets(Game g, String type) {
  final sets = g.trainItems(type);
  g.upgrades[type] = [for (final MapEntry(key: i, value: n) in sets.entries) ...List.filled(n, i)];
  g.upgradePlus[type] = {for (final MapEntry(key: i, value: n) in sets.entries) i: List.filled(n, 5)};
}

/// After wave 90, rich: the knight and the archer with every item +5 (Train open), the priest at Awaken 3 at +0, one of
/// each fielded, plenty of every material.
Game trainer() {
  final g = Game()..wave = 90;
  fillSets(g, 'knight');
  fillSets(g, 'archer');
  g.upgrades['priest'] = awakenItems('priest', 3);
  for (final m in trainParts.values) {
    g.materials[m] = 100;
  }
  g.gold = 100000000;
  expect(g.place('knight', 0, 1), isTrue);
  expect(g.place('archer', 0, 3), isTrue);
  return g;
}

void main() {
  testWidgets('the Train rows fit the page, a tap buys, Max says why, no Range row for the archer, the closed line', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 947)
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
    final b = game.board
      ..welcome = null
      ..miniMapOpen = false;

    /// Scrolls the detail's body until [key]'s tag shows whole in it; its rect then.
    Future<Rect> show(String key) async {
      b.troopDetailScroll = 0;
      await frames(tester, 2);
      for (var i = 0; i < 200; i++) {
        final r = b.troopDetail(key), body = b.troopDetailBody;
        if (r != Rect.zero && r.top >= body.top - 0.5 && r.bottom <= body.bottom + 0.5) return r;
        if (b.troopDetailScroll >= b.troopDetailContent - body.height) break;
        b.troopDetailScroll = min(b.troopDetailScroll + 6, b.troopDetailContent - body.height);
        await frames(tester, 1);
      }
      return Rect.zero;
    }

    Future<void> pick(String type) async {
      if (b.messageBox != Rect.zero) {
        await tester.tapAt(b.messageBox.center); // out of the way
        await frames(tester, 3);
      }
      for (var i = 0; i < 4 && b.troopRow(type) == Rect.zero; i++) {
        final (back, on) = b.armyPager;
        await tester.tapAt((on != Rect.zero ? on : back).center);
        await frames(tester, 3);
      }
      await tester.tapAt(b.troopRow(type).center);
      await frames(tester, 3);
    }

    Future<void> check(Size screen) async {
      final g = b.state = trainer();
      await frames(tester, 40);
      if (b.messageBox != Rect.zero) {
        await tester.tapAt(b.messageBox.center);
        await frames(tester, 3);
      }
      if (b.troopRow('knight') == Rect.zero && b.bookTabs.any((t) => t.$1 == 'troops')) {
        await tester.tapAt(b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2.center);
        await frames(tester, 3);
      }
      await pick('knight');
      // Every row, its tag inside the page's body, its words as the rules say.
      for (final stat in TrainStat.values) {
        final r = await show('train:${stat.name}');
        expect(r, isNot(Rect.zero), reason: '$screen ${stat.name}');
        final body = b.troopDetailBody;
        expect((r.left >= body.left, r.right <= body.right + 0.5), (true, true), reason: '$screen ${stat.name}: $r in $body');
        final capped = g.trainCapped('knight', stat);
        expect(b.troopDetailWords('train:${stat.name}'), [capped ? 'Max' : shortPrice(g.trainCostOf('knight', stat)!.gold)], reason: '$screen ${stat.name}');
      }
      expect(b.troopDetailWords('train'), containsAll(['Train: every item +5', 'HP', 'Lv 0', '+5%', 'Range', '+10%']), reason: '$screen');

      // A tap on HP's price buys it.
      final hp = await show('train:hp'), gold = g.gold;
      await tester.tapAt(Offset(hp.right - 4, hp.center.dy));
      await frames(tester, 3);
      expect((g.train['knight']?[TrainStat.hp], g.gold, b.message), (1, gold - 20000, 'Knight: Train HP Lv 1!'), reason: '$screen');
      expect(b.troopDetailWords('train'), contains('Lv 1'), reason: '$screen');
      // A "Max" says why and buys nothing.
      final rate = await show('train:rate');
      await tester.tapAt(Offset(rate.right - 4, rate.center.dy));
      await frames(tester, 3);
      expect((g.train['knight']?[TrainStat.rate], b.message), (null, 'Max: attack floor'), reason: '$screen');

      // The archer: open, its reach past one screen, so no Range row; Speed sold.
      await pick('archer');
      expect(await show('train:speed'), isNot(Rect.zero), reason: '$screen');
      expect(await show('train:range'), Rect.zero, reason: '$screen: no Range row');
      expect(b.troopDetailWords('train'), isNot(contains('Range')), reason: '$screen');

      // The priest at Awaken 3, nothing +5: how far.
      await pick('priest');
      for (var i = 0; i < 200 && !b.troopDetailWords('train').any((w) => w.startsWith('Train')); i++) {
        b.troopDetailScroll += 6;
        await frames(tester, 1);
      }
      expect(b.troopDetailWords('train'), anyOf(contains('Train: needs every item +5 (0/36)'), contains('Train: +5 all (0/36)')), reason: '$screen');
      b.state = Game(); // leave nothing a later step could save
      await frames(tester, 5);
    }

    await check(const Size(1600, 947));
    tester.view.physicalSize = const Size(915, 412);
    await check(const Size(915, 412));
    await frames(tester, 10); // the taps' timers run out
  });
}
