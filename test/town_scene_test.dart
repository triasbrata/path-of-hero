// The Town scene (decisions-log 224; lib/town_scene.dart; ui-hud.md "Town"): the house rebuilt cell by cell exactly as
// the design's house.py (its fixture), and booted TdGames with the Towns on at the desk (1266x713), the phone (915x412)
// and the owner's tablet (1164x777): the Town gone into after the win's cheer with a fade, the scene and its
// places where the layout puts them (the troops' rest, the Smithy, the Tavern, the Shop; the scale and the Tavern's
// storeys and width by the room), its three buildings cell by cell standing right on the street's strip (decisions-log
// 279), the signs, the anchors for the troops on the street's lane, the book's Town tabs, a
// tap on a sign or a building opening its page, the bare scene shutting the book, the pans, Leave and its fade back, Auto's countdown and its stop on a press, no guide in a Town, a save
// reopening in it; and out of a Town the field's book.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/guide_rules.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/save.dart';
import 'package:tower_defense/town_art.dart';

import 'town_hud_test.dart' show boot, frames, townGame;

/// Wins wave [wave] + 1 of a Towns-on board game (the Town marked before wave [wave] + 2), and waits until it is gone
/// into: the cheer, then the Town.
Future<Game> intoTown(WidgetTester tester, Board b, {int wave = 5}) async {
  final g = b.state = townGame()
    ..wave = wave
    ..townAt = wave + 2;
  g
    ..startWave()
    ..queue.clear()
    ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
  for (var i = 0; i < 600 && !g.inTown; i++) {
    await frames(tester, 1);
  }
  expect(g.inTown, isTrue);
  return g;
}

/// Pumps until the fade between the field and the Town is over.
Future<void> settle(WidgetTester tester, Board b) async {
  for (var i = 0; i < 120 && b.townFade > 0; i++) {
    await frames(tester, 1);
  }
  await frames(tester, 30); // the pan's 0.4 s too
}

/// The mouse wheel over [at] by [dy] screen px (down goes right: the Town pans, decisions-log 264), and its glide.
Future<void> wheel(WidgetTester tester, Offset at, double dy) async {
  final mouse = TestPointer(9, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(mouse.hover(at));
  await tester.sendEventToBinding(mouse.scroll(Offset(0, dy)));
  await frames(tester, 30);
}

/// A point on the Town's bare scene: under the HUD's rows, left of the book, on no sign or place.
Offset bare(Board b, Size size) {
  final taken = [...b.townScene.entries.where((e) => !const {'scene', 'street'}.contains(e.key)).map((e) => e.value),
    for (final place in const ['smithy', 'tavern', 'shop']) b.townSign(place),
    b.bookArea, b.waveMeter, b.logButton, b.troopCounter];
  for (var y = b.waveMeter.bottom + 12; y < size.height - 8; y += 8) {
    for (var x = 8.0; x < (b.bookArea.isEmpty ? size.width : b.bookArea.left) - 8; x += 8) {
      final p = Offset(x, y);
      if (!taken.any((r) => r.inflate(4).contains(p))) return p;
    }
  }
  fail('no bare scene to tap');
}

/// The test sizes, the screen px a world px each one draws the Town at, the Tavern it builds (n, storeys), and the
/// Town's room to pan with the book shut (its 1010 world px less the screen's, decisions-log 271).
const sizes = [
  (Size(1266, 713), 2.0, (1, 2), 1010 - 633.0),
  (Size(915, 412), 1.0, (1, 2), 1010 - 915.0), // at 2 the scale's rule doesn't fit its 457 world px across 582
  (Size(1164, 777), 2.0, (1, 2), 1010 - 582.0), // the least screen at 2: 582 world px
];

/// The Smithy's pieces outside its house, each with its art's columns in its drawn box (world px): the furnace's 10-53
/// of its 64, the sawmill's 4-60, the rest their whole box. Left to right: the wood corner, then past the house the
/// furnace and the ore (decisions-log 271).
const smithyArt = {'stumpAxe': (0, 21), 'logPile': (0, 47), 'sawmill': (4, 61), 'furnace': (10, 54), 'ore': (0, 53)};

/// The middle of the Smithy's house's walls and its furnace's art on the screen: what a pan to the Smithy centres
/// (decisions-log 253: the furnace outside, on the house's right).
double smithyMid(Board b) =>
    (b.townBuilding('smithy').firstWhere((c) => c.$1 == 'wallL8a').$2.left + b.townScene['furnace']!.left + 54 * b.townK) / 2;

/// The bounds of a building's cells as drawn.
Rect bounds(List<(String, Rect)> cells) => cells.map((c) => c.$2).reduce((a, b) => a.expandToInclude(b));

void main() {
  test("houseCells, houseProps and houseSize rebuild the design's houses exactly (house.py's fixture), from "
      "town_house.png's cells", () {
    final houses = (jsonDecode(File('test/fixtures/town_house_cells.json').readAsStringSync()) as Map)['houses'] as List;
    expect(houses, hasLength(3));
    for (final h in houses.cast<Map<String, dynamic>>()) {
      final n = h['n'] as int, storeys = h['storeys'] as int, tag = 'n $n, $storeys storeys';
      expect([for (final (name, c, r) in houseCells(n, storeys)) [name, c, r]], h['cells'], reason: tag);
      expect([for (final (name, x, b) in houseProps(n, storeys)) [name, x, b]], h['props'], reason: tag);
      expect(houseSize(n, storeys), ((h['size'] as List)[0], (h['size'] as List)[1]), reason: tag);
    }
    // Every house the scene can draw: each cell is the atlas's, none twice on one place, all inside the grid.
    for (final (n, storeys) in const [(-1, 1), (-1, 2), (0, 1), (0, 2), (1, 1), (1, 2)]) {
      final cells = houseCells(n, storeys);
      final (w, h) = houseSize(n, storeys);
      expect(cells.map((c) => c.$1).toSet().difference(townHouseCells.keys.toSet()), isEmpty);
      expect({for (final (_, c, r) in cells) (c, r)}, hasLength(cells.length), reason: 'n $n, $storeys: no cell twice');
      expect(cells.every((c) => c.$2 >= 0 && c.$2 * 16 < w && c.$3 >= 0 && c.$3 * 16 < h), isTrue);
      expect(houseProps(n, storeys).every((p) => townPropCells.containsKey(p.$1)), isTrue);
      // The props stand on the house: none past its right end column.
      for (final (name, x, _) in houseProps(n, storeys)) {
        expect(x + townPropCells[name]!.w, lessThanOrEqualTo((12 + 2 * n) * 16), reason: 'n $n, $storeys: $name');
      }
    }
    expect([for (final (name, _, _) in houseProps(-1, 2)) name], ['table', 'crates2', 'cauldron']);
  });

  for (final (size, scale, shape, shut) in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('the Town at $tag: gone into after the cheer with a fade, the scene laid out by the room (k $scale, the '
        'Tavern n ${shape.$1}, ${shape.$2} storeys), its buildings, signs and anchors, the Town\'s tabs, taps on signs '
        'and buildings, the pans, Leave and the fade back', (tester) async {
      final b = await boot(tester, size);
      b.autoStart.set(false);
      final g = await intoTown(tester, b);
      // The fade: the field dims first, then the Town comes up out of the dim.
      expect((b.townShown, b.townFade < 0.1), (false, true));
      await frames(tester, 12); // ~0.19 s
      expect(b.townShown, isFalse, reason: 'the field, dimming');
      expect(b.townFade, inInclusiveRange(0.1, 0.35));
      await frames(tester, 14); // ~0.42 s
      expect(b.townShown, isTrue, reason: 'the Town, coming up');
      expect(b.townFade, inExclusiveRange(0.0, 0.35));
      await settle(tester, b);
      expect((b.townShown, b.townFade), (true, 0.0));
      expect(b.coveredAt(Offset(size.width / 2, size.height / 2)), isTrue, reason: 'no unit of the field under the Town');

      // The book: open on the Smithy, with the Town's tabs (the Tavern's after it, decisions-log 268).
      expect(b.bookPage, 'smithy');
      expect([for (final (name, _) in b.bookTabs) name], ['smithy', 'tavern', 'store', 'troops', 'bag', 'settings']);
      expect(b.bookArea, isNot(Rect.zero));

      // The scene: its room, at k; the three buildings by the room, cell by cell.
      final scene = b.townScene, k = b.townK;
      expect(k, scale);
      expect(scene['scene'], Offset.zero & size);
      for (final (place, want) in [('smithy', (-1, 1)), ('tavern', shape), ('shop', (-1, 1))]) {
        expect(b.townBuildingShape(place), want, reason: place);
        final cells = houseCells(want.$1, want.$2), drawn = b.townBuilding(place);
        expect([for (final (name, _) in drawn) name], [for (final (name, _, _) in cells) name], reason: place);
        final origin = drawn.first.$2.topLeft - Offset(cells.first.$2 * 16 * k, cells.first.$3 * 16 * k);
        for (var i = 0; i < cells.length; i++) {
          final (name, r) = drawn[i];
          final (_, col, row) = cells[i];
          final cell = townHouseCells[name]!;
          expect(r, Rect.fromLTWH(origin.dx + col * 16 * k, origin.dy + row * 16 * k, cell.w * k, cell.h * k),
              reason: '$place $name');
        }
        expect(origin.dx, origin.dx.roundToDouble(), reason: 'on whole screen px');
        // Its porch stands right on the street (decisions-log 279): its bottom on the strip's top edge, the street's line,
        // nothing over its feet.
        expect(bounds(drawn).bottom, scene['street']!.top, reason: '$place: on the strip');
        expect(bounds(drawn).bottom, b.townLane, reason: "$place: on the street's line");
      }
      // Every piece at every size (the Town laid out 1010 world px wide, decisions-log 271).
      for (final piece in ['tent', 'campfire', 'crates2', 'fruitTable', 'barrels', 'basket', 'pine', 'clothesLine',
        ...smithyArt.keys]) {
        expect(scene[piece], isNotNull, reason: piece);
      }
      // The campfire's 32 px of art end at the tent's right, before the Smithy's wood corner.
      expect(scene['campfire']!.right, closeTo(scene['tent']!.right, 0.01));
      expect(scene['stumpAxe']!.left - scene['campfire']!.right, greaterThanOrEqualTo(4 * k - 0.01));
      // The Smithy (decisions-log 253: the owner, "smithy furnace dan sawmillnya jangan di taruh di dalam bangunan"; 271:
      // "posisi furnace di sebelah kanan dan sawmill di sebelah kiri dari smithy"): nothing on its ground floor between
      // its walls (the smith's); on its left the wood corner, the stump, the log pile and the sawmill, each piece's art
      // after the last's and the sawmill's clear of the house's eave tip (its door further in); on its right the furnace
      // against its wall, outside, and the ore past it, short of the yard's pine; none under the Smithy's sign.
      final smithy = b.townBuilding('smithy');
      Rect cell(List<(String, Rect)> house, String name) => house.firstWhere((c) => c.$1 == name).$2;
      final walls = Rect.fromLTRB(cell(smithy, 'wallL8a').left, cell(smithy, 'wallL8a').top, cell(smithy, 'blockBR').right,
          cell(smithy, 'blockBR').bottom);
      for (final MapEntry(key: name, value: r) in scene.entries) {
        if (const {'scene', 'street', 'tent', 'smithy', 'yard', 'tavern', 'shop', 'smith'}.contains(name)) continue;
        final (l, rr) = smithyArt[name] ?? (0, r.width ~/ k);
        final art = Rect.fromLTRB(r.left + l * k, r.top, r.left + rr * k, r.bottom);
        expect(art.overlaps(walls), isFalse, reason: '$name on the Smithy\'s ground floor: $art, its walls $walls');
      }
      final work = smithyArt.keys.toList();
      double artL(String name) => scene[name]!.left + smithyArt[name]!.$1 * k;
      double artR(String name) => scene[name]!.left + smithyArt[name]!.$2 * k;
      for (var i = 1; i < work.length; i++) {
        expect(artL(work[i]), greaterThanOrEqualTo(artR(work[i - 1])), reason: '${work[i - 1]} then ${work[i]}');
      }
      final house = bounds(smithy), seen = house.left + 6 * k; // its left eave tip's clear 6 world px
      expect(artR('sawmill'), closeTo(seen - 3 * k, 0.01), reason: "the sawmill left of the Smithy, 3 clear of its eave");
      expect(artL('sawmill') - artR('logPile'), closeTo(3 * k, 0.01), reason: 'the logs by the sawmill');
      expect(artL('furnace'), closeTo(walls.right, 0.01), reason: 'the furnace against the wall, outside, on the right');
      expect(artL('ore') - artR('furnace'), closeTo(2 * k, 0.01), reason: 'the ore by the furnace');
      expect(scene['pine']!.left - artR('ore'), greaterThanOrEqualTo(2 * k - 0.01), reason: 'the ore clear of the pine');
      for (final name in work) {
        expect(scene[name]!.overlaps(b.townSign('smithy')), isFalse, reason: '$name under the sign');
      }
      expect(scene['smithy'], scene['stumpAxe']!.expandToInclude(scene['ore']!).expandToInclude(house),
          reason: "the Smithy's place: its wood corner, its house, its furnace and the ore");
      // The yard (decisions-log 253): the pine at its left and the clothes line beside it, so the pine's first tier
      // (its widest rows, the whole 50 px across) shows whole, never behind the line's cloths or posts; past the
      // Smithy's ore, inside the yard.
      final pine = scene['pine']!, line = scene['clothesLine']!, yard = scene['yard']!;
      expect(pine.size, Size(50 * k, 128 * k));
      expect(line.left, greaterThanOrEqualTo(pine.right), reason: 'the line right of the pine: $pine $line');
      expect(yard, pine.expandToInclude(line));
      // The anchors for the troops: on the street's lane, left to right, each at its own thing.
      final lane = b.townLane, spots = ['guard', 'tent', 'smithy', 'tavernDoor', 'talk', 'shop'];
      expect(lane, scene['street']!.top, reason: "the lane on the strip's top edge");
      for (final spot in spots) {
        expect(b.townSpot(spot).dy, lane, reason: spot);
      }
      for (var i = 1; i < spots.length; i++) {
        expect(b.townSpot(spots[i]).dx, greaterThan(b.townSpot(spots[i - 1]).dx), reason: '${spots[i - 1]} < ${spots[i]}');
      }
      bool over(String spot, Rect r) => b.townSpot(spot).dx >= r.left && b.townSpot(spot).dx <= r.right;
      expect(over('tent', scene['tent']!), isTrue);
      expect(over('smithy', scene['furnace']!), isTrue);
      expect(over('tavernDoor', b.townBuilding('tavern').firstWhere((c) => c.$1 == 'doorLow').$2), isTrue);
      expect(over('shop', scene['fruitTable']!), isTrue);

      // A tap on the bare scene shuts the book: the open page's place (the Smithy) in the middle of the screen, kept
      // between the Town's ends, the rest a pan away (decisions-log 271: the Town laid out wider than the screen).
      await tester.tapAt(bare(b, size));
      await frames(tester, 40);
      expect(b.bookArea, Rect.zero);
      final (lo, hi) = b.townRoom;
      final cam = b.townCam;
      expect(lo, 0.0);
      expect(hi, closeTo(shut, 0.01), reason: 'the room to pan with the book shut');
      expect(cam, inInclusiveRange(lo, hi));
      if (cam > lo && cam < hi) expect(smithyMid(b), closeTo(size.width / 2, 2), reason: 'the Smithy in the middle');
      final now = b.townScene, places = [for (final p in ['tent', 'smithy', 'tavern', 'shop']) now[p]!];
      for (var i = 1; i < places.length; i++) {
        expect(places[i - 1].right, lessThanOrEqualTo(places[i].left + 16 * k),
            reason: 'the rest, the Smithy, the Tavern and the Shop side by side: $places');
      }
      expect(now['tent']!.left, closeTo((2 - cam) * k, 1), reason: "the rest at the Town's left end");
      expect(now['shop']!.right, closeTo((1010 - cam) * k, 1), reason: "the Shop at the Town's right end");
      for (final sign in ['smithy', 'tavern', 'shop']) {
        final r = b.townSign(sign);
        expect(r.top, greaterThanOrEqualTo(b.waveMeter.bottom), reason: '$sign sign $r');
        expect(r.center.dx, closeTo(bounds(b.townBuilding(sign)).center.dx, 1), reason: '$sign sign over its building');
        expect(r.bottom, lessThanOrEqualTo(bounds(b.townBuilding(sign)).top), reason: '$sign sign over its roof');
      }
      final sign = b.townSign('smithy');
      expect(sign.left >= 0 && sign.right <= size.width, isTrue, reason: "the Smithy's sign on the screen: $sign");
      // Each piece of the Smithy's opens it: the sawmill on its left, the furnace and the ore on its right (each
      // piece's art its place's tap box, decisions-log 253).
      for (final (name, at) in [
        ('sawmill', now['sawmill']!.center),
        ('furnace', Offset(now['furnace']!.left + 32 * k, now['furnace']!.bottom - 20 * k)),
        ('ore', now['ore']!.center),
      ]) {
        await tester.tapAt(at);
        await frames(tester, 40);
        expect((b.bookPage, b.bookArea == Rect.zero), ('smithy', false), reason: '$name at $at');
        await tester.tapAt(bare(b, size));
        await frames(tester, 40);
        expect(b.bookArea, Rect.zero);
      }
      // The wheel to the Town's right end; the Shop's sign opens its page at wave 5, the Shop open in every Town
      // (decisions-log 253), its place panned into the strip left of the book.
      await wheel(tester, bare(b, size), 3000);
      expect(b.townCam, hi);
      await tester.tapAt(b.townSign('shop').center);
      await frames(tester, 40);
      expect((b.bookPage, b.storeShown), ('store', true));
      expect(b.townSign('shop').center.dx, closeTo(b.bookArea.left / 2, 2));
      // Shut, the Shop's place stays in view (the Town's right end); the Tavern opens its page (decisions-log 268; the
      // Bag with the Tavern off), panned into the strip left of the book.
      await tester.tapAt(bare(b, size));
      await frames(tester, 40);
      expect((b.bookArea, b.townCam), (Rect.zero, hi));
      final tavern = b.townBuilding('tavern').firstWhere((c) => c.$1 == 'wallL8a').$2;
      await tester.tapAt(tavern.center);
      await frames(tester, 40);
      expect(b.bookPage, 'tavern');
      expect(b.townSign('tavern').center.dx, closeTo(b.bookArea.left / 2, 2));
      // Shut again, the wheel back to the Town's left end, and the Smithy's sign opens the Smithy, its place left of
      // the book.
      await tester.tapAt(bare(b, size));
      await frames(tester, 40);
      expect(b.bookArea, Rect.zero);
      await wheel(tester, bare(b, size), -3000);
      expect(b.townCam, lo);
      await tester.tapAt(b.townSign('smithy').center);
      await frames(tester, 40);
      expect(b.bookPage, 'smithy');
      expect(smithyMid(b), closeTo(b.bookArea.left / 2, 2));

      // The Shop's tab: with a later town.json shop.from (the knob) it says when the Shop opens and turns no page; as
      // shipped (1: open in every Town, decisions-log 253) it opens the Shop's page at wave 5, its place in view.
      final shipped = g.townRules;
      g.townRules = TownRules.patch({'shop': {'from': 15}});
      await frames(tester, 2);
      await tester.tapAt(b.bookTabs.firstWhere((t) => t.$1 == 'store').$2.center);
      await frames(tester, 2);
      expect(b.message, 'Opens after wave 15');
      expect(b.bookPage, isNot('store'));
      await frames(tester, 150); // the message goes
      g.townRules = shipped;
      await frames(tester, 2);
      await tester.tapAt(b.bookTabs.firstWhere((t) => t.$1 == 'store').$2.center);
      await frames(tester, 40);
      expect((b.bookPage, b.storeShown), ('store', true));
      expect(b.townSign('shop').center.dx, closeTo(b.bookArea.left / 2, 2), reason: "the Shop's place in view");

      // Leave: the fade back, the field, its book without the Shop (the Towns on).
      await tester.tapAt(b.startButton.center);
      await frames(tester, 2);
      expect((g.inTown, b.townShown), (false, true), reason: 'the Town, dimming');
      await settle(tester, b);
      expect((b.townShown, b.townScene.isEmpty, b.townFade), (false, true, 0.0));
      expect(b.bookPage, 'troops');
      expect([for (final (name, _) in b.bookTabs) name], ['troops', 'bag', 'settings']);
      expect(b.coveredAt(Offset(size.width * 0.1, size.height * 0.3)), isFalse);
      await frames(tester, 30);
    });
  }

  testWidgets('Auto in a Town: "Leave town 5" counts down; a press in the Town (a tab) stops it for the visit; with no '
      'press it leaves at 0 and the wave starts once the fade back is over', (tester) async {
    final b = await boot(tester);
    b.autoStart.set(true);
    addTearDown(() => b.autoStart.set(false));
    var g = await intoTown(tester, b);
    expect(b.autoStart.shown, 5);
    await frames(tester, 30);
    await tester.tapAt(b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
    await frames(tester, 2);
    expect(b.autoStart.left, isNull, reason: 'stopped by the press');
    await frames(tester, 400); // 6.4 s
    expect(g.inTown, isTrue, reason: 'Leave by hand then');
    await tester.tapAt(b.startButton.center);
    await frames(tester, 60);
    expect((g.inTown, g.waveActive), (false, false), reason: 'left by hand: no wave by itself');

    // No press: Auto leaves after 5 s, the wave waiting for the fade back.
    g = await intoTown(tester, b, wave: 12);
    expect(b.autoStart.shown, 5);
    for (var i = 0; i < 400 && g.inTown; i++) {
      await frames(tester, 1);
    }
    expect((g.inTown, g.waveActive), (false, false), reason: 'the fade back first');
    await frames(tester, 12);
    expect(g.waveActive, isFalse);
    await frames(tester, 40);
    expect((g.waveActive, g.wave), (true, 14));
    await frames(tester, 30);
  });

  testWidgets('no guide card or pointer in a Town but its own (K23, seen here; town_switch_test.dart); a save made in it '
      'reopens in it at once (no fade), the book on the Smithy; a game out of a Town shows none, and the field\'s book has no '
      'Shop tab (the Toko went in decisions-log 296)', (tester) async {
    final b = await boot(tester);
    b.autoStart.set(false);
    final seen = b.guideSeen;
    addTearDown(() => b.guideSeen = seen);
    b.guideSeen = {guideIntro, 'K23'}; // P1 (the Army's price button) would point between waves on the field
    final g = await intoTown(tester, b);
    await settle(tester, b);
    expect((b.coachCard, b.coachPointer), (null, null));
    b.guideSeen = seen;

    saveGame(g);
    final back = loadGame()!;
    expect(back.inTown, isTrue);
    b.state = back;
    await frames(tester, 2);
    expect((b.townShown, b.townFade, b.bookPage), (true, 0.0, 'smithy'));

    b.state = Game(Random(1), Random(2)).boardRules()
      ..wave = 20;
    await frames(tester, 40);
    expect((b.townShown, b.townScene.isEmpty), (false, true));
    expect([for (final (name, _) in b.bookTabs) name], ['troops', 'bag', 'settings']);
    await frames(tester, 30);
  });
}

