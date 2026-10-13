// The Dungeon seen (decisions-log 336, 337; lib/dungeon_scene.dart, lib/dungeon_hud.dart, lib/dungeon_page.dart;
// docs/ui-hud.md "Dungeon"): offscreen shots into <probe root>/shots/dungeon/ (`OUT`), to look at beside the
// design's mockups (A: the band and the chain's steps; D: the door). A probe, not part of the suite (no `_test.dart`):
// queue `["test", "test/probe_dungeon_shots.dart"]` with the worktree as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir); the dice are seeded.
//
// At 1600x947 and 1266x713 as on the desk, and 915x412 as on a phone (<size>), a board game in its first Town with a
// mixed army: page-<size> (the book's Dungeon page), picked-<size> (a knight, an archer and a priest picked; the door at
// the street's far end left of the book), cave-<size> (just in: the arrival room, the save point), fight-<size> (the
// first room's monsters fighting the party: the live panel, the party panel, the target, the bars and numbers),
// step1-<size>, step2-<size>, step4-<size> (the Action chain in Wait), leave-<size> (the leader back at the save point,
// no monster hostile: Leave) and back-<size> (the Town again, "Back from the Dungeon").
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/dungeon');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A board game between waves at wave 7 with the Towns on, every roll hitting, seeded, a mixed army.
Game board() {
  final g = Game(Random(seed), Random(seed + 100)).boardRules()
    ..slots = Random(seed + 300)
    ..loot = Random(seed + 200)
    ..draft = Random(seed + 500)
    ..townDice = Random(seed + 600)
    ..townRules = TownRules.patch({
      'schedule': {'chanceStart': 1.0},
    })
    ..armyMax = null
    ..gold = 40000
    ..wave = 7;
  g.seedDice(seed);
  for (final type in ['knight', 'archer', 'priest', 'wizard', 'soldier', 'lancer']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  return g;
}

/// Wins the wave on (its monsters gone).
void win(Game g) {
  g
    ..startWave()
    ..queue.clear()
    ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
}

Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
  await simulateKeyDownEvent(k);
  await simulateKeyUpEvent(k);
  await frames(tester, 3);
}

void main() {
  for (final (size, platform) in const [
    (Size(1600, 947), TargetPlatform.macOS),
    (Size(1266, 713), TargetPlatform.macOS),
    (Size(915, 412), TargetPlatform.android),
  ]) {
    final tag = '${size.width.round()}x${size.height.round()}', touch = platform == TargetPlatform.android;
    testWidgets('dungeon shots $tag', (tester) async {
      debugDefaultTargetPlatformOverride = platform; // the HUD asks it every frame: the desk's layout or a phone's
      try {
        await shots(tester, size, tag, touch);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}

Future<void> shots(WidgetTester tester, Size size, String tag, bool touch) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(loadHudFontNow);
  final game = TdGame();
  final boundaryKey = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: boundaryKey, child: GameWidget(game: game)));
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
    final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = (await tester.runAsync(() => boundary.toImage()))!;
    await tester.runAsync(() async {
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name-$tag.png')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
    final g = b.state, d = g.dungeon;
    // ignore: avoid_print
    print('wrote $out/$name-$tag.png  page ${b.bookPage} trip ${d != null} step ${b.dungeonStep}/${b.dungeonPoint} '
        'k ${b.dungeonK} rows ${d == null ? 0 : g.liveRows().length} parts ${{
      for (final MapEntry(:key, :value) in b.dungeonParts.entries) key: '${value.left.round()},${value.top.round()} ${value.width.round()}x${value.height.round()}',
    }} taps<44 ${b.dungeonTaps.where((r) => r.width < 44 || r.height < 44).length} door ${b.townScene['dungeon']} sign ${b.townSign('dungeon')}');
  }

  Rect tab(String page) => b.bookTabs.firstWhere((t) => t.$1 == page).$2;

  // Wave 8 won: a Town before wave 10 marked; wave 9 won: the Town, after the cheer.
  final g = b.state = board();
  win(g);
  await frames(tester, 200);
  win(g);
  for (var i = 0; i < 600 && !g.inTown; i++) {
    await frames(tester, 1);
  }
  await frames(tester, 60);
  await tester.tapAt(tab('dungeon').center);
  await shot('page', 40);
  for (final type in ['knight', 'archer', 'priest']) {
    final u = g.troops.firstWhere((t) => t.type == type);
    final at = b.dungeonPage['troop:${u.name}']!;
    await tester.tapAt(at.center);
    await frames(tester, 2);
  }
  await shot('picked', 30);
  await tester.tapAt(b.dungeonPage['enter']!.center);
  await shot('cave', 40);
  final d = g.dungeon!;
  // In: the leader walks right (at its walk speed, 24 world units a second) until the first room's monsters are near,
  // then attacks the nearest, as a tap on it would (the gambits fight only the hostile ones); the fight runs 10 s (the
  // game ticked directly, its stick held).
  d.stick = const Point(1, 0.1);
  double? fightAt;
  for (var i = 0; i < 30 * 60 && g.dungeon != null; i++) {
    g.tick(1 / 30);
    final foes = [for (final u in g.units) if (u.side == Side.enemy && u.alive && g.t >= u.busyUntil) u]
      ..sort((a, b) => a.pos.distanceTo(d.leader.pos).compareTo(b.pos.distanceTo(d.leader.pos)));
    if (foes.isEmpty || foes.first.pos.distanceTo(d.leader.pos) > 140) continue;
    d.stick = const Point(0, 0);
    if (d.minds[d.leader]?.act == null) g.command(d.leader, ActKind.attack, foes.first);
    fightAt ??= g.t;
    if (g.t - fightAt > 10) break;
  }
  await shot('fight', 4);
  if (touch) {
    await tester.tapAt(b.dungeonParts['action']!.center);
    await shot('step1', 4);
    await tester.tapAt(b.dungeonParts['member:1']!.center);
    await shot('step2', 4);
    await tester.tapAt(b.dungeonParts['action:0']!.center);
    await shot('step4', 4);
    for (var i = 0; i < 3; i++) {
      if (b.dungeonStep > 0) await tester.tapAt(b.dungeonParts['back']!.center);
      await frames(tester, 3);
    }
  } else {
    await key(tester, LogicalKeyboardKey.enter);
    await key(tester, LogicalKeyboardKey.arrowDown);
    await shot('step1', 4);
    await key(tester, LogicalKeyboardKey.enter);
    await shot('step2', 4);
    await key(tester, LogicalKeyboardKey.enter);
    await shot('step4', 4);
    for (var i = 0; i < 3; i++) {
      await key(tester, LogicalKeyboardKey.escape);
    }
  }
  // Back to the save point, the monsters gone: Leave shows over the campfire.
  if (g.dungeon != null) {
    g.units.removeWhere((u) => u.side == Side.enemy);
    d.due.clear();
    for (final u in d.party) {
      u.pos = d.floor.savePoint + Point(10.0 + 14 * d.party.indexOf(u), 4.0);
    }
    for (var i = 0; i < 30; i++) {
      g.tick(1 / 30);
    }
    await shot('leave', 10);
    if (b.dungeonParts['leave'] case final r?) await tester.tapAt(r.center);
  }
  await shot('back', 60);
}
