// The Towns' identities and the market for forged goods (decisions-log 326; loot-items-relics.md "The market", ui-hud.md
// "The Towns"): the identity by the Town's number, two a season; an item's and a small relic's HPP (its parts at what
// the Shop pays for them, its gold) and its price (the gold at the floor, the parts at the Town's margin: 1.3x-4x by
// grade and demand); one exact product's pressure pulling it down to the floor, never under, and coming back over
// 2-3 Towns; the Shop's materials dearer as they are bought; the Sell page's words; the events; the save, and an
// old save's Town count guessed. The Sell page's looks: shop_tabs_ui_test.dart; the scene: town_scene_test.dart.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';

import 'hero_skill_helpers.dart';

/// A game in its [n]th Town after wave 40 (the Shop and the forge open), rich.
Game inTown(int n) => bareGame(Random(1))
  ..wave = 40
  ..gold = 1000000
  ..townAt = 41
  ..inTown = true
  ..townCount = n;

/// The next Town gone into and left at once (its recovery and its number).
void nextTown(Game g) {
  g
    ..leaveTown()
    ..townAt = g.wave + 1;
  expect(g.enterTown(), isTrue);
}

void main() {
  final rules = const TownRules().market;

  test('the identity follows the Town number, two a tier taking turns: Millbrook and Willowmere (summer) for Towns '
      '1-3, Ironvale and Ambergate (autumn) for 4-6, Frostgate and Highspire (winter) from 7 on', () {
    expect([for (var n = 1; n <= 12; n++) identityOf(n).key], [
      'millbrook', 'willowmere', 'millbrook', 'ironvale', 'ambergate', 'ironvale', //
      'frostgate', 'highspire', 'frostgate', 'highspire', 'frostgate', 'highspire',
    ]);
    expect([for (final t in townIdentities) t.season], [
      TownSeason.summer, TownSeason.summer, TownSeason.autumn, TownSeason.autumn, TownSeason.winter, TownSeason.winter,
    ]);
    expect(identityOf(0).key, 'millbrook', reason: 'before any Town: the first');
    expect([for (final t in townIdentities) t.wants.length], everyElement(4));
    expect(identityOf(1).wantsLine, 'Pays well for Boots, Potion, Gloves and Prayer Beads');
    expect(identityKeyed('frostgate')?.name, 'Frostgate');
    expect(identityKeyed('nowhere'), isNull);

    // The Town the prices read: the one the player is in, else the next.
    final g = bareGame(Random(1))..wave = 10;
    expect((g.townCount, g.marketTown, g.townIdentity.key, g.sceneIdentity.key), (0, 1, 'millbrook', 'millbrook'));
    g
      ..townAt = 11
      ..inTown = true
      ..townCount = 1;
    expect((g.marketTown, g.townIdentity.key), (1, 'millbrook'));
    g.leaveTown();
    expect((g.marketTown, g.townIdentity.key, g.sceneIdentity.key), (2, 'willowmere', 'millbrook'),
        reason: 'left: the next Town prices, the scene fading out is still the last');
  });

  test("an item's HPP: its parts at what the Shop pays for them and its gold; an enhanced one adds each step's gold "
      "and stone (the stone's own materials and gold); a small relic its recipe's", () {
    final g = inTown(1);
    int sell(Mat m) => g.townRules.materials[m]!.sell;
    expect(g.costOf(Item.sword), (parts: 2 * sell(Mat.boneShard) + 2 * sell(Mat.orcTooth), gold: 20));
    expect(g.hppOf(Item.sword), 80); // 2 x 15 + 2 x 15 parts, 20 gold
    expect(g.hppOf(Item.royalSword), 2 * 40 + 35 + 250);
    final mithril = (parts: sell(Mat.evilEye) + 2 * sell(Mat.ironScrap) + sell(Mat.graveSteel), gold: 1000);
    expect(g.costOf(Item.royalSword, 2),
        (parts: 115 + 2 * mithril.parts, gold: 250 + 500 + 1000 + 2 * mithril.gold), reason: '+2: two steps, a Mithril each');
    // +4 takes a Starmetal: a Soul Orb, a Lich Orb and a Mithril, and its own gold.
    final star = (parts: sell(Mat.soulOrb) + sell(Mat.lichOrb) + mithril.parts, gold: 3000 + mithril.gold);
    expect(g.costOf(Item.sword, 4), (
      parts: 60 + 3 * mithril.parts + star.parts,
      gold: 20 + 500 + 1000 + 1500 + 2500 + 3 * mithril.gold + star.gold,
    ));
    for (final r in Relic.values.where((r) => !r.pusaka && g.craftRecipe(r) != null)) {
      final recipe = g.craftRecipe(r)!;
      expect(g.costOf(r).gold, greaterThanOrEqualTo(recipe.gold), reason: '$r');
      expect(g.hppOf(r), greaterThan(0), reason: '$r');
    }
    expect((g.marketed(Item.sword), g.marketed(droppedRelics.first), g.marketed(Mat.slimeGel), g.marketed(Relic.titanBane)),
        (true, true, false, false), reason: 'the Smithy\'s goods only: no material, no Artifact');
    expect(g.freshMargin(Mat.slimeGel), 0);
  });

  test("a fresh price: the gold at the 1.3x floor, the parts at the Town's margin by grade (an enhanced item its own "
      'column, a small relic its tier), a wanted kind x1.3, kept in 1.3..4', () {
    expect((rules.floor, rules.top, rules.want, rules.most, rules.recover), (1.3, 4.0, 1.3, 24, 10));
    expect(rules.towns, [
      [3.0, 2.2, 1.6, 1.4], [3.0, 2.2, 1.6, 1.4], [3.0, 2.2, 1.6, 1.4], //
      [2.4, 2.4, 2.2, 1.8], [2.0, 2.4, 2.4, 1.9], [1.6, 2.8, 2.6, 2.0], [1.3, 2.0, 3.0, 2.2],
    ]);
    expect(rules.rowOf(40), rules.towns.last, reason: 'every Town past the table: its last row');
    final g = inTown(1); // Millbrook: Boots, Potion, Gloves, Prayer Beads
    expect([g.freshMargin(Item.sword), g.freshMargin(Item.boots), g.freshMargin(Item.royalSword)], [3.0, closeTo(3.9, 1e-9), 1.6]);
    expect(g.sellPrice(Item.sword), 206); // 20 x 1.3 + 60 x 3.0
    expect(g.sellPrice(Item.boots), 182); // 20 x 1.3 + 40 x 3.9
    expect(g.sellPrice(Item.royalSword), 509); // 250 x 1.3 + 115 x 1.6
    for (final n in [1, 2, 4, 5, 6, 7, 8, 20]) {
      g.townCount = n;
      final row = rules.rowOf(n), wants = identityOf(n).wants;
      for (final item in Item.values) {
        final want = wants.contains(item.slot) ? rules.want : 1.0;
        expect(g.freshMargin(item), closeTo((row[item.grade - 1] * want).clamp(1.3, 4.0), 1e-9), reason: 'Town $n $item');
        expect(g.freshMargin(item, 3), closeTo((row[3] * want).clamp(1.3, 4.0), 1e-9), reason: 'Town $n $item +3');
        final (:parts, :gold) = g.costOf(item);
        expect(g.sellPrice(item), (gold * 1.3 + parts * g.freshMargin(item)).round(), reason: 'Town $n $item');
        expect(g.sellPrice(item), greaterThanOrEqualTo((g.hppOf(item) * 1.3).floor()), reason: 'never under 1.3x');
        expect(g.sellPrice(item), lessThanOrEqualTo((g.hppOf(item) * 4.0).ceil()), reason: 'never over 4x');
      }
      for (final r in Relic.values.where((r) => !r.pusaka)) {
        expect(g.freshMargin(r), closeTo(row[g.relicTier(r).index].clamp(1.3, 4.0), 1e-9), reason: 'Town $n $r');
      }
    }
    // The late Towns pay for high-class goods; a beginner item there stays at the floor.
    g.townCount = 7; // Frostgate: Sword, Cap/Helm, Ring, Amulet
    expect([g.freshMargin(Item.royalSword), g.freshMargin(Item.royalSword, 3), g.freshMargin(Item.boots)],
        [closeTo(3.9, 1e-9), closeTo(2.86, 1e-9), 1.3]);
    expect(g.sellPrice(Item.royalSword), 774); // 250 x 1.3 + 115 x 3.9
    expect(g.sellPriceAt(Item.royalSword, 2), 8293); // 3,750 x 1.3 + 1,195 x 2.86
  });

  test('selling one exact product pulls its margin to the floor over 24 sales (gently at first), never under; '
      'a Sword, a Sword +2 and a Shield each their own', () {
    final g = inTown(1)..inventory.addAll({Item.sword: 30, Item.shield: 2});
    g.enhancedBag[(Item.sword, 2)] = 1;
    final fresh = g.freshMargin(Item.sword), hpp = g.hppOf(Item.sword);
    final margins = [for (var s = 0; s <= 30; s++) g.marginOf(Item.sword, 0, s)];
    for (var s = 1; s <= 24; s++) {
      expect(margins[s], lessThan(margins[s - 1]), reason: 'down with each sale ($s)');
    }
    expect(margins.first, fresh);
    expect(margins[24], closeTo(1.3, 1e-9));
    expect(margins.skip(24), everyElement(closeTo(1.3, 1e-9)), reason: 'never under the floor');
    expect(margins[6], closeTo(1.3 + (fresh - 1.3) * (1 - pow(6 / 24, 1.5)), 1e-9));
    expect(margins[6] - 1.3, greaterThan((fresh - 1.3) * 0.8), reason: 'a few sales cost little');

    final before = g.gold, sum = g.marketSum(Item.sword, 0, 30);
    expect(sum, [for (var s = 0; s < 30; s++) g.marketPrice(Item.sword, 0, s)].fold(0, (a, b) => a + b));
    expect(g.sell(Item.sword, 30), 30);
    expect(g.gold - before, sum, reason: 'each piece at its own step');
    expect([g.pressureOf(Item.sword), g.marginOf(Item.sword), g.sellPrice(Item.sword)], [24, closeTo(1.3, 1e-9), (hpp * 1.3).round()]);
    final sold = g.log.entries.whereType<StoreSold>().last;
    expect(sold.toJson(), {
      'v': eventVersion, 'kind': 'storeSold', 'wave': 40, 't': g.t, 'item': 'sword', 'relic': null, 'n': 30, //
      'gain': sum, 'margin': 3.0, 'pressure': 0,
    });
    expect(eventVersion, 14);
    expect((g.pressureOf(Item.sword, 2), g.pressureOf(Item.shield)), (0, 0), reason: 'the others untouched');
    expect(g.sellPriceAt(Item.sword, 2), g.marketPrice(Item.sword, 2));
    expect(g.sellAt(Item.sword, 2), 1);
    expect([g.pressureOf(Item.sword, 2), g.market.keys.toSet()], [1, {'sword', 'sword+2'}]);
    expect(g.log.entries.whereType<StoreSold>().last.toJson()['plus'], 2);
  });

  test("each new Town takes 10 off every product's pressure: back to fresh in the third Town after a flood", () {
    final g = inTown(1)
      ..inventory[Item.sword] = 24
      ..matsSeen.add(Mat.slimeGel);
    g.sell(Item.sword, 24);
    final mat = g.buyPrice(Mat.slimeGel);
    g.buy(Mat.slimeGel);
    expect([g.market, g.townCount], [{'sword': 24, 'mat:slimeGel': 1}, 1]);
    nextTown(g);
    expect([g.market, g.townCount, g.townIdentity.key], [{'sword': 14}, 2, 'willowmere']);
    expect(g.buyPrice(Mat.slimeGel), mat, reason: "the material's price back");
    nextTown(g);
    expect(g.market, {'sword': 4});
    nextTown(g);
    expect([g.market, g.townCount], [<String, int>{}, 4]);
    expect(g.marginOf(Item.sword), g.freshMargin(Item.sword), reason: 'fresh again (Ironvale, Town 4)');
    final entered = g.log.entries.whereType<TownEntered>().last;
    expect((entered.toJson()['n'], entered.toJson()['identity']), (4, 'ironvale'));
  });

  test("a material the Shop sells costs 10% more for each one bought (a Trophy 25%), rounded up to 5, back as the "
      'Towns pass', () {
    final g = inTown(1)..matsSeen.addAll([Mat.slimeGel, Mat.evilEye]);
    final base = g.shopMatPrice(Mat.slimeGel), trophy = g.shopMatPrice(Mat.evilEye);
    expect((base, trophy), (25, 750));
    int up5(double v) => (v / 5 - 1e-9).ceil() * 5;
    final paid = <int>[];
    for (var i = 0; i < 4; i++) {
      expect(g.buyPrice(Mat.slimeGel, 1), up5(base * (1 + 0.1 * (i + 1))), reason: 'the one after');
      paid.add(g.buyPrice(Mat.slimeGel));
      expect(g.buy(Mat.slimeGel), isTrue);
    }
    expect(paid, [25, 30, 30, 35]);
    expect(g.buyPrice(Mat.evilEye), 750);
    g.buy(Mat.evilEye);
    expect((g.buyPrice(Mat.evilEye), g.matFactor(Mat.evilEye)), (940, 1.25));
    g.market['mat:slimeGel'] = 99;
    expect(g.matFactor(Mat.slimeGel), closeTo(1 + 0.1 * 24, 1e-9), reason: 'the rise stops at 24');
  });

  test("the Sell page's words: Hot in the Town for a kind it wants (fresh 2x or more), Flooded past half way to the "
      'floor, else none', () {
    final g = inTown(1);
    expect([g.marketWord(Item.boots), g.marketWord(Item.windBoots), g.marketWord(Item.sword), g.marketWord(Item.boots, 1)],
        [MarketWord.hot, MarketWord.hot, null, null],
        reason: 'Boots wanted (3.9), Wind Boots too (1.6 x 1.3: 2.08); the Sword not; Boots +1 wanted but 1.4 x 1.3, under 2');
    g.market['boots'] = 12;
    expect(g.marketWord(Item.boots), MarketWord.hot, reason: '12 sold: 35% of the way down');
    g.market['boots'] = 16;
    expect(g.marketWord(Item.boots), MarketWord.flooded, reason: '16 sold: past half way');
    g.townCount = 7;
    expect((g.marketWord(Item.boots), g.marketWord(Mat.slimeGel)), (null, null),
        reason: 'fresh at the floor: never flooded; a material: no word');
  });

  test('the save keeps the market and the Town count; an old save starts fresh and guesses its count from its last '
      "Town's slot; a key it doesn't know or a pressure out of range is let go", () {
    final g = inTown(5)..market.addAll({'sword': 7, 'royalSword+2': 3, 'relic:${droppedRelics.first.name}': 2, 'mat:slimeGel': 1});
    final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    expect([j['market'], (j['town'] as Map)['n']], [g.market, 5]);
    final back = Game.fromJson(j);
    expect([back.market, back.townCount, back.townIdentity.key], [g.market, 5, 'ambergate']);

    final fresh = bareGame(Random(1));
    final none = jsonDecode(jsonEncode(fresh.toJson())) as Map<String, dynamic>;
    expect((none.containsKey('market'), (none['town'] as Map).containsKey('n')), (false, false));
    expect(Game.fromJson(none).townCount, 0);

    final odd = {...j, 'market': {'sword': 99, 'noSuchItem': 3, 'sword+x': 2, 'mat:gone': 1, 'boots': 0, 'bow': 'many'}};
    expect(Game.fromJson(odd).market, {'sword': 24});

    // Before the market: no `market`, no `town.n`. Its last Town's slot at wave 33 in a run whose Towns start counting
    // at wave 2: about four Towns ((33 - 2) / 7.5), and the one it is in.
    final old = {...j}..remove('market');
    old['town'] = {...(j['town'] as Map)}..remove('n');
    (old['town'] as Map)['last'] = 33;
    final was = Game.fromJson(old);
    expect([was.market, was.inTown, was.townCount], [<String, int>{}, true, 5]);
    (old['town'] as Map).remove('in');
    expect(Game.fromJson(old).townCount, 4);
  });

  test("town.json's market: the defaults; a number out of range keeps its default, a table that isn't rows of four "
      'margins too, noted', () {
    expect(TownRules.fromJson(jsonDecode(jsonEncode(const TownRules().toJson()))).market.toJson(), rules.toJson());
    final skipped = <String>[];
    final m = MarketRules.fromJson({'floor': 0.5, 'top': 2.0, 'most': 0, 'towns': [[1, 2, 3]]}, skipped);
    expect([m.floor, m.top, m.most, m.towns], [1.3, 2.0, 24, rules.towns]);
    expect(skipped, ['market.towns: not rows of four margins']);
    final mine = MarketRules.fromJson({'floor': 1.5, 'towns': [[2, 2, 2, 2]]}, []);
    expect([mine.floor, mine.rowOf(9)], [1.5, [2.0, 2.0, 2.0, 2.0]]);
  });
}
