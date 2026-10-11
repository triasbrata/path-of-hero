// The book's pages seen after the Army list's rework and the book's padding (decisions-log 198; ui-hud.md "Army", "The
// book's padding"): offscreen shots into <probe root>/shots/army-rework/ (`OUT`). A probe, not part of the suite
// (no `_test.dart`): queue `["test", "test/probe_army_rework_shots.dart"]` with a mirror as `dir`. It never touches the
// real save (flutter_test_config.dart's temp dir), and wins no wave. It taps only through getters older than the rework
// (troopRow, releaseChip, bookButton, bookTabs, bagSlot), so the same file shoots the pages before and after.
//
// At 1266x713, 412x860 and 915x412 (`desk-` / `phone-` / `wide-`), on the owner's wave-89 save (the fixture): army (the
// first type alive picked), army-templar (picked: its Void Eye), army-hover (the mouse on the knight's row), army-pressed
// (a press held on the archer's row), army-armed (the axeman's Release armed), army-poor (no gold), army-midwave (a wave
// begun; on desk the book opened by hand); on a full type army-locked (the priests at their cap, 5/5, picked: their
// forbidden sign; Replace fallen in the footer; before the type caps, decisions-log 201, the roster's 4/4 types); then bag (the sword picked: the grid and its detail) and settings (the field's Shop tab went in decisions-log 296).
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui' show PointerDeviceKind;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/army-rework/after');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The middle of field cell ([c], [r]), as a fallen troop's spot.
Point<double> cellMiddle(int c, int r) => Point(c * tile + tile / 2, r * tile + tile / 2);

Game load() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>)
    .boardRules()
  ..chests.clear();

/// A full type (decisions-log 201): the free priest and four more (5/5), a soldier, an archer and a knight; a soldier of
/// the last wave fell.
Game full() {
  final g = Game().boardRules()
    ..gold = 5000
    ..capacity = 12;
  for (final type in ['priest', 'priest', 'priest', 'priest', 'soldier', 'archer', 'knight']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.toReplace.add((type: 'soldier', post: cellMiddle(1, 1)));
  return g;
}

void main() {
  testWidgets('army rework shots', (tester) async {
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
      final rows = [for (final t in troopTypes.keys) b.troopRow(t)].where((r) => r != Rect.zero).toList();
      // ignore: avoid_print
      print('wrote $out/$name.png ${img.width}x${img.height}; picked ${b.troopPicked}, book ${b.bookArea}, '
          'rows ${rows.length} first ${rows.firstOrNull} last ${rows.lastOrNull}, room ${b.capacityButton}, '
          'card ${b.spawnCard(b.troopPicked)}, chip ${b.releaseChip(b.troopPicked)}, message ${b.message}');
    }

    Future<void> tap(Rect r) async {
      if (r == Rect.zero) return;
      await tester.tapAt(r.center);
      await frames(tester);
    }

    Future<void> page(String name) async {
      if (b.messageBox != Rect.zero) await tap(b.messageBox);
      final tab = b.bookTabs.where((t) => t.$1 == name).firstOrNull;
      if (tab != null) await tap(tab.$2);
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860)), ('wide', Size(915, 412))]) {
      tester.view.physicalSize = size;
      var g = b.state = load();
      await frames(tester, 50);
      if (b.messageBox != Rect.zero) await tap(b.messageBox);
      await shot('$tag-army');
      await tap(b.troopRow('knight_templar'));
      await shot('$tag-army-templar');
      final mouse = TestPointer(7, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(b.troopRow('knight').centerLeft + const Offset(40, 0)));
      await shot('$tag-army-hover', 3);
      await tester.sendEventToBinding(mouse.hover(b.bookArea.topLeft));
      final press = await tester.startGesture(b.troopRow('archer').centerLeft + const Offset(40, 0));
      await shot('$tag-army-pressed', 3);
      await press.cancel();
      await frames(tester);
      await tap(b.releaseChip('armored_axeman'));
      await shot('$tag-army-armed');
      await tap(b.troopRow('armored_axeman')); // lets Release go
      final gold = g.gold;
      g.gold = 0;
      await shot('$tag-army-poor');
      g.gold = gold;
      g.startWave();
      await frames(tester, 3);
      if (b.bookButton != Rect.zero) await tap(b.bookButton); // landscape: the book shuts in a wave, opened by hand
      await frames(tester, 40);
      await shot('$tag-army-midwave', 4);
      b.state = Game(); // leave no wave to win
      await frames(tester, 5);

      b.state = full();
      await frames(tester, 50);
      await tap(b.troopRow('priest'));
      await shot('$tag-army-locked');

      g = b.state = load();
      await frames(tester, 50);
      await page('bag');
      await tap(b.bagSlot(Item.sword));
      await shot('$tag-bag');
      // ignore: avoid_print
      print('$tag pages ${b.bookPages} bag page sizes ${b.bagPageSizes}'); // after only
      await page('settings');
      await shot('$tag-settings');
      await page('troops');
      b.state = Game();
      await frames(tester, 5);
    }
    await frames(tester, 10);
  });
}
