// The pocket items on screen (decisions-log 332; ui-hud.md "The pocket bar"; lib/pocket_look.dart, bag.dart,
// smithy_page.dart): booted TdGames. The bar, a column of four slots at the field's right edge over the step, in a wave
// and between waves (beside the open book), none in a Town or with nothing in it; what hangs under the wave meter keeps
// left of it (915x412 with the map open); a tap on a slot uses one, or says why (its cooldown only the error), keys 1 to
// 4 likewise; its tooltips and the running boost's chip; the open battle log over it takes its taps; the Bag's Pocket
// chip and its row that puts one in the bar or takes it out; the Smithy's Pocket section that crafts one into the bar.
// The rules: pocket_test.dart. One TdGame per widget test.
//
// Never let a wave be won or the game end here (the Board then saves): a wave begun runs a few frames only.
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';

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
    ..miniMapOpen = false
    ..guideSeen = null
    ..autoStart.set(false);
}

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> tapOn(WidgetTester tester, Rect r) async {
  expect(r, isNot(Rect.zero));
  await tester.tapAt(r.center);
  await frames(tester, 3);
}

/// Shuts the message window, if one is up.
Future<void> shut(WidgetTester tester, Board b) async {
  if (b.messageBox != Rect.zero) await tapOn(tester, b.messageBox);
}

/// [r] wholly inside [area].
bool inside(Rect r, Rect area) => r.left >= area.left - 0.5 && r.top >= area.top - 0.5 && r.right <= area.right + 0.5 && r.bottom <= area.bottom + 0.5;

/// A board game after wave 11 with the Towns on, between waves on the field: a soldier, a knight, an archer and a priest;
/// three Heal Bottles in slot 1 and two Rage Tonics in slot 2.
Game pocketGame() {
  final g = Game(Random(1), Random(2)).boardRules()
    ..townDice = Random(3)
    ..tavernDice = Random(4)
    ..armyMax = null
    ..wave = 11
    ..gold = 5000;
  for (final type in ['soldier', 'knight', 'archer', 'priest']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.pocketStock.addAll({PocketKind.healBottle: 3, PocketKind.rageTonic: 2});
  g.pocketSlots
    ..[0] = PocketKind.healBottle
    ..[1] = PocketKind.rageTonic;
  return g;
}

/// Every living troop at half its HP.
void hurt(Game g) {
  for (final u in g.troops) {
    u.hp = u.maxHp * 0.5;
  }
}

void main() {
  for (final size in const [Size(1600, 947), Size(1266, 713), Size(1164, 777), Size(915, 412)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('the bar at $tag: four slots of 44 px at least in a column at the right edge over the step, beside the '
        'open book between waves, still in a wave; none in a Town or with nothing in it', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = pocketGame();
      await frames(tester, 60);
      final bar = b.pocketBar, slots = b.pocketSlots;
      expect(bar, isNot(Rect.zero), reason: '$tag: between waves (the bottles work then)');
      expect(bar.right, size.width - 10, reason: '$tag: right-aligned with the wave meter');
      expect(bar.right, b.waveMeter.right);
      expect(bar.bottom, lessThan(b.spawnBarPanel.top), reason: '$tag: over the step');
      expect(slots, hasLength(pocketSlotCount));
      for (final (i, r) in slots.indexed) {
        expect((r.width >= 44, r.height >= 44), (true, true), reason: '$tag slot $i: the tap rule');
        expect(inside(r, bar), isTrue, reason: '$tag slot $i in the panel');
        if (i > 0) expect(r.top, greaterThan(slots[i - 1].bottom), reason: '$tag: a column, apart');
        expect(r.left, slots.first.left);
      }
      expect(b.bookArea, isNot(Rect.zero));
      expect(b.bookArea.right, lessThanOrEqualTo(bar.left), reason: '$tag: beside the book, not over it');

      g.startWave();
      await frames(tester, 10);
      expect(b.pocketBar, bar, reason: '$tag: the same place in a wave');

      b.state = pocketGame()
        ..pocketSlots.fillRange(0, pocketSlotCount, null);
      await frames(tester, 10);
      expect(b.pocketBar, Rect.zero, reason: '$tag: nothing in it, the field\'s edge clear');

      final town = b.state = pocketGame()..townAt = 12;
      await frames(tester, 3);
      if (!town.inTown) expect(town.enterTown(), isTrue);
      await frames(tester, 30);
      expect(b.pocketBar, Rect.zero, reason: '$tag: none in a Town');
    });
  }

  testWidgets('at 915x412 with the map open what hangs under the wave meter keeps left of the bar', (tester) async {
    final b = await boot(tester, const Size(915, 412));
    b.miniMapOpen = true;
    final g = b.state = pocketGame()
      ..townAt = 13
      ..boosts.add(RunningBoost(Boost.feast, 2));
    g
      ..omens.addAll([OmenKind.values[0], OmenKind.values[1]])
      ..weakened = 1; // the weakened foes' chip after a wipe (decisions-log 333)
    g.startWave();
    await frames(tester, 10);
    expect(g.usePocket(1), isTrue); // the Rage Tonic: its chip
    await frames(tester, 10);
    final bar = b.pocketBar;
    expect(b.pocketChips, hasLength(1));
    final hung = {'omens': b.omenRow, 'town': b.townChip, 'boosts': b.boostChips.first, 'pocket': b.pocketChips.first, 'weak': b.weakChip};
    for (final MapEntry(key: name, value: r) in hung.entries) {
      expect(r, isNot(Rect.zero), reason: name);
      expect(r.overlaps(bar), isFalse, reason: '$name $r over the bar $bar');
    }
    expect(b.townChip.right, lessThanOrEqualTo(bar.left), reason: 'the Town chip beside the bar: left of it');
  });

  testWidgets('a tap on a slot uses one; refused, why in the message window, but a cooldown only the error', (tester) async {
    final b = await boot(tester);
    final g = b.state = pocketGame();
    g.startWave();
    await frames(tester, 10);
    await shut(tester, b);
    hurt(g);
    await tapOn(tester, b.pocketSlots[0]);
    expect(g.pocketHeld(PocketKind.healBottle), 2, reason: 'one used');
    expect(g.troops.every((u) => u.hp > u.maxHp * 0.8), isTrue, reason: 'every troop healed');
    expect(b.message, isNull);
    await tapOn(tester, b.pocketSlots[0]);
    expect((g.pocketHeld(PocketKind.healBottle), b.message), (2, null), reason: 'cooling: the slot counts it down');
    await tapOn(tester, b.pocketSlots[2]);
    expect(b.message, Words.pocketEmpty, reason: 'an empty slot says how to fill it');
    await shut(tester, b);

    // Between waves a booster is greyed and refused.
    b.state = pocketGame();
    await frames(tester, 60);
    await shut(tester, b);
    await tapOn(tester, b.pocketSlots[1]);
    expect((b.state.pocketHeld(PocketKind.rageTonic), b.message), (2, Words.onlyInWave));
  });

  testWidgets("the bombs on the monsters come in: each its burst (the wizard's ice star's, its fireball's) drawn on them",
      (tester) async {
    final b = await boot(tester);
    final g = b.state = pocketGame();
    g.pocketStock.addAll({PocketKind.frostBomb: 1, PocketKind.fireBomb: 1});
    g.pocketSlots
      ..[2] = PocketKind.frostBomb
      ..[3] = PocketKind.fireBomb;
    g.startWave();
    for (var i = 0; i < 400 && !g.enemies.any((m) => m.alive && m.entered); i++) {
      await frames(tester);
    }
    final foes = [for (final m in g.enemies) if (m.alive && m.entered) m];
    expect(foes, isNotEmpty);
    await shut(tester, b);
    await tapOn(tester, b.pocketSlots[2]);
    await tapOn(tester, b.pocketSlots[3]);
    expect((g.pocketHeld(PocketKind.frostBomb), g.pocketHeld(PocketKind.fireBomb)), (0, 0));
    expect(foes.every((m) => m.effects.containsKey(Status.slow)), isTrue, reason: 'the Frost Bomb on each');
    await frames(tester, 30); // the bursts play through, drawn from their sheets
    expect(tester.takeException(), isNull);
  });

  testWidgets('keys 1 to 4 use the slots, the number row and the keypad', (tester) async {
    final b = await boot(tester);
    final g = b.state = pocketGame();
    g.startWave();
    await frames(tester, 10);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await frames(tester);
    expect((g.pocketHeld(PocketKind.rageTonic), g.pocketBoosts.length), (1, 1));
    hurt(g);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad1);
    await frames(tester);
    expect(g.pocketHeld(PocketKind.healBottle), 2);
  });

  testWidgets("a slot's tooltip and the running boost's chip", (tester) async {
    final b = await boot(tester);
    final g = b.state = pocketGame();
    g.startWave();
    await frames(tester, 10);
    expect(g.usePocket(1), isTrue);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(b.pocketSlots[1].center);
    await frames(tester, 30);
    final (title, lines) = b.tooltipShown!;
    expect(title, 'Rage Tonic');
    expect(lines.first, 'Every troop for 15 s: +25% damage, +15% attack speed.');
    expect(lines, containsAll(['Only in a wave. Cooldown 60 s.', 'In bag: 1/3.', 'Key: 2']));
    expect(lines.where((l) => l.startsWith('Ready in ')), hasLength(1));
    expect(b.pocketChips, hasLength(1));
    await mouse.moveTo(b.pocketChips.first.center);
    await frames(tester, 30);
    expect(b.tooltipShown?.$1, matches(RegExp(r'^Rage Tonic: 1[45] s left$')));
  });

  testWidgets('the open battle log stands over the bar and takes its taps', (tester) async {
    final b = await boot(tester, const Size(915, 412));
    final g = b.state = pocketGame();
    g.startWave();
    await frames(tester, 10);
    await shut(tester, b);
    hurt(g);
    await tapOn(tester, b.logButton);
    expect(b.logPanel.overlaps(b.pocketSlots[0]), isTrue);
    await tapOn(tester, b.pocketSlots[0]);
    expect(g.pocketHeld(PocketKind.healBottle), 3, reason: 'the log took the tap');
    await tapOn(tester, b.logButton);
    await tapOn(tester, b.pocketSlots[0]);
    expect(g.pocketHeld(PocketKind.healBottle), 2);
  });

  testWidgets("the Bag's Pocket chip while one is held, and its row: take it out, put it in, refused with the bar full",
      (tester) async {
    final b = await boot(tester);
    final g = b.state = pocketGame();
    await frames(tester, 60);
    await shut(tester, b);
    await tapOn(tester, [...b.bookTabTaps, ...b.bookTabs].firstWhere((t) => t.$1 == 'bag').$2);
    await tapOn(tester, b.bagChip(BagCategory.pocket));
    expect([for (final (k, _) in b.bagCells) k], [PocketKind.healBottle, PocketKind.rageTonic]);
    await tapOn(tester, b.bagCells.first.$2);
    expect(b.picked, PocketKind.healBottle);
    Rect row() => b.bagActions.singleWhere((a) => a.$1 == BagAction.pocket).$2;
    await tapOn(tester, row());
    expect(g.pocketSlots, [null, PocketKind.rageTonic, null, null], reason: 'taken out; it stays in the Bag');
    expect(g.pocketHeld(PocketKind.healBottle), 3);
    await tapOn(tester, row());
    expect(g.pocketSlots.first, PocketKind.healBottle, reason: 'into the first empty slot');
    g.pocketSlots.setAll(0, [PocketKind.rageTonic, PocketKind.frostBomb, PocketKind.fireBomb, PocketKind.holyWater]);
    await frames(tester, 3);
    expect(b.bagActions.singleWhere((a) => a.$1 == BagAction.pocket).$3, isFalse, reason: 'the bar full: greyed');
    await tapOn(tester, row());
    expect(b.message, Words.pocketFull);
  });

  testWidgets("the Smithy's Pocket section: a pick shows its recipe, Craft makes one into the bar", (tester) async {
    final b = await boot(tester);
    final g = b.state = pocketGame()
      ..townAt = 12;
    g.pocketStock.clear();
    g.pocketSlots.fillRange(0, pocketSlotCount, null);
    g.materials.addAll({Mat.slimeGel: 8, Mat.tealCloth: 4, Mat.batWing: 4});
    await frames(tester, 3);
    if (!g.inTown) expect(g.enterTown(), isTrue);
    await frames(tester, 60);
    await shut(tester, b);
    await tapOn(tester, b.smithyAt('tab:items'));
    while (b.smithyPocketCells.isEmpty && b.smithyItemPage < b.smithyItemPages - 1) {
      await tapOn(tester, b.smithyItemPager('on'));
    }
    expect([for (final (k, _) in b.smithyPocketCells) k], PocketKind.values);
    expect(b.smithyAt('pocket'), isNot(Rect.zero), reason: 'under its heading');
    await tapOn(tester, b.smithyPocketCells.first.$2);
    expect(b.smithyPocket, PocketKind.healBottle);
    expect(b.smithyText('effect'), 'Every troop heals 35% of its HP.');
    expect(b.smithyText('craft'), 'Craft (50 gold)');
    await tapOn(tester, b.smithyAt('craft'));
    expect((g.pocketHeld(PocketKind.healBottle), g.pocketSlots.first), (1, PocketKind.healBottle));
    expect(b.message, 'Heal Bottle ${Words.crafted}!');
  });
}
