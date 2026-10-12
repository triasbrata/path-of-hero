part of 'game.dart';

// The pocket items (decisions-log 332; docs/loot-items-relics.md "Pocket items", docs/ui-hud.md "The pocket bar"). The
// owner, 2026-10-12: "aku mau tambahkan user pocket item, dimana item ini bisa di pakai by kemauan user, misal botol heal
// untuk melakukan heal atau botol mana atau bisa juga item booster lain, yang nge boost troops untuk beberapa detik atau
// menit. dan di dapatkan dari forge juga tapi itemnya dibuat butuh banyak untuk 1 item"; one tap acts on every troop
// ("Ke semua troop"), four slots and a cooldown ("4 slot + cooldown"), the bottles between waves too ("Botol juga di jeda
// wave"), the costs as proposed ("Cukup"), and the kinds past his four to be judged in play ("ini aku belum tau sih"), so
// every number is town.json's `pocket` block ([PocketRules]): a kind is only its rule, and a kind dropped from the file's
// recipes is easy to drop from the game.
//
// The Smithy makes them in a Town ([Pockets.craftPocket]: many materials and a share of the Tavern's purse of the wave
// won, [PocketRules.priceOf]) into [Game.pocketStock], at most [PocketRule.cap] of a kind. The bar on the battle HUD
// holds a kind a slot ([Game.pocketSlots]: a kind made for the first time takes the first empty slot, the Bag's Pocket
// chip puts one in or takes it out); a tap on a slot ([Pockets.usePocket]) uses one on the whole army or on every
// monster on the field, in a wave (a [PocketRule.between] kind between waves too), never paused nor in a Town, and starts
// that kind's [PocketRule.cooldown]. What a kind does is the sum of its rule's effects, in this order: a heal through the
// troop funnel ([HealSrc.pocket]), MP, a cleanse and a ward for [PocketRule.time] s, the skills ready, a boost for
// [PocketRule.time] s fed into the Tavern's step ([Tavern._boostStats], its caps), a slow on every monster, a blow on
// every monster ([Hit.pocket]). Only the player uses them: no probe, policy or auto-player does.

/// How many slots the battle HUD's pocket bar has (the owner's "4 slot").
const pocketSlotCount = 4;

/// A pocket item's kind: its name is its save key, its town.json key (`pocket.kinds.<name>`) and its icon's
/// (`pocket_<name>.png`); a new one is only ever appended.
enum PocketKind { healBottle, manaBottle, rageTonic, ironDraught, frostBomb, fireBomb, holyWater, pocketWatch }

/// The kinds' names as the player reads them.
const pocketNames = {
  PocketKind.healBottle: 'Heal Bottle', // the owner's: a heal
  PocketKind.manaBottle: 'Mana Bottle', // the owner's: MP
  PocketKind.rageTonic: 'Rage Tonic', // the owner's booster: attack and speed
  PocketKind.ironDraught: 'Iron Draught', // the owner's booster: defence
  PocketKind.frostBomb: 'Frost Bomb', // the dynamic ones (decisions-log 332)
  PocketKind.fireBomb: 'Fire Bomb',
  PocketKind.holyWater: 'Holy Water',
  PocketKind.pocketWatch: 'Pocket Watch',
};

/// The burst each kind's use draws on whom it touches (the troops', or the monsters' for a bomb): the field's own sheets
/// (tiny_fx_heal, fx_upgrade, tiny_fx_holy, the wizard's shards and fireball).
const pocketFx = {
  PocketKind.healBottle: 'heal',
  PocketKind.manaBottle: 'upgrade',
  PocketKind.rageTonic: 'upgrade',
  PocketKind.ironDraught: 'upgrade',
  PocketKind.frostBomb: 'shards',
  PocketKind.fireBomb: 'fireball',
  PocketKind.holyWater: 'holy',
  PocketKind.pocketWatch: 'upgrade',
};

/// One kind's rule (town.json `pocket.kinds.<kind>`): what one use does, how often and how many, and its recipe.
/// - [heal]: every troop heals this share of its max HP; [mp]: every troop with MP gets this share of its max MP.
/// - [cleanse]: every troop's bad effects end ([Cleanse.cleanse]) and none takes hold for [time] s.
/// - [ready]: every troop's skills are ready now (its #10, awakening and Hero skill; their MP still pays).
/// - [dmg], [rate], [taken]: every troop's damage (a healer's heal), attack speed and damage taken × for [time] s: a boost
///   beside the Tavern's, under the same caps ([BoostMost]).
/// - [slow]: every monster on the field walks and attacks × this for [time] s; a boss or a mini boss [bossSlow].
/// - [hit]: every monster on the field loses this share of its max HP (a boss or a mini boss [bossHit]).
/// - [cooldown]: seconds before the kind can be used again; [cap]: the most of it the Bag holds; [between]: it works
///   between waves too (the bottles).
/// - [materials] and [k]: its recipe, the materials and the gold in the Tavern's purses of the wave won
///   ([PocketRules.priceOf]).
class PocketRule {
  const PocketRule(
      {this.heal = 0,
      this.mp = 0,
      this.cleanse = false,
      this.ready = false,
      this.dmg = 1,
      this.rate = 1,
      this.taken = 1,
      this.slow = 1,
      this.bossSlow = 1,
      this.hit = 0,
      this.bossHit = 0,
      this.time = 0,
      required this.cooldown,
      required this.cap,
      this.between = false,
      this.materials = const {},
      required this.k});

  final double heal, mp, dmg, rate, taken, slow, bossSlow, hit, bossHit, time, cooldown, k;
  final bool cleanse, ready, between;
  final int cap;
  final Map<Mat, int> materials;

  /// A boost on the troops while it lasts.
  bool get boosts => dmg != 1 || rate != 1 || taken != 1;

  /// What it does, by the file's names, only what isn't its default: the file's, the event's and the texts' shape.
  Map<String, num> get effects => {
        if (heal > 0) 'heal': heal,
        if (mp > 0) 'mp': mp,
        if (cleanse) 'cleanse': 1,
        if (ready) 'ready': 1,
        if (dmg != 1) 'dmg': dmg,
        if (rate != 1) 'rate': rate,
        if (taken != 1) 'taken': taken,
        if (slow != 1) 'slow': slow,
        if (bossSlow != 1) 'bossSlow': bossSlow,
        if (hit > 0) 'hit': hit,
        if (bossHit > 0) 'bossHit': bossHit,
      };

  /// [j]'s rule, each field only when of the right kind and in range (a share 0 to 1, a multiplier above 0, a time not
  /// negative, a cap at least 1), else [d]'s; a material it doesn't know is noted in [skipped].
  factory PocketRule.fromJson(Map<String, dynamic> j, PocketRule d, List<String> skipped, String where) {
    double share(String key, double def) => switch (j[key]) { final num v when v >= 0 && v <= 1 => v.toDouble(), _ => def };
    double times(String key, double def) => switch (j[key]) { final num v when v > 0 && v.isFinite => v.toDouble(), _ => def };
    double secs(String key, double def) => switch (j[key]) { final num v when v >= 0 && v.isFinite => v.toDouble(), _ => def };
    bool flag(String key, bool def) => switch (j[key]) { final bool b => b, _ => def };
    return PocketRule(
      heal: share('heal', d.heal),
      mp: share('mp', d.mp),
      cleanse: flag('cleanse', d.cleanse),
      ready: flag('ready', d.ready),
      dmg: times('dmg', d.dmg),
      rate: times('rate', d.rate),
      taken: times('taken', d.taken),
      slow: times('slow', d.slow),
      bossSlow: times('bossSlow', d.bossSlow),
      hit: share('hit', d.hit),
      bossHit: share('bossHit', d.bossHit),
      time: secs('time', d.time),
      cooldown: secs('cooldown', d.cooldown),
      cap: switch (j['cap']) { final int n when n >= 1 => n, _ => d.cap },
      between: flag('between', d.between),
      materials: switch (j['materials']) { final Map<String, dynamic> m => _matCounts(m, skipped, '$where.materials'), _ => d.materials },
      k: secs('k', d.k),
    );
  }

  Map<String, dynamic> toJson() => {
        for (final MapEntry(:key, :value) in effects.entries) key: key == 'cleanse' || key == 'ready' ? true : value,
        if (time > 0) 'time': time,
        'cooldown': cooldown,
        'cap': cap,
        if (between) 'between': true,
        'materials': _matJson(materials),
        'k': k,
      };
}

/// The pocket items' numbers (town.json `pocket`, decisions-log 332): what the Shop pays for one ([sell]: a share of its
/// worth, the materials' sell prices and its gold now: always a loss, so no buy-craft-sell loop; never the market's), the
/// least gold a recipe asks ([least]), and every kind's rule ([kinds]). The gold is rounded the Tavern's way
/// ([TavernRules.rounded]).
class PocketRules {
  const PocketRules({this.sell = 0.5, this.least = 50, this.kinds = _pocketKinds});

  final double sell;
  final int least;
  final Map<PocketKind, PocketRule> kinds;

  /// [j]'s numbers, each only when of the right kind and in range (else its default); a name it doesn't know (a key of the
  /// block, a kind) is left out and noted in [skipped].
  factory PocketRules.fromJson(Map<String, dynamic> j, List<String> skipped) {
    const d = PocketRules();
    final kinds = switch (j['kinds']) { final Map<String, dynamic> m => m, _ => const <String, dynamic>{} };
    skipped
      ..addAll([for (final k in j.keys) if (!d.toJson().containsKey(k)) 'pocket: no $k'])
      ..addAll([for (final k in kinds.keys) if (!PocketKind.values.asNameMap().containsKey(k)) 'pocket.kinds: no $k']);
    return PocketRules(
      sell: _townShare(j['sell'], d.sell),
      least: switch (j['least']) { final int n when n >= 0 => n, _ => d.least },
      kinds: {
        for (final MapEntry(key: p, value: def) in d.kinds.entries)
          p: switch (kinds[p.name]) { final Map<String, dynamic> v => PocketRule.fromJson(v, def, skipped, 'pocket.kinds.${p.name}'), _ => def },
      },
    );
  }

  /// The gold one [kind] asks at wave [wave] (the wave won): its [PocketRule.k] of the Tavern's purse ([TavernRules.purseAt],
  /// from wave 1), rounded the Tavern's way, at least [least].
  int priceOf(PocketKind kind, int wave, TavernRules tavern) => max(least, tavern.rounded(kinds[kind]!.k * tavern.purseAt(max(1, wave))));

  Map<String, dynamic> toJson() => {
        'sell': sell,
        'least': least,
        'kinds': {for (final MapEntry(:key, :value) in kinds.entries) key.name: value.toJson()},
      };
}

/// The shipped kinds (assets/config/town.json writes each one out): 13-16 materials each where an item takes 3-4 (the
/// owner's "butuh banyak untuk 1 item"), a Rare part in the stronger ones and a Trophy in the Pocket Watch.
const _pocketKinds = {
  PocketKind.healBottle: PocketRule(
      heal: 0.35, cooldown: 30, cap: 5, between: true, materials: {Mat.slimeGel: 8, Mat.tealCloth: 4, Mat.batWing: 4}, k: 0.05),
  PocketKind.manaBottle: PocketRule(
      mp: 0.5, cooldown: 30, cap: 5, between: true, materials: {Mat.tealCloth: 6, Mat.batWing: 6, Mat.batFang: 1}, k: 0.05),
  PocketKind.rageTonic: PocketRule(
      dmg: 1.25, rate: 1.15, time: 15, cooldown: 60, cap: 3, materials: {Mat.orcTooth: 8, Mat.wolfClaw: 4, Mat.orcHeart: 1}, k: 0.08),
  PocketKind.ironDraught: PocketRule(
      taken: 0.7, time: 15, cooldown: 60, cap: 3, materials: {Mat.boneShard: 8, Mat.rustyPlate: 4, Mat.ironTusk: 1}, k: 0.08),
  PocketKind.frostBomb: PocketRule(
      slow: 0.6, bossSlow: 0.8, time: 6, cooldown: 45, cap: 3, materials: {Mat.boneArrow: 6, Mat.batWing: 6, Mat.boneBow: 1}, k: 0.08),
  PocketKind.fireBomb: PocketRule(
      hit: 0.08, bossHit: 0.02, cooldown: 45, cap: 3, materials: {Mat.orcEar: 6, Mat.leatherStrap: 6, Mat.wargFang: 1}, k: 0.08),
  PocketKind.holyWater: PocketRule(
      cleanse: true, time: 5, cooldown: 45, cap: 3, materials: {Mat.tealCloth: 8, Mat.bigBone: 4, Mat.tealGem: 1}, k: 0.08),
  PocketKind.pocketWatch: PocketRule(
      ready: true, cooldown: 90, cap: 2, materials: {Mat.bearFur: 6, Mat.ironScrap: 6, Mat.evilEye: 1}, k: 0.12),
};

/// What a kind of [rule] does, one short line each, as the player reads it: "Every troop heals 35% of its HP.", "Every
/// troop for 15 s: +25% damage, +15% attack speed.", "Every monster loses 8% of its HP (bosses 2%).".
List<String> pocketEffectLines(PocketRule rule) {
  String secs(double s) => '${s == s.roundToDouble() ? s.round() : s} s';
  String boss(double all, double bosses) => bosses > 0 && bosses != all ? ' (bosses ${_percent(bosses)}%)' : '';
  final boost = boostEffectLines({if (rule.dmg != 1) 'dmg': rule.dmg, if (rule.rate != 1) 'rate': rule.rate, if (rule.taken != 1) 'taken': rule.taken});
  return [
    if (rule.heal > 0) 'Every troop heals ${_percent(rule.heal)}% of its HP.',
    if (rule.mp > 0) 'Every troop gets ${_percent(rule.mp)}% of its MP.',
    if (rule.cleanse) "Ends every troop's bad effects; none take hold for ${secs(rule.time)}.",
    if (rule.ready) "Every troop's skills are ready now (MP still pays).",
    if (boost.isNotEmpty) 'Every troop for ${secs(rule.time)}: ${boost.join(', ')}.',
    if (rule.slow != 1)
      'Every monster walks and attacks ${_percent(1 - rule.slow)}% slower for ${secs(rule.time)}'
          '${rule.bossSlow != 1 && rule.bossSlow != rule.slow ? ' (bosses ${_percent(1 - rule.bossSlow)}%)' : ''}.',
    if (rule.hit > 0) 'Every monster loses ${_percent(rule.hit)}% of its HP${boss(rule.hit, rule.bossHit)}.',
  ];
}

/// Why a pocket slot can't be used now ([Pockets.whyNotUsePocket]): the game is over, paused, in a Town, the slot empty,
/// none of its kind left, not in a wave (a kind that works only in one), its cooldown running, or nobody it would help
/// (no troop hurt, none short of MP, no monster on the field).
enum PocketWhy { over, paused, asked, town, empty, none, wave, cooling, hurt, mp, foes }

/// A running pocket boost ([PocketRule.boosts]): its [kind] and the game time it ends at. Not saved: a save is between
/// waves, and a wave's end ends them.
class PocketBoost {
  PocketBoost(this.kind, this.until);

  final PocketKind kind;
  double until;
}

/// The pocket on [Game] (the fields are the class's: [Game.pocketStock], [Game.pocketSlots], ...).
extension Pockets on Game {
  /// [kind]'s rule as this game reads it.
  PocketRule pocketRule(PocketKind kind) => townRules.pocket.kinds[kind]!;

  /// How many [kind] the Bag holds.
  int pocketHeld(PocketKind kind) => pocketStock[kind] ?? 0;

  /// The seconds before [kind] can be used again (0: ready), and the share of its cooldown still to run (0 to 1).
  double pocketCoolLeft(PocketKind kind) => max(0, (pocketReady[kind] ?? double.negativeInfinity) - t);
  double pocketCoolShare(PocketKind kind) {
    final cd = pocketRule(kind).cooldown;
    return cd <= 0 ? 0 : min(1, pocketCoolLeft(kind) / cd);
  }

  /// The pocket boost of [kind] running, or null.
  PocketBoost? pocketBoostOf(PocketKind kind) => pocketBoosts.where((b) => b.kind == kind).firstOrNull;

  /// Why slot [slot] can't be used now, or null, in this order: the game over, paused, a wipe's choice waiting ([Game.wipeAsk],
  /// decisions-log 333: its dialog over everything), in a Town, an empty slot, none of
  /// its kind left, not in a wave (a kind not [PocketRule.between]), its cooldown, and nobody it would act on: a kind
  /// that only heals with every troop at full HP, one that only gives MP with none short, one that only acts on monsters
  /// with none on the field.
  PocketWhy? whyNotUsePocket(int slot) {
    if (over) return PocketWhy.over;
    if (paused) return PocketWhy.paused;
    if (wipeAsk) return PocketWhy.asked;
    if (inTown) return PocketWhy.town;
    final kind = slot >= 0 && slot < pocketSlots.length ? pocketSlots[slot] : null;
    if (kind == null) return PocketWhy.empty;
    if (pocketHeld(kind) <= 0) return PocketWhy.none;
    final rule = pocketRule(kind);
    if (!waveActive && !rule.between) return PocketWhy.wave;
    if (pocketCoolLeft(kind) > 0) return PocketWhy.cooling;
    return _pocketIdle(rule);
  }

  /// Why [rule] would do nothing now, or null: it only heals (and every living troop is at full HP), only gives MP (and
  /// none is short), or only acts on monsters (and none is on the field). A cleanse, the skills, a boost always act.
  PocketWhy? _pocketIdle(PocketRule rule) {
    if (rule.cleanse || rule.ready || rule.boosts) return null;
    final living = [for (final u in troops) if (u.alive) u];
    if (rule.heal > 0 && living.any((u) => u.hp < u.maxHp)) return null;
    if (rule.mp > 0 && living.any((u) => u.stats.mp > 0 && u.mp < u.stats.mp)) return null;
    if ((rule.hit > 0 || rule.slow != 1) && _pocketFoes.isNotEmpty) return null;
    if (rule.heal > 0) return PocketWhy.hurt;
    if (rule.mp > 0) return PocketWhy.mp;
    return PocketWhy.foes;
  }

  /// The monsters a pocket item acts on: every one alive that has come onto the field.
  List<Unit> get _pocketFoes => [for (final u in enemies) if (u.alive && u.entered) u];

  /// Uses one of slot [slot]'s kind ([whyNotUsePocket]) on every troop alive, or on every monster on the field: its
  /// effects in [PocketRule]'s order, one fewer in the Bag, its cooldown started, its burst on whom it touched, and
  /// [PocketUsed]. False (and [Sfx.error]) when it can't.
  bool usePocket(int slot) {
    if (whyNotUsePocket(slot) != null) {
      sfx.add(Sfx.error);
      return false;
    }
    final kind = pocketSlots[slot]!, rule = pocketRule(kind), fx = pocketFx[kind]!;
    final living = [for (final u in troops) if (u.alive) u], foes = rule.hit > 0 || rule.slow != 1 ? _pocketFoes : const <Unit>[];
    var (hp, mp, cleansed, killed) = (0.0, 0.0, 0, 0);
    for (final u in living) {
      if (rule.heal > 0 && u.hp < u.maxHp) {
        final before = u.hp;
        _healTroop(u, u.maxHp * rule.heal, HealSrc.pocket);
        hp += u.hp - before;
      }
      if (rule.mp > 0 && u.stats.mp > 0) {
        final before = u.mp;
        u.mp = min(u.stats.mp.toDouble(), u.mp + u.stats.mp * rule.mp);
        mp += u.mp - before;
      }
      if (rule.cleanse) cleansed += cleanse(u);
      if (rule.ready) {
        u
          ..skillAt = double.negativeInfinity // its #10 skill
          ..awakenSkillAt = double.negativeInfinity // its awakening skill (awaken_skills.dart)
          ..heroSkillAt = double.negativeInfinity; // a Hero's own (hero_skills.dart)
      }
      impacts.add((u.pos, fx));
    }
    if (rule.cleanse) pocketWardUntil = max(pocketWardUntil, t + rule.time);
    if (rule.boosts && rule.time > 0) {
      if (pocketBoostOf(kind) case final b?) {
        b.until = t + rule.time; // a second use renews it, never stacks
      } else {
        pocketBoosts.add(PocketBoost(kind, t + rule.time));
      }
      _refitTroops(); // the living troops take it now, as a Tavern boost
    }
    for (final m in foes) {
      final big = m.tier == Tier.boss || m.tier == Tier.miniBoss;
      if (rule.slow != 1) {
        final k = big ? rule.bossSlow : rule.slow;
        addEffect(m, Status.slow, rule.time, k: k);
        addEffect(m, Status.daze, rule.time, k: 1 / k); // its pause between attacks: attacks as much slower
      }
      if (rule.hit > 0) {
        _hurt(m, m.maxHp * (big ? rule.bossHit : rule.hit), Hit.pocket);
        if (!m.alive) killed++;
      }
      impacts.add((m.pos, fx));
    }
    final left = pocketHeld(kind) - 1;
    if (left > 0) {
      pocketStock[kind] = left;
    } else {
      pocketStock.remove(kind); // the last one used leaves no entry; its slot keeps the kind
    }
    pocketReady[kind] = t + rule.cooldown;
    sfx.add(foes.isNotEmpty ? Sfx.magic : Sfx.clear);
    _emit(PocketUsed(wave, t,
        pocket: kind,
        slot: slot,
        inWave: waveActive,
        troops: living.length,
        foes: foes.length,
        healed: hp.round(),
        mana: mp.round(),
        cleansed: cleansed,
        killed: killed));
    return true;
  }

  /// Every tick: the pocket boosts whose time is up end (the troops refit).
  void _pocketTick() {
    if (pocketBoosts.isEmpty) return;
    final ended = [for (final b in pocketBoosts) if (b.until <= t) b];
    if (ended.isEmpty) return;
    pocketBoosts.removeWhere(ended.contains);
    _refitTroops();
  }

  /// A wave ended (won, lost, or wiped and played again): the pocket boosts and the ward end with it. The cooldowns run on
  /// (a bottle used as a wave ends isn't ready again at once), but none is saved.
  void _pocketWaveEnd() {
    pocketWardUntil = double.negativeInfinity;
    if (pocketBoosts.isEmpty) return;
    pocketBoosts.clear();
    _refitTroops();
  }

  /// A Holy Water's ward holds now: nothing bad a monster does takes hold on a troop ([HeroSkills.addEffect], a stun).
  bool get pocketWarded => t < pocketWardUntil;

  /// [kind]'s recipe line by line, as [Craft.craftRows]: each material as the file lists it, then the gold now
  /// ([PocketRules.priceOf]).
  List<CraftRow> pocketCraftRows(PocketKind kind) => [
        for (final MapEntry(key: m, value: n) in pocketRule(kind).materials.entries) (kind: m, have: materials[m] ?? 0, need: n),
        (kind: null, have: gold, need: pocketPrice(kind)),
      ];

  /// The gold one [kind] asks now ([PocketRules.priceOf] at the wave won).
  int pocketPrice(PocketKind kind) => townRules.pocket.priceOf(kind, wave, townRules.tavern);

  /// Why [kind] can't be crafted now, or null, in [Craft.whyNotCraft]'s order: the game over, not in a Town, the Bag full
  /// of it ([PocketRule.cap]: "Full: 5/5"), then the first of its rows short.
  CraftRefusal? whyNotCraftPocket(PocketKind kind) {
    if (over) return const CraftRefusal(CraftWhy.over);
    if (!inTown) return const CraftRefusal(CraftWhy.town);
    final cap = pocketRule(kind).cap;
    if (pocketHeld(kind) >= cap) return CraftRefusal(CraftWhy.full, have: pocketHeld(kind), need: cap);
    return Craft._rowsShort(pocketCraftRows(kind));
  }

  /// [kind] can be crafted now ([whyNotCraftPocket] has nothing against it).
  bool canCraftPocket(PocketKind kind) => whyNotCraftPocket(kind) == null;

  /// Crafts one [kind] ([whyNotCraftPocket]): its materials and gold taken ([Craft._payCraft]), one more in the Bag, a kind
  /// the Bag held none of into the bar's first empty slot ([Game.pocketSlots]) unless it is in the bar already (one taken
  /// out while some are held stays out), `Sfx.clear`, and [PocketCrafted]. False
  /// (nothing changes but the error sound) when it can't.
  bool craftPocket(PocketKind kind) {
    if (whyNotCraftPocket(kind) != null) {
      sfx.add(Sfx.error);
      return false;
    }
    final mats = pocketRule(kind).materials, price = pocketPrice(kind), first = pocketHeld(kind) == 0;
    _payCraft(mats, const {}, price);
    pocketStock[kind] = pocketHeld(kind) + 1;
    if (first && !pocketSlots.contains(kind)) putInPocket(kind); // the first empty slot, if any
    sfx.add(Sfx.clear);
    _emit(PocketCrafted(wave, t, pocket: kind, materials: mats, gold: price));
    return true;
  }

  /// Puts [kind] in the bar's slot [slot] (by default the first empty one): a kind is in one slot at most, so from another
  /// slot it moves; what was in [slot] leaves the bar (it stays in the Bag). False when there is no such slot (or no empty
  /// one).
  bool putInPocket(PocketKind kind, [int? slot]) {
    final at = slot ?? pocketSlots.indexOf(null);
    if (at < 0 || at >= pocketSlots.length) return false;
    final was = pocketSlots.indexOf(kind);
    if (was >= 0) pocketSlots[was] = null;
    pocketSlots[at] = kind;
    return true;
  }

  /// Takes [kind] out of the bar (it stays in the Bag). False when it isn't in it.
  bool takeOutOfPocket(PocketKind kind) {
    final at = pocketSlots.indexOf(kind);
    if (at < 0) return false;
    pocketSlots[at] = null;
    return true;
  }

  /// Why slot [slot] can't be used now, in the player's words ([whyNotUsePocket]): "Ready in 12 s", "No one is hurt", ...;
  /// null when it can.
  String? pocketWhyText(int slot) => switch (whyNotUsePocket(slot)) {
        null => null,
        PocketWhy.over => Words.gameOver,
        PocketWhy.paused => Words.paused,
        PocketWhy.asked => '${Words.tryAgain} or ${Words.giveUp} first',
        PocketWhy.town => Words.notInTown,
        PocketWhy.empty => Words.pocketEmpty,
        PocketWhy.none => Words.noneLeft,
        PocketWhy.wave => Words.onlyInWave,
        PocketWhy.cooling => '${Words.readyIn} ${pocketCoolLeft(pocketSlots[slot]!).ceil()} s',
        PocketWhy.hurt => Words.noOneHurt,
        PocketWhy.mp => Words.noOneNeedsMp,
        PocketWhy.foes => Words.noMonster,
      };

  /// [kind]'s tooltip and the Bag's lines: its name; what it does ([pocketEffectLines]); when it works, its cooldown and
  /// how many the Bag holds of the most: "In a wave or between waves. Cooldown 30 s.", "In bag: 3/5.".
  (String, List<String>) pocketInfo(PocketKind kind) {
    final r = pocketRule(kind);
    String secs(double s) => '${s == s.roundToDouble() ? s.round() : s} s';
    return (
      pocketNames[kind]!,
      [
        ...pocketEffectLines(r),
        '${r.between ? 'In a wave or between waves' : Words.onlyInWave}. Cooldown ${secs(r.cooldown)}.',
        'In ${Words.bag.toLowerCase()}: ${pocketHeld(kind)}/${r.cap}.',
      ],
    );
  }

  /// The pocket bar's slot [slot] tooltip (decisions-log 332): its kind's [pocketInfo], with why it can't be used now
  /// first after what it does ("Ready in 12 s", "None left: craft more at the Smithy"), and its key on the desktop
  /// ("Key: 1", with [keys]); an empty slot's "Empty: put one in from the Bag".
  (String, List<String>) pocketSlotTip(int slot, {bool keys = true}) {
    final kind = pocketSlots[slot], key = keys ? 'Key: ${slot + 1}' : null;
    if (kind == null) return ('${Words.pocket} ${slot + 1}', [Words.pocketEmpty, ?key]);
    final (title, lines) = pocketInfo(kind);
    final effects = pocketEffectLines(pocketRule(kind)).length;
    final why = switch (whyNotUsePocket(slot)) { PocketWhy.cooling || PocketWhy.none => pocketWhyText(slot), _ => null };
    return (title, [...lines.take(effects), ?why, ...lines.skip(effects), ?key]);
  }

  /// A running pocket boost's chip tooltip ([Game.pocketBoosts]'s [i]): "Rage Tonic: 12 s left" and what it does.
  (String, List<String>) pocketBoostTip(int i) {
    final b = pocketBoosts[i];
    return ('${pocketNames[b.kind]}: ${max(0, b.until - t).ceil()} s left', pocketEffectLines(pocketRule(b.kind)));
  }

  /// What the Shop pays for one [kind] ([Store.sellPrice]): [PocketRules.sell] of its worth now, its materials at their
  /// sell prices and its gold ([pocketPrice]), rounded; never the market's.
  int pocketSellPrice(PocketKind kind) {
    final worth = pocketRule(kind).materials.entries.fold(pocketPrice(kind), (a, e) => a + (townRules.materials[e.key]?.sell ?? 0) * e.value);
    return (worth * townRules.pocket.sell).round();
  }

  /// The save's `pocket`, only while the Bag holds one or a slot is set: `{"slots": [kind or null, ...], "stock": {kind:
  /// n}}`.
  Map<String, Object> get _pocketJson => {
        if (pocketStock.isNotEmpty || pocketSlots.any((k) => k != null))
          'pocket': {
            'slots': [for (final k in pocketSlots) k?.name],
            'stock': {for (final MapEntry(:key, :value) in pocketStock.entries) key.name: value},
          },
      };

  /// [j]'s `pocket` ([Game.fromJson]): the stock (an unknown kind or a count under 1 skipped, a count over its cap cut to
  /// it) and the slots (an unknown kind, a kind twice or a slot past the bar's skipped). None in a save from before it.
  void _loadPocket(Map<String, dynamic> j) {
    final p = j['pocket'];
    if (p is! Map) return;
    for (final MapEntry(:key, :value) in ((p['stock'] as Map?) ?? const {}).entries) {
      if ((PocketKind.values.asNameMap()[key], value) case (final k?, final int n) when n > 0) pocketStock[k] = min(n, pocketRule(k).cap);
    }
    for (final (i, name) in ((p['slots'] as List?) ?? const []).indexed) {
      if (i >= pocketSlots.length) break;
      if (PocketKind.values.asNameMap()[name] case final k? when !pocketSlots.contains(k)) pocketSlots[i] = k;
    }
  }
}
