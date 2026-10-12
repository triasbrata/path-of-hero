// The Smithy's seven small relics (decisions-log 227; lib/relics.dart; docs/loot-items-relics.md "Relics"): Sweep (save
// key cleave), Venom, Mana Siphon, Spirit Ward (Strong), Iron Will (lastStand), Giant Slayer, Holy Charm (blessing)
// (Mighty). One group a relic, its numbers from the rules (town.json `relics`) at their edges and patched; a Hero holding
// two; the save's names; the tiers and their words; with the Towns off none of the seven ever shows or drops.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// A [bareGame] with no skills of any kind and no monster skills: what happens is the relics' doing.
Game plain() => bareGame(Random(1))
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false
  ..monsterSkills = false;

/// A troop of [type] at cell ([c], [r]) holding [relics].
Unit holder(Game g, String type, int c, int r, List<Relic> relics) => placeNow(g, type, c, r)..relics.addAll(relics);

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

/// Wins [g]'s wave outright: one slime shows up and is gone (heal_funnel_test.dart's).
void winWave(Game g) {
  g.startWave();
  g.queue
    ..clear()
    ..add(('slime', Tier.normal));
  g.tick(0.05);
  g.enemies.single.gone = true;
  g.tick(0.05);
}

/// A wave on with nothing left to spawn.
void waveOn(Game g) => g
  ..startWave()
  ..queue.clear();

const seven = [Relic.cleave, Relic.venom, Relic.manaSiphon, Relic.spiritWard, Relic.lastStand, Relic.giantSlayer, Relic.blessing];

void main() {
  group('the seven in the game', () {
    test('appended to the enum after the last Artifact, never reordered: their save keys; small relics, never dropped', () {
      expect(Relic.values.skip(Relic.brightSpring.index + 1).take(seven.length), seven, reason: "batch G-1P's Legenda follow them");
      expect([for (final r in seven) r.name], ['cleave', 'venom', 'manaSiphon', 'spiritWard', 'lastStand', 'giantSlayer', 'blessing']);
      expect(smallRelics, [Relic.fang, Relic.thorns, Relic.fury, Relic.guard, ...seven]);
      expect(seven.every((r) => r.scope == RelicScope.troop && !r.pusaka && r.rarity == Rarity.biasa), isTrue);
      expect(droppedRelics, [Relic.fang, Relic.thorns, Relic.fury, Relic.guard], reason: 'monsters drop only the four');
      expect(storeGoods.where(seven.contains), isEmpty, reason: "today's Shop sells none");
      expect([for (final r in seven) relicNames[r]], ['Sweep', 'Venom', 'Mana Siphon', 'Spirit Ward', 'Iron Will', 'Giant Slayer', 'Holy Charm'],
          reason: "the owner's names (decisions-log 227): not the Hero skills Cleave, Last Stand and Blessing");
      for (final s in [HeroSkill.cleave, HeroSkill.lastStand, HeroSkill.blessing]) {
        expect(relicNames.values, isNot(contains(s.title)), reason: '${s.title}: a Hero skill');
      }
    });

    test('their tiers are their recipes\' (town.json): the four Basic, four Strong, three Mighty; a patch moves one', () {
      final g = Game();
      expect({for (final r in smallRelics) r: g.relicTier(r)}, {
        Relic.fang: RelicTier.basic, Relic.thorns: RelicTier.basic, Relic.fury: RelicTier.basic, Relic.guard: RelicTier.basic, //
        Relic.cleave: RelicTier.strong, Relic.venom: RelicTier.strong, Relic.manaSiphon: RelicTier.strong, //
        Relic.spiritWard: RelicTier.strong, Relic.lastStand: RelicTier.mighty, Relic.giantSlayer: RelicTier.mighty, //
        Relic.blessing: RelicTier.mighty,
      });
      g.townRules = TownRules.patch({'recipes': {'cleave': {'tier': 'mighty'}}});
      expect(g.relicTier(Relic.cleave), RelicTier.mighty);
      expect(g.relicTierLine(Relic.cleave), 'Mighty relic');
    });

    test('in play: all eleven and the forge\'s nine (the guide, the Bag\'s kinds)', () {
      expect(Game().relicsInPlay, [...smallRelics, ...forgeRelics]);
    });
  });

  group('Sweep (cleave)', () {
    test('a blow also hits the nearest other monster within its reach of the target, for its share, through its defence', () {
      final g = plain(), k = holder(g, 'knight', 2, 3, [Relic.cleave]);
      final reach = g.relicK(Relic.cleave, 'reach') * tile, share = g.relicK(Relic.cleave, 'share');
      expect((reach, share), (1.5 * tile, 0.30), reason: 'town.json');
      final a = foeAt(g, 'orc', k.pos + const Point(12, 0));
      final b = foeAt(g, 'orc', a.pos + Point(0, reach)); // exactly at its reach
      final c = foeAt(g, 'orc', a.pos + Point(0, -reach - 0.5)); // just past it
      for (final f in [a, b, c]) {
        f.hp = 1000;
      }
      strikeOnce(g, k);
      expect(1000 - a.hp, hitTaken(k.stats.dmg, a.stats.def));
      expect(1000 - b.hp, closeTo(hitTaken(k.stats.dmg * share, b.stats.def), 1e-9));
      expect(c.hp, 1000, reason: 'past its reach');
    });

    test('only the nearest; never chains (its own hit sweeps nothing); a patch moves its share and reach', () {
      final g = plain()..townRules = TownRules.patch({'relics': {'cleave': {'share': 0.5, 'reach': 2.0}}});
      final k = holder(g, 'knight', 2, 3, [Relic.cleave]);
      final a = foeAt(g, 'orc', k.pos + const Point(12, 0));
      final near = foeAt(g, 'orc', a.pos + const Point(0, 1.0 * tile)), far = foeAt(g, 'orc', a.pos + const Point(0, -1.9 * tile));
      final next = foeAt(g, 'orc', near.pos + const Point(0, 1.0 * tile)); // 2 tiles from the target, 1 from the swept
      for (final f in [a, near, far, next]) {
        f.hp = 1000;
      }
      strikeOnce(g, k);
      expect(1000 - near.hp, closeTo(hitTaken(k.stats.dmg * 0.5, near.stats.def), 1e-9));
      expect((far.hp, next.hp), (1000, 1000), reason: 'one monster, the nearest; and no sweep of a sweep');
    });

    test('a shot sweeps where it lands; a smite sweeps nothing', () {
      final g = plain(), archer = holder(g, 'archer', 1, 3, [Relic.cleave]);
      final a = foeAt(g, 'orc', archer.pos + const Point(50, 0)), b = foeAt(g, 'orc', a.pos + const Point(0, 12));
      a.hp = b.hp = 1000;
      strikeOnce(g, archer);
      land(g);
      expect(1000 - b.hp, closeTo(hitTaken(archer.stats.dmg * g.relicK(Relic.cleave, 'share'), b.stats.def), 1e-9));

      final h = plain(), priest = holder(h, 'priest', 1, 3, [Relic.cleave]);
      final s1 = foeAt(h, 'skeleton', priest.pos + const Point(60, 0)), s2 = foeAt(h, 'skeleton', s1.pos + const Point(0, 10));
      s1.hp = s2.hp = 1000;
      strikeOnce(h, priest);
      expect([s1.hp, s2.hp].where((hp) => hp < 1000), hasLength(1), reason: 'one smite, no sweep');
    });
  });

  group('Venom', () {
    test('a hit poisons: its share of the hit over its secs, a tick a second; all of it lands', () {
      final g = plain(), k = holder(g, 'knight', 2, 3, [Relic.venom]);
      final share = g.relicK(Relic.venom, 'share'), secs = g.relicK(Relic.venom, 'secs');
      expect((share, secs), (0.20, 3.0), reason: 'town.json');
      final a = foeAt(g, 'orc', k.pos + const Point(12, 0))..hp = 1000;
      strikeOnce(g, k);
      final e = g.effectOn(a, Status.bleed)!;
      expect(e.k, closeTo(k.stats.dmg * share / 3, 1e-9));
      expect((e.n, e.by), (3, k));
      final after = a.hp;
      runFor(g, 3.6);
      expect(after - a.hp, closeTo(3 * hitTaken(k.stats.dmg * share / 3, a.stats.def), 1e-9));
      expect(g.effectOn(a, Status.bleed), isNull, reason: 'run out');
    });

    test('never stacks: a stronger bleed on it stays, a weaker one is replaced; a patch moves share and secs', () {
      final g = plain(), k = holder(g, 'knight', 2, 3, [Relic.venom]);
      final a = foeAt(g, 'orc', k.pos + const Point(12, 0))..hp = 1000;
      g.addEffect(a, Status.bleed, 5, k: 100, n: 5);
      strikeOnce(g, k);
      expect(g.effectOn(a, Status.bleed)!.k, 100);
      a.effects.clear();
      g.addEffect(a, Status.bleed, 5, k: 0.1, n: 5);
      g.townRules = TownRules.patch({'relics': {'venom': {'share': 0.5, 'secs': 2.0}}});
      strikeOnce(g, k);
      final e = g.effectOn(a, Status.bleed)!;
      expect(e.k, closeTo(k.stats.dmg * 0.5 / 2, 1e-9));
      expect(e.n, 2);
    });

    test('a shot poisons where it lands; a smite poisons nothing', () {
      final g = plain(), archer = holder(g, 'archer', 1, 3, [Relic.venom]);
      final a = foeAt(g, 'orc', archer.pos + const Point(50, 0))..hp = 1000;
      strikeOnce(g, archer);
      expect(g.effectOn(a, Status.bleed), isNull, reason: 'in flight');
      land(g);
      expect(g.effectOn(a, Status.bleed)!.k, closeTo(archer.stats.dmg * g.relicK(Relic.venom, 'share') / 3, 1e-9));

      final h = plain(), priest = holder(h, 'priest', 1, 3, [Relic.venom]);
      final s = foeAt(h, 'skeleton', priest.pos + const Point(60, 0))..hp = 1000;
      strikeOnce(h, priest);
      expect(s.hp, lessThan(1000), reason: 'smitten');
      expect(h.effectOn(s, Status.bleed), isNull);
    });
  });

  group('Mana Siphon', () {
    /// The MP [type] holding [relics] has after one strike (or heal) of [setUp]'s scene, from [mp].
    double mpAfter(String type, List<Relic> relics, double mp, void Function(Game g, Unit u) setUp) {
      final g = plain(), u = holder(g, type, 1, 3, relics)..mp = mp;
      setUp(g, u);
      strikeOnce(g, u);
      land(g);
      return u.mp;
    }

    void blow(Game g, Unit u) => foeAt(g, 'orc', u.pos + const Point(12, 0)).hp = 1000;
    void shot(Game g, Unit u) => foeAt(g, 'orc', u.pos + const Point(50, 0)).hp = 1000;
    void smite(Game g, Unit u) => foeAt(g, 'skeleton', u.pos + const Point(60, 0)).hp = 1000;
    void heal(Game g, Unit u) {
      placeNow(g, 'knight', 2, 3)
        ..hp = 10
        ..busyUntil = hold;
      foeAt(g, 'orc', const Point(300, 60)); // mid-wave
    }

    test('each hit it lands (a blow, a shot, a smite) or heal it gives: its mp more than without it', () {
      final mp = Game().relicK(Relic.manaSiphon, 'mp');
      expect(mp, 2, reason: 'town.json');
      // A heal costs the priest healMp (decisions-log 297): it starts with that much; a smite is free.
      for (final (type, scene, from) in [('knight', blow, 0.0), ('archer', shot, 0.0), ('priest', smite, 0.0), ('priest', heal, healMp)]) {
        final gain = mpAfter(type, [Relic.manaSiphon], from, scene) - mpAfter(type, [], from, scene);
        expect(gain, closeTo(mp, 1e-9), reason: type);
      }
    });

    test('never past its max MP', () {
      final max = troopTypes['knight']!.mp.toDouble();
      expect(mpAfter('knight', [Relic.manaSiphon], max - 0.5, blow), max);
    });
  });

  group('Spirit Ward', () {
    test("at each wave's start a shield of its share of max HP; gone at the wave's end; never past wardMax", () {
      final g = plain(), s = holder(g, 'soldier', 2, 3, [Relic.spiritWard]), bare = placeNow(g, 'soldier', 2, 4);
      expect(g.relicK(Relic.spiritWard, 'share'), 0.15, reason: 'town.json');
      waveOn(g);
      final orc = foeAt(g, 'orc', const Point(300, 60)); // the wave goes on
      expect(s.ward, closeTo(s.maxHp * 0.15, 1e-9));
      expect(bare.ward, 0);
      orc.gone = true;
      g.tick(0.05);
      expect(g.waveActive, isFalse);
      expect(s.ward, 0, reason: 'it ends with the wave');
      g.townRules = TownRules.patch({'relics': {'spiritWard': {'share': 0.5}}});
      waveOn(g);
      expect(s.ward, closeTo(s.maxHp * wardMax, 1e-9));
    });
  });

  group('Iron Will (lastStand)', () {
    /// A wave on, and soldier [s] holding [relics] with an orc next to it that strikes only when told: its blow's HP.
    (Game, Unit, Unit, double) scene([List<Relic> relics = const [Relic.lastStand]]) {
      final g = plain(), s = holder(g, 'soldier', 2, 3, relics)..busyUntil = hold;
      waveOn(g);
      final orc = foeAt(g, 'orc', s.pos + const Point(12, 0));
      return (g, s, orc, hitTaken(orc.stats.dmg, s.stats.def));
    }

    void strike(Game g, Unit orc) {
      orc
        ..busyUntil = double.negativeInfinity
        ..cd = 0;
      g.tick(0.05);
      orc.busyUntil = hold;
    }

    test('a blow that leaves it under its below line heals its heal share at once, through the funnel, once a wave', () {
      final (g, s, orc, blow) = scene();
      final below = g.relicK(Relic.lastStand, 'below'), heal = g.relicK(Relic.lastStand, 'heal');
      expect((below, heal), (0.25, 0.40), reason: 'town.json');
      final heard = <(HealSrc, double)>[];
      g.onTroopHeal = (u, src, asked, past) => heard.add((src, asked));
      s.hp = s.maxHp * below + blow - 0.5;
      strike(g, orc);
      expect(s.hp, closeTo(s.maxHp * below - 0.5 + s.maxHp * heal, 1e-9));
      expect(heard, [(HealSrc.lastStand, s.maxHp * heal)]);
      expect(g.healKind(HealSrc.lastStand), HealKind.inWave, reason: 'Wound cuts it like any heal in a wave');
      s.hp = s.maxHp * below + blow - 0.5;
      strike(g, orc);
      expect(s.hp, closeTo(s.maxHp * below - 0.5, 1e-9), reason: 'once a wave');
      orc.gone = true; // the wave won, the next begun
      g.tick(0.05);
      expect(g.waveActive, isFalse);
      waveOn(g);
      final orc2 = foeAt(g, 'orc', s.pos + const Point(12, 0));
      s.hp = s.maxHp * below + hitTaken(orc2.stats.dmg, s.stats.def) - 0.5; // a wave on: a stronger orc
      expect(s.ironWillUsed, isFalse, reason: 'a new wave');
      strike(g, orc2);
      expect(s.hp, closeTo(s.maxHp * below - 0.5 + s.maxHp * heal, 1e-9), reason: 'again the next wave');
    });

    test('at its line exactly, nothing; a killing blow is the Grail\'s, never this', () {
      final (g, s, orc, blow) = scene();
      s.hp = s.maxHp * 0.25 + blow;
      strike(g, orc);
      expect(s.hp, closeTo(s.maxHp * 0.25, 1e-9));
      expect(s.ironWillUsed, isFalse);
      s.hp = blow / 2;
      strike(g, orc);
      expect(s.alive, isFalse);
    });

    test('with Holy Charm on a Hero: the heal is bigger by its k', () {
      final (g, s, orc, blow) = scene([Relic.lastStand, Relic.blessing]);
      s.hero = true;
      s.hp = s.maxHp * 0.25 + blow - 0.5;
      strike(g, orc);
      expect(s.hp, closeTo(s.maxHp * 0.25 - 0.5 + s.maxHp * 0.40 * 1.4, 1e-9));
    });
  });

  group('Giant Slayer', () {
    /// The HP a knight holding [relics] takes off a monster of [tier] with one blow (a patch [p] on the rules), and the
    /// monster's defence.
    (double, double) blow(Tier tier, List<Relic> relics, [Map<String, dynamic>? p]) {
      final g = plain();
      if (p != null) g.townRules = TownRules.patch(p);
      final k = holder(g, 'knight', 2, 3, relics), f = foeAt(g, 'orc', k.pos + const Point(12, 0), tier)..hp = 100000;
      return (lost(f, () => strikeOnce(g, k)), f.stats.def);
    }

    test('its attacks do its k more to a mini boss and the boss, before defence; to the others, nothing more', () {
      final k = Game().relicK(Relic.giantSlayer, 'k'), dmg = troopTypes['knight']!.dmg;
      expect(k, 1.5, reason: 'town.json');
      for (final tier in Tier.values) {
        final (hp, def) = blow(tier, [Relic.giantSlayer]);
        final big = tier == Tier.miniBoss || tier == Tier.boss;
        expect(hp, closeTo(hitTaken(dmg * (big ? k : 1), def), 1e-9), reason: tier.name);
      }
      final (hp, def) = blow(Tier.boss, [Relic.giantSlayer], {'relics': {'giantSlayer': {'k': 2.0}}});
      expect(hp, closeTo(hitTaken(dmg * 2, def), 1e-9));
    });

    test("a healer's smite too; a skill's blow not (a Hero's Cleave)", () {
      final g = plain(), p = holder(g, 'priest', 1, 3, [Relic.giantSlayer]);
      final s = foeAt(g, 'skeleton', p.pos + const Point(60, 0), Tier.miniBoss)..hp = 100000;
      final smite = lost(s, () => strikeOnce(g, p));
      final h = plain(), q = holder(h, 'priest', 1, 3, []);
      final t = foeAt(h, 'skeleton', q.pos + const Point(60, 0), Tier.miniBoss)..hp = 100000;
      final plainSmite = lost(t, () => strikeOnce(h, q));
      expect(smite, greaterThan(plainSmite));

      double cleave(List<Relic> relics) {
        final (g, hero) = heroCaster(HeroSkill.cleave, Random(1));
        hero.relics.addAll(relics);
        final f = foeAt(g, 'orc', hero.pos + const Point(12, 0), Tier.miniBoss)..hp = 100000;
        return lost(f, () => runFor(g, 0.3));
      }

      expect(cleave([]), greaterThan(0), reason: 'the Hero cast its Cleave');
      expect(cleave([Relic.giantSlayer]), closeTo(cleave([]), 1e-9), reason: 'not on a skill');
    });
  });

  group('Holy Charm (blessing)', () {
    test("heals on it are its k bigger: a healer's; its own regen, the Grail's save and the after-wave heal not", () {
      final heard = <double>[];
      final g = plain()..onTroopHeal = (u, src, asked, past) => heard.add(asked);
      expect(g.relicK(Relic.blessing, 'k'), 1.4, reason: 'town.json');
      placeNow(g, 'priest', 0, 3);
      final k = holder(g, 'knight', 2, 3, [Relic.blessing])
        ..hp = 50
        ..busyUntil = hold;
      foeAt(g, 'orc', const Point(300, 60)); // mid-wave
      for (var i = 0; i < 60 && heard.isEmpty; i++) {
        g.tick(0.05);
      }
      expect(heard, hasLength(1));
      expect(k.hp, closeTo(50 + heard.single * 1.4, 1e-9), reason: 'the funnel hears the heal asked; it lands bigger');

      final r = plain()..givePusaka(Relic.dragonHeart, type: 'knight');
      final rk = holder(r, 'knight', 2, 3, [Relic.blessing])..hp = 50; // not held busy: a busy troop never regens
      expect(rk.stats.regen, greaterThan(0));
      r.tick(0.05);
      expect(rk.hp, closeTo(50 + rk.stats.regen * 0.05, 1e-9), reason: 'its own regen: as it is');

      final q = plain()..givePusaka(Relic.grail, type: 'soldier');
      final s = holder(q, 'soldier', 2, 3, [Relic.blessing])..busyUntil = hold;
      waveOn(q);
      final orc = foeAt(q, 'orc', s.pos + const Point(12, 0))
        ..busyUntil = double.negativeInfinity
        ..cd = 0;
      s.hp = 1;
      q.tick(0.05);
      orc.busyUntil = hold;
      expect((s.alive, s.hp), (true, s.maxHp * grailK.hpLeft[0]), reason: "the Grail's save: its share, not more");
    });
  });

  group('a Hero holds two', () {
    test('Sweep and Venom: one blow sweeps and poisons; a third relic, or a second of a kind, is refused', () {
      final g = plain(), h = placeNow(g, 'soldier', 2, 3)..hero = true;
      g.relicBag
        ..[Relic.cleave] = 2
        ..[Relic.venom] = 1
        ..[Relic.blessing] = 1;
      expect(g.useRelic(Relic.cleave, h), isTrue);
      expect(g.relicRefusal(Relic.cleave, h), holdsRelic(Relic.cleave));
      expect(g.useRelic(Relic.venom, h), isTrue);
      expect(g.relicRefusal(Relic.blessing, h), assignRefusals.full);
      final soldier = placeNow(g, 'soldier', 2, 5);
      expect(g.useRelic(Relic.blessing, soldier), isTrue);
      expect(g.relicRefusal(Relic.cleave, soldier), holdsRelic(Relic.blessing), reason: 'one a troop');
      final a = foeAt(g, 'orc', h.pos + const Point(12, 0))..hp = 1000;
      final b = foeAt(g, 'orc', a.pos + const Point(0, 16))..hp = 1000;
      strikeOnce(g, h);
      expect(b.hp, lessThan(1000), reason: 'swept');
      expect(g.effectOn(a, Status.bleed), isNotNull, reason: 'poisoned');
    });
  });

  test('the save keeps them by their keys: the bag, a troop\'s, a Hero\'s two', () {
    final g = Game(Random(1))..boardRules();
    final s = placeNow(g, 'soldier', 2, 3), h = placeNow(g, 'knight', 2, 4)..hero = true;
    for (final r in seven) {
      g.relicBag[r] = r.index;
    }
    s.relics.add(Relic.spiritWard);
    h.relics.addAll([Relic.lastStand, Relic.blessing]);
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect((j['relicBag'] as Map).keys, containsAll(['cleave', 'venom', 'manaSiphon', 'spiritWard', 'lastStand', 'giantSlayer', 'blessing']));
    final back = Game.fromJson(j, Random(1), Random(2), Random(3));
    expect({for (final r in seven) r: back.relicBag[r]}, {for (final r in seven) r: r.index});
    final troops = [for (final u in back.troops) '${u.type}: ${u.relics.map((r) => r.name).join(', ')}'];
    expect(troops, containsAll(['soldier: spiritWard', 'knight: lastStand, blessing']));
  });

  group('their words', () {
    test('what each does, from the rules\' numbers; a patch shows', () {
      final g = Game();
      expect({for (final r in seven) r: g.relicEffect(r)}, {
        Relic.cleave: ['Hits 1 more monster near the target for 30%'],
        Relic.venom: ['Poisons: +20% of the hit over 3 s'],
        Relic.manaSiphon: ['+2 MP each hit or heal'],
        Relic.spiritWard: ['Shield 15% HP each wave'],
        Relic.lastStand: ['Once a wave: heals 40% HP below 25%'],
        Relic.giantSlayer: ['x1.5 damage to mini boss and boss'],
        Relic.blessing: ['Heals on it +40%'],
      });
      g.townRules = TownRules.patch({'relics': {'cleave': {'share': 0.45}, 'venom': {'secs': 4.0}}});
      expect(g.relicEffect(Relic.cleave).single, 'Hits 1 more monster near the target for 45%');
      expect(g.relicEffect(Relic.venom).single, 'Poisons: +20% of the hit over 4 s');
    });

    test('the tooltip shows the tier and who it suits', () {
      final on = Game();
      expect(on.relicInfo(Relic.fang).$2, containsAllInOrder(['Heals 30% of damage dealt', 'Basic relic', 'Best on: Knight, Templar, Lancer, Swordsman']));
      expect(on.relicInfo(Relic.cleave).$2, containsAllInOrder(['Strong relic', 'Best on: Soldier, Knight, Axeman, Templar', relicSlotsLine]));
      expect(on.relicInfo(Relic.lastStand).$2, containsAllInOrder(['Mighty relic', 'Best on: Front melee, Heroes']));
      expect(on.relicInfo(Relic.blessing).$1, 'Holy Charm');
      for (final r in smallRelics) {
        expect(on.relicBestLine(r), isNotNull, reason: '$r');
      }
    });
  });
}
