// Shared by the Hero skill tests (#48): hero_skills_test.dart, hero_moves_test.dart, hero_shots_test.dart…
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

/// busyUntil for a unit that stands still and never fights.
const hold = 1e9;

/// A game without the free healer, with a 6-column zone and gold to spare.
Game bareGame([Random? rng]) => Game(rng)
  ..capacity = 6 * rows
  ..units.clear()
  ..gold = 100000;

/// A troop of [type] bought onto cell ([c], [r]), standing there at once instead of marching in.
Unit placeNow(Game g, String type, int c, int r) {
  expect(g.place(type, c, r), isTrue, reason: 'placing $type at ($c, $r)');
  return g.units.last
    ..pos = g.units.last.post
    ..entered = true
    ..arriving = false;
}

/// A monster of [type] and [tier] (of the game's wave) standing at [at], on the field, that never moves or
/// fights on its own ([hold]).
Unit foeAt(Game g, String type, Point<double> at, [Tier tier = Tier.normal]) {
  final u = g.monster(type, tier, at)
    ..entered = true
    ..busyUntil = hold;
  g.units.add(u);
  return u;
}

/// A wave begun with nothing left to spawn (it runs while a monster is added), and a Hero of [skill]'s type
/// at cell (2, 3) holding [skill] with full MP. It never strikes on its own ([Unit.cd]) and the #10 skills
/// are off ([Game.skills]), so what happens is its Hero skill's doing. Not refit: its stats are its type's.
(Game, Unit) heroCaster(HeroSkill skill, [Random? rng]) {
  final g = bareGame(rng)..skills = false;
  final h = placeNow(g, skill.type, 2, 3);
  g
    ..startWave()
    ..queue.clear();
  h
    ..hero = true
    ..heroSkill = skill
    ..cd = hold
    ..mp = h.stats.mp.toDouble();
  return (g, h);
}

/// Ticks [g] by [dt] until [s] seconds have passed. A game that is over (its last troop fell, its lives gone) or paused
/// stops its clock ([Game.tick] returns at once): then it fails at once, rather than spin until the runner's timeout.
void runFor(Game g, double s, [double dt = 0.05]) {
  final end = g.t + s - 1e-9;
  while (g.t < end) {
    final was = g.t;
    g.tick(dt);
    if (g.t == was) fail('runFor: the clock stopped at ${g.t} s (over: ${g.over}, paused: ${g.paused}) with ${end - was} s to go');
  }
}
