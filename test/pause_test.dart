import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/auto_start.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/sounds.dart';

import 'hud_font.dart';

// The pause (#93, lib/pause.dart; ui-hud.md "Pause"): no panel, the field dimmed under "Pause", and the HUD and the
// book still at work while the game waits (troops bought and placed, items and relics given by tap and by drag);
// the book pausing a wave when the player opens it by its button,
// and resuming it when it paused it; the auto start waiting on the book's other pages between waves; on the desktop the window's focus
// pausing nothing, and a timer running the game while it is hidden; on a phone the background pausing the game
// (decisions-log 146) and holding its sound (decisions-log 147). One TdGame per widget test, pressed with
// tester.tapAt / startGesture.
//
// Never let a wave be won or the game end here (the Board then saves): the waves here are never won (their one
// monster stands still), and their troops stand still.

/// Boots one TdGame in a 1266x713 window, past the welcome screen, with the game's font and the minimap folded.
Future<(TdGame, Board)> boot(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1266, 713)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadHudFont(tester);
  final game = TdGame();
  await tester.pumpWidget(GameWidget(game: game));
  for (var i = 0; i < 3000 && !game.isLoaded; i++) {
    // onLoad decodes images in real time: let it run, then pump.
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(game.isLoaded, isTrue);
  return (
    game,
    game.board
      ..welcome = null
      ..miniMapOpen = false
  );
}

/// Advances the game [n] frames.
Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> tapOn(WidgetTester tester, Rect r) async {
  expect(r, isNot(Rect.zero));
  await tester.tapAt(r.center);
  await frames(tester);
}

/// A troop of [type] standing still at ([x], [y]) on [g]'s field.
Unit troopAt(Game g, String type, double x, double y) {
  final u = Unit(Side.troop, type, g.statsOf(type), Point(x, y))
    ..entered = true
    ..arriving = false
    ..stunUntil = 1e9;
  g.units.add(u);
  return u;
}

/// [g] with a wave on that is never won: its queue emptied, and one orc far out that stands still.
Game waveOn(Game g) {
  g
    ..startWave()
    ..queue.clear()
    ..waveSpawned = 30;
  g.units.add(g.monster('orc', Tier.normal, const Point(260, 60))
    ..entered = true
    ..stunUntil = 1e9);
  return g;
}

/// Where to point at [u] on the screen: just above its feet.
Offset at(Board b, Unit u) => b.toScreen(u.pos.x, u.pos.y - 3);

/// The book's tab for [page] ('troops', 'bag', 'settings').
Rect tab(Board b, String page) => b.bookTabs.firstWhere((t) => t.$1 == page).$2;

/// Whether the game ran over [n] frames: its clock went on.
Future<bool> runs(WidgetTester tester, Board b, [int n = 5]) async {
  final t = b.state.t;
  await frames(tester, n);
  return b.state.t > t;
}

/// The app's lifecycle as the engine tells it ([SystemChannels.lifecycle]); the binding steps through the states
/// between, and turns frames off while hidden or paused.
Future<void> lifecycle(WidgetTester tester, AppLifecycleState s) async {
  await tester.binding.defaultBinaryMessenger
      .handlePlatformMessage(SystemChannels.lifecycle.name, SystemChannels.lifecycle.codec.encodeMessage(s.toString()), (_) {});
}

/// What would be heard ([Sounds.output]; a test can't load SoLoud's native library): the loop playing and each
/// loop's volume, whether everything is held, and the effects played.
class FakeOutput implements SoundOutput {
  final volume = <Music, double>{}, effects = <Sfx>[];
  Music? playing;
  bool held = false;
  int starts = 0; // a loop started over (or reloaded) loses its place

  /// The music's volume as heard: none while held.
  double get music => held || playing == null ? 0 : volume[playing]!;

  @override
  Future<void> open() async {}

  @override
  void start(Music m, double v) {
    starts++;
    playing = m;
    volume[m] = v;
  }

  @override
  void effect(Sfx s, double v) => effects.add(s);

  @override
  void fade(Music m, double v, Duration time) => volume[m] = v;

  @override
  void crossFade(Music from, Music to, double v, Duration time) {
    volume[from] = 0;
    playing = to;
    volume[to] = v;
  }

  @override
  void hold(bool on) => held = on;
}

/// The sound through a [FakeOutput] for this test, from [Sounds.init] on; after it, back in the foreground at full
/// volumes, the game's own output again (silent in tests).
Future<FakeOutput> listen() async {
  final before = Sounds.output, out = FakeOutput();
  Sounds.output = out;
  Sounds.forgetPlayed(); // the effects' gaps run on the real clock: the last test's play may be a moment ago
  addTearDown(() {
    Sounds.background(false);
    Sounds.volumes(1, 1);
    Sounds.output = before;
  });
  await Sounds.init();
  return out;
}

/// Where the welcome screen's "Lanjutkan" is on a [size] screen (lib/welcome.dart's layout).
Offset lanjutkan(Size size) {
  final u = min(1.0, min(size.width / 600, size.height / 540)), top = size.height * 0.38 - 201 * u;
  return Offset(size.width / 2, top + 120 * u + 28 * u);
}

void main() {
  testWidgets('paused, the field dims under "Pause" at its top centre, clear of the HUD, which still takes presses; '
      'a tap on the field doesn\'t resume', (tester) async {
    final (_, b) = await boot(tester);
    for (final size in const [Size(1266, 713), Size(915, 412)]) {
      for (final midWave in [false, true]) {
        final why = '$size${midWave ? ', mid-wave' : ''}';
        tester.view.physicalSize = size;
        final g = b.state = Game();
        if (midWave) waveOn(g);
        b.miniMapOpen = false;
        await frames(tester, 40); // the book floats in between waves
        expect(b.pauseTitle, Rect.zero, reason: why);
        // Between waves the Start/Pause toggle starts the wave: P pauses there; mid-wave the toggle does.
        if (midWave) {
          await tapOn(tester, b.pauseButton);
        } else {
          await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
        }
        await frames(tester, 10); // "Pause" pops in
        expect(g.paused, isTrue, reason: why);
        final title = b.pauseTitle;
        expect(title, isNot(Rect.zero), reason: why);
        expect(title.height, greaterThanOrEqualTo(20), reason: why);
        // At the top centre (right of the book's tabs where they reach it: 915x412).
        expect(title.center.dx, inInclusiveRange(size.width / 3, size.width * 2 / 3), reason: '$why: at the top centre');
        expect((title.top >= 0, title.bottom <= size.height), (true, true), reason: '$why: on the field');
        final hud = <String, Rect>{
          'the counter': b.troopCounter,
          'the hearts': b.livesBar,
          'the gold': b.goldPanel,
          'x2': b.speedButton,
          'the toggle': b.toggleButton,
          'the book button': b.bookButton,
          'Auto': b.autoButton,
          'the meter': b.waveMeter,
          'the map': b.miniMap,
          'the log': b.logButton,
          for (final (page, r) in b.bookTabs) 'the $page tab': r,
          'the book': b.bookArea,
        };
        for (final MapEntry(key: what, value: r) in hud.entries) {
          expect(title.overlaps(r), isFalse, reason: '$why: clear of $what');
        }

        // No panel over it: the HUD and the book still take presses.
        await tapOn(tester, b.speedButton);
        expect(b.speed, 2, reason: why);
        await tapOn(tester, b.speedButton);
        expect(b.speed, 1, reason: why);
        if (!midWave) {
          await tapOn(tester, tab(b, 'bag'));
          expect(b.bagOpen, isTrue, reason: '$why: the Tas page');
          await tapOn(tester, tab(b, 'troops'));
        }
        // A tap on bare field neither covered nor resumes.
        final field = b.toScreen(b.camX + g.viewW * 0.25, 8);
        expect(b.coveredAt(field), isFalse, reason: why);
        await tapOn(tester, Rect.fromCenter(center: field, width: 2, height: 2));
        expect((g.paused, b.pauseTitle == Rect.zero), (true, false), reason: '$why: still paused');

        // Esc and P resume and pause; so does the toggle (pause_test's book tests).
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await frames(tester);
        expect((g.paused, b.pauseTitle), (false, Rect.zero), reason: why);
        expect(await runs(tester, b), isTrue, reason: why);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
        await frames(tester);
        expect(g.paused, isTrue, reason: why);
        expect(await runs(tester, b), isFalse, reason: why);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
        await frames(tester);
        expect(g.paused, isFalse, reason: why);
      }
    }
    b.miniMapOpen = false;
  });

  testWidgets('paused mid-wave, the book gives items and relics by tap and by drag and buys and places troops; nothing '
      'moves until Esc', (tester) async {
    final (_, b) = await boot(tester);
    final g = b.state = Game()
      ..units.clear()
      ..gold = 10000;
    final aldo = troopAt(g, 'knight', 40, 50), bima = troopAt(g, 'knight', 40, 90);
    troopAt(g, 'priest', 15, 70);
    waveOn(g);
    g.inventory[Item.sword] = 3;
    g.relicBag[Relic.fang] = 2;
    await frames(tester, 30); // past the toggle's guard after a wave starts (start_button.dart)
    await tapOn(tester, b.pauseButton); // the player pauses, then opens the book
    await tapOn(tester, b.bookButton);
    await frames(tester, 30); // it opens
    expect((g.paused, b.bookArea == Rect.zero), (true, false));
    final t = g.t, where = [for (final u in g.units) u.pos];

    // An item: picked in the bag, given from the Tas list's row, then dragged onto a knight on the field.
    await tapOn(tester, tab(b, 'bag'));
    await tapOn(tester, b.bagSlot(Item.sword));
    expect(b.picked, Item.sword);
    await tapOn(tester, b.bagAction(BagAction.giveTroops)); // its type rows (decisions-log 202)
    await tapOn(tester, b.assignRows.firstWhere((r) => r.$1 == 'knight').$2);
    expect((g.countOf('knight', Item.sword), g.inventory[Item.sword]), (1, 2));
    final drag = await tester.startGesture(b.bagSlot(Item.sword).center);
    await drag.moveBy(const Offset(-30, 0));
    await frames(tester);
    await drag.moveTo(at(b, aldo));
    await frames(tester);
    expect(b.dropFor, aldo); // the drop popup tells about it
    await drag.up();
    await frames(tester);
    expect((g.countOf('knight', Item.sword), g.inventory[Item.sword]), (2, 1));

    // A relic: from the list's row to one knight, then dragged onto the other.
    await tapOn(tester, b.bagSlot(Relic.fang));
    expect(b.picked, Relic.fang);
    await tapOn(tester, b.bagAction(BagAction.equip));
    await tapOn(tester, b.assignRows.firstWhere((r) => r.$1 == aldo).$2);
    expect(g.relicBag[Relic.fang], 1);
    final relic = await tester.startGesture(b.bagSlot(Relic.fang).center);
    await relic.moveBy(const Offset(-30, 0));
    await frames(tester);
    await relic.moveTo(at(b, bima));
    await frames(tester);
    expect(b.dropFor, bima);
    await relic.up();
    await frames(tester);
    expect(g.relicBag[Relic.fang], 0);

    // A troop bought from the spawn bar (decisions-log 283): on the field at once, and it waits there.
    final gold = g.gold, count = g.troops.length;
    await tapOn(tester, b.spawnCard('soldier'));
    expect((g.troops.length, g.gold < gold), (count + 1, true));
    final soldier = g.troops.last, placed = soldier.pos;
    await frames(tester, 20);
    expect(soldier.pos, placed);

    // All the while nothing moved and the clock stood.
    expect((g.paused, g.t), (true, t));
    expect([for (final u in g.units.take(where.length)) u.pos], where);
    // The book shut: still paused (the player paused it, not the book). Esc resumes.
    await tapOn(tester, b.bookButton);
    await frames(tester, 30);
    expect((g.paused, b.bookArea), (true, Rect.zero));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await frames(tester);
    expect(g.paused, isFalse);
    expect(await runs(tester, b), isTrue);
    expect(soldier.pos, isNot(placed)); // it marches in now
  });

  testWidgets('between waves, paused, a troop is dragged to another cell of the zone', (tester) async {
    final (_, b) = await boot(tester);
    final g = b.state = Game();
    await frames(tester, 40);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP); // (the toggle starts the wave between waves)
    await frames(tester);
    final priest = g.troops.single, from = priest.post, step = from.y < fieldH / 2 ? tile : -tile;
    final drag = await tester.startGesture(b.toScreen(from.x, from.y));
    await drag.moveBy(Offset(0, step / 2));
    await frames(tester);
    await drag.moveTo(b.toScreen(from.x, from.y + step)); // the next cell up or down
    await frames(tester);
    await drag.up();
    await frames(tester);
    expect(g.paused, isTrue);
    expect(priest.post, Point(from.x, from.y + step)); // its new spot
  });

  testWidgets('opening the book mid-wave pauses the game and shutting it resumes it; paused first, it stays paused; '
      'Menu Utama leaves it paused', (tester) async {
    final (_, b) = await boot(tester);
    for (final size in const [Size(1266, 713), Size(915, 412)]) {
      tester.view.physicalSize = size;
      final g = b.state = waveOn(Game());
      await frames(tester, 10);
      expect(await runs(tester, b), isTrue, reason: '$size');

      // The book opened: paused ("Pause" shows), whichever page; shut: running again.
      await tapOn(tester, b.bookButton);
      expect((g.paused, b.pauseTitle == Rect.zero), (true, false), reason: '$size');
      await frames(tester, 30);
      await tapOn(tester, tab(b, 'bag'));
      expect(await runs(tester, b), isFalse, reason: '$size');
      await tapOn(tester, b.bookButton);
      expect(g.paused, isFalse, reason: '$size');
      expect(await runs(tester, b, 30), isTrue, reason: '$size');

      // Opened again, the toggle (or Esc) resumes with the book open; shutting it then changes nothing.
      for (final resume in ['the toggle', 'Esc']) {
        await tapOn(tester, b.bookButton);
        await frames(tester, 30);
        expect(g.paused, isTrue, reason: '$size');
        if (resume == 'Esc') {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await frames(tester);
        } else {
          await tapOn(tester, b.pauseButton);
        }
        expect((g.paused, b.bookArea == Rect.zero), (false, false), reason: '$size: $resume');
        expect(await runs(tester, b), isTrue, reason: '$size: $resume');
        await tapOn(tester, b.bookButton);
        await frames(tester, 30);
        expect((g.paused, b.bookArea), (false, Rect.zero), reason: '$size: $resume');
      }

      // Paused first: the book opened and shut again leaves it paused.
      await tapOn(tester, b.pauseButton);
      await tapOn(tester, b.bookButton);
      await frames(tester, 30);
      await tapOn(tester, b.bookButton);
      await frames(tester, 30);
      expect(g.paused, isTrue, reason: '$size: paused first');
      await tapOn(tester, b.pauseButton);
      expect(g.paused, isFalse, reason: '$size');

      // Menu Utama from the Pengaturan page (the book paused the game): "Lanjutkan" comes back to it paused, and
      // now the player's pause: shutting the book leaves it paused.
      await tapOn(tester, b.bookButton);
      await frames(tester, 30);
      await tapOn(tester, tab(b, 'settings'));
      await tapOn(tester, b.menuButton);
      expect(b.welcome, isNotNull, reason: '$size');
      await tester.tapAt(lanjutkan(size));
      await frames(tester, 5);
      expect((b.welcome, g.paused), (null, true), reason: '$size: back, paused');
      await tapOn(tester, b.bookButton);
      await frames(tester, 30);
      expect(g.paused, isTrue, reason: '$size: the menu\'s pause is the player\'s');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(tester);
      expect(g.paused, isFalse, reason: '$size');
    }
  });

  testWidgets('between waves the auto start waits on Tas and Pengaturan and runs on Pasukan (the field\'s Toko, which '
      'held it too, went in decisions-log 296)', (tester) async {
    final (_, b) = await boot(tester);
    final g = b.state = Game()..wave = storeFrom;
    await frames(tester, 40); // the book floats in
    b.autoStart
      ..set(true)
      ..won();
    for (final page in ['bag', 'settings']) {
      await tapOn(tester, tab(b, page));
      await frames(tester, 130); // 2 s
      expect((b.autoStart.shown, g.paused), (autoStartDelay.round(), false), reason: page);
    }
    await tapOn(tester, tab(b, 'troops'));
    await frames(tester, 130);
    expect(b.autoStart.shown, 3);
    b.autoStart.set(false);
    await frames(tester, 5); // past the tap's own timer
  });

  testWidgets('on the desktop the window losing its focus pauses nothing; hidden, a timer runs the game at the real '
      'speed, x2 and the pause included, and stops when it shows again, no time counted twice', (tester) async {
    final (game, b) = await boot(tester);
    expect(game.pauseWhenBackgrounded, isFalse);
    final g = b.state = waveOn(Game());
    await frames(tester, 10);

    // Another window has the focus: frames go on, the game runs.
    await lifecycle(tester, AppLifecycleState.inactive);
    expect((WidgetsBinding.instance.framesEnabled, game.runsHidden), (true, false));
    expect(await runs(tester, b), isTrue);
    expect(g.paused, isFalse);

    for (final hidden in [AppLifecycleState.hidden, AppLifecycleState.paused]) {
      // Minimized, covered, another Space: Flutter draws no frames, so a timer runs the game, at the real speed.
      await lifecycle(tester, hidden);
      expect((WidgetsBinding.instance.framesEnabled, game.runsHidden, game.paused), (false, true, false), reason: '$hidden');
      var t = g.t;
      await tester.pump(const Duration(seconds: 2));
      expect(g.t - t, closeTo(2, 0.05), reason: '$hidden: 2 s on');
      expect((g.paused, b.pauseTitle), (false, Rect.zero), reason: '$hidden');
      // A frame's own update meanwhile is dropped.
      t = g.t;
      game.update(0.05);
      expect(g.t, t, reason: '$hidden');
      // x2: twice as fast. Our pause: nothing moves.
      b.speed = 2;
      await tester.pump(const Duration(seconds: 1));
      expect(g.t - t, closeTo(2, 0.1), reason: '$hidden: x2');
      b.speed = 1;
      g.paused = true;
      t = g.t;
      await tester.pump(const Duration(seconds: 1));
      expect(g.t, t, reason: '$hidden: paused');
      g.paused = false;

      // Shown again: the timer stops, and the frames run it, the hidden time not counted again.
      await lifecycle(tester, AppLifecycleState.resumed);
      expect((WidgetsBinding.instance.framesEnabled, game.runsHidden), (true, false), reason: '$hidden');
      t = g.t;
      await frames(tester, 30);
      expect(g.t - t, closeTo(30 * 0.016, 0.04), reason: '$hidden: 30 frames');
    }

    // Between waves the auto start's countdown runs on while hidden.
    b.state = Game();
    await frames(tester, 10);
    b.autoStart
      ..set(true)
      ..won();
    await lifecycle(tester, AppLifecycleState.hidden);
    await tester.pump(const Duration(milliseconds: 2100));
    expect(b.autoStart.shown, 3);
    b.autoStart.set(false);
    await lifecycle(tester, AppLifecycleState.resumed);
    await frames(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('on a phone the app going to the background pauses the game, mid-wave or between waves (Auto held), and '
      'nothing runs meanwhile; back, it stays paused, even when the book had paused it (decisions-log 146)',
      (tester) async {
    final (game, b) = await boot(tester);
    expect(game.pauseWhenBackgrounded, isTrue);
    final g = b.state = waveOn(Game());
    await frames(tester, 10);

    // Something over the app (inactive: the notification shade, a call): frames go on, nothing pauses.
    await lifecycle(tester, AppLifecycleState.inactive);
    expect(await runs(tester, b), isTrue);
    expect(g.paused, isFalse);

    for (final away in [AppLifecycleState.hidden, AppLifecycleState.paused]) {
      // In the background: the game paused as by the pause button, Flame's loop stopped, and no timer runs it.
      await lifecycle(tester, away);
      expect((g.paused, game.paused, game.runsHidden), (true, true, false), reason: '$away');
      final t = g.t;
      await tester.pump(const Duration(seconds: 2));
      expect(g.t, t, reason: '$away: nothing runs');

      // Back: the loop runs again and "Pause" shows; the game waits for the pause button.
      await lifecycle(tester, AppLifecycleState.resumed);
      expect((game.paused, g.paused), (false, true), reason: '$away');
      await frames(tester, 30);
      expect((g.t, b.pauseTitle == Rect.zero), (t, false), reason: '$away: back, still paused');
      await tapOn(tester, b.pauseButton);
      expect(await runs(tester, b), isTrue, reason: '$away: resumed');
    }

    // The book had paused the wave: back from the background it is the player's pause, and shutting the book
    // leaves it paused.
    await tapOn(tester, b.bookButton);
    await frames(tester, 30);
    expect(g.paused, isTrue);
    await lifecycle(tester, AppLifecycleState.hidden);
    await lifecycle(tester, AppLifecycleState.resumed);
    await frames(tester);
    await tapOn(tester, b.bookButton);
    await frames(tester, 30);
    expect((g.paused, b.bookArea), (true, Rect.zero));
    await tapOn(tester, b.pauseButton);
    expect(await runs(tester, b), isTrue);

    // Between waves the auto start's countdown waits, in the background and back, until the game is resumed. A bare
    // Game has no army hold (decisions-log 141: [Game.boardRules] is off), so the pause alone holds it.
    final next = b.state = Game();
    expect(next.autoHeld, isFalse);
    await frames(tester, 10);
    b.autoStart
      ..set(true)
      ..won();
    await lifecycle(tester, AppLifecycleState.hidden);
    expect((next.paused, b.autoStart.left), (true, autoStartDelay));
    await tester.pump(const Duration(seconds: 3));
    await lifecycle(tester, AppLifecycleState.resumed);
    await frames(tester, 120); // about 2 s
    expect((next.paused, next.waveActive, b.autoStart.left), (true, false, autoStartDelay));
    await tapOn(tester, b.pauseButton);
    await frames(tester, 60);
    expect(b.autoStart.left, lessThan(autoStartDelay - 0.5));
    b.autoStart.set(false);
  }, variant: TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}));

  testWidgets('on a phone the background holds the sound, the music and the effects; back, it goes on, the music '
      'where it was, but a volume the player set to 0 stays silent (decisions-log 147)', (tester) async {
    final (_, b) = await boot(tester);
    final out = await listen();
    final g = b.state = waveOn(Game());
    await frames(tester, 10);
    expect((out.playing, out.held, out.starts), (Music.battle, false, 1));
    expect(out.music, closeTo(.35, 1e-9));

    // Something over the app (inactive: the notification shade, a call) holds nothing.
    await lifecycle(tester, AppLifecycleState.inactive);
    expect(out.held, isFalse);

    for (final (away, sfx) in [(AppLifecycleState.hidden, Sfx.leak), (AppLifecycleState.paused, Sfx.lose)]) {
      await lifecycle(tester, away);
      expect((out.held, out.music), (true, 0.0), reason: '$away');
      // An effect fired as the game goes away (a timer's) doesn't start.
      out.effects.clear();
      Sounds.play(sfx);
      expect(out.effects, isEmpty, reason: '$away');

      // Back: the same loop goes on (not started over), quieter while the game waits paused; effects play again.
      await lifecycle(tester, AppLifecycleState.resumed);
      await frames(tester);
      expect((out.held, out.playing, out.starts, g.paused), (false, Music.battle, 1, true), reason: '$away');
      expect(out.music, closeTo(.35 * .4, 1e-9), reason: '$away');
      Sounds.play(sfx);
      expect(out.effects, [sfx], reason: '$away');
      await tapOn(tester, b.pauseButton);
      await frames(tester);
      expect(out.music, closeTo(.35, 1e-9), reason: '$away: resumed');
    }

    // On the welcome screen too, where no pause holds the game.
    b.showWelcome();
    await frames(tester);
    expect((out.playing, out.held), (Music.idle, false));
    await lifecycle(tester, AppLifecycleState.hidden);
    expect((out.held, out.music), (true, 0.0));
    await lifecycle(tester, AppLifecycleState.resumed);
    expect(out.held, isFalse);
    expect(out.music, greaterThan(0));
    b.welcome = null;

    // The player's sound off (Pengaturan: both volumes at 0, as settings.json keeps them): back from the background
    // it stays silent.
    Sounds.volumes(0, 0);
    await lifecycle(tester, AppLifecycleState.hidden);
    await lifecycle(tester, AppLifecycleState.resumed);
    await frames(tester);
    out.effects.clear();
    Sounds.play(Sfx.wave);
    expect((out.held, out.music, out.effects.length), (false, 0.0, 0));
  }, variant: TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}));

  testWidgets('on the desktop the window hidden holds no sound: the game runs on, and its sounds with it (#93)',
      (tester) async {
    await boot(tester);
    final out = await listen();
    await frames(tester, 10);
    for (final (hidden, sfx) in [(AppLifecycleState.hidden, Sfx.leak), (AppLifecycleState.paused, Sfx.lose)]) {
      await lifecycle(tester, hidden);
      out.effects.clear();
      Sounds.play(sfx);
      expect(out.effects, [sfx], reason: '$hidden');
      expect(out.held, isFalse, reason: '$hidden');
      expect(out.music, closeTo(.35, 1e-9), reason: '$hidden');
      await lifecycle(tester, AppLifecycleState.resumed);
      await frames(tester);
    }
  }, variant: TargetPlatformVariant.desktop());
}
