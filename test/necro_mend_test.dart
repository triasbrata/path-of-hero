// The healing necromancer's choices stick (decisions-log 314; the owner: "ai necromencer healer juga masi suka diam
// bingung antara mau heal dan dan melarikan diri"): no flipping between walking in and backing off, a heal spot found
// round the hurt monster, a back-off that goes on until it is clear and then comes back, and a troop whose reach covers
// the whole right edge (a late archer's) neither pins it there nor keeps it from healing.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

/// A game with no units and no monster skills (no Mass Mend).
Game bare() => Game(Random(1))
  ..units.clear()
  ..monsterSkills = false;

/// A troop of [type] at [at] that neither walks nor fights, with [stats] (else its type's).
Unit standing(Game g, String type, Point<double> at, [Stats? stats]) {
  final u = Unit(Side.troop, type, stats ?? troopTypes[type]!, at)
    ..entered = true
    ..busyUntil = 1e9;
  g.units.add(u);
  return u;
}

/// A normal monster of [type] at [at] that neither walks nor fights, with [hp] left (else full).
Unit still(Game g, String type, Point<double> at, [double? hp]) {
  final u = g.monster(type, Tier.normal, at)..busyUntil = 1e9;
  if (hp != null) u.hp = hp;
  g.units.add(u);
  return u;
}

/// The healing necromancer at [at] with [mp].
Unit mender(Game g, Point<double> at, [double mp = 40]) {
  final u = g.monster(necroHealer, Tier.normal, at)..mp = mp;
  g.units.add(u);
  return u;
}

/// How far [p] is inside [o]'s reach and [necroSafety]; > 0 is too close.
double into(Unit o, Point<double> p) => o.stats.range + necroSafety - o.pos.distanceTo(p);

/// Its choices tick by tick for [n] ticks of 0.05 s.
List<Mend> run(Game g, Unit u, int n) {
  final ms = <Mend>[];
  for (var i = 0; i < n; i++) {
    g.tick(0.05);
    ms.add(u.mend);
  }
  return ms;
}

/// How often [ms] goes from walking in (to rest or to heal) to backing off or back.
int flips(List<Mend> ms) {
  var n = 0;
  bool? backing;
  for (final m in ms) {
    final b = m == Mend.backOff ? true : (m == Mend.rest || m == Mend.toHeal ? false : null);
    if (b == null) continue;
    if (backing != null && b != backing) n++;
    backing = b;
  }
  return n;
}

void main() {
  test('the constants: it backs off until half a tile clear, keeps a monster it goes to heal a second, tries five ways '
      'round it', () {
    expect((mendClear, mendCommit), (tile / 2, 1.0));
    expect(mendTurns, [0.0, 40.0, -40.0, 80.0, -80.0]);
  });

  test("a rest spot in a troop's reach (an escort's healer rests at most escortReach behind its boss) is not walked "
      'into: it holds, and never flips between walking in and backing off', () {
    final g = bare();
    final lead = still(g, 'werebear', const Point(150, 60));
    final knight = standing(g, 'knight', const Point(175, 60)); // its reach and margin take in (150 + 64, 60)
    final u = mender(g, const Point(240, 60), 0)..escortOf = lead; // no MP: nothing to heal anyway
    final ms = run(g, u, 100);
    expect(flips(ms), 0);
    expect(ms.toSet(), {Mend.hold});
    expect(into(knight, u.pos), lessThanOrEqualTo(0));
    expect(u.pos.distanceTo(const Point(240, 60)), lessThan(1));
  });

  test('it heals a hurt monster from a safe spot round it when the straight way ends in a troop\'s reach', () {
    final g = bare();
    final orc = still(g, 'orc', const Point(150, 40), 10);
    final knight = standing(g, 'knight', const Point(200, 25)); // the straight heal spot (207, 50) is in its reach
    final u = mender(g, const Point(260, 60));
    for (var i = 0; i < 160 && orc.hp == 10; i++) {
      g.tick(0.05);
      expect(into(knight, u.pos), lessThanOrEqualTo(0), reason: '$i');
    }
    expect((orc.hp, orc.healedBy), (10 + necroHealerStats.dmg, u));
    expect(u.pos.distanceTo(orc.pos), lessThanOrEqualTo(necroHealerStats.range)); // on its way to the spot, as soon as in range
    expect(u.pos.y, greaterThan(orc.pos.y + tile), reason: 'turned 40° away from the knight');
  });

  test('it backs off until it is half a tile clear, without stopping at the margin, then comes back to its rest spot '
      'once the troop has gone', () {
    final g = bare();
    still(g, 'slime', const Point(180, 60)); // its rest spot: (196, 60)
    final knight = standing(g, 'knight', const Point(170, 60)); // 30 away: inside 14 + 32, out of its scythe's reach
    final u = mender(g, const Point(200, 60));
    var d = u.pos.distanceTo(knight.pos);
    final ms = <Mend>[];
    for (var i = 0; i < 100; i++) {
      g.tick(0.05);
      ms.add(u.mend);
      if (u.mend == Mend.backOff) {
        expect(u.pos.distanceTo(knight.pos), greaterThan(d), reason: '$i');
        d = u.pos.distanceTo(knight.pos);
      }
    }
    expect(ms.first, Mend.backOff);
    expect(flips(ms), 1, reason: 'backs off once, then rests: $ms');
    expect(into(knight, u.pos), lessThanOrEqualTo(-mendClear + 1e-6));
    knight.gone = true;
    ms.clear();
    for (var i = 0; i < 100; i++) {
      g.tick(0.05);
      ms.add(u.mend);
    }
    expect(ms.toSet(), {Mend.rest});
    expect(u.pos.x, closeTo(196, 1));
  });

  test('once clear it stays: a troop at the margin, but no deeper, starts no new back-off (the hysteresis)', () {
    final g = bare();
    still(g, 'slime', const Point(180, 60));
    final knight = standing(g, 'knight', const Point(170, 60));
    final u = mender(g, const Point(200, 60));
    for (var i = 0; i < 100; i++) {
      g.tick(0.05);
    }
    // The knight steps up to just short of its margin: no back-off.
    knight.pos = u.pos - Point(knight.stats.range + necroSafety + 1, 0);
    expect(run(g, u, 20), isNot(contains(Mend.backOff)));
    knight.pos = u.pos - Point(knight.stats.range + necroSafety - 2, 0); // into it: it backs off again
    expect(run(g, u, 2), contains(Mend.backOff));
  });

  test("a troop whose reach covers the whole right edge (a late army's archer) doesn't pin it there: it comes on, "
      'walks in and heals', () {
    final g = bare();
    // An archer of the owner's wave-58 army reaches about 1150: wherever the healer stands, it is in its reach.
    final far = Stats(hp: 100, cost: 0, speed: 20, dmg: 1, range: 600, rate: 1, shotSpeed: 200);
    standing(g, 'archer', const Point(40, 60), far);
    final orc = still(g, 'orc', const Point(150, 60), 10);
    final u = mender(g, const Point(300, 60)); // right of the right limit: it hasn't come on yet
    final ms = <Mend>[];
    for (var i = 0; i < 300 && orc.hp == 10; i++) {
      g.tick(0.05);
      ms.add(u.mend);
    }
    expect(orc.healedBy, u);
    expect(ms, isNot(contains(Mend.backOff)));
    expect(u.pos.x, lessThan(g.rightLimit));
  });

  test('cornered (the right limit and the top hold it), it holds instead of backing off on the spot, and heals what '
      'it reaches from there', () {
    final g = bare();
    still(g, 'slime', const Point(150, 100));
    final knight = standing(g, 'knight', const Point(262, 26)); // reaches into its margin, away is up and right
    final u = mender(g, Point(g.rightLimit, tile / 2)); // the right limit this tick (the view moves after the moves)
    final at = u.pos;
    g.tick(0.05);
    expect((u.mend, u.pos), (Mend.hold, at));
    expect(into(knight, u.pos), greaterThan(0));
    final orc = still(g, 'orc', u.pos - const Point(40, 0), 10); // in its range
    g.tick(0.05);
    expect((u.mend, orc.healedBy), (Mend.heal, u));
  });

  test('a monster it walks to heal is kept a second even when another becomes more hurt, then it heals the most hurt',
      () {
    final g = bare();
    final a = still(g, 'orc', const Point(150, 30), 20), b = still(g, 'orc', const Point(150, 90), 25);
    final u = mender(g, const Point(270, 60));
    g.tick(0.05);
    expect((u.mend, u.mendOn), (Mend.toHeal, a));
    b.hp = 5; // now the most hurt
    for (var i = 0; i < (mendCommit / 0.05).floor() - 2; i++) {
      g.tick(0.05);
      expect(u.mendOn, a, reason: '$i');
    }
    for (var i = 0; i < 4; i++) {
      g.tick(0.05);
    }
    expect((u.mend, u.mendOn), (Mend.toHeal, b));
  });
}
