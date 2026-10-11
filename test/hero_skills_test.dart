// Heroes' own skills (#48, branch 1): the roll, save and load, when they cast, the effect store's hooks and the
// 18 simple skills. docs/units-and-combat.md, "Hero skills".
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';
import 'hud_font.dart';

void main() {
  /// A troop of [type] at cell ([c], [r]) that never strikes on its own.
  Unit idle(Game g, String type, int c, int r) => placeNow(g, type, c, r)..cd = hold;

  /// Monster [m] strikes its nearest foe once, now (it must be in its reach): one tick.
  void strikeOnce(Game g, Unit m) {
    m
      ..busyUntil = double.negativeInfinity
      ..cd = 0;
    g.tick(0.05);
    m.busyUntil = hold;
  }

  group('the skills', () {
    test('every troop type has five, each with a name, a line, a mark, an MP cost it can pay from full and a cooldown', () {
      for (final type in troopTypes.keys) {
        final mine = HeroSkill.values.where((s) => s.type == type).toList();
        expect(mine, hasLength(5), reason: type);
        for (final s in mine) {
          expect(s.cost, inInclusiveRange(1, troopTypes[type]!.mp), reason: s.name);
          expect(s.cooldown, greaterThan(0), reason: s.name);
          expect((s.title.isNotEmpty, s.desc.isNotEmpty), (true, true), reason: s.name);
        }
      }
      expect(HeroSkill.values.map((s) => s.title).toSet(), hasLength(45)); // no two alike
    });

    test('names and lines are in English and use only what the pixel font draws', () {
      final font = fontChars();
      for (final s in HeroSkill.values) {
        for (final text in [s.title, s.desc]) {
          expect(text.runes.where((c) => !font.contains(c)), isEmpty, reason: '${s.name}: $text');
          expect(text.codeUnits.every((c) => c >= 32 && c < 127), isTrue, reason: '${s.name}: $text');
        }
      }
    });

    test('only built skills are rolled, and every type has at least one', () {
      expect(HeroSkill.values.where((s) => s.built).length, greaterThanOrEqualTo(18)); // more with each branch
      for (final type in troopTypes.keys) {
        final pool = heroSkillPool(type);
        expect(pool, isNotEmpty, reason: type);
        expect(pool, [for (final s in HeroSkill.values) if (s.type == type && s.built) s], reason: type);
      }
    });
  });

  group('the roll, save and load', () {
    test('a new Hero rolls its skill with the heroes dice, right after its attributes', () {
      for (final seed in [1, 2, 3, 4]) {
        for (final type in ['soldier', 'priest', 'knight_templar']) {
          final g = bareGame()..heroes = Random(seed), dice = Random(seed);
          idle(g, type, 2, 3);
          g
            ..wave = heroEvery - 1
            ..startWave()
            ..queue.clear();
          foeAt(g, 'slime', const Point(200.0, 60.0)).gone = true; // wave 10 won at once: the Hero comes (#47)
          g.tick(0);
          dice.nextInt(1); // who: the only troop
          for (var i = 0; i < heroStatCount; i++) {
            dice.nextInt(heroPoolOf(type).length - i); // its attributes
          }
          final pool = heroSkillPool(type);
          expect(g.troops.single.heroSkill, pool[dice.nextInt(pool.length)], reason: '$type seed $seed');
        }
      }
    });

    test('the skill is saved by its id and comes back; an old Hero, or an unknown id, rolls one on load', () {
      final (g, h) = heroCaster(HeroSkill.execute);
      final j = g.toJson();
      final troop = (j['troops'] as List).single as Map<String, Object?>;
      expect(troop['heroSkill'], 'execute');
      expect(Game.fromJson(j).troops.single.heroSkill, HeroSkill.execute);

      for (final saved in [null, 'nope']) {
        final old = {...troop}..remove('heroSkill');
        if (saved != null) old['heroSkill'] = saved;
        final loaded = Game.fromJson({...j, 'troops': [old]}).troops.single;
        expect(heroSkillPool(h.type), contains(loaded.heroSkill), reason: '$saved');
      }
      // A troop that isn't a Hero has none, whatever the save says.
      final plain = {...troop}..remove('hero');
      expect(Game.fromJson({...j, 'troops': [plain]}).troops.single.heroSkill, isNull);
    });
  });

  group('when a Hero skill casts', () {
    test('it pays the MP, waits out its cooldown, and tells the UI; never with Hero skills off', () {
      final (g, h) = heroCaster(HeroSkill.judgement);
      foeAt(g, 'skeleton', h.pos + Point(h.stats.range, 0)).hp = 1e6; // never dies
      g.tick(0.05);
      final first = g.t, s = HeroSkill.judgement;
      expect((h.heroSkillAt, h.mp), (first, h.stats.mp - s.cost));
      expect(g.heroCasts, [(h, s)]);
      while (h.heroSkillAt == first && g.t - first < s.cooldown + 1) {
        h.mp = h.stats.mp.toDouble();
        g.tick(0.05);
      }
      expect(h.heroSkillAt - first, inInclusiveRange(s.cooldown * heroCdK, s.cooldown * heroCdK + 0.05)); // decisions-log 298

      final (off, oh) = heroCaster(HeroSkill.judgement);
      off.heroSkills = false;
      foeAt(off, 'skeleton', oh.pos + Point(oh.stats.range, 0));
      off.tick(0.05);
      expect((oh.heroSkillAt, oh.mp, off.heroCasts.isEmpty), (double.negativeInfinity, oh.stats.mp, true));
    });

    test('it is ready again at every wave\'s start, and never cast between waves', () {
      final (g, h) = heroCaster(HeroSkill.judgement);
      final foe = foeAt(g, 'skeleton', h.pos + Point(h.stats.range, 0));
      g.tick(0.05);
      expect(h.heroSkillAt, g.t);
      foe.gone = true;
      g.tick(0.05); // won
      expect(g.waveActive, isFalse);
      g
        ..startWave()
        ..queue.clear();
      expect(h.heroSkillAt, double.negativeInfinity);
    });

    test('while it is ready and wanted but short of MP, the #10 skill waits and keeps the MP for it', () {
      Unit priestWith(bool undead) {
        final (g, p) = heroCaster(HeroSkill.holyNova);
        g.skills = true;
        final hurt = [for (final r in [3, 4]) idle(g, 'soldier', 3, r)..hp = 10]; // two hurt side by side: Healing Prayer wants them
        expect(hurt.length, prayer.crowd);
        for (var i = 0; i < holyNovaK.crowd; i++) {
          foeAt(g, undead ? 'skeleton' : 'orc', p.pos + Point(40.0, i * 8.0));
        }
        p.mp = HeroSkill.holyNova.cost - 1.0; // enough for Healing Prayer (15), not for Holy Nova (40)
        g.tick(0.05);
        return p;
      }

      expect(priestWith(true).skillAt, double.negativeInfinity, reason: 'Holy Nova wanted: it saves up');
      expect(priestWith(false).skillAt, isNot(double.negativeInfinity), reason: 'Holy Nova not wanted: Healing Prayer as usual');
    });

    test('while a stalled wave marches only the skills that don\'t hold monsters cast', () {
      for (final (skill, type, holds) in [(HeroSkill.quake, 'orc', true), (HeroSkill.judgement, 'skeleton', false)]) {
        final (g, h) = heroCaster(skill);
        for (var i = 0; i < quakeK.crowd; i++) {
          foeAt(g, type, h.pos + Point(h.stats.range, i * 4.0));
        }
        g.marching = true;
        g.tick(0.05);
        expect(skill.holds, holds);
        expect(h.heroSkillAt == g.t, !holds, reason: skill.name);
      }
    });

    test('the skills that wait out the march are the 13 that move, stop, slow or turn monsters; Crippling Shot, Frost Storm, Curse and Holy Taunt too', () {
      // "Nothing that moves or holds monsters casts during a stalled wave's march" (decisions-log 76). The
      // moves (hero_moves_test.dart), Earthquake (above) and Duel of Honour (hero_guard_test.dart) are checked
      // where they're built; here the rest of the set.
      expect({for (final s in HeroSkill.values) if (s.holds) s}, {
        HeroSkill.shieldBash, HeroSkill.duel, HeroSkill.rescueLeap, HeroSkill.crippleShot, HeroSkill.charge, //
        HeroSkill.spearWall, HeroSkill.sweep, HeroSkill.hook, HeroSkill.quake, HeroSkill.frostStorm, HeroSkill.curse,
        HeroSkill.slimeHex, HeroSkill.holyTaunt,
      });
      final scenes = <HeroSkill, void Function(Game, Unit)>{
        HeroSkill.crippleShot: (g, h) => foeAt(g, 'werewolf', h.pos + const Point(60, 8)), // faster than the archer
        HeroSkill.frostStorm: (g, h) {
          for (final d in const [Point(0.0, 0.0), Point(14.0, 0.0), Point(0.0, 14.0), Point(-10.0, -10.0)]) {
            foeAt(g, 'elite_orc', h.pos + const Point(60, 0) + d); // 4 together
          }
        },
        HeroSkill.curse: (g, h) => foeAt(g, 'elite_orc', h.pos + const Point(50, 10), Tier.elite),
        HeroSkill.holyTaunt: (g, h) {
          final other = idle(g, 'soldier', 4, 3);
          for (final d in const [Point(12.0, 0.0), Point(0.0, 12.0), Point(0.0, -12.0)]) {
            foeAt(g, 'orc', other.pos + d).attackedAt = g.t; // 3 fighting the soldier
          }
        },
      };
      for (final MapEntry(key: skill, value: scene) in scenes.entries) {
        final (g, h) = heroCaster(skill);
        scene(g, h);
        expect(g.wantsHeroSkill(h), isTrue, reason: skill.name);
        g.marching = true;
        g.tick(0.05);
        expect(h.heroSkillAt, double.negativeInfinity, reason: '${skill.name} marching');
        g.marching = false;
        g.tick(0.05);
        expect(h.heroSkillAt, g.t, reason: skill.name);
      }
    });

    test('through a real stall the watchdog marches after stallTime, and a holding skill ready again mid-march waits it out', () {
      final (g, h) = heroCaster(HeroSkill.curse);
      foeAt(g, 'elite_orc', h.pos + const Point(50, 10), Tier.elite); // in range and stuck: the wave makes no progress
      final start = g.t;
      g.tick(0.05);
      final cast = h.heroSkillAt;
      expect(cast, g.t); // ready at the wave's start; a curse takes no HP, so it is no progress either
      while (!g.marching && g.t - start < stallTime + 2) {
        g.tick(0.05);
      }
      expect(g.marching, isTrue);
      expect(g.t - start, inInclusiveRange(stallTime, stallTime + 1));
      final last = h.heroSkillAt; // at heroCdK of its cooldown it may have cursed again before the march (decisions-log 298)
      // The curse has worn off and its cooldown comes round mid-march: wanted, paid for, and it waits.
      runFor(g, last + HeroSkill.curse.cooldown * heroCdK + 5 - g.t);
      expect((g.marching, g.wantsHeroSkill(h), h.mp >= HeroSkill.curse.cost, h.heroSkillAt), (true, true, true, last));
    });
  });

  group('the effect store', () {
    test('a stronger effect of a kind stays until it ends, one as strong is renewed, and each runs out', () {
      final g = bareGame();
      final u = idle(g, 'soldier', 2, 3);
      g.addEffect(u, Status.haste, 5, k: 0.6);
      g.addEffect(u, Status.haste, 9, k: 0.8); // weaker: ignored
      expect((g.effectK(u, Status.haste), g.effectOn(u, Status.haste)!.until), (0.6, g.t + 5));
      g.addEffect(u, Status.haste, 9, k: 0.6); // as strong: renewed
      expect(g.effectOn(u, Status.haste)!.until, g.t + 9);
      runFor(g, 9.05);
      expect((g.under(u, Status.haste), g.effectK(u, Status.haste), u.effects.isEmpty), (false, 1.0, true));
    });

    test('a stat effect (range) refits the troop as it starts and when it runs out', () {
      final g = bareGame();
      final a = idle(g, 'archer', 2, 3), range = a.stats.range;
      g.addEffect(a, Status.range, 1, k: 1.5);
      expect(a.stats.range, range * 1.5);
      runFor(g, 1.05);
      expect(a.stats.range, range);
    });

    test('when a wave ends every effect ends with it, and what was left for later is dropped', () {
      final (g, h) = heroCaster(HeroSkill.warCry);
      final foe = foeAt(g, 'orc', const Point(250, 60));
      var ran = false;
      g
        ..addEffect(h, Status.range, 30, k: 2)
        ..addEffect(foe, Status.slow, 30, k: 0.5)
        ..later(10, () => ran = true);
      foe.gone = true;
      g.tick(0.05);
      expect(g.waveActive, isFalse);
      expect((h.effects.isEmpty, h.stats.range), (true, g.statsOf('soldier').range));
      runFor(g, 11);
      expect(ran, isFalse);
    });

    test('later runs a function once, after its delay', () {
      final (g, _) = heroCaster(HeroSkill.warCry);
      foeAt(g, 'orc', const Point(250, 60));
      final at = <double>[];
      final start = g.t;
      g.later(0.2, () => at.add(g.t - start));
      runFor(g, 1);
      expect(at.single, closeTo(0.2, 0.051));
    });

    test('haste shortens the pause between attacks (and heals), might raises the damage dealt, vulnerable the damage taken from troops', () {
      final g = bareGame()..skills = false; // its blow alone, no Circle Slash
      final k = placeNow(g, 'knight', 2, 3);
      final foe = foeAt(g, 'orc', k.pos + Point(k.stats.range, 0));
      g
        ..addEffect(k, Status.haste, 5, k: 0.8)
        ..addEffect(k, Status.might, 5, k: 1.5)
        ..addEffect(foe, Status.vulnerable, 5, k: 1.2);
      expect(g.attackEvery(k), closeTo(k.stats.rate * 0.8, 1e-9));
      k.cd = 0;
      g.tick(0.05);
      expect(foe.hp, closeTo(foe.maxHp - k.stats.dmg * 1.5 * 1.2, 1e-9));
      expect(k.cd, closeTo(k.stats.rate * 0.8, 1e-9));
      final p = placeNow(g, 'priest', 0, 3);
      g.addEffect(p, Status.haste, 5, k: 0.8);
      expect(g.attackEvery(p), closeTo(p.stats.rate * 0.8, 1e-9));
    });

    test('weaken cuts what a monster deals; the cap, a veil (absorb) and the MP (mana shield) soak what a troop takes', () {
      (Game, Unit, Unit) fight() {
        final g = bareGame()..skills = false;
        final s = idle(g, 'soldier', 2, 3);
        final orc = foeAt(g, 'orc', s.pos + Point(12, 0));
        foeAt(g, 'orc', const Point(300, 10)); // keeps the wave on
        return (g, s, orc);
      }

      final (g, s, orc) = fight();
      final blow = orc.stats.dmg;
      g.addEffect(orc, Status.weaken, 5, k: 0.6);
      strikeOnce(g, orc);
      expect(s.hp, closeTo(s.maxHp - blow * 0.6, 1e-9));

      final (c, cs, corc) = fight();
      c.addEffect(cs, Status.cap, 5, k: 0.05);
      strikeOnce(c, corc);
      expect(cs.hp, closeTo(cs.maxHp - cs.maxHp * 0.05, 1e-9));

      final (a, au, aorc) = fight();
      a.addEffect(au, Status.absorb, 5, k: 4);
      strikeOnce(a, aorc);
      expect(au.hp, closeTo(au.maxHp - (blow - 4), 1e-9));
      expect(a.under(au, Status.absorb), isFalse); // used up

      final (m, ms, morc) = fight();
      m.addEffect(ms, Status.manaShield, 5);
      ms.mp = 4 - ms.stats.mpRegen * 0.05; // 4 when the blow lands
      strikeOnce(m, morc);
      expect(ms.mp, closeTo(0, 1e-9));
      expect(ms.hp, closeTo(ms.maxHp - (blow - 4), 1e-9));
    });

    test('block stops the next n melee blows, each answered with k times the damage; link passes a share to another troop', () {
      final g = bareGame()..skills = false;
      final s = idle(g, 'soldier', 2, 3), k = idle(g, 'knight', 0, 0);
      final orc = foeAt(g, 'orc', s.pos + Point(12, 0));
      g.addEffect(s, Status.block, 10, k: 1.5, n: 2);
      strikeOnce(g, orc);
      strikeOnce(g, orc);
      expect(s.hp, s.maxHp);
      expect(orc.hp, closeTo(orc.maxHp - 2 * s.stats.dmg * 1.5, 1e-9));
      expect(g.under(s, Status.block), isFalse); // both used
      runFor(g, 1);
      strikeOnce(g, orc);
      expect(s.hp, closeTo(s.maxHp - orc.stats.dmg, 1e-9));

      final h = bareGame()..skills = false;
      final hs = idle(h, 'soldier', 2, 3), hk = idle(h, 'knight', 0, 0);
      final horc = foeAt(h, 'orc', hs.pos + Point(12, 0));
      h.addEffect(hs, Status.link, 6, k: 0.5, by: hk);
      strikeOnce(h, horc);
      expect(hs.hp, closeTo(hs.maxHp - horc.stats.dmg / 2, 1e-9));
      expect(hk.hp, closeTo(hk.maxHp - horc.stats.dmg / 2, 1e-9));
      expect(k.hp, k.maxHp);
    });

    test('lifesteal heals the attacker; reflect sends a share of a melee blow back', () {
      final g = bareGame()..skills = false;
      final k = placeNow(g, 'knight', 2, 3)..hp = 50;
      final foe = foeAt(g, 'orc', k.pos + const Point(12, 0)); // in the reach of both
      g.addEffect(k, Status.lifesteal, 5, k: 0.4);
      k.cd = 0;
      g.tick(0.05);
      expect(k.hp, closeTo(50 + k.stats.dmg * 0.4, 1e-9));

      k.cd = hold;
      g.addEffect(k, Status.reflect, 5, k: 0.6);
      final before = foe.hp;
      strikeOnce(g, foe);
      expect(foe.hp, closeTo(before - foe.stats.dmg * 0.6, 1e-9));
    });

    test('heal gives HP back over time; bleed hurts once a whole second, n times', () {
      final g = bareGame()..skills = false;
      final s = idle(g, 'soldier', 2, 3)..hp = 10;
      final orc = foeAt(g, 'orc', const Point(200, 60));
      g
        ..addEffect(s, Status.heal, 2, k: 5)
        ..addEffect(orc, Status.bleed, 3.5, k: 7, by: s, n: 3);
      runFor(g, 1.0);
      expect(s.hp, closeTo(15, 1e-6));
      expect(orc.hp, orc.maxHp - 7);
      runFor(g, 3.0);
      expect(s.hp, closeTo(20, 1e-6));
      expect(orc.hp, orc.maxHp - 21);
    });

    test('slow makes a monster walk slower, but not while its wave marches', () {
      double walked(bool slow, bool march) {
        final g = bareGame()..skills = false;
        idle(g, 'soldier', 0, 0);
        final m = foeAt(g, 'orc', const Point(250, 100))..busyUntil = double.negativeInfinity;
        if (slow) g.addEffect(m, Status.slow, 5, k: 0.5);
        g.marching = march;
        final x = m.pos.x;
        g.tick(0.05);
        return x - m.pos.x;
      }

      expect(walked(true, false), closeTo(walked(false, false) * 0.5, 1e-6));
      expect(walked(true, true), closeTo(walked(false, true), 1e-6));
    });

    test('taunt turns a monster on the taunter; holdGround keeps a hurt troop from falling back; noShove holds its ground', () {
      final g = bareGame()..skills = false;
      final near = idle(g, 'soldier', 2, 1), far = idle(g, 'knight', 2, 6);
      final m = foeAt(g, 'orc', near.pos + const Point(40, 0))..busyUntil = double.negativeInfinity;
      g.addEffect(m, Status.taunt, 5, by: far);
      g.tick(0.05);
      expect(m.heading.y, greaterThan(0.5)); // down to the knight, not across to the soldier

      for (final hold in [false, true]) {
        final h = bareGame()..skills = false;
        idle(h, 'priest', 0, 3);
        final s = idle(h, 'soldier', 2, 3)..hp = 20;
        foeAt(h, 'orc', const Point(250, 60));
        if (hold) h.addEffect(s, Status.holdGround, 5);
        h.tick(0.05);
        expect(s.retreating, !hold);
      }

      final n = bareGame()..skills = false;
      final s = idle(n, 'soldier', 2, 3);
      foeAt(n, 'orc', s.pos + const Point(4, 0));
      n.addEffect(s, Status.noShove, 5);
      final at = s.pos;
      n.tick(0.05);
      expect(s.pos, at);
    });
  });

  group('the 18 simple Hero skills', () {
    test('War Cry: with a troop near that fought (itself too; it waited for 3 before decisions-log 298), each troop within reach attacks 25% faster for 6 s', () {
      final (g, h) = heroCaster(HeroSkill.warCry);
      final a = idle(g, 'knight', 3, 3), b = idle(g, 'archer', 1, 3), out = idle(g, 'archer', 2, 7);
      foeAt(g, 'orc', const Point(250, 60));
      g.tick(0.05);
      expect(h.heroSkillAt, double.negativeInfinity, reason: 'none fought');
      a.attackedAt = g.t;
      g.tick(0.05);
      expect(h.heroSkillAt, g.t);
      for (final u in [h, a, b]) {
        expect((g.effectK(u, Status.haste), g.effectOn(u, Status.haste)!.until), (warCryK.haste, g.t + warCryK.time), reason: u.type);
      }
      expect(g.under(out, Status.haste), isFalse);
    });

    test('Plunder: with a foe near, for 8 s every monster killed near it pays 50% more gold (rounded up)', () {
      final (g, h) = heroCaster(HeroSkill.plunder);
      final foes = [for (var i = 0; i < 3; i++) foeAt(g, 'orc', h.pos + Point(h.stats.range, i * 6.0 - 6))];
      foes[1].hp = 1; // the nearest
      h.cd = 0; // casts, then strikes the nearest
      final gold = g.gold;
      g.tick(0.05);
      h.cd = hold;
      expect(h.heroSkillAt, g.t);
      final pay = foes[1].stats.cost;
      expect(g.gold, gold + pay + (pay * plunderK.bonus).ceil());
      expect(g.goldPops.single.$2, (pay * plunderK.bonus).ceil());
      runFor(g, plunderK.time + 0.1);
      expect(g.under(h, Status.plunder), isFalse);
    });

    test('Cleave: one 3x blow at a foe in reach (any since decisions-log 298; one worth it first); a kill gives back half the MP', () {
      final (g, h) = heroCaster(HeroSkill.cleave);
      final foe = foeAt(g, 'orc', h.pos + Point(h.stats.range, 0));
      g.tick(0.05);
      expect(h.heroSkillAt, g.t);
      expect(foe.hp, closeTo(foe.maxHp - h.stats.dmg * cleaveK.hit, 1e-9));

      final (w, wh) = heroCaster(HeroSkill.cleave);
      final weak = foeAt(w, 'orc', wh.pos + Point(wh.stats.range, 0))..hp = wh.stats.dmg * cleaveK.hit - 1; // not worth it, but the only one
      w.tick(0.05);
      expect((wh.heroSkillAt, weak.alive), (w.t, false));

      final (k, kh) = heroCaster(HeroSkill.cleave);
      final dies = foeAt(k, 'orc', kh.pos + Point(kh.stats.range, 0))..hp = kh.stats.dmg * cleaveK.hit;
      k.tick(0.05);
      expect(dies.alive, isFalse);
      expect(kh.mp, closeTo(kh.stats.mp - HeroSkill.cleave.cost * (1 - cleaveK.refund), 1e-9)); // it was full
    });

    test('Execute: a foe in reach below 25% dies at once, never the boss or a mini boss', () {
      for (final (tier, dies) in [(Tier.normal, true), (Tier.elite, true), (Tier.miniBoss, false), (Tier.boss, false)]) {
        final (g, h) = heroCaster(HeroSkill.execute);
        final foe = foeAt(g, tier == Tier.boss ? boss : 'orc', h.pos + Point(h.stats.range, 0), tier);
        foe.hp = foe.maxHp * executeK.below - 1;
        g.tick(0.05);
        expect(foe.alive, !dies, reason: tier.name);
      }
      final (g, h) = heroCaster(HeroSkill.execute);
      final foe = foeAt(g, 'orc', h.pos + Point(h.stats.range, 0));
      foe.hp = foe.maxHp * executeK.below + 1;
      g.tick(0.05);
      expect((foe.alive, h.heroSkillAt), (true, double.negativeInfinity));
    });

    test('Bloodlust: hurt with a foe near, it heals 40% of what it deals for 6 s', () {
      final (g, h) = heroCaster(HeroSkill.bloodlust);
      final foe = foeAt(g, 'orc', h.pos + Point(h.stats.range, 0));
      foeAt(g, 'orc', h.pos + const Point(6, 13)); // near, but not so near anything shoves it
      g.tick(0.05);
      expect(h.heroSkillAt, double.negativeInfinity, reason: 'at full health');
      h
        ..hp = 50
        ..cd = 0;
      g.tick(0.05);
      expect(g.effectK(h, Status.lifesteal), bloodlustK.share);
      expect(h.hp, closeTo(50 + h.stats.dmg * bloodlustK.share, 1e-9));
      expect(foe.hp, foe.maxHp - h.stats.dmg);
    });

    test('Deep Wound: a cut, then the foe bleeds its damage every second for 4 s', () {
      final (g, h) = heroCaster(HeroSkill.deepWound);
      final foe = foeAt(g, 'orc', h.pos + Point(h.stats.range, 0));
      g.tick(0.05);
      final d = h.stats.dmg;
      expect(foe.hp, foe.maxHp - d);
      runFor(g, 1.0);
      expect(foe.hp, foe.maxHp - 2 * d);
      runFor(g, 4.0);
      expect(foe.hp, foe.maxHp - 5 * d); // 4 bleeds, then no more
      expect(g.under(foe, Status.bleed), isFalse);
    });

    test('Eagle Eye: a monster that shoots or heals just out of range: +40% range and +30% damage for 8 s', () {
      final (g, h) = heroCaster(HeroSkill.eagleEye);
      final range = h.stats.range;
      foeAt(g, 'orc', h.pos + Point(range * 1.2, 0)); // doesn't shoot
      g.tick(0.05);
      expect(h.heroSkillAt, double.negativeInfinity);
      foeAt(g, 'skeleton_archer', h.pos + Point(range * 1.3, 8));
      g.tick(0.05);
      expect(h.stats.range, closeTo(range * eagleEyeK.range, 1e-9));
      expect(g.effectK(h, Status.might), eagleEyeK.might);
      runFor(g, eagleEyeK.time + 0.1);
      expect(h.stats.range, range);
    });

    test('Hunter\'s Mark: the strongest elite in range takes 25% more from troops for 8 s (the boss 15%)', () {
      final (g, h) = heroCaster(HeroSkill.huntersMark);
      final small = foeAt(g, 'orc', h.pos + Point(40, 0), Tier.elite), big = foeAt(g, 'elite_orc', h.pos + Point(40, 10), Tier.elite);
      g.tick(0.05);
      expect((g.effectK(big, Status.vulnerable), g.under(small, Status.vulnerable)), (huntersMarkK.taken, false));
      final (b, bh) = heroCaster(HeroSkill.huntersMark);
      final necro = foeAt(b, boss, bh.pos + Point(40, 0), Tier.boss);
      b.tick(0.05);
      expect(b.effectK(necro, Status.vulnerable), huntersMarkK.boss);
    });

    test('Flurry: three thrusts at an elite in reach, 0.2 s apart: 1x, 1x, 2x', () {
      final (g, h) = heroCaster(HeroSkill.flurry);
      final plain = foeAt(g, 'orc', h.pos + Point(h.stats.range, 0));
      g.tick(0.05);
      expect(h.heroSkillAt, double.negativeInfinity, reason: 'not elite');
      final elite = foeAt(g, 'elite_orc', h.pos + Point(h.stats.range - 2, 6), Tier.elite);
      g.tick(0.05);
      final d = h.stats.dmg;
      expect(elite.hp, closeTo(elite.maxHp - d, 1e-9));
      runFor(g, 0.2);
      expect(elite.hp, closeTo(elite.maxHp - 2 * d, 1e-9));
      runFor(g, 0.2);
      expect(elite.hp, closeTo(elite.maxHp - 4 * d, 1e-9));
      expect(plain.hp, plain.maxHp);
    });

    test('Blessing: with a hurt troop in reach, each gets 2% of its max HP back a second for 8 s', () {
      final (g, h) = heroCaster(HeroSkill.blessing);
      final hurt = [for (var r = 1; r <= 3; r++) idle(g, 'knight', 3, r)..hp = 50];
      foeAt(g, 'orc', const Point(250, 60));
      g.tick(0.05);
      expect(h.heroSkillAt, g.t);
      runFor(g, blessingK.time);
      for (final u in hurt) {
        expect(u.hp, closeTo(50 + u.maxHp * blessingK.share * blessingK.time, 0.2));
      }
    });

    test('Holy Nova: with an undead in range (or the boss) each takes 2.5x its heal as holy damage', () {
      final (g, h) = heroCaster(HeroSkill.holyNova);
      final dead = [for (var i = 0; i < 3; i++) foeAt(g, 'skeleton', h.pos + Point(60, i * 8.0))];
      final orc = foeAt(g, 'orc', h.pos + Point(60, 30));
      g.tick(0.05);
      for (final o in dead) {
        expect(o.hp, closeTo(o.maxHp - h.stats.dmg * holyNovaK.hit * holyShare, 1e-9));
      }
      expect(orc.hp, orc.maxHp);
      final (b, bh) = heroCaster(HeroSkill.holyNova);
      foeAt(b, boss, bh.pos + Point(60, 0), Tier.boss);
      b.tick(0.05);
      expect(bh.heroSkillAt, b.t);
    });

    test('Gift of Mana: with a foe on and a troop short of MP for its skill, every other troop in reach gets 15 MP', () {
      final (g, h) = heroCaster(HeroSkill.manaGift);
      final a = idle(g, 'knight', 3, 3)..mp = 0, b = idle(g, 'wizard', 3, 4)..mp = 0;
      g.tick(0.05);
      expect(h.heroSkillAt, double.negativeInfinity, reason: 'no foe');
      foeAt(g, 'orc', const Point(250, 60));
      h.mp = HeroSkill.manaGift.cost.toDouble();
      g.tick(0.05);
      expect(a.mp, closeTo(manaGiftK.mp + 2 * 0.05 * a.stats.mpRegen, 1e-9));
      expect(b.mp, closeTo(manaGiftK.mp + 2 * 0.05 * b.stats.mpRegen, 1e-9));
      expect(h.mp, closeTo(h.stats.mpRegen * 0.05, 1e-9)); // not for itself
    });

    test('Iron Skin: hit with a foe in reach, it takes 15% less and sends 60% of melee blows back, for 6 s', () {
      final (g, h) = heroCaster(HeroSkill.ironSkin);
      final orc = foeAt(g, 'orc', h.pos + const Point(12, 0)); // in the reach of both
      foeAt(g, 'orc', h.pos + const Point(6, 12.5)); // in its reach too, and too far from either to be shoved
      g.tick(0.05);
      expect(h.heroSkillAt, double.negativeInfinity, reason: 'not hit yet');
      strikeOnce(g, orc); // the blow lands, then (next tick) it casts
      final hp = h.hp;
      g.tick(0.05);
      expect((g.effectK(h, Status.reflect), h.guardCut), (ironSkinK.reflect, ironSkinK.cut));
      final orcHp = orc.hp;
      runFor(g, 1);
      strikeOnce(g, orc);
      final took = hitTaken(orc.stats.dmg, h.stats.def) * (1 - ironSkinK.cut);
      expect(h.hp, closeTo(hp - took, 1e-9));
      expect(orc.hp, closeTo(orcHp - took * ironSkinK.reflect, 1e-9));
    });

    test('Earthquake: with a foe near (it waited for 4 before decisions-log 298), each takes 0.75x and walks at 60% for 4 s (the boss 80%)', () {
      final (g, h) = heroCaster(HeroSkill.quake);
      foeAt(g, 'orc', h.pos + const Point(250, 0)); // keeps the wave on, far off
      g.tick(0.05);
      expect(h.heroSkillAt, double.negativeInfinity, reason: 'none near');
      final foes = [for (var i = 0; i < 3; i++) foeAt(g, 'orc', h.pos + Point(20, i * 8.0)), foeAt(g, boss, h.pos + Point(30, 20), Tier.boss)];
      g.tick(0.05);
      for (final o in foes) {
        expect(o.hp, closeTo(o.maxHp - h.stats.dmg * quakeK.hit, 1e-9));
        expect(g.effectK(o, Status.slow), o.tier == Tier.boss ? quakeK.boss : quakeK.slow);
      }
    });

    test('Curse of Weakness: the elite in range that hits hardest deals 40% less and walks 20% slower for 8 s', () {
      final (g, h) = heroCaster(HeroSkill.curse);
      final weak = foeAt(g, 'orc', h.pos + Point(50, 0), Tier.elite), hard = foeAt(g, 'elite_orc', h.pos + Point(50, 10), Tier.elite);
      g.tick(0.05);
      expect((g.effectK(hard, Status.weaken), g.effectK(hard, Status.slow)), (curseK.dealt, curseK.slow));
      expect(g.under(weak, Status.weaken), isFalse);
      final (b, bh) = heroCaster(HeroSkill.curse);
      final necro = foeAt(b, boss, bh.pos + Point(50, 0), Tier.boss);
      b.tick(0.05);
      expect((b.effectK(necro, Status.weaken), b.effectK(necro, Status.slow)), (curseK.bossDealt, curseK.bossSlow));
    });

    test('Judgement: a holy blow at a foe that is undead (4x) or elite (2x)', () {
      final (g, h) = heroCaster(HeroSkill.judgement);
      final orc = foeAt(g, 'orc', h.pos + Point(h.stats.range, 0));
      g.tick(0.05);
      expect(h.heroSkillAt, double.negativeInfinity, reason: 'a plain orc');
      orc.gone = true;
      final skel = foeAt(g, 'skeleton', h.pos + Point(h.stats.range, 0))..hp = 1000;
      g.tick(0.05);
      expect(skel.hp, closeTo(1000 - h.stats.dmg * judgementK.dark, 1e-9));
      final (e, eh) = heroCaster(HeroSkill.judgement);
      final elite = foeAt(e, 'elite_orc', eh.pos + Point(eh.stats.range, 0), Tier.elite);
      e.tick(0.05);
      expect(elite.hp, closeTo(elite.maxHp - eh.stats.dmg * judgementK.hit, 1e-9));
    });

    test('Sacrifice: above 60% it gives 25% of its HP to the most hurt troop near below 25%', () {
      final (g, h) = heroCaster(HeroSkill.sacrifice);
      final a = idle(g, 'knight', 3, 3)..hp = 30, b = idle(g, 'soldier', 3, 4)..hp = 10;
      foeAt(g, 'orc', const Point(250, 60));
      final hp = h.hp;
      g.tick(0.05);
      expect(h.hp, closeTo(hp * (1 - sacrificeK.share), 1e-9));
      expect((b.hp, a.hp), (10 + hp * sacrificeK.share, 30));

      final (w, wh) = heroCaster(HeroSkill.sacrifice);
      idle(w, 'soldier', 3, 4).hp = 10;
      foeAt(w, 'orc', const Point(250, 60));
      wh.hp = wh.maxHp * sacrificeK.above;
      w.tick(0.05);
      expect(wh.heroSkillAt, double.negativeInfinity, reason: 'not above 60%');
    });

    test('Exorcism: with a raised minion near (it waited for 3 before decisions-log 298), the normal and elite ones crumble, a stronger one takes 3x', () {
      final (g, h) = heroCaster(HeroSkill.exorcism);
      final necro = foeAt(g, boss, const Point(250, 60), Tier.boss);
      Unit raised(Tier tier, double dy) => foeAt(g, 'skeleton', h.pos + Point(20, dy), tier)..raisedBy = necro;
      final plain = foeAt(g, 'skeleton', h.pos + const Point(20, -8))..hp = 1e6; // not raised
      g.tick(0.05);
      expect(h.heroSkillAt, double.negativeInfinity, reason: 'none raised near');
      plain.gone = true;
      final weak = [raised(Tier.normal, 0), raised(Tier.elite, 8)], strong = raised(Tier.highElite, 16);
      g.tick(0.05);
      expect(weak.every((o) => !o.alive), isTrue);
      expect(strong.hp, closeTo(strong.maxHp - h.stats.dmg * exorcismK.hit, 1e-9));
      expect(necro.hp, necro.maxHp); // the necromancer untouched
    });
  });
}
