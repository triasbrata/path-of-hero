// The spawn bar as a hotbar on a step (decisions-log 287; ui-hud.md "Spawn bar"): offscreen shots into
// <probe root>/shots/army-hotbar/new (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_hotbar_shots.dart"]` with a mirror as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir).
//
// At each size (`SIZES`, default the owner's 1600x947, 1266x713, 1164x777 and 915x412): the w89 save mid-wave, the book
// shut, with two troops and a foe pushed to the lowest a unit stands (y 126) in the middle of the view; a fresh game
// between waves with the book open; the same with Auto on and the pointer on a slot (lit); and with the battle log
// open. A line `HOT {json}` a shot: the bar's pieces, the step's top, the lowest shadow on the screen, the book, the
// log's panel, the scale and the view's width.
import 'dart:convert';
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/army-hotbar/new');
const sizes = String.fromEnvironment('SIZES', defaultValue: '1600x947,1266x713,1164x777,915x412');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Game w89() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>,
    Random(89), Random(189), Random(389));

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
  testWidgets('hotbar shots', (tester) async {
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
      ..guideSeen = null
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
      var lowest = 0.0;
      for (final u in g.units) {
        if (u.alive) lowest = max(lowest, b.toScreen(u.pos.x, u.pos.y + 6).dy);
      }
      // ignore: avoid_print
      print('HOT ${jsonEncode({
            'shot': '$name.png',
            'area': _r(b.spawnBarArea),
            'list': _r(b.spawnBarList),
            'cards': [for (final (r, t) in b.spawnBarCards) '$t ${_r(r)}'],
            'per': b.spawnBarPerPage,
            'arrows': [_r(b.spawnBarArrows.$1), _r(b.spawnBarArrows.$2)],
            'room': _r(b.capacityButton),
            'auto': _r(b.autoReplaceButton),
            'log': _r(b.logButton),
            'logPanel': _r(b.logPanel),
            'book': _r(b.bookArea),
            'bookBtn': _r(b.bookButton),
            'panel': _r(b.spawnBarPanel),
            'stepLip': b.toScreen(0, stepLip).dy,
            'scale': b.toScreen(0, 1).dy - b.toScreen(0, 0).dy,
            'shadow132': b.toScreen(0, 132).dy,
            'lowestShadow': lowest,
            'top': b.toScreen(0, -backdropH).dy,
            'horizon': b.toScreen(0, 0).dy,
            'viewW': g.viewW,
          })}');
    }

    for (final spec in sizes.split(',')) {
      final [w, h] = [for (final n in spec.split('x')) double.parse(n)];
      tester.view.physicalSize = Size(w, h);
      // A wave: the w89 save mid-wave, two troops and a foe at the lowest a unit stands, mid-view.
      final g = b.state = w89();
      await frames(tester, 2);
      g.startWave();
      await frames(tester, 240);
      final mid = g.cam + g.viewW / 2;
      final troops = [for (final u in g.troops) if (u.alive) u]..sort((a, c) => (a.pos.x - mid).abs().compareTo((c.pos.x - mid).abs()));
      final foes = [for (final u in g.units) if (u.alive && u.side != Side.troop) u]
        ..sort((a, c) => (a.pos.x - mid).abs().compareTo((c.pos.x - mid).abs()));
      for (final u in [...troops.take(2), ...foes.take(1)]) {
        u.pos = Point(u.pos.x, fieldH - 2);
      }
      await frames(tester, 1);
      await shot('$spec-wave');
      // Between waves, the book open; then Auto on and the pointer resting on a slot.
      b.state = fresh();
      await frames(tester, 60);
      await shot('$spec-between');
      b.state.setAutoReplace(true);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: b.spawnCard('knight').center);
      await frames(tester, 40);
      await shot('$spec-between-lit');
      await mouse.moveTo(const Offset(2, 2));
      await frames(tester, 5);
      await mouse.removePointer();
      // The battle log open over it: never over the bar's controls.
      await tester.tapAt(b.logButton.center);
      await frames(tester, 5);
      await shot('$spec-between-log');
      await tester.tapAt(b.logButton.center);
      await frames(tester, 5);
    }
    await frames(tester, 10);
  });
}

List<int> _r(Rect r) => [r.left.round(), r.top.round(), r.right.round(), r.bottom.round()];
