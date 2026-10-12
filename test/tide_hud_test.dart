import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';

// The tide's HUD (#92 part 1, docs/ui-hud.md): the wave meter's "+35%" from the tide's first wave (an army over the
// cap's the same since Beban went, decisions-log 329), its tooltip's target, the top rows still clear of the wider
// meter, and "Ganti yang gugur" on the Pasukan page. One TdGame (its own file: a second TdGame in one file breaks the shared image cache,
// docs/testing.md). The rules: tide_test.dart.

/// Advances the game [n] frames.
Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Point<double> cellMiddle(int c, int r) => Point(c * tile + tile / 2, r * tile + tile / 2);

void main() {
  testWidgets('the meter shows the tide from its first wave and stays clear of the top rows; the fallen come back from the '
      'Pasukan page', (tester) async {
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

    // Between waves the meter shows the coming wave: none before the tide's first, "+0%" on it, "+35%" on 65.
    for (final (won, badge) in [(33, ''), (34, '+0%'), (64, '+35%')]) {
      b.state = Game()..wave = won;
      await frames(tester, 3);
      expect(b.tideBadge, badge, reason: 'wave $won won');
      expect(b.tideBadgeAt, badge.isEmpty ? Rect.zero : b.waveMeter, reason: 'wave $won won: the tooltip over the meter');
    }
    // An old save's tide counts from its own start: 72 from 52 is +22%.
    b.state = Game()
      ..wave = 71
      ..tideStart = 52;
    await frames(tester, 3);
    expect(b.tideBadge, '+22%');
    // An army over the cap meets the tide as any army (Beban, decisions-log 162, went in 329): 48 over the board's 36
    // with the tide from 66 meets wave 87's from 66 (+21%).
    final over = Game()
      ..wave = 86
      ..tideStart = 66
      ..capacity = 48
      ..notes.add('army'); // no one-time note over the field
    for (var i = 0; over.armySize < 48; i++) {
      over.units.add(Unit(Side.troop, 'soldier', troopTypes['soldier']!, cellMiddle(i ~/ rows, i % rows))..entered = true);
    }
    b.state = over.boardRules();
    await frames(tester, 3);
    expect(b.tideBadge, '+${tidePercent(87, 66)}%');

    // The meter is wider by the badge ("+999%" kept free), and still clear of the rows at the top on every screen.
    for (final size in const [Size(1266, 713), Size(915, 412)]) {
      tester.view.physicalSize = size;
      final early = b.state = Game();
      await frames(tester, 40);
      final narrow = b.waveMeter.width;
      final g = b.state = Game()..wave = 99;
      await frames(tester, 40);
      expect((b.tideBadge, b.waveMeter.width > narrow), ('+91%', true), reason: '$size');
      for (final when in ['between waves', 'in a wave']) {
        final pieces = {
          'counter': b.troopCounter,
          'hearts': b.livesBar,
          'gold': b.goldPanel,
          'x2': b.speedButton,
          'book': b.bookButton,
          'toggle': b.toggleButton,
          'Auto': b.autoButton,
          'log': b.logButton,
        }..removeWhere((_, r) => r == Rect.zero);
        for (final MapEntry(key: name, value: r) in pieces.entries) {
          expect(r.overlaps(b.waveMeter), isFalse, reason: '$size $when: the meter and $name');
        }
        expect(b.waveMeter.left, greaterThanOrEqualTo(0), reason: '$size $when');
        g.startWave();
        await frames(tester, 5);
      }
      expect(early.tideStart, tideFrom);
    }
    tester.view.physicalSize = const Size(1266, 713);

    // "Replace fallen": shown between waves while someone of the last won wave can come back, on the Army page's right
    // page at the foot's bottom-left, as wide as its words, no separator over it (decisions-log 288); a press buys them
    // back.
    final g = b.state = Game()..gold = 1000;
    await frames(tester, 40); // the book floats in between waves
    expect(b.replaceButton, Rect.zero); // nobody fell
    g.toReplace.addAll([(type: 'soldier', post: cellMiddle(1, 1)), (type: 'knight', post: cellMiddle(1, 6))]);
    await frames(tester, 3);
    final at = b.replaceButton, right = b.bookPages.$2;
    expect(at, isNot(Rect.zero));
    expect((at.left, at.bottom, at.width < right.width, b.troopDetail('separator')),
        (right.left.roundToDouble(), right.bottom.roundToDouble(), true, Rect.zero));
    expect(at.top, greaterThan(b.troopDetailBody.bottom));
    expect(b.replaceLabel, '${Words.replaceFallen} (2)  ${shortPrice(g.priceOf('soldier') + g.priceOf('knight'))}');
    await tester.tapAt(at.center);
    await frames(tester, 3);
    expect(g.toReplace, isEmpty);
    expect(g.troopCounts, {'soldier': 1, 'knight': 1, 'priest': 1});
    expect(b.replaceButton, Rect.zero); // all back
    // Greyed when nobody can come back, and a press says why.
    g
      ..toReplace.add((type: 'wizard', post: cellMiddle(2, 2)))
      ..gold = 0;
    await frames(tester, 3);
    await tester.tapAt(b.replaceButton.center);
    await frames(tester, 2);
    expect((g.toReplace.length, b.message), (1, Words.notEnoughGold));
    // Partly: the message says how many of how many came back, and why not the rest.
    g
      ..toReplace.add((type: 'soldier', post: cellMiddle(2, 3)))
      ..gold = g.priceOf('soldier');
    await frames(tester, 3);
    await tester.tapAt(b.replaceButton.center);
    await frames(tester, 2);
    expect((g.toReplace.length, b.message), (1, 'Replaced 1 of 2 (not enough gold)'));
    // During a wave it is gone.
    g.startWave();
    await frames(tester, 3);
    expect(b.replaceButton, Rect.zero);
  });
}
