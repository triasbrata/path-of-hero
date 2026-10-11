// A monster champion's skill banner (lib/foe_cut_in.dart, ui-hud.md "A foe's skill banner"): offscreen shots of the
// owner's wave-86 save (the fixture) on wave 60 (a mini boss and the boss), into <probe root>/shots/foe-banner/
// (`OUT`). A probe, not part of the suite (no `_test.dart`): queue `["test", "test/probe_foe_cut_shots.dart"]` with the
// worktree as `dir`. It never touches the real save (flutter_test_config.dart's temp dir); the dice are seeded and the
// play is at a fixed step, so a rerun gives the same shots.
//
// It writes, at 1266x713 (`desk-`) and 412x860 (`phone-`): together (the wave's first champion banner with a Hero's
// cut-in band and the Grail's plate showing at once), miniboss (a mini boss's banner), moment (the boss's moment band),
// each with a 2x crop of the banner (`-zoom`); and desk-hero-splash, the Hero splash, to set beside them.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/foe-banner');
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
    testWidgets('foe banner shots ($name)', (tester) async {
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

      /// The banner showing, a frame after its slide in: the screen, and its 2x crop.
      Future<void> shotBanner(String file) async {
        await frames(tester, 22); // 0.35 s: past the slide in (15% of 1.4 s)
        final cut = b.foeCutIn;
        // ignore: avoid_print
        print('$file: ${cut?.title} / ${cut?.line} band ${cut?.band} at ${cut?.at} title ${cut?.titleSize}');
        final img = await grab();
        await save(img, file);
        if (cut != null) await zoom(img, cut.at.inflate(24), '$file-zoom');
      }

      // Plays [seconds] of the wave at a fixed step, a frame every half second; stops right after the frame on which
      // [until] holds.
      Future<void> play(Game g, double seconds, {bool Function()? until}) async {
        for (var t = 0.0; t < seconds; t += 0.5) {
          for (var i = 0; i < 15 && !g.over; i++) {
            g.tick(1 / 30);
          }
          g.heroCasts.clear();
          await frames(tester, 1);
          if (until?.call() ?? false) return;
        }
      }

      final g = b.state = load()..wave = 59;
      await frames(tester, 30);
      b.showMessage('', time: 0); // the save's one-time notes go: they would lie over the Hero's band
      g.startWave();
      await frames(tester, 2);
      // The wave's first champion banner, and with it a Hero's cut-in and the Grail's plate.
      await play(g, 90, until: () => b.foeCutShowing != null);
      // ignore: avoid_print
      print('first banner at t ${g.t.toStringAsFixed(1)}: ${b.foeCutShowing?.$2.title} ${b.foeCutShowing?.$3.name}');
      final hero = g.troops.where((u) => u.alive && u.hero && u.heroSkill != null).firstOrNull;
      if (hero != null) g.heroCasts.add((hero, hero.heroSkill!));
      g.grailFirst = g.troops.where((u) => u.alive).firstOrNull;
      await frames(tester, 1);
      // ignore: avoid_print
      print('hero cut-in ${hero?.name}; grail: ${b.grailCutIn}');
      await shotBanner('together');

      // A mini boss's banner (the wave's own, else one made for the shot), then the boss's moment.
      await frames(tester, 120); // the first one's time is over
      final mini = g.enemies.where((u) => u.alive && u.tier == Tier.miniBoss).firstOrNull ??
          g.monster('orc', Tier.miniBoss, Point(g.cam + 300, 60));
      final miniSkill = monsterSkillsOf(mini).where((s) => s.rank == MonsterRank.miniBoss).firstOrNull ?? MonsterSkill.groundSlam;
      g.monsterCasts.add((mini, miniSkill));
      await frames(tester, 1);
      await shotBanner('miniboss');
      await frames(tester, 120);
      final big = g.enemies.where((u) => u.alive && u.tier == Tier.boss).firstOrNull ?? g.monster(boss, Tier.boss, Point(g.cam + 300, 60));
      final moment = MonsterSkill.values.firstWhere((s) => s.rank == MonsterRank.moment && s.type == big.type);
      g.monsterCasts.add((big, moment));
      await frames(tester, 1);
      await shotBanner('moment');

      if (name == 'desk') {
        // The Hero splash, to set beside them.
        await frames(tester, 120);
        if (hero != null) {
          g.heroMade.add(hero);
          await frames(tester, 40);
          await save(await grab(), 'hero-splash');
        }
      }
    });
  }
}
