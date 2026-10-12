part of 'game.dart';

// The Towns (decisions-log 216; docs/loot-items-relics.md "Towns (dark)"). The owner, 2026-10-03: relics will be
// crafted at a Smithy in a Town, not dropped; a Town is an interlude BETWEEN two waves, rolled two waves ahead. The
// owner's 2026-10-04 answer: "untuk town setiap wave antara wave 6 dan wave7, jadi harusnya tida menggangu spawn mini
// boss atau boss" (a Town sits between two waves, so the mini boss / boss schedule is untouched). The schedule and the
// Town's state live here; the scene is town_scene.dart's, the Smithy smithy_page.dart's, the Shop bag.dart's. Every game
// has the Towns (decisions-log 237, 296; a plain Game() too since decisions-log 321).
//
// The roll ([Towns._rollTown], in tick's win path after the Hero and the Boss Chest, so the auto-save keeps it): after
// wave n is won, for "a Town before wave n+2" (slot n+2: it opens once wave n+1 is won, before wave n+2 starts). A Town
// already marked: no roll. Blocked (n+2 − [Game.townLast] < [TownSchedule.minGap]): no roll, and the chance stays. Else
// one draw on [Game.townDice]: under [Game.townChance] the slot is marked ([Game.townAt]) and the chance goes back to
// [TownSchedule.chanceStart]; else it grows by [TownSchedule.chanceStep], at most [TownSchedule.chanceCap]. A new run
// counts as a Town before wave [TownSchedule.firstTownAfter], so the first Town comes before wave 7 at the earliest.

/// The Towns' numbers: assets/config/town.json (the owner's tuning file), loaded at start into [loadedTownRules]; each
/// [Game] reads its own [Game.townRules], so a test or probe swaps them per game ([patch]). The game reads the
/// [schedule] (decisions-log 216), the materials' [forgeDrops], [parts] and [materials] (decisions-log 221, 246), the
/// crafted relics' [relics] numbers (decisions-log 227), and the Smithy's [recipes] ([Craft]), the relic [tiers]' prices
/// and the [shop]'s item prices ([Store], decisions-log 233); the forge's (decisions-log 245, in every
/// game with the Towns since the forge-off build went, decisions-log 296): the [items]' recipes and effects, the relic recipes that change with it ([forgeChanges]) and the [combos]; the
/// Tavern's boosts ([tavern], decisions-log 266). [parse] skips any block it doesn't know.
class TownRules {
  /// The format the file is written in ([toJson]). 2: the materials, recipes and prices; 3 (decisions-log 245): the
  /// forge's `items`, `combos`, `awaken` and `enhance`, and each relic's recipe in its `relics` entry (with what the
  /// forge changes in it).
  static const version = 3;

  /// The formats [parse] reads (a version-2 file's relic recipes are its `recipes` block); a file of another version
  /// gives every default.
  static const versions = [2, 3];

  const TownRules({
    this.schedule = const TownSchedule(),
    this.forgeDrops = _forgeDrops,
    this.necromancerPlus = const {Mat.lichOrb: 1},
    this.parts = _townParts,
    this.materials = _townMaterials,
    this.recipes = _townRecipes,
    this.tiers = _townTiers,
    this.relics = _townRelicNumbers,
    this.shop = const TownShop(),
    this.items = _townItems,
    this.forgeChanges = _townForgeChanges,
    this.combos = const Combos(),
    this.awaken = const AwakenRules(),
    this.enhance = const EnhanceRules(),
    this.tavern = const TavernRules(),
    this.market = const MarketRules(),
    this.skipped = const [],
  });

  /// When Towns come ([Towns._rollTown]).
  final TownSchedule schedule;

  /// What a kill drops by its rank ([dropOf]; the forge's, decisions-log 246; the file's `drops.forge`): a list a rank,
  /// each its own part, chance and count (a high elite its Common always and its Rare at 50%), and the always-drops. The
  /// drops from before the forge (the file's `drops.normal` to `drops.boss`) are gone with the forge-off build
  /// (decisions-log 296): an old file's are noted in [skipped].
  final Map<Tier, List<MatDrop>> forgeDrops;

  /// What the Necromancer ([boss]) drops on top as a mini boss or the boss (the file's `drops.necromancerSlot.plus`).
  final Map<Mat, int> necromancerPlus;

  /// Each monster type's Common and Rare part (null: none of that grade, the Necromancer's Common).
  final Map<String, (Mat?, Mat?)> parts;

  /// Each material's grade and what the Town's Shop pays for one.
  final Map<Mat, MatInfo> materials;

  /// The Smithy's recipes by the relic's save key ([townRelics], then the forge's nine, [forgeRelics]): its tier,
  /// materials, items and gold. [forgeRecipe] reads them with its changes.
  final Map<String, Recipe> recipes;

  /// Each relic tier's prices: the share of its craft gold a sale pays, the Shop's price and its rise a buy.
  final Map<RelicTier, TierPrices> tiers;

  /// Each crafted relic's numbers by its save key (`fang`'s `share`, `fury`'s `every` and `hit`, …).
  final Map<String, Map<String, num>> relics;

  /// The Town Shop's opening wave and the items' prices.
  final TownShop shop;

  /// Every item's Smithy recipe and what one does (decisions-log 245; the file's `items`), by [Item].
  final Map<Item, ItemRecipe> items;

  /// The relics whose recipe the forge changes (decisions-log 245; a `relics` entry's `forge`), by save key: the whole
  /// recipe then (Mana Siphon's materials; Iron Will's, Giant Slayer's and Holy Charm's grade-II item).
  final Map<String, Recipe> forgeChanges;

  /// The small relics' cap and the hidden pairings (decisions-log 245; the file's `combos`): data only, nothing reads it
  /// yet.
  final Combos combos;

  /// Awaken by grade (decisions-log 245, 249; the file's `awaken`).
  final AwakenRules awaken;

  /// The late game's Enhance (decisions-log 245; the file's `enhance`; enhance.dart's [Enhance], decisions-log 255).
  final EnhanceRules enhance;

  /// The Tavern's boosts (decisions-log 266; the file's `tavern`, lib/tavern.dart): read with the Tavern on.
  final TavernRules tavern;

  /// The market for forged goods (decisions-log 326; the file's `market`, lib/market.dart).
  final MarketRules market;

  /// What [parse] left out of the file, one line each (a name it doesn't know, a number out of range): main.dart
  /// prints them. Not in [toJson].
  final List<String> skipped;

  /// The rules in [text] (assets/config/town.json), or every default when it isn't an object of one of [versions].
  static TownRules parse(String text) {
    try {
      final j = jsonDecode(text);
      if (j is Map<String, dynamic> && versions.contains(j['version'])) return TownRules.fromJson(j);
    } on FormatException {
      // not JSON: the defaults
    }
    return const TownRules();
  }

  /// [j]'s numbers, each only when it is of the right kind and in its range (else its default); a name the game
  /// doesn't know (a material, a monster type, a relic, an item) is left out where it stands and noted in [skipped].
  factory TownRules.fromJson(Map<String, dynamic> j) {
    const d = TownRules();
    final skipped = <String>[];
    Map<String, dynamic> block(Map<String, dynamic> m, String k) => switch (m[k]) { final Map<String, dynamic> b => b, _ => const {} };
    final drops = block(j, 'drops'), parts = block(j, 'parts'), mats = block(j, 'materials'), recipes = block(j, 'recipes');
    final tiers = block(j, 'tiers'), relics = block(j, 'relics'), items = block(j, 'items');
    void unknown(Map<String, dynamic> m, Iterable<String> known, String where) =>
        skipped.addAll([for (final k in m.keys) if (!known.contains(k)) '$where: no $k']);
    unknown(drops, ['necromancerSlot', 'forge'], 'drops');
    unknown(block(drops, 'forge'), [for (final t in Tier.values) t.name], 'drops.forge');
    unknown(parts, [...enemyTypes.keys, boss, necroHealer], 'parts');
    unknown(mats, [for (final m in Mat.values) m.name], 'materials');
    unknown(recipes, d.recipes.keys, 'recipes');
    unknown(tiers, [for (final t in RelicTier.values) t.name], 'tiers');
    unknown(relics, d.relics.keys, 'relics');
    unknown(items, [for (final i in Item.values) i.name], 'items');
    // In the file's order, so [skipped] notes come as they stand.
    final forgeDropsOf = {
      for (final tier in Tier.values)
        tier: switch (block(drops, 'forge')[tier.name]) {
          final List<dynamic> l => [
              for (final (i, e) in l.indexed)
                if (e is Map<String, dynamic>)
                  MatDrop.fromJson(e, d.forgeDrops[tier]!.elementAtOrNull(i) ?? const MatDrop(MatGrade.common, 0), skipped,
                      'drops.forge.${tier.name}'),
            ],
          _ => d.forgeDrops[tier]!,
        },
    };
    final necromancerPlus = switch (block(drops, 'necromancerSlot')['plus']) {
      final Map<String, dynamic> m => _matCounts(m, skipped, 'drops.necromancerSlot.plus'),
      _ => d.necromancerPlus,
    };
    final partsOf = {
      for (final MapEntry(key: type, value: def) in d.parts.entries)
        type: switch (parts[type]) {
          [final c, final r] => (_mat(c, skipped, 'parts.$type'), _mat(r, skipped, 'parts.$type')),
          _ => def,
        },
    };
    // A relic's recipe: the `recipes` block's (version 2, or a patch's), else its `relics` entry's (version 3), else its
    // default.
    final relicRecipes = {
      for (final MapEntry(key: r, value: def) in d.recipes.entries)
        r: switch ((recipes[r], block(relics, r)['recipe'])) {
          (final Map<String, dynamic> v, _) => Recipe.fromJson(v, def, skipped, 'recipes.$r'),
          (_, final Map<String, dynamic> v) => Recipe.fromJson(v, def, skipped, 'relics.$r.recipe'),
          _ => def,
        },
    };
    return TownRules(
      schedule: switch (j['schedule']) { final Map<String, dynamic> s => TownSchedule.fromJson(s), _ => const TownSchedule() },
      forgeDrops: forgeDropsOf,
      necromancerPlus: necromancerPlus,
      parts: partsOf,
      materials: {
        for (final MapEntry(key: m, value: def) in d.materials.entries)
          m: switch (mats[m.name]) { final Map<String, dynamic> v => MatInfo.fromJson(v, def), _ => def },
      },
      recipes: relicRecipes,
      tiers: {
        for (final MapEntry(key: tier, value: def) in d.tiers.entries)
          tier: switch (tiers[tier.name]) { final Map<String, dynamic> v => TierPrices.fromJson(v, def), _ => def },
      },
      relics: {
        for (final MapEntry(key: relic, value: nums) in d.relics.entries)
          relic: {for (final MapEntry(:key, :value) in nums.entries) key: _number(block(relics, relic)[key], value)},
      },
      shop: TownShop.fromJson(block(j, 'shop')),
      items: {
        for (final MapEntry(key: i, value: def) in d.items.entries)
          i: switch (items[i.name]) { final Map<String, dynamic> v => ItemRecipe.fromJson(v, def, skipped, 'items.${i.name}'), _ => def },
      },
      // A `forge` block holds what changes: what it leaves out is the relic's own recipe's. None: the default change.
      forgeChanges: {
        for (final MapEntry(key: r, value: recipe) in relicRecipes.entries)
          if (block(relics, r)['forge'] case final Map<String, dynamic> v)
            r: Recipe.fromJson(v, recipe, skipped, 'relics.$r.forge')
          else
            r: ?d.forgeChanges[r],
      },
      combos: switch (j['combos']) { final Map<String, dynamic> c => Combos.fromJson(c, skipped), _ => const Combos() },
      awaken: AwakenRules.fromJson(block(j, 'awaken'), skipped),
      enhance: EnhanceRules.fromJson(block(j, 'enhance'), skipped),
      tavern: TavernRules.fromJson(block(j, 'tavern'), skipped),
      market: MarketRules.fromJson(block(j, 'market'), skipped),
      skipped: skipped,
    );
  }

  /// The defaults with the numbers of [p] put in, nested as the file is (`{'schedule': {'chanceStart': 1.0}}`; a relic's
  /// recipe also as version 2 nests it, `{'recipes': {'fang': {'gold': 800}}}`): for tests and probes.
  static TownRules patch(Map<String, dynamic> p) {
    Map<String, dynamic> merge(Map<String, dynamic> a, Map<String, dynamic> b) => {
          ...a,
          for (final MapEntry(:key, :value) in b.entries)
            key: switch ((a[key], value)) { (final Map<String, dynamic> x, final Map<String, dynamic> y) => merge(x, y), _ => value },
        };
    // A version-2 `recipes` block (a relic's recipe) goes into its `relics` entry, as version 3 writes it.
    Map<String, dynamic> part(String k) => switch (p[k]) { final Map<String, dynamic> m => m, _ => const {} };
    final recipes = part('recipes');
    final moved = {
      ...p,
      'relics': merge(part('relics'), {
        for (final MapEntry(:key, :value) in recipes.entries) key: {'recipe': value},
      }),
    }..remove('recipes');
    return TownRules.fromJson(merge(const TownRules().toJson(), moved));
  }

  /// What the kill of a [type] monster of rank [tier] drops (decisions-log 221), each kind with its count: the type's
  /// part of the rank's grade ([MatDrop.part]) at the rank's chance, one draw on [dice] when the chance is between 0 and 1
  /// and the type has that part (none for an always-drop), then the rank's always-drops ([MatDrop.plus]), and the
  /// Necromancer's ([necromancerPlus]) as a mini boss or the boss. The rank's list ([forgeDrops]) in turn: each entry its
  /// own draw, then all their always-drops.
  Map<Mat, int> dropOf(String type, Tier tier, Random dice) {
    final got = <Mat, int>{}, ds = forgeDrops[tier]!;
    void add(Map<Mat, int> more) {
      for (final MapEntry(key: m, value: n) in more.entries) {
        got[m] = (got[m] ?? 0) + n;
      }
    }

    for (final d in ds) {
      if (partOf(type, d.part) case final part? when d.chance > 0 && d.count > 0) {
        if (d.chance >= 1 || dice.nextDouble() < d.chance) add({part: d.count});
      }
    }
    for (final d in ds) {
      add(d.plus);
    }
    if (type == boss && (tier == Tier.miniBoss || tier == Tier.boss)) add(necromancerPlus);
    return got;
  }

  /// [type]'s part of [grade] (common or rare): none for a type the file doesn't name or a null part.
  Mat? partOf(String type, MatGrade grade) => switch ((parts[type], grade)) {
        ((final c, _)?, MatGrade.common) => c,
        ((_, final r)?, MatGrade.rare) => r,
        _ => null,
      };

  /// The monster types that drop [m] as a part (its Common or Rare), in [parts]' order.
  List<String> sourcesOf(Mat m) => [for (final MapEntry(key: type, value: (c, r)) in parts.entries) if (c == m || r == m) type];

  /// [key]'s recipe (decisions-log 245): its [forgeChanges] one, else its own ([recipes]).
  Recipe? forgeRecipe(String key) => forgeChanges[key] ?? recipes[key];

  /// The relics whose recipe takes [m], in [townRelics]' order.
  List<String> recipesWith(Mat m) => [for (final r in townRelics) if (recipes[r]?.materials.containsKey(m) ?? false) r];

  Map<String, dynamic> toJson() => {
        'version': version,
        'schedule': schedule.toJson(),
        'drops': {
          'necromancerSlot': {'plus': _matJson(necromancerPlus)},
          'forge': {for (final MapEntry(:key, :value) in forgeDrops.entries) key.name: [for (final d in value) d.toJson()]},
        },
        'parts': {for (final MapEntry(key: type, value: (c, r)) in parts.entries) type: [c?.name, r?.name]},
        'materials': {for (final MapEntry(:key, :value) in materials.entries) key.name: value.toJson()},
        'tiers': {for (final MapEntry(:key, :value) in tiers.entries) key.name: value.toJson()},
        'relics': {
          for (final MapEntry(key: r, value: nums) in relics.entries)
            r: {
              ...nums,
              'recipe': ?recipes[r]?.toJson(),
              if ((recipes[r], forgeChanges[r]) case (final recipe?, final change?)) 'forge': change.changesFrom(recipe),
            },
        },
        'shop': shop.toJson(),
        'items': {for (final MapEntry(:key, :value) in items.entries) key.name: value.toJson()},
        'combos': combos.toJson(),
        'awaken': awaken.toJson(),
        'enhance': enhance.toJson(),
        'tavern': tavern.toJson(),
        'market': market.toJson(),
      };
}

/// Awaken by grade (town.json `awaken`, decisions-log 245 and 249; forge-design §11): Awaken L needs the type's recipe in
/// grade-L items ([Game.gradeSet]), grade L's counts [share] L's of the recipe's, rounded up ([gradeCount]; one per
/// grade, the first grade's first). Always by grade: the file's `byGrade`, the switch back to the rule from before the
/// grades, is gone (decisions-log 296) and an old file's is ignored.
class AwakenRules {
  const AwakenRules({this.share = const [1.0, 1.0, 0.667]});

  final List<double> share;

  /// [j]'s rules; a `share` that isn't a list of shares above 0 and at most 1 keeps the default (noted in [skipped]).
  factory AwakenRules.fromJson(Map<String, dynamic> j, List<String> skipped) {
    const d = AwakenRules();
    return AwakenRules(
      share: switch (j['share']) {
        null => d.share,
        final List<dynamic> l when l.isNotEmpty && l.every((v) => v is num && v > 0 && v <= 1) => [for (final num v in l) v.toDouble()],
        final v => (skipped..add('awaken.share: $v'), d.share).$2,
      },
    );
  }

  Map<String, dynamic> toJson() => {'share': share};
}

/// Enhance (town.json `enhance`, decisions-log 245; forge-design §12): from wave [from] a Smithy takes a crafted item
/// up to [most] steps, each adding [per] of the item's own bonus, step n taking [stone] n and [gold] n; the stones are
/// made from [stones]' recipes, and an item at +n shows under [tints] n at [tintAlpha]. Read by enhance.dart's
/// [Enhance] (decisions-log 255).
class EnhanceRules {
  const EnhanceRules({
    this.from = 30,
    this.most = 5,
    this.per = 0.10,
    this.gold = const [500, 1000, 1500, 2500, 4000],
    this.stone = const [Mat.mithril, Mat.mithril, Mat.mithril, Mat.starmetal, Mat.starmetal],
    this.stones = _enhanceStones,
    this.tints = const [0xFF3D8BFF, 0xFFE8203A, 0xFFFFC93C, 0xFF8E44FF, 0xFFF2F6FF],
    this.tintAlpha = 0.45,
  });

  final int from, most;
  final double per, tintAlpha;
  final List<int> gold;
  final List<Mat> stone;
  final Map<Mat, StoneRecipe> stones;

  /// The colours as 0xAARRGGBB (the file's `#RRGGBB`, opaque).
  final List<int> tints;

  /// [j]'s rules. The per-step lists ([gold], [stone], [tints]) are taken whole and only when each has [most] entries
  /// of the right kind, else all three keep the default (noted in [skipped]); a stone the game doesn't know is left out.
  factory EnhanceRules.fromJson(Map<String, dynamic> j, List<String> skipped) {
    const d = EnhanceRules();
    final most = switch (j['most']) { final int n when n > 0 => n, _ => d.most };
    int? colour(Object? v) => switch (v) {
          final String s when RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(s) => 0xFF000000 | int.parse(s.substring(1), radix: 16),
          _ => null,
        };
    // A list the file leaves out is the default's, which has the default's steps.
    List<T>? steps<T extends Object>(Object? v, List<T> def, T? Function(Object?) read) => switch (v) {
          null when most == d.most => def,
          final List<dynamic> l when l.length == most => switch ([for (final e in l) read(e)]) {
              final r when !r.contains(null) => [for (final e in r) e!],
              _ => null,
            },
          _ => null,
        };
    final lists = switch ((
      steps(j['gold'], d.gold, (v) => v is int && v >= 0 ? v : null),
      steps(j['stone'], d.stone, (v) => Mat.values.asNameMap()[v]),
      steps(j['tints'], d.tints, colour),
    )) {
      (final g?, final s?, final t?) => (most, g, s, t),
      _ => null,
    };
    if (lists == null) skipped.add('enhance: gold, stone and tints need $most steps each');
    final (count, gold, stone, tints) = lists ?? (d.most, d.gold, d.stone, d.tints);
    return EnhanceRules(
      from: _number(j['from'], d.from).toInt(),
      most: count,
      per: switch (j['per']) { final num v when v > 0 && v.isFinite => v.toDouble(), _ => d.per },
      gold: gold,
      stone: stone,
      stones: switch (j['stones']) {
        final Map<String, dynamic> m => {
            for (final MapEntry(:key, :value) in m.entries)
              if ((_mat(key, skipped, 'enhance.stones'), value) case (final s?, final Map<String, dynamic> v))
                s: StoneRecipe.fromJson(v, d.stones[s] ?? const StoneRecipe({}, 0), skipped, 'enhance.stones.$key'),
          },
        _ => d.stones,
      },
      tints: tints,
      tintAlpha: switch (j['tintAlpha']) { final num v when v >= 0 && v <= 1 => v.toDouble(), _ => d.tintAlpha },
    );
  }

  Map<String, dynamic> toJson() => {
        'from': from,
        'most': most,
        'per': per,
        'gold': gold,
        'stone': [for (final m in stone) m.name],
        'stones': {for (final MapEntry(:key, :value) in stones.entries) key.name: value.toJson()},
        'tints': [for (final c in tints) '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}'],
        'tintAlpha': tintAlpha,
      };
}

/// A forge stone's Smithy recipe (town.json `enhance.stones.<stone>`): the [materials] (Starmetal takes a Mithril) and
/// the [gold].
class StoneRecipe {
  const StoneRecipe(this.materials, this.gold);

  final Map<Mat, int> materials;
  final int gold;

  factory StoneRecipe.fromJson(Map<String, dynamic> j, StoneRecipe d, List<String> skipped, String where) => StoneRecipe(
        switch (j['materials']) { final Map<String, dynamic> m => _matCounts(m, skipped, '$where.materials'), _ => d.materials },
        _number(j['gold'], d.gold).toInt(),
      );

  Map<String, dynamic> toJson() => {'materials': _matJson(materials), 'gold': gold};
}

/// When Towns come (town.json `schedule`; the owner's B1-B3: 20% at first and after each Town, +5% a missed roll, up to
/// 100%; at least 5 waves fought between two Towns).
class TownSchedule {
  const TownSchedule({
    this.chanceStart = 0.20,
    this.chanceStep = 0.05,
    this.chanceCap = 1.00,
    this.minGap = 5,
    this.firstTownAfter = 2,
    this.autoLeave = 5.0,
  });

  /// The first roll's chance, and again after each Town.
  final double chanceStart;

  /// Added after each missed roll.
  final double chanceStep;

  /// The chance never goes above it.
  final double chanceCap;

  /// A Town's slot is at least this many after the last Town's: that many waves fought between two Towns.
  final int minGap;

  /// A new run counts as if a Town had come before this wave.
  final int firstTownAfter;

  /// Seconds Auto waits in a Town before it leaves (and the next wave starts).
  final double autoLeave;

  factory TownSchedule.fromJson(Map<String, dynamic> j) {
    const d = TownSchedule();
    double share(String k, double def) => switch (j[k]) { final num v when v >= 0 && v <= 1 => v.toDouble(), _ => def };
    int atLeast(String k, int min, int def) => switch (j[k]) { final int v when v >= min => v, _ => def };
    var (start, cap) = (share('chanceStart', d.chanceStart), share('chanceCap', d.chanceCap));
    if (cap < start) (start, cap) = (d.chanceStart, d.chanceCap); // a cap under the start would cut the first roll
    return TownSchedule(
      chanceStart: start,
      chanceStep: share('chanceStep', d.chanceStep),
      chanceCap: cap,
      minGap: atLeast('minGap', 1, d.minGap),
      firstTownAfter: atLeast('firstTownAfter', 0, d.firstTownAfter),
      autoLeave: switch (j['autoLeave']) { final num v when v >= 0 && v.isFinite => v.toDouble(), _ => d.autoLeave },
    );
  }

  Map<String, dynamic> toJson() => {
        'chanceStart': chanceStart,
        'chanceStep': chanceStep,
        'chanceCap': chanceCap,
        'minGap': minGap,
        'firstTownAfter': firstTownAfter,
        'autoLeave': autoLeave,
      };
}

/// A material's grade (town.json `materials`): a monster type's Common part (its normal and elite kills), its Rare part
/// (its high elites, mini bosses and bosses), a Trophy (always from a mini boss or the boss), or the forge's crafted
/// stones (decisions-log 245: made at a Smithy, never dropped, [craftedMats]).
enum MatGrade { common, rare, trophy, crafted }

/// The 30 materials (decisions-log 221; docs/loot-items-relics.md "Town and Smithy"): each monster type's Common and Rare
/// part and the three Trophies, which the Smithy crafts relics from. Monsters drop them
/// ([Materials._dropMaterials]), into [Game.materials] at a won wave. The value is the save key and the icon's name
/// (`mat_<name>.png`), so a new one is only ever appended; this order is the Bag's: Common, Rare, Trophy, and within a
/// grade the monsters weakest first ([enemyTypes]), then the healer, then the Necromancer. The forge's two stones come
/// last ([craftedMats]).
enum Mat {
  slimeGel, batWing, boneShard, orcTooth, boneArrow, wolfClaw, rustyPlate, leatherStrap, orcEar, ironScrap, bigBone, //
  bearFur, tealCloth,
  slimeCore, batFang, skull, orcTusk, boneBow, wolfFang, crackedSkull, wargFang, orcHeart, ironTusk, graveSteel, //
  bearClaw, tealGem, darkGem,
  evilEye, soulOrb, lichOrb,
  // The forge's Enhance stones (decisions-log 245; forge-design §12): made at a Smithy, never dropped.
  mithril, starmetal;

  /// Its name in the game ([Words.materialNames]).
  String get label => Words.materialNames[name]!;

  /// Made at a Smithy, never dropped ([craftedMats]).
  bool get crafted => craftedMats.contains(this);
}

/// The forge's stones (decisions-log 245; forge-design §12): Smithy-made for Enhance (town.json `enhance.stones`). No
/// monster drops one, the Shop's shelf never holds one ([Game.matsSeen]); the Bag shows them
/// ([Materials.matsInPlay]).
const craftedMats = [Mat.mithril, Mat.starmetal];

/// The materials monsters drop: every [Mat] but the [craftedMats] (the 30 of decisions-log 221).
final droppedMats = [for (final m in Mat.values) if (!m.crafted) m];

/// What a kill of one rank drops (town.json `drops`): its type's [part] (its Common or Rare, [TownRules.parts]) at
/// [chance], [count] of it, and [plus] always.
class MatDrop {
  const MatDrop(this.part, this.chance, {this.count = 1, this.plus = const {}});

  /// The grade of the type's part it drops: common or rare.
  final MatGrade part;

  /// The chance a kill drops it: 1 always (no draw), 0 never.
  final double chance;
  final int count;

  /// What it drops on top, always (the Trophies).
  final Map<Mat, int> plus;

  factory MatDrop.fromJson(Map<String, dynamic> j, MatDrop d, List<String> skipped, String where) => MatDrop(
        switch (j['part']) { 'common' => MatGrade.common, 'rare' => MatGrade.rare, _ => d.part },
        _townShare(j['chance'], d.chance),
        count: _number(j['count'], d.count).toInt(),
        plus: switch (j['plus']) { final Map<String, dynamic> m => _matCounts(m, skipped, '$where.plus'), _ => d.plus },
      );

  Map<String, dynamic> toJson() => {'part': part.name, 'chance': chance, 'count': count, if (plus.isNotEmpty) 'plus': _matJson(plus)};
}

/// A material's grade and the gold the Town's Shop pays for one (town.json `materials`).
class MatInfo {
  const MatInfo(this.grade, this.sell);

  final MatGrade grade;
  final int sell;

  factory MatInfo.fromJson(Map<String, dynamic> j, MatInfo d) => MatInfo(
        MatGrade.values.asNameMap()[j['grade']] ?? d.grade,
        _number(j['sell'], d.sell).toInt(),
      );

  Map<String, dynamic> toJson() => {'grade': grade.name, 'sell': sell};
}

/// A crafted relic's tier: what its recipe takes and its prices ([TierPrices]).
enum RelicTier { basic, strong, mighty }

/// The small relics a Smithy crafts but the forge's, by their save keys: today's four and the Smithy's seven
/// ([smallRelics], relics.dart). The forge's nine ([forgeRelics]) have recipes too ([TownRules.recipes]).
const townRelics = [
  'fang', 'thorns', 'fury', 'guard', 'cleave', 'venom', 'manaSiphon', 'spiritWard', 'lastStand', 'giantSlayer', //
  'blessing',
];

/// A Smithy recipe (town.json `recipes`): the relic's [tier], the [materials], [items] and [gold] it takes.
class Recipe {
  const Recipe(this.tier, this.materials, this.gold, {this.items = const {}});

  final RelicTier tier;
  final Map<Mat, int> materials;
  final Map<Item, int> items;
  final int gold;

  factory Recipe.fromJson(Map<String, dynamic> j, Recipe d, List<String> skipped, String where) => Recipe(
        RelicTier.values.asNameMap()[j['tier']] ?? d.tier,
        switch (j['materials']) { final Map<String, dynamic> m => _matCounts(m, skipped, '$where.materials'), _ => d.materials },
        _number(j['gold'], d.gold).toInt(),
        items: switch (j['items']) { final Map<String, dynamic> m => _counts(m, Item.values, skipped, '$where.items'), _ => d.items },
      );

  Map<String, dynamic> toJson() => {
        'tier': tier.name,
        'materials': _matJson(materials),
        'items': {for (final MapEntry(:key, :value) in items.entries) key.name: value},
        'gold': gold,
      };

  /// What of [toJson] differs from [base]'s, each field whole: a relic entry's `forge` block (decisions-log 245).
  Map<String, dynamic> changesFrom(Recipe base) {
    final (mine, theirs) = (toJson(), base.toJson());
    return {for (final MapEntry(:key, :value) in mine.entries) if (jsonEncode(value) != jsonEncode(theirs[key])) key: value};
  }
}

/// An item's Smithy recipe and what one does (town.json `items`, decisions-log 245): the
/// [materials], the lower-grade [items] it takes (only the Cap's and the Ring's grades II and III take one, the grade
/// below's), the [gold], and its [effect] on a troop type by its kind ([Item.slot]): sword and staff attack ×, shield
/// defence +, boots walk ×, bow reach ×, gloves wait ×, potion regen + HP/s, amulet max HP ×, beads heal ×, torch damage
/// to the undead ×, spear melee reach ×, prism splash ×, helm damage taken ×, ring MP regen + per s. The grade-I seven's
/// effects are today's ([swordDmg] …). The grade-I spear's and prism's entries also hold their kind's ceiling,
/// [reachMost] and [splashMost] (decisions-log 251).
class ItemRecipe {
  const ItemRecipe(this.materials, this.gold, this.effect, {this.items = const {}, this.reachMost, this.splashMost});

  final Map<Mat, int> materials;
  final Map<Item, int> items;
  final int gold;
  final double effect;

  /// The spear's only (`items.spear.reachMost`; null on every other item): however many spears a type holds, its reach
  /// stops at this many times its base reach, and its reach cap at this many times [meleeMaxRange] ([Game.statsOf]).
  final double? reachMost;

  /// The prism's only (`items.prism.splashMost`; null on every other item): however many prisms a type holds, its splash
  /// stops at this many times its base splash ([Game.statsOf]).
  final double? splashMost;

  factory ItemRecipe.fromJson(Map<String, dynamic> j, ItemRecipe d, List<String> skipped, String where) => ItemRecipe(
        switch (j['materials']) { final Map<String, dynamic> m => _matCounts(m, skipped, '$where.materials'), _ => d.materials },
        _number(j['gold'], d.gold).toInt(),
        _number(j['effect'], d.effect).toDouble(),
        items: switch (j['items']) { final Map<String, dynamic> m => _counts(m, Item.values, skipped, '$where.items'), _ => d.items },
        reachMost: switch (j['reachMost']) { final num v when v >= 1 && v.isFinite => v.toDouble(), _ => d.reachMost },
        splashMost: switch (j['splashMost']) { final num v when v >= 1 && v.isFinite => v.toDouble(), _ => d.splashMost },
      );

  Map<String, dynamic> toJson() => {
        'materials': _matJson(materials),
        'items': {for (final MapEntry(:key, :value) in items.entries) key.name: value},
        'gold': gold,
        'effect': effect,
        'reachMost': ?reachMost,
        'splashMost': ?splashMost,
      };
}

/// The small relics' combos (town.json `combos`, decisions-log 245; forge-design §6): never named in the game. The
/// product of the small relics' damage factors on one blow is at most [relicMost] (the Artifacts' own stay outside it);
/// each of the [secrets] changes one relic's numbers when its holder has what it names. Data only, nothing reads it yet.
class Combos {
  const Combos({this.relicMost = 3.0, this.secrets = _townSecrets});

  final double relicMost;
  final Map<String, Secret> secrets;

  /// [j]'s numbers; a `secret` block replaces the defaults' whole, a bad entry in it left out (noted in [skipped]).
  factory Combos.fromJson(Map<String, dynamic> j, List<String> skipped) {
    const d = Combos();
    return Combos(
      relicMost: switch (j['relicMost']) { final num v when v >= 1 && v.isFinite => v.toDouble(), _ => d.relicMost },
      secrets: switch (j['secret']) {
        final Map<String, dynamic> m => {
            for (final MapEntry(:key, :value) in m.entries) key: ?Secret.fromJson(value, skipped, 'combos.secret.$key'),
          },
        _ => d.secrets,
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'relicMost': relicMost,
        'secret': {for (final MapEntry(:key, :value) in secrets.entries) key: value.toJson()},
      };
}

/// A hidden pairing (town.json `combos.secret.<name>`): a troop holding every one of [holds] (a Hero holds two), whose
/// type has [artifact] bound when one is named, gets [relic]'s numbers ([TownRules.relics]) [set] to these.
class Secret {
  const Secret(this.holds, this.relic, this.set, {this.artifact});

  final List<Relic> holds;
  final Relic relic;
  final Map<String, num> set;
  final Relic? artifact;

  /// [j] as a secret, or null (noted in [skipped]) when a name isn't a small relic (an Artifact for `artifact`), its
  /// [relic] isn't one it holds, or a number isn't one [relic] has.
  static Secret? fromJson(Object? j, List<String> skipped, String where) {
    final names = Relic.values.asNameMap();
    if (j case {'holds': final List holds, 'relic': final String relic, 'set': final Map<String, dynamic> set}) {
      final held = [for (final n in holds) if (names[n] case final r? when !r.pusaka) r];
      final artifact = (j as Map)['artifact'], bound = names[artifact];
      final nums = _townRelicNumbers[relic] ?? const <String, num>{};
      final numbers = <String, num>{
        for (final MapEntry(:key, :value) in set.entries) if (nums[key] case final def?) key: _number(value, def),
      };
      if (held.length == holds.length && held.any((r) => r.name == relic) && (artifact == null || (bound?.pusaka ?? false)) &&
          numbers.isNotEmpty && numbers.length == set.length) {
        return Secret(held, names[relic]!, numbers, artifact: bound);
      }
    }
    skipped.add('$where: not a secret');
    return null;
  }

  Map<String, dynamic> toJson() => {
        'holds': [for (final r in holds) r.name],
        'artifact': ?artifact?.name,
        'relic': relic.name,
        'set': set,
      };
}

/// A relic tier's prices (town.json `tiers`): a sale pays [sellShare] of its recipe's gold; the Town's Shop sells one
/// at [shop] gold, [shopRise] of it more after each bought.
class TierPrices {
  const TierPrices(this.shop, {this.sellShare = 0.5, this.shopRise = 0.2});

  final double sellShare, shopRise;
  final int shop;

  /// What the Shop asks for one after [n] of the kind were bought: [shop], and [shopRise] of it more for each.
  int priceAfter(int n) => shop + (shop * shopRise).round() * n;

  factory TierPrices.fromJson(Map<String, dynamic> j, TierPrices d) => TierPrices(
        _number(j['shop'], d.shop).toInt(),
        sellShare: _townShare(j['sellShare'], d.sellShare),
        shopRise: _number(j['shopRise'], d.shopRise).toDouble(),
      );

  Map<String, dynamic> toJson() => {'sellShare': sellShare, 'shop': shop, 'shopRise': shopRise};
}

/// The Town's Shop (town.json `shop`): open from wave [from]'s win (1, the owner's 2026-10-07 "shop juga harusnya di buka
/// ketika masuk kota": open in every Town, decisions-log 253; it was 15) — OWNER-MAY-CHANGE KNOB; an item costs
/// [itemPrice], [itemRise] more after each bought, and sells back for [itemSellShare] of its price. It sells (decisions-log 246) the materials
/// that have dropped ([Game.matsSeen]) at [matMarkup] times their sell price, and [matRise] of that more a buy ([matPrice]).
class TownShop {
  const TownShop({
    this.from = 1,
    this.itemPrice = 2000,
    this.itemRise = 200,
    this.itemSellShare = 0.5,
    this.matMarkup = 2.5,
    this.matRise = 0.0,
  });

  final int from, itemPrice, itemRise;
  final double itemSellShare, matMarkup, matRise;

  /// What the Shop asks for a material that sells for [sell], after [n] of it were bought: [sell] × [matMarkup] rounded
  /// up to 5 (Slime Gel 10: 25, Wolf Claw 25: 65), then [matRise] of that more a buy, each step rounded up to 5 too.
  int matPrice(int sell, [int n = 0]) {
    int upTo5(double v) => (v / 5 - 1e-9).ceil() * 5;
    final base = upTo5(sell * matMarkup);
    return base + upTo5(base * matRise) * n;
  }

  factory TownShop.fromJson(Map<String, dynamic> j) {
    const d = TownShop();
    return TownShop(
      from: max(1, _number(j['from'], d.from).toInt()),
      itemPrice: _number(j['itemPrice'], d.itemPrice).toInt(),
      itemRise: _number(j['itemRise'], d.itemRise).toInt(),
      itemSellShare: _townShare(j['itemSellShare'], d.itemSellShare),
      matMarkup: _number(j['matMarkup'], d.matMarkup).toDouble(),
      matRise: _number(j['matRise'], d.matRise).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'from': from,
        'itemPrice': itemPrice,
        'itemRise': itemRise,
        'itemSellShare': itemSellShare,
        'matMarkup': matMarkup,
        'matRise': matRise,
      };
}

/// [v] when it is a share (0 to 1), else [def].
double _townShare(Object? v, double def) => switch (v) { final num n when n >= 0 && n <= 1 => n.toDouble(), _ => def };

/// [v] when it is a number of [def]'s kind (an int for an int), finite and not negative, else [def].
num _number(Object? v, num def) => switch (v) {
      final int n when n >= 0 => def is int ? n : n.toDouble(),
      final double n when def is double && n.isFinite && n >= 0 => n,
      _ => def,
    };

/// A material by its save key: null for null, and for a name the game doesn't know (noted in [skipped]).
Mat? _mat(Object? name, List<String> skipped, String where) {
  if (name == null) return null;
  final m = Mat.values.asNameMap()[name];
  if (m == null) skipped.add('$where: no $name');
  return m;
}

/// The kinds of [j] (by name, of [values]) with their counts, each at least 1; an unknown name or a bad count is left
/// out and noted in [skipped].
Map<T, int> _counts<T extends Enum>(Map<String, dynamic> j, List<T> values, List<String> skipped, String where) {
  final out = <T, int>{};
  for (final MapEntry(:key, :value) in j.entries) {
    if ((values.asNameMap()[key], value) case (final k?, final int n) when n > 0) {
      out[k] = n;
    } else {
      skipped.add('$where: $key $value');
    }
  }
  return out;
}

Map<Mat, int> _matCounts(Map<String, dynamic> j, List<String> skipped, String where) => _counts(j, Mat.values, skipped, where);

Map<String, int> _matJson(Map<Mat, int> m) => {for (final MapEntry(:key, :value) in m.entries) key.name: value};

// The shipped numbers (assets/config/town.json writes each one out; test/town_materials_test.dart pins them).

/// The forge's drops (decisions-log 246; forge-design §2): about 3x the materials, the Trophies as before.
const _forgeDrops = {
  Tier.normal: [MatDrop(MatGrade.common, 0.60)],
  Tier.elite: [MatDrop(MatGrade.common, 1.0)],
  Tier.highElite: [MatDrop(MatGrade.common, 1.0), MatDrop(MatGrade.rare, 0.50)],
  Tier.miniBoss: [MatDrop(MatGrade.common, 1.0, count: 3), MatDrop(MatGrade.rare, 1.0, count: 3, plus: {Mat.evilEye: 1})],
  Tier.boss: [MatDrop(MatGrade.common, 1.0, count: 4), MatDrop(MatGrade.rare, 1.0, count: 4, plus: {Mat.soulOrb: 1})],
};

const _townParts = {
  'slime': (Mat.slimeGel, Mat.slimeCore),
  'bat': (Mat.batWing, Mat.batFang),
  'skeleton': (Mat.boneShard, Mat.skull),
  'orc': (Mat.orcTooth, Mat.orcTusk),
  'skeleton_archer': (Mat.boneArrow, Mat.boneBow),
  'werewolf': (Mat.wolfClaw, Mat.wolfFang),
  'armored_skeleton': (Mat.rustyPlate, Mat.crackedSkull),
  'orc_rider': (Mat.leatherStrap, Mat.wargFang),
  'elite_orc': (Mat.orcEar, Mat.orcHeart),
  'armored_orc': (Mat.ironScrap, Mat.ironTusk),
  'greatsword_skeleton': (Mat.bigBone, Mat.graveSteel),
  'werebear': (Mat.bearFur, Mat.bearClaw),
  necroHealer: (Mat.tealCloth, Mat.tealGem),
  boss: (null, Mat.darkGem), // the Necromancer is never normal or elite
};

const _townMaterials = {
  Mat.slimeGel: MatInfo(MatGrade.common, 10),
  Mat.batWing: MatInfo(MatGrade.common, 10),
  Mat.boneShard: MatInfo(MatGrade.common, 15),
  Mat.orcTooth: MatInfo(MatGrade.common, 15),
  Mat.boneArrow: MatInfo(MatGrade.common, 20),
  Mat.wolfClaw: MatInfo(MatGrade.common, 25),
  Mat.rustyPlate: MatInfo(MatGrade.common, 25),
  Mat.leatherStrap: MatInfo(MatGrade.common, 30),
  Mat.orcEar: MatInfo(MatGrade.common, 35),
  Mat.ironScrap: MatInfo(MatGrade.common, 40),
  Mat.bigBone: MatInfo(MatGrade.common, 40),
  Mat.bearFur: MatInfo(MatGrade.common, 50),
  Mat.tealCloth: MatInfo(MatGrade.common, 30),
  Mat.slimeCore: MatInfo(MatGrade.rare, 40),
  Mat.batFang: MatInfo(MatGrade.rare, 40),
  Mat.skull: MatInfo(MatGrade.rare, 60),
  Mat.orcTusk: MatInfo(MatGrade.rare, 60),
  Mat.boneBow: MatInfo(MatGrade.rare, 80),
  Mat.wolfFang: MatInfo(MatGrade.rare, 100),
  Mat.crackedSkull: MatInfo(MatGrade.rare, 100),
  Mat.wargFang: MatInfo(MatGrade.rare, 120),
  Mat.orcHeart: MatInfo(MatGrade.rare, 140),
  Mat.ironTusk: MatInfo(MatGrade.rare, 160),
  Mat.graveSteel: MatInfo(MatGrade.rare, 160),
  Mat.bearClaw: MatInfo(MatGrade.rare, 200),
  Mat.tealGem: MatInfo(MatGrade.rare, 120),
  Mat.darkGem: MatInfo(MatGrade.rare, 200),
  Mat.evilEye: MatInfo(MatGrade.trophy, 300),
  Mat.soulOrb: MatInfo(MatGrade.trophy, 600),
  Mat.lichOrb: MatInfo(MatGrade.trophy, 800),
  // Half a stone's worth, like any item the Shop buys: its materials' sell prices and its gold (forge-design §12).
  Mat.mithril: MatInfo(MatGrade.crafted, 770),
  Mat.starmetal: MatInfo(MatGrade.crafted, 2970),
};

const _townRecipes = {
  'fang': Recipe(RelicTier.basic, {Mat.batWing: 2, Mat.slimeGel: 2}, 300),
  'thorns': Recipe(RelicTier.basic, {Mat.slimeGel: 3, Mat.boneShard: 2}, 300),
  'fury': Recipe(RelicTier.basic, {Mat.batWing: 2, Mat.boneShard: 2, Mat.skull: 1}, 400),
  'guard': Recipe(RelicTier.basic, {Mat.orcTooth: 3, Mat.slimeGel: 2}, 400),
  'cleave': Recipe(RelicTier.strong, {Mat.wolfClaw: 4, Mat.leatherStrap: 3, Mat.orcTusk: 2, Mat.wolfFang: 1}, 1000, items: {Item.sword: 1}),
  'venom': Recipe(RelicTier.strong, {Mat.boneArrow: 4, Mat.slimeCore: 2, Mat.batFang: 1, Mat.boneBow: 1}, 1000, items: {Item.bow: 1}),
  'manaSiphon': Recipe(RelicTier.strong, {Mat.tealCloth: 4, Mat.batFang: 2, Mat.slimeCore: 1, Mat.tealGem: 1}, 1000, items: {Item.staff: 1}),
  'spiritWard': Recipe(RelicTier.strong, {Mat.rustyPlate: 4, Mat.skull: 2, Mat.crackedSkull: 1, Mat.wargFang: 1}, 1000, items: {Item.shield: 1}),
  'lastStand': Recipe(RelicTier.mighty, {Mat.bearFur: 3, Mat.orcHeart: 1, Mat.bearClaw: 1, Mat.evilEye: 1}, 3000, items: {Item.boots: 1}),
  'giantSlayer': Recipe(RelicTier.mighty, {Mat.ironScrap: 4, Mat.orcEar: 3, Mat.ironTusk: 1, Mat.soulOrb: 1}, 3500, items: {Item.gloves: 1}),
  'blessing': Recipe(RelicTier.mighty, {Mat.bigBone: 4, Mat.graveSteel: 1, Mat.darkGem: 2, Mat.lichOrb: 1}, 3000, items: {Item.potion: 1}),
  // The forge's nine (decisions-log 245; forge-design §5), at the forge's relic gold (70%, §11).
  'chill': Recipe(RelicTier.basic, {Mat.boneArrow: 3, Mat.slimeCore: 1}, 200),
  'sharkTooth': Recipe(RelicTier.basic, {Mat.wolfClaw: 3, Mat.batFang: 1}, 300),
  'grit': Recipe(RelicTier.basic, {Mat.rustyPlate: 3, Mat.orcTusk: 1}, 300),
  'ambush': Recipe(RelicTier.strong, {Mat.leatherStrap: 3, Mat.orcEar: 1, Mat.wargFang: 1, Mat.wolfFang: 1}, 700),
  'weakSpot': Recipe(RelicTier.strong, {Mat.boneArrow: 2, Mat.rustyPlate: 2, Mat.crackedSkull: 1, Mat.boneBow: 1}, 700),
  'hotStreak': Recipe(RelicTier.strong, {Mat.orcEar: 3, Mat.leatherStrap: 1, Mat.orcHeart: 1, Mat.wargFang: 1}, 700),
  'avalanche':
      Recipe(RelicTier.mighty, {Mat.ironScrap: 3, Mat.bigBone: 2, Mat.graveSteel: 1, Mat.evilEye: 1}, 2100, items: {Item.steelSword: 1}),
  'afterglow':
      Recipe(RelicTier.mighty, {Mat.orcEar: 3, Mat.darkGem: 1, Mat.tealGem: 1, Mat.evilEye: 1}, 2100, items: {Item.magicStaff: 1}),
  'reaper':
      Recipe(RelicTier.mighty, {Mat.bearFur: 2, Mat.bigBone: 2, Mat.bearClaw: 1, Mat.soulOrb: 1}, 2450, items: {Item.longBow: 1}),
};

/// What the forge changes in the eleven relics' recipes (decisions-log 245; forge-design §5, §11): every one costs 70% of
/// the gold (rounded to 50), since Awaken by grade takes gold the relics had; Mana Siphon's materials (Teal Cloth was
/// scarce) and the Mighty three's item, a grade-II one.
const _townForgeChanges = {
  'fang': Recipe(RelicTier.basic, {Mat.batWing: 2, Mat.slimeGel: 2}, 200),
  'thorns': Recipe(RelicTier.basic, {Mat.slimeGel: 3, Mat.boneShard: 2}, 200),
  'fury': Recipe(RelicTier.basic, {Mat.batWing: 2, Mat.boneShard: 2, Mat.skull: 1}, 300),
  'guard': Recipe(RelicTier.basic, {Mat.orcTooth: 3, Mat.slimeGel: 2}, 300),
  'cleave':
      Recipe(RelicTier.strong, {Mat.wolfClaw: 4, Mat.leatherStrap: 3, Mat.orcTusk: 2, Mat.wolfFang: 1}, 700, items: {Item.sword: 1}),
  'venom':
      Recipe(RelicTier.strong, {Mat.boneArrow: 4, Mat.slimeCore: 2, Mat.batFang: 1, Mat.boneBow: 1}, 700, items: {Item.bow: 1}),
  'manaSiphon':
      Recipe(RelicTier.strong, {Mat.boneArrow: 3, Mat.batFang: 2, Mat.slimeCore: 1, Mat.tealGem: 1}, 700, items: {Item.staff: 1}),
  'spiritWard':
      Recipe(RelicTier.strong, {Mat.rustyPlate: 4, Mat.skull: 2, Mat.crackedSkull: 1, Mat.wargFang: 1}, 700, items: {Item.shield: 1}),
  'lastStand':
      Recipe(RelicTier.mighty, {Mat.bearFur: 3, Mat.orcHeart: 1, Mat.bearClaw: 1, Mat.evilEye: 1}, 2100, items: {Item.towerShield: 1}),
  'giantSlayer':
      Recipe(RelicTier.mighty, {Mat.ironScrap: 4, Mat.orcEar: 3, Mat.ironTusk: 1, Mat.soulOrb: 1}, 2450, items: {Item.steelGloves: 1}),
  'blessing':
      Recipe(RelicTier.mighty, {Mat.bigBone: 4, Mat.graveSteel: 1, Mat.darkGem: 2, Mat.lichOrb: 1}, 2100, items: {Item.bigPotion: 1}),
};

const _townTiers = {RelicTier.basic: TierPrices(12000), RelicTier.strong: TierPrices(20000), RelicTier.mighty: TierPrices(32000)};

const _townRelicNumbers = <String, Map<String, num>>{
  'fang': {'share': 0.30},
  'thorns': {'share': 0.30},
  'fury': {'every': 3, 'hit': 2.0},
  'guard': {'cut': 0.25},
  'cleave': {'share': 0.30, 'reach': 1.5, 'targets': 1},
  'venom': {'share': 0.20, 'secs': 3.0},
  'manaSiphon': {'mp': 2},
  'spiritWard': {'share': 0.15},
  'lastStand': {'below': 0.25, 'heal': 0.40},
  'giantSlayer': {'k': 1.5},
  'blessing': {'k': 1.4},
  // The forge's nine (decisions-log 245; forge-design §5): not wired yet.
  'chill': {'every': 3, 'slow': 0.30, 'secs': 1.5, 'bossShare': 0.5},
  'sharkTooth': {'k': 1.25},
  'grit': {'below': 0.50, 'k': 1.30},
  'ambush': {'k': 1.35},
  'weakSpot': {'taken': 1.12, 'boss': 1.06, 'secs': 3.0},
  'hotStreak': {'per': 0.10, 'most': 3, 'secs': 4.0},
  'avalanche': {'per': 0.08, 'most': 5, 'reach': 2.0},
  'afterglow': {'hits': 3, 'k': 1.5},
  'reaper': {'below': 0.15, 'bossK': 1.5},
};

/// The spears' ceiling by default (decisions-log 251; town.json `items.spear.reachMost`): a type's reach at most 1.5 times
/// its base reach however many spears it holds (a Lancer's 22 → 33), its reach cap at most 1.5 × [meleeMaxRange], so a
/// melee fighter never reaches like an archer (64).
const spearReachMost = 1.5;

/// The prisms' ceiling by default (decisions-log 251; town.json `items.prism.splashMost`): a type's splash at most 1.5
/// times its base however many prisms it holds (the Wizard's 20 → 30, the Axeman's 16 → 24; the Wizard's whole set
/// 2 + 2 + 2 would be ×2.74, a circle near the field's height).
const prismSplashMost = 1.5;

/// The 42 items' recipes and effects (decisions-log 245; forge-design §1, §10, §11): grade I takes the first monsters'
/// Common parts (20 gold); grades II and III of the twelve Awaken kinds take only the middle and the late monsters'
/// Commons and no item (60 and 250 gold), so the rare parts stay for the relics; the Cap's and the Ring's grade II and
/// III take the grade below, as before.
const _townItems = {
  Item.sword: ItemRecipe({Mat.boneShard: 2, Mat.orcTooth: 2}, 20, swordDmg),
  Item.shield: ItemRecipe({Mat.orcTooth: 2, Mat.boneShard: 1, Mat.slimeGel: 1}, 20, shieldDef),
  Item.boots: ItemRecipe({Mat.batWing: 2, Mat.slimeGel: 2}, 20, bootsSpeed),
  Item.bow: ItemRecipe({Mat.batWing: 2, Mat.boneShard: 1, Mat.tealCloth: 1}, 20, bowRange),
  Item.gloves: ItemRecipe({Mat.batWing: 1, Mat.slimeGel: 1, Mat.orcTooth: 1, Mat.tealCloth: 1}, 20, glovesRate),
  Item.potion: ItemRecipe({Mat.slimeGel: 2, Mat.batWing: 1, Mat.tealCloth: 1}, 20, potionRegen),
  Item.staff: ItemRecipe({Mat.boneShard: 2, Mat.tealCloth: 1, Mat.slimeGel: 1}, 20, staffDmg),
  Item.amulet: ItemRecipe({Mat.orcTooth: 2, Mat.slimeGel: 1, Mat.boneShard: 1}, 20, 1.08),
  Item.prayerBeads: ItemRecipe({Mat.tealCloth: 2, Mat.batWing: 1}, 20, 1.12),
  Item.torch: ItemRecipe({Mat.boneShard: 2, Mat.batWing: 1}, 20, 1.12),
  Item.spear: ItemRecipe({Mat.orcTooth: 1, Mat.boneShard: 1, Mat.batWing: 2}, 20, 1.15, reachMost: spearReachMost),
  Item.prism: ItemRecipe({Mat.slimeGel: 2, Mat.tealCloth: 1}, 20, 1.15, splashMost: prismSplashMost),
  Item.steelSword: ItemRecipe({Mat.wolfClaw: 2, Mat.orcEar: 1}, 60, 1.28),
  Item.towerShield: ItemRecipe({Mat.rustyPlate: 2, Mat.leatherStrap: 1}, 60, 4.0),
  Item.swiftBoots: ItemRecipe({Mat.leatherStrap: 2, Mat.wolfClaw: 1}, 60, 1.27),
  Item.longBow: ItemRecipe({Mat.boneArrow: 2, Mat.leatherStrap: 1}, 60, 1.22),
  Item.steelGloves: ItemRecipe({Mat.leatherStrap: 1, Mat.rustyPlate: 1, Mat.wolfClaw: 1}, 60, 0.78),
  Item.bigPotion: ItemRecipe({Mat.orcEar: 2, Mat.tealCloth: 1}, 60, 8.0),
  Item.magicStaff: ItemRecipe({Mat.boneArrow: 1, Mat.orcEar: 1, Mat.tealCloth: 1}, 60, 1.28),
  Item.silverAmulet: ItemRecipe({Mat.orcEar: 2, Mat.rustyPlate: 1}, 60, 1.10),
  Item.holyBeads: ItemRecipe({Mat.tealCloth: 2, Mat.leatherStrap: 1}, 60, 1.15),
  Item.holyTorch: ItemRecipe({Mat.boneArrow: 2, Mat.rustyPlate: 1}, 60, 1.15),
  Item.wingedSpear: ItemRecipe({Mat.wolfClaw: 1, Mat.rustyPlate: 1, Mat.boneArrow: 1}, 60, 1.18),
  Item.arcanePrism: ItemRecipe({Mat.tealCloth: 1, Mat.wolfClaw: 1, Mat.orcEar: 1}, 60, 1.18),
  Item.royalSword: ItemRecipe({Mat.bigBone: 2, Mat.orcEar: 1}, 250, 1.32),
  Item.royalShield: ItemRecipe({Mat.ironScrap: 2, Mat.rustyPlate: 1}, 250, 6.0),
  Item.windBoots: ItemRecipe({Mat.bearFur: 2, Mat.leatherStrap: 1}, 250, 1.30),
  Item.greatBow: ItemRecipe({Mat.bigBone: 2, Mat.boneArrow: 1}, 250, 1.25),
  Item.royalGloves: ItemRecipe({Mat.ironScrap: 1, Mat.bearFur: 1, Mat.leatherStrap: 1}, 250, 0.75),
  Item.elixir: ItemRecipe({Mat.bearFur: 1, Mat.orcEar: 1, Mat.tealCloth: 1}, 250, 12.0),
  Item.crystalStaff: ItemRecipe({Mat.bearFur: 1, Mat.bigBone: 1, Mat.tealCloth: 1}, 250, 1.32),
  Item.goldAmulet: ItemRecipe({Mat.ironScrap: 1, Mat.bigBone: 1, Mat.orcEar: 1}, 250, 1.12),
  Item.saintBeads: ItemRecipe({Mat.bearFur: 1, Mat.tealCloth: 2}, 250, 1.18),
  Item.sunTorch: ItemRecipe({Mat.bigBone: 2, Mat.boneArrow: 1}, 250, 1.18),
  Item.royalSpear: ItemRecipe({Mat.ironScrap: 2, Mat.wolfClaw: 1}, 250, 1.22),
  Item.royalPrism: ItemRecipe({Mat.bearFur: 1, Mat.ironScrap: 1, Mat.tealCloth: 1}, 250, 1.22),
  Item.leatherCap: ItemRecipe({Mat.leatherStrap: 2, Mat.orcTooth: 1}, 150, 0.96),
  Item.steelHelm: ItemRecipe({Mat.rustyPlate: 2, Mat.skull: 1}, 600, 0.95, items: {Item.leatherCap: 1}),
  Item.royalHelm: ItemRecipe({Mat.ironScrap: 2, Mat.evilEye: 1}, 2500, 0.93, items: {Item.steelHelm: 1}),
  Item.ring: ItemRecipe({Mat.batFang: 1, Mat.slimeCore: 1}, 150, 0.10),
  Item.gemRing: ItemRecipe({Mat.tealGem: 1, Mat.wolfFang: 1}, 600, 0.15, items: {Item.ring: 1}),
  Item.royalRing: ItemRecipe({Mat.bearClaw: 1, Mat.soulOrb: 1}, 2500, 0.20, items: {Item.gemRing: 1}),
};

/// The forge's stones' recipes (decisions-log 245; forge-design §12): Mithril from the trophies and late parts, Starmetal
/// from the two rarest trophies and a Mithril.
const _enhanceStones = {
  Mat.mithril: StoneRecipe({Mat.evilEye: 1, Mat.ironScrap: 2, Mat.graveSteel: 1}, 1000),
  Mat.starmetal: StoneRecipe({Mat.soulOrb: 1, Mat.lichOrb: 1, Mat.mithril: 1}, 3000),
};

/// The four hidden pairings (decisions-log 245; forge-design §6), described nowhere in the game.
const _townSecrets = {
  'venom+sharkTooth': Secret([Relic.venom, Relic.sharkTooth], Relic.venom, {'share': 0.30}),
  'cleave+avalanche': Secret([Relic.cleave, Relic.avalanche], Relic.cleave, {'targets': 2}),
  'weakSpot@voidEye': Secret([Relic.weakSpot], Relic.weakSpot, {'taken': 1.20}, artifact: Relic.voidEye),
  'chill@snareCord': Secret([Relic.chill], Relic.chill, {'every': 2}, artifact: Relic.snareCord),
};

/// The rules every [Game] starts with: the defaults until the game loads assets/config/town.json at start (main.dart).
TownRules loadedTownRules = const TownRules();

/// The Town's schedule and state on [Game] (the fields are the class's: [Game.townAt], …).
extension Towns on Game {
  /// The chance of the next roll: [TownSchedule.chanceStart] until a roll moved it.
  double get townChance => _townChance ?? townRules.schedule.chanceStart;

  /// The slot of the last Town left, or where a new run counts one ([TownSchedule.firstTownAfter]).
  int get townLast => _townLast ?? townRules.schedule.firstTownAfter;

  /// The marked Town comes before the next wave: between waves. While it is due (until it is left, [leaveTown]) no wave
  /// starts ([Game.canStartWave]).
  bool get townDue => townAt != null && townAt == wave + 1 && !waveActive;

  /// The Town before wave [townAt] was marked and hasn't come yet ([TownMarked]): the wave meter's chip says so.
  bool get townMarked => townAt != null && !inTown;

  /// Goes into the due Town ([townDue]); [auto]: Auto was on. False (nothing changes) when none is due or it is in one.
  bool enterTown({bool auto = false}) {
    if (!townDue || inTown || over) return false;
    inTown = true;
    _marketNewTown(); // its number and the market's recovery (market.dart)
    _townSince = t;
    _townCrafts.clear();
    _townCraftSpent = 0;
    _rollTavern(); // the Tavern's offers (tavern.dart), on its own dice
    _emit(TownEntered(wave, t, slot: townAt!, gold: gold, auto: auto, n: townCount, identity: townIdentity.key));
    return true;
  }

  /// Leaves the Town ([auto]: Auto left it): its slot becomes [townLast] and the mark goes, so the next wave can start.
  /// False (nothing changes) when not in one.
  bool leaveTown({bool auto = false}) {
    if (!inTown) return false;
    final slot = townAt!;
    inTown = false;
    _townLast = slot;
    townAt = null;
    _emit(TownLeft(wave, t,
        slot: slot, secs: ((t - _townSince) * 100).round() / 100, auto: auto, crafts: {..._townCrafts}, craftSpent: _townCraftSpent,
        tavern: _tavernLeft)); // the Tavern's visit (tavern.dart): null without it
    _townCrafts.clear();
    _townCraftSpent = 0;
    _tavern = null; // the offers go with the Town (tavern.dart)
    _wishSweep(); // a free wish met another way (a chest's relic) drops off too (wishlist.dart)
    return true;
  }

  /// The roll after wave [Game.wave] was won (the class comment's rule). The wave's record gets what it did
  /// ([TownRolled]).
  void _rollTown() {
    final s = townRules.schedule, slot = wave + 2;
    if (townAt case final at?) return _emit(TownRolled(wave, t, town: {'marked': at}));
    if (slot - townLast < s.minGap) return _emit(TownRolled(wave, t, town: {'blocked': true}));
    // Every won wave from the first unblocked one rolls once until a hit: this is the rolls-th since the last Town.
    final chance = townChance, rolls = slot - townLast - s.minGap + 1, hit = townDice.nextDouble() < chance;
    if (hit) {
      townAt = slot;
      _townChance = s.chanceStart;
    } else {
      _townChance = min(s.chanceCap, chance + s.chanceStep);
    }
    _emit(TownRolled(wave, t, town: {'chance': chance, 'hit': hit, if (hit) 'slot': slot}));
    if (hit) _emit(TownMarked(wave, t, slot: slot, chance: chance, rolls: rolls));
  }

  /// A probe's way through a due Town with no player ([Game.townPolicy], at the next wave's start): 'leave' enters it
  /// and leaves at once, buying at the Tavern first by [Game.tavernPolicy] (tavern.dart).
  void _townByPolicy() {
    if (townPolicy == null || !townDue) return;
    enterTown(auto: true);
    if (tavernPolicy != null) _tavernByPolicy();
    leaveTown(auto: true);
  }

  /// The save's `town`: the chance, the last Town's slot, the marked slot and whether the player is in it; the Tavern's
  /// keys (tavern.dart), none while unused.
  Map<String, Object> get _townJson => {
        'town': {'chance': townChance, 'last': townLast, 'at': ?townAt, if (inTown) 'in': true, if (townCount > 0) 'n': townCount, ..._tavernTownJson},
      };

  /// [j]'s `town` (a save without it is from before the Towns: it counts as a Town before its own
  /// wave, so the first comes [TownSchedule.minGap] waves on at the earliest, like a new run's). A mark already passed,
  /// and `in` without a due Town, are dropped.
  void _loadTown(Map<String, dynamic> j) {
    if (j['town'] case final Map town) {
      _townChance = switch (town['chance']) { final num v when v >= 0 && v <= 1 => v.toDouble(), _ => null };
      _townLast = town['last'] as int?;
      townAt = switch (town['at']) { final int at when at > wave => at, _ => null };
      inTown = town['in'] == true && townAt == wave + 1;
      _loadTavern(town); // the Tavern's (tavern.dart)
      townCount = switch (town['n']) { final int n when n >= 0 => n, _ => _townCountGuess };
    } else if (wave > 0) {
      _townLast = max(wave, townRules.schedule.firstTownAfter);
      townCount = _townCountGuess;
    }
  }

  /// The Towns a save without its count (`town.n`, decisions-log 326) has been through: one each [townGapGuess] waves
  /// from the run's first count to its last Town's slot, and the one it is in.
  int get _townCountGuess =>
      max(0, ((townLast - townRules.schedule.firstTownAfter) / townGapGuess).round()) + (inTown ? 1 : 0);

  /// The wave meter chip's tooltip ([townMarked]): "Town after wave 12" and what a Town holds, in the street's order (its
  /// Smithy crafts the items too, decisions-log 272; the Tavern, decisions-log 268).
  (String, List<String>) get townTip => ('${Words.townAfter} ${(townAt ?? wave + 1) - 1}', [
        '${Words.smithy}: craft items and relics',
        '${Words.tavern}: buy boosts',
        if ((townAt ?? 0) - 1 >= shopFrom) '${Words.shop}: buy and sell',
      ]);
}

/// The name of the relic of save key [key] ([townRelics]): a recipe's name on the Bag's material page.
String townRelicName(String key) => switch (Relic.values.asNameMap()[key]) { final r? => relicNames[r]!, _ => key };

/// What a material is for, under what drops it (the Bag's facing page, its tooltip).
const matUseLine = 'Used at the ${Words.smithy}, in a ${Words.town}. Sold at its ${Words.shop}.';

/// The materials monsters drop (decisions-log 221; [Mat], [TownRules.forgeDrops]).
extension Materials on Game {
  /// [m]'s tooltip: its name, what drops it ([matSource]) and what it is for ([matUseLine]).
  (String, List<String>) matInfo(Mat m) => (m.label, [matSource(m), matUseLine]);

  /// The materials this game can hold (decisions-log 245): every [Mat], the forge's stones ([craftedMats]) too.
  List<Mat> get matsInPlay => Mat.values;

  /// Who drops [m], by the rules ([townRules]): "Common material. Slimes drop it."; a Rare part's "Rare material. High
  /// elite slimes drop it, a slime mini boss 2, a boss 3."; a Trophy's "Trophy. Every mini boss drops one."; a forge
  /// stone's "Made at the Smithy.".
  String matSource(Mat m) {
    final r = townRules, byRank = r.forgeDrops;
    if (r.materials[m]?.grade == MatGrade.crafted) return '${Words.madeAtSmithy}.'; // the forge's stones
    String name(String type) => monsterTypeNames[type] ?? type;
    String plural(String n) => n.endsWith('wolf') ? '${n.substring(0, n.length - 4)}wolves' : '${n}s';
    String list(Iterable<String> words) {
      final w = [...words];
      return w.length < 2 ? w.join() : '${w.take(w.length - 1).join(', ')} and ${w.last}';
    }

    String one(int n) => n == 1 ? 'one' : '$n';
    final says = <String>[];
    for (final grade in const [MatGrade.common, MatGrade.rare]) {
      final from = [for (final type in r.parts.keys) if (r.partOf(type, grade) == m) type];
      final ranks = [
        for (final MapEntry(key: tier, value: ds) in byRank.entries)
          for (final d in ds)
            if (d.part == grade && d.chance > 0 && d.count > 0) (tier, d),
      ];
      if (from.isEmpty || ranks.isEmpty) continue;
      // The lowest rank that drops it names who ("Slimes", "High elite slimes"); a mini boss's and a boss's count follow.
      final low = ranks.first.$1, who = list(from.map((t) => plural(name(t))));
      final rank = tierNames[low]!;
      says.add([
        low == Tier.normal ? '$who drop it' : '${rank[0]}${rank.substring(1).toLowerCase()} ${who.toLowerCase()} drop it',
        for (final (tier, d) in ranks)
          if (tier == Tier.miniBoss) 'a ${list(from.map(name)).toLowerCase()} mini boss ${d.count}' else if (tier == Tier.boss) 'a boss ${d.count}',
      ].join(', '));
    }
    for (final MapEntry(key: tier, value: ds) in byRank.entries) {
      for (final d in ds) {
        if (d.plus[m] case final n?) says.add('Every ${tierNames[tier]!.toLowerCase()} drops ${one(n)}');
      }
    }
    if (r.necromancerPlus[m] case final n?) says.add('The ${name(boss)} drops ${one(n)} as a mini boss or boss');
    final word = switch (r.materials[m]!.grade) {
      MatGrade.common => '${Words.common} material',
      MatGrade.rare => '${Words.rare} material',
      MatGrade.trophy => Words.trophy,
      MatGrade.crafted => Words.madeAtSmithy,
    };
    return '$word. ${says.isEmpty ? 'No monster drops it now' : says.join('. ')}.';
  }

  /// Who [m] comes from, in a word or two (the Smithy's recipe rows, decisions-log 235): its monster's name ("Werewolf"),
  /// the Necromancer's for the Lich Orb, a Trophy's rank ("Mini Boss", "Boss"); '' for one no monster drops by the rules.
  String matFrom(Mat m) {
    final r = townRules;
    for (final MapEntry(key: type, value: (common, rare)) in r.parts.entries) {
      if (common == m || rare == m) return monsterTypeNames[type] ?? type;
    }
    if (r.necromancerPlus.containsKey(m)) return monsterTypeNames[boss] ?? boss;
    for (final MapEntry(key: tier, value: ds) in r.forgeDrops.entries) {
      if (ds.any((d) => d.plus.containsKey(m))) return tierNames[tier]!;
    }
    return '';
  }


  /// What the kill of [u] drops into [Game.waveMaterials] ([TownRules.dropOf] on [Game.matDice], the forge's lists; a
  /// raised monster, [Unit.raisedBy], drops none, like its gold: its caller checks). Each kind lies
  /// where it fell until the wave is won ([Game.matPops], decisions-log 262), and a kind dropped for the first time joins
  /// [Game.matsSeen].
  void _dropMaterials(Unit u) {
    for (final (i, MapEntry(key: m, value: n)) in townRules.dropOf(u.type, u.tier, matDice).entries.indexed) {
      waveMaterials[m] = (waveMaterials[m] ?? 0) + n;
      matPops.add((u.pos + Point(i * 8.0, 0), m, n));
      if (!m.crafted) matsSeen.add(m); // a forge stone never drops, whatever a town.json says
    }
  }

  /// What the forge's Town Shop asks for one [m] after [bought] of it were bought ([TownShop.matPrice]): 2.5x its sell
  /// price ([MatInfo.sell]) rounded up to 5, as shipped (Slime Gel 25, Wolf Claw 65, Soul Orb 1,500). Its shelf holds
  /// only the kinds in [Game.matsSeen] (decisions-log 246).
  int shopMatPrice(Mat m, [int bought = 0]) => townRules.shop.matPrice(townRules.materials[m]?.sell ?? 0, bought);

  /// What the Shop asks for the next [m] after [ahead] more ([Store.buyPrice]): [shopMatPrice] at its [bought] count,
  /// times the market's [Market.matFactor] (decisions-log 326: dearer for each one bought, back over 2-3 Towns), rounded
  /// up to 5.
  int marketMatPrice(Mat m, [int bought = 0, int ahead = 0]) => ((shopMatPrice(m, bought) * matFactor(m, ahead)) / 5 - 1e-9).ceil() * 5;

}

// The Smithy's Craft (decisions-log 233; town-design rev 2 §7; docs/loot-items-relics.md "Town and Smithy: Craft"): in a
// Town, a small relic is made from its recipe ([TownRules.recipes]): its materials, its item (a Strong or a Mighty
// relic's) and its gold, into the Bag. No limit a visit: again and again while the bag can pay (the owner's F3). The
// Smithy's page (its own step) draws [Craft.craftRows] and says [Craft.whyNotCraft]'s reason on its greyed button.

/// Why the Smithy won't craft a relic ([CraftRefusal.why]), in the order [Craft.whyNotCraft] asks: the game is over, not
/// in a Town, no recipe (not a small relic), a material short, an item short, the gold short. Enhance's (decisions-log
/// 255, enhance.dart): not open yet ([closed], before town.json `enhance.from`) and an item already at the most steps
/// ([top]).
enum CraftWhy { over, town, recipe, material, item, gold, closed, top }

/// Why [Craft.whyNotCraft] refused: [why]; for a material or an item short, which one ([short]), how many are held
/// ([have]) and how many the recipe takes ([need]); for [CraftWhy.closed] the wave it opens after, for [CraftWhy.top]
/// the most steps, in [need].
class CraftRefusal {
  const CraftRefusal(this.why, {this.short, this.have = 0, this.need = 0});

  final CraftWhy why;
  final Enum? short;
  final int have, need;

  /// How the Smithy says it: "Only in a Town", "Need 2 more Wolf Claw" (some held), "Need 1 Bow" (none held), "Not
  /// enough gold"; Enhance's "Opens after wave 30" and "Max: +5".
  String get text => switch (why) {
        CraftWhy.over => Words.gameOver,
        CraftWhy.town => Words.onlyInTown,
        CraftWhy.recipe => 'No recipe',
        CraftWhy.gold => Words.notEnoughGold,
        CraftWhy.closed => 'Opens after wave $need',
        CraftWhy.top => 'Max: +$need',
        CraftWhy.material || CraftWhy.item =>
          'Need ${need - have} ${have > 0 ? 'more ' : ''}${switch (short) { final Mat m => m.label, final Item i => itemNames[i]!, _ => '' }}',
      };

  @override
  String toString() => text;
}

/// One line of a recipe on the Smithy's page ([Craft.craftRows]): a material ([Mat]), an item ([Item]) or the gold
/// (null), how many are held and how many it takes.
typedef CraftRow = ({Enum? kind, int have, int need});

/// What the message window says once [relic] is crafted: "Sweep crafted!".
String craftedLine(Relic relic) => '${relicNames[relic]} ${Words.crafted}!';

/// The Smithy's rules (decisions-log 233): the Smithy's page calls them.
extension Craft on Game {
  /// [relic]'s recipe ([TownRules.recipes], by its save key, as the forge changes it: [TownRules.forgeRecipe],
  /// decisions-log 245), or null for a relic the Smithy doesn't make (a Pusaka).
  Recipe? craftRecipe(Relic relic) => relic.pusaka ? null : townRules.forgeRecipe(relic.name);

  /// [relic]'s recipe line by line: each material, then each item, as the file lists them, then the gold: what the bag
  /// holds and what it takes. None for a relic without a recipe.
  List<CraftRow> craftRows(Relic relic) => switch (craftRecipe(relic)) {
        final r? => [
            for (final MapEntry(key: m, value: n) in r.materials.entries) (kind: m, have: materials[m] ?? 0, need: n),
            for (final MapEntry(key: i, value: n) in r.items.entries) (kind: i, have: inventory[i] ?? 0, need: n),
            (kind: null, have: gold, need: r.gold),
          ],
        null => const [],
      };

  /// Why [relic] can't be crafted now, or null: the game over, not in a Town ([Game.inTown]), no recipe, then the first line of [craftRows] short: a material, an item ("Need 1 Bow"), the gold.
  CraftRefusal? whyNotCraft(Relic relic) {
    if (over) return const CraftRefusal(CraftWhy.over);
    if (!inTown) return const CraftRefusal(CraftWhy.town);
    return _rowsShort(craftRows(relic));
  }

  /// The first of a recipe's [rows] short ([whyNotCraft]'s, [whyNotCraftItem]'s order): a material, an item, the gold;
  /// [CraftWhy.recipe] for none; null when every row has enough.
  static CraftRefusal? _rowsShort(List<CraftRow> rows) {
    if (rows.isEmpty) return const CraftRefusal(CraftWhy.recipe);
    for (final (:kind, :have, :need) in rows) {
      if (have >= need) continue;
      return switch (kind) {
        null => const CraftRefusal(CraftWhy.gold),
        Mat() => CraftRefusal(CraftWhy.material, short: kind, have: have, need: need),
        _ => CraftRefusal(CraftWhy.item, short: kind, have: have, need: need),
      };
    }
    return null;
  }

  /// [relic] can be crafted now ([whyNotCraft] has nothing against it).
  bool canCraft(Relic relic) => whyNotCraft(relic) == null;

  /// The first fielded troop type (a living troop of it, in [troopTypes] order) that still needs [item] for its next
  /// Awaken from items ([Game.awakenShort]: its recipe, by grade the next grade set; below [maxAwaken]): the type, how
  /// many more it takes and that Awaken's
  /// level; null: none. Craft reserves no item (decision 11), so the Smithy's item row warns with it ("Knight needs 1
  /// for Awaken 2", decisions-log 235).
  ({String type, int need, int level})? craftItemNeed(Item item) {
    final fielded = {for (final u in troops) if (u.alive) u.type};
    for (final type in troopTypes.keys) {
      if (!fielded.contains(type)) continue;
      if (awakenShort(type)[item] case final short?) return (type: type, need: short, level: itemLevel(type) + 1);
    }
    return null;
  }

  /// Crafts one [relic]: takes its recipe's materials, items and gold, puts it in the Bag ([Game.relicBag]), `Sfx.clear`,
  /// and emits [Crafted] (the battle log's "Crafted Sweep (1,000 gold)", the telemetry's). False (nothing changes but the
  /// error sound) when [whyNotCraft] refuses.
  bool craft(Relic relic) {
    if (whyNotCraft(relic) != null) {
      sfx.add(Sfx.error);
      return false;
    }
    final r = craftRecipe(relic)!;
    _payCraft(r.materials, r.items, r.gold);
    relicBag[relic] = (relicBag[relic] ?? 0) + 1;
    _townCrafts[relic] = (_townCrafts[relic] ?? 0) + 1;
    sfx.add(Sfx.clear);
    _emit(Crafted(wave, t, relic: relic, materials: r.materials, items: r.items, gold: r.gold));
    _wishSweep(); // a free wish met drops off (wishlist.dart)
    return true;
  }

  /// Takes a recipe's [mats] (the last one of a kind leaves no entry), its [items] and its [gold] from the Bag, and counts
  /// the gold in the visit's ([TownLeft.craftSpent]).
  void _payCraft(Map<Mat, int> mats, Map<Item, int> items, int gold) {
    for (final MapEntry(key: m, value: n) in mats.entries) {
      final left = materials[m]! - n;
      if (left > 0) {
        materials[m] = left;
      } else {
        materials.remove(m); // the last one used leaves no entry (the save writes only those held)
      }
    }
    for (final MapEntry(key: i, value: n) in items.entries) {
      inventory[i] = inventory[i]! - n;
    }
    this.gold -= gold;
    _townCraftSpent += gold;
  }

  // The forge's items (decisions-log 249; forge-design §1, §11): the Smithy makes every [Item] from its town.json `items`
  // recipe ([TownRules.items]): grade I, II and III from their own materials and 20 / 60 / 250 gold, the Cap's and the
  // Ring's grades II and III from the grade below too. The Smithy's Items board draws [smithyItems] grade by grade and
  // asks [whyNotCraftItem]; the Army detail asks [canMake].

  /// [item]'s Smithy recipe ([TownRules.items]).
  ItemRecipe? itemRecipe(Item item) => townRules.items[item];

  /// [item]'s recipe line by line, as [craftRows]: each material, then the item it takes (the Cap's and the Ring's grade
  /// below), then the gold; none without a recipe.
  List<CraftRow> itemCraftRows(Item item) => switch (itemRecipe(item)) {
        final r? => [
            for (final MapEntry(key: m, value: n) in r.materials.entries) (kind: m, have: materials[m] ?? 0, need: n),
            for (final MapEntry(key: i, value: n) in r.items.entries) (kind: i, have: inventory[i] ?? 0, need: n),
            (kind: null, have: gold, need: r.gold),
          ],
        null => const [],
      };

  /// Why [item] can't be crafted now, or null, in [whyNotCraft]'s order: the game over, not in a Town, no recipe, a
  /// material short, the grade-below item short ("Need 1 Leather Cap"), the gold.
  CraftRefusal? whyNotCraftItem(Item item) {
    if (over) return const CraftRefusal(CraftWhy.over);
    if (!inTown) return const CraftRefusal(CraftWhy.town);
    return _rowsShort(itemCraftRows(item));
  }

  /// [item] can be crafted now ([whyNotCraftItem] has nothing against it).
  bool canCraftItem(Item item) => whyNotCraftItem(item) == null;

  /// How many [item]s the Bag's materials, items and gold pay for, one after another, wherever the game is (the Army
  /// detail's "Smithy: can make 3" between Towns); 0 without a recipe.
  int canMake(Item item) => switch (itemCraftRows(item)) {
        final rows when rows.isNotEmpty => rows.map((r) => r.need == 0 ? 1 << 30 : r.have ~/ r.need).reduce(min),
        _ => 0,
      };

  /// Why the Bag can't pay for one [item] wherever the game is ([whyNotCraftItem] without the Town and the game's end): no
  /// recipe, its first material, item or the gold short; null when it can ([canMake] > 0). The Army detail's "Smithy:
  /// needs Wolf Claw".
  CraftRefusal? whyNotMake(Item item) => _rowsShort(itemCraftRows(item));

  /// The Smithy's items of [grade] (1 to 3) in [Item] order: every kind's.
  List<Item> smithyItems(int grade) => [for (final i in Item.values) if (i.grade == grade) i];

  /// Those of [smithyItems] that can be crafted now ([canCraftItem]).
  List<Item> craftableItems(int grade) => [for (final i in smithyItems(grade)) if (canCraftItem(i)) i];

  /// Crafts one [item]: takes its recipe's materials, item and gold ([_payCraft]), puts it in the Bag ([Game.inventory]),
  /// `Sfx.clear`, and emits [ItemCrafted] (the battle log's "Crafted Steel Sword (60 gold)", the telemetry's). False
  /// (nothing changes but the error sound) when [whyNotCraftItem] refuses.
  bool craftItem(Item item) {
    if (whyNotCraftItem(item) != null) {
      sfx.add(Sfx.error);
      return false;
    }
    final r = itemRecipe(item)!;
    _payCraft(r.materials, r.items, r.gold);
    inventory[item] = (inventory[item] ?? 0) + 1;
    sfx.add(Sfx.clear);
    _emit(ItemCrafted(wave, t, item: item, materials: r.materials, items: r.items, gold: r.gold));
    _wishSweep(); // a free wish met drops off (wishlist.dart)
    return true;
  }
}
