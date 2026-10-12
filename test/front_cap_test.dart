// The front's cap at the view's right edge, and the army kept together round the fight the view centres (decisions-log
// 324; the owner: "yang troops maju mundur ini mungkin batas maksimal maju adalah sejauh kanan kamera ...", then "battle
// harus tetap di tengah layar ... harusnya para healer ikut maju agar battle field kembali ke center camera"): no troop
// walks past the cap, one at it stands facing its foe and strikes what it reaches, never stepping back for it, a shove
// doesn't push it past it; the view centres the fight and doesn't wait for a troop behind; a healer rests at most
// [Game.healBehind] behind the rearmost melee in the fight, and one far behind it walks up first, healing on the way only
// one at half HP or less; a melee troop holds before it turns back, waits where it stands, and an ally's shove moves it
// in x as they stand apart; the stall detector quiet through all of it. And from decisions-log 312: a healer out of
// sight walks into view before it heals, one left behind walks up between heals.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// Mid-wave on a bare field (no free healer, the #10 skills off), nothing left to spawn; a slime held far off keeps
/// the wave on.
Game midWave() {
  final g = bareGame(Random(1))..skills = false;
  g
    ..startWave()
    ..queue.clear();
  foeAt(g, 'slime', const Point(900, 120));
  return g;
}

var _cell = 0;

/// A troop of [type] standing at ([x], [y]) on [g]'s field, its spot there; [held]: it never moves nor acts.
Unit troopAt(Game g, String type, double x, double y, {bool held = false}) {
  final c = _cell++ % 48;
  final u = placeNow(g, type, c ~/ rows, c % rows)
    ..pos = Point(x, y)
    ..post = Point(x, y)
    ..joining = false; // on the field already, not walking in
  if (held) u.busyUntil = hold;
  return u;
}

/// A Hero priest: its reach ×[heroBoost] (288).
void heroReach(Game g, Unit u) => u
  ..hero = true
  ..heroStats = [HeroStat.range]
  ..stats = g.statsOf(u.type).heroic({HeroStat.range}, heroBoost);

/// Ticks [g] for [secs] s with the view's left edge held at [cam] (the cap at cam + viewW − a tile), as when the view
/// shows a fight further back; [each] runs after every tick.
void pinned(Game g, double cam, double secs, [void Function(int i)? each]) {
  for (var i = 0; i < (secs / 0.05).round(); i++) {
    g
      ..tick(0.05)
      ..cam = cam;
    each?.call(i);
  }
}

void main() {
  setUp(() => _cell = 0);

  test('the cap: a tile inside the view\'s right edge mid-wave; none with it off, before a wave or on a stalled wave\'s '
      'march', () {
    final g = midWave()..cam = 40;
    expect(g.frontCap, 40 + g.viewW - tile);
    expect((midWave()..keepSupports = false).frontCap, isNull);
    expect(bareGame(Random(1)).frontCap, isNull);
    expect((midWave()..marching = true).frontCap, isNull);
  });

  test('a troop walks at its foe up to the cap and stands there facing it, never further, never "stuck"', () {
    final g = midWave();
    final knight = troopAt(g, 'knight', 60, 56);
    foeAt(g, 'slime', const Point(600, 56));
    pinned(g, 0, 15, (i) {
      expect(knight.pos.x, lessThanOrEqualTo(g.frontCap! + 1e-6), reason: 'tick $i');
      expect(knight.throughUntil, double.negativeInfinity, reason: 'tick $i: never "stuck"');
    });
    expect(knight.pos.x, closeTo(g.frontCap!, 0.5));
    expect(knight.moving, isFalse);
    expect(knight.dir, 1); // facing the slime
  });

  test('at the cap a troop strikes what it reaches and never steps back; a shove doesn\'t push it past the cap', () {
    final g = midWave();
    final knight = troopAt(g, 'knight', 60, 56);
    foeAt(g, 'slime', const Point(600, 56));
    pinned(g, 0, 15);
    final x = knight.pos.x;
    expect(x, closeTo(g.frontCap!, 0.5));
    final orc = foeAt(g, 'orc', Point(x + 14, 56)); // in its reach, past the cap
    var least = x;
    pinned(g, 0, 2, (i) => least = min(least, knight.pos.x));
    expect(orc.hp, lessThan(orc.maxHp));
    expect(least, greaterThan(x - 1e-6)); // it never stepped back
    // Another knight walks up beside it: the two shove each other, never past the cap.
    final ally = troopAt(g, 'knight', x - 30, 60);
    pinned(g, 0, 3, (i) {
      for (final u in [knight, ally]) {
        expect(u.pos.x, lessThanOrEqualTo(g.frontCap! + 1e-6), reason: 'tick $i');
      }
    });
  });

  test('past the cap (the view went back) a troop stands where it is: no step back, none further', () {
    final g = midWave();
    final knight = troopAt(g, 'knight', 400, 56); // the cap at 304
    foeAt(g, 'slime', const Point(600, 56));
    pinned(g, 0, 3, (i) {
      expect(knight.pos.x, closeTo(400, 1e-6), reason: 'tick $i');
      expect(knight.throughUntil, double.negativeInfinity, reason: 'tick $i');
    });
    expect(g.frontCap, lessThan(400));
  });

  test('the view centres the fight, a troop behind or not; the cap a safety that a walk with the view never meets', () {
    final g = midWave();
    final priest = troopAt(g, 'priest', 20, 20, held: true); // far behind: the view doesn't wait for it
    final knight = troopAt(g, 'knight', 250, 56, held: true); // it never kills the orc: the fight stays
    foeAt(g, 'orc', Point(knight.pos.x + 14, 56)); // the fight at about 257
    runFor(g, 3);
    expect(g.viewMid, closeTo(g.meetX!, focusSlack + 1e-6));
    expect(g.meetX, closeTo(257, 1));
    expect(priest.pos.x, lessThan(g.cam - Game.offViewBy)); // out of sight: it isn't the view's business
    // A knight walking on with the view following it stays well inside the cap.
    final w = midWave(), walker = troopAt(w, 'knight', 60, 56);
    foeAt(w, 'slime', const Point(600, 56));
    var room = double.infinity;
    for (var i = 0; i < 200; i++) {
      w.tick(0.05);
      room = min(room, w.frontCap! - walker.pos.x);
    }
    expect(room, greaterThan(tile));
  });

  test('a healer rests at most healBehind behind the rearmost melee in the fight, not behind the long range; with it off '
      'a tile behind the rearmost fighter', () {
    double restOf(bool keep) {
      final g = midWave()..keepSupports = keep;
      final knight = troopAt(g, 'knight', 250, 56);
      foeAt(g, 'orc', Point(knight.pos.x + 14, 56))
        ..maxHp = 1000000
        ..hp = 1e6;
      final wizard = troopAt(g, 'wizard', 150, 90), priest = troopAt(g, 'priest', 100, 20);
      runFor(g, 12);
      expect(g.t - knight.attackedAt, lessThan(2)); // fighting
      expect(g.t - wizard.attackedAt, lessThan(2)); // shooting, from its hold further back
      return priest.pos.x - (keep ? knight.pos.x - Game.healBehind : wizard.pos.x - tile);
    }

    expect(restOf(true), closeTo(0, 2));
    expect(restOf(false), closeTo(0, 2));
  });

  test('a walking army: the healer stays on the screen, the knight under the cap, and the knight reaches its foe', () {
    final g = midWave();
    final priest = troopAt(g, 'priest', 20, 20), knight = troopAt(g, 'knight', 60, 56);
    final slime = foeAt(g, 'slime', const Point(420, 56));
    for (var i = 0; i < 500 && slime.hp == slime.maxHp; i++) {
      g.tick(0.05);
      expect(priest.pos.x, greaterThanOrEqualTo(g.cam - Game.offViewBy), reason: 'tick $i: the priest on the screen');
      expect(knight.pos.x, lessThanOrEqualTo(g.frontCap! + 1e-6), reason: 'tick $i');
      expect(knight.throughUntil, double.negativeInfinity, reason: 'tick $i');
    }
    expect(slime.hp, lessThan(slime.maxHp));
  });

  test('with keepSupports off no cap: a troop walks past where the cap would hold it (as before decisions-log 324)', () {
    double frontOf(bool keep) {
      final g = midWave()..keepSupports = keep;
      final knight = troopAt(g, 'knight', 60, 56);
      foeAt(g, 'slime', const Point(322, 56)); // its front spot at about 310: open (inside the view), past the cap
      pinned(g, 0, 20);
      return knight.pos.x;
    }

    expect(frontOf(true), closeTo(304, 0.5)); // the cap: the view's left edge at 0, 320 wide, less a tile
    expect(frontOf(false), greaterThan(304 + 3));
  });

  test('a melee troop that walked forward holds [turnHold] before it turns back to a goal behind it, then turns', () {
    final g = midWave();
    final knight = troopAt(g, 'knight', 60, 56), slime = foeAt(g, 'slime', const Point(400, 56));
    runFor(g, 1); // walking forward
    expect(knight.moving, isTrue);
    final x = knight.pos.x;
    slime.pos = Point(x - 80, 56); // its foe now lies behind it
    var held = 0.0;
    while (knight.pos.x >= x - 1e-6 && held < 2) {
      g.tick(0.05);
      held += 0.05;
      expect(knight.throughUntil, double.negativeInfinity);
    }
    expect(held, closeTo(Game.turnHold, 0.051)); // it stood that long, then turned
    runFor(g, 1);
    expect(knight.pos.x, lessThan(x - tile)); // walking back to it
  });

  test('a troop that loses its spot waits where it stands when that is between its wait point and the front spot', () {
    double waiterX(bool keep) {
      final g = midWave()..keepSupports = keep;
      final us = [for (var i = 0; i < 9; i++) troopAt(g, 'soldier', 120, 8.0 + 14 * i)];
      final m = foeAt(g, 'orc', const Point(200, 56))
        ..maxHp = 1000000
        ..hp = 1e6;
      runFor(g, 20);
      final waiter = us.singleWhere((u) => u.spotOf == null);
      expect(waiter.waiting, isTrue);
      final front = m.pos.x - (max(12.0, waiter.stats.range) - spotSlack);
      waiter.pos = Point(front - waitBack / 2, m.pos.y - tile); // between its wait point and the front spot
      final x = waiter.pos.x;
      runFor(g, 2);
      expect(waiter.waiting, isTrue);
      return waiter.pos.x - x;
    }

    expect(waiterX(true).abs(), lessThan(2)); // it stays
    expect(waiterX(false), lessThan(-waitBack / 2 + 2)); // before: back to the wait point
  });

  test('mid-wave two allies one above the other shove apart in y, hardly in x', () {
    final g = midWave();
    final a = troopAt(g, 'knight', 60, 50), b = troopAt(g, 'knight', 60, 70);
    foeAt(g, 'slime', const Point(600, 56));
    pinned(g, 0, 15); // both at the cap, standing
    final cap = g.frontCap!;
    a.pos = Point(cap, 50);
    b.pos = Point(cap - 1, 58); // 8 apart, a hair behind in x
    pinned(g, 0, 0.5);
    expect((b.pos.y - a.pos.y).abs(), greaterThan(11));
    expect(b.pos.x, greaterThan(cap - 1 - 0.6)); // not the half gap of before
    expect(a.pos.x, lessThanOrEqualTo(g.frontCap! + 1e-6));
  });

  test('a healer left behind walks up whenever no heal of its is due: short of MP too, not only between heals', () {
    double walked(bool keep) {
      final g = midWave()..keepSupports = keep;
      final priest = troopAt(g, 'priest', 100, 20);
      heroReach(g, priest); // it reaches the knight from where it stands
      priest.mp = 0; // short of the MP: no heal is due
      final knight = troopAt(g, 'knight', 330, 56);
      foeAt(g, 'orc', const Point(344, 56))
        ..maxHp = 1000000
        ..hp = 1e6;
      knight.hp = knight.maxHp / 2;
      g.cam = 100; // the priest in sight: no walk-in
      runFor(g, 1.5);
      return priest.pos.x - 100;
    }

    expect(walked(true), greaterThan(tile)); // up toward its rest behind the knight
    expect(walked(false), closeTo(0, 1e-6)); // before: it stood, dry, where it was
  });

  test('a healer far behind its rest walks up first: one at half HP or less it heals on the way, a lighter hurt waits', () {
    // [share]: the knight's HP; the orc held, so only heals change it. Returns how far the priest walked in 1.5 s and
    // whether it healed the knight.
    (double, bool) run(bool keep, double share) {
      final g = midWave()..keepSupports = keep;
      final priest = troopAt(g, 'priest', 100, 20);
      heroReach(g, priest); // it reaches the knight from where it stands
      final knight = troopAt(g, 'knight', 330, 56);
      foeAt(g, 'orc', const Point(344, 56))
        ..maxHp = 1000000
        ..hp = 1e6
        ..busyUntil = hold;
      knight.hp = knight.maxHp * share;
      g.cam = 100; // the priest in sight: no walk-in
      runFor(g, 1.5);
      return (priest.pos.x - 100, knight.healedAt > 0);
    }

    final (walked, healed) = run(true, 0.8);
    expect(healed, isFalse); // 80%: not now
    expect(walked, greaterThan(2 * tile)); // it walks on, not stopping to cast
    final (_, healedLow) = run(true, 0.4);
    expect(healedLow, isTrue); // at half HP or less: healed on the way
    final (stood, healedOff) = run(false, 0.8);
    expect(healedOff, isTrue); // with keepSupports off it heals from where it stands, as before
    expect(stood, lessThan(tile));
  });

  test('a troop healer out of sight left of the view walks into it before it heals', () {
    final g = midWave();
    final priest = troopAt(g, 'priest', 20, 20);
    heroReach(g, priest); // it reaches the knight from out of sight
    final knight = troopAt(g, 'knight', 330, 56);
    foeAt(g, 'slime', const Point(344, 56));
    knight.hp = knight.maxHp / 2;
    g.cam = 200; // the view on the fight
    var healedAway = false, healed = false;
    for (var i = 0; i < 200 && !healed; i++) {
      final away = priest.pos.x < g.cam + g.keepUpShift - Game.offViewBy, x = priest.pos.x, hp = knight.hp;
      g.tick(0.05);
      if (knight.hp > hp) (away ? healedAway = true : healed = true);
      if (away) expect(priest.pos.x, greaterThan(x), reason: 'tick $i: it walks up');
    }
    expect(healedAway, isFalse);
    expect(healed, isTrue);
  });

  test('a troop healer left behind the army walks up behind it between heals, and heals on', () {
    final g = midWave();
    final priest = troopAt(g, 'priest', 120, 20);
    heroReach(g, priest);
    final knight = troopAt(g, 'knight', 330, 56);
    foeAt(g, 'slime', const Point(344, 56));
    knight.hp = 1;
    final from = priest.pos.x, hp = knight.hp;
    runFor(g, 2.5);
    expect(knight.hp, greaterThan(hp)); // it healed
    expect(priest.pos.x, greaterThan(from + tile)); // and came up between heals
    expect(priest.pos.x, lessThanOrEqualTo(knight.pos.x - tile + 1e-6)); // never past its rest behind the army
    // keepSupports off: it heals from where it stands, as before.
    final h = midWave()..keepSupports = false;
    final p = troopAt(h, 'priest', 120, 20);
    heroReach(h, p);
    troopAt(h, 'knight', 330, 56).hp = 1;
    foeAt(h, 'slime', const Point(344, 56));
    runFor(h, 2.5);
    expect(p.pos.x, closeTo(120, 1e-6));
  });
}
