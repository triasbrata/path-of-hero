part of 'game.dart';

// The Tavern's boosts (decisions-log 266; docs/loot-items-relics.md "Towns: the Tavern"). The owner, 2026-10-07: "terus
// di tavern ini aku mau ada feature user bisa beli temporary boost misal 500 gold untuk party yang bisa meningkatkan 2
// wave atk+ def untuk semua jenis troops, nah ini di buat jadi gacha juga opsi yang di tawarkan di tavern"; and on
// 2026-10-08 (the design's questions): "500 adalah contoh saja, kalau bisa jangan terlalu mahal untuk di kota kota awal",
// "Sebanyak gold cukup" (no buy limit), "semua buff tavern adalah temporary buff untuk 2 wave setelahnya" (every boost
// lasts the next two waves), DEF = damage taken, and the game's existing icons.
//
// In every Town the Tavern offers [TavernRules.offers] boosts rolled on [Game.tavernDice] at [Towns.enterTown], each of a
// rarity ([Rarity]: Common, Rare, Epic, Legendary); every offer can be bought once while the gold lasts, and a reroll
// rolls the unbought ones again for a price that doubles within the visit. A boost runs from its buy for the next
// [TavernRules.waves] waves fought, counted down at each wave's end ([Tavern._boostWaveEnd]), and works as one step at the
// end of [Game.statsOf] ([Tavern._boostStats]), on top of the items, awakening, Tempa, the heavies' buff, the Pusaka and
// the oath; two kinds hook the kill gold ([Tavern._boostGold]) and the leak line ([Tavern._boostLeak]) instead. Every
// number is town.json's `tavern` block ([TavernRules]). Every Town has its Tavern (decisions-log 296: the Tavern-off
// build is gone); a game with the Towns off ([Game.towns], tests only) rolls, sells and saves none of it.

/// A Tavern boost's kind; its name is its save key and its town.json key (`tavern.boosts.<name>`).
enum Boost { feast, ale, stew, broth, tea, rations, toast, mage, plate, watch, banquet }

/// The boosts' names as the player reads them.
const boostNames = {
  Boost.feast: 'Feast', // the owner's: damage and less damage taken, for every troop
  Boost.ale: 'Strong Ale',
  Boost.stew: 'Hearty Stew',
  Boost.broth: 'Iron Broth',
  Boost.tea: 'Spiced Tea',
  Boost.rations: 'Travel Rations', // a little of everything
  Boost.toast: 'Lucky Toast',
  Boost.mage: "Mage's Brew",
  Boost.plate: "Champion's Plate", // one troop type, much stronger
  Boost.watch: "Watchman's Brew",
  Boost.banquet: "King's Banquet",
};

/// The rarities by their town.json and telemetry key (the [Rarity] enum's names are the old Indonesian ones).
const rarityKeys = {Rarity.biasa: 'common', Rarity.langka: 'rare', Rarity.epik: 'epic', Rarity.legenda: 'legendary'};

/// One boost kind's rule (town.json `tavern.boosts.<kind>`): its [rarity], and what it multiplies while it runs: a
/// troop's damage (a healer's heal), the damage it takes, its max HP, its attack speed (the pause between attacks ÷
/// [rate]), its MP regen, the kill gold; [leaks]: the monsters a wave that cross the back line without costing a life.
/// [oneType]: it works on one troop type, rolled with the offer (town.json `"who": "type"`), else on every troop. [k]:
/// its own price in purses, over its rarity's.
class BoostRule {
  const BoostRule(this.rarity,
      {this.dmg = 1, this.taken = 1, this.maxHp = 1, this.rate = 1, this.mpRegen = 1, this.gold = 1, this.leaks = 0, this.oneType = false, this.k});

  final Rarity rarity;
  final double dmg, taken, maxHp, rate, mpRegen, gold;
  final int leaks;
  final bool oneType;
  final double? k;

  /// What it changes, by the file's names, only what isn't 1 (or 0 leaks): the file's, the event's and the texts' shape.
  Map<String, num> get effects => {
        if (dmg != 1) 'dmg': dmg,
        if (taken != 1) 'taken': taken,
        if (maxHp != 1) 'hp': maxHp,
        if (rate != 1) 'rate': rate,
        if (mpRegen != 1) 'mpRegen': mpRegen,
        if (gold != 1) 'gold': gold,
        if (leaks > 0) 'leaks': leaks,
      };

  /// [j]'s rule, each field only when it is of the right kind and in range (a multiplier above 0, [leaks] not negative),
  /// else [d]'s; a rarity or a `who` it doesn't know is noted in [skipped].
  factory BoostRule.fromJson(Map<String, dynamic> j, BoostRule d, List<String> skipped, String where) {
    double x(String key, double def) => switch (j[key]) { final num v when v > 0 && v.isFinite => v.toDouble(), _ => def };
    final rarity = switch (j['rarity']) {
      null => d.rarity,
      final Object v => rarityKeys.entries.where((e) => e.value == v).firstOrNull?.key ?? (skipped..add('$where.rarity: $v'), d.rarity).$2,
    };
    final who = switch (j['who']) {
      null => d.oneType,
      'all' => false,
      'type' => true,
      final Object v => (skipped..add('$where.who: $v'), d.oneType).$2,
    };
    return BoostRule(rarity,
        dmg: x('dmg', d.dmg),
        taken: x('taken', d.taken),
        maxHp: x('hp', d.maxHp),
        rate: x('rate', d.rate),
        mpRegen: x('mpRegen', d.mpRegen),
        gold: x('gold', d.gold),
        leaks: switch (j['leaks']) { final int n when n >= 0 => n, _ => d.leaks },
        oneType: who,
        k: switch (j['k']) { final num v when v > 0 && v.isFinite => v.toDouble(), _ => d.k });
  }

  Map<String, dynamic> toJson() => {'rarity': rarityKeys[rarity], ...effects, if (oneType) 'who': 'type', 'k': ?k};
}

/// The most the boosts running together give one stat (town.json `tavern.most`; the owner's no-limit buys made it a
/// must): the product of their multipliers stops at [dmg], [maxHp], [rate], [mpRegen] and [gold], and the damage taken's at
/// [taken] (a floor: the most it is cut).
class BoostMost {
  const BoostMost({this.dmg = 1.8, this.maxHp = 1.8, this.rate = 1.8, this.mpRegen = 1.8, this.gold = 2.0, this.taken = 0.6});

  final double dmg, maxHp, rate, mpRegen, gold, taken;

  factory BoostMost.fromJson(Map<String, dynamic> j) {
    const d = BoostMost();
    double up(String key, double def) => switch (j[key]) { final num v when v >= 1 && v.isFinite => v.toDouble(), _ => def };
    return BoostMost(
      dmg: up('dmg', d.dmg),
      maxHp: up('hp', d.maxHp),
      rate: up('rate', d.rate),
      mpRegen: up('mpRegen', d.mpRegen),
      gold: up('gold', d.gold),
      taken: switch (j['taken']) { final num v when v > 0 && v <= 1 => v.toDouble(), _ => d.taken },
    );
  }

  Map<String, dynamic> toJson() => {'dmg': dmg, 'hp': maxHp, 'rate': rate, 'mpRegen': mpRegen, 'gold': gold, 'taken': taken};
}

/// The Tavern's numbers (town.json `tavern`, decisions-log 266): [offers] a visit, each boost's [waves] (every kind the
/// same: the owner's two), the wave a Legendary may first be offered at ([legendFrom]; before it an Epic), the [pity]th
/// visit in a row without an Epic or better gets one in its last slot (0: never), the run's first Tavern's first offer the
/// Feast ([firstFeast]); each rarity's [odds] (a share of their sum); the [price] of a rarity in the Tavern's purses of
/// the wave won ([purseAt]: the game's purse, [early] of it at wave 0 rising to all of it at [fullFrom], so the first
/// Towns are cheap: the owner, 2026-10-08), at least [priceLeast], rounded to [round] gold, to [roundBig] from
/// [bigFrom]; the first reroll's [rerollK] purses (at least [rerollLeast], rounded the same), × [rerollRise] for each one
/// before it in the visit; the [most] a stat gets from boosts together; and every kind's [boosts] rule.
class TavernRules {
  const TavernRules({
    this.offers = 3,
    this.waves = 2,
    this.legendFrom = 30,
    this.pity = 4,
    this.firstFeast = true,
    this.odds = const {Rarity.biasa: 0.55, Rarity.langka: 0.30, Rarity.epik: 0.13, Rarity.legenda: 0.02},
    this.price = const {Rarity.biasa: 0.3, Rarity.langka: 0.5, Rarity.epik: 0.9, Rarity.legenda: 1.5},
    this.early = 0.5,
    this.fullFrom = 20,
    this.priceLeast = 50,
    this.round = 50,
    this.roundBig = 1000,
    this.bigFrom = 10000,
    this.rerollK = 0.1,
    this.rerollLeast = 50,
    this.rerollRise = 2.0,
    this.most = const BoostMost(),
    this.boosts = _tavernBoosts,
  });

  final int offers, waves, legendFrom, pity, fullFrom, priceLeast, round, roundBig, bigFrom, rerollLeast;
  final bool firstFeast;
  final Map<Rarity, double> odds, price;
  final double early, rerollK, rerollRise;
  final BoostMost most;
  final Map<Boost, BoostRule> boosts;

  /// [j]'s numbers, each only when of the right kind and in range (else its default); a name it doesn't know (a key of
  /// the block, a rarity, a boost) is left out and noted in [skipped].
  factory TavernRules.fromJson(Map<String, dynamic> j, List<String> skipped) {
    const d = TavernRules();
    Map<String, dynamic> block(Map<String, dynamic> m, String k) => switch (m[k]) { final Map<String, dynamic> b => b, _ => const {} };
    void unknown(Map<String, dynamic> m, Iterable<String> known, String where) =>
        skipped.addAll([for (final k in m.keys) if (!known.contains(k)) '$where: no $k']);
    int atLeast(Map<String, dynamic> m, String k, int least, int def) => switch (m[k]) { final int v when v >= least => v, _ => def };
    double above(Map<String, dynamic> m, String k, double least, double def) =>
        switch (m[k]) { final num v when v >= least && v.isFinite => v.toDouble(), _ => def };
    // A share of each rarity, by its key: one it doesn't know is noted; none above 0 keeps the defaults.
    Map<Rarity, double> byRarity(Map<String, dynamic> m, Map<Rarity, double> def, String where, {required bool positive}) {
      unknown(m, rarityKeys.values, where);
      final out = {
        for (final MapEntry(key: r, value: v) in def.entries)
          r: switch (m[rarityKeys[r]]) { final num n when n >= 0 && n.isFinite && (!positive || n > 0) => n.toDouble(), _ => v },
      };
      return out.values.any((v) => v > 0) ? out : def;
    }

    final price = block(j, 'price'), reroll = block(j, 'reroll'), boosts = block(j, 'boosts');
    unknown(j, d.toJson().keys, 'tavern');
    unknown(price, ['k', 'early', 'fullFrom', 'least', 'round', 'roundBig', 'bigFrom'], 'tavern.price');
    unknown(reroll, ['k', 'least', 'rise'], 'tavern.reroll');
    unknown(boosts, [for (final b in Boost.values) b.name], 'tavern.boosts');
    return TavernRules(
      offers: switch (j['offers']) { final int n when n >= 1 && n <= Boost.values.length => n, _ => d.offers },
      waves: atLeast(j, 'waves', 1, d.waves),
      legendFrom: atLeast(j, 'legendFrom', 0, d.legendFrom),
      pity: atLeast(j, 'pity', 0, d.pity),
      firstFeast: switch (j['firstFeast']) { final bool b => b, _ => d.firstFeast },
      odds: byRarity(block(j, 'odds'), d.odds, 'tavern.odds', positive: false),
      price: byRarity(block(price, 'k'), d.price, 'tavern.price.k', positive: true),
      early: switch (price['early']) { final num v when v >= 0 && v <= 1 => v.toDouble(), _ => d.early },
      fullFrom: atLeast(price, 'fullFrom', 1, d.fullFrom),
      priceLeast: atLeast(price, 'least', 0, d.priceLeast),
      round: atLeast(price, 'round', 1, d.round),
      roundBig: atLeast(price, 'roundBig', 1, d.roundBig),
      bigFrom: atLeast(price, 'bigFrom', 0, d.bigFrom),
      rerollK: above(reroll, 'k', 0, d.rerollK),
      rerollLeast: atLeast(reroll, 'least', 0, d.rerollLeast),
      rerollRise: above(reroll, 'rise', 1, d.rerollRise),
      most: BoostMost.fromJson(block(j, 'most')),
      boosts: {
        for (final MapEntry(key: b, value: def) in d.boosts.entries)
          b: switch (boosts[b.name]) { final Map<String, dynamic> v => BoostRule.fromJson(v, def, skipped, 'tavern.boosts.${b.name}'), _ => def },
      },
    );
  }

  /// The Tavern's purse of wave [w]: the game's ([purseRaw]) × [early] at wave 0, rising in a line to × 1 at [fullFrom].
  double purseAt(int w) => purseRaw(w) * (early + (1 - early) * min(1, w / fullFrom));

  /// [v] gold rounded the Tavern's way: to [round], to [roundBig] from [bigFrom].
  int rounded(double v) => v >= bigFrom ? (v / roundBig).round() * roundBig : (v / round).round() * round;

  Map<String, dynamic> toJson() => {
        'offers': offers,
        'waves': waves,
        'legendFrom': legendFrom,
        'pity': pity,
        'firstFeast': firstFeast,
        'odds': {for (final MapEntry(:key, :value) in odds.entries) rarityKeys[key]!: value},
        'price': {
          'k': {for (final MapEntry(:key, :value) in price.entries) rarityKeys[key]!: value},
          'early': early,
          'fullFrom': fullFrom,
          'least': priceLeast,
          'round': round,
          'roundBig': roundBig,
          'bigFrom': bigFrom,
        },
        'reroll': {'k': rerollK, 'least': rerollLeast, 'rise': rerollRise},
        'most': most.toJson(),
        'boosts': {for (final MapEntry(:key, :value) in boosts.entries) key.name: value.toJson()},
      };
}

/// The shipped catalogue (assets/config/town.json writes each one out). Every kind lasts [TavernRules.waves] (the owner:
/// two waves, every one). Travel Rations was the design's "longer but weaker" (5 waves); with every boost two waves it is
/// a cheap Common with a little of everything.
const _tavernBoosts = {
  Boost.feast: BoostRule(Rarity.langka, dmg: 1.20, taken: 0.85),
  Boost.ale: BoostRule(Rarity.biasa, dmg: 1.15),
  Boost.stew: BoostRule(Rarity.biasa, maxHp: 1.20),
  Boost.broth: BoostRule(Rarity.biasa, taken: 0.88),
  Boost.tea: BoostRule(Rarity.biasa, rate: 1.12),
  Boost.rations: BoostRule(Rarity.biasa, dmg: 1.06, taken: 0.94, maxHp: 1.06),
  Boost.toast: BoostRule(Rarity.biasa, gold: 1.30),
  Boost.mage: BoostRule(Rarity.langka, mpRegen: 1.60),
  Boost.plate: BoostRule(Rarity.epik, dmg: 1.40, rate: 1.15, oneType: true),
  Boost.watch: BoostRule(Rarity.epik, leaks: 1),
  Boost.banquet: BoostRule(Rarity.legenda, dmg: 1.30, taken: 0.75, maxHp: 1.25, rate: 1.10),
};

/// What a boost of [effects] ([BoostRule.effects]) does, one short line each: "+20% damage", "15% less damage taken".
List<String> boostEffectLines(Map<String, num> effects) => [
      for (final MapEntry(:key, :value) in effects.entries)
        switch (key) {
          'leaks' => value == 1 ? 'a leak a wave costs no life' : '$value leaks a wave cost no life',
          'taken' => value <= 1 ? '${_percent(1 - value)}% less damage taken' : '${_percent(value - 1)}% more damage taken',
          _ => '${value >= 1 ? '+' : '-'}${_percent((value - 1).abs())}% ${_boostStatWords[key] ?? key}',
        },
    ];

const _boostStatWords = {'dmg': 'damage', 'hp': 'max HP', 'rate': 'attack speed', 'mpRegen': 'MP regen', 'gold': 'kill gold'};

int _percent(num share) => (share * 100).round();

/// One offer in the Tavern: its [kind], the [type] it works on (a one-type kind's, rolled with it), and whether it was
/// bought.
class BoostOffer {
  BoostOffer(this.kind, {this.type, this.sold = false});

  final Boost kind;
  final String? type;
  bool sold;

  factory BoostOffer.fromJson(Map j) => BoostOffer(Boost.values.byName(j['kind'] as String), type: j['type'] as String?, sold: j['sold'] == true);

  Map<String, Object> toJson() => {'kind': kind.name, 'type': ?type, if (sold) 'sold': true};
}

/// A boost running: its [kind], the waves [left] (counted down at each wave's end), the [type] it works on (a one-type
/// kind's), and the leaks it forgave this wave ([saved]; not saved: a save is between waves).
class RunningBoost {
  RunningBoost(this.kind, this.left, {this.type});

  final Boost kind;
  final String? type;
  int left, saved = 0;

  Map<String, Object> toJson() => {'kind': kind.name, 'left': left, 'type': ?type};
}

/// The Tavern in the Town the player is in ([Game._tavern]): its [offers], the rerolls bought, the gold spent on boosts and
/// rerolls, the kinds bought; for the save and [TownLeft.tavern].
class TavernVisit {
  TavernVisit(this.offers);

  final List<BoostOffer> offers;
  int rerolls = 0, spent = 0;
  final bought = <Boost>[];

  Map<String, Object> toJson() => {
        'offers': [for (final o in offers) o.toJson()],
        if (rerolls > 0) 'rerolls': rerolls,
        if (spent > 0) 'spent': spent,
        if (bought.isNotEmpty) 'bought': [for (final b in bought) b.name],
      };
}

/// Why a boost can't be bought or the offers rerolled now: the game is over, not in a Town, the offer
/// already bought (or every one, for a reroll), or the gold is short.
enum BoostWhy { over, town, sold, soldOut, gold }

/// Each [BoostWhy] in the player's words.
const boostRefusals = {
  BoostWhy.over: Words.gameOver,
  BoostWhy.town: Words.onlyInTown,
  BoostWhy.sold: Words.sold,
  BoostWhy.soldOut: Words.soldOut,
  BoostWhy.gold: Words.notEnoughGold,
};

/// The effect keys ([BoostRule.effects]) that act on troops: a boost with one says which troops it is for.
const _boostTroopKeys = {'dmg', 'taken', 'hp', 'rate', 'mpRegen'};

/// Who a boost of [kind] works on, in the player's words: "All troops", a one-type kind's [type] ("Knights"), or null for
/// one that doesn't act on troops (kill gold, a leak).
String? boostWho(Game g, Boost kind, String? type) => !g.boostRule(kind).effects.keys.any(_boostTroopKeys.contains)
    ? null
    : type == null
        ? 'All troops'
        : troopTypePlurals[type] ?? type;

/// The Tavern on [Game] (the fields are the class's: [Game.tavernDice], [Game.boosts], …).
extension Tavern on Game {
  /// The offers of the Tavern the player is in, in their slots; none outside a Town.
  List<BoostOffer> get tavernOffers => _tavern?.offers ?? const [];

  /// The rerolls bought in this visit, and the gold spent on boosts and rerolls in it.
  int get tavernRerolls => _tavern?.rerolls ?? 0;
  int get tavernSpent => _tavern?.spent ?? 0;

  /// [kind]'s rule as this game reads it.
  BoostRule boostRule(Boost kind) => townRules.tavern.boosts[kind]!;

  /// Whether a boost of [kind] runs now.
  bool boostRunning(Boost kind) => boosts.any((b) => b.kind == kind);

  /// Whether running boost [b] acts on troop [type]'s troops: one with a troop effect, on every type or on its own.
  bool boostTouches(RunningBoost b, String type) =>
      (b.type == null || b.type == type) && boostRule(b.kind).effects.keys.any(_boostTroopKeys.contains);

  /// The battle chip's tooltip for running boost [i] ([Game.boosts]; decisions-log 268): "Feast: 2 waves left", then
  /// what it does, an effect a line, and who it works on.
  (String, List<String>) boostTip(int i) {
    final b = boosts[i], who = boostWho(this, b.kind, b.type);
    return (
      '${boostNames[b.kind]}: ${b.left} ${b.left == 1 ? 'wave' : 'waves'} left',
      [...boostEffectLines(boostRule(b.kind).effects), ?who],
    );
  }

  /// What a boost of [kind] costs now: its rarity's purses (or its own [BoostRule.k]) of the wave won
  /// ([TavernRules.purseAt]), rounded the Tavern's way, at least [TavernRules.priceLeast].
  int boostPrice(Boost kind) {
    final r = townRules.tavern, rule = r.boosts[kind]!;
    return max(r.priceLeast, r.rounded((rule.k ?? r.price[rule.rarity]!) * r.purseAt(max(1, wave))));
  }

  /// What the next reroll costs: [TavernRules.rerollK] purses of the wave won × [TavernRules.rerollRise] for each one
  /// bought in this visit, rounded the Tavern's way, at least [TavernRules.rerollLeast].
  int get tavernRerollPrice {
    final r = townRules.tavern;
    return max(r.rerollLeast, r.rounded(r.rerollK * r.purseAt(max(1, wave)) * pow(r.rerollRise, tavernRerolls)));
  }

  /// Why offer [i] can't be bought now, or null: the game over, no Tavern here (not in a Town, no such
  /// offer), bought already, the gold short. Every offer can be bought while the gold lasts (the owner: no buy limit).
  BoostWhy? whyNotBuyBoost(int i) {
    if (over) return BoostWhy.over;
    final v = _tavern;
    if (!towns || !inTown || v == null || i < 0 || i >= v.offers.length) return BoostWhy.town;
    if (v.offers[i].sold) return BoostWhy.sold;
    if (gold < boostPrice(v.offers[i].kind)) return BoostWhy.gold;
    return null;
  }

  /// Buys offer [i] ([whyNotBuyBoost]): its price paid, it runs at once for [TavernRules.waves] waves (the troops refit:
  /// HP gained comes with it), and [BoostBought]. False (and [Sfx.error]) when it can't.
  bool buyBoost(int i) {
    if (whyNotBuyBoost(i) != null) {
      sfx.add(Sfx.error);
      return false;
    }
    final v = _tavern!, o = v.offers[i], rule = boostRule(o.kind), price = boostPrice(o.kind), waves = townRules.tavern.waves;
    gold -= price;
    o.sold = true;
    v
      ..spent += price
      ..bought.add(o.kind);
    boosts.add(RunningBoost(o.kind, waves, type: o.type));
    _refitTroops(); // the living troops take it now (pusaka.dart's oath does the same)
    sfx.add(Sfx.clear);
    _emit(BoostBought(wave, t, boost: o.kind, rarity: rule.rarity, price: price, waves: waves, type: o.type, slot: i, effects: rule.effects));
    return true;
  }

  /// Why the offers can't be rerolled now, or null: the game over, no Tavern here, every offer bought, the gold short.
  BoostWhy? whyNotRerollTavern() {
    if (over) return BoostWhy.over;
    final v = _tavern;
    if (!towns || !inTown || v == null) return BoostWhy.town;
    if (v.offers.every((o) => o.sold)) return BoostWhy.soldOut;
    if (gold < tavernRerollPrice) return BoostWhy.gold;
    return null;
  }

  /// Rerolls the unbought offers ([whyNotRerollTavern]) on [Game.tavernDice], each in its slot, for [tavernRerollPrice]
  /// ([TavernRerolled]); the bought ones stay. No pity, no first Feast: those are the visit's first roll's. False (and
  /// [Sfx.error]) when it can't.
  bool rerollTavern() {
    if (whyNotRerollTavern() != null) {
      sfx.add(Sfx.error);
      return false;
    }
    final v = _tavern!, price = tavernRerollPrice;
    gold -= price;
    v
      ..rerolls += 1
      ..spent += price;
    final taken = {for (final o in v.offers) if (o.sold) o.kind};
    for (var i = 0; i < v.offers.length; i++) {
      if (v.offers[i].sold) continue;
      final open = _openBoosts(taken);
      if (open.isEmpty) {
        taken.add(v.offers[i].kind); // nothing else left: it stays
        continue;
      }
      final kind = _drawBoost(open);
      taken.add(kind);
      v.offers[i] = BoostOffer(kind, type: boostRule(kind).oneType ? _boostType() : null);
    }
    sfx.add(Sfx.click);
    _emit(TavernRerolled(wave, t, price: price, n: v.rerolls, offers: [for (final o in v.offers) o.kind]));
    return true;
  }

  /// The visit's first roll ([Towns.enterTown], with the Tavern on): [TavernRules.offers] different kinds on
  /// [Game.tavernDice], none of a kind running. The run's first Tavern ([Game.tavernSeen] false) has the Feast first
  /// ([TavernRules.firstFeast]); after [TavernRules.pity] − 1 visits in a row without an Epic or better ([Game.tavernDry])
  /// the last slot is an Epic when none came before it. Each other slot draws a rarity ([TavernRules.odds]) and a kind of
  /// it, stepping down, then up, when that rarity has none left (a Legendary before [TavernRules.legendFrom] has none); a
  /// one-type kind draws its type among the types alive.
  void _rollTavern() {
    final r = townRules.tavern, first = r.firstFeast && !tavernSeen, pity = r.pity > 0 && tavernDry >= r.pity - 1;
    final offers = <BoostOffer>[];
    bool epicOrBetter(Boost k) => r.boosts[k]!.rarity.index >= Rarity.epik.index;
    for (var i = 0; i < r.offers; i++) {
      final open = _openBoosts({for (final o in offers) o.kind});
      if (open.isEmpty) break;
      final Boost kind;
      if (first && i == 0 && open.contains(Boost.feast)) {
        kind = Boost.feast;
      } else {
        final lift = pity && i == r.offers - 1 && !offers.any((o) => epicOrBetter(o.kind));
        kind = _drawBoost(open, lift ? Rarity.epik : null);
      }
      offers.add(BoostOffer(kind, type: r.boosts[kind]!.oneType ? _boostType() : null));
    }
    _tavern = TavernVisit(offers);
    tavernSeen = true;
    tavernDry = offers.any((o) => epicOrBetter(o.kind)) ? 0 : tavernDry + 1;
  }

  /// The kinds that may be offered now, but [taken]: none running, a Legendary only from [TavernRules.legendFrom], a
  /// one-type kind only while a troop lives; in [Boost] order.
  List<Boost> _openBoosts(Set<Boost> taken) {
    final r = townRules.tavern, alive = troops.any((u) => u.alive);
    return [
      for (final k in Boost.values)
        if (!taken.contains(k) &&
            !boostRunning(k) &&
            (r.boosts[k]!.rarity != Rarity.legenda || wave >= r.legendFrom) &&
            (!r.boosts[k]!.oneType || alive))
          k,
    ];
  }

  /// One kind of [open], of rarity [want] (null: one drawn by [TavernRules.odds]) or the nearest below it that has any,
  /// else above it; one draw on [Game.tavernDice] for the rarity (none when [want] is given) and one for the kind.
  Boost _drawBoost(List<Boost> open, [Rarity? want]) {
    final r = townRules.tavern;
    final rarity = want ?? _boostRarity();
    final order = [
      for (var i = rarity.index; i >= 0; i--) Rarity.values[i],
      for (var i = rarity.index + 1; i < Rarity.values.length; i++) Rarity.values[i],
    ];
    for (final at in order) {
      final pool = [for (final k in open) if (r.boosts[k]!.rarity == at) k];
      if (pool.isNotEmpty) return pool[tavernDice.nextInt(pool.length)];
    }
    return open[tavernDice.nextInt(open.length)];
  }

  /// A rarity by [TavernRules.odds] (each a share of their sum), on one [Game.tavernDice] draw.
  Rarity _boostRarity() {
    final odds = townRules.tavern.odds, total = odds.values.fold(0.0, (a, b) => a + b);
    var at = tavernDice.nextDouble() * total;
    for (final MapEntry(:key, :value) in odds.entries) {
      if (at < value) return key;
      at -= value;
    }
    return odds.keys.last;
  }

  /// A troop type alive, in [troopTypes] order, on one [Game.tavernDice] draw (a one-type kind's).
  String _boostType() {
    final types = [for (final type in troopTypes.keys) if (troops.any((u) => u.alive && u.type == type)) type];
    return types[tavernDice.nextInt(types.length)];
  }

  /// [type]'s stats [s] with the boosts running ([Game.statsOf]'s last step; only called while any runs): the product of
  /// each one's multipliers that works on [type], each stat's stopped at [TavernRules.most]. Damage (a healer's heal), max
  /// HP, the pause between attacks (÷: faster), MP regen, and the damage taken ([Stats.taken], cut after the Guard relic
  /// as the forge's Helm: every troop has it, shields or not). Outside the relics' cap: a boost is no relic factor.
  Stats _boostStats(String type, Stats s) {
    final r = townRules.tavern, m = r.most;
    var (dmg, taken, hp, rate, mp) = (1.0, 1.0, 1.0, 1.0, 1.0);
    for (final b in boosts) {
      if (b.type != null && b.type != type) continue;
      final e = r.boosts[b.kind]!;
      (dmg, taken, hp, rate, mp) = (dmg * e.dmg, taken * e.taken, hp * e.maxHp, rate * e.rate, mp * e.mpRegen);
    }
    (dmg, taken, hp, rate, mp) = (min(dmg, m.dmg), max(taken, m.taken), min(hp, m.maxHp), min(rate, m.rate), min(mp, m.mpRegen));
    return s._with(
        hp: hp == 1 ? null : (s.hp * hp).round(), dmg: s.dmg * dmg, taken: s.taken * taken, rate: s.rate / rate, mpRegen: s.mpRegen * mp);
  }

  /// A kill's [gold] with the boosts running (the kill pay line, after the Bayangan Thrift; not the won wave's bonus nor
  /// Plunder's extra): times their gold multipliers, at most [BoostMost.gold].
  int _boostGold(int gold) {
    if (boosts.isEmpty) return gold;
    var k = 1.0;
    for (final b in boosts) {
      k *= boostRule(b.kind).gold;
    }
    k = min(k, townRules.tavern.most.gold);
    return k == 1 ? gold : (gold * k).round();
  }

  /// A monster crossed the back line: true when a boost running forgives it ([BoostRule.leaks] a wave: Watchman's Brew),
  /// so no life is lost ([BoostSaved]).
  bool _boostLeak() {
    for (final b in boosts) {
      if (b.saved < boostRule(b.kind).leaks) {
        b.saved++;
        _emit(BoostSaved(wave, t, boost: b.kind));
        return true;
      }
    }
    return false;
  }

  /// A wave ended (won, or the game lost): each boost running has one wave fewer, its forgiven leaks back to none, and
  /// those at 0 end ([BoostEnded]): the troops refit, the HP lost only capped ([Game._refit]: it never kills).
  void _boostWaveEnd() {
    if (boosts.isEmpty) return;
    for (final b in boosts) {
      b
        ..left -= 1
        ..saved = 0;
    }
    final ended = [for (final b in boosts) if (b.left <= 0) b];
    if (ended.isEmpty) return;
    boosts.removeWhere(ended.contains);
    _refitTroops();
    for (final b in ended) {
      _emit(BoostEnded(wave, t, boost: b.kind, type: b.type));
    }
  }

  /// A probe's buys in a Tavern ([Game.tavernPolicy], from [Towns._townByPolicy] before it leaves): 'top' the best offer
  /// it can pay (the highest rarity, then the dearest, then the first slot), 'all' every one it can pay in that order.
  void _tavernByPolicy() {
    final v = _tavern;
    if (v == null) return;
    int rank(int i) => boostRule(v.offers[i].kind).rarity.index;
    final order = [for (var i = 0; i < v.offers.length; i++) i]
      ..sort((a, b) => switch (rank(b).compareTo(rank(a))) {
            0 => switch (boostPrice(v.offers[b].kind).compareTo(boostPrice(v.offers[a].kind))) { 0 => a.compareTo(b), final c => c },
            final c => c,
          });
    for (final i in order) {
      if (whyNotBuyBoost(i) == null && buyBoost(i) && tavernPolicy == 'top') return;
    }
  }

  /// What the visit did, for [TownLeft.tavern]: the kinds of its last roll, the kinds bought, the rerolls, the gold spent;
  /// null without a Tavern.
  Map<String, Object>? get _tavernLeft => switch (_tavern) {
        final v? => {
            'offered': [for (final o in v.offers) o.kind.name],
            'bought': [for (final b in v.bought) b.name],
            'rerolls': v.rerolls,
            'spent': v.spent,
          },
        _ => null,
      };

  /// The save's `boosts` (top level), only while any runs.
  Map<String, Object> get _boostsJson => {
        if (boosts.isNotEmpty) 'boosts': [for (final b in boosts) b.toJson()],
      };

  /// The save's Tavern keys inside `town` ([Towns._townJson]): the visit while in a Town, the pity's count and whether the
  /// first Tavern was rolled; none while unused.
  Map<String, Object> get _tavernTownJson => {
        if (inTown && _tavern != null) 'tavern': _tavern!.toJson(),
        if (tavernDry > 0) 'tavernDry': tavernDry,
        if (tavernSeen) 'tavernSeen': true,
      };

  /// [j]'s `boosts` ([Game.fromJson], before the troops come in, so they fit with them), whatever the flags are (the key
  /// is only written while one runs): an unknown kind, a one-type kind without a troop type, and one with no wave left
  /// are dropped.
  void _loadBoosts(Map<String, dynamic> j) {
    for (final b in (j['boosts'] as List?) ?? const []) {
      if (b is! Map) continue;
      final kind = Boost.values.asNameMap()[b['kind']], left = b['left'], type = b['type'];
      if (kind == null || left is! int || left <= 0) continue;
      final oneType = boostRule(kind).oneType;
      if (oneType && !troopTypes.containsKey(type)) continue;
      boosts.add(RunningBoost(kind, left, type: oneType ? type as String : null));
    }
  }

  /// [town]'s Tavern keys ([Towns._loadTown]): the pity's count, the first Tavern rolled, and the visit while in a Town
  /// (an unknown kind's offer dropped); in a Town with the Tavern on and no visit saved (a save from a build without it),
  /// the visit is rolled now.
  void _loadTavern(Map town) {
    tavernDry = switch (town['tavernDry']) { final int n when n > 0 => n, _ => 0 };
    tavernSeen = town['tavernSeen'] == true;
    if (!inTown) return;
    if (town['tavern'] case final Map v) {
      _tavern = TavernVisit([
        for (final o in (v['offers'] as List?) ?? const [])
          if (o is Map && Boost.values.asNameMap().containsKey(o['kind']) && (o['type'] == null || troopTypes.containsKey(o['type'])))
            BoostOffer.fromJson(o),
      ])
        ..rerolls = switch (v['rerolls']) { final int n when n > 0 => n, _ => 0 }
        ..spent = switch (v['spent']) { final int n when n > 0 => n, _ => 0 }
        ..bought.addAll([for (final b in (v['bought'] as List?) ?? const []) ?Boost.values.asNameMap()[b]]);
    } else {
      _rollTavern();
    }
  }
}
