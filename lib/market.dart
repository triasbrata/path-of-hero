part of 'game.dart';

// The Towns' identities and the market for forged goods (decisions-log 326; docs/loot-items-relics.md "The market").
// The owner, 2026-10-12: a forged item (and its "+") sells for 1.3x-4x its cost of goods, by its grade and the Town's
// demand; every Town has its own identity and look (the first three value beginner items, the late ones high-class
// goods); selling one exact product again and again pulls its price down to the floor, 1.3x, and it comes back over 2-3
// Towns. His answers (go 326): the cost counts the parts at what the Shop pays for them ([MarketRules], (R)), the early
// Towns keep valuing beginner items, the forge's gold earns only the floor and the Shop's materials get dearer as they
// are bought (the guard against buying parts only to forge and sell), six identities, two a season.
//
// A Town's identity follows its number in the run ([Game.townCount]; no dice, so a seeded run plays as before). The
// market is bookkeeping only: [Game.market] keeps each product's pressure (a piece sold, a material bought), and every
// new Town takes [MarketRules.recover] off each ([Towns.enterTown]). The prices are [Store.sellPrice]'s and
// [Enhance.sellPriceAt]'s for an item and a small relic, and [Store.buyPrice]'s for a material.

/// A Town's season: its backdrop, castle and ground (town_scene.dart, [townSeasonArt]).
enum TownSeason { summer, autumn, winter }

/// One of the Towns' identities (decisions-log 326): its save key, its name and what it is (the arrival ribbon's second
/// line), its season (its look) and the item kinds it pays well for ([MarketRules.want]).
class TownIdentity {
  const TownIdentity(this.key, this.name, this.line, this.season, this.wants);

  final String key, name, line;
  final TownSeason season;
  final List<ItemSlot> wants;

  /// "Pays well for Boots, Potion, Gloves and Prayer Beads": its [wants] by their first grade's names.
  String get wantsLine {
    final names = [for (final s in wants) itemNames[Item.values.firstWhere((i) => i.slot == s && i.grade == 1)]!];
    return '${Words.paysWellFor} ${names.take(names.length - 1).join(', ')} and ${names.last}';
  }
}

/// The six identities in the road's order, two a tier ([identityFrom]): the first three Towns' (summer), the middle
/// ones' (autumn), the late ones' (winter). The two of a tier take turns, so neighbours differ.
const townIdentities = [
  TownIdentity('millbrook', 'Millbrook', 'Farming village', TownSeason.summer,
      [ItemSlot.boots, ItemSlot.potion, ItemSlot.gloves, ItemSlot.beads]),
  TownIdentity('willowmere', 'Willowmere', 'Riverside village', TownSeason.summer,
      [ItemSlot.bow, ItemSlot.spear, ItemSlot.torch, ItemSlot.shield]),
  TownIdentity('ironvale', 'Ironvale', 'Mining town', TownSeason.autumn,
      [ItemSlot.shield, ItemSlot.helm, ItemSlot.gloves, ItemSlot.amulet]),
  TownIdentity('ambergate', 'Ambergate', 'Harvest market', TownSeason.autumn,
      [ItemSlot.potion, ItemSlot.staff, ItemSlot.ring, ItemSlot.prism]),
  TownIdentity('frostgate', 'Frostgate', 'Royal capital', TownSeason.winter,
      [ItemSlot.sword, ItemSlot.helm, ItemSlot.ring, ItemSlot.amulet]),
  TownIdentity('highspire', 'Highspire', 'Temple city', TownSeason.winter,
      [ItemSlot.staff, ItemSlot.beads, ItemSlot.torch, ItemSlot.prism]),
];

/// The Town number each tier starts at: Towns 1-3 the first two identities, 4-6 the next two, 7 on the last two.
const identityFrom = [1, 4, 7];

/// The identity of the [n]th Town of a run (1 the first; 0 or less reads as 1).
TownIdentity identityOf(int n) {
  final t = identityFrom.lastIndexWhere((from) => max(1, n) >= from);
  return townIdentities[2 * t + (max(1, n) - identityFrom[t]) % 2];
}

/// The identity of save key [key] (a [TownEntered] event's), or null.
TownIdentity? identityKeyed(String key) => townIdentities.where((t) => t.key == key).firstOrNull;

/// How many waves apart Towns come on average (the schedule's rolls, decisions-log 216): an old save's Town count is
/// guessed from its last Town's slot with it ([Towns._loadTown]).
const townGapGuess = 7.5;

/// The market's words on the Sell page ([Market.marketWord]): a kind the Town wants, still fresh; a product sold so much
/// its price is past half way to the floor.
enum MarketWord { hot, flooded }

/// The market's numbers (town.json `market`, decisions-log 326).
class MarketRules {
  const MarketRules({
    this.floor = 1.3,
    this.top = 4.0,
    this.want = 1.3,
    this.most = 24,
    this.curve = 1.5,
    this.recover = 10,
    this.matRise = 0.10,
    this.trophyRise = 0.25,
    this.towns = _marketTowns,
  });

  /// The margin no sale goes under (the owner: never below 30% profit) and the most a fresh one reaches.
  final double floor, top;

  /// A kind the Town wants ([TownIdentity.wants]) has its grade's margin times this.
  final double want;

  /// The pressure that takes a product to the [floor] (the owner: looser than 15 sales); it never goes higher.
  final int most;

  /// The curve's power: margin = floor + (fresh - floor) x (1 - (pressure / most)^curve), gentle at first.
  final double curve;

  /// What each new Town takes off every product's pressure (24 -> 14 -> 4 -> 0: fresh again in the third Town).
  final int recover;

  /// A material bought costs this share of its price more for each one bought before it (its pressure, up to [most]);
  /// a Trophy (Evil Eye, Soul Orb, Lich Orb) [trophyRise].
  final double matRise, trophyRise;

  /// The fresh margin by Town number (row 1 the first Town; the last row for every Town past it): grade I, II, III and
  /// an enhanced item (+1 to +5). A small relic reads its tier as the grade (Basic I, Strong II, Mighty III).
  final List<List<double>> towns;

  /// The fresh margins of the [n]th Town: [towns]' row n (its last for any Town past them).
  List<double> rowOf(int n) => towns[(max(1, n) - 1).clamp(0, towns.length - 1)];

  /// [j]'s numbers, each only of the right kind and in its range (else its default); a `towns` that isn't rows of four
  /// margins keeps the default, noted in [skipped].
  factory MarketRules.fromJson(Map<String, dynamic> j, List<String> skipped) {
    const d = MarketRules();
    double at(String k, double def, double lo) => switch (j[k]) { final num v when v >= lo => v.toDouble(), _ => def };
    int whole(String k, int def) => switch (j[k]) { final int v when v >= 1 => v, _ => def };
    final floor = at('floor', d.floor, 1), top = at('top', d.top, 1);
    final towns = switch (j['towns']) {
      final List rows when rows.isNotEmpty && rows.every((r) => r is List && r.length == 4 && r.every((v) => v is num && v > 0)) => [
          for (final r in rows) [for (final v in r as List) (v as num).toDouble()],
        ],
      null => d.towns,
      _ => () {
          skipped.add('market.towns: not rows of four margins');
          return d.towns;
        }(),
    };
    return MarketRules(
      floor: floor,
      top: max(floor, top),
      want: at('want', d.want, 0),
      most: whole('most', d.most),
      curve: at('curve', d.curve, 0.01),
      recover: whole('recover', d.recover),
      matRise: at('matRise', d.matRise, 0),
      trophyRise: at('trophyRise', d.trophyRise, 0),
      towns: towns,
    );
  }

  Map<String, dynamic> toJson() => {
        'floor': floor,
        'top': top,
        'want': want,
        'most': most,
        'curve': curve,
        'recover': recover,
        'matRise': matRise,
        'trophyRise': trophyRise,
        'towns': towns,
      };
}

/// The shipped demand table (the design's, with qa-balance's trim of Town 4 and 5's grade II, 3.0 -> 2.4).
const _marketTowns = [
  [3.0, 2.2, 1.6, 1.4],
  [3.0, 2.2, 1.6, 1.4],
  [3.0, 2.2, 1.6, 1.4],
  [2.4, 2.4, 2.2, 1.8],
  [2.0, 2.4, 2.4, 1.9],
  [1.6, 2.8, 2.6, 2.0],
  [1.3, 2.0, 3.0, 2.2],
];

/// The market on [Game] (its fields: [Game.market], [Game.townCount]).
extension Market on Game {
  MarketRules get _m => townRules.market;

  /// The Town whose market the prices read: the one the player is in, else the next one.
  int get marketTown => inTown ? max(1, townCount) : townCount + 1;

  /// [marketTown]'s identity.
  TownIdentity get townIdentity => identityOf(marketTown);

  /// The identity of the Town last gone into (the Town scene's, as it fades out too; the first's before any).
  TownIdentity get sceneIdentity => identityOf(townCount);

  /// Whether [kind] is one of the market's products: an item or a small relic (the Smithy's goods). A material and an
  /// Artifact keep their own prices.
  bool marketed(Enum kind) => kind is Item || (kind is Relic && !kind.pusaka);

  /// [kind]'s key in [Game.market]: an item's name ("royalSword", "royalSword+2" at +2), a small relic's "relic:fang", a
  /// material's "mat:boneShard" (what was bought of it).
  String marketKey(Enum kind, [int plus = 0]) => switch (kind) {
        Item(:final name) => plus > 0 ? '$name+$plus' : name,
        Relic(:final name) => 'relic:$name',
        _ => 'mat:${kind.name}',
      };

  /// [kind]'s pressure now (0 to [MarketRules.most]).
  int pressureOf(Enum kind, [int plus = 0]) => market[marketKey(kind, plus)] ?? 0;

  /// What a part is worth to the player: what the Shop pays for it (the owner's (R)).
  int _partWorth(Mat m) => townRules.materials[m]?.sell ?? 0;

  /// [kind]'s cost of goods (at +[plus]), split into its parts' worth ([_partWorth]: the recipe's materials, an item it
  /// takes at its own cost, a stone's materials) and its gold (the forge's, an Enhance step's, a stone's). Its HPP is
  /// the sum ([hppOf]).
  ({int parts, int gold}) costOf(Enum kind, [int plus = 0]) {
    var parts = 0, gold = 0;
    void addMats(Map<Mat, int> mats, int n) {
      for (final MapEntry(key: m, value: c) in mats.entries) {
        if (stoneRecipe(m) case final s?) {
          addMats(s.materials, c * n);
          gold += s.gold * c * n;
        } else {
          parts += _partWorth(m) * c * n;
        }
      }
    }

    void addItem(Item item, int n) {
      final r = itemRecipe(item);
      if (r == null) return;
      addMats(r.materials, n);
      gold += r.gold * n;
      for (final MapEntry(key: sub, value: c) in r.items.entries) {
        addItem(sub, c * n);
      }
    }

    switch (kind) {
      case final Item item:
        addItem(item, 1);
        for (var p = 0; p < plus; p++) {
          if (enhanceCost(p) case (:final stone, gold: final step)) {
            gold += step;
            addMats({stone: 1}, 1);
          }
        }
      case final Relic relic when !relic.pusaka:
        if (craftRecipe(relic) case final r?) {
          addMats(r.materials, 1);
          gold += r.gold;
          for (final MapEntry(key: sub, value: c) in r.items.entries) {
            addItem(sub, c);
          }
        }
      default:
    }
    return (parts: parts, gold: gold);
  }

  /// [kind]'s HPP at +[plus]: its parts' worth and its gold ([costOf]).
  int hppOf(Enum kind, [int plus = 0]) {
    final (:parts, :gold) = costOf(kind, plus);
    return parts + gold;
  }

  /// [kind]'s fresh margin at +[plus] in the [town]th Town ([marketTown] by default): its grade's (an enhanced item's
  /// column, a small relic's tier) in [MarketRules.towns], times [MarketRules.want] for a kind the Town wants, kept in
  /// [MarketRules.floor] .. [MarketRules.top]. 0 for what the market doesn't deal in.
  double freshMargin(Enum kind, [int plus = 0, int? town]) {
    final n = town ?? marketTown, row = _m.rowOf(n);
    final m = switch (kind) {
      final Item i when plus > 0 => row[3] * (identityOf(n).wants.contains(i.slot) ? _m.want : 1),
      final Item i => row[i.grade - 1] * (identityOf(n).wants.contains(i.slot) ? _m.want : 1),
      final Relic r when !r.pusaka => row[relicTier(r).index],
      _ => 0.0,
    };
    return m <= 0 ? 0 : m.clamp(_m.floor, _m.top).toDouble();
  }

  /// [kind]'s margin at +[plus] for the piece after [ahead] more of it are sold: its [freshMargin] pulled toward the
  /// floor by its pressure ([pressureOf] + [ahead], at most [MarketRules.most]).
  double marginOf(Enum kind, [int plus = 0, int ahead = 0]) {
    final fresh = freshMargin(kind, plus), s = min(_m.most, pressureOf(kind, plus) + ahead);
    return _m.floor + (fresh - _m.floor) * (1 - pow(s / _m.most, _m.curve));
  }

  /// What the Shop pays for one [kind] at +[plus] after [ahead] more are sold (decisions-log 326): its gold at the floor
  /// and its parts at its margin ([marginOf]), so never under [MarketRules.floor] x its HPP. Any margin over 1 on the
  /// gold would print gold (buy the parts, forge, sell); the parts are what the Town's demand pays for.
  int marketPrice(Enum kind, [int plus = 0, int ahead = 0]) {
    final (:parts, :gold) = costOf(kind, plus);
    return (gold * _m.floor + parts * marginOf(kind, plus, ahead)).round();
  }

  /// What [n] of [kind] at +[plus] bring together, each at its own step ([marketPrice]).
  int marketSum(Enum kind, int plus, int n) => [for (var k = 0; k < n; k++) marketPrice(kind, plus, k)].fold(0, (a, b) => a + b);

  /// The Sell page's word for [kind] at +[plus] here ([MarketWord]): flooded once its margin is more than half way from
  /// fresh to the floor; hot for a kind the Town wants ([TownIdentity.wants]) whose fresh margin is 2 or more, while not
  /// flooded; else none.
  MarketWord? marketWord(Enum kind, [int plus = 0]) {
    if (!marketed(kind)) return null;
    final fresh = freshMargin(kind, plus), now = marginOf(kind, plus);
    if (fresh > _m.floor + 1e-9 && (fresh - now) / (fresh - _m.floor) > 0.5) return MarketWord.flooded;
    if (kind case final Item i when townIdentity.wants.contains(i.slot) && fresh >= 2.0) return MarketWord.hot;
    return null;
  }

  /// [n] pieces of [kind] at +[plus] sold: its pressure rises by [n], at most [MarketRules.most].
  void _marketSold(Enum kind, int plus, int n) {
    if (n <= 0) return;
    final k = marketKey(kind, plus);
    market[k] = min(_m.most, (market[k] ?? 0) + n);
  }

  /// What a material bought next costs, times its price before the market: 1 + its rise ([MarketRules.matRise], a Trophy
  /// [MarketRules.trophyRise]) for each one bought before it (its pressure + [ahead], at most [MarketRules.most]).
  double matFactor(Mat m, [int ahead = 0]) =>
      1 + (townRules.materials[m]?.grade == MatGrade.trophy ? _m.trophyRise : _m.matRise) * min(_m.most, pressureOf(m) + ahead);

  /// A new Town ([Towns.enterTown]): its number goes up, and every product's pressure comes down by
  /// [MarketRules.recover] (a key at 0 leaves).
  void _marketNewTown() {
    townCount++;
    for (final k in [...market.keys]) {
      final left = market[k]! - _m.recover;
      if (left > 0) {
        market[k] = left;
      } else {
        market.remove(k);
      }
    }
  }

  /// The save's `market` (only when any pressure is left).
  Map<String, Object> get _marketJson => {if (market.isNotEmpty) 'market': {...market}};

  /// [j]'s `market`: each key with a whole pressure, kept in 1 .. [MarketRules.most]; a key of a product this build
  /// doesn't know (an item, a relic or a material's name) is skipped. A save without it starts fresh.
  void _loadMarket(Map<String, dynamic> j) {
    final items = Item.values.asNameMap(), relics = Relic.values.asNameMap(), mats = Mat.values.asNameMap();
    bool known(String k) => switch (k.split(':')) {
          ['relic', final r] => relics[r] != null,
          ['mat', final m] => mats[m] != null,
          [final i] => switch (i.split('+')) {
              [final name] => items[name] != null,
              [final name, final p] => items[name] != null && (int.tryParse(p) ?? 0) >= 1,
              _ => false,
            },
          _ => false,
        };
    for (final e in ((j['market'] as Map?) ?? {}).entries) {
      if ((e.key, e.value) case (final String k, final int v) when v > 0 && known(k)) market[k] = min(_m.most, v);
    }
  }
}
