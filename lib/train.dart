part of 'game.dart';

// Train (decisions-log 334; docs/loot-items-relics.md "Train"): the owner, 2026-10-13, "setelah enhance sudah penuh di late
// game user bisa bebas mengupgrade attribute dari troopsnya tapi untuk attack speed dan walkspeed ini ada limitnya, selain
// itu bisa di enhance semua". Once every item of a troop type's three grade sets is at the most Enhance gives (+5,
// [Train.trainOpen]), the type buys levels of eight attributes ([TrainStat]) for gold and a material, per type (its
// troops now and later), on its Army detail between waves (troop_detail.dart's Train section), as Forge is bought.
// HP, power, defence, MP and MP regen have no end (a guard at [trainMax]); attack speed stops at the attack floor
// ([minAttackInterval]), walk speed at the walk cap ([walkCap]) and reach at [Train.trainCapOf]'s. Forge stays as it is.

/// The attributes Train raises, in the Army detail's order: HP, power (a healer's heal), defence, MP, MP regen, attack
/// speed (the pause between attacks), walk speed and reach. Their names are the save's keys: never renamed.
enum TrainStat { hp, power, defence, mp, mpRegen, rate, speed, range }

/// What one level gives: HP, power, MP and MP regen ×(1 + [trainPct]), compounding, as a Forge level's HP; defence
/// +[trainDef], a grade-I Shield's; the pause between attacks ÷(1 + [trainFast]), walk speed and reach ×(1 + [trainFast]),
/// each up to its cap ([Train.trainCapOf]).
const trainPct = 0.05, trainDef = shieldDef, trainFast = 0.1;

/// The farthest Train takes a shooter's or a healer's reach: one screen's width ([cols] tiles, 320). A melee fighter's
/// stops at its own reach cap ([Stats.reachCap]: [meleeMaxRange], or what spears raised it to). Bows and a Hero's ×3 are
/// not cut by it: at the gate every shooter and healer is past it with its bows alone (an archer 1,487).
const trainReachMost = cols * tile;

/// Level n + 1 of an attribute costs [trainK] × the wave's [purse] × [trainRise]^n gold, rounded to [trainRound] (at
/// least that), and 1 + n ~/ 2 of its material ([trainParts]).
const trainK = 0.15, trainRise = 1.2, trainRound = 1000;

/// A guard: no attribute is bought past this level (its price is then 1.2^49, about 7,600 times its first).
const trainMax = 50;

/// Each attribute's material, a late monster's Rare part: HP the Werebear's Bear Claw, power the Veteran Orc's Orc Heart,
/// defence the Armored Orc's Iron Tusk, MP the Necro Healer's Teal Gem, MP regen the Necromancer's Dark Gem, attack speed
/// the Werewolf's Wolf Fang, walk speed the Orc Rider's Warg Fang, reach the Skeleton Archer's Bone Bow.
const trainParts = {
  TrainStat.hp: Mat.bearClaw,
  TrainStat.power: Mat.orcHeart,
  TrainStat.defence: Mat.ironTusk,
  TrainStat.mp: Mat.tealGem,
  TrainStat.mpRegen: Mat.darkGem,
  TrainStat.rate: Mat.wolfFang,
  TrainStat.speed: Mat.wargFang,
  TrainStat.range: Mat.boneBow,
};

/// What level [n] + 1 of an attribute costs after wave [w]: [trainK] × [purse] × [trainRise]^[n], rounded to
/// [trainRound], at least [trainRound]. Wave 90: 20k, 23k, 28k, 34k, 40k … 101k at level 10.
int trainPrice(int w, int n) => max(1, (trainK * purse(w) * pow(trainRise, n) / trainRound).round()) * trainRound;

/// How many of its material level [n] + 1 takes: 1, 1, 2, 2, 3 …
int trainPartCount(int n) => 1 + n ~/ 2;

/// Each attribute's name on the Train rows: the Army detail's short names (a healer's power is its heal).
String trainStatName(TrainStat stat, {bool heals = false}) => switch (stat) {
      TrainStat.hp => Words.hp,
      TrainStat.power => heals ? Words.heal : Words.damage,
      TrainStat.defence => Words.defence,
      TrainStat.mp => Words.mp,
      TrainStat.mpRegen => Words.mpRegen,
      TrainStat.rate => Words.rate,
      TrainStat.speed => Words.speed,
      TrainStat.range => Words.range,
    };

/// The item whose icon stands for [stat] on its row (the heart and the bolt are HP's and MP's): the power item
/// ([powerItem]: the staff for the casters), the Shield, the Ring (MP regen), the Gloves, the Boots, the Bow.
Item trainIcon(String type, TrainStat stat) => switch (stat) {
      TrainStat.power => powerItem(type),
      TrainStat.defence => Item.shield,
      TrainStat.mpRegen => Item.ring,
      TrainStat.rate => Item.gloves,
      TrainStat.speed => Item.boots,
      TrainStat.range => Item.bow,
      TrainStat.hp || TrainStat.mp => Item.amulet,
    };

/// A bought level as the battle log and the message window say it: "Train HP Lv 4" (a healer's power "Train Heal Lv 2").
String trainLine(String type, TrainStat stat, int level) =>
    '${Words.train} ${trainStatName(stat, heals: troopTypes[type]?.heals ?? false)} ${Words.lv} $level';

/// What one more level of [stat] gives, as its row says it: "+5%", "+2.5", "-9%" (the pause), "+10%".
String trainGain(TrainStat stat) => switch (stat) {
      TrainStat.defence => '+${trainDef.toStringAsFixed(1)}',
      TrainStat.rate => '-${((1 - 1 / (1 + trainFast)) * 100).round()}%',
      TrainStat.speed || TrainStat.range => '+${(trainFast * 100).round()}%',
      _ => '+${(trainPct * 100).round()}%',
    };

/// Why a type can't buy a Train level, after the store's own refusals ([StoreRefusal]): its items aren't all +5 yet,
/// the attribute is at its cap (the attack floor, the walk cap, the reach cap) or at [trainMax], then its material
/// ([CraftRefusal]'s "Need 2 Bear Claw") and the gold.
final trainRefusals = (
  closed: 'Needs every item +5',
  floor: 'Max: attack floor',
  walk: 'Max: walk cap',
  reach: 'Max: reach cap',
  maxed: 'Max: ${Words.lv} $trainMax',
  gold: storeRefusalNames[StoreRefusal.gold]!,
);

/// Train's rules: the gate, the levels and what they give ([Game.statsOf] reads [_trainStats]), the price, the buy and
/// the save.
extension Train on Game {
  /// [type]'s three grade sets ([Game.gradeSet], Awaken 1 to 3), each item with how many of it the sets take: what
  /// "every item +5" counts. The Cap and the Ring are no part of it (no Awaken counts them, and a type needn't wear one),
  /// nor are copies past a set's count (a save from before the grades holds old grade-I ones).
  Map<Item, int> trainItems(String type) => {for (var l = 1; l <= maxAwaken; l++) ...gradeSet(type, l)};

  /// How far [type] is toward Train: its copies at the most Enhance gives ([Enhance.plusMost], +5) counted up to each
  /// set's count (have), and the sets' items in all (need): the knight 0/31 to 31/31.
  (int, int) trainProgress(String type) {
    var have = 0, need = 0;
    for (final MapEntry(key: item, value: n) in trainItems(type).entries) {
      need += n;
      have += min(n, plusesOn(type, item).where((p) => p >= plusMost).length);
    }
    return (have, need);
  }

  /// Whether [type] trains (decisions-log 334, the owner's "Semua item troop sudah +5"): every item of its three grade sets
  /// held at +5, as many of each as the set takes, whatever level it kept from old items. Awaken 4-5 isn't asked. Once
  /// met it stays: nothing takes a +5 copy off (Enhance's swap only sends out a lower "+"); if town.json raised
  /// `enhance.most` the levels would wait for the new top. Kept per type while its items and pluses are the same lists
  /// ([_trainGates]): [Game.statsOf] asks it.
  bool trainOpen(String type) {
    final items = upgrades[type], pluses = upgradePlus[type], n = items?.length ?? 0;
    if (items == null || pluses == null) return false;
    if (_trainGates[type] case (final i, final len, final p, final most, final open) when identical(i, items) && len == n && identical(p, pluses) && most == plusMost) {
      return open;
    }
    final (have, need) = trainProgress(type);
    final open = need > 0 && have >= need;
    _trainGates[type] = (items, n, pluses, plusMost, open);
    return open;
  }

  /// The levels of [stat] that count for [type]: those bought ([Game.train]), while its gate is open ([trainOpen]).
  int trainOf(String type, TrainStat stat) {
    final n = train[type]?[stat] ?? 0;
    return n > 0 && trainOpen(type) ? n : 0;
  }

  /// [s] (a type's stats with its items, awakening and Forge, [Game.statsOf]) with [type]'s Train levels ([trainOf]): HP,
  /// power, MP and MP regen ×(1 + [trainPct])^n, defence + [trainDef] × n; the pause between attacks ÷(1 + [trainFast])^n
  /// but never under the attack floor, walk and reach ×(1 + [trainFast])^n up to their caps ([trainCapOf]). A stat
  /// already past its cap (boots, bows) is left as it is.
  Stats _trainStats(String type, Stats s) {
    final levels = train[type];
    if (levels == null || levels.isEmpty || !trainOpen(type)) return s;
    int n(TrainStat stat) => levels[stat] ?? 0;
    double up(TrainStat stat) => pow(1 + trainPct, n(stat)).toDouble();
    double fast(TrainStat stat) => pow(1 + trainFast, n(stat)).toDouble();
    final reach = trainCapOf(type, TrainStat.range, s)!, walk = walkCap(type);
    return s._with(
      hp: (s.hp * up(TrainStat.hp)).round(),
      dmg: s.dmg * up(TrainStat.power),
      def: s.def + trainDef * n(TrainStat.defence),
      mp: (s.mp * up(TrainStat.mp)).round(),
      mpRegen: s.mpRegen * up(TrainStat.mpRegen),
      rate: s.rate > minAttackInterval ? max(minAttackInterval, s.rate / fast(TrainStat.rate)) : s.rate,
      speed: s.speed < walk ? min(walk, s.speed * fast(TrainStat.speed)) : s.speed,
      range: s.range < reach ? min(reach, s.range * fast(TrainStat.range)) : s.range,
    );
  }

  /// [stat]'s cap for [type] (with its stats [s] before Train, its own by default): the attack floor
  /// ([minAttackInterval]) for attack speed, the walk cap ([walkCap]) for walk speed, and for reach a melee fighter's
  /// own reach cap ([Stats.reachCap]) or [trainReachMost]; null for the five without one.
  double? trainCapOf(String type, TrainStat stat, [Stats? s]) => switch (stat) {
        TrainStat.rate => minAttackInterval,
        TrainStat.speed => walkCap(type),
        TrainStat.range => () {
            final own = s ?? _ownStats(type);
            return own.melee ? own.reachCap : trainReachMost;
          }(),
        _ => null,
      };

  /// [stat] of [type] as Train has it now: its own stats with its levels ([_ownStats], [_trainStats]), before the heavy
  /// types' +20%, an Artifact, an oath, a boost, the Hero and the aura.
  num trainValue(String type, TrainStat stat) {
    final s = _trainStats(type, _ownStats(type));
    return switch (stat) {
      TrainStat.hp => s.hp,
      TrainStat.power => s.dmg,
      TrainStat.defence => s.def,
      TrainStat.mp => s.mp,
      TrainStat.mpRegen => s.mpRegen,
      TrainStat.rate => s.rate,
      TrainStat.speed => s.speed,
      TrainStat.range => s.range,
    };
  }

  /// Whether [type]'s row of [stat] shows on the Army detail: every attribute's but reach where it can't rise (the owner,
  /// 2026-10-13: "Sembunyikan baris Range"): at its cap with no level of it bought, by the rule (a shooter's or a healer's
  /// past [trainReachMost] with its bows, a melee fighter's at its reach cap from bows). Attack speed and walk speed at
  /// their caps show "Max" instead ("Ya, biarkan begitu").
  bool trainShown(String type, TrainStat stat) => stat != TrainStat.range || (train[type]?[stat] ?? 0) > 0 || !trainCapped(type, stat);

  /// Whether [type]'s [stat] is at its cap ([trainCapOf]) with the levels it has: the next level would add nothing, so
  /// none is sold and the row says "Max". A capped stat that boots, gloves or bows already took past it is at it from
  /// the start (at the gate eight of the nine types are at the attack floor).
  bool trainCapped(String type, TrainStat stat) {
    final cap = trainCapOf(type, stat);
    if (cap == null) return false;
    final v = trainValue(type, stat);
    return stat == TrainStat.rate ? v <= cap + 1e-9 : v >= cap - 1e-9;
  }

  /// What [type]'s next level of [stat] costs now: the gold ([trainPrice] after this [wave]) and its material
  /// ([trainParts], [trainPartCount]); null at [trainMax].
  ({int gold, Mat mat, int n})? trainCostOf(String type, TrainStat stat) {
    final n = train[type]?[stat] ?? 0;
    return n < trainMax ? (gold: trainPrice(wave, n), mat: trainParts[stat]!, n: trainPartCount(n)) : null;
  }

  /// Why [type] can't buy its next level of [stat] now, in the UI's words, or null when it can: the store's refusal first
  /// ([Store._armyClosed]: before wave [storeFrom] is won, mid-wave, the game over), then [trainRefusals] in their order:
  /// the gate, the cap, [trainMax], the material ("Need 2 Bear Claw"), the gold.
  String? whyNotTrain(String type, TrainStat stat) {
    if (_armyClosed case final why?) return storeRefusalNames[why]!;
    if (!trainOpen(type)) return trainRefusals.closed;
    if (trainCapped(type, stat)) {
      return switch (stat) { TrainStat.rate => trainRefusals.floor, TrainStat.speed => trainRefusals.walk, _ => trainRefusals.reach };
    }
    final cost = trainCostOf(type, stat);
    if (cost == null) return trainRefusals.maxed;
    final have = materials[cost.mat] ?? 0;
    if (have < cost.n) return CraftRefusal(CraftWhy.material, short: cost.mat, have: have, need: cost.n).text;
    return gold < cost.gold ? trainRefusals.gold : null;
  }

  /// Buys [type]'s next level of [stat] for [trainCostOf]: the gold and the material go, every living troop of it is
  /// refitted ([_refit]: the HP and MP it gains come with it) and bursts in its awakening's colour, and it is logged
  /// ([Trained]). False (and nothing changes but the error sound) when [whyNotTrain] refuses.
  bool trainUp(String type, TrainStat stat) {
    if (whyNotTrain(type, stat) != null) {
      sfx.add(Sfx.error);
      return false;
    }
    final cost = trainCostOf(type, stat)!;
    gold -= cost.gold;
    materials[cost.mat] = materials[cost.mat]! - cost.n;
    final level = (train[type]?[stat] ?? 0) + 1;
    (train[type] ??= {})[stat] = level;
    for (final u in troops) {
      if (!u.alive || u.type != type) continue;
      _refit(u);
      impacts.add((u.pos, awakeFx('upgrade', awakenLevel(type))));
    }
    sfx
      ..add(Sfx.magic)
      ..add(Sfx.clear);
    _emit(Trained(wave, t, type: type, stat: stat, level: level, cost: cost.gold, mat: cost.mat, n: cost.n));
    return true;
  }

  /// Some living type can buy a Train level now ([whyNotTrain] null for one of its attributes): with the gold piled up,
  /// a reason for the Army tab's dot ([Tempa.armyNudge]).
  bool trainAny(String type) => trainOpen(type) && TrainStat.values.any((stat) => whyNotTrain(type, stat) == null);

  /// What [type]'s next level of [stat] gives, for its row's tooltip: its name, then its lines.
  (String, List<String>) trainInfo(String type, TrainStat stat) {
    final heals = troopTypes[type]!.heals, name = trainStatName(stat, heals: heals), n = train[type]?[stat] ?? 0;
    final cap = trainCapOf(type, stat);
    return ('${Words.train} $name', [
      '${trainGain(stat)} ${switch (stat) { TrainStat.rate => 'attack wait', TrainStat.defence => 'defence', _ => name }} a level',
      if (cap == null) 'Stacks each level' else 'Stacks up to its cap',
      allOfType,
      if (n > 0) 'Now: ${Words.lv} $n',
      if (whyNotTrain(type, stat) case final why? when why.startsWith('Max')) why
      else if (trainCostOf(type, stat) case (:final gold, :final mat, n: final k)?) 'Price: ${thousands(gold)} gold, $k ${mat.label}',
    ]);
  }

  // The save.

  /// The save's `train`: per type its levels by attribute ({"knight": {"hp": 3}}), only once one is bought.
  Map<String, Object> get _trainJson => {
        if (train.values.any((m) => m.isNotEmpty))
          'train': {
            for (final MapEntry(key: type, value: m) in train.entries)
              if (m.isNotEmpty) type: {for (final MapEntry(key: stat, value: n) in m.entries) stat.name: n},
          },
      };

  /// [j]'s `train` (a save without it: none). An unknown type or attribute is skipped and a level kept in 1 to
  /// [trainMax]. Before the troops, so they come back with their Train HP.
  void _loadTrain(Map<String, dynamic> j) {
    for (final MapEntry(:key, :value) in ((j['train'] as Map?) ?? const {}).entries) {
      if (!troopTypes.containsKey(key) || value is! Map) continue;
      final m = <TrainStat, int>{
        for (final MapEntry(key: name, value: n) in value.entries)
          if (TrainStat.values.asNameMap()[name] case final stat?)
            if (n case final int k when k > 0) stat: min(k, trainMax),
      };
      if (m.isNotEmpty) train[key as String] = m;
    }
  }
}
