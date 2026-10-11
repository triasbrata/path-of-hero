// Shadow batch G-2B (decisions-log 236, lib/omen.dart; catalog-bayangan-v2 §3.3; docs/units-and-combat.md "Bayangan on
// the field", docs/loot-items-relics.md "Bayangan"): ten more Legenda kinds. Their rows (the Legenda pool alone, among
// G-1B's in the pool's order; numbers, icons, the troop-side flag, needs), the cap at E8 and the HUD number equal to it,
// and with omens on one test a kind: Cover cuts a troop's blow on a boss or mini boss with a monster next to it and Adapt
// a blow in a run of one troop type (both in the taken floor); Renewal shields a monster a troop's strip took something
// off, once; Side Swing hits the troop next to the one a melee monster hit; Deathless leaves a silver or gold monster at
// 1 HP once; Warlord raises the monsters' blows while the boss or a mini boss lives, Spree a silver or gold killer's,
// Backlash those near a troop that casts (all three in the dealt cap); Vultures sends silver and gold monsters at the most
// hurt troop they reach; Mana Burn takes a troop's MP on a hit. The design's guards for Risk 3 (Adapt: the run stops at 3,
// and the boss stack holds at the taken floor) and Risk 4 (the kill snowball: Spree's count stops at 3 and only silver and
// gold count, and with Gloat, Triumph, Warlord and Backlash the dealt cap holds). With omens off none of it acts.
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

const cover = OmenKind.cover, renewal = OmenKind.renewal, sideSwing = OmenKind.sideSwing, deathless = OmenKind.deathless;
const adapt = OmenKind.adapt, warlord = OmenKind.warlord, spree = OmenKind.spree, vultures = OmenKind.vultures;
const manaBurn = OmenKind.manaBurn, backlash = OmenKind.backlash;

/// The batch, in the Legenda pool's order.
const batch = [cover, renewal, sideSwing, deathless, adapt, warlord, spree, vultures, manaBurn, backlash];

/// G-1B's ten (omen_legenda1_test.dart), the Legenda pool's other new kinds.
const g1b = [
  OmenKind.scatter, OmenKind.thornproof, OmenKind.rust, OmenKind.veterans, OmenKind.hardy, OmenKind.unbowed, //
  OmenKind.executioner, OmenKind.spite, OmenKind.blunt, OmenKind.horde,
];

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

/// A knight and a monster of [type] and [tier] 12 px from it, both standing; the enemy holding [omens] at [factor]. The
/// knight has HP to spare (100000 max HP).
(Game, Unit, Unit) duel({List<OmenKind> omens = const [], double factor = 1, Tier tier = Tier.normal, String type = 'orc'}) {
  final g = plain(omens: omens, factor: factor);
  final k = placeNow(g, 'knight', 2, 3)
    ..busyUntil = hold
    ..maxHp = 100000
    ..hp = 100000;
  final o = foeAt(g, type, k.pos + const Point(12, 0), tier);
  return (g, k, o);
}

/// The monster's blow on the knight of a fresh [duel], both [set] up so.
double foeBlow({List<OmenKind> omens = const [], double factor = 1, Tier tier = Tier.normal, void Function(Game, Unit k, Unit o)? set}) {
  final (g, k, o) = duel(omens: omens, factor: factor, tier: tier);
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

/// A soldier in a wave on, full of MP, with high elite orcs (HP to spare) 10 px and 12.8 px from it (Hold Fast wants two
/// near) and the [others]; the enemy holding [omens] at [factor] (Hero and monster skills off). Its next tick casts.
(Game, Unit, List<Unit>) caster(List<OmenKind> omens, {double factor = 2, List<(Point<double>, Tier)> others = const []}) {
  final g = bareGame(Random(1))
    ..heroSkills = false
    ..monsterSkills = false
    ..omens.addAll(omens);
  final u = placeNow(g, 'soldier', 2, 3);
  g
    ..startWave()
    ..queue.clear()
    ..omenFactor = factor;
  u
    ..cd = hold
    ..mp = u.stats.mp.toDouble();
  final foes = [
    for (final (d, tier) in <(Point<double>, Tier)>[(const Point(10, 0), Tier.highElite), (const Point(10, 8), Tier.highElite), ...others])
      foeAt(g, 'orc', u.pos + d, tier)..hp = 1e4,
  ];
  return (g, u, foes);
}

/// Vultures' scene: an orc (or [type]) of [tier] right of two knights, [a] at [aAt] px (the nearest, full HP) and [b] at
/// [bAt] px below it (30% HP), all standing; the enemy holding [omens] at the factor 2. Both are inside an orc's reach (12
/// px) and stay in it when the units part to 12 px after a blow.
(Game, Unit, Unit, Unit) scene(List<OmenKind> omens, Tier tier, {String type = 'orc', double aAt = 11.8, double bAt = 11.9}) {
  final g = plain(omens: omens, factor: 2);
  final a = placeNow(g, 'knight', 2, 3)
    ..busyUntil = hold
    ..maxHp = 100000
    ..hp = 100000;
  final b = placeNow(g, 'knight', 2, 5)
    ..busyUntil = hold
    ..maxHp = 100000
    ..hp = 30000;
  final o = foeAt(g, type, a.pos + Point(aAt, 0), tier);
  b.pos = o.pos + Point(0, bAt);
  return (g, a, b, o);
}

/// Monster [o] strikes once now: which of [troops] it hit.
Unit? strike(Game g, Unit o, List<Unit> troops) {
  final hp = [for (final u in troops) u.hp];
  o
    ..busyUntil = double.negativeInfinity
    ..cd = 0;
  g.tick(0.05);
  o.busyUntil = hold;
  for (var i = 0; i < troops.length; i++) {
    if (troops[i].hp < hp[i]) return troops[i];
  }
  return null;
}

/// Monster [o] looks for its troop for one tick without attacking (its pause not over).
void look(Game g, Unit o) {
  o
    ..busyUntil = double.negativeInfinity
    ..cd = 10;
  g.tick(0.05);
  o.busyUntil = hold;
}

void main() {
  tearDown(() => omensOn = false);

  group('the rows', () {
    test("the ten sit in the Legenda pool alone, among G-1B's (and G-3B's) after Barrier and Escort (today's seven until "
        "the Legenda cut-over), in the pool's order; the Langka and Epik pools as they were; their numbers, titles, "
        "constants, troop-side flag, needs and icons (an existing sheet's mapped cell, each unique)", () {
      final pool = omenPool(Rarity.legenda);
      expect(pool.take(2), [OmenKind.shield, OmenKind.guard], reason: "the Legenda cut-over's two (omen_legenda_cutover_test.dart)");
      expect(pool.skip(2).where((k) => batch.contains(k) || g1b.contains(k)), [
        OmenKind.scatter, cover, OmenKind.thornproof, renewal, OmenKind.rust, sideSwing, OmenKind.veterans, //
        OmenKind.hardy, OmenKind.unbowed, OmenKind.executioner, OmenKind.spite, deathless, OmenKind.blunt, adapt, warlord, //
        spree, vultures, manaBurn, backlash, OmenKind.horde,
      ], reason: "catalog-bayangan-v2 §2's order, G-3B's seven among them (omen_legenda3_test.dart)");
      expect(pool.where(batch.contains), batch);
      expect(pool.where(g1b.contains), g1b);
      expect([for (final k in batch) k.title],
          ['Cover', 'Renewal', 'Side Swing', 'Deathless', 'Adapt', 'Warlord', 'Spree', 'Vultures', 'Mana Burn', 'Backlash']);
      expect(omenPool(Rarity.langka), hasLength(30));
      expect(omenPool(Rarity.epik), hasLength(30));
      expect([...omenPool(Rarity.langka), ...omenPool(Rarity.epik)].where(batch.contains), isEmpty);
      expect(omenOrder, OmenKind.values);
      expect(OmenKind.values.take(OmenKind.values.indexOf(OmenKind.muster) + 1).where(batch.contains), isEmpty, reason: 'after the Epik kinds');
      for (final k in batch) {
        expect(k.tiers, {Rarity.legenda}, reason: '$k');
        expect(k.live, isTrue, reason: '$k');
        expect(k.debuff, isFalse, reason: '$k');
        expect(k.byL, isEmpty, reason: '$k');
        expect(k.steps, {adapt: omenAdaptSteps, spree: omenSpreeKills}[k] ?? 0, reason: '$k');
        expect(k.who, k == vultures ? ['Strong', 'Strong', 'Silver and gold', 'Silver and gold'] : isEmpty, reason: '$k');
      }
      // Their counters came with batch G-2 (pusaka_legenda2_test.dart); Cover, Renewal, Adapt, Warlord and Mana Burn are
      // faces only.
      expect({for (final k in batch) if (k.answers.isNotEmpty) k: k.answers}, {
        sideSwing: [Relic.guardianChain, Relic.phalanx, Relic.soulShelter],
        deathless: [Relic.glorySeeker],
        spree: [Relic.phoenix],
        vultures: [Relic.rageTotem],
        backlash: [Relic.manaFont],
      });
      expect({for (final k in batch) k: k.k}, {
        cover: (perE: 0.05, max: 0.3),
        renewal: (perE: 0.04, max: 0.25),
        sideSwing: (perE: 0.06, max: 0.3),
        deathless: (perE: 0.2, max: 1.2),
        adapt: (perE: 0.02, max: 0.1),
        warlord: (perE: 0.04, max: 0.25),
        spree: (perE: 0.03, max: 0.1),
        vultures: (perE: 0.0, max: 0.0),
        manaBurn: (perE: 0.005, max: 0.03),
        backlash: (perE: 0.04, max: 0.25),
      });
      expect([omenCoverReach, omenSideSwingReach, omenAdaptSteps, omenSpreeKills, omenVulturesNear, omenManaBurnEvery], [
        1.5 * tile, tile, 3, 3, 1.5 * tile, 0.5,
      ]);
      expect([omenBacklashTiles, omenBacklashTime, omenBacklashEvery], [2, 3, 1]);
      expect(omenVulturesRanks, [
        {Tier.highElite},
        {Tier.highElite},
        {Tier.elite, Tier.highElite},
        {Tier.elite, Tier.highElite},
      ]);
      expect([for (final k in batch) if (k.troopSide) k], [manaBurn], reason: 'Mana Burn is troop-side (catalog-bayangan-v2 §5.1)');
      expect({for (final k in batch) if (k.needs.isNotEmpty) k: k.needs}, {
        manaBurn: {OmenNeed.mpSkill},
        backlash: {OmenNeed.mpSkill},
      });
      // The cells mapped first (shots/cat-G2B/map-01..11): each its own sprite, nothing of a neighbour's in it.
      expect({for (final k in batch) k: (k.icon!.sheet, k.icon!.x, k.icon!.y, k.icon!.size, k.icon!.tint)}, {
        cover: ('fx_hit_knight_templar.png', 48, 0, 48, tintRed),
        renewal: ('fx_hit_wizard.png', 144, 0, 48, tintTeal),
        sideSwing: ('fx_hit_greatsword_skeleton.png', 384, 0, 64, null),
        deathless: ('ui_icons.png', 80, 16, 16, tintTeal),
        adapt: ('ui_icons.png', 48, 16, 16, tintTeal),
        warlord: ('relic_warDrum.png', 0, 0, 32, tintDarkRed),
        spree: ('fx_upgrade.png', 384, 0, 64, tintPop),
        vultures: ('ui_icons.png', 16, 0, 16, tintOlive),
        manaBurn: ('ui_icons.png', 144, 0, 16, tintOrange),
        backlash: ('ui_icons.png', 160, 0, 16, tintRed),
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

    test('needs: Mana Burn and Backlash act on an army with a troop skill that costs MP (not under Vow of Silence); the '
        'other eight always', () {
      final g = bareGame(Random(1))..skills = false;
      for (final kind in batch) {
        expect(omenCanAct(kind, g.omenMet), !{manaBurn, backlash}.contains(kind), reason: 'no army: $kind');
      }
      placeNow(g, 'knight', 2, 3);
      expect([omenCanAct(manaBurn, g.omenMet), omenCanAct(backlash, g.omenMet)], [true, true], reason: "a knight's Circle Slash");
      g.givePusaka(Relic.vowSilence, type: 'knight', stars: 1);
      expect([omenCanAct(manaBurn, g.omenMet), omenCanAct(backlash, g.omenMet)], [false, false], reason: 'its type casts none');
      placeNow(g, 'wizard', 2, 4);
      expect([omenCanAct(manaBurn, g.omenMet), omenCanAct(backlash, g.omenMet)], [true, true], reason: "a wizard's Arcane Blast");
    });

    test("the Legenda pool's order: a take's overflow follows it (Holy Ward's into Cover, Thornproof's into Blight (batch "
        "G-3's), Blight's into Renewal, Rust's into Side Swing, Spite's into Deathless, Backlash's into Horde, ...; G-3B's "
        'kinds between some: omen_legenda3_test.dart); Mana Burn past the troop-side cap overflows too; a face past the tilt '
        'comes from the whole pool, the batch among them', () {
      final pool = omenPool(Rarity.legenda);
      for (final (face, next) in [
        (OmenKind.holyWard, cover), (OmenKind.thornproof, OmenKind.blight), (OmenKind.blight, renewal), (renewal, OmenKind.rust), //
        (OmenKind.rust, sideSwing), (OmenKind.spite, deathless), (deathless, OmenKind.blunt), //
        (OmenKind.blunt, adapt), (adapt, warlord), (warlord, spree), (spree, vultures), (vultures, manaBurn), //
        (backlash, OmenKind.horde),
      ]) {
        expect(omenPlace(levels(face, 3), face, pool, 3), [face, next, next], reason: '$face');
      }
      // Four troop-side kinds held (Wound, Sunder, Scar, Fade): Mana Burn has no room, and its levels go on (to G-3B's
      // Dusk).
      final four = [OmenKind.wound, OmenKind.sunder, OmenKind.scar, OmenKind.fade];
      expect(omenPlace(four, manaBurn, pool, 3), levels(OmenKind.dusk, 3), reason: 'past Mana Burn');
      expect(omenPlace([...four.take(3)], manaBurn, pool, 3), levels(manaBurn, 3), reason: 'room');
      // Dragon Crown (Legenda, its counter Barrier): past the tilt each kind of the pool as likely.
      final faces = {for (var i = 0; i < 5400; i++) omenFace(Relic.dragonCrown, null, omenTilt + (1 - omenTilt) * (i + 0.5) / 5400)};
      expect(faces, pool.toSet());
      expect(faces, containsAll(batch));
      // An army that casts no MP skill: Mana Burn and Backlash are never a face (but by the tilt).
      final none = {for (var i = 0; i < 5400; i++) omenFace(Relic.dragonCrown, null, (i + 0.5) / 5400, (k) => omenCanAct(k, const {}))};
      expect(none.intersection({manaBurn, backlash}), isEmpty);
    });
  });

  group('the HUD numbers', () {
    setUp(() => omensOn = true);

    test('at E8 each shows its capped share (its max), the one its hooks read (Deathless in seconds, Adapt and Spree their '
        'totals, Vultures its rank word by L); every line short and in English', () {
      final g = plain(omens: [for (final k in batch) ...top(k)], factor: 2);
      foeAt(g, 'orc', const Point(300, 60)); // a wave on: the HUD shows its frozen factor
      expect(g.omenShownFactor, 2);
      for (final k in batch) {
        final v = omenShown(k, omenCap, 8);
        expect(v.x, k.k.max, reason: '$k: E8 is past its max');
        expect(g.omenK(k), v.x, reason: '$k: the hooks read the same');
        expect(g.omenShownK(k), v.x, reason: '$k');
        if (k != vultures && k != deathless) expect(g.omenEffect(k), contains('${omenPercent(v.x)}%'), reason: '$k');
      }
      expect({for (final k in batch) k: g.omenEffect(k)}, {
        cover: 'Boss and mini boss take 30% less damage with a monster next to them.',
        renewal: 'Once, a monster that loses its good effects gets a 25% HP shield.',
        sideSwing: 'Monster up-close hits also hit the troop next to it for 30%.',
        deathless: 'Silver and gold monsters survive 1 deadly hit: no damage for 1.2s.',
        adapt: 'Each hit in a row from one troop type does 10% less, up to 30%.',
        warlord: 'While a boss or mini boss lives, other monsters deal 25% more damage.',
        spree: 'Each kill gives a silver or gold monster 10% more damage, up to 30%.',
        vultures: 'Silver and gold monsters hit the most hurt troop they can reach.',
        manaBurn: "Each monster hit takes 3% of the troop's max MP.",
        backlash: 'A troop skill: monsters within 2 tiles deal 25% more damage for 3s.',
      });
      expect([for (var n = 1; n <= 4; n++) plain(omens: levels(vultures, n)).omenEffect(vultures)], [
        for (final who in ['Strong', 'Strong', 'Silver and gold', 'Silver and gold']) '$who monsters hit the most hurt troop they can reach.',
      ], reason: 'a rank word by L');
      expect(plain(omens: levels(vultures, 1), factor: 2).omenEffect(vultures), startsWith('Strong'), reason: 'never scaled by the factor');
      expect([for (var n = 1; n <= 4; n++) plain(omens: levels(deathless, n)).omenEffect(deathless)],
          [for (final s in ['0.2', '0.4', '0.6', '0.8']) 'Silver and gold monsters survive 1 deadly hit: no damage for ${s}s.']);
      expect([for (var n = 1; n <= 4; n++) plain(omens: levels(adapt, n)).omenEffect(adapt)],
          [for (final (x, cap) in [('2', '6'), ('4', '12'), ('6', '18'), ('8', '24')]) 'Each hit in a row from one troop type does $x% less, up to $cap%.']);
      expect([for (var n = 1; n <= 4; n++) plain(omens: levels(spree, n)).omenEffect(spree)],
          [for (final (x, cap) in [('3', '9'), ('6', '18'), ('9', '27'), ('10', '30')]) 'Each kill gives a silver or gold monster $x% more damage, up to $cap%.']);
      expect(plain(omens: levels(manaBurn, 1)).omenEffect(manaBurn), "Each monster hit takes 0.5% of the troop's max MP.");
      for (final k in batch) {
        final line = g.omenLine(k);
        expect(line.length, lessThanOrEqualTo(80), reason: line);
        expect(line.codeUnits.every((c) => c < 128), isTrue, reason: line);
      }
    });
  });

  group('on', () {
    setUp(() => omensOn = true);

    test("Cover: a troop's blow on the boss or a mini boss with another living monster within 1.5 tiles × (1 − share), at "
        'most 30%; alone, a farther one, a dead one or a normal monster as it was; in the taken floor', () {
      double withNeighbour(Tier tier, {List<OmenKind> omens = const [], double factor = 1, double at = 20, bool dead = false}) =>
          troopBlow(omens: omens, factor: factor, tier: tier, set: (g, k, o) {
            final n = foeAt(g, 'orc', o.pos + Point(at, 0));
            if (dead) n.dying = 0;
          });
      for (final tier in [Tier.boss, Tier.miniBoss]) {
        final base = troopBlow(tier: tier);
        expect(withNeighbour(tier), closeToBlow(base), reason: '${tier.name}: without it');
        for (final (n, factor, share) in steps(cover)) {
          expect(withNeighbour(tier, omens: levels(cover, n), factor: factor), closeToBlow(base * (1 - share)), reason: '${tier.name} L$n ×$factor');
        }
        expect(troopBlow(omens: top(cover), factor: 2, tier: tier), closeToBlow(base), reason: '${tier.name}: alone');
        expect(withNeighbour(tier, omens: top(cover), factor: 2, at: 25), closeToBlow(base), reason: '${tier.name}: 25 px off');
        expect(withNeighbour(tier, omens: top(cover), factor: 2, at: 24), closeToBlow(base * (1 - cover.k.max)), reason: '1.5 tiles: next to it');
        expect(withNeighbour(tier, omens: top(cover), factor: 2, dead: true), closeToBlow(base), reason: '${tier.name}: a dead one');
        // With Armor at its max (0.4): 0.7 × 0.6 = 0.42, held at the floor.
        expect(withNeighbour(tier, omens: [...top(cover), ...top(OmenKind.armor)], factor: 2), closeToBlow(base * omenTakenFloor));
      }
      for (final tier in [Tier.normal, Tier.elite, Tier.highElite]) {
        expect(withNeighbour(tier, omens: top(cover), factor: 2), closeToBlow(troopBlow(tier: tier)), reason: tier.name);
      }
      expect(foeBlow(omens: top(cover), factor: 2, tier: Tier.boss, set: (g, k, o) => foeAt(g, 'orc', o.pos + const Point(20, 0))),
          closeToBlow(foeBlow(tier: Tier.boss)), reason: "the boss's own blow");
    });

    test("Renewal: a troop's strip that takes something off a monster (Spell Cutter's, Null Stone's) gives it a shield of "
        "share of its max HP, at most 25%, on the Barrier's soak; once a life; no strip, nothing", () {
      /// A knight holding Spell Cutter strikes its every-th hit on an orc with a might of its own: the orc and the game.
      (Game, Unit, Unit) cut(List<OmenKind> omens, {double factor = 1, bool might = true}) {
        final (g, k, o) = duel(omens: omens, factor: factor);
        g.givePusaka(Relic.spellCutter, type: 'knight');
        o
          ..maxHp = 100000
          ..hp = 100000;
        if (might) g.addEffect(o, Status.might, 100, k: 1.2, by: o);
        k.blows = 0;
        for (var i = 0; i < spellCutterK.every; i++) {
          blowOn(g, o, k);
        }
        return (g, k, o);
      }

      // Spell Cutter strips as its every-th hit is made, so that blow lands on the new shield.
      final blow = troopBlow();
      for (final (n, factor, share) in steps(renewal)) {
        final (g, _, o) = cut(levels(renewal, n), factor: factor);
        expect(g.effectOn(o, Status.might), isNull, reason: 'stripped');
        expect([o.renewed, o.shield, o.hp], [true, closeTo(o.maxHp * share - blow, 1e-6), 100000 - blow * (spellCutterK.every - 1)],
            reason: 'L$n ×$factor');
      }
      final (g, k, o) = cut(top(renewal), factor: 2);
      final shield = o.shield;
      // Once: a second strip after the cooldown gives none.
      g.addEffect(o, Status.might, 100, k: 1.2, by: o);
      k.fxReady = double.negativeInfinity;
      for (var i = 0; i < spellCutterK.every; i++) {
        blowOn(g, o, k);
      }
      expect(g.effectOn(o, Status.might), isNull, reason: 'stripped again');
      expect(o.shield, lessThan(shield), reason: 'no second shield: the blows broke some of the first');
      // The shield soaks a blow before its HP.
      final hp = o.hp;
      expect(blowOn(g, o, k), 0);
      expect(o.hp, hp);
      // Nothing to strip: no strip, no shield.
      final (_, _, bare) = cut(top(renewal), factor: 2, might: false);
      expect([bare.renewed, bare.shield], [false, 0]);
      // Without it.
      final (_, _, plainOrc) = cut(const []);
      expect([plainOrc.renewed, plainOrc.shield], [false, 0]);

      // Null Stone's strip (the one Spellbreaker's arrow takes too): an orc that hits the knight loses its might and
      // gets the shield.
      final (s, sk, so) = duel(omens: top(renewal), factor: 2);
      s.givePusaka(Relic.nullStone, type: 'knight');
      s.addEffect(so, Status.might, 100, k: 1.2, by: so);
      blowOn(s, sk, so);
      expect(s.effectOn(so, Status.might), isNull, reason: 'stripped');
      expect(so.shield, closeTo(so.maxHp * renewal.k.max, 1e-6));
    });

    test('Side Swing: a melee monster\'s normal attack on a troop also hits the nearest other troop within 1 tile for '
        'share of the blow, at most 30%, through its defence, from no one; none farther, none from a shooter, none on the '
        "monsters' side, and it never swings on", () {
      /// An orc (or [type]) hits knight a; knights b (at [bAt] from a) and c (at [cAt]) stand by. What a, b and c lost.
      (double, double, double) swing(List<OmenKind> omens,
          {double factor = 1, String type = 'orc', Point<double> bAt = const Point(0, 12), Point<double> cAt = const Point(0, -15)}) {
        final (g, a, o) = duel(omens: omens, factor: factor, type: type);
        Unit stand(int row, Point<double> at) => placeNow(g, 'knight', 2, row)
          ..pos = a.pos + at
          ..busyUntil = hold
          ..maxHp = 100000
          ..hp = 100000;
        final b = stand(5, bAt), c = stand(6, cAt);
        final hp = a.hp;
        blowOn(g, a, o);
        if (type != 'orc') runFor(g, 1); // a shot lands
        return (hp - a.hp, 100000 - b.hp, 100000 - c.hp);
      }

      final (base, b0, c0) = swing(const []);
      expect([b0, c0], [0, 0]);
      final orc = foeAt(plain(), 'orc', const Point(0, 0)), def = placeNow(plain(), 'knight', 2, 3).stats.def;
      for (final (n, factor, share) in steps(sideSwing)) {
        final (a, b, c) = swing(levels(sideSwing, n), factor: factor);
        expect(a, closeToBlow(base), reason: 'L$n ×$factor: its target as it was');
        expect(b, closeToBlow(hitTaken(orc.stats.dmg * share, def)), reason: 'L$n ×$factor: the nearest');
        expect(c, 0, reason: 'only one');
      }
      final (_, b1, c1) = swing(top(sideSwing), factor: 2, bAt: const Point(0, 17), cAt: const Point(0, -20));
      expect([b1, c1], [0, 0], reason: 'none within a tile');
      final (_, b2, c2) = swing(top(sideSwing), factor: 2, bAt: const Point(0, 15), cAt: const Point(0, -14));
      expect([b2, c2 > 0], [0, true], reason: 'the nearer of two');
      final (a3, b3, _) = swing(top(sideSwing), factor: 2, type: 'skeleton_archer');
      expect([a3 > 0, b3], [true, 0], reason: "a shooter's blow");
      // A troop's blow on a monster swings onto nothing.
      final (g, k, o) = duel(omens: top(sideSwing), factor: 2);
      o
        ..maxHp = 100000
        ..hp = 100000;
      final next = foeAt(g, 'orc', o.pos + const Point(0, 10))..hp = 1000;
      blowOn(g, o, k);
      expect(next.hp, 1000, reason: "the monsters' side");
    });

    test('Deathless: a silver or gold monster a blow would kill is left at 1 HP, takes no blow for share s (at most 1.2 s) '
        'and gives no gold, kill or killHeal; once a life; a normal monster, a mini boss and the boss die', () {
      for (final tier in [Tier.elite, Tier.highElite]) {
        for (final (n, factor, share) in steps(deathless)) {
          final (g, k, o) = duel(omens: levels(deathless, n), factor: factor, tier: tier);
          k
            ..hp = 50000
            ..busyUntil = hold;
          g.addEffect(k, Status.killHeal, 100, k: 0.1); // Last Stand's: a kill heals it
          o.hp = 2; // the knight's blow is at least 2 (a tenth of its 20)
          final gold = g.gold, kills = g.kills;
          final took = blowOn(g, o, k);
          expect([o.alive, o.hp, o.omenSaved], [true, 1, true], reason: '${tier.name} L$n ×$factor');
          expect(took, 1, reason: 'what it lost');
          final cap = g.effectOn(o, Status.cap)!;
          expect([cap.k, cap.omen, cap.until], [0, true, closeTo(g.t + share, 1e-9)], reason: 'no damage for its share in s');
          expect([g.gold, g.kills, k.hp], [gold, kills, 50000], reason: 'no gold, no kill, no killHeal');
          expect(g.loot.nextDouble(), Random(9).nextDouble(), reason: 'no loot die drawn');
          expect(blowOn(g, o, k), 0, reason: 'inside its window');
          runFor(g, share);
          expect(g.effectOn(o, Status.cap), isNull);
          blowOn(g, o, k);
          expect(o.alive, isFalse, reason: 'once: the next deadly blow kills it');
          expect([g.gold, g.kills], [greaterThan(gold), kills + 1]);
          expect(k.hp, greaterThan(50000), reason: 'its real death heals the killer');
        }
      }
      for (final tier in [Tier.normal, Tier.miniBoss, Tier.boss]) {
        final (g, k, o) = duel(omens: top(deathless), factor: 2, tier: tier);
        o.hp = 2;
        blowOn(g, o, k);
        expect([o.alive, o.omenSaved], [false, false], reason: tier.name);
      }
      final (g, k, o) = duel(tier: Tier.elite);
      o.hp = 2;
      blowOn(g, o, k);
      expect(o.alive, isFalse, reason: 'without it');
    });

    test("Adapt (Risk 3's guard): a troop type's normal blows in a row on one monster each cut share more, the run at most "
        "3 (share × 3, at most 30%); another type's blow starts it again; an extra hit neither counts nor is cut; in the "
        'taken floor, which holds the boss stack', () {
      /// The knight's [n] blows on the orc.
      List<double> run(List<OmenKind> omens, int n, {double factor = 1}) {
        final (g, k, o) = duel(omens: omens, factor: factor);
        o
          ..maxHp = 100000
          ..hp = 100000;
        return [for (var i = 0; i < n; i++) blowOn(g, o, k)];
      }

      final base = troopBlow();
      expect(run(const [], 5), [for (var i = 0; i < 5; i++) closeToBlow(base)]);
      for (final (n, factor, share) in steps(adapt)) {
        expect(run(levels(adapt, n), 6, factor: factor), [for (final r in [0, 1, 2, 3, 3, 3]) closeToBlow(base * (1 - share * r))],
            reason: 'L$n ×$factor: the run stops at 3');
      }
      // A soldier's blow between: the run is the soldier's (0), and the knight's next starts at 0 again.
      final (g, k, o) = duel(omens: top(adapt), factor: 2);
      o
        ..maxHp = 100000
        ..hp = 100000;
      final s = placeNow(g, 'soldier', 2, 5)
        ..pos = o.pos + const Point(0, 12)
        ..busyUntil = hold;
      final soldierBase = s.stats.dmg;
      expect([blowOn(g, o, k), blowOn(g, o, k), blowOn(g, o, k)], [for (final r in [0, 1, 2]) closeToBlow(base * (1 - 0.1 * r))]);
      expect([o.adaptType, o.adaptRun], ['knight', 2]);
      expect(blowOn(g, o, s), closeToBlow(hitTaken(soldierBase, o.stats.def)), reason: "another type's: no cut");
      expect([o.adaptType, o.adaptRun], ['soldier', 0]);
      expect(blowOn(g, o, k), closeToBlow(base), reason: 'the run starts again');
      // An axeman's splash past its target: the extra hit is never cut and never counts.
      final a = plain(omens: top(adapt), factor: 2);
      final axe = placeNow(a, 'armored_axeman', 2, 3)..busyUntil = hold;
      final ao = foeAt(a, 'orc', axe.pos + const Point(12, 0))
        ..maxHp = 100000
        ..hp = 100000;
      final p = foeAt(a, 'orc', ao.pos + const Point(0, 8))
        ..maxHp = 100000
        ..hp = 100000;
      final extras = <double>[];
      for (var i = 0; i < 4; i++) {
        final before = p.hp;
        blowOn(a, ao, axe);
        extras.add(before - p.hp);
      }
      expect(extras.toSet(), hasLength(1), reason: 'the extra hit as it was each time');
      expect([p.adaptType, p.adaptRun], [null, 0]);
      expect([ao.adaptType, ao.adaptRun], ['armored_axeman', 3]);
      // Risk 3: the boss stack at E8 (Cover 0.7 × Adapt's run 0.7 × Hard Shell 0.7 × Armor 0.6 = 0.21) held at the floor.
      final stack = [...top(cover), ...top(adapt), ...top(OmenKind.hardShell), ...top(OmenKind.armor)];
      final (b, bk, boss) = duel(omens: stack, factor: 2, tier: Tier.boss);
      boss
        ..maxHp = 100000
        ..hp = 100000
        ..shield = 1e6; // a Barrier: Hard Shell's shield
      foeAt(b, 'orc', boss.pos + const Point(20, 0)); // Cover's neighbour
      final bossBase = troopBlow(tier: Tier.boss);
      final lost = <double>[];
      for (var i = 0; i < 5; i++) {
        final before = boss.shield;
        blowOn(b, boss, bk);
        lost.add(before - boss.shield);
      }
      expect(lost, [for (var i = 0; i < 5; i++) closeToBlow(bossBase * omenTakenFloor)], reason: 'the floor holds from the first blow');
    });

    test("Warlord: a monster's blow on a troop × (1 + share), at most 25%, while the wave's boss or a mini boss lives (on "
        'the field, not raised); not its own blow; a dead or raised one gives none; in the dealt cap', () {
      final base = foeBlow();
      void bossAt(Game g, Unit k, Unit o, {Tier tier = Tier.boss, bool raised = false, bool dead = false}) {
        final b = foeAt(g, 'orc', const Point(400, 60), tier);
        if (raised) b.raisedBy = o;
        if (dead) b.dying = 0;
      }

      expect(foeBlow(set: bossAt), closeToBlow(base), reason: 'without it');
      for (final (n, factor, share) in steps(warlord)) {
        expect(foeBlow(omens: levels(warlord, n), factor: factor, set: bossAt), closeToBlow(base * (1 + share)), reason: 'L$n ×$factor');
        expect(foeBlow(omens: levels(warlord, n), factor: factor, set: (g, k, o) => bossAt(g, k, o, tier: Tier.miniBoss)),
            closeToBlow(base * (1 + share)), reason: 'a mini boss');
      }
      expect(foeBlow(omens: top(warlord), factor: 2), closeToBlow(base), reason: 'none alive');
      expect(foeBlow(omens: top(warlord), factor: 2, set: (g, k, o) => bossAt(g, k, o, dead: true)), closeToBlow(base), reason: 'dead');
      expect(foeBlow(omens: top(warlord), factor: 2, set: (g, k, o) => bossAt(g, k, o, raised: true)), closeToBlow(base), reason: 'raised');
      final bossBase = foeBlow(tier: Tier.boss);
      expect(foeBlow(omens: top(warlord), factor: 2, tier: Tier.boss), closeToBlow(bossBase), reason: "the boss's own blow");
      expect(foeBlow(omens: top(warlord), factor: 2, set: (g, k, o) {
        bossAt(g, k, o);
        o.raisedBy = foeAt(g, 'orc', const Point(420, 60)); // a raised minion gets it too
      }), closeToBlow(base * 1.25));
      // In the dealt cap: with Spite's 0.3 and Prey's 0.4 too, 1.25 × 1.3 × 1.4 = 2.275, held at 1.6.
      expect(foeBlow(omens: [...top(warlord), ...top(OmenKind.spite), ...top(OmenKind.prey)], factor: 2, set: (g, k, o) {
        bossAt(g, k, o);
        o.emberMark = (relic: Relic.emberBrand, from: 'archer', k: 1.25, until: g.t + 5);
        k.hp = k.maxHp * 0.2;
      }), closeToBlow(base * omenDealtMost));
    });

    test("Spree (Risk 4's guard): a silver or gold monster that kills a troop counts it, at most 3; its blows on troops × "
        '(1 + share × kills), at most 10% a kill (30%); a normal one, a mini boss and the boss never count; with Gloat, '
        'Triumph, Warlord and Backlash at their max the dealt cap holds the snowball', () {
      /// A monster of [tier] that strikes [n] troops of 1 HP next to the knight; then its blow on the knight.
      (double, Unit, Game) killer(List<OmenKind> omens, Tier tier, int n, {double factor = 2, void Function(Game g, Unit k, Unit o)? set}) {
        final (g, k, o) = duel(omens: omens, factor: factor, tier: tier);
        for (var i = 0; i < n; i++) {
          final v = placeNow(g, 'soldier', 4, i)
            ..pos = o.pos + const Point(0, 11) // nearer than the knight
            ..busyUntil = hold
            ..hp = 1;
          blowOn(g, v, o);
          expect(v.alive, isFalse, reason: 'kill $i');
          o.cd = 0;
        }
        set?.call(g, k, o);
        return (blowOn(g, k, o), o, g);
      }

      for (final tier in [Tier.elite, Tier.highElite]) {
        final base = foeBlow(tier: tier);
        for (final (n, factor, share) in steps(spree)) {
          for (final kills in [0, 1, 2, 3, 4]) {
            final (blow, o, _) = killer(levels(spree, n), tier, kills, factor: factor);
            expect(o.troopKills, min(kills, omenSpreeKills), reason: '${tier.name} L$n ×$factor $kills kills');
            expect(blow, closeToBlow(base * (1 + share * min(kills, omenSpreeKills))), reason: '${tier.name} L$n ×$factor $kills kills');
          }
        }
        final (blow, o, _) = killer(const [], tier, 2);
        expect([blow, o.troopKills], [closeToBlow(base), 0], reason: 'without it nothing counts');
      }
      for (final tier in [Tier.normal, Tier.miniBoss, Tier.boss]) {
        final (blow, o, _) = killer(top(spree), tier, 2);
        expect([blow, o.troopKills], [closeToBlow(foeBlow(tier: tier)), 0], reason: tier.name);
      }
      // Risk 4 at E8: the kill makes the killer heal (Gloat) and haste (Triumph); its blow with 3 kills (1.3), Warlord's
      // boss alive (1.25) and Backlash's might (1.25) is 2.03 × the blow, held at 1.6.
      final snowball = [...top(spree), ...top(OmenKind.gloat), ...top(OmenKind.triumph), ...top(warlord), ...top(backlash)];
      final (blow, o, g) = killer(snowball, Tier.elite, 3, set: (g, k, o) {
        foeAt(g, 'orc', const Point(400, 60), Tier.boss);
        g.addEffect(o, Status.might, omenBacklashTime.toDouble(), k: 1 + backlash.k.max, omen: true);
      });
      expect(o.troopKills, 3);
      expect(g.effectOn(o, Status.haste)?.omen, isTrue, reason: "Triumph's haste on it");
      expect(blow, closeToBlow(foeBlow(tier: Tier.elite) * omenDealtMost), reason: 'the dealt cap holds');
    });

    test('Vultures: a monster of the ranks its level names goes for the most hurt troop it reaches (a tie: the nearest), '
        'keeps it until it falls, leaves its reach or the monster attacks again; a shooter only among those within 1.5 '
        'tiles of its target; another rank, the boss or no troop in reach: the nearest, as before', () {
      for (final (n, tier, hurt) in [
        (1, Tier.highElite, true), (2, Tier.highElite, true), (1, Tier.elite, false), (2, Tier.elite, false), //
        (3, Tier.elite, true), (4, Tier.highElite, true), (4, Tier.normal, false), (4, Tier.miniBoss, false), (4, Tier.boss, false),
      ]) {
        final (g, a, b, o) = scene(levels(vultures, n), tier);
        expect(strike(g, o, [a, b]), hurt ? b : a, reason: 'L$n ${tier.name}');
      }
      final (g0, a0, b0, o0) = scene(const [], Tier.highElite);
      expect(strike(g0, o0, [a0, b0]), a0, reason: 'without it: the nearest');
      // A tie on HP: the nearest.
      final (gt, at, bt, ot) = scene(top(vultures), Tier.highElite);
      bt.hp = at.hp;
      expect(strike(gt, ot, [at, bt]), at);

      // It keeps its target until it attacks again: a heal on it between its attacks doesn't make it switch.
      final (g, a, b, o) = scene(top(vultures), Tier.highElite);
      expect(strike(g, o, [a, b]), b);
      look(g, o); // after its attack: it picks again (b is still the most hurt)
      expect(o.vultureFoe, b);
      b.hp = b.maxHp.toDouble();
      a.hp = a.maxHp * 0.2;
      look(g, o);
      expect(o.vultureFoe, b, reason: 'held: no attack since');
      expect(strike(g, o, [a, b]), b, reason: 'its next attack still goes to it');
      look(g, o);
      expect(o.vultureFoe, a, reason: 'after that attack, the most hurt now');
      // Out of its reach: it picks again at once.
      a.pos = o.pos + const Point(0, -30);
      look(g, o);
      expect(o.vultureFoe, b);
      // Dead: again.
      a.pos = o.pos + const Point(0, -12);
      look(g, o);
      expect(o.vultureFoe, b, reason: 'b held: a back in reach changes nothing');
      b.dying = 0;
      look(g, o);
      expect(o.vultureFoe, a);

      // A shooter (a high elite skeleton archer): only among those within 1.5 tiles of its target. Knights a at 30 px
      // (full), b 15 px below a (30% HP), c 26 px above a (10% HP): c is in its reach but too far from a.
      final (s, sa, sb, so) = scene(top(vultures), Tier.highElite, type: 'skeleton_archer', aAt: 30);
      sb.pos = sa.pos + const Point(0, 15);
      final sc = placeNow(s, 'knight', 1, 1)
        ..busyUntil = hold
        ..maxHp = 100000
        ..hp = 10000
        ..pos = sa.pos + const Point(0, -26);
      expect([s.reaches(so, sa), s.reaches(so, sb), s.reaches(so, sc)], [true, true, true]);
      so
        ..busyUntil = double.negativeInfinity
        ..cd = 0;
      s.tick(0.05);
      expect(s.shots.last.target, sb, reason: 'the most hurt near its target; c is farther from it');

      // No troop in its reach: as before, and nothing held.
      final (f, fa, fb, fo) = scene(top(vultures), Tier.highElite, aAt: 40, bAt: 40);
      fo.busyUntil = double.negativeInfinity;
      f.tick(0.05);
      expect(fo.vultureFoe, isNull);
      expect([fa.hp, fb.hp], [100000, 30000]);
    });

    test("Mana Burn (troop-side): a monster's hit takes share of the troop's max MP, at most 3%, never below 0, at most "
        'once every 0.5 s a troop; with no effects on either unit; none for a troop with no MP', () {
      /// A knight at [mp] MP takes [hits] orc blows [gap] s apart: its MP lost, against the same without Mana Burn.
      double burnt(List<OmenKind> omens, {double factor = 1, double mp = 10, int hits = 1, double gap = 0}) {
        double run(List<OmenKind> omens) {
          final (g, k, o) = duel(omens: omens, factor: factor);
          k.mp = mp;
          for (var i = 0; i < hits; i++) {
            if (i > 0) runFor(g, gap);
            expect([k.effects, o.effects], [isEmpty, isEmpty], reason: 'no effects on either');
            blowOn(g, k, o);
          }
          return k.mp;
        }

        return run(const []) - run(omens);
      }

      final full = placeNow(plain(), 'knight', 2, 3).stats.mp;
      for (final (n, factor, share) in steps(manaBurn)) {
        expect(burnt(levels(manaBurn, n), factor: factor), closeTo(full * share, 1e-9), reason: 'L$n ×$factor');
      }
      expect(burnt(top(manaBurn), factor: 2, hits: 2, gap: 0.2), closeTo(full * 0.03, 1e-9), reason: 'twice in 0.5 s: once');
      expect(burnt(top(manaBurn), factor: 2, hits: 2, gap: 0.5), closeTo(full * 0.06, 1e-9), reason: '0.5 s apart: twice');
      final (g, k, o) = duel(omens: top(manaBurn), factor: 2);
      k.mp = 0.1;
      blowOn(g, k, o);
      expect(k.mp, greaterThanOrEqualTo(0), reason: 'never below 0');
      expect(k.mp, lessThan(0.1));
    });

    test("Backlash: a troop's skill gives each monster within 2 tiles of it an omen might of 1 + share for 3 s, at most "
        '25%, the boss too, at most once a second each; none farther; in the dealt cap', () {
      for (final (omens, factor, k) in [(levels(backlash, 1), 1.0, 0.04), (top(backlash), 2.0, 0.25)]) {
        final (g, u, [a, b, boss, far]) = caster(omens, factor: factor, others: [
          (const Point(-10.0, 8), Tier.boss),
          (const Point(40.0, 0), Tier.normal),
        ]);
        g.tick(0.05);
        expect(g.log.entries.whereType<SkillCast>(), hasLength(1), reason: 'Hold Fast cast');
        for (final o in [a, b, boss]) {
          final m = g.effectOn(o, Status.might)!;
          expect([m.k, m.omen, m.by], [closeTo(1 + k, 1e-9), true, null], reason: o.tier.name);
          expect(m.until, closeTo(g.t + omenBacklashTime, 1e-9));
          expect(o.backlashAt, g.t);
        }
        expect(g.effectOn(far, Status.might), isNull, reason: '40 px off');
      }
      // Once a second: one raised 0.5 s ago gets none, one 1 s ago again.
      final (g, _, [a, b]) = caster(top(backlash));
      a.backlashAt = g.t - 0.5;
      b.backlashAt = g.t - omenBacklashEvery;
      g.tick(0.05);
      expect([g.effectOn(a, Status.might), g.effectOn(b, Status.might) != null], [null, true]);
      // Without it nothing; Counterspell's shield still comes at the same site.
      final (h, _, [c, _]) = caster(top(OmenKind.counterspell));
      h.tick(0.05);
      expect([h.effectOn(c, Status.might), h.effectOn(c, Status.absorb) != null], [null, true]);
      // In the dealt cap: Backlash's might (1.25) with Prey (1.4) is 1.75 × the blow, held at 1.6.
      final base = foeBlow();
      expect(foeBlow(omens: [...top(backlash), ...top(OmenKind.prey)], factor: 2, set: (g, k, o) {
        g.addEffect(o, Status.might, 3, k: 1.25, omen: true);
        k.hp = k.maxHp * 0.2;
      }), closeToBlow(base * omenDealtMost));
    });
  });

  group('off', () {
    test('with omens off and every level held none of the ten acts', () {
      final all = [for (final k in batch) ...top(k)];
      final troop = troopBlow(tier: Tier.boss), foe = foeBlow();
      expect(troopBlow(omens: all, factor: 2, tier: Tier.boss, set: (g, k, o) => foeAt(g, 'orc', o.pos + const Point(20, 0))),
          closeToBlow(troop), reason: 'Cover, Adapt');
      expect(foeBlow(omens: all, factor: 2, set: (g, k, o) {
        foeAt(g, 'orc', const Point(400, 60), Tier.boss);
        o
          ..tier = Tier.elite
          ..troopKills = 3;
      }), closeToBlow(foeBlow(set: (g, k, o) => o.tier = Tier.elite)), reason: 'Warlord, Spree');
      expect(foe, greaterThan(0));
      // Deathless: the elite dies.
      final (g, k, o) = duel(omens: all, factor: 2, tier: Tier.elite);
      o.hp = 2;
      blowOn(g, o, k);
      expect(o.alive, isFalse);
      // Side Swing and Mana Burn.
      final (s, a, so) = duel(omens: all, factor: 2);
      final b = placeNow(s, 'knight', 2, 5)
        ..pos = a.pos + const Point(0, 12)
        ..busyUntil = hold;
      final bhp = b.hp;
      a.mp = 10;
      blowOn(s, a, so);
      expect(b.hp, bhp);
      expect(a.mp, greaterThanOrEqualTo(10));
      // Backlash and Vultures.
      final (c, _, [ca, _]) = caster(all);
      c.tick(0.05);
      expect(c.effectOn(ca, Status.might), isNull);
      final (v, va, vb, vo) = scene(all, Tier.highElite);
      expect(strike(v, vo, [va, vb]), va);
      expect(vo.vultureFoe, isNull);
      // Renewal.
      final (r, rk, ro) = duel(omens: all, factor: 2);
      r.givePusaka(Relic.spellCutter, type: 'knight');
      ro
        ..maxHp = 100000
        ..hp = 100000;
      r.addEffect(ro, Status.might, 100, k: 1.2, by: ro);
      rk.blows = 0;
      for (var i = 0; i < spellCutterK.every; i++) {
        blowOn(r, ro, rk);
      }
      expect(r.effectOn(ro, Status.might), isNull);
      expect([ro.renewed, ro.shield], [false, 0]);
    });
  });
}
