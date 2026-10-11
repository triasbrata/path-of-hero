// The Army page's header seen (decisions-log 256, 260; ui-hud.md "Army"): offscreen shots into
// <probe root>/shots/val-army/new (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_army_header_shots.dart"]` with a mirror as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir), and wins no wave.
//
// It writes, at 1266x713 and 412x860 (`desk-` / `phone-`), on a new game with 4 troops in room for 6 (the owner's
// "4/6"): "+Room  40" normal; poor (gold 10: the footer's greyed button, whole); at the most (room for 32: "Room:
// max", greyed); the wave-89 save (the fixture: "48/36" red, "Room: max"); and the tooltip under the mouse
// ([Game.roomTip], last, so the pointer leaves the rest alone). Each line printed gives the button's and the counter's
// boxes, for a crop.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/val-army/new');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A new game on the board's rules, 150 gold, 4 troops alive in room for 6, all standing.
Game fresh() {
  final g = Game().boardRules()..gold = 1000;
  while (g.armySize < 4) {
    g.autoPlace('soldier');
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  return g..gold = 150;
}

Game w89() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>)
    .boardRules()
  ..chests.clear()
  // the limits' one-time notes marked seen: this army is over its cap and its types over theirs, and the notes'
  // plaques draw right over the header this probe looks at ([Game.limitNotes])
  ..notes.addAll(const {'army', 'over', 'caps'});

void main() {
  testWidgets('army header shots', (tester) async {
    tester.view
      ..physicalSize = const Size(1266, 713)
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

    Future<void> shot(String name, [int settle = 20]) async {
      await frames(tester, settle);
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
      print('wrote $out/$name.png ${img.width}x${img.height}; room ${b.capacityButton}, count ${b.armyCount}, '
          'title ${b.armyTitle}, tip ${b.tooltipBox}; capacity ${g.capacity} cap ${g.armyCap} alive ${g.armySize} '
          'gold ${g.gold} cost ${g.capacityCost} can ${g.canBuyCapacity} why ${g.whyNotCapacity}; '
          'replace ${b.replaceButton} release ${b.troopDetail('release')} buy ${b.troopDetail('buy')}');
    }

    // A mouse resting on +Room (the pointer added without a press, so no tap): its tooltip after the 0.25 s.
    Future<void> tip(String name) async {
      final h = await tester.createGesture(kind: PointerDeviceKind.mouse, pointer: 9);
      await h.addPointer(location: b.capacityButton.center);
      await h.moveTo(b.capacityButton.center);
      await frames(tester, 30);
      await shot(name, 2);
      await h.moveTo(const Offset(2, 2)); // off the book first: the tooltip and the hover go with the mouse
      await frames(tester, 10);
      await h.removePointer();
      await frames(tester, 3);
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860))]) {
      tester.view.physicalSize = size;
      final g = b.state = fresh();
      await frames(tester, 50);
      await shot('$tag-normal');
      await tip('$tag-tip');
      g.gold = 10;
      await shot('$tag-poor');
      await tip('$tag-tip-poor');
      g
        ..gold = 5000
        ..capacity = armyMaxBoard;
      await shot('$tag-max');
      await tip('$tag-tip-max');
      b.state = w89();
      await frames(tester, 50);
      await shot('$tag-w89');
    }
    await frames(tester, 10);
  });
}
