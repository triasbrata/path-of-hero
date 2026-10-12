// Shadow batch G-3B (decisions-log 239, lib/omen.dart; catalog-bayangan-v2 §3.3; docs/units-and-combat.md "Bayangan on
// the field", docs/loot-items-relics.md "Bayangan"): seven more Legenda kinds. Their rows (the Legenda pool alone, among
// G-1B's and G-2B's in the pool's order; numbers, icons, the troop-side flag, needs), the cap at E8 and the HUD number
// equal to it, and with omens on one test a kind: Spell Ward cuts a troop's skill blow on a monster and Holy Ward a
// Priest's smite on a skeleton (both in the taken floor); Hero Hunt raises a monster's blow on a Hero, Rider Rush an orc
// rider's first hit and Dusk every monster's but the boss's once the crowd has been all in for 30 s (all three in the
// dealt cap); Oathbane gives the boss and a mini boss more HP while an oath is held; Last Gasp heals the boss or a mini
// boss once at 40% HP. With omens off none of it acts.
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show logLine;

import 'hero_skill_helpers.dart';

const spellWard = OmenKind.spellWard, holyWard = OmenKind.holyWard, heroHunt = OmenKind.heroHunt, oathbane = OmenKind.oathbane;
const lastGasp = OmenKind.lastGasp, riderRush = OmenKind.riderRush, dusk = OmenKind.dusk;

/// The batch, in the Legenda pool's order.
const batch = [spellWard, holyWard, heroHunt, oathbane, lastGasp, riderRush, dusk];

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
double foeBlow(
    {List<OmenKind> omens = const [], double factor = 1, Tier tier = Tier.normal, String type = 'orc', void Function(Game, Unit k, Unit o)? set}) {
  final (g, k, o) = duel(omens: omens, factor: factor, tier: tier, type: type);
  set?.call(g, k, o);
  return blowOn(g, k, o);
}

/// The knight's blow on the monster of a fresh [duel] (the monster with HP to spare), both [set] up so.
double troopBlow({List<OmenKind> omens = const [], double factor = 1, Tier tier = Tier.normal, String type = 'orc'}) {
  final (g, k, o) = duel(omens: omens, factor: factor, tier: tier, type: type);
  o
    ..maxHp = 100000
    ..hp = 100000;
  return blowOn(g, o, k);
}

/// An archer's skill shot ([Shot.special], [Hit.skill]) of [dmg] on a monster of [type] with HP to spare, landing this
/// tick: what it took.
double skillShot({List<OmenKind> omens = const [], double factor = 1, String type = 'orc', double dmg = 100}) {
  final g = plain(omens: omens, factor: factor);
  final a = placeNow(g, 'archer', 2, 3)..busyUntil = hold;
  final o = foeAt(g, type, a.pos + const Point(40, 0))
    ..maxHp = 100000
    ..hp = 100000;
  g.shots.add(Shot.special(a, o, o.pos - const Point(1.0, 0), dmg: dmg, speed: 200));
  g.tick(0.05);
  return 100000 - o.hp;
}

/// A Priest's smite on a dark monster of [type] (HP to spare) 40 px off, nobody of its own hurt: what it took.
double smite({List<OmenKind> omens = const [], double factor = 1, String type = 'skeleton'}) {
  final g = plain(omens: omens, factor: factor);
  final p = placeNow(g, 'priest', 2, 3)..cd = 0;
  final o = foeAt(g, type, p.pos + const Point(40, 0))
    ..maxHp = 100000
    ..hp = 100000;
  g.tick(0.05);
  return 100000 - o.hp;
}

/// A PNG's width and height, from its header.
(int, int) pngSize(File f) {
  final b = f.readAsBytesSync();
  int at(int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
  return (at(16), at(20));
}

/// A blow's damage [v] to within float noise.
Matcher closeToBlow(double v) => closeTo(v, 1e-9);

void main() {
  tearDown(() => omensOn = omensDefault);

  group('the rows', () {
    test("the seven sit in the Legenda pool alone, among G-1B's and G-2B's after Barrier and Escort (today's seven until "
        "the Legenda cut-over), in the pool's order; the Langka and Epik pools as they were; their numbers, titles, "
        "constants, troop-side flag, needs and icons (an existing sheet's mapped cell, each unique)", () {
      final pool = omenPool(Rarity.legenda);
      expect(pool, [
        OmenKind.shield, OmenKind.guard, spellWard, OmenKind.scatter, holyWard, OmenKind.cover, heroHunt, OmenKind.thornproof, //
        OmenKind.blight, OmenKind.renewal, //
        OmenKind.rust, OmenKind.sideSwing, oathbane, OmenKind.veterans, lastGasp, riderRush, OmenKind.hardy, OmenKind.unbowed, //
        OmenKind.executioner, OmenKind.spite, OmenKind.deathless, OmenKind.blunt, OmenKind.adapt, OmenKind.warlord, //
        OmenKind.spree, OmenKind.vultures, OmenKind.manaBurn, dusk, OmenKind.backlash, OmenKind.horde,
      ], reason: "catalog-bayangan-v2 §2's order since the Legenda cut-over (batch G-3: Blight in, five of today's seven out)");
      expect(pool.where(batch.contains), batch);
      expect([for (final k in batch) k.title], ['Spell Ward', 'Holy Ward', 'Hero Hunt', 'Oathbane', 'Last Gasp', 'Rider Rush', 'Dusk']);
      expect(omenPool(Rarity.langka), hasLength(30));
      expect(omenPool(Rarity.epik), hasLength(30));
      expect([...omenPool(Rarity.langka), ...omenPool(Rarity.epik)].where(batch.contains), isEmpty);
      expect(omenOrder, OmenKind.values);
      expect(OmenKind.values.take(OmenKind.values.indexOf(OmenKind.muster) + 1).where(batch.contains), isEmpty, reason: 'after the Epik kinds');
      for (final k in batch) {
        expect(k.tiers, {Rarity.legenda}, reason: '$k');
        expect(k.live, isTrue, reason: '$k');
        expect([k.debuff, k.troopSide], [false, false], reason: '$k: none is troop-side (catalog-bayangan-v2 §5.1)');
        expect([k.byL, k.who, k.steps], [isEmpty, isEmpty, 0], reason: '$k');
      }
      // Their counters: Wrath Psalm (Holy Ward) came with batch G-3 (pusaka_legenda3_test.dart); the oaths (Spell Ward,
      // Hero Hunt, Oathbane, Rider Rush, Dusk) with G-4 (pusaka_legenda4_test.dart); Last Gasp is faces only.
      expect({for (final k in batch) if (k.answers.isNotEmpty) k: k.answers}, {
        spellWard: [Relic.spellOath],
        holyWard: [Relic.wrathPsalm],
        heroHunt: [Relic.kingsOath],
        oathbane: [Relic.bloodOath],
        riderRush: [Relic.vanguardOath],
        dusk: [Relic.wallOath],
      });
      expect({for (final k in batch) k: k.k}, {
        spellWard: (perE: 0.06, max: 0.36),
        holyWard: (perE: 0.06, max: 0.4),
        heroHunt: (perE: 0.08, max: 0.5),
        oathbane: (perE: 0.06, max: 0.3),
        lastGasp: (perE: 0.03, max: 0.15),
        riderRush: (perE: 0.12, max: 0.5),
        dusk: (perE: 0.04, max: 0.3),
      });
      expect([omenLastGaspAt, omenRiderRushType, omenDuskAfter], [40, 'orc_rider', 30]);
      expect({omenMusterBit, omenLastRageBit, omenSecondSkinBit, omenLastGaspBit}, hasLength(4), reason: 'a bit each on Unit.belowHp');
      expect({for (final k in batch) if (k.needs.isNotEmpty) k: k.needs}, {
        spellWard: {OmenNeed.mpSkill},
        holyWard: {OmenNeed.healer},
        heroHunt: {OmenNeed.hero},
        oathbane: {OmenNeed.oath},
      });
      // The cells mapped first (shots/cat-G3B/map-01..08): each its own sprite, nothing of a neighbour's in it.
      expect({for (final k in batch) k: (k.icon!.sheet, k.icon!.x, k.icon!.y, k.icon!.size, k.icon!.tint)}, {
        spellWard: ('ui_icons.png', 208, 16, 16, null),
        holyWard: ('tiny_skeleton_idle.png', 42, 35, 28, tintViolet),
        heroHunt: ('ui_icons.png', 64, 16, 16, tintRed),
        oathbane: ('relic_oathOfOne.png', 0, 0, 32, tintDarkRed),
        lastGasp: ('relic_lastStand.png', 0, 0, 32, tintDarkRed),
        riderRush: ('tiny_orc_rider_idle.png', 37, 27, 32, null),
        dusk: ('ui_icons.png', 64, 0, 16, tintViolet),
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

    test('needs: Spell Ward acts on an army with a troop skill that costs MP, Holy Ward with a healer type, Hero Hunt with '
        'a Hero, Oathbane with an oath held; Last Gasp, Rider Rush and Dusk always', () {
      final g = bareGame(Random(1))..skills = false;
      Map<OmenKind, bool> acts() => {for (final k in batch) k: omenCanAct(k, g.omenMet)};
      expect(acts(), {spellWard: false, holyWard: false, heroHunt: false, oathbane: false, lastGasp: true, riderRush: true, dusk: true},
          reason: 'no army');
      final k = placeNow(g, 'knight', 2, 3);
      expect([acts()[spellWard], acts()[holyWard], acts()[heroHunt]], [true, false, false], reason: "a knight's Circle Slash");
      g.givePusaka(Relic.vowSilence, type: 'knight', stars: 1);
      expect(acts()[spellWard], isFalse, reason: 'its type casts none');
      placeNow(g, 'priest', 2, 4);
      expect([acts()[spellWard], acts()[holyWard]], [true, true], reason: "a priest: a healer, and its skill's MP");
      k.hero = true;
      expect(acts()[heroHunt], isTrue, reason: 'a Hero');
      g.givePusaka(Relic.alliance);
      expect(acts()[oathbane], isTrue, reason: 'an oath held');
    });

    test("the Legenda pool's order: a take's overflow follows it (Escort's into Spell Ward, Spell Ward's into Scatter, "
        "Scatter's into Holy Ward, Cover's into Hero Hunt, Side Swing's into Oathbane, Veterans' into Last Gasp, Mana "
        "Burn's into Dusk, Dusk's into Backlash, ...); a face past the tilt comes from the whole pool, the batch among "
        'them, and the four that need something never on an army without it', () {
      final pool = omenPool(Rarity.legenda);
      expect(omenPlace(levels(OmenKind.guard, 2), OmenKind.guard, pool, 3), [OmenKind.guard, OmenKind.guard, spellWard]);
      for (final (face, next) in [
        (spellWard, OmenKind.scatter), (OmenKind.scatter, holyWard), (holyWard, OmenKind.cover), (OmenKind.cover, heroHunt), //
        (heroHunt, OmenKind.thornproof), (OmenKind.sideSwing, oathbane), (oathbane, OmenKind.veterans), (OmenKind.veterans, lastGasp), //
        (lastGasp, riderRush), (riderRush, OmenKind.hardy), (OmenKind.manaBurn, dusk), (dusk, OmenKind.backlash),
      ]) {
        expect(omenPlace(levels(face, 3), face, pool, 3), [face, next, next], reason: '$face');
      }
      // Four troop-side kinds held (Wound, Sunder, Scar, Fade): Mana Burn has no room, and its levels go on to Dusk.
      final four = [OmenKind.wound, OmenKind.sunder, OmenKind.scar, OmenKind.fade];
      expect(omenPlace(four, OmenKind.manaBurn, pool, 3), levels(dusk, 3), reason: 'past Mana Burn');
      // Dragon Crown (Legenda, its counter Barrier): past the tilt each kind of the pool as likely.
      final faces = {for (var i = 0; i < 6800; i++) omenFace(Relic.dragonCrown, null, omenTilt + (1 - omenTilt) * (i + 0.5) / 6800)};
      expect(faces, pool.toSet());
      expect(faces, containsAll(batch));
      // An army that meets nothing: the four that need something are never a face (Barrier still comes by the tilt).
      final none = {for (var i = 0; i < 6800; i++) omenFace(Relic.dragonCrown, null, (i + 0.5) / 6800, (k) => omenCanAct(k, const {}))};
      expect(none.intersection({spellWard, holyWard, heroHunt, oathbane}), isEmpty);
      expect(none, containsAll([lastGasp, riderRush, dusk]));
    });
  });

  group('the HUD numbers', () {
    setUp(() => omensOn = true);

    test('at E8 each shows its capped share (its max), the one its hooks read; every line short and in English', () {
      final g = plain(omens: [for (final k in batch) ...top(k)], factor: 2);
      foeAt(g, 'orc', const Point(300, 60)); // a wave on: the HUD shows its frozen factor
      expect(g.omenShownFactor, 2);
      for (final k in batch) {
        final v = omenShown(k, omenCap, 8);
        expect(v.x, k.k.max, reason: '$k: E8 is past its max');
        expect(g.omenK(k), v.x, reason: '$k: the hooks read the same');
        expect(g.omenShownK(k), v.x, reason: '$k');
        expect(g.omenEffect(k), contains('${omenPercent(v.x)}%'), reason: '$k');
      }
      expect({for (final k in batch) k: g.omenEffect(k)}, {
        spellWard: 'Troop skills do 36% less damage to monsters.',
        holyWard: 'Skeletons take 40% less damage from Priests.',
        heroHunt: 'Monsters deal 50% more damage to Heroes.',
        oathbane: 'While you hold an Oath, boss and mini boss have 30% more HP.',
        lastGasp: 'Once, at 40% HP, boss and mini boss heal 15% HP.',
        riderRush: "An Orc Rider's first hit deals 50% more.",
        dusk: '30s after the crowd is all in, monsters (not bosses) deal 30% more.',
      });
      expect([for (final k in batch) plain(omens: levels(k, 1)).omenEffect(k)], [
        'Troop skills do 6% less damage to monsters.',
        'Skeletons take 6% less damage from Priests.',
        'Monsters deal 8% more damage to Heroes.',
        'While you hold an Oath, boss and mini boss have 6% more HP.',
        'Once, at 40% HP, boss and mini boss heal 3% HP.',
        "An Orc Rider's first hit deals 12% more.",
        '30s after the crowd is all in, monsters (not bosses) deal 4% more.',
      ]);
      for (final k in batch) {
        final line = g.omenLine(k);
        expect(line.length, lessThanOrEqualTo(80), reason: line);
        expect(line.codeUnits.every((c) => c < 128), isTrue, reason: line);
      }
      expect(logLine(OmenDusk(90, 0, level: 4, share: 0.3)), 'Dusk: monsters (not bosses) deal 30% more');
    });
  });

  group('on', () {
    setUp(() => omensOn = true);

    test("Spell Ward: a troop's skill blow on a monster × (1 − share), at most 36%; a normal blow as it was; in the taken "
        'floor', () {
      final base = skillShot();
      expect(base, closeToBlow(100 - foeAt(plain(), 'orc', const Point(0, 0)).stats.def), reason: 'the shot lands whole');
      for (final (n, factor, share) in steps(spellWard)) {
        expect(skillShot(omens: levels(spellWard, n), factor: factor), closeToBlow(base * (1 - share)), reason: 'L$n ×$factor');
      }
      expect(troopBlow(omens: top(spellWard), factor: 2), closeToBlow(troopBlow()), reason: "a knight's normal blow");
      // With Armor at its max (0.4): 0.64 × 0.6 = 0.384, held at the floor.
      expect(skillShot(omens: [...top(spellWard), ...top(OmenKind.armor)], factor: 2), closeToBlow(base * omenTakenFloor));
      // A monster's blow on a troop: nothing.
      expect(foeBlow(omens: top(spellWard), factor: 2), closeToBlow(foeBlow()));
    });

    test("Holy Ward: a Priest's smite on a skeleton kind × (1 − share), at most 40%; on the necromancer (dark, no "
        "skeleton) and a knight's blow on a skeleton as they were; in the taken floor", () {
      for (final type in ['skeleton', 'armored_skeleton']) {
        final base = smite(type: type);
        expect(base, greaterThan(0), reason: '$type: smitten');
        for (final (n, factor, share) in steps(holyWard)) {
          expect(smite(omens: levels(holyWard, n), factor: factor, type: type), closeToBlow(base * (1 - share)), reason: '$type L$n ×$factor');
        }
        // With Armor at its max (0.4): 0.6 × 0.6 = 0.36, held at the floor.
        expect(smite(omens: [...top(holyWard), ...top(OmenKind.armor)], factor: 2, type: type), closeToBlow(base * omenTakenFloor));
      }
      expect(smite(omens: top(holyWard), factor: 2, type: boss), closeToBlow(smite(type: boss)), reason: 'the necromancer');
      expect(troopBlow(omens: top(holyWard), factor: 2, type: 'skeleton'), closeToBlow(troopBlow(type: 'skeleton')), reason: "a knight's blow");
    });

    test("Hero Hunt: a monster's blow on a Hero × (1 + share), at most 50%; on another troop as it was; in the dealt cap",
        () {
      void hero(Game g, Unit k, Unit o) => k.hero = true;
      final base = foeBlow(set: hero);
      for (final (n, factor, share) in steps(heroHunt)) {
        expect(foeBlow(omens: levels(heroHunt, n), factor: factor, set: hero), closeToBlow(base * (1 + share)), reason: 'L$n ×$factor');
      }
      expect(foeBlow(omens: top(heroHunt), factor: 2), closeToBlow(foeBlow()), reason: 'not a Hero');
      // In the dealt cap: with Prey's 0.4 too, 1.5 × 1.4 = 2.1, held at 1.6.
      expect(foeBlow(omens: [...top(heroHunt), ...top(OmenKind.prey)], factor: 2, set: (g, k, o) {
        hero(g, k, o);
        k.hp = k.maxHp * 0.2;
      }), closeToBlow(base * omenDealtMost));
    });

    test("Oathbane: while an oath is held, the boss's and a mini boss's max HP × (1 + share), at most 30%, a raised one's "
        'too; none without an oath, nor a silver or gold one', () {
      double hpOf(Tier tier, {List<OmenKind> omens = const [], double factor = 1, Relic? oath = Relic.alliance, bool raised = false}) {
        final g = plain(omens: omens, factor: factor);
        if (oath != null) g.givePusaka(oath);
        return g.spawnStats('orc', tier, raised: raised).hp.toDouble();
      }

      for (final tier in [Tier.boss, Tier.miniBoss]) {
        final base = hpOf(tier);
        expect(hpOf(tier, oath: null), base, reason: '${tier.name}: the oath gives no HP of its own here');
        for (final (n, factor, share) in steps(oathbane)) {
          expect(hpOf(tier, omens: levels(oathbane, n), factor: factor), closeTo(base * (1 + share), 0.5), reason: '${tier.name} L$n ×$factor');
        }
        expect(hpOf(tier, omens: top(oathbane), factor: 2, oath: Relic.oathOfOne), closeTo(base * 1.3, 0.5), reason: 'Oath of One');
        expect(hpOf(tier, omens: top(oathbane), factor: 2, oath: null), base, reason: 'no oath');
        expect(hpOf(tier, omens: top(oathbane), factor: 2, raised: true), closeTo(hpOf(tier, raised: true) * 1.3, 0.5), reason: 'raised');
      }
      for (final tier in [Tier.normal, Tier.elite, Tier.highElite]) {
        expect(hpOf(tier, omens: top(oathbane), factor: 2), hpOf(tier), reason: tier.name);
      }
      // A boss that comes on has it.
      final g = plain(omens: top(oathbane), factor: 2)..givePusaka(Relic.alliance);
      expect(foeAt(g, 'orc', const Point(300, 60), Tier.boss).maxHp, closeTo(hpOf(Tier.boss) * 1.3, 0.5));
    });

    test('Last Gasp: the boss or a mini boss at or under 40% HP for the first time heals share of its max HP, at most 15%, '
        'once; a blow that kills it, a silver or gold one and a second time nothing', () {
      /// A monster of [tier] at [at] of 1000 HP takes an arrow of [took] HP (a skill's, [Shot.special]): the monster.
      Unit shot(Game g, Unit o, Unit a, double took) {
        g.shots.add(Shot.special(a, o, o.pos - const Point(1.0, 0), dmg: took + o.stats.def, speed: 200));
        g.tick(0.05);
        return o;
      }

      (Game, Unit, Unit) scene(Tier tier, {List<OmenKind> omens = const [], double factor = 1, double at = 450}) {
        final g = plain(omens: omens, factor: factor);
        final a = placeNow(g, 'archer', 2, 3)..busyUntil = hold;
        final o = foeAt(g, 'orc', a.pos + const Point(40, 0), tier)
          ..maxHp = 1000
          ..hp = at;
        return (g, o, a);
      }

      for (final tier in [Tier.boss, Tier.miniBoss]) {
        for (final (n, factor, share) in steps(lastGasp)) {
          final (g, o, a) = scene(tier, omens: levels(lastGasp, n), factor: factor);
          shot(g, o, a, 40);
          expect(o.hp, closeTo(410, 1e-9), reason: '${tier.name} L$n ×$factor: over 40%, nothing');
          shot(g, o, a, 20);
          expect(o.hp, closeTo(390 + 1000 * share, 1e-9), reason: '${tier.name} L$n ×$factor: at 39%');
          expect(o.belowHp & (1 << omenLastGaspBit), isNot(0));
          final hp = o.hp;
          o.hp = 300;
          shot(g, o, a, 100);
          expect(o.hp, closeTo(200, 1e-9), reason: 'once: under it again, nothing ($hp before)');
        }
        final (g, o, a) = scene(tier, omens: top(lastGasp), factor: 2, at: 50);
        shot(g, o, a, 100);
        expect(o.alive, isFalse, reason: '${tier.name}: the killing blow heals nothing');
        final (h, ho, ha) = scene(tier);
        shot(h, ho, ha, 60);
        expect(ho.hp, closeTo(390, 1e-9), reason: '${tier.name}: without it');
      }
      for (final tier in [Tier.normal, Tier.elite, Tier.highElite]) {
        final (g, o, a) = scene(tier, omens: top(lastGasp), factor: 2);
        shot(g, o, a, 60);
        expect(o.hp, closeTo(390, 1e-9), reason: tier.name);
      }
    });

    test("Rider Rush: an orc rider's first blow on a troop × (1 + share), at most 50%, once; its later blows and another "
        "type's as they were; with no level nothing is spent; in the dealt cap", () {
      final base = foeBlow(type: 'orc_rider');
      for (final (n, factor, share) in steps(riderRush)) {
        final (g, k, o) = duel(omens: levels(riderRush, n), factor: factor, type: 'orc_rider');
        expect(blowOn(g, k, o), closeToBlow(base * (1 + share)), reason: 'L$n ×$factor: its first');
        expect(o.rushed, isTrue);
        expect(blowOn(g, k, o), closeToBlow(base), reason: 'L$n ×$factor: its second');
      }
      expect(foeBlow(omens: top(riderRush), factor: 2), closeToBlow(foeBlow()), reason: "an orc's first");
      final (g, k, o) = duel(type: 'orc_rider');
      blowOn(g, k, o);
      expect(o.rushed, isFalse, reason: 'no level: nothing spent');
      // In the dealt cap: with Prey's 0.4 too, 1.5 × 1.4 = 2.1, held at 1.6.
      expect(foeBlow(omens: [...top(riderRush), ...top(OmenKind.prey)], factor: 2, type: 'orc_rider', set: (g, k, o) => k.hp = k.maxHp * 0.2),
          closeToBlow(base * omenDealtMost));
    });

    test("Dusk: once it has fallen, a monster's blow on a troop × (1 + share), at most 30%; not the boss's or a mini boss's "
        'own; none before; in the dealt cap', () {
      void fallen(Game g, Unit k, Unit o) => g.duskOn = true;
      final base = foeBlow(set: fallen);
      for (final (n, factor, share) in steps(dusk)) {
        expect(foeBlow(omens: levels(dusk, n), factor: factor, set: fallen), closeToBlow(base * (1 + share)), reason: 'L$n ×$factor');
      }
      expect(foeBlow(omens: top(dusk), factor: 2), closeToBlow(base), reason: 'not fallen yet');
      for (final tier in [Tier.boss, Tier.miniBoss]) {
        expect(foeBlow(omens: top(dusk), factor: 2, tier: tier, set: fallen), closeToBlow(foeBlow(tier: tier)), reason: tier.name);
      }
      for (final tier in [Tier.elite, Tier.highElite]) {
        expect(foeBlow(omens: top(dusk), factor: 2, tier: tier, set: fallen), closeToBlow(foeBlow(tier: tier) * 1.3), reason: tier.name);
      }
      // In the dealt cap: with Hero Hunt's 0.5 too, 1.3 × 1.5 = 1.95, held at 1.6.
      expect(foeBlow(omens: [...top(dusk), ...top(heroHunt)], factor: 2, set: (g, k, o) {
        fallen(g, k, o);
        k.hero = true;
      }), closeToBlow(foeBlow(set: (g, k, o) => k.hero = true) * omenDealtMost));
    });

    test('Dusk falls 30 s after the wave\'s last crowd monster came on (not the boss or a mini boss, an escort nor a '
        "Guard's), once, with a line in the battle log; it never moves the spawns; the next wave waits again", () {
      // A plain wave (22), a boss wave (50: its last necro healer walks behind the boss and its escort, a crowd monster)
      // and a mini boss wave (51) with its escort and two Guards. Only the queue's last 12 are spawned (the rest dropped
      // from its front, the spawn count moved on): the tail holds the slot's group.
      for (final wave in [22, 50, 51]) {
        final g = plain(omens: [...top(dusk), ...levels(OmenKind.guard, 3)], factor: 2)..wave = wave - 1;
        final spawns = <(Unit, double)>[];
        g.listeners.add((e) {
          if (e is MonsterSpawned && !e.raised) spawns.add((g.units.last, e.t));
        });
        g.startWave();
        final full = [...g.queue], drop = g.queue.length - 12;
        g
          ..queue.removeRange(0, drop)
          ..waveSpawned = drop;
        double? on;
        while (g.queue.isNotEmpty || on == null) {
          g.tick(0.1);
          for (final u in g.enemies) {
            u.busyUntil = hold; // they stand: the wave stays on
          }
          if (g.duskOn) on ??= g.t;
          if (g.t > 400) fail('w$wave: Dusk never fell');
        }
        final gaps = [for (var i = 1; i < spawns.length; i++) spawns[i].$2 - spawns[i - 1].$2];
        bool crowd(Unit u) => u.tier != Tier.boss && u.tier != Tier.miniBoss && u.escortOf == null && u.guardOf == null;
        final inAt = spawns.where((s) => crowd(s.$1)).last.$2;
        expect(spawns, hasLength(12), reason: 'w$wave');
        expect(on, greaterThanOrEqualTo(inAt + omenDuskAfter - 1e-9), reason: 'w$wave: not before');
        expect(on, lessThan(inAt + omenDuskAfter + 0.1 + 1e-9), reason: 'w$wave: the tick it is due');
        final lines = g.log.entries.whereType<OmenDusk>().toList();
        expect([for (final e in lines) (e.level, e.share, e.wave)], [(4, g.omenK(dusk), wave)], reason: 'w$wave: once, its share at the wave\'s frozen factor');
        expect(g.omenK(dusk), dusk.k.perE * 4, reason: 'the factor 1 frozen at the start: no army over the cap');
        if (wave == 51) {
          expect([for (final (u, _) in spawns) if (!crowd(u)) (u.tier == Tier.miniBoss, u.escortOf != null, u.guardOf != null)], [
            (true, false, false), for (var i = 0; i < escortHealers + escortSummoners; i++) (false, true, false),
            (false, false, true), (false, false, true),
          ], reason: 'the mini boss, its escort, two Guards');
          expect(spawns.indexWhere((s) => !crowd(s.$1)), greaterThan(0));
          expect(spawns.lastWhere((s) => crowd(s.$1)).$2, lessThan(spawns.last.$2), reason: 'the crowd in before the slot came');
        }
        if (wave == 50) expect(spawns.last.$1.type, necroHealer, reason: 'the healer behind the boss is the last crowd monster');
        // The spawns as without it: the same gaps from the same queue.
        final h = plain(omens: levels(OmenKind.guard, 3), factor: 2)..wave = wave - 1;
        final times = <double>[];
        h.listeners.add((e) {
          if (e is MonsterSpawned && !e.raised) times.add(e.t);
        });
        h.startWave();
        expect(h.queue, full, reason: 'w$wave: the same queue');
        h
          ..queue.removeRange(0, drop)
          ..waveSpawned = drop;
        while (h.queue.isNotEmpty) {
          h.tick(0.1);
          for (final u in h.enemies) {
            u.busyUntil = hold;
          }
        }
        expect([for (var i = 1; i < times.length; i++) times[i] - times[i - 1]], gaps, reason: 'w$wave: the spawn pace');
        // The next wave waits for its crowd again.
        g.units.removeWhere((u) => u.side == Side.enemy);
        g.startWave();
        expect(g.duskOn, isFalse, reason: 'w$wave: afresh');
      }
    });

    test('Dusk with no level: it never falls and says nothing', () {
      final g = plain()..wave = 21;
      g
        ..startWave()
        ..queue.removeRange(0, g.queue.length - 2)
        ..waveSpawned = 0;
      for (var i = 0; i < 500; i++) {
        g.tick(0.1);
        for (final u in g.enemies) {
          u.busyUntil = hold;
        }
      }
      expect([g.duskOn, g.log.entries.whereType<OmenDusk>()], [false, isEmpty]);
    });
  });

  group('off', () {
    setUp(() => omensOn = false); // its own switch: it ran on an earlier test's reset (decisions-log 329)

    test('with omens off and every level held none of the seven acts', () {
      final all = [for (final k in batch) ...top(k)];
      expect(skillShot(omens: all, factor: 2), closeToBlow(skillShot()), reason: 'Spell Ward');
      expect(smite(omens: all, factor: 2), closeToBlow(smite()), reason: 'Holy Ward');
      expect(foeBlow(omens: all, factor: 2, set: (g, k, o) {
        k.hero = true;
        g.duskOn = true;
      }), closeToBlow(foeBlow(set: (g, k, o) => k.hero = true)), reason: 'Hero Hunt, Dusk');
      final (g, k, o) = duel(omens: all, factor: 2, type: 'orc_rider');
      expect(blowOn(g, k, o), closeToBlow(foeBlow(type: 'orc_rider')), reason: 'Rider Rush');
      expect(o.rushed, isFalse);
      final b = plain(omens: all, factor: 2)..givePusaka(Relic.alliance);
      expect(b.spawnStats('orc', Tier.boss).hp, plain().spawnStats('orc', Tier.boss).hp, reason: 'Oathbane');
      // Last Gasp: a boss under 40% heals nothing.
      final a = placeNow(b, 'archer', 2, 3)..busyUntil = hold;
      final boss = foeAt(b, 'orc', a.pos + const Point(40, 0), Tier.boss)
        ..maxHp = 1000
        ..hp = 450;
      b.shots.add(Shot.special(a, boss, boss.pos - const Point(1.0, 0), dmg: 100 + boss.stats.def, speed: 200));
      b.tick(0.05);
      expect(boss.hp, closeTo(350, 1e-9));
      // Dusk: a wave's crowd all in long ago, nothing falls and nothing is said.
      final w = plain(omens: all, factor: 2)..wave = 21;
      w
        ..startWave()
        ..queue.removeRange(0, w.queue.length - 2)
        ..waveSpawned = 0;
      for (var i = 0; i < 500; i++) {
        w.tick(0.1);
        for (final u in w.enemies) {
          u.busyUntil = hold;
        }
      }
      expect([w.duskOn, w.log.entries.whereType<OmenDusk>()], [false, isEmpty]);
    });
  });
}
