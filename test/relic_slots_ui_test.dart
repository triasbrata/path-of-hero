import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';

// #91 relics taken off and a Hero's two slots, as the player gets them (lib/bag.dart, lib/plates.dart,
// lib/drop_popup.dart; ui-hud.md): the Tas page's rows show each troop's slots, a Hero two; with nothing picked
// the page lists the troops holding relics; a held relic's slot offers Lepas, which takes it off between waves
// and is greyed with why during one; the pinned plate on the field has a Lepas for each relic; the drop popup
// over a Hero shows its slots. One TdGame per widget test. The rules: relic_slots_test.dart.
//
// Never let a wave be won or the game end here (the Board then saves): the troops stand still, and a wave begun
// runs a few frames only.

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

/// A troop of [type] called [name] standing still at ([x], [y]) on [g]'s field; a Hero when [hero].
Unit troopAt(Game g, String type, double x, double y, String name, {bool hero = false}) {
  final u = Unit(Side.troop, type, g.statsOf(type), Point(x, y))
    ..name = name
    ..hero = hero
    ..entered = true
    ..arriving = false
    ..stunUntil = 1e9;
  g.units.add(u);
  return u;
}

Future<void> tapOn(WidgetTester tester, Offset p) async {
  await tester.tapAt(p);
  await frames(tester);
}

/// Turns the open book to its Tas page.
Future<void> openBag(WidgetTester tester, Board b) async {
  await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
  expect(b.bagOpen, isTrue);
}

void main() {
  testWidgets('the Tas page: a Hero\'s two slots, nothing picked blank, and Remove between waves only', (tester) async {
    final b = await boot(tester);
    final g = b.state = Game()..units.clear();
    final aldo = troopAt(g, 'knight', 40, 50, 'Aldo Ash', hero: true)..relics.add(Relic.fang);
    final bima = troopAt(g, 'knight', 40, 90, 'Bima Sakti')..relics.add(Relic.guard);
    await frames(tester, 40); // the book floats in between waves
    await openBag(tester, b);
    List<(Unit, Relic?)> slots() => [for (final (u, r, _) in b.assignSlots) (u, r)];
    Rect slotOf(Unit u, Relic? r) => b.assignSlots.firstWhere((s) => s.$1 == u && s.$2 == r).$3;

    // Nothing picked: the facing page is blank (decisions-log 241): no row, no slot, no button.
    expect(b.picked, isNull);
    expect(slots(), isEmpty);
    expect((b.takeOffArmed, b.takeOffButton), (null, Rect.zero));

    // Remove from a troop (the bag holds a fang too): the wearer's row shows the Hero's two slots, one empty. A tap on
    // a held relic's slot picks it out: its row offers Remove; again lets it go.
    g.relicBag[Relic.fang] = 1;
    await frames(tester);
    await tapOn(tester, b.bagSlot(Relic.fang).center);
    await tapOn(tester, b.bagAction(BagAction.takeOff).center);
    expect(slots(), [(aldo, Relic.fang), (aldo, null)]);
    await tapOn(tester, slotOf(aldo, Relic.fang).center);
    expect(b.takeOffArmed, (aldo, Relic.fang));
    await tapOn(tester, slotOf(aldo, Relic.fang).center);
    expect(b.takeOffArmed, isNull);
    // Remove (the Remove chooser's row always has it) takes it off into the bag; the troop leaves the list, and the
    // chooser goes with the last one worn.
    await tapOn(tester, b.takeOffButton.center);
    expect(aldo.relics, isEmpty);
    expect((g.relicBag[Relic.fang], b.takeOffArmed, b.bagChooser), (2, null, null));
    g.relicBag[Relic.fang] = 1; // one to give again below
    await frames(tester);

    // Picked, a relic lists every troop: the Hero takes it and has a slot left for another kind; the other
    // troop holds one, and its slot still offers Lepas.
    g.relicBag[Relic.thorns] = 1;
    await frames(tester); // its cell comes in: a kind the bag lacks has none (decisions-log 187)
    await tapOn(tester, b.bagSlot(Relic.thorns).center);
    await tapOn(tester, b.bagAction(BagAction.equip).center); // its "Equip on a troop" (decisions-log 202)
    expect([for (final (who, _, ok) in b.assignRows) (who, ok)], [(aldo, true), (bima, false)]);
    await tapOn(tester, b.assignRows.first.$2.center);
    expect(aldo.relics, [Relic.thorns]);
    await tapOn(tester, b.bagSlot(Relic.fang).center);
    await tapOn(tester, b.bagAction(BagAction.equip).center);
    expect([for (final (who, _, ok) in b.assignRows) (who, ok)], [(aldo, true), (bima, false)]);
    expect(slots(), [(aldo, Relic.thorns), (aldo, null), (bima, Relic.guard)]);

    // Held over the Hero on the field, the popup counts its slots and names the one it holds.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: b.toScreen(80, 20));
    await mouse.moveTo(b.toScreen(aldo.pos.x, aldo.pos.y - 3));
    await frames(tester);
    expect(b.dropFor, aldo);
    expect(b.dropLines, ['Hero Aldo Ash', troopTypeNames['knight'], 'Relic slots 1/2 > 2/2', relicNames[Relic.thorns], 'Heals 30% of damage dealt']);
    await mouse.moveTo(b.toScreen(bima.pos.x, bima.pos.y - 3));
    await frames(tester);
    expect(b.dropLines, ['Bima Sakti', troopTypeNames['knight'], holdsRelic(Relic.guard)]); // one slot: unchanged
    // Off the troops before it goes: the mouse's last place stays, and a plate shown there would make the next
    // touch tap a long press (the tooltip's rule).
    await mouse.moveTo(b.toScreen(80, 20));
    await frames(tester);
    await mouse.removePointer();
    await tapOn(tester, b.assignRows.first.$2.center); // the list's Hero row gives it
    expect(aldo.relics, [Relic.thorns, Relic.fang]);
    expect(b.picked, isNull); // the bag ran out of fangs

    // During a wave Remove is greyed with why, and a tap on it says so and takes nothing off.
    g.relicBag[Relic.fang] = 1;
    g.startWave(); // the book shuts for the wave
    await frames(tester, 40);
    await tapOn(tester, b.bookButton.center); // and opens on Pasukan
    await frames(tester, 40);
    await openBag(tester, b);
    await tapOn(tester, b.bagSlot(Relic.fang).center);
    expect(b.picked, Relic.fang);
    await tapOn(tester, b.bagAction(BagAction.takeOff).center); // its row is greyed: the tap says why
    expect((b.bagChooser, b.message, g.relicBag[Relic.fang]), (null, takeOffRefusals.midWave, 1));
    expect(aldo.relics, [Relic.thorns, Relic.fang]);
    await frames(tester, 10); // the last tap's gesture timers run out
  });

  testWidgets('the pinned plate has a Lepas for each relic its troop holds: one comes off and the pin stays; mid-wave '
      'they are greyed and say why', (tester) async {
    final b = await boot(tester);
    final g = b.state = Game()..units.clear();
    final aldo = troopAt(g, 'knight', 40, 60, 'Aldo Ash', hero: true)..relics.addAll([Relic.guard, Relic.fang]);
    final bima = troopAt(g, 'archer', 40, 100, 'Bima Sakti');
    await frames(tester, 30);
    await tapOn(tester, b.toScreen(aldo.pos.x, aldo.pos.y - 7));
    expect(b.pinned, aldo);
    expect(b.plateTakeOff, hasLength(2));
    expect(b.plateTakeOff.every((r) => b.pinnedPlate.intersect(r) == r), isTrue); // on the plate

    await tapOn(tester, b.plateTakeOff.first.center);
    expect(aldo.relics, [Relic.fang]);
    expect((g.relicBag[Relic.guard], b.pinned, b.plateTakeOff.length), (1, aldo, 1));

    // A troop holding none has none.
    await tapOn(tester, b.toScreen(bima.pos.x, bima.pos.y - 7));
    expect((b.pinned, b.plateTakeOff.length), (bima, 0));

    // Mid-wave: greyed, and a tap says why.
    await tapOn(tester, b.toScreen(aldo.pos.x, aldo.pos.y - 7));
    g.startWave();
    await frames(tester, 10);
    expect((b.pinned, b.plateTakeOff.length), (aldo, 1));
    await tapOn(tester, b.plateTakeOff.single.center);
    expect((b.message, aldo.relics.single, g.relicBag[Relic.fang] ?? 0, b.pinned), (takeOffRefusals.midWave, Relic.fang, 0, aldo));
    await frames(tester, 10);
  });
}
