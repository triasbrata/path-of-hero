// The Bag's light controls (decisions-log 198's "Bag chips"; docs/ui-hud.md "Tas, the Bag"): the category chips as one
// segmented paper strip (the one on lit as a picked slot, the others their words on the paper), the pager's two small
// arrow tags (faded at the ends), and a chooser's type filter as light icon tags on the slot's paper card (lit while on); no ui_buttons bevel
// among them. At 1266x713 and 915x412, read off the drawn screen. One TdGame per widget test; never a wave won,
// never the real save (flutter_test_config.dart).
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui' show PointerDeviceKind;

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';

const desk = Size(1266, 713), wide = Size(915, 412);

/// The colours: the page's paper (the slot card's face), the card's rim, the lit card's outline, the pick's cream face and
/// orange rim, and the capsules' outline.
const paper = 0xFFF6CA9F, rim = 0xFFE69C69, litEdge = 0xFFBF6F4A, pickFace = 0xFFFFE9C2, pickRim = 0xFFF77622, outline = 0xFF181425;

/// Boots one TdGame in a [size] window inside a RepaintBoundary under [key], past the welcome screen, with the game's
/// font and the minimap folded.
Future<Board> boot(WidgetTester tester, Size size, GlobalKey key) async {
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

/// The screen as drawn now: its pixel at (x, y) as 0xAARRGGBB.
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

/// The share of [r]'s pixels near [colour].
double share(int Function(int, int) px, Rect r, int colour) {
  var n = 0, all = 0;
  for (var y = r.top.ceil(); y < r.bottom.floor(); y++) {
    for (var x = r.left.ceil(); x < r.right.floor(); x++) {
      all++;
      if (near(px(x, y), colour)) n++;
    }
  }
  return n / max(1, all);
}

/// A board game between waves at wave 30 (the Shop open) with no army cap, gold to spare, a soldier and a knight beside
/// the free priest at their posts, and a long run's bag (bag_grid_test.dart's).
Game stocked() {
  final g = Game(Random(1)).boardRules()
    ..armyMax = null
    ..gold = 5000000
    ..wave = 30;
  for (final type in ['soldier', 'knight']) {
    expect(g.autoPlace(type), isTrue);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.inventory.addAll({Item.sword: 86, Item.shield: 1, Item.bow: 3, Item.potion: 1200, Item.staff: 2});
  g.relicBag.addAll({Relic.fang: 1, Relic.fury: 5, Relic.guard: 2});
  g
    ..givePusaka(Relic.dragonHeart, type: 'knight', stars: 2)
    ..givePusaka(Relic.grail)
    ..givePusaka(Relic.oathOfOne);
  return g;
}

/// Turns the open book to its Bag page, the All chip on and the mouse off the page.
Future<void> openBag(WidgetTester tester, Board b, TestPointer mouse) async {
  if (b.messageBox != Rect.zero) await tapOn(tester, b.messageBox.center);
  await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2.center);
  expect(b.bagOpen, isTrue);
  await tapOn(tester, b.bagChip(BagCategory.all).center);
  await tester.sendEventToBinding(mouse.hover(Offset.zero));
  await frames(tester, 10);
}

void main() {
  for (final size in const [desk, wide]) {
    final at = '${size.width.round()}x${size.height.round()}';

    testWidgets('at $at the category chips are one paper strip across the page, the one on lit as a picked slot, the '
        'others their words on the paper, a segment under the mouse lit', (tester) async {
      final key = GlobalKey(), b = await boot(tester, size, key), mouse = TestPointer(7, PointerDeviceKind.mouse);
      b.state = stocked();
      await frames(tester, 50);
      await openBag(tester, b, mouse);
      // Read where they are in the frame the pixels come from: the book bobs.
      // The chips shown (Materials too).
      final cats = [for (final cat in BagCategory.values) if (b.bagChip(cat) != Rect.zero) cat];
      expect(cats, [BagCategory.all, BagCategory.items, BagCategory.relics, BagCategory.materials, BagCategory.artifacts]);
      List<Rect> chips() => [for (final cat in cats) b.bagChip(cat)];
      // The segments tile the strip, which spans the page's writing: no gap, one top and height, a finger's.
      final page = b.bookPages.$1, now = chips();
      expect((now.first.left - page.left).abs() < 1 && (now.last.right - page.right).abs() < 1, isTrue, reason: '$at $now in $page');
      for (final (i, r) in now.indexed) {
        expect((r.top, r.height, r.height >= 20), (now.first.top, now.first.height, true), reason: '$at chip $i');
        if (i > 0) expect(r.left, moreOrLessEquals(now[i - 1].right), reason: '$at chip $i: next to the last');
      }

      Future<void> lit(BagCategory on, String why) async {
        final px = await screenPixels(tester, key);
        for (final (i, r) in chips().indexed) {
          final face = share(px, r, pickFace), orange = share(px, r, pickRim), plain = share(px, r, paper);
          if (cats[i] == on) {
            // Five segments (Materials too; 0.4 with four): the rim and the bold word
            // take a larger share of a narrower one, and the others have none of the face at all.
            expect((face > 0.25, orange > 0.02), (true, true), reason: '$at $why: ${cats[i]} lit as a pick ($face, $orange)');
          } else {
            expect((face, orange, plain > 0.5), (0.0, 0.0, true), reason: '$at $why: ${cats[i]} on the paper ($plain)');
          }
        }
      }

      await lit(BagCategory.all, 'All');
      await tapOn(tester, b.bagChip(BagCategory.items).center);
      await tester.sendEventToBinding(mouse.hover(Offset.zero));
      await frames(tester, 10);
      expect(b.bagCategory, BagCategory.items);
      await lit(BagCategory.items, 'Items');

      // Under the mouse a segment lights as a slot does (the lit card's outline and 2-px rim): less of it is paper.
      final before = share(await screenPixels(tester, key), b.bagChip(BagCategory.relics), paper);
      await tester.sendEventToBinding(mouse.hover(b.bagChip(BagCategory.relics).center));
      await frames(tester, 3);
      final hovered = await screenPixels(tester, key), relics = b.bagChip(BagCategory.relics);
      expect((share(hovered, relics, paper) < before - 0.05, share(hovered, relics, pickFace)), (true, 0.0), reason: '$at hover');
      await tester.sendEventToBinding(mouse.hover(Offset.zero));
      await tapOn(tester, b.bagChip(BagCategory.all).center);
      await frames(tester, 10);
    }, tags: 'art');

    testWidgets('at $at a chooser\'s type filter is light icon tags on the slot\'s paper card, lit as a pick while on, the '
        'lit card under the mouse', (tester) async {
      final key = GlobalKey(), b = await boot(tester, size, key), mouse = TestPointer(7, PointerDeviceKind.mouse);
      b.state = stocked();
      await frames(tester, 50);
      await openBag(tester, b, mouse);
      await tapOn(tester, b.bagSlot(Relic.fury).center);
      await tapOn(tester, b.bagAction(BagAction.equip).center);
      if (b.assignFilter.isNotEmpty) await tapOn(tester, b.assignChip(null).center);
      await tester.sendEventToBinding(mouse.hover(Offset.zero));
      await frames(tester, 10);

      // A tag's face is its rect less the lit card's outline and rim (4 px: it may sink); its top row is the card's edge
      // (the plain card's rim, the lit card's outline), less its cut corners.
      Rect face(Rect r) => r.deflate(4);
      Rect edge(Rect r) => Rect.fromLTWH(r.left + 3, r.top.roundToDouble(), r.width - 6, 1);
      expect((b.assignChip(null).height >= 20, b.assignChip('soldier').height >= 20), (true, true), reason: at);
      var px = await screenPixels(tester, key);
      expect(share(px, face(b.assignChip(null)), pickFace), greaterThan(0.4), reason: '$at: All on, lit');
      expect(share(px, face(b.assignChip('soldier')), pickFace), 0.0, reason: '$at: soldier off');
      expect(share(px, edge(b.assignChip('soldier')), rim), greaterThan(0.5), reason: '$at: the off tag, a plain card');

      await tapOn(tester, b.assignChip('soldier').center);
      await tester.sendEventToBinding(mouse.hover(Offset.zero));
      await frames(tester, 10);
      expect(b.assignFilter, {'soldier'});
      px = await screenPixels(tester, key);
      expect((share(px, face(b.assignChip(null)), pickFace), share(px, face(b.assignChip('soldier')), pickFace) > 0.2), (0.0, true),
          reason: '$at: soldier on');

      await tester.sendEventToBinding(mouse.hover(b.assignChip('archer').center));
      await frames(tester, 3);
      px = await screenPixels(tester, key);
      final archer = b.assignChip('archer');
      expect((share(px, edge(archer), litEdge) > 0.5, share(px, face(archer), pickFace)), (true, 0.0), reason: '$at: under the mouse');
      await tester.sendEventToBinding(mouse.hover(Offset.zero));
      await tapOn(tester, b.assignChip(null).center);
      await frames(tester, 10);
    }, tags: 'art');
  }

  testWidgets('at 915x412 with everything owned the pager is two small arrow tags in their hit places, the one at the '
      'end faded, and "1/2" between', (tester) async {
    final key = GlobalKey(), b = await boot(tester, wide, key), mouse = TestPointer(7, PointerDeviceKind.mouse);
    final g = b.state = stocked();
    for (final r in Relic.values) {
      if (r.pusaka && !g.pusaka.containsKey(r)) g.givePusaka(r);
      if (!r.pusaka) g.relicBag[r] = (g.relicBag[r] ?? 0) + 1;
    }
    for (final i in droppedItems) {
      g.inventory[i] = (g.inventory[i] ?? 0) + 1;
    }
    await frames(tester, 50);
    await openBag(tester, b, mouse);
    expect(b.bagPages, greaterThan(1));
    var px = await screenPixels(tester, key);
    final back = b.bagPager('back'), on = b.bagPager('on');
    expect((back.width >= 32, back.height >= 20, on.width >= 32, on.height >= 20), (true, true, true, true), reason: '$back $on');
    // No bevel: each place mostly the page's paper; the live tag's outline drawn, the faded one's blended away.
    expect((share(px, back, paper) > 0.6, share(px, on, paper) > 0.6), (true, true));
    expect((share(px, back, outline), share(px, on, outline) > 0.02), (0.0, true), reason: 'page 1: ◂ faded, ▸ live');
    await tapOn(tester, b.bagPager('back').center);
    expect(b.bagPage, 0, reason: 'faded: no turn');
    await tapOn(tester, b.bagPager('on').center);
    expect(b.bagPage, 1);
    while (b.bagPage < b.bagPages - 1) {
      await tapOn(tester, b.bagPager('on').center);
    }
    await tester.sendEventToBinding(mouse.hover(Offset.zero));
    await frames(tester, 10);
    px = await screenPixels(tester, key);
    expect((share(px, b.bagPager('back'), outline) > 0.02, share(px, b.bagPager('on'), outline)), (true, 0.0), reason: 'the last page');
    await frames(tester, 10);
  }, tags: 'art');
}
