// #82: two troops whose ways cross ("kalau tA dan tB sama sama mau lewat"): who gives way, how it gets round,
// spots traded after a win, the healers' lanes, and the stall detector (formation-and-navigation.md).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// A troop of [type] standing at [at] (its spot for now), placed after the ones before it.
Unit troopAt(Game g, String type, Point<double> at) {
  final u = placeNow(g, type, 0, g.troops.length % rows);
  return u
    ..pos = at
    ..post = at;
}

/// How far [p] is from the line through [a] and [b] (from [a] when they are one point).
double offLine(Point<double> p, Point<double> a, Point<double> b) {
  final d = b - a;
  return d.magnitude < 1e-9 ? p.distanceTo(a) : ((p.x - a.x) * d.y - (p.y - a.y) * d.x).abs() / d.magnitude;
}

/// Between waves, [a] and [b] walk to their spots ([Unit.post]); ticks until both stand there (at most [cap] s).
/// Returns when each got there (null: never), the closest they came, and how far off its straight way each went.
({double? a, double? b, double gap, double offA, double offB}) walkHome(Game g, Unit a, Unit b, {double cap = 15}) {
  final (a0, b0) = (a.pos, b.pos);
  double? at(Unit u) => u.pos.distanceTo(u.post) < 1 && !u.moving ? g.t : null;
  double? ta, tb;
  var gap = double.infinity, offA = 0.0, offB = 0.0;
  final t0 = g.t;
  while (g.t - t0 < cap && (ta == null || tb == null)) {
    g.tick(1 / 30);
    ta ??= at(a);
    tb ??= at(b);
    gap = min(gap, a.pos.distanceTo(b.pos));
    offA = max(offA, offLine(a.pos, a0, a.post));
    offB = max(offB, offLine(b.pos, b0, b.post));
  }
  return (a: ta == null ? null : ta - t0, b: tb == null ? null : tb - t0, gap: gap, offA: offA, offB: offB);
}

/// Seconds [u] needs to walk straight from [from] to its spot.
double straight(Unit u, Point<double> from) => from.distanceTo(u.post) / u.stats.speed;

void main() {
  test('two troops whose ways home cross both get there: the one that goes first walks straight, the other round it', () {
    // The owner's sketch: A from the top left to the lower right, B from the bottom left to the upper right; and
    // two swapping spots straight up and down. Back-rank pairs used to swap the way back and forth for good.
    const top = Point(40.0, 24.0), low = Point(40.0, 104.0), upRight = Point(120.0, 24.0), downRight = Point(120.0, 104.0);
    for (final (ta, tb, a0, a1, b0, b1) in [
      ('soldier', 'soldier', top, downRight, low, upRight),
      ('archer', 'archer', top, downRight, low, upRight),
      ('priest', 'priest', top, downRight, low, upRight),
      ('wizard', 'priest', top, downRight, low, upRight),
      ('archer', 'soldier', top, downRight, low, upRight),
      ('archer', 'archer', const Point(40.0, 40.0), const Point(40.0, 88.0), const Point(40.0, 88.0), const Point(40.0, 40.0)),
    ]) {
      final g = bareGame();
      final a = troopAt(g, ta, a0)..post = a1, b = troopAt(g, tb, b0)..post = b1;
      final (keeper, other) = tb == 'soldier' && ta != 'soldier' ? (b, a) : (a, b); // melee go first, else the placed first
      final r = walkHome(g, a, b);
      final why = '$ta+$tb';
      expect(r.a, isNotNull, reason: why);
      expect(r.b, isNotNull, reason: why);
      expect(r.a!, lessThan(straight(a, a0) + 1.5), reason: why);
      expect(r.b!, lessThan(straight(b, b0) + 1.5), reason: why);
      expect(identical(keeper, a) ? r.offA : r.offB, lessThan(0.5), reason: why); // it went first, straight on
      expect(r.gap, greaterThan(10), reason: why);
      expect(identical(keeper, a) ? r.offB : r.offA, greaterThan(2), reason: why); // the other went round it
    }
  });

  test('the one giving way passes behind the one crossing its way', () {
    final g = bareGame();
    final a = troopAt(g, 'soldier', const Point(40, 24))..post = const Point(120, 104);
    final b = troopAt(g, 'soldier', const Point(40, 104))..post = const Point(120, 24);
    // A (placed first) goes first. Its way is the line y = x − 16; where B crosses it, A must already be past.
    var crossed = false;
    for (var i = 0; i < 300; i++) {
      final before = b.pos.y - (b.pos.x - 16);
      g.tick(1 / 30);
      final after = b.pos.y - (b.pos.x - 16);
      if (before > 0 && after <= 0) {
        crossed = true;
        expect(a.pos.x, greaterThan(b.pos.x + 6), reason: 't=${g.t}'); // behind A
      }
    }
    expect(crossed, isTrue);
    expect((a.pos, b.pos), (a.post, b.post));
  });

  test('head-on, the one giving way passes on its goal\'s side: the one whose goal is lower passes below', () {
    for (final goalY in [64.0, 48.0]) {
      final g = bareGame();
      final a = troopAt(g, 'soldier', const Point(40, 56))..post = const Point(140, 56);
      final b = troopAt(g, 'soldier', const Point(140, 56))..post = Point(40, goalY);
      double? passedAt; // B's height relative to A as they go by each other
      for (var i = 0; i < 300; i++) {
        g.tick(1 / 30);
        if ((a.pos.x - b.pos.x).abs() < 2) passedAt ??= b.pos.y - a.pos.y;
      }
      expect(passedAt, isNotNull);
      expect(passedAt!.sign, (goalY - 56).sign, reason: 'goal y $goalY'); // below for the lower goal, above for the upper
      expect(passedAt.abs(), greaterThan(8));
      expect((a.pos, b.pos), (a.post, b.post));
    }
  });

  test('in battle one coming through from behind goes first, and the one it meets bends round it at full pace', () {
    final g = bareGame();
    troopAt(g, 'priest', const Point(40, 56)).busyUntil = hold;
    // An archer walks up to get the foe in range; a hurt soldier falls back to the priest, head-on into it.
    final back = troopAt(g, 'soldier', const Point(170, 56)), up = troopAt(g, 'archer', const Point(70, 56));
    back.hp = back.maxHp * 0.3;
    g
      ..startWave()
      ..queue.clear();
    foeAt(g, 'werebear', const Point(320, 56));
    const there = 40 + 48.0; // near enough the priest
    double? at;
    var gap = double.infinity, bent = 0.0, upBent = 0.0;
    for (var i = 0; i < 30 * 6 && at == null; i++) {
      g.tick(1 / 30);
      gap = min(gap, back.pos.distanceTo(up.pos));
      bent = max(bent, (back.pos.y - 56).abs());
      upBent = max(upBent, (up.pos.y - 56).abs());
      if (back.pos.x <= there + 0.5) at = g.t;
    }
    expect(at, isNotNull);
    // Between waves the soldier would go first (the fixed order: the further forward); in battle the one heading
    // for the fight does.
    expect(bent, greaterThan(4));
    expect(upBent, lessThan(bent / 2)); // side by side neither comes through, and the separation may nudge it a little
    expect(gap, greaterThan(10));
    expect(at!, lessThan((170 - there) / back.stats.speed + 0.15)); // never slowed down for it
  });

  test('after a win two troops of a rank whose ways home cross trade spots; other ranks keep their own', () {
    for (final (ta, tb) in [('archer', 'archer'), ('soldier', 'knight'), ('soldier', 'archer')]) {
      final g = bareGame();
      final a = placeNow(g, ta, 1, 1), b = placeNow(g, tb, 1, 6);
      // Where the fight left them: each in the other's row.
      a.pos = Point(160, b.post.y);
      b.pos = Point(160, a.post.y);
      final ys = (a.post.y, b.post.y);
      g.startWave();
      g.queue
        ..clear()
        ..add(('slime', Tier.normal));
      g.tick(0.05);
      g.enemies.single.gone = true;
      g.tick(0.05);
      expect(g.waveActive, isFalse);
      final trade = a.rank == b.rank;
      expect((a.post.y, b.post.y), trade ? (ys.$2, ys.$1) : ys, reason: '$ta+$tb');
      if (!trade) continue;
      final r = walkHome(g, a, b); // the cheering, then home
      expect(r.a! < victoryTime + 2 && r.b! < victoryTime + 2, isTrue, reason: '$ta+$tb');
      expect(max(r.offA, r.offB), lessThan(1), reason: '$ta+$tb'); // straight home, nobody in the other's way
    }
  });

  test('mid-battle idle healers take their lanes top to bottom as they stand', () {
    final g = bareGame();
    final low = troopAt(g, 'priest', const Point(40, 100)), high = troopAt(g, 'priest', const Point(40, 28)); // the lower placed first
    for (final y in [40.0, 88.0]) {
      troopAt(g, 'knight', Point(120, y)).busyUntil = hold;
    }
    g
      ..startWave()
      ..queue.clear();
    foeAt(g, 'werebear', const Point(300, 64));
    runFor(g, 5);
    expect(high.pos.y, closeTo(56, 1)); // a lane apart around the fighters' middle
    expect(low.pos.y, closeTo(72, 1));
    expect((high.moving, low.moving), (false, false));
  });

  test('healing necromancers rest in lanes top to bottom as they stand, never pushing against each other', () {
    final g = bareGame();
    troopAt(g, 'knight', const Point(20, 64)).busyUntil = hold;
    g
      ..startWave()
      ..queue.clear();
    for (final y in [40.0, 88.0]) {
      foeAt(g, 'slime', Point(250, y));
    }
    final low = g.monster(necroHealer, Tier.normal, const Point(262, 110)), high = g.monster(necroHealer, Tier.normal, const Point(262, 20));
    g.units.addAll([low, high]); // the lower came first
    runFor(g, 4);
    expect(high.pos.y, closeTo(56, 1));
    expect(low.pos.y, closeTo(72, 1));
    expect((high.moving, low.moving), (false, false));
  });

  test('a kiting archer pinned at the view\'s left edge backs straight up to it and holds, not sliding along it', () {
    final g = bareGame();
    final a = troopAt(g, 'archer', const Point(40, 56));
    g
      ..startWave()
      ..queue.clear();
    foeAt(g, 'werebear', const Point(70, 40)); // too close, and above: backing off from it goes left and down
    final edge = a.pos.x - tile; // the view's left edge a tile behind it
    var shots = 0;
    for (var i = 0; i < 60; i++) {
      g.cam = edge; // held there
      g.tick(1 / 30);
      if (a.attackedAt == g.t) shots++;
      expect(a.pos.y, 56, reason: 't=${g.t}'); // straight back, never sideways
    }
    expect(a.pos.x, closeTo(edge + tile / 2, 1e-9));
    expect(a.moving, isFalse);
    expect(shots, greaterThan(0));
  });

  test('between waves a troop shoved back again and again, though it gets on in between, walks through after a while', () {
    // The probe (auto-player, seed 1, wave 14): a wizard walking home up the back rank through the spot of an archer
    // that kept stepping back onto it was shoved back down each time, round and round every 10 s. It got on in
    // between, so a count of ticks without getting on never reached the limit. Here whatever is in its way at [gate]
    // shoves it back a tile each time it gets there (and lets it by while it walks through its allies).
    final g = bareGame();
    final w = troopAt(g, 'wizard', const Point(40, 104))..post = const Point(40, 8);
    const gate = 56.0;
    var through = false;
    for (var i = 0; i < 30 * 15 && w.pos.distanceTo(w.post) >= 1; i++) {
      g.tick(1 / 30);
      if (g.t < w.throughUntil) {
        through = true;
      } else if (w.pos.y < gate && w.pos.y > gate - tile / 2) {
        w.pos = Point(w.pos.x, gate + tile);
      }
    }
    expect(through, isTrue);
    expect(w.pos.distanceTo(w.post), lessThan(1));
  });

  test('a troop walking without getting on for a while walks through its allies, and nobody freezes', () {
    final g = bareGame();
    // A wall of priests down the whole field, a tile apart, each mid-cast all along: they hold their ground, and
    // no gap between two is wide enough to walk through.
    final wall = [for (var r = 0; r < rows; r++) troopAt(g, 'priest', Point(80, r * tile + tile / 2))];
    final soldier = troopAt(g, 'soldier', const Point(40, 56))..post = const Point(140, 56);
    var through = false;
    for (var i = 0; i < 30 * 10 && soldier.pos.distanceTo(soldier.post) >= 1; i++) {
      for (final p in wall) {
        p.attackedAt = g.t;
      }
      g.tick(1 / 30);
      through |= g.t < soldier.throughUntil;
      expect(soldier.stuckFor, lessThan(1.5 + 1e-9));
    }
    expect(through, isTrue);
    expect(soldier.pos.distanceTo(soldier.post), lessThan(1));
    for (final p in wall) {
      expect(p.pos, p.post);
    }
  });
}
