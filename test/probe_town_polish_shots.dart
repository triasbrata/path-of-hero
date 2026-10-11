// The Town polish seen (decisions-log 253; ui-hud.md "Town"): offscreen shots into <probe root>/shots/town-polish/
// (`OUT`), named with `TAG` ('after' by default; 'before' on a mirror of main). A probe, not part of the suite (no
// `_test.dart`): queue `["test", "test/probe_town_polish_shots.dart"]` with the worktree or a mirror as `dir`
// (`--dart-define=SIZES=1266x713,412x860` for some sizes only). It never touches the real save (flutter_test_config.dart's
// temp dir); every dice is seeded.
//
// At 1266x713, 1164x777, 915x412 and 412x860 (<size>), a board game with the Towns on, in its Town (landscape: the book
// shut, the whole Town; a phone: the Smithy's place):
// - town-<tag>-<size>: the Town with nobody on the street, and yard-<tag>-<size>: its yard (the pine and the clothes
//   line) 3x, where it is drawn;
// - talk0-<tag>-<size>, talk1-<tag>-<size>: every troop type in five talking pairs (soldier-knight, swordsman-archer,
//   lancer-priest, armored_axeman-wizard, knight_templar-lancer), the first line (the left one of each pair speaks) and
//   the second (the right one), each pair 3x side by side, so each type's bubble is seen over its head.
// It prints where the yard's pieces and each bubble were drawn.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/town-polish');
const only = String.fromEnvironment('SIZES');
const tag = String.fromEnvironment('TAG', defaultValue: 'after');
const seed = 7;

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The pairs, left one first: every troop type, the lancer twice (the owner's case).
const _pairs = [
  ('soldier', 'knight'),
  ('swordsman', 'archer'),
  ('lancer', 'priest'),
  ('armored_axeman', 'wizard'),
  ('knight_templar', 'lancer'),
];

/// A board game between waves at wave 20 with the Towns on, a Town due at once, seeded, no army.
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
    testWidgets('town polish shots $name', (tester) async {
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
          File('$out/$file-$tag-$name.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        // ignore: avoid_print
        print('wrote $out/$file-$tag-$name.png');
      }

      /// [boxes] of [img] side by side, each [z] times, on one picture.
      Future<ui.Image> crops(ui.Image img, List<Rect> boxes, [double z = 3]) async {
        final rec = ui.PictureRecorder(), canvas = Canvas(rec), paint = Paint()..filterQuality = FilterQuality.none;
        var x = 0.0, h = 0.0;
        for (final box in boxes) {
          canvas.drawImageRect(img, box, Offset(x, 0) & box.size * z, paint);
          x += box.width * z + 6;
          h = max(h, box.height * z);
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
      final k = b.townK;

      // The street empty, and its yard close up.
      g.units.removeWhere((u) => u.side == Side.troop);
      await frames(tester, 4);
      final empty = await grab();
      await save(empty, 'town');
      final scene = b.townScene;
      // ignore: avoid_print
      print('yard $name k $k: yard ${scene['yard']} pine ${scene['pine']} clothesLine ${scene['clothesLine']} '
          'stumpAxe ${scene['stumpAxe']} tavern ${scene['tavern']}');
      if (scene['yard'] case final yard?) await save(await crops(empty, [yard.inflate(12 * k)]), 'yard');

      // Every type talking, in five pairs across the view.
      final units = [
        for (final (a, c) in _pairs)
          for (final type in [a, c]) Unit(Side.troop, type, g.statsOf(type), const Point(20, 20)),
      ];
      g.units.addAll(units);
      await frames(tester, 4);
      final life = b.townLife;
      TownFolk folkOf(Unit u) => life.folk.firstWhere((f) => identical(f.unit, u));
      final viewL = b.townCam, viewW = size.width / k, step = (viewW - 40) / _pairs.length;
      void talk(double since) {
        for (var p = 0; p < _pairs.length; p++) {
          final mid = viewL + 20 + step * (p + 0.5);
          final a = folkOf(units[2 * p]), c = folkOf(units[2 * p + 1]);
          for (final (f, x, dir) in [(a, mid - townTalkGap / 2, 1), (c, mid + townTalkGap / 2, -1)]) {
            f
              ..doing = TownDo.talk
              ..x = x
              ..goal = double.nan
              ..dir = dir
              ..inside = false
              ..thought = false // a browser's grey bubble before it: this one speaks
              ..line = -1
              ..from = life.t - since
              ..until = life.t + 100;
          }
          a
            ..mate = c
            ..lead = true;
          c
            ..mate = a
            ..lead = false;
        }
      }

      for (final (line, since) in [(0, 0.3), (1, 1.9)]) {
        talk(since);
        await frames(tester, 3);
        final img = await grab();
        await save(img, 'talk${line}full');
        final drawn = {for (final f in b.townFolk) f.unit: f};
        final boxes = <Rect>[];
        for (var p = 0; p < _pairs.length; p++) {
          final a = drawn[units[2 * p]]!, c = drawn[units[2 * p + 1]]!;
          final top = [a.feet!.dy - 60 * k, if (a.bubble.width > 0) a.bubble.top - 4, if (c.bubble.width > 0) c.bubble.top - 4].reduce(min);
          boxes.add(Rect.fromLTRB(a.feet!.dx - 24 * k, top, c.feet!.dx + 24 * k, a.feet!.dy + 6 * k));
          for (final f in [a, c]) {
            // ignore: avoid_print
            print('talk$line $name ${f.unit.type} feet ${f.feet} dir ${f.dir} bubble ${f.bubble} '
                'tail ${f.bubble.width > 0 ? Offset(f.bubble.left + townBubbleTip.dx * max(2, k), f.bubble.bottom) : '-'}');
          }
        }
        await save(await crops(img, boxes), 'talk$line');
      }
    });
  }
}
