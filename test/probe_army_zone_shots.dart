// The deploy zone at the army's most (decisions-log 260; camera-and-field.md "The deploy zone"): offscreen shots into
// <probe root>/shots/val-army/zone36 (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_army_zone_shots.dart"]` with a mirror as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir), and wins no wave.
//
// At 412x860 and 360x800 (portrait phones: 30% of the field held 4 and 3 columns, the zone now grows to 5) and 1266x713
// (6 columns, as before): a new game on the board's rules bought up to 36 troops, all placed between waves
// (`-between`), then a wave begun and a second in (`-wave`). Each line printed gives the view's width, the zone's
// columns, the troops alive and how many shared a cell, for the report.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/val-army/zone36');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('army zone shots', (tester) async {
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

    Future<void> shot(String name, Game g) async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = (await tester.runAsync(() => boundary.toImage()))!;
      await tester.runAsync(() async {
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
      final alive = g.troops.where((u) => u.alive).toList(), cells = {for (final u in alive) u.cell};
      // ignore: avoid_print
      print('wrote $out/$name.png ${img.width}x${img.height}; viewW ${g.viewW.toStringAsFixed(1)} zoneCols ${g.zoneCols} '
          'maxZoneCols ${g.maxZoneCols} (30%: ${(g.viewW * 0.3 / tile).floor()}) capacity ${g.capacity} maxCapacity '
          '${g.maxCapacity} armyCap ${g.armyCap} alive ${alive.length} cells ${cells.length} wave ${g.wave} active ${g.waveActive}');
    }

    for (final (tag, size) in const [('phone412', Size(412, 860)), ('phone360', Size(360, 800)), ('desk', Size(1266, 713))]) {
      tester.view.physicalSize = size;
      final g = b.state = Game().boardRules()
        ..gold = 1 << 20
        ..notes.addAll(const {'army', 'over', 'caps'});
      await frames(tester, 5); // the view's width from this window
      while (g.buyCapacity()) {}
      var refused = 0;
      for (final type in ['soldier', 'knight', 'swordsman', 'lancer']) {
        while (g.armySize < g.armyCap && g.buyRefusal(type) == null) {
          if (!g.autoPlace(type)) {
            refused++;
            break;
          }
        }
      }
      for (final u in g.troops) {
        u
          ..pos = u.post
          ..arriving = false;
      }
      // ignore: avoid_print
      print('$tag: bought to ${g.capacity}, ${g.armySize} alive, $refused refused (no free cell)');
      await frames(tester, 50);
      await shot('$tag-between', g);
      g.startWave();
      await frames(tester, 60); // a second in
      await shot('$tag-wave', g);
    }
    await frames(tester, 10);
  });
}
