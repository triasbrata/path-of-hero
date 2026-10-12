// The Town checkpoint (lib/wipe.dart, lib/wipe_ask.dart, decisions-log 333; ui-hud.md "An army wiped"): offscreen shots
// of the w89 save with its Town before wave 90 gone into and left, wave 90 lost, into <probe root>/shots/town-checkpoint/
// (`OUT`). A probe, not part of the suite (no `_test.dart`): queue `["test", "test/probe_town_checkpoint_shots.dart",
// "--dart-define=POH_PROBE_ROOT=<folder>"]` with the worktree as `dir`. It never touches the real save; the dice are
// seeded, the play at a fixed step, the player choosing ([autoTryAgain] off).
//
// At 1600x947 (`desk-`) and 915x412 (`phone-`): hop (the army down, the monsters hopping, the heart popped), ask (the
// dialog after the hop) and its 2x crop (`ask-zoom`), town (Try again: back in the Town, the "Weakened foes" chip under
// the meter) and its chip's 2x crop with the tooltip (`town-tip`), field (the Town left, wave 90 begun weakened), and
// over (another wipe, Give up: the game-over screen).
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/town-checkpoint');

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Game w89() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>,
    Random(89), Random(189), Random(389));

/// The next wave begun (none while one is on), and its army held at 1 HP beside werebears that don't fall until it is down.
void loseNext(Game g) {
  g.startWave();
  final bears = <Unit, Unit>{};
  for (var i = 0; i < 3600 && !g.wipedOut; i++) {
    for (final u in g.troops.where((u) => u.alive).toList()) {
      u
        ..hp = min(u.hp, 1)
        ..shield = 0
        ..ward = 0;
      if (!(bears[u]?.alive ?? false)) {
        g.units.add(bears[u] = Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, u.pos + const Point(10, 0))
          ..entered = true
          ..maxHp = 10000000
          ..hp = 1e7);
      }
    }
    g.paused = false; // the book never holds it
    g.tick(1 / 30);
  }
  g
    ..heroCasts.clear()
    ..monsterCasts.clear();
  expect(g.wipedOut, isTrue, reason: 'the army fell');
}

void main() {
  setUp(() => autoTryAgain = false);
  tearDown(() => autoTryAgain = true);

  for (final (name, size) in [('desk', const Size(1600, 947)), ('phone', const Size(915, 412))]) {
    testWidgets('town checkpoint shots ($name)', (tester) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(loadHudFontNow);
      final game = TdGame();
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key, child: GameWidget(game: game, overlayBuilderMap: {'name': (_, TdGame g) => const SizedBox.shrink()})));
      for (var i = 0; i < 3000 && !game.isLoaded; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(game.isLoaded, isTrue);
      final b = game.board
        ..welcome = null
        ..guideSeen = null // no guide card nor foe splash over the field
        ..miniMapOpen = false;
      b.autoStart.set(false);

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

      // The w89 save, its Town before wave 90 gone into and left: the checkpoint.
      final g = w89();
      if (g.townDue) {
        g
          ..enterTown()
          ..leaveTown();
      }
      g.townAt = g.wave + 1;
      expect((g.enterTown(), g.leaveTown()), (true, true));
      b.state = g;
      await frames(tester, 30);
      b.showMessage('', time: 0); // the save's one-time notes go
      final lives = g.lives, next = g.wave + 1;
      loseNext(g);
      await frames(tester, 20);
      // ignore: avoid_print
      print('$name: wave $next lost, lives $lives -> ${g.lives}, wave now ${g.wave} (lost ${g.lostWave}), town ${g.townAt} '
          'again ${g.townAgain}, weakened ${g.weakened}, ask ${g.wipeAsk}, note "${g.wipeNote}"');
      expect((g.lives, g.wave, g.townAgain, g.wipeAsk), (lives - wipeLives, next - 1, true, true));
      await save(await grab(), 'hop');
      await frames(tester, 160); // past the hop
      expect(b.wipeAskPanel, isNot(Rect.zero));
      final ask = await grab();
      await save(ask, 'ask');
      await zoom(ask, b.wipeAskPanel.expandToInclude(b.wipeAskRibbon).inflate(12), 'ask-zoom');

      // Try again (Enter): back into the Town, the chip under the meter, its tooltip.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      for (var i = 0; i < 600 && !g.inTown; i++) {
        await frames(tester, 1);
      }
      expect(g.inTown, isTrue);
      await frames(tester, 240); // past the fade and the name's ribbon
      await save(await grab(), 'town');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(b.weakChip.center);
      await frames(tester, 40);
      // ignore: avoid_print
      print('$name: chip ${b.weakChip}, meter ${b.waveMeter}, tooltip ${b.tooltipShown}');
      final tip = await grab();
      await zoom(tip, b.weakChip.inflate(8).expandToInclude(Rect.fromLTWH(b.weakChip.right - 380, b.weakChip.top, 380, 160)),
          'town-tip');
      await mouse.moveTo(Offset.zero);

      // The Town left, wave 90 begun weakened.
      g.leaveTown();
      await frames(tester, 90);
      g.startWave();
      for (var i = 0; i < 90; i++) {
        g.paused = false;
        g.tick(1 / 30);
        if (i % 10 == 0) await frames(tester, 1);
      }
      g
        ..heroCasts.clear()
        ..monsterCasts.clear();
      await frames(tester, 3);
      await save(await grab(), 'field');

      // Lost again (the wave on: no new one starts), and Give up (Esc): the game over.
      loseNext(g);
      await frames(tester, 200);
      expect(b.wipeAskPanel, isNot(Rect.zero));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(tester, 30);
      // ignore: avoid_print
      print('$name: gave up: over ${g.over}, wave ${g.wave}, reached ${g.waveReached}');
      expect(g.over, isTrue);
      await save(await grab(), 'over');
    });
  }
}
