// The book's padding (decisions-log 198; docs/ui-hud.md "Layouts"): each page writes inside its printed line less
// bookPadY book px at the top and the bottom and bookPadX at the sides (the owner's "padding 10px dan 5px", the CSS
// shorthand), at 1266x713 and 915x412; and what every field tab draws (Army, Bag, Settings; the Toko's Shop tab went
// in decisions-log 296) stays inside that writing. One TdGame per widget test.
//
// Never let a wave be won or the game end here: the board saves, into the queue's temp HOME (flutter_test_config.dart).
import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';

const desk = Size(1266, 713), wide = Size(915, 412);

/// The book's pixel scale at each test window (ui-hud.md "Layouts": 2 on the desk, 1 at 915x412).
const sizes = [(desk, 2.0), (wide, 1.0)];

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

/// Rich, the Shop open, a soldier and a knight beside the free priest at their posts, a sword in the bag.
Game shopGame() {
  final g = Game().boardRules()
    ..gold = 50000
    ..wave = storeFrom + 1;
  for (final type in ['soldier', 'knight']) {
    expect(g.autoPlace(type), isTrue);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.inventory[Item.sword] = 3;
  return g;
}

/// Whether [r] lies inside [page] (half a pixel of rounding allowed).
bool inside(Rect r, Rect page) =>
    r.left >= page.left - 0.5 && r.top >= page.top - 0.5 && r.right <= page.right + 0.5 && r.bottom <= page.bottom + 0.5;

void main() {
  test('the padding is the owner\'s: 10 book px at the top and the bottom, 5 at the sides', () {
    expect((bookPadY, bookPadX), (10.0, 5.0));
    expect(bookWriting(const Rect.fromLTRB(0, 0, 100, 200), 2), const Rect.fromLTRB(10, 20, 90, 180));
  });

  for (final (size, ps) in sizes) {
    final at = '${size.width.round()}x${size.height.round()}';
    testWidgets('at $at each page writes inside its printed line less the padding, and every tab stays inside it',
        (tester) async {
      final b = await boot(tester, size);
      b.state = shopGame();
      await frames(tester, 50);
      var (left, right) = b.bookPages;
      var book = b.bookArea;
      // The outer sides: the printed line at sprite x 16 (223 from the right: 17 px of cover and line), y 10 and 127
      // (144 - 17); the spine's gutter: the left page's line at 112, the right one's at 127 (sprite 96 to 143 fixed).
      expect(left.left - book.left, closeTo((17 + bookPadX) * ps, 0.01), reason: at);
      expect(book.right - right.right, closeTo((17 + bookPadX) * ps, 0.01), reason: at);
      expect(left.top - book.top, closeTo((11 + bookPadY) * ps, 0.01), reason: at);
      expect(right.top, left.top, reason: at);
      expect(book.bottom - left.bottom, closeTo((17 + bookPadY) * ps, 0.01), reason: at);
      expect(right.left - left.right, closeTo((143 - 96 - 31 + 2 * bookPadX) * ps, 0.01), reason: at);
      expect(left.width, closeTo(right.width, 0.5), reason: at);

      // Army: the grid's cells (and its pager) on the left; the detail's sections and buttons, the foot's Release and its
      // press area on the right (decisions-log 218 and 288; Buy and +Room went to the spawn bar, 283).
      final (back, on) = b.armyPager;
      final army = [for (final t in troopTypes.keys) b.troopRow(t), back, on].where((r) => r != Rect.zero).toList();
      expect(army.length, greaterThanOrEqualTo(troopTypes.length ~/ b.armyPageCount), reason: at);
      for (final r in army) {
        expect(inside(r, left), isTrue, reason: '$at Army: $r in $left');
      }
      for (final key in ['heading', 'stats', 'next', 'pusaka', 'heroes', 'relics', 'upgrade', 'change', 'bag', 'recall:0', 'release', 'releaseTap']) {
        final r = b.troopDetail(key);
        if (r != Rect.zero) expect(inside(r, right), isTrue, reason: '$at Army detail $key: $r in $right');
      }

      Future<void> open(String tab) async {
        await tester.tapAt(b.bookTabs.firstWhere((t) => t.$1 == tab).$2.center);
        await frames(tester, 3);
        (left, right) = b.bookPages;
        book = b.bookArea;
      }

      // Bag: the chips and the board on the left; the picked sword's page on the right.
      await open('bag');
      await tester.tapAt(b.bagCells.firstWhere((c) => c.$1 == Item.sword).$2.center);
      await frames(tester, 3);
      (left, right) = b.bookPages;
      final bag = [...b.bagSlots, for (final cat in BagCategory.values) b.bagChip(cat)].where((r) => r != Rect.zero).toList();
      expect(bag, isNotEmpty, reason: at);
      for (final r in bag) {
        expect(inside(r, left), isTrue, reason: '$at Bag: $r in $left');
      }
      expect((inside(b.bagDetail('page'), right), inside(b.assignList, right)), (true, true), reason: '$at Bag detail in $right');

      // Settings: the volumes and How to Play on the left, the toggles and Main Menu on the right.
      await open('settings');
      for (final r in [...b.volumeRows, b.howToButton]) {
        expect(inside(r, left), isTrue, reason: '$at Settings: $r in $left');
      }
      for (final r in [b.sendButton, b.licenceButton, b.foeCutButton, b.heroCutButton, b.menuButton]) {
        expect(inside(r, right), isTrue, reason: '$at Settings: $r in $right');
      }
      await open('troops');
      await frames(tester, 10);
    });
  }
}
