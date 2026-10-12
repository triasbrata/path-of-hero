// The Smithy's Wishlist tab, where wishes are made and never added (decisions-log 300, 302, 303; lib/smithy_page.dart,
// lib/wishlist_look.dart; docs/ui-hud.md "The Smithy", "The Bag" and "Army"), booted TdGames in a Town. At 1600x947,
// 1266x713, 1164x777 and 915x412: the Smithy opens on its Wishlist tab; no Add, no picker, no count to change on it; a
// group per type with open wishes, then "For the Bag", each its heading over a row per thing to make, the rows down the
// left page and on down the right one (no product page), paged by spreads, each row inside its page: "Sword ×2 for
// Knight", its parts' "have/need" for all still to make (the gold what it takes), "Ready" or what is short, Craft and a
// type's "Give to <type>" in the row, its ✕. Craft and Give from a row do what the item page's do (the same refusals,
// the same messages); a met wish drops off the tab; the Awaken a Give brings ends the set; a free line's craft that
// meets it drops it. The ✕ takes one wish off, a group's Remove (two taps; the first lapses after 3 s) the group's. The
// places that add: a product's Smithy page (its free line, no types' chips), the Bag's item and relic pages (the same
// free line), the Army detail ("Wishlist all", the needs rows' "+"). The materials' star in the Bag's Materials and the
// Shop's Buy (a free relic's too). Nothing crafts or gives by itself. One TdGame per test.
//
// Never let a wave be won or the game end here (the Board then saves).
import 'dart:math';

import 'package:flame/game.dart' hide Game;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

import 'hud_font.dart';
import 'page_scroll.dart';

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

/// Taps [r]'s middle (never Rect.zero).
Future<void> tapOn(WidgetTester tester, Rect r, [String why = '']) async {
  expect(r, isNot(Rect.zero), reason: why);
  await tester.tapAt(r.center);
  await frames(tester, 3);
}

/// Shuts the message window (it can lie over the rows).
Future<void> shutMessage(WidgetTester tester, Board b) async {
  if (b.messageBox != Rect.zero) await tapOn(tester, b.messageBox);
}

/// [r] wholly inside [area].
bool inside(Rect r, Rect area) => r.left >= area.left - 0.5 && r.top >= area.top - 0.5 && r.right <= area.right + 0.5 && r.bottom <= area.bottom + 0.5;

/// The Smithy's facing page scrolled until its part [key] shows, and that part there.
Future<Rect> seen(WidgetTester tester, Board b, String key) => scrolledTo(tester, b, 'smithy', () => b.smithyAt(key));

const sizes = [Size(1600, 947), Size(1266, 713), Size(1164, 777), Size(915, 412)];

/// A board game after wave 20 in the Town before wave 21: a soldier, a knight, an archer and a priest (none holding an
/// item: each still needs grade I's set), 40,000 gold, the materials for a few grade-I items.
Game townGame() {
  final g = Game(Random(1), Random(2)).boardRules()
    ..townDice = Random(3)
    ..armyMax = null
    ..wave = 20
    ..gold = 40000
    ..townAt = 21
    ..inTown = true;
  for (final type in ['soldier', 'knight', 'archer', 'priest']) {
    g.autoPlace(type);
  }
  for (final u in g.troops) {
    u
      ..pos = u.post
      ..arriving = false;
  }
  g.materials.addAll({Mat.wolfClaw: 2, Mat.orcEar: 1, Mat.tealCloth: 4, Mat.batWing: 2, Mat.boneShard: 6, Mat.orcTooth: 4, Mat.slimeGel: 3});
  return g;
}

/// What a craft or a gift would change in [g], written out (each map in its keys' order, whatever order they came in).
String bags(Game g) {
  String sorted(Map<Object, Object?> m) => (m.entries.map((e) => '${e.key}: ${e.value}').toList()..sort()).join(', ');
  return '${sorted(g.materials)} | ${sorted(g.inventory)} | ${g.gold} | ${sorted(g.upgrades)} | ${sorted(g.relicBag)}';
}

/// Puts [relic]'s recipe [times] over in [g]'s Bag (its materials and items; the gold is there).
void giveRelicRecipe(Game g, Relic relic, [int times = 1]) {
  final r = g.craftRecipe(relic)!;
  for (final MapEntry(key: m, value: n) in r.materials.entries) {
    g.materials[m] = (g.materials[m] ?? 0) + n * times;
  }
  for (final MapEntry(key: i, value: n) in r.items.entries) {
    g.inventory[i] = (g.inventory[i] ?? 0) + n * times;
  }
}

/// [r]'s key on the tab: its group and its product's name.
String keyOf(WishRow r) => '${r.type ?? 'free'}:${r.kind.name}';

/// [r]'s parts as the tab says them: each part's name ("gold") and "have/need" (the gold what it takes); none with
/// nothing to make.
String partsOf(WishRow r) => r.make == 0
    ? ''
    : [for (final p in r.parts) '${p.kind?.name ?? 'gold'} ${p.kind == null ? shortPrice(p.need) : '${shortCount(p.have)}/${p.need}'}'].join(',');

/// The rows on the spread shown, by key.
List<String> spread(Board b) => (b.smithyText('wishPage') ?? '').split('|').where((k) => k.isNotEmpty).toList();

/// Back to the tab's first spread.
Future<void> firstSpread(WidgetTester tester, Board b) async {
  await shutMessage(tester, b);
  while (b.smithyWishPage > 0) {
    await tapOn(tester, b.smithyWishPager('back'));
  }
}

/// The spread with row [key] on it, turned to from the first.
Future<void> toRow(WidgetTester tester, Board b, String key) async {
  await firstSpread(tester, b);
  while (!spread(b).contains(key) && b.smithyWishPage < b.smithyWishPages - 1) {
    await tapOn(tester, b.smithyWishPager('on'));
  }
  expect(spread(b), contains(key));
}

/// Each spread's rows over the tab (its pager turns them, back to the first after).
Future<List<List<String>>> spreads(WidgetTester tester, Board b) async {
  await firstSpread(tester, b);
  final all = <List<String>>[];
  for (var p = 0; p < b.smithyWishPages; p++) {
    if (p > 0) await tapOn(tester, b.smithyWishPager('on'));
    all.add(spread(b));
  }
  await firstSpread(tester, b);
  return all;
}

/// The rows each spread holds, its left page's and its right page's, with the tab's wishes of the first test: at the
/// owner's 1600x947, the desk's 1266x713, the tablet's 1164x777 and a phone's 915x412 (decisions-log 303's table).
const perSpread = {
  '1600x947': '4+6,3+6',
  '1266x713': '4+6,3+6',
  '1164x777': '3+5,3+6,2+0',
  '915x412': '1+3,1+3,1+3,1+3,1+2',
};

void main() {
  test("a row's flow under its title (decisions-log 303): parts to a line while they fit, then the status's end beside the "
      'last or on a line of its own', () {
    // Three parts 40 wide in 160 from 0, 6 apart: two to a line (40+6+40+6 = 92; the third at 92 ends 132 ≤ 160).
    var f = wishFlow([40, 40, 40], 20, 0, 160, 6);
    expect(f.at, [(1, 0.0), (1, 46.0), (1, 92.0)]);
    expect((f.endLine, f.endX, f.lines), (1, 138.0, 2));
    // The end 30 wide no longer fits after them (138 + 30 > 160): a line of its own.
    f = wishFlow([40, 40, 40], 30, 0, 160, 6);
    expect((f.endLine, f.endX, f.lines), (2, 0.0, 3));
    // Four parts: the fourth wraps under the first.
    f = wishFlow([40, 40, 40, 40], 20, 10, 160, 6);
    expect((f.at.last, f.endLine, f.lines), ((2, 10.0), 2, 3));
    // No parts (a type's row with all in the Bag): the end on the first line under the title.
    f = wishFlow(const [], 50, 0, 160, 6);
    expect(f.at, isEmpty);
    expect((f.endLine, f.endX, f.lines), (1, 0.0, 2));
  });

  for (final size in sizes) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('the Wishlist tab at $tag: no Add, no picker; a group per type then "For the Bag", a row per thing to make, '
        'its parts\' have/need, its status, Craft and Give in it; down both pages, paged by spreads; nothing changes by a look',
        (tester) async {
      final b = await boot(tester, size);
      final g = b.state = townGame();
      g.upgrades['knight'] = [Item.sword];
      g.inventory[Item.amulet] = 1;
      for (final type in ['knight', 'archer', 'priest']) {
        g.wishSet(type);
      }
      g
        ..wish('knight', Item.royalHelm)
        ..unwishParts(); // its Steel Helm and Leather Cap rows (decisions-log 323) are smithy_chain_ui_test.dart's
      final relic = smithyRelics(g).first;
      expect((g.wishFreeAdd(relic, 2), g.wishFreeAdd(Item.steelSword)), (true, true));
      await frames(tester, 40);
      await shutMessage(tester, b);
      expect((b.bookPage, b.smithyTab, b.smithyText('tabs')), ('smithy', SmithyTab.wishlist, 'Wishlist|Items|Relics|Enhance'));
      final before = bags(g);

      // Nothing on it adds or edits (decisions-log 303): no Add, no picker, no free line's count; no materials; no product
      // page (the rows take both pages).
      expect((b.smithyAt('add'), b.smithyText('add'), b.smithyAt('freeLess'), b.smithyAt('freeMore'), b.smithyAt('freeAdd')),
          (Rect.zero, null, Rect.zero, Rect.zero, Rect.zero), reason: tag);
      for (final t in troopTypes.keys) {
        expect((b.smithyAt('setPick:$t'), b.smithyAt('wish:$t')), (Rect.zero, Rect.zero), reason: '$tag $t');
      }
      expect((b.smithyAt('kinds'), b.bagCells.length, b.smithyAt('craft'), b.smithyAt('recipe')), (Rect.zero, 0, Rect.zero, Rect.zero), reason: tag);
      final (left, right) = b.bookPages;
      final head = b.smithyAt('wishHead');
      expect(inside(head, left) && head.top >= b.smithyAt('tab:wishlist').bottom - 0.5, isTrue, reason: '$tag: $head under the strip');

      // The rows in order: each type's open wishes (troop types' order, each in the order put on: the knight's Sword, held
      // 1 of 3, wants 2), then the free lines; how many they still want.
      final rows = g.wishRows;
      expect(b.smithyText('wishLines'), [for (final r in rows) '${keyOf(r)} ×${r.need}'].join('|'));
      expect(b.smithyText('wishLines')!.split('|'), [
        'knight:sword ×2', 'knight:shield ×3', 'knight:boots ×2', 'knight:gloves ×2', 'knight:amulet ×1', 'knight:royalHelm ×1', //
        for (final t in ['archer', 'priest'])
          for (final MapEntry(key: i, value: n) in g.gradeSet(t, 1).entries) '$t:${i.name} ×$n',
        'free:${relic.name} ×2', 'free:steelSword ×1',
      ]);
      final need = rows.fold(0, (a, r) => a + r.need);
      if (b.smithyText('wishNeeded') case final said?) expect(said, '$need needed');

      // Every row once over the spreads, each where its page is, with its words from the rules.
      final seenRows = <String>[], groups = <String>{};
      final all = await spreads(tester, b);
      expect(b.smithyText('wishPer'), perSpread[tag], reason: '$tag: the rows a spread holds');
      for (final (p, keys) in all.indexed) {
        while (b.smithyWishPage < p) {
          await tapOn(tester, b.smithyWishPager('on'));
        }
        final pager = b.smithyWishPages > 1 ? b.smithyWishPager('back') : Rect.zero;
        for (final key in keys) {
          final r = rows.firstWhere((r) => keyOf(r) == key), card = b.smithyAt('wishRow:$key'), group = r.type ?? 'free';
          final page = inside(card, left) ? left : right;
          expect(inside(card, page), isTrue, reason: '$tag $key: $card on a page');
          if (page == left) expect(card.top, greaterThanOrEqualTo(head.bottom - 0.5), reason: '$tag $key: under the heading');
          if (pager != Rect.zero && page == left) expect(card.bottom, lessThanOrEqualTo(pager.top + 0.5), reason: '$tag $key: over the pager');
          // Its group's heading over it on its page (again on each page it goes on to).
          final heads = [for (final (gr, h) in b.smithyWishHeads) if (gr == group && inside(h, page) && h.top < card.top) h];
          expect(heads, isNotEmpty, reason: '$tag $key: $group\'s heading over it on its page ${b.smithyWishHeads}');
          groups.add(group);
          // Its ✕ and its tags inside it.
          expect(inside(b.smithyAt('wishOff:$key'), card), isTrue, reason: '$tag $key ✕');
          expect(b.smithyText('wishParts:$key'), partsOf(r), reason: '$tag $key');
          final name = '${r.kind is Item ? itemNames[r.kind] : relicNames[r.kind]} ×${r.need}';
          expect(b.smithyText('wishTitle:$key'), anyOf(name, '$name for ${troopTypeNames[r.type]}'), reason: '$tag $key');
          final status = b.smithyText('wishStatus:$key')!, short = g.wishRowShort(r);
          if (r.make == 0) {
            expect(status, anyOf('In ${Words.bag}: ${g.inBag(r.kind)}', 'In ${Words.bag}'), reason: '$tag $key');
          } else if (short.isEmpty) {
            expect(status, Words.ready, reason: '$tag $key');
          } else {
            expect(status, startsWith(Words.short), reason: '$tag $key');
          }
          if (r.make > 0) {
            expect(inside(b.smithyAt('wishCraft:$key'), card), isTrue, reason: '$tag $key: Craft');
            final why = switch (r.kind) { final Item i => g.whyNotCraftItem(i), final Relic relic => g.whyNotCraft(relic), _ => null };
            expect(b.smithyText('wishCraft:$key'), why?.text ?? '', reason: '$tag $key');
          } else {
            expect(b.smithyAt('wishCraft:$key'), Rect.zero, reason: '$tag $key: nothing to make');
          }
          final give = r.type != null && g.inBag(r.kind) > 0;
          expect(b.smithyAt('wishGive:$key') != Rect.zero, give, reason: '$tag $key: Give');
          if (give) {
            expect(inside(b.smithyAt('wishGive:$key'), card), isTrue, reason: '$tag $key: Give inside');
            expect(b.smithyText('wishGive:$key'), anyOf('${Words.give} to ${troopTypeNames[r.type]}', Words.give));
          }
          seenRows.add(key);
        }
      }
      expect(seenRows, [for (final r in rows) keyOf(r)], reason: '$tag: each row once, in order');
      expect(groups, {'knight', 'archer', 'priest', 'free'});
      // The knight's Sword: Bone Shard 6/4 and Orc Tooth 4/4 for the two still to make, 40 gold; ready.
      expect(partsOf(rows.first), 'boneShard 6/4,orcTooth 4/4,gold 40');
      // The Amulet the Bag holds: nothing to make, Give.
      final amulet = rows.firstWhere((r) => keyOf(r) == 'knight:amulet');
      expect((amulet.make, partsOf(amulet)), (0, ''));

      // A look changes nothing; a tap on a row's words picks nothing (no product page here).
      await firstSpread(tester, b);
      final first = b.smithyAt('wishRow:knight:sword');
      await tester.tapAt(Offset(first.left + first.width * 0.4, first.bottom - 3));
      await frames(tester, 3);
      expect((b.smithyTab, b.smithyAt('craft')), (SmithyTab.wishlist, Rect.zero));
      expect(bags(g), before, reason: '$tag: nothing crafts or gives by itself');
      b.state = Game();
      await frames(tester, 5);
    });
  }

  for (final size in [const Size(1266, 713), const Size(915, 412)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('a row at $tag crafts and gives as the item page does: Craft one (refused: greyed, a tap says why), "Give to '
        'Knight" (refused: greyed with why); a met wish drops off; the Awaken it brings ends the set; a free line\'s craft '
        'that meets it drops it', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = townGame()..wishSet('knight');
      g.wish('knight', Item.steelSword); // grade II: the knight at Awaken 0 can't take it yet
      final relic = smithyRelics(g).first;
      giveRelicRecipe(g, relic);
      g.wishFreeAdd(relic);
      await frames(tester, 40);
      await shutMessage(tester, b);

      // The Shield ×3 (Orc Tooth 2, Bone Shard 1, Slime Gel 1, 20 gold each): short for three, one can be made.
      await toRow(tester, b, 'knight:shield');
      expect(b.smithyText('wishParts:knight:shield'), 'orcTooth 4/6,boneShard 6/3,slimeGel 5/3,gold 60');
      expect(b.smithyText('wishStatus:knight:shield'), anyOf('${Words.short}: Orc Tooth 2', Words.short));
      expect((b.smithyText('wishCraft:knight:shield'), b.smithyAt('wishGive:knight:shield')), ('', Rect.zero));
      final gold = g.gold; // the troops placed took some
      await tapOn(tester, b.smithyAt('wishCraft:knight:shield'));
      expect(b.message, 'Shield ${Words.crafted}!');
      await shutMessage(tester, b);
      expect((g.inventory[Item.shield], g.materials[Mat.orcTooth], g.materials[Mat.boneShard], g.materials[Mat.slimeGel], g.gold),
          (1, 2, 5, 4, gold - 20));
      // In the Bag now: two still to make, and Give.
      await toRow(tester, b, 'knight:shield');
      expect(b.smithyText('wishParts:knight:shield'), 'orcTooth 2/4,boneShard 5/2,slimeGel 4/2,gold 40');
      expect(b.smithyText('wishGive:knight:shield'), anyOf('${Words.give} to Knight', Words.give));
      expect(b.smithyText('wishGiveWhy:knight:shield'), '');
      await tapOn(tester, b.smithyAt('wishGive:knight:shield'));
      expect((b.bookPage, b.message, g.countOf('knight', Item.shield)), ('smithy', 'Shield given to Knight (1/3)', 1));
      await shutMessage(tester, b);
      expect(b.smithyText('wishLines'), contains('knight:shield ×2'));

      // Refused: no materials, Craft greyed, a tap says why and nothing changes.
      final mats = Map.of(g.materials);
      g.materials.clear();
      await frames(tester, 2);
      await toRow(tester, b, 'knight:shield');
      final why = g.whyNotCraftItem(Item.shield)!.text;
      expect(b.smithyText('wishCraft:knight:shield'), why);
      final before = bags(g);
      await tapOn(tester, b.smithyAt('wishCraft:knight:shield'));
      expect((b.message, bags(g)), (why, before));
      await shutMessage(tester, b);
      g.materials.addAll(mats);

      // A Steel Sword in the Bag: Give greyed with why (grade II opens at Awaken 1), a tap says it, nothing goes on.
      g.inventory[Item.steelSword] = 1;
      await frames(tester, 2);
      await toRow(tester, b, 'knight:steelSword');
      final refusal = g.itemRefusal(Item.steelSword, 'knight', g.whyNot(Item.steelSword, 'knight')!);
      expect(b.smithyText('wishGiveWhy:knight:steelSword'), refusal);
      await tapOn(tester, b.smithyAt('wishGive:knight:steelSword'));
      expect((b.message, g.countOf('knight', Item.steelSword)), (refusal, 0));
      await shutMessage(tester, b);

      // The Amulet in the Bag: nothing to make, "In Bag: 1", Give; given, the wish is met and drops off the tab (the Army
      // detail shows it done until the Awaken).
      g.inventory[Item.amulet] = 1;
      await frames(tester, 2);
      await toRow(tester, b, 'knight:amulet');
      expect((b.smithyText('wishParts:knight:amulet'), b.smithyAt('wishCraft:knight:amulet')), ('', Rect.zero));
      expect(b.smithyText('wishStatus:knight:amulet'), anyOf('In ${Words.bag}: 1', 'In ${Words.bag}'));
      await tapOn(tester, b.smithyAt('wishGive:knight:amulet'));
      expect(b.message, 'Amulet given to Knight (1/1)');
      await shutMessage(tester, b);
      expect(b.smithyText('wishLines'), isNot(contains('knight:amulet')));
      expect(g.wishesOf('knight'), contains(Item.amulet));
      expect(g.wishDone('knight', Item.amulet), isTrue);

      // All but the last Gloves straight onto the type; the last from its row: Awaken 1, and the set ends (the Steel
      // Sword's open wish stays).
      final set = g.gradeSet('knight', 1);
      for (final MapEntry(key: item, value: n) in set.entries) {
        for (var i = g.countOf('knight', item); i < n - (item == Item.gloves ? 1 : 0); i++) {
          g.inventory[item] = (g.inventory[item] ?? 0) + 1;
          expect(g.useItem(item, 'knight'), isTrue, reason: '$item');
        }
      }
      g.inventory[Item.gloves] = 1;
      await frames(tester, 2);
      await toRow(tester, b, 'knight:gloves');
      await tapOn(tester, b.smithyAt('wishGive:knight:gloves'));
      expect(b.message, 'Knight: ${Words.awaken} 1!');
      await shutMessage(tester, b);
      expect(g.itemLevel('knight'), 1);
      expect(g.wishesOf('knight'), [Item.steelSword]);

      // The free relic: its craft meets the line, which drops off.
      await toRow(tester, b, 'free:${relic.name}');
      expect(b.smithyText('wishStatus:free:${relic.name}'), Words.ready);
      await tapOn(tester, b.smithyAt('wishCraft:free:${relic.name}'));
      expect(b.message, craftedLine(relic));
      await shutMessage(tester, b);
      expect(g.wishFree, isEmpty);
      expect(b.smithyText('wishLines'), 'knight:steelSword ×1');
      b.state = Game();
      await frames(tester, 5);
    });
  }

  for (final size in [const Size(1600, 947), const Size(915, 412)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('removing at $tag: a row\'s ✕ takes its wish off, a group\'s Remove its wishes (two taps; the first lapses '
        'after 3 s); none left: where to add them', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = townGame()
        ..wishSet('knight')
        ..wishSet('archer');
      final relic = smithyRelics(g).first;
      g
        ..wishFreeAdd(relic, 2)
        ..wishFreeAdd(Item.steelSword);
      await frames(tester, 40);
      await shutMessage(tester, b);
      final before = bags(g);

      await toRow(tester, b, 'knight:boots');
      await tapOn(tester, b.smithyAt('wishOff:knight:boots'));
      expect(b.message, 'Boots: off Knight\'s ${Words.wishlist.toLowerCase()}');
      await shutMessage(tester, b);
      expect((g.wishesOf('knight').contains(Item.boots), b.smithyText('wishLines')!.contains('knight:boots')), (false, false));
      await toRow(tester, b, 'free:steelSword');
      await tapOn(tester, b.smithyAt('wishOff:free:steelSword'));
      expect(b.message, 'Steel Sword: off the ${Words.wishlist.toLowerCase()}');
      await shutMessage(tester, b);
      expect(g.freeWishes, [relic]);

      // The knight's Remove: armed ("Sure?"), it lapses after 3 s; then two taps clear the group.
      await firstSpread(tester, b);
      expect(b.smithyText('wishOffAll:knight'), Words.remove);
      await tapOn(tester, b.smithyAt('wishOffAll:knight'));
      expect(b.smithyText('wishOffAll:knight'), Words.sure);
      expect(g.wishesOf('knight'), isNotEmpty);
      await frames(tester, 200); // 3.2 s
      expect(b.smithyText('wishOffAll:knight'), Words.remove);
      await tapOn(tester, b.smithyAt('wishOffAll:knight'));
      await tapOn(tester, b.smithyAt('wishOffAll:knight'));
      expect(b.message, 'Knight: ${Words.wishlist.toLowerCase()} cleared');
      await shutMessage(tester, b);
      expect(g.wishlist.keys, ['archer']);
      // The free lines' group, then the archer's.
      await toRow(tester, b, 'free:${relic.name}');
      await tapOn(tester, b.smithyAt('wishOffAll:free'));
      await tapOn(tester, b.smithyAt('wishOffAll:free'));
      expect(b.message, '${Words.forBag}: ${Words.wishlist.toLowerCase()} cleared');
      await shutMessage(tester, b);
      expect(g.wishFree, isEmpty);
      await firstSpread(tester, b);
      await tapOn(tester, b.smithyAt('wishOffAll:archer'));
      await tapOn(tester, b.smithyAt('wishOffAll:archer'));
      await shutMessage(tester, b);
      expect(g.wishlist, isEmpty);
      // None left: where wishes are put on, inside the left page; one spread.
      expect((b.smithyText('wishLines'), b.smithyWishPages), ('', 1));
      expect(b.smithyText('wishEmpty'), startsWith('${Words.noWishes}.'));
      expect(b.smithyText('wishEmpty')!.replaceAll('\n', ' '), contains('Add wishes'), reason: '$tag: the hint shows');
      expect(bags(g), before, reason: '$tag: removing crafts and gives nothing');
      b.state = Game();
      await frames(tester, 5);
    });
  }

  testWidgets('Give from the item page (decisions-log 300): one tap to its one wishing type, the count follows', (tester) async {
    final b = await boot(tester);
    final g = b.state = townGame()..wishSet('knight');
    g.inventory[Item.amulet] = 1;
    await frames(tester, 40);
    await shutMessage(tester, b);
    await tapOn(tester, b.smithyAt('tab:items'));
    while (!b.smithyItemCells.any((c) => c.$1 == Item.amulet)) {
      await tapOn(tester, b.smithyItemPager('on'));
    }
    await tapOn(tester, b.smithyItemCells.firstWhere((c) => c.$1 == Item.amulet).$2);
    expect(b.bagDetailText('title:giveTroops'), '${Words.give} to Knight');
    expect(b.bagDetailText('hint:giveTroops'), '1 in ${Words.bag}. Knight 0/1');
    await tapOn(tester, await seen(tester, b, 'give'));
    expect((b.bookPage, b.message, g.countOf('knight', Item.amulet)), ('smithy', 'Amulet given to Knight (1/1)', 1));
    await shutMessage(tester, b);
    // Met: no longer the Give row's (it opens the Bag as before), and off the Wishlist tab.
    expect(b.bagDetailText('title:giveTroops'), '${Words.give} to troops');
    await tapOn(tester, b.smithyAt('tab:wishlist'));
    expect(b.smithyText('wishLines'), isNot(contains('knight:amulet')));
    b.state = Game();
    await frames(tester, 5);
  });

  for (final size in [const Size(1266, 713), const Size(915, 412)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('a product\'s page at $tag: no types\' chips (decisions-log 303); "-" ×n "+" and "Add to wishlist" put a free '
        'line on with its count; its crafts count down on the Wishlist tab, the one that meets it drops the line; "Remove" '
        'takes one off', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = townGame();
      final relic = smithyRelics(g).first;
      giveRelicRecipe(g, relic, 2);
      await frames(tester, 40);
      await shutMessage(tester, b);
      await tapOn(tester, b.smithyAt('tab:relics'));
      while (!b.smithyCells.any((c) => c.$1 == relic)) {
        await tapOn(tester, b.smithyBoardPager('on'));
      }
      await tapOn(tester, b.smithyCells.firstWhere((c) => c.$1 == relic).$2);
      expect(b.smithyPick, relic);
      expect((b.smithyText('free'), b.smithyText('wishMissing')), ('off ×1', null));
      expect([Words.addToWishlist, Words.add], contains(b.smithyText('freeAdd')), reason: tag);
      await tapOn(tester, await seen(tester, b, 'freeMore'));
      expect(b.smithyText('free'), 'off ×2');
      await tapOn(tester, await seen(tester, b, 'freeLess'));
      await tapOn(tester, await seen(tester, b, 'freeLess'));
      expect(b.smithyText('free'), 'off ×1', reason: '$tag: "-" stops at one');
      await tapOn(tester, await seen(tester, b, 'freeMore'));
      expect(g.wishFree, isEmpty, reason: 'nothing on until "Add"');
      await tapOn(tester, await seen(tester, b, 'freeAdd'));
      expect(b.message, '${relicNames[relic]} ×2: on the ${Words.wishlist.toLowerCase()}');
      await shutMessage(tester, b);
      expect((g.freeGoal(relic), b.smithyText('free'), b.smithyText('freeAdd')), (2, 'on ×2', Words.remove));
      expect(b.smithyMarks(relic)!.wished, isTrue, reason: '$tag: its star on the Relics board');
      expect(b.smithyText('wishMissing'), Words.readyToCraft, reason: '$tag: wished, its status');
      // On it, "+" asks one more and "-" one fewer, never under one.
      await tapOn(tester, await seen(tester, b, 'freeMore'));
      expect((g.freeGoal(relic), b.smithyText('free')), (3, 'on ×3'));
      await tapOn(tester, await seen(tester, b, 'freeLess'));
      expect(g.freeGoal(relic), 2);

      // Its crafts count down on the Wishlist tab; the one that meets it drops the line.
      await tapOn(tester, await seen(tester, b, 'craft'));
      await shutMessage(tester, b);
      expect((g.freeCount(relic), b.smithyText('free')), ((1, 2), 'on ×1'));
      await tapOn(tester, b.smithyAt('tab:wishlist'));
      expect(b.smithyText('wishLines'), 'free:${relic.name} ×1');
      await tapOn(tester, b.smithyAt('tab:relics'));
      await tapOn(tester, await seen(tester, b, 'craft'));
      await shutMessage(tester, b);
      expect(g.wishFree, isEmpty, reason: '$tag: met, it drops off');
      expect((b.smithyText('free'), b.smithyMarks(relic)!.wished), ('off ×1', false));
      await tapOn(tester, b.smithyAt('tab:wishlist'));
      expect(b.smithyText('wishLines'), '');

      // An item's page: no types' chips, no "Wishlist: …"; its free line on, then "Remove".
      await tapOn(tester, b.smithyAt('tab:items'));
      while (!b.smithyItemCells.any((c) => c.$1 == Item.steelSword)) {
        await tapOn(tester, b.smithyItemPager('on'));
      }
      await tapOn(tester, b.smithyItemCells.firstWhere((c) => c.$1 == Item.steelSword).$2);
      for (final t in troopTypes.keys) {
        expect(b.smithyAt('wish:$t'), Rect.zero, reason: '$tag: no $t chip');
      }
      expect((b.smithyText('wishlist'), b.smithyText('wishTypes')), (null, null));
      await tapOn(tester, await seen(tester, b, 'freeAdd'));
      expect((g.freeGoal(Item.steelSword), b.smithyItemMarks(Item.steelSword)!.wished), (1, true));
      await shutMessage(tester, b);
      await tapOn(tester, await seen(tester, b, 'freeAdd'));
      expect(b.message, 'Steel Sword: off the ${Words.wishlist.toLowerCase()}');
      expect(g.wishFree, isEmpty);
      b.state = Game();
      await frames(tester, 5);
    });
  }

  for (final size in [const Size(1266, 713), const Size(915, 412)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('the Bag at $tag (decisions-log 303): an item\'s and a small relic\'s page have the free line ("-" ×n "+", '
        '"Add to wishlist", then "Remove") over their rows; a material\'s none; the Wishlist tab lists it', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = townGame();
      final relic = smithyRelics(g).first;
      g
        ..inventory[Item.amulet] = 1
        ..relicBag[relic] = 1;
      await frames(tester, 40);
      await shutMessage(tester, b);
      await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2, 'the Bag');
      await tapOn(tester, b.bagChip(BagCategory.items));
      await tapOn(tester, b.bagCells.firstWhere((c) => c.$1 == Item.amulet).$2);
      final (_, right) = b.bookPages;
      expect((b.bagDetailText('name'), b.bagDetailText('free')), ('Amulet', 'off ×1'));
      final add = b.bagDetail('freeAdd');
      expect(inside(add, right), isTrue, reason: '$tag $add');
      expect(b.bagAction(BagAction.giveTroops).top, greaterThanOrEqualTo(add.bottom), reason: '$tag: over the rows');
      await tapOn(tester, b.bagDetail('freeMore'));
      expect(b.bagDetailText('free'), 'off ×2');
      await tapOn(tester, b.bagDetail('freeAdd'));
      expect(b.message, 'Amulet ×2: on the ${Words.wishlist.toLowerCase()}');
      await shutMessage(tester, b);
      expect((g.freeGoal(Item.amulet), b.bagDetailText('free'), b.bagDetailText('freeAdd')), (3, 'on ×2', Words.remove));
      // A small relic's page too.
      await tapOn(tester, b.bagChip(BagCategory.relics));
      await tapOn(tester, b.bagCells.firstWhere((c) => c.$1 == relic).$2);
      await tapOn(tester, b.bagDetail('freeAdd'));
      await shutMessage(tester, b);
      expect(g.freeGoal(relic), 2);
      // A material's: none.
      g.matsSeen.add(Mat.boneShard);
      await tapOn(tester, b.bagChip(BagCategory.materials));
      await tapOn(tester, b.bagCells.firstWhere((c) => c.$1 == Mat.boneShard).$2);
      expect(b.bagDetail('freeAdd'), Rect.zero);
      // Both on the Wishlist tab, then the amulet's off from the Bag again.
      await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'smithy').$2, 'the Smithy');
      await tapOn(tester, b.smithyAt('tab:wishlist'));
      expect(b.smithyText('wishLines'), 'free:amulet ×2|free:${relic.name} ×1');
      await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2, 'the Bag');
      await tapOn(tester, b.bagChip(BagCategory.items));
      await tapOn(tester, b.bagCells.firstWhere((c) => c.$1 == Item.amulet).$2);
      await tapOn(tester, b.bagDetail('freeAdd'));
      expect(b.message, 'Amulet: off the ${Words.wishlist.toLowerCase()}');
      expect(g.freeWishes, [relic]);
      b.state = Game();
      await frames(tester, 5);
    });
  }

  for (final size in [const Size(1266, 713), const Size(915, 412)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets('the Army detail at $tag: "Wishlist all" by the Awaken needs puts the set on, "Remove set" takes it off; a '
        'needs row\'s "+" wishes its item with its count where the row has room', (tester) async {
      final b = await boot(tester, size);
      final g = b.state = townGame()..leaveTown();
      await frames(tester, 40);
      await shutMessage(tester, b);
      await tapOn(tester, b.troopRow('soldier'));
      Future<Rect> detailSeen(String key) async {
        b.troopDetailScroll = 0;
        await frames(tester, 2);
        for (var i = 0; i < 80; i++) {
          final r = b.troopDetail(key);
          if (r != Rect.zero && r.bottom < b.troopDetailBody.bottom - 1) return r;
          final was = b.troopDetailScroll;
          b.troopDetailScroll = was + 16;
          await frames(tester, 2);
          if (b.troopDetailScroll == was) break;
        }
        return b.troopDetail(key);
      }

      // The "+" on a needs row, where its words still fit beside it: the item on the soldier's wishes with the set's count.
      final set = g.gradeSet('soldier', 1);
      final pluses = [
        for (final item in set.keys)
          if (await detailSeen('wishOne:${item.name}') case final r when r != Rect.zero) (item, r),
      ];
      if (size.width >= 1266) expect(pluses, isNotEmpty, reason: '$tag: room for the "+"');
      for (final (_, r) in pluses) {
        expect(inside(r, b.bookPages.$2), isTrue, reason: '$tag $r');
      }
      if (pluses.isNotEmpty) {
        final (item, _) = pluses.first;
        await tapOn(tester, await detailSeen('wishOne:${item.name}'));
        expect(b.message, '${itemNames[item]} ×${set[item]}: on Soldier\'s ${Words.wishlist.toLowerCase()}');
        await shutMessage(tester, b);
        expect((g.wishGoal('soldier', item), await detailSeen('wishOne:${item.name}')), (set[item], Rect.zero), reason: '$tag: wished, no "+"');
        g.unwish('soldier', item);
      }

      final all = await detailSeen('wishAll');
      expect(inside(all, b.bookPages.$2), isTrue, reason: '$tag $all');
      expect(b.troopDetailWords('wishAll'), [Words.wishAll]);
      await tapOn(tester, all);
      expect(b.message, 'Soldier: ${Words.awaken} 1 set on the ${Words.wishlist.toLowerCase()}');
      await shutMessage(tester, b);
      expect(g.wishesOf('soldier'), set.keys);
      await detailSeen('wishAll');
      expect(b.troopDetailWords('wishAll'), [Words.removeSet]);
      expect(await detailSeen('wish:sword'), isNot(Rect.zero), reason: '$tag: the set in the Wishlist section');
      for (final item in set.keys) {
        expect(b.troopDetail('wishOne:${item.name}'), Rect.zero, reason: '$tag $item: wished, no "+"');
      }
      await tapOn(tester, await detailSeen('wishAll'));
      expect(b.message, 'Soldier: ${Words.awaken} 1 set off the ${Words.wishlist.toLowerCase()}');
      expect(g.wishlist, isEmpty);
      b.state = Game();
      await frames(tester, 5);
    });
  }

  testWidgets('the materials\' star: in the Bag\'s Materials and the Shop\'s Buy (decisions-log 300), a free relic\'s too (302)',
      (tester) async {
    final b = await boot(tester);
    final g = b.state = townGame()..wish('knight', Item.steelSword);
    g.matsSeen.addAll([Mat.wolfClaw, Mat.orcEar, Mat.slimeGel]);
    await frames(tester, 40);
    await shutMessage(tester, b);
    await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2, 'the Bag');
    await tapOn(tester, b.bagChip(BagCategory.materials));
    expect(b.bagCells, isNotEmpty);
    for (final (kind, _) in b.bagCells) {
      expect(b.bagMarks(kind)!.wished, kind == Mat.wolfClaw || kind == Mat.orcEar, reason: 'Bag $kind');
    }
    await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'store').$2, 'the Shop');
    expect(b.bagCells, isNotEmpty);
    for (final (kind, _) in b.bagCells) {
      expect(b.bagMarks(kind)!.wished, kind == Mat.wolfClaw || kind == Mat.orcEar, reason: 'Shop $kind');
    }
    // Met (the knight holds its one): no star.
    g.upgrades['knight'] = [Item.steelSword];
    await frames(tester, 2);
    expect([for (final (kind, _) in b.bagCells) if (b.bagMarks(kind)!.wished) kind], isEmpty);
    // A free relic's materials: starred in the Bag's Materials.
    final relic = smithyRelics(g).first, takes = g.craftRecipe(relic)!.materials.keys.toSet();
    g.wishFreeAdd(relic);
    g.matsSeen.addAll(takes);
    for (final m in takes) {
      g.materials[m] = (g.materials[m] ?? 0) + 1;
    }
    await tapOn(tester, b.bookTabs.firstWhere((t) => t.$1 == 'bag').$2, 'the Bag');
    await tapOn(tester, b.bagChip(BagCategory.materials));
    for (final (kind, _) in b.bagCells) {
      expect(b.bagMarks(kind)!.wished, takes.contains(kind), reason: 'Bag $kind for $relic');
    }
    b.state = Game();
    await frames(tester, 5);
  });
}
