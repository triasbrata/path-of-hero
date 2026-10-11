// The Town's life seen (decisions-log 229; lib/town_life.dart; ui-hud.md "Town life"): offscreen shots into
// <probe root>/shots/town-T6d/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_town_life_shots.dart"]` with the worktree as `dir` (`--dart-define=SIZES=1266x713,412x860` for
// some sizes only). It never touches the real save (flutter_test_config.dart's temp dir); every dice is seeded.
//
// At 1266x713, 1164x777, 915x412 and 412x860 (<size>), a board game with the Towns on, in its Town (landscape: the book
// shut, the whole Town; a phone: its one place, the Smithy's and then the Tavern's):
// - life6-<size>, life30-<size>: 6 and 30 troops (a Hero among them) after 8 s of their life on a seeded visual dice
//   (a phone's: life6-bag-<size>, life30-bag-<size> on the Tavern too);
// - spots-<size> (a phone: spots-smithy-, spots-bag-, spots-shop-): someone at each anchor, set by hand: two guards
//   (the Town's ends, facing out), two resting by the tent's fire, a browser at the Smithy's furnace and one at the
//   Shop's stall (their thought bubbles), one inside the Tavern (its window's bubble), a pair talking before the
//   Tavern's right side (a bubble over the first), one walking;
// - 1266x713 only: talk1-closeup, talk2-closeup (the pair 3x: the first's line, then the other's) and seq1 … seq8
//   (12 troops, 0.5 s apart: moving).
// It also prints the Town's cost a frame (update + render into a picture, 600 frames) at 1164x777 with 30 troops and
// with none.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/town-T6d');
const only = String.fromEnvironment('SIZES');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The army's types, in turn: [n] troops of them.
const _mix = ['soldier', 'knight', 'archer', 'priest', 'swordsman', 'wizard', 'lancer', 'armored_axeman', 'knight_templar'];

/// A board game between waves at wave 20 (the Shop open) with the Towns on, every roll hitting, seeded, no army.
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

/// [n] troops on [g]'s field (the first a Hero).
void army(Game g, int n) {
  g.units.removeWhere((u) => u.side == Side.troop);
  for (var i = 0; i < n; i++) {
    final type = _mix[i % _mix.length];
    g.units.add(Unit(Side.troop, type, g.statsOf(type), Point(10.0 + (i % 3) * 14, 20.0 + (i ~/ 3) * 10))..hero = i == 0);
  }
}

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
    final tag = '${size.width.round()}x${size.height.round()}', phone = size.width < size.height;
    testWidgets('town life shots $tag', (tester) async {
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

      Future<void> save(ui.Image img, String name) async {
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
      }

      String folkLine() => [
            for (final f in b.townFolk)
              '${f.unit.type}${f.unit.hero ? '*' : ''} ${f.doing} ${f.feet == null ? 'in' : '${f.feet!.dx.round()},${f.feet!.dy.round()}'}'
                  '${f.dir < 0 ? '<' : '>'}${f.icon == null ? '' : ' [${f.icon}${f.thought ? '?' : ''}]'}',
          ].join('; ');

      Future<ui.Image> shot(String name, [int settle = 2]) async {
        await frames(tester, settle);
        final img = await grab();
        await save(img, '$name-$tag');
        // ignore: avoid_print
        print('wrote $out/$name-$tag.png  page ${b.bookPage} k ${b.townK} cam ${b.townCam.toStringAsFixed(1)} lane '
            '${b.townLane} life t ${b.townLife.t.toStringAsFixed(1)} width ${b.townLife.width} window ${b.townWindowBubble} '
            'folk ${folkLine()}');
        return img;
      }

      Rect tab(String page) => b.bookTabs.firstWhere((t) => t.$1 == page).$2;

      /// Into the Town (the book shut in landscape), its fade over.
      Future<Game> town() async {
        final g = b.state = board();
        win(g);
        await frames(tester, 200);
        win(g);
        for (var i = 0; i < 600 && !b.townShown; i++) {
          await frames(tester, 1);
        }
        await frames(tester, 60);
        if (!phone) {
          // A tap on the sky left of the book: the book shuts, the whole Town shows.
          await tester.tapAt(Offset(b.bookArea.left / 2, b.waveMeter.bottom + 40));
          await frames(tester, 40);
        }
        return g;
      }

      final g = await town();
      for (final n in [6, 30]) {
        army(g, n);
        await frames(tester, 500); // 8 s of their life
        await shot('life$n');
        if (phone) {
          await tester.tapAt(tab('bag').center);
          await shot('life$n-bag', 40);
          await tester.tapAt(tab('smithy').center);
          await frames(tester, 40);
        }
      }

      // Someone at each anchor, set by hand (each standing for good: no stay ends).
      army(g, 12);
      await frames(tester, 4);
      final life = b.townLife, s = life.spots, folk = life.folk;
      life.t = 100.2; // the Tavern window's bubble shows (its first 1.8 s of every 5)
      void put(TownFolk f, TownDo what, double x, int dir, {bool inside = false, double since = 1}) {
        f
          ..doing = what
          ..x = x
          ..goal = double.nan
          ..dir = dir
          ..inside = inside
          ..mate = null
          ..lead = false
          ..line = -1
          ..from = life.t - since
          ..until = double.infinity;
      }

      put(folk[0], TownDo.guard, s['guard']!, -1);
      put(folk[1], TownDo.guard, life.width - s['guard']!, 1);
      put(folk[2], TownDo.rest, s['tent']!, 1);
      put(folk[3], TownDo.rest, s['tent']! + townRest[1], 1);
      put(folk[4], TownDo.smithy, s['smithy']! + townBrowse[0], 1);
      put(folk[5], TownDo.shop, s['shop']! + townBrowse[0], 1);
      put(folk[6], TownDo.tavern, s['tavernDoor']!, 1, inside: true);
      void talk(double since) {
        put(folk[7], TownDo.talk, s['talk']! - townTalkGap / 2, 1, since: since);
        put(folk[8], TownDo.talk, s['talk']! + townTalkGap / 2, -1, since: since);
        folk[7]
          ..mate = folk[8]
          ..lead = true
          ..until = life.t + 100;
        folk[8]
          ..mate = folk[7]
          ..until = life.t + 100;
      }

      talk(0.3);
      for (final f in folk.skip(9)) {
        put(f, TownDo.stroll, f.x.isNaN ? 300 : f.x, 1);
        f.goal = life.width - townEdge; // walking
      }
      if (phone) {
        for (final page in ['smithy', 'bag', 'store']) {
          await tester.tapAt(tab(page).center);
          await frames(tester, 40);
          life.t = 100.2;
          for (final f in [folk[4], folk[5]]) {
            f.from = life.t - 1;
          }
          talk(0.3);
          await shot('spots-${page == 'store' ? 'shop' : page}');
        }
        return;
      }
      final spots = await shot('spots');
      if (size.width != 1266) return;

      // The talk close up, 3x: the first's line, then the other's.
      Future<void> closeUp(ui.Image img, String name) async {
        final a = b.townFolk[7], c = b.townFolk[8], k = b.townK;
        // From over the higher bubble (a lancer's rides over its lance) to under their feet.
        final top = [a.feet!.dy - 70 * k, if (a.bubble.width > 0) a.bubble.top - 4 * k, if (c.bubble.width > 0) c.bubble.top - 4 * k].reduce(min);
        final box = Rect.fromLTRB(a.feet!.dx - 30 * k, top, c.feet!.dx + 30 * k, a.feet!.dy + 8 * k);
        final rec = ui.PictureRecorder(), canvas = Canvas(rec);
        canvas.drawImageRect(img, box, Offset.zero & box.size * 3, Paint()..filterQuality = FilterQuality.none);
        final big = await tester.runAsync(() => rec.endRecording().toImage((box.width * 3).round(), (box.height * 3).round()));
        await save(big!, '$name-$tag');
        // ignore: avoid_print
        print('wrote $out/$name-$tag.png  bubbles ${b.townFolk[7].bubble} ${b.townFolk[8].bubble} icons ${b.townFolk[7].icon} '
            '${b.townFolk[8].icon}');
      }

      await closeUp(spots, 'talk1-closeup');
      talk(1.9); // the second line: the other's
      await closeUp(await shot('spots-line2'), 'talk2-closeup');

      // 12 troops on the visual dice, 0.5 s apart.
      b.townDice = Random(seed + 800);
      army(g, 0);
      await frames(tester, 2);
      army(g, 12);
      await frames(tester, 120);
      for (var i = 1; i <= 8; i++) {
        await shot('seq$i', i == 1 ? 2 : 31);
      }
    });
  }

  testWidgets("the Town's cost a frame at 1164x777: 30 troops and none", (tester) async {
    tester.view
      ..physicalSize = const Size(1164, 777)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadHudFontNow);
    final game = TdGame();
    await tester.pumpWidget(GameWidget(game: game));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    final b = game.board
      ..welcome = null
      ..miniMapOpen = false
      ..townDice = Random(seed + 900);
    b.autoStart.set(false);
    final g = b.state = board();
    win(g);
    await frames(tester, 200);
    win(g);
    for (var i = 0; i < 600 && !b.townShown; i++) {
      await frames(tester, 1);
    }
    await frames(tester, 60);
    for (final n in [30, 0, 30]) {
      army(g, n);
      await frames(tester, 10);
      // Warm up, then 600 frames of update + render into a picture (not rasterised), timed.
      void run(int frames) {
        for (var i = 0; i < frames; i++) {
          b.update(1 / 60);
          final rec = ui.PictureRecorder();
          b.render(Canvas(rec));
          rec.endRecording().dispose();
        }
      }

      run(120);
      final watch = Stopwatch()..start();
      run(600);
      // ignore: avoid_print
      print('COST $n troops: ${(watch.elapsedMicroseconds / 600).toStringAsFixed(0)} us a frame (update + render), '
          'folk ${b.townLife.folk.length} shown ${b.townFolk.where((f) => f.feet != null).length}');
    }
  });
}
