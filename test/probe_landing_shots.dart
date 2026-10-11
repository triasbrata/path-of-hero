// The champions' landing looks seen (ui-hud.md "A monster's skill"): offscreen shots into
// <probe root>/shots/landing/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_landing_shots.dart"]` with the worktree as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir); the dice are seeded.
//
// At 1266x713 and 412x860 (`desk-` / `phone-`), a small army against a high elite, a mini boss and a boss
// (`-high`, `-mini`, `-boss`) caught just after the cast lands: Volley, Shield Up, Brutal Swing, Bulwark, Blade Dance;
// each beside a troop skill's look drawn from the same kind of sheet at the same moment (Arrow Rain's zone, Hold Fast's
// shield, Circle Slash's blade, Crushing Blow's dust), and as `<name>-zoom`, a 3x crop round the caster. Then `fight-<n>`:
// the first landings of the five in the owner's wave-86 save's next wave (the fixture), played at a fixed step.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/landing');

/// The five skills with a landing look of their own.
const landings = [MonsterSkill.volley, MonsterSkill.shieldUp, MonsterSkill.brutalSwing, MonsterSkill.bulwark, MonsterSkill.bladeDance];

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// An army in the deploy zone and, in front of it, a monster of [skill]'s type and [tier] about to land [skill] (in
/// reach of the front line for the melee ones, further out for the rest), two plain orcs beside it (and one just
/// behind a Shield Up's caster, which a mini boss's ward covers too).
(Game, Unit, Map<String, Unit>) scene(MonsterSkill skill, Tier tier) {
  final g = bareGame(Random(3))
    ..skills = false
    ..heroSkills = false;
  final army = {
    for (final (type, c, r) in [
      ('soldier', 5, 3),
      ('knight', 5, 4),
      ('lancer', 4, 5),
      ('archer', 3, 2),
      ('wizard', 3, 6),
      ('priest', 2, 4),
      ('armored_axeman', 4, 2),
    ])
      type: placeNow(g, type, c, r)..cd = hold,
  };
  g
    ..startWave()
    ..queue.clear();
  final front = army.values.map((o) => o.pos.x).reduce(max);
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

  final gap = switch (skill) { MonsterSkill.brutalSwing || MonsterSkill.bladeDance || MonsterSkill.bulwark => 10.0, _ => 30.0 };
  final u = foe(skill.type, tier, Point(front + gap, 4 * tile))..dir = -1;
  foe('orc', Tier.normal, u.pos + const Point(12.0, -18.0));
  foe('orc', Tier.normal, u.pos + const Point(16.0, 16.0)).hp *= 0.4;
  if (skill == MonsterSkill.shieldUp) foe('orc', Tier.normal, u.pos + const Point(9.0, 5.0));
  u
    ..winding = skill
    ..windUntil = g.t + 0.03
    ..skillAt = g.t // its clocks run from this wind-up, so it begins nothing else after it lands
    ..bossSkillAt = g.t
    ..castAt = g.t;
  g.monsterCasts.add((u, skill));
  return (g, u, army);
}

/// The troop skill's look shown beside [skill]'s landing, from the same kind of sheet, begun now.
void beside(Game g, MonsterSkill skill, Unit u, Map<String, Unit> army) {
  switch (skill) {
    case MonsterSkill.volley:
      g.zones.add(Zone(army['archer']!, u.pos + const Point(14.0, 0.0),
          since: g.t, duration: skillLook.volley, radius: 1.5 * tile, side: Side.enemy, look: ZoneLook.volley));
    case MonsterSkill.shieldUp:
      g.rings.add(Ring.over(army['soldier']!, radius: 12, since: g.t, look: RingLook.brace, duration: skillLook.brace));
    case MonsterSkill.brutalSwing || MonsterSkill.bladeDance:
      g.rings.add(Ring.over(army['lancer']!, radius: slash.reach, since: g.t, look: RingLook.slash, duration: skillLook.slash));
    default:
      final axe = army['armored_axeman']!;
      g.rings.add(Ring(axe.pos, radius: slam.reach, since: g.t, look: RingLook.crack, duration: skillLook.crack));
  }
}

/// How many 16 ms frames after the landing each look is shot: partway, where it reads most.
const shotAfter = {
  MonsterSkill.volley: 6,
  MonsterSkill.shieldUp: 14,
  MonsterSkill.brutalSwing: 8,
  MonsterSkill.bulwark: 6,
  MonsterSkill.bladeDance: 6,
};

void main() {
  testWidgets('landing shots', (tester) async {
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

    Future<ui.Image> shot(String name) async {
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
      final (zw, zh) = tag == 'desk' ? (300.0, 170.0) : (200.0, 120.0);
      for (final skill in landings) {
        for (final (rank, tier) in const [('high', Tier.highElite), ('mini', Tier.miniBoss), ('boss', Tier.boss)]) {
          final (g, u, army) = scene(skill, tier);
          b.state = g;
          await frames(tester, 1);
          if (b.messageBox != Rect.zero) {
            await tester.tapAt(b.messageBox.center); // the tide's news over the field
            await frames(tester, 1);
          }
          for (var i = 0; i < 20 && u.winding != null; i++) {
            await frames(tester, 1);
          }
          expect(u.winding, isNull, reason: '${skill.title} landed');
          beside(g, skill, u, army);
          await frames(tester, shotAfter[skill]!);
          final name = '$tag-${skill.name}-$rank';
          final img = await shot(name);
          // ignore: avoid_print
          print('$name: caster at ${b.toScreen(u.pos.x, u.pos.y)} looks ${[for (final r in g.rings) r.look.name]} '
              'bursts ${[for (final s in g.shots) s.target.type]}');
          await zoom(img, b.toScreen(u.pos.x - 16, u.pos.y), '$name-zoom', w: zw, h: zh);
        }
      }

      // The fixture's next wave, at a fixed step: the first landings of the five, shot a few frames in.
      final save0 = jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>;
      final g = b.state = Game.fromJson(save0, Random(5), Random(105), Random(305))..loot = Random(205);
      g.startWave();
      await frames(tester, 2);
      if (b.messageBox != Rect.zero) {
        await tester.tapAt(b.messageBox.center); // the save's Pusaka note over the field
        await frames(tester, 1);
      }
      var n = 0;
      final seen = <Unit>{};
      for (var i = 0; i < 30 * 90 && n < 3 && !g.over; i++) {
        final winding = {for (final u in g.enemies) if (u.alive && landings.contains(u.winding)) u: u.winding!};
        g.tick(1 / 30);
        g.heroCasts.clear();
        final landed = winding.entries.where((e) => e.key.winding == null && !seen.contains(e.key)).firstOrNull;
        if (landed == null) continue;
        seen.add(landed.key);
        n++;
        await frames(tester, shotAfter[landed.value]!); // the board plays on: the look partway
        final u = landed.key, name = '$tag-fight-$n';
        final img = await shot(name);
        // ignore: avoid_print
        print('$name: t ${g.t.toStringAsFixed(1)} ${u.type} ${u.tier.name} ${landed.value.title} at ${b.toScreen(u.pos.x, u.pos.y)}');
        await zoom(img, b.toScreen(u.pos.x - 16, u.pos.y), '$name-zoom', w: zw, h: zh);
      }
    }
    await frames(tester, 4);
  });
}
