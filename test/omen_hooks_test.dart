// The Bayangan's enemy hooks (catalog step 0d, decisions-log 188, lib/omen.dart; docs/units-and-combat.md "Bayangan on
// the field"): off, nothing acts (a monster's stats are exactly enemyStats's, no guard, no skip buff, no shield, a blow
// as it was); on, one test a kind: Armor cuts a troop's blow on a monster and never a monster's on a troop, Haste
// shortens the attack pause with the floors kept, Mend gives regen but never to a slot, Thorns sends a melee troop's
// blow back up to its cap and with no attacker, Wound cuts the funnel's heals, Shield sits on the slots alone and
// breaks before their HP, Guard brings its monsters behind each slot's escort on the slot's row with rng and slots
// still paired; and Lewati's skip buff lands on exactly the first 30% by spawn order, for one wave.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

const armor = OmenKind.armor, haste = OmenKind.haste, mend = OmenKind.mend, wound = OmenKind.wound;
const thorns = OmenKind.thorns, shield = OmenKind.shield, guard = OmenKind.guard;

/// [n] levels of [kind].
List<OmenKind> levels(OmenKind kind, int n) => List.filled(n, kind);

/// A [bareGame] with no skills of any kind (nor the monsters'), its slots' dice seeded, the enemy holding [omens].
Game plain({List<OmenKind> omens = const [], Random? rng}) => bareGame(rng ?? Random(2))
  ..slots = Random(3)
  ..skills = false
  ..heroSkills = false
  ..awakenSkills = false
  ..monsterSkills = false
  ..omens.addAll(omens);

/// What a monster's blow (or a troop's) took off the other: [by] strikes [u] once now.
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

/// A knight and an orc of [tier] beside it, both standing.
(Game, Unit, Unit) duel({List<OmenKind> omens = const [], Tier tier = Tier.normal, String type = 'knight'}) {
  final g = plain(omens: omens);
  final k = placeNow(g, type, 2, 3)..busyUntil = hold;
  final orc = foeAt(g, 'orc', k.pos + const Point(12, 0), tier);
  return (g, k, orc);
}

/// A spawn of the wave: what came on, in order, where, and when.
typedef Spawn = ({Unit u, double y, double t});

/// Starts wave [wave] of a [plain] game holding [omens] (the skip buff owed when [skipBuff]) and lets its whole queue
/// come on, each monster held where it came. The spawns in order, and the game.
(Game, List<Spawn>) spawnAll(int wave, {List<OmenKind> omens = const [], bool skipBuff = false}) {
  final g = plain(omens: omens, rng: Random(5))
    ..wave = wave - 1
    ..lives = 100000
    ..skipBuffDue = skipBuff;
  final spawns = <Spawn>[];
  g.listeners.add((e) {
    if (e is MonsterSpawned && !e.raised) {
      final u = g.units.last;
      spawns.add((u: u, y: u.pos.y, t: g.t));
    }
  });
  g.startWave();
  while (g.queue.isNotEmpty) {
    g.tick(0.05);
    for (final u in g.enemies) {
      u.busyUntil = hold;
    }
  }
  return (g, spawns);
}

bool slot(Tier tier) => tier == Tier.boss || tier == Tier.miniBoss;

/// Every number of [s], to compare two stats whole.
List<num?> fields(Stats s) => [s.hp, s.dmg, s.speed, s.rate, s.range, s.def, s.regen, s.mp, s.mpRegen, s.cost];

void main() {
  tearDown(() => omensOn = false);

  group('off: nothing acts', () {
    setUp(() => omensOn = false);

    test("every kind at its cap and Lewati owed, yet a wave comes on exactly as enemyStats makes it: no guard, no "
        'skip buff, no shield, and its dice drawn as without them', () {
      final all = [for (final k in OmenKind.values) ...levels(k, omenCap)];
      for (final wave in [30, 60]) {
        final (g, spawns) = spawnAll(wave, omens: all, skipBuff: true);
        final (b, base) = spawnAll(wave);
        expect([for (final s in spawns) (s.u.type, s.u.tier, s.y, s.t)], [for (final s in base) (s.u.type, s.u.tier, s.y, s.t)]);
        for (final s in spawns) {
          expect(fields(s.u.stats), fields(enemyStats(s.u.type, s.u.tier, wave, tideStart: g.waveTideFrom)));
          expect((s.u.shield, s.u.skipBuffed, s.u.guardOf), (0, false, null));
        }
        expect([g.rng.nextDouble(), g.slots.nextDouble()], [b.rng.nextDouble(), b.slots.nextDouble()]);
        expect([g.waveSkipBuff, g.skipBuffN], [false, 0]);
      }
    });

    test('a blow both ways is what it was, and spawnStats is enemyStats at every route', () {
      final all = [for (final k in OmenKind.values) ...levels(k, omenCap)];
      final (g, k, orc) = duel(omens: all);
      final (b, bk, borc) = duel();
      expect(blowOn(g, orc, k), blowOn(b, borc, bk));
      expect(blowOn(g, k, orc), blowOn(b, bk, borc));
      for (final tier in Tier.values) {
        for (final raised in [false, true]) {
          final want = enemyStats('orc', tier, g.wave, raised: raised, tideStart: g.waveTideFrom);
          expect(fields(g.spawnStats('orc', tier, raised: raised, skipBuff: true)), fields(want), reason: '${tier.name} $raised');
        }
      }
      expect(fields(g.spawnStats(boss, Tier.boss, at: 40, tideStart: tideFrom)), fields(enemyStats(boss, Tier.boss, 40)));
    });
  });

  group('on', () {
    setUp(() => omensOn = true);

    test('Armor: a troop\'s blow on a monster is cut by 0.05 E (at most 0.4), a slot\'s too; a monster\'s blow on a troop '
        'never (the enemy side only)', () {
      final (b, bk, borc) = duel();
      final base = blowOn(b, borc, bk), taken = blowOn(b, bk, borc);
      expect(base, greaterThan(0));
      for (final (n, factor, cut) in [(1, 1.0, 0.05), (4, 1.0, 0.2), (4, 2.0, 0.4), (4, 3.0, 0.4)]) {
        final (g, k, orc) = duel(omens: levels(armor, n));
        g.omenFactor = factor;
        expect(g.omenK(armor), closeTo(cut, 1e-12));
        expect(blowOn(g, orc, k), closeTo(base * (1 - cut), 1e-9), reason: 'L$n ×$factor');
        expect(blowOn(g, k, orc), taken, reason: 'the enemy side only');
      }
      for (final tier in [Tier.miniBoss, Tier.boss]) {
        final (s, sk, sorc) = duel(tier: tier);
        final (g, k, orc) = duel(omens: levels(armor, 2), tier: tier);
        expect(blowOn(g, orc, k), closeTo(blowOn(s, sorc, sk) * (1 - 0.1 * omenSlotShare), 1e-9), reason: tier.name);
      }
    });

    test('Haste: a monster\'s attack pause ÷(1 + 0.05 E), a slot\'s at its share, and the floors stay', () {
      final g = plain(omens: levels(haste, 4));
      for (final tier in Tier.values) {
        final base = enemyStats('orc', tier, g.wave, tideStart: g.waveTideFrom).rate;
        expect(g.spawnStats('orc', tier).rate, closeTo(base / (1 + 0.2 * (slot(tier) ? omenSlotShare : 1)), 1e-12), reason: tier.name);
      }
      g.omenFactor = 2;
      expect(g.spawnStats('orc', Tier.normal).rate, closeTo(enemyStats('orc', Tier.normal, g.wave).rate / 1.4, 1e-12));
      for (final (tier, floor) in [(Tier.normal, minAttackInterval), (Tier.boss, bossMinAttackInterval)]) {
        final u = foeAt(g, 'orc', const Point(250, 60), tier);
        g.addEffect(u, Status.haste, 100, k: 0.01);
        expect(g.attackEvery(u), floor, reason: tier.name);
      }
    });

    test('Mend: regen of 0.003 E of max HP a second, never a slot\'s (a raised mini boss is no slot); it heals', () {
      final g = plain(omens: levels(mend, 2));
      for (final tier in Tier.values) {
        for (final raised in [false, true]) {
          final s = g.spawnStats('orc', tier, raised: raised);
          expect(s.regen, closeTo(slot(tier) && !raised ? 0 : 0.006 * s.hp, 1e-9), reason: '${tier.name} raised: $raised');
        }
      }
      g.omenFactor = 9;
      expect(g.spawnStats('orc', Tier.normal).regen, closeTo(0.024 * g.spawnStats('orc', Tier.normal).hp, 1e-9), reason: 'its max');
      g.omenFactor = 1;
      final orc = foeAt(g, 'orc', const Point(250, 60))..hp = 10;
      orc.busyUntil = double.negativeInfinity;
      g.tick(0.05);
      expect(orc.hp, closeTo(10 + orc.stats.regen * 0.05, 1e-9));
    });

    test('Thorns: a melee troop takes 0.03 E of its blow back, at most 5% of its max HP, from no one; a ranged one never',
        () {
      final (g, k, orc) = duel(omens: levels(thorns, 2));
      k.relics.add(Relic.thorns); // a worn thorns would answer a blow that had an attacker
      final dealt = blowOn(g, orc, k);
      expect(k.hp, closeTo(k.maxHp - hitTaken(dealt * 0.06, k.stats.def), 1e-9));
      expect(orc.hp, orc.maxHp - dealt, reason: 'nothing bounced back');

      final (c, ck, corc) = duel(omens: levels(thorns, 4));
      c.omenFactor = 2;
      ck
        ..maxHp = 40
        ..hp = 40;
      final hit = blowOn(c, corc, ck);
      expect(hit * 0.24, greaterThan(40 * omenThornsCap), reason: 'the cap binds');
      expect(ck.hp, closeTo(40 - hitTaken(40 * omenThornsCap, ck.stats.def), 1e-9));

      final (r, archer, rorc) = duel(omens: levels(thorns, 4), type: 'archer');
      rorc.pos = archer.pos + const Point(40, 0);
      archer
        ..busyUntil = double.negativeInfinity
        ..cd = 0;
      for (var i = 0; i < 40 && rorc.hp == rorc.maxHp; i++) {
        r.tick(0.05);
      }
      expect(rorc.hp, lessThan(rorc.maxHp));
      expect(archer.hp, archer.maxHp, reason: 'a ranged troop takes none');
    });

    test('Wound: a heal in a wave ×(1 − 0.06 E), at most half; woundForce still in its place', () {
      for (final (n, factor, k, force) in [(2, 1.0, 0.88, null), (4, 3.0, 0.5, null), (4, 1.0, 0.3, 0.3)]) {
        final g = plain(omens: levels(wound, n))
          ..omenFactor = factor
          ..woundForce = force
          ..givePusaka(Relic.dragonHeart, type: 'knight');
        final kn = placeNow(g, 'knight', 2, 3)
          ..cd = hold
          ..hp = 10;
        foeAt(g, 'orc', const Point(250, 60)).hp = 100000;
        var asked = 0.0;
        g.onTroopHeal = (u, src, a, _) => asked += u == kn ? a : 0;
        g.tick(0.05);
        expect(asked, greaterThan(0));
        expect(kn.hp - 10, closeTo(asked * k, 1e-9), reason: 'L$n ×$factor force $force');
      }
    });

    test('Shield: the boss and the mini boss come on with 0.05 E of their max HP, broken before their HP; no other '
        'monster, nor a raised one', () {
      final g = plain(omens: levels(shield, 3));
      for (final tier in Tier.values) {
        final u = g.monster('orc', tier, const Point(250, 60));
        expect(u.shield, slot(tier) ? closeTo(0.15 * u.maxHp, 1e-9) : 0, reason: tier.name);
      }
      final necro = g.monster(boss, Tier.boss, const Point(250, 60))..summonCd = 0;
      g.units.add(necro..mp = necro.stats.mp.toDouble());
      g.tick(0.05);
      expect(g.minionsOf(necro), isNotEmpty);
      expect([for (final m in g.minionsOf(necro)) m.shield], everyElement(0));

      final (s, k, mini) = duel(omens: levels(shield, 4), tier: Tier.miniBoss);
      final (b, bk, bmini) = duel(tier: Tier.miniBoss);
      final wall = mini.shield, blow = blowOn(b, bmini, bk);
      expect(wall, closeTo(0.2 * mini.maxHp, 1e-9));
      expect(blowOn(s, mini, k), 0, reason: 'the shield took it');
      expect(mini.shield, closeTo(wall - blow, 1e-9));
      mini.shield = 1;
      expect(blowOn(s, mini, k), closeTo(blow - 1, 1e-9), reason: 'what is left goes to its HP');
      expect(mini.shield, 0);
    });

    test('Guard: each slot brings 1, 1, 2, 2 high elites of the pool\'s strongest type right behind its escort, on its '
        'row, linked to it; rng and slots stay paired and the #90 escort link holds', () {
      expect([for (final n in [0, 1, 2, 3, 4]) plain(omens: levels(guard, n)).omenGuards], [0, 1, 1, 2, 2]);
      for (final (wave, n) in [(30, 1), (60, 3), (60, 4)]) {
        final (g, spawns) = spawnAll(wave, omens: levels(guard, n));
        final (b, base) = spawnAll(wave);
        final per = g.omenGuards, escort = wave >= escortFrom ? escortHealers + escortSummoners : 0;
        final guards = spawns.where((s) => s.u.guardOf != null).toList(), plainOnes = spawns.where((s) => s.u.guardOf == null).toList();
        expect(guards, hasLength(per * base.where((s) => slot(s.u.tier)).length));
        expect([for (final s in plainOnes) (s.u.type, s.u.tier, s.y)], [for (final s in base) (s.u.type, s.u.tier, s.y)],
            reason: 'w$wave: the rest of the wave and its rows as without them');
        for (final (i, s) in spawns.indexed) {
          if (!slot(s.u.tier)) continue;
          final behind = spawns.sublist(i + 1, i + 1 + escort + per);
          expect([for (final e in behind.take(escort)) e.u.escortOf], everyElement(s.u), reason: 'the escort first');
          for (final gd in behind.skip(escort)) {
            expect((gd.u.type, gd.u.tier, gd.u.guardOf, gd.y), (poolOf(wave).last, Tier.highElite, s.u, s.y));
            expect(gd.u.maxHp, enemyStats(poolOf(wave).last, Tier.highElite, wave, tideStart: g.waveTideFrom).hp, reason: 'tided');
          }
        }
        expect([g.rng.nextDouble(), g.slots.nextDouble()], [b.rng.nextDouble(), b.slots.nextDouble()], reason: 'w$wave');
        expect(g.waveSpawned, b.waveSpawned + guards.length);
      }
    });

    test("Lewati's skip buff: the first 30% by spawn order get +10% HP, damage, attack speed and walk speed, for that "
        'wave only; the gap and the dice untouched', () {
      final (g, spawns) = spawnAll(30, skipBuff: true);
      final (_, base) = spawnAll(30);
      final n = (spawns.length * skipBuffShare).round();
      expect([g.waveSkipBuff, g.skipBuffN, g.skipBuffDue], [true, n, false]);
      expect([for (final s in spawns) (s.u.type, s.u.tier, s.y, s.t)], [for (final s in base) (s.u.type, s.u.tier, s.y, s.t)]);
      for (final (i, s) in spawns.indexed) {
        final want = g.spawnStats(s.u.type, s.u.tier), up = i < n ? 1 + skipBuffK : 1.0;
        expect(s.u.skipBuffed, i < n, reason: '#$i');
        expect(s.u.maxHp, (want.hp * up).round(), reason: '#$i');
        expect(s.u.stats.dmg, closeTo(want.dmg * up, 1e-9));
        expect(s.u.stats.speed, closeTo(want.speed * up, 1e-9));
        expect(s.u.stats.rate, closeTo(want.rate / up, 1e-12));
      }
      g.units.removeWhere((u) => u.side == Side.enemy);
      g.startWave();
      expect([g.waveSkipBuff, g.skipBuffN], [false, 0], reason: 'one wave only');
      g.tick(0.05);
      expect(g.enemies.single.skipBuffed, isFalse);
    });
  });
}
