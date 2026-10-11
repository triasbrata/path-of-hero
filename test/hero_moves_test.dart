import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

// #48 branch 2a (lib/hero_moves.dart): the forced movement on its own (the knockback, the leap, the drag, the
// charge and the brace), then the seven movement Hero skills built on it: each one's rule and effect, the
// march guard and the boss rules.

/// A game with nobody on the field and the troops' own skills (#10) off.
Game empty() => Game()
  ..units.clear()
  ..skills = false;

/// Troop [type] standing at [at], on the field.
Unit troop(Game g, String type, Point<double> at) {
  final u = Unit(Side.troop, type, troopTypes[type]!, at)
    ..entered = true
    ..arriving = false;
  g.units.add(u);
  return u;
}

/// Monster [type] of [tier] at [at], on the field and standing still unless [still] is false.
Unit foe(Game g, String type, Point<double> at, {Tier tier = Tier.normal, bool still = true}) {
  final u = g.monster(type, tier, at)..entered = true;
  if (still) u.busyUntil = hold;
  g.units.add(u);
  return u;
}

/// Ticks [g] for [secs] game seconds in 0.05 s steps.
void play(Game g, double secs) {
  for (var i = 0; i < (secs / 0.05).round(); i++) {
    g.tick(0.05);
  }
}

void main() {
  test('a knockback slides a monster a tile away from the base over slideTime, and it does nothing else meanwhile', () {
    final g = empty();
    final orc = foe(g, 'orc', const Point(150, 64), still: false), knight = troop(g, 'knight', const Point(140, 64))..busyUntil = hold;
    expect(g.knockBack(orc, tile), isTrue);
    g.tick(0.05);
    expect(orc.pos.x, greaterThan(150));
    expect(orc.pos.x, lessThan(150 + tile));
    expect(orc.attackedAt, double.negativeInfinity); // carried: no blow, though the knight is in its reach
    play(g, slideTime - 0.05); // it gets there on the tick slideTime ends
    expect(orc.pos.x, closeTo(150 + tile, 1e-6));
    expect(orc.pos.y, 64);
    expect(orc.move, isNull);
    expect(knight.hp, knight.maxHp);
  });

  test('a mini boss is knocked back half as far and the boss not at all', () {
    final g = empty();
    final mini = foe(g, 'werebear', const Point(120, 30), tier: Tier.miniBoss);
    final big = foe(g, boss, const Point(120, 90), tier: Tier.boss);
    expect(shoveShare(mini), 0.5);
    expect(shoveShare(big), 0.0);
    expect(g.knockBack(mini, tile), isTrue);
    expect(g.knockBack(big, tile), isFalse);
    expect(big.move, isNull);
    play(g, 0.5);
    expect(mini.pos.x, closeTo(120 + tile / 2, 1e-6));
    expect(big.pos.x, 120);
  });

  test('a knockback never pushes a monster out past the right edge; one already past it stays (#42)', () {
    final g = empty();
    final edge = g.rightLimit;
    final near = foe(g, 'slime', Point(edge - 4, 40)), out = foe(g, 'slime', Point(edge + 20, 90))..entered = false;
    g.knockBack(near, tile);
    g.knockBack(out, tile);
    for (var i = 0; i < 10; i++) {
      g.tick(0.05);
      expect(near.pos.x, lessThanOrEqualTo(max(g.rightLimit, edge - 4) + 1e-9));
    }
    expect(near.pos.x, greaterThan(edge - 4));
    expect(out.pos.x, edge + 20);
  });

  test('a knockback sideways moves the monster along the given direction, kept inside the field', () {
    final g = empty();
    final orc = foe(g, 'orc', Point(120, fieldH - 6));
    g.knockBack(orc, tile, const Point(0.0, 1.0));
    play(g, 0.5);
    expect(orc.pos.x, 120);
    expect(orc.pos.y, fieldH - 2); // the bottom row's edge, not past it
  });

  test('a leap hops a troop to the spot in hopTime, rising hopHeight at its middle; it lands once, over whoever is under it', () {
    final g = empty();
    final knight = troop(g, 'knight', const Point(100, 64));
    final under = foe(g, 'slime', const Point(124, 64)); // on the way, in the knight's reach at mid-hop
    var landed = 0;
    g.leap(knight, const Point(148, 64), () => landed++);
    final hop = knight.move! as Carry;
    expect(hop.liftAt(hop.start + hopTime / 2), closeTo(hopHeight, 1e-9));
    expect(hop.liftAt(hop.start), 0);
    expect(hop.liftAt(hop.end), 0);
    for (var i = 0; i < 7; i++) { // 7 × 0.05 = hopTime: it lands on the last
      g.tick(0.05);
      if (knight.move != null) {
        expect(knight.attackedAt, double.negativeInfinity); // in the air: no blow
        expect(under.pos, const Point(124.0, 64.0)); // hopped over, not shoved
      }
    }
    expect(landed, 1);
    expect(knight.move, isNull);
    expect(knight.pos, const Point(148.0, 64.0)); // landed (the slime 24 away doesn't shove it)
  });

  test('a drag pulls a monster to the spot in dragTime and then runs its end; never the boss', () {
    final g = empty();
    final axe = troop(g, 'armored_axeman', const Point(100, 64))..busyUntil = hold;
    final archer = foe(g, 'skeleton_archer', const Point(170, 30));
    final spot = g.beside(axe, archer.pos, 14);
    expect(spot.distanceTo(axe.pos), closeTo(14, 1e-9));
    var ended = 0;
    expect(g.drag(archer, spot, onEnd: () => ended++), isTrue);
    play(g, dragTime - 0.05);
    expect(ended, 0);
    play(g, 0.1);
    expect(ended, 1);
    expect(archer.pos.distanceTo(axe.pos), closeTo(14, 0.5));
    final big = foe(g, boss, const Point(170, 100), tier: Tier.boss);
    expect(g.drag(big, spot), isFalse);
    expect(big.move, isNull);
  });

  test('a charge gallops at the target at k x speed, hits and shoves aside each foe along its path once, and arrives once', () {
    final g = empty();
    final lancer = troop(g, 'lancer', const Point(100, 64));
    final target = foe(g, 'orc', const Point(180, 64)); // 5 tiles ahead
    final passed = foe(g, 'slime', const Point(140, 68)); // 4 off the path
    final clear = foe(g, 'slime', const Point(140, 100)); // 36 off it
    var arrived = 0;
    late ({double gap, double targetHp, double passedHp, double passedY, double clearHp, Point<double> clearAt}) seen;
    g.charge(lancer, target, speed: 3, lane: 8, hit: 1, shove: tile / 2, onArrive: () {
      arrived++;
      seen = (gap: lancer.pos.distanceTo(target.pos), targetHp: target.hp, passedHp: passed.hp, passedY: passed.pos.y,
          clearHp: clear.hp, clearAt: clear.pos);
    });
    g.tick(0.05);
    expect(lancer.pos.x, closeTo(100 + 3 * lancer.stats.speed * 0.05, 1e-6));
    play(g, 1.5);
    expect(arrived, 1);
    expect(lancer.move, isNull);
    expect(seen.gap, lessThanOrEqualTo(lancer.stats.range));
    expect(seen.targetHp, target.maxHp); // the target's blow is the skill's own, in onArrive
    expect(passed.maxHp - seen.passedHp, closeTo(hitTaken(lancer.stats.dmg, passed.stats.def), 1e-9)); // hit once
    expect(seen.passedY, greaterThanOrEqualTo(68 + tile / 2)); // aside, away from the path
    expect(seen.clearHp, clear.maxHp);
    expect(seen.clearAt, const Point(140.0, 100.0));
  });

  test('a charge whose target dies on the way just stops', () {
    final g = empty();
    final lancer = troop(g, 'lancer', const Point(100, 64));
    final target = foe(g, 'orc', const Point(200, 64));
    var arrived = 0;
    g.charge(lancer, target, speed: 3, lane: 8, hit: 1, shove: 8, onArrive: () => arrived++);
    play(g, 0.2);
    target.gone = true;
    final at = lancer.pos;
    g.tick(0.05);
    expect(lancer.move, isNull);
    expect(arrived, 0);
    expect(lancer.pos.x, lessThan(at.x + 3 * lancer.stats.speed * 0.05));
  });

  test('a braced troop neither walks nor is shoved, meets each foe coming into its reach once, and lets go with the wave', () {
    final g = empty();
    final soldier = troop(g, 'soldier', const Point(100, 64));
    final close = foe(g, 'slime', const Point(106, 64)); // inside its personal space, in reach
    final far = foe(g, 'slime', const Point(160, 64)); // out of reach: it would walk up to it
    final met = <Unit>[];
    g.brace(soldier, 5, met.add);
    expect(g.braced(soldier), isTrue);
    play(g, 1);
    expect(soldier.pos, const Point(100.0, 64.0));
    expect(close.pos.x - soldier.pos.x, greaterThanOrEqualTo(11.9)); // the slime took the whole shove
    expect(met, [close]);
    play(g, 4.1);
    expect(g.braced(soldier), isFalse);
    expect(soldier.brace, isNull);
    // Braced again, then the wave ends: it lets go.
    g.brace(soldier, 5);
    close.gone = true;
    far.gone = true;
    g.tick(0.05);
    expect(g.waveActive, isFalse);
    expect(g.braced(soldier), isFalse);
  });

  group('the seven movement Hero skills', () {
    /// The first tick a Hero skill could cast in: whether it did.
    bool casts(Game g, Unit h) {
      g.tick(0.05);
      return h.heroSkillAt == g.t;
    }

    /// Hero [h]'s blow of [k] × its damage at [o], after [o]'s defence.
    double blow(Unit h, Unit o, double k) => hitTaken(h.stats.dmg * k, o.stats.def);

    test('Shield Bash: at an elite in reach, a 2x blow, a knockback of a tile and a 1.5 s stun; a mini boss half of both', () {
      for (final (tier, type) in [(Tier.elite, 'orc'), (Tier.highElite, 'orc'), (Tier.miniBoss, 'werebear')]) {
        final (g, h) = heroCaster(HeroSkill.shieldBash);
        final o = foeAt(g, type, h.pos + Point(h.stats.range, 0), tier), x = o.pos.x;
        expect(casts(g, h), isTrue, reason: tier.name);
        final half = tier == Tier.miniBoss ? 0.5 : 1.0;
        expect(o.hp, closeTo(o.maxHp - blow(h, o, shieldBashK.hit), 1e-9), reason: tier.name);
        expect(o.stunUntil, closeTo(g.t + shieldBashK.stun * half, 1e-9), reason: tier.name);
        runFor(g, slideTime + 0.05);
        expect(o.pos.x, closeTo(x + shieldBashK.shove * half, 1e-6), reason: tier.name);
      }
    });

    test('Shield Bash: a normal foe only while the soldier is below half its HP; the boss never as the strong one, and then only the blow', () {
      final (g, h) = heroCaster(HeroSkill.shieldBash);
      final o = foeAt(g, 'orc', h.pos + Point(h.stats.range, 0));
      expect(casts(g, h), isFalse);
      h.hp = h.maxHp * shieldBashK.below - 1;
      expect(casts(g, h), isTrue);
      expect(o.hp, closeTo(o.maxHp - blow(h, o, shieldBashK.hit), 1e-9));

      final (b, bh) = heroCaster(HeroSkill.shieldBash);
      final necro = foeAt(b, boss, bh.pos + Point(bh.stats.range, 0), Tier.boss), x = necro.pos.x;
      expect(casts(b, bh), isFalse, reason: 'the boss is no "strong one" for it');
      bh.hp = bh.maxHp * shieldBashK.below - 1;
      expect(casts(b, bh), isTrue);
      runFor(b, slideTime + 0.05);
      expect(necro.hp, closeTo(necro.maxHp - blow(bh, necro, shieldBashK.hit), 1e-9));
      expect((necro.pos.x, necro.stunUntil), (x, double.negativeInfinity));
    });

    test('Spear Sweep: with a foe ahead in its reach (decisions-log 298), a 1x blow to each foe ahead within reach + half a tile, knocked back a tile', () {
      final (g, h) = heroCaster(HeroSkill.sweep);
      final behind = foeAt(g, 'slime', h.pos + const Point(-15, 0)); // in reach, but behind it
      expect(casts(g, h), isFalse, reason: 'none ahead');
      final a = foeAt(g, 'slime', h.pos + const Point(18, 0));
      final b = foeAt(g, 'orc', h.pos + const Point(12, 14)), edge = foeAt(g, 'slime', h.pos + Point(h.stats.range + 4, -14)); // all 12+ apart
      final xs = {for (final o in [a, b, edge, behind]) o: o.pos.x};
      expect(casts(g, h), isTrue);
      for (final o in [a, b, edge]) {
        expect(o.hp, closeTo(o.maxHp - blow(h, o, sweepK.hit), 1e-9), reason: o.type);
      }
      expect(behind.hp, behind.maxHp);
      runFor(g, slideTime + 0.05);
      for (final o in [a, b, edge]) {
        expect(o.pos.x, closeTo(xs[o]! + sweepK.shove, 1e-6), reason: o.type);
      }
      expect(behind.pos.x, xs[behind]);
    });

    test('Spear Sweep: a mini boss goes half as far, the boss not at all', () {
      final (g, h) = heroCaster(HeroSkill.sweep);
      final mini = foeAt(g, 'werebear', h.pos + const Point(18, -8), Tier.miniBoss), big = foeAt(g, boss, h.pos + const Point(18, 10), Tier.boss);
      expect(mini.pos.distanceTo(big.pos), greaterThan(12));
      final (mx, bx) = (mini.pos.x, big.pos.x);
      expect(casts(g, h), isTrue);
      runFor(g, slideTime + 0.05);
      expect(mini.pos.x, closeTo(mx + sweepK.shove / 2, 1e-6));
      expect(big.pos.x, bx);
    });

    /// A Guardian Leap scene: the knight Hero, an archer behind it, and an orc by the archer.
    (Game, Unit, Unit) rescue() {
      final (g, h) = heroCaster(HeroSkill.rescueLeap);
      final archer = placeNow(g, 'archer', 0, 6)..cd = hold;
      final o = foeAt(g, 'orc', archer.pos + const Point(12, 6));
      expect(o.pos.distanceTo(h.pos), allOf(greaterThan(h.stats.range), lessThanOrEqualTo(rescueLeapK.reach)));
      return (g, h, o);
    }

    test('Guardian Leap: to a foe by a back-line troop, it leaps beside it in hopTime, then a 2x blow and a 1 s stun', () {
      final (g, h, o) = rescue();
      expect(casts(g, h), isTrue);
      expect(h.move, isA<Carry>());
      runFor(g, hopTime);
      expect(h.move, isNull);
      expect(h.pos.distanceTo(o.pos), closeTo(besideGap, 1));
      expect(o.hp, closeTo(o.maxHp - blow(h, o, rescueLeapK.hit), 1e-9));
      expect(o.stunUntil, greaterThan(g.t + rescueLeapK.stun - 0.1));
    });

    test('Guardian Leap: not at 40% HP or less, not for a foe by no back-line troop, not for one in its reach', () {
      final (g, h, _) = rescue();
      h.hp = h.maxHp * rescueLeapK.above;
      expect(casts(g, h), isFalse, reason: 'too hurt');
      final (f, fh, fo) = rescue();
      fo.pos = fo.pos + const Point(0, -30); // away from the archer
      expect(casts(f, fh), isFalse, reason: 'nobody behind to guard');
      final (n, nh, _) = rescue();
      foeAt(n, 'slime', nh.pos + Point(nh.stats.range - 2, 0)); // a nearer one, in its reach: still wanted
      final (c, ch, co) = rescue();
      co.pos = ch.pos + Point(ch.stats.range - 1, 0);
      c.troops.firstWhere((u) => u.type == 'archer').pos = co.pos + const Point(0, 10);
      expect(casts(c, ch), isFalse, reason: 'the foe is in its reach already');
      expect(casts(n, nh), isTrue, reason: 'the orc by the archer is still out of its reach');
    });

    test('Death Leap: onto a healing necromancer or skeleton archer out of its reach, a 2.5x blow; not a plain one, not at 40% HP', () {
      for (final type in [necroHealer, 'skeleton_archer']) {
        final (g, h) = heroCaster(HeroSkill.deathLeap);
        final o = foeAt(g, type, h.pos + const Point(64, 0));
        expect(casts(g, h), isTrue, reason: type);
        runFor(g, hopTime);
        expect(h.pos.distanceTo(o.pos), closeTo(besideGap, 1), reason: type);
        expect(o.hp, closeTo(o.maxHp - blow(h, o, deathLeapK.hit), 1e-9), reason: type);
        expect(o.stunUntil, double.negativeInfinity, reason: type); // no stun
      }
      final (g, h) = heroCaster(HeroSkill.deathLeap);
      foeAt(g, 'orc', h.pos + const Point(64, 0));
      expect(casts(g, h), isFalse, reason: 'a plain orc');
      final (w, wh) = heroCaster(HeroSkill.deathLeap);
      foeAt(w, necroHealer, wh.pos + const Point(64, 0));
      wh.hp = wh.maxHp * deathLeapK.above;
      expect(casts(w, wh), isFalse, reason: 'too hurt');
      final (r, rh) = heroCaster(HeroSkill.deathLeap);
      foeAt(r, necroHealer, rh.pos + Point(rh.stats.range, 0));
      expect(casts(r, rh), isFalse, reason: 'in its reach already');
    });

    test('Cavalry Charge: at 3x speed through the nearer foes on its path (a 1x blow each, shoved aside) to the farthest, a 2x blow and a 1 s stun', () {
      final (g, h) = heroCaster(HeroSkill.charge);
      final passed = foeAt(g, 'slime', h.pos + const Point(56, 4)), target = foeAt(g, 'orc', h.pos + const Point(80, 0));
      final x = h.pos.x;
      expect(casts(g, h), isTrue);
      g.tick(0.05);
      expect(h.pos.x, closeTo(x + chargeK.speed * h.stats.speed * 0.05, 1e-6));
      runFor(g, 1.5);
      expect(h.move, isNull);
      expect(h.pos.distanceTo(target.pos), lessThanOrEqualTo(h.stats.range));
      expect(passed.hp, closeTo(passed.maxHp - blow(h, passed, chargeK.pass), 1e-9));
      expect(passed.pos.y, greaterThanOrEqualTo(h.pos.y + 4 + chargeK.shove - 1e-6));
      expect(target.hp, closeTo(target.maxHp - blow(h, target, chargeK.hit), 1e-9));
      expect(target.stunUntil, greaterThan(g.t)); // still stunned (1 s from the arrival)
    });

    test('Cavalry Charge: not with a foe nearer than 3 tiles, none within 6 ahead, or a troop in the way', () {
      final (g, h) = heroCaster(HeroSkill.charge);
      foeAt(g, 'orc', h.pos + const Point(80, 0));
      foeAt(g, 'slime', h.pos + const Point(40, 20)); // 2.8 tiles
      expect(casts(g, h), isFalse, reason: 'already near a fight');
      final (f, fh) = heroCaster(HeroSkill.charge);
      foeAt(f, 'orc', fh.pos + const Point(100, 0));
      foeAt(f, 'orc', fh.pos + const Point(-60, 0)); // behind
      expect(casts(f, fh), isFalse, reason: 'too far ahead, and the other behind');
      final (b, bh) = heroCaster(HeroSkill.charge);
      foeAt(b, 'orc', bh.pos + const Point(80, 0));
      placeNow(b, 'soldier', 4, 3).cd = hold; // on the way
      expect(casts(b, bh), isFalse, reason: 'a troop in the way');
    });

    test('Chain Hook: a skeleton archer or healing necromancer 2-5 tiles off is dragged beside it, then a 1x blow and a 1 s stun', () {
      for (final type in ['skeleton_archer', necroHealer]) {
        final (g, h) = heroCaster(HeroSkill.hook);
        final o = foeAt(g, type, h.pos + const Point(64, 10));
        expect(casts(g, h), isTrue, reason: type);
        expect((o.move as Carry).by, h);
        runFor(g, dragTime);
        expect(o.move, isNull, reason: type);
        expect(o.pos.distanceTo(h.pos), closeTo(besideGap, 0.5), reason: type);
        expect(o.hp, closeTo(o.maxHp - blow(h, o, hookK.hit), 1e-9), reason: type);
        expect(o.stunUntil, greaterThan(g.t + hookK.stun - 0.1), reason: type);
      }
    });

    test('Chain Hook: never a plain monster, a mini boss or the boss, nor one nearer than 2 or farther than 5 tiles', () {
      for (final (type, tier, at, why) in [
        ('orc', Tier.normal, 64.0, 'a plain orc'),
        ('skeleton_archer', Tier.miniBoss, 64.0, 'a mini boss'),
        ('skeleton_archer', Tier.normal, 24.0, 'too near'),
        ('skeleton_archer', Tier.normal, 90.0, 'too far'),
      ]) {
        final (g, h) = heroCaster(HeroSkill.hook);
        foeAt(g, type, h.pos + Point(at, 0), tier);
        expect(casts(g, h), isFalse, reason: why);
      }
    });

    test('Spear Wall: with a foe within 3 tiles ahead and none in reach (decisions-log 298) it braces 5 s; each one coming in takes 1.5x and a 1 s stun, once', () {
      final (g, h) = heroCaster(HeroSkill.spearWall);
      foeAt(g, 'slime', h.pos + const Point(-30, 0)); // behind it
      expect(casts(g, h), isFalse, reason: 'none ahead');
      final comer = foeAt(g, 'slime', h.pos + const Point(30, 0))..busyUntil = double.negativeInfinity; // walks in
      foeAt(g, 'slime', h.pos + const Point(36, -12));
      final at = h.pos;
      expect(casts(g, h), isTrue);
      expect(g.braced(h), isTrue);
      runFor(g, 2);
      expect(comer.hp, closeTo(comer.maxHp - blow(h, comer, spearWallK.hit), 1e-9)); // once, though it stays
      expect(comer.stunUntil, greaterThan(double.negativeInfinity));
      expect(h.pos, at); // it neither walked to them nor was shoved
      runFor(g, spearWallK.time - 2 + 0.1);
      expect(g.braced(h), isFalse);

      final (n, nh) = heroCaster(HeroSkill.spearWall);
      for (var i = 0; i < 3; i++) {
        foeAt(n, 'slime', nh.pos + Point(30.0 + i * 6, i * 10.0 - 10));
      }
      foeAt(n, 'slime', nh.pos + Point(nh.stats.range - 2, 0));
      expect(casts(n, nh), isFalse, reason: 'one in its reach already');
    });

    test('the six that move or hold monsters never cast while a stalled wave marches; Death Leap does', () {
      final scenes = <HeroSkill, void Function(Game, Unit)>{
        HeroSkill.shieldBash: (g, h) => foeAt(g, 'orc', h.pos + Point(h.stats.range, 0), Tier.elite),
        HeroSkill.sweep: (g, h) => [foeAt(g, 'slime', h.pos + const Point(18, 0)), foeAt(g, 'orc', h.pos + const Point(15, 10))],
        HeroSkill.rescueLeap: (g, h) => foeAt(g, 'orc', (placeNow(g, 'archer', 0, 6)..cd = hold).pos + const Point(12, 6)),
        HeroSkill.charge: (g, h) => foeAt(g, 'orc', h.pos + const Point(80, 0)),
        HeroSkill.hook: (g, h) => foeAt(g, 'skeleton_archer', h.pos + const Point(64, 10)),
        HeroSkill.spearWall: (g, h) => [for (var i = 0; i < 3; i++) foeAt(g, 'slime', h.pos + Point(30.0 + i * 6, i * 10.0 - 10))],
        HeroSkill.deathLeap: (g, h) => foeAt(g, necroHealer, h.pos + const Point(64, 0)),
      };
      for (final MapEntry(key: skill, value: scene) in scenes.entries) {
        for (final marching in [false, true]) {
          final (g, h) = heroCaster(skill);
          scene(g, h);
          g.marching = marching;
          expect(casts(g, h), !marching || !skill.holds, reason: '${skill.name}${marching ? ' marching' : ''}');
        }
      }
    });

    test('the boss is never moved or stunned by them: a charge and a leap only hit it', () {
      final (g, h) = heroCaster(HeroSkill.charge);
      final big = foeAt(g, boss, h.pos + const Point(80, 0), Tier.boss), x = big.pos.x;
      expect(casts(g, h), isTrue);
      runFor(g, 1.5);
      expect(big.hp, closeTo(big.maxHp - blow(h, big, chargeK.hit), 1e-9));
      expect((big.pos.x, big.stunUntil), (x, double.negativeInfinity));

      final (r, rh) = heroCaster(HeroSkill.rescueLeap);
      final archer = placeNow(r, 'archer', 0, 6)..cd = hold;
      final necro = foeAt(r, boss, archer.pos + const Point(12, 6), Tier.boss);
      expect(casts(r, rh), isTrue);
      runFor(r, hopTime);
      expect(necro.hp, closeTo(necro.maxHp - blow(rh, necro, rescueLeapK.hit), 1e-9));
      expect(necro.stunUntil, double.negativeInfinity);
    });

    test('since any type can hold any rank (#58) shoves go by rank and stuns by rank and type: a boss orc takes neither, a mini boss necromancer half the shove and no stun', () {
      // Shield Bash with the soldier below half its HP, so it takes any foe in reach: the blow, then the knockback
      // (a tile, times the rank's share) and the stun as the rank and type allow.
      for (final (type, tier, share) in [('orc', Tier.boss, 0.0), (boss, Tier.miniBoss, 0.5)]) {
        final (g, h) = heroCaster(HeroSkill.shieldBash);
        final o = foeAt(g, type, h.pos + Point(h.stats.range, 0), tier), x = o.pos.x;
        h.hp = h.maxHp * shieldBashK.below - 1;
        expect(casts(g, h), isTrue, reason: '$type ${tier.name}');
        expect(o.hp, closeTo(o.maxHp - blow(h, o, shieldBashK.hit), 1e-9), reason: '$type ${tier.name}');
        runFor(g, slideTime + 0.05);
        expect(o.pos.x, closeTo(x + shieldBashK.shove * share, 1e-6), reason: '$type ${tier.name}');
        expect(o.stunUntil, double.negativeInfinity, reason: '$type ${tier.name}');
      }
      // Nothing drags a boss of any type.
      final g = empty();
      expect(g.drag(foe(g, 'skeleton_archer', const Point(200, 60), tier: Tier.boss), const Point(100, 60)), isFalse);
    });
  });
}
