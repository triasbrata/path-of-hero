// The spawn bar (decisions-log 283, 287; docs/ui-hud.md "Spawn bar"): a slot per troop type on a hotbar (the owner,
// 2026-10-09: "untuk sloot army-nya coba di pakaikan seperti ini ... di taruh di tengah saja"), in troopTypes order,
// buying one with a tap as the Army detail's Buy did (gold, count, autoPlace, mid-wave too); too poor or refused; its
// place and size at the test windows (centred on the screen on a raised step, "+Room" left of it and "Auto Buy" right of
// it on the step, "Di atas panggung"; the open book two slots over the hotbar's bottom); all nine at once at the test
// windows, in a landscape window too narrow for them (568x320) paged by whole slots between two arrow buttons beside the
// hotbar, never over a slot (the arrows, the wheel, a swipe), while the hotbar and its buttons stay put; the words' sizes; their taps and
// tooltips; the field under the bar taking no press; none in a Town or on the welcome screen; and the guide's P1 at its
// first slot that buys (or the arrow toward it). Nothing of the battle behind the bar: bar_clear_test.dart. Auto Buy's
// own rules (the fallen bought back): auto_replace_test.dart. One TdGame per widget test.
//
// Never let a wave be won or the game end here (the Board then saves): a wave begun runs a few frames only.
import 'dart:math' as math;
import 'dart:math' show max, min;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/guide_rules.dart' show guideIntro;
import 'package:tower_defense/main.dart';
import 'package:tower_defense/save.dart' show Welcome;

import 'troops_detail_test.dart' show boot, desk, fourTypes, frames, inside, rich, tablet, tapOn, wide;

const owner = Size(1600, 947); // the owner's window

/// A landscape window too narrow for all nine slots with +Room and Auto Buy beside them (an iPhone SE's, 568x320): the
/// hotbar pages.
const small = Size(568, 320);

/// The hotbar's frame round its slots and the gap between them: 5 sprite px at [hotbarPx].
const gap = 5 * hotbarPx;

/// Every card the bar has at [b]'s size, its pages turned from the first to the last: their types in the order they
/// came, each card's rect where it was first drawn (whole: the strip pages by whole cards). Leaves the strip on its
/// first page.
Future<List<(String, Rect)>> allCards(WidgetTester tester, Board b) async {
  final out = <String, Rect>{};
  b.spawnBarFirst = 0;
  await frames(tester);
  for (var i = 0; i < 20; i++) {
    for (final (r, t) in b.spawnBarCards) {
      out.putIfAbsent(t, () => r);
    }
    if (b.spawnBarFirst + b.spawnBarPerPage >= troopTypes.length) break;
    b.spawnBarFirst += b.spawnBarPerPage;
    await frames(tester);
  }
  b.spawnBarFirst = 0;
  await frames(tester);
  return [for (final MapEntry(:key, :value) in out.entries) (key, value)];
}

/// Turns the strip's pages from the first until troop [type]'s card shows; returns it.
Future<Rect> into(WidgetTester tester, Board b, String type) async {
  b.spawnBarFirst = 0;
  await frames(tester);
  for (var i = 0; i < 20; i++) {
    final r = b.spawnCard(type);
    if (r != Rect.zero) return r;
    b.spawnBarFirst += math.max(1, b.spawnBarPerPage);
    await frames(tester);
  }
  fail('$type never shows');
}

/// No arrow button over a card: each card clear of both (decisions-log 283; the owner, 2026-10-09: "emang itu bisa di
/// click kalau kamu buat seperti itu?").
void clearOfArrows(Board b, String tag) {
  final (back, on) = b.spawnBarArrows;
  for (final (r, t) in b.spawnBarCards) {
    expect(r.overlaps(back) || r.overlaps(on), isFalse, reason: '$tag $t: $r clear of the arrows $back $on');
  }
}

/// The hotbar's panel and its two buttons' press areas (+Room's, Auto Buy's), to see them stay put.
List<Rect> block(Board b) => [b.spawnBarPanel, b.capacityButton, b.autoReplaceButton];

void main() {
  testWidgets('a slot per type in troopTypes order on the hotbar, square, one size, one row, a gap apart; the hotbar centred '
      'on the screen on the step, its bottom on the log button\'s line; +Room left of it and Auto Buy right of it, level '
      'with the slots, as far off it each side; the step under them all, symmetric, down to the screen\'s bottom, its '
      'slopes whole; slots 44 px at least (56 in the owner\'s 1600x947), all nine in view; the open book two slots\' '
      'height over the hotbar\'s bottom at the most, over the step; none in a Town or on the welcome screen', (tester) async {
    final b = await boot(tester);
    for (final size in [owner, desk, tablet, wide]) {
      for (final wave in [false, true]) {
        tester.view.physicalSize = size;
        final g = b.state = rich();
        if (wave) g.startWave();
        await frames(tester, 40);
        final tag = '$size ${wave ? 'wave' : 'between'}';
        final cards = await allCards(tester, b);
        expect([for (final (t, _) in cards) t], troopTypes.keys, reason: '$tag: every type, in order');
        expect([for (final (_, t) in b.spawnBarCards) t], troopTypes.keys, reason: '$tag: all nine at once');
        expect(b.spawnBarArrows, (Rect.zero, Rect.zero), reason: '$tag: all nine fit, no arrows');
        final first = cards.first.$2, last = cards.last.$2;
        expect(first.width, first.height, reason: '$tag: square');
        for (final (i, (t, r)) in cards.indexed) {
          expect((r.size, r.top), (first.size, first.top), reason: '$tag $t: one size, one row');
          if (i > 0) expect(r.left - cards[i - 1].$2.right, gap, reason: '$tag $t: a gap apart');
        }
        final (panel, room, auto, area) = (b.spawnBarPanel, b.capacityButton, b.autoReplaceButton, b.spawnBarArea);
        expect((panel.left + panel.right) / 2, closeTo(size.width / 2, 0.5), reason: '$tag: $panel centred');
        expect((first.left - panel.left, panel.right - last.right, first.top - panel.top, panel.bottom - first.bottom), (gap, gap, gap, gap),
            reason: '$tag: the hotbar\'s frame round the slots');
        expect(panel.bottom, b.logButton.deflate(2 * b.hudScale).bottom, reason: '$tag: on the log button\'s line');
        expect((room.right <= panel.left, auto.left >= panel.right), (true, true), reason: '$tag: +Room left, Auto Buy right');
        expect(panel.left - room.right, closeTo(auto.left - panel.right, 0.5), reason: '$tag: as far off it each side');
        for (final r in [room, auto]) {
          expect(r.center.dy, closeTo(first.center.dy, 0.5), reason: '$tag: $r level with the slots');
          expect(r.height, greaterThanOrEqualTo(math.max(44.0, first.height)), reason: '$tag: $r, a slot\'s height and more');
        }
        for (final r in [panel, room, auto]) {
          expect(inside(r, area), isTrue, reason: '$tag: $r on the step $area');
        }
        expect(area.top, lessThan(panel.top), reason: '$tag: the step\'s top over the hotbar');
        expect((area.bottom, area.left > 0, area.right < size.width), (size.height, true, true), reason: '$tag: $area');
        expect((area.left + area.right) / 2, closeTo(size.width / 2, 1), reason: '$tag: $area symmetric');
        expect(first.height, size == owner ? 56 : greaterThanOrEqualTo(44), reason: '$tag: the owner\'s 56, 44 at least');
        // Their words at the HUD's small floor at least: at 1600x947 the price 13 px, the count 12.
        final (price, count) = (barPriceSize(first.height), barCountSize(first.height));
        expect(price >= 11 && count >= 11, isTrue, reason: '$tag: $price $count');
        if (size == owner) expect((price, count), (13, 12), reason: tag);
        // The open book over it: its bottom, as low as it bobs, two slots' height over the hotbar's bottom at the most
        // (283's rule), over the step's top.
        if (!wave) {
          expect(b.bookArea, isNot(Rect.zero), reason: '$tag: the book open');
          expect(b.bookArea.bottom, lessThanOrEqualTo(panel.bottom - 2 * first.height + 0.5), reason: '$tag: ${b.bookArea} over $panel');
          expect(b.bookArea.bottom, lessThan(area.top), reason: '$tag: ${b.bookArea} over the step $area');
        }
        b.state = Game(); // leave no wave to win
        await frames(tester, 3);
      }
    }
    // A Town: no bar (its book keeps its pages).
    tester.view.physicalSize = desk;
    final t = b.state = Game()
      ..towns = true
      ..townAt = 1;
    expect(t.enterTown(), isTrue);
    await frames(tester, 40);
    expect(b.spawnBarCards, isEmpty, reason: 'not in a Town');
    expect(b.spawnBarArea, Rect.zero, reason: 'not in a Town');
    // The welcome screen: none either.
    b
      ..state = rich()
      ..welcome = Welcome(null, discard: () {});
    await frames(tester, 3);
    expect(b.spawnBarCards, isEmpty, reason: 'not on the welcome screen');
  });

  testWidgets('a tap on a card buys one of its type as the Army detail\'s Buy did: the gold, the count, the troop sent to its '
      'cell; the Army page\'s pick unchanged; mid-wave too, unpaused, at the desk, 915x412 and 568x320 (paged)', (tester) async {
    final b = await boot(tester);
    for (final size in [desk, wide, small]) {
      tester.view.physicalSize = size;
      final g = b.state = fourTypes();
      await frames(tester, 40);
      final pick = b.troopPicked, gold = g.gold, army = g.armySize, price = g.priceOf('knight'), n = g.troopCounts['knight']!;
      final knight = await into(tester, b, 'knight');
      expect(b.spawnCardLook('knight'), 'buy', reason: '$size');
      await tapOn(tester, knight);
      expect((g.gold, g.armySize, g.troopCounts['knight'], b.troopPicked, b.message), (gold - price, army + 1, n + 1, pick, null),
          reason: '$size: one bought, the pick kept, nothing said');
      expect(g.troops.last.type, 'knight', reason: '$size: on the field');
      // Mid-wave (the book shut in landscape): it still buys, and nothing pauses.
      g.startWave();
      await frames(tester, 40);
      final card = await into(tester, b, 'archer'), now = g.armySize, before = g.gold;
      await tapOn(tester, card);
      expect((g.armySize, g.gold, g.paused, g.waveActive), (now + 1, before - g.priceOf('archer'), false, true), reason: '$size: mid-wave');
      b.state = Game(); // leave no wave to win
      await frames(tester, 30);
    }
  });

  testWidgets('too poor: the coin faded and the price grey, a tap buys and says nothing; refused (the type at its cap, the '
      'army full): the forbidden sign, a tap says why', (tester) async {
    final b = await boot(tester);
    for (final size in [desk, wide, small]) {
      tester.view.physicalSize = size;
      final g = b.state = fourTypes()..capacity = 12;
      while (!g.typeFull(Game.freeHealer) && g.autoPlace(Game.freeHealer)) {}
      g.gold = 0;
      await frames(tester, 40);
      final army = g.armySize;
      await tapOn(tester, await into(tester, b, 'soldier'));
      expect(b.spawnCardLook('soldier'), 'poor', reason: '$size');
      expect((g.armySize, g.gold, b.message), (army, 0, null), reason: '$size: too poor: nothing, and nothing said');
      g.gold = 50000;
      await frames(tester);
      expect(b.spawnCardLook('soldier'), 'buy', reason: '$size');
      final priest = await into(tester, b, Game.freeHealer);
      expect(b.spawnCardLook(Game.freeHealer), 'refused', reason: '$size');
      await tapOn(tester, priest);
      expect((g.armySize, b.message), (army, 'Priests full 5/5'), reason: '$size: at its cap: why');
      await frames(tester, 140); // the message goes
      // The army without room: every card refused, a tap says why.
      g.capacity = g.armySize;
      await frames(tester);
      final why = g.buyRefusal('archer');
      expect(why, isNotNull);
      final archer = await into(tester, b, 'archer');
      expect(b.spawnCardLook('archer'), 'refused', reason: '$size');
      await tapOn(tester, archer);
      expect((g.armySize, b.message), (army, why), reason: '$size');
      await frames(tester, 140);
    }
  });

  testWidgets('where the slots don\'t all fit (568x320) they page by whole slots between two arrow buttons beside the '
      'hotbar (level with the slots, 44 px wide at least, a gap off it, over no slot), greyed at the ends; the arrows, the '
      'wheel and a swipe turn the page and buy nothing; the hotbar and its buttons stay put; every slot shown buys', (tester) async {
    final b = await boot(tester, small);
    final g = b.state = rich()..capacity = 40;
    await frames(tester, 40);
    final still = block(b), list = b.spawnBarList, per = b.spawnBarPerPage, n = troopTypes.length, types = troopTypes.keys.toList();
    final (back, on) = b.spawnBarArrows;
    final panel = b.spawnBarPanel, row = b.spawnBarCards.first.$1;
    expect((back == Rect.zero, on == Rect.zero, per < n), (false, false, true), reason: 'slots hide: the arrows show');
    expect(per, greaterThanOrEqualTo(2), reason: 'two a page at least');
    for (final r in [back, on]) {
      expect((r.width >= barArrowMin, r.top, r.bottom), (true, row.top, row.bottom), reason: '$r: 44 px wide at least, level with the slots');
    }
    expect((back.right, on.left), (panel.left - gap, panel.right + gap), reason: 'a gap off the hotbar each side');
    expect((back.left, on.right), (list.left, list.right), reason: 'at the strip\'s ends');
    expect((panel.left + panel.right) / 2, closeTo(small.width / 2, 0.5), reason: 'the hotbar centred');
    expect((b.capacityButton.right <= back.left, b.autoReplaceButton.left >= on.right), (true, true), reason: '+Room and Auto Buy outside the arrows');
    var army = g.armySize;
    void stays(String how) {
      expect(block(b), still, reason: '$how: the hotbar and its buttons stay put');
      expect(b.spawnBarList, list, reason: how);
      expect(b.spawnBarArrows, (back, on), reason: '$how: the arrows stay put');
      expect(g.armySize, army, reason: '$how: no buy');
    }

    // A page: per cards, whole, one size, in order, between the arrows and clear of them.
    void page(int from, String how) {
      expect(b.spawnBarFirst, from, reason: how);
      expect([for (final (_, t) in b.spawnBarCards) t], types.sublist(from, from + per), reason: how);
      for (final (r, t) in b.spawnBarCards) {
        expect((r.size, inside(r, panel)), (b.spawnBarCards.first.$1.size, true), reason: '$how $t: $r whole, on the hotbar');
      }
      clearOfArrows(b, how);
    }

    page(0, 'the first page');
    expect(b.spawnCard(types.last), Rect.zero, reason: 'the last type on another page');
    // The arrows: on a page, on to the last (the last cards), greyed there; back. A tap on one never buys.
    final last = n - per;
    var at = 0;
    while (at < last) {
      await tapOn(tester, on);
      at = min(at + per, last);
      page(at, 'the arrow on');
      stays('the arrow on');
      await frames(tester, 20);
    }
    await tapOn(tester, on); // greyed: nothing more that way
    page(last, 'the arrow on, greyed at the end');
    stays('the greyed arrow');
    await tapOn(tester, back);
    page(max(0, last - per), 'the arrow back');
    stays('the arrow back');
    b.spawnBarFirst = 0;
    await frames(tester, 20);
    await tapOn(tester, back); // greyed: nothing more that way
    page(0, 'the arrow back, greyed at the start');
    stays('the greyed arrow back');

    // A swipe along the strip: left a page on, right a page back, one a swipe. Before the mouse comes: a drag carries
    // the mouse's spot with it (main.dart onDragUpdate), and a tooltip where it ends would make the next tap no tap.
    await tester.dragFrom(b.spawnBarCards[1].$1.center, const Offset(-90, 0));
    await frames(tester);
    page(min(per, last), 'a swipe left');
    stays('the swipe');
    await tester.dragFrom(b.spawnBarCards[1].$1.center, const Offset(90, 0));
    await frames(tester);
    page(0, 'a swipe right');
    stays('the swipe back');

    // The wheel over the strip: a page a notch (one more within the Bag's gap does nothing); not over +Room.
    final mouse = TestPointer(9, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(b.spawnBarCards.first.$1.center));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 40)));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 40)));
    await frames(tester);
    page(min(per, last), 'the wheel on');
    stays('the wheel');
    await frames(tester, 30); // past the gap
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -40)));
    await frames(tester);
    page(0, 'the wheel back');
    await frames(tester, 30);
    await tester.sendEventToBinding(mouse.hover(b.capacityButton.center));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 40)));
    await frames(tester);
    page(0, 'not over the strip');
    await tester.sendEventToBinding(mouse.hover(const Offset(2, 2)));
    await tester.sendEventToBinding(mouse.removePointer()); // gone: no tooltip comes up where it rested (a tap under one is no tap)
    await frames(tester, 30);

    // Every card shown buys, on every page.
    for (var from = 0;; from = min(from + per, last)) {
      b.spawnBarFirst = from;
      await frames(tester, 3);
      for (final (_, t) in b.spawnBarCards) {
        if (b.spawnCardLook(t) != 'buy') continue;
        final was = g.troopCounts[t] ?? 0;
        await tapOn(tester, b.spawnCard(t));
        army++;
        expect((g.armySize, g.troopCounts[t]), (army, was + 1), reason: '$t: a tap buys');
        await frames(tester, 30);
      }
      if (from == last) break;
    }
    expect(g.troopCounts.keys.toSet(), types.where((t) => g.buyRefusal(t) == null || g.troopCounts.containsKey(t)).toSet(),
        reason: 'every type that could be bought was');
    await frames(tester, 30);
  });

  testWidgets('+Room\'s words on one line inside its button ("+Room  40", "Room: max" at the most); +Room and Auto Buy 44 px '
      'each way at least, at the test windows and 568x320', (tester) async {
    final b = await boot(tester);
    for (final size in [owner, desk, tablet, wide, small]) {
      for (final most in [false, true]) {
        tester.view.physicalSize = size;
        final g = b.state = rich()..capacity = 20;
        if (most) g.capacity = g.maxCapacity;
        await frames(tester, 40);
        final tag = '$size${most ? ' at the most' : ''}', price = shortPrice(g.capacityCost);
        final face = b.spawnBarRoomFace, words = b.spawnBarRoomWords;
        expect([for (final (t, _) in words) t], most ? ['Room: max'] : ['${Words.room}  $price'], reason: tag);
        for (final (t, r) in words) {
          expect(inside(r, face.deflate(2)), isTrue, reason: '$tag "$t" $r inside its button $face');
        }
        for (final r in [face, b.capacityButton, b.autoReplaceButton]) {
          expect(r.width >= 44 && r.height >= 44, isTrue, reason: '$tag: $r 44 px each way at least');
        }
        b.state = Game();
        await frames(tester, 3);
      }
    }
  });

  testWidgets('+Room is on the bar\'s step, not the Army header: a tap buys the room (2 more, its price), greyed it says '
      'why; Auto Buy turns the fallen\'s buying back on and off, mid-wave too; their tooltips', (tester) async {
    final b = await boot(tester);
    for (final size in [owner, desk, wide]) {
      tester.view.physicalSize = size;
      final g = b.state = rich();
      await frames(tester, 40);
      final (room, auto) = (b.capacityButton, b.autoReplaceButton);
      expect(inside(room, b.spawnBarArea), isTrue, reason: '$size: +Room on the step');
      expect(room.overlaps(b.bookArea), isFalse, reason: '$size: not in the book');
      final (cap, gold, cost) = (g.capacity, g.gold, g.capacityCost);
      await tapOn(tester, room);
      expect((g.capacity, g.gold, b.message), (cap + capacityStep, gold - cost, null), reason: '$size: +Room bought');
      await frames(tester, 30);
      g.gold = 0;
      await frames(tester);
      await tapOn(tester, room);
      expect((g.capacity, b.message), (cap + capacityStep, '${Words.notEnoughGold} (need ${g.capacityCost}).'),
          reason: '$size: greyed, says why');
      await frames(tester, 140);
      // Auto Buy: off at first; a tap on, a tap off; mid-wave too.
      expect(g.autoReplace, isFalse, reason: '$size: off by default');
      await tapOn(tester, auto);
      expect(g.autoReplace, isTrue, reason: '$size: on');
      await frames(tester, 30);
      await tapOn(tester, auto);
      expect(g.autoReplace, isFalse, reason: '$size: off');
      await frames(tester, 30);
      g.startWave();
      await frames(tester, 3);
      await tapOn(tester, b.autoReplaceButton);
      expect((g.autoReplace, g.waveActive, g.paused), (true, true, false), reason: '$size: mid-wave');
      b.state = Game(); // leave no wave to win
      await frames(tester, 30);
    }
    // The tooltips.
    tester.view.physicalSize = desk;
    final g = b.state = rich();
    await frames(tester, 40);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(b.autoReplaceButton.center);
    await frames(tester, 30);
    expect(b.tooltipShown?.$1, 'Auto Buy');
    expect(b.tooltipShown?.$2, ['Auto Buy: replace fallen troops.', 'Off.']);
    g.setAutoReplace(true);
    await frames(tester, 3);
    expect(b.tooltipShown?.$2, ['Auto Buy: replace fallen troops.', 'On: each one comes back as gold allows.']);
    await mouse.moveTo(b.capacityButton.center);
    await frames(tester, 30);
    expect(b.tooltipShown?.$1, Words.room);
    expect(b.tooltipShown?.$2, g.roomTip.$2);
    await mouse.moveTo(const Offset(2, 2));
    await frames(tester, 10);
    await mouse.removePointer();
  });

  testWidgets('+Room greyed says why on a tap, for each reason (decisions-log 292): too poor "Not enough gold (need 60).", '
      'the next buy\'s price; at the most "Army room is at its most (36)."; nothing moves. Its tooltip, under the mouse or '
      'a long press, says what it does ("+Room: more army room (40 gold).") and why not; not greyed, a tap still buys',
      (tester) async {
    final b = await boot(tester);
    for (final size in [owner, wide]) {
      tester.view.physicalSize = size;
      final g = b.state = rich();
      await frames(tester, 40);
      final room = b.capacityButton;
      List<String> words() => [for (final (t, _) in b.spawnBarRoomWords) t];
      Future<List<String>?> hover() async {
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(room.center);
        await frames(tester, 30);
        final tip = b.tooltipShown;
        await mouse.moveTo(const Offset(2, 2));
        await frames(tester, 10);
        await mouse.removePointer();
        expect(tip?.$1, Words.room, reason: '$size: its title');
        return tip?.$2;
      }

      // It buys: no message; a second tap buys again, 10 dearer.
      for (var i = 0; i < 2; i++) {
        final (cap, gold, cost) = (g.capacity, g.gold, g.capacityCost);
        expect(g.canBuyCapacity, isTrue, reason: '$size $i');
        expect(words(), ['${Words.room}  ${shortPrice(cost)}'], reason: '$size $i');
        expect((await hover())?.first, '${Words.room}: ${Words.moreRoom} ($cost gold).', reason: '$size $i: what it does');
        await tapOn(tester, room);
        expect((g.capacity, g.gold, b.message), (cap + capacityStep, gold - cost, null), reason: '$size $i: bought');
        await frames(tester, 30);
      }
      expect(g.capacityCost, capacityPrice + 2 * capacityPriceRise);

      // Too poor: greyed, a tap says the price it needs; nothing moves.
      g.gold = g.capacityCost - 1;
      await frames(tester, 3);
      final (cap, gold) = (g.capacity, g.gold);
      final poor = '${Words.notEnoughGold} (need ${g.capacityCost}).';
      expect((g.canBuyCapacity, g.whyNotCapacity, poor), (false, poor, 'Not enough gold (need 60).'), reason: '$size');
      await tapOn(tester, room);
      expect((g.capacity, g.gold, b.message), (cap, gold, poor), reason: '$size: too poor, says why');
      await frames(tester, 140); // the message goes
      final tip = await hover();
      expect((tip?.first, tip?.last), ('${Words.room}: ${Words.moreRoom} (${g.capacityCost} gold).', poor), reason: '$size');

      // At the most: "Room: max", a tap says so; nothing moves, whatever the gold.
      g
        ..gold = 50000
        ..capacity = g.maxCapacity;
      await frames(tester, 3);
      final most = '${Words.roomAtMost} ($armyMaxBoard).';
      expect((g.maxCapacity, most), (armyMaxBoard, 'Army room is at its most (36).'), reason: '$size');
      expect(words(), [Words.roomMax], reason: '$size: "Room: max" on it');
      await tapOn(tester, room);
      expect((g.capacity, g.gold, b.message), (armyMaxBoard, 50000, most), reason: '$size: at the most, says why');
      await frames(tester, 140);
      expect(await hover(), ['${Words.room}: ${Words.moreRoom}.', most], reason: '$size: its tooltip at the most');

      // A long press (touch) shows the same tooltip; its tap down says why as a tap does.
      final finger = await tester.startGesture(room.center);
      await frames(tester, 60);
      expect(b.message, most, reason: '$size: long press, its tap down');
      expect(b.tooltipShown?.$2, ['${Words.room}: ${Words.moreRoom}.', most], reason: '$size: long press, its tooltip');
      await finger.up();
      await frames(tester, 140);
      b.state = Game();
      await frames(tester, 10);
    }
  });

  testWidgets('the bar clear of the HUD\'s other pieces and the open battle log at the test windows: the slots, '
      'the hotbar, its arrows, +Room and Auto Buy, the step but for its slope under the log button (drawn over it); the '
      'field under the bar takes no press, hover or drag', (tester) async {
    final b = await boot(tester);
    for (final size in [owner, desk, tablet, wide]) {
      for (final wave in [false, true]) {
        tester.view.physicalSize = size;
        final g = b.state = fourTypes();
        if (wave) g.startWave();
        await frames(tester, 40);
        final others = {
          'counter': b.troopCounter,
          'hearts': b.livesBar,
          'gold': b.goldPanel,
          'book button': b.bookButton,
          'toggle': b.toggleButton,
          'x2': b.speedButton,
          'Auto Wave': b.autoButton,
          'meter': b.waveMeter,
          'log': b.logButton,
          'book': b.bookArea, // the open book stands over the bar
        }..removeWhere((_, r) => r == Rect.zero);
        final (back, on) = b.spawnBarArrows;
        final tag = '$size wave $wave';
        final mine = [
          ...b.spawnBarCards,
          (b.spawnBarPanel, 'hotbar'),
          (b.capacityButton, '+Room'),
          (b.autoReplaceButton, 'Auto Buy'),
          if (back != Rect.zero) ...[(back, 'arrow back'), (on, 'arrow on')],
        ];
        for (final (r, t) in [...mine, (b.spawnBarArea, 'step')]) {
          for (final MapEntry(:key, :value) in others.entries) {
            if (t == 'step' && key == 'log') continue; // its slope runs under the log button, drawn over it
            expect(r.overlaps(value), isFalse, reason: '$tag: $t $r over $key $value');
          }
        }
        // The battle log open: its panel over none of the bar's pieces as drawn (+Room's and Auto Buy's faces: their
        // press areas run k round them, and at 1266x713 the panel's bottom rests on Auto Buy's face, over its press
        // area's top, where it stood before 287).
        await tapOn(tester, b.logButton);
        expect(b.logPanel, isNot(Rect.zero), reason: '$size');
        final drawn = [
          for (final (r, t) in mine)
            (t == '+Room' ? b.spawnBarRoomFace : t == 'Auto Buy' ? r.deflate(b.hudScale) : r, t),
        ];
        for (final (r, t) in drawn) {
          expect(r.overlaps(b.logPanel), isFalse, reason: '$tag: $t $r under the log ${b.logPanel}');
        }
        await tapOn(tester, b.logButton);
        final area = b.spawnBarArea;
        for (final (p, what) in [
          (b.spawnBarCards.first.$1.center, 'a slot'),
          (b.spawnBarPanel.topCenter + const Offset(0, 2), 'the hotbar\'s rim'),
          (Offset(area.center.dx, area.top + 1), 'the step\'s top'),
          (Offset(math.max(area.left, 0) + 4, area.bottom - 4), 'the step\'s slope'),
        ]) {
          expect(b.coveredAt(p), isTrue, reason: '$tag: the field under $what covered');
        }
        b.state = Game();
        await frames(tester, 3);
      }
    }
    // A tap on a slot pins no plate; a drag from it moves no troop.
    tester.view.physicalSize = wide;
    final g = b.state = fourTypes();
    await frames(tester, 40);
    final card = b.spawnCard('soldier'), u = g.troops.first, from = u.post;
    expect(b.coveredAt(card.center), isTrue);
    await tapOn(tester, card);
    expect(b.pinned, isNull, reason: 'no plate pinned from the bar');
    await tester.dragFrom(card.center, const Offset(0, -120));
    await frames(tester, 3);
    expect(u.post, from, reason: 'no troop dragged from the bar');
    expect(b.dragging, isNull, reason: 'no troop dragged from the bar');
    await frames(tester, 30);
  });

  testWidgets('a card\'s tooltip: its name, price, count against its cap and why it can\'t be bought', (tester) async {
    final b = await boot(tester);
    final g = b.state = fourTypes()..capacity = 12;
    while (!g.typeFull(Game.freeHealer) && g.autoPlace(Game.freeHealer)) {}
    await frames(tester, 40);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(b.spawnCard('knight').center);
    await frames(tester, 30);
    final cap = g.typeCapOf('knight');
    expect(b.tooltipShown?.$1, troopTypeNames['knight']);
    expect(b.tooltipShown?.$2, ['Buy one: ${thousands(g.priceOf('knight'))} gold.', 'On the field: 1/$cap.']);
    await mouse.moveTo(const Offset(2, 2));
    await mouse.moveTo((await into(tester, b, Game.freeHealer)).center);
    await frames(tester, 30);
    expect(b.tooltipShown?.$2.last, 'Priests full 5/5');
    expect(g.spawnTip('soldier').$2, everyElement(isNot(startsWith('Not'))));
    g.gold = 0;
    expect(g.spawnTip('soldier').$2.last, '${Words.notEnoughGold}.');
    await mouse.moveTo(const Offset(2, 2));
    await frames(tester, 10);
    await mouse.removePointer();
  });

  testWidgets('the guide\'s P1 points at the first card on the strip\'s page that buys, else (one on another page buys) the '
      'arrow toward it, else the first card, which says why; its box clear of it and on screen; a tap there buys and P2 follows', (tester) async {
    final b = await boot(tester);
    for (final size in [desk, small, wide, tablet, owner]) {
      tester.view.physicalSize = size;
      final g = b.state = rich()..gold = 0;
      b.guideSeen = {guideIntro};
      await frames(tester, 40);
      expect(b.coachPointer, 'P1', reason: '$size');
      expect(b.coachPointerTarget, b.spawnBarCards.first.$1, reason: '$size: none buyable: the first card');
      // Only the first type buys, on another page: the arrow back.
      final cheapest = troopTypes.keys.first;
      g.gold = g.priceOf(cheapest);
      expect([for (final t in troopTypes.keys) if (g.buyRefusal(t) == null) t], [cheapest], reason: '$size');
      b.spawnBarFirst = troopTypes.length;
      await frames(tester, 3);
      if (b.spawnCard(cheapest) == Rect.zero) {
        expect(b.coachPointerTarget, b.spawnBarArrows.$1, reason: '$size: the arrow toward the $cheapest');
      }
      expect(b.spawnCard(cheapest) == Rect.zero, size == small, reason: '$size: on another page at 568x320 only');
      b.spawnBarFirst = 0;
      g
        ..gold = 75 // the Soldier to the Archer
        ..capacity = g.armySize + 4;
      await frames(tester, 3);
      final first = troopTypes.keys.firstWhere((t) => g.buyRefusal(t) == null);
      final target = b.coachPointerTarget, box = b.coachPointerBox;
      expect(target, b.spawnCard(first), reason: '$size: the first that buys, $first');
      expect(box.overlaps(target), isFalse, reason: '$size: $box');
      expect(inside(box, Offset.zero & size), isTrue, reason: '$size: $box');
      final army = g.armySize;
      await tapOn(tester, target);
      expect(g.armySize, army + 1, reason: '$size');
      await frames(tester, 3);
      expect(b.coachPointer, 'P2', reason: '$size: P1 seen once the army grew');
      await frames(tester, 30);
    }
  });
}
