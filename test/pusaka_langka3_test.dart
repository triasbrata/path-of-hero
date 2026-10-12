// Batch L-3 (decisions-log 209; catalog-design §3.1 and §5.2, catalog-bayangan-v2 §4 and §5.2): the last six Langka
// Artifacts as catalog rows on the engine's Fx. Each one's effect at ★1, ★2 and ★3 and with Carve steps (the number
// [pusakaAt] gives), its words, its row (rarity, Carve role, the atlas's icon, epithet, counter, chest-only), the
// counters that answer it (Drag, Wound, Scar), Salt Charm and Pure Water against the Bayangan Sap, the chest offering it,
// the save keeping an owned one, what it gives the Shadows' needs, its battle-log line, and its card on the Boss Chest at
// 915x412 and 1266x713. The rules every row keeps (band, key, icon, counter in its pool): pusaka_catalog_test.dart.
// docs/loot-items-relics.md "The Pusaka catalog and its engine".
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

/// The batch's six, in [Relic] order (catalog-design §3.1's).
const batch = [Relic.saltCharm, Relic.wolfFeast, Relic.fullCup, Relic.hiddenFlask, Relic.livingMoss, Relic.pureWater];

/// The stars and Carve steps each effect is checked at: ★1-★3 bare, then two carved.
const _levels = [(1, 0), (2, 0), (3, 0), (1, 2), (3, 5)];

/// A game with no skills cast, so what happens is the Pusaka's doing.
Game plain([Random? rng]) => bareGame(rng)
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false
  ..monsterSkills = false;

/// Lets [foe] strike once now (then it stands again).
void strikeBy(Game g, Unit foe) {
  foe
    ..busyUntil = double.negativeInfinity
    ..cd = 0;
  g.tick(0.05);
  foe.busyUntil = hold;
}

/// What troop [u]'s next normal attack takes off [foe] (its cooldown over now; it waits again after).
double blow(Game g, Unit u, Unit foe) {
  final before = foe.hp;
  u.cd = 0;
  g.tick(0.05);
  u.cd = hold;
  return before - foe.hp;
}

/// A knight standing at (2, 3) with [relic] bound to its type at [stars] and [ukir] Carve steps (none: nothing bound),
/// that attacks only when told ([blow]), and an orc of [tier] next to it with HP to spare that strikes only when told
/// ([strikeBy]); an archer far behind keeps the game on if the knight falls.
(Game, Unit, Unit) duel(Relic? relic, {int stars = 1, int ukir = 0, Tier tier = Tier.normal}) {
  final g = plain(Random(2));
  final k = placeNow(g, 'knight', 2, 3)..cd = hold;
  placeNow(g, 'archer', 0, 1).cd = hold;
  if (relic != null) g.givePusaka(relic, type: 'knight', stars: stars, ukir: ukir);
  final orc = foeAt(g, 'orc', k.pos + const Point(12, 0), tier)
    ..maxHp = 1000000
    ..hp = 1e6;
  return (g, k, orc);
}

/// A monster with 1 HP at [u]'s target spot, put first so [u] hits it before the orc there.
Unit weak(Game g, Unit u) {
  final o = foeAt(g, 'orc', u.pos + const Point(12, 0));
  g.units
    ..remove(o)
    ..insert(0, o);
  return o..hp = 1;
}

/// A priest at (0, 3) with [relic] bound to the priests at [stars] and [ukir] Carve steps, and a knight at (2, 3) at
/// [hp] of its max HP ([maxHp] if given) that never moves or fights; mid-wave (an orc far off). The priest heals on its
/// own; [heals] lists each heal the knight gets (its tag and what went past full), in order.
(Game, Unit, Unit, List<double>) healScene(Relic? relic, {int stars = 1, int ukir = 0, double hp = 0.5, int? maxHp}) {
  final g = plain(Random(2));
  final p = placeNow(g, 'priest', 0, 3);
  final k = placeNow(g, 'knight', 2, 3)
    ..busyUntil = hold
    ..cd = hold;
  if (maxHp != null) k.maxHp = maxHp;
  k.hp = k.maxHp * hp;
  if (relic != null) g.givePusaka(relic, type: 'priest', stars: stars, ukir: ukir);
  foeAt(g, 'orc', const Point(300, 60)); // mid-wave
  final heals = <double>[];
  g.onTroopHeal = (u, src, _, past) {
    if (u == k && src == HealSrc.heal) heals.add(past);
  };
  return (g, p, k, heals);
}

/// Ticks [g] until [heals] has [n] heals (at most 10 s).
void untilHeals(Game g, List<double> heals, int n) {
  for (var i = 0; i < 200 && heals.length < n; i++) {
    g.tick(0.05);
  }
  expect(heals.length, greaterThanOrEqualTo(n), reason: 'the priest healed');
}

/// Draft dice that roll every rarity at [roll] (0: Langka) and take the [pick]th card of a pool (wrapping).
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
    test('six Langka appended after batch L-2P (save keys), chest-only, in the game; names, Carve roles, epithets, the '
        "atlas's icons and catalog-bayangan-v2's counters", () {
      expect(Relic.values.skipWhile((r) => r != Relic.spellCutter).skip(1).take(batch.length).toList(), batch,
          reason: "the last Langka (batch E-1P's Epik follow)");
      expect({for (final r in batch) r: relicNames[r]}, {
        Relic.saltCharm: 'Salt Charm',
        Relic.wolfFeast: 'Wolf Feast',
        Relic.fullCup: 'Full Cup',
        Relic.hiddenFlask: 'Hidden Flask',
        Relic.livingMoss: 'Living Moss',
        Relic.pureWater: 'Pure Water',
      });
      for (final r in batch) {
        final art = pusakaCatalog[r]!;
        expect((r.rarity, r.scope, r.store, art.live, r.oath, maxStars(r)), (Rarity.langka, RelicScope.type, false, true, false, starMax), reason: '$r');
        expect(art.icon.sheet, 'artifact_icons.png', reason: '$r');
        expect((art.icon.x, art.icon.y, art.icon.tint), (artifactIcon(r.name).x, artifactIcon(r.name).y, null), reason: '$r');
        expect(art.fx, hasLength(r == Relic.livingMoss ? 2 : 1), reason: '$r: Living Moss pays for its regen with attack');
      }
      expect(liveL3P, isTrue);
      expect({for (final r in batch) r: pusakaCatalog[r]!.role}, {
        Relic.saltCharm: UkirRole.guard,
        Relic.wolfFeast: UkirRole.life,
        Relic.fullCup: UkirRole.life,
        Relic.hiddenFlask: UkirRole.life,
        Relic.livingMoss: UkirRole.life,
        Relic.pureWater: UkirRole.life,
      });
      expect({for (final r in batch) r: buildEpithets[r]}, {
        Relic.saltCharm: 'Warding',
        Relic.wolfFeast: 'Ravenous',
        Relic.fullCup: 'Brimming',
        Relic.hiddenFlask: 'Prudent',
        Relic.livingMoss: 'Mossy',
        Relic.pureWater: 'Pure',
      });
      expect(buildEpithets.values.toSet().length, buildEpithets.length, reason: 'an epithet twice');
      expect({for (final r in batch) r: pusakaCatalog[r]!.counter}, {
        Relic.saltCharm: OmenKind.quickSpells,
        Relic.wolfFeast: OmenKind.grudge,
        Relic.fullCup: OmenKind.scar,
        Relic.hiddenFlask: OmenKind.pummel,
        Relic.livingMoss: OmenKind.wound,
        Relic.pureWater: OmenKind.drag,
      });
      for (final r in batch) {
        expect(pusakaCatalog[r]!.counter.answers, contains(r), reason: '$r');
        expect(pusakaCatalog[r]!.counter.tiers, contains(Rarity.langka), reason: '$r: a kind of its own pool, after the cut-over');
      }
      final g = Game()..wave = storeFrom;
      expect([for (final r in batch) g.basePrice(r)], everyElement(langkaPrice), reason: 'sold back from the Vault like the four');
      expect(storeGoods.where(batch.contains), isEmpty, reason: 'never in the Shop');
    });

    test('each leads with its own Fx (no other row shares its key); the band measures the heals and the shield (its most); '
        "the regen and the cleanses are exempt; the cleanses' k is their cooldown", () {
      final keys = {for (final MapEntry(key: r, value: a) in pusakaCatalog.entries) if (a.fx.isNotEmpty) a.fx.first.key: r};
      for (final r in batch) {
        expect(keys[pusakaCatalog[r]!.fx.first.key], r, reason: '$r');
      }
      Fx fx(Relic r) => pusakaCatalog[r]!.fx.first;
      for (var s = 1; s <= starMax; s++) {
        expect(fxGain(fx(Relic.wolfFeast), pusakaAt(Relic.wolfFeast, s), 1), (Band.healMaxHp, wolfFeastK[s - 1]));
        expect(fxGain(fx(Relic.hiddenFlask), pusakaAt(Relic.hiddenFlask, s), 1), (Band.healMaxHp, hiddenFlaskK.heal[s - 1]));
        expect(fxGain(fx(Relic.fullCup), pusakaAt(Relic.fullCup, s), 1), (Band.ward, fullCupK.most), reason: 'its most, not its share');
        for (final r in [Relic.livingMoss, Relic.saltCharm, Relic.pureWater]) {
          expect(fxGain(fx(r), pusakaAt(r, s), 1), isNull, reason: '$r: exempt, a probe arm instead');
        }
      }
      expect(fxBandExempt.stats, contains(Stat.regen));
      expect([for (final r in batch) if (fx(r).cooled) r], [Relic.saltCharm, Relic.pureWater]);
      expect([for (final r in batch) if (fx(r).cdByStars) r], [Relic.saltCharm, Relic.pureWater]);
      expect(hardConds.contains(fx(Relic.hiddenFlask).when), isFalse, reason: 'a low troop earns the quarter');
      final moss = pusakaCatalog[Relic.livingMoss]!.fx[1];
      expect((moss.on, moss.eff, moss.stat), (Trig.always, Eff.stat, Stat.dmg), reason: 'the trade');
      expect(moss.k, [livingMossK.dmg]);
    });

    test('their words at ★1, from the constants: the card and tooltip lines, the Bag row\'s gist and the Bag detail\'s '
        'first sentence', () {
      final g = Game();
      expect({for (final r in batch) r: g.relicEffect(r, stars: 1)}, {
        Relic.saltCharm: ['When hit: clears 1 bad effect', 'Every 8s at most'],
        Relic.wolfFeast: ['Each kill heals it 4% max HP'],
        Relic.fullCup: ['Its heals past full HP:', '50% of that becomes a shield', 'up to 12% max HP'],
        Relic.hiddenFlask: ['Once a wave, under 35% HP:', 'heals 20% max HP'],
        Relic.livingMoss: ['Heals 0.4% max HP every second', 'but -10% attack or heal'],
        Relic.pureWater: ['Its heals also clear 1 bad effect', 'Every 3s at most'],
      });
      expect({for (final r in batch) r: pusakaGist(r, 1)}, {
        Relic.saltCharm: 'Hit: clears 1 bad effect',
        Relic.wolfFeast: 'Kill: heals 4% HP',
        Relic.fullCup: 'Extra heal: 50% shield',
        Relic.hiddenFlask: 'Under 35%: heals 20%',
        Relic.livingMoss: 'Heals 0.4% HP a second',
        Relic.pureWater: 'Heal clears 1, every 3s',
      });
      expect({for (final r in batch) r: firstSentence(g.relicEffect(r, stars: 1))}, {
        Relic.saltCharm: 'When hit: clears 1 bad effect',
        Relic.wolfFeast: 'Each kill heals it 4% max HP',
        Relic.fullCup: 'Its heals past full HP: 50% of that becomes a shield up to 12% max HP',
        Relic.hiddenFlask: 'Once a wave, under 35% HP: heals 20% max HP',
        Relic.livingMoss: 'Heals 0.4% max HP every second but -10% attack or heal',
        Relic.pureWater: 'Its heals also clear 1 bad effect',
      });
      // ★2, ★3 and a Carve step move the numbers the words show: a cooldown comes down, a half percent stays.
      expect(g.relicEffect(Relic.saltCharm, stars: 3).last, 'Every 4s at most');
      expect(g.relicEffect(Relic.pureWater, stars: 2).last, 'Every 2.5s at most');
      expect(g.relicEffect(Relic.livingMoss, stars: 2), ['Heals 0.6% max HP every second', 'but -10% attack or heal']);
      expect(g.relicEffect(Relic.fullCup, stars: 3)[1], '100% of that becomes a shield');
      expect(g.relicEffect(Relic.hiddenFlask, stars: 3).last, 'heals 30% max HP');
      expect(pusakaAt(Relic.saltCharm, 1, ukir: 5), lessThan(saltCharmK.cd[0]), reason: 'Carve shortens it, as the stars do');
      expect(fxLines(Relic.livingMoss, 1, ukir: 5).last, 'but -10% attack or heal', reason: 'Carve never moves the trade');
      // Dawn Star's attack line (no trade) is as it was.
      expect(g.relicEffect(Relic.dawnStar, stars: 1), ['+30% attack or heal']);
    });
  });

  group('the effects at ★1, ★2, ★3 and carved', () {
    for (final (stars, ukir) in _levels) {
      final at = '★$stars${ukir > 0 ? ' +$ukir' : ''}';

      test('$at: the table, or past it by the Carve steps', () {
        final i = stars - 1;
        for (final (r, table) in [
          (Relic.saltCharm, saltCharmK.cd),
          (Relic.wolfFeast, wolfFeastK),
          (Relic.fullCup, fullCupK.share),
          (Relic.hiddenFlask, hiddenFlaskK.heal),
          (Relic.livingMoss, livingMossK.regen),
          (Relic.pureWater, pureWaterK.cd),
        ]) {
          final k = pusakaAt(r, stars, ukir: ukir);
          if (ukir == 0) {
            expect(k, table[i], reason: '$r $at');
          } else {
            expect((k - table[i]).abs(), greaterThan(0), reason: '$r $at: Carve moves it');
            expect((k - table[i]).sign, (table[2] - table[0]).sign, reason: '$r $at: the way the stars go');
          }
        }
      });

      test("$at Salt Charm: a blow on it ends the monster's bad effect with the most time left, then it waits k s; with "
          'none on it no wait starts', () {
        final k = pusakaAt(Relic.saltCharm, stars, ukir: ukir);
        final (g, u, orc) = duel(Relic.saltCharm, stars: stars, ukir: ukir);
        strikeBy(g, orc);
        expect(u.fxReady, double.negativeInfinity, reason: 'nothing to clear: no cooldown');
        g
          ..addEffect(u, Status.weaken, 20, k: 0.8, by: orc, bad: true)
          ..addEffect(u, Status.daze, 10, k: 1.25, by: orc, bad: true)
          ..addEffect(u, Status.might, 30, k: 1.2); // its own good effect stays
        strikeBy(g, orc);
        expect(u.effects.keys.toSet(), {Status.daze, Status.might}, reason: 'the longest left ended');
        expect(u.fxReady - g.t, closeTo(k, 0.051));
        expect(g.pusakaWorth[Relic.saltCharm]!.uses, 1);
        strikeBy(g, orc);
        expect(g.under(u, Status.daze), isTrue, reason: 'its cooldown');
        runFor(g, k);
        strikeBy(g, orc);
        expect(g.under(u, Status.daze), isFalse);
        expect(g.under(u, Status.might), isTrue);
        expect(g.pusakaWorth[Relic.saltCharm]!.uses, 2);
      });

      test('$at Wolf Feast: each kill heals it k of its max HP, never past full', () {
        final k = pusakaAt(Relic.wolfFeast, stars, ukir: ukir);
        final (g, u, _) = duel(Relic.wolfFeast, stars: stars, ukir: ukir);
        u.hp = u.maxHp * 0.5;
        final w = weak(g, u);
        blow(g, u, w);
        expect(w.alive, isFalse);
        expect(u.hp, closeTo(u.maxHp * (0.5 + k), 1e-9));
        expect(g.pusakaWorth[Relic.wolfFeast]!.uses, 1);
        expect(g.pusakaWorth[Relic.wolfFeast]!.worth, closeTo(u.maxHp * k, 1e-9));
        u.hp = u.maxHp - 1.0;
        blow(g, u, weak(g, u));
        expect(u.hp, u.maxHp, reason: 'never past full');
        expect(g.pusakaWorth[Relic.wolfFeast]!.worth, closeTo(u.maxHp * k + 1, 1e-9), reason: 'what landed');
      });

      test("$at Full Cup: a priest's heal past full HP gives the troop healed a shield of k of the extra, up to 12% of its "
          'max HP; what the shield soaks counts for it', () {
        final k = pusakaAt(Relic.fullCup, stars, ukir: ukir);
        final (g, p, kn, heals) = healScene(Relic.fullCup, stars: stars, ukir: ukir, hp: 0.99);
        untilHeals(g, heals, 1);
        final past = heals.first;
        expect(past, greaterThan(0));
        expect(past * k, lessThan(kn.maxHp * fullCupK.most), reason: 'under its most');
        expect(kn.ward, closeTo(past * k, 1e-9));
        expect((kn.wardFrom, g.pusakaWorth[Relic.fullCup]!.uses), (Relic.fullCup, 1));
        // A blow on the knight: its shield soaks first, for Full Cup's counter.
        final orc = foeAt(g, 'orc', kn.pos + const Point(12, 0));
        final ward = kn.ward;
        strikeBy(g, orc);
        expect(kn.ward, lessThan(ward));
        expect(g.pusakaWorth[Relic.fullCup]!.worth, closeTo(ward - kn.ward, 1e-9));
        expect(p.alive, isTrue);
        // A small troop: the shield stops at 12% of its max HP.
        final (h, _, small, smallHeals) = healScene(Relic.fullCup, stars: stars, ukir: ukir, hp: 0.99, maxHp: 40);
        untilHeals(h, smallHeals, 1);
        expect(smallHeals.first * k, greaterThan(40 * fullCupK.most));
        expect(small.ward, closeTo(40 * fullCupK.most, 1e-9));
        // A heal that ends under full gives none.
        final (n, _, low, lowHeals) = healScene(Relic.fullCup, stars: stars, ukir: ukir, hp: 0.3);
        untilHeals(n, lowHeals, 1);
        expect((lowHeals.first, low.ward, n.pusakaWorth[Relic.fullCup]?.uses ?? 0), (0, 0, 0));
      });

      test('$at Hidden Flask: once a wave, a blow that leaves it under 35% HP heals it k of its max HP; a blow that fells '
          'it heals nothing; a new wave fills the flask again', () {
        final k = pusakaAt(Relic.hiddenFlask, stars, ukir: ukir);
        final (g, u, orc) = duel(Relic.hiddenFlask, stars: stars, ukir: ukir);
        final hit = hitTaken(orc.stats.dmg, u.stats.def);
        u.hp = u.maxHp * 0.6;
        strikeBy(g, orc);
        expect(g.pusakaWorth[Relic.hiddenFlask], isNull, reason: 'over 35%');
        u.hp = u.maxHp * hiddenFlaskK.below + hit * 0.5; // the next blow takes it under
        strikeBy(g, orc);
        expect(u.hp, closeTo(u.maxHp * (hiddenFlaskK.below + k) - hit * 0.5, 1e-9));
        expect(g.pusakaWorth[Relic.hiddenFlask]!.uses, 1);
        expect(g.pusakaWorth[Relic.hiddenFlask]!.worth, closeTo(u.maxHp * k, 1e-9));
        u.hp = u.maxHp * 0.2;
        strikeBy(g, orc);
        expect(u.hp, closeTo(u.maxHp * 0.2 - hit, 1e-9), reason: 'once a wave');
        // The next wave: again.
        g.units.removeWhere((o) => o.side == Side.enemy);
        g
          ..startWave()
          ..queue.clear();
        final next = foeAt(g, 'orc', u.pos + const Point(12, 0))
          ..maxHp = 1000000
          ..hp = 1e6;
        strikeBy(g, next);
        expect(g.pusakaWorth[Relic.hiddenFlask]!.uses, 1, reason: 'a new wave counts anew');
        expect(u.hp, closeTo(u.maxHp * (0.2 + k) - 2 * hit, 1e-9));
        // A blow that fells it: no heal.
        final (h, v, ho) = duel(Relic.hiddenFlask, stars: stars, ukir: ukir);
        v.hp = hit * 0.5;
        strikeBy(h, ho);
        expect((v.alive, h.pusakaWorth[Relic.hiddenFlask]), (false, null));
      });

      test('$at Living Moss: its type heals k of its max HP every second (its regen, through the heal funnel) and deals '
          '×0.9; its counter counts what the regen healed', () {
        final k = pusakaAt(Relic.livingMoss, stars, ukir: ukir);
        final g = plain(Random(2));
        final base = g.statsOf('knight');
        g.givePusaka(Relic.livingMoss, type: 'knight', stars: stars, ukir: ukir);
        final s = g.statsOf('knight');
        expect(s.regen, closeTo(base.regen + base.hp * k, 1e-9));
        expect(s.dmg, closeTo(base.dmg * livingMossK.dmg, 1e-9));
        expect(s.hp, base.hp);
        final u = placeNow(g, 'knight', 2, 3)..cd = hold;
        final heals = <HealSrc>{};
        g.onTroopHeal = (o, src, _, _) => heals.add(src);
        final orc = foeAt(g, 'orc', const Point(300, 60)); // mid-wave
        u.hp = u.maxHp * 0.5;
        runFor(g, 1);
        expect(u.hp - u.maxHp * 0.5, closeTo(s.regen, 1e-6));
        expect(heals, {HealSrc.regen});
        expect(g.pusakaWorth[Relic.livingMoss]!.worth, closeTo(s.regen, 1e-6));
        expect(orc.alive, isTrue);
        final near = foeAt(g, 'orc', u.pos + const Point(12, 0))
          ..maxHp = 1000000
          ..hp = 1e6;
        expect(blow(g, u, near), closeTo(hitTaken(base.dmg * livingMossK.dmg, near.stats.def), 1e-9), reason: 'its trade');
      });

      test("$at Pure Water: a priest's heal also ends a monster's bad effect on the troop healed (the most time left), "
          'then it waits k s; a heal on a troop with none starts no wait', () {
        final k = pusakaAt(Relic.pureWater, stars, ukir: ukir);
        final (g, p, kn, heals) = healScene(Relic.pureWater, stars: stars, ukir: ukir, hp: 0.3);
        untilHeals(g, heals, 1);
        expect(p.fxReady, double.negativeInfinity, reason: 'nothing to clear: no cooldown');
        final orc = g.enemies.first;
        g
          ..addEffect(kn, Status.weaken, 30, k: 0.8, by: orc, bad: true)
          ..addEffect(kn, Status.daze, 20, k: 1.25, by: orc, bad: true);
        untilHeals(g, heals, 2);
        expect(kn.effects.keys.toSet(), {Status.daze}, reason: 'the longest left ended');
        expect(p.fxReady - g.t, closeTo(k, 0.051));
        expect(g.pusakaWorth[Relic.pureWater]!.uses, 1);
        runFor(g, k - 0.2);
        expect(heals.length, greaterThan(2), reason: 'it healed in its cooldown');
        expect(g.under(kn, Status.daze), isTrue, reason: 'its cooldown');
        runFor(g, 2);
        expect(g.under(kn, Status.daze), isFalse);
        expect(g.pusakaWorth[Relic.pureWater]!.uses, 2);
      });
    }
  });

  group('the counters answer them', () {
    setUp(() => omensOn = true);

    test("Drag stretches Salt Charm's and Pure Water's cooldown; Wound cuts Wolf Feast's, Hidden Flask's and Living Moss's "
        "heals in a wave; under Scar a troop kept under full gets no heal, so no Full Cup shield", () {
      final drag = List.filled(omenCap, OmenKind.drag), wound = List.filled(omenCap, OmenKind.wound);
      // Drag at its most: × 1.5.
      double saltWait(List<OmenKind> omens) {
        final (g, u, orc) = duel(Relic.saltCharm);
        g
          ..omens.addAll(omens)
          ..omenFactor = 2
          ..addEffect(u, Status.weaken, 20, k: 0.8, by: orc, bad: true);
        strikeBy(g, orc);
        return u.fxReady - g.t;
      }

      expect(saltWait(drag), closeTo(saltCharmK.cd[0] * 1.5, 0.051 * 1.5));
      double waterWait(List<OmenKind> omens) {
        final (g, p, kn, heals) = healScene(Relic.pureWater, hp: 0.3);
        g
          ..omens.addAll(omens)
          ..omenFactor = 2
          ..addEffect(kn, Status.weaken, 20, k: 0.8, by: g.enemies.first, bad: true);
        untilHeals(g, heals, 1);
        return p.fxReady - g.t;
      }

      expect(waterWait(drag), closeTo(pureWaterK.cd[0] * 1.5, 0.051 * 1.5));
      // Wound at E8: its most, 48% less.
      final cut = 1 - min(OmenKind.wound.k.max, OmenKind.wound.k.perE * 8);
      final (g, u, _) = duel(Relic.wolfFeast);
      g
        ..omens.addAll(wound)
        ..omenFactor = 2;
      u.hp = u.maxHp * 0.5;
      blow(g, u, weak(g, u));
      expect(u.hp, closeTo(u.maxHp * (0.5 + wolfFeastK[0] * cut), 1e-9));
      final (f, fu, fo) = duel(Relic.hiddenFlask);
      f
        ..omens.addAll(wound)
        ..omenFactor = 2;
      final hit = hitTaken(fo.stats.dmg, fu.stats.def);
      fu.hp = fu.maxHp * 0.3;
      strikeBy(f, fo);
      expect(fu.hp, closeTo(fu.maxHp * (0.3 + hiddenFlaskK.heal[0] * cut) - hit, 1e-9));
      final m = plain(Random(2))..givePusaka(Relic.livingMoss, type: 'knight');
      final mu = placeNow(m, 'knight', 2, 3)..cd = hold;
      m
        ..omens.addAll(wound)
        ..omenFactor = 2;
      foeAt(m, 'orc', const Point(300, 60));
      mu.hp = mu.maxHp * 0.5;
      runFor(m, 1);
      expect(mu.hp - mu.maxHp * 0.5, closeTo(mu.stats.regen * cut, 1e-6));
      // Scar at its most (85%): a knight at 95% is past its ceiling, so the priest passes it by; without Scar it heals it
      // past full, and Full Cup shields it.
      for (final (omens, shielded) in [(const <OmenKind>[], true), (List.filled(omenCap, OmenKind.scar), false)]) {
        final (s, _, kn, heals) = healScene(Relic.fullCup, hp: 0.95);
        s
          ..omens.addAll(omens)
          ..omenFactor = 2;
        runFor(s, 3);
        expect((heals.isNotEmpty, kn.ward > 0), (shielded, shielded), reason: '$omens');
      }
    });
  });

  group('against the Bayangan Sap (the Langka troop debuff)', () {
    setUp(() => omensOn = true);

    test("Salt Charm ends Sap's weaken on the next blow; Pure Water ends it with the next heal", () {
      final sap = List.filled(omenCap, OmenKind.sap);
      final (g, u, orc) = duel(Relic.saltCharm);
      g
        ..omens.addAll(sap)
        ..omenFactor = 2;
      u
        ..maxHp = 100000
        ..hp = 100000;
      for (var i = 0; i < omenSapEvery; i++) {
        strikeBy(g, orc);
      }
      expect(g.effectOn(u, Status.weaken)?.k, closeTo(0.8, 1e-9), reason: 'sapped on the 4th');
      expect(u.fxReady, double.negativeInfinity, reason: 'nothing to clear before it');
      strikeBy(g, orc);
      expect(g.effectOn(u, Status.weaken), isNull, reason: 'Salt Charm cleared it');
      expect(g.pusakaWorth[Relic.saltCharm]!.uses, 1);

      final (h, p, kn, heals) = healScene(Relic.pureWater, hp: 0.5);
      h
        ..omens.addAll(sap)
        ..omenFactor = 2;
      final ho = foeAt(h, 'orc', kn.pos + const Point(12, 0));
      p.cd = hold; // no heal while it is sapped
      for (var i = 0; i < omenSapEvery; i++) {
        strikeBy(h, ho);
      }
      expect(h.effectOn(kn, Status.weaken), isNotNull, reason: 'sapped on the 4th');
      p.cd = 0;
      final sapped = h.t, before = heals.length;
      untilHeals(h, heals, before + 1);
      expect(h.t - sapped, lessThan(omenSapTime), reason: 'a heal before the weaken ran out');
      expect(h.effectOn(kn, Status.weaken), isNull, reason: 'Pure Water cleared it');
      expect(h.pusakaWorth[Relic.pureWater]!.uses, 1);
      expect(p.fxReady, greaterThan(h.t));
    });
  });

  group('the chest, the save, the Shadows\' needs, the log', () {
    test('the chest deals each of the six (the Langka pool is thirty now), binds it by its default rule (the two heal '
        'ones on the priests), and keeps a ★3 one off its cards', () {
      final langka = [for (final r in Relic.values) if (r.pusaka && r.rarity == Rarity.langka && pusakaCatalog[r]!.live) r];
      expect(langka, hasLength(30));
      expect(langka.skip(24), batch);
      final dealt = <Relic>{};
      for (var pick = 0; pick < langka.length; pick++) {
        final g = plain(Random(1))
          ..offers = true
          ..wave = 30
          ..chestsGiven = 1
          ..draft = _Dice(0, pick)
          ..giveChests(1);
        dealt.add(g.chest!.cards!.first!);
      }
      expect(dealt, langka.toSet());
      for (final r in batch) {
        final g = plain(Random(1))
          ..offers = true
          ..wave = 30;
        placeNow(g, 'knight', 2, 3);
        placeNow(g, 'priest', 0, 3);
        g.chests.add(Chest(ChestKind.boss, 30, cards: [r]));
        expect(g.openChest(), [r], reason: '$r');
        expect(g.takeCard(0), isTrue);
        final type = r == Relic.fullCup || r == Relic.pureWater ? 'priest' : 'knight';
        expect((g.pusaka[r]!.stars, g.pusaka[r]!.type), (1, type), reason: '$r');
        g.givePusaka(r, type: type, stars: starMax);
        g.chests.add(Chest(ChestKind.boss, 30, cards: [r]));
        expect(g.openChest(), [null], reason: '$r ★3: a Shard');
      }
      expect({for (final r in [Relic.fullCup, Relic.pureWater]) r: pusakaPrefs[r]}, {
        Relic.fullCup: ['priest'],
        Relic.pureWater: ['priest'],
      });
      for (final r in batch) {
        expect(pusakaPrefs[r], isNotEmpty, reason: '$r');
      }
    });

    test("the save keeps an owned one (its type, stars and Carve steps); the owner's save holds none; a shield and its "
        'giver are not saved', () {
      final g = plain(Random(1));
      final u = placeNow(g, 'knight', 2, 3);
      placeNow(g, 'priest', 0, 3);
      g
        ..givePusaka(Relic.fullCup, type: 'priest', stars: 2, ukir: 3)
        ..givePusaka(Relic.saltCharm, stars: 3);
      u
        ..ward = 10
        ..wardFrom = Relic.fullCup;
      final back = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
      expect((back.pusaka[Relic.fullCup]!.type, back.pusaka[Relic.fullCup]!.stars, back.pusaka[Relic.fullCup]!.ukir), ('priest', 2, 3));
      expect((back.pusaka[Relic.saltCharm]!.type, back.pusaka[Relic.saltCharm]!.stars), (null, 3));
      expect(back.gudang, contains(Relic.saltCharm));
      final v = back.troops.firstWhere((o) => o.type == 'knight');
      expect((v.ward, v.wardFrom), (0, null));
      final w89 = Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>);
      expect(w89.pusaka.keys.where(batch.contains), isEmpty, reason: "the owner's save holds none");
    });

    test("the Shadows' needs: a cooldown (Drag) from the cleanses, a troop shield (Fade, Shieldbreak) from Full Cup, a "
        'heal source (Scar) from the heals and the regen', () {
      final g = plain(Random(1));
      for (final (type, c, r) in [('knight', 2, 3), ('archer', 1, 3), ('soldier', 2, 5), ('lancer', 1, 5)]) {
        placeNow(g, type, c, r);
      }
      expect(g.omenMet.intersection({OmenNeed.cdFx, OmenNeed.troopShield, OmenNeed.heal}), isEmpty);
      g.givePusaka(Relic.saltCharm, type: 'knight');
      expect(g.omenMet, contains(OmenNeed.cdFx));
      for (final (r, type) in [(Relic.wolfFeast, 'archer'), (Relic.hiddenFlask, 'soldier'), (Relic.livingMoss, 'lancer')]) {
        final h = plain(Random(1));
        placeNow(h, type, 2, 3);
        expect(h.omenMet.contains(OmenNeed.heal), isFalse, reason: '$r');
        h.givePusaka(r, type: type);
        expect(h.omenMet, contains(OmenNeed.heal), reason: '$r');
      }
      final p = plain(Random(1));
      placeNow(p, 'priest', 0, 3);
      expect(p.omenMet.intersection({OmenNeed.cdFx, OmenNeed.troopShield}), isEmpty);
      p.givePusaka(Relic.fullCup, type: 'priest');
      expect(p.omenMet, contains(OmenNeed.troopShield));
      p.givePusaka(Relic.pureWater, type: 'priest');
      expect(p.omenMet, contains(OmenNeed.cdFx));
      expect(p.omenMet.contains(OmenNeed.troopShield), isFalse, reason: 'a type holds one: Full Cup went to the Vault');
    });

    test("the battle log's report lines; a cleanse counts what it ended, no worth (never the VICTORY! line's)", () {
      String line(Relic r, String type, int uses, double worth) => pusakaReportLines(PusakaReport(1, 0, lines: [
            (relic: r, type: type, stars: 1, uses: uses, worth: worth),
          ])).single;
      expect(line(Relic.saltCharm, 'knight', 3, 0), 'Salt Charm (Knight): cleared 3 bad effects');
      expect(line(Relic.pureWater, 'priest', 1, 0), 'Pure Water (Priest): cleared 1 bad effect');
      expect(line(Relic.wolfFeast, 'knight', 4, 340), 'Wolf Feast (Knight): +340 HP from kills');
      expect(line(Relic.hiddenFlask, 'knight', 1, 240), 'Hidden Flask (Knight): drunk once, +240 HP');
      expect(line(Relic.hiddenFlask, 'knight', 3, 1240), 'Hidden Flask (Knight): drunk 3 times, +1.2k HP');
      expect(line(Relic.livingMoss, 'knight', 0, 120), 'Living Moss (Knight): +120 HP');
      expect(line(Relic.fullCup, 'priest', 5, 80), 'Full Cup (Priest): +80 damage blocked');
      expect({for (final r in batch) r: fxFamily(r)}, {
        Relic.saltCharm: FxFamily.applied,
        Relic.wolfFeast: FxFamily.healed,
        Relic.fullCup: FxFamily.keptOff,
        Relic.hiddenFlask: FxFamily.healed,
        Relic.livingMoss: FxFamily.healed,
        Relic.pureWater: FxFamily.applied,
      });
      final r = PusakaReport(1, 0, lines: [
        (relic: Relic.saltCharm, type: 'knight', stars: 1, uses: 9, worth: 0),
        (relic: Relic.wolfFeast, type: 'swordsman', stars: 1, uses: 9, worth: 900),
        (relic: Relic.warDrum, type: 'archer', stars: 1, uses: 3, worth: 120),
      ]);
      expect(r.best?.relic, Relic.wolfFeast);
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
      testWidgets('each of the six fits ${size.width.round()}x${size.height.round()}: the cards and the buttons on the '
          'screen, apart', (tester) async {
        final b = await boot(tester, size);
        final g = b.state = Game(Random(1)).boardRules()
          ..armyMax = null
          ..gold = 200000
          ..wave = 86
          ..chestsGiven = 1;
        for (final type in ['soldier', 'archer', 'knight', 'priest']) {
          expect(g.autoPlace(type), isTrue);
        }
        // The six three a chest, the longest together (Full Cup's three lines); the last with L-2P's longest.
        final hands = [
          [Relic.fullCup, Relic.pureWater, Relic.livingMoss],
          [Relic.saltCharm, Relic.wolfFeast, Relic.hiddenFlask],
          [Relic.fullCup, Relic.spellCutter, Relic.saltCharm],
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
