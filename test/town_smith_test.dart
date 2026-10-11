// The Town's smith in the scene (decisions-log 265; lib/town_smith.dart; ui-hud.md "Town"): at the desk (1266x713),
// the phone (915x412) and the owner's tablet (1164x777), in a Town he is drawn on the Smithy's ground floor, his
// feet at its house's middle (under its sign) on its floor (townStep over the street's lane, decisions-log 274), inside
// its walls and below its window, at 1 world px
// a sprite px; his loop runs on the field's clock; with the Towns off no Town and no smith shows. Decoration only: a tap
// on him is the Smithy's house's (its page).
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/town_smith_art.dart';

import 'town_hud_test.dart' show boot, frames;
import 'town_scene_test.dart' show bare, intoTown, settle, sizes, wheel;

void main() {
  test('townSmithFrameAt plays the beats in turn and loops every townSmithLoopMs', () {
    var at = 0;
    for (final b in townSmithBeats) {
      expect(townSmithFrameAt(at / 1000), b.frame, reason: 'at $at ms');
      expect(townSmithFrameAt((at + b.ms - 1) / 1000), b.frame, reason: 'at ${at + b.ms - 1} ms');
      at += b.ms;
    }
    expect(at, townSmithLoopMs);
    expect(townSmithFrameAt(townSmithLoopMs / 1000), townSmithBeats.first.frame, reason: 'again from the start');
    expect(townSmithFrameAt(10 * townSmithLoopMs / 1000 + 0.2), townSmithFrameAt(0.2));
  });

  for (final (size, scale, _, _) in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('the smith at $tag: on the Smithy\'s ground floor under its sign, on the street, at 1 world px a sprite '
        'px; a tap on him opens the Smithy', (tester) async {
      final b = await boot(tester, size);
      b.autoStart.set(false);
      await intoTown(tester, b);
      await settle(tester, b);
      final k = b.townK, smith = b.townScene['smith']!;
      expect(k, scale);
      expect(smith.size, Size(townSmithW * k, townSmithH * k), reason: '1 world px a sprite px');
      expect(smith.left, smith.left.roundToDouble(), reason: 'on whole screen px');
      final feet = Offset(smith.left + townSmithFeet.x * k, smith.top + townSmithFeet.y * k);
      expect(feet.dx, closeTo(b.townSign('smithy').center.dx, k), reason: 'at the house\'s middle, under its sign');
      expect(feet.dy, closeTo(b.townLane - townStep * k, 0.01), reason: "on the Smithy's floor, townStep over the lane");
      Rect cell(String name) => b.townBuilding('smithy').firstWhere((c) => c.$1 == name).$2;
      final walls = Rect.fromLTRB(cell('wallL8a').left, cell('wallL8a').top, cell('blockBR').right, cell('blockBR').bottom);
      expect(smith.left, greaterThanOrEqualTo(walls.left), reason: 'inside the walls: $smith, $walls');
      expect(smith.right, lessThanOrEqualTo(walls.right), reason: 'inside the walls: $smith, $walls');
      final window = b.townBuilding('smithy').where((c) => c.$1.startsWith('win')).map((c) => c.$2).reduce((a, c) => a.expandToInclude(c));
      expect(smith.top, greaterThanOrEqualTo(window.bottom - 2 * k), reason: 'below the window: $smith, $window');
      // No tap of his own: a tap on him is the Smithy's house's, its page (landscape: the book shut, then on the Tavern's
      // page, then shut again, so the Smithy's page comes from the tap; the wheel brings each into view, the Town wider
      // than the screen: decisions-log 271).
      if (size.width > size.height) {
        Future<void> tap(Offset at) async {
          await tester.tapAt(at);
          await frames(tester, 40);
        }
        await tap(bare(b, size));
        await wheel(tester, bare(b, size), b.townScene['tavern']!.center.dx - size.width / 2);
        await tap(b.townScene['tavern']!.center);
        expect(b.bookPage, 'tavern');
        await tap(bare(b, size));
        expect(b.bookArea, Rect.zero);
        await wheel(tester, bare(b, size), b.townScene['smith']!.center.dx - size.width / 2);
        await tap(b.townScene['smith']!.center);
        expect(b.bookPage, 'smithy');
      }
    });
  }

  testWidgets('with the Towns off no Town shows, so no smith', (tester) async {
    final b = await boot(tester);
    b.autoStart.set(false);
    b.state = Game(Random(1), Random(2)).boardRules()
      ..towns = false
      ..wave = 20;
    await frames(tester, 40);
    expect((b.townShown, b.townScene.containsKey('smith')), (false, false));
  });
}
