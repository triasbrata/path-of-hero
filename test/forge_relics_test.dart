// The forge's nine small relics' effects and the hidden combos (decisions-log 250; lib/relics.dart; forge-design §5, §6;
// docs/loot-items-relics.md "The forge's nine relics"): each relic alone at its town.json numbers (the bosses' halves,
// Reaper on a boss), the four hidden pairings on and off, the relics' cap (combos.relicMost 3.0: Giant Slayer + the Fury
// beat, under Relic Altar), the design's combos C1-C9, the cards (each its own effect only), the report's and the
// telemetry's counters, and the Towns off (tests only): the nine do nothing and the eleven are as before the forge.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/telemetry.dart';

import 'hero_skill_helpers.dart';

/// A [bareGame] with no skills of any kind and no monster skills, the Towns (and with them the forge) on: what happens is
/// the relics' doing. [towns] false: the Towns off (a plain Game()'s rules, tests only; the forge-off build is gone,
/// decisions-log 296).
Game plain({bool towns = true}) => bareGame(Random(1))
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false
  ..monsterSkills = false
  ..towns = towns;

/// A troop of [type] at cell ([c], [r]) holding [relics] (a Hero when [hero]), standing until told to strike.
Unit holder(Game g, String type, int c, int r, List<Relic> relics, {bool hero = false}) => placeNow(g, type, c, r)
  ..relics.addAll(relics)
  ..hero = hero
  ..busyUntil = hold;

/// A monster of [tier] at [at] with no defence and [hp] of [hp] HP (its max too), that never moves or fights: a blow's
/// HP lost is the blow itself.
Unit dummy(Game g, Point<double> at, {Tier tier = Tier.normal, int hp = 100000}) {
  final f = foeAt(g, 'orc', at, tier);
  f.stats = const Stats(hp: 100000, cost: 0, speed: 0, dmg: 0, range: 0, rate: 1);
  return f
    ..maxHp = hp
    ..hp = hp.toDouble();
}

/// [u] strikes once now: its cooldown cleared, one short tick, then it stands (a shot still flies: [land]).
void strikeOnce(Game g, Unit u) {
  u
    ..busyUntil = double.negativeInfinity
    ..cd = 0;
  g.tick(0.05);
  u.busyUntil = hold;
}

/// Ticks until every shot in the air has landed (at most 2 s).
void land(Game g) {
  for (var i = 0; i < 40 && g.shots.isNotEmpty; i++) {
    g.tick(0.05);
  }
  expect(g.shots, isEmpty);
}

/// The HP [f] lost while [act] ran.
double lost(Unit f, void Function() act) {
  final before = f.hp;
  act();
  return before - f.hp;
}

/// The HP one strike of [u] took off [f] (a shot's once it landed).
double blow(Game g, Unit u, Unit f) => lost(f, () {
      strikeOnce(g, u);
      land(g);
    });

/// One strike of [u] on [f] as a multiple of [u]'s attack ([blow] ÷ its damage; [f] has no defence).
double x(Game g, Unit u, Unit f) => blow(g, u, f) / u.stats.dmg;

/// The bleed on [f] in all: its tick × its ticks left.
double bleedLeft(Game g, Unit f) => switch (g.effectOn(f, Status.bleed)) { final e? => e.k * e.n, _ => 0 };

/// Next to a troop at [p]: where its melee blow reaches.
Point<double> next(Point<double> p) => p + const Point(12, 0);

const nine = [
  Relic.chill, Relic.sharkTooth, Relic.grit, Relic.ambush, Relic.weakSpot, Relic.hotStreak, Relic.avalanche, //
  Relic.afterglow, Relic.reaper,
];

void main() {
  test('the nine are the forge\'s, in Relic order; their numbers are town.json\'s', () {
    expect(forgeRelics, nine);
    final g = plain();
    expect({for (final r in nine) r: g.townRules.relics[r.name]}, {
      Relic.chill: {'every': 3, 'slow': 0.30, 'secs': 1.5, 'bossShare': 0.5},
      Relic.sharkTooth: {'k': 1.25},
      Relic.grit: {'below': 0.50, 'k': 1.30},
      Relic.ambush: {'k': 1.35},
      Relic.weakSpot: {'taken': 1.12, 'boss': 1.06, 'secs': 3.0},
      Relic.hotStreak: {'per': 0.10, 'most': 3, 'secs': 4.0},
      Relic.avalanche: {'per': 0.08, 'most': 5, 'reach': 2.0},
      Relic.afterglow: {'hits': 3, 'k': 1.5},
      Relic.reaper: {'below': 0.15, 'bossK': 1.5},
    });
    expect(g.townRules.combos.relicMost, 3.0);
  });

  group('each alone', () {
    test('Chill: every 3rd hit that lands slows 30% for 1.5 s, on its own count; a mini boss or the boss 15%', () {
      for (final tier in [Tier.normal, Tier.elite, Tier.miniBoss, Tier.boss]) {
        final g = plain(), k = holder(g, 'knight', 2, 3, [Relic.chill]), f = dummy(g, next(k.pos), tier: tier);
        strikeOnce(g, k);
        strikeOnce(g, k);
        expect(g.effectOn(f, Status.slow), isNull, reason: '${tier.name}: two hits');
        strikeOnce(g, k);
        final e = g.effectOn(f, Status.slow)!, big = tier == Tier.miniBoss || tier == Tier.boss;
        expect(e.k, closeTo(big ? 0.85 : 0.70, 1e-9), reason: tier.name);
        expect(e.by, k);
        expect(g.relicWorth[Relic.chill]!.uses, 1);
        expect(k.chillHits, 3);
        runFor(g, 1.4);
        expect(g.held(f), isTrue, reason: 'slowed is held');
        runFor(g, 0.2);
        expect(g.effectOn(f, Status.slow), isNull, reason: '1.5 s');
        for (var i = 0; i < 3; i++) {
          strikeOnce(g, k);
        }
        expect(g.relicWorth[Relic.chill]!.uses, 2, reason: 'the 6th hit');
      }
    });

    test('Chill: a shot slows where it lands; a smite counts nothing; a patch moves its numbers', () {
      final g = plain(), a = holder(g, 'archer', 1, 3, [Relic.chill]), f = dummy(g, a.pos + const Point(50, 0));
      a.chillHits = 2;
      strikeOnce(g, a);
      expect(g.effectOn(f, Status.slow), isNull, reason: 'in flight');
      land(g);
      expect(g.effectOn(f, Status.slow)!.k, closeTo(0.7, 1e-9));

      final h = plain(), p = holder(h, 'priest', 1, 3, [Relic.chill]);
      foeAt(h, 'skeleton', p.pos + const Point(60, 0)).hp = 10000;
      for (var i = 0; i < 3; i++) {
        strikeOnce(h, p);
      }
      expect(p.chillHits, 0, reason: 'a smite is no hit of its');

      final q = plain()..townRules = TownRules.patch({'relics': {'chill': {'every': 1, 'slow': 0.5}}});
      final k = holder(q, 'knight', 2, 3, [Relic.chill]), d = dummy(q, next(k.pos));
      strikeOnce(q, k);
      expect(q.effectOn(d, Status.slow)!.k, closeTo(0.5, 1e-9));
    });

    test('Shark Tooth: x1.25 on a bleeding or poisoned monster, before defence; none on a clean one', () {
      final g = plain(), k = holder(g, 'knight', 2, 3, [Relic.sharkTooth]), f = dummy(g, next(k.pos));
      expect(blow(g, k, f), closeTo(20, 1e-9));
      g.addEffect(f, Status.bleed, 5, k: 0.01, n: 5);
      expect(blow(g, k, f), closeTo(25, 1e-9));
      expect(g.relicWorth[Relic.sharkTooth]!.worth, closeTo(5, 1e-9), reason: 'the damage it added');
      final o = foeAt(g, 'orc', next(k.pos))..hp = 10000;
      f.gone = true;
      g.tick(0.01);
      g.addEffect(o, Status.bleed, 5, k: 0.01, n: 5);
      expect(blow(g, k, o), closeTo(hitTaken(25, o.stats.def), 1e-9), reason: 'through its defence');
    });

    test('Grit: x1.3 while under 50% HP; at 50% nothing', () {
      final g = plain(), k = holder(g, 'knight', 2, 3, [Relic.grit]), f = dummy(g, next(k.pos));
      k.hp = k.maxHp * 0.5;
      expect(blow(g, k, f), closeTo(20, 1e-9));
      k.hp = k.maxHp * 0.5 - 1;
      expect(blow(g, k, f), closeTo(26, 1e-9));
    });

    test('Ambush: x1.35 on a slowed, pinned, stunned or hexed monster; none on a free one', () {
      void on(String why, void Function(Game g, Unit f) hold, double k) {
        final g = plain(), u = holder(g, 'knight', 2, 3, [Relic.ambush]), f = dummy(g, next(u.pos));
        hold(g, f);
        expect(blow(g, u, f), closeTo(20 * k, 1e-9), reason: why);
      }

      on('free', (g, f) {}, 1);
      on('slowed', (g, f) => g.addEffect(f, Status.slow, 5, k: 0.9), 1.35);
      on('pinned', (g, f) => g.addEffect(f, Status.impaled, 5, k: 0.5), 1.35);
      on('stunned', (g, f) => f.stunUntil = g.t + 5, 1.35);
    });

    test('Weak Spot: its hits mark 3 s: +12% from every troop (a mini boss or the boss +6%); a stronger mark stays', () {
      final g = plain(), k = holder(g, 'knight', 2, 3, [Relic.weakSpot]), f = dummy(g, next(k.pos));
      final archer = holder(g, 'archer', 1, 3, []);
      expect(blow(g, k, f), closeTo(20, 1e-9), reason: 'the mark comes as the blow lands');
      final e = g.effectOn(f, Status.vulnerable)!;
      expect(e.k, closeTo(1.12, 1e-9));
      expect((e.by, f.weakMark), (k, e));
      expect(blow(g, archer, f), closeTo(9 * 1.12, 1e-9), reason: "another troop's shot");
      expect(g.relicWorth[Relic.weakSpot]!.uses, 1);
      expect(g.relicWorth[Relic.weakSpot]!.worth, closeTo(9 * 0.12, 1e-9), reason: 'what the mark added');
      runFor(g, 3.1);
      expect(g.effectOn(f, Status.vulnerable), isNull, reason: '3 s');

      final b = plain(), kb = holder(b, 'knight', 2, 3, [Relic.weakSpot]), boss = dummy(b, next(kb.pos), tier: Tier.boss);
      strikeOnce(b, kb);
      expect(b.effectOn(boss, Status.vulnerable)!.k, closeTo(1.06, 1e-9));

      final h = plain(), kh = holder(h, 'knight', 2, 3, [Relic.weakSpot]), m = dummy(h, next(kh.pos));
      h.addEffect(m, Status.vulnerable, 8, k: 1.25); // Hunter's Mark's
      strikeOnce(h, kh);
      expect(h.effectOn(m, Status.vulnerable)!.k, 1.25);
      expect((h.relicWorth[Relic.weakSpot]?.uses ?? 0, m.weakMark), (0, null));
    });

    test('Hot Streak: each kill +10% for 4 s, up to 3 stacks; the oldest gives way', () {
      final g = plain(), k = holder(g, 'knight', 2, 3, [Relic.hotStreak]);
      void kill() {
        final v = foeAt(g, 'orc', next(k.pos))..hp = 1;
        strikeOnce(g, k);
        expect(v.alive, isFalse);
        runFor(g, 0.7); // its body gone
      }

      double hit() {
        final f = dummy(g, next(k.pos)), d = blow(g, k, f);
        f.gone = true;
        g.tick(0.01);
        return d;
      }

      expect(hit(), closeTo(20, 1e-9));
      kill();
      expect(hit(), closeTo(22, 1e-9));
      kill();
      kill();
      expect(hit(), closeTo(26, 1e-9));
      kill();
      expect(k.streak, hasLength(3), reason: 'at most 3');
      expect(hit(), closeTo(26, 1e-9));
      runFor(g, 4.1);
      expect(hit(), closeTo(20, 1e-9), reason: 'each lasts 4 s');
    });

    test('Avalanche: +8% for each other monster within 2 tiles of its target, up to 5', () {
      double withNear(int near, {double at = 1.9}) {
        final g = plain(), k = holder(g, 'knight', 2, 3, [Relic.avalanche]), f = dummy(g, next(k.pos));
        for (var i = 0; i < near; i++) {
          final a = 2 * pi * i / max(near, 1) - pi / 2;
          dummy(g, f.pos + Point(cos(a).abs() * at * tile, sin(a) * at * tile)); // away from the knight
        }
        return blow(g, k, f) / 20;
      }

      expect(withNear(0), closeTo(1, 1e-9));
      expect(withNear(4), closeTo(1.32, 1e-9));
      expect(withNear(5), closeTo(1.40, 1e-9));
      expect(withNear(7), closeTo(1.40, 1e-9), reason: 'up to 5');
      expect(withNear(4, at: 2.1), closeTo(1, 1e-9), reason: 'past 2 tiles');
    });

    test('Afterglow: after a skill cast its next 3 hits deal x1.5', () {
      final (g, hero) = heroCaster(HeroSkill.cleave, Random(1));
      g.towns = true;
      hero.relics.add(Relic.afterglow);
      final f = dummy(g, next(hero.pos), tier: Tier.miniBoss);
      expect(lost(f, () => runFor(g, 0.3)), greaterThan(0), reason: 'the Hero cast its Cleave');
      expect(hero.glow, 3);
      expect([for (var i = 0; i < 4; i++) blow(g, hero, f)], [30, 30, 30, 20]);
      expect(g.relicWorth[Relic.afterglow]!.uses, 3);
    });

    test('Reaper: a hit that leaves a monster under 15% HP ends it; a mini boss or the boss never, x1.5 there instead', () {
      final g = plain(), k = holder(g, 'knight', 2, 3, [Relic.reaper]);
      final at = dummy(g, next(k.pos), hp: 1000)..hp = 170; // left at 150: not under
      strikeOnce(g, k);
      expect(at.hp, 150);
      final under = dummy(g, next(k.pos), hp: 1000)..hp = 169;
      at.gone = true;
      g.tick(0.01);
      strikeOnce(g, k);
      expect((under.alive, g.relicWorth[Relic.reaper]!.uses), (false, 1));
      expect(g.relicWorth[Relic.reaper]!.worth, closeTo(149, 1e-9), reason: 'the HP it took past the blow');
      for (final tier in [Tier.miniBoss, Tier.boss]) {
        final b = plain(), kb = holder(b, 'knight', 2, 3, [Relic.reaper]), boss = dummy(b, next(kb.pos), tier: tier, hp: 1000);
        boss.hp = 151;
        expect(blow(b, kb, boss), closeTo(20, 1e-9), reason: '${tier.name}: at 15.1%');
        expect((boss.alive, boss.hp), (true, 131), reason: '${tier.name}: left under 15%, never ended');
        expect(blow(b, kb, boss), closeTo(30, 1e-9), reason: '${tier.name}: under 15%: x1.5');
      }
    });
  });

  group('the hidden pairings (combos.secret): on with their partner, off without or patched away', () {
    Game noSecrets() => plain()..townRules = const TownRules(combos: Combos(secrets: {}));

    test('Venom + Shark Tooth on one Hero: the poison is 30% of the hit, not 20%', () {
      for (final (g, relics, share) in [
        (plain(), [Relic.venom, Relic.sharkTooth], 0.30),
        (plain(), [Relic.venom], 0.20),
        (noSecrets(), [Relic.venom, Relic.sharkTooth], 0.20),
        (plain(towns: false), [Relic.venom, Relic.sharkTooth], 0.20),
      ]) {
        final h = holder(g, 'knight', 2, 3, relics, hero: true), f = dummy(g, next(h.pos));
        expect(g.relicKOf(h, Relic.venom, 'share'), share);
        strikeOnce(g, h);
        expect(bleedLeft(g, f), closeTo(20 * share, 1e-9), reason: '$relics');
      }
    });

    test('Sweep + Avalanche on one Hero: Sweep hits 2 monsters, the nearest first', () {
      for (final (g, relics, swept) in [
        (plain(), [Relic.cleave, Relic.avalanche], 2),
        (plain(), [Relic.cleave], 1),
        (noSecrets(), [Relic.cleave, Relic.avalanche], 1),
      ]) {
        final h = holder(g, 'knight', 2, 3, relics, hero: true), f = dummy(g, next(h.pos));
        final near = [for (final dy in [10.0, -12.0, 14.0]) dummy(g, f.pos + Point(4, dy))];
        strikeOnce(g, h);
        expect([for (final o in near) o.hp < o.maxHp], [for (var i = 0; i < 3; i++) i < swept], reason: '$relics');
      }
    });

    test("Weak Spot on a type with Void Eye bound: its mark +20%, not +12% (a boss's +6% as it is)", () {
      for (final (bound, k) in [(true, 1.20), (false, 1.12)]) {
        final g = plain();
        if (bound) g.givePusaka(Relic.voidEye, type: 'knight');
        final w = holder(g, 'knight', 2, 3, [Relic.weakSpot]), f = dummy(g, next(w.pos));
        strikeOnce(g, w);
        expect(g.effectOn(f, Status.vulnerable)!.k, closeTo(k, 1e-9), reason: 'Void Eye bound: $bound');
        expect(g.relicKOf(w, Relic.weakSpot, 'boss'), 1.06);
      }
      final g = plain()..givePusaka(Relic.voidEye, type: 'archer');
      final w = holder(g, 'knight', 2, 3, [Relic.weakSpot]);
      expect(g.relicKOf(w, Relic.weakSpot, 'taken'), 1.12, reason: 'bound to another type');
    });

    test('Chill on a type with Snare Cord bound: every 2nd hit, not every 3rd', () {
      for (final (bound, every) in [(true, 2), (false, 3)]) {
        final g = plain();
        if (bound) g.givePusaka(Relic.snareCord, type: 'knight');
        final c = holder(g, 'knight', 2, 3, [Relic.chill]), f = dummy(g, next(c.pos));
        for (var i = 1; i <= every; i++) {
          expect(g.effectOn(f, Status.slow)?.k == 0.7, isFalse, reason: 'before hit $i');
          strikeOnce(g, c);
        }
        expect(g.effectOn(f, Status.slow)!.k, closeTo(0.7, 1e-9), reason: 'Snare Cord bound: $bound');
      }
    });
  });

  group("the relics' cap (combos.relicMost): their factors on one blow, the Artifacts' outside", () {
    /// The multiples of [n] blows of a knight Hero holding [relics] on a [tier] dummy (its type holding [artifacts]).
    List<double> blows(List<Relic> relics, {int n = 3, Tier tier = Tier.boss, List<Relic> artifacts = const [], bool towns = true,
        void Function(Game g, Unit h)? before}) {
      final g = plain(towns: towns);
      for (final a in artifacts) {
        g.givePusaka(a, type: 'knight');
      }
      final h = holder(g, 'knight', 2, 3, relics, hero: true), f = dummy(g, next(h.pos), tier: tier);
      before?.call(g, h);
      return [for (var i = 0; i < n; i++) x(g, h, f)];
    }

    test('Giant Slayer + the Fury beat on a boss: exactly 3.0, the cap', () {
      final x = blows([Relic.giantSlayer, Relic.fury]);
      expect(x, [closeTo(1.5, 1e-9), closeTo(1.5, 1e-9), closeTo(3.0, 1e-9)]);
    });

    test('under Relic Altar (the beat x2.5): 3.75 with the Towns off (tests only), capped to 3.0 with them', () {
      final off = blows([Relic.giantSlayer, Relic.fury], artifacts: [Relic.relicAltar], towns: false);
      expect(off.last, closeTo(3.75, 1e-9), reason: "today's rules");
      final on = blows([Relic.giantSlayer, Relic.fury], artifacts: [Relic.relicAltar]);
      expect(on, [closeTo(1.5, 1e-9), closeTo(1.5, 1e-9), closeTo(3.0, 1e-9)]);
    });

    test('Afterglow + the Fury beat: 3.0 at the cap; with Grit too (3.9) cut to 3.0', () {
      void glow(Game g, Unit h) => h.glow = 3;
      expect(blows([Relic.afterglow, Relic.fury], tier: Tier.normal, before: glow).last, closeTo(3.0, 1e-9));
      final g = blows([Relic.afterglow, Relic.fury], tier: Tier.normal, before: (g, h) {
        glow(g, h);
        h.relics.add(Relic.grit); // a test's third
        h.hp = h.maxHp * 0.4;
      });
      expect(g, [closeTo(1.95, 1e-9), closeTo(1.95, 1e-9), closeTo(3.0, 1e-9)]);
    });

    test("an Artifact's power stays outside it: + Titan Bane on the boss, the beat 3.0 x1.15", () {
      final x = blows([Relic.giantSlayer, Relic.fury], artifacts: [Relic.titanBane]);
      expect(x, [closeTo(1.5 * 1.15, 1e-9), closeTo(1.5 * 1.15, 1e-9), closeTo(3.0 * 1.15, 1e-9)]);
    });

    test('a patch moves the cap', () {
      final g = plain()..townRules = TownRules.patch({'combos': {'relicMost': 2.0}});
      final h = holder(g, 'knight', 2, 3, [Relic.giantSlayer, Relic.fury], hero: true), f = dummy(g, next(h.pos), tier: Tier.boss);
      expect([for (var i = 0; i < 3; i++) x(g, h, f)], [closeTo(1.5, 1e-9), closeTo(1.5, 1e-9), closeTo(2.0, 1e-9)]);
    });
  });

  group('the combos C1-C9 (forge-design §6): their multiples per hit', () {
    test('C1 Venom + Shark Tooth (a Hero): x1.62 a hit on a poisoned monster, poison in (x1.50 without the pairing)', () {
      for (final (g, x) in [(plain(), 1.625), (plain()..townRules = const TownRules(combos: Combos(secrets: {})), 1.5)]) {
        final h = holder(g, 'knight', 2, 3, [Relic.venom, Relic.sharkTooth], hero: true), f = dummy(g, next(h.pos));
        strikeOnce(g, h); // the first poisons
        final hit = blow(g, h, f);
        expect((hit + bleedLeft(g, f)) / h.stats.dmg, closeTo(x, 1e-9));
      }
    });

    test('C2 Chill + Ambush (a Hero): x1.35 on the chilled hits; x1.755 with Bully\'s Club', () {
      for (final (artifacts, k) in [(<Relic>[], 1.35), ([Relic.bullyClub], 1.35 * 1.3)]) {
        final g = plain();
        for (final a in artifacts) {
          g.givePusaka(a, type: 'knight');
        }
        final h = holder(g, 'knight', 2, 3, [Relic.chill, Relic.ambush], hero: true), f = dummy(g, next(h.pos));
        final hits = [for (var i = 0; i < 4; i++) x(g, h, f)];
        expect(hits, [1, 1, 1, closeTo(k, 1e-9)], reason: 'the 3rd chills, the 4th lands on a held one');
      }
    });

    test('C3 Weak Spot + Void Eye: x1.50 (x1.40 without the pairing)', () {
      for (final (g, k) in [(plain(), 1.5), (plain()..townRules = const TownRules(combos: Combos(secrets: {})), 1.4)]) {
        g.givePusaka(Relic.voidEye, type: 'knight');
        final w = holder(g, 'knight', 2, 3, [Relic.weakSpot]), f = dummy(g, next(w.pos));
        strikeOnce(g, w); // both marks go on
        expect(x(g, w, f), closeTo(k, 1e-9));
      }
    });

    test('C4 Sweep + Avalanche (a Hero), 4 near: the pack takes x2.11 (x1.72 without the pairing)', () {
      for (final (g, k) in [(plain(), 2.112), (plain()..townRules = const TownRules(combos: Combos(secrets: {})), 1.716)]) {
        final h = holder(g, 'knight', 2, 3, [Relic.cleave, Relic.avalanche], hero: true), f = dummy(g, next(h.pos));
        final pack = [
          f, // two within Sweep's 1.5 tiles, two more within Avalanche's 2
          for (final p in [const Point(4.0, 10.0), const Point(4.0, -10.0), const Point(20.0, 18.0), const Point(20.0, -18.0)]) dummy(g, f.pos + p),
        ];
        final before = [for (final o in pack) o.hp];
        strikeOnce(g, h);
        final took = [for (var i = 0; i < pack.length; i++) before[i] - pack[i].hp].reduce((a, b) => a + b);
        expect(took / h.stats.dmg, closeTo(k, 1e-9));
      }
    });

    test('C5 Mana Siphon + Afterglow: the hits a cast charges are x1.5 (the siphon brings the casts sooner)', () {
      final (g, hero) = heroCaster(HeroSkill.cleave, Random(1));
      g.towns = true;
      hero.relics.addAll([Relic.manaSiphon, Relic.afterglow]);
      final f = dummy(g, next(hero.pos), tier: Tier.miniBoss);
      runFor(g, 0.3);
      final mp = hero.mp;
      expect(x(g, hero, f), 1.5);
      expect(hero.mp, greaterThanOrEqualTo(mp + 2), reason: 'the siphon: +2 MP a hit, toward the next cast');
    });

    test('C6 Hot Streak + Momentum: 3 stacks x1.3, the blow after a kill x1.69', () {
      final g = plain()..givePusaka(Relic.momentum, type: 'knight');
      final k = holder(g, 'knight', 2, 3, [Relic.hotStreak]);
      for (var i = 0; i < 3; i++) {
        foeAt(g, 'orc', next(k.pos)).hp = 1;
        strikeOnce(g, k);
        runFor(g, 0.7);
      }
      final f = dummy(g, next(k.pos));
      expect([x(g, k, f), x(g, k, f)], [closeTo(1.69, 1e-9), closeTo(1.3, 1e-9)]);
    });

    test('C7 Reaper + Finishing Blade: a monster falls in fewer hits (x1.2 or so, the model x1.21)', () {
      int hitsToKill(List<Relic> relics, List<Relic> artifacts) {
        final g = plain();
        for (final a in artifacts) {
          g.givePusaka(a, type: 'knight');
        }
        final k = holder(g, 'knight', 2, 3, relics), f = dummy(g, next(k.pos), hp: 1000);
        var n = 0;
        while (f.alive && n < 100) {
          strikeOnce(g, k);
          n++;
        }
        return n;
      }

      final plainHits = hitsToKill([], []), both = hitsToKill([Relic.reaper], [Relic.finishingBlade]);
      expect(plainHits, 50);
      expect(hitsToKill([Relic.reaper], []), 43, reason: 'the last 15% free: 1000 - 20 x 42 = 160, the 43rd ends it');
      expect(plainHits / both, closeTo(1.21, 0.05));
    });

    test('C8 Grit + Rage Totem under 50% HP: x2.08', () {
      final g = plain()..givePusaka(Relic.rageTotem, type: 'knight');
      final k = holder(g, 'knight', 2, 3, [Relic.grit]), f = dummy(g, next(k.pos));
      k.hp = k.maxHp * 0.4;
      expect(x(g, k, f), closeTo(2.08, 1e-9));
    });

    test('C9 Giant Slayer + Fury on a boss: x2.00 a blow on average; with Titan Bane and Weak Spot x2.44', () {
      final g = plain()..givePusaka(Relic.titanBane, type: 'knight');
      final h = holder(g, 'knight', 2, 3, [Relic.giantSlayer, Relic.fury], hero: true);
      final w = holder(g, 'archer', 1, 3, [Relic.weakSpot]), boss = dummy(g, next(h.pos), tier: Tier.boss);
      strikeOnce(g, w);
      land(g);
      expect(g.effectOn(boss, Status.vulnerable)!.k, closeTo(1.06, 1e-9));
      final three = [for (var i = 0; i < 3; i++) x(g, h, boss)];
      expect(three.reduce((a, b) => a + b) / 3, closeTo(2.0 * 1.15 * 1.06, 1e-9));
      final p = plain();
      final hp = holder(p, 'knight', 2, 3, [Relic.giantSlayer, Relic.fury], hero: true), bp = dummy(p, next(hp.pos), tier: Tier.boss);
      expect([for (var i = 0; i < 3; i++) x(p, hp, bp)].reduce((a, b) => a + b) / 3, closeTo(2.0, 1e-9));
    });
  });

  group('the cards and the counters', () {
    test('each card says only its own effect: no other relic, no Artifact, no "combo"', () {
      final g = plain();
      for (final r in nine) {
        final texts = [...g.relicEffect(r), g.relicTierLine(r), ?g.relicBestLine(r), relicNames[r]!];
        final others = [for (final o in Relic.values) if (o != r) relicNames[o]!];
        for (final s in texts) {
          for (final o in others) {
            expect(RegExp('\\b${RegExp.escape(o)}\\b').hasMatch(s), isFalse, reason: '${relicNames[r]}: "$s" names $o');
          }
          expect(s.toLowerCase(), isNot(anyOf(contains('combo'), contains('pair'), contains('secret'))), reason: s);
        }
      }
      expect(g.relicEffect(Relic.reaper), ['Ends a monster under 15% HP at once (bosses: x1.5 damage)']);
      expect(g.relicEffect(Relic.chill), ['Every 3rd hit slows 30% for 1.5 s (bosses 15%)']);
    });

    test("a won wave's report has a row each for the nine that did something; the log's words name only the relic", () {
      final g = plain();
      final h = holder(g, 'knight', 2, 3, [Relic.chill, Relic.sharkTooth], hero: true)..busyUntil = double.negativeInfinity;
      g
        ..startWave()
        ..queue.clear();
      final f = foeAt(g, 'orc', next(h.pos))..hp = 200;
      g.addEffect(f, Status.bleed, 30, k: 0.01, n: 30);
      for (var n = 0; n < 400 && g.waveActive; n++) {
        g.tick(0.05);
      }
      expect(g.waveActive, isFalse);
      final r = g.lastPusaka!;
      expect([for (final d in r.relics) d.relic], [Relic.chill, Relic.sharkTooth]);
      final lines = pusakaReportLines(r);
      expect(lines, [
        'Chill: slowed ${r.relics[0].uses == 1 ? 'once' : '${r.relics[0].uses} times'}',
        'Shark Tooth: +${r.relics[1].worth.round()} damage',
      ]);
      expect(relicCounter((relic: Relic.weakSpot, uses: 9, worth: 812)), 'marked 9 times, +812 damage');
      expect(relicCounter((relic: Relic.avalanche, uses: 40, worth: 1234)), '+1.2k damage');
      expect(relicCounter((relic: Relic.chill, uses: 1, worth: 0)), 'slowed once');
      expect(r.data['relics'], {
        'chill': {'uses': r.relics[0].uses, 'worth': 0},
        'sharkTooth': {'uses': r.relics[1].uses, 'worth': r.relics[1].worth.round()},
      });
    });

    test("the telemetry's wave record: each relic's uses and worth, and each pair's troops and damage", () {
      final g = plain();
      final kept = _Kept();
      TelemetryAdapter([kept], installId: 'i', session: 's', platform: 'test', now: () => DateTime.utc(2026, 10, 4)).attach(g);
      g.givePusaka(Relic.snareCord, type: 'knight');
      final h = holder(g, 'knight', 2, 3, [Relic.chill, Relic.ambush], hero: true)..busyUntil = double.negativeInfinity;
      g
        ..startWave()
        ..queue.clear();
      expect(h.comboKey, 'chill+ambush@snareCord');
      foeAt(g, 'orc', next(h.pos)).hp = 300;
      for (var n = 0; n < 400 && g.waveActive; n++) {
        g.tick(0.05);
      }
      expect(g.waveActive, isFalse);
      final w = kept.records.lastWhere((r) => r['rec'] == 'wave');
      expect((w['relics'] as Map).keys, containsAll(['chill', 'ambush']));
      expect(w['relicPairs'], {
        'chill+ambush@snareCord': {'troops': 1, 'dealt': 300},
      });
    });

    test('the Towns off (tests only): no relics, no pairs in the record; the report has none of the nine', () {
      final g = plain(towns: false);
      final kept = _Kept();
      TelemetryAdapter([kept], installId: 'i', session: 's', platform: 'test', now: () => DateTime.utc(2026, 10, 4)).attach(g);
      final h = holder(g, 'knight', 2, 3, [Relic.chill, Relic.fury], hero: true)..busyUntil = double.negativeInfinity;
      g
        ..startWave()
        ..queue.clear();
      foeAt(g, 'orc', next(h.pos)).hp = 300;
      for (var n = 0; n < 400 && g.waveActive; n++) {
        g.tick(0.05);
      }
      final w = kept.records.lastWhere((r) => r['rec'] == 'wave');
      expect(w.containsKey('relics') || w.containsKey('relicPairs'), isFalse);
      expect(g.lastPusaka?.relics ?? const [], isEmpty);
      expect(h.comboKey, isNull);
    });
  });

  group('the Towns off (tests only): the nine do nothing, the eleven as before the forge', () {
    test('a troop holding all nine (a test\'s) strikes, marks, slows and ends nothing more', () {
      final g = plain(towns: false), k = holder(g, 'knight', 2, 3, nine), f = dummy(g, next(k.pos), hp: 1000);
      k
        ..hp = k.maxHp * 0.3
        ..glow = 3;
      g.addEffect(f, Status.bleed, 30, k: 0.001, n: 30);
      g.addEffect(f, Status.slow, 30, k: 0.9);
      f.hp = 169;
      final hits = [for (var i = 0; i < 3; i++) blow(g, k, f)];
      expect(hits, [20, 20, 20]);
      expect((g.effectOn(f, Status.vulnerable), g.effectOn(f, Status.slow)!.k, f.alive, k.glow), (null, 0.9, true, 3));
      expect(g.relicWorth, isEmpty);
    });

    test('the eleven: Giant Slayer + Fury uncapped, Venom 20%, Sweep one monster, whatever they hold', () {
      final g = plain(towns: false);
      final h = holder(g, 'knight', 2, 3, [Relic.venom, Relic.sharkTooth], hero: true), f = dummy(g, next(h.pos));
      strikeOnce(g, h);
      expect(bleedLeft(g, f), closeTo(h.stats.dmg * 0.2, 1e-9));
      expect(g.relicKOf(h, Relic.cleave, 'targets'), 1);
    });

    test('the save never writes their state: a Hero holding two of the nine round-trips as before', () {
      final g = Game(Random(1))
        ..boardRules()
        ..towns = true;
      final h = placeNow(g, 'knight', 2, 4)..hero = true;
      h.relics.addAll([Relic.chill, Relic.reaper]);
      h
        ..glow = 2
        ..chillHits = 5
        ..streak.add(3);
      final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
      final back = Game.fromJson(j, Random(1), Random(101), Random(301));
      final u = back.troops.firstWhere((u) => u.hero);
      expect(u.relics, [Relic.chill, Relic.reaper]);
      expect((u.glow, u.chillHits, u.streak.length), (0, 0, 0));
    });
  });
}

/// A sink that keeps what it gets (through JSON, as a file would).
class _Kept implements TelemetrySink {
  final records = <Map<String, dynamic>>[];

  @override
  void add(Map<String, Object?> record) => records.add(jsonDecode(jsonEncode(record)) as Map<String, dynamic>);

  @override
  Future<void> flush() async {}
}
