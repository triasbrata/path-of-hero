// The forge's cut-over (decisions-log 272): a behaviour probe, not a balance one, and its shots, offscreen into
// <probe root>/shots/forge-cutover/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_forge_cutover.dart"]` with a mirror as `dir`, no define (every board game's forge). It never touches
// the real save (flutter_test_config.dart's temp dir); the dice are seeded.
//
// A fresh board game (the forge with the Towns): waves 1 to 6 won, their monsters (the real queues) killed by four
// knights at 1 HP each as probe_forge_drops.dart does: no item ever drops, the materials pile up; then the Town before
// wave 7, where the Smithy crafts a grade-I item and the knights take it. At 1266x713 and 412x860 (<size>):
// smithy-<size> (that Town's Smithy, the Items tab on grade I, after the craft) and battle-<size> (wave 7 fought for
// `MID` s by a small army: the materials lying where monsters fell).
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hero_skill_helpers.dart';
import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/forge-cutover');
const seed = int.fromEnvironment('SEED', defaultValue: 5), mid = int.fromEnvironment('MID', defaultValue: 12);

int _sum(Map<Mat, int> m) => m.values.fold(0, (a, n) => a + n);

/// A fresh board game of [seed], the forge as the build has it, waves 1 to 6 won by four knights against the real
/// queues at 1 HP, then in the Town before wave 7 with one grade-I item crafted and given to the knights. Prints what
/// each wave dropped.
Game sixWavesAndACraft() {
  final g = Game(Random(seed), Random(seed + 100)).boardRules()
    ..heroes = Random(seed + 300)
    ..loot = Random(seed + 200)
    ..slots = Random(seed + 400)
    ..draft = Random(seed + 500)
    ..townDice = Random(seed + 600)
    ..matDice = Random(seed + 700)
    ..townPolicy = 'leave'
    ..skills = false
    ..heroSkills = false
    ..awakenSkills = false
    ..monsterSkills = false
    ..gold = 2000;
  expect((g.towns, g.byGrade), (true, true), reason: 'a board game plays the forge');
  final knights = [for (final r in [1, 3, 5, 7]) placeNow(g, 'knight', g.baseCol + deployCols - 1, r)];
  for (var w = 1; w <= 6; w++) {
    g.startWave();
    final spawn = [...g.queue];
    g.queue.clear();
    final foes = [
      for (final (i, (type, tier)) in spawn.indexed)
        foeAt(g, type, knights[i % knights.length].pos + Point(12.0, (i ~/ knights.length) * 0.01), tier)..hp = 1,
    ];
    for (var n = 0; n < 6000 && g.waveActive; n++) {
      g.tick(0.05);
    }
    expect(foes.where((u) => u.alive), isEmpty, reason: 'wave $w');
    expect((g.waveActive, g.over), (false, false), reason: 'wave $w won');
    expect([g.drops, g.lastLoot, g.inventory.keys], everyElement(isEmpty), reason: 'wave $w: no item drops with the forge');
    // ignore: avoid_print
    print('wave ${g.wave}: ${spawn.length} monsters, materials ${_sum(g.lastMaterials)} dropped, ${_sum(g.materials)} held '
        'in ${g.materials.length} kinds; items ${g.inventory.length}; seen ${g.matsSeen.length}');
  }
  expect(_sum(g.materials), greaterThan(0));
  // The Town before wave 7, whatever the roll said.
  g
    ..townPolicy = null
    ..townAt = g.wave + 1;
  expect(g.enterTown(), isTrue);
  final can = g.craftableItems(1), held = g.kindRecipe('knight').keys;
  // ignore: avoid_print
  print('Town before wave ${g.wave + 1}: gold ${g.gold}; grade I craftable ${[for (final i in can) itemNames[i]]}');
  final item = can.firstWhere((i) => held.contains(i.slot), orElse: () => can.first);
  final gold = g.gold;
  expect(g.craftItem(item), isTrue);
  expect((g.inventory[item], g.gold), (1, gold - g.itemRecipe(item)!.gold));
  if (held.contains(item.slot)) expect(g.useItem(item, 'knight'), isTrue);
  // ignore: avoid_print
  print('crafted ${itemNames[item]} (${g.itemRecipe(item)!.gold} gold): bag ${g.inventory}, knight ${g.upgrades['knight']}');
  return g;
}

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  test('a fresh board game: waves 1-6 drop no item and some materials; the Town before wave 7 crafts a grade-I item',
      sixWavesAndACraft);

  for (final size in const [Size(1266, 713), Size(412, 860)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('forge cut-over shots $tag', (tester) async {
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
        ..miniMapOpen = false
        ..autoStart.set(false);

      Future<void> shot(String name) async {
        await frames(tester, 20);
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = (await tester.runAsync(() => boundary.toImage()))!;
        final file = '$out/$name-$tag.png';
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File(file)
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        // ignore: avoid_print
        print('wrote $file; tab ${b.smithyTab} item ${b.smithyItem} (page ${b.smithyItemPage + 1}/${b.smithyItemPages}); '
            'message ${b.message}');
      }

      Future<void> quiet() async {
        if (b.messageBox != Rect.zero) {
          await tester.tapAt(b.messageBox.center);
          await frames(tester, 3);
        }
      }

      final g = b.state = sixWavesAndACraft();
      await frames(tester, 40);
      await quiet();
      await shot('smithy');

      // Wave 7, fought for real by a small army (the knights at full HP, and archers and priests), [mid] s in.
      expect(g.leaveTown(), isTrue);
      g
        ..skills = true
        ..monsterSkills = true
        ..gold = 1000000;
      for (var i = 0; i < 3; i++) {
        g.buyCapacity(); // room for five more beside the knights and the healer
      }
      for (final type in ['archer', 'archer', 'priest', 'knight', 'knight']) {
        g.autoPlace(type);
      }
      await frames(tester, 60);
      g.startWave();
      final end = g.t + mid;
      for (var i = 0; i < 200000 && g.t < end && g.waveActive && !g.over; i++) {
        b.update(1 / 30);
      }
      // ignore: avoid_print
      print('wave ${g.wave} at ${g.t.toStringAsFixed(1)} s: kills ${g.kills}, lying ${_sum(g.waveMaterials)} in '
          '${g.waveMaterials.length} kinds, items dropped ${g.drops.length}, active ${g.waveActive}');
      expect(g.drops, isEmpty);
      await frames(tester, 4);
      await shot('battle');
    });
  }
}
