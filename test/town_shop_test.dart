// The Town's Shop's rules (decisions-log 230; loot-items-relics.md "The store", ui-hud.md "The Town's Shop"): with the
// Towns on the store deals only in a Town (StoreRefusal.town, first), for every kind it buys or sells, while Awaken,
// Forge and Recall still buy between any waves; in a Town it sells the materials seen (the forge's shelf, its rules
// forge_shop_test.dart's) and buys at today's prices, the materials at their own price (town.json), the last one leaving
// no entry, with its own `material` in the record; the Sell grid (decisions-log 269: shopSellLoot); with the Towns off
// (tests only) nothing changes. The page: forge_shop_ui_test.dart, shop_tabs_ui_test.dart.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show shopSellLoot;

import 'hero_skill_helpers.dart';

/// A rich game after wave 20 (the store open) with the Towns [on] (off: tests only), [inTown] or not, holding items,
/// small relics, materials and a Vault Artifact; the Wolf Claw has dropped (on the forge's shelf, [Game.matsSeen]).
Game shopGame({bool on = true, bool inTown = false}) {
  final g = bareGame(Random(1))
    ..towns = on
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
  g.matsSeen.add(Mat.wolfClaw);
  g.pusaka[Relic.titanBane] = OwnedPusaka(stars: 2);
  return g;
}

void main() {
  final kinds = <Enum>[Item.sword, droppedRelics.first, Mat.wolfClaw, Relic.titanBane];

  test('with the Towns on, outside a Town the store neither buys nor sells anything ("Only in a Town", first); in one it '
      'deals as today, open from the first Town (town.json shop.from 1, decisions-log 253; locked before a later shop.from)',
      () {
    final g = shopGame();
    expect(storeRefusalNames[StoreRefusal.town], Words.onlyInTown);
    for (final kind in kinds) {
      expect(g.whyNotSell(kind), StoreRefusal.town, reason: '$kind');
    }
    for (final kind in [Item.sword, droppedRelics.first, Mat.wolfClaw]) {
      expect(g.whyNotBuy(kind), StoreRefusal.town, reason: '$kind');
    }
    final gold = g.gold, bag = {...g.inventory}, relics = {...g.relicBag}, mats = {...g.materials};
    g.sfx.clear();
    expect([g.buy(Mat.wolfClaw), g.buy(droppedRelics.first)], [false, false]);
    expect([for (final kind in kinds) g.sell(kind, 99)], [0, 0, 0, 0]);
    expect((g.gold, g.pusaka.containsKey(Relic.titanBane)), (gold, true));
    expect([g.inventory, g.relicBag, g.materials], [bag, relics, mats]);
    expect(g.sfx.where((s) => s == Sfx.error), hasLength(6), reason: 'each refused with the error sound');

    // Mid-wave there is no Town to be in: still "Only in a Town", first.
    g.startWave();
    expect((g.whyNotBuy(Mat.wolfClaw), g.whyNotSell(Item.sword)), (StoreRefusal.town, StoreRefusal.town));

    // In the Town: today's refusals and prices; the shelf the materials seen alone (no item, no small relic).
    final t = shopGame(inTown: true);
    for (final kind in kinds) {
      expect(t.whyNotSell(kind), isNull, reason: '$kind');
    }
    expect((t.whyNotBuy(Item.sword), t.whyNotBuy(droppedRelics.first), t.whyNotBuy(Mat.wolfClaw)),
        (StoreRefusal.notSold, StoreRefusal.notSold, null));
    expect(t.sellPrice(Item.sword), 1000);
    final relic = droppedRelics.first, back = t.sellPrice(relic); // the Craft step's by tier
    expect(t.sell(relic), 1);
    expect(t.gold, 100000 + back, reason: "a small relic at the store's own price");
    t.gold = 100000;
    final claw = t.buyPrice(Mat.wolfClaw);
    expect(t.buy(Mat.wolfClaw), isTrue);
    expect((t.materials[Mat.wolfClaw], t.gold), (5, 100000 - claw));
    t.gold = 100000;
    expect(t.sell(Item.sword, 2), 2);
    expect((t.inventory[Item.sword], t.gold), (1, 100000 + 2000));
    t.gold = 1;
    expect(t.whyNotBuy(Mat.wolfClaw), StoreRefusal.gold);
    expect(t.sell(Relic.titanBane), 1, reason: 'a Vault Artifact sells in the Town');
    expect(t.pusaka.containsKey(Relic.titanBane), isFalse);

    // Open from the first Town: wave 1 won is open, before it nothing is (and no Town comes before a win).
    final early = shopGame(inTown: true)..wave = 1;
    expect((early.shopFrom, early.whyNotBuy(Mat.wolfClaw), early.whyNotSell(Item.sword)), (1, null, null));
    early.wave = 0;
    expect(early.whyNotBuy(Mat.wolfClaw), StoreRefusal.locked);
    // A later shop.from (the knob) locks the Shop before it, in a Town too.
    final later = shopGame(inTown: true)
      ..townRules = TownRules.patch({'shop': {'from': 15}})
      ..wave = 14;
    expect((later.whyNotBuy(Mat.wolfClaw), later.whyNotSell(Item.sword)), (StoreRefusal.locked, StoreRefusal.locked));
  });

  test('Awaken, Forge and Recall still buy between any waves outside a Town (the Army detail\'s)', () {
    final g = shopGame()..gold = 1000000;
    expect(g.inTown, isFalse);
    g.fallenHeroes.add(FallenHero(name: 'Kael', type: 'knight', stats: const [HeroStat.hp], fell: 16));
    expect(g.whyNotRecall(g.fallenHeroes.single), isNull);
    expect(g.recallHero(g.fallenHeroes.single), isTrue);
    expect(g.fallenHeroes, isEmpty);
  });

  test('the Shop buys the materials at their own price (town.json), one or all, the last leaving no entry; the record and '
      'an item\'s record has no `material`', () {
    final g = shopGame(inTown: true), events = <GameEvent>[];
    g.listeners.add(events.add);
    final claw = g.townRules.materials[Mat.wolfClaw]!.sell, skull = g.townRules.materials[Mat.skull]!.sell;
    expect((g.sellPrice(Mat.wolfClaw), g.sellPrice(Mat.skull), g.inBag(Mat.wolfClaw)), (claw, skull, 4));
    expect((claw, skull), (25, 60), reason: "town.json's defaults");
    final gold = g.gold;
    expect(g.sell(Mat.wolfClaw), 1);
    expect((g.materials[Mat.wolfClaw], g.gold), (3, gold + claw));
    expect(g.sell(Mat.wolfClaw, 3), 3);
    expect((g.materials.containsKey(Mat.wolfClaw), g.gold), (false, gold + 4 * claw));
    expect(g.whyNotSell(Mat.wolfClaw), StoreRefusal.none);
    expect(g.sell(Item.sword), 1);
    final sold = events.whereType<StoreSold>().toList();
    expect([for (final e in sold) e.data], [
      {'item': null, 'relic': null, 'material': 'wolfClaw', 'n': 1, 'gain': claw},
      {'item': null, 'relic': null, 'material': 'wolfClaw', 'n': 3, 'gain': 3 * claw},
      {'item': 'sword', 'relic': null, 'n': 1, 'gain': 1000},
    ]);
  });

  test("the Shop's Sell (decisions-log 269): what the player holds that it buys, in the Bag's order, the Vault "
      "Artifacts but not a bound one, not an oath (its Buy, the forge's shelf: forge_shop_test.dart)", () {
    final g = shopGame(inTown: true);
    expect([for (final l in shopSellLoot(g)) l.kind], [Item.sword, droppedRelics.first, Mat.wolfClaw, Mat.skull, Relic.titanBane]);
    g.pusaka[Relic.dragonCrown] = OwnedPusaka(type: 'knight');
    g.pusaka[Relic.oathOfOne] = OwnedPusaka();
    expect([for (final l in shopSellLoot(g)) if (l.kind case Relic(pusaka: true)) l.kind], [Relic.titanBane], reason: 'bound and oaths out');
  });

  test('with the Towns off nothing changes: the store deals on the field, and no material is ever in its record', () {
    final g = shopGame(on: false), events = <GameEvent>[];
    g.listeners.add(events.add);
    expect((g.inTown, g.whyNotBuy(Item.sword), g.whyNotSell(Item.sword), g.whyNotSell(Relic.titanBane)), (false, null, null, null));
    expect(g.sell(Item.sword), 1);
    expect(events.whereType<StoreSold>().single.data, {'item': 'sword', 'relic': null, 'n': 1, 'gain': 1000});
  });
}
