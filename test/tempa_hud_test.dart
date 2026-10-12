import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'real_rules.dart';
import 'hud_font.dart';

// Tempa on the board (decisions-log 163, lib/ascend_page.dart): the "+n" after a Bangkit 5 type's stars on the Army
// detail's heading and the Tas rows, and the Army tab's dot (its detail buys the next level, decisions-log 230; the
// Toko's Bangkit rows went in decisions-log 296), fitting the owner's window and 1164x777 in the game's font. One TdGame
// (its own file: a second TdGame in one file breaks the shared image cache, docs/testing.md). The rules: tempa_test.dart.

/// Advances the game [n] frames.
Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// After wave 87, rich: the knight at Bangkit 5 and Tempa +3 with one fielded, the archer at Bangkit 2 with one too: its
/// grade sets ([awakenItems]) get the knight to Bangkit 3 at once.
Game forger() {
  final g = Game()..wave = 87;
  g.upgrades['knight'] = awakenItems('knight', 3);
  g.ascended['knight'] = maxAscend;
  g.tempa['knight'] = 3;
  g.upgrades['archer'] = awakenItems('archer', 2);
  g.inventory[Item.sword] = 1; // one to pick on the Tas page, whose rows then show the types
  g.gold = 1000000;
  expect(g.place('knight', 0, 1), isTrue);
  expect(g.place('archer', 0, 3), isTrue);
  return g..gold = 2000000;
}

void main() {
  testWidgets('a Bangkit 5 type shows "+n" after its stars; the Army tab\'s dot', (tester) async {
    tester.view
      ..physicalSize = const Size(1266, 713) // the owner's window
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

    /// The "+n" drawn inside [row] this frame.
    (Rect, String)? markIn(Rect row) => b.tempaMarks.where((m) => row.contains(m.$1.center)).firstOrNull;

    /// It reads, and stays inside [row], left of [before].
    void fits((Rect, String)? m, Rect row, double before, String text, String where) {
      expect(m, isNotNull, reason: where);
      final (r, label) = m!;
      expect(label, text, reason: where);
      expect(r.height, greaterThanOrEqualTo(7), reason: '$where: big enough to read');
      expect((r.left >= row.left, r.right <= before, r.top >= row.top, r.bottom <= row.bottom), (true, true, true, true), reason: '$where: $r in $row');
    }

    Future<void> check(Size screen) async {
      var g = b.state = forger();
      await frames(tester, 40); // the book floats in between waves
      if (b.troopRow('knight') == Rect.zero) {
        // Still on the page the last check left it at: back to Pasukan.
        await tester.tapAt(b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2.center);
        await frames(tester, 3);
      }

      // The Army tab's dot: 2M is over 3 purses (528k) and the knight can buy Tempa +4 (its detail sells it).
      final dot = b.storeAt('tokoDot'), army = b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2;
      expect(dot, isNot(Rect.zero), reason: '$screen');
      expect(army.inflate(8).contains(dot.center), isTrue, reason: '$screen: on the Army tab');
      expect(b.bookTabs.map((t) => t.$1), isNot(contains('store')), reason: '$screen: no Toko on the field');
      expect(b.storeAt('bagDot'), Rect.zero, reason: 'nothing in the bag awakens anyone');

      // Army: "+3" after the knight's stars in its detail's header once its cell is picked (decisions-log 218: the
      // stars are the header's, not the cell's); none for the archer.
      expect(b.troopRow('knight'), isNot(Rect.zero));
      expect(markIn(b.troopRow('knight')), isNull, reason: '$screen: not on the cell');
      await tester.tapAt(b.troopRow('knight').center);
      await frames(tester);
      final head = b.troopDetail('heading');
      fits(markIn(head), head, head.right, '+3', '$screen Army');
      await tester.tapAt(b.troopRow('archer').center);
      await frames(tester);
      expect(markIn(b.troopDetail('heading')), isNull, reason: screen.toString());

      // Short of 3 purses: no dot.
      g.gold = nudgePurses * purse(88) - 1;
      await frames(tester);
      expect(b.storeAt('tokoDot'), Rect.zero);

      // The Tas page's rows show it too, once the sword is picked and its Give to troops open.
      await tester.tapAt(b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
      await frames(tester, 3);
      await tester.tapAt(b.bagSlot(Item.sword).center);
      await frames(tester, 3);
      await tester.tapAt(b.bagAction(BagAction.giveTroops).center); // its type rows (decisions-log 202)
      await frames(tester, 3);
      expect(b.tempaMarks.map((m) => m.$2), contains('+3'), reason: '$screen Tas');
      g = b.state = Game(); // leave nothing that a later step could save
      await frames(tester, 5);
    }

    await check(const Size(1266, 713));
    tester.view.physicalSize = const Size(1164, 777);
    await check(const Size(1164, 777));
    await frames(tester, 10); // the tap's timers run out
  });
}
