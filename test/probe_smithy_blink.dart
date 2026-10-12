// The Smithy's blinking material slots (decisions-log 277): a probe, not part of the suite (no `_test.dart`). Queue
// `["test", "test/probe_smithy_blink.dart"]` (`--plain-name <size>` for one size). It never touches the real save
// (flutter_test_config.dart's temp dir); the dice are seeded.
//
// At 1266x713, 1164x777, 915x412 and 412x860, the forge's Smithy is drawn for one whole bob of the
// book (the open book moves sin(clock 1.6) up and down: 3.93 s), a frame every 64 ms, nothing else changing. Each frame's
// layout is written relative to the left page (the materials' slots, rows, pager, the board's slot size, the "Materials"
// heading): a layout that changes while nothing changed in the game is the blink. It prints each scenario's distinct
// layouts with the frames they show in, and writes the left page of the first frame of each into `OUT`
// (blink-<scenario>-<size>-<n>.png).
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/smithy-items');
const steps = int.fromEnvironment('STEPS', defaultValue: 62), stepMs = int.fromEnvironment('STEP_MS', defaultValue: 64);

Game forgeGame({int wave = 20}) {
  final g = Game(Random(1), Random(2)).boardRules()
    ..townDice = Random(3)
    ..armyMax = null
    ..wave = wave;
  for (final type in ['soldier', 'knight', 'archer', 'priest']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g
    ..gold = 40000
    ..townAt = wave + 1
    ..inTown = true;
  return g;
}

void addMats(Game g, int kinds) {
  for (final (i, m) in Mat.values.where((m) => !m.crafted).take(kinds).indexed) {
    g.materials[m] = 1 + i * 5 % 13;
  }
}

String r1(double v) => v.toStringAsFixed(1);

/// The sweep's window sizes: [sweepW] wide, every [sweepStep] px of height from 400 to 1000.
const sweepW = String.fromEnvironment('SWEEP_W', defaultValue: '1266,1600'), sweepStep = int.fromEnvironment('SWEEP_STEP', defaultValue: 8);

void main() {
  for (final size in const [Size(1266, 713), Size(1164, 777), Size(915, 412), Size(412, 860), Size(1600, 947), Size(1600, 975)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('smithy blink $tag', (tester) async {
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

      Future<void> frames(int n, [int ms = 16]) async {
        for (var i = 0; i < n; i++) {
          await tester.pump(Duration(milliseconds: ms));
        }
      }

      Future<void> tap(Rect r) async {
        expect(r, isNot(Rect.zero));
        await tester.tapAt(r.center);
        await frames(3);
      }

      Future<void> shut() async {
        if (b.messageBox != Rect.zero) await tap(b.messageBox);
      }

      Future<void> leftShot(String name) async {
        final (left, _) = b.bookPages;
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = (await tester.runAsync(() => boundary.toImage()))!;
        await tester.runAsync(() async {
          final rec = ui.PictureRecorder();
          final c = Canvas(rec);
          final src = left.inflate(8).intersect(Offset.zero & size);
          c.drawImageRect(img, src, Offset.zero & src.size, Paint());
          final crop = await rec.endRecording().toImage(src.width.round(), src.height.round());
          final png = await crop.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
      }

      /// The left page's layout, its places relative to the board's first cell (both on whole pixels): what must not
      /// change while nothing changes in the game.
      String layout() {
        final slots = b.bagSlots, rows = {for (final s in slots) s.top}.length;
        final board = [...b.smithyItemCells.map((c) => c.$2), ...b.smithyCells.map((c) => c.$2), ...b.smithyEnhanceCells.map((c) => c.$2)];
        final o = board.isEmpty ? b.bookPages.$1.topLeft : board.first.topLeft;
        String rel(Rect r) => r == Rect.zero ? '-' : '${(r.left - o.dx).round()},${(r.top - o.dy).round()} ${r1(r.width)}x${r1(r.height)}';
        return 'mats ${slots.length} slots/$rows rows, ${b.bagCells.length} cells, per ${b.bagPageSizes}, '
            'page ${b.bagPage + 1}/${b.bagPages}, pager ${rel(b.bagPager('on'))}, first ${slots.isEmpty ? '-' : rel(slots.first)}, '
            'last ${slots.isEmpty ? '-' : rel(slots.last)}; board ${board.length} ${board.isEmpty ? '-' : rel(board.last)} '
            'small ${b.smithySmallBoard}';
      }

      Future<void> run(String name, Game g, {String? tab, Rect Function()? pick}) async {
        b.state = g;
        await frames(40);
        await shut();
        if (tab != null) await tap(b.smithyAt(tab));
        if (pick != null) await tap(pick());
        await shut();
        await frames(4);
        expect(b.bookPage, 'smithy');
        final seen = <String, List<int>>{};
        for (var i = 0; i < steps; i++) {
          await tester.pump(Duration(milliseconds: stepMs));
          final l = layout();
          final first = !seen.containsKey(l);
          (seen[l] ??= []).add(i);
          if (first && seen.length <= 3) await leftShot('blink-$name-$tag-${seen.length}');
        }
        // ignore: avoid_print
        print('$tag $name: ${seen.length} layout${seen.length == 1 ? '' : 's'}${seen.length > 1 ? ' BLINK' : ''}');
        for (final MapEntry(key: l, value: at) in seen.entries) {
          // ignore: avoid_print
          print('  ${at.length} frames (first ${at.first}): $l');
        }
      }

      await run('items-none', forgeGame());
      final g1 = forgeGame();
      addMats(g1, 27);
      await run('items-mats', g1);
      final g2 = forgeGame();
      addMats(g2, 27);
      await run('items-pick', g2, pick: () => b.smithyItemCells[3].$2);
      final g3 = forgeGame();
      addMats(g3, 27);
      await run('relics-mats', g3, tab: 'tab:relics');
      final g4 = forgeGame();
      await run('relics-none', g4, tab: 'tab:relics');
      final g5 = forgeGame(wave: 30);
      addMats(g5, 27);
      await run('enhance-mats', g5, tab: 'tab:enhance');
    });
  }

  // Window heights from 400 to 1000 at each width of [sweepW]: the Items tab (27 kinds of materials) and the Relics tab, a
  // bob sampled at 20 phases (196 ms apart: one 3.93-s bob); a size whose layout changes is listed.
  for (final w in sweepW.split(',').map(double.parse)) {
    testWidgets('smithy blink sweep ${w.round()}', (tester) async {
      tester.view
        ..physicalSize = Size(w, 713)
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
        ..miniMapOpen = false;
      b.autoStart.set(false);
      String layout() {
        final slots = b.bagSlots;
        final board = [...b.smithyItemCells.map((c) => c.$2), ...b.smithyCells.map((c) => c.$2)];
        final o = board.first.topLeft;
        return '${slots.length} slots ${b.bagPageSizes} ${b.bagPages}p ${b.bagPager('on') == Rect.zero ? '' : (b.bagPager('on').top - o.dy).round()} '
            '${slots.isEmpty ? '' : (slots.last.top - o.dy).round()} board ${board.last.width} ${(board.last.top - o.dy).round()}';
      }

      final g = forgeGame();
      addMats(g, 27);
      b.state = g;
      final blinks = <String>[];
      var n = 0;
      for (final tab in ['tab:items', 'tab:relics']) {
        for (var h = 400.0; h <= 1000; h += sweepStep) {
          tester.view.physicalSize = Size(w, h);
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          if (b.messageBox != Rect.zero) {
            await tester.tapAt(b.messageBox.center);
            await tester.pump(const Duration(milliseconds: 16));
          }
          if (b.smithyTab.name != tab.substring(4)) {
            await tester.tapAt(b.smithyAt(tab).center);
            await tester.pump(const Duration(milliseconds: 16));
          }
          final seen = <String>{};
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 393));
            seen.add(layout());
          }
          n++;
          if (seen.length > 1) blinks.add('${w.round()}x${h.round()} $tab: ${seen.join(' | ')}');
        }
      }
      // ignore: avoid_print
      print('sweep ${w.round()}: ${blinks.length} of $n sizes blink');
      for (final l in blinks) {
        // ignore: avoid_print
        print('  $l');
      }
    });
  }
}
