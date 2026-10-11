// The wind-up tells seen (ui-hud.md "A monster's skill"): offscreen shots into <probe root>/shots/wind-tell/
// (`OUT`). A probe, not part of the suite (no `_test.dart`): queue `["test", "test/probe_wind_tell_shots.dart"]` with
// the worktree as `dir`. It never touches the real save (flutter_test_config.dart's temp dir); the dice are seeded.
//
// At 1266x713 and 412x860 (`desk-` / `phone-`), a small army against a monster caught partway through its wind-up,
// beside the looks the game already draws from the same sheets (a necromancer's summon circle, a frost field, a hit
// burst): War Shout (an area), a mini boss's Volley (its marks, the boss bar's flash), Trample (a lane), Earthshaker (a
// boss's moment: its red edges), Shield Up (at its feet), Curse of Frailty, Mass Mend and Bulwark (their own colours);
// each also as `<name>-zoom`, a 3x crop round the caster. Then `fight-<n>`: the first wind-ups of the owner's wave-86
// save's next wave (the fixture), played at a fixed step.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/wind-tell');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// An army in the deploy zone and, in front of it, a monster of [skill]'s type and [tier] [done] of the way through
/// its wind-up of [skill], two plain orcs beside it, a necromancer's summon circle and a frost field near the troops.
(Game, Unit) scene(MonsterSkill skill, Tier tier, {double done = 0.5}) {
  final g = bareGame(Random(3))
    ..skills = false
    ..heroSkills = false;
  final army = [
    for (final (type, c, r) in [('soldier', 5, 3), ('knight', 5, 5), ('lancer', 4, 4), ('archer', 3, 2), ('wizard', 3, 6), ('priest', 2, 4)])
      placeNow(g, type, c, r)..cd = hold,
  ];
  g
    ..startWave()
    ..queue.clear();
  final front = army.map((o) => o.pos.x).reduce(max);
  Unit foe(String type, Tier tier, Point<double> at) {
    final m = g.monster(type, tier, at)
      ..entered = true
      ..cd = hold
      ..summonCd = hold;
    g
      ..units.add(m)
      ..addEffect(m, Status.slow, hold, k: 0);
    return m;
  }

  final u = foe(skill.type, tier, Point(front + 34, 4.5 * tile));
  foe('orc', Tier.normal, u.pos + const Point(10.0, -16.0));
  foe('orc', Tier.normal, u.pos + const Point(14.0, 14.0)).hp *= 0.4;
  if (skill == MonsterSkill.massMend) {
    for (final m in g.enemies) {
      m.hp = m.maxHp * 0.4;
    }
  }
  final wind = max(skill.wind, 0.4);
  u
    ..winding = skill
    ..windUntil = g.t + wind * (1 - done);
  g
    ..monsterCasts.add((u, skill))
    ..impacts.add((army.first.pos + const Point(0.0, 30.0), 'summon'))
    ..impacts.add((army[2].pos + const Point(8.0, -2.0), 'hit_orc'))
    ..zones.add(Zone(army.last, army.last.pos + const Point(-6.0, 26.0), since: g.t - 1, duration: 30, radius: 1.5 * tile, side: Side.enemy, look: ZoneLook.frost));
  return (g, u);
}

void main() {
  testWidgets('wind tell shots', (tester) async {
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

    Future<void> save(ui.Image img, String name) async {
      await tester.runAsync(() async {
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
      // ignore: avoid_print
      print('wrote $out/$name.png ${img.width}x${img.height}');
    }

    Future<ui.Image> shot(String name, [int settle = 2]) async {
      await frames(tester, settle);
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = (await tester.runAsync(() => boundary.toImage()))!;
      await save(img, name);
      return img;
    }

    /// [src] cut to a [w]x[h] box round [at] and scaled 3 times, pixel for pixel.
    Future<void> zoom(ui.Image src, Offset at, String name, {double w = 300, double h = 170}) async {
      final crop = Rect.fromCenter(center: at, width: w, height: h).intersect(Offset.zero & Size(src.width.toDouble(), src.height.toDouble()));
      final img = await tester.runAsync(() {
        final rec = ui.PictureRecorder();
        Canvas(rec).drawImageRect(src, crop, Offset.zero & (crop.size * 3), Paint()..filterQuality = FilterQuality.none);
        return rec.endRecording().toImage((crop.width * 3).round(), (crop.height * 3).round());
      });
      await save(img!, name);
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860))]) {
      tester.view.physicalSize = size;
      for (final (name, skill, tier, done) in [
        ('war-shout', MonsterSkill.warShout, Tier.highElite, 0.6),
        ('volley', MonsterSkill.volley, Tier.miniBoss, 0.5),
        ('trample', MonsterSkill.trample, Tier.highElite, 0.5),
        ('moment', MonsterSkill.earthshaker, Tier.boss, 0.3),
        ('shield-up', MonsterSkill.shieldUp, Tier.highElite, 0.6),
        ('curse', MonsterSkill.curseOfFrailty, Tier.boss, 0.6),
        ('mass-mend', MonsterSkill.massMend, Tier.highElite, 0.6),
        ('bulwark', MonsterSkill.bulwark, Tier.miniBoss, 0.6),
      ]) {
        final (g, u) = scene(skill, tier, done: done);
        b.state = g;
        await frames(tester, 2);
        if (b.messageBox != Rect.zero) {
          await tester.tapAt(b.messageBox.center); // the tide's news over the field
          u.windUntil += 0.05;
          await frames(tester, 1);
        }
        final img = await shot('$tag-$name', 1);
        // ignore: avoid_print
        print('$tag $name: cam ${g.cam.toStringAsFixed(1)} view ${g.viewW.toStringAsFixed(1)} caster at ${b.toScreen(u.pos.x, u.pos.y)} '
            'winding ${u.winding?.title} marks ${[for (final o in g.windTargetsOf(u)) o.type]}');
        await zoom(img, b.toScreen(u.pos.x - 20, u.pos.y), '$tag-$name-zoom', w: tag == 'desk' ? 300 : 200, h: tag == 'desk' ? 170 : 120);
      }

      // The fixture's next wave, at a fixed step: the first three wind-ups caught partway.
      final save0 = jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>;
      final g = b.state = Game.fromJson(save0, Random(5), Random(105), Random(305))..loot = Random(205);
      g.startWave();
      await frames(tester, 2);
      var n = 0;
      final seen = <Unit>{};
      for (var i = 0; i < 30 * 90 && n < 3 && !g.over; i++) {
        g.tick(1 / 30);
        g.heroCasts.clear();
        final u = g.enemies.where((u) => u.alive && u.winding != null && !seen.contains(u) && windTells[u.winding] != WindTell.none).where((u) {
          final s = u.winding!;
          return s.wind > 0 && (u.windUntil - g.t) / s.wind < 0.6;
        }).firstOrNull;
        if (u == null) continue;
        seen.add(u);
        n++;
        final img = await shot('$tag-fight-$n', 1);
        // ignore: avoid_print
        print('$tag fight $n: t ${g.t.toStringAsFixed(1)} ${u.type} ${u.tier.name} ${u.winding?.title} at ${b.toScreen(u.pos.x, u.pos.y)} '
            'marks ${[for (final o in g.windTargetsOf(u)) o.type]}');
        await zoom(img, b.toScreen(u.pos.x - 20, u.pos.y), '$tag-fight-$n-zoom', w: tag == 'desk' ? 300 : 200, h: tag == 'desk' ? 170 : 120);
      }
    }
    await frames(tester, 4);
  });
}
