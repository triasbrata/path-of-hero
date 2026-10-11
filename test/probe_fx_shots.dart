// The field's looks cut from the packs' sheets (decisions-log 173; ui-hud.md): offscreen shots of the rings, orbs,
// zones, beams and the troops' and the awakening skills' looks in a gallery, next to a pack hit burst, at 1266x713 and
// 412x860, into <probe root>/shots/pack-looks (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_fx_shots.dart", "--dart-define=GROUP=<1..4|all>"]` with the worktree as `dir`; run it in a
// mirror of main too for the before shots. Groups: 1 orbs, plain rings, the glob, special arrows; 2 the troops' skills
// (#81); 3 the awakening skills (#88); 4 the zones and Skyfall's landing shadow. Each at 20%, 50% and 80% of its time.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/pack-looks');
const group = String.fromEnvironment('GROUP', defaultValue: 'all');

/// A scene: what to put on the field for a look at progress [p] (0..1 of its time), with the game's clock [t].
typedef Scene = void Function(Game g, double t, double p);

/// The gallery's spots: two rows of four, in world units on the field (clear of the left HUD).
const spots = [
  Point(70.0, 44.0), Point(118.0, 44.0), Point(166.0, 44.0), Point(214.0, 44.0),
  Point(70.0, 100.0), Point(118.0, 100.0), Point(166.0, 100.0), Point(214.0, 100.0),
];

Unit troopAt(Game g, String type, Point<double> at) {
  var placed = false;
  for (var c = 0; c < 6 && !placed; c++) {
    for (var r = 0; r < rows && !placed; r++) {
      if (g.troopAt(c, r) == null) placed = g.place(type, c, r);
    }
  }
  expect(placed, isTrue, reason: 'placing $type');
  return g.units.last
    ..pos = at
    ..entered = true
    ..arriving = false
    ..cd = hold;
}

/// A monster standing at [at] that never strikes and outlives every blow; drawn standing (a board draws a unit held by
/// busyUntil as rising, from a busyFrom it never had).
Unit held(Game g, String type, Point<double> at) => foeAt(g, type, at)
  ..hp = 1e5
  ..busyUntil = double.negativeInfinity
  ..cd = hold;

void main() {
  testWidgets('fx shots', (tester) async {
    tester.view
      ..physicalSize = const Size(1266, 713)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await loadHudFontNow();
    });
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

    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> shot(String name) async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = (await tester.runAsync(() => boundary.toImage()))!;
      await tester.runAsync(() async {
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
      // ignore: avoid_print
      print('wrote $out/$name.png ${img.width}x${img.height} cam ${b.camX.toStringAsFixed(1)}');
    }

    // Each group: its looks, one per spot, each drawn at progress p.
    final groups = <String, List<Scene>>{
      // Orbs, plain ground rings, the glob, the special arrows' trails.
      '1': [
        (g, t, p) {
          final w = troopAt(g, 'wizard', spots[0] - const Point(30.0, 0)), f = held(g, 'orc', spots[0] + const Point(60.0, 0));
          g.shots.add(Shot(w, f, spots[0], Hit.normal));
        },
        (g, t, p) {
          final w = troopAt(g, 'wizard', spots[1] - const Point(30.0, 0)), f = held(g, 'orc', spots[1] + const Point(60.0, 0));
          g.shots.add(Shot(w, f, spots[1], Hit.skill, null, 30, true, RingLook.arcane));
        },
        (g, t, p) => g.rings.add(Ring(spots[2], radius: 24, since: t - p * ringTime, look: RingLook.red)),
        (g, t, p) => g.rings.add(Ring(spots[3], radius: 24, since: t - p * ringTime, look: RingLook.dust)),
        (g, t, p) {
          final s = held(g, 'slime', spots[4] + const Point(40.0, 0)), o = troopAt(g, 'soldier', spots[4] - const Point(40.0, 0));
          g.shots.add(Shot.special(s, o, spots[4], dmg: 0, speed: 1, look: ShotLook.glob));
        },
        (g, t, p) {
          final a = troopAt(g, 'archer', spots[5] - const Point(40.0, 0)), f = held(g, 'orc', spots[5] + const Point(60.0, 0));
          g.shots.add(Shot.special(a, f, spots[5], dmg: 0, speed: 1, look: ShotLook.trail));
        },
        (g, t, p) {
          final a = troopAt(g, 'archer', spots[6] - const Point(40.0, 0)), f = held(g, 'orc', spots[6] + const Point(60.0, 0));
          g.shots.add(Shot.special(a, f, spots[6], dmg: 0, speed: 1, look: ShotLook.silver));
        },
        (g, t, p) => g.rings.add(Ring(spots[7], radius: 40, since: t - p * ringTime, look: RingLook.steel)),
      ],
      // The troops' skills' looks (#81).
      '2': [
        (g, t, p) => g.rings.add(Ring.over(troopAt(g, 'soldier', spots[0]), radius: 12, since: t - p * skillLook.brace, look: RingLook.brace, duration: skillLook.brace)),
        (g, t, p) => g.rings.add(Ring.over(troopAt(g, 'knight', spots[1]), radius: slash.reach, since: t - p * skillLook.slash, look: RingLook.slash, duration: skillLook.slash)),
        (g, t, p) {
          final u = troopAt(g, 'swordsman', spots[2])..frenzyUntil = t + 3;
          g.rings.add(Ring.over(u, radius: 16, since: t - p * skillLook.rage, look: RingLook.rage, duration: skillLook.rage));
        },
        (g, t, p) {
          final u = troopAt(g, 'knight', spots[3]);
          g.rings
            ..add(Ring(spots[3], radius: prayer.reach, since: t - p * ringTime, look: RingLook.prayer))
            ..add(Ring.over(u, radius: 8, since: t - p * skillLook.pillar, look: RingLook.pillar, duration: skillLook.pillar));
        },
        (g, t, p) {
          troopAt(g, 'armored_axeman', spots[4]);
          g.rings.add(Ring(spots[4], radius: slam.reach, since: t - p * skillLook.crack, look: RingLook.crack, duration: skillLook.crack));
        },
        (g, t, p) => g.rings.add(Ring(spots[5], radius: blast.splash, since: t - p * ringTime, look: RingLook.arcane)),
        (g, t, p) {
          final u = troopAt(g, 'soldier', spots[6]);
          g.rings
            ..add(Ring(spots[6], radius: ward.reach, since: t - p * ringTime, look: RingLook.holy))
            ..add(Ring.over(u, radius: 8, since: t - p * skillLook.dome, look: RingLook.dome, duration: skillLook.dome));
        },
        (g, t, p) {
          troopAt(g, 'lancer', spots[7] - const Point(20.0, 0));
          g.beams.add(Beam([spots[7] - const Point(20.0, 0), spots[7] + const Point(40.0, 0)], since: t - p * skillLook.thrust, duration: skillLook.thrust, look: BeamLook.thrust));
        },
      ],
      // The awakening skills' looks (#88).
      '3': [
        (g, t, p) => g.rings.add(Ring.over(held(g, 'orc', spots[0]), radius: 10, since: t - p * ringTime, look: RingLook.shatter)),
        (g, t, p) => g.rings.add(Ring(spots[1], radius: 24, since: t - p * ringTime, look: RingLook.dispel)),
        (g, t, p) => g.rings.add(Ring(spots[2], radius: 24, since: t - p * ringTime, look: RingLook.implode)),
        (g, t, p) => g.rings.add(Ring.over(held(g, 'orc', spots[3]), radius: 10, since: t - p * ringTime, look: RingLook.shards)),
        (g, t, p) => g.rings.add(Ring.over(troopAt(g, 'knight', spots[4]), radius: 16, since: t - p * ringTime, look: RingLook.unchain)),
        (g, t, p) => g.rings.add(Ring.over(held(g, 'orc', spots[5]), radius: 10, since: t - p * ringTime, look: RingLook.crossCut)),
        (g, t, p) => g.rings.add(Ring(spots[6], radius: 24, since: t - p * ringTime, look: RingLook.crater)),
        (g, t, p) {
          g.rings.add(Ring.over(troopAt(g, 'soldier', spots[7]), radius: 12, since: t - p * ringTime, look: RingLook.bloom));
          troopAt(g, 'lancer', spots[7] - const Point(40.0, 30));
          g.beams
            ..add(Beam([spots[7] - const Point(40.0, 30), spots[7] - const Point(-30.0, 30)], since: t - p * 0.4, duration: 0.4, look: BeamLook.lunge))
            ..add(Beam([spots[7] - const Point(40.0, 15), spots[7] - const Point(-30.0, 15)], since: t - p * 0.4, duration: 0.4, look: BeamLook.rush));
        },
      ],
      // Zones.
      '4': [
        for (final (i, look) in [ZoneLook.frost, ZoneLook.slime, ZoneLook.arrowRain, ZoneLook.volley, ZoneLook.consecrate, ZoneLook.singularity, ZoneLook.banner].indexed)
          (g, t, p) {
            final from = troopAt(g, 'archer', Point(20.0, 20.0 + i));
            g.zones.add(Zone(from, spots[i], since: t - p * 3, duration: 3, radius: 22, side: Side.enemy, look: look));
          },
        (g, t, p) {
          // Skyfall's landing shadow: an axeman in the air coming down on spots[7].
          final u = troopAt(g, 'armored_axeman', spots[7] - const Point(30.0, 10));
          u.move = Carry(u.pos, spots[7], t - p * 0.6, t + (1 - p) * 0.6, lift: 20, look: CarryLook.skyfall, radius: 24);
        },
      ],
    };

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860))]) {
      tester.view.physicalSize = size;
      for (final MapEntry(key: id, value: scenes) in groups.entries) {
        if (group != 'all' && group != id) continue;
        for (final p in const [0.2, 0.5, 0.8]) {
          final g = bareGame(Random(1))
            ..heroSkills = false
            ..monsterSkills = false
            ..skills = false;
          g
            ..startWave()
            ..queue.clear();
          held(g, 'orc', const Point(330.0, 70.0)); // keeps the wave on
          b.state = g;
          await frames(20);
          // A pack burst for comparison, under the last spot's row, shown mid-way when the shot is taken.
          g.impacts.add((const Point(30.0, 72.0), 'hit_knight'));
          await frames(8);
          for (final s in scenes) {
            s(g, g.t, p);
          }
          await frames(1);
          await shot('g$id-$tag-p${(p * 10).round()}');
        }
      }
    }
  });
}
