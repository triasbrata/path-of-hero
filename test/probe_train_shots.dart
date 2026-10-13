// Train seen (decisions-log 334, ui-hud.md "Army"): offscreen shots of the owner's wave-89 save (the fixture) with the
// axeman's three grade sets put on at +5 (Train open, a few levels bought) and the wizard's at +5 but four, into
// <probe root>/shots/train/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_train_shots.dart"]` with a mirror as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir), and wins no wave.
//
// At 1600x947 and 915x412 (`big-` / `wide-`): army (the Army tab, its dot), axeman (its detail scrolled to Train: the
// rows, prices, materials, Max), bought (after a tap on the HP row's price: the message, Lv 4), wizard (Train closed:
// "needs every item +5 (30/34)"), tip (the Dmg row's tooltip), archer (Train open, no Range row: its bows took it past
// one screen; Rate Max).
import 'dart:convert';
import 'dart:io';
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/train');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// [type]'s three grade sets put on at +5 in the save [j] (all but [short] of them at +5), as a real save holds them.
void fill(Map<String, dynamic> j, String type, {int short = 0}) {
  final sets = Game().trainItems(type);
  final items = [...((j['upgrades'] as Map)[type] as List? ?? const [])];
  final plus = <Map<String, Object>>[];
  var left = sets.values.fold(0, (a, n) => a + n) - short;
  for (final MapEntry(key: item, value: n) in sets.entries) {
    final have = items.where((i) => i == item.name).length;
    for (var k = have; k < n; k++) {
      items.add(item.name);
    }
    final at5 = n < left ? n : left;
    left -= at5;
    if (at5 > 0) plus.add({'item': item.name, 'plus': 5, 'n': at5});
  }
  (j['upgrades'] as Map)[type] = items;
  ((j['upgradePlus'] ??= <String, Object>{}) as Map)[type] = plus;
}

Game load() {
  final j = jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>;
  fill(j, 'armored_axeman');
  fill(j, 'wizard', short: 4);
  fill(j, 'archer');
  j['train'] = {
    'armored_axeman': {'hp': 3, 'power': 2, 'defence': 1, 'speed': 8},
  };
  j['gold'] = 900000;
  j['materials'] = {'bearClaw': 6, 'orcHeart': 4, 'ironTusk': 2, 'tealGem': 3, 'darkGem': 0, 'wolfFang': 5, 'wargFang': 1, 'boneBow': 7};
  return Game.fromJson(j).boardRules()..chests.clear();
}

void main() {
  testWidgets('train shots', (tester) async {
    tester.view
      ..physicalSize = const Size(1600, 947)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await loadHudFontNow();
    });
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
      print('wrote $out/$name.png ${img.width}x${img.height}; message ${b.message}; dot ${b.storeAt('armyDot')}');
    }

    Future<void> tap(Offset p) async {
      await tester.tapAt(p);
      await frames(tester);
    }

    /// Scrolls the detail's body so that its Train section's heading is at the body's top.
    Future<void> toTrain() async {
      await frames(tester, 3);
      for (var i = 0; i < 80 && b.troopDetail('train:hp') == Rect.zero; i++) {
        b.troopDetailScroll = b.troopDetailScroll + 10;
        await frames(tester, 2);
      }
      final hp = b.troopDetail('train:hp');
      b.troopDetailScroll = b.troopDetailScroll + hp.top - b.troopDetailBody.top - hp.height - 2;
      await frames(tester, 3);
      // ignore: avoid_print
      print('train words: ${[for (final s in TrainStat.values) '${s.name}=${b.troopDetailWords('train:${s.name}')}']} ${b.troopDetailWords('train')}');
    }

    for (final (tag, size) in const [('big', Size(1600, 947)), ('wide', Size(915, 412))]) {
      tester.view.physicalSize = size;
      final g = b.state = load();
      await frames(tester, 50);
      if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
      if (b.troopRow('priest') == Rect.zero) await tap(b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2.center);
      await shot('$tag-army');
      while (b.troopRow('armored_axeman') == Rect.zero && b.armyPager.$2 != Rect.zero) {
        await tap(b.armyPager.$2.center);
      }
      await tap(b.troopRow('armored_axeman').center);
      await toTrain();
      await shot('$tag-axeman');
      await tap(b.troopRow('wizard').center);
      await frames(tester, 3);
      for (var i = 0; i < 80 && !b.troopDetailWords('train').any((w) => w.startsWith('Train')); i++) {
        b.troopDetailScroll = b.troopDetailScroll + 10;
        await frames(tester, 2);
      }
      b.troopDetailScroll = b.troopDetailScroll + 40;
      await shot('$tag-wizard');
      // ignore: avoid_print
      print('$tag: wizard ${g.trainProgress('wizard')} ${b.troopDetailWords('train')}');
      await tap(b.troopRow('armored_axeman').center);
      await toTrain();
      final hp = b.troopDetail('train:hp');
      // ignore: avoid_print
      print('$tag: axeman open ${g.trainOpen('armored_axeman')}, hp ${g.statsOf('armored_axeman').hp}, why ${[for (final s in TrainStat.values) g.whyNotTrain('armored_axeman', s)]}');
      if (hp != Rect.zero) {
        await tap(Offset(hp.right - 6, hp.center.dy));
        await shot('$tag-bought', 4);
        // ignore: avoid_print
        print('$tag: hp level ${g.train['armored_axeman']}, gold ${g.gold}, bear claws ${g.materials[Mat.bearClaw]}');
        final row = b.troopDetail('train:power');
        if (row != Rect.zero) {
          final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
          await gesture.addPointer(location: Offset(row.left - 80, row.center.dy - 4));
          await gesture.moveTo(Offset(row.left - 60, row.center.dy));
          await frames(tester, 80);
          await shot('$tag-tip', 2);
          await gesture.removePointer();
        }
      }
      await tap(b.troopRow('archer') == Rect.zero ? b.armyPager.$1.center : b.troopRow('archer').center);
      if (b.troopRow('archer') != Rect.zero) await tap(b.troopRow('archer').center);
      await toTrain();
      await shot('$tag-archer');
      // ignore: avoid_print
      print('$tag: archer open ${g.trainOpen('archer')} ${b.troopDetailWords('train')}');
      b.state = Game();
      await frames(tester, 5);
    }
    await frames(tester, 10);
  });
}
