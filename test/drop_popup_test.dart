import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';

// #86 loot in hand and the drop popup (lib/drop_popup.dart; ui-hud.md "Loot in hand and the drop popup"): what
// the popup over a troop says, that no troop is ringed, that picked loot stays in hand from troop to troop,
// and where the popup goes; and that loot only held isn't drawn at the pointer over the open book (ghost-book). One
// TdGame per widget test, pressed with tester.tapAt / startGesture.
//
// Never let a wave be won or the game end here (the Board then saves): every test plays between waves, and its
// troops stand still.

/// Boots one TdGame in a 1266x713 window, past the welcome screen, with the game's font and the minimap folded.
Future<Board> boot(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1266, 713)
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

/// Advances the game [n] frames.
Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// A troop of [type] called [name] standing still at ([x], [y]) on [g]'s field.
Unit troopAt(Game g, String type, double x, double y, [String name = '']) {
  final u = Unit(Side.troop, type, g.statsOf(type), Point(x, y))
    ..name = name
    ..entered = true
    ..arriving = false
    ..stunUntil = 1e9;
  g.units.add(u);
  return u;
}

/// Where to point at [u] on the screen: just above its feet.
Offset at(Board b, Unit u) => b.toScreen(u.pos.x, u.pos.y - 3);

Future<void> tapOn(WidgetTester tester, Offset p) async {
  await tester.tapAt(p);
  await frames(tester);
}

/// Turns the open book to its Tas page.
Future<void> openBag(WidgetTester tester, Board b) async {
  await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
  expect(b.bagOpen, isTrue);
}

/// The old rings round the troops an item or a relic would go to (amber, red, yellow): none may be drawn.
Matcher get noRing => isNot(anyOf(
      paints..circle(color: Colors.amber, style: PaintingStyle.stroke),
      paints..circle(color: const Color(0xFFE0402A), style: PaintingStyle.stroke),
      paints..circle(color: const Color(0xFFFFD54F), style: PaintingStyle.stroke),
    ));

final board = find.byWidgetPredicate((w) => w is GameWidget);

/// The drop popup this frame is up, on the [size] screen, off the [pointer] and clear of every HUD rect (#74).
void expectClear(Board b, Size size, Offset pointer, String why) {
  final box = b.dropPopup, screen = Offset.zero & size;
  expect(box, isNot(Rect.zero), reason: why);
  expect(screen.contains(box.topLeft) && screen.contains(box.bottomRight - const Offset(1, 1)), isTrue, reason: '$why: $box on the screen');
  expect(box.contains(pointer), isFalse, reason: '$why: $box off the pointer $pointer');
  for (final r in [
    b.bookArea, b.bossBars, b.logButton, b.logPanel, b.troopCounter, b.troopList, b.waveMeter, b.miniMap, //
    b.autoButton, b.startButton, b.livesBar, b.goldPanel, b.speedButton, b.pauseButton, b.bookButton,
  ]) {
    final i = box.intersect(r);
    expect(i.width > 0 && i.height > 0, isFalse, reason: '$why: $box clear of $r');
  }
}

void main() {
  testWidgets('loot over a troop: a popup for the troop it would go to (an item: its whole type), why it can\'t in red, and no troop ringed',
      (tester) async {
    final b = await boot(tester);
    final g = b.state = Game()..units.clear();
    final aldo = troopAt(g, 'knight', 40, 50, 'Aldo Ash'), bima = troopAt(g, 'knight', 40, 90, 'Bima Sakti');
    final citra = troopAt(g, 'priest', 15, 70, 'Citra Dewi');
    g.inventory[Item.sword] = 3;
    g.relicBag[Relic.fang] = 1;
    await frames(tester, 40); // the book floats in
    await openBag(tester, b);

    // A sword dragged out of the bag onto a knight: what it does to every knight.
    final drag = await tester.startGesture(b.bagSlot(Item.sword).center);
    await drag.moveBy(const Offset(-30, 0));
    await frames(tester);
    await drag.moveTo(at(b, aldo));
    await frames(tester);
    expect(b.dropFor, aldo);
    expect(b.dropLines, ['Every ${troopTypeNames['knight']} (2)', '${statName(StatKind.dmg)} 20 > 25', '${itemNames[Item.sword]} 0/3 > 1/3', '${awakenName(1)}: 0/11 > 1/11']); // its grade I set: 11
    expect(board, noRing);
    // Over the priest, whose recipe takes no sword: why, and nothing before and after.
    await drag.moveTo(at(b, citra));
    await frames(tester);
    expect(b.dropFor, citra);
    expect(b.dropLines, ['Every ${troopTypeNames['priest']} (1)', refusalNames[Refusal.notInRecipe]]);
    // The knights at their grade I cap (grade II's swords come with Awaken 1): why, and their count.
    g.upgrades['knight'] = [Item.sword, Item.sword, Item.sword];
    await drag.moveTo(at(b, bima));
    await frames(tester);
    expect(b.dropFor, bima);
    expect(b.dropLines, ['Every ${troopTypeNames['knight']} (2)', refusalNames[Refusal.maxed], '${itemNames[Item.sword]} 3/3']);
    expect(board, noRing);
    // Let go there: refused, the bag keeps it, and it stays in hand.
    await drag.up();
    await frames(tester);
    expect((g.inventory[Item.sword], g.countOf('knight', Item.sword), b.picked), (3, 3, Item.sword));

    // A relic: that one troop's name and type, and the relic's effect; on a troop holding one, which, in red.
    bima.relics.add(Relic.guard);
    final relic = await tester.startGesture(b.bagSlot(Relic.fang).center);
    await relic.moveBy(const Offset(-30, 0));
    await frames(tester);
    await relic.moveTo(at(b, aldo));
    await frames(tester);
    expect(b.dropFor, aldo);
    expect(b.dropLines, ['Aldo Ash', troopTypeNames['knight'], 'Heals 30% of damage dealt']);
    expect(board, noRing);
    await relic.moveTo(at(b, bima));
    await frames(tester);
    expect(b.dropFor, bima);
    expect(b.dropLines, ['Bima Sakti', troopTypeNames['knight'], holdsRelic(Relic.guard)]);
    expect(board, noRing);
    // Off every troop: no popup.
    await relic.moveTo(b.toScreen(80, 20));
    await frames(tester);
    expect((b.dropFor, b.dropPopup), (null, Rect.zero));
    await relic.up();
    await frames(tester);
    expect((b.picked, g.relicBag[Relic.fang]), (null, 1)); // let go on bare ground: put back
  });

  testWidgets('loot picked once stays in hand: a tap or a drop on a troop gives one each time, a refused one stays, '
      'and it goes when the bag runs out or is put back', (tester) async {
    final b = await boot(tester);
    final g = b.state = Game()..units.clear();
    final aldo = troopAt(g, 'knight', 40, 50, 'Aldo Ash'), bima = troopAt(g, 'knight', 40, 90, 'Bima Sakti');
    final citra = troopAt(g, 'priest', 15, 70, 'Citra Dewi');
    g.inventory[Item.sword] = 3;
    await frames(tester, 40);
    await openBag(tester, b);

    // Three swords with one pick: a tap on a knight each, the priest's refusal in between.
    await tapOn(tester, b.bagSlot(Item.sword).center);
    expect(b.picked, Item.sword);
    await tapOn(tester, at(b, aldo));
    expect((g.countOf('knight', Item.sword), g.inventory[Item.sword], b.picked), (1, 2, Item.sword));
    expect(b.pinned, isNull); // the tap gave the sword and pinned nothing
    expect(b.dropFor, aldo); // the finger's last place: the popup tells about the next one
    await tapOn(tester, at(b, citra));
    expect((g.inventory[Item.sword], b.picked), (2, Item.sword));
    expect(b.dropLines, ['Every ${troopTypeNames['priest']} (1)', refusalNames[Refusal.notInRecipe]]);
    expect(b.message, isNull); // the popup says why: no message window over it
    await tapOn(tester, at(b, bima));
    await tapOn(tester, at(b, aldo));
    expect((g.countOf('knight', Item.sword), g.inventory[Item.sword] ?? 0, b.picked), (3, 0, null)); // the bag ran out

    // Put back untouched: Esc (it doesn't pause), a right click, a tap on bare ground, a tap on its slot.
    g.inventory[Item.boots] = 3;
    await frames(tester); // its cell comes in: a kind the bag lacks has none (decisions-log 187)
    Future<void> pick() async {
      await tapOn(tester, b.bagSlot(Item.boots).center);
      expect(b.picked, Item.boots);
    }

    await pick();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await frames(tester);
    expect((b.picked, g.paused), (null, false));
    await pick();
    await tester.tapAt(at(b, aldo), buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
    await frames(tester);
    expect(b.picked, isNull);
    await pick();
    await tapOn(tester, b.toScreen(80, 20));
    expect(b.picked, isNull);
    await pick();
    await tapOn(tester, b.bagSlot(Item.boots).center);
    expect(b.picked, isNull);
    expect((g.inventory[Item.boots], g.countOf('knight', Item.boots)), (3, 0));

    // A drop keeps it in hand too, and a tap gives the next: the knights take 2 boots before they awaken.
    final drag = await tester.startGesture(b.bagSlot(Item.boots).center);
    await drag.moveBy(const Offset(-30, 0));
    await frames(tester);
    await drag.moveTo(at(b, aldo));
    await frames(tester);
    await drag.up();
    await frames(tester);
    expect((g.countOf('knight', Item.boots), g.inventory[Item.boots], b.picked), (1, 2, Item.boots));
    await tapOn(tester, at(b, bima));
    expect((g.countOf('knight', Item.boots), g.inventory[Item.boots], b.picked), (2, 1, Item.boots));
    await tapOn(tester, at(b, aldo)); // capped: refused, still in hand
    expect((g.countOf('knight', Item.boots), g.inventory[Item.boots], b.picked), (2, 1, Item.boots));
    expect(b.dropLines, contains(refusalNames[Refusal.maxed]));

    // Relics the same way, one troop each; one that holds a relic refuses it.
    g.relicBag[Relic.fang] = 2;
    await frames(tester);
    await tapOn(tester, b.bagSlot(Relic.fang).center);
    expect(b.picked, Relic.fang);
    await tapOn(tester, at(b, aldo));
    expect((aldo.relics.firstOrNull, g.relicBag[Relic.fang], b.picked), (Relic.fang, 1, Relic.fang));
    await tapOn(tester, at(b, aldo));
    expect((g.relicBag[Relic.fang], b.picked), (1, Relic.fang));
    expect(b.dropLines.last, holdsRelic(Relic.fang));
    await tapOn(tester, at(b, bima));
    expect((bima.relics.firstOrNull, g.relicBag[Relic.fang], b.picked), (Relic.fang, 0, null));
    await frames(tester, 10); // the last tap's gesture timers run out
  });

  testWidgets('a Pusaka in hand shows its stars by the pointer, as its Tas slot does, not the bag\'s count (bound it is '
      '0, in the Gudang 1); carried onto a troop it is refused and stays in hand', (tester) async {
    final b = await boot(tester);
    final g = b.state = Game()..units.clear();
    final aldo = troopAt(g, 'knight', 40, 50, 'Aldo Ash');
    g
      ..inventory[Item.sword] = 3
      ..givePusaka(Relic.dragonHeart, type: 'knight', stars: 2);
    await frames(tester, 40);
    await openBag(tester, b);
    expect(b.heldCount, isNull); // nothing in hand

    // Bound: the bag counts it 0, and the loot at the pointer says ★2 (it said "x0"). Over the book it isn't drawn at
    // the pointer (ghost-book): the mouse shows it on bare ground (a tap there would put it back).
    await tapOn(tester, b.bagSlot(Relic.dragonHeart).center);
    expect((b.picked, b.heldCount), (Relic.dragonHeart, null));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(b.toScreen(80, 20));
    await frames(tester);
    expect((b.picked, g.inBag(Relic.dragonHeart), b.heldCount), (Relic.dragonHeart, 0, '★2'));
    // Carried onto a knight on the field: a Pusaka goes on a type, from the Tas page; let go there, it stays in hand.
    final drag = await tester.startGesture(b.toScreen(80, 20));
    await drag.moveBy(const Offset(-30, 0));
    await frames(tester);
    await drag.moveTo(at(b, aldo));
    await frames(tester);
    expect((b.dropFor, b.dropLines.last, b.heldCount), (aldo, pusakaOnType, '★2'));
    await drag.up();
    await frames(tester);
    expect((b.picked, g.pusaka[Relic.dragonHeart]!.type, aldo.relics.length), (Relic.dragonHeart, 'knight', 0));

    // In the Gudang the bag counts it 1: still its stars. An item shows how many the bag holds.
    g.unbindPusaka(Relic.dragonHeart);
    await frames(tester);
    expect((b.picked, g.inBag(Relic.dragonHeart), b.heldCount), (Relic.dragonHeart, 1, '★2'));
    await tapOn(tester, b.bagSlot(Item.sword).center);
    await mouse.moveTo(b.toScreen(80, 20));
    await frames(tester);
    expect((b.picked, b.heldCount), (Item.sword, 'x3'));
    await mouse.removePointer();
    await frames(tester, 10); // the last tap's gesture timers run out
  });

  testWidgets('loot only held is not drawn at the pointer over the open book, where its slot stays lit; on the field it '
      'is, and dragged over the book too; Asah takes its taps as before (ghost-book)', (tester) async {
    final b = await boot(tester);
    // The owner's wave-86 save (a copy): five Pusaka ★1.
    final save = jsonDecode(File('test/fixtures/save-20261001-2005-pre-awaken.json').readAsStringSync()) as Map<String, dynamic>;
    // Its catch-up chests' popup would take the taps.
    final g = b.state = Game.fromJson(save).boardRules()
      ..chests.clear();
    g.dismissPusakaNote();
    await frames(tester, 50);
    if (b.messageBox != Rect.zero) await tapOn(tester, b.messageBox.center); // the save's notes can lie over the tabs
    await openBag(tester, b);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    Future<void> point(Offset p) async {
      await mouse.moveTo(p);
      await frames(tester);
    }

    Future<void> click(Offset p) async {
      await point(p);
      await tester.tapAt(p, kind: PointerDeviceKind.mouse);
      await frames(tester);
    }

    // Dragon Heart picked: over the book nothing at the pointer, its slot lit instead.
    await click(b.bagSlot(Relic.dragonHeart).center);
    expect(b.picked, Relic.dragonHeart);
    expect((b.heldGhost, b.heldCount, b.heldCue), (Rect.zero, null, b.bagSlot(Relic.dragonHeart)));
    // On Asah, none either; its two taps arm it ("Yakin?") and raise it, as with nothing over it.
    final gold = g.gold;
    await point(b.asahButton.center);
    expect((b.heldGhost, b.heldCue), (Rect.zero, b.bagSlot(Relic.dragonHeart)));
    await click(b.asahButton.center);
    expect((b.asahArmed, g.pusaka[Relic.dragonHeart]!.stars, g.gold, b.heldGhost), (Relic.dragonHeart, 1, gold, Rect.zero));
    await click(b.asahButton.center);
    expect((b.asahArmed, g.pusaka[Relic.dragonHeart]!.stars, g.gold), (null, 2, gold - 60000));
    expect(b.picked, Relic.dragonHeart);
    // On the field: at the pointer as ever, with its stars; no cue.
    final field = Offset(b.bookArea.left - 80, b.bookArea.center.dy);
    expect(b.coveredAt(field), isFalse);
    await point(field);
    expect(((b.heldGhost.center - field).distance < 0.01, b.heldCount, b.heldCue), (true, '★2', Rect.zero));
    // On a tab of the book: none again.
    await point(b.bookTabs.firstWhere((t) => t.$1 == 'troops').$2.center);
    expect((b.heldGhost, b.heldCue), (Rect.zero, b.bagSlot(Relic.dragonHeart)));

    // Put back by a tap on its cell: nothing in hand, nothing lit.
    await click(b.bagSlot(Relic.dragonHeart).center);
    expect((b.picked, b.heldCue), (null, Rect.zero));
    await mouse.removePointer();

    // A sword dragged with a finger over the book: at the finger as ever (above it), its count by it.
    g.inventory[Item.sword] = 3;
    await frames(tester);
    if (b.messageBox != Rect.zero) await tapOn(tester, b.messageBox.center); // Asah's message would take the press
    final drag = await tester.startGesture(b.bagSlot(Item.sword).center);
    await drag.moveBy(const Offset(-30, 0));
    await frames(tester);
    final page = b.assignList.center;
    await drag.moveTo(page);
    await frames(tester);
    expect(b.bookArea.contains(page), isTrue);
    expect(((b.heldGhost.center - (page - const Offset(0, 28))).distance < 1, b.heldCount, b.heldCue), (true, 'x3', Rect.zero));
    await drag.up();
    await frames(tester);
    expect((b.picked, g.inventory[Item.sword]), (null, 3)); // let go on the book: put back, as before
    await frames(tester, 10); // the last tap's gesture timers run out
  });

  testWidgets('on a phone (915x412) a finger\'s pick over the book draws nothing at it; the lanes show left of the book, '
      'and a tap on a troop there gives one and shows it above the finger (ghost-book)', (tester) async {
    final b = await boot(tester);
    tester.view.physicalSize = const Size(915, 412);
    final g = b.state = Game()..units.clear();
    final aldo = troopAt(g, 'knight', 40, 50, 'Aldo Ash');
    g.inventory[Item.sword] = 3;
    await frames(tester, 40);
    await openBag(tester, b);
    await tapOn(tester, b.bagSlot(Item.sword).center);
    expect((b.picked, b.heldGhost, b.heldCount, b.heldCue), (Item.sword, Rect.zero, null, b.bagSlot(Item.sword)));
    expect(b.bookArea.contains(at(b, aldo)), isFalse, reason: '${at(b, aldo)} left of ${b.bookArea}');
    await tapOn(tester, at(b, aldo));
    expect((g.countOf('knight', Item.sword), b.picked, b.heldCue), (1, Item.sword, Rect.zero));
    expect(((b.heldGhost.center - (at(b, aldo) - const Offset(0, 28))).distance < 1, b.heldCount), (true, 'x2'));
    await frames(tester, 10); // the last tap's gesture timers run out
  });

  testWidgets('the popup stays on the screen, clear of the HUD and the pointer, at desktop and phone sizes; a pinned plate '
      'hides while loot is held', (tester) async {
    final b = await boot(tester);
    for (final size in const [Size(1266, 713), Size(915, 412)]) {
      tester.view.physicalSize = size;
      final g = b.state = Game()..units.clear();
      // The field's corners and middle, the last lane's (y 120, 125) and one over it (y 108).
      final troops = [
        for (final (x, y) in const [(10.0, 8.0), (40.0, 60.0), (70.0, 120.0), (20.0, 125.0), (70.0, 10.0), (20.0, 108.0)])
          troopAt(g, 'archer', x, y, 'Eka $x $y'),
      ];
      g.inventory[Item.bow] = 3;
      await frames(tester, 40);
      await openBag(tester, b);
      await tapOn(tester, at(b, troops[1]));
      expect((b.pinned, b.pinnedPlate == Rect.zero), (troops[1], false));
      // The troops the HUD leaves in reach: all six at both sizes, the last lane's too (the spawn bar's step stands under
      // the lowest a unit's shadow reaches, decisions-log 287; at 915x412 the bar of 283 covered the two at y 120 and 125).
      final reach = [for (final u in troops) if (!b.coveredAt(at(b, u))) u];
      expect(reach.length, 6, reason: '$size: ${[for (final u in reach) u.name]}');

      // Dragged with a finger over each troop: the popup above it and the finger, or beside it.
      final drag = await tester.startGesture(b.bagSlot(Item.bow).center);
      await drag.moveBy(const Offset(-30, 0));
      await frames(tester);
      expect((b.pinned, b.pinnedPlate), (troops[1], Rect.zero)); // the pin stays, its plate hides
      for (final u in reach) {
        await drag.moveTo(at(b, u));
        await frames(tester);
        expect(b.dropFor, u, reason: '$size ${u.name}');
        expectClear(b, size, at(b, u), '$size ${u.name}, dragged');
        final p = at(b, u), box = b.dropPopup;
        if (box.left <= p.dx && p.dx <= box.right) {
          expect(box.bottom, lessThanOrEqualTo(p.dy - 28), reason: '$size ${u.name}: above the finger');
        }
      }
      await drag.moveTo(at(b, troops[1]));
      await frames(tester);
      await drag.up();
      await frames(tester);
      expect((b.picked, b.pinnedPlate), (Item.bow, Rect.zero)); // in hand: still hidden

      // In hand with the mouse over each troop.
      if (size.width > size.height) {
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: at(b, troops[0]));
        for (final u in reach) {
          await mouse.moveTo(at(b, u));
          await frames(tester);
          expect(b.dropFor, u, reason: 'mouse ${u.name}');
          expectClear(b, size, at(b, u), 'mouse ${u.name}');
        }
        await mouse.removePointer();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape); // put back: the pinned plate is back
      await frames(tester);
      expect((b.picked, b.pinned, b.pinnedPlate == Rect.zero), (null, troops[1], false));
    }
  });

  testWidgets('mid-wave the popup keeps clear of the boss bars, the open minimap and the open battle log', (tester) async {
    final b = await boot(tester);
    for (final size in const [Size(1266, 713), Size(915, 412)]) {
      tester.view.physicalSize = size;
      final g = b.state = Game(Random(5), Random(6))..units.clear();
      final troops = [
        for (final (x, y) in const [(40.0, 8.0), (60.0, 40.0), (80.0, 70.0), (100.0, 100.0), (120.0, 124.0), (120.0, 12.0)])
          troopAt(g, 'knight', x, y, 'Eka $x $y'),
      ];
      g
        ..startWave()
        ..queue.clear()
        ..waveSpawned = 30; // a wave on that is never won: its two monsters stand still
      for (final (type, tier, x, y) in [('werebear', Tier.miniBoss, 170.0, 14.0), (boss, Tier.boss, 210.0, 60.0)]) {
        g.units.add(g.monster(type, tier, Point(x, y))
          ..entered = true
          ..stunUntil = 1e9);
      }
      g.inventory[Item.sword] = 20;
      b.miniMapOpen = true;
      await frames(tester, 40); // the camera settles
      if (b.bookOpened) await tapOn(tester, b.bookButton.center); // still open from the size before: shut first
      if (b.bookButton != Rect.zero) await tapOn(tester, b.bookButton.center); // the book opened mid-wave
      await frames(tester, 20);
      // The log open (at the right; it stays open from size to size).
      if (b.logPanel == Rect.zero) await tapOn(tester, b.logButton.center);
      await openBag(tester, b);
      await tapOn(tester, b.bagSlot(Item.sword).center);
      expect(b.picked, Item.sword, reason: '$size');
      expect((b.bossBars == Rect.zero, b.miniMap == Rect.zero, b.logPanel == Rect.zero), (false, false, false), reason: '$size');

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      var shown = 0;
      for (final u in troops) {
        final p = at(b, u);
        // Under the HUD, or off the screen: no troop there takes it, so no popup.
        if (b.coveredAt(p) || !(Offset.zero & size).contains(p)) continue;
        await mouse.moveTo(p);
        await frames(tester);
        expect(b.dropFor, u, reason: '$size ${u.name}');
        expectClear(b, size, p, '$size ${u.name}, mid-wave');
        shown++;
      }
      await mouse.removePointer();
      expect(shown, greaterThanOrEqualTo(2), reason: '$size');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(tester);
      expect(b.picked, isNull);
      b.miniMapOpen = false;
    }
  });
}
