// Batch G-2 (decisions-log 238; catalog-design §3.3 and §5.2, catalog-bayangan-v2 §4): eight more new Legenda Artifacts
// as catalog rows on the engine's Fx, each a rule with a real cost: a power while low (Rage Totem), a link that takes the
// hits of the troops near (Guardian Chain), a cut in a crowd of its own (Phalanx), a fallen troop back (Phoenix Plume), a
// fall that shelters the troops near (Soul Shelter), a skill that fills their MP (Mana Font), every few hits a hex (Hex
// Blade) and a strong kill that powers the type (Glory Seeker). A Legenda has ★1 only: its ★2 and ★3 read ★1, and Carve
// moves one named number ([ukirPerStar]). Each one's effect at ★1-★3 and carved, its words, its row (rarity, Carve role,
// the atlas's icon, epithet, counter, chest-only), the Shadows that answer it (batch G-1B's Unbowed, G-2B's kinds), the
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

/// The batch's eight, in [Relic] order (after batch G-1P's ten).
const batch = [
  Relic.rageTotem, Relic.guardianChain, Relic.phalanx, Relic.phoenix, Relic.soulShelter, Relic.manaFont, Relic.hexBlade, //
  Relic.glorySeeker,
];

/// The stars and Carve steps each effect is checked at: ★1-★3 bare (a Legenda's ★2 and ★3 are its ★1), then two carved.
const _levels = [(1, 0), (2, 0), (3, 0), (1, 2), (1, 5)];

/// Each one's number Carve moves (its Fx number, [ukirPerStar]) and that Fx's table at ★1, with its step a star.
final _carved = <Relic, (int, double, double)>{
  Relic.rageTotem: (0, rageTotemK.power, rageTotemK.perStar),
  Relic.guardianChain: (0, guardianChainK.share, guardianChainK.perStar),
  Relic.phalanx: (0, phalanxK.cut, phalanxK.perStar),
  Relic.phoenix: (0, phoenixK.hpLeft, phoenixK.perStar),
  Relic.soulShelter: (0, soulShelterK.time, soulShelterK.perStar),
  Relic.manaFont: (0, manaFontK.share, manaFontK.perStar),
  Relic.hexBlade: (0, hexBladeK.time, hexBladeK.perStar),
  Relic.glorySeeker: (0, glorySeekerK.might, glorySeekerK.perStar),
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
/// bound), that attacks only when told ([blow]), with HP to spare; and a monster of [foe] and [tier] 12 px from it with HP
/// to spare that strikes only when told ([strikeBy]); an archer far behind keeps the game on. [wave]: a wave begun first,
/// with nothing left to spawn.
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
  final o = foeAt(g, foe, u.pos + const Point(12, 0), tier)
    ..maxHp = 1000000
    ..hp = 1e6;
  return (g, u, o);
}

/// A monster of [type] at [at] with HP to spare, standing.
Unit bigFoe(Game g, Point<double> at, [String type = 'orc']) => foeAt(g, type, at)
  ..maxHp = 1000000
  ..hp = 1e6;

/// A soldier at cell (2, 3) holding [relic] on its type (none: nothing), in a wave, its MP full and its attack held, with
/// two orcs beside it (Hold Fast's crowd): its next tick casts Hold Fast. An archer 2.2 tiles off ([near]) and a wizard 4
/// tiles off ([far]), both standing with no MP.
(Game, Unit, Unit, Unit) fontScene(Relic? relic, {int stars = 1, int ukir = 0}) {
  final g = bareGame(Random(1))
    ..heroSkills = false
    ..monsterSkills = false;
  final u = placeNow(g, 'soldier', 2, 3);
  final near = stand(placeNow(g, 'archer', 1, 1)), far = stand(placeNow(g, 'wizard', 2, 7));
  if (relic != null) g.givePusaka(relic, type: 'soldier', stars: stars, ukir: ukir);
  g
    ..startWave()
    ..queue.clear();
  u
    ..cd = hold
    ..mp = u.stats.mp.toDouble();
  near.mp = 0;
  far.mp = 0;
  for (final d in const <Point<double>>[Point(10, 0), Point(10, -8)]) {
    foeAt(g, 'orc', u.pos + d).hp = 1e4;
  }
  return (g, u, near, far);
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
  tearDown(() => omensOn = omensDefault);

  group('the rows', () {
    test("eight Legenda appended after batch G-1P's ten (save keys), chest-only (sold back at the Legenda price), ★1 "
        "only, in the game; names, Carve roles, epithets, the atlas's icons and catalog-bayangan-v2's counters (batch "
        "G-1B's Unbowed, G-2B's kinds), which now name them", () {
      expect(Relic.values.skipWhile((r) => r != Relic.vowSilence).skip(1).take(batch.length).toList(), batch,
          reason: "after batch G-1P's ten (batch G-3's follow)");
      expect({for (final r in batch) r: relicNames[r]}, {
        Relic.rageTotem: 'Rage Totem',
        Relic.guardianChain: 'Guardian Chain',
        Relic.phalanx: 'Phalanx',
        Relic.phoenix: 'Phoenix Plume',
        Relic.soulShelter: 'Soul Shelter',
        Relic.manaFont: 'Mana Font',
        Relic.hexBlade: 'Hex Blade',
        Relic.glorySeeker: 'Glory Seeker',
      });
      for (final r in batch) {
        final art = pusakaCatalog[r]!;
        expect((r.rarity, r.scope, r.store, art.live, r.oath, maxStars(r)), (Rarity.legenda, RelicScope.type, false, true, false, 1),
            reason: '$r');
        expect(art.icon.sheet, 'artifact_icons.png', reason: '$r');
        expect((art.icon.x, art.icon.y, art.icon.tint), (artifactIcon(r.name).x, artifactIcon(r.name).y, null), reason: '$r');
        expect(art.healerCounter, isNull, reason: '$r');
        expect(art.fx, hasLength(r == Relic.guardianChain ? 1 : 2), reason: '$r: a trade beside it (the chain: the hits it takes)');
      }
      expect({for (final r in batch) r: pusakaCatalog[r]!.role}, {
        Relic.rageTotem: UkirRole.attack,
        Relic.guardianChain: UkirRole.guard,
        Relic.phalanx: UkirRole.guard,
        Relic.phoenix: UkirRole.life,
        Relic.soulShelter: UkirRole.life,
        Relic.manaFont: UkirRole.life,
        Relic.hexBlade: UkirRole.attack,
        Relic.glorySeeker: UkirRole.attack,
      });
      (String, int, int, int?) cell(Art a) => (a.icon.sheet, a.icon.x, a.icon.y, a.icon.tint);
      final cells = [for (final a in pusakaCatalog.values) cell(a)];
      for (final r in batch) {
        expect(cells.where((c) => c == cell(pusakaCatalog[r]!)), hasLength(1), reason: '$r: its own icon');
      }
      expect(liveG2, isTrue);
      expect({for (final r in batch) r: buildEpithets[r]}, {
        Relic.rageTotem: 'Raging',
        Relic.guardianChain: 'Guardian',
        Relic.phalanx: 'Serried',
        Relic.phoenix: 'Phoenix',
        Relic.soulShelter: 'Sheltering',
        Relic.manaFont: 'Wellspring',
        Relic.hexBlade: 'Hexing',
        Relic.glorySeeker: 'Glorious',
      });
      expect(buildEpithets.values.toSet().length, buildEpithets.length, reason: 'an epithet twice');
      expect({for (final r in batch) r: pusakaCatalog[r]!.counter}, {
        Relic.rageTotem: OmenKind.vultures,
        Relic.guardianChain: OmenKind.sideSwing,
        Relic.phalanx: OmenKind.sideSwing,
        Relic.phoenix: OmenKind.spree,
        Relic.soulShelter: OmenKind.sideSwing,
        Relic.manaFont: OmenKind.backlash,
        Relic.hexBlade: OmenKind.unbowed,
        Relic.glorySeeker: OmenKind.deathless,
      });
      // G-2B's answers filled: each kind names the Artifacts it blunts (Unbowed: Ice Grip's hold too).
      expect({for (final k in const [OmenKind.vultures, OmenKind.sideSwing, OmenKind.spree, OmenKind.backlash, OmenKind.unbowed, OmenKind.deathless]) k: k.answers}, {
        OmenKind.vultures: [Relic.rageTotem],
        OmenKind.sideSwing: [Relic.guardianChain, Relic.phalanx, Relic.soulShelter],
        OmenKind.spree: [Relic.phoenix],
        OmenKind.backlash: [Relic.manaFont],
        OmenKind.unbowed: [Relic.iceGrip, Relic.hexBlade],
        OmenKind.deathless: [Relic.glorySeeker],
      });
      for (final r in batch) {
        expect(omenPool(Rarity.legenda), contains(pusakaCatalog[r]!.counter), reason: '$r');
      }
      for (final k in const [OmenKind.cover, OmenKind.renewal, OmenKind.adapt, OmenKind.warlord, OmenKind.manaBurn]) {
        expect(k.answers, isEmpty, reason: '$k: faces only');
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

    test('each leads with its own Fx (no other row shares its key); each pays for its rule (a condition, a trade under 1, '
        'or the hits it takes); ★2 and ★3 read ★1; Carve moves its one named number by its step a star of worth, and '
        'nothing else; the every-Nth ones are Legenda (no Off Beat, no Fury beat)', () {
      final keys = {for (final MapEntry(key: r, value: a) in pusakaCatalog.entries) if (a.fx.isNotEmpty) a.fx.first.key: r};
      for (final r in batch) {
        expect(keys[pusakaCatalog[r]!.fx.first.key], r, reason: '$r');
        for (final fx in pusakaCatalog[r]!.fx) {
          expect(fxBuilt(fx), isTrue, reason: '$r: the engine runs it');
          expect(fx.when == null || fxIfsBuilt.contains(fx.when), isTrue, reason: '$r');
          expect((fx.k.length <= 1, fx.count.isEmpty, fx.furyBeat), (true, true, false), reason: '$r: one number');
        }
      }
      Fx fx(Relic r, [int i = 0]) => pusakaCatalog[r]!.fx[i];
      expect((fx(Relic.rageTotem).when, fx(Relic.rageTotem).ifK), (If.hpBelow, rageTotemK.below));
      expect((fx(Relic.phalanx).when, fx(Relic.phalanx).ifK, fx(Relic.phalanx).ifR), (If.alliesNear, phalanxK.near.toDouble(), phalanxK.reach));
      expect(fx(Relic.phoenix).when, If.firstOfTypeThisWave);
      expect(fx(Relic.glorySeeker).when, If.foeHighElite);
      expect([for (final r in batch) if (r != Relic.guardianChain) fx(r, 1).k], [
        [rageTotemK.healIn],
        [phalanxK.dmg],
        [phoenixK.hp],
        [soulShelterK.dmg],
        [manaFontK.mpRegen],
        [hexBladeK.dmg],
        [glorySeekerK.dmg],
      ], reason: 'the trades');
      expect([for (final r in batch) if (r != Relic.guardianChain) (fx(r, 1).on, fx(r, 1).eff, fx(r, 1).stat)], [
        (Trig.heals, Eff.heal, null), // the heals it gets
        (Trig.always, Eff.stat, Stat.dmg),
        (Trig.always, Eff.stat, Stat.hp),
        (Trig.always, Eff.stat, Stat.dmg),
        (Trig.always, Eff.stat, Stat.mpRegen),
        (Trig.always, Eff.stat, Stat.dmg),
        (Trig.always, Eff.stat, Stat.dmg),
      ]);
      expect((fx(Relic.guardianChain).status, fx(Relic.guardianChain).k.single, fx(Relic.guardianChain).r), (Status.link, guardianChainK.share, guardianChainK.reach),
          reason: 'its cost: a share of the hits near it');
      expect({for (final r in batch) r: fx(r).every}, {
        Relic.rageTotem: 0,
        Relic.guardianChain: guardianChainK.every,
        Relic.phalanx: 0,
        Relic.phoenix: 0,
        Relic.soulShelter: 0,
        Relic.manaFont: 0,
        Relic.hexBlade: hexBladeK.every,
        Relic.glorySeeker: 0,
      });
      expect({for (final r in batch) if (fx(r).cd > 0) r: fx(r).cd}, {Relic.soulShelter: soulShelterK.cd, Relic.hexBlade: hexBladeK.cd});
      expect((fx(Relic.guardianChain).time, fx(Relic.phoenix).time, fx(Relic.glorySeeker).time), (guardianChainK.time, phoenixK.delay, glorySeekerK.time));
      expect((fx(Relic.soulShelter).status, fx(Relic.soulShelter).r, fx(Relic.manaFont).r), (Status.cap, soulShelterK.reach, manaFontK.reach));
      expect((fx(Relic.hexBlade).status, fx(Relic.glorySeeker).status), (Status.hex, Status.might));
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
          }
        }
        expect(pusakaAt(r, 1, fx: carved), table, reason: '$r');
      }
    });

    test("their words at ★1, from the constants: the card and tooltip lines, the Bag row's gist and the Bag detail's first "
        "sentence (a cost reads on: 'but …'); Carve moves the numbers; plain English", () {
      final g = Game();
      expect({for (final r in batch) r: g.relicEffect(r, stars: 1)}, {
        Relic.rageTotem: ['Under 50% HP: +60% damage', 'but heals on it -30%'],
        Relic.guardianChain: ['Every 4th hit, for 4s: it takes', '25% of the damage on troops of', 'other types within 2 tiles'],
        Relic.phalanx: ['3 or more troops within', '1.5 tiles: -30% damage taken', 'but -15% attack or heal'],
        Relic.phoenix: ["Once a wave, the type's first", 'to die (not a Hero) comes back', 'after 3s at 30% HP', 'but -15% max HP'],
        Relic.soulShelter: ['When one dies: troops within', '2 tiles take no damage for 1.5s,', 'at most once every 6s', 'but -15% attack or heal'],
        Relic.manaFont: ['After it uses a skill: other', 'troops within 3 tiles get', '25% of their max MP', 'but its MP comes back 30% slower'],
        Relic.hexBlade: ['Every 8th hit turns the monster', 'into a slime for 2s (no bosses),', 'at most once every 6s', 'but -15% attack or heal'],
        Relic.glorySeeker: ['When it kills a gold monster', 'or a boss: this type +25%', 'damage for 5s', 'but -10% attack or heal'],
      });
      expect({for (final r in batch) r: pusakaGist(r, 1)}, {
        Relic.rageTotem: 'Under 50%: +60% damage',
        Relic.guardianChain: 'Every 4th: takes 25% for near',
        Relic.phalanx: '3+ near: -30% taken',
        Relic.phoenix: 'First to die: back at 30%',
        Relic.soulShelter: 'Death: near safe 1.5s',
        Relic.manaFont: 'Skill: near +25% MP',
        Relic.hexBlade: 'Every 8th: slime 2s',
        Relic.glorySeeker: 'Gold kill: type +25%',
      });
      expect({for (final r in batch) r: firstSentence(g.relicEffect(r, stars: 1))}, {
        Relic.rageTotem: 'Under 50% HP: +60% damage but heals on it -30%',
        Relic.guardianChain: 'Every 4th hit, for 4s: it takes 25% of the damage on troops of other types within 2 tiles',
        Relic.phalanx: '3 or more troops within 1.5 tiles: -30% damage taken but -15% attack or heal',
        Relic.phoenix: "Once a wave, the type's first to die (not a Hero) comes back after 3s at 30% HP but -15% max HP",
        Relic.soulShelter: 'When one dies: troops within 2 tiles take no damage for 1.5s, at most once every 6s but -15% attack or heal',
        Relic.manaFont: 'After it uses a skill: other troops within 3 tiles get 25% of their max MP but its MP comes back 30% slower',
        Relic.hexBlade: 'Every 8th hit turns the monster into a slime for 2s (no bosses), at most once every 6s but -15% attack or heal',
        Relic.glorySeeker: 'When it kills a gold monster or a boss: this type +25% damage for 5s but -10% attack or heal',
      });
      for (final r in batch) {
        expect(g.relicEffect(r, stars: 3), g.relicEffect(r, stars: 1), reason: '$r: ★3 is ★1');
      }
      expect({for (final r in batch) r: fxLines(r, 1, ukir: 5).first}, {
        Relic.rageTotem: 'Under 50% HP: +68% damage',
        Relic.guardianChain: 'Every 4th hit, for 4s: it takes',
        Relic.phalanx: '3 or more troops within',
        Relic.phoenix: "Once a wave, the type's first",
        Relic.soulShelter: 'When one dies: troops within',
        Relic.manaFont: 'After it uses a skill: other',
        Relic.hexBlade: 'Every 8th hit turns the monster',
        Relic.glorySeeker: 'When it kills a gold monster',
      });
      expect({for (final r in batch) r: fxLines(r, 1, ukir: 5)[1]}, {
        Relic.rageTotem: 'but heals on it -30%',
        Relic.guardianChain: '29% of the damage on troops of',
        Relic.phalanx: '1.5 tiles: -32% damage taken',
        Relic.phoenix: 'to die (not a Hero) comes back',
        Relic.soulShelter: '2 tiles take no damage for 1.7s,',
        Relic.manaFont: 'troops within 3 tiles get',
        Relic.hexBlade: 'into a slime for 2.2s (no bosses),',
        Relic.glorySeeker: 'or a boss: this type +29%',
      });
      expect((fxLines(Relic.phoenix, 1, ukir: 5)[2], fxLines(Relic.manaFont, 1, ukir: 5)[2]), ('after 3s at 34% HP', '29% of their max MP'));
      // Moonwell's MP regen line is as it was (a × over 1).
      expect(fxLines(Relic.moonwell, 1).first, 'MP comes back ${(moonwellK.mpRegen[0] * 100 - 100).round()}% faster');
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

      test('$at Rage Totem: under half its max HP its normal attacks do ×k (counted); at half or over as before; the heals '
          'it gets land ×0.7 (counted as nothing)', () {
        final k = pusakaAt(Relic.rageTotem, stars, ukir: ukir);
        final (g, u, orc) = duel(Relic.rageTotem, stars: stars, ukir: ukir);
        final hit = hitTaken(u.stats.dmg, orc.stats.def);
        expect(blow(g, u, orc), closeTo(hit, 1e-9), reason: 'full HP');
        u.hp = u.maxHp * rageTotemK.below;
        expect(blow(g, u, orc), closeTo(hit, 1e-9), reason: 'at half');
        expect(g.pusakaWorth[Relic.rageTotem], isNull);
        u.hp = u.maxHp * rageTotemK.below - 1;
        expect(blow(g, u, orc), closeTo(hitTaken(u.stats.dmg * k, orc.stats.def), 1e-9), reason: 'under half');
        expect(g.pusakaWorth[Relic.rageTotem]!.uses, 1);
        expect(g.pusakaWorth[Relic.rageTotem]!.worth, closeTo(u.stats.dmg * (k - 1), 1e-9));
        double healed(Relic? relic) {
          final (h, v, _) = duel(relic, stars: stars, ukir: ukir);
          v.hp = 1000;
          h.addEffect(v, Status.heal, 1, k: 100);
          runFor(h, 1.2);
          expect(h.pusakaWorth[Relic.rageTotem], isNull, reason: 'a trade counts nothing');
          return v.hp - 1000;
        }

        expect(healed(null), greaterThanOrEqualTo(100 - 1e-9));
        expect(healed(Relic.rageTotem), closeTo(healed(null) * rageTotemK.healIn, 1e-6));
      });

      test('$at Guardian Chain: every 4th normal attack links each troop of another type within 2 tiles to it for 4s (k of '
          "every blow on that troop goes to it, through its own defence; counted); its own type, one farther, none; two "
          'links on each other never loop', () {
        final k = pusakaAt(Relic.guardianChain, stars, ukir: ukir);
        final (g, u, orc) = duel(Relic.guardianChain, stars: stars, ukir: ukir);
        final near = stand(placeNow(g, 'archer', 1, 3)), mate = stand(placeNow(g, 'knight', 2, 4));
        final far = stand(placeNow(g, 'wizard', 2, 6));
        for (var n = 1; n < guardianChainK.every; n++) {
          blow(g, u, orc);
          expect(g.effectOn(near, Status.link), isNull, reason: 'blow $n');
        }
        blow(g, u, orc);
        final link = g.effectOn(near, Status.link)!;
        expect((link.k, link.by, link.bad), (k, u, false));
        expect(link.until, closeTo(g.t + guardianChainK.time, 0.051));
        expect((g.effectOn(mate, Status.link), g.effectOn(far, Status.link)), (null, null), reason: 'its own type; past 2 tiles');
        expect(g.pusakaWorth[Relic.guardianChain]!.uses, 1);
        // A blow on the archer: k of it goes to the knight, through the knight's defence.
        final hound = bigFoe(g, near.pos + const Point(-12, 0));
        near
          ..maxHp = 100000
          ..hp = 100000;
        final raw = hound.stats.dmg, uHp = u.hp, nHp = near.hp;
        strikeBy(g, hound);
        expect(nHp - near.hp, closeTo(hitTaken(raw * (1 - k), near.stats.def), 1e-9));
        expect(uHp - u.hp, closeTo(hitTaken(raw * k, u.stats.def), 1e-9));
        expect(g.pusakaWorth[Relic.guardianChain]!.worth, closeTo(uHp - u.hp, 1e-9));
        // The knight linked to the archer too (a Shared Wounds the other way): its share isn't passed back.
        g.addEffect(u, Status.link, 10, k: 0.5, by: near);
        final u2 = u.hp, n2 = near.hp;
        strikeBy(g, hound);
        expect(n2 - near.hp, closeTo(hitTaken(raw * (1 - k), near.stats.def), 1e-9));
        expect(u2 - u.hp, closeTo(hitTaken(raw * k, u.stats.def), 1e-9));
        runFor(g, guardianChainK.time);
        expect(g.effectOn(near, Status.link), isNull, reason: 'run out');
      });

      test('$at Phalanx: with 3 or more other troops within 1.5 tiles its type takes k less of every blow (counted); with '
          '2, as before; its attack ×0.85', () {
        final k = pusakaAt(Relic.phalanx, stars, ukir: ukir);
        final base = plain().statsOf('knight');
        final (g, u, orc) = duel(Relic.phalanx, stars: stars, ukir: ukir);
        expect(g.statsOf('knight').dmg, closeTo(base.dmg * phalanxK.dmg, 1e-9));
        stand(placeNow(g, 'archer', 1, 3));
        stand(placeNow(g, 'wizard', 2, 4));
        stand(placeNow(g, 'soldier', 3, 1)); // 2.2 tiles off: not near
        final hit = hitTaken(orc.stats.dmg, u.stats.def);
        expect(taken(g, u, orc), closeTo(hit, 1e-9), reason: '2 near');
        expect(g.pusakaWorth[Relic.phalanx], isNull);
        stand(placeNow(g, 'soldier', 1, 4)); // 1.4 tiles off
        expect(taken(g, u, orc), closeTo(hit * (1 - k), 1e-9), reason: '3 near');
        expect(g.pusakaWorth[Relic.phalanx]!.worth, closeTo(hit * k, 1e-9));
      });

      test("$at Phoenix Plume: once a wave the first of its type to fall (not a Hero) rises 3s later where it fell, at k of "
          'its max HP with no MP (its name and spot, never brought back again; counted); the next to fall that wave stays '
          'down; a Hero falling first keeps the once; its max HP ×0.85', () {
        final k = pusakaAt(Relic.phoenix, stars, ukir: ukir);
        final base = plain().statsOf('knight');
        final (g, u, orc) = duel(Relic.phoenix, stars: stars, ukir: ukir, wave: true);
        expect(g.statsOf('knight').hp, (base.hp * phoenixK.hp).round());
        u.hp = 1;
        strikeBy(g, orc);
        expect((u.alive, g.fallen.contains(u)), (false, true));
        runFor(g, phoenixK.delay - 0.2);
        expect(g.troops.where((o) => o.alive && o.type == 'knight'), isEmpty, reason: 'not yet');
        runFor(g, 0.3);
        final r = g.troops.singleWhere((o) => o.alive && o.type == 'knight');
        expect((r.name, r.pos, r.post, r.revived, r.hero), (u.name, u.pos, u.post, true, false));
        expect(r.maxHp, (base.hp * phoenixK.hp).round());
        expect(r.hp, closeTo(r.maxHp * k, 1e-9));
        expect(r.mp, lessThan(1));
        expect((g.fallen.contains(u), g.waveActive), (false, true));
        expect(g.risen, [r], reason: 'the UI names it');
        expect((g.pusakaWorth[Relic.phoenix]!.uses, g.pusakaWorth[Relic.phoenix]!.worth), (1, 1.0));
        // The next of its type to fall this wave stays down; the risen one too, were it to fall.
        final next = stand(placeNow(g, 'knight', 2, 6));
        final hound = bigFoe(g, next.pos + const Point(12, 0));
        next.hp = 1;
        strikeBy(g, hound);
        runFor(g, phoenixK.delay + 0.2);
        expect((next.alive, g.fallen.contains(next), g.pusakaWorth[Relic.phoenix]!.uses), (false, true, 1));
        // A Hero falls first: it stays down, and the once waits for the next.
        final (h, v, foe) = duel(Relic.phoenix, stars: stars, ukir: ukir, wave: true);
        v
          ..hero = true
          ..hp = 1;
        strikeBy(h, foe);
        runFor(h, phoenixK.delay + 0.2);
        expect(h.troops.where((o) => o.alive && o.type == 'knight'), isEmpty, reason: 'a Hero stays down');
        final plainOne = stand(placeNow(h, 'knight', 2, 6));
        final orc2 = bigFoe(h, plainOne.pos + const Point(12, 0));
        plainOne.hp = 1;
        strikeBy(h, orc2);
        runFor(h, phoenixK.delay + 0.2);
        expect([for (final o in h.troops) if (o.alive && o.type == 'knight') o.name], [plainOne.name]);
      });

      test('$at Soul Shelter: when one of its type falls each troop within 2 tiles takes no damage for k s (a cap at 0 from '
          'it; counted: the troops and the damage kept off); farther, none; at most once every 6s for the whole type; its '
          'attack ×0.85', () {
        final k = pusakaAt(Relic.soulShelter, stars, ukir: ukir);
        final base = plain().statsOf('knight');
        final (g, u, orc) = duel(Relic.soulShelter, stars: stars, ukir: ukir);
        expect(g.statsOf('knight').dmg, closeTo(base.dmg * soulShelterK.dmg, 1e-9));
        final near = stand(placeNow(g, 'archer', 1, 3)), mate = stand(placeNow(g, 'knight', 2, 5));
        final far = stand(placeNow(g, 'wizard', 2, 6)), last = stand(placeNow(g, 'knight', 2, 7));
        u.hp = 1;
        strikeBy(g, orc);
        expect(u.alive, isFalse);
        for (final o in [near, mate]) {
          final cap = g.effectOn(o, Status.cap)!;
          expect((cap.k, cap.by), (0.0, u), reason: o.type);
          expect(cap.until, closeTo(g.t + k, 0.051), reason: o.type);
        }
        expect(g.effectOn(far, Status.cap), isNull, reason: 'past 2 tiles');
        expect(g.pusakaWorth[Relic.soulShelter]!.uses, 2);
        // A blow on the archer in the window: nothing; counted as kept off.
        final hound = bigFoe(g, near.pos + const Point(-12, 0));
        near
          ..maxHp = 100000
          ..hp = 100000;
        expect(taken(g, near, hound), 0);
        expect(g.pusakaWorth[Relic.soulShelter]!.worth, closeTo(hitTaken(hound.stats.dmg, near.stats.def), 1e-9));
        // The mate falls once the window is over, within 6s of the first: no shelter (the type's cooldown).
        runFor(g, k + 0.1);
        expect(g.effectOn(near, Status.cap), isNull, reason: 'run out');
        final orc2 = bigFoe(g, mate.pos + const Point(12, 0));
        mate.hp = 1;
        strikeBy(g, orc2);
        expect((mate.alive, g.effectOn(far, Status.cap), g.pusakaWorth[Relic.soulShelter]!.uses), (false, null, 2));
        // 6s after the first: the last one's fall shelters the wizard next to it.
        runFor(g, soulShelterK.cd);
        final orc3 = bigFoe(g, last.pos + const Point(12, 0));
        last.hp = 1;
        strikeBy(g, orc3);
        expect(g.effectOn(far, Status.cap)?.by, last);
        expect(g.pusakaWorth[Relic.soulShelter]!.uses, 3);
      });

      test('$at Mana Font: a skill its type casts gives each other troop within 3 tiles k of its max MP (not itself, not one '
          'farther; counted as MP); its MP regen ×0.7', () {
        final k = pusakaAt(Relic.manaFont, stars, ukir: ukir);
        final base = plain().statsOf('soldier');
        expect((plain()..givePusaka(Relic.manaFont, type: 'soldier')).statsOf('soldier').mpRegen, closeTo(base.mpRegen * manaFontK.mpRegen, 1e-9));
        final (free, fu, fNear, fFar) = fontScene(null);
        free.tick(0.05);
        final (g, u, near, far) = fontScene(Relic.manaFont, stars: stars, ukir: ukir);
        g.tick(0.05);
        expect(g.log.entries.whereType<SkillCast>(), hasLength(1), reason: 'Hold Fast cast');
        expect(near.mp - fNear.mp, closeTo(near.stats.mp * k, 1e-9));
        expect(far.mp, closeTo(fFar.mp, 1e-9), reason: 'past 3 tiles');
        expect(u.mp, lessThanOrEqualTo(fu.mp), reason: 'none to itself');
        expect(g.pusakaWorth[Relic.manaFont]!.uses, 1);
        expect(g.pusakaWorth[Relic.manaFont]!.worth, closeTo(near.stats.mp * k, 1e-9));
      });

      test('$at Hex Blade: every 8th normal attack turns the monster it hits into a slime for k s (from the troop; counted), '
          'at most once every 6s a troop; never the boss nor a mini boss; its attack ×0.85', () {
        final k = pusakaAt(Relic.hexBlade, stars, ukir: ukir);
        final base = plain().statsOf('knight');
        for (final tier in [Tier.miniBoss, Tier.boss]) {
          final (g, u, orc) = duel(Relic.hexBlade, stars: stars, ukir: ukir, tier: tier);
          for (var n = 1; n <= hexBladeK.every; n++) {
            blow(g, u, orc);
          }
          expect((g.effectOn(orc, Status.hex), g.pusakaWorth[Relic.hexBlade], u.fxReady), (null, null, double.negativeInfinity),
              reason: '${tier.name}: none, and its cooldown not spent');
        }
        final (g, u, orc) = duel(Relic.hexBlade, stars: stars, ukir: ukir);
        expect(g.statsOf('knight').dmg, closeTo(base.dmg * hexBladeK.dmg, 1e-9));
        final own = orc.stats;
        for (var n = 1; n < hexBladeK.every; n++) {
          blow(g, u, orc);
          expect(g.effectOn(orc, Status.hex), isNull, reason: 'blow $n');
        }
        blow(g, u, orc);
        final hex = g.effectOn(orc, Status.hex)!;
        expect((hex.by, identical(hex.was, own), identical(orc.stats, own)), (u, true, false), reason: 'a slime now');
        expect(hex.until, closeTo(g.t + k, 0.051));
        expect(g.pusakaWorth[Relic.hexBlade]!.uses, 1);
        runFor(g, k + 0.1);
        expect((g.effectOn(orc, Status.hex), identical(orc.stats, own)), (null, true), reason: 'back');
        orc
          ..maxHp = 1000000
          ..hp = 1e6;
        for (var n = 1; n <= hexBladeK.every; n++) {
          blow(g, u, orc);
        }
        expect(g.effectOn(orc, Status.hex), isNull, reason: 'within 6s');
        runFor(g, hexBladeK.cd);
        for (var n = 1; n <= hexBladeK.every; n++) {
          blow(g, u, orc);
        }
        expect(g.effectOn(orc, Status.hex)?.by, u, reason: 'after 6s');
        expect(g.pusakaWorth[Relic.hexBlade]!.uses, 2);
      });

      test('$at Glory Seeker: its type killing a high elite, a mini boss or the boss gives every troop of its type ×k damage '
          'for 5s (a might from the killer; counted); a normal or elite kill, none; its attack ×0.9', () {
        final k = pusakaAt(Relic.glorySeeker, stars, ukir: ukir);
        final base = plain().statsOf('knight');
        for (final tier in Tier.values) {
          final (g, u, orc) = duel(Relic.glorySeeker, stars: stars, ukir: ukir, tier: tier);
          expect(g.statsOf('knight').dmg, closeTo(base.dmg * glorySeekerK.dmg, 1e-9));
          final mate = stand(placeNow(g, 'knight', 1, 5)), other = stand(placeNow(g, 'archer', 2, 5));
          orc.hp = 1;
          blow(g, u, orc);
          expect(orc.alive, isFalse, reason: tier.name);
          final strong = tier.index >= Tier.highElite.index;
          for (final o in [u, mate]) {
            final might = g.effectOn(o, Status.might);
            if (!strong) {
              expect(might, isNull, reason: tier.name);
              continue;
            }
            expect((might!.k, might.by), (k, u), reason: tier.name);
            expect(might.until, closeTo(g.t + glorySeekerK.time, 0.051), reason: tier.name);
          }
          expect(g.effectOn(other, Status.might), isNull, reason: 'another type');
          expect(g.pusakaWorth[Relic.glorySeeker]?.uses, strong ? 1 : null, reason: tier.name);
        }
      });
    }
  });

  group('the Shadows that answer them', () {
    setUp(() => omensOn = true);

    test("Off Beat never stretches Guardian Chain's nor Hex Blade's every-Nth (a Legenda's)", () {
      final (g, u, orc) = duel(Relic.guardianChain);
      topOmen(g, OmenKind.offBeat);
      expect(g.omenOffBeat, greaterThan(0));
      final near = stand(placeNow(g, 'archer', 1, 3));
      for (var n = 1; n <= guardianChainK.every; n++) {
        blow(g, u, orc);
      }
      expect(g.effectOn(near, Status.link)?.by, u, reason: 'the 4th');
      final (h, v, foe) = duel(Relic.hexBlade);
      topOmen(h, OmenKind.offBeat);
      for (var n = 1; n <= hexBladeK.every; n++) {
        blow(h, v, foe);
      }
      expect(h.effectOn(foe, Status.hex)?.by, v, reason: 'the 8th');
    });

    test("Unbowed shrugs off Hex Blade's first hex (its cooldown spent, nothing counted); the next one after it lands", () {
      final (g, u, orc) = duel(Relic.hexBlade);
      g.omens.add(OmenKind.unbowed);
      orc.shrugs = 1;
      for (var n = 1; n <= hexBladeK.every; n++) {
        blow(g, u, orc);
      }
      expect((g.effectOn(orc, Status.hex), orc.shrugs, g.pusakaWorth[Relic.hexBlade]), (null, 0, null));
      expect(u.fxReady, greaterThan(g.t), reason: 'the cooldown runs');
      runFor(g, hexBladeK.cd);
      for (var n = 1; n <= hexBladeK.every; n++) {
        blow(g, u, orc);
      }
      expect((g.effectOn(orc, Status.hex)?.by, g.pusakaWorth[Relic.hexBlade]!.uses), (u, 1));
    });

    test("Deathless keeps a gold monster's first deadly blow from killing it: no Glory Seeker might until it truly dies", () {
      final (g, u, orc) = duel(Relic.glorySeeker, tier: Tier.highElite);
      topOmen(g, OmenKind.deathless);
      orc.hp = 1;
      blow(g, u, orc);
      expect((orc.alive, g.effectOn(u, Status.might)), (true, null));
      runFor(g, OmenKind.deathless.k.max + 0.1);
      orc.hp = 1;
      blow(g, u, orc);
      expect(orc.alive, isFalse);
      expect(g.effectOn(u, Status.might)?.k, glorySeekerK.might);
    });

    test("Spree counts Phoenix Plume's fall as a silver killer's kill, though the troop rises again", () {
      final (g, u, orc) = duel(Relic.phoenix, tier: Tier.elite, wave: true);
      topOmen(g, OmenKind.spree);
      u.hp = 1;
      strikeBy(g, orc);
      expect((u.alive, orc.troopKills), (false, 1));
      runFor(g, phoenixK.delay + 0.2);
      expect(g.troops.where((o) => o.alive && o.type == 'knight'), hasLength(1));
      expect(orc.troopKills, 1);
    });

    test("Side Swing's extra hit does nothing to a troop Soul Shelter shelters", () {
      double swung({required bool shelter}) {
        final g = plain(Random(2));
        final a = stand(placeNow(g, 'knight', 1, 3)), y = stand(placeNow(g, 'archer', 3, 3)), x = stand(placeNow(g, 'soldier', 4, 3));
        stand(placeNow(g, 'wizard', 0, 6));
        if (shelter) g.givePusaka(Relic.soulShelter, type: 'knight');
        topOmen(g, OmenKind.sideSwing);
        for (final o in [y, x]) {
          o
            ..maxHp = 100000
            ..hp = 100000;
        }
        final killer = bigFoe(g, a.pos + const Point(-12, 0));
        a.hp = 1;
        strikeBy(g, killer);
        expect(a.alive, isFalse);
        expect(g.effectOn(y, Status.cap) != null, shelter);
        expect(g.effectOn(x, Status.cap), isNull, reason: '3 tiles off');
        strikeBy(g, bigFoe(g, x.pos + const Point(12, 0)));
        expect(x.hp, lessThan(100000));
        return 100000 - y.hp;
      }

      expect(swung(shelter: false), greaterThan(0));
      expect(swung(shelter: true), 0);
    });

    test("Backlash answers Mana Font's skill like any: the monsters near the caster get its might", () {
      final (g, u, near, _) = fontScene(Relic.manaFont);
      topOmen(g, OmenKind.backlash);
      g.tick(0.05);
      expect(g.log.entries.whereType<SkillCast>(), hasLength(1));
      expect(near.mp, greaterThan(0));
      final close = [for (final o in g.enemies) if (o.pos.distanceTo(u.pos) <= omenBacklashTiles * tile) o];
      expect(close, isNotEmpty);
      expect([for (final o in close) g.effectOn(o, Status.might)?.omen], everyElement(isTrue));
    });
  });

  group('the chest, the save, the Shadows\' needs, the log', () {
    test('the chest deals each of the eight from wave legendFrom (the Legenda pool was twenty-one then), binds it by its '
        'default rule, and never offers one found again', () {
      final legenda = [for (final r in Relic.values) if (r.pusaka && r.rarity == Rarity.legenda && pusakaCatalog[r]!.live) r];
      expect(legenda.skip(13).take(batch.length).toList(), batch, reason: "batch G-3's three follow");
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
      expect(pusakaPrefs[Relic.rageTotem]!.contains('priest'), isFalse, reason: 'its trade cuts the heals it gets');
    });

    test("the save keeps an owned one (its type, ★1 and Carve steps) and finds it; the owner's save holds none", () {
      final g = plain(Random(1));
      placeNow(g, 'knight', 2, 3);
      placeNow(g, 'soldier', 0, 3);
      g
        ..givePusaka(Relic.phoenix, type: 'knight', ukir: 3)
        ..givePusaka(Relic.manaFont, type: 'soldier', stars: 3, ukir: 5)
        ..givePusaka(Relic.hexBlade);
      final back = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
      final p = back.pusaka;
      expect((p[Relic.phoenix]!.type, p[Relic.phoenix]!.stars, p[Relic.phoenix]!.ukir), ('knight', 1, 3));
      expect((p[Relic.manaFont]!.type, p[Relic.manaFont]!.stars, p[Relic.manaFont]!.ukir), ('soldier', 1, 5));
      expect(p[Relic.hexBlade]!.type, isNull);
      expect(back.gudang, contains(Relic.hexBlade));
      expect(back.legendsFound, {Relic.phoenix, Relic.manaFont, Relic.hexBlade});
      expect(back.statsOf('knight').hp, g.statsOf('knight').hp, reason: 'the trade works on load');
      expect(back.statsOf('soldier').mpRegen, g.statsOf('soldier').mpRegen);
      expect(jsonEncode(back.toJson()), jsonEncode(g.toJson()));
      final w89 = Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>);
      expect(w89.pusaka.keys.where(batch.contains), isEmpty, reason: "the owner's save holds none");
    });

    test("the Shadows' needs they meet: a hex (Hex Blade), a might on troops (Glory Seeker); none an every-Nth or a "
        'cooldown (a Legenda\'s)', () {
      Game army() {
        final g = plain(Random(1));
        placeNow(g, 'knight', 2, 3);
        placeNow(g, 'archer', 0, 3);
        return g;
      }

      Set<OmenNeed> met(Relic r) => (army()..givePusaka(r, type: 'knight')).omenMet;
      final none = army().omenMet;
      expect({for (final r in batch) r: met(r).difference(none)}, {
        Relic.rageTotem: <OmenNeed>{},
        Relic.guardianChain: <OmenNeed>{},
        Relic.phalanx: <OmenNeed>{},
        Relic.phoenix: <OmenNeed>{},
        Relic.soulShelter: <OmenNeed>{},
        Relic.manaFont: <OmenNeed>{},
        Relic.hexBlade: {OmenNeed.hex},
        Relic.glorySeeker: {OmenNeed.mightOrHaste},
      });
      expect(omenCanAct(OmenKind.unbowed, met(Relic.hexBlade)), isTrue);
      for (final kind in const [OmenKind.vultures, OmenKind.sideSwing, OmenKind.spree, OmenKind.deathless]) {
        expect(kind.needs, isEmpty, reason: '$kind always acts');
      }
      expect(omenCanAct(OmenKind.backlash, met(Relic.manaFont)), isTrue, reason: 'an MP skill');
    });

    test("the battle log's report lines and the counter families", () {
      String line(Relic r, String type, int uses, double worth) => pusakaReportLines(PusakaReport(1, 0, lines: [
            (relic: r, type: type, stars: 1, uses: uses, worth: worth),
          ])).single;
      expect(line(Relic.rageTotem, 'armored_axeman', 9, 1200), 'Rage Totem (Axeman): +1.2k damage');
      expect(line(Relic.guardianChain, 'knight_templar', 12, 640), 'Guardian Chain (Templar): took +640 for troops near');
      expect(line(Relic.phalanx, 'soldier', 0, 300), 'Phalanx (Soldier): +300 damage blocked');
      expect(line(Relic.phoenix, 'soldier', 1, 1), 'Phoenix Plume (Soldier): brought back 1 troop');
      expect(line(Relic.soulShelter, 'soldier', 3, 450), 'Soul Shelter (Soldier): sheltered 3 troops, +450 blocked');
      expect(line(Relic.manaFont, 'wizard', 4, 120), 'Mana Font (Wizard): +120 MP');
      expect(line(Relic.hexBlade, 'archer', 3, 0), 'Hex Blade (Archer): hexed 3 times');
      expect(line(Relic.hexBlade, 'archer', 1, 0), 'Hex Blade (Archer): hexed once');
      expect(line(Relic.glorySeeker, 'swordsman', 2, 0), 'Glory Seeker (Swordsman): powered up 2 times');
      expect({for (final r in batch) r: fxFamily(r)}, {
        Relic.rageTotem: FxFamily.added,
        Relic.guardianChain: FxFamily.keptOff,
        Relic.phalanx: FxFamily.keptOff,
        Relic.phoenix: FxFamily.saves,
        Relic.soulShelter: FxFamily.keptOff,
        Relic.manaFont: FxFamily.mana,
        Relic.hexBlade: FxFamily.applied,
        Relic.glorySeeker: FxFamily.applied,
      });
      expect(pusakaCounter((relic: Relic.phoenix, type: 'soldier', stars: 1, uses: 2, worth: 2)), '2 saved');
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
      testWidgets('each of the eight fits ${size.width.round()}x${size.height.round()}: the gold Legenda cards and the '
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
        // The eight three a chest, the longest together (Mana Font, Hex Blade, Soul Shelter); the last with old ones.
        final hands = [
          [Relic.manaFont, Relic.hexBlade, Relic.soulShelter],
          [Relic.phoenix, Relic.guardianChain, Relic.glorySeeker],
          [Relic.rageTotem, Relic.phalanx, Relic.vowSilence],
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
