// Carve on the Bag's facing page (Ukir's UI, item-artefact-design U3 and U4, decisions-log 196; its row since the action
// list, 202; docs/ui-hud.md "Tas"): a Pusaka's Carve row under its Sharpen row and over the Vault's Melt, at 1266x713,
// and 915x412, inside the page; its bar (the steps as ui_bars.png's pips, the points on this one); the tag's two
// taps ("Carve -20", the next step's line), the toast; each refusal on the tag and its tap; the "★2+3" badge (the Bag
// cell, the heading, the Army detail's capsule, the chest card); Melt's confirm ("the higher Carve is kept"; the Bag
// sells nothing, decisions-log 296); the help tooltip with the role's kinds; an item's Give rows in its "Give to an Artifact"
// chooser (the role's first, that kind alone, fitting); the taps each takes; the new words in the game's font. The
// rules: ukir_test.dart. One TdGame per widget test.
//
// Never let a wave be won or the game end here: the board saves after a pick, into the queue's temp HOME
// (flutter_test_config.dart), never the real save.
import 'dart:math';
import 'dart:ui' show PointerDeviceKind;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'bag_pages.dart';
import 'hud_font.dart';

const desk = Size(1266, 713), wide = Size(915, 412);
const sizes = [desk, wide];

/// Boots one TdGame in a [size] window, past the welcome screen, with the game's font and the minimap folded.
Future<Board> boot(WidgetTester tester, [Size size = desk]) async {
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

/// Taps [r]'s middle (never Rect.zero) and counts it in [taps].
Future<void> tapOn(WidgetTester tester, Rect r, [List<int>? taps]) async {
  expect(r, isNot(Rect.zero));
  await tester.tapAt(r.center);
  await frames(tester);
  taps?[0]++;
}

/// Closes the message window if it shows (a press on it does nothing else).
Future<void> quiet(WidgetTester tester, Board b) async {
  if (b.messageBox != Rect.zero) await tapOn(tester, b.messageBox);
}

/// Turns the open book to its [tab] page ('bag', 'troops').
Future<void> openTab(WidgetTester tester, Board b, String tab) async {
  await quiet(tester, b);
  await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == tab).$2);
}

/// Picks [kind] in the Bag's grid (its cell, the grid turned to its page: [bagTo]), unless it is the pick already;
/// counted in [taps] (the page turns not).
Future<void> pick(WidgetTester tester, Board b, Enum kind, [List<int>? taps]) async {
  await quiet(tester, b);
  if (b.picked != kind) {
    await bagTo(tester, b, kind);
    await tapOn(tester, b.bagSlot(kind), taps);
  }
  expect(b.picked, kind);
}

/// [who]'s row on the facing page's list, the list wheeled down until it shows whole (the rows are in their order;
/// from the top when it isn't in view).
Future<Rect> rowOf(WidgetTester tester, Board b, Object who) async {
  final mouse = TestPointer(9, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(mouse.hover(b.assignList.center));
  final h = b.assignRows.map((r) => r.$2.height).reduce(max);
  bool whole() => b.assignRows.any((r) => r.$1 == who && r.$2.height >= h - 0.5);
  if (!b.assignRows.any((r) => r.$1 == who)) {
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100000)));
    await frames(tester);
  }
  for (var i = 0; i < 80 && !whole(); i++) {
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 20)));
    await frames(tester);
  }
  await tester.sendEventToBinding(mouse.hover(b.bookArea.topLeft)); // off the rows: a touch tap under a tooltip is no tap
  await frames(tester);
  return b.assignRows.firstWhere((r) => r.$1 == who).$2;
}

/// The facing page's action list wheeled down until its part [key] shows whole (the short window's page is shorter than
/// its rows; a wheel is no tap).
Future<void> wheelTo(WidgetTester tester, Board b, String key) => wheelUntil(tester, b, () => b.bagDetail(key));

/// The facing page's list wheeled from its top until what [at] gives shows whole in it (at 915x412 the shorter landscape
/// book's list holds about two rows, decisions-log 283).
Future<void> wheelUntil(WidgetTester tester, Board b, Rect Function() at) async {
  final mouse = TestPointer(9, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(mouse.hover(b.assignList.center));
  await tester.sendEventToBinding(mouse.scroll(const Offset(0, -2000)));
  await frames(tester);
  for (var i = 0; i < 60 && !inside(at(), b.assignList); i++) {
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 10)));
    await frames(tester);
  }
  await tester.sendEventToBinding(mouse.hover(b.bookArea.topLeft)); // off the rows: a touch tap under a tooltip is no tap
  await frames(tester);
}

/// A board game between waves at [wave] (Carve opens at 40), no army cap, gold to spare, a soldier and a knight beside
/// the free priest at their posts; a long run's bag; Dragon Heart ★2+3 on the knight, the Grail +2 (40 points on its
/// bar) and Dawn Star in the Vault, God's Thunder on the soldier, Oath of One.
Game carved({int wave = 45}) {
  final g = Game(Random(1)).boardRules()
    ..towns = false // the Towns off (tests only, decisions-log 296: the rules from before them; the book is the Towns' still)
    ..armyMax = null
    ..gold = 5000000
    ..wave = wave;
  for (final type in ['soldier', 'knight']) {
    expect(g.autoPlace(type), isTrue);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.inventory.addAll({Item.sword: 86, Item.shield: 14, Item.boots: 9, Item.bow: 30, Item.gloves: 12, Item.potion: 120, Item.staff: 40});
  g.relicBag.addAll({Relic.fury: 5, Relic.thorns: 12});
  g
    ..givePusaka(Relic.dragonHeart, type: 'knight', stars: 2, ukir: 3)
    ..givePusaka(Relic.grail, ukir: 2)
    ..givePusaka(Relic.dawnStar)
    ..givePusaka(Relic.godThunder, type: 'soldier')
    ..givePusaka(Relic.oathOfOne);
  g.pusaka[Relic.grail]!.feed = 40;
  return g;
}

/// [inner] inside [outer], to half a pixel.
bool inside(Rect inner, Rect outer) => outer.inflate(0.5).contains(inner.topLeft) && outer.inflate(0.5).contains(inner.bottomRight);

/// Whether [shown] is one of [words] or the last cut to fit ("..").
bool oneOf(String? shown, List<String> words) =>
    shown != null && (words.contains(shown) || (shown.endsWith('..') && words.last.startsWith(shown.substring(0, shown.length - 2))));

/// The items in [take], all kinds.
int count(Map<Item, int> take) => take.values.fold(0, (n, v) => n + v);

void main() {
  for (final size in sizes) {
    final at = '${size.width.round()}x${size.height.round()}';
    testWidgets('at $at Carve\'s row under Sharpen\'s and over the Vault\'s Melt; its bar, the badge in the heading; two '
        'taps carve ("Carve -N", the next step\'s line), the toast', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = carved();
      await frames(tester, 50);
      await openTab(tester, b, 'bag');
      final taps = [0];
      await pick(tester, b, Relic.grail, taps);
      // Each row whole in the list at some wheel, and where it lies down the list (its rect at no wheel).
      final down = <String, Rect>{};
      for (final key in ['sharpen', 'carve', 'melt']) {
        Rect at() => key == 'melt' ? b.bagAction(BagAction.melt) : b.bagDetail(key);
        await wheelUntil(tester, b, at);
        final list = b.assignList, r = at();
        expect(inside(r, list), isTrue, reason: '$at: $key $r in $list');
        down[key] = r.translate(0, b.assignScroll);
      }
      final (sharpen, carve, melt) = (down['sharpen']!, down['carve']!, down['melt']!);
      expect((carve.top >= sharpen.bottom, carve.width, melt.top >= carve.bottom), (true, sharpen.width, true),
          reason: '$at: its own row, under Sharpen\'s, over the Vault\'s Melt');
      // Sharpen's cost whole on its row's second line: the coin, the price, each small relic it takes as its icon and how
      // many (or "+ 10 relics" where they don't fit).
      await wheelTo(tester, b, 'sharpen');
      final cost = b.bagDetail('sharpenCost'), costWords = b.bagDetailText('sharpenCost')!, asah = b.asahButton;
      expect((inside(cost, b.bagDetail('sharpen')), cost.translate(0, b.assignScroll).overlaps(carve), cost.overlaps(asah), costWords.endsWith('..')),
          (true, false, false, false),
          reason: '$at: "$costWords" at $cost, Sharpen $asah, Carve $carve');
      await wheelTo(tester, b, 'carve');
      final btn = b.bagDetail('carveBtn'), bar = b.bagDetail('carveBar'), row = b.bagDetail('carve');
      expect((inside(btn, row), inside(bar, row), bar.right <= btn.left, bar.top >= btn.top), (true, true, true, true),
          reason: '$at: bar $bar, tag $btn in $row');
      expect(costWords.startsWith(shortPrice(g.asahPriceOf(Relic.grail)!)), isTrue, reason: '$at: "$costWords" at $cost');
      expect((b.bagDetailText('carve'), b.bagDetailText('carveBar'), b.bagDetailText('count')), (Words.carve, '40/135', '★1+2'),
          reason: at);

      // The first tap arms: "Carve -N" (the items one tap takes) in red, and what the next step gives.
      final take = g.ukirTake(Relic.grail), points = take.points, budget = g.ukirBudget;
      expect((points, budget), (60, ukirPerBoss), reason: at);
      await tapOn(tester, btn, taps);
      expect((b.carveArmed, b.bagDetailText('carve'), g.pusaka[Relic.grail]!.feed), (Relic.grail, '${Words.carve} -${count(take.items)}', 40),
          reason: at);
      final next = g.carveNext(Relic.grail)!;
      expect(next.now, isNot(next.after), reason: 'the Grail ★1 +2 → +3');
      expect(b.bagDetailText('next'), startsWith('Next: ${next.now} ▸ ${next.after}'), reason: at);
      // The second feeds it: the bar fills, the budget falls, the toast says what went in.
      final before = [for (final i in Item.values) g.inventory[i] ?? 0];
      await tapOn(tester, b.bagDetail('carveBtn'), taps);
      final p = g.pusaka[Relic.grail]!;
      expect((b.carveArmed, p.ukir, p.feed, g.ukirBudget), (null, 2, 100, budget - points), reason: at);
      expect([for (final (n, i) in Item.values.indexed) before[n] - (g.inventory[i] ?? 0)], [for (final i in Item.values) take.items[i] ?? 0],
          reason: '$at: what it said it would take');
      expect(b.message, startsWith('${relicNames[Relic.grail]}: 100/135 ('), reason: at);
      expect(taps.first, 3, reason: '$at: cell, Carve, Carve -N');
      await quiet(tester, b);
      expect((b.bagDetailText('carveBar'), b.bagDetailText('carve')), ('100/135', Words.carve), reason: at);

      // A step: "Grail of Immortality ★1+3: a bit stronger!", its badge "+3".
      await tapOn(tester, b.bagDetail('carveBtn'));
      await tapOn(tester, b.bagDetail('carveBtn'));
      expect((p.ukir, p.feed), (3, 0), reason: at);
      expect(b.message, '${relicNames[Relic.grail]} ★1+3: a bit stronger!', reason: at);
      await quiet(tester, b);
      expect(b.bagDetailText('count'), '★1+3', reason: at);
      await frames(tester, 10);
    });
  }

  for (final size in const [desk, wide]) {
    final at = '${size.width.round()}x${size.height.round()}';
    testWidgets('at $at each refusal on the button: greyed, why on the bar, a tap says why and arms nothing; another pick '
        'lets an armed Carve go', (tester) async {
      final b = await boot(tester, size);
      var g = b.state = carved(wave: 30);
      await frames(tester, 50);
      await openTab(tester, b, 'bag');

      Future<void> refused(Relic relic, String why, String label) async {
        await frames(tester); // what the test changed drawn
        await pick(tester, b, relic);
        await wheelTo(tester, b, 'carve'); // at 915x412 the list holds about two rows
        final p = g.pusaka[relic]!, was = (p.ukir, p.feed, g.ukir.pts);
        expect(g.whyNotUkir(relic), why, reason: '$at $label');
        expect(oneOf(b.bagDetailText('carveBar'), b.carveWhyWords(why)), isTrue, reason: '$at $label: ${b.bagDetailText('carveBar')}');
        await tapOn(tester, b.bagDetail('carveBtn'));
        expect((b.carveArmed, b.message, (p.ukir, p.feed, g.ukir.pts)), (null, why, was), reason: '$at $label');
        await quiet(tester, b);
      }

      await refused(Relic.grail, ukirRefusals.from, 'before wave 40');
      g = b.state = carved();
      await frames(tester, 10);
      await refused(Relic.oathOfOne, ukirRefusals.oath, 'an oath');
      g.pusaka[Relic.dragonHeart]!.ukir = ukirCost.length;
      await refused(Relic.dragonHeart, ukirRefusals.full, 'full');
      g.ukir
        ..iv = g.wave ~/ bossEvery
        ..pts = ukirPerBoss;
      await refused(Relic.grail, '${ukirRefusals.budget} ${g.ukirAgainAt}', 'the budget');
      g.ukir.pts = 0;
      for (final i in Item.values) {
        g.inventory[i] = 0;
      }
      await refused(Relic.grail, ukirRefusals.items, 'no items');
      g.inventory[Item.potion] = 50;

      // Armed, then another pick: it lets go.
      await pick(tester, b, Relic.grail);
      await tapOn(tester, b.bagDetail('carveBtn'));
      expect(b.carveArmed, Relic.grail, reason: at);
      await pick(tester, b, Relic.dawnStar);
      expect(b.carveArmed, isNull, reason: at);

      // Mid-wave.
      g.startWave();
      await frames(tester, 40); // the book shuts for the wave
      for (var i = 0; i < 3 && b.bookTabs.isEmpty; i++) {
        await quiet(tester, b);
        await tapOn(tester, b.bookButton);
        await frames(tester, 40);
      }
      if (!b.bagOpen) await openTab(tester, b, 'bag');
      await refused(Relic.grail, ukirRefusals.midWave, 'mid-wave');
      b.state = Game(); // leave no wave to win
      await frames(tester, 10);
    });
  }

  for (final size in sizes) {
    final at = '${size.width.round()}x${size.height.round()}';
    testWidgets('at $at the badge "★2+3" (the "+3" in Carve\'s gold): the Bag cell, the heading, the Army detail; the '
        'confirm: an armed Melt "the higher Carve is kept"', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = carved();
      await frames(tester, 50);
      await openTab(tester, b, 'bag');
      bool badge(String words, Rect where) => b.carveBadges.any((c) => c.$2 == words && inside(c.$1, where));
      // Each on its page of the grid ([bagTo]: at 915x412 a page holds 12 on the shorter landscape book, decisions-log 283).
      for (final (r, ukir, words) in [(Relic.dragonHeart, 3, '★2+3'), (Relic.grail, 2, '★1+2'), (Relic.dawnStar, 0, null)]) {
        await bagTo(tester, b, r);
        expect(b.bagMarks(r)!.ukir, ukir, reason: '$at $r');
        if (words == null) {
          expect(b.carveBadges.where((c) => c.$2.startsWith('★1+') && inside(c.$1, b.bagSlot(r))), isEmpty, reason: at);
          continue;
        }
        expect(badge(words, b.bagSlot(r)), isTrue, reason: '$at $r: ${b.carveBadges}');
        // At the cell's bottom right, where a Pusaka has no count: the top right is the head of the pack's diagonal weapons.
        final slot = b.bagSlot(r), box = b.carveBadges.firstWhere((c) => inside(c.$1, slot)).$1;
        expect((box.top >= slot.center.dy, box.right >= slot.right - slot.width / 4), (true, true), reason: '$at: $r\'s badge $box in $slot');
      }
      await pick(tester, b, Relic.dragonHeart);
      expect((b.bagDetailText('count'), badge('★2+3', b.bagDetail('count'))), ('★2+3', true), reason: at);

      // Melt the Grail (+2) into Dawn Star (+0): the armed row says the higher is kept.
      await pick(tester, b, Relic.grail);
      await wheelUntil(tester, b, () => b.leburButton);
      await tapOn(tester, b.leburButton);
      await tapOn(tester, await rowOf(tester, b, Relic.dawnStar));
      expect(b.leburArmed, Relic.dawnStar, reason: at);
      expect(oneOf(b.bagDetailText('meltArmed'), ['Tap again: the higher ${Words.carve} is kept', 'The higher ${Words.carve} is kept',
          'Higher ${Words.carve} kept']), isTrue, reason: '$at: ${b.bagDetailText('meltArmed')}');
      await tapOn(tester, await rowOf(tester, b, Relic.dawnStar));
      expect((g.pusaka.containsKey(Relic.grail), g.pusaka[Relic.dawnStar]!.stars, g.pusaka[Relic.dawnStar]!.ukir), (false, 2, 2), reason: at);
      await quiet(tester, b);

      // The Army page: the knight's detail shows Dragon Heart's capsule with its "+3".
      await openTab(tester, b, 'troops');
      await tapOn(tester, b.troopRow('knight'));
      // The detail's body scrolls where it is taller than its room (decisions-log 218): down until the Artifact's line shows.
      bool shown() => b.carveBadges.any((c) => c.$2 == '★2+3' && inside(c.$1, b.troopDetail('pusaka')));
      for (var s = 6.0; !shown() && s <= b.troopDetailContent; s += 6) {
        b.troopDetailScroll = s;
        await frames(tester, 1);
      }
      expect(shown(), isTrue, reason: '$at: ${b.carveBadges} in ${b.troopDetail('pusaka')}');
      await frames(tester, 10);
    });
  }

  testWidgets('the chest card of an owned carved Pusaka shows its Carve "+2" after the stars, and its effect with it',
      (tester) async {
    final b = await boot(tester);
    final g = b.state = carved()..chests.add(Chest(ChestKind.boss, 50, cards: [Relic.grail, Relic.bloodFang, Relic.mourningBell]));
    await frames(tester, 3);
    await tester.tapAt(const Offset(2, 2)); // the notes go, the popup stays
    await frames(tester, 30);
    expect(b.chestOpen, isTrue);
    final card = b.chestCards.first;
    expect(b.carveBadges.any((c) => c.$2 == '+2' && inside(c.$1, card)), isTrue, reason: '${b.carveBadges} in $card');
    expect(b.carveBadges.where((c) => !c.$2.startsWith('★') && inside(c.$1, b.chestCards[1])), isEmpty); // the Army rows' under it
    expect(g.relicEffect(Relic.grail, stars: g.cardStars(Relic.grail), ukir: 2), isNot(g.relicEffect(Relic.grail, stars: g.cardStars(Relic.grail))));
    b.state = Game();
    await frames(tester, 10);
  });

  testWidgets('the help tooltip over the bar: what Carve is, the role\'s kinds that count 2, the shared budget, its steps',
      (tester) async {
    final b = await boot(tester);
    final g = b.state = carved();
    await frames(tester, 50);
    await openTab(tester, b, 'bag');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    for (final (relic, kinds) in [(Relic.grail, 'Potion and staff'), (Relic.dragonHeart, 'Shield and boots'), (Relic.godThunder, 'Sword, bow and gloves')]) {
      await pick(tester, b, relic);
      await mouse.moveTo(b.bagDetail('carveBar').center);
      await frames(tester, 30);
      expect(b.tooltipShown?.$1, Words.carve, reason: '$relic');
      expect(b.tooltipShown!.$2, g.carveInfo(relic).$2, reason: '$relic');
      expect(b.tooltipShown!.$2, containsAll(['Give spare items to this ${Words.artifact}.', '$kinds count $ukirMatch.',
          'Other items count $ukirAny.', 'Full bar: a bit stronger.', '$ukirPerBoss points each boss, for all ${Words.artifact}s.']),
          reason: '$relic');
      expect(inside(b.tooltipBox, Offset.zero & desk), isTrue, reason: '$relic: ${b.tooltipBox}');
      await mouse.moveTo(Offset.zero);
      await frames(tester);
    }
    expect(g.carveInfo(Relic.dragonHeart).$2.last, ukirGist(3));
    expect(g.relicInfo(Relic.dragonHeart).$2, contains('${Words.carve} 3 of 5: not a star, a bit stronger.'));
    expect(g.relicInfo(Relic.dawnStar).$2.where((l) => l.startsWith(Words.carve)), isEmpty);
    await mouse.removePointer();
    await frames(tester, 10);
  });

  for (final size in sizes) {
    final at = '${size.width.round()}x${size.height.round()}';
    testWidgets('at $at an item\'s Give rows in its "Give to an Artifact" chooser: every Pusaka that takes Carve (not the '
        'oath), its role\'s first; a row\'s tap gives that kind alone to that one (3 taps), inside the list', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = carved();
      await frames(tester, 50);
      await openTab(tester, b, 'bag');
      final taps = [0];
      await pick(tester, b, Item.potion, taps);
      expect(b.bagDetailText('hint:giveArtifact'), '${Words.carve}: 4 can take it', reason: at);
      await tapOn(tester, b.bagAction(BagAction.giveArtifact), taps);
      expect((b.bagChooser, b.bagDetailText('chooser')), (BagAction.giveArtifact, '${Words.give} to an ${Words.artifact}'), reason: at);
      // The order: the life ones (the Grail) first, then the others in the Bag's order.
      final bag = [for (final k in bagKinds(g, BagCategory.artifacts)) if (!(k as Relic).oath) k];
      bool life(Relic r) => pusakaCatalog[r]!.role == UkirRole.life;
      final order = [...bag.where(life), ...bag.where((r) => !life(r))];
      expect(order.first, Relic.grail, reason: at);
      final mouse = TestPointer(9, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(b.assignList.center));
      final seen = <Relic>[];
      for (var i = 0; i < 80; i++) {
        for (final (who, r, _) in b.assignRows) {
          if (who is Relic && !seen.contains(who)) seen.add(who);
          expect(inside(r, b.assignList), isTrue, reason: '$at: $who $r in ${b.assignList}');
        }
        await tester.sendEventToBinding(mouse.scroll(const Offset(0, 20)));
        await frames(tester);
      }
      await tester.sendEventToBinding(mouse.hover(b.bookArea.topLeft));
      await frames(tester);
      expect(seen, order, reason: at);
      expect(b.assignRows.every((r) => r.$1 is Relic), isTrue, reason: '$at: the Give rows alone');

      // A tap on the Grail's row: potions alone (2 points each), at once.
      final take = g.ukirTake(Relic.grail, only: Item.potion), before = [for (final i in Item.values) g.inventory[i] ?? 0];
      expect((take.items.keys.join(), take.points), ('${Item.potion}', 60), reason: at);
      await tapOn(tester, await rowOf(tester, b, Relic.grail), taps);
      expect([for (final (n, i) in Item.values.indexed) before[n] - (g.inventory[i] ?? 0)], [for (final i in Item.values) take.items[i] ?? 0],
          reason: '$at: potions only');
      expect((g.pusaka[Relic.grail]!.feed, taps.first), (100, 3), reason: '$at: cell, Give to an Artifact, row');
      expect(b.message, startsWith('${relicNames[Relic.grail]}: 100/135 (${itemNames[Item.potion]} 30)'), reason: at);
      await quiet(tester, b);
      // God's Thunder (attack) takes potions at 1 point each; Dragon Heart's step: a refused row says why, its tap too.
      g
        ..ukir.iv = g.wave ~/ bossEvery
        ..ukir.pts = ukirPerBoss;
      final row = await rowOf(tester, b, Relic.godThunder);
      expect(b.assignRows.firstWhere((r) => r.$1 == Relic.godThunder).$3, isFalse, reason: '$at: the budget spent');
      await tapOn(tester, row);
      expect(b.message, '${ukirRefusals.budget} ${g.ukirAgainAt}', reason: at);
      await quiet(tester, b);

      // A sword: the attack ones first.
      g.ukir.pts = 0;
      await pick(tester, b, Item.sword);
      expect(b.bagChooser, isNull, reason: '$at: another pick, its action list');
      await tapOn(tester, b.bagAction(BagAction.giveArtifact));
      final attack = [for (final r in bag) if (pusakaCatalog[r]!.role == UkirRole.attack) r];
      await rowOf(tester, b, attack.first);
      final rowsNow = [for (final (who, _, _) in b.assignRows) if (who is Relic) who];
      expect(rowsNow.first, attack.first, reason: '$at: $rowsNow');
      await frames(tester, 10);
    });
  }

  test('Carve\'s new words are in the game\'s font (a star is drawn as an icon)', () {
    final chars = fontChars();
    for (final line in [
      Words.carve, Words.give, 'Carve -30', 'Next: 40% ▸ 42% HP, no damage for 3s', 'Next: a bit stronger', '40/135', 'x2', 'x1',
      'Uses 30: 40/135 ▸ 100/135', '+2 ▸ +3', 'Give to an Artifact', 'Carve +3 is lost', '+3 is lost',
      'Tap again: the higher Carve is kept', 'The higher Carve is kept', 'Higher Carve kept', '★2+3', 'Grail of Immortality ★2+3: a bit stronger!',
      'Grail of Immortality: 100/135 (Potion 12, Staff 8)', 'Between waves', 'Later', 'From wave 40', 'w40', 'Not for an Oath', 'No',
      'Full', 'No items', 'More at wave 50', 'Wave 50', 'w50', ukirRefusals.midWave, ukirRefusals.from, ukirRefusals.oath,
      ukirRefusals.bound, ukirRefusals.full, ukirRefusals.budget, ukirRefusals.items, ...Game().carveInfo(Relic.godThunder).$2,
      ukirGist(5),
    ]) {
      final missing = line.replaceAll('★', '').replaceAll('▸', '').runes.where((c) => !chars.contains(c)).map(String.fromCharCode).toList();
      expect(missing, isEmpty, reason: line);
    }
  });
}
