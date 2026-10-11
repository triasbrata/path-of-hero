// The itch.io page's images (#94, docs/itch-page.md): offscreen shots of the game into marketing/itch/. A probe,
// not part of the suite (no `_test.dart`): queue `["test", "test/probe_itch_shots.dart"]` with the worktree as
// `dir` (docs/testing.md). It never touches the real save: the game's files go to a temp dir of its own
// (flutter_test_config.dart), and the army comes from a snapshot copy (`SNAPSHOT`), loaded with seeded dice and
// played at a fixed step, so a rerun gives the same shots. The game plays by the board's rules, as a player's does
// (`boardRules`: the army cap, the roster limit, the boss chest), so the snapshot's army is cut to fit them.
//
// It writes, at 1280x720: welcome and screenshot-1..7 (battle, hero, boss, book, hero-splash, chest; no 5, store: the
// field's Shop went in decisions-log 296); the
// banner (960x240) and the cover (630x500), both the welcome screen's valley and marching squad titled in the game's
// font; and gif/frame_NNN.png (640x360) for the short GIF (ffmpeg: docs/itch-page.md). `--dart-define=COVER_ONLY=true`
// writes only the cover.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/hud_font.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/save.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const snapshot = String.fromEnvironment('SNAPSHOT',
    defaultValue: '$probeRoot/snapshots/save-20260928-0355.json');
const seed = int.fromEnvironment('SEED', defaultValue: 7);
const out = 'marketing/itch';
const shotSize = Size(1280, 720);
const tagline = 'Lead the march. Hold the road.';
const coverOnly = bool.fromEnvironment('COVER_ONLY');

/// The cover's scene: the welcome screen in a view 4 x (backdropH + fieldH) = 768 tall, so the valley is drawn at
/// exactly 4 px a pixel, and wide enough that the panel (520 wide, centred) leaves the left 630 px to the valley.
const coverView = Size(2400, 768);

/// When the cover is shot, in seconds: the squad's rear is then at 14·t mod (600 + 130) − 100 ≈ 41 (welcome.dart),
/// so the squad (about rear − 15 to rear + 90) sits in the middle of the cover's 157 units.
const coverAt = 10.1;

Future<void> frames(WidgetTester tester, [int n = 2, int ms = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

/// The snapshot's army cut to what the board lets a player field ([armyMaxBoard] troops, each type at most its
/// [typeCapBoard]): so many of each type, the first in the save's order (its three Heroes are a knight, an archer and a
/// priest).
const kept = {'knight': 9, 'archer': 8, 'priest': 5, 'armored_axeman': 10};

/// The snapshot at the board's rules, its army cut to [kept], with the Pusaka its six boss chests (waves 5 to 30) could
/// have brought, one bound to each type; the old save's catch-up chests go (the Boss Chest shot sets its own).
Game load() {
  final save = jsonDecode(File(snapshot).readAsStringSync()) as Map<String, dynamic>;
  final room = {...kept}, troops = [];
  for (final t in save['troops'] as List) {
    final type = (t as Map)['type'] as String;
    if ((room[type] ?? 0) == 0) continue;
    room[type] = room[type]! - 1;
    troops.add(t);
  }
  save
    ..['troops'] = troops
    ..['capacity'] = armyMaxBoard;
  return Game.fromJson(save, Random(seed), Random(seed + 100), Random(seed + 300))
    ..loot = Random(seed + 200)
    ..draft = Random(seed + 500)
    ..boardRules()
    ..chests.clear()
    ..givePusaka(Relic.dragonHeart, type: 'knight', stars: 2)
    ..givePusaka(Relic.godThunder, type: 'archer', stars: 2)
    ..givePusaka(Relic.ironBanner, type: 'armored_axeman')
    ..givePusaka(Relic.dawnStar, type: 'priest');
}

/// [src] cut to [crop] and drawn into [w]x[h] (pixel for pixel when the sizes match), with [title] and [tagline] in
/// the game's font over a dark band: across the top, or down the left side when [left].
Future<ui.Image> compose(ui.Image src, Rect crop, int w, int h,
    {String? title, double titleSize = 64, Offset? titleAt, bool left = false}) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  final to = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
  final same = crop.size == to.size;
  c.drawImageRect(src, crop, to, Paint()..filterQuality = same ? FilterQuality.none : FilterQuality.medium);
  if (title != null) {
    final at = titleAt ?? Offset(w / 2, titleSize * 0.95);
    const dark = [Color(0xD91E120A), Color(0xA61E120A), Color(0x001E120A)];
    final reach = left ? at.dx * 2.2 : at.dy + titleSize * 1.9;
    c.drawRect(
        left ? Rect.fromLTWH(0, 0, reach, h.toDouble()) : Rect.fromLTWH(0, 0, w.toDouble(), reach),
        Paint()..shader = ui.Gradient.linear(Offset.zero, left ? Offset(reach, 0) : Offset(0, reach), dark, const [0, 0.55, 1]));
    words(c, title, at, titleSize, const Color(0xFFFFD65A), const Color(0xFF3C1E0A));
    words(c, tagline, at + Offset(0, titleSize * 0.95), titleSize * 0.36, const Color(0xFFFFF4DC), const Color(0xFF3C1E0A));
  }
  return rec.endRecording().toImage(w, h);
}

/// [text] centred on [at], word by word with the gaps as spacing (the title is drawn here, not by the game), in the
/// game's title weight with a dark outline under the fill like the welcome title.
void words(Canvas c, String text, Offset at, double size, Color fill, Color outline) {
  TextPainter paint(String s, Paint p) => TextPainter(
        text: TextSpan(text: s, style: hudStyle(size, foreground: p, height: 1, bold: true)),
        textDirection: TextDirection.ltr,
      )..layout();
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = size / 7
    ..strokeJoin = StrokeJoin.round
    ..color = outline;
  final parts = text.split(' '), gap = size * 0.4;
  final fills = [for (final s in parts) paint(s, Paint()..color = fill)];
  final width = fills.fold(0.0, (a, p) => a + p.width) + gap * (parts.length - 1);
  var x = at.dx - width / 2;
  for (var i = 0; i < parts.length; i++) {
    final top = Offset(x, at.dy - fills[i].height / 2);
    paint(parts[i], stroke).paint(c, top);
    fills[i].paint(c, top);
    x += fills[i].width + gap;
  }
}

Future<void> save(WidgetTester tester, ui.Image img, String name) async {
  await tester.runAsync(() async {
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
  // ignore: avoid_print
  print('wrote $out/$name.png ${img.width}x${img.height}');
}

void main() {
  testWidgets('itch shots', (tester) async {
    tester.view
      ..physicalSize = shotSize
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
    final b = game.board;

    Future<ui.Image> grab() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return (await tester.runAsync(() => boundary.toImage()))!;
    }

    Future<ui.Image> shot(String name, [int settle = 20, int ms = 16]) async {
      await frames(tester, settle, ms);
      final img = await grab();
      await save(tester, img, name);
      return img;
    }

    // A fight's shot with the board stopped (speed 0) while it settles, so no cast or cut-in lands in its last frames;
    // the last frame is drawn at x1 again (the speed button shows it) and takes no time.
    Future<void> still(String name, int settle) async {
      b.speed = 0;
      await frames(tester, settle);
      b.speed = 1;
      await shot(name, 1, 0);
    }

    Future<void> titled(ui.Image src, Rect crop, int w, int h, String name, double size, Offset at, {bool left = false}) async {
      final img = await tester.runAsync(() => compose(src, crop, w, h, title: 'Path of Hero', titleSize: size, titleAt: at, left: left));
      await save(tester, img!, name);
    }

    // Plays [seconds] of the wave at a fixed step, a frame every half second so the HUD takes the casts and bursts as
    // they come. A Hero's cast shows its cut-in only with [cutIns]. The monsters' casts never reach the board, so no
    // foe banner (nor a red cast name) is left over the field in a shot. Stops early, before that frame, when [until]
    // holds.
    Future<void> play(Game g, double seconds, {bool cutIns = false, bool Function()? until}) async {
      for (var t = 0.0; t < seconds; t += 0.5) {
        for (var i = 0; i < 15 && !g.over; i++) {
          g.tick(1 / 30);
        }
        if (!cutIns) g.heroCasts.clear();
        g.monsterCasts.clear();
        if (until?.call() ?? false) return;
        await frames(tester, 1);
      }
    }

    // 1. The cover (630x500): the welcome screen's valley at 4x with the squad marching, pixel for pixel, under the
    // title; its bottom 500 rows are the field, the squad's three lanes at the foot.
    b.welcome = Welcome(load(), discard: () {});
    tester.view.physicalSize = coverView;
    await frames(tester, (coverAt * 10).round(), 100);
    final scene = await grab();
    await titled(scene, Rect.fromLTWH(0, coverView.height - 500, 630, 500), 630, 500, 'cover', 68, const Offset(315, 64));
    if (coverOnly) return;

    // 2. The welcome screen, as a player with a save sees it, ~20 s in: the squad (rear = 14·t mod (viewW + 130)
    // − 100, welcome.dart) right of the middle, under the panel. The banner is that valley strip with the title.
    tester.view.physicalSize = shotSize;
    await frames(tester, 203 - (coverAt * 10).round(), 100);
    final welcome = await shot('welcome', 1);
    await titled(welcome, const Rect.fromLTWH(160, 475, 960, 240), 960, 240, 'banner', 60, const Offset(250, 100), left: true);
    b.welcome = null;

    // 3. Between waves: the book on the Army page, then a Hero's splash.
    final rest = b.state = load();
    b.miniMapOpen = false;
    await shot('screenshot-4-book', 40);
    rest.heroMade.add(rest.troops.firstWhere((u) => u.alive && u.hero));
    await shot('screenshot-6-hero-splash', 40);
    await tester.tapAt(const Offset(640, 360)); // closes it
    await frames(tester);

    // The Boss Chest after wave 30: an Epic, a Rare and a Legendary card, the Legendary lifted (Take on it).
    b.state = load()
      ..wave = 30
      ..chests.add(Chest(ChestKind.boss, 30, cards: [Relic.godThunder, Relic.ironBanner, Relic.dragonCrown]));
    await frames(tester, 3);
    expect(b.chestOpen, isTrue);
    await tester.tapAt(b.chestCards.last.center);
    await shot('screenshot-7-chest', 30);

    // 4. The wave-30 fight (a mini boss and the boss) with the snapshot's army: the battle, a Hero's cut-in, the boss.
    final g = b.state = load()..wave = 29;
    b.miniMapOpen = true;
    await frames(tester, 30);
    g.startWave();
    await frames(tester, 2);
    await play(g, 16);
    await still('screenshot-1-battle', 4);
    // The short GIF: 3 s of the fight at 10 fps, 640x360.
    for (var i = 0; i < 30; i++) {
      for (var k = 0; k < 3; k++) {
        g.tick(1 / 30);
      }
      g.heroCasts.clear();
      g.monsterCasts.clear();
      await frames(tester, 1);
      final f = await grab();
      final small = (await tester.runAsync(() => compose(f, Offset.zero & shotSize, 640, 360)))!;
      await save(tester, small, 'gif/frame_${i.toString().padLeft(3, '0')}');
    }
    await play(g, 30, cutIns: true, until: () => g.heroCasts.isNotEmpty);
    await shot('screenshot-2-hero', 18);
    bool bossIn() => g.enemies.any((u) => u.tier == Tier.boss && u.entered && u.alive);
    await play(g, 90, until: bossIn);
    await play(g, 4);
    await still('screenshot-3-boss', 4);

    // ignore: avoid_print
    print('wave ${g.wave} over ${g.over} troops ${g.troops.where((u) => u.alive).length} foes ${g.enemies.length}');
  });
}
