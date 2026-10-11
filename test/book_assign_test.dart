import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hero_skill_helpers.dart';

// The Tas page's list (#87) as the player gets it: a picked relic's "Equip on a troop" lists the living troops, a picked
// item's "Give to troops" the troop types (decisions-log 202: its action row opens the chooser), each row greyed with why
// when it can't take it; a row gives one, and the pick and its chooser stay while the bag holds more; a drag or the
// wheel scrolls it; the troop filter stays until the player changes it. One TdGame (its own
// file: a second TdGame in one file breaks the shared image cache, docs/testing.md). What each row says comes from
// Game.assignPreview: assign_test.dart.

/// Advances the game [n] frames.
Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('the Tas page lists who takes the picked relic or item, gives from its rows, scrolls, and keeps its filter',
      (tester) async {
    tester.view
      ..physicalSize = const Size(1266, 713)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = TdGame();
    await tester.pumpWidget(GameWidget(game: game));
    for (var i = 0; i < 3000 && !game.isLoaded; i++) {
      // onLoad decodes images in real time: let it run, then pump.
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(game.isLoaded, isTrue);
    final b = game.board..welcome = null;
    final g = b.state = bareGame(Random(1));
    final s1 = placeNow(g, 'soldier', 1, 1), s2 = placeNow(g, 'soldier', 1, 2), a1 = placeNow(g, 'archer', 0, 1), w = placeNow(g, 'wizard', 0, 3);
    a1.relics.add(Relic.guard);
    g.relicBag[Relic.fang] = 2;
    await frames(tester, 40); // the book floats in between waves
    await tester.tapAt(b.bookTabs[1].$2.center); // Tas
    await frames(tester);
    // Nothing picked: the facing page is blank (decisions-log 241): no row, no slot.
    expect((b.picked, b.assignRows.length), (null, 0));
    expect(b.assignSlots, isEmpty);

    Future<void> tap(Rect r) async {
      await tester.tapAt(r.center);
      await frames(tester);
    }

    Rect rowOf(Object who) => b.assignRows.firstWhere((r) => r.$1 == who).$2;
    bool okOf(Object who) => b.assignRows.firstWhere((r) => r.$1 == who).$3;

    // A relic: its actions first; "Equip on a troop" lists one row per living troop, in the book's order; the archer
    // holding one is greyed.
    await tap(b.bagSlot(Relic.fang));
    expect(b.picked, Relic.fang);
    expect(b.bagChooser, isNull);
    await tap(b.bagAction(BagAction.equip));
    expect(b.bagChooser, BagAction.equip);
    expect(b.assignRows.map((r) => r.$1), [s1, s2, a1, w]);
    expect(b.assignRows.map((r) => r.$3), [true, true, false, true]);
    expect(b.assignRows.every((r) => b.assignList.contains(r.$2.topLeft) && b.bookArea.contains(r.$2.center)), isTrue);

    // A tap on the greyed row says why and gives nothing.
    await tap(rowOf(a1));
    expect((b.message, a1.relics.firstOrNull, g.relicBag[Relic.fang]), (holdsRelic(Relic.guard), Relic.guard, 2));
    await frames(tester, 130); // the message window has gone
    expect(b.message, isNull);

    // A row gives one; the pick stays while the bag holds more, the row greys, and the next row takes the last.
    await tap(rowOf(s1));
    expect((s1.relics.firstOrNull, g.relicBag[Relic.fang], b.picked, okOf(s1)), (Relic.fang, 1, Relic.fang, false));
    await tap(rowOf(w));
    expect((w.relics.firstOrNull, g.relicBag[Relic.fang]), (Relic.fang, 0));
    await frames(tester);
    expect((b.picked, b.assignRows.length), (null, 0)); // none left: the pick goes, the page is blank
    expect(b.assignSlots, isEmpty);

    // An item: "Give to troops" lists one row per troop type; the staff only fits the casters' recipes, so theirs come
    // first and the types it is never for after them, greyed.
    g.inventory[Item.staff] = 2;
    await frames(tester); // its cell comes in: a kind the bag lacks has none (decisions-log 187)
    await tap(b.bagSlot(Item.staff));
    expect(b.picked, Item.staff);
    await tap(b.bagAction(BagAction.giveTroops));
    final types = [
      for (final never in [false, true])
        for (final t in troopTypes.keys)
          if ((g.whyNot(Item.staff, t) == Refusal.notInRecipe) == never) t,
    ];
    expect(types.first, isNot('soldier'));
    expect(b.assignRows.map((r) => r.$1), types.take(b.assignRows.length)); // the casters first, as many as show
    expect(b.assignRows.length, lessThan(types.length)); // the rest are further down

    // A drag on the list scrolls it and gives nothing.
    final first = types.first, before = rowOf(first).top;
    await tester.dragFrom(rowOf(types[1]).center, const Offset(0, -150));
    await frames(tester);
    expect(b.assignRows.any((r) => r.$1 == first && r.$2.top == before), isFalse);
    expect(g.upgrades[types[1]], isNull);
    // The wheel scrolls it too, down to the end, and back up to the wizard's row.
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(b.assignList.center));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 1000)));
    await frames(tester);
    expect((b.assignRows.last.$1, okOf(types.last)), (types.last, false));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -1000)));
    await frames(tester);
    expect(okOf('wizard'), isTrue);
    await tap(rowOf('wizard'));
    expect((g.countOf('wizard', Item.staff), g.inventory[Item.staff], b.picked), (1, 1, Item.staff));

    // The filter: a chip per type shows only it, several at once; it stays through another pick, a turned page
    // and the book shutting and opening again, until the player changes it.
    expect(b.assignFilter, isEmpty);
    await tap(b.assignChip('wizard'));
    expect(b.assignFilter, {'wizard'});
    expect(b.assignRows.map((r) => r.$1), ['wizard']);
    await tap(b.assignChip('soldier'));
    expect(b.assignRows.map((r) => r.$1), ['wizard', 'soldier']); // the soldier never takes a staff: after it
    g.relicBag[Relic.thorns] = 1;
    await frames(tester);
    await tap(b.bagSlot(Relic.thorns));
    expect(b.picked, Relic.thorns);
    await tap(b.bagAction(BagAction.equip));
    expect(b.assignRows.map((r) => r.$1), [s1, s2, w]);
    await tap(b.bookTabs[0].$2); // Pasukan
    await tap(b.bookTabs[1].$2); // Tas again: the pick went back, the filter didn't
    expect(b.picked, isNull);
    expect(b.assignFilter, {'soldier', 'wizard'});
    g.startWave(); // the book shuts for the wave
    await frames(tester, 40);
    expect(b.bookArea, Rect.zero);
    await tap(b.bookButton); // and opens on Pasukan
    await frames(tester, 40);
    await tap(b.bookTabs[1].$2);
    await tap(b.bagSlot(Relic.thorns));
    await tap(b.bagAction(BagAction.equip));
    expect(b.assignFilter, {'soldier', 'wizard'});
    expect(b.assignRows.map((r) => r.$1), [s1, s2, w]);
    await tap(b.assignChip('soldier')); // again: out of the filter
    expect(b.assignFilter, {'wizard'});
    await tap(b.assignChip(null)); // All: every type again
    expect(b.assignFilter, isEmpty);
    expect(b.assignRows.map((r) => r.$1), [s1, s2, a1, w]);

    // The phone (915x412): the chips in two rows, the list on the right page.
    tester.view.physicalSize = const Size(915, 412);
    await frames(tester, 40);
    expect(b.picked, Relic.thorns); // still picked
    expect(b.assignChip('lancer').top, greaterThan(b.assignChip(null).bottom));
    expect(b.assignRows.map((r) => r.$1).take(2), [s1, s2]);
    expect(b.assignRows.every((r) => b.bookArea.contains(r.$2.center) && r.$2.center.dx > b.bookArea.center.dx), isTrue);
    await tap(rowOf(s2));
    expect((s2.relics.firstOrNull, g.relicBag[Relic.thorns]), (Relic.thorns, 0));
    await frames(tester, 10); // the tap's gesture timers run out
  });
}
