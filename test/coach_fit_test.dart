// The first-time guide fits (docs/ui-hud.md "Guide", lib/coach.dart): at 1266x713 and 915x412 every page of the
// intro and of every one-time card K0-K22 stays 8 px inside the screen, its ribbon in, its buttons inside it and apart;
// the pointers P1-P5 stay 8 px inside too and never cover what they point at (their tail neither), all through their
// bob; and the welcome screen's split row "Papan Skor | Cara Main" sits under the other buttons, on the screen, with a
// save to go back to (the tallest panel). The behaviour: coach_hud_test.dart. One TdGame per widget test.
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/guide_rules.dart';
import 'package:tower_defense/guide_text.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/save.dart' show Welcome;

import 'hud_font.dart';

const sizes = [Size(1266, 713), Size(915, 412)];

/// How far inside the screen's edges the guide stays.
const edge = 8.0;

Future<Board> boot(WidgetTester tester, Size size) async {
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

/// [r] [edge] px inside a [size] screen.
void inside(Rect r, Size size, String why) {
  expect(r, isNot(Rect.zero), reason: '$why: drawn');
  expect((r.left >= edge, r.top >= edge, r.right <= size.width - edge, r.bottom <= size.height - edge), (true, true, true, true),
      reason: '$why: $r on $size');
}

/// [rects] not overlapping one another.
void apart(Iterable<Rect> rects, String why) {
  final list = rects.toList();
  for (final (i, r) in list.indexed) {
    for (final o in list.skip(i + 1)) {
      expect(r.intersect(o).width <= 0 || r.intersect(o).height <= 0, isTrue, reason: '$why: $r over $o');
    }
  }
}

void main() {
  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';

    testWidgets('$tag: every page of the intro and of each card K0-K22 fits, its buttons inside it', (tester) async {
      final b = await boot(tester, size);
      b
        ..state = (Game(Random(1)).boardRules()..gold = 1 << 20)
        ..guideSeen = {};
      await frames(tester, 10);
      for (final key in [guideIntro, ...guideEn.cards.keys]) {
        b.openGuide(key);
        final pages = key == guideIntro ? guideEn.intro.length : guideEn.cards[key]!.length;
        for (var page = 0; page < pages; page++) {
          await frames(tester, 30); // popped in
          final why = '$key page ${page + 1}';
          expect(b.coachCard, (key, page), reason: why);
          final panel = b.coachPanel;
          inside(panel, size, why);
          final buttons = b.coachButtons;
          expect(buttons.length, key == guideIntro ? 3 : 0, reason: why);
          for (final r in buttons.values) {
            expect(panel.contains(r.topLeft) && panel.contains(r.bottomRight - const Offset(1, 1)), isTrue, reason: '$why: $r');
          }
          apart(buttons.values, why);
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await frames(tester);
        }
        expect(b.coachCard, isNull, reason: '$key: closed after its last page');
      }
    });

    testWidgets('$tag: the pointers P1-P5 stay inside and never cover what they point at', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = Game(Random(1)).boardRules()..gold = 1 << 20;
      b.guideSeen = {guideIntro};
      await frames(tester, 60);

      /// Pointer [key] over a bob's whole swing: inside, its box and tail clear of its target.
      Future<void> check(String key) async {
        for (var i = 0; i < 20; i++) {
          await frames(tester, 4);
          final why = '$key, frame $i';
          expect(b.coachPointer, key, reason: why);
          final box = b.coachPointerBox, target = b.coachPointerTarget;
          inside(box, size, why);
          // The tail sticks out of the box toward the target, at most 12 px, its tip a few px off it.
          expect(box.inflate(10).overlaps(target), isFalse, reason: '$why: $box (and its tail) over $target');
        }
      }

      await check('P1');
      b.guideSeen!.add('P1');
      await check('P2');
      expect(b.coachPointerTarget, b.startButton);
      b.guideSeen!.add('P2');
      g.inventory[Item.sword] = 1;
      await check('P3');
      await tester.tapAt(b.coachPointerTarget.center);
      await frames(tester, 3);
      await check('P4');
      await tester.tapAt(b.coachPointerTarget.center);
      await frames(tester, 3);
      expect(b.picked, Item.sword);
      await check('P5'); // at its "Give to troops" (decisions-log 202)
      await tester.tapAt(b.coachPointerTarget.center);
      await frames(tester, 3);
      expect(b.bagChooser, BagAction.giveTroops);
      await check('P5'); // at a type that takes it
    });

    testWidgets('$tag: the welcome screen\'s last row, "Scoreboard | How to Play" (ids \'Papan Skor\', \'Cara Main\'), fits '
        'under the others', (tester) async {
      final b = await boot(tester, size)..welcome = Welcome(Game()..wave = 12, discard: () {});
      await frames(tester, 3);
      final w = b.welcomeButtons;
      expect(w.keys, unorderedEquals(['Lanjutkan', 'Main Baru', 'Papan Skor', 'Cara Main']));
      for (final MapEntry(key: label, value: r) in w.entries) {
        inside(r, size, label);
      }
      apart(w.values, 'welcome');
      final (score, howTo) = (w['Papan Skor']!, w['Cara Main']!);
      for (final (a, b) in [(score.top, howTo.top), (score.height, howTo.height), (score.width, howTo.width)]) {
        expect(a, closeTo(b, 0.01), reason: 'one row, alike');
      }
      expect(score.right, lessThan(howTo.left));
      expect(score.top, greaterThan(w['Main Baru']!.bottom), reason: 'the last row');
      expect((score.left + howTo.right) / 2, closeTo(size.width / 2, 1), reason: 'centred');
    });
  }
}
