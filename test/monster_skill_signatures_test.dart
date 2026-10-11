// Monster skills, branch 2b (#59; lib/monster_skill_signatures.dart): the skeleton's Reassemble, the werebear's
// Maul and the necromancer's Curse of Frailty, and one cast under one cap (decision 110).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// A wave on (nothing left to spawn), the troops' and Heroes' skills off, and a skeleton of [tier] at [at]
/// that never moves or fights on its own ([hold]).
(Game, Unit) skeletonAt(Tier tier, {Point<double> at = const Point(250.0, 60.0)}) {
  final g = bareGame()
    ..skills = false
    ..heroSkills = false;
  g
    ..startWave()
    ..queue.clear();
  return (g, foeAt(g, 'skeleton', at, tier));
}

/// A wave on (of [wave], nothing left to spawn), the troops' and Heroes' skills off, and a monster of [type] and
/// [tier] at [at] that casts but never strikes on its own ([Unit.cd]) (a copy of monster_skills_test.dart's).
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

/// Ticks until monster [u] has begun its skill and then cast it; fails if it never began.
void landCast(Game g, Unit u) {
  for (var i = 0; i < 40 && u.winding == null; i++) {
    g.tick(0.05);
  }
  expect(u.winding, isNotNull, reason: '${u.type} began its skill');
  for (var i = 0; i < 40 && u.winding != null; i++) {
    g.tick(0.05);
  }
}

/// An archer standing still ([hold]) that the tests fire from.
Unit archerAt(Game g, Point<double> at) {
  final u = Unit(Side.troop, 'archer', troopTypes['archer']!, at)
    ..entered = true
    ..busyUntil = hold;
  g.units.add(u);
  return u;
}

/// [by]'s arrow of [dmg] on [o], landing this tick (not holy).
void arrow(Game g, Unit by, Unit o, double dmg) {
  g.shots.add(Shot.special(by, o, o.pos - const Point(1.0, 0), dmg: dmg, speed: 200));
  g.tick(0.05);
}

void main() {
  test('Reassemble: a skeleton high elite\'s first killing blow drops it into a heap of bones for 2 s instead; its '
      'title pops, nothing but holy damage touches it, then it stands at 30% of its max HP; the next is for good', () {
    final (g, sk) = skeletonAt(Tier.highElite);
    final archer = archerAt(g, const Point(150.0, 60.0));
    final (gold, kills) = (g.gold, g.kills);
    expect(monsterSkillOf(sk), MonsterSkill.reassemble);
    expect((MonsterSkill.reassemble.type, MonsterSkill.reassemble.title), ('skeleton', 'Reassemble'));
    expect(reassembleK, (down: 2.0, stand: 0.3, strong: 0.5));

    final hitAt = g.t;
    arrow(g, archer, sk, sk.hp + 50);
    expect((sk.alive, sk.hp > 0, sk.reassembled), (true, true, true));
    expect(sk.downUntil, closeTo(hitAt + 0.05 + reassembleK.down, 1e-6));
    expect(g.monsterCasts.single, (sk, MonsterSkill.reassemble));
    expect((g.gold, g.kills), (gold, kills)); // not a kill: no gold, no score
    expect(g.log.entries.whereType<MonsterSkillCast>().single.skill, MonsterSkill.reassemble);

    final lying = sk.hp;
    arrow(g, archer, sk, 1000); // a heap of bones: a plain blow passes through
    expect((sk.alive, sk.hp), (true, lying));

    runFor(g, reassembleK.down);
    expect(g.t, greaterThanOrEqualTo(sk.downUntil));
    expect(sk.hp, closeTo(sk.maxHp * reassembleK.stand, 1e-6));

    arrow(g, archer, sk, sk.hp + 50); // once a life
    expect(sk.alive, isFalse);
    expect((g.kills, g.gold > gold), (kills + 1, true));
  });

  test('a troop healer\'s holy light ends a heap of bones for good, and a holy killing blow never lets a skeleton '
      'reassemble', () {
    final (g, sk) = skeletonAt(Tier.highElite);
    final archer = archerAt(g, const Point(150.0, 60.0));
    arrow(g, archer, sk, sk.hp + 50);
    expect(sk.alive, isTrue);
    final priest = Unit(Side.troop, 'priest', troopTypes['priest']!, sk.pos - const Point(40.0, 0))..entered = true;
    g.units.add(priest); // nobody to heal: it smites the weakest undead in range, the heap
    runFor(g, 1);
    expect(sk.alive, isFalse);
    expect(g.kills, 1);

    final (h, sk2) = skeletonAt(Tier.highElite);
    sk2.hp = 1;
    h.units.add(Unit(Side.troop, 'priest', troopTypes['priest']!, sk2.pos - const Point(40.0, 0))..entered = true);
    runFor(h, 1);
    expect((sk2.alive, sk2.reassembled), (false, false));
  });

  test('the troops\' own attacks pass a heap of bones by: a knight beside one goes for the next monster', () {
    final (g, sk) = skeletonAt(Tier.highElite);
    final archer = archerAt(g, const Point(150.0, 60.0));
    arrow(g, archer, sk, sk.hp + 50);
    // The archer only drops the skeleton. Left standing for good ([hold]), it would be the knight's support and hold it
    // on its leash (decisions-log 312): it covers to x 206, the knight may go to 230, where it stands, and the orc's near
    // side is at 236. A real archer walks up and the leash with it; this one never would.
    g.units.remove(archer);
    final orc = foeAt(g, 'orc', sk.pos + const Point(0, 30.0));
    final knight = Unit(Side.troop, 'knight', troopTypes['knight']!, sk.pos - const Point(20.0, 0))..entered = true;
    g.units.add(knight);
    runFor(g, 1.8); // the heap still lies
    expect(g.t, lessThan(sk.downUntil));
    expect(orc.hp, lessThan(orc.maxHp));
  });

  test('a skeleton mini boss stands again at 50%; normal and elite skeletons, raised ones, a hexed one and any '
      'with the monster skills off die at once', () {
    final (g, mini) = skeletonAt(Tier.miniBoss);
    arrow(g, archerAt(g, const Point(150.0, 60.0)), mini, mini.hp + 50);
    runFor(g, reassembleK.down);
    expect(mini.hp, closeTo(mini.maxHp * reassembleK.strong, 1e-6));

    Unit dropped(Tier tier, [void Function(Game, Unit)? setUp]) {
      final (h, sk) = skeletonAt(tier);
      setUp?.call(h, sk);
      arrow(h, archerAt(h, const Point(150.0, 60.0)), sk, sk.hp + 50);
      return sk;
    }

    for (final tier in [Tier.normal, Tier.elite]) {
      expect(dropped(tier).alive, isFalse, reason: '$tier');
    }
    expect(dropped(Tier.highElite, (g, sk) => sk.raisedBy = foeAt(g, boss, const Point(300.0, 60.0), Tier.boss)).alive, isFalse);
    expect(dropped(Tier.highElite, (g, sk) => sk.effects[Status.hex] = Effect(g.t + 5, 0, was: sk.stats)).alive, isFalse);
    expect(dropped(Tier.highElite, (g, _) => g.monsterSkills = false).alive, isFalse);
  });

  test('a cast\'s hits on one troop share the cap (decision 110): a mini boss\'s Blade Dance and Volley take at '
      'most 35% of a troop\'s HP in all, 25% of a Hero\'s', () {
    final (g, sk) = casterAt('greatsword_skeleton', Tier.miniBoss, wave: 60);
    sk.bossSkillAt = double.infinity; // its mini-boss skill (Soul Rend, boss_skills.dart) kept out of this
    final knight = troopAt(g, 'knight', sk.pos - const Point(10.0, 6));
    final hero = troopAt(g, 'knight', sk.pos - const Point(10.0, -6))..hero = true;
    expect(sk.stats.dmg * bladeDanceK.hit, greaterThan(knight.maxHp * monsterSkillCap.troop)); // one cut alone would pass it
    landCast(g, sk);
    runFor(g, bladeDanceK.strong * bladeDanceK.gap); // all 4 cuts
    expect(knight.maxHp - knight.hp, closeTo(knight.maxHp * monsterSkillCap.troop, 1e-6));
    expect(hero.maxHp - hero.hp, closeTo(hero.maxHp * monsterSkillCap.hero, 1e-6));

    final (h, a) = casterAt('skeleton_archer', Tier.miniBoss, wave: 60);
    a.bossSkillAt = double.infinity; // Barbed Arrow kept out
    final archers = [troopAt(h, 'archer', a.pos - const Point(20.0, 0)), troopAt(h, 'archer', a.pos - const Point(40.0, 0))];
    landCast(h, a);
    runFor(h, 1); // 5 arrows: 3 on the nearest, 2 on the other, all landed
    expect(h.shots, isEmpty);
    for (final o in archers) {
      expect(o.maxHp - o.hp, closeTo(o.maxHp * monsterSkillCap.troop, 1e-6));
    }
  });

  test('Maul: with a troop in reach the werebear winds up 0.8 s, then hits the nearest 2.5x (a mini boss 3x; the cap '
      'holds) and knocks it back a tile (a Hero half)', () {
    expect((MonsterSkill.maul.type, MonsterSkill.maul.title, MonsterSkill.maul.cooldown, MonsterSkill.maul.wind), ('werebear', 'Maul', 12.0, 0.8));
    expect(maulK, (hit: 2.5, strong: 3.0, shove: tile));
    final (g, bear) = casterAt('werebear', Tier.highElite);
    final knight = troopAt(g, 'knight', bear.pos - const Point(10.0, 0))
      ..maxHp = 1000
      ..hp = 1000;
    final x0 = knight.pos.x;
    landCast(g, bear);
    expect(knight.maxHp - knight.hp, closeTo(bear.stats.dmg * maulK.hit, 1e-6));
    runFor(g, 0.5); // the slide
    expect(x0 - knight.pos.x, closeTo(maulK.shove, 1.5)); // the slide, and a step after it

    final (h, mini) = casterAt('werebear', Tier.miniBoss, wave: 60);
    final hero = troopAt(h, 'knight', mini.pos - const Point(10.0, 0))..hero = true;
    final hx0 = hero.pos.x;
    landCast(h, mini);
    expect(mini.stats.dmg * maulK.strong, greaterThan(hero.maxHp * monsterSkillCap.hero));
    expect(hero.maxHp - hero.hp, closeTo(hero.maxHp * monsterSkillCap.hero, 1e-6)); // the cap holds
    runFor(h, 0.5);
    expect(hx0 - hero.pos.x, closeTo(maulK.shove * heroShoveShare, 1.5));

    final (k, alone) = casterAt('werebear', Tier.highElite);
    troopAt(k, 'knight', alone.pos - const Point(60.0, 0)); // out of reach, and still out of it after a second's walk
    runFor(k, 1);
    expect(k.monsterCasts, isEmpty);
  });

  test('Curse of Frailty: with 3 troops within 3 tiles the necromancer curses them all to take 1.15x from monsters '
      'for 5 s (a mini boss or boss 1.2x); with 2 it doesn\'t', () {
    expect((MonsterSkill.curseOfFrailty.type, MonsterSkill.curseOfFrailty.title), (boss, 'Curse of Frailty'));
    expect(curseOfFrailtyK, (crowd: 3, reach: 3 * tile, time: 5.0, taken: 1.15, strong: 1.2));
    (Game, Unit, List<Unit>) cursing(Tier tier, int troops) {
      final (g, n) = casterAt(boss, tier);
      n.mp = 0; // no summons meanwhile
      return (g, n, [for (var i = 0; i < troops; i++) troopAt(g, 'knight', n.pos - Point(20.0 + 8 * i, 0))]);
    }

    final (g, necro, three) = cursing(Tier.highElite, 3);
    landCast(g, necro);
    for (final o in three) {
      final e = g.effectOn(o, Status.vulnerable)!;
      expect((e.k, e.by), (curseOfFrailtyK.taken, necro));
      expect(e.until, closeTo(g.t + curseOfFrailtyK.time, 0.06));
    }
    final (h, necroBoss, bossTroops) = cursing(Tier.boss, 3);
    necroBoss.bossSkillAt = double.infinity; // Soul Drain kept out (its moment waits for half its HP)
    landCast(h, necroBoss);
    expect(bossTroops.map((o) => h.effectK(o, Status.vulnerable)), everyElement(curseOfFrailtyK.strong));

    final (k, _, two) = cursing(Tier.highElite, 2);
    runFor(k, 1);
    expect(k.monsterCasts, isEmpty);
    expect(two.any((o) => k.under(o, Status.vulnerable)), isFalse);
  });

  test('the looks the prep branch brought: Bulwark\'s guard ring in orange, War Shout\'s red ring bursting out', () {
    final (g, orc) = casterAt('armored_orc', Tier.highElite);
    troopAt(g, 'knight', orc.pos - const Point(10.0, 6));
    troopAt(g, 'knight', orc.pos - const Point(10.0, -6));
    landCast(g, orc);
    expect((orc.guardLook, g.t < orc.guardUntil), (RingLook.orange, true));

    final (h, shouter) = casterAt('orc', Tier.highElite);
    for (final dy in [-10.0, 0.0, 10.0]) {
      foeAt(h, 'orc', shouter.pos + Point(4.0, dy)).attackedAt = h.t;
    }
    landCast(h, shouter);
    final ring = h.rings.single;
    expect((ring.at, ring.radius, ring.look), (shouter.pos, warShoutK.reach, RingLook.red));
  });
}
