// A monster skill's first-sighting splash (lib/foe_splash.dart, ui-hud.md "Foe splash"): offscreen shots of the owner's
// wave-86 save (the fixture) on wave 60, a boss wave, into <probe root>/shots/foe-splash/ (`OUT`). A probe, not
// part of the suite (no `_test.dart`): queue `["test", "test/probe_foe_splash_shots.dart"]` with the worktree as `dir`.
// It never touches the real save (flutter_test_config.dart's temp dir); the dice are seeded and the play is at a fixed
// step, so a rerun gives the same shots.
//
// It writes, at 1266x713 (`desk-`) and 412x860 (`phone-`): bulwark (an armored orc high elite's Bulwark), curse (a
// necromancer high elite's Curse of Frailty) and moment (the wave's boss's moment), each with a 2x crop of the panel
// (`-zoom`). Each scene loads the save afresh, plays 20 s of the wave (no casts kept: no banner, no splash), then the
// caster joins the monsters at the front and winds up.
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

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/foe-splash');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The fixture: the owner's w86 save from before the Pusaka (its five bound by default when loaded).
Game load() {
  final save = jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>;
  return Game.fromJson(save, Random(seed), Random(seed + 100), Random(seed + 300))..loot = Random(seed + 200);
}

void main() {
  for (final (name, size) in [('desk', const Size(1266, 713)), ('phone', const Size(412, 860))]) {
    testWidgets('foe splash shots ($name)', (tester) async {
      tester.view
        ..physicalSize = size
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

      Future<ui.Image> grab() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        return (await tester.runAsync(() => boundary.toImage()))!;
      }

      Future<void> save(ui.Image img, String file) async {
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name-$file.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        // ignore: avoid_print
        print('wrote $out/$name-$file.png ${img.width}x${img.height}');
      }

      /// [src] cut to [crop] and scaled 2x, pixel for pixel.
      Future<void> zoom(ui.Image src, Rect crop, String file) async {
        final c = crop.intersect(Offset.zero & size);
        final img = await tester.runAsync(() {
          final rec = ui.PictureRecorder();
          Canvas(rec).drawImageRect(src, c, Offset.zero & (c.size * 2), Paint()..filterQuality = FilterQuality.none);
          return rec.endRecording().toImage((c.width * 2).round(), (c.height * 2).round());
        });
        await save(img!, file);
      }

      /// The save on wave 60, [seconds] of it played at a fixed step with no casts kept; then [caster] (made from the
      /// game, or the wave's own boss) winds up [skill] and the splash pops in: the screen and its 2x crop.
      Future<void> scene(String file, MonsterSkill skill, Unit Function(Game g) caster, {double seconds = 20}) async {
        b.guideSeen = null; // no splash while it plays
        final g = b.state = load()..wave = 59;
        await frames(tester, 30);
        b.showMessage('', time: 0); // the save's one-time notes go
        g.startWave();
        await frames(tester, 2);
        for (var t = 0.0; t < seconds; t += 0.5) {
          for (var i = 0; i < 15 && !g.over; i++) {
            g.tick(1 / 30);
          }
          g.heroCasts.clear();
          g.monsterCasts.clear();
          await frames(tester, 1);
        }
        b.guideSeen = {};
        final u = caster(g);
        g.monsterCasts.add((u, skill));
        await frames(tester, 25); // 0.4 s: past the pop in
        final f = b.foeSplash;
        // ignore: avoid_print
        print('$file: ${f?.title} / ${f?.line} / ${f?.lines} / ${f?.hint} at ${f?.panel}; caster ${u.type} ${u.tier.name} at ${u.pos}');
        final img = await grab();
        await save(img, file);
        if (f != null) await zoom(img, f.panel.inflate(16), '$file-zoom');
      }

      /// A monster of [type] and [tier] beside the front monster (the one nearest the base), so it stands in the fight.
      Unit beside(Game g, String type, Tier tier) {
        final front = g.enemies.where((u) => u.alive).fold<Unit?>(null, (a, u) => a == null || u.pos.x < a.pos.x ? u : a);
        final at = front == null ? Point(g.cam + g.viewW * 0.6, 60.0) : Point(front.pos.x + 14, front.pos.y);
        return g.monster(type, tier, at);
      }

      await scene('bulwark', MonsterSkill.bulwark, (g) => beside(g, 'armored_orc', Tier.highElite));
      await scene('curse', MonsterSkill.curseOfFrailty, (g) => beside(g, boss, Tier.highElite));
      await scene('moment', MonsterSkill.earthshaker, (g) {
        final big = g.enemies.where((u) => u.alive && u.tier == Tier.boss && u.type == 'armored_orc').firstOrNull;
        return big ?? beside(g, 'armored_orc', Tier.boss);
      }, seconds: 30);
    });
  }
}
