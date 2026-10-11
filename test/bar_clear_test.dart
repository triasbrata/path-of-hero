// The spawn bar's step (decisions-log 287; ui-hud.md "Spawn bar", camera-and-field.md "Field size"; the owner, 2026-10-09:
// "supaya battle jangan sampai di belakang dari action bar untuk spawn troops"): no unit, foe, shot, loot pile or plate
// is ever drawn behind the bar. A long wave of the w89 save (wave 90: its whole army, the wave's foes, its drops) fought
// headless gives how low anything on the field goes; then at the test windows and every landscape window from 900x400 to
// 2600x1500 (step 100), between waves and in a wave, the bar (the step with its slopes, down to the screen's bottom) is
// under the lowest of them, and the first lane's bars are under the top band. The lowest unit's pinned plate is over the bar. The field's
// scale is the screen's but on a short screen, the HUD's never the zoom's. One TdGame per widget test.
//
// Never let a wave be won or the game end on the Board here (the Board then saves): a wave begun runs a few frames only.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'troops_detail_test.dart' show boot, desk, frames, rich, tablet, wide;

const owner = Size(1600, 947); // the owner's window

/// How far under its place each thing is drawn at the most, world units: a unit's shadow's last row (its feet 5 under
/// its y, the shadow 1 more), a shot (the wizard's fireball and Arcane Blast's star: lib/wizard_fx.dart), a loot icon (10 px), a
/// relic's glint (16 px) and a material's pile (10 px).
const unitUnder = 6.0, shotUnder = 8.0, lootUnder = 5.0, relicUnder = 8.0, matUnder = 5.0;

Game w89() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>,
    Random(89), Random(189), Random(389));

/// The lowest field y anything is drawn at over [seconds] of [g]'s wave, fought headless (the view [viewW] wide), and
/// what it was.
(double, String) lowestDrawn(Game g, {double seconds = 60, double viewW = 341}) {
  var (low, what) = (double.negativeInfinity, '');
  void seen(double y, String w) {
    if (y > low) (low, what) = (y, w);
  }

  const dt = 1 / 30;
  g.startWave();
  for (var i = 0; i < seconds / dt && g.waveActive && !g.over; i++) {
    g
      ..viewW = viewW
      ..tick(dt);
    for (final u in g.units) {
      if (u.alive) seen(u.pos.y + unitUnder, '${u.side.name} ${u.type}');
    }
    for (final s in g.shots) {
      seen(s.pos.y + shotUnder, 'shot of ${s.from.type}');
    }
    for (final (p, _) in g.drops) {
      seen(p.y + lootUnder, 'loot');
    }
    for (final (p, _) in g.relicDrops) {
      seen(p.y + relicUnder, 'relic');
    }
    for (final (p, _, _) in g.matPops) {
      seen(p.y + matUnder, 'material');
    }
    g.matPops.clear(); // the Board takes them each frame
  }
  return (low, what);
}

void main() {
  test('a long wave: nothing on the field goes under the step\'s top (field y stepLip): units no lower than y fieldH - 2, '
      'their shadows to 132; shots, loot and materials no lower', () {
    final g = w89();
    expect(g.troops.where((u) => u.alive).length, greaterThanOrEqualTo(36), reason: 'the whole army');
    final (low, what) = lowestDrawn(g);
    expect(low, lessThanOrEqualTo(stepLip), reason: 'the lowest drawn: $what at $low');
    expect(low, greaterThanOrEqualTo(fieldH - 2 + unitUnder - 1e-9), reason: 'the lowest lane is reached ($what)');
  });

  testWidgets('at every landscape window the bar (the step, its slopes, down to the screen\'s bottom) is under the lowest '
      'anything on the field is drawn, between waves and in a wave; the first lane\'s bars under the top band', (tester) async {
    final b = await boot(tester);
    // The lowest of the long wave, or the step's own top, whichever is lower.
    final (low, _) = lowestDrawn(w89(), seconds: 20);
    final lowest = max(low, stepLip);
    const named = [owner, desk, tablet, wide, Size(1280, 720), Size(1920, 1080)];
    final sizes = [
      ...named,
      for (var w = 900.0; w <= 2600; w += 100)
        for (var h = 400.0; h <= min(w, 1500); h += 100) Size(w, h),
    ];
    for (final size in sizes) {
      final (w, h) = (size.width, size.height);
      tester.view.physicalSize = size;
      for (final wave in [false, true]) {
        final g = b.state = rich();
        if (wave) g.startWave();
        await frames(tester, 2);
        final tag = '${w.round()}x${h.round()} ${wave ? 'wave' : 'between'}', bar = b.spawnBarArea;
        expect(bar, isNot(Rect.zero), reason: tag);
        // Down to the screen's bottom, symmetric about its middle; a near-square window's slopes may run off its sides,
        // the named sizes' show whole.
        expect(bar.bottom, h, reason: '$tag: $bar to the screen\'s bottom');
        expect((bar.left + bar.right) / 2, closeTo(w / 2, 1), reason: '$tag: $bar centred');
        if (named.contains(size)) expect((bar.left > 0, bar.right < w), (true, true), reason: '$tag: $bar, the slopes whole');
        expect(b.toScreen(g.cam, lowest).dy, lessThanOrEqualTo(bar.top + 1e-6), reason: '$tag: the lowest over the bar $bar');
        expect(b.toScreen(g.cam, stepLip).dy, closeTo(bar.top, 1e-6), reason: '$tag: the step\'s top on the plinth');
        final band = b.waveMeter.bottom; // the top band: the troop counter and the meter, as tall
        expect(b.toScreen(g.cam, tile / 2 - barReach).dy, greaterThanOrEqualTo(band), reason: '$tag: the first lane\'s bars under the top band $band');
        for (final (r, t) in b.spawnBarCards) {
          expect(r.top, greaterThan(bar.top), reason: '$tag: $t on the step');
        }
        b.state = Game(); // leave no wave to win
        await frames(tester, 2);
      }
    }
  });

  testWidgets('the lowest unit\'s pinned plate is over the bar, at the test windows', (tester) async {
    final b = await boot(tester);
    for (final size in [owner, desk, tablet, wide]) {
      tester.view.physicalSize = size;
      // Between waves the open book covers the field's right: a knight in the lowest lane at its left, standing still.
      final g = b.state = Game()..units.clear();
      await frames(tester, 20);
      final u = Unit(Side.troop, 'knight', g.statsOf('knight'), Point(g.cam + 40, fieldH - 2))
        ..entered = true
        ..arriving = false
        ..stunUntil = 1e9;
      g.units.add(u);
      await frames(tester, 2);
      await tester.tapAt(b.toScreen(u.pos.x, u.pos.y - 7)); // the middle of its body
      await frames(tester, 2);
      expect(b.pinned, u, reason: '$size: pinned');
      expect(b.pinnedPlate, isNot(Rect.zero), reason: '$size');
      expect(b.pinnedPlate.bottom, lessThanOrEqualTo(b.spawnBarArea.top), reason: '$size: ${b.pinnedPlate} over ${b.spawnBarArea}');
      b.state = Game();
      await frames(tester, 3);
    }
  });

  testWidgets('the field\'s scale is the screen\'s height over the scene\'s but on a short screen (915x412: a little less, the '
      'view wider), the HUD\'s scale never the zoom\'s; the step and the scale the same with the bar hidden (a Town)', (tester) async {
    final b = await boot(tester);
    for (final (size, zoomed) in [(owner, false), (desk, false), (tablet, false), (const Size(1280, 720), false), (wide, true)]) {
      tester.view.physicalSize = size;
      final g = b.state = rich();
      await frames(tester, 3);
      final scale = b.toScreen(0, 1).dy - b.toScreen(0, 0).dy, full = size.height / (backdropH + fieldH);
      if (zoomed) {
        expect(scale, lessThan(full * 0.95), reason: '$size: zoomed out ($scale for $full)');
        expect(scale, greaterThan(full * 0.85), reason: '$size: a little');
      } else {
        expect(scale, closeTo(full, 1e-9), reason: '$size: the screen\'s');
      }
      expect(g.viewW, closeTo(size.width / scale, 1e-6), reason: '$size: the view as wide as the screen at that scale');
      expect(b.hudScale, size.height < 713 ? 2 : 3, reason: '$size: the HUD\'s own scale');
      if (size == wide) {
        expect(scale, closeTo(1.916, 0.001), reason: 'its scale');
        expect(g.viewW, closeTo(477.6, 0.1), reason: 'its view (426.4 before decisions-log 287)');
      }
      // A Town (no bar): the field's scale and framing don't move.
      final top = b.spawnBarArea.top;
      final t = b.state = Game()
        ..towns = true
        ..townAt = 1;
      expect(t.enterTown(), isTrue);
      await frames(tester, 40);
      expect(b.spawnBarArea, Rect.zero, reason: '$size: no bar in a Town');
      expect(b.toScreen(0, 1).dy - b.toScreen(0, 0).dy, closeTo(scale, 1e-9), reason: '$size: the field\'s scale kept');
      expect(b.toScreen(0, stepLip).dy, closeTo(top, 1e-6), reason: '$size: its framing kept');
      b.state = Game();
      await frames(tester, 3);
    }
  });
}
