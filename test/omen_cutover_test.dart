// Shadow batch L-3 (decisions-log 209, lib/omen.dart; catalog-bayangan-v2 §2, §3.1 and §5.2; docs/units-and-combat.md
// "Bayangan on the field", docs/loot-items-relics.md "Bayangan"): Sap, the Langka pool's troop debuff, and the Langka
// cut-over. Sap's row (the Langka pool alone, its numbers, icon, no needs, the debuff flag: one a pool, never a
// counter), the cap at E8 and the HUD number equal to it, and with omens on its effect: a monster's every 4th normal
// attack (on the count Pummel reads, a shot's too, the boss's too) makes the troop it hits deal less for 2 s, a weaken
// a monster put on it (a cleanse ends it). The cut-over: Armor, Mend, Barrier and Escort leave the Langka pool, which
// is now the design's thirty in its order; Legenda's keeps today's seven (Epik's and Legenda's had their own cut-overs
// since: omen_epik_cutover_test.dart, omen_legenda_cutover_test.dart); a Langka card never shows the four nor overflows into them, and the levels a save holds
// of them stay and act. With omens off none of it acts. Salt Charm and Pure Water against Sap: pusaka_langka3_test.dart.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

const sap = OmenKind.sap, pummel = OmenKind.pummel;

/// Today's seven, whole in the Legenda pool until its cut-over (Epik's kept two: batch E-3).
const seven = [OmenKind.armor, OmenKind.haste, OmenKind.mend, OmenKind.thorns, OmenKind.wound, OmenKind.shield, OmenKind.guard];

/// The four the Langka cut-over takes out of the Langka pool.
const leaving = [OmenKind.armor, OmenKind.mend, OmenKind.shield, OmenKind.guard];

/// catalog-bayangan-v2 §2's Langka pool, in its order: the thirty.
const langka30 = [
  OmenKind.haste, OmenKind.thorns, OmenKind.wound, OmenKind.brace, OmenKind.stubborn, OmenKind.sunder, //
  OmenKind.shieldbreak, OmenKind.unshaken, OmenKind.quickSpells, OmenKind.thrift, OmenKind.lingering, OmenKind.avenge,
  OmenKind.feed, OmenKind.grudge, OmenKind.bearHide, OmenKind.eager, OmenKind.healerHunt, sap, OmenKind.hardShell,
  OmenKind.spellTax, OmenKind.offBeat, OmenKind.drag, OmenKind.scar, OmenKind.deflect, OmenKind.gloat, OmenKind.rekindle,
  pummel, OmenKind.fade, OmenKind.defiant, OmenKind.straggler,
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

/// What a shot took off [u]: [by] fires once now, and the shot flies until it lands.
double shotOn(Game g, Unit u, Unit by) {
  final hp = u.hp;
  blowOn(g, u, by);
  for (var i = 0; i < 40 && g.shots.isNotEmpty; i++) {
    g.tick(0.05);
  }
  return hp - u.hp;
}

/// A knight and a monster of [tier] beside it, both standing, the knight with HP to spare; the enemy holding [omens] at
/// [factor].
(Game, Unit, Unit) duel({List<OmenKind> omens = const [], double factor = 1, Tier tier = Tier.normal}) {
  final g = plain(omens: omens, factor: factor);
  final k = placeNow(g, 'knight', 2, 3)
    ..busyUntil = hold
    ..maxHp = 100000
    ..hp = 100000;
  final o = foeAt(g, 'orc', k.pos + const Point(12, 0), tier)
    ..maxHp = 1000000
    ..hp = 1e6;
  return (g, k, o);
}

/// The weaken on troop [u] now ([Status.weaken]): its k, or null.
double? weakenOn(Game g, Unit u) => g.effectOn(u, Status.weaken)?.k;

void main() {
  tearDown(() => omensOn = omensDefault);

  group('the rows', () {
    test("Sap sits in the Langka pool alone, after Healer Hunt; its numbers, title, icon (an existing sheet's cell, its "
        'own), no needs, not troop-side; the troop debuff: one a pool, at most omenDebuffMax s, no Pusaka names it', () {
      expect(sap.tiers, {Rarity.langka});
      expect((sap.k, sap.title, sap.troopSide, sap.debuff, sap.live), ((perE: 0.03, max: 0.2), 'Sap', false, true, true));
      expect(sap.needs, isEmpty);
      expect(sap.byL, isEmpty);
      expect([omenSapEvery, omenSapTime, omenDebuffMax], [4, 2, 3]);
      expect(omenSapTime, lessThanOrEqualTo(omenDebuffMax));
      final icon = sap.icon!;
      expect((icon.sheet, icon.x, icon.y, icon.size, icon.tint), ('item_sword.png', 0, 0, 32, tintDarkRed));
      expect(File('assets/images/item_sword.png').existsSync(), isTrue);
      final cells = [for (final k in OmenKind.values) if (k.icon case final i?) (i.sheet, i.x, i.y, i.tint)];
      expect(cells.where((c) => c == (icon.sheet, icon.x, icon.y, icon.tint)), hasLength(1), reason: 'its own');
      expect([for (final k in OmenKind.values) if (k.debuff) k], [sap, OmenKind.batVenom, OmenKind.blight],
          reason: "Bat Venom is the Epik pool's (omen_epik_cutover_test.dart), Blight the Legenda pool's (omen_legenda_cutover_test.dart)");
      for (final r in [Rarity.langka, Rarity.epik, Rarity.legenda]) {
        expect(omenPool(r).where((k) => k.debuff).length, lessThanOrEqualTo(1), reason: '${r.name}: one troop debuff a pool');
      }
      expect(sap.answers, isEmpty, reason: 'faces only: the tilt never aims a debuff');
      for (final MapEntry(key: r, value: art) in pusakaCatalog.entries) {
        expect([art.counter, art.healerCounter], isNot(contains(sap)), reason: '$r');
      }
      expect(omenCanAct(sap, const {}), isTrue, reason: 'it needs nothing');
    });
  });

  group('the cut-over', () {
    test("the Langka pool is the design's thirty in its order; Armor, Mend, Barrier and Escort left it for Epik's and "
        "Legenda's (Barrier and Escort, since the Epik cut-over, for Legenda's alone), which keeps today's seven; every "
        "kind of it sits in Langka's alone but today's three", () {
      expect(omenPool(Rarity.langka), langka30);
      expect(langka30, hasLength(30));
      expect(omenPool(Rarity.epik).where(leaving.contains), [OmenKind.armor, OmenKind.mend],
          reason: "the Epik cut-over took Barrier and Escort out of Epik's too (omen_epik_cutover_test.dart)");
      expect(omenPool(Rarity.legenda).where(seven.contains), [OmenKind.shield, OmenKind.guard],
          reason: "the Legenda cut-over (batch G-3) took the other five out of Legenda's (omen_legenda_cutover_test.dart)");
      for (final k in leaving) {
        expect(k.tiers, {OmenKind.armor, OmenKind.mend}.contains(k) ? {Rarity.epik} : {Rarity.legenda}, reason: '$k');
      }
      for (final k in langka30) {
        expect(k.tiers, {Rarity.langka}, reason: "$k: today's three left Epik's, then Legenda's");
      }
      expect(omenOrder, OmenKind.values, reason: "an old save's catch-up still overflows along every kind");
      expect(omenOneTier, isTrue, reason: 'the last cut-over (Legenda, batch G-3) turned it on');
      // Every Langka Pusaka's counter is in the pool; none names one of the four.
      for (final MapEntry(key: r, value: art) in pusakaCatalog.entries) {
        if (art.rarity != Rarity.langka) continue;
        expect(langka30, contains(art.counter), reason: '$r');
      }
    });

    test('a Langka card never shows the four, whatever the draw; its counter keeps its tilt; an Epik card still may show '
        'Armor and Mend, a Legenda card Barrier and Escort (the Legenda cut-over took Armor and Mend out)', () {
      final cards = [for (final r in Relic.values) if (r.pusaka && r.rarity == Rarity.langka && pusakaCatalog[r]!.live) r];
      expect(cards, hasLength(30));
      for (final r in cards) {
        final faces = {for (var i = 0; i < 300; i++) omenFace(r, null, (i + 0.5) / 300)!};
        expect(faces.intersection(leaving.toSet()), isEmpty, reason: '$r');
        expect(omenFace(r, null, 0), pusakaCatalog[r]!.counter, reason: '$r: the tilt');
      }
      final epik = {for (var i = 0; i < 300; i++) omenFace(Relic.godThunder, null, (i + 0.5) / 300)!};
      expect(epik, containsAll([OmenKind.armor, OmenKind.mend]));
      expect(epik.intersection({OmenKind.shield, OmenKind.guard}), isEmpty, reason: "the Epik cut-over took them out of Epik's");
      final legenda = {for (var i = 0; i < 300; i++) omenFace(Relic.dragonCrown, null, (i + 0.5) / 300)!};
      expect(legenda, containsAll([OmenKind.shield, OmenKind.guard]));
      expect(legenda.intersection({OmenKind.armor, OmenKind.mend}), isEmpty, reason: "the Legenda cut-over took them out of Legenda's");
    });

    test("a Langka take's overflow follows the Langka pool, never into the four; held levels of them still count toward "
        'the eight kinds', () {
      final pool = omenPool(Rarity.langka);
      // Straggler (the pool's last) full: one level wraps to the pool's first, Haste, not to Armor.
      expect(omenPlace(top(OmenKind.straggler), OmenKind.straggler, pool, 1), [OmenKind.haste]);
      // Seven kinds held, among them the four that left: the eighth may still come. With eight a new kind is full, and
      // the level goes to the next held kind of the Langka pool with room (Haste), never to one of the four.
      final held = [...leaving, OmenKind.haste, OmenKind.thorns, OmenKind.wound];
      expect(omenPlace(held, sap, pool, 1), [sap]);
      expect(omenPlace([...held, OmenKind.brace], sap, pool, 1), [OmenKind.haste], reason: 'eight kinds held');
      expect(omenPlace([...held, OmenKind.brace, ...top(OmenKind.haste), ...top(OmenKind.thorns), ...top(OmenKind.wound), ...top(OmenKind.brace)],
          sap, pool, 1), isEmpty, reason: "the Langka ones full: the four's room is never used");
    });

    test("a save holding levels of the four loads them, and they act as before (Armor's cut, Barrier's shield, Mend's "
        'regen, Escort\'s guards)', () {
      omensOn = true;
      final g = plain(omens: [...levels(OmenKind.armor, 2), OmenKind.mend, OmenKind.shield, OmenKind.guard]);
      final back = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
      expect(back.omens, [OmenKind.armor, OmenKind.armor, OmenKind.mend, OmenKind.shield, OmenKind.guard]);
      back.omenFactor = 1;
      expect([back.omenK(OmenKind.armor), back.omenK(OmenKind.mend), back.omenK(OmenKind.shield)], [0.1, 0.003, 0.05]);
      expect(back.omenGuards, 1);
      // Armor still cuts a troop's blow.
      final (h, k, o) = duel(omens: levels(OmenKind.armor, 2));
      final (b, bk, bo) = duel();
      expect(blowOn(h, o, k), closeTo(blowOn(b, bo, bk) * 0.9, 1e-9));
    });
  });

  group('the HUD numbers', () {
    setUp(() => omensOn = true);

    test("at E8 Sap shows its capped share (its max), the one its hook reads; its line short and in English", () {
      final g = plain(omens: top(sap), factor: 2);
      foeAt(g, 'orc', const Point(300, 60)); // a wave on: the HUD shows its frozen factor
      final v = omenShown(sap, omenCap, 8);
      expect(v.x, sap.k.max, reason: 'E8 is past its max');
      expect(g.omenK(sap), v.x);
      expect(g.omenShownK(sap), v.x);
      expect(g.omenEffect(sap), 'Every 4th monster hit makes a troop deal 20% less damage for 2s.');
      expect(plain(omens: [sap]).omenEffect(sap), 'Every 4th monster hit makes a troop deal 3% less damage for 2s.');
      final line = g.omenLine(sap);
      expect(line.length, lessThanOrEqualTo(80), reason: line);
      expect(line.codeUnits.every((c) => c < 128), isTrue, reason: line);
    });
  });

  group('on', () {
    setUp(() => omensOn = true);

    test("Sap: a monster's every 4th normal attack makes the troop it hits deal × (1 − share) for 2s, at most 20% less; "
        'a weaken a monster put on it', () {
      for (final (n, factor, k) in [(1, 1.0, 0.03), (4, 1.0, 0.12), (4, 2.0, 0.2)]) {
        final (g, kn, o) = duel(omens: levels(sap, n), factor: factor);
        final weakens = <double?>[];
        for (var i = 0; i < 4; i++) {
          blowOn(g, kn, o);
          weakens.add(weakenOn(g, kn));
        }
        expect(weakens, [null, null, null, closeTo(1 - k, 1e-9)], reason: 'L$n ×$factor');
        final e = g.effectOn(kn, Status.weaken)!;
        expect((e.bad, e.by, e.omen), (true, o, true), reason: "a monster's, so a cleanse ends it");
        expect(e.until - g.t, inInclusiveRange(omenSapTime - 0.051, omenSapTime + 1e-9));
        expect(g.badOn(kn), 1);
        // It deals that much less now (a weakened blow, then its defence).
        final d = kn.stats.dmg;
        expect(blowOn(g, o, kn), closeTo(hitTaken(d * (1 - k), o.stats.def), 1e-9), reason: 'L$n ×$factor');
        runFor(g, omenSapTime.toDouble());
        expect(weakenOn(g, kn), isNull, reason: 'over after 2s');
        expect(blowOn(g, o, kn), closeTo(hitTaken(d, o.stats.def), 1e-9));
      }
    });

    test("Sap counts on Pummel's count (every 3rd a pummel, every 4th a sap, the 12th both); the boss's and a mini boss's "
        'blows too; a shot\'s 4th arrow; a skill\'s blow never counts', () {
      final (g, kn, o) = duel(omens: [...top(sap), ...top(pummel)], factor: 2);
      final sapped = <int>[];
      for (var i = 1; i <= 12; i++) {
        g.cleanse(kn); // each blow starts clean
        blowOn(g, kn, o);
        if (weakenOn(g, kn) != null) sapped.add(i);
      }
      expect(sapped, [4, 8, 12]);
      expect(o.blows, 12);
      for (final tier in [Tier.miniBoss, Tier.boss]) {
        final (h, hk, ho) = duel(omens: top(sap), factor: 2, tier: tier);
        for (var i = 0; i < 4; i++) {
          blowOn(h, hk, ho);
        }
        expect(weakenOn(h, hk), closeTo(0.8, 1e-9), reason: tier.name);
      }
      // A skeleton archer's 4th arrow saps where it lands.
      final s = plain(omens: top(sap), factor: 2);
      final sk = placeNow(s, 'knight', 2, 3)
        ..busyUntil = hold
        ..maxHp = 100000
        ..hp = 100000;
      final a = foeAt(s, 'skeleton_archer', sk.pos + const Point(40, 0));
      final shots = <double?>[];
      for (var i = 0; i < 4; i++) {
        shotOn(s, sk, a);
        shots.add(weakenOn(s, sk));
      }
      expect(shots, [null, null, null, closeTo(0.8, 1e-9)]);
      // A skill's blow is no attack: Brutal Swing leaves the count, and saps nobody.
      final sw = plain(omens: top(sap))..monsterSkills = true;
      sw
        ..startWave()
        ..queue.clear()
        ..omenFactor = 2;
      final u = sw.monster('elite_orc', Tier.highElite, const Point(250, 60))
        ..entered = true
        ..cd = hold;
      sw.units.add(u);
      sw.addEffect(u, Status.slow, hold, k: 0);
      final crowd = [
        for (final dy in [-6.0, 6.0])
          Unit(Side.troop, 'knight', troopTypes['knight']!, u.pos + Point(-10, dy))
            ..entered = true
            ..busyUntil = hold
            ..maxHp = 5000
            ..hp = 5000,
      ];
      sw.units.addAll(crowd);
      for (var i = 0; i < 400 && u.winding == null; i++) {
        sw.tick(0.05);
      }
      for (var i = 0; i < 40 && u.winding != null; i++) {
        sw.tick(0.05);
      }
      expect(u.blows, 0);
      expect([for (final c in crowd) weakenOn(sw, c)], [null, null]);
    });

    test('Sap: a stronger weaken already on the troop stays; a blocked blow lands no Sap', () {
      final (g, kn, o) = duel(omens: top(sap), factor: 2);
      g.addEffect(kn, Status.weaken, 10, k: 0.5, by: o, bad: true);
      for (var i = 0; i < 4; i++) {
        blowOn(g, kn, o);
      }
      expect(weakenOn(g, kn), 0.5, reason: 'the stronger stays');
      final (h, hk, ho) = duel(omens: top(sap), factor: 2);
      for (var i = 0; i < 3; i++) {
        blowOn(h, hk, ho);
      }
      h.addEffect(hk, Status.block, 10, k: 0, n: 1); // the next up-close blow does nothing
      blowOn(h, hk, ho);
      expect(weakenOn(h, hk), isNull, reason: 'blocked: it never landed');
    });
  });

  group('off', () {
    setUp(() => omensOn = false);

    test('with Sap at its most, nothing acts: no count, no weaken', () {
      final (g, kn, o) = duel(omens: top(sap), factor: 2);
      for (var i = 0; i < 8; i++) {
        blowOn(g, kn, o);
      }
      expect([o.blows, weakenOn(g, kn)], [0, null]);
      expect(g.omenEffect(sap), 'Every 4th monster hit makes a troop deal 0% less damage for 2s.');
    });
  });
}
