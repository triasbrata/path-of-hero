// The Smithy's seven small relics seen (decisions-log 227; lib/relics.dart): offscreen shots into
// <probe root>/shots/town-T3/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_relics_shots.dart"]` with the worktree as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir), and wins no wave. The relics are put in the bag by hand (the Smithy that makes
// them comes later), with the Towns on.
//
// It writes, at 1266x713 and 412x860 (`desk-` / `phone-`): each of the seven picked in the Bag (its facing page: the
// tier line, what it does, who it suits; the troops' rows with their relic slots), the Bag with nothing picked (blank:
// a Hero holding two of them, troops holding one), the Army page's detail of the soldiers (at its top, and
// scrolled to its Relics line: their relics' icons);
// on the desk also the tooltip of a relic's cell (its tier and "Best on") and of a relic on the Army detail.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui' show PointerDeviceKind;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/town-T3');

const seven = [Relic.cleave, Relic.venom, Relic.manaSiphon, Relic.spiritWard, Relic.lastStand, Relic.giantSlayer, Relic.blessing];

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game between waves at wave 30 with the Towns on, no army cap, gold to spare: two soldiers (one a Hero holding
/// Sweep and Iron Will, one holding Spirit Ward), a knight holding Holy Charm and the free priest holding Mana Siphon at
/// their posts; every small relic in the bag.
Game relicGame() {
  final g = Game(Random(1)).boardRules()
    ..towns = true
    ..armyMax = null
    ..gold = 5000000
    ..wave = 30;
  for (final type in ['soldier', 'soldier', 'knight']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  final soldiers = [for (final u in g.troops) if (u.type == 'soldier') u];
  soldiers.first
    ..hero = true
    ..relics.addAll([Relic.cleave, Relic.lastStand]);
  soldiers.last.relics.add(Relic.spiritWard);
  g.troops.firstWhere((u) => u.type == 'knight').relics.add(Relic.blessing);
  g.troops.firstWhere((u) => u.type == 'priest').relics.add(Relic.manaSiphon);
  for (final (i, r) in smallRelics.indexed) {
    g.relicBag[r] = 1 + i % 3;
  }
  return g;
}

void main() {
  testWidgets('relic shots', (tester) async {
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

    var n = 1;
    Future<void> shot(String name, [int settle = 20]) async {
      await frames(tester, settle);
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = (await tester.runAsync(() => boundary.toImage()))!;
      final file = '$out/${(++n).toString().padLeft(2, '0')}-$name.png';
      await tester.runAsync(() async {
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(file)
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
      // ignore: avoid_print
      print('wrote $file ${img.width}x${img.height}; picked ${b.picked}; tier "${b.bagDetailText('tier')}"; '
          'desc "${b.bagDetailText('desc')?.replaceAll('\n', ' / ')}"; tooltip ${b.tooltipShown}; '
          'army relics ${b.troopDetail('relics')}; message ${b.message}');
    }

    Future<void> tap(Offset p) async {
      await tester.tapAt(p);
      await frames(tester);
    }

    Future<void> quiet() async {
      if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
    }

    Future<void> page(String name) async {
      await quiet();
      await tap(b.bookTabs.firstWhere((t) => t.$1 == name).$2.center);
    }

    Future<void> start(Game g) async {
      b.state = g;
      await frames(tester, 50);
      await page('troops');
      await page('bag');
    }

    Future<void> pick(Enum kind) async {
      if (b.bagSlot(kind) == Rect.zero) {
        // ignore: avoid_print
        print('$kind: no cell on this page');
        return;
      }
      if (b.picked != kind) await tap(b.bagSlot(kind).center);
    }

    // The chip that shows only the relics: every small relic on its first page.
    Future<void> relicsChip() async {
      final chip = b.bagChip(BagCategory.relics);
      if (chip != Rect.zero) await tap(chip.center);
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860))]) {
      tester.view.physicalSize = size;
      await start(relicGame());
      await relicsChip();
      await shot('$tag-relics-none');
      for (final r in seven) {
        await pick(r);
        await shot('$tag-${r.name}');
      }
      if (tag == 'desk') {
        // A relic cell's tooltip (its tier and who it suits), Sweep's facing page beside it.
        await tap(b.bagSlot(Relic.cleave).center);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(b.bagSlot(Relic.giantSlayer).center);
        await frames(tester, 60);
        await shot('$tag-tip-giantSlayer', 2);
        await mouse.moveTo(Offset.zero);
        await mouse.removePointer();
        await frames(tester);
      }
      // The Army page's detail of the soldiers: their relics' icons.
      await page('troops');
      if (b.troopRow('soldier') != Rect.zero) await tap(b.troopRow('soldier').center);
      await shot('$tag-army-soldier');
      // Its Relics line is at the body's foot: scrolled to the end (clamped when drawn).
      b.troopDetailScroll = 1e6;
      await shot('$tag-army-soldier-relics');
      if (tag == 'desk' && b.troopDetail('relics') != Rect.zero) {
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
        await mouse.addPointer(location: Offset.zero);
        // The first icon right of "Relics:" (~46 px in at the desk's size), aimed again while the book settles.
        for (var i = 0; i < 4; i++) {
          final relics = b.troopDetail('relics');
          await mouse.moveTo(Offset(relics.left + 46, relics.center.dy));
          await frames(tester, 20);
        }
        await shot('$tag-army-tip', 2);
        await mouse.moveTo(Offset.zero);
        await mouse.removePointer();
        await frames(tester);
      }
    }
    b.state = Game();
    await frames(tester, 10);
  });
}
