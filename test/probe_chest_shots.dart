// Peti Bos seen (decisions-log 152, ui-hud.md "Boss Chest"): offscreen shots of the boss chest's popup and its "Peti!"
// chip, into <probe root>/shots/peti-bos/ (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_chest_shots.dart"]` with the worktree as `dir`. It never touches the real save
// (flutter_test_config.dart's temp dir); the dice are seeded, so a rerun gives the same shots.
//
// At 1266x713, 1164x777, 915x412, 412x860 and 1600x947, from the owner's wave-86 save (the fixture: its five Pusaka
// bound by default, and its 3 catch-up chests): chest-<size> (the first catch-up chest open, nothing picked: the row's
// Take greyed), picked-<size> (a card picked: lifted and lit, Take green; decisions-log 281), next-<size> (after the
// take: the second chest, the message), cheer-<size> (a boss win's cheer at wave 90, its chest waiting: the "Chest!"
// chip under Start, a fresh army at wave 5) and start-<size> (Start pressed in that cheer: the chest opens, no wave starts;
// decisions-log 281); at 1600 and 412 the same win on the w86 save, which makes a new Hero: herostart-<size> (Start
// pressed in the cheer: nothing opens, no wave), hero-<size> (the Hero's splash after the cheer) and herochest-<size>
// (the splash closed: the chest); and at 1266 moved (the pick moved to the third card), boss (a boss chest of three Langka cards, at wave 90) and tas (the Tas page, decisions-log
// 151, with Iron Banner ★2 in the Gudang and picked: its slot among the nine Pusaka, the type rows' gist).
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/peti-bos');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The fixture (the owner's w86 save from before the Pusaka and the chest).
Game load() {
  final save = jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>;
  return Game.fromJson(save, Random(seed), Random(seed + 100), Random(seed + 300))
    ..loot = Random(seed + 200)
    ..draft = Random(seed + 500)
    ..boardRules();
}

void main() {
  for (final size in const [Size(1266, 713), Size(1164, 777), Size(915, 412), Size(412, 860), Size(1600, 947)]) {
    final tag = '${size.width.round()}';
    testWidgets('chest shots $tag', (tester) async {
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

      // The Tas page with a Langka in the Gudang, picked.
      Future<void> tas() async {
        b.state = load()
          ..chests.clear()
          ..givePusaka(Relic.ironBanner, stars: 2);
        await frames(tester, 3);
        if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
        await tap(b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
        await tap(b.bagSlot(Relic.ironBanner).center);
        await shot('tas-$tag', 40);
      }

      final g = b.state = load();
      await frames(tester, 3);
      await tap(const Offset(2, 2)); // the save's notes go, the popup stays
      // ignore: avoid_print
      print('chests ${g.chests.length}: ${g.chest?.title} ${g.chest?.cards}; gold ${g.gold}');
      await shot('chest-$tag', 30);
      await tap(b.chestButtons['take']!.center); // greyed: nothing happens
      await tap(b.chestCards.first.center);
      // ignore: avoid_print
      print('picked ${b.chestPicked}; buttons ${b.chestButtons}; cards ${b.chestCards}');
      await shot('picked-$tag', 10);
      if (tag == '1266') {
        await tap(b.chestCards.last.center);
        await shot('moved', 10);
      }
      await tap(b.chestButtons['take']!.center);
      await shot('next-$tag', 6);
      // A boss win's cheer with its chest waiting (the chip under Start), then Start pressed in it: the chest opens and no
      // wave starts (decisions-log 281). A fresh army at the first boss (wave 5), so no new Hero is due.
      Future<Game> bossWin(Game w) async {
        b.state = w;
        await frames(tester, 3);
        if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
        w
          ..startWave()
          ..queue.clear()
          ..units.add(w.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
        await frames(tester, 3);
        return w;
      }

      void note(String what, Game w) {
        // ignore: avoid_print
        print('$what $tag: wave ${w.wave} chests ${w.chests.length} open ${b.chestOpen} waveActive ${w.waveActive} '
            'cheer ${(w.t - w.victoryAt).toStringAsFixed(2)} chip ${b.chestChip} hero ${b.heroSplash}');
      }

      final fresh = Game(Random(seed), Random(seed + 100)).boardRules()
        ..armyMax = null
        ..gold = 200000
        ..wave = 4 // the first boss win: no Hero is made at it (at wave 90 one is)
        ..draft = Random(seed + 500);
      for (final type in ['soldier', 'archer', 'knight', 'soldier', 'archer', 'knight']) {
        fresh.autoPlace(type);
      }
      for (final u in fresh.troops) {
        u
          ..pos = u.post
          ..arriving = false;
      }
      final w = await bossWin(fresh);
      note('cheer', w);
      await shot('cheer-$tag', 6);
      await tap(b.startButton.center);
      note('start pressed', w);
      await shot('start-$tag', 30);
      if (tag == '1600' || tag == '412') {
        // The owner's w86 save at a boss win that makes a new Hero: Start in the cheer opens nothing and starts no wave;
        // after the cheer the Hero's splash, and once it is closed the chest.
        final h = await bossWin(load()
          ..chests.clear()
          ..wave = 89);
        await tap(b.startButton.center);
        note('hero start pressed', h);
        await shot('herostart-$tag', 6);
        for (var i = 0; i < 300 && b.heroSplash == null; i++) {
          await frames(tester, 1);
        }
        note('hero splash', h);
        await shot('hero-$tag', 20);
        await tap(const Offset(4, 4)); // closes the splash
        note('splash closed', h);
        await shot('herochest-$tag', 30);
      }
      if (tag != '1266') return;
      // A boss chest of three Langka cards at wave 90.
      final h = b.state = load()
        ..wave = 90
        ..chests.clear()
        ..chests.add(Chest(ChestKind.boss, 90, cards: [Relic.ironBanner, Relic.bloodFang, Relic.mourningBell]));
      await frames(tester, 3);
      await tap(const Offset(2, 2));
      // ignore: avoid_print
      print('boss chest: ${h.chest?.cards}');
      await shot('boss', 30);
      await tas();
    });
  }
}
