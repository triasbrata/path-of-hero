// The game is landscape only (decisions-log 289; lib/letterbox.dart, main.dart's landscapeOnly and gameRoot; ui-hud.md
// "Layouts"). A phone is locked sideways: AndroidManifest.xml's sensorLandscape, the web app's manifest, and
// SystemChrome's two landscape orientations asked before the first frame on Android and iOS (none elsewhere). A view
// taller than wide shows the landscape game across its width in a 1.5 rect between plain black bars, laid out at 915
// px wide at the least and scaled down to fit (letterboxFit; the insets as the game sees them, letterboxInsets); through
// gameRoot at 412x860, 390x844 and 700x900: the game's rect and size, the bars black and crisp at every state (the
// welcome screen, the book open, a wave with the log open, a Town, the mouse in a bar), the HUD inside its laid-out size
// with no piece over another, a tap, a hover, a drag and the wheel mapped through it, a tap or the mouse in a bar doing
// nothing; and a window resized across the line and back laid out as before, the same game going on. One TdGame per
// widget test.
//
// Never let a wave be won or the game end here: the board saves, into the queue's temp HOME (flutter_test_config.dart).
import 'dart:io';
import 'dart:math' show Point;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/letterbox.dart';
import 'package:tower_defense/main.dart';

import 'bag_chips_test.dart' show screenPixels;
import 'hud_font.dart';
import 'touch_hud_test.dart' show frames, on, pieces;
import 'town_hud_test.dart' show townGame;
import 'town_scene_test.dart' show bare, settle;
import 'town_scroll_test.dart' show drag;

/// The letterbox's test views: a phone upright (412x860, an iPhone's 390x844) and a desktop window dragged tall.
const tall = [Size(412, 860), Size(390, 844), Size(700, 900)];

const desk = Size(1266, 713);

final _shot = GlobalKey();

/// Boots one TdGame the way the app does ([gameRoot]: in its letterbox) in a [view] window, on the welcome screen.
Future<(TdGame, Board)> bootRoot(WidgetTester tester, Size view) async {
  tester.view
    ..physicalSize = view
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadHudFont(tester);
  final game = TdGame();
  await tester.pumpWidget(RepaintBoundary(key: _shot, child: gameRoot(game)));
  for (var i = 0; i < 3000 && !game.isLoaded; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(game.isLoaded, isTrue);
  await frames(tester, 10);
  return (game, game.board);
}

/// [a] is [b] to a millionth of a px each side.
void sameRect(Rect a, Rect b, String why) =>
    expect([a.left, a.top, a.right, a.bottom], [for (final v in [b.left, b.top, b.right, b.bottom]) closeTo(v, 1e-6)], reason: '$why: $a, $b');

/// [f] is ([rect], [layout], [scale]), to a millionth.
void fitIs(({Rect rect, Size layout, double scale}) f, Rect rect, Size layout, double scale, String why) {
  sameRect(f.rect, rect, why);
  expect([f.layout.width, f.layout.height, f.scale], [closeTo(layout.width, 1e-6), closeTo(layout.height, 1e-6), closeTo(scale, 1e-9)],
      reason: '$why: ${f.layout} ${f.scale}');
}

/// The Board laid out at [layout] (its size a Float32 Vector2: to a thousandth).
void laidOutAt(Board b, Size layout, String why) =>
    expect([b.size.x, b.size.y], [closeTo(layout.width, 1e-3), closeTo(layout.height, 1e-3)], reason: '$why: laid out at $layout');

/// Where the game's point [p] (its laid-out px) shows on a [view] window.
Offset toView(Size view, Offset p) {
  final f = letterboxFit(view);
  return f.rect.topLeft + p * f.scale;
}

/// The bars of a [view] window black, every pixel of their rows checked at every 3rd column, and the game's first and
/// last rows inside the rect drawn (the bars end on whole pixels).
Future<void> barsBlack(WidgetTester tester, Size view, String why) async {
  final px = await screenPixels(tester, _shot), r = letterboxFit(view).rect;
  final (top, bottom) = (r.top.round(), r.bottom.round());
  expect((top.toDouble(), bottom.toDouble()), (r.top, r.bottom), reason: '$why: on whole pixels');
  for (final y in [for (var y = 0; y < top; y++) y, for (var y = bottom; y < view.height; y++) y]) {
    for (var x = 0; x < view.width; x += 3) {
      if (px(x, y) != 0xFF000000) fail('$why: ($x, $y) is ${px(x, y).toRadixString(16)}, not the bars\' black');
    }
  }
  for (final y in [top, bottom - 1]) {
    expect([for (var x = 0; x < view.width; x += 3) px(x, y)].where((c) => c != 0xFF000000), isNotEmpty,
        reason: '$why: row $y, the game\'s own, drawn');
  }
}

/// The HUD's pieces inside the game's laid-out [size], none over another.
void hudFits(Board b, Size size, String why) {
  final at = pieces(b)..removeWhere((_, r) => r == Rect.zero);
  final names = at.keys.toList(), box = (Offset.zero & size).inflate(0.5);
  expect(names, containsAll(['counter', 'hearts', 'gold', 'toggle', 'x2', 'Auto', 'meter', 'log']), reason: why);
  for (final n in names) {
    expect(box.contains(at[n]!.topLeft) && box.contains(at[n]!.bottomRight), isTrue, reason: '$why: $n ${at[n]} inside $size');
  }
  for (var i = 0; i < names.length; i++) {
    for (var j = i + 1; j < names.length; j++) {
      expect(at[names[i]]!.overlaps(at[names[j]]!), isFalse, reason: '$why: ${names[i]} over ${names[j]}');
    }
  }
}

void main() {
  group('the lock', () {
    test('Android\'s activity turns sideways only (sensorLandscape), and so does the web app\'s manifest', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      final activity = RegExp(r'<activity\b[^>]*>').firstMatch(manifest)!.group(0)!;
      expect(activity, contains('android:name=".MainActivity"'));
      expect(activity, contains('android:screenOrientation="sensorLandscape"'));
      expect(RegExp('screenOrientation').allMatches(manifest), hasLength(1), reason: 'the one activity, nothing upright');
      expect(File('web/manifest.json').readAsStringSync(), contains('"orientation": "landscape"'));
    });

    testWidgets('landscapeOnly asks Android and iOS for their two landscape orientations, nothing elsewhere', (tester) async {
      final asked = <Object?>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') asked.add(call.arguments);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
      for (final platform in TargetPlatform.values) {
        asked.clear();
        await on(platform, landscapeOnly);
        final phone = platform == TargetPlatform.android || platform == TargetPlatform.iOS;
        expect(asked, phone ? [['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight']] : isEmpty, reason: '$platform');
      }
    });

    test('main asks for it before anything is drawn, and runs the game in its letterbox', () {
      final src = File('lib/main.dart').readAsStringSync();
      final start = src.indexOf('Future<void> main() async {'), body = src.substring(start, src.indexOf('\n}\n', start));
      expect(start, greaterThanOrEqualTo(0));
      final lock = body.indexOf('await landscapeOnly();'), run = body.indexOf('runApp(gameRoot(TdGame()));');
      expect((lock > 0, run > 0), (true, true), reason: body);
      expect(lock, lessThan(run), reason: 'locked before the first frame');
      expect(lock, lessThan(body.indexOf('_fullScreenOnPhone();')), reason: 'before the bars hide');
    });
  });

  group('the fit', () {
    test('a view as wide as tall or wider is the game\'s own, unscaled', () {
      for (final view in const [Size(1266, 713), Size(1600, 947), Size(1164, 777), Size(915, 412), Size(800, 800), Size(568, 320)]) {
        final f = letterboxFit(view, 2.625);
        expect((f.rect, f.layout, f.scale), (Offset.zero & view, view, 1.0), reason: '$view');
      }
    });

    test('a taller one: its width, 1.5 as wide as tall, centred, on whole physical px; laid out 915 wide at the least', () {
      fitIs(letterboxFit(const Size(412, 860)), const Rect.fromLTWH(0, 293, 412, 275), const Size(915, 275 * 915 / 412), 412 / 915, '412x860');
      fitIs(letterboxFit(const Size(390, 844)), const Rect.fromLTWH(0, 292, 390, 260), const Size(915, 260 * 915 / 390), 390 / 915, '390x844');
      fitIs(letterboxFit(const Size(700, 900)), const Rect.fromLTWH(0, 217, 700, 467), const Size(915, 467 * 915 / 700), 700 / 915, '700x900');
      fitIs(letterboxFit(const Size(1000, 1400)), const Rect.fromLTWH(0, 367, 1000, 667), const Size(1000, 667), 1.0, '1000x1400');
      for (final (view, dpr) in const [(Size(412, 860), 2.625), (Size(390, 844), 3.0), (Size(700, 900), 1.5), (Size(800, 801), 2.0), (Size(360, 2000), 4.0)]) {
        final f = letterboxFit(view, dpr), why = '$view at $dpr';
        expect((f.rect.left, f.rect.width), (0, view.width), reason: '$why: the view\'s width');
        expect(f.rect.width / f.rect.height, closeTo(letterboxAspect, letterboxAspect * 0.5 / (f.rect.height * dpr) + 1e-9), reason: '$why: ${f.rect}');
        expect((f.rect.top - (view.height - f.rect.bottom)).abs(), lessThanOrEqualTo(1 / dpr + 1e-9), reason: '$why: centred');
        for (final y in [f.rect.top, f.rect.bottom]) {
          expect(y * dpr, closeTo((y * dpr).roundToDouble(), 1e-6), reason: '$why: $y on a physical px');
        }
        expect(f.layout.width, greaterThanOrEqualTo(letterboxMinWidth - 1e-6), reason: why);
        expect([f.layout.width * f.scale, f.layout.height * f.scale], [closeTo(f.rect.width, 1e-6), closeTo(f.rect.height, 1e-6)],
            reason: '$why: drawn into its rect');
      }
    });

    test('the insets as the game sees them: as they are outside a letterbox; in one only where they reach into its rect, '
        'in its laid-out px', () {
      const pad = EdgeInsets.fromLTRB(10, 40, 12, 300);
      expect(letterboxInsets(desk, 1, pad), pad);
      final f = letterboxFit(const Size(412, 860)), seen = letterboxInsets(const Size(412, 860), 1, pad); // bars of 293 and 292
      expect([seen.left, seen.top, seen.right, seen.bottom], [closeTo(10 / f.scale, 1e-6), 0, closeTo(12 / f.scale, 1e-6), closeTo(8 / f.scale, 1e-6)]);
      expect(letterboxInsets(const Size(1000, 1400), 1, pad), const EdgeInsets.fromLTRB(10, 0, 12, 0));
    });
  });

  for (final view in tall) {
    final tag = '${view.width.round()}x${view.height.round()}';
    testWidgets('$tag: the game in its letterbox, the bars black at every state, the HUD laid out at 915 wide; a tap and a '
        'hover mapped through it, a tap or the mouse in a bar doing nothing', (tester) async {
      final (game, b) = await bootRoot(tester, view);
      final f = letterboxFit(view);
      sameRect(tester.getRect(find.byType(GameWidget<TdGame>)), f.rect, 'the game\'s rect');
      laidOutAt(b, f.layout, 'the letterbox');
      expect(f.layout.width, closeTo(letterboxMinWidth, 1e-6));
      expect(b.welcome, isNotNull);
      await barsBlack(tester, view, 'the welcome screen');

      b
        ..welcome = null
        ..miniMapOpen = false;
      final g = b.state = Game()..gold = 5000;
      await frames(tester, 40); // the book floats in
      expect(b.bookArea, isNot(Rect.zero), reason: 'the book open between waves');
      hudFits(b, f.layout, 'between waves');
      await barsBlack(tester, view, 'the book open');

      // A tap on x2, mapped: it takes it. Taps on the bars over and under it, and under the spawn bar: nothing.
      await tester.tapAt(toView(view, b.speedButton.center));
      await frames(tester, 3);
      expect(b.speed, 2, reason: 'x2 tapped through the letterbox');
      final before = (b.speed, g.paused, g.waveActive, b.bookPage, b.bookArea == Rect.zero, b.message, g.gold, g.armySize, b.pinned);
      final card = b.spawnBarCards.first.$1;
      for (final x in [toView(view, b.speedButton.center).dx, toView(view, card.center).dx, view.width / 2]) {
        for (final y in [f.rect.top / 2, f.rect.top - 1, f.rect.bottom + 1, (f.rect.bottom + view.height) / 2]) {
          await tester.tapAt(Offset(x, y));
          await frames(tester, 3);
        }
      }
      await frames(tester, 10);
      expect((b.speed, g.paused, g.waveActive, b.bookPage, b.bookArea == Rect.zero, b.message, g.gold, g.armySize, b.pinned), before,
          reason: 'a tap on a bar does nothing');
      b.speed = 1;

      // The mouse over Auto Buy, mapped: its tooltip. Down into the bar under it: gone, and no cursor drawn there.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset(view.width / 2, 2));
      await mouse.moveTo(toView(view, b.autoReplaceButton.center));
      await frames(tester, 30);
      expect(b.tooltipShown?.$1, Words.autoBuy, reason: 'hovered through the letterbox');
      await mouse.moveTo(Offset(toView(view, b.autoReplaceButton.center).dx, f.rect.bottom + 3));
      await frames(tester, 30);
      expect(b.tooltipShown, isNull, reason: 'the mouse in the bar: no tooltip');
      await barsBlack(tester, view, 'the mouse in the bar');
      await mouse.removePointer();

      // A wave, the log open: the HUD still fits, the bars still black.
      g.startWave();
      await frames(tester, 5);
      await tester.tapAt(toView(view, b.logButton.center));
      await frames(tester, 10);
      expect(b.logPanel, isNot(Rect.zero), reason: 'the log opened through the letterbox');
      hudFits(b, f.layout, 'in a wave');
      expect(b.logPanel.bottom, lessThanOrEqualTo(f.layout.height), reason: 'the log inside');
      await barsBlack(tester, view, 'a wave, the log open');
      b.state = Game(); // leave no wave to win
      await frames(tester, 10);
      expect(game.isLoaded, isTrue);
    });
  }

  testWidgets('700x900: a Town in the letterbox, its bars black; a drag and the wheel on its street pan it by what they '
      'moved in the game\'s px', (tester) async {
    const view = Size(700, 900);
    final (_, b) = await bootRoot(tester, view);
    final f = letterboxFit(view);
    b
      ..welcome = null
      ..autoStart.set(false);
    final g = b.state = townGame()
      ..wave = 5
      ..townAt = 7;
    g
      ..startWave()
      ..queue.clear()
      ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
    for (var i = 0; i < 600 && !g.inTown; i++) {
      await frames(tester, 1);
    }
    expect(g.inTown, isTrue);
    await settle(tester, b);
    await barsBlack(tester, view, 'a Town');
    final k = b.townK, at = toView(view, bare(b, f.layout));
    await frames(tester, 40);
    final was = b.townCam;
    // A finger's drag of 60 view px left: 60 / scale of the game's, less the Town's 8 px slop.
    await drag(tester, at, -60);
    expect(b.townCam, closeTo(was + (60 / f.scale - 8) / k, 0.01), reason: 'the drag in the game\'s px');
    await frames(tester, 40);
    // The wheel 40 px up: 40 / scale of the game's back.
    final mouse = TestPointer(9, PointerDeviceKind.mouse), now = b.townCam;
    await tester.sendEventToBinding(mouse.hover(at));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -40)));
    await frames(tester, 30);
    expect(b.townCam, closeTo(now - 40 / f.scale / k, 0.01), reason: 'the wheel in the game\'s px');
    await tester.sendEventToBinding(mouse.removePointer());
    await frames(tester, 10);
  });

  testWidgets('a window resized across the line and back: the letterbox comes and goes, the game laid out at each size '
      'as it is there, the HUD where it was, the same game going on', (tester) async {
    final (game, b) = await bootRoot(tester, desk);
    b
      ..welcome = null
      ..miniMapOpen = false;
    final g = b.state = Game()..gold = 5000;
    await frames(tester, 40);
    final hud = pieces(b), board = game.board;
    sameRect(tester.getRect(find.byType(GameWidget<TdGame>)), Offset.zero & desk, 'the desk');
    for (final view in const [Size(700, 900), Size(800, 800), Size(800, 801), Size(412, 860), Size(915, 412), desk]) {
      tester.view.physicalSize = view;
      await frames(tester, 40);
      final f = letterboxFit(view), tag = '$view';
      sameRect(tester.getRect(find.byType(GameWidget<TdGame>)), f.rect, tag);
      laidOutAt(b, f.layout, tag);
      expect((game.board, b.state), (board, g), reason: '$tag: the same game, not started again');
      hudFits(b, f.layout, tag);
    }
    expect(pieces(b), hud, reason: 'back at the desk: the HUD where it was');
  });
}
