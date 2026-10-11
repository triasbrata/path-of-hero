import 'package:flame/game.dart' hide Game;
import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';

// The HUD on a touch device (decisions-log 215, docs/ui-hud.md "Layouts"): its scale capped at the desk's share of the
// screen's height, the screen's safe insets kept clear, the system bars hidden; the desktop's window the same since decisions-log 217
// (test/hud_sweep_test.dart sweeps every window size). The owner's tablet (Xiaomi Pad 8: 3200x2136 px at density 440) is 1164x777 logical px in landscape.

const desk = Size(1266, 713), wide = Size(915, 412);
const tablet = Size(1164, 777);

Future<Board> boot(WidgetTester tester) async {
  tester.view
    ..physicalSize = desk
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

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Runs [body] as on [platform] (the HUD asks [defaultTargetPlatform] every frame), and back.
Future<T> on<T>(TargetPlatform platform, Future<T> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    return await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// The HUD's pieces as drawn this frame, by name (Rect.zero: not drawn): the hearts-and-gold panel as its two parts, the
/// Start/Pause toggle whatever it does (decisions-log 220), the spawn bar (decisions-log 283).
Map<String, Rect> pieces(Board b) => {
      'counter': b.troopCounter,
      'hearts': b.livesBar,
      'gold': b.goldPanel,
      'book': b.bookButton,
      'toggle': b.toggleButton,
      'x2': b.speedButton,
      'Auto': b.autoButton,
      'meter': b.waveMeter,
      'log': b.logButton,
      // the spawn bar's hotbar, its arrows, +Room and Auto Buy, as one (decisions-log 283, 287)
      'bar': [b.spawnBarList, b.capacityButton, b.autoReplaceButton].where((r) => r != Rect.zero).fold(Rect.zero, (a, r) => a == Rect.zero ? r : a.expandToInclude(r)),
    };

/// A fresh game on a [size] screen, between waves with the book open (or in a wave), drawn a while.
Future<Map<String, Rect>> scene(WidgetTester tester, Board b, Size size, {bool wave = false}) async {
  tester.view.physicalSize = size;
  final g = b.state = Game();
  if (wave) g.startWave();
  await frames(tester, 40);
  return pieces(b);
}

/// The book as drawn: where it starts and how big, to a thousandth (it bobs up and down with the clock, which moves
/// its edges' last bits).
(double, double, double) bookOf(Board b) {
  double r(double v) => (v * 1000).roundToDouble() / 1000;
  return (r(b.bookArea.left), r(b.bookArea.width), r(b.bookArea.height));
}

void main() {
  testWidgets('a touch device\'s HUD takes no more of the screen\'s height than the desk\'s top band (44 of 713): the '
      'owner\'s tablet at 3, not 4; the desk, 915x412 and 1280x720 the same on the desktop', (tester) async {
    final b = await boot(tester);
    for (final (size, macK, touchK) in const [
      (desk, 3.0, 3.0),
      (wide, 2.0, 2.0),
      (Size(1280, 720), 3.0, 3.0),
      (tablet, 3.0, 3.0), // the owner's: 64 of 777 px (8.2%) before; the desktop's window the same since decisions-log 217
      (Size(1366, 1024), 3.0, 3.0), // a 12.9-inch tablet
      (Size(1920, 1080), 4.0, 4.0), // 64 of 1080 is 5.9%
    ]) {
      for (final wave in [false, true]) {
        final mac = await on(TargetPlatform.macOS, () async => (await scene(tester, b, size, wave: wave), b.hudScale, bookOf(b)));
        final touch = await on(TargetPlatform.android, () async => (await scene(tester, b, size, wave: wave), b.hudScale, bookOf(b)));
        expect((mac.$2, touch.$2), (macK, touchK), reason: '$size');
        if (macK == touchK) {
          expect(touch.$1, mac.$1, reason: '$size wave $wave: the same HUD');
          expect(touch.$3, mac.$3, reason: '$size wave $wave: the same book');
        }
        // The top band's share of the height: never more than the desk's on a touch device.
        final band = touch.$1['meter']!.height;
        expect(band, 20 * touchK - 16, reason: '$size');
        if (touchK > 2) expect(band / size.height, lessThanOrEqualTo(44 / 713), reason: '$size: $band px');
      }
    }
  });

  testWidgets('on the owner\'s tablet the HUD at 3 fits one row, nothing overlapping, and every button is 40 px or more '
      'each way', (tester) async {
    final b = await boot(tester);
    await on(TargetPlatform.android, () async {
      for (final wave in [false, true]) {
        final at = await scene(tester, b, tablet, wave: wave)
          ..removeWhere((_, r) => r == Rect.zero);
        final names = at.keys.toList();
        for (var i = 0; i < names.length; i++) {
          for (var j = i + 1; j < names.length; j++) {
            expect(at[names[i]]!.overlaps(at[names[j]]!), isFalse, reason: 'wave $wave: ${names[i]} and ${names[j]}');
          }
        }
        for (final name in ['counter', 'x2', 'book', 'toggle', 'Auto', 'meter', 'log']) {
          final r = at[name];
          if (r == null) continue;
          expect((r.width >= 40, r.height >= 40), (true, true), reason: 'wave $wave: $name $r');
        }
        expect(at['meter']!.top, at['hearts']!.top, reason: 'one row');
        expect(at['meter']!.right, tablet.width - 10);
      }
    });
  });

  testWidgets('a phone\'s HUD keeps inside the screen\'s safe insets (a notch, the bars while they show); the desktop\'s '
      'ignores them', (tester) async {
    final b = await boot(tester);
    // As Android would hand them over with the status bar (33) and a cutout on each side; device px at 2.75 per px.
    const dpr = 2.75, l = 48.0, t = 33.0, r = 40.0, bt = 16.0;
    tester.view
      ..devicePixelRatio = dpr
      ..viewPadding = const FakeViewPadding(left: l * dpr, top: t * dpr, right: r * dpr, bottom: bt * dpr);
    addTearDown(tester.view.resetViewPadding);
    Future<Map<String, Rect>> at(Size size, {bool wave = false}) async {
      tester.view.physicalSize = size * dpr;
      final g = b.state = Game();
      if (wave) g.startWave();
      await frames(tester, 40);
      return pieces(b)..removeWhere((_, r) => r == Rect.zero);
    }

    await on(TargetPlatform.android, () async {
      for (final wave in [false, true]) {
        final hud = await at(tablet, wave: wave), k = b.hudScale, pad = 2 * k;
        expect((b.safeInsets, k), (const EdgeInsets.fromLTRB(l, t, r, bt), 3.0));
        expect(hud['hearts']!.top, t + 10, reason: 'the top band under the top inset');
        expect(hud['counter']!.deflate(pad).left, l + 10, reason: 'the counter right of the left one');
        expect((hud['meter']!.top, hud['meter']!.right), (t + 10, tablet.width - r - 10), reason: 'the meter left of the right one');
        final log = hud['log']!.deflate(pad);
        expect((log.right, log.bottom), (tablet.width - r - 10, tablet.height - bt - 10), reason: 'the log above the bottom one');
        for (final MapEntry(:key, :value) in hud.entries) {
          final drawn = const {'counter', 'log'}.contains(key) ? value.deflate(pad) : value; // their press areas are bigger
          expect(drawn.left >= l && drawn.top >= t && drawn.right <= tablet.width - r && drawn.bottom <= tablet.height - bt, isTrue,
              reason: 'wave $wave: $key $drawn');
        }
        if (!wave) {
          final book = b.bookArea;
          expect((book.right <= tablet.width - r, book.bottom <= tablet.height - bt, book.top > hud['meter']!.bottom), (true, true, true),
              reason: '$book');
        }
      }
    });

    // The desktop takes none: its HUD where it is without them.
    final (withPadding, insets) = await on(TargetPlatform.macOS, () async => (await at(desk), b.safeInsets));
    tester.view.resetViewPadding();
    final without = await on(TargetPlatform.macOS, () => at(desk));
    expect(insets, EdgeInsets.zero);
    expect(withPadding, without);
  });

  testWidgets('a phone asks for full screen (the bars hidden, a swipe shows them a moment) whenever the app comes back to '
      'the front; the desktop\'s window is left alone', (tester) async {
    final b = await boot(tester);
    final asked = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      asked.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    bool fullScreen() => asked.any((c) => c.method == 'SystemChrome.setEnabledSystemUIMode' && c.arguments == 'SystemUiMode.immersiveSticky');
    for (final (platform, phone) in const [(TargetPlatform.android, true), (TargetPlatform.iOS, true), (TargetPlatform.macOS, false)]) {
      asked.clear();
      await on(platform, () async {
        b.game.lifecycleStateChange(AppLifecycleState.resumed);
        await frames(tester);
      });
      expect(fullScreen(), phone, reason: '$platform');
    }
  });
}
