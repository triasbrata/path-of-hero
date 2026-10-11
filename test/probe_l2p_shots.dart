// Batch L-2P seen (decisions-log 207; loot-items-relics.md "Pusaka"): offscreen shots of the ten new Langka Artifacts
// into <probe root>/shots/cat-L2P/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_l2p_shots.dart"]` with the worktree as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir), and wins no wave.
//
// On the owner's wave-89 save (the fixture), at wave 90: chest-<size>-<n> (four boss chests of three cards that deal
// the ten, n 1..4, at 412x860 and 1266x713); at 1266x713 bag-spellcutter (the Bag, Spell Cutter ★2 on the archers
// picked: its detail on the right page, the longest of the ten), army-templar (the Army page, the templars picked:
// their Watch Shield ★2) and field-ward (wave 91 begun: the templars' Watch Shield ★3, the guard's mark over each).
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/cat-L2P');

/// The ten, three a chest; the last chest's other two cards are older Langka.
const hands = [
  [Relic.momentum, Relic.bleedingEdge, Relic.shatterShard],
  [Relic.painCrystal, Relic.watchShield, Relic.boneBuckler],
  [Relic.riposte, Relic.manaLeech, Relic.lootersPouch],
  [Relic.spellCutter, Relic.ironBanner, Relic.warDrum],
];

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Game load() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>)
    .boardRules()
  ..chests.clear()
  ..wave = 90;

void main() {
  testWidgets('l2p shots', (tester) async {
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
      print('wrote $out/$name.png ${img.width}x${img.height}');
    }

    Future<void> tap(Offset p) async {
      await tester.tapAt(p);
      await frames(tester);
    }

    Future<void> page(String name) async {
      if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
      await tap(b.bookTabs.firstWhere((t) => t.$1 == name).$2.center);
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860))]) {
      tester.view.physicalSize = size;
      for (final (i, hand) in hands.indexed) {
        final g = b.state = load()..chests.add(Chest(ChestKind.boss, 90, cards: hand));
        await frames(tester, 3);
        await tap(const Offset(2, 2)); // the save's notes go, the popup stays
        // ignore: avoid_print
        print('chest ${i + 1}: ${g.chest?.cards}; cards ${b.chestCards}');
        await shot('chest-$tag-${i + 1}', 30);
      }
    }

    tester.view.physicalSize = const Size(1266, 713);
    b.state = load()
      ..givePusaka(Relic.spellCutter, type: 'archer', stars: 2)
      ..givePusaka(Relic.watchShield, type: 'knight_templar', stars: 2);
    await frames(tester, 30);
    await page('troops');
    await page('bag');
    await tap(b.bagSlot(Relic.spellCutter).center);
    await shot('bag-spellcutter', 30);
    await page('troops');
    await tap(b.troopRow('knight_templar').center);
    await shot('army-templar', 30);

    // The field: wave 91 begun with the templars' Watch Shield ★3, so each wears its shield's mark.
    final g = b.state = load()..givePusaka(Relic.watchShield, type: 'knight_templar', stars: 3);
    await frames(tester, 10);
    if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
    g.startWave();
    await frames(tester, 20);
    final warded = g.troops.where((u) => u.ward > 0).toList();
    // ignore: avoid_print
    print('warded ${warded.length}: ${warded.map((u) => '${u.type} ${u.ward.toStringAsFixed(1)}').join(', ')}');
    expect(warded, isNotEmpty);
    await shot('field-ward', 10);
    b.state = Game();
    await frames(tester, 10);
  });
}
