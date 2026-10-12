// An army wiped mid-wave (lib/wipe.dart, decisions-log 322; ui-hud.md "An army wiped"): offscreen shots of the w89
// save's wave 90 as its army falls, into <probe root>/shots/wipe/ (`OUT`). A probe, not part of the suite (no
// `_test.dart`): queue `["test", "test/probe_wipe_shots.dart"]` with the worktree as `dir`. It never touches the real
// save (flutter_test_config.dart's temp dir); the dice are seeded and the play is at a fixed step.
//
// It writes, at 1600x947 (`desk-`) and 915x412 (`phone-`): pop (the heart popping as the last troop falls, the monsters
// hopping, the message), hop (a second on), after (the hop over: the field swept, the message, the meter's next wave),
// and 2x crops of the hearts (`-hearts`) and the message (`-msg`) of pop.
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

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/wipe');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Game w89() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>,
    Random(89), Random(189), Random(389));

void main() {
  for (final (name, size) in [('desk', const Size(1600, 947)), ('phone', const Size(915, 412))]) {
    testWidgets('wipe shots ($name)', (tester) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(loadHudFontNow);
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
        ..guideSeen = null // no guide card nor foe splash over the field
        ..miniMapOpen = false;

      Future<ui.Image> grab() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        return (await tester.runAsync(() => boundary.toImage()))!;
      }

      Future<void> save(ui.Image img, String file) async {
        await tester.runAsync(() async {
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name-$file.png')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
        // ignore: avoid_print
        print('wrote $out/$name-$file.png ${img.width}x${img.height}');
      }

      /// [src] cut to [crop] and scaled 2x, pixel for pixel.
      Future<void> zoom(ui.Image src, Rect crop, String file) async {
        final c = crop.intersect(Offset.zero & size);
        final img = await tester.runAsync(() {
          final rec = ui.PictureRecorder();
          Canvas(rec).drawImageRect(src, c, Offset.zero & (c.size * 2), Paint()..filterQuality = FilterQuality.none);
          return rec.endRecording().toImage((c.width * 2).round(), (c.height * 2).round());
        });
        await save(img!, file);
      }

      final g = b.state = w89();
      await frames(tester, 30);
      b.showMessage('', time: 0); // the save's one-time notes go
      if (g.townDue) {
        g
          ..enterTown()
          ..leaveTown();
      }
      final lives = g.lives, next = g.wave + 1;
      g.startWave();
      await frames(tester, 2);
      // 12 s of the wave at a fixed step, the casts' pops drained so no banner covers the field.
      // ignore: avoid_print
      print('$name: wave ${g.wave} started, ${g.troops.where((u) => u.alive).length} troops, paused ${g.paused}');
      for (var s = 0.0; s < 12 && !g.wipedOut; s += 0.5) {
        for (var i = 0; i < 15 && !g.wipedOut; i++) {
          g.paused = false;
          g.tick(1 / 30);
        }
        g
          ..heroCasts.clear()
          ..monsterCasts.clear();
        await frames(tester, 1);
      }
      // Then each troop left, at 1 HP, meets a werebear beside it.
      for (final u in g.troops.where((u) => u.alive).toList()) {
        u
          ..hp = 1
          ..shield = 0;
        g.units.add(Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, u.pos + const Point(10, 0))..entered = true);
      }
      for (var i = 0; i < 1200 && !g.wipedOut; i++) {
        g.paused = false; // the book never holds it
        g.tick(1 / 30);
        if (i % 150 == 149) {
          final left = g.troops.where((u) => u.alive).toList();
          // ignore: avoid_print
          print('$name t ${g.t.toStringAsFixed(1)}: ${left.length} troops left ${[for (final u in left.take(4)) '${u.type} ${u.hp.toStringAsFixed(0)} at ${u.pos}']}, '
              'foes ${g.enemies.where((u) => u.alive).length}, active ${g.waveActive}, over ${g.over}');
          for (final u in left) {
            u.hp = min(u.hp, 1); // healed back up: down to 1 again
          }
        }
      }
      expect(g.wipedOut, isTrue, reason: 'the army fell');
      g
        ..heroCasts.clear()
        ..monsterCasts.clear();
      await frames(tester, 5);
      // ignore: avoid_print
      print('$name: wave $next lost, lives $lives -> ${g.lives}, wave now ${g.wave} (lostWave ${g.lostWave}), swept ${g.swept.length}, '
          'message "${b.message}", auto ${b.autoStart.left}, toReplace ${g.toReplace.length}, over ${g.over}');
      expect((g.lives, g.wave, g.lostWave, g.over), (lives - wipeLives, next - 1, next, false));
      expect(b.message, g.wipeNote);
      final pop = await grab();
      await save(pop, 'pop');
      await zoom(pop, b.livesBar.inflate(8), 'pop-hearts');
      await zoom(pop, b.messageBox.inflate(8), 'pop-msg');
      await frames(tester, 60);
      await save(await grab(), 'hop');
      await frames(tester, 120); // past the hop: the swept monsters gone
      expect(g.swept, isEmpty);
      // ignore: avoid_print
      print('$name after: message "${b.message}", enemies ${g.enemies.length}, canStart ${g.canStartWave}');
      await save(await grab(), 'after');
    });
  }
}
