// Monster skills (#59 phase 2, branch 1; lib/monster_skills.dart): who casts, the first cast's stagger, the
// wind-up and what cancels it, the cap on a skill's blow, the log line, and the seven skills of this branch.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show logLine;

import 'hero_skill_helpers.dart';

/// A wave on (of [wave], nothing left to spawn), the troops' skills off, and a monster of [type] and [tier] at
/// [at] that walks and fights on its own but never strikes ([Unit.cd]): what it does is its skill's doing.
(Game, Unit) casterAt(String type, Tier tier, {Point<double> at = const Point(250.0, 60.0), int wave = 1}) {
  final g = bareGame()
    ..skills = false
    ..heroSkills = false
    ..wave = wave - 1;
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

/// Ticks until monster [u] has begun its skill and then cast it (the tick it lands); fails if it never began.
void landCast(Game g, Unit u) {
  for (var i = 0; i < 40 && u.winding == null; i++) {
    g.tick(0.05);
  }
  expect(u.winding, isNotNull, reason: '${u.type} began its skill');
  for (var i = 0; i < 40 && u.winding != null; i++) {
    g.tick(0.05);
  }
  expect(u.winding, isNull, reason: '${u.type} cast its skill');
}

void main() {
  test('high elites and up cast their type\'s skill (English titles); normal and elite monsters, raised minions and '
      'types without one built don\'t', () {
    expect([for (final s in MonsterSkill.values.where((s) => s.rank == MonsterRank.signature)) (s.type, s.title)], [
      ('orc', 'War Shout'),
      ('skeleton_archer', 'Volley'),
      ('armored_skeleton', 'Shield Up'),
      ('elite_orc', 'Brutal Swing'),
      ('armored_orc', 'Bulwark'),
      ('greatsword_skeleton', 'Blade Dance'),
      (necroHealer, 'Mass Mend'),
      ('slime', 'Sticky Glob'), // branch 2a (monster_skill_moves_test.dart)
      ('bat', 'Swoop'),
      ('werewolf', 'Pounce'),
      ('orc_rider', 'Trample'),
      ('skeleton', 'Reassemble'), // branch 2b (monster_skill_signatures_test.dart)
      ('werebear', 'Maul'),
      (boss, 'Curse of Frailty'),
    ]);
    expect(monsterSkillCap, (troop: 0.35, hero: 0.25));
    final g = bareGame();
    Unit at(String type, Tier tier) => g.monster(type, tier, const Point(250.0, 60.0));
    for (final tier in Tier.values) {
      expect(monsterSkillOf(at('orc', tier)), tier.index >= Tier.highElite.index ? MonsterSkill.warShout : null, reason: '$tier');
    }
    expect(monsterSkillOf(at('skeleton', Tier.miniBoss)), MonsterSkill.reassemble); // every type has one since 2b
    expect(monsterSkillOf(at(boss, Tier.boss)), MonsterSkill.curseOfFrailty);
    expect(monsterSkillOf(at('orc', Tier.highElite)..raisedBy = at(boss, Tier.boss)), isNull);
    expect(monsterSkillOf(Unit(Side.troop, 'soldier', troopTypes['soldier']!, const Point(100.0, 60.0))), isNull);
  });

  test('a monster\'s first cast comes 2 to 5 s after it comes on, a second later for each place in the wave', () {
    final g = bareGame()..skills = false;
    g
      ..startWave()
      ..queue.clear()
      ..queue.addAll([for (var i = 0; i < 5; i++) ('orc', Tier.highElite)]);
    final cameAt = <Unit, double>{};
    for (var i = 0; i < 200 && cameAt.length < 5; i++) {
      g.tick(0.05);
      for (final u in g.enemies) {
        cameAt.putIfAbsent(u, () => g.t);
      }
    }
    expect([for (final MapEntry(key: u, value: t0) in cameAt.entries) u.skillAt + MonsterSkill.warShout.cooldown - t0],
        [for (final s in [2, 3, 4, 5, 2]) closeTo(s.toDouble(), 1e-9)]);
  });

  test('War Shout: it winds up first (its title pops, the log names it), then the monsters near it that fought deal '
      'more for a while; a mini boss\'s more', () {
    final (g, orc) = casterAt('orc', Tier.highElite);
    final mates = [for (final dy in [-10.0, 10.0]) foeAt(g, 'orc', orc.pos + Point(4.0, dy))..attackedAt = g.t];
    final far = foeAt(g, 'orc', orc.pos + const Point(40.0, 0))..attackedAt = g.t; // beyond 2 tiles
    g.tick(0.05);
    expect(orc.winding, isNull); // two near it fought (not itself): not enough
    mates.add(foeAt(g, 'orc', orc.pos + const Point(-4.0, 0))..attackedAt = g.t);
    g.tick(0.05);
    expect((orc.winding, orc.skillAt, orc.moving), (MonsterSkill.warShout, g.t, false));
    expect(g.monsterCasts, [(orc, MonsterSkill.warShout)]);
    expect(g.log.entries.whereType<MonsterSkillCast>().map((e) => (e.type, e.tier, e.skill)), [('orc', Tier.highElite, MonsterSkill.warShout)]);
    expect(g.under(mates.first, Status.might), isFalse); // not yet: it winds up first
    landCast(g, orc);
    for (final o in [orc, ...mates]) {
      expect(g.effectK(o, Status.might), warShoutK.might);
      expect(g.effectOn(o, Status.might)!.until, closeTo(g.t + warShoutK.time, 1e-9));
    }
    expect(g.under(far, Status.might), isFalse);

    final (h, mini) = casterAt('orc', Tier.miniBoss);
    for (final dy in [-10.0, 0.0, 10.0]) {
      foeAt(h, 'orc', mini.pos + Point(4.0, dy)).attackedAt = h.t;
    }
    landCast(h, mini);
    expect(h.effectK(mini, Status.might), warShoutK.strong);
  });

  test('a stun, a march or Slime Hex during the wind-up cancels the skill, and it waits its cooldown all the same; '
      'with the skills off none casts', () {
    (Game, Unit, List<Unit>) shouting() {
      final (g, orc) = casterAt('orc', Tier.highElite);
      final mates = [for (final dy in [-10.0, 0.0, 10.0]) foeAt(g, 'orc', orc.pos + Point(4.0, dy))..attackedAt = g.t];
      return (g, orc, mates);
    }

    final (g, orc, mates) = shouting();
    g.tick(0.05);
    expect(orc.winding, MonsterSkill.warShout);
    final began = orc.skillAt;
    orc.stunUntil = g.t + 1;
    runFor(g, 1.5);
    expect(orc.winding, isNull);
    expect(mates.any((o) => g.under(o, Status.might)), isFalse);
    for (final o in mates) {
      o.attackedAt = g.t; // still fighting: it would want it again
    }
    runFor(g, 2);
    expect((orc.skillAt, orc.winding), (began, null)); // on its cooldown
    expect(mates.any((o) => g.under(o, Status.might)), isFalse);

    final (h, orc2, mates2) = shouting();
    h.tick(0.05);
    expect(orc2.winding, MonsterSkill.warShout);
    h.marching = true;
    h.tick(0.05);
    expect(orc2.winding, isNull);
    h.marching = false;
    runFor(h, 1);
    expect(mates2.any((o) => h.under(o, Status.might)), isFalse);

    final (m, orc4, mates4) = shouting();
    m.tick(0.05);
    expect(orc4.winding, MonsterSkill.warShout);
    orc4.effects[Status.hex] = Effect(m.t + 1, 0, was: orc4.stats); // Slime Hex: a slime for a second
    m.tick(0.05);
    expect(orc4.winding, isNull);
    orc4.skillAt = double.negativeInfinity; // off its cooldown, and they still fight: no cast while a slime
    for (final o in mates4) {
      o.attackedAt = m.t;
    }
    m.tick(0.05);
    expect(orc4.winding, isNull);
    expect(mates4.any((o) => m.under(o, Status.might)), isFalse);

    final (k, orc3, _) = shouting();
    k.monsterSkills = false;
    runFor(k, 1);
    expect(orc3.winding, isNull);
    expect(k.monsterCasts, isEmpty);
  });

  test('Volley: with 2 troops in range the skeleton archer looses 3 arrows at 0.8x, nearest first (a mini boss 5); '
      'with 1 it doesn\'t; a troop\'s arrows share 35% of its HP (decision 110)', () {
    final (g, a) = casterAt('skeleton_archer', Tier.highElite);
    final near = troopAt(g, 'knight', a.pos - const Point(20.0, 0));
    runFor(g, 0.5);
    expect((a.winding, a.skillAt), (null, double.negativeInfinity)); // one troop in range
    final far = troopAt(g, 'knight', a.pos - const Point(40.0, 0));
    landCast(g, a);
    final hit = a.stats.dmg * volleyK.hit;
    expect(g.shots.map((s) => (s.from, s.target)), [(a, near), (a, far), (a, near)]);
    expect(g.shots.map((s) => s.dmg), everyElement(closeTo(hit, 1e-9)));

    final (h, mini) = casterAt('skeleton_archer', Tier.miniBoss, wave: 60);
    mini.bossSkillAt = double.infinity; // its mini-boss skill (Barbed Arrow, boss_skills.dart) kept out of this
    final troops = [troopAt(h, 'archer', mini.pos - const Point(20.0, 0)), troopAt(h, 'archer', mini.pos - const Point(40.0, 0))];
    landCast(h, mini);
    expect(h.shots.map((s) => s.target), [troops[0], troops[1], troops[0], troops[1], troops[0]]);
    expect(mini.stats.dmg * volleyK.hit, greaterThan(troops[0].maxHp * monsterSkillCap.troop)); // it would hit harder
    final cap = troops[0].maxHp * monsterSkillCap.troop; // 3 arrows on the nearest, 2 on the other
    expect(h.shots.map((s) => s.dmg), [for (final on in [3, 2, 3, 2, 3]) closeTo(cap / on, 1e-9)]);
  });

  test('Shield Up: hit by a long-range troop, the armored skeleton takes half from long-range troops for 4 s, a melee '
      'troop\'s shot in full; a mini boss covers those just behind it', () {
    final (g, sk) = casterAt('armored_skeleton', Tier.highElite);
    final archer = troopAt(g, 'archer', sk.pos - const Point(50.0, 0)), knight = troopAt(g, 'knight', sk.pos - const Point(10.0, 0));
    runFor(g, 0.5);
    expect(sk.winding, isNull); // nobody shot it
    double took(Unit from, double dmg) {
      final hp = sk.hp;
      g.shots.add(Shot.special(from, sk, sk.pos - const Point(1.0, 0), dmg: dmg, speed: 200)); // lands this tick
      g.tick(0.05);
      return hp - sk.hp;
    }

    expect(took(archer, 10), closeTo(hitTaken(10, sk.stats.def), 1e-9)); // in full, and now it wants it
    landCast(g, sk);
    expect(g.effectK(sk, Status.shotWard), shieldUpK.ward);
    expect(took(archer, 20), closeTo(hitTaken(20, sk.stats.def) * shieldUpK.ward, 1e-9));
    expect(took(knight, 20), closeTo(hitTaken(20, sk.stats.def), 1e-9));

    final (h, mini) = casterAt('armored_skeleton', Tier.miniBoss);
    mini.bossSkillAt = double.infinity; // its mini-boss skill (Bone Bash, boss_skills.dart) kept out of this
    troopAt(h, 'knight', mini.pos - const Point(10.0, 0)); // in its reach: it stands
    // Just behind it (further from the base) and just before it, each within a tile, none close enough to shove.
    final behind = foeAt(h, 'skeleton', mini.pos + const Point(14.0, 0)), before = foeAt(h, 'skeleton', mini.pos + const Point(-6.0, 13));
    mini.rangedHitAt = h.t;
    landCast(h, mini);
    expect([for (final o in [mini, behind, before]) h.under(o, Status.shotWard)], [true, true, false]);
  });

  test('Brutal Swing: with 2 troops in reach the elite orc hits each for 1.2x (a mini boss 1.5x), never more than 35% '
      'of a troop\'s max HP, a Hero\'s 25%', () {
    final (g, orc) = casterAt('elite_orc', Tier.highElite);
    final a = troopAt(g, 'knight', orc.pos - const Point(8.0, 5));
    runFor(g, 0.5);
    expect(orc.winding, isNull);
    final b = troopAt(g, 'knight', orc.pos - const Point(8.0, -5));
    landCast(g, orc);
    for (final o in [a, b]) {
      expect(o.maxHp - o.hp, closeTo(orc.stats.dmg * brutalSwingK.hit, 1e-9));
    }

    final (h, mini) = casterAt('elite_orc', Tier.miniBoss, wave: 60);
    final troop = troopAt(h, 'knight', mini.pos - const Point(8.0, 5)), hero = troopAt(h, 'knight', mini.pos - const Point(8.0, -5))..hero = true;
    expect(mini.stats.dmg * brutalSwingK.strong, greaterThan(troop.maxHp)); // unchecked it would kill outright
    landCast(h, mini);
    expect(troop.maxHp - troop.hp, closeTo(troop.maxHp * monsterSkillCap.troop, 1e-9));
    expect(hero.maxHp - hero.hp, closeTo(hero.maxHp * monsterSkillCap.hero, 1e-9));
  });

  test('Bulwark: the armored orc makes the melee troops within 2 tiles fight it and takes 30% less for 4 s; a mini '
      'boss also sends back melee blows', () {
    final (g, orc) = casterAt('armored_orc', Tier.highElite);
    final k1 = troopAt(g, 'knight', orc.pos - const Point(8.0, 5)), archer = troopAt(g, 'archer', orc.pos - const Point(28.0, 0));
    // A free knight with a slime just behind it: it faces the slime until taunted.
    final k2 = troopAt(g, 'soldier', orc.pos - const Point(8.0, -5))
      ..busyUntil = double.negativeInfinity
      ..cd = hold;
    foeAt(g, 'slime', k2.pos - const Point(5.0, 0));
    g.tick(0.05);
    expect(k2.dir, -1);
    orc.guardOmen = true; // a Bayangan's guard before (the v2 rules): Bulwark's takes the slot and clears the flag
    landCast(g, orc);
    for (final o in [k1, k2]) {
      expect(g.effectOn(o, Status.taunt)?.by, orc, reason: o.type);
    }
    expect(g.under(archer, Status.taunt), isFalse); // melee only
    expect(orc.guardUntil - g.t, closeTo(bulwarkK.time, 1e-9));
    expect((orc.guardCut, orc.guardOmen), (bulwarkK.cut, false));
    expect(g.under(orc, Status.reflect), isFalse);
    g.tick(0.05);
    expect(k2.dir, 1); // it turned to the orc

    final (h, mini) = casterAt('armored_orc', Tier.miniBoss);
    troopAt(h, 'knight', mini.pos - const Point(8.0, 0)); // one troop in reach, but a monster near it is hurt
    foeAt(h, 'orc', mini.pos + const Point(10.0, 0)).hp = 1;
    landCast(h, mini);
    expect(h.effectK(mini, Status.reflect), bulwarkK.reflect);
  });

  test('Blade Dance: with 2 troops within 1.5 tiles the greatsword skeleton spins 3 cuts 0.5 s apart at 0.7x each '
      '(a mini boss 4), all of them together at most 35% of a troop\'s HP; a stun stops the spin', () {
    final (g, sk) = casterAt('greatsword_skeleton', Tier.highElite);
    final troops = [troopAt(g, 'knight', sk.pos - const Point(10.0, 6)), troopAt(g, 'knight', sk.pos - const Point(10.0, -6))];
    landCast(g, sk);
    runFor(g, 1.1);
    for (final o in troops) {
      final cut = min(sk.stats.dmg * bladeDanceK.hit, o.maxHp * monsterSkillCap.troop / bladeDanceK.cuts); // decision 110
      expect(o.maxHp - o.hp, closeTo(cut * bladeDanceK.cuts, 1e-6));
    }

    final (h, mini) = casterAt('greatsword_skeleton', Tier.miniBoss);
    mini.bossSkillAt = double.infinity; // its mini-boss skill (Soul Rend, boss_skills.dart) kept out of this
    final tough = [
      for (final dy in [6.0, -6.0])
        troopAt(h, 'knight', mini.pos - Point(10.0, dy))
          ..maxHp = 1000
          ..hp = 1000,
    ];
    landCast(h, mini);
    runFor(h, 1.6);
    expect(tough.first.maxHp - tough.first.hp, closeTo(mini.stats.dmg * bladeDanceK.hit * bladeDanceK.strong, 1e-6));

    final (k, stunned) = casterAt('greatsword_skeleton', Tier.highElite);
    final t1 = troopAt(k, 'knight', stunned.pos - const Point(10.0, 6));
    troopAt(k, 'knight', stunned.pos - const Point(10.0, -6));
    landCast(k, stunned);
    stunned.stunUntil = k.t + 5;
    runFor(k, 1.1);
    expect(t1.maxHp - t1.hp, closeTo(min(stunned.stats.dmg * bladeDanceK.hit, t1.maxHp * monsterSkillCap.troop / bladeDanceK.cuts), 1e-6)); // the first cut only
  });

  test('Mass Mend: with 2 monsters below 70% within 2 tiles the healing necromancer heals every hurt one there by '
      'its heal for 16 MP; not short of MP; a mini boss 1.5x', () {
    final (g, h) = casterAt(necroHealer, Tier.highElite);
    final a = foeAt(g, 'orc', h.pos + const Point(10.0, 0))..hp = 10;
    runFor(g, 0.5);
    expect(h.winding, isNull); // one hurt
    final b = foeAt(g, 'orc', h.pos - const Point(10.0, 0))..hp = 10;
    final mp = h.mp;
    landCast(g, h);
    expect([a.hp, b.hp], everyElement(closeTo(10 + h.stats.dmg * massMendK.heal, 1e-9)));
    expect(h.mp, closeTo(mp - massMendK.cost * necroHealCost, 1e-9));

    final (k, poor) = casterAt(necroHealer, Tier.highElite);
    for (final dx in [10.0, -10.0]) {
      foeAt(k, 'orc', poor.pos + Point(dx, 0)).hp = 10;
    }
    poor.mp = massMendK.cost * necroHealCost - 1;
    k.tick(0.05);
    expect(poor.winding, isNull);

    final (m, mini) = casterAt(necroHealer, Tier.miniBoss);
    final c = foeAt(m, 'orc', mini.pos + const Point(10.0, 0))..hp = 10;
    foeAt(m, 'orc', mini.pos - const Point(10.0, 0)).hp = 10;
    landCast(m, mini);
    expect(c.hp, closeTo(10 + mini.stats.dmg * massMendK.strong, 1e-9));
  });

  test("Mass Mend's heals don't stack either (#78): a monster in another healer's window neither counts for it nor "
      'gets its heal, and each one it heals opens its own window', () {
    final (g, h) = casterAt(necroHealer, Tier.highElite);
    final other = Unit(Side.enemy, necroHealer, necroHealerStats, const Point(0.0, 0.0)); // another healer
    final a = foeAt(g, 'orc', h.pos + const Point(10.0, 0))
      ..hp = 10
      ..healedUntil = g.t + 5
      ..healedBy = other;
    final b = foeAt(g, 'orc', h.pos - const Point(10.0, 0))..hp = 10;
    runFor(g, 0.5);
    expect(h.winding, isNull); // two hurt, but one of them is in another healer's window
    final c = foeAt(g, 'orc', h.pos + const Point(0, 10.0))..hp = 10;
    landCast(g, h);
    expect(a.hp, 10);
    expect([b.hp, c.hp], everyElement(closeTo(10 + h.stats.dmg * massMendK.heal, 1e-9)));
    expect((b.healedBy, c.healedBy, a.healedBy), (h, h, other));
    expect(b.healedUntil - g.t, closeTo(g.attackEvery(h) * healWindow, 0.051));
  });

  test('the battle log names a monster\'s skill with its rank first; the event\'s JSON carries it', () {
    final e = MonsterSkillCast(3, 1.5, type: 'orc_rider', tier: Tier.miniBoss, skill: MonsterSkill.warShout);
    expect(logLine(e), '${tierNames[Tier.miniBoss]} ${monsterTypeNames['orc_rider']}: War Shout');
    expect(logLine(MonsterSkillCast(3, 1.5, type: 'elite_orc', tier: Tier.highElite, skill: MonsterSkill.brutalSwing)),
        '${tierNames[Tier.highElite]} ${monsterTypeNames['elite_orc']}: Brutal Swing');
    expect(e.toJson(), {'v': eventVersion, 'kind': 'monsterSkill', 'wave': 3, 't': 1.5, 'type': 'orc_rider', 'tier': 'miniBoss', 'skill': 'warShout'});
  });
}
