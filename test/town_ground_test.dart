// The Town's sky and ground (decisions-log 274, the ground since 279; lib/town_scene.dart, lib/town_life.dart; ui-hud.md
// "Town", "The troops' life"): the ground at 1266x713, 1164x777, 915x412 and 1600x947 (town_ground.png, Floor
// Tiles2's grass top over its earth, tiled side by side from the street's line across the view and moving with the
// street; its last row, the earth's one colour, on to the view's bottom; no full green (town_bg_1's last row); every
// building, piece and the smith standing right on it, the ground drawn first and the street's troops in front, their
// feet on the strip at their depth); the clouds over its sky (the field's battle_clouds.png, between the sky and the
// mountains, drifting on the field's clock and moving at 0.07 of the pan), and inside is higher (a troop in the Tavern's
// doorway or the tent's opening stands on its floor over the street, the porch's top or the tent's hem, behind its
// troops, and steps back down as it comes out); every troop's soles on its line (decisions-log 292: [townFeet], each
// type's feet row in its idle strip, on the hem's top in the tent, the sill in the Tavern's doorway, the street's strip
// at its depth). Booted TdGames (the ground at the four sizes, the clouds at 1266x713 and 915x412, inside at 1266x713,
// the soles at 1600x947 and 1266x713), and [TownLife] alone on a scripted dice.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/town_art.dart';

import 'town_hud_test.dart' show boot, frames;
import 'town_life_test.dart' show ScriptDice, anchors, at, life, troop, until;
import 'town_scene_test.dart' show bounds, intoTown, settle;

/// A canvas that only notes the images drawn on it, from where and to where, in order; every other call does nothing.
class _Drawn implements Canvas {
  final images = <(ui.Image, Rect, Rect)>[];

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) => images.add((image, src, dst));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A canvas that notes each image drawn with the translation and scale it was drawn under (save, restore, translate and
/// scale: what the Town's troops are drawn with); every other call does nothing.
class _Placed implements Canvas {
  final images = <(ui.Image, Rect, Offset, Offset)>[]; // the image, its dst, the translation, the scale
  var _t = Offset.zero, _s = const Offset(1, 1);
  final _stack = <(Offset, Offset)>[];

  @override
  void save() => _stack.add((_t, _s));

  @override
  void saveLayer(Rect? bounds, Paint paint) => save();

  @override
  void restore() {
    if (_stack.isEmpty) return;
    final (t, s) = _stack.removeLast();
    _t = t;
    _s = s;
  }

  @override
  void translate(double dx, double dy) => _t += Offset(dx * _s.dx, dy * _s.dy);

  @override
  void scale(double sx, [double? sy]) => _s = Offset(_s.dx * sx, _s.dy * (sy ?? sx));

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) => images.add((image, dst, _t, _s));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// [path]'s pixels, RGBA row by row, and its width and height.
Future<(ByteData, int, int)> _pixels(String path) async {
  final image = (await (await ui.instantiateImageCodec(File(path).readAsBytesSync())).getNextFrame()).image;
  final out = ((await image.toByteData())!, image.width, image.height);
  image.dispose();
  return out;
}

/// Where feet stand on the street in the layers' px (town_scene.dart's `_townGround`): the layers' top is the lane less
/// this many world px.
const ground = 262;

/// The clouds' first copy's left now, as an offset into a repeat (screen px, 0 up to its width).
double cloudsAt(Board b) => -b.townClouds.first.left;

/// The pieces standing on the street (town_scene.dart's `_TownLayout.pieces`; the first Town's yard, Millbrook's).
const pieces = ['tent', 'campfire', 'crates2', 'fruitTable', 'barrels', 'basket', 'flowerTree', 'wheat', 'wheat2', 'sack',
  'sheaf', 'furnace', 'sawmill', 'ore', 'logPile', 'stumpAxe'];

void main() {
  test("town_ground.png is opaque, its top row the strip's edge and its last row one colour, the earth's", () async {
    final bytes = File('assets/images/$townGroundTile').readAsBytesSync();
    final image = (await (await ui.instantiateImageCodec(bytes)).getNextFrame()).image;
    expect((image.width, image.height), (townGroundW, townGroundH));
    final px = (await image.toByteData())!; // RGBA, row by row
    int at(int x, int y) => px.getUint32((y * townGroundW + x) * 4);
    for (var y = 0; y < townGroundH; y++) {
      for (var x = 0; x < townGroundW; x++) {
        expect(at(x, y) & 0xff, 255, reason: '($x, $y) opaque: the strip hides the layers under it');
      }
    }
    final earth = {for (var x = 0; x < townGroundW; x++) at(x, townGroundH - 1)};
    expect(earth, hasLength(1), reason: 'its last row one colour: stretched down, it goes on as the earth');
    image.dispose();
  });

  for (final size in const [Size(1266, 713), Size(1164, 777), Size(915, 412), Size(1600, 947)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('the ground at $tag: town_ground.png tiled from the street\'s line across the view with the street, its '
        'earth to the bottom; the buildings and pieces right on it, nothing over their feet; drawn first, the troops in '
        'front on the strip', (tester) async {
      final b = await boot(tester, size)..townDice = ScriptDice(); // every roll a stroll: everyone on the street
      b.autoStart.set(false);
      final g = await intoTown(tester, b);
      g.units.addAll([troop('knight'), troop('archer'), troop('wizard')]);
      await settle(tester, b);
      final k = b.townK, lane = b.townLane, ground = b.townGround, scene = b.townScene;
      expect(ground.keys, ['strip', 'earth']);
      final [strip, earth] = [for (final band in ['strip', 'earth']) ground[band]!];
      for (final (name, r) in [('strip', strip), ('earth', earth)]) {
        expect((r.left, r.right), (0, size.width), reason: '$name: across the view');
        expect([r.top, r.bottom].every((y) => y == y.roundToDouble()), isTrue, reason: '$name: on whole screen px');
      }
      expect(scene['street'], strip, reason: "the street's strip");
      expect((strip.top, strip.height), (lane, townGroundH * k), reason: "its top edge on the street's line, at k");
      expect(earth.top, strip.bottom);
      expect(earth.bottom, greaterThanOrEqualTo(size.height), reason: "the earth to the view's bottom");
      expect(strip.bottom, lessThanOrEqualTo(size.height), reason: 'the strip on the screen, the earth under it');
      // The tiles: town_ground.png whole, side by side (each where the last ends) from left of the view to past its
      // right, on the street's own grid (they move with it); its last row stretched under them.
      List<(ui.Image, Rect, Rect)> drawnNow() {
        final drawn = _Drawn();
        b.render(drawn);
        return drawn.images;
      }

      final images = b.game.images, tile = images.fromCache(townGroundTile), w = townGroundW * k;
      List<Rect> tiles(List<(ui.Image, Rect, Rect)> drawn) => [
            for (final (i, src, dst) in drawn)
              if (i == tile && src == Rect.fromLTWH(0, 0, townGroundW.toDouble(), townGroundH.toDouble())) dst,
          ];
      void seamless(List<Rect> row, String when) {
        expect(row, isNotEmpty, reason: when);
        expect(row.first.left, lessThanOrEqualTo(0), reason: '$when: from left of the view');
        expect(row.last.right, greaterThanOrEqualTo(size.width), reason: '$when: past its right');
        for (var i = 0; i < row.length; i++) {
          expect(row[i], Rect.fromLTWH(row[i].left, lane, w, townGroundH * k), reason: '$when: tile $i at k on the lane');
          if (i > 0) expect(row[i].left, row[i - 1].right, reason: '$when: tile $i where tile ${i - 1} ends');
        }
        final ox = -(b.townCam * k).roundToDouble();
        expect((row.first.left - ox) % w, 0, reason: "$when: on the street's grid (${b.townCam})");
      }

      final drawn = drawnNow();
      seamless(tiles(drawn), 'at rest');
      final under = [for (final (i, src, dst) in drawn) if (i == tile && src.height == 1) (src, dst)];
      expect(under, [(Rect.fromLTWH(0, townGroundH - 1.0, townGroundW.toDouble(), 1), earth)], reason: 'its last row, stretched');
      // Panned (a drag on the street), the tiles move with it, still seamless.
      final (lo, hi) = b.townRoom;
      if (hi > lo) {
        final cam0 = b.townCam, toward = cam0 - lo > hi - cam0 ? -1.0 : 1.0;
        final press = await tester.startGesture(Offset(size.width / 4, lane - 10));
        await frames(tester, 1);
        await press.moveBy(Offset(-toward * 30, 0));
        await frames(tester, 1);
        await press.moveBy(Offset(-toward * 37, 0));
        await frames(tester, 1);
        expect(b.townCam, isNot(cam0), reason: 'panned');
        seamless(tiles(drawnNow()), 'panned to ${b.townCam}');
        await press.up();
        await frames(tester, 30);
      }
      // Each building, piece and the smith right on the strip: a building's porch and every piece's bottom on its top
      // edge (the street's line), the smith on his house's floor (townStep over it), nothing drawn over their feet.
      for (final place in ['smithy', 'tavern', 'shop']) {
        expect(bounds(b.townBuilding(place)).bottom, lane, reason: '$place: on the strip');
      }
      for (final piece in pieces) {
        final r = scene[piece];
        if (r == null) continue; // off the view: drawn only where it shows
        expect(r.bottom, lane, reason: '$piece: on the strip');
      }
      final smith = scene['smith'];
      if (smith != null) expect(smith.bottom, lane - townStep * k, reason: "the smith on the Smithy's floor");
      // The order: the strip and its earth first, then the houses and the pieces standing on it, then the street's troops;
      // never town_bg_1's last row stretched (274's full green).
      final order = [for (final (i, _, _) in drawnNow()) i];
      int first(String file) => order.indexOf(images.fromCache(file));
      int last(String file) => order.lastIndexOf(images.fromCache(file));
      expect(last(townGroundTile), lessThan(first('town_house.png')), reason: 'the houses on the strip');
      expect(last(townGroundTile), lessThan(first(townTent)), reason: 'the tent on the strip');
      expect([for (final (i, src, _) in drawnNow()) if (i == images.fromCache(townLayers[0]) && src.height == 1) src], isEmpty,
          reason: "no full green (town_bg_1's last row)");
      final street = [for (final f in b.townLife.folk) if (f.shown && !f.up) images.fromCache(f.walking ? f.walk : f.idle)];
      expect(street, isNotEmpty);
      expect(order.indexWhere(street.contains), greaterThan(last(townGroundTile)), reason: "the street's troops in front");
      // Their feet on the strip, at their depth under its top edge (0 to 4 world px).
      for (final f in b.townFolk) {
        final feet = f.feet;
        if (feet == null) continue;
        final folk = b.townLife.folk.firstWhere((e) => e.unit == f.unit), up = folk.up;
        expect(feet.dy, up ? lane - folk.floor * k : inInclusiveRange(lane, lane + 4 * k),
            reason: '${f.unit.type} ${f.doing}');
        if (!up) expect(feet.dy, lessThan(strip.bottom), reason: '${f.unit.type}: on the strip (off the view too)');
      }
    });
  }

  test('a resting troop steps up into the tent\'s opening and stays down by the fire; up and down with its errands', () {
    for (final (slot, x, up) in [
      (0, anchors['tent']! + townRest[0], true),
      (1, anchors['tent']! + townRest[1], true),
      (2, anchors['tent']! + townRest[2], true),
      (3, anchors['tent']! + townRest[3], false), // by the fire, outside
    ]) {
      final dice = ScriptDice(), l = life(dice, [troop()]), f = l.folk.single;
      dice.queue.addAll([at(300), 0.9, TownLife.drawFor(TownDo.stroll), at(300), 0.5]);
      l.step(0.05);
      until(l, () => !f.walking);
      expect(f.up, isFalse, reason: 'a stroll stands on the street');
      f
        ..doing = TownDo.rest
        ..slot = slot
        ..until = double.infinity
        ..goal = x;
      until(l, () => !f.walking);
      expect((f.x, f.up), (x, up), reason: 'slot $slot: ${up ? 'in the opening' : 'by the fire'}');
      f.until = l.t; // its rest is over: it sets out on the next errand (the fallback: a stroll)
      l.step(0.05);
      expect((f.doing, f.up), (TownDo.stroll, false), reason: 'slot $slot: steps down as it sets out');
    }
  });

  for (final size in const [Size(1266, 713), Size(915, 412)]) {
    final tag = '${size.width.round()}x${size.height.round()}';

    testWidgets('the clouds at $tag: battle_clouds.png over the Town\'s sky, between the sky and the mountains, side by '
        'side across the view, drifting left on the clock and moving at 0.07 of the pan', (tester) async {
      final b = await boot(tester, size);
      b.autoStart.set(false);
      await intoTown(tester, b);
      await settle(tester, b);
      final k = b.townK, clouds = b.townClouds;
      expect(clouds, isNotEmpty);
      expect(clouds.first.left, lessThanOrEqualTo(0));
      expect(clouds.last.right, greaterThanOrEqualTo(size.width));
      for (var i = 0; i < clouds.length; i++) {
        final r = clouds[i];
        expect(r.size, Size(battleCloudsW * k, battleCloudsH * k), reason: 'copy $i: at k a px, as the layers');
        expect(r.top, b.townLane - (ground + 4) * k, reason: "copy $i: row 0 4 px over the layers' (as on the field)");
        if (i > 0) expect(r.left, clouds[i - 1].right, reason: 'copy $i: side by side');
      }
      // Drawn between the sky (town_bg_5) and the mountains (town_bg_4), each copy where townClouds says.
      final drawn = _Drawn();
      b.render(drawn);
      final images = b.game.images, order = [for (final (i, _, _) in drawn.images) i];
      final sky = order.lastIndexOf(images.fromCache(townLayers[4])), hills = order.indexOf(images.fromCache(townLayers[3]));
      final cloud = images.fromCache('battle_clouds.png');
      expect([for (final (i, at) in drawn.images.indexed) if (at.$1 == cloud) (i > sky && i < hills, at.$3)],
          [for (final r in b.townClouds) (true, r)]);
      // They drift left: 6 px (the field's 1.2 world units) a second at k screen px a px.
      final x0 = cloudsAt(b);
      await frames(tester, 60); // 0.96 s
      final drift = (cloudsAt(b) - x0) % (battleCloudsW * k);
      expect(drift, closeTo(0.96 * 6 * k, 1.5), reason: 'the drift');
      // The player's pan moves them 0.07 as far as the street (decisions-log 264's drag).
      final (lo, hi) = b.townRoom;
      final cam0 = b.townCam, toward = cam0 - lo > hi - cam0 ? -1.0 : 1.0; // toward the farther end
      final press = await tester.startGesture(Offset(size.width / 4, b.townLane - 10));
      await frames(tester, 1);
      await press.moveBy(Offset(-toward * 30, 0)); // past the slop: it takes hold
      await frames(tester, 1);
      final cam1 = b.townCam, c1 = cloudsAt(b);
      await press.moveBy(Offset(-toward * 120, 0));
      await frames(tester, 1);
      final moved = b.townCam - cam1, by = (cloudsAt(b) - c1) % (battleCloudsW * k);
      expect(moved.abs(), greaterThan(30), reason: 'the street panned');
      expect(by, closeTo((0.07 * moved * k + 0.016 * 6 * k) % (battleCloudsW * k), 1.5), reason: 'the clouds 0.07 of it');
      await press.up();
      await frames(tester, 30);
    });
  }

  testWidgets('inside is higher at 1266x713: a troop in the tent\'s opening stands townTentStep over the street, in the '
      'Tavern\'s doorway townStep, behind its troops; gone inside, then back in the doorway, then down on the street',
      (tester) async {
    final b = await boot(tester)..townDice = ScriptDice(); // every roll a stroll, at once, depth 0
    b.autoStart.set(false);
    final g = await intoTown(tester, b);
    g.units
      ..removeWhere((u) => u.side == Side.troop)
      ..addAll([troop('knight'), troop('priest')]);
    await settle(tester, b);
    final life = b.townLife, k = b.townK, lane = b.townLane;
    final (a, c) = (life.folk[0], life.folk[1]);
    Offset? feet(TownFolk f) => b.townFolk.firstWhere((e) => e.unit == f.unit).feet;
    /// Sends [f] on [what] at [x] as `_next` would (down on the street, not inside), from 40 world px right of it.
    Future<void> send(TownFolk f, TownDo what, double x) async {
      f
        ..doing = what
        ..slot = 0
        ..mate = null
        ..up = false
        ..inside = false
        ..until = double.infinity
        ..x = x + 40
        ..goal = x;
      for (var i = 0; i < 900 && f.walking; i++) {
        await frames(tester, 1);
      }
      await frames(tester, 1);
    }

    // c strolls to a point on the street and stands there; a rests in the tent's opening.
    await send(c, TownDo.stroll, life.spots['tent']! + 120);
    c.until = double.infinity; // it stays
    await send(a, TownDo.rest, life.spots['tent']!);
    expect((a.up, c.up), (true, false));
    expect(feet(a)!.dy, lane - townTentStep * k, reason: "on the tent's floor, its canvas's hem (decisions-log 279)");
    expect(a.floor, townTentStep);
    expect(feet(c)!.dy, lane + c.depth * k, reason: 'on the street');
    expect(feet(a)!.dy, lessThan(lane), reason: 'higher than any troop on the street (depth 0 to 4 under the lane)');
    // The one inside drawn first: behind the street's troops.
    final drawn = _Drawn();
    b.render(drawn);
    final images = b.game.images, order = [for (final (i, _, _) in drawn.images) i];
    expect(order.indexOf(images.fromCache(a.idle)), lessThan(order.indexOf(images.fromCache(c.idle))));
    // a goes to the Tavern: up its doorstep, in its doorway, inside (not drawn), back in its doorway, down on the street.
    await send(a, TownDo.tavern, life.spots['tavernDoor']! + 0);
    a.until = life.t + townDoorway + 1.0 + townDoorway; // a short visit
    expect((a.up, a.inside, feet(a)!.dy), (true, false, lane - townStep * k), reason: 'in the doorway, going in');
    // The floor is the porch's top (decisions-log 279): the step its height, the guest on the door's sill.
    expect(townStep, townHouseCells['porch']!.h);
    expect(feet(a)!.dy, b.townBuilding('tavern').firstWhere((c) => c.$1 == 'doorLow').$2.bottom, reason: "on the door's sill");
    for (var i = 0; i < 120 && !a.inside; i++) {
      await frames(tester, 1);
    }
    expect((a.inside, feet(a)), (true, null), reason: 'inside: not drawn');
    for (var i = 0; i < 120 && a.inside; i++) {
      await frames(tester, 1);
    }
    expect((a.doing, a.up, feet(a)!.dy), (TownDo.tavern, true, lane - townStep * k), reason: 'in the doorway, coming out');
    for (var i = 0; i < 120 && a.doing == TownDo.tavern; i++) {
      await frames(tester, 1);
    }
    expect(a.up, isFalse, reason: 'stepped down');
    expect(feet(a)!.dy, lane + a.depth * k, reason: 'back on the street');
  });

  // Every troop's soles on its line (decisions-log 292; the owner, 2026-10-09, of a priest resting in the tent: still a
  // little up, its feet floating over the tent's hem). Until then every troop was drawn with its frame's row 59 on its
  // line (the field's anchor, where its shadow goes), and its feet end on row 56: 4 world px over it.
  test("townFeet: each troop type's feet's last row in its idle strip, in every frame, in the body's own columns 44-55 "
      "(the staffs and the swordsman's blade beside it, and the Soldier's baked-in shadow, left out)", () async {
    expect(townFeet.keys.toSet(), troopTypes.keys.toSet());
    for (final type in troopTypes.keys) {
      final (px, w, h) = await _pixels('assets/images/tiny_${type}_idle.png');
      final (sh, sw, shh) = await _pixels('assets/images/tiny_${type}_shadow.png');
      final ink = {for (var i = 0; i < sw * shh * 4; i += 4) if (sh.getUint8(i + 3) != 0) sh.getUint32(i)};
      bool body(int x, int y) {
        final v = px.getUint32((y * w + x) * 4);
        return v & 0xff != 0 && !ink.contains(v);
      }

      for (var f = 0; f < w ~/ h; f++) {
        var last = -1;
        for (var y = h - 1; y >= 0 && last < 0; y--) {
          for (var x = 44; x <= 55; x++) {
            if (body(f * h + x, y)) last = y;
          }
        }
        expect(last, townFeet[type], reason: '$type frame $f');
      }
      expect(townSole(type), townFeet[type]! + 1, reason: '$type: the row whose bottom edge stands on the line');
    }
  }, tags: 'art');

  for (final size in const [Size(1600, 947), Size(1266, 713)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets("every troop type's soles on its line at $tag, to the px: resting in the tent's opening on its hem's top "
        "(townTentStep over the street: inside is higher), in the Tavern's doorway on its sill (townStep), on the street "
        'on the strip at its depth (0 and 4)', (tester) async {
      final dice = ScriptDice(); // every roll a stroll
      final b = await boot(tester, size)..townDice = dice;
      b.autoStart.set(false);
      final g = await intoTown(tester, b);
      await settle(tester, b);
      // The book shut: the tent and the Tavern's door on the screen.
      await tester.tapAt(Offset(b.bookArea.left / 2, b.waveMeter.bottom + 40));
      await frames(tester, 60);
      final life = b.townLife, k = b.townK, lane = b.townLane;
      final hem = lane - townTentStep * k, sill = b.townBuilding('tavern').firstWhere((c) => c.$1 == 'doorLow').$2.bottom;
      expect((townTentStep, townStep, lane - sill), (4.0, 8.0, townStep * k), reason: "the floors stay (274, 279)");
      final tent = b.townScene['tent']!; // the tent and the fire's pot: their bottoms on the street
      expect(tent.bottom, lane);
      for (final type in troopTypes.keys) {
        final units = [for (var i = 0; i < 4; i++) troop(type)];
        g.units
          ..removeWhere((u) => u.side == Side.troop)
          ..addAll(units);
        // Their depths as they join: 0, 0, 0 and 4 (each draws its depth, then its strips' head start).
        dice.queue
          ..clear()
          ..addAll([0, 0, 0, 0, 0, 0, 0.9, 0]);
        await frames(tester, 2);
        TownFolk of(Unit u) => life.folk.firstWhere((f) => identical(f.unit, u));
        final [rest, guest, near, far] = [for (final u in units) of(u)];
        expect((near.depth, far.depth), (0.0, 4.0), reason: type);
        void put(TownFolk f, TownDo what, double x, {bool up = false}) => f
          ..doing = what
          ..mate = null
          ..slot = 0
          ..inside = false
          ..up = up
          ..x = x
          ..goal = double.nan
          ..dir = 1
          ..from = life.t + 1e6 // a guest stays in its doorway
          ..until = double.infinity;
        put(rest, TownDo.rest, life.spots['tent']!, up: true);
        put(guest, TownDo.tavern, life.spots['tavernDoor']!, up: true);
        put(near, TownDo.stroll, life.spots['tent']! + 80);
        put(far, TownDo.stroll, life.spots['tent']! + 110);
        await frames(tester, 2);
        final canvas = _Placed();
        b.render(canvas);
        final idle = b.game.images.fromCache('tiny_${type}_idle.png');
        for (final (f, line, where) in [(rest, hem, "the tent's hem"), (guest, sill, 'the sill'), (near, lane, 'the street'),
          (far, lane + 4 * k, 'the street, 4 under its edge')]) {
          final feet = b.townFolk.firstWhere((e) => identical(e.unit, f.unit)).feet!;
          final drawn = [
            for (final (image, dst, at, scale) in canvas.images)
              if (identical(image, idle) && at.dx == feet.dx) at.dy + (dst.top + townFeet[type]! + 1) * scale.dy,
          ];
          // The last row of its feet ends on the line: their bottom edge is the line's y, to the px.
          expect(drawn, [line], reason: '$type on $where');
          expect(feet.dy, line, reason: '$type: townFolk\'s feet are the line');
        }
        expect(hem, lessThan(lane), reason: 'inside is higher');
        expect(tent.contains(Offset(rest.sx, hem - 1)), isTrue, reason: "$type: in the tent's opening");
      }
      b.state = Game();
      await frames(tester, 10);
    });
  }
}
