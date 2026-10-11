// The in-game text seen (ui-hud.md "In-game text"): offscreen shots of every page and popup a player reads, into
// <probe root>/shots/english/<OUT's last folder> (`OUT`). A probe, not part of the suite (no `_test.dart`): queue
// `["test", "test/probe_english_shots.dart", "--dart-define=OUT=<dir>"]` with the worktree as `dir` (`--plain-name
// "english shots 412"` for one size). It never touches the real save (flutter_test_config.dart's temp dir); the dice
// are seeded, so a rerun gives the same shots. Run it before a text change and after, and look at the pairs one by one.
//
// From the owner's wave-86 save (the fixture: five types, its Pusaka bound by default, 3 catch-up chests), at 1266x713
// (device pixel ratio 2, a Retina Mac) and 412x860 (ratio 3, a phone), shot at the device's own pixels: welcome, chest
// (the save's first catch-up chest), hud, army (with every row's build name), release (a type's chip armed), badge
// (a Pusaka badge's tooltip), stars (an Awaken stars tooltip), bag, vault (a Vault Pusaka picked: Sharpen), melt (its
// picker), settings, licenses, howto, victory-names and victory-counts (the fallen by name and by
// type), drop-item and drop-relic (the drop popup over a troop), banner and splash (a high elite's skill, a mini boss's),
// battle (wave 90 with its mini boss and boss: the boss bars), plate (the boss's pinned plate, then a high elite's),
// log, gameover. At 915x412 the guide: its intro, two cards and How to Play. Every text the shots read is written to
// OUT/text-<size>.txt, so two runs diff line by line. `--dart-define=ONLY=b3` shoots only How to Play's Shop topics ([b3]),
// `ONLY=b4` only the Boss Chest's, the battle log's and the Artifact reports' ([b4]), `ONLY=b5` only the Bag's, the
// Artifacts' and the troop tooltips' ([b5]), at each size.
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
import 'package:tower_defense/cut_ins.dart' show foeCutTime;
import 'package:tower_defense/game.dart';
import 'package:tower_defense/guide_rules.dart' show guideIntro;
import 'package:tower_defense/guide_text.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/save.dart' show Welcome, dataFile;

import 'hud_font.dart';
import 'probe_root.dart';

const out = String.fromEnvironment('OUT', defaultValue: '$probeRoot/shots/english/x');
const seed = int.fromEnvironment('SEED', defaultValue: 7);

/// `b3`: only How to Play's two Shop topics ([b3]); `b4`: only the Boss Chest, battle log
/// and Artifact report shots ([b4]); `b5`: only the Bag, Artifact and troop tooltip shots ([b5]); the rest left out.
const only = String.fromEnvironment('ONLY');

/// What a fit dump adds to every shot: nothing here. The fit dump's mirror swaps this line for one that records
/// main.dart's `debugDrawn` (every text `_text` drew, its size and width) into `OUT/fit-SIZE.txt` (docs/testing.md).
Future<void> fitHook(WidgetTester tester, String section) async {}

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// The fixture (the owner's w86 save: five types, its Pusaka bound by default, 3 catch-up chests).
Game load() {
  final save = jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>;
  return Game.fromJson(save, Random(seed), Random(seed + 100), Random(seed + 300))
    ..loot = Random(seed + 200)
    ..draft = Random(seed + 500)
    ..boardRules();
}

/// The fixture without its catch-up chests and the save's notes, so no popup or message covers a shot.
Game quiet() => load()
  ..chests.clear()
  ..notes.clear();

void main() {
  for (final (size, ratio) in const [(Size(1266, 713), 2.0), (Size(412, 860), 3.0), (Size(915, 412), 2.0)]) {
    final tag = '${size.width.round()}';
    testWidgets('english shots $tag', (tester) async {
      tester.view
        ..physicalSize = size * ratio
        ..devicePixelRatio = ratio;
      addTearDown(tester.view.reset);
      await loadHudFont(tester);
      final game = TdGame();
      final key = GlobalKey();
      // The app's name field after a game over is a Flutter overlay (main.dart): an empty one here, so it isn't shot.
      await tester.pumpWidget(RepaintBoundary(
          key: key, child: GameWidget(game: game, overlayBuilderMap: {'name': (_, TdGame g) => const SizedBox.shrink()})));
      for (var i = 0; i < 3000 && !game.isLoaded; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(game.isLoaded, isTrue);
      final b = game.board..miniMapOpen = false;
      final text = <String>[];
      void note(String section, Object? what) => text.add('$section|$what');

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

      /// The screen as `NAME-SIZE.png`, after [settle] frames; what a tooltip, a message and the drop popup say noted.
      Future<void> shot(String name, [int settle = 20]) async {
        await frames(tester, settle);
        await fitHook(tester, '$tag|$name');
        if (b.tooltipShown != null) note(name, 'tooltip ${b.tooltipShown}');
        if (b.message != null) note(name, 'message ${b.message}');
        if (b.dropPopup != Rect.zero) note(name, 'drop ${b.dropLines}');
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await save((await tester.runAsync(() => boundary.toImage(pixelRatio: ratio)))!, '$name-$tag');
      }

      Future<void> tap(Offset p) async {
        await tester.tapAt(p);
        await frames(tester, 2);
      }

      /// Closes the message window when one shows (a save's notes), so it covers no shot.
      Future<void> calm() async {
        await frames(tester, 3);
        if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
      }

      Future<void> page(String name) async {
        final t = b.bookTabs.where((t) => t.$1 == name);
        if (t.isNotEmpty) await tap(t.first.$2.center);
        await frames(tester, 20);
      }

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      Future<void> off() async {
        await mouse.moveTo(const Offset(1, 1));
        await frames(tester, 3);
      }

      Future<void> hover(Offset at, String name) async {
        await off();
        await mouse.moveTo(at);
        await frames(tester, 30);
        await shot(name, 2);
        await off();
      }

      if (only == 'b3' || only == 'b4' || only == 'b5') {
        await (switch (only) { 'b3' => b3, 'b4' => b4, _ => b5 })(tester, b, tag, shot, note, tap, calm, hover);
        await mouse.removePointer();
        await tester.runAsync(() async => File('$out/text-$tag.txt')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('${text.join('\n')}\n'));
        return;
      }
      if (tag == '915') {
        // The guide: its intro, the first two cards, and the How to Play page.
        b
          ..state = (load()..chests.clear())
          ..guideSeen = {};
        await frames(tester, 10);
        for (final k in [guideIntro, ...guideEn.cards.keys.take(2)]) {
          b.openGuide(k);
          await shot('guide-$k', 30);
          note('guide-$k', b.coachCard);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await frames(tester, 10);
        }
        b.guideSeen = {'intro', ...guideEn.cards.keys};
        b.showSettings();
        await frames(tester, 20);
        if (b.howToButton != Rect.zero) {
          await tap(b.howToButton.center);
          await shot('howto', 20);
          note('howto', b.howToTopics.map((t) => t.$1).toList());
        }
      } else {
        b.guideSeen = {guideIntro, ...guideEn.pointers.keys, ...guideEn.cards.keys}; // no guide card or pointer
        b.welcome = Welcome(Game()..wave = 3, discard: () {});
        await shot('welcome', 30);
        note('welcome', b.welcomeButtons.keys.toList());
        b.welcome = null;

        // The save's first catch-up chest.
        b.state = load();
        await frames(tester, 3);
        await tap(const Offset(2, 2)); // the save's notes go, the popup stays
        await shot('chest', 30);

        final g = b.state = load()..chests.clear();
        await frames(tester, 3);
        if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
        await frames(tester, 60); // the book floats in
        await calm();
        await shot('hud');
        note('hud', 'troops ${b.troopCountText} tide "${b.tideBadge}"');

        // Army: every type's build name (each picked in turn), a Pusaka badge's tooltip, an item cell's (its Awaken stars), a type's release chip.
        await page('troops');
        await shot('army', 30);
        for (final type in g.troopCounts.keys) {
          await tap(b.troopRow(type).center); // the right page shows the picked type's build name
          note('army', '$type build ${b.rowBuildName(type)?.$1}');
        }
        final badge = b.pusakaBadge('knight_templar');
        if (badge != Rect.zero) await hover(badge.center, 'badge');
        final cell = b.itemCells.where((c) => c.$3 == 'armored_axeman').firstOrNull ?? b.itemCells.firstOrNull;
        if (cell != null) await hover(cell.$1.center, 'stars');
        final chip = b.releaseChip('archer');
        if (chip != Rect.zero) {
          await tap(chip.center);
          await shot('release', 10);
          note('release', 'armed ${b.releaseArmed}');
          await tap(const Offset(2, 2));
        }

        // Bag: the page, a Vault Pusaka picked (Sharpen on the facing page), its Melt picker.
        g
          ..givePusaka(Relic.bloodFang, stars: 2)
          ..givePusaka(Relic.warDrum);
        await page('bag');
        await shot('bag');
        final vault = b.bagSlot(Relic.bloodFang);
        if (vault != Rect.zero) {
          await tap(vault.center);
          await shot('vault');
          if (b.leburButton != Rect.zero) {
            await tap(b.leburButton.center);
            await shot('melt');
            if (b.leburBack != Rect.zero) await tap(b.leburBack.center);
          }
          await tap(b.bagSlot(Relic.bloodFang).center); // put back
        }

        b.showSettings();
        await shot('settings', 10);
        if (b.licenceButton != Rect.zero) {
          await tap(b.licenceButton.center);
          await shot('licenses', 20);
          if (b.licenceBack != Rect.zero) await tap(b.licenceBack.center);
        }
        b.showSettings();
        await frames(tester, 10);
        if (b.howToButton != Rect.zero) {
          await tap(b.howToButton.center);
          await shot('howto', 20);
          if (b.howToBack != Rect.zero) await tap(b.howToBack.center);
        }
        await page('troops');

        // The drop popup: a sword over an axeman (its whole type), a relic over a wizard.
        await off();
        await page('bag');
        Future<void> drop(Enum loot, String type, String name) async {
          final slot = b.bagSlot(loot);
          final u = g.troops.where((u) => u.alive && u.type == type).firstOrNull;
          if (slot == Rect.zero || u == null) return;
          final drag = await tester.startGesture(slot.center);
          await drag.moveBy(const Offset(-30, 0));
          await frames(tester);
          await drag.moveTo(b.toScreen(u.pos.x, u.pos.y - 3));
          await shot(name, 4);
          await drag.moveTo(slot.center);
          await frames(tester);
          await drag.up();
          await frames(tester, 4);
        }

        await drop(Item.sword, 'armored_axeman', 'drop-item');
        await drop(Relic.fury, 'wizard', 'drop-relic');
        await page('troops');

        // Victory: the fallen by name (a Hero among them), then by type.
        final fallen = [
          for (final u in g.troops.where((u) => u.alive)) if (u.hero || u.type == 'armored_axeman' || u.type == 'wizard') u,
        ];
        final won = b.state = quiet()..wave = 90;
        await calm();
        won
          ..lastFallen = fallen.take(fallenNamesMax).toList()
          ..victoryAt = won.t;
        await shot('victory-names', 30);
        note('victory-names', [for (final u in won.lastFallen) '${u.name} (${troopTypeNames[u.type]})']);
        if (b.winPusakaLine != null) note('victory-names', 'win line ${b.winPusakaLine!.text}');
        won
          ..lastFallen = fallen
          ..victoryAt = won.t;
        await shot('victory-counts', 30);

        // A high elite's skill (its first sighting's splash, then its banner), then a mini boss's.
        final f = b.state = quiet();
        await calm();
        await frames(tester, 30);
        f.monsterCasts.add((f.monster('greatsword_skeleton', Tier.highElite, Point(f.cam + 60, 60)), MonsterSkill.values.firstWhere((s) => s.type == 'greatsword_skeleton')));
        await frames(tester, 3);
        if (b.foeSplash != null) {
          await shot('splash', 4);
          note('splash', '${b.foeSplash!.title} | ${b.foeSplash!.line}');
          await tap(b.foeSplash!.panel.center);
          await frames(tester, 3);
        }
        if (b.foeCutIn != null) {
          await shot('banner', 6);
          note('banner', '${b.foeCutIn!.title} | ${b.foeCutIn!.line}');
        }
        await frames(tester, (foeCutTime * 1000 / 16).ceil() + 4);
        f.monsterCasts.add((f.monster('orc_rider', Tier.miniBoss, Point(f.cam + 60, 60)), MonsterSkill.values.firstWhere((s) => s.type == 'orc_rider')));
        await frames(tester, 3);
        if (b.foeSplash != null) {
          await tap(b.foeSplash!.panel.center);
          await frames(tester, 3);
        }
        if (b.foeCutIn != null) {
          await shot('banner-mini', 6);
          note('banner-mini', '${b.foeCutIn!.title} | ${b.foeCutIn!.line}');
        }

        // Wave 90: its mini boss and boss on the field (the boss bars), the boss's pinned plate, a high elite's, the log.
        final w = b.state = quiet()..wave = 89;
        b.miniMapOpen = true;
        await calm();
        await frames(tester, 10);
        w.startWave();
        // Until both are on the field, or 15 s after the first of them came.
        int bosses() => w.enemies.where((u) => u.tier.index >= Tier.miniBoss.index && u.entered && u.alive).length;
        double? first;
        for (var t = 0.0; t < 150 && bosses() < 2 && !w.over && (first == null || t < first + 15); t += 0.5) {
          if (bosses() > 0) first ??= t;
          for (var i = 0; i < 15 && !w.over; i++) {
            w.tick(1 / 30);
          }
          w
            ..heroCasts.clear()
            ..monsterCasts.clear();
          await frames(tester, 1);
        }
        b.speed = 0;
        await shot('battle', 6);
        for (final u in w.enemies.where((u) => u.tier.index >= Tier.miniBoss.index && u.alive)) {
          note('battle', 'boss bar ${tierNames[u.tier]} ${bossBarName(u)}');
        }
        for (final rank in [Tier.boss, Tier.miniBoss, Tier.highElite]) {
          final u = w.enemies.where((u) => u.tier == rank && u.entered && u.alive).firstOrNull;
          if (u == null) continue;
          await tap(b.toScreen(u.pos.x, u.pos.y - 3));
          await shot('plate-${rank.name}', 4);
          final p = monsterPlate(u);
          note('plate-${rank.name}', '${p.name} | ${p.tier} | ${p.kinds} | ${p.hp}');
          await tap(const Offset(2, 2));
        }
        await tap(b.logButton.center);
        await shot('log', 4);
        await tap(b.logButton.center);
        b.speed = 1;

        // Game over.
        b.state = quiet()..lives = 0;
        await calm();
        await shot('gameover', 30);
      }

      // The menus, the HUD and the wave meter, at every size: the welcome screen and its scoreboard, the start button
      // counting down with Auto held, the cap's warning and the wave meter's tooltip at the cap, the save's notes and
      // the meter over the cap, a stalled wave's message, the win that opens the Shop as the tide comes, a Hero's
      // splash, Settings with both spotlights off, a package's licences, the intro's seven pages, the pointer P2 and
      // the cards K1 and K4.
      await b2(tester, b, tag, shot, note, tap, calm, hover);
      await b3(tester, b, tag, shot, note, tap, calm, hover);
      await b4(tester, b, tag, shot, note, tap, calm, hover);
      await b5(tester, b, tag, shot, note, tap, calm, hover);
      await mouse.removePointer();
      await tester.runAsync(() async => File('$out/text-$tag.txt')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('${text.join('\n')}\n'));
    });
  }
}

/// The menus, the HUD and the wave meter's shots (see [main]'s call). The scoreboard reads ten entries written to this
/// test's own scores.json (long names, a seven-digit score, three-digit waves).
Future<void> b2(
    WidgetTester tester,
    Board b,
    String tag,
    Future<void> Function(String name, [int settle]) shot,
    void Function(String section, Object? what) note,
    Future<void> Function(Offset p) tap,
    Future<void> Function() calm,
    Future<void> Function(Offset at, String name) hover) async {
  final seenAll = {guideIntro, ...guideEn.pointers.keys, ...guideEn.cards.keys};
  b
    ..guideSeen = {...seenAll}
    ..miniMapOpen = false;

  // The welcome screen (at 915 too).
  if (tag == '915') {
    b.welcome = Welcome(Game()..wave = 3, discard: () {});
    await shot('welcome', 30);
    note('welcome', b.welcomeButtons.keys.toList());
    b.welcome = null;
  }

  // Game over: the name panel (asked once a run) and its OK with no name typed (the default name), the game-over screen,
  // then its scoreboard: ten entries written to this test's own scores.json and the new one.
  dataFile('scores.json').writeAsStringSync(jsonEncode([
    for (final (i, name) in ['WWWWWWWWWWWW', 'Pemain', 'Player', 'Aldo Ash', 'Kael Drake', 'Budi', 'Mmmmmmmmmmmm', 'Sari', 'Tono', 'Ana'].indexed)
      {'name': name, 'score': 2345678 - i * 123457, 'wave': 120 - i * 9, 'kills': 0, 'at': DateTime.utc(2026, 10, 1, 12, i).toIso8601String()},
  ]));
  final u = min(1.0, min(b.size.x / 600, b.size.y / 540)); // the score screens' scale (scoreboard.dart)
  b.state = quiet()..lives = 0;
  await calm();
  await shot('name', 30);
  await tap(Offset(b.size.x / 2, b.size.y * 0.3 + 63 * u)); // the name panel's OK
  for (var i = 0; i < 20; i++) { // the score's submit to the file
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await shot('gameover-screen', 10);
  await tap(Offset(b.size.x / 2 - 98 * u, b.size.y / 2 + 52 * u)); // its scoreboard button
  await shot('scoreboard-loading', 1);
  for (var i = 0; i < 20; i++) { // the file's reads finish in real time, each step's next in the test's clock
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await shot('scoreboard', 10);
  note('scoreboard', 'message ${b.message}');
  await tap(Offset(b.size.x / 2, b.size.y / 2 + 250 * u - 46 * u)); // the board's Back, under its panel's middle

  // A new game: the start button counting down, Auto held (1 troop of 6), with the minimap open.
  final fresh = b.state = Game().boardRules()..gold = 5000;
  b.miniMapOpen = true;
  await calm();
  await shot('fresh', 30);
  b.autoStart
    ..set(true)
    ..won();
  await shot('autoheld', 70);
  note('autoheld', 'start ${b.startButton} held ${b.autoHeldLine} map ${b.miniMap} wave ${fresh.wave}');
  b.autoStart.set(false);
  b.miniMapOpen = false;

  // The army full at the cap of 32 after wave 63: the cap's warning, then the wave meter's tooltip ending with its line.
  final cap = Game().boardRules()
    ..gold = 1 << 30
    ..wave = 63
    ..victoryAt = -victoryTime
    ..capacity = armyMaxBoard;
  while (cap.armySize < armyMaxBoard && cap.autoPlace('soldier')) {}
  for (final u in cap.troops) {
    u
      ..pos = u.post
      ..entered = true
      ..arriving = false;
  }
  b.state = cap;
  await shot('capwarn', 10);
  note('capwarn', 'message ${b.message} box ${b.messageBox}');
  for (var i = 0; i < 3 && b.messageBox != Rect.zero; i++) {
    await tap(b.messageBox.center);
  }
  if (b.tideBadgeAt != Rect.zero) await hover(b.tideBadgeAt.center, 'meter');

  // The fixture with its notes unseen: the limits' notes (the army cap, over it, the types) in one window; then the
  // meter's tooltip over the cap (Beban's line).
  b.state = quiet();
  await shot('notes', 10);
  note('notes', 'message ${b.message} box ${b.messageBox}');
  for (var i = 0; i < 3 && b.messageBox != Rect.zero; i++) {
    await tap(b.messageBox.center);
  }
  if (b.tideBadgeAt != Rect.zero) await hover(b.tideBadgeAt.center, 'meter-over');

  // A stalled wave's message.
  b.state.newMarch = true;
  await shot('march', 4);
  note('march', 'message ${b.message}');
  await calm();

  // The win that opens the Shop as the tide comes: both lines on the victory popup.
  final won = b.state = quiet()
    ..wave = storeFrom
    ..tideStart = storeFrom + 1;
  await calm();
  won.victoryAt = won.t;
  await shot('victory-news', 30);

  // A new Hero's splash, then a recalled one's.
  final h = b.state = quiet();
  await calm();
  final hero = h.troops.where((u) => u.alive && !u.hero).first;
  h.heroMade.add(hero..hero = true);
  await shot('hero-splash', 20);
  note('hero-splash', b.heroSplash);
  await tap(Offset(b.size.x / 2, b.size.y / 2));
  await tester.pump(const Duration(seconds: 6)); // past the splash's own time, whatever closed it
  h.heroRecalled.add(hero);
  await shot('hero-back', 20);
  note('hero-back', b.heroSplash);
  await tap(Offset(b.size.x / 2, b.size.y / 2));
  await tester.pump(const Duration(seconds: 6));

  // Settings with both spotlights off, then a package's licences.
  b.showSettings();
  await shot('settings', 10);
  await tap(b.heroCutButton.center);
  await tap(b.foeCutButton.center);
  await shot('settings-off', 10);
  await tap(b.heroCutButton.center);
  await tap(b.foeCutButton.center);
  if (b.licenceButton != Rect.zero) {
    await tap(b.licenceButton.center);
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await shot('licenses', 10);
    final list = b.licenceColumns[1];
    if (list != Rect.zero) {
      await tap(list.topCenter + const Offset(0, 12));
      await shot('licenses-open', 10);
      note('licenses-open', b.licencePackage);
    }
    if (b.licenceBack != Rect.zero) await tap(b.licenceBack.center);
  }
  b.state = quiet();
  await calm();

  // The guide: the intro's seven pages, the pointer P2 at the start button, the cards K1 and K4 (two pages).
  b.guideSeen = {};
  b.openGuide(guideIntro);
  for (var i = 1; i <= 7 && b.coachCard != null; i++) {
    await shot('intro-$i', 20);
    note('intro-$i', b.coachCard);
    await tap(b.coachButtons['next']!.center);
  }
  b.guideSeen = {...seenAll}..remove('P2');
  await shot('p2', 60);
  note('p2', '${b.coachPointer} ${b.coachPointerBox} at ${b.coachPointerTarget}');
  b.guideSeen = {...seenAll};
  for (final k in ['K1', 'K4']) {
    b.openGuide(k);
    for (var i = 1; i <= 3 && b.coachCard?.$1 == k; i++) {
      await shot('card-$k-$i', 20);
      note('card-$k-$i', b.coachCard);
      await tap(b.coachPanel.center);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await frames(tester, 10);
  }
}

/// How to Play's two Shop topics (b3-howto-items, b3-howto-shop; see [main]'s call), on the fixture with gold to spare.
/// The field's Shop tab and its shots (Awaken 4-5, the Fallen Heroes, an item's card) went with it (decisions-log 296):
/// Awaken 4-5 and Forge are on the Army detail, the fallen are recalled there, a Town's Shop has its own probe
/// (probe_town_shop_tabs_shots.dart).
Future<void> b3(
    WidgetTester tester,
    Board b,
    String tag,
    Future<void> Function(String name, [int settle]) shot,
    void Function(String section, Object? what) note,
    Future<void> Function(Offset p) tap,
    Future<void> Function() calm,
    Future<void> Function(Offset at, String name) hover) async {
  b
    ..guideSeen = {guideIntro, ...guideEn.pointers.keys, ...guideEn.cards.keys}
    ..miniMapOpen = false
    ..welcome = null; // a fresh launch (ONLY=b3) shows the welcome screen
  Game shop() {
    final g = quiet()..gold = 5000000;
    final ready = [for (final t in g.troopCounts.keys) if (g.awakenLevel(t) >= maxAwaken) t];
    if (ready.isNotEmpty) {
      g
        ..ascended[ready.first] = maxAscend
        ..tempa[ready.first] = 6;
    }
    if (ready.length > 1) g.ascended[ready[1]] = 1;
    note('b3', 'types ${g.troopCounts.keys} at ${[for (final t in g.troopCounts.keys) g.awakenLevel(t)]} forge ${ready.firstOrNull}');
    return g;
  }

  b.state = shop();
  await calm();
  await frames(tester, 60); // the book floats in
  await calm();

  // How to Play's two Shop topics: Items & Awaken, and Shop.
  b.showSettings();
  await frames(tester, 10);
  if (b.howToButton != Rect.zero) {
    await tap(b.howToButton.center);
    final wheel = TestPointer(9, PointerDeviceKind.mouse);
    for (final (name, i) in [
      ('items', guideEn.topics.indexWhere((t) => t.live == GuideLive.items)),
      ('shop', guideEn.topics.indexWhere((t) => t.cards.contains('K11'))),
    ]) {
      final title = guideEn.topics[i].title;
      await tester.sendEventToBinding(wheel.hover(b.howToColumns[0].center));
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, -2000)));
      await frames(tester);
      for (var k = 0; k < 40 && !b.howToTopics.any((t) => t.$1 == title && t.$2.height > 8); k++) {
        await tester.sendEventToBinding(wheel.scroll(const Offset(0, 20)));
        await frames(tester);
      }
      final at = b.howToTopics.where((t) => t.$1 == title).firstOrNull;
      if (at == null) continue;
      await tap(at.$2.center);
      await shot('b3-howto-$name', 10);
      note('b3-howto-$name', b.howToText);
    }
    if (b.howToBack != Rect.zero) await tap(b.howToBack.center);
  }
}

/// The Boss Chest, the battle log and the Artifact reports' shots (see [main]'s call), on the fixture (wave 86): a boss
/// chest of a Rare, an Epic and a Legendary (b4-chest), a card lifted (b4-chest-take), Skip armed (b4-chest-skip), the
/// gold short of a reroll (b4-chest-short), a Shard card with two held (b4-chest-shard), an old save's catch-up chest
/// (b4-missed), the chip by the start button with two waiting (b4-chip), the guide's K5 (two pages) and K12 over a
/// chest, the open battle log with a line of each kind (b4-log) and on its Artifact chip (b4-log-artifact), the
/// "VICTORY!" popup with a boss chest's line and the Artifact line, short and long (b4-victory, b4-victory-long), the
/// Grail's cut-in (b4-grail) and How to Play's "Boss Chest & Artifacts" (b4-howto).
Future<void> b4(
    WidgetTester tester,
    Board b,
    String tag,
    Future<void> Function(String name, [int settle]) shot,
    void Function(String section, Object? what) note,
    Future<void> Function(Offset p) tap,
    Future<void> Function() calm,
    Future<void> Function(Offset at, String name) hover) async {
  b
    ..guideSeen = {guideIntro, ...guideEn.pointers.keys, ...guideEn.cards.keys}
    ..miniMapOpen = false
    ..welcome = null; // a fresh launch (ONLY=b4) shows the welcome screen

  /// The fixture with [cards] in a chest waiting (a boss one, or catch-up [n] of [of]), [gold] and [shards] held.
  Game chest(List<Relic?> cards, {int gold = 5000000, int shards = 0, ChestKind kind = ChestKind.boss, int n = 1, int of = 1}) {
    final g = quiet()
      ..gold = gold
      ..serpihan = shards;
    g.chests.add(Chest(kind, g.wave, cards: cards, n: n, of: of));
    return g;
  }

  Future<void> open(Game g) async {
    b.state = g;
    await frames(tester, 3);
    await calm();
    await frames(tester, 40);
  }

  const three = [Relic.ironBanner, Relic.godThunder, Relic.dragonCrown];
  await open(chest(three));
  await shot('b4-chest', 10);
  note('b4-chest', 'hint ${b.chestHint} | buttons ${b.chestButtons.keys.toList()} | open ${b.chestOpen}');
  if (b.chestCards.length == 3) {
    await tap(b.chestCards[2].center);
    await shot('b4-chest-take', 6);
    note('b4-chest-take', 'hint ${b.chestHint}');
    await tap(const Offset(2, 2));
  }
  if (b.chestButtons['skip'] case final skip?) {
    await tap(skip.center);
    await shot('b4-chest-skip', 6);
    await tap(const Offset(2, 2));
  }
  await open(chest(three, gold: 1000));
  await shot('b4-chest-short', 10);
  await open(chest([null, Relic.warDrum, Relic.oathOfOne], shards: 2));
  await shot('b4-chest-shard', 10);
  await open(chest(three, kind: ChestKind.catchUp, n: 1, of: 3));
  await shot('b4-missed', 10);

  // Two waiting through a won wave's cheer, before the popup opens (no Later since decisions-log 281, and no chest waits
  // mid-wave): the chip by the start button.
  final two = chest(three)..chests.add(Chest(ChestKind.boss, 86, cards: three));
  await open(two);
  two
    ..startWave()
    ..queue.clear()
    ..units.add(two.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
  await frames(tester, 4);
  await shot('b4-chip', 6);
  note('b4-chip', 'chip ${b.chestChip}');

  // The guide's cards over the chest: K5 (two pages), K12.
  for (final k in ['K5', 'K12']) {
    await open(chest(three));
    b.guideSeen = {guideIntro, ...guideEn.pointers.keys, ...guideEn.cards.keys}..remove(k);
    b.openGuide(k);
    for (var i = 1; i <= 2 && b.coachCard?.$1 == k; i++) {
      await shot('b4-$k-$i', 30);
      note('b4-$k-$i', b.coachCard);
      await tap(b.coachPanel.center);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await frames(tester, 10);
  }
  b.guideSeen = {guideIntro, ...guideEn.pointers.keys, ...guideEn.cards.keys};

  // The battle log, a line of each kind (the longest the game writes), newest on top.
  final g = b.state = quiet();
  await calm();
  await frames(tester, 30);
  final type = g.troopCounts.keys.first, other = g.troopCounts.keys.last;
  for (final e in <GameEvent>[
    WaveEnded(85, 0, won: false),
    WaveEnded(86, 0, won: true),
    StrongFoe(86, 1, type: 'greatsword_skeleton', tier: Tier.highElite),
    StrongFoe(86, 1, type: 'werebear', tier: Tier.miniBoss),
    LootDropped(86, 2, from: 'greatsword_skeleton', tier: Tier.highElite, relic: Relic.thorns),
    MonsterSkillCast(86, 2, type: 'orc_rider', tier: Tier.miniBoss, skill: MonsterSkill.values.firstWhere((s) => s.type == 'orc_rider')),
    TroopFell(86, 3, name: 'Kael Drake', type: 'armored_axeman', hero: true, killer: 'greatsword_skeleton', killerTier: Tier.highElite, relics: const [Relic.fury, Relic.fang]),
    TroopFell(86, 3, name: 'Budi', type: 'soldier', killer: 'orc_rider', killerTier: Tier.miniBoss),
    GrailSaved(86, 4, name: 'Kael Drake', type: 'armored_axeman', hero: true),
    Ascended(86, 5, type: type, level: 5, cost: 250000),
    Tempered(86, 5, type: type, level: 6, cost: 40000),
    PusakaAsah(86, 6, relic: Relic.dragonHeart, stars: 2, type: 'knight_templar', cost: 60000, relics: const {Relic.thorns: 8, Relic.fury: 2}),
    PusakaLebur(86, 6, fodder: Relic.voidEye, fodderStars: 1, relic: Relic.grail, stars: 3, cost: 150000),
    OfferPicked(86, 7, pick: Relic.ironBanner, stars: 1, type: 'knight_templar', rerolls: 0, chest: 'catchUp', chestWave: 86),
    OfferPicked(86, 7, skipped: true, gain: 38000, rerolls: 0, chest: 'boss', chestWave: 86),
    PusakaReport(86, 8, lines: [
      (relic: Relic.grail, type: 'armored_axeman', stars: 1, uses: 7, worth: 6.0),
      (relic: Relic.dragonHeart, type: 'knight_templar', stars: 2, uses: 0, worth: 1.0),
      (relic: Relic.mourningBell, type: other, stars: 1, uses: 3, worth: 3200.0),
      (relic: Relic.dawnStar, type: 'priest', stars: 1, uses: 0, worth: 5000.0),
    ], returned: const {Relic.fury: 2, Relic.fang: 1}),
  ]) {
    g.log.add(e);
  }
  note('b4-log', [for (final e in g.log.newestFirst) ...logLines(e)]);
  await tap(b.logButton.center);
  await shot('b4-log', 6);
  final panel = b.logPanel;
  if (panel != Rect.zero) {
    await tap(Offset(panel.left + panel.width * 4.5 / 7, panel.top + 10)); // the fifth chip, Artifact
    await shot('b4-log-artifact', 6);
  }
  await tap(b.logButton.center);

  // VICTORY!: a boss wave with its chest's line and the Artifact line, then a long one that shrinks.
  for (final (name, r) in [
    ('b4-victory', PusakaReport(90, 0, lines: [(relic: Relic.grail, type: 'armored_axeman', stars: 1, uses: 7, worth: 6.0)], returned: const {Relic.fury: 2})),
    ('b4-victory-long', PusakaReport(90, 0, lines: [(relic: Relic.dragonHeart, type: 'knight_templar', stars: 1, uses: 0, worth: 128.0)],
        returned: const {Relic.guard: 12, Relic.thorns: 11, Relic.fang: 9, Relic.fury: 8})),
  ]) {
    final won = b.state = quiet()..wave = 90;
    await calm();
    won
      ..chests.add(Chest(ChestKind.boss, 90, cards: three))
      ..lastPusaka = r
      ..victoryAt = won.t;
    await shot(name, 30);
    if (b.winPusakaLine case final l?) note(name, 'win line ${l.text} at ${l.size}');
  }

  // The Grail's cut-in.
  final c = b.state = quiet();
  await calm();
  await frames(tester, 30);
  c.grailFirst = c.troops.firstWhere((u) => u.alive && u.hero, orElse: () => c.troops.firstWhere((u) => u.alive));
  await frames(tester, 3);
  await shot('b4-grail', 8);
  note('b4-grail', b.grailCutIn);

  // How to Play's "Boss Chest & Artifacts".
  b.state = quiet();
  await calm();
  b.showSettings();
  await frames(tester, 10);
  if (b.howToButton != Rect.zero) {
    await tap(b.howToButton.center);
    final wheel = TestPointer(9, PointerDeviceKind.mouse);
    final title = guideEn.topics.firstWhere((t) => t.live == GuideLive.pusaka).title;
    await tester.sendEventToBinding(wheel.hover(b.howToColumns[0].center));
    await tester.sendEventToBinding(wheel.scroll(const Offset(0, -2000)));
    await frames(tester);
    for (var k = 0; k < 40 && !b.howToTopics.any((t) => t.$1 == title && t.$2.height > 8); k++) {
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, 20)));
      await frames(tester);
    }
    if (b.howToTopics.where((t) => t.$1 == title).firstOrNull case final at?) {
      await tap(at.$2.center);
      await shot('b4-howto', 10);
      note('b4-howto', b.howToText);
    }
    if (b.howToBack != Rect.zero) await tap(b.howToBack.center);
  }
}

/// The Bag's, the Artifacts' and the troop tooltips' shots (B5 of the English text; see [main]'s call): the save's
/// notes as it comes in (the Artifacts' three lines) and the Bag's suggestion strip (OK, Undo); an item, a relic, a
/// bound Artifact and a Vault one picked (the facing page: type rows, Sharpen) and its Melt picker; the Army page's HP
/// and MP tooltips and a Release armed (its confirm); a troop's pinned plate with its relics' Remove; the drop popup of
/// an item over a type and of a relic over a Hero (its relic slots).
Future<void> b5(
    WidgetTester tester,
    Board b,
    String tag,
    Future<void> Function(String name, [int settle]) shot,
    void Function(String section, Object? what) note,
    Future<void> Function(Offset p) tap,
    Future<void> Function() calm,
    Future<void> Function(Offset at, String name) hover) async {
  b
    ..guideSeen = {guideIntro, ...guideEn.pointers.keys, ...guideEn.cards.keys}
    ..miniMapOpen = false
    ..welcome = null; // a fresh launch (ONLY=b5) shows the welcome screen

  Future<void> page(String name) async {
    final t = b.bookTabs.where((t) => t.$1 == name);
    if (t.isNotEmpty) await tap(t.first.$2.center);
    await frames(tester, 20);
  }

  // The save's notes as they come in, the Artifacts' note among them (as for a save from before them), then the Bag's
  // strip while the suggestion stands.
  final g = b.state = load()
    ..chests.clear()
    ..notes.remove(pusakaNote);
  await frames(tester, 30);
  await shot('b5-notes', 4);
  note('b5-notes', b.message);
  if (b.messageBox != Rect.zero) await tap(b.messageBox.center);
  await frames(tester, 60); // the book floats in
  await page('bag');
  await shot('b5-strip', 10);
  note('b5-strip', 'ok ${b.pusakaNoteButton('ok')} undo ${b.pusakaNoteButton('batal')}');

  // An item, a relic, a bound Artifact and a Vault one picked, each with the facing page it opens; the Vault one's Melt.
  g.givePusaka(Relic.bloodFang, stars: 2);
  await frames(tester, 10);
  final bound = g.pusaka.entries.where((e) => e.value.type != null && !e.key.oath).firstOrNull?.key;
  for (final (loot, name) in [(Item.sword, 'b5-item'), (Relic.fury, 'b5-relic'), (bound, 'b5-bound'), (Relic.bloodFang, 'b5-vault')]) {
    if (loot == null) continue;
    final slot = b.bagSlot(loot);
    if (slot == Rect.zero) {
      note(name, 'no slot for $loot');
      continue;
    }
    await tap(slot.center);
    await shot(name, 10);
    note(name, [for (final k in ['name', 'where', 'effect', 'why']) '$k: ${b.bagDetailText(k)}'].join(' | '));
    if (loot == Relic.bloodFang && b.leburButton != Rect.zero) {
      await tap(b.leburButton.center);
      await shot('b5-melt', 10);
      if (b.leburBack != Rect.zero) await tap(b.leburBack.center);
    }
    if (b.bagSlot(loot) != Rect.zero) await tap(b.bagSlot(loot).center); // put back
  }

  // The drop popup: an item over a type (its whole type), a relic over a Hero (its two slots).
  Future<void> drop(Enum loot, Unit? u, String name) async {
    final slot = b.bagSlot(loot);
    if (slot == Rect.zero || u == null) {
      note(name, 'no slot or troop');
      return;
    }
    final drag = await tester.startGesture(slot.center);
    await drag.moveBy(const Offset(-30, 0));
    await frames(tester);
    await drag.moveTo(b.toScreen(u.pos.x, u.pos.y - 3));
    await shot(name, 4);
    await drag.moveTo(slot.center);
    await frames(tester);
    await drag.up();
    await frames(tester, 4);
  }

  Unit? alive(bool Function(Unit u) test) => g.troops.where((u) => u.alive && test(u)).firstOrNull;
  await drop(Item.sword, alive((u) => u.type == 'knight') ?? alive((u) => true), 'b5-drop-item');
  await drop(Relic.fury, alive((u) => u.hero && u.relics.length < u.relicSlots), 'b5-drop-hero');

  // Army: the picked type's HP and MP cells hovered, then a Release armed (the detail's confirm).
  await page('troops');
  final types = {for (final u in g.troops) if (u.alive) u.type};
  final type = types.contains('knight_templar') ? 'knight_templar' : types.first;
  await tap(b.troopRow(type).center);
  final stats = b.troopDetail('stats');
  if (stats != Rect.zero) {
    final cols = stats.width >= 212 ? 4 : 2, cellW = stats.width / cols, cellH = stats.height / (8 / cols).ceil();
    await hover(stats.topLeft + Offset(cellW * 0.3, cellH / 2), 'b5-hp');
    await hover(stats.topLeft + Offset(cellW * 1.3, cellH / 2), 'b5-mp');
  }
  final chip = b.releaseChip(type);
  if (chip != Rect.zero) {
    await tap(chip.center);
    await shot('b5-release', 10);
    note('b5-release', 'armed ${b.releaseArmed} confirm ${b.troopDetailWords('releaseConfirm')}');
  }

  // A troop's pinned plate on the field, outside the book, with two relics (a Hero) or one: each with its Remove. Last,
  // and tapped twice (a first tap may only let the armed Release go): on a phone a tap at the top left opens the
  // troop counter's list instead of closing anything.
  final u = alive((u) => u.hero && !b.bookArea.contains(b.toScreen(u.pos.x, u.pos.y - 7))) ??
      alive((u) => !b.bookArea.contains(b.toScreen(u.pos.x, u.pos.y - 7)));
  if (u == null) {
    note('b5-plate', 'no troop outside the book');
    return;
  }
  if (u.relics.isEmpty) u.relics.add(Relic.guard);
  if (u.relicSlots > 1 && u.relics.length < 2) u.relics.add(u.relics.contains(Relic.fang) ? Relic.thorns : Relic.fang);
  await frames(tester, 4);
  await tap(b.toScreen(u.pos.x, u.pos.y - 7));
  if (b.pinned != u) await tap(b.toScreen(u.pos.x, u.pos.y - 7));
  await shot('b5-plate', 6);
  note('b5-plate', 'pinned ${b.pinned?.name} removes ${b.plateTakeOff.length} plate ${b.pinnedPlate}');
}
