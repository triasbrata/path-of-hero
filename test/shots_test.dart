// A shot whose target went flies on (decisions-log 327; units-and-combat.md "A shot whose target went flies on"): it
// keeps its target's last place, flies on to it and lands there as on its target. A splash hurts the units round the
// spot, the unit standing on the spot takes the shot as its target would have, and with nobody there a single shot shows
// its look alone. The monsters' shots at troops the same. A shot in the air at a wave's end or a wipe lands its look
// alone. Every shot here is fired by hand, by a shooter held still, so only the shot does anything.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// A wave on with nothing to spawn and a troop of [type] at cell (2, 3) that never walks or strikes on its own (a
/// walking troop sets those in its way stepping aside); no skills.
(Game, Unit) shooter(String type) {
  final g = bareGame(Random(1))
    ..heroSkills = false
    ..monsterSkills = false
    ..skills = false;
  final u = placeNow(g, type, 2, 3)
    ..cd = hold
    ..busyUntil = hold;
  g
    ..startWave()
    ..queue.clear();
  return (g, u);
}

/// A monster of [type] at [at] that never moves or strikes ([foeAt], and no blow due).
Unit still(Game g, String type, Point<double> at) => foeAt(g, type, at)..cd = hold;

/// A troop of [type] bought onto cell ([c], [r]) and standing at [at], never walking off or striking.
Unit troopAt(Game g, String type, int c, int r, Point<double> at) => placeNow(g, type, c, r)
  ..pos = at
  ..cd = hold
  ..busyUntil = hold;

/// [from]'s plain shot at [target], fired now from where [from] stands.
Shot fire(Game g, Unit from, Unit target) {
  final s = Shot(from, target, from.pos + const Point(0, -6), Hit.normal);
  g.shots.add(s);
  return s;
}

/// Ticks [g] until its shots have all landed (at most 5 s).
void land(Game g) {
  for (var i = 0; i < 100 && g.shots.isNotEmpty; i++) {
    g.tick(0.05);
  }
  expect(g.shots, isEmpty);
}

/// What [o] has after one blow of [dmg] on it.
double afterHit(Unit o, double dmg) => o.maxHp - hitTaken(dmg, o.stats.def);

void main() {
  test('a fireball whose target falls mid-flight flies on to where it fell, bursts there and splashes the monsters round it', () {
    final (g, w) = shooter('wizard');
    final target = still(g, 'orc', w.pos + const Point(56.0, 0.0)), at = target.pos;
    final near = [still(g, 'orc', at + const Point(0.0, 14.0)), still(g, 'orc', at + const Point(0.0, -14.0))];
    final beyond = still(g, 'orc', at + Point(w.stats.splash + tile, 0.0)); // past the splash, and the wave stays on
    final shot = fire(g, w, target);
    g.tick(0.05);
    expect((shot.to, shot.aim), (null, at), reason: 'it homes on its living target');
    target.dying = 0; // it falls to another troop's blow
    g.tick(0.05);
    expect((shot.to, shot.aim, g.shots.contains(shot)), (at, at, true), reason: 'it flies on to where its target fell');
    final left = shot.pos.distanceTo(at);
    g.tick(0.05);
    expect(shot.pos.distanceTo(at), closeTo(left - w.stats.shotSpeed * 0.05, 1e-9), reason: 'at its own speed');
    land(g);
    expect(g.impacts, contains((at, 'fireball')), reason: 'its burst where it lands');
    for (final o in near) {
      expect(o.hp, afterHit(o, shot.dmg), reason: 'the splash round the spot');
    }
    expect(beyond.hp, beyond.maxHp);
  });

  test('the splash at the spot kills as any splash does: kill gold, a kill', () {
    final (g, w) = shooter('wizard');
    final target = still(g, 'orc', w.pos + const Point(56.0, 0.0)), at = target.pos;
    final victim = still(g, 'slime', at + const Point(0.0, 14.0))..hp = 1;
    still(g, 'orc', at + const Point(60.0, 0.0)); // keeps the wave on
    fire(g, w, target);
    g.tick(0.05);
    target.dying = 0;
    final (gold, kills) = (g.gold, g.kills);
    land(g);
    expect((victim.alive, g.gold, g.kills), (false, gold + victim.stats.cost, kills + 1));
  });

  test('Arcane Blast whose target leaked flies on and bursts with its ring and splash at the spot', () {
    final (g, w) = shooter('wizard');
    final target = still(g, 'orc', w.pos + const Point(56.0, 0.0)), at = target.pos;
    final near = still(g, 'orc', at + const Point(20.0, 0.0));
    final shot = Shot(w, target, w.pos + const Point(0, -6), Hit.skill, w.stats.dmg * blast.hit, blast.splash, true, RingLook.arcane);
    g.shots.add(shot);
    g.tick(0.05);
    target.gone = true; // off the field, as a leak goes
    land(g);
    expect(shot.to, at);
    expect(g.impacts, contains((at, 'shards')));
    expect(g.rings.where((r) => r.look == RingLook.arcane).map((r) => r.at), [at]);
    expect(near.hp, afterHit(near, shot.dmg));
  });

  test('a single shot whose target fell hits the unit standing nearest the spot, within half a tile, as its target', () {
    final (g, a) = shooter('archer');
    final target = still(g, 'orc', a.pos + const Point(56.0, 0.0)), at = target.pos;
    final shot = fire(g, a, target);
    g.tick(0.05);
    target.dying = 0;
    // Monsters on the spot it fell from (put after it fell: two living ones closer than 12 shove each other apart).
    final nearest = still(g, 'orc', at + const Point(6.0, 0.0)), next = still(g, 'orc', at + const Point(-7.0, 0.0));
    final past = still(g, 'orc', at + const Point(0.0, landReach + 4)); // further than half a tile
    expect(landReach, tile / 2);
    land(g);
    expect(g.impacts, contains((at, 'hit_archer')));
    expect([nearest.hp, next.hp, past.hp], [afterHit(nearest, shot.dmg), next.maxHp, past.maxHp]);
  });

  test('a single shot whose target fell with nobody on the spot shows its burst there and hits nothing', () {
    final (g, a) = shooter('archer');
    final target = still(g, 'orc', a.pos + const Point(56.0, 0.0)), at = target.pos;
    final aside = still(g, 'orc', at + const Point(0.0, landReach + 4));
    fire(g, a, target);
    g.tick(0.05);
    target.dying = 0;
    land(g);
    expect(g.impacts.where((i) => i.$2 == 'hit_archer').map((i) => i.$1), [at]);
    expect(aside.hp, aside.maxHp);
  });

  test('a monster\'s shot at a troop that fell flies on: a troop on the spot takes it, else it hits nothing', () {
    for (final standing in [true, false]) {
      final (g, a) = shooter('archer');
      final knight = troopAt(g, 'knight', 4, 3, a.pos + const Point(16.0, 0.0));
      final other = troopAt(g, 'soldier', 5, 1, knight.pos + const Point(0.0, 30.0));
      final archer = still(g, 'skeleton_archer', knight.pos + const Point(60.0, 0.0));
      final shot = fire(g, archer, knight);
      g.tick(0.05);
      final at = knight.pos;
      knight.dying = 0; // it falls before the arrow lands
      if (standing) other.pos = at + const Point(0.0, 5.0); // steps onto its place (two living troops that close make way)
      land(g);
      expect(shot.to, at, reason: 'standing: $standing');
      expect(g.impacts, contains((at, 'hit_skeleton_archer')), reason: 'standing: $standing');
      expect(other.hp, standing ? afterHit(other, shot.dmg) : other.maxHp, reason: 'standing: $standing');
    }
  });

  test('shots in the air when the wave ends land their look and hurt nobody', () {
    final (g, a) = shooter('archer');
    final knight = troopAt(g, 'knight', 4, 3, a.pos + const Point(16.0, 0.0));
    final last = still(g, 'skeleton_archer', knight.pos + const Point(64.0, 0.0)), at = last.pos;
    final theirs = fire(g, last, knight), ours = fire(g, a, last);
    g.tick(0.05);
    last.gone = true; // the wave's last monster goes: the wave ends this tick
    g.tick(0.05);
    expect((g.waveActive, theirs.spent, ours.spent, ours.to), (false, true, true, at));
    land(g);
    expect(knight.hp, knight.maxHp, reason: 'a monster\'s arrow landing after the wave hurts nobody');
    expect(g.impacts.map((i) => i.$2), containsAll(['hit_skeleton_archer', 'hit_archer']));
  });

  test('a wipe leaves the shots in the air to land their look alone where their targets were', () {
    final (g, a) = shooter('archer');
    a.hp = 1;
    final far = still(g, 'slime', a.pos + const Point(60.0, 0.0)), at = far.pos;
    g.units.add(Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, a.pos + const Point(10, 0))..entered = true);
    final shot = fire(g, a, far);
    for (var i = 0; i < 20 && !g.wipedOut; i++) {
      g.tick(0.05);
    }
    expect((g.wipedOut, g.over, g.swept.contains(far), shot.spent, shot.to, g.shots.single), (true, false, true, true, at, shot));
    land(g);
    expect(g.impacts.where((i) => i.$2 == 'hit_archer').map((i) => i.$1), [at]);
    expect(far.hp, far.maxHp);
  });
}
