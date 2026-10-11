// The Legenda seen (decisions-log 155, ui-hud.md "Tas", "Peti Bos"): offscreen shots into
// <probe root>/shots/legenda/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_legenda_shots.dart"]` with the worktree as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir); the dice are seeded, so a rerun gives the same shots.
//
// From the owner's wave-86 save (the fixture: five types, so Oath of One waits), at 1280x720 and 412x860: chest-<size>
// (a wave-90 chest of the three Legenda: one star each, the oath's "Baru: seluruh pasukan" and Oath of One's wait in
// red), tas-<size> (Oath of One taken and picked: every type's row "Seluruh pasukan" and the wait; Dragon Crown on the
// Templar, the Legenda's row of slots), pasukan-<size> (the title's alive/cap and the oath's faded icon); and at 1280
// the wave-90 boss fight with Dragon Crown on the Templar instead of Dragon Heart: rings (its jade ring), rings-zoom
// (3x round a Templar) and the crown's counter printed (blows cut, HP kept): a check that the cap fires in a real fight.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/legenda');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The fixture (the owner's w86 save from before the Pusaka and the chest), its catch-up chests cleared, its note seen.
Game load() {
  final save = jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>;
  return Game.fromJson(save, Random(seed), Random(seed + 100), Random(seed + 300))
    ..loot = Random(seed + 200)
    ..draft = Random(seed + 500)
    ..boardRules()
    ..chests.clear()
    ..dismissPusakaNote();
}

void main() {
  for (final size in const [Size(1280, 720), Size(412, 860)]) {
    final tag = '${size.width.round()}';
    testWidgets('legenda shots $tag', (tester) async {
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

      Future<ui.Image> shot(String name, [int settle = 20]) async {
        await frames(tester, settle);
        final img = await grab();
        await save(img, name);
        return img;
      }

      Future<void> tap(Offset p) async {
        await tester.tapAt(p);
        await frames(tester, 2);
      }

      Future<void> closeMessage() async {
        if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
      }

      // A wave-90 chest of the three Legenda.
      final g = b.state = load()
        ..wave = 90
        ..chests.add(Chest(ChestKind.boss, 90, cards: [Relic.dragonCrown, Relic.oathOfOne, Relic.alliance]));
      await frames(tester, 3);
      await tap(const Offset(2, 2)); // any note goes, the popup stays
      await shot('chest-$tag', 30);

      // Oath of One taken (it waits: five types), Dragon Crown on the Templar; the Tas page with the oath picked.
      await tap(b.chestCards[1].center);
      await tap(b.chestButtons['take']!.center);
      // ignore: avoid_print
      print('took: oath ${g.oath}, waits ${g.oathWaits}, types alive ${g.typesAlive}, message ${b.message}');
      g.givePusaka(Relic.dragonCrown, type: 'knight_templar');
      await frames(tester, 150); // the message goes
      await closeMessage();
      await tap(b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
      await tap(b.bagSlot(Relic.oathOfOne).center);
      await shot('tas-$tag', 40);
      await tap(b.bagSlot(Relic.oathOfOne).center); // put back
      await tap(b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2.center);
      await shot('pasukan-$tag', 30);
      if (size.width < 1000) return;

      // The wave-90 boss fight with Dragon Crown on the Templar (its Dragon Heart in the Gudang): the jade rings, and
      // the crown's counter.
      final f = b.state = load()
        ..wave = 89
        ..givePusaka(Relic.dragonCrown, type: 'knight_templar');
      await frames(tester, 20);
      f.startWave();
      await frames(tester, 2);
      for (var t = 0.0; t < 14; t += 0.5) {
        for (var i = 0; i < 15 && !f.over; i++) {
          f.tick(1 / 30);
        }
        f.heroCasts.clear();
        await frames(tester, 1);
      }
      final fight = await shot('rings', 2);
      final templar = f.troops.where((u) => u.alive && u.type == 'knight_templar').firstOrNull;
      if (templar != null) {
        final at = b.toScreen(templar.pos.x, templar.pos.y);
        final crop = Rect.fromCenter(center: at, width: 320, height: 180).intersect(Offset.zero & size);
        final img = await tester.runAsync(() {
          final rec = ui.PictureRecorder();
          Canvas(rec).drawImageRect(fight, crop, Offset.zero & (crop.size * 3), Paint()..filterQuality = FilterQuality.none);
          return rec.endRecording().toImage((crop.width * 3).round(), (crop.height * 3).round());
        });
        await save(img!, 'rings-zoom');
      }
      // Play the boss wave on (at most 120 s more) and print what the crown did.
      for (var t = 0.0; t < 120 && f.waveActive && !f.over; t += 0.5) {
        for (var i = 0; i < 15 && f.waveActive && !f.over; i++) {
          f.tick(1 / 30);
        }
        f.heroCasts.clear();
      }
      final tally = f.pusakaWorth[Relic.dragonCrown];
      final templars = f.troops.where((u) => u.alive && u.type == 'knight_templar').length;
      // ignore: avoid_print
      print('w${f.wave} ${f.waveActive ? 'on' : 'over'} t ${f.t.toStringAsFixed(1)}: Dragon Crown cut ${tally?.uses ?? 0} blows, '
          'kept ${tally?.worth.round() ?? 0} HP; templars alive $templars');
    });
  }
}
