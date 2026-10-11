// Shadow batch G-3 (decisions-log 243, lib/omen.dart; catalog-bayangan-v2 §2, §3.3, §4 and §5.2; docs/units-and-combat.md
// "Bayangan on the field", docs/loot-items-relics.md "Bayangan"): Blight, the Legenda pool's troop debuff, and the Legenda
// cut-over, the last. Blight's row (the Legenda pool alone, after Thornproof; its numbers, icon, no needs, the debuff
// flag: one a pool; the Legenda heal penalty on the tilt, Vampire Kiss's counter), the cap at E8 and the HUD number
// equal to it, and with omens on its effect: the boss's or a mini boss's blow that lands stops the troop's heals in a
// wave for its time (a noHeal a monster put on it: a cleanse ends it; no healer picks it while it lasts). The cut-over:
// Armor, Mend, Haste, Spikes and Wound leave the Legenda pool, which is now the design's thirty in its order; every kind
// sits in one tier ([omenOneTier]); a Legenda card never shows the five nor overflows into them, and the levels a save
// holds of them stay and act; the old saves' catch-up is as it was. With omens off none of it acts.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

const blight = OmenKind.blight;

/// The five the Legenda cut-over takes out of the Legenda pool.
const leaving = [OmenKind.armor, OmenKind.haste, OmenKind.mend, OmenKind.thorns, OmenKind.wound];

/// catalog-bayangan-v2 §2's Legenda pool, in its order: the thirty (Shield and Guard by their glossary titles).
const legenda30 = [
  'Barrier', 'Escort', 'Spell Ward', 'Scatter', 'Holy Ward', 'Cover', 'Hero Hunt', 'Thornproof', 'Blight', 'Renewal', //
  'Rust', 'Side Swing', 'Oathbane', 'Veterans', 'Last Gasp', 'Rider Rush', 'Hardy', 'Unbowed', 'Executioner', 'Spite',
  'Deathless', 'Blunt', 'Adapt', 'Warlord', 'Spree', 'Vultures', 'Mana Burn', 'Dusk', 'Backlash', 'Horde',
];

/// catalog-bayangan-v2 §2's Epik pool, in its order (batch E-3's cut-over, unchanged).
const epik30 = [
  'Armor', 'Mend', 'Prey', 'Dark Hymn', 'Bone Arrows', 'Arrow Ward', 'Second Skin', 'Bile Sacs', 'Blood Moon', 'Mark Ward', //
  'Herd Hunt', 'Last Rage', 'Parting Gift', 'Old Bones', 'Bat Venom', 'Grave Pact', 'Captain', 'Enrage', 'Heal Siphon', 'Hunker',
  'Counterspell', 'Close Ranks', 'Wear Down', 'Blindside', 'Envy', 'Trickle', 'Toll', 'Zeal', 'Triumph', 'Muster',
];

/// catalog-bayangan-v2 §2's Langka pool, in its order (batch L-3's cut-over, unchanged).
const langka30 = [
  'Haste', 'Spikes', 'Wound', 'Brace', 'Stubborn', 'Sunder', 'Shieldbreak', 'Unshaken', 'Quick Spells', 'Thrift', //
  'Lingering', 'Avenge', 'Feed', 'Grudge', 'Bear Hide', 'Eager', 'Healer Hunt', 'Sap', 'Hard Shell', 'Spell Tax', 'Off Beat',
  'Drag', 'Scar', 'Deflect', 'Gloat', 'Rekindle', 'Pummel', 'Fade', 'Defiant', 'Straggler',
];

/// [n] levels of [kind].
List<OmenKind> levels(OmenKind kind, int n) => List.filled(n, kind);

/// [kind] at its most levels: at the Beban factor 2 that is E8, past its max.
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

/// A knight of 100000 max HP at half of it and an orc of [tier] 12 px from it, both standing (a wave on while the orc
/// lives); the enemy holding [omens] at [factor].
(Game, Unit, Unit) duel({List<OmenKind> omens = const [], double factor = 1, Tier tier = Tier.boss}) {
  final g = plain(omens: omens, factor: factor);
  final k = placeNow(g, 'knight', 2, 3)
    ..busyUntil = hold
    ..maxHp = 100000
    ..hp = 50000;
  final o = foeAt(g, 'orc', k.pos + const Point(12, 0), tier)
    ..maxHp = 1000000
    ..hp = 1e6;
  return (g, k, o);
}

/// The noHeal on troop [u] now ([Status.noHeal]: Blight's), or null.
Effect? blightOn(Game g, Unit u) => g.effectOn(u, Status.noHeal);

/// What a heal over time of 100 HP a second for 1 s gave troop [u], ticked [s] s.
double healedBy(Game g, Unit u, [double s = 0.5]) {
  final hp = u.hp;
  g.addEffect(u, Status.heal, 1, k: 100);
  runFor(g, s);
  return u.hp - hp;
}

/// A PNG's width and height, from its header.
(int, int) pngSize(File f) {
  final b = f.readAsBytesSync();
  int at(int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
  return (at(16), at(20));
}

Map<String, dynamic> fixture(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, dynamic>;

void main() {
  tearDown(() => omensOn = false);

  group('the row', () {
    test("Blight sits in the Legenda pool alone, after Thornproof; its numbers (seconds), title, icon (fx_hit_slime's "
        "frame 6 splat, mapped, olive, its own), no needs, not troop-side; the troop debuff: one a pool, at most "
        "omenDebuffMax s; the Legenda heal penalty on the tilt: Vampire Kiss names it", () {
      expect(blight.tiers, {Rarity.legenda});
      expect((blight.k, blight.title, blight.troopSide, blight.debuff, blight.live), ((perE: 0.75, max: 3.0), 'Blight', false, true, true));
      expect(blight.k.max, lessThanOrEqualTo(omenDebuffMax));
      expect((blight.needs.isEmpty, blight.byL.isEmpty, blight.who.isEmpty, blight.steps), (true, true, true, 0));
      final pool = omenPool(Rarity.legenda);
      expect(pool.indexOf(blight), pool.indexOf(OmenKind.thornproof) + 1);
      expect(pool.indexOf(OmenKind.renewal), pool.indexOf(blight) + 1);
      // The cell mapped first (shots/cat-G3/map-01-fx_hit_slime): frame 6's splat (its box 401,19 27x27) alone, inside
      // the frame (384..447), no speck of a neighbour's.
      final icon = blight.icon!;
      expect((icon.sheet, icon.x, icon.y, icon.size, icon.tint), ('fx_hit_slime.png', 399, 18, 30, tintOlive));
      expect(icon.x >= 6 * 64 && icon.x + icon.size <= 7 * 64, isTrue, reason: 'inside frame 6');
      final f = File('assets/images/${icon.sheet}');
      expect(f.existsSync(), isTrue);
      final (w, h) = pngSize(f);
      expect(icon.x + icon.size <= w && icon.y + icon.size <= h, isTrue, reason: 'inside its sheet');
      final cells = [for (final k in OmenKind.values) if (k.icon case final i?) (i.sheet, i.x, i.y, i.tint)];
      expect(cells.where((c) => c == (icon.sheet, icon.x, icon.y, icon.tint)), hasLength(1), reason: 'its own');
      expect([for (final k in OmenKind.values) if (k.debuff) k], [OmenKind.sap, OmenKind.batVenom, blight]);
      for (final r in [Rarity.langka, Rarity.epik, Rarity.legenda]) {
        expect(omenPool(r).where((k) => k.debuff), hasLength(1), reason: '${r.name}: one troop debuff a pool');
      }
      expect(blight.answers, [Relic.vampireKiss], reason: "the Legenda heal penalty on the tilt (Wound Langka's, Heal Siphon Epik's)");
      for (final MapEntry(key: r, value: art) in pusakaCatalog.entries) {
        if (r == Relic.vampireKiss) continue;
        expect([art.counter.debuff, art.healerCounter?.debuff ?? false], [false, false], reason: '$r: Sap and Bat Venom are faces only');
      }
      expect(omenCanAct(blight, const {}), isTrue, reason: 'it needs nothing');
    });
  });

  group('the cut-over', () {
    test("the Legenda pool is the design's thirty in its order; Armor and Mend left it for Epik's alone, Haste, Spikes and "
        "Wound for Langka's; Langka's and Epik's keep their thirty; every kind sits in one tier (omenOneTier)", () {
      final pool = omenPool(Rarity.legenda);
      expect([for (final k in pool) k.title], legenda30);
      expect(pool, hasLength(30));
      expect(pool.where(leaving.contains), isEmpty);
      expect([for (final k in omenPool(Rarity.langka)) k.title], langka30);
      expect([for (final k in omenPool(Rarity.epik)) k.title], epik30);
      for (final k in [OmenKind.armor, OmenKind.mend]) {
        expect(k.tiers, {Rarity.epik}, reason: '$k');
      }
      for (final k in [OmenKind.haste, OmenKind.thorns, OmenKind.wound]) {
        expect(k.tiers, {Rarity.langka}, reason: '$k');
      }
      for (final k in [OmenKind.shield, OmenKind.guard]) {
        expect(k.tiers, {Rarity.legenda}, reason: '$k');
      }
      expect(omenOneTier, isTrue, reason: 'the last cut-over');
      for (final k in OmenKind.values) {
        expect(k.tiers, hasLength(1), reason: '$k');
      }
      expect(OmenKind.values, hasLength(90), reason: '90 kinds, 30 a tier');
      expect({for (final r in [Rarity.langka, Rarity.epik, Rarity.legenda]) ...omenPool(r)}, OmenKind.values.toSet(), reason: 'every kind in a pool');
      expect(omenPool(Rarity.biasa), isEmpty);
      expect(omenOrder, OmenKind.values, reason: "an old save's catch-up still overflows along every kind");
      // Every Pusaka's counter is in its own tier's pool.
      for (final MapEntry(key: r, value: art) in pusakaCatalog.entries) {
        expect(omenPool(art.rarity), contains(art.counter), reason: '$r');
        if (art.healerCounter case final h?) expect(omenPool(art.rarity), contains(h), reason: '$r on a healer');
      }
    });

    test('a Legenda card never shows the five, whatever the draw; its counter keeps its tilt; a Langka card may still show '
        'Haste, Spikes and Wound, an Epik card Armor and Mend', () {
      final cards = [for (final r in Relic.values) if (r.pusaka && r.rarity == Rarity.legenda && pusakaCatalog[r]!.live) r];
      expect(cards, hasLength(30), reason: "today's three, G-1P's ten, G-2's eight, G-3's three, G-4's six oaths");
      for (final r in cards) {
        final faces = {for (var i = 0; i < 300; i++) omenFace(r, null, (i + 0.5) / 300)!};
        expect(faces.intersection(leaving.toSet()), isEmpty, reason: '$r');
        expect(omenFace(r, null, 0), omenCounter(r, null), reason: '$r: the tilt');
      }
      final all = {for (var i = 0; i < 300; i++) omenFace(Relic.dragonCrown, null, (i + 0.5) / 300)!};
      expect(all, containsAll([blight, OmenKind.shield, OmenKind.guard]));
      final langka = {for (var i = 0; i < 300; i++) omenFace(Relic.snareCord, null, (i + 0.5) / 300)!};
      expect(langka, containsAll([OmenKind.haste, OmenKind.thorns, OmenKind.wound]));
      final epik = {for (var i = 0; i < 300; i++) omenFace(Relic.bullyClub, null, (i + 0.5) / 300)!};
      expect(epik, containsAll([OmenKind.armor, OmenKind.mend]));
    });

    test("a Legenda take's overflow follows the Legenda pool (Thornproof's into Blight, Blight's into Renewal, Horde's round "
        'to Barrier), never into the five; held levels of them still count toward the eight kinds', () {
      final pool = omenPool(Rarity.legenda);
      expect(omenPlace(levels(OmenKind.thornproof, 3), OmenKind.thornproof, pool, 3), [OmenKind.thornproof, blight, blight]);
      expect(omenPlace(levels(blight, 3), blight, pool, 2), [blight, OmenKind.renewal]);
      expect(omenPlace(top(OmenKind.horde), OmenKind.horde, pool, 1), [OmenKind.shield], reason: 'the pool round, not Armor');
      // Seven kinds held, five of them the ones that left: the eighth may still come. With eight a new kind is full, and
      // the level goes round the Legenda pool to the next held kind with room (Barrier), never to one of the five.
      final held = [...leaving, OmenKind.shield, OmenKind.guard];
      expect(omenPlace(held, blight, pool, 1), [blight]);
      expect(omenPlace([...held, OmenKind.spellWard], blight, pool, 1), [OmenKind.shield], reason: 'eight kinds held');
      expect(omenPlace([...leaving, ...top(OmenKind.shield), ...top(OmenKind.guard), ...top(OmenKind.spellWard)], blight, pool, 1), isEmpty,
          reason: "the Legenda ones full: the five's room is never used");
    });

    test("a save holding levels of the five loads them, and they act as before (Armor's, Haste's, Mend's, Spikes' and "
        "Wound's shares)", () {
      omensOn = true;
      final g = plain(omens: [...levels(OmenKind.armor, 2), OmenKind.haste, OmenKind.mend, OmenKind.thorns, OmenKind.wound]);
      final back = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
      expect(back.omens, [OmenKind.armor, OmenKind.armor, OmenKind.haste, OmenKind.mend, OmenKind.thorns, OmenKind.wound]);
      back.omenFactor = 1;
      expect([for (final k in leaving) back.omenK(k)], [0.1, 0.05, closeTo(0.003, 1e-12), 0.03, 0.06]);
    });

    test("the old saves' catch-up is as it was: b86 Wear Down / Heal Siphon / Mend / Prey / Armor twice, w89's twelve", () {
      omensOn = true; // an old save owes its catch-up only while the Shadows are on
      final b86 = Game.fromJson(fixture('save-20261001-2005-pre-awaken.json'));
      const five = [OmenKind.wearDown, OmenKind.healSiphon, OmenKind.mend, OmenKind.prey, OmenKind.armor];
      expect(b86.omensOwed, [...five, ...five]);
      final w89 = Game.fromJson(fixture('save-20261002-2222-w89-sellbug.json'));
      const six = [OmenKind.wearDown, OmenKind.armor, OmenKind.mend, OmenKind.prey, OmenKind.armor, OmenKind.guard];
      expect(w89.omensOwed, [...six, ...six]);
    });
  });

  group('the HUD numbers', () {
    setUp(() => omensOn = true);

    test('at E8 Blight shows its capped time (its max, omenDebuffMax), the one its hook reads; at L1 0.75s; its line short '
        'and in English', () {
      final g = plain(omens: top(blight), factor: 2);
      foeAt(g, 'orc', const Point(300, 60)); // a wave on: the HUD shows its frozen factor
      final v = omenShown(blight, omenCap, 8);
      expect(v.x, blight.k.max, reason: 'E8 is past its max');
      expect(g.omenK(blight), v.x);
      expect(g.omenShownK(blight), v.x);
      expect(g.omenEffect(blight), 'A boss or mini boss hit stops heals on that troop for 3s.');
      expect(plain(omens: [blight]).omenEffect(blight), 'A boss or mini boss hit stops heals on that troop for 0.75s.');
      expect(plain(omens: levels(blight, 2)).omenEffect(blight), 'A boss or mini boss hit stops heals on that troop for 1.5s.');
      final line = g.omenLine(blight);
      expect(line.length, lessThanOrEqualTo(80), reason: line);
      expect(line.codeUnits.every((c) => c < 128), isTrue, reason: line);
    });
  });

  group('on', () {
    setUp(() => omensOn = true);

    test("Blight: the boss's or a mini boss's blow that lands puts a noHeal on the troop for its time (a monster's: bad, "
        "omen), capped at omenDebuffMax; a silver's, a gold's or a plain monster's none", () {
      for (final (n, factor, time) in [(1, 1.0, 0.75), (2, 1.0, 1.5), (4, 1.0, 3.0), (4, 2.0, 3.0)]) {
        for (final tier in [Tier.boss, Tier.miniBoss]) {
          final (g, k, o) = duel(omens: levels(blight, n), factor: factor, tier: tier);
          expect(blowOn(g, k, o), greaterThan(0));
          final e = blightOn(g, k)!;
          expect((e.bad, e.omen, e.by), (true, true, o), reason: 'L$n ×$factor $tier');
          expect(e.until - g.t, inInclusiveRange(time - 0.051, time + 1e-9), reason: 'L$n ×$factor $tier');
          expect(g.blighted(k), isTrue);
          expect(g.badOn(k), 1);
        }
      }
      for (final tier in [Tier.normal, Tier.elite, Tier.highElite]) {
        final (g, k, o) = duel(omens: top(blight), factor: 2, tier: tier);
        blowOn(g, k, o);
        expect(blightOn(g, k), isNull, reason: '$tier');
      }
      // A blocked blow never landed.
      final (b, bk, bo) = duel(omens: top(blight), factor: 2);
      b.addEffect(bk, Status.block, 10, k: 0, n: 1); // the next up-close blow does nothing
      blowOn(b, bk, bo);
      expect(blightOn(b, bk), isNull);
    });

    test('Blight: while it lasts no heal lands on the troop in a wave (its heal ceiling its HP: no healer picks it), and a '
        'new blow runs it from now; once it ends, heals land again', () {
      final (g, k, o) = duel(omens: levels(blight, 2)); // 1.5 s
      blowOn(g, k, o);
      expect(g.healCeil(k), k.hp, reason: 'nothing more while it lasts');
      expect(healedBy(g, k), 0);
      runFor(g, 0.5);
      blowOn(g, k, o);
      expect(blightOn(g, k)!.until - g.t, closeTo(1.5, 0.051), reason: 'from the new blow');
      runFor(g, 1.6);
      expect(blightOn(g, k), isNull);
      expect(g.blighted(k), isFalse);
      expect(g.healCeil(k), k.maxHp);
      expect(healedBy(g, k), closeTo(50, 1e-6), reason: 'half of a 100 HP a second heal over 0.5 s');
    });

    test("Blight: a priest passes over a blighted troop for the next most hurt one; a troop's cleanse ends it", () {
      final (g, k, o) = duel(omens: top(blight), factor: 2);
      final p = placeNow(g, 'priest', 0, 3)..cd = 0;
      final other = placeNow(g, 'soldier', 1, 3)..busyUntil = hold;
      p.pos = k.pos + const Point(-30, 0);
      other
        ..pos = k.pos + const Point(-15, 8)
        ..hp = other.maxHp * 0.8;
      final heard = <(Unit, HealSrc)>[];
      g.onTroopHeal = (u, src, _, _) => heard.add((u, src));
      blowOn(g, k, o);
      expect(g.blighted(k), isTrue);
      for (var i = 0; i < 60 && !heard.any((h) => h.$2 == HealSrc.heal); i++) {
        g.tick(0.05);
      }
      expect([for (final h in heard) if (h.$2 == HealSrc.heal) h.$1], everyElement(other), reason: 'the knight is blighted');
      expect(heard.where((h) => h.$2 == HealSrc.heal), isNotEmpty);
      expect(g.cleanse(k), 1);
      expect(g.blighted(k), isFalse);
      expect(healedBy(g, k), greaterThan(0));
    });
  });

  group('off', () {
    setUp(() => omensOn = false);

    test('with Blight at its most, nothing acts: no noHeal, heals land', () {
      final (g, k, o) = duel(omens: top(blight), factor: 2);
      blowOn(g, k, o);
      expect(blightOn(g, k), isNull);
      expect(healedBy(g, k), closeTo(50, 1e-6));
      expect(g.omenEffect(blight), 'A boss or mini boss hit stops heals on that troop for 0s.');
    });
  });
}
