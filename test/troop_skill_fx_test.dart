import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hero_skill_helpers.dart';

// The troops' skills' own looks (#81, docs/ui-hud.md "Skills"): each cast leaves its look in the game (a ring, a
// beam or a zone that only shows) and it goes when its time is up. How they are drawn is lib/skills.dart; the last
// test draws every one on a booted board.

/// A monster of [type] at [at] that never moves or fights on its own and outlives every blow a skill deals.
Unit sturdyFoe(Game g, String type, Point<double> at) => foeAt(g, type, at)..hp = 1e5;

/// A wave on with nothing to spawn, and a troop of [type] at cell (2, 3) that never strikes on its own, full of
/// MP, with the scene its skill casts in by its rule ([Game.wantsSkill]) on the next tick: foes (and hurt or
/// fighting allies) round it. Only the #10 skills are on. Returns the game and the caster.
(Game, Unit) skillScene(String type) {
  final g = bareGame(Random(1))
    ..heroSkills = false
    ..monsterSkills = false;
  final u = placeNow(g, type, 2, 3);
  final allies = switch (type) {
    'priest' => [placeNow(g, 'soldier', 4, 3), placeNow(g, 'knight', 4, 4), placeNow(g, 'archer', 3, 2)],
    'knight_templar' => [placeNow(g, 'soldier', 3, 3), placeNow(g, 'knight', 3, 2), placeNow(g, 'swordsman', 3, 4)],
    _ => <Unit>[],
  };
  g
    ..startWave()
    ..queue.clear();
  u
    ..cd = hold
    ..mp = u.stats.mp.toDouble();
  for (final a in allies) {
    a.cd = hold;
  }
  Point<double> at(double dx, double dy) => u.pos + Point(dx, dy);
  final foes = switch (type) {
    'soldier' => [at(11, -4), at(11, 6)], // two within guardNear
    'knight' => [at(12, -6), at(12, 7), at(-12, 3)], // within slash.reach
    'swordsman' => [at(11, 0)], // in reach
    'archer' => [at(44, -8), at(52, 10), at(60, 0)], // in range
    'lancer' => [at(14, 0), at(30, 3), at(42, -4)], // its target and two behind it in its lane
    'armored_axeman' => [at(12, -6), at(12, 8), at(-10, 4)], // within slam.reach
    'wizard' => [at(48, 0), at(56, 8), at(56, -8), at(64, 0)], // a target in reach with three round it
    _ => [at(60, 0)], // the priest and the templar need only a wave on
  };
  for (final p in foes) {
    sturdyFoe(g, 'orc', p);
  }
  if (type == 'priest') {
    // The most hurt below prayer.low, the others below prayer.hurt.
    for (final (a, share) in [(allies[0], 0.3), (allies[1], 0.6), (allies[2], 0.5)]) {
      a.hp = a.maxHp * share;
    }
  }
  if (type == 'knight_templar') {
    for (final a in [u, ...allies]) {
      a.attackedAt = g.t; // fighting
    }
  }
  return (g, u);
}

/// Ticks [g] once: the caster casts.
void cast(Game g, Unit u) {
  final before = u.skillAt;
  g.tick(0.05);
  expect(u.skillAt, isNot(before), reason: '${u.type} cast its skill');
}

/// The rings of [look] in [g].
List<Ring> ringsOf(Game g, RingLook look) => [for (final r in g.rings) if (r.look == look) r];

void main() {
  test('Hold Fast braces the soldier: a steel-blue ring on it for its time, then its guard ring in steel blue', () {
    final (g, u) = skillScene('soldier');
    cast(g, u);
    final brace = ringsOf(g, RingLook.brace).single;
    expect(brace.follow, same(u));
    expect(brace.until - brace.since, closeTo(skillLook.brace, 1e-9));
    expect(u.guardLook, RingLook.brace);
    expect(g.impacts.where((i) => i.$2 == 'upgrade'), isEmpty, reason: 'no upgrade burst: that is the Hero skills\' look');
    runFor(g, skillLook.brace + 0.05);
    expect(ringsOf(g, RingLook.brace), isEmpty);
    expect(g.t < u.guardUntil, isTrue);
    expect(u.guardLook, RingLook.brace, reason: 'its guard ring stays steel blue while the guard lasts');
  });

  test('Circle Slash sweeps a blade ring round the knight over its reach, gone after its time', () {
    final (g, u) = skillScene('knight');
    cast(g, u);
    final slashRing = ringsOf(g, RingLook.slash).single;
    expect(slashRing.follow, same(u));
    expect(slashRing.radius, slash.reach);
    runFor(g, skillLook.slash + 0.05);
    expect(ringsOf(g, RingLook.slash), isEmpty);
  });

  test('Rampage bursts in embers off the swordsman; its aura lasts as long as Rampage does', () {
    final (g, u) = skillScene('swordsman');
    cast(g, u);
    expect(ringsOf(g, RingLook.rage).single.follow, same(u));
    expect(u.frenzyUntil - g.t, closeTo(frenzy.time, 0.051));
    expect(g.impacts.where((i) => i.$2 == 'upgrade'), isEmpty);
    runFor(g, skillLook.rage + 0.05);
    expect(ringsOf(g, RingLook.rage), isEmpty);
    expect(g.t < u.frenzyUntil, isTrue, reason: 'the aura is drawn from frenzyUntil');
  });

  test('Arrow Rain rains on its targets: a zone that only shows over both, while its two arrows fly', () {
    final (g, u) = skillScene('archer');
    cast(g, u);
    final z = g.zones.single;
    expect(z.look, ZoneLook.volley);
    expect(z.from, same(u));
    expect(z.inside, isNull);
    expect(z.pulse, isNull);
    final targets = [for (final s in g.shots) s.target];
    expect(targets, hasLength(volleyArrows));
    for (final o in targets) {
      expect(o.pos.distanceTo(z.at), lessThanOrEqualTo(z.radius), reason: 'the rain covers every target');
    }
    runFor(g, skillLook.volley + 0.05);
    expect(g.zones, isEmpty);
  });

  test('Piercing Thrust streaks from the lancer through its target to the end of its reach, then goes', () {
    final (g, u) = skillScene('lancer');
    final start = u.pos, target = g.enemies.first.pos;
    cast(g, u);
    final b = g.beams.single;
    expect(b.look, BeamLook.thrust);
    expect(b.points.first.distanceTo(start), lessThan(1));
    expect(b.points.last.distanceTo(target + Point(pierce.depth, 0.0)), lessThan(1));
    runFor(g, skillLook.thrust + 0.05);
    expect(g.beams, isEmpty);
  });

  test('Healing Prayer rings its reach in mint and raises a column of light on each troop it heals', () {
    final (g, u) = skillScene('priest');
    final hurt = [for (final o in g.troops) if (o != u && o.hp < o.maxHp) o];
    final worst = hurt.reduce((a, b) => a.hp / a.maxHp < b.hp / b.maxHp ? a : b), at = worst.pos;
    final healed = [for (final o in hurt) if (o.pos.distanceTo(at) <= prayer.reach) o];
    cast(g, u);
    final reach = ringsOf(g, RingLook.prayer).single;
    expect(reach.at.distanceTo(at), lessThan(1));
    expect(reach.radius, prayer.reach);
    expect(healed, isNotEmpty);
    expect(ringsOf(g, RingLook.pillar).map((r) => r.follow), unorderedEquals(healed));
    runFor(g, skillLook.pillar + 0.05);
    expect(ringsOf(g, RingLook.prayer), isEmpty);
    expect(ringsOf(g, RingLook.pillar), isEmpty);
  });

  test('a column on a troop that falls goes with it', () {
    final (g, u) = skillScene('priest');
    cast(g, u);
    final pillar = ringsOf(g, RingLook.pillar).first;
    pillar.follow!.gone = true;
    g.tick(0.05);
    expect(g.rings, isNot(contains(pillar)));
  });

  test('Crushing Blow cracks the ground round the axeman over its reach, gone after its time', () {
    final (g, u) = skillScene('armored_axeman');
    final at = u.pos;
    cast(g, u);
    final crack = ringsOf(g, RingLook.crack).single;
    expect(crack.at.distanceTo(at), lessThan(1));
    expect(crack.follow, isNull, reason: 'the ground stays cracked where it was struck');
    expect(crack.radius, slam.reach);
    runFor(g, skillLook.crack + 0.05);
    expect(ringsOf(g, RingLook.crack), isEmpty);
  });

  test('Arcane Blast flies as its ice star (wizard_fx_test.dart) and bursts in a violet ring over its splash where it lands', () {
    final (g, u) = skillScene('wizard');
    cast(g, u);
    final orb = g.shots.single;
    expect(orb.ring, RingLook.arcane);
    expect(ringsOf(g, RingLook.arcane), isEmpty, reason: 'nothing bursts before it lands');
    for (var i = 0; i < 100 && g.shots.isNotEmpty; i++) {
      g.tick(0.05);
    }
    final blastRing = ringsOf(g, RingLook.arcane).single;
    expect(blastRing.at, orb.target.pos);
    expect(blastRing.radius, blast.splash);
    runFor(g, ringTime + 0.05);
    expect(ringsOf(g, RingLook.arcane), isEmpty);
  });

  test('Holy Shield rings its reach in white and raises a dome over each troop it shields, not one it leaves', () {
    final (g, u) = skillScene('knight_templar');
    final braced = g.troops.firstWhere((o) => o.type == 'soldier');
    braced
      ..guardUntil = g.t + 10
      ..guardCut = guardSelf.cut
      ..guardLook = RingLook.brace; // Hold Fast's stronger guard stays
    cast(g, u);
    expect(ringsOf(g, RingLook.holy).single.radius, ward.reach);
    final shielded = [for (final o in g.troops) if (o != braced) o];
    expect(ringsOf(g, RingLook.dome).map((r) => r.follow), unorderedEquals(shielded));
    for (final o in shielded) {
      expect(o.guardLook, RingLook.holy);
    }
    expect(braced.guardLook, RingLook.brace);
    expect(g.impacts.where((i) => i.$2 == 'upgrade'), isEmpty);
    runFor(g, skillLook.dome + 0.05);
    expect(ringsOf(g, RingLook.dome), isEmpty);
    expect(ringsOf(g, RingLook.holy), isEmpty);
  });

  testWidgets('every troop skill\'s look draws on the field, from its cast until it is gone', (tester) async {
    tester.view
      ..physicalSize = const Size(1266, 713)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = TdGame();
    await tester.pumpWidget(GameWidget(game: game));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue);
    final b = game.board..welcome = null;
    for (final type in troopSkills.keys) {
      final (g, u) = skillScene(type);
      for (final o in g.enemies) {
        // Drawn standing: a board draws a unit held by busyUntil (foeAt's) as rising, from a busyFrom it never had.
        o
          ..busyUntil = double.negativeInfinity
          ..cd = hold;
      }
      b.state = g;
      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(milliseconds: 16)); // 1.1 s: every look from its first frame to its last
      }
      expect(u.skillAt, greaterThan(double.negativeInfinity), reason: '$type cast');
      expect(tester.takeException(), isNull, reason: type);
    }
  });

  testWidgets('every monster skill\'s wind-up tell draws at all three ranks (high elite, mini boss, boss): its circle, '
      'its marks, a lane\'s arrows, a moment\'s red edges, the boss bar\'s flash', (tester) async {
    tester.view
      ..physicalSize = const Size(1266, 713)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = TdGame();
    await tester.pumpWidget(GameWidget(game: game));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue);
    final b = game.board..welcome = null;
    for (final skill in MonsterSkill.values) {
      for (final tier in [Tier.highElite, Tier.miniBoss, Tier.boss]) {
        final g = bareGame(Random(1))
          ..skills = false
          ..heroSkills = false;
        g
          ..startWave()
          ..queue.clear();
        final u = g.monster(skill.type, tier, const Point(250.0, 60.0))
          ..entered = true
          ..cd = hold
          ..summonCd = hold;
        g
          ..units.add(u)
          ..addEffect(u, Status.slow, hold, k: 0);
        // Troops round it (hurt, so Pounce has one), and a hurt monster struck lately (Unholy Ward's).
        for (final (dx, dy, type) in [(10.0, 0.0, 'soldier'), (30.0, 12.0, 'archer'), (50.0, -10.0, 'priest'), (70.0, 4.0, 'knight')]) {
          final o = Unit(Side.troop, type, troopTypes[type]!, u.pos + Point(-dx, dy))
            ..entered = true
            ..cd = hold; // drawn standing (one held by busyUntil would be drawn rising)
          g.units.add(o..hp = o.maxHp * 0.4);
        }
        final ally = foeAt(g, 'orc', u.pos + const Point(10.0, 8.0))
          ..busyUntil = double.negativeInfinity
          ..cd = hold
          ..hurtBefore = g.t;
        ally.hp = ally.maxHp * 0.3;
        u
          ..winding = skill
          ..windUntil = g.t + max(skill.wind, 0.4);
        g.monsterCasts.add((u, skill));
        b.state = g;
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(tester.takeException(), isNull, reason: '${skill.title} ${tier.name}');
      }
    }
  });
}
