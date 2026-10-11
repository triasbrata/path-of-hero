// The guide's one-time cards at their breaks (docs/ui-hud.md "Guide", lib/coach.dart's `_coachNews`): a card due
// (lib/guide_rules.dart) opens by itself between waves, once the won wave's "MENANG!" is over and after a Hero's splash,
// a message and a boss chest (K5 and K12 sit over the chest's popup instead); one a break; Auto's countdown waits while
// it shows; closed it is seen, saved, and never comes back, through "Main Baru" too; not before a loaded game's first
// win; a device from before the guide with the owner's wave-86 save sees only K14, K15, K18, K20, K21 and K22; and K5 over
// its chest fits at 1266x713, 1164x777 and 915x412 with the chest under it taking no press. The card's own input and
// look: coach_hud_test.dart, coach_fit_test.dart. One TdGame per widget test; the board saves settings.json and the game
// into the test file's temp dir (flutter_test_config.dart).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/guide_rules.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/save.dart' show Welcome;
import 'package:tower_defense/settings.dart';

import 'hud_font.dart';

const _fixture = 'test/fixtures/save-20261001-2005-pre-awaken.json';

/// Boots one TdGame in a [size] window, past the welcome screen, with the game's font and the minimap folded.
Future<Board> boot(WidgetTester tester, [Size size = const Size(1266, 713)]) async {
  tester.view
    ..physicalSize = size
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

Future<void> tapOn(WidgetTester tester, Rect r) async {
  expect(r, isNot(Rect.zero));
  await tester.tapAt(r.center);
  await frames(tester);
}

/// The intro and the pointers seen: only the cards are left.
Set<String> pastIntro() => {guideIntro, ...guidePointers};

/// A board game between waves at wave [wave] (none of K2-K4's, nor a Hero's or a boss's, comes next): no army limit, so
/// Auto's countdown waits only for what is tested; gold to spare.
Game boardGame([int wave = 5]) => Game(Random(1)).boardRules()
  ..towns = false // a Town (rolled on an unseeded die) would take a break; the Towns' cards: town_switch_test.dart
  ..armyMax = null
  ..gold = 200000
  ..wave = wave;

/// Makes K13 due in [g]: its priests up to their cap (decisions-log 201), the gold as it was.
void capPriests(Game g) {
  final gold = g.gold;
  g.gold = 1 << 20;
  while (!g.typeFull(Game.freeHealer) && g.autoPlace(Game.freeHealer)) {}
  g.gold = gold;
}

/// [g]'s wave started and won at once (its one monster gone): the cheering begins.
Future<void> endWave(WidgetTester tester, Game g) async {
  g
    ..startWave()
    ..queue.clear()
    ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
  await frames(tester, 3);
  expect(g.waveActive, isFalse);
}

/// Frames through the rest of [g]'s won wave's cheering ("MENANG!"): no card shows in it.
Future<void> cheer(WidgetTester tester, Board b, Game g) async {
  for (var i = 0; i < 400 && g.t - g.victoryAt < victoryTime; i++) {
    expect(b.coachCard, isNull, reason: 'no card while "MENANG!" shows');
    await frames(tester, 1);
  }
}

/// Frames (at most [n]) until a card shows: its key, or null.
Future<String?> cardShown(WidgetTester tester, Board b, [int n = 60]) async {
  for (var i = 0; i < n && b.coachCard == null; i++) {
    await frames(tester, 1);
  }
  return b.coachCard?.$1;
}

/// A break with [g]: its wave won, the cheering over; the card it opens (null: none within [n] frames).
Future<String?> breakCard(WidgetTester tester, Board b, Game g, [int n = 60]) async {
  await endWave(tester, g);
  await cheer(tester, b, g);
  return cardShown(tester, b, n);
}

/// Closes the card showing with Space, page by page.
Future<void> close(WidgetTester tester, Board b) async {
  for (var i = 0; i < 4 && b.coachCard != null; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await frames(tester);
  }
  expect(b.coachCard, isNull);
}

/// The owner's wave-86 save, as the board plays it (its limits on).
Game w86() => Game.fromJson(jsonDecode(File(_fixture).readAsStringSync()) as Map<String, dynamic>, Random(1), Random(101),
    Random(301));

void main() {
  testWidgets('a card due opens once "MENANG!" is over and holds Auto until tapped; closed it is seen and saved, and '
      'never comes back while still due', (tester) async {
    final b = await boot(tester);
    final g = b.state = boardGame()..relicBag[Relic.fang] = 1; // K7: a small relic in the bag
    b
      ..guideSeen = pastIntro()
      ..autoStart.set(true);
    addTearDown(() => b.autoStart.set(false));
    await frames(tester, 10);
    expect(b.coachCard, isNull, reason: 'none before a win in this game');
    expect(await breakCard(tester, b, g), 'K7');
    expect(b.coachCard, ('K7', 0));
    final held = b.autoStart.left!;
    await frames(tester, 120);
    expect((b.autoStart.left, g.waveActive, b.coachCard), (held, false, ('K7', 0)), reason: 'Auto waits for the card');
    await tapOn(tester, b.coachPanel);
    expect(b.coachCard, isNull);
    expect(b.guideSeen, contains('K7'));
    expect(loadSettings().seen, contains('K7'), reason: 'saved');
    await frames(tester, 30);
    expect(b.autoStart.left!, lessThan(held), reason: 'counts again');

    b.autoStart.set(false);
    expect(g.relicBag[Relic.fang], 1, reason: 'still due');
    expect(await breakCard(tester, b, g), isNull, reason: 'seen: never again');
  });

  testWidgets('one card a break, in guideNext\'s order; the next one at the next break', (tester) async {
    final b = await boot(tester);
    final g = b.state = boardGame()..relicBag[Relic.fang] = 1; // K7
    capPriests(g); // K13: a type at its cap
    b.guideSeen = pastIntro();
    await frames(tester, 10);
    expect(await breakCard(tester, b, g), 'K7');
    await close(tester, b);
    expect(await cardShown(tester, b, 120), isNull, reason: 'K13 waits for the next break');
    expect(await breakCard(tester, b, g), 'K13');
    await close(tester, b);
    expect(await breakCard(tester, b, g), isNull);
    expect(b.guideSeen, containsAll(['K7', 'K13']));
  });

  testWidgets('no card mid-wave, while paused, while a message shows, nor before the intro is seen', (tester) async {
    final b = await boot(tester);
    final g = b.state = boardGame()..relicBag[Relic.fang] = 1;
    b.guideSeen = {}; // the intro not seen
    await frames(tester, 10);
    expect(await breakCard(tester, b, g), isNull, reason: 'the intro first');

    b.guideSeen = pastIntro();
    g.paused = true;
    expect(await cardShown(tester, b), isNull, reason: 'paused');
    g.paused = false;
    b.showMessage(Words.notEnoughGold, time: 1);
    expect(await cardShown(tester, b, 20), isNull, reason: 'a message up');
    expect(await cardShown(tester, b, 120), 'K7', reason: 'after it');
    await close(tester, b);

    g.relicBag[Relic.fang] = 0;
    g.startWave();
    capPriests(g); // K13 due, mid-wave
    expect(await cardShown(tester, b), isNull, reason: 'mid-wave');
  });

  testWidgets("a card waits for a new Hero's splash, and opens once it is closed", (tester) async {
    final b = await boot(tester);
    final g = b.state = boardGame()..relicBag[Relic.fang] = 1;
    b.guideSeen = pastIntro();
    await frames(tester, 10);
    await endWave(tester, g);
    g.heroMade.add(g.troops.first); // a splash after the cheering
    await cheer(tester, b, g);
    await frames(tester, 5);
    expect(b.heroSplash, isNotNull);
    expect(await cardShown(tester, b, 60), isNull, reason: 'the splash first');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape); // closes the splash
    await frames(tester, 2);
    expect(b.heroSplash, isNull);
    expect(await cardShown(tester, b), 'K7');
  });

  testWidgets('a boss chest holds every card but K5, which sits over its popup: the chest under it takes no press; the '
      'other card waits for the next break', (tester) async {
    final b = await boot(tester);
    final g = b.state = boardGame()..relicBag[Relic.fang] = 1;
    b.guideSeen = pastIntro();
    await frames(tester, 10);
    await endWave(tester, g);
    g.chests.add(Chest(ChestKind.boss, g.wave, cards: [Relic.grail, Relic.voidEye, Relic.dawnStar]));
    await cheer(tester, b, g);
    await frames(tester, 3);
    expect((b.chestOpen, b.coachCard), (true, null), reason: 'the chest pops in first');
    expect(b.chestRibbon, isNot(Rect.zero), reason: 'the chest\'s title');
    expect(await cardShown(tester, b), 'K5');
    expect(b.chestOpen, isTrue, reason: 'over the chest');
    await frames(tester, 2);
    expect(b.chestRibbon, Rect.zero, reason: 'one ribbon: the card\'s, not the chest\'s under it');
    final cards = b.chestCards;
    await tapOn(tester, cards.first);
    expect((b.coachCard, b.chestPicked), (('K5', 1), null), reason: 'the tap turned the page only');
    await tapOn(tester, cards.first);
    expect(b.coachCard, isNull);
    expect(b.guideSeen, contains('K5'));
    await frames(tester, 30);
    expect(b.chestOpen, isTrue, reason: 'the chest still to pick');
    expect(b.chestRibbon, isNot(Rect.zero), reason: 'its title back');
    await tapOn(tester, b.chestCards.first);
    expect(b.chestPicked, 0, reason: 'the chest takes presses again');
    await tapOn(tester, b.chestButtons['take']!); // taken: it holds nothing now
    expect(b.chestOpen, isFalse);
    await tapOn(tester, b.messageBox); // the take's message
    expect(await cardShown(tester, b, 120), isNull, reason: 'K5 was this break\'s card');
    expect(await breakCard(tester, b, g), 'K7');
  });

  testWidgets('with K5 seen, the chest open holds the card; once it is taken, the card opens in the same break',
      (tester) async {
    final b = await boot(tester);
    final g = b.state = boardGame()..relicBag[Relic.fang] = 1;
    b.guideSeen = {...pastIntro(), 'K5'};
    await frames(tester, 10);
    await endWave(tester, g);
    g.chests.add(Chest(ChestKind.boss, g.wave, cards: [Relic.grail, Relic.voidEye, Relic.dawnStar]));
    await cheer(tester, b, g);
    await frames(tester, 3);
    expect(b.chestOpen, isTrue);
    expect(await cardShown(tester, b, 90), isNull, reason: 'the chest first');
    await tapOn(tester, b.chestCards.first);
    await tapOn(tester, b.chestButtons['take']!);
    expect(b.chestOpen, isFalse);
    await tapOn(tester, b.messageBox); // the take's message (the card waits for it)
    expect(await cardShown(tester, b), 'K7');
    await frames(tester, 10); // the tap's timers run out
  });

  testWidgets('K12 sits over a chest that shows a Legenda', (tester) async {
    final b = await boot(tester);
    final g = b.state = boardGame(legendFrom);
    b.guideSeen = {...pastIntro(), 'K5'};
    await frames(tester, 10);
    await endWave(tester, g);
    g.chests.add(Chest(ChestKind.boss, g.wave, cards: [Relic.dragonCrown, Relic.ironBanner, Relic.grail]));
    await cheer(tester, b, g);
    expect(await cardShown(tester, b), 'K12');
    await frames(tester, 2);
    expect((b.chestOpen, b.chestRibbon), (true, Rect.zero), reason: 'over the chest, one ribbon');
  });

  testWidgets('the seen cards survive "Main Baru"; the new game\'s breaks have their own card', (tester) async {
    final b = await boot(tester);
    final g = b.state = boardGame()..relicBag[Relic.fang] = 1;
    // K11 seen: with the Towns on it is due once a Town is marked (decisions-log 253), which the new game's own
    // (unseeded) dice may roll at its break, before K13 in the cards' order.
    b.guideSeen = pastIntro()..add('K11');
    await frames(tester, 10);
    expect(await breakCard(tester, b, g), 'K7');
    await close(tester, b);

    b.welcome = Welcome(null, discard: () {});
    await frames(tester);
    await tapOn(tester, b.welcomeButtons['Main Baru']!);
    expect((b.welcome, b.coachCard), (null, null), reason: 'the intro is seen');
    final next = b.state;
    expect(identical(next, g), isFalse);
    expect(b.guideSeen, contains('K7'));
    next
      ..wave = 5
      ..armyMax = null
      ..relicBag[Relic.fang] = 1;
    capPriests(next);
    expect(await breakCard(tester, b, next), 'K13', reason: 'K7 seen; its first break opens K13');
    await close(tester, b);
    expect(loadSettings().seen, containsAll(['K7', 'K13']));
  });

  testWidgets('a device from before the guide with the w86 save: only K15, K18, K20 and K22 there, one a break, then K14 '
      'and K21 when due; none before its first win here', (tester) async {
    final b = await boot(tester);
    final g = b.state = w86().boardRules()
      ..towns = false // the Towns' cards: town_switch_test.dart (decisions-log 237)
      ..capWarnedAt = 1 << 20; // the cap's warning off: its 8 s message would only delay each card
    b.guideSeen = seenFrom(86);
    expect([for (final r in guideRules) if (!b.guideSeen!.contains(r.key)) r.key], ['K14', 'K15', 'K18', 'K20', 'K21', 'K22', 'K23']);
    expect(await cardShown(tester, b, 30), isNull, reason: 'not before a win in this game');
    expect(g.chests, isNotEmpty, reason: 'a save from before the chests gets its catch-up chests');
    await endWave(tester, g);
    await cheer(tester, b, g);
    // Its catch-up chests (Peti Tertunda) first, each passed over (Lewati twice): the cards wait for them.
    for (var i = 0; i < 10 && g.chests.isNotEmpty; i++) {
      for (var j = 0; j < 100 && !b.chestOpen; j++) {
        await frames(tester, 1);
      }
      await frames(tester, 3); // drawn: its buttons take presses
      expect(b.coachCard, isNull, reason: 'the chests first');
      await tapOn(tester, b.chestButtons['skip']!);
      await tapOn(tester, b.chestButtons['skip']!);
      await frames(tester, 5);
    }
    expect(g.chests, isEmpty);
    final shown = [await cardShown(tester, b, 600)]; // the save's own notes (8 s) may still be up
    await close(tester, b);
    for (var i = 0; i < 2; i++) {
      shown.add(await breakCard(tester, b, g, 120));
      await close(tester, b);
    }
    expect(shown, ['K15', 'K18', 'K20']);
    g.wave = 86; // back, so wave 90's Hero and boss never come
    expect(await breakCard(tester, b, g, 120), 'K22', reason: 'its bag can Carve');
    await close(tester, b);
    g.wave = 86; // back again
    expect(await breakCard(tester, b, g, 120), isNull, reason: 'no fallen Hero, no spare Pusaka yet');

    g.fallenHeroes.add(FallenHero(name: 'Kael', type: 'knight', stats: const [], fell: g.wave));
    expect(await breakCard(tester, b, g), 'K14');
    await close(tester, b);
    g.pusaka[Relic.grail]!.type = null; // to the Gudang: it can melt into another
    expect(await breakCard(tester, b, g), 'K21');
    await close(tester, b);
    expect(await breakCard(tester, b, g), isNull);
    expect(b.guideSeen, containsAll(['K14', 'K15', 'K18', 'K20', 'K21', 'K22']));
  });

  for (final size in const [Size(1266, 713), Size(1164, 777), Size(915, 412)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('$tag: K5 over its chest fits 8 px inside the screen, both pages', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = boardGame();
      b.guideSeen = pastIntro();
      await frames(tester, 10);
      await endWave(tester, g);
      g.chests.add(Chest(ChestKind.boss, g.wave, cards: [Relic.grail, Relic.voidEye, Relic.dawnStar]));
      await cheer(tester, b, g);
      expect(await cardShown(tester, b), 'K5');
      for (var page = 0; page < 2; page++) {
        await frames(tester, 30);
        expect(b.coachCard, ('K5', page));
        final r = b.coachPanel;
        expect((r.left >= 8, r.top >= 8, r.right <= size.width - 8, r.bottom <= size.height - 8), (true, true, true, true),
            reason: 'page ${page + 1}: $r');
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await frames(tester);
      }
      expect((b.coachCard, b.chestOpen), (null, true));
    });
  }
}
