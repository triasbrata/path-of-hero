// The field's bottom padding (decisions-log 263): offscreen shots of the battle mid-wave with units in the last lanes,
// into <probe root>/shots/field-pad/ (`OUT`, `TAG` = before|after|...). A probe, not part of the suite (no
// `_test.dart`): queue `["test", "test/probe_field_pad_shots.dart", "--dart-define=TAG=after"]`. It never touches the
// real save (flutter_test_config.dart's temp dir).
//
// At 1266x713, 1164x777 (the owner's tablet), 915x412 and 412x860: a fresh game whose army stands in the last lanes
// (the camera at the near end) and the w89 save (the far end), each mid-wave. <TAG>-<w>x<h>-<near|far>.png, and a line
// `PAD {json}` a shot: the scale, where the field's bottom and the front edge's lip are on the screen (`LIP`, field
// y), and each unit's feet on the screen; then the lowest unit's y over the whole wave.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/field-pad');
const tag = String.fromEnvironment('TAG', defaultValue: 'after');
final lip = double.parse(const String.fromEnvironment('LIP', defaultValue: '121.6')); // field y of the front edge's top

Game low() {
  final g = Game(Random(7), Random(107))..gold = 900;
  for (final (type, col, row) in const [('knight', 2, 7), ('knight', 2, 6), ('archer', 1, 7), ('priest', 0, 6), ('lancer', 1, 5),
    ('soldier', 2, 5), ('armored_axeman', 0, 7)]) {
    g.place(type, col, row);
  }
  return g;
}

Game w89() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>,
    Random(89), Random(189), Random(389));

void main() {
  testWidgets('field pad shots $tag', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await loadHudFontNow();
    });
    tester.view.physicalSize = const Size(1266, 713);
    final game = TdGame();
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: GameWidget(game: game)));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue);
    final b = game.board
      ..miniMapOpen = false
      ..guideSeen = null
      ..welcome = null;

    Future<void> shot(String name) async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = (await tester.runAsync(() => boundary.toImage()))!;
      await tester.runAsync(() async {
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$tag-$name.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
      final g = b.state;
      final units = [
        for (final u in g.units)
          if (u.alive && u.pos.x > g.cam - tile && u.pos.x < g.cam + g.viewW + tile)
            [b.toScreen(u.pos.x, u.pos.y + 5).dx.roundToDouble(), b.toScreen(u.pos.x, u.pos.y + 5).dy, u.pos.y, u.side.name],
      ];
      // ignore: avoid_print
      print('PAD ${jsonEncode({
            'shot': '$tag-$name.png',
            'w': img.width,
            'h': img.height,
            'scale': b.toScreen(0, 1).dy - b.toScreen(0, 0).dy,
            'fieldBottom': b.toScreen(0, fieldH).dy,
            'screenBottom': b.size.y > b.size.x ? b.size.y * 0.42 : b.size.y, // the field's part of the screen
            'lip': b.toScreen(0, lip).dy,
            'units': units,
          })}');
    }

    for (final size in const [Size(1266, 713), Size(1164, 777), Size(915, 412), Size(412, 860)]) {
      tester.view.physicalSize = size;
      final s = '${size.width.round()}x${size.height.round()}';
      for (final (scene, make) in [('near', low), ('far', w89)]) {
        final g = b.state = make();
        await tester.pump(const Duration(milliseconds: 16));
        g.startWave();
        var lowest = 0.0;
        for (var i = 0; i < 300; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          for (final u in g.units) {
            if (u.alive) lowest = max(lowest, u.pos.y);
          }
        }
        await shot('$s-$scene');
        // ignore: avoid_print
        print('LOWEST $s-$scene ${lowest.toStringAsFixed(2)}');
      }
    }
  });
}
