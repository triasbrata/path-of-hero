// Batch E-2P (decisions-log 214; catalog-design §3.2 and §5.2, catalog-bayangan-v2 §4 and §5.2): seven more new Epik
// Artifacts as catalog rows on the engine's Fx. Each one's effect at ★1, ★2 and ★3 and with Carve steps (the number
// [pusakaAt] gives), its words, its row (rarity, Carve role, the atlas's icon, epithet, counter, chest-only), the batch
// E-2B Shadows that answer them (Mark Ward, Close Ranks) and Off Beat on the two that wait every few hits, the Shadows'
// needs they meet, the chest offering them, the save keeping an owned one, the Shop buying one back at its Epik price,
// their battle-log lines, and their cards on the Boss Chest at 915x412 and 1266x713. The rules every row keeps (band,
// key, icon, counter in its pool): pusaka_catalog_test.dart. docs/loot-items-relics.md "The Pusaka catalog and its
// engine".
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

/// The batch's seven, in [Relic] order (catalog-design §3.2's).
const batch = [
  Relic.emberBrand, Relic.funeralPyre, Relic.nullStone, Relic.fallenFlag, Relic.aegisSeal, Relic.wardensHorn, //
  Relic.anchor,
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

/// A troop of [type] standing at (2, 3) with [relic] bound to its type at [stars] and [ukir] Carve steps (none: nothing
/// bound), that attacks only when told ([blow]), with HP to spare; and a monster of [foe] and [tier] 12 px from it (40 px
/// for a shooter) with HP to spare that strikes only when told ([strikeBy]); an archer far behind (its own type, which
/// spends an Ember Brand mark) keeps the game on.
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

/// [g]'s archer (the one [duel] places far behind).
Unit archerOf(Game g) => g.troops.firstWhere((u) => u.type == 'archer');

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
  tearDown(() => omensOn = omensDefault);

  group('the rows', () {
    test("seven Epik appended after batch E-1P's (save keys), chest-only (sold back at the Epik price), in the game; "
        "names, Carve roles, epithets, the atlas's icons and catalog-bayangan-v2's counters (four of batch E-2B's kinds, "
        "today's Mend, E-1B's Counterspell), which now name them", () {
      expect(Relic.values.skipWhile((r) => r != Relic.moonwell).skip(1).take(batch.length).toList(), batch,
          reason: "after batch E-1P's (batch E-3P's follow: pusaka_epik3_test.dart)");
      expect({for (final r in batch) r: relicNames[r]}, {
        Relic.emberBrand: 'Ember Brand',
        Relic.funeralPyre: 'Funeral Pyre',
        Relic.nullStone: 'Null Stone',
        Relic.fallenFlag: 'Fallen Flag',
        Relic.aegisSeal: 'Aegis Seal',
        Relic.wardensHorn: "Warden's Horn",
        Relic.anchor: 'Anchor',
      });
      for (final r in batch) {
        final art = pusakaCatalog[r]!;
        expect((r.rarity, r.scope, r.store, art.live, r.oath, maxStars(r)), (Rarity.epik, RelicScope.type, false, true, false, starMax), reason: '$r');
        expect(art.icon.sheet, 'artifact_icons.png', reason: '$r');
        expect((art.icon.x, art.icon.y, art.icon.tint), (artifactIcon(r.name).x, artifactIcon(r.name).y, null), reason: '$r');
        expect(art.fx, hasLength(r == Relic.anchor ? 2 : 1), reason: '$r: Anchor pays with a trade');
        expect(art.healerCounter, isNull, reason: '$r');
      }
      expect((liveE2P, newEpikStore), (true, false));
      expect({for (final r in batch) r: pusakaCatalog[r]!.role}, {
        Relic.emberBrand: UkirRole.attack,
        Relic.funeralPyre: UkirRole.attack,
        Relic.nullStone: UkirRole.attack,
        Relic.fallenFlag: UkirRole.attack,
        Relic.aegisSeal: UkirRole.guard,
        Relic.wardensHorn: UkirRole.guard,
        Relic.anchor: UkirRole.guard,
      });
      expect({for (final r in batch) r: buildEpithets[r]}, {
        Relic.emberBrand: 'Ember',
        Relic.funeralPyre: 'Burning',
        Relic.nullStone: 'Null',
        Relic.fallenFlag: 'Rallying',
        Relic.aegisSeal: 'Aegis',
        Relic.wardensHorn: 'Warden',
        Relic.anchor: 'Anchored',
      });
      expect(buildEpithets.values.toSet().length, buildEpithets.length, reason: 'an epithet twice');
      expect({for (final r in batch) r: pusakaCatalog[r]!.counter}, {
        Relic.emberBrand: OmenKind.markWard,
        Relic.funeralPyre: OmenKind.closeRanks,
        Relic.nullStone: OmenKind.mend,
        Relic.fallenFlag: OmenKind.triumph,
        Relic.aegisSeal: OmenKind.counterspell,
        Relic.wardensHorn: OmenKind.blindside,
        Relic.anchor: OmenKind.bileSacs,
      });
      for (final r in batch) {
        final counter = pusakaCatalog[r]!.counter;
        expect(counter.answers, contains(r), reason: '$r');
        expect(omenPool(Rarity.epik), contains(counter), reason: '$r');
      }
      expect(OmenKind.mend.answers, [Relic.godThunder, Relic.nullStone], reason: "today's God's Thunder, then Null Stone");
      expect(OmenKind.counterspell.answers.take(2), [Relic.moonwell, Relic.aegisSeal], reason: "batch E-3P's two follow");
      // The Shop never sells one; one in the Vault sells to it at its share of epikPrice (owner, 2026-10-03: "hanya bisa
      // sell ke toko tapi untuk buy tidak bisa").
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

    test('each leads with its own Fx (no other row shares its key); the band measures Ember Brand as an every-3rd power '
        "(at most War Drum's a proc), Fallen Flag's might and Aegis Seal's shield; Funeral Pyre's kill burst, the strip, "
        'the taunt, the stand and the trade are unmeasured (probe arms); the every-few-hits and cooldown ones', () {
      final keys = {for (final MapEntry(key: r, value: a) in pusakaCatalog.entries) if (a.fx.isNotEmpty) a.fx.first.key: r};
      for (final r in batch) {
        expect(keys[pusakaCatalog[r]!.fx.first.key], r, reason: '$r');
      }
      Fx fx(Relic r, [int i = 0]) => pusakaCatalog[r]!.fx[i];
      for (var s = 1; s <= starMax; s++) {
        final i = s - 1;
        expect(fxGain(fx(Relic.emberBrand), pusakaAt(Relic.emberBrand, s), 1), (Band.power, (emberBrandK.hit[i] - 1) / emberBrandK.every));
        expect(emberBrandK.hit[i], lessThanOrEqualTo(perProcMax[i]), reason: 'per proc');
        expect(fxGain(fx(Relic.fallenFlag), pusakaAt(Relic.fallenFlag, s), 1), (Band.power, fallenFlagK.might[i] - 1));
        expect(fxGain(fx(Relic.aegisSeal), pusakaAt(Relic.aegisSeal, s), 1), (Band.ward, aegisSealK[i]));
        expect(fxGain(fx(Relic.funeralPyre), pusakaAt(Relic.funeralPyre, s), 1), isNull, reason: 'a kill burst: a proc');
        expect(funeralPyreK.share[i], lessThanOrEqualTo(1), reason: 'never past the hit itself');
        for (final r in [Relic.nullStone, Relic.wardensHorn]) {
          expect(fxGain(fx(r), pusakaAt(r, s), 1), isNull, reason: '$r: exempt, a probe arm instead');
        }
        expect(fxGain(fx(Relic.anchor, 1), pusakaAt(Relic.anchor, s, fx: 1), 1), isNull, reason: 'a trade is no gain');
      }
      expect(fxGain(fx(Relic.anchor), 0, 1), isNull, reason: 'its stand: exempt');
      expect(fxBandExempt.statuses, containsAll([Status.taunt, Status.noShove]));
      expect(fxBandExempt.effs, contains(Eff.strip));
      expect({for (final r in batch) r: [for (final f in pusakaCatalog[r]!.fx) (f.every, f.cooled)]}, {
        Relic.emberBrand: [(emberBrandK.every, false)],
        Relic.funeralPyre: [(0, true)],
        Relic.nullStone: [(0, true)],
        Relic.fallenFlag: [(0, false)],
        Relic.aegisSeal: [(0, false)],
        Relic.wardensHorn: [(wardensHornK.every, true)],
        Relic.anchor: [(0, false), (0, false)],
      });
      expect(fx(Relic.nullStone).cdByStars, isTrue, reason: "a strip's k is its cooldown");
      expect((fx(Relic.funeralPyre).cd, fx(Relic.wardensHorn).cd), (funeralPyreK.cd, wardensHornK.cd));
      expect(fx(Relic.wardensHorn).when, If.melee, reason: 'its taunt needs a melee holder');
      expect(fx(Relic.wardensHorn).boss, [0.0, 0.0, 0.0], reason: 'none on the boss');
      expect(fx(Relic.anchor).k, isEmpty, reason: 'the whole wave: no number by stars');
      expect(fx(Relic.anchor, 1).k, anchorK.speed, reason: 'the trade carries the stars');
    });

    test("their words at ★1, from the constants: the card and tooltip lines, the Bag row's gist and the Bag detail's first "
        'sentence; ★2, ★3 and Carve move the numbers (Aegis Seal stops at the most a shield gives)', () {
      final g = Game();
      expect({for (final r in batch) r: g.relicEffect(r, stars: 1)}, {
        Relic.emberBrand: ['Every 3rd hit marks the monster', 'for 4s: the next hit on it from', 'another type does x1.5 damage'],
        Relic.funeralPyre: ['When it kills, monsters within 1.5 tiles of', 'the one it killed take 60% of that hit', 'Every 1.5s at most'],
        Relic.nullStone: ['When a monster hits it, that monster', 'loses its good effects (bosses: half time)', 'Every 6s at most'],
        Relic.fallenFlag: ['When one dies, troops within 2 tiles', 'get +20% damage for 4s'],
        Relic.aegisSeal: ['After it uses a skill:', 'a shield of 10% max HP'],
        Relic.wardensHorn: ['Every 6th up-close hit: monsters', 'within 2 tiles must fight it for 2.5s', 'Not the boss. Every 6s at most'],
        Relic.anchor: ["Monsters can't push it back", 'but -15% walk speed'],
      });
      expect({for (final r in batch) r: pusakaGist(r, 1)}, {
        Relic.emberBrand: 'Mark: x1.5 every 3rd',
        Relic.funeralPyre: 'Kill: 60% to near',
        Relic.nullStone: 'Strips attacker, every 6s',
        Relic.fallenFlag: 'Death: near +20% damage',
        Relic.aegisSeal: 'Skill: 10% HP shield',
        Relic.wardensHorn: 'Every 6th: near must fight it',
        Relic.anchor: "Can't be pushed back",
      });
      expect({for (final r in batch) r: firstSentence(g.relicEffect(r, stars: 1))}, {
        Relic.emberBrand: 'Every 3rd hit marks the monster for 4s: the next hit on it from another type does x1.5 damage',
        Relic.funeralPyre: 'When it kills, monsters within 1.5 tiles of the one it killed take 60% of that hit',
        Relic.nullStone: 'When a monster hits it, that monster loses its good effects (bosses: half time)',
        Relic.fallenFlag: 'When one dies, troops within 2 tiles get +20% damage for 4s',
        Relic.aegisSeal: 'After it uses a skill: a shield of 10% max HP',
        Relic.wardensHorn: 'Every 6th up-close hit: monsters within 2 tiles must fight it for 2.5s',
        Relic.anchor: "Monsters can't push it back but -15% walk speed",
      });
      expect(g.relicEffect(Relic.emberBrand, stars: 3).last, 'another type does x2 damage');
      expect(g.relicEffect(Relic.funeralPyre, stars: 2)[1], 'the one it killed take 80% of that hit');
      expect(g.relicEffect(Relic.nullStone, stars: 3).last, 'Every 4s at most');
      expect(g.relicEffect(Relic.fallenFlag, stars: 3).last, 'get +30% damage for 4s');
      expect(g.relicEffect(Relic.aegisSeal, stars: 2).last, 'a shield of 14% max HP');
      expect(g.relicEffect(Relic.wardensHorn, stars: 3)[1], 'within 2 tiles must fight it for 3.5s');
      expect(g.relicEffect(Relic.anchor, stars: 2), ["Monsters can't push it back", 'but -10% walk speed']);
      expect(fxLines(Relic.emberBrand, 3, ukir: 5).last, 'another type does x2.2 damage', reason: 'past ★3 by the last gap');
      expect(fxLines(Relic.nullStone, 3, ukir: 5).last, 'Every 3.2s at most', reason: 'its cooldown shorter');
      expect(fxLines(Relic.aegisSeal, 3, ukir: 5).last, 'a shield of 20% max HP', reason: 'no shield past wardMax');
      expect(fxLines(Relic.anchor, 3, ukir: 5).last, 'but -1% walk speed', reason: 'Carve lightens the trade as a star does');
      // The Bag's "Next:" names the number a Carve step moves: Anchor's walk speed, its stand having none.
      final c = plain(Random(1))..givePusaka(Relic.anchor, type: 'knight', stars: 1);
      expect(c.carveNext(Relic.anchor), (now: '-15%', after: '-14%', rest: 'walk speed'));
    });
  });

  group('the effects at ★1, ★2, ★3 and carved', () {
    for (final (stars, ukir) in _levels) {
      final at = '★$stars${ukir > 0 ? ' +$ukir' : ''}';

      test('$at: the table, or past it by the Carve steps', () {
        final i = stars - 1;
        for (final (r, fx, table) in [
          (Relic.emberBrand, 0, emberBrandK.hit),
          (Relic.funeralPyre, 0, funeralPyreK.share),
          (Relic.nullStone, 0, nullStoneK.cd),
          (Relic.fallenFlag, 0, fallenFlagK.might),
          (Relic.aegisSeal, 0, aegisSealK),
          (Relic.wardensHorn, 0, wardensHornK.time),
          (Relic.anchor, 1, anchorK.speed),
        ]) {
          final k = pusakaAt(r, stars, ukir: ukir, fx: fx);
          if (ukir == 0) {
            expect(k, table[i], reason: '$r $at');
          } else {
            expect((k - table[i]).abs(), greaterThan(0), reason: '$r $at: Carve moves it');
            expect((k - table[i]).sign, (table[2] - table[0]).sign, reason: '$r $at: the way the stars go');
          }
        }
        expect(pusakaAt(Relic.wardensHorn, stars, ukir: ukir, boss: true), 0, reason: 'none on the boss');
      });

      test('$at Ember Brand: every 3rd normal attack marks the monster for 4s; its own type never spends the mark, the '
          "next blow of another type does ×k and spends it; a mark run out does nothing", () {
        final k = pusakaAt(Relic.emberBrand, stars, ukir: ukir);
        final (g, u, orc) = duel(Relic.emberBrand, stars: stars, ukir: ukir);
        final archer = archerOf(g)..pos = u.pos + const Point(-20, 8); // in its range, behind the knight
        final plainArcher = hitTaken(archer.stats.dmg, orc.stats.def);
        for (var n = 1; n < emberBrandK.every; n++) {
          blow(g, u, orc);
          expect(orc.emberMark, isNull, reason: 'blow $n');
        }
        expect(blow(g, u, orc), closeTo(hitTaken(u.stats.dmg, orc.stats.def), 1e-9), reason: 'the marking blow is a plain one');
        final m = orc.emberMark!;
        expect((m.relic, m.from, m.k), (Relic.emberBrand, 'knight', k));
        expect(m.until, closeTo(g.t + emberBrandK.time, 0.051));
        expect(blow(g, u, orc), closeTo(hitTaken(u.stats.dmg, orc.stats.def), 1e-9), reason: 'its own type: no spend');
        expect(orc.emberMark, isNotNull);
        expect(blow(g, archer, orc), closeTo(hitTaken(archer.stats.dmg * k, orc.stats.def), 1e-9), reason: 'another type spends it');
        expect(orc.emberMark, isNull);
        expect(blow(g, archer, orc), closeTo(plainArcher, 1e-9), reason: 'spent: the next one plain');
        expect(g.pusakaWorth[Relic.emberBrand]!.uses, 1);
        expect(g.pusakaWorth[Relic.emberBrand]!.worth, closeTo(archer.stats.dmg * (k - 1), 1e-9));
        // A mark that ran out.
        for (var n = 0; n < emberBrandK.every; n++) {
          blow(g, u, orc);
        }
        expect(orc.emberMark, isNotNull);
        runFor(g, emberBrandK.time + 0.1);
        expect(blow(g, archer, orc), closeTo(plainArcher, 1e-9), reason: 'it ran out');
        expect(orc.emberMark, isNull);
        expect(g.pusakaWorth[Relic.emberBrand]!.uses, 1);
      });

      test('$at Funeral Pyre: its kill burns every other monster within 1.5 tiles of the dead one for k of the killing '
          'blow, after their defence; once every 1.5s at most a troop', () {
        final k = pusakaAt(Relic.funeralPyre, stars, ukir: ukir);
        final (g, u, victim) = duel(Relic.funeralPyre, stars: stars, ukir: ukir);
        victim.hp = 1;
        Unit big(Point<double> at) => foeAt(g, 'orc', at)
          ..maxHp = 1000000
          ..hp = 1e6;
        final near = [big(victim.pos + const Point(8, 10)), big(victim.pos + const Point(14, -8))];
        final far = big(victim.pos + const Point(2 * tile + 10, 0));
        expect(near.every((o) => o.pos.distanceTo(victim.pos) <= funeralPyreK.reach), isTrue);
        blow(g, u, victim);
        expect(victim.alive, isFalse);
        final want = hitTaken(u.stats.dmg * k, near.first.stats.def);
        for (final o in near) {
          expect(1e6 - o.hp, closeTo(want, 1e-6), reason: 'burnt');
        }
        expect(far.hp, 1e6, reason: 'out of reach');
        expect(g.pusakaWorth[Relic.funeralPyre]!.uses, 1);
        expect(g.pusakaWorth[Relic.funeralPyre]!.worth, closeTo(2 * want, 1e-6));
        // A second kill inside the cooldown: no burst; after it, one again.
        Unit next() => foeAt(g, 'orc', u.pos + const Point(12, 0))..hp = 1;
        blow(g, u, next());
        expect(1e6 - near.first.hp, closeTo(want, 1e-6), reason: 'on its cooldown');
        runFor(g, funeralPyreK.cd);
        blow(g, u, next());
        expect(1e6 - near.first.hp, closeTo(2 * want, 1e-6), reason: 'after its cooldown');
        expect(g.pusakaWorth[Relic.funeralPyre]!.uses, 2);
        // With no monster near the dead one, no burst and no cooldown.
        final (h, v, lone) = duel(Relic.funeralPyre, stars: stars, ukir: ukir);
        lone.hp = 1;
        blow(h, v, lone);
        expect((h.pusakaWorth[Relic.funeralPyre], v.fxReady), (null, double.negativeInfinity));
      });

      test("$at Null Stone: a monster that takes HP off it loses its good effects and its guard (the boss and a mini boss "
          'half of what is left); once every k s a troop, the cooldown starting only when one held something', () {
        final cd = pusakaAt(Relic.nullStone, stars, ukir: ukir);
        final (g, u, orc) = duel(Relic.nullStone, stars: stars, ukir: ukir);
        strikeBy(g, orc);
        expect(u.fxReady, double.negativeInfinity, reason: 'nothing to take: no cooldown');
        void buff(Unit o) {
          g.addEffect(o, Status.might, 30, k: 1.3);
          g.addEffect(o, Status.haste, 30, k: 0.8);
          o
            ..guardUntil = g.t + 30
            ..guardCut = 0.3;
        }

        buff(orc);
        strikeBy(g, orc);
        expect((g.effectOn(orc, Status.might), g.effectOn(orc, Status.haste), g.t < orc.guardUntil), (null, null, false));
        expect(g.pusakaWorth[Relic.nullStone]!.uses, 1);
        expect(g.rings.where((r) => r.look == RingLook.dispel), isNotEmpty, reason: "Spellbreaker's rune ring");
        expect(u.fxReady, closeTo(g.t + cd, 0.051));
        buff(orc);
        strikeBy(g, orc);
        expect(g.effectOn(orc, Status.might), isNotNull, reason: 'on its cooldown');
        runFor(g, cd);
        strikeBy(g, orc);
        expect(g.effectOn(orc, Status.might), isNull);
        expect(g.pusakaWorth[Relic.nullStone]!.uses, 2);
        // A troop's own effect on the monster stays (a slow), as Spellbreaker leaves it.
        final (s, su, so) = duel(Relic.nullStone, stars: stars, ukir: ukir);
        s.addEffect(so, Status.slow, 30, k: 0.7, by: su);
        s.addEffect(so, Status.might, 30, k: 1.3);
        strikeBy(s, so);
        expect((s.effectOn(so, Status.slow) != null, s.effectOn(so, Status.might)), (true, null));
        // The boss and a mini boss: half of what is left, once.
        for (final tier in [Tier.boss, Tier.miniBoss]) {
          final (h, v, b) = duel(Relic.nullStone, stars: stars, ukir: ukir, tier: tier);
          h.addEffect(b, Status.might, 20, k: 1.3);
          strikeBy(h, b);
          final e = h.effectOn(b, Status.might)!;
          expect(e.halved, isTrue, reason: '$tier');
          expect(e.until, closeTo(h.t + 10, 0.11), reason: '$tier');
          expect(h.pusakaWorth[Relic.nullStone]!.uses, 1, reason: '$tier');
          expect(v.alive, isTrue);
        }
      });

      test("$at Fallen Flag: when a troop of its type falls, every troop within 2 tiles of it deals ×k for 4s (a might "
          'from the fallen one); farther, none; a stronger might stays', () {
        final k = pusakaAt(Relic.fallenFlag, stars, ukir: ukir);
        final g = plain(Random(2));
        final s = placeNow(g, 'soldier', 2, 3)..cd = hold;
        final mate = placeNow(g, 'soldier', 2, 5)..cd = hold;
        final knight = placeNow(g, 'knight', 1, 3)..cd = hold;
        final strong = placeNow(g, 'knight', 1, 5)..cd = hold;
        final far = placeNow(g, 'archer', 0, 1)..cd = hold;
        g.givePusaka(Relic.fallenFlag, type: 'soldier', stars: stars, ukir: ukir);
        mate.pos = s.pos + const Point(0, tile);
        knight.pos = s.pos + const Point(-tile, tile);
        strong.pos = s.pos + const Point(-tile, -tile);
        far.pos = s.pos + const Point(-3 * tile, 0);
        g.addEffect(strong, Status.might, 30, k: 2.0);
        for (final o in [s, mate, knight, strong, far]) {
          o.busyUntil = hold; // they stand where put: the monster hits the one meant
        }
        s.hp = 1;
        final orc = foeAt(g, 'orc', s.pos + const Point(10, 0));
        strikeBy(g, orc);
        expect(s.alive, isFalse);
        for (final o in [mate, knight]) {
          final m = g.effectOn(o, Status.might)!;
          expect((m.k, m.by, m.bad), (k, s, false), reason: o.type);
          expect(m.until, closeTo(g.t + fallenFlagK.time, 0.051), reason: o.type);
        }
        expect(g.effectOn(far, Status.might), isNull, reason: 'out of reach');
        expect(g.effectOn(strong, Status.might)!.k, 2.0, reason: 'a stronger might stays');
        expect(g.pusakaWorth[Relic.fallenFlag]!.uses, 2);
        // Another type's fall: none.
        g.units.removeWhere((o) => o.side == Side.enemy);
        knight.hp = 1;
        final orc2 = foeAt(g, 'orc', knight.pos + const Point(-10, 0)); // on the far side from the soldier
        mate.effects.remove(Status.might); // ended
        strikeBy(g, orc2);
        expect(knight.alive, isFalse);
        expect(g.effectOn(mate, Status.might), isNull, reason: "a knight's fall: Fallen Flag is the soldiers'");
      });

      test("$at Aegis Seal: a skill cast (its own, a Hero's) gives the caster a shield of k of its max HP (never past "
          'wardMax); what it soaks is its counter', () {
        final k = min(wardMax, pusakaAt(Relic.aegisSeal, stars, ukir: ukir));
        final g = bareGame(Random(1))
          ..heroSkills = false
          ..monsterSkills = false;
        final u = placeNow(g, 'soldier', 2, 3);
        g
          ..givePusaka(Relic.aegisSeal, type: 'soldier', stars: stars, ukir: ukir)
          ..startWave()
          ..queue.clear();
        u
          ..cd = hold
          ..mp = u.stats.mp.toDouble();
        final orcs = [for (final d in const <Point<double>>[Point(10, 0), Point(10, 8)]) foeAt(g, 'orc', u.pos + d)..hp = 1e4];
        g.tick(0.05);
        expect(g.log.entries.whereType<SkillCast>(), hasLength(1), reason: 'Hold Fast cast');
        expect(u.ward, closeTo(u.maxHp * k, 1e-9));
        expect((u.wardFrom, g.pusakaWorth[Relic.aegisSeal]!.uses), (Relic.aegisSeal, 1));
        final ward = u.ward;
        orcs.first.pos = u.pos + const Point(10, 0); // the crowd's shoves moved it off: back in reach
        strikeBy(g, orcs.first);
        expect(g.pusakaWorth[Relic.aegisSeal]!.worth, closeTo(ward - u.ward, 1e-9));
        expect(ward - u.ward, greaterThan(0), reason: 'it soaked the blow');
        // A Hero's cast (Shield Bash) too.
        final (hg, hero) = heroCaster(HeroSkill.shieldBash);
        hg.givePusaka(Relic.aegisSeal, type: hero.type, stars: stars, ukir: ukir);
        foeAt(hg, 'orc', hero.pos + Point(hero.stats.range, 0), Tier.highElite).hp = 1e4;
        hg.tick(0.05);
        expect(hero.heroSkillAt, hg.t, reason: 'Shield Bash cast');
        expect(hero.ward, closeTo(hero.maxHp * k, 1e-9));
      });

      test("$at Warden's Horn: every 6th up-close hit, every monster within 2 tiles of it but the boss must fight it for "
          'k s; once every 6s a troop; never on a type that shoots', () {
        final k = pusakaAt(Relic.wardensHorn, stars, ukir: ukir);
        final (g, u, orc) = duel(Relic.wardensHorn, stars: stars, ukir: ukir);
        Unit big(Point<double> at, [Tier tier = Tier.normal]) => foeAt(g, 'orc', at, tier)
          ..maxHp = 1000000
          ..hp = 1e6;
        final near = [orc, big(u.pos + const Point(0, tile)), big(u.pos + const Point(1.5 * tile, tile), Tier.miniBoss)];
        final boss = big(u.pos + const Point(-tile, 0), Tier.boss);
        final far = big(u.pos + const Point(3 * tile, 0));
        for (var n = 1; n < wardensHornK.every; n++) {
          blow(g, u, orc);
        }
        expect([for (final o in [...near, boss, far]) g.effectOn(o, Status.taunt)], everyElement(isNull));
        blow(g, u, orc);
        for (final o in near) {
          final e = g.effectOn(o, Status.taunt)!;
          expect(e.by, u, reason: '${o.tier}');
          expect(e.until, closeTo(g.t + k, 0.051), reason: '${o.tier}');
        }
        expect((g.effectOn(boss, Status.taunt), g.effectOn(far, Status.taunt)), (null, null), reason: 'the boss; out of reach');
        expect(g.pusakaWorth[Relic.wardensHorn]!.uses, near.length);
        final until = g.effectOn(orc, Status.taunt)!.until;
        for (var n = 0; n < wardensHornK.every; n++) {
          blow(g, u, orc);
        }
        expect((g.effectOn(orc, Status.taunt)!.until, g.pusakaWorth[Relic.wardensHorn]!.uses), (until, near.length), reason: 'on its cooldown');
        runFor(g, wardensHornK.cd);
        for (var n = 0; n < wardensHornK.every; n++) {
          blow(g, u, orc);
        }
        expect(g.pusakaWorth[Relic.wardensHorn]!.uses, 2 * near.length);
        // An archer type holds it: no taunt (its taunt needs a melee holder).
        final (h, a, o) = duel(Relic.wardensHorn, type: 'archer', stars: stars, ukir: ukir);
        for (var n = 0; n < wardensHornK.every; n++) {
          blow(h, a, o);
        }
        expect((h.effectOn(o, Status.taunt), h.pusakaWorth[Relic.wardensHorn]), (null, null));
      });

      test('$at Anchor: its type walks ×speed; from a wave\'s start each of its troops stands its own noShove all wave: a '
          "monster's shove or drag doesn't move it (its counter), a troop bought mid-wave has none, its troops still make "
          'way for each other; another type is moved', () {
        final speed = pusakaAt(Relic.anchor, stars, ukir: ukir, fx: 1);
        final g = plain(Random(2));
        final base = g.statsOf('knight');
        final a = placeNow(g, 'knight', 2, 3), b = placeNow(g, 'knight', 2, 5), s = placeNow(g, 'soldier', 1, 3);
        g.givePusaka(Relic.anchor, type: 'knight', stars: stars, ukir: ukir);
        expect(g.statsOf('knight').speed, closeTo(base.speed * speed, 1e-9));
        expect((g.statsOf('knight').hp, g.statsOf('knight').dmg, g.statsOf('knight').def), (base.hp, base.dmg, base.def));
        g
          ..startWave()
          ..queue.clear();
        foeAt(g, 'orc', const Point(300, 60)); // the wave runs on (a wave starts with none on the field)
        for (final k in [a, b]) {
          final e = g.effectOn(k, Status.noShove)!;
          expect((e.by, e.until), (k, double.infinity));
        }
        expect(g.effectOn(s, Status.noShove), isNull, reason: 'another type');
        final at = a.pos;
        expect(g.knockBack(a, 20), isFalse);
        expect(g.drag(a, a.pos + const Point(-20, 0)), isFalse);
        expect((a.pos, a.move), (at, null));
        expect(g.pusakaWorth[Relic.anchor]!.uses, 2);
        expect(g.knockBack(s, 20), isTrue, reason: 'the soldiers are moved');
        final late = placeNow(g, 'knight', 1, 5);
        expect(g.effectOn(late, Status.noShove), isNull, reason: 'bought mid-wave: it missed the start');
        // Two of its troops on one spot still part (Anchor holds against monsters only); a plain stand would not.
        for (final k in [a, b]) {
          k
            ..busyUntil = hold
            ..cd = hold;
        }
        b.pos = a.pos + const Point(0.5, 0);
        for (var i = 0; i < 10; i++) {
          g.tick(0.05);
        }
        expect(a.pos.distanceTo(b.pos), greaterThan(4), reason: 'they made way');
      });
    }

    test("Bastion's short stand never cuts Anchor's whole-wave one short", () {
      final g = bareGame(Random(1))..skills = false;
      final h = placeNow(g, HeroSkill.bastion.type, 2, 3);
      g.givePusaka(Relic.anchor, type: h.type);
      g
        ..startWave()
        ..queue.clear();
      foeAt(g, 'orc', h.pos + Point(h.stats.range, 0), Tier.miniBoss).hp = 1e4;
      h
        ..hero = true
        ..heroSkill = HeroSkill.bastion
        ..cd = hold
        ..mp = h.stats.mp.toDouble();
      expect(g.effectOn(h, Status.noShove)!.until, double.infinity);
      g.tick(0.05);
      expect(h.heroSkillAt, g.t, reason: 'Bastion cast (a mini boss in reach)');
      expect(g.effectOn(h, Status.cap), isNotNull);
      expect((g.effectOn(h, Status.noShove)!.until, g.effectOn(h, Status.noShove)!.by), (double.infinity, h));
    });
  });

  group('the Shadows that answer them', () {
    setUp(() => omensOn = true);

    test('Mark Ward shortens an Ember Brand mark; Close Ranks guards the monsters next to a kill before Funeral Pyre '
        "burns them; Off Beat makes Ember Brand and Warden's Horn wait longer", () {
      // Mark Ward at its most (-50%).
      final (g, u, orc) = duel(Relic.emberBrand);
      g
        ..omens.addAll(List.filled(omenCap, OmenKind.markWard))
        ..omenFactor = 2;
      for (var n = 0; n < emberBrandK.every; n++) {
        blow(g, u, orc);
      }
      expect(orc.emberMark!.until, closeTo(g.t + emberBrandK.time * (1 - OmenKind.markWard.k.max), 0.051));
      // Close Ranks at its most (-15%) on the neighbours of the dead one: the burst meets the guard.
      final (c, v, victim) = duel(Relic.funeralPyre);
      c
        ..omens.addAll(List.filled(omenCap, OmenKind.closeRanks))
        ..omenFactor = 2;
      victim.hp = 1;
      final nb = foeAt(c, 'orc', victim.pos + const Point(8, 10))
        ..maxHp = 1000000
        ..hp = 1e6;
      blow(c, v, victim);
      expect(c.t < nb.guardUntil && nb.guardOmen, isTrue, reason: 'guarded');
      expect(1e6 - nb.hp, closeTo(hitTaken(v.stats.dmg * funeralPyreK.share[0], nb.stats.def) * (1 - OmenKind.closeRanks.k.max), 1e-6));
      // Off Beat at its most: every few hits waits [omenOffBeat] more.
      final (o, ou, oo) = duel(Relic.emberBrand);
      o.omens.addAll(List.filled(omenCap, OmenKind.offBeat));
      final extra = o.omenOffBeat;
      expect(extra, greaterThan(0));
      for (var n = 1; n < emberBrandK.every + extra; n++) {
        blow(o, ou, oo);
        expect(oo.emberMark, isNull, reason: 'blow $n');
      }
      blow(o, ou, oo);
      expect(oo.emberMark, isNotNull, reason: 'the ${emberBrandK.every + extra}th');
      final (w, wu, wo) = duel(Relic.wardensHorn);
      w.omens.addAll(List.filled(omenCap, OmenKind.offBeat));
      for (var n = 1; n < wardensHornK.every + extra; n++) {
        blow(w, wu, wo);
      }
      expect(w.effectOn(wo, Status.taunt), isNull);
      blow(w, wu, wo);
      expect(w.effectOn(wo, Status.taunt)?.by, wu, reason: 'the ${wardensHornK.every + extra}th');
    });
  });

  group('the chest, the save, the Shadows\' needs, the log', () {
    test('the chest deals each of the seven (the Epik pool is thirty since batch E-3P; the run\'s first chest, three Epik, '
        'may show them), binds it by its default rule, and keeps a ★3 one off its cards', () {
      final epik = [for (final r in Relic.values) if (r.pusaka && r.rarity == Rarity.epik && pusakaCatalog[r]!.live) r];
      expect(epik, hasLength(30));
      expect(epik.skip(15).take(batch.length), batch);
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
      expect(pusakaPrefs[Relic.wardensHorn]!.where((t) => !troopTypes[t]!.melee), isEmpty, reason: 'its taunt needs a melee holder');
      expect(pusakaPrefs[Relic.emberBrand]!.first, 'archer');
    });

    test("the save keeps an owned one (its type, stars and Carve steps); a mark, a stand and a shield are a wave's only; "
        "the owner's save holds none", () {
      final g = plain(Random(1));
      placeNow(g, 'archer', 0, 3);
      placeNow(g, 'knight', 2, 3);
      g
        ..givePusaka(Relic.emberBrand, type: 'archer', stars: 2, ukir: 3)
        ..givePusaka(Relic.anchor, type: 'knight', stars: 3, ukir: 1)
        ..givePusaka(Relic.aegisSeal, stars: 1);
      final back = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
      final p = back.pusaka;
      expect((p[Relic.emberBrand]!.type, p[Relic.emberBrand]!.stars, p[Relic.emberBrand]!.ukir), ('archer', 2, 3));
      expect((p[Relic.anchor]!.type, p[Relic.anchor]!.stars, p[Relic.anchor]!.ukir), ('knight', 3, 1));
      expect(p[Relic.aegisSeal]!.type, isNull);
      expect(back.gudang, contains(Relic.aegisSeal));
      expect(back.statsOf('knight').speed, closeTo(g.statsOf('knight').speed, 1e-9));
      final w89 = Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>);
      expect(w89.pusaka.keys.where(batch.contains), isEmpty, reason: "the owner's save holds none");
    });

    test("the Shadows' needs they meet: every few hits (Ember Brand; Warden's Horn on a melee type only), a cooldown "
        "(Funeral Pyre, Null Stone), a troop shield (Aegis Seal), a might (Fallen Flag), a taunt (Warden's Horn), a mark "
        "and Spite's mark (Ember Brand), an extra hit (Funeral Pyre)", () {
      Game army() {
        final g = plain(Random(1));
        placeNow(g, 'knight', 2, 3);
        placeNow(g, 'archer', 0, 3);
        return g;
      }

      Set<OmenNeed> met(Relic r, String type) => (army()..givePusaka(r, type: type)).omenMet;
      final none = army().omenMet;
      expect(met(Relic.emberBrand, 'archer').difference(none), {OmenNeed.everyFx, OmenNeed.mark, OmenNeed.spiteMark});
      expect(met(Relic.funeralPyre, 'archer').difference(none), {OmenNeed.cdFx, OmenNeed.extraHit});
      expect(met(Relic.nullStone, 'knight').difference(none), {OmenNeed.cdFx});
      expect(met(Relic.fallenFlag, 'knight').difference(none), {OmenNeed.mightOrHaste});
      expect(met(Relic.aegisSeal, 'knight').difference(none), {OmenNeed.troopShield});
      expect(met(Relic.wardensHorn, 'knight').difference(none), {OmenNeed.everyFx, OmenNeed.cdFx, OmenNeed.taunt});
      expect(met(Relic.wardensHorn, 'archer').difference(none), isEmpty, reason: 'a melee holder\'s');
      expect(met(Relic.anchor, 'knight').difference(none), isEmpty);
      expect(OmenNeed.spiteMark.built, isTrue);
    });

    test("the battle log's report lines and the counter families", () {
      String line(Relic r, String type, int uses, double worth) => pusakaReportLines(PusakaReport(1, 0, lines: [
            (relic: r, type: type, stars: 1, uses: uses, worth: worth),
          ])).single;
      expect(line(Relic.emberBrand, 'archer', 6, 840), 'Ember Brand (Archer): +840 damage');
      expect(line(Relic.funeralPyre, 'wizard', 3, 1500), 'Funeral Pyre (Wizard): +1.5k damage');
      expect(line(Relic.nullStone, 'knight', 4, 0), 'Null Stone (Knight): stripped 4 times');
      expect(line(Relic.fallenFlag, 'soldier', 9, 0), 'Fallen Flag (Soldier): powered up 9 times');
      expect(line(Relic.aegisSeal, 'knight', 3, 420), 'Aegis Seal (Knight): +420 damage blocked');
      expect(line(Relic.wardensHorn, 'knight', 12, 0), "Warden's Horn (Knight): taunted 12 times");
      expect(line(Relic.anchor, 'knight', 1, 0), 'Anchor (Knight): stood firm once');
      expect(line(Relic.anchor, 'knight', 3, 0), 'Anchor (Knight): stood firm 3 times');
      expect({for (final r in batch) r: fxFamily(r)}, {
        Relic.emberBrand: FxFamily.added,
        Relic.funeralPyre: FxFamily.added,
        Relic.nullStone: FxFamily.applied,
        Relic.fallenFlag: FxFamily.applied,
        Relic.aegisSeal: FxFamily.keptOff,
        Relic.wardensHorn: FxFamily.applied,
        Relic.anchor: FxFamily.applied,
      });
      expect([for (final r in batch) if (fxRaisesHp(r)) r], isEmpty);
      expect(fxMarks.where((m) => batch.contains(m.$2)), isEmpty, reason: "Ember Brand's mark is spent by one blow: no taken mark");
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
      testWidgets('each of the seven fits ${size.width.round()}x${size.height.round()}: the purple Epik cards and the '
          'buttons on the screen, apart', (tester) async {
        final b = await boot(tester, size);
        final g = b.state = Game(Random(1)).boardRules()
          ..armyMax = null
          ..gold = 200000
          ..wave = 86
          ..chestsGiven = 1;
        for (final type in ['soldier', 'archer', 'knight', 'priest']) {
          expect(g.autoPlace(type), isTrue);
        }
        // The seven three a chest, the longest together (Funeral Pyre, Null Stone, Warden's Horn); the last with an old Epik.
        final hands = [
          [Relic.funeralPyre, Relic.nullStone, Relic.wardensHorn],
          [Relic.emberBrand, Relic.fallenFlag, Relic.aegisSeal],
          [Relic.anchor, Relic.grail, Relic.emberBrand],
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
