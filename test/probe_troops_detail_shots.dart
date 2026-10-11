// The Army page's right page, the picked type's detail (ui-hud.md "Army", decisions-log 187): offscreen shots into
// <probe root>/shots/troops-t2/after/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_troops_detail_shots.dart"]` with a mirror as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir), and wins no wave. It taps only through the getters the list had before the
// detail (troopRow, releaseChip, bookButton), so the same file shoots the page before and after.
//
// At 1266x713, 412x860 and 915x412 (`desk-` / `phone-` / `wide-`), on the owner's wave-89 save (the fixture) with a
// fallen Hero added: hero (the priest: a living Hero, Forge, the Fallen Heroes line), artifact (the wizard: God's
// Thunder, Awaken 5), forge (the axeman: the Grail, Forge +6), templar (its Void Eye, Awaken 3 from the Bag),
// recipe (the archer: Awaken 2, what Awaken 3 needs), armed (the axeman's Release armed), midwave (a wave begun, the
// axeman picked; on desk the book opened by hand); then with a full type: locked (the priests at their cap, 5/5,
// picked), fresh (the soldier, Awaken 0, before the Shop opens).
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/troops-t2/after');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The middle of field cell ([c], [r]), as a fallen troop's spot.
Point<double> cellMiddle(int c, int r) => Point(c * tile + tile / 2, r * tile + tile / 2);

/// The wave-89 save with a fallen priest Hero (the Shop's Fallen Heroes side has one).
Game load() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>)
    .boardRules()
  ..chests.clear()
  ..fallenHeroes.add(FallenHero(name: 'Kael', type: 'priest', stats: const [HeroStat.hp, HeroStat.power], fell: 88));

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
  testWidgets('army detail shots', (tester) async {
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
      print('wrote $out/$name.png ${img.width}x${img.height}; picked ${b.troopPicked}, '
          'stats ${b.troopRowStats(b.troopPicked)}, build ${b.rowBuildName(b.troopPicked)?.$1}, confirm ${b.releaseConfirm}');
    }

    Future<void> tap(Rect r) async {
      if (r == Rect.zero) return;
      await tester.tapAt(r.center);
      await frames(tester);
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860)), ('wide', Size(915, 412))]) {
      tester.view.physicalSize = size;
      final g = b.state = load();
      await frames(tester, 50);
      if (b.messageBox != Rect.zero) await tap(b.messageBox);
      await tap(b.troopRow('priest'));
      await shot('$tag-hero');
      await tap(b.troopRow('wizard'));
      await shot('$tag-artifact');
      await tap(b.troopRow('armored_axeman'));
      await shot('$tag-forge');
      await tap(b.troopRow('knight_templar'));
      await shot('$tag-templar');
      await tap(b.troopRow('archer'));
      await shot('$tag-recipe');
      await tap(b.releaseChip('armored_axeman'));
      await shot('$tag-armed');
      await tap(b.troopRow('armored_axeman')); // lets Release go
      g.startWave();
      await frames(tester, 3);
      if (b.bookButton != Rect.zero) await tap(b.bookButton); // landscape: the book shuts in a wave, opened by hand
      await frames(tester, 40);
      await shot('$tag-midwave', 4);
      b.state = Game(); // leave no wave to win
      await frames(tester, 5);

      b.state = full();
      await frames(tester, 50);
      await tap(b.troopRow('priest'));
      await shot('$tag-locked');
      await tap(b.troopRow('soldier'));
      await shot('$tag-fresh');
      b.state = Game();
      await frames(tester, 5);
    }
    await frames(tester, 10);
  });
}
