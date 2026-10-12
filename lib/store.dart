part of 'game.dart';

// The store, the Town's Shop (#63, the "Toko" until decisions-log 230; docs/loot-items-relics.md, "The store"): while its
// shelf is open ([shelfOpen]: not beside the boss's chest, draft.dart) it sells the five epik Pusaka ([Relic.store];
// pusaka.dart), one of each, a copy of one owned refused; what is in the bag (and a Pusaka in the Gudang) sells back for
// a small share. Every choice the owner may still change is one constant or switch below. It deals only in a Town
// ([StoreRefusal.town], decisions-log 230; the field's Toko page went in decisions-log 296, its prices and rules in 321):
// the Town's Shop page, on the Bag's own code (lib/bag.dart), buys and sells there, the Towns' materials too (each at its
// own price, [TownRules.materials]). Its prices are town.json's ([TownRules], decisions-log 233); an item and a small
// relic sell back at the market's price (decisions-log 326, market.dart: their cost times the Town's demand). The forge's
// Shop (decisions-log 248): its shelf holds only the materials that have dropped ([Game.matsSeen]), each at
// [Materials.shopMatPrice], and no item or small relic (their tier's and the [TownShop]'s buy prices stay in town.json,
// unused); it still buys them all.

/// The store opened once wave [storeFrom] was won (the owner: "hanya dibuka ketika player sudah melewati wave 15"); a
/// Town's Shop opens at the wave town.json's `shop.from` names ([Store.shopFrom]: 1, every Town's Shop open,
/// decisions-log 253; 237 read it, at 15), while Awaken 4-5, Forge and Recall keep this wave ([Store.armyBuysOpen]).
const storeFrom = 15;

/// Whether the store deals during a wave too, or only between waves (false, the owner's pick: mid-wave its buttons
/// grey out, "Hanya di antara gelombang"). Either way the book's Shop page holds the auto start while it is open.
const storeMidWave = false;

/// What each store Pusaka costs (twice the design's); one bought again after selling it costs ×[artefactRise] the one
/// before.
const artefactPrice = {Relic.grail: 24000, Relic.dragonHeart: 30000, Relic.voidEye: 36000, Relic.godThunder: 40000, Relic.dawnStar: 40000};
const artefactRise = 1.5;

/// What the store pays for one from the bag: this share of its kind's base price (the owner: half), never the
/// risen one, so buying back never pays and selling never lowers a price. Only the bag sells: an item given to
/// a troop type is part of it (its awakening, caps and price), and a relic held by a troop stays on it.
const sellShare = 0.5;

/// Everything the store sold, in the book's order: the items monsters dropped ([droppedItems]: not the forge's,
/// decisions-log 245), the dropped relics ([droppedRelics]: not the Smithy's, relics.dart), the artefacts ([Art.store],
/// in the game: [Art.live]; not the chest's Langka). A Town's Shop deals in the artefacts and materials only.
final storeGoods = <Enum>[...droppedItems, ...droppedRelics, for (final r in Relic.values) if (r.store && pusakaCatalog[r]!.live) r];

/// Why the store won't buy or sell now ([Store.whyNotBuy], [Store.whyNotSell]): besides the store's own, a Pusaka
/// already owned isn't sold again ([owned]), one bound to a type isn't bought back ([bound]), with the shelf closed
/// a Pusaka comes only from the boss's chest ([shelf], [artefactShelf]), it deals only in a Town ([town], decisions-log
/// 230), and what isn't on its shelf isn't sold ([notSold]: a material not dropped yet, an item and a small relic,
/// decisions-log 248).
enum StoreRefusal { locked, midWave, over, gold, none, owned, bound, shelf, town, notSold }

/// The "VICTORY!" popup's line at the win that opens the Shop (decisions-log 237): it deals only in a
/// Town. None while town.json's `shop.from` is 1 (decisions-log 253): no Town comes before wave 1 is won, so the Shop
/// never was shut.
const shopInTowns = 'Towns have a ${Words.shop} now!';

/// The refusals as the store says them.
const storeRefusalNames = {
  StoreRefusal.locked: 'Opens after wave $storeFrom',
  StoreRefusal.midWave: Words.onlyBetweenWaves,
  StoreRefusal.over: Words.gameOver,
  StoreRefusal.gold: Words.notEnoughGold,
  StoreRefusal.none: 'None in the ${Words.bag}',
  StoreRefusal.owned: 'Owned',
  StoreRefusal.bound: 'Equipped: send it to ${Words.vault} first',
  StoreRefusal.shelf: '${Words.bossChest} only',
  StoreRefusal.town: Words.onlyInTown,
  StoreRefusal.notSold: 'Not for sale',
};

/// The store's rules.
extension Store on Game {
  /// The wave whose win opens the store: town.json's `shop.from` ([TownShop.from]: 1, so a Town's Shop is open in every
  /// Town, decisions-log 253). It opens the Shop only; Awaken 4-5, Forge and Recall on the Army page keep [storeFrom]
  /// ([armyBuysOpen]).
  int get shopFrom => townRules.shop.from;

  /// Wave [shopFrom] has been won ([Game.wonWave]). Derived from the waves, so not saved.
  bool get storeOpen => wonWave(shopFrom);

  /// This wave's win opened the Shop: the "VICTORY!" popup says so ([shopInTowns]; a game without the Towns said "The Shop is open!" until decisions-log 296). Never while
  /// [shopFrom] is 1, where no Town comes before it and so the Shop was never shut (decisions-log 253).
  bool get shopJustOpened => wave == shopFrom && shopFrom > 1;

  /// Wave [storeFrom] has been won: Awaken 4-5, Forge and Recall can be bought (in the Army page's detail, between any
  /// waves). A Town's Shop opens at [shopFrom] instead (decisions-log 253: the owner asked the Shop open in every Town,
  /// nothing about these). Derived from the waves ([Game.wonWave]: a wipe's trip back to a Town locks nothing again), so
  /// not saved.
  bool get armyBuysOpen => wonWave(storeFrom);

  /// [why] in the store's words ([storeRefusalNames]), the locked one with this game's [shopFrom].
  String storeWhy(StoreRefusal why) => why == StoreRefusal.locked ? 'Opens after wave $shopFrom' : storeRefusalNames[why]!;

  /// Whether the shelf has no [kind] to sell ([StoreRefusal.notSold]). The forge's Town Shop (decisions-log 248; the
  /// owner, 2026-10-04: "shop di town hanya menjual item yang pernah di drop dari wave sebelumnya dengan harga x2.5 harga
  /// jual item ke toko"): the shelf holds the materials that have dropped ([Game.matsSeen]) at [Materials.shopMatPrice]
  /// and no item or small relic (they never drop); the Artifact shelf is unchanged, and the Shop still buys everything.
  bool _notSold(Enum kind) => switch (kind) {
        final Mat m => !matsSeen.contains(m),
        Item() || Relic(pusaka: false) => true,
        _ => false,
      };

  /// The artefact shelf sells the epik Pusaka: always with [artefactShelf], else only without the boss's chest
  /// ([Game.offers]: off in a plain Game(), on the board), where the Pusaka come from the chest alone (decisions-log 152).
  bool get shelfOpen => artefactShelf || !offers;

  /// Why the store can't deal now at all, or null when it can.
  StoreRefusal? get _closed => !storeOpen ? StoreRefusal.locked : _busy;

  /// Why Awaken 4-5, Forge or Recall can't be bought now at all ([armyBuysOpen], then as the store), or null when they
  /// can. Its locked refusal says [storeFrom] ([storeRefusalNames]).
  StoreRefusal? get _armyClosed => !armyBuysOpen ? StoreRefusal.locked : _busy;

  /// The game over, or (unless [storeMidWave]) a wave on: why nothing is bought now, open or not.
  StoreRefusal? get _busy => over
      ? StoreRefusal.over
      : !storeMidWave && waveActive
          ? StoreRefusal.midWave
          : null;

  /// Why the store won't deal here at all: only in a Town (decisions-log 230), first, so a stale tap or a test can't buy
  /// or sell on the field. Not for Awaken, Forge or Recall, which the Army page's detail buys between any waves
  /// ([_armyClosed] alone).
  StoreRefusal? get _away => !inTown ? StoreRefusal.town : null;

  /// [kind]'s price before any was bought; a small relic's is its tier's ([TierPrices.shop]: Basic
  /// 12,000, Strong 20,000, Mighty 32,000) and an item's the [TownShop]'s; a material's the forge's Shop's
  /// ([Materials.shopMatPrice]).
  int basePrice(Enum kind) => switch (kind) {
        final Mat m => shopMatPrice(m),
        Relic(store: true) => artefactPrice[kind]!,
        Relic(rarity: Rarity.legenda) => legendaPrice, // the chest's Legenda, never sold here (pusaka.dart)
        Relic(rarity: Rarity.epik, pusaka: true) => epikPrice, // the chest's new Epik (owner: its own price), sold to it, never bought (draft.dart)
        Relic(pusaka: true) => langkaPrice, // the chest's Langka (owner 3c: sold to it, never bought), never sold here (draft.dart)
        final Relic r => _tierPrices(r).shop,
        _ => townRules.shop.itemPrice, // an item
      };

  /// What the next [kind] costs: its base price, risen by every one of it the store sold this game (and by
  /// [ahead] more: what the one after would cost). A small relic rises its tier's [TierPrices.shopRise]
  /// of its base a buy (Basic 12,000, 14,400, 16,800, …) and an item the [TownShop]'s rise; a material the forge's Shop's
  /// ([Materials.shopMatPrice]: its [TownShop.matRise] a buy, 0 as shipped).
  int buyPrice(Enum kind, [int ahead = 0]) {
    final n = (storeBought[kind] ?? 0) + ahead;
    return switch (kind) {
      final Mat m => marketMatPrice(m, n, ahead), // dearer for each bought, by the market (market.dart)
      Relic(store: true) => (artefactPrice[kind]! * pow(artefactRise, n)).round(),
      final Relic r when !r.pusaka => _tierPrices(r).priceAfter(n),
      Relic() => basePrice(kind), // the chest's Pusaka: never sold here ([StoreRefusal.shelf])
      _ => townRules.shop.itemPrice + townRules.shop.itemRise * n, // an item
    };
  }

  /// What one [kind] from the bag sells for: [sellShare] of its base price; a material ([Mat]) its own price
  /// ([MatInfo.sell], town.json `materials`). An item and a small relic, the Smithy's goods, sell at the market's price
  /// for the next piece ([Market.marketPrice], decisions-log 326: 1.3x-4x their cost by grade and the Town's demand,
  /// lower the more of that exact product was sold); until then a small relic sold for half its craft gold and every
  /// item for a flat 1,000 (the [TownShop]'s share of its price).
  int sellPrice(Enum kind) => switch (kind) {
        Mat() => townRules.materials[kind]?.sell ?? 0,
        Item() || Relic(pusaka: false) => marketPrice(kind),
        _ => (basePrice(kind) * sellShare).round(),
      };

  /// Small relic [relic]'s tier prices ([Relics.relicTier], town.json `tiers`).
  TierPrices _tierPrices(Relic relic) => townRules.tiers[relicTier(relic)] ?? _townTiers[relicTier(relic)]!;

  /// How many [kind] are in the bag; a Pusaka: 1 while it waits in the Gudang (an oath never does: it never sells); a
  /// material ([Mat]): how many are held.
  int inBag(Enum kind) => switch (kind) {
        Relic(oath: true) => 0,
        Relic(pusaka: true) => pusaka[kind]?.type == null && pusaka.containsKey(kind) ? 1 : 0,
        Relic() => relicBag[kind] ?? 0,
        Mat() => materials[kind] ?? 0,
        _ => inventory[kind as Item] ?? 0,
      };

  /// Puts [n] [kind] in the bag (takes them out, when negative); a Pusaka bought goes to the Gudang at ★1, and one sold
  /// leaves with its stars; a material's last one sold leaves no entry.
  void _toBag(Enum kind, int n) {
    if (kind is Mat) {
      final left = inBag(kind) + n;
      if (left > 0) {
        materials[kind] = left;
      } else {
        materials.remove(kind);
      }
    } else if (kind is Relic && kind.pusaka) {
      if (n > 0) {
        pusaka[kind] ??= OwnedPusaka();
      } else {
        pusaka.remove(kind);
      }
    } else if (kind is Relic) {
      relicBag[kind] = inBag(kind) + n;
    } else {
      inventory[kind as Item] = inBag(kind) + n;
    }
  }

  /// Why one [kind] can't be bought now, or null when it can: outside a Town ([_away]), nothing off the shelf
  /// ([_notSold]: a material not dropped yet, an item, a small relic), a Pusaka only
  /// while the shelf is open ([shelfOpen]; a Langka never), and one already owned isn't sold again.
  StoreRefusal? whyNotBuy(Enum kind) =>
      _away ??
      _closed ??
      (_notSold(kind)
          ? StoreRefusal.notSold
          : kind is Relic && kind.pusaka && (!kind.store || !shelfOpen)
              ? StoreRefusal.shelf
              : kind is Relic && pusaka.containsKey(kind)
                  ? StoreRefusal.owned
                  : (gold < buyPrice(kind) ? StoreRefusal.gold : null));

  /// Why one [kind] can't be sold now, or null when it can: outside a Town ([_away]); a Pusaka sells
  /// only from the Gudang.
  StoreRefusal? whyNotSell(Enum kind) =>
      _away ?? _closed ?? (kind is Relic && pusaka[kind]?.type != null ? StoreRefusal.bound : (inBag(kind) == 0 ? StoreRefusal.none : null));

  /// Buys one [kind] into the bag at [buyPrice], and the next costs more. False (and nothing changes) when
  /// [whyNotBuy] refuses. A material bought never joins [Game.matsSeen] (only a drop does).
  bool buy(Enum kind) {
    if (whyNotBuy(kind) != null) {
      sfx.add(Sfx.error);
      return false;
    }
    final price = buyPrice(kind);
    gold -= price;
    storeBought[kind] = (storeBought[kind] ?? 0) + 1;
    if (kind is Mat) _marketSold(kind, 0, 1); // the next one dearer (market.dart)
    _toBag(kind, 1);
    _emit(StoreBought(wave, t, loot: kind, cost: price));
    sfx.add(Sfx.kill); // the coin
    return true;
  }

  /// Sells [n] [kind] from the bag (all of them when there are fewer) for [sellPrice] each. How many went; 0
  /// (and nothing changes) when [whyNotSell] refuses.
  int sell(Enum kind, [int n = 1]) {
    if (whyNotSell(kind) != null) {
      sfx.add(Sfx.error);
      return 0;
    }
    final sold = min(n, inBag(kind)), market = marketed(kind);
    // The Smithy's goods sell each piece at its own step of the market (market.dart), the rest at one price.
    final gain = market ? marketSum(kind, 0, sold) : sold * sellPrice(kind);
    final margin = market ? marginOf(kind) : null, pressure = market ? pressureOf(kind) : null;
    _toBag(kind, -sold);
    gold += gain;
    if (market) _marketSold(kind, 0, sold);
    _emit(StoreSold(wave, t, loot: kind, n: sold, gain: gain, margin: margin, pressure: pressure));
    sfx.add(Sfx.kill);
    return sold;
  }
}
