// The pocket items on screen (decisions-log 332; ui-hud.md "The pocket bar"): offscreen shots into
// <probe root>/shots/pocket-items/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_pocket_shots.dart"]` with a mirror as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir); the dice are seeded.
//
// At 1600x947, 1266x713, 1164x777 and 915x412 (<size>), an army of six with the Shadows' two chips, the next Town marked,
// a Heal Bottle, a Rage Tonic, a Frost Bomb and a Pocket Watch (none left) in the bar: wave-<size> (in a wave, the Rage
// Tonic just used: its cooldown and its chip), map-<size> (the minimap open: what hangs under it keeps left of the bar),
// tip-<size> (the mouse on the Rage Tonic's slot), log-<size> (the battle log open over the bar), between-<size> (between
// waves, the book open: the bottles live, the rest greyed), bag-<size> (the Bag's Pocket chip, the Heal Bottle picked),
// smithy-<size> (a Town's Smithy, the Items tab's Pocket section, the Heal Bottle picked).
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/pocket-items');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game after wave 11, seeded: six troops, the Shadows' two chips, the next Town marked, gold, materials for a
/// few pocket items, and four kinds in the bar (the Pocket Watch none left).
Game pocketGame() {
  final g = Game(Random(seed), Random(seed + 100)).boardRules()
    ..seedDice(seed)
    ..armyMax = null
    ..gold = 4200
    ..wave = 11
    ..townAt = 13;
  for (final type in ['knight', 'knight', 'archer', 'priest', 'wizard', 'lancer']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.omens.addAll([OmenKind.values[0], OmenKind.values[1]]);
  g.materials.addAll({Mat.slimeGel: 11, Mat.tealCloth: 9, Mat.batWing: 3, Mat.orcTooth: 8});
  g.pocketStock.addAll({PocketKind.healBottle: 3, PocketKind.rageTonic: 2, PocketKind.frostBomb: 1});
  g.pocketSlots
    ..[0] = PocketKind.healBottle
    ..[1] = PocketKind.rageTonic
    ..[2] = PocketKind.frostBomb
    ..[3] = PocketKind.pocketWatch;
  return g;
}

void main() {
  for (final size in const [Size(1600, 947), Size(1266, 713), Size(1164, 777), Size(915, 412)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets(tag, (tester) async {
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
        ..guideSeen = null;
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
        print('wrote $out/$name-$tag.png bar ${b.pocketBar} slots ${b.pocketSlots} chips ${b.pocketChips} '
            'omens ${b.omenRow} town ${b.townChip} boosts ${b.boostChips} boss ${b.bossBars} map ${b.miniMap} '
            'meter ${b.waveMeter} book ${b.bookPages} log ${b.logPanel} msg ${b.message} tip ${b.tooltipShown} '
            'smithy "${b.smithyText('effect')}" / "${b.smithyText('tier')}" craft "${b.smithyText('craft')}" '
            'pocket head ${b.smithyAt('pocket')} pick ${b.smithyPocket} actions ${b.bagActions.map((a) => '${a.$1.name} ${a.$3}')}');
      }

      Future<void> tap(Rect r) async {
        expect(r, isNot(Rect.zero));
        await tester.tapAt(r.center);
        await frames(tester, 3);
      }

      Future<void> shut() async {
        if (b.messageBox != Rect.zero) await tap(b.messageBox);
      }

      Rect tab(String name) => [...b.bookTabTaps, ...b.bookTabs].firstWhere((t) => t.$1 == name).$2;

      // In a wave, the Rage Tonic just used.
      var g = b.state = pocketGame();
      await frames(tester, 3);
      g.startWave();
      await frames(tester, 220); // the first monsters come into view
      for (final u in g.troops) {
        u.hp = u.maxHp * 0.6; // hurt: the Heal Bottle would act
      }
      expect(g.usePocket(1), isTrue);
      await frames(tester, 60); // a second of its cooldown
      await shot('wave');
      b.miniMapOpen = true;
      await shot('map');
      b.miniMapOpen = false;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(b.pocketSlots[1].center);
      await shot('tip', 40);
      await mouse.moveTo(Offset(size.width / 2, size.height / 2));
      await frames(tester, 10);
      await tap(b.logButton);
      await shot('log');
      await tap(b.logButton);

      // Between waves, the book open.
      g = b.state = pocketGame();
      await frames(tester, 3);
      await shot('between', 60);

      // The Bag: its Pocket chip, the Heal Bottle picked.
      await tap(tab('bag'));
      await tap(b.bagChip(BagCategory.pocket));
      await tap(b.bagCells.firstWhere((c) => c.$1 == PocketKind.healBottle).$2);
      await shot('bag');

      // A Town's Smithy: the Items tab's Pocket section, the Heal Bottle picked.
      g = b.state = pocketGame()
        ..townAt = 12
        ..wave = 11;
      await frames(tester, 3);
      if (!g.inTown) expect(g.enterTown(), isTrue);
      await frames(tester, 60);
      await shut();
      await tap(b.smithyAt('tab:items'));
      while (b.smithyPocketCells.isEmpty && b.smithyItemPage < b.smithyItemPages - 1) {
        await tap(b.smithyItemPager('on'));
      }
      await tap(b.smithyPocketCells.firstWhere((c) => c.$1 == PocketKind.healBottle).$2);
      await shot('smithy');
      await frames(tester, 40);
    });
  }
}
