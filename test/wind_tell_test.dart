// A monster skill's wind-up tell (lib/skills.dart [windTells], lib/monster_skills.dart [MonsterSkills.windTargetsOf];
// docs/ui-hud.md "A monster's skill"): every skill has one, an area's circle is as wide as the skill's reach, the
// marked troops are the ones the cast lands on, and asking who they are changes nothing in the game. The drawing
// itself, every skill at all three ranks, is troop_skill_fx_test.dart's last test.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hero_skill_helpers.dart';

/// A wave on (nothing left to spawn), the troops' skills off, and a monster of [type] and [tier] at (250, 60) that
/// never strikes, summons nor walks: what it does is its skills' doing. [skill]'s own clock is ready and the
/// monster's other recurring skill waits, so [skill] is the one it begins.
(Game, Unit) casting(MonsterSkill skill, String type, Tier tier) {
  final g = bareGame()
    ..skills = false
    ..heroSkills = false;
  g
    ..startWave()
    ..queue.clear();
  final u = g.monster(type, tier, const Point(250.0, 60.0))
    ..entered = true
    ..cd = hold
    ..summonCd = hold;
  g
    ..units.add(u)
    ..addEffect(u, Status.slow, hold, k: 0);
  switch (skill.rank) {
    case MonsterRank.signature:
      u.bossSkillAt = g.t;
    case MonsterRank.miniBoss:
      u.skillAt = g.t;
    case MonsterRank.moment:
      u
        ..skillAt = g.t
        ..bossSkillAt = g.t
        ..hp = u.maxHp * 0.4;
  }
  return (g, u);
}

/// A troop of [type] [dx] to the left of monster [u] and [dy] below it, standing and never fighting.
Unit troop(Game g, Unit u, String type, double dx, [double dy = 0]) {
  final o = Unit(Side.troop, type, troopTypes[type]!, u.pos + Point(-dx, dy))
    ..entered = true
    ..busyUntil = hold;
  g.units.add(o);
  return o;
}

/// Ticks until [u] begins [skill]; who its tell marks then; then ticks until it lands.
List<Unit> markedThenLanded(Game g, Unit u, MonsterSkill skill) {
  for (var i = 0; i < 80 && u.winding != skill; i++) {
    g.tick(0.05);
  }
  expect(u.winding, skill, reason: '${u.type} began ${skill.title}');
  final marked = g.windTargetsOf(u);
  for (var i = 0; i < 40 && u.winding != null; i++) {
    g.tick(0.05);
  }
  expect(u.winding, isNull, reason: '${skill.title} landed');
  return marked;
}

/// Runs [g] for [s] more seconds (a leap's bite, a shot's flight, a drain's ticks).
void settle(Game g, [double s = 2.5]) => runFor(g, s);

/// [o] took a blow: it lost HP, or fell.
bool struck(Unit o, double before) => !o.alive || o.hp < before;

void main() {
  test('every monster skill has a wind-up tell; only the two that never wind up (Reassemble, Split) have none', () {
    expect(windTells.keys.toSet(), MonsterSkill.values.toSet());
    for (final s in MonsterSkill.values) {
      final passive = s == MonsterSkill.reassemble || s == MonsterSkill.split;
      expect(windTells[s] == WindTell.none, passive, reason: s.title);
      if (s.wind > 0) expect(windTells[s], isNot(WindTell.none), reason: s.title);
    }
    expect([for (final s in MonsterSkill.values) if (windTells[s] == WindTell.lane) s], [MonsterSkill.trample, MonsterSkill.graveWave]);
  });

  test('an area skill\'s circle is as wide as its reach (its <id>K.reach, Brutal Swing the monster\'s reach); the rest sit at its feet', () {
    final g = bareGame();
    final orc = g.monster('elite_orc', Tier.highElite, const Point(250.0, 60.0));
    final reach = {
      MonsterSkill.warShout: warShoutK.reach,
      MonsterSkill.brutalSwing: orc.stats.range,
      MonsterSkill.bulwark: bulwarkK.reach,
      MonsterSkill.bladeDance: bladeDanceK.reach,
      MonsterSkill.massMend: massMendK.reach,
      MonsterSkill.curseOfFrailty: curseOfFrailtyK.reach,
      MonsterSkill.screech: screechK.reach,
      MonsterSkill.boneShield: boneShieldK.reach,
      MonsterSkill.groundSlam: groundSlamK.reach,
      MonsterSkill.howl: howlK.reach,
      MonsterSkill.earthshaker: earthshakerK.reach,
      MonsterSkill.roar: roarK.reach,
      MonsterSkill.deathNova: deathNovaK.reach,
      MonsterSkill.lastRites: lastRitesK.reach,
    };
    expect({for (final s in MonsterSkill.values) if (windTells[s] == WindTell.area) s}, reach.keys.toSet());
    for (final MapEntry(key: s, value: r) in reach.entries) {
      expect(windReachOf(orc, s), r, reason: s.title);
    }
    final feet = windReachOf(orc, MonsterSkill.maul);
    for (final s in MonsterSkill.values.where((s) => windTells[s] != WindTell.area)) {
      expect(windReachOf(orc, s), feet, reason: s.title);
    }
    expect(windTellAlpha.from, lessThan(windTellAlpha.to));
  });

  group('the marked troops are the ones the cast lands on, with a decoy it passes over', () {
    test('Volley: its 3 nearest troops in range (a 4th further off is not marked and gets no arrow)', () {
      final (g, u) = casting(MonsterSkill.volley, 'skeleton_archer', Tier.highElite);
      final near = [for (final dx in [20.0, 30.0, 40.0]) troop(g, u, 'soldier', dx)];
      final far = troop(g, u, 'soldier', u.stats.range - 2);
      final marked = markedThenLanded(g, u, MonsterSkill.volley);
      expect(marked.toSet(), near.toSet());
      expect({for (final s in g.shots) s.target}, near.toSet());
      expect(marked, isNot(contains(far)));
    });

    test('a mini boss\'s Volley marks its 5 arrows\' troops: every troop in range when there are fewer', () {
      final (g, u) = casting(MonsterSkill.volley, 'skeleton_archer', Tier.miniBoss);
      final all = [for (final dx in [20.0, 30.0, 40.0]) troop(g, u, 'archer', dx)];
      final marked = markedThenLanded(g, u, MonsterSkill.volley);
      expect(marked.toSet(), all.toSet());
      expect({for (final s in g.shots) s.target}, all.toSet());
    });

    test('Sticky Glob: the nearest back-line troop, not a nearer melee one nor a further archer', () {
      final (g, u) = casting(MonsterSkill.stickyGlob, 'slime', Tier.highElite);
      troop(g, u, 'soldier', 15);
      final aim = troop(g, u, 'archer', 30), decoy = troop(g, u, 'archer', 50);
      final marked = markedThenLanded(g, u, MonsterSkill.stickyGlob);
      expect(marked, [aim]);
      expect(g.shots.single.target, aim);
      expect(decoy, isNot(isIn(marked)));
    });

    for (final (skill, type, tier) in [
      (MonsterSkill.swoop, 'bat', Tier.highElite),
      (MonsterSkill.spearThrow, 'orc_rider', Tier.miniBoss),
    ]) {
      test('${skill.title}: the nearest back-line troop it can reach; the further one is untouched', () {
        final (g, u) = casting(skill, type, tier);
        final aim = troop(g, u, 'archer', 30), decoy = troop(g, u, 'archer', 55, 6);
        final (hp, decoyHp) = (aim.hp, decoy.hp);
        final marked = markedThenLanded(g, u, skill);
        expect(marked, [aim]);
        settle(g);
        expect(struck(aim, hp), isTrue);
        expect(struck(decoy, decoyHp), isFalse);
      });
    }

    test('Pounce: the troop with the least of its HP left; a less hurt one nearer is untouched', () {
      final (g, u) = casting(MonsterSkill.pounce, 'werewolf', Tier.highElite);
      final decoy = troop(g, u, 'soldier', 25)..hp *= 0.45, aim = troop(g, u, 'soldier', 45, 8)..hp *= 0.2;
      final (hp, decoyHp) = (aim.hp, decoy.hp);
      final marked = markedThenLanded(g, u, MonsterSkill.pounce);
      expect(marked, [aim]);
      settle(g);
      expect(struck(aim, hp), isTrue);
      expect(struck(decoy, decoyHp), isFalse);
    });

    test('Trample (a lane): the back-line troop it charges, not the nearer soldier in its way', () {
      final (g, u) = casting(MonsterSkill.trample, 'orc_rider', Tier.highElite);
      troop(g, u, 'soldier', 40, 20);
      final aim = troop(g, u, 'archer', 60);
      final marked = markedThenLanded(g, u, MonsterSkill.trample);
      expect(marked, [aim]);
      expect((u.move! as Charge).target, aim);
    });

    for (final (skill, type, tier) in [
      (MonsterSkill.maul, 'werebear', Tier.highElite),
      (MonsterSkill.headbutt, 'orc', Tier.miniBoss),
      (MonsterSkill.barbedArrow, 'skeleton_archer', Tier.miniBoss),
      (MonsterSkill.boneBash, 'armored_skeleton', Tier.miniBoss),
      (MonsterSkill.skullCrusher, 'elite_orc', Tier.boss),
    ]) {
      test('${skill.title}: the nearest troop in its reach; the further one in reach is untouched', () {
        final (g, u) = casting(skill, type, tier);
        final r = u.stats.range;
        final aim = troop(g, u, 'soldier', 0.4 * r), decoy = troop(g, u, 'soldier', 0.7 * r, 0.5 * r);
        final (hp, decoyHp) = (aim.hp, decoy.hp);
        final marked = markedThenLanded(g, u, skill);
        expect(marked, [aim]);
        settle(g);
        expect(struck(aim, hp), isTrue);
        expect(struck(decoy, decoyHp), isFalse);
      });
    }

    test('Soul Drain: the troop with the most HP within its reach; the weaker one is untouched', () {
      final (g, u) = casting(MonsterSkill.soulDrain, boss, Tier.miniBoss);
      final decoy = troop(g, u, 'soldier', 20)..hp *= 0.5, aim = troop(g, u, 'soldier', 40, 10);
      final (hp, decoyHp) = (aim.hp, decoy.hp);
      final marked = markedThenLanded(g, u, MonsterSkill.soulDrain);
      expect(marked, [aim]);
      expect(g.beams.single.follow, [u, aim]);
      settle(g);
      expect(struck(aim, hp), isTrue);
      expect(struck(decoy, decoyHp), isFalse);
    });

    test('Unholy Ward: the most hurt monster struck lately (a green marker), which the soak goes on', () {
      final (g, u) = casting(MonsterSkill.unholyWard, necroHealer, Tier.miniBoss);
      Unit ally(double dx, double share) => foeAt(g, 'orc', u.pos + Point(-dx, 4))
        ..hp *= share
        ..hurtBefore = g.t + 0.5;
      final decoy = ally(10, 0.6), aim = ally(20, 0.3);
      final marked = markedThenLanded(g, u, MonsterSkill.unholyWard);
      expect(marked, [aim]);
      expect(g.under(aim, Status.absorb), isTrue);
      expect(g.under(decoy, Status.absorb), isFalse);
    });

    test('Grave Wave (a lane): the nearest troop, which its line runs at', () {
      final (g, u) = casting(MonsterSkill.graveWave, 'greatsword_skeleton', Tier.boss);
      final aim = troop(g, u, 'soldier', 50, 20);
      troop(g, u, 'archer', 70, -10);
      final marked = markedThenLanded(g, u, MonsterSkill.graveWave);
      expect(marked, [aim]);
      final line = g.lineShots.single, to = aim.pos - u.pos;
      expect(line.dir.x, closeTo(to.x / to.magnitude, 1e-9));
      expect(line.dir.y, closeTo(to.y / to.magnitude, 1e-9));
    });

    test('an area or self skill marks no one, nor a monster winding up nothing', () {
      final (g, u) = casting(MonsterSkill.warShout, 'orc', Tier.highElite);
      troop(g, u, 'soldier', 10);
      expect(g.windTargetsOf(u), isEmpty);
      u
        ..winding = MonsterSkill.earthshaker
        ..windUntil = g.t + 1;
      expect(g.windTargetsOf(u), isEmpty);
      u.winding = MonsterSkill.rally;
      expect(g.windTargetsOf(u), isEmpty);
    });
  });

  test('asking who a wind-up marks changes nothing: two runs of the w86 save from the same seeds, one asking every tick, are the same',
      () {
    final save = jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>;
    String digest(Game g) => [
          't ${g.t} gold ${g.gold} lives ${g.lives} kills ${g.kills} score ${g.score} log ${g.log.entries.length}',
          for (final u in g.units) '${u.side.name} ${u.type} ${u.tier.name} ${u.alive} ${u.hp} ${u.mp} ${u.pos} ${u.winding}',
        ].join('\n');
    (String, int) run({required bool ask}) {
      final g = Game.fromJson(save, Random(5), Random(105), Random(305))
        ..loot = Random(205)
        ..slots = Random(405)
        ..draft = Random(505)
        ..startWave();
      var marked = 0;
      for (var i = 0; i < 30 * 70 && g.waveActive && !g.over; i++) {
        g.tick(1 / 30);
        if (!ask) continue;
        for (final u in g.enemies) {
          if (u.winding case final s?) {
            marked += g.windTargetsOf(u).length;
            windReachOf(u, s);
          }
        }
      }
      return (digest(g), marked);
    }

    final (plain, _) = run(ask: false);
    final (asked, marked) = run(ask: true);
    expect(marked, greaterThan(0), reason: 'the wave\'s wind-ups marked someone');
    expect(asked, plain);
  });
}
