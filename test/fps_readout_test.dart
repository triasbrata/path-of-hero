// The dev FPS readout (lib/fps_readout.dart, decisions-log 308): its meter, Settings' "Show FPS" (off by default, kept
// in settings.json, an old file without it loads off), and the readout clear of the HUD at every test window, between
// waves and in a wave, with the troops' list open.
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/settings.dart';

import 'hud_font.dart';

Future<Board> boot(WidgetTester tester, double w, double h) async {
  tester.view
    ..physicalSize = Size(w, h)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadHudFont(tester);
  final game = TdGame();
  await tester.pumpWidget(GameWidget(game: game));
  for (var i = 0; i < 3000 && !game.isLoaded; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(game.isLoaded, isTrue);
  return game.board
    ..welcome = null
    ..miniMapOpen = false;
}

Future<void> frames(WidgetTester tester, [int n = 2, int ms = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

void main() {
  group('FpsMeter', () {
    test('counts a second at a time: the frames it drew and its slowest one', () {
      final m = FpsMeter();
      for (var i = 0; i < 59; i++) {
        m.frame(1 / 60);
      }
      expect(m.text, isNull); // not a second yet
      m.frame(1 / 60);
      expect((m.fps, m.worstMs, m.text), (60, 17, '60 fps 17 ms'));
      // A stall: 30 frames and one of 0.5 s.
      for (var i = 0; i < 30; i++) {
        m.frame(1 / 60);
      }
      m.frame(0.5);
      expect((m.fps, m.worstMs), (31, 500));
      m.reset();
      expect((m.fps, m.text), (null, null));
    });
  });

  group('Settings.showFps', () {
    test('off by default, an old settings.json without it loads off, and it round-trips', () {
      expect(Settings().showFps, isFalse);
      expect(Settings.fromJson({'music': 50, 'autoStart': true}).showFps, isFalse);
      final on = Settings.fromJson(Settings(showFps: true).toJson());
      expect((on.showFps, on.toJson()['showFps']), (true, true));
      expect(Settings.fromJson({'showFps': 'yes'}).showFps, isFalse); // a broken value keeps the default
    });
  });

  for (final (w, h) in [(1600.0, 947.0), (1266.0, 713.0), (1164.0, 777.0), (915.0, 412.0)]) {
    testWidgets('"Show FPS" on the Settings page turns the readout on and off, kept in settings.json; it sits clear of '
        'the HUD (${w.round()}x${h.round()})', (tester) async {
      final b = await boot(tester, w, h);
      final g = b.state = Game(Random(1));
      for (final t in ['soldier', 'archer', 'priest']) {
        g.autoPlace(t);
      }
      await frames(tester);
      b.showSettings();
      await frames(tester, 40); // the book is open between waves
      // Off by default: nothing counted, nothing drawn.
      expect((loadSettings().showFps, b.fpsText, b.fpsReadout), (false, null, Rect.zero));
      // The toggle: on the left page, under the volume rows and over "How to Play".
      final button = b.fpsButton, volumes = b.volumeRows;
      expect(button.isEmpty, isFalse);
      expect(volumes.last.bottom < button.top, isTrue, reason: '${volumes.last} over $button at ${w}x$h');
      expect(button.bottom < b.howToButton.top, isTrue, reason: '$button over ${b.howToButton} at ${w}x$h');
      expect((button.left, button.right), (b.howToButton.left, b.howToButton.right));
      await tester.tapAt(button.center);
      await frames(tester, 70); // over a second of 16 ms frames
      expect(loadSettings().showFps, isTrue);
      expect(b.fpsText, matches(RegExp(r'^\d+ fps \d+ ms$')));

      // Clear of the HUD: the top band, the spawn bar, the book, the battle log's button, the off-view marker.
      void clear(String when) {
        final r = b.fpsReadout;
        expect(r.isEmpty, isFalse, reason: when);
        expect(Rect.fromLTWH(0, 0, w, h).intersect(r), r, reason: 'off the screen $when');
        final hud = {
          'counter': b.troopCounter,
          'hearts and gold': b.heartsGoldPanel,
          'book button': b.bookButton,
          'toggle': b.toggleButton,
          'speed': b.speedButton,
          'auto': b.autoButton,
          'wave meter': b.waveMeter,
          'spawn bar': b.spawnBarArea,
          'room': b.capacityButton,
          'auto buy': b.autoReplaceButton,
          'log button': b.logButton,
          'book': b.bookArea,
          'off-view': b.offViewMarker,
          'troop list': b.troopList,
          'boss bars': b.bossBars,
        };
        for (final MapEntry(:key, :value) in hud.entries) {
          expect(value.isEmpty || !value.overlaps(r), isTrue, reason: 'the readout $r over the $key $value $when at ${w}x$h');
        }
      }

      clear('between waves, the book open on Settings');
      // In a wave, the book shut, with the troop counter's list open.
      g.startWave();
      await frames(tester, 30);
      clear('in a wave');
      await tester.tapAt(b.troopCounter.center);
      await frames(tester, 3);
      expect(b.troopList.isEmpty, isFalse);
      clear('in a wave, the troops\' list open');
      await tester.tapAt(b.troopCounter.center);
      await frames(tester, 3);

      // Off again: nothing drawn, and settings.json says so.
      b.state = Game(Random(2));
      await frames(tester);
      b.showSettings();
      await frames(tester, 40);
      await tester.tapAt(b.fpsButton.center);
      await frames(tester, 70);
      expect((loadSettings().showFps, b.fpsText, b.fpsReadout), (false, null, Rect.zero));
    });
  }
}
