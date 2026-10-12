// Batch G-3 seen (decisions-log 243; loot-items-relics.md "Pusaka", ui-hud.md "Shadows"): offscreen shots into
// <probe root>/shots/cat-G3/ (`OUT`), built on test/probe_g2_shots.dart and test/probe_g3b_shots.dart. A probe, not
// part of the suite (no `_test.dart`): queue `["test", "test/probe_g3_shots.dart"]` with the worktree as `dir`. It never
// touches the real save (flutter_test_config.dart's temp dir); the dice are seeded, so a rerun gives the same shots.
//
// map-02-atlas-numbered: the Legenda rows of assets/images/artifact_icons.png (cells 60..89) at 4x, each cell's number
// and kind under it, the batch's three framed (the sheet mapped before its cells are used). The three Legenda Artifacts
// on the owner's wave-89 save (the fixture) at wave 90, the Shadows off: chest-<tag>-<n> (a boss chest of the three, then
// Wrath Psalm and Grave Seal each beside old ones, n 1..2, at 412x860 and 1266x713, the tag phone or desk). With the
// Shadows forced on, at both sizes (<size>): reveal-<size> (a Boss Chest of the three hiding Blight, Holy Ward and Hardy,
// the first taken: "Blight 3"), message-<size> (after it), chips-<size> and tip-<size> (between waves, Blight held with
// Barrier and Holy Ward: the icons and levels, then their tooltip), and at 1266x713 field-blight-zoom and
// field-plain-zoom (a troop under Blight's noHeal drawn olive, and the same troop without it, cut out around it at 6x).
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

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/cat-G3');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

/// The batch's three.
const batch = [Relic.vampireKiss, Relic.wrathPsalm, Relic.graveSeal];

/// The three together, then Wrath Psalm (the longest) and Grave Seal beside old ones.
const hands = [
  batch,
  [Relic.wrathPsalm, Relic.graveSeal, Relic.dragonCrown],
];

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Game load() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>)
    .boardRules()
  ..chests.clear()
  ..wave = 90;

/// A board game between waves at wave 89 (the next a boss's), seeded, a mixed army of eight types, gold to spare.
Game board() {
  final g = Game(Random(seed), Random(seed + 100)).boardRules()
    ..seedDice(seed) // every die, the Shadows' faces too (decisions-log 319)
    ..armyMax = null
    ..gold = 400000
    ..wave = 89;
  for (final type in ['knight', 'knight_templar', 'archer', 'priest', 'wizard', 'soldier', 'lancer', 'swordsman']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  return g;
}

Future<void> save(ui.Image img, String name) async {
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File('$out/$name.png')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote $out/$name.png ${img.width}x${img.height}');
}

/// The atlas's Legenda rows, numbered: cell n at 4x, "n kind" under it, the batch's cells framed.
Future<void> atlasMap() async {
  const scale = 4.0, cell = 32 * scale, label = 40.0, first = 60, rows = 3;
  final codec = await ui.instantiateImageCodec(File('assets/images/artifact_icons.png').readAsBytesSync());
  final atlas = (await codec.getNextFrame()).image;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..drawRect(const Rect.fromLTWH(0, 0, cell * artifactIconCols, (cell + label) * rows), Paint()..color = const Color(0xff202028));
  final mine = {for (final r in batch) r.name};
  for (var i = first; i < first + rows * artifactIconCols; i++) {
    final kind = artifactIconKinds[i];
    final at = Offset((i % artifactIconCols) * cell, (i ~/ artifactIconCols - first ~/ artifactIconCols) * (cell + label));
    final src = Rect.fromLTWH(i % artifactIconCols * 32.0, i ~/ artifactIconCols * 32.0, 32, 32);
    c.drawImageRect(atlas, src, at & const Size(cell, cell), Paint()..filterQuality = FilterQuality.none);
    if (mine.contains(kind)) {
      c.drawRect((at & const Size(cell, cell + label)).deflate(1), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xffffd040));
    }
    final tp = TextPainter(
      text: TextSpan(text: '$i $kind', style: TextStyle(fontFamily: hudFont, fontSize: 13, color: mine.contains(kind) ? const Color(0xffffd040) : const Color(0xffd0d0d0))),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: cell - 4);
    tp.paint(c, at + Offset(3, cell + 2));
  }
  final img = await rec.endRecording().toImage((cell * artifactIconCols).toInt(), ((cell + label) * rows).toInt());
  await save(img, 'map-02-atlas-numbered');
}

/// [img]'s part in [box] at [scale]x, pixels kept square.
Future<ui.Image> cut(ui.Image img, Rect box, double scale) async {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawImageRect(img, box, Offset.zero & (box.size * scale), Paint()..filterQuality = FilterQuality.none);
  return rec.endRecording().toImage((box.width * scale).round(), (box.height * scale).round());
}

/// The box around the pixels that differ between [a] and [b] (same size), or null.
Future<Rect?> differs(ui.Image a, ui.Image b) async {
  final pa = (await a.toByteData())!.buffer.asUint8List(), pb = (await b.toByteData())!.buffer.asUint8List();
  var (x0, y0, x1, y1) = (a.width, a.height, -1, -1);
  for (var y = 0; y < a.height; y++) {
    for (var x = 0; x < a.width; x++) {
      final i = (y * a.width + x) * 4;
      if ((pa[i] - pb[i]).abs() + (pa[i + 1] - pb[i + 1]).abs() + (pa[i + 2] - pb[i + 2]).abs() < 24) continue;
      (x0, y0, x1, y1) = (min(x0, x), min(y0, y), max(x1, x), max(y1, y));
    }
  }
  return x1 < 0 ? null : Rect.fromLTRB(x0.toDouble(), y0.toDouble(), x1 + 1.0, y1 + 1.0);
}

void main() {
  tearDown(() => omensOn = false);

  testWidgets('G-3 artifact shots', (tester) async {
    final key = GlobalKey();
    tester.view
      ..physicalSize = const Size(1266, 713)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(loadHudFontNow);
    final game = TdGame();
    await tester.pumpWidget(RepaintBoundary(key: key, child: GameWidget(game: game)));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue);
    final b = game.board
      ..welcome = null
      ..miniMapOpen = false;
    await tester.runAsync(atlasMap);
    for (final r in batch) {
      final i = artifactIconKinds.indexOf(r.name);
      // ignore: avoid_print
      print('${r.name}: cell $i (row ${i ~/ artifactIconCols}, col ${i % artifactIconCols}), icon ${pusakaCatalog[r]!.icon}');
    }

    Future<ui.Image> grab([int settle = 20]) async {
      await frames(tester, settle);
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return (await tester.runAsync(() => boundary.toImage()))!;
    }

    Future<void> shot(String name, [int settle = 20]) async {
      final img = await grab(settle);
      await tester.runAsync(() => save(img, name));
    }

    Future<void> tap(Offset p) async {
      await tester.tapAt(p);
      await frames(tester);
    }

    // The chest cards, the Shadows off.
    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860))]) {
      tester.view.physicalSize = size;
      for (final (i, hand) in hands.indexed) {
        final g = b.state = load()..chests.add(Chest(ChestKind.boss, 90, cards: hand));
        await frames(tester, 3);
        await tap(const Offset(2, 2)); // the save's notes go, the popup stays
        // ignore: avoid_print
        print('chest ${i + 1}: ${g.chest?.cards}; cards ${b.chestCards}');
        await shot('chest-$tag-${i + 1}', 30);
      }
    }

    // Blight with the Shadows forced on: a reveal, the message, the chips and their tooltip.
    omensOn = true;
    for (final size in const [Size(412, 860), Size(1266, 713)]) {
      final tag = '${size.width.round()}x${size.height.round()}';
      tester.view.physicalSize = size;
      final g = b.state = board()..chestsGiven = 1;
      g.chests.add(Chest(ChestKind.boss, 90, cards: batch, omens: [OmenKind.blight, OmenKind.holyWard, OmenKind.hardy]));
      await frames(tester, 40);
      await tap(b.chestCards[0].center);
      await tap(b.chestButtons['take']!.center);
      await shot('reveal-$tag', 30);
      await frames(tester, (omenRevealFor * 60).ceil());
      await shot('message-$tag', 2);
      // ignore: avoid_print
      print('message-$tag: ${b.message}');
      if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
      g.omens
        ..clear()
        ..addAll([...List.filled(4, OmenKind.blight), ...List.filled(3, OmenKind.shield), ...List.filled(3, OmenKind.holyWard)]);
      await shot('chips-$tag', 20);
      await tap(b.omenRow.center);
      await shot('tip-$tag', 30);
      // ignore: avoid_print
      print('tip-$tag: ${g.omenTip.$2.join(' | ')}');
      await tap(b.omenRow.center);
    }

    // A troop under Blight on the field, drawn olive; the same troop without it. The game paused, so only the tint moves.
    tester.view.physicalSize = const Size(1266, 713);
    final g = b.state = board();
    final orc = g.monster('orc', Tier.boss, const Point(400, 60))..entered = true;
    g
      ..units.add(orc)
      ..paused = true; // the orc stays where it is
    await frames(tester, 30);
    final knight = g.troops.firstWhere((u) => u.type == 'knight');
    final plain = await grab(10);
    g.addEffect(knight, Status.noHeal, 1e6, by: orc, bad: true, omen: true);
    final blighted = await grab(10);
    final box = await tester.runAsync(() => differs(plain, blighted));
    // ignore: avoid_print
    print('blight: ${g.blighted(knight)}, the pixels that moved: $box');
    if (box != null) {
      final around = Rect.fromCenter(center: box.center, width: max(box.width, 48) + 24, height: max(box.height, 48) + 24);
      await tester.runAsync(() async {
        await save(await cut(blighted, around, 6), 'field-blight-zoom');
        await save(await cut(plain, around, 6), 'field-plain-zoom');
      });
    }
    g.paused = false;
    omensOn = false;
    b.state = Game();
    await frames(tester, 10);
  });
}
