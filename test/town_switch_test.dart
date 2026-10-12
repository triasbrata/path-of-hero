// Town step T7 (decisions-log 237): the Towns switched on for every board game (a plain Game() keeps them off, tests
// only; no build turns the board's off since decisions-log 296), a save from before them discarded at launch (no Continue,
// the file gone; a save of this format loads, one in a due Town reopens it), the guide's Town cards (K23 in the first
// Town, K24 once a material is held; the Shop, Recall and spend-gold cards told as a Town has them), town.json's
// `shop.from` read, and the polish list: the Army detail's Recall tag always says Recall, the talk bubbles over the head
// (a lancer's over its helmet, not its lance), and the Army relic tooltip without the Bag's "Tap" line. (The Smithy's
// small material counts tucked into the slot's corner went with its materials' grid, decisions-log 302: the Wishlist
// tab's 22-px cells keep that tuck, smithy_wish_ui_test.dart.)
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/guide_rules.dart';
import 'package:tower_defense/guide_text.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/save.dart';

import 'hud_font.dart';
import 'real_rules.dart';
import 'town_hud_test.dart' show frames, townGame;
import 'town_life_test.dart' show ScriptDice, troop;
import 'town_scene_test.dart' show intoTown, settle;
import 'town_smithy_ui_test.dart' show smithyGame;

/// The owner's w89 save: from before the Towns (no `v`).
const _old = 'test/fixtures/save-20261002-2222-w89-sellbug.json';

/// Boots one TdGame in a [size] window, its welcome screen kept (the launch's own: [launchSave]).
Future<Board> launch(WidgetTester tester, [Size size = const Size(1266, 713)]) async {
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
  return game.board..miniMapOpen = false;
}

/// Boots past the welcome screen.
Future<Board> boot(WidgetTester tester, [Size size = const Size(1266, 713)]) async => (await launch(tester, size))..welcome = null;

File get _save => dataFile('save.json');

/// Every card seen but [keys] (the intro and the pointers too): only those can show.
Set<String> seenBut(Set<String> keys) => {guideIntro, ...guidePointers, for (final r in guideRules) if (!keys.contains(r.key)) r.key};

/// Frames (at most [n]) until a card shows: its key, or null.
Future<String?> cardShown(WidgetTester tester, Board b, [int n = 120]) async {
  for (var i = 0; i < n && b.coachCard == null; i++) {
    await frames(tester, 1);
  }
  return b.coachCard?.$1;
}

/// Closes the card showing with Space, page by page.
Future<void> closeCard(WidgetTester tester, Board b) async {
  for (var i = 0; i < 4 && b.coachCard != null; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await frames(tester);
  }
  expect(b.coachCard, isNull);
}

/// A board game of [seed] going through each Town at once, its dice seeded as the probes do.
Game seeded(int seed) => Game(Random(seed), Random(seed + 100)).boardRules()
  ..heroes = Random(seed + 300)
  ..loot = Random(seed + 200)
  ..slots = Random(seed + 400)
  ..draft = Random(seed + 500)
  ..townDice = Random(seed + 600)
  ..townPolicy = 'leave';

void main() {
  test('every game plays with the Towns: the board (no define, decisions-log 296) and a plain Game() (decisions-log 321)', () {
    expect(Game().towns, isTrue);
    expect(Game().boardRules().towns, isTrue);
  });

  test('a board game rolls Towns: over 30 waves won at once each seed has Towns, none before wave 7, 5 apart at least, '
      'the mini bosses and bosses where they were', () {
    for (var seed = 1; seed <= 3; seed++) {
      final g = seeded(seed);
      final bosses = <int>[];
      for (var w = 0; w < 30; w++) {
        g.startWave();
        if (g.queue.any((s) => s.$2 == Tier.boss)) bosses.add(g.wave);
        g.queue
          ..clear()
          ..add(('slime', Tier.normal));
        g.tick(0.05);
        g.enemies.single.gone = true;
        g.tick(0.05);
      }
      final slots = [for (final e in g.log.entries.whereType<TownLeft>()) e.slot];
      expect(slots, isNotEmpty, reason: 'seed $seed');
      expect(slots.first, greaterThanOrEqualTo(7), reason: 'seed $seed: $slots');
      for (var i = 1; i < slots.length; i++) {
        expect(slots[i] - slots[i - 1], greaterThanOrEqualTo(5), reason: 'seed $seed: $slots');
      }
      expect(bosses, [for (var w = bossEvery; w <= 30; w += bossEvery) w], reason: 'seed $seed');
    }
  });

  group('the save (decisions-log 237)', () {
    tearDown(clearSave);

    test('written with its format first: v ${Game.saveVersion}', () {
      final j = Game().toJson();
      expect((j.keys.first, j['v']), ('v', 3));
      expect((Game.saveVersion, Game.saveLoadsFrom), (3, 2), reason: 'a version-2 save loads forward (decisions-log 245)');
    });

    test('a save from before the Towns is no save: loadGame and savedWave see none, the launch deletes it; settings, '
        'scores and telemetry stay', () {
      final others = [for (final name in ['settings.json', 'scores.json', 'telemetry.jsonl']) dataFile(name)];
      for (final f in others) {
        f
          ..createSync(recursive: true)
          ..writeAsStringSync('{}');
      }
      for (final text in [
        File(_old).readAsStringSync(), // the owner's w89: no v
        jsonEncode({...jsonDecode(File(_old).readAsStringSync()) as Map, 'v': 1}),
        jsonEncode({...jsonDecode(File(_old).readAsStringSync()) as Map, 'v': '2'}), // not a number
      ]) {
        _save.writeAsStringSync(text);
        expect((loadGame(), savedWave()), (null, null));
        expect(_save.existsSync(), isTrue, reason: 'only the launch deletes it');
        expect(launchSave(), isNull);
        expect(_save.existsSync(), isFalse, reason: 'the launch deleted it');
      }
      expect(others.every((f) => f.existsSync() && f.readAsStringSync() == '{}'), isTrue);
      for (final f in others) {
        f.deleteSync();
      }
    });

    test('a save of this format loads, at the launch too, and stays; a broken file is no save and is kept aside', () {
      final g = Game(Random(1))
        ..wave = 12
        ..gold = 777
        ..towns = true
        ..townAt = 13;
      expect(saveGame(g), isTrue);
      expect(jsonDecode(_save.readAsStringSync())['v'], Game.saveVersion);
      expect((loadGame()?.gold, savedWave()), (777, 12));
      expect((launchSave()?.wave, launchSave()?.townAt), (12, 13));
      expect(_save.existsSync(), isTrue);
      _save.writeAsStringSync('{"v": 2, "wave": ');
      expect((loadGame(), savedWave(), launchSave()), (null, null, null));
      // Not a save from before: moved aside (save.bad-<time>.json, decisions-log 317), so the next save can't write over it.
      expect(_save.existsSync(), isFalse);
      final bad = [for (final f in _save.parent.listSync()) if (f is File && f.uri.pathSegments.last.startsWith('save.bad-')) f];
      expect([for (final f in bad) f.readAsStringSync()], ['{"v": 2, "wave": ']);
      for (final f in bad) {
        f.deleteSync();
      }
    });
  });

  group('the launch', () {
    tearDown(clearSave);

    testWidgets('a save from before the Towns: the welcome offers only a new game, and the file is gone', (tester) async {
      _save
        ..createSync(recursive: true)
        ..writeAsStringSync(File(_old).readAsStringSync());
      final b = await launch(tester);
      await frames(tester, 3);
      expect(b.welcome?.saved, isNull);
      expect(b.welcomeButtons.keys, isNot(contains('Lanjutkan')));
      expect(b.welcomeButtons.keys, contains('Main Baru'));
      expect(_save.existsSync(), isFalse);
    });

    testWidgets('a save of this format in a due Town: "Continue" at its wave, and it reopens in the Town', (tester) async {
      final g = townGame()
        ..wave = 8
        ..townAt = 9;
      expect(g.enterTown(), isTrue);
      expect(saveGame(g), isTrue);
      final b = await launch(tester);
      await frames(tester, 3);
      expect(b.welcome?.saved?.wave, 8);
      await tester.tapAt(b.welcomeButtons['Lanjutkan']!.center);
      for (var i = 0; i < 120 && !b.townShown; i++) {
        await frames(tester, 1);
      }
      expect((b.welcome, b.state.towns, b.state.inTown, b.townShown), (null, true, true, true));
      await frames(tester, 40); // the tap's own timers
    });
  });

  group('the guide (decisions-log 237)', () {
    test('K23 is due only in a Town and only there; K24 once a material is held, with the Towns on', () {
      final seen = seenBut({'K23', 'K24', 'K13'});
      final g = townGame()
        ..wave = 8
        ..townAt = 9;
      g.gold = 1 << 20;
      while (!g.typeFull(Game.freeHealer) && g.autoPlace(Game.freeHealer)) {} // K13 due everywhere
      g.gold = 5000;
      expect(guideNext(g, seen), isNull, reason: 'a Town due: no card before it opens');
      g.enterTown();
      expect(guideNext(g, seen), 'K23', reason: 'in the Town: its own card, no other');
      expect(guideNext(g, seen..add('K23')), isNull);
      g.leaveTown();
      expect(guideNext(g, seen), 'K13');
      seen.add('K13');
      expect(guideNext(g, seen), isNull);
      g.materials[Mat.slimeGel] = 1;
      expect(guideNext(g, seen), 'K24');
    });

    test('the Shop, Recall and spend-gold cards tell a Town\'s game: no Shop tab, the Army tab\'s dot, Recall', () {
      String lines(String key) => guideEn.cards[key]!.map((p) => p.lines.join(' / ')).join(' // ');
      expect(lines('K11'), contains(Words.town));
      expect(lines('K14'), allOf(contains('"${Words.army}"'), contains('"${Words.recall}"')));
      expect(lines('K18'), contains('Red dot on "${Words.army}"'));
      expect(lines('K23'), allOf(contains('"${Words.smithy}"'), contains('"${Words.leaveTown}"')));
      expect(lines('K24'), allOf(contains(Words.materials.toLowerCase()), contains('"${Words.smithy}"')));
      final towns = guideEn.topics.firstWhere((t) => t.title == '${Words.town}s');
      expect(towns.cards, ['K23', 'K24']);
      expect(towns.lines, containsAllInOrder(['after ${const TownSchedule().autoLeave.round()} seconds.', 'The "${Words.tavern}" sells boosts']));
    });

    testWidgets('K23 shows in the first Town, over it; seen, never again', (tester) async {
      final b = await boot(tester);
      b
        ..guideSeen = seenBut({'K23'})
        ..autoStart.set(false);
      final g = await intoTown(tester, b);
      expect(await cardShown(tester, b), 'K23');
      expect(g.inTown, isTrue);
      await closeCard(tester, b);
      expect(b.guideSeen, contains('K23'));
      g.leaveTown();
      await frames(tester, 30);
      g
        ..townAt = g.wave + 2
        ..startWave()
        ..queue.clear()
        ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
      for (var i = 0; i < 600 && !g.inTown; i++) {
        await frames(tester, 1);
      }
      expect(g.inTown, isTrue);
      expect(await cardShown(tester, b, 90), isNull, reason: 'seen');
    });

    testWidgets('K24 shows after the first wave that drops a material', (tester) async {
      final b = await boot(tester);
      b
        ..guideSeen = seenBut({'K24'})
        ..autoStart.set(false);
      final g = b.state = townGame()..wave = 1;
      g
        ..startWave()
        ..queue.clear()
        ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
      await frames(tester, 3);
      g.materials[Mat.slimeGel] = 1; // as the wave's kills would drop
      expect(await cardShown(tester, b, 400), 'K24');
    });
  });

  test("town.json's shop.from opens the Town's Shop (shipped 1: every Town's, decisions-log 253); Awaken 4-5, Forge and "
      'Recall keep wave 15', () {
    expect(const TownRules().shop.from, 1);
    final on = Game()
      ..towns = true
      ..townRules = TownRules.patch({'shop': {'from': 10}})
      ..wave = 9;
    expect((on.shopFrom, on.storeOpen, on.storeWhy(StoreRefusal.locked)), (10, false, 'Opens after wave 10'));
    on.wave = 10;
    expect(on.storeOpen, isTrue);
    // The shipped rules: the Shop open from wave 1's win; the Army page's buys from wave 15's.
    final g = Game()..gold = 1 << 30;
    for (var w = 0; w <= 20; w++) {
      g.wave = w;
      expect(g.storeOpen, w >= 1, reason: 'wave $w: the Shop');
      expect(g.armyBuysOpen, w >= storeFrom, reason: 'wave $w: Awaken 4-5, Forge, Recall');
    }
    g
      ..wave = storeFrom - 1
      ..fallenHeroes.add(FallenHero(name: 'Kael', type: 'knight', stats: const [HeroStat.hp], fell: 3));
    for (final why in [g.whyNotAscend('knight'), g.whyNotTempa('knight'), g.whyNotRecall(g.fallenHeroes.single)]) {
      expect(why, 'Opens after wave $storeFrom', reason: 'the Army page\'s buys before wave 15');
    }
    g.wave = storeFrom;
    for (final why in [g.whyNotAscend('knight'), g.whyNotTempa('knight'), g.whyNotRecall(g.fallenHeroes.single)]) {
      expect(why, isNot('Opens after wave $storeFrom'), reason: 'open from wave 15 (its own refusals then)');
    }
  });

  test('the Shop texts: the cap warning and the awakening tooltip send to the Army page', () {
    expect(capWarningText(32, 50, towns: true), endsWith('in the ${Words.army} page (${Words.awaken})'));
    // At Awaken 3 from its items, by the game's own rule (by grade, decisions-log 272): the next is bought.
    final g = Game()..upgrades['priest'] = awakenItems('priest', maxAwaken);
    expect(g.awakenLevel('priest'), maxAwaken);
    expect(g.awakenInfo('priest').$2.last, (null, '${awakenName(maxAwaken + 1)}: buy on the ${Words.army} page'));
  });

  testWidgets('the Recall tag always says Recall: "Recall 6k" where "6000" won\'t fit, a swap only where it fits whole',
      (tester) async {
    final b = await boot(tester);
    for (final size in const [Size(1266, 713), Size(915, 412)]) {
      tester.view.physicalSize = size;
      final g = b.state = smithyGame()
        ..inTown = false
        ..townAt = null
        ..wave = 20
        ..gold = 1000000;
      g.fallenHeroes.add(FallenHero(name: 'Hero 1', type: 'knight', stats: const [HeroStat.hp, HeroStat.power], fell: 19));
      g.capacity = g.armySize; // full: a recall swaps a knight
      await frames(tester, 40);
      if (b.bookPage != 'troops') {
        await tester.tapAt(b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2.center);
        await frames(tester, 3);
      }
      await tester.tapAt(b.troopRow('knight').center);
      await frames(tester, 3);
      for (var i = 0; i < 40 && b.troopDetail('recall:0') == Rect.zero; i++) {
        b.troopDetailScroll += 30;
        await frames(tester, 2);
      }
      final words = b.troopDetailWords('recall');
      expect(words, isNotEmpty, reason: '$size');
      expect(words.every((w) => w.startsWith(Words.recall)), isTrue, reason: '$size: $words');
      expect(g.recallInfo(g.fallenHeroes.single).$2.join(' '), contains('goes home'));
    }
  });

  testWidgets("a lancer's talk bubble sits over its helmet, not over its lance's tip", (tester) async {
    final b = await boot(tester);
    b.autoStart.set(false);
    final dice = ScriptDice();
    b.townDice = dice;
    final g = await intoTown(tester, b);
    await settle(tester, b);
    final x = b.townLife.width / 2;
    double draw(double world) => (world - townEdge) / (b.townLife.width - 2 * townEdge);
    dice.queue.addAll([
      0, 0, 0, 0, // the depth and head start of each
      draw(x), 0.1, TownLife.drawFor(TownDo.stroll), draw(x + 4), // the knight strolls on
      draw(x + 30), 0.9, TownLife.drawFor(TownDo.talk), 0.9, // the lancer talks with it, halfway, and says the first line
      0.99, // six lines
    ]);
    final lancer = troop('lancer');
    g.units
      ..removeWhere((u) => u.side == Side.troop)
      ..addAll([troop('knight'), lancer]);
    Rect? seen;
    Offset? feet;
    for (var i = 0; i < 600 && seen == null; i++) {
      await frames(tester, 1);
      for (final f in b.townFolk) {
        if (f.unit == lancer && f.bubble != Rect.zero) (seen, feet) = (f.bubble, f.feet);
      }
    }
    expect(seen, isNotNull, reason: 'the lancer spoke');
    final s = b.townK * townFolkK;
    // The idle lancer, its soles on its line (decisions-log 292: its feet's last row 56): its lance's tip 37 sprite px
    // over it (row 20), its helmet's top 29 (row 28).
    expect(seen!.bottom, greaterThan(feet!.dy - 37 * s), reason: 'under the lance tip');
    expect(seen.bottom, lessThanOrEqualTo(feet.dy - 29 * s), reason: 'over the helmet');
  });

  testWidgets('the Army detail\'s relic tooltip: what it is, its tier, no "Tap, then pick a troop"', (tester) async {
    final b = await boot(tester);
    final g = b.state = smithyGame()
      ..inTown = false
      ..townAt = null;
    g.troops.firstWhere((u) => u.type == 'soldier').relics.add(Relic.cleave);
    await frames(tester, 40);
    if (b.bookPage != 'troops') {
      await tester.tapAt(b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2.center);
      await frames(tester, 3);
    }
    await tester.tapAt(b.troopRow('soldier').center);
    await frames(tester, 3);
    b.troopDetailScroll = 1e6;
    await frames(tester, 3);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await mouse.addPointer(location: Offset.zero);
    for (var i = 0; i < 4; i++) {
      final relics = b.troopDetail('relics');
      expect(relics, isNot(Rect.zero));
      await mouse.moveTo(Offset(relics.left + 46, relics.center.dy));
      await frames(tester, 20);
    }
    final tip = b.tooltipShown;
    await mouse.moveTo(Offset.zero);
    await mouse.removePointer();
    expect(tip?.$1, relicNames[Relic.cleave]);
    expect(tip!.$2, isNot(contains(tapLine)));
    expect(tip.$2, contains(g.relicTierLine(Relic.cleave)));
  });
}
