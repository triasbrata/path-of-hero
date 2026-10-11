// Two small looks (decisions-log 292), offscreen into <probe root>/shots/room-tent/ (`OUT`, `TAG` before each
// name: "before", "after"). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_room_tent_shots.dart"]` with a worktree or mirror as `dir` (`--dart-define=PART=room` or `tent`
// for one part). It never touches the real save (flutter_test_config.dart's temp dir); every dice is seeded.
// - room-<size> (1600x947, 915x412): the spawn bar's +Room greyed too poor and at the most, each with the message its tap
//   says, and its tooltip under the mouse while it buys and while greyed; the whole screen and the bar's left 3x.
// - tent-<size> (1600x947, 1266x713): each troop type resting in the tent's opening (its slot +0), one of its own kind on
//   the street by it at depth 0, 4x round the tent's foot (tent-<type>-<size>) and all nine on one sheet 2x
//   (tent-all-<size>); a guest in the Tavern's doorway and the smith on his porch 4x (porch-<size>), to compare. Each
//   line printed gives the lane, the hem's top (the lane less townTentStep world px) and where each one's soles end.
// - bag-<size>, sell-<size> (1600x947, 915x412): the empty Bag with the Towns and the forge on (what drops: materials,
//   and the Smithy makes items) and the Town Shop's empty Sell grid; the whole screen and the book 2x.
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

import 'bag_grid_test.dart' show bagGame, openBag;
import 'forge_shop_ui_test.dart' show forgeGame, turnTo;
import 'hud_font.dart';
import 'town_hud_test.dart' show townGame;
import 'town_life_test.dart' show ScriptDice;
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/room-tent');
const tag = String.fromEnvironment('TAG', defaultValue: 'after');
const part = String.fromEnvironment('PART');

/// The troop types that rest in the tent: every one (the army's types).
const types = ['soldier', 'knight', 'swordsman', 'archer', 'lancer', 'priest', 'armored_axeman', 'wizard', 'knight_templar'];

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  late GlobalKey key;

  Future<Board> boot(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadHudFontNow);
    final game = TdGame();
    key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: GameWidget(game: game)));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue);
    return game.board
      ..welcome = null
      ..miniMapOpen = false;
  }

  Future<ui.Image> grab(WidgetTester tester) async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return (await tester.runAsync(() => boundary.toImage()))!;
  }

  /// [src] of [img] at [z] times, nearest neighbour.
  Future<ui.Image> zoom(WidgetTester tester, ui.Image img, Rect src, double z) async {
    final rec = ui.PictureRecorder(), w = (src.width * z).round(), h = (src.height * z).round();
    Canvas(rec).drawImageRect(img, src, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..filterQuality = FilterQuality.none);
    return (await tester.runAsync(() => rec.endRecording().toImage(w, h)))!;
  }

  /// [parts] side by side, [cols] a row, 8 px apart on grey.
  Future<ui.Image> sheet(WidgetTester tester, List<ui.Image> parts, int cols) async {
    final pw = parts.first.width, ph = parts.first.height, rows = (parts.length + cols - 1) ~/ cols;
    final w = cols * (pw + 8) + 8, h = rows * (ph + 8) + 8, rec = ui.PictureRecorder(), c = Canvas(rec);
    c.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = const Color(0xFF808080));
    for (final (i, p) in parts.indexed) {
      c.drawImage(p, Offset(8.0 + (i % cols) * (pw + 8), 8.0 + (i ~/ cols) * (ph + 8)), Paint());
    }
    return (await tester.runAsync(() => rec.endRecording().toImage(w, h)))!;
  }

  Future<void> save(WidgetTester tester, ui.Image img, String name) async {
    await tester.runAsync(() async {
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$tag-$name.png')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
    // ignore: avoid_print
    print('wrote $out/$tag-$name.png');
  }

  for (final size in const [Size(1600, 947), Size(915, 412)]) {
    final s = '${size.width.round()}x${size.height.round()}';
    if (part.isNotEmpty && part != 'room') continue;
    testWidgets('+Room greyed and its tooltip $s', (tester) async {
      final b = await boot(tester, size);
      b.autoStart.set(false);
      Future<void> shoot(String name) async {
        final img = await grab(tester), bar = b.spawnBarArea;
        await save(tester, img, 'room-$name-$s');
        final left = Rect.fromLTRB(0, max(0, bar.top - 140), min(size.width, b.spawnBarPanel.left + 60), size.height);
        await save(tester, await zoom(tester, img, left, 3), 'room-$name-zoom-$s');
        // ignore: avoid_print
        print('$name $s: message ${b.message} | tooltip ${b.tooltipShown} | words ${b.spawnBarRoomWords.map((e) => e.$1)} '
            '| face ${b.spawnBarRoomFace} press ${b.capacityButton}');
      }

      // Too poor: 20 gold for the next 40.
      final g = b.state = Game().boardRules()
        ..towns = false
        ..gold = 20;
      await frames(tester, 40);
      await tester.tapAt(b.capacityButton.center);
      await frames(tester, 6);
      await shoot('poor');
      await frames(tester, 140);
      // At the most.
      g
        ..gold = 5000
        ..capacity = g.maxCapacity;
      await frames(tester, 10);
      await tester.tapAt(b.capacityButton.center);
      await frames(tester, 6);
      await shoot('max');
      await frames(tester, 140);
      // Its tooltip under the mouse: buys, then too poor, then at the most.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      for (final (name, gold, cap) in [('tip-buys', 5000, 20), ('tip-poor', 20, 20), ('tip-max', 5000, g.maxCapacity)]) {
        g
          ..gold = gold
          ..capacity = cap;
        await mouse.moveTo(const Offset(2, 2));
        await frames(tester, 10);
        await mouse.moveTo(b.capacityButton.center);
        await frames(tester, 40);
        await shoot(name);
      }
      await mouse.moveTo(const Offset(2, 2));
      await frames(tester, 10);
      await mouse.removePointer();
      b.state = Game();
      await frames(tester, 10);
    });
  }

  for (final size in const [Size(1600, 947), Size(1266, 713)]) {
    final s = '${size.width.round()}x${size.height.round()}';
    if (part.isNotEmpty && part != 'tent') continue;
    testWidgets('the tent\'s resting troops $s', (tester) async {
      final b = await boot(tester, size)..townDice = ScriptDice(); // every roll a stroll, depth 0
      b.autoStart.set(false);
      final g = b.state = townGame()
        ..wave = 5
        ..townAt = 7;
      g
        ..startWave()
        ..queue.clear()
        ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
      for (var i = 0; i < 600 && !g.inTown; i++) {
        await frames(tester, 1);
      }
      for (var i = 0; i < 120 && b.townFade > 0; i++) {
        await frames(tester, 1);
      }
      await frames(tester, 30);
      // The book shut: the Town's left end, the tent, in view.
      await tester.tapAt(Offset(b.bookArea.left / 2, b.waveMeter.bottom + 40));
      await frames(tester, 60);
      final life = b.townLife, k = b.townK, lane = b.townLane, hem = lane - townTentStep * k;
      final crops = <ui.Image>[];
      for (final type in types) {
        g.units
          ..removeWhere((u) => u.side == Side.troop)
          ..addAll([for (var i = 0; i < 2; i++) Unit(Side.troop, type, troopTypes[type]!, const Point(8, 8))]);
        await frames(tester, 4);
        final tent = life.spots['tent']!;
        final [a, c] = life.folk;
        a
          ..doing = TownDo.rest
          ..slot = 0
          ..mate = null
          ..inside = false
          ..up = true
          ..x = tent
          ..goal = double.nan
          ..dir = 1
          ..until = double.infinity;
        c
          ..doing = TownDo.stroll
          ..mate = null
          ..inside = false
          ..up = false
          ..x = tent + 66
          ..goal = double.nan
          ..dir = -1
          ..until = double.infinity;
        await frames(tester, 6);
        final img = await grab(tester), place = b.townScene['tent']!;
        final feet = {for (final f in b.townFolk) f.unit: f.feet};
        final box = Rect.fromLTRB(place.left - 8 * k, lane - 56 * k, place.right + 44 * k, lane + 10 * k);
        // ignore: avoid_print
        print('$type $s: k $k lane $lane hem $hem tent ${b.townScene['tent']} rest anchor ${feet[a.unit]} street anchor '
            '${feet[c.unit]} (since decisions-log 292 the soles end on the anchor; before, 4 world px over it)');
        final z = await zoom(tester, img, box, 4);
        await save(tester, z, 'tent-$type-$s');
        crops.add(await zoom(tester, img, box, 2));
        if (type == types.first) await save(tester, img, 'town-$s');
      }
      await save(tester, await sheet(tester, crops, 3), 'tent-all-$s');
      // The Tavern's doorway (a priest) and the smith's porch, to compare.
      g.units
        ..removeWhere((u) => u.side == Side.troop)
        ..add(Unit(Side.troop, 'priest', troopTypes['priest']!, const Point(8, 8)));
      await frames(tester, 4);
      final f = life.folk.single;
      f
        ..doing = TownDo.tavern
        ..mate = null
        ..up = true
        ..inside = false
        ..x = life.spots['tavernDoor']!
        ..goal = double.nan
        ..dir = 1
        ..from = life.t + 1e6
        ..until = double.infinity;
      await frames(tester, 6);
      // A narrow screen pans right (the wheel) until the Tavern's door shows.
      final mouse = TestPointer(9, PointerDeviceKind.mouse);
      for (var i = 0; i < 12 && b.townBuilding('tavern').firstWhere((c) => c.$1 == 'doorLow').$2.right > size.width - 80; i++) {
        await tester.sendEventToBinding(mouse.hover(Offset(size.width / 2, size.height / 2)));
        await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
        await frames(tester, 30);
      }
      final img = await grab(tester), door = b.townBuilding('tavern').firstWhere((c) => c.$1 == 'doorLow').$2;
      final smithy = b.townScene['smithy']!;
      // ignore: avoid_print
      print('doorway $s: anchor ${b.townFolk.single.feet} doorLow $door; smithy $smithy');
      await save(tester, await zoom(tester, img, Rect.fromLTRB(door.left - 40 * k, lane - 56 * k, door.right + 40 * k, lane + 10 * k), 4),
          'door-$s');
      await save(tester, await zoom(tester, img, Rect.fromLTRB(smithy.left, lane - 56 * k, smithy.right, lane + 10 * k), 3), 'porch-$s');
    });
  }

  for (final size in const [Size(1600, 947), Size(915, 412)]) {
    final s = '${size.width.round()}x${size.height.round()}';
    if (part.isNotEmpty && part != 'bag') continue;
    testWidgets('the empty Bag and Sell grid, Towns on $s', (tester) async {
      final b = await boot(tester, size);
      b.autoStart.set(false);
      Future<void> shoot(String name) async {
        await frames(tester, 6);
        final img = await grab(tester);
        await save(tester, img, '$name-$s');
        await save(tester, await zoom(tester, img, b.bookArea, 2), '$name-book-$s');
        // ignore: avoid_print
        print('$name $s: ${b.bagEmpty} card ${b.bagEmptyCard}');
      }

      b.state = bagGame()..towns = true;
      await frames(tester, 50);
      await openBag(tester, b);
      await shoot('bag');
      final g = b.state = forgeGame()
        ..matsSeen.clear()
        ..inventory.clear()
        ..relicBag.clear()
        ..materials.clear()
        ..pusaka.clear();
      await frames(tester, 40);
      if (b.bookPage != 'store') await turnTo(tester, b, 'store');
      await tester.tapAt(b.shopTabAt(ShopTab.sell).center);
      await shoot('sell');
      expect(g.towns, isTrue);
      b.state = Game();
      await frames(tester, 10);
    });
  }
}
