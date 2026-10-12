// A shot whose target went flies on, seen (decisions-log 327, units-and-combat.md "A shot whose target went flies on"):
// offscreen frames at 1600x947 of a wizard's fireball, and of its Arcane Blast, at an orc that falls while the shot is
// halfway there; the shot flies on to where it fell and bursts, its splash hitting the two orcs beside that spot. Into
// <probe root>/shots/shot-through/ (`OUT`), named `<TAG>-<scene>-<nn>.png`, one every 48 ms (3 frames of 16 ms). A probe,
// not part of the suite (no `_test.dart`): queue `["test", "test/probe_shot_through_shots.dart",
// "--dart-define=POH_PROBE_ROOT=<folder>"]` with the worktree (or a `git archive` mirror) as `dir`. It reads no save and
// never touches the real one (flutter_test_config.dart's temp dir); the dice are seeded. Each scene prints the screen
// box round its units, for cropping, and the HP the splash took.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hero_skill_helpers.dart';
import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/shot-through');
const tag = String.fromEnvironment('TAG', defaultValue: 'after');

/// A wizard at cell (2, 3), an orc 64 before it and two more 14 above and below that one, all held still (never
/// walking, striking or falling on their own).
(Game, Unit, Unit, List<Unit>) scene() {
  final g = bareGame(Random(1))
    ..heroSkills = false
    ..monsterSkills = false
    ..skills = false;
  final w = placeNow(g, 'wizard', 2, 3)
    ..cd = hold
    ..mp = 0;
  g
    ..startWave()
    ..queue.clear();
  Unit orc(Point<double> at) => foeAt(g, 'orc', at)
    ..hp = 1e6
    ..cd = hold
    ..busyUntil = double.negativeInfinity // drawn standing (a held one is drawn rising)
    ..stunUntil = 1e9; // and never walking off
  final target = orc(w.pos + const Point(64.0, 0.0));
  return (g, w, target, [orc(target.pos + const Point(0.0, 14.0)), orc(target.pos + const Point(0.0, -14.0))]);
}

void main() {
  testWidgets('shot through shots', (tester) async {
    await tester.runAsync(() async {
      await loadHudFontNow();
    });
    tester.view
      ..physicalSize = const Size(1600, 947)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = TdGame();
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: GameWidget(game: game)));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue);
    final b = game.board
      ..welcome = null
      ..miniMapOpen = false;

    Future<void> shot(String name) async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = (await tester.runAsync(() => boundary.toImage()))!;
      await tester.runAsync(() async {
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    for (final arcane in [false, true]) {
      final name = arcane ? 'arcane' : 'fireball';
      final (g, w, target, near) = scene();
      b.state = g;
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16)); // the view settles on them
      }
      final s = arcane
          ? Shot(w, target, w.pos + const Point(0, -6), Hit.skill, w.stats.dmg * blast.hit, blast.splash, true, RingLook.arcane)
          : Shot(w, target, w.pos + const Point(0, -6), Hit.normal);
      g.shots.add(s);
      w.attackedAt = g.t; // its attack strip, as it fires
      final xs = [w.pos.x, target.pos.x], ys = [for (final u in [w, target, ...near]) u.pos.y];
      final lt = b.toScreen(xs.reduce(min) - 24, ys.reduce(min) - 34), rb = b.toScreen(xs.reduce(max) + 28, ys.reduce(max) + 14);
      // ignore: avoid_print
      print('box $tag-$name ${lt.dx.round()} ${lt.dy.round()} ${(rb.dx - lt.dx).round()} ${(rb.dy - lt.dy).round()}');
      var fell = -1;
      for (var i = 0; i < 20; i++) {
        await shot('$tag-$name-${i.toString().padLeft(2, '0')}');
        for (var k = 0; k < 3; k++) {
          if (fell < 0 && s.pos.distanceTo(target.pos) <= 32) {
            target
              ..hp = 0
              ..dying = 0; // it falls halfway: another troop's blow
            fell = i;
          }
          await tester.pump(const Duration(milliseconds: 16));
        }
      }
      // ignore: avoid_print
      print('$tag-$name fell at frame $fell, shot to ${s.to}, landed ${!g.shots.contains(s)}, splash took '
          '${[for (final o in near) (1e6 - o.hp).toStringAsFixed(1)]}');
    }
    await tester.pump(const Duration(milliseconds: 16));
  });
}
