// The zones' and rings' looks at the units' pixel size (decisions-log 177; ui-hud.md): offscreen shots at 1266x713 and
// 412x860 into OUT (default <probe root>/shots/fx-zone/<TAG>). A probe, not part of the suite (no `_test.dart`):
// queue `["test", "test/probe_zone_shots.dart", "--dart-define=SECTION=<gallery|fight>", "--dart-define=TAG=<after>"]`
// with the worktree as `dir`; run it in a git-archive mirror of main too for the before shots. SECTION:
//   gallery: each look alone at the field's middle, a knight and an orc standing in it, at 20%, 50% and 80% of its
//            time: Singularity's well at Bangkit 1 and 3+, its collapse, Holy Shield's ring, Arrow Rain's zone wide,
//            Howl's and Death Nova's rings, Skyfall's landing shadow, and Consecration and the frost field (2x, kept).
//   tells  : the wind-up tells whose reach is over twice the circle (Howl, Earthshaker, Roar, Death Nova, Curse of
//            Frailty, Last Rites), each a boss winding up beside a knight, 30% and 80% into its wind-up.
//   fight  : the w89 save's next wave (w90) with its Bangkit-5 wizards: the first well 1 s in, 2 s in, and its collapse.
// Each shot prints a CROP line (the look's box on the screen, in px) for the zoomed crops.
import 'dart:convert';
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

const tag = String.fromEnvironment('TAG', defaultValue: 'after');
const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/fx-zone/$tag');
const section = String.fromEnvironment('SECTION', defaultValue: 'gallery');

/// A look on the field: what to put there at progress [p] (0..1 of its time [time]) round [at], with the clock [t].
typedef Look = ({String name, double time, double radius, void Function(Game g, Point<double> at, double t, double p) put});

/// An orc standing at [at] that never strikes, walks or falls; drawn standing (a board draws a unit held by busyUntil
/// as rising, from a busyFrom it never had).
Unit held(Game g, Point<double> at) {
  final u = foeAt(g, 'orc', at)
    ..hp = 1e5
    ..busyUntil = double.negativeInfinity
    ..cd = hold;
  g.addEffect(u, Status.slow, hold, k: 0);
  return u;
}

void p(String s) {
  // ignore: avoid_print
  print(s);
}

void main() {
  testWidgets('zone shots $section', (tester) async {
    tester.view
      ..physicalSize = const Size(1266, 713)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadHudFontNow);
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
      p('SHOT $out/$name.png ${img.width}x${img.height}');
    }

    // The box round [at] that holds a reach of [radius] and the units in it, on the screen.
    void crop(String name, Point<double> at, double radius) {
      final a = b.toScreen(at.x - radius - 24, at.y - radius * 0.45 - 30), z = b.toScreen(at.x + radius + 24, at.y + radius * 0.45 + 16);
      p('CROP $name ${a.dx.round()} ${a.dy.round()} ${(z.dx - a.dx).round()} ${(z.dy - a.dy).round()}');
    }

    final Look well1 = (name: 'well1', time: 3.0, radius: singularityK.radius[0], put: (g, at, t, q) {
      g.zones.add(Zone(g.troops.first, at, since: t - q * 3, duration: 3, radius: singularityK.radius[0], side: Side.enemy, look: ZoneLook.singularity));
    });
    final Look well3 = (name: 'well3', time: 3.0, radius: singularityK.radius[2], put: (g, at, t, q) {
      g.zones.add(Zone(g.troops.first, at, since: t - q * 3, duration: 3, radius: singularityK.radius[2], side: Side.enemy, look: ZoneLook.singularity));
    });
    Look ring(String name, double radius, RingLook look, [double time = ringTime]) => (name: name, time: time, radius: radius, put: (g, at, t, q) {
          g.rings.add(Ring(at, radius: radius, since: t - q * time, look: look, duration: time));
        });
    Look zone(String name, double radius, ZoneLook look, double time) => (name: name, time: time, radius: radius, put: (g, at, t, q) {
          g.zones.add(Zone(g.troops.first, at, since: t - q * time, duration: time, radius: radius, side: Side.enemy, look: look));
        });
    final Look skyfall = (name: 'skyfall', time: 0.6, radius: skyfallK.radius[2], put: (g, at, t, q) {
      final u = placeNow(g, 'armored_axeman', 0, 0)..cd = hold;
      u.move = Carry(at - const Point(30.0, 10.0), at, t - q * 0.6, t + (1 - q) * 0.6, lift: 20, look: CarryLook.skyfall, radius: skyfallK.radius[2]);
    });
    final looks = <Look>[
      well1,
      well3,
      ring('implode3', singularityK.radius[2], RingLook.implode, singularityK.implode),
      ring('holy', ward.reach, RingLook.holy),
      zone('volley', 44, ZoneLook.volley, skillLook.volley),
      ring('howl', howlK.reach, RingLook.grey, wideRingTime),
      ring('deathNova', deathNovaK.reach, RingLook.dark),
      skyfall,
      zone('consecrate', consecrationK.radius[2], ZoneLook.consecrate, 4),
      zone('frost', frostStormK.radius, ZoneLook.frost, 5),
    ];

    for (final (size, view) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860))]) {
      tester.view.physicalSize = view;

      if (section == 'gallery') {
        for (final look in looks) {
          for (final q in const [0.2, 0.5, 0.8]) {
            final g = bareGame(Random(1))
              ..heroSkills = false
              ..monsterSkills = false
              ..skills = false;
            g
              ..startWave()
              ..queue.clear();
            held(g, const Point(600.0, 70.0)); // keeps the wave on
            b.state = g;
            await frames(30); // the book shuts
            final at = Point(g.cam + g.viewW / 2, 70.0);
            // A knight and an orc standing in it, for the units' pixels.
            placeNow(g, 'knight', 0, 1)
              ..pos = at - Point(look.radius * 0.6, 4.0)
              ..cd = hold;
            held(g, at + Point(look.radius * 0.35, 6.0));
            await frames(2);
            look.put(g, at, g.t, q);
            b.speed = 0; // the board ticks nothing while the shot is taken (a pause would dim the field)
            await frames(1);
            final name = '$size-${look.name}-p${(q * 10).round()}';
            await shot(name);
            crop(name, at, look.radius);
            b.speed = 1;
          }
        }
      }

      if (section == 'tells') {
        for (final skill in [MonsterSkill.howl, MonsterSkill.earthshaker, MonsterSkill.roar, MonsterSkill.deathNova,
            MonsterSkill.curseOfFrailty, MonsterSkill.lastRites]) {
          for (final done in const [0.3, 0.8]) {
            final g = bareGame(Random(1))
              ..heroSkills = false
              ..skills = false;
            g
              ..startWave()
              ..queue.clear();
            held(g, const Point(600.0, 70.0)); // keeps the wave on
            b.state = g;
            await frames(30);
            final at = Point(g.cam + g.viewW / 2, 70.0);
            placeNow(g, 'knight', 0, 1)
              ..pos = at - const Point(26.0, 4.0)
              ..cd = hold;
            final u = g.monster(skill.type, Tier.boss, at)
              ..entered = true
              ..cd = hold
              ..summonCd = hold;
            g
              ..units.add(u)
              ..addEffect(u, Status.slow, hold, k: 0);
            u
              ..winding = skill
              ..windUntil = g.t + skill.wind * (1 - done);
            g.monsterCasts.add((u, skill)); // its banner and a moment's red edges, as in play
            await frames(2);
            b.speed = 0;
            await frames(1);
            final name = '$size-tell-${skill.name}-p${(done * 10).round()}';
            await shot(name);
            crop(name, at, windReachOf(u, skill));
            b.speed = 1;
          }
        }
      }

      if (section == 'fight') {
        final save = jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>;
        final g = b.state = Game.fromJson(save, Random(7), Random(107), Random(307)).boardRules()..loot = Random(207);
        await frames(40);
        for (var i = 0; i < 4 && b.messageBox != Rect.zero; i++) {
          await tester.tapAt(b.messageBox.center);
          await frames(2);
        }
        b.showMessage('', time: 0);
        g.startWave();
        await frames(30); // the book shuts
        Zone? well;
        final shots = <String>{};
        for (var i = 0; i < 30 * 200 && g.waveActive && !g.over && shots.length < 3; i++) {
          g.tick(1 / 30);
          g.monsterCasts.clear(); // no foe banner over the field
          if (i % 10 == 0) await frames(1);
          well ??= g.zones.where((z) => z.look == ZoneLook.singularity).firstOrNull;
          final w = well;
          if (w == null) continue;
          final age = g.t - w.since;
          final collapse = g.rings.where((r) => r.look == RingLook.implode && g.t - r.since >= 0.12).firstOrNull;
          String? name;
          if (age >= 1.0 && !shots.contains('well-1s')) name = 'well-1s';
          if (age >= 2.0 && !shots.contains('well-2s')) name = 'well-2s';
          if (collapse != null && !shots.contains('implode')) name = 'implode';
          if (name == null) continue;
          shots.add(name);
          b.speed = 0;
          await frames(2);
          await shot('$size-fight-$name');
          crop('$size-fight-$name', w.at, w.radius);
          p('WELL r ${w.radius} at ${w.at} t ${g.t.toStringAsFixed(2)} age ${age.toStringAsFixed(2)} in it '
              '${g.enemies.where((o) => o.alive && w.covers(o)).length} cam ${g.cam.toStringAsFixed(1)}');
          b.speed = 1;
        }
        p('FIGHT $size wave ${g.wave} t ${g.t.toStringAsFixed(1)} shots $shots');
      }
    }
  });
}
