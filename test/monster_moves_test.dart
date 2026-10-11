import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

// #59's groundwork (the PREP branch): #48's effects, moves and ground objects working the other way, monster
// on troop, for the monster skills to build on: weaken and vulnerable on a troop, a troop knocked back,
// dragged, leapt on and charged through by a monster, a troop's stun limits (stunTroop), a beam that follows
// its units and the rings that burst out. The skills themselves are in monster_skills_test.dart.

/// A game with nobody on the field and the troops' own skills (#10) off.
Game empty() => Game()
  ..units.clear()
  ..skills = false;

/// Troop [type] standing at [at], on the field, that never walks or strikes on its own ([hold]); only what
/// carries it moves it.
Unit troop(Game g, String type, Point<double> at) {
  final u = Unit(Side.troop, type, troopTypes[type]!, at)
    ..entered = true
    ..arriving = false
    ..busyUntil = hold
    ..cd = hold;
  g.units.add(u);
  return u;
}

/// Monster [type] at [at], on the field, standing still and never striking unless let ([hold]).
Unit monsterAt(Game g, String type, Point<double> at) {
  final u = g.monster(type, Tier.normal, at)
    ..entered = true
    ..busyUntil = hold;
  g.units.add(u);
  return u;
}

/// Unit [u] strikes its nearest foe once, now (it must be in its reach): one tick.
void strikeOnce(Game g, Unit u) {
  u
    ..busyUntil = double.negativeInfinity
    ..cd = 0;
  g.tick(0.05);
  u
    ..busyUntil = hold
    ..cd = hold;
}

/// Ticks [g] for [secs] game seconds in 0.05 s steps.
void play(Game g, double secs) {
  for (var i = 0; i < (secs / 0.05).round(); i++) {
    g.tick(0.05);
  }
}

void main() {
  group('effects both ways', () {
    test('weaken on a troop cuts what it deals: its blow, its shot and its skill', () {
      final g = empty();
      final k = troop(g, 'knight', const Point(100, 64)), orc = monsterAt(g, 'orc', const Point(112, 64));
      g.addEffect(k, Status.weaken, 5, k: 0.75, by: orc);
      strikeOnce(g, k);
      expect(orc.hp, closeTo(orc.maxHp - hitTaken(k.stats.dmg * 0.75, orc.stats.def), 1e-9));

      final a = empty();
      final archer = troop(a, 'archer', const Point(40, 64)), far = monsterAt(a, 'werebear', const Point(100, 64));
      a.addEffect(archer, Status.weaken, 5, k: 0.75);
      strikeOnce(a, archer);
      play(a, 1); // the arrow flies, then lands
      expect(far.hp, closeTo(far.maxHp - hitTaken(archer.stats.dmg * 0.75, far.stats.def), 1e-9));

      final (h, knight) = heroCaster(HeroSkill.cleave);
      final bear = foeAt(h, 'werebear', knight.pos + Point(knight.stats.range, 0));
      h.addEffect(knight, Status.weaken, 5, k: 0.75);
      h.tick(0.05); // Cleave: one blow of cleaveK.hit x its damage
      expect(bear.hp, closeTo(bear.maxHp - hitTaken(knight.stats.dmg * cleaveK.hit * 0.75, bear.stats.def), 1e-9));
    });

    test("vulnerable on a troop raises what monsters' blows take from it; a blow with no attacker doesn't count", () {
      final g = empty();
      final s = troop(g, 'soldier', const Point(100, 64)), orc = monsterAt(g, 'orc', const Point(112, 64));
      g.addEffect(s, Status.vulnerable, 5, k: 1.15, by: orc);
      strikeOnce(g, orc);
      final blow = hitTaken(orc.stats.dmg, s.stats.def) * 1.15;
      expect(s.hp, closeTo(s.maxHp - blow, 1e-9));
      // A bleed whose source is gone (no attacker): its ticks aren't raised.
      g.addEffect(s, Status.bleed, 3, k: 5, n: 1);
      play(g, 1.05);
      expect(s.hp, closeTo(s.maxHp - blow - hitTaken(5, s.stats.def), 1e-9));
    });

    test("a monster's shot counts as its blow: a glob raises by vulnerable and its onHit lands on the troop", () {
      final g = empty();
      final s = troop(g, 'soldier', const Point(40, 64)), slime = monsterAt(g, 'slime', const Point(100, 64));
      g
        ..addEffect(s, Status.vulnerable, 5, k: 1.15)
        ..shots.add(Shot.special(slime, s, slime.pos,
            dmg: 10, speed: 120, look: ShotLook.glob, onHit: (o) => g.addEffect(o, Status.slow, 3, k: 0.7, by: slime)));
      play(g, 1);
      expect(g.shots, isEmpty);
      expect(s.hp, closeTo(s.maxHp - hitTaken(10, s.stats.def) * 1.15, 1e-9));
      expect(g.effectK(s, Status.slow), 0.7);
    });
  });

  group('moves on troops', () {
    test('a knockback shoves a troop towards the base by default, a Hero heroShoveShare as far; a monster still away from it', () {
      final g = empty();
      final s = troop(g, 'soldier', const Point(150, 30)), h = troop(g, 'knight', const Point(150, 100))..hero = true;
      final orc = monsterAt(g, 'orc', const Point(200, 64));
      expect((shoveShare(s), shoveShare(h), shoveShare(orc)), (1.0, heroShoveShare, 1.0));
      expect((g.knockBack(s, tile), g.knockBack(h, tile), g.knockBack(orc, tile)), (true, true, true));
      play(g, slideTime);
      expect((s.pos.x, h.pos.x, orc.pos.x), (150 - tile, 150 - tile * heroShoveShare, 200 + tile));
      expect((s.pos.y, h.pos.y), (30.0, 100.0));
    });

    test('a knockback never takes a troop behind the back line; a braced, carried or noShove one stays put', () {
      final g = empty();
      final rear = max(g.baseX, g.cam) + Game.clearOfLine;
      final near = troop(g, 'soldier', Point(rear + 6, 30));
      g.knockBack(near, tile);
      play(g, slideTime);
      expect(near.pos.x, closeTo(rear, 1e-9));

      final f = empty();
      monsterAt(f, 'orc', const Point(300, 10)); // keeps the wave on: a brace holds only during one
      final braced = troop(f, 'lancer', const Point(150, 30)), firm = troop(f, 'soldier', const Point(150, 60));
      final hopping = troop(f, 'knight', const Point(150, 100));
      f
        ..brace(braced, 5)
        ..addEffect(firm, Status.noShove, 5)
        ..leap(hopping, const Point(180, 100));
      expect((f.knockBack(braced, tile), f.knockBack(firm, tile), f.knockBack(hopping, tile)), (false, false, false));
      expect(f.drag(braced, const Point(100, 30)), isFalse);
      play(f, hopTime);
      expect((braced.pos.x, firm.pos.x, hopping.pos.x), (150.0, 150.0, 180.0));
    });

    test('a monster leaps onto a troop: in the air it passes over the others, and it lands once beside it', () {
      final g = empty();
      final priest = troop(g, 'priest', const Point(60, 64)), guard = troop(g, 'soldier', const Point(90, 64));
      final bat = monsterAt(g, 'bat', const Point(130, 64));
      var landed = 0;
      final to = g.beside(priest, bat.pos, besideGap + 2); // a hair past the personal space: nobody shoves it after
      g.leap(bat, to, () => landed++);
      play(g, hopTime / 2);
      expect(bat.move?.liftAt(g.t), greaterThan(hopHeight * 0.9));
      play(g, hopTime / 2 + 0.1);
      expect(landed, 1);
      expect(bat.pos.distanceTo(to), lessThan(1e-6));
      expect(guard.pos, const Point(90.0, 64.0)); // hopped over, not through a shove
    });

    test('a monster charges a troop: each troop on its path takes hit x, then onPass, then is shoved aside; monsters on it are left alone', () {
      final g = empty();
      final priest = troop(g, 'priest', const Point(40, 64)), front = troop(g, 'soldier', const Point(90, 66));
      final hero = troop(g, 'knight', const Point(70, 62))..hero = true;
      final rider = monsterAt(g, 'orc_rider', const Point(140, 64)), other = monsterAt(g, 'slime', const Point(115, 64));
      final passed = <Unit>[];
      late ({double frontHp, double frontY, double heroY}) seen;
      var arrived = 0;
      g.charge(rider, priest, speed: 2, lane: 8, hit: 1, shove: tile / 2, onPass: passed.add, onArrive: () {
        arrived++;
        seen = (frontHp: front.hp, frontY: front.pos.y, heroY: hero.pos.y);
      });
      play(g, 2);
      expect(arrived, 1);
      expect(passed, [front, hero]);
      expect(seen.frontHp, closeTo(front.maxHp - hitTaken(rider.stats.dmg, front.stats.def), 1e-9));
      expect(seen.frontY, closeTo(66 + tile / 2, 1e-6)); // aside, away from the path
      expect(seen.heroY, closeTo(62 - tile / 2 * heroShoveShare, 1e-6)); // a Hero half as far
      expect((other.hp, priest.hp), (other.maxHp.toDouble(), priest.maxHp.toDouble()));
    });

    test("a charge with hit 0 lands no blow of its own: onPass is the skill's", () {
      final g = empty();
      final priest = troop(g, 'priest', const Point(40, 64)), front = troop(g, 'soldier', const Point(90, 64));
      final rider = monsterAt(g, 'orc_rider', const Point(140, 64));
      g.charge(rider, priest, speed: 2, lane: 8, hit: 0, shove: 0, onPass: (o) => o.hp -= 7);
      play(g, 2);
      expect(front.hp, front.maxHp - 7);
      expect(front.hurtAt, double.negativeInfinity); // no plain blow went through _hurt
    });

    test('a monster drags a troop to the spot, never behind the back line', () {
      final g = empty();
      final rear = max(g.baseX, g.cam) + Game.clearOfLine;
      final s = troop(g, 'soldier', const Point(120, 64)), back = troop(g, 'archer', Point(rear + 20, 30));
      final orc = monsterAt(g, 'orc', const Point(160, 64));
      var ended = 0;
      expect(g.drag(s, g.beside(orc, s.pos, besideGap), by: orc, onEnd: () => ended++), isTrue);
      expect(g.drag(back, Point(rear - 30, 30)), isTrue);
      play(g, dragTime + 0.05);
      expect(ended, 1);
      expect(s.pos.distanceTo(orc.pos), closeTo(besideGap, 1e-6));
      expect(back.pos.x, closeTo(rear, 1e-9));
    });
  });

  group("a troop's stun (stunTroop)", () {
    test('it lasts at most troopStunK.most, a Hero half of that; the troop stands frozen meanwhile', () {
      final g = empty();
      final s = troop(g, 'soldier', const Point(100, 64))..busyUntil = double.negativeInfinity;
      final h = troop(g, 'knight', const Point(100, 100))..hero = true;
      monsterAt(g, 'orc', const Point(112, 64));
      final t0 = g.t;
      expect((g.stunTroop(s, 3), g.stunTroop(h, 3)), (true, true));
      expect(s.stunUntil, closeTo(t0 + troopStunK.most, 1e-9));
      expect(h.stunUntil, closeTo(t0 + troopStunK.most * troopStunK.hero, 1e-9));
      s.cd = 0; // it would strike the orc in its reach, but stands frozen
      play(g, 0.5);
      expect(s.attackedAt, double.negativeInfinity);
      play(g, 0.4);
      expect(s.attackedAt, greaterThan(t0 + troopStunK.most - 1e-9)); // free again: it strikes
    });

    test('after a stun the troop is immune for troopStunK.immune s: a stun meanwhile does nothing; then it takes again', () {
      final g = empty();
      final s = troop(g, 'soldier', const Point(100, 64));
      monsterAt(g, 'orc', const Point(300, 64));
      expect(g.stunTroop(s, 0.5), isTrue);
      expect(s.stunImmuneUntil, closeTo(g.t + 0.5 + troopStunK.immune, 1e-9));
      play(g, 1);
      final until = s.stunUntil;
      expect(g.stunTroop(s, 0.5), isFalse);
      expect(s.stunUntil, until);
      play(g, troopStunK.immune - 0.4);
      expect(g.stunTroop(s, 0.5), isTrue);
    });

    test("a Hero stunned mid-skill still gets the blows its skill queued (Whirlwind's cuts): the stun holds only what it starts next", () {
      double spun({required bool stunned}) {
        final (g, h) = heroCaster(HeroSkill.whirlwind);
        final foes = [for (final d in [const Point(12.0, 0.0), const Point(-8.0, 10.0), const Point(0.0, -12.0)]) foeAt(g, 'werebear', h.pos + d)];
        g.tick(0.05); // the first cut, the other three queued
        if (stunned) expect(g.stunTroop(h, 0.8), isTrue);
        runFor(g, whirlwindK.hits * whirlwindK.gap);
        return foes.first.maxHp - foes.first.hp;
      }

      expect(spun(stunned: true), closeTo(spun(stunned: false), 1e-9));
      expect(spun(stunned: false), greaterThan(0));
    });
  });

  group('ground objects', () {
    test('a beam between units follows them as they move, and goes as soon as one falls', () {
      final g = empty();
      final necro = monsterAt(g, necroHealer, const Point(160, 64)), s = troop(g, 'soldier', const Point(100, 64));
      final b = Beam.between([necro, s], since: g.t, duration: 3, look: BeamLook.drain);
      g.beams.add(b);
      s.pos = const Point(90, 70);
      expect(b.at, [necro.pos, const Point(90.0, 70.0)]);
      play(g, 1);
      expect(g.beams, [b]);
      s.gone = true;
      g.tick(0.05);
      expect(g.beams, isEmpty);
      // A plain beam keeps its points and goes when its time is up.
      final plain = Beam([const Point(0.0, 0.0), const Point(10.0, 0.0)], since: g.t, duration: 0.3);
      g.beams.add(plain);
      expect(plain.at, [const Point(0.0, 0.0), const Point(10.0, 0.0)]);
      expect(plain.broken, isFalse);
      play(g, 0.35);
      expect(g.beams, isEmpty);
    });

    test('a ring bursts for ringTime unless told otherwise, then goes', () {
      final g = empty();
      monsterAt(g, 'orc', const Point(300, 64));
      g.rings
        ..add(Ring(const Point(100, 64), radius: 3 * tile, since: g.t, look: RingLook.red))
        ..add(Ring(const Point(100, 64), radius: tile, since: g.t, look: RingLook.dark, duration: 1.5));
      expect(g.rings.first.until, closeTo(g.t + ringTime, 1e-9));
      play(g, ringTime + 0.05);
      expect(g.rings.single.look, RingLook.dark);
      play(g, 1);
      expect(g.rings, isEmpty);
    });

    test("the new zone looks are zones like any: a slime puddle slows the troops in it, Bone Rain's pulses hurt them", () {
      final g = empty();
      final archer = monsterAt(g, 'skeleton_archer', const Point(200, 64));
      final inIt = troop(g, 'soldier', const Point(100, 64)), out = troop(g, 'soldier', const Point(100, 120));
      g.zones
        ..add(Zone(archer, const Point(100, 64),
            since: g.t, duration: 2, radius: 1.5 * tile, side: Side.troop, look: ZoneLook.slime, inside: (u) => g.addEffect(u, Status.slow, 0.2, k: 0.6)))
        ..add(Zone(archer, const Point(100, 64),
            since: g.t, duration: 2, radius: 1.5 * tile, side: Side.troop, look: ZoneLook.arrowRain, pulse: (u) => g.addEffect(u, Status.weaken, 1, k: 0.9)));
      g.tick(0.05);
      expect((g.effectK(inIt, Status.slow), g.effectK(out, Status.slow)), (0.6, 1.0));
      expect((g.effectK(inIt, Status.weaken), g.effectK(out, Status.weaken)), (0.9, 1.0));
    });
  });
}
