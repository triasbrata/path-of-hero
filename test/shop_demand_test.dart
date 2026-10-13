// The Sell tab's High demand (decisions-log 335; ui-hud.md "The Town's Shop"; loot-items-relics.md "Towns: the market"):
// which products it lists in each identity's Town and in what order, a flooded one gone, and the demand count
// ([Market.demandLeft]) against the market's own flooded word. The page: shop_demand_ui_test.dart.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart';

/// A game in its [n]th Town (its market reads that Town's identity).
Game townGame(int n) => Game(Random(1), Random(2)).boardRules()
  ..townCount = n
  ..inTown = true;

void main() {
  test("High demand: each identity's hot products, every grade of its four kinds at +0, by the price here, most first",
      () {
    for (final n in const [1, 2, 4, 5, 7, 8]) {
      final g = townGame(n), who = identityOf(n), list = shopDemandLoot(g);
      final hot = [
        for (final i in Item.values)
          if (who.wants.contains(i.slot) && g.marketWord(i) == MarketWord.hot) i,
      ];
      expect(list.map((l) => l.kind).toSet(), hot.toSet(), reason: '${who.name}: the hot products of its kinds');
      expect(list.every((l) => l.plus == 0), isTrue, reason: '${who.name}: never an enhanced stack');
      final prices = [for (final l in list) g.sellPrice(l.kind)];
      expect(prices, [...prices]..sort((a, b) => b.compareTo(a)), reason: '${who.name}: by price, most first');
      // Every grade of every wanted kind is hot in the first six Towns; from the seventh grade I is at 1.3 x 1.3 (< 2).
      expect(list.length, n >= 7 ? 8 : 12, reason: who.name);
      if (n >= 7) expect(list.any((l) => (l.kind as Item).grade == 1), isFalse, reason: '${who.name}: no grade I');
    }
  });

  test('Millbrook: Wind Boots first (595), Boots last (182); equal prices keep the Town order', () {
    final g = townGame(1), list = shopDemandLoot(g);
    expect((list.first.kind, g.sellPrice(list.first.kind)), (Item.windBoots, 595));
    expect((list.last.kind, g.sellPrice(list.last.kind)), (Item.boots, 182));
    // Ironvale: the Tower Shield and the Steel Gloves both 328, the shield's kind first in its wants.
    final iron = townGame(4), names = [for (final l in shopDemandLoot(iron)) l.kind];
    expect((iron.sellPrice(Item.towerShield), iron.sellPrice(Item.steelGloves)), (328, 328));
    expect(names.indexOf(Item.towerShield) < names.indexOf(Item.steelGloves), isTrue);
  });

  test('a product sold until flooded leaves High demand; the demand count is the pieces before it floods', () {
    final g = townGame(1), key = g.marketKey(Item.boots);
    expect(g.demandLeft(Item.boots), 16, reason: 'fresh: pressure 16 of 24 is past half way at the curve 1.5');
    for (var p = 0; p <= g.townRules.market.most; p++) {
      g.market[key] = p;
      // The demand is how many more sales keep it unflooded: at pressure p + demand the market says flooded.
      final left = g.demandLeft(Item.boots);
      expect(left, max(0, 16 - p), reason: 'pressure $p');
      expect(g.marketWord(Item.boots) == MarketWord.flooded, left == 0, reason: 'pressure $p');
      expect(shopDemandLoot(g).any((l) => l.kind == Item.boots), left > 0, reason: 'pressure $p');
      if (left > 0) {
        g.market[key] = p + left - 1;
        expect(g.marketWord(Item.boots), MarketWord.hot, reason: 'the last piece of the demand still hot');
        g.market[key] = p + left;
        expect(g.marketWord(Item.boots), MarketWord.flooded, reason: 'the one after it flooded');
      }
    }
  });

  test('a product at the floor already never floods: its demand is the most', () {
    final g = townGame(7);
    // Frostgate's Sword (grade I, a wanted kind): 1.3 x 1.3 fresh, never hot, so not listed.
    expect(shopDemandLoot(g).any((l) => l.kind == Item.sword), isFalse);
    expect(g.marketWord(Item.sword), isNull);
    // A grade I item the Town doesn't want, at the floor: nothing to flood.
    expect(g.freshMargin(Item.bow), g.townRules.market.floor);
    expect(g.demandLeft(Item.bow), g.townRules.market.most);
  });
}
