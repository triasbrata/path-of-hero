import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/auto_start.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/save.dart';
import 'package:tower_defense/settings.dart';

import 'hud_font.dart';

// The HUD as the player gets it: a widget test that boots one TdGame (its onLoad needs the asset bundle)
// and presses what it draws, and the HUD's layout math. Pure rules are tested in game_test.dart.
//
// A won wave here saves the game and writes the telemetry's file, and the Auto toggle and the telemetry's
// install id save settings.json: into this file's own temp dir (flutter_test_config.dart, docs/testing.md), so
// other test files running at once never overwrite them.

/// Wins the wave on: once a monster is out, its queue emptied and its monsters gone, the next tick is a win
/// (a wave that was never on the field isn't one).
Future<void> winWave(WidgetTester tester, Game g) async {
  for (var i = 0; i < 300 && g.enemies.isEmpty; i++) {
    await frames(tester, 1);
  }
  g.queue.clear();
  for (final e in g.enemies) {
    e.gone = true;
  }
}

/// Boots one TdGame in a 1266x713 window and returns its board, past the welcome screen, with the game's font
/// (the HUD's rows are laid out by its widths) and the minimap folded (settings.json may keep it open from an
/// earlier test).
Future<Board> boot(WidgetTester tester) async {
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
  return game.board
    ..welcome = null
    ..miniMapOpen = false;
}

/// Advances the game [n] frames.
Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  test('a button is lit under the mouse, pushed in while a press on it is held, and neither when disabled', () {
    const r = Rect.fromLTWH(10, 10, 40, 32), on = Offset(20, 20), off = Offset(100, 100);
    const held = (at: on, down: 1.0, up: null), elsewhere = (at: off, down: 1.0, up: null);
    expect(buttonLook(r), ButtonLook.normal);
    expect(buttonLook(r, hover: on), ButtonLook.hover);
    expect(buttonLook(r, hover: off), ButtonLook.normal);
    expect(buttonLook(r, hover: on, press: held, now: 2), ButtonLook.pressed); // the press wins over the hover
    expect(buttonLook(r, press: held, now: 60), ButtonLook.pressed); // touch: no hover, only the press
    expect(buttonLook(r, hover: on, press: elsewhere, now: 2), ButtonLook.hover); // a press held elsewhere
    for (final (hover, press) in [(null, null), (on, null), (on, held)]) {
      expect(buttonLook(r, enabled: false, hover: hover, press: press, now: 2), ButtonLook.disabled);
    }
  });

  test('a press shows pushed in while held and pressMin at least, then comes back up through the hover look', () {
    ButtonPress press(double? up) => (at: Offset.zero, down: 1, up: up);
    expect(pressLook(null, 1), isNull);
    expect(pressLook(press(null), 30), ButtonLook.pressed); // held
    // A long press: pushed in until it comes up, then pressBack s of the hover look.
    expect(pressLook(press(2), 1.99), ButtonLook.pressed);
    expect(pressLook(press(2), 2 + pressBack / 2), ButtonLook.hover);
    expect(pressLook(press(2), 2 + pressBack + 0.01), isNull);
    // A quick click (up within a frame): still pressMin s pushed in, so it shows.
    expect(pressLook(press(1.01), 1 + pressMin - 0.01), ButtonLook.pressed);
    expect(pressLook(press(1.01), 1 + pressMin + pressBack / 2), ButtonLook.hover);
    expect(pressLook(press(1.01), 1 + pressMin + pressBack + 0.01), isNull);
    // The touch without hover gets the same: pressed, then the hover look on the way back, then normal.
    const r = Rect.fromLTWH(0, 0, 10, 10);
    expect([for (final t in [1.05, 1.1, 1.2]) buttonLook(r, press: press(1.01), now: t)],
        [ButtonLook.pressed, ButtonLook.hover, ButtonLook.normal]);
  });

  test('the pointer presses: the arrow, then its two press frames, the second while held, and back through the first', () {
    ButtonPress press(double? up) => (at: Offset.zero, down: 1, up: up);
    expect(cursorFrame(null, 5), 0);
    expect(cursorFrame(press(null), 1 + cursorStep / 2), 1);
    expect(cursorFrame(press(null), 1 + cursorStep * 1.5), 2);
    expect(cursorFrame(press(null), 30), 2); // held
    // Held 1 s: back through frame 1 for cursorStep s, then the arrow.
    expect([for (final t in [1.99, 2.0 + cursorStep / 2, 2.0 + cursorStep * 1.5]) cursorFrame(press(2), t)], [2, 1, 0]);
    // A quick click still shows both press frames, then comes back.
    expect([for (final i in [0.5, 1.5, 2.5, 3.5]) cursorFrame(press(1.01), 1 + cursorStep * i)], [1, 2, 1, 0]);
  });

  test('the auto start counts down only after a win, stands still while held, and stops when turned off', () {
    final auto = AutoStart(on: true);
    expect((auto.tick(10), auto.shown), (false, null)); // no countdown before a win
    auto.won();
    expect((auto.left, auto.shown), (autoStartDelay, 5));
    expect(auto.tick(2, held: true), isFalse); // paused, or the Hero splash
    expect(auto.left, autoStartDelay);
    expect((auto.tick(1.5), auto.shown), (false, 4));
    expect((auto.tick(3.4), auto.shown), (false, 1));
    expect((auto.tick(0.2), auto.left), (true, null)); // 0: start the wave, once
    expect(auto.tick(1), isFalse);

    auto.won();
    auto.cancel(); // Mulai pressed early, or the game over
    expect(auto.tick(10), isFalse);
    auto
      ..won()
      ..set(false); // turned off
    expect((auto.left, auto.tick(10)), (null, false));
    auto.won(); // off: a win starts nothing
    expect(auto.left, isNull);
    auto.set(true); // on again: nothing until the next win
    expect(auto.left, isNull);
  });

  test('settings.json keeps whether the auto start is on and the minimap open; off when missing or broken', () {
    final dir = Directory.systemTemp.createTempSync('td_settings'), file = File('${dir.path}/settings.json');
    addTearDown(() => dir.deleteSync(recursive: true));
    expect((loadSettings(file).autoStart, loadSettings(file).miniMap), (false, false)); // no file
    saveSettings(Settings(autoStart: true, miniMap: true), file);
    expect((loadSettings(file).autoStart, loadSettings(file).miniMap), (true, true));
    for (final text in ['{"music": 50}', '{"autoStart": "yes", "miniMap": 1}', 'not json']) {
      file.writeAsStringSync(text);
      expect((loadSettings(file).autoStart, loadSettings(file).miniMap), (false, false), reason: text);
    }
  });

  test('the minimap shows the field from the back line to where the monsters come on and every unit', () {
    final g = Game()
      ..units.clear()
      ..gold = 1000
      ..baseX = 3 * tile
      ..cam = 5 * tile
      ..viewW = 20 * tile;
    expect(miniMapSpan(g), (2 * tile, 26 * tile)); // the back line to the view's right edge, a tile more each side
    g.place('knight', 3, 2);
    final knight = g.troops.single
      ..pos = const Point(100.0, 40.0)
      ..entered = true;
    Unit foe(Tier tier, double x) {
      final u = g.monster('orc', tier, Point(x, 60))..entered = true;
      g.units.add(u);
      return u;
    }

    final far = foe(Tier.normal, 900);
    expect(miniMapSpan(g), (2 * tile, 900 + tile)); // a monster past the view's right edge
    foe(Tier.elite, 300);
    knight.pos = const Point(10.0, 40.0); // behind the back line
    expect(miniMapSpan(g).$1, 10 - tile);
    far.gone = true; // the dead are left out
    expect(miniMapSpan(g), (10 - tile, 26 * tile));
  });

  test('the minimap\'s battle line is the fight the camera centres (#85): none before the first contact, held through '
      'a lull, gone after the win', () {
    final g = Game()
      ..units.clear()
      ..gold = 1000;
    expect(g.place('knight', 0, 2), isTrue);
    g.troops.single
      ..pos = const Point(300.0, 56.0)
      ..entered = true
      ..busyUntil = 1e9;
    expect(battleLine(g), isNull); // between waves
    g.startWave();
    g.queue.clear();
    final orc = g.monster('orc', Tier.normal, const Point(1000, 56))..busyUntil = 1e9;
    g.units.add(orc);
    g.aim();
    expect(g.meetMode, MeetMode.approach);
    expect(battleLine(g), isNull); // not met yet
    orc.pos = const Point(312, 56);
    g.aim();
    expect((battleLine(g), g.fightX), (306.0, 306.0));
    orc.dying = 0;
    g.aim();
    expect(battleLine(g), 306); // the lull: held
    orc.gone = true;
    g.tick(0.05);
    expect(g.waveActive, isFalse);
    expect(battleLine(g), isNull); // won
  });

  test('the lives are hearts of two: full, half for an odd count, empty for lives lost', () {
    // (How many lives there are: game_test.dart.)
    expect(hearts(Game.startLives), [2, 2, 2]); // 6 lives: 3 full hearts
    expect(hearts(5), [2, 2, 1]);
    expect(hearts(2), [2, 0, 0]);
    expect(hearts(1), [1, 0, 0]);
    expect(hearts(0), [0, 0, 0]);
    expect(hearts(9), [2, 2, 2, 2, 1]); // more than startLives (none today): more hearts
    // The hearts that lose a half (they pop): the one a life goes from, or all a bigger loss touches.
    expect(heartsLost(6, 5), [2]);
    expect(heartsLost(5, 4), [2]);
    expect(heartsLost(6, 3), [1, 2]);
    expect(heartsLost(3, 0), [0, 1]);
  });

  test('a unit with MP has one bar, its inside 65% HP over 35% MP, ending where a lone HP bar does', () {
    const k = barK, near = 1e-9;
    final lone = unitBar(100, 50, mp: false), both = unitBar(100, 50, mp: true);
    // Without MP: the pack's 12x6 capsule, all its 10x4 inside HP.
    expect((lone.box.width, lone.box.height, lone.mp), (12 * k, 6 * k, null));
    expect(lone.hp, Rect.fromLTWH(lone.box.left + k, lone.box.top + k, 10 * k, 4 * k));
    // With MP: as wide, same bottom (clear of the head), taller than a lone bar but shorter than the old HP + MP
    // pair (11 px).
    final mp = both.mp!;
    expect((both.box.left, both.box.right, both.box.bottom), (lone.box.left, lone.box.right, lone.box.bottom));
    expect(both.box.height, allOf(greaterThan(lone.box.height), lessThan(11 * k)));
    // Inside the 1 px rim: HP on top, MP right under it, full width, 65 / 35 of the inside's height.
    expect((both.hp.top, mp.bottom), (both.box.top + k, both.box.bottom - k));
    expect((mp.top, mp.left, mp.width), (both.hp.bottom, both.hp.left, both.hp.width));
    expect(both.hp.height / (both.hp.height + mp.height), closeTo(0.65, near));
    expect(both.hp.height + mp.height, closeTo(barInnerMp * k, near));
  });

  testWidgets('the Start/Pause toggle at the top centre: between waves it starts the wave, in a wave it pauses it, paused '
      'it resumes; Auto left of the wave meter in every state', (tester) async {
    // (Its rule, Game.canStartWave, after a win and after game over: game_test.dart. Decisions-log 220.)
    final b = await boot(tester);
    final g = b.state = Game();
    await frames(tester);

    // Before the first wave: Start, in the middle of the top band.
    final at = b.startButton;
    expect(at, isNot(Rect.zero));
    expect((b.toggleButton, b.pauseButton), (at, Rect.zero));
    expect(at.center.dx, closeTo(1266 / 2, 1));
    expect(at.bottom, lessThan(713 * 0.1));
    // It acts on the way down (#54), before the pointer comes up.
    final press = await tester.startGesture(at.center);
    await frames(tester);
    expect((g.wave, g.waveActive, g.paused), (1, true, false));
    await press.up();
    await frames(tester);

    // In the wave it pauses: square, its middle where Start's was.
    final pause = b.pauseButton;
    expect((b.startButton, b.toggleButton), (Rect.zero, pause));
    expect((pause.width, pause.height), (44, 44));
    expect(pause.center.dx, closeTo(at.center.dx, 1));
    // A press as the wave starts (a double tap on Start, Auto starting it under a finger) pauses nothing.
    await tester.tapAt(pause.center);
    await frames(tester);
    expect(g.paused, isFalse);
    await frames(tester, 25); // 0.4 s: past the guard
    await tester.tapAt(pause.center);
    await frames(tester);
    expect(g.paused, isTrue);
    // Paused, it resumes, in the same place.
    expect((b.pauseButton, b.startButton), (pause, Rect.zero));
    await tester.tapAt(pause.center);
    await frames(tester);
    expect(g.paused, isFalse);

    // Between waves again (a fresh game: a won wave would be saved), and paused there: it resumes, and then starts.
    final next = b.state = Game();
    await frames(tester);
    expect(b.startButton, at);
    next.paused = true;
    await frames(tester);
    expect((b.startButton, b.pauseButton), (Rect.zero, pause));
    await tester.tapAt(pause.center);
    await frames(tester);
    expect((next.paused, next.wave, b.startButton), (false, 0, at));

    // Auto (#68) left of the wave meter, x2 left of it: a press turns it on, and settings.json keeps it.
    final auto = b.autoButton;
    expect((auto.right, b.speedButton.right), (b.waveMeter.left - 6, auto.left - 6));
    expect(b.autoStart.on, isFalse);
    await tester.tapAt(auto.center);
    await frames(tester);
    expect((b.autoStart.on, loadSettings().autoStart), (true, true));
    // With Auto on Start keeps room for its seconds: wider, its middle where it was.
    final wide = b.startButton;
    expect(wide.width, greaterThan(at.width));
    expect(wide.center.dx, closeTo(at.center.dx, 1));
    // No countdown before the first win.
    await frames(tester, 400);
    expect((next.wave, b.autoStart.left), (0, null));
    // It stays during a wave, where it was.
    await tester.tapAt(wide.center);
    await frames(tester);
    expect((next.wave, b.autoButton), (1, auto));
    // A win starts the countdown, shown on Start; it waits while paused, then starts the wave.
    await winWave(tester, next);
    await frames(tester);
    expect((next.waveActive, b.autoStart.shown), (false, 5));
    await frames(tester, 130); // 2.08 s
    expect(b.autoStart.shown, 3);
    next.paused = true;
    await frames(tester, 120);
    expect(b.autoStart.shown, 3);
    next.paused = false;
    await frames(tester, 200);
    expect((next.wave, next.waveActive, b.autoStart.left), (2, true, null));
    // Pressing Start early ends the countdown; turning Auto off stops one.
    await winWave(tester, next);
    await frames(tester, 30);
    expect(b.autoStart.shown, isNotNull);
    await tester.tapAt(b.startButton.center);
    await frames(tester);
    expect((next.wave, b.autoStart.left), (3, null));
    await winWave(tester, next);
    await frames(tester, 30);
    await tester.tapAt(b.autoButton.center);
    await frames(tester, 400);
    expect((b.autoStart.on, b.autoStart.left, next.wave, next.waveActive), (false, null, 3, false));
    expect(loadSettings().autoStart, isFalse);
  });

  testWidgets('a press meant for Start that comes as the wave starts pauses nothing: Auto\'s countdown under a finger, a '
      'press on what still shows Start', (tester) async {
    final b = await boot(tester);
    b.autoStart.set(true);
    final g = b.state = Game(Random(1))
      ..loot = Random(2)
      ..heroes = Random(3);
    await frames(tester);
    final start = b.startButton;
    g.startWave();
    await winWave(tester, g);
    await frames(tester);
    expect(b.autoStart.shown, 5);
    b.autoStart.left = 0.01; // it ends at the next frame
    await frames(tester, 1);
    expect((g.wave, g.waveActive), (2, true));
    await tester.tapAt(start.center);
    await frames(tester);
    expect(g.paused, isFalse);
    // Drawn as Start, the wave started before the press (no frame between): nothing.
    b.autoStart.set(false);
    final next = b.state = Game();
    await frames(tester);
    expect(b.startButton, isNot(Rect.zero));
    next.startWave();
    await tester.tapAt(b.startButton.center);
    await frames(tester, 40);
    expect((next.wave, next.waveActive, next.paused), (1, true, false));
  });

  testWidgets('Auto counts real seconds, x2 doesn\'t hurry it, and another game coming in (a new one, a loaded save) ends it', (tester) async {
    // (The countdown's own rules: the auto start test above; the toggle and settings.json: the start button
    // test. Decisions-log 77. After a game over the start button is gone, Game.canStartWave: game_test.dart.)
    final b = await boot(tester);
    b.autoStart.set(true);
    final g = b.state = Game(Random(1))
      ..loot = Random(2)
      ..heroes = Random(3);
    await frames(tester);
    final width = b.startButton.width; // with Auto on it keeps room for the seconds
    g.startWave();
    await winWave(tester, g);
    await frames(tester);
    // During the win's cheering: the start button shows the countdown, as wide as before.
    expect((g.waveActive, b.autoStart.shown, b.startButton.width), (false, autoStartDelay.round(), width));
    // At x2 the game runs twice as fast; the countdown doesn't: 2.08 s on it shows 3, as at x1 (1 if it
    // counted game time).
    b.speed = 2;
    await frames(tester, 130);
    expect(b.autoStart.shown, 3);
    b.speed = 1;
    // The win was auto-saved; loading it ("Lanjutkan") carries no countdown over, and none starts.
    final loaded = b.state = loadGame()!;
    await frames(tester);
    expect((loaded.wave, loaded.canStartWave, b.autoStart.left), (1, true, null));
    await frames(tester, 400); // 6.4 s
    expect((loaded.wave, loaded.waveActive, b.autoStart.left), (1, false, null));
    // A win of the loaded game counts down again; a new game coming in ends it.
    loaded.startWave();
    await winWave(tester, loaded);
    await frames(tester);
    expect(b.autoStart.shown, autoStartDelay.round());
    final fresh = b.state = Game(Random(1));
    await frames(tester, 400);
    expect((fresh.wave, fresh.waveActive, b.autoStart.left), (0, false, null));
  });

  testWidgets('hidden or in the background between waves the game is saved, and goes on (the desktop) or pauses (a phone); '
      'mid-wave and on the welcome screen the save stands', (tester) async {
    final phone = defaultTargetPlatform == TargetPlatform.android;
    final b = await boot(tester);
    addTearDown(() => b.game.lifecycleStateChange(AppLifecycleState.resumed));
    clearSave();
    final g = b.state = Game(Random(1))..gold = 777;
    await frames(tester);
    // Called on the game itself, frames stay on (no hidden timer, pause_test.dart): only the save is looked at here.
    b.game.lifecycleStateChange(AppLifecycleState.hidden); // Android: then paused, where it may be ended
    // The desktop's hiding pauses nothing (#93); a phone's background pauses the game (decisions-log 146).
    expect((g.paused, loadGame()?.gold), (phone, 777));
    // A save holds no wave in progress (loading it would skip the wave): mid-wave the last one stands.
    g
      ..startWave()
      ..gold = 5;
    b.game.lifecycleStateChange(AppLifecycleState.paused);
    expect((g.waveActive, loadGame()?.wave, loadGame()?.gold), (true, 0, 777));
    // On launch the welcome screen shows over a fresh game, which must not replace the save.
    b
      ..welcome = Welcome(loadGame(), discard: () {})
      ..state = Game(Random(2));
    b.game.lifecycleStateChange(AppLifecycleState.hidden);
    expect(loadGame()?.gold, 777);
  }, variant: TargetPlatformVariant({TargetPlatform.macOS, TargetPlatform.android}));

  testWidgets('Auto waits while a new Hero\'s splash is due or shows, from the win until it closes, then counts down', (tester) async {
    // (Who is crowned and when: game_test.dart. Decisions-log 77 and 79.)
    final b = await boot(tester);
    b.autoStart.set(true);
    final g = b.state = Game(Random(1))
      ..loot = Random(2)
      ..heroes = Random(3)
      ..wave = heroEvery - 1; // the next wave is a 10th: its win crowns the free priest
    await frames(tester);
    g.startWave();
    await winWave(tester, g);
    await frames(tester);
    expect((g.troops.single.hero, b.holdAutoStart, b.autoStart.shown), (true, true, autoStartDelay.round()));
    // The cheering (victoryTime 2.4 s), then the splash for up to 4 s: 4 s after the win nothing has counted.
    await frames(tester, 250);
    expect((b.holdAutoStart, b.autoStart.shown), (true, autoStartDelay.round()));
    // A tap closes the splash, and the countdown runs from there: 2.08 s on it shows 3, then the wave starts.
    await tester.tapAt(const Offset(1266 / 2, 713 / 2));
    await frames(tester);
    expect(b.holdAutoStart, isFalse);
    await frames(tester, 130);
    expect(b.autoStart.shown, 3);
    await frames(tester, 200);
    expect((g.wave, g.waveActive, b.autoStart.left), (heroEvery + 1, true, null));
  });

  testWidgets('"Kirim data permainan" on the Pengaturan page is off at first; a press turns it on and settings.json keeps it', (tester) async {
    final b = await boot(tester);
    b.state = Game();
    await frames(tester);
    expect(b.sendButton, Rect.zero); // the troops' page
    b.showSettings();
    await frames(tester, 40); // the book is open between waves
    final at = b.sendButton;
    expect(at, isNot(Rect.zero));
    expect(loadSettings().sendTelemetry, isFalse);
    await tester.tapAt(at.center);
    await frames(tester);
    expect(loadSettings().sendTelemetry, isTrue);
    await tester.tapAt(at.center);
    await frames(tester, 5); // past the tap's own timer
    expect(loadSettings().sendTelemetry, isFalse);
    // The telemetry listened to the game from its first frame, so the install id is made and kept.
    expect(loadSettings().installId, matches(RegExp(r'^[0-9a-f]{32}$')));
  });

  testWidgets('while troops are out of sight left of the view a marker shows on the field\'s left edge, level with them', (tester) async {
    // (Who is out of sight, Game.leftOfView: game_test.dart.)
    final b = await boot(tester);
    final g = b.state = Game()..paused = true; // nothing moves: the view stays where it is put
    final priest = g.troops.single; // the free healer
    await frames(tester);
    expect(b.offViewMarker, Rect.zero);
    g.cam = priest.pos.x + Game.offViewBy + tile;
    await frames(tester);
    final marker = b.offViewMarker;
    expect(marker, isNot(Rect.zero));
    expect(marker.left, lessThan(tile)); // on the edge
    expect(marker.center.dy, closeTo(b.toScreen(0, priest.pos.y).dy, 1)); // level with it
    g.cam = 0;
    await frames(tester);
    expect(b.offViewMarker, Rect.zero);
  });

  // #74, the HUD together: what one piece drew where another is.

  /// A wave on with nothing left to come, a knight standing still at the back and, ahead of it and still, the
  /// mini boss in the top row and the boss: both boss bars show.
  Future<(Game, Unit)> bossScene(WidgetTester tester, Board b) async {
    final g = b.state = Game(Random(5), Random(6))
      ..units.clear()
      ..gold = 1000;
    g.place('knight', 1, 3);
    final knight = g.troops.single
      ..pos = g.troops.single.post
      ..entered = true
      ..arriving = false
      ..stunUntil = 1e9;
    g
      ..startWave()
      ..queue.clear()
      ..waveSpawned = 30;
    Unit foe(String type, Tier tier, Point<double> at) {
      final u = g.monster(type, tier, at)
        ..entered = true
        ..stunUntil = 1e9;
      g.units.add(u);
      return u;
    }

    final mini = foe('werebear', Tier.miniBoss, Point(knight.pos.x + 70, 14));
    foe(boss, Tier.boss, Point(knight.pos.x + 110, 60));
    await frames(tester, 40); // the book closes, the camera settles
    return (g, mini);
  }

  testWidgets('a unit\'s plate stays under the top band and the boss bars: beside a unit too near the top for it above', (tester) async {
    final b = await boot(tester);
    for (final size in const [Size(1266, 713), Size(915, 412)]) {
      tester.view.physicalSize = size;
      final (g, mini) = await bossScene(tester, b);
      expect(b.bossBars, isNot(Rect.zero), reason: '$size');
      // The mini boss in the top row, or where the bars hang over it at the right, the boss.
      final on = b.toScreen(mini.pos.x, mini.pos.y - 7), boss = g.enemies.firstWhere((u) => u.tier == Tier.boss);
      await tester.tapAt(b.coveredAt(on) ? b.toScreen(boss.pos.x, boss.pos.y - 7) : on); // pins its plate
      await frames(tester, 5);
      final plate = b.pinnedPlate;
      expect(plate, isNot(Rect.zero), reason: '$size');
      expect(plate.top, greaterThanOrEqualTo(b.bossBars.bottom), reason: '$size: under the boss bars');
      expect(b.coveredAt(b.bossBars.center), isTrue, reason: '$size: no unit is pointed at through a bar');
      for (final (what, r) in [('the log\'s button', b.logButton), ('Auto', b.autoButton)]) {
        expect(plate.overlaps(r), isFalse, reason: '$size: $what');
      }
      expect(g.over, isFalse);
    }
  });

  testWidgets('the battle log\'s button is at the bottom right of the field; its panel opens upward from it, under the meter, '
      'the map and the boss bars', (tester) async {
    final b = await boot(tester);
    for (final size in const [Size(1266, 713), Size(915, 412)]) {
      tester.view.physicalSize = size;
      final fieldBottom = size.height;
      await bossScene(tester, b);
      if (!b.miniMapOpen) await tester.tapAt(b.waveMeter.center);
      if (b.logPanel == Rect.zero) await tester.tapAt(b.logButton.center);
      await frames(tester, 5);
      final button = b.logButton, panel = b.logPanel;
      expect(button.right, lessThanOrEqualTo(size.width), reason: '$size');
      expect(button.bottom, lessThanOrEqualTo(fieldBottom), reason: '$size');
      expect(button.center.dx, greaterThan(size.width * 0.85), reason: '$size: the right');
      expect(button.center.dy, greaterThan(fieldBottom * 0.85), reason: '$size: the bottom');
      expect(panel, isNot(Rect.zero), reason: '$size');
      expect(panel.bottom, lessThan(button.center.dy), reason: '$size: over it');
      expect(panel.right, allOf(greaterThan(button.center.dx), lessThanOrEqualTo(button.right)), reason: '$size: right-aligned');
      for (final (what, r) in [('the meter', b.waveMeter), ('the map', b.miniMap), ('the boss bars', b.bossBars)]) {
        expect(r, isNot(Rect.zero), reason: '$size: $what');
        expect(panel.top, greaterThan(r.bottom), reason: '$size: under $what');
      }
    }
  });

  testWidgets('the off-view marker keeps clear of an open panel: beside the troop list', (tester) async {
    final b = await boot(tester);
    for (final size in const [Size(1266, 713), Size(915, 412)]) {
      tester.view.physicalSize = size;
      final g = b.state = Game()..gold = 10000;
      for (final t in troopTypes.keys) {
        g.autoPlace(t); // a long troop list, down into the field
      }
      await frames(tester, 40);
      // The troop list, under the counter at the left.
      Rect panel() => b.troopList;
      if (panel() == Rect.zero) await tester.tapAt(b.troopCounter.center);
      await frames(tester, 5);
      expect(panel(), isNot(Rect.zero), reason: '$size');
      final scale = b.toScreen(0, 1).dy - b.toScreen(0, 0).dy;
      // Level with the panel's middle.
      final y = (panel().bottom - 8 - b.toScreen(0, 0).dy) / scale; // the field's y there
      final priest = g.troops.firstWhere((u) => u.type == 'priest')..pos = Point(g.troops.map((u) => u.pos.x).reduce(min) - tile, y);
      for (final u in g.troops) {
        if (u != priest) u.pos = Point(priest.pos.x + 6 * tile, u.pos.y); // in view: only the priest is behind
      }
      g
        ..paused = true // nothing moves: the view stays where it is put
        ..cam = priest.pos.x + Game.offViewBy + tile;
      await frames(tester);
      final marker = b.offViewMarker;
      expect(marker, isNot(Rect.zero), reason: '$size');
      expect(marker.overlaps(panel()), isFalse, reason: '$size');
      expect(b.coveredAt(marker.center), isTrue, reason: '$size: no unit is pointed at through it');
      expect(marker.left, greaterThanOrEqualTo(panel().right)); // beside it, still level with the priest
      expect(marker.center.dy, closeTo(b.toScreen(0, y).dy, 1));
      await tester.tapAt(b.troopCounter.center); // folded again
      await frames(tester, 5); // past the tap's own timer
    }
  });

  testWidgets('a new game drops the last one\'s bursts, cast names and gold pops', (tester) async {
    final b = await boot(tester);
    final old = b.state = Game()..t = 500; // far on: its effects run on its clock
    await frames(tester);
    final u = old.troops.single;
    old
      ..impacts.add((u.pos, 'upgrade'))
      ..casts.add(u)
      ..goldPops.add((u.pos, 5));
    await frames(tester);
    expect(b.fieldFx, 3);
    b.state = Game(); // Ulang, or a save loaded: its clock starts again
    await frames(tester);
    expect(b.fieldFx, 0);
  });

  testWidgets('a book opened mid-wave in landscape puts the boss bars compact at the left, clear of it, and back when it shuts', (tester) async {
    final b = await boot(tester);
    for (final size in const [Size(1266, 713), Size(915, 412)]) {
      tester.view.physicalSize = size;
      await bossScene(tester, b);
      final under = b.bossBars; // under the wave meter
      expect((b.bossBarsAside, b.bookArea), (false, Rect.zero), reason: '$size');
      await tester.tapAt(b.bookButton.center);
      await frames(tester, 30); // it opens
      final aside = b.bossBars, book = b.bookArea;
      expect(book, isNot(Rect.zero), reason: '$size');
      expect(b.bossBarsAside, isTrue, reason: '$size');
      expect(aside.right, lessThan(book.left), reason: '$size: clear of the book and its tabs');
      expect(aside.top, greaterThan(b.goldPanel.bottom), reason: '$size: under the top row');
      expect(aside.height, lessThanOrEqualTo(under.height), reason: '$size: compact (915x412 has them compact already)');
      // With the troop list open they go under it; the map, open, stays under the meter (decisions-log 220).
      await tester.tapAt(b.troopCounter.center);
      await frames(tester, 5);
      expect(b.bossBars.top, greaterThan(b.troopList.bottom), reason: '$size');
      expect(b.bossBars.right, lessThan(book.left), reason: '$size');
      await tester.tapAt(b.troopCounter.center);
      await tester.tapAt(b.waveMeter.center);
      await frames(tester, 5);
      final map = b.miniMap;
      expect((map.left, map.top > b.waveMeter.bottom), (b.waveMeter.left, true), reason: '$size: under the meter');
      expect((b.bossBars.left, b.bossBars.top > b.goldPanel.bottom), (10, true), reason: '$size: the bars at the left, under the top row');
      expect(b.bossBars.overlaps(map), isFalse, reason: '$size');
      await tester.tapAt(b.waveMeter.center);
      await frames(tester, 5);
      await tester.tapAt(b.bookButton.center);
      await frames(tester, 30); // it shuts
      expect((b.bossBarsAside, b.bookArea, b.bossBars), (false, Rect.zero, under), reason: '$size');
    }
  });

  // #80: the HUD re-laid out; the owner: "gold, x2 dan pause di pindah ke kiri. wave level di pindahkan ke dalam
  // wave meter", "map pindah ke kanan atas dan dia itu dropdown dari meter wave", "log di pindah ke kanan bawah".

  testWidgets('the top band: the troop counter, then the hearts and the gold on one panel (and the book button in a wave) at '
      'the left; x2, Auto and the wave meter at the right; the Start/Pause toggle in the middle; '
      'none of it moves between waves, in a wave and paused', (tester) async {
    final b = await boot(tester);
    for (final size in const [Size(1266, 713), Size(915, 412)]) {
      tester.view.physicalSize = size;
      const edge = 10.0;
      final g = b.state = Game();
      await frames(tester, 40);
      void noOverlaps(String when) {
        final pieces = {
          'counter': b.troopCounter,
          'hearts': b.livesBar,
          'gold': b.goldPanel,
          'book': b.bookButton,
          'toggle': b.toggleButton,
          'x2': b.speedButton,
          'Auto': b.autoButton,
          'meter': b.waveMeter,
          'log': b.logButton,
        }..removeWhere((_, r) => r == Rect.zero);
        final names = pieces.keys.toList();
        for (var i = 0; i < names.length; i++) {
          for (var j = i + 1; j < names.length; j++) {
            expect(pieces[names[i]]!.overlaps(pieces[names[j]]!), isFalse, reason: '$size $when: ${names[i]} and ${names[j]}');
          }
        }
      }

      noOverlaps('between waves');
      final meter = b.waveMeter, panel = b.heartsGoldPanel, lives = b.livesBar, gold = b.goldPanel;
      final x2 = b.speedButton, auto = b.autoButton, toggle = b.toggleButton, pad = 2 * b.hudScale;
      // One panel: its hearts' part, then its gold's, as tall as it.
      expect(panel, lives.expandToInclude(gold), reason: '$size');
      expect((lives.left, lives.right, gold.right), (panel.left, gold.left, panel.right), reason: '$size');
      expect((lives.top, lives.bottom, gold.top, gold.bottom), (panel.top, panel.bottom, panel.top, panel.bottom), reason: '$size');
      expect(meter.right, size.width - edge, reason: '$size: the top right');
      expect(x2.right, auto.left - pad, reason: '$size: x2, then Auto');
      expect(toggle.center.dx, closeTo(size.width / 2, 1), reason: '$size: the toggle in the middle');
      expect((panel.left, panel.top), (b.troopCounter.right, meter.top), reason: '$size: beside the counter, level with the meter');
      expect((auto.right, x2.top), (meter.left - pad, meter.top), reason: '$size: Auto right beside the meter');
      expect((auto.center.dy, toggle.center.dy), (meter.center.dy, meter.center.dy), reason: '$size: in the band');
      // x2 works from there.
      await tester.tapAt(x2.center);
      await frames(tester);
      expect(b.speed, 2, reason: '$size');
      await tester.tapAt(x2.center);
      await frames(tester);
      expect(b.speed, 1, reason: '$size');

      // In a wave and paused: the book button at the left row's end; the rest where it was.
      g.startWave();
      await frames(tester, 5);
      for (final when in ['in a wave', 'paused']) {
        g.paused = when == 'paused';
        await frames(tester);
        noOverlaps(when);
        expect((b.heartsGoldPanel, b.speedButton, b.autoButton, b.waveMeter), (panel, x2, auto, meter), reason: '$size $when');
        expect(b.toggleButton.center.dx, closeTo(toggle.center.dx, 1), reason: '$size $when');
        expect((b.bookButton.top, b.bookButton.left), (panel.top, panel.right + pad), reason: '$size $when');
      }
      g.paused = false;
    }
  });

  testWidgets('a press on the wave meter drops the minimap down under it, the boss bars under that; another folds it, '
      'and settings.json keeps which', (tester) async {
    final b = await boot(tester);
    Future<void> fold() async {
      if (!b.miniMapOpen) return;
      await tester.tapAt(b.waveMeter.center);
      await frames(tester, 5); // past the tap's own timer
    }

    for (final size in const [Size(1266, 713), Size(915, 412)]) {
      tester.view.physicalSize = size;
      // Between waves too; the book is open then, and the map stays under the meter, over the book's top
      // edge (decisions-log 220: it never moves).
      final g = b.state = Game();
      await frames(tester, 40);
      await fold();
      expect((b.miniMapOpen, b.miniMap), (false, Rect.zero), reason: '$size');
      await tester.tapAt(b.waveMeter.center);
      await frames(tester);
      expect((b.miniMapOpen, loadSettings().miniMap), (true, true), reason: '$size');
      final between = b.miniMap;
      expect(between, isNot(Rect.zero), reason: '$size');
      expect((between.left, between.width, between.top > b.waveMeter.bottom), (b.waveMeter.left, b.waveMeter.width, true),
          reason: '$size: under the meter');
      expect(b.bookArea, isNot(Rect.zero), reason: '$size: the book open');
      g.startWave(); // the book shuts: the map stays
      await frames(tester, 30);
      expect((b.bookArea == Rect.zero, b.miniMap), (true, between), reason: '$size');
      await fold();

      // In a wave with the boss bars: folded, the bars hang under the meter, right-aligned with it.
      await bossScene(tester, b);
      expect(b.miniMap, Rect.zero, reason: '$size');
      final under = b.bossBars, meter = b.waveMeter;
      expect((under.top > meter.bottom, under.right), (true, meter.right), reason: '$size');
      await tester.tapAt(meter.center);
      await frames(tester);
      final map = b.miniMap;
      expect((map.left, map.width, map.top > meter.bottom), (meter.left, meter.width, true), reason: '$size: under the meter');
      expect((b.bossBars.top > map.bottom, b.bossBars.right), (true, map.right), reason: '$size: the boss bars under it');
      expect(b.coveredAt(map.center), isTrue, reason: '$size: no unit is pointed at through it');
      await tester.tapAt(map.center); // it only tells
      await frames(tester);
      expect(b.miniMapOpen, isTrue, reason: '$size');
      await fold();
      expect((b.miniMap, b.bossBars, loadSettings().miniMap), (Rect.zero, under, false), reason: '$size');
    }
  });
}
