// The Shop open in every Town (decisions-log 253; the owner, 2026-10-07: "shop juga harusnya di buka ketika masuk kota,
// dan di battle ground tabnya di hilangkan"; ui-hud.md "Town", loot-items-relics.md "The store"): the shipped town.json's
// `shop.from` 1 opens a Town's Shop from the first Town, while Awaken 4-5, Forge and Recall keep wave 15
// ([Store.armyBuysOpen]); no "VICTORY!" line for a Shop that never was shut ([Store.shopJustOpened]); the book's tabs on
// the field and in a Town (no Shop tab on the field at any wave: the Toko's tab went in decisions-log 296), at the desk
// (1266x713) and a phone (915x412).
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'town_hud_test.dart' show boot, frames, townGame;
import 'town_scene_test.dart' show intoTown, settle;

void main() {
  final shipped = TownRules.parse(File('assets/config/town.json').readAsStringSync());

  test("the shipped town.json opens a Town's Shop from the first Town; Awaken 4-5, Forge and Recall keep wave 15", () {
    expect(shipped.shop.from, 1);
    expect(shipped.skipped, isEmpty);
    final g = Game(Random(1), Random(2)).boardRules()
      ..townRules = shipped
      ..gold = 1 << 20
      ..wave = 1 // wave 1 won: the earliest a Town can come
      ..townAt = 2
      ..inTown = true;
    g.inventory[Item.sword] = 1;
    expect((g.storeOpen, g.armyBuysOpen), (true, false));
    expect(g.whyNotSell(Item.sword), isNull);
    expect(g.sell(Item.sword), 1, reason: 'sold in the first Town');
    g.fallenHeroes.add(FallenHero(name: 'Kael', type: 'knight', stats: const [HeroStat.hp], fell: 1));
    expect(g.whyNotRecall(g.fallenHeroes.single), 'Opens after wave $storeFrom', reason: 'Recall keeps wave 15');
  });

  test('no "VICTORY!" Shop line while shop.from is 1; a later shop.from has it at its wave', () {
    final on = Game()
      ..townRules = shipped;
    expect([for (var w = 0; w <= 40; w++) (on..wave = w).shopJustOpened], everyElement(isFalse));
    final later = Game()
      ..townRules = TownRules.patch({'shop': {'from': 10}});
    expect([for (var w = 0; w <= 40; w++) if ((later..wave = w).shopJustOpened) w], [10]);
  });

  for (final size in const [Size(1266, 713), Size(915, 412)]) {
    final tag = '${size.width.round()}x${size.height.round()}';
    testWidgets("the book's tabs at $tag: no Shop tab on the field at any wave, the Shop's in a Town open from the first",
        (tester) async {
      final b = await boot(tester, size);
      b.autoStart.set(false);
      List<String> tabs() => [for (final (name, _) in b.bookTabs) name];

      // On the field: Army, Bag, Settings, whatever the wave.
      final g = b.state = townGame()..townRules = shipped;
      for (final w in [0, 1, 14, 15, 40]) {
        g.wave = w;
        await frames(tester, 3);
        expect(tabs(), ['troops', 'bag', 'settings'], reason: 'the field at wave $w');
      }

      // The first Town (wave 1 won): its tabs, and the Shop's opens its page.
      final t = await intoTown(tester, b, wave: 0);
      await settle(tester, b);
      expect((t.wave, t.inTown, t.storeOpen), (1, true, true));
      expect(tabs(), ['smithy', 'tavern', 'store', 'troops', 'bag', 'settings']); // the Tavern's after the Smithy (decisions-log 268), the Army's after the Shop (301)
      await tester.tapAt(b.bookTabs.firstWhere((x) => x.$1 == 'store').$2.center);
      await frames(tester, 40);
      expect((b.bookPage, b.storeShown), ('store', true), reason: 'the Shop open in the first Town');
    });
  }
}
