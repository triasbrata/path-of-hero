// The catalog's shared hooks (catalog step 0f, decisions-log 182; docs/loot-items-relics.md "The Pusaka catalog and its
// engine"): the duration scaler at addEffect (1 today: every time as given, to the bit), the per-tick near counts
// against a brute count, the once-an-HP-threshold flags, a unit's first strike, and the conditions the engine checks
// (hpBelow, hpAbove, foeHpBelow, foeHpAbove, alliesNear, firstOfTypeThisWave), each through a real trigger on a row
// swapped in for the test. Today's rows use none of them (pusaka_catalog_test.dart); the hit-source tag:
// hit_source_test.dart.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// A game with no skills cast, so what happens is the hooks' and the Pusaka's doing.
Game plain([Random? rng]) => bareGame(rng)
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false
  ..monsterSkills = false;

/// Lets [foe] strike once now (then it stands again).
void strikeBy(Game g, Unit foe) {
  foe
    ..busyUntil = double.negativeInfinity
    ..cd = 0;
  g.tick(0.05);
  foe.busyUntil = hold;
}

/// What [foe]'s blow takes off [u] when [u] stands at [share] of its max HP.
double took(Game g, Unit u, Unit foe, double share) {
  u.hp = u.maxHp * share;
  final before = u.hp;
  strikeBy(g, foe);
  return before - u.hp;
}

/// Runs [body] with [relic]'s row holding [fx] in place of its own (the rest of the row kept), then puts the row back.
/// A Pusaka given inside [body] is booked from the swapped row.
void withFx(Relic relic, List<Fx> fx, void Function() body) {
  final was = pusakaCatalog[relic]!;
  pusakaCatalog[relic] = Art(was.rarity, was.role, was.icon,
      fx: fx, epithet: was.epithet, counter: was.counter, healerCounter: was.healerCounter, store: was.store, live: was.live);
  try {
    body();
  } finally {
    pusakaCatalog[relic] = was;
  }
}

/// A wave on at wave 10 with [type]'s troop at cell (2, 3) holding [relic] (standing still, never striking) and an orc
/// next to it that strikes only when told ([strikeBy]).
(Game, Unit, Unit) struck(Relic relic, [String type = 'knight_templar']) {
  final g = plain()..wave = 9;
  final k = placeNow(g, type, 2, 3)..busyUntil = hold;
  g
    ..givePusaka(relic, type: type)
    ..startWave()
    ..queue.clear();
  return (g, k, foeAt(g, 'orc', k.pos + const Point(12, 0)));
}

void main() {
  test('the duration scaler: at 1 every effect lasts its own time, to the bit; shortened, never under 0.3 s (or its own '
      'time, when shorter); lengthened, times k', () {
    for (final time in [0.0, 0.05, 0.25, 0.3, 1 / 3, 1.0, 2.5, 5.0, 12.75, 1e9, double.infinity]) {
      expect(scaledEffectTime(time, 1), time, reason: '$time');
    }
    expect(effectTimeFloor, 0.3);
    expect(scaledEffectTime(2, 0.5), 1);
    expect(scaledEffectTime(0.5, 0.2), effectTimeFloor);
    expect(scaledEffectTime(0.2, 0.5), 0.2, reason: 'never longer than it was');
    expect(scaledEffectTime(2, 1.4), closeTo(2.8, 1e-12));
    // addEffect, the one place: every status on a monster and a troop ends at t + its time exactly.
    final g = plain()..t = 12.345;
    final k = placeNow(g, 'knight', 2, 3), orc = foeAt(g, 'orc', const Point(200, 60));
    for (final u in [k, orc]) {
      for (final s in Status.values) {
        if (s == Status.hex) continue; // swaps the monster's stats: its own test (hero_skills_test.dart)
        for (final time in [0.1, 2.5, 7.0]) {
          u.effects.remove(s);
          g.addEffect(u, s, time, k: s.base * 1.1, by: u == k ? orc : k, n: 2);
          expect(u.effects[s]!.until, g.t + time, reason: '${u.type} ${s.name} $time');
        }
      }
    }
  });

  test('the near counts match a brute count, for either side, any reach, the dead, the gone and those not yet on; '
      'counted once a tick for a reach', () {
    final g = plain(Random(1)), dice = Random(42);
    Point<double> anywhere() => Point(dice.nextDouble() * 400, dice.nextDouble() * fieldH);
    for (var c = 0; c < 4; c++) {
      for (var r = 0; r < 5; r++) {
        placeNow(g, 'soldier', c, r)
          ..pos = anywhere()
          ..busyUntil = hold;
      }
    }
    for (var i = 0; i < 25; i++) {
      foeAt(g, 'orc', anywhere());
    }
    g.units[3].entered = false;
    g.units[7].gone = true;
    g.units[22].dying = 0;
    g.units[30].entered = false;
    g.units[41].gone = true;
    int brute(Unit u, double r, {required bool allies}) => g.units
        .where((o) => o != u && (o.side == u.side) == allies && o.alive && o.entered && o.pos.distanceTo(u.pos) <= r)
        .length;
    void check() {
      for (final u in g.units) {
        for (final r in [0.0, 16.0, 24.0, 48.0, 100.0, 1000.0, 48.0]) {
          expect(g.alliesNearOf(u, r), brute(u, r, allies: true), reason: 'allies of ${g.units.indexOf(u)} within $r');
          expect(g.foesNearOf(u, r), brute(u, r, allies: false), reason: 'foes of ${g.units.indexOf(u)} within $r');
        }
      }
    }

    check();
    expect(g.units.map((u) => g.alliesNearOf(u, 1000)).reduce(max), greaterThan(10), reason: 'a crowd to count');
    // Asked again in the same tick at the same reach: the counts stand, though a troop and a monster have stepped up.
    final u = g.units.first;
    bool far(Unit o) => o != u && o.alive && o.entered && o.pos.distanceTo(u.pos) > 30;
    final mate = g.troops.firstWhere(far), foe = g.enemies.firstWhere(far);
    final before = (g.alliesNearOf(u, 30), g.foesNearOf(u, 30));
    mate.pos = u.pos + const Point(5, 0);
    foe.pos = u.pos + const Point(0, 5);
    expect((brute(u, 30, allies: true), brute(u, 30, allies: false)), (before.$1 + 1, before.$2 + 1));
    expect((g.alliesNearOf(u, 30), g.foesNearOf(u, 30)), before);
    g.tick(1e-6); // the next tick counts afresh
    expect(g.alliesNearOf(u, 30), brute(u, 30, allies: true));
    expect(g.foesNearOf(u, 30), brute(u, 30, allies: false));
    check();
  });

  test('belowOnce: true once for a flag when HP is at or under its share; each flag its own; a killing blow uses none; a '
      'troop\'s flags answer again when a wave starts', () {
    final g = plain();
    final orc = foeAt(g, 'orc', const Point(200, 60));
    expect(g.belowOnce(orc, 0.5, 0), isFalse, reason: 'full HP');
    orc.hp = orc.maxHp * 0.5;
    expect(g.belowOnce(orc, 0.5, 0), isTrue);
    expect(g.belowOnce(orc, 0.5, 0), isFalse, reason: 'once');
    expect(g.belowOnce(orc, 0.35, 1), isFalse, reason: 'half is not under 35%');
    expect(g.belowOnce(orc, 0.6, 2), isTrue, reason: 'its own bit');
    orc.hp = orc.maxHp.toDouble();
    orc.hp = orc.maxHp * 0.3;
    expect(g.belowOnce(orc, 0.5, 0), isFalse, reason: 'healed and hurt again: still used');
    orc.hp = 0;
    expect(g.belowOnce(orc, 0.35, 1), isFalse, reason: 'a killing blow uses none');
    orc.hp = orc.maxHp * 0.3;
    expect(orc.belowHp, 1 | 4);
    final k = placeNow(g, 'knight', 2, 3)..hp = 10;
    expect((g.belowOnce(k, 0.5, 0), g.belowOnce(k, 0.5, 0), g.belowOnce(k, 0.5, 62)), (true, false, true));
    g.units.remove(orc); // the wave won (a wave starts only with no monster on the field)
    g
      ..startWave()
      ..queue.clear();
    expect(g.waveActive, isFalse);
    expect(k.belowHp, 0);
    expect(g.belowOnce(k, 0.5, 0), isTrue, reason: 'a new wave');
  });

  test('firstStrikeAt: when a unit first struck (its first blow as the attacker), kept after; a troop\'s anew each wave',
      () {
    final g = plain();
    final k = placeNow(g, 'knight', 2, 3), orc = foeAt(g, 'orc', k.pos + const Point(14, 0))..hp = 100000;
    expect((k.firstStrikeAt, orc.firstStrikeAt), (double.infinity, double.infinity));
    k.cd = 0;
    g.tick(0.05);
    final first = g.t;
    expect(orc.hp, lessThan(100000), reason: 'it struck');
    expect(k.firstStrikeAt, first);
    k.cd = 0;
    g.tick(0.05);
    expect(k.firstStrikeAt, first, reason: 'its first stays');
    g.units.remove(orc); // the wave won (a wave starts only with no monster on the field)
    g
      ..startWave()
      ..queue.clear();
    k.busyUntil = hold;
    expect(k.firstStrikeAt, double.infinity, reason: 'a troop strikes first anew each wave');
    final orc2 = foeAt(g, 'orc', k.pos + const Point(12, 0))..hp = 100000; // within an orc's reach
    strikeBy(g, orc2);
    final bit = g.t;
    expect(k.hp, lessThan(k.maxHp), reason: 'it struck');
    expect(orc2.firstStrikeAt, bit);
    strikeBy(g, orc2);
    expect(g.t, greaterThan(bit));
    expect((orc2.firstStrikeAt, k.firstStrikeAt), (bit, double.infinity));
  });

  test('hpAbove and hpBelow: a struck cut only while its troop is over / under its share of max HP, as the blow finds it',
      () {
    for (final (cond, share, on, off) in [(If.hpAbove, 0.8, [1.0, 0.85], [0.8, 0.5]), (If.hpBelow, 0.4, [0.3, 0.35], [0.4, 1.0])]) {
      withFx(Relic.ironBanner, [Fx(Trig.struck, Eff.cut, To.self, when: cond, ifK: share, k: const [0.5])], () {
        final (g, k, orc) = struck(Relic.ironBanner);
        final blow = hitTaken(orc.stats.dmg, k.stats.def);
        expect(blow, lessThan(k.maxHp * 0.3));
        for (final s in on) {
          expect(took(g, k, orc, s), closeTo(blow * 0.5, 1e-9), reason: '$cond at $s');
        }
        for (final s in off) {
          expect(took(g, k, orc, s), closeTo(blow, 1e-9), reason: '$cond at $s: not over / under it');
        }
      });
    }
  });

  test('foeHpAbove and foeHpBelow: on a struck cut, the attacker\'s HP; on an attack\'s power, the target\'s', () {
    withFx(Relic.ironBanner, [Fx(Trig.struck, Eff.cut, To.self, when: If.foeHpAbove, ifK: 0.9, k: const [0.5])], () {
      final (g, k, orc) = struck(Relic.ironBanner);
      final blow = hitTaken(orc.stats.dmg, k.stats.def);
      expect(took(g, k, orc, 1), closeTo(blow * 0.5, 1e-9), reason: 'a fresh orc');
      orc.hp = orc.maxHp * 0.5;
      expect(took(g, k, orc, 1), closeTo(blow, 1e-9), reason: 'a hurt orc');
    });
    withFx(Relic.warDrum, [Fx(Trig.attack, Eff.power, To.foeHit, when: If.foeHpBelow, ifK: 0.3, k: const [2.0])], () {
      final g = plain()..wave = 30;
      final k = placeNow(g, 'knight', 2, 3);
      g.givePusaka(Relic.warDrum, type: 'knight');
      final bear = foeAt(g, 'werebear', k.pos + const Point(14, 0), Tier.miniBoss);
      double hit(double share) {
        bear.hp = bear.maxHp * share;
        final before = bear.hp;
        k.cd = 0;
        g.tick(0.05);
        return before - bear.hp;
      }

      expect(hit(0.5), closeTo(hitTaken(k.stats.dmg, bear.stats.def), 1e-9), reason: 'half: not under 30%');
      expect(hit(0.2), closeTo(hitTaken(k.stats.dmg * 2, bear.stats.def), 1e-9), reason: 'under 30%: x2');
      expect(hit(0.3), closeTo(hitTaken(k.stats.dmg, bear.stats.def), 1e-9), reason: 'at 30%: not under it');
      expect(g.pusakaWorth[Relic.warDrum]!.uses, 1);
    });
  });

  test('alliesNear: a struck cut while ifK or more other troops stand within ifR of it; monsters don\'t count; counted '
      'afresh each blow\'s tick', () {
    withFx(Relic.ironBanner, [Fx(Trig.struck, Eff.cut, To.self, when: If.alliesNear, ifK: 3, ifR: 40, k: const [0.5])], () {
      final (g, k, orc) = struck(Relic.ironBanner);
      final mates = [
        for (final (c, r) in [(1, 3), (2, 2), (2, 4)])
          placeNow(g, 'soldier', c, r)
            ..busyUntil = hold
            ..hp = 1e6,
      ];
      for (final (i, d) in [const Point(-20.0, 0.0), const Point(0.0, -20.0), const Point(0.0, 20.0)].indexed) {
        mates[i].pos = k.pos + d;
      }
      final blow = hitTaken(orc.stats.dmg, k.stats.def);
      expect(took(g, k, orc, 1), closeTo(blow * 0.5, 1e-9), reason: 'three near');
      mates.last.pos = k.pos + const Point(100, 0);
      foeAt(g, 'orc', k.pos + const Point(0, 30)); // a monster near counts for nothing
      expect(took(g, k, orc, 1), closeTo(blow, 1e-9), reason: 'two near');
      mates.last.pos = k.pos + const Point(-30, 10);
      expect(took(g, k, orc, 1), closeTo(blow * 0.5, 1e-9), reason: 'three again');
    });
  });

  test('firstOfTypeThisWave: the first troop of the type struck this wave gets it and no other; a new wave, the first '
      'again', () {
    withFx(Relic.ironBanner, [Fx(Trig.struck, Eff.cut, To.self, when: If.firstOfTypeThisWave, k: const [0.5])], () {
      final (g, a, orc) = struck(Relic.ironBanner);
      final b = placeNow(g, 'knight_templar', 4, 6)..busyUntil = hold;
      final blow = hitTaken(orc.stats.dmg, a.stats.def);
      expect(took(g, a, orc, 1), closeTo(blow * 0.5, 1e-9), reason: 'the first');
      orc.pos = b.pos + const Point(12, 0);
      expect(took(g, b, orc, 1), closeTo(blow, 1e-9), reason: 'another of the type');
      orc.pos = a.pos + const Point(12, 0);
      expect(took(g, a, orc, 1), closeTo(blow, 1e-9), reason: 'the first again, the same wave');
      orc.gone = true;
      g.tick(0.05);
      expect(g.waveActive, isFalse, reason: 'won');
      g
        ..startWave()
        ..queue.clear();
      final orc2 = foeAt(g, 'orc', b.pos + const Point(12, 0));
      final blow2 = hitTaken(orc2.stats.dmg, b.stats.def);
      expect(took(g, b, orc2, 1), closeTo(blow2 * 0.5, 1e-9), reason: 'a new wave: its first');
      expect(took(g, b, orc2, 1), closeTo(blow2, 1e-9));
    });
  });
}
