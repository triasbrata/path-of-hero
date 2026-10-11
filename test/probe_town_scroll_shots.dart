// The Town's sideways pan seen (decisions-log 264, 271; ui-hud.md "Town"): offscreen shots into
// <probe root>/shots/town-scroll/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_town_scroll_shots.dart"]` with the worktree or a mirror as `dir` (`--dart-define=SIZES=1266x713`
// for some sizes only). It never touches the real save (flutter_test_config.dart's temp dir); every dice is seeded.
//
// At 1266x713, 1164x777, 915x412 and 412x860 (<size>), a board game with the Towns on, in its Town (laid out 1010 world
// px wide, decisions-log 271), the book open on the Smithy (where a Town opens), panned by a finger's drag:
// - open-<size>: the Town as it opens, the Smithy's place in view;
// - pan-left-<size>, pan-mid-<size>, pan-right-<size>: at the pan's left end, its middle and its right end.
// In landscape, the book shut:
// - shut-<size>: as it shuts, the Smithy in the middle of the screen;
// - shut-left-<size>, shut-mid-<size>, shut-right-<size>: nobody on the street (so the pieces show), panned to the
//   Town's left end, its middle and its right end.
// It prints the pan's room and where the places were drawn.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'town_scene_test.dart' show bare;
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/town-scroll');
const only = String.fromEnvironment('SIZES');
const seed = 7;

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game between waves at wave 20 with the Towns on, a Town due at once, seeded.
Game board() => Game(Random(seed), Random(seed + 100)).boardRules()
    ..slots = Random(seed + 300)
    ..loot = Random(seed + 200)
    ..draft = Random(seed + 500)
    ..townDice = Random(seed + 600)
    ..towns = true
    ..townRules = TownRules.patch({
      'schedule': {'chanceStart': 1.0},
    })
    ..armyMax = null
    ..gold = 40000
    ..wave = 20;

/// Wins the wave on (its monsters gone).
void win(Game g) {
  g
    ..startWave()
    ..queue.clear()
    ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
}

void main() {
  final sizes = [
    for (final s in const [Size(1266, 713), Size(1164, 777), Size(915, 412), Size(412, 860)])
      if (only.isEmpty || only.split(',').contains('${s.width.round()}x${s.height.round()}')) s,
  ];
  for (final size in sizes) {
    final name = '${size.width.round()}x${size.height.round()}', phone = size.width < size.height;
    testWidgets('town scroll shots $name', (tester) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(loadHudFontNow);
      final game = TdGame();
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: key, child: GameWidget(game: game)));
      for (var i = 0; i < 3000 && !game.isLoaded; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(game.isLoaded, isTrue);
      final b = game.board
        ..welcome = null
        ..miniMapOpen = false
        ..townDice = Random(seed + 700);
      b.autoStart.set(false);

      Future<void> shot(String file) async {
        await frames(tester, 3);
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = (await tester.runAsync(() => boundary.toImage()))!;
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$file-$name.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        final scene = b.townScene;
        // ignore: avoid_print
        print('$file-$name cam ${b.townCam.toStringAsFixed(1)} room ${b.townRoom} k ${b.townK} book ${b.bookArea} '
            'tent ${scene['tent']} smithy ${scene['smithy']} tavern ${scene['tavern']} shop ${scene['shop']} '
            'pieces ${[for (final p in const ['pine', 'clothesLine', 'ore', 'sawmill', 'logPile', 'stumpAxe']) if (scene.containsKey(p)) p]}');
      }

      /// A finger's drag on the street that puts the view's left edge at [cam] (past the 8 px slop).
      Future<void> panTo(double cam) async {
        final dx = (b.townCam - cam) * b.townK;
        if (dx.abs() < 0.5) return;
        final right = b.bookArea.isEmpty || phone ? size.width : b.bookArea.left;
        final from = Offset(dx > 0 ? 20 : right - 20, b.townLane - 10);
        final g = await tester.startGesture(from);
        await frames(tester, 1);
        await g.moveBy(Offset(dx.sign * 30, 0));
        await frames(tester, 1);
        await g.moveBy(Offset(dx - dx.sign * 22, 0));
        await frames(tester, 1);
        await g.up();
        await frames(tester, 4);
        expect(b.townCam, closeTo(cam, 0.01), reason: 'panned to $cam');
      }

      Future<void> intoTown() async {
        final g = b.state = board();
        win(g);
        await frames(tester, 200);
        win(g);
        for (var i = 0; i < 600 && !b.townShown; i++) {
          await frames(tester, 1);
        }
        expect(b.townShown, isTrue);
        // Two of each type on the street (the board's army is its few starters).
        for (final type in troopTypes.keys) {
          for (var i = 0; i < 2; i++) {
            g.units.add(Unit(Side.troop, type, g.statsOf(type), const Point(20, 20)));
          }
        }
        await frames(tester, 200); // the fade, and the troops spread along the street
      }

      await intoTown();
      await shot('open');
      final (lo, hi) = b.townRoom;
      await panTo(lo);
      await shot('pan-left');
      await panTo((lo + hi) / 2);
      await shot('pan-mid');
      await panTo(hi);
      await shot('pan-right');

      if (phone) return;
      // The book shut (its page the Smithy again first), then the street emptied and the Town panned end to end.
      await tester.tapAt(b.bookTabs.firstWhere((t) => t.$1 == 'smithy').$2.center);
      await frames(tester, 40);
      await tester.tapAt(bare(b, size));
      await frames(tester, 40);
      expect(b.bookArea, Rect.zero);
      await shot('shut');
      b.state.units.removeWhere((u) => u.side == Side.troop);
      final (slo, shi) = b.townRoom;
      await panTo(slo);
      await shot('shut-left');
      await panTo((slo + shi) / 2);
      await shot('shut-mid');
      await panTo(shi);
      await shot('shut-right');
    });
  }
}
