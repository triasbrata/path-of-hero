// The Shop's Sell tab with what the Town is looking for (decisions-log 335; ui-hud.md "The Town's Shop"): offscreen shots
// into <probe root>/shots/town-wants/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_town_wants_shots.dart"]` with the worktree as `dir` (`SIZES`: e.g. "1600x947,915x412"). It never
// touches the real save (flutter_test_config.dart's temp dir); the dice are seeded.
//
// At each size (<size>), in Millbrook (Town 1), Ironvale (4) and Frostgate (7) (<key> its save key): sell-<key>-<size>
// (the Sell tab: High demand, then Items in Bag; the basket empty), demand-<key>-<size> (a High demand product the Bag
// doesn't hold picked: its demand, Add to wishlist, "None in your Bag."), wished-<key>-<size> (its Add to wishlist
// tapped: "On wishlist", the star on its cell), held-<key>-<size> (a held one picked: into the basket, the price row)
// and, where the board pages (915x412), page2-<key>-<size>. It prints what each shot shows.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/town-wants');
const sizesArg = String.fromEnvironment('SIZES', defaultValue: '1600x947,1266x713,1164x777,915x412');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game after wave 30 with its [n]th Town marked before wave 31: a mixed army, 40,000 gold, the early
/// materials seen, and in the Bag some of every identity's kinds (Boots and Swift Boots, Prayer Beads, Swords, Tower
/// Shields, a Leather Cap, a Ring, a Gold Amulet) and a few materials.
Game wantsGame(int n) {
  final g = Game(Random(1), Random(2)).boardRules()
    ..townDice = Random(3)
    ..armyMax = null
    ..gold = 40000
    ..wave = 30
    ..townAt = 31
    ..townCount = n - 1;
  for (final type in ['knight', 'archer', 'priest', 'soldier']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.inventory.addAll({
    Item.boots: 2,
    Item.swiftBoots: 1,
    Item.prayerBeads: 1,
    Item.sword: 3,
    Item.towerShield: 2,
    Item.leatherCap: 1,
    Item.ring: 1,
    Item.goldAmulet: 1,
  });
  g.materials.addAll({Mat.wolfClaw: 4, Mat.slimeGel: 9, Mat.boneShard: 6, Mat.orcTooth: 3, Mat.batWing: 5});
  g.matsSeen.addAll([Mat.slimeGel, Mat.batWing, Mat.boneShard, Mat.orcTooth, Mat.boneArrow, Mat.wolfClaw, Mat.rustyPlate, Mat.leatherStrap]);
  return g;
}

Game? g0;

void main() {
  final sizes = [
    for (final s in sizesArg.split(','))
      Size(double.parse(s.split('x')[0]), double.parse(s.split('x')[1])),
  ];
  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('town wants shots $tag', (tester) async {
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
        print('wrote $out/$name-$tag.png  heads ${[for (final h in ['High demand', 'Items in Bag']) '$h ${b.shopAt('head:$h')}']} '
            'page ${b.bagPage}/${b.bagPages} pick ${b.shopPickAt} basket ${b.shopBasket}\n'
            '  demand ${[for (final (l, r) in b.shopDemandCells) '${l.kind.name} ${g0!.sellPrice(l.kind)} ${r.left},${r.top}']}\n'
            '  detail kind "${b.shopText('kind')}" demand "${b.shopText('demand')}" wish "${b.shopText('wish')}" at ${b.shopAt('wish')} '
            'none "${b.shopText('none')}" price "${b.shopText('price')}" desc "${b.shopText('desc')}"');
      }

      Future<void> tapOn(Rect r) async {
        await tester.tapAt(r.center);
        await frames(tester, 3);
      }

      for (final n in const [1, 4, 7]) {
        final g = wantsGame(n), who = identityOf(n);
        // The board takes the game with no Town due (so it fades into it as it comes), then the Town comes.
        b.state = g..townAt = null;
        await frames(tester, 4);
        g.townAt = 31;
        for (var i = 0; i < 100 && !g.inTown; i++) {
          await frames(tester, 1);
        }
        expect((g.townCount, g.townIdentity.key), (n, who.key));
        await frames(tester, 70);
        if (b.messageBox != Rect.zero) await tapOn(b.messageBox);
        await tapOn(b.bookTabs.firstWhere((t) => t.$1 == 'store').$2);
        await tapOn(b.shopTabAt(ShopTab.sell));
        g0 = g;
        await shot('sell-${who.key}', 30);
        // A High demand product the Bag doesn't hold, then its Add to wishlist; then a held one.
        final cells = b.shopDemandCells;
        final none = cells.where((c) => g.inventory[c.$1.kind] == null).firstOrNull;
        if (none != null) {
          await tapOn(none.$2);
          await shot('demand-${who.key}', 10);
          if (n == 1) {
            await tapOn(b.shopAt('wish'));
            if (b.messageBox != Rect.zero) await tapOn(b.messageBox);
            await shot('wished-${who.key}', 10);
          }
        }
        final held = b.shopDemandCells.where((c) => g.inventory[c.$1.kind] != null).firstOrNull;
        if (held != null) {
          await tapOn(held.$2);
          await shot('held-${who.key}', 10);
        }
        if (b.bagPages > 1) {
          await tapOn(b.bagPager('on'));
          await shot('page2-${who.key}', 10);
        }
        await tester.tapAt(Offset(size.width * 0.12, size.height * 0.5)); // the bare sky: the book shuts
        await frames(tester, 20);
        g.leaveTown();
        await frames(tester, 60);
      }
    });
  }
}
