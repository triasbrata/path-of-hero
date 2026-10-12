// Batch L-2P (decisions-log 207; catalog-design §3.1 and §5.2, catalog-bayangan-v2 §4 and §5.2): ten more Langka
// Artifacts as catalog rows on the engine's Fx. Each one's effect at ★1, ★2 and ★3 and with Carve steps (the number
// [pusakaAt] gives), its words, its row (rarity, Carve role, the atlas's icon, epithet, counter, chest-only), the
// Bayangan Off Beat's reach on its every-Nth gates (the `_everyOf` contract of batch L-2B), the counters that answer
// it, the chest offering it, the save keeping an owned one, what it gives the Shadows' needs, its battle-log line, and
// its card on the Boss Chest at 915x412 and 1266x713. The rules every row keeps (band, key, icon, counter in its pool):
// pusaka_catalog_test.dart. docs/loot-items-relics.md "The Pusaka catalog and its engine".
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

/// The batch's ten, in [Relic] order (catalog-design §3.1's).
const batch = [
  Relic.momentum, Relic.bleedingEdge, Relic.shatterShard, Relic.painCrystal, Relic.watchShield, //
  Relic.boneBuckler, Relic.riposte, Relic.manaLeech, Relic.lootersPouch, Relic.spellCutter,
];

/// Batch L-1P's ten, before these in the Langka pool (pusaka_langka1_test.dart).
const _l1p = [
  Relic.titanBane, Relic.finishingBlade, Relic.firstCut, Relic.shellCracker, Relic.twinFury, //
  Relic.steadyStance, Relic.turtleShell, Relic.dullingMail, Relic.challengeLetter, Relic.snareCord,
];

/// The stars and Carve steps each effect is checked at: ★1-★3 bare, then two carved.
const _levels = [(1, 0), (2, 0), (3, 0), (1, 2), (3, 5)];

/// A game with no skills cast, so what happens is the Pusaka's doing.
Game plain([Random? rng]) => bareGame(rng)
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false
  ..monsterSkills = false;

/// Lets [foe] strike once now (then it stands again); a shooter's arrow gets the time to land.
void strikeBy(Game g, Unit foe) {
  foe
    ..busyUntil = double.negativeInfinity
    ..cd = 0;
  g.tick(0.05);
  foe.busyUntil = hold;
  if (foe.stats.shotSpeed > 0) runFor(g, 0.3);
}

/// What troop [u]'s next normal attack takes off [foe] (its cooldown over now; it waits again after).
double blow(Game g, Unit u, Unit foe) {
  final before = foe.hp;
  u.cd = 0;
  g.tick(0.05);
  u.cd = hold;
  return before - foe.hp;
}

/// [n] normal attacks of troop [u].
void blows(Game g, Unit u, int n) {
  for (var i = 0; i < n; i++) {
    u.cd = 0;
    g.tick(0.05);
  }
  u.cd = hold;
}

/// A knight (or a troop of [type]) standing at (2, 3) with [relic] bound to its type at [stars] and [ukir] Carve steps
/// (none: nothing bound), that attacks only when told ([blow]), and an orc of [tier] next to it with HP to spare that
/// strikes only when told ([strikeBy]).
(Game, Unit, Unit) duel(Relic? relic, {int stars = 1, int ukir = 0, Tier tier = Tier.normal, String type = 'knight'}) {
  final g = plain(Random(2));
  final k = placeNow(g, type, 2, 3)..cd = hold;
  if (relic != null) g.givePusaka(relic, type: type, stars: stars, ukir: ukir);
  final orc = foeAt(g, 'orc', k.pos + const Point(12, 0), tier)
    ..maxHp = 1000000
    ..hp = 1e6;
  return (g, k, orc);
}

/// A monster of [type] with [hp] left at [u]'s target spot, put first so [u] hits it before the orc there.
Unit weak(Game g, Unit u, {double hp = 1, String type = 'orc'}) {
  final o = foeAt(g, type, u.pos + const Point(12, 0));
  g.units
    ..remove(o)
    ..insert(0, o);
  return o..hp = hp;
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
    test('ten Langka appended after batch L-1P (save keys), chest-only, in the game; names, Carve roles, epithets, the '
        "atlas's icons and catalog-bayangan-v2's counters", () {
      expect(Relic.values.skipWhile((r) => r != Relic.snareCord).skip(1).take(batch.length).toList(), batch);
      expect({for (final r in batch) r: relicNames[r]}, {
        Relic.momentum: 'Momentum',
        Relic.bleedingEdge: 'Bleeding Edge',
        Relic.shatterShard: 'Shatter Shard',
        Relic.painCrystal: 'Pain Crystal',
        Relic.watchShield: 'Watch Shield',
        Relic.boneBuckler: 'Bone Buckler',
        Relic.riposte: 'Riposte',
        Relic.manaLeech: 'Mana Leech',
        Relic.lootersPouch: "Looter's Pouch",
        Relic.spellCutter: 'Spell Cutter',
      });
      for (final r in batch) {
        final art = pusakaCatalog[r]!;
        expect((r.rarity, r.scope, r.store, art.live, r.oath, maxStars(r)), (Rarity.langka, RelicScope.type, false, true, false, starMax), reason: '$r');
        expect(art.icon.sheet, 'artifact_icons.png', reason: '$r');
        expect((art.icon.x, art.icon.y, art.icon.tint), (artifactIcon(r.name).x, artifactIcon(r.name).y, null), reason: '$r');
        expect(art.fx, hasLength(1), reason: '$r');
      }
      expect(liveL2P, isTrue);
      expect({for (final r in batch) r: pusakaCatalog[r]!.role}, {
        Relic.momentum: UkirRole.attack,
        Relic.bleedingEdge: UkirRole.attack,
        Relic.shatterShard: UkirRole.attack,
        Relic.painCrystal: UkirRole.guard, // utility (guard)
        Relic.watchShield: UkirRole.guard,
        Relic.boneBuckler: UkirRole.guard,
        Relic.riposte: UkirRole.guard,
        Relic.manaLeech: UkirRole.life, // utility (life)
        Relic.lootersPouch: UkirRole.attack, // utility (attack)
        Relic.spellCutter: UkirRole.attack, // utility (attack)
      });
      expect({for (final r in batch) r: buildEpithets[r]}, {
        Relic.momentum: 'Rushing',
        Relic.bleedingEdge: 'Rending',
        Relic.shatterShard: 'Shattering',
        Relic.painCrystal: 'Crystal',
        Relic.watchShield: 'Watchful',
        Relic.boneBuckler: 'Bone',
        Relic.riposte: 'Parrying',
        Relic.manaLeech: 'Leeching',
        Relic.lootersPouch: 'Greedy',
        Relic.spellCutter: 'Dispelling',
      });
      expect(buildEpithets.values.toSet().length, buildEpithets.length, reason: 'an epithet twice');
      expect({for (final r in batch) r: pusakaCatalog[r]!.counter}, {
        Relic.momentum: OmenKind.avenge,
        Relic.bleedingEdge: OmenKind.offBeat,
        Relic.shatterShard: OmenKind.brace,
        Relic.painCrystal: OmenKind.spellTax,
        Relic.watchShield: OmenKind.fade,
        Relic.boneBuckler: OmenKind.shieldbreak,
        Relic.riposte: OmenKind.thorns,
        Relic.manaLeech: OmenKind.spellTax,
        Relic.lootersPouch: OmenKind.thrift,
        Relic.spellCutter: OmenKind.lingering,
      });
      for (final r in batch) {
        expect(pusakaCatalog[r]!.counter.answers, contains(r), reason: '$r');
      }
      final g = Game()..wave = storeFrom;
      expect([for (final r in batch) g.basePrice(r)], everyElement(langkaPrice), reason: 'sold back from the Vault like the four');
      expect(storeGoods.where(batch.contains), isEmpty, reason: 'never in the Shop');
    });

    test('each leads with its own Fx (no other row shares its key); the band measures the bleed, the bursts and the '
        "shields; Momentum's charge is a proc, at most War Drum's; the cooled ones", () {
      final keys = {for (final MapEntry(key: r, value: a) in pusakaCatalog.entries) if (a.fx.isNotEmpty) a.fx.first.key: r};
      for (final r in batch) {
        expect(keys[pusakaCatalog[r]!.fx.first.key], r, reason: '$r');
      }
      Fx fx(Relic r) => pusakaCatalog[r]!.fx.first;
      for (var s = 1; s <= starMax; s++) {
        expect(fxGain(fx(Relic.bleedingEdge), pusakaAt(Relic.bleedingEdge, s), 1), (Band.power, bleedingEdgeK.share[s - 1] / bleedingEdgeK.every));
        expect(fxGain(fx(Relic.shatterShard), pusakaAt(Relic.shatterShard, s), 1), (Band.power, shatterShardK.share[s - 1] / shatterShardK.every));
        expect(fxGain(fx(Relic.riposte), pusakaAt(Relic.riposte, s), 1), (Band.power, riposteK.share[s - 1] / riposteK.every));
        expect(fxGain(fx(Relic.boneBuckler), pusakaAt(Relic.boneBuckler, s), boneBucklerK.stack)!.$2,
            closeTo(boneBucklerK.add[s - 1] * boneBucklerK.stack, 1e-9));
        expect(fxGain(fx(Relic.watchShield), pusakaAt(Relic.watchShield, s), 1), (Band.ward, watchShieldK[s - 1]));
        expect(fxGain(fx(Relic.momentum), pusakaAt(Relic.momentum, s), 1), isNull);
        expect(momentumK[s - 1], lessThanOrEqualTo(perProcMax[s - 1]));
      }
      for (final r in [Relic.manaLeech, Relic.painCrystal, Relic.lootersPouch, Relic.spellCutter]) {
        expect(fxGain(fx(r), pusakaAt(r, 1), 1), isNull, reason: '$r: exempt, a probe arm instead');
      }
      expect([for (final r in batch) if (fx(r).cooled) r], [Relic.shatterShard, Relic.painCrystal, Relic.spellCutter]);
      expect(hardConds.contains(fx(Relic.riposte).when), isFalse, reason: 'up close earns the quarter');
    });

    test('their words at ★1, from the constants: the card and tooltip lines, and the Bag row\'s gist', () {
      final g = Game();
      expect({for (final r in batch) r: g.relicEffect(r, stars: 1)}, {
        Relic.momentum: ['After a kill: next hit x1.3 damage'],
        Relic.bleedingEdge: ['Every 3rd hit: the monster bleeds', '30% of that hit over 3s'],
        Relic.shatterShard: ['Every 5th hit: monsters next to', 'the target take 40% of it'],
        Relic.painCrystal: ['When hit: +2% max MP', 'Every 1s at most'],
        Relic.watchShield: ['Each wave starts with a shield', 'of 10% max HP'],
        Relic.boneBuckler: ['Each kill: +4% max HP shield', 'up to 12%'],
        Relic.riposte: ['Every 3rd up-close hit on it:', 'hits back for 40% of its attack'],
        Relic.manaLeech: ['Every 3rd hit: +3% max MP'],
        Relic.lootersPouch: ['Monsters it kills give +10% gold'],
        Relic.spellCutter: ['Every 5th hit: the monster loses', '1 good effect (bosses: half its time)', 'Every 6s at most'],
      });
      expect({for (final r in batch) r: pusakaGist(r, 1)}, {
        Relic.momentum: 'Kill: next hit x1.3',
        Relic.bleedingEdge: 'Bleed 30% every 3rd',
        Relic.shatterShard: '40% to near, every 5th',
        Relic.painCrystal: 'Hit: +2% MP',
        Relic.watchShield: 'Wave shield 10% HP',
        Relic.boneBuckler: 'Kill: +4% shield, max 12%',
        Relic.riposte: 'Hits back 40%, every 3rd',
        Relic.manaLeech: '+3% MP every 3rd',
        Relic.lootersPouch: '+10% kill gold',
        Relic.spellCutter: 'Strips 1 every 5th',
      });
      // ★2, ★3 and a Carve step move the numbers the words show: a half percent stays, a cooldown comes down.
      expect(g.relicEffect(Relic.manaLeech, stars: 2), ['Every 3rd hit: +4.5% max MP']);
      expect(g.relicEffect(Relic.boneBuckler, stars: 3), ['Each kill: +6% max HP shield', 'up to 18%']);
      expect(g.relicEffect(Relic.spellCutter, stars: 3).last, 'Every 4s at most');
      expect(g.relicEffect(Relic.momentum, stars: 2), ['After a kill: next hit x1.45 damage']);
      expect(pusakaAt(Relic.spellCutter, 1, ukir: 5), lessThan(spellCutterK.cd[0]), reason: 'Carve shortens it, as the stars do');
      expect(fxLines(Relic.lootersPouch, 1, ukir: 5), ['Monsters it kills give +${((pusakaAt(Relic.lootersPouch, 1, ukir: 5) - 1) * 100).round()}% gold']);
      // A carved Bone Buckler at ★3 builds up no shield past the ward's most.
      expect(fxLines(Relic.boneBuckler, 3, ukir: ukirCost.length).last, 'up to ${(wardMax * 100).round()}%');
      expect(pusakaAt(Relic.watchShield, 3, ukir: ukirCost.length), greaterThan(wardMax));
      expect(fxLines(Relic.watchShield, 3, ukir: ukirCost.length).last, 'of ${(wardMax * 100).round()}% max HP');
    });

    test("the Bag's detail says the first sentence whole", () {
      final g = Game();
      expect({for (final r in batch) r: firstSentence(g.relicEffect(r, stars: 1))}, {
        Relic.momentum: 'After a kill: next hit x1.3 damage',
        Relic.bleedingEdge: 'Every 3rd hit: the monster bleeds 30% of that hit over 3s',
        Relic.shatterShard: 'Every 5th hit: monsters next to the target take 40% of it',
        Relic.painCrystal: 'When hit: +2% max MP',
        Relic.watchShield: 'Each wave starts with a shield of 10% max HP',
        Relic.boneBuckler: 'Each kill: +4% max HP shield up to 12%',
        Relic.riposte: 'Every 3rd up-close hit on it: hits back for 40% of its attack',
        Relic.manaLeech: 'Every 3rd hit: +3% max MP',
        Relic.lootersPouch: 'Monsters it kills give +10% gold',
        Relic.spellCutter: 'Every 5th hit: the monster loses 1 good effect (bosses: half its time)',
      });
    });
  });

  group('the effects at ★1, ★2, ★3 and carved', () {
    for (final (stars, ukir) in _levels) {
      final at = '★$stars${ukir > 0 ? ' +$ukir' : ''}';

      test('$at: the table, or past it by the Carve steps', () {
        final i = stars - 1;
        for (final (r, table) in [
          (Relic.momentum, momentumK),
          (Relic.bleedingEdge, bleedingEdgeK.share),
          (Relic.shatterShard, shatterShardK.share),
          (Relic.painCrystal, painCrystalK.mp),
          (Relic.watchShield, watchShieldK),
          (Relic.boneBuckler, boneBucklerK.add),
          (Relic.riposte, riposteK.share),
          (Relic.manaLeech, manaLeechK.mp),
          (Relic.lootersPouch, lootersPouchK),
          (Relic.spellCutter, spellCutterK.cd),
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

      test('$at Momentum: a kill charges its next normal attack with ×k, once; a wave\'s start drops a charge', () {
        final k = pusakaAt(Relic.momentum, stars, ukir: ukir);
        final (g, u, orc) = duel(Relic.momentum, stars: stars, ukir: ukir);
        final d = u.stats.dmg, def = orc.stats.def;
        expect(blow(g, u, orc), closeTo(hitTaken(d, def), 1e-9), reason: 'no charge yet');
        final w = weak(g, u);
        blow(g, u, w);
        expect(w.alive, isFalse);
        expect((u.charge?.relic, u.charge?.k), (Relic.momentum, k));
        expect(blow(g, u, orc), closeTo(hitTaken(d * k, def), 1e-9), reason: 'the charge spent');
        expect(u.charge, isNull);
        expect(blow(g, u, orc), closeTo(hitTaken(d, def), 1e-9), reason: 'one hit only');
        expect(g.pusakaWorth[Relic.momentum]!.uses, 1);
        expect(g.pusakaWorth[Relic.momentum]!.worth, closeTo(d * (k - 1), 1e-9));
        blow(g, u, weak(g, u));
        expect(u.charge, isNotNull);
        g.units.removeWhere((o) => o.side == Side.enemy);
        g.startWave();
        expect(u.charge, isNull, reason: 'a new wave');
      });

      test('$at Bleeding Edge: every 3rd attack makes the monster bleed k of that attack over 3s, a tick a second', () {
        final k = pusakaAt(Relic.bleedingEdge, stars, ukir: ukir);
        final (g, u, orc) = duel(Relic.bleedingEdge, stars: stars, ukir: ukir);
        final d = u.stats.dmg;
        blows(g, u, 2);
        expect(g.effectOn(orc, Status.bleed), isNull);
        blows(g, u, 1);
        final e = g.effectOn(orc, Status.bleed)!;
        expect(e.k, closeTo(d * k / bleedingEdgeK.time, 1e-9));
        expect((e.n, e.by), (bleedingEdgeK.time.round(), u));
        expect(e.until - g.t, closeTo(bleedingEdgeK.time + 0.5, 0.051));
        final before = orc.hp;
        runFor(g, bleedingEdgeK.time + 0.6);
        expect(before - orc.hp, closeTo(3 * hitTaken(d * k / 3, orc.stats.def), 1e-6), reason: 'three ticks, each through its defence');
        expect(g.effectOn(orc, Status.bleed), isNull);
        expect(g.pusakaWorth[Relic.bleedingEdge]!.uses, 1);
        expect(g.pusakaWorth[Relic.bleedingEdge]!.worth, closeTo(d * k, 1e-9));
        // A stronger bleed already on it stays.
        g.addEffect(orc, Status.bleed, 10, k: d * 10, n: 10);
        blows(g, u, 3);
        expect(g.effectOn(orc, Status.bleed)!.k, d * 10);
        expect(g.pusakaWorth[Relic.bleedingEdge]!.uses, 1);
      });

      test('$at Shatter Shard: every 5th hit landed, the monsters next to its target take k of it, at most once a second',
          () {
        final k = pusakaAt(Relic.shatterShard, stars, ukir: ukir);
        final (g, u, orc) = duel(Relic.shatterShard, stars: stars, ukir: ukir);
        final near = foeAt(g, 'orc', orc.pos + const Point(0, 10))..hp = 1e5..maxHp = 100000; // next to it, out of u's reach
        final far = foeAt(g, 'orc', orc.pos + const Point(0, 30))..hp = 1e5..maxHp = 100000;
        final d = u.stats.dmg;
        blows(g, u, 4);
        expect((near.hp, far.hp), (1e5, 1e5));
        blows(g, u, 1);
        expect(1e5 - near.hp, closeTo(hitTaken(d * k, near.stats.def), 1e-9), reason: 'extra damage, through its defence');
        expect(far.hp, 1e5, reason: 'past a tile');
        expect(orc.hp, closeTo(1e6 - 5 * hitTaken(d, orc.stats.def), 1e-6), reason: 'the target takes only its own hits');
        expect(g.pusakaWorth[Relic.shatterShard]!.uses, 1);
        // The next 5th comes within its cooldown: none; after it, one.
        blows(g, u, 5);
        expect(1e5 - near.hp, closeTo(hitTaken(d * k, near.stats.def), 1e-9));
        runFor(g, shatterShardK.cd);
        blows(g, u, 5);
        expect(1e5 - near.hp, closeTo(2 * hitTaken(d * k, near.stats.def), 1e-9));
        expect(g.pusakaWorth[Relic.shatterShard]!.uses, 2);
      });

      test('$at Pain Crystal: a blow that hurts it gives it k of its max MP, at most once a second', () {
        final k = pusakaAt(Relic.painCrystal, stars, ukir: ukir);
        final (g, u, orc) = duel(Relic.painCrystal, stars: stars, ukir: ukir);
        u.mp = 0;
        strikeBy(g, orc);
        final most = u.stats.mp;
        expect(g.pusakaWorth[Relic.painCrystal]!.worth, closeTo(most * k, 1e-9));
        strikeBy(g, orc);
        expect(g.pusakaWorth[Relic.painCrystal]!.uses, 1, reason: 'its cooldown');
        runFor(g, painCrystalK.cd);
        strikeBy(g, orc);
        expect(g.pusakaWorth[Relic.painCrystal]!.uses, 2);
        u.mp = most.toDouble();
        runFor(g, painCrystalK.cd);
        strikeBy(g, orc);
        expect(u.mp, most, reason: 'never past its max MP');
      });

      test('$at Watch Shield: each wave starts with a shield of k of its max HP that blows break first; it counts what '
          'it kept off', () {
        final k = min(wardMax, pusakaAt(Relic.watchShield, stars, ukir: ukir)); // a carved ★3 stops at the ward's most
        final g = plain(Random(2));
        final u = placeNow(g, 'knight', 2, 3)..cd = hold;
        final other = placeNow(g, 'archer', 1, 3)..cd = hold;
        g
          ..givePusaka(Relic.watchShield, type: 'knight', stars: stars, ukir: ukir)
          ..startWave()
          ..queue.clear();
        expect(u.ward, closeTo(u.maxHp * k, 1e-9));
        expect(other.ward, 0, reason: 'its type only');
        final orc = foeAt(g, 'orc', u.pos + const Point(12, 0));
        final hp = u.hp;
        strikeBy(g, orc);
        final hit = hitTaken(orc.stats.dmg, u.stats.def);
        expect(u.hp, hp, reason: 'the shield took it');
        expect(u.ward, closeTo(u.maxHp * k - hit, 1e-9));
        expect(g.pusakaWorth[Relic.watchShield]!.worth, closeTo(hit, 1e-9));
        expect(g.pusakaWorth[Relic.watchShield]!.uses, 1);
      });

      test('$at Bone Buckler: each kill gives a shield of k of its max HP, up to 3 kills\' worth (never past the ward\'s '
          'most)', () {
        final k = pusakaAt(Relic.boneBuckler, stars, ukir: ukir);
        final (g, u, _) = duel(Relic.boneBuckler, stars: stars, ukir: ukir);
        final most = min(wardMax, k * boneBucklerK.stack);
        for (var n = 1; n <= 4; n++) {
          final w = weak(g, u);
          blow(g, u, w);
          expect(w.alive, isFalse);
          expect(u.ward, closeTo(u.maxHp * min(most, n * k), 1e-9), reason: 'kill $n');
        }
        expect(g.pusakaWorth[Relic.boneBuckler]!.uses, 4);
      });

      test('$at Riposte: every 3rd blow from a monster up close hits it back for k of its attack; a shot counts none', () {
        final k = pusakaAt(Relic.riposte, stars, ukir: ukir);
        final (g, u, orc) = duel(Relic.riposte, stars: stars, ukir: ukir);
        for (var n = 1; n <= 2; n++) {
          strikeBy(g, orc);
          expect(orc.hp, 1e6, reason: 'blow $n');
        }
        strikeBy(g, orc);
        expect(1e6 - orc.hp, closeTo(hitTaken(u.stats.dmg * k, orc.stats.def), 1e-9));
        expect(g.pusakaWorth[Relic.riposte]!.uses, 1);
        // A skeleton archer's arrows are no up-close blows.
        final (h, v, _) = duel(Relic.riposte, stars: stars, ukir: ukir);
        final archer = foeAt(h, 'skeleton_archer', v.pos + const Point(30, 0))
          ..maxHp = 100000
          ..hp = 1e5;
        for (var n = 0; n < 4; n++) {
          v.hp = v.maxHp.toDouble();
          strikeBy(h, archer);
        }
        expect(v.hp, lessThan(v.maxHp), reason: 'it was shot');
        expect((archer.hp, h.pusakaWorth[Relic.riposte]?.uses ?? 0), (1e5, 0));
      });

      test('$at Mana Leech: every 3rd attack gives it k of its max MP', () {
        final k = pusakaAt(Relic.manaLeech, stars, ukir: ukir);
        final (g, u, _) = duel(Relic.manaLeech, stars: stars, ukir: ukir);
        u.mp = 0;
        blows(g, u, 2);
        expect(g.pusakaWorth[Relic.manaLeech], isNull);
        blows(g, u, 1);
        expect(g.pusakaWorth[Relic.manaLeech]!.worth, closeTo(u.stats.mp * k, 1e-9));
      });

      test("$at Looter's Pouch: what it kills pays ×k gold, whole coins as they add up", () {
        final k = pusakaAt(Relic.lootersPouch, stars, ukir: ukir);
        final (g, u, _) = duel(Relic.lootersPouch, stars: stars, ukir: ukir);
        var paid = 0, bonus = 0.0;
        for (var n = 0; n < 12; n++) {
          final w = weak(g, u), gold = g.gold;
          blow(g, u, w);
          expect(w.alive, isFalse);
          paid += g.gold - gold - w.stats.cost;
          bonus += w.stats.cost * (k - 1);
        }
        expect(paid, inInclusiveRange(bonus.floor() - 1, bonus.floor()), reason: 'the share, in whole coins');
        expect(g.pusakaWorth[Relic.lootersPouch]!.worth, paid);
        expect(g.goldPops, isNotEmpty, reason: 'floated like Plunder\'s');
      });

      test('$at Spell Cutter: every 5th attack takes 1 good effect off (the longest left); on the boss half of what is '
          'left; then it waits k s', () {
        final k = pusakaAt(Relic.spellCutter, stars, ukir: ukir);
        final (g, u, orc) = duel(Relic.spellCutter, stars: stars, ukir: ukir);
        g
          ..addEffect(orc, Status.might, 30, k: 1.3)
          ..addEffect(orc, Status.haste, 20, k: 0.8);
        blows(g, u, 4);
        expect((g.under(orc, Status.might), g.under(orc, Status.haste)), (true, true));
        blows(g, u, 1);
        expect((g.under(orc, Status.might), g.under(orc, Status.haste)), (false, true), reason: 'the longest left');
        expect(u.fxReady - g.t, closeTo(k, 0.051));
        expect(g.pusakaWorth[Relic.spellCutter]!.uses, 1);
        blows(g, u, 5);
        expect(g.under(orc, Status.haste), isTrue, reason: 'its cooldown');
        runFor(g, k);
        blows(g, u, 5);
        expect(g.under(orc, Status.haste), isFalse);
        // A troop's slow is no good effect; with none to take, no cooldown starts.
        g.addEffect(orc, Status.slow, 10, k: 0.5, by: u);
        runFor(g, k);
        blows(g, u, 5);
        expect(g.under(orc, Status.slow), isTrue);
        expect(g.t, greaterThanOrEqualTo(u.fxReady));
        // The boss: half of what is left, once.
        final (h, v, boss) = duel(Relic.spellCutter, stars: stars, ukir: ukir, tier: Tier.boss);
        h.addEffect(boss, Status.might, 10, k: 1.3);
        blows(h, v, 5);
        final e = h.effectOn(boss, Status.might)!;
        expect(e.halved, isTrue);
        expect(e.until - h.t, closeTo((10 - 0.25) / 2, 0.06));
      });
    }
  });

  group("the Bayangan Off Beat's reach (batch L-2B's `_everyOf`): every one of the ten's every-Nth gates waits for its "
      'n more hits', () {
    test('Bleeding Edge, Mana Leech and Spell Cutter (attacks), Shatter Shard (hits landed), Riposte (hits taken)', () {
      omensOn = true;
      // Off Beat 1: one more hit each.
      (Game, Unit, Unit) beat(Relic r) {
        final (g, u, orc) = duel(r);
        g.omens.add(OmenKind.offBeat);
        expect(g.omenOffBeat, 1);
        return (g, u, orc);
      }

      var (g, u, orc) = beat(Relic.bleedingEdge);
      blows(g, u, 3);
      expect(g.effectOn(orc, Status.bleed), isNull, reason: 'the 3rd is the 4th now');
      blows(g, u, 1);
      expect(g.effectOn(orc, Status.bleed), isNotNull);

      (g, u, orc) = beat(Relic.manaLeech);
      u.mp = 0;
      blows(g, u, 3);
      expect(g.pusakaWorth[Relic.manaLeech], isNull);
      blows(g, u, 1);
      expect(g.pusakaWorth[Relic.manaLeech]!.uses, 1);

      (g, u, orc) = beat(Relic.spellCutter);
      g.addEffect(orc, Status.might, 10, k: 1.3);
      blows(g, u, 5);
      expect(g.under(orc, Status.might), isTrue);
      blows(g, u, 1);
      expect(g.under(orc, Status.might), isFalse);

      (g, u, orc) = beat(Relic.shatterShard);
      final near = foeAt(g, 'orc', orc.pos + const Point(0, 10))..hp = 1e5..maxHp = 100000;
      blows(g, u, 5);
      expect(near.hp, 1e5);
      blows(g, u, 1);
      expect(near.hp, lessThan(1e5));

      (g, u, orc) = beat(Relic.riposte);
      for (var n = 0; n < 3; n++) {
        strikeBy(g, orc);
      }
      expect(orc.hp, 1e6);
      strikeBy(g, orc);
      expect(orc.hp, lessThan(1e6));
      // Momentum, the shields, Pain Crystal and Looter's Pouch have no every: Off Beat needs nothing of them.
      for (final r in [Relic.momentum, Relic.watchShield, Relic.boneBuckler, Relic.painCrystal, Relic.lootersPouch]) {
        expect(pusakaCatalog[r]!.fx.first.every, 0, reason: '$r');
      }
    });
  });

  group('the counters answer them', () {
    test("Thrift cuts Looter's Pouch's share with the kill's gold; Fade shrinks Watch Shield's shield; Shieldbreak "
        "breaks Bone Buckler's sooner; Brace cuts Shatter Shard's burst on a fresh monster", () {
      omensOn = true;
      // Thrift: the Pouch's share is of the gold the kill pays after it.
      int pouch(List<OmenKind> omens) {
        final (g, u, _) = duel(Relic.lootersPouch, stars: 3);
        g.omens.addAll(omens);
        var paid = 0;
        for (var n = 0; n < 20; n++) {
          final w = weak(g, u, type: 'werebear'), gold = g.gold;
          blow(g, u, w);
          paid += g.gold - gold;
        }
        return paid;
      }

      final rich = pouch([]), thrift = pouch([OmenKind.thrift, OmenKind.thrift, OmenKind.thrift, OmenKind.thrift]);
      expect(thrift, lessThan(rich));
      // Fade: the shield shrinks each second.
      final g = plain(Random(2));
      final u = placeNow(g, 'knight', 2, 3)..cd = hold;
      g
        ..givePusaka(Relic.watchShield, type: 'knight', stars: 3)
        ..startWave()
        ..queue.clear();
      foeAt(g, 'orc', u.pos + const Point(200, 0)); // the wave stays on
      final full = u.ward;
      g.omens.addAll([OmenKind.fade, OmenKind.fade]);
      runFor(g, 1);
      expect(u.ward, lessThan(full));
      expect(u.ward, closeTo(full * pow(1 - g.omenK(OmenKind.fade) * 0.05, 20), 1e-6));
      // Shieldbreak: a monster's blow takes more of the shield.
      double broke(List<OmenKind> omens) {
        final (h, v, orc) = duel(Relic.boneBuckler, stars: 3);
        h.omens.addAll(omens);
        for (var n = 0; n < boneBucklerK.stack; n++) {
          blow(h, v, weak(h, v)); // a shield bigger than the orc's blow
        }
        final before = v.ward;
        strikeBy(h, orc);
        return before - v.ward;
      }

      expect(broke([OmenKind.shieldbreak, OmenKind.shieldbreak]), greaterThan(broke([])));
      // Brace: a monster over 90% HP takes less of the burst.
      double shard(List<OmenKind> omens) {
        final (h, v, orc) = duel(Relic.shatterShard);
        h.omens.addAll(omens);
        final near = foeAt(h, 'orc', orc.pos + const Point(0, 10))..hp = 1e5..maxHp = 100000;
        blows(h, v, 5);
        return 1e5 - near.hp;
      }

      expect(shard([OmenKind.brace, OmenKind.brace]), lessThan(shard([])));
    });
  });

  group('the chest, the save, the Shadows\' needs, the log', () {
    test('the chest deals each of the ten (the Langka pool is the four, L-1P\'s ten and these ten), binds it by its '
        'default rule, and keeps a ★3 one off its cards', () {
      final langka = [for (final r in Relic.values) if (r.pusaka && r.rarity == Rarity.langka && pusakaCatalog[r]!.live) r];
      // The first 24 of the Langka (batch L-3's six follow: pusaka_langka3_test.dart).
      expect(langka.take(24), [Relic.ironBanner, Relic.bloodFang, Relic.warDrum, Relic.mourningBell, ..._l1p, ...batch]);
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
        final k = placeNow(g, 'knight', 2, 3);
        g.chests.add(Chest(ChestKind.boss, 30, cards: [r]));
        expect(g.openChest(), [r], reason: '$r');
        expect(g.takeCard(0), isTrue);
        expect((g.pusaka[r]!.stars, g.pusaka[r]!.type, g.pusakaOf(k.type)), (1, 'knight', r), reason: '$r: every one may go on the knight');
        g.givePusaka(r, type: 'knight', stars: starMax);
        g.chests.add(Chest(ChestKind.boss, 30, cards: [r]));
        expect(g.openChest(), [null], reason: '$r ★3: a Shard');
      }
      for (final r in batch) {
        expect(pusakaPrefs[r], isNotEmpty, reason: '$r');
      }
    });

    test('the save keeps an owned one (its type, stars and Carve steps); the owner\'s save holds none; a charge, a '
        'shield and a cooldown are not saved', () {
      final g = plain(Random(1));
      final u = placeNow(g, 'knight', 2, 3);
      g
        ..givePusaka(Relic.riposte, type: 'knight', stars: 2, ukir: 3)
        ..givePusaka(Relic.lootersPouch, stars: 3);
      u
        ..charge = (relic: Relic.momentum, k: 1.3)
        ..ward = 10;
      final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
      final back = Game.fromJson(j);
      expect((back.pusaka[Relic.riposte]!.type, back.pusaka[Relic.riposte]!.stars, back.pusaka[Relic.riposte]!.ukir), ('knight', 2, 3));
      expect((back.pusaka[Relic.lootersPouch]!.type, back.pusaka[Relic.lootersPouch]!.stars), (null, 3));
      expect(back.gudang, contains(Relic.lootersPouch));
      final v = back.troops.single;
      expect((v.charge, v.ward), (null, 0));
      final w89 = Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>);
      expect(w89.pusaka.keys.where(batch.contains), isEmpty, reason: "the owner's save holds none");
    });

    test("the Shadows' needs: every few hits (Off Beat), a cooldown (Drag), a troop shield (Fade, Shieldbreak), an extra "
        'hit (Scatter) and a hit back (Thornproof)', () {
      final g = plain(Random(1));
      for (final (type, c, r) in [('knight', 2, 3), ('archer', 1, 3), ('soldier', 2, 5), ('lancer', 1, 5), ('swordsman', 2, 1)]) {
        placeNow(g, type, c, r);
      }
      expect(g.omenMet.intersection({OmenNeed.everyFx, OmenNeed.cdFx, OmenNeed.troopShield, OmenNeed.extraHit, OmenNeed.hitBack}), isEmpty);
      g.givePusaka(Relic.riposte, type: 'knight');
      expect(g.omenMet, containsAll([OmenNeed.everyFx, OmenNeed.hitBack]));
      expect(g.omenMet.contains(OmenNeed.extraHit), isFalse, reason: 'a hit back is no extra hit');
      g.givePusaka(Relic.painCrystal, type: 'archer');
      expect(g.omenMet, contains(OmenNeed.cdFx));
      g.givePusaka(Relic.watchShield, type: 'soldier');
      expect(g.omenMet, contains(OmenNeed.troopShield));
      g.givePusaka(Relic.shatterShard, type: 'lancer');
      expect(g.omenMet, contains(OmenNeed.extraHit));
      final h = plain(Random(1));
      placeNow(h, 'knight', 2, 3);
      h.givePusaka(Relic.spellCutter, type: 'knight');
      expect(h.omenMet, containsAll([OmenNeed.everyFx, OmenNeed.cdFx]), reason: "a strip's cooldown is its k");
    });

    test("the battle log's report lines and the VICTORY! line: MP and gold count their own, never against damage", () {
      String line(Relic r, int uses, double worth) => pusakaReportLines(PusakaReport(1, 0, lines: [
            (relic: r, type: 'knight', stars: 1, uses: uses, worth: worth),
          ])).single;
      expect(line(Relic.spellCutter, 3, 0), 'Spell Cutter (Knight): stripped 3 times');
      expect(line(Relic.spellCutter, 1, 0), 'Spell Cutter (Knight): stripped once');
      expect(line(Relic.manaLeech, 5, 12.4), 'Mana Leech (Knight): +12 MP');
      expect(line(Relic.painCrystal, 5, 3), 'Pain Crystal (Knight): +3 MP');
      expect(line(Relic.lootersPouch, 9, 1234), "Looter's Pouch (Knight): +1.2k gold");
      expect(line(Relic.watchShield, 4, 340), 'Watch Shield (Knight): +340 damage blocked');
      expect(line(Relic.boneBuckler, 4, 34), 'Bone Buckler (Knight): +34 damage blocked');
      expect(line(Relic.bleedingEdge, 4, 340), 'Bleeding Edge (Knight): +340 damage');
      expect(line(Relic.momentum, 2, 40), 'Momentum (Knight): +40 damage');
      expect({for (final r in batch) r: fxFamily(r)}, {
        Relic.momentum: FxFamily.added,
        Relic.bleedingEdge: FxFamily.added,
        Relic.shatterShard: FxFamily.added,
        Relic.painCrystal: FxFamily.mana,
        Relic.watchShield: FxFamily.keptOff,
        Relic.boneBuckler: FxFamily.keptOff,
        Relic.riposte: FxFamily.added,
        Relic.manaLeech: FxFamily.mana,
        Relic.lootersPouch: FxFamily.gold,
        Relic.spellCutter: FxFamily.applied,
      });
      final r = PusakaReport(1, 0, lines: [
        (relic: Relic.lootersPouch, type: 'archer', stars: 1, uses: 9, worth: 5000),
        (relic: Relic.manaLeech, type: 'wizard', stars: 1, uses: 9, worth: 900),
        (relic: Relic.warDrum, type: 'knight', stars: 1, uses: 3, worth: 120),
      ]);
      expect(r.best?.relic, Relic.warDrum);
      expect(pusakaWinLine(PusakaReport(1, 0, lines: [(relic: Relic.lootersPouch, type: 'archer', stars: 1, uses: 9, worth: 5000)])), isNull);
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
      testWidgets('each of the ten fits ${size.width.round()}x${size.height.round()}: the cards and the buttons on the '
          'screen, apart', (tester) async {
        final b = await boot(tester, size);
        final g = b.state = Game(Random(1)).boardRules()
          ..armyMax = null
          ..gold = 200000
          ..wave = 86
          ..chestsGiven = 1;
        for (final type in ['soldier', 'archer', 'knight']) {
          expect(g.autoPlace(type), isTrue);
        }
        // The ten three a chest, the longest together (Spell Cutter's three lines); the last with today's longest.
        final hands = [
          [Relic.spellCutter, Relic.bleedingEdge, Relic.riposte],
          [Relic.shatterShard, Relic.painCrystal, Relic.watchShield],
          [Relic.boneBuckler, Relic.momentum, Relic.manaLeech],
          [Relic.lootersPouch, Relic.grail, Relic.godThunder],
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
