// The two Autos named apart, seen (decisions-log 290; ui-hud.md "Start/Pause toggle", "Spawn bar"): offscreen shots into
// <probe root>/shots/auto-names/new (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_auto_names_shots.dart"]` with a mirror as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir).
//
// At each size (`SIZES`): the top band with Auto Wave on, between waves, its countdown running ("Start 4"); the same held
// ("Army 1/6 · Auto Wave waits"); in a wave; in a Town ("Leave town 5"); and the spawn bar's Auto Buy off and on. Each
// line printed gives the top band's pieces and the bar's still block, and any two top band pieces that overlap. Then
// the landscape top band's width at k 2, 3 and 4 (as test/probe_hud_merge_width.dart), for wave_meter.dart's fit.
import 'dart:convert';
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/auto-names/new');
const sizes = String.fromEnvironment('SIZES', defaultValue: '1600x947,1266x713,1164x777,915x412,412x860');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('auto names shots', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 947)
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

    Map<String, Rect> band() => {
          'counter': b.troopCounter,
          'hearts': b.livesBar,
          'gold': b.goldPanel,
          'book': b.bookButton,
          'toggle': b.toggleButton,
          'x2': b.speedButton,
          'Auto': b.autoButton,
          'meter': b.waveMeter,
          'held': b.autoHeldLine,
        }..removeWhere((_, r) => r == Rect.zero);

    Future<void> shot(String name) async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = (await tester.runAsync(() => boundary.toImage()))!;
      await tester.runAsync(() async {
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
      final at = band(), names = at.keys.toList(), over = <String>[];
      for (var i = 0; i < names.length; i++) {
        for (var j = i + 1; j < names.length; j++) {
          if (at[names[i]]!.overlaps(at[names[j]]!)) over.add('${names[i]}/${names[j]}');
        }
      }
      // ignore: avoid_print
      print('AUTO ${jsonEncode({
            'shot': '$name.png',
            'k': b.hudScale,
            for (final MapEntry(:key, :value) in at.entries) key: _r(value),
            'countdown': b.autoStart.shown,
            'barPanel': _r(b.spawnBarPanel),
            'room': _r(b.capacityButton),
            'autoBuy': _r(b.autoReplaceButton),
            'perPage': b.spawnBarPerPage,
            'cards': b.spawnBarCards.length,
            'overlaps': over,
          })}');
    }

    for (final spec in sizes.split(',')) {
      final [w, h] = [for (final n in spec.split('x')) double.parse(n)];
      tester.view.physicalSize = Size(w, h);

      // Between waves, Auto Wave on, its countdown running: a full army (not held), gold 5 digits, Auto Buy off.
      var g = b.state = Game().boardRules()..gold = 99999;
      while (!g.typeFull('soldier') && g.autoPlace('soldier')) {}
      await frames(tester, 40);
      b.autoStart
        ..set(true)
        ..won();
      await frames(tester, 40); // under a second: "Start 5" → "Start 4"
      await shot('$spec-a-countdown');

      // Held: one troop of six, the line under the toggle.
      g = b.state = Game().boardRules()..gold = 99999;
      await frames(tester, 40);
      b.autoStart.won();
      await frames(tester, 20);
      await shot('$spec-b-held');

      // Auto Buy on.
      g.setAutoReplace(true);
      await frames(tester, 3);
      await shot('$spec-c-autobuy-on');

      // A wave on (the book shut, the book button in the row).
      b.autoStart.cancel();
      g.startWave();
      await frames(tester, 40);
      await shot('$spec-d-wave');

      // A Town with Auto Wave on: "Leave town 5".
      g = b.state = Game(Random(1), Random(2)).boardRules()
        ..armyMax = null
        ..townDice = Random(3)
        ..gold = 99999
        ..wave = 5
        ..townAt = 7;
      g
        ..startWave()
        ..queue.clear()
        ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
      for (var i = 0; i < 600 && !g.inTown; i++) {
        await frames(tester, 1);
      }
      for (var i = 0; i < 120 && b.townFade > 0; i++) {
        await frames(tester, 1);
      }
      await frames(tester, 10);
      await shot('$spec-e-town');
      b.autoStart.set(false);
      b.state = Game();
      await frames(tester, 10);
    }

    // The landscape top band's width at each k (test/probe_hud_merge_width.dart's measure).
    for (final (k, h) in const [(2, 412.0), (3, 713.0), (4, 1080.0)]) {
      tester.view.physicalSize = Size(3000, h);
      b.autoStart.set(true);
      final g = b.state = Game()
        ..gold = 99999
        ..wave = 99;
      await frames(tester, 3);
      final start = b.toggleButton.width;
      g.startWave();
      await frames(tester, 3);
      final left = [b.troopCounter, b.heartsGoldPanel, b.bookButton].map((r) => r.right).reduce(max);
      final right = 3000 - b.speedButton.left, gap = 2 * b.hudScale;
      // ignore: avoid_print
      print('WIDTH k ${b.hudScale} (want $k): left $left start $start right $right needs ${left + gap + start + gap + right} '
          'auto ${b.autoButton.width}');
    }
    b.autoStart.set(false);
    b.state = Game();
    await frames(tester, 10);
  });
}

List<int> _r(Rect r) => [r.left.round(), r.top.round(), r.right.round(), r.bottom.round()];
