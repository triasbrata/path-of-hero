// The Towns' identities and their market seen (decisions-log 326; ui-hud.md "The Towns"): offscreen shots into
// <probe root>/shots/town-market/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_market_shots.dart"]` with the worktree as `dir` (`SIZES`: e.g. "1600x947,915x412"). It never
// touches the real save (flutter_test_config.dart's temp dir); the dice are seeded.
//
// At each size (<size>), for each identity's first Town (1 Millbrook, 2 Willowmere, 4 Ironvale, 5 Ambergate,
// 7 Frostgate, 8 Highspire; <key> its save key): arrive-<key>-<size> (a moment after going in: its name's ribbon, the
// book open on the Smithy), town-<key>-<size> (the book shut, the ribbon gone: the season's backdrop and street, the
// yard) and sell-<key>-<size> (the Shop's Sell page: a kind the Town wants "Hot in <name>", the Sword sold 20 times
// "Flooded"). It prints each Town's chip tooltip, its meter's words and the Sell page's prices.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/town-market');
const sizesArg = String.fromEnvironment('SIZES', defaultValue: '1600x947,915x412');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game after wave 30 with its [n]th Town marked before wave 31 (the Towns and the forge on): a mixed army,
/// 40,000 gold, items of every grade in the Bag (Boots, Swords I-III, a Sword +2, Tower Shields), the Sword sold
/// 20 times already.
Game marketGame(int n) {
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
  final swords = [for (final i in Item.values) if (i.slot == ItemSlot.sword) i];
  g.inventory.addAll({Item.boots: 3, for (final s in swords) s: 2, Item.towerShield: 2});
  g.enhancedBag[(Item.sword, 2)] = 1;
  g.market[g.marketKey(Item.sword)] = 20;
  return g;
}

void main() {
  final sizes = [
    for (final s in sizesArg.split(','))
      Size(double.parse(s.split('x')[0]), double.parse(s.split('x')[1])),
  ];
  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('market shots $tag', (tester) async {
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
        print('wrote $out/$name-$tag.png  ribbon ${b.townArrival} meter "${b.townMeterText}"');
      }

      Future<void> tapOn(Rect r) async {
        await tester.tapAt(r.center);
        await frames(tester, 3);
      }

      for (final n in const [1, 2, 4, 5, 7, 8]) {
        final g = marketGame(n), who = identityOf(n);
        // ignore: avoid_print
        print('Town $n ${who.key}: tip ${g.townTip}');
        // The board takes the game with no Town due (so it fades into it as it comes), then the Town comes.
        b.state = g..townAt = null;
        await frames(tester, 4);
        g.townAt = 31;
        for (var i = 0; i < 100 && !g.inTown; i++) {
          await frames(tester, 1);
        }
        expect((g.townCount, g.townIdentity.key, g.sceneIdentity.key), (n, who.key, who.key));
        await shot('arrive-${who.key}', 70);
        if (b.messageBox != Rect.zero) await tapOn(b.messageBox);
        await tester.tapAt(Offset(size.width * 0.12, size.height * 0.3)); // the bare sky: the book shuts
        await shot('town-${who.key}', 200);
        // The Shop's Sell page, by the book's tab (a tap on the Shop's sign opens the book there).
        await tapOn(b.townSign('shop'));
        await frames(tester, 30);
        if (b.messageBox != Rect.zero) await tapOn(b.messageBox);
        await tapOn(b.shopTabAt(ShopTab.sell));
        await shot('sell-${who.key}', 30);
        // ignore: avoid_print
        print('  prices: ${[
          for (final i in g.inventory.keys) '${itemNames[i]} ${g.sellPrice(i)} (x${g.marginOf(i).toStringAsFixed(2)}, '
              'hpp ${g.hppOf(i)}, ${g.marketWord(i)?.name ?? '-'})',
          'Sword +2 ${g.sellPriceAt(Item.sword, 2)}',
        ].join('; ')}');
        g.leaveTown();
        await frames(tester, 60);
      }
    });
  }
}
