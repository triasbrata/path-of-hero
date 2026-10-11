// The Town's Tavern pages (decisions-log 267; ui-hud.md "The Tavern"; lib/tavern_page.dart): offscreen shots into
// <probe root>/shots/tavern/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_tavern_shots.dart"]` with the worktree as `dir` (`--plain-name <size>` for one size). It never
// touches the real save (flutter_test_config.dart's temp dir); the dice are seeded.
//
// First the sheets' maps (map-ui_icons-tavern.png: each ui_icons.png cell the page uses at x4 with its name and top left;
// map-fx_upgrade.png: the burst's frames numbered). Then at 1266x713, 1164x777, 915x412 and 412x860 (<size>), the Town
// after wave 20 with the Tavern on: reveal-<size> (0.15 s after the page opens: the rows coming in), tavern-<size> (the
// first look: the Feast picked, nothing bought), bought-<size> (the Feast bought: Sold, the Active slot; the second offer
// picked), short-<size> (the gold short: red prices, the white Buy, Reroll greyed), rerolled-<size> (after a reroll); and
// after wave 30 with every roll a Legendary: burst-<size> (0.4 s in: the Banquet's and the Epics' bursts),
// banquet-<size> (the King's Banquet's six rows), plate-<size> (the Champion's Plate picked, two boosts running).
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/hud_font.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/tavern');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game with the Towns and the Tavern on gone into the Town after wave [wave], seeded, [rules], a mixed army and
/// [gold].
Game board({int wave = 20, int gold = 4090, TownRules rules = const TownRules()}) {
  final g = Game(Random(seed), Random(seed + 100)).boardRules()
    ..slots = Random(seed + 300)
    ..loot = Random(seed + 200)
    ..draft = Random(seed + 500)
    ..townDice = Random(seed + 600)
    ..matDice = Random(seed + 700)
    ..tavernDice = Random(seed + 800)
    ..towns = true
    ..townRules = rules
    ..armyMax = null
    ..wave = wave;
  for (final type in ['knight', 'knight', 'archer', 'priest', 'wizard', 'soldier', 'lancer']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g
    ..gold = gold
    ..townAt = wave + 1;
  expect(g.enterTown(), isTrue);
  return g;
}

/// [cells] of [img] (name, its 16-px cell's top left) at x[k], each with its name and top left under it, on a dark
/// ground, into [file].
Future<void> mapSheet(WidgetTester tester, ui.Image img, List<(String, Rect)> cells, String file, {double k = 4}) async {
  const cellW = 150.0;
  final cellH = cells.map((e) => e.$2.height).reduce(max) * k + 40;
  final rec = ui.PictureRecorder(), c = Canvas(rec), w = cellW * min(6, cells.length), h = cellH * ((cells.length + 5) ~/ 6);
  c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF4F4A45));
  for (final (i, (name, src)) in cells.indexed) {
    final x = (i % 6) * cellW, y = (i ~/ 6) * cellH, to = Rect.fromLTWH(x + 8, y + 8, src.width * k, src.height * k);
    c.drawRect(to, Paint()..color = const Color(0xFFC8BCA0));
    c.drawImageRect(img, src, to, Paint()..filterQuality = FilterQuality.none);
    c.drawRect(to, Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFE0402A));
    final label = '$i $name ${src.left.round()},${src.top.round()} ${src.width.round()}x${src.height.round()}';
    TextPainter(text: TextSpan(text: label, style: hudStyle(11, color: Colors.white)), textDirection: TextDirection.ltr)
      ..layout(maxWidth: cellW - 8)
      ..paint(c, Offset(x + 8, to.bottom + 4));
  }
  final pic = rec.endRecording();
  await tester.runAsync(() async {
    final shot = await pic.toImage(w.round(), h.round());
    final png = await shot.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$file')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
  // ignore: avoid_print
  print('wrote $out/$file: ${cells.length} cells');
}

void main() {
  testWidgets('maps', (tester) async {
    await tester.runAsync(loadHudFontNow);
    final game = TdGame();
    await tester.pumpWidget(GameWidget(game: game));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    Rect cell(Offset o) => o & const Size(16, 16);
    await mapSheet(tester, game.images.fromCache('ui_icons.png'), [
      ('heart (Stew, Max HP)', cell(Offset.zero)),
      ('coin (Toast, Kill gold)', cell(const Offset(96, 0))),
      ('bolt (Mage, MP regen)', cell(const Offset(144, 0))),
      ('steel shield (Watch)', cell(const Offset(192, 0))),
      ('sword (Waves)', cell(const Offset(16, 16))),
      ('crown (Banquet)', cell(const Offset(64, 16))),
      ('crossed swords (Troops)', cell(const Offset(112, 16))),
      ('backpack (Rations)', cell(const Offset(160, 32))),
    ], 'map-ui_icons-tavern.png');
    final fx = game.images.fromCache('fx_upgrade.png'), fs = fx.height.toDouble();
    await mapSheet(tester, fx, [for (var f = 0; f < fx.width ~/ fx.height; f++) ('frame', Rect.fromLTWH(f * fs, 0, fs, fs))], 'map-fx_upgrade.png',
        k: 2);
    // ignore: avoid_print
    print('fx_upgrade.png ${fx.width}x${fx.height}: ${fx.width ~/ fx.height} frames; town_mug.png ${game.images.fromCache('town_mug.png').width}');
  });

  for (final size in const [Size(1266, 713), Size(1164, 777), Size(915, 412), Size(412, 860)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('tavern $tag', (tester) async {
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
        print('wrote $out/$name-$tag.png  page ${b.bookPage} pick ${b.tavernPick} rows ${[
          for (final r in b.tavernRows) '${r.kind.name} ${r.price}${r.short ? ' short' : ''}'
        ]} buy ${b.tavernText('buy')} effects ${[for (final e in b.tavernEffects) '${e.what} ${e.value}']} msg ${b.message}');
      }

      Future<void> tap(Rect r) async {
        expect(r, isNot(Rect.zero));
        await tester.tapAt(r.center);
        await frames(tester, 3);
      }

      Future<void> shut() async {
        if (b.messageBox != Rect.zero) await tap(b.messageBox);
      }

      var g = b.state = board();
      await frames(tester, 40);
      await shut();
      await tap(b.bookTabs.firstWhere((t) => t.$1 == 'tavern').$2);
      await shot('reveal', 6);
      await shot('tavern', 40);
      await tap(b.tavernAt('buy'));
      await shut();
      await tap(b.tavernRows[1].at);
      await shot('bought');
      g.gold = 120;
      await shot('short');
      g.gold = 4090;
      await tap(b.tavernAt('reroll'));
      await shot('rerolled', 40);

      // After wave 30, every roll a Legendary: the Banquet first, then the Epics.
      g = b.state = board(
          wave: 30,
          gold: 60000,
          rules: TownRules.patch({
            'tavern': {
              'odds': {'common': 0.0, 'rare': 0.0, 'epic': 0.0, 'legendary': 1.0},
              'firstFeast': false,
            },
          }));
      await frames(tester, 40);
      await shut();
      if (b.bookPage != 'tavern') await tap(b.bookTabs.firstWhere((t) => t.$1 == 'tavern').$2);
      await shot('burst', 20);
      await shot('banquet', 90); // the bursts over (1.2 s)
      await tap(b.tavernAt('buy'));
      await shut();
      final plate = b.tavernRows.indexWhere((r) => r.kind == Boost.plate);
      await tap(b.tavernRows[plate].at);
      await tap(b.tavernAt('buy'));
      await shut();
      await shot('plate');
    });
  }
}
