// The forge's items and Awaken by grade (decisions-log 249; lib/game.dart's awaken rules, lib/town.dart's Craft;
// docs/loot-items-relics.md "The forge: Awaken by grade, items crafted"), in every game (the forge comes with the Towns;
// its off switch is gone, decisions-log 296, 321): each type's grade sets (its recipe + its own new kind, grade III at two thirds rounded up), Awaken L from exactly
// the grade-L set, the caps per kind and grade and when a grade opens, the Cap's and the Ring's chain and swap at the cap,
// every item's recipe and gold, the Stats each grade gives (Knight swords 3 + 3 + 2 = x7.137), the event and its
// telemetry.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_defense/game.dart';
import 'package:tower_defense/main.dart' show logLine;
import 'package:tower_defense/telemetry.dart';

import 'hero_skill_helpers.dart';

/// A game with the Towns and the forge on, [gold].
Game forge({int gold = 0}) => Game(Random(1), Random(101))
  ..gold = gold;

/// [forge] in the Town before wave [wave] + 1 (the Smithy open).
Game forgeInTown({int gold = 0, int wave = 0}) {
  final g = forge(gold: gold)..wave = wave;
  g.townAt = wave + 1;
  expect(g.enterTown(), isTrue);
  return g;
}

/// [type]'s grade sets 1 to [level], as a list of items (what a type at Awaken [level] holds).
List<Item> sets(Game g, String type, int level) => [
      for (var l = 1; l <= level; l++)
        for (final MapEntry(key: item, value: n) in g.gradeSet(type, l).entries) ...List.filled(n, item),
    ];

/// Puts exactly [item]'s recipe in [g]'s bag [times] over: its materials, its items and its gold.
void giveRecipe(Game g, Item item, [int times = 1]) {
  final r = g.itemRecipe(item)!;
  for (final MapEntry(key: m, value: n) in r.materials.entries) {
    g.materials[m] = (g.materials[m] ?? 0) + n * times;
  }
  for (final MapEntry(key: i, value: n) in r.items.entries) {
    g.inventory[i] = (g.inventory[i] ?? 0) + n * times;
  }
  g.gold += r.gold * times;
}

/// What a craft may change in [g], written out: the materials, items, gold.
String bags(Game g) => '${g.materials} ${g.inventory} ${g.gold}';

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
  test('the grade count: rounded up, at least 1, 0.667 read as two thirds', () {
    expect([for (final n in [1, 2, 3, 4, 5, 6]) gradeCount(n, 0.667)], [1, 2, 2, 3, 4, 4]);
    expect([for (final n in [1, 2, 3, 4]) gradeCount(n, 1)], [1, 2, 3, 4]);
    expect([for (final n in [1, 2, 3, 4]) gradeCount(n, 0.5)], [1, 1, 2, 2]);
    expect(gradeCount(3, 0.34), 2, reason: '1.02 is past a whole number by more than a hundredth');
  });

  test("each type's grade sets: its recipe plus its own new kind, the same counts at Awaken 1 and 2, two thirds at 3 "
      "(the design's table)", () {
    final g = forge();
    const table = {
      // type: {kind: count a level}, then the Awaken 3 counts where they differ, then the items of I / II / III.
      'soldier': ({ItemSlot.sword: 2, ItemSlot.shield: 2, ItemSlot.boots: 1, ItemSlot.bow: 1, ItemSlot.gloves: 1, ItemSlot.potion: 1, ItemSlot.amulet: 1}, <ItemSlot, int>{}, (9, 9, 9)),
      'knight': ({ItemSlot.sword: 3, ItemSlot.shield: 3, ItemSlot.boots: 2, ItemSlot.gloves: 2, ItemSlot.amulet: 1}, {ItemSlot.sword: 2, ItemSlot.shield: 2}, (11, 11, 9)),
      'swordsman': ({ItemSlot.sword: 3, ItemSlot.boots: 2, ItemSlot.gloves: 3, ItemSlot.potion: 2, ItemSlot.torch: 1}, {ItemSlot.sword: 2, ItemSlot.gloves: 2}, (11, 11, 9)),
      'archer': ({ItemSlot.sword: 2, ItemSlot.boots: 1, ItemSlot.bow: 4, ItemSlot.gloves: 3, ItemSlot.torch: 1}, {ItemSlot.bow: 3, ItemSlot.gloves: 2}, (11, 11, 9)),
      'lancer': ({ItemSlot.sword: 2, ItemSlot.shield: 2, ItemSlot.boots: 4, ItemSlot.gloves: 1, ItemSlot.spear: 2}, {ItemSlot.boots: 3}, (11, 11, 10)),
      'priest': ({ItemSlot.staff: 2, ItemSlot.shield: 2, ItemSlot.bow: 2, ItemSlot.gloves: 2, ItemSlot.potion: 2, ItemSlot.beads: 2}, <ItemSlot, int>{}, (12, 12, 12)),
      'armored_axeman': ({ItemSlot.sword: 2, ItemSlot.shield: 3, ItemSlot.boots: 1, ItemSlot.gloves: 2, ItemSlot.potion: 2, ItemSlot.prism: 1}, {ItemSlot.shield: 2}, (11, 11, 10)),
      'wizard': ({ItemSlot.staff: 2, ItemSlot.bow: 3, ItemSlot.gloves: 3, ItemSlot.potion: 2, ItemSlot.prism: 2}, {ItemSlot.bow: 2, ItemSlot.gloves: 2}, (12, 12, 10)),
      'knight_templar': ({ItemSlot.sword: 2, ItemSlot.shield: 2, ItemSlot.boots: 2, ItemSlot.bow: 1, ItemSlot.potion: 3, ItemSlot.torch: 1}, {ItemSlot.potion: 2}, (11, 11, 10)),
    };
    expect(table.keys, troopTypes.keys.toSet());
    for (final MapEntry(key: type, value: (kinds, three, (i, ii, iii))) in table.entries) {
      expect(g.kindRecipe(type), kinds, reason: type);
      for (final level in [1, 2]) {
        expect(g.gradeSet(type, level), {for (final MapEntry(:key, :value) in kinds.entries) itemOf(key, level): value}, reason: '$type $level');
      }
      expect(g.gradeSet(type, 3), {for (final MapEntry(:key, :value) in kinds.entries) itemOf(key, 3): three[key] ?? value}, reason: type);
      int total(int level) => g.gradeSet(type, level).values.fold(0, (a, b) => a + b);
      expect((total(1), total(2), total(3)), (i, ii, iii), reason: type);
      for (final level in [1, 2, 3]) {
        expect(g.gradeSet(type, level).keys.every((item) => item.grade == level && !outsideAwaken.contains(item.slot)), isTrue);
      }
    }
    // The share is town.json's: full sets at 1.
    g.townRules = TownRules.patch({
      'awaken': {
        'share': [1, 1, 1]
      }
    });
    expect(g.gradeSet('knight', 3), {Item.royalSword: 3, Item.royalShield: 3, Item.windBoots: 2, Item.royalGloves: 2, Item.goldAmulet: 1});
  });

  test('Awaken L takes exactly the grade-L set, after the sets below it, for every type', () {
    for (final type in troopTypes.keys) {
      final g = forge();
      for (var level = 1; level <= maxAwaken; level++) {
        final full = sets(g, type, level);
        g.upgrades[type] = [...full];
        expect(g.itemLevel(type), level, reason: '$type holds sets 1 to $level');
        expect(g.awakenNeeds(type, level).values.fold(0, (a, b) => a + b), full.length);
        // One item of the grade-L set short: the level below.
        for (final item in g.gradeSet(type, level).keys) {
          g.upgrades[type] = [...full]..remove(item);
          expect(g.itemLevel(type), level - 1, reason: '$type short of $item');
        }
        // The grade-L set held without the one below it counts for nothing past it.
        if (level > 1) {
          g.upgrades[type] = [...sets(g, type, level - 2), ...g.gradeSet(type, level).entries.expand((e) => List.filled(e.value, e.key))];
          expect(g.itemLevel(type), level - 2, reason: '$type: grade $level without grade ${level - 1}');
        }
        // Another grade's items in the grade-L count don't stand in for it.
        g.upgrades[type] = [
          ...sets(g, type, level - 1),
          for (final MapEntry(key: item, value: n) in g.gradeSet(type, level).entries) ...List.filled(n, itemOf(item.slot, level == 1 ? 2 : 1)),
        ];
        expect(g.itemLevel(type), level - 1, reason: '$type: another grade in place of grade $level');
      }
      // A Cap and a Ring never count.
      g.upgrades[type] = [...sets(g, type, 1), Item.royalHelm, Item.royalRing];
      expect(g.itemLevel(type), 1);
    }
  });

  test('giving items: grade I open at Awaken 0, grade II at 1, grade III at 2 (two thirds); each full grade refused '
      'for good; kinds outside the recipe never', () {
    final g = forge();
    g.inventory.addAll({for (final i in Item.values) i: 20});
    expect(g.capOf('knight', Item.sword), 3);
    expect((g.capOf('knight', Item.steelSword), g.whyNot(Item.steelSword, 'knight')), (0, Refusal.awakenFirst));
    expect((g.capOf('knight', Item.royalSword), g.whyNot(Item.royalSword, 'knight')), (0, Refusal.awakenFirst));
    expect((g.capOf('knight', Item.bow), g.whyNot(Item.bow, 'knight')), (0, Refusal.notInRecipe));
    expect((g.capOf('knight', Item.torch), g.whyNot(Item.torch, 'knight')), (0, Refusal.notInRecipe), reason: "not the knight's kind");
    // The refusal's words (decisions-log 252): a closed grade says which Awaken opens it, its tooltip's line.
    expect(g.itemRefusal(Item.steelSword, 'knight', Refusal.awakenFirst), 'Opens at ${awakenName(1)}');
    expect(g.itemRefusal(Item.royalSword, 'knight', Refusal.awakenFirst), 'Opens at ${awakenName(2)}');
    expect(g.itemRefusal(Item.bow, 'knight', Refusal.notInRecipe), refusalNames[Refusal.notInRecipe]);
    expect(g.capOf('knight', Item.amulet), 1, reason: 'its own new kind');
    expect(g.useItem(Item.steelSword, 'knight'), isFalse);
    // Grade I in full: Awaken 1, and grade I stays full.
    for (final MapEntry(key: item, value: n) in g.gradeSet('knight', 1).entries) {
      for (var i = 0; i < n; i++) {
        expect(g.useItem(item, 'knight'), isTrue, reason: '$item ${i + 1}/$n');
      }
    }
    expect(g.awakenLevel('knight'), 1);
    expect((g.capOf('knight', Item.sword), g.whyNot(Item.sword, 'knight')), (3, Refusal.maxed));
    expect((g.capOf('knight', Item.steelSword), g.whyNot(Item.steelSword, 'knight')), (3, null));
    expect((g.capOf('knight', Item.royalSword), g.whyNot(Item.royalSword, 'knight')), (0, Refusal.awakenFirst));
    for (final MapEntry(key: item, value: n) in g.gradeSet('knight', 2).entries) {
      for (var i = 0; i < n; i++) {
        expect(g.useItem(item, 'knight'), isTrue);
      }
    }
    expect(g.awakenLevel('knight'), 2);
    expect([for (final item in [Item.royalSword, Item.royalShield, Item.windBoots, Item.royalGloves, Item.goldAmulet]) g.capOf('knight', item)],
        [2, 2, 2, 2, 1]);
    for (final MapEntry(key: item, value: n) in g.gradeSet('knight', 3).entries) {
      for (var i = 0; i < n; i++) {
        expect(g.useItem(item, 'knight'), isTrue);
      }
    }
    expect(g.awakenLevel('knight'), 3);
    expect(g.upgrades['knight']!.length, 11 + 11 + 9, reason: "today's recipe x3, less the trimmed third of grade III");
    for (final item in Item.values) {
      if (outsideAwaken.contains(item.slot)) continue;
      expect(g.canUse(item, 'knight'), isFalse, reason: '$item at Awaken 3');
    }
    // The rows a list shows: (type, taken, cap, why).
    expect(g.typesFor(Item.royalSword).firstWhere((r) => r.$1 == 'knight'), ('knight', 2, 2, Refusal.maxed));
  });

  test("the Cap and the Ring: every type, one of the kind per level and one more (1 to 4, any grade); at the cap a "
      'better grade swaps out the lowest, which goes back to the Bag', () {
    final g = forge();
    g.inventory.addAll({Item.leatherCap: 3, Item.steelHelm: 2, Item.royalHelm: 1, Item.ring: 2, Item.gemRing: 1});
    for (final type in troopTypes.keys) {
      expect((g.capOf(type, Item.leatherCap), g.capOf(type, Item.royalRing)), (1, 1), reason: type);
    }
    expect(g.useItem(Item.leatherCap, 'soldier'), isTrue);
    expect(g.whyNot(Item.leatherCap, 'soldier'), Refusal.awakenFirst, reason: 'the same grade at the cap: an Awaken raises it');
    expect(g.itemRefusal(Item.leatherCap, 'soldier', Refusal.awakenFirst), refusalNames[Refusal.awakenFirst], reason: 'the grade is open; no Awaken named');
    expect(g.swapOut('soldier', Item.leatherCap), isNull);
    expect(g.swapOut('soldier', Item.steelHelm), Item.leatherCap);
    expect(g.priceWith('soldier', Item.steelHelm), g.priceOf('soldier'), reason: 'a swap adds no item to the price');
    expect(g.useItem(Item.steelHelm, 'soldier'), isTrue);
    expect(g.upgrades['soldier'], [Item.steelHelm]);
    expect((g.inventory[Item.leatherCap], g.inventory[Item.steelHelm]), (3, 1));
    expect(g.whyNot(Item.leatherCap, 'soldier'), Refusal.awakenFirst, reason: 'a lower grade never swaps');
    // Each level raises the cap by one: 4 at Awaken 3.
    g.upgrades['soldier'] = [...sets(g, 'soldier', 3), Item.steelHelm];
    expect((g.awakenLevel('soldier'), g.capOf('soldier', Item.leatherCap), g.heldOf('soldier', Item.royalHelm)), (3, 4, 1));
    expect(g.useItem(Item.leatherCap, 'soldier') && g.useItem(Item.leatherCap, 'soldier') && g.useItem(Item.leatherCap, 'soldier'), isTrue);
    expect(g.whyNot(Item.leatherCap, 'soldier'), Refusal.maxed);
    expect(g.useItem(Item.royalHelm, 'soldier'), isTrue, reason: 'swaps a Leather Cap out');
    expect([for (final i in g.upgrades['soldier']!) if (i.slot == ItemSlot.helm) i], [Item.steelHelm, Item.leatherCap, Item.leatherCap, Item.royalHelm]);
    expect(g.inventory[Item.leatherCap], 1);
    expect(g.awakenLevel('soldier'), 3, reason: 'helms never count for Awaken');
    // The ring the same way, apart from the helm.
    expect(g.useItem(Item.ring, 'knight') && g.whyNot(Item.ring, 'knight') == Refusal.awakenFirst, isTrue);
    expect(g.useItem(Item.gemRing, 'knight'), isTrue);
    expect(g.upgrades['knight'], [Item.gemRing]);
    expect(g.inventory[Item.ring], 2);
  });

  test('every item crafts from its own recipe: grade gold 20 / 60 / 250, the Cap and the Ring 150 / 600 / 2,500 and '
      'the grade below; refusals in order; no limit; canMake and whyNotMake', () {
    final g = forgeInTown();
    for (final item in Item.values) {
      final r = g.itemRecipe(item)!, chain = outsideAwaken.contains(item.slot);
      expect(r.gold, chain ? const [150, 600, 2500][item.grade - 1] : const [20, 60, 250][item.grade - 1], reason: '$item');
      expect(r.items, chain && item.grade > 1 ? {itemOf(item.slot, item.grade - 1): 1} : isEmpty, reason: '$item');
      expect(r.materials.keys.every((m) => !m.crafted), isTrue);
      expect(g.whyNotCraftItem(item)?.why, anyOf(CraftWhy.material, CraftWhy.item, CraftWhy.gold));
      giveRecipe(g, item);
      expect((g.canMake(item), g.whyNotMake(item)), (1, null), reason: '$item');
      final before = Map.of(g.inventory)..[item] = (g.inventory[item] ?? 0) + 1;
      for (final MapEntry(key: i, value: n) in r.items.entries) {
        before[i] = before[i]! - n;
      }
      expect(g.craftItem(item), isTrue, reason: '$item');
      expect(g.gold, 0, reason: '$item: exactly its recipe');
      expect(g.materials, isEmpty, reason: '$item');
      expect(g.inventory, before, reason: '$item');
    }
    // The order: a material, the item below, the gold.
    final h = forgeInTown();
    final no = h.whyNotCraftItem(Item.steelHelm)!;
    expect((no.why, no.short, no.text), (CraftWhy.material, Mat.rustyPlate, 'Need 2 ${Mat.rustyPlate.label}'));
    h.materials.addAll({Mat.rustyPlate: 2, Mat.skull: 1});
    expect((h.whyNotCraftItem(Item.steelHelm)!.text, h.whyNotMake(Item.steelHelm)!.short), ('Need 1 ${itemNames[Item.leatherCap]}', Item.leatherCap));
    h.inventory[Item.leatherCap] = 1;
    expect(h.whyNotCraftItem(Item.steelHelm)!.why, CraftWhy.gold);
    expect(h.craftItem(Item.steelHelm), isFalse);
    expect(h.sfx, contains(Sfx.error));
    // No limit: again while the bag pays; canMake counts how many.
    giveRecipe(h, Item.sword, 3);
    expect((h.canMake(Item.sword), h.smithyItems(1).length), (3, 14));
    expect(h.craftableItems(1), [Item.sword]);
    expect(h.craftItem(Item.sword) && h.craftItem(Item.sword) && h.craftItem(Item.sword), isTrue);
    expect((h.inventory[Item.sword], h.canMake(Item.sword), h.craftItem(Item.sword)), (3, 0, false));
    // Outside a Town: canMake still counts (the Army detail), Craft says why.
    final out = forge(gold: 100);
    giveRecipe(out, Item.steelSword, 1);
    expect((out.canMake(Item.steelSword), out.whyNotCraftItem(Item.steelSword)!.why), (1, CraftWhy.town));
    expect(out.craftItem(Item.steelSword), isFalse);
    // A craft never shows a material as dropped (the stones least of all).
    final seen = forgeInTown();
    giveRecipe(seen, Item.royalHelm);
    seen.inventory[Item.steelHelm] = 1;
    expect(seen.craftItem(Item.royalHelm), isTrue);
    expect(seen.matsSeen, isEmpty);
  });

  test('the Smithy item a fielded type still needs is the next grade set (craftItemNeed, awakenShort, bagLevel)', () {
    final g = forgeInTown(gold: 1000);
    expect(g.autoPlace('knight'), isTrue);
    g.upgrades['knight'] = sets(g, 'knight', 1)..remove(Item.sword);
    expect(g.awakenShort('knight'), {Item.sword: 1});
    expect(g.craftItemNeed(Item.sword), (type: 'knight', need: 1, level: 1));
    expect(g.craftItemNeed(Item.steelSword), isNull, reason: 'grade II waits for Awaken 1');
    g.upgrades['knight'] = sets(g, 'knight', 1);
    expect(g.awakenShort('knight'), g.gradeSet('knight', 2));
    expect(g.craftItemNeed(Item.steelSword), (type: 'knight', need: 3, level: 2));
    expect(g.craftItemNeed(Item.sword), isNull);
    // The Bag's items in a row of sets: Awaken 2, not 3 without grade III.
    g.inventory.addAll(g.gradeSet('knight', 2));
    expect(g.bagLevel('knight'), 2);
    g.inventory.addAll(g.gradeSet('knight', 3));
    expect(g.bagLevel('knight'), 3);
    g.inventory.removeWhere((i, _) => i.grade == 2);
    expect(g.bagLevel('knight'), 1, reason: 'grade III without grade II');
  });

  test("the Stats each item's grade gives: town.json's numbers (the knight's swords 3 + 3 + 2 = x7.137; heals, the Cap's "
      'cut and the Ring by grade)', () {
    final g = forge(), plain = forge();
    g.upgrades['knight'] = [...List.filled(3, Item.sword), ...List.filled(3, Item.steelSword), ...List.filled(2, Item.royalSword)];
    final k = g.statsOf('knight').dmg / plain.statsOf('knight').dmg;
    expect(k, closeTo(pow(1.25, 3) * pow(1.28, 3) * pow(1.32, 2), 1e-9));
    expect(k, closeTo(7.137, 0.001), reason: "the design's x7.13, cut rather than rounded");
    num after(Item item, String type, num Function(Stats) stat) {
      final h = forge()..upgrades[type] = [item];
      return stat(h.statsOf(type)) - stat(forge().statsOf(type));
    }

    expect([for (final i in [Item.shield, Item.towerShield, Item.royalShield]) after(i, 'knight', (s) => s.def)], [2.5, 4.0, 6.0]);
    expect([for (final i in [Item.potion, Item.bigPotion, Item.elixir]) after(i, 'knight', (s) => s.regen)], [5.0, 8.0, 12.0]);
    for (final (i, heal) in [(Item.potion, 3.0), (Item.bigPotion, 4.8), (Item.elixir, 7.2), (Item.staff, 3.0), (Item.magicStaff, 3.36), (Item.crystalStaff, 3.84)]) {
      expect(after(i, 'priest', (s) => s.dmg), closeTo(heal, 1e-9), reason: '$i on a healer');
      expect(forge().healOf(i), closeTo(heal, 1e-9));
    }
    expect([for (final i in [Item.boots, Item.swiftBoots, Item.windBoots]) (forge()..upgrades['knight'] = [i]).statsOf('knight').speed / troopTypes['knight']!.speed],
        [closeTo(1.25, 1e-9), closeTo(1.27, 1e-9), closeTo(1.30, 1e-9)]);
    expect([for (final i in [Item.gloves, Item.steelGloves, Item.royalGloves]) (forge()..upgrades['knight'] = [i]).statsOf('knight').rate / troopTypes['knight']!.rate],
        [closeTo(0.8, 1e-9), closeTo(0.78, 1e-9), closeTo(0.75, 1e-9)]);
    expect([for (final i in [Item.leatherCap, Item.steelHelm, Item.royalHelm]) (forge()..upgrades['knight'] = [i]).statsOf('knight').taken],
        [0.96, 0.95, 0.93]);
    expect((forge()..upgrades['knight'] = [Item.leatherCap, Item.royalHelm]).statsOf('knight').taken, closeTo(0.96 * 0.93, 1e-12));
    expect([for (final i in [Item.ring, Item.gemRing, Item.royalRing]) after(i, 'knight', (s) => s.mpRegen)],
        [closeTo(0.1, 1e-9), closeTo(0.15, 1e-9), closeTo(0.2, 1e-9)]);
    // The file's number is the one used: a tuned Steel Sword.
    final tuned = forge()
      ..townRules = TownRules.patch({
        'items': {
          'steelSword': {'effect': 1.5}
        }
      })
      ..upgrades['knight'] = [Item.steelSword];
    expect(tuned.statsOf('knight').dmg / plain.statsOf('knight').dmg, closeTo(1.5, 1e-9));
  });

  test("a Cap's cut lands on every blow after the defence", () {
    final g = bareGame()
      ..upgrades['soldier'] = [Item.royalHelm];
    final u = placeNow(g, 'soldier', 2, 3)..busyUntil = hold;
    expect(u.stats.taken, 0.93);
    final bear = Unit(Side.enemy, 'werebear', enemyTypes['werebear']!, u.pos + const Point(10, 0));
    g.units.add(bear);
    g.tick(0.05);
    expect(u.hp, closeTo(u.maxHp - enemyTypes['werebear']!.dmg * 0.93, 1e-9));
  });

  test('a craft is an itemCrafted event: the battle log line, the telemetry event and the wave record', () {
    final sink = _Kept(), events = <GameEvent>[];
    final g = forgeInTown();
    g.listeners.add(events.add);
    TelemetryAdapter([sink], installId: 'i', session: 's', platform: 'test', now: () => DateTime.utc(2026, 10, 4)).attach(g);
    giveRecipe(g, Item.steelSword);
    expect(g.craftItem(Item.steelSword), isTrue);
    final e = events.whereType<ItemCrafted>().single;
    expect(logLine(e), 'Crafted ${itemNames[Item.steelSword]} (60 gold)');
    expect(passedOn, contains(EventKind.itemCrafted));
    expect(g.leaveTown(), isTrue);
    g.startWave();
    g.queue
      ..clear()
      ..add(('slime', Tier.normal));
    g.tick(0.05);
    g.enemies.single.gone = true;
    g.tick(0.05);
    final ev = [for (final r in sink.of('event')) r['event'] as Map<String, dynamic>].singleWhere((e) => e['kind'] == 'itemCrafted');
    expect((ev['item'], ev['gold']), ('steelSword', 60));
    expect(ev['materials'], {'wolfClaw': 2, 'orcEar': 1});
    final w = sink.of('wave').single;
    expect(w['crafted'], {'steelSword': 1});
    expect(w['materialsUsed'], {'wolfClaw': 2, 'orcEar': 1});
    expect((w['gold'] as Map)['craftSpent'], 60);
  });

  test("the item recipe each type's grade sets build on (forgeAwakenKinds adds its own kind; an old save's level reads it)", () {
    expect(awakenRecipe, {
      'soldier': {Item.sword: 2, Item.shield: 2, Item.boots: 1, Item.bow: 1, Item.gloves: 1, Item.potion: 1},
      'knight': {Item.sword: 3, Item.shield: 3, Item.boots: 2, Item.gloves: 2},
      'swordsman': {Item.sword: 3, Item.boots: 2, Item.gloves: 3, Item.potion: 2},
      'archer': {Item.sword: 2, Item.boots: 1, Item.bow: 4, Item.gloves: 3},
      'lancer': {Item.sword: 2, Item.shield: 2, Item.boots: 4, Item.gloves: 1},
      'priest': {Item.staff: 2, Item.shield: 2, Item.bow: 2, Item.gloves: 2, Item.potion: 2},
      'armored_axeman': {Item.sword: 2, Item.shield: 3, Item.boots: 1, Item.gloves: 2, Item.potion: 2},
      'wizard': {Item.staff: 2, Item.bow: 3, Item.gloves: 3, Item.potion: 2},
      'knight_templar': {Item.sword: 2, Item.shield: 2, Item.boots: 2, Item.bow: 1, Item.potion: 3},
    });
  });
}
