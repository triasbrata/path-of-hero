// Batch G-4 seen (decisions-log 247; loot-items-relics.md "Legenda", ui-hud.md "Boss Chest"): offscreen shots into
// <probe root>/shots/cat-G4/ (`OUT`), built on test/probe_g3_shots.dart and test/probe_legenda_shots.dart. A probe,
// not part of the suite (no `_test.dart`): queue `["test", "test/probe_g4_shots.dart"]` with the worktree as `dir`. It
// never touches the real save (flutter_test_config.dart's temp dir); the dice are seeded, so a rerun gives the same shots.
//
// map-01-atlas-numbered: the Legenda rows of assets/images/artifact_icons.png (cells 60..89) at 4x, each cell's number
// and kind under it, the batch's six padlocks framed (the sheet mapped before its cells are used). Then the owner's
// wave-89 save (the fixture; its Alliance taken off, so every oath may come) at wave 90, the Shadows off, at 1266x713
// (desk) and 412x860 (phone): chest-<tag>-<n> (n 1..3: the Few, the Wall and Blood Oath; the Vanguard, Kings and Spells;
// the Vanguard and Kings beside Dragon Crown; the Few's card says in red that it would wait, 48 troops alive),
// take-<tag> (the Few taken: its message and the wait), bag-<tag> (the Bag with the Few picked: every type's row
// "Waiting: 48/24 troops"), allfound-<tag> (a wave-90 chest on Legenda dice with every Legenda a run can find found:
// three Epik cards, the step-down) and army-<tag> (a board army of 24 under the Few: the Army page, Buy refused with
// "Oath of the Few: up to 24 troops").
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/cat-G4');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

/// The batch's six.
const batch = [Relic.fewOath, Relic.wallOath, Relic.bloodOath, Relic.vanguardOath, Relic.kingsOath, Relic.spellOath];

/// Three at a time, then two beside Dragon Crown.
const hands = [
  [Relic.fewOath, Relic.wallOath, Relic.bloodOath],
  [Relic.vanguardOath, Relic.kingsOath, Relic.spellOath],
  [Relic.vanguardOath, Relic.kingsOath, Relic.dragonCrown],
];

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The owner's wave-89 save at wave 90, its Alliance taken off and forgotten (so every oath may come), no chest waiting.
Game load() {
  final g = Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>,
      Random(seed), Random(seed + 100), Random(seed + 300))
    ..boardRules()
    ..chests.clear()
    ..wave = 90;
  g.pusaka.remove(Relic.alliance);
  g.legendsFound.clear();
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
  await save(img, 'map-01-atlas-numbered');
}

/// Draft dice that roll every rarity at [roll] (0.99: Legenda) and take the first card of a pool.
class _Dice implements Random {
  _Dice(this.roll);
  final double roll;

  @override
  double nextDouble() => roll;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

void main() {
  testWidgets('G-4 oath shots', (tester) async {
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

    Future<void> shot(String name, [int settle = 20]) async {
      await frames(tester, settle);
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = (await tester.runAsync(() => boundary.toImage()))!;
      await tester.runAsync(() => save(img, name));
    }

    Future<void> tap(Offset p) async {
      await tester.tapAt(p);
      await frames(tester);
    }

    Future<void> closeMessage() async {
      if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
    }

    for (final (tag, size) in const [('desk', Size(1266, 713)), ('phone', Size(412, 860))]) {
      tester.view.physicalSize = size;
      // The chest cards.
      for (final (i, hand) in hands.indexed) {
        final g = b.state = load()..chests.add(Chest(ChestKind.boss, 90, cards: hand));
        await frames(tester, 3);
        await tap(const Offset(2, 2)); // the save's notes go, the popup stays
        // ignore: avoid_print
        print('chest $tag ${i + 1}: ${g.chest?.cards}; cards ${b.chestCards}; alive ${g.armySize}');
        await shot('chest-$tag-${i + 1}', 30);
      }
      // The Few taken with 48 alive: its message, then the Bag with it picked.
      final g = b.state = load()..chests.add(Chest(ChestKind.boss, 90, cards: hands.first));
      await frames(tester, 3);
      await tap(const Offset(2, 2));
      await frames(tester, 30);
      await tap(b.chestCards[0].center);
      await tap(b.chestButtons['take']!.center);
      await shot('take-$tag', 30);
      // ignore: avoid_print
      print('take $tag: oath ${g.oath}, waits ${g.oathWaits}, alive ${g.armySize}, message ${b.message}, where ${g.pusakaWhere(Relic.fewOath)}');
      await frames(tester, 150); // the message goes
      await closeMessage();
      await tap(b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
      await tap(b.bagSlot(Relic.fewOath).center);
      await shot('bag-$tag', 40);
      await tap(b.bagSlot(Relic.fewOath).center); // put back
      await tap(b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center); // the book shut
      // Every Legenda a run can find found: a Legenda roll steps down to an Epik.
      final all = b.state = load()
        ..chestsGiven = 1
        ..draft = _Dice(0.99);
      all.legendsFound.addAll([
        for (final r in Relic.values) if (r.pusaka && r.rarity == Rarity.legenda && !r.oath) r,
        Relic.kingsOath,
      ]);
      all.giveChests(1);
      await frames(tester, 3);
      await tap(const Offset(2, 2));
      // ignore: avoid_print
      print('allfound $tag: found ${all.legendsFound.length}, cards ${all.chest?.cards} (${all.chest?.cards?.map((r) => r?.rarity.name)})');
      await shot('allfound-$tag', 30);
      // A board army of 24 under the Few: the Army page refuses a 25th.
      final a = b.state = Game(Random(seed), Random(seed + 100)).boardRules()
        ..gold = 400000
        ..wave = 89;
      var n = 0;
      for (final type in ['knight', 'knight_templar', 'archer', 'soldier', 'swordsman', 'lancer']) {
        for (var i = 0; i < 4 && n < 24; i++, n++) {
          a.capacity = max(a.capacity, n + 1);
          a.autoPlace(type);
        }
      }
      a
        ..capacity = 30 // room for more: the oath's 24, not the room, says no
        ..givePusaka(Relic.fewOath);
      for (final u in a.troops) {
        u
          ..pos = u.post
          ..arriving = false;
      }
      await frames(tester, 10);
      await tap(b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2.center);
      if (b.troopRow('archer') != Rect.zero) await tap(b.troopRow('archer').center);
      await tap(b.spawnCard('archer') == Rect.zero ? const Offset(2, 2) : b.spawnCard('archer').center);
      // ignore: avoid_print
      print('army $tag: alive ${a.armySize}/${a.armyCap}, locked ${a.armyLocked}, refusal ${a.buyRefusal('archer')}, message ${b.message}');
      await shot('army-$tag', 20);
      await closeMessage();
      await tap(b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2.center); // the book shut
    }
    b.state = Game();
    await frames(tester, 10);
  });
}
