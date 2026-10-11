// A book page's part that scrolls where it doesn't fit (decisions-log 283: the landscape book shorter; lib/page_scroll.dart;
// ui-hud.md "The Smithy" and "The Tavern"): the tests that check a line on the Smithy's facing page or the Tavern's pages
// scroll it into view first. Not a test file (no `_test.dart`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/main.dart';

/// Scrolls [part] ([Board.pageScrollView]: 'smithy', 'tavernList', 'tavernFacing') from its top, 16 px a step, until
/// what [at] gives shows down to its bottom in the view (or the part is at its end), and returns it there (Rect.zero:
/// never drawn). What takes a tap or a hover is cut to the view, so a rect it returns can be tapped.
Future<Rect> scrolledTo(WidgetTester tester, Board b, String part, Rect Function() at) async {
  Future<void> frame() async {
    for (var i = 0; i < 2; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  b.setPageScroll(part, 0);
  await frame();
  for (var i = 0; i < 200; i++) {
    final r = at(), view = b.pageScrollView(part);
    if (r != Rect.zero && r.bottom < view.bottom - 1) return r;
    final was = b.pageScroll(part);
    b.setPageScroll(part, was + 16);
    await frame();
    if (b.pageScroll(part) == was) break; // at its end
  }
  return at();
}

/// Whether [part] is taller than its room this frame (it scrolls).
bool scrolls(Board b, String part) => b.pageScrollContent(part) > b.pageScrollView(part).height + 1e-9;

/// What [at] gives scrolled into [part]'s view ([scrolledTo]), and where it lies down what the part holds: its top and
/// bottom from the part's top at no scroll.
Future<({Rect at, double top, double bottom})> scrolledDown(WidgetTester tester, Board b, String part, Rect Function() at) async {
  final r = await scrolledTo(tester, b, part, at), y = b.pageScroll(part) - b.pageScrollView(part).top;
  return (at: r, top: r.top + y, bottom: r.bottom + y);
}
