// Batch L-1P (decisions-log 205; catalog-design §3.1 and §5.2, catalog-bayangan-v2 §4): the first ten new Langka
// Artifacts as catalog rows on the engine's Fx. Each one's effect at ★1, ★2 and ★3 and with Carve steps (the number
// [pusakaAt] gives), its words, its row (rarity, Carve role, the atlas's icon, epithet, counter, chest-only), the chest
// offering it, the save keeping an owned one, what it gives the Shadows' needs, its battle-log line, and its card on
// the Boss Chest at 915x412 and 1266x713. The rules every row keeps (band, key, icon, counter in its pool):
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

/// Lets [foe] strike once now (then it stands again).
void strikeBy(Game g, Unit foe) {
  foe
    ..busyUntil = double.negativeInfinity
    ..cd = 0;
  g.tick(0.05);
  foe.busyUntil = hold;
}

/// What troop [u]'s next normal attack takes off [foe] (its cooldown over now).
double blow(Game g, Unit u, Unit foe) {
  final before = foe.hp;
  u.cd = 0;
  g.tick(0.05);
  return before - foe.hp;
}

/// A knight (or a troop of [type]) standing at (2, 3) with [relic] bound to its type at [stars] and [ukir] Carve steps
/// (none: nothing bound), and an orc of [tier] next to it with HP to spare that strikes only when told ([strikeBy]).
(Game, Unit, Unit) duel(Relic? relic, {int stars = 1, int ukir = 0, Tier tier = Tier.normal, String type = 'knight'}) {
  final g = plain(Random(2));
  final k = placeNow(g, type, 2, 3);
  if (relic != null) g.givePusaka(relic, type: type, stars: stars, ukir: ukir);
  final orc = foeAt(g, 'orc', k.pos + const Point(12, 0), tier)
    ..maxHp = 1000000
    ..hp = 1e6;
  return (g, k, orc);
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
  group('the rows', () {
    test('ten Langka appended after the oaths (save keys), chest-only, in the game; names, Carve roles, epithets, the '
        "atlas's icons and catalog-bayangan-v2's counters", () {
      expect(Relic.values.skipWhile((r) => r != Relic.alliance).skip(1).take(batch.length).toList(), batch);
      expect({for (final r in batch) r: relicNames[r]}, {
        Relic.titanBane: 'Titan Bane',
        Relic.finishingBlade: 'Finishing Blade',
        Relic.firstCut: 'First Cut',
        Relic.shellCracker: 'Shell Cracker',
        Relic.twinFury: 'Twin Fury',
        Relic.steadyStance: 'Steady Stance',
        Relic.turtleShell: 'Turtle Shell',
        Relic.dullingMail: 'Dulling Mail',
        Relic.challengeLetter: 'Challenge Letter',
        Relic.snareCord: 'Snare Cord',
      });
      for (final r in batch) {
        final art = pusakaCatalog[r]!;
        expect((r.rarity, r.scope, r.store, art.live, r.oath, maxStars(r)), (Rarity.langka, RelicScope.type, false, true, false, starMax), reason: '$r');
        expect(art.icon.sheet, 'artifact_icons.png', reason: '$r');
        expect((art.icon.x, art.icon.y, art.icon.tint), (artifactIcon(r.name).x, artifactIcon(r.name).y, null), reason: '$r');
        expect(art.fx, hasLength(1), reason: '$r');
      }
      expect(liveL1P, isTrue);
      expect({for (final r in batch) r: pusakaCatalog[r]!.role}, {
        Relic.titanBane: UkirRole.attack,
        Relic.finishingBlade: UkirRole.attack,
        Relic.firstCut: UkirRole.attack,
        Relic.shellCracker: UkirRole.attack,
        Relic.twinFury: UkirRole.attack,
        Relic.steadyStance: UkirRole.guard,
        Relic.turtleShell: UkirRole.guard,
        Relic.dullingMail: UkirRole.guard,
        Relic.challengeLetter: UkirRole.guard,
        Relic.snareCord: UkirRole.attack, // utility (attack)
      });
      expect({for (final r in batch) r: buildEpithets[r]}, {
        Relic.titanBane: 'Fearless',
        Relic.finishingBlade: 'Ruthless',
        Relic.firstCut: 'Keen',
        Relic.shellCracker: 'Breaching',
        Relic.twinFury: 'Furious',
        Relic.steadyStance: 'Steady',
        Relic.turtleShell: 'Turtle',
        Relic.dullingMail: 'Dulling',
        Relic.challengeLetter: 'Bold',
        Relic.snareCord: 'Snaring',
      });
      expect(buildEpithets.values.toSet().length, buildEpithets.length, reason: 'an epithet twice');
      expect({for (final r in batch) r: pusakaCatalog[r]!.counter}, {
        Relic.titanBane: OmenKind.deflect,
        Relic.finishingBlade: OmenKind.stubborn,
        Relic.firstCut: OmenKind.brace,
        Relic.shellCracker: OmenKind.hardShell,
        Relic.twinFury: OmenKind.thorns,
        Relic.steadyStance: OmenKind.sunder,
        Relic.turtleShell: OmenKind.sunder,
        Relic.dullingMail: OmenKind.unshaken,
        Relic.challengeLetter: OmenKind.defiant,
        Relic.snareCord: OmenKind.unshaken,
      });
      for (final r in batch) {
        expect(pusakaCatalog[r]!.counter.answers, contains(r), reason: '$r');
      }
      final g = Game()..wave = storeFrom;
      expect([for (final r in batch) g.basePrice(r)], everyElement(langkaPrice), reason: 'sold back from the Vault like the four');
      expect(storeGoods.where(batch.contains), isEmpty, reason: 'never in the Shop');
    });

    test('each leads with its own Fx (no other row shares its key), and the band holds: the conditions earn a quarter, '
        "the boss doesn't", () {
      final keys = {for (final MapEntry(key: r, value: a) in pusakaCatalog.entries) if (a.fx.isNotEmpty) a.fx.first.key: r};
      for (final r in batch) {
        expect(keys[pusakaCatalog[r]!.fx.first.key], r, reason: '$r');
      }
      expect(hardConds.contains(pusakaCatalog[Relic.titanBane]!.fx.first.when), isTrue);
      for (final r in [Relic.finishingBlade, Relic.firstCut, Relic.shellCracker, Relic.steadyStance, Relic.turtleShell]) {
        expect(hardConds.contains(pusakaCatalog[r]!.fx.first.when), isFalse, reason: '$r');
      }
    });

    test('their words at ★1, from the constants: the card and tooltip lines, and the Bag row\'s gist', () {
      final g = Game();
      expect({for (final r in batch) r: g.relicEffect(r, stars: 1)}, {
        Relic.titanBane: ['+15% damage to the boss and mini boss'],
        Relic.finishingBlade: ['+20% damage to monsters under 30% HP'],
        Relic.firstCut: ['+20% damage to monsters over 90% HP'],
        Relic.shellCracker: ['+20% damage to a monster with a shield'],
        Relic.twinFury: ['With Fury: its x2 hit', 'does x1.2 more'],
        Relic.steadyStance: ['Over 80% HP: -18% damage taken'],
        Relic.turtleShell: ['Under 40% HP: -18% damage taken'],
        Relic.dullingMail: ['When hit: that monster deals', '-10% damage for 2s (boss -5%)'],
        Relic.challengeLetter: ['Every 4th up-close hit: the monster', 'must fight it for 2s (boss 1s)'],
        Relic.snareCord: ['Every 4th hit: the monster', '-20% walk speed for 2s (boss -10%)'],
      });
      expect({for (final r in batch) r: pusakaGist(r, 1)}, {
        Relic.titanBane: '+15% vs boss',
        Relic.finishingBlade: '+20% under 30% HP',
        Relic.firstCut: '+20% over 90% HP',
        Relic.shellCracker: '+20% vs shields',
        Relic.twinFury: 'Fury hit x1.2',
        Relic.steadyStance: 'Over 80%: -18% taken',
        Relic.turtleShell: 'Under 40%: -18% taken',
        Relic.dullingMail: 'Attacker -10% damage',
        Relic.challengeLetter: 'Every 4th: must fight it 2s',
        Relic.snareCord: '-20% speed every 4th',
      });
      // ★3 and a Carve step move the numbers the words show.
      expect(g.relicEffect(Relic.titanBane, stars: 3), ['+${((titanBaneK[2] - 1) * 100).round()}% damage to the boss and mini boss']);
      expect(g.relicEffect(Relic.turtleShell, stars: 2), ['Under 40% HP: -${(turtleShellK.cut[1] * 100).round()}% damage taken']);
      expect(g.relicEffect(Relic.challengeLetter, stars: 3), ['Every 4th up-close hit: the monster', 'must fight it for 3s (boss 1.5s)']);
      expect(fxLines(Relic.firstCut, 1, ukir: 5), ['+${((pusakaAt(Relic.firstCut, 1, ukir: 5) - 1) * 100).round()}% damage to monsters over 90% HP']);
      expect(pusakaAt(Relic.firstCut, 1, ukir: 5), greaterThan(firstCutK.hit[0]));
    });

    test("the Bag's detail says the first sentence whole: a card line that goes on (a small letter, a sign) joins it, "
        'one with a capital is the next', () {
      final g = Game();
      expect({for (final r in [Relic.twinFury, Relic.dullingMail, Relic.challengeLetter, Relic.snareCord]) r: firstSentence(g.relicEffect(r, stars: 1))}, {
        Relic.twinFury: 'With Fury: its x2 hit does x1.2 more',
        Relic.dullingMail: 'When hit: that monster deals -10% damage for 2s (boss -5%)',
        Relic.challengeLetter: 'Every 4th up-close hit: the monster must fight it for 2s (boss 1s)',
        Relic.snareCord: 'Every 4th hit: the monster -20% walk speed for 2s (boss -10%)',
      });
      for (final r in batch.where((r) => g.relicEffect(r, stars: 1).length == 1)) {
        expect(firstSentence(g.relicEffect(r, stars: 1)), g.relicEffect(r, stars: 1).single, reason: '$r');
      }
      // The older rows: Mourning Bell's and God's Thunder's sentences were cut at the card's line; Void Eye's and the
      // Grail's second lines are sentences of their own.
      expect(firstSentence(g.relicEffect(Relic.mourningBell, stars: 1)), startsWith('When one dies, all troops within '));
      expect(firstSentence(g.relicEffect(Relic.godThunder, stars: 1)), contains(' more monsters within '));
      for (final r in [Relic.voidEye, Relic.grail, Relic.dragonHeart]) {
        expect(firstSentence(g.relicEffect(r, stars: 1)), g.relicEffect(r, stars: 1).first, reason: '$r');
      }
    });
  });

  group('the effects at ★1, ★2, ★3 and carved', () {
    for (final (stars, ukir) in _levels) {
      final at = '★$stars${ukir > 0 ? ' +$ukir' : ''}';

      test('$at: the table, or past it by the Carve steps', () {
        final i = stars - 1;
        for (final (r, table) in [
          (Relic.titanBane, titanBaneK),
          (Relic.finishingBlade, finishingBladeK.hit),
          (Relic.firstCut, firstCutK.hit),
          (Relic.shellCracker, shellCrackerK),
          (Relic.twinFury, twinFuryK),
          (Relic.steadyStance, steadyStanceK.cut),
          (Relic.turtleShell, turtleShellK.cut),
          (Relic.dullingMail, dullingMailK.dealt),
          (Relic.challengeLetter, challengeLetterK.time),
          (Relic.snareCord, snareCordK.slow),
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

      test('$at Titan Bane: blows on the boss and a mini boss do ×k, before their defence; a normal monster, none', () {
        final k = pusakaAt(Relic.titanBane, stars, ukir: ukir);
        for (final tier in [Tier.boss, Tier.miniBoss, Tier.normal]) {
          final (g, u, orc) = duel(Relic.titanBane, stars: stars, ukir: ukir, tier: tier);
          final want = tier == Tier.normal ? 1.0 : k;
          expect(blow(g, u, orc), closeTo(hitTaken(u.stats.dmg * want, orc.stats.def), 1e-9), reason: '$tier');
          expect(g.pusakaWorth[Relic.titanBane]?.worth ?? 0, closeTo(u.stats.dmg * (want - 1), 1e-9), reason: '$tier');
        }
      });

      test('$at Finishing Blade and First Cut: ×k under 30% (over 90%) of the monster\'s HP before the blow', () {
        for (final (r, below, line) in [(Relic.finishingBlade, true, finishingBladeK.below), (Relic.firstCut, false, firstCutK.above)]) {
          final k = pusakaAt(r, stars, ukir: ukir);
          for (final share in [0.1, 0.5, 0.95]) {
            final (g, u, orc) = duel(r, stars: stars, ukir: ukir);
            orc.hp = orc.maxHp * share;
            final on = below ? share < line : share > line;
            expect(blow(g, u, orc), closeTo(hitTaken(u.stats.dmg * (on ? k : 1), orc.stats.def), 1e-9), reason: '$r at $share');
          }
        }
      });

      test('$at Shell Cracker: ×k on a monster with a shield (a shot ward, a guard), none without', () {
        final k = pusakaAt(Relic.shellCracker, stars, ukir: ukir);
        final (g, u, orc) = duel(Relic.shellCracker, stars: stars, ukir: ukir);
        expect(blow(g, u, orc), closeTo(hitTaken(u.stats.dmg, orc.stats.def), 1e-9));
        g.addEffect(orc, Status.shotWard, 100, k: 1); // a ward against shots: no change on a melee blow but its own
        expect(g.shielded(orc), isTrue);
        expect(blow(g, u, orc), closeTo(hitTaken(u.stats.dmg * k, orc.stats.def), 1e-9));
        expect(g.pusakaWorth[Relic.shellCracker]!.uses, 1);
      });

      test('$at Twin Fury: a troop wearing a fury does ×k more on the fury\'s x2 attack; without one, nothing', () {
        final k = pusakaAt(Relic.twinFury, stars, ukir: ukir);
        final (g, u, orc) = duel(Relic.twinFury, stars: stars, ukir: ukir);
        final d = u.stats.dmg, def = orc.stats.def;
        expect([for (var n = 0; n < 3; n++) blow(g, u, orc)], everyElement(closeTo(hitTaken(d, def), 1e-9)));
        g.relicBag[Relic.fury] = 1;
        expect(g.useRelic(Relic.fury, u), isTrue);
        u.blows = 0;
        final hits = [for (var n = 0; n < 6; n++) blow(g, u, orc)];
        final fury = hitTaken(d * furyHit * k, def), plainHit = hitTaken(d, def);
        expect(hits, [
          closeTo(plainHit, 1e-9), closeTo(plainHit, 1e-9), closeTo(fury, 1e-9), //
          closeTo(plainHit, 1e-9), closeTo(plainHit, 1e-9), closeTo(fury, 1e-9),
        ]);
        expect(g.pusakaWorth[Relic.twinFury]!.uses, 2);
        expect(g.pusakaWorth[Relic.twinFury]!.worth, closeTo(2 * d * furyHit * (k - 1), 1e-9));
      });

      test('$at Steady Stance and Turtle Shell: -k damage taken over 80% (under 40%) of its HP, like Iron Banner', () {
        for (final (r, high) in [(Relic.steadyStance, true), (Relic.turtleShell, false)]) {
          final k = pusakaAt(r, stars, ukir: ukir);
          for (final share in [1.0, 0.6, 0.3]) {
            double took(Relic? with_) {
              final (g, u, orc) = duel(with_, stars: stars, ukir: ukir);
              u.hp = u.maxHp * share;
              final before = u.hp;
              strikeBy(g, orc);
              return before - u.hp;
            }

            final on = high ? share > steadyStanceK.above : share < turtleShellK.below;
            final base = took(null);
            expect(base, greaterThan(0));
            expect(took(r), closeTo(base * (on ? 1 - k : 1), 1e-9), reason: '$r at $share');
          }
        }
      });

      test('$at Dulling Mail: the monster that hurts it deals ×k for 2s (the boss half of the cut), at most once a second', () {
        final k = pusakaAt(Relic.dullingMail, stars, ukir: ukir), boss = pusakaAt(Relic.dullingMail, stars, ukir: ukir, boss: true);
        expect(boss, closeTo(1 - (1 - k) * dullingMailK.boss, 1e-9));
        for (final tier in [Tier.normal, Tier.boss]) {
          final (g, u, orc) = duel(Relic.dullingMail, stars: stars, ukir: ukir, tier: tier);
          u.hp = u.maxHp.toDouble();
          strikeBy(g, orc);
          final e = g.effectOn(orc, Status.weaken)!;
          expect((e.k, e.by), (tier == Tier.boss ? boss : k, u), reason: '$tier');
          expect(e.until - g.t, closeTo(dullingMailK.time, 0.051), reason: '$tier');
          // Within its 1 s cooldown another blow puts none on; after it, one does.
          orc.effects.remove(Status.weaken);
          strikeBy(g, orc);
          expect(g.effectOn(orc, Status.weaken), isNull, reason: '$tier: its cooldown');
          runFor(g, dullingMailK.cd);
          strikeBy(g, orc);
          expect(g.effectOn(orc, Status.weaken), isNotNull, reason: '$tier: after it');
          expect(g.pusakaWorth[Relic.dullingMail]!.uses, 2);
        }
      });

      test('$at Challenge Letter: every 4th attack of a melee holder makes the monster fight it for k s (the boss half)', () {
        final k = pusakaAt(Relic.challengeLetter, stars, ukir: ukir), boss = pusakaAt(Relic.challengeLetter, stars, ukir: ukir, boss: true);
        expect(boss, closeTo(k * challengeLetterK.boss, 1e-9));
        for (final tier in [Tier.normal, Tier.boss]) {
          final (g, u, orc) = duel(Relic.challengeLetter, stars: stars, ukir: ukir, tier: tier);
          for (var n = 1; n <= 3; n++) {
            blow(g, u, orc);
            expect(g.effectOn(orc, Status.taunt), isNull, reason: '$tier: attack $n');
          }
          blow(g, u, orc);
          final e = g.effectOn(orc, Status.taunt)!;
          expect(e.by, u);
          expect(e.until - g.t, closeTo(tier == Tier.boss ? boss : k, 0.051), reason: '$tier');
          expect(g.pusakaWorth[Relic.challengeLetter]!.uses, 1);
        }
        // On a type that shoots it does nothing: the holder must fight up close.
        final (g, u, orc) = duel(Relic.challengeLetter, stars: stars, ukir: ukir, type: 'archer');
        for (var n = 0; n < 8; n++) {
          u.cd = 0;
          g.tick(0.05);
        }
        expect(g.effectOn(orc, Status.taunt), isNull);
      });

      test('$at Snare Cord: every 4th attack slows the monster to ×k for 2s (the boss half of the slow)', () {
        final k = pusakaAt(Relic.snareCord, stars, ukir: ukir), boss = pusakaAt(Relic.snareCord, stars, ukir: ukir, boss: true);
        expect(boss, closeTo(1 - (1 - k) * snareCordK.boss, 1e-9));
        for (final tier in [Tier.normal, Tier.boss]) {
          final (g, u, orc) = duel(Relic.snareCord, stars: stars, ukir: ukir, tier: tier);
          for (var n = 1; n <= 3; n++) {
            blow(g, u, orc);
          }
          expect(g.effectOn(orc, Status.slow), isNull, reason: '$tier');
          blow(g, u, orc);
          final e = g.effectOn(orc, Status.slow)!;
          expect(e.k, tier == Tier.boss ? boss : k, reason: '$tier');
          expect(e.until - g.t, closeTo(snareCordK.time, 0.051), reason: '$tier');
          expect(g.pusakaWorth[Relic.snareCord]!.uses, 1);
        }
      });
    }
  });

  group('the counters (batch L-1B\'s Shadows) answer them', () {
    tearDown(() => omensOn = omensDefault);

    test('Sunder weakens Steady Stance\'s cut; Unshaken shortens Snare Cord\'s slow and Dulling Mail\'s weaken; Defiant '
        "reads Challenge Letter's taunt", () {
      omensOn = true;
      // Sunder: the cut ×(1 − its share).
      double took(List<OmenKind> omens) {
        final (g, u, orc) = duel(Relic.steadyStance);
        g.omens.addAll(omens);
        u.hp = u.maxHp.toDouble();
        final before = u.hp;
        strikeBy(g, orc);
        return before - u.hp;
      }

      final (g0, _, _) = duel(null);
      final base = took([]), sundered = took([OmenKind.sunder, OmenKind.sunder]);
      final keep = 1 - (g0..omens.addAll([OmenKind.sunder, OmenKind.sunder])).omenK(OmenKind.sunder);
      expect(sundered, closeTo(base / (1 - steadyStanceK.cut[0]) * (1 - steadyStanceK.cut[0] * keep), 1e-9));
      // Unshaken: the slow and the weaken end sooner.
      final (g, u, orc) = duel(Relic.snareCord);
      g.omens.addAll([OmenKind.unshaken, OmenKind.unshaken]);
      for (var n = 0; n < 4; n++) {
        blow(g, u, orc);
      }
      expect(g.effectOn(orc, Status.slow)!.until - g.t, closeTo(snareCordK.time * (1 - g.omenK(OmenKind.unshaken)), 0.051));
      // Defiant: the monster Challenge Letter taunted deals its holder more.
      final (h, k, o) = duel(Relic.challengeLetter);
      for (var n = 0; n < 4; n++) {
        blow(h, k, o);
      }
      expect(h.effectOn(o, Status.taunt)!.by, k);
      double hit(Game x, Unit at, Unit by) {
        at.hp = at.maxHp.toDouble();
        final before = at.hp;
        strikeBy(x, by);
        return before - at.hp;
      }

      final calm = hit(h, k, o);
      h.omens.addAll([OmenKind.defiant, OmenKind.defiant]);
      expect(hit(h, k, o), greaterThan(calm), reason: 'Defiant: it hits its challenger harder');
    });
  });

  group('the chest, the save, the Shadows\' needs, the log', () {
    test('the chest deals each of the ten (the Langka pool is the four, the ten and the later batches\'), binds it by its '
        'default rule, and keeps a ★3 one off its cards', () {
      final langka = [for (final r in Relic.values) if (r.pusaka && r.rarity == Rarity.langka && pusakaCatalog[r]!.live) r];
      expect(langka.take(4 + batch.length), [Relic.ironBanner, Relic.bloodFang, Relic.warDrum, Relic.mourningBell, ...batch]);
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
      // Challenge Letter goes to the melee only.
      expect(pusakaPrefs[Relic.challengeLetter], everyElement(predicate((String t) => troopTypes[t]!.melee)));
      for (final r in batch) {
        expect(pusakaPrefs[r], isNotEmpty, reason: '$r');
      }
    });

    test('the save keeps an owned one (its type, stars and Carve steps); a save from before the batch loads with none', () {
      final g = plain(Random(1));
      placeNow(g, 'knight', 2, 3);
      g
        ..givePusaka(Relic.challengeLetter, type: 'knight', stars: 2, ukir: 3)
        ..givePusaka(Relic.titanBane, stars: 3);
      final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
      final back = Game.fromJson(j);
      expect((back.pusaka[Relic.challengeLetter]!.type, back.pusaka[Relic.challengeLetter]!.stars, back.pusaka[Relic.challengeLetter]!.ukir),
          ('knight', 2, 3));
      expect((back.pusaka[Relic.titanBane]!.type, back.pusaka[Relic.titanBane]!.stars), (null, 3));
      expect(back.gudang, contains(Relic.titanBane));
      final w89 = Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>);
      expect(w89.pusaka.keys.where(batch.contains), isEmpty, reason: "the owner's save holds none");
    });

    test("the Shadows' needs: Snare Cord slows and works every few hits, Dulling Mail weakens on its own cooldown, "
        "Challenge Letter taunts only on a melee type, Twin Fury's every is the fury's", () {
      final g = plain(Random(1));
      placeNow(g, 'knight', 2, 3);
      placeNow(g, 'archer', 1, 3);
      placeNow(g, 'soldier', 2, 5);
      expect(g.omenMet.intersection({OmenNeed.slow, OmenNeed.weaken, OmenNeed.taunt, OmenNeed.everyFx, OmenNeed.cdFx}), isEmpty);
      g.givePusaka(Relic.twinFury, type: 'knight');
      expect(g.omenMet.contains(OmenNeed.everyFx), isFalse, reason: "Twin Fury's every is the worn fury's");
      g.givePusaka(Relic.challengeLetter, type: 'archer');
      expect(g.omenMet.contains(OmenNeed.taunt), isFalse, reason: 'on a type that shoots');
      g.givePusaka(Relic.challengeLetter, type: 'soldier');
      expect(g.omenMet, containsAll([OmenNeed.taunt, OmenNeed.everyFx]));
      g.givePusaka(Relic.dullingMail, type: 'archer');
      expect(g.omenMet, containsAll([OmenNeed.weaken, OmenNeed.cdFx]));
      g.givePusaka(Relic.snareCord, type: 'knight');
      expect(g.omenMet, contains(OmenNeed.slow));
      expect(pusakaCatalog[Relic.twinFury]!.fx.first.furyBeat, isTrue);
    });

    test("the battle log's report line: a status one counts the times it took hold; a power one its damage", () {
      final (g, u, orc) = duel(Relic.snareCord);
      for (var n = 0; n < 8; n++) {
        blow(g, u, orc);
      }
      final (h, v, o) = duel(Relic.titanBane, tier: Tier.boss);
      blow(h, v, o);
      String line(Game x, Relic r) => pusakaReportLines(PusakaReport(x.wave, x.t, lines: [
            (relic: r, type: 'knight', stars: 1, uses: x.pusakaWorth[r]!.uses, worth: x.pusakaWorth[r]!.worth),
          ])).single;
      expect(line(g, Relic.snareCord), 'Snare Cord (Knight): slowed 2 times');
      expect(line(h, Relic.titanBane), startsWith('Titan Bane (Knight): +'));
      expect(line(h, Relic.titanBane), endsWith(' damage'));
      expect(fxFamily(Relic.snareCord), FxFamily.applied);
      expect(fxFamily(Relic.titanBane), FxFamily.added);
      expect(fxFamily(Relic.steadyStance), FxFamily.keptOff);
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
        // The ten three a chest, the two-line ones together; the last with today's longest, the Grail's.
        final hands = [
          [Relic.dullingMail, Relic.challengeLetter, Relic.snareCord],
          [Relic.twinFury, Relic.titanBane, Relic.shellCracker],
          [Relic.finishingBlade, Relic.firstCut, Relic.steadyStance],
          [Relic.turtleShell, Relic.grail, Relic.godThunder],
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
