// #84: where melee troops stand to fight (lib/engage.dart) and monsters that meet troops fight them.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// A wave on with nothing more to come and no skills of any kind, so where the troops go is the spots' doing.
Game engageGame() {
  final g = bareGame()
    ..skills = false
    ..heroSkills = false
    ..monsterSkills = false;
  g
    ..startWave()
    ..queue.clear();
  return g;
}

/// A monster at [at] that stands and never fights ([foeAt]), with HP to outlast any test.
Unit tough(Game g, Point<double> at, [String type = 'orc']) => foeAt(g, type, at)
  ..maxHp = 1000000
  ..hp = 1e6;

/// [n] soldiers from cell (0, 0) down the zone's first columns.
List<Unit> soldiers(Game g, int n) => [for (var i = 0; i < n; i++) placeNow(g, 'soldier', i ~/ rows, i % rows)];

bool inReach(Unit u, Unit m) => u.pos.distanceTo(m.pos) <= u.stats.range + spotSlack;

void main() {
  test('eight spots round a monster like a compass, filled front first and the back last', () {
    expect(spotCount, 8);
    expect(Spot.values.length, spotCount);
    expect({for (final row in spotFill) ...row}, Spot.values.toSet());
    expect([for (final row in spotFill) ...row].length, spotCount);
    expect(spotFill.first, [Spot.front]);
    expect(spotFill.last, [Spot.back]);
    final g = engageGame(), s = placeNow(g, 'soldier', 2, 3), lancer = placeNow(g, 'lancer', 2, 4);
    final m = tough(g, Point(12 * tile, 3.5 * tile));
    expect(g.spotPoint(s, m, Spot.front), m.pos + Point(-(s.stats.range - spotSlack), 0));
    expect(g.spotPoint(s, m, Spot.top).y, lessThan(m.pos.y));
    expect(g.spotPoint(s, m, Spot.back).x, greaterThan(m.pos.x));
    // Sized to the troop's reach: a lancer stands further out than a soldier.
    expect(g.spotRing(lancer, m), greaterThan(g.spotRing(s, m)));
    for (final spot in Spot.values) {
      expect(g.spotPoint(s, m, spot).distanceTo(m.pos), lessThanOrEqualTo(s.stats.range), reason: '$spot');
    }
  });

  test('a melee troop with no foe in reach walks to the front spot of the nearest monster and fights from there', () {
    final g = engageGame();
    final s = placeNow(g, 'soldier', 2, 1);
    final m = tough(g, Point(12 * tile, 3.5 * tile));
    runFor(g, 10);
    expect((s.spotOf, s.spot), (m, Spot.front));
    expect(s.pos.distanceTo(g.spotPoint(s, m, Spot.front)), lessThan(2));
    expect(inReach(s, m), isTrue);
    expect(g.t - s.attackedAt, lessThan(1)); // fighting
  });

  test('the spots fill in order: front, beside it, top and bottom, then round to the back', () {
    final g = engageGame();
    final us = soldiers(g, 6);
    final m = tough(g, Point(12 * tile, 3.5 * tile));
    g.tick(0.05);
    final spots = {for (final u in us) u.spot};
    expect(spots, containsAll([Spot.front, Spot.frontTop, Spot.frontBottom, Spot.top, Spot.bottom]));
    expect(spots.intersection({Spot.backTop, Spot.backBottom}).length, 1); // the sixth flanks
    expect(spots.contains(Spot.back), isFalse);
    expect(us.every((u) => u.spotOf == m), isTrue);
  });

  test('with the front spots taken a troop flanks round to the back and hits from there', () {
    final g = engageGame();
    final us = soldiers(g, 6);
    final m = tough(g, Point(12 * tile, 3.5 * tile));
    runFor(g, 15);
    final back = us.singleWhere((u) => u.spot == Spot.backTop || u.spot == Spot.backBottom);
    expect(back.pos.x, greaterThan(m.pos.x + 4)); // behind the monster
    expect(inReach(back, m), isTrue);
    expect(g.t - back.attackedAt, lessThan(1));
    expect(us.where((u) => inReach(u, m)).length, 6);
  });

  test('a monster with every spot taken: the next troop goes to the nearest monster with a free one', () {
    final g = engageGame();
    final us = soldiers(g, 9);
    final a = tough(g, Point(10 * tile, 3.5 * tile)), b = tough(g, Point(16 * tile, 3.5 * tile));
    runFor(g, 20);
    final onA = us.where((u) => u.spotOf == a).toList(), onB = us.where((u) => u.spotOf == b).toList();
    expect(onA.length, spotCount);
    expect({for (final u in onA) u.spot}.length, spotCount); // one troop a spot
    expect(onA.every((u) => inReach(u, a)), isTrue, reason: 'all eight hit it');
    expect(onB.length, 1);
    expect(inReach(onB.single, b), isTrue);
  });

  test('with every spot taken the extra troop waits just behind the fighters and steps into the first spot that frees', () {
    final g = engageGame();
    final us = soldiers(g, 9);
    final m = tough(g, Point(12 * tile, 3.5 * tile));
    runFor(g, 20);
    final waiter = us.singleWhere((u) => u.spotOf == null);
    expect(waiter.waiting, isTrue);
    expect(waiter.pos.distanceTo(m.pos), lessThanOrEqualTo(3 * tile));
    expect(waiter.pos.x, lessThan(m.pos.x - waiter.stats.range)); // behind the front fighter, not in the ring
    final gone = us.firstWhere((u) => u.spot == Spot.frontTop)
      ..hp = 0
      ..dying = 0; // it falls: its spot frees
    runFor(g, 3);
    expect(gone.alive, isFalse);
    expect((waiter.waiting, waiter.spotOf), (false, m));
    expect(inReach(waiter, m), isTrue);
    expect(g.t - waiter.attackedAt, lessThan(1));
  });

  test('a troop that already reaches a foe fights from where it stands and holds the spot on its side', () {
    final g = engageGame();
    final m = tough(g, Point(12 * tile, 3.5 * tile));
    final s = placeNow(g, 'soldier', 2, 3)..pos = m.pos + const Point(0, -11);
    g.tick(0.05);
    expect((s.spotOf, s.spot), (m, Spot.top));
    expect(s.moving, isFalse);
    // The next troop doesn't get that spot.
    final t = placeNow(g, 'soldier', 2, 2);
    g.tick(0.05);
    expect(t.spot, Spot.front);
  });

  test('spots off the field or inside another monster are not taken', () {
    final g = engageGame();
    final us = soldiers(g, 6);
    final m = tough(g, Point(12 * tile, 6)); // on the top edge: no room above it
    final behind = tough(g, m.pos + const Point(14, 0)); // right behind it: no room at its back
    g.tick(0.05);
    final spots = {for (final u in us) if (u.spotOf == m) u.spot};
    expect(spots.intersection({Spot.frontTop, Spot.top, Spot.backTop, Spot.back}), isEmpty);
    expect(spots, containsAll([Spot.front, Spot.frontBottom, Spot.bottom]));
    expect(us.where((u) => u.spotOf == behind), isNotEmpty); // the rest go on to the next monster
  });

  test('two troops walking to spots of one monster swap them rather than cross', () {
    final g = engageGame();
    final m = tough(g, Point(12 * tile, 3.5 * tile));
    final up = placeNow(g, 'soldier', 2, 1), down = placeNow(g, 'soldier', 2, 6);
    up
      ..spotOf = m
      ..spot = Spot.frontBottom;
    down
      ..spotOf = m
      ..spot = Spot.frontTop;
    g.tick(0.05);
    expect((up.spot, down.spot), (Spot.frontTop, Spot.frontBottom));
  });

  test('long range troops and healers keep their own rules: no spots', () {
    final g = engageGame();
    final archer = placeNow(g, 'archer', 0, 2), priest = placeNow(g, 'priest', 0, 4), s = placeNow(g, 'soldier', 2, 3);
    tough(g, Point(14 * tile, 3.5 * tile));
    g.tick(0.05);
    expect((archer.spotOf, archer.waiting, priest.spotOf, priest.waiting), (null, false, null, false));
    expect(s.spotOf, isNotNull);
  });

  test('a troop falling back gives up its spot, and between waves nobody holds one', () {
    final g = engageGame();
    final s = placeNow(g, 'soldier', 2, 3);
    final m = tough(g, Point(12 * tile, 3.5 * tile));
    g.tick(0.05);
    expect(s.spotOf, m);
    s.retreating = true;
    g.tick(0.05);
    expect(s.spotOf, isNull);
    s.retreating = false;
    g.tick(0.05);
    expect(s.spotOf, m);
    m.gone = true;
    g.tick(0.05);
    expect(g.waveActive, isFalse);
    g.tick(0.05);
    expect((s.spotOf, s.spot, s.waiting), (null, null, false));
  });

  group('monsters meet troops and fight them', () {
    /// A monster of [type] at [at] that walks and fights on its own, with HP to outlast the test.
    Unit walker(Game g, Point<double> at, [String type = 'orc']) {
      final m = g.monster(type, Tier.normal, at)
        ..entered = true
        ..maxHp = 1000000
        ..hp = 1e6;
      g.units.add(m);
      return m;
    }

    /// A troop at [at] that stands and never fights, with HP to outlast the test.
    Unit post(Game g, String type, Point<double> at) => placeNow(g, type, 0, 0)
      ..pos = at
      ..busyUntil = hold
      ..maxHp = 1000000
      ..hp = 1e6;

    test('a monster whose way to the troop it goes for runs into another fights that one instead of squeezing past', () {
      final g = engageGame();
      final m = walker(g, const Point(140, 56));
      final behind = post(g, 'knight', const Point(126.5, 56)); // the nearest, just out of reach
      final inWay = post(g, 'soldier', const Point(132, 45)); // a little further, but 11 off the way: its body is in it
      runFor(g, 2);
      expect(inWay.hp, lessThan(1e6)); // it fought the one it met
      expect(behind.hp, 1e6);
      expect(m.pos.x, greaterThan(inWay.pos.x)); // and never got past it
    });

    test('through a real gap, a troop more than a body off its way, a monster walks on to the troop it goes for', () {
      final g = engageGame();
      final m = walker(g, const Point(150, 56));
      final target = post(g, 'knight', const Point(124, 56)); // the nearest all the way
      final aside = post(g, 'soldier', const Point(138, 80)); // 24 off its way: a real gap
      runFor(g, 4);
      expect(target.hp, lessThan(1e6));
      expect(aside.hp, 1e6);
      expect(m.pos.x, lessThan(aside.pos.x)); // it walked on past it
    });

    test('a monster walking up behind one that fights does not shove it on into the troops; it slides round', () {
      final g = engageGame();
      final t = post(g, 'knight', const Point(100, 56));
      final front = walker(g, const Point(112, 56)), back = walker(g, const Point(130, 56));
      final start = t.pos;
      var frontMax = 0.0;
      for (var i = 0; i < 100; i++) {
        g.tick(0.05);
        frontMax = max(frontMax, front.pos.distanceTo(t.pos));
      }
      expect(t.pos.distanceTo(start), lessThan(4)); // the troop wasn't driven back by the crowd (main: ~20 px)
      expect(front.pos.x, greaterThan(t.pos.x + 6)); // the front monster wasn't pushed past it
      expect(frontMax, lessThanOrEqualTo(front.stats.range + 2)); // it kept fighting from its reach
      expect((back.pos.y - 56).abs(), greaterThan(4)); // the one behind went round
      expect(back.pos.distanceTo(t.pos), lessThanOrEqualTo(back.stats.range + 2)); // and fights it too
    });

    test('Trample still gallops through the troops: a skill, not a slip', () {
      final g = engageGame()..monsterSkills = true;
      final rider = walker(g, const Point(200, 56), 'orc_rider')..tier = Tier.highElite;
      final wall = [for (final y in [40.0, 56.0, 72.0]) post(g, 'soldier', Point(150, y))];
      final back = post(g, 'archer', const Point(120, 56));
      rider.skillAt = double.negativeInfinity;
      var passed = false;
      for (var i = 0; i < 200 && !passed; i++) {
        g.tick(0.05);
        passed = rider.pos.x < wall.first.pos.x - 6;
      }
      expect(passed, isTrue);
      expect(back.alive, isTrue);
    });
  });
}

