// The field's rings, the Hero's halo and a dragged troop's reach in the sprites' pixels (decisions-log 325; ui-hud.md
// "The field's rings in pixels"; lib/pixel_shapes.dart). The cells: a ring is a stepped oval one cell thick filling its
// box, a dashed ring half of it turning with its steps, the halo 4 bands of alpha fainter outward, the reach a filled
// disc. Drawn at zooms that are no whole number and read back pixel by pixel: the Pusaka's ring (each pixel its
// Pusaka's colour at 90% or nothing, on the cells one world unit each, 20 x 8 round the feet, every colour as before),
// the halo (each pixel white at one of its bands' alphas or nothing) and the reach (white at 12% or nothing). On the
// field: a troop drawn with and without its type's Pusaka, a guard or Spear Wall's brace, and a monster with and without
// a slow and a Barrier, differ round the feet only on that ring's cells. Booted TdGames, seeded.
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'town_hud_test.dart' show boot, frames;

/// Every Pusaka's ring colour before the rings went to pixels (ui-hud.md "The Pusaka in battle"), and the cream of one
/// without its own (Moonwell).
const colours = {
  Relic.dragonHeart: Color(0xFFFF6A1F),
  Relic.dawnStar: Color(0xFFFF7FD0),
  Relic.godThunder: Color(0xFFFFF04A),
  Relic.grail: Color(0xFF3FE6FF),
  Relic.voidEye: Color(0xFF1A0A2E),
  Relic.ironBanner: Color(0xFF9AA8BC),
  Relic.bloodFang: Color(0xFF8E0E2A),
  Relic.warDrum: Color(0xFFC98A4B),
  Relic.mourningBell: Color(0xFFB4A7D6),
  Relic.dragonCrown: Color(0xFF2FD6A0),
  Relic.moonwell: Color(0xFFFFF1D6),
};

/// The Pusaka ring's box in world units (20 x 8, as before) and where its image (the cells and a clear pixel round
/// them) sits from the feet: the box centred 1 above them.
const ringW = 20, ringH = 8, imageAt = Offset(-11, -6);

/// The other rings' boxes and where their images sit from the feet: the guard's 16 x 7 (its odd height half a unit
/// higher), Spear Wall's brace 18 x 8, the effects' first two, 18 x 8 and 14 x 6.
const guardRing = (w: 16, h: 7, at: Offset(-9, -6)), braceRing = (w: 18, h: 8, at: Offset(-10, -6));
const effectRings = [(w: 18, h: 8, at: Offset(-10, -6)), (w: 14, h: 6, at: Offset(-8, -5))];

/// The halo's band alphas (0-255), from the middle out: the old gradient's at each band's middle.
const haloAlphas = [203, 168, 128, 43];

/// The cells of a [w] x [h] ring as rows of '#' (a cell) and '.'.
List<String> picture(int w, int h) {
  final cells = pixelRingCells(w, h).toSet();
  return [for (var j = 0; j < h; j++) [for (var i = 0; i < w; i++) cells.contains((i, j)) ? '#' : '.'].join()];
}

/// The shape cell screen pixel ([x], [y])'s middle samples when its image's top left is [at] from [ground] (world
/// units), drawn at [origin] + world × [k]: null when the middle is within a hair of a cell's edge (either cell may take
/// it). Cells count from the image's clear border's inside, so (-1, ...) is the border.
(int, int)? cellAt(int x, int y, Offset ground, Offset origin, double k, [Offset at = imageAt]) {
  final u = (x + 0.5 - origin.dx) / k - ground.dx - at.dx, v = (y + 0.5 - origin.dy) / k - ground.dy - at.dy;
  const hair = 0.02;
  if ((u - u.round()).abs() < hair || (v - v.round()).abs() < hair) return null;
  return (u.floor() - 1, v.floor() - 1);
}

/// Pixel ([x], [y]) of straight RGBA [px] [w] wide: (r, g, b, a).
(int, int, int, int) pixel(ByteData px, int w, int x, int y) {
  final at = (y * w + x) * 4;
  return (px.getUint8(at), px.getUint8(at + 1), px.getUint8(at + 2), px.getUint8(at + 3));
}

/// [pic] rasterised [w] x [h] and read back as straight RGBA.
Future<ByteData> readBack(WidgetTester tester, ui.Picture pic, int w, int h) async => (await tester.runAsync(() async {
      final img = await pic.toImage(w, h);
      final px = await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      img.dispose();
      return px!;
    }))!;

void main() {
  group('the cells', () {
    test('20 x 8, the ring under a troop: a stepped oval one cell thick', () {
      expect(picture(ringW, ringH), [
        '.....##########.....',
        '..###..........###..',
        '.#................#.',
        '#..................#',
        '#..................#',
        '.#................#.',
        '..###..........###..',
        '.....##########.....',
      ]);
    });

    for (final (w, h) in [(20, 8), (16, 7), (18, 7), (24, 9), (32, 13)]) {
      test('$w x $h: fills its box, mirrors both ways, closed, never two cells thick', () {
        final cells = pixelRingCells(w, h).toSet();
        expect(cells.every((c) => c.$1 >= 0 && c.$1 < w && c.$2 >= 0 && c.$2 < h), isTrue, reason: 'inside its box');
        expect([for (final c in cells) c.$1].reduce(min), 0);
        expect([for (final c in cells) c.$1].reduce(max), w - 1);
        expect([for (final c in cells) c.$2].reduce(min), 0);
        expect([for (final c in cells) c.$2].reduce(max), h - 1);
        for (final (i, j) in cells) {
          expect(cells.contains((w - 1 - i, j)), isTrue, reason: '($i, $j) mirrored across');
          expect(cells.contains((i, h - 1 - j)), isTrue, reason: '($i, $j) mirrored down');
          final near = [for (var dx = -1; dx <= 1; dx++) for (var dy = -1; dy <= 1; dy++) if (dx != 0 || dy != 0) (i + dx, j + dy)];
          expect(near.where(cells.contains).length, greaterThanOrEqualTo(2), reason: '($i, $j): the line goes on both ways');
          expect(cells.containsAll([(i + 1, j), (i, j + 1), (i + 1, j + 1)]), isFalse, reason: '($i, $j): no 2x2 block');
        }
        // One loop: every cell reached from the first through its eight neighbours.
        final seen = {cells.first}, todo = [cells.first];
        while (todo.isNotEmpty) {
          final (i, j) = todo.removeLast();
          for (var dx = -1; dx <= 1; dx++) {
            for (var dy = -1; dy <= 1; dy++) {
              final n = (i + dx, j + dy);
              if (cells.contains(n) && seen.add(n)) todo.add(n);
            }
          }
        }
        expect(seen.length, cells.length, reason: 'one closed line');
      });
    }
  });

  group('the other shapes\' cells', () {
    for (final (w, h) in [(18, 8), (14, 6), (10, 4), (6, 2)]) {
      test('$w x $h dashed: on its ring, every cell at some step; from 14 x 6 up about half at each step, turning', () {
        final ring = pixelRingCells(w, h).toSet(), every = <(int, int)>{};
        List<(int, int)>? last;
        for (var p = 0; p < dashPhases; p++) {
          final on = pixelDashCells(w, h, p);
          expect(ring.containsAll(on), isTrue, reason: 'step $p: on the ring');
          if (w >= 14) {
            expect(on.length, inInclusiveRange(ring.length * 0.25, ring.length * 0.75), reason: 'step $p: about half of it');
            expect(on, isNot(last), reason: 'step $p: turned from the last');
          }
          every.addAll(on);
          last = on;
        }
        expect(every, ring, reason: 'every cell shows at some step');
      });
    }

    for (var r = haloRadii.from; r <= haloRadii.to; r++) {
      test('the halo at radius $r: $haloBands bands of the old gradient, fainter outward, round and mirrored', () {
        final halo = pixelHaloCells(r);
        expect(halo.values.toSet(), haloAlphas.toSet(), reason: 'its band alphas');
        double out((int, int) c) => sqrt(pow(c.$1 + 0.5 - r, 2) + pow(c.$2 + 0.5 - r, 2));
        for (final MapEntry(key: c, value: a) in halo.entries) {
          expect(out(c), lessThanOrEqualTo(r), reason: '$c: inside the circle');
          expect(halo[(2 * r - 1 - c.$1, c.$2)], a, reason: '$c: mirrored across');
          expect(halo[(c.$1, 2 * r - 1 - c.$2)], a, reason: '$c: mirrored down');
          expect(a, haloAlphas[min(haloBands - 1, (out(c) / r * haloBands).floor())], reason: '$c: its band');
        }
        expect(halo.length, closeTo(pi * r * r, pi * r * r * 0.06), reason: 'a disc');
      });
    }

    for (final r in [12, 13, 14, 22, 64, 72, 96]) {
      test('the reach at range $r: a filled disc, one run a row, mirrored', () {
        final disc = pixelDiscCells(r).toSet();
        for (var j = 0; j < 2 * r; j++) {
          final row = [for (var i = 0; i < 2 * r; i++) if (disc.contains((i, j))) i];
          expect(row, isNotEmpty, reason: 'row $j');
          expect(row.last - row.first + 1, row.length, reason: 'row $j: one run');
          expect(row.first + row.last, 2 * r - 1, reason: 'row $j: centred');
          expect(disc.contains((row.first, 2 * r - 1 - j)), isTrue, reason: 'row $j: mirrored down');
        }
        expect(disc.length, closeTo(pi * r * r, pi * r * r * 0.05), reason: 'its area');
      });
    }
  });

  testWidgets('drawn: each pixel its Pusaka\'s colour at 90% or nothing, on the cells, 20 x 8 round the feet, at any zoom',
      (tester) async {
    final b = await boot(tester);
    final cells = pixelRingCells(ringW, ringH).toSet();
    var i = 0;
    for (final MapEntry(key: relic, value: colour) in colours.entries) {
      // Zooms of the test windows' kind, none a whole number, and the feet off the screen's pixels.
      final k = const [3.37, 2.41, 1.73, 4.62][i % 4], origin = Offset(0.31 + 0.17 * i, 0.77 - 0.05 * i);
      i++;
      const ground = Offset(13.4, 9.7);
      final w = ((ground.dx + 14) * k).ceil(), h = ((ground.dy + 8) * k).ceil();
      final rec = ui.PictureRecorder(), c = Canvas(rec)
        ..translate(origin.dx, origin.dy)
        ..scale(k);
      b.paintPusakaRing(c, ground, relic);
      final px = await readBack(tester, rec.endRecording(), w, h);
      var lit = 0, left = w, right = -1, top = h, bottom = -1;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final (r, g, bl, a) = pixel(px, w, x, y);
          final tag = '${relic.name} at k $k, pixel ($x, $y)';
          expect(a == 0 || (a - 0.9 * 255).abs() <= 1, isTrue, reason: '$tag: alpha $a, nothing in between (no anti-alias)');
          if (a > 0) {
            lit++;
            (left, right, top, bottom) = (min(left, x), max(right, x), min(top, y), max(bottom, y));
            expect([(r - (colour.r * 255).round()).abs(), (g - (colour.g * 255).round()).abs(), (bl - (colour.b * 255).round()).abs()],
                everyElement(lessThanOrEqualTo(2)), reason: '$tag: ($r, $g, $bl), its colour');
          }
          if (cellAt(x, y, ground, origin, k) case final cell?) {
            expect(a > 0, cells.contains(cell), reason: '$tag: cell $cell');
          }
        }
      }
      expect(lit, greaterThan(cells.length * (k * k).floor() * 0.8), reason: '${relic.name}: every cell drawn');
      // Its box: 20 x 8 world units, centred 1 above the feet, to a screen pixel.
      final box = Rect.fromLTRB(left + 0.0, top + 0.0, right + 1.0, bottom + 1.0);
      final want = Rect.fromCenter(center: origin + (ground - const Offset(0, 1)) * k, width: ringW * k, height: ringH * k);
      for (final (got, wanted) in [(box.left, want.left), (box.top, want.top), (box.right, want.right), (box.bottom, want.bottom)]) {
        expect((got - wanted).abs(), lessThanOrEqualTo(1), reason: '${relic.name} at k $k: box $box, want $want');
      }
    }
  });

  for (final size in const [Size(1600, 947), Size(915, 412)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('on the field at $tag: a bound type\'s troop differs round its feet only on the ring\'s cells', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = Game(Random(1), Random(2)).boardRules()..armyMax = null;
      final at = Point(g.baseX + tile * 2, tile * 3.0);
      final u = Unit(Side.troop, 'archer', g.statsOf('archer'), at)
        ..post = at
        ..entered = true
        ..arriving = false;
      g.units.add(u);
      await frames(tester, 4);

      // The frame as the screen gets it, drawn now (no step between the two).
      Future<ByteData> field() async {
        final rec = ui.PictureRecorder();
        b.render(Canvas(rec));
        return readBack(tester, rec.endRecording(), size.width.toInt(), size.height.toInt());
      }

      final plain = await field();
      g.givePusaka(Relic.godThunder, type: 'archer');
      final ringed = await field();
      // World units to the screen: toScreen(0, 0) + world × k.
      final origin = b.toScreen(0, 0), k = b.toScreen(1, 0).dx - origin.dx;
      final ground = Offset(u.pos.x, u.pos.y + 5), feet = b.toScreen(ground.dx, ground.dy), w = size.width.toInt();
      expect((Offset.zero & size).contains(feet), isTrue, reason: '$tag: the troop is in view');
      final cells = pixelRingCells(ringW, ringH).toSet(), shown = <(int, int)>{};
      var changed = 0;
      final area = Rect.fromCenter(center: feet, width: 26 * k, height: 14 * k);
      for (var y = max(0, area.top.floor()); y < min(size.height, area.bottom).ceil(); y++) {
        for (var x = max(0, area.left.floor()); x < min(size.width, area.right).ceil(); x++) {
          if (pixel(plain, w, x, y) == pixel(ringed, w, x, y)) continue;
          changed++;
          final cell = cellAt(x, y, ground, origin, k);
          if (cell == null) continue;
          expect(cells.contains(cell), isTrue, reason: '$tag: pixel ($x, $y) changed off the ring, on $cell');
          shown.add(cell);
        }
      }
      expect(changed, greaterThan(0), reason: '$tag: the ring is drawn');
      expect(shown.length, greaterThanOrEqualTo(cells.length ~/ 2), reason: '$tag: the ring shows round the body');
      b.state = Game();
      await frames(tester);
    });
  }
  testWidgets('drawn: the halo white in its bands or nothing, the reach white at 12% or nothing, on their cells, at any zoom',
      (tester) async {
    final b = await boot(tester);
    var i = 0;
    for (var r = haloRadii.from; r <= haloRadii.to; r++, i++) {
      final k = const [3.37, 2.41, 1.73, 4.62][i % 4], origin = Offset(0.31 + 0.17 * i, 0.77 - 0.05 * i);
      final middle = Offset(r + 2.4, r + 2.7), halo = pixelHaloCells(r), w = ((2 * r + 6) * k).ceil();
      final rec = ui.PictureRecorder(), c = Canvas(rec)
        ..translate(origin.dx, origin.dy)
        ..scale(k);
      b.paintHeroHalo(c, middle, r);
      final px = await readBack(tester, rec.endRecording(), w, w);
      for (var y = 0; y < w; y++) {
        for (var x = 0; x < w; x++) {
          final (red, g, bl, a) = pixel(px, w, x, y);
          final tag = 'halo $r at k $k, pixel ($x, $y)';
          expect(a == 0 || haloAlphas.any((h) => (h - a).abs() <= 1), isTrue, reason: '$tag: alpha $a, a band or nothing');
          if (a > 0) expect(min(red, min(g, bl)), greaterThanOrEqualTo(250), reason: '$tag: white');
          if (cellAt(x, y, middle, origin, k, Offset(-r - 1.0, -r - 1.0)) case final cell?) {
            expect((a - (halo[cell] ?? 0)).abs(), lessThanOrEqualTo(1), reason: '$tag: cell $cell');
          }
        }
      }
    }
    for (final range in [12.0, 64.0, 96.0]) {
      final k = const [1.73, 3.37, 2.41][i++ % 3], origin = Offset(0.43, 0.29), r = range.round();
      final middle = Offset(r + 3.0, r + 3.0), disc = pixelDiscCells(r).toSet(), w = ((2 * r + 6) * k).ceil();
      final rec = ui.PictureRecorder(), c = Canvas(rec)
        ..translate(origin.dx, origin.dy)
        ..scale(k);
      b.paintReachDisc(c, middle, range, 0.12);
      final px = await readBack(tester, rec.endRecording(), w, w);
      for (var y = 0; y < w; y++) {
        for (var x = 0; x < w; x++) {
          final (_, _, _, a) = pixel(px, w, x, y);
          final tag = 'reach $r at k $k, pixel ($x, $y)';
          expect(a == 0 || (a - 0.12 * 255).abs() <= 1, isTrue, reason: '$tag: alpha $a, 12% or nothing');
          if (cellAt(x, y, middle, origin, k, Offset(-r - 1.0, -r - 1.0)) case final cell?) {
            expect(a > 0, disc.contains(cell), reason: '$tag: cell $cell');
          }
        }
      }
    }
  });

  testWidgets('on the field at 1600x947: a guard, a slow and a Barrier, and Spear Wall\'s brace differ only on their rings',
      (tester) async {
    const size = Size(1600, 947);
    final b = await boot(tester, size);
    final g = b.state = Game(Random(1), Random(2)).boardRules()..armyMax = null;
    Unit troop(double row) {
      final at = Point(g.baseX + tile * 2, tile * row);
      final u = Unit(Side.troop, 'knight', g.statsOf('knight'), at)
        ..post = at
        ..entered = true
        ..arriving = false;
      g.units.add(u);
      return u;
    }

    final guarded = troop(1), braced = troop(3);
    await frames(tester, 4);
    // A monster on the field (a wave on, so a brace holds), never stepped.
    final foe = Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, Point(g.baseX + tile * 8, tile * 5.0));
    g.units.add(foe);

    Future<ByteData> field() async {
      final rec = ui.PictureRecorder();
      b.render(Canvas(rec));
      return readBack(tester, rec.endRecording(), size.width.toInt(), size.height.toInt());
    }

    final origin = b.toScreen(0, 0), k = b.toScreen(1, 0).dx - origin.dx;
    // The cells, from the feet, of the rings [rings] (each its size and where its image sits).
    Set<(int, int)> placed(List<({int w, int h, Offset at})> rings) => {
          for (final ring in rings)
            for (final (i, j) in pixelRingCells(ring.w, ring.h)) (ring.at.dx.toInt() + 1 + i, ring.at.dy.toInt() + 1 + j),
        };
    // [before] and [after] differ round [u]'s feet, within [rows] (from the feet) only on [cells], and on at least
    // [share] of the cells there.
    void onlyOn(ByteData before, ByteData after, Unit u, Set<(int, int)> cells, String tag,
        {(int, int) rows = (-7, 4), double share = 0.5}) {
      final ground = Offset(u.pos.x, u.pos.y + 5), feet = b.toScreen(ground.dx, ground.dy);
      expect((Offset.zero & size).contains(feet), isTrue, reason: '$tag: in view');
      final shown = <(int, int)>{}, w = size.width.toInt();
      final top = (feet.dy + rows.$1 * k).floor(), bottom = (feet.dy + rows.$2 * k).ceil();
      for (var y = top; y < bottom; y++) {
        for (var x = (feet.dx - 13 * k).floor(); x < (feet.dx + 13 * k).ceil(); x++) {
          if (pixel(before, w, x, y) == pixel(after, w, x, y)) continue;
          final cell = cellAt(x, y, ground, origin, k, const Offset(-1, -1));
          if (cell == null) continue;
          expect(cells.contains(cell), isTrue, reason: '$tag: pixel ($x, $y) changed off its ring, on $cell');
          shown.add(cell);
        }
      }
      final there = cells.where((c) => c.$2 >= rows.$1 && c.$2 < rows.$2).length;
      expect(shown.length, greaterThanOrEqualTo((there * share).floor()), reason: '$tag: its ring shows');
    }

    final plain = await field();
    guarded
      ..guardUntil = g.t + 10
      ..guardLook = RingLook.holy;
    onlyOn(plain, await field(), guarded, placed([guardRing]), 'the guard');
    guarded.guardUntil = double.negativeInfinity;
    foe
      ..effects[Status.slow] = Effect(g.t + 10, 0.5, bad: true)
      ..shield = 100;
    onlyOn(plain, await field(), foe, placed(effectRings), 'a slow and a Barrier', share: 0.3); // a werebear hides more
    foe
      ..effects.clear()
      ..shield = 0;
    braced.brace = Brace(g.t + 10);
    expect(g.braced(braced), isTrue);
    // The brace holds the body at its thrust, so only the ring's rows under the feet count.
    onlyOn(plain, await field(), braced, placed([braceRing]), 'the brace', rows: (0, 3), share: 0.8);
    b.state = Game();
    await frames(tester);
  });
}
