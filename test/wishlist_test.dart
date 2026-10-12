// The Wishlist's rules (decisions-log 282, 300; lib/wishlist.dart; docs/loot-items-relics.md "The Wishlist"): who can wish
// for what (a troop type's products the Smithy makes: by grade its Awaken kinds in every grade, the Cap and the Ring), the
// wishes per type in the order put on, once each, one list whoever edits it, each with how many the type is to hold (its
// have read live); a type's whole next Awaken in one go, on and off; a wish met shown done until the type's Awaken drops
// it (a Cap's or a Ring's at once); the Items board's order (open wishes first in their grade); what a wish still lacks
// and the materials the open wishes take; the save's `wishlist` (a round trip with the counts, a 282 save's lists as
// held + 1, an old save without it, unknown names skipped, no key with nothing wished or the Towns off); free lines
// (decisions-log 302: any item or relic the Smithy makes, for the Bag to hold a count of it; met by a craft or on leaving
// the Town, it drops off; its recipe's parts for the rest; the save's `free`); and nothing crafts or gives by itself. No game is ever drawn here: the pages are wishlist_ui_test.dart's.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show smithyItemOrder, smithyRelics;

/// A board game with the forge on (the Towns on, as every board game), a soldier, a knight, an archer and a priest
/// placed; [inTown]: in the Town before wave 21.
Game forgeGame({bool inTown = false}) {
  final g = Game(Random(1), Random(2)).boardRules()
    ..townDice = Random(3)
    ..towns = true
    ..armyMax = null
    ..wave = 20;
  for (final type in ['soldier', 'knight', 'archer', 'priest']) {
    g.autoPlace(type);
  }
  if (inTown) {
    g
      ..townAt = 21
      ..inTown = true;
  }
  return g;
}

/// [g] through a save and back, as the launch reads it.
Game reload(Game g) => Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>, Random(1), Random(2))..boardRules();

/// What a craft or a gift would change in [g], written out.
String bags(Game g) => '${g.materials} ${g.inventory} ${g.gold} ${g.upgrades} ${g.relicBag}';

/// The grade's items in [Item] order.
List<Item> gradeItems(int grade) => [for (final i in Item.values) if (i.grade == grade) i];

void main() {
  test('who can wish for what: a type\'s Awaken kinds in every grade, the Cap and the Ring; only with the forge', () {
    final g = forgeGame();
    final kinds = {ItemSlot.sword, ItemSlot.shield, ItemSlot.boots, ItemSlot.gloves, ItemSlot.amulet, ItemSlot.helm, ItemSlot.ring};
    expect(g.wishable('knight'), [for (final i in Item.values) if (kinds.contains(i.slot)) i], reason: 'the knight\'s 7 kinds, Item order');
    expect(g.wishable('knight'), hasLength(21));
    expect([for (final i in [Item.steelSword, Item.royalShield, Item.leatherCap, Item.royalRing, Item.bow, Item.staff, Item.torch]) g.canWish('knight', i)],
        [true, true, true, true, false, false, false]);
    expect(g.canWish('priest', Item.saintBeads), isTrue, reason: 'the priest\'s own kind');
    expect(g.canWish('priest', Item.sword), isFalse);
    expect(g.wishable('lancer').where((i) => i.slot == ItemSlot.spear), [Item.spear, Item.wingedSpear, Item.royalSpear]);
    // Every type can wish for something, and every product suits some type.
    for (final type in troopTypes.keys) {
      expect(g.wishable(type), isNotEmpty, reason: type);
    }
    for (final item in Item.values) {
      expect(troopTypes.keys.any((t) => g.canWish(t, item)), isTrue, reason: '$item');
    }
    expect(g.canWish('slime', Item.sword), isFalse, reason: 'not a troop type');
  });

  test('wish, unwish, toggle: one list per type, in the order put on, once each', () {
    final g = forgeGame();
    expect(g.wish('knight', Item.steelSword), isTrue);
    expect(g.wish('knight', Item.steelSword), isFalse, reason: 'once');
    expect(g.wish('knight', Item.bow), isFalse, reason: 'not for a knight');
    expect(g.wish('knight', Item.leatherCap), isTrue);
    expect(g.wish('archer', Item.steelSword), isTrue);
    expect(g.wishesOf('knight'), [Item.steelSword, Item.leatherCap]);
    expect(g.wishersOf(Item.steelSword), ['knight', 'archer']);
    expect((g.wished(Item.steelSword), g.wished(Item.leatherCap), g.wished(Item.sword)), (true, true, false));
    expect(g.wishedItems, [Item.steelSword, Item.leatherCap], reason: 'Item order, once each');

    expect(g.unwish('knight', Item.steelSword), isTrue);
    expect(g.unwish('knight', Item.steelSword), isFalse, reason: 'not on it any more');
    expect(g.wishesOf('knight'), [Item.leatherCap]);
    expect(g.wishersOf(Item.steelSword), ['archer']);
    expect(g.toggleWish('knight', Item.leatherCap), isFalse, reason: 'off');
    expect(g.wishlist.containsKey('knight'), isFalse, reason: 'the last wish leaves no entry');
    expect(g.toggleWish('knight', Item.royalSword), isTrue, reason: 'on');
    expect(g.toggleWish('knight', Item.staff), isFalse, reason: 'a staff never goes on a knight\'s');
    expect(g.wishlist, {
      'archer': {Item.steelSword: 1},
      'knight': {Item.royalSword: 1},
    }, reason: 'each to hold one more than the type holds');
  });

  test('how many: a wish is for the type to hold a count, its have read live from the type (decisions-log 300)', () {
    final g = forgeGame();
    g.upgrades['knight'] = [Item.sword];
    expect(g.wish('knight', Item.sword), isTrue);
    expect((g.wishGoal('knight', Item.sword), g.wishCount('knight', Item.sword), g.wishDone('knight', Item.sword)), (2, (1, 2), false),
        reason: 'one more than it holds');
    expect(g.wish('archer', Item.sword, 3), isTrue);
    expect(g.wishCount('archer', Item.sword), (0, 3));
    expect((g.wishGoal('priest', Item.sword), g.wishCount('priest', Item.sword), g.wishDone('priest', Item.sword)), (null, null, false));
    // Given any way (here straight onto the type): the count follows, never past the need.
    g.upgrades['knight'] = [Item.sword, Item.sword, Item.sword];
    expect((g.wishCount('knight', Item.sword), g.wishDone('knight', Item.sword)), ((2, 2), true));
    // A done wish stays on the list (shown done) but is no longer open: no star, no materials, not the Give row's.
    expect(g.wishesOf('knight'), [Item.sword]);
    expect(g.wishersOf(Item.sword), ['knight', 'archer']);
    expect(g.openWishersOf(Item.sword), ['archer']);
    expect(g.wished(Item.sword), isTrue, reason: 'the archer\'s is open');
    g.unwish('archer', Item.sword);
    expect(g.wished(Item.sword), isFalse);
    expect(g.wishedItems, isEmpty);
    expect(g.wishMats, isEmpty);
  });

  test('a whole set: every item the next Awaken lacks with its count, in one go; off again; none at the top', () {
    final g = forgeGame();
    g.upgrades['knight'] = [Item.sword];
    g.wish('knight', Item.royalHelm);
    g.wish('knight', Item.shield); // one more than it holds: 1, under the set's 3
    // The knight's Awaken 1 takes Sword 3, Shield 3, Boots 2, Gloves 2, Amulet 1 (loot-items-relics.md's table).
    expect(g.gradeSet('knight', 1), {Item.sword: 3, Item.shield: 3, Item.boots: 2, Item.gloves: 2, Item.amulet: 1});
    expect(g.wishSetOf('knight'), {Item.sword: 3, Item.shield: 3, Item.boots: 2, Item.gloves: 2, Item.amulet: 1});
    expect(g.setWished('knight'), isFalse);
    expect(g.wishSet('knight'), isTrue);
    expect(g.setWished('knight'), isTrue);
    expect(g.wishesOf('knight'), [Item.royalHelm, Item.shield, Item.sword, Item.boots, Item.gloves, Item.amulet],
        reason: 'a wish already on keeps its place, the rest go on last in the set\'s order');
    expect({for (final i in g.wishesOf('knight')) i: g.wishCount('knight', i)}, {
      Item.royalHelm: (0, 1),
      Item.shield: (0, 3),
      Item.sword: (1, 3),
      Item.boots: (0, 2),
      Item.gloves: (0, 2),
      Item.amulet: (0, 1),
    });
    expect(g.wishSet('knight'), isTrue, reason: 'again: nothing changes');
    expect(g.wishesOf('knight'), hasLength(6));
    // A kind it already holds in full is not in the set.
    g.upgrades['archer'] = [Item.sword, Item.sword];
    expect(g.wishSetOf('archer').containsKey(Item.sword), isFalse);
    expect(g.wishSetOf('archer').keys, [Item.boots, Item.bow, Item.gloves, Item.torch]);

    // Off: the set's items go, the other wishes stay.
    expect(g.unwishSet('knight'), isTrue);
    expect(g.wishesOf('knight'), [Item.royalHelm]);
    expect(g.unwishSet('knight'), isFalse, reason: 'none of it on');
    expect(g.unwishAll('knight'), isTrue);
    expect((g.wishlist.containsKey('knight'), g.unwishAll('knight')), (false, false));

    // At the top (every grade set held): no set.
    g.upgrades['soldier'] = [for (var l = 1; l <= maxAwaken; l++) for (final e in g.gradeSet('soldier', l).entries) ...List.filled(e.value, e.key)];
    expect(g.itemLevel('soldier'), maxAwaken);
    expect(g.wishSetOf('soldier'), isEmpty);
    expect((g.wishSet('soldier'), g.setWished('soldier')), (false, false));
  });

  test('done: a wish met shows done until the type\'s Awaken drops it; a Cap\'s or a Ring\'s drops at once', () {
    final g = forgeGame()..wishSet('knight');
    g.wish('knight', Item.leatherCap);
    g.wish('knight', Item.royalHelm); // grade III: not open yet, stays open through the Awaken
    final set = g.gradeSet('knight', 1);
    for (final MapEntry(key: item, value: n) in set.entries) {
      g.inventory[item] = n;
    }
    g.inventory[Item.leatherCap] = 1;
    expect(g.useItem(Item.leatherCap, 'knight'), isTrue);
    expect(g.wishesOf('knight').contains(Item.leatherCap), isFalse, reason: 'a Cap met: off at once');
    // Every item but the last Gloves: each met one stays, shown done.
    for (final MapEntry(key: item, value: n) in set.entries) {
      for (var i = 0; i < n - (item == Item.gloves ? 1 : 0); i++) {
        expect(g.useItem(item, 'knight'), isTrue, reason: '$item');
      }
    }
    expect(g.itemLevel('knight'), 0);
    expect([for (final i in g.wishesOf('knight')) (i, g.wishDone('knight', i))], [
      (Item.sword, true),
      (Item.shield, true),
      (Item.boots, true),
      (Item.gloves, false),
      (Item.amulet, true),
      (Item.royalHelm, false),
    ]);
    // The last one brings Awaken 1: the set's wishes drop off, the open one stays.
    expect(g.useItem(Item.gloves, 'knight'), isTrue);
    expect(g.itemLevel('knight'), 1);
    expect(g.wishesOf('knight'), [Item.royalHelm]);
    expect(g.wishSetOf('knight').keys.every((i) => i.grade == 2), isTrue, reason: 'no roll-on: Awaken 2\'s set is the next one to add');
  });

  test('the Items board: wished items first in their grade, each part in Item order', () {
    final g = forgeGame(inTown: true);
    for (final n in [1, 2, 3]) {
      expect(smithyItemOrder(g, n), gradeItems(n), reason: 'grade $n, nothing wished');
    }
    g
      ..wish('knight', Item.steelGloves)
      ..wish('archer', Item.longBow)
      ..wish('knight', Item.royalSword)
      ..wish('priest', Item.steelGloves);
    expect(smithyItemOrder(g, 2), [Item.longBow, Item.steelGloves, ...gradeItems(2).where((i) => i != Item.longBow && i != Item.steelGloves)]);
    expect(smithyItemOrder(g, 3), [Item.royalSword, ...gradeItems(3).where((i) => i != Item.royalSword)]);
    expect(smithyItemOrder(g, 1), gradeItems(1));
  });

  test('what a wish still lacks, and the materials the wishes take', () {
    final g = forgeGame()..gold = 0;
    final r = g.itemRecipe(Item.steelSword)!;
    expect(r.materials, {Mat.wolfClaw: 2, Mat.orcEar: 1});
    expect((r.items.isEmpty, r.gold), (true, 60));
    g.materials[Mat.wolfClaw] = 1;
    expect([for (final s in g.wishShort(Item.steelSword)) (s.kind, s.have, s.need)], [(Mat.wolfClaw, 1, 2), (Mat.orcEar, 0, 1), (null, 0, 60)]);
    g
      ..materials.addAll({Mat.wolfClaw: 2, Mat.orcEar: 1})
      ..gold = 60;
    expect(g.wishShort(Item.steelSword), isEmpty);
    expect(g.canMake(Item.steelSword), 1);
    // A Steel Helm takes its grade below too: the Leather Cap is what it lacks.
    expect(g.wishShort(Item.steelHelm).map((s) => s.kind), contains(Item.leatherCap));

    expect(g.wishMats, isEmpty);
    g.wish('knight', Item.steelSword);
    expect(g.wishMats, {Mat.wolfClaw, Mat.orcEar});
    g.wish('priest', Item.towerShield);
    expect(g.wishMats, {Mat.wolfClaw, Mat.orcEar, ...g.itemRecipe(Item.towerShield)!.materials.keys});
    g.unwish('knight', Item.steelSword);
    expect(g.wishMats, g.itemRecipe(Item.towerShield)!.materials.keys.toSet());
  });

  test('the rows (decisions-log 303): one per open wish, the types\' then the free lines; how many still wanted and to '
      'make (a type\'s less what the Bag holds), the parts for them, what they lack; a met wish none', () {
    final g = forgeGame()..gold = 100;
    expect(g.wishRows, isEmpty);
    final sword = g.itemRecipe(Item.sword)!;
    g
      ..materials.addAll(sword.materials) // enough for one Sword
      ..inventory[Item.sword] = 1
      ..wish('knight', Item.sword, 3);
    expect(g.wishFreeAdd(Item.steelSword), isTrue);
    String said(WishRow r) => '${r.type ?? 'free'}:${r.kind.name} ×${r.need} make ${r.make}: '
        '${[for (final p in r.parts) '${p.kind?.name ?? 'gold'} ${p.have}/${p.need}'].join(',')}';
    String rowOf(String key, Item item, int need, int make) => '$key ×$need make $make: '
        '${[for (final p in g.itemCraftRows(item)) '${p.kind?.name ?? 'gold'} ${p.have}/${p.need * make}'].join(',')}';
    // The knight's three Swords: two to make (the Bag holds one), each part twice; the free Steel Sword: one.
    expect(g.wishRows.map(said), [rowOf('knight:sword', Item.sword, 3, 2), rowOf('free:steelSword', Item.steelSword, 1, 1)]);
    // Short for the second Sword by one Sword's materials (the gold pays); the Steel Sword by its Wolf Claw and Orc Ear.
    expect(g.wishRowShort(g.wishRows.first), [for (final MapEntry(key: m, value: n) in sword.materials.entries) (m, n)]);
    expect(g.wishRowShort(g.wishRows.last), [(Mat.wolfClaw, 2), (Mat.orcEar, 1)]);
    // The Bag's Sword given: two still wanted, two to make.
    expect(g.useItem(Item.sword, 'knight'), isTrue);
    expect(said(g.wishRows.first), rowOf('knight:sword', Item.sword, 2, 2));
    // Met: no row (the wish stays, done, until the Awaken).
    g.inventory[Item.sword] = 2;
    expect((g.useItem(Item.sword, 'knight'), g.useItem(Item.sword, 'knight')), (true, true));
    expect(g.wishRows.map((r) => r.type), [null]);
    expect(g.wishesOf('knight'), [Item.sword]);
    // The free lines' group off at once.
    expect((g.unwishFreeAll(), g.unwishFreeAll()), (true, false));
    expect(g.wishRows, isEmpty);
  });

  test('the save: `wishlist` round trip in order; none without a wish or with the forge off; an old save has none', () {
    final g = forgeGame()
      ..wish('knight', Item.royalSword)
      ..wish('knight', Item.leatherCap)
      ..wish('priest', Item.prayerBeads);
    final j = g.toJson();
    g.wishSet('archer');
    expect(j['wishlist'], {
      'knight': {'royalSword': 1, 'leatherCap': 1},
      'priest': {'prayerBeads': 1},
    });
    expect((g.toJson()['wishlist'] as Map)['archer'], {'sword': 2, 'boots': 1, 'bow': 4, 'gloves': 3, 'torch': 1}, reason: 'a set with its counts');
    final back = reload(g);
    expect(back.wishlist, {
      'knight': {Item.royalSword: 1, Item.leatherCap: 1},
      'priest': {Item.prayerBeads: 1},
      'archer': {Item.sword: 2, Item.boots: 1, Item.bow: 4, Item.gloves: 3, Item.torch: 1},
    });
    expect(back.wishesOf('archer'), [Item.sword, Item.boots, Item.bow, Item.gloves, Item.torch], reason: 'in order');
    expect(reload(back).toJson()['wishlist'], g.toJson()['wishlist'], reason: 'the same again');

    // Nothing wished: no key, so a save without one is unchanged (the w89 dump too).
    expect(forgeGame().toJson().containsKey('wishlist'), isFalse);
    // An old save (no key) loads with an empty Wishlist.
    final old = jsonDecode(jsonEncode(forgeGame().toJson())) as Map<String, dynamic>..remove('wishlist');
    expect((Game.fromJson(old)..boardRules()).wishlist, isEmpty);
    // A name this build doesn't know, a type that isn't a troop type, an item twice: skipped, kept once.
    final odd = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>
      ..['wishlist'] = {
        'knight': ['royalSword', 'mysterySword', 'royalSword', 'leatherCap'],
        'slime': ['sword'],
        'archer': ['nothing'],
      };
    expect(Game.fromJson(odd).wishlist, {
      'knight': {Item.royalSword: 1, Item.leatherCap: 1},
    }, reason: 'a 282 save\'s list: each to hold one more than the type holds');
    // A 282 save's list for a type that holds some: one more than it holds, as it was wished.
    final held = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>
      ..['upgrades'] = {'knight': ['sword', 'sword']}
      ..['wishlist'] = {'knight': ['sword', 'steelSword']};
    expect(Game.fromJson(held).wishlist, {'knight': {Item.sword: 3, Item.steelSword: 1}});
    // Goals: an unknown name, a goal under 1, a goal that isn't a number: skipped.
    final goals = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>
      ..['wishlist'] = {
        'knight': {'royalSword': 2, 'mysterySword': 1, 'leatherCap': 0, 'steelSword': 'x'},
        'slime': {'sword': 1},
      };
    expect(Game.fromJson(goals).wishlist, {'knight': {Item.royalSword: 2}});
    // The Towns off (tests only) write none (their game has no Wishlist).
    g.towns = false;
    expect(g.toJson().containsKey('wishlist'), isFalse);
    expect(Game.saveVersion, 3, reason: 'an added key, its value read in both shapes: no new format');
  });

  test('free lines (decisions-log 302): any item or relic the Smithy makes, for the Bag to hold a count; met by a craft, or '
      'on leaving the Town, it drops off; its recipe\'s parts for the rest', () {
    final g = forgeGame(inTown: true)..gold = 40000;
    final relic = smithyRelics(g).first;
    expect((g.canWishFree(Item.steelSword), g.canWishFree(relic), g.canWishFree(Mat.wolfClaw)), (true, true, false));
    // On for two more than the Bag holds, once; its have read live.
    g.inventory[Item.steelSword] = 1;
    expect(g.wishFreeAdd(Item.steelSword, 2), isTrue);
    expect((g.wishFreeAdd(Item.steelSword), g.freeGoal(Item.steelSword), g.freeCount(Item.steelSword)), (false, 3, (1, 3)));
    expect(g.wishFreeAdd(relic), isTrue);
    expect(g.freeWishes, [Item.steelSword, relic]);
    expect((g.wished(Item.steelSword), g.freeWished(relic)), (true, true));
    expect(g.wishedItems, [Item.steelSword]);
    // "-" and "+": never under one more than the Bag holds; none without a line.
    expect([g.wishFreeMore(relic, 1), g.wishFreeMore(relic, -5), g.wishFreeMore(Item.bow, 1)], [2, 1, null]);
    // Its parts: the recipe's materials, then its items, each for the rest of the line.
    final r = g.craftRecipe(relic)!, m = r.materials.keys.first;
    expect(g.freeParts(relic), [...r.materials.keys, ...r.items.keys]);
    g.materials[m] = 1;
    expect(g.freeNeed(relic, m), (min(1, r.materials[m]!), r.materials[m]!));
    // The materials the free lines take, the relic's with the Steel Sword's.
    expect(g.wishMats, containsAll([...r.materials.keys, ...g.itemRecipe(Item.steelSword)!.materials.keys]));
    // Off; on again for one; off.
    expect((g.unwishFree(relic), g.unwishFree(relic), g.toggleFree(relic), g.freeGoal(relic)), (true, false, true, 1));
    expect(g.toggleFree(relic), isFalse);
    expect(g.freeWishes, [Item.steelSword]);
    // Met by a craft: it drops off at the craft that meets it.
    final sword = g.itemRecipe(Item.steelSword)!;
    for (final MapEntry(key: m, value: n) in sword.materials.entries) {
      g.materials[m] = (g.materials[m] ?? 0) + 2 * n;
    }
    for (final MapEntry(key: i, value: n) in sword.items.entries) {
      g.inventory[i] = (g.inventory[i] ?? 0) + 2 * n;
    }
    expect(g.craftItem(Item.steelSword), isTrue);
    expect(g.freeCount(Item.steelSword), (2, 3));
    expect(g.craftItem(Item.steelSword), isTrue);
    expect(g.wishFree, isEmpty, reason: 'met: dropped');
    // Met another way (a chest's relic): none at once, dropped when the Town is left.
    g.wishFreeAdd(relic);
    g.relicBag[relic] = (g.relicBag[relic] ?? 0) + 1;
    expect(g.freeWishes, isEmpty);
    expect(g.wishFree, hasLength(1));
    g.leaveTown();
    expect(g.wishFree, isEmpty);
  });

  test('the save\'s free lines (decisions-log 302): under `wishlist`, by name in order with their goals, read back; unknown '
      'names and goals under 1 skipped; a met line not saved', () {
    final g = forgeGame();
    final relic = smithyRelics(g).first;
    g
      ..wishFreeAdd(relic, 2)
      ..wishFreeAdd(Item.steelSword);
    expect(g.toJson()['wishlist'], {'free': {relic.name: 2, 'steelSword': 1}});
    final back = reload(g);
    expect(back.wishFree, {relic: 2, Item.steelSword: 1});
    expect(back.freeWishes, [relic, Item.steelSword]);
    // With a type's wishes beside them.
    g.wish('knight', Item.sword);
    expect(reload(g).wishlist, {'knight': {Item.sword: 1}});
    expect(reload(g).wishFree, {relic: 2, Item.steelSword: 1});
    // Unknown names and goals under 1 skipped.
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    (j['wishlist'] as Map)['free'] = {'nothing': 2, 'steelSword': 0, relic.name: 3};
    expect((Game.fromJson(j, Random(1), Random(2))..boardRules()).wishFree, {relic: 3});
    // A met line isn't saved; with none at all, no key.
    g
      ..unwishAll('knight')
      ..inventory[Item.steelSword] = 1;
    expect(g.toJson()['wishlist'], {'free': {relic.name: 2}});
    g.unwishFree(relic);
    expect(g.toJson().containsKey('wishlist'), isFalse);
  });

  test('nothing crafts or gives by itself: a wish changes no bag, in a Town or not, while the game runs', () {
    final g = forgeGame(inTown: true)..gold = 1000;
    g.materials.addAll({Mat.wolfClaw: 4, Mat.orcEar: 2});
    final before = bags(g);
    for (final type in ['soldier', 'knight', 'archer']) {
      expect(g.wish(type, Item.steelSword), isTrue);
    }
    g.wish('knight', Item.leatherCap);
    expect(g.canCraftItem(Item.steelSword), isTrue, reason: 'it could be crafted now');
    for (var i = 0; i < 60; i++) {
      g.tick(0.05);
    }
    expect(bags(g), before, reason: 'no craft, no gift: the player\'s');
    g.leaveTown();
    for (var i = 0; i < 60; i++) {
      g.tick(0.05);
    }
    expect(bags(g), before);
    // Crafting one still takes a press, and the wish stays on the list after it.
    expect(g.craftItem(Item.steelSword), isFalse, reason: 'out of a Town');
    g
      ..townAt = 21
      ..inTown = true;
    expect(g.craftItem(Item.steelSword), isTrue);
    expect(g.inventory[Item.steelSword], 1);
    expect(g.wishersOf(Item.steelSword), ['soldier', 'knight', 'archer']);
  });
}
