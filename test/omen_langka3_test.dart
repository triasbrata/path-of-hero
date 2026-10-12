// Shadow batch L-3B (decisions-log 208, lib/omen.dart; catalog-bayangan-v2 §3.1; docs/units-and-combat.md "Bayangan on
// the field", docs/loot-items-relics.md "Bayangan"): six more Langka kinds. Their rows (the Langka pool alone, in the
// pool's order among L-1B's and L-2B's; numbers, icons, the troop-side flag, needs), the cap at E8 and the HUD number
// equal to it, and with omens on one test a kind: Grudge raises a monster's blow on last wave's top killer (and its
// bookkeeping: the pick, a tie, a wave with no kill, the save); Drag stretches a Rare or Epic Artifact's own cooldown on
// the engine's gate, never a Legendary one's; Scar stops a troop's heals in a wave short of its max HP, healers pass over
// a troop at that ceiling, and a heal that gave nothing runs no heals Fx; Gloat heals a monster that kills a troop;
// Rekindle heals a high elite whose skill lands; Pummel raises a monster's every 3rd normal attack, melee or shot, inside
// the dealt cap. With omens off none of it acts.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

const grudge = OmenKind.grudge, drag = OmenKind.drag, scar = OmenKind.scar, gloat = OmenKind.gloat;
const rekindle = OmenKind.rekindle, pummel = OmenKind.pummel;

/// The batch, in the Langka pool's order.
const batch = [grudge, drag, scar, gloat, rekindle, pummel];

/// Today's seven, whole in the Legenda pool until its cut-over (Langka's kept three: batch L-3; Epik's two: batch E-3).
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

/// A [troop] and a monster of [tier] beside it, both standing; the enemy holding [omens] at [factor].
(Game, Unit, Unit) duel({List<OmenKind> omens = const [], double factor = 1, String troop = 'knight', Tier tier = Tier.normal}) {
  final g = plain(omens: omens, factor: factor);
  final k = placeNow(g, troop, 2, 3)..busyUntil = hold;
  final o = foeAt(g, 'orc', k.pos + const Point(12, 0), tier);
  return (g, k, o);
}

/// The monster's blow on the troop of a fresh [duel], both [set] up so.
double foeBlow(
    {List<OmenKind> omens = const [],
    double factor = 1,
    String troop = 'knight',
    Tier tier = Tier.normal,
    void Function(Game, Unit k, Unit o)? set}) {
  final (g, k, o) = duel(omens: omens, factor: factor, troop: troop, tier: tier);
  set?.call(g, k, o);
  return blowOn(g, k, o);
}

/// Runs [body] with [relic]'s row holding [fx] in place of its own (the rest of the row kept), then puts the row back
/// (cleanse_test.dart's). A Pusaka given inside [body] is booked from the swapped row.
void withFx(Relic relic, List<Fx> fx, void Function() body) {
  final was = pusakaCatalog[relic]!;
  pusakaCatalog[relic] = Art(was.rarity, was.role, was.icon,
      fx: fx, epithet: was.epithet, counter: was.counter, healerCounter: was.healerCounter, store: was.store, live: was.live);
  try {
    body();
  } finally {
    pusakaCatalog[relic] = was;
  }
}

/// A wave of [g] begun with nothing to come, in which each troop of [kills] kills its count of orcs with its blows, then
/// won: Grudge's tally picks its top killer at the win.
void killThenWin(Game g, Map<Unit, int> kills) {
  g
    ..startWave()
    ..queue.clear();
  for (final MapEntry(key: k, value: n) in kills.entries) {
    for (var i = 0; i < n; i++) {
      final o = foeAt(g, 'orc', k.pos + const Point(12, 0))..hp = 1;
      blowOn(g, o, k);
      expect(o.alive, isFalse, reason: '${k.type} kills');
    }
  }
  if (g.enemies.isEmpty) foeAt(g, 'orc', const Point(300, 60)).gone = true; // a wave no troop killed in: one leaves
  runFor(g, deathTime + 0.2);
  expect(g.waveActive, isFalse, reason: 'won');
}

/// A troop of [type] standing at [at] that never moves or fights ([hold]), set down as is (cleanse_test.dart's).
Unit troopAt(Game g, String type, Point<double> at) {
  final u = Unit(Side.troop, type, troopTypes[type]!, at)
    ..entered = true
    ..busyUntil = hold;
  g.units.add(u);
  return u;
}

/// A wave on with nothing to come and an elite orc of [tier] standing at (250, 60) that never strikes, two knights in its
/// reach (Brutal Swing's crowd); the enemy holding [omens] at [factor], the monsters' skills on.
(Game, Unit) swinger({List<OmenKind> omens = const [], double factor = 1, Tier tier = Tier.highElite}) {
  final g = plain(omens: omens)..monsterSkills = true;
  g
    ..startWave()
    ..queue.clear()
    ..omenFactor = factor; // after the start, which freezes the army's own
  final u = g.monster('elite_orc', tier, const Point(250, 60))
    ..entered = true
    ..cd = hold;
  g.units.add(u);
  g.addEffect(u, Status.slow, hold, k: 0);
  for (final dy in [-6.0, 6.0]) {
    troopAt(g, 'knight', u.pos + Point(-10, dy))
      ..maxHp = 5000
      ..hp = 5000;
  }
  return (g, u);
}

/// [types] placed in rows 1, 2, … of column 2, standing still.
List<Unit> army(Game g, List<String> types) => [for (final (i, t) in types.indexed) placeNow(g, t, 2, i + 1)..busyUntil = hold];

/// A PNG's width and height, from its header.
(int, int) pngSize(File f) {
  final b = f.readAsBytesSync();
  int at(int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
  return (at(16), at(20));
}

void main() {
  tearDown(() => omensOn = omensDefault);

  group('the rows', () {
    test("the six sit in the Langka pool alone, in the pool's order among L-1B's and L-2B's after today's three that stay; "
        'their numbers, titles, troop-side flag, needs and icons (an existing sheet\'s cell, each unique)', () {
      // Today's three that stay in it since the Langka cut-over (batch L-3: omen_cutover_test.dart pins it whole).
      const pool = [
        OmenKind.haste, OmenKind.thorns, OmenKind.wound, OmenKind.brace, OmenKind.stubborn, OmenKind.sunder, OmenKind.shieldbreak, OmenKind.unshaken, //
        OmenKind.quickSpells, OmenKind.thrift, OmenKind.lingering, OmenKind.avenge, OmenKind.feed, grudge, OmenKind.bearHide,
        OmenKind.eager, OmenKind.healerHunt, OmenKind.hardShell, OmenKind.spellTax, OmenKind.offBeat, drag, scar,
        OmenKind.deflect, gloat, rekindle, pummel, OmenKind.fade, OmenKind.defiant, OmenKind.straggler,
      ];
      expect(omenPool(Rarity.langka).where(pool.contains), pool);
      expect(omenPool(Rarity.epik).take(2), [OmenKind.armor, OmenKind.mend], reason: 'the Epik cut-over (omen_epik_cutover_test.dart)');
      expect(omenPool(Rarity.legenda).take(2), [OmenKind.shield, OmenKind.guard],
          reason: "Barrier and Escort first since the Legenda cut-over (omen_legenda_cutover_test.dart); G-1B's kinds follow");
      expect(omenOrder, OmenKind.values);
      for (final k in batch) {
        expect(k.tiers, {Rarity.langka}, reason: '$k');
        expect(k.live, isTrue, reason: '$k');
      }
      expect({for (final k in batch) k: k.k}, {
        grudge: (perE: 0.04, max: 0.25),
        drag: (perE: 0.1, max: 0.5),
        scar: (perE: 0.05, max: 0.15),
        gloat: (perE: 0.05, max: 0.15),
        rekindle: (perE: 0.03, max: 0.15),
        pummel: (perE: 0.1, max: 0.3),
      });
      expect([for (final k in batch) k.title], ['Grudge', 'Drag', 'Scar', 'Gloat', 'Rekindle', 'Pummel']);
      expect(omenPummelEvery, 3);
      expect([for (final k in OmenKind.values) if (k.troopSide && k.tiers.contains(Rarity.langka)) k],
          [OmenKind.wound, OmenKind.sunder, OmenKind.spellTax, OmenKind.offBeat, drag, scar, OmenKind.fade]);
      expect({for (final k in batch) if (k.needs.isNotEmpty) k: k.needs}, {
        drag: {OmenNeed.cdFx},
        scar: {OmenNeed.heal},
      });
      for (final k in batch) {
        expect(k.byL, isEmpty, reason: '$k: a share, no count');
        for (final n in k.needs) {
          expect(n.built, isTrue, reason: '$k needs $n');
        }
      }
      expect([tintOlive, tintDarkGreen, tintDarkRed], [0xFF8A9A3A, 0xFF3F7F3F, 0xFFA0322D]);
      expect({for (final k in batch) k: (k.icon!.sheet, k.icon!.x, k.icon!.y, k.icon!.size, k.icon!.tint)}, {
        grudge: ('ui_icons.png', 176, 80, 16, null),
        drag: ('ui_icons.png', 64, 0, 16, tintOlive),
        scar: ('ui_icons.png', 0, 0, 16, tintDarkGreen),
        gloat: ('ui_icons.png', 80, 16, 16, tintDarkRed),
        rekindle: ('fx_upgrade.png', 384, 0, 64, tintGreen),
        pummel: ('fx_hit_orc_rider.png', 192, 0, 64, tintRed),
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

    test('needs: Drag acts on an army with a Rare or Epic Artifact on its own cooldown bound to a living type, Scar with a '
        'heal source; the other four always', () {
      final g = bareGame(Random(1))..heroSkills = true;
      for (final kind in batch) {
        expect(omenCanAct(kind, g.omenMet), kind != drag && kind != scar, reason: 'no army: $kind');
      }
      placeNow(g, 'knight', 2, 3);
      expect([omenCanAct(drag, g.omenMet), omenCanAct(scar, g.omenMet)], [false, false]);
      g.givePusaka(Relic.warDrum, type: 'knight');
      expect(omenCanAct(drag, g.omenMet), isFalse, reason: "War Drum's every 3rd has no cooldown");
      g.givePusaka(Relic.painCrystal, type: 'knight');
      expect(omenCanAct(drag, g.omenMet), isTrue, reason: "Pain Crystal's cooldown");
      placeNow(g, 'priest', 1, 3);
      expect(omenCanAct(scar, g.omenMet), isTrue, reason: 'a healer');
    });
  });

  group('the HUD numbers', () {
    setUp(() => omensOn = true);

    test('at E8 each shows its capped share (its max), the one its hooks read; Grudge names its target or none; every '
        'line short and in English', () {
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
      expect(g.omenEffect(grudge), "Monsters deal 25% more damage to last wave's top killer: none.");
      expect(g.omenEffect(drag), 'Rare and Epic Artifacts that work every few seconds wait 50% longer.');
      expect(g.omenEffect(scar), "In a wave, heals can't fill the last 15% of a troop's HP.");
      expect(g.omenEffect(gloat), 'A monster that kills a troop heals 15% HP. Not the boss or mini boss.');
      expect(g.omenEffect(rekindle), 'A strong monster heals 15% HP each time it uses a skill.');
      expect(g.omenEffect(pummel), 'Every 3rd hit of a monster deals 30% more. Not the boss or mini boss.');
      expect(plain(omens: [scar]).omenEffect(scar), "In a wave, heals can't fill the last 5% of a troop's HP.");
      for (final type in troopTypes.keys) {
        g.grudgeType = type;
        final line = g.omenLine(grudge);
        expect(line, "Grudge 4: Monsters deal 25% more damage to last wave's top killer: ${troopTypePlurals[type]}.");
        expect(line.length, lessThanOrEqualTo(80), reason: line);
      }
      for (final k in batch) {
        final line = g.omenLine(k);
        expect(line.length, lessThanOrEqualTo(80), reason: line);
        expect(line.codeUnits.every((c) => c < 128), isTrue, reason: line);
      }
    });
  });

  group('on', () {
    setUp(() => omensOn = true);

    test("Grudge: a monster's blow on a troop of last wave's top killer × (1 + share), at most 25%; on another type, or "
        'with none, never', () {
      final knight = foeBlow(), priest = foeBlow(troop: 'priest');
      for (final (n, factor, k) in [(1, 1.0, 0.04), (4, 1.0, 0.16), (4, 2.0, 0.25)]) {
        expect(foeBlow(omens: levels(grudge, n), factor: factor, set: (g, _, _) => g.grudgeType = 'knight'),
            closeTo(knight * (1 + k), 1e-9), reason: 'L$n ×$factor');
      }
      expect(foeBlow(omens: top(grudge), factor: 2, troop: 'priest', set: (g, _, _) => g.grudgeType = 'knight'), priest,
          reason: 'another type');
      expect(foeBlow(omens: top(grudge), factor: 2), knight, reason: 'no top killer');
      // A Hero is a troop of its type.
      expect(foeBlow(omens: top(grudge), factor: 2, set: (g, k, _) => (g.grudgeType = 'knight', k.hero = true)),
          closeTo(foeBlow(set: (g, k, _) => k.hero = true) * 1.25, 1e-9));
    });

    test("Grudge's bookkeeping: at a won wave's end the type whose troops killed the most, a tie to the first in "
        "troopTypes' order; a wave no troop killed in: none; fixed through the next wave; saved between waves", () {
      final g = plain(omens: top(grudge));
      final [soldier, knight, swordsman] = army(g, ['soldier', 'knight', 'swordsman']);
      expect(g.grudgeType, isNull, reason: 'no wave won yet');
      killThenWin(g, {soldier: 1, knight: 2, swordsman: 3});
      expect(g.grudgeType, 'swordsman');
      expect(g.omenEffect(grudge), "Monsters deal 16% more damage to last wave's top killer: Swordsmen.",
          reason: 'between waves: the next wave\'s target');
      killThenWin(g, {swordsman: 2, knight: 2, soldier: 1});
      expect(g.grudgeType, 'knight', reason: "a tie: knight before swordsman in troopTypes' order");
      // In a wave it holds, whatever is killed, until the wave is won.
      g
        ..startWave()
        ..queue.clear();
      for (var i = 0; i < 3; i++) {
        final o = foeAt(g, 'orc', soldier.pos + const Point(12, 0))..hp = 1;
        blowOn(g, o, soldier);
      }
      foeAt(g, 'orc', const Point(300, 60));
      expect(g.grudgeType, 'knight', reason: 'mid-wave: still the last won wave\'s');
      for (final o in g.enemies) {
        o.gone = true;
      }
      runFor(g, deathTime + 0.2);
      expect(g.grudgeType, 'soldier', reason: "that wave's three");
      killThenWin(g, {});
      expect(g.grudgeType, isNull, reason: 'a wave no troop killed in');
      expect(g.omenEffect(grudge), "Monsters deal 16% more damage to last wave's top killer: none.");

      // The save: between waves the target round-trips by name; none writes no key; an unknown type is skipped.
      killThenWin(g, {knight: 1});
      final saved = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
      expect(saved['grudgeType'], 'knight');
      expect(Game.fromJson(saved).grudgeType, 'knight');
      expect(Game.fromJson({...saved, 'grudgeType': 'dragon'}).grudgeType, isNull);
      g.grudgeType = null;
      expect(g.toJson().containsKey('grudgeType'), isFalse);
      // Off: no tally, no key.
      omensOn = false;
      final off = plain(omens: top(grudge));
      final [ok] = army(off, ['knight']);
      killThenWin(off, {ok: 2});
      expect(off.grudgeType, isNull);
      off.grudgeType = 'knight';
      expect(off.toJson().containsKey('grudgeType'), isFalse);
    });

    test("Drag (troop-side): a Rare or Epic Artifact's Fx on its own cooldown waits × (1 + share) for its next, at most "
        "50% longer, on the engine's cooldown gate (a strip's too); a Legendary one's never", () {
      /// How much later than without Drag the holder's Fx is ready again after one monster blow (Pain Crystal's
      /// `struck` MP, cd 1 s), the Pusaka [relic] holding that Fx.
      double later(List<OmenKind> omens, {double factor = 1, Relic relic = Relic.painCrystal}) {
        final (g, k, o) = duel(omens: omens, factor: factor);
        final (b, bk, bo) = duel();
        for (final (game, kn, orc) in [(g, k, o), (b, bk, bo)]) {
          game.givePusaka(relic, type: 'knight');
          kn.mp = 0;
          blowOn(game, kn, orc);
          expect(kn.fxReady, greaterThan(game.t), reason: 'the cooldown runs');
        }
        return k.fxReady - bk.fxReady;
      }

      for (final (n, factor, k) in [(1, 1.0, 0.1), (4, 1.0, 0.4), (4, 2.0, 0.5)]) {
        expect(later(levels(drag, n), factor: factor), closeTo(painCrystalK.cd * k, 1e-9), reason: 'L$n ×$factor');
      }
      final painFx = pusakaCatalog[Relic.painCrystal]!.fx;
      withFx(Relic.dawnStar, painFx, () {
        expect(later(top(drag), factor: 2, relic: Relic.dawnStar), closeTo(painCrystalK.cd * 0.5, 1e-9), reason: 'an Epic one');
      });
      withFx(Relic.dragonCrown, painFx, () {
        expect(later(top(drag), factor: 2, relic: Relic.dragonCrown), 0, reason: 'a Legendary one never');
      });
      expect(plain(omens: top(drag), factor: 2).omenDrag(Relic.dragonCrown), 1);

      // Spell Cutter's strip waits its k (6 s at ★1) on the same gate: 9 s under Drag at its most.
      double stripWait(List<OmenKind> omens) {
        final (g, k, o) = duel(omens: omens, factor: 2);
        g.givePusaka(Relic.spellCutter, type: 'knight');
        o.hp = 1e9;
        g.addEffect(o, Status.might, 100, k: 1.2, by: o);
        k.blows = 0;
        for (var i = 0; i < spellCutterK.every; i++) {
          blowOn(g, o, k);
        }
        expect(g.effectOn(o, Status.might), isNull, reason: 'stripped');
        return k.fxReady - g.t;
      }

      expect(stripWait(top(drag)) - stripWait(const []), closeTo(spellCutterK.cd[0] * 0.5, 1e-9));
    });

    test("Scar (troop-side): in a wave a troop's heals stop at 1 − share of its max HP, at most 15% short; never lower "
        'its HP; what passed full still counts against the real max; between waves none', () {
      /// A knight at [share] of its max HP with a huge regen (a heal each tick), mid-wave unless [between]: its HP after
      /// one tick and the heal past full the funnel reported.
      (double, double, Unit) regen(List<OmenKind> omens, double share, {double factor = 1, bool between = false}) {
        final g = plain(omens: omens, factor: factor);
        final k = placeNow(g, 'knight', 2, 3)..cd = hold; // never strikes; not held busy, so its regen ticks
        final s = k.stats;
        k
          ..stats = Stats(hp: s.hp, cost: s.cost, speed: s.speed, dmg: s.dmg, range: s.range, rate: s.rate, regen: 10000)
          ..hp = k.maxHp * share;
        if (!between) foeAt(g, 'orc', const Point(300, 60)); // mid-wave
        var past = 0.0;
        g.onTroopHeal = (u, src, asked, p) => past += u == k ? p : 0;
        g.tick(0.05);
        return (k.hp, past, k);
      }

      for (final (n, factor, k) in [(1, 1.0, 0.05), (2, 1.0, 0.1), (4, 2.0, 0.15)]) {
        final (hp, past, u) = regen(levels(scar, n), 0.5, factor: factor);
        expect(hp, closeTo(u.maxHp * (1 - k), 1e-9), reason: 'L$n ×$factor: its ceiling');
        expect(past, closeTo(u.maxHp * 0.5 + 500 - u.maxHp, 1e-9), reason: 'past full: against the real max HP');
      }
      final (high, _, hu) = regen(top(scar), 0.95, factor: 2);
      expect(high, closeTo(hu.maxHp * 0.95, 1e-9), reason: 'over the ceiling: never lowered');
      final (between, _, bu) = regen(top(scar), 0.5, factor: 2, between: true);
      expect(between, bu.maxHp, reason: 'between waves: to full');
      final (none, _, nu) = regen(const [], 0.5);
      expect(none, nu.maxHp);
    });

    test('Scar: a priest passes over a troop at its ceiling and heals one under it up to the ceiling; a heal that gave '
        'nothing runs no heals Fx', () {
      (Game, Unit, List<HealSrc>) scene(double share) {
        final g = plain(omens: top(scar), factor: 2);
        placeNow(g, 'priest', 0, 3);
        final k = placeNow(g, 'knight', 2, 3)
          ..busyUntil = hold
          ..cd = hold;
        k.hp = k.maxHp * share;
        foeAt(g, 'orc', const Point(300, 60)); // mid-wave
        final heals = <HealSrc>[];
        g.onTroopHeal = (u, src, _, _) => heals.add(src);
        return (g, k, heals);
      }

      final (g, k, heals) = scene(0.85);
      runFor(g, 4);
      expect(heals, isEmpty, reason: 'at the ceiling: no heal cast');
      expect(k.hp, closeTo(k.maxHp * 0.85, 1e-9));
      final (h, hk, hHeals) = scene(0.5);
      runFor(h, 8);
      expect(hk.hp, closeTo(hk.maxHp * 0.85, 1e-9), reason: 'healed up to the ceiling');
      final cast = hHeals.length;
      expect(cast, greaterThan(1));
      runFor(h, 4);
      expect(hHeals.length, cast, reason: 'then passed over');

      // A `heals` Fx on the priest's type (a gold one is built nowhere: it throws when it runs) runs on a heal that gave
      // HP, and never on one that gave nothing (a listener takes the heal back: no HP and none past full).
      withFx(Relic.dawnStar, [Fx(Trig.heals, Eff.gold, To.healed, k: [0.1])], () {
        final (a, ak, _) = scene(0.5);
        a.givePusaka(Relic.dawnStar, type: 'priest');
        expect(() => runFor(a, 3), throwsStateError, reason: 'a heal that gave HP');
        final (z, zk, _) = scene(0.5);
        z.givePusaka(Relic.dawnStar, type: 'priest');
        z.onTroopHeal = (u, src, _, _) => u.hp = u.maxHp * 0.5;
        runFor(z, 3);
        expect(zk.hp, closeTo(zk.maxHp * 0.5, 1e-9));
        expect(ak.alive, isTrue);
      });
    });

    test('Gloat: a monster that kills a troop heals share of its max HP, at most 15%; not the boss or a mini boss; a '
        'troop that falls to no one gives nothing', () {
      double gloats({List<OmenKind> omens = const [], double factor = 1, Tier tier = Tier.normal}) {
        final (g, k, o) = duel(omens: omens, factor: factor, tier: tier);
        k.hp = 1;
        o.hp = 10;
        blowOn(g, k, o);
        expect(k.alive, isFalse);
        return o.hp - 10;
      }

      expect(gloats(), 0);
      for (final (n, factor, k) in [(1, 1.0, 0.05), (4, 1.0, 0.15), (4, 2.0, 0.15)]) {
        final (_, _, o) = duel();
        expect(gloats(omens: levels(gloat, n), factor: factor), closeTo(o.maxHp * k, 1e-9), reason: 'L$n ×$factor');
      }
      for (final tier in [Tier.miniBoss, Tier.boss]) {
        expect(gloats(omens: top(gloat), factor: 2, tier: tier), 0, reason: tier.name);
      }
      expect(gloats(omens: top(gloat), factor: 2, tier: Tier.highElite), greaterThan(0));
      // A bleed's tick (no attacker) fells it: nobody heals.
      final (g, k, o) = duel(omens: top(gloat), factor: 2);
      o.hp = 10;
      k.hp = 1;
      g.addEffect(k, Status.bleed, 1.5, k: 30, n: 1, bad: true);
      for (var i = 0; i < 40 && k.alive; i++) {
        g.tick(0.05); // bounded: with its one troop fallen the game is over and stops its clock
      }
      expect([k.alive, o.hp], [false, 10]);
    });

    test('Rekindle: a high elite heals share of its max HP each time its skill lands, at most 15%; a wind-up broken off, '
        "or a mini boss's skill, never", () {
      /// An elite orc of [tier] (at 70% HP: no Bloodrage for a mini boss) winds up Brutal Swing; [broken]: a stun breaks
      /// it. The share of its max HP it gained from the cast.
      double cast(List<OmenKind> omens, {double factor = 1, Tier tier = Tier.highElite, bool broken = false}) {
        final (g, u) = swinger(omens: omens, factor: factor, tier: tier);
        u.hp = u.maxHp * 0.7;
        for (var i = 0; i < 400 && u.winding != MonsterSkill.brutalSwing; i++) {
          g.tick(0.05);
        }
        expect(u.winding, MonsterSkill.brutalSwing);
        final hp = u.hp;
        if (broken) u.stunUntil = g.t + 1;
        for (var i = 0; i < 40 && u.winding != null; i++) {
          g.tick(0.05);
        }
        return (u.hp - hp) / u.maxHp;
      }

      expect(cast(const []), 0);
      for (final (n, factor, k) in [(1, 1.0, 0.03), (4, 1.0, 0.12), (4, 2.0, 0.15)]) {
        expect(cast(levels(rekindle, n), factor: factor), closeTo(k, 1e-9), reason: 'L$n ×$factor');
      }
      expect(cast(top(rekindle), factor: 2, broken: true), 0, reason: 'broken off');
      expect(cast(top(rekindle), factor: 2, tier: Tier.miniBoss), 0, reason: 'a mini boss');
    });

    test("Pummel: a monster's every 3rd normal attack × (1 + share) on the troop it hits, at most 30%, a shot's too; "
        'not the boss or a mini boss; a skill blow never counts', () {
      final base = foeBlow();
      for (final (n, factor, k) in [(1, 1.0, 0.1), (4, 1.0, 0.3), (4, 2.0, 0.3)]) {
        final (g, kn, o) = duel(omens: levels(pummel, n), factor: factor);
        kn
          ..maxHp = 100000
          ..hp = 100000;
        final blows = [for (var i = 0; i < 6; i++) blowOn(g, kn, o)];
        expect(blows, [
          for (var i = 1; i <= 6; i++) closeToBlow(i % omenPummelEvery == 0 ? base * (1 + k) : base),
        ], reason: 'L$n ×$factor');
        expect(o.blows, 6);
      }
      for (final tier in [Tier.miniBoss, Tier.boss]) {
        final (g, kn, o) = duel(omens: top(pummel), factor: 2, tier: tier);
        kn
          ..maxHp = 100000
          ..hp = 100000;
        final blows = [for (var i = 0; i < 3; i++) blowOn(g, kn, o)];
        expect(blows[2], closeTo(blows[0], 1e-9), reason: tier.name);
      }
      // A skeleton archer's 3rd arrow lands harder.
      List<double> arrows(List<OmenKind> omens) {
        final g = plain(omens: omens, factor: 2);
        final kn = placeNow(g, 'knight', 2, 3)
          ..busyUntil = hold
          ..maxHp = 100000
          ..hp = 100000;
        final a = foeAt(g, 'skeleton_archer', kn.pos + const Point(40, 0));
        return [for (var i = 0; i < 3; i++) shotOn(g, kn, a)];
      }

      final plainShots = arrows(const []), pummelShots = arrows(top(pummel));
      expect(plainShots[0], greaterThan(0));
      expect(pummelShots, [closeToBlow(plainShots[0]), closeToBlow(plainShots[1]), closeToBlow(plainShots[2] * 1.3)]);
      // Inside the dealt cap: Pummel, Grudge and an omen might stop at 1.6 together.
      final (g, kn, o) = duel(omens: [...top(pummel), ...top(grudge)], factor: 2);
      g
        ..grudgeType = 'knight'
        ..addEffect(o, Status.might, 100, k: 1.2, omen: true);
      kn
        ..maxHp = 100000
        ..hp = 100000;
      final capped = [for (var i = 0; i < 3; i++) blowOn(g, kn, o)];
      expect(capped[0], closeTo(base * 1.2 * 1.25, 1e-9), reason: 'under the cap: the product');
      expect(capped[2], closeTo(base * omenDealtMost, 1e-9), reason: '1.2 × 1.25 × 1.3: the cap');
      // A skill's blow is no attack: Brutal Swing leaves the count.
      final (s, u) = swinger(omens: top(pummel), factor: 2);
      for (var i = 0; i < 400 && u.winding == null; i++) {
        s.tick(0.05);
      }
      for (var i = 0; i < 40 && u.winding != null; i++) {
        s.tick(0.05);
      }
      expect(u.blows, 0);
    });
  });

  group('off', () {
    setUp(() => omensOn = false);

    test('with every kind of the batch at its most, nothing acts: blows, cooldowns, heals, kills and casts land as with '
        'none, and no blow is counted', () {
      final all = [for (final k in batch) ...top(k)];
      final (g, k, o) = duel(omens: all, factor: 2);
      final (b, bk, bo) = duel();
      for (final (game, kn) in [(g, k), (b, bk)]) {
        game
          ..grudgeType = 'knight'
          ..givePusaka(Relic.painCrystal, type: 'knight');
        kn
          ..maxHp = 100000
          ..hp = 100000;
      }
      expect([for (var i = 0; i < 3; i++) blowOn(g, k, o)], [for (var i = 0; i < 3; i++) blowOn(b, bk, bo)],
          reason: 'Grudge, Pummel');
      expect(o.blows, 0, reason: 'no count');
      expect(k.fxReady, bk.fxReady, reason: 'Drag');
      expect(g.healCeil(k), k.maxHp);
      final (gl, gk, go) = duel(omens: all, factor: 2);
      gk.hp = 1;
      go.hp = 10;
      blowOn(gl, gk, go);
      expect([gk.alive, go.hp], [false, 10], reason: 'Gloat');
      expect(g.omenDrag(Relic.painCrystal), 1);
    });
  });
}

/// A blow's damage [v] to within float noise.
Matcher closeToBlow(double v) => closeTo(v, 1e-9);
