// The Shadows on the board (catalog step 0h, decisions-log 191; lib/omen_look.dart, docs/ui-hud.md "Shadows"), with
// [omensOn] forced on: a chest card shows its hidden Shadow as "?" and red "!" marks in a row of their own; the
// first chest says what the marks mean, an armed Skip what it brings; a take flips the marks over (the taken one to its
// kind and level, the others "Dodged"), the ribbon says what the monsters got, a tap skips it and Auto waits for it;
// the chips under the wave meter (at most 8: seven kinds and Skip's "!") fit with the popup and two boss bars at
// 915x412 and 1266x713, and their tapped tooltip wraps inside the screen and under them (at 915x412 wider,
// decisions-log 291); a boss's Barrier shows as a teal segment on its bar and the teal ring at its feet; a reload after
// a take or a reroll keeps it all; the owner's w89 save gets its catch-up note and 2 levels a wave; every line is in the
// HUD's font. With omens off nothing of it shows
// (and test/probe_omen_shots.dart's off shots equal main's). The rules: omen_test.dart, omen_hooks_test.dart.
// One TdGame per widget test; the queue's runs have a temp HOME (flutter_test_config.dart): the real save is untouched.
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
import 'package:tower_defense/hud_font.dart' show hudStyle;
import 'package:tower_defense/main.dart';
import 'package:tower_defense/save.dart' show loadGame;

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

/// The screen as drawn now (boot's RepaintBoundary under [key]): its pixel at (x, y) as 0xAARRGGBB.
Future<int Function(int, int)> screenPixels(WidgetTester tester, GlobalKey key) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final img = (await tester.runAsync(() => boundary.toImage()))!;
  final px = (await tester.runAsync(() => img.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  return (x, y) {
    if (x < 0 || y < 0 || x >= img.width || y >= img.height) return 0;
    final i = (y * img.width + x) * 4;
    return px.getUint8(i + 3) << 24 | px.getUint8(i) << 16 | px.getUint8(i + 1) << 8 | px.getUint8(i + 2);
  };
}

/// Colour [a] within 4 of [b] in each of red, green and blue.
bool near(int a, int b) => [16, 8, 0].every((s) => ((a >> s & 0xFF) - (b >> s & 0xFF)).abs() <= 4);

/// A teal pixel, blended or not: green and blue high and close, red well under them (the Barrier's ring at its pulse).
bool tealish(int a) {
  final (r, g, b) = (a >> 16 & 0xFF, a >> 8 & 0xFF, a & 0xFF);
  return g > 0x80 && b > 0x80 && (g - b).abs() < 0x30 && r < g - 0x40;
}

/// The pixels in [r] that [test] picks.
int count(int Function(int, int) px, Rect r, bool Function(int) test) {
  var n = 0;
  for (var y = r.top.floor(); y < r.bottom.ceil(); y++) {
    for (var x = r.left.floor(); x < r.right.ceil(); x++) {
      if (test(px(x, y))) n++;
    }
  }
  return n;
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

/// A board game between waves with the chest on and no army limit, three troops, gold to spare, at [wave].
Game omenGame({int wave = 30}) {
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

/// A Legenda, an Epik and a Langka card (3, 2 and 1 marks), hiding Armor, Haste and Wound.
const threeCards = [Relic.dragonCrown, Relic.godThunder, Relic.ironBanner];
const threeFaces = [OmenKind.armor, OmenKind.haste, OmenKind.wound];

/// A boss chest of wave [wave] with [threeCards] and, while [faces], [threeFaces].
Chest omenChest({int wave = 30, bool faces = true}) => Chest(ChestKind.boss, wave, cards: [...threeCards], omens: faces ? [...threeFaces] : null);

/// The owner's wave-89 save from before the Shadows (6 Pusaka owned: 12 levels owed).
Game w89() => Game.fromJson(jsonDecode(File('test/fixtures/save-20261002-2222-w89-sellbug.json').readAsStringSync()) as Map<String, dynamic>);

const sizes = [Size(915, 412), Size(1266, 713)];

/// The most kinds the monsters hold at once ([omenKindsMax]): today's seven and one of batch L-1B's (Hard Shell, a
/// 48 px effect frame). With Skip's "!" that is 9 chips, the longest row the game can show.
final most = [...OmenKind.values.take(7), OmenKind.hardShell];

/// How far down the chips and the boss bars may reach on a [size] screen: the field's bottom.
double fieldBottom(Size size) => size.height;

void main() {
  setUp(() => omensOn = true);
  tearDown(() => omensOn = false);

  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('$tag: the 3-face popup fits, and so does a row of 9 chips (8 kinds, the most held, and Skip) with the HUD',
        (tester) async {
      final b = await boot(tester, size);
      final g = b.state = omenGame()..chestsGiven = 1;
      g
        ..omens.addAll([for (final k in most) ...List.filled(omenCap, k)])
        ..skipBuffDue = true
        ..chests.add(omenChest());
      await frames(tester, 30);
      expect(b.chestOpen, isTrue);
      expect(b.chestFaces, ['?!!!', '?!!', '?!'], reason: 'Legendary 3 marks, Epic 2, Rare 1; the kind hidden');
      fitsApart(b.chestCards, size, 'cards');
      fitsApart([...b.chestButtons.values], size, 'buttons');
      for (final c in b.chestCards) {
        for (final r in b.chestButtons.values) {
          expect(c.overlaps(r), isFalse, reason: 'card $c over button $r');
        }
      }
      await tapOn(tester, b.chestCards.last.center);
      expect(b.chestPicked, 2);
      fitsApart([...b.chestCards, ...b.chestButtons.values], size, 'a card picked'); // lifted, clear of the row's Take
      await tapOn(tester, b.chestButtons['skip']!.center); // no Later (decisions-log 281): Skip shuts it, its "!" held already
      await tapOn(tester, b.chestButtons['skip']!.center);
      await tapOn(tester, b.messageBox.center);
      await frames(tester, 5);
      expect((b.chestOpen, g.chests.length), (false, 0));

      final row = b.omenRow, chips = b.omenChips;
      expect(most, hasLength(omenKindsMax));
      expect(chips, hasLength(omenKindsMax + 1));
      expect([for (final (_, k) in chips) k], [...most, null], reason: 'each kind in order, then Skip\'s "!"');
      expect((Offset.zero & size).intersect(row), row, reason: 'on the screen');
      for (final (r, _) in chips) {
        expect(row.intersect(r), r, reason: 'a chip inside its row');
      }
      final aside = b.bookArea != Rect.zero && size.width > size.height;
      // The troop counter's rect is its press area, 2·k round what it draws; the gold panel stands for the top row.
      if (aside) {
        // Landscape between waves: the book shows, so they go to the left under the top row, as the map does.
        expect(row.left, lessThanOrEqualTo(10), reason: 'at the left');
        expect(row.right, lessThan(b.bookArea.left), reason: 'clear of the book');
        expect(row.top, greaterThan(b.goldPanel.bottom), reason: 'under the top row');
      } else {
        expect(row.right, b.waveMeter.right, reason: 'right-aligned with the wave meter');
        expect(row.top, greaterThan(b.waveMeter.bottom), reason: 'under it');
      }
      fitsApart([row, b.waveMeter, b.chestChip, b.startButton, b.autoButton, if (!aside) b.troopCounter, b.goldPanel, b.logButton]
          .where((r) => !r.isEmpty).toList(), size, 'the chips and the HUD');
      expect(row.bottom, lessThan(fieldBottom(size)), reason: 'on the field');
    });

    testWidgets('$tag: two boss bars stay on the field under a row of 9 chips', (tester) async {
      final b = await boot(tester, size);
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
        ..waveSpawned = 30
        ..omens.addAll(most)
        ..waveSkipBuff = true;
      for (final (type, tier, at) in [('werebear', Tier.miniBoss, Point(knight.pos.x + 70, 14.0)), (boss, Tier.boss, Point(knight.pos.x + 110, 60.0))]) {
        g.units.add(g.monster(type, tier, at)
          ..entered = true
          ..stunUntil = 1e9);
      }
      await frames(tester, 40); // the book closes, the camera settles
      final row = b.omenRow, bars = b.bossBars;
      expect(b.omenChips, hasLength(omenKindsMax + 1));
      expect(bars, isNot(Rect.zero));
      expect(bars.top, greaterThan(row.bottom), reason: 'under the chips');
      expect((Offset.zero & size).intersect(bars), bars, reason: 'on the screen');
      expect(bars.bottom, lessThanOrEqualTo(fieldBottom(size)), reason: 'on the field');
      expect(b.coveredAt(row.center), isTrue, reason: 'no unit is pointed at through the chips');
      expect(g.over, isFalse);
    });
  }

  testWidgets('the marks get a row of their own: a card with them is taller', (tester) async {
    final b = await boot(tester, const Size(915, 412));
    final heights = <bool, List<double>>{};
    for (final size in const [Size(915, 412), Size(1266, 713)]) {
      tester.view.physicalSize = size;
      for (final faces in [false, true]) {
        final g = b.state = omenGame()..chestsGiven = 1;
        g.chests.add(omenChest(faces: faces));
        await frames(tester, 30);
        expect(b.chestFaces, hasLength(faces ? 3 : 0));
        heights[faces] = [for (final r in b.chestCards) r.height];
      }
      expect(heights[true]![0], greaterThan(heights[false]![0]), reason: '$size: "Monsters: ?!!!" at the bottom');
    }
  });

  testWidgets('the hint: what the marks mean on the first chest, what an armed Skip brings; Skip leaves a "!" chip for the '
      'next wave', (tester) async {
    final b = await boot(tester, const Size(915, 412));
    final g = b.state = omenGame()..chestsGiven = 1;
    g.chests.addAll([omenChest(), omenChest()]);
    await frames(tester, 30);
    expect(b.chestHint, 'Each card gives monsters a ${Words.shadow} (! = how strong)');
    await tapOn(tester, b.chestCards.first.center);
    expect(b.chestHint, 'Tap ${Words.take} to get it');
    await tapOn(tester, b.chestButtons['skip']!.center);
    expect(b.chestHint, 'Skip: next wave, the first 30% of monsters get +10% to all');
    final gold = g.gold;
    await tapOn(tester, b.chestButtons['skip']!.center);
    expect((g.chests.length, g.skipBuffDue), (1, true));
    expect(g.omens, isEmpty);
    expect(b.message, 'Chest skipped: +${shortPrice(g.gold - gold)} gold\nSkip: next wave, the first 30% of monsters get +10% to all');
    await tapOn(tester, b.messageBox.center);
    await frames(tester, 3);
    expect(b.chestOpen, isTrue, reason: 'the next chest');
    await tapOn(tester, b.chestButtons['skip']!.center); // no Later (decisions-log 281): Skip shuts it too
    await tapOn(tester, b.chestButtons['skip']!.center);
    await tapOn(tester, b.messageBox.center);
    await frames(tester, 3);
    expect((b.chestOpen, g.chests.length), (false, 0));
    expect([for (final (_, k) in b.omenChips) k], [null], reason: 'only the "!" while no kind is held');
    await tapOn(tester, b.omenRow.center);
    await frames(tester, 10);
    expect(b.tooltipShown?.$1, 'Monster ${Words.shadow}s');
    expect(b.tooltipShown!.$2.join(' '), 'Skip: next wave, the first 30% of monsters get +10% to all');
    g.startWave();
    await frames(tester, 3);
    expect((g.skipBuffDue, g.waveSkipBuff), (false, true));
    expect([for (final (_, k) in b.omenChips) k], [null], reason: 'its wave keeps the chip');
    expect(g.omenTip.$2, ['Skip: this wave, the first 30% of monsters get +10% to all']);
  });

  testWidgets('a take: the marks flip over (the taken one to its kind and level, the others "Dodged"), the ribbon says what the '
      'monsters got, Auto waits; a tap skips it, or it ends by itself; then the message', (tester) async {
    final b = await boot(tester);
    final g = b.state = omenGame()..chestsGiven = 1;
    g.chests.addAll([omenChest(), omenChest()]);
    b.autoStart.set(true);
    await frames(tester, 30);
    b.autoStart.won();
    await frames(tester, 30);
    expect((b.chestOpen, b.autoStart.left), (true, autoStartDelay));
    await tapOn(tester, b.chestCards.first.center);
    await tapOn(tester, b.chestButtons['take']!.center);
    expect(g.omenLevel(OmenKind.armor), 3, reason: 'a Legenda: 3 levels');
    expect((b.chestOpen, b.chestRevealing, b.chestRevealLine, b.message), (false, true, 'Monsters got Armor 3', null));
    expect(b.chestCards, hasLength(3), reason: 'the cards as they were');
    expect(b.chestButtons, isEmpty, reason: 'greyed: nothing to press');
    await frames(tester, (omenFlip * 2 * 60).ceil() + 4); // both flips over (the others start half a flip later)
    expect(b.chestFaces, ['Armor 3', 'Dodged', 'Dodged']);
    expect(b.chestRevealing, isTrue);
    expect(b.autoStart.left, autoStartDelay, reason: 'Auto waits for it');
    expect(b.chestChip, Rect.zero, reason: 'no chip under it');

    await tapOn(tester, const Offset(4, 4)); // a tap skips it
    expect(b.chestRevealing, isFalse);
    expect(b.message, '${relicNames[Relic.dragonCrown]} ★1!\nMonsters got Armor 3: Monsters take 15% less damage.');
    await tapOn(tester, b.messageBox.center);
    await frames(tester, 3);
    expect(b.chestOpen, isTrue, reason: 'the next chest opens');

    // The second: an Epik's face, Haste 2, left to end by itself.
    await tapOn(tester, b.chestCards[1].center);
    await tapOn(tester, b.chestButtons['take']!.center);
    expect((b.chestRevealing, b.chestRevealLine), (true, 'Monsters got Haste 2'));
    await frames(tester, (omenRevealFor * 60).ceil() - 10);
    expect((b.chestRevealing, b.message), (true, null));
    await frames(tester, 14);
    expect(b.chestRevealing, isFalse);
    expect(b.message, '${relicNames[Relic.godThunder]} ★1!\nMonsters got Haste 2: Monsters attack 10% faster.');
    await frames(tester, 30);
    expect(b.autoStart.left!, lessThan(autoStartDelay), reason: 'then the countdown goes on');
    b.autoStart.set(false);
    expect([for (final (_, k) in b.omenChips) k], [OmenKind.armor, OmenKind.haste]);
    await frames(tester, 30);
  });

  // At the tablet's 1164x777 the long lines wrap at 360 px; at the phone's 915x412 that box would be taller than the room
  // under the chips, so the lines wrap at 600 px there and none needs a second row (decisions-log 291).
  for (final (size, wrapped) in const [(Size(915, 412), false), (Size(1164, 777), true)]) {
    final at = '${size.width.round()}x${size.height.round()}';
    testWidgets("at $at the chips' tooltip: a tap shows it, wrapped to its width, under the chips and inside the screen; "
        'another tap, or any press, hides it', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = omenGame()..chestsGiven = 1;
      // The most kinds a game holds (omenKindsMax): Armor, Mend and Escort, and the five others with the longest lines.
      final pinned = {OmenKind.armor, OmenKind.mend, OmenKind.guard};
      final others = [for (final k in OmenKind.values) if (!pinned.contains(k)) k]
        ..sort((a, b) => b.hud.length.compareTo(a.hud.length));
      final held = {...pinned, ...others.take(omenKindsMax - pinned.length)};
      g
        ..omens.addAll([for (final k in OmenKind.values) if (held.contains(k)) k])
        ..omensOwed.addAll([OmenKind.wound, OmenKind.mend, OmenKind.armor])
        ..skipBuffDue = true;
      await frames(tester, 30);
      await tapOn(tester, b.omenRow.center);
      await frames(tester, 30);
      final (title, lines) = g.omenTip;
      expect(title, 'Monster ${Words.shadow}s');
      expect(lines, [
        for (final k in OmenKind.values)
          if (held.contains(k)) g.omenLine(k),
        'Late ${Words.shadow}: 3 more, 2 each wave',
        'Skip: next wave, the first 30% of monsters get +10% to all',
      ]);
      expect(g.omenLine(OmenKind.armor), 'Armor 1: Monsters take 5% less damage.');
      expect(g.omenLine(OmenKind.mend), 'Mend 1: Monsters heal 0.3% HP a second. Not the boss or mini boss.');
      expect(g.omenLine(OmenKind.guard), 'Escort 1: Each boss and mini boss brings 1 more strong monster.');
      expect(b.tooltipShown?.$1, title);
      final rows = b.tooltipShown!.$2;
      expect(rows.join(' '), lines.join(' '), reason: 'every word, in order');
      if (wrapped) {
        expect(rows.length, greaterThan(lines.length), reason: '$at: the long lines wrapped');
      } else {
        expect(rows, lines, reason: '$at: wide enough that no line wraps');
      }
      final box = b.tooltipBox;
      expect((box.left >= 4, box.right <= size.width - 4, box.top >= b.omenRow.bottom, box.bottom <= size.height - 4),
          (true, true, true, true), reason: '$at: $box');
      await frames(tester, 60);
      expect(b.tooltipShown, isNotNull, reason: 'it stays a while');
      await tapOn(tester, b.omenRow.center); // another tap on the row hides it
      await frames(tester, 3);
      expect(b.tooltipShown, isNull);
      await tapOn(tester, b.omenRow.center);
      await frames(tester, 3);
      expect(b.tooltipShown, isNotNull);
      await tapOn(tester, const Offset(206, 300)); // a press on the field
      await frames(tester, 3);
      expect(b.tooltipShown, isNull);
    });
  }

  testWidgets("a w90 boss's Barrier: a teal segment on its bar, the teal ring at its feet, and its Escort", (tester) async {
    final key = GlobalKey();
    final b = await boot(tester, const Size(1266, 713), key);
    final g = b.state = Game(Random(5), Random(6))
      ..units.clear()
      ..gold = 1000
      ..wave = 89;
    g.omens.addAll([...List.filled(omenCap, OmenKind.shield), ...List.filled(3, OmenKind.guard)]);
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
    expect((g.wave, g.omenGuards), (90, 2));
    final lord = g.monster(boss, Tier.boss, Point(knight.pos.x + 110, 60))
      ..entered = true
      ..stunUntil = 1e9;
    g.units.add(lord);
    expect(lord.shield, closeTo(lord.maxHp * 0.2, 1e-6), reason: 'Barrier 4: 20% of its HP');
    await frames(tester, 40);
    // The ring's alpha pulses (0.35 to 0.85 in about a second, its phase set by the unit's id, so by how many units the
    // tests before made): the most over one pulse.
    Future<(int, int)> teal() async {
      var (bar, ring) = (0, 0);
      for (var i = 0; i < 8; i++) {
        final px = await screenPixels(tester, key), feet = b.toScreen(lord.pos.x, lord.pos.y);
        bar = max(bar, count(px, b.bossBars, (p) => near(p, tintTeal)));
        ring = max(ring, count(px, Rect.fromCenter(center: feet, width: 80, height: 40), tealish));
        await frames(tester, 8);
      }
      return (bar, ring);
    }

    final (bar, ring) = await teal();
    lord.shield = 0; // broken
    await frames(tester, 3);
    final (barAfter, ringAfter) = await teal();
    expect(bar, greaterThan(40), reason: 'the segment');
    expect(barAfter, lessThan(bar ~/ 4), reason: 'gone with the Barrier');
    expect(ring, greaterThan(ringAfter + 10), reason: 'the ring: $ring with it, $ringAfter without');
  });

  testWidgets('a reload after a reroll and after a take keeps the faces and the levels', (tester) async {
    final b = await boot(tester);
    final g = b.state = omenGame()..chestsGiven = 1;
    g.giveChests(2);
    await frames(tester, 30);
    expect(b.chestOpen, isTrue);
    await tapOn(tester, b.chestButtons['reroll']!.center);
    final chest = g.chest!, faces = [...chest.omens!];
    expect([for (final (i, c) in chest.cards!.indexed) c == null || faces[i] != null], everyElement(isTrue));
    expect(loadGame()!.chests.first.omens, faces, reason: 'the reroll saved its faces');
    final shown = b.chestFaces;
    final i = chest.cards!.indexWhere((c) => c != null);
    await tapOn(tester, b.chestCards[i].center);
    await tapOn(tester, b.chestButtons['take']!.center);
    expect(b.chestRevealing, isTrue);
    await tapOn(tester, const Offset(4, 4));
    await tapOn(tester, b.messageBox.center);
    await frames(tester, 3);
    final held = [...g.omens], next = [...g.chest!.omens!];
    expect(held, isNotEmpty);
    final saved = loadGame()!;
    expect(saved.omens, held);
    expect(saved.chests.first.omens, next);

    b.state = saved; // the reload
    await frames(tester, 30);
    expect(b.chestOpen, isTrue);
    expect(b.chestFaces, hasLength(next.whereType<OmenKind>().length));
    expect([for (final (_, k) in b.omenChips) k], [for (final k in OmenKind.values) if (held.contains(k)) k]);
    expect(shown, hasLength(faces.whereType<OmenKind>().length));
  });

  testWidgets("the owner's w89 save: its catch-up note once, then 2 levels a wave in the chips", (tester) async {
    final b = await boot(tester);
    final g = b.state = w89().boardRules();
    expect(g.omensOwed, hasLength(omenCatchUpMax));
    expect(g.omens, isEmpty);
    await frames(tester, 3);
    expect(b.message, contains('Monsters answer your ${Words.artifact}s: 12 ${Words.shadow}s come, 2 each wave'));
    expect(b.omenChips, isEmpty);
    await tapOn(tester, b.messageBox.center);
    g.startWave();
    await frames(tester, 3);
    expect((g.omens.length, g.omensOwed.length), (2, 10));
    expect([for (final (_, k) in b.omenChips) k], [for (final k in OmenKind.values) if (g.omens.contains(k)) k]);
    expect(g.omenTip.$2, contains('Late ${Words.shadow}: 10 more, 2 each wave'));
    expect(b.message, isNot(contains('Monsters answer')), reason: 'once');
  });

  testWidgets('omens off: no marks, no chips, no reveal, no Barrier ring, as on main', (tester) async {
    omensOn = false;
    final b = await boot(tester);
    final g = b.state = omenGame()..chestsGiven = 1;
    g.chests.add(omenChest()); // faces from a save written while on: ignored
    await frames(tester, 30);
    expect((b.chestOpen, b.chestHint), (true, 'Tap a card to pick it'));
    expect(b.chestFaces, isEmpty);
    await tapOn(tester, b.chestCards.first.center);
    await tapOn(tester, b.chestButtons['take']!.center);
    expect((b.chestRevealing, b.message), (false, '${relicNames[Relic.dragonCrown]} ★1!'));
    expect(g.omens, isEmpty);
    g.omens.add(OmenKind.armor); // even with a level somehow held
    await frames(tester, 3);
    expect(b.omenRow, Rect.zero);
    expect(b.omenChips, isEmpty);
  });

  testWidgets("in a window too narrow for it a Shadow's long take line breaks at its spaces: the message window stays inside "
      'the screen', (tester) async {
    // 320 tall (the message's font 20 x 320/540 px) and a pixel too narrow for the line beside the window's margin and the
    // crate's posts (8 + 28 px a side, message.dart).
    const line = 'Monsters got Off Beat 1: Rare and Epic Artifacts that work every few hits need 1 more hit.';
    final b = await boot(tester, const Size(568, 320));
    final font = 20 * 320 / 540, lineW = TextPaint(style: hudStyle(font)).getLineMetrics(line).width;
    final size = Size((lineW + 2 * (8 + 28) - 1).floorToDouble(), 320);
    expect(size.width, greaterThan(600 * 320 / 540), reason: 'the font still set by the height');
    tester.view.physicalSize = size;
    final g = b.state = omenGame()..chestsGiven = 1;
    g.chests.add(Chest(ChestKind.boss, 30,
        cards: [Relic.warDrum, Relic.titanBane, Relic.snareCord], omens: [OmenKind.offBeat, OmenKind.spellTax, OmenKind.straggler]));
    await frames(tester, 30);
    await tapOn(tester, b.chestCards.first.center);
    await tapOn(tester, b.chestButtons['take']!.center);
    await frames(tester, (omenRevealFor * 60).ceil() + 10); // the reveal ends by itself
    expect(b.message, '${relicNames[Relic.warDrum]} ★1!\n$line');
    await frames(tester, 10);
    final box = b.messageBox;
    expect((box.left >= 8 - 1e-6, box.right <= size.width - 8 + 1e-6), (true, true), reason: '$box');
    expect(box.height, greaterThan(font * 2.25 + 56 + 1), reason: 'its second line broken: two lines are ${font * 2.25 + 56} px tall');
  });

  test("every line the Shadows show is in the HUD's font", () {
    final font = fontChars();
    final g = Game()
      ..omens.addAll([for (final k in OmenKind.values) ...List.filled(omenCap, k)])
      ..omensOwed.addAll([OmenKind.wound, OmenKind.mend]);
    final lines = <String>[
      'Monsters:', 'Dodged', 'Monster ${Words.shadow}s', 'Each card gives monsters a ${Words.shadow} (! = how strong)',
      '  +2 escort', g.skipNote(), g.skipNote(now: true), g.omenCatchUpNote, ...g.omenTip.$2,
      g.omenGotLine([OmenKind.armor]), g.omenGotLine([OmenKind.armor, OmenKind.haste]), g.omenGotLine([]),
      'Over the army cap (48/36): ${Words.shadow}s x1.33',
      for (final k in OmenKind.values) ...[
        '${k.title} 4', g.omenLine(k), ...g.omenPlateKinds,
        for (final from in ['chest', 'catchUp', 'ukir']) logLine(OmenGained(90, 0, omen: k, level: 4, gained: 3, from: from, chestWave: 90)),
        logLine(OmenEased(90, 0, omen: k, level: 3)),
      ],
    ];
    for (final line in lines) {
      expect([for (final ch in line.runes) if (!font.contains(ch)) String.fromCharCode(ch)], isEmpty, reason: line);
    }
    expect(logLine(OmenGained(90, 0, omen: OmenKind.armor, level: 2, gained: 2, from: 'chest', chestWave: 90)),
        'Monsters got Armor 2 (${Words.bossChest} w90)');
  });
}
