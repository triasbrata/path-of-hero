// Carve (Ukir's UI, decisions-log 196; ui-hud.md "Tas") seen: offscreen shots into <probe root>/shots/carve/
// (`OUT`). A probe, not part of the suite (no `_test.dart`): queue `["test", "test/probe_carve_shots.dart"]` with the
// worktree as `dir`. It never touches the real save (flutter_test_config.dart's temp dir), and wins no wave. It uses
// only getters a checkout from before Carve has too (a tap on a part that isn't there is skipped), so the same file
// takes the before shots.
//
// It writes, at 1266x713, 412x860 and 915x412 (`desk-` / `phone-` / `wide-`): vault (the Grail in the Vault, Carve +2
// with 40 points on its bar, at wave 45), armed (its Carve tapped once), bound (Dragon Heart ★2+3 on the knight), give
// (a Potion picked, the list wheeled to the Give rows), refused (wave 30: Carve opens at wave 40), army (the Army page,
// the knight's detail: Dragon Heart's capsule); and at 1266x713 chest (a boss chest showing the Grail).
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/carve');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game between waves at [wave] (the Shop open), no army cap, gold to spare, a soldier and a knight beside the
/// free priest at their posts; a long run's bag, and Artifacts with Carve: Dragon Heart ★2+3 on the knight, the Grail
/// +2 (40 points on its bar) in the Vault, God's Thunder on the soldier, Oath of One.
Game carved({int wave = 45}) {
  final g = Game(Random(1)).boardRules()
    ..armyMax = null
    ..gold = 5000000
    ..wave = wave;
  for (final type in ['soldier', 'knight']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.inventory.addAll({Item.sword: 86, Item.shield: 14, Item.boots: 9, Item.bow: 3, Item.gloves: 12, Item.potion: 120, Item.staff: 40});
  g.relicBag.addAll({Relic.fury: 5, Relic.thorns: 12});
  g
    ..givePusaka(Relic.dragonHeart, type: 'knight', stars: 2, ukir: 3)
    ..givePusaka(Relic.grail, ukir: 2)
    ..givePusaka(Relic.godThunder, type: 'soldier')
    ..givePusaka(Relic.oathOfOne);
  g.pusaka[Relic.grail]!.feed = 40;
  return g;
}

void main() {
  testWidgets('carve shots', (tester) async {
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
      // ignore: avoid_print
      print('wrote $out/$name.png ${img.width}x${img.height}; picked ${b.picked}, message ${b.message}, '
          'carve ${b.bagDetail('carve')} ${b.bagDetailText('carve')}, give ${b.bagDetail('give')}');
    }

    Future<void> tap(Rect r) async {
      if (r == Rect.zero) return;
      await tester.tapAt(r.center);
      await frames(tester);
    }

    Future<void> quiet() async {
      if (b.messageBox != Rect.zero) await tap(b.messageBox);
    }

    Future<void> page(String name) async {
      await quiet();
      await tap(b.bookTabs.firstWhere((t) => t.$1 == name).$2);
    }

    Future<void> start(Game g) async {
      b.state = g;
      await frames(tester, 50);
      await page('troops');
      await page('bag');
    }

    Future<void> pick(Enum kind) async {
      await quiet();
      if (b.picked != kind) await tap(b.bagSlot(kind));
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860)), ('wide', Size(915, 412))]) {
      tester.view.physicalSize = size;
      await start(carved());
      await pick(Relic.grail);
      await shot('$tag-vault');
      await tap(b.bagDetail('carveBtn'));
      await shot('$tag-armed');
      await pick(Relic.dragonHeart);
      await shot('$tag-bound');
      await pick(Item.potion);
      final wheel = TestPointer(9, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(wheel.hover(b.assignList.center));
      for (var i = 0; i < 40; i++) {
        await tester.sendEventToBinding(wheel.scroll(const Offset(0, 60)));
        await frames(tester);
      }
      await tester.sendEventToBinding(wheel.hover(b.bookArea.topLeft));
      await shot('$tag-give');
      await start(carved(wave: 30));
      await pick(Relic.grail);
      await shot('$tag-refused');
      await start(carved());
      await page('troops');
      await tap(b.troopRow('knight'));
      await shot('$tag-army');
      if (tag == 'desk') {
        b.state = carved()..chests.add(Chest(ChestKind.boss, 50, cards: [Relic.grail, Relic.dragonHeart, Relic.bloodFang]));
        await frames(tester, 3);
        await tester.tapAt(const Offset(2, 2)); // the notes go, the popup stays
        await shot('$tag-chest', 30);
      }
      b.state = Game();
      await frames(tester, 5);
    }
    await frames(tester, 10);
  });
}
