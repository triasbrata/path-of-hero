// The awakening skills (#88, lib/awaken_skills.dart; docs/units-and-combat.md "Awakening skills"): the shared rules
// (the level unlocks the skill, the switch, one cast a tick, the MP it shares with the #10 skill, the clocks and their
// stagger, the pops, the book, the log and the telemetry's count), then each built skill. The last test draws the
// awakening skills' looks on a booted board.
import 'dart:convert';
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/telemetry.dart';

import 'awaken_items.dart';
import 'hero_skill_helpers.dart';

/// A wave on with nothing to spawn, [type] awakened to [level], and a troop of it at cell (2, 3), full of MP, that
/// never strikes on its own. The Hero and monster skills are off; the #10 skills stay on. Returns the game and the
/// troop. Add foes before ticking: with none the wave is won on the next tick.
(Game, Unit) awakenScene(String type, int level) {
  final g = bareGame(Random(1))
    ..heroSkills = false
    ..monsterSkills = false;
  g.upgrades[type] = awakenItems(type, level);
  final u = placeNow(g, type, 2, 3);
  g
    ..startWave()
    ..queue.clear();
  u
    ..cd = hold
    ..mp = u.stats.mp.toDouble();
  return (g, u);
}

/// The awakening skills cast so far in [g] (its log).
List<AwakenSkillCast> awakenCastsOf(Game g) => g.log.entries.whereType<AwakenSkillCast>().toList();

/// The #10 skills cast so far in [g].
List<SkillCast> skillCastsOf(Game g) => g.log.entries.whereType<SkillCast>().toList();

/// Ticks [g] by [dt] for [s] seconds; which of [foes] lost HP on which tick (its game time), in order.
List<(Unit, double)> cutsOver(Game g, List<Unit> foes, double s, [double dt = 0.01]) {
  final hp = {for (final o in foes) o: o.hp}, cuts = <(Unit, double)>[], end = g.t + s - 1e-9;
  while (g.t < end) {
    g.tick(dt);
    for (final o in foes) {
      if (o.hp < hp[o]!) cuts.add((o, g.t));
      hp[o] = o.hp;
    }
  }
  return cuts;
}

/// A sturdy elite orc (it outlives every blow) [dx], [dy] from [u]: in a soldier's reach when within 12.
Unit bigFoe(Game g, Unit u, double dx, double dy, [Tier tier = Tier.elite]) => foeAt(g, 'orc', u.pos + Point(dx, dy), tier)..hp = 1e4;

void main() {
  group('shared rules', () {
    test('only built skills unlock, one per type, and their names take the level\'s numeral', () {
      expect(awakenSkillOf('soldier'), AwakenSkill.disarm);
      expect(awakenSkillOf('orc'), isNull);
      for (final s in AwakenSkill.values) {
        expect(troopTypes.containsKey(s.type), isTrue, reason: s.name);
        expect(AwakenSkill.values.where((o) => o.type == s.type), hasLength(1), reason: s.type);
        expect(awakenSkillOf(s.type), s.built ? s : isNull);
        expect(s.cooldown, hasLength(maxAwaken));
      }
      expect([for (var l = 1; l <= 3; l++) AwakenSkill.disarm.titleAt(l)], ['Disarm', 'Disarm II', 'Disarm III']);
    });

    test('an awakening skill costs 40% of its type\'s MP pool at its level: 8 s of its regen, and a full pool pays it and the #10 skill', () {
      final g = bareGame();
      const costs = {
        'soldier': [10, 12, 14],
        'knight': [10, 12, 14],
        'swordsman': [15, 18, 21],
        'archer': [15, 18, 21],
        'lancer': [10, 12, 14],
        'priest': [30, 36, 42],
        'armored_axeman': [10, 12, 14],
        'wizard': [40, 48, 56],
        'knight_templar': [20, 24, 28],
      };
      for (final s in AwakenSkill.values) {
        expect([for (var l = 1; l <= 3; l++) s.costAt(l)], costs[s.type], reason: s.name);
        for (var l = 1; l <= 3; l++) {
          g.upgrades[s.type] = awakenItems(s.type, l);
          final pool = g.statsOf(s.type);
          expect(s.costAt(l) + troopSkills[s.type]!.cost, lessThanOrEqualTo(pool.mp), reason: '${s.name} $l');
          expect(s.costAt(l) / pool.mpRegen, closeTo(8, 0.5), reason: '${s.name} $l');
        }
      }
    });

    test('no awakening skill before Bangkit 1, none with the switch off, and the #10 skill as before', () {
      for (final (level, on) in [(0, true), (1, false)]) {
        final (g, u) = awakenScene('soldier', level);
        g.awakenSkills = on;
        bigFoe(g, u, 10, 0);
        bigFoe(g, u, 10, 8);
        runFor(g, 2);
        expect(awakenCastsOf(g), isEmpty, reason: 'level $level, switch $on');
        expect(g.awakenCasts, isEmpty);
        expect(skillCastsOf(g), hasLength(1), reason: 'Hold Fast');
      }
    });

    test('the awakening skill casts while the #10 skill is on cooldown, pays its MP and pops its name', () {
      final (g, u) = awakenScene('soldier', 2);
      final foe = bigFoe(g, u, 10, 0);
      u.skillAt = g.t; // Hold Fast just cast
      final mp = u.mp;
      g.tick(0.05);
      expect(awakenCastsOf(g).single.skill, AwakenSkill.disarm);
      expect(awakenCastsOf(g).single.level, 2);
      expect(u.mp, closeTo(mp - AwakenSkill.disarm.costAt(2), 1e-9)); // full: the tick's regen had no room
      expect(u.awakenSkillAt, g.t);
      expect(g.awakenCasts.single, (u, AwakenSkill.disarm, 2));
      expect(g.effectK(foe, Status.weaken), disarmK.weaken[1]);
      runFor(g, AwakenSkill.disarm.cooldownAt(2) - 0.5);
      expect(awakenCastsOf(g), hasLength(1), reason: 'its cooldown');
    });

    test('one cast a tick: with MP for both, the #10 skill first and the awakening skill on the next tick', () {
      final (g, u) = awakenScene('soldier', 1);
      bigFoe(g, u, 10, 0);
      bigFoe(g, u, 10, 8); // Hold Fast wants it too
      expect(u.mp, 25);
      g.tick(0.05);
      expect((skillCastsOf(g).length, awakenCastsOf(g).length), (1, 0));
      g.tick(0.05);
      expect((skillCastsOf(g).length, awakenCastsOf(g).length), (1, 1));
      expect(u.mp, closeTo(25 - troopSkills['soldier']!.cost - AwakenSkill.disarm.costAt(1), 0.1)); // a tick's regen
    });

    test('with MP for one, the #10 skill leaves it to the awakening skill that is ready and wanted', () {
      final (g, u) = awakenScene('soldier', 1);
      bigFoe(g, u, 10, 0);
      bigFoe(g, u, 10, 8);
      u.mp = 12; // Hold Fast 5 would leave 7: Disarm costs 10
      g.tick(0.05);
      expect((skillCastsOf(g).length, awakenCastsOf(g).length), (0, 1));
      // The awakening skill on its cooldown: the #10 skill is back to its own rule, as soon as it has the MP.
      u.mp = troopSkills['soldier']!.cost;
      g.tick(0.05);
      expect(skillCastsOf(g), hasLength(1));
    });

    test('with the awakening skill not wanted, the #10 skill spends as before', () {
      final (g, u) = awakenScene('soldier', 1);
      for (final dy in [0.0, 8.0]) {
        foeAt(g, 'slime', u.pos + Point(10, dy)).disarmedAt = g.t; // disarmed lately: not again for disarmK.again s
      }
      u.mp = 12; // Hold Fast 5 would leave too little for Disarm (10): it asks the awakening skill's rule first
      g.tick(0.05);
      expect((skillCastsOf(g).length, awakenCastsOf(g).length), (1, 0));
      expect(u.awakenThinkAt, closeTo(g.t + awakenThink, 1e-9), reason: 'the rule said no: not asked again for a while');
    });

    test('a Hero saving up for its own skill spends no MP on its awakening skill either', () {
      final (g, u) = awakenScene('soldier', 1);
      u
        ..hero = true
        ..heroSkill = HeroSkill.shieldBash; // an elite in reach: wanted
      g.heroSkills = true;
      bigFoe(g, u, 10, 0);
      u
        ..skillAt = g.t
        ..mp = 12; // Disarm's 10 but not Shield Bash's 15
      g.tick(0.05);
      expect(awakenCastsOf(g), isEmpty);
      g.heroSkills = false; // no longer saving
      g.tick(0.05);
      expect(awakenCastsOf(g), hasLength(1));
    });

    test('a wave\'s start makes the i-th troop of an awakened type ready i % 4 s in; a troop placed later at once', () {
      final g = bareGame(Random(1))..upgrades['soldier'] = awakenItems('soldier', 1);
      final all = [for (var r = 0; r < 5; r++) placeNow(g, 'soldier', 2, r)];
      final knight = placeNow(g, 'knight', 3, 0);
      g.startWave();
      final cd = AwakenSkill.disarm.cooldownAt(1);
      expect([for (final u in all) u.awakenSkillAt + cd - g.t], [0, 1, 2, 3, 0]);
      expect(knight.awakenSkillAt, double.negativeInfinity, reason: 'not awakened');
      g.queue.clear();
      foeAt(g, 'orc', const Point(300, 60));
      final late = placeNow(g, 'soldier', 3, 1);
      expect(late.awakenSkillAt, double.negativeInfinity);
    });

    test('awakening mid-wave: the skill is ready over 0-3 s, its name pops over each troop, the log names it', () {
      final g = bareGame(Random(1))..upgrades['soldier'] = awakenItems('soldier', 1).sublist(1);
      final missing = awakenItems('soldier', 1).first;
      final all = [for (var r = 0; r < 3; r++) placeNow(g, 'soldier', 2, r)];
      g
        ..startWave()
        ..queue.clear();
      foeAt(g, 'orc', const Point(300, 60));
      runFor(g, 5);
      expect(all.every((u) => u.awakenSkillAt == double.negativeInfinity), isTrue);
      g.inventory[missing] = 1;
      expect(g.useItem(missing, 'soldier'), isTrue);
      expect(g.awakenLevel('soldier'), 1);
      final cd = AwakenSkill.disarm.cooldownAt(1);
      for (final (i, u) in all.indexed) {
        expect(u.awakenSkillAt + cd - g.t, closeTo(i, 1e-9));
      }
      expect(g.awakenCasts, [for (final u in all) (u, AwakenSkill.disarm, 1)]);
      expect(awakenCastsOf(g), isEmpty, reason: 'the moment is no cast');
      final e = g.log.entries.whereType<Awakened>().single;
      expect(logLine(e), '${troopTypeNames['soldier']}: ${awakenName(1)} - Disarm');
    });

    test('the level is kept, and still follows the items the previews try on and take back', () {
      final g = bareGame();
      final items = awakenItems('knight', 1), last = items.removeLast();
      g
        ..upgrades['knight'] = items
        ..inventory[last] = 1;
      expect(g.awakenLevel('knight'), 0);
      expect(g.assignPreview(last, 'knight').awaken, (0, 1));
      expect(g.priceWith('knight', last), (troopTypes['knight']!.cost + (items.length + 1) * Game.priceStep('knight')) * awakenPrice);
      expect(g.awakenLevel('knight'), 0, reason: 'taken back');
      g.upgrades['knight'] = awakenItems('knight', 2); // a new list
      expect(g.awakenLevel('knight'), 2);
      g.upgrades['knight']!.removeLast(); // the same list, shorter
      expect(g.awakenLevel('knight'), 1);
      g.upgrades.clear();
      expect(g.awakenLevel('knight'), 0);
    });

    test('Gift of Mana counts a troop short of the MP its next skill wants: the #10 skill\'s, or its awakening skill\'s', () {
      final (g, u) = awakenScene('soldier', 3);
      expect(g.mpWanted(u), max(troopSkills['soldier']!.cost, AwakenSkill.disarm.costAt(3)).toDouble());
      final (g2, u2) = awakenScene('knight', 1);
      expect(g2.mpWanted(u2), max(troopSkills['knight']!.cost, AwakenSkill.unbroken.costAt(1)).toDouble());
    });

    test('the book: the stars tell the skill of the level, its MP and cooldown, the next level; the MP cell what spends it', () {
      final g = bareGame();
      final (title0, lines0) = g.awakenInfo('soldier');
      expect(title0, awakenName(0));
      expect([for (final (_, l) in lines0) l].take(5), [
        '${awakenName(1)} unlocks Disarm',
        'x1.5 hit on the strongest monster',
        'Its attack -10% for 6s (boss -5%)',
        'MP 10, cooldown 11s',
        '${awakenName(1)} needs:',
      ]);
      g.upgrades['soldier'] = awakenItems('soldier', 1);
      final (title1, lines1) = g.awakenInfo('soldier');
      expect(title1, awakenName(1));
      expect([for (final (_, l) in lines1) l].take(6), [
        'Skill: Disarm',
        'x1.5 hit on the strongest monster',
        'Its attack -10% for 6s (boss -5%)',
        'MP 10, cooldown 11s',
        '${awakenName(2)}: Disarm II (x2, -15%)',
        '${awakenName(2)} needs:',
      ]);
      expect(g.mpInfo('soldier').$2.skip(3), ['For Hold Fast (5 MP)', 'and Disarm (10 MP)']);
      g.upgrades['soldier'] = awakenItems('soldier', 3);
      final (title3, lines3) = g.awakenInfo('soldier');
      expect(title3, awakenName(3)); // Bangkit 4 and 5 are bought (#92 part 2, ascend_test.dart)
      expect([for (final (_, l) in lines3) l], [
        'Skill: Disarm III',
        'x2.5 hit on the strongest monster',
        'Its attack -20% for 6s (boss -10%)',
        'MP 14, cooldown 9s',
        '${awakenName(4)}: cooldown 7.7s',
        '${awakenName(4)}: buy on the ${Words.army} page',
      ]);
      expect(g.mpInfo('wizard').$2.skip(3), ['For Arcane Blast (20 MP)'], reason: 'not awakened: its awakening skill spends nothing yet');
      expect(awakenSkillChange('soldier', 0, 1), ('Unlocks Disarm', null));
      expect(awakenSkillChange('soldier', 1, 2), ('Disarm', 'Disarm II'));
      expect(awakenSkillChange('soldier', 2, 2), isNull);
      expect(awakenSkillChange('wizard', 0, 1), ('Unlocks Singularity', null));
      expect(awakenSkillChange('orc', 0, 1), isNull, reason: 'not a troop');
    });

    test('the log and the telemetry: "<name> memakai Disarm II" under Skill, counted by the skill\'s id', () {
      final g = bareGame(Random(1))
        ..skills = false // Hold Fast would take the first tick
        ..heroSkills = false
        ..monsterSkills = false;
      g.upgrades['soldier'] = awakenItems('soldier', 2);
      final u = placeNow(g, 'soldier', 2, 3), records = <Map<String, dynamic>>[];
      TelemetryAdapter([_Keep(records)], installId: 'i', session: 's', platform: 'test', now: () => DateTime.utc(2026)).attach(g);
      g
        ..startWave()
        ..queue.clear();
      final foe = foeAt(g, 'orc', u.pos + const Point(10, 0), Tier.elite)..hp = u.stats.dmg * 5;
      u.cd = hold;
      g.tick(0.05);
      expect(logLine(awakenCastsOf(g).single), '${u.name} uses Disarm II');
      expect(awakenCastsOf(g).single.toJson(), containsPair('level', 2));
      u.cd = 0; // now it strikes the foe down
      for (var i = 0; i < 400 && g.waveActive; i++) {
        g.tick(0.05);
      }
      expect(foe.alive, isFalse);
      expect(records.where((r) => r['rec'] == 'wave').single['awakenCasts'], {'disarm': 1});
    });
  });

  group('Disarm', () {
    test('strikes the strongest foe in reach worth it: the highest rank, then the hardest hitter, then the nearest', () {
      final (g, u) = awakenScene('soldier', 1);
      final near = bigFoe(g, u, 6, 0, Tier.normal);
      final elite = bigFoe(g, u, 10, 4);
      final werewolf = foeAt(g, 'werewolf', u.pos + const Point(0, 10), Tier.elite)..hp = 1e4;
      foeAt(g, 'orc', u.pos + const Point(-10, 0), Tier.highElite); // too weak to be worth it: its HP set below
      g.enemies.last.hp = u.stats.dmg * disarmK.worth - 1;
      u.skillAt = g.t;
      final hp = werewolf.hp;
      g.tick(0.05);
      expect(werewolf.hp, closeTo(hp - u.stats.dmg * disarmK.hit[0], 1e-6), reason: 'the elite werewolf hits harder than the elite orc');
      expect(g.effectK(werewolf, Status.weaken), disarmK.weaken[0]);
      expect(g.under(elite, Status.weaken) || g.under(near, Status.weaken), isFalse);
      expect(g.rings.where((r) => r.look == RingLook.shards && r.follow == werewolf), hasLength(1));
    });

    test('grows with the level, takes less off the boss rank, and never weakens a foe again as strongly', () {
      for (final level in [1, 2, 3]) {
        final (g, u) = awakenScene('soldier', level);
        final boss = bigFoe(g, u, 10, 0, Tier.boss);
        u.skillAt = g.t;
        final hp = boss.hp;
        g.tick(0.05);
        expect(boss.hp, closeTo(hp - hitTaken(u.stats.dmg * disarmK.hit[level - 1], boss.stats.def), 1e-6), reason: 'level $level');
        expect(g.effectK(boss, Status.weaken), disarmK.boss[level - 1]);
        boss.disarmedAt = double.negativeInfinity; // as if its 30 s were over: the weakness alone keeps it off
        expect(g.wantsAwakenSkill(u, AwakenSkill.disarm, level), isFalse, reason: 'weakened as strongly already');
      }
      final (g, u) = awakenScene('soldier', 1);
      final cursed = bigFoe(g, u, 10, 0);
      g.addEffect(cursed, Status.weaken, 8, k: curseK.dealt);
      expect(g.wantsAwakenSkill(u, AwakenSkill.disarm, 1), isFalse, reason: 'a curse is stronger');
    });

    test('a Disarmed foe is not Disarmed again by any soldier for 30 s, while a second foe still is', () {
      final (g, u) = awakenScene('soldier', 1);
      final mini = bigFoe(g, u, 10, 0, Tier.miniBoss);
      final elite = bigFoe(g, u, 6, 6);
      u.skillAt = g.t; // Hold Fast on its cooldown
      g.tick(0.05);
      expect(mini.disarmedAt, g.t);
      expect([g.under(mini, Status.weaken), g.under(elite, Status.weaken)], [true, false]);
      // Its weakness taken off, so only the 30 s keep it from a second soldier, ready at once: that one takes the elite.
      mini.effects.remove(Status.weaken);
      final other = placeNow(g, 'soldier', 2, 4)
        ..cd = hold
        ..skillAt = g.t;
      other
        ..pos = u.pos + const Point(0, 2) // both foes in its reach
        ..mp = other.stats.mp.toDouble();
      g.tick(0.05);
      expect(g.awakenCasts.map((c) => c.$1), [u, other]);
      expect(elite.disarmedAt, g.t, reason: 'the second foe still is');
      expect([g.under(mini, Status.weaken), g.under(elite, Status.weaken)], [false, true]);
      // Ready again: nothing to Disarm while both are inside their 30 s; the mini boss again once its 30 s are over.
      u
        ..awakenSkillAt = double.negativeInfinity
        ..awakenThinkAt = double.negativeInfinity
        ..mp = u.stats.mp.toDouble();
      mini.disarmedAt = g.t - disarmK.again + 0.5;
      expect(g.wantsAwakenSkill(u, AwakenSkill.disarm, 1), isFalse);
      mini.disarmedAt = g.t - disarmK.again;
      g.tick(0.05);
      expect(g.awakenCasts.map((c) => c.$1), [u, other, u]);
      expect((mini.disarmedAt, g.under(mini, Status.weaken)), (g.t, true));
    });

    test('a taunted soldier disarms only its taunter', () {
      final (g, u) = awakenScene('soldier', 1);
      final strong = bigFoe(g, u, 8, 0, Tier.highElite);
      final taunter = bigFoe(g, u, 10, 4, Tier.normal);
      g.addEffect(u, Status.taunt, 4, by: taunter);
      u.skillAt = g.t;
      g.tick(0.05);
      expect(g.under(taunter, Status.weaken), isTrue);
      expect(g.under(strong, Status.weaken), isFalse);
    });

    test('a Hero wizard\'s Curse still lands on a disarmed foe, and a cursed one takes no second curse', () {
      final (g, h) = heroCaster(HeroSkill.curse);
      final foe = foeAt(g, 'orc', h.pos + const Point(40, 0), Tier.elite)..hp = 1e4;
      g.addEffect(foe, Status.weaken, disarmK.time, k: disarmK.weaken[2]);
      g.tick(0.05);
      expect(g.effectK(foe, Status.weaken), curseK.dealt);
      h.heroSkillAt = double.negativeInfinity;
      expect(g.wantsHeroSkill(h), isFalse);
    });
  });

  group('Unbroken', () {
    test('hurt and just hit: it heals itself and the troops beside it, and throws off the monsters\' holds only', () {
      final (g, u) = awakenScene('knight', 1);
      g.skills = false; // Circle Slash would take the first tick (a lone foe is its target, decisions-log 298)
      final foe = bigFoe(g, u, 10, 0);
      final beside = placeNow(g, 'soldier', 2, 4)..cd = hold; // a tile away
      final far = placeNow(g, 'soldier', 4, 3)..cd = hold; // two
      for (final o in [beside, far]) {
        o.hp = o.maxHp * 0.5;
      }
      u
        ..hp = u.maxHp * 0.5
        ..hurtAt = g.t
        ..hero = true; // a Hero knight in its own duel
      g
        ..addEffect(u, Status.slow, 4, k: 0.7, by: foe)
        ..addEffect(u, Status.haste, 4, k: 1 / 0.7, by: foe) // a Sticky Glob's attack slow
        ..addEffect(u, Status.bleed, 4.5, k: 1, by: foe, n: 4)
        ..addEffect(u, Status.duel, 8, k: duelK.might, by: foe)
        ..addEffect(u, Status.might, 6, k: 1.2); // a War Banner's: a troop's, not a hindrance
      final (hp, bHp, fHp) = (u.hp, beside.hp, far.hp);
      g.tick(0.05);
      expect(awakenCastsOf(g).single.skill, AwakenSkill.unbroken);
      expect(u.hp, closeTo(hp + u.maxHp * unbrokenK.self[0], 1e-6));
      expect(beside.hp, closeTo(bHp + beside.maxHp * unbrokenK.allies[0], 1e-6));
      expect(far.hp, fHp);
      expect([for (final s in [Status.slow, Status.haste, Status.bleed]) g.under(u, s)], [false, false, false]);
      expect(g.under(u, Status.duel), isTrue, reason: 'its own duel stays');
      expect(g.under(u, Status.might), isTrue);
      expect(g.rings.where((r) => r.look == RingLook.unchain && r.follow == u), hasLength(1));
    });

    test('its rule (any HP lost since decisions-log 298): hurt only when just hit, or under a monster\'s hindrance; never at full HP, never with no foe in reach', () {
      final (g, u) = awakenScene('knight', 1);
      final foe = bigFoe(g, u, 10, 0);
      bool wants() => g.wantsAwakenSkill(u, AwakenSkill.unbroken, 1);
      u.hp = u.maxHp * 0.5;
      expect(wants(), isFalse, reason: 'not hit lately');
      u.hurtAt = g.t - 0.5;
      expect(wants(), isTrue);
      u
        ..hurtAt = double.negativeInfinity
        ..hp = u.maxHp * 0.8;
      g.addEffect(u, Status.slow, 4, k: 0.7, by: foe);
      expect(wants(), isTrue, reason: 'slowed by a monster');
      u.hp = u.maxHp.toDouble();
      expect(wants(), isFalse, reason: 'at full HP a slow is no reason');
      u.hp = u.maxHp * 0.5;
      u.hurtAt = g.t;
      foe.pos = u.pos + const Point(40, 0);
      expect(wants(), isFalse, reason: 'no foe in reach');
    });

    test('grows with the level', () {
      for (final level in [1, 2, 3]) {
        final (g, u) = awakenScene('knight', level);
        g.skills = false; // no Circle Slash first
        bigFoe(g, u, 10, 0);
        u
          ..hp = u.maxHp * 0.3
          ..hurtAt = g.t;
        final hp = u.hp;
        g.tick(0.05);
        expect(u.hp, closeTo(hp + u.maxHp * unbrokenK.self[level - 1], 1e-6), reason: 'level $level');
      }
    });
  });

  group('Impale', () {
    /// A high-elite elite orc winding up Brutal Swing (begun 0.1 s ago) in front of lancer [u], past its reach but in
    /// its lunge's; or a monster of [type] and [tier] winding up [skill].
    Unit winder(Game g, Unit u, {String type = 'elite_orc', Tier tier = Tier.highElite, MonsterSkill skill = MonsterSkill.brutalSwing}) =>
        foeAt(g, type, u.pos + Point(u.stats.range + impaleK.reach - 4, 0), tier)
          ..hp = 1e5
          ..winding = skill
          ..windUntil = g.t + 0.5
          ..castAt = g.t - 0.1
          ..skillAt = g.t - 0.1
          ..bossSkillAt = g.t - 0.1;

    test('breaks a wind-up from past its reach: the wind-up ends, its cooldown stands, a 0.3 s stagger, no second break for 25 s', () {
      final (g, u) = awakenScene('lancer', 1);
      final o = winder(g, u);
      final mini = bigFoe(g, u, 10, 0, Tier.miniBoss); // stronger, and to pin: a break comes first
      u.skillAt = g.t; // Piercing Thrust on its cooldown
      final hp = o.hp;
      g.tick(0.05);
      expect(awakenCastsOf(g).single.skill, AwakenSkill.impale);
      expect(o.winding, isNull);
      expect(o.skillAt, closeTo(g.t - 0.15, 1e-9), reason: 'its cooldown runs on from the wind-up');
      expect(o.stunUntil, closeTo(g.t + impaleK.stagger, 1e-9));
      expect(o.interruptedAt, g.t);
      expect(hp - o.hp, closeTo(hitTaken(u.stats.dmg * impaleK.hit[0], o.stats.def), 1e-6));
      expect([g.under(o, Status.impaled), g.under(mini, Status.impaled)], [false, false], reason: 'a break pins nothing');
      expect(g.beams.where((b) => b.look == BeamLook.lunge), hasLength(1));
      expect(g.rings.where((r) => r.look == RingLook.shatter), hasLength(1));
      // It winds up again: within 25 s no second break, so the mini boss is pinned instead.
      void again() {
        o
          ..winding = MonsterSkill.brutalSwing
          ..windUntil = g.t + 0.5
          ..stunUntil = double.negativeInfinity;
        u
          ..awakenSkillAt = double.negativeInfinity
          ..awakenThinkAt = double.negativeInfinity
          ..mp = u.stats.mp.toDouble();
      }

      again();
      o.interruptedAt = g.t - impaleK.window + 0.5;
      g.tick(0.05);
      expect(o.winding, MonsterSkill.brutalSwing);
      expect(g.under(mini, Status.impaled), isTrue);
      again();
      o.interruptedAt = g.t - impaleK.window;
      g.tick(0.05);
      expect(o.winding, isNull, reason: '25 s on, it breaks again');
    });

    test('a mini boss staggers half as long', () {
      final (g, u) = awakenScene('lancer', 1);
      final o = winder(g, u, tier: Tier.miniBoss);
      u.skillAt = g.t;
      g.tick(0.05);
      expect(o.winding, isNull);
      expect(o.stunUntil, closeTo(g.t + impaleK.stagger / 2, 1e-9));
    });

    test('never breaks the boss rank, a necromancer (the escort\'s high elite too) or a once-only skill: it pins them instead', () {
      for (final (type, tier, skill) in [
        ('orc', Tier.boss, MonsterSkill.warShout),
        (boss, Tier.highElite, MonsterSkill.curseOfFrailty),
        (boss, Tier.miniBoss, MonsterSkill.soulDrain),
        ('werebear', Tier.miniBoss, MonsterSkill.thickHide),
      ]) {
        final (g, u) = awakenScene('lancer', 1);
        final o = winder(g, u, type: type, tier: tier, skill: skill);
        u.skillAt = g.t;
        g.tick(0.05);
        expect(awakenCastsOf(g).single.skill, AwakenSkill.impale, reason: '$type ${tier.name}');
        expect((o.winding, o.interruptedAt, o.stunUntil), (skill, double.negativeInfinity, double.negativeInfinity), reason: '$type ${tier.name}');
        expect(g.effectK(o, Status.impaled), tier == Tier.boss ? impaleK.boss : impaleK.slow, reason: 'pinned instead');
      }
    });

    test('a pin: the highest ranked strong foe, then the most HP; x0.1 for 2 / 2.5 / 3 s, the boss rank x0.55, no stagger', () {
      for (final level in [1, 2, 3]) {
        final (g, u) = awakenScene('lancer', level);
        final elite = bigFoe(g, u, 10, 0);
        final high = bigFoe(g, u, 0, 14, Tier.highElite)..hp = 5000;
        final low = bigFoe(g, u, -12, -8, Tier.highElite)..hp = 4000;
        foeAt(g, 'slime', u.pos + const Point(4, -14)); // a normal one is never pinned
        u.skillAt = g.t;
        g.tick(0.05);
        final e = g.effectOn(high, Status.impaled);
        expect(e?.k, impaleK.slow, reason: 'level $level');
        expect(e!.until, closeTo(g.t + impaleK.pin[level - 1], 1e-9));
        expect(e.by, u);
        expect(high.stunUntil, double.negativeInfinity, reason: 'a pin doesn\'t stagger');
        expect([g.under(elite, Status.impaled), g.under(low, Status.impaled)], [false, false]);
        u.awakenSkillAt = double.negativeInfinity;
        expect(g.wantsAwakenSkill(u, AwakenSkill.impale, level), isTrue, reason: 'the next strong one');
        for (final o in [elite, low]) {
          g.addEffect(o, Status.impaled, 2, k: impaleK.slow);
        }
        expect(g.wantsAwakenSkill(u, AwakenSkill.impale, level), isFalse, reason: 'all pinned');
      }
      final (g, u) = awakenScene('lancer', 1);
      final chief = bigFoe(g, u, 10, 0, Tier.boss);
      u.skillAt = g.t;
      g.tick(0.05);
      expect(g.effectK(chief, Status.impaled), impaleK.boss);
    });

    test('a pinned monster walks at x0.1 while it lasts, and at its own pace in a march', () {
      final (g, u) = awakenScene('lancer', 1);
      g.awakenSkills = false;
      Unit walker(double dy) => g.monster('orc', Tier.elite, u.pos + Point(140, dy))
        ..entered = true
        ..cd = hold;
      final (pinned, free) = (walker(-24), walker(24));
      g
        ..units.addAll([pinned, free])
        ..addEffect(pinned, Status.impaled, 10, k: impaleK.slow);
      var (p0, f0) = (pinned.pos, free.pos);
      runFor(g, 1);
      expect(pinned.pos.distanceTo(p0) / free.pos.distanceTo(f0), closeTo(impaleK.slow, 0.02));
      g.marching = true;
      (p0, f0) = (pinned.pos, free.pos);
      runFor(g, 0.5);
      expect(pinned.pos.distanceTo(p0) / free.pos.distanceTo(f0), closeTo(1, 0.02));
    });

    test('keeps the lance for a break while a monster it could break stands within 5 tiles, for 3 s at most', () {
      final (g, u) = awakenScene('lancer', 1);
      g.monsterSkills = true; // they cast: a break may come
      bigFoe(g, u, 10, 0); // strong, to pin
      final caster = foeAt(g, 'elite_orc', u.pos + const Point(4 * tile, 0), Tier.highElite)..hp = 1e5; // out of the lunge's reach
      final cd = AwakenSkill.impale.cooldownAt(1);
      bool wants(double readyFor) {
        u.awakenSkillAt = g.t - cd - readyFor;
        return g.wantsAwakenSkill(u, AwakenSkill.impale, 1);
      }

      expect(wants(0), isFalse, reason: 'held for a break');
      expect(wants(impaleK.hold - 0.1), isFalse);
      expect(wants(impaleK.hold + 0.01), isTrue, reason: 'it pins once 3 s are up');
      caster.interruptedAt = g.t; // just broken: nothing to wait for
      expect(wants(0), isTrue);
      caster
        ..interruptedAt = double.negativeInfinity
        ..pos = u.pos + const Point(5 * tile + 2, 0);
      expect(wants(0), isTrue, reason: 'more than 5 tiles away');
      caster.pos = u.pos + const Point(4 * tile, 0);
      g.monsterSkills = false;
      expect(wants(0), isTrue, reason: 'the monsters cast nothing');
    });

    test('never while the wave marches; a taunted lancer lunges only at its taunter', () {
      final (g, u) = awakenScene('lancer', 1);
      final strong = bigFoe(g, u, 10, 0, Tier.highElite);
      final taunter = bigFoe(g, u, 0, 14);
      u.skillAt = g.t;
      g.marching = true;
      g.tick(0.05);
      expect(awakenCastsOf(g), isEmpty);
      g
        ..marching = false
        ..addEffect(u, Status.taunt, 4, by: taunter);
      g.tick(0.05);
      expect([g.under(taunter, Status.impaled), g.under(strong, Status.impaled)], [true, false]);
    });
  });

  group('Spellbreaker', () {
    test('a silver arrow strips the buffs and the guard monsters gave a normal or elite foe, never what troops put on it', () {
      final (g, u) = awakenScene('archer', 1);
      final shouter = foeAt(g, 'orc', u.pos + const Point(60, 30), Tier.highElite); // nothing on it: never the target
      final o = foeAt(g, 'armored_orc', u.pos + const Point(60, 0), Tier.elite)..hp = 1e4;
      g
        ..addEffect(o, Status.might, warShoutK.time, k: warShoutK.might, by: shouter)
        ..addEffect(o, Status.reflect, bulwarkK.time, k: bulwarkK.reflect)
        ..addEffect(o, Status.absorb, unholyWardK.time, k: 50) // an escort healer's Unholy Ward names no giver
        ..addEffect(o, Status.slow, 5, k: 0.5, by: u)
        ..addEffect(o, Status.vulnerable, 8, k: huntersMarkK.taken, by: u);
      o
        ..guardUntil = g.t + bulwarkK.time
        ..guardCut = bulwarkK.cut
        ..guardLook = RingLook.orange;
      u.skillAt = g.t; // Arrow Rain on its cooldown
      g.tick(0.05);
      expect(awakenCastsOf(g).single.skill, AwakenSkill.spellbreaker);
      final arrow = g.shots.single;
      expect((arrow.look, arrow.speed, arrow.dmg, arrow.target), (ShotLook.silver, spellbreakerK.speed, u.stats.dmg * spellbreakerK.hit[0], o));
      runFor(g, 0.3);
      expect(g.shots, isEmpty);
      expect([for (final s in [Status.might, Status.reflect, Status.absorb]) g.under(o, s)], [false, false, false]);
      expect(o.guardUntil, lessThanOrEqualTo(g.t));
      expect([g.under(o, Status.slow), g.under(o, Status.vulnerable)], [true, true], reason: 'the troops\' own stay');
      expect(g.rings.where((r) => r.look == RingLook.dispel), hasLength(1));
    });

    test('a mini boss and the boss rank lose half of what is left, once; so does a buff the boss gave (Rally); a buff of another is stripped', () {
      final (g, u) = awakenScene('archer', 1);
      final chief = foeAt(g, 'orc', u.pos + const Point(110, 50), Tier.boss)..hp = 1e5;
      final wolf = foeAt(g, 'werewolf', u.pos + const Point(60, 0), Tier.miniBoss)..hp = 1e5;
      final rallied = foeAt(g, 'orc', u.pos + const Point(60, 30))..hp = 1e4;
      final t0 = g.t;
      g
        ..addEffect(wolf, Status.haste, frenzyK.time, k: frenzyK.pause) // its Frenzy
        ..addEffect(rallied, Status.might, rallyK.time, k: rallyK.might, by: chief) // the orc boss's Rally
        ..addEffect(chief, Status.swift, secondWindK.time, k: secondWindK.walk); // and on the boss itself
      wolf
        ..guardUntil = t0 + 4
        ..guardCut = 0.3;
      void shoot() {
        u
          ..skillAt = g.t
          ..awakenSkillAt = double.negativeInfinity
          ..awakenThinkAt = double.negativeInfinity
          ..mp = u.stats.mp.toDouble();
        g.rings.clear();
        g.tick(0.05);
        expect(awakenCastsOf(g).last.skill, AwakenSkill.spellbreaker);
        runFor(g, 0.3);
      }

      double landed() => g.rings.firstWhere((r) => r.look == RingLook.dispel).since;
      shoot(); // the boss first: the highest ranked with something
      var at = landed();
      expect(g.effectOn(chief, Status.swift)!.until, closeTo(at + (t0 + secondWindK.time - at) / 2, 1e-9));
      expect(g.effectOn(chief, Status.swift)!.halved, isTrue);
      shoot(); // then the mini boss
      at = landed();
      expect(g.effectOn(wolf, Status.haste)!.until, closeTo(at + (t0 + frenzyK.time - at) / 2, 1e-9));
      expect(g.effectOn(wolf, Status.haste)!.halved, isTrue);
      expect(wolf.guardUntil, closeTo(at + (t0 + 4 - at) / 2, 1e-9));
      expect(wolf.guardHalved, wolf.guardUntil);
      shoot(); // then the rallied orc
      at = landed();
      expect(g.effectOn(rallied, Status.might)!.until, closeTo(at + (t0 + rallyK.time - at) / 2, 1e-9), reason: 'halved, not stripped');
      u.awakenSkillAt = double.negativeInfinity;
      expect(g.wantsAwakenSkill(u, AwakenSkill.spellbreaker, 1), isFalse, reason: 'each halved once');
      g.addEffect(rallied, Status.lifesteal, bloodrageK.time, k: bloodrageK.share, by: rallied); // a Bloodrage of its own
      expect(g.wantsAwakenSkill(u, AwakenSkill.spellbreaker, 1), isTrue);
    });

    test('a werewolf mini boss\'s Frenzy is halved, not taken off, and still comes below half its HP', () {
      final (g, u) = awakenScene('archer', 1);
      g.monsterSkills = true;
      final shouter = foeAt(g, 'orc', u.pos + const Point(100, 40), Tier.highElite);
      final wolf = g.monster('werewolf', Tier.miniBoss, u.pos + const Point(70, 0))
        ..entered = true
        ..cd = hold
        ..skillAt = hold; // its Pounce kept out
      g
        ..units.add(wolf)
        ..addEffect(wolf, Status.slow, hold, k: 0) // it stands
        ..addEffect(wolf, Status.might, warShoutK.time, k: warShoutK.strong, by: shouter);
      wolf.hp = wolf.maxHp * 0.6;
      u.skillAt = g.t;
      g.tick(0.05);
      runFor(g, 0.3);
      expect(g.effectOn(wolf, Status.might)?.halved, isTrue);
      expect(g.under(wolf, Status.haste), isFalse);
      wolf.hp = wolf.maxHp * 0.45;
      runFor(g, 0.3);
      final frenzy = g.effectOn(wolf, Status.haste);
      expect(frenzy?.k, frenzyK.pause, reason: 'Frenzy came');
      final left = frenzy!.until - g.t;
      u
        ..skillAt = g.t
        ..awakenSkillAt = double.negativeInfinity
        ..awakenThinkAt = double.negativeInfinity
        ..mp = u.stats.mp.toDouble();
      g.tick(0.05);
      runFor(g, 0.3);
      expect(g.effectOn(wolf, Status.haste)?.halved, isTrue);
      expect(g.effectOn(wolf, Status.haste)!.until - g.t, lessThan(left / 2 + 0.05));
    });

    test('at Bangkit 2 and 3 it strips every foe within 1 and 1.5 tiles of its target too', () {
      for (final level in [2, 3]) {
        final (g, u) = awakenScene('archer', level);
        final target = foeAt(g, 'orc', u.pos + const Point(80, 0), Tier.elite)..hp = 1e4;
        final foes = [target, for (final p in const [Point(0.0, 14.0), Point(20.0, 0.0), Point(0.0, -30.0)]) foeAt(g, 'orc', target.pos + p)..hp = 1e4];
        for (final o in foes) {
          g.addEffect(o, Status.might, 5, k: warShoutK.might, by: o);
        }
        u.skillAt = g.t;
        g.tick(0.05);
        expect(g.shots.single.target, target);
        runFor(g, 0.3);
        expect([for (final o in foes) g.under(o, Status.might)], [false, false, level < 3, true], reason: 'level $level');
      }
    });

    test('a quiet field, a buff under 1 s, a troop\'s effect or an arrow already on its way: no cast', () {
      final (g, u) = awakenScene('archer', 1);
      final o = foeAt(g, 'orc', u.pos + const Point(60, 0), Tier.elite)..hp = 1e4;
      bool wants(Unit a) => g.wantsAwakenSkill(a, AwakenSkill.spellbreaker, 1);
      expect(wants(u), isFalse, reason: 'nothing to strip');
      g.addEffect(o, Status.slow, 5, k: 0.5, by: u);
      expect(wants(u), isFalse, reason: 'a troop\'s');
      g.addEffect(o, Status.might, 0.9, k: warShoutK.might, by: o);
      o.guardUntil = g.t + 0.5;
      expect(wants(u), isFalse, reason: 'under 1 s left');
      g.addEffect(o, Status.might, 3, k: warShoutK.might, by: o);
      expect(wants(u), isTrue);
      final other = placeNow(g, 'archer', 2, 5)
        ..cd = hold
        ..skillAt = g.t;
      u.skillAt = g.t;
      g.tick(0.05);
      expect(g.shots.single.look, ShotLook.silver);
      expect(wants(other), isFalse, reason: 'one arrow on its way is enough');
    });
  });

  group('Singularity', () {
    test('opens on the foe with the most it can pull round it; they drift in, never toward the base, the boss not at all, a mini boss at half', () {
      final (g, u) = awakenScene('wizard', 1);
      final c = u.pos + Point(u.stats.range - 10, 0);
      foeAt(g, 'orc', c, Tier.elite).hp = 1e4;
      final right = foeAt(g, 'orc', c + const Point(20, 0)); // its pull's x part would take it to the base
      final left = foeAt(g, 'orc', c + const Point(-20, 0));
      final below = foeAt(g, 'orc', c + const Point(0, 20));
      final chief = foeAt(g, 'orc', c + const Point(14, -14), Tier.boss);
      final mini = foeAt(g, 'orc', c + const Point(-14, -16), Tier.miniBoss);
      u.skillAt = g.t; // Arcane Blast on its cooldown
      final start = {for (final o in g.enemies) o: o.pos};
      g.tick(0.05);
      final z = g.zones.single;
      expect((z.look, z.at, z.radius, z.side), (ZoneLook.singularity, c, singularityK.radius[0], Side.enemy));
      expect(z.until - z.since, closeTo(singularityK.time[0], 1e-9));
      runFor(g, 0.2); // five ticks of pull in all: 6 at 24 a second
      final step = singularityK.pull[0] * 0.25;
      expect(right.pos, start[right], reason: 'no x part toward the base, no y part');
      expect(left.pos.x - start[left]!.x, closeTo(step, 1e-9), reason: 'away from the base');
      expect(left.pos.y, start[left]!.y);
      expect(below.pos.x, start[below]!.x);
      expect(start[below]!.y - below.pos.y, closeTo(step, 1e-9));
      expect(chief.pos, start[chief], reason: 'the boss rank is never pulled');
      expect(start[mini]!.distanceTo(c) - mini.pos.distanceTo(c), closeTo(step / 2, 1e-9), reason: 'a mini boss half');
    });

    test('a monster with a troop in its reach drifts only sideways: it isn\'t dragged off its fight', () {
      final (g, u) = awakenScene('wizard', 1);
      final c = u.pos + const Point(70, 0);
      for (final p in const [Point(0.0, 0.0), Point(0.0, 20.0), Point(0.0, -20.0)]) {
        foeAt(g, 'orc', c + p);
      }
      final fighter = foeAt(g, 'orc', c + const Point(-20, 8));
      g.units.add(Unit(Side.troop, 'soldier', troopTypes['soldier']!, fighter.pos - const Point(12, 0))
        ..entered = true
        ..busyUntil = hold); // just in its reach, not close enough to be shoved
      u.skillAt = g.t;
      final at = fighter.pos;
      g.tick(0.05);
      expect(g.zones.single.at, c);
      expect(fighter.pos.x, at.x, reason: 'no x part');
      expect(fighter.pos.y, closeTo(at.y - singularityK.pull[0] * 0.05 * 8 / sqrt(464), 1e-9));
    });

    test('one well pulls a monster a tick, the oldest; none opens over an open one', () {
      final (g, u) = awakenScene('wizard', 1);
      final c1 = u.pos + Point(u.stats.range - 10, 0), c2 = c1 + const Point(44, 0);
      for (final p in const [Point(0.0, 0.0), Point(0.0, 20.0), Point(0.0, -20.0), Point(-20.0, 0.0)]) {
        foeAt(g, 'orc', c1 + p);
      }
      final shared = foeAt(g, 'orc', c1 + const Point(20, 0)); // in both wells: 20 from the first's centre, 24 from the second's
      final second = [for (final p in const [Point(0.0, 0.0), Point(0.0, 20.0), Point(20.0, 0.0), Point(0.0, -20.0)]) foeAt(g, 'orc', c2 + p)];
      final w2 = placeNow(g, 'wizard', 5, 6)
        ..cd = hold
        ..skillAt = g.t;
      expect(w2.pos.distanceTo(c2), lessThanOrEqualTo(w2.stats.range));
      u.skillAt = g.t;
      final at = shared.pos, high = second[1].pos;
      g.tick(0.05);
      expect([for (final z in g.zones) z.at], [c1, c2]);
      runFor(g, 0.2);
      expect(shared.pos, at, reason: 'the first well holds it: its pull has no x part, the second\'s would have one');
      expect(second[1].pos.y, lessThan(high.y), reason: 'the second well pulls its own');
      for (final w in [u, w2]) {
        w.awakenSkillAt = double.negativeInfinity;
        expect(g.wantsAwakenSkill(w, AwakenSkill.singularity, 1), isFalse, reason: 'every foe in a well');
      }
    });

    test('it closes with a burst, 1x / 1.25x / 1.5x, on the foes within 1.25 tiles of its centre; it pulls nothing while the wave marches', () {
      for (final level in [1, 2, 3]) {
        final (g, u) = awakenScene('wizard', level);
        final c = u.pos + const Point(60, 0); // the centre: the nearest of the four, all on its far side
        final near = [for (final p in const [Point(0.0, 0.0), Point(16.0, 0.0), Point(8.0, 14.0), Point(8.0, -14.0)]) foeAt(g, 'orc', c + p)..hp = 1e4];
        // In the well (2+ tiles across) but past the burst; the centre still has the most round it and is nearest.
        final far = foeAt(g, 'orc', c + Point(0, -singularityK.burst - 4))..hp = 1e4;
        u.skillAt = g.t;
        g.tick(0.05);
        expect(g.zones.single.look, ZoneLook.singularity, reason: 'level $level');
        g.marching = true; // from here on nothing pulls
        final at = [for (final o in near) o.pos];
        runFor(g, singularityK.time[level - 1] - 0.1);
        expect([for (final o in near) o.pos], at, reason: 'no pull in a march');
        expect([for (final o in near) o.hp], everyElement(1e4));
        runFor(g, 0.2);
        expect(g.zones, isEmpty);
        for (final o in near) {
          expect(1e4 - o.hp, closeTo(hitTaken(u.stats.dmg * singularityK.hit[level - 1], o.stats.def), 1e-6), reason: 'level $level');
        }
        expect(far.hp, 1e4);
        expect(g.rings.where((r) => r.look == RingLook.implode), hasLength(1));
      }
    });

    test('the book tells Impale, Spellbreaker and Singularity, and the next level\'s numbers', () {
      final g = bareGame();
      for (final (type, lines) in [
        (
          'lancer',
          [
            'Skill: Impale',
            'x1.5 thrust, reach +1 tile',
            "Stops a monster's skill (not a boss), or pins a strong one 2s",
            'MP 10, cooldown 9s',
            '${awakenName(2)}: Impale II (x2, pin 2.5s)',
          ]
        ),
        (
          'archer',
          [
            'Skill: Spellbreaker',
            'x1.5 silver arrow takes monster buffs',
            'Boss and mini boss: half the time left',
            'MP 15, cooldown 9s',
            '${awakenName(2)}: Spellbreaker II (x2, 1 tile)',
          ]
        ),
        (
          'wizard',
          [
            'Skill: Singularity',
            'A 2-tile well pulls monsters in for 2s',
            'Then it bursts for x1 damage',
            'MP 40, cooldown 12s',
            '${awakenName(2)}: Singularity II (2.5 tiles, x1.25)',
          ]
        ),
      ]) {
        g.upgrades[type] = awakenItems(type, 1);
        expect([for (final (_, l) in g.awakenInfo(type).$2) l].take(5), lines, reason: type);
      }
      g.upgrades['archer'] = awakenItems('archer', 3);
      expect(awakenLines('archer', 3)[1], 'x2.5 silver arrow takes monster buffs (1.5 tiles)');
    });
  });

  group('Consecration', () {
    test('holy ground at its feet with 3+ foes on it: a pulse each second, the first at once, the undead x1.25, the damage fixed at the cast', () {
      final (g, u) = awakenScene('knight_templar', 1);
      final orc = bigFoe(g, u, 10, 0), orc2 = bigFoe(g, u, 0, 14);
      final skel = foeAt(g, 'skeleton', u.pos + const Point(-12, -8), Tier.elite)..hp = 1e4;
      final hit = u.stats.dmg * consecrationK.hit[0], start = (orc.hp, orc2.hp, skel.hp), at = u.pos;
      g.tick(0.05);
      final z = g.zones.single;
      expect((z.look, z.side, z.radius, z.until - z.since, z.at), (ZoneLook.consecrate, Side.enemy, consecrationK.radius[0], consecrationK.time[0], at));
      expect(start.$1 - orc.hp, closeTo(hit, 1e-6));
      expect(start.$3 - skel.hp, closeTo(hit * consecrationK.undead * u.stats.darkK, 1e-6)); // and its torches' (decisions-log 251)
      u.stats = u.stats.boosted(2); // a buff after the cast doesn't raise it
      runFor(g, consecrationK.time[0] + 0.5);
      expect(g.zones, isEmpty);
      expect(start.$2 - orc2.hp, closeTo(4 * hit, 1e-6), reason: 'four pulses in 4 s');
      expect(start.$3 - skel.hp, closeTo(4 * hit * consecrationK.undead * u.stats.darkK, 1e-6));
    });

    test('its blows are holy: a skeleton it kills never reassembles, and it ends a heap of bones', () {
      final (g, u) = awakenScene('knight_templar', 1);
      g.monsterSkills = true; // Reassemble is a monster skill
      for (final (dx, dy) in [(10.0, 0.0), (0.0, 14.0)]) {
        bigFoe(g, u, dx, dy);
      }
      final bones = foeAt(g, 'skeleton', u.pos + const Point(-12, -8), Tier.highElite)..hp = 1;
      final heap = foeAt(g, 'skeleton', u.pos + const Point(8, 8), Tier.highElite)
        ..hp = 1
        ..reassembled = true
        ..downUntil = g.t + 5; // lying as a heap already
      g.tick(0.05);
      expect(awakenCastsOf(g).single.skill, AwakenSkill.consecration);
      expect((bones.alive, bones.reassembled, bones.downUntil), (false, false, double.negativeInfinity), reason: 'no Reassemble');
      expect(heap.alive, isFalse, reason: 'a heap ends');
    });

    test('never a second ground within 1.5x its radius, nor with fewer than 3 foes on it', () {
      final (g, u) = awakenScene('knight_templar', 1);
      for (final (dx, dy) in [(10.0, 0.0), (0.0, 14.0), (-12.0, -8.0)]) {
        bigFoe(g, u, dx, dy);
      }
      g.tick(0.05);
      expect(g.zones, hasLength(1));
      u.awakenSkillAt = double.negativeInfinity;
      expect(g.wantsAwakenSkill(u, AwakenSkill.consecration, 1), isFalse);
      final r = consecrationK.radius[0], from = u.pos;
      u.pos = g.zones.single.at + Point(consecrationK.apart * r + 1, 0); // from the ground's centre (it walked a little)
      for (final o in g.enemies.toList()) {
        o.pos += u.pos - from;
      }
      expect(g.wantsAwakenSkill(u, AwakenSkill.consecration, 1), isTrue);
      u.pos -= const Point(2, 0);
      expect(g.wantsAwakenSkill(u, AwakenSkill.consecration, 1), isFalse, reason: 'within 1.5x its radius');
      u.pos += const Point(2, 0);
      for (final o in g.enemies.skip(1)) {
        o.pos += const Point(100, 0);
      }
      expect(g.wantsAwakenSkill(u, AwakenSkill.consecration, 1), isTrue, reason: 'a lone foe on it (decisions-log 298)');
      g.enemies.first.pos += const Point(100, 0);
      expect(g.wantsAwakenSkill(u, AwakenSkill.consecration, 1), isFalse, reason: 'none on it');
    });

    test('at Bangkit 3: 2 tiles for 5 s at 0.25x, and it burns on with no attacker once the templar has fallen', () {
      final (g, u) = awakenScene('knight_templar', 3);
      final foes = [bigFoe(g, u, 10, 0), bigFoe(g, u, 0, 14), bigFoe(g, u, -12, -8)];
      final hp = foes.first.hp;
      g.tick(0.05);
      final z = g.zones.single;
      expect((z.radius, z.until - z.since, z.pulses), (2 * tile, 5.0, 5));
      final hit = hp - foes.first.hp;
      expect(hit, closeTo(u.stats.dmg * consecrationK.hit[2], 1e-6));
      u.hp = 0;
      u.dying = 0;
      runFor(g, 1.03); // the second pulse
      expect(hp - foes.first.hp, closeTo(2 * hit, 1e-6));
    });
  });

  group('Phantom Rush', () {
    /// Elite orcs [dx], [dy] from swordsman [u], at [share] of a 10000 HP pool each (so the round's order is theirs);
    /// 12+ apart, so nobody shoves anybody.
    List<Unit> round(Game g, Unit u, List<(double, double, double)> foes) => [
          for (final (dx, dy, share) in foes)
            foeAt(g, 'orc', u.pos + Point(dx, dy), Tier.elite)
              ..maxHp = 10000
              ..hp = 10000 * share,
        ];

    test('cuts the most wounded first, then round again, 0.2 s apart, and is back where it stood', () {
      final (g, u) = awakenScene('swordsman', 3);
      final foes = round(g, u, [(12.5, 0, 0.9), (0, 14, 0.5), (-12, -8, 0.7)]);
      final [a, b, c] = foes;
      u.skillAt = g.t; // Rampage on its cooldown
      final home = u.pos, start = [for (final o in foes) o.hp];
      g.tick(0.01);
      expect(awakenCastsOf(g).single.skill, AwakenSkill.phantomRush);
      expect(u.move, isA<Carry>().having((m) => m.look, 'look', CarryLook.ghost).having((m) => m.lift, 'lift', phantomRushK.lift));
      final cuts = cutsOver(g, foes, 1.5);
      expect([for (final (o, _) in cuts) o], [b, c, a, b], reason: 'at Bangkit 3, four cuts round three foes');
      for (var i = 1; i < cuts.length; i++) {
        expect(cuts[i].$2 - cuts[i - 1].$2, closeTo(phantomRushK.dash, 0.011));
      }
      final cut = u.stats.dmg * phantomRushK.hit[2];
      expect(start[1] - b.hp, closeTo(2 * hitTaken(cut, b.stats.def), 1e-6));
      expect(start[0] - a.hp, closeTo(hitTaken(cut, a.stats.def), 1e-6));
      expect(u.move, isNull);
      expect(u.pos.distanceTo(home), lessThan(1e-6), reason: 'back where it stood');
      expect(g.beams.where((x) => x.look == BeamLook.rush), isEmpty, reason: 'each dash\'s streak gone after its time');
    });

    test('Rampage goes first when both are ready, and the rush gets a cut more; a kill another, once', () {
      final (g, u) = awakenScene('swordsman', 1);
      final foes = round(g, u, [(12.5, 0, 0.0001), (0, 14, 0.0002), (-12, -8, 0.5), (0, -16, 0.7)]);
      final [k1, k2, a, b] = foes;
      g.tick(0.01);
      expect(skillCastsOf(g).single.skill, 'Rampage');
      expect(awakenCastsOf(g), isEmpty, reason: 'one cast a tick, the #10 skill first');
      final cuts = cutsOver(g, foes, 2);
      expect(awakenCastsOf(g).single.skill, AwakenSkill.phantomRush);
      // 3 cuts, +1 raging, +1 for k1's kill; k2's kill gives none, and the dead are passed over.
      expect([for (final (o, _) in cuts) o], [k1, k2, a, b, a]);
      expect((k1.alive, k2.alive), (false, false));
    });

    test('only with a foe in reach (a lone one is enough since decisions-log 298), never taunted or falling back; its attack pause waits while it rushes', () {
      final (g, u) = awakenScene('swordsman', 1);
      bool wants() => g.wantsAwakenSkill(u, AwakenSkill.phantomRush, 1);
      final a = bigFoe(g, u, 12.5, 0);
      expect(wants(), isTrue, reason: 'a lone foe');
      bigFoe(g, u, 0, 14);
      bigFoe(g, u, -12, -8);
      expect(wants(), isTrue);
      a.pos = u.pos + const Point(20, 0);
      expect(wants(), isFalse, reason: 'none in its reach');
      a.pos = u.pos + const Point(12.5, 0);
      g.addEffect(u, Status.taunt, 4, by: a);
      expect(wants(), isFalse, reason: 'taunted');
      u.effects.clear();
      u.retreating = true;
      expect(wants(), isFalse, reason: 'falling back');
      u
        ..retreating = false
        ..skillAt = g.t
        ..cd = 0.5;
      g.tick(0.05);
      expect(u.move, isA<Carry>());
      final cd = u.cd;
      runFor(g, 0.4);
      expect((u.move != null, u.cd), (true, cd), reason: 'carried: its pause doesn\'t run');
    });
  });

  group('Skyfall', () {
    /// An axeman at Bangkit [level] (Crushing Blow on its cooldown) at cell (2, 3), a soldier that just fought at
    /// cell (5, 3), 3 tiles ahead of it, and three foes 3.5-3.75 tiles ahead of the axeman round that soldier, 12+
    /// apart so none shoves another out of the landing.
    (Game, Unit, Unit, List<Unit>) skyfallScene(int level) {
      final (g, u) = awakenScene('armored_axeman', level);
      final front = placeNow(g, 'soldier', 5, 3)
        ..cd = hold
        ..attackedAt = g.t;
      final foes = [for (final (dx, dy) in [(60.0, 0.0), (56.0, 12.0), (56.0, -12.0)]) bigFoe(g, u, dx, dy)];
      u.skillAt = g.t;
      return (g, u, front, foes);
    }

    test('leaps beside the crowd its troops fight, never past the front, and lands with its blow and its guard', () {
      final (g, u, front, foes) = skyfallScene(1);
      final (frontX, y) = (front.pos.x, u.pos.y);
      final hp = [for (final o in foes) o.hp];
      g.tick(0.05);
      expect(awakenCastsOf(g).single.skill, AwakenSkill.skyfall);
      final m = u.move as Carry, r = skyfallK.radius[0];
      expect((m.look, m.lift, m.radius), (CarryLook.skyfall, skyfallK.lift, r));
      expect(m.end - m.start, closeTo(skyfallK.time, 1e-9));
      expect(m.to.x, closeTo(frontX, 1e-9), reason: 'beside the nearest, held back to the soldier fighting there');
      expect(m.to.y, closeTo(y, 1e-9));
      while (u.move != null) {
        g.tick(0.05);
      }
      for (final (i, o) in foes.indexed) {
        expect(hp[i] - o.hp, closeTo(hitTaken(u.stats.dmg * skyfallK.hit[0], o.stats.def), 1e-6), reason: 'foe $i');
      }
      expect((u.guardCut, u.guardLook), (skyfallK.guard[0], null));
      expect(u.guardUntil, closeTo(g.t + skyfallK.guardTime, 1e-9));
      expect(g.rings.where((x) => x.look == RingLook.crater && x.radius == r), hasLength(1));
    });

    test('no leap with a foe in its reach, below half its HP, taunted, or where nobody fights; a lone foe there is enough (decisions-log 298)', () {
      final (g, u, front, foes) = skyfallScene(1);
      bool wants() => g.wantsAwakenSkill(u, AwakenSkill.skyfall, 1);
      expect(wants(), isTrue);
      front.attackedAt = g.t - skyfallK.fought;
      expect(wants(), isFalse, reason: 'nobody fought there lately');
      front.attackedAt = g.t;
      u.hp = u.maxHp * 0.45;
      expect(wants(), isFalse, reason: 'below half its HP');
      u.hp = u.maxHp.toDouble();
      g.addEffect(u, Status.taunt, 4, by: foes.first);
      expect(wants(), isFalse, reason: 'taunted');
      u.effects.clear();
      final near = bigFoe(g, u, 12, 0);
      expect(wants(), isFalse, reason: 'a foe in its reach');
      g.units
        ..remove(near)
        ..removeWhere(foes.skip(1).contains);
      expect(wants(), isTrue, reason: 'a lone foe there');
    });

    test('two axemen never leap to one spot: the second takes the next crowd', () {
      for (final both in [true, false]) {
        final (g, u, _, _) = skyfallScene(1);
        for (final (dx, dy) in [(60.0, 48.0), (56.0, 60.0), (56.0, 36.0)]) {
          bigFoe(g, u, dx, dy); // a second crowd, round a second soldier fighting at cell (5, 6)
        }
        placeNow(g, 'soldier', 5, 6)
          ..cd = hold
          ..attackedAt = g.t;
        final v = placeNow(g, 'armored_axeman', 2, 4) // the first crowd is its nearest too
          ..cd = hold
          ..skillAt = g.t;
        if (!both) u.awakenSkillAt = g.t; // the first axeman on its cooldown
        g.tick(0.05);
        final to = (v.move as Carry).to;
        if (both) {
          final first = (u.move as Carry).to;
          expect(to.distanceTo(first), greaterThan(skyfallK.radius[0]));
          expect(to.y, greaterThan(80), reason: 'the second crowd');
        } else {
          expect((u.move, to.y < 80), (null, true), reason: 'alone, it takes the nearest crowd');
        }
      }
    });

    test('Crushing Blow stuns a mini boss half as long now, as every stun of the troops\' does (_stunFor)', () {
      final (g, u) = awakenScene('armored_axeman', 0);
      final mini = bigFoe(g, u, 12, 0, Tier.miniBoss), orc = bigFoe(g, u, 0, 14, Tier.normal);
      g.tick(0.05);
      expect(skillCastsOf(g).single.skill, troopSkills['armored_axeman']!.name);
      expect((mini.stunUntil, orc.stunUntil), (g.t + slam.stun * 0.5, g.t + slam.stun));
    });
  });

  group('Lifeline', () {
    /// A soldier at cell ([c], [r]) at [share] of its HP, just hit, never striking, with an elite orc beside it.
    Unit dying(Game g, int c, int r, [double share = 0.2]) {
      final o = placeNow(g, 'soldier', c, r)..cd = hold;
      o
        ..hp = o.maxHp * share
        ..hurtAt = g.t;
      foeAt(g, 'orc', o.pos + const Point(12, 0), Tier.elite).hp = 1e4;
      return o;
    }

    /// A priest at Bangkit [level] (Healing Prayer on its cooldown) at cell (2, 3) and a dying soldier 3 tiles ahead.
    (Game, Unit, Unit) lifelineScene(int level) {
      final (g, u) = awakenScene('priest', level);
      u.skillAt = g.t;
      return (g, u, dying(g, 5, 3));
    }

    test('lifts the dying troop out of the fight to its side, mended, and counted as come to its healer', () {
      final (g, u, o) = lifelineScene(1);
      final hp = o.hp, at = u.pos;
      g.tick(0.05);
      expect(awakenCastsOf(g).single.skill, AwakenSkill.lifeline);
      final m = o.move as Carry;
      expect((m.lift, m.by, m.look), (lifelineK.lift, null, CarryLook.plain));
      expect(m.end - m.start, closeTo(lifelineK.time, 1e-9));
      expect(m.to.distanceTo(at), closeTo(lifelineK.gap, 1e-6), reason: 'beside the priest, on its side towards the troop');
      expect(g.beams.where((b) => b.look == BeamLook.tether && b.follow!.first == u && b.follow!.last == o), hasLength(1));
      while (o.move != null) {
        g.tick(0.05);
      }
      expect(o.pos.distanceTo(m.to), lessThan(0.01));
      expect(o.hp, closeTo(hp + u.stats.dmg * lifelineK.heal[0], 1e-6));
      expect((o.healedAt, o.waitFrom), (g.t, g.t));
      expect(g.rings.where((r) => r.look == RingLook.bloom && r.follow == o), hasLength(1));
    });

    test('only the dying still in the fight, 2+ tiles off: never one holding its ground, braced or carried', () {
      final (g, u, o) = lifelineScene(1);
      final foe = g.enemies.single, at = o.pos;
      bool wants() => g.wantsAwakenSkill(u, AwakenSkill.lifeline, 1);
      void to(Point<double> p) {
        o.pos = p;
        foe.pos = p + const Point(12, 0);
      }

      expect(wants(), isTrue);
      o.hp = o.maxHp * (lifelineK.below + 0.05);
      expect(wants(), isFalse, reason: 'not hurt enough');
      o.hp = o.maxHp * 0.2;
      o.hurtAt = g.t - 1.5;
      expect(wants(), isFalse, reason: 'not hit lately');
      o.hurtAt = g.t;
      foe.pos = o.pos + const Point(20, 0);
      expect(wants(), isFalse, reason: 'no foe within a tile of it');
      to(u.pos + const Point(28, 0));
      expect(wants(), isFalse, reason: 'within 2 tiles of the priest');
      to(u.pos + Point(u.stats.range + 4, 0));
      expect(wants(), isFalse, reason: 'out of the priest\'s reach');
      to(at);
      g.addEffect(o, Status.holdGround, 4);
      expect(wants(), isFalse, reason: 'holding its ground');
      o.effects.clear();
      g.brace(o, 2);
      expect(wants(), isFalse, reason: 'braced');
      o
        ..brace = null
        ..move = Carry(o.pos, o.pos, g.t, g.t + 1);
      expect(wants(), isFalse, reason: 'carried (another priest lifts it)');
      o.move = null;
      expect(wants(), isTrue);
    });

    test('at Bangkit 3 it lifts the two most hurt, a ribbon each, never setting one down behind the back line', () {
      final (g, u) = awakenScene('priest', 3);
      u.skillAt = g.t;
      final a = dying(g, 5, 1, 0.25), b = dying(g, 5, 3, 0.1), c = dying(g, 5, 5, 0.2);
      g.baseX = 4 * tile; // the back line well past the priest's side
      g.tick(0.05);
      expect(a.move, isNull);
      expect([b.move, c.move], everyElement(isA<Carry>()));
      for (final o in [b, c]) {
        expect((o.move as Carry).to.x, g.baseX + Game.clearOfLine, reason: 'held at the back line');
      }
      expect(g.beams.where((x) => x.look == BeamLook.tether), hasLength(2));
      while (b.move != null) {
        g.tick(0.05);
      }
      expect(b.hp, closeTo(min(b.maxHp.toDouble(), b.maxHp * 0.1 + u.stats.dmg * lifelineK.heal[2]), 1e-6), reason: 'healed, up to its max');
    });

    test('set down unhealed when its priest falls meanwhile', () {
      final (g, u, o) = lifelineScene(2);
      final hp = o.hp;
      g.tick(0.05);
      u
        ..hp = 0
        ..dying = 0;
      while (o.move != null) {
        g.tick(0.05);
      }
      expect((o.hp, o.waitFrom.isNaN || o.waitFrom != g.t), (hp, true));
      expect(g.rings.where((r) => r.look == RingLook.bloom), isEmpty);
    });
  });

  test('the book tells the movers\' numbers, with their two decimals', () {
    final g = bareGame();
    List<String> lines(String type, int level) {
      g.upgrades[type] = awakenItems(type, level);
      return [for (final (_, l) in g.awakenInfo(type).$2) l].take(5).toList();
    }

    expect(lines('swordsman', 1), [
      'Skill: Phantom Rush',
      '3 quick cuts x1.2 on the most hurt (2.5 tiles)',
      '+1 in Rampage, +1 on a kill; then back',
      'MP 15, cooldown 9s',
      '${awakenName(2)}: Phantom Rush II (3 cuts x1.3)',
    ]);
    expect(lines('armored_axeman', 1), [
      'Skill: Skyfall',
      'Leaps where troops fight (2.5-5 tiles)',
      'x1 slam (1.25 tiles), shield 15% for 3s',
      'MP 10, cooldown 11s',
      '${awakenName(2)}: Skyfall II (x1.25, 1.5 tiles, shield 20%)',
    ]);
    expect(lines('priest', 2), [
      'Skill: Lifeline II',
      'Pulls a hurt troop (under 50% HP) to its side',
      'Heals x2 its heal',
      'MP 36, cooldown 10s',
      '${awakenName(3)}: Lifeline III (2 troops, heal x2.5)',
    ]);
    expect(lines('priest', 3).take(3), ['Skill: Lifeline III', 'Pulls 2 hurt troops (under 50% HP) to its side', 'Heals x2.5 its heal']);
  });

  testWidgets('every ring look draws with its colour, and the awakening skills\' casts and pops draw on the field', (tester) async {
    tester.view
      ..physicalSize = const Size(1266, 713)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = TdGame();
    await tester.pumpWidget(GameWidget(game: game));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue);
    final b = game.board..welcome = null;
    expect(awakenColors.keys.toSet(), AwakenSkill.values.toSet(), reason: 'one colour table for all nine');
    for (final s in AwakenSkill.values.where((s) => s.built)) {
      final (g, u) = awakenScene(s.type, 3);
      final foe = bigFoe(g, u, 10, 0);
      bigFoe(g, u, 0, 14);
      bigFoe(g, u, -12, -8);
      switch (s) {
        case AwakenSkill.unbroken:
          u
            ..hp = u.maxHp * 0.4
            ..hurtAt = g.t;
        case AwakenSkill.skyfall:
          // The foes 3.75-4 tiles ahead, round a soldier fighting there: it leaps to them.
          const ahead = [Point(60.0, 0.0), Point(56.0, 12.0), Point(56.0, -12.0)];
          for (final (i, o) in g.enemies.indexed) {
            o.pos = u.pos + ahead[i];
          }
          placeNow(g, 'soldier', 5, 3)
            ..cd = hold
            ..attackedAt = g.t;
        case AwakenSkill.lifeline:
          // A soldier dying 3 tiles ahead, the first foe beside it: it is lifted to the priest.
          final o = placeNow(g, 'soldier', 5, 3)..cd = hold;
          o
            ..hp = o.maxHp * 0.2
            ..hurtAt = g.t;
          foe.pos = o.pos + const Point(12, 0);
        default:
          break;
      }
      for (final o in g.enemies) {
        // Drawn standing: a board draws a unit held by busyUntil (foeAt's) as rising, from a busyFrom it never had.
        o
          ..busyUntil = double.negativeInfinity
          ..cd = hold;
      }
      for (final look in RingLook.values) {
        // Every look (a missing colour would throw), on the foe and on the ground.
        g.rings.add(Ring.over(foe, radius: 12, since: g.t, look: look, duration: 1));
      }
      u.skillAt = g.t;
      castable(g, u, s);
      b.state = g;
      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(milliseconds: 16)); // 1.1 s
      }
      expect(awakenCastsOf(g).map((e) => e.skill), contains(s), reason: '${s.name} cast');
      expect(tester.takeException(), isNull, reason: s.name);
    }
  });
}

/// For the field test, what Spellbreaker and Singularity need besides the three foes round the troop: a buff to
/// strip (a War Shout's), a fourth foe in the knot (standing, like the others).
void castable(Game g, Unit u, AwakenSkill s) {
  switch (s) {
    case AwakenSkill.spellbreaker:
      final o = g.enemies.first;
      g.addEffect(o, Status.might, warShoutK.time, k: warShoutK.might, by: o);
    case AwakenSkill.singularity:
      foeAt(g, 'orc', u.pos + const Point(12, 12), Tier.elite)
        ..hp = 1e4
        ..busyUntil = double.negativeInfinity
        ..cd = hold;
    default:
      break;
  }
}

/// A telemetry sink that keeps its records (through JSON).
class _Keep implements TelemetrySink {
  _Keep(this.records);
  final List<Map<String, dynamic>> records;

  @override
  void add(Map<String, Object?> record) => records.add(jsonDecode(jsonEncode(record)) as Map<String, dynamic>);

  @override
  Future<void> flush() async {}
}
