// The open book's shadow in pixel style (decisions-log 275; ui-hud.md "Layouts"; lib/main.dart Board._bookShadow): on
// the field, at 1266x713 (the book at 2 screen px a book px) and 915x412 (at 1), a stepped ellipse in the book's own
// pixels: each row one book px tall on whole screen px, its ends on the book's grid, the widest in the middle and the
// same width a row from either end, one tone with no anti-alias; it stays on the ground while the book bobs, smaller
// while the book is up; and its alpha follows the book's slide in. In a Town none (decisions-log 304, the owner: "book di
// town di remove backgroundnya"), at 1600x947, 1266x713, 1164x777 and 915x412: not once the Town's scene shows, nor over
// a whole bob, nor while the book slides back in; the field's is back with the field. Booted TdGames, seeded.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'town_hud_test.dart' show boot, frames;
import 'town_scene_test.dart' show bare, intoTown, settle;

/// The test windows and the book's pixel scale there (ui-hud.md "Layouts").
const sizes = [(Size(1266, 713), 2.0), (Size(915, 412), 1.0)];

/// The Town's windows (decisions-log 304: no shadow at any of them): the owner's window, the desk's, the tablet's and the
/// phone's.
const townSizes = [Size(1600, 947), Size(1266, 713), Size(1164, 777), Size(915, 412)];

/// The book's pixel scale at a Town's [size] (ui-hud.md "Layouts": 974 px wide at 1600x947, 711 at 1164x777).
double bookPs(Size size) => switch (size.width) { >= 1500 => 3.0, >= 1100 => 2.0, _ => 1.0 };

/// A board game between waves with the Towns off, seeded: the field's book.
Game fieldGame() => Game(Random(1), Random(2)).boardRules()
  ..towns = false
  ..armyMax = null
  ..gold = 5000;

/// The shadow's widest row's width now, screen px.
double widest(Board b) => b.bookShadow.rows.map((r) => r.width).reduce(max);

/// Checks the shadow as drawn now with the book at [ps] screen px a book px: 18 screen px of rows (to whole book px),
/// each [ps] tall on whole screen px, its ends on the book's grid, a stepped ellipse (the widest in the middle, the same
/// a row from either end, never wider toward an end), 0.75-0.85 of the book's width at its widest; no anti-alias.
void pixelShadow(Board b, double ps, String tag) {
  final rows = b.bookShadow.rows, book = b.bookArea;
  expect(rows, hasLength(max(2, (18 / ps).round())), reason: '$tag: 18 screen px of book px rows');
  expect(b.bookShadow.paint.isAntiAlias, isFalse, reason: '$tag: hard edges');
  for (var j = 0; j < rows.length; j++) {
    final r = rows[j];
    for (final edge in [r.left, r.top, r.right, r.bottom]) {
      expect(edge, edge.roundToDouble(), reason: '$tag row $j: on whole screen px');
    }
    expect(r.height, ps, reason: '$tag row $j: one book px tall');
    expect(r.width % ps, 0, reason: '$tag row $j: whole book px wide');
    final n = (r.left - book.left) / ps;
    expect((r.left - book.left - n.round() * ps).abs(), lessThanOrEqualTo(0.5), reason: "$tag row $j: on the book's grid");
    if (j > 0) expect(r.top, rows[j - 1].bottom, reason: '$tag row $j: under the last');
    final mirror = rows[rows.length - 1 - j];
    expect((r.left, r.right), (mirror.left, mirror.right), reason: '$tag row $j: as wide as its mirror row');
    if (j > 0 && j <= rows.length ~/ 2) {
      expect(r.width, greaterThanOrEqualTo(rows[j - 1].width), reason: '$tag row $j: no narrower toward the middle');
    }
  }
  expect(rows.first.width, lessThan(widest(b)), reason: '$tag: stepped');
  expect(widest(b) / book.width, inInclusiveRange(0.75 - 2 * ps / book.width, 0.85 + 2 * ps / book.width), reason: tag);
  expect((rows.first.center.dx - book.center.dx).abs(), lessThanOrEqualTo(ps), reason: '$tag: under the book');
  expect(rows.last.bottom, greaterThan(book.bottom), reason: '$tag: on the ground below the book');
}

/// Over a whole bob (4 s), the shadow keeps its rows on the ground and is never wider while the book stands higher;
/// it changes size there.
Future<void> bobs(WidgetTester tester, Board b, String tag) async {
  final seen = <(double, double)>[]; // (the book's top, the shadow's widest row)
  final ground = b.bookShadow.rows.first.top;
  for (var i = 0; i < 250; i++) {
    await frames(tester, 1);
    expect(b.bookShadow.rows.first.top, ground, reason: '$tag: the shadow stays on the ground');
    seen.add((b.bookArea.top, widest(b)));
  }
  for (final (top, w) in seen) {
    for (final (top2, w2) in seen) {
      if (top < top2 - 0.01) expect(w, lessThanOrEqualTo(w2), reason: '$tag: higher (top $top) never wider than at $top2');
    }
  }
  final ws = seen.map((s) => s.$2);
  expect(ws.reduce(max), greaterThan(ws.reduce(min)), reason: '$tag: it changes with the bob');
}

/// The book slides in from the right: each frame the shadow's alpha is 0.25 of the slide's ease, read off how far the
/// book still is from where it rests ([rest]: its left there).
Future<void> fadesIn(WidgetTester tester, Board b, Size size, double rest, String tag) async {
  var last = 0.0, slid = 0;
  for (var i = 0; i < 40; i++) {
    await frames(tester, 1);
    if (b.bookArea.isEmpty) continue;
    // It slides in from the right (0.6 of the width).
    final e = 1 - (b.bookArea.left - rest) / (0.6 * size.width);
    final a = b.bookShadow.paint.color.a;
    expect(a, closeTo(0.25 * e, 0.005), reason: '$tag frame $i: 0.25 of the ease $e');
    expect(a, greaterThanOrEqualTo(last), reason: '$tag frame $i: never fainter as it comes in');
    if (e < 0.99) slid++;
    last = a;
  }
  expect(slid, greaterThan(2), reason: '$tag: seen on its way in');
  expect(last, closeTo(0.25, 0.001), reason: '$tag: 0.25 once in');
}

void main() {
  for (final (size, ps) in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';

    testWidgets('the field at $tag: the book\'s shadow is pixel art on its grid, stays on the ground and is smaller '
        'while the book bobs up; its alpha follows the slide in', (tester) async {
      final b = await boot(tester, size);
      b.state = fieldGame();
      await frames(tester, 60);
      expect(b.bookArea, isNot(Rect.zero));
      expect(b.bookShadow.paint.color.a, closeTo(0.25, 0.001));
      pixelShadow(b, ps, 'field $tag');
      await bobs(tester, b, 'field $tag');
      // A wave shuts the book (no shadow), its button opens it mid-fight: the shadow fades in with it.
      final rest = b.bookArea.left;
      b.state.startWave();
      for (var i = 0; i < 120 && !b.bookArea.isEmpty; i++) {
        await frames(tester, 1);
      }
      expect(b.bookArea, Rect.zero);
      expect(b.bookShadow.rows, isEmpty, reason: 'no shadow under a shut book');
      await tester.tapAt(b.bookButton.center);
      await fadesIn(tester, b, size, rest, 'field $tag');
      pixelShadow(b, ps, 'field $tag, opened mid-wave');
    });
  }

  for (final size in townSizes) {
    final tag = '${size.width.round()}x${size.height.round()}';

    testWidgets('a Town at $tag: no shadow under the book (decisions-log 304) once the Town shows, over a whole bob, nor '
        'as it slides back in after a tap on the scene shut it and a sign opened it; the field\'s back with the field', (tester) async {
      final b = await boot(tester, size);
      b.autoStart.set(false);
      final g = await intoTown(tester, b);
      // Through the fade: the field, dimming, keeps the shadow under an open book; the Town's scene has none.
      var town = 0;
      for (var i = 0; i < 60; i++) {
        await frames(tester, 1);
        if (b.bookArea.isEmpty) continue;
        if (b.townShown) town++;
        expect(b.bookShadow.rows, b.townShown ? isEmpty : isNotEmpty, reason: '$tag frame $i, the Town shown: ${b.townShown}');
      }
      expect(town, greaterThan(10), reason: '$tag: the Town seen with the book open');
      await settle(tester, b);
      expect((b.townShown, b.bookArea.isEmpty), (true, false));
      for (var i = 0; i < 250; i++) {
        await frames(tester, 1);
        expect(b.bookShadow.rows, isEmpty, reason: '$tag: a whole bob, frame $i');
      }
      await tester.tapAt(bare(b, size));
      for (var i = 0; i < 60 && !b.bookArea.isEmpty; i++) {
        await frames(tester, 1);
      }
      expect(b.bookArea, Rect.zero);
      await tester.tapAt(b.townSign('smithy').center);
      var slid = 0;
      for (var i = 0; i < 40; i++) {
        await frames(tester, 1);
        if (b.bookArea.isEmpty) continue;
        slid++;
        expect(b.bookShadow.rows, isEmpty, reason: '$tag: sliding in, frame $i');
      }
      expect(slid, greaterThan(2), reason: '$tag: the book came back');

      // Leave: once the field shows again its book has the shadow.
      g.leaveTown();
      await settle(tester, b);
      for (var i = 0; i < 60 && b.bookArea.isEmpty; i++) {
        await frames(tester, 1);
      }
      await frames(tester, 40);
      expect((b.townShown, b.bookArea.isEmpty), (false, false));
      pixelShadow(b, bookPs(size), 'the field after the Town $tag');
    });
  }
}
