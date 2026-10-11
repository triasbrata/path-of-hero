// The forge's Town Shop (decisions-log 248; loot-items-relics.md "The forge: the Town Shop", ui-hud.md "The Town's Shop"):
// with the forge and the Towns on ([Store.forgeShop]) the shelf holds every material that has dropped ([Game.matsSeen], in
// first-drop order) at 2.5x its sell price rounded up to 5, and no item or small relic ("Not for sale"); a bought
// material goes in the Bag for its price and never joins matsSeen; the Shop still buys everything at today's prices, and
// still opens from wave 15. With the forge off, or the Towns off, the shelf is today's and no material is sold. Its Buy
// sections, only those with goods (decisions-log 269 and 280), and Sell grid. The page: forge_shop_ui_test.dart,
// shop_tabs_ui_test.dart.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show BagCategory, onShopShelf, shopBuyKinds, shopBuySections, shopSellLoot;

import 'hero_skill_helpers.dart';

/// A rich game in a Town after wave 20 with the Towns on (or off, [towns]: tests only), holding a Sword, a small relic, Wolf
/// Claws and a Skull and a Vault Artifact; the materials seen ([Game.matsSeen]) in drop order: Wolf Claw, Slime Gel, Lich
/// Orb, Evil Eye, Soul Orb (the Skull held but never dropped: say a save's).
Game forgeShopGame({bool towns = true, bool inTown = true}) {
  final g = bareGame(Random(1))
    ..towns = towns
    ..wave = 20
    ..gold = 100000;
  if (inTown) {
    g
      ..townAt = 21
      ..inTown = true;
  }
  g.inventory[Item.sword] = 3;
  g.relicBag[droppedRelics.first] = 2;
  g.materials.addAll({Mat.wolfClaw: 4, Mat.skull: 1});
  g.matsSeen.addAll([Mat.wolfClaw, Mat.slimeGel, Mat.lichOrb, Mat.evilEye, Mat.soulOrb]);
  g.pusaka[Relic.titanBane] = OwnedPusaka(stars: 2);
  return g;
}

void main() {
  const seen = [Mat.wolfClaw, Mat.slimeGel, Mat.lichOrb, Mat.evilEye, Mat.soulOrb];

  test("the shelf is the materials seen, in first-drop order: Buy's one section Materials (Items and Relics, which have "
      'none, left out); Sell is what the player holds, in the Bag\'s order; no item, no small relic on the shelf', () {
    final g = forgeShopGame()..offers = true; // the board's: the Artifact shelf closed beside the boss's chest
    expect(g.forgeShop, isTrue);
    final relic = droppedRelics.first;
    expect(shopBuySections(g), [BagCategory.materials]);
    expect(shopBuyKinds(g, BagCategory.materials), seen, reason: 'the shelf alone, never a held kind not dropped');
    expect([shopBuyKinds(g, BagCategory.items), shopBuyKinds(g, BagCategory.relics)], [isEmpty, isEmpty]);
    expect(shopBuyKinds(g, BagCategory.all), seen);
    expect([for (final l in shopSellLoot(g)) l.kind], [Item.sword, relic, Mat.wolfClaw, Mat.skull, Relic.titanBane]);
    expect([for (final m in Mat.values) if (onShopShelf(g, m)) m], unorderedEquals(seen));
    expect([for (final i in Item.values) if (onShopShelf(g, i)) i], isEmpty);
    expect([for (final r in smallRelics) if (onShopShelf(g, r)) r], isEmpty);

    // The Artifact shelf is unchanged: open, the store's Artifacts are a section before the materials.
    g.offers = false;
    final shelf = [for (final r in Relic.values) if (r.store && pusakaCatalog[r]!.live) r];
    expect(shelf, isNotEmpty);
    expect(shopBuySections(g), [BagCategory.artifacts, BagCategory.materials]);
    expect(shopBuyKinds(g, BagCategory.all), [...shelf, ...seen]);
    for (final r in shelf) {
      expect((onShopShelf(g, r), g.whyNotBuy(r), g.buyPrice(r)), (true, null, artefactPrice[r]), reason: '$r');
    }

    // Nothing dropped yet and nothing held: an empty shelf, no section (the page's "Nothing to buy here yet."); the
    // Artifact shelf open, Artifacts alone.
    final bare = forgeShopGame()
      ..offers = true
      ..matsSeen.clear()
      ..inventory.clear()
      ..relicBag.clear()
      ..materials.clear()
      ..pusaka.clear();
    expect([shopBuyKinds(bare, BagCategory.all), shopSellLoot(bare)], [isEmpty, isEmpty]);
    expect(shopBuySections(bare), isEmpty, reason: 'no section with nothing to buy (decisions-log 280)');
    bare.offers = false;
    expect(shopBuySections(bare), [BagCategory.artifacts]);
  });

  test("the prices: 2.5x the material's sell price rounded up to 5 (Slime Gel 25, Wolf Claw 65, Evil Eye 750, Soul Orb "
      '1500, Lich Orb 2000), the same after a buy; an item, a small relic or a material not seen is "Not for sale"', () {
    final g = forgeShopGame();
    expect({for (final m in seen) m: g.buyPrice(m)},
        {Mat.wolfClaw: 65, Mat.slimeGel: 25, Mat.lichOrb: 2000, Mat.evilEye: 750, Mat.soulOrb: 1500});
    for (final m in seen) {
      expect((g.buyPrice(m), g.basePrice(m), g.buyPrice(m, 3)), (g.shopMatPrice(m), g.shopMatPrice(m), g.shopMatPrice(m)), reason: '$m');
      expect(g.whyNotBuy(m), isNull, reason: '$m');
    }
    expect(storeRefusalNames[StoreRefusal.notSold], 'Not for sale');
    for (final kind in [Item.sword, Item.potion, droppedRelics.first, smallRelics.last, Mat.skull, Mat.batWing]) {
      expect(g.whyNotBuy(kind), StoreRefusal.notSold, reason: '$kind');
    }
    final gold = g.gold, bag = {...g.inventory}, relics = {...g.relicBag}, mats = {...g.materials};
    g.sfx.clear();
    expect([g.buy(Item.sword), g.buy(droppedRelics.first), g.buy(Mat.skull)], [false, false, false]);
    expect(g.gold, gold);
    expect([g.inventory, g.relicBag, g.materials, g.storeBought], [bag, relics, mats, isEmpty]);
    expect(g.sfx.where((s) => s == Sfx.error), hasLength(3));

    // A patched rise (town.json shop.matRise) adds its share a buy, counted as the store's other goods.
    g.townRules = TownRules.patch({
      'shop': {'matRise': 0.1},
    });
    expect([g.buyPrice(Mat.slimeGel), g.buyPrice(Mat.slimeGel, 1)], [25, 30]);
    expect(g.buy(Mat.slimeGel), isTrue);
    expect((g.buyPrice(Mat.slimeGel), g.gold), (30, gold - 25));
  });

  test('buying a material: its price in gold, one more in the Bag (a first one too), the coin; never added to matsSeen; '
      'its record names the material; saved and loaded with the rest', () {
    final g = forgeShopGame(), events = <GameEvent>[];
    g.listeners.add(events.add);
    final order = [...g.matsSeen];
    g.sfx.clear();
    expect(g.buy(Mat.wolfClaw), isTrue);
    expect((g.materials[Mat.wolfClaw], g.gold), (5, 100000 - 65));
    expect(g.buy(Mat.slimeGel), isTrue, reason: 'none held: the first one');
    expect((g.materials[Mat.slimeGel], g.gold), (1, 100000 - 90));
    expect(g.buy(Mat.soulOrb), isTrue);
    expect((g.materials[Mat.soulOrb], g.gold), (1, 100000 - 1590));
    expect(g.sfx.where((s) => s == Sfx.kill), hasLength(3), reason: 'the coin each');
    expect([...g.matsSeen], order, reason: 'a buy never adds, nor moves one');
    expect(g.storeBought, {Mat.wolfClaw: 1, Mat.slimeGel: 1, Mat.soulOrb: 1});
    expect([for (final e in events.whereType<StoreBought>()) e.data], [
      {'item': null, 'relic': null, 'material': 'wolfClaw', 'cost': 65},
      {'item': null, 'relic': null, 'material': 'slimeGel', 'cost': 25},
      {'item': null, 'relic': null, 'material': 'soulOrb', 'cost': 1500},
    ]);

    // Not enough gold: refused, nothing changes.
    g.gold = 1000;
    expect((g.whyNotBuy(Mat.lichOrb), g.buy(Mat.lichOrb)), (StoreRefusal.gold, false));
    expect((g.gold, g.materials.containsKey(Mat.lichOrb)), (1000, false));

    // The save: the bought counts by the material's name, back on load.
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect(j['storeBought'], {'wolfClaw': 1, 'slimeGel': 1, 'soulOrb': 1});
    final back = Game.fromJson(j, Random(1), Random(2));
    expect(back.storeBought, {Mat.wolfClaw: 1, Mat.slimeGel: 1, Mat.soulOrb: 1});
  });

  test('the Shop still buys everything at today\'s prices: an item and a small relic at half their worth, a material at '
      'its sell price, a Vault Artifact; and opens from town.json\'s shop.from (1 as shipped: every Town, decisions-log '
      '253)', () {
    final on = forgeShopGame();
    final relic = droppedRelics.first;
    for (final kind in [Item.sword, relic, Mat.wolfClaw, Mat.skull, Relic.titanBane]) {
      expect(on.whyNotSell(kind), isNull, reason: '$kind');
    }
    expect((on.sellPrice(Item.sword), on.sellPrice(Mat.wolfClaw), on.sellPrice(Mat.skull)), (1000, 25, 60));
    final gold = on.gold, worth = [Item.sword, relic, Mat.wolfClaw, Relic.titanBane].fold(0, (n, k) => n + on.sellPrice(k));
    expect([on.sell(Item.sword), on.sell(relic), on.sell(Mat.wolfClaw), on.sell(Relic.titanBane)], [1, 1, 1, 1]);
    expect(on.gold, gold + worth);
    expect(on.matsSeen, contains(Mat.wolfClaw), reason: 'selling never takes a kind off the shelf');
    expect(on.sell(Mat.wolfClaw, 99), 3);
    expect((on.materials.containsKey(Mat.wolfClaw), onShopShelf(on, Mat.wolfClaw), on.whyNotBuy(Mat.wolfClaw)), (false, true, null),
        reason: 'the last sold, still on the shelf');

    final early = forgeShopGame()..wave = 0;
    expect((early.whyNotBuy(Mat.wolfClaw), early.whyNotSell(Mat.wolfClaw)), (StoreRefusal.locked, StoreRefusal.locked));
    final later = forgeShopGame()
      ..townRules = TownRules.patch({
        'shop': {'from': 15},
      })
      ..wave = 14;
    expect((later.whyNotBuy(Mat.wolfClaw), later.whyNotSell(Mat.wolfClaw)), (StoreRefusal.locked, StoreRefusal.locked));
    final field = forgeShopGame(inTown: false);
    expect((field.whyNotBuy(Mat.wolfClaw), field.buy(Mat.wolfClaw)), (StoreRefusal.town, false));
  });

  test('with the Towns off (tests only) no forge Shop: the store sells as before the Towns', () {
    final noTowns = forgeShopGame(towns: false, inTown: false);
    expect(noTowns.forgeShop, isFalse);
    expect(noTowns.whyNotBuy(Item.sword), isNull, reason: "the Towns-off store's shelf");
  });
}
