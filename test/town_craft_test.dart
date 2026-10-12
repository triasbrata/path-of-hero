// The Smithy's Craft (decisions-log 233; lib/town.dart `extension Craft`; docs/loot-items-relics.md "Town and Smithy:
// Craft"): each refusal in the design's order, no limit a visit, the materials, items and gold taken (the forge's gold,
// decisions-log 245), the recipe's rows, every recipe craftable from exactly its own; the Town Shop's prices (the small
// relics at their tier's price, sold back at half their own recipe's gold; the items town.json's); Asah's cheapest-first
// take; the event, its log lines and the telemetry.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show logLine;
import 'package:tower_defense/telemetry.dart';

/// A game with the Towns on, [gold], in the Town before wave [wave] + 1 (the Smithy is open). Its relic recipes are the
/// forge's ([TownRules.forgeRecipe]: their own with the forge's gold; the forge's nine and the item recipes are
/// forge_data_test.dart's and forge_awaken_test.dart's).
Game inTown({int gold = 0, int wave = 0}) {
  final g = Game(Random(1), Random(101))
    ..wave = wave
    ..gold = gold;
  g.townAt = wave + 1;
  expect(g.enterTown(), isTrue);
  return g;
}

/// Puts exactly [relic]'s recipe in [g]'s bag: its materials, its items and its gold.
void giveRecipe(Game g, Relic relic, [int times = 1]) {
  final r = g.craftRecipe(relic)!;
  for (final MapEntry(key: m, value: n) in r.materials.entries) {
    g.materials[m] = (g.materials[m] ?? 0) + n * times;
  }
  for (final MapEntry(key: i, value: n) in r.items.entries) {
    g.inventory[i] = (g.inventory[i] ?? 0) + n * times;
  }
  g.gold += r.gold * times;
}

/// What a craft may change in [g], written out: the materials, items, gold and the relic bag.
String bags(Game g) => '${g.materials} ${g.inventory} ${g.gold} ${g.relicBag}';

/// Wins [g]'s next wave outright (one slime dealt with).
void winWave(Game g) {
  g.startWave();
  g.queue
    ..clear()
    ..add(('slime', Tier.normal));
  g.tick(0.05);
  g.enemies.single.gone = true;
  g.tick(0.05);
  expect(g.waveActive, isFalse);
}

/// A sink that keeps what it gets, through JSON as a file would.
class _Kept implements TelemetrySink {
  final records = <Map<String, dynamic>>[];

  @override
  void add(Map<String, Object?> record) => records.add(jsonDecode(jsonEncode(record)) as Map<String, dynamic>);

  @override
  Future<void> flush() async {}

  List<Map<String, dynamic>> of(String rec) => [for (final r in records) if (r['rec'] == rec) r];
}

void main() {
  test("each refusal in the design's order: over, town, no recipe, the first short material, the first short item, "
      'the gold; refused, nothing changes and the error sounds', () {
    void refused(Game g, Relic relic, CraftWhy why, String text) {
      final before = bags(g);
      final no = g.whyNotCraft(relic);
      expect((no?.why, no?.text, g.canCraft(relic)), (why, text, false), reason: text);
      g.sfx.clear();
      expect(g.craft(relic), isFalse);
      expect(bags(g), before, reason: text);
      expect(g.sfx, [Sfx.error], reason: text);
    }

    // Only in a Town: on the field, whatever the bag holds.
    final field = Game()
      ..gold = 100000;
    giveRecipe(field, Relic.fang);
    refused(field, Relic.fang, CraftWhy.town, Words.onlyInTown);
    field.lives = 0;
    refused(field, Relic.fang, CraftWhy.over, Words.gameOver);

    final g = inTown();
    refused(g, Relic.grail, CraftWhy.recipe, 'No recipe');
    expect(g.craftRows(Relic.grail), isEmpty);
    // Sweep (save key cleave): Wolf Claw 4, Leather Strap 3, Orc Tusk 2, Wolf Fang 1, a Sword, 700 gold.
    refused(g, Relic.cleave, CraftWhy.material, 'Need 4 Wolf Claw');
    g.materials[Mat.wolfClaw] = 2;
    refused(g, Relic.cleave, CraftWhy.material, 'Need 2 more Wolf Claw');
    expect(g.whyNotCraft(Relic.cleave)?.short, Mat.wolfClaw);
    g.materials.addAll({Mat.wolfClaw: 4, Mat.leatherStrap: 3, Mat.orcTusk: 1});
    refused(g, Relic.cleave, CraftWhy.material, 'Need 1 more Orc Tusk');
    g.materials[Mat.orcTusk] = 2;
    refused(g, Relic.cleave, CraftWhy.material, 'Need 1 Wolf Fang');
    g.materials[Mat.wolfFang] = 1;
    refused(g, Relic.cleave, CraftWhy.item, 'Need 1 Sword');
    expect(g.whyNotCraft(Relic.cleave)?.short, Item.sword);
    g.inventory[Item.sword] = 1;
    g.gold = 699;
    refused(g, Relic.cleave, CraftWhy.gold, Words.notEnoughGold);
    g.gold = 700;
    expect((g.whyNotCraft(Relic.cleave), g.canCraft(Relic.cleave)), (null, true));
    // The design's own examples: Venom short of its Bow.
    final v = inTown();
    giveRecipe(v, Relic.venom);
    v.inventory[Item.bow] = 0;
    refused(v, Relic.venom, CraftWhy.item, 'Need 1 Bow');
    // A material short comes before an item or the gold short; the game over before everything.
    final all = inTown();
    expect(all.whyNotCraft(Relic.giantSlayer)?.text, 'Need 4 Iron Scrap');
    all.lives = 0;
    expect(all.whyNotCraft(Relic.giantSlayer)?.why, CraftWhy.over);
  });

  test("craftRows: each material, then each item, as the recipe lists them, then the gold, with what's held", () {
    final g = inTown(gold: 640)
      ..materials.addAll({Mat.wolfClaw: 2, Mat.wolfFang: 3})
      ..inventory[Item.sword] = 1;
    expect(g.craftRows(Relic.cleave), <CraftRow>[
      (kind: Mat.wolfClaw, have: 2, need: 4),
      (kind: Mat.leatherStrap, have: 0, need: 3),
      (kind: Mat.orcTusk, have: 0, need: 2),
      (kind: Mat.wolfFang, have: 3, need: 1),
      (kind: Item.sword, have: 1, need: 1),
      (kind: null, have: 640, need: 700),
    ]);
    expect(g.craftRows(Relic.fang), <CraftRow>[
      (kind: Mat.batWing, have: 0, need: 2),
      (kind: Mat.slimeGel, have: 0, need: 2),
      (kind: null, have: 640, need: 200),
    ]);
  });

  test('craft takes the materials, the item and the gold, and puts the relic in the Bag (the last of a material '
      'leaves no entry); the clear sound', () {
    final g = inTown(gold: 5000)
      ..materials.addAll({Mat.wolfClaw: 6, Mat.leatherStrap: 3, Mat.orcTusk: 2, Mat.wolfFang: 1, Mat.slimeGel: 9})
      ..inventory.addAll({Item.sword: 2, Item.bow: 1})
      ..relicBag[Relic.cleave] = 1;
    g.sfx.clear();
    expect(g.craft(Relic.cleave), isTrue);
    expect(g.materials, {Mat.wolfClaw: 2, Mat.slimeGel: 9});
    expect((g.inventory[Item.sword], g.inventory[Item.bow], g.gold, g.relicBag[Relic.cleave]), (1, 1, 4300, 2));
    expect(g.sfx, [Sfx.clear]);
    expect(craftedLine(Relic.cleave), 'Sweep crafted!');
    expect(craftedLine(Relic.blessing), 'Holy Charm crafted!');
  });

  test('no limit a visit: crafted again while the bag can pay', () {
    final g = inTown();
    giveRecipe(g, Relic.fang, 5);
    for (var i = 1; i <= 5; i++) {
      expect(g.craft(Relic.fang), isTrue, reason: 'craft $i');
    }
    expect((g.relicBag[Relic.fang], g.gold), (5, 0));
    expect(g.materials, isEmpty);
    expect(g.whyNotCraft(Relic.fang)?.text, 'Need 2 Bat Wing');
    expect(g.craft(Relic.fang), isFalse);
  });

  test('each of the 11 crafts from exactly its recipe, and the 30 materials are all in some recipe', () {
    for (final relic in smallRelics) {
      final g = inTown();
      giveRecipe(g, relic);
      expect(g.craft(relic), isTrue, reason: relicNames[relic]);
      expect((g.materials.isEmpty, g.inventory.values.every((n) => n == 0), g.gold), (true, true, 0), reason: relicNames[relic]);
      expect(g.relicBag, {relic: 1}, reason: relicNames[relic]);
    }
    expect(smallRelics, hasLength(11));
    // town.json's own recipes (their gold is a small relic's sell price and Asah's order) name every dropped material.
    final g = Game();
    expect({for (final r in smallRelics) ...g.townRules.recipes[r.name]!.materials.keys}, droppedMats.toSet());
  });

  test("a patched recipe is the Smithy's: town.json's numbers", () {
    // A patch merges into the shipped recipe and its forge change: Fang's two materials at 1 each, a Potion added, and
    // 50 gold (the forge's gold, the one charged).
    final g = inTown(gold: 50)
      ..townRules = TownRules.patch({
        'recipes': {
          'fang': {'materials': {'batWing': 1, 'slimeGel': 1}, 'items': {'potion': 1}},
        },
        'relics': {
          'fang': {'forge': {'gold': 50}},
        },
      })
      ..materials.addAll({Mat.batWing: 1, Mat.slimeGel: 1});
    expect(g.whyNotCraft(Relic.fang)?.text, 'Need 1 Potion');
    g.inventory[Item.potion] = 1;
    expect(g.craft(Relic.fang), isTrue);
    expect((g.materials.isEmpty, g.inventory[Item.potion], g.gold, g.relicBag[Relic.fang]), (true, 0, 0, 1));
  });

  test('the Crafted event: its fields, the battle log ("Crafted Sweep (700 gold)", "Left town: 2 crafted"), and '
      "TownLeft's crafts and gold", () {
    final g = inTown();
    giveRecipe(g, Relic.cleave);
    giveRecipe(g, Relic.fang);
    expect(g.craft(Relic.cleave) && g.craft(Relic.fang), isTrue);
    final made = g.log.entries.whereType<Crafted>().toList();
    expect(made.first.toJson(), {
      'v': eventVersion,
      'kind': 'crafted',
      'wave': 0,
      't': made.first.t,
      'relic': 'cleave',
      'materials': {'wolfClaw': 4, 'leatherStrap': 3, 'orcTusk': 2, 'wolfFang': 1},
      'items': {'sword': 1},
      'gold': 700,
    });
    expect(made.map(logLine), ['Crafted Sweep (700 gold)', 'Crafted Fang (200 gold)']);
    expect(g.leaveTown(), isTrue);
    final left = g.log.entries.whereType<TownLeft>().single;
    expect(left.data['crafts'], {'cleave': 1, 'fang': 1});
    expect((left.data['craftSpent'], logLine(left)), (900, 'Left town: 2 crafted'));
    // The next Town starts its own count.
    g.townAt = 1;
    expect(g.enterTown() && g.leaveTown(), isTrue);
    final next = g.log.entries.whereType<TownLeft>().last;
    expect(next.data['crafts'], isEmpty);
    expect((next.data['craftSpent'], logLine(next)), (0, 'Left town'));
  });

  test("telemetry: the crafted event goes out; the next wave's record has crafted, materialsUsed and gold.craftSpent", () {
    expect(passedOn, contains(EventKind.crafted));
    final sink = _Kept();
    final g = inTown();
    TelemetryAdapter([sink], installId: 'i', session: 's', platform: 'test', now: () => DateTime.utc(2026, 10, 4)).attach(g);
    giveRecipe(g, Relic.fang, 2);
    giveRecipe(g, Relic.thorns);
    expect(g.craft(Relic.fang) && g.craft(Relic.fang) && g.craft(Relic.thorns), isTrue);
    expect(g.leaveTown(), isTrue);
    winWave(g);
    final events = [for (final r in sink.of('event')) r['event'] as Map<String, dynamic>];
    expect([for (final e in events) if (e['kind'] == 'crafted') (e['relic'], e['gold'])], [('fang', 200), ('fang', 200), ('thorns', 200)]);
    final left = events.singleWhere((e) => e['kind'] == 'townLeft');
    expect(left['crafts'], {'fang': 2, 'thorns': 1});
    expect(left['craftSpent'], 600);
    final w = sink.of('wave').single;
    expect((w['wave'], (w['gold'] as Map)['craftSpent']), (1, 600));
    expect(w['crafted'], {'fang': 2, 'thorns': 1});
    expect(w['materialsUsed'], {'batWing': 4, 'slimeGel': 7, 'boneShard': 2});
  });

  group('prices', () {
    /// A game at wave 15 in a Town (the Shop open), with plenty of gold.
    Game shop() => inTown(gold: 1000000, wave: storeFrom);

    test("Towns on: the Smithy's goods have no Shop price (decisions-log 329): never on the shelf, a sale at the "
        "market's price; an old save's count bought is kept and moves nothing", () {
      final g = shop();
      for (final r in smallRelics) {
        // A sale at the market's price (decisions-log 326; market_test.dart): its cost times the Town's demand.
        expect((g.basePrice(r), g.buyPrice(r), g.buyPrice(r, 1), g.sellPrice(r)), (0, 0, 0, g.marketPrice(r)), reason: relicNames[r]);
      }
      expect((g.whyNotBuy(Relic.cleave), g.buy(Relic.cleave), g.gold), (StoreRefusal.notSold, false, 1000000));
      g.storeBought[Relic.cleave] = 2;
      final back = Game.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
      expect((back.storeBought[Relic.cleave], back.buyPrice(Relic.cleave)), (2, 0));
      g.relicBag[Relic.cleave] = 2;
      final two = g.marketSum(Relic.cleave, 0, 2);
      expect(g.sell(Relic.cleave, 2), 2);
      expect(g.gold, 1000000 + two);
      // The items the same; the Artifacts as today.
      expect((g.whyNotBuy(Item.sword), g.buyPrice(Item.sword), g.sellPrice(Item.sword)), (StoreRefusal.notSold, 0, g.marketPrice(Item.sword)));
      expect((g.buyPrice(Relic.grail), g.sellPrice(Relic.grail), g.sellPrice(Relic.ironBanner)), (24000, 12000, 8000));
    });

    test("Towns on: town.json's numbers (a patched recipe); an older file's tier and item prices are read as nothing", () {
      final g = shop()
        ..townRules = TownRules.patch({
          'tiers': {'basic': {'shop': 10000, 'shopRise': 0.5, 'sellShare': 0.25}},
          'recipes': {'fang': {'gold': 800}},
          'shop': {'itemPrice': 3000, 'itemRise': 300, 'itemSellShare': 0.4},
        });
      // A recipe's gold is in the relic's cost, at the floor; the Shop prices of town.json before decisions-log 329
      // (`tiers`, the shop's `itemPrice`, `itemRise` and `itemSellShare`) are gone.
      expect(g.costOf(Relic.fang).gold, g.craftRecipe(Relic.fang)!.gold);
      expect((g.buyPrice(Relic.fang), g.buyPrice(Item.potion)), (0, 0));
      expect((g.sellPrice(Relic.fang), g.sellPrice(Item.potion)), (g.marketPrice(Relic.fang), g.marketPrice(Item.potion)));
      expect(g.townRules.toJson().containsKey('tiers'), isFalse);
      expect(g.townRules.shop.toJson().keys, ['from', 'matMarkup', 'matRise']);
    });
  });

  group("Asah's take", () {
    test('Towns on: the cheapest first by craft gold, the most held first among one price; a dearer one only once the '
        'cheaper are gone', () {
      final g = Game();
      g.relicBag.addAll({Relic.fang: 3, Relic.thorns: 5, Relic.fury: 4, Relic.cleave: 5, Relic.lastStand: 2, Relic.giantSlayer: 1});
      expect(g.asahRelicsInBag, 20);
      expect(g.asahTake, {Relic.thorns: 5, Relic.fang: 3, Relic.fury: 2});
      expect(g.asahTake.keys, [Relic.thorns, Relic.fang, Relic.fury], reason: 'the order taken');
      g.relicBag
        ..clear()
        ..addAll({Relic.giantSlayer: 20, Relic.guard: 1, Relic.venom: 2});
      expect(g.asahTake, {Relic.guard: 1, Relic.venom: 2, Relic.giantSlayer: 7});
      g.relicBag
        ..clear()
        ..addAll({Relic.cleave: 1, Relic.venom: 1, Relic.lastStand: 5, Relic.blessing: 5, Relic.giantSlayer: 5});
      expect(g.asahTake, {Relic.cleave: 1, Relic.venom: 1, Relic.lastStand: 4, Relic.blessing: 4},
          reason: 'Iron Will and Holy Charm (3,000) before Giant Slayer (3,500), evenly');
      g.relicBag
        ..clear()
        ..addAll({Relic.spiritWard: 3, Relic.manaSiphon: 2});
      expect(g.asahRelicsInBag, 5);
      expect(g.asahTake, {Relic.spiritWard: 3, Relic.manaSiphon: 2});
    });

    test("Towns on: a Sharpen takes them from the Bag; the Smithy's seven count toward its 10", () {
      final g = Game()
        ..gold = 60000;
      g.pusaka[Relic.grail] = OwnedPusaka();
      g.relicBag.addAll({Relic.cleave: 4, Relic.blessing: 6, Relic.fang: 1});
      expect((g.asahRelicsInBag, g.whyNotAsah(Relic.grail)), (11, null));
      expect(g.asah(Relic.grail), isTrue);
      expect((g.relicBag[Relic.fang], g.relicBag[Relic.cleave], g.relicBag[Relic.blessing], g.pusaka[Relic.grail]!.stars), (0, 0, 1, 2));
      expect(g.log.entries.whereType<PusakaAsah>().single.relics, {Relic.fang: 1, Relic.cleave: 4, Relic.blessing: 5});
    });

  });

  group("the Smithy page's words (decisions-log 235)", () {
    test('who each material comes from: its monster, the Necromancer for the Lich Orb, a Trophy\'s rank', () {
      final g = inTown();
      expect([g.matFrom(Mat.slimeGel), g.matFrom(Mat.wolfClaw), g.matFrom(Mat.wargFang), g.matFrom(Mat.tealCloth), g.matFrom(Mat.darkGem)],
          ['Slime', 'Werewolf', 'Orc Rider', 'Necro Healer', 'Necromancer']);
      expect([g.matFrom(Mat.evilEye), g.matFrom(Mat.soulOrb), g.matFrom(Mat.lichOrb)], ['Mini Boss', 'Boss', 'Necromancer']);
      for (final m in droppedMats) {
        expect(g.matFrom(m), isNotEmpty, reason: '$m');
      }
    });
  });
}
