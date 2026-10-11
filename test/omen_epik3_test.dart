// Shadow batch E-3B (decisions-log 219, lib/omen.dart; catalog-bayangan-v2 §3.2; docs/units-and-combat.md "Bayangan on
// the field", docs/loot-items-relics.md "Bayangan"): seven more Epik kinds. Their rows (the Epik pool alone, in the
// pool's order among E-1B's and E-2B's; numbers, icons, the troop-side flag, needs), the cap at E8 and the HUD number
// equal to it, and with omens on one test a kind: Prey and Herd Hunt raise a monster's blow on a troop under 30% HP or of
// a type with 10 alive (in the dealt cap); Old Bones gives the skeletons more HP; Grave Pact cuts a troop's blow on a
// monster raised by one that lives (in the taken floor); Heal Siphon pays a share of the troops' heals to the nearest
// monster; Trickle spreads a troop's heals over its time, each heal on its own clock; Toll takes a share of a killer
// troop's HP. The heal stack (Wound, Scar, Trickle, Heal Siphon) composes in the funnel's order. With omens off none of
// it acts.
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

const prey = OmenKind.prey, herdHunt = OmenKind.herdHunt, oldBones = OmenKind.oldBones, gravePact = OmenKind.gravePact;
const healSiphon = OmenKind.healSiphon, trickle = OmenKind.trickle, toll = OmenKind.toll;

/// The batch, in the Epik pool's order.
const batch = [prey, herdHunt, oldBones, gravePact, healSiphon, trickle, toll];

/// Today's seven, whole in the Legenda pool until its cut-over (Epik's kept two: batch E-3).
const seven = [OmenKind.armor, OmenKind.haste, OmenKind.mend, OmenKind.thorns, OmenKind.wound, OmenKind.shield, OmenKind.guard];

/// The Epik pool's thirty in their order (catalog-bayangan-v2 §2): the pool itself since the Epik cut-over.
const epikOrder = [
  'Armor', 'Mend', 'Prey', 'Dark Hymn', 'Bone Arrows', 'Arrow Ward', 'Second Skin', 'Bile Sacs', 'Blood Moon', 'Mark Ward', //
  'Herd Hunt', 'Last Rage', 'Parting Gift', 'Old Bones', 'Bat Venom', 'Grave Pact', 'Captain', 'Enrage', 'Heal Siphon', 'Hunker',
  'Counterspell', 'Close Ranks', 'Wear Down', 'Blindside', 'Envy', 'Trickle', 'Toll', 'Zeal', 'Triumph', 'Muster',
];

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
(Game, Unit, Unit) duel({List<OmenKind> omens = const [], double factor = 1, Tier tier = Tier.normal}) {
  final g = plain(omens: omens, factor: factor);
  final k = placeNow(g, 'knight', 2, 3)
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

/// A troop of [type] standing at [at] that never moves or fights ([hold]), set down as is (cleanse_test.dart's).
Unit troopAt(Game g, String type, Point<double> at) {
  final u = Unit(Side.troop, type, troopTypes[type]!, at)
    ..entered = true
    ..busyUntil = hold;
  g.units.add(u);
  return u;
}

/// A monster heal the funnel heard: the monster, its tag, the HP asked and the HP it gained.
typedef Healed = ({Unit u, MonsterHeal src, double asked, double gained});

/// Every monster heal of [g] from now on, in order.
List<Healed> hear(Game g) {
  final heard = <Healed>[];
  g.onMonsterHeal = (u, src, asked, gained) => heard.add((u: u, src: src, asked: asked, gained: gained));
  return heard;
}

/// A troop heal the funnel heard: the troop, its tag, when, the HP asked and the heal past full it reported.
typedef TroopHealed = ({Unit u, HealSrc src, double t, double asked, double past});

/// Ticks [g] until [done], at most [most] s.
void tickUntil(Game g, bool Function() done, [double most = 5]) {
  final end = g.t + most;
  while (!done()) {
    if (g.t >= end) fail('tickUntil: not done in $most s');
    g.tick(0.05);
  }
}

/// A PNG's width and height, from its header.
(int, int) pngSize(File f) {
  final b = f.readAsBytesSync();
  int at(int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
  return (at(16), at(20));
}

/// A blow's damage [v] to within float noise.
Matcher closeToBlow(double v) => closeTo(v, 1e-9);

/// A wave on, a priest at cell (0, 3) and a knight at (2, 3) that never fights, of [maxHp] max HP at [hp], and an orc
/// [orcAt] px right of the knight hurt to 10 HP (in Heal Siphon's reach); the enemy holding [omens] at [factor]. Every
/// troop heal the funnel hears, and every monster heal.
(Game, Unit, Unit, Unit, List<TroopHealed>, List<Healed>) healScene(List<OmenKind> omens,
    {double factor = 2, int maxHp = 1000, double? hp, double orcAt = 30}) {
  final g = plain(omens: omens, factor: factor);
  final pr = placeNow(g, 'priest', 0, 3)..cd = hold; // it heals only when [castOnce] lets it
  final k = placeNow(g, 'knight', 2, 3)
    ..busyUntil = hold
    ..cd = hold
    ..maxHp = maxHp;
  k.hp = hp ?? maxHp / 2;
  final o = foeAt(g, 'orc', k.pos + Point(orcAt, 0))..hp = 10;
  final heals = <TroopHealed>[];
  g.onTroopHeal = (u, src, asked, past) => heals.add((u: u, src: src, t: g.t, asked: asked, past: past));
  return (g, pr, k, o, heals, hear(g));
}

/// [healScene]'s priest casts its heal once (and no more): the time it landed.
double castOnce(Game g, Unit pr, List<TroopHealed> heals) {
  final n = heals.length;
  pr.cd = 0;
  tickUntil(g, () => heals.length > n);
  pr.cd = hold;
  expect(heals.last.src, HealSrc.heal);
  return heals.last.t;
}

/// A knight at [share] of its max HP with a huge regen (a heal each tick), with [foes] (px right of it, rank) hurt to 10
/// HP, mid-wave while there are any; the enemy holding [omens] at [factor]. One tick: the knight healed.
(Game, Unit, List<Unit>, List<Healed>) regenScene(List<OmenKind> omens,
    {double factor = 2, double share = 0.5, List<(double, Tier)> foes = const [(20, Tier.normal)]}) {
  final g = plain(omens: omens, factor: factor);
  final k = placeNow(g, 'knight', 2, 3)..cd = hold; // never strikes; not held busy, so its regen ticks
  final s = k.stats;
  k
    ..stats = Stats(hp: s.hp, cost: s.cost, speed: s.speed, dmg: s.dmg, range: s.range, rate: s.rate, regen: 10000)
    ..hp = k.maxHp * share;
  final os = [for (final (dx, tier) in foes) foeAt(g, 'orc', k.pos + Point(dx, 0), tier)..hp = 10];
  final heard = hear(g);
  g.tick(0.05);
  k.busyUntil = hold; // healed: it stands where it is
  return (g, k, os, heard);
}

void main() {
  tearDown(() => omensOn = false);

  group('the rows', () {
    test("the seven sit in the Epik pool alone, in the pool's order among E-1B's and E-2B's; the Langka and Legenda pools "
        "as they were; their numbers, titles, constants, troop-side flag, needs and icons (an existing sheet's cell, each "
        'unique)', () {
      final pool = omenPool(Rarity.epik);
      expect([for (final k in pool) k.title], epikOrder, reason: "since the Epik cut-over the pool is §2's thirty (omen_epik_cutover_test.dart)");
      expect(pool, containsAllInOrder(batch));
      expect(omenPool(Rarity.langka), hasLength(30));
      expect(omenPool(Rarity.langka).where(batch.contains), isEmpty);
      expect(omenPool(Rarity.legenda).take(2), [OmenKind.shield, OmenKind.guard],
          reason: "Barrier and Escort first since the Legenda cut-over (omen_legenda_cutover_test.dart); G-1B's kinds follow");
      expect(omenOrder, OmenKind.values);
      for (final k in batch) {
        expect(k.tiers, {Rarity.epik}, reason: '$k');
        expect(k.live, isTrue, reason: '$k');
        expect(k.debuff, isFalse, reason: '$k');
        expect(k.byL, isEmpty, reason: '$k: a share, no count');
      }
      // Batch E-3 names three of them: the Grail's and Dawn Star's healer counter switched with the Epik cut-over, and
      // Hearth, Mercy Lily, Heartbeat, Halo Lantern and Bright Spring came (pusaka_epik3_test.dart). The other four are
      // faces only.
      expect({for (final k in batch) k: k.answers}, {
        prey: [Relic.grail, Relic.hearth, Relic.mercyLily],
        herdHunt: [Relic.heartbeat],
        oldBones: <Relic>[],
        gravePact: <Relic>[],
        healSiphon: [Relic.dawnStar, Relic.haloLantern, Relic.brightSpring],
        trickle: <Relic>[],
        toll: <Relic>[],
      });
      expect({for (final k in batch) k: k.k}, {
        prey: (perE: 0.06, max: 0.4),
        herdHunt: (perE: 0.04, max: 0.3),
        oldBones: (perE: 0.08, max: 0.4),
        gravePact: (perE: 0.05, max: 0.3),
        healSiphon: (perE: 0.05, max: 0.3),
        trickle: (perE: 0.4, max: 2.0),
        toll: (perE: 0.01, max: 0.04),
      });
      expect([for (final k in batch) k.title], ['Prey', 'Herd Hunt', 'Old Bones', 'Grave Pact', 'Heal Siphon', 'Trickle', 'Toll']);
      expect([omenPreyBelow, omenHerdHuntAt, omenHealSiphonReach, omenHealSiphonEvery, omenTollEvery, omenTollAbove],
          [30, 10, 3 * tile, 1, 2, 25]);
      expect(omenTrickled, {HealSrc.heal, HealSrc.prayer, HealSrc.sacrifice, HealSrc.pusaka});
      expect(skeletonKinds, {'skeleton', 'skeleton_archer', 'armored_skeleton', 'greatsword_skeleton'});
      expect([for (final k in OmenKind.values) if (k.troopSide) k], [
        OmenKind.wound, OmenKind.sunder, OmenKind.spellTax, OmenKind.offBeat, OmenKind.drag, OmenKind.scar, OmenKind.fade, //
        trickle, toll, OmenKind.rust, OmenKind.executioner, OmenKind.manaBurn, // G-1B's two, G-2B's one (omen_legenda1/2_test.dart)
      ], reason: 'Trickle and Toll are troop-side (catalog-bayangan-v2 §5.1)');
      expect({for (final k in batch) if (k.needs.isNotEmpty) k: k.needs}, {
        healSiphon: {OmenNeed.heal},
        trickle: {OmenNeed.heal},
      });
      expect(OmenNeed.heal.built, isTrue);
      expect({for (final k in batch) k: (k.icon!.sheet, k.icon!.x, k.icon!.y, k.icon!.size, k.icon!.tint)}, {
        prey: ('fx_hit_swordsman.png', 256, 0, 64, tintRed),
        herdHunt: ('fx_hit_orc_rider.png', 192, 0, 64, null),
        oldBones: ('tiny_skeleton_idle.png', 42, 35, 28, null),
        gravePact: ('fx_hit_necromancer.png', 128, 0, 64, null),
        healSiphon: ('tiny_fx_heal.png', 136, 32, 30, tintOlive),
        trickle: ('item_potion.png', 0, 0, 32, tintOlive),
        toll: ('fx_hit_necromancer.png', 192, 0, 64, null),
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

    test('needs: Heal Siphon and Trickle act on an army with a heal source (a healer type, a regen, a heal Fx); the other '
        'five always', () {
      final g = bareGame(Random(1));
      for (final kind in batch) {
        expect(omenCanAct(kind, g.omenMet), !{healSiphon, trickle}.contains(kind), reason: 'no army: $kind');
      }
      placeNow(g, 'knight', 2, 3);
      expect(omenCanAct(healSiphon, g.omenMet), isFalse, reason: 'a knight heals nobody');
      placeNow(g, 'priest', 0, 3);
      expect([omenCanAct(healSiphon, g.omenMet), omenCanAct(trickle, g.omenMet)], [true, true], reason: 'a priest');
      final m = bareGame(Random(1));
      placeNow(m, 'knight', 2, 3);
      m.givePusaka(Relic.wolfFeast, type: 'knight', stars: 1);
      expect(omenCanAct(trickle, m.omenMet), isTrue, reason: "Wolf Feast's heal");
    });

    test("the Epik pool's order: a take's overflow follows it (Prey's into Dark Hymn, Parting Gift's into Old Bones, Grave "
        "Pact's into Captain, Enrage's into Heal Siphon, Envy's into Trickle, Toll's into Zeal); a troop-side kind past the "
        'troop-side cap overflows too; a face past the tilt comes from the thirty, the batch among them', () {
      final pool = omenPool(Rarity.epik);
      expect(omenPlace(levels(prey, 3), prey, pool, 2), [prey, OmenKind.darkHymn]);
      expect(omenPlace(levels(OmenKind.markWard, 3), OmenKind.markWard, pool, 2), [OmenKind.markWard, herdHunt]);
      expect(omenPlace(levels(herdHunt, 3), herdHunt, pool, 2), [herdHunt, OmenKind.lastRage]);
      expect(omenPlace(levels(OmenKind.partingGift, 3), OmenKind.partingGift, pool, 2), [OmenKind.partingGift, oldBones]);
      expect(omenPlace(levels(oldBones, 3), oldBones, pool, 2), [oldBones, OmenKind.batVenom], reason: 'Bat Venom since batch E-3');
      expect(omenPlace(levels(gravePact, 3), gravePact, pool, 2), [gravePact, OmenKind.captain]);
      expect(omenPlace(levels(OmenKind.enrage, 3), OmenKind.enrage, pool, 2), [OmenKind.enrage, healSiphon]);
      expect(omenPlace(levels(healSiphon, 3), healSiphon, pool, 2), [healSiphon, OmenKind.hunker]);
      expect(omenPlace(levels(OmenKind.envy, 3), OmenKind.envy, pool, 2), [OmenKind.envy, trickle]);
      expect(omenPlace(levels(trickle, 3), trickle, pool, 2), [trickle, toll]);
      expect(omenPlace(levels(toll, 3), toll, pool, 2), [toll, OmenKind.zeal]);
      // Four troop-side kinds held (Wound, Sunder, Scar, Fade): Trickle and Toll have no room, and their levels go on.
      final four = [OmenKind.wound, OmenKind.sunder, OmenKind.scar, OmenKind.fade];
      expect(omenPlace(four, trickle, pool, 2), [OmenKind.zeal, OmenKind.zeal], reason: 'past Trickle and Toll');
      expect(omenPlace([...four.take(3), trickle], toll, pool, 2), [OmenKind.zeal, OmenKind.zeal]);
      expect(omenPlace([...four.take(3)], trickle, pool, 2), [trickle, trickle], reason: 'room under the cap');
      // The Grail (Epik, its counter Prey): past the tilt each of the thirty as likely.
      final faces = {for (var i = 0; i < 3400; i++) omenFace(Relic.grail, null, omenTilt + (1 - omenTilt) * (i + 0.5) / 3400)};
      expect(faces, pool.toSet());
      expect(faces, containsAll(batch));
    });
  });

  group('the HUD numbers', () {
    setUp(() => omensOn = true);

    test("at E8 each shows its capped share (its max), the one its hooks read (Trickle's in seconds); every line short "
        'and in English', () {
      final g = plain(omens: [for (final k in batch) ...top(k)], factor: 2);
      foeAt(g, 'orc', const Point(300, 60)); // a wave on: the HUD shows its frozen factor
      expect(g.omenShownFactor, 2);
      for (final k in batch) {
        final v = omenShown(k, omenCap, 8);
        expect(v.x, k.k.max, reason: '$k: E8 is past its max');
        expect(g.omenK(k), v.x, reason: '$k: the hooks read the same');
        expect(g.omenShownK(k), v.x, reason: '$k');
        expect(g.omenEffect(k), contains(k == trickle ? 'over 2s' : '${omenPercent(v.x)}%'), reason: '$k');
      }
      expect({for (final k in batch) k: g.omenEffect(k)}, {
        prey: 'Monsters deal 40% more damage to troops under 30% HP.',
        herdHunt: 'Monsters deal 30% more damage to a type with 10+ troops alive.',
        oldBones: 'Skeletons have 40% more HP.',
        gravePact: 'While its raiser lives, a raised monster takes 30% less damage.',
        healSiphon: 'The nearest monster (not a boss) gets 30% of each troop heal.',
        trickle: 'Troop heals in a wave come in over 2s, not all at once.',
        toll: 'A troop that kills a monster loses 4% of its max HP (not below 25%).',
      });
      expect([for (var n = 1; n <= 4; n++) plain(omens: levels(trickle, n)).omenEffect(trickle)],
          [for (final s in ['0.4', '0.8', '1.2', '1.6']) 'Troop heals in a wave come in over ${s}s, not all at once.']);
      final mid = plain(omens: levels(trickle, 2), factor: 1.25);
      foeAt(mid, 'orc', const Point(300, 60));
      expect(mid.omenEffect(trickle), contains('over 1s, '), reason: 'E2.5 in a wave');
      expect([for (var n = 1; n <= 4; n++) plain(omens: levels(toll, n)).omenEffect(toll)],
          [for (final x in [1, 2, 3, 4]) 'A troop that kills a monster loses $x% of its max HP (not below 25%).']);
      for (final k in batch) {
        final line = g.omenLine(k);
        expect(line.length, lessThanOrEqualTo(80), reason: line);
        expect(line.codeUnits.every((c) => c < 128), isTrue, reason: line);
      }
    });
  });

  group('on', () {
    setUp(() => omensOn = true);

    test("Prey: a monster's blow on a troop under 30% of its max HP (before the blow) × (1 + share), at most 40%; at 30% "
        'or over as it was', () {
      final base = foeBlow();
      void low(Game g, Unit k, Unit o) => k.hp = k.maxHp * 0.29;
      for (final (n, factor, share) in steps(prey)) {
        expect(foeBlow(omens: levels(prey, n), factor: factor, set: low), closeToBlow(base * (1 + share)), reason: 'L$n ×$factor');
      }
      expect(foeBlow(omens: top(prey), factor: 2, set: (g, k, o) => k.hp = k.maxHp * omenPreyBelow / 100), closeToBlow(base),
          reason: 'at 30%');
      expect(foeBlow(omens: top(prey), factor: 2), closeToBlow(base), reason: 'full HP');
      expect(foeBlow(set: low), closeToBlow(base), reason: 'without it');
    });

    test("Herd Hunt: a monster's blow on a troop whose type has 10 or more troops alive × (1 + share), at most 30%; 9, or "
        'a tenth that fell, as it was; the dealt cap holds Prey and Herd Hunt together at 1.6', () {
      final base = foeBlow();
      void herd(Game g, Unit k, int n, {bool oneDead = false}) {
        for (var i = 1; i < n; i++) {
          final u = troopAt(g, 'knight', Point(4.0 + i, 4.0));
          if (oneDead && i == 1) u.dying = 0;
        }
        expect(g.aliveOf('knight'), oneDead ? n - 1 : n);
      }

      for (final (n, factor, share) in steps(herdHunt)) {
        expect(foeBlow(omens: levels(herdHunt, n), factor: factor, set: (g, k, o) => herd(g, k, omenHerdHuntAt)),
            closeToBlow(base * (1 + share)), reason: 'L$n ×$factor');
      }
      expect(foeBlow(omens: top(herdHunt), factor: 2, set: (g, k, o) => herd(g, k, 9)), closeToBlow(base), reason: '9 alive');
      expect(foeBlow(omens: top(herdHunt), factor: 2, set: (g, k, o) => herd(g, k, 10, oneDead: true)), closeToBlow(base),
          reason: 'a tenth fell');
      expect(foeBlow(set: (g, k, o) => herd(g, k, 12)), closeToBlow(base), reason: 'without it');
      // Prey (×1.4) and Herd Hunt (×1.3) on one blow: 1.82, held at the dealt cap.
      expect(
          foeBlow(omens: [...top(prey), ...top(herdHunt)], factor: 2, set: (g, k, o) {
            herd(g, k, 10);
            k.hp = k.maxHp * 0.1;
          }),
          closeToBlow(base * omenDealtMost));
    });

    test('Old Bones: a skeleton kind of any rank (a raised one too) comes on with share more HP, at most 40%, rounded; its '
        'other stats, and every other type, as they were; with the skip buff both', () {
      List<num> rest(Stats s) => [s.dmg, s.speed, s.rate, s.range, s.def, s.regen, s.cost];
      for (final (n, factor, share) in steps(oldBones)) {
        final g = plain(omens: levels(oldBones, n), factor: factor);
        for (final type in skeletonKinds) {
          for (final tier in Tier.values) {
            for (final raised in [false, true]) {
              final want = enemyStats(type, tier, g.wave, raised: raised, tideStart: g.waveTideFrom), got = g.spawnStats(type, tier, raised: raised);
              expect(got.hp, (want.hp * (1 + share)).round(), reason: 'L$n ×$factor $type ${tier.name} $raised');
              expect(rest(got), rest(want), reason: '$type ${tier.name}');
            }
          }
          final skip = g.spawnStats(type, Tier.normal, skipBuff: true), want = enemyStats(type, Tier.normal, g.wave, tideStart: g.waveTideFrom);
          expect(skip.hp, (want.hp * (1 + skipBuffK) * (1 + share)).round(), reason: '$type with the skip buff');
          expect(g.monster(type, Tier.elite, const Point(250, 60)).maxHp, g.spawnStats(type, Tier.elite).hp);
        }
        for (final type in ['orc', 'slime', 'bat', 'werebear', boss, necroHealer]) {
          expect(g.spawnStats(type, Tier.normal).hp, enemyStats(type, Tier.normal, g.wave, tideStart: g.waveTideFrom).hp, reason: type);
        }
      }
      final g = plain();
      expect(g.spawnStats('skeleton', Tier.normal).hp, enemyStats('skeleton', Tier.normal, g.wave, tideStart: g.waveTideFrom).hp,
          reason: 'without it');
    });

    test("Grave Pact: a troop's blow on a raised monster while the one that raised it lives × (1 − share), at most 30%; "
        'its raiser fallen, or none, as it was; in the taken floor', () {
      final base = troopBlow();
      void raised(Game g, Unit k, Unit o, {bool fell = false}) {
        final r = foeAt(g, boss, o.pos + const Point(200, 0));
        o.raisedBy = r;
        if (fell) r.dying = 0;
      }

      for (final (n, factor, share) in steps(gravePact)) {
        expect(troopBlow(omens: levels(gravePact, n), factor: factor, set: raised), closeToBlow(base * (1 - share)), reason: 'L$n ×$factor');
      }
      expect(troopBlow(omens: top(gravePact), factor: 2, set: (g, k, o) => raised(g, k, o, fell: true)), closeToBlow(base),
          reason: 'its raiser fell');
      expect(troopBlow(omens: top(gravePact), factor: 2), closeToBlow(base), reason: 'not raised');
      expect(troopBlow(set: raised), closeToBlow(base), reason: 'without it');
      // With Armor (×0.6) the product 0.42 stops at the floor.
      expect(troopBlow(omens: [...top(gravePact), ...top(OmenKind.armor)], factor: 2, set: raised), closeToBlow(base * omenTakenFloor));
    });

    test("Heal Siphon: a troop's heal in a wave owes share of the HP it gave, at most 30%, paid within a second to the "
        'nearest monster below a mini boss within 3 tiles, with its own tag; the boss and a mini boss passed over; none '
        'in reach: dropped; between waves none', () {
      for (final (n, factor, share) in steps(healSiphon)) {
        final (g, k, os, heard) = regenScene(levels(healSiphon, n), factor: factor, foes: [(20, Tier.normal), (30, Tier.normal)]);
        final gave = k.maxHp * 0.5;
        expect(k.hp, k.maxHp, reason: 'the regen landed whole');
        expect(k.siphonDue, closeTo(gave * share, 1e-9), reason: 'L$n ×$factor');
        expect(heard, isEmpty, reason: 'not paid yet');
        runFor(g, omenHealSiphonEvery + 0.05);
        expect([for (final h in heard) (h.u, h.src)], [(os[0], MonsterHeal.siphon)], reason: 'the nearest');
        expect(heard.single.asked, closeTo(gave * share, 1e-9));
        expect(heard.single.gained, closeTo(min(gave * share, os[0].maxHp - 10.0), 1e-9));
        expect(k.siphonDue, 0);
        expect(g.impacts.any((i) => i.$1 == os[0].pos && i.$2 == 'heal'), isTrue, reason: 'the heal sparkle on it');
      }
      for (final rank in [Tier.miniBoss, Tier.boss]) {
        final (g, _, os, heard) = regenScene(top(healSiphon), foes: [(10, rank), (30, Tier.normal)]);
        runFor(g, 1.1);
        expect([for (final h in heard) if (h.src == MonsterHeal.siphon) h.u], [os[1]], reason: '${rank.name} passed over');
      }
      final (fg, fk, _, far) = regenScene(top(healSiphon), foes: [(omenHealSiphonReach + 4, Tier.normal)]);
      expect(fk.siphonDue, greaterThan(0));
      runFor(fg, 1.1);
      expect([far.where((h) => h.src == MonsterHeal.siphon), fk.siphonDue], [isEmpty, 0], reason: 'none in reach: dropped');
      final (_, bk, _, _) = regenScene(top(healSiphon), foes: const []);
      expect([bk.hp, bk.siphonDue], [bk.maxHp, 0], reason: 'between waves');
      final (_, nk, _, _) = regenScene(const []);
      expect(nk.siphonDue, 0, reason: 'without it');
      // After Wound and Scar's ceiling: the regen's 500 HP halved to 250, stopped at 85% of the max HP.
      final (_, wk, _, _) = regenScene([...top(healSiphon), ...top(OmenKind.wound), ...top(OmenKind.scar)]);
      expect(wk.hp, closeTo(wk.maxHp * 0.85, 1e-9));
      expect(wk.siphonDue, closeTo(wk.maxHp * 0.35 * 0.3, 1e-9), reason: 'what it gave');
    });

    test("Trickle (troop-side): a healer's heal in a wave comes in over its time, at most 2 s: nothing lands at the call, "
        'then its rate a second until its own end; between waves at once', () {
      for (final (n, factor, time) in steps(trickle)) {
        final (g, pr, k, _, heals, _) = healScene(levels(trickle, n), factor: factor);
        final before = k.hp, at = castOnce(g, pr, heals), h = pr.stats.dmg;
        expect(k.hp, before, reason: 'L$n ×$factor: nothing at the call');
        expect(k.trickle, hasLength(1));
        expect([k.trickle.single.rate, k.trickle.single.end], [closeTo(h / time, 1e-9), closeTo(at + time, 1e-9)]);
        expect(g.trickleLeft(k), closeTo(h, 1e-9));
        runFor(g, time / 2);
        expect(k.hp, closeTo(before + h / 2, 1e-6), reason: 'half way');
        runFor(g, time / 2 + 0.05);
        expect(k.hp, closeTo(before + h, 1e-6), reason: 'whole');
        expect(k.trickle, isEmpty);
      }
      final (g, pr, k, _, heals, _) = healScene(const []);
      final before = k.hp;
      castOnce(g, pr, heals);
      expect([k.hp, k.trickle], [closeTo(before + pr.stats.dmg, 1e-9), isEmpty], reason: 'without it: at once');
      // Between waves (no monster): the regen lands at once; and no heal is spread.
      final (rg, rk, _, _) = regenScene(top(trickle), foes: const []);
      expect([rk.hp, rk.trickle], [rk.maxHp, isEmpty]);
      expect(rg.waveActive, isFalse);
    });

    test('Trickle: two heals keep their own ends; a rescue, regen, a heal status land at once; past full counts against '
        'the HP and what is still to come; the heals Fx read the whole heal at the call (Full Cup\'s shield)', () {
      final (g, pr, k, _, heals, _) = healScene(top(trickle), maxHp: 1000, hp: 500);
      final h = pr.stats.dmg, before = k.hp;
      final t1 = castOnce(g, pr, heals);
      runFor(g, 0.5);
      final t2 = castOnce(g, pr, heals);
      expect([for (final e in k.trickle) e.end], [closeTo(t1 + 2, 1e-9), closeTo(t2 + 2, 1e-9)], reason: 'the first kept its end');
      runFor(g, t1 + 2 - g.t + 0.01);
      expect([for (final e in k.trickle) e.end], [closeTo(t2 + 2, 1e-9)], reason: 'the first done');
      runFor(g, t2 + 2 - g.t + 0.01);
      expect([k.trickle, k.hp], [isEmpty, closeTo(before + 2 * h, 1e-6)]);

      // At once: regen (the knight's own), a heal status.
      final (_, rk, _, _) = regenScene(top(trickle));
      expect([rk.hp, rk.trickle], [rk.maxHp, isEmpty], reason: 'regen');
      final (sg, _, sk, _, _, _) = healScene(top(trickle));
      final sb = sk.hp;
      sg.addEffect(sk, Status.heal, 1, k: 20);
      sg.tick(0.05);
      expect([sk.hp, sk.trickle], [closeTo(sb + 20 * 0.05, 1e-9), isEmpty], reason: 'a heal status (Blessing)');

      // Past full: the knight 1.5 heals short of full; the second heal, before the first has landed, passes it.
      final (pg, pp, pk, _, pheals, _) = healScene(top(trickle), maxHp: 1000);
      pk.hp = pk.maxHp - 1.5 * pp.stats.dmg;
      pg.onTroopHeal = (u, src, asked, past) {
        pheals.add((u: u, src: src, t: pg.t, asked: asked, past: past));
        expect(past, closeTo((u.hp + pg.trickleLeft(u) - u.maxHp).clamp(0.0, asked), 1e-9), reason: 'against HP + what is to come');
      };
      castOnce(pg, pp, pheals);
      expect(pheals.last.past, 0);
      castOnce(pg, pp, pheals);
      expect(pheals.last.past, greaterThan(0));
      runFor(pg, 2.1);
      expect(pk.hp, pk.maxHp, reason: 'never past full');

      // Full Cup on the priests: a heal that passes full shields the knight at the call, though no HP has landed yet.
      final (fg, fp, fk, _, fheals, _) = healScene(top(trickle), maxHp: 1000);
      fg.givePusaka(Relic.fullCup, type: 'priest');
      fk.hp = fk.maxHp - fp.stats.dmg / 2;
      final fb = fk.hp;
      castOnce(fg, fp, fheals);
      expect(fk.hp, fb, reason: 'nothing landed');
      expect(fk.ward, closeTo(min(fp.stats.dmg / 2 * fullCupK.share[0], fk.maxHp * fullCupK.most), 1e-9), reason: 'the shield at the call');
    });

    test('Trickle: a troop that falls loses the rest; the wave\'s end drops what is left', () {
      final (g, pr, k, _, heals, _) = healScene(top(trickle));
      castOnce(g, pr, heals);
      final o = foeAt(g, 'orc', k.pos + const Point(-12, 0));
      k.hp = 1;
      blowOn(g, k, o);
      expect(k.alive, isFalse);
      g.tick(0.05);
      expect([k.trickle, k.hp <= 0], [isEmpty, true], reason: 'fell: the rest lost');

      final (w, wp, wk, wo, wheals, _) = healScene(top(trickle));
      final before = wk.hp, h = wp.stats.dmg;
      castOnce(w, wp, wheals);
      wo.dying = 0; // the last monster falls: the wave is won once it is gone
      tickUntil(w, () => !w.waveActive);
      expect(wk.trickle, isEmpty, reason: 'ended with the wave');
      final landed = wk.hp - before;
      expect(landed, inExclusiveRange(0, h));
      w.tick(0.05);
      expect(wk.hp, before + landed, reason: 'nothing more comes');
    });

    test('Toll (troop-side): a troop that kills a monster loses share of its max HP, at most 4%, through its defence, as '
        'a blow from no one; never below 25% of it; at most once every 2 s; at or under 25% nothing', () {
      /// The knight of a fresh [duel] at [share] of its max HP kills a 1-HP orc: what it lost, and the game.
      (double, Game, Unit) kill(List<OmenKind> omens, {double factor = 2, double share = 1}) {
        final (g, k, o) = duel(omens: omens, factor: factor);
        k.hp = k.maxHp * share;
        o.hp = 1;
        final hp = k.hp;
        blowOn(g, o, k);
        expect(o.alive, isFalse);
        return (hp - k.hp, g, k);
      }

      for (final (n, factor, share) in steps(toll)) {
        final (lost, g, k) = kill(levels(toll, n), factor: factor);
        expect(lost, closeToBlow(hitTaken(k.maxHp * share, k.stats.def)), reason: 'L$n ×$factor');
        expect(k.tollAt, g.t);
        expect(g.impacts.any((i) => i.$1 == k.pos && i.$2 == 'hit_necromancer'), isTrue, reason: 'the skull on it');
      }
      final (near, _, nk) = kill(top(toll), share: 0.26);
      expect(near, closeToBlow(hitTaken(nk.maxHp * 0.01, nk.stats.def)), reason: 'down to 25%, no further');
      final (at, _, ak) = kill(top(toll), share: omenTollAbove / 100);
      expect([at, ak.tollAt], [0, double.negativeInfinity], reason: 'at 25%: nothing, its clock unspent');
      final (none, _, _) = kill(const []);
      expect(none, 0, reason: 'without it');
      // Once every 2 s: another kill a tick later costs nothing; one 2 s later does.
      final (_, g, k) = kill(top(toll));
      double again() {
        final o = foeAt(g, 'orc', k.pos + const Point(12, 0))..hp = 1, hp = k.hp;
        blowOn(g, o, k);
        expect(o.alive, isFalse);
        return hp - k.hp;
      }

      expect(again(), 0, reason: '0.05 s later');
      runFor(g, omenTollEvery.toDouble());
      expect(again(), closeToBlow(hitTaken(k.maxHp * 0.04, k.stats.def)), reason: '2 s later');
    });

    test('the heal stack: Wound cuts first, Trickle spreads what is left, Scar\'s ceiling stops it as it lands, and Heal '
        'Siphon owes its share of the whole heal at the call (without Trickle, of what landed under the ceiling)', () {
      final stack = [...top(OmenKind.wound), ...top(OmenKind.scar), ...top(trickle), ...top(healSiphon)];
      final (g, pr, k, o, heals, heard) = healScene(stack, maxHp: 100, hp: 80);
      final h = pr.stats.dmg, cut = h * (1 - g.omenK(OmenKind.wound)); // Wound at E8: 48% less
      expect(g.omenK(OmenKind.wound), closeTo(0.48, 1e-12));
      expect(80 + cut, greaterThan(85), reason: 'the heal reaches past the ceiling');
      castOnce(g, pr, heals);
      expect(k.hp, 80, reason: 'nothing at the call');
      expect(k.trickle.single.rate, closeTo(cut / 2, 1e-9), reason: 'Wound first, then spread over 2 s');
      expect(k.siphonDue, closeTo(cut * 0.3, 1e-9), reason: 'the whole heal at the call');
      runFor(g, 2.1);
      expect(k.hp, closeTo(85, 1e-9), reason: "Scar's ceiling as it lands");
      final paid = [for (final x in heard) if (x.src == MonsterHeal.siphon) x];
      expect([for (final x in paid) x.u], [o]);
      expect(paid.single.asked, closeTo(cut * 0.3, 1e-9));

      // Without Trickle: the heal lands at once, stopped at the ceiling, and Heal Siphon owes a share of what landed.
      final (ig, ip, ik, _, iheals, _) = healScene([...top(OmenKind.wound), ...top(OmenKind.scar), ...top(healSiphon)], maxHp: 100, hp: 80);
      castOnce(ig, ip, iheals);
      expect(ik.hp, closeTo(85, 1e-9));
      expect(ik.siphonDue, closeTo(5 * 0.3, 1e-9));
      // Without Scar: all of it lands.
      final (ng, np, nk, _, nheals, _) = healScene([...top(OmenKind.wound), ...top(trickle)], maxHp: 100, hp: 80);
      castOnce(ng, np, nheals);
      runFor(ng, 2.1);
      expect(nk.hp, closeTo(80 + cut, 1e-6));
    });
  });

  group('off', () {
    setUp(() => omensOn = false);

    test('nothing of it acts: heals land at once and owe nothing, a kill costs nothing, blows and stats as they were', () {
      final all = [for (final k in batch) ...top(k)];
      final (g, pr, k, _, heals, heard) = healScene(all);
      final before = k.hp;
      castOnce(g, pr, heals);
      expect([k.hp, k.trickle, k.siphonDue], [closeTo(before + pr.stats.dmg, 1e-9), isEmpty, 0]);
      runFor(g, 1.1);
      expect(heard.where((h) => h.src == MonsterHeal.siphon), isEmpty);
      final (dg, dk, o) = duel(omens: all, factor: 2);
      o.hp = 1;
      final hp = dk.hp;
      blowOn(dg, o, dk);
      expect([o.alive, dk.hp, dk.tollAt], [false, hp, double.negativeInfinity]);
      expect(foeBlow(omens: all, factor: 2, set: (g, k, o) => k.hp = k.maxHp * 0.1), closeToBlow(foeBlow(set: (g, k, o) => k.hp = k.maxHp * 0.1)));
      expect(plain(omens: all, factor: 2).spawnStats('skeleton', Tier.normal).hp, plain().spawnStats('skeleton', Tier.normal).hp);
    });
  });
}
