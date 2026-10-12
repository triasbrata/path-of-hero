// The Boss Chest's popup and its "Chest!" chip on the board (decisions-log 152, 281, lib/chest_popup.dart; docs/ui-hud.md
// "Boss Chest"): it opens once a won boss wave's cheering is over and holds Auto; a tap picks a card, a tap on another
// moves the pick, and the button row's Take, greyed until a card is picked, takes it; Reroll pays, Skip takes two taps;
// there is no Later: the popup stays until Take or Skip, and a chest left waiting by a wave started in the cheer is the
// chip (mid-wave it says why not) and opens after that wave; the owner's w86 save opens its catch-up chests one after
// another, saved once rolled; it fits a phone and a laptop; a card's frame is the page card recoloured by its rarity, no
// ink box over it, its rarity named in its ink; every line it shows is in the HUD's font. The rules: draft_test.dart.
// One TdGame per widget test. The board saves after a win and a pick: the queue's runs have a temp HOME
// (flutter_test_config.dart), so the real save is never touched.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/auto_start.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';
import 'package:tower_defense/save.dart' show loadGame, saveGame;

import 'hud_font.dart';

/// Boots one TdGame in a [size] window, past the welcome screen, with the game's font and the minimap folded; inside a
/// RepaintBoundary under [key], for [screenPixels].
Future<Board> boot(WidgetTester tester, [Size size = const Size(1266, 713), Key? key]) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await loadHudFont(tester);
  final game = TdGame();
  await tester.pumpWidget(RepaintBoundary(key: key, child: GameWidget(game: game)));
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

Future<void> tapOn(WidgetTester tester, Offset p) async {
  await tester.tapAt(p);
  await frames(tester);
}

/// A board game between waves with the chest on (the board's rules, but no army limit: so Auto's countdown waits only
/// for the chest), three troops, gold to spare, and the next wave a boss's.
Game boardGame({int wave = 4}) {
  final g = Game(Random(1)).boardRules()
    ..armyMax = null
    ..gold = 200000
    ..wave = wave
    ..draft = Random(5);
  for (final type in ['soldier', 'archer', 'knight']) {
    expect(g.autoPlace(type), isTrue);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  return g;
}

/// The owner's wave-86 save from before the chest: 3 catch-up chests.
Game w86() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>);

/// The screen as drawn now (boot's RepaintBoundary under [key]): its pixel at (x, y) as 0xAARRGGBB.
Future<int Function(int, int)> screenPixels(WidgetTester tester, GlobalKey key) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final img = (await tester.runAsync(() => boundary.toImage()))!;
  final px = (await tester.runAsync(() => img.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  return (x, y) {
    final i = (y * img.width + x) * 4;
    return px.getUint8(i + 3) << 24 | px.getUint8(i) << 16 | px.getUint8(i + 1) << 8 | px.getUint8(i + 2);
  };
}

/// Colour [a] within 4 of [b] in each of red, green and blue.
bool near(int a, int b) => [16, 8, 0].every((s) => ((a >> s & 0xFF) - (b >> s & 0xFF)).abs() <= 4);

/// Every rect of the popup this frame: its cards and buttons.
List<Rect> popupRects(Board b) => [...b.chestCards, ...b.chestButtons.values];

/// [g]'s wave won now: its queue emptied and its monsters gone.
void winWave(Game g) {
  g.queue.clear();
  for (final u in g.units) {
    if (u.side == Side.enemy) u.gone = true;
  }
}

/// [rects] all on a [size] screen, none overlapping another.
void fitsApart(List<Rect> rects, Size size, String why) {
  final screen = Offset.zero & size;
  for (final (i, r) in rects.indexed) {
    expect(screen.intersect(r) == r, isTrue, reason: '$why: $r off the screen');
    for (final o in rects.skip(i + 1)) {
      final x = r.intersect(o);
      expect(x.width <= 0 || x.height <= 0, isTrue, reason: '$why: $r over $o');
    }
  }
}

void main() {
  testWidgets("after a won boss wave's cheering the chest opens and holds Auto; a tap picks a card, the row's Take (greyed "
      'until then) takes it, and the game is saved', (tester) async {
    final b = await boot(tester);
    final g = b.state = boardGame();
    b.autoStart.set(true);
    await frames(tester, 30);
    g
      ..startWave()
      ..queue.clear()
      ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
    await frames(tester, 3); // the win: its chest rolled at once
    expect((g.wave, g.chests.length, b.chestOpen), (5, 1, false), reason: 'not during the cheering');
    final left = b.autoStart.left!;
    await frames(tester, (victoryTime * 60).ceil() + 10);
    expect(b.chestOpen, isTrue);
    expect(b.chestCards, hasLength(3));
    await frames(tester, 120);
    expect((b.chestOpen, b.autoStart.left), (true, left), reason: "the countdown waits while it's open");
    expect(g.waveActive, isFalse);

    final card = g.chest!.cards!.first!;
    expect(b.chestButtons.keys, ['reroll', 'skip', 'take'], reason: 'no Later: Take in its place');
    expect(b.chestPicked, isNull);
    await tapOn(tester, b.chestButtons['take']!.center);
    expect((b.chestOpen, g.chests.length, b.message), (true, 1, null), reason: 'greyed: nothing picked, nothing taken');
    await tapOn(tester, b.chestCards.first.center);
    expect((g.chests.length, b.chestPicked), (1, 0), reason: 'the tap only picks it');
    await tapOn(tester, b.chestCards.first.center);
    expect((g.chests.length, b.chestPicked), (1, 0), reason: 'a tap on it again keeps it picked and takes nothing');
    for (final c in b.chestCards) {
      expect(c.overlaps(b.chestButtons['take']!), isFalse, reason: 'Take is the row\'s, on no card');
    }
    await tapOn(tester, b.chestButtons['take']!.center);
    expect(g.chests, isEmpty);
    expect((b.chestOpen, g.pusaka.containsKey(card)), (false, true));
    expect(b.message, '${relicNames[card]} ★1!');
    expect(loadGame()!.pusaka.containsKey(card), isTrue, reason: 'saved after the pick');
    await frames(tester, 30);
    expect(b.autoStart.left!, lessThan(left), reason: 'the countdown goes on');
    expect(b.chestChip, Rect.zero);
    b.autoStart.set(false);
    await frames(tester, 30);
  });

  testWidgets('Reroll pays and deals new cards; Skip takes two taps and pays; a tap on another card moves the pick, a tap '
      'off the cards keeps it', (tester) async {
    final b = await boot(tester);
    final g = b.state = boardGame(wave: 30)..chestsGiven = 1;
    g.giveChests(2);
    await frames(tester, 30);
    expect(b.chestOpen, isTrue);
    final cards = [...g.chest!.cards!], gold = g.gold;
    await tapOn(tester, b.chestButtons['reroll']!.center);
    expect((g.gold, g.chest!.rerolls), (gold - 2500, 1));
    expect(g.chest!.cards, isNot(cards));
    await tapOn(tester, b.chestCards[1].center);
    expect(b.chestPicked, 1);
    await tapOn(tester, const Offset(4, 4)); // off the panel: nothing taken, the pick kept
    expect((b.chestOpen, b.chestPicked, g.chests.length), (true, 1, 2));
    final gap = b.chestButtons['take']!.left - 2; // between Skip and Take: a near miss of Take
    await tapOn(tester, Offset(gap, b.chestButtons['take']!.center.dy));
    expect((b.chestOpen, b.chestPicked, g.chests.length), (true, 1, 2), reason: 'a near miss keeps it too');
    await tapOn(tester, b.chestCards[2].center);
    expect((b.chestPicked, g.chests.length), (2, 2), reason: 'the pick moves; nothing taken');
    await tapOn(tester, b.chestButtons['skip']!.center);
    expect((g.chests.length, b.chestPicked), (2, null), reason: 'the first tap only arms it, and lets the pick go');
    await tapOn(tester, b.chestButtons['take']!.center);
    expect(g.chests.length, 2, reason: 'Take greyed again: a press on it is one off the buttons, and lets Skip go');
    await tapOn(tester, b.chestButtons['skip']!.center);
    expect(g.chests.length, 2, reason: 'armed again');
    await tapOn(tester, b.chestButtons['skip']!.center);
    expect((g.chests.length, g.gold, b.message), (1, gold - 2500 + 2500, 'Chest skipped: +2500 gold\n${g.skipNote()}'),
        reason: 'from omenFrom a Skip owes the next wave the skip buff, which its message says (decisions-log 319)');
    await frames(tester, 3);
    expect(b.chestOpen, isTrue, reason: 'the next chest due opens');
    await frames(tester, 30);
  });

  testWidgets('no Later: the open chest holds Auto and the Start/Pause toggle until Take or Skip, however long it waits',
      (tester) async {
    final b = await boot(tester);
    final g = b.state = boardGame()..chestsGiven = 1;
    g.giveChests(1);
    b.autoStart.set(true);
    await frames(tester, 30); // the board takes the game in (a new game cancels any countdown)
    b.autoStart.won();
    await frames(tester, 30);
    expect((b.chestOpen, b.autoStart.left), (true, autoStartDelay));
    expect(b.chestButtons.containsKey('later'), isFalse);
    // While it is open the Start/Pause toggle under it takes no press: no wave starts (decisions-log 220).
    final wave = g.wave;
    expect(b.toggleButton, b.startButton);
    await tapOn(tester, b.toggleButton.center);
    await tapOn(tester, const Offset(4, 4));
    await frames(tester, 300);
    expect((b.chestOpen, g.wave, g.waveActive, g.chests.length, b.autoStart.left), (true, wave, false, 1, autoStartDelay));
    expect(b.chestChip, Rect.zero, reason: 'no chip while it is open');
    await tapOn(tester, b.chestCards[1].center);
    await tapOn(tester, b.chestButtons['take']!.center);
    expect((b.chestOpen, g.chests.length), (false, 0));
    await frames(tester, 30);
    expect(b.autoStart.left!, lessThan(autoStartDelay), reason: 'taken: the countdown goes');
    b.autoStart.set(false);
    await frames(tester, 30);
  });

  testWidgets("Start pressed in a boss win's cheer opens its chest and starts no wave; Auto's wave comes only once it is "
      'taken; the "Chest!" chip shows in the cheer, never mid-wave', (tester) async {
    final b = await boot(tester);
    final g = b.state = boardGame()..towns = false; // no Town due: Start shows in the cheer
    b.autoStart.set(true);
    await frames(tester, 30);
    g
      ..startWave()
      ..queue.clear()
      ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
    await frames(tester, 3); // the boss wave won: its chest rolled, the cheer on
    expect((g.wave, g.chests.length, b.chestOpen), (5, 1, false));
    expect(b.chestChip.isEmpty, isFalse, reason: 'it waits behind the cheer');
    expect(g.t - g.victoryAt, lessThan(victoryTime));
    final left = b.autoStart.left!;
    await tapOn(tester, b.startButton.center); // Start in the cheer, before the popup opened
    expect((g.wave, g.waveActive, b.chestOpen, b.chestChip), (5, false, true, Rect.zero), reason: 'the chest, not the wave');
    expect(g.t - g.victoryAt, lessThan(victoryTime), reason: 'opened in the cheer');
    await frames(tester, 200);
    expect((b.chestOpen, g.waveActive, b.autoStart.left), (true, false, left), reason: 'Auto waits for it');
    await tapOn(tester, b.chestCards.first.center);
    await tapOn(tester, b.chestButtons['take']!.center);
    await tapOn(tester, b.messageBox.center);
    expect((b.chestOpen, g.chests.length), (false, 0));
    for (var i = 0; i < 600 && !g.waveActive; i++) {
      await frames(tester, 1);
    }
    expect((g.waveActive, g.wave), (true, 6), reason: "taken: Auto's countdown runs out and starts the wave");
    // No chest can wait mid-wave now; one there anyway (put in by hand) shows no chip.
    g.chests.add(Chest(ChestKind.boss, 5, cards: [Relic.ironBanner, Relic.grail, Relic.dragonCrown]));
    await frames(tester, 3);
    expect((g.waveActive, b.chestOpen, b.chestChip), (true, false, Rect.zero));
    b.autoStart.set(false);
    await frames(tester, 30);
  });

  testWidgets("with a new Hero's splash due, Start in the cheer opens nothing and starts no wave: the splash, then the chest",
      (tester) async {
    final b = await boot(tester);
    final g = b.state = boardGame()..towns = false;
    await frames(tester, 30);
    g
      ..startWave()
      ..queue.clear()
      ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
    await frames(tester, 3);
    g.heroMade.add(g.troops.first); // a splash after the cheering
    await frames(tester, 2);
    await tapOn(tester, b.startButton.center);
    expect((g.wave, g.waveActive, b.chestOpen, b.heroSplash), (5, false, false, null), reason: 'nothing yet');
    for (var i = 0; i < 400 && b.heroSplash == null; i++) {
      await frames(tester, 1);
    }
    expect(b.heroSplash, isNotNull, reason: 'the splash first');
    expect(b.chestOpen, isFalse);
    await tapOn(tester, const Offset(4, 4)); // closes the splash
    await frames(tester, 3);
    expect((b.heroSplash, b.chestOpen, g.waveActive), (null, true, false), reason: 'then the chest');
    await frames(tester, 30);
  });

  testWidgets("the owner's w86 save: its 3 catch-up chests open one after another, none can wait, saved once rolled",
      (tester) async {
    final b = await boot(tester);
    final g = b.state = w86().boardRules();
    await frames(tester, 3);
    expect((b.chestOpen, g.chests.length, g.chest!.title), (true, 3, 'Missed Chest 1/3'));
    expect(g.chest!.cards, hasLength(3));
    expect(loadGame()!.chests.first.cards, g.chest!.cards, reason: 'rolled and saved: a reload shows the same');
    expect(b.message, isNotNull, reason: "the save's notes, over the popup");
    await tapOn(tester, const Offset(2, 2)); // closes them, and does nothing else
    expect((b.message, b.chestOpen), (null, true));
    expect(b.chestHint, 'Tap a card to pick it');
    await tapOn(tester, b.chestCards.first.center);
    await tapOn(tester, b.chestButtons['take']!.center);
    await tapOn(tester, b.messageBox.center); // the take's message
    await frames(tester, 3);
    expect((b.chestOpen, g.chests.length, g.chest!.title, b.chestPicked), (true, 2, 'Missed Chest 2/3', null),
        reason: 'the next opens with nothing picked');
    await frames(tester, 150);
    expect((b.chestOpen, g.chests.length, b.chestChip), (true, 2, Rect.zero), reason: 'two waiting: still open, no chip');
    await tapOn(tester, b.chestCards.last.center);
    await tapOn(tester, b.chestButtons['take']!.center);
    await tapOn(tester, b.messageBox.center);
    await frames(tester, 3);
    expect((b.chestOpen, g.chests.length, g.chest!.title), (true, 1, 'Missed Chest 3/3'));
    await frames(tester, 30);
  });

  testWidgets('a save holding two chests put off with Later (before decisions-log 281) loads with the first open at once; '
      'the second follows', (tester) async {
    final b = await boot(tester);
    final saved = boardGame(wave: 30)..chestsGiven = 3;
    saved.chests.addAll([
      Chest(ChestKind.boss, 25, cards: [Relic.ironBanner, Relic.grail, Relic.dragonCrown]),
      Chest(ChestKind.boss, 30, cards: [Relic.godThunder, Relic.mourningBell, null]),
    ]);
    expect(saveGame(saved), isTrue);
    final g = b.state = loadGame()!.boardRules();
    await frames(tester, 3);
    expect((b.chestOpen, g.chests.length, g.chest!.wave), (true, 2, 25));
    expect(b.chestButtons.keys, ['reroll', 'skip', 'take']);
    expect(b.chestChip, Rect.zero);
    await tapOn(tester, b.chestCards[1].center);
    await tapOn(tester, b.chestButtons['take']!.center);
    expect((g.pusaka.containsKey(Relic.grail), g.chests.length), (true, 1));
    await frames(tester, 3);
    expect((b.chestOpen, g.chest!.wave, b.chestPicked), (true, 30, null), reason: 'the next one, nothing picked');
    await frames(tester, 30);
  });

  for (final size in const [Size(915, 412), Size(1266, 713)]) {
    testWidgets('it fits ${size.width.round()}x${size.height.round()}: the cards and the buttons on the screen, apart, a '
        'card picked too', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = boardGame(wave: 86)..chestsGiven = 1;
      // The longest cards: Grail of Immortality, God's Thunder's and Mourning Bell's two lines.
      g.chests.add(Chest(ChestKind.catchUp, 86, cards: [Relic.grail, Relic.godThunder, Relic.mourningBell], n: 3, of: 3));
      await frames(tester, 30);
      expect(b.chestOpen, isTrue);
      fitsApart(b.chestCards, size, 'cards');
      fitsApart([for (final e in b.chestButtons.entries) e.value], size, 'buttons');
      for (final c in b.chestCards) {
        for (final r in b.chestButtons.values) {
          expect(c.overlaps(r), isFalse, reason: 'card $c over button $r');
        }
      }
      await tapOn(tester, b.chestCards.last.center);
      fitsApart(popupRects(b), size, 'a card picked'); // lifted, it stays clear of the row
      expect(b.chestButtons.keys, ['reroll', 'skip', 'take']);
      await frames(tester, 30);
    });
  }

  testWidgets("a card's frame is the page card recoloured by its rarity, no ink box drawn over it, and its rarity named in its "
      'ink', (tester) async {
    final key = GlobalKey();
    final b = await boot(tester, const Size(1266, 713), key);
    // Each card's ink (its rarity's name; until 2026-10-02 also a box over the frame), and its frame's rim and dark rim
    // (chest_popup.dart's _rarityFrame): Epic, Rare, Legendary, and a Shard's, which names no rarity.
    const looks = <Relic?, (int, int, int)>{
      Relic.godThunder: (0xFF9B4DFF, 0xFFB98CF0, 0xFF7E50C8),
      Relic.ironBanner: (0xFF3FA34D, 0xFF8CC878, 0xFF4E8C46),
      Relic.dragonCrown: (0xFFFF9F1C, 0xFFF2C23C, 0xFFC8821E),
      null: (0xFF8A9BB0, 0xFFA4B2C6, 0xFF6A7A92),
    };
    for (final cards in [
      <Relic?>[Relic.godThunder, Relic.ironBanner, Relic.dragonCrown],
      <Relic?>[null, Relic.ironBanner, Relic.godThunder],
    ]) {
      final g = b.state = boardGame(wave: 30)..chestsGiven = 1;
      g.chests.add(Chest(ChestKind.boss, 30, cards: cards));
      await frames(tester, 30);
      expect(b.chestOpen, isTrue);
      for (var lifted = -1; lifted < 3; lifted++) {
        if (lifted >= 0) await tapOn(tester, b.chestCards[lifted].center);
        final px = await screenPixels(tester, key);
        for (final (i, r) in b.chestCards.indexed) {
          final (ink, rim, dark) = looks[cards[i]]!;
          final up = i == lifted;
          final why = '${cards[i]?.name ?? 'serpihan'}${up ? ' lifted' : ''}';
          final edge = px(r.center.dx.round(), r.top.ceil() + 1); // the top rim's middle: the lit frame's is its dark line
          expect(near(edge, up ? dark : rim), isTrue, reason: '$why: its frame 0x${edge.toRadixString(16)}');
          var box = 0, named = 0;
          for (var y = r.top.ceil(); y < r.bottom.floor(); y++) {
            for (var x = r.left.ceil(); x < r.right.floor(); x++) {
              if (!near(px(x, y), ink)) continue;
              if (r.deflate(8).contains(Offset(x + 0.5, y + 0.5))) {
                named++;
              } else {
                box++;
              }
            }
          }
          expect(box, 0, reason: '$why: no ink box along the frame');
          if (cards[i] != null && lifted < 0) expect(named, greaterThan(4), reason: '$why: its rarity named in its ink');
        }
      }
      await tapOn(tester, const Offset(2, 2)); // the lifted card back down
    }
    await frames(tester, 30);
    // The frame's colours are the real art's (ui_book.png's card, recoloured): placeholder art draws another frame, so
    // the public repo's `flutter test -x art` leaves this test out (testing.md "Placeholder art").
  }, tags: 'art');

  test("every line the chest shows is in the HUD's font (a '★' is drawn as the star icon, so it is left out; no '→')", () {
    final font = fontChars();
    final g = Game()..boardRules();
    final lines = <String>[
      'Boss Chest', 'Missed Chest 1/3', 'Boss Chest: pick 1 of 3!', 'Chest!', 'Chest! x2', 'Take', 'Skip +38k',
      'Sure? +38k', 'Reroll 2.5k', 'Free Reroll', 'Need 38k gold', 'Tap a card to pick it', 'Tap Take to get it', 'Shard',
      'One free Reroll, kept', 'You have: 2', 'Shard x2   Gold 1.2k', 'Shard +1: one free Reroll', 'Chest skipped: +38k gold',
      'New: to Vault', 'In Vault', 'Artifacts: Boss Chest only', 'Shop Artifacts', 'Shop Artifact',
      ...rarityNames.values,
      chestRefusals.over, chestRefusals.midWave, chestRefusals.none, chestRefusals.gold,
      for (final r in Relic.values)
        if (r.pusaka) ...[
          relicNames[r]!,
          '${relicNames[r]} ★3!',
          '${relicNames[r]}: Oath for all troops!',
          for (final stars in [1, 2, 3]) ...g.relicEffect(r, stars: stars),
          for (final t in troopTypeNames.values) ...['New: for $t', 'On $t'],
          offerLine(OfferPicked(5, 0, pick: r, stars: 2, type: 'knight', rerolls: 0, chest: 'boss', chestWave: 5)),
          offerLine(OfferPicked(86, 0, pick: r, stars: 1, rerolls: 1, chest: 'catchUp', chestWave: 86)),
        ],
      offerLine(OfferPicked(5, 0, serpihan: true, rerolls: 0, chest: 'boss', chestWave: 5)),
      offerLine(OfferPicked(86, 0, skipped: true, gain: 38000, rerolls: 2, chest: 'boss', chestWave: 86)),
    ];
    for (final line in lines) {
      expect([for (final ch in line.replaceAll('★', '').runes) if (!font.contains(ch)) String.fromCharCode(ch)], isEmpty, reason: line);
    }
    expect(offerLine(OfferPicked(5, 0, pick: Relic.ironBanner, stars: 1, type: 'knight_templar', rerolls: 0, chest: 'boss', chestWave: 5)),
        'Boss Chest: Iron Banner ★1 (Rare) to ${troopTypeNames['knight_templar']}');
    expect(offerLine(OfferPicked(5, 0, pick: Relic.ironBanner, stars: 2, rerolls: 0, chest: 'boss', chestWave: 5)),
        'Boss Chest: Iron Banner ★2 (Rare) to Vault');
    expect(offerLine(OfferPicked(5, 0, serpihan: true, rerolls: 0, chest: 'boss', chestWave: 5)), 'Boss Chest: Shard');
    expect(offerLine(OfferPicked(86, 0, skipped: true, gain: 38000, rerolls: 0, chest: 'catchUp', chestWave: 86)), 'Missed Chest skipped: +38k gold');
  });
}
