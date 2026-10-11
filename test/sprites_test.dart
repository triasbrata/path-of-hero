import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

// The sprites the game builds in memory at load (TdGame.onLoad): a widget test, since it needs the asset
// bundle and image decoding. Pure rules are tested in game_test.dart.

/// The pack's shadow colour: the Soldier's strips have it baked into rows 55-59 (assets.md).
const shadowInk = (83, 69, 69), shadowRows = (55, 59);
const anims = ['idle', 'walk', 'attack', 'hurt', 'death'];

/// How many visible pixels of [img] are the shadow colour in the shadow rows.
Future<int> shadowPixels(WidgetTester tester, ui.Image img) async {
  final px = (await tester.runAsync(() => img.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  var n = 0;
  for (var y = shadowRows.$1; y <= shadowRows.$2; y++) {
    for (var x = 0; x < img.width; x++) {
      final i = (y * img.width + x) * 4;
      if (px.getUint8(i + 3) != 0 && (px.getUint8(i), px.getUint8(i + 1), px.getUint8(i + 2)) == shadowInk) n++;
    }
  }
  return n;
}

void main() {
  testWidgets('every troop is drawn with one shadow: the Soldier\'s baked-in one is cleared at load', (tester) async {
    // The file still has it, so this test would catch it coming back.
    final file = (await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec((await rootBundle.load('assets/images/tiny_soldier_idle.png')).buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    }))!;
    expect(await shadowPixels(tester, file), greaterThan(0));

    final game = TdGame();
    await tester.pumpWidget(GameWidget(game: game));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      // onLoad decodes images in real time: let it run, then pump.
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue);
    // What the field draws (a troop, and the ghost of one being dragged: its idle strip).
    for (final type in troopTypes.keys) {
      // Its skill strips too (skill_strips.dart, decisions-log 299).
      for (final a in [...anims, for (final (t, a) in skillStripFiles()) if (t == type && !anims.contains(a)) a]) {
        expect(await shadowPixels(tester, game.images.fromCache('tiny_${type}_$a.png')), 0, reason: '$type $a');
      }
      // The one shadow it keeps: its shadow file, drawn on the ground under it.
      expect(await shadowPixels(tester, game.images.fromCache('tiny_${type}_shadow.png')), greaterThan(0), reason: type);
    }
  });
}
