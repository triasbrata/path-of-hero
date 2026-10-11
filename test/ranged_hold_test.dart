// The long range's hold (decisions-log 199, units-and-combat.md "Long range hold"): a shooter stands no further from
// the foe it shoots than its shot flies in [rangedFlight] s, at least [rangedGap] off, within its reach; a troop
// shooter backs off a foe nearer than [Engage.kiteAt]; a monster shooter walks to its hold the same way.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// [base] with [n] bows.
Stats bows(Stats base, int n) => List.filled(n, Item.bow).fold(base, (s, i) => s.upgraded(i));

/// A wave under way with nothing left to spawn and every skill off: what moves is the hold and the kite.
Game wave() => bareGame(Random(1))
  ..viewW = 341
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false
  ..monsterSkills = false;

/// An archer with [n] bows on cell (2, [r]), in a wave begun with nothing left to spawn.
Unit archer(Game g, int n, [int r = 3]) {
  g.upgrades['archer'] = List.filled(n, Item.bow);
  final a = placeNow(g, 'archer', 2, r);
  if (!g.waveActive) {
    g
      ..startWave()
      ..queue.clear();
  }
  return a;
}

/// [u] can't fall (the test watches where it stands, not who wins).
Unit tough(Unit u) => u
  ..maxHp = 1 << 30
  ..hp = 1e9;

void main() {
  test('a shooter holds at its shot flight of rangedFlight s, at least rangedGap off, within its reach; others at their reach', () {
    final g = wave();
    Unit troop(String type, Stats s) => Unit(Side.troop, type, s, const Point(100, 60));
    final archer = troopTypes['archer']!, wizard = troopTypes['wizard']!;
    // A base archer (64) and one with a bow (76.8) or two (92.2) hold at their reach; from three bows (110.6) at
    // 100: its arrows' 200/s for 0.5 s. Twelve bows (570, the owner's w89 archers) the same.
    for (final (n, at) in [(0, 64.0), (1, 64 * 1.2), (2, 64 * 1.44), (3, 100.0), (12, 100.0)]) {
      expect(g.holdAt(troop('archer', bows(archer, n))), closeTo(at, 1e-9), reason: 'archer, $n bows');
    }
    // A wizard's orbs fly 140/s: 70, a hair inside its base reach of 72, and so with any bows.
    for (final n in [0, 1, 9]) {
      expect(g.holdAt(troop('wizard', bows(wizard, n))), closeTo(70, 1e-9), reason: 'wizard, $n bows');
    }
    // Slow shots never bring a shooter nearer than 4 tiles, unless its reach is shorter.
    const slow = Stats(hp: 60, cost: 70, speed: 22, dmg: 9, range: 200, rate: 0.6, shotSpeed: 50);
    expect(g.holdAt(troop('archer', slow)), rangedGap);
    // Melee and healers hold at their reach, as before.
    expect(g.holdAt(troop('soldier', troopTypes['soldier']!)), 12);
    expect(g.holdAt(troop('priest', bows(troopTypes['priest']!, 2))), closeTo(96 * 1.44, 1e-9));

    // A skeleton archer's bolts fly 150/s: at its reach of 60 in wave 1, 75 once its reach passes that (90 by w76).
    final early = g.monster('skeleton_archer', Tier.normal, const Point(200, 60));
    expect(g.holdAt(early), closeTo(early.stats.range, 1e-9));
    g.wave = 89;
    final late = g.monster('skeleton_archer', Tier.normal, const Point(200, 60));
    expect(late.stats.range, closeTo(90, 1e-9));
    expect(g.holdAt(late), 75);

    // The kite: a base archer still backs off at 48 (3/4 of 64), a long-reach one under 4 tiles, a wizard under 52.5.
    expect(g.kiteAt(troop('archer', archer)), 48);
    expect(g.kiteAt(troop('archer', bows(archer, 12))), rangedGap);
    expect(g.kiteAt(troop('wizard', bows(wizard, 9))), 52.5);
  });

  test('a long-reach archer steps up to its hold while shooting, and stands there', () {
    final g = wave();
    final a = archer(g, 4); // reach 132.7, hold 100
    final foe = tough(foeAt(g, 'werebear', a.pos + const Point(125, 0)));
    expect(g.reaches(a, foe), isTrue, reason: 'in its reach from the start');
    var shots = 0, walkingShots = 0, last = a.attackedAt;
    for (var i = 0; i < 60; i++) {
      g.tick(0.05);
      if (a.attackedAt != last) {
        (shots, last) = (shots + 1, a.attackedAt);
        if (a.moving) walkingShots++;
      }
      expect(a.dir, 1, reason: 'faces the foe at t=${g.t}');
    }
    expect(walkingShots, greaterThan(0), reason: 'it shot on its way');
    expect(shots, greaterThanOrEqualTo(4));
    expect(a.pos.distanceTo(foe.pos), closeTo(100, 0.5));
    expect(a.moving, isFalse);
  });

  test('out of its reach a long-reach archer walks to its hold, not to the edge of its reach', () {
    final g = wave();
    final a = archer(g, 4);
    final foe = tough(foeAt(g, 'werebear', a.pos + const Point(260, 0)));
    runFor(g, 12);
    expect(a.pos.distanceTo(foe.pos), closeTo(100, 0.5));
    expect(a.moving, isFalse);
  });

  test('a base archer still stands where its reach begins: no step up, no kite', () {
    final g = wave();
    final a = archer(g, 0);
    final foe = tough(foeAt(g, 'werebear', a.pos + const Point(60, 0)));
    final p0 = a.pos;
    runFor(g, 2);
    expect(a.pos, p0);
    expect(a.attackedAt, greaterThan(0));
    expect(g.reaches(a, foe), isTrue);
  });

  test('a long-reach archer backs off a foe within 4 tiles to 4 tiles, shooting, not out to its reach', () {
    final g = wave();
    final a = archer(g, 12); // reach 570: before, it backed off any foe within 428
    final foe = tough(foeAt(g, 'werebear', a.pos + const Point(40, 0)));
    final x0 = a.pos.x;
    var shots = 0, last = a.attackedAt;
    for (var i = 0; i < 40; i++) {
      g.tick(0.05);
      if (a.attackedAt != last) (shots, last) = (shots + 1, a.attackedAt);
    }
    expect(a.pos.x, lessThan(x0 - tile));
    expect(a.pos.distanceTo(foe.pos), inInclusiveRange(rangedGap, rangedGap + 2));
    expect(a.moving, isFalse);
    expect(shots, greaterThanOrEqualTo(2), reason: 'it kept shooting');
  });

  test("a troop doesn't back away from a ranged monster standing at its hold: no drift", () {
    final g = waveOf(89);
    final a = tough(archer(g, 12)); // hold 100, kite under 64
    final m = tough(g.monster('skeleton_archer', Tier.highElite, a.pos + const Point(200, 0))..entered = true);
    g.units.add(m);
    runFor(g, 8);
    final (pa, pm) = (a.pos, m.pos);
    expect(a.pos.distanceTo(m.pos), closeTo(75, 0.5), reason: 'the monster at its hold (reach 90)');
    runFor(g, 8);
    expect(a.pos.distanceTo(pa), lessThan(0.5), reason: 'the archer stands');
    expect(m.pos.distanceTo(pm), lessThan(0.5), reason: 'and so does the monster');
    expect(a.attackedAt, greaterThan(g.t - 2));
    expect(m.attackedAt, greaterThan(g.t - 2));
  });

  test('a monster shooter steps up to its hold while shooting; short of its reach it walks to its hold', () {
    // Wave 89: reach 90, hold 75. In its reach at 88, it steps up to 75, shooting on its way.
    final g = waveOf(89);
    final s = tough(placeNow(g, 'soldier', 2, 3)..busyUntil = hold);
    final m = tough(g.monster('skeleton_archer', Tier.normal, s.pos + const Point(88, 0))..entered = true);
    g.units.add(m);
    expect(g.reaches(m, s), isTrue);
    var walkingShots = 0, last = m.attackedAt;
    for (var i = 0; i < 80; i++) {
      g.tick(0.05);
      if (m.attackedAt != last) {
        last = m.attackedAt;
        if (m.moving) walkingShots++;
      }
    }
    expect(walkingShots, greaterThan(0), reason: 'it shot on its way');
    expect(m.pos.distanceTo(s.pos), closeTo(75, 0.5));
    expect(m.moving, isFalse);

    // Wave 1: reach 60, its hold. From out of reach it walks to it, as before; inside it, it stands.
    for (final (from, at) in [(120.0, 60.0), (40.0, 40.0)]) {
      final h = waveOf(1);
      final t = tough(placeNow(h, 'soldier', 2, 3)..busyUntil = hold);
      final e = tough(h.monster('skeleton_archer', Tier.normal, t.pos + Point(from, 0))..entered = true);
      h.units.add(e);
      runFor(h, 6);
      expect(e.pos.distanceTo(t.pos), closeTo(at, 0.5), reason: 'from $from');
    }
  });

  test('long-reach archers behind a melee line stand clear of every body', () {
    final g = wave();
    final archers = [for (final r in [2, 3, 4]) archer(g, 6, r)];
    final knights = [for (final r in [2, 4]) placeNow(g, 'knight', 4, r)];
    for (final y in [40.0, 56.0, 72.0]) {
      tough(foeAt(g, 'werebear', Point(archers.first.pos.x + 240, y)));
    }
    for (final u in [...archers, ...knights]) {
      tough(u);
    }
    runFor(g, 15);
    final foes = g.enemies.toList();
    for (final a in archers) {
      final near = foes.map((f) => f.pos.distanceTo(a.pos)).reduce(min);
      expect(near, inInclusiveRange(g.kiteAt(a), g.holdAt(a) + 0.5));
      for (final o in g.units.where((o) => o != a && o.alive)) {
        expect(o.pos.distanceTo(a.pos), greaterThanOrEqualTo(11.5), reason: '${a.id} and ${o.type} ${o.id}');
      }
    }
    for (final k in knights) {
      expect(foes.any((f) => g.reaches(k, f)), isTrue, reason: 'the knights fight in front');
    }
  });
}

/// [wave] begun, its wave number then set to [n]: the monsters made after grow to it.
Game waveOf(int n) {
  final g = wave()
    ..startWave()
    ..queue.clear();
  return g..wave = n;
}
