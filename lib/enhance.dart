part of 'game.dart';

// Enhance (decisions-log 255; forge-design §12; docs/loot-items-relics.md "The forge: Enhance"): the owner, 2026-10-04,
// wants items enhanced late in a run. From wave 30 (town.json `enhance.from`) a Town's Smithy takes an item in the Bag
// one step up, to at most +5 (`enhance.most`), for step n's stone (`enhance.stone`: Mithril for +1 to +3, Starmetal for
// +4 and +5) and gold (`enhance.gold`). It never fails. Each step adds a tenth (`enhance.per`) of the item's own bonus
// ([enhancedK]). The stones are Smithy-made materials ([craftedMats], `enhance.stones`).
//
// An enhanced item is its own stack, (item, plus): in the Bag ([Game.enhancedBag]; +0 stays in [Game.inventory]) and on
// a troop type ([Game.upgradePlus]: the pluses of its copies in [Game.upgrades], which still lists every item, so the
// Awaken counts, caps and levels never change with Enhance). At a type's cap a higher plus swaps out the lowest-plus copy
// of that item, which goes back to the Bag at its plus ([Game.swapOut]; the Cap's and the Ring's lowest by grade, then
// plus). The Smithy's Enhance tab (smithy_page.dart) draws [Enhance.enhanceRows] and asks [Enhance.whyNotEnhance]; the
// Bag, the Shop and the Smithy give each stack its own cell (bag.dart's [BagLoot]), its icon in its level's colour.

/// The kinds whose effect is added, not a factor ([Stats.upgraded]): the shield's defence, the potion's regen and the
/// ring's MP regen. Enhance raises them as a share of themselves ([enhancedK]).
const flatKinds = {ItemSlot.shield, ItemSlot.potion, ItemSlot.ring};

/// What one [item] of effect [k] ([Game.itemK]) does at +[plus] (decisions-log 255): [per] of its own bonus more a step.
/// A flat one ([flatKinds]) is k × (1 + per × plus) (Royal Shield 6 → 9 at +5); a factor 1 + (k − 1)(1 + per × plus),
/// so a gain grows (Royal Sword ×1.32 → ×1.48) and a cut deepens (Royal Gloves' wait ×0.75 → ×0.625). +0 is [k] itself.
double enhancedK(Item item, double k, int plus, double per) {
  if (plus <= 0) return k;
  final up = 1 + per * plus;
  return flatKinds.contains(item.slot) ? k * up : 1 + (k - 1) * up;
}

/// An item's name with its plus: "Royal Sword +3"; +0 its name alone ([itemNames]).
String itemLabel(Item item, [int plus = 0]) => plus > 0 ? '${itemNames[item]} +$plus' : itemNames[item]!;

/// The Smithy's Enhance (decisions-log 255): the stones, the steps, the Bag's enhanced stacks and the Shop's price.
extension Enhance on Game {
  /// Whether the Smithy's Enhance is open (town.json `enhance.from`, forge-design §12): once wave 30 is won (past it, or on it between waves: [Store.storeOpen]'s form of rule). The one place the rule lives: the Smithy's
  /// strip greys its Enhance segment by it and keeps its tab off while closed, and [whyNotEnhance] / [whyNotCraftStone]
  /// refuse by it ([CraftWhy.closed]).
  bool get enhanceOpen {
    final from = townRules.enhance.from;
    return wave > from || wave == from && !waveActive;
  }

  /// The most steps an item takes (town.json `enhance.most`, 5).
  int get plusMost => townRules.enhance.most;

  // The Bag's stacks.

  /// How many [item]s at +[plus] the Bag holds: +0 in [Game.inventory], an enhanced one in [Game.enhancedBag].
  int bagOf(Item item, [int plus = 0]) => plus <= 0 ? inventory[item] ?? 0 : enhancedBag[(item, plus)] ?? 0;

  /// Puts [n] [item]s at +[plus] in the Bag (takes them out, when negative). An enhanced stack's last one leaves no entry
  /// (the save writes only those held); +0 is [Game.inventory]'s, as [Game.useItem] keeps it.
  void _toBagAt(Item item, int plus, int n) {
    if (plus <= 0) {
      inventory[item] = bagOf(item) + n;
      return;
    }
    final left = bagOf(item, plus) + n;
    if (left > 0) {
      enhancedBag[(item, plus)] = left;
    } else {
      enhancedBag.remove((item, plus));
    }
  }

  /// The Bag's enhanced stacks held, each (item, plus) once: in [Item] order, then by plus, lowest first.
  List<(Item, int)> get enhancedHeld => [
        for (final (i, p) in enhancedBag.keys.toList()..sort((a, b) => a.$1 == b.$1 ? a.$2 - b.$2 : a.$1.index - b.$1.index))
          if (enhancedBag[(i, p)]! > 0) (i, p),
      ];

  // A type's enhanced items.

  /// The pluses of [type]'s copies of [item], highest first, one per copy ([Game.countOf]): its enhanced ones
  /// ([Game.upgradePlus]), then 0 for each other.
  List<int> plusesOn(String type, Item item) {
    final up = upgradePlus[type]?[item] ?? const <int>[], n = countOf(type, item);
    return [...up.take(n), for (var i = up.length; i < n; i++) 0];
  }

  /// The lowest plus among [type]'s copies of [item]: 0 while one is +0 (or none is held).
  int _lowPlus(String type, Item item) {
    final up = upgradePlus[type]?[item];
    return up == null || up.length < countOf(type, item) ? 0 : up.last;
  }

  // The stones (town.json `enhance.stones`).

  /// [stone]'s recipe ([EnhanceRules.stones]), or null for a material that isn't a stone.
  StoneRecipe? stoneRecipe(Mat stone) => townRules.enhance.stones[stone];

  /// [stone]'s recipe line by line, as [Craft.craftRows]: each material (Starmetal's Mithril too), then the gold; none
  /// without a recipe.
  List<CraftRow> stoneCraftRows(Mat stone) => switch (stoneRecipe(stone)) {
        final r? => [
            for (final MapEntry(key: m, value: n) in r.materials.entries) (kind: m, have: materials[m] ?? 0, need: n),
            (kind: null, have: gold, need: r.gold),
          ],
        null => const [],
      };

  /// Why [stone] can't be made now, or null, in [Craft.whyNotCraft]'s order: the game over, not in a Town, no recipe (not
  /// a stone), Enhance not open yet ([enhanceOpen]: "Opens after wave 30"), a material short, the gold.
  CraftRefusal? whyNotCraftStone(Mat stone) {
    if (over) return const CraftRefusal(CraftWhy.over);
    if (!inTown) return const CraftRefusal(CraftWhy.town);
    final rows = stoneCraftRows(stone);
    if (rows.isEmpty) return const CraftRefusal(CraftWhy.recipe);
    if (!enhanceOpen) return CraftRefusal(CraftWhy.closed, need: townRules.enhance.from);
    return Craft._rowsShort(rows);
  }

  /// [stone] can be made now ([whyNotCraftStone] has nothing against it).
  bool canCraftStone(Mat stone) => whyNotCraftStone(stone) == null;

  /// Makes one [stone]: takes its materials and gold ([Craft._payCraft], counted in the visit's), one more in
  /// [Game.materials] (never in [Game.matsSeen]: it never dropped), `Sfx.clear`, and emits [StoneCrafted] (the battle log's
  /// "Crafted Mithril (1,000 gold)"). False (nothing changes but the error sound) when [whyNotCraftStone] refuses.
  bool craftStone(Mat stone) {
    if (whyNotCraftStone(stone) != null) {
      sfx.add(Sfx.error);
      return false;
    }
    final r = stoneRecipe(stone)!;
    _payCraft(r.materials, const {}, r.gold);
    materials[stone] = (materials[stone] ?? 0) + 1;
    sfx.add(Sfx.clear);
    _emit(StoneCrafted(wave, t, stone: stone, materials: r.materials, gold: r.gold));
    return true;
  }

  // The steps.

  /// The stone and the gold the step from +[plus] to the next takes (town.json `enhance.stone` and `enhance.gold`, the
  /// step's entry), or null at [plusMost].
  ({Mat stone, int gold})? enhanceCost(int plus) {
    final e = townRules.enhance;
    return plus < 0 || plus >= e.most ? null : (stone: e.stone[plus], gold: e.gold[plus]);
  }

  /// The step from +[plus] line by line, as [Craft.craftRows]: its stone, then its gold; none at [plusMost]. The item
  /// itself isn't a row: the Smithy enhances the one picked in the Bag.
  List<CraftRow> enhanceRows(int plus) => switch (enhanceCost(plus)) {
        (:final stone, :final gold) => [(kind: stone, have: materials[stone] ?? 0, need: 1), (kind: null, have: this.gold, need: gold)],
        null => const [],
      };

  /// Why [item] at +[plus] can't go one step up now, or null: the game over, not in a Town, Enhance not open yet ([CraftWhy.closed], "Opens after wave 30"), none of it in the Bag ([CraftWhy.item]), already at
  /// [plusMost] ([CraftWhy.top], "Max: +5"), then its stone short ("Need 1 Starmetal"), the gold. Any item and grade
  /// takes it, and it never fails.
  CraftRefusal? whyNotEnhance(Item item, int plus) {
    if (over) return const CraftRefusal(CraftWhy.over);
    if (!inTown) return const CraftRefusal(CraftWhy.town);
    if (!enhanceOpen) return CraftRefusal(CraftWhy.closed, need: townRules.enhance.from);
    if (bagOf(item, plus) == 0) return CraftRefusal(CraftWhy.item, short: item, need: 1);
    if (plus >= plusMost) return CraftRefusal(CraftWhy.top, need: plusMost);
    return Craft._rowsShort(enhanceRows(plus));
  }

  /// [item] at +[plus] can go one step up now ([whyNotEnhance] has nothing against it).
  bool canEnhance(Item item, int plus) => whyNotEnhance(item, plus) == null;

  /// Takes one [item] at +[plus] in the Bag one step up: its stone and gold go ([Craft._payCraft], counted in the visit's),
  /// the item leaves its stack for the next one's (its own Bag cell), `Sfx.clear`, and [ItemEnhanced] (the battle log's
  /// "Enhanced Royal Sword to +3 (1,500 gold)"). Always works once allowed: no dice. False (nothing changes but the error
  /// sound) when [whyNotEnhance] refuses.
  bool enhance(Item item, int plus) {
    if (whyNotEnhance(item, plus) != null) {
      sfx.add(Sfx.error);
      return false;
    }
    final (:stone, :gold) = enhanceCost(plus)!;
    _payCraft({stone: 1}, const {}, gold);
    _toBagAt(item, plus, -1);
    _toBagAt(item, plus + 1, 1);
    sfx.add(Sfx.clear);
    _emit(ItemEnhanced(wave, t, item: item, plus: plus + 1, stone: stone, gold: gold));
    return true;
  }

  // The Shop.

  /// What the Shop pays for one [item] at +[plus] (forge-design §12): [Store.sellPrice]'s, plus half of what its steps
  /// cost: each step's gold at the Shop's item share ([TownShop.itemSellShare]) and its stone at its own sell price
  /// ([MatInfo.sell], half a stone's worth). +0: [Store.sellPrice].
  int sellPriceAt(Item item, int plus) {
    var price = sellPrice(item).toDouble();
    for (var p = 0; p < plus; p++) {
      if (enhanceCost(p) case (:final stone, :final gold)) {
        price += gold * townRules.shop.itemSellShare + (townRules.materials[stone]?.sell ?? 0);
      }
    }
    return price.round();
  }

  /// Why one [item] at +[plus] can't be sold now, or null: [Store.whyNotSell]'s, by its own stack.
  StoreRefusal? whyNotSellAt(Item item, int plus) =>
      plus <= 0 ? whyNotSell(item) : _away ?? _closed ?? (bagOf(item, plus) == 0 ? StoreRefusal.none : null);

  /// Sells [n] [item]s at +[plus] from the Bag (all of them when there are fewer) for [sellPriceAt] each, as
  /// [Store.sell] (+0 is [Store.sell] itself). How many went; 0 (and nothing changes) when [whyNotSellAt] refuses.
  int sellAt(Item item, int plus, [int n = 1]) {
    if (plus <= 0) return sell(item, n);
    if (whyNotSellAt(item, plus) != null) {
      sfx.add(Sfx.error);
      return 0;
    }
    final sold = min(n, bagOf(item, plus)), price = sellPriceAt(item, plus);
    _toBagAt(item, plus, -sold);
    gold += sold * price;
    _emit(StoreSold(wave, t, loot: item, n: sold, gain: sold * price, plus: plus));
    sfx.add(Sfx.kill);
    return sold;
  }

  // The save.

  /// The save's Enhance keys, only with something enhanced: `bagPlus`, the Bag's enhanced stacks as {item, plus, n}, and `upgradePlus`, per type its enhanced copies the same
  /// way. Every item stays in `inventory` (+0) and `upgrades` (all), so a save read without these keys is all +0.
  Map<String, Object> get _enhanceJson {
    List<Map<String, Object>> rows(Iterable<(Item, int, int)> held) => [
          for (final (i, p, n) in held) {'item': i.name, 'plus': p, 'n': n},
        ];
    final bag = rows([for (final (i, p) in enhancedHeld) (i, p, enhancedBag[(i, p)]!)]);
    final on = {
      for (final MapEntry(key: type, value: m) in upgradePlus.entries)
        if (m.isNotEmpty)
          type: rows([
            for (final MapEntry(key: i, value: ps) in m.entries)
              for (final p in {...ps}) (i, p, ps.where((q) => q == p).length),
          ]),
    };
    return {if (bag.isNotEmpty) 'bagPlus': bag, if (on.isNotEmpty) 'upgradePlus': on};
  }

  /// [j]'s `bagPlus` and `upgradePlus` (a save without them: all +0). An item name this build
  /// doesn't know is skipped, a plus is kept in 1 to [plusMost], and a type keeps at most as many enhanced copies of an
  /// item as [Game.upgrades] lists (its highest). After [Game.upgrades] is read, before the troops take their stats.
  void _loadEnhance(Map<String, dynamic> j) {
    (Item, int, int)? row(Object? r) => switch (r) {
          {'item': final String name, 'plus': final int p, 'n': final int n} when n > 0 && p > 0 =>
            switch (Item.values.asNameMap()[name]) { final i? => (i, min(p, plusMost), n), null => null },
          _ => null,
        };
    for (final r in (j['bagPlus'] as List?) ?? const []) {
      if (row(r) case (final i, final p, final n)) _toBagAt(i, p, n);
    }
    for (final MapEntry(:key, :value) in ((j['upgradePlus'] as Map?) ?? const {}).entries) {
      final type = key as String, m = <Item, List<int>>{};
      for (final r in value as List) {
        if (row(r) case (final i, final p, final n)) (m[i] ??= []).addAll(List.filled(n, p));
      }
      for (final MapEntry(key: i, value: ps) in m.entries.toList()) {
        ps.sort((a, b) => b - a);
        final keep = countOf(type, i);
        if (keep == 0) {
          m.remove(i);
        } else if (ps.length > keep) {
          ps.removeRange(keep, ps.length);
        }
      }
      if (m.isNotEmpty) upgradePlus[type] = m;
    }
  }
}
