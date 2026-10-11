// The Bayangan v2 rules (catalog step 0j, decisions-log 192, lib/omen.dart; docs/units-and-combat.md "Bayangan on the
// field", docs/loot-items-relics.md "Bayangan"): the taken floor (0.5) and the dealt cap (1.6) at their edges, an omen
// might counted and a monster skill's not, an omen guard inside the floor and a skill's after it; Unholy Ward ignores an
// omen absorb; omenPlace's troop-side cap and its overflow; the acting faces (one draw a card, the same faces when every
// kind acts, the tilt's counter exempt) and what the army meets; the HUD numbers at E8 equal to what the hooks read.
// With omens off none of it acts.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

const armor = OmenKind.armor, haste = OmenKind.haste, mend = OmenKind.mend, wound = OmenKind.wound;
const thorns = OmenKind.thorns, shield = OmenKind.shield, guard = OmenKind.guard;

/// [n] levels of [kind].
List<OmenKind> levels(OmenKind kind, int n) => List.filled(n, kind);

/// Dice that give [rolls] in turn (the last one again once they run out) and count their draws.
class _Seq implements Random {
  _Seq(this.rolls);
  final List<double> rolls;
  int draws = 0;

  @override
  double nextDouble() => rolls[min(draws++, rolls.length - 1)];

  @override
  int nextInt(int max) {
    draws++;
    return 0;
  }

  @override
  bool nextBool() {
    draws++;
    return false;
  }
}

/// A [bareGame] with no skills of any kind (nor the monsters'), the enemy holding [omens].
Game plain({List<OmenKind> omens = const []}) => bareGame(Random(2))
  ..slots = Random(3)
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false
  ..monsterSkills = false
  ..omens.addAll(omens);

/// What a blow took off [u]: [by] strikes it once now.
double blowOn(Game g, Unit u, Unit by) {
  final hp = u.hp;
  by
    ..busyUntil = double.negativeInfinity
    ..cd = 0;
  u.busyUntil = hold;
  g.tick(0.05);
  by.busyUntil = hold;
  return hp - u.hp;
}

/// A knight and an orc beside it, both standing; the enemy holding [omens] at the Beban [factor].
(Game, Unit, Unit) duel({List<OmenKind> omens = const [], double factor = 1}) {
  final g = plain(omens: omens)..omenFactor = factor;
  final k = placeNow(g, 'knight', 2, 3)..busyUntil = hold;
  final orc = foeAt(g, 'orc', k.pos + const Point(12, 0));
  return (g, k, orc);
}

/// Every item [type]'s awakening recipe asks for, [level] times over: the type at awakening [level].
List<Item> recipe(String type, int level) => [
      for (final MapEntry(key: item, value: n) in awakenRecipe[type]!.entries)
        for (var i = 0; i < n * level; i++) item,
    ];

void main() {
  tearDown(() => omensOn = false);

  group('the combined caps', () {
    setUp(() => omensOn = true);

    test('the taken floor: Armor at its max (×0.6) stays above it; with an omen guard the product stops at 0.5, the edge '
        'exactly; a monster skill\'s guard is not counted and cuts after it', () {
      expect([omenTakenFloor, omenDealtMost], [0.5, 1.6]);
      final (b, bk, borc) = duel();
      final base = blowOn(b, borc, bk);
      expect(base, greaterThan(0));
      final (g, k, orc) = duel(omens: levels(armor, 4), factor: 2);
      expect(g.omenK(armor), 0.4, reason: 'E8: its max');
      expect(blowOn(g, orc, k), closeTo(base * 0.6, 1e-9), reason: "Armor's 0.6 is above the floor");
      for (final (cut, want) in [(0.1, 0.54), (1 / 6, 0.5), (0.3, 0.5), (0.9, 0.5)]) {
        final (g, k, orc) = duel(omens: levels(armor, 4), factor: 2);
        orc
          ..guardUntil = 1e9
          ..guardCut = cut
          ..guardOmen = true;
        expect(blowOn(g, orc, k), closeTo(base * want, 1e-9), reason: 'an omen guard of $cut');
      }
      final (s, sk, sorc) = duel(omens: levels(armor, 4), factor: 2);
      sorc
        ..guardUntil = 1e9
        ..guardCut = 0.3;
      expect(blowOn(s, sorc, sk), closeTo(base * 0.6 * 0.7, 1e-9), reason: "a monster skill's guard: 0.42, under the floor");
    });

    test("the dealt cap: an omen might counts, and the blow stops at 1.6 × the blow without it, the edge exactly; a "
        "monster skill's might is not counted", () {
      double hit(double k, {required bool omen}) {
        final (g, kn, orc) = duel();
        g.addEffect(orc, Status.might, 100, k: k, omen: omen);
        return blowOn(g, kn, orc);
      }

      final plain16 = hit(1.6, omen: false);
      expect(hit(1.3, omen: true), hit(1.3, omen: false), reason: 'under the cap, as any might');
      expect(hit(1.6, omen: true), closeTo(plain16, 1e-9), reason: 'the edge');
      expect(hit(2.5, omen: true), closeTo(plain16, 1e-9), reason: 'capped at 1.6 ×');
      expect(hit(2.5, omen: false), greaterThan(plain16), reason: "a monster skill's might is not capped");
      expect(hit(2.5, omen: true), lessThan(hit(2.5, omen: false)));
    });

    test('Unholy Ward ignores an omen absorb (it still lands when the stronger), never a skill\'s', () {
      final g = plain();
      final u = foeAt(g, 'orc', const Point(300, 60))..winding = MonsterSkill.unholyWard;
      final o = foeAt(g, 'orc', const Point(304, 60))
        ..hp = 10
        ..hurtBefore = g.t;
      expect(g.windTargetsOf(u), [o]);
      g.addEffect(o, Status.absorb, 5, k: 10, omen: true);
      expect(g.windTargetsOf(u), [o], reason: 'a Bayangan shield: still wardable');
      g.addEffect(o, Status.absorb, 5, k: 20); // a stronger ward replaces it
      expect(g.effectOn(o, Status.absorb)!.omen, isFalse);
      expect(g.windTargetsOf(u), isEmpty, reason: 'a ward on it already');
    });
  });

  group('the troop-side cap', () {
    test('Wound, Sunder, Spell Tax, Off Beat, Drag, Scar, Fade, Trickle, Toll, Rust and Executioner are troop-side; at most '
        '4 held, past it a new troop-side kind overflows along the pool, as past omenCap', () {
      expect([for (final k in OmenKind.values) if (k.troopSide) k], [
        wound, OmenKind.sunder, OmenKind.spellTax, OmenKind.offBeat, OmenKind.drag, OmenKind.scar, OmenKind.fade, //
        OmenKind.trickle, OmenKind.toll, OmenKind.rust, OmenKind.executioner, OmenKind.manaBurn,
      ]);
      expect(omenTroopRulesMax, 4);
      final pool = OmenKind.values.take(7).toList(); // today's seven, a pool of their own (omenPlace takes any)
      expect(omenPlace([], wound, pool, 2), [wound, wound]);
      expect(omenPlace([], wound, pool, 2, troopMax: 0), [shield, shield], reason: 'no room: the next kind in pool order');
      expect(omenPlace([wound], wound, pool, 2, troopMax: 1), [wound, wound], reason: 'held: room under its cap');
      expect(omenPlace(levels(wound, 3), wound, pool, 3, troopMax: 1), [wound, shield, shield], reason: 'then omenCap');
      expect(omenPlace([], armor, pool, 2, troopMax: 0), [armor, armor], reason: 'a monster-side kind is never held back');
      expect(omenPlace([...levels(shield, 4), ...levels(guard, 4)], wound, pool, 3, troopMax: 0), [armor, armor, armor],
          reason: 'the overflow wraps round the pool');
      // With the kinds cap too: a troop-side kind needs room under both.
      expect(omenPlace([armor, haste], wound, pool, 1, kindsMax: 2), [armor]);
    });
  });

  group('the acting faces', () {
    setUp(() => omensOn = true);

    test("today's seven always act: they need nothing, and every need a live kind names is built", () {
      for (final k in omenPool(Rarity.epik).take(7)) { // today's seven
        expect(k.needs, isEmpty, reason: '$k');
        expect(omenCanAct(k, const {}), isTrue, reason: '$k');
      }
      for (final k in omenOrder) {
        for (final n in k.needs) {
          expect(n.built, isTrue, reason: '$k needs $n');
        }
      }
      expect([for (final n in OmenNeed.values) if (!n.built) n], isEmpty, reason: "spiteMark came with Ember Brand (batch E-2P)");
    });

    test('the filter keeps the single draw: every kind acting gives the faces of no filter; a kind that can\'t act is '
        'never drawn but by the tilt (the counter is exempt); none acting: the whole pool', () {
      for (final r in Relic.values.where((r) => r.pusaka)) {
        for (final type in [null, 'priest', 'archer']) {
          for (var i = 0; i < 900; i++) {
            final u = i / 900;
            expect(omenFace(r, type, u, (_) => true), omenFace(r, type, u), reason: '$r $type $u');
          }
        }
      }
      bool acts(OmenKind k) => k != armor && k != haste; // Iron Banner's counter is Haste
      final n = <OmenKind, int>{};
      for (var i = 0; i < 9000; i++) {
        final u = (i + 0.5) / 9000, f = omenFace(Relic.ironBanner, null, u, acts)!;
        if (u < omenTilt) {
          expect(f, haste, reason: 'the tilt');
        } else {
          n[f] = (n[f] ?? 0) + 1;
        }
      }
      final acting = omenPool(Rarity.langka).where(acts).toList();
      expect(n.keys.toSet(), acting.toSet());
      for (final c in n.values) {
        expect(c / 7000, closeTo(1 / acting.length, 0.01), reason: 'evenly over the acting ones');
      }
      // A counter outside the acting pool's filter still has its tilt; none acting spreads over the whole pool.
      for (final u in [0.0, 0.3, 0.6, 0.99]) {
        expect(omenFace(Relic.warDrum, null, u, (_) => false), omenFace(Relic.warDrum, null, u));
      }
    });

    test("a roll draws one die a card whatever acts, and its faces are omenFace's over the kinds that act on the army", () {
      final dice = _Seq([0.05, 0.5, 0.95]);
      final g = bareGame(Random(1))
        ..offers = true
        ..wave = 29
        ..chestsGiven = 1
        ..draft = Random(7)
        ..omenDice = dice;
      placeNow(g, 'priest', 1, 1);
      g.giveChests(1);
      expect(dice.draws, draftCards);
      final c = g.chest!;
      expect(c.omens, [
        for (var i = 0; i < draftCards; i++)
          if (c.cards![i] case final r?) omenFace(r, g.cardType(r), dice.rolls[i], (k) => omenCanAct(k, g.omenMet)) else null,
      ]);
    });

    test('what the army meets: its living troops, Heroes, skills, awakening, small relics, oaths and bound Fx', () {
      final g = bareGame(Random(1));
      expect(g.omenMet, isEmpty, reason: 'no army');
      final p = placeNow(g, 'priest', 1, 1);
      expect(g.omenMet, {OmenNeed.mpSkill, OmenNeed.healer, OmenNeed.heal});
      p.gone = true;
      expect(g.omenMet, isEmpty, reason: 'only the living count');
      placeNow(g, 'armored_axeman', 2, 1);
      expect(g.omenMet, {OmenNeed.mpSkill, OmenNeed.stun, OmenNeed.extraHit}, reason: 'Crushing Blow, its splash');
      g.skills = false;
      expect(g.omenMet, {OmenNeed.mpSkill, OmenNeed.extraHit});
      final k = placeNow(g, 'knight', 3, 1)..relics.add(Relic.thorns);
      expect(g.omenMet, containsAll([OmenNeed.smallRelic, OmenNeed.hitBack]));
      k
        ..hero = true
        ..heroSkill = HeroSkill.duel;
      expect(g.omenMet, containsAll([OmenNeed.hero, OmenNeed.taunt]));
      g.heroSkills = false;
      expect(g.omenMet.contains(OmenNeed.taunt), isFalse, reason: 'no Hero skills: no Duel');
      expect(g.omenMet.contains(OmenNeed.hero), isTrue);
      g.upgrades['lancer'] = recipe('lancer', 1);
      placeNow(g, 'lancer', 4, 1);
      expect(g.omenMet, containsAll([OmenNeed.hold, OmenNeed.stun]), reason: 'Impale');
      g.awakenSkills = false;
      expect(g.omenMet.contains(OmenNeed.hold), isFalse);
      g.givePusaka(Relic.voidEye, type: 'archer');
      expect(g.omenMet.contains(OmenNeed.mark), isFalse, reason: 'no archer alive');
      placeNow(g, 'archer', 5, 1);
      expect(g.omenMet.contains(OmenNeed.mark), isTrue);
      expect(g.omenMet.contains(OmenNeed.everyFx), isFalse);
      g.givePusaka(Relic.warDrum, type: 'knight');
      expect(g.omenMet.contains(OmenNeed.everyFx), isTrue, reason: "War Drum's every 3rd");
      g
        ..givePusaka(Relic.godThunder, type: 'lancer')
        ..givePusaka(Relic.oathOfOne);
      expect(g.omenMet, containsAll([OmenNeed.oath]));
      final s = placeNow(g, 'soldier', 0, 2);
      g.givePusaka(Relic.dragonHeart, type: 'soldier');
      expect(s.alive, isTrue);
      expect(g.omenMet, containsAll([OmenNeed.heal, OmenNeed.extraHit]), reason: "Dragon Heart's regen, God's Thunder's leap");
      expect(g.omenMet.intersection({OmenNeed.spiteMark, OmenNeed.cdFx, OmenNeed.troopShield}), isEmpty, reason: 'no source today');
    });
  });

  group('the HUD numbers', () {
    setUp(() => omensOn = true);

    test('at E8 every kind shows its capped share, the one its hooks read; Escort counts by L; {who} only Vultures\' (batch '
        "G-2B: its rank words by L), and {cap} only Horde's, Adapt's and Spree's (batches G-1B, G-2B: the share × 3)", () {
      final g = plain(omens: [for (final k in OmenKind.values) ...levels(k, omenCap)])..omenFactor = 2;
      for (final k in OmenKind.values) {
        final v = omenShown(k, omenCap, 8);
        expect(v.x, min(k.k.max, k.k.perE * 8), reason: '$k');
        expect(v.x, g.omenK(k), reason: '$k: the hooks read the same');
        expect(omenShare(k, 8), v.x);
        final steps = {OmenKind.horde: omenHordeSteps, OmenKind.adapt: omenAdaptSteps, OmenKind.spree: omenSpreeKills}[k] ?? 0;
        expect((v.who, v.cap), (k == OmenKind.vultures ? 'Silver and gold' : '', v.x * steps), reason: '$k');
        if (k.byL.isEmpty) expect(v.n, 0, reason: '$k');
      }
      for (var l = 0; l <= omenCap; l++) {
        expect(omenShown(guard, l, 0).n, min(guard.k.max, (guard.k.perE * l).ceil()), reason: 'L$l');
      }
      expect(guard.byL, [1, 1, 2, 2]);
      expect(g.omenGuards, 2);
      expect(omenShown(armor, 0, 0), (x: 0.0, n: 0, who: '', cap: 0.0));
      expect(omenShown(armor, 1, 1).x, closeTo(0.05, 1e-12));
    });
  });

  group('off', () {
    setUp(() => omensOn = false);

    test('nothing of it acts: an omen might is any might, an omen guard any guard, and no face is drawn', () {
      double hit(double k, {required bool omen}) {
        final (g, kn, orc) = duel();
        g.addEffect(orc, Status.might, 100, k: k, omen: omen);
        return blowOn(g, kn, orc);
      }

      expect(hit(2.5, omen: true), hit(2.5, omen: false));
      double guarded({required bool omen}) {
        final (g, k, orc) = duel(omens: levels(armor, 4), factor: 2);
        orc
          ..guardUntil = 1e9
          ..guardCut = 0.9
          ..guardOmen = omen;
        return blowOn(g, orc, k);
      }

      expect(guarded(omen: true), guarded(omen: false));
      final dice = _Seq([0.5]);
      final g = bareGame(Random(1))
        ..offers = true
        ..wave = 29
        ..chestsGiven = 1
        ..omenDice = dice;
      g.giveChests(1);
      expect([dice.draws, g.chest!.omens], [0, null]);
    });
  });
}
