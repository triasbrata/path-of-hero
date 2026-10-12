// Enhance (decisions-log 255; lib/enhance.dart, lib/game.dart's items per plus; docs/loot-items-relics.md "The forge:
// Enhance"), with the Towns on (the forge comes with them; its off switch is gone, decisions-log 296): what each step
// costs and does, the cap at +5, that it
// always works, its refusals, the stones, an enhanced item on a type (its stats, the swap by plus at the cap, the Cap's
// and the Ring's chain), the Shop's price, the events, and the save (a load without the plus keys is all +0).
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show logLine;
import 'package:tower_defense/telemetry.dart';

/// A game with the Towns and the forge on, [gold], at [wave].
Game forge({int gold = 0, int wave = 30}) => Game(Random(1), Random(101))
  ..gold = gold
  ..wave = wave;

/// [forge] in the Town before wave [wave] + 1 (the Smithy open).
Game forgeInTown({int gold = 0, int wave = 30}) {
  final g = forge(gold: gold, wave: wave);
  g.townAt = wave + 1;
  expect(g.enterTown(), isTrue);
  return g;
}

/// [type]'s grade sets 1 to [level], as a list of items (what a type at Awaken [level] holds).
List<Item> sets(Game g, String type, int level) => [
      for (var l = 1; l <= level; l++)
        for (final MapEntry(key: item, value: n) in g.gradeSet(type, l).entries) ...List.filled(n, item),
    ];

/// Puts every step's stone from +[from] to +[to] in [g]'s bag, and their gold.
void giveSteps(Game g, int from, int to) {
  for (var p = from; p < to; p++) {
    final (:stone, :gold) = g.enhanceCost(p)!;
    g.materials[stone] = (g.materials[stone] ?? 0) + 1;
    g.gold += gold;
  }
}

/// A save of [g] through JSON, as the file holds it.
Map<String, dynamic> saved(Game g) => jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;

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
  test("each step adds a tenth of the item's own bonus: a factor's gain grows, a cut deepens, a flat one grows by itself",
      () {
    final g = forge();
    List<double> steps(Item item) => [for (var p = 0; p <= 5; p++) g.itemK(item, p)];
    void near(List<double> got, List<double> want, String why) {
      for (final (i, v) in want.indexed) {
        expect(got[i], closeTo(v, 1e-12), reason: '$why +$i');
      }
    }

    near(steps(Item.royalSword), [1.32, 1.352, 1.384, 1.416, 1.448, 1.48], 'Royal Sword');
    near(steps(Item.royalGloves), [0.75, 0.725, 0.70, 0.675, 0.65, 0.625], 'Royal Gloves');
    near(steps(Item.royalShield), [6, 6.6, 7.2, 7.8, 8.4, 9], 'Royal Shield');
    near(steps(Item.goldAmulet), [1.12, 1.132, 1.144, 1.156, 1.168, 1.18], 'Gold Amulet');
    near(steps(Item.elixir), [12, 13.2, 14.4, 15.6, 16.8, 18], 'Elixir');
    near(steps(Item.royalRing), [0.2, 0.22, 0.24, 0.26, 0.28, 0.3], 'Royal Ring');
    near(steps(Item.royalHelm), [0.93, 0.923, 0.916, 0.909, 0.902, 0.895], 'Royal Helm');
    near(steps(Item.sword), [1.25, 1.275, 1.3, 1.325, 1.35, 1.375], 'a grade-I Sword');
    for (final item in Item.values) {
      expect(g.itemK(item, 0), g.townRules.items[item]!.effect, reason: '+0 is the number itself, bit for bit: $item');
    }
    // A patched step share.
    final half = forge()..townRules = TownRules.patch({'enhance': {'per': 0.5}});
    expect(half.itemK(Item.royalSword, 2), closeTo(1.64, 1e-12));
  });

  test('each step costs its stone and gold: Mithril for +1 to +3, Starmetal for +4 and +5, 20,500 gold in all; none past +5',
      () {
    final g = forge();
    expect([for (var p = 0; p < 5; p++) g.enhanceCost(p)], [
      (stone: Mat.mithril, gold: 500),
      (stone: Mat.mithril, gold: 1000),
      (stone: Mat.mithril, gold: 1500),
      (stone: Mat.starmetal, gold: 2500),
      (stone: Mat.starmetal, gold: 4000),
    ]);
    expect((g.enhanceCost(5), g.enhanceCost(-1), g.plusMost), (null, null, 5));
    // From +0 to +5 in all (forge-design §12): the steps' gold, and each stone made from its recipe (a Starmetal's Mithril
    // too).
    final mats = <Mat, int>{};
    var gold = 0;
    void make(Mat stone) {
      final r = g.stoneRecipe(stone)!;
      gold += r.gold;
      for (final MapEntry(key: m, value: n) in r.materials.entries) {
        for (var i = 0; i < n; i++) {
          if (m.crafted) {
            make(m);
          } else {
            mats[m] = (mats[m] ?? 0) + 1;
          }
        }
      }
    }

    for (var p = 0; p < 5; p++) {
      gold += g.enhanceCost(p)!.gold;
      make(g.enhanceCost(p)!.stone);
    }
    expect(gold, 20500);
    expect(mats, {Mat.evilEye: 5, Mat.soulOrb: 2, Mat.lichOrb: 2, Mat.ironScrap: 10, Mat.graveSteel: 5});
    expect(g.enhanceRows(3), [(kind: Mat.starmetal, have: 0, need: 1), (kind: null, have: 0, need: 2500)]);
    expect(g.enhanceRows(5), isEmpty);
    // The stones' recipes (town.json `enhance.stones`).
    expect(g.stoneRecipe(Mat.mithril)!.toJson(), {'materials': {'evilEye': 1, 'ironScrap': 2, 'graveSteel': 1}, 'gold': 1000});
    expect(g.stoneRecipe(Mat.starmetal)!.toJson(), {'materials': {'soulOrb': 1, 'lichOrb': 1, 'mithril': 1}, 'gold': 3000});
    expect(g.stoneRecipe(Mat.evilEye), isNull);
  });

  test('Enhance opens once wave 30 is won (town.json `enhance.from`)', () {
    expect(forge(wave: 29).enhanceOpen, isFalse);
    expect(forge(wave: 30).enhanceOpen, isTrue);
    expect(forge(wave: 44).enhanceOpen, isTrue);
    final fighting = forge(wave: 30)..queue.add(('slime', Tier.normal));
    expect(fighting.enhanceOpen, isFalse, reason: 'wave 30 still being fought');
    expect((forge(wave: 12)..townRules = TownRules.patch({'enhance': {'from': 12}})).enhanceOpen, isTrue);
  });

  test('an item goes up to +5 one step at a time, each its own Bag stack, and every step works (no dice)', () {
    for (final seed in [1, 2, 3]) {
      final g = Game(Random(seed), Random(seed + 100))
        ..gold = 0
        ..wave = 30
        ..townAt = 31;
      expect(g.enterTown(), isTrue);
      g.inventory[Item.royalSword] = 2;
      giveSteps(g, 0, 5);
      for (var p = 0; p < 5; p++) {
        final gold = g.gold;
        expect(g.enhance(Item.royalSword, p), isTrue, reason: 'seed $seed +$p');
        expect(g.gold, gold - g.enhanceCost(p)!.gold);
      }
      expect((g.bagOf(Item.royalSword), g.bagOf(Item.royalSword, 5)), (1, 1));
      expect(g.enhancedHeld, [(Item.royalSword, 5)], reason: 'the steps in between left no stack');
      expect(g.gold, 0);
      expect(g.materials, isEmpty, reason: 'every stone taken');
      expect(g.whyNotEnhance(Item.royalSword, 5)!.text, 'Max: +5');
      expect(g.enhance(Item.royalSword, 5), isFalse);
      expect(g.sfx.last, Sfx.error);
    }
  });

  test('the steps in between keep their own stacks: +0, +1 and +2 side by side', () {
    final g = forgeInTown(gold: 99999);
    g.inventory[Item.sword] = 3;
    g.materials[Mat.mithril] = 3;
    expect(g.enhance(Item.sword, 0) && g.enhance(Item.sword, 0) && g.enhance(Item.sword, 1), isTrue);
    expect([g.bagOf(Item.sword), g.bagOf(Item.sword, 1), g.bagOf(Item.sword, 2)], [1, 1, 1]);
    expect(g.enhancedHeld, [(Item.sword, 1), (Item.sword, 2)]);
    g.inventory[Item.royalShield] = 1;
    expect(g.enhancedHeld, [(Item.sword, 1), (Item.sword, 2)], reason: '+0 is the inventory');
    expect(itemLabel(Item.sword, 2), '${itemNames[Item.sword]} +2');
    expect(itemLabel(Item.sword), itemNames[Item.sword]);
  });

  test('why an Enhance is refused, in order: game over, not in a Town, not open, none held, at +5, the '
      'stone, the gold', () {
    String? why(Game g, [Item item = Item.royalSword, int plus = 0]) => g.whyNotEnhance(item, plus)?.text;
    final g = forgeInTown();
    expect(why(g), 'Need 1 ${itemNames[Item.royalSword]}');
    g.inventory[Item.royalSword] = 1;
    expect(why(g), 'Need 1 ${Mat.mithril.label}');
    expect(g.whyNotEnhance(Item.royalSword, 0)!.why, CraftWhy.material);
    g.materials[Mat.mithril] = 1;
    expect(why(g), Words.notEnoughGold);
    g.gold = 500;
    expect(why(g), isNull);
    expect(g.canEnhance(Item.royalSword, 0), isTrue);
    expect(why(forgeInTown(wave: 29)), 'Opens after wave 30');
    expect(forgeInTown(wave: 29).whyNotEnhance(Item.royalSword, 0)!.why, CraftWhy.closed);
    expect(why(forge()), Words.onlyInTown, reason: 'between Towns');
    g.lives = 0;
    expect(why(g), Words.gameOver);
    final at5 = forgeInTown()..enhancedBag[(Item.ring, 5)] = 1;
    expect((at5.whyNotEnhance(Item.ring, 5)!.why, at5.whyNotEnhance(Item.ring, 5)!.text), (CraftWhy.top, 'Max: +5'));
    // A refused Enhance changes nothing.
    final r = forgeInTown(gold: 400)
      ..inventory[Item.royalSword] = 1
      ..materials[Mat.mithril] = 1;
    expect(r.enhance(Item.royalSword, 0), isFalse);
    expect(r.gold, 400);
    expect(r.materials, {Mat.mithril: 1});
    expect(r.inventory, {Item.royalSword: 1});
    expect(r.enhancedBag, isEmpty);
  });

  test('the stones: made at the Smithy from their recipe once Enhance is open, into the materials, never seen as a drop',
      () {
    final g = forgeInTown(gold: 4000);
    g.materials.addAll({Mat.evilEye: 1, Mat.ironScrap: 2, Mat.graveSteel: 1, Mat.soulOrb: 1, Mat.lichOrb: 1});
    expect(g.stoneCraftRows(Mat.starmetal), [
      (kind: Mat.soulOrb, have: 1, need: 1),
      (kind: Mat.lichOrb, have: 1, need: 1),
      (kind: Mat.mithril, have: 0, need: 1),
      (kind: null, have: 4000, need: 3000),
    ]);
    expect(g.whyNotCraftStone(Mat.starmetal)!.text, 'Need 1 ${Mat.mithril.label}');
    expect(g.craftStone(Mat.mithril), isTrue);
    expect((g.materials[Mat.mithril], g.materials.containsKey(Mat.evilEye), g.gold), (1, false, 3000));
    expect(g.craftStone(Mat.starmetal), isTrue);
    expect(g.materials, {Mat.starmetal: 1});
    expect(g.gold, 0);
    expect(g.matsSeen, isEmpty, reason: 'a stone never drops');
    expect(g.whyNotCraftStone(Mat.mithril)!.text, 'Need 1 ${Mat.evilEye.label}');
    expect(forgeInTown(wave: 29).whyNotCraftStone(Mat.mithril)!.text, 'Opens after wave 30');
    expect(forge().whyNotCraftStone(Mat.mithril)!.why, CraftWhy.town);
    expect(forgeInTown().whyNotCraftStone(Mat.evilEye)!.why, CraftWhy.recipe, reason: 'not a stone');
  });

  test('on a type an enhanced item fights at its plus', () {
    final g = forge()..upgrades['knight'] = sets(forge(), 'knight', 3);
    final plain = g.statsOf('knight');
    expect(g.plusesOn('knight', Item.royalSword), [0, 0]);
    g.upgradePlus['knight'] = {Item.royalSword: [5], Item.royalShield: [5, 2]};
    expect(g.plusesOn('knight', Item.royalSword), [5, 0]);
    final up = g.statsOf('knight');
    expect(up.dmg, closeTo(plain.dmg * 1.48 / 1.32, 1e-9));
    expect(up.def, closeTo(plain.def + 3 + 1.2, 1e-9), reason: 'Royal Shield 6 → 9 at +5 and 7.2 at +2');
    expect((up.hp, up.speed, up.rate), (plain.hp, plain.speed, plain.rate));
  });

  test('giving an enhanced item: from its own stack, onto the type with its plus, the Awaken counts unchanged', () {
    final g = forge();
    g.enhancedBag[(Item.sword, 3)] = 1;
    final now = g.statsOf('soldier');
    expect(g.useItem(Item.sword, 'soldier', plus: 3), isTrue);
    expect(g.upgrades['soldier'], [Item.sword]);
    expect(g.upgradePlus['soldier'], {Item.sword: [3]});
    expect(g.enhancedBag, isEmpty);
    expect(g.statsOf('soldier').dmg, closeTo(now.dmg * 1.325, 1e-9));
    expect(g.useItem(Item.sword, 'soldier', plus: 3), isFalse, reason: 'none left at +3');
    g.inventory[Item.sword] = 1;
    expect(g.useItem(Item.sword, 'soldier'), isTrue);
    expect(g.countOf('soldier', Item.sword), 2);
    expect(g.plusesOn('soldier', Item.sword), [3, 0]);
    expect(g.awakenProgress('soldier')[Item.sword], (2, 2), reason: 'an enhanced item counts as its item');
  });

  test('at the cap a higher plus swaps out the lowest-plus copy, which goes back to the Bag at its plus; an equal or '
      'lower plus is refused', () {
    // A knight at Awaken 2 holding its 2 Royal Swords, grade III's cap.
    final g = forge(), held = sets(g, 'knight', 2);
    g.upgrades['knight'] = [...held, Item.royalSword, Item.royalSword];
    expect((g.awakenLevel('knight'), g.heldOf('knight', Item.royalSword), g.capOf('knight', Item.royalSword)), (2, 2, 2));
    final price = g.priceOf('knight'), level = g.awakenLevel('knight');
    expect(g.whyNot(Item.royalSword, 'knight'), Refusal.maxed);
    expect(g.swapOut('knight', Item.royalSword, 3), Item.royalSword);
    expect(g.priceWith('knight', Item.royalSword, plus: 3), price, reason: 'a swap adds no item');
    final preview = g.assignPreview(Item.royalSword, 'knight', plus: 3);
    expect(preview.why, assignRefusals.empty, reason: 'none in the Bag yet');
    g.enhancedBag.addAll({(Item.royalSword, 3): 1, (Item.royalSword, 1): 1, (Item.royalSword, 2): 2});
    final shown = g.assignPreview(Item.royalSword, 'knight', plus: 3);
    expect(shown.why, isNull);
    expect(shown.stats.map((s) => s.$1), [StatKind.dmg]);
    expect(shown.count, ((2, 2), (2, 2)));
    expect((g.upgradePlus['knight'], g.upgrades['knight']!.length), (null, held.length + 2), reason: 'tried on, then taken back');
    final plain = g.statsOf('knight').dmg;
    expect(g.useItem(Item.royalSword, 'knight', plus: 3), isTrue);
    expect(g.plusesOn('knight', Item.royalSword), [3, 0]);
    expect(g.inventory[Item.royalSword], 1, reason: 'the Royal Sword +0 back in the Bag');
    expect(g.useItem(Item.royalSword, 'knight', plus: 1), isTrue);
    expect(g.plusesOn('knight', Item.royalSword), [3, 1]);
    expect(g.inventory[Item.royalSword], 2);
    expect(g.useItem(Item.royalSword, 'knight', plus: 2), isTrue);
    expect(g.plusesOn('knight', Item.royalSword), [3, 2]);
    expect((g.bagOf(Item.royalSword, 1), g.bagOf(Item.royalSword, 2), g.bagOf(Item.royalSword, 3)), (1, 1, 0));
    expect(g.whyNot(Item.royalSword, 'knight', plus: 2), Refusal.maxed, reason: 'no lower plus there');
    expect(g.useItem(Item.royalSword, 'knight', plus: 2), isFalse);
    expect(g.useItem(Item.royalSword, 'knight'), isFalse);
    expect((g.awakenLevel('knight'), g.priceOf('knight'), g.countOf('knight', Item.royalSword)), (level, price, 2));
    expect(g.statsOf('knight').dmg, closeTo(plain * (1 + 0.32 * 1.3) * (1 + 0.32 * 1.2) / (1.32 * 1.32), 1e-9));
  });

  test("the Cap's and the Ring's chain stays: at the cap the lowest by grade, then plus, swaps out", () {
    final g = forge();
    g.inventory[Item.steelHelm] = 1;
    g.enhancedBag.addAll({(Item.leatherCap, 5): 1, (Item.steelHelm, 1): 1});
    g.inventory[Item.royalHelm] = 1;
    expect(g.useItem(Item.steelHelm, 'soldier'), isTrue);
    expect(g.whyNot(Item.leatherCap, 'soldier', plus: 5), Refusal.awakenFirst, reason: 'a lower grade never swaps, whatever its plus');
    expect(g.swapOut('soldier', Item.steelHelm, 1), Item.steelHelm);
    expect(g.useItem(Item.steelHelm, 'soldier', plus: 1), isTrue);
    expect(g.upgrades['soldier'], [Item.steelHelm]);
    expect(g.upgradePlus['soldier'], {Item.steelHelm: [1]});
    expect(g.inventory[Item.steelHelm], 1, reason: 'the Steel Helm +0 back in the Bag');
    expect(g.useItem(Item.royalHelm, 'soldier'), isTrue, reason: 'a better grade swaps out the Steel Helm +1');
    expect(g.upgrades['soldier'], [Item.royalHelm]);
    expect((g.upgradePlus['soldier'], g.bagOf(Item.steelHelm, 1)), (null, 1));
  });

  test("the Shop buys an enhanced item at the market's price for that exact product (decisions-log 326): its steps' "
      "gold and stones in its cost, the enhanced column's margin, each piece at its own step", () {
    final g = forgeInTown();
    final base = g.sellPrice(Item.royalSword);
    expect(g.sellPriceAt(Item.royalSword, 0), base);
    // +1 in the first Town: the Royal Sword's 115 of parts and 250 gold, a step's 500 gold and a Mithril (its Evil Eye,
    // two Iron Scraps and a Grave Steel, 540, and its 1,000 gold); the gold at 1.3, the parts at the enhanced 1.4.
    expect(g.costOf(Item.royalSword, 1), (parts: 115 + 540, gold: 250 + 500 + 1000));
    expect(g.sellPriceAt(Item.royalSword, 1), (1750 * 1.3 + 655 * 1.4).round());
    expect(g.sellPriceAt(Item.royalSword, 5), g.marketPrice(Item.royalSword, 5));
    g.enhancedBag[(Item.royalSword, 2)] = 2;
    final two = g.marketSum(Item.royalSword, 2, 2);
    expect(g.sellAt(Item.royalSword, 2, 5), 2);
    expect(g.gold, two);
    expect(g.pressureOf(Item.royalSword, 2), 2);
    expect(g.enhancedBag, isEmpty);
    expect(g.whyNotSellAt(Item.royalSword, 2), StoreRefusal.none);
    expect(forge().whyNotSellAt(Item.royalSword, 2), StoreRefusal.town);
  });

  test('a stone made and an item enhanced are events: the battle log, the telemetry and the wave record', () {
    final sink = _Kept(), events = <GameEvent>[];
    // Enhance patched open from the start, so the wave played after is an early one.
    final g = forgeInTown(gold: 1500, wave: 0)..townRules = TownRules.patch({'enhance': {'from': 0}});
    g.listeners.add(events.add);
    TelemetryAdapter([sink], installId: 'i', session: 's', platform: 'test', now: () => DateTime.utc(2026, 10, 7)).attach(g);
    g.materials.addAll({Mat.evilEye: 1, Mat.ironScrap: 2, Mat.graveSteel: 1});
    g.inventory[Item.royalSword] = 1;
    expect(g.craftStone(Mat.mithril) && g.enhance(Item.royalSword, 0), isTrue);
    expect(logLine(events.whereType<StoneCrafted>().single), 'Crafted ${Mat.mithril.label} (1,000 gold)');
    expect(logLine(events.whereType<ItemEnhanced>().single), 'Enhanced ${itemNames[Item.royalSword]} to +1 (500 gold)');
    expect(passedOn, containsAll([EventKind.stoneCrafted, EventKind.itemEnhanced]));
    expect(g.leaveTown(), isTrue);
    g.startWave();
    g.queue
      ..clear()
      ..add(('slime', Tier.normal));
    g.tick(0.05);
    g.enemies.single.gone = true;
    g.tick(0.05);
    final ev = [for (final r in sink.of('event')) r['event'] as Map<String, dynamic>];
    expect(ev.singleWhere((e) => e['kind'] == 'stoneCrafted'), containsPair('materials', {'evilEye': 1, 'ironScrap': 2, 'graveSteel': 1}));
    final up = ev.singleWhere((e) => e['kind'] == 'itemEnhanced');
    expect((up['item'], up['plus'], up['stone'], up['gold']), ('royalSword', 1, 'mithril', 500));
    final w = sink.of('wave').single;
    expect(w['crafted'], {'mithril': 1});
    expect(w['materialsUsed'], {'evilEye': 1, 'ironScrap': 2, 'graveSteel': 1, 'mithril': 1});
    expect((w['gold'] as Map)['craftSpent'], 1500);
  });

  test('the save: the plus keys round-trip; a save without them loads all +0', () {
    final g = forge();
    g.upgrades['knight'] = [Item.royalSword, Item.royalSword, Item.royalShield];
    g.upgradePlus['knight'] = {Item.royalSword: [4, 2]};
    g.enhancedBag.addAll({(Item.ring, 1): 2, (Item.elixir, 5): 1});
    final j = saved(g);
    expect(j['bagPlus'], [
      {'item': 'elixir', 'plus': 5, 'n': 1},
      {'item': 'ring', 'plus': 1, 'n': 2},
    ]);
    expect(j['upgradePlus'], {
      'knight': [
        {'item': 'royalSword', 'plus': 4, 'n': 1},
        {'item': 'royalSword', 'plus': 2, 'n': 1},
      ],
    });
    expect(j['v'], Game.saveVersion);
    final back = Game.fromJson(j);
    expect(back.upgradePlus, g.upgradePlus);
    expect(back.enhancedBag, g.enhancedBag);
    expect(back.statsOf('knight').dmg, closeTo(g.statsOf('knight').dmg, 1e-9));
    expect(saved(back)['upgradePlus'], j['upgradePlus']);

    // Without the keys (a save from before Enhance): everything +0, the items all there.
    final old = Map<String, dynamic>.of(j)
      ..remove('bagPlus')
      ..remove('upgradePlus');
    final plain = Game.fromJson(old);
    expect(plain.upgradePlus, isEmpty);
    expect(plain.enhancedBag, isEmpty);
    expect(plain.upgrades['knight'], [Item.royalSword, Item.royalSword, Item.royalShield]);

    // Nothing enhanced: no key.
    expect(saved(forge()).keys, isNot(anyOf(contains('bagPlus'), contains('upgradePlus'))));

    // A bad entry: an unknown item is skipped, a plus over the most is kept at it, and a type keeps no more enhanced
    // copies than it holds (its highest).
    final bad = saved(forge()..upgrades['archer'] = [Item.bow])
      ..['bagPlus'] = [
        {'item': 'noSuchItem', 'plus': 1, 'n': 1},
        {'item': 'bow', 'plus': 9, 'n': 1},
        {'item': 'bow', 'plus': 0, 'n': 1},
        'junk',
      ]
      ..['upgradePlus'] = {
        'archer': [
          {'item': 'bow', 'plus': 1, 'n': 1},
          {'item': 'bow', 'plus': 3, 'n': 1},
          {'item': 'greatBow', 'plus': 2, 'n': 1},
        ],
      };
    final read = Game.fromJson(bad);
    expect(read.enhancedBag, {(Item.bow, 5): 1});
    expect(read.upgradePlus, {'archer': {Item.bow: [3]}});
  });
}
