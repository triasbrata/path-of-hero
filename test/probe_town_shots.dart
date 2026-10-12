// The Towns seen (decisions-log 216; ui-hud.md "The Town chip"): offscreen shots into <probe root>/shots/town-T2/
// (`OUT`). A probe, not part of the suite (no `_test.dart`): queue `["test", "test/probe_town_shots.dart"]` with the
// worktree as `dir`. It never touches the real save (flutter_test_config.dart's temp dir); the dice are seeded.
//
// At 1266x713, 915x412 and 412x860 (<size>): chip-<size> (wave 8 won, every roll hitting: a Town marked before wave 10,
// "Town after wave 9"; the book open), tip-<size> (its tooltip under the mouse), wave-<size> (wave 9 on, the book shut:
// the chip under the meter, the mini boss's bar under it), town-<size> (wave 9 won, in the Town: the meter's beer mug,
// "In town", "next wave 10"; "Leave town" in Start's place, no chip), auto-<size> (the same with Auto on: still "Leave town", no countdown: decisions-log 328) and log-<size> (the battle log's Town lines).
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/town-T2');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game between waves at wave 7 with the Towns on, every roll hitting, seeded, a mixed army.
Game board() {
  final g = Game(Random(seed), Random(seed + 100)).boardRules()
    ..slots = Random(seed + 300)
    ..loot = Random(seed + 200)
    ..draft = Random(seed + 500)
    ..townDice = Random(seed + 600)
    ..townRules = TownRules.patch({
      'schedule': {'chanceStart': 1.0},
    })
    ..armyMax = null
    ..gold = 40000
    ..wave = 7;
  for (final type in ['knight', 'archer', 'priest', 'wizard', 'soldier', 'lancer']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  return g;
}

void main() {
  for (final size in const [Size(1266, 713), Size(915, 412), Size(412, 860)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('town shots $tag', (tester) async {
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
        ..miniMapOpen = false;
      b.autoStart.set(false);

      Future<void> shot(String name, [int settle = 20]) async {
        await frames(tester, settle);
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = (await tester.runAsync(() => boundary.toImage()))!;
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name-$tag.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        // ignore: avoid_print
        print('wrote $out/$name-$tag.png  chip ${b.townChip} "${b.townChipLabel}" meter ${b.waveMeter} start ${b.startButton}');
      }

      // Wave 8 won (its one slime gone): the roll marks the Town before wave 10.
      final g = b.state = board();
      g
        ..startWave()
        ..queue.clear()
        ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
      await frames(tester, 3);
      await shot('chip', 200);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(b.townChip.center);
      await shot('tip', 30);
      await mouse.moveTo(Offset(size.width / 2, size.height - 4));
      await mouse.removePointer();

      // Wave 9 on, the book shut: a boss bar under the chip (a mini boss in the field).
      g
        ..startWave()
        ..queue.clear()
        ..waveSpawned = 20;
      final front = g.troops.map((u) => u.pos.x).reduce(max);
      for (final u in g.troops) {
        u.stunUntil = 1e9;
      }
      final bear = g.monster('werebear', Tier.miniBoss, Point(front + 90, 40))
        ..name = 'Grimdor'
        ..entered = true
        ..stunUntil = 1e9;
      g.units.add(bear);
      await shot('wave', 40);

      // Won (the mini boss gone): the cheer, then the Town ("Leave town"); with Auto on, the same (decisions-log 328).
      bear.gone = true;
      for (var i = 0; i < 600 && !g.inTown; i++) {
        await frames(tester, 1);
      }
      await shot('town', 30);
      b.autoStart.set(true);
      await shot('auto', 2);
      b.autoStart.set(false);
      if (b.logPanel == Rect.zero) {
        await tester.tapAt(b.logButton.center);
        await frames(tester, 2);
      }
      await shot('log', 10);
    });
  }
}
