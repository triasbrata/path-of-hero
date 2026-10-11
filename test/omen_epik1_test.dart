// Shadow batch E-1B (decisions-log 210, lib/omen.dart; catalog-bayangan-v2 §3.2; docs/units-and-combat.md "Bayangan on
// the field", docs/loot-items-relics.md "Bayangan"): the first ten Epik kinds. Their rows (the Epik pool alone, after
// today's seven in the pool's order; numbers, icons, the troop-side flag, needs), the cap at E8 and the HUD number equal
// to it, and with omens on one test a kind: Dark Hymn and Bone Arrows raise a monster healer's heal and a skeleton
// archer's damage in its stats (outside the dealt cap); Arrow Ward gives a monster that comes on a shot ward (outside the
// taken floor); Enrage raises a monster's blow after 10 s of fighting; Hunker cuts a troop's blow on a held monster (in
// the taken floor); Counterspell shields the high elites near a troop that casts, at the three cast sites, once per 6 s;
// Wear Down adds a share of the troop's max HP to a monster's normal attack, never more than half the blow (the Risk-1
// guard); Envy raises a monster's blow on a boosted troop; Zeal gives a monster a monster healer healed a might; Muster
// gives the monsters near a boss under 60% a might, once. Enrage, Envy, Wear Down, Zeal and Muster stop at the dealt cap
// together. With omens off none of it acts.
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

const darkHymn = OmenKind.darkHymn, boneArrows = OmenKind.boneArrows, arrowWard = OmenKind.arrowWard;
const enrage = OmenKind.enrage, hunker = OmenKind.hunker, counterspell = OmenKind.counterspell;
const wearDown = OmenKind.wearDown, envy = OmenKind.envy, zeal = OmenKind.zeal, muster = OmenKind.muster;

/// The batch, in the Epik pool's order.
const batch = [darkHymn, boneArrows, arrowWard, enrage, hunker, counterspell, wearDown, envy, zeal, muster];

/// Today's seven, whole in the Legenda pool until its cut-over (Epik's kept two: batch E-3).
const seven = [OmenKind.armor, OmenKind.haste, OmenKind.mend, OmenKind.thorns, OmenKind.wound, OmenKind.shield, OmenKind.guard];

/// [n] levels of [kind].
List<OmenKind> levels(OmenKind kind, int n) => List.filled(n, kind);

/// [kind] at its most levels: at the Beban factor 2 that is E8, past every kind's max.
List<OmenKind> top(OmenKind kind) => levels(kind, omenCap);

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

/// What a shot took off [u]: [by] fires once now, and the shot flies until it lands.
double shotOn(Game g, Unit u, Unit by) {
  final hp = u.hp;
  blowOn(g, u, by);
  for (var i = 0; i < 40 && g.shots.isNotEmpty; i++) {
    g.tick(0.05);
  }
  return hp - u.hp;
}

/// A [troop] and a monster of [tier] beside it, both standing; the enemy holding [omens] at [factor]. The troop has
/// HP to spare ([big]: 100000 max HP).
(Game, Unit, Unit) duel({List<OmenKind> omens = const [], double factor = 1, String troop = 'knight', Tier tier = Tier.normal, bool big = true}) {
  final g = plain(omens: omens, factor: factor);
  final k = placeNow(g, troop, 2, 3)..busyUntil = hold;
  if (big) {
    k
      ..maxHp = 100000
      ..hp = 100000;
  }
  final o = foeAt(g, 'orc', k.pos + const Point(12, 0), tier);
  return (g, k, o);
}

/// The monster's blow on the troop of a fresh [duel], both [set] up so.
double foeBlow(
    {List<OmenKind> omens = const [],
    double factor = 1,
    String troop = 'knight',
    Tier tier = Tier.normal,
    bool big = true,
    void Function(Game, Unit k, Unit o)? set}) {
  final (g, k, o) = duel(omens: omens, factor: factor, troop: troop, tier: tier, big: big);
  set?.call(g, k, o);
  return blowOn(g, k, o);
}

/// The troop's blow on the monster of a fresh [duel] (the monster with HP to spare), both [set] up so.
double troopBlow({List<OmenKind> omens = const [], double factor = 1, void Function(Game, Unit k, Unit o)? set}) {
  final (g, k, o) = duel(omens: omens, factor: factor);
  o
    ..maxHp = 100000
    ..hp = 100000;
  set?.call(g, k, o);
  return blowOn(g, o, k);
}

/// A skeleton archer's arrow on a knight with HP to spare 40 px from it, the enemy holding [omens] at [factor] (the
/// archer spawned under them), [set] up so; and the archer.
(double, Unit) arrowOn(List<OmenKind> omens, {double factor = 2, void Function(Game, Unit k, Unit a)? set}) {
  final g = plain(omens: omens, factor: factor);
  final k = placeNow(g, 'knight', 2, 3)
    ..busyUntil = hold
    ..maxHp = 100000
    ..hp = 100000;
  final a = foeAt(g, 'skeleton_archer', k.pos + const Point(40, 0));
  set?.call(g, k, a);
  return (shotOn(g, k, a), a);
}

/// A troop of [type] standing at [at] that never moves or fights ([hold]), set down as is (cleanse_test.dart's).
Unit troopAt(Game g, String type, Point<double> at) {
  final u = Unit(Side.troop, type, troopTypes[type]!, at)
    ..entered = true
    ..busyUntil = hold;
  g.units.add(u);
  return u;
}

/// A wave on with nothing left to spawn in a [plain] game holding [omens] at [factor] (set after the start, which
/// freezes the army's own), the monsters' skills on, and a monster of [type] and [tier] at (250, 60) that casts but
/// never strikes; a [still] one never walks either (cleanse_test.dart's casterAt).
(Game, Unit) casterAt(String type, Tier tier, {List<OmenKind> omens = const [], double factor = 1, bool still = false}) {
  final g = plain(omens: omens)..monsterSkills = true;
  g
    ..startWave()
    ..queue.clear()
    ..omenFactor = factor;
  final u = g.monster(type, tier, const Point(250, 60))
    ..entered = true
    ..cd = hold
    ..summonCd = hold;
  g.units.add(u);
  if (still) g.addEffect(u, Status.slow, hold, k: 0);
  return (g, u);
}

/// Ticks until monster [u] has begun [skill] and then cast it (cleanse_test.dart's).
void lands(Game g, Unit u, MonsterSkill skill) {
  for (var i = 0; i < 60 && u.winding != skill; i++) {
    g.tick(0.05);
  }
  expect(u.winding, skill, reason: '${u.type} began ${skill.title}');
  for (var i = 0; i < 40 && u.winding != null; i++) {
    g.tick(0.05);
  }
  expect(u.winding, isNull, reason: '${u.type} cast ${skill.title}');
}

/// Ticks [g] until [done] (at most [s] seconds).
void tickUntil(Game g, bool Function() done, [double s = 5]) {
  final end = g.t + s;
  while (!done() && g.t < end) {
    g.tick(0.05);
  }
}

/// A monster heal the funnel heard: the monster, its tag, the HP it gained.
typedef Healed = ({Unit u, MonsterHeal src, double asked, double gained});

/// Every monster heal of [g] from now on, in order.
List<Healed> hear(Game g) {
  final heard = <Healed>[];
  g.onMonsterHeal = (u, src, asked, gained) => heard.add((u: u, src: src, asked: asked, gained: gained));
  return heard;
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
  tearDown(() => omensOn = false);

  group('the rows', () {
    test("the ten sit in the Epik pool alone, in the pool's order (after Armor and Mend since the Epik cut-over); the "
        'Langka and Legenda pools as they were; their numbers, titles, constants, troop-side flag, needs and icons (an '
        "existing sheet's cell, each unique)", () {
      expect(omenPool(Rarity.epik).take(2), [OmenKind.armor, OmenKind.mend], reason: 'the Epik cut-over (omen_epik_cutover_test.dart)');
      expect(omenPool(Rarity.epik).where(batch.contains), batch,
          reason: "batch E-2B's ten sit among them in the pool's order (omen_epik2_test.dart)");
      expect(omenPool(Rarity.langka), hasLength(30));
      expect(omenPool(Rarity.langka).where(batch.contains), isEmpty);
      expect(omenPool(Rarity.legenda).take(2), [OmenKind.shield, OmenKind.guard],
          reason: "Barrier and Escort first since the Legenda cut-over (omen_legenda_cutover_test.dart); G-1B's kinds follow");
      expect(omenOrder, OmenKind.values);
      expect(omenMarks[Rarity.epik], 2, reason: 'an Epik take gives 2 levels (catalog-bayangan-v2 §1)');
      for (final k in batch) {
        expect(k.tiers, {Rarity.epik}, reason: '$k');
        expect(k.live, isTrue, reason: '$k');
        expect(k.debuff, isFalse, reason: '$k');
        expect(k.byL, isEmpty, reason: '$k: a share, no count');
      }
      // Batch E-1P's Artifacts name them, one each (pusaka_epik1_test.dart; later Epik batches add more).
      expect({for (final k in batch) k: k.answers}, {
        darkHymn: [Relic.healerBane],
        boneArrows: [Relic.arrowCatcher],
        arrowWard: [Relic.hawkFeather],
        enrage: [Relic.stoneCoat],
        hunker: [Relic.bullyClub],
        counterspell: [Relic.moonwell, Relic.aegisSeal, Relic.manaHymn, Relic.saintTear], // and batch E-2P's and E-3P's
        wearDown: [Relic.dragonHeart, Relic.heroCloak], // Dragon Heart's since the Epik cut-over
        envy: [Relic.runeGauntlet, Relic.braveSong], // and batch E-3P's (pusaka_epik3_test.dart)
        zeal: [Relic.witherroot],
        muster: [Relic.unityRing],
      });
      expect({for (final k in batch) k: k.k}, {
        darkHymn: (perE: 0.08, max: 0.4),
        boneArrows: (perE: 0.08, max: 0.4),
        arrowWard: (perE: 0.08, max: 0.5),
        enrage: (perE: 0.06, max: 0.3),
        hunker: (perE: 0.05, max: 0.2),
        counterspell: (perE: 0.03, max: 0.12),
        wearDown: (perE: 0.0015, max: 0.01),
        envy: (perE: 0.04, max: 0.25),
        zeal: (perE: 0.05, max: 0.3),
        muster: (perE: 0.05, max: 0.3),
      });
      expect([for (final k in batch) k.title],
          ['Dark Hymn', 'Bone Arrows', 'Arrow Ward', 'Enrage', 'Hunker', 'Counterspell', 'Wear Down', 'Envy', 'Zeal', 'Muster']);
      expect([omenArrowWardTime, omenEnrageAfter, omenCounterspellTime, omenCounterspellReach, omenCounterspellEvery], [6, 10, 3, 2.5 * tile, 6]);
      expect([omenWearDownBlow, omenZealTime, omenMusterAt, omenMusterReach, omenMusterTime], [0.5, 3, 60, 3 * tile, 5]);
      expect([for (final k in OmenKind.values) if (k.troopSide) k].where(batch.contains), isEmpty, reason: 'none of the ten is troop-side');
      expect({for (final k in batch) if (k.needs.isNotEmpty) k: k.needs}, {
        hunker: {OmenNeed.slow, OmenNeed.hold, OmenNeed.stun},
        counterspell: {OmenNeed.mpSkill},
        envy: {OmenNeed.mightOrHaste},
      });
      for (final k in batch) {
        for (final n in k.needs) {
          expect(n.built, isTrue, reason: '$k needs $n');
        }
      }
      expect({for (final k in batch) k: (k.icon!.sheet, k.icon!.x, k.icon!.y, k.icon!.size, k.icon!.tint)}, {
        darkHymn: ('item_staff.png', 0, 0, 32, tintDarkGreen),
        boneArrows: ('tiny_skeleton_archer_idle.png', 41, 38, 22, null),
        arrowWard: ('item_bow.png', 0, 0, 32, tintOlive),
        enrage: ('fx_hit_armored_axeman.png', 128, 0, 64, null),
        hunker: ('item_shield.png', 0, 0, 32, tintSteel),
        counterspell: ('ui_icons.png', 176, 16, 16, tintTeal),
        wearDown: ('ui_icons.png', 0, 0, 16, tintDarkRed),
        envy: ('ui_icons.png', 144, 48, 16, tintDarkRed),
        zeal: ('item_staff.png', 0, 0, 32, tintGold),
        muster: ('relic_dragonCrown.png', 0, 0, 32, tintRed),
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
      }
    });

    test('needs: Hunker acts on an army with a slow, hold or stun source, Counterspell with an MP skill, Envy with a '
        'might or haste source; the other seven always', () {
      final g = bareGame(Random(1))..heroSkills = true;
      for (final kind in batch) {
        expect(omenCanAct(kind, g.omenMet), !const {hunker, counterspell, envy}.contains(kind), reason: 'no army: $kind');
      }
      final k = placeNow(g, 'knight', 2, 3);
      expect([omenCanAct(hunker, g.omenMet), omenCanAct(counterspell, g.omenMet), omenCanAct(envy, g.omenMet)], [false, true, false],
          reason: "a knight: its skill costs MP, it holds nobody, it boosts nobody");
      placeNow(g, 'armored_axeman', 2, 4);
      expect(omenCanAct(hunker, g.omenMet), isTrue, reason: "the axemen's Crushing Blow stuns");
      expect(omenCanAct(envy, g.omenMet), isFalse);
      k
        ..hero = true
        ..heroSkill = HeroSkill.warCry;
      expect(omenCanAct(envy, g.omenMet), isTrue, reason: "a Hero's War Cry");
    });

    test("the Epik pool's order: a take's overflow follows it, past Muster round to the pool's start; a face past the tilt "
        'comes from the whole pool, the batch among them', () {
      final pool = omenPool(Rarity.epik);
      expect(omenPlace(levels(darkHymn, 3), darkHymn, pool, 2), [darkHymn, boneArrows]);
      expect(omenPlace(levels(zeal, 3), zeal, pool, 2), [zeal, pool[pool.indexOf(zeal) + 1]], reason: 'the next in the pool');
      expect(omenPlace(levels(muster, 3), muster, pool, 2), [muster, OmenKind.armor], reason: 'the overflow wraps round');
      // The Grail (Epik, its counter Prey): past the tilt each kind of the pool as likely, Muster the last.
      expect(omenFace(Relic.grail, null, 0.9999), muster);
      final faces = {for (var i = 0; i < 2700; i++) omenFace(Relic.grail, null, omenTilt + (1 - omenTilt) * (i + 0.5) / 2700)};
      expect(faces, pool.toSet());
      expect(faces, containsAll([OmenKind.armor, OmenKind.mend, ...batch]));
    });
  });

  group('the HUD numbers', () {
    setUp(() => omensOn = true);

    test('at E8 each shows its capped share (its max), the one its hooks read; every line short and in English; Wear '
        "Down's small shares in two decimals", () {
      final g = plain(omens: [for (final k in batch) ...top(k)], factor: 2);
      foeAt(g, 'orc', const Point(300, 60)); // a wave on: the HUD shows its frozen factor
      expect(g.omenShownFactor, 2);
      for (final k in batch) {
        final v = omenShown(k, omenCap, 8);
        expect(v.x, min(k.k.max, k.k.perE * 8), reason: '$k');
        expect(v.x, k.k.max, reason: '$k: E8 is past its max');
        expect(g.omenK(k), v.x, reason: '$k: the hooks read the same');
        expect(g.omenShownK(k), v.x, reason: '$k');
        expect(g.omenEffect(k), contains('${omenPercent(v.x)}%'), reason: '$k');
      }
      expect({for (final k in batch) k: g.omenEffect(k)}, {
        darkHymn: 'Monster healers heal 40% more.',
        boneArrows: 'Skeleton Archers deal 40% more damage.',
        arrowWard: 'New monsters take 50% less from arrows and spells for 6s.',
        enrage: 'A monster that has fought for 10s deals 30% more damage. Not bosses.',
        hunker: 'Slowed, held or stunned monsters take 20% less damage.',
        counterspell: "A troop's skill shields strong monsters near it: 12% HP for 3s.",
        wearDown: "Monster hits also deal 1% of the troop's max HP.",
        envy: 'Monsters deal 25% more damage to troops with a damage or speed boost.',
        zeal: 'Monsters healed by a monster healer deal 30% more damage for 3s.',
        muster: 'At 60% HP, a boss or mini boss gives monsters near +30% damage for 5s.',
      });
      expect([for (var n = 1; n <= 4; n++) plain(omens: levels(wearDown, n)).omenEffect(wearDown)], [
        for (final x in ['0.15', '0.3', '0.45', '0.6']) "Monster hits also deal $x% of the troop's max HP.",
      ]);
      expect(omenPercent(0.003), '0.3', reason: "Mend's L1 as before");
      expect(omenPercent(0.0624), '6.2', reason: 'one decimal from 1% up');
      for (final k in batch) {
        final line = g.omenLine(k);
        expect(line.length, lessThanOrEqualTo(80), reason: line);
        expect(line.codeUnits.every((c) => c < 128), isTrue, reason: line);
      }
    });
  });

  group('on', () {
    setUp(() => omensOn = true);

    test("Dark Hymn: a monster healer's heal (its damage, which its heal and Mass Mend read) × (1 + share), at most 40%; "
        'no other monster; a stat kind', () {
      final none = plain();
      for (final (n, factor, k) in [(1, 1.0, 0.08), (4, 1.0, 0.32), (4, 2.0, 0.4)]) {
        final g = plain(omens: levels(darkHymn, n), factor: factor);
        for (final tier in Tier.values) {
          expect(g.spawnStats(necroHealer, tier).dmg, closeTo(none.spawnStats(necroHealer, tier).dmg * (1 + k), 1e-9),
              reason: 'L$n ×$factor ${tier.name}');
          expect(g.spawnStats('orc', tier).dmg, none.spawnStats('orc', tier).dmg, reason: 'an orc');
        }
        expect(g.spawnStats(necroHealer, Tier.normal).range, none.spawnStats(necroHealer, Tier.normal).range);
      }
      // A healer's heal on a hurt orc asks for its heal × 1.4.
      double heal(List<OmenKind> omens) {
        final g = plain(omens: omens, factor: 2), heard = hear(g);
        foeAt(g, necroHealer, const Point(250, 60)).busyUntil = double.negativeInfinity;
        final orc = foeAt(g, 'orc', const Point(260, 60))..hp = 10;
        tickUntil(g, () => heard.any((h) => h.u == orc));
        return heard.firstWhere((h) => h.u == orc && h.src == MonsterHeal.heal).asked;
      }

      expect(heal(top(darkHymn)), closeTo(heal(const []) * 1.4, 1e-9));
    });

    test("Bone Arrows: a skeleton archer's damage × (1 + share), at most 40%, its range kept; no other monster; a stat "
        'kind, outside the dealt cap', () {
      final none = plain();
      for (final (n, factor, k) in [(1, 1.0, 0.08), (4, 1.0, 0.32), (4, 2.0, 0.4)]) {
        final g = plain(omens: levels(boneArrows, n), factor: factor);
        for (final tier in Tier.values) {
          final s = g.spawnStats('skeleton_archer', tier), b = none.spawnStats('skeleton_archer', tier);
          expect(s.dmg, closeTo(b.dmg * (1 + k), 1e-9), reason: 'L$n ×$factor ${tier.name}');
          expect(s.range, b.range);
          expect(g.spawnStats('skeleton', tier).dmg, none.spawnStats('skeleton', tier).dmg, reason: 'a skeleton');
        }
      }
      final (plainArrow, a0) = arrowOn(const []);
      final (arrow, a) = arrowOn(top(boneArrows));
      expect(plainArrow, hitTaken(a0.stats.dmg, 0));
      expect(arrow, closeToBlow(hitTaken(a0.stats.dmg * 1.4, 0)));
      expect(a.stats.dmg, closeTo(a0.stats.dmg * 1.4, 1e-9));
      // With Grudge (×1.25) and an omen might (×1.2) the cap would stop the adds at 1.6 × the blow; Bone Arrows' 1.4 is
      // in the blow itself: 1.4 × 1.5, never capped.
      final (stacked, _) = arrowOn([...top(boneArrows), ...top(OmenKind.grudge)], set: (g, k, a) {
        g.grudgeType = 'knight';
        g.addEffect(a, Status.might, 100, k: 1.2, omen: true);
      });
      expect(stacked, closeToBlow(hitTaken(a0.stats.dmg * 1.4 * 1.2 * 1.25, 0)));
    });

    test('Arrow Ward: a monster that comes on (a raised one too) takes × (1 − share) from the troops that shoot for 6 s, '
        'at most 50%; a blow up close never; outside the taken floor', () {
      for (final (omens, factor, k) in [(levels(arrowWard, 1), 1.0, 0.08), (top(arrowWard), 2.0, 0.5)]) {
        final g = plain(omens: omens, factor: factor);
        for (final tier in Tier.values) {
          final w = g.effectOn(g.monster('orc', tier, const Point(250, 60)), Status.shotWard)!;
          expect(w.k, closeTo(1 - k, 1e-12), reason: tier.name);
          expect(w.until, closeTo(g.t + omenArrowWardTime, 1e-9), reason: tier.name);
          expect([w.omen, w.by], [true, null], reason: '${tier.name}: a Shadow\'s, Spellbreaker strips it');
        }
      }
      expect(spellbreakerStrips, contains(Status.shotWard));
      final g = plain(omens: top(arrowWard), factor: 2);
      final necro = g.monster(boss, Tier.boss, const Point(250, 60))..summonCd = 0;
      g.units.add(necro..mp = necro.stats.mp.toDouble());
      g.tick(0.05);
      expect(g.minionsOf(necro), isNotEmpty);
      expect([for (final m in g.minionsOf(necro)) g.effectOn(m, Status.shotWard)?.k], everyElement(closeTo(0.5, 1e-12)), reason: 'raised');
      expect(plain(omens: top(OmenKind.armor)).monster('orc', Tier.normal, const Point(250, 60)).effects, isEmpty, reason: 'without it');

      /// A troop archer's arrow on an orc that just came on (with HP to spare), the enemy holding [omens] at E8; [late]:
      /// after the ward ran out.
      double arrowIn(List<OmenKind> omens, {bool late = false}) {
        final g = plain(omens: omens, factor: 2);
        final a = placeNow(g, 'archer', 2, 3)..busyUntil = hold;
        final o = foeAt(g, 'orc', a.pos + const Point(40, 0))
          ..maxHp = 100000
          ..hp = 100000;
        if (late) runFor(g, omenArrowWardTime + 0.05);
        return shotOn(g, o, a);
      }

      final bare = arrowIn(const []);
      expect(arrowIn(top(arrowWard)), closeToBlow(bare * 0.5));
      expect(arrowIn(top(arrowWard), late: true), closeToBlow(bare), reason: 'after 6 s');
      expect(troopBlow(omens: top(arrowWard), factor: 2), troopBlow(), reason: 'a knight up close');
      // Outside the floor: Armor (×0.6) and Hard Shell (its shot ward is a shield: ×0.7) stop at 0.5; the ward halves on top.
      final floor = [...top(OmenKind.armor), ...top(OmenKind.hardShell)];
      expect(troopBlow(omens: [...floor, ...top(arrowWard)], factor: 2), closeToBlow(troopBlow() * omenTakenFloor));
      expect(arrowIn([...floor, ...top(arrowWard)]), closeToBlow(bare * omenTakenFloor * 0.5));
    });

    test("Enrage: a monster's blow × (1 + share) once 10 s have passed since its first blow, at most 30%; its first "
        "blows never; not the boss's or a mini boss's; the field rings it", () {
      final base = foeBlow();
      for (final (n, factor, k) in [(1, 1.0, 0.06), (4, 1.0, 0.24), (4, 2.0, 0.3)]) {
        final (g, kn, o) = duel(omens: levels(enrage, n), factor: factor);
        expect(blowOn(g, kn, o), closeToBlow(base), reason: 'L$n ×$factor: its first blow');
        expect(o.firstStrikeAt, lessThan(g.t + 1e-9));
        expect(g.omenEnraged(o), isFalse);
        o.firstStrikeAt = g.t - omenEnrageAfter + 1; // 9 s of fighting
        expect(blowOn(g, kn, o), closeToBlow(base), reason: 'L$n ×$factor: 9 s');
        o.firstStrikeAt = g.t - omenEnrageAfter - 0.01;
        expect(g.omenEnraged(o), isTrue);
        expect(blowOn(g, kn, o), closeToBlow(base * (1 + k)), reason: 'L$n ×$factor: 10 s');
      }
      for (final tier in [Tier.miniBoss, Tier.boss]) {
        final (g, kn, o) = duel(omens: top(enrage), factor: 2, tier: tier);
        final first = blowOn(g, kn, o);
        o.firstStrikeAt = g.t - 60;
        expect(g.omenEnraged(o), isFalse, reason: tier.name);
        expect(blowOn(g, kn, o), closeToBlow(first), reason: tier.name);
      }
      final (g, _, o) = duel();
      o.firstStrikeAt = g.t - 60;
      expect(g.omenEnraged(o), isFalse, reason: 'without it');
    });

    test("Hunker: a troop's blow on a monster that a slow, a hold or a stun holds × (1 − share), at most 20%; a free one, "
        'or one weakened, never; in the taken floor', () {
      final base = troopBlow();
      final holds = <String, void Function(Game, Unit, Unit)>{
        'slow': (g, k, o) => g.addEffect(o, Status.slow, 10, k: 0.5, by: k),
        'hold': (g, k, o) => g.addEffect(o, Status.impaled, 10, k: 0, by: k),
        'stun': (g, k, o) => o.stunUntil = g.t + 10,
      };
      for (final (n, factor, k) in [(1, 1.0, 0.05), (4, 1.0, 0.2), (4, 2.0, 0.2)]) {
        for (final MapEntry(key: name, value: set) in holds.entries) {
          expect(troopBlow(omens: levels(hunker, n), factor: factor, set: set), closeToBlow(base * (1 - k)), reason: 'L$n ×$factor $name');
        }
        expect(troopBlow(omens: levels(hunker, n), factor: factor), closeToBlow(base), reason: 'free');
        expect(troopBlow(omens: levels(hunker, n), factor: factor, set: (g, k, o) => g.addEffect(o, Status.weaken, 10, k: 0.8, by: k)),
            closeToBlow(base), reason: 'weakened: not held');
      }
      expect(troopBlow(set: holds['stun']), closeToBlow(base), reason: 'without it');
      // Armor (×0.6) and Hunker (×0.8) on one blow: 0.48, held at the floor.
      expect(troopBlow(omens: [...top(OmenKind.armor), ...top(hunker)], factor: 2, set: holds['stun']), closeToBlow(base * omenTakenFloor));
    });

    test("Counterspell: a troop's skill (its #10 skill, its awakening skill, a Hero's) shields each high elite within 2.5 "
        'tiles of it, share of its max HP for 3 s, at most 12%; once per 6 s each; no other rank, none farther', () {
      /// A soldier awakened to 2 in a wave on, full of MP, with high elite orcs (HP to spare) 10 px and 12.8 px from it
      /// (Hold Fast wants two near) and the [others]; the enemy holding [omens] at [factor] (Hero and monster skills off).
      (Game, Unit, List<Unit>) scene(List<OmenKind> omens, {double factor = 2, List<(Point<double>, Tier)> others = const []}) {
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

      Effect? shieldOn(Game g, Unit o) => g.effectOn(o, Status.absorb);

      // The #10 skill (Hold Fast): both high elites near, at L1 ×1 and at E8; an elite, a mini boss and a far one never.
      for (final (omens, factor, k) in [(levels(counterspell, 1), 1.0, 0.03), (top(counterspell), 2.0, 0.12)]) {
        final (g, u, [a, b, elite, mini, far]) = scene(omens, factor: factor, others: [
          (const Point(-10.0, 0), Tier.elite),
          (const Point(-10.0, 8), Tier.miniBoss),
          (const Point(45.0, 0), Tier.highElite),
        ]);
        g.tick(0.05);
        expect(g.log.entries.whereType<SkillCast>(), hasLength(1), reason: 'Hold Fast cast');
        for (final o in [a, b]) {
          final s = shieldOn(g, o)!;
          expect(s.k, closeTo(o.maxHp * k, 1e-9), reason: 'its share of its max HP');
          expect(s.until, closeTo(g.t + omenCounterspellTime, 1e-9));
          expect([s.omen, s.by], [true, null]);
          expect(o.counterAt, g.t);
        }
        expect([shieldOn(g, elite), shieldOn(g, mini), shieldOn(g, far)], [null, null, null], reason: 'other ranks, 45 px');
        expect(u.mp, lessThan(u.stats.mp), reason: 'the cast paid');
      }
      // Once per 6 s each: one shielded 5 s ago gets none; 6 s ago, again.
      final (g, _, [a, b]) = scene(top(counterspell));
      a.counterAt = g.t - omenCounterspellEvery + 1;
      b.counterAt = g.t - omenCounterspellEvery;
      g.tick(0.05);
      expect([shieldOn(g, a), shieldOn(g, b) != null], [null, true]);
      // A bigger absorb it holds stays (one at a time).
      final (h, _, [c, _]) = scene(top(counterspell));
      h.addEffect(c, Status.absorb, 10, k: c.maxHp.toDouble(), by: c);
      h.tick(0.05);
      expect(shieldOn(h, c)!.k, c.maxHp, reason: 'the bigger stays');
      // The awakening skill (Disarm, Hold Fast on its cooldown).
      final (w, wu, [wa, wb]) = scene(top(counterspell));
      w.upgrades['soldier'] = [
        for (final MapEntry(key: item, value: n) in awakenRecipe['soldier']!.entries)
          for (var i = 0; i < n * 2; i++) item,
      ];
      wu.skillAt = w.t;
      w.tick(0.05);
      expect(w.log.entries.whereType<AwakenSkillCast>(), hasLength(1), reason: 'Disarm cast');
      expect([shieldOn(w, wa)?.k, shieldOn(w, wb)?.k], [closeTo(wa.maxHp * 0.12, 1e-9), closeTo(wb.maxHp * 0.12, 1e-9)]);
      // A Hero's (Shield Bash).
      final (s, hero) = heroCaster(HeroSkill.shieldBash);
      s
        ..omens.addAll(top(counterspell))
        ..omenFactor = 2;
      final elite = foeAt(s, 'orc', hero.pos + Point(hero.stats.range, 0), Tier.highElite);
      s.tick(0.05);
      expect(hero.heroSkillAt, s.t, reason: 'Shield Bash cast');
      expect(shieldOn(s, elite)?.k, closeTo(elite.maxHp * 0.12, 1e-9));
      // Without it, no shield.
      final (n, _, [na, _]) = scene(const []);
      n.tick(0.05);
      expect(shieldOn(n, na), isNull);
    });

    test("Wear Down: a monster's normal attack also deals share of the troop's max HP, at most 1%, before its defence; "
        'never more than half the blow (the Risk-1 guard); a shot\'s too; a skill\'s blow never', () {
      final (g0, k0, o0) = duel(big: false);
      final b = o0.stats.dmg, m = k0.maxHp;
      expect(blowOn(g0, k0, o0), closeToBlow(hitTaken(b, 0)));
      for (final (n, factor, k) in [(1, 1.0, 0.0015), (4, 1.0, 0.006), (4, 2.0, 0.01)]) {
        expect(foeBlow(omens: levels(wearDown, n), factor: factor, big: false), closeToBlow(hitTaken(b + min(k * m, b / 2), 0)),
            reason: 'L$n ×$factor: a knight of $m HP');
      }
      // The guard: on a tank of 100000 HP 1% is 1000, but the blow gains half of itself at most.
      expect(foeBlow(omens: top(wearDown), factor: 2), closeToBlow(hitTaken(b * (1 + omenWearDownBlow), 0)));
      // The half is of the blow after the monster's might (a War Shout's 1.2: 0.6 b more); with an omen might of 1.2 the
      // dealt cap holds the two at 1.6 b.
      expect(foeBlow(omens: top(wearDown), factor: 2, set: (g, k, o) => g.addEffect(o, Status.might, 100, k: 1.2, by: o)),
          closeToBlow(hitTaken(b * 1.2 * 1.5, 0)));
      expect(foeBlow(omens: top(wearDown), factor: 2, set: (g, k, o) => g.addEffect(o, Status.might, 100, k: 1.2, omen: true)),
          closeToBlow(hitTaken(b * omenDealtMost, 0)));
      // A skeleton archer's arrow is a normal attack too.
      final (_, a0) = arrowOn(const []);
      final (arrow, _) = arrowOn(top(wearDown));
      expect(arrow, closeToBlow(hitTaken(a0.stats.dmg * 1.5, 0)));
      // A skill's blow (Brutal Swing on two knights) gains nothing.
      double swing(List<OmenKind> omens) {
        final (g, u) = casterAt('elite_orc', Tier.highElite, omens: omens, factor: 2, still: true);
        final knights = [for (final dy in [-6.0, 6.0]) troopAt(g, 'knight', u.pos + Point(-10, dy))];
        for (final k in knights) {
          k
            ..maxHp = 5000
            ..hp = 5000;
        }
        lands(g, u, MonsterSkill.brutalSwing);
        return knights.fold(0.0, (s, k) => s + 5000 - k.hp);
      }

      final swung = swing(const []);
      expect(swung, greaterThan(0));
      expect(swing(top(wearDown)), closeToBlow(swung));
    });

    test("Envy: a monster's blow on a troop with a damage or speed boost (a might over 1, a haste under 1) × (1 + share), "
        'at most 25%; a slowing haste, a might under 1 or none never', () {
      final base = foeBlow();
      void might(Game g, Unit k, Unit o) => g.addEffect(k, Status.might, 10, k: 1.2);
      void haste(Game g, Unit k, Unit o) => g.addEffect(k, Status.haste, 10, k: 0.8);
      for (final (n, factor, k) in [(1, 1.0, 0.04), (4, 1.0, 0.16), (4, 2.0, 0.25)]) {
        expect(foeBlow(omens: levels(envy, n), factor: factor, set: might), closeToBlow(base * (1 + k)), reason: 'L$n ×$factor might');
        expect(foeBlow(omens: levels(envy, n), factor: factor, set: haste), closeToBlow(base * (1 + k)), reason: 'L$n ×$factor haste');
      }
      expect(foeBlow(omens: top(envy), factor: 2), base, reason: 'no boost');
      expect(foeBlow(omens: top(envy), factor: 2, set: (g, k, o) => g.addEffect(k, Status.haste, 10, k: 1.5)), closeToBlow(base),
          reason: 'a slowing haste (Sticky Glob)');
      expect(foeBlow(omens: top(envy), factor: 2, set: (g, k, o) => g.addEffect(k, Status.might, 10, k: 0.9)), closeToBlow(base),
          reason: 'a might under 1');
      expect(foeBlow(set: might), base, reason: 'without it');
    });

    test('Zeal: a monster that a monster healer\'s heal or Mass Mend gave HP gets an omen might of 1 + share for 3 s, at '
        'most 30%; a heal that gave nothing, or any other monster heal, never', () {
      /// A healer heals a hurt orc (sealed: under noHeal); its might.
      Effect? healed(List<OmenKind> omens, {double factor = 2, bool sealed = false}) {
        final g = plain(omens: omens, factor: factor), heard = hear(g);
        foeAt(g, necroHealer, const Point(250, 60)).busyUntil = double.negativeInfinity;
        final orc = foeAt(g, 'orc', const Point(260, 60))..hp = 10;
        if (sealed) g.addEffect(orc, Status.noHeal, 60);
        tickUntil(g, () => heard.any((h) => h.u == orc));
        expect(heard.where((h) => h.u == orc).first.src, MonsterHeal.heal);
        final m = g.effectOn(orc, Status.might);
        if (m != null) expect(m.until, closeTo(g.t + omenZealTime, 0.051), reason: 'from the heal');
        return m;
      }

      for (final (n, factor, k) in [(1, 1.0, 0.05), (4, 1.0, 0.2), (4, 2.0, 0.3)]) {
        final m = healed(levels(zeal, n), factor: factor)!;
        expect([m.k, m.omen, m.by], [closeTo(1 + k, 1e-12), true, null], reason: 'L$n ×$factor');
      }
      expect(healed(top(zeal), sealed: true), isNull, reason: 'noHeal: it gave nothing');
      expect(healed(const []), isNull, reason: 'without it');
      // Mass Mend: both hurt orcs near the high elite healer.
      final (g, h) = casterAt(necroHealer, Tier.highElite, omens: top(zeal), factor: 2);
      final a = foeAt(g, 'orc', h.pos + const Point(10.0, 0))..hp = 10, b = foeAt(g, 'orc', h.pos - const Point(10.0, 0))..hp = 10;
      lands(g, h, MonsterSkill.massMend);
      expect([g.effectOn(a, Status.might)?.k, g.effectOn(b, Status.might)?.k], [closeTo(1.3, 1e-12), closeTo(1.3, 1e-12)]);
      // Feed (its blow heals it) and Mend (regen) heal it too, but bring no might.
      final (fg, fk, fo) = duel(omens: [...top(OmenKind.feed), ...top(zeal)], factor: 2);
      fo.hp = 10;
      final heard = hear(fg);
      blowOn(fg, fk, fo);
      expect(heard.where((h) => h.u == fo && h.src == MonsterHeal.feed && h.gained > 0), isNotEmpty);
      expect(fg.effectOn(fo, Status.might), isNull, reason: 'Feed');
      final mg = plain(omens: [...top(OmenKind.mend), ...top(zeal)], factor: 2), mHeard = hear(mg);
      final mo = foeAt(mg, 'orc', const Point(250, 60))
        ..hp = 10
        ..busyUntil = double.negativeInfinity; // not held busy: its regen ticks
      mg.tick(0.05);
      expect(mHeard.where((h) => h.u == mo && h.src == MonsterHeal.regen && h.gained > 0), isNotEmpty);
      expect(mg.effectOn(mo, Status.might), isNull, reason: 'Mend');
    });

    test('Muster: a boss or mini boss at or under 60% of its HP for the first time gives every other monster within 3 '
        'tiles of it an omen might of 1 + share for 5 s, at most 30%; once; a killing blow, another rank or a far one '
        'never', () {
      /// A knight's blow takes a monster of [tier] 12 px from it from just over 60% under it (or, [kill], from 1 HP to
      /// none), monsters 30 px and 60 px behind it; the might each got.
      (Effect?, Effect?, Effect?, Game, Unit, Unit, Unit) call(List<OmenKind> omens, {double factor = 2, Tier tier = Tier.boss, bool kill = false}) {
        final (g, k, o) = duel(omens: omens, factor: factor, tier: tier);
        final near = foeAt(g, 'orc', o.pos + const Point(30, 0)), far = foeAt(g, 'orc', o.pos + const Point(60, 0));
        o.hp = kill ? 1 : o.maxHp * omenMusterAt / 100 + 0.5;
        blowOn(g, o, k);
        expect(o.hp, kill ? lessThanOrEqualTo(0) : lessThan(o.maxHp * omenMusterAt / 100));
        return (g.effectOn(near, Status.might), g.effectOn(far, Status.might), g.effectOn(o, Status.might), g, k, o, near);
      }

      for (final (n, factor, k) in [(1, 1.0, 0.05), (4, 1.0, 0.2), (4, 2.0, 0.3)]) {
        for (final tier in [Tier.boss, Tier.miniBoss]) {
          final (near, far, own, g, _, _, _) = call(levels(muster, n), factor: factor, tier: tier);
          expect([near?.k, near?.omen, near?.by], [closeTo(1 + k, 1e-12), true, null], reason: 'L$n ×$factor ${tier.name}');
          expect(near!.until, closeTo(g.t + omenMusterTime, 1e-9));
          expect([far, own], [null, null], reason: '60 px; itself');
        }
      }
      // Once: back over 60% and under again, no new call.
      final (_, _, _, g, k, o, near) = call(top(muster));
      near.effects.remove(Status.might);
      o.hp = o.maxHp * 0.9;
      blowOn(g, o, k);
      o.hp = o.maxHp * omenMusterAt / 100 + 0.5;
      blowOn(g, o, k);
      expect(g.effectOn(near, Status.might), isNull, reason: 'once');
      for (final tier in [Tier.normal, Tier.elite, Tier.highElite]) {
        final (n, _, _, _, _, _, _) = call(top(muster), tier: tier);
        expect(n, isNull, reason: tier.name);
      }
      final (killed, _, _, _, _, _, _) = call(top(muster), kill: true);
      expect(killed, isNull, reason: 'a killing blow');
      final (none, _, _, _, _, _, _) = call(const []);
      expect(none, isNull, reason: 'without it');
    });

    test("the dealt cap: Enrage, Envy, Wear Down and an omen might (Zeal's, Muster's) on one blow stop at 1.6 × the blow "
        'without them; under it, their product and sum', () {
      final base = foeBlow();
      void all(Game g, Unit k, Unit o) {
        g
          ..addEffect(o, Status.might, 100, k: 1.3, omen: true) // Muster's at its most
          ..addEffect(k, Status.haste, 10, k: 0.8);
        o.firstStrikeAt = g.t - omenEnrageAfter;
      }

      expect(foeBlow(omens: [...top(enrage), ...top(envy), ...top(wearDown)], factor: 2, set: all), closeToBlow(base * omenDealtMost),
          reason: '1.3 × 1.3 × 1.25 + Wear Down: the cap');
      expect(foeBlow(omens: [...levels(enrage, 1), ...levels(envy, 1)], set: all), closeToBlow(base * 1.3 * 1.06 * 1.04),
          reason: 'under the cap: the product');
      final (g, k, o) = duel(omens: [...levels(enrage, 1), ...levels(wearDown, 1)], big: false);
      final m = k.maxHp;
      o.firstStrikeAt = g.t - omenEnrageAfter;
      expect(blowOn(g, k, o), closeToBlow(base * 1.06 + min(0.0015 * m, base / 2)), reason: 'Wear Down adds on top');
    });
  });

  group('off', () {
    setUp(() => omensOn = false);

    test('with every kind of the batch at its most, nothing acts: stats, spawns, blows both ways, casts, heals and a '
        "boss's call as with none", () {
      final all = [for (final k in batch) ...top(k)];
      final g = plain(omens: all, factor: 2), none = plain();
      for (final type in [necroHealer, 'skeleton_archer']) {
        expect(g.spawnStats(type, Tier.normal).dmg, none.spawnStats(type, Tier.normal).dmg, reason: type);
      }
      expect(g.monster('orc', Tier.normal, const Point(250, 60)).effects, isEmpty, reason: 'Arrow Ward');
      void boosted(Game g, Unit k, Unit o) {
        g.addEffect(k, Status.might, 10, k: 1.2);
        o.firstStrikeAt = g.t - 60;
      }

      expect(foeBlow(omens: all, factor: 2, set: boosted), foeBlow(set: boosted), reason: 'Enrage, Envy, Wear Down');
      void stunned(Game g, Unit k, Unit o) => o.stunUntil = g.t + 10;
      expect(troopBlow(omens: all, factor: 2, set: stunned), troopBlow(set: stunned), reason: 'Hunker');
      final (dg, _, o) = duel(omens: all, factor: 2);
      o.firstStrikeAt = dg.t - 60;
      expect(dg.omenEnraged(o), isFalse);
      // Counterspell: a Hero's cast shields nobody.
      final (s, hero) = heroCaster(HeroSkill.shieldBash);
      s
        ..omens.addAll(all)
        ..omenFactor = 2;
      final elite = foeAt(s, 'orc', hero.pos + Point(hero.stats.range, 0), Tier.highElite);
      s.tick(0.05);
      expect(hero.heroSkillAt, s.t);
      expect(s.effectOn(elite, Status.absorb), isNull);
      // Zeal: a healer's heal brings no might.
      final h = plain(omens: all, factor: 2), heard = hear(h);
      foeAt(h, necroHealer, const Point(250, 60)).busyUntil = double.negativeInfinity;
      final orc = foeAt(h, 'orc', const Point(260, 60))..hp = 10;
      tickUntil(h, () => heard.any((e) => e.u == orc));
      expect(heard.where((e) => e.u == orc), isNotEmpty);
      expect(h.effectOn(orc, Status.might), isNull);
      // Muster: a boss's crossing calls nobody, and its bit stays unused.
      final (bg, bk, bo) = duel(omens: all, factor: 2, tier: Tier.boss);
      final near = foeAt(bg, 'orc', bo.pos + const Point(30, 0));
      bo.hp = bo.maxHp * omenMusterAt / 100 + 0.5;
      blowOn(bg, bo, bk);
      expect([bg.effectOn(near, Status.might), bo.belowHp], [null, 0]);
    });
  });
}
