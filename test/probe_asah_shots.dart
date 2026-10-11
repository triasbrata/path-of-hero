// Asah seen (decisions-log 154, ui-hud.md "Tas"): offscreen shots of the Tas page with a Pusaka picked on the owner's
// wave-86 save (the fixture), into <probe root>/shots/asah/ (`OUT`). A probe, not part of the suite (no
// `_test.dart`): queue `["test", "test/probe_asah_shots.dart"]` with the worktree as `dir`. It never touches the real
// save (flutter_test_config.dart's temp dir), and wins no wave.
//
// It writes, at 1266x713 and 412x860 (`desk-` / `phone-`): ready (Dragon Heart picked, the strip's "Asah ★2", the cost
// and the relics), armed ("Yakin?"), done (Bintang 2, the message), once (the Grail in the same boss interval: greyed,
// why in red), and on the desktop short (the gold short: the price in red).
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/asah');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Game load() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>);

void main() {
  testWidgets('asah shots', (tester) async {
    tester.view
      ..physicalSize = const Size(1266, 713)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await loadHudFontNow();
    });
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
      // ignore: avoid_print
      print('wrote $out/$name.png ${img.width}x${img.height}; Asah ${b.asahButton}, list ${b.assignList}, message ${b.message}');
    }

    Future<void> tap(Offset p) async {
      await tester.tapAt(p);
      await frames(tester);
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860))]) {
      tester.view.physicalSize = size;
      final g = b.state = load().boardRules()..chests.clear();
      g.dismissPusakaNote();
      await frames(tester, 50);
      if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
      await tap(b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
      await tap(b.bagSlot(Relic.dragonHeart).center);
      await shot('$tag-ready');
      await tap(b.asahButton.center);
      await shot('$tag-armed', 4);
      await tap(b.asahButton.center);
      await shot('$tag-done', 6);
      await tap(b.bagSlot(Relic.grail).center);
      await shot('$tag-once', 120); // the message gone
      if (tag == 'desk') {
        g
          ..asahAt = null
          ..gold = 50000;
        await shot('$tag-short', 4);
      }
    }
    await frames(tester, 10);
  });
}
