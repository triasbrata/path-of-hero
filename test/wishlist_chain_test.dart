// The Wishlist's ingredient wishes (decisions-log 323; lib/wishlist.dart's WishPart; docs/loot-items-relics.md "The
// Wishlist"): the owner, 2026-10-12, "kalau user whitelist item yang item untuk forgenya ada item yang perlu di forge dulu
// maka item itu juga akan langsung ke whitelist". Which recipes take a forged product; a wish put on puts its ingredients
// on, recursively (one level: a relic's item; two: the Royal Ring's Gem Ring and Ring), from a type's wish, a set and a
// free line; their counts read live (the recipe's count for each of the parent still to make, less the Bag's); two
// parents' counts add up; their rows name the product they are for and no troop; taken off with their parent (by a tap,
// or met: "Ikut terhapus"), the player's own wish for the same product kept apart; the save's `parts` (a round trip, an
// old save's wishes chained as now, unknown names and lost parents skipped). No game is ever drawn here: the pages are
// smithy_wish_ui_test.dart's.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show smithyItemOrder;

/// A board game, a soldier, a knight, an archer and a priest placed; [inTown]: in the Town before wave 21, 40,000 gold.
Game forgeGame({bool inTown = false}) {
  final g = Game(Random(1), Random(2)).boardRules()
    ..townDice = Random(3)
    ..armyMax = null
    ..wave = 20
    ..gold = 40000;
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

/// The ingredient wishes as saved: "knight/royalRing/gemRing".
List<String> parts(Game g) => [for (final p in g.wishParts) p.names.join('/')];

/// The tab's rows: "group:product ×need" (an ingredient's group "parts", then "for" and the products it is for).
List<String> rows(Game g) => [
      for (final r in g.wishRows)
        '${r.parents.isNotEmpty ? 'parts' : r.type ?? 'free'}:${r.kind.name} ×${r.need}${r.parents.isEmpty ? '' : ' for ${r.parents.map((k) => k.name).join(',')}'}',
    ];

/// Puts [item]'s recipe's materials in [g]'s Bag [times] over (its items and gold are the test's own).
void giveMats(Game g, Item item, [int times = 1]) {
  for (final MapEntry(key: m, value: n) in g.itemRecipe(item)!.materials.entries) {
    g.materials[m] = (g.materials[m] ?? 0) + n * times;
  }
}

void main() {
  test('the recipes that take a forged product (decisions-log 323): the Cap\'s and the Ring\'s grade below, ten relics\' '
      'items; none takes a relic', () {
    final g = forgeGame();
    final takes = {
      for (final i in Item.values)
        if (g.itemRecipe(i)!.items.isNotEmpty) i.name: {for (final e in g.itemRecipe(i)!.items.entries) e.key.name: e.value},
      for (final r in g.relicsInPlay)
        if (g.craftRecipe(r)?.items case final items? when items.isNotEmpty) r.name: {for (final e in items.entries) e.key.name: e.value},
    };
    expect(takes, {
      'steelHelm': {'leatherCap': 1},
      'royalHelm': {'steelHelm': 1},
      'gemRing': {'ring': 1},
      'royalRing': {'gemRing': 1},
      'cleave': {'sword': 1},
      'venom': {'bow': 1},
      'manaSiphon': {'staff': 1},
      'spiritWard': {'shield': 1},
      'lastStand': {'towerShield': 1},
      'giantSlayer': {'steelGloves': 1},
      'blessing': {'bigPotion': 1},
      'avalanche': {'steelSword': 1},
      'afterglow': {'magicStaff': 1},
      'reaper': {'longBow': 1},
    });
    // Every one of them is a product the Smithy makes: each is an ingredient wish.
    for (final i in [for (final m in takes.values) ...m.keys]) {
      expect(g.canWishFree(Item.values.byName(i)), isTrue, reason: i);
    }
  });

  test('one level: a free relic\'s item goes on with it, for its count; two levels: the Royal Ring\'s Gem Ring and Ring',
      () {
    final g = forgeGame();
    expect(g.wishFreeAdd(Relic.cleave, 2), isTrue);
    expect(parts(g), ['free/cleave/sword']);
    expect(rows(g), ['free:cleave ×2', 'parts:sword ×2 for cleave'], reason: 'the recipe\'s one Sword for each of two');
    // Two levels, from a type's wish: the Gem Ring under the Royal Ring, the Ring under the Gem Ring.
    expect(g.wish('knight', Item.royalRing), isTrue);
    expect(parts(g), ['free/cleave/sword', 'knight/royalRing/gemRing', 'knight/royalRing/gemRing/ring']);
    expect(rows(g), ['knight:royalRing ×1', 'free:cleave ×2', 'parts:sword ×2 for cleave', 'parts:gemRing ×1 for royalRing', 'parts:ring ×1 for gemRing']);
    // An ingredient row is for no troop: no type; it makes what it still wants (the Bag's are counted in its need).
    final gem = g.wishRows.firstWhere((r) => r.kind == Item.gemRing);
    expect((gem.type, gem.make), (null, 1));
    expect(gem.parents, [Item.royalRing]);
    expect([for (final p in gem.parts) (p.kind, p.need)], [(Mat.tealGem, 1), (Mat.wolfFang, 1), (Item.ring, 1), (null, 600)]);
    // A Steel Helm's Leather Cap; a set's items take none.
    g.wish('archer', Item.steelHelm);
    expect(parts(g).last, 'archer/steelHelm/leatherCap');
    final before = parts(g);
    g.wishSet('priest');
    expect(parts(g), before, reason: 'no grade-I item takes a forged one');
    // Once each: the same wish again puts nothing on twice.
    expect(g.wish('knight', Item.royalRing), isFalse);
    expect(parts(g), before);
  });

  test('counts read live: the Bag\'s count less, none once the parent is made; two parents add up and each keeps it', () {
    final g = forgeGame(inTown: true);
    g
      ..wish('knight', Item.royalRing)
      ..wish('archer', Item.royalRing);
    expect(rows(g).where((r) => r.startsWith('parts:')), ['parts:gemRing ×2 for royalRing', 'parts:ring ×2 for gemRing'],
        reason: 'two parents of the same product: their counts add up');
    // A Ring in the Bag: one less to make.
    g.inventory[Item.ring] = 1;
    expect(rows(g).last, 'parts:ring ×1 for gemRing');
    // A Gem Ring crafted from it: one Gem Ring and one Ring still wanted (the Bag's Gem Ring is the first parent's).
    giveMats(g, Item.gemRing);
    expect(g.craftItem(Item.gemRing), isTrue);
    expect(rows(g).where((r) => r.startsWith('parts:')), ['parts:gemRing ×1 for royalRing', 'parts:ring ×1 for gemRing']);
    expect(g.partHeldFor(Item.gemRing), [Item.royalRing]);
    // A Royal Ring crafted (it takes the Gem Ring): the Bag's Royal Ring counts for both types' wishes, as their rows do
    // (decisions-log 303), so nothing is left to make for either, and no ingredient is wanted or kept.
    giveMats(g, Item.royalRing);
    expect(g.craftItem(Item.royalRing), isTrue);
    expect(rows(g), ['knight:royalRing ×1', 'archer:royalRing ×1']);
    expect(g.partWished(Item.gemRing), isFalse);
    expect(g.partHeldFor(Item.gemRing), isEmpty, reason: 'made: nothing kept for it');
    // Given to the knight: its wish met, off with its chain; the archer's still wants one, its Gem Ring and Ring again.
    expect(g.useItem(Item.royalRing, 'knight'), isTrue);
    expect(parts(g), ['archer/royalRing/gemRing', 'archer/royalRing/gemRing/ring']);
    expect(rows(g), ['archer:royalRing ×1', 'parts:gemRing ×1 for royalRing', 'parts:ring ×1 for gemRing']);
    // Two parents, one off: the other keeps them, at its count.
    g.wish('soldier', Item.royalRing);
    expect(rows(g).where((r) => r.startsWith('parts:')), ['parts:gemRing ×2 for royalRing', 'parts:ring ×2 for gemRing']);
    expect(g.unwish('archer', Item.royalRing), isTrue);
    expect(rows(g), ['soldier:royalRing ×1', 'parts:gemRing ×1 for royalRing', 'parts:ring ×1 for gemRing']);
    expect(parts(g), ['soldier/royalRing/gemRing', 'soldier/royalRing/gemRing/ring']);
  });

  test('the player\'s own wish for the same product stays apart: its own row, kept when the parent goes', () {
    final g = forgeGame();
    g
      ..wishFreeAdd(Item.gemRing)
      ..wish('knight', Item.royalRing);
    // Two Gem Rings to make (the own one, the Royal Ring's), so two Rings: the Ring first, put on first under the free line.
    expect(rows(g), ['knight:royalRing ×1', 'free:gemRing ×1', 'parts:ring ×2 for gemRing', 'parts:gemRing ×1 for royalRing']);
    expect(parts(g), ['free/gemRing/ring', 'knight/royalRing/gemRing', 'knight/royalRing/gemRing/ring'],
        reason: 'the own free line\'s Ring is its own too');
    expect(g.unwish('knight', Item.royalRing), isTrue);
    expect(rows(g), ['free:gemRing ×1', 'parts:ring ×1 for gemRing']);
    expect(g.freeGoal(Item.gemRing), 1, reason: 'the own wish untouched');
    // And an ingredient's ✕ leaves the own wish too.
    g.wish('knight', Item.royalRing);
    expect(g.unwishPart(Item.gemRing), isTrue);
    expect(rows(g), ['knight:royalRing ×1', 'free:gemRing ×1', 'parts:ring ×1 for gemRing'],
        reason: 'the knight\'s Gem Ring and its Ring off; the free line\'s Ring stays');
  });

  test('taken off with their parent (the owner: "Ikut terhapus"): unwish, a group\'s Remove, a free line off, an '
      'ingredient\'s ✕ and the group\'s; the parent stays when only its ingredient goes', () {
    final g = forgeGame();
    void chain() {
      g
        ..wish('knight', Item.royalRing)
        ..wish('knight', Item.royalHelm)
        ..wishFreeAdd(Relic.venom)
        ..wishFreeAdd(Item.royalRing);
    }

    chain();
    expect(parts(g), [
      'knight/royalRing/gemRing',
      'knight/royalRing/gemRing/ring',
      'knight/royalHelm/steelHelm',
      'knight/royalHelm/steelHelm/leatherCap',
      'free/venom/bow',
      'free/royalRing/gemRing',
      'free/royalRing/gemRing/ring',
    ]);
    expect(g.unwish('knight', Item.royalHelm), isTrue);
    expect(parts(g).where((p) => p.contains('Helm') || p.contains('Cap')), isEmpty, reason: 'recursively');
    expect(g.unwishFree(Relic.venom), isTrue);
    expect(parts(g), ['knight/royalRing/gemRing', 'knight/royalRing/gemRing/ring', 'free/royalRing/gemRing', 'free/royalRing/gemRing/ring']);
    expect(g.unwishAll('knight'), isTrue);
    expect(parts(g), ['free/royalRing/gemRing', 'free/royalRing/gemRing/ring']);
    expect(g.unwishFreeAll(), isTrue);
    expect(parts(g), isEmpty);
    // An ingredient's ✕: it and those under it, the wish it was for stays.
    chain();
    expect(g.unwishPart(Item.gemRing), isTrue);
    expect(parts(g), ['knight/royalHelm/steelHelm', 'knight/royalHelm/steelHelm/leatherCap', 'free/venom/bow']);
    expect(g.wishesOf('knight'), [Item.royalRing, Item.royalHelm]);
    expect((g.unwishPart(Item.gemRing), g.unwishPart(Item.ring)), (false, false), reason: 'none left');
    // The group's Remove: every ingredient wish, no parent.
    expect(g.unwishParts(), isTrue);
    expect(parts(g), isEmpty);
    expect((g.wishesOf('knight'), g.freeWishes), ([Item.royalRing, Item.royalHelm], [Relic.venom, Item.royalRing]));
    expect(g.unwishParts(), isFalse);
  });

  test('met, the parent takes its ingredients with it: a Ring given, a free line crafted', () {
    final g = forgeGame(inTown: true);
    g.wish('knight', Item.royalRing);
    g.inventory[Item.royalRing] = 1;
    expect(g.useItem(Item.royalRing, 'knight'), isTrue);
    expect(g.wishesOf('knight'), isEmpty, reason: 'a Ring met drops at once');
    expect(parts(g), isEmpty, reason: 'its chain with it');
    // A free Cleave crafted: its Sword goes with the line.
    g.wishFreeAdd(Relic.cleave);
    final r = g.craftRecipe(Relic.cleave)!;
    for (final MapEntry(key: m, value: n) in r.materials.entries) {
      g.materials[m] = (g.materials[m] ?? 0) + n;
    }
    giveMats(g, Item.sword);
    expect(rows(g), ['free:cleave ×1', 'parts:sword ×1 for cleave']);
    expect(g.craftItem(Item.sword), isTrue);
    expect(rows(g), ['free:cleave ×1'], reason: 'the Sword made: its row met');
    expect(parts(g), ['free/cleave/sword'], reason: 'still held for the Cleave');
    expect(g.partHeldFor(Item.sword), [Relic.cleave]);
    expect(g.craft(Relic.cleave), isTrue);
    expect(g.wishFree, isEmpty);
    expect(parts(g), isEmpty);
    // A Steel Helm given: its Leather Cap goes with the met wish.
    g.wish('knight', Item.steelHelm);
    g.inventory[Item.steelHelm] = 1;
    expect(g.useItem(Item.steelHelm, 'knight'), isTrue);
    expect(parts(g), isEmpty);
  });

  test('an ingredient wish is wished: the Items board\'s star and order, its materials marked; nothing crafted or given '
      'by itself', () {
    final g = forgeGame(inTown: true);
    final before = '${g.materials} ${g.inventory} ${g.gold} ${g.upgrades}';
    g.wish('knight', Item.royalRing);
    expect([g.wished(Item.gemRing), g.wished(Item.ring), g.wished(Item.royalRing)], [true, true, true]);
    expect(smithyItemOrder(g, 2).first, Item.gemRing);
    expect(smithyItemOrder(g, 1).first, Item.ring);
    expect(g.wishMats, containsAll([...g.itemRecipe(Item.gemRing)!.materials.keys, ...g.itemRecipe(Item.ring)!.materials.keys]));
    for (var i = 0; i < 40; i++) {
      g.tick(0.05);
    }
    expect('${g.materials} ${g.inventory} ${g.gold} ${g.upgrades}', before);
  });

  test('the save\'s `parts` (decisions-log 323): a round trip in order; an old save\'s wishes chained as now; unknown '
      'names, a lost wish or parent, a part its recipe doesn\'t take skipped; a met free line\'s not saved', () {
    final g = forgeGame()
      ..wish('knight', Item.royalRing)
      ..wishFreeAdd(Relic.cleave);
    final saved = (g.toJson()['wishlist'] as Map)['parts'];
    expect(saved, [
      ['knight', 'royalRing', 'gemRing'],
      ['knight', 'royalRing', 'gemRing', 'ring'],
      ['free', 'cleave', 'sword'],
    ]);
    expect(parts(reload(g)), parts(g));
    expect((reload(reload(g)).toJson()['wishlist'] as Map)['parts'], saved);
    // An ingredient taken off by hand stays off after a reload (the key is there, empty or not).
    g.unwishParts();
    expect((g.toJson()['wishlist'] as Map)['parts'], isEmpty);
    expect(parts(reload(g)), isEmpty);

    // A save from before (no `parts`): its wishes' ingredients go on as a wish put on now does.
    final old = jsonDecode(jsonEncode(forgeGame().toJson())) as Map<String, dynamic>
      ..['wishlist'] = {
        'knight': {'royalHelm': 1, 'sword': 2},
        'free': {'venom': 1},
      };
    final back = Game.fromJson(old, Random(1), Random(2))..boardRules();
    expect(parts(back), ['knight/royalHelm/steelHelm', 'knight/royalHelm/steelHelm/leatherCap', 'free/venom/bow']);

    // Skipped: a name this build doesn't know, a type that isn't one, a wish not on the list, a parent missing, a part
    // its parent's recipe doesn't take.
    final odd = jsonDecode(jsonEncode(forgeGame().toJson())) as Map<String, dynamic>
      ..['wishlist'] = {
        'knight': {'royalRing': 1},
        'parts': [
          ['knight', 'royalRing', 'gemRing'],
          ['knight', 'royalRing', 'mysteryRing'],
          ['slime', 'royalRing', 'gemRing'],
          ['archer', 'royalRing', 'gemRing'],
          ['knight', 'royalHelm', 'steelHelm', 'leatherCap'],
          ['knight', 'royalRing', 'sword'],
          ['knight', 'royalRing'],
          'knight/royalRing/gemRing/ring',
          ['knight', 'royalRing', 'gemRing', 'ring'],
        ],
      };
    expect(parts(Game.fromJson(odd, Random(1), Random(2))..boardRules()), ['knight/royalRing/gemRing', 'knight/royalRing/gemRing/ring']);

    // A met free line isn't saved, nor its ingredients.
    final met = forgeGame()..wishFreeAdd(Relic.cleave);
    met.relicBag[Relic.cleave] = 1;
    expect(met.toJson().containsKey('wishlist'), isFalse);
    expect(Game.saveVersion, 3, reason: 'an added key: no new format');
  });
}
