// The Town troops' feet seen (decisions-log 242 gave them shadows, 270 took them away; lib/town_life.dart): offscreen shots into
// <probe root>/shots/town-shadow/ (`OUT`, file prefix `TAG`). A probe, not part of the suite: queue
// `["test", "test/probe_town_shadow_shots.dart", "--dart-define=TAG=before"]` (`--dart-define=SIZES=1266x713` for one size).
// At 1266x713, 1164x777, 915x412 and 412x860: the Town with 9 troops standing in a row on the street (types at awakening
// 0, 1, 2, 3, 4 and 5), `<TAG>-<size>` the whole shot and `<TAG>-zoom-<size>` the row's feet at 3x.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/town-shadow');
const tagName = String.fromEnvironment('TAG', defaultValue: 'after');
const only = String.fromEnvironment('SIZES');
const seed = 7;

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Every item [type]'s awakening recipe asks for, [level] times over.
List<Item> recipe(String type, int level) => [
      for (final MapEntry(key: item, value: n) in awakenRecipe[type]!.entries)
        for (var i = 0; i < n * level; i++) item,
    ];

const _types = ['soldier', 'knight', 'archer', 'priest', 'swordsman', 'wizard', 'lancer', 'armored_axeman', 'knight_templar'];
const _levels = [0, 1, 2, 3, 4, 5, 0, 1, 3];

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

void main() {
  final sizes = [
    for (final s in const [Size(1266, 713), Size(1164, 777), Size(915, 412), Size(412, 860)])
      if (only.isEmpty || only.split(',').contains('${s.width.round()}x${s.height.round()}')) s,
  ];
  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}', phone = size.width < size.height;
    testWidgets('town shadow shots $tag', (tester) async {
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
      final b = game.board
        ..welcome = null
        ..miniMapOpen = false
        ..townDice = Random(seed + 700);
      b.autoStart.set(false);
      final g = b.state = board();
      g
        ..startWave()
        ..queue.clear()
        ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
      await frames(tester, 200);
      g
        ..startWave()
        ..queue.clear()
        ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
      for (var i = 0; i < 600 && !b.townShown; i++) {
        await frames(tester, 1);
      }
      await frames(tester, 60);
      if (!phone) {
        await tester.tapAt(Offset(b.bookArea.left / 2, b.waveMeter.bottom + 40));
        await frames(tester, 40);
      }
      g.units.removeWhere((u) => u.side == Side.troop);
      for (var i = 0; i < _types.length; i++) {
        final t = _types[i], l = _levels[i];
        g.upgrades[t] = recipe(t, min(l, 3));
        if (l > 3) g.ascended[t] = l - 3;
        g.units.add(Unit(Side.troop, t, g.statsOf(t), Point(10.0 + i * 5, 20.0)));
      }
      await frames(tester, 4);
      final life = b.townLife, folk = life.folk;
      final base = life.spots['tent']!;
      for (var i = 0; i < folk.length; i++) {
        folk[i]
          ..doing = TownDo.rest
          ..x = base + i * 40
          ..goal = double.nan
          ..dir = i.isEven ? 1 : -1
          ..inside = false
          ..mate = null
          ..lead = false
          ..line = -1
          ..from = life.t - 1
          ..until = double.infinity;
      }
      await frames(tester, 3);
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = (await tester.runAsync(() => boundary.toImage()))!;
      final feet = [for (final f in b.townFolk) if (f.feet != null) f.feet!];
      final k = b.townK;
      final box = Rect.fromLTRB(feet.map((o) => o.dx).reduce(min) - 20 * k, feet.first.dy - 40 * k, feet.map((o) => o.dx).reduce(max) + 20 * k, feet.first.dy + 8 * k)
          .intersect(Offset.zero & size);
      final rec = ui.PictureRecorder(), canvas = Canvas(rec);
      canvas.drawImageRect(img, box, Offset.zero & box.size * 3, Paint()..filterQuality = FilterQuality.none);
      final big = await tester.runAsync(() => rec.endRecording().toImage((box.width * 3).round(), (box.height * 3).round()));
      await tester.runAsync(() async {
        for (final (name, im) in [('$tagName-$tag', img), ('$tagName-zoom-$tag', big!)]) {
          final png = await im.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        }
      });
      // ignore: avoid_print
      print('wrote $out/$tagName-$tag.png levels ${[for (final t in _types) g.awakenLevel(t)]} feet $feet');
    });
  }
}
