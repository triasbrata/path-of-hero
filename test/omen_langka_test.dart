// Shadow batch L-1B (decisions-log 204, lib/omen.dart; catalog-bayangan-v2 §3.1; docs/units-and-combat.md "Bayangan on
// the field", docs/loot-items-relics.md "Bayangan"): the first ten Langka kinds. Their rows (the Langka pool alone,
// after today's seven in the pool's order; numbers, icons, the troop-side flag, needs), the cap at E8 and the HUD number
// equal to it, and with omens on one test a kind: Brace, Stubborn, Bear Hide and Hard Shell cut a troop's blow inside
// the taken floor; Sunder weakens the troops' cuts; Unshaken shortens what troops put on monsters; Quick Spells a high
// elite's cooldown; Thrift the kill gold; Deflect cancels every nth normal attack and runs no `landed` Fx for it;
// Defiant raises a taunted monster's blow inside the dealt cap. With omens off none of it acts.
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

const brace = OmenKind.brace, stubborn = OmenKind.stubborn, sunder = OmenKind.sunder, unshaken = OmenKind.unshaken;
const quickSpells = OmenKind.quickSpells, thrift = OmenKind.thrift, bearHide = OmenKind.bearHide;
const hardShell = OmenKind.hardShell, deflect = OmenKind.deflect, defiant = OmenKind.defiant, armor = OmenKind.armor;

/// The batch, in the Langka pool's order.
const batch = [brace, stubborn, sunder, unshaken, quickSpells, thrift, bearHide, hardShell, deflect, defiant];

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

/// A knight and a monster of [type] and [tier] beside it, both standing; the enemy holding [omens] at [factor].
(Game, Unit, Unit) duel({List<OmenKind> omens = const [], double factor = 1, String type = 'orc', Tier tier = Tier.normal}) {
  final g = plain(omens: omens, factor: factor);
  final k = placeNow(g, 'knight', 2, 3)..busyUntil = hold;
  final o = foeAt(g, type, k.pos + const Point(12, 0), tier);
  return (g, k, o);
}

/// The knight's blow on the monster of a fresh [duel] whose monster is at [share] of its max HP and [set] up so.
double troopBlow({List<OmenKind> omens = const [], double factor = 1, String type = 'orc', double share = 1, void Function(Game, Unit)? set}) {
  final (g, k, o) = duel(omens: omens, factor: factor, type: type);
  o.hp = o.maxHp * share;
  set?.call(g, o);
  return blowOn(g, o, k);
}

/// The monster's blow on the knight of a fresh [duel] of [tier], both [set] up so.
double foeBlow({List<OmenKind> omens = const [], double factor = 1, Tier tier = Tier.normal, void Function(Game, Unit k, Unit o)? set}) {
  final (g, k, o) = duel(omens: omens, factor: factor, tier: tier);
  set?.call(g, k, o);
  return blowOn(g, k, o);
}

/// A PNG's width and height, from its header.
(int, int) pngSize(File f) {
  final b = f.readAsBytesSync();
  int at(int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
  return (at(16), at(20));
}

void main() {
  tearDown(() => omensOn = omensDefault);

  group('the rows', () {
    test("the ten sit in the Langka pool alone, after today's three that stay in the pool's order (batch L-2B's among them, "
        'omen_langka2_test.dart); their numbers, titles, troop-side flag, needs and icons (an existing sheet\'s cell, '
        'each unique)', () {
      // After today's three that stay in it since the Langka cut-over (batch L-3, omen_cutover_test.dart pins it whole).
      expect(omenPool(Rarity.langka).take(3), [OmenKind.haste, OmenKind.thorns, OmenKind.wound]);
      expect(omenPool(Rarity.langka).where(batch.contains), batch);
      expect(omenPool(Rarity.epik).take(2), [OmenKind.armor, OmenKind.mend], reason: 'the Epik cut-over (omen_epik_cutover_test.dart)');
      expect(omenPool(Rarity.legenda).take(2), [OmenKind.shield, OmenKind.guard],
          reason: "Barrier and Escort first since the Legenda cut-over (omen_legenda_cutover_test.dart); G-1B's kinds follow");
      expect(omenOrder, OmenKind.values);
      for (final k in batch) {
        expect(k.tiers, {Rarity.langka}, reason: '$k');
        expect(k.live, isTrue, reason: '$k');
      }
      expect({for (final k in batch) k: k.k}, {
        brace: (perE: 0.05, max: 0.3),
        stubborn: (perE: 0.06, max: 0.3),
        sunder: (perE: 0.08, max: 0.5),
        unshaken: (perE: 0.1, max: 0.5),
        quickSpells: (perE: 0.05, max: 0.3),
        thrift: (perE: 0.04, max: 0.3),
        bearHide: (perE: 0.06, max: 0.4),
        hardShell: (perE: 0.05, max: 0.3),
        deflect: (perE: 0.0, max: 0.0),
        defiant: (perE: 0.06, max: 0.25),
      });
      expect([for (final k in batch) k.title],
          ['Brace', 'Stubborn', 'Sunder', 'Unshaken', 'Quick Spells', 'Thrift', 'Bear Hide', 'Hard Shell', 'Deflect', 'Defiant']);
      expect([omenBraceAbove, omenStubbornBelow, omenDefiantBoss], [0.9, 0.3, 0.5]);
      expect(deflect.byL, [12, 8, 6, 5]);
      expect([for (final k in batch) if (k.troopSide) k], [sunder]);
      expect({for (final k in batch) if (k.needs.isNotEmpty) k: k.needs}, {
        unshaken: {OmenNeed.slow, OmenNeed.hold, OmenNeed.stun, OmenNeed.taunt, OmenNeed.weaken, OmenNeed.hex},
        defiant: {OmenNeed.taunt},
      });
      for (final k in batch) {
        for (final n in k.needs) {
          expect(n.built, isTrue, reason: '$k needs $n');
        }
      }
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

    test('needs: Unshaken acts on an army with a slow, hold, stun, taunt, weaken or hex source, Defiant with a taunt '
        'source; the other eight always', () {
      final g = bareGame(Random(1))..heroSkills = true;
      final k = placeNow(g, 'knight', 2, 3);
      expect(g.omenMet.intersection({OmenNeed.taunt, OmenNeed.stun, OmenNeed.slow}), isEmpty);
      for (final kind in batch) {
        expect(omenCanAct(kind, g.omenMet), kind != unshaken && kind != defiant, reason: '$kind');
      }
      k
        ..hero = true
        ..heroSkill = HeroSkill.duel;
      expect(omenCanAct(defiant, g.omenMet), isTrue, reason: 'the Duel of Honour taunts');
      expect(omenCanAct(unshaken, g.omenMet), isTrue);
      expect(omenCanAct(unshaken, {OmenNeed.hex}), isTrue);
      expect(omenCanAct(defiant, {OmenNeed.stun}), isFalse);
    });
  });

  group('the HUD numbers', () {
    setUp(() => omensOn = true);

    test('at E8 each shows its capped share (its max), the one its hooks read; Deflect counts by L, not the factor; '
        'every line short and in English', () {
      final g = plain(omens: [for (final k in batch) ...top(k)], factor: 2);
      foeAt(g, 'orc', const Point(300, 60)); // a wave on: the HUD shows its frozen factor
      expect(g.omenShownFactor, 2);
      for (final k in batch.where((k) => k != deflect)) {
        final v = omenShown(k, omenCap, 8);
        expect(v.x, min(k.k.max, k.k.perE * 8), reason: '$k');
        expect(v.x, k.k.max, reason: '$k: E8 is past its max');
        expect(g.omenK(k), v.x, reason: '$k: the hooks read the same');
        expect(g.omenShownK(k), v.x, reason: '$k');
        expect(g.omenEffect(k), contains('${omenPercent(v.x)}%'), reason: '$k');
      }
      for (var l = 1; l <= omenCap; l++) {
        expect(omenShown(deflect, l, l * 2.0).n, deflect.byL[l - 1], reason: 'L$l');
      }
      expect(g.omenDeflectEvery, 5);
      g.omenFactor = 1;
      expect(g.omenDeflectEvery, 5, reason: 'a count goes by L');
      expect(g.omenEffect(deflect), 'Each monster ignores every 5th troop attack on it. Skills still land.');
      g.omenFactor = 2;
      expect(g.omenEffect(brace), 'Monsters over 90% HP take 30% less damage.');
      expect(g.omenEffect(defiant), 'A monster made to fight a troop deals it 25% more. Bosses: half.');
      for (final k in batch) {
        final line = g.omenLine(k);
        expect(line.length, lessThanOrEqualTo(80), reason: line);
        expect(line.codeUnits.every((c) => c < 128), isTrue, reason: line);
      }
    });
  });

  group('on', () {
    setUp(() => omensOn = true);

    test('Brace: a troop\'s blow on a monster over 90% of its max HP (before the blow) is cut, at most 30%; at 90% or '
        'under, or a monster\'s blow on a troop, never', () {
      final base = troopBlow(), taken = foeBlow();
      expect(base, greaterThan(0));
      for (final (n, factor, cut) in [(1, 1.0, 0.05), (4, 1.0, 0.2), (4, 2.0, 0.3)]) {
        expect(troopBlow(omens: levels(brace, n), factor: factor), closeTo(base * (1 - cut), 1e-9), reason: 'L$n ×$factor');
      }
      expect(troopBlow(omens: top(brace), factor: 2, share: 0.91), closeTo(base * 0.7, 1e-9));
      expect(troopBlow(omens: top(brace), factor: 2, share: omenBraceAbove), closeTo(base, 1e-9), reason: 'at 90%: not over');
      expect(troopBlow(omens: top(brace), factor: 2, share: 0.5), closeTo(base, 1e-9));
      expect(foeBlow(omens: top(brace), factor: 2), taken, reason: 'the enemy side only');
    });

    test('Stubborn: a troop\'s blow on a monster under 30% of its max HP is cut, at most 30%; at 30% or over, never', () {
      final base = troopBlow(share: 0.2);
      for (final (n, factor, cut) in [(1, 1.0, 0.06), (4, 1.0, 0.24), (4, 2.0, 0.3)]) {
        expect(troopBlow(omens: levels(stubborn, n), factor: factor, share: 0.2), closeTo(base * (1 - cut), 1e-9), reason: 'L$n ×$factor');
      }
      expect(troopBlow(omens: top(stubborn), factor: 2, share: omenStubbornBelow), closeTo(base, 1e-9), reason: 'at 30%: not under');
      expect(troopBlow(omens: top(stubborn), factor: 2), closeTo(base, 1e-9));
      expect(foeBlow(omens: top(stubborn), factor: 2, set: (g, k, o) => o.hp = o.maxHp * 0.2), foeBlow());
    });

    test('Bear Hide: a troop\'s blow on a werebear is cut, at most 40%; on any other monster never', () {
      final bear = troopBlow(type: 'werebear'), orc = troopBlow();
      for (final (n, factor, cut) in [(1, 1.0, 0.06), (4, 1.0, 0.24), (4, 2.0, 0.4)]) {
        expect(troopBlow(omens: levels(bearHide, n), factor: factor, type: 'werebear'), closeTo(bear * (1 - cut), 1e-9));
      }
      expect(troopBlow(omens: top(bearHide), factor: 2), closeTo(orc, 1e-9), reason: 'an orc');
    });

    test('Hard Shell: a troop\'s blow on a monster with a shield (an absorb, a shot ward, a Barrier, a guard) is cut, at '
        'most 30%; on one without, never', () {
      final base = troopBlow();
      const tiny = 1e-6; // an absorb or a Barrier that soaks next to nothing
      final shields = <String, void Function(Game, Unit)>{
        'an absorb': (g, o) => g.addEffect(o, Status.absorb, 100, k: tiny, omen: true),
        'a shot ward': (g, o) => g.addEffect(o, Status.shotWard, 100, k: 0.5), // a knight's blow is no shot
        'a Barrier': (g, o) => o.shield = tiny,
        'a guard': (g, o) => o
          ..guardUntil = 1e9
          ..guardCut = 0,
      };
      for (final MapEntry(key: what, value: set) in shields.entries) {
        final soak = what == 'an absorb' || what == 'a Barrier' ? tiny : 0.0;
        expect(troopBlow(set: set), closeTo(base - soak, 1e-9), reason: '$what alone');
        expect(troopBlow(omens: levels(hardShell, 2), set: set), closeTo(base * 0.9 - soak, 1e-9), reason: '$what, L2');
        expect(troopBlow(omens: top(hardShell), factor: 2, set: set), closeTo(base * 0.7 - soak, 1e-9), reason: '$what, E8');
      }
      expect(troopBlow(omens: top(hardShell), factor: 2), closeTo(base, 1e-9), reason: 'no shield');
      expect(troopBlow(omens: top(hardShell), factor: 2, set: (g, o) => o.guardUntil = g.t), closeTo(base, 1e-9),
          reason: 'a guard that ended');
    });

    test('the taken floor: the four kinds multiply in with Armor and stop at 0.5 together', () {
      final base = troopBlow(), bear = troopBlow(type: 'werebear');
      final armored = [...top(armor)];
      expect(troopBlow(omens: [...armored, ...top(brace)], factor: 2), closeTo(base * 0.5, 1e-9), reason: '0.6 × 0.7: the floor');
      expect(troopBlow(omens: [...armored, ...top(stubborn)], factor: 2, share: 0.2), closeTo(troopBlow(share: 0.2) * 0.5, 1e-9));
      expect(troopBlow(omens: [...armored, ...top(bearHide)], factor: 2, type: 'werebear'), closeTo(bear * 0.5, 1e-9));
      void guard(Game g, Unit o) => o
        ..guardUntil = 1e9
        ..guardCut = 0;
      expect(troopBlow(omens: [...top(brace), ...top(hardShell)], factor: 2, set: guard), closeTo(base * 0.5, 1e-9),
          reason: 'Brace and Hard Shell alone: 0.49, the floor');
      expect(troopBlow(omens: [...levels(brace, 2), ...levels(hardShell, 2)], set: guard), closeTo(base * 0.9 * 0.9, 1e-9),
          reason: 'above it: the product');
    });

    test('Sunder (troop-side): a troop\'s cuts are weaker, the small relic Guard\'s, a skill\'s guard and a Pusaka\'s '
        '`cut` (Iron Banner); a monster\'s guard never', () {
      final taken = foeBlow();
      void relic(Game g, Unit k, Unit o) => k.relics.add(Relic.guard);
      void skillGuard(Game g, Unit k, Unit o) => k
        ..guardUntil = 1e9
        ..guardCut = 0.3;
      void banner(Game g, Unit k, Unit o) => g.givePusaka(Relic.ironBanner, type: 'knight');
      expect(foeBlow(set: relic), closeTo(taken * (1 - guardCut), 1e-9));
      for (final (n, factor, keep) in [(1, 1.0, 0.92), (4, 1.0, 0.68), (4, 2.0, 0.5)]) {
        final omens = levels(sunder, n);
        expect(foeBlow(omens: omens, factor: factor, set: relic), closeTo(taken * (1 - guardCut * keep), 1e-9), reason: 'L$n ×$factor');
        expect(foeBlow(omens: omens, factor: factor, set: skillGuard), closeTo(taken * (1 - 0.3 * keep), 1e-9));
      }
      final cut = 1 - foeBlow(set: banner) / taken;
      expect(cut, greaterThan(0), reason: "Iron Banner's cut");
      expect(foeBlow(omens: top(sunder), factor: 2, set: banner), closeTo(taken * (1 - cut * 0.5), 1e-9));
      expect(foeBlow(omens: top(sunder), factor: 2), taken, reason: 'nothing to weaken');
      void foeGuard(Game g, Unit o) => o
        ..guardUntil = 1e9
        ..guardCut = 0.3;
      expect(troopBlow(omens: top(sunder), factor: 2, set: foeGuard), closeTo(troopBlow() * 0.7, 1e-9), reason: "a monster's guard");
    });

    test('Unshaken: a slow, pin, taunt, weaken, hex or stun on a monster lasts × (1 − share), at least 0.3 s (or its own '
        'time when shorter); a monster\'s buff and what a monster puts on a troop, never', () {
      final (g, k, o) = duel(omens: top(unshaken), factor: 2);
      for (final s in [Status.slow, Status.impaled, Status.taunt, Status.weaken, Status.hex]) {
        final u = foeAt(g, 'orc', o.pos + const Point(0, 20));
        g.addEffect(u, s, 4, k: 0.5, by: k);
        expect(g.effectOn(u, s)!.until, closeTo(g.t + 2, 1e-9), reason: s.name);
      }
      final f = foeAt(g, 'orc', o.pos + const Point(0, -20));
      g.addEffect(f, Status.slow, 0.5, k: 0.5, by: k);
      expect(g.effectOn(f, Status.slow)!.until, closeTo(g.t + effectTimeFloor, 1e-9), reason: 'the floor');
      g.addEffect(f, Status.weaken, 0.2, k: 0.5, by: k);
      expect(g.effectOn(f, Status.weaken)!.until, closeTo(g.t + 0.2, 1e-9), reason: 'shorter than the floor: its own');
      g.addEffect(o, Status.might, 4, k: 1.2);
      expect(g.effectOn(o, Status.might)!.until, closeTo(g.t + 4, 1e-9), reason: "a monster's buff");
      g.addEffect(k, Status.slow, 4, k: 0.5, by: o, bad: true);
      expect(g.effectOn(k, Status.slow)!.until, closeTo(g.t + 4, 1e-9), reason: 'on a troop');
      final (l1, lk, lo) = duel(omens: levels(unshaken, 1));
      l1.addEffect(lo, Status.slow, 4, k: 0.5, by: lk);
      expect(l1.effectOn(lo, Status.slow)!.until, closeTo(l1.t + 3.6, 1e-9), reason: 'L1: 10% sooner');

      // A stun (Shield Bash) and Slime Hex: set straight, not through addEffect.
      for (final tier in [Tier.highElite, Tier.miniBoss]) {
        final (s, h) = heroCaster(HeroSkill.shieldBash);
        s
          ..omens.addAll(top(unshaken))
          ..omenFactor = 2;
        final u = foeAt(s, 'orc', h.pos + Point(h.stats.range, 0), tier);
        s.tick(0.05);
        expect(h.heroSkillAt, s.t, reason: tier.name);
        expect(u.stunUntil, closeTo(s.t + shieldBashK.stun * (tier == Tier.miniBoss ? 0.5 : 1) * 0.5, 1e-9), reason: tier.name);
      }
      final (x, h) = heroCaster(HeroSkill.slimeHex);
      x
        ..omens.addAll(top(unshaken))
        ..omenFactor = 2;
      final strong = foeAt(x, 'elite_orc', h.pos + const Point(60, 0), Tier.highElite);
      x.tick(0.05);
      expect(x.effectOn(strong, Status.hex)!.until, closeTo(x.t + slimeHexK.time * 0.5, 1e-9));
    });

    test('Quick Spells: a high elite\'s skill comes back × (1 − share), at most 30% sooner, its first cast when it would '
        'have come; a mini boss\'s never', () {
      // The first cast: 2 to 5 s after it comes on either way.
      final g = bareGame()..skills = false;
      g
        ..startWave()
        ..queue.clear()
        ..queue.addAll([for (var i = 0; i < 5; i++) ('orc', Tier.highElite)])
        ..omens.addAll(top(quickSpells))
        ..omenFactor = 2;
      final cameAt = <Unit, double>{};
      for (var i = 0; i < 200 && cameAt.length < 5; i++) {
        g.tick(0.05);
        for (final u in g.enemies) {
          cameAt.putIfAbsent(u, () => g.t);
        }
      }
      expect([for (final MapEntry(key: u, value: t0) in cameAt.entries) u.skillAt + MonsterSkill.warShout.cooldown * 0.7 - t0],
          [for (final s in [2, 3, 4, 5, 2]) closeTo(s.toDouble(), 1e-9)]);

      // Its cooldown: War Shout's 14 s at 70%.
      bool readyAfter(double since, {List<OmenKind> omens = const [], Tier tier = Tier.highElite}) {
        final g = bareGame()
          ..skills = false
          ..heroSkills = false;
        g
          ..startWave()
          ..queue.clear()
          ..omens.addAll(omens)
          ..omenFactor = 2;
        final orc = g.monster('orc', tier, const Point(250, 60))
          ..entered = true
          ..cd = hold;
        g.units.add(orc);
        for (final dy in [-10.0, 0.0, 10.0]) {
          foeAt(g, 'orc', orc.pos + Point(4.0, dy)).attackedAt = g.t;
        }
        orc
          ..skillAt = g.t - since
          ..bossSkillAt = g.t; // a mini boss's other skill just cast: only its signature could start
        g.tick(0.05);
        return orc.winding == MonsterSkill.warShout;
      }

      const cd = 14.0;
      expect(MonsterSkill.warShout.cooldown, cd);
      expect(readyAfter(cd * 0.7, omens: top(quickSpells)), isTrue);
      expect(readyAfter(cd * 0.7 - 0.2, omens: top(quickSpells)), isFalse);
      expect(readyAfter(cd * 0.7), isFalse, reason: 'without it');
      expect(readyAfter(cd * 0.8, omens: levels(quickSpells, 2)), isTrue, reason: 'L2 ×2, E4: 20% sooner');
      expect(readyAfter(cd * 0.8 - 0.2, omens: levels(quickSpells, 2)), isFalse);
      expect(readyAfter(cd * 0.7, omens: top(quickSpells), tier: Tier.miniBoss), isFalse, reason: 'a mini boss: never');
      expect(readyAfter(cd, omens: top(quickSpells), tier: Tier.miniBoss), isTrue);
    });

    test('Thrift: a kill pays its gold × (1 − share), rounded, at most 30% less, a plunderer\'s extra of it too; the '
        'loot dice draw as before', () {
      (int, double) kill({List<OmenKind> omens = const [], double factor = 1, bool plunder = false}) {
        final (g, k, o) = duel(omens: omens, factor: factor, type: 'werebear');
        if (plunder) g.addEffect(k, Status.plunder, 100, k: plunderK.bonus, by: k);
        o.hp = 1;
        final gold = g.gold;
        blowOn(g, o, k);
        expect(o.alive, isFalse);
        return (g.gold - gold, g.loot.nextDouble());
      }

      final (full, dice) = kill();
      expect(full, greaterThan(10));
      for (final (omens, factor, k) in [(levels(thrift, 1), 1.0, 0.04), (top(thrift), 1.0, 0.16), (top(thrift), 2.0, 0.3)]) {
        expect(kill(omens: omens, factor: factor), ((full * (1 - k)).round(), dice), reason: '$k off');
      }
      final kept = (full * 0.7).round();
      expect(kill(omens: top(thrift), factor: 2, plunder: true).$1, kept + (kept * plunderK.bonus).ceil());
      expect(kill(plunder: true).$1, full + (full * plunderK.bonus).ceil());
    });

    test('Deflect: each monster cancels every nth normal troop attack on it (L4: every 5th), with its own hit burst and no '
        '`landed` Fx (God\'s Thunder\'s leap); extra hits never count; a shot the same', () {
      final (g, k, o) = duel(omens: levels(deflect, 4));
      final near = foeAt(g, 'orc', o.pos + const Point(30, 0)); // in the leap's reach, out of the blow's
      g.givePusaka(Relic.godThunder, type: 'knight');
      o.hp = near.hp = 1e9;
      for (var i = 1; i <= 10; i++) {
        final before = near.hp;
        g.impacts.clear();
        final lost = blowOn(g, o, k);
        if (i % 5 == 0) {
          expect(lost, 0, reason: 'blow $i: cancelled');
          expect(near.hp, before, reason: 'blow $i: no leap');
          expect(g.impacts, contains((o.pos, 'hit_orc')), reason: 'its own burst');
        } else {
          expect(lost, greaterThan(0), reason: 'blow $i');
          expect(near.hp, lessThan(before), reason: 'blow $i: it leaps');
        }
      }
      expect((o.fxN, near.fxN), (10, 0), reason: 'a leap is an extra hit');

      // A shot landing: an archer's 5th normal shot on a monster.
      final (s, _, so) = duel(omens: levels(deflect, 4));
      final a = placeNow(s, 'archer', 0, 3)..busyUntil = hold;
      final sNear = foeAt(s, 'orc', so.pos + const Point(30, 0));
      s.givePusaka(Relic.godThunder, type: 'archer');
      so
        ..hp = 1e9
        ..fxN = 4;
      sNear.hp = 1e9;
      s.shots.add(Shot(a, so, so.pos, Hit.normal, 10));
      s.tick(0.05);
      expect((so.hp, sNear.hp, so.fxN), (1e9, 1e9, 5), reason: 'cancelled: no leap');
      s.shots.add(Shot(a, so, so.pos, Hit.normal, 10));
      s.tick(0.05);
      expect(so.hp, lessThan(1e9));
      expect(sNear.hp, lessThan(1e9), reason: 'the 6th lands and leaps');
    });

    test('Defiant: a monster under a troop\'s taunt deals that troop × (1 + share), at most 25%, the boss and mini boss '
        'half; inside the dealt cap; untaunted, or under a monster\'s taunt on the troop, never', () {
      double mighty(double k, {Tier tier = Tier.normal, bool omen = false}) =>
          foeBlow(tier: tier, set: (g, kn, o) => g.addEffect(o, Status.might, 100, k: k, omen: omen));
      void taunted(Game g, Unit k, Unit o) => g.addEffect(o, Status.taunt, 100, by: k);
      for (final tier in [Tier.normal, Tier.miniBoss, Tier.boss]) {
        final half = tier == Tier.normal ? 1.0 : omenDefiantBoss;
        expect(foeBlow(omens: top(defiant), factor: 2, tier: tier, set: taunted), closeTo(mighty(1 + 0.25 * half, tier: tier), 1e-9),
            reason: tier.name);
        expect(foeBlow(omens: levels(defiant, 1), tier: tier, set: taunted), closeTo(mighty(1 + 0.06 * half, tier: tier), 1e-9),
            reason: '${tier.name} L1');
      }
      final base = foeBlow();
      expect(foeBlow(omens: top(defiant), factor: 2), base, reason: 'not taunted');
      expect(foeBlow(omens: top(defiant), factor: 2, set: (g, k, o) => g.addEffect(k, Status.taunt, 100, by: o, bad: true)), base,
          reason: "a monster's taunt on the troop (Bulwark's)");
      // The dealt cap: an omen might of 1.5 with Defiant's 1.25 is 1.875, capped at 1.6.
      expect(
          foeBlow(omens: top(defiant), factor: 2, set: (g, k, o) {
            taunted(g, k, o);
            g.addEffect(o, Status.might, 100, k: 1.5, omen: true);
          }),
          closeTo(mighty(omenDealtMost), 1e-9));
      expect(
          foeBlow(omens: top(defiant), factor: 2, set: (g, k, o) {
            taunted(g, k, o);
            g.addEffect(o, Status.might, 100, k: 1.2, omen: true);
          }),
          closeTo(mighty(1.2 * 1.25), 1e-9),
          reason: 'under the cap: the product');
    });
  });

  group('off', () {
    setUp(() => omensOn = false);

    test('with every kind of the batch at its most, nothing acts: blows both ways, the troops\' cuts, effect times, '
        'kill gold and every attack land as with none', () {
      final all = [for (final k in batch) ...top(k)];
      void shielded(Game g, Unit o) => o
        ..guardUntil = 1e9
        ..guardCut = 0;
      expect(troopBlow(omens: all, factor: 2, set: shielded), troopBlow(set: shielded));
      expect(troopBlow(omens: all, factor: 2, type: 'werebear', share: 0.2), troopBlow(type: 'werebear', share: 0.2));
      void guarded(Game g, Unit k, Unit o) {
        k.relics.add(Relic.guard);
        g.addEffect(o, Status.taunt, 100, by: k);
      }

      expect(foeBlow(omens: all, factor: 2, set: guarded), foeBlow(set: guarded));
      final (g, k, o) = duel(omens: all, factor: 2);
      g.addEffect(o, Status.slow, 4, k: 0.5, by: k);
      expect(g.effectOn(o, Status.slow)!.until, g.t + 4);
      o.hp = 1e9;
      for (var i = 0; i < 12; i++) {
        expect(blowOn(g, o, k), greaterThan(0));
      }
      expect(o.fxN, 0);
      int gold(List<OmenKind> omens) {
        final (g, k, bear) = duel(omens: omens, factor: 2, type: 'werebear');
        bear.hp = 1;
        final before = g.gold;
        blowOn(g, bear, k);
        return g.gold - before;
      }

      expect(gold(all), gold(const []));
    });
  });
}
