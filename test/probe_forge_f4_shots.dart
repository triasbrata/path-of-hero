// The forge's nine small relics seen (decisions-log 250; lib/relics.dart): offscreen shots into
// <probe root>/shots/forge-F4/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_forge_f4_shots.dart"]` with a mirror as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir), and wins no wave. The relics are put in the bag by hand, with the Towns and the
// forge on.
//
// It writes, at 1266x713 and 412x860 (`desk-` / `phone-`): each of the nine picked in the Bag (its facing page: the tier
// line, its own effect, who it suits), the Army page's detail of the soldiers scrolled to their Relics line (a Hero
// holding Chill and Hot Streak), on the desk the tooltip of a relic on it, and the battle log open on a won wave's
// report with a row for each of the forge's relics that did something ("Shark Tooth: +1.2k damage").
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/forge-F4');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game between waves at wave 30 with the Towns and the forge on, no army cap, gold to spare: two soldiers (one
/// a Hero holding Chill and Hot Streak, one holding Avalanche), a knight holding Grit and the free priest holding Weak
/// Spot at their posts; every small relic in the bag; a won wave's report in the log.
Game relicGame() {
  final g = Game(Random(1)).boardRules()
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
    ..relics.addAll([Relic.chill, Relic.hotStreak]);
  soldiers.last.relics.add(Relic.avalanche);
  g.troops.firstWhere((u) => u.type == 'knight').relics.add(Relic.grit);
  g.troops.firstWhere((u) => u.type == 'priest').relics.add(Relic.weakSpot);
  for (final (i, r) in g.relicsInPlay.indexed) {
    g.relicBag[r] = 1 + i % 3;
  }
  g.log // as a win emits them: the report, then the win's line
    ..add(PusakaReport(29, 0, lines: const [], relics: const [
      (relic: Relic.chill, uses: 12, worth: 0),
      (relic: Relic.grit, uses: 18, worth: 310),
      (relic: Relic.weakSpot, uses: 9, worth: 812),
      (relic: Relic.hotStreak, uses: 26, worth: 540),
      (relic: Relic.avalanche, uses: 40, worth: 1234),
    ]))
    ..add(WaveEnded(29, 0, won: true));
  return g;
}

void main() {
  testWidgets('forge relic shots', (tester) async {
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

    var n = 0;
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
          'army relics ${b.troopDetail('relics')}; log ${b.logPanel}');
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

    // The chip that shows only the relics.
    Future<void> relicsChip() async {
      final chip = b.bagChip(BagCategory.relics);
      if (chip != Rect.zero) await tap(chip.center);
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860))]) {
      tester.view.physicalSize = size;
      await start(relicGame());
      await relicsChip();
      for (final r in forgeRelics) {
        await pick(r);
        await shot('$tag-${r.name}');
      }
      // The Army page's detail of the soldiers: their relics' icons at its foot.
      await page('troops');
      if (b.troopRow('soldier') != Rect.zero) await tap(b.troopRow('soldier').center);
      b.troopDetailScroll = 1e6;
      await shot('$tag-army-soldier-relics');
      if (tag == 'desk' && b.troopDetail('relics') != Rect.zero) {
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
        await mouse.addPointer(location: Offset.zero);
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
      // The battle log on the field, open, a wave on (the book shut): the won wave's report rows.
      await quiet();
      final lg = relicGame()..startWave(); // its monsters still to come: the wave stays on
      b.state = lg;
      await frames(tester, 30);
      if (b.logPanel == Rect.zero && b.logButton != Rect.zero) await tap(b.logButton.center);
      await shot('$tag-battle-log', 10);
      if (b.logPanel != Rect.zero) await tap(b.logButton.center); // folded again for the next size
    }
    b.state = Game();
    await frames(tester, 10);
  });
}
