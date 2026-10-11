// The Bag's grid pages where its kinds don't all fit (ui-hud.md "Tas"), and so does the Smithy's Relics or Enhance board
// above its materials (ui-hud.md "The Smithy"); on the shorter landscape book (decisions-log 283) a page holds fewer (12
// at 915x412), so the tests that look at a cell turn the grid or the board to it first. Not a test file (no
// `_test.dart`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart' show Relic;
import 'package:tower_defense/main.dart';

/// Turns the Bag's grid by its pager to the page holding [kind]'s cell (it stays where it shows already).
Future<void> bagTo(WidgetTester tester, Board b, Enum kind) async {
  Future<void> tap(Rect r) async {
    await tester.tapAt(r.center);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  for (var i = 0; i < 20 && b.bagSlot(kind) == Rect.zero && b.bagPage > 0; i++) {
    await tap(b.bagPager('back'));
  }
  for (var i = 0; i < 20 && b.bagSlot(kind) == Rect.zero && b.bagPage < b.bagPages - 1; i++) {
    await tap(b.bagPager('on'));
  }
  expect(b.bagSlot(kind), isNot(Rect.zero), reason: '$kind on a page of the grid');
}

/// The Smithy's Relics (or Enhance) board page by page from the first, its pager turned ([Board.smithyBoardPager]; it
/// pages where its cells don't all fit above the materials' two rows, decisions-log 283): each page's cells with their
/// marks, and the book and its left page that frame (the book bobs). Back on the first page after.
Future<List<({List<(Relic, Rect, BagMarks)> cells, Rect book, Rect left})>> smithyBoardPages(WidgetTester tester, Board b) async {
  Future<void> tap(Rect r) async {
    await tester.tapAt(r.center);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  for (var i = 0; i < 20 && b.smithyBoardPage > 0; i++) {
    await tap(b.smithyBoardPager('back'));
  }
  final pages = <({List<(Relic, Rect, BagMarks)> cells, Rect book, Rect left})>[];
  for (var p = 0; p < b.smithyBoardPages; p++) {
    if (p > 0) await tap(b.smithyBoardPager('on'));
    expect(b.smithyBoardPage, p, reason: 'the pager turned the board');
    pages.add((cells: [for (final (r, at) in b.smithyCells) (r, at, b.smithyMarks(r)!)], book: b.bookArea, left: b.bookPages.$1));
  }
  for (var i = 0; i < 20 && b.smithyBoardPage > 0; i++) {
    await tap(b.smithyBoardPager('back'));
  }
  return pages;
}

/// Turns the Smithy's Relics board by its pager to [relic]'s page.
Future<void> smithyBoardTo(WidgetTester tester, Board b, Relic relic) async {
  bool shown() => b.smithyCells.any((c) => c.$1 == relic);
  Future<void> tap(Rect r) async {
    await tester.tapAt(r.center);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  for (var i = 0; i < 20 && !shown() && b.smithyBoardPage > 0; i++) {
    await tap(b.smithyBoardPager('back'));
  }
  for (var i = 0; i < 20 && !shown() && b.smithyBoardPage < b.smithyBoardPages - 1; i++) {
    await tap(b.smithyBoardPager('on'));
  }
  expect(shown(), isTrue, reason: '$relic on a page of the board');
}
