// The Town's sky and ground seen (decisions-log 274; ui-hud.md "Town"): offscreen shots into
// <probe root>/shots/town-ground/ (`OUT`), named `<TAG>-<shot>-<size>` (`TAG`, default "after"). A probe, not part
// of the suite (no `_test.dart`): queue `["test", "test/probe_town_ground_shots.dart"]` with the worktree or a `git
// archive` mirror as `dir` (`--dart-define=SIZES=1266x713` for some sizes only). It reads only the Board's Town hooks
// that a base without 274 has too, so it also makes the before shots. It never touches the real save
// (flutter_test_config.dart's temp dir); every dice is seeded.
//
// At 1266x713, 1164x777, 915x412, 412x860 and 1600x947 (the owner's window), a board game in its Town with two of
// each troop type:
// - town: the book open on the Smithy (as a Town opens), the troops spread along the street;
// - shut (landscape): the book shut, the street empty but for two troops sent in: the buildings' feet and the ground;
// - tent: panned to the tent, one troop resting in its opening and one by the fire;
// - door, out, down: panned to the Tavern, a troop just come to its door (going in), just come out of it again, and
//   set out on its next errand.
// It prints the lane, the street's rect and each building's bottom, and the two troops' feet.
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
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/town-ground');
const tag = String.fromEnvironment('TAG', defaultValue: 'after');
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
    for (final s in const [Size(1266, 713), Size(1164, 777), Size(915, 412), Size(412, 860), Size(1600, 947)])
      if (only.isEmpty || only.split(',').contains('${s.width.round()}x${s.height.round()}')) s,
  ];
  for (final size in sizes) {
    final name = '${size.width.round()}x${size.height.round()}', phone = size.width < size.height;
    testWidgets('town ground shots $name', (tester) async {
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
      final life = b.townLife;

      Future<void> shot(String file) async {
        await frames(tester, 2);
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = (await tester.runAsync(() => boundary.toImage()))!;
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$tag-$file-$name.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        final scene = b.townScene;
        String bottom(String place) {
          final cells = b.townBuilding(place);
          return cells.isEmpty ? '-' : cells.map((c) => c.$2.bottom).reduce(max).toStringAsFixed(0);
        }

        // ignore: avoid_print
        print('$tag-$file-$name k ${b.townK} cam ${b.townCam.toStringAsFixed(1)} lane ${b.townLane} '
            'street ${scene['street']} tent ${scene['tent']?.bottom} smithy ${bottom('smithy')} '
            'tavern ${bottom('tavern')} shop ${bottom('shop')} smith ${scene['smith']?.bottom} book ${b.bookArea} '
            'feet ${[for (final f in b.townFolk.take(2)) '${f.doing} ${f.feet}']}');
      }

      /// A finger's drag on the street that puts the view's left edge at [cam], kept in the pan's room.
      Future<void> panTo(double cam) async {
        final (lo, hi) = b.townRoom;
        cam = cam.clamp(lo, hi);
        final dx = (b.townCam - cam) * b.townK;
        if (dx.abs() < 0.5) return;
        final right = b.bookArea.isEmpty || phone ? size.width : b.bookArea.left;
        final from = Offset(dx > 0 ? 20 : right - 60, b.townLane - 10); // clear of the battle log's button
        final g = await tester.startGesture(from);
        await frames(tester, 1);
        await g.moveBy(Offset(dx.sign * 30, 0));
        await frames(tester, 1);
        await g.moveBy(Offset(dx - dx.sign * 22, 0));
        await frames(tester, 1);
        await g.up();
        await frames(tester, 4);
      }

      /// An anchor's world x ([Board.townSpot] is on the screen).
      double world(String spot) => b.townSpot(spot).dx / b.townK + b.townCam;

      /// Sends [f] to do [what] at [x] (world px) from [from], and steps until it gets there.
      Future<void> send(TownFolk f, TownDo what, double x, {double? from, int slot = 0}) async {
        f
          ..doing = what
          ..slot = slot
          ..mate = null
          ..until = double.infinity
          ..goal = x;
        if (from != null) f.x = from;
        for (var i = 0; i < 600 && f.walking; i++) {
          await frames(tester, 1);
        }
      }

      final g = b.state = board();
      win(g);
      await frames(tester, 200);
      win(g);
      for (var i = 0; i < 600 && !b.townShown; i++) {
        await frames(tester, 1);
      }
      expect(b.townShown, isTrue);
      for (final type in troopTypes.keys) {
        for (var i = 0; i < 2; i++) {
          g.units.add(Unit(Side.troop, type, g.statsOf(type), const Point(20, 20)));
        }
      }
      await frames(tester, 200); // the fade, and the troops spread along the street
      await shot('town');

      // Two troops alone on the street, each sent on its errand by hand (nobody else rolls one).
      g.units.removeWhere((u) => u.side == Side.troop && !const {'knight', 'priest'}.contains(u.type));
      final kept = <String>{};
      g.units.removeWhere((u) => u.side == Side.troop && !kept.add(u.type));
      await frames(tester, 4);
      expect(life.folk, hasLength(2));
      final (a, c) = (life.folk[0], life.folk[1]);
      if (!phone) {
        await tester.tapAt(Offset(min(b.bookArea.left, size.width) / 2, b.waveMeter.bottom + 40));
        await frames(tester, 40);
      }
      await panTo(world('tent') - 60);
      await send(a, TownDo.rest, world('tent'), from: world('tent') + 90);
      await send(c, TownDo.rest, world('tent') + 56, from: world('tent') + 120, slot: 3);
      await frames(tester, 10);
      await shot('tent');
      if (!phone) {
        await panTo(0);
        await shot('shut');
      }
      final door = world('tavernDoor');
      await panTo(door - 120);
      c.goal = double.nan; // the other stands by the fire
      await send(a, TownDo.tavern, door, from: door + 50);
      await frames(tester, 3);
      await shot('door');
      a.until = life.t + 1.8; // a short visit: inside (not drawn), then out of the door again
      for (var i = 0; i < 300 && !a.inside; i++) {
        await frames(tester, 1);
      }
      for (var i = 0; i < 300 && a.inside; i++) {
        await frames(tester, 1);
      }
      await frames(tester, 3);
      await shot('out');
      for (var i = 0; i < 300 && a.doing == TownDo.tavern; i++) {
        await frames(tester, 1);
      }
      await frames(tester, 6);
      await shot('down');
    });
  }
}
