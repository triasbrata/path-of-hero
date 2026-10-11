// Tempa seen (decisions-log 163, ui-hud.md "Army"): offscreen shots of the owner's wave-86 save (the fixture) with
// its three Bangkit 3 types raised to Bangkit 5 and given Tempa, into <probe root>/shots/tempa/ (`OUT`). A probe,
// not part of the suite (no `_test.dart`): queue `["test", "test/probe_tempa_shots.dart"]` with the worktree as `dir`.
// It never touches the real save (flutter_test_config.dart's temp dir), and wins no wave.
//
// It writes, at 1266x713 and 412x860 (`desk-` / `phone-`): pasukan (the "+n" after the stars, the Army tab's dot),
// wizard (its Army detail: "Forge +n  <price>"), bought (after one Tempa from that button, the message) and tas (a
// sword picked: the rows' "+n"). The Toko's Bangkit rows and their card (toko, tip) went in decisions-log 296.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/tempa');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The fixture at wave 86, its priest, axeman and wizard (Bangkit 3 from their items) bought up to Bangkit 5, with
/// Tempa +6, +2 and +14; a sword in the bag to pick on the Tas page.
Game load() {
  final j = jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>;
  j['ascended'] = {'priest': maxAscend, 'armored_axeman': maxAscend, 'wizard': maxAscend};
  j['tempa'] = {'priest': 6, 'armored_axeman': 2, 'wizard': 14}; // loaded before the troops, as a real save is
  final g = Game.fromJson(j).boardRules()..chests.clear();
  g.dismissPusakaNote();
  g.inventory[Item.sword] = (g.inventory[Item.sword] ?? 0) + 1;
  return g;
}

void main() {
  testWidgets('tempa shots', (tester) async {
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
      print('wrote $out/$name.png ${img.width}x${img.height}; marks ${b.tempaMarks}, dot ${b.storeAt('tokoDot')}, message ${b.message}');
    }

    Future<void> tap(Offset p) async {
      await tester.tapAt(p);
      await frames(tester);
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860))]) {
      tester.view.physicalSize = size;
      final g = b.state = load();
      await frames(tester, 50);
      if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
      if (b.troopRow('priest') == Rect.zero) await tap(b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2.center);
      await shot('$tag-pasukan');
      await tap(b.troopRow('wizard').center);
      await shot('$tag-wizard');
      await tap(b.troopDetail('upgrade').center);
      await shot('$tag-bought', 4);
      // ignore: avoid_print
      print('$tag: wizard Tempa ${g.tempa['wizard']}, gold ${g.gold}');
      await tap(b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
      await tap(b.bagSlot(Item.sword).center);
      await shot('$tag-tas');
      b.state = Game();
      await frames(tester, 5);
    }
    await frames(tester, 10);
  });
}
