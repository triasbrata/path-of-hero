import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

const dt = 1 / 30;

/// A wave under way with nothing left to spawn, skills off: a wizard with three bows (it backs off a foe nearer
/// than [Engage.kiteAt], 52.5 px) [gap] px right of a werebear mini boss and [dy] px below it, neither of them able
/// to fall. qa-3's stall (s2-w90, dice 2903) had a lone wizard 90-104 px right of a skeleton archer mini boss, when a
/// troop backed off any foe nearer than 0.75 × its reach; since decisions-log 199 it stands its ground against a
/// ranged one (that stands at its hold, further off than the kite), so the boss that leads it off here is a melee
/// one. [Game.holdPastFoe] is off, the default.
(Game, Unit, Unit) pastFoe({double gap = 40, double dy = 0}) {
  final g = Game(Random(1))
    ..gold = 100000
    ..capacity = 6 * rows
    ..viewW = 341
    ..skills = false
    ..heroSkills = false
    ..awakenSkills = false
    ..monsterSkills = false;
  g.units.clear(); // no free healer
  g.upgrades['wizard'] = List.filled(3, Item.bow);
  expect(g.place('wizard', 3, 3), isTrue);
  final y = fieldH / 2;
  final wizard = g.units.last
    ..pos = Point(g.baseX + 224, y + dy)
    ..entered = true
    ..arriving = false
    ..maxHp = 1 << 30
    ..hp = 1e9;
  g.startWave();
  g.queue.clear();
  final mini = g.monster('werebear', Tier.miniBoss, Point(wizard.pos.x - gap, y))
    ..entered = true
    ..maxHp = 1 << 30
    ..hp = 1e9;
  g.units.add(mini);
  expect(wizard.pos.distanceTo(mini.pos), lessThan(g.kiteAt(wizard))); // it would back off
  expect(mini.stats.range, lessThan(g.kiteAt(wizard))); // and the boss would follow it
  return (g, wizard, mini);
}

/// A wave under way with nothing left to spawn and no troop, and a plain monster (no mini boss or boss: none of
/// [stallProgress]) that neither walks nor fights, too tough to fall: the test moves it and takes its HP.
(Game, Unit) quietWave() {
  final g = Game(Random(1))..units.clear();
  g.startWave();
  g.queue.clear();
  final m = plain(g, Point(g.baseX + 120, fieldH / 2));
  g.units.add(m);
  return (g, m);
}

/// A plain monster that neither walks nor fights, too tough to fall.
Unit plain(Game g, Point<double> at) => g.monster('werebear', Tier.highElite, at)
  ..entered = true
  ..busyUntil = 1e9
  ..maxHp = 1 << 30
  ..hp = 1e9;

/// A wave under way, monster skills off and no troop, whose mini boss (and boss, with [boss]) came on as the wave
/// spawns them (the overtime clock's last start, at the returned time), then stand and fight nobody; beside them a
/// plain monster ([plain]) whose HP the test takes so the stall clock never stalls. The test takes the slots' HP too.
(Game, List<Unit>, Unit, double) slotFight({bool boss = false}) {
  final g = Game(Random(1))
    ..units.clear()
    ..monsterSkills = false;
  g.startWave();
  // On the field before the spawns, so its HP is in the stall clock's low from the first spawn on.
  final filler = plain(g, Point(g.baseX + 200, fieldH / 2));
  g.units.add(filler);
  g.queue
    ..clear()
    ..add(('werebear', Tier.miniBoss));
  if (boss) g.queue.add(('werebear', Tier.boss));
  while (g.queue.isNotEmpty) {
    g.tick(dt);
  }
  final from = g.t, slots = g.enemies.where((u) => u != filler).toList();
  for (final (i, u) in slots.indexed) {
    u
      ..entered = true
      ..busyUntil = 1e9
      ..pos = Point(g.baseX + 120 + 30.0 * i, fieldH / 2);
  }
  expect(slots.map((u) => u.tier), [Tier.miniBoss, if (boss) Tier.boss]);
  return (g, slots, filler, from);
}

void main() {
  final heard = <Marched>[];
  void listen(Game g) {
    heard.clear();
    g.listeners.add((e) {
      if (e is Marched) heard.add(e);
    });
  }

  test('a wizard right of a mini boss leads it off until the stall watch marches it back (qa-3)', () {
    final (g, wizard, mini) = pastFoe();
    listen(g);
    expect(g.holdPastFoe, isFalse, reason: 'the default (decisions-log 153)');
    final start = g.t, x0 = wizard.pos.x, lives = g.lives;
    var most = x0;
    while (g.waveActive && g.t - start < 300) {
      g.tick(dt);
      if (!g.marching) most = max(most, wizard.pos.x);
    }
    // qa-3's scene: both go right, the boss after the wizard, the view in tow, its blows a new low of HP every time. Past
    // [stallDrift] they are no progress; [stallTime] later the boss marches, and neither can fall, so [marchMax] s on the
    // wave is lost (it leaked over the back line until decisions-log 329).
    expect(g.waveActive, isFalse, reason: 'the wave ended');
    expect(heard.map((e) => e.why), [MarchCause.drifting]);
    expect((g.lives, g.wipeCause), (lives - wipeLives, WipeCause.slow));
    expect(most - x0, greaterThan(stallDrift), reason: 'it did lead the boss off');
    expect(most - x0, lessThan(stallDrift + (stallTime + 2) * wizard.stats.speed + 2 * tile),
        reason: 'no further than the drift and the stall clock allow');
    expect(mini.hp, greaterThan(0), reason: 'the march was not won, it never fell');
  });

  test('with holdPastFoe on, a wizard right of a mini boss stands its ground instead of backing off', () {
    final (g, wizard, mini) = pastFoe();
    g.holdPastFoe = true;
    final x0 = wizard.pos.x;
    var most = x0;
    for (var i = 0; i < 120 / dt; i++) {
      g.tick(dt);
      most = max(most, wizard.pos.x);
    }
    expect(most - x0, lessThanOrEqualTo(tile), reason: 'it never went more than a tile right');
    expect(mini.pos.x, lessThan(x0), reason: 'nor did the boss get past where it stood');
    expect((g.waveActive, g.marching), (true, false)); // neither can fall: they shoot it out where they stand
  });

  test('with holdPastFoe on, past its foe a kiting wizard keeps its x and only steps aside; short of it, it still backs off toward the base', () {
    final (g, wizard, _) = pastFoe(dy: 20);
    g.holdPastFoe = true;
    final p0 = wizard.pos;
    for (var i = 0; i < 15; i++) {
      g.tick(dt);
      expect(wizard.pos.x, p0.x, reason: 'tick $i');
    }
    expect(wizard.pos.y, greaterThan(p0.y + 4)); // away from the boss, down the field
    expect(wizard.dir, -1); // facing it

    // The boss on the base's side of it no longer: in front, as monsters come, it backs off left as ever.
    final (h, front, foe) = pastFoe();
    h.holdPastFoe = true;
    foe.pos = Point(front.pos.x + 40, front.pos.y);
    final x0 = front.pos.x;
    for (var i = 0; i < 15; i++) {
      h.tick(dt);
    }
    expect(front.pos.x, lessThan(x0 - 3));
  });

  test('monsters drifting away from the base stall the wave even while their HP keeps falling', () {
    final (g, m) = quietWave();
    listen(g);
    final start = g.t;
    // Hit all the while and led away at a walker's pace (18 px/s, the wizard's), as in qa-3's stall.
    while (!g.marching && g.t - start < 120) {
      m
        ..hp -= 10
        ..pos += const Point(18 * dt, 0);
      g.tick(dt);
    }
    final drifted = stallDrift / 18; // when it is over [stallDrift] past its low: its HP stops counting
    expect(g.marching, isTrue);
    expect(g.t - start, inInclusiveRange(drifted + stallTime, drifted + stallTime + 1));
    expect(heard.map((e) => e.why), [MarchCause.drifting]);
    expect(g.newMarch, isTrue);
  });

  test('a slow fight of plain monsters holding their ground, knocked back now and then, never stalls before stallOvertime', () {
    final (g, m) = quietWave();
    listen(g);
    final start = g.t, x0 = m.pos.x;
    for (var i = 0; g.t - start < stallOvertime - 1; i++) {
      m.hp -= 1e5; // 3M HP a second, over half of its HP by the end, and nobody dies
      // A tile's knockback every 5 s, walked back over the next 2 s.
      final k = i % 150;
      m.pos = Point(x0 + (k < 60 ? tile * (1 - k / 60) : 0), m.pos.y);
      g.tick(dt);
      expect(g.marching, isFalse, reason: 'at ${g.t - start}');
    }
    // Then it has gone on too long, falling HP or not: a plain monster's is no [stallProgress], however much.
    while (!g.marching && g.t - start < stallOvertime + 2) {
      m.hp -= 1e5;
      g.tick(dt);
    }
    expect(m.hp, lessThan(0.5 * m.maxHp));
    expect(g.marching, isTrue);
    expect(g.t - start, inInclusiveRange(stallOvertime, stallOvertime + 0.1));
    expect(heard.map((e) => e.why), [MarchCause.overtime]);
  });

  test('a plain monster falling does not start the overtime clock afresh', () {
    // (A life lost to the back line did until decisions-log 329: no life is lost mid-wave now.)
    {
      final (g, m) = quietWave();
      listen(g);
      final start = g.t;
      void fight(double until) {
        while (!g.marching && g.t - start < until) {
          m.hp -= 0.5;
          g.tick(dt);
        }
      }

      fight(60);
      // One falls: progress for the stall clock, not for the overtime one.
      final slime = g.monster('slime', Tier.normal, m.pos + const Point(30, 0))
        ..entered = true
        ..busyUntil = 1e9;
      g.units.add(slime);
      g.tick(dt);
      slime
        ..hp = 0
        ..dying = 0;
      fight(100);
      final from = start;
      fight(from - start + stallOvertime + 2);
      expect(g.marching, isTrue);
      expect(g.t - from, inInclusiveRange(stallOvertime, stallOvertime + 0.1));
      expect(heard.map((e) => e.why), [MarchCause.overtime]);
    }
  });

  test('a slow slot fight whose mini boss keeps losing HP goes on past stallOvertime, until stallOvertimeMax', () {
    {
      final (g, [mini], filler, from) = slotFight();
      listen(g);
      // 6% of its max HP every 180 s, a little every tick, the plain monster untouched: the overtime clock starts
      // afresh every ~150 s ([stallProgress]), and every blow is a new low for the stall clock.
      final blow = 0.06 * mini.maxHp / stallOvertime * dt;
      void fight(double until) {
        while (!g.marching && g.t - from < until) {
          mini.hp -= blow;
          g.tick(dt);
        }
      }

      final last = from;
      fight(last - from + stallOvertimeMax - 1);
      expect(g.marching, isFalse);
      // Then the wave has run too long since its last spawn, however the fight goes.
      fight(last - from + stallOvertimeMax + 2);
      expect(heard.map((e) => e.why), [MarchCause.overtimeMax]);
      expect(heard.single.t - last, inInclusiveRange(stallOvertimeMax - dt, stallOvertimeMax + 0.1));
      expect(mini.hp / mini.maxHp, closeTo(1 - 0.06 * (heard.single.t - from) / stallOvertime, 0.01));
      expect(filler.hp, 1e9);
    }
  });

  test('a slot fight whose mini boss stops losing HP marches stallOvertime after its last stallProgress', () {
    final (g, [mini], filler, from) = slotFight();
    listen(g);
    // The plain monster's HP falls all the while, so the stall clock never stalls; the mini boss loses
    // [stallProgress] of its max HP at once at 50 s and 100 s, then nothing more.
    void fight(double until) {
      while (!g.marching && g.t - from < until) {
        filler.hp -= 1e4;
        g.tick(dt);
      }
    }

    var last = from;
    for (final at in [50.0, 100.0]) {
      fight(at);
      mini.hp -= (stallProgress + 0.001) * mini.maxHp;
      g.tick(dt);
      last = g.t;
    }
    fight(last - from + stallOvertime - 1);
    expect(g.marching, isFalse, reason: 'the clock started afresh at 100 s');
    fight(last - from + stallOvertime + 2);
    expect(g.marching, isTrue);
    expect(heard.single.t - last, inInclusiveRange(stallOvertime - dt, stallOvertime + 0.1));
    expect(heard.single.why, MarchCause.overtime);
  });

  test('HP a slot monster is healed back has to be lost again; a mini boss falling is progress', () {
    for (final more in [false, true]) {
      final (g, [mini, chief], filler, from) = slotFight(boss: true);
      listen(g);
      final all = mini.maxHp + chief.maxHp;
      void fight(double until) {
        while (!g.marching && g.t - from < until) {
          filler.hp -= 1e4;
          g.tick(dt);
        }
      }

      // The boss loses 4% of the two's max HP, is healed it back, and loses it again: 8% lost, 4% short of where the
      // clock started.
      for (final (at, d) in [(20.0, 0.04), (40.0, -0.04), (60.0, 0.04)]) {
        fight(at);
        chief.hp -= d * all;
      }
      var last = from;
      if (more) {
        fight(80);
        chief.hp -= 0.015 * all; // 5.5% short of the start: progress
        g.tick(dt);
        last = g.t;
      }
      fight(last - from + stallOvertime + 2);
      expect(heard.map((e) => e.why), [MarchCause.overtime], reason: '$more');
      expect(heard.single.t - last, inInclusiveRange(stallOvertime - dt, stallOvertime + 0.1), reason: '$more');
    }

    // The mini boss falling at full health counts as its HP lost.
    final (g, [mini, chief], filler, from) = slotFight(boss: true);
    listen(g);
    expect(mini.maxHp, greaterThan(stallProgress * (mini.maxHp + chief.maxHp)));
    while (g.t - from < 100) {
      filler.hp -= 1e4;
      g.tick(dt);
    }
    mini
      ..hp = 0
      ..dying = 0;
    g.tick(dt);
    final fell = g.t;
    while (!g.marching && g.t - fell < stallOvertime + 2) {
      filler.hp -= 1e4;
      g.tick(dt);
    }
    expect(heard.single.why, MarchCause.overtime);
    expect(heard.single.t - fell, inInclusiveRange(stallOvertime - dt, stallOvertime + 0.1));
  });

  test('a monster that stands still and takes no hurt stalls after stallTime, as before', () {
    final (g, m) = quietWave();
    listen(g);
    final start = g.t;
    while (!g.marching && g.t - start < stallTime + 2) {
      g.tick(dt);
    }
    expect(g.t - start, inInclusiveRange(stallTime, stallTime + 0.1));
    expect(heard.map((e) => e.why), [MarchCause.stalled]);
    expect(m.alive, isTrue);
  });
}
