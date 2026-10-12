part of 'game.dart';

// The game's events (issue #60; the owner: "perlu di tambahkan fitur log dimana user bisa liat hal hal
// penting ..."): one typed stream, fed from where things happen in [Game]. [Game.log] keeps the last
// [logSize] as a ring buffer (the battle log shows them, lib/battle_log.dart), and every listener in
// [Game.listeners] gets each one as it happens: the telemetry (#64, lib/telemetry.dart) subscribes there and
// sends [toJson]. The listeners also get the [TraceEvent]s, which the log never keeps. Not saved: a loaded
// game starts with an empty log.

/// The events' JSON shape ([GameEvent.toJson]): raise it when a field changes, for the telemetry. 2: a fall's relics,
/// a wave start's Pusaka, the Pusaka events (decisions-log 138). 3: the boss chest's (decisions-log 152). 4: Asah's
/// [PusakaAsah] (decisions-log 154). 5: a recall's swap, [HeroRecalled.refund] (decisions-log 167). 6: Tempa's [Tempered]
/// (decisions-log 163). 7: Lebur's [PusakaLebur] (decisions-log 164). 8: the Bayangan's ([OmenGained], [OmenEased],
/// [OfferShown.omens], [OfferPicked.omen] / [OfferPicked.levels] / [OfferPicked.skipBuff], [WaveStarted.omens];
/// decisions-log 180) and Ukir's ([UkirFed] and [UkirStep], an Asah's [PusakaAsah.items] and a wave start's Pusaka
/// with their Ukir; decisions-log 183). While [omensOn] is off no Bayangan field is written. 9: the Towns' ([TownMarked],
/// [TownEntered], [TownLeft], [TownRolled]; decisions-log 216), and the Smithy's [Crafted] with [TownLeft.crafts] and
/// [TownLeft.craftSpent] (decisions-log 233), in every game (decisions-log 321). [OmenDusk] (decisions-log 239) came without
/// a raise: like every Bayangan event it is sent only while [omensOn] is on, which no player's game has yet. The Tavern's
/// ([BoostBought], [BoostEnded], [BoostSaved], [TavernRerolled], [TownLeft.tavern], [WaveStarted.boosts]; decisions-log
/// 266) came without a raise too: only a game with the Tavern's switch on had them, which no player's game had yet. 10: the
/// forge's ([ItemCrafted], [StoneCrafted], [ItemEnhanced]; decisions-log 249, 255), sent in every board game since the
/// forge's cut-over (decisions-log 272), in every game since decisions-log 321. 11: the Tavern switched on
/// (decisions-log 268): the Tavern's (its own switch is gone, decisions-log 296). 12: the Bayangan switched on
/// (decisions-log 319): their events and fields (8's, [OmenDusk]) reach every player's records; `--dart-define=OMENS=false`
/// (tests only) sends none. 13: an army wiped mid-wave no longer ends the game ([Wiped]; decisions-log 322). 14: the
/// Towns' market and identities ([StoreSold] margin and pressure, [TownEntered] n and identity; decisions-log 326). 15: a
/// Tavern boost's length is its offer's ([BoostBought.waves] 2 to 4, or 0 with [BoostBought.untilTown]; decisions-log 331).
/// 16: the pocket items ([PocketUsed], [PocketCrafted], [WaveStarted.pocket]; decisions-log 332).
const eventVersion = 16;

/// How many events [Game.log] keeps, the oldest going first.
const logSize = 200;

/// What an event is about. The twelve from waveStarted to pusakaMoved are [TraceEvent]s, for the telemetry only, and so
/// are offerShown, offerRerolled, ukirFed, ukirStep, townRolled and tavernRerolled.
enum EventKind {
  fell, skill, heroSkill, awakenSkill, strongFoe, monsterSkill, heroMade, awakened, waveWon, waveLost, //
  waveStarted, spawned, bought, itemUsed, relicUsed, marched, storeBought, storeSold,
  relicTakenOff, typeReleased, pusakaBound, pusakaMoved,
  ascended, heroRecalled, grailSaved, pusakaReport,
  offerPicked, offerShown, offerRerolled,
  pusakaAsah,
  tempa,
  pusakaLebur,
  omenGained, omenEased, omenDusk,
  ukirFed, ukirStep,
  townMarked, townEntered, townLeft, townRolled,
  crafted,
  itemCrafted,
  stoneCrafted, itemEnhanced, // Enhance (decisions-log 255)
  boostBought, boostEnded, boostSaved, tavernRerolled, // the Tavern (decisions-log 266)
  wipe, // an army wiped mid-wave: a heart lost, the wave played again (decisions-log 322)
  pocketUsed, pocketCrafted, // the pocket items (decisions-log 332)
}

/// Something that happened, in wave [wave] at game time [t].
sealed class GameEvent {
  GameEvent(this.wave, this.t);

  final int wave;
  final double t;

  EventKind get kind;

  /// This event's own fields, for [toJson].
  Map<String, Object?> get data;

  /// The event as the telemetry sends it: [eventVersion], its [kind], wave, time and its own fields.
  Map<String, Object?> toJson() => {'v': eventVersion, 'kind': kind.name, 'wave': wave, 't': t, ...data};
}

/// A troop fell: its [name] and [type], whether it was a Hero, the monster that dealt the blow ([killer] and its
/// [killerTier]; none when nothing struck it), and the small [relics] it held, back in the bag now.
final class TroopFell extends GameEvent {
  TroopFell(super.wave, super.t,
      {required this.name, required this.type, this.hero = false, this.killer, this.killerTier, this.relics = const []});

  final String name, type;
  final bool hero;
  final String? killer;
  final Tier? killerTier;
  final List<Relic> relics;

  @override
  EventKind get kind => EventKind.fell;

  @override
  Map<String, Object?> get data => {
        'name': name, 'type': type, 'hero': hero, 'killer': killer, 'killerTier': killerTier?.name,
        'relics': [for (final r in relics) r.name],
      };
}

/// A troop cast its type's skill ([troopSkills], #10).
final class SkillCast extends GameEvent {
  SkillCast(super.wave, super.t, {required this.name, required this.type, required this.skill});

  final String name, type, skill;

  @override
  EventKind get kind => EventKind.skill;

  @override
  Map<String, Object?> get data => {'name': name, 'type': type, 'skill': skill};
}

/// A Hero cast its own skill ([HeroSkill], #48).
final class HeroSkillCast extends GameEvent {
  HeroSkillCast(super.wave, super.t, {required this.name, required this.type, required this.skill});

  final String name, type;
  final HeroSkill skill;

  @override
  EventKind get kind => EventKind.heroSkill;

  @override
  Map<String, Object?> get data => {'name': name, 'type': type, 'skill': skill.name};
}

/// A troop cast its type's awakening [skill] ([AwakenSkill], #88) at awakening [level].
final class AwakenSkillCast extends GameEvent {
  AwakenSkillCast(super.wave, super.t, {required this.name, required this.type, required this.skill, required this.level});

  final String name, type;
  final AwakenSkill skill;
  final int level;

  @override
  EventKind get kind => EventKind.awakenSkill;

  @override
  Map<String, Object?> get data => {'name': name, 'type': type, 'skill': skill.name, 'level': level};
}

/// A strong monster came onto the field: a high elite, a mini boss or the boss ([strongTiers]).
final class StrongFoe extends GameEvent {
  StrongFoe(super.wave, super.t, {required this.type, required this.tier});

  final String type;
  final Tier tier;

  @override
  EventKind get kind => EventKind.strongFoe;

  @override
  Map<String, Object?> get data => {'type': type, 'tier': tier.name};
}

/// The monster ranks the log names when they come in.
const strongTiers = {Tier.highElite, Tier.miniBoss, Tier.boss};

/// A monster of [type] and [tier] began its [skill] ([MonsterSkill], #59): logged at the wind-up, when its title
/// pops, whether or not a stun then cancels it.
final class MonsterSkillCast extends GameEvent {
  MonsterSkillCast(super.wave, super.t, {required this.type, required this.tier, required this.skill});

  final String type;
  final Tier tier;
  final MonsterSkill skill;

  @override
  EventKind get kind => EventKind.monsterSkill;

  @override
  Map<String, Object?> get data => {'type': type, 'tier': tier.name, 'skill': skill.name};
}

/// A troop was made a Hero ([heroEvery]), with its rolled attributes and its own skill.
final class HeroMade extends GameEvent {
  HeroMade(super.wave, super.t, {required this.name, required this.type, required this.stats, this.skill});

  final String name, type;
  final List<HeroStat> stats;
  final HeroSkill? skill;

  @override
  EventKind get kind => EventKind.heroMade;

  @override
  Map<String, Object?> get data => {'name': name, 'type': type, 'stats': [for (final s in stats) s.name], 'skill': skill?.name};
}

/// A troop type awakened to [level] ([awakenRecipe]).
final class Awakened extends GameEvent {
  Awakened(super.wave, super.t, {required this.type, required this.level});

  final String type;
  final int level;

  @override
  EventKind get kind => EventKind.awakened;

  @override
  Map<String, Object?> get data => {'type': type, 'level': level};
}

/// A troop type at Bangkit 3 bought its next [level] (4 or 5) on its Army detail for [cost] gold ([Ascend.ascend], #92 part 2).
final class Ascended extends GameEvent {
  Ascended(super.wave, super.t, {required this.type, required this.level, required this.cost});

  final String type;
  final int level, cost;

  @override
  EventKind get kind => EventKind.ascended;

  @override
  Map<String, Object?> get data => {'type': type, 'level': level, 'cost': cost};
}

/// A troop type at Bangkit 5 bought Tempa [level] on its Army detail for [cost] gold ([Tempa.temper], decisions-log 163).
final class Tempered extends GameEvent {
  Tempered(super.wave, super.t, {required this.type, required this.level, required this.cost});

  final String type;
  final int level, cost;

  @override
  EventKind get kind => EventKind.tempa;

  @override
  Map<String, Object?> get data => {'type': type, 'level': level, 'cost': cost};
}

/// Pusaka [relic] gained a star by Asah, to [stars] ([Asah.asah], pusaka.dart): bound to [type] (null: in the Gudang),
/// for [cost] gold, the small [relics] taken from the bag, by kind, and the [items] ([asahItems]: none by default).
final class PusakaAsah extends GameEvent {
  PusakaAsah(super.wave, super.t, {required this.relic, required this.stars, this.type, required this.cost, required this.relics, this.items = const {}});

  final Relic relic;
  final int stars, cost;
  final String? type;
  final Map<Relic, int> relics;
  final Map<Item, int> items;

  @override
  EventKind get kind => EventKind.pusakaAsah;

  @override
  Map<String, Object?> get data => {
        'relic': relic.name, 'stars': stars, 'type': type, 'cost': cost,
        'relics': {for (final MapEntry(:key, :value) in relics.entries) key.name: value},
        if (items.isNotEmpty) 'items': {for (final MapEntry(:key, :value) in items.entries) key.name: value},
      };
}

/// Pusaka [fodder], at [fodderStars] in the Gudang, was melted into [relic], which rose to [stars] ([Lebur.lebur],
/// pusaka.dart): [relic] bound to [type] (null: in the Gudang), for [cost] gold and the small [relics] taken from the bag,
/// by kind (none while [leburRelics] is 0). The fodder is gone.
final class PusakaLebur extends GameEvent {
  PusakaLebur(super.wave, super.t,
      {required this.fodder, required this.fodderStars, required this.relic, required this.stars, this.type, required this.cost, this.relics = const {}});

  final Relic fodder, relic;
  final int fodderStars, stars, cost;
  final String? type;
  final Map<Relic, int> relics;

  @override
  EventKind get kind => EventKind.pusakaLebur;

  @override
  Map<String, Object?> get data => {
        'fodder': fodder.name, 'fodderStars': fodderStars, 'relic': relic.name, 'stars': stars, 'type': type, 'cost': cost,
        'relics': {for (final MapEntry(:key, :value) in relics.entries) key.name: value},
      };
}

/// A boss chest ([Chest], draft.dart) was closed: a card taken ([pick] a Pusaka, now at [stars], bound to [type] or in
/// the Gudang when null; or a Serpihan, [pick] null and [serpihan]) or the chest passed over ([skipped], for [gain]
/// gold), after [rerolls] rerolls. [chest] is its kind's name ('boss', 'catchUp'), [chestWave] the wave that brought it.
/// The Bayangan (omen.dart; [levels] null while [omensOn] is off, and then no key): the face the taken card hid ([omen],
/// null: none), the kinds its levels went to, one a level ([levels]: empty with no face, or "penuh"), and whether a
/// Lewati owes the next wave the skip buff ([skipBuff]).
final class OfferPicked extends GameEvent {
  OfferPicked(super.wave, super.t,
      {this.pick,
      this.stars = 0,
      this.type,
      this.serpihan = false,
      this.skipped = false,
      this.gain = 0,
      required this.rerolls,
      required this.chest,
      required this.chestWave,
      this.omen,
      this.levels,
      this.skipBuff = false});

  final Relic? pick;
  final int stars, gain, rerolls, chestWave;
  final String? type;
  final bool serpihan, skipped, skipBuff;
  final String chest;
  final OmenKind? omen;
  final List<OmenKind>? levels;

  @override
  EventKind get kind => EventKind.offerPicked;

  @override
  Map<String, Object?> get data => {
        'pick': pick?.name ?? (serpihan ? 'serpihan' : null), 'rarity': pick?.rarity.name, 'stars': stars, 'type': type,
        'skipped': skipped, 'gain': gain, 'rerolls': rerolls, 'chest': chest, 'chestWave': chestWave,
        if (levels case final l?) ...{'omen': omen?.name, 'levels': [for (final k in l) k.name], 'skipBuff': skipBuff},
      };
}

/// The enemy gained Bayangan [omen] (omen.dart): [gained] levels, now at [level], from a chest's card taken ([from]
/// 'chest', the chest of [chestWave]), an old save's catch-up ('catchUp') or a Pusaka's Ukir star ('ukir').
final class OmenGained extends GameEvent {
  OmenGained(super.wave, super.t, {required this.omen, required this.level, required this.gained, required this.from, this.chestWave});

  final OmenKind omen;
  final int level, gained;
  final String from;
  final int? chestWave;

  @override
  EventKind get kind => EventKind.omenGained;

  @override
  Map<String, Object?> get data => {'omen': omen.name, 'level': level, 'gained': gained, 'from': from, 'chestWave': chestWave};
}

/// A won wave's falls eased Bayangan [omen] by its newest level (omen.dart), down to [level].
final class OmenEased extends GameEvent {
  OmenEased(super.wave, super.t, {required this.omen, required this.level});

  final OmenKind omen;
  final int level;

  @override
  EventKind get kind => EventKind.omenEased;

  @override
  Map<String, Object?> get data => {'omen': omen.name, 'level': level};
}

/// The Bayangan Dusk fell (omen.dart): the wave's crowd was all in [omenDuskAfter] s ago, and from now on its monsters
/// but the boss and a mini boss deal [share] more (Dusk at [level]). Once a wave, only while [omensOn] is on.
final class OmenDusk extends GameEvent {
  OmenDusk(super.wave, super.t, {required this.level, required this.share});

  final int level;
  final double share;

  @override
  EventKind get kind => EventKind.omenDusk;

  @override
  Map<String, Object?> get data => {'omen': OmenKind.dusk.name, 'level': level, 'share': share};
}

/// A fallen Hero was called back on its Army detail (Hero Gugur) for [cost] gold ([Recall.recallHero], #92 part 3), with the
/// [stats] and [skill] it fell with in wave [fell]. A full army's recall sent troop [swapped] of its type home for it,
/// paying back [refund] (decisions-log 167; null and 0 with room in the army). [swapped] is the log's: the telemetry
/// sends no troop names.
final class HeroRecalled extends GameEvent {
  HeroRecalled(super.wave, super.t,
      {required this.name,
      required this.type,
      required this.stats,
      this.skill,
      required this.fell,
      required this.cost,
      this.swapped,
      this.refund = 0});

  final String name, type;
  final List<HeroStat> stats;
  final HeroSkill? skill;
  final int fell, cost, refund;
  final String? swapped;

  @override
  EventKind get kind => EventKind.heroRecalled;

  @override
  Map<String, Object?> get data => {
        'name': name,
        'type': type,
        'stats': [for (final s in stats) s.name],
        'skill': skill?.name,
        'fell': fell,
        'cost': cost,
        'refund': refund,
      };
}

/// The Grail of Immortality ([grailK]) on troop type [type] saved its troop [name] from a killing blow (a Hero's:
/// [hero]; decisions-log 149). For the battle log; the telemetry has the saves in the wave record's `pusaka`.
final class GrailSaved extends GameEvent {
  GrailSaved(super.wave, super.t, {required this.name, required this.type, this.hero = false});

  final String name, type;
  final bool hero;

  @override
  EventKind get kind => EventKind.grailSaved;

  @override
  Map<String, Object?> get data => {'name': name, 'type': type, 'hero': hero};
}

/// What a won wave's Pusaka did (decisions-log 149), for the battle log and the "MENANG!" line ([Game.lastPusaka]):
/// each bound one's counter ([lines], [PusakaDone]), what the forge's small relics did ([relics], [RelicDone];
/// decisions-log 250), and the small relics that went back to the bag as their troops fell ([returned], by
/// kind). The telemetry has the same in the wave record's `pusaka` and `relics`.
final class PusakaReport extends GameEvent {
  PusakaReport(super.wave, super.t, {required this.lines, this.relics = const [], this.returned = const {}});

  final List<PusakaDone> lines;
  final List<RelicDone> relics;
  final Map<Relic, int> returned;

  /// The counter the "MENANG!" line names: troops kept alive first (a save's kept, [FxFamily.saves], the Grail's; or
  /// blows lived through, [FxFamily.survived], Dragon Heart's: the more of the two, a save on a tie), else the most
  /// damage or healing a Pusaka added (Dawn Star, God's Thunder, Void Eye); null when every counter is 0. MP and gold
  /// ([FxFamily.mana], [FxFamily.gold]) never weigh against damage.
  PusakaDone? get best {
    PusakaDone? lives, power;
    for (final d in lines) {
      if (d.worth <= 0) continue;
      final family = fxFamily(d.relic);
      if (family == FxFamily.mana || family == FxFamily.gold) continue;
      if (family == FxFamily.saves || family == FxFamily.survived) {
        if (lives == null || d.worth > lives.worth || (d.worth == lives.worth && family == FxFamily.saves)) lives = d;
      } else if (power == null || d.worth > power.worth) {
        power = d;
      }
    }
    return lives ?? power;
  }

  @override
  EventKind get kind => EventKind.pusakaReport;

  @override
  Map<String, Object?> get data => {
        'pusaka': {for (final d in lines) d.relic.name: {'type': d.type, 'stars': d.stars, 'uses': d.uses, 'worth': d.worth.round()}},
        if (relics.isNotEmpty) 'relics': {for (final d in relics) d.relic.name: {'uses': d.uses, 'worth': d.worth.round()}},
        'returned': {for (final MapEntry(:key, :value) in returned.entries) key.name: value},
      };
}

/// A Town was marked for [slot] (it comes before wave [slot], [Towns._rollTown]): the roll's [chance] hit, the [rolls]th
/// since the last Town (or the run's start).
final class TownMarked extends GameEvent {
  TownMarked(super.wave, super.t, {required this.slot, required this.chance, required this.rolls});

  final int slot, rolls;
  final double chance;

  @override
  EventKind get kind => EventKind.townMarked;

  @override
  Map<String, Object?> get data => {'slot': slot, 'chance': chance, 'rolls': rolls};
}

/// The player went into the Town of [slot] ([Towns.enterTown]) with [gold]; [auto]: Auto was on.
final class TownEntered extends GameEvent {
  TownEntered(super.wave, super.t, {required this.slot, required this.gold, this.auto = false, this.n = 0, this.identity = ''});

  final int slot, gold;
  final bool auto;

  /// The Town's number in the run and its identity's key (decisions-log 326, market.dart; `eventVersion` 14).
  final int n;
  final String identity;

  @override
  EventKind get kind => EventKind.townEntered;

  @override
  Map<String, Object?> get data => {'slot': slot, 'gold': gold, 'auto': auto, 'n': n, 'identity': identity};
}

/// The player left the Town of [slot] ([Towns.leaveTown]) after [secs] game seconds in it; [auto]: a probe's policy left
/// it (the player leaves by hand: Auto stopped leaving Towns in decisions-log 328). The relics crafted there ([crafts],
/// by kind) and the gold they took ([craftSpent]; [Craft.craft], decisions-log 233). The Tavern's visit ([tavern]: the
/// kinds of its last roll, the kinds bought, the rerolls, the gold spent; tavern.dart, decisions-log 266), null without
/// the Tavern (no key).
final class TownLeft extends GameEvent {
  TownLeft(super.wave, super.t,
      {required this.slot, required this.secs, this.auto = false, this.crafts = const {}, this.craftSpent = 0, this.tavern});

  final int slot, craftSpent;
  final double secs;
  final bool auto;
  final Map<Relic, int> crafts;
  final Map<String, Object>? tavern;

  @override
  EventKind get kind => EventKind.townLeft;

  @override
  Map<String, Object?> get data => {
        'slot': slot, 'secs': secs, 'auto': auto,
        'crafts': {for (final MapEntry(:key, :value) in crafts.entries) key.name: value}, 'craftSpent': craftSpent,
        'tavern': ?tavern,
      };
}

/// A Tavern boost was bought ([Tavern.buyBoost], decisions-log 266): its kind ([boost]) and [rarity], the [price], the
/// [waves] it runs (0 for one [untilTown], which runs until the next Town; decisions-log 331), the [type] it works on (a
/// one-type kind's), the offer's [slot], and what it multiplies ([effects], [BoostRule.effects]: its own numbers, for the
/// log's line and the telemetry).
final class BoostBought extends GameEvent {
  BoostBought(super.wave, super.t,
      {required this.boost,
      required this.rarity,
      required this.price,
      required this.waves,
      this.untilTown = false,
      this.type,
      required this.slot,
      this.effects = const {}});

  final Boost boost;
  final Rarity rarity;
  final int price, waves, slot;
  final bool untilTown;
  final String? type;
  final Map<String, num> effects;

  @override
  EventKind get kind => EventKind.boostBought;

  @override
  Map<String, Object?> get data => {
        'boost': boost.name, 'rarity': rarityKeys[rarity], 'price': price, 'waves': waves, if (untilTown) 'untilTown': true, //
        'type': ?type, 'slot': slot, 'effects': effects,
      };
}

/// A Tavern boost ran its waves out ([Tavern._boostWaveEnd]): its kind and the [type] it worked on.
final class BoostEnded extends GameEvent {
  BoostEnded(super.wave, super.t, {required this.boost, this.type});

  final Boost boost;
  final String? type;

  @override
  EventKind get kind => EventKind.boostEnded;

  @override
  Map<String, Object?> get data => {'boost': boost.name, 'type': ?type};
}

/// A pocket item was used ([Pockets.usePocket], decisions-log 332): its kind ([pocket]), the bar's [slot], whether in a wave
/// ([inWave]; a bottle works between waves too), the troops alive and the monsters on the field it acted on ([troops],
/// [foes]: 0 for a kind that acts on none), the HP and MP it gave ([healed], [mana]), the bad effects it ended
/// ([cleansed]) and the monsters it killed ([killed]).
final class PocketUsed extends GameEvent {
  PocketUsed(super.wave, super.t,
      {required this.pocket,
      required this.slot,
      required this.inWave,
      this.troops = 0,
      this.foes = 0,
      this.healed = 0,
      this.mana = 0,
      this.cleansed = 0,
      this.killed = 0});

  final PocketKind pocket;
  final int slot, troops, foes, healed, mana, cleansed, killed;
  final bool inWave;

  @override
  EventKind get kind => EventKind.pocketUsed;

  @override
  Map<String, Object?> get data => {
        'pocket': pocket.name, 'slot': slot, 'inWave': inWave, 'troops': troops, 'foes': foes, //
        'healed': healed, 'mana': mana, 'cleansed': cleansed, 'killed': killed,
      };
}

/// A pocket item was made at a Town's Smithy ([Pockets.craftPocket], decisions-log 332): its kind ([pocket]), the
/// [materials] and the [gold] it took.
final class PocketCrafted extends GameEvent {
  PocketCrafted(super.wave, super.t, {required this.pocket, required this.materials, required this.gold});

  final PocketKind pocket;
  final Map<Mat, int> materials;
  final int gold;

  @override
  EventKind get kind => EventKind.pocketCrafted;

  @override
  Map<String, Object?> get data => {'pocket': pocket.name, 'materials': _matJson(materials), 'gold': gold};
}

/// A Tavern boost forgave a monster crossing the back line: no life lost ([Tavern._boostLeak]; Watchman's Brew).
final class BoostSaved extends GameEvent {
  BoostSaved(super.wave, super.t, {required this.boost});

  final Boost boost;

  @override
  EventKind get kind => EventKind.boostSaved;

  @override
  Map<String, Object?> get data => {'boost': boost.name};
}

/// Small relic [relic] was crafted at the Smithy ([Craft.craft], decisions-log 233) from its recipe: the [materials] and
/// [items] it took, by kind, and the [gold].
final class Crafted extends GameEvent {
  Crafted(super.wave, super.t, {required this.relic, required this.materials, this.items = const {}, required this.gold});

  final Relic relic;
  final Map<Mat, int> materials;
  final Map<Item, int> items;
  final int gold;

  @override
  EventKind get kind => EventKind.crafted;

  @override
  Map<String, Object?> get data => {
        'relic': relic.name,
        'materials': _matJson(materials),
        'items': {for (final MapEntry(:key, :value) in items.entries) key.name: value},
        'gold': gold,
      };
}

/// An item made at a Town's Smithy (town.dart's [Craft.craftItem], decisions-log 249): what it took.
final class ItemCrafted extends GameEvent {
  ItemCrafted(super.wave, super.t, {required this.item, required this.materials, this.items = const {}, required this.gold});

  final Item item;
  final Map<Mat, int> materials;
  final Map<Item, int> items;
  final int gold;

  @override
  EventKind get kind => EventKind.itemCrafted;

  @override
  Map<String, Object?> get data => {
        'item': item.name,
        'materials': _matJson(materials),
        'items': {for (final MapEntry(:key, :value) in items.entries) key.name: value},
        'gold': gold,
      };
}

/// A forge stone made at a Town's Smithy (enhance.dart's [Enhance.craftStone], decisions-log 255; only with the forge
/// on): what it took.
final class StoneCrafted extends GameEvent {
  StoneCrafted(super.wave, super.t, {required this.stone, required this.materials, required this.gold});

  final Mat stone;
  final Map<Mat, int> materials;
  final int gold;

  @override
  EventKind get kind => EventKind.stoneCrafted;

  @override
  Map<String, Object?> get data => {'stone': stone.name, 'materials': _matJson(materials), 'gold': gold};
}

/// An item in the Bag taken one step up at a Town's Smithy (enhance.dart's [Enhance.enhance], decisions-log 255): now at
/// +[plus], for one [stone] and the [gold].
final class ItemEnhanced extends GameEvent {
  ItemEnhanced(super.wave, super.t, {required this.item, required this.plus, required this.stone, required this.gold});

  final Item item;
  final int plus;
  final Mat stone;
  final int gold;

  @override
  EventKind get kind => EventKind.itemEnhanced;

  @override
  Map<String, Object?> get data => {'item': item.name, 'plus': plus, 'stone': stone.name, 'gold': gold};
}

/// The wave was won, or lost (the game is over).
final class WaveEnded extends GameEvent {
  WaveEnded(super.wave, super.t, {required this.won});

  final bool won;

  @override
  EventKind get kind => won ? EventKind.waveWon : EventKind.waveLost;

  @override
  Map<String, Object?> get data => {};
}

/// The army was wiped mid-wave ([Wipe._wipe], wipe.dart; decisions-log 322): the [lost] lives (a heart, fewer when fewer
/// were left), the [lives] left, the monsters still alive or queued ([foes]), and whether it ended the game ([over]);
/// else they were swept off and the wave is played again.
final class Wiped extends GameEvent {
  Wiped(super.wave, super.t, {required this.lives, required this.lost, required this.foes, required this.over});

  final int lives, lost, foes;
  final bool over;

  @override
  EventKind get kind => EventKind.wipe;

  @override
  Map<String, Object?> get data => {'lives': lives, 'livesLost': lost, 'foes': foes, 'over': over};
}

/// The events only the telemetry takes (#64): what a balancing log needs but a player doesn't. They go to
/// [Game.listeners] only, never into [Game.log], so the battle log never sees them.
sealed class TraceEvent extends GameEvent {
  TraceEvent(super.wave, super.t);
}

/// The Tavern's unbought offers were rolled again ([Tavern.rerollTavern]) for [price], the visit's [n]th reroll; the
/// [offers] after it, by slot.
final class TavernRerolled extends TraceEvent {
  TavernRerolled(super.wave, super.t, {required this.price, required this.n, required this.offers});

  final int price, n;
  final List<Boost> offers;

  @override
  EventKind get kind => EventKind.tavernRerolled;

  @override
  Map<String, Object?> get data => {'price': price, 'n': n, 'offers': [for (final o in offers) o.name]};
}

/// A wave began: the army that fights it ([army]: living troops by type; [levels]: each type's awakening
/// level above 0; [heroes]: each Hero's type and own skill), the [gold], [capacity] and [lives] it starts
/// with, the item and relic bags, and the Pusaka owned ([pusaka]: name → its type, none in the Gudang, stars, and its Ukir
/// steps once fed).
final class WaveStarted extends TraceEvent {
  WaveStarted(super.wave, super.t,
      {required this.army, required this.levels, required this.heroes, required this.gold, required this.capacity,
      required this.lives, required this.bag, required this.relics, this.tide = const (hp: 1.0, dmg: 1.0, gap: Game.spawnGap, over: 0), this.pusaka = const {},
      this.omens, this.materials, this.boosts, this.pocket});

  final Map<String, int> army, levels, bag, relics;
  final Map<String, Map<String, Object>> pusaka;

  /// The Bayangan the wave starts with (omen.dart): `levels` (each kind held, by name), the frozen Beban `factor`, the
  /// levels still `owed` and the `skipBuff`; null while [omensOn] is off (no key).
  final Map<String, Object>? omens;

  /// The Towns' materials held at the start (town.dart, by name); null in an event made without them (no key).
  final Map<String, int>? materials;

  /// The Tavern's boosts running at the start (tavern.dart, each kind's waves left, 0 for one until the next Town); null
  /// while none runs (no key).
  final Map<String, int>? boosts;

  /// The pocket items the Bag holds at the start (pocket.dart, by kind); null while it holds none (no key).
  final Map<String, int>? pocket;
  final List<(String, String?)> heroes;
  final int gold, capacity, lives;

  /// The tide on this wave's crowd (#92, [tide]): the HP and damage multipliers, the seconds between two monsters
  /// coming on ([spawnGapOf]), and how many waves earlier it counts from for an army over the cap ([Game.waveOver],
  /// Beban, decisions-log 162; 0 at the cap or under it).
  final ({double hp, double dmg, double gap, int over}) tide;

  @override
  EventKind get kind => EventKind.waveStarted;

  @override
  Map<String, Object?> get data => {
        'army': army, 'levels': levels, 'gold': gold, 'capacity': capacity, 'lives': lives, 'bag': bag, 'relics': relics,
        'heroes': [for (final (type, skill) in heroes) {'type': type, 'skill': skill}],
        'tide': {
          for (final (k, v) in [('hp', tide.hp), ('dmg', tide.dmg), ('gap', tide.gap)]) k: (v * 10000).round() / 10000,
          'over': tide.over,
        },
        'pusaka': pusaka,
        'omens': ?omens,
        'materials': ?materials,
        'boosts': ?boosts,
        'pocket': ?pocket,
      };
}

/// A monster came onto the field: from the wave's queue, or raised by a necromancer ([raised]).
final class MonsterSpawned extends TraceEvent {
  MonsterSpawned(super.wave, super.t, {required this.type, required this.tier, this.raised = false});

  final String type;
  final Tier tier;
  final bool raised;

  @override
  EventKind get kind => EventKind.spawned;

  @override
  Map<String, Object?> get data => {'type': type, 'tier': tier.name, 'raised': raised};
}

/// Gold spent: a troop of [type], or ([type] null) more capacity, for [cost].
final class Bought extends TraceEvent {
  Bought(super.wave, super.t, {this.type, required this.cost});

  final String? type;
  final int cost;

  @override
  EventKind get kind => EventKind.bought;

  @override
  Map<String, Object?> get data => {'type': type, 'cost': cost};
}

/// An [item] from the bag given to troop type [type].
final class ItemUsed extends TraceEvent {
  ItemUsed(super.wave, super.t, {required this.item, required this.type, this.plus = 0});

  final Item item;
  final String type;

  /// An enhanced item's plus (decisions-log 255), in the data only above 0.
  final int plus;

  @override
  EventKind get kind => EventKind.itemUsed;

  @override
  Map<String, Object?> get data => {'item': item.name, 'type': type, if (plus > 0) 'plus': plus};
}

/// A [relic] from the bag given to a troop of [type].
final class RelicUsed extends TraceEvent {
  RelicUsed(super.wave, super.t, {required this.relic, required this.type});

  final Relic relic;
  final String type;

  @override
  EventKind get kind => EventKind.relicUsed;

  @override
  Map<String, Object?> get data => {'relic': relic.name, 'type': type};
}

/// A [relic] taken off a troop of [type], back into the bag (#91, [Game.takeOff]).
final class RelicTakenOff extends TraceEvent {
  RelicTakenOff(super.wave, super.t, {required this.relic, required this.type});

  final Relic relic;
  final String type;

  @override
  EventKind get kind => EventKind.relicTakenOff;

  @override
  Map<String, Object?> get data => {'relic': relic.name, 'type': type};
}

/// Pusaka [relic] bound from the Gudang to troop type [type] at [stars] stars, for [cost] (0: its first binding;
/// pusaka.dart).
final class PusakaBound extends TraceEvent {
  PusakaBound(super.wave, super.t, {required this.relic, required this.type, required this.stars, required this.cost});

  final Relic relic;
  final String type;
  final int stars, cost;

  @override
  EventKind get kind => EventKind.pusakaBound;

  @override
  Map<String, Object?> get data => {'relic': relic.name, 'type': type, 'stars': stars, 'cost': cost};
}

/// Pusaka [relic] moved off troop type [from]: to type [to] (a Pindah, for [cost]), or to the Gudang ([to] null, free:
/// unbound, or put out by another Pusaka bound to [from]).
final class PusakaMoved extends TraceEvent {
  PusakaMoved(super.wave, super.t, {required this.relic, required this.from, this.to, required this.cost});

  final Relic relic;
  final String from;
  final String? to;
  final int cost;

  @override
  EventKind get kind => EventKind.pusakaMoved;

  @override
  Map<String, Object?> get data => {'relic': relic.name, 'from': from, 'to': to, 'cost': cost};
}

/// One [loot] (an [Item] or a [Relic], or with the forge's Town Shop a material, [Mat], decisions-log 248) bought in the
/// store (#63, store.dart) for [cost].
final class StoreBought extends TraceEvent {
  StoreBought(super.wave, super.t, {required this.loot, required this.cost}) : assert(loot is Item || loot is Relic || loot is Mat);

  final Enum loot;
  final int cost;

  @override
  EventKind get kind => EventKind.storeBought;

  @override
  Map<String, Object?> get data => {..._lootJson(loot), 'cost': cost};
}

/// [n] [loot] (an [Item], a [Relic], a material, [Mat], or a pocket item, [PocketKind]) sold from the bag to the store for
/// [gain] in all.
final class StoreSold extends TraceEvent {
  StoreSold(super.wave, super.t, {required this.loot, required this.n, required this.gain, this.plus = 0, this.margin, this.pressure})
      : assert(loot is Item || loot is Relic || loot is Mat || loot is PocketKind);

  final Enum loot;
  final int n, gain;

  /// An enhanced item's plus (decisions-log 255), in the data only above 0.
  final int plus;

  /// The market's margin for the first piece and the product's pressure before the sale (decisions-log 326,
  /// market.dart; `eventVersion` 14): only for the Smithy's goods (an item, a small relic).
  final double? margin;
  final int? pressure;

  @override
  EventKind get kind => EventKind.storeSold;

  @override
  Map<String, Object?> get data => {
        ..._lootJson(loot),
        if (plus > 0) 'plus': plus,
        'n': n,
        'gain': gain,
        if (margin case final m?) 'margin': (m * 100).round() / 100,
        'pressure': ?pressure,
      };
}

/// A store event's loot: `item` or `relic` by name, the other null (as a field drop's event had it, decisions-log 321); a material sold (the Towns'
/// Shop, decisions-log 230) both null and its name under `material`.
Map<String, Object?> _lootJson(Enum loot) => {
      'item': loot is Item ? loot.name : null,
      'relic': loot is Relic ? loot.name : null,
      if (loot is Mat) 'material': loot.name,
      if (loot is PocketKind) 'pocket': loot.name, // decisions-log 332
    };

/// Troop [type] was sent home (Lepas jenis, [Game.releaseType], decisions-log 141): [troops] of it went home for
/// [refund] gold in all.
final class TypeReleased extends TraceEvent {
  TypeReleased(super.wave, super.t, {required this.type, required this.troops, required this.refund});

  final String type;
  final int troops, refund;

  @override
  EventKind get kind => EventKind.typeReleased;

  @override
  Map<String, Object?> get data => {'type': type, 'troops': troops, 'refund': refund};
}

/// A boss chest's [cards] were rolled ([Chest], draft.dart): its first roll ([reroll] 0) or a reroll. A card is a Pusaka by
/// name, or 'serpihan'. [omens]: the Bayangan each card hides (omen.dart; null while [omensOn] is off, and then no key).
final class OfferShown extends TraceEvent {
  OfferShown(super.wave, super.t, {required this.cards, this.omens, required this.reroll, required this.chest, required this.chestWave});

  final List<Relic?> cards;
  final List<OmenKind?>? omens;
  final int reroll, chestWave;
  final String chest;

  @override
  EventKind get kind => EventKind.offerShown;

  @override
  Map<String, Object?> get data => {
        'cards': [for (final r in cards) r?.name ?? 'serpihan'],
        'rarities': [for (final r in cards) r?.rarity.name],
        'reroll': reroll, 'chest': chest, 'chestWave': chestWave,
        if (omens case final o?) 'omens': [for (final k in o) k?.name],
      };
}

/// A boss chest was rerolled ("Kocok ulang") for [price] gold, or with a Serpihan ([serpihan], free).
final class OfferRerolled extends TraceEvent {
  OfferRerolled(super.wave, super.t, {required this.price, this.serpihan = false});

  final int price;
  final bool serpihan;

  @override
  EventKind get kind => EventKind.offerRerolled;

  @override
  Map<String, Object?> get data => {'price': price, 'serpihan': serpihan};
}

/// Pusaka [relic] (bound to [type]; null: in the Gudang) was fed the [items] from the bag, by kind, for [points] on its
/// Ukir bar: one tap ([Ukir.feedUkir], pusaka.dart). Between waves only, so the next wave's record sums it.
final class UkirFed extends TraceEvent {
  UkirFed(super.wave, super.t, {required this.relic, required this.items, required this.points, this.type});

  final Relic relic;
  final Map<Item, int> items;
  final int points;
  final String? type;

  @override
  EventKind get kind => EventKind.ukirFed;

  @override
  Map<String, Object?> get data => {
        'relic': relic.name, 'items': {for (final MapEntry(:key, :value) in items.entries) key.name: value}, 'points': points,
        'type': type,
      };
}

/// Pusaka [relic], at [stars] (bound to [type]; null: in the Gudang), took Ukir [step] (1 to [ukirCost].length): its bar
/// was full ([Ukir.feedUkir]). [starUps]: how many star-ups for the enemy buffs it set off, a full [ukirOmenStars] of
/// worth fed in the run passed (written only when any).
final class UkirStep extends TraceEvent {
  UkirStep(super.wave, super.t, {required this.relic, required this.step, required this.stars, this.type, this.starUps = 0});

  final Relic relic;
  final int step, stars, starUps;
  final String? type;

  @override
  EventKind get kind => EventKind.ukirStep;

  @override
  Map<String, Object?> get data => {'relic': relic.name, 'step': step, 'stars': stars, 'type': type, if (starUps > 0) 'starUps': starUps};
}

/// What the Town roll after won wave [wave] did ([Towns._rollTown]), for that wave's telemetry record (its `town`):
/// `{chance, hit, slot?}` when it rolled, `{blocked: true}` within [TownSchedule.minGap] of the last Town, `{marked:
/// slot}` while one is marked. Once every won wave.
final class TownRolled extends TraceEvent {
  TownRolled(super.wave, super.t, {required this.town});

  final Map<String, Object> town;

  @override
  EventKind get kind => EventKind.townRolled;

  @override
  Map<String, Object?> get data => {'town': town};
}

/// Why a wave's monsters march ([Marched], [Game._watchStall]): no progress for [stallTime]; the same while they
/// drift away from the base, whatever their HP did ([stallDrift]); [stallOvertime] after the last spawn, life lost or
/// the slots' [stallProgress]; or [stallOvertimeMax] after the last spawn or life lost, whatever the slots did.
enum MarchCause { stalled, drifting, overtime, overtimeMax }

/// The wave stalled and its monsters began their march on the base ([stallTime]), and why.
final class Marched extends TraceEvent {
  Marched(super.wave, super.t, {this.why = MarchCause.stalled});

  final MarchCause why;

  @override
  EventKind get kind => EventKind.marched;

  @override
  Map<String, Object?> get data => {'why': why.name};
}

/// The last [logSize] events, oldest first, and how many there have been in all.
class EventLog {
  final _entries = <GameEvent>[];

  /// How many events came in all, the dropped ones too (the battle log counts the unread with it).
  int total = 0;

  List<GameEvent> get entries => List.unmodifiable(_entries);

  /// The newest first.
  Iterable<GameEvent> get newestFirst => _entries.reversed;

  void add(GameEvent e) {
    _entries.add(e);
    total++;
    if (_entries.length > logSize) _entries.removeAt(0);
  }
}
