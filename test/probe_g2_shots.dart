// Batch G-2 seen (decisions-log 238; loot-items-relics.md "Pusaka"): offscreen shots into <probe root>/shots/cat-G2/
// (`OUT`), built on test/probe_g1p_shots.dart. A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_g2_shots.dart"]` with the worktree as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir); nothing is rolled, so a rerun gives the same shots.
//
// map-02-atlas-numbered: the Legenda rows of assets/images/artifact_icons.png (cells 60..89) at 4x, each cell's number
// and kind under it, the eight of the batch framed (the sheet mapped before its cells are used). The eight Legenda
// Artifacts on the owner's wave-89 save (the fixture) at wave 90, the Shadows off: chest-<tag>-<n> (three boss chests of
// three gold Legenda cards that deal the eight, the longest together first, the third with Dragon Crown, n 1..3, at
// 412x860 and 1266x713, the tag phone or desk); bag-shelter at 1266x713 and bag-shelter-phone at 412x860 (the Bag's
// Artifacts, Soul Shelter on the templars picked: its detail, the action rows under it); and at 1266x713 army-axeman
// (the Army page, the axemen under Glory Seeker picked: "Glorious Armored Axeman", its attack down in the detail).
import 'dart:convert';
import 'dart:io';
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/cat-G2');

/// The batch's eight.
const batch = [
  Relic.rageTotem, Relic.guardianChain, Relic.phalanx, Relic.phoenix, //
  Relic.soulShelter, Relic.manaFont, Relic.hexBlade, Relic.glorySeeker,
];

/// The eight, three a chest (the longest together first), and Dragon Crown beside the last two.
const hands = [
  [Relic.manaFont, Relic.hexBlade, Relic.soulShelter],
  [Relic.phoenix, Relic.guardianChain, Relic.glorySeeker],
  [Relic.rageTotem, Relic.phalanx, Relic.dragonCrown],
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

/// Boots one TdGame in [size] under a [RepaintBoundary] of [key], past the welcome screen.
Future<Board> boot(WidgetTester tester, Size size, GlobalKey key) async {
  tester.view
    ..physicalSize = size
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
  return game.board
    ..welcome = null
    ..miniMapOpen = false;
}

Future<void> save(ui.Image img, String name) async {
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File('$out/$name.png')
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote $out/$name.png ${img.width}x${img.height}');
}

/// Shoots the boundary of [key] into `$out/$name.png` after [settle] frames.
Future<void> shot(WidgetTester tester, GlobalKey key, String name, [int settle = 20]) async {
  await frames(tester, settle);
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final img = (await tester.runAsync(() => boundary.toImage()))!;
  await tester.runAsync(() => save(img, name));
}

/// The atlas's Legenda rows, numbered: cell n at 4x, "n kind" under it, the batch's cells framed.
Future<void> atlasMap() async {
  const scale = 4.0, cell = 32 * scale, label = 40.0, first = 60, rows = 3;
  final codec = await ui.instantiateImageCodec(File('assets/images/artifact_icons.png').readAsBytesSync());
  final atlas = (await codec.getNextFrame()).image;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..drawRect(const Rect.fromLTWH(0, 0, cell * artifactIconCols, (cell + label) * rows), Paint()..color = const Color(0xff202028));
  final mine = {for (final r in batch) relicKind(r)};
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

/// [r]'s atlas kind: its [Relic]'s name.
String relicKind(Relic r) => r.name;

void main() {
  testWidgets('G-2 artifact shots', (tester) async {
    final key = GlobalKey();
    final b = await boot(tester, const Size(1266, 713), key);
    await tester.runAsync(atlasMap);
    for (final r in batch) {
      final i = artifactIconKinds.indexOf(r.name);
      // ignore: avoid_print
      print('${r.name}: cell $i (row ${i ~/ artifactIconCols}, col ${i % artifactIconCols}), icon ${pusakaCatalog[r]!.icon}');
    }

    Future<void> tap(Offset p) async {
      await tester.tapAt(p);
      await frames(tester);
    }

    Future<void> page(String name) async {
      if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
      await tap(b.bookTabs.firstWhere((t) => t.$1 == name).$2.center);
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860))]) {
      tester.view.physicalSize = size;
      for (final (i, hand) in hands.indexed) {
        final g = b.state = load()..chests.add(Chest(ChestKind.boss, 90, cards: hand));
        await frames(tester, 3);
        await tap(const Offset(2, 2)); // the save's notes go, the popup stays
        // ignore: avoid_print
        print('chest ${i + 1}: ${g.chest?.cards}; cards ${b.chestCards}');
        await shot(tester, key, 'chest-$tag-${i + 1}', 30);
      }
    }

    for (final (name, size) in const [('bag-shelter', Size(1266, 713)), ('bag-shelter-phone', Size(412, 860))]) {
      tester.view.physicalSize = size;
      b.state = load()
        ..givePusaka(Relic.soulShelter, type: 'knight_templar')
        ..givePusaka(Relic.glorySeeker, type: 'armored_axeman', ukir: 2);
      await frames(tester, 30);
      await page('troops');
      await page('bag');
      await tap(b.bagChip(BagCategory.artifacts).center);
      for (var i = 0; i < 5 && b.bagSlot(Relic.soulShelter) == Rect.zero && b.bagPager('on') != Rect.zero; i++) {
        await tap(b.bagPager('on').center);
      }
      await tap(b.bagSlot(Relic.soulShelter).center);
      // ignore: avoid_print
      print('$name: picked ${b.picked}, desc ${b.bagDetailText('desc')?.replaceAll('\n', ' | ')}');
      await shot(tester, key, name, 30);
    }
    tester.view.physicalSize = const Size(1266, 713);
    await page('troops');
    await tap(b.troopRow('armored_axeman').center);
    await shot(tester, key, 'army-axeman', 30);
    b.state = Game();
    await frames(tester, 10);
  });
}
