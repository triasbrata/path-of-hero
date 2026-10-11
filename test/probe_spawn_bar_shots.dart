// The spawn bar seen (decisions-log 283; ui-hud.md "Spawn bar"): offscreen shots into
// <probe root>/shots/spawn-bar/new (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_spawn_bar_shots.dart"]` with a mirror as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir).
//
// At each size (`SIZES`, default the owner's 1600x947 and a phone's 412x860): a new game on the board's rules with room
// for 20, five Priests (the type's cap: refused, "Priests full 5/5") and three Soldiers, and 140 gold (the Templar's 150
// is too poor); between waves with the book open (a phone's shut: it opens by hand), the same on the strip's last page
// with Auto on (where the cards page: a phone), and a wave on (landscape: the book shut). Each line printed gives the
// bar's row, its cards, strip, panel and arrows, the log button and the book, for a crop.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/spawn-bar/new');
const sizes = String.fromEnvironment('SIZES', defaultValue: '1600x947,412x860');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Game fresh() {
  final g = Game().boardRules()
    ..gold = 100000
    ..capacity = 20;
  for (var i = 0; i < 5; i++) {
    g.autoPlace('priest');
  }
  for (var i = 0; i < 3; i++) {
    g.autoPlace('soldier');
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  return g
    ..gold = 140
    ..notes.addAll(const {'army', 'over', 'caps'});
}

void main() {
  testWidgets('spawn bar shots', (tester) async {
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

    Future<void> shot(String name) async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = (await tester.runAsync(() => boundary.toImage()))!;
      await tester.runAsync(() async {
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
      final g = b.state;
      // ignore: avoid_print
      print('BAR ${jsonEncode({
            'shot': '$name.png',
            'w': img.width,
            'h': img.height,
            'row': _r(b.spawnBarArea),
            'cards': [for (final (r, t) in b.spawnBarCards) '$t ${_r(r)}'],
            'list': _r(b.spawnBarList),
            'panel': _r(b.spawnBarPanel),
            'room': _r(b.capacityButton),
            'auto': _r(b.autoReplaceButton),
            'arrows': [_r(b.spawnBarArrows.$1), _r(b.spawnBarArrows.$2)],
            'log': _r(b.logButton),
            'book': _r(b.bookArea),
            'gold': g.gold,
            'wave': g.waveActive,
            'lowestFeet': b.toScreen(0, fieldH - 2 + 5).dy,
            'normalShadow': b.toScreen(0, 126).dy,
          })}');
    }

    for (final spec in sizes.split(',')) {
      final [w, h] = [for (final n in spec.split('x')) double.parse(n)];
      tester.view.physicalSize = Size(w, h);
      b.state = fresh();
      await frames(tester, 60);
      await shot('$spec-between');
      b.state.setAutoReplace(true); // Auto lit
      b.spawnBarFirst = troopTypes.length; // on the last page: the back arrow lit (where the cards page)
      await frames(tester, 3);
      await shot('$spec-between-scrolled');
      b.spawnBarFirst = 0;
      b.state.startWave();
      await frames(tester, 60);
      await shot('$spec-wave');
    }
    await frames(tester, 10);
  });
}

List<int> _r(Rect r) => [r.left.round(), r.top.round(), r.right.round(), r.bottom.round()];
