// Batch G-1P (decisions-log 231; catalog-design §3.3 and §5.2, catalog-bayangan-v2 §4): the first ten new Legenda
// Artifacts as catalog rows on the engine's Fx, each a rule with a real cost: strong while few (Lone Wolf Pelt), a fall
// that burns the monsters near (Martyr's Flame), blows that sweep (Wide Blows), the Heroes that lead (Champion's
// Mantle), a mark on what hurts it (Vengeance Mark), a wave-long reflect (Mirror Shield), every few blows on it that
// miss (Ghost Step), every few hits a hold (Ice Grip), the small relics worked harder (Relic Altar) and no skill for
// more HP and attack (Vow of Silence). A Legenda has ★1 only: its ★2 and ★3 read ★1, and Carve moves one named number
// ([ukirPerStar]). Each one's effect at ★1-★3 and carved, its words, its row (rarity, Carve role, the atlas's icon,
// epithet, counter, chest-only), the Shadows that answer it, the Shadows' needs it meets, the chest offering it, the
// save keeping an owned one, the Shop buying one back at the Legenda price, the battle-log lines, and the Legenda cards
// on the Boss Chest at 915x412 and 1266x713. The rules every row keeps (key, icon, counter in its pool, a Legenda's
// cost): pusaka_catalog_test.dart. docs/loot-items-relics.md "The Pusaka catalog and its engine".
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

/// The batch's ten, in [Relic] order (after the Smithy's small relics).
const batch = [
  Relic.loneWolf, Relic.martyrFlame, Relic.wideBlows, Relic.champion, Relic.vengeance, Relic.mirror, Relic.ghostStep, //
  Relic.iceGrip, Relic.relicAltar, Relic.vowSilence,
];

/// The stars and Carve steps each effect is checked at: ★1-★3 bare (a Legenda's ★2 and ★3 are its ★1), then two carved.
const _levels = [(1, 0), (2, 0), (3, 0), (1, 2), (1, 5)];

/// Each one's number Carve moves (its Fx number, [ukirPerStar]) and that Fx's table at ★1, with its step a star.
final _carved = <Relic, (int, double, double)>{
  Relic.loneWolf: (0, loneWolfK.power, loneWolfK.perStar),
  Relic.martyrFlame: (0, martyrFlameK.share, martyrFlameK.perStar),
  Relic.wideBlows: (1, wideBlowsK.dmg, wideBlowsK.perStar),
  Relic.champion: (0, championK.hero, championK.perStar),
  Relic.vengeance: (0, vengeanceK.taken, vengeanceK.perStar),
  Relic.mirror: (0, mirrorK.share, mirrorK.perStar),
  Relic.ghostStep: (1, ghostStepK.dmg, ghostStepK.perStar),
  Relic.iceGrip: (0, iceGripK.hold, iceGripK.perStar),
  Relic.relicAltar: (0, relicAltarK.k, relicAltarK.perStar),
  Relic.vowSilence: (0, vowSilenceK.k, vowSilenceK.perStar),
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

/// What a blow on [u] by [foe] takes off it.
double taken(Game g, Unit u, Unit foe) {
  final before = u.hp;
  strikeBy(g, foe);
  return before - u.hp;
}

/// A troop of [type] standing at (2, 3) with [relic] bound to its type at [stars] and [ukir] Carve steps (none: nothing
/// bound), that attacks only when told ([blow]), with HP to spare; and a monster of [foe] and [tier] 12 px from it (40 px
/// for a shooter) with HP to spare that strikes only when told ([strikeBy]); an archer far behind keeps the game on.
/// [wave]: a wave begun first (its `waveStart` Fx: Mirror Shield's), with nothing left to spawn.
(Game, Unit, Unit) duel(Relic? relic,
    {String type = 'knight', int stars = 1, int ukir = 0, String foe = 'orc', Tier tier = Tier.normal, bool wave = false}) {
  final g = plain(Random(2));
  final u = placeNow(g, type, 2, 3)..cd = hold;
  placeNow(g, 'archer', 0, 1).cd = hold;
  if (relic != null) g.givePusaka(relic, type: type, stars: stars, ukir: ukir);
  if (wave) {
    g
      ..startWave()
      ..queue.clear();
  }
  u
    ..maxHp = 100000
    ..hp = 100000;
  final o = foeAt(g, foe, u.pos + Point(foe == 'skeleton_archer' ? 40 : 12, 0), tier)
    ..maxHp = 1000000
    ..hp = 1e6;
  return (g, u, o);
}

/// A monster of [type] at [at] with HP to spare, standing.
Unit bigFoe(Game g, Point<double> at, [String type = 'orc']) => foeAt(g, type, at)
  ..maxHp = 1000000
  ..hp = 1e6;

/// A soldier at cell (2, 3) holding [relic] on its type (none: nothing), in a wave, its MP full and its attack held,
/// with two orcs beside it (Hold Fast's crowd): its next tick casts Hold Fast, unless it may not.
(Game, Unit) castScene(Relic? relic) {
  final g = bareGame(Random(1))
    ..heroSkills = false
    ..monsterSkills = false;
  final u = placeNow(g, 'soldier', 2, 3);
  if (relic != null) g.givePusaka(relic, type: 'soldier');
  g
    ..startWave()
    ..queue.clear();
  u
    ..cd = hold
    ..mp = u.stats.mp.toDouble();
  for (final d in const <Point<double>>[Point(10, 0), Point(10, -8)]) {
    foeAt(g, 'orc', u.pos + d).hp = 1e4;
  }
  return (g, u);
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
    test("ten Legenda appended after the Smithy's small relics (save keys), chest-only (sold back at the Legenda price), "
        "★1 only, in the game; names, Carve roles, epithets, the atlas's icons and catalog-bayangan-v2's counters (batch "
        "G-1B's kinds), which now name them", () {
      expect(Relic.values.skipWhile((r) => r != Relic.blessing).skip(1).take(batch.length).toList(), batch,
          reason: "after the Smithy's seven (batch G-2's follow)");
      expect({for (final r in batch) r: relicNames[r]}, {
        Relic.loneWolf: 'Lone Wolf Pelt',
        Relic.martyrFlame: "Martyr's Flame",
        Relic.wideBlows: 'Wide Blows',
        Relic.champion: "Champion's Mantle",
        Relic.vengeance: 'Vengeance Mark',
        Relic.mirror: 'Mirror Shield',
        Relic.ghostStep: 'Ghost Step',
        Relic.iceGrip: 'Ice Grip',
        Relic.relicAltar: 'Relic Altar',
        Relic.vowSilence: 'Vow of Silence',
      });
      for (final r in batch) {
        final art = pusakaCatalog[r]!;
        expect((r.rarity, r.scope, r.store, art.live, r.oath, maxStars(r)), (Rarity.legenda, RelicScope.type, false, true, false, 1),
            reason: '$r');
        expect(art.icon.sheet, 'artifact_icons.png', reason: '$r');
        expect((art.icon.x, art.icon.y, art.icon.tint), (artifactIcon(r.name).x, artifactIcon(r.name).y, null), reason: '$r');
        expect(art.healerCounter, isNull, reason: '$r');
        expect(art.fx, hasLength(r == Relic.loneWolf ? 1 : 2), reason: '$r: a condition, or a trade beside it');
      }
      expect({for (final r in batch) r: pusakaCatalog[r]!.role}, {
        Relic.loneWolf: UkirRole.attack,
        Relic.martyrFlame: UkirRole.attack,
        Relic.wideBlows: UkirRole.attack,
        Relic.champion: UkirRole.attack,
        Relic.vengeance: UkirRole.attack,
        Relic.mirror: UkirRole.guard,
        Relic.ghostStep: UkirRole.guard,
        Relic.iceGrip: UkirRole.guard,
        Relic.relicAltar: UkirRole.attack,
        Relic.vowSilence: UkirRole.attack,
      });
      (String, int, int, int?) cell(Art a) => (a.icon.sheet, a.icon.x, a.icon.y, a.icon.tint);
      final cells = [for (final a in pusakaCatalog.values) cell(a)];
      for (final r in batch) {
        expect(cells.where((c) => c == cell(pusakaCatalog[r]!)), hasLength(1), reason: '$r: its own icon');
      }
      expect(liveG1P, isTrue);
      expect({for (final r in batch) r: buildEpithets[r]}, {
        Relic.loneWolf: 'Lone',
        Relic.martyrFlame: 'Martyred',
        Relic.wideBlows: 'Sweeping',
        Relic.champion: 'Champion',
        Relic.vengeance: 'Vengeful',
        Relic.mirror: 'Mirrored',
        Relic.ghostStep: 'Ghostly',
        Relic.iceGrip: 'Frozen',
        Relic.relicAltar: 'Hallowed',
        Relic.vowSilence: 'Silent',
      });
      expect(buildEpithets.values.toSet().length, buildEpithets.length, reason: 'an epithet twice');
      final counters = {
        Relic.loneWolf: OmenKind.blunt,
        Relic.martyrFlame: OmenKind.veterans,
        Relic.wideBlows: OmenKind.scatter,
        Relic.champion: OmenKind.horde,
        Relic.vengeance: OmenKind.spite,
        Relic.mirror: OmenKind.thornproof,
        Relic.ghostStep: OmenKind.executioner,
        Relic.iceGrip: OmenKind.unbowed,
        Relic.relicAltar: OmenKind.rust,
        Relic.vowSilence: OmenKind.hardy,
      };
      expect({for (final r in batch) r: pusakaCatalog[r]!.counter}, counters);
      for (final MapEntry(key: r, value: kind) in counters.entries) {
        expect(kind.answers, [r, if (kind == OmenKind.unbowed) Relic.hexBlade, if (kind == OmenKind.hardy) Relic.graveSeal],
            reason: '$kind: the Artifacts that name it (G-2: Hex Blade; G-3: Grave Seal)');
        expect(omenPool(Rarity.legenda), contains(kind), reason: '$r');
      }
      // The Shop never sells one; one in the Gudang sells to it at its share of legendaPrice; a bound one doesn't.
      expect(storeGoods.where(batch.contains), isEmpty, reason: 'never in the Shop');
      for (final r in batch) {
        final g = Game()..wave = storeFrom;
        expect(g.basePrice(r), legendaPrice, reason: '$r');
        g.givePusaka(r);
        final gold = g.gold;
        expect(g.whyNotSell(r), isNull, reason: '$r in the Gudang');
        expect((g.sellPrice(r), g.sell(r)), ((legendaPrice * sellShare).round(), 1), reason: '$r');
        expect((g.gold - gold, g.pusaka.containsKey(r), g.legendsFound.contains(r)), ((legendaPrice * sellShare).round(), false, true),
            reason: '$r: sold, it stays found');
        final bound = Game()..wave = storeFrom;
        bound.givePusaka(r, type: 'knight');
        expect(bound.whyNotSell(r), StoreRefusal.bound, reason: '$r: equipped');
      }
    });

    test('each leads with its own Fx (no other row shares its key); each pays for its rule (a condition, or a trade: a '
        'number under 1, a cut under 0, no skills); ★2 and ★3 read ★1; Carve moves its one named number by its step a '
        'star of worth, and nothing else; the every-Nth ones are Legenda (no Off Beat, no Fury beat)', () {
      final keys = {for (final MapEntry(key: r, value: a) in pusakaCatalog.entries) if (a.fx.isNotEmpty) a.fx.first.key: r};
      for (final r in batch) {
        expect(keys[pusakaCatalog[r]!.fx.first.key], r, reason: '$r');
        for (final fx in pusakaCatalog[r]!.fx) {
          expect(fxBuilt(fx), isTrue, reason: '$r: the engine runs it');
          expect(fx.when == null || fxIfsBuilt.contains(fx.when), isTrue, reason: '$r');
          expect((fx.k.length <= 1, fx.count.isEmpty, fx.cd, fx.furyBeat), (true, true, 0.0, false), reason: '$r: one number, no cooldown');
        }
      }
      Fx fx(Relic r, [int i = 0]) => pusakaCatalog[r]!.fx[i];
      expect((fx(Relic.loneWolf).when, fx(Relic.loneWolf).ifK), (If.fewOfType, loneWolfK.few.toDouble()));
      expect([fx(Relic.champion).when, fx(Relic.champion, 1).when], [If.hero, If.notHero]);
      expect([for (final r in batch.skip(1)) fx(r, 1).k], [
        [martyrFlameK.hp],
        [wideBlowsK.dmg],
        [championK.rest],
        [1 - vengeanceK.selfTaken],
        [mirrorK.dmg],
        [ghostStepK.dmg],
        [iceGripK.dmg],
        [relicAltarK.hp],
        <double>[],
      ], reason: 'the trades');
      expect((fx(Relic.vowSilence, 1).on, fx(Relic.vowSilence, 1).eff), (Trig.always, Eff.skillGate));
      for (final r in batch.skip(1)) {
        expect(fx(r, 1).k.every((k) => k < 1), isTrue, reason: '$r: its cost');
      }
      expect({for (final r in batch) r: fx(r).every}, {
        Relic.loneWolf: 0,
        Relic.martyrFlame: 0,
        Relic.wideBlows: 0,
        Relic.champion: 0,
        Relic.vengeance: 0,
        Relic.mirror: 0,
        Relic.ghostStep: ghostStepK.every,
        Relic.iceGrip: iceGripK.every,
        Relic.relicAltar: 0,
        Relic.vowSilence: 0,
      });
      expect((fx(Relic.martyrFlame).r, fx(Relic.wideBlows).k.single, fx(Relic.vengeance).time), (martyrFlameK.reach, wideBlowsK.splash, vengeanceK.time));
      expect((fx(Relic.vengeance).boss!.single, fx(Relic.iceGrip).boss!.single, fx(Relic.iceGrip).time),
          (vengeanceK.boss, iceGripK.bossSlow, iceGripK.bossTime));
      expect(fx(Relic.ghostStep).k, isEmpty, reason: 'a miss has no strength');
      for (final r in batch) {
        final (carved, table, per) = _carved[r]!;
        expect(ukirPerStar[r], (fx: carved, per: per), reason: '$r');
        final art = pusakaCatalog[r]!;
        for (var i = 0; i < art.fx.length; i++) {
          if (art.fx[i].k.isEmpty) continue;
          final one = pusakaAt(r, 1, fx: i);
          expect((pusakaAt(r, 2, fx: i), pusakaAt(r, 3, fx: i)), (one, one), reason: '$r: ★2 and ★3 are ★1');
          for (final u in [2, 5]) {
            expect(pusakaAt(r, 1, fx: i, ukir: u), closeTo(i == carved ? one + per * ukirWorthOf(u) : one, 1e-12), reason: '$r fx $i +$u');
            if (art.fx[i].boss != null) expect(pusakaAt(r, 1, fx: i, ukir: u, boss: true), art.fx[i].boss!.first, reason: "$r: the boss's stays");
          }
        }
        expect(pusakaAt(r, 1, fx: carved), table, reason: '$r');
      }
      expect(ukirWorthOf(5), closeTo(0.8, 1e-12));
    });

    test("their words at ★1, from the constants: the card and tooltip lines, the Bag row's gist and the Bag detail's first "
        "sentence (a cost reads on: 'but …'); Carve moves the numbers; plain English", () {
      final g = Game();
      expect({for (final r in batch) r: g.relicEffect(r, stars: 1)}, {
        Relic.loneWolf: ['While 3 or fewer of this type live:', '+100% damage'],
        Relic.martyrFlame: ['When one dies: monsters within', '2 tiles take 60% of its max HP', 'but -10% max HP'],
        Relic.wideBlows: ['Every hit also hits monsters', 'next to the target', 'but -20% attack or heal'],
        Relic.champion: ["This type's Heroes: +80% damage", 'but the others: -10% damage'],
        Relic.vengeance: ['A monster that hits it takes', '+25% damage for 4s (boss +12%)', 'but it takes +15% damage'],
        Relic.mirror: ['Monsters that hit it up close', 'take 40% of the hit back', 'but -20% attack or heal'],
        Relic.ghostStep: ['Every 3rd hit on it misses', 'but -20% attack or heal'],
        Relic.iceGrip: ['Every 4th hit holds the monster', 'for 1s (bosses: -30% speed)', 'but -15% attack or heal'],
        Relic.relicAltar: ['Relics on this type work +50%', 'but -15% max HP'],
        Relic.vowSilence: ['+40% HP and attack', 'but it never uses skills'],
      });
      expect({for (final r in batch) r: pusakaGist(r, 1)}, {
        Relic.loneWolf: '3 or fewer: +100%',
        Relic.martyrFlame: 'Death: 60% HP to near',
        Relic.wideBlows: 'Hits splash near target',
        Relic.champion: 'Heroes: +80% damage',
        Relic.vengeance: 'Attacker takes +25%',
        Relic.mirror: 'Up close: 40% back',
        Relic.ghostStep: 'Every 3rd hit misses',
        Relic.iceGrip: 'Every 4th: hold 1s',
        Relic.relicAltar: 'Relics +50%',
        Relic.vowSilence: '+40% HP, no skills',
      });
      expect({for (final r in batch) r: firstSentence(g.relicEffect(r, stars: 1))}, {
        Relic.loneWolf: 'While 3 or fewer of this type live: +100% damage',
        Relic.martyrFlame: 'When one dies: monsters within 2 tiles take 60% of its max HP but -10% max HP',
        Relic.wideBlows: 'Every hit also hits monsters next to the target but -20% attack or heal',
        Relic.champion: "This type's Heroes: +80% damage but the others: -10% damage",
        Relic.vengeance: 'A monster that hits it takes +25% damage for 4s (boss +12%) but it takes +15% damage',
        Relic.mirror: 'Monsters that hit it up close take 40% of the hit back but -20% attack or heal',
        Relic.ghostStep: 'Every 3rd hit on it misses but -20% attack or heal',
        Relic.iceGrip: 'Every 4th hit holds the monster for 1s (bosses: -30% speed) but -15% attack or heal',
        Relic.relicAltar: 'Relics on this type work +50% but -15% max HP',
        Relic.vowSilence: '+40% HP and attack but it never uses skills',
      });
      for (final r in batch) {
        expect(g.relicEffect(r, stars: 3), g.relicEffect(r, stars: 1), reason: '$r: ★3 is ★1');
      }
      expect({for (final r in batch) r: fxLines(r, 1, ukir: 5)}, {
        Relic.loneWolf: ['While 3 or fewer of this type live:', '+112% damage'],
        Relic.martyrFlame: ['When one dies: monsters within', '2 tiles take 68% of its max HP', 'but -10% max HP'],
        Relic.wideBlows: ['Every hit also hits monsters', 'next to the target', 'but -16% attack or heal'],
        Relic.champion: ["This type's Heroes: +88% damage", 'but the others: -10% damage'],
        Relic.vengeance: ['A monster that hits it takes', '+29% damage for 4s (boss +12%)', 'but it takes +15% damage'],
        Relic.mirror: ['Monsters that hit it up close', 'take 44% of the hit back', 'but -20% attack or heal'],
        Relic.ghostStep: ['Every 3rd hit on it misses', 'but -16% attack or heal'],
        Relic.iceGrip: ['Every 4th hit holds the monster', 'for 1.2s (bosses: -30% speed)', 'but -15% attack or heal'],
        Relic.relicAltar: ['Relics on this type work +58%', 'but -15% max HP'],
        Relic.vowSilence: ['+44% HP and attack', 'but it never uses skills'],
      });
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
          final g = plain()..givePusaka(r, type: 'knight', stars: stars, ukir: ukir);
          expect(g.pusaka[r]!.stars, 1, reason: '$r: ★1 only');
          expect(pusakaAt(r, stars, fx: carved, ukir: ukir), closeTo(table + per * ukirWorthOf(ukir), 1e-12), reason: '$r $at');
        }
      });

      test('$at Lone Wolf Pelt: while 3 or fewer of its type live their normal attacks do ×k; with 4 as before', () {
        final k = pusakaAt(Relic.loneWolf, stars, ukir: ukir);
        final (g, u, orc) = duel(Relic.loneWolf, stars: stars, ukir: ukir);
        final mates = [for (final (c, r) in const [(1, 3), (1, 5)]) stand(placeNow(g, 'knight', c, r))];
        expect((g.aliveOf('knight'), mates.length), (3, 2));
        expect(blow(g, u, orc), closeTo(hitTaken(u.stats.dmg * k, orc.stats.def), 1e-9), reason: '3 alive');
        expect(g.pusakaWorth[Relic.loneWolf]!.uses, 1);
        expect(g.pusakaWorth[Relic.loneWolf]!.worth, closeTo(u.stats.dmg * (k - 1), 1e-9));
        stand(placeNow(g, 'knight', 2, 5));
        expect(blow(g, u, orc), closeTo(hitTaken(u.stats.dmg, orc.stats.def), 1e-9), reason: '4 alive');
        expect(g.pusakaWorth[Relic.loneWolf]!.uses, 1);
        g.units.remove(mates.first); // one gone: 3 again
        expect(g.aliveOf('knight'), 3);
        expect(blow(g, u, orc), closeTo(hitTaken(u.stats.dmg * k, orc.stats.def), 1e-9), reason: 'one fell');
      });

      test("$at Martyr's Flame: when one of its type falls every monster within 2 tiles of it takes k of its max HP "
          "(extra damage, through each one's defence); farther, none; its type's max HP ×0.9", () {
        final k = pusakaAt(Relic.martyrFlame, stars, ukir: ukir);
        final base = plain().statsOf('knight');
        final g = plain(Random(2));
        final u = stand(placeNow(g, 'knight', 2, 3));
        placeNow(g, 'archer', 0, 1).cd = hold;
        g.givePusaka(Relic.martyrFlame, type: 'knight', stars: stars, ukir: ukir);
        expect(g.statsOf('knight').hp, (base.hp * martyrFlameK.hp).round());
        expect(u.maxHp, (base.hp * martyrFlameK.hp).round());
        final killer = bigFoe(g, u.pos + const Point(12, 0)), near = bigFoe(g, u.pos + const Point(0, 2 * tile - 1));
        final far = bigFoe(g, u.pos + const Point(-2 * tile - 2, 0));
        final most = u.maxHp.toDouble();
        u.hp = 1;
        strikeBy(g, killer);
        expect(u.alive, isFalse);
        final burn = hitTaken(most * k, killer.stats.def);
        expect([1e6 - killer.hp, 1e6 - near.hp, 1e6 - far.hp], [closeTo(burn, 1e-6), closeTo(burn, 1e-6), 0]);
        expect(g.pusakaWorth[Relic.martyrFlame]!.uses, 1);
        expect(g.pusakaWorth[Relic.martyrFlame]!.worth, closeTo(2 * burn, 1e-6));
      });

      test("$at Wide Blows: its type's normal attacks also hit every monster within 16 px more of the target, on top of "
          "its own splash (its counter: the extra hits past the old splash); its attack ×k", () {
        final k = pusakaAt(Relic.wideBlows, stars, fx: 1, ukir: ukir);
        final base = plain().statsOf('knight'), axe = plain().statsOf('armored_axeman');
        final (g, u, orc) = duel(Relic.wideBlows, stars: stars, ukir: ukir);
        expect(g.statsOf('knight').splash, base.splash + wideBlowsK.splash);
        expect(g.statsOf('knight').dmg, closeTo(base.dmg * k, 1e-9));
        final near = bigFoe(g, orc.pos + const Point(0, 15)), far = bigFoe(g, orc.pos + const Point(0, 17));
        final hit = hitTaken(u.stats.dmg, orc.stats.def);
        expect(blow(g, u, orc), closeTo(hit, 1e-9));
        expect([1e6 - near.hp, 1e6 - far.hp], [closeTo(hit, 1e-9), 0]);
        expect(g.pusakaWorth[Relic.wideBlows]!.uses, 1);
        expect(g.pusakaWorth[Relic.wideBlows]!.worth, closeTo(hit, 1e-9));
        // An axeman's own 16 px splash grows to 32: a monster in the old one counts nothing, one past it counts.
        final (h, a, target) = duel(Relic.wideBlows, type: 'armored_axeman', stars: stars, ukir: ukir);
        expect(h.statsOf('armored_axeman').splash, axe.splash + wideBlowsK.splash);
        final inOld = bigFoe(h, target.pos + const Point(0, 12)), past = bigFoe(h, target.pos + const Point(0, 28));
        final cut = hitTaken(a.stats.dmg, target.stats.def);
        blow(h, a, target);
        expect([1e6 - inOld.hp, 1e6 - past.hp], [closeTo(cut, 1e-9), closeTo(cut, 1e-9)]);
        expect(h.pusakaWorth[Relic.wideBlows]!.uses, 1);
        expect(h.pusakaWorth[Relic.wideBlows]!.worth, closeTo(cut, 1e-9));
      });

      test("$at Champion's Mantle: its type's Heroes' normal attacks do ×k, the others' ×0.9 (counted as nothing)", () {
        final k = pusakaAt(Relic.champion, stars, ukir: ukir);
        expect(pusakaAt(Relic.champion, stars, fx: 1, ukir: ukir), championK.rest, reason: 'Carve leaves the trade');
        final (g, u, orc) = duel(Relic.champion, stars: stars, ukir: ukir);
        expect(blow(g, u, orc), closeTo(hitTaken(u.stats.dmg * championK.rest, orc.stats.def), 1e-9), reason: 'no Hero');
        expect(g.pusakaWorth[Relic.champion], isNull);
        u.hero = true;
        expect(blow(g, u, orc), closeTo(hitTaken(u.stats.dmg * k, orc.stats.def), 1e-9), reason: 'a Hero');
        expect(g.pusakaWorth[Relic.champion]!.uses, 1);
        expect(g.pusakaWorth[Relic.champion]!.worth, closeTo(u.stats.dmg * (k - 1), 1e-9));
      });

      test('$at Vengeance Mark: a monster that takes HP off its type is marked for 4s: every troop blow on it ×k (the '
          "boss ×its boss k, a mini boss ×k), counted; the troop takes ×1.15", () {
        final k = pusakaAt(Relic.vengeance, stars, ukir: ukir);
        expect(pusakaAt(Relic.vengeance, stars, ukir: ukir, boss: true), vengeanceK.boss);
        for (final tier in [Tier.normal, Tier.miniBoss, Tier.boss]) {
          final (g, u, orc) = duel(Relic.vengeance, stars: stars, ukir: ukir, tier: tier);
          final mk = tier == Tier.boss ? vengeanceK.boss : k;
          final hit = hitTaken(orc.stats.dmg, u.stats.def);
          expect(taken(g, u, orc), closeTo(hit * vengeanceK.selfTaken, 1e-9), reason: '${tier.name}: the trade');
          final mark = g.effectOn(orc, Status.pusakaMark)!;
          expect((mark.k, mark.by, mark.bad), (mk, u, false), reason: tier.name);
          expect(mark.until, closeTo(g.t + vengeanceK.time, 0.051), reason: tier.name);
          expect(g.pusakaWorth[Relic.vengeance]!.uses, 1);
          final dealt = blow(g, u, orc);
          expect(dealt, closeTo(hitTaken(u.stats.dmg, orc.stats.def) * mk, 1e-9), reason: tier.name);
          expect(g.pusakaWorth[Relic.vengeance]!.worth, closeTo(dealt * (1 - 1 / mk), 1e-9));
          runFor(g, vengeanceK.time);
          expect(g.effectOn(orc, Status.pusakaMark), isNull, reason: 'run out');
          expect(blow(g, u, orc), closeTo(hitTaken(u.stats.dmg, orc.stats.def), 1e-9));
        }
      });

      test('$at Mirror Shield: from the wave\'s start its type\'s troops reflect k of every blow up close for the whole '
          'wave, from themselves (counted); a shot, none; one bought mid-wave misses it; the wave\'s end ends it; its '
          'attack ×0.8', () {
        final k = pusakaAt(Relic.mirror, stars, ukir: ukir);
        final base = plain().statsOf('knight');
        final (g, u, orc) = duel(Relic.mirror, stars: stars, ukir: ukir, wave: true);
        expect(g.statsOf('knight').dmg, closeTo(base.dmg * mirrorK.dmg, 1e-9));
        final e = g.effectOn(u, Status.reflect)!;
        expect((e.k, e.by, e.until), (k, u, double.infinity));
        taken(g, u, orc);
        final back = 1e6 - orc.hp;
        // The same as a reflect of k from no one.
        final (h, v, twin) = duel(null, wave: true);
        h.addEffect(v, Status.reflect, 1e9, k: k);
        taken(h, v, twin);
        expect(back, closeTo(1e6 - twin.hp, 1e-9));
        expect(back, greaterThan(0));
        expect(g.pusakaWorth[Relic.mirror]!.uses, 1);
        expect(g.pusakaWorth[Relic.mirror]!.worth, closeTo(back, 1e-9));
        expect(h.pusakaWorth, isEmpty);
        // A shot: no reflect.
        final (s, w, shooter) = duel(Relic.mirror, stars: stars, ukir: ukir, wave: true, foe: 'skeleton_archer');
        expect(taken(s, w, shooter), greaterThan(0));
        expect((shooter.hp, s.pusakaWorth[Relic.mirror]), (1e6, null));
        // One bought mid-wave: none; the wave's end: none on any.
        final late = placeNow(g, 'knight', 1, 5);
        expect(g.effectOn(late, Status.reflect), isNull);
        for (final o in g.enemies) {
          o.gone = true;
        }
        g.tick(0.05);
        expect(g.waveActive, isFalse);
        expect(g.effectOn(u, Status.reflect), isNull);
      });

      test('$at Ghost Step: every 3rd blow of a monster on its type misses (its counter: the blows kept off; a bleed\'s '
          'tick is no blow); its attack ×k', () {
        final k = pusakaAt(Relic.ghostStep, stars, fx: 1, ukir: ukir);
        final base = plain().statsOf('knight');
        final (g, u, orc) = duel(Relic.ghostStep, stars: stars, ukir: ukir);
        expect(g.statsOf('knight').dmg, closeTo(base.dmg * k, 1e-9));
        final hit = hitTaken(orc.stats.dmg, u.stats.def);
        expect([for (var n = 1; n <= 6; n++) taken(g, u, orc)], [closeTo(hit, 1e-9), closeTo(hit, 1e-9), 0, closeTo(hit, 1e-9), closeTo(hit, 1e-9), 0]);
        expect(g.pusakaWorth[Relic.ghostStep]!.uses, 2);
        expect(g.pusakaWorth[Relic.ghostStep]!.worth, closeTo(2 * hit, 1e-9));
        // A monster's bleed on it: its ticks land, and count no blow.
        final n = u.fxN, hp = u.hp;
        g.addEffect(u, Status.bleed, 3, k: 5, by: orc, n: 3, bad: true);
        runFor(g, 3.1);
        expect((u.fxN, u.hp < hp), (n, true));
      });

      test('$at Ice Grip: every 4th normal attack holds the monster it hits in place for k s (from the troop; never over '
          'a longer pin), the boss and a mini boss slowed to 70% for 2s instead; its attack ×0.85', () {
        final k = pusakaAt(Relic.iceGrip, stars, ukir: ukir);
        final base = plain().statsOf('knight');
        for (final tier in [Tier.normal, Tier.miniBoss, Tier.boss]) {
          final (g, u, orc) = duel(Relic.iceGrip, stars: stars, ukir: ukir, tier: tier);
          expect(g.statsOf('knight').dmg, closeTo(base.dmg * iceGripK.dmg, 1e-9));
          for (var n = 1; n < iceGripK.every; n++) {
            blow(g, u, orc);
            expect((g.effectOn(orc, Status.impaled), g.effectOn(orc, Status.slow)), (null, null), reason: '${tier.name} blow $n');
          }
          blow(g, u, orc);
          expect(g.pusakaWorth[Relic.iceGrip]!.uses, 1, reason: tier.name);
          if (tier == Tier.normal) {
            final pin = g.effectOn(orc, Status.impaled)!;
            expect((pin.k, pin.by, g.effectOn(orc, Status.slow)), (fxHoldWalk, u, null));
            expect(pin.until, closeTo(g.t + k, 0.051));
          } else {
            final slow = g.effectOn(orc, Status.slow)!;
            expect((slow.k, slow.by, g.effectOn(orc, Status.impaled)), (iceGripK.bossSlow, u, null), reason: tier.name);
            expect(slow.until, closeTo(g.t + iceGripK.bossTime, 0.051), reason: tier.name);
          }
        }
        // A longer pin (a lancer's) stays as it is.
        final (g, u, orc) = duel(Relic.iceGrip, stars: stars, ukir: ukir);
        final lancer = stand(placeNow(g, 'lancer', 1, 5));
        g.addEffect(orc, Status.impaled, 10, k: 0.5, by: lancer);
        final pin = g.effectOn(orc, Status.impaled);
        for (var n = 1; n <= iceGripK.every; n++) {
          blow(g, u, orc);
        }
        expect(identical(g.effectOn(orc, Status.impaled), pin), isTrue);
        expect(g.pusakaWorth[Relic.iceGrip], isNull);
      });

      test('$at Relic Altar: the small relics its troops wear work ×k: the guard\'s cut, the fang\'s heal, the fury\'s '
          "extra, the thorns' hit back (its counter: what the × added); its type's max HP ×0.85; a troop that wears none "
          'as before', () {
        final k = pusakaAt(Relic.relicAltar, stars, ukir: ukir);
        final base = plain().statsOf('knight');
        expect(plain().statsOf('knight').hp, base.hp);
        final hp = (plain()..givePusaka(Relic.relicAltar, type: 'knight')).statsOf('knight').hp;
        expect(hp, (base.hp * relicAltarK.hp).round());
        // The guard.
        final (g, u, orc) = duel(Relic.relicAltar, stars: stars, ukir: ukir);
        final hit = hitTaken(orc.stats.dmg, u.stats.def);
        expect(taken(g, u, orc), closeTo(hit, 1e-9), reason: 'none worn');
        expect(g.pusakaWorth[Relic.relicAltar], isNull);
        u.relics.add(Relic.guard);
        expect(taken(g, u, orc), closeTo(hit * (1 - guardCut * k), 1e-9));
        expect(g.pusakaWorth[Relic.relicAltar]!.uses, 1);
        expect(g.pusakaWorth[Relic.relicAltar]!.worth, closeTo(hit * guardCut * (k - 1), 1e-9));
        // The fang.
        final (f, fu, fo) = duel(Relic.relicAltar, stars: stars, ukir: ukir);
        fu
          ..relics.add(Relic.fang)
          ..hp = 50000;
        final dealt = blow(f, fu, fo);
        expect(fu.hp - 50000, closeTo(dealt * fangShare * k, 1e-9));
        expect(f.pusakaWorth[Relic.relicAltar]!.worth, closeTo(dealt * fangShare * (k - 1), 1e-9));
        // The fury: its every 3rd hit's extra ×k.
        final (y, yu, yo) = duel(Relic.relicAltar, stars: stars, ukir: ukir);
        yu.relics.add(Relic.fury);
        final hits = [for (var n = 1; n <= furyEvery; n++) blow(y, yu, yo)];
        expect(hits.last, closeTo(hitTaken(yu.stats.dmg * (1 + (furyHit - 1) * k), yo.stats.def), 1e-9));
        expect(hits.first, closeTo(hitTaken(yu.stats.dmg, yo.stats.def), 1e-9));
        expect(y.pusakaWorth[Relic.relicAltar]!.worth, closeTo(yu.stats.dmg * (furyHit - 1) * (k - 1), 1e-9));
        // The thorns: the hit back ×k.
        double back(Relic? relic) {
          final (t, tu, to) = duel(relic, stars: stars, ukir: ukir);
          tu.relics.add(Relic.thorns);
          strikeBy(t, to);
          return 1e6 - to.hp;
        }

        expect(back(Relic.relicAltar), greaterThan(back(null)));
      });

      test('$at Vow of Silence: its type\'s max HP and attack ×k (its counter: what the × added); it casts no skill, '
          "a Hero's own neither, and spends no MP", () {
        final k = pusakaAt(Relic.vowSilence, stars, ukir: ukir);
        final base = plain().statsOf('soldier');
        final g = plain()..givePusaka(Relic.vowSilence, type: 'soldier', stars: stars, ukir: ukir);
        expect(g.statsOf('soldier').hp, (base.hp * k).round());
        expect(g.statsOf('soldier').dmg, closeTo(base.dmg * k, 1e-9));
        expect((g.statsOf('soldier').mp, g.statsOf('soldier').range), (base.mp, base.range));
        final (d, u, orc) = duel(Relic.vowSilence, type: 'soldier', stars: stars, ukir: ukir);
        final dealt = blow(d, u, orc);
        expect(dealt, closeTo(hitTaken(base.dmg * k, orc.stats.def), 1e-9));
        expect(d.pusakaWorth[Relic.vowSilence]!.worth, closeTo(dealt * (1 - 1 / k), 1e-9));
        // Hold Fast: cast without it, never with it; its MP stays.
        final (free, _) = castScene(null);
        free.tick(0.05);
        expect(free.log.entries.whereType<SkillCast>(), hasLength(1), reason: 'Hold Fast cast');
        final (silent, s) = castScene(Relic.vowSilence);
        runFor(silent, 1);
        expect(silent.log.entries.whereType<SkillCast>(), isEmpty);
        expect(s.mp, s.stats.mp);
        // A Hero's Shield Bash: none.
        for (final vow in [false, true]) {
          final (x, h) = heroCaster(HeroSkill.shieldBash);
          if (vow) x.givePusaka(Relic.vowSilence, type: h.type, stars: stars, ukir: ukir);
          foeAt(x, 'orc', h.pos + Point(h.stats.range, 0), Tier.highElite);
          h
            ..heroSkillAt = double.negativeInfinity
            ..mp = h.stats.mp.toDouble();
          x.tick(0.05);
          expect(h.heroSkillAt, vow ? double.negativeInfinity : x.t, reason: vow ? 'under the vow' : 'free');
          expect(h.mp, vow ? h.stats.mp : lessThan(h.stats.mp));
        }
      });
    }
  });

  group('the Shadows that answer them', () {
    setUp(() => omensOn = true);

    test("Off Beat never stretches Ghost Step's nor Ice Grip's every-Nth (a Legenda's)", () {
      final (g, u, orc) = duel(Relic.ghostStep);
      topOmen(g, OmenKind.offBeat);
      expect(g.omenOffBeat, greaterThan(0));
      expect([for (var n = 1; n <= 3; n++) taken(g, u, orc) == 0], [false, false, true]);
      final (h, v, foe) = duel(Relic.iceGrip);
      topOmen(h, OmenKind.offBeat);
      for (var n = 1; n <= iceGripK.every; n++) {
        blow(h, v, foe);
      }
      expect(h.effectOn(foe, Status.impaled), isNotNull, reason: 'the 4th');
    });

    test('Blunt cuts the big part of Lone Wolf\'s blow on a silver monster; Spite raises the blow of a monster Vengeance '
        'Mark marked; Executioner bares a low troop of Ghost Step\'s miss (the count goes on); Unbowed shrugs off Ice '
        "Grip's first hold; Rust weakens Relic Altar's relics too; Scatter cuts Wide Blows' extra hits; Thornproof cuts "
        "Mirror Shield's hit back", () {
      // Blunt: a ×2 blow on a silver monster with little max HP is mostly past 20% of it.
      double wolf({required bool blunt}) {
        final (g, u, orc) = duel(Relic.loneWolf, tier: Tier.elite);
        if (blunt) topOmen(g, OmenKind.blunt);
        orc
          ..maxHp = 100
          ..hp = 1e6;
        return blow(g, u, orc);
      }

      expect(wolf(blunt: true), lessThan(wolf(blunt: false)));
      // Spite: the second blow (on a marked monster) × (1 + its share).
      final (g, u, orc) = duel(Relic.vengeance);
      topOmen(g, OmenKind.spite);
      final hit = hitTaken(orc.stats.dmg, u.stats.def);
      expect(taken(g, u, orc), closeTo(hit * vengeanceK.selfTaken, 1e-9), reason: 'not marked yet');
      expect(taken(g, u, orc), closeTo(hit * vengeanceK.selfTaken * (1 + OmenKind.spite.k.max), 1e-9));
      // Executioner: under 20% the 3rd lands; the count went on, so the 6th misses.
      final (x, k, o) = duel(Relic.ghostStep);
      topOmen(x, OmenKind.executioner);
      final blowOn = hitTaken(o.stats.dmg, k.stats.def);
      k.hp = k.maxHp * 0.19;
      expect([for (var n = 1; n <= 3; n++) taken(x, k, o)], everyElement(closeTo(blowOn, 1e-9)), reason: 'bare');
      k.hp = k.maxHp.toDouble();
      expect([for (var n = 4; n <= 6; n++) taken(x, k, o)], [closeTo(blowOn, 1e-9), closeTo(blowOn, 1e-9), 0]);
      // Unbowed L1: the first hold shrugged (not counted), the next lands.
      final (b, bu, bo) = duel(Relic.iceGrip);
      b.omens.add(OmenKind.unbowed);
      bo.shrugs = 1;
      for (var n = 1; n <= iceGripK.every; n++) {
        blow(b, bu, bo);
      }
      expect((b.effectOn(bo, Status.impaled), bo.shrugs, b.pusakaWorth[Relic.iceGrip]), (null, 0, null));
      for (var n = 1; n <= iceGripK.every; n++) {
        blow(b, bu, bo);
      }
      expect((b.effectOn(bo, Status.impaled)?.by, b.pusakaWorth[Relic.iceGrip]!.uses), (bu, 1));
      // Rust: the guard's cut × (1 − its share) × Relic Altar's k.
      final (r, ru, ro) = duel(Relic.relicAltar);
      topOmen(r, OmenKind.rust);
      ru.relics.add(Relic.guard);
      final cut = guardCut * (1 - OmenKind.rust.k.max) * relicAltarK.k;
      expect(taken(r, ru, ro), closeTo(hitTaken(ro.stats.dmg, ru.stats.def) * (1 - cut), 1e-9));
      // Scatter: the splash past the target × (1 − its share).
      double swept({required bool scatter}) {
        final (s, su, so) = duel(Relic.wideBlows);
        if (scatter) topOmen(s, OmenKind.scatter);
        final near = bigFoe(s, so.pos + const Point(0, 10));
        blow(s, su, so);
        return 1e6 - near.hp;
      }

      expect(swept(scatter: true), closeTo(swept(scatter: false) * (1 - OmenKind.scatter.k.max), 1e-9));
      // Thornproof: Mirror Shield's hit back × (1 − its share); at its most (0.6) the taken floor holds it at 0.5.
      double mirrored({required bool thornproof}) {
        final (m, mu, mo) = duel(Relic.mirror, wave: true);
        if (thornproof) topOmen(m, OmenKind.thornproof);
        strikeBy(m, mo);
        return 1e6 - mo.hp;
      }

      expect(mirrored(thornproof: true), closeTo(mirrored(thornproof: false) * omenTakenFloor, 1e-9));
    });

    test("Iron Skin's stronger reflect takes Mirror Shield's slot while it lasts; Mirror Shield's comes back after it, "
        'for the rest of the wave', () {
      omensOn = false;
      final (g, u, _) = duel(Relic.mirror, wave: true);
      g.addEffect(u, Status.reflect, ironSkinK.time, k: ironSkinK.reflect);
      expect((g.effectOn(u, Status.reflect)!.k, g.effectOn(u, Status.reflect)!.by), (ironSkinK.reflect, null));
      runFor(g, ironSkinK.time + 0.1);
      final e = g.effectOn(u, Status.reflect)!;
      expect((e.k, e.by, e.until), (mirrorK.share, u, double.infinity));
      // A weaker one never takes it.
      g.addEffect(u, Status.reflect, 5, k: mirrorK.share / 2);
      expect(g.effectOn(u, Status.reflect)!.by, u);
    });
  });

  group('the chest, the save, the Shadows\' needs, the log', () {
    test('the chest deals each of the ten from wave legendFrom (the Legenda pool is thirteen now), binds it by its '
        'default rule, and never offers one found again', () {
      final legenda = [for (final r in Relic.values) if (r.pusaka && r.rarity == Rarity.legenda && pusakaCatalog[r]!.live) r];
      expect(legenda.take(13).toList(), [Relic.dragonCrown, Relic.oathOfOne, Relic.alliance, ...batch], reason: "batch G-2's eight follow");
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
      expect(pusakaPrefs[Relic.vowSilence]!.contains('priest'), isFalse, reason: "a healer's heal is its skill-less attack");
    });

    test("the save keeps an owned one (its type, ★1 and Carve steps) and finds it; the owner's save holds none", () {
      final g = plain(Random(1));
      placeNow(g, 'knight', 2, 3);
      placeNow(g, 'soldier', 0, 3);
      g
        ..givePusaka(Relic.mirror, type: 'knight', ukir: 3)
        ..givePusaka(Relic.vowSilence, type: 'soldier', stars: 3, ukir: 5)
        ..givePusaka(Relic.iceGrip);
      final back = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
      final p = back.pusaka;
      expect((p[Relic.mirror]!.type, p[Relic.mirror]!.stars, p[Relic.mirror]!.ukir), ('knight', 1, 3));
      expect((p[Relic.vowSilence]!.type, p[Relic.vowSilence]!.stars, p[Relic.vowSilence]!.ukir), ('soldier', 1, 5));
      expect(p[Relic.iceGrip]!.type, isNull);
      expect(back.gudang, contains(Relic.iceGrip));
      expect(back.legendsFound, {Relic.mirror, Relic.vowSilence, Relic.iceGrip});
      expect(back.statsOf('soldier').hp, g.statsOf('soldier').hp, reason: 'the vow works on load');
      expect(jsonEncode(back.toJson()), jsonEncode(g.toJson()));
      final w89 = Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>);
      expect(w89.pusaka.keys.where(batch.contains), isEmpty, reason: "the owner's save holds none");
    });

    test("the Shadows' needs they meet: an extra hit (Martyr's Flame, Wide Blows), a hit back (Mirror Shield), a mark and "
        "Spite's mark (Vengeance Mark), a hold (Ice Grip); none an every-Nth (a Legenda's); Vow of Silence takes its "
        "type's skills off them", () {
      Game army() {
        final g = plain(Random(1));
        placeNow(g, 'knight', 2, 3);
        placeNow(g, 'archer', 0, 3);
        return g;
      }

      Set<OmenNeed> met(Relic r) => (army()..givePusaka(r, type: 'knight')).omenMet;
      final none = army().omenMet;
      expect({for (final r in batch) r: met(r).difference(none)}, {
        Relic.loneWolf: <OmenNeed>{},
        Relic.martyrFlame: {OmenNeed.extraHit},
        Relic.wideBlows: {OmenNeed.extraHit},
        Relic.champion: <OmenNeed>{},
        Relic.vengeance: {OmenNeed.mark, OmenNeed.spiteMark},
        Relic.mirror: {OmenNeed.hitBack},
        Relic.ghostStep: <OmenNeed>{},
        Relic.iceGrip: {OmenNeed.hold},
        Relic.relicAltar: <OmenNeed>{},
        Relic.vowSilence: <OmenNeed>{},
      });
      final solo = bareGame(Random(1));
      placeNow(solo, 'soldier', 2, 3);
      expect(solo.omenMet, contains(OmenNeed.mpSkill));
      solo.givePusaka(Relic.vowSilence, type: 'soldier');
      expect(solo.omenMet.contains(OmenNeed.mpSkill), isFalse, reason: 'it casts none');
      expect(omenCanAct(OmenKind.spite, met(Relic.vengeance)), isTrue);
      expect(omenCanAct(OmenKind.thornproof, met(Relic.mirror)), isTrue);
      expect(omenCanAct(OmenKind.unbowed, met(Relic.iceGrip)), isTrue);
    });

    test("the battle log's report lines and the counter families", () {
      String line(Relic r, String type, int uses, double worth) => pusakaReportLines(PusakaReport(1, 0, lines: [
            (relic: r, type: type, stars: 1, uses: uses, worth: worth),
          ])).single;
      expect(line(Relic.loneWolf, 'wizard', 9, 1200), 'Lone Wolf Pelt (Wizard): +1.2k damage');
      expect(line(Relic.martyrFlame, 'soldier', 2, 900), "Martyr's Flame (Soldier): +900 damage");
      expect(line(Relic.wideBlows, 'swordsman', 14, 640), 'Wide Blows (Swordsman): +640 damage');
      expect(line(Relic.champion, 'knight', 5, 300), "Champion's Mantle (Knight): +300 damage");
      expect(line(Relic.vengeance, 'knight', 6, 450), 'Vengeance Mark (Knight): +450 damage');
      expect(line(Relic.mirror, 'knight', 8, 220), 'Mirror Shield (Knight): +220 damage');
      expect(line(Relic.ghostStep, 'knight', 4, 160), 'Ghost Step (Knight): +160 damage blocked');
      expect(line(Relic.iceGrip, 'archer', 5, 0), 'Ice Grip (Archer): held 5 times');
      expect(line(Relic.iceGrip, 'archer', 1, 0), 'Ice Grip (Archer): held once');
      expect(line(Relic.relicAltar, 'swordsman', 7, 310), 'Relic Altar (Swordsman): +310 from relics');
      expect(line(Relic.vowSilence, 'soldier', 3, 520), 'Vow of Silence (Soldier): +520 damage & heal');
      expect({for (final r in batch) r: fxFamily(r)}, {
        Relic.loneWolf: FxFamily.added,
        Relic.martyrFlame: FxFamily.added,
        Relic.wideBlows: FxFamily.added,
        Relic.champion: FxFamily.added,
        Relic.vengeance: FxFamily.added,
        Relic.mirror: FxFamily.added,
        Relic.ghostStep: FxFamily.keptOff,
        Relic.iceGrip: FxFamily.applied,
        Relic.relicAltar: FxFamily.added,
        Relic.vowSilence: FxFamily.added,
      });
      expect([for (final r in batch) if (fxRaisesHp(r)) r], [Relic.vowSilence]);
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
      testWidgets('each of the ten fits ${size.width.round()}x${size.height.round()}: the gold Legenda cards and the '
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
        // The ten three a chest, the longest together (Ice Grip, Vengeance Mark, Martyr's Flame); the last with old ones.
        final hands = [
          [Relic.iceGrip, Relic.vengeance, Relic.martyrFlame],
          [Relic.loneWolf, Relic.wideBlows, Relic.champion],
          [Relic.mirror, Relic.ghostStep, Relic.relicAltar],
          [Relic.vowSilence, Relic.dragonCrown, Relic.alliance],
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
