// The Town's smith seen (decisions-log 265; ui-hud.md "Town"): offscreen shots into <probe root>/shots/smithy-npc/
// (`OUT`). A probe, not part of the suite (no `_test.dart`): queue `["test", "test/probe_smith_shots.dart"]` with the
// worktree as `dir` (`--dart-define=SIZES=1266x713,412x860` for some sizes only). It never touches the real save
// (flutter_test_config.dart's temp dir); every dice is seeded.
//
// At 1266x713, 1164x777, 915x412 and 412x860 (<size>), a board game with the Towns on, in its Town (landscape: the book
// shut, the whole Town; a phone: the Smithy's place), its troops sent away:
// - smith-town-<size>: the Town; smith-house-<size>: the Smithy's house and its furnace 3x;
// - smith-anim-<size>: the smith where he is drawn, 4x, once for each frame seen over 3.2 s of his loop (in the order
//   seen), side by side.
// It prints where the smith, the Smithy's walls and its sign were drawn, and the street's lane.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/smithy-npc');
const only = String.fromEnvironment('SIZES');
const seed = 7;

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game between waves at wave 20 with the Towns on, a Town due at once, seeded, no army cap.
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
    for (final s in const [Size(1266, 713), Size(1164, 777), Size(915, 412), Size(412, 860)])
      if (only.isEmpty || only.split(',').contains('${s.width.round()}x${s.height.round()}')) s,
  ];
  for (final size in sizes) {
    final name = '${size.width.round()}x${size.height.round()}', phone = size.width < size.height;
    testWidgets('smith shots $name', (tester) async {
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

      Future<ui.Image> grab() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        return (await tester.runAsync(() => boundary.toImage()))!;
      }

      Future<void> save(ui.Image img, String file) async {
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$file-$name.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        // ignore: avoid_print
        print('wrote $out/$file-$name.png');
      }

      /// [boxes] of [imgs] side by side (the i-th box of the i-th image), each [z] times, on one picture.
      Future<ui.Image> crops(List<ui.Image> imgs, List<Rect> boxes, [double z = 3]) async {
        final rec = ui.PictureRecorder(), canvas = Canvas(rec), paint = Paint()..filterQuality = FilterQuality.none;
        var x = 0.0, h = 0.0;
        for (var i = 0; i < boxes.length; i++) {
          canvas.drawImageRect(imgs[i], boxes[i], Offset(x, 0) & boxes[i].size * z, paint);
          x += boxes[i].width * z + 6;
          h = max(h, boxes[i].height * z);
        }
        return (await tester.runAsync(() => rec.endRecording().toImage(max(1, x.round()), max(1, h.round()))))!;
      }

      // Into the Town, the book shut in landscape (a tap on the sky left of it).
      final g = b.state = board();
      win(g);
      await frames(tester, 200);
      win(g);
      for (var i = 0; i < 600 && !b.townShown; i++) {
        await frames(tester, 1);
      }
      await frames(tester, 60);
      if (!phone) {
        await tester.tapAt(Offset(b.bookArea.left / 2, b.waveMeter.bottom + 40));
        await frames(tester, 40);
      }
      expect(b.townShown, isTrue);
      g.units.removeWhere((u) => u.side == Side.troop);
      await frames(tester, 4);
      final k = b.townK, scene = b.townScene, smith = scene['smith']!;
      final house = b.townBuilding('smithy').map((c) => c.$2).reduce((a, c) => a.expandToInclude(c));
      // ignore: avoid_print
      print('smith $name k $k: smith $smith feet x ${smith.left + 20 * k} sign ${b.townSign('smithy').center} '
          'house $house lane ${b.townLane} furnace ${scene['furnace']}');
      final town = await grab();
      await save(town, 'smith-town');
      final around = house.expandToInclude(scene['furnace']!).inflate(4 * k).intersect(Offset.zero & size);
      await save(await crops([town], [around], 3), 'smith-house');

      // The loop: a grab every 48 ms for 3.2 s, each new look of the smith kept once, in the order seen.
      final seen = <Uint8List>[], shots = <ui.Image>[];
      for (var i = 0; i < 67 && seen.length < 6; i++) {
        await frames(tester, 3);
        final img = await grab();
        final bytes = await tester.runAsync(() async {
          final rec = ui.PictureRecorder();
          Canvas(rec).drawImageRect(img, smith, Offset.zero & smith.size, Paint());
          final crop = await rec.endRecording().toImage(smith.width.round(), smith.height.round());
          return (await crop.toByteData())!.buffer.asUint8List();
        });
        if (!seen.any((s) => listEquals(s, bytes!))) {
          seen.add(bytes!);
          shots.add(img);
        }
      }
      // ignore: avoid_print
      print('smith $name: ${seen.length} looks seen');
      await save(await crops(shots, [for (final _ in shots) smith.inflate(2 * k)], 4 / k), 'smith-anim');
    });
  }
}
