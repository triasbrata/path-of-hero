// The Town's sideways pan (decisions-log 264; lib/town_scene.dart; ui-hud.md "Town"): booted TdGames with the Towns on
// at the desk (1266x713), the owner's tablet (1164x777) and a phone (915x412). The pan's room at each size (the
// Town's left end at the screen's left, its right end at the right of what shows, the page's own pan inside it), a
// finger's drag following it and holding, a tap on a building after a pan opening that building's page, a drag never
// tapping, the smith panning with his house, the book shut still panning between the Town's ends (laid out
// wider than the screen, decisions-log 271), and the Town reopening where it opens after a visit panned away. At the
// desk: a gesture from the book, the HUD or a popup never pans it; the HUD's and the book's buttons act on the press as
// before and the Town's taps on the release; a mouse's drag pans and a press moving less than the slop taps; the wheel,
// a trackpad's swipe and a fling pan; the Bag's item drag and its list's scroll work as before. The field never pans.
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'town_hud_test.dart' show boot, frames, townGame;
import 'town_scene_test.dart' show bare, bounds, intoTown, settle, sizes;

/// The right of what shows of the Town: with the book open its left, else the screen's.
double showsRight(Board b, Size size) => b.bookArea.isEmpty ? size.width : b.bookArea.left;

/// A point to drag from: on the street, under the HUD's band, in the middle of what shows.
Offset street(Board b, Size size) => Offset(showsRight(b, size) / 2, b.townLane - 10);

/// The Town's right end on the screen: the Shop's cells' right (its eave tip's clear end, the layout's last 6 world px).
double townRight(Board b) => bounds(b.townBuilding('shop')).right;

/// A drag of [dx] screen px from [from]: 30 px first (past Flutter's slop and the Town's), then the rest, then up; no
/// fling (the test pointer's events carry no time).
Future<void> drag(WidgetTester tester, Offset from, double dx, {PointerDeviceKind kind = PointerDeviceKind.touch}) async {
  final g = await tester.startGesture(from, kind: kind);
  await frames(tester, 1);
  await g.moveBy(Offset(dx.sign * 30, 0));
  await frames(tester, 1);
  await g.moveBy(Offset(dx - dx.sign * 30, 0));
  await frames(tester, 1);
  await g.up();
  await frames(tester, 2);
}

/// The page a building's tap opens (the Tavern its own with it on, as shipped; the Bag with it off).
const pageOf = {'smithy': 'smithy', 'tavern': 'tavern', 'shop': 'store'};

/// A building (not [not]) whose ground floor's left wall shows whole on the scene, and that wall's middle.
(String, Offset)? shownBuilding(Board b, Size size, {String? not}) {
  for (final place in const ['shop', 'tavern', 'smithy']) {
    if (place == not) continue;
    final wall = b.townBuilding(place).firstWhere((c) => c.$1 == 'wallL8a').$2;
    if (wall.left >= 4 && wall.right <= showsRight(b, size) - 4) return (place, wall.center);
  }
  return null;
}

/// Back into a Town in the same game [g]: the next wave won with a Town due after it.
Future<void> backIntoTown(WidgetTester tester, Game g) async {
  g
    ..townAt = g.wave + 2
    ..startWave()
    ..queue.clear()
    ..units.add(g.monster('slime', Tier.normal, const Point(300, 60))..gone = true);
  for (var i = 0; i < 600 && !g.inTown; i++) {
    await frames(tester, 1);
  }
  expect(g.inTown, isTrue);
}

void main() {
  for (final (size, k, _, shut) in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('the Town pans sideways at $tag: its room between its ends, a drag following the finger and holding, a '
        'tap on a building after a pan opening it, a drag never tapping, and the Town reopening where it opens',
        (tester) async {
      final b = await boot(tester, size);
      b.autoStart.set(false);
      final g = await intoTown(tester, b);
      await settle(tester, b);
      expect(b.bookPage, 'smithy');
      final opened = b.townCam, shows = showsRight(b, size);
      final (lo, hi) = b.townRoom;
      expect(lo, min(0.0, opened), reason: "the Town's left end at the screen's left, or the page's own pan");
      expect(hi, greaterThan(opened + 100 / k), reason: 'room to look round to the right: ($lo, $hi) from $opened');

      // All the way right: the Town's left end at the screen's left.
      await drag(tester, street(b, size), 3000);
      expect(b.townCam, lo);
      if (lo == 0) expect(b.townScene['tent']!.left, closeTo(2 * k, 1), reason: "the Town's left end at the screen's");
      // All the way left: its right end at the right of what shows (the book's left).
      await drag(tester, street(b, size), -3000);
      expect(b.townCam, hi);
      expect(townRight(b), closeTo(shows, 2), reason: "the Town's right end at what shows' right");
      // A drag of 208 px: the scene follows from where it passed the 8 px slop, 200 px, and holds there; the Smithy's
      // smith (decisions-log 265) moves with its house.
      Rect wallL8a(String place) => b.townBuilding(place).firstWhere((c) => c.$1 == 'wallL8a').$2;
      final (smith0, house0) = (b.townScene['smith']!, wallL8a('smithy'));
      await drag(tester, street(b, size), 208);
      expect(b.townCam, closeTo(hi - 200 / k, 0.01));
      expect(b.townScene['smith']!.left - smith0.left, closeTo(wallL8a('smithy').left - house0.left, 1),
          reason: 'the smith pans with his house');
      expect(wallL8a('smithy').left - house0.left, closeTo(200, 1));
      await frames(tester, 40);
      expect(b.townCam, closeTo(hi - 200 / k, 0.01), reason: "the player's pan holds");
      expect(b.townRoom, (lo, hi), reason: 'the room stays');
      // A drag that began on another building opens nothing: it pans.
      final (other, on) = shownBuilding(b, size, not: 'smithy')!;
      final before = b.townCam;
      await drag(tester, on, 40);
      expect(b.bookPage, 'smithy', reason: 'a drag from the $other is no tap');
      expect(b.townCam, closeTo(before - 32 / k, 0.01));

      // A tap on a building after the pan opens that building's page, and the pan heads for its place.
      final (place, at) = shownBuilding(b, size, not: 'smithy')!;
      await tester.tapAt(at);
      await frames(tester, 40);
      expect(b.bookPage, pageOf[place], reason: 'the tap at $at after the pan: the $place');
      final sign = b.townSign(place).center.dx;
      expect(sign, closeTo(b.bookArea.left / 2, 2), reason: "the $place's place in view");

      // The bare scene shuts the book: the Town still pans, between its ends at the screen's (the Town 1010 world px
      // wide, decisions-log 271).
      await tester.tapAt(bare(b, size));
      await frames(tester, 40);
      expect(b.bookArea, Rect.zero);
      expect(b.townRoom, (0.0, shut));
      await drag(tester, street(b, size), -3000);
      expect(b.townCam, shut);
      expect(townRight(b), closeTo(size.width, 2), reason: "the Town's right end at the screen's");
      expect(b.bookArea, Rect.zero, reason: 'a drag is no tap: the book stays shut');
      await drag(tester, street(b, size), 3000);
      expect(b.townCam, 0.0);
      expect(b.townScene['tent']!.left, closeTo(2 * k, 1), reason: "the Town's left end at the screen's");
      // A sign opens the book again on its page.
      await tester.tapAt(b.townSign('smithy').center);
      await frames(tester, 40);
      expect(b.bookPage, 'smithy');
      expect(b.townCam, closeTo(opened, 0.01), reason: 'the Smithy where it opens');

      // Panned away, Leave, and the next Town opens where a Town opens.
      await drag(tester, street(b, size), -3000);
      expect(b.townCam, hi);
      await tester.tapAt(b.startButton.center);
      await settle(tester, b);
      expect((g.inTown, b.townShown), (false, false));
      await backIntoTown(tester, g);
      await settle(tester, b);
      expect((b.bookPage, b.townCam), ('smithy', opened), reason: 'the pan reset on leaving');
      await frames(tester, 30);
    });
  }

  testWidgets('at the desk: a gesture from the book, the HUD or a popup never pans the Town; the HUD and the book act on '
      'the press as before, the Town on the release; a mouse drag pans and a press moving under the slop taps; the wheel, '
      'a trackpad swipe and a fling pan; the Bag\'s item drag and its list\'s scroll as before', (tester) async {
    const size = Size(1266, 713);
    final b = await boot(tester, size);
    b.autoStart.set(false);
    final g = await intoTown(tester, b);
    g.inventory[Item.staff] = 2;
    await settle(tester, b);
    final opened = b.townCam;
    final (lo, hi) = b.townRoom;

    // From the book's page, the wave meter (the HUD's band), the troop counter and the log's button: no pan. The
    // counter's and the log's presses are theirs (they open), so they are folded again.
    for (final (what, at) in [
      ('book', b.bookArea.center),
      ('meter', b.waveMeter.center),
      ('counter', b.troopCounter.center),
      ('log', b.logButton.center),
    ]) {
      await drag(tester, at, -300);
      await frames(tester, 30);
      expect(b.townCam, opened, reason: 'a drag from the $what');
      expect(b.bookPage, 'smithy', reason: 'a drag from the $what');
    }
    expect((b.logPanel == Rect.zero, b.troopList), (false, Rect.zero), reason: 'the log open, the list folded for it');
    // The battle log's open panel: its own drag, no pan.
    await drag(tester, b.logPanel.center, -200);
    expect(b.townCam, opened, reason: "a drag on the log's panel");
    await tester.tapAt(b.logButton.center);
    await frames(tester, 4);
    expect(b.logPanel, Rect.zero);
    // A message over the scene: a press on it closes it, its drag pans nothing.
    b.showMessage('A long message over the Town, so its window reaches the scene left of the book');
    await frames(tester, 2);
    final box = b.messageBox, onBox = Offset(box.left + 12, box.center.dy);
    expect(b.bookArea.contains(onBox), isFalse, reason: 'the message over the scene: $box');
    await drag(tester, onBox, -300);
    expect((b.townCam, b.message), (opened, null), reason: 'a drag from the message');

    // The book's buttons act as they are pressed, as before; the Town's taps as the press comes up (the Shop, panned
    // to the Town's right end).
    Rect tabOf(String page) => b.bookTabs.firstWhere((t) => t.$1 == page).$2;
    final tab = await tester.startGesture(tabOf('bag').center);
    await frames(tester, 2);
    expect(b.bookPage, 'bag', reason: 'a tab acts on the press');
    await tab.up();
    await frames(tester, 40);
    await drag(tester, street(b, size), -3000);
    expect(b.townCam, hi);
    final (place, at) = shownBuilding(b, size, not: 'tavern')!;
    expect(place, 'shop');
    final press = await tester.startGesture(at);
    await frames(tester, 4);
    expect(b.bookPage, 'bag', reason: "the $place's tap waits for the release");
    await press.up();
    await frames(tester, 40);
    expect(b.bookPage, pageOf[place], reason: 'and comes with it');

    // A mouse: a drag pans (past the 8 px slop: 108 px move it 100); with the Smithy's house panned in from the Town's
    // left end (its wood corner first: decisions-log 271) a press on it moving 12 px is no tap, 5 px is still one.
    await tester.tapAt(tabOf('bag').center);
    await frames(tester, 40);
    final mid = b.townCam;
    expect(mid, inExclusiveRange(lo + 60, hi - 60), reason: 'room both ways from the Tavern');
    await drag(tester, street(b, size), 108, kind: PointerDeviceKind.mouse);
    expect(b.townCam, closeTo(mid - 50, 0.01));
    await drag(tester, street(b, size), 3000, kind: PointerDeviceKind.mouse);
    expect(b.townCam, lo);
    final wall = b.townBuilding('smithy').firstWhere((c) => c.$1 == 'wallL8a').$2;
    await drag(tester, street(b, size), 40 - wall.left - 8, kind: PointerDeviceKind.mouse);
    for (final (move, taps) in [(-12.0, false), (-5.0, true)]) {
      final (place, at) = shownBuilding(b, size, not: 'tavern')!;
      expect(place, 'smithy');
      final was = b.townCam;
      final m = await tester.startGesture(at, kind: PointerDeviceKind.mouse);
      await frames(tester, 1);
      await m.moveBy(Offset(move, 0));
      await frames(tester, 1);
      await m.up();
      await frames(tester, 2);
      expect(b.bookPage, taps ? pageOf[place] : 'bag', reason: 'a mouse press on the $place moving $move px');
      if (!taps) expect(b.townCam, closeTo(was - (move + 8) / 2, 0.01), reason: 'it panned from the slop on');
      await frames(tester, 40);
    }

    // The wheel over the scene: down goes right, the sideways scroll as it says, gliding (0.4 s); over the book no pan.
    await tester.tapAt(tabOf('bag').center);
    await frames(tester, 40);
    final wheel = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(wheel.hover(street(b, size)));
    var was = b.townCam;
    await tester.sendEventToBinding(wheel.scroll(const Offset(0, 60)));
    await frames(tester, 2);
    expect(b.townCam, inExclusiveRange(was, was + 30), reason: 'on its way');
    await frames(tester, 30);
    expect(b.townCam, closeTo(was + 30, 0.01));
    await tester.sendEventToBinding(wheel.scroll(const Offset(-80, 0)));
    await frames(tester, 30);
    expect(b.townCam, closeTo(was - 10, 0.01));
    was = b.townCam;
    await tester.sendEventToBinding(wheel.hover(b.bookArea.center));
    await tester.sendEventToBinding(wheel.scroll(const Offset(0, 60)));
    await frames(tester, 30);
    expect(b.townCam, was, reason: 'the wheel over the book is the book\'s');

    // A trackpad's two-finger swipe (a pan, not a scroll): the scene follows the fingers.
    final pad = TestPointer(2, PointerDeviceKind.trackpad);
    final on = street(b, size);
    await tester.sendEventToBinding(pad.panZoomStart(on));
    await frames(tester, 1);
    await tester.sendEventToBinding(pad.panZoomUpdate(on, pan: const Offset(-20, 0)));
    await frames(tester, 1);
    await tester.sendEventToBinding(pad.panZoomUpdate(on, pan: const Offset(-60, 0)));
    await frames(tester, 1);
    await tester.sendEventToBinding(pad.panZoomEnd());
    await frames(tester, 30);
    expect(b.townCam, closeTo(was + 30, 0.01), reason: 'a swipe of 60 px to the left');

    // A fling glides on past where the finger let go, inside the room.
    await drag(tester, street(b, size), 3000);
    expect(b.townCam, lo);
    await tester.flingFrom(street(b, size), const Offset(-120, 0), 1500);
    await frames(tester, 40);
    expect(b.townCam, inInclusiveRange(lo + (120 - 8) / 2 + 20, hi), reason: 'glided on');

    // The Bag's item drag: from its cell over the scene the item is dragged, the Town stays.
    expect(b.bookPage, 'bag');
    was = b.townCam;
    final item = await tester.startGesture(b.bagSlot(Item.staff).center);
    await item.moveBy(const Offset(-30, 0));
    await frames(tester);
    await item.moveTo(street(b, size));
    await frames(tester);
    expect(b.dragAt, isNotNull, reason: 'the staff in hand');
    expect(b.townCam, was);
    await item.up();
    await frames(tester, 4);
    expect((g.inventory[Item.staff], b.townCam), (2, was));
    // Its list (Give to troops): a drag scrolls it, the Town stays.
    if (b.picked != Item.staff) {
      await tester.tapAt(b.bagSlot(Item.staff).center);
      await frames(tester, 4);
    }
    expect(b.bagAction(BagAction.giveTroops), isNot(Rect.zero));
    await tester.tapAt(b.bagAction(BagAction.giveTroops).center);
    await frames(tester, 4);
    final rows = b.assignRows, first = rows.first;
    await tester.dragFrom(rows[1].$2.center, const Offset(0, -150));
    await frames(tester);
    expect(b.assignRows.any((r) => r.$1 == first.$1 && r.$2.top == first.$2.top), isFalse, reason: 'the list scrolled');
    expect(b.townCam, was);
    await frames(tester, 30);
  });

  testWidgets('the field never pans: a drag and the wheel on the battle ground between waves leave its camera where it '
      'is', (tester) async {
    final b = await boot(tester);
    b.autoStart.set(false);
    final g = b.state = townGame()..wave = 5;
    await frames(tester, 40);
    expect((g.inTown, b.townShown), (false, false));
    await frames(tester, 120); // the field's camera where it eases to
    final cam = b.camX, ground = b.toScreen(cam + 40, 20);
    expect(b.bookArea.contains(ground), isFalse, reason: 'on the field');
    await drag(tester, ground, -300);
    await drag(tester, ground, 300, kind: PointerDeviceKind.mouse);
    final wheel = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(wheel.hover(ground));
    await tester.sendEventToBinding(wheel.scroll(const Offset(0, 200)));
    await tester.sendEventToBinding(wheel.scroll(const Offset(200, 0)));
    final pad = TestPointer(2, PointerDeviceKind.trackpad);
    await tester.sendEventToBinding(pad.panZoomStart(ground));
    await tester.sendEventToBinding(pad.panZoomUpdate(ground, pan: const Offset(-200, 0)));
    await tester.sendEventToBinding(pad.panZoomEnd());
    await frames(tester, 30);
    expect(b.camX, cam);
    expect(b.townShown, isFalse);
  });
}
