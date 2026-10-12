// Batch E-1P (decisions-log 211; catalog-design §3.2 and §5.2, catalog-bayangan-v2 §4 and §5.2): the first ten new Epik
// Artifacts as catalog rows on the engine's Fx. Each one's effect at ★1, ★2 and ★3 and with Carve steps (the number
// [pusakaAt] gives), its words, its row (rarity, Carve role, the atlas's icon, epithet, counter, chest-only), a few of
// the counters that answer it (Hunker, Bone Arrows, Envy), the Shadows' needs it meets (and that none waits every few
// hits, so Off Beat reaches none), the chest offering it, the save keeping an owned one, the Shop buying it back, its
// battle-log line, and its card on the Boss Chest at 915x412 and 1266x713. The rules every row keeps (band, key, icon,
// counter in its pool): pusaka_catalog_test.dart. docs/loot-items-relics.md "The Pusaka catalog and its engine".
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hero_skill_helpers.dart';
import 'hud_font.dart';

/// The batch's ten, in [Relic] order (catalog-design §3.2's).
const batch = [
  Relic.healerBane, Relic.bullyClub, Relic.unityRing, Relic.runeGauntlet, Relic.hawkFeather, //
  Relic.witherroot, Relic.arrowCatcher, Relic.stoneCoat, Relic.heroCloak, Relic.moonwell,
];

/// The stars and Carve steps each effect is checked at: ★1-★3 bare, then two carved.
const _levels = [(1, 0), (2, 0), (3, 0), (1, 2), (3, 5)];

/// A game with no skills cast, so what happens is the Pusaka's doing.
Game plain([Random? rng]) => bareGame(rng)
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false
  ..monsterSkills = false;

/// Lets [foe] strike once now (then it stands again); a shot is let fly to its target.
void strikeBy(Game g, Unit foe) {
  foe
    ..busyUntil = double.negativeInfinity
    ..cd = 0;
  g.tick(0.05);
  foe.busyUntil = hold;
  for (var i = 0; i < 60 && g.shots.isNotEmpty; i++) {
    g.tick(0.05);
  }
}

/// What troop [u]'s next normal attack takes off [foe] (its cooldown over now; it waits again after); a shot is let fly.
double blow(Game g, Unit u, Unit foe) {
  final before = foe.hp;
  u.cd = 0;
  g.tick(0.05);
  u.cd = hold;
  for (var i = 0; i < 60 && g.shots.isNotEmpty; i++) {
    g.tick(0.05);
  }
  return before - foe.hp;
}

/// What a blow on [u] by [foe] takes off it.
double taken(Game g, Unit u, Unit foe) {
  final before = u.hp;
  strikeBy(g, foe);
  return before - u.hp;
}

/// A troop of [type] standing at (2, 3) with [relic] bound to its type at [stars] and [ukir] Carve steps (none: nothing
/// bound), that attacks only when told ([blow]), with HP to spare; and a monster of [foe] and [tier] 12 px from it (40 px
/// for a shooter) with HP to spare that strikes only when told ([strikeBy]); an archer far behind keeps the game on.
(Game, Unit, Unit) duel(Relic? relic, {String type = 'knight', int stars = 1, int ukir = 0, String foe = 'orc', Tier tier = Tier.normal}) {
  final g = plain(Random(2));
  final u = placeNow(g, type, 2, 3)..cd = hold;
  placeNow(g, 'archer', 0, 1).cd = hold;
  if (relic != null) g.givePusaka(relic, type: type, stars: stars, ukir: ukir);
  u
    ..maxHp = 100000
    ..hp = 100000;
  final o = foeAt(g, foe, u.pos + Point(foe == 'skeleton_archer' ? 40 : 12, 0), tier)
    ..maxHp = 1000000
    ..hp = 1e6;
  return (g, u, o);
}

/// Draft dice that roll every rarity at [roll] and take the [pick]th card of a pool (wrapping).
class _Dice implements Random {
  _Dice(this.roll, [this.pick = 0]);
  final double roll;
  final int pick;

  @override
  double nextDouble() => roll;

  @override
  int nextInt(int max) => pick % max;

  @override
  bool nextBool() => false;
}

void main() {
  tearDown(() => omensOn = false);

  group('the rows', () {
    test('ten Epik appended after batch L-3 (save keys), chest-only (sold back like a Langka), in the game; names, Carve '
        "roles, epithets, the atlas's icons and catalog-bayangan-v2's counters (batch E-1B's kinds)", () {
      expect(Relic.values.skipWhile((r) => r != Relic.pureWater).skip(1).take(batch.length).toList(), batch,
          reason: "after the last Langka (batch E-2P's Epik follow)");
      expect({for (final r in batch) r: relicNames[r]}, {
        Relic.healerBane: 'Healer Bane',
        Relic.bullyClub: "Bully's Club",
        Relic.unityRing: 'Unity Ring',
        Relic.runeGauntlet: 'Rune Gauntlet',
        Relic.hawkFeather: 'Hawk Feather',
        Relic.witherroot: 'Witherroot',
        Relic.arrowCatcher: 'Arrow Catcher',
        Relic.stoneCoat: 'Stone Coat',
        Relic.heroCloak: "Hero's Cloak",
        Relic.moonwell: 'Moonwell',
      });
      for (final r in batch) {
        final art = pusakaCatalog[r]!;
        expect((r.rarity, r.scope, r.store, art.live, r.oath, maxStars(r)), (Rarity.epik, RelicScope.type, false, true, false, starMax), reason: '$r');
        expect(art.icon.sheet, 'artifact_icons.png', reason: '$r');
        expect((art.icon.x, art.icon.y, art.icon.tint), (artifactIcon(r.name).x, artifactIcon(r.name).y, null), reason: '$r');
        expect(art.fx, hasLength(const [Relic.hawkFeather, Relic.stoneCoat, Relic.moonwell].contains(r) ? 2 : 1),
            reason: '$r: the three stats pay with a trade');
        expect(art.healerCounter, isNull, reason: '$r');
      }
      expect((liveE1P, newEpikStore), (true, false));
      expect({for (final r in batch) r: pusakaCatalog[r]!.role}, {
        Relic.healerBane: UkirRole.attack,
        Relic.bullyClub: UkirRole.attack,
        Relic.unityRing: UkirRole.attack,
        Relic.runeGauntlet: UkirRole.attack,
        Relic.hawkFeather: UkirRole.attack,
        Relic.witherroot: UkirRole.guard,
        Relic.arrowCatcher: UkirRole.guard,
        Relic.stoneCoat: UkirRole.guard,
        Relic.heroCloak: UkirRole.guard,
        Relic.moonwell: UkirRole.life,
      });
      expect({for (final r in batch) r: buildEpithets[r]}, {
        Relic.healerBane: 'Merciless',
        Relic.bullyClub: 'Cruel',
        Relic.unityRing: 'United',
        Relic.runeGauntlet: 'Runic',
        Relic.hawkFeather: 'Hawk',
        Relic.witherroot: 'Withering',
        Relic.arrowCatcher: 'Arrowproof',
        Relic.stoneCoat: 'Stone',
        Relic.heroCloak: 'Cloaked',
        Relic.moonwell: 'Moonlit',
      });
      expect(buildEpithets.values.toSet().length, buildEpithets.length, reason: 'an epithet twice');
      expect({for (final r in batch) r: pusakaCatalog[r]!.counter}, {
        Relic.healerBane: OmenKind.darkHymn,
        Relic.bullyClub: OmenKind.hunker,
        Relic.unityRing: OmenKind.muster,
        Relic.runeGauntlet: OmenKind.envy,
        Relic.hawkFeather: OmenKind.arrowWard,
        Relic.witherroot: OmenKind.zeal,
        Relic.arrowCatcher: OmenKind.boneArrows,
        Relic.stoneCoat: OmenKind.enrage,
        Relic.heroCloak: OmenKind.wearDown,
        Relic.moonwell: OmenKind.counterspell,
      });
      for (final r in batch) {
        final counter = pusakaCatalog[r]!.counter;
        expect(counter.answers, contains(r), reason: '$r');
        expect(counter.tiers, {Rarity.epik}, reason: '$r: a kind of the Epik pool alone');
        expect(omenPool(Rarity.epik), contains(counter), reason: '$r');
      }
      // The Shop never sells one; one in the Vault sells to it at epikPrice (owner, 2026-10-03: "hanya bisa sell ke toko
      // tapi untuk buy tidak bisa").
      expect(storeGoods.where(batch.contains), isEmpty, reason: 'never in the Shop');
      for (final r in batch) {
        final g = Game()
          ..wave = storeFrom
          ..inTown = true; // the Shop buys only in a Town
        expect(g.basePrice(r), epikPrice, reason: '$r');
        g.givePusaka(r);
        final gold = g.gold;
        expect(g.whyNotSell(r), isNull, reason: '$r in the Vault');
        expect(g.sell(r), 1, reason: '$r');
        expect((g.gold - gold, g.pusaka.containsKey(r)), (epikPrice ~/ 2, false), reason: '$r');
        final bound = Game()
          ..wave = storeFrom
          ..inTown = true; // the Shop buys only in a Town
        bound.givePusaka(r, type: 'knight');
        expect(bound.whyNotSell(r), StoreRefusal.bound, reason: '$r: equipped');
      }
    });

    test('each leads with its own Fx (no other row shares its key); the band measures the powers (a skill\'s might too) '
        'and the cuts; Unity Ring and Hero\'s Cloak earn no quarter (hard conditions); range, defence and MP regen are '
        'exempt, a trade and a weaken unmeasured; none waits every few hits nor on a cooldown', () {
      final keys = {for (final MapEntry(key: r, value: a) in pusakaCatalog.entries) if (a.fx.isNotEmpty) a.fx.first.key: r};
      for (final r in batch) {
        expect(keys[pusakaCatalog[r]!.fx.first.key], r, reason: '$r');
      }
      Fx fx(Relic r, [int i = 0]) => pusakaCatalog[r]!.fx[i];
      for (var s = 1; s <= starMax; s++) {
        final i = s - 1;
        expect(fxGain(fx(Relic.healerBane), pusakaAt(Relic.healerBane, s), 1), (Band.power, healerBaneK[i] - 1));
        expect(fxGain(fx(Relic.bullyClub), pusakaAt(Relic.bullyClub, s), 1), (Band.power, bullyClubK[i] - 1));
        expect(fxGain(fx(Relic.unityRing), pusakaAt(Relic.unityRing, s), 1), (Band.power, unityRingK.hit[i] - 1));
        expect(fxGain(fx(Relic.runeGauntlet), pusakaAt(Relic.runeGauntlet, s), 1), (Band.power, runeGauntletK.might[i] - 1));
        expect(fxGain(fx(Relic.arrowCatcher), pusakaAt(Relic.arrowCatcher, s), 1), (Band.cut, arrowCatcherK[i]));
        expect(fxGain(fx(Relic.heroCloak), pusakaAt(Relic.heroCloak, s), 1), (Band.cut, heroCloakK[i]));
        expect(heroCloakK[i], lessThanOrEqualTo(fxBand[Band.cut]![Rarity.epik]![i]), reason: 'a hard condition: no quarter more');
        expect(unityRingK.hit[i] - 1, lessThanOrEqualTo(fxBand[Band.power]![Rarity.epik]![i]), reason: 'a hard condition: no quarter more');
        for (final r in [Relic.hawkFeather, Relic.stoneCoat, Relic.moonwell, Relic.witherroot]) {
          expect(fxGain(fx(r), pusakaAt(r, s), 1), isNull, reason: '$r: exempt or unmeasured, a probe arm instead');
        }
        for (final r in [Relic.hawkFeather, Relic.stoneCoat, Relic.moonwell]) {
          expect(fxGain(fx(r, 1), pusakaAt(r, s, fx: 1), 1), isNull, reason: '$r: a trade is no gain');
        }
      }
      expect(hardConds.containsAll([If.typesAlive, If.hero]), isTrue);
      expect(hardConds.intersection({If.foeHealer, If.foeHeld, If.attackerRanged}), isEmpty, reason: 'they narrow: a quarter more');
      expect(fxBandExempt.stats, containsAll([Stat.range, Stat.def, Stat.mpRegen]));
      for (final r in batch) {
        for (final f in pusakaCatalog[r]!.fx) {
          expect((f.every, f.cooled, f.furyBeat), (0, false, false), reason: '$r: every hit, no cooldown');
        }
      }
      // The trades: one number at every star, never carved.
      expect([fx(Relic.hawkFeather, 1).k, fx(Relic.stoneCoat, 1).k, fx(Relic.moonwell, 1).k], [
        [hawkFeatherK.dmg],
        [stoneCoatK.speed],
        [moonwellK.hp],
      ]);
      expect([fx(Relic.hawkFeather, 1).stat, fx(Relic.stoneCoat, 1).stat, fx(Relic.moonwell, 1).stat], [Stat.dmg, Stat.speed, Stat.hp]);
      expect(fx(Relic.stoneCoat).k, [for (final d in stoneCoatK.def) d * shieldDef], reason: "a Shield's defence to two");
    });

    test("their words at ★1, from the constants: the card and tooltip lines, the Bag row's gist and the Bag detail's first "
        'sentence; ★2, ★3 and Carve move the numbers, never a trade', () {
      final g = Game();
      expect({for (final r in batch) r: g.relicEffect(r, stars: 1)}, {
        Relic.healerBane: ['+30% damage to monster healers'],
        Relic.bullyClub: ['+30% damage to a monster', 'that is slowed, held, stunned or hexed'],
        Relic.unityRing: ['4 or more types alive:', '+25% damage'],
        Relic.runeGauntlet: ['After it uses a skill:', '+30% damage for 4s'],
        Relic.hawkFeather: ['+15% range', 'but -10% attack or heal'],
        Relic.witherroot: ['Monsters it hits deal -10% damage', 'for 3s (boss -5%)'],
        Relic.arrowCatcher: ['-20% damage taken', 'from monsters that shoot'],
        Relic.stoneCoat: ['-2.5 damage taken per hit', 'but -10% walk speed'],
        Relic.heroCloak: ["This type's Hero: -20% damage taken"],
        Relic.moonwell: ['MP comes back 30% faster', 'but -10% max HP'],
      });
      expect({for (final r in batch) r: pusakaGist(r, 1)}, {
        Relic.healerBane: '+30% vs healers',
        Relic.bullyClub: '+30% vs held',
        Relic.unityRing: '4+ types: +25%',
        Relic.runeGauntlet: 'Skill: +30% for 4s',
        Relic.hawkFeather: '+15% range',
        Relic.witherroot: 'Monsters hit: -10% damage',
        Relic.arrowCatcher: '-20% from shots',
        Relic.stoneCoat: '-2.5 damage a hit',
        Relic.heroCloak: 'Hero: -20% taken',
        Relic.moonwell: 'MP 30% faster',
      });
      expect({for (final r in batch) r: firstSentence(g.relicEffect(r, stars: 1))}, {
        Relic.healerBane: '+30% damage to monster healers',
        Relic.bullyClub: '+30% damage to a monster that is slowed, held, stunned or hexed',
        Relic.unityRing: '4 or more types alive: +25% damage',
        Relic.runeGauntlet: 'After it uses a skill: +30% damage for 4s',
        Relic.hawkFeather: '+15% range but -10% attack or heal',
        Relic.witherroot: 'Monsters it hits deal -10% damage for 3s (boss -5%)',
        Relic.arrowCatcher: '-20% damage taken from monsters that shoot',
        Relic.stoneCoat: '-2.5 damage taken per hit but -10% walk speed',
        Relic.heroCloak: "This type's Hero: -20% damage taken",
        Relic.moonwell: 'MP comes back 30% faster but -10% max HP',
      });
      expect(g.relicEffect(Relic.healerBane, stars: 3), ['+60% damage to monster healers']);
      expect(g.relicEffect(Relic.bullyClub, stars: 2).first, '+40% damage to a monster');
      expect(g.relicEffect(Relic.unityRing, stars: 3).last, '+45% damage');
      expect(g.relicEffect(Relic.runeGauntlet, stars: 3).last, '+50% damage for 4s');
      expect(g.relicEffect(Relic.hawkFeather, stars: 2), ['+22% range', 'but -10% attack or heal']);
      expect(g.relicEffect(Relic.witherroot, stars: 3), ['Monsters it hits deal -16% damage', 'for 3s (boss -9%)']);
      expect(g.relicEffect(Relic.arrowCatcher, stars: 3).first, '-30% damage taken');
      expect(g.relicEffect(Relic.stoneCoat, stars: 2).first, '-3.75 damage taken per hit');
      expect(g.relicEffect(Relic.stoneCoat, stars: 3).first, '-5 damage taken per hit');
      expect(g.relicEffect(Relic.heroCloak, stars: 2), ["This type's Hero: -25% damage taken"]);
      expect(g.relicEffect(Relic.moonwell, stars: 2).first, 'MP comes back 45% faster');
      expect(fxLines(Relic.stoneCoat, 3, ukir: 5).first, '-6 damage taken per hit', reason: 'past ★3 by the last gap');
      for (final r in [Relic.hawkFeather, Relic.stoneCoat, Relic.moonwell]) {
        expect(fxLines(r, 3, ukir: 5).last, fxLines(r, 1).last, reason: '$r: Carve never moves the trade');
      }
      // Dragon Heart's HP line (no trade) and Dawn Star's attack line are as they were.
      expect(g.relicEffect(Relic.dragonHeart, stars: 1), ['+60% max HP', 'Heals 1% max HP every second']);
      expect(g.relicEffect(Relic.dawnStar, stars: 1), ['+30% attack or heal']);
    });
  });

  group('the effects at ★1, ★2, ★3 and carved', () {
    for (final (stars, ukir) in _levels) {
      final at = '★$stars${ukir > 0 ? ' +$ukir' : ''}';

      test('$at: the table, or past it by the Carve steps', () {
        final i = stars - 1;
        for (final (r, table) in [
          (Relic.healerBane, healerBaneK),
          (Relic.bullyClub, bullyClubK),
          (Relic.unityRing, unityRingK.hit),
          (Relic.runeGauntlet, runeGauntletK.might),
          (Relic.hawkFeather, hawkFeatherK.range),
          (Relic.witherroot, witherrootK.dealt),
          (Relic.arrowCatcher, arrowCatcherK),
          (Relic.stoneCoat, [for (final d in stoneCoatK.def) d * shieldDef]),
          (Relic.heroCloak, heroCloakK),
          (Relic.moonwell, moonwellK.mpRegen),
        ]) {
          final k = pusakaAt(r, stars, ukir: ukir);
          if (ukir == 0) {
            expect(k, table[i], reason: '$r $at');
          } else {
            expect((k - table[i]).abs(), greaterThan(0), reason: '$r $at: Carve moves it');
            expect((k - table[i]).sign, (table[2] - table[0]).sign, reason: '$r $at: the way the stars go');
          }
        }
        expect(pusakaAt(Relic.witherroot, stars, boss: true), ukir == 0 ? witherrootK.boss[i] : pusakaAt(Relic.witherroot, stars, boss: true));
      });

      test('$at Healer Bane: a normal attack on a monster healer does ×k; on another monster as before', () {
        final k = pusakaAt(Relic.healerBane, stars, ukir: ukir);
        final (g, u, healer) = duel(Relic.healerBane, stars: stars, ukir: ukir, foe: necroHealer);
        expect(healer.stats.heals, isTrue);
        expect(blow(g, u, healer), closeTo(hitTaken(u.stats.dmg * k, healer.stats.def), 1e-9));
        expect(g.pusakaWorth[Relic.healerBane]!.uses, 1);
        expect(g.pusakaWorth[Relic.healerBane]!.worth, closeTo(u.stats.dmg * (k - 1), 1e-9));
        final (h, v, orc) = duel(Relic.healerBane, stars: stars, ukir: ukir);
        expect(blow(h, v, orc), closeTo(hitTaken(v.stats.dmg, orc.stats.def), 1e-9));
        expect(h.pusakaWorth[Relic.healerBane], isNull);
      });

      test("$at Bully's Club: a normal attack on a slowed, pinned, stunned or hexed monster does ×k; on one standing free "
          'as before', () {
        final k = pusakaAt(Relic.bullyClub, stars, ukir: ukir);
        for (final (name, hold) in <(String, void Function(Game, Unit, Unit))>[
          ('slowed', (g, u, o) => g.addEffect(o, Status.slow, 10, k: 0.7, by: u)),
          ('pinned', (g, u, o) => g.addEffect(o, Status.impaled, 10, k: 0, by: u)),
          ('stunned', (g, u, o) => o.stunUntil = g.t + 10),
          ('hexed', (g, u, o) => g.addEffect(o, Status.hex, 10, by: u)),
        ]) {
          final (g, u, orc) = duel(Relic.bullyClub, stars: stars, ukir: ukir);
          hold(g, u, orc);
          expect(g.foeHeld(orc), isTrue, reason: name);
          expect(blow(g, u, orc), closeTo(hitTaken(u.stats.dmg * k, orc.stats.def), 1e-9), reason: name);
          expect(g.pusakaWorth[Relic.bullyClub]!.uses, 1, reason: name);
        }
        final (g, u, orc) = duel(Relic.bullyClub, stars: stars, ukir: ukir);
        expect(blow(g, u, orc), closeTo(hitTaken(u.stats.dmg, orc.stats.def), 1e-9));
        expect(g.pusakaWorth[Relic.bullyClub], isNull);
      });

      test('$at Unity Ring: with 4 or more troop types alive a normal attack does ×k; with 3 as before; it counts again '
          'when one dies out', () {
        final k = pusakaAt(Relic.unityRing, stars, ukir: ukir);
        final (g, u, orc) = duel(Relic.unityRing, stars: stars, ukir: ukir); // a knight and an archer
        placeNow(g, 'soldier', 1, 5).cd = hold;
        expect(g.typesAlive, 3);
        expect(blow(g, u, orc), closeTo(hitTaken(u.stats.dmg, orc.stats.def), 1e-9), reason: '3 types');
        final lancer = placeNow(g, 'lancer', 0, 5)..cd = hold;
        expect(blow(g, u, orc), closeTo(hitTaken(u.stats.dmg * k, orc.stats.def), 1e-9), reason: '4 types');
        expect(g.pusakaWorth[Relic.unityRing]!.uses, 1);
        g.units.remove(lancer);
        expect(blow(g, u, orc), closeTo(hitTaken(u.stats.dmg, orc.stats.def), 1e-9), reason: 'back to 3');
      });

      test('$at Rune Gauntlet: a skill cast (its own, a Hero\'s) gives the caster a might of k for 4s; a stronger might '
          'stays', () {
        final k = pusakaAt(Relic.runeGauntlet, stars, ukir: ukir);
        /// A soldier in a wave with full MP and two orcs near (Hold Fast wants two), [relic] bound to the soldiers.
        (Game, Unit) scene(Relic? relic) {
          final g = bareGame(Random(1))
            ..heroSkills = false
            ..monsterSkills = false;
          final u = placeNow(g, 'soldier', 2, 3);
          if (relic != null) g.givePusaka(relic, type: 'soldier', stars: stars, ukir: ukir);
          g
            ..startWave()
            ..queue.clear();
          u
            ..cd = hold
            ..mp = u.stats.mp.toDouble();
          for (final d in const <Point<double>>[Point(10, 0), Point(10, 8)]) {
            foeAt(g, 'orc', u.pos + d).hp = 1e4;
          }
          return (g, u);
        }

        final (none, nu) = scene(null);
        none.tick(0.05);
        expect(none.log.entries.whereType<SkillCast>(), hasLength(1), reason: 'Hold Fast cast');
        expect(none.effectOn(nu, Status.might), isNull, reason: 'Hold Fast gives no might itself');
        final (g, u) = scene(Relic.runeGauntlet);
        g.tick(0.05);
        expect(g.log.entries.whereType<SkillCast>(), hasLength(1));
        final m = g.effectOn(u, Status.might)!;
        expect((m.k, m.omen, m.bad), (k, false, false));
        expect(m.until, closeTo(g.t + runeGauntletK.time, 1e-9));
        expect(g.pusakaWorth[Relic.runeGauntlet]!.uses, 1);
        // A stronger might already on it stays.
        final (s, su) = scene(Relic.runeGauntlet);
        s.addEffect(su, Status.might, 20, k: 2.0);
        s.tick(0.05);
        expect(s.effectOn(su, Status.might)!.k, 2.0);
        // A Hero's cast (Shield Bash) too.
        final (hg, hero) = heroCaster(HeroSkill.shieldBash);
        hg.givePusaka(Relic.runeGauntlet, type: hero.type, stars: stars, ukir: ukir);
        foeAt(hg, 'orc', hero.pos + Point(hero.stats.range, 0), Tier.highElite).hp = 1e4;
        hg.tick(0.05);
        expect(hero.heroSkillAt, hg.t, reason: 'Shield Bash cast');
        expect(hg.effectOn(hero, Status.might)?.k, k);
      });

      test('$at Hawk Feather: its type\'s range ×k (a melee type\'s up to the most a melee reach goes), its attack ×0.9; it '
          'counts the attacks made from past its old range', () {
        final k = pusakaAt(Relic.hawkFeather, stars, ukir: ukir);
        final g = plain(Random(2));
        final archer = g.statsOf('archer'), lancer = g.statsOf('lancer'), priest = g.statsOf('priest');
        g
          ..givePusaka(Relic.hawkFeather, type: 'archer', stars: stars, ukir: ukir)
          ..givePusaka(Relic.stoneCoat, type: 'priest');
        expect(g.statsOf('archer').range, closeTo(archer.range * k, 1e-9));
        expect(g.statsOf('archer').dmg, closeTo(archer.dmg * hawkFeatherK.dmg, 1e-9));
        expect(g.statsOf('archer').hp, archer.hp);
        expect(g.statsOf('priest').range, priest.range, reason: 'only its own type');
        final h = plain(Random(2))..givePusaka(Relic.hawkFeather, type: 'lancer', stars: stars, ukir: ukir);
        expect(lancer.melee, isTrue);
        expect(h.statsOf('lancer').range, closeTo(max(lancer.range, min(lancer.range * k, meleeMaxRange)), 1e-9));
        expect(h.statsOf('lancer').range, lessThanOrEqualTo(meleeMaxRange));
        // An archer shooting a monster farther than its old range: one counted; a near one: none.
        final (f, u, orc) = duel(Relic.hawkFeather, type: 'archer', stars: stars, ukir: ukir);
        orc.pos = u.pos + Point(u.stats.range - 1, 0);
        expect(u.stats.range - 1, greaterThan(archer.range));
        expect(blow(f, u, orc), closeTo(hitTaken(archer.dmg * hawkFeatherK.dmg, orc.stats.def), 1e-9));
        expect(f.pusakaWorth[Relic.hawkFeather]!.uses, 1);
        orc.pos = u.pos + Point(archer.range * 0.5, 0);
        blow(f, u, orc);
        expect(f.pusakaWorth[Relic.hawkFeather]!.uses, 1, reason: 'within its old range');
      });

      test('$at Witherroot: a monster it takes HP off deals ×k for 3s (the boss ×its boss k, a mini boss ×k); a blow on a '
          'weakened one refreshes it; it counts the monsters it weakened anew', () {
        final k = pusakaAt(Relic.witherroot, stars, ukir: ukir), boss = pusakaAt(Relic.witherroot, stars, ukir: ukir, boss: true);
        for (final (tier, want) in [(Tier.normal, k), (Tier.miniBoss, k), (Tier.boss, boss)]) {
          final (g, u, o) = duel(Relic.witherroot, stars: stars, ukir: ukir, tier: tier);
          blow(g, u, o);
          final w = g.effectOn(o, Status.weaken)!;
          expect((w.k, w.by), (want, u), reason: '$tier');
          expect(w.until, closeTo(g.t + witherrootK.time, 0.051), reason: '$tier');
        }
        final (g, u, orc) = duel(Relic.witherroot, stars: stars, ukir: ukir);
        expect(taken(g, u, orc), closeTo(hitTaken(orc.stats.dmg, u.stats.def), 1e-9), reason: 'before its first blow');
        blow(g, u, orc);
        expect(g.pusakaWorth[Relic.witherroot]!.uses, 1);
        expect(taken(g, u, orc), closeTo(hitTaken(orc.stats.dmg * k, u.stats.def), 1e-9), reason: 'it deals less');
        runFor(g, 1);
        blow(g, u, orc);
        expect(g.pusakaWorth[Relic.witherroot]!.uses, 1, reason: 'a refresh, not a new one');
        expect(g.effectOn(orc, Status.weaken)!.until, closeTo(g.t + witherrootK.time, 0.051));
        runFor(g, witherrootK.time + 0.2);
        expect(g.effectOn(orc, Status.weaken), isNull, reason: 'it ran out');
        blow(g, u, orc);
        expect(g.pusakaWorth[Relic.witherroot]!.uses, 2);
      });

      test('$at Arrow Catcher: a shot of a monster that shoots takes k less off it, after its defence; a blow up close as '
          'before', () {
        final k = pusakaAt(Relic.arrowCatcher, stars, ukir: ukir);
        final (g, u, archer) = duel(Relic.arrowCatcher, stars: stars, ukir: ukir, foe: 'skeleton_archer');
        expect(archer.stats.shotSpeed, greaterThan(0));
        final hit = hitTaken(archer.stats.dmg, u.stats.def);
        expect(taken(g, u, archer), closeTo(hit * (1 - k), 1e-9));
        expect(g.pusakaWorth[Relic.arrowCatcher]!.worth, closeTo(hit * k, 1e-9));
        final (h, v, orc) = duel(Relic.arrowCatcher, stars: stars, ukir: ukir);
        expect(taken(h, v, orc), closeTo(hitTaken(orc.stats.dmg, v.stats.def), 1e-9));
        expect(h.pusakaWorth[Relic.arrowCatcher], isNull);
      });

      test('$at Stone Coat: its type\'s defence +k and walk speed ×0.9; a blow takes k less (never under the least a blow '
          'does); it counts what its defence kept off', () {
        final k = pusakaAt(Relic.stoneCoat, stars, ukir: ukir);
        final g = plain(Random(2));
        final base = g.statsOf('knight');
        g.givePusaka(Relic.stoneCoat, type: 'knight', stars: stars, ukir: ukir);
        expect(g.statsOf('knight').def, closeTo(base.def + k, 1e-9));
        expect(g.statsOf('knight').speed, closeTo(base.speed * stoneCoatK.speed, 1e-9));
        expect((g.statsOf('knight').hp, g.statsOf('knight').dmg), (base.hp, base.dmg));
        final (d, u, orc) = duel(Relic.stoneCoat, stars: stars, ukir: ukir);
        final want = hitTaken(orc.stats.dmg, u.stats.def);
        expect(taken(d, u, orc), closeTo(want, 1e-9));
        expect(want, lessThan(hitTaken(orc.stats.dmg, base.def)));
        expect(d.pusakaWorth[Relic.stoneCoat]!.worth, closeTo(hitTaken(orc.stats.dmg, base.def) - want, 1e-9));
      });

      test("$at Hero's Cloak: its type's Hero takes k less damage, after its defence; a troop of it that is no Hero as "
          'before', () {
        final k = pusakaAt(Relic.heroCloak, stars, ukir: ukir);
        final (g, u, orc) = duel(Relic.heroCloak, stars: stars, ukir: ukir);
        final hit = hitTaken(orc.stats.dmg, u.stats.def);
        expect(taken(g, u, orc), closeTo(hit, 1e-9), reason: 'no Hero');
        expect(g.pusakaWorth[Relic.heroCloak], isNull);
        u.hero = true;
        expect(taken(g, u, orc), closeTo(hit * (1 - k), 1e-9));
        expect(g.pusakaWorth[Relic.heroCloak]!.worth, closeTo(hit * k, 1e-9));
      });

      test('$at Moonwell: its type\'s MP comes back ×k as fast and its max HP ×0.9; it counts the MP its quicker regen gave',
          () {
        final k = pusakaAt(Relic.moonwell, stars, ukir: ukir);
        final g = plain(Random(2));
        final base = g.statsOf('wizard');
        g.givePusaka(Relic.moonwell, type: 'wizard', stars: stars, ukir: ukir);
        final s = g.statsOf('wizard');
        expect(s.mpRegen, closeTo(base.mpRegen * k, 1e-9));
        expect(s.hp, (base.hp * moonwellK.hp).round());
        expect((s.mp, s.dmg, s.regen), (base.mp, base.dmg, base.regen));
        final u = placeNow(g, 'wizard', 0, 3)..cd = hold;
        foeAt(g, 'orc', const Point(300, 60)); // mid-wave
        u.mp = 0;
        runFor(g, 1);
        expect(u.mp, closeTo(s.mpRegen, 1e-6));
        expect(g.pusakaWorth[Relic.moonwell]!.worth, closeTo(s.mpRegen * (1 - 1 / k), 1e-6));
      });
    }
  });

  group('the counters answer them', () {
    setUp(() => omensOn = true);

    test("Hunker cuts Bully's Club's blow on a held monster; Bone Arrows' shots hit harder through Arrow Catcher; Envy "
        "hits a troop that Rune Gauntlet's might is on harder", () {
      final hunker = List.filled(omenCap, OmenKind.hunker);
      final (g, u, orc) = duel(Relic.bullyClub);
      g
        ..omens.addAll(hunker)
        ..omenFactor = 2;
      orc.stunUntil = g.t + 10;
      expect(blow(g, u, orc), closeTo(hitTaken(u.stats.dmg * bullyClubK[0], orc.stats.def) * (1 - OmenKind.hunker.k.max), 1e-9));
      // Bone Arrows at its most: the skeleton archers' damage ×1.4, then the cut.
      final bones = plain(Random(2));
      bones
        ..omens.addAll(List.filled(omenCap, OmenKind.boneArrows))
        ..omenFactor = 2;
      final k = placeNow(bones, 'knight', 2, 3)..cd = hold;
      placeNow(bones, 'archer', 0, 1).cd = hold;
      bones.givePusaka(Relic.arrowCatcher, type: 'knight');
      k
        ..maxHp = 100000
        ..hp = 100000;
      final sa = foeAt(bones, 'skeleton_archer', k.pos + const Point(40, 0));
      final (_, _, plainArcher) = duel(null, foe: 'skeleton_archer');
      expect(sa.stats.dmg, closeTo(plainArcher.stats.dmg * (1 + OmenKind.boneArrows.k.max), 1e-9));
      expect(taken(bones, k, sa), closeTo(hitTaken(sa.stats.dmg, k.stats.def) * (1 - arrowCatcherK[0]), 1e-9));
      // Envy at its most (+25%) on an orc's blow on a soldier under Rune Gauntlet's might.
      final envy = plain(Random(2))
        ..omens.addAll(List.filled(omenCap, OmenKind.envy))
        ..omenFactor = 2;
      final s = placeNow(envy, 'soldier', 2, 3)..cd = hold;
      placeNow(envy, 'archer', 0, 1).cd = hold;
      s
        ..maxHp = 100000
        ..hp = 100000;
      final o = foeAt(envy, 'orc', s.pos + const Point(12, 0));
      final plainHit = taken(envy, s, o);
      envy.addEffect(s, Status.might, runeGauntletK.time, k: runeGauntletK.might[0], by: s);
      expect(taken(envy, s, o), closeTo(hitTaken(o.stats.dmg * (1 + OmenKind.envy.k.max), s.stats.def), 1e-9));
      expect(plainHit, closeTo(hitTaken(o.stats.dmg, s.stats.def), 1e-9));
    });
  });

  group('the chest, the save, the Shadows\' needs, the log', () {
    test('the chest deals each of the ten (the Epik pool is fifteen now; the run\'s first chest, three Epik, may show '
        'them), binds it by its default rule, and keeps a ★3 one off its cards', () {
      final epik = [for (final r in Relic.values) if (r.pusaka && r.rarity == Rarity.epik && pusakaCatalog[r]!.live) r];
      expect(epik.length, greaterThanOrEqualTo(15), reason: 'the five, the ten, and the later Epik batches (pusaka_epik2_test.dart)');
      expect(epik.skip(5).take(batch.length), batch);
      final epicRoll = chestOddsAt(30).rare + chestOddsAt(30).epic / 2;
      final dealt = <Relic>{};
      for (var pick = 0; pick < epik.length; pick++) {
        final g = plain(Random(1))
          ..offers = true
          ..wave = 30
          ..chestsGiven = 1
          ..draft = _Dice(epicRoll, pick)
          ..giveChests(1);
        expect(g.chest!.cards!.map((r) => r!.rarity), everyElement(Rarity.epik));
        dealt.add(g.chest!.cards!.first!);
      }
      expect(dealt, epik.toSet());
      final first = <Relic>{};
      for (var pick = 0; pick < epik.length; pick++) {
        final g = plain(Random(1))
          ..offers = true
          ..wave = 5
          ..draft = _Dice(0, pick)
          ..giveChests(1);
        expect(g.chest!.epik, isTrue);
        first.addAll(g.chest!.cards!.cast<Relic>());
      }
      expect(first, containsAll(batch), reason: "the run's first chest");
      const army = ['knight', 'archer', 'wizard', 'priest'];
      for (final r in batch) {
        final g = plain(Random(1))
          ..offers = true
          ..wave = 30;
        for (final (i, type) in army.indexed) {
          placeNow(g, type, 2 * (i % 2), 1 + 4 * (i ~/ 2));
        }
        g.chests.add(Chest(ChestKind.boss, 30, cards: [r]));
        expect(g.openChest(), [r], reason: '$r');
        expect(g.takeCard(0), isTrue);
        final type = pusakaPrefs[r]!.firstWhere(army.contains);
        expect((g.pusaka[r]!.stars, g.pusaka[r]!.type), (1, type), reason: '$r');
        g.givePusaka(r, type: type, stars: starMax);
        g.chests.add(Chest(ChestKind.boss, 30, cards: [r]));
        expect(g.openChest(), [null], reason: '$r ★3: a Shard');
      }
      expect(pusakaPrefs[Relic.hawkFeather], isNot(contains('priest')), reason: 'its trade would cut the heal');
      expect(pusakaPrefs[Relic.healerBane]!.first, 'archer');
      expect(pusakaPrefs[Relic.moonwell]!.take(2), ['wizard', 'priest']);
    });

    test("the save keeps an owned one (its type, stars and Carve steps); the owner's save holds none", () {
      final g = plain(Random(1));
      placeNow(g, 'archer', 0, 3);
      placeNow(g, 'knight', 2, 3);
      g
        ..givePusaka(Relic.hawkFeather, type: 'archer', stars: 2, ukir: 3)
        ..givePusaka(Relic.stoneCoat, type: 'knight', stars: 3)
        ..givePusaka(Relic.moonwell, stars: 1);
      final back = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
      final p = back.pusaka;
      expect((p[Relic.hawkFeather]!.type, p[Relic.hawkFeather]!.stars, p[Relic.hawkFeather]!.ukir), ('archer', 2, 3));
      expect((p[Relic.stoneCoat]!.type, p[Relic.stoneCoat]!.stars), ('knight', 3));
      expect(p[Relic.moonwell]!.type, isNull);
      expect(back.gudang, contains(Relic.moonwell));
      expect(back.statsOf('archer').range, closeTo(g.statsOf('archer').range, 1e-9));
      expect(back.statsOf('knight').def, closeTo(g.statsOf('knight').def, 1e-9));
      final w89 = Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>);
      expect(w89.pusaka.keys.where(batch.contains), isEmpty, reason: "the owner's save holds none");
    });

    test("the Shadows' needs: a might source (Envy) from Rune Gauntlet, a weaken source from Witherroot; none of the ten "
        'waits every few hits or on a cooldown, so Off Beat and Drag reach none', () {
      final g = plain(Random(1));
      for (final (type, c, r) in [('knight', 2, 3), ('soldier', 2, 5), ('wizard', 0, 3)]) {
        placeNow(g, type, c, r);
      }
      expect(g.omenMet.intersection({OmenNeed.mightOrHaste, OmenNeed.weaken}), isEmpty);
      g.givePusaka(Relic.runeGauntlet, type: 'soldier');
      expect(g.omenMet, contains(OmenNeed.mightOrHaste));
      g.givePusaka(Relic.witherroot, type: 'knight');
      expect(g.omenMet, contains(OmenNeed.weaken));
      final all = plain(Random(1));
      final types = ['knight', 'soldier', 'wizard', 'archer', 'lancer', 'swordsman', 'armored_axeman', 'knight_templar', 'priest'];
      for (final (i, type) in types.indexed) {
        placeNow(all, type, i % 3, 1 + i % 7);
      }
      for (final (i, r) in batch.indexed) {
        all.givePusaka(r, type: types[i % types.length]);
      }
      expect(all.omenMet.intersection({OmenNeed.everyFx, OmenNeed.cdFx}), isEmpty, reason: 'Off Beat and Drag have nothing to stretch');
      expect(omenCanAct(OmenKind.offBeat, all.omenMet), isFalse);
    });

    test("the battle log's report lines and the counter families; a stat's own counter (never the VICTORY! line's but "
        "Stone Coat's damage kept off)", () {
      String line(Relic r, String type, int uses, double worth) => pusakaReportLines(PusakaReport(1, 0, lines: [
            (relic: r, type: type, stars: 1, uses: uses, worth: worth),
          ])).single;
      expect(line(Relic.healerBane, 'archer', 9, 640), 'Healer Bane (Archer): +640 damage');
      expect(line(Relic.bullyClub, 'swordsman', 4, 1240), "Bully's Club (Swordsman): +1.2k damage");
      expect(line(Relic.unityRing, 'wizard', 20, 900), 'Unity Ring (Wizard): +900 damage');
      expect(line(Relic.runeGauntlet, 'wizard', 4, 0), 'Rune Gauntlet (Wizard): powered up 4 times');
      expect(line(Relic.runeGauntlet, 'wizard', 1, 0), 'Rune Gauntlet (Wizard): powered up once');
      expect(line(Relic.hawkFeather, 'archer', 34, 0), 'Hawk Feather (Archer): 34 hits past its old range');
      expect(line(Relic.witherroot, 'knight', 12, 0), 'Witherroot (Knight): weakened 12 times');
      expect(line(Relic.arrowCatcher, 'knight', 0, 300), 'Arrow Catcher (Knight): +300 damage blocked');
      expect(line(Relic.stoneCoat, 'knight', 0, 450), 'Stone Coat (Knight): +450 damage blocked');
      expect(line(Relic.heroCloak, 'knight', 0, 80), "Hero's Cloak (Knight): +80 damage blocked");
      expect(line(Relic.moonwell, 'wizard', 0, 42), 'Moonwell (Wizard): +42 MP');
      expect({for (final r in batch) r: fxFamily(r)}, {
        Relic.healerBane: FxFamily.added,
        Relic.bullyClub: FxFamily.added,
        Relic.unityRing: FxFamily.added,
        Relic.runeGauntlet: FxFamily.applied,
        Relic.hawkFeather: FxFamily.applied,
        Relic.witherroot: FxFamily.applied,
        Relic.arrowCatcher: FxFamily.keptOff,
        Relic.stoneCoat: FxFamily.keptOff,
        Relic.heroCloak: FxFamily.keptOff,
        Relic.moonwell: FxFamily.mana,
      });
      expect([for (final r in batch) if (fxRaisesHp(r)) r], isEmpty, reason: "Moonwell's max HP goes down");
      final r = PusakaReport(1, 0, lines: [
        (relic: Relic.moonwell, type: 'wizard', stars: 1, uses: 0, worth: 9000),
        (relic: Relic.hawkFeather, type: 'archer', stars: 1, uses: 90, worth: 0),
        (relic: Relic.stoneCoat, type: 'knight', stars: 1, uses: 0, worth: 400),
        (relic: Relic.warDrum, type: 'archer', stars: 1, uses: 3, worth: 120),
      ]);
      expect(r.best?.relic, Relic.stoneCoat);
    });
  });

  group('the Boss Chest card', () {
    /// Boots one TdGame in a [size] window, past the welcome screen, with the game's font.
    Future<Board> boot(WidgetTester tester, Size size) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await loadHudFont(tester);
      final game = TdGame();
      await tester.pumpWidget(GameWidget(game: game));
      for (var i = 0; i < 3000 && !game.isLoaded; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(game.isLoaded, isTrue);
      return game.board
        ..welcome = null
        ..miniMapOpen = false;
    }

    Future<void> frames(WidgetTester tester, [int n = 2]) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    for (final size in const [Size(915, 412), Size(1266, 713)]) {
      testWidgets('each of the ten fits ${size.width.round()}x${size.height.round()}: the purple Epik cards and the buttons '
          'on the screen, apart', (tester) async {
        final b = await boot(tester, size);
        final g = b.state = Game(Random(1)).boardRules()
          ..armyMax = null
          ..gold = 200000
          ..wave = 86
          ..chestsGiven = 1;
        for (final type in ['soldier', 'archer', 'knight', 'priest']) {
          expect(g.autoPlace(type), isTrue);
        }
        // The ten three a chest, the longest together (Bully's Club, Witherroot, Arrow Catcher); the last with an old Epik.
        final hands = [
          [Relic.bullyClub, Relic.witherroot, Relic.arrowCatcher],
          [Relic.healerBane, Relic.unityRing, Relic.runeGauntlet],
          [Relic.hawkFeather, Relic.stoneCoat, Relic.heroCloak],
          [Relic.moonwell, Relic.grail, Relic.bullyClub],
        ];
        g.chests.add(Chest(ChestKind.boss, 86, cards: hands.first));
        await frames(tester, 30);
        expect(b.chestOpen, isTrue);
        for (final hand in hands) {
          g.chests.first.cards = hand;
          await frames(tester, 3);
          final screen = Offset.zero & size, rects = [...b.chestCards, ...b.chestButtons.values];
          expect(b.chestCards, hasLength(3), reason: '$hand');
          for (final (i, r) in rects.indexed) {
            expect(screen.intersect(r), r, reason: '$hand: $r off the screen');
            for (final o in rects.skip(i + 1)) {
              final x = r.intersect(o);
              expect(x.width <= 0 || x.height <= 0, isTrue, reason: '$hand: $r over $o');
            }
          }
        }
        await frames(tester, 30);
      });
    }
  });
}
