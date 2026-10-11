// The book's bookmarks are its page tabs only (decisions-log 285; ui-hud.md "Bookmarks"): the gold and wave ribbons
// (ui_book_marks.png's flags, out from under the right cover; on a phone held upright two pills on its top edge) are
// gone, on the field's book and a Town's, on every page; the top band's gold panel and wave meter still show both. The
// board is rendered into a recording canvas and every piece it takes from ui_book_marks.png is checked: the tabs lie
// at x < 60 of the sheet, the flags from x 162. Booted TdGames, seeded.
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'town_hud_test.dart' show boot, frames, townGame;
import 'town_scene_test.dart' show intoTown, settle;

const sizes = [Size(1266, 713), Size(915, 412)];

/// The pieces of ui_book_marks.png the board draws this frame (their rects on the sheet), rendered into a recording
/// canvas.
List<Rect> marksDrawn(Board b) {
  final marks = b.game.images.fromCache('ui_book_marks.png'), canvas = TestRecordingCanvas();
  b.render(canvas);
  return [
    for (final call in canvas.invocations.map((i) => i.invocation))
      if (call.memberName == #drawImageRect && (call.positionalArguments[0] as ui.Image).isCloneOf(marks))
        call.positionalArguments[1] as Rect,
  ];
}

/// On each of the book's pages: the tabs drawn from the sheet, no ribbon flag; the gold panel and the wave meter shown.
/// Ends on the first page.
Future<void> noRibbons(WidgetTester tester, Board b, String tag) async {
  final pages = [for (final (page, _) in b.bookTabs) page];
  expect(pages, isNotEmpty, reason: '$tag: the book is open');
  for (final page in pages) {
    if (b.bookPage != page) {
      await tester.tapAt(b.bookTabs.firstWhere((t) => t.$1 == page).$2.center);
      await frames(tester, 3);
    }
    expect(b.bookPage, page, reason: '$tag: on $page');
    final drawn = marksDrawn(b);
    expect(drawn, isNotEmpty, reason: '$tag $page: the page tabs come from ui_book_marks.png');
    expect([for (final r in drawn) if (r.right > 60) r], isEmpty, reason: '$tag $page: no gold or wave ribbon');
    expect(b.heartsGoldPanel.isEmpty, isFalse, reason: '$tag $page: the gold on the top band');
    expect(b.waveMeter.isEmpty, isFalse, reason: '$tag $page: the wave meter');
  }
  // Back on the first page (the field's Army, a Town's Smithy), as the next step expects it.
  await tester.tapAt(b.bookTabs.firstWhere((t) => t.$1 == pages.first).$2.center);
  await frames(tester, 3);
  expect(b.bookPage, pages.first, reason: tag);
}

void main() {
  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('$tag: no gold or wave ribbon on the book, on the field (Towns off and on) and in a Town, on every page',
        (tester) async {
      final b = (await boot(tester, size))..guideSeen = null; // no guide card: its gold picture draws the sheet's flag
      // The field's book with the Towns off at wave 20 (tests only): Army, Bag, Settings (the Toko's Shop tab went in
      // decisions-log 296).
      b.state = Game(Random(1), Random(2)).boardRules()
        ..towns = false
        ..armyMax = null
        ..wave = 20
        ..gold = 4130;
      await frames(tester, 60);
      expect(b.bookTabs.map((t) => t.$1), ['troops', 'bag', 'settings']);
      await noRibbons(tester, b, 'field $tag');
      // The field's book with the Towns on: Army, Bag, Settings.
      b.state = townGame()
        ..wave = 20
        ..gold = 4130;
      await frames(tester, 60);
      expect(b.bookTabs.map((t) => t.$1), containsAll(['troops', 'bag', 'settings']));
      await noRibbons(tester, b, 'field, Towns on, $tag');
      // A Town's book: Smithy, Tavern, Shop, Army, Bag, Settings (decisions-log 230, 268, 301).
      await intoTown(tester, b);
      await settle(tester, b);
      expect(b.townShown, isTrue);
      expect(b.bookTabs.map((t) => t.$1), containsAll(['smithy', 'store', 'troops']));
      await noRibbons(tester, b, 'Town $tag');
    });
  }
}
