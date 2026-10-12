// Shadow batch G-1B (decisions-log 226, lib/omen.dart; catalog-bayangan-v2 §3.3; docs/units-and-combat.md "Bayangan on
// the field", docs/loot-items-relics.md "Bayangan"): the first ten Legenda kinds. Their rows (the Legenda pool alone,
// after today's seven, in the pool's order; numbers, icons, the troop-side flag, needs), the cap at E8 and the HUD number
// equal to it, and with omens on one test a kind: Scatter and Thornproof cut a troop's extra hits and hit backs, Blunt
// the part of a big blow on a silver, gold or boss monster, Horde every blow by the monsters alive (all four in the taken
// floor); Rust weakens the small relics; Veterans makes more of a wave silver on the same draw; Hardy gives silver and
// gold more HP; Unbowed shrugs off the first holds, stuns and hexes; Executioner bares a low troop of its shields, blocks
// and cuts; Spite raises the blows of a monster a Pusaka marked (in the dealt cap). The design's guards for Risk 2
// (Blunt: crowds and small hits untouched) and Risk 5 (Horde with Close Ranks, Captain and Hunker: the taken floor
// holds). With omens off none of it acts.
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

const scatter = OmenKind.scatter, thornproof = OmenKind.thornproof, rust = OmenKind.rust, veterans = OmenKind.veterans;
const hardy = OmenKind.hardy, unbowed = OmenKind.unbowed, executioner = OmenKind.executioner, spite = OmenKind.spite;
const blunt = OmenKind.blunt, horde = OmenKind.horde;

/// The batch, in the Legenda pool's order.
const batch = [scatter, thornproof, rust, veterans, hardy, unbowed, executioner, spite, blunt, horde];

/// Today's seven, whole in the Legenda pool until its cut-over.
const seven = [OmenKind.armor, OmenKind.haste, OmenKind.mend, OmenKind.thorns, OmenKind.wound, OmenKind.shield, OmenKind.guard];

/// [n] levels of [kind].
List<OmenKind> levels(OmenKind kind, int n) => List.filled(n, kind);

/// [kind] at its most levels: at the Beban factor 2 that is E8, past every kind's max.
List<OmenKind> top(OmenKind kind) => levels(kind, omenCap);

/// L1 at ×1, L4 at ×1 and L4 at ×2 (E8) of [kind]: the levels, the factor and the share each acts with.
List<(int, double, double)> steps(OmenKind kind) => [
      (1, 1.0, kind.k.perE),
      (4, 1.0, min(kind.k.max, kind.k.perE * 4)),
      (4, 2.0, kind.k.max),
    ];

/// A [bareGame] with no skills of any kind (nor the monsters'), the enemy holding [omens] at the Beban [factor].
Game plain({List<OmenKind> omens = const [], double factor = 1}) => bareGame(Random(2))
  ..slots = Random(3)
  ..loot = Random(9)
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false
  ..monsterSkills = false
  ..omens.addAll(omens)
  ..omenFactor = factor;

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

/// A knight and a monster of [tier] 12 px from it, both standing; the enemy holding [omens] at [factor]. The knight has
/// HP to spare (100000 max HP).
(Game, Unit, Unit) duel({List<OmenKind> omens = const [], double factor = 1, Tier tier = Tier.normal, String type = 'knight'}) {
  final g = plain(omens: omens, factor: factor);
  final k = placeNow(g, type, 2, 3)
    ..busyUntil = hold
    ..maxHp = 100000
    ..hp = 100000;
  final o = foeAt(g, 'orc', k.pos + const Point(12, 0), tier);
  return (g, k, o);
}

/// The monster's blow on the knight of a fresh [duel], both [set] up so.
double foeBlow({List<OmenKind> omens = const [], double factor = 1, void Function(Game, Unit k, Unit o)? set}) {
  final (g, k, o) = duel(omens: omens, factor: factor);
  set?.call(g, k, o);
  return blowOn(g, k, o);
}

/// The knight's blow on the monster of a fresh [duel] (the monster with HP to spare), both [set] up so.
double troopBlow({List<OmenKind> omens = const [], double factor = 1, Tier tier = Tier.normal, void Function(Game, Unit k, Unit o)? set}) {
  final (g, k, o) = duel(omens: omens, factor: factor, tier: tier);
  o
    ..maxHp = 100000
    ..hp = 100000;
  set?.call(g, k, o);
  return blowOn(g, o, k);
}

/// A PNG's width and height, from its header.
(int, int) pngSize(File f) {
  final b = f.readAsBytesSync();
  int at(int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
  return (at(16), at(20));
}

/// A blow's damage [v] to within float noise.
Matcher closeToBlow(double v) => closeTo(v, 1e-9);

/// [n] monsters on the field far from the fight (entered, standing), for Horde's count.
void crowd(Game g, int n) {
  for (var i = 0; i < n; i++) {
    foeAt(g, 'orc', Point(400.0 + 6 * (i % 10), 20.0 + 8 * (i ~/ 10)));
  }
}

/// The wave [wave]'s queue of a [plain] game holding [omens], and the next draw of its rng after it was made.
(List<(String, Tier)>, double) queueOf(int wave, List<OmenKind> omens) {
  final g = plain(omens: omens)..wave = wave - 1;
  g.startWave();
  return ([...g.queue], g.rng.nextDouble());
}

void main() {
  tearDown(() => omensOn = omensDefault);

  group('the rows', () {
    test("the ten sit in the Legenda pool alone, after Barrier and Escort (today's seven until the Legenda cut-over), in "
        "the pool's order; the Langka and Epik pools as they were; their numbers, titles, constants, troop-side flag, needs "
        "and icons (an existing sheet's cell, each unique)", () {
      final pool = omenPool(Rarity.legenda);
      expect(pool.take(2), [OmenKind.shield, OmenKind.guard], reason: "the Legenda cut-over's two (omen_legenda_cutover_test.dart)");
      expect(pool.skip(2).where(batch.contains), batch,
          reason: "catalog-bayangan-v2 §2's order, G-2B's ten and G-3B's seven among them (omen_legenda2_test.dart, omen_legenda3_test.dart)");
      expect([for (final k in batch) k.title],
          ['Scatter', 'Thornproof', 'Rust', 'Veterans', 'Hardy', 'Unbowed', 'Executioner', 'Spite', 'Blunt', 'Horde']);
      expect(omenPool(Rarity.langka), hasLength(30));
      expect(omenPool(Rarity.epik), hasLength(30));
      expect([...omenPool(Rarity.langka), ...omenPool(Rarity.epik)].where(batch.contains), isEmpty);
      expect(omenOrder, OmenKind.values);
      expect(OmenKind.values.skip(OmenKind.values.indexOf(OmenKind.muster) + 1).where(batch.contains), batch, reason: 'after the Epik kinds');
      expect(OmenKind.values.take(OmenKind.values.indexOf(OmenKind.muster) + 1).where(batch.contains), isEmpty);
      for (final k in batch) {
        expect(k.tiers, {Rarity.legenda}, reason: '$k');
        expect(k.live, isTrue, reason: '$k');
        expect(k.debuff, isFalse, reason: '$k');
        expect(k.byL, k == unbowed ? [1, 1, 2, 2] : isEmpty, reason: '$k');
        expect(k.steps, k == horde ? omenHordeSteps : 0, reason: '$k');
        expect(k.who, isEmpty, reason: '$k');
      }
      // Their counters came with batch G-1P (pusaka_legenda1_test.dart), Hex Blade's with G-2 (pusaka_legenda2_test.dart) and
      // Grave Seal's with G-3 (pusaka_legenda3_test.dart).
      expect({for (final k in batch) k: k.answers}, {
        scatter: [Relic.wideBlows],
        thornproof: [Relic.mirror],
        rust: [Relic.relicAltar],
        veterans: [Relic.martyrFlame],
        hardy: [Relic.vowSilence, Relic.graveSeal],
        unbowed: [Relic.iceGrip, Relic.hexBlade],
        executioner: [Relic.ghostStep],
        spite: [Relic.vengeance],
        blunt: [Relic.loneWolf],
        horde: [Relic.champion],
      });
      expect({for (final k in batch) k: k.k}, {
        scatter: (perE: 0.08, max: 0.4),
        thornproof: (perE: 0.12, max: 0.6),
        rust: (perE: 0.1, max: 0.6),
        veterans: (perE: 0.03, max: 0.15),
        hardy: (perE: 0.05, max: 0.3),
        unbowed: (perE: 0.0, max: 0.0),
        executioner: (perE: 0.05, max: 0.2),
        spite: (perE: 0.06, max: 0.3),
        blunt: (perE: 0.06, max: 0.3),
        horde: (perE: 0.015, max: 0.06),
      });
      expect([omenBluntOver, omenHordePer, omenHordeSteps, tintRust], [20, 10, 3, 0xFFC8641E]);
      expect([for (final k in OmenKind.values) if (k.troopSide) k], [
        OmenKind.wound, OmenKind.sunder, OmenKind.spellTax, OmenKind.offBeat, OmenKind.drag, OmenKind.scar, OmenKind.fade, //
        OmenKind.trickle, OmenKind.toll, rust, executioner, OmenKind.manaBurn, // G-2B's one (omen_legenda2_test.dart)
      ], reason: 'Rust and Executioner are troop-side (catalog-bayangan-v2 §5.1)');
      expect({for (final k in batch) if (k.needs.isNotEmpty) k: k.needs}, {
        scatter: {OmenNeed.extraHit},
        thornproof: {OmenNeed.hitBack},
        rust: {OmenNeed.smallRelic},
        unbowed: {OmenNeed.hold, OmenNeed.stun, OmenNeed.hex},
        spite: {OmenNeed.spiteMark},
      });
      expect({for (final k in batch) k: (k.icon!.sheet, k.icon!.x, k.icon!.y, k.icon!.size, k.icon!.tint)}, {
        scatter: ('fx_hit_orc.png', 40, 0, 40, tintSilver),
        thornproof: ('relic_thorns.png', 0, 0, 32, tintSilver),
        rust: ('ui_icons.png', 48, 16, 16, tintRust),
        veterans: ('ui_icons.png', 80, 0, 16, null),
        hardy: ('ui_icons.png', 0, 0, 16, tintViolet),
        unbowed: ('ui_icons.png', 208, 80, 16, tintSteel),
        executioner: ('fx_hit_necromancer.png', 192, 0, 64, tintDarkRed),
        spite: ('fx_hit_werewolf.png', 64, 0, 64, tintRust),
        blunt: ('relic_dragonCrown.png', 0, 0, 32, tintSteel),
        horde: ('fx_hit_orc.png', 40, 0, 40, tintRed),
      });
      final seen = <(String, int, int, int?)>{};
      for (final k in OmenKind.values) {
        final icon = k.icon;
        if (icon == null) continue;
        final f = File('assets/images/${icon.sheet}');
        expect(f.existsSync(), isTrue, reason: '$k');
        final (w, h) = pngSize(f);
        expect(icon.x + icon.size <= w && icon.y + icon.size <= h, isTrue, reason: '$k: inside its sheet');
        expect(seen.add((icon.sheet, icon.x, icon.y, icon.tint)), isTrue, reason: '$k: its own (sheet, cell, tint)');
        if (icon.sheet == 'ui_icons.png') expect(meaningCells, isNot(contains((icon.x, icon.y))), reason: '$k: no cell that means something else');
      }
    });

    test('needs: Scatter acts on an army with an extra hit, Thornproof with a hit back, Rust with a worn small relic, '
        'Unbowed with a hold, stun or hex, Spite with Ember Brand bound; the other five always', () {
      final none = {scatter, thornproof, rust, unbowed, spite};
      final g = bareGame(Random(1))..skills = false;
      for (final kind in batch) {
        expect(omenCanAct(kind, g.omenMet), !none.contains(kind), reason: 'no army: $kind');
      }
      final k = placeNow(g, 'knight', 2, 3);
      for (final kind in none) {
        expect(omenCanAct(kind, g.omenMet), isFalse, reason: 'a plain knight: $kind');
      }
      placeNow(g, 'armored_axeman', 2, 4);
      expect(omenCanAct(scatter, g.omenMet), isTrue, reason: "an axeman's splash");
      expect(omenCanAct(unbowed, g.omenMet), isFalse, reason: 'its Crushing Blow only while the #10 skills are on');
      g.skills = true;
      expect(omenCanAct(unbowed, g.omenMet), isTrue, reason: 'Crushing Blow stuns');
      k.relics.add(Relic.guard);
      expect([omenCanAct(rust, g.omenMet), omenCanAct(thornproof, g.omenMet)], [true, false], reason: 'a worn guard');
      k.relics
        ..clear()
        ..add(Relic.thorns);
      expect([omenCanAct(rust, g.omenMet), omenCanAct(thornproof, g.omenMet)], [true, true], reason: 'worn thorns');
      expect(omenCanAct(spite, g.omenMet), isFalse);
      g.givePusaka(Relic.emberBrand, type: 'knight', stars: 1);
      expect(omenCanAct(spite, g.omenMet), isTrue, reason: 'Ember Brand bound');
      final h = bareGame(Random(1))..heroSkills = true;
      placeNow(h, 'wizard', 2, 3)
        ..hero = true
        ..heroSkill = HeroSkill.slimeHex;
      expect(omenCanAct(unbowed, h.omenMet), isTrue, reason: "a Hero's Slime Hex");
    });

    test("the Legenda pool's order: a take's overflow follows it (Escort's into G-3B's Spell Ward, Scatter's into G-3B's Holy Ward, "
        "Hardy's into Unbowed, Spite's into G-2B's Deathless, Horde's round to Barrier); a troop-side kind past the troop-side "
        'cap overflows too; a face past the tilt comes from the whole pool, the batch among them', () {
      final pool = omenPool(Rarity.legenda);
      expect(omenPlace(levels(OmenKind.guard, 2), OmenKind.guard, pool, 3), [OmenKind.guard, OmenKind.guard, OmenKind.spellWard]);
      expect(omenPlace(levels(scatter, 3), scatter, pool, 3), [scatter, OmenKind.holyWard, OmenKind.holyWard]);
      expect(omenPlace(levels(hardy, 2), hardy, pool, 3), [hardy, hardy, unbowed]);
      expect(omenPlace(levels(spite, 3), spite, pool, 3), [spite, OmenKind.deathless, OmenKind.deathless]);
      expect(omenPlace(levels(horde, 3), horde, pool, 3), [horde, OmenKind.shield, OmenKind.shield], reason: 'round to the start');
      // Four troop-side kinds held (Wound, Sunder, Scar, Fade): Rust and Executioner have no room, and their levels go on.
      final four = [OmenKind.wound, OmenKind.sunder, OmenKind.scar, OmenKind.fade];
      expect(omenPlace(four, rust, pool, 3), List.filled(3, OmenKind.sideSwing), reason: 'past Rust');
      expect(omenPlace(four, executioner, pool, 3), [spite, spite, spite], reason: 'past Executioner');
      expect(omenPlace([...four.take(3)], executioner, pool, 3), [executioner, executioner, executioner], reason: 'room');
      // Dragon Crown (Legenda, its counter Barrier): past the tilt each kind of the pool as likely.
      final faces = {for (var i = 0; i < 3400; i++) omenFace(Relic.dragonCrown, null, omenTilt + (1 - omenTilt) * (i + 0.5) / 3400)};
      expect(faces, pool.toSet());
      expect(faces, containsAll(batch));
    });
  });

  group('the HUD numbers', () {
    setUp(() => omensOn = true);

    test('at E8 each shows its capped share (its max), the one its hooks read (Unbowed its count by L, Horde its total); '
        'every line short and in English', () {
      final g = plain(omens: [for (final k in batch) ...top(k)], factor: 2);
      foeAt(g, 'orc', const Point(300, 60)); // a wave on: the HUD shows its frozen factor
      expect(g.omenShownFactor, 2);
      for (final k in batch) {
        final v = omenShown(k, omenCap, 8);
        expect(v.x, k.k.max, reason: '$k: E8 is past its max');
        expect(g.omenK(k), v.x, reason: '$k: the hooks read the same');
        expect(g.omenShownK(k), v.x, reason: '$k');
        if (k != unbowed) expect(g.omenEffect(k), contains('${omenPercent(v.x)}%'), reason: '$k');
      }
      expect(g.omenUnbowed, 2);
      expect({for (final k in batch) k: g.omenEffect(k)}, {
        scatter: 'Extra hits (jumps, blasts, hits near the target) do 40% less.',
        thornproof: 'Damage troops send back does 60% less to monsters.',
        rust: 'Small relics on troops work 60% less.',
        veterans: '15% more monsters are silver (stronger).',
        hardy: 'Silver and gold monsters have 30% more HP.',
        unbowed: 'Each monster ignores its first 2 holds, stuns or hexes.',
        executioner: 'Troops under 20% HP get no shield, block or "less damage taken".',
        spite: 'Monsters marked by Vengeance Mark or Ember Brand deal 30% more damage.',
        blunt: 'Silver, gold and bosses take 30% less of a hit past 20% of their HP.',
        horde: 'Each 10 monsters alive make monsters take 6% less damage, up to 18%.',
      });
      expect([for (var n = 1; n <= 4; n++) plain(omens: levels(unbowed, n)).omenEffect(unbowed)], [
        'Each monster ignores its first 1 hold, stun or hex.',
        'Each monster ignores its first 1 hold, stun or hex.',
        'Each monster ignores its first 2 holds, stuns or hexes.',
        'Each monster ignores its first 2 holds, stuns or hexes.',
      ], reason: 'a count by L');
      expect(plain(omens: levels(unbowed, 1), factor: 2).omenUnbowed, 1, reason: 'the Beban factor never scales a count');
      expect([for (var n = 1; n <= 4; n++) plain(omens: levels(horde, n)).omenEffect(horde)],
          [for (final (x, cap) in [('1.5', '4.5'), ('3', '9'), ('4.5', '13.5'), ('6', '18')]) 'Each 10 monsters alive make monsters take $x% less damage, up to $cap%.']);
      for (final k in batch) {
        final line = g.omenLine(k);
        expect(line.length, lessThanOrEqualTo(80), reason: line);
        expect(line.codeUnits.every((c) => c < 128), isTrue, reason: line);
      }
    });
  });

  group('on', () {
    setUp(() => omensOn = true);

    test("Scatter: a troop's extra hit (an axeman's splash past its target) on a monster × (1 − share), at most 40%; its "
        'blow on its target as it was; in the taken floor', () {
      /// An axeman strikes an orc 12 px from it; another orc 8 px past it takes the splash. What each lost.
      (double, double) splash(List<OmenKind> omens, {double factor = 1, List<OmenKind> more = const []}) {
        final g = plain(omens: [...omens, ...more], factor: factor);
        final a = placeNow(g, 'armored_axeman', 2, 3)..busyUntil = hold;
        final o = foeAt(g, 'orc', a.pos + const Point(12, 0))
          ..maxHp = 100000
          ..hp = 100000;
        final p = foeAt(g, 'orc', o.pos + const Point(0, 8))
          ..maxHp = 100000
          ..hp = 100000;
        final hp = p.hp, main = blowOn(g, o, a);
        return (main, hp - p.hp);
      }

      final (main, extra) = splash(const []);
      expect(extra, greaterThan(0), reason: 'the splash lands');
      for (final (n, factor, share) in steps(scatter)) {
        final (m, e) = splash(levels(scatter, n), factor: factor);
        expect(m, closeToBlow(main), reason: 'L$n ×$factor: its target');
        expect(e, closeToBlow(extra * (1 - share)), reason: 'L$n ×$factor: the extra hit');
      }
      // With Armor at its max (0.4): 0.6 × 0.6 = 0.36, held at the floor.
      expect(splash(top(scatter), factor: 2, more: top(OmenKind.armor)).$2, closeToBlow(extra * omenTakenFloor));
    });

    test("Thornproof: a troop's hit back (worn thorns) on a monster × (1 − share), at most 60%, so at E8 the taken floor "
        "(50%) holds it; a troop's blow as it was", () {
      /// An orc strikes a knight that wears thorns: what the orc lost.
      double back(List<OmenKind> omens, {double factor = 1}) {
        final (g, k, o) = duel(omens: omens, factor: factor);
        k.relics.add(Relic.thorns);
        o
          ..maxHp = 100000
          ..hp = 100000;
        final hp = o.hp;
        blowOn(g, k, o);
        return hp - o.hp;
      }

      final base = back(const []);
      expect(base, greaterThan(0));
      for (final (n, factor, share) in steps(thornproof)) {
        expect(back(levels(thornproof, n), factor: factor), closeToBlow(base * max(omenTakenFloor, 1 - share)), reason: 'L$n ×$factor');
      }
      expect(thornproof.k.max, greaterThan(1 - omenTakenFloor), reason: 'its max alone is past the floor');
      expect(troopBlow(omens: top(thornproof), factor: 2), closeToBlow(troopBlow()), reason: "a troop's own blow");
    });

    test("Rust: a troop's worn small relics work × (1 − share), at most 60%: guard's cut, fang's heal, thorns' hit back "
        "and fury's extra on its beat; without a level as they were", () {
      final base = foeBlow();
      void guard(Game g, Unit k, Unit o) => k.relics.add(Relic.guard);
      expect(foeBlow(set: guard), closeToBlow(base * (1 - guardCut)));
      for (final (n, factor, share) in steps(rust)) {
        expect(foeBlow(omens: levels(rust, n), factor: factor, set: guard), closeToBlow(base * (1 - guardCut * (1 - share))),
            reason: 'L$n ×$factor: guard');
      }
      // Fang: the heal asked is the share of what the blow took.
      double fang(List<OmenKind> omens) {
        final (g, k, o) = duel(omens: omens, factor: 2);
        k
          ..relics.add(Relic.fang)
          ..hp = 50000;
        o
          ..maxHp = 100000
          ..hp = 100000;
        double? asked;
        g.onTroopHeal = (u, src, a, past) {
          if (src == HealSrc.fang) asked = a;
        };
        final dealt = blowOn(g, o, k);
        return asked! / dealt;
      }

      expect(fang(const []), closeTo(fangShare, 1e-9));
      expect(fang(top(rust)), closeTo(fangShare * (1 - rust.k.max), 1e-9));
      // Thorns: what the orc loses to the knight's worn thorns.
      double thorns(List<OmenKind> omens) {
        final (g, k, o) = duel(omens: omens, factor: 2);
        k.relics.add(Relic.thorns);
        o
          ..maxHp = 100000
          ..hp = 100000;
        blowOn(g, k, o);
        return 100000 - o.hp;
      }

      final t0 = thorns(const []), def = foeAt(plain(), 'orc', const Point(0, 0)).stats.def;
      // The thorns' blow goes through the orc's defence: its share of the knight's loss, less the orc's defence.
      final took = foeBlow(set: (g, k, o) => k.relics.add(Relic.thorns));
      expect(t0, closeToBlow(hitTaken(took * thornsShare, def)));
      expect(thorns(top(rust)), closeToBlow(hitTaken(took * thornsShare * (1 - rust.k.max), def)));
      // Fury: the third blow is × 1 + its extra × (1 − share).
      List<double> fury(List<OmenKind> omens) {
        final (g, k, o) = duel(omens: omens, factor: 2);
        k.relics.add(Relic.fury);
        o
          ..maxHp = 100000
          ..hp = 100000;
        return [for (var i = 0; i < 3; i++) blowOn(g, o, k)];
      }

      final kn = troopTypes['knight']!.dmg;
      expect(fury(const []), [for (final m in [1, 1, furyHit]) closeToBlow(hitTaken(kn * m, def))]);
      expect(fury(top(rust)), [for (final m in [1.0, 1.0, 1 + (furyHit - 1) * (1 - rust.k.max)]) closeToBlow(hitTaken(kn * m, def))]);
    });

    test('Veterans: on the same draw, perE × E more of the wave comes silver (a normal one turned elite), at most 15%; never '
        'more gold; the dice as they were', () {
      final (plainQ, plainNext) = queueOf(30, const []);
      final (vetQ, vetNext) = queueOf(30, top(veterans)); // no army: the factor 1, so E4: 12%
      expect(vetNext, plainNext, reason: 'the same draws');
      expect(vetQ.length, plainQ.length);
      var turned = 0;
      for (var i = 0; i < plainQ.length; i++) {
        expect(vetQ[i].$1, plainQ[i].$1, reason: 'the same types');
        if (vetQ[i].$2 == plainQ[i].$2) continue;
        expect((plainQ[i].$2, vetQ[i].$2), (Tier.normal, Tier.elite), reason: 'only a normal one turns silver');
        turned++;
      }
      expect(turned, greaterThan(0));
      int count(List<(String, Tier)> q, Tier tier) => q.where((e) => e.$2 == tier).length;
      expect(count(vetQ, Tier.highElite), count(plainQ, Tier.highElite), reason: 'never more gold');
      // The threshold: r under highEliteChance + eliteChance + share is silver. Over many waves' draws the share moved is
      // about the share.
      var moved = 0, all = 0;
      for (var w = 30; w < 60; w++) {
        final (a, _) = queueOf(w, const []);
        final (b, _) = queueOf(w, top(veterans));
        for (var i = 0; i < a.length; i++) {
          if (a[i].$2 == Tier.boss || a[i].$2 == Tier.miniBoss) continue;
          all++;
          if (a[i].$2 != b[i].$2) moved++;
        }
      }
      expect(moved / all, closeTo(0.12, 0.03), reason: '$moved of $all');
      final (offQ, _) = queueOf(30, const []);
      expect(offQ, plainQ, reason: 'without it');
    });

    test('Hardy: an elite and a high elite (a raised one too) come on with share more HP, at most 30%, rounded; the other '
        'ranks and stats as they were; with the skip buff both', () {
      List<num> rest(Stats s) => [s.dmg, s.speed, s.rate, s.range, s.def, s.regen, s.cost];
      for (final (n, factor, share) in steps(hardy)) {
        final g = plain(omens: levels(hardy, n), factor: factor);
        for (final tier in Tier.values) {
          for (final raised in [false, true]) {
            final want = enemyStats('orc', tier, g.wave, raised: raised, tideStart: g.tideStart), got = g.spawnStats('orc', tier, raised: raised);
            final silver = tier == Tier.elite || tier == Tier.highElite;
            expect(got.hp, silver ? (want.hp * (1 + share)).round() : want.hp, reason: 'L$n ×$factor ${tier.name} $raised');
            expect(rest(got), rest(want), reason: tier.name);
          }
        }
        final skip = g.spawnStats('orc', Tier.elite, skipBuff: true), want = enemyStats('orc', Tier.elite, g.wave, tideStart: g.tideStart);
        expect(skip.hp, (want.hp * (1 + skipBuffK) * (1 + share)).round(), reason: 'with the skip buff');
        expect(g.monster('orc', Tier.highElite, const Point(250, 60)).maxHp, g.spawnStats('orc', Tier.highElite).hp);
      }
      final bones = plain(omens: [...top(hardy), ...top(OmenKind.oldBones)], factor: 2);
      final want = enemyStats('skeleton', Tier.elite, bones.wave, tideStart: bones.tideStart).hp;
      expect(bones.spawnStats('skeleton', Tier.elite).hp, (want * 1.4 * 1.3).round(), reason: 'with Old Bones');
    });

    test('Unbowed: each monster shrugs off its first n pins, stuns and hexes a troop puts on it (n by L: 1, 1, 2, 2), Hold '
        "Fast's steel flash on it; then they land; a landed hex refills nothing; a slow or a monster's own pin lands", () {
      final (g, k, o) = duel(omens: levels(unbowed, 1), factor: 2);
      expect(o.shrugs, 1, reason: 'L1: one, whatever the factor');
      expect(duel(omens: levels(unbowed, 3)).$3.shrugs, 2);
      final rings = g.rings.length;
      g.addEffect(o, Status.impaled, 2, k: 0.5, by: k);
      expect([g.effectOn(o, Status.impaled), o.shrugs], [null, 0], reason: 'shrugged off');
      expect([g.rings.length, g.rings.last.look, g.rings.last.follow], [rings + 1, RingLook.brace, o]);
      g.addEffect(o, Status.impaled, 2, k: 0.5, by: k);
      expect(g.effectOn(o, Status.impaled), isNotNull, reason: 'the next lands');
      final p = foeAt(g, 'orc', o.pos + const Point(0, 20));
      g.addEffect(p, Status.slow, 2, k: 0.5, by: k);
      g.addEffect(p, Status.impaled, 2, k: 0.5);
      expect([g.under(p, Status.slow), g.under(p, Status.impaled), p.shrugs], [true, true, 1], reason: "a slow; a pin from no troop");

      // A stun (Shield Bash): shrugged, then it lands.
      for (final tier in [Tier.highElite, Tier.miniBoss]) {
        final (s, h) = heroCaster(HeroSkill.shieldBash);
        s
          ..omens.addAll(levels(unbowed, 1))
          ..omenFactor = 1;
        final u = foeAt(s, 'orc', h.pos + Point(h.stats.range, 0), tier);
        void bash() {
          u.pos = h.pos + Point(h.stats.range, 0);
          h
            ..heroSkillAt = double.negativeInfinity
            ..mp = h.stats.mp.toDouble();
          s.tick(0.05);
          expect(h.heroSkillAt, s.t, reason: '${tier.name}: it cast');
        }

        bash();
        expect([u.stunUntil, u.shrugs], [double.negativeInfinity, 0], reason: tier.name);
        bash();
        expect(u.stunUntil, greaterThan(s.t), reason: 'the second lands');
      }

      // Slime Hex: shrugged (no hex, its stats its own), then it lands; when it ends nothing refills.
      final (x, h) = heroCaster(HeroSkill.slimeHex);
      x
        ..omens.addAll(levels(unbowed, 1))
        ..omenFactor = 1;
      final strong = foeAt(x, 'elite_orc', h.pos + const Point(60, 0), Tier.highElite), stats = strong.stats;
      x.tick(0.05);
      expect(h.heroSkillAt, x.t);
      expect([x.under(strong, Status.hex), strong.stats, strong.shrugs], [false, stats, 0], reason: 'shrugged');
      h
        ..heroSkillAt = double.negativeInfinity
        ..mp = h.stats.mp.toDouble();
      x.tick(0.05);
      expect(x.under(strong, Status.hex), isTrue, reason: 'the second lands');
      h.heroSkillAt = x.t + 1000; // no third
      runFor(x, slimeHexK.time + 0.2);
      expect([x.under(strong, Status.hex), strong.stats, strong.shrugs], [false, stats, 0], reason: 'a landed hex refills nothing');
    });

    test('Executioner: a monster\'s blow on a troop under share of its max HP (read before it, at most 20%) meets no worn '
        "guard, skill guard, cut Fx, duel's cut, block, absorb, Mana Shield, ward nor cap over 0; its defence, a cap-0 "
        "window and a struck Fx's MP still act; at or over the line, as it was", () {
      final base = foeBlow();
      void low(Game g, Unit k, Unit o) => k.hp = k.maxHp * 0.19;
      void line(Game g, Unit k, Unit o) => k.hp = k.maxHp * executioner.k.max; // at 20%: not under
      final shields = <String, (void Function(Game g, Unit k, Unit o), double)>{
        'worn guard': ((g, k, o) => k.relics.add(Relic.guard), base * (1 - guardCut)),
        'skill guard': (
          (g, k, o) => k
            ..guardUntil = 1e9
            ..guardCut = 0.3,
          base * 0.7
        ),
        'Turtle Shell': ((g, k, o) => g.givePusaka(Relic.turtleShell, type: 'knight', stars: 1), base * (1 - turtleShellK.cut[0])),
        "duel's cut": ((g, k, o) => g.addEffect(k, Status.duel, 5, by: o), base * (1 - duelK.cut)),
        'block': ((g, k, o) => g.addEffect(k, Status.block, 5, k: 0, n: 2), 0.0),
        'absorb': ((g, k, o) => g.addEffect(k, Status.absorb, 5, k: 1000), 0.0),
        'Mana Shield': (
          (g, k, o) {
            g.addEffect(k, Status.manaShield, 5);
            k.mp = 1000;
          },
          0.0
        ),
        'ward': ((g, k, o) => g.giveWard(k, 1000), 0.0),
        'cap over 0': ((g, k, o) => g.addEffect(k, Status.cap, 5, k: 0.00001), 1.0),
      };
      for (final MapEntry(key: name, value: (set, shielded)) in shields.entries) {
        expect(foeBlow(omens: top(executioner), factor: 2, set: (g, k, o) {
          set(g, k, o);
          k.hp = k.maxHp * 0.3; // between Executioner's 20% and Turtle Shell's 40%
        }), closeToBlow(shielded), reason: '$name over the line');
        expect(foeBlow(omens: top(executioner), factor: 2, set: (g, k, o) {
          set(g, k, o);
          low(g, k, o);
        }), closeToBlow(base), reason: '$name under it: bare');
        expect(foeBlow(set: (g, k, o) {
          set(g, k, o);
          low(g, k, o);
        }), closeToBlow(shielded), reason: '$name without it');
      }
      for (final (n, factor, share) in steps(executioner)) {
        void under(Game g, Unit k, Unit o) {
          k
            ..relics.add(Relic.guard)
            ..hp = k.maxHp * (share - 0.001);
        }

        void at(Game g, Unit k, Unit o) {
          k
            ..relics.add(Relic.guard)
            ..hp = k.maxHp * share;
        }

        expect(foeBlow(omens: levels(executioner, n), factor: factor, set: under), closeToBlow(base), reason: 'L$n ×$factor under');
        expect(foeBlow(omens: levels(executioner, n), factor: factor, set: at), closeToBlow(base * (1 - guardCut)),
            reason: 'L$n ×$factor at the line');
      }
      expect(foeBlow(omens: top(executioner), factor: 2, set: (g, k, o) {
        line(g, k, o);
        k.relics.add(Relic.guard);
      }), closeToBlow(base * (1 - guardCut)), reason: 'at 20%');
      // Kept: a cap-0 window (the Grail's save) and the ward isn't touched; Pain Crystal's MP still comes.
      expect(foeBlow(omens: top(executioner), factor: 2, set: (g, k, o) {
        low(g, k, o);
        g.addEffect(k, Status.cap, 5, k: 0);
      }), 0, reason: 'a cap-0 window');
      /// A low knight with a ward (and Pain Crystal when [crystal]) takes a blow: what it lost, its ward before and after,
      /// and its MP after.
      (double, double, double, double) bareBlow({required bool crystal}) {
        final (g, k, o) = duel(omens: top(executioner), factor: 2);
        if (crystal) g.givePusaka(Relic.painCrystal, type: 'knight', stars: 1);
        low(g, k, o);
        g.giveWard(k, 1000);
        k.mp = 0;
        final ward = k.ward, lost = blowOn(g, k, o);
        return (lost, ward, k.ward, k.mp);
      }

      final (lost, wardBefore, wardAfter, mp) = bareBlow(crystal: true);
      final (_, _, _, mpWithout) = bareBlow(crystal: false);
      expect([lost, wardAfter], [closeToBlow(base), wardBefore], reason: 'its ward untouched');
      expect(wardBefore, greaterThan(0));
      expect(mp, greaterThan(mpWithout), reason: "Pain Crystal's MP came");
      // A troop's blow on a monster and a monster's on a monster are no troop's: as they were.
      expect(troopBlow(omens: top(executioner), factor: 2, set: (g, k, o) => o.hp = o.maxHp * 0.1), closeToBlow(troopBlow()));
    });

    test("Spite: a monster's blow on a troop while Ember Brand's mark is on it × (1 + share), at most 30%; a mark run out, "
        "Hunter's Mark or none as it was; with Prey held at the dealt cap", () {
      final base = foeBlow();
      void marked(Game g, Unit k, Unit o) => o.emberMark = (relic: Relic.emberBrand, from: 'archer', k: 1.25, until: g.t + 5);
      for (final (n, factor, share) in steps(spite)) {
        expect(foeBlow(omens: levels(spite, n), factor: factor, set: marked), closeToBlow(base * (1 + share)), reason: 'L$n ×$factor');
      }
      expect(foeBlow(omens: top(spite), factor: 2, set: (g, k, o) => o.emberMark = (relic: Relic.emberBrand, from: 'archer', k: 1.25, until: g.t - 1)),
          closeToBlow(base), reason: 'run out');
      expect(foeBlow(omens: top(spite), factor: 2, set: (g, k, o) => g.addEffect(o, Status.vulnerable, 5, k: 1.2, by: k)), closeToBlow(base),
          reason: "Hunter's Mark");
      expect(foeBlow(omens: top(spite), factor: 2), closeToBlow(base), reason: 'no mark');
      expect(foeBlow(set: marked), closeToBlow(base), reason: 'without it');
      // Spite (×1.3) and Prey (×1.4): 1.82, held at the dealt cap.
      expect(
          foeBlow(omens: [...top(spite), ...top(OmenKind.prey)], factor: 2, set: (g, k, o) {
            marked(g, k, o);
            k.hp = k.maxHp * 0.1;
          }),
          closeToBlow(base * omenDealtMost));
    });

    test("Blunt (Risk 2's guard): the part of a troop's blow past 20% of a silver, gold or boss monster's max HP × (1 − "
        'share), at most 30%; a blow at or under the line, and a normal monster (a crowd), as they were; in the taken floor',
        () {
      final big = <Tier, double>{};
      for (final tier in Tier.values) {
        big[tier] = troopBlow(tier: tier);
      }

      /// The knight's blow on a monster of [tier] whose max HP makes the blow [times] its 20% line.
      double blow(Tier tier, double times, {List<OmenKind> omens = const [], double factor = 1}) =>
          troopBlow(omens: omens, factor: factor, tier: tier, set: (g, k, o) {
            final m = (big[tier]! / (times * omenBluntOver / 100)).round();
            o
              ..maxHp = m
              ..hp = m.toDouble();
          });

      for (final tier in [Tier.elite, Tier.highElite, Tier.miniBoss, Tier.boss]) {
        for (final (n, factor, share) in steps(blunt)) {
          final m = (big[tier]! / (2 * omenBluntOver / 100)).round(), line = m * omenBluntOver / 100;
          expect(blow(tier, 2, omens: levels(blunt, n), factor: factor), closeToBlow(line + (big[tier]! - line) * (1 - share)),
              reason: '${tier.name} L$n ×$factor: the part past the line');
        }
        expect(blow(tier, 0.9, omens: top(blunt), factor: 2), closeToBlow(big[tier]!), reason: '${tier.name}: under the line');
      }
      expect(blow(Tier.normal, 5, omens: top(blunt), factor: 2), closeToBlow(big[Tier.normal]!), reason: 'a crowd monster: never');
      expect(blow(Tier.elite, 2), closeToBlow(big[Tier.elite]!), reason: 'without it');
      // A blow 10× the line with Armor at its max: (0.1 + 0.9 × 0.7) × 0.6 = 0.438, held at the floor.
      expect(blow(Tier.elite, 10, omens: [...top(blunt), ...top(OmenKind.armor)], factor: 2), closeToBlow(big[Tier.elite]! * omenTakenFloor));
    });

    test("Horde (Risk 5's guard): a troop's blow on any monster (the boss too) × (1 − share × steps), a step every 10 "
        'monsters alive on the field, at most 3 (18% at E8); the dead and those not on yet never count; with Close Ranks, '
        'Captain and Hunker at their max the taken floor holds', () {
      final base = troopBlow();
      // [n] monsters alive in all, the one struck among them.
      double withCrowd(int n, {List<OmenKind> omens = const [], double factor = 2, Tier tier = Tier.normal, void Function(Game, Unit k, Unit o)? more}) =>
          troopBlow(omens: omens, factor: factor, tier: tier, set: (g, k, o) {
            crowd(g, n - 1);
            more?.call(g, k, o);
          });
      for (final (alive, n) in [(9, 0), (10, 1), (19, 1), (20, 2), (29, 2), (30, 3), (45, 3)]) {
        expect(withCrowd(alive, omens: top(horde)), closeToBlow(base * (1 - horde.k.max * n)), reason: '$alive alive: $n steps');
      }
      for (final (n, factor, share) in steps(horde)) {
        expect(withCrowd(30, omens: levels(horde, n), factor: factor), closeToBlow(base * (1 - share * omenHordeSteps)), reason: 'L$n ×$factor');
      }
      final boss = troopBlow(tier: Tier.boss);
      expect(withCrowd(30, omens: top(horde), tier: Tier.boss), closeToBlow(boss * 0.82), reason: 'the boss too');
      expect(
          withCrowd(10, omens: top(horde), more: (g, k, o) {
            for (final u in g.enemies.where((u) => u != o).take(3).toList()) {
              u.dying = 0;
            }
          }),
          closeToBlow(base),
          reason: 'three of them dead: 7 alive');
      expect(
          withCrowd(10, omens: top(horde), more: (g, k, o) => g.enemies.last.entered = false),
          closeToBlow(base),
          reason: 'one not on yet: 9');
      expect(withCrowd(30), closeToBlow(base), reason: 'without it');
      expect(foeBlow(omens: top(horde), factor: 2, set: (g, k, o) => crowd(g, 30)), closeToBlow(foeBlow()), reason: "a monster's blow");
      // Risk 5, the crowd stack at E8: Horde 0.82 × Close Ranks' guard 0.85 × Captain 0.75 × Hunker 0.8 = 0.418, held at 0.5.
      final stack = [...top(horde), ...top(OmenKind.closeRanks), ...top(OmenKind.captain), ...top(OmenKind.hunker)];
      expect(
          withCrowd(30, omens: stack, more: (g, k, o) {
            foeAt(g, 'orc', o.pos + const Point(20, 0), Tier.highElite); // a captain near
            g.addEffect(o, Status.slow, 5, k: 0.5, by: k); // held
            o
              ..guardCut = OmenKind.closeRanks.k.max
              ..guardUntil = g.t + 5
              ..guardOmen = true; // Close Ranks' guard
          }),
          closeToBlow(base * omenTakenFloor));
    });
  });

  group('off', () {
    test('with omens off and every level held none of the ten acts', () {
      final all = [for (final k in batch) ...top(k)];
      omensOn = true;
      final hp = plain(omens: all, factor: 2).spawnStats('orc', Tier.elite).hp;
      omensOn = false;
      final g = plain(omens: all, factor: 2);
      expect(g.spawnStats('orc', Tier.elite).hp, enemyStats('orc', Tier.elite, g.wave, tideStart: g.tideStart).hp);
      expect(hp, isNot(g.spawnStats('orc', Tier.elite).hp), reason: 'Hardy on');
      expect(foeAt(g, 'orc', const Point(300, 60)).shrugs, 0);
      expect(g.omenUnbowed, 0);
      expect(foeBlow(omens: all, factor: 2, set: (g, k, o) {
        k
          ..relics.add(Relic.guard)
          ..hp = k.maxHp * 0.1;
        o.emberMark = (relic: Relic.emberBrand, from: 'archer', k: 1.25, until: g.t + 5);
      }), closeToBlow(foeBlow() * (1 - guardCut)), reason: 'Rust, Executioner, Spite');
      expect(troopBlow(omens: all, factor: 2, tier: Tier.elite, set: (g, k, o) {
        crowd(g, 30);
        o
          ..maxHp = 10
          ..hp = 10;
      }), closeToBlow(troopBlow(tier: Tier.elite, set: (g, k, o) => o
        ..maxHp = 10
        ..hp = 10)), reason: 'Blunt, Horde');
      final (q, next) = queueOf(30, all);
      final (q0, next0) = queueOf(30, const []);
      expect([q, next], [q0, next0], reason: 'Veterans');
      final (h, k, o) = duel(omens: all, factor: 2);
      h.addEffect(o, Status.impaled, 2, k: 0.5, by: k);
      expect(h.under(o, Status.impaled), isTrue, reason: 'Unbowed');
    });
  });
}
