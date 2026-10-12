part of 'game.dart';

// Peti Bos, the boss's chest (decisions-log 152; docs/loot-items-relics.md, "Peti Bos"; the design's P3). The owner,
// 2026-10-01: "mungkin unsur rougelikenya bisa dari item artefak yang ada sekarang" (the roguelike element can come from
// today's artefacts). Every won boss wave brings a chest of [draftCards] different Pusaka cards: take one (Ambil), and
// the others crumble. A card is a new Pusaka at ★1 (bound by the default rule, [pusakaPrefs], or into the Gudang; an
// oath the whole army's) or one more star on one owned; a ★3 one is never offered, and with too few left a gap is a
// Serpihan (a free reroll). The run's first chest is three different Epik. From wave [legendFrom] a card may be a
// Legenda (pusaka.dart, decisions-log 155; batch G-1P's ten, decisions-log 231): ★1 only, each found once a run
// ([Game.legendsFound]), and one oath found keeps every other off the cards (batch G-4's six with Oath of One and
// Alliance: eight, one a run; decisions-log 247). Gold rerolls the cards (Kocok ulang, doubling) or passes the chest
// over for gold (Lewati); it can't be put off (decisions-log 281: the UI's Nanti is gone, lib/chest_popup.dart). With
// the chest on ([Game.offers]) the Pusaka come only from it: the store's shelf closes ([artefactShelf]); the boss's
// small relic went with it (`chestTakesBossRelic`, decisions-log 152), as every field drop has since (decisions-log 321:
// the switch went too). The four Langka Pusaka's numbers are this file's too: their rows are in [pusakaCatalog]
// (pusaka_catalog.dart), run by the engine (pusaka_engine.dart). Every number the owner may tune is one constant below.

/// Cards in a chest; the most catch-up chests an old save gets (one per [catchUpEvery] boss waves won); the chest in a
/// row with no Epik or better that gets one in its first slot ([legendPity]); and the wave from which a Legenda may come
/// (before it, or with every Legenda found, a Legenda roll steps down to Epik). Until decisions-log 281 `offerQueueMax`
/// 2 chests could be put off (Nanti) before the next had to be opened.
const draftCards = 3, catchUpMax = 3, catchUpEvery = 3, legendPity = 6, legendFrom = 20;

/// A card's rarity odds in the first boss chest's wave: Langka, Epik, Legenda (they add up to 1). A rarity with no card
/// left steps down, then up (a Legenda before [legendFrom], or once every one is found, to Epik).
const chestOdds = (rare: 0.55, epic: 0.37, legend: 0.08);

/// Each later boss chest's wave moves the odds [chestOddsStep] of Legenda further toward [chestOddsCap], Epik and
/// Langka giving it up in the cap's proportion; the cap is reached at the 68th step (wave 345) and kept (decisions-log
/// 185). The owner, 2026-10-02: "makin tinggi wave maka change untuk item buff langka naik 0.05 per wave dan stop di
/// angka yang ngebuat change normal item turun ke angka 50%"; 2026-10-03: "wave 5 8%, nanti di wave 10 8.25%", then
/// the cap: "aku mau rebalance wX dan seterusnya -> 40%, 35%, 25%". The step and the cap set where it lands.
const chestOddsCap = (rare: 0.40, epic: 0.35, legend: 0.25), chestOddsStep = 0.0025;

/// The rarity odds of a chest of [wave]: [chestOdds] moved one [chestOddsStep] for each boss wave before it after the
/// first (w5 none, w10 one, w100 19), up to [chestOddsCap].
({double rare, double epic, double legend}) chestOddsAt(int wave) {
  final steps = ((chestOddsCap.legend - chestOdds.legend) / chestOddsStep).round(), n = max(0, wave ~/ bossEvery - 1);
  if (n >= steps) return chestOddsCap;
  double at(double from, double to) => from + (to - from) * n / steps;
  return (
    rare: at(chestOdds.rare, chestOddsCap.rare),
    epic: at(chestOdds.epic, chestOddsCap.epic),
    legend: at(chestOdds.legend, chestOddsCap.legend),
  );
}

/// Each further reroll of one chest costs [rerollRise] times the one before ([rerollPrice] the first, back to it for
/// the next chest); Lewati pays [skipShare] of one reroll price.
const rerollRise = 2.0, skipShare = 1.0;

/// Whether the store still sells the epik Pusaka beside the chest (owner decision 4b). False (4a): with the chest on
/// ([Game.offers]) the Toko's artefact shelf is closed; a plain Game() (no chest) keeps it ([Store.shelfOpen]).
const artefactShelf = false;

/// What a Langka Pusaka is worth ([Store.basePrice]): the Gudang sells one back for [sellShare] of it, and an old
/// save's copy past ★3 pays back [copyRefund] of it. The store never sells one.
const langkaPrice = 16000;

/// What a new Epik Artifact (the chest's, not the Shop's five) is worth ([Store.basePrice]): the Vault sells one back
/// for [sellShare] of it, and an old save's copy past ★3 pays back [copyRefund] of it. Between [langkaPrice] and
/// `legendaPrice`; the owner's call (2026-10-04: "epik punya harganya sendiri"), one number to change.
const epikPrice = 25000;

/// Iron Banner: every troop of the type takes this share less damage (by stars), after its defence, with a worn guard's.
const ironBannerK = [0.15, 0.20, 0.25];

/// Blood Fang: every troop of the type heals this share of the damage it deals (by stars), on top of a worn fang.
const bloodFangK = [0.10, 0.15, 0.20];

/// War Drum: every [every]th normal attack of a troop of the type (the fury's blow counter, [Unit.blows]) does ×[hit]
/// (by stars), with a worn fury's.
const warDrumK = (every: 3, hit: [1.5, 1.75, 2.0]);

/// Mourning Bell: when a troop of the type falls, every troop within [reach] of it heals [heal] of its max HP (by stars).
const mourningBellK = (reach: 2 * tile, heal: [0.20, 0.25, 0.30]);

// Batch L-1P (decisions-log 205; catalog-design §3.1): ten more Langka, chest-only like the four, each a row of
// [pusakaCatalog] on the engine's Fx. A "boss" share is what a status does on the boss (Tier.boss) of what it does on
// the others: half, as the Hero skills' slows and weakens.

/// Titan Bane: every blow of a troop of the type on the boss or a mini boss does ×this (by stars), before its defence.
const titanBaneK = [1.15, 1.22, 1.30];

/// Finishing Blade: a blow of a troop of the type on a monster under [below] of its max HP does ×[hit] (by stars).
const finishingBladeK = (below: 0.3, hit: [1.2, 1.3, 1.4]);

/// First Cut: a blow of a troop of the type on a monster over [above] of its max HP does ×[hit] (by stars).
const firstCutK = (above: 0.9, hit: [1.2, 1.3, 1.4]);

/// Shell Cracker: a normal attack of a troop of the type on a monster with a shield ([FxEngine.shielded]: an absorb, a
/// shot ward, a Barrier or a guard) does ×this (by stars).
const shellCrackerK = [1.2, 1.3, 1.4];

/// Twin Fury: a troop of the type that wears a fury does ×this (by stars) more on the fury's ×[furyHit] attack.
const twinFuryK = [1.2, 1.3, 1.4];

/// Steady Stance: a troop of the type over [above] of its max HP takes [cut] less damage (by stars), after its
/// defence, like Iron Banner's.
const steadyStanceK = (above: 0.8, cut: [0.18, 0.24, 0.30]);

/// Turtle Shell: a troop of the type under [below] of its max HP takes [cut] less damage (by stars).
const turtleShellK = (below: 0.4, cut: [0.18, 0.24, 0.30]);

/// Dulling Mail: a monster that takes HP off a troop of the type deals ×[dealt] (by stars; the boss [boss] of the cut)
/// for [time] s, at most once every [cd] s a troop.
const dullingMailK = (dealt: [0.90, 0.86, 0.82], time: 2.0, cd: 1.0, boss: 0.5);

/// Challenge Letter: every [every]th normal attack of a melee troop of the type makes the monster it hits fight that
/// troop ([Status.taunt]) for [time] s (by stars; the boss [boss] of it).
const challengeLetterK = (every: 4, time: [2.0, 2.5, 3.0], boss: 0.5);

/// Snare Cord: every [every]th normal attack of a troop of the type makes the monster it hits walk at ×[slow] (by stars;
/// the boss [boss] of the slow) for [time] s.
const snareCordK = (every: 4, slow: [0.8, 0.75, 0.7], time: 2.0, boss: 0.5);

/// A status's number on the boss: [share] of its distance from [base] (1: no change), by stars ([dullingMailK],
/// [challengeLetterK], [snareCordK]).
List<double> bossShare(List<double> k, double share, {double base = 1}) => [for (final v in k) base + (v - base) * share];

/// Whether batch L-1P's rows are in the game ([Art.live]): a probe's mirror turns it off to check that the batch
/// changes nothing else (the chest's Langka pool back to the four).
const liveL1P = true;

// Batch L-2P (decisions-log 207; catalog-design §3.1): ten more Langka, chest-only like the others, each a row of
// [pusakaCatalog] on the engine's Fx. An every-Nth one waits under the Bayangan Off Beat ([FxEngine._everyOf]); one on
// its own cooldown counts it from its last proc ([FxEngine._fxGate]).

/// Momentum: a troop of the type that kills a monster does ×this (by stars) on its next normal attack (one charge,
/// [Unit.charge]; a wave's start drops it).
const momentumK = [1.3, 1.45, 1.6];

/// Bleeding Edge: every [every]th normal attack of a troop of the type makes the monster it hits bleed [share] (by stars)
/// of that attack, over [time] s (a tick a second, [Status.bleed]).
const bleedingEdgeK = (every: 3, share: [0.30, 0.45, 0.60], time: 3.0);

/// Shatter Shard: every [every]th normal attack of a troop of the type that lands: the other monsters within [reach] of
/// its target take [share] (by stars) of it (extra damage), at most once every [cd] s a troop.
const shatterShardK = (every: 5, share: [0.4, 0.5, 0.6], reach: tile, cd: 1.0);

/// Pain Crystal: a blow that hurts a troop of the type gives it [mp] (by stars) of its max MP, at most once every [cd] s.
const painCrystalK = (mp: [0.02, 0.03, 0.04], cd: 1.0);

/// Watch Shield: every troop of the type starts each wave with a shield (its ward, heal.dart) of this share of its max HP
/// (by stars); the wave's end clears it.
const watchShieldK = [0.10, 0.14, 0.18];

/// Bone Buckler: each kill of a troop of the type gives it a shield of [add] (by stars) of its max HP, up to [stack]
/// kills' worth (never past [wardMax]).
const boneBucklerK = (add: [0.04, 0.05, 0.06], stack: 3);

/// Riposte: every [every]th blow a monster that fights up close lands on a troop of the type: the troop hits it back for
/// [share] (by stars) of its own attack (a hit-back: no attacker, so nothing answers it).
const riposteK = (every: 3, share: [0.40, 0.55, 0.70]);

/// Mana Leech: every [every]th normal attack of a troop of the type gives it [mp] (by stars) of its max MP.
const manaLeechK = (every: 3, mp: [0.03, 0.045, 0.06]);

/// Looter's Pouch: a monster a troop of the type kills pays ×this of its gold (by stars; after the Bayangan Thrift).
const lootersPouchK = [1.10, 1.15, 1.20];

/// Spell Cutter: every [every]th normal attack of a troop of the type takes 1 good effect off the monster it hits (the
/// longest left of what Spellbreaker strips, or its guard; on the boss and a mini boss half of what is left, once), at
/// most once every [cd] s (by stars) a troop.
const spellCutterK = (every: 5, cd: [6.0, 5.0, 4.0]);

/// Whether batch L-2P's rows are in the game ([Art.live]): a probe's mirror turns it off to check that the batch
/// changes nothing else (the chest's Langka pool back to fourteen).
const liveL2P = true;

// Batch L-3 (decisions-log 209; catalog-design §3.1): the last six Langka, chest-only like the others, each a row of
// [pusakaCatalog] on the engine's Fx: two cleanses on their own cooldown (Salt Charm when hit, Pure Water with a heal),
// three heals through the heal funnel (Wolf Feast on a kill, Hidden Flask once a wave when low, Living Moss's regen for
// some attack) and a heal's extra turned to a shield (Full Cup).

/// Salt Charm: a blow on a troop of the type ends [clears] bad effect a monster put on it, at most once every [cd] s (by
/// stars; its cooldown starts only when there was one to clear).
const saltCharmK = (cd: [8.0, 6.0, 4.0], clears: 1);

/// Wolf Feast: a troop of the type that kills a monster heals this share of its max HP (by stars).
const wolfFeastK = [0.04, 0.06, 0.08];

/// Full Cup: a heal of a healer of the type that goes past the troop's full HP gives that troop a shield (its ward,
/// heal.dart) of [share] (by stars) of the extra, up to [most] of its max HP.
const fullCupK = (share: [0.50, 0.75, 1.00], most: 0.12);

/// Hidden Flask: once a wave, a blow that leaves a troop of the type alive under [below] of its max HP heals it [heal]
/// (by stars) of its max HP.
const hiddenFlaskK = (below: 0.35, heal: [0.20, 0.25, 0.30]);

/// Living Moss: a troop of the type heals [regen] (by stars) of its max HP every second (its regen), and deals ×[dmg].
const livingMossK = (regen: [0.004, 0.006, 0.008], dmg: 0.9);

/// Pure Water: a heal of a healer of the type also ends [clears] bad effect a monster put on the troop healed, at most
/// once every [cd] s (by stars) a healer (its cooldown starts only when there was one to clear).
const pureWaterK = (cd: [3.0, 2.5, 2.0], clears: 1);

/// Whether batch L-3's rows are in the game ([Art.live]): a probe's mirror turns it off to check that the batch changes
/// nothing else (the chest's Langka pool back to twenty-four).
const liveL3P = true;

// Batch E-1P (decisions-log 211; catalog-design §3.2): the first ten new Epik, chest-only like the Langka (the Toko
// never sells them, [newEpikStore]; one in the Gudang sells back like a Langka), each a row of [pusakaCatalog] on the
// engine's Fx: four powers on a condition (Healer Bane, Bully's Club, Unity Ring) or after a skill (Rune Gauntlet), two
// cuts on a condition (Arrow Catcher, Hero's Cloak), a weaken on what it hits (Witherroot), and three stats with a trade
// (Hawk Feather, Stone Coat, Moonwell).

/// Healer Bane: a normal attack of a troop of the type on a monster healer does ×this (by stars).
const healerBaneK = [1.3, 1.45, 1.6];

/// Bully's Club: a normal attack of a troop of the type on a held monster ([FxEngine.foeHeld]: slowed, pinned, stunned
/// or hexed) does ×this (by stars).
const bullyClubK = [1.3, 1.4, 1.5];

/// Unity Ring: while [types] or more troop types have a troop alive, a normal attack of a troop of the type does ×[hit]
/// (by stars).
const unityRingK = (types: 4, hit: [1.25, 1.35, 1.45]);

/// Rune Gauntlet: a troop of the type that casts a skill (its own, its awakening's or a Hero's) deals ×[might] (by stars)
/// for [time] s (its might, [Status.might]).
const runeGauntletK = (might: [1.3, 1.4, 1.5], time: 4.0);

/// Hawk Feather: the type's range ×[range] (by stars; a melee type's stops at [meleeMaxRange], as a bow's), and its
/// attack or heal ×[dmg].
const hawkFeatherK = (range: [1.15, 1.22, 1.3], dmg: 0.9);

/// Witherroot: a monster a troop of the type takes HP off deals ×[dealt] (by stars; the boss ×[boss]) for [time] s (a
/// weaken).
const witherrootK = (dealt: [0.9, 0.87, 0.84], boss: [0.95, 0.93, 0.91], time: 3.0);

/// Arrow Catcher: a troop of the type takes this share less damage from a monster that shoots (by stars), after its
/// defence, like Iron Banner's.
const arrowCatcherK = [0.2, 0.25, 0.3];

/// Stone Coat: the type's defence + [def] × [shieldDef] (by stars: one Shield's to two), and its walk speed ×[speed].
const stoneCoatK = (def: [1.0, 1.5, 2.0], speed: 0.9);

/// Hero's Cloak: the type's Hero takes this share less damage (by stars), after its defence.
const heroCloakK = [0.2, 0.25, 0.3];

/// Moonwell: the type's MP comes back ×[mpRegen] as fast (by stars), and its max HP ×[hp].
const moonwellK = (mpRegen: [1.3, 1.45, 1.6], hp: 0.9);

/// Whether batch E-1P's rows are in the game ([Art.live]): a probe's mirror turns it off to check that the batch changes
/// nothing else (the chest's Epik pool back to the five).
const liveE1P = true;

// Batch E-2P (decisions-log 214; catalog-design §3.2): seven more new Epik, chest-only like E-1P's (the Toko never sells
// them, [newEpikStore]; one in the Gudang sells back at its share of [epikPrice]), each a row of [pusakaCatalog] on the
// engine's Fx: a one-hit mark another type spends (Ember Brand), a burst when it kills (Funeral Pyre), a strip of the
// monster that hits it (Null Stone), a taunt on the monsters near (Warden's Horn), a might on the troops near one that
// falls (Fallen Flag), a stand against shoves all wave with a trade (Anchor) and a shield after a skill (Aegis Seal).

/// Ember Brand: every [every]th normal attack of a troop of the type marks the monster it hits for [time] s
/// ([Unit.emberMark]; shorter under the Bayangan Mark Ward); the next blow on it from a troop of another type (a normal
/// attack, a smite or a skill's, never extra damage) does ×[hit] (by stars) and uses the mark up.
const emberBrandK = (every: 3, hit: [1.5, 1.75, 2.0], time: 4.0);

/// Funeral Pyre: a troop of the type that kills a monster burns every other monster within [reach] of it for [share]
/// (by stars) of the killing blow (as it was before the dead one's defence), at most once every [cd] s a troop.
const funeralPyreK = (share: [0.6, 0.8, 1.0], reach: 1.5 * tile, cd: 1.5);

/// Null Stone: a monster that takes HP off a troop of the type loses its good effects and its guard (the ones
/// Spellbreaker strips; the boss and a mini boss half of what is left, once), at most once every [cd] s (by stars) a
/// troop.
const nullStoneK = (cd: [6.0, 5.0, 4.0]);

/// Warden's Horn: every [every]th normal attack of a melee troop of the type makes every monster within [reach] of it
/// but the boss fight it ([Status.taunt]) for [time] s (by stars), at most once every [cd] s a troop.
const wardensHornK = (every: 6, time: [2.5, 3.0, 3.5], reach: 2 * tile, cd: 6.0);

/// Fallen Flag: when a troop of the type falls, every troop within [reach] of it deals ×[might] (by stars) for [time] s
/// (a might).
const fallenFlagK = (might: [1.2, 1.25, 1.3], time: 4.0, reach: 2 * tile);

/// Anchor: from a wave's start each troop of the type stands firm against the monsters for the whole wave
/// ([Status.noShove]: no monster's shove, drag or press moves it), and walks at ×[speed] (by stars: the trade lightens).
const anchorK = (speed: [0.85, 0.9, 0.95]);

/// Aegis Seal: a troop of the type that casts a skill (its own, its awakening's or a Hero's) gets a shield of this share
/// of its max HP (by stars; never past [wardMax], a shield already over it stays).
const aegisSealK = [0.10, 0.14, 0.18];

/// Whether batch E-2P's rows are in the game ([Art.live]): a probe's mirror turns it off to check that the batch changes
/// nothing else (the chest's Epik pool back to fifteen).
const liveE2P = true;

// Batch E-3P (decisions-log 223; catalog-design §3.2): the last eight new Epik, chest-only like the others (the Toko
// never sells them, [newEpikStore]; one in the Gudang sells back at its share of [epikPrice]), each a row of
// [pusakaCatalog] on the engine's Fx, most of them heals through the heal funnel: a healer's heal that also gives the
// troop healed MP (Mana Hymn) or a might (Brave Song), or heals the troops next to it (Halo Lantern); a heal on a low
// troop that lands bigger (Mercy Lily); a heal at a wave's end (Hearth); a skill that heals (Bright Spring) or cleanses
// (Saint's Tear) the troops near; and a heal on the troops near every few hits (Heartbeat).

/// Mana Hymn: a heal of a healer of the type gives the troop healed this share of its own max MP (by stars).
const manaHymnK = [0.03, 0.04, 0.05];

/// Saint's Tear: a troop of the type that casts a skill (its own, its awakening's or a Hero's) ends every bad effect a
/// monster put on it and on each troop within [reach] of it, at most once every [cd] s (by stars; its cooldown starts
/// only when there was one to end).
const saintTearK = (cd: [6.0, 5.0, 4.0], reach: 2 * tile);

/// Brave Song: a troop a heal of a healer of the type lands on deals ×[might] (by stars) for [time] s (a might).
const braveSongK = (might: [1.1, 1.15, 1.2], time: 3.0);

/// Halo Lantern: a heal of a healer of the type also heals the [most] troops nearest the one healed, within [reach] of
/// it, [share] (by stars) of that heal each (no chain: their heals set off nothing).
const haloLanternK = (share: [0.15, 0.2, 0.25], most: 2, reach: tile);

/// Hearth: at a won wave's end each living troop of the type heals up to this share of its max HP (by stars), a heal
/// between waves.
const hearthK = [0.4, 0.6, 0.8];

/// Heartbeat: every [every]th normal attack of a troop of the type heals every troop within [reach] of it (itself too)
/// [heal] (by stars) of its own max HP.
const heartbeatK = (every: 4, heal: [0.03, 0.04, 0.05], reach: 1.5 * tile);

/// Mercy Lily: a heal on a troop of the type while it is under [below] of its max HP lands ×[heal] (by stars); not the
/// Grail's save nor the after-wave heal.
const mercyLilyK = (heal: [1.35, 1.5, 1.7], below: 0.4);

/// Bright Spring: a troop of the type that casts a skill heals itself and each troop within [reach] of it [heal] (by
/// stars) of its own max HP.
const brightSpringK = (heal: [0.06, 0.09, 0.12], reach: 1.5 * tile);

/// Whether batch E-3P's rows are in the game ([Art.live]): a probe's mirror turns it off to check that the batch changes
/// nothing else (the chest's Epik pool back to twenty-two).
const liveE3P = true;

// Batch G-1P (decisions-log 231; catalog-design §3.3): the first ten new Legenda, from the chest from wave [legendFrom]
// like Dragon Crown, each found once a run, ★1 only, never in the Toko (one in the Gudang sells back at its share of
// [legendaPrice]), each a row of [pusakaCatalog] on the engine's Fx: a rule with a real cost, a condition or a trade. A
// Legenda has no star past ★1, so Carve moves one named number of each by [perStar] a star of worth ([ukirPerStar]).

/// Lone Wolf Pelt: while [few] or fewer troops of the type are alive, their normal attacks do ×[power]. Carve: [power]
/// +[perStar].
const loneWolfK = (few: 3, power: 2.0, perStar: 0.15);

/// Martyr's Flame: when a troop of the type falls, every monster within [reach] of it takes [share] of the fallen one's
/// max HP (through its defence; extra damage); the type's max HP ×[hp] (the trade). Carve: [share] +[perStar].
const martyrFlameK = (share: 0.6, reach: 2 * tile, hp: 0.9, perStar: 0.1);

/// Wide Blows: the type's normal attacks (a blow, a shot) also hit every monster within [splash] px more of their
/// target, on top of its own splash (extra damage past the target); its attack (a healer's heal) ×[dmg] (the trade).
/// Carve: [dmg] +[perStar].
const wideBlowsK = (splash: 16.0, dmg: 0.8, perStar: 0.05);

/// Champion's Mantle: the type's Heroes' normal attacks do ×[hero], the rest of the type's ×[rest] (the trade). Carve:
/// [hero] +[perStar].
const championK = (hero: 1.8, rest: 0.9, perStar: 0.1);

/// Vengeance Mark: a monster that takes HP off a troop of the type is marked for [time] s ([Status.pusakaMark]): it takes
/// ×[taken] from every troop (the boss ×[boss]); the type's troops take ×[selfTaken] (the trade). Carve: [taken]
/// +[perStar] (the boss's stays).
const vengeanceK = (taken: 1.25, boss: 1.12, time: 4.0, selfTaken: 1.15, perStar: 0.05);

/// Mirror Shield: from a wave's start each troop of the type sends [share] of every up-close blow it takes back at the
/// monster (its own [Status.reflect], the whole wave); its attack (a healer's heal) ×[dmg] (the trade). Carve: [share]
/// +[perStar].
const mirrorK = (share: 0.4, dmg: 0.8, perStar: 0.05);

/// Ghost Step: every [every]th monster blow on a troop of the type does nothing; its attack (a healer's heal) ×[dmg] (the
/// trade). Carve: [dmg] +[perStar].
const ghostStepK = (every: 3, dmg: 0.8, perStar: 0.05);

/// Ice Grip: every [every]th normal attack of a troop of the type holds the monster it hits for [hold] s (it can't walk:
/// [Status.impaled] at [fxHoldWalk]); the boss and a mini boss walk ×[bossSlow] for [bossTime] s instead ([Status.slow]);
/// its attack (a healer's heal) ×[dmg] (the trade). Carve: [hold] +[perStar] (the bosses' slow stays).
const iceGripK = (every: 4, hold: 1.0, bossSlow: 0.7, bossTime: 2.0, dmg: 0.85, perStar: 0.2);

/// Relic Altar: what the small relics worn by the type's troops do ×[k] (fang's heal, thorns' hit back, guard's cut and
/// fury's extra, at the sites the Bayangan Rust weakens); the type's max HP ×[hp] (the trade). Carve: [k] +[perStar].
const relicAltarK = (k: 1.5, hp: 0.85, perStar: 0.1);

/// Vow of Silence: the type's max HP and attack (a healer's heal) ×[k]; it never uses a skill (its own, its awakening's
/// or a Hero's). Carve: [k] +[perStar].
const vowSilenceK = (k: 1.4, perStar: 0.05);

/// Whether batch G-1P's rows are in the game ([Art.live]): a probe's mirror turns it off to check that the batch changes
/// nothing else (the chest's Legenda pool back to three).
const liveG1P = true;

// Batch G-2 (decisions-log 238; catalog-design §3.3): eight more new Legenda, chest-only and ★1 only like G-1P's, each
// a rule with a real cost: a power while low (Rage Totem), a link that takes the troops' hits near it (Guardian Chain), a
// cut in a crowd of its own (Phalanx), a fallen troop back (Phoenix Plume), a fall that shelters the troops near (Soul
// Shelter), a skill that fills their MP (Mana Font), every few hits a hex (Hex Blade) and a strong kill that powers the
// type (Glory Seeker). Carve moves one named number of each by [perStar] a star of worth ([ukirPerStar]).

/// Rage Totem: while a troop of the type is under [below] of its max HP, its normal attacks do ×[power]; the heals it
/// gets in a wave land ×[healIn] (the trade, through the heal funnel; never the Grail's save nor the after-wave heal).
/// Carve: [power] +[perStar].
const rageTotemK = (below: 0.5, power: 1.6, healIn: 0.7, perStar: 0.1);

/// Guardian Chain: every [every]th normal attack of a troop of the type links each troop of another type within [reach]
/// of it for [time] s ([Status.link], as Shared Wounds'): [share] of every blow on that troop goes to the chain's holder
/// instead, through the holder's own defence (the cost: it takes their hits). Carve: [share] +[perStar].
const guardianChainK = (every: 4, reach: 2 * tile, share: 0.25, time: 4.0, perStar: 0.05);

/// Phalanx: while [near] or more other troops stand within [reach] of a troop of the type, it takes [cut] less of every
/// blow (after its defence); the type's attack (a healer's heal) ×[dmg] (the trade). Carve: [cut] +[perStar].
const phalanxK = (near: 3, reach: 1.5 * tile, cut: 0.3, dmg: 0.85, perStar: 0.03);

/// Phoenix Plume: once a wave the first troop of the type to fall (not a Hero, nor one brought back before) rises again
/// [delay] s later where it fell, at [hpLeft] of its max HP (Resurrection's way back, [Unit.revived]); the type's max HP
/// ×[hp] (the trade). Carve: [hpLeft] +[perStar].
const phoenixK = (hpLeft: 0.3, delay: 3.0, hp: 0.85, perStar: 0.05);

/// Soul Shelter: when a troop of the type falls, every living troop within [reach] of it takes no damage for [time] s (a
/// [Status.cap] at 0, the Grail save's window), at most once every [cd] s for the whole type; the type's attack (a
/// healer's heal) ×[dmg] (the trade). Carve: [time] +[perStar].
const soulShelterK = (time: 1.5, reach: 2 * tile, cd: 6.0, dmg: 0.85, perStar: 0.25);

/// Mana Font: a troop of the type that casts a skill (its own, its awakening's or a Hero's) gives each other troop within
/// [reach] of it [share] of that troop's max MP; the type's MP regen ×[mpRegen] (the trade). Carve: [share] +[perStar].
const manaFontK = (share: 0.25, reach: 3 * tile, mpRegen: 0.7, perStar: 0.05);

/// Hex Blade: every [every]th normal attack of a troop of the type turns the monster it hits into a slime for [time] s
/// (Slime Hex's [Status.hex]; never the boss nor a mini boss), at most once every [cd] s a troop; the type's attack (a
/// healer's heal) ×[dmg] (the trade). Carve: [time] +[perStar].
const hexBladeK = (every: 8, time: 2.0, cd: 6.0, dmg: 0.85, perStar: 0.25);

/// Glory Seeker: a troop of the type that kills a high elite, a mini boss or the boss gives every troop of the type
/// ×[might] damage for [time] s (a might); the type's attack (a healer's heal) ×[dmg] (the trade). Carve: [might]
/// +[perStar].
const glorySeekerK = (might: 1.25, time: 5.0, dmg: 0.9, perStar: 0.05);

/// Whether batch G-2's rows are in the game ([Art.live]): a probe's mirror turns it off to check that the batch changes
/// nothing else (the chest's Legenda pool back to thirteen).
const liveG2 = true;

// Batch G-3 (decisions-log 243; catalog-design §3.3): the last three new Legenda but the oaths, chest-only and ★1 only
// like G-2's: what it deals heals the most hurt troop near (Vampire Kiss), a healer's heals also smite the monsters next
// to the troop healed (Wrath Psalm), and what it hits can't heal (Grave Seal). Carve moves one named number of each by
// [perStar] a star of worth ([ukirPerStar]).

/// Vampire Kiss: [share] of the HP a troop of the type takes off a monster heals the most hurt other troop within
/// [reach] of it (the lowest share of its max HP, through the heal funnel); the heals a troop of the type gets in a wave
/// land ×[healIn] (the trade, as Rage Totem's). Carve: [share] +[perStar].
const vampireKissK = (share: 0.12, reach: 2 * tile, healIn: 0.6, perStar: 0.03);

/// Wrath Psalm: a heal of a troop healer of the type also strikes each monster within [reach] of the troop healed for
/// [share] of that heal, as a smite (holy light, [Hit.smite]), at most once every [cd] s a healer; the type's heal (a
/// healer's attack) ×[heal] (the trade). Carve: [share] +[perStar].
const wrathPsalmK = (share: 0.3, reach: tile, cd: 2.0, heal: 0.75, perStar: 0.05);

/// Grave Seal: a monster a troop of the type takes HP off heals nothing for [time] s ([Status.noHeal]: its own heals,
/// its healers', the Shadows' heals, Reassemble); the type's attack (a healer's heal) ×[dmg] (the trade). Carve: [time]
/// +[perStar].
const graveSealK = (time: 3.0, dmg: 0.9, perStar: 0.5);

/// Whether batch G-3's rows are in the game ([Art.live]): a probe's mirror turns it off to check that the batch changes
/// nothing else (the chest's Legenda pool back to twenty-one).
const liveG3 = true;

// Batch G-4 (decisions-log 247; catalog-design §3.3): the last six Legenda, the oaths (their numbers are pusaka.dart's,
// beside Oath of One's: [fewOathK] to [spellOathK]). With them the catalog holds its 90 Artifacts, 30 a rarity.

/// Whether batch G-4's rows are in the game ([Art.live]): a probe's mirror turns it off to check that the batch changes
/// nothing else (the chest's Legenda pool back to twenty-four).
const liveG4 = true;

/// The rarities' names, on the cards and in the log ([Words]).
const rarityNames = {Rarity.biasa: Words.common, Rarity.langka: Words.rare, Rarity.epik: Words.epic, Rarity.legenda: Words.legendary};

/// Why the chest can't be dealt with now: the game is over, a wave is on, none waits, or the gold is short for a reroll.
const chestRefusals = (
  over: Words.gameOver,
  midWave: Words.onlyBetweenWaves,
  none: 'No chest',
  gold: Words.notEnoughGold,
);

/// Where a chest came from: a won boss wave, or an old save's catch-up (a "Missed Chest").
enum ChestKind { boss, catchUp }

/// One chest waiting ([Game.chests]): its [kind], the [wave] that brought it, and its [cards] (null: not rolled yet, a
/// catch-up chest is rolled when opened; a null card is a Serpihan). [epik]: the run's first, three different Epik.
/// [rerolls] so far (each doubles the next). A catch-up chest is [n] of [of]. [omens]: the Bayangan each card hides
/// (omen.dart; null: none, a Serpihan's, a chest rolled before [omenFrom] or while [omensOn] was off).
class Chest {
  Chest(this.kind, this.wave, {this.cards, this.omens, this.rerolls = 0, this.epik = false, this.n = 1, this.of = 1});

  final ChestKind kind;
  final int wave, n, of;
  final bool epik;
  List<Relic?>? cards;
  List<OmenKind?>? omens;
  int rerolls;

  /// Its title on the popup: "Boss Chest", or "Missed Chest 1/3".
  String get title => kind == ChestKind.catchUp ? '${Words.missedChest} $n/$of' : Words.bossChest;

  Map<String, Object> toJson() => {
        'kind': kind.name,
        'wave': wave,
        if (cards case final c?) 'cards': [for (final r in c) r?.name ?? 'serpihan'],
        if (omens case final o? when omensOn) 'omens': [for (final k in o) k?.name], // the Bayangan's faces (omen.dart)
        if (rerolls > 0) 'rerolls': rerolls,
        if (epik) 'epik': true,
        if (of > 1) ...{'n': n, 'of': of},
      };

  /// A saved chest; a card naming no Pusaka this build knows is a Serpihan. Its faces only while [omensOn] is on, one a
  /// card (an unknown kind, or a card past the list, none); a chest saved before the Bayangan has none.
  factory Chest.fromJson(Map j) {
    final cards = switch (j['cards']) {
      final List c => [for (final r in c) Relic.values.asNameMap()[r]?.pusaka == true ? Relic.values.asNameMap()[r] : null],
      _ => null,
    };
    return Chest(ChestKind.values.asNameMap()[j['kind']] ?? ChestKind.boss, j['wave'] as int? ?? 0,
        cards: cards,
        omens: switch (j['omens']) {
          final List o when omensOn && cards != null => [
              for (var i = 0; i < cards.length; i++) cards[i] == null || i >= o.length ? null : OmenKind.values.asNameMap()[o[i]],
            ],
          _ => null,
        },
        rerolls: j['rerolls'] as int? ?? 0,
        epik: j['epik'] == true,
        n: j['n'] as int? ?? 1,
        of: j['of'] as int? ?? 1);
  }
}

/// The chest's rules.
extension Draft on Game {
  /// The chest to open now: the next waiting, or null.
  Chest? get chest => chests.firstOrNull;

  /// Why no chest can be opened, taken or rerolled now, in the UI's words, or null.
  String? get whyNotChest => over
      ? chestRefusals.over
      : waveActive
          ? chestRefusals.midWave
          : chests.isEmpty
              ? chestRefusals.none
              : null;

  /// What rerolling [c] costs now: [rerollPrice] × [rerollRise] for each reroll it had; nothing with a Serpihan held.
  int rerollCost(Chest c) => serpihan > 0 ? 0 : (rerollPrice(wave) * pow(rerollRise, c.rerolls)).round();

  /// What passing a chest over (Lewati) pays: [skipShare] of one reroll price.
  int get skipGold => (rerollPrice(wave) * skipShare).round();

  /// Why the open chest can't be rerolled now, or null.
  String? get whyNotReroll => whyNotChest ?? (gold < rerollCost(chests.first) ? chestRefusals.gold : null);

  /// Where [relic]'s card goes: the type it is bound to (a star card), or the one the default rule picks for a new one;
  /// null: the Gudang, or for an oath the whole army ([Relic.oath]).
  String? cardType(Relic relic) => pusaka.containsKey(relic) ? pusaka[relic]!.type : _freeTypeFor(relic);

  /// The stars [relic] has after its card is taken.
  int cardStars(Relic relic) => min(maxStars(relic), (pusaka[relic]?.stars ?? 0) + 1);

  /// Opens the next chest: rolls its cards when it has none yet (a catch-up one; the UI saves after). A card whose Pusaka
  /// reached ★3 since (another chest's) is a Serpihan now, and its Bayangan face goes with it. Its cards, or null when
  /// refused ([whyNotChest]).
  List<Relic?>? openChest() {
    if (whyNotChest != null) return null;
    final c = chests.first;
    if (c.cards == null) _roll(c);
    final cards = c.cards = [for (final r in c.cards!) r != null && _offerable(r) ? r : null];
    if (c.omens case final o?) c.omens = [for (var i = 0; i < cards.length; i++) cards[i] == null || i >= o.length ? null : o[i]];
    return cards;
  }

  /// Takes card [i] of the open chest (Ambil): a new Pusaka is owned at ★1 and bound where [cardType] says (a binding
  /// that doesn't count: its first move is still free, [bindPrice]; an oath works on the whole army at once), an owned
  /// one gets a star, a Serpihan is kept. A Legenda is found ([Game.legendsFound]). The type's troops burst in gold (an
  /// oath's: the whole army). Its Bayangan face, when it hides one (omen.dart), gives the enemy [omenMarks] levels by the
  /// card's rarity, overflowing past [omenCap] ([omenPlace]); the other cards' faces go unseen. False (nothing changes)
  /// when refused.
  bool takeCard(int i) {
    final cards = openChest();
    if (cards == null || i < 0 || i >= cards.length) {
      sfx.add(Sfx.error);
      return false;
    }
    final c = chests.removeAt(0), relic = cards[i], face = omensOn ? c.omens?.elementAtOrNull(i) : null;
    var stars = 0;
    String? type;
    if (relic == null) {
      serpihan++;
    } else if (pusaka[relic] case final p?) {
      stars = p.stars = min(maxStars(relic), p.stars + 1);
      type = p.type;
      if (type != null) _refitType(type);
    } else {
      type = _freeTypeFor(relic);
      pusaka[relic] = OwnedPusaka(type: type);
      stars = 1;
      if (type != null) {
        _refitType(type);
        _emit(PusakaBound(wave, t, relic: relic, type: type, stars: 1, cost: 0));
      }
      if (relic.rarity == Rarity.legenda) legendsFound.add(relic);
      _oathWatch(); // an oath works at once (Oath of One while no more than its types are alive)
    }
    final army = relic != null && relic.oath;
    for (final u in troops) {
      if (u.alive && (army || (type != null && u.type == type))) impacts.add((u.pos, awakeFx('upgrade', maxAwaken))); // a Pusaka's gold
    }
    sfx.add(Sfx.clear);
    final plan = relic != null && face != null ? _omenPlan(face, relic) : const <OmenKind>[];
    _emit(OfferPicked(wave, t,
        pick: relic,
        stars: stars,
        type: type,
        serpihan: relic == null,
        rerolls: c.rerolls,
        chest: c.kind.name,
        chestWave: c.wave,
        omen: face,
        levels: omensOn ? plan : null));
    _omenAdd(plan, 'chest', chestWave: c.wave); // after the card's line: the reveal
    return true;
  }

  /// Rerolls the open chest (Kocok ulang): new cards for [rerollCost], paid with a Serpihan when one is held. False
  /// (nothing changes) when refused ([whyNotReroll]).
  bool rerollChest() {
    if (openChest() == null || whyNotReroll != null) {
      sfx.add(Sfx.error);
      return false;
    }
    final c = chests.first, price = rerollCost(c), token = serpihan > 0;
    if (token) {
      serpihan--;
    } else {
      gold -= price;
    }
    c.rerolls++;
    _emit(OfferRerolled(wave, t, price: price, serpihan: token));
    _roll(c);
    sfx.add(Sfx.magic);
    return true;
  }

  /// Passes the open chest over (Lewati): no card, [skipGold] gold, and no Bayangan. From [omenFrom] (while [omensOn] is
  /// on) the next wave owes the skip buff instead ([Game.skipBuffDue], the owner's rule; step 0d builds it). The gold, or
  /// null when refused.
  int? skipChest() {
    if (openChest() == null) {
      sfx.add(Sfx.error);
      return null;
    }
    final c = chests.removeAt(0), gain = skipGold, buff = omensOn && wave >= omenFrom;
    gold += gain;
    if (buff) skipBuffDue = true;
    _emit(OfferPicked(wave, t,
        skipped: true,
        gain: gain,
        rerolls: c.rerolls,
        chest: c.kind.name,
        chestWave: c.wave,
        levels: omensOn ? const [] : null,
        skipBuff: buff));
    sfx.add(Sfx.kill); // the coin
    return gain;
  }

  /// The card [draftPolicy] takes of [cards]: 'first' the first; 'rarity' the highest rarity (a Serpihan last), then the
  /// one whose type has the most troops alive, then the first. Any other policy throws: a probe's typo fails loudly.
  int policyPick(List<Relic?> cards) {
    switch (draftPolicy) {
      case 'first':
        return 0;
      case 'rarity':
        final counts = troopCounts;
        (int, int) score(Relic? r) => r == null ? (-1, 0) : (r.rarity.index, counts[cardType(r)] ?? 0);
        var best = 0;
        for (var i = 1; i < cards.length; i++) {
          final (a, b) = (score(cards[i]), score(cards[best]));
          if (a.$1 > b.$1 || (a.$1 == b.$1 && a.$2 > b.$2)) best = i;
        }
        return best;
      default:
        throw ArgumentError.value(draftPolicy, 'draftPolicy', "'rarity' or 'first'");
    }
  }

  // The rules' insides.

  /// The won boss wave's chest ([Game.tick]'s win): waiting, its cards rolled now; with a [draftPolicy], taken at once.
  void _bossChest() {
    _giveChests(1);
    if (draftPolicy != null) _pickChests();
  }

  /// [Game.giveChests]: [n] boss chests of this wave, rolled now; the run's first one three different Epik.
  void _giveChests(int n) {
    for (var i = 0; i < n; i++) {
      final c = Chest(ChestKind.boss, wave, epik: chestsGiven == 0);
      chestsGiven++;
      chests.add(c);
      _roll(c);
    }
  }

  /// [Game.pickChests]: every waiting chest taken by [draftPolicy], while one may be ([whyNotChest]). How many.
  int _pickChests() {
    var n = 0;
    while (draftPolicy != null && chests.isNotEmpty && whyNotChest == null) {
      if (!takeCard(policyPick(openChest()!))) break;
      n++;
    }
    return n;
  }

  /// [relic] may be on a card: a Pusaka in the game ([Art.live]) under its top star ([maxStars]); a Legenda only from
  /// [legendFrom], never one found this run ([Game.legendsFound], even once sold), and no oath once one is found (at
  /// most one a run).
  bool _offerable(Relic relic) =>
      relic.pusaka &&
      pusakaCatalog[relic]!.live &&
      (relic.rarity != Rarity.legenda ||
          (wave >= legendFrom && !legendsFound.contains(relic) && !(relic.oath && legendsFound.any((r) => r.oath)))) &&
      (pusaka[relic]?.stars ?? 0) < maxStars(relic);

  /// Rolls [c]'s cards on the [Game.draft] dice: [draftCards] different ones, each of a rarity by the odds of [c]'s own
  /// wave ([chestOddsAt]; the run's first chest all Epik; a [legendPity]th dry chest's first card Epik or better),
  /// stepping down then up when that rarity has none left; a Serpihan when none is left at all. A chest's first roll
  /// counts toward the pity. Then the cards' Bayangan faces, on their own dice ([Omens._faces]), so the cards are the
  /// same with them or without.
  void _roll(Chest c) {
    final first = c.cards == null, pity = first && !c.epik && draftDry >= legendPity - 1;
    final cards = <Relic?>[];
    for (var i = 0; i < draftCards; i++) {
      final open = [for (final r in Relic.values) if (!cards.contains(r) && _offerable(r)) r];
      if (open.isEmpty) {
        cards.add(null);
        continue;
      }
      final pool = _stepped(open, c.epik || (pity && i == 0) ? Rarity.epik : _rollRarity(c.wave));
      cards.add(pool[draft.nextInt(pool.length)]);
    }
    c.cards = cards;
    c.omens = _faces(cards);
    if (first) draftDry = cards.any((r) => r != null && r.rarity.index >= Rarity.epik.index) ? 0 : draftDry + 1;
    _emit(OfferShown(wave, t, cards: cards, omens: c.omens, reroll: c.rerolls, chest: c.kind.name, chestWave: c.wave));
  }

  /// A rarity by the odds of a chest of [chestWave] ([chestOddsAt]), on one [Game.draft] draw.
  Rarity _rollRarity(int chestWave) {
    final odds = chestOddsAt(chestWave), r = draft.nextDouble();
    return r < odds.rare
        ? Rarity.langka
        : r < odds.rare + odds.epic
            ? Rarity.epik
            : Rarity.legenda;
  }

  /// The cards of [open] of rarity [want], or of the nearest rarity below it that has any, else above it.
  List<Relic> _stepped(List<Relic> open, Rarity want) {
    final order = [
      for (var i = want.index; i >= 0; i--) Rarity.values[i],
      for (var i = want.index + 1; i < Rarity.values.length; i++) Rarity.values[i],
    ];
    for (final rarity in order) {
      final pool = [for (final r in open) if (r.rarity == rarity) r];
      if (pool.isNotEmpty) return pool;
    }
    return open;
  }

  /// [Game.fromJson]: the chests waiting, the pity, the chests given and the Serpihan; a save from before the chest (no
  /// `chests` key) gets its catch-up chests instead: one per [catchUpEvery] boss waves won, at most [catchUpMax], rolled
  /// when opened (no dice drawn here, decision 112), the first three Epik.
  void _loadChests(Map<String, dynamic> j) {
    draftDry = j['draftDry'] as int? ?? 0;
    chestsGiven = j['chestsGiven'] as int? ?? 0;
    serpihan = j['serpihan'] as int? ?? 0;
    if (j['chests'] case final List saved) {
      chests.addAll([for (final c in saved) Chest.fromJson(c as Map)]);
      return;
    }
    final n = min(catchUpMax, wave ~/ bossEvery ~/ catchUpEvery);
    for (var i = 1; i <= n; i++) {
      chests.add(Chest(ChestKind.catchUp, wave, epik: chestsGiven == 0 && i == 1, n: i, of: n));
    }
    chestsGiven += n;
  }
}
