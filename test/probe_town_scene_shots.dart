// The Town scene seen (decisions-log 224; lib/town_scene.dart; ui-hud.md "Town"): offscreen shots into
// <probe root>/shots/town-T6a/ (`OUT`), to look at beside the design's mockups (town-<size>.png). A probe, not part
// of the suite (no `_test.dart`): queue `["test", "test/probe_town_scene_shots.dart"]` with the worktree as `dir`. It
// never touches the real save (flutter_test_config.dart's temp dir); the dice are seeded.
//
// At 1266x713, 915x412, 412x860 and 1164x777 (<size>), a board game with the Towns on, every roll hitting, a mixed army:
// fadein1-<size> (wave 8 won, ~0.2 s into the fade: the field dimming), fadein2-<size> (~0.5 s: the Town coming up),
// smithy-<size> (in the Town, the book on the Smithy), bag-<size>, settings-<size>, shop-<size> (the Shop's page from
// wave 15: the wave set to 20), shut-<size> (landscape: a tap on the scene shut the book, the whole Town), fadeout-<size>
// ("Leave town", ~0.2 s in) and field-<size> (back on the field, its book without the Shop tab).
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/town-T6a');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game between waves at wave 7 with the Towns on, every roll hitting, seeded, a mixed army.
Game board() {
  final g = Game(Random(seed), Random(seed + 100)).boardRules()
    ..slots = Random(seed + 300)
    ..loot = Random(seed + 200)
    ..draft = Random(seed + 500)
    ..townDice = Random(seed + 600)
    ..towns = true
    ..townRules = TownRules.patch({
      'schedule': {'chanceStart': 1.0},
    })
    ..armyMax = null
    ..gold = 40000
    ..wave = 7;
  for (final type in ['knight', 'archer', 'priest', 'wizard', 'soldier', 'lancer']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  return g;
}

/// A point on the Town's bare scene: under the HUD's band, left of the book, on no sign or place.
Offset bare(Board b, Size size) {
  final taken = [...b.townScene.entries.where((e) => !const {'scene', 'street'}.contains(e.key)).map((e) => e.value),
    for (final place in const ['smithy', 'tavern', 'shop']) b.townSign(place),
    b.bookArea, b.waveMeter, b.logButton, b.troopCounter];
  for (var y = b.waveMeter.bottom + 12; y < size.height - 8; y += 8) {
    for (var x = 8.0; x < (b.bookArea.isEmpty ? size.width : b.bookArea.left) - 8; x += 8) {
      final p = Offset(x, y);
      if (!taken.any((r) => r.inflate(4).contains(p))) return p;
    }
  }
  return const Offset(8, 8);
}

/// Wins the wave on (its monsters gone).
void win(Game g) {
  g
    ..startWave()
    ..queue.clear()
    ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
}

void main() {
  for (final size in const [Size(1266, 713), Size(915, 412), Size(412, 860), Size(1164, 777)]) {
    final tag = '${size.width.round()}x${size.height.round()}', phone = size.width < size.height;
    testWidgets('town scene shots $tag', (tester) async {
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

      Future<void> shot(String name, [int settle = 20]) async {
        await frames(tester, settle);
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = (await tester.runAsync(() => boundary.toImage()))!;
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name-$tag.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        // ignore: avoid_print
        print('wrote $out/$name-$tag.png  shown ${b.townShown} fade ${b.townFade.toStringAsFixed(2)} page ${b.bookPage} '
            'k ${b.townK} cam ${b.townCam.toStringAsFixed(1)} lane ${b.townLane} places ${[
          for (final p in ['tent', 'smithy', 'tavern', 'shop']) '$p ${b.townBuildingShape(p)} ${b.townScene[p]}',
        ]} signs ${[for (final p in ['smithy', 'tavern', 'shop']) b.townSign(p)]} spots ${[
          for (final s in ['guard', 'tent', 'smithy', 'tavernDoor', 'talk', 'shop']) '$s ${b.townSpot(s).dx}',
        ]}');
      }

      Rect tab(String page) => b.bookTabs.firstWhere((t) => t.$1 == page).$2;

      // Wave 8 won: a Town before wave 10 marked; wave 9 won: the Town, after the cheer.
      final g = b.state = board();
      win(g);
      await frames(tester, 200);
      win(g);
      for (var i = 0; i < 600 && !g.inTown; i++) {
        await frames(tester, 1);
      }
      await shot('fadein1', 12);
      await shot('fadein2', 18);
      await shot('smithy', 60);
      await tester.tapAt(tab('bag').center);
      await shot('bag', 40);
      await tester.tapAt(tab('settings').center);
      await shot('settings', 40);
      g
        ..wave = 20 // the Shop opens from wave 15
        ..townAt = 21;
      await frames(tester, 2);
      await tester.tapAt(tab('store').center);
      await shot('shop', 40);
      if (!phone) {
        // A tap on the bare sky left of the book: the book shuts, the whole Town shows.
        await tester.tapAt(bare(b, size));
        await shot('shut', 50);
        await tester.tapAt(b.townSign('smithy').center); // the sign opens the Smithy again
        await frames(tester, 40);
      }
      await tester.tapAt(b.startButton.center); // "Leave town"
      await shot('fadeout', 12);
      await shot('field', 80);
    });
  }
}
