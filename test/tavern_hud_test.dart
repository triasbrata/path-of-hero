// The Tavern in battle (decisions-log 268; ui-hud.md "The Tavern in battle"; lib/tavern_look.dart): booted TdGames with
// the Towns on at 1266x713, 1164x777 and 915x412. The boosts running as chips under the wave meter (under the
// Town chip when one is marked, else under the meter; right-aligned with it, apart, on the screen), their tooltips
// ("Feast: 2 waves left", an effect a line, who), the battle log's panel kept clear of them, none without a boost, six
// in rows the meter's width; and the field back from a Town: each troop a boost bought there touches bursts once with the upgrade
// burst, none without a buy. One TdGame per widget test.
//
// Never let a wave be won or the game end here (the Board then saves).
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
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
    ..autoStart.set(false);
}

Future<void> frames(WidgetTester tester, [int n = 2]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// [r] wholly inside [area].
bool inside(Rect r, Rect area) => r.left >= area.left - 0.5 && r.top >= area.top - 0.5 && r.right <= area.right + 0.5 && r.bottom <= area.bottom + 0.5;

const sizes = [Size(1266, 713), Size(1164, 777), Size(915, 412)];

/// A board game after wave 20 with the Towns on (the Tavern too, as shipped), between waves on the field: a soldier, a
/// knight, an archer and a priest; with [marked] a Town after wave 22.
Game fieldGame({bool marked = true}) {
  final g = Game(Random(1), Random(2)).boardRules()
    ..townDice = Random(3)
    ..tavernDice = Random(4)
    ..armyMax = null
    ..wave = 20;
  for (final type in ['soldier', 'knight', 'archer', 'priest']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g
    ..gold = 40000
    ..townAt = marked ? 23 : null;
  return g;
}

void main() {
  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets("the boosts' chips at $tag: under the Town chip, right-aligned, their tooltips; the log keeps clear",
        (tester) async {
      final b = await boot(tester, size);
      b.state = fieldGame()
        ..boosts.addAll([RunningBoost(Boost.feast, 2), RunningBoost(Boost.plate, 1, type: 'knight')]);
      await frames(tester, 30);
      final screen = Offset.zero & size, meter = b.waveMeter, town = b.townChip, chips = b.boostChips;
      expect(town, isNot(Rect.zero), reason: 'a Town marked');
      expect(chips, hasLength(2));
      for (final (i, r) in chips.indexed) {
        expect(inside(r, screen), isTrue, reason: '$tag chip $i: $r');
        expect(r.top, greaterThanOrEqualTo(town.bottom), reason: '$tag chip $i under the Town chip');
        expect(r.left, greaterThanOrEqualTo(meter.left - 0.5), reason: '$tag chip $i under the meter');
      }
      expect(chips.last.right, closeTo(meter.right, 1), reason: '$tag: right-aligned with the meter');
      expect(chips.first.overlaps(chips.last), isFalse);
      expect(chips.first.right, lessThanOrEqualTo(chips.last.left), reason: 'in the order bought, left to right');

      // The tooltips under the mouse.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(chips.first.center);
      await frames(tester, 30);
      expect(b.tooltipShown?.$1, 'Feast: 2 waves left');
      expect(b.tooltipShown?.$2, ['+20% damage', '15% less damage taken', 'All troops']);
      await mouse.moveTo(chips.last.center);
      await frames(tester, 30);
      expect(b.tooltipShown?.$1, "Champion's Plate: 1 wave left");
      expect(b.tooltipShown?.$2, ['+40% damage', '+15% attack speed', 'Knights']);
      await mouse.moveTo(Offset.zero);
      await frames(tester, 3);

      // The battle log's panel opens under them.
      await tester.tapAt(b.logButton.center);
      await frames(tester, 3);
      expect(b.logPanel, isNot(Rect.zero));
      expect(b.logPanel.top, greaterThanOrEqualTo(chips.map((r) => r.bottom).reduce(max)), reason: '$tag: the log under the chips');
    });

    testWidgets("the boosts' chips at $tag: one until the next Town shows the Town's hammer, as wide as the others; its "
        'tip names the Town once marked (decisions-log 331)', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = fieldGame()
        ..boosts.addAll([RunningBoost(Boost.feast, 2), RunningBoost(Boost.watch, 0, untilTown: true)]);
      await frames(tester, 30);
      final chips = b.boostChips, screen = Offset.zero & size;
      expect(chips, hasLength(2));
      expect(chips.first.size, chips.last.size);
      expect(inside(chips.first, screen) && inside(chips.last, screen) && !chips.first.overlaps(chips.last), isTrue, reason: tag);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(chips.last.center);
      await frames(tester, 30);
      expect(b.tooltipShown?.$1, "Watchman's Brew: until next Town");
      expect(b.tooltipShown?.$2, ['${Words.townAfter} 22', 'a leak a wave costs no life']);
      g.townAt = null;
      await mouse.moveTo(Offset.zero);
      await frames(tester, 3);
      await mouse.moveTo(b.boostChips.last.center);
      await frames(tester, 30);
      expect(b.tooltipShown?.$2, ['a leak a wave costs no life'], reason: 'no Town marked yet');
    });

    testWidgets("the boosts' chips at $tag: under the meter without a Town marked; none without a boost; six in rows",
        (tester) async {
      final b = await boot(tester, size);
      final g = b.state = fieldGame(marked: false)..boosts.add(RunningBoost(Boost.watch, 2));
      await frames(tester, 30);
      expect(b.townChip, Rect.zero);
      expect(b.boostChips, hasLength(1));
      expect(b.boostChips.single.top, greaterThanOrEqualTo(b.waveMeter.bottom));
      expect(b.boostChips.single.right, closeTo(b.waveMeter.right, 1));
      g.boosts.clear();
      await frames(tester, 3);
      expect(b.boostChips, isEmpty);
      g.boosts.addAll([for (final k in [Boost.feast, Boost.ale, Boost.stew, Boost.broth, Boost.tea, Boost.rations]) RunningBoost(k, 2)]);
      await frames(tester, 3);
      // Six: in rows the meter's width, each row right-aligned with it, all on the screen and apart.
      final chips = b.boostChips, screen = Offset.zero & size;
      expect(chips, hasLength(6));
      for (final (i, r) in chips.indexed) {
        expect(inside(r, screen) && r.left >= b.waveMeter.left - 0.5, isTrue, reason: '$tag chip $i: $r');
        for (final o in chips.skip(i + 1)) {
          expect(r.overlaps(o), isFalse, reason: '$tag chip $i: $r and $o');
        }
      }
      expect(chips.last.right, closeTo(b.waveMeter.right, 1));
    });
  }

  testWidgets('the field back from a Town: the troops a boost bought there touches burst once; none without a buy',
      (tester) async {
    final b = await boot(tester);
    Future<List<(Offset, String)>> back(Game g) async {
      expect(g.leaveTown(), isTrue);
      for (var i = 0; i < 120 && b.townShown; i++) {
        await frames(tester);
      }
      expect(b.townShown, isFalse);
      return [for (final x in b.fieldBursts) if (x.$2 == 'upgrade') x];
    }

    // No buy: no burst.
    var g = b.state = fieldGame()..townAt = 21;
    expect(g.enterTown(), isTrue);
    await frames(tester, 60);
    expect(await back(g), isEmpty);

    // The Feast bought: every living troop bursts, where it stands.
    g = b.state = fieldGame()..townAt = 21;
    expect(g.enterTown(), isTrue);
    await frames(tester, 60);
    final feast = g.tavernOffers.indexWhere((o) => o.kind == Boost.feast);
    expect(g.buyBoost(feast), isTrue);
    final bursts = await back(g);
    expect(bursts, hasLength(g.troops.where((u) => u.alive).length));
    expect({for (final (at, _) in bursts) at}, {for (final u in g.troops) Offset(u.pos.x, u.pos.y)});
  });
}
