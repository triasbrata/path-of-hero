// Shadow batch E-2B (decisions-log 212, lib/omen.dart; catalog-bayangan-v2 §3.2; docs/units-and-combat.md "Bayangan on
// the field", docs/loot-items-relics.md "Bayangan"): ten more Epik kinds. Their rows (the Epik pool alone, in the pool's
// order among E-1B's ten; numbers, icons, the troop-side flag, needs), the cap at E8 and the HUD number equal to it, and
// with omens on one test a kind: Second Skin and Last Rage answer a monster's HP going under a line once (an absorb, a
// might); Bile Sacs hurts the troops next to a slime that dies; Blood Moon gives a wolf or a bear that comes on a
// lifesteal healed with its own tag; Mark Ward shortens the marks on monsters; Parting Gift heals the monsters near one
// that dies; Captain cuts a troop's blow on a monster near a high elite (in the taken floor); Close Ranks guards the
// monsters next to one that dies, before the kill Fx and never inside a leap (in the taken floor); Blindside raises a
// monster's blow on a troop busy with another monster (in the dealt cap); Triumph hastens the monsters near a troop that
// falls. The crowd stack (Captain, Close Ranks, Hunker) and the dealt stack (Last Rage, Blindside, Envy) stop at their
// caps. With omens off none of it acts.
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

const secondSkin = OmenKind.secondSkin, bileSacs = OmenKind.bileSacs, bloodMoon = OmenKind.bloodMoon;
const markWard = OmenKind.markWard, lastRage = OmenKind.lastRage, partingGift = OmenKind.partingGift;
const captain = OmenKind.captain, closeRanks = OmenKind.closeRanks, blindside = OmenKind.blindside, triumph = OmenKind.triumph;

/// The batch, in the Epik pool's order.
const batch = [secondSkin, bileSacs, bloodMoon, markWard, lastRage, partingGift, captain, closeRanks, blindside, triumph];

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
/// HP to spare ([big]: 100000 max HP).
(Game, Unit, Unit) duel({List<OmenKind> omens = const [], double factor = 1, Tier tier = Tier.normal, bool big = true}) {
  final g = plain(omens: omens, factor: factor);
  final k = placeNow(g, 'knight', 2, 3)..busyUntil = hold;
  if (big) {
    k
      ..maxHp = 100000
      ..hp = 100000;
  }
  final o = foeAt(g, 'orc', k.pos + const Point(12, 0), tier);
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

/// A PNG's width and height, from its header.
(int, int) pngSize(File f) {
  final b = f.readAsBytesSync();
  int at(int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
  return (at(16), at(20));
}

/// A blow's damage [v] to within float noise.
Matcher closeToBlow(double v) => closeTo(v, 1e-9);

/// What [k]'s blow took off monster [u]: [k] steps 12 px to its left (in its reach, nearer than any other) and strikes.
double strikeAt(Game g, Unit u, Unit k) {
  k.pos = u.pos - const Point(12, 0);
  return blowOn(g, u, k);
}

/// A knight (not big) kills a 1-HP monster of [type] 12 px from it now; knights 8 px ([near]) and 20 px ([far]) from
/// the dead one stand by, [near] [set] up so before, and an orc far off keeps the fight on; the enemy holding [omens] at
/// [factor].
(Game, Unit, Unit, Unit, Unit) burst(List<OmenKind> omens, {double factor = 2, String type = 'slime', void Function(Game, Unit near)? set}) {
  final g = plain(omens: omens, factor: factor);
  final k = placeNow(g, 'knight', 2, 3)..busyUntil = hold;
  foeAt(g, 'orc', k.pos + const Point(200, 0));
  final s = foeAt(g, type, k.pos + const Point(12, 0))..hp = 1;
  final near = troopAt(g, 'knight', s.pos + const Point(0, 8)), far = troopAt(g, 'knight', s.pos + const Point(0, 20));
  set?.call(g, near);
  blowOn(g, s, k);
  expect(s.alive, isFalse, reason: 'the $type died');
  return (g, k, s, near, far);
}

/// A monster of [tier] in a fresh [duel] that the knight's blow takes from just over [at] percent of its HP under it (or,
/// [kill], from 1 HP to none); the game, the knight and the monster.
(Game, Unit, Unit) under(int at, List<OmenKind> omens, {double factor = 2, Tier tier = Tier.normal, bool kill = false}) {
  final (g, k, o) = duel(omens: omens, factor: factor, tier: tier);
  o.hp = kill ? 1 : o.maxHp * at / 100 + 0.5;
  blowOn(g, o, k);
  expect(o.hp, kill ? lessThanOrEqualTo(0) : lessThan(o.maxHp * at / 100), reason: 'the blow took it under $at%');
  return (g, k, o);
}

void main() {
  tearDown(() => omensOn = omensDefault);

  group('the rows', () {
    test("the ten sit in the Epik pool alone, in the pool's order among E-1B's ten; the Langka and Legenda pools as they "
        "were; their numbers, titles, constants, troop-side flag, needs and icons (an existing sheet's cell, each unique)", () {
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
      // Batch E-2P's Artifacts name five of them, one each (pusaka_epik2_test.dart); the other five are faces only.
      expect({for (final k in batch) k: k.answers}, {
        secondSkin: <Relic>[],
        bileSacs: [Relic.anchor],
        bloodMoon: <Relic>[],
        markWard: [Relic.emberBrand],
        lastRage: <Relic>[],
        partingGift: <Relic>[],
        captain: <Relic>[],
        closeRanks: [Relic.funeralPyre],
        blindside: [Relic.wardensHorn],
        triumph: [Relic.fallenFlag],
      });
      expect({for (final k in batch) k: k.k}, {
        secondSkin: (perE: 0.03, max: 0.2),
        bileSacs: (perE: 0.02, max: 0.12),
        bloodMoon: (perE: 0.05, max: 0.3),
        markWard: (perE: 0.1, max: 0.5),
        lastRage: (perE: 0.1, max: 0.4),
        partingGift: (perE: 0.03, max: 0.15),
        captain: (perE: 0.04, max: 0.25),
        closeRanks: (perE: 0.04, max: 0.15),
        blindside: (perE: 0.03, max: 0.15),
        triumph: (perE: 0.05, max: 0.2),
      });
      expect([for (final k in batch) k.title], [
        'Second Skin', 'Bile Sacs', 'Blood Moon', 'Mark Ward', 'Last Rage', 'Parting Gift', 'Captain', 'Close Ranks', 'Blindside', //
        'Triumph',
      ]);
      expect([omenSecondSkinAt, omenSecondSkinTime, omenSecondSkinBit, omenLastRageAt, omenLastRageTime, omenLastRageBit], [50, 6, 2, 35, 4, 1]);
      expect({omenMusterBit, omenLastRageBit, omenSecondSkinBit}, hasLength(3), reason: "each kind's own bit on Unit.belowHp");
      expect([omenBileReach, omenBileEvery, omenBloodMoonTime, omenPartingGiftReach, omenPartingGiftEvery], [tile, 0.5, 8, 1.5 * tile, 1]);
      expect(omenBloodMoonTypes, {'werewolf', 'werebear'});
      expect([omenCaptainReach, omenCloseRanksReach, omenCloseRanksTime, omenBlindsideBusy, omenTriumphReach, omenTriumphTime],
          [1.5 * tile, tile, 1.5, 1.5, 2 * tile, 3]);
      expect([for (final k in OmenKind.values) if (k.troopSide) k].where(batch.contains), isEmpty, reason: 'none of the ten is troop-side');
      expect({for (final k in batch) if (k.needs.isNotEmpty) k: k.needs}, {markWard: {OmenNeed.mark}});
      expect(OmenNeed.mark.built, isTrue);
      expect({for (final k in batch) k: (k.icon!.sheet, k.icon!.x, k.icon!.y, k.icon!.size, k.icon!.tint)}, {
        secondSkin: ('ui_icons.png', 208, 0, 16, tintTeal),
        bileSacs: ('tiny_slime_idle.png', 36, 39, 24, tintGreen),
        bloodMoon: ('tiny_werewolf_idle.png', 41, 35, 28, tintRed),
        markWard: ('ui_icons.png', 128, 0, 16, tintRed),
        lastRage: ('relic_fury.png', 0, 0, 32, null),
        partingGift: ('tiny_fx_heal.png', 136, 32, 30, tintViolet),
        captain: ('ui_icons.png', 96, 16, 16, tintDarkRed),
        closeRanks: ('fx_hit_armored_orc.png', 128, 0, 32, tintSteel),
        blindside: ('fx_hit_werewolf.png', 64, 0, 64, null),
        triumph: ('item_gloves.png', 0, 0, 32, tintPop),
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

    test('needs: Mark Ward acts on an army with a mark source (a Hero\'s Hunter\'s Mark, Void Eye bound); the other nine '
        'always', () {
      final g = bareGame(Random(1))..heroSkills = true;
      for (final kind in batch) {
        expect(omenCanAct(kind, g.omenMet), kind != markWard, reason: 'no army: $kind');
      }
      final k = placeNow(g, 'knight', 2, 3);
      expect(omenCanAct(markWard, g.omenMet), isFalse, reason: 'a knight marks nobody');
      k
        ..hero = true
        ..heroSkill = HeroSkill.huntersMark;
      expect(omenCanAct(markWard, g.omenMet), isTrue, reason: "a Hero's Hunter's Mark");
      final v = bareGame(Random(1));
      placeNow(v, 'knight', 2, 3);
      v.givePusaka(Relic.voidEye, type: 'knight', stars: 1);
      expect(omenCanAct(markWard, v.omenMet), isTrue, reason: "Void Eye's mark");
    });

    test("the Epik pool's order: a take's overflow follows it (Second Skin's into Bile Sacs, Captain's into Enrage, "
        "Triumph's into Muster); a face past the tilt comes from the whole pool, the batch among them", () {
      final pool = omenPool(Rarity.epik);
      expect(omenPlace(levels(secondSkin, 3), secondSkin, pool, 2), [secondSkin, bileSacs]);
      expect(omenPlace(levels(partingGift, 3), partingGift, pool, 2), [partingGift, pool[pool.indexOf(partingGift) + 1]],
          reason: "the next in the pool (E-3B's Old Bones since)");
      expect(omenPlace(levels(captain, 3), captain, pool, 2), [captain, OmenKind.enrage]);
      expect(omenPlace(levels(closeRanks, 3), closeRanks, pool, 2), [closeRanks, OmenKind.wearDown]);
      expect(omenPlace(levels(triumph, 3), triumph, pool, 2), [triumph, OmenKind.muster]);
      expect(omenPlace(levels(OmenKind.muster, 3), OmenKind.muster, pool, 2), [OmenKind.muster, OmenKind.armor], reason: 'wraps round');
      // The Grail (Epik, its counter Prey): past the tilt each kind of the pool as likely.
      final n = pool.length * 100;
      final faces = {for (var i = 0; i < n; i++) omenFace(Relic.grail, null, omenTilt + (1 - omenTilt) * (i + 0.5) / n)};
      expect(faces, pool.toSet());
      expect(faces, containsAll(batch));
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
        secondSkin: 'Monsters at half HP get a 20% HP shield for 6s, once. Not bosses.',
        bileSacs: 'A Slime that dies hurts troops next to it for 12% of their max HP.',
        bloodMoon: 'New Werewolves and Werebears heal 30% of what they deal for 8s.',
        markWard: 'Marks on monsters end 50% sooner.',
        lastRage: 'A monster under 35% HP deals 40% more damage for 4s. Not bosses.',
        partingGift: 'When a monster dies, monsters near it heal 15% HP. Not bosses.',
        captain: 'Monsters near a strong monster take 25% less damage.',
        closeRanks: 'Monsters next to one that dies take 15% less damage for 1.5s.',
        blindside: 'Monsters deal 15% more damage to a troop fighting another monster.',
        triumph: 'A troop falls: monsters near it attack 20% faster for 3s. Not bosses.',
      });
      expect([for (var n = 1; n <= 4; n++) plain(omens: levels(captain, n)).omenEffect(captain)],
          [for (final x in [4, 8, 12, 16]) 'Monsters near a strong monster take $x% less damage.']);
      for (final k in batch) {
        final line = g.omenLine(k);
        expect(line.length, lessThanOrEqualTo(80), reason: line);
        expect(line.codeUnits.every((c) => c < 128), isTrue, reason: line);
      }
    });
  });

  group('on', () {
    setUp(() => omensOn = true);

    test('Second Skin: a monster below a mini boss at or under half its HP for the first time gets an omen absorb of share '
        'of its max HP for 6 s, at most 20%, which soaks the next blow; once; not the boss or a mini boss; a killing '
        'blow none', () {
      for (final (n, factor, share) in steps(secondSkin)) {
        final (g, k, o) = under(omenSecondSkinAt, levels(secondSkin, n), factor: factor);
        final s = g.effectOn(o, Status.absorb)!;
        expect([s.k, s.omen, s.by], [closeTo(o.maxHp * share, 1e-9), true, null], reason: 'L$n ×$factor');
        expect(s.until, closeTo(g.t + omenSecondSkinTime, 1e-9));
        expect(o.belowHp & (1 << omenSecondSkinBit), isNot(0));
        // It soaks the next blow: the knight's blow takes what is past the shield.
        final hp = o.hp, shield = s.k, blow = troopBlow();
        blowOn(g, o, k);
        expect(hp - o.hp, closeToBlow(max(0.0, blow - shield)), reason: 'L$n ×$factor: the shield took ${min(blow, shield)}');
      }
      expect(spellbreakerStrips, contains(Status.absorb), reason: 'Spellbreaker strips it');
      // Once: back over half and under again, no new shield.
      final (g, k, o) = under(omenSecondSkinAt, top(secondSkin));
      o
        ..effects.remove(Status.absorb)
        ..hp = o.maxHp * omenSecondSkinAt / 100 + 0.5;
      blowOn(g, o, k);
      expect(g.effectOn(o, Status.absorb), isNull, reason: 'once');
      for (final tier in [Tier.miniBoss, Tier.boss]) {
        final (_, _, b) = under(omenSecondSkinAt, top(secondSkin), tier: tier);
        expect([b.effects[Status.absorb], b.belowHp], [null, 0], reason: '${tier.name}: none, its bit unused');
      }
      final (_, _, dead) = under(omenSecondSkinAt, top(secondSkin), kill: true);
      expect(dead.effects[Status.absorb], isNull, reason: 'a killing blow');
      final (_, _, none) = under(omenSecondSkinAt, const []);
      expect([none.effects[Status.absorb], none.belowHp], [null, 0], reason: 'without it');
    });

    test('Last Rage: a monster below a mini boss at or under 35% of its HP for the first time gets an omen might of 1 + '
        'share for 4 s, at most 40%: its blows on troops harder; once; not the boss or a mini boss', () {
      final base = foeBlow();
      for (final (n, factor, share) in steps(lastRage)) {
        final (g, k, o) = under(omenLastRageAt, levels(lastRage, n), factor: factor);
        final m = g.effectOn(o, Status.might)!;
        expect([m.k, m.omen, m.by], [closeTo(1 + share, 1e-12), true, null], reason: 'L$n ×$factor');
        expect(m.until, closeTo(g.t + omenLastRageTime, 1e-9));
        k
          ..maxHp = 100000
          ..hp = 100000;
        expect(blowOn(g, k, o), closeToBlow(base * (1 + share)), reason: 'L$n ×$factor: its blow');
      }
      // Over 35% it waits; once.
      final (g, k, o) = under(70, top(lastRage));
      expect(o.hp, greaterThan(o.maxHp * omenLastRageAt / 100));
      expect(g.effectOn(o, Status.might), isNull, reason: 'over 35%');
      o.hp = o.maxHp * omenLastRageAt / 100 + 0.5;
      blowOn(g, o, k);
      expect(g.effectOn(o, Status.might), isNotNull);
      o
        ..effects.remove(Status.might)
        ..hp = o.maxHp * omenLastRageAt / 100 + 0.5;
      blowOn(g, o, k);
      expect(g.effectOn(o, Status.might), isNull, reason: 'once');
      for (final tier in [Tier.miniBoss, Tier.boss]) {
        final (bg, _, b) = under(omenLastRageAt, top(lastRage), tier: tier);
        expect([bg.effectOn(b, Status.might), b.belowHp], [null, 0], reason: tier.name);
      }
      final (ng, _, none) = under(omenLastRageAt, const []);
      expect(ng.effectOn(none, Status.might), isNull, reason: 'without it');
      // A blow that takes it under both lines at once: Second Skin's shield and Last Rage's might, each its own bit.
      final (bg, _, both) = under(30, [...top(secondSkin), ...top(lastRage)]);
      expect([bg.effectOn(both, Status.absorb) != null, bg.effectOn(both, Status.might) != null], [true, true]);
      expect(both.belowHp, (1 << omenSecondSkinBit) | (1 << omenLastRageBit));
    });

    test('Bile Sacs: a slime that dies hurts each troop within 1 tile of it for share of the troop\'s max HP, at most '
        '12%, from no one, through its defence and cuts; a troop at most once every 0.5 s; another monster never', () {
      for (final (n, factor, share) in steps(bileSacs)) {
        final (g, k, s, near, far) = burst(levels(bileSacs, n), factor: factor);
        for (final u in [near, k]) {
          expect(u.maxHp - u.hp, closeToBlow(hitTaken(u.maxHp * share, u.stats.def)), reason: 'L$n ×$factor: ${u.pos.distanceTo(s.pos)} px');
          expect(u.bileAt, g.t);
        }
        expect(far.hp, far.maxHp, reason: '20 px');
      }
      // Once every 0.5 s: a second slime dies next to the same knight a tick later, then another 0.5 s on.
      final (g, k, _, near, _) = burst(top(bileSacs));
      double again() {
        final hp = near.hp, s = foeAt(g, 'slime', near.pos + const Point(4, 0))..hp = 1;
        strikeAt(g, s, k);
        expect(s.alive, isFalse);
        return hp - near.hp;
      }

      expect(again(), 0, reason: '0.05 s later');
      runFor(g, omenBileEvery);
      expect(again(), closeToBlow(hitTaken(near.maxHp * 0.12, near.stats.def)), reason: '0.5 s later');
      // Through the cuts: the small relic Guard's.
      final (_, _, _, guarded, _) = burst(top(bileSacs), set: (g, u) => u.relics.add(Relic.guard));
      expect(guarded.maxHp - guarded.hp, closeToBlow(hitTaken(guarded.maxHp * 0.12, guarded.stats.def) * (1 - guardCut)),
          reason: "the Guard's cut");
      // Another monster's death, or none of it, hurts nobody.
      final (_, ok, _, onear, _) = burst(top(bileSacs), type: 'orc');
      expect([onear.hp, ok.hp], [onear.maxHp, ok.maxHp], reason: 'an orc');
      final (_, nk, _, nnear, _) = burst(const []);
      expect([nnear.hp, nk.hp], [nnear.maxHp, nk.maxHp], reason: 'without it');
    });

    test('Blood Moon: a werewolf or werebear that comes on (any rank) gets an omen lifesteal of share for 8 s, at most '
        "30%, healed through the monster funnel with its own tag; other types never; a skill's lifesteal keeps its tag", () {
      for (final (n, factor, share) in steps(bloodMoon)) {
        final g = plain(omens: levels(bloodMoon, n), factor: factor);
        for (final type in omenBloodMoonTypes) {
          for (final tier in Tier.values) {
            final e = g.effectOn(g.monster(type, tier, const Point(250, 60)), Status.lifesteal)!;
            expect([e.k, e.omen, e.by], [closeTo(share, 1e-12), true, null], reason: 'L$n ×$factor $type ${tier.name}');
            expect(e.until, closeTo(g.t + omenBloodMoonTime, 1e-9));
          }
        }
        for (final type in ['orc', 'slime', 'bat', 'skeleton', boss]) {
          expect(g.monster(type, Tier.normal, const Point(250, 60)).effects[Status.lifesteal], isNull, reason: type);
        }
      }
      expect(spellbreakerStrips, contains(Status.lifesteal));

      /// A hurt [type] that came on under [omens] strikes a big knight after [wait] s: its heals heard.
      (double, List<Healed>) bite(List<OmenKind> omens, {String type = 'werewolf', double wait = 0, bool rage = false}) {
        final g = plain(omens: omens, factor: 2);
        final k = placeNow(g, 'knight', 2, 3)
          ..busyUntil = hold
          ..maxHp = 100000
          ..hp = 100000;
        final w = foeAt(g, type, k.pos + const Point(12, 0))..hp = 10;
        if (rage) g.addEffect(w, Status.lifesteal, 100, k: 0.3); // a skill's (Bloodrage)
        if (wait > 0) runFor(g, wait);
        final heard = hear(g);
        return (blowOn(g, k, w), heard.where((h) => h.u == w).toList());
      }

      for (final type in omenBloodMoonTypes) {
        final (dealt, heard) = bite(top(bloodMoon), type: type);
        expect(heard, hasLength(1), reason: type);
        expect([heard.single.src, heard.single.asked], [MonsterHeal.bloodMoon, closeTo(dealt * 0.3, 1e-9)], reason: type);
      }
      final (_, late) = bite(top(bloodMoon), wait: omenBloodMoonTime + 0.05);
      expect(late, isEmpty, reason: 'after 8 s');
      final (_, none) = bite(const []);
      expect(none, isEmpty, reason: 'without it');
      final (dealt, raged) = bite(const [], rage: true);
      expect([raged.single.src, raged.single.asked], [MonsterHeal.lifesteal, closeTo(dealt * 0.3, 1e-9)], reason: "Bloodrage's own tag");
    });

    test("Mark Ward: a mark a troop puts on a monster (Hunter's Mark's, Void Eye's) lasts × (1 − share), at most 50% "
        "less, never under 0.3 s; another status, or a monster's mark on a troop, as it was", () {
      for (final (n, factor, share) in steps(markWard)) {
        final g = plain(omens: levels(markWard, n), factor: factor);
        final kn = placeNow(g, 'knight', 2, 3)..busyUntil = hold;
        final o = foeAt(g, 'orc', const Point(250, 60));
        g
          ..addEffect(o, Status.vulnerable, 10, k: 1.25, by: kn)
          ..addEffect(o, Status.voidMark, 4, k: 1.25)
          ..addEffect(o, Status.slow, 10, k: 0.5, by: kn)
          ..addEffect(kn, Status.vulnerable, 10, k: 1.2, by: o, bad: true);
        expect(g.effectOn(o, Status.vulnerable)!.until, closeTo(g.t + 10 * (1 - share), 1e-9), reason: 'L$n ×$factor');
        expect(g.effectOn(o, Status.voidMark)!.until, closeTo(g.t + 4 * (1 - share), 1e-9), reason: 'L$n ×$factor');
        expect(g.effectOn(o, Status.slow)!.until, closeTo(g.t + 10, 1e-9), reason: 'a slow');
        expect(g.effectOn(kn, Status.vulnerable)!.until, closeTo(g.t + 10, 1e-9), reason: "Curse of Frailty's on a troop");
      }
      final g = plain(omens: top(markWard), factor: 2);
      final o = foeAt(g, 'orc', const Point(250, 60));
      g.addEffect(o, Status.vulnerable, 0.5, k: 1.25);
      expect(g.effectOn(o, Status.vulnerable)!.until, closeTo(g.t + effectTimeFloor, 1e-9), reason: 'the floor');
      // Void Eye bound: its mark from a knight's blow.
      double voidMark(List<OmenKind> omens) {
        final (g, k, o) = duel(omens: omens, factor: 2);
        g.givePusaka(Relic.voidEye, type: 'knight', stars: 1);
        o
          ..maxHp = 100000
          ..hp = 100000;
        blowOn(g, o, k);
        return g.effectOn(o, Status.voidMark)!.until - g.t;
      }

      expect(voidMark(const []), closeTo(voidEyeK.time, 1e-9));
      expect(voidMark(top(markWard)), closeTo(voidEyeK.time * 0.5, 1e-9));
    });

    test('Parting Gift: a monster that dies heals each hurt monster below a mini boss within 1.5 tiles of it share of '
        'its own max HP, at most 15%, with its own tag; a monster at most once a second; none past the reach, on a '
        'mini boss, on one at full HP', () {
      /// A knight kills 1-HP orcs 12 px from it; hurt orcs 20 px ([near]) and 30 px ([far]) past the first, a hurt mini
      /// boss and a full orc 10 px from it.
      (Game, Unit, Unit, List<Healed>, Unit, Unit, Unit, Unit) gift(List<OmenKind> omens, {double factor = 2}) {
        final (g, k, o) = duel(omens: omens, factor: factor);
        o.hp = 1;
        final near = foeAt(g, 'orc', o.pos + const Point(20, 0))..hp = 10, far = foeAt(g, 'orc', o.pos + const Point(30, 0))..hp = 10;
        final mini = foeAt(g, 'orc', o.pos + const Point(0, 10), Tier.miniBoss)..hp = 10, full = foeAt(g, 'orc', o.pos + const Point(0, -10));
        final heard = hear(g);
        blowOn(g, o, k);
        expect(o.alive, isFalse);
        return (g, k, o, heard, near, far, mini, full);
      }

      for (final (n, factor, share) in steps(partingGift)) {
        final (g, _, _, heard, near, far, mini, full) = gift(levels(partingGift, n), factor: factor);
        final h = heard.where((h) => h.src == MonsterHeal.partingGift).toList();
        expect([for (final e in h) e.u], [near], reason: 'L$n ×$factor: not $far, $mini, $full');
        expect([h.single.asked, h.single.gained], [closeTo(near.maxHp * share, 1e-9), closeTo(near.maxHp * share, 1e-9)]);
        expect(near.giftAt, g.t);
      }
      // Once a second: another orc dies by it a tick later, then a second on.
      final (g, k, _, heard, near, _, mini, full) = gift(top(partingGift));
      g.units.removeWhere((u) => u == mini || u == full); // out of the knight's way
      int gifts() => heard.where((h) => h.src == MonsterHeal.partingGift && h.u == near).length;
      void killNext() {
        final o = foeAt(g, 'orc', near.pos - const Point(10, 0))..hp = 1;
        near.hp = 10;
        strikeAt(g, o, k);
        expect(o.alive, isFalse);
      }

      killNext();
      expect(gifts(), 1, reason: '0.05 s later');
      runFor(g, omenPartingGiftEvery.toDouble());
      killNext();
      expect(gifts(), 2, reason: 'a second later');
      // noHeal: asked, nothing gained.
      final (sg, sk, so) = duel(omens: top(partingGift), factor: 2);
      so.hp = 1;
      final sealed = foeAt(sg, 'orc', so.pos + const Point(10, 0))..hp = 10;
      sg.addEffect(sealed, Status.noHeal, 60);
      final sHeard = hear(sg);
      blowOn(sg, so, sk);
      expect([for (final h in sHeard) (h.src, h.gained)], [(MonsterHeal.partingGift, 0.0)]);
      final (_, _, _, nHeard, _, _, _, _) = gift(const []);
      expect(nHeard, isEmpty, reason: 'without it');
    });

    test('Captain: a troop\'s blow on a monster with a living high elite (not itself) within 1.5 tiles × (1 − share), at '
        "most 25%; an elite, a far or a dead one never; any rank it guards; a monster's blow as it was; in the taken floor",
        () {
      final base = troopBlow();
      void captainAt(Game g, Unit k, Unit o, [double dx = 20, Tier tier = Tier.highElite]) => foeAt(g, 'orc', o.pos + Point(dx, 0), tier);
      for (final (n, factor, share) in steps(captain)) {
        expect(troopBlow(omens: levels(captain, n), factor: factor, set: captainAt), closeToBlow(base * (1 - share)), reason: 'L$n ×$factor');
      }
      expect(troopBlow(omens: top(captain), factor: 2, set: (g, k, o) => captainAt(g, k, o, omenCaptainReach)), closeToBlow(base * 0.75),
          reason: 'at 1.5 tiles');
      expect(troopBlow(omens: top(captain), factor: 2, set: (g, k, o) => captainAt(g, k, o, omenCaptainReach + 1)), closeToBlow(base),
          reason: 'past 1.5 tiles');
      expect(troopBlow(omens: top(captain), factor: 2, set: (g, k, o) => captainAt(g, k, o, 20, Tier.elite)), closeToBlow(base), reason: 'an elite');
      expect(troopBlow(omens: top(captain), factor: 2, set: (g, k, o) => foeAt(g, 'orc', o.pos + const Point(20, 0), Tier.highElite).dying = 0),
          closeToBlow(base), reason: 'a dead one');
      // The high elite itself: alone none, with another near the cut.
      final elite = troopBlow(tier: Tier.highElite);
      expect(troopBlow(omens: top(captain), factor: 2, tier: Tier.highElite), closeToBlow(elite), reason: 'alone: itself never counts');
      expect(troopBlow(omens: top(captain), factor: 2, tier: Tier.highElite, set: captainAt), closeToBlow(elite * 0.75));
      final bossBlow = troopBlow(tier: Tier.boss);
      expect(troopBlow(omens: top(captain), factor: 2, tier: Tier.boss, set: captainAt), closeToBlow(bossBlow * 0.75), reason: 'a boss too');
      expect(foeBlow(omens: top(captain), factor: 2, set: captainAt), closeToBlow(foeBlow()), reason: "a monster's blow");
      expect(troopBlow(set: captainAt), closeToBlow(base), reason: 'without it');
    });

    test('Close Ranks: a monster that dies guards each monster within 1 tile of it, share less taken for 1.5 s, at most '
        "15% (a Bayangan's guard: in the taken floor); the stronger guard stays; it lands before the killer's kill Fx; a "
        'kill inside a leap gives none', () {
      final base = troopBlow();

      /// A knight kills a 1-HP orc 12 px from it; orcs with HP to spare 10 px ([near]) and 20 px ([far]) past it, [near]
      /// [set] up so before.
      (Game, Unit, Unit, Unit) kill(List<OmenKind> omens, {double factor = 2, void Function(Game, Unit near)? set}) {
        final (g, k, o) = duel(omens: omens, factor: factor);
        o.hp = 1;
        final near = foeAt(g, 'orc', o.pos + const Point(10, 0))
          ..maxHp = 100000
          ..hp = 100000;
        final far = foeAt(g, 'orc', o.pos + const Point(20, 4))
          ..maxHp = 100000
          ..hp = 100000;
        set?.call(g, near);
        blowOn(g, o, k);
        expect(o.alive, isFalse);
        return (g, k, near, far);
      }

      for (final (n, factor, share) in steps(closeRanks)) {
        final (g, k, near, far) = kill(levels(closeRanks, n), factor: factor);
        expect([near.guardCut, near.guardOmen, near.guardLook], [closeTo(share, 1e-12), true, null], reason: 'L$n ×$factor');
        expect(near.guardUntil, closeTo(g.t + omenCloseRanksTime, 1e-9));
        expect(far.guardUntil, double.negativeInfinity, reason: '20 px');
        expect(strikeAt(g, near, k), closeToBlow(base * (1 - share)), reason: 'L$n ×$factor: its guard');
      }
      final (g, k, near, _) = kill(top(closeRanks));
      runFor(g, omenCloseRanksTime);
      expect(strikeAt(g, near, k), closeToBlow(base), reason: 'after 1.5 s');
      // The stronger guard stays (a skill's, after the floor); a weaker one gives way.
      final (sg, sk, strong, _) = kill(top(closeRanks), set: (g, o) {
        o
          ..guardCut = 0.3
          ..guardUntil = g.t + 10;
      });
      expect([strong.guardCut, strong.guardOmen], [0.3, false]);
      expect(strikeAt(sg, strong, sk), closeToBlow(base * 0.7));
      final (_, _, weak, _) = kill(top(closeRanks), set: (g, o) {
        o
          ..guardCut = 0.05
          ..guardUntil = g.t + 10;
      });
      expect([weak.guardCut, weak.guardOmen], [closeTo(0.15, 1e-12), true]);
      // Before the kill Fx: Wolf Feast's heal of the killer finds the guard already on.
      bool? seen;
      kill(top(closeRanks), set: (g, o) {
        g
          ..givePusaka(Relic.wolfFeast, type: 'knight', stars: 1)
          ..onTroopHeal = (u, src, asked, past) {
            if (src == HealSrc.pusaka) seen = o.guardOmen && g.t < o.guardUntil;
          };
        for (final u in g.troops) {
          u.hp = u.maxHp / 2;
        }
      });
      expect(seen, isTrue, reason: "its guard landed before Wolf Feast's kill Fx");
      // Inside a leap (God's Thunder): the 1-HP orc the leap kills guards nobody; killed by a blow, it does.
      Unit leapt({required bool leap}) {
        final (g, k, a) = duel(omens: top(closeRanks), factor: 2);
        if (leap) g.givePusaka(Relic.godThunder, type: 'knight', stars: 1);
        a
          ..maxHp = 100000
          ..hp = 100000;
        final b = foeAt(g, 'orc', a.pos + const Point(20, 0))..hp = 1;
        final c = foeAt(g, 'orc', b.pos + const Point(0, 10))
          ..maxHp = 100000
          ..hp = 100000;
        if (!leap) k.pos = b.pos - const Point(0, 12); // b 12 px off, c 22, a 23
        blowOn(g, leap ? a : b, k);
        expect(b.alive, isFalse, reason: leap ? 'the leap killed it' : 'the blow killed it');
        return c;
      }

      expect(leapt(leap: true).guardUntil, double.negativeInfinity, reason: 'a kill inside a leap');
      expect(leapt(leap: false).guardOmen, isTrue, reason: 'a kill by a blow');
      final (_, _, none, _) = kill(const []);
      expect(none.guardUntil, double.negativeInfinity, reason: 'without it');
    });

    test("Blindside: a monster's blow on a troop that struck another monster less than 1.5 s ago × (1 + share), at most "
        "15%; on a troop fighting it, or idle, never; a troop's strike marks whom it fights", () {
      final base = foeBlow();
      void busy(Game g, Unit k, Unit o, [double ago = 0]) =>
          k.lastFoe = (foe: foeAt(g, 'orc', k.pos + const Point(10, 10)), at: g.t - ago);
      for (final (n, factor, share) in steps(blindside)) {
        expect(foeBlow(omens: levels(blindside, n), factor: factor, set: busy), closeToBlow(base * (1 + share)), reason: 'L$n ×$factor');
      }
      expect(foeBlow(omens: top(blindside), factor: 2, set: (g, k, o) => busy(g, k, o, omenBlindsideBusy - 0.1)), closeToBlow(base * 1.15),
          reason: '1.4 s ago (+0.05)');
      expect(foeBlow(omens: top(blindside), factor: 2, set: (g, k, o) => busy(g, k, o, omenBlindsideBusy)), closeToBlow(base),
          reason: '1.5 s ago');
      expect(foeBlow(omens: top(blindside), factor: 2, set: (g, k, o) => k.lastFoe = (foe: o, at: g.t)), closeToBlow(base),
          reason: 'fighting the one that hits it');
      expect(foeBlow(omens: top(blindside), factor: 2), closeToBlow(base), reason: 'idle');
      expect(foeBlow(set: busy), closeToBlow(base), reason: 'without it');
      // A troop's strike marks whom it fights (only while the omens are on).
      final (g, k, o) = duel();
      o
        ..maxHp = 100000
        ..hp = 100000;
      blowOn(g, o, k);
      expect([k.lastFoe?.foe, k.lastFoe?.at], [o, g.t]);
      expect(o.lastFoe, isNull, reason: 'a monster keeps none');
    });

    test('Triumph: a troop that falls hastens each monster below a mini boss within 2 tiles of it, an omen haste of 1 / '
        '(1 + share) for 3 s, at most 20% faster; the floors kept; a stronger haste stays; none past the reach or on a '
        'mini boss', () {
      /// A knight with 1 HP falls to the orc 12 px from it; orcs 20 px ([near]) and 40 px ([far]) from it and a mini boss
      /// 10 px from it stand by; an archer far behind keeps the game on.
      (Game, Unit, Unit, Unit, Unit) fall(List<OmenKind> omens, {double factor = 2, void Function(Game, Unit near)? set}) {
        final (g, k, o) = duel(omens: omens, factor: factor, big: false);
        placeNow(g, 'archer', 0, 1).cd = hold;
        final near = foeAt(g, 'orc', k.pos + const Point(0, 20)), far = foeAt(g, 'orc', k.pos + const Point(0, -40));
        final mini = foeAt(g, 'orc', k.pos + const Point(-10, 0), Tier.miniBoss);
        set?.call(g, near);
        k.hp = 1;
        blowOn(g, k, o);
        expect(k.alive, isFalse);
        return (g, o, near, far, mini);
      }

      for (final (n, factor, share) in steps(triumph)) {
        final (g, killer, near, far, mini) = fall(levels(triumph, n), factor: factor);
        for (final u in [near, killer]) {
          final h = g.effectOn(u, Status.haste)!;
          expect([h.k, h.omen, h.by], [closeTo(1 / (1 + share), 1e-12), true, null], reason: 'L$n ×$factor');
          expect(h.until, closeTo(g.t + omenTriumphTime, 1e-9));
          expect(g.attackEvery(u), closeTo(max(minAttackInterval, u.stats.rate / (1 + share)), 1e-12));
        }
        expect([g.effectOn(far, Status.haste), g.effectOn(mini, Status.haste)], [null, null], reason: '40 px; a mini boss');
      }
      expect(spellbreakerStrips, contains(Status.haste));
      final (_, _, kept, _, _) = fall(top(triumph), set: (g, o) => g.addEffect(o, Status.haste, 10, k: 0.5, by: o));
      expect(kept.effects[Status.haste]!.k, 0.5, reason: 'the stronger stays');
      final (_, _, none, _, _) = fall(const []);
      expect(none.effects[Status.haste], isNull, reason: 'without it');
    });

    test('the crowd stack: Captain, Close Ranks and Hunker multiply on one blow (0.51 at their most), and with Armor stop '
        'at the taken floor (0.5)', () {
      final base = troopBlow();
      void crowd(Game g, Unit k, Unit o) {
        foeAt(g, 'orc', o.pos + const Point(20, 0), Tier.highElite);
        o
          ..guardCut = 0.15
          ..guardUntil = g.t + 10
          ..guardOmen = true
          ..stunUntil = g.t + 10;
      }

      final stack = [...top(captain), ...top(closeRanks), ...top(OmenKind.hunker)];
      expect(troopBlow(omens: stack, factor: 2, set: crowd), closeToBlow(base * 0.75 * 0.85 * 0.8));
      expect(troopBlow(omens: [...stack, ...top(OmenKind.armor)], factor: 2, set: crowd), closeToBlow(base * omenTakenFloor));
    });

    test('the dealt stack: Last Rage, Blindside and Envy on one blow stop at 1.6 × the blow without them; under it, their '
        'product', () {
      final base = foeBlow();
      void all(Game g, Unit k, Unit o) {
        g
          ..addEffect(o, Status.might, 100, k: 1.4, omen: true) // Last Rage's at its most
          ..addEffect(k, Status.haste, 10, k: 0.8);
        k.lastFoe = (foe: foeAt(g, 'orc', k.pos + const Point(10, 10)), at: g.t);
      }

      expect(foeBlow(omens: [...top(blindside), ...top(OmenKind.envy)], factor: 2, set: all), closeToBlow(base * omenDealtMost),
          reason: '1.4 × 1.15 × 1.25: the cap');
      expect(foeBlow(omens: [...levels(blindside, 1), ...levels(OmenKind.envy, 1)], set: all), closeToBlow(base * 1.4 * 1.03 * 1.04),
          reason: 'under the cap: the product');
    });
  });

  group('off', () {
    setUp(() => omensOn = false);

    test('with every kind of the batch at its most, nothing acts: shields, mights and hastes, the slime\'s burst, the '
        'lifesteal, the marks, the heals, the guards and both caps\' blows as with none', () {
      final all = [for (final k in batch) ...top(k)];
      // Second Skin and Last Rage: under both lines, nothing, no bit spent.
      final (_, _, o) = under(30, all);
      expect([o.effects[Status.absorb], o.effects[Status.might], o.belowHp], [null, null, 0]);
      // Blood Moon.
      final g = plain(omens: all, factor: 2);
      expect(g.monster('werewolf', Tier.normal, const Point(250, 60)).effects, isEmpty);
      // Mark Ward.
      final m = foeAt(g, 'orc', const Point(250, 60));
      g.addEffect(m, Status.vulnerable, 10, k: 1.25);
      expect(g.effectOn(m, Status.vulnerable)!.until, closeTo(g.t + 10, 1e-9));
      // Captain, Close Ranks' guard slot (a guard marked so is any guard), Blindside.
      void crowd(Game g, Unit k, Unit o) {
        foeAt(g, 'orc', o.pos + const Point(20, 0), Tier.highElite);
        k.lastFoe = (foe: foeAt(g, 'orc', k.pos + const Point(10, 10)), at: g.t);
      }

      expect(troopBlow(omens: all, factor: 2, set: crowd), troopBlow(set: crowd));
      expect(foeBlow(omens: all, factor: 2, set: crowd), foeBlow(set: crowd));
      // Bile Sacs, Parting Gift, Close Ranks: a slime dies next to a knight and a hurt orc.
      late Unit orc;
      late List<Healed> heard;
      final (dg, dk, _, near, _) = burst(all, set: (g, u) {
        orc = foeAt(g, 'orc', u.pos + const Point(8, -8))..hp = 10; // 8 px from the slime
        heard = hear(g);
      });
      expect([dk.hp, near.hp], [dk.maxHp, near.maxHp], reason: 'no burst');
      expect(heard, isEmpty, reason: 'no gift');
      expect(orc.guardUntil, double.negativeInfinity, reason: 'no guard');
      expect(dk.lastFoe, isNull, reason: "a strike marks nobody while they're off");
      expect(dg.omens, hasLength(40));
      // Triumph: a troop falls, the monsters near stay as they were.
      final (tg, tk, to) = duel(omens: all, factor: 2, big: false);
      placeNow(tg, 'archer', 0, 1).cd = hold;
      tk.hp = 1;
      blowOn(tg, tk, to);
      expect(tk.alive, isFalse);
      expect(to.effects, isEmpty);
    });
  });
}
