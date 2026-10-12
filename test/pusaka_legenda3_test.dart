// Batch G-3 (decisions-log 243; catalog-design §3.3 and §5.2, catalog-bayangan-v2 §4): the last three new Legenda
// Artifacts but the oaths, as catalog rows on the engine's Fx, each a rule with a real cost: what it deals heals the most
// hurt troop near (Vampire Kiss), a healer's heals also smite the monsters next to the troop healed (Wrath Psalm), what it
// hits can't heal (Grave Seal). A Legenda has ★1 only: its ★2 and ★3 read ★1, and Carve moves one named number
// ([ukirPerStar]). Each one's effect at ★1-★3 and carved, its words, its row (rarity, Carve role, the atlas's icon,
// epithet, counter, chest-only), the Shadows that answer it (the batch's Blight, G-3B's Holy Ward, G-1B's Hardy), the
// Shadows' needs it meets, the chest offering it, the save keeping an owned one, the Shop buying one back at the Legenda
// price, the battle-log lines, and the Legenda cards on the Boss Chest at 915x412 and 1266x713. The rules every row keeps
// (key, icon, counter in its pool, a Legenda's cost): pusaka_catalog_test.dart. docs/loot-items-relics.md "The Pusaka
// catalog and its engine".
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

/// The batch's three, in [Relic] order (after batch G-2's eight).
const batch = [Relic.vampireKiss, Relic.wrathPsalm, Relic.graveSeal];

/// The stars and Carve steps each effect is checked at: ★1-★3 bare (a Legenda's ★2 and ★3 are its ★1), then two carved.
const _levels = [(1, 0), (2, 0), (3, 0), (1, 2), (1, 5)];

/// Each one's number Carve moves (its Fx number, [ukirPerStar]) and that Fx's table at ★1, with its step a star.
final _carved = <Relic, (int, double, double)>{
  Relic.vampireKiss: (0, vampireKissK.share, vampireKissK.perStar),
  Relic.wrathPsalm: (0, wrathPsalmK.share, wrathPsalmK.perStar),
  Relic.graveSeal: (0, graveSealK.time, graveSealK.perStar),
};

/// A game with no skills cast, so what happens is the Pusaka's doing.
Game plain([Random? rng]) => bareGame(rng)
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false
  ..monsterSkills = false;

/// Holds [u] where it stands: it neither walks nor attacks.
Unit stand(Unit u) => u
  ..busyUntil = hold
  ..cd = hold;

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
/// bound), that attacks only when told ([blow]), with HP to spare; and a monster of [foe] and [tier] 12 px from it with HP
/// to spare that strikes only when told ([strikeBy]); an archer far behind keeps the game on.
(Game, Unit, Unit) duel(Relic? relic, {String type = 'knight', int stars = 1, int ukir = 0, String foe = 'orc', Tier tier = Tier.normal}) {
  final g = plain(Random(2));
  final u = placeNow(g, type, 2, 3)..cd = hold;
  placeNow(g, 'archer', 0, 1).cd = hold;
  if (relic != null) g.givePusaka(relic, type: type, stars: stars, ukir: ukir);
  u
    ..maxHp = 100000
    ..hp = 100000;
  final o = foeAt(g, foe, u.pos + const Point(12, 0), tier)
    ..maxHp = 1000000
    ..hp = 1e6;
  return (g, u, o);
}

/// A monster of [type] and [tier] at [at] with HP to spare, standing.
Unit bigFoe(Game g, Point<double> at, [String type = 'orc', Tier tier = Tier.normal]) => foeAt(g, type, at, tier)
  ..maxHp = 1000000
  ..hp = 1e6;

/// A troop of [type] at cell ([c], [r]), standing, at [hp] of 100000 max HP.
Unit hurt(Game g, String type, int c, int r, double hp) => stand(placeNow(g, type, c, r))
  ..maxHp = 100000
  ..hp = 100000 * hp;

/// A priest at cell (0, 3), 40 px left of a knight at (2, 3) at half of its 100000 max HP, ready to heal; [relic] on
/// the priests at [stars] and [ukir] Carve steps; monsters of [foe] with HP to spare 12 px right of the knight and 14 px
/// above it ([near], within a tile), and one 24 px below it ([far]). The time of every priest heal is heard ([times]).
(Game, Unit, Unit, List<Unit>, Unit, List<double>) psalmScene(Relic? relic, {int stars = 1, int ukir = 0, String foe = 'orc'}) {
  final g = plain(Random(2));
  final p = placeNow(g, 'priest', 0, 3)..cd = 0;
  final k = hurt(g, 'knight', 2, 3, 0.5);
  p.pos = k.pos + const Point(-40, 0);
  if (relic != null) g.givePusaka(relic, type: 'priest', stars: stars, ukir: ukir);
  final near = [bigFoe(g, k.pos + const Point(12, 0), foe), bigFoe(g, k.pos + const Point(0, -14), foe)];
  final far = bigFoe(g, k.pos + const Point(0, 24), foe);
  final times = <double>[];
  g.onTroopHeal = (u, src, _, _) {
    if (src == HealSrc.heal) times.add(g.t);
  };
  return (g, p, k, near, far, times);
}

/// Ticks [g] until [times] holds [n] heals (at most 20 s).
void untilHeals(Game g, List<double> times, int n) {
  for (var i = 0; i < 400 && times.length < n; i++) {
    g.tick(0.05);
  }
  expect(times.length, greaterThanOrEqualTo(n), reason: 'the priest healed');
}

/// [kind] at its most levels: at the Beban factor 2 that is E8, past every kind's max.
void topOmen(Game g, OmenKind kind) => g
  ..omens.addAll(List.filled(omenCap, kind))
  ..omenFactor = 2;

/// Draft dice that roll every rarity at [roll] (0.99: Legenda) and take the [pick]th card of a pool (wrapping).
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
    test("three Legenda appended after batch G-2's eight (save keys), chest-only (sold back at the Legenda price), ★1 only, "
        "in the game; names, Carve roles, epithets, the atlas's icons and catalog-bayangan-v2's counters (Blight, Holy Ward, "
        'Hardy), which now name them', () {
      expect(Relic.values.skipWhile((r) => r != Relic.glorySeeker).skip(1).take(3).toList(), batch, reason: "G-4's oaths after them");
      expect({for (final r in batch) r: relicNames[r]}, {
        Relic.vampireKiss: 'Vampire Kiss',
        Relic.wrathPsalm: 'Wrath Psalm',
        Relic.graveSeal: 'Grave Seal',
      });
      for (final r in batch) {
        final art = pusakaCatalog[r]!;
        expect((r.rarity, r.scope, r.store, art.live, r.oath, maxStars(r)), (Rarity.legenda, RelicScope.type, false, true, false, 1),
            reason: '$r');
        expect(art.icon.sheet, 'artifact_icons.png', reason: '$r');
        expect((art.icon.x, art.icon.y, art.icon.tint), (artifactIcon(r.name).x, artifactIcon(r.name).y, null), reason: '$r');
        expect(art.healerCounter, isNull, reason: '$r');
        expect(art.fx, hasLength(2), reason: '$r: a trade beside it');
      }
      // Their cells in the Artifact atlas (artifact_icons.dart, mapped with the sheet).
      expect({for (final r in batch) r: artifactIconKinds.indexOf(r.name)}, {Relic.vampireKiss: 79, Relic.wrathPsalm: 80, Relic.graveSeal: 85});
      expect({for (final r in batch) r: pusakaCatalog[r]!.role}, {
        Relic.vampireKiss: UkirRole.life,
        Relic.wrathPsalm: UkirRole.life,
        Relic.graveSeal: UkirRole.attack,
      });
      (String, int, int, int?) cell(Art a) => (a.icon.sheet, a.icon.x, a.icon.y, a.icon.tint);
      final cells = [for (final a in pusakaCatalog.values) cell(a)];
      for (final r in batch) {
        expect(cells.where((c) => c == cell(pusakaCatalog[r]!)), hasLength(1), reason: '$r: its own icon');
      }
      expect(liveG3, isTrue);
      expect({for (final r in batch) r: buildEpithets[r]}, {Relic.vampireKiss: 'Vampiric', Relic.wrathPsalm: 'Wrathful', Relic.graveSeal: 'Grim'});
      expect(buildEpithets.values.toSet().length, buildEpithets.length, reason: 'an epithet twice');
      expect({for (final r in batch) r: pusakaCatalog[r]!.counter}, {
        Relic.vampireKiss: OmenKind.blight,
        Relic.wrathPsalm: OmenKind.holyWard,
        Relic.graveSeal: OmenKind.hardy,
      });
      // The answers filled: Blight (this batch's) and G-3B's Holy Ward name them; Hardy names Vow of Silence too.
      expect({for (final k in const [OmenKind.blight, OmenKind.holyWard, OmenKind.hardy]) k: k.answers}, {
        OmenKind.blight: [Relic.vampireKiss],
        OmenKind.holyWard: [Relic.wrathPsalm],
        OmenKind.hardy: [Relic.vowSilence, Relic.graveSeal],
      });
      for (final r in batch) {
        expect(omenPool(Rarity.legenda), contains(pusakaCatalog[r]!.counter), reason: '$r');
      }
      // The Shop never sells one; one in the Gudang sells to it at its share of legendaPrice; a bound one doesn't.
      expect(storeGoods.where(batch.contains), isEmpty, reason: 'never in the Shop');
      for (final r in batch) {
        final g = Game()
          ..wave = storeFrom
          ..inTown = true; // the Shop buys only in a Town
        expect(g.basePrice(r), legendaPrice, reason: '$r');
        g.givePusaka(r);
        final gold = g.gold;
        expect(g.whyNotSell(r), isNull, reason: '$r in the Gudang');
        expect((g.sellPrice(r), g.sell(r)), ((legendaPrice * sellShare).round(), 1), reason: '$r');
        expect((g.gold - gold, g.pusaka.containsKey(r), g.legendsFound.contains(r)), ((legendaPrice * sellShare).round(), false, true),
            reason: '$r: sold, it stays found');
        final bound = Game()
          ..wave = storeFrom
          ..inTown = true; // the Shop buys only in a Town
        bound.givePusaka(r, type: 'knight');
        expect(bound.whyNotSell(r), StoreRefusal.bound, reason: '$r: equipped');
      }
    });

    test('each leads with its own Fx (no other row shares its key); each pays for its rule (a trade under 1); ★2 and ★3 '
        'read ★1; Carve moves its one named number by its step a star of worth, and nothing else', () {
      final keys = {for (final MapEntry(key: r, value: a) in pusakaCatalog.entries) if (a.fx.isNotEmpty) a.fx.first.key: r};
      for (final r in batch) {
        expect(keys[pusakaCatalog[r]!.fx.first.key], r, reason: '$r');
        for (final fx in pusakaCatalog[r]!.fx) {
          expect(fxBuilt(fx), isTrue, reason: '$r: the engine runs it');
          expect(fx.when, isNull, reason: '$r: no condition');
          expect((fx.k.length, fx.count.isEmpty, fx.furyBeat, fx.every), (1, true, false, 0), reason: '$r: one number');
        }
      }
      Fx fx(Relic r, [int i = 0]) => pusakaCatalog[r]!.fx[i];
      expect((fx(Relic.vampireKiss).on, fx(Relic.vampireKiss).eff, fx(Relic.vampireKiss).to, fx(Relic.vampireKiss).r),
          (Trig.dealt, Eff.heal, To.mostHurtNear, vampireKissK.reach));
      expect((fx(Relic.wrathPsalm).on, fx(Relic.wrathPsalm).eff, fx(Relic.wrathPsalm).to, fx(Relic.wrathPsalm).r, fx(Relic.wrathPsalm).cd),
          (Trig.heals, Eff.burst, To.nearFoes, wrathPsalmK.reach, wrathPsalmK.cd));
      expect((fx(Relic.graveSeal).on, fx(Relic.graveSeal).eff, fx(Relic.graveSeal).to), (Trig.dealt, Eff.noHeal, To.foeHit));
      expect([for (final r in batch) fx(r, 1).k], [
        [vampireKissK.healIn],
        [wrathPsalmK.heal],
        [graveSealK.dmg],
      ], reason: 'the trades, each under 1');
      expect([for (final r in batch) (fx(r, 1).on, fx(r, 1).eff, fx(r, 1).to, fx(r, 1).stat)], [
        (Trig.heals, Eff.heal, To.self, null), // the heals it gets (Rage Totem's trade)
        (Trig.always, Eff.stat, To.type, Stat.dmg), // a healer's heal
        (Trig.always, Eff.stat, To.type, Stat.dmg),
      ]);
      for (final r in batch) {
        final (carved, table, per) = _carved[r]!;
        expect(ukirPerStar[r], (fx: carved, per: per), reason: '$r');
        final art = pusakaCatalog[r]!;
        for (var i = 0; i < art.fx.length; i++) {
          final one = pusakaAt(r, 1, fx: i);
          expect((pusakaAt(r, 2, fx: i), pusakaAt(r, 3, fx: i)), (one, one), reason: '$r: ★2 and ★3 are ★1');
          for (final u in [2, 5]) {
            expect(pusakaAt(r, 1, fx: i, ukir: u), closeTo(i == carved ? one + per * ukirWorthOf(u) : one, 1e-12), reason: '$r fx $i +$u');
          }
        }
        expect(pusakaAt(r, 1, fx: carved), table, reason: '$r');
      }
    });

    test("their words at ★1, from the constants: the card and tooltip lines, the Bag row's gist and the Bag detail's first "
        "sentence (a cost reads on: 'but …'); Carve moves the numbers; plain English", () {
      final g = Game();
      expect({for (final r in batch) r: g.relicEffect(r, stars: 1)}, {
        Relic.vampireKiss: ['12% of its damage heals the most', 'hurt other troop within 2 tiles', 'but heals on it -40%'],
        Relic.wrathPsalm: ['Its heals also strike monsters', 'next to the troop healed: 30%', 'of the heal, at most every 2s', 'but -25% attack or heal'],
        Relic.graveSeal: ["Monsters it hits can't heal for 3s", 'but -10% attack or heal'],
      });
      expect({for (final r in batch) r: pusakaGist(r, 1)}, {
        Relic.vampireKiss: 'Hits: 12% to most hurt',
        Relic.wrathPsalm: 'Heals smite near: 30%',
        Relic.graveSeal: 'Hit: no heals 3s',
      });
      expect({for (final r in batch) r: firstSentence(g.relicEffect(r, stars: 1))}, {
        Relic.vampireKiss: '12% of its damage heals the most hurt other troop within 2 tiles but heals on it -40%',
        Relic.wrathPsalm: 'Its heals also strike monsters next to the troop healed: 30% of the heal, at most every 2s but -25% attack or heal',
        Relic.graveSeal: "Monsters it hits can't heal for 3s but -10% attack or heal",
      });
      for (final r in batch) {
        expect(g.relicEffect(r, stars: 3), g.relicEffect(r, stars: 1), reason: '$r: ★3 is ★1');
      }
      expect(
          (fxLines(Relic.vampireKiss, 1, ukir: 5).first, fxLines(Relic.wrathPsalm, 1, ukir: 5)[1], fxLines(Relic.graveSeal, 1, ukir: 5).first),
          ('14% of its damage heals the most', 'next to the troop healed: 34%', "Monsters it hits can't heal for 3.4s"));
      expect((pusakaGist(Relic.vampireKiss, 1, ukir: 5), pusakaGist(Relic.graveSeal, 1, ukir: 5)), ('Hits: 14% to most hurt', 'Hit: no heals 3.4s'));
      for (final r in batch) {
        for (final (s, u) in _levels) {
          for (final line in [...fxLines(r, s, ukir: u), fxGist(r, s, ukir: u)]) {
            expect(line.codeUnits.every((c) => c < 128), isTrue, reason: '$r: $line');
          }
        }
      }
    });
  });

  group('the effects at ★1, ★2, ★3 and carved', () {
    for (final (stars, ukir) in _levels) {
      final at = '★$stars${ukir > 0 ? ' +$ukir' : ''}';

      test('$at: the number Carve names is its ★1 number, or past it by the Carve steps; the others stay', () {
        for (final r in batch) {
          final (carved, table, per) = _carved[r]!;
          final g = plain()..givePusaka(r, type: r == Relic.wrathPsalm ? 'priest' : 'knight', stars: stars, ukir: ukir);
          expect(g.pusaka[r]!.stars, 1, reason: '$r: ★1 only');
          expect(pusakaAt(r, stars, fx: carved, ukir: ukir), closeTo(table + per * ukirWorthOf(ukir), 1e-12), reason: '$r $at');
        }
      });

      test('$at Vampire Kiss: k of the HP a blow takes off a monster heals the most hurt other troop within 2 tiles '
          '(counted), through the heal funnel; never itself nor one farther; none hurt near: nothing; the heals it gets '
          'land ×0.6 (counted as nothing)', () {
        final k = pusakaAt(Relic.vampireKiss, stars, ukir: ukir);
        final (g, u, orc) = duel(Relic.vampireKiss, stars: stars, ukir: ukir);
        u.hp = u.maxHp * 0.2; // the most hurt of all: never its own
        final near = hurt(g, 'archer', 1, 3, 0.5), mate = hurt(g, 'soldier', 2, 4, 0.7), far = hurt(g, 'wizard', 2, 6, 0.1);
        final dealt = blow(g, u, orc);
        expect(dealt, greaterThan(0));
        expect(near.hp - 50000, closeTo(dealt * k, 1e-9), reason: 'the most hurt near');
        expect((mate.hp, far.hp, u.hp), (70000, 10000, 20000), reason: 'not the less hurt, the one past 2 tiles, itself');
        expect(g.pusakaWorth[Relic.vampireKiss]!.uses, 1);
        expect(g.pusakaWorth[Relic.vampireKiss]!.worth, closeTo(dealt * k, 1e-9));
        // The archer healed full: the soldier next. None hurt near: nothing.
        near.hp = near.maxHp.toDouble();
        final next = blow(g, u, orc);
        expect(mate.hp - 70000, closeTo(next * k, 1e-9));
        mate.hp = mate.maxHp.toDouble();
        final uses = g.pusakaWorth[Relic.vampireKiss]!.uses;
        blow(g, u, orc);
        expect((g.pusakaWorth[Relic.vampireKiss]!.uses, far.hp, u.hp), (uses, 10000, 20000));
        double healed(Relic? relic) {
          final (h, v, _) = duel(relic, stars: stars, ukir: ukir);
          v.hp = 1000;
          h.addEffect(v, Status.heal, 1, k: 100);
          runFor(h, 1.2);
          expect(h.pusakaWorth[Relic.vampireKiss], isNull, reason: 'a trade counts nothing');
          return v.hp - 1000;
        }

        expect(healed(null), greaterThanOrEqualTo(100 - 1e-9));
        expect(healed(Relic.vampireKiss), closeTo(healed(null) * vampireKissK.healIn, 1e-6));
      });

      test("$at Wrath Psalm: a priest's heal also strikes each monster within a tile of the troop healed for k of the heal "
          '(a smite, through its defence; counted), at most once every 2s a priest; one farther, none; the priests heal '
          '×0.75', () {
        final k = pusakaAt(Relic.wrathPsalm, stars, ukir: ukir);
        final (g, p, _, near, far, times) = psalmScene(Relic.wrathPsalm, stars: stars, ukir: ukir);
        expect(g.statsOf('priest').dmg, closeTo(plain().statsOf('priest').dmg * wrathPsalmK.heal, 1e-9), reason: 'the trade');
        // The times a smite landed, against the heals.
        final smites = <double>[];
        var hp = near.first.hp;
        for (var i = 0; i < 400 && times.length < 5; i++) {
          g.tick(0.05);
          if (near.first.hp < hp) {
            smites.add(g.t);
            hp = near.first.hp;
          }
        }
        expect(times, hasLength(5), reason: 'the priest healed');
        expect(smites.length, inInclusiveRange(2, times.length - 1), reason: 'the first heal smote; not every one');
        for (var i = 1; i < smites.length; i++) {
          expect(smites[i] - smites[i - 1], greaterThanOrEqualTo(wrathPsalmK.cd - 1e-6), reason: 'its cooldown');
        }
        final each = hitTaken(p.stats.dmg * k, near.first.stats.def);
        for (final o in near) {
          expect(1e6 - o.hp, closeTo(smites.length * each, 1e-6), reason: 'k of the heal, through its defence');
        }
        expect(far.hp, 1e6, reason: 'past a tile');
        expect(g.pusakaWorth[Relic.wrathPsalm]!.uses, smites.length);
        expect(g.pusakaWorth[Relic.wrathPsalm]!.worth, closeTo(smites.length * each * near.length, 1e-6));
        // No Psalm: no smite.
        final (h, _, _, near0, _, times0) = psalmScene(null);
        untilHeals(h, times0, 2);
        expect([for (final o in near0) o.hp], everyElement(1e6));
      });

      test('$at Grave Seal: a monster it takes HP off heals nothing for k s (a noHeal from the troop; counted: the monsters '
          'sealed fresh, and the HP of the heals it stopped); a new blow runs it from now; once it ends, heals land; the '
          "type's attack ×0.9", () {
        final k = pusakaAt(Relic.graveSeal, stars, ukir: ukir);
        final (g, u, orc) = duel(Relic.graveSeal, stars: stars, ukir: ukir);
        expect(g.statsOf('knight').dmg, closeTo(plain().statsOf('knight').dmg * graveSealK.dmg, 1e-9), reason: 'the trade');
        orc.hp = 5e5;
        blow(g, u, orc);
        final e = g.effectOn(orc, Status.noHeal)!;
        expect((e.by, e.bad), (u, false));
        expect(e.until - g.t, inInclusiveRange(k - 0.051, k + 1e-9));
        final hp = orc.hp;
        g.addEffect(orc, Status.heal, 1, k: 100);
        runFor(g, 1.2);
        expect(orc.hp, hp, reason: 'sealed');
        expect(g.pusakaWorth[Relic.graveSeal]!.uses, 1);
        expect(g.pusakaWorth[Relic.graveSeal]!.worth, greaterThanOrEqualTo(100 - 1e-6), reason: 'the heal it stopped');
        blow(g, u, orc);
        expect(g.effectOn(orc, Status.noHeal)!.until - g.t, inInclusiveRange(k - 0.051, k + 1e-9), reason: 'from the new blow');
        expect(g.pusakaWorth[Relic.graveSeal]!.uses, 1, reason: 'renewed, not sealed fresh');
        runFor(g, k + 0.1);
        expect(g.effectOn(orc, Status.noHeal), isNull);
        final before = orc.hp;
        g.addEffect(orc, Status.heal, 1, k: 100);
        runFor(g, 1.2);
        expect(orc.hp - before, greaterThanOrEqualTo(100 - 1e-6), reason: 'it heals again');
      });
    }
  });

  group('the Shadows that answer them', () {
    setUp(() => omensOn = true);

    test("Blight: a troop a boss's blow blighted gets nothing from Vampire Kiss; the next most hurt one does", () {
      final (g, u, orc) = duel(Relic.vampireKiss);
      topOmen(g, OmenKind.blight);
      final near = hurt(g, 'archer', 1, 3, 0.5), mate = hurt(g, 'soldier', 2, 4, 0.7);
      final boss = bigFoe(g, near.pos + const Point(-12, 0), 'orc', Tier.boss);
      strikeBy(g, boss);
      expect(g.blighted(near), isTrue);
      final (nHp, mHp) = (near.hp, mate.hp);
      final dealt = blow(g, u, orc);
      expect(near.hp, nHp, reason: 'blighted');
      expect(mate.hp - mHp, closeTo(dealt * vampireKissK.share, 1e-9));
    });

    test("Holy Ward cuts Wrath Psalm's smite on a skeleton (a Priest's holy light), not on an orc", () {
      double smite(String foe, {required bool ward}) {
        final (g, _, _, near, _, times) = psalmScene(Relic.wrathPsalm, foe: foe);
        if (ward) topOmen(g, OmenKind.holyWard);
        untilHeals(g, times, 1);
        return 1e6 - near.first.hp;
      }

      expect(smite('skeleton', ward: false), greaterThan(0));
      expect(smite('skeleton', ward: true), closeTo(smite('skeleton', ward: false) * (1 - OmenKind.holyWard.k.max), 1e-6));
      expect(smite('orc', ward: true), closeTo(smite('orc', ward: false), 1e-9));
    });

    test("Grave Seal stops the Shadows' heals too: a sealed boss's Last Gasp heals nothing", () {
      /// What Last Gasp gives the boss on the blow that takes it under the line, after a first blow.
      double gasp(Relic? relic) {
        final (g, u, boss) = duel(relic, tier: Tier.boss);
        topOmen(g, OmenKind.lastGasp);
        final dealt = blow(g, u, boss); // far over the line; under Grave Seal it seals the boss
        final line = boss.maxHp * omenLastGaspAt / 100 + 1;
        boss.hp = line;
        blow(g, u, boss);
        return boss.hp - (line - dealt);
      }

      expect(gasp(null), closeTo(1e6 * OmenKind.lastGasp.k.max, 1e-6), reason: 'Last Gasp heals');
      expect(gasp(Relic.graveSeal), closeTo(0, 1e-6), reason: 'sealed');
      expect(OmenKind.hardy.answers, contains(Relic.graveSeal), reason: 'HP no seal touches: its counter');
    });
  });

  group('the chest, the save, the Shadows\' needs, the log', () {
    test('the chest deals each of the three from wave legendFrom (the Legenda pool is thirty since G-4), binds it by its '
        'default rule, and never offers one found again', () {
      final legenda = [for (final r in Relic.values) if (r.pusaka && r.rarity == Rarity.legenda && pusakaCatalog[r]!.live) r];
      expect(legenda.skip(21).take(3).toList(), batch);
      expect(legenda, hasLength(30)); // G-4's six oaths after them (pusaka_legenda4_test.dart)
      final dealt = <Relic>{};
      for (var pick = 0; pick < legenda.length; pick++) {
        final g = plain()
          ..offers = true
          ..wave = legendFrom
          ..chestsGiven = 1
          ..draft = _Dice(0.99, pick)
          ..giveChests(1);
        expect(g.chest!.cards!.map((r) => r!.rarity), everyElement(Rarity.legenda));
        dealt.add(g.chest!.cards!.first!);
      }
      expect(dealt, legenda.toSet());
      final early = plain()
        ..offers = true
        ..wave = legendFrom - 1
        ..chestsGiven = 1
        ..draft = _Dice(0.99)
        ..giveChests(1);
      expect(early.chest!.cards!.where(batch.contains), isEmpty, reason: 'before legendFrom');
      const army = ['knight', 'archer', 'wizard', 'priest', 'soldier', 'swordsman'];
      for (final r in batch) {
        final g = plain()
          ..offers = true
          ..wave = 30;
        for (final (i, type) in army.indexed) {
          placeNow(g, type, 2 * (i % 2), 1 + 2 * (i ~/ 2));
        }
        g.chests.add(Chest(ChestKind.boss, 30, cards: [r]));
        expect(g.openChest(), [r], reason: '$r');
        expect(g.takeCard(0), isTrue);
        final type = pusakaPrefs[r]!.firstWhere(army.contains);
        expect((g.pusaka[r]!.stars, g.pusaka[r]!.type, g.legendsFound.contains(r)), (1, type, true), reason: '$r');
        g.chests.add(Chest(ChestKind.boss, 30, cards: [r]));
        expect(g.openChest(), [null], reason: '$r: found');
      }
      expect(pusakaPrefs[Relic.wrathPsalm], ['priest'], reason: "only a healer's heal sets it off");
      expect(pusakaPrefs[Relic.vampireKiss]!.contains('priest'), isFalse, reason: 'its trade cuts the heals it gets');
    });

    test("the save keeps an owned one (its type, ★1 and Carve steps) and finds it; the owner's save holds none", () {
      final g = plain(Random(1));
      placeNow(g, 'knight', 2, 3);
      placeNow(g, 'priest', 0, 3);
      g
        ..givePusaka(Relic.vampireKiss, type: 'knight', ukir: 3)
        ..givePusaka(Relic.wrathPsalm, type: 'priest', stars: 3, ukir: 5)
        ..givePusaka(Relic.graveSeal);
      final back = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
      final p = back.pusaka;
      expect((p[Relic.vampireKiss]!.type, p[Relic.vampireKiss]!.stars, p[Relic.vampireKiss]!.ukir), ('knight', 1, 3));
      expect((p[Relic.wrathPsalm]!.type, p[Relic.wrathPsalm]!.stars, p[Relic.wrathPsalm]!.ukir), ('priest', 1, 5));
      expect(p[Relic.graveSeal]!.type, isNull);
      expect(back.gudang, contains(Relic.graveSeal));
      expect(back.legendsFound, {Relic.vampireKiss, Relic.wrathPsalm, Relic.graveSeal});
      expect(back.statsOf('priest').dmg, g.statsOf('priest').dmg, reason: 'the trade works on load');
      expect(jsonEncode(back.toJson()), jsonEncode(g.toJson()));
      final w89 = Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>);
      expect(w89.pusaka.keys.where(batch.contains), isEmpty, reason: "the owner's save holds none");
    });

    test("the Shadows' needs they meet: a heal source (Vampire Kiss); Wrath Psalm's smite is no extra hit (Scatter's); "
        'Grave Seal none', () {
      Game army() {
        final g = plain(Random(1));
        placeNow(g, 'knight', 2, 3);
        placeNow(g, 'archer', 0, 3);
        return g;
      }

      Set<OmenNeed> met(Relic r) => (army()..givePusaka(r, type: 'knight')).omenMet;
      final none = army().omenMet;
      expect(none.contains(OmenNeed.heal), isFalse);
      expect({for (final r in batch) r: met(r).difference(none)}, {
        Relic.vampireKiss: {OmenNeed.heal},
        Relic.wrathPsalm: <OmenNeed>{},
        Relic.graveSeal: <OmenNeed>{},
      });
      for (final kind in const [OmenKind.blight, OmenKind.hardy]) {
        expect(kind.needs, isEmpty, reason: '$kind always acts');
      }
      expect(OmenKind.holyWard.needs, {OmenNeed.healer}, reason: 'a Psalm on a priest meets it');
    });

    test("the battle log's report lines and the counter families", () {
      String line(Relic r, String type, int uses, double worth) => pusakaReportLines(PusakaReport(1, 0, lines: [
            (relic: r, type: type, stars: 1, uses: uses, worth: worth),
          ])).single;
      expect(line(Relic.vampireKiss, 'knight', 9, 1200), 'Vampire Kiss (Knight): +1.2k HP to the most hurt');
      expect(line(Relic.wrathPsalm, 'priest', 4, 640), 'Wrath Psalm (Priest): +640 damage');
      expect(line(Relic.graveSeal, 'archer', 6, 2300), 'Grave Seal (Archer): stopped +2.3k monster heals');
      expect({for (final r in batch) r: fxFamily(r)}, {
        Relic.vampireKiss: FxFamily.healed,
        Relic.wrathPsalm: FxFamily.added,
        Relic.graveSeal: FxFamily.keptOff,
      });
      expect(pusakaCounter((relic: Relic.graveSeal, type: 'archer', stars: 1, uses: 6, worth: 2300)), '+2.3k blocked');
      expect([for (final r in batch) if (fxRaisesHp(r)) r], isEmpty);
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
      testWidgets('each of the three fits ${size.width.round()}x${size.height.round()}: the gold Legenda cards and the '
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
        // The three together (Wrath Psalm's the longest), then each beside two old ones.
        final hands = [
          batch,
          [Relic.wrathPsalm, Relic.manaFont, Relic.hexBlade],
          [Relic.vampireKiss, Relic.graveSeal, Relic.dragonCrown],
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
