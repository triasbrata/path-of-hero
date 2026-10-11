// The champions' landing looks (docs/ui-hud.md "A monster's skill"; lib/monster_skills.dart [landingLook], drawn by
// lib/skills.dart): each of the five skills whose landing read weakest leaves its look in the game as it lands, for
// its time; the `big` flag on a skill's blow only swaps its burst (its damage: monster_skills_test.dart's Brutal Swing
// test); Blade Dance's blows and Ground Slam's whole landing
// are as they were; and drawing the looks changes nothing in the fight. Every skill's landing at all three ranks is
// also drawn by troop_skill_fx_test.dart's last test.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hero_skill_helpers.dart';

/// A wave on (nothing left to spawn), the troops' skills off, and a monster of [type] and [tier] at (250, 60) that
/// never strikes, summons nor walks, with [skill] the one it begins (wind_tell_test.dart's).
(Game, Unit) casting(MonsterSkill skill, String type, Tier tier) {
  final g = bareGame()
    ..skills = false
    ..heroSkills = false;
  g
    ..startWave()
    ..queue.clear();
  final u = g.monster(type, tier, const Point(250.0, 60.0))
    ..entered = true
    ..cd = hold
    ..summonCd = hold;
  g
    ..units.add(u)
    ..addEffect(u, Status.slow, hold, k: 0);
  if (skill.rank == MonsterRank.signature) u.bossSkillAt = g.t; // its mini-boss skill waits
  if (skill.rank == MonsterRank.miniBoss) u.skillAt = g.t; // its signature waits
  return (g, u);
}

/// A troop of [type] [dx] to the left of monster [u] and [dy] below it, standing and never fighting.
Unit troop(Game g, Unit u, String type, double dx, [double dy = 0]) {
  final o = Unit(Side.troop, type, troopTypes[type]!, u.pos + Point(-dx, dy))
    ..entered = true
    ..busyUntil = hold;
  g.units.add(o);
  return o;
}

/// Ticks until [u] winds up [skill] and then until it lands.
void land(Game g, Unit u, MonsterSkill skill) {
  for (var i = 0; i < 80 && u.winding != skill; i++) {
    g.tick(0.05);
  }
  expect(u.winding, skill, reason: '${u.type} began ${skill.title}');
  for (var i = 0; i < 40 && u.winding != null; i++) {
    g.tick(0.05);
  }
  expect(u.winding, isNull, reason: '${skill.title} landed');
}

/// The rings of [look] in [g].
List<Ring> ringsOf(Game g, RingLook look) => [for (final r in g.rings) if (r.look == look) r];

/// The hit bursts [g] has queued for the UI at [at] (nothing drains them without a board).
List<String> burstsAt(Game g, Point<double> at) => [for (final (p, fx) in g.impacts) if (p == at) fx];

/// The champions' landing looks; none of them is a plain monster ring.
const landingLooks = {RingLook.cleave, RingLook.spin, RingLook.ward};

void main() {
  for (final (tier, aimed) in [(Tier.highElite, 3), (Tier.miniBoss, 4)]) {
    test('Volley (${tier.name}) lands with the archer\'s hit burst at it and a red ring under each troop it aims at '
        '(its 3 arrows\' nearest; a mini boss\'s 5 go round all 4)', () {
      final (g, u) = casting(MonsterSkill.volley, 'skeleton_archer', tier);
      final near = [for (final dx in [20.0, 30.0, 40.0, 50.0]) troop(g, u, 'soldier', dx)];
      land(g, u, MonsterSkill.volley);
      expect(burstsAt(g, u.pos), ['hit_skeleton_archer']);
      final marks = ringsOf(g, RingLook.red);
      expect(marks.map((r) => r.follow), unorderedEquals(near.take(aimed)));
      expect({for (final s in g.shots) s.target}, near.take(aimed).toSet(), reason: 'the rings are under the arrows\' troops');
      for (final r in marks) {
        expect(r.radius, landingLook.mark);
        expect(r.until - r.since, closeTo(ringTime, 1e-9));
      }
      runFor(g, ringTime + 0.05);
      expect(ringsOf(g, RingLook.red), isEmpty);
    });
  }

  test('Shield Up lands a ward look on the skeleton for its ward\'s time; a mini boss\'s on each monster behind it that its '
      'ward covers too, not one in front', () {
    for (final tier in [Tier.highElite, Tier.miniBoss]) {
      final (g, u) = casting(MonsterSkill.shieldUp, 'armored_skeleton', tier);
      u.rangedHitAt = g.t;
      final behind = foeAt(g, 'orc', u.pos + const Point(8.0, 4.0)), ahead = foeAt(g, 'orc', u.pos + const Point(-8.0, 4.0));
      land(g, u, MonsterSkill.shieldUp);
      final covered = [u, if (tier == Tier.miniBoss) behind];
      final wards = ringsOf(g, RingLook.ward);
      expect(wards.map((r) => r.follow), unorderedEquals(covered), reason: tier.name);
      for (final r in wards) {
        expect(g.under(r.follow!, Status.shotWard), isTrue);
        expect(r.until - r.since, closeTo(shieldUpK.time, 1e-9));
      }
      expect(g.under(ahead, Status.shotWard), isFalse);
      runFor(g, shieldUpK.time + 0.05);
      expect(ringsOf(g, RingLook.ward), isEmpty, reason: 'gone with the ward');
    }
  });

  test('a second Shield Up on a warded monster replaces its ward look: one shield on it, never two', () {
    final (g, u) = casting(MonsterSkill.shieldUp, 'armored_skeleton', Tier.miniBoss);
    u.rangedHitAt = g.t;
    final behind = foeAt(g, 'orc', u.pos + const Point(8.0, 4.0));
    final other = g.monster('armored_skeleton', Tier.miniBoss, u.pos + const Point(4.0, -6.0))
      ..entered = true
      ..cd = hold
      ..summonCd = hold
      ..bossSkillAt = g.t
      ..skillAt = g.t; // it casts later, by hand
    g
      ..units.add(other)
      ..addEffect(other, Status.slow, hold, k: 0);
    land(g, u, MonsterSkill.shieldUp);
    other
      ..winding = MonsterSkill.shieldUp
      ..windUntil = g.t;
    g.tick(0.05);
    expect(other.winding, isNull);
    final onBehind = [for (final r in ringsOf(g, RingLook.ward)) if (r.follow == behind) r];
    expect(onBehind, hasLength(1));
    expect(onBehind.single.since, closeTo(g.t, 1e-9), reason: 'the newer ward\'s look, for its whole time');
  });

  test('Brutal Swing lands a cleave round the elite orc over its reach and the big hit on each troop in reach', () {
    final (g, u) = casting(MonsterSkill.brutalSwing, 'elite_orc', Tier.highElite);
    final r = u.stats.range;
    final hit = [troop(g, u, 'soldier', 0.4 * r), troop(g, u, 'knight', 0.6 * r, 0.5 * r)], far = troop(g, u, 'archer', 2 * r);
    final hp = [for (final o in hit) o.hp];
    land(g, u, MonsterSkill.brutalSwing);
    final cleave = ringsOf(g, RingLook.cleave).single;
    expect(cleave.follow, same(u));
    expect(cleave.radius, r);
    expect(cleave.until - cleave.since, closeTo(landingLook.cleave, 1e-9));
    for (final (i, o) in hit.indexed) {
      expect(burstsAt(g, o.pos), ['hit_elite_orc_big'], reason: 'the big hit, not the plain one too');
      expect(o.hp, lessThan(hp[i]));
    }
    expect(burstsAt(g, far.pos), isEmpty);
    runFor(g, landingLook.cleave + 0.05);
    expect(ringsOf(g, RingLook.cleave), isEmpty);
  });

  test('Bulwark lands the armored orc\'s big hit on it and an orange ring out to its reach', () {
    final (g, u) = casting(MonsterSkill.bulwark, 'armored_orc', Tier.highElite);
    final r = u.stats.range;
    troop(g, u, 'soldier', 0.4 * r);
    troop(g, u, 'knight', 0.6 * r, 0.5 * r);
    land(g, u, MonsterSkill.bulwark);
    expect(burstsAt(g, u.pos), ['hit_armored_orc_big']);
    final ring = ringsOf(g, RingLook.orange).single;
    expect(ring.at, u.pos);
    expect(ring.follow, isNull, reason: 'it bursts where it stood');
    expect(ring.radius, bulwarkK.reach);
    expect(ring.until - ring.since, closeTo(ringTime, 1e-9));
    expect(u.guardLook, RingLook.orange, reason: 'its guard ring stays the taunt\'s orange');
  });

  for (final (tier, cuts) in [(Tier.highElite, bladeDanceK.cuts), (Tier.miniBoss, bladeDanceK.strong)]) {
    test('Blade Dance (${tier.name}) spins once each of its $cuts cuts; its blows are as before: the plain hit on each '
        'troop each cut, never the big one', () {
      final (g, u) = casting(MonsterSkill.bladeDance, 'greatsword_skeleton', tier);
      final near = [troop(g, u, 'knight', 10), troop(g, u, 'knight', 16, 8)];
      land(g, u, MonsterSkill.bladeDance);
      final spins = <Ring>{...ringsOf(g, RingLook.spin)};
      for (var i = 0; i < 60; i++) {
        g.tick(0.05);
        spins.addAll(ringsOf(g, RingLook.spin));
      }
      expect(spins, hasLength(cuts));
      for (final r in spins) {
        expect(r.follow, same(u));
        expect(r.radius, bladeDanceK.reach);
        expect(r.until - r.since, closeTo(landingLook.spin, 1e-9));
      }
      for (final o in near) {
        final fx = [for (final (p, f) in g.impacts) if (p.distanceTo(o.pos) < 1e-9) f];
        expect(fx, List.filled(cuts, 'hit_greatsword_skeleton'), reason: 'one plain hit a cut');
      }
      expect(ringsOf(g, RingLook.spin), isEmpty);
    });
  }

  test('a stunned Blade Dance stops spinning: no spin after the cut it stopped at', () {
    final (g, u) = casting(MonsterSkill.bladeDance, 'greatsword_skeleton', Tier.highElite);
    troop(g, u, 'knight', 10);
    troop(g, u, 'knight', 16, 8);
    land(g, u, MonsterSkill.bladeDance);
    u.stunUntil = g.t + 5;
    final spins = <Ring>{...ringsOf(g, RingLook.spin)};
    for (var i = 0; i < 40; i++) {
      g.tick(0.05);
      spins.addAll(ringsOf(g, RingLook.spin));
    }
    expect(spins, hasLength(1));
  });

  test('Ground Slam lands as before: its big hit on the armored orc, the plain one on each troop, one dust ring; none of '
      'the new looks', () {
    final (g, u) = casting(MonsterSkill.groundSlam, 'armored_orc', Tier.miniBoss);
    final near = [troop(g, u, 'soldier', 8), troop(g, u, 'knight', 12, 8), troop(g, u, 'lancer', 16, -8)];
    land(g, u, MonsterSkill.groundSlam);
    near.sort((a, b) => a.pos.distanceTo(u.pos).compareTo(b.pos.distanceTo(u.pos)));
    expect(g.impacts, [(u.pos, 'hit_armored_orc_big'), for (final o in near) (o.pos, 'hit_armored_orc')]);
    final ring = g.rings.single;
    expect(ring.look, RingLook.dust);
    expect(ring.radius, groundSlamK.reach);
    expect(ring.at, u.pos);
  });

  test('every new look has a colour (a ring with none would fail on the ground) and none is a plain ring', () {
    for (final look in landingLooks) {
      expect(RingLook.values, contains(look));
    }
    expect(landingLook.cleave, greaterThan(0));
    expect(landingLook.spin, lessThan(bladeDanceK.gap), reason: 'one spin ends before the next cut');
  });

  testWidgets('drawing the landings changes nothing: the w86 save\'s next wave from the same seeds ends the same played '
      'headless and drawn every tick, and its champions\' landings were drawn', (tester) async {
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

    final save = jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>;
    String digest(Game g) => [
          't ${g.t} gold ${g.gold} lives ${g.lives} kills ${g.kills} score ${g.score} log ${g.log.entries.length} cam ${g.cam}',
          for (final u in g.units) '${u.side.name} ${u.type} ${u.tier.name} ${u.alive} ${u.hp} ${u.mp} ${u.pos} ${u.winding}',
        ].join('\n');
    Game fresh() => Game.fromJson(save, Random(5), Random(105), Random(305))
      ..loot = Random(205)
      ..slots = Random(405)
      ..draft = Random(505);

    // The board sets the view's width (which play reads: the camera, how far a shove goes) on the game it holds, and
    // a wave begun drops the save's Pusaka note: the headless game gets both the same way.
    final drawn = fresh()..paused = true;
    b.state = drawn;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    final plain = fresh()..viewW = drawn.viewW;
    for (final g in [plain, drawn]) {
      g.startWave();
      if (g.pusakaSuggested) g.dismissPusakaNote();
    }

    // Headless: the game alone.
    for (var i = 0; i < 30 * 70 && plain.waveActive && !plain.over; i++) {
      plain.tick(1 / 30);
    }

    // Drawn: the same ticks, the board drawing the field after each (paused between them, so its own clock never
    // moves the game).
    final looks = <Ring>{};
    var bursts = 0;
    for (var i = 0; i < 30 * 70 && drawn.waveActive && !drawn.over; i++) {
      drawn
        ..paused = false
        ..tick(1 / 30)
        ..paused = true;
      looks.addAll([
        for (final r in drawn.rings)
          if (landingLooks.contains(r.look) || r.look == RingLook.orange || (r.look == RingLook.red && r.follow?.side == Side.troop)) r
      ]);
      bursts += drawn.impacts.where((i) => i.$2 == 'hit_elite_orc_big' || i.$2 == 'hit_armored_orc_big' || i.$2 == 'hit_skeleton_archer').length;
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }
    drawn.paused = false;
    // ignore: avoid_print
    print('landing looks drawn: ${looks.length} (${{for (final r in looks) r.look.name}}), bursts $bursts, t ${drawn.t.toStringAsFixed(1)}');
    expect(looks, isNotEmpty, reason: 'the wave\'s champions landed some of the five');
    expect(digest(drawn), digest(plain));
  });
}
