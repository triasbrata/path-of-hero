// The chest cards' frames recoloured by rarity (ui-hud.md "Boss Chest"; the owner, 2026-10-02: no ink box over the frame):
// offscreen shots into <probe root>/shots/chest-frame/ (`OUT`). A probe, not part of the suite (no `_test.dart`):
// queue `["test", "test/probe_chest_frame_shots.dart"]` with the worktree as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir).
//
// At 1266x713 and 412x860, from the owner's wave-86 save (the fixture) with two boss chests in turn: a (God's Thunder
// Epik, Iron Banner Langka, Dragon Crown Legenda) and b (a Serpihan, War Drum Langka, Oath of One Legenda). Each one
// plain (<size>-<a|b>-plain), then each card lifted (<size>-<a|b>-armed-<n>, Ambil on it).
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/chest-frame');
const seed = 7;

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The fixture (the owner's w86 save) at wave 90 with [cards] as its one chest.
Game load(List<Relic?> cards) {
  final save = jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>;
  return Game.fromJson(save, Random(seed), Random(seed + 100), Random(seed + 300))
    ..loot = Random(seed + 200)
    ..draft = Random(seed + 500)
    ..boardRules()
    ..wave = 90
    ..chests.clear()
    ..chests.add(Chest(ChestKind.boss, 90, cards: cards));
}

void main() {
  for (final size in const [Size(1266, 713), Size(412, 860)]) {
    final tag = '${size.width.round()}';
    testWidgets('chest frame shots $tag', (tester) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await loadHudFont(tester);
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

      Future<void> shot(String name, [int settle = 20]) async {
        await frames(tester, settle);
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = (await tester.runAsync(() => boundary.toImage()))!;
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        // ignore: avoid_print
        print('wrote $out/$name.png ${img.width}x${img.height}');
      }

      Future<void> tap(Offset p) async {
        await tester.tapAt(p);
        await frames(tester, 2);
      }

      for (final (name, cards) in [
        ('a', [Relic.godThunder, Relic.ironBanner, Relic.dragonCrown]),
        ('b', [null, Relic.warDrum, Relic.oathOfOne]),
      ]) {
        b.state = load(cards);
        await frames(tester, 3);
        await tap(const Offset(2, 2)); // the save's notes go, the popup stays
        expect(b.chestOpen, isTrue);
        await shot('$tag-$name-plain', 30);
        for (var i = 0; i < 3; i++) {
          await tap(b.chestCards[i].center);
          await shot('$tag-$name-armed-$i', 10);
        }
      }
    });
  }
}
