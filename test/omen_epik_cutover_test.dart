// Shadow batch E-3 (decisions-log 223, lib/omen.dart; catalog-bayangan-v2 §2, §3.2, §4 and §5.2; docs/units-and-combat.md
// "Bayangan on the field", docs/loot-items-relics.md "Bayangan"): Bat Venom, the Epik pool's troop debuff, and the Epik
// cut-over. Bat Venom's row (the Epik pool alone, after Old Bones; its numbers, icon, no needs, the debuff flag: one a
// pool, never a counter), the cap at E8 and the HUD number equal to it, and with omens on its effect: a bat's normal
// attack that lands makes the troop bleed its share of max HP a second for 3 s, from no one, a bleed a monster put on it
// (a cleanse ends it: Saint's Tear). The cut-over: Haste, Spikes, Wound, Barrier and Escort leave the Epik pool, which is
// now the design's thirty in its order; Langka's keeps its thirty (Legenda's had its own cut-over since:
// omen_legenda_cutover_test.dart); an Epik card never shows the five nor overflows into them, and the levels a save
// holds of them stay and act. The Grail, Dragon Heart and Dawn Star's healer counter switch, and the old saves' catch-up
// takes the new counters. With omens off none of it acts.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

const batVenom = OmenKind.batVenom;

/// Today's seven, whole in the Legenda pool until its cut-over.
const seven = [OmenKind.armor, OmenKind.haste, OmenKind.mend, OmenKind.thorns, OmenKind.wound, OmenKind.shield, OmenKind.guard];

/// The five the Epik cut-over takes out of the Epik pool.
const leaving = [OmenKind.haste, OmenKind.thorns, OmenKind.wound, OmenKind.shield, OmenKind.guard];

/// catalog-bayangan-v2 §2's Epik pool, in its order: the thirty.
const epik30 = [
  'Armor', 'Mend', 'Prey', 'Dark Hymn', 'Bone Arrows', 'Arrow Ward', 'Second Skin', 'Bile Sacs', 'Blood Moon', 'Mark Ward', //
  'Herd Hunt', 'Last Rage', 'Parting Gift', 'Old Bones', 'Bat Venom', 'Grave Pact', 'Captain', 'Enrage', 'Heal Siphon', 'Hunker',
  'Counterspell', 'Close Ranks', 'Wear Down', 'Blindside', 'Envy', 'Trickle', 'Toll', 'Zeal', 'Triumph', 'Muster',
];

/// catalog-bayangan-v2 §2's Langka pool, in its order (batch L-3's cut-over, unchanged).
const langka30 = [
  OmenKind.haste, OmenKind.thorns, OmenKind.wound, OmenKind.brace, OmenKind.stubborn, OmenKind.sunder, //
  OmenKind.shieldbreak, OmenKind.unshaken, OmenKind.quickSpells, OmenKind.thrift, OmenKind.lingering, OmenKind.avenge,
  OmenKind.feed, OmenKind.grudge, OmenKind.bearHide, OmenKind.eager, OmenKind.healerHunt, OmenKind.sap, OmenKind.hardShell,
  OmenKind.spellTax, OmenKind.offBeat, OmenKind.drag, OmenKind.scar, OmenKind.deflect, OmenKind.gloat, OmenKind.rekindle,
  OmenKind.pummel, OmenKind.fade, OmenKind.defiant, OmenKind.straggler,
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

/// A knight of 100000 max HP and a monster of [foe] 12 px from it, both standing; the enemy holding [omens] at [factor].
(Game, Unit, Unit) duel({List<OmenKind> omens = const [], double factor = 1, String foe = 'bat'}) {
  final g = plain(omens: omens, factor: factor);
  final k = placeNow(g, 'knight', 2, 3)
    ..busyUntil = hold
    ..maxHp = 100000
    ..hp = 100000;
  final o = foeAt(g, foe, k.pos + const Point(12, 0))
    ..maxHp = 1000
    ..hp = 500;
  return (g, k, o);
}

/// The bleed on troop [u] now ([Status.bleed]), or null.
Effect? bleedOn(Game g, Unit u) => g.effectOn(u, Status.bleed);

/// A PNG's width and height, from its header.
(int, int) pngSize(File f) {
  final b = f.readAsBytesSync();
  int at(int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
  return (at(16), at(20));
}

Map<String, dynamic> fixture(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, dynamic>;

void main() {
  tearDown(() => omensOn = omensDefault);

  group('the rows', () {
    test("Bat Venom sits in the Epik pool alone, after Old Bones; its numbers, title, icon (a bat from an existing sheet, "
        'green, its own), no needs, not troop-side; the troop debuff: one a pool, at most omenDebuffMax s, no Pusaka names '
        'it', () {
      expect(batVenom.tiers, {Rarity.epik});
      expect((batVenom.k, batVenom.title, batVenom.troopSide, batVenom.debuff, batVenom.live), ((perE: 0.01, max: 0.04), 'Bat Venom', false, true, true));
      expect(batVenom.needs, isEmpty);
      expect(batVenom.byL, isEmpty);
      expect((omenBatVenomTime, omenBatVenomType), (3, 'bat'));
      expect(omenBatVenomTime, lessThanOrEqualTo(omenDebuffMax));
      expect(monsterTypeNames.containsKey(omenBatVenomType), isTrue, reason: 'a monster type');
      final pool = omenPool(Rarity.epik);
      expect(pool.indexOf(batVenom), pool.indexOf(OmenKind.oldBones) + 1);
      final icon = batVenom.icon!;
      expect((icon.sheet, icon.x, icon.y, icon.size, icon.tint), ('tiny_bat_idle.png', 37, 32, 24, tintGreen));
      final f = File('assets/images/${icon.sheet}');
      expect(f.existsSync(), isTrue);
      final (w, h) = pngSize(f);
      expect(icon.x + icon.size <= w && icon.y + icon.size <= h, isTrue, reason: 'inside its sheet');
      final cells = [for (final k in OmenKind.values) if (k.icon case final i?) (i.sheet, i.x, i.y, i.tint)];
      expect(cells.where((c) => c == (icon.sheet, icon.x, icon.y, icon.tint)), hasLength(1), reason: 'its own');
      expect([for (final k in OmenKind.values) if (k.debuff) k], [OmenKind.sap, batVenom, OmenKind.blight],
          reason: "Blight is the Legenda pool's (omen_legenda_cutover_test.dart)");
      for (final r in [Rarity.langka, Rarity.epik, Rarity.legenda]) {
        expect(omenPool(r).where((k) => k.debuff).length, lessThanOrEqualTo(1), reason: '${r.name}: one troop debuff a pool');
      }
      expect(batVenom.answers, isEmpty, reason: 'faces only: the tilt never aims a debuff');
      for (final MapEntry(key: r, value: art) in pusakaCatalog.entries) {
        expect([art.counter, art.healerCounter], isNot(contains(batVenom)), reason: '$r');
      }
      expect(omenCanAct(batVenom, const {}), isTrue, reason: 'it needs nothing');
    });
  });

  group('the cut-over', () {
    test("the Epik pool is the design's thirty in its order; Haste, Spikes and Wound left it for Langka's (and Legenda's "
        "until the Legenda cut-over), Barrier and Escort for Legenda's alone; Langka's keeps its thirty", () {
      final epik = omenPool(Rarity.epik);
      expect([for (final k in epik) k.title], epik30);
      expect(epik, hasLength(30));
      expect(epik.where(leaving.contains), isEmpty);
      expect(omenPool(Rarity.langka), langka30);
      expect(omenPool(Rarity.legenda).take(2), [OmenKind.shield, OmenKind.guard],
          reason: "Barrier and Escort first since the Legenda cut-over (omen_legenda_cutover_test.dart); G-1B's kinds follow");
      for (final k in [OmenKind.haste, OmenKind.thorns, OmenKind.wound]) {
        expect(k.tiers, {Rarity.langka}, reason: '$k: the Legenda cut-over took it out of Legenda\'s');
      }
      for (final k in [OmenKind.shield, OmenKind.guard]) {
        expect(k.tiers, {Rarity.legenda}, reason: '$k');
      }
      for (final k in [OmenKind.armor, OmenKind.mend]) {
        expect(k.tiers, {Rarity.epik}, reason: '$k: the Legenda cut-over took it out of Legenda\'s');
      }
      for (final k in epik.skip(2)) {
        expect(k.tiers, {Rarity.epik}, reason: '$k: the Epik kinds alone');
      }
      expect(OmenKind.values.where((k) => k.tiers.length == 3), isEmpty, reason: 'no kind in every pool now');
      expect(omenOrder, OmenKind.values, reason: "an old save's catch-up still overflows along every kind");
      expect(omenOneTier, isTrue, reason: 'the last cut-over (Legenda, batch G-3) turned it on');
      // Every Epik Pusaka's counter is in the pool; none names one of the five.
      for (final MapEntry(key: r, value: art) in pusakaCatalog.entries) {
        if (art.rarity != Rarity.epik) continue;
        expect(epik, contains(art.counter), reason: '$r');
        if (art.healerCounter case final h?) expect(epik, contains(h), reason: '$r on a healer');
      }
    });

    test('an Epik card never shows the five, whatever the draw; its counter keeps its tilt; a Langka card still may show '
        'Haste, Spikes and Wound, a Legenda card Barrier and Escort (since the Legenda cut-over, not the other three)', () {
      final cards = [for (final r in Relic.values) if (r.pusaka && r.rarity == Rarity.epik && pusakaCatalog[r]!.live) r];
      expect(cards, hasLength(30));
      for (final r in cards) {
        for (final type in [null, 'priest']) {
          final faces = {for (var i = 0; i < 300; i++) omenFace(r, type, (i + 0.5) / 300)!};
          expect(faces.intersection(leaving.toSet()), isEmpty, reason: '$r $type');
          expect(omenFace(r, type, 0), omenCounter(r, type), reason: '$r $type: the tilt');
        }
      }
      final langka = {for (var i = 0; i < 300; i++) omenFace(Relic.snareCord, null, (i + 0.5) / 300)!};
      expect(langka, containsAll([OmenKind.haste, OmenKind.thorns, OmenKind.wound]));
      expect(langka.intersection({OmenKind.shield, OmenKind.guard}), isEmpty);
      final legenda = {for (var i = 0; i < 300; i++) omenFace(Relic.dragonCrown, null, (i + 0.5) / 300)!};
      expect(legenda, containsAll([OmenKind.shield, OmenKind.guard]));
      expect(legenda.intersection({OmenKind.haste, OmenKind.thorns, OmenKind.wound}), isEmpty);
    });

    test("an Epik take's overflow follows the Epik pool (Old Bones' into Bat Venom, Bat Venom's into Grave Pact, Muster's "
        'round to Armor), never into the five; held levels of them still count toward the eight kinds', () {
      final pool = omenPool(Rarity.epik);
      expect(omenPlace(levels(OmenKind.oldBones, 3), OmenKind.oldBones, pool, 2), [OmenKind.oldBones, batVenom]);
      expect(omenPlace(levels(batVenom, 3), batVenom, pool, 2), [batVenom, OmenKind.gravePact]);
      expect(omenPlace(top(OmenKind.muster), OmenKind.muster, pool, 1), [OmenKind.armor], reason: 'the pool round, not Haste');
      // Seven kinds held, five of them the ones that left: the eighth may still come. With eight a new kind is full, and
      // the level goes to the next held kind of the Epik pool with room (Dark Hymn), never to one of the five.
      final held = [...leaving, OmenKind.armor, OmenKind.mend];
      expect(omenPlace(held, OmenKind.prey, pool, 1), [OmenKind.prey]);
      expect(omenPlace([...held, OmenKind.darkHymn], OmenKind.prey, pool, 1), [OmenKind.darkHymn], reason: 'eight kinds held');
      expect(omenPlace([...held, ...top(OmenKind.darkHymn), ...top(OmenKind.armor), ...top(OmenKind.mend)], OmenKind.prey, pool, 1),
          isEmpty, reason: "the Epik ones full: the five's room is never used");
    });

    test("a save holding levels of the five loads them, and they act as before (Haste's, Spikes', Wound's and Barrier's "
        "shares, Escort's guards)", () {
      omensOn = true;
      final g = plain(omens: [...levels(OmenKind.haste, 2), OmenKind.thorns, OmenKind.wound, OmenKind.shield, OmenKind.guard]);
      final back = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
      expect(back.omens, [OmenKind.haste, OmenKind.haste, OmenKind.thorns, OmenKind.wound, OmenKind.shield, OmenKind.guard]);
      back.omenFactor = 1;
      expect([for (final k in leaving.take(4)) back.omenK(k)], [0.1, 0.03, 0.06, 0.05]);
      expect(back.omenGuards, 1);
    });
  });

  group('the counters and the catch-up', () {
    test("the Grail's counter is Prey, Dragon Heart's Wear Down, Dawn Star's on a healer Heal Siphon (its own elsewhere)", () {
      expect((pusakaCatalog[Relic.grail]!.counter, pusakaCatalog[Relic.dragonHeart]!.counter), (OmenKind.prey, OmenKind.wearDown));
      expect(pusakaCatalog[Relic.dawnStar]!.healerCounter, OmenKind.healSiphon);
      expect(omenCounter(Relic.dawnStar, 'priest'), OmenKind.healSiphon);
      expect(omenCounter(Relic.dawnStar, 'knight'), pusakaCatalog[Relic.dawnStar]!.counter);
      expect(omenCounter(Relic.dawnStar, 'knight'), isNot(OmenKind.healSiphon));
    });

    test("b86's catch-up takes the new counters: Wear Down 2 / Heal Siphon 2 / Mend 2 / Prey 2 / Armor 2, round-robin in "
        "Relic order; w89's twelve too", () {
      omensOn = true; // an old save owes its catch-up only while the Shadows are on
      final b86 = Game.fromJson(fixture('save-20261001-2005-pre-awaken.json'));
      expect(b86.pusaka[Relic.dawnStar]!.type, 'priest', reason: 'bound by default to the priests: Heal Siphon');
      const five = [OmenKind.wearDown, OmenKind.healSiphon, OmenKind.mend, OmenKind.prey, OmenKind.armor];
      expect(b86.omensOwed, [...five, ...five]);
      final w89 = Game.fromJson(fixture('save-20261002-2222-w89-sellbug.json'));
      const six = [OmenKind.wearDown, OmenKind.armor, OmenKind.mend, OmenKind.prey, OmenKind.armor, OmenKind.guard];
      expect(w89.omensOwed, [...six, ...six]);
      expect(w89.omensOwed.length, omenCatchUpMax);
    });
  });

  group('the HUD numbers', () {
    setUp(() => omensOn = true);

    test('at E8 Bat Venom shows its capped share (its max), the one its hook reads; its line short and in English', () {
      final g = plain(omens: top(batVenom), factor: 2);
      foeAt(g, 'orc', const Point(300, 60)); // a wave on: the HUD shows its frozen factor
      final v = omenShown(batVenom, omenCap, 8);
      expect(v.x, batVenom.k.max, reason: 'E8 is past its max');
      expect(g.omenK(batVenom), v.x);
      expect(g.omenShownK(batVenom), v.x);
      expect(g.omenEffect(batVenom), 'A Bat bite makes a troop lose 4% max HP a second for 3s.');
      expect(plain(omens: [batVenom]).omenEffect(batVenom), 'A Bat bite makes a troop lose 1% max HP a second for 3s.');
      final line = g.omenLine(batVenom);
      expect(line.length, lessThanOrEqualTo(80), reason: line);
      expect(line.codeUnits.every((c) => c < 128), isTrue, reason: line);
    });
  });

  group('on', () {
    setUp(() => omensOn = true);

    test("Bat Venom: a bat's normal attack that lands makes the troop bleed share × its max HP a second, 3 ticks, through "
        'its defence; a bleed a monster put on it, ticking from no one (Feed never hears it)', () {
      for (final (n, factor, k) in [(1, 1.0, 0.01), (2, 1.0, 0.02), (4, 2.0, 0.04)]) {
        final (g, kn, bat) = duel(omens: [...levels(batVenom, n), ...top(OmenKind.feed)], factor: factor);
        blowOn(g, kn, bat);
        final e = bleedOn(g, kn)!;
        expect(e.k, closeTo(100000 * k, 1e-6), reason: 'L$n ×$factor');
        expect((e.n, e.bad, e.omen, e.by), (omenBatVenomTime, true, true, bat), reason: 'L$n ×$factor');
        expect(e.until - g.t, inInclusiveRange(omenBatVenomTime + 0.5 - 0.051, omenBatVenomTime + 0.5 + 1e-9));
        expect(g.badOn(kn), 1);
        final hp = kn.hp, batHp = bat.hp;
        runFor(g, omenBatVenomTime + 0.5);
        expect(hp - kn.hp, closeTo(omenBatVenomTime * hitTaken(100000 * k, kn.stats.def), 1e-6), reason: 'L$n ×$factor');
        expect(bat.hp, batHp, reason: 'from no one: no Feed');
        expect(bleedOn(g, kn), isNull, reason: 'over after 3 ticks');
      }
    });

    test('Bat Venom: a bite on a troop the venom holds runs it 3s from now, its next tick kept; a stronger bleed stays; a '
        "blocked bite and another monster's blow bleed none", () {
      final (g, kn, bat) = duel(omens: top(batVenom), factor: 2);
      blowOn(g, kn, bat);
      final e = bleedOn(g, kn)!, next = e.next;
      runFor(g, 0.5);
      blowOn(g, kn, bat);
      expect(identical(bleedOn(g, kn), e), isTrue, reason: 'the same bleed');
      expect((e.n, e.next), (omenBatVenomTime, next), reason: 'renewed, its next tick kept');
      expect(e.until - g.t, closeTo(omenBatVenomTime + 0.5, 0.051));
      // A stronger bleed (a skill's) stays.
      final (s, sk, sb) = duel(omens: top(batVenom), factor: 2);
      s.addEffect(sk, Status.bleed, 10, k: 1e6, by: sb, n: 5, bad: true);
      blowOn(s, sk, sb);
      expect((bleedOn(s, sk)!.k, bleedOn(s, sk)!.omen), (1e6, false));
      // Blocked: it never landed.
      final (b, bk, bb) = duel(omens: top(batVenom), factor: 2);
      b.addEffect(bk, Status.block, 10, k: 0, n: 1); // the next up-close blow does nothing
      blowOn(b, bk, bb);
      expect(bleedOn(b, bk), isNull);
      // An orc's blow: none.
      final (o, ok, orc) = duel(omens: top(batVenom), factor: 2, foe: 'orc');
      blowOn(o, ok, orc);
      expect(bleedOn(o, ok), isNull);
    });

    test("Bat Venom: a troop's cleanse ends it; Saint's Tear on its type's skill does", () {
      final (g, kn, bat) = duel(omens: top(batVenom), factor: 2);
      blowOn(g, kn, bat);
      expect(g.cleanse(kn), 1);
      expect(bleedOn(g, kn), isNull);
      // A soldier holding Saint's Tear, bitten, casts Hold Fast: the bleed ends.
      final s = bareGame(Random(1))
        ..heroSkills = false
        ..monsterSkills = false;
      final u = placeNow(s, 'soldier', 2, 3);
      s
        ..givePusaka(Relic.saintTear, type: 'soldier')
        ..omens.addAll(top(batVenom))
        ..startWave()
        ..queue.clear()
        ..omenFactor = 2;
      u
        ..cd = hold
        ..mp = 0;
      for (final d in const <Point<double>>[Point(10, 0), Point(10, -8)]) {
        foeAt(s, 'orc', u.pos + d).hp = 1e4;
      }
      final b = foeAt(s, 'bat', u.pos + const Point(-10, 0));
      b
        ..busyUntil = double.negativeInfinity
        ..cd = 0;
      s.tick(0.05);
      b.busyUntil = hold;
      expect(bleedOn(s, u)?.omen, isTrue, reason: 'bitten');
      u.mp = u.stats.mp.toDouble();
      s.tick(0.05);
      expect(s.log.entries.whereType<SkillCast>(), hasLength(1), reason: 'Hold Fast cast');
      expect(bleedOn(s, u), isNull);
      expect(s.pusakaWorth[Relic.saintTear]!.uses, 1);
    });
  });

  group('off', () {
    setUp(() => omensOn = false);

    test('with Bat Venom at its most, nothing acts: no bleed', () {
      final (g, kn, bat) = duel(omens: top(batVenom), factor: 2);
      blowOn(g, kn, bat);
      expect(bleedOn(g, kn), isNull);
      expect(g.omenEffect(batVenom), 'A Bat bite makes a troop lose 0% max HP a second for 3s.');
    });
  });
}
