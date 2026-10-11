// The Army page seen before and after its second rework (decisions-log 218; ui-hud.md "Army"): offscreen shots into
// <probe root>/shots/army-rework2/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_army_rework2_shots.dart"]` with a mirror as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir), and wins no wave. The before shots came from main with this file's first
// version, which tapped through the older getters only; this one turns the grid's pages (armyPage, armyPager), so it
// shoots the branch.
//
// At 412x860, 915x412, 1164x777 (the owner's tablet), 1266x713 and 777x1164 (`phone-` / `wide-` / `tablet-` /
// `desk-` / `tabletp-`): army (the wave-89 save, the first type alive picked), army-templar (picked: its Void Eye and
// relics on its troops), army-cap (the priests at their cap, 5/5, picked), army-armed (the axeman's Release armed),
// army-awaken (a soldier before Awaken 1, its six-item recipe, the Shop open, the Bag holding some), army-midwave (a
// wave begun; in landscape the book opened by hand).
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/army-rework2/after');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The middle of field cell ([c], [r]), as a fallen troop's spot.
Point<double> cellMiddle(int c, int r) => Point(c * tile + tile / 2, r * tile + tile / 2);

/// The wave-89 save; its Templars wear relics (a Fang, a Guard, Thorns).
Game load() {
  final g = Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>)
      .boardRules()
    ..chests.clear();
  final templars = [for (final u in g.troops) if (u.alive && u.type == 'knight_templar') u];
  for (final (i, r) in [Relic.fang, Relic.guard, Relic.thorns, Relic.fang].indexed) {
    if (i < templars.length && templars[i].relics.isEmpty) templars[i].relics.add(r);
  }
  return g;
}

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

/// A soldier before Awaken 1 (its six-item recipe: a sword and a shield given, the rest to find), the Shop open
/// (wave 16), the Bag holding the rest of its recipe (so "Awaken 1 from the Bag" shows) and a spare sword.
Game awaken() {
  final g = Game().boardRules()
    ..wave = 16
    ..gold = 9000
    ..capacity = 12;
  g.upgrades['soldier'] = [Item.sword, Item.shield];
  for (final (item, n) in [(Item.sword, 2), (Item.shield, 1), (Item.boots, 1), (Item.bow, 1), (Item.gloves, 1), (Item.potion, 1)]) {
    g.inventory[item] = n;
  }
  for (final type in ['soldier', 'soldier', 'archer']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  return g;
}

void main() {
  testWidgets('army rework2 shots', (tester) async {
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
      print('wrote $out/$name.png ${img.width}x${img.height}; picked ${b.troopPicked}, pages ${b.bookPages}, '
          'cells ${rows.length} first ${rows.firstOrNull} last ${rows.lastOrNull}, room ${b.capacityButton}, '
          'buy ${b.troopDetail('buy')}, release ${b.troopDetail('release')}, confirm ${b.releaseConfirm}, '
          'stats ${b.troopDetail('stats')}, next ${b.troopDetail('next')}, pusaka ${b.troopDetail('pusaka')}, '
          'relics ${b.troopDetail('relics')}, message ${b.message}');
    }

    Future<void> tap(Rect r) async {
      if (r == Rect.zero) return;
      await tester.tapAt(r.center);
      await frames(tester);
    }

    // A type's cell, the grid turned to its page first where it has a pager.
    Future<void> pick(String type) async {
      while (b.troopRow(type) == Rect.zero && b.armyPage > 0) {
        await tap(b.armyPager.$1);
      }
      while (b.troopRow(type) == Rect.zero && b.armyPage < b.armyPageCount - 1) {
        await tap(b.armyPager.$2);
      }
      await tap(b.troopRow(type));
    }

    for (final (tag, size) in const [
      ('phone', Size(412, 860)),
      ('wide', Size(915, 412)),
      ('tablet', Size(1164, 777)),
      ('desk', Size(1266, 713)),
      ('tabletp', Size(777, 1164)),
    ]) {
      tester.view.physicalSize = size;
      final g = b.state = load();
      await frames(tester, 50);
      if (b.messageBox != Rect.zero) await tap(b.messageBox);
      await shot('$tag-army');
      await pick('knight_templar');
      await shot('$tag-army-templar');
      await pick('armored_axeman');
      await tap(b.troopDetail('release'));
      await shot('$tag-army-armed');
      await pick('armored_axeman'); // lets Release go
      g.startWave();
      await frames(tester, 3);
      if (b.bookButton != Rect.zero) await tap(b.bookButton); // landscape: the book shuts in a wave, opened by hand
      await frames(tester, 40);
      await shot('$tag-army-midwave', 4);
      b.state = Game(); // leave no wave to win
      await frames(tester, 5);

      b.state = full();
      await frames(tester, 50);
      await pick('priest');
      await shot('$tag-army-cap');

      b.state = awaken();
      await frames(tester, 50);
      if (b.messageBox != Rect.zero) await tap(b.messageBox);
      await pick('soldier');
      await shot('$tag-army-awaken');
      b.state = Game();
      await frames(tester, 5);
    }
    await frames(tester, 10);
  });
}
