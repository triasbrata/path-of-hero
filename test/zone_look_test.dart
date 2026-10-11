// The zones' and rings' looks at the units' pixel size (docs/ui-hud.md "Awakening skills" and "A monster's skill";
// decisions-log 177, amending 173): a ground circle's ring round a reach wider than twice the circle is laid in dashes
// of the circle's own ring at the units' pixel size ([reachDashes]), a wind-up's end to end ([closeDashes]);
// Singularity's well, its collapse, the wide rings and Skyfall's landing shadow draw on a booted board all through
// their lives; and drawing them changes nothing in the fight.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hero_skill_helpers.dart';

/// tiny_fx_summon.png's ring: its middle in its 100 px frame, and its visible box there (32 x 13 px).
const mid = Offset(52, 56.5), ringBox = Rect.fromLTRB(36, 50, 68, 63);

/// Ground circles are drawn scaled up to this many times their size; wider reaches get the dashes.
const stretchMax = 2.0;

/// The reaches over twice the circle the game's looks use: Singularity's wells from Bangkit 2 (a well's ring is
/// dashed at every Bangkit, its first's at exactly twice), Holy Shield's, Howl's, Earthshaker's and Roar's, Death
/// Nova's, and a wide Arrow Rain.
final wide = [...singularityK.radius.skip(1), ward.reach, howlK.reach, earthshakerK.reach, roarK.reach, deathNovaK.reach, 44.0];

Future<TdGame> boot(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1266, 713)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final game = TdGame();
  await tester.pumpWidget(GameWidget(game: game));
  for (var i = 0; i < 3000 && !game.isLoaded; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(game.isLoaded, isTrue);
  game.board.welcome = null;
  return game;
}

void main() {
  test('every wide reach is over twice the circle (so it is dashed) and every dash is the ring\'s own pixels at the units\' '
      'size: 1 world unit a sprite px, on the frame\'s pixels, on its ring', () {
    for (final r in wide) {
      expect(2 * r / 32, greaterThan(stretchMax), reason: 'reach $r');
    }
    for (final r in [16.0, ...singularityK.radius, ...wide, 72.0]) {
      final dashes = reachDashes(r);
      expect(dashes, hasLength(20));
      for (final (from, to) in dashes) {
        expect(to.width, closeTo(from.width, 1e-9), reason: 'reach $r: not stretched');
        expect(to.height, closeTo(from.height, 1e-9), reason: 'reach $r: not stretched');
        expect((from.left, from.top), (from.left.roundToDouble(), from.top.roundToDouble()), reason: 'on the frame\'s pixels');
        expect(ringBox.overlaps(from), isTrue, reason: 'reach $r: $from on the ring');
      }
    }
  });

  test('at the circle\'s own size the dashes lie where its frame draws the ring; wider, they are pushed out to the reach '
      'all round, evenly spaced', () {
    for (final (from, to) in reachDashes(16)) {
      expect(to, from.shift(-mid));
    }
    for (final r in {...singularityK.radius, ...wide}) {
      final at = reachDashes(r).map((d) => d.$2).toList(), flat = r * 6.5 / 16;
      // The window is a pixel wider than the ring's outer row at each end.
      expect(at.map((t) => t.right).reduce(max), closeTo(r, 1.5), reason: 'reach $r: right');
      expect(at.map((t) => t.left).reduce(min), closeTo(-r, 1.5), reason: 'reach $r: left');
      expect(at.map((t) => t.bottom).reduce(max), closeTo(flat, 1.5), reason: 'reach $r: front');
      expect(at.map((t) => t.top).reduce(min), closeTo(-flat, 1.5), reason: 'reach $r: back');
      final gaps = [for (var i = 0; i < at.length; i++) (at[(i + 1) % at.length].center - at[i].center).distance];
      expect(gaps.reduce(max) / gaps.reduce(min), lessThan(1.5), reason: 'reach $r: gaps $gaps');
    }
    // A whole turn puts every dash back where it was.
    final once = reachDashes(48, turn: 1), none = reachDashes(48);
    for (var i = 0; i < 20; i++) {
      expect((once[i].$2.center - none[i].$2.center).distance, lessThan(1e-6));
    }
  });

  test('a wind-up\'s reach over twice the circle is ringed whole: its 4-unit dashes about 4 apart all round (end to '
      'end), never fewer than a plain ring\'s', () {
    for (final r in [howlK.reach, earthshakerK.reach, roarK.reach, deathNovaK.reach, curseOfFrailtyK.reach, lastRitesK.reach]) {
      final n = closeDashes(r, 4), at = [for (final (_, to) in reachDashes(r, count: n)) to.center];
      final gaps = [for (var i = 0; i < n; i++) (at[(i + 1) % n] - at[i]).distance];
      expect(gaps.reduce(max), lessThan(5.5), reason: 'reach $r: $n dashes, gaps $gaps');
      expect(gaps.reduce(min), greaterThan(2), reason: 'reach $r: $n dashes, gaps $gaps');
    }
    expect(closeDashes(16, 4), 20);
  });

  testWidgets('the wide looks draw on a booted board all through their lives: the wells at every Bangkit, the collapse, '
      'the wide rings and zones, and Skyfall\'s landing shadow', (tester) async {
    final b = (await boot(tester)).board;
    final g = bareGame(Random(1))
      ..heroSkills = false
      ..monsterSkills = false
      ..skills = false;
    g
      ..startWave()
      ..queue.clear();
    final orc = foeAt(g, 'orc', const Point(400.0, 70.0)) // keeps the wave on
      ..hp = 1e5
      ..busyUntil = double.negativeInfinity // drawn standing, not rising
      ..cd = hold;
    g.addEffect(orc, Status.slow, hold, k: 0);
    b.state = g;
    await tester.pump(const Duration(milliseconds: 16));
    final archer = placeNow(g, 'archer', 0, 0)..cd = hold;
    final axeman = placeNow(g, 'armored_axeman', 0, 2)..cd = hold;
    final at = Point(g.cam + g.viewW / 2, 70.0), t = g.t;
    for (final (i, r) in singularityK.radius.indexed) {
      g.zones.add(Zone(archer, at, since: t, duration: singularityK.time[i], radius: r, side: Side.enemy, look: ZoneLook.singularity));
      g.rings.add(Ring(at + Point(0.0, 20.0 * i), radius: r, since: t, look: RingLook.implode, duration: singularityK.implode));
    }
    g
      ..zones.add(Zone(archer, at, since: t, duration: skillLook.volley, radius: 44, side: Side.enemy, look: ZoneLook.volley))
      ..zones.add(Zone(archer, at, since: t, duration: 2, radius: 3 * tile, side: Side.troop, look: ZoneLook.slime))
      ..rings.add(Ring(at, radius: ward.reach, since: t, look: RingLook.holy))
      ..rings.add(Ring(at, radius: howlK.reach, since: t, look: RingLook.grey, duration: wideRingTime))
      ..rings.add(Ring(at, radius: deathNovaK.reach, since: t, look: RingLook.dark));
    axeman.move = Carry(axeman.pos, at, t, t + 1.0, lift: 20, look: CarryLook.skyfall, radius: skyfallK.radius.last);
    for (var i = 0; i < 3.6 / 0.05; i++) {
      g.tick(0.05);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull, reason: 'at ${g.t.toStringAsFixed(2)}');
    }
    expect(g.waveActive, isTrue, reason: 'the field was drawn all along');
    expect(g.zones.where((z) => z.look == ZoneLook.singularity), isEmpty, reason: 'every well closed');
  });

  // The w86 save's next wave (as the other looks' tests play it) and the w89 save's (Bangkit-5 wizards: wells open).
  for (final (name, file, board) in [
    ('w86', 'save-20261001-2005-pre-awaken.json', false),
    ('w89', 'save-20261002-2222-w89-sellbug.json', true),
  ]) {
    testWidgets('drawing the zones changes nothing: the $name save\'s next wave from the same seeds ends the same played '
        'headless and drawn every tick', (tester) async {
      final b = (await boot(tester)).board;
      final save = jsonDecode(File('test/fixtures/$file').readAsStringSync()) as Map<String, dynamic>;
      String digest(Game g) => [
            't ${g.t} gold ${g.gold} lives ${g.lives} kills ${g.kills} score ${g.score} log ${g.log.entries.length} cam ${g.cam}',
            for (final u in g.units) '${u.side.name} ${u.type} ${u.tier.name} ${u.alive} ${u.hp} ${u.mp} ${u.pos} ${u.winding}',
          ].join('\n');
      Game fresh() {
        final g = Game.fromJson(save, Random(5), Random(105), Random(305))
          ..loot = Random(205)
          ..slots = Random(405)
          ..draft = Random(505);
        return board ? g.boardRules() : g;
      }

      // The board sets the view's width (which play reads) on the game it holds, and a wave begun drops the save's
      // Pusaka note: the headless game gets both the same way (landing_look_test.dart's).
      final drawn = fresh()..paused = true;
      b.state = drawn;
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      final plain = fresh()..viewW = drawn.viewW;
      for (final g in [plain, drawn]) {
        g.startWave();
        if (g.pusakaSuggested) g.dismissPusakaNote();
      }
      for (var i = 0; i < 30 * 70 && plain.waveActive && !plain.over; i++) {
        plain.tick(1 / 30);
      }
      final wells = <Zone>{}, wideRings = <Ring>{};
      for (var i = 0; i < 30 * 70 && drawn.waveActive && !drawn.over; i++) {
        drawn
          ..paused = false
          ..tick(1 / 30)
          ..paused = true;
        wells.addAll(drawn.zones.where((z) => z.look == ZoneLook.singularity));
        wideRings.addAll(drawn.rings.where((r) => 2 * r.radius / 32 > stretchMax));
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }
      drawn.paused = false;
      // ignore: avoid_print
      print('$name: wells drawn ${wells.length}, wide rings ${wideRings.length} (${{for (final r in wideRings) r.look.name}}), '
          't ${drawn.t.toStringAsFixed(1)}');
      if (name == 'w89') expect(wells, isNotEmpty, reason: 'its wizards opened wells');
      expect(digest(drawn), digest(plain));
    });
  }
}
