// Monster skills (#59 branch 2a; lib/monster_skill_moves.dart): Sticky Glob, Swoop, Pounce and Trample, each
// with the stronger cast of a mini boss, what their wind-up's cancel does to them, and a charger stopped by a
// stun (a monster's Trample and a troop Hero's Cavalry Charge alike).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// A wave on (nothing left to spawn), the troops' skills off, and a monster of [type] and [tier] at [at] that
/// walks on its own but never strikes ([Unit.cd]): what it does is its skill's doing.
(Game, Unit) casterAt(String type, Tier tier, {Point<double> at = const Point(250.0, 60.0)}) {
  final g = bareGame()
    ..skills = false
    ..heroSkills = false;
  g
    ..startWave()
    ..queue.clear();
  final u = g.monster(type, tier, at)
    ..entered = true
    ..cd = hold;
  g.units.add(u);
  return (g, u);
}

/// A troop of [type] standing at [at] that never moves or fights ([hold]).
Unit troopAt(Game g, String type, Point<double> at) {
  final u = Unit(Side.troop, type, troopTypes[type]!, at)
    ..entered = true
    ..busyUntil = hold;
  g.units.add(u);
  return u;
}

/// Ticks until monster [u] has begun its skill (fails if it never does).
void windUp(Game g, Unit u) {
  for (var i = 0; i < 40 && u.winding == null; i++) {
    g.tick(0.05);
  }
  expect(u.winding, isNotNull, reason: '${u.type} began its skill');
}

/// Ticks until monster [u] has begun its skill and then cast it (the tick it lands).
void landCast(Game g, Unit u) {
  windUp(g, u);
  for (var i = 0; i < 40 && u.winding != null; i++) {
    g.tick(0.05);
  }
  expect(u.winding, isNull, reason: '${u.type} cast its skill');
}

void main() {
  test("the four signatures of branch 2a: a slime's, a bat's, a werewolf's and an orc rider's, from high elite up", () {
    expect(
        [for (final s in [MonsterSkill.stickyGlob, MonsterSkill.swoop, MonsterSkill.pounce, MonsterSkill.trample]) '${s.type} ${s.title} ${s.wind}/${s.cooldown}'],
        ['slime Sticky Glob 0.4/10.0', 'bat Swoop 0.4/12.0', 'werewolf Pounce 0.4/12.0', 'orc_rider Trample 0.5/15.0']);
    final g = bareGame();
    for (final (type, skill) in [('slime', MonsterSkill.stickyGlob), ('bat', MonsterSkill.swoop), ('werewolf', MonsterSkill.pounce), ('orc_rider', MonsterSkill.trample)]) {
      expect(monsterSkillOf(g.monster(type, Tier.elite, const Point(250.0, 60.0))), isNull, reason: type);
      expect(monsterSkillOf(g.monster(type, Tier.highElite, const Point(250.0, 60.0))), skill, reason: type);
      expect(monsterSkillOf(g.monster(type, Tier.miniBoss, const Point(250.0, 60.0))), skill, reason: type);
    }
  });

  group('Sticky Glob', () {
    test('at the nearest back-line troop within 4 tiles, past a nearer melee one: a 0.8x glob, then it walks 30% slower and attacks 30% slower for 3 s', () {
      final (g, slime) = casterAt('slime', Tier.highElite);
      final front = troopAt(g, 'soldier', const Point(236, 60)), priest = troopAt(g, 'priest', const Point(200, 64));
      landCast(g, slime);
      final glob = g.shots.single;
      expect((glob.target, glob.look, glob.speed), (priest, ShotLook.glob, stickyGlobK.speed));
      expect(glob.dmg, closeTo(slime.stats.dmg * stickyGlobK.hit, 1e-9));
      final landed = g.t + slime.pos.distanceTo(priest.pos) / stickyGlobK.speed;
      for (var i = 0; i < 40 && g.shots.isNotEmpty; i++) {
        g.tick(0.05);
      }
      expect(priest.hp, closeTo(priest.maxHp - hitTaken(slime.stats.dmg * stickyGlobK.hit, priest.stats.def), 1e-9));
      expect(front.hp, front.maxHp);
      expect((g.effectK(priest, Status.slow), g.effectK(priest, Status.haste)), (stickyGlobK.slow, 1 / stickyGlobK.slow));
      expect(g.attackEvery(priest), closeTo(priest.stats.rate / stickyGlobK.slow, 1e-9));
      expect(priest.effects[Status.slow]!.until, closeTo(landed + stickyGlobK.time, 0.06));
    });

    test('a mini boss slows 40% for 4 s; with no back-line troop within 4 tiles it never spits', () {
      final (g, slime) = casterAt('slime', Tier.miniBoss);
      final archer = troopAt(g, 'archer', const Point(200, 60));
      landCast(g, slime);
      runFor(g, 1);
      expect(g.effectK(archer, Status.slow), stickyGlobK.strongSlow);
      expect(archer.effects[Status.slow]!.until - g.t, greaterThan(stickyGlobK.strongTime - 1.2));

      final (f, far) = casterAt('slime', Tier.highElite);
      troopAt(f, 'soldier', const Point(240, 60)); // the front only
      troopAt(f, 'archer', Point(250 - stickyGlobK.reach - 30, 60)); // out of reach, and the slime can't walk up (the soldier holds it)
      runFor(f, 2);
      expect(far.winding, isNull);
      expect(f.shots, isEmpty);
    });
  });

  group('Swoop', () {
    test('it leaps over the front to a back-line troop out of its reach, bites 1.5x and heals half of what the bite took', () {
      final (g, bat) = casterAt('bat', Tier.highElite);
      final front = troopAt(g, 'soldier', const Point(232, 60)), priest = troopAt(g, 'priest', const Point(190, 60));
      bat.hp = 5;
      landCast(g, bat);
      expect(bat.move, isA<Carry>()); // in the air
      runFor(g, hopTime + 0.05);
      final bite = hitTaken(bat.stats.dmg * swoopK.hit, priest.stats.def);
      expect(priest.hp, closeTo(priest.maxHp - bite, 1e-9));
      expect(bat.hp, closeTo(5 + bite * swoopK.heal, 1e-9));
      expect(bat.pos.distanceTo(priest.pos), closeTo(besideGap, 0.5));
      expect(front.hp, front.maxHp); // flown over
    });

    test("a mini boss bites 2x; the bite never takes more than the cap; a back-line troop already in its reach isn't swooped", () {
      final (g, bat) = casterAt('bat', Tier.miniBoss);
      final archer = troopAt(g, 'archer', const Point(190, 60));
      landCast(g, bat);
      runFor(g, hopTime + 0.05);
      final bite = min(hitTaken(bat.stats.dmg * swoopK.strongHit, archer.stats.def), archer.maxHp * monsterSkillCapOf(archer));
      expect(archer.hp, closeTo(archer.maxHp - bite, 1e-9));

      final (c, capped) = casterAt('bat', Tier.highElite);
      capped.stats = const Stats(hp: 20, cost: 3, speed: 34, dmg: 400, range: 12, rate: 0.6); // a bite far past the cap
      final priest = troopAt(c, 'priest', const Point(190, 60))..hero = true;
      landCast(c, capped);
      runFor(c, hopTime + 0.05);
      expect(priest.maxHp - priest.hp, closeTo(priest.maxHp * monsterSkillCap.hero, 1e-9));

      final (n, near) = casterAt('bat', Tier.highElite);
      troopAt(n, 'priest', const Point(240, 60)); // within its reach
      runFor(n, 1);
      expect(near.winding, isNull);
    });
  });

  group('Pounce', () {
    test('onto the troop with the least HP left below half (a Hero below a quarter): a 1.5x bite, then it bleeds 0.3x a second 4 times', () {
      final (g, wolf) = casterAt('werewolf', Tier.highElite);
      troopAt(g, 'soldier', const Point(220, 60)).hp = 60; // 67%: not hurt enough
      final weak = troopAt(g, 'knight_templar', const Point(215, 76))..hp = 112; // 40%, with room for a high elite's bite and bleed
      troopAt(g, 'knight', const Point(214, 44))
        ..hero = true
        ..hp = 42; // 30%: a Hero only below 25%
      landCast(g, wolf);
      expect(wolf.move, isA<Carry>());
      runFor(g, hopTime + 0.05);
      final bite = hitTaken(wolf.stats.dmg * pounceK.hit, weak.stats.def);
      expect(weak.hp, closeTo(112 - bite, 1e-9));
      expect(wolf.pos.distanceTo(weak.pos), closeTo(besideGap, 0.5));
      runFor(g, pounceK.time + 0.6);
      expect(weak.hp, closeTo(112 - bite - pounceK.time * hitTaken(wolf.stats.dmg * pounceK.bleed, weak.stats.def), 1e-9));
    });

    test('a mini boss bites 2x; a Hero below a quarter is prey too; nobody below half: no pounce', () {
      final (g, wolf) = casterAt('werewolf', Tier.miniBoss);
      final hero = troopAt(g, 'knight_templar', const Point(214, 60))
        ..hero = true
        ..hp = 60; // 21%
      landCast(g, wolf);
      runFor(g, hopTime + 0.05);
      expect(hero.hp, closeTo(60 - min(hitTaken(wolf.stats.dmg * pounceK.strongHit, hero.stats.def), hero.maxHp * monsterSkillCap.hero), 1e-9));

      final (f, calm) = casterAt('werewolf', Tier.highElite);
      troopAt(f, 'soldier', const Point(220, 60)).hp = 50; // 56%
      runFor(f, 1);
      expect(calm.winding, isNull);
    });

    test("one cast, one cap: the bleed gets what the bite left of it, and none when that's under a blow's least a tick", () {
      final (g, wolf) = casterAt('werewolf', Tier.highElite);
      final knight = troopAt(g, 'knight', const Point(215, 60))..hp = 56; // 40%
      final cap = knight.maxHp * monsterSkillCapOf(knight), bite = hitTaken(wolf.stats.dmg * pounceK.hit, knight.stats.def);
      expect(bite, lessThan(cap)); // the bite alone is under the cap...
      expect(bite + pounceK.time * hitTaken(wolf.stats.dmg * pounceK.bleed, knight.stats.def), greaterThan(cap)); // ...with a full bleed over it
      landCast(g, wolf);
      runFor(g, hopTime + 0.05);
      expect(knight.hp, closeTo(56 - bite, 1e-9));
      expect(g.effectK(knight, Status.bleed), closeTo((cap - bite) / pounceK.time, 1e-9));
      runFor(g, pounceK.time + 0.6);
      expect(56 - knight.hp, closeTo(cap, 1e-9)); // bite and bleed: the cap, no more

      final (f, wolf2) = casterAt('werewolf', Tier.highElite);
      final soldier = troopAt(f, 'soldier', const Point(215, 60))..hp = 36; // 40%
      final bite2 = hitTaken(wolf2.stats.dmg * pounceK.hit, soldier.stats.def);
      expect(soldier.maxHp * monsterSkillCapOf(soldier) - bite2, inInclusiveRange(0, pounceK.time * minHit)); // too little left
      landCast(f, wolf2);
      runFor(f, hopTime + 0.05);
      expect(soldier.effects[Status.bleed], isNull);
      runFor(f, pounceK.time + 0.6);
      expect(soldier.hp, closeTo(36 - bite2, 1e-9));
    });
  });

  group('Trample', () {
    test('with a troop 2-5 tiles ahead it gallops at 2x through the front (1x each, shoved half a tile aside) to the first back-line troop, and stops there', () {
      final (g, rider) = casterAt('orc_rider', Tier.highElite);
      final front = troopAt(g, 'soldier', const Point(215, 63)), archer = troopAt(g, 'archer', const Point(180, 60));
      landCast(g, rider);
      expect(rider.move, isA<Charge>());
      expect((rider.move! as Charge).target, archer);
      runFor(g, 1.5);
      expect(rider.move, isNull);
      expect(rider.pos.distanceTo(archer.pos), lessThanOrEqualTo(rider.stats.range + 1e-9));
      expect(front.hp, closeTo(front.maxHp - hitTaken(rider.stats.dmg * trampleK.hit, front.stats.def), 1e-9));
      expect(front.pos.y, closeTo(63 + trampleK.shove, 1e-6)); // aside, away from its way
      expect(archer.hp, archer.maxHp); // the target isn't trampled: the rider fights it from here
      expect(front.stunUntil, double.negativeInfinity);
    });

    test('a mini boss tramples 1.5x and stuns each troop it passes 0.5 s; nobody 2-5 tiles ahead (only in its reach): no trample', () {
      final (g, rider) = casterAt('orc_rider', Tier.miniBoss);
      rider.bossSkillAt = double.infinity; // its mini-boss skill (Spear Throw at the priest, boss_skills.dart) kept out of this
      final front = troopAt(g, 'soldier', const Point(215, 63));
      troopAt(g, 'priest', const Point(180, 60));
      landCast(g, rider);
      runFor(g, 0.6); // it passes the soldier
      expect(front.hp, closeTo(front.maxHp - min(hitTaken(rider.stats.dmg * trampleK.strongHit, front.stats.def), front.maxHp * monsterSkillCap.troop), 1e-9));
      expect(front.stunImmuneUntil, greaterThan(g.t)); // stunned (stunTroop), and immune for a while after

      final (f, close) = casterAt('orc_rider', Tier.highElite);
      troopAt(f, 'soldier', const Point(238, 60)); // in its reach; it walks no further
      runFor(f, 1);
      expect(close.winding, isNull);
    });
  });

  group('the counterplay', () {
    test("a stun during Swoop's wind-up cancels it (no leap) and it waits its cooldown; a knockback cancels Trample's", () {
      final (g, bat) = casterAt('bat', Tier.highElite);
      final priest = troopAt(g, 'priest', const Point(190, 60));
      windUp(g, bat);
      bat.stunUntil = g.t + 1; // Crushing Blow's stun
      runFor(g, 3);
      expect((bat.winding, priest.hp), (null, priest.maxHp.toDouble()));
      expect(g.t - bat.skillAt, lessThan(MonsterSkill.swoop.cooldown));

      final (f, rider) = casterAt('orc_rider', Tier.highElite);
      troopAt(f, 'soldier', const Point(215, 60));
      troopAt(f, 'archer', const Point(180, 60));
      windUp(f, rider);
      expect(f.knockBack(rider, tile), isTrue); // a Hero's Shield Bash
      runFor(f, 1);
      expect(rider.winding, isNull);
      expect(rider.move, isNull); // the slide is over, and no charge followed
    });

    test('a charger stunned mid-charge stops where it is: a monster\'s Trample, and a troop Hero\'s Cavalry Charge under stunTroop', () {
      final (g, rider) = casterAt('orc_rider', Tier.highElite);
      troopAt(g, 'soldier', const Point(215, 60));
      troopAt(g, 'archer', const Point(180, 60));
      landCast(g, rider);
      g.tick(0.05);
      rider.stunUntil = g.t + 1;
      g.tick(0.05);
      final at = rider.pos;
      expect(rider.move, isNull);
      runFor(g, 0.5);
      expect(rider.pos, at);

      final f = bareGame()..skills = false;
      final lancer = placeNow(f, 'lancer', 2, 3)..cd = hold;
      final orc = foeAt(f, 'orc', lancer.pos + const Point(90.0, 0.0));
      f.charge(lancer, orc, speed: chargeK.speed, lane: chargeK.lane, hit: 0, shove: 0);
      f.tick(0.05);
      expect(f.stunTroop(lancer, 0.8), isTrue);
      final from = lancer.pos;
      f.tick(0.05);
      expect(lancer.move, isNull);
      expect(lancer.pos, from);
    });
  });
}
