// The mini bosses' and the boss's skills (#59 branch 3; lib/boss_skills.dart): who casts what, the second
// skill's first cast and the gap between a mini boss's two, the boss's moment (once, at half its HP, tried again
// after a cancel), the newcomers a skill brings in (raised minions in every respect), and each skill's numbers.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// A wave on (of [wave], nothing left to spawn), the troops' skills off, and a monster of [type] and [tier] at
/// [at] that never strikes ([Unit.cd]), summons nor walks (a slow of 0): what it does is its skills' doing.
(Game, Unit) bossAt(String type, Tier tier, {Point<double> at = const Point(250.0, 60.0), int wave = 1}) {
  final g = bareGame()
    ..skills = false
    ..heroSkills = false
    ..wave = wave - 1;
  g
    ..startWave()
    ..queue.clear();
  final u = g.monster(type, tier, at)
    ..entered = true
    ..cd = hold
    ..summonCd = hold;
  g
    ..units.add(u)
    ..addEffect(u, Status.slow, hold, k: 0);
  return (g, u);
}

/// A troop of [type] standing at [at] that never moves or fights ([hold]).
Unit standing(Game g, String type, Point<double> at) {
  final u = Unit(Side.troop, type, troopTypes[type]!, at)
    ..entered = true
    ..busyUntil = hold;
  g.units.add(u);
  return u;
}

/// Ticks until [u] has begun [skill] and then cast it (the tick it lands); fails if it never began.
void lands(Game g, Unit u, MonsterSkill skill) {
  for (var i = 0; i < 60 && u.winding != skill; i++) {
    g.tick(0.05);
  }
  expect(u.winding, skill, reason: '${u.type} began ${skill.title}');
  for (var i = 0; i < 40 && u.winding != null; i++) {
    g.tick(0.05);
  }
  expect(u.winding, isNull, reason: '${u.type} cast ${skill.title}');
}

/// The skills [g]'s log saw begun, in order, and when.
List<(MonsterSkill, double)> begun(Game g) => [for (final e in g.log.entries.whereType<MonsterSkillCast>()) (e.skill, e.t)];

/// Kills [u] with one blow from troop [by] (a shot landing this tick).
void kill(Game g, Unit u, Unit by) {
  g.shots.add(Shot.special(by, u, u.pos - const Point(1.0, 0), dmg: 1e7, speed: 200));
  g.tick(0.05);
  expect(u.alive, isFalse);
}

void main() {
  test('a mini boss casts its signature and its mini-boss skill, a boss its moment too; high elites only the '
      'signature; none for raised minions, slimes (Slime Hex) or the troops', () {
    expect([for (final s in MonsterSkill.values.where((s) => s.rank == MonsterRank.miniBoss)) (s.type, s.title)], [
      ('slime', 'Split'),
      ('bat', 'Screech'),
      ('skeleton', 'Bone Shield'),
      ('orc', 'Headbutt'),
      ('skeleton_archer', 'Barbed Arrow'),
      ('werewolf', 'Frenzy'),
      ('armored_skeleton', 'Bone Bash'),
      ('orc_rider', 'Spear Throw'),
      ('elite_orc', 'Bloodrage'),
      ('armored_orc', 'Ground Slam'),
      ('greatsword_skeleton', 'Soul Rend'),
      ('werebear', 'Thick Hide'),
      (boss, 'Soul Drain'),
      (necroHealer, 'Unholy Ward'),
    ]);
    expect([for (final s in MonsterSkill.values.where((s) => s.rank == MonsterRank.moment)) (s.type, s.title)], [
      ('slime', 'Slime Tide'),
      ('bat', 'Swarm'),
      ('skeleton', 'Grave Call'),
      ('orc', 'Rally'),
      ('skeleton_archer', 'Bone Rain'),
      ('werewolf', 'Howl'),
      ('armored_skeleton', 'Iron March'),
      ('orc_rider', 'Second Wind'),
      ('elite_orc', 'Skull Crusher'),
      ('armored_orc', 'Earthshaker'),
      ('greatsword_skeleton', 'Grave Wave'),
      ('werebear', 'Roar'),
      (boss, 'Death Nova'),
      (necroHealer, 'Last Rites'),
    ]);
    // Once only: the moments, the mini-boss skills that come with a drop in HP or a death, and 2b's Reassemble.
    expect([for (final s in MonsterSkill.values) if (!s.cooldown.isFinite) s.name],
        ['reassemble', 'split', 'frenzy', 'thickHide', for (final s in MonsterSkill.values) if (s.rank == MonsterRank.moment) s.name]);
    expect((bossSkillGap, bossMomentK), (3.0, (at: 0.5, retry: 1.5)));

    final g = bareGame();
    Unit at(String type, Tier tier) => g.monster(type, tier, const Point(250.0, 60.0));
    const gs = 'greatsword_skeleton';
    expect([for (final tier in Tier.values) monsterSkillsOf(at(gs, tier))], [
      <MonsterSkill>[],
      <MonsterSkill>[],
      [MonsterSkill.bladeDance],
      [MonsterSkill.soulRend, MonsterSkill.bladeDance],
      [MonsterSkill.graveWave, MonsterSkill.soulRend, MonsterSkill.bladeDance],
    ]);
    expect(monsterSkillsOf(at(necroHealer, Tier.boss)), [MonsterSkill.lastRites, MonsterSkill.unholyWard, MonsterSkill.massMend]);
    expect(monsterSkillsOf(at('werewolf', Tier.boss)), [MonsterSkill.howl, MonsterSkill.frenzy, MonsterSkill.pounce]);
    expect(monsterSkillsOf(at(gs, Tier.boss)..raisedBy = at(boss, Tier.boss)), isEmpty);
    final hexed = at(gs, Tier.boss);
    hexed.effects[Status.hex] = Effect(10, 0, was: hexed.stats);
    expect(monsterSkillsOf(hexed), isEmpty);
    expect(monsterSkillsOf(Unit(Side.troop, 'soldier', troopTypes['soldier']!, const Point(100.0, 60.0))), isEmpty);
  });

  test('a mini boss\'s other skill first comes 3 s after its signature\'s first cast; after one starts the other '
      'waits 3 s', () {
    final g = bareGame()..skills = false;
    g
      ..startWave()
      ..queue.clear()
      ..queue.addAll([('orc', Tier.normal), ('greatsword_skeleton', Tier.miniBoss)]);
    for (var i = 0; i < 200 && g.queue.isNotEmpty; i++) {
      g.tick(0.05);
    }
    final gs = g.enemies.firstWhere((u) => u.type == 'greatsword_skeleton'), came = g.t;
    expect(gs.skillAt + MonsterSkill.bladeDance.cooldown - came, closeTo(3, 1e-9)); // its place in the wave: 2nd
    expect(gs.bossSkillAt + MonsterSkill.soulRend.cooldown - came, closeTo(3 + bossSkillGap, 1e-9));

    // Both wanted at once: the mini-boss skill first, the signature 3 s after it.
    final (h, mini) = bossAt('greatsword_skeleton', Tier.miniBoss);
    for (final dy in [6.0, -6.0]) {
      standing(h, 'knight', mini.pos - Point(10.0, dy))
        ..maxHp = 5000
        ..hp = 5000;
    }
    runFor(h, 5);
    final t0 = begun(h).first.$2;
    expect(begun(h).map((b) => b.$1), [MonsterSkill.soulRend, MonsterSkill.bladeDance]);
    expect(begun(h).last.$2 - t0, closeTo(bossSkillGap, 0.051));
  });

  test('the boss\'s moment: once, when its HP drops to half; a stun cancels it and it winds up again 1.5 s later; '
      'none while the wave marches, none for a mini boss', () {
    final (g, gs) = bossAt('greatsword_skeleton', Tier.boss);
    gs.hp = gs.maxHp * 0.51;
    runFor(g, 1);
    expect(begun(g), isEmpty);
    gs.hp = gs.maxHp * 0.5;
    g.tick(0.05);
    expect((gs.winding, gs.momentDone), (MonsterSkill.graveWave, false));
    gs.stunUntil = g.t + 0.2; // cancelled
    g.tick(0.05);
    final cancelled = g.t;
    expect(gs.winding, isNull);
    expect(gs.momentAt, closeTo(cancelled + bossMomentK.retry, 1e-9));
    runFor(g, bossMomentK.retry - 0.1);
    expect(gs.winding, isNull); // free again, but not yet
    runFor(g, 0.15);
    expect(gs.winding, MonsterSkill.graveWave);
    lands(g, gs, MonsterSkill.graveWave);
    expect(gs.momentDone, isTrue);
    gs.hp = gs.maxHp * 0.2; // lower still: it doesn't come again
    runFor(g, 3);
    expect(begun(g).map((b) => b.$1), [MonsterSkill.graveWave, MonsterSkill.graveWave]);

    final (h, marcher) = bossAt('greatsword_skeleton', Tier.boss);
    marcher.hp = marcher.maxHp * 0.4;
    h.marching = true;
    runFor(h, 1);
    expect(begun(h), isEmpty);

    final (k, mini) = bossAt('greatsword_skeleton', Tier.miniBoss);
    mini.hp = mini.maxHp * 0.4;
    runFor(k, 2);
    expect(begun(k), isEmpty);
  });

  test('Split\'s slimes have the wave\'s tide, from the game\'s tideStart', () {
    final (g, slime) = bossAt('slime', Tier.miniBoss, wave: 87);
    g.tideStart = 18;
    slime.skillAt = hold;
    kill(g, slime, standing(g, 'archer', slime.pos - const Point(40.0, 0)));
    expect(g.raised, hasLength(splitK.slimes));
    for (final m in g.raised) {
      expect(m.maxHp, enemyStats('slime', Tier.normal, 87, raised: true, tideStart: 18).hp);
    }
    expect(g.raised.first.maxHp, greaterThan(enemyStats('slime', Tier.normal, 87, raised: true, tideStart: 66).hp));
  });

  test('Split: a slime mini boss bursts into 3 normal slimes of its wave as it dies; they are raised minions in '
      'every respect: no gold, no score, no skills, the wave goes on while they live, the watchdog doesn\'t count '
      'them', () {
    final (g, slime) = bossAt('slime', Tier.miniBoss, wave: 20);
    slime.skillAt = hold; // its Sticky Glob (branch 2a) stays out
    final archer = standing(g, 'archer', slime.pos - const Point(40.0, 0));
    final gold = g.gold;
    kill(g, slime, archer);
    expect(g.gold - gold, slime.stats.cost);
    final newcomers = [...g.raised];
    for (final m in newcomers) {
      m.busyUntil = hold; // they stand where they came
    }
    expect(newcomers.map((m) => (m.type, m.tier, m.raisedBy, m.stats.cost)), List.filled(3, ('slime', Tier.normal, slime, 0)));
    for (final m in newcomers) {
      expect(m.pos.distanceTo(slime.pos), closeTo(splitK.spread, 1e-9));
      expect(m.maxHp, enemyStats('slime', Tier.normal, 20).hp);
      expect(monsterSkillsOf(m), isEmpty);
    }
    expect(g.monsterCasts.last, (newcomers.first, MonsterSkill.split));
    expect(begun(g).map((b) => b.$1), [MonsterSkill.split]);
    g.tick(0.05);
    expect(g.enemies.where((u) => u.alive).toList(), newcomers); // they joined the field
    runFor(g, 2);
    expect(g.waveActive, isTrue); // the slime's body is gone; the wave goes on while they live

    // The watchdog: their HP going down is no progress, so with only them left the wave still marches.
    for (final m in newcomers) {
      m
        ..maxHp = 1000
        ..hp = 1000;
    }
    for (var i = 0; i < stallTime + 2 && !g.marching; i++) {
      newcomers.first.hp -= 1;
      runFor(g, 1);
    }
    expect(g.marching, isTrue);

    // No gold and no score for them; the wave ends when they are down.
    final (gold2, score2) = (g.gold, g.score);
    for (final m in newcomers) {
      kill(g, m, archer);
    }
    expect((g.gold, g.score), (gold2, score2));
    runFor(g, 2);
    expect(g.waveActive, isFalse);

    // A high elite slime doesn't split; nor a mini boss while its wave marches.
    final (h, elite) = bossAt('slime', Tier.highElite);
    kill(h, elite, standing(h, 'archer', elite.pos - const Point(40.0, 0)));
    expect(h.raised, isEmpty);
    final (m, marching) = bossAt('slime', Tier.miniBoss);
    m.marching = true;
    kill(m, marching, standing(m, 'archer', marching.pos - const Point(40.0, 0)));
    expect(m.raised, isEmpty);
  });

  test('Screech: with 3 troops within 2 tiles the bat\'s screech makes their attacks come 1.25x as far apart for '
      '4 s; not with 2', () {
    final (g, bat) = bossAt('bat', Tier.miniBoss);
    final troops = [for (final dy in [-8.0, 8.0]) standing(g, 'knight', bat.pos - Point(12.0, dy))];
    runFor(g, 0.5);
    expect(bat.winding, isNull);
    final before = g.attackEvery(troops.first);
    troops.add(standing(g, 'soldier', bat.pos - const Point(20.0, 0)));
    lands(g, bat, MonsterSkill.screech);
    for (final o in troops) {
      expect(g.effectK(o, Status.daze), screechK.pause);
      expect(g.effectOn(o, Status.daze)!.until, closeTo(g.t + screechK.time, 1e-9));
    }
    expect(g.attackEvery(troops.first), closeTo(before * screechK.pause, 1e-9));
    expect(g.rings.map((r) => (r.look, r.radius)), [(RingLook.pale, screechK.reach)]); // a pale ring bursts out
    // A troop's own haste still counts beside it.
    g.addEffect(troops.first, Status.haste, 4, k: 0.8);
    expect(g.attackEvery(troops.first), closeTo(before * screechK.pause * 0.8, 1e-9));
  });

  test('Bone Shield: the most hurt undead monster within 2 tiles below half its HP takes 40% less for 4 s; an orc '
      'isn\'t undead', () {
    final (g, sk) = bossAt('skeleton', Tier.miniBoss);
    final orc = foeAt(g, 'orc', sk.pos + const Point(10.0, 0))..hp = 1;
    runFor(g, 0.5);
    expect(sk.winding, isNull);
    final archer = foeAt(g, 'skeleton_archer', sk.pos + const Point(0, 12.0))..hp = 15; // 15/40
    final gs = foeAt(g, 'greatsword_skeleton', sk.pos - const Point(0, 12.0))..hp = 50; // 50/220: the most hurt
    lands(g, sk, MonsterSkill.boneShield);
    expect((gs.guardCut, gs.guardLook), (boneShieldK.cut, RingLook.bone));
    expect(gs.guardUntil, closeTo(g.t + boneShieldK.time, 1e-9));
    expect(archer.guardUntil, double.negativeInfinity);
    expect(orc.guardUntil, double.negativeInfinity);
  });

  test('Barbed Arrow: the skeleton archer shoots the nearest troop in range for 1x, and it bleeds 0.5x a second 4 '
      'times', () {
    final (g, a) = bossAt('skeleton_archer', Tier.miniBoss);
    a.skillAt = double.infinity; // its Volley kept out of this
    final far = standing(g, 'knight', a.pos - const Point(50.0, 0)), near = standing(g, 'knight', a.pos - const Point(30.0, 0));
    for (final o in [far, near]) {
      o
        ..maxHp = 5000
        ..hp = 5000;
    }
    lands(g, a, MonsterSkill.barbedArrow);
    final shot = g.shots.single;
    expect(shot.target, near);
    expect(shot.dmg, closeTo(a.stats.dmg * barbedArrowK.hit, 1e-9));
    runFor(g, 0.5);
    expect(near.maxHp - near.hp, closeTo(a.stats.dmg * barbedArrowK.hit, 1e-9));
    final bleed = g.effectOn(near, Status.bleed)!;
    expect((bleed.n, bleed.by), (barbedArrowK.time, a));
    expect(bleed.k, closeTo(a.stats.dmg * barbedArrowK.bleed, 1e-9));
    runFor(g, 4.2);
    expect(near.maxHp - near.hp, closeTo(a.stats.dmg * (barbedArrowK.hit + barbedArrowK.bleed * barbedArrowK.time), 1e-9));
    expect(far.hp, far.maxHp);

    // The arrow and the bleed share the cap (per cast per troop): a strong archer's arrow uses it all.
    final (h, strong) = bossAt('skeleton_archer', Tier.miniBoss, wave: 60);
    strong.skillAt = double.infinity;
    final knight = standing(h, 'knight', strong.pos - const Point(30.0, 0));
    expect(strong.stats.dmg * barbedArrowK.hit, greaterThan(knight.maxHp * monsterSkillCap.troop));
    lands(h, strong, MonsterSkill.barbedArrow);
    runFor(h, 5);
    expect(knight.maxHp - knight.hp, closeTo(knight.maxHp * monsterSkillCap.troop, 1e-6));
    expect(h.under(knight, Status.bleed), isFalse);
  });

  test('Frenzy: once, when the werewolf drops below half its HP, its attacks come 1/1.4 as far apart for 6 s '
      '(never under the floor)', () {
    final (g, wolf) = bossAt('werewolf', Tier.miniBoss);
    wolf.hp = wolf.maxHp * 0.55;
    runFor(g, 0.5);
    expect(begun(g), isEmpty);
    final before = g.attackEvery(wolf);
    wolf.hp = wolf.maxHp * 0.45;
    lands(g, wolf, MonsterSkill.frenzy);
    expect(g.effectK(wolf, Status.haste), frenzyK.pause);
    expect(g.effectOn(wolf, Status.haste)!.until, closeTo(g.t + frenzyK.time, 1e-9));
    expect(g.attackEvery(wolf), closeTo(max(minAttackInterval, before * frenzyK.pause), 1e-9));
    wolf.hp = wolf.maxHp.toDouble();
    runFor(g, 7);
    wolf.hp = wolf.maxHp * 0.3;
    runFor(g, 2);
    expect(begun(g).map((b) => b.$1), [MonsterSkill.frenzy]); // once
  });

  test('Spear Throw: the orc rider throws a spear at the nearest back-line troop within 5 tiles for 1.5x (at most '
      '35% of its max HP), past a nearer knight', () {
    final (g, rider) = bossAt('orc_rider', Tier.miniBoss, wave: 30);
    standing(g, 'knight', rider.pos - const Point(12.0, 0));
    runFor(g, 0.5);
    expect(rider.winding, isNull); // no back line within 5 tiles
    final priest = standing(g, 'priest', rider.pos - const Point(70.0, 0)), archer = standing(g, 'archer', rider.pos - const Point(60.0, 0));
    lands(g, rider, MonsterSkill.spearThrow);
    final spear = g.shots.single;
    expect((spear.target, spear.look, spear.speed), (archer, ShotLook.spear, spearThrowK.speed));
    expect(spear.dmg, closeTo(min(rider.stats.dmg * spearThrowK.hit, archer.maxHp * monsterSkillCap.troop), 1e-9));
    expect(priest.hp, priest.maxHp);
  });

  test('Bloodrage: below 60% of its HP with a troop in reach the elite orc heals 30% of what it deals for 6 s', () {
    final (g, orc) = bossAt('elite_orc', Tier.miniBoss);
    orc.hp = orc.maxHp * 0.65;
    standing(g, 'knight', orc.pos - const Point(10.0, 0));
    runFor(g, 0.5);
    expect(begun(g).map((b) => b.$1), isNot(contains(MonsterSkill.bloodrage)));
    orc.hp = orc.maxHp * 0.55;
    lands(g, orc, MonsterSkill.bloodrage);
    expect(g.effectK(orc, Status.lifesteal), bloodrageK.share);
    expect(g.effectOn(orc, Status.lifesteal)!.until, closeTo(g.t + bloodrageK.time, 1e-9));
  });

  test('Ground Slam: with 3 troops within 1.5 tiles the armored orc hits each for 1x; not with 2', () {
    final (g, orc) = bossAt('armored_orc', Tier.miniBoss);
    // Out of its reach (no Bulwark), within 1.5 tiles.
    final troops = [for (final dy in [-8.0, 8.0]) standing(g, 'knight', orc.pos - Point(14.0, dy))];
    runFor(g, 0.5);
    expect(begun(g), isEmpty);
    troops.add(standing(g, 'knight', orc.pos - const Point(22.0, 0)));
    final far = standing(g, 'knight', orc.pos - const Point(30.0, 0));
    for (final o in [...troops, far]) {
      o
        ..maxHp = 5000
        ..hp = 5000;
    }
    lands(g, orc, MonsterSkill.groundSlam);
    for (final o in troops) {
      expect(o.maxHp - o.hp, closeTo(orc.stats.dmg * groundSlamK.hit, 1e-9));
    }
    expect(far.hp, far.maxHp);
  });

  test('Soul Rend: with a troop that has 5 MP in reach, the greatsword skeleton\'s blows take 5 MP each for 6 s', () {
    final (g, gs) = bossAt('greatsword_skeleton', Tier.miniBoss);
    final knight = standing(g, 'knight', gs.pos - const Point(12.0, 0))..mp = 0;
    runFor(g, 0.5);
    expect(gs.winding, isNull); // not 5 MP to take
    knight.mp = 20;
    lands(g, gs, MonsterSkill.soulRend);
    expect(g.effectK(gs, Status.soulRend), soulRendK.mp);
    expect(g.effectOn(gs, Status.soulRend)!.until, closeTo(g.t + soulRendK.time, 1e-9));
    gs.cd = 0; // one blow
    g.tick(0.05);
    gs.cd = hold;
    expect(knight.mp, closeTo(20 - soulRendK.mp, 0.1)); // and a tick's MP back
  });

  test('Thick Hide: once, when the werebear drops below half its HP, it takes 30% less for 6 s', () {
    final (g, bear) = bossAt('werebear', Tier.miniBoss);
    bear
      ..hp = bear.maxHp * 0.45
      ..guardOmen = true; // a Bayangan's guard before (the v2 rules): a skill's takes the slot and clears the flag
    lands(g, bear, MonsterSkill.thickHide);
    expect((bear.guardCut, bear.guardLook, bear.guardOmen), (thickHideK.cut, RingLook.brown, false));
    expect(bear.guardUntil, closeTo(g.t + thickHideK.time, 1e-9));
    runFor(g, 7);
    bear.hp = bear.maxHp * 0.3;
    runFor(g, 1);
    expect(begun(g).map((b) => b.$1), [MonsterSkill.thickHide]);
  });

  test('Unholy Ward: a monster in range hit twice in the last 2 s soaks 2x the healing necromancer\'s heal for 6 s', () {
    final (g, h) = bossAt(necroHealer, Tier.miniBoss);
    final orc = foeAt(g, 'orc', h.pos - const Point(30.0, 0))..hurtAt = g.t;
    runFor(g, 0.5);
    expect(h.winding, isNull); // hit once
    orc
      ..hurtBefore = g.t - 1
      ..hurtAt = g.t;
    lands(g, h, MonsterSkill.unholyWard);
    expect(g.effectK(orc, Status.absorb), closeTo(h.stats.dmg * unholyWardK.soak, 1e-9));
    expect(g.effectOn(orc, Status.absorb)!.until, closeTo(g.t + unholyWardK.time, 1e-9));
  });

  test('Swarm: at half its HP the bat boss calls 4 normal bats of its wave round it, raised minions', () {
    final (g, bat) = bossAt('bat', Tier.boss, wave: 10);
    bat.hp = bat.maxHp * 0.5;
    lands(g, bat, MonsterSkill.swarm);
    final bats = [...g.enemies.where((m) => m.raisedBy == bat)];
    expect(bats.map((m) => (m.type, m.tier, m.raisedBy, m.stats.cost)), List.filled(swarmK.bats, ('bat', Tier.normal, bat, 0)));
    for (final m in bats) {
      expect(m.pos.distanceTo(bat.pos), closeTo(swarmK.spread, 1e-6));
    }
  });

  test('Grave Call: at half its HP the skeleton boss raises up to 4 skeleton kinds that fell this wave within 4 '
      'tiles, nearest first, at 25% of their HP; never a raised one, nor one that fell before the wave', () {
    final (g, sk) = bossAt('skeleton', Tier.boss);
    final archer = standing(g, 'archer', sk.pos - const Point(60.0, 0));
    final fell = [
      for (final (type, tier, dx) in [
        ('skeleton_archer', Tier.highElite, 10.0),
        ('skeleton', Tier.normal, 20.0),
        ('armored_skeleton', Tier.elite, 30.0),
        ('greatsword_skeleton', Tier.normal, 40.0),
        ('skeleton', Tier.normal, 50.0), // the fifth nearest
        ('skeleton', Tier.normal, 70.0), // beyond 4 tiles
      ])
        foeAt(g, type, sk.pos + Point(dx, 0), tier),
    ];
    final orc = foeAt(g, 'orc', sk.pos + const Point(5.0, 0));
    final minion = foeAt(g, 'skeleton', sk.pos + const Point(6.0, 0))..raisedBy = sk;
    for (final o in [...fell, orc, minion]) {
      kill(g, o, archer);
    }
    expect(g.graves, fell);
    sk.hp = sk.maxHp * 0.5;
    lands(g, sk, MonsterSkill.graveCall);
    final risen = [...g.enemies.where((m) => m.raisedBy == sk && m.alive)];
    expect(risen.map((m) => (m.type, m.tier, m.raisedBy, m.stats.cost)).toList(), [for (final o in fell.take(4)) (o.type, o.tier, sk, 0)]);
    for (final (i, m) in risen.indexed) {
      expect(m.pos.distanceTo(fell[i].pos), lessThan(tile / 2)); // where it lay (then made room for)
      expect(m.hp, closeTo(m.maxHp * graveCallK.hp, 1e-9));
      expect(monsterSkillsOf(m), isEmpty); // the high elite archer casts nothing now
    }
    expect(fell.take(4).map((o) => o.gone), everyElement(isTrue)); // their bodies go
    expect(g.graves, fell.skip(4));
  });

  test('Rally: at half its HP the orc boss makes every orc kind on the field deal 1.25x and attack 1/1.2 as far '
      'apart for 8 s', () {
    final (g, orc) = bossAt('orc', Tier.boss);
    final kin = [for (final (type, dx) in [('orc_rider', 100.0), ('elite_orc', -60.0), ('armored_orc', 20.0)]) foeAt(g, type, orc.pos + Point(dx, 0))];
    final slime = foeAt(g, 'slime', orc.pos + const Point(10.0, 0));
    orc.hp = orc.maxHp * 0.5;
    lands(g, orc, MonsterSkill.rally);
    for (final o in [orc, ...kin]) {
      expect((g.effectK(o, Status.might), g.effectK(o, Status.haste)), (rallyK.might, rallyK.pause), reason: o.type);
      expect(g.effectOn(o, Status.might)!.until, closeTo(g.t + rallyK.time, 1e-9));
    }
    expect(g.under(slime, Status.might), isFalse);
  });

  test('Howl: at half its HP the werewolf boss makes every monster within 3 tiles walk 1.25x as fast and attack 1/1.2 '
      'as far apart for 6 s', () {
    final (g, wolf) = bossAt('werewolf', Tier.boss);
    final near = foeAt(g, 'orc', wolf.pos + const Point(30.0, 30.0)), far = foeAt(g, 'orc', wolf.pos + const Point(60.0, 0));
    wolf.hp = wolf.maxHp * 0.5;
    lands(g, wolf, MonsterSkill.howl);
    for (final o in [wolf, near]) {
      expect((g.effectK(o, Status.swift), g.effectK(o, Status.haste)), (howlK.walk, howlK.pause));
      expect(g.effectOn(o, Status.swift)!.until, closeTo(g.t + howlK.time, 1e-9));
    }
    expect(g.under(far, Status.swift), isFalse);
    // It walks faster: a step of the orc near it, freed, against its own speed, toward a troop far off (with none
    // standing a monster waits, decisions-log 329).
    near.busyUntil = double.negativeInfinity;
    standing(g, 'soldier', near.pos - const Point(200.0, 0));
    final x = near.pos.x;
    g.tick(0.05);
    expect(x - near.pos.x, closeTo(near.stats.speed * howlK.walk * 0.05, 1e-6));
  });

  test('Second Wind: at half its HP the orc rider boss gets 25% of its max HP back and walks and attacks faster for '
      '6 s', () {
    final (g, rider) = bossAt('orc_rider', Tier.boss);
    rider.hp = rider.maxHp * 0.5;
    lands(g, rider, MonsterSkill.secondWind);
    expect(rider.hp, closeTo(rider.maxHp * (0.5 + secondWindK.heal), 1e-6));
    expect((g.effectK(rider, Status.swift), g.effectK(rider, Status.haste)), (secondWindK.walk, secondWindK.pause));
  });

  test('Grave Wave: at half its HP the greatsword skeleton boss sends a wave 5 tiles towards the nearest troop: 2x '
      'to each troop on its line, at most 35% of its max HP', () {
    final (g, gs) = bossAt('greatsword_skeleton', Tier.boss, wave: 10);
    final troops = [
      for (final dx in [20.0, 40.0, 100.0])
        standing(g, 'knight', gs.pos - Point(dx, 0))
          ..maxHp = 2000
          ..hp = 2000,
    ];
    final aside = standing(g, 'knight', gs.pos - const Point(30.0, 20));
    final hero = standing(g, 'soldier', gs.pos - const Point(60.0, 0))..hero = true;
    gs.hp = gs.maxHp * 0.5;
    lands(g, gs, MonsterSkill.graveWave);
    final wave = g.lineShots.single;
    expect((wave.dir, wave.length, wave.speed, wave.look), (const Point(-1.0, 0.0), graveWaveK.length, graveWaveK.speed, ShotLook.long));
    runFor(g, 1);
    expect(troops.map((o) => o.maxHp - o.hp), [
      closeTo(gs.stats.dmg * graveWaveK.hit, 1e-6),
      closeTo(gs.stats.dmg * graveWaveK.hit, 1e-6),
      0.0, // beyond 5 tiles
    ]);
    expect(aside.hp, aside.maxHp);
    expect(hero.maxHp - hero.hp, closeTo(min(gs.stats.dmg * graveWaveK.hit, hero.maxHp * monsterSkillCap.hero), 1e-6));
  });

  test('Roar: at half its HP the werebear boss makes the troops within 3 tiles deal 0.75x for 5 s', () {
    final (g, bear) = bossAt('werebear', Tier.boss);
    final near = standing(g, 'knight', bear.pos - const Point(40.0, 0)), far = standing(g, 'knight', bear.pos - const Point(60.0, 0));
    bear.hp = bear.maxHp * 0.5;
    lands(g, bear, MonsterSkill.roar);
    expect(g.effectK(near, Status.weaken), roarK.dealt);
    expect(g.effectOn(near, Status.weaken)!.until, closeTo(g.t + roarK.time, 1e-9));
    expect(g.under(far, Status.weaken), isFalse);
    // What the knight deals now.
    final orc = foeAt(g, 'orc', near.pos + const Point(8.0, 0))
      ..maxHp = 1000
      ..hp = 1000;
    near
      ..busyUntil = double.negativeInfinity
      ..cd = 0;
    g.tick(0.05);
    expect(orc.maxHp - orc.hp, closeTo(hitTaken(near.stats.dmg * roarK.dealt, orc.stats.def), 1e-6));
  });

  test('Death Nova: at half its HP the necromancer boss hits every troop within 2.5 tiles for 1.5x, a Hero at most '
      '25% of its max HP', () {
    final (g, necro) = bossAt(boss, Tier.boss, wave: 5);
    final near = standing(g, 'knight_templar', necro.pos - const Point(30.0, 0)), far = standing(g, 'knight', necro.pos - const Point(45.0, 0));
    final hero = standing(g, 'knight', necro.pos - const Point(10.0, 10))..hero = true;
    necro.hp = necro.maxHp * 0.5;
    lands(g, necro, MonsterSkill.deathNova);
    expect(near.maxHp - near.hp, closeTo(min(necro.stats.dmg * deathNovaK.hit, near.maxHp * monsterSkillCap.troop), 1e-6));
    expect(hero.maxHp - hero.hp, closeTo(min(necro.stats.dmg * deathNovaK.hit, hero.maxHp * monsterSkillCap.hero), 1e-6));
    expect(far.hp, far.maxHp);
  });

  test('Last Rites: at half its HP the healing necromancer boss gives every monster within 3 tiles 20% of its max '
      'HP back', () {
    final (g, h) = bossAt(necroHealer, Tier.boss);
    final near = foeAt(g, 'orc', h.pos + const Point(40.0, 0))..hp = 10, far = foeAt(g, 'orc', h.pos + const Point(60.0, 0))..hp = 10;
    h.hp = h.maxHp * 0.5;
    lands(g, h, MonsterSkill.lastRites);
    expect(near.hp, closeTo(10 + near.maxHp * lastRitesK.heal, 1e-9));
    expect(h.hp, closeTo(h.maxHp * (0.5 + lastRitesK.heal), 1e-9));
    expect(far.hp, 10);
  });

  test('Headbutt: the orc hits the nearest troop in reach for 1.2x and stuns it 0.5 s (a Hero 0.25 s), then it can\'t '
      'be stunned for 4 s', () {
    final (g, orc) = bossAt('orc', Tier.miniBoss);
    final knight = standing(g, 'knight', orc.pos - const Point(10.0, 0))
      ..maxHp = 5000
      ..hp = 5000;
    lands(g, orc, MonsterSkill.headbutt);
    expect(knight.maxHp - knight.hp, closeTo(orc.stats.dmg * headbuttK.hit, 1e-9));
    expect(knight.stunUntil, closeTo(g.t + headbuttK.stun, 1e-9));
    expect(knight.stunImmuneUntil, closeTo(knight.stunUntil + troopStunK.immune, 1e-9));

    final (h, mini) = bossAt('orc', Tier.miniBoss);
    final hero = standing(h, 'knight', mini.pos - const Point(10.0, 0))
      ..hero = true
      ..maxHp = 5000
      ..hp = 5000;
    lands(h, mini, MonsterSkill.headbutt);
    expect(hero.stunUntil, closeTo(h.t + headbuttK.stun * troopStunK.hero, 1e-9));
  });

  test('Bone Bash: the armored skeleton hits the nearest troop in reach for 1x and knocks it a tile towards the base', () {
    final (g, sk) = bossAt('armored_skeleton', Tier.miniBoss);
    final knight = standing(g, 'knight', sk.pos - const Point(12.0, 0)) // in its reach, not near enough to be shoved
      ..maxHp = 5000
      ..hp = 5000;
    final x = knight.pos.x;
    lands(g, sk, MonsterSkill.boneBash);
    expect(knight.maxHp - knight.hp, closeTo(sk.stats.dmg * boneBashK.hit, 1e-9));
    expect(knight.move, isNotNull);
    runFor(g, 1);
    expect(x - knight.pos.x, closeTo(boneBashK.shove, 1e-6));
  });

  test('Soul Drain: the necromancer drains the troop with the most HP within 4 tiles: 0.6x three times a second '
      'apart, healing half; a stun on it ends the drain', () {
    final (g, necro) = bossAt(boss, Tier.miniBoss, wave: 5);
    necro.hp = necro.maxHp * 0.5;
    standing(g, 'knight', necro.pos - const Point(30.0, 0));
    final templar = standing(g, 'knight_templar', necro.pos - const Point(50.0, 0))
      ..maxHp = 5000
      ..hp = 5000;
    lands(g, necro, MonsterSkill.soulDrain);
    final beam = g.beams.single;
    expect(beam.look, BeamLook.drain);
    expect(beam.follow, [necro, templar]);
    final hp = necro.hp;
    runFor(g, 3.1);
    final each = necro.stats.dmg * soulDrainK.hit;
    expect(templar.maxHp - templar.hp, closeTo(each * soulDrainK.ticks, 1e-6));
    expect(necro.hp - hp, closeTo(each * soulDrainK.ticks * soulDrainK.heal, 1e-6));
    expect(g.beams, isEmpty);

    final (h, stunned) = bossAt(boss, Tier.miniBoss, wave: 5);
    final knight = standing(h, 'knight_templar', stunned.pos - const Point(30.0, 0))
      ..maxHp = 5000
      ..hp = 5000;
    lands(h, stunned, MonsterSkill.soulDrain);
    runFor(h, 0.6); // the first drain
    stunned.stunUntil = h.t + 5;
    runFor(h, 3);
    expect(knight.maxHp - knight.hp, closeTo(stunned.stats.dmg * soulDrainK.hit, 1e-6));
    expect(h.beams, isEmpty);

    // The three drains on one troop share the cap (per cast per troop).
    final (k, strong) = bossAt(boss, Tier.miniBoss, wave: 60);
    final archer = standing(k, 'archer', strong.pos - const Point(30.0, 0));
    expect(strong.stats.dmg * soulDrainK.hit * soulDrainK.ticks, greaterThan(archer.maxHp * monsterSkillCap.troop));
    lands(k, strong, MonsterSkill.soulDrain);
    runFor(k, 3.1);
    expect(archer.maxHp - archer.hp, closeTo(archer.maxHp * monsterSkillCap.troop, 1e-6));
  });

  test('Slime Tide: at half its HP the slime boss leaves a puddle 1.5 tiles round it for 6 s: troops in it walk 40% '
      'slower', () {
    final (g, slime) = bossAt('slime', Tier.boss);
    final inside = standing(g, 'knight', slime.pos - const Point(20.0, 0)), outside = standing(g, 'knight', slime.pos - const Point(30.0, 0));
    slime.hp = slime.maxHp * 0.5;
    lands(g, slime, MonsterSkill.slimeTide);
    final zone = g.zones.single;
    expect((zone.at, zone.radius, zone.look, zone.side), (slime.pos, slimeTideK.radius, ZoneLook.slime, Side.troop));
    expect(zone.until, closeTo(g.t + slimeTideK.time, 1e-9));
    g.tick(0.05);
    expect(g.effectK(inside, Status.slow), slimeTideK.slow);
    expect(g.under(outside, Status.slow), isFalse);
  });

  test('Bone Rain: at half its HP the skeleton archer boss rains arrows 1 tile round the thickest spot of troops in '
      'its range for 4 s: 0.5x to each troop there every second', () {
    final (g, a) = bossAt('skeleton_archer', Tier.boss);
    a
      ..skillAt = double.infinity // its Volley and Barbed Arrow kept out of this
      ..bossSkillAt = double.infinity;
    final lone = standing(g, 'knight', a.pos - const Point(20.0, 0));
    final crowd = [
      for (final dy in [-12.0, 0.0, 12.0]) // a tile apart: none shoves another
        standing(g, 'knight', a.pos - Point(45.0, dy))
          ..maxHp = 5000
          ..hp = 5000,
    ];
    a.hp = a.maxHp * 0.5;
    lands(g, a, MonsterSkill.boneRain);
    final zone = g.zones.single;
    expect((zone.at, zone.radius, zone.look), (crowd[1].pos, boneRainK.radius, ZoneLook.arrowRain));
    runFor(g, 4.5);
    for (final o in crowd) {
      expect(o.maxHp - o.hp, closeTo(a.stats.dmg * boneRainK.hit * boneRainK.time, 1e-6));
    }
    expect(lone.hp, lone.maxHp);

    // Its arrows on one troop share the cap (per cast per troop): four volleys that would take more stop at 35%.
    final (h, strong) = bossAt('skeleton_archer', Tier.boss, wave: 30);
    strong
      ..skillAt = double.infinity
      ..bossSkillAt = double.infinity
      ..hp = strong.maxHp * 0.5;
    final soldier = standing(h, 'soldier', strong.pos - const Point(40.0, 0));
    expect(strong.stats.dmg * boneRainK.hit * boneRainK.time, greaterThan(soldier.maxHp * monsterSkillCap.troop));
    lands(h, strong, MonsterSkill.boneRain);
    runFor(h, 4.5);
    expect(soldier.maxHp - soldier.hp, closeTo(soldier.maxHp * monsterSkillCap.troop, 1e-6));
  });

  test('Iron March: at half its HP the armored skeleton boss walks 1.3x as fast for 8 s, and no slow holds it; its '
      'steel ring', () {
    final (g, sk) = bossAt('armored_skeleton', Tier.boss); // held by a slow of 0
    sk.hp = sk.maxHp * 0.5;
    lands(g, sk, MonsterSkill.ironMarch);
    expect((g.under(sk, Status.steadfast), g.effectK(sk, Status.swift), sk.guardLook), (true, ironMarchK.walk, RingLook.steel));
    expect(sk.guardUntil, closeTo(g.t + ironMarchK.time, 1e-9));
    standing(g, 'soldier', sk.pos - const Point(200.0, 0)); // it walks to a troop far off (with none it waits, decisions-log 329)
    final x = sk.pos.x;
    g.tick(0.05);
    expect(x - sk.pos.x, closeTo(sk.stats.speed * ironMarchK.walk * 0.05, 1e-6));
    runFor(g, ironMarchK.time);
    final x2 = sk.pos.x;
    g.tick(0.05);
    expect(sk.pos.x, x2); // held again
  });

  test('Skull Crusher: at half its HP, once a troop is in its reach, the elite orc boss hits the nearest for 3x (at '
      'most 35% of its max HP) and stuns it 0.8 s', () {
    final (g, orc) = bossAt('elite_orc', Tier.boss, wave: 20);
    orc.hp = orc.maxHp * 0.5;
    runFor(g, 1);
    expect(begun(g), isEmpty); // nobody in reach
    final knight = standing(g, 'knight', orc.pos - const Point(10.0, 0));
    lands(g, orc, MonsterSkill.skullCrusher);
    expect(knight.maxHp - knight.hp, closeTo(min(orc.stats.dmg * skullCrusherK.hit, knight.maxHp * monsterSkillCap.troop), 1e-6));
    expect(knight.stunUntil, closeTo(g.t + skullCrusherK.stun, 1e-9));
  });

  test('Earthshaker: at half its HP the armored orc boss hits every troop within 3 tiles for 1.2x and stuns each 0.5 s, '
      'not one still immune', () {
    final (g, orc) = bossAt('armored_orc', Tier.boss);
    final troops = [
      for (final dx in [20.0, 40.0])
        standing(g, 'knight', orc.pos - Point(dx, 0))
          ..maxHp = 5000
          ..hp = 5000,
    ];
    final immune = standing(g, 'knight', orc.pos - const Point(30.0, 12))..stunImmuneUntil = 100;
    final far = standing(g, 'knight', orc.pos - const Point(60.0, 0));
    orc.hp = orc.maxHp * 0.5;
    lands(g, orc, MonsterSkill.earthshaker);
    for (final o in troops) {
      expect(o.maxHp - o.hp, closeTo(orc.stats.dmg * earthshakerK.hit, 1e-9));
      expect(o.stunUntil, closeTo(g.t + earthshakerK.stun, 1e-9));
    }
    expect(immune.stunUntil, double.negativeInfinity);
    expect(far.hp, far.maxHp);
    expect(g.rings.map((r) => (r.look, r.radius)), [(RingLook.brown, earthshakerK.reach)]);
  });
}
