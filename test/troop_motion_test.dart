// Where a troop is drawn and how it walks there (lib/body_look.dart, decisions-log 307 and 310): a troop the game moves
// in one step (a shove) is drawn closing the gap no faster than the rule, walking, and taps find it where it is drawn; a
// fast troop's shove as slowly as a slow one's, its own walk exactly; a frame cut short moves its body no more than a
// 30 fps frame; an Auto-Bought troop walks in with its walk strip; a troop on a move of its own, new, or put somewhere
// (moved to a cell) is drawn where the game has it, and a monster's knockback is drawn as a shove.
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

/// The most a body standing (not walking) may move in a frame of [dt] game seconds toward a gap of [gap]: the rule.
double mostStanding(Unit u, double gap, double dt) => max(bodyRun * troopTypes[u.type]!.speed, gap / bodyCatch) * min(dt, bodyFrame);

Future<Board> boot(WidgetTester tester, [double w = 1266, double h = 713]) async {
  tester.view
    ..physicalSize = Size(w, h)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final game = TdGame();
  await tester.pumpWidget(GameWidget(game: game));
  for (var i = 0; i < 3000 && !game.isLoaded; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(game.isLoaded, isTrue);
  return game.board
    ..welcome = null
    ..miniMapOpen = false;
}

/// [u] standing on [g]'s field at [at], its spot there.
Unit stand(Game g, String type, Point<double> at) {
  final u = Unit(Side.troop, type, troopTypes[type]!, at)
    ..entered = true
    ..arriving = false
    ..post = at;
  g.units.add(u);
  return u;
}

void main() {
  testWidgets('a troop the game moves in one step is drawn closing the gap no faster than the rule, walking, and a tap '
      'finds it where it is drawn', (tester) async {
    final b = await boot(tester);
    final g = b.state = Game(Random(1))..units.clear();
    final u = stand(g, 'archer', const Point(40, 40));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(b.drawnAt(u), u.pos); // a new troop is drawn where it stands
    expect(b.stripOf(u), 'idle');
    // A shove of 36 (the worst one tick gave on the owner's wave-30 save): its spot moves with it, so it stays there.
    u.post = u.pos = const Point(40, 76);
    var t = g.t, at = b.drawnAt(u), walked = 0, frames = 0;
    while (b.drawnAt(u) != u.pos && frames < 120) {
      await tester.pump(const Duration(milliseconds: 16));
      frames++;
      final now = b.drawnAt(u), dt = g.t - t, gap = (u.pos - at).magnitude;
      final most = mostStanding(u, gap, dt);
      expect((now - at).magnitude, lessThanOrEqualTo(most + 1e-9), reason: 'frame $frames: ${(now - at).magnitude} > $most');
      if (now != at) {
        expect(b.stripOf(u), 'walk', reason: 'frame $frames: it moves');
        walked++;
      }
      (t, at) = (g.t, now);
    }
    expect(b.drawnAt(u), u.pos);
    expect(walked, greaterThan(5)); // a few quick steps, not a pop
    expect(frames, lessThan(60)); // within a second
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(b.stripOf(u), 'idle'); // standing again

    // Paused mid-gap: the tap finds it where it is drawn, not where the game has it.
    u.post = u.pos = const Point(40, 40);
    await tester.pump(const Duration(milliseconds: 16));
    g.paused = true;
    await tester.pump(const Duration(milliseconds: 16));
    final drawn = b.drawnAt(u);
    expect((drawn - u.pos).magnitude, greaterThan(20));
    await tester.tapAt(b.toScreen(u.pos.x, u.pos.y - 7));
    await tester.pump(const Duration(milliseconds: 16));
    expect(b.pinned, isNull); // nothing drawn there
    await tester.tapAt(b.toScreen(drawn.x, drawn.y - 7));
    await tester.pump(const Duration(milliseconds: 16));
    expect(b.pinned, u);
    g.paused = false;
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16)); // past the tap's own timer
    }
  });

  testWidgets('a frame cut short moves a body no more than a 30 fps frame; far off or on a leap of its own it is where the '
      'game has it, and a monster\'s knockback is drawn as a shove', (tester) async {
    final b = await boot(tester);
    final g = b.state = Game(Random(1))..units.clear();
    final u = stand(g, 'knight', const Point(40, 40));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    u.post = u.pos = const Point(40, 70);
    final before = b.drawnAt(u);
    await tester.pump(const Duration(milliseconds: 300)); // a stall: the game ticks 0.1 s
    expect((b.drawnAt(u) - before).magnitude, lessThanOrEqualTo(mostStanding(u, 30, bodyFrame) + 1e-9));
    expect((b.drawnAt(u) - before).magnitude, greaterThan(0));
    // A gap of bodySnap or more: there at once.
    u.post = u.pos = const Point(40 + bodySnap + 1, 70);
    await tester.pump(const Duration(milliseconds: 16));
    expect(b.drawnAt(u), u.pos);
    // Its own leap (a Hero's skill, its hop's own look): exactly where the game has it, every frame.
    g.leap(u, u.pos + const Point(2 * tile, 0));
    for (var i = 0; i < 30 && u.move != null; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(b.drawnAt(u), u.pos);
    }
    u.post = u.pos;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // A monster's knockback (a slide it doesn't make): drawn as a shove is, behind the game and no faster than the
    // rule, there in the end.
    expect(g.knockBack(u, tile), isTrue);
    u.post = (u.move! as Carry).to; // it stays where it is knocked to
    var t = g.t, at = b.drawnAt(u), behind = 0;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final now = b.drawnAt(u);
      expect((now - at).magnitude, lessThanOrEqualTo(mostStanding(u, (u.pos - at).magnitude, g.t - t) + 1e-9), reason: 'frame $i');
      if (now != u.pos) behind++;
      (t, at) = (g.t, now);
    }
    expect(behind, greaterThan(3));
    expect(b.drawnAt(u), u.pos);
  });

  testWidgets('a fast troop (boots) shoved aside is drawn closing the gap at its type\'s base pace, not three times its own '
      'walk; its own walk is drawn exactly', (tester) async {
    final b = await boot(tester);
    final g = b.state = Game(Random(1))..units.clear();
    g.upgrades['knight'] = List.filled(4, Item.boots);
    final u = stand(g, 'knight', const Point(40, 40))..stats = g.statsOf('knight');
    expect(u.stats.speed, greaterThan(2 * troopTypes['knight']!.speed));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    // The separation's shove of 12 (its spot moves with it): no faster than the base pace's rule, a few frames.
    u.post = u.pos = const Point(40, 52);
    var t = g.t, at = b.drawnAt(u), frames = 0;
    while (b.drawnAt(u) != u.pos && frames < 120) {
      await tester.pump(const Duration(milliseconds: 16));
      frames++;
      final now = b.drawnAt(u), dt = g.t - t, gap = (u.pos - at).magnitude;
      expect((now - at).magnitude, lessThanOrEqualTo(mostStanding(u, gap, dt) + 1e-9), reason: 'frame $frames');
      if (frames == 1) expect((now - at).magnitude, lessThan(bodyRun * u.stats.speed * dt), reason: 'slower than 3x its own walk');
      (t, at) = (g.t, now);
    }
    expect(frames, greaterThan(5));
    // Walking off to a spot far away: drawn exactly where the game has it, every frame.
    u.post = const Point(200, 52);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(b.drawnAt(u).distanceTo(u.pos), lessThan(1e-9), reason: 'frame $i');
    }
    expect(u.moving, isTrue);
    expect(b.stripOf(u), 'walk');
  });

  testWidgets('a troop moved to another cell between waves, and the one it swaps with, are drawn there at once', (tester) async {
    final b = await boot(tester);
    final g = b.state = Game(Random(1))..gold = 10000;
    for (final type in ['knight', 'archer']) {
      g.autoPlace(type);
    }
    for (var i = 0; i < 400 && g.troops.any((u) => u.arriving || u.moving); i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final knight = g.troops.firstWhere((u) => u.type == 'knight'), archer = g.troops.firstWhere((u) => u.type == 'archer');
    final (k0, a0) = (knight.pos, archer.pos);
    expect(k0.distanceTo(a0), lessThan(3 * tile)); // near: the old rule glided them over
    await tester.dragFrom(b.toScreen(k0.x, k0.y), b.toScreen(a0.x, a0.y) - b.toScreen(k0.x, k0.y));
    await tester.pump(const Duration(milliseconds: 16));
    expect(knight.post.distanceTo(a0) < 1 && archer.post.distanceTo(k0) < 1, isTrue); // swapped
    expect(b.drawnAt(knight), knight.pos);
    expect(b.drawnAt(archer), archer.pos);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  });

  testWidgets('a troop bought mid-wave (Auto Buy) is drawn from where it comes on and walks in with its walk strip, its '
      'stride as quick as it goes', (tester) async {
    final b = await boot(tester);
    final g = b.state = Game(Random(1))..gold = 10000;
    for (final type in ['knight', 'soldier', 'archer']) {
      g.autoPlace(type);
    }
    for (var i = 0; i < 400 && g.troops.any((u) => u.arriving); i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    g.startWave();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final before = {...g.troops};
    expect(g.autoPlace('archer'), isTrue); // what Auto Buy does for a fallen archer
    final u = g.troops.firstWhere((o) => !before.contains(o));
    await tester.pump(const Duration(milliseconds: 16));
    expect(b.drawnAt(u), u.pos); // drawn from where it comes on: no glide from elsewhere
    var walking = 0;
    for (var i = 0; i < 60; i++) {
      final at = b.drawnAt(u);
      await tester.pump(const Duration(milliseconds: 16));
      if ((b.drawnAt(u) - at).magnitude > 0.05 && u.troopWind == null) {
        expect(b.stripOf(u), 'walk', reason: 'frame $i: it moves');
        walking++;
      }
    }
    expect(walking, greaterThan(20));
  });
}
