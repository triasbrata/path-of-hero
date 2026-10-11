// Heroes' own skills (#48, branch 2c): the ten that change the damage rules or what monsters and troops do.
// docs/units-and-combat.md, "Hero skills".
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

void main() {
  /// A troop of [type] at cell ([c], [r]) that never strikes (nor heals) on its own.
  Unit idle(Game g, String type, int c, int r) => placeNow(g, type, c, r)..cd = hold;

  /// Monster [m] strikes its nearest foe once, now (it must be in its reach): one tick.
  void strikeOnce(Game g, Unit m) {
    m
      ..busyUntil = double.negativeInfinity
      ..cd = 0;
    g.tick(0.05);
    m.busyUntil = hold;
  }

  test('the ten are built, so Heroes roll them', () {
    for (final s in [
      HeroSkill.lastStand, HeroSkill.parry, HeroSkill.duel, HeroSkill.shareWounds, HeroSkill.whirlwind, //
      HeroSkill.lightVeil, HeroSkill.giantRage, HeroSkill.manaShield, HeroSkill.holyTaunt, HeroSkill.bastion,
    ]) {
      expect(heroSkillPool(s.type), contains(s), reason: s.name);
    }
  });

  test('Last Stand: hurt (any HP lost since decisions-log 298) with a foe in reach it stands its ground for 6 s, deals 1.5x, and each kill heals it 20%', () {
    final (g, h) = heroCaster(HeroSkill.lastStand);
    idle(g, 'priest', 0, 3); // a healer to fall back to
    final foe = foeAt(g, 'orc', h.pos + Point(h.stats.range, 0));
    foeAt(g, 'orc', const Point(300, 10)); // keeps the wave on
    g.tick(0.05);
    expect(h.heroSkillAt, double.negativeInfinity, reason: 'at full health');
    expect(lastStandK.below, 1.0);
    h.hp = h.maxHp * 0.4;
    g.tick(0.05);
    expect(h.heroSkillAt, g.t);
    expect(h.retreating, isFalse); // at 40% it would fall back to the priest
    expect((g.effectK(h, Status.might), g.effectK(h, Status.killHeal)), (lastStandK.might, lastStandK.heal));
    expect(g.effectOn(h, Status.holdGround)!.until, g.t + lastStandK.time);

    h.cd = 0;
    g.tick(0.05);
    expect(foe.hp, closeTo(foe.maxHp - h.stats.dmg * lastStandK.might, 1e-9));
    final hp = h.hp;
    foe.hp = 1;
    h.cd = 0;
    g.tick(0.05);
    expect(foe.alive, isFalse);
    expect(h.hp, closeTo(hp + h.maxHp * lastStandK.heal, 1e-9));
    runFor(g, lastStandK.time);
    expect(g.under(h, Status.holdGround), isFalse);
  });

  test('Parry: hit with a melee foe in reach, it blocks the next 3 melee blows and answers each 1.5x; not against shots only', () {
    final (g, h) = heroCaster(HeroSkill.parry);
    final orc = foeAt(g, 'orc', h.pos + Point(h.stats.range, 0));
    g.tick(0.05);
    expect(h.heroSkillAt, double.negativeInfinity, reason: 'not hit yet');
    strikeOnce(g, orc); // the blow lands, then (next tick) it casts
    g.tick(0.05);
    expect(h.heroSkillAt, g.t);
    expect((g.effectOn(h, Status.block)!.n, g.effectK(h, Status.block)), (parryK.blows, parryK.answer));
    final hp = h.hp;
    for (var i = 0; i < parryK.blows; i++) {
      strikeOnce(g, orc);
    }
    expect(h.hp, hp);
    expect(orc.hp, closeTo(orc.maxHp - parryK.blows * h.stats.dmg * parryK.answer, 1e-9));
    strikeOnce(g, orc);
    expect(h.hp, closeTo(hp - orc.stats.dmg, 1e-9)); // the fourth lands

    final (s, sh) = heroCaster(HeroSkill.parry);
    foeAt(s, 'skeleton_archer', sh.pos + Point(sh.stats.range, 0));
    sh.hurtAt = s.t;
    s.tick(0.05);
    expect(sh.heroSkillAt, double.negativeInfinity, reason: 'a shot is never blocked');
  });

  test('Duel of Honour: the highest-ranked foe within 2 tiles fights only the knight for 8 s: 1.5x from it, 30% less to it', () {
    final (g, h) = heroCaster(HeroSkill.duel);
    foeAt(g, 'orc', h.pos + const Point(0, -14)); // a normal one: no duel
    g.tick(0.05);
    expect(h.heroSkillAt, double.negativeInfinity);
    final elite = foeAt(g, 'elite_orc', h.pos + const Point(0, 14), Tier.elite); // reaches 14
    final mini = foeAt(g, 'orc', h.pos + const Point(12, 0), Tier.miniBoss); // the knight's nearest
    mini.bossSkillAt = double.infinity; // its mini-boss skill (Headbutt, boss_skills.dart) kept out of this
    g.marching = true;
    g.tick(0.05);
    expect(h.heroSkillAt, double.negativeInfinity, reason: 'it holds monsters: never during a march');
    g.marching = false;
    g.tick(0.05);
    expect(h.heroSkillAt, g.t);
    expect(g.effectOn(mini, Status.taunt)!.by, h); // the mini boss, over the elite
    expect(g.under(elite, Status.taunt), isFalse);
    expect((g.effectOn(h, Status.duel)!.by, g.effectK(h, Status.duel)), (mini, duelK.might));
    expect(g.effectOn(h, Status.duel)!.until, g.t + duelK.time);

    h.cd = 0;
    g.tick(0.05);
    h.cd = hold;
    expect(mini.hp, closeTo(mini.maxHp - hitTaken(h.stats.dmg * duelK.might, mini.stats.def), 1e-9));
    final hp = h.hp, cut = hitTaken(mini.stats.dmg, h.stats.def) * (1 - duelK.cut);
    strikeOnce(g, mini);
    expect(h.hp, closeTo(hp - cut, 1e-9));
    strikeOnce(g, elite);
    expect(h.hp, closeTo(hp - cut - hitTaken(elite.stats.dmg, h.stats.def), 1e-9)); // not in the duel: all of it
  });

  test('Shared Wounds: above half its HP, the knight takes half the blows of a troop near below 30% that was just hit, for 6 s', () {
    final (g, h) = heroCaster(HeroSkill.shareWounds);
    final ally = idle(g, 'soldier', 2, 5)..hp = 20;
    final orc = foeAt(g, 'orc', ally.pos + const Point(12, 0));
    g.tick(0.05);
    expect(h.heroSkillAt, double.negativeInfinity, reason: 'not hit lately');
    ally.hurtAt = g.t;
    h.hp = h.maxHp * shareWoundsK.above;
    g.tick(0.05);
    expect(h.heroSkillAt, double.negativeInfinity, reason: 'the knight is hurt itself');
    h.hp = h.maxHp.toDouble();
    g.tick(0.05);
    expect(h.heroSkillAt, g.t);
    expect((g.effectOn(ally, Status.link)!.by, g.effectK(ally, Status.link)), (h, shareWoundsK.share));
    strikeOnce(g, orc);
    expect(ally.hp, closeTo(20 - orc.stats.dmg * shareWoundsK.share, 1e-9));
    expect(h.hp, closeTo(h.maxHp - orc.stats.dmg * shareWoundsK.share, 1e-9));
  });

  test('Whirlwind: with a foe near (it waited for 3 before decisions-log 298), 4 cuts 0.5 s apart hit each for 0.7x; its own attacks wait meanwhile', () {
    final (g, h) = heroCaster(HeroSkill.whirlwind);
    final r = h.stats.range; // in its reach, so it stands still
    foeAt(g, 'orc', h.pos + const Point(250, 0)); // keeps the wave on, far off
    g.tick(0.05);
    expect(h.heroSkillAt, double.negativeInfinity, reason: 'none near');
    final foes = [foeAt(g, 'orc', h.pos + Point(r, 0)), foeAt(g, 'orc', h.pos + Point(0, r)), foeAt(g, 'orc', h.pos + Point(0, -r))];
    h.cd = 0;
    g.tick(0.05);
    expect(h.heroSkillAt, g.t);
    expect(h.cd, whirlwindK.hits * whirlwindK.gap);
    final cut = h.stats.dmg * whirlwindK.hit;
    for (final o in foes) {
      expect(o.hp, closeTo(o.maxHp - cut, 1e-9));
    }
    runFor(g, (whirlwindK.hits - 1) * whirlwindK.gap);
    for (final o in foes) {
      expect(o.hp, closeTo(o.maxHp - whirlwindK.hits * cut, 1e-9)); // and no other blow
    }
  });

  test('Veil of Light: the most hurt troop in reach below 50% that was just hit gets a veil of 4x the heal for 8 s', () {
    final (g, h) = heroCaster(HeroSkill.lightVeil);
    final a = idle(g, 'soldier', 4, 3)..hp = 40, b = idle(g, 'knight', 4, 5)..hp = 30;
    foeAt(g, 'orc', const Point(300, 10));
    g.tick(0.05);
    expect(h.heroSkillAt, double.negativeInfinity, reason: 'not hit lately');
    a.hurtAt = b.hurtAt = g.t;
    g.tick(0.05);
    expect(h.heroSkillAt, g.t);
    expect(g.effectK(b, Status.absorb), h.stats.dmg * lightVeilK.soak); // its heal is its dmg
    expect(g.effectOn(b, Status.absorb)!.until, g.t + lightVeilK.time);
    expect(g.under(a, Status.absorb), isFalse);
  });

  test('Giant\'s Rage: with a foe near (or hurt with one in reach; it waited for 3 near before decisions-log 298) +50% max HP and 1.5x splash for 8 s, then its HP is only capped', () {
    final (g, h) = heroCaster(HeroSkill.giantRage);
    final r = h.stats.range, hp = h.maxHp, splash = h.stats.splash;
    foeAt(g, 'orc', h.pos + const Point(250, 0)); // keeps the wave on, far off
    g.tick(0.05);
    expect(h.heroSkillAt, double.negativeInfinity, reason: 'none near, at full health');
    foeAt(g, 'orc', h.pos + Point(r, 0));
    g.tick(0.05);
    expect(h.heroSkillAt, g.t);
    expect((h.maxHp, h.hp, h.stats.splash), ((hp * giantRageK.hp).round(), (hp * giantRageK.hp).roundToDouble(), splash * giantRageK.splash));
    runFor(g, giantRageK.time + 0.1);
    expect((h.maxHp, h.hp, h.stats.splash), (hp, hp.toDouble(), splash));

    final (k, kh) = heroCaster(HeroSkill.giantRage);
    foeAt(k, 'orc', kh.pos + Point(kh.stats.range, 0));
    final hurt = kh.hp = kh.maxHp * giantRageK.below - 1;
    k.tick(0.05);
    expect(kh.heroSkillAt, k.t);
    expect(kh.hp, closeTo(hurt + hp * (giantRageK.hp - 1), 1e-9)); // gains what it grew
  });

  test('Mana Shield: with a foe within 2 tiles, or just hit, what it takes drains its MP first for 8 s', () {
    final (g, h) = heroCaster(HeroSkill.manaShield);
    foeAt(g, 'orc', h.pos + const Point(60, 0)); // in its range, not near
    g.tick(0.05);
    expect(h.heroSkillAt, double.negativeInfinity);
    h.hurtAt = g.t;
    g.tick(0.05);
    expect(h.heroSkillAt, g.t);
    expect(g.effectOn(h, Status.manaShield)!.until, g.t + manaShieldK.time);

    final (n, nh) = heroCaster(HeroSkill.manaShield);
    foeAt(n, 'orc', nh.pos + const Point(30, 0));
    n.tick(0.05);
    expect(n.under(nh, Status.manaShield), isTrue);
  });

  test('Holy Taunt: a troop near hurt and just hit, or a foe near fighting others (decisions-log 298; below 40%, or 3): monsters near turn on it for 5 s, and it takes 25% less', () {
    final (g, h) = heroCaster(HeroSkill.holyTaunt);
    final ally = idle(g, 'soldier', 4, 3);
    final orcs = [foeAt(g, 'orc', ally.pos + const Point(12, 0)), foeAt(g, 'orc', ally.pos + const Point(0, 12))];
    final healer = foeAt(g, necroHealer, ally.pos + const Point(0, -12)), raising = foeAt(g, boss, h.pos + const Point(0, 30)); // busy
    g.tick(0.05);
    expect(h.heroSkillAt, double.negativeInfinity, reason: 'none fight, and the ally is well');
    ally
      ..hp = ally.maxHp * holyTauntK.below - 1
      ..hurtAt = g.t;
    g.tick(0.05);
    expect(h.heroSkillAt, g.t);
    for (final o in orcs) {
      expect(g.effectOn(o, Status.taunt)!.by, h);
    }
    expect((g.under(healer, Status.taunt), g.under(raising, Status.taunt)), (false, false));
    expect((h.guardCut, h.guardUntil), (holyTauntK.cut, g.t + holyTauntK.time));

    final (c, ch) = heroCaster(HeroSkill.holyTaunt);
    final other = idle(c, 'soldier', 4, 3);
    final fighting = [foeAt(c, 'orc', other.pos + const Point(12, 0))..attackedAt = c.t];
    c.tick(0.05);
    expect(ch.heroSkillAt, c.t, reason: 'one fights the soldier');
    expect(fighting.every((o) => c.effectOn(o, Status.taunt)?.by == ch), isTrue);
  });

  test('Bastion of Faith: a boss or mini boss in reach, or hurt with 2 in reach: no blow takes over 8% of its HP for 5 s, nothing shoves it', () {
    final (g, h) = heroCaster(HeroSkill.bastion);
    final r = h.stats.range;
    foeAt(g, 'orc', h.pos + Point(r, 0));
    foeAt(g, 'orc', h.pos + Point(0, r));
    g.tick(0.05);
    expect(h.heroSkillAt, double.negativeInfinity, reason: 'at full health');
    h.hp = h.maxHp * bastionK.below - 1;
    g.tick(0.05);
    expect(h.heroSkillAt, g.t);
    expect((g.effectK(h, Status.cap), g.under(h, Status.noShove)), (bastionK.cap, true));
    expect(g.effectOn(h, Status.cap)!.until, g.t + bastionK.time);

    final (m, mh) = heroCaster(HeroSkill.bastion);
    m.monsterSkills = false; // its plain blow, not Maul (#59 2b)
    final bear = foeAt(m, 'werebear', mh.pos + Point(mh.stats.range, 0), Tier.miniBoss);
    m.tick(0.05);
    expect(mh.heroSkillAt, m.t, reason: 'a mini boss in reach');
    expect(hitTaken(bear.stats.dmg, mh.stats.def), greaterThan(mh.maxHp * bastionK.cap));
    strikeOnce(m, bear);
    expect(mh.hp, closeTo(mh.maxHp * (1 - bastionK.cap), 1e-9));
  });
}
