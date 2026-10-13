// The heal funnel (catalog step 0e, decisions-log 181; lib/heal.dart; docs/units-and-combat.md "Heals"): every heal a
// troop gets goes through `_healTroop` with its tag. A table over every heal site (each sets off its own heal, and the
// funnel hears its tag and what Wound takes it for); the static guard (no unit's HP goes up anywhere else in lib/ than
// the troops' funnel and the monsters' one, `_healMonster`: its table is cleanse_test.dart's);
// Wound's factor and its exemptions (the Grail's save, the after-wave heal, any heal between waves); the heal past full
// HP; the ward (at most wardMax of max HP, broken before HP, gone at the wave's end).
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'real_rules.dart';
import 'hero_skill_helpers.dart';

/// A heal the funnel heard: the troop, its tag, what it was to Wound then, the heal asked and the heal past full HP.
typedef Heard = ({Unit u, HealSrc src, HealKind kind, double asked, double past});

/// Every troop heal of [g] from now on, in order.
List<Heard> listen(Game g) {
  final heard = <Heard>[];
  g.onTroopHeal = (u, src, asked, past) => heard.add((u: u, src: src, kind: g.healKind(src), asked: asked, past: past));
  return heard;
}

/// A [bareGame] with no skills of any kind.
Game plain([Random? rng]) => bareGame(rng)
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false;

/// A troop of [type] at cell ([c], [r]) that never strikes (nor heals) on its own.
Unit idle(Game g, String type, int c, int r) => placeNow(g, type, c, r)..cd = hold;

/// Lets [foe] strike once now (then it stands again).
void strikeBy(Game g, Unit foe) {
  foe
    ..busyUntil = double.negativeInfinity
    ..cd = 0;
  g.tick(0.05);
  foe.busyUntil = hold;
}

/// Ticks [g] until [done] (at most [s] seconds).
void tickUntil(Game g, bool Function() done, [double s = 5]) {
  final end = g.t + s;
  while (!done() && g.t < end) {
    g.tick(0.05);
  }
}

/// Wins [g]'s wave outright: one slime shows up and is gone.
void winWave(Game g) {
  g.startWave();
  g.queue
    ..clear()
    ..add(('slime', Tier.normal));
  g.tick(0.05);
  g.enemies.single.gone = true;
  g.tick(0.05);
}

/// A wave on with nothing to spawn, [type] awakened to [level], and a troop of it at cell (2, 3), full of MP, that
/// never strikes on its own (awaken_skills_test.dart's).
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

/// One scene a heal site sets off: the game, what the funnel heard, and the troop it must heal.
typedef Scene = (Game, List<Heard>, Unit);

/// Each heal site's scene, by the tag it must carry (the existing tests' set-ups).
final Map<HealSrc, Scene Function()> sites = {
  HealSrc.heal: () {
    final g = plain(), heard = listen(g);
    placeNow(g, 'priest', 0, 3);
    final k = idle(g, 'knight', 2, 3)..hp = 50;
    foeAt(g, 'orc', const Point(250, 60)); // mid-wave
    tickUntil(g, () => heard.isNotEmpty);
    return (g, heard, k);
  },
  HealSrc.prayer: () {
    final g = bareGame()..gold = 10000, heard = listen(g);
    final p = placeNow(g, 'priest', 0, 3)..cd = hold;
    final ks = [for (var r = 0; r < 5; r++) placeNow(g, 'knight', 3, 2 + r)];
    for (final (i, share) in [0.99, 0.2, 1.0, 0.5, prayer.hurt].indexed) { // two below prayer.hurt round the worst (decisions-log 298)
      ks[i].hp = ks[i].maxHp * share;
    }
    foeAt(g, 'orc', const Point(250, 60)); // mid-wave
    g.tick(0.05);
    expect(p.skillAt, g.t, reason: 'Healing Prayer cast');
    return (g, heard, ks[1]);
  },
  HealSrc.overTime: () {
    final (g, h) = heroCaster(HeroSkill.blessing);
    final heard = listen(g), hurt = [for (var r = 1; r <= 3; r++) idle(g, 'knight', 3, r)..hp = 50];
    foeAt(g, 'orc', const Point(250, 60));
    g.tick(0.05);
    expect(h.heroSkillAt, g.t, reason: 'Blessing cast');
    runFor(g, 1);
    return (g, heard, hurt.first);
  },
  HealSrc.lifesteal: () {
    final (g, h) = heroCaster(HeroSkill.bloodlust);
    final heard = listen(g);
    foeAt(g, 'orc', h.pos + Point(h.stats.range, 0));
    foeAt(g, 'orc', h.pos + const Point(6, 13));
    h
      ..hp = 50
      ..cd = 0;
    g.tick(0.05);
    expect(g.effectK(h, Status.lifesteal), bloodlustK.share, reason: 'Bloodlust cast');
    return (g, heard, h);
  },
  HealSrc.killHeal: () {
    final (g, h) = heroCaster(HeroSkill.lastStand);
    final heard = listen(g);
    idle(g, 'priest', 0, 3);
    final foe = foeAt(g, 'orc', h.pos + Point(h.stats.range, 0));
    foeAt(g, 'orc', const Point(300, 10)); // keeps the wave on
    h.hp = h.maxHp * 0.4; // hurt
    g.tick(0.05);
    expect(h.heroSkillAt, g.t, reason: 'Last Stand cast');
    foe.hp = 1;
    h.cd = 0;
    g.tick(0.05);
    expect(foe.alive, isFalse);
    return (g, heard, h);
  },
  HealSrc.sacrifice: () {
    final (g, h) = heroCaster(HeroSkill.sacrifice);
    final heard = listen(g);
    idle(g, 'knight', 3, 3).hp = 30;
    final b = idle(g, 'soldier', 3, 4)..hp = 10;
    foeAt(g, 'orc', const Point(250, 60));
    g.tick(0.05);
    expect(h.heroSkillAt, g.t, reason: 'Sacrifice cast');
    return (g, heard, b);
  },
  HealSrc.unbroken: () {
    final (g, u) = awakenScene('knight', 1);
    g.skills = false; // no Circle Slash first (a lone foe is its target, decisions-log 298)
    final heard = listen(g);
    foeAt(g, 'orc', u.pos + const Point(10, 0), Tier.elite).hp = 1e4;
    final beside = idle(g, 'soldier', 2, 4)..hp = 10;
    u
      ..hp = u.maxHp * 0.5
      ..hurtAt = g.t;
    g.tick(0.05);
    expect(heard.where((h) => h.u == u && h.src == HealSrc.unbroken), hasLength(1), reason: 'itself');
    return (g, heard, beside);
  },
  HealSrc.lifeline: () {
    final (g, u) = awakenScene('priest', 1);
    final heard = listen(g);
    u.skillAt = g.t; // Healing Prayer on its cooldown
    final o = idle(g, 'soldier', 5, 3);
    o
      ..hp = o.maxHp * 0.2
      ..hurtAt = g.t;
    foeAt(g, 'orc', o.pos + const Point(12, 0), Tier.elite).hp = 1e4;
    g.tick(0.05);
    expect(o.move, isA<Carry>(), reason: 'Lifeline cast');
    tickUntil(g, () => o.move == null);
    return (g, heard, o);
  },
  HealSrc.regen: () {
    final g = plain()..givePusaka(Relic.dragonHeart, type: 'knight'), heard = listen(g);
    final k = idle(g, 'knight', 2, 3);
    expect(k.stats.regen, greaterThan(0));
    k.hp = 50;
    foeAt(g, 'orc', const Point(250, 60)); // mid-wave
    g.tick(0.05);
    return (g, heard, k);
  },
  HealSrc.fang: () {
    final g = plain(), heard = listen(g);
    final k = placeNow(g, 'knight', 2, 3)..hp = 10;
    k.relics.add(Relic.fang);
    foeAt(g, 'orc', k.pos + const Point(14, 0)).hp = 100000;
    g.tick(0.05);
    return (g, heard, k);
  },
  HealSrc.pusaka: () {
    final g = plain()..givePusaka(Relic.mourningBell, type: 'soldier'), heard = listen(g);
    final s = placeNow(g, 'soldier', 2, 3), mate = placeNow(g, 'soldier', 2, 4);
    for (final u in [s, mate]) {
      u
        ..busyUntil = hold
        ..hp = 1;
    }
    strikeBy(g, foeAt(g, 'orc', s.pos + const Point(-12, 0)));
    expect(s.alive, isFalse);
    return (g, heard, mate);
  },
  HealSrc.queue: () {
    final g = plain()..gold = 1000, heard = listen(g);
    placeNow(g, 'priest', 0, 3);
    final k = placeNow(g, 'knight', 3, 3)..hp = 50;
    winWave(g);
    expect(g.healQueue, contains(k));
    tickUntil(g, () => k.hp == k.maxHp, victoryTime + 2);
    return (g, heard, k);
  },
  HealSrc.pocket: () {
    // A Heal Bottle (pocket.dart, decisions-log 332): every troop, here in a wave.
    final g = plain(), heard = listen(g);
    final s = idle(g, 'soldier', 2, 3)..busyUntil = hold;
    g
      ..startWave()
      ..queue.clear();
    foeAt(g, 'orc', s.pos + const Point(60, 0));
    s.hp = s.maxHp * 0.5;
    g.pocketStock[PocketKind.healBottle] = 1;
    expect(g.putInPocket(PocketKind.healBottle, 0), isTrue);
    expect(g.usePocket(0), isTrue);
    return (g, heard, s);
  },
  HealSrc.lastStand: () {
    // Iron Will (relics.dart, decisions-log 227): a blow leaves its holder under its line; once a wave.
    final g = plain(), heard = listen(g);
    final s = idle(g, 'soldier', 2, 3)
      ..busyUntil = hold
      ..relics.add(Relic.lastStand);
    g
      ..startWave()
      ..queue.clear();
    final orc = foeAt(g, 'orc', s.pos + const Point(12, 0));
    s.hp = s.maxHp * 0.25 + hitTaken(orc.stats.dmg, s.stats.def) - 0.5;
    strikeBy(g, orc);
    expect(s.ironWillUsed, isTrue);
    return (g, heard, s);
  },
  HealSrc.grail: () {
    final g = plain(), heard = listen(g);
    final s = idle(g, 'soldier', 2, 3)..busyUntil = hold;
    g
      ..givePusaka(Relic.grail, type: 'soldier')
      ..startWave()
      ..queue.clear();
    final orc = foeAt(g, 'orc', s.pos + const Point(12, 0));
    s.hp = 1;
    strikeBy(g, orc);
    expect((s.alive, s.fxOnce), (true, true));
    return (g, heard, s);
  },
};

/// What every hp write in lib/ outside the two funnels is, by file (the trimmed line): no heal. A new one fails the
/// guard: a troop's heal goes through `_healTroop`, a monster's through `_healMonster` (lib/heal.dart, step 0g, where
/// `Status.noHeal` makes it 0); anything else is listed here, with why.
const notHeals = <String, List<String>>{
  'boss_skills.dart': [
    'm.hp = m.maxHp * graveCallK.hp;', // Grave Call: a monster raised from a grave
  ],
  'dungeon.dart': [
    '..hp = c.stats.hp.toDouble()', // a Dungeon party member made: a new copy of a picked troop at full HP (the army's untouched)
    '..hp = 0', // a unit falling inside a trip (_dungeonFell): no heal
  ],
  'game.dart': [
    'u.hp = min(u.hp + max(0, u.maxHp - before), u.maxHp.toDouble());', // _refit: the HP its new max HP brings
    'u.hp = min(hp, u.maxHp.toDouble());', // _loadedHpBack: the saved HP, capped (fromJson)
  ],
  'heal.dart': [
    'u.hp = inWave && scar > 0 ? max(u.hp, min(full * (1 - scar), to)) : min(full, to);', // the troop funnel itself (Scar's ceiling)
    'u.hp = to;', // the monster funnel (none under noHeal)
  ],
  'hero_skills.dart': [
    '..hp = r.maxHp * reviveK.hp', // Resurrection: a fallen troop back as a new one, not a heal
    '..hp = share * s.hp;', // a hexed monster's stats swapped
  ],
  'omen.dart': [
    '..hp = min(1.0, before);', // Deathless: a deadly blow stopped at 1 HP (it took only what the monster lost), no heal
    'if (pay > 0) u.hp = max(u.hp, min(healCeil(u), u.hp + pay));', // Trickle: a funnel heal (heard at its call) landing over its time
  ],
  'monster_skill_signatures.dart': [
    '..hp = min(1.0, stand)', // Reassemble's heap: kept from falling, never under noHeal (_reassembles asks first)
  ],
  'pusaka_engine.dart': [
    '..hp = 0; // the save lifts it from nothing (heal.dart: never under Wound)', // the Grail's save, then the funnel
    '..hp = r.maxHp * b.k', // Phoenix Plume: a fallen troop back as a new one (Resurrection's way), not a heal
  ],
};

void main() {
  group('every heal site goes through the funnel with its tag', () {
    test('the table covers every tag', () {
      expect(sites.keys.toSet(), HealSrc.values.toSet());
    });

    for (final MapEntry(key: src, value: scene) in sites.entries) {
      final kind = switch (src) { HealSrc.grail => HealKind.grail, HealSrc.queue => HealKind.between, _ => HealKind.inWave };
      test('${src.name}: its troop is healed through the funnel, as ${kind.name}', () {
        final (_, heard, u) = scene();
        final mine = heard.where((h) => h.u == u && h.src == src).toList();
        expect(mine, isNotEmpty, reason: 'heard: ${[for (final h in heard) h.src.name]}');
        expect(mine.map((h) => h.kind).toSet(), {kind});
        expect(mine.every((h) => h.asked > 0), isTrue);
      });
    }

    test('the after-wave heal carried into the next wave is still between waves; regen after the win is too', () {
      final g = plain()
        ..gold = 1000
        ..retreatPolicy = RuleRetreatPolicy(RetreatBrain(carryHealQueue: true))
        ..givePusaka(Relic.dragonHeart, type: 'knight');
      final heard = listen(g);
      placeNow(g, 'priest', 0, 3);
      final k = placeNow(g, 'knight', 3, 3)..hp = 50;
      winWave(g);
      g.tick(0.05);
      expect(heard.where((h) => h.u == k && h.src == HealSrc.regen).last.kind, HealKind.between, reason: 'regen after the win');
      g
        ..startWave()
        ..queue.clear();
      foeAt(g, 'orc', const Point(300, 10)); // the wave goes on
      tickUntil(g, () => heard.any((h) => h.src == HealSrc.queue), victoryTime + 2);
      expect(g.waveActive, isTrue);
      expect(heard.where((h) => h.src == HealSrc.queue).single.kind, HealKind.between);
      expect(heard.where((h) => h.u == k && h.src == HealSrc.regen).last.kind, HealKind.inWave, reason: 'regen in the wave');
    });

    test("a monster's heal at a shared site is no troop heal: a healing necromancer's", () {
      final g = plain(), heard = listen(g);
      final necro = foeAt(g, necroHealer, const Point(250, 60))..busyUntil = double.negativeInfinity;
      final orc = foeAt(g, 'orc', const Point(260, 60))..hp = 10;
      tickUntil(g, () => orc.hp > 10);
      expect(orc.hp, greaterThan(10), reason: 'the necromancer healed it');
      expect(heard, isEmpty);
      expect(necro.alive, isTrue);
    });
  });

  test('static guard: no hp write in lib/ outside the two funnels but the listed ones (none a heal)', () {
    final write = RegExp(r'(\.|\.\.)hp\s*(\+=|=(?![=>]))');
    final found = <String, List<String>>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final name = f.uri.pathSegments.last;
      for (final line in f.readAsLinesSync()) {
        final code = line.trimLeft();
        if (code.startsWith('//') || !write.hasMatch(code)) continue;
        (found[name] ??= []).add(code.trim());
      }
    }
    expect(found, notHeals,
        reason: "a troop's heal goes through _healTroop, a monster's through _healMonster (lib/heal.dart); a non-heal is "
            'listed in notHeals with why');
  });

  group("Wound's factor", () {
    test("cuts a heal in a wave by its factor: a healer's heal, regen, a worn fang", () {
      for (final src in [HealSrc.heal, HealSrc.regen, HealSrc.fang]) {
        final g = plain()..woundForce = 0.5;
        if (src == HealSrc.regen) g.givePusaka(Relic.dragonHeart, type: 'knight');
        if (src == HealSrc.heal) placeNow(g, 'priest', 0, 3);
        final k = placeNow(g, 'knight', 2, 3)..hp = 10;
        if (src == HealSrc.fang) {
          k.relics.add(Relic.fang);
        } else {
          k.cd = hold;
        }
        foeAt(g, 'orc', src == HealSrc.fang ? k.pos + const Point(14, 0) : const Point(250, 60)).hp = 100000;
        final heard = listen(g);
        tickUntil(g, () => heard.any((h) => h.src == src));
        final asked = heard.where((h) => h.u == k).fold(0.0, (a, h) => a + h.asked);
        expect(asked, greaterThan(0), reason: src.name);
        expect(k.hp - 10, closeTo(asked * 0.5, 1e-9), reason: src.name);
      }
    });

    test("never the Grail's save, the after-wave heal or a heal between waves", () {
      final g = plain()..woundForce = 0.5;
      final s = idle(g, 'soldier', 2, 3)..busyUntil = hold;
      g
        ..givePusaka(Relic.grail, type: 'soldier')
        ..startWave()
        ..queue.clear();
      final orc = foeAt(g, 'orc', s.pos + const Point(12, 0));
      s.hp = 1;
      strikeBy(g, orc);
      expect(s.hp, s.maxHp * grailK.hpLeft[0]);

      final q = plain()
        ..gold = 1000
        ..woundForce = 0.5;
      placeNow(q, 'priest', 0, 3);
      final k = placeNow(q, 'knight', 3, 3)..hp = 50;
      winWave(q);
      tickUntil(q, () => k.hp == k.maxHp, victoryTime + 2);
      expect(k.hp, k.maxHp.toDouble(), reason: 'all its HP back');

      final r = plain()
        ..woundForce = 0.5
        ..givePusaka(Relic.dragonHeart, type: 'knight');
      final rk = idle(r, 'knight', 2, 3)..hp = 50;
      expect(r.waveActive, isFalse);
      r.tick(0.05);
      expect(rk.hp, closeTo(50 + rk.stats.regen * 0.05, 1e-9), reason: 'regen between waves, uncut');
    });

    test('with no factor set it is 1: a heal is exactly what it was', () {
      final (_, heard, k) = sites[HealSrc.heal]!();
      final h = heard.firstWhere((h) => h.u == k);
      expect(k.hp, 50 + h.asked);
    });
  });

  test('the funnel returns the heal past full HP: none while it lacks more, the rest beyond', () {
    // The heal alone: with keepSupports the priest, far behind the knight walking on, would walk up before a light heal
    // (decisions-log 324).
    final g = plain()..keepSupports = false, heard = listen(g);
    final p = placeNow(g, 'priest', 0, 3);
    final k = idle(g, 'knight', 2, 3)..hp = 50;
    foeAt(g, 'orc', const Point(250, 60));
    tickUntil(g, () => heard.isNotEmpty);
    expect(heard.single.past, 0);
    final heal = p.stats.dmg;
    k.hp = k.maxHp - heal / 4;
    p.cd = 0;
    tickUntil(g, () => heard.length == 2);
    expect(k.hp, k.maxHp.toDouble());
    expect(heard.last.past, closeTo(heal * 3 / 4, 1e-9));
  });

  group('the ward', () {
    test('at most wardMax of max HP, from any number of gifts; a smaller most stops lower, never cuts one there', () {
      final g = plain(), k = idle(g, 'knight', 2, 3), most = k.maxHp * wardMax;
      expect(wardMax, 0.20);
      expect(g.giveWard(k, 1e6), closeTo(most, 1e-9));
      expect(g.giveWard(k, 5), 0);
      expect(k.ward, closeTo(most, 1e-9));
      k.ward = 0;
      expect(g.giveWard(k, 1e6, most: 0.1), closeTo(k.maxHp * 0.1, 1e-9));
      expect(g.giveWard(k, 1e6, most: 0.5), closeTo(most - k.maxHp * 0.1, 1e-9), reason: 'never past wardMax');
      expect(g.giveWard(k, 5, most: 0.1), 0);
      expect(k.ward, closeTo(most, 1e-9));
    });

    test('a blow breaks it before the HP', () {
      double loss({double ward = 0}) {
        final g = plain(), k = idle(g, 'knight', 2, 3)..busyUntil = hold;
        expect(g.giveWard(k, ward), ward);
        final bear = foeAt(g, 'werebear', k.pos + const Point(12, 0));
        strikeBy(g, bear);
        expect(k.ward, max(0.0, ward - hitTaken(bear.stats.dmg, k.stats.def)));
        return k.maxHp - k.hp;
      }

      final full = loss();
      expect(full, inInclusiveRange(10, troopTypes['knight']!.hp * wardMax), reason: 'a blow a ward can take whole');
      expect(loss(ward: 10), closeTo(full - 10, 1e-9));
      expect(loss(ward: full), 0);
    });

    test('it ends with the wave', () {
      final g = plain(), k = idle(g, 'knight', 2, 3);
      g
        ..startWave()
        ..queue.clear();
      foeAt(g, 'orc', const Point(300, 10));
      g.giveWard(k, 20);
      g.tick(0.05);
      expect(k.ward, 20);
      g.enemies.single.gone = true;
      g.tick(0.05);
      expect(g.waveActive, isFalse);
      expect(k.ward, 0);
    });
  });
}
