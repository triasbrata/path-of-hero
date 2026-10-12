// The Pusaka's ring in the sprites' pixels (decisions-log 325, ui-hud.md "The Pusaka in battle"): offscreen shots and a
// frame-time check on the owner's wave-30 save (a copy, `SAVE`: God's Thunder on the archers in lemon, five Pusaka
// without a colour of their own in cream). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_pixel_rings.dart", "--dart-define=TAG=after"]` with the worktree, and the same with a `git
// archive` mirror of main (this file copied in, `TAG=before`), to look at the two side by side. It reads the save copy
// only and never touches the real save (flutter_test_config.dart's temp dir); the dice are seeded and the play is at a
// fixed step, so the two runs show the same moments.
//
// It writes into `OUT`/<TAG>/, at 1600x947 and 915x412. `SECTION=gallery`: each shape alone on a bare field (gallery-a
// between waves: Holy Shield's and Hold Fast's guards, a Hero's halo, a dragged archer's reach; gallery-b with a monster
// on: Spear Wall's brace, a slow and a Barrier, Impale's dashed ring) and a close-up of each. `SECTION=fight`: 8 s into
// the save's wave, field-<size> (the whole frame) and 6x close-ups round a plain troop (plain-<size>), a Hero
// (hero-<size>) and an awakened troop (awake-<size>), each of a bound type, and the field's other shapes put on for one
// frame (others-<size>); then at 1600x947 40 s of the wave stepped at 30 fps (`Board.update`), each frame's drawing
// (`Board.render` into a picture) timed, every 10th also rasterised and timed: the mean, median, 95th percentile and
// worst, and how many rings a frame drew. Without `SECTION`, both.
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

const save = String.fromEnvironment('SAVE', defaultValue: '$probeRoot/shots/mage-fx/save-w30-copy.json');
const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/pixel-rings');
const tag = String.fromEnvironment('TAG', defaultValue: 'after');

/// What to shoot: `fight` (the save's wave, its close-ups and the frame time), `gallery` (each shape alone) or `all`.
const section = String.fromEnvironment('SECTION', defaultValue: 'all');

String stats(List<double> ms) {
  if (ms.isEmpty) return 'none';
  final s = [...ms]..sort();
  double at(double q) => s[min(s.length - 1, (q * s.length).floor())];
  return 'n ${s.length} mean ${(s.reduce((a, b) => a + b) / s.length).toStringAsFixed(2)} p50 ${at(0.5).toStringAsFixed(2)} '
      'p95 ${at(0.95).toStringAsFixed(2)} max ${s.last.toStringAsFixed(2)} ms';
}

void main() {
  testWidgets('pixel rings', (tester) async {
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
    final json = jsonDecode(File(save).readAsStringSync()) as Map<String, dynamic>;

    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> write(ui.Image img, String name) async {
      await tester.runAsync(() async {
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$tag/$name.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
      // ignore: avoid_print
      print('wrote $out/$tag/$name.png ${img.width}x${img.height}');
    }

    /// [src] cut to [crop] and scaled [k] times, pixel for pixel.
    Future<void> zoom(ui.Image src, Rect crop, double k, String name) async {
      final img = await tester.runAsync(() {
        final rec = ui.PictureRecorder();
        Canvas(rec).drawImageRect(src, crop, Offset.zero & (crop.size * k), Paint()..filterQuality = FilterQuality.none);
        return rec.endRecording().toImage((crop.width * k).round(), (crop.height * k).round());
      });
      await write(img!, name);
    }

    Game load() {
      final g = Game.fromJson(json, Random(30), Random(130), Random(330))
        ..loot = Random(230)
        ..slots = Random(430);
      return g;
    }

    Future<void> dismissNotes() async {
      await frames(1);
      if (b.messageBox != Rect.zero) {
        await tester.tapAt(b.messageBox.center); // the save's notes over the field
        await frames(1);
      }
    }

    // The gallery: each shape alone on a bare field at the window's size, between waves (Holy Shield's and Hold Fast's
    // guards, a Hero's halo, a dragged archer's reach over a free cell), then with a monster on (Spear Wall's brace, a
    // slow and a Barrier, Impale's dashed ring and lance). Drawn straight from the board (no step), gallery-a/b-<size>,
    // and a 6x close-up of each, gallery-<what>-<size>.
    for (final size in const [Size(1600, 947), Size(915, 412)]) {
      if (section != 'all' && section != 'gallery') break;
      final name = '${size.width.round()}x${size.height.round()}';
      tester.view.physicalSize = size;
      final g = b.state = Game(Random(1), Random(2)).boardRules()..armyMax = null;
      Unit put(Side side, String type, double col, double row) {
        final at = Point(g.baseX + tile * col, tile * row);
        final u = Unit(side, type, side == Side.troop ? g.statsOf(type) : enemyTypes[type]!, at);
        if (side == Side.troop) {
          u
            ..post = at
            ..entered = true
            ..arriving = false;
        }
        g.units.add(u);
        return u;
      }

      final holy = put(Side.troop, 'knight', 1, 1)
        ..guardUntil = 1e9
        ..guardLook = RingLook.holy;
      final hold = put(Side.troop, 'knight', 1, 3.5)
        ..guardUntil = 1e9
        ..guardLook = RingLook.brace;
      final hero = put(Side.troop, 'knight_templar', 3, 1)..hero = true;
      final lancer = put(Side.troop, 'lancer', 3, 3.5);
      await frames(4);
      final k = b.toScreen(1, 0).dx - b.toScreen(0, 0).dx, view = Offset.zero & size;
      // A free cell the archer could go to, in view, away from the others.
      (int, int)? free;
      for (var c = (g.baseX / tile).floor() + 5; free == null && c < (g.baseX / tile).floor() + 40; c++) {
        for (var r = 1; free == null && r < rows - 1; r++) {
          if (g.canPlace(c, r) && view.deflate(40).contains(b.toScreen(c * tile + tile / 2, r * tile + tile / 2))) free = (c, r);
        }
      }
      final cellMid = free == null ? null : b.toScreen(free.$1 * tile + tile / 2, free.$2 * tile + tile / 2);
      if (cellMid != null) {
        b
          ..dragging = 'archer'
          ..dragAt = Vector2(cellMid.dx, cellMid.dy);
      }

      Future<ui.Image> draw() async => (await tester.runAsync(() {
            final rec = ui.PictureRecorder();
            b.render(Canvas(rec));
            return rec.endRecording().toImage(size.width.toInt(), size.height.toInt());
          }))!;

      Future<void> closeUp(ui.Image shot, Offset feet, double up, double half, double zoomBy, String what) async {
        final crop = Rect.fromLTWH(feet.dx - half * k, feet.dy - (up + 6) * k, 2 * half * k, (up + 12) * k).intersect(view);
        await zoom(shot, Rect.fromLTRB(crop.left.floorToDouble(), crop.top.floorToDouble(), crop.right.ceilToDouble(), crop.bottom.ceilToDouble()),
            zoomBy, 'gallery-$what-$name');
      }

      Offset feetOf(Unit u) => b.toScreen(u.pos.x, u.pos.y + 5);
      final a = await draw();
      await write(a, 'gallery-a-$name');
      await closeUp(a, feetOf(holy), 22, 14, 6, 'guard-holy');
      await closeUp(a, feetOf(hold), 22, 14, 6, 'guard-hold');
      await closeUp(a, feetOf(hero), 28, 18, 6, 'halo');
      if (cellMid != null) await closeUp(a, cellMid, 66, 66, 3, 'reach');
      b
        ..dragging = null
        ..dragAt = null;
      // A wave on: monsters on the field.
      final foe = put(Side.enemy, 'werebear', 7, 1.5)
        ..effects[Status.slow] = Effect(1e9, 0.5, bad: true)
        ..shield = 100;
      final pinned = put(Side.enemy, 'orc', 6, 4)..effects[Status.impaled] = Effect(1e9, 0, by: lancer, bad: true);
      lancer.brace = Brace(1e9);
      final bShot = await draw();
      await write(bShot, 'gallery-b-$name');
      await closeUp(bShot, feetOf(lancer), 22, 16, 6, 'brace');
      await closeUp(bShot, feetOf(foe), 26, 16, 6, 'slow-barrier');
      await closeUp(bShot, feetOf(pinned), 24, 16, 6, 'impale');
      // ignore: avoid_print
      print('$name gallery: zoom $k, reach cell $free, braced ${g.braced(lancer)}, impaled ${g.under(pinned, Status.impaled)}');
    }

    for (final size in const [Size(1600, 947), Size(915, 412)]) {
      if (section != 'all' && section != 'fight') break;
      final name = '${size.width.round()}x${size.height.round()}';
      tester.view.physicalSize = size;
      final g = b.state = load();
      await dismissNotes();
      g.startWave();
      for (var t = 0.0; t < 8; t += 0.5) {
        for (var i = 0; i < 15 && !g.over; i++) {
          g.tick(1 / 30);
        }
        g.heroCasts.clear();
        await frames(1);
      }
      await frames(2);
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final shot = (await tester.runAsync(() => boundary.toImage()))!;
      await write(shot, 'field-$name');
      final bound = {for (final p in g.pusaka.values) ?p.type};
      final k = b.toScreen(1, 0).dx - b.toScreen(0, 0).dx;
      // ignore: avoid_print
      print('$name: zoom $k screen px a world unit; bound ${{for (final MapEntry(key: r, value: p) in g.pusaka.entries) if (p.type != null) r.name: p.type}}');
      final view = Offset.zero & size;
      // Where a troop's feet are drawn on the screen: at its drawn body (body_look.dart), not its game position.
      Offset feetOf(Unit u) {
        final p = b.drawnAt(u);
        return b.toScreen(p.x, p.y + 5);
      }

      bool shows(Unit u) => u.alive && bound.contains(u.type) && view.contains(feetOf(u));
      for (final (look, pick) in [
        ('plain', (Unit u) => !u.hero && g.awakenLevel(u.type) == 0),
        ('hero', (Unit u) => u.hero),
        ('awake', (Unit u) => !u.hero && g.awakenLevel(u.type) > 0),
      ]) {
        final u = g.troops.where((u) => shows(u) && pick(u)).firstOrNull;
        if (u == null) {
          // ignore: avoid_print
          print('$name $look: none in view');
          continue;
        }
        // ignore: avoid_print
        print('$name $look: ${u.type} at ${u.pos} (Hero ${u.hero}, Awaken ${g.awakenLevel(u.type)})');
        final feet = feetOf(u);
        final crop = Rect.fromLTWH(feet.dx - 18 * k, feet.dy - 30 * k, 36 * k, 36 * k).intersect(view);
        await zoom(shot, Rect.fromLTRB(crop.left.floorToDouble(), crop.top.floorToDouble(), crop.right.ceilToDouble(), crop.bottom.ceilToDouble()),
            6, '$look-$name');
      }

      // The rings and ellipses still drawn smooth (unchanged, for the owner to decide), put on for one frame: Holy
      // Shield's white guard ring, Spear Wall's brace ring, a monster's effect rings (a slow's ice blue, a Barrier's teal),
      // a Hero's halo, and a dragged troop's reach disc. others-<size>, and a 6x close-up of each (other-<what>-<size>).
      final near = [for (final u in g.troops) if (u.alive && !u.hero && view.contains(feetOf(u))) u];
      final foe = g.units.where((u) => u.side == Side.enemy && u.alive && view.contains(b.toScreen(u.pos.x, u.pos.y + 5))).firstOrNull;
      final hero = g.troops.where((u) => u.alive && u.hero && view.contains(feetOf(u))).firstOrNull;
      if (near.length < 3 || foe == null) {
        // ignore: avoid_print
        print('$name others: too few in view (${near.length} troops, foe $foe)');
        continue;
      }
      final guarded = near[0], braced = near[1], dragged = near[2];
      guarded
        ..guardUntil = g.t + 5
        ..guardLook = RingLook.holy;
      braced.brace = Brace(g.t + 5);
      foe
        ..effects[Status.slow] = Effect(g.t + 5, 0.5, bad: true)
        ..shield = 100;
      final dragAt = feetOf(dragged) - Offset(0, (tile + 5) * k);
      b
        ..dragging = dragged.type
        ..dragAt = Vector2(dragAt.dx, dragAt.dy);
      await frames(2);
      final others = (await tester.runAsync(() => boundary.toImage()))!;
      await write(others, 'others-$name');
      b
        ..dragging = null
        ..dragAt = null;
      for (final (what, u, up) in [('guard', guarded, 8.0), ('brace', braced, 8.0), ('foe', foe, 8.0), if (hero != null) ('halo', hero, 14.0),
        ('drag', dragged, 8.0)]) {
        final feet = what == 'drag' ? dragAt : u.side == Side.troop ? feetOf(u) : b.toScreen(u.pos.x, u.pos.y + 5);
        final half = what == 'drag' ? 30 * k : 18 * k;
        final crop = Rect.fromLTWH(feet.dx - half, feet.dy - (up + 22) * k, 2 * half, (up + 30) * k).intersect(view);
        await zoom(others, Rect.fromLTRB(crop.left.floorToDouble(), crop.top.floorToDouble(), crop.right.ceilToDouble(), crop.bottom.ceilToDouble()),
            what == 'drag' ? 3 : 6, 'other-$what-$name');
      }
      // ignore: avoid_print
      print('$name others: guard ${guarded.type}, brace ${braced.type} (braced ${g.braced(braced)}), foe ${foe.type} '
          '(slow, Barrier), halo ${hero?.type}, drag ${dragged.type}');
    }

    // The frame time at the owner's window size.
    if (section == 'all' || section == 'fight') {
      tester.view.physicalSize = const Size(1600, 947);
      final pg = b.state = load();
      await dismissNotes();
      pg.startWave();
      final draw = <double>[], raster = <double>[];
      var frameNo = 0, rings = 0;
      final sw = Stopwatch();
      final perfBound = {for (final p in pg.pusaka.values) ?p.type};
      while (pg.t < 40 && pg.waveActive && !pg.over && frameNo < 4000) {
        b.update(1 / 30);
        frameNo++;
        final rec = ui.PictureRecorder();
        sw
          ..reset()
          ..start();
        b.render(Canvas(rec));
        sw.stop();
        draw.add(sw.elapsedMicroseconds / 1000);
        final pic = rec.endRecording();
        if (frameNo % 10 == 0) {
          final ms = await tester.runAsync(() async {
            final t = Stopwatch()..start();
            final img = await pic.toImage(1600, 947);
            t.stop();
            img.dispose();
            return t.elapsedMicroseconds / 1000;
          });
          raster.add(ms!);
        }
        pic.dispose();
        rings += pg.troops.where((u) => u.alive && perfBound.contains(u.type)).length;
      }
      // ignore: avoid_print
      print('$tag perf: wave ${pg.wave} t ${pg.t.toStringAsFixed(1)} frames $frameNo rings a frame ${(rings / max(1, frameNo)).toStringAsFixed(1)}');
      // ignore: avoid_print
      print('$tag draw: ${stats(draw)}');
      // ignore: avoid_print
      print('$tag raster: ${stats(raster)}');
    }
    b.state = Game();
    await tester.pump(const Duration(milliseconds: 100)); // the notes' tap's timer runs out
  });
}
