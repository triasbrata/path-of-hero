// The Army in a Town (decisions-log 301; the owner, 2026-10-09: "di town tab army harus di munculkan dan ketika user
// tenda maka akan ke tab army"; lib/town_scene.dart, lib/troops_page.dart; ui-hud.md "Town" and "Army"): a Town's book
// has the Army tab after the Shop (Smithy, Tavern, Shop, Army, Bag, Settings), the field's page as it is (the grid and
// the picked type's detail; Release works, a wish tapped goes to the Smithy on it; no "Replace fallen", the field's buy),
// and a tap on the tent or its campfire opens it, the view panning to the tent; the other places' taps as before. The
// tabs' press areas are the tap rule's (44 px each way, [bookTabTapMin]), none over another, over a page's writing or a
// piece of the HUD, at 1600x947, 1266x713, 1164x777 and 915x412, in a Town and on the field, as the book bobs. Booted
// TdGames with the Towns and the forge on, seeded.
//
// Never let a wave be won or the game end here (the Board then saves).
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'town_scene_test.dart' show bare, intoTown, settle, wheel;
import 'wishlist_ui_test.dart' show boot, forgeGame, frames, inside, shutMessage, tapOn;

const sizes = [Size(1600, 947), Size(1266, 713), Size(1164, 777), Size(915, 412)];

/// The HUD's pieces this frame, by name (a press area of the toggle, x2 and the book button reaches k round them: 4 px
/// at the most).
Map<String, Rect> hud(Board b) => {
      'counter': b.troopCounter,
      'hearts': b.livesBar,
      'gold': b.goldPanel,
      'book': b.bookButton,
      'toggle': b.toggleButton,
      'x2': b.speedButton,
      'Auto': b.autoButton,
      'meter': b.waveMeter,
      'log': b.logButton,
      'townChip': b.townChip,
      'map': b.miniMap,
      'chest': b.chestChip,
      for (final (i, r) in b.boostChips.indexed) 'boost$i': r,
    };

/// The book's tabs as the tap rule wants them, over the book's bob (sampled across one swing): every shut tab's press
/// area at least [bookTabTapMin] each way, round its tab, on the screen, none over another, over the pages' writing or
/// a piece of the HUD; the tabs drawn inside the screen and clear of the HUD too. [open] is the open page.
Future<void> tabsFit(WidgetTester tester, Board b, Size size, String open, String tag) async {
  final screen = Offset.zero & size;
  for (var i = 0; i < 8; i++) {
    final tabs = b.bookTabs, taps = b.bookTabTaps, pages = b.bookPages;
    expect([for (final (name, _) in taps) name], [for (final (name, _) in tabs) if (name != open) name],
        reason: '$tag: a press area for every shut tab, none for the open one');
    final top = min(pages.$1.top, pages.$2.top);
    for (final (name, r) in taps) {
      final tab = tabs.firstWhere((t) => t.$1 == name).$2;
      expect((r.width >= bookTabTapMin - 0.01, r.height >= bookTabTapMin - 0.01), (true, true), reason: '$tag $name: $r');
      expect(inside(tab, r), isTrue, reason: '$tag $name: its tab $tab inside its press area $r');
      expect(inside(r, screen), isTrue, reason: '$tag $name: on the screen, $r');
      expect(r.bottom, lessThanOrEqualTo(top + 0.5), reason: "$tag $name: over the pages' writing ($top), $r");
      for (final (other, o) in taps) {
        // Side by side they may touch (a hair's float apart), never cover each other.
        if (other != name) expect(r.deflate(0.01).overlaps(o), isFalse, reason: '$tag: $name $r over $other $o');
      }
    }
    for (final (name, r) in [...tabs, ...taps]) {
      expect(inside(r, screen), isTrue, reason: '$tag $name: on the screen, $r');
      for (final MapEntry(key: piece, value: h) in hud(b).entries) {
        if (h.isEmpty) continue;
        expect(r.overlaps(h.inflate(4)), isFalse, reason: '$tag: the $name tab $r over the HUD\'s $piece $h');
      }
    }
    await frames(tester, 30); // ~0.5 s: an eighth of the bob's swing
  }
}

/// [type]'s cell on the Army grid, its page turned to (a short book shows a few rows a page, 915x412 two).
Future<Rect> cell(WidgetTester tester, Board b, String type) async {
  while (b.troopRow(type) == Rect.zero && b.armyPage > 0) {
    await tapOn(tester, b.armyPager.$1, 'back to $type');
  }
  while (b.troopRow(type) == Rect.zero && b.armyPage < b.armyPageCount - 1) {
    await tapOn(tester, b.armyPager.$2, 'on to $type');
  }
  return b.troopRow(type);
}

void main() {
  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('the Army in a Town at $tag: its tab after the Shop; the tabs fit (the tap rule, clear of the HUD); the '
        'tent opens it, panned to; its grid and detail, Release, a wish to the Smithy, no Replace fallen; the other '
        "places' taps as before", (tester) async {
      final b = await boot(tester, size);
      final g = b.state = forgeGame();
      await frames(tester, 40);
      // A game that comes in in a Town opens on the Smithy, with the Army's tab after the Shop's.
      expect((b.bookPage, b.townShown), ('smithy', true));
      expect([for (final (name, _) in b.bookTabs) name], ['smithy', 'tavern', 'store', 'dungeon', 'troops', 'bag', 'settings']);
      await tabsFit(tester, b, size, 'smithy', '$tag Town, Smithy');

      // The Army's tab: the field's page (the grid, the picked type's detail), the view panned to the tent (the
      // troops' rest) left of the book.
      await tapOn(tester, b.bookTabTaps.firstWhere((t) => t.$1 == 'troops').$2);
      await frames(tester, 40);
      expect(b.bookPage, 'troops');
      for (final type in ['soldier', 'knight', 'archer', 'priest']) {
        expect(await cell(tester, b, type), isNot(Rect.zero), reason: '$tag: $type on the grid');
      }
      expect(b.townScene['tent']!.center.dx, closeTo(b.bookArea.left / 2, 2), reason: '$tag: the tent in view');
      await tabsFit(tester, b, size, 'troops', '$tag Town, Army');

      // Its detail: the stats; Release sends a type home (two taps), as on the field.
      await tapOn(tester, await cell(tester, b, 'archer'));
      expect(b.troopPicked, 'archer');
      expect(b.troopDetail('stats'), isNot(Rect.zero), reason: '$tag: the stats');
      final refund = g.releaseRefundOf('archer'), was = g.gold;
      await tapOn(tester, b.troopDetail('release'), '$tag: Release');
      expect(b.releaseArmed, 'archer');
      await tapOn(tester, b.troopDetail('releaseConfirm'), '$tag: its confirm');
      expect((g.troopCounts['archer'], g.gold, b.bookPage), (null, was + refund, 'troops'), reason: '$tag: sent home');
      await shutMessage(tester, b);

      // No "Replace fallen" in a Town (no troop is bought there); back on the field it shows.
      g.toReplace.add((type: 'soldier', post: g.troops.first.post));
      await tapOn(tester, await cell(tester, b, 'soldier'));
      await frames(tester, 3);
      expect(b.troopDetail('replace'), Rect.zero, reason: '$tag: no Replace fallen in a Town');

      // A wish tapped on the detail goes to the Smithy's Items tab on it (wishlist_look.dart's _wishGo, in a Town).
      g.toggleWish('knight', Item.steelSword);
      await tapOn(tester, await cell(tester, b, 'knight'));
      var wish = b.troopDetail('wish:steelSword');
      for (var i = 0; i < 80 && (wish == Rect.zero || wish.bottom >= b.troopDetailBody.bottom - 1); i++) {
        b.troopDetailScroll += 16;
        await frames(tester, 2);
        wish = b.troopDetail('wish:steelSword');
      }
      await tapOn(tester, wish, '$tag: the knight\'s wish');
      expect((b.bookPage, b.smithyItem), ('smithy', Item.steelSword), reason: '$tag: the wish on the Smithy');

      // The tent: shut the book, the view to the Town's left end, a tap on the tent opens the book on the Army, panned
      // to the tent; its campfire too (the rest's place). A tap on the bare scene still shuts the book.
      await tester.tapAt(bare(b, size));
      await frames(tester, 40);
      expect(b.bookArea, Rect.zero, reason: '$tag: shut');
      await wheel(tester, bare(b, size), -3000);
      expect(b.townCam, b.townRoom.$1);
      final tent = b.townScene['tent']!;
      await tester.tapAt(Offset(tent.center.dx, tent.bottom - tent.height / 4));
      await frames(tester, 40);
      expect((b.bookPage, b.bookArea == Rect.zero), ('troops', false), reason: '$tag: the tent opens the Army');
      expect(b.townScene['tent']!.center.dx, closeTo(b.bookArea.left / 2, 2), reason: '$tag: the tent in view');
      await tapOn(tester, b.bookTabTaps.firstWhere((t) => t.$1 == 'bag').$2);
      await frames(tester, 40);
      expect(b.bookPage, 'bag');
      await tester.tapAt(bare(b, size));
      await frames(tester, 40);
      await wheel(tester, bare(b, size), -3000);
      await tester.tapAt(b.townScene['campfire']!.center);
      await frames(tester, 40);
      expect((b.bookPage, b.bookArea == Rect.zero), ('troops', false), reason: '$tag: its campfire too');

      // The other places as before: the bare scene shuts the book (it shut on the Army: the tent in view), the Smithy's
      // sign opens the Smithy, the Tavern's building the Tavern, the Shop's sign the Shop.
      await tester.tapAt(bare(b, size));
      await frames(tester, 40);
      expect(b.bookArea, Rect.zero);
      expect(b.townScene['tent']!.left, greaterThanOrEqualTo(-1), reason: "$tag: shut on the Army, the tent in view");
      await tester.tapAt(b.townSign('smithy').center);
      await frames(tester, 40);
      expect(b.bookPage, 'smithy');
      await tester.tapAt(bare(b, size));
      await frames(tester, 40);
      // The Tavern's building panned into view (the Dungeon's door past the Shop is the Town's right end now,
      // decisions-log 337).
      Rect tavernWall() => b.townBuilding('tavern').firstWhere((c) => c.$1 == 'wallL8a').$2;
      for (var i = 0; i < 30 && (tavernWall().left < 4 || tavernWall().right > size.width - 4); i++) {
        await wheel(tester, bare(b, size), tavernWall().left < 4 ? -60 : 60);
      }
      await tester.tapAt(tavernWall().center);
      await frames(tester, 40);
      expect(b.bookPage, 'tavern');
      await tester.tapAt(bare(b, size));
      await frames(tester, 40);
      await wheel(tester, bare(b, size), 3000);
      await tester.tapAt(b.townSign('shop').center);
      await frames(tester, 40);
      expect(b.bookPage, 'store');

      // Leave on the Army: the field's book stays on it, and Replace fallen shows there.
      await tapOn(tester, b.bookTabTaps.firstWhere((t) => t.$1 == 'troops').$2);
      g.leaveTown();
      await frames(tester, 60);
      expect((g.inTown, b.bookPage), (false, 'troops'));
      expect([for (final (name, _) in b.bookTabs) name], ['troops', 'bag', 'settings']);
      await tapOn(tester, await cell(tester, b, 'soldier'));
      await frames(tester, 3);
      expect(b.troopDetail('replace'), isNot(Rect.zero), reason: '$tag: Replace fallen on the field');
      await tabsFit(tester, b, size, 'troops', '$tag field');
      b.state = Game();
      await frames(tester, 5);
    });
  }

  testWidgets('a Town gone into from the field\'s Army opens on the Smithy, as before; its Army tab then turns to the Army',
      (tester) async {
    final b = await boot(tester, const Size(1266, 713));
    expect(b.bookPage, 'troops');
    await intoTown(tester, b);
    await settle(tester, b);
    expect((b.townShown, b.bookPage), (true, 'smithy'));
    await tapOn(tester, b.bookTabTaps.firstWhere((t) => t.$1 == 'troops').$2);
    await frames(tester, 10);
    expect(b.bookPage, 'troops', reason: 'the Army stays open in a Town');
    b.state = Game();
    await frames(tester, 5);
  });
}
