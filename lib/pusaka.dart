part of 'game.dart';

// Pusaka (decisions-log 138; docs/loot-items-relics.md, "Pusaka"): the owner, 2026-10-01: "sekarang user bener bener
// nga ada ngerasa apapun dari penggunaan artefaknya". The five artefacts are no longer held by one troop: each is
// bound to a troop TYPE and works on every living troop of it, Heroes and the ones bought later included, and is never
// lost when they fall. A type holds one Pusaka; the rest wait unbound in the Gudang. Each has stars, ★1 to [starMax].
// Binding, unbinding and moving one ("Pindah") happen between waves only; the first binding of each is free, unbinding
// is free, every later binding costs [rerollPrice]. What each one does is its row of Fx in [pusakaCatalog]
// (pusaka_catalog.dart), run by the engine (pusaka_engine.dart): the stat ones (Dragon Heart, Dawn Star) fold into
// [Game.statsOf], so the book and the field agree; the others act in the fight. Every number the owner may tune is one
// constant below.

/// The most stars a Pusaka has: ★1 to ★3 (a duplicate from the chest or Asah adds one, P3 / P6).
const starMax = 3;

/// A Legenda has this many stars, no more: ★1 only (decisions-log 155). One owned is never on a chest's card again.
const legendStars = 1;

/// The most stars [relic] reaches: [starMax], a Legenda [legendStars].
int maxStars(Relic relic) => relic.rarity == Rarity.legenda ? legendStars : starMax;

/// Dragon Heart: max HP ×[hp] (by stars), and [regen] of the max HP back every second. ★1 lets a templar survive one
/// w100 boss blow (design §3.9); ★3 is the old single-troop ×3.
const dragonHeartK = (hp: [1.6, 2.2, 3.0], regen: 0.01);

/// Dawn Star: damage, or a healer's heal, ×[power] (by stars). The old pause cut is gone: 4 of the owner's 5 types
/// already attack at [minAttackInterval].
const dawnStarK = (power: [1.3, 1.45, 1.6]);

/// God's Thunder: every blow or shot of the type that lands (its attacks, not a skill's own blows) leaps from its
/// target to the [jumps] nearest other monsters within [reach] (by stars), each taking [share] of it. At most
/// [beamsPerSec] leaps a second are drawn (beam and spark), over the whole field; the damage is never capped.
const godThunderK = (jumps: [2, 3, 4], reach: 3 * tile, share: 0.4, beamsPerSec: 12);

/// Grail of Immortality: once a wave, each troop of the type survives its first killing blow at [hpLeft] of its max
/// HP (by stars), and no blow hurts it for [time] s (the effect store's [Status.cap] at 0, Bastion's).
const grailK = (hpLeft: [0.3, 0.4, 0.5], time: 2.0);

/// Void Eye: every monster the type hits takes ×[taken] (by stars; the boss ×[boss]) from every troop for [time] s: its
/// own [Status.voidMark], so it stacks with Hunter's Mark ([Status.vulnerable]).
const voidEyeK = (taken: [1.25, 1.35, 1.45], boss: [1.15, 1.2, 1.25], time: 5.0);

/// A Grail save counts as kept ([PusakaTally]) once its troop lives this many seconds more, or to the wave's end.
const keptAfter = 5.0;

// The first three Legenda (decisions-log 155; the chest deals them from wave [legendFrom], each once a run, ★1 only); the
// catalog's other 27 are batch G-1P's to G-4's (draft.dart's constants, and the six oaths' below).

/// Dragon Crown: no blow takes more than this share of a troop's max HP, for every troop of the type it is bound to
/// (its own check in [Game._hurt], after every other cut: a Grail save's and Bastion's [Status.cap] still go under it).
const crownCap = 0.6;

/// Oath of One (an oath, the whole army's; decisions-log 155, 201): while [types] types or fewer are alive, every troop's
/// HP and damage (a healer's heal) are ×[k] and the type caps are off ([Game.typeCapOf]: its types may fill the army); with
/// the caps on no other type joins then ([Game.typeLocked], [oathOneBar]). Above it the oath waits ([oathWaiting]).
const oathOneK = (types: 2, k: 1.5);

/// Alliance (an oath): every troop's HP and damage are +[perType] for each type with a troop alive, at most [most] of
/// them counted (6 types: +30%, its most under decisions-log 141's roster of 6).
const allianceK = (most: 6, perType: 0.05);

// Batch G-4 (decisions-log 247; catalog-design §3.3): the last six Legenda, all oaths: the whole army's, ★1 only, no
// Carve, at most one a run, each a rule with a real cost. Their switch is [liveG4] (draft.dart).

/// Oath of the Few: while [army] troops or fewer are alive, every troop's HP and damage (a healer's heal) are ×[k]; above
/// it the oath waits ([Pusaka.oathWaits]), as Oath of One does, and with the board's army cap on no troop more joins while
/// [army] are alive ([Game.armyLocked], [fewOathBar]), so one tap never ends it. It reads the army's size, not its types.
const fewOathK = (army: 24, k: 1.35);

/// Oath of the Wall: every troop's max HP ×[hp]; its attack (a healer's heal) ×[dmg] (the cost).
const wallOathK = (hp: 1.4, dmg: 0.8);

/// Blood Oath: every troop's attack ×[dmg], a healer's heal not; every heal a troop gets in a wave ×[healIn] (the cost,
/// through the heal funnel; never the Grail's save nor the after-wave heal).
const bloodOathK = (dmg: 1.3, healIn: 0.5);

/// Oath of the Vanguard: every troop that fights up close ([Stats.melee]) has max HP and attack ×[melee]; every other
/// (a shooter, a healer) attack and heal ×[back] (the cost).
const vanguardOathK = (melee: 1.4, back: 0.75);

/// Oath of Kings: a living Hero's aura gives every other troop ×[aura] (not [auraBoost]), and a Hero's own rolled
/// attributes are ×[heroBoost] (not the game's [heroBoost], the cost): [Pusaka.auraNow], [Pusaka.heroBoostNow].
const kingsOathK = (aura: 1.25, heroBoost: 2.0);

/// Oath of Spells: every troop skill's cooldown (its own, its awakening's, a Hero's) ×[cd], never under [cdFloor] nor
/// over the skill's own ([Pusaka.skillCd]); every normal attack's damage ×[blow] (a blow, a shot, a healer's smite: the
/// cost; [FxEngine._blowK]).
const spellOathK = (cd: 0.8, blow: 0.8);

/// The shortest a troop skill's cooldown is made by a multiplier on it (catalog-design §2.3's `cooldown`, Oath of
/// Spells'), in seconds. Since decisions-log 298 the #10 skills come back in 4-6 s, so under the oath a 4 s one stays
/// 4 s (never over its own) and a 6 s one comes back in 5.
const cdFloor = 5.0;

/// Pusaka [relic]'s number at [stars] (clamped to ★1-[starMax]): the one read of every number that goes with a Pusaka's
/// stars, in the rules and in every text (catalog step 0a, Ukir's U1), so nothing else indexes the tables above and in
/// draft.dart (pusaka_at_test.dart checks it). It is [Fx.k] of its [pusakaCatalog] row's Fx number [fx] (the first: the
/// one its texts lead with), which names the table: Dragon Heart's max HP ×, Dawn Star's power ×, God's Thunder's share
/// of a leap, the Grail's HP left, Void Eye's damage taken × ([boss]: on the boss, [Fx.boss]), Iron Banner's cut, Blood
/// Fang's share healed, War Drum's blow ×, Mourning Bell's heal and Dragon Crown's cap.
///
/// [ukir], its Ukir steps (0 to [ukirCost].length; "Ukir" below), adds their worth ([ukirWorthOf], 0.8 star at +5) to
/// the stars: the number goes on in a line between two stars, and past the table's last star by its last gap (★3+5:
/// ★3 + 0.8 × (★3 − ★2)). At 0 it is exactly the table's. A number that is the same at every star moves by its named
/// rule ([ukirPerStar]: God's Thunder's share up, Dragon Crown's cap down, each Legenda's one number), or not at all; a
/// boss's own number ([Fx.boss]) beside it stays. A whole number by stars is [pusakaCountAt]'s, and Ukir never moves it;
/// a number no star changes (a reach, a time) is read from its table. The oaths have none.
double pusakaAt(Relic relic, int stars, {bool boss = false, int fx = 0, int ukir = 0}) {
  final f = pusakaCatalog[relic]?.fx.elementAtOrNull(fx);
  if (f == null || f.k.isEmpty) throw ArgumentError.value(relic, 'relic', 'has no number by stars');
  final k = boss ? f.boss ?? f.k : f.k, worth = ukirWorthOf(ukir);
  if (k.length == 1) {
    final rule = ukirPerStar[relic];
    return worth == 0 || rule == null || rule.fx != fx || (boss && f.boss != null) ? k.first : k.first + rule.per * worth;
  }
  final s = stars.clamp(1, starMax);
  if (worth == 0) return k[s - 1];
  final at = s - 1 + worth, i = min(at.floor(), k.length - 2); // the gap it lies in: the last one past the end
  return k[i] + (at - i) * (k[i + 1] - k[i]);
}

/// Pusaka [relic]'s whole number at [stars] (clamped as [pusakaAt]'s), [Fx.count] of its Fx number [fx]: God's
/// Thunder's leaps. It reads the stars only (Ukir never moves it).
int pusakaCountAt(Relic relic, int stars, {int fx = 0}) {
  final f = pusakaCatalog[relic]?.fx.elementAtOrNull(fx);
  if (f == null || f.count.isEmpty) throw ArgumentError.value(relic, 'relic', 'has no whole number by stars');
  return f.count.length == 1 ? f.count.first : f.count[stars.clamp(1, starMax) - 1];
}

/// What a Legenda is worth ([Store.basePrice]): Dragon Crown in the Gudang sells back for [sellShare] of it. An oath is
/// never in the Gudang, so it never sells.
const legendaPrice = 40000;

/// Oath of One's words while more types than its own are alive: it does nothing yet (the item text, in English,
/// decisions-log 168). [oathWaitingRow]: the same for a Tas row, short enough for a phone's, with the [types] alive now.
/// [oathWaitingNote]: the chest's message when it is taken.
final oathWaiting = 'Waiting: keep only ${oathOneK.types} types', oathWaitingNote = 'Oath waits: keep only ${_count(oathOneK.types, 'type')}';
String oathWaitingRow(int types) => 'Waiting: $types/${oathOneK.types} types';

/// The oaths ([Relic.oath]), in [Relic] order: what [Pusaka.oath] looks through.
final _oaths = [for (final r in Relic.values) if (r.oath) r];

/// Why Oath of One bars a type with none alive ([Game.typeLocked], decisions-log 201): its types are set.
final oathOneBar = 'Oath of One: only ${oathOneK.types} types';

/// Oath of the Few's words while more troops than its own are alive (decisions-log 247), as Oath of One's above: the
/// item text ([fewWaiting]), a Bag row's with the troops alive now ([fewWaitingRow]), the chest's message
/// ([fewWaitingNote]); and why no troop more joins while its [fewOathK].army are alive ([Game.armyLocked]).
final fewWaiting = 'Waiting: keep ${fewOathK.army} troops or fewer', fewWaitingNote = 'Oath waits: keep ${fewOathK.army} troops or fewer';
String fewWaitingRow(int troops) => 'Waiting: $troops/${fewOathK.army} troops';
final fewOathBar = 'Oath of the Few: up to ${fewOathK.army} troops';

/// The waiting oath's words ([Pusaka.oathWaits]): Oath of One's or Oath of the Few's, by [relic]; the row's with [alive],
/// the types or troops alive now.
String oathWaitingOf(Relic relic) => relic == Relic.fewOath ? fewWaiting : oathWaiting;
String oathWaitingNoteOf(Relic relic) => relic == Relic.fewOath ? fewWaitingNote : oathWaitingNote;
String oathWaitingRowOf(Relic relic, int alive) => relic == Relic.fewOath ? fewWaitingRow(alive) : oathWaitingRow(alive);

/// What a reroll of the chest costs on [wave] (P3), rounded to 100: 700 on wave 5, 2.5k on 30, 38k on 86. A Pindah costs
/// [pindahShare] of it.
int rerollPrice(int wave) => (600 * pow(1.05, wave - 1) / 100).round() * 100;

/// A Pindah (a binding after the first: moving a Pusaka, or binding it again from the Gudang) costs this share of
/// [rerollPrice]; the first binding and unbinding are free.
const pindahShare = 1.0;

/// Whether a Pusaka can be bound, moved or unbound while a wave is on: no, between waves only (like the store).
const bindMidWave = false;

/// A store copy of a Pusaka already owned is refused ("Dimiliki"): a purchase that does nothing is a trap (critique C3).
/// A copy found in an old save adds a star instead, up to [starMax]; past it, it pays back [copyRefund] of its base price.
const copyRefund = 0.5;

/// Build names (decisions-log 149): a type with a Pusaka bound goes by its name with the Pusaka's epithet ([Art.epithet])
/// before it on its Pasukan row and its troops' plates, "Undying Templar" ([Pusaka.buildNameOf]). A Pusaka without one (an oath)
/// gives no build name.
final buildEpithets = <Relic, String>{
  for (final MapEntry(key: r, value: art) in pusakaCatalog.entries) r: ?art.epithet,
};

/// A Pusaka's name where a line is short (the "MENANG!" line, the cut-in): the Grail without "of Immortality".
String pusakaShortName(Relic relic) => relic == Relic.grail ? 'Grail' : relicNames[relic]!;

/// One bound Pusaka's wave ([PusakaReport]): its type, stars and tally ([PusakaTally]: [uses], [worth]).
typedef PusakaDone = ({Relic relic, String type, int stars, int uses, double worth});

/// One of the forge's small relics' wave ([PusakaReport.relics], decisions-log 250): its tally over every troop holding
/// one ([Game.relicWorth]: [uses], [worth]).
typedef RelicDone = ({Relic relic, int uses, double worth});

/// The default binding (the migration of a save from before the Pusaka, a new one taken from the boss's chest, draft.dart,
/// and PUSAKA=bound in the probes): each Pusaka in turn, in this order, goes to the first living type on its list that
/// holds none yet (critique M1). One with no such type stays in the Gudang.
const pusakaPrefs = <Relic, List<String>>{
  Relic.dragonHeart: ['knight_templar', 'knight', 'armored_axeman', 'lancer', 'swordsman', 'soldier'],
  Relic.grail: ['armored_axeman', 'knight_templar', 'knight', 'swordsman', 'lancer', 'soldier'],
  Relic.godThunder: ['wizard', 'armored_axeman', 'archer', 'lancer', 'swordsman', 'knight'],
  Relic.dawnStar: ['priest', 'wizard', 'archer', 'knight_templar'],
  Relic.voidEye: ['archer', 'wizard', 'lancer', 'armored_axeman'],
  // The chest's Langka (draft.dart): the guard and the bell to the front, the fang and the drum to the hitters.
  Relic.ironBanner: ['knight_templar', 'armored_axeman', 'knight', 'lancer', 'soldier', 'swordsman'],
  Relic.bloodFang: ['swordsman', 'armored_axeman', 'knight', 'lancer', 'knight_templar', 'soldier', 'archer', 'wizard'],
  Relic.warDrum: ['wizard', 'archer', 'armored_axeman', 'lancer', 'swordsman', 'knight', 'knight_templar', 'soldier'],
  Relic.mourningBell: ['knight_templar', 'armored_axeman', 'knight', 'soldier', 'swordsman', 'lancer'],
  // The Legenda on a type (decisions-log 155): the front, which the boss's blows fell (the oaths go to no type).
  Relic.dragonCrown: ['knight_templar', 'armored_axeman', 'knight', 'lancer', 'swordsman', 'soldier'],
  // Batch L-1P's Langka (draft.dart, decisions-log 205): the damage ones to the hitters (the slow to the shooters, Twin
  // Fury to the front, where a worn fury hits most), the guard ones to the front, Challenge Letter to the melee only
  // (its taunt needs a melee holder).
  Relic.titanBane: ['wizard', 'archer', 'armored_axeman', 'lancer', 'swordsman', 'knight', 'knight_templar', 'soldier'],
  Relic.finishingBlade: ['archer', 'wizard', 'swordsman', 'lancer', 'armored_axeman', 'knight', 'soldier', 'knight_templar'],
  Relic.firstCut: ['wizard', 'archer', 'armored_axeman', 'lancer', 'swordsman', 'knight', 'soldier', 'knight_templar'],
  Relic.shellCracker: ['archer', 'wizard', 'lancer', 'armored_axeman', 'swordsman', 'knight', 'soldier', 'knight_templar'],
  Relic.twinFury: ['swordsman', 'armored_axeman', 'knight', 'lancer', 'soldier', 'knight_templar', 'archer', 'wizard'],
  Relic.steadyStance: ['knight_templar', 'armored_axeman', 'knight', 'lancer', 'soldier', 'swordsman'],
  Relic.turtleShell: ['knight_templar', 'knight', 'armored_axeman', 'soldier', 'lancer', 'swordsman'],
  Relic.dullingMail: ['knight_templar', 'armored_axeman', 'knight', 'soldier', 'lancer', 'swordsman'],
  Relic.challengeLetter: ['knight_templar', 'knight', 'armored_axeman', 'soldier', 'lancer', 'swordsman'],
  Relic.snareCord: ['archer', 'wizard', 'lancer', 'soldier', 'swordsman', 'knight', 'armored_axeman', 'knight_templar'],
  // Batch L-2P's Langka (draft.dart, decisions-log 207): the kill and hit ones to the hitters, the shields, Pain Crystal
  // and Riposte to the front, where the blows land.
  Relic.momentum: ['archer', 'wizard', 'swordsman', 'lancer', 'armored_axeman', 'knight', 'soldier', 'knight_templar'],
  Relic.bleedingEdge: ['swordsman', 'archer', 'lancer', 'armored_axeman', 'knight', 'soldier', 'wizard', 'knight_templar'],
  Relic.shatterShard: ['archer', 'lancer', 'armored_axeman', 'swordsman', 'knight', 'soldier', 'knight_templar', 'wizard'],
  Relic.painCrystal: ['knight_templar', 'knight', 'armored_axeman', 'soldier', 'lancer', 'swordsman'],
  Relic.watchShield: ['knight_templar', 'knight', 'armored_axeman', 'soldier', 'lancer', 'swordsman'],
  Relic.boneBuckler: ['armored_axeman', 'swordsman', 'knight', 'lancer', 'soldier', 'knight_templar'],
  Relic.riposte: ['knight_templar', 'knight', 'armored_axeman', 'soldier', 'swordsman', 'lancer'],
  Relic.manaLeech: ['wizard', 'archer', 'lancer', 'swordsman', 'soldier', 'knight', 'armored_axeman', 'knight_templar'],
  Relic.lootersPouch: ['archer', 'wizard', 'lancer', 'swordsman', 'armored_axeman', 'knight', 'soldier', 'knight_templar'],
  Relic.spellCutter: ['archer', 'wizard', 'lancer', 'swordsman', 'armored_axeman', 'knight', 'soldier', 'knight_templar'],
  // Batch L-3's Langka (draft.dart, decisions-log 209): Salt Charm, Hidden Flask and Living Moss to the front, where the
  // blows land; Wolf Feast to the hitters up close, as Blood Fang; Full Cup and Pure Water to the healers alone (their
  // trigger is a heal).
  Relic.saltCharm: ['knight_templar', 'knight', 'armored_axeman', 'soldier', 'lancer', 'swordsman'],
  Relic.wolfFeast: ['swordsman', 'armored_axeman', 'knight', 'lancer', 'knight_templar', 'soldier', 'archer', 'wizard'],
  Relic.fullCup: ['priest'],
  Relic.hiddenFlask: ['knight_templar', 'knight', 'armored_axeman', 'soldier', 'lancer', 'swordsman'],
  Relic.livingMoss: ['knight_templar', 'armored_axeman', 'knight', 'soldier', 'lancer', 'swordsman'],
  Relic.pureWater: ['priest'],
  // Batch E-1P's Epik (draft.dart, decisions-log 211): the powers to the hitters (Healer Bane to the shooters, who reach
  // the healers at the back; Bully's Club up close, beside the lancers' pins and the axemen's stuns; Rune Gauntlet to
  // the casters), Hawk Feather to the shooters (no healer: its trade cuts the heal), the guard ones to the front (Hero's
  // Cloak wherever a Hero may be), Moonwell to the casters with the most MP.
  Relic.healerBane: ['archer', 'wizard', 'lancer', 'swordsman', 'armored_axeman', 'knight', 'soldier', 'knight_templar'],
  Relic.bullyClub: ['armored_axeman', 'swordsman', 'lancer', 'knight', 'archer', 'wizard', 'soldier', 'knight_templar'],
  Relic.unityRing: ['wizard', 'archer', 'armored_axeman', 'lancer', 'swordsman', 'knight', 'soldier', 'knight_templar'],
  Relic.runeGauntlet: ['wizard', 'archer', 'lancer', 'armored_axeman', 'swordsman', 'knight', 'soldier', 'knight_templar'],
  Relic.hawkFeather: ['archer', 'wizard', 'lancer', 'swordsman', 'soldier', 'knight', 'armored_axeman', 'knight_templar'],
  Relic.witherroot: ['knight_templar', 'armored_axeman', 'knight', 'soldier', 'lancer', 'swordsman', 'archer', 'wizard'],
  Relic.arrowCatcher: ['knight_templar', 'knight', 'armored_axeman', 'soldier', 'lancer', 'swordsman'],
  Relic.stoneCoat: ['knight_templar', 'armored_axeman', 'knight', 'soldier', 'lancer', 'swordsman'],
  Relic.heroCloak: ['knight_templar', 'knight', 'armored_axeman', 'swordsman', 'lancer', 'soldier', 'archer', 'wizard'],
  Relic.moonwell: ['wizard', 'priest', 'archer', 'lancer', 'armored_axeman', 'swordsman', 'knight', 'soldier', 'knight_templar'],
  // Batch E-2P's Epik (draft.dart, decisions-log 214): Ember Brand to the shooters (they mark what the front then hits),
  // Funeral Pyre to the hitters that kill in crowds, the guard ones and Null Stone to the front, where the blows land
  // (Warden's Horn to the melee only: its taunt needs a melee holder), Fallen Flag to the front that falls first, Aegis
  // Seal to the casters up front.
  Relic.emberBrand: ['archer', 'wizard', 'swordsman', 'lancer', 'armored_axeman', 'knight', 'soldier', 'knight_templar'],
  Relic.funeralPyre: ['wizard', 'archer', 'armored_axeman', 'swordsman', 'lancer', 'knight', 'soldier', 'knight_templar'],
  Relic.nullStone: ['knight_templar', 'knight', 'armored_axeman', 'soldier', 'lancer', 'swordsman'],
  Relic.fallenFlag: ['soldier', 'swordsman', 'knight', 'lancer', 'armored_axeman', 'knight_templar'],
  Relic.aegisSeal: ['knight_templar', 'knight', 'armored_axeman', 'soldier', 'lancer', 'swordsman', 'wizard', 'archer'],
  Relic.wardensHorn: ['knight_templar', 'knight', 'armored_axeman', 'soldier', 'lancer', 'swordsman'],
  Relic.anchor: ['knight_templar', 'armored_axeman', 'knight', 'soldier', 'lancer', 'swordsman'],
  // Batch E-3P's Epik (draft.dart, decisions-log 223): the healer's own (Mana Hymn, Brave Song, Halo Lantern) to the
  // healers alone (their trigger is a heal); Mercy Lily, Hearth and Saint's Tear to the front, where the low troops and
  // the monsters' bad effects are; Heartbeat to the hitters up close in a crowd; Bright Spring to the casters up front.
  Relic.manaHymn: ['priest'],
  Relic.saintTear: ['knight_templar', 'knight', 'armored_axeman', 'soldier', 'lancer', 'swordsman', 'priest', 'wizard', 'archer'],
  Relic.braveSong: ['priest'],
  Relic.haloLantern: ['priest'],
  Relic.hearth: ['knight_templar', 'armored_axeman', 'knight', 'soldier', 'lancer', 'swordsman', 'archer', 'wizard'],
  Relic.heartbeat: ['soldier', 'swordsman', 'knight', 'lancer', 'armored_axeman', 'knight_templar', 'archer', 'wizard'],
  Relic.mercyLily: ['knight_templar', 'knight', 'armored_axeman', 'soldier', 'lancer', 'swordsman'],
  Relic.brightSpring: ['knight_templar', 'knight', 'armored_axeman', 'soldier', 'lancer', 'swordsman', 'priest', 'wizard', 'archer'],
  // Batch G-1P's Legenda (draft.dart, decisions-log 231): Lone Wolf Pelt to the types an army holds few of, Martyr's
  // Flame to the front that falls first, Wide Blows to the hitters up close, Champion's Mantle where a Hero stands, the
  // ones that answer a blow (Vengeance Mark, Mirror Shield, Ghost Step) to the front, Ice Grip to the shooters and the
  // lancers, Relic Altar to the hitters that wear the relics, Vow of Silence to the types whose skills weigh least (never
  // a healer: its heals are its worth).
  Relic.loneWolf: ['knight_templar', 'wizard', 'lancer', 'armored_axeman', 'archer', 'swordsman', 'knight', 'soldier'],
  Relic.martyrFlame: ['soldier', 'swordsman', 'knight', 'lancer', 'armored_axeman', 'knight_templar'],
  Relic.wideBlows: ['swordsman', 'armored_axeman', 'knight', 'lancer', 'soldier', 'knight_templar', 'archer', 'wizard'],
  Relic.champion: ['knight', 'knight_templar', 'swordsman', 'lancer', 'armored_axeman', 'soldier', 'archer', 'wizard'],
  Relic.vengeance: ['knight_templar', 'knight', 'armored_axeman', 'soldier', 'lancer', 'swordsman'],
  Relic.mirror: ['knight_templar', 'knight', 'armored_axeman', 'soldier', 'lancer', 'swordsman'],
  Relic.ghostStep: ['knight_templar', 'knight', 'armored_axeman', 'soldier', 'lancer', 'swordsman'],
  Relic.iceGrip: ['archer', 'wizard', 'lancer', 'swordsman', 'soldier', 'knight', 'armored_axeman', 'knight_templar'],
  Relic.relicAltar: ['swordsman', 'armored_axeman', 'knight', 'lancer', 'knight_templar', 'soldier', 'archer', 'wizard'],
  Relic.vowSilence: ['soldier', 'swordsman', 'knight', 'lancer', 'armored_axeman', 'knight_templar', 'archer', 'wizard'],
  // Batch G-2's Legenda (draft.dart, decisions-log 238): Rage Totem to the hitters up front that get low (never a
  // healer: its trade cuts the heals it gets), Guardian Chain and Phalanx to the front that stands among the others,
  // Phoenix Plume and Soul Shelter to the front that falls first, Mana Font to the casters (as Moonwell), Hex Blade to
  // the shooters with many hits (as Ice Grip), Glory Seeker to the hitters that kill the strong ones.
  Relic.rageTotem: ['armored_axeman', 'swordsman', 'knight', 'soldier', 'lancer', 'knight_templar', 'archer', 'wizard'],
  Relic.guardianChain: ['knight_templar', 'knight', 'armored_axeman', 'soldier', 'lancer', 'swordsman'],
  Relic.phalanx: ['soldier', 'knight', 'knight_templar', 'lancer', 'swordsman', 'armored_axeman'],
  Relic.phoenix: ['soldier', 'swordsman', 'knight', 'lancer', 'armored_axeman', 'knight_templar', 'archer', 'wizard', 'priest'],
  Relic.soulShelter: ['soldier', 'swordsman', 'knight', 'lancer', 'armored_axeman', 'knight_templar'],
  Relic.manaFont: ['wizard', 'priest', 'archer', 'lancer', 'armored_axeman', 'swordsman', 'knight', 'soldier', 'knight_templar'],
  Relic.hexBlade: ['archer', 'wizard', 'swordsman', 'lancer', 'soldier', 'knight', 'armored_axeman', 'knight_templar'],
  Relic.glorySeeker: ['swordsman', 'armored_axeman', 'lancer', 'knight', 'archer', 'wizard', 'soldier', 'knight_templar'],
  // Batch G-3's Legenda (draft.dart, decisions-log 243): Vampire Kiss to the hitters in the thick of it, with others hurt
  // near them (never a healer: its trade cuts the heals it gets), Wrath Psalm to the healers alone (as Full Cup: only a
  // healer's heal sets it off), Grave Seal to the hitters that land the most blows on the monsters that heal.
  Relic.vampireKiss: ['swordsman', 'knight', 'soldier', 'lancer', 'armored_axeman', 'knight_templar', 'archer', 'wizard'],
  Relic.wrathPsalm: ['priest'],
  Relic.graveSeal: ['archer', 'wizard', 'swordsman', 'lancer', 'soldier', 'knight', 'armored_axeman', 'knight_templar'],
};

/// The one-time message ([Game.notes]) about the artefacts turned Pusaka, for a save from before them (P1b shows it,
/// with Undo: [Pusaka.undoDefaultBinding]): "Your Artifacts now work for a whole type, troops bought later too, and are
/// never lost. Put on for you: change or Undo in the Bag." ([pusakaNoteLines]).
const pusakaNote = 'pusaka';

/// A Pusaka refused on one troop ([Game.relicRefusal]).
const pusakaOnType = 'Artifacts go on a type, not one troop';

/// Who a Pusaka works on, the book's words for it ([Game.relicInfo]): every troop of its type, the ones bought later
/// too, and it isn't lost when they fall; an oath's catch: it stays for the whole run.
const pusakaLine = 'For a whole type, never lost', oathLine = 'Lasts the whole run';

/// Why a Pusaka can't be bound, moved or unbound now ([Pusaka.whyNotBind], [Pusaka.whyNotUnbind]), besides
/// [assignRefusals].over: a wave is on ([bindMidWave]), it isn't owned, it is on that type already, the gold is short
/// for a Pindah, it is in the Gudang already, or the type isn't a troop type; and why the save's suggestion can't be
/// undone: none of it is left ([Pusaka.whyNotUndoDefault]).
const pusakaRefusals = (
  midWave: Words.onlyBetweenWaves,
  none: 'Not owned yet',
  same: 'Already on this type',
  gold: Words.notEnoughGold,
  unbound: 'Already in ${Words.vault}',
  notType: 'Not a troop type',
  noSuggestion: 'No suggestion left',
  oath: '${Words.oath}: for all troops',
);

/// What a tap on a type's row does with a Pusaka picked on the Tas page (P1b, [Pusaka.pusakaPreview]): binds it there,
/// the first time free ([pasang]); binds it there for [Pusaka.bindPrice], from another type or again from the Gudang
/// ([pindah]); or, on the type it is bound to, sends it back to the Gudang, free ([lepas]). An oath binds nowhere: its
/// rows show what it gives each type ([sumpah]), and a tap says how it stands.
enum PusakaAction { pasang, pindah, lepas, sumpah }

/// Each [PusakaAction] in the Bag page's words (decisions-log 187).
const pusakaActionNames = {
  PusakaAction.pasang: Words.equip,
  PusakaAction.pindah: Words.move,
  PusakaAction.lepas: Words.toVault,
  PusakaAction.sumpah: 'All troops',
};

/// What a tap on [type]'s row would do with a Pusaka ([Pusaka.pusakaPreview]): [why] it can't now ([Pusaka.whyNotBind]
/// / [Pusaka.whyNotUnbind]; null: it can), the [action] and its [price]; how many troops of the type are [alive]; the
/// type's [stats] that change, (kind, now, after) as [Game.assignPreview] gives them, as its troops fight
/// ([Pusaka.fieldStats]; a binding that sends another Pusaka to the Gudang loses that one's too); and when its HP
/// changes, the [blows] of the next boss ([bossWave]) a troop of it lives through from full HP, now and after
/// ([Pusaka.bossBlowsLived], critique H1).
typedef PusakaPreview = ({
  String? why,
  PusakaAction action,
  int price,
  int alive,
  List<(StatKind, num, num)> stats,
  (int, int)? blows,
  int bossWave,
});

/// The Bag page's words for [PusakaPreview.blows] on [wave]; [short] where the row is narrow (a phone's).
String bossBlowsLabel(int wave, {bool short = false}) => short ? 'Boss hits (w$wave)' : 'Boss hits lived (wave $wave)';

/// The Pusaka's one-time message ([pusakaNote]) as the message window shows it, once, when the save comes in, a line
/// each ([Pusaka.pusakaNotes]); and the Tas page's strip that keeps the suggestion's OK and Batal while it stands
/// ([Pusaka.pusakaSuggested]: until the player picks one, moves every suggested one, or starts a wave). The last two
/// name the Bag page and its Undo, in English like them (decisions-log 187).
const pusakaNoteLines = [
  'Your Artifacts now work for a whole type,',
  'troops bought later too, and are never lost.',
];
const pusakaNoteSuggested = 'Put on for you: change or Undo in the Bag.', pusakaNoteNone = 'Equip them in the Bag.';
const pusakaNoteStrip = 'Suggested Artifacts are on';

/// What Pusaka [relic] does at [stars] and [ukir] steps, in a few words for a Tas row: what a row that changes no stat
/// shows ([PusakaPreview.stats] empty), e.g. "Hits 2 more, 40%".
String pusakaGist(Relic relic, int stars, {int ukir = 0}) {
  String share(double s) => '${(s * 100).round()}%';
  return switch (relic) {
    // The oaths' bespoke rules (decisions-log 155).
    Relic.oathOfOne => '${oathOneK.types} types: ${_pct(oathOneK.k)}',
    Relic.alliance => '${allianceK.most} types: +${share(allianceK.perType)} each',
    // Batch G-4's (decisions-log 247).
    Relic.fewOath => '${fewOathK.army} troops: ${_pct(fewOathK.k)}',
    Relic.wallOath => '${_pct(wallOathK.hp)} HP, ${_pct(wallOathK.dmg)} attack',
    Relic.bloodOath => '${_pct(bloodOathK.dmg)} attack, ${_pct(bloodOathK.healIn)} heals',
    Relic.vanguardOath => 'Up close ${_pct(vanguardOathK.melee)}, others ${_pct(vanguardOathK.back)}',
    Relic.kingsOath => 'Aura ${_pct(kingsOathK.aura)}, Heroes x${_x(kingsOathK.heroBoost)}',
    Relic.spellOath => 'Skills ${share(1 - spellOathK.cd)} sooner, hits ${_pct(spellOathK.blow)}',
    _ when relic.pusaka => fxGist(relic, stars, ukir: ukir), // its row's template (pusaka_catalog.dart)
    _ => relicNames[relic]!,
  };
}

/// [n] with its thousands marked the English way, wherever the game writes a whole number of gold or HP (decisions-log
/// 168, 200): 4524 as "4,524", -1803245 as "-1,803,245". Short prices ("2.5k") are [shortPrice].
String thousands(int n) {
  final digits = '${n.abs()}', out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return '$out';
}

/// One owned Pusaka ([Game.pusaka]): the troop type it is bound to (null: in the Gudang), its stars, how many times it
/// has been bound (0: the next binding is free), whether its binding is the migration's suggestion, which Batal
/// still takes back ([Pusaka.undoDefaultBinding]), its Ukir steps taken and the points on its next step's bar
/// ([Ukir.feedUkir]).
class OwnedPusaka {
  OwnedPusaka({this._type, this._stars = 1, this.binds = 0, this.suggested = false, this._ukir = 0, this.feed = 0}); // type:, stars:, ukir:

  String? _type;
  int _stars, _ukir;
  int binds;
  bool suggested;

  /// The points fed toward its next Ukir step ([ukirCost] of [ukir]); 0 at the last.
  int feed;

  /// Its Ukir steps taken, 0 to [ukirCost].length; a change rebuilds the books, as its stars do.
  int get ukir => _ukir;
  set ukir(int to) {
    _ukir = to;
    _pusakaEdits++;
  }

  /// Its type; a change rebuilds the books ([_pusakaEdits], pusaka_engine.dart).
  String? get type => _type;
  set type(String? to) {
    _type = to;
    _pusakaEdits++;
  }

  /// Its stars; a change rebuilds the books too.
  int get stars => _stars;
  set stars(int to) {
    _stars = to;
    _pusakaEdits++;
  }

  /// Its Ukir is written only once fed, so a save without it loads (and writes) as before.
  Map<String, Object> toJson() => {
        'type': ?type,
        'stars': stars,
        if (binds > 0) 'binds': binds,
        if (suggested) 'suggested': true,
        if (ukir > 0) 'ukir': ukir,
        if (feed > 0) 'feed': feed,
      };
}

/// What one Pusaka did in the wave being fought ([Game.pusakaWorth], H3c), by its family ([FxFamily], its first Fx's
/// effect): [uses], the Grail's saves; and [worth], its effective counter: the Grail's saves kept (its troop alive
/// [keptAfter] s later, or at the wave's end), Dragon Heart's blows survived that would have killed at base HP, Dawn
/// Star's extra healing that landed (no overheal) and extra damage, God's Thunder's leap damage and Void Eye's bonus
/// damage (each at most the target's HP left).
class PusakaTally {
  int uses = 0;
  double worth = 0;
}

/// The Pusaka's rules, and the hooks game.dart and store.dart call.
extension Pusaka on Game {
  /// The stars of [relic] on troop [u]'s type: 0 when it isn't bound there (or [u] is a monster).
  int pusakaLevel(Unit u, Relic relic) {
    final p = pusaka[relic];
    return p != null && p.type == u.type && u.side == Side.troop ? p.stars : 0;
  }

  /// The Pusaka bound to [type], or null.
  Relic? pusakaOf(String type) {
    for (final MapEntry(key: r, value: p) in pusaka.entries) {
      if (p.type == type) return r;
    }
    return null;
  }

  /// [type]'s build name, the epithet first ([buildEpithets]: "Undying Templar"), or null: no Pusaka bound to it, or one
  /// without an epithet.
  String? buildNameOf(String type) => switch (pusakaOf(type)) {
        final r? when buildEpithets.containsKey(r) => '${buildEpithets[r]} ${troopTypeNames[type] ?? type}',
        _ => null,
      };

  /// What this wave's Pusaka did, at its win ([PusakaReport]): every bound one with its tally, in [Relic] order, each of
  /// the forge's small relics that did something ([Game.relicWorth]), and the small relics back in
  /// the bag from falls ([Game.relicsBack]); null when none is bound, none did anything and none came back.
  PusakaReport? _pusakaReport() {
    final lines = <PusakaDone>[
      for (final r in Relic.values)
        if (pusaka[r] case OwnedPusaka(type: final type?, :final stars))
          (relic: r, type: type, stars: stars, uses: pusakaWorth[r]?.uses ?? 0, worth: pusakaWorth[r]?.worth ?? 0),
    ];
    final relics = <RelicDone>[
      for (final r in forgeRelics)
        if (relicWorth[r] case final w? when w.uses > 0) (relic: r, uses: w.uses, worth: w.worth),
    ];
    if (lines.isEmpty && relics.isEmpty && relicsBack.isEmpty) return null;
    return PusakaReport(wave, t, lines: lines, relics: relics, returned: {...relicsBack});
  }

  /// The Pusaka in the Gudang: owned, bound to no type (an oath is the army's, never in it).
  List<Relic> get gudang => [for (final MapEntry(key: r, value: p) in pusaka.entries) if (p.type == null && !r.oath) r];

  /// [relic] is bound but no troop of its type lives: it does nothing for now ("tidur").
  bool pusakaAsleep(Relic relic) => switch (pusaka[relic]?.type) {
        final t? => !troops.any((u) => u.alive && u.type == t),
        null => false,
      };

  /// What binding [relic] costs now: nothing the first time, else a Pindah ([pindahShare] of [rerollPrice]).
  int bindPrice(Relic relic) => (pusaka[relic]?.binds ?? 0) == 0 ? 0 : (rerollPrice(wave) * pindahShare).round();

  /// Why [relic] can't be bound to [type] now, in the UI's words, or null.
  String? whyNotBind(Relic relic, String type) {
    if (over) return assignRefusals.over;
    if (!bindMidWave && waveActive) return pusakaRefusals.midWave;
    if (!troopTypes.containsKey(type)) return pusakaRefusals.notType;
    final p = pusaka[relic];
    if (p == null) return pusakaRefusals.none;
    if (relic.oath) return pusakaRefusals.oath; // the whole army's, bound to no type
    if (p.type == type) return pusakaRefusals.same;
    return gold < bindPrice(relic) ? pusakaRefusals.gold : null;
  }

  /// Binds [relic] to [type], from the Gudang or from another type (a Pindah), for [bindPrice]: every troop of [type]
  /// gets it now and later. A Pusaka [type] held goes to the Gudang. A refusal ([whyNotBind]) plays the error and
  /// changes nothing.
  bool bindPusaka(Relic relic, String type) {
    if (whyNotBind(relic, type) != null) {
      sfx.add(Sfx.error);
      return false;
    }
    final p = pusaka[relic]!, price = bindPrice(relic), from = p.type;
    gold -= price;
    if (pusakaOf(type) case final other?) {
      pusaka[other]!
        ..type = null
        ..suggested = false;
      _emit(PusakaMoved(wave, t, relic: other, from: type, cost: 0));
    }
    p
      ..type = type
      ..binds += 1
      ..suggested = false;
    _refitType(type);
    if (from != null) _refitType(from);
    _emit(from == null
        ? PusakaBound(wave, t, relic: relic, type: type, stars: p.stars, cost: price)
        : PusakaMoved(wave, t, relic: relic, from: from, to: type, cost: price));
    for (final u in troops) {
      if (u.alive && u.type == type) impacts.add((u.pos, awakeFx('upgrade', maxAwaken))); // a Pusaka's burst is gold
    }
    sfx.add(Sfx.magic);
    return true;
  }

  /// Why [relic] can't go back to the Gudang now, or null.
  String? whyNotUnbind(Relic relic) {
    if (over) return assignRefusals.over;
    if (!bindMidWave && waveActive) return pusakaRefusals.midWave;
    final p = pusaka[relic];
    if (p == null) return pusakaRefusals.none;
    if (relic.oath) return pusakaRefusals.oath; // an oath is for the run
    return p.type == null ? pusakaRefusals.unbound : null;
  }

  /// Unbinds [relic] into the Gudang, free; its type's troops lose it (without Dragon Heart the HP is cut to the max).
  bool unbindPusaka(Relic relic) {
    if (whyNotUnbind(relic) != null) {
      sfx.add(Sfx.error);
      return false;
    }
    _toGudang(relic);
    sfx.add(Sfx.place);
    return true;
  }

  /// The one-time message about the artefacts turned Pusaka is still to be shown ([pusakaNote]).
  bool get pusakaNoteDue => !notes.contains(pusakaNote);

  /// The one-time message's lines ([pusakaNoteLines], the last saying whether a suggestion was bound), marked shown so
  /// they show once, like [Game.limitNotes]; none when it was shown, or with no Pusaka. The suggestion stays
  /// ([pusakaSuggested]): the Tas page keeps its OK and Undo.
  List<String> pusakaNotes() {
    if (!pusakaNoteDue || pusaka.isEmpty) return const [];
    notes.add(pusakaNote);
    return [...pusakaNoteLines, pusakaSuggested ? pusakaNoteSuggested : pusakaNoteNone];
  }

  /// Some Pusaka is still bound by the migration's suggestion, which Batal takes back ([undoDefaultBinding]).
  bool get pusakaSuggested => pusaka.values.any((p) => p.suggested);

  /// The message was shown and kept: its suggestion stands (a later move is a Pindah).
  void dismissPusakaNote() {
    notes.add(pusakaNote);
    for (final p in pusaka.values) {
      p.suggested = false;
    }
  }

  /// Why the message's Batal can't be done now ([undoDefaultBinding]), or null: after game over, mid-wave, or with no
  /// suggestion left.
  String? get whyNotUndoDefault => over
      ? assignRefusals.over
      : !bindMidWave && waveActive
          ? pusakaRefusals.midWave
          : pusaka.values.any((p) => p.suggested)
              ? null
              : pusakaRefusals.noSuggestion;

  /// The message's Batal: every Pusaka the migration bound goes to the Gudang, and its first binding stays free. False
  /// (nothing changes) when [whyNotUndoDefault] refuses.
  bool undoDefaultBinding() {
    final undo = [for (final p in pusaka.values) if (p.suggested) p];
    if (whyNotUndoDefault != null) return false;
    for (final p in undo) {
      final from = p.type;
      p
        ..type = null
        ..binds = 0
        ..suggested = false;
      if (from != null) _refitType(from);
    }
    notes.add(pusakaNote);
    return true;
  }

  // The rules' insides.

  /// Bound [relic] goes to the Gudang, free: its type's troops lose it ([unbindPusaka], and Lepas jenis,
  /// [Game.releaseType], with the type's troops gone home already).
  void _toGudang(Relic relic) {
    final p = pusaka[relic]!, from = p.type!;
    p
      ..type = null
      ..suggested = false;
    _refitType(from);
    _emit(PusakaMoved(wave, t, relic: relic, from: from, cost: 0));
  }

  /// [Game.givePusaka]: owns [relic] at [stars], bound to [type] (null: the Gudang; an oath always the army's); no price,
  /// no event. A Legenda is found ([Game.legendsFound]).
  void _givePusaka(Relic relic, String? type, int stars) {
    assert(relic.pusaka);
    if (relic.oath) type = null;
    final p = pusaka[relic] ??= OwnedPusaka(), from = p.type;
    if (relic.rarity == Rarity.legenda) legendsFound.add(relic);
    if (type != null) {
      if (pusakaOf(type) case final other? when other != relic) pusaka[other]!.type = null; // a type holds one
    }
    p
      ..type = type
      ..stars = stars.clamp(1, maxStars(relic))
      ..binds = max(p.binds, type == null ? 0 : 1);
    if (from != null) _refitType(from);
    if (type != null) _refitType(type);
    _oathWatch();
  }

  /// [Game.bindByDefault]: every Pusaka in the Gudang ([only] those, when given), in [pusakaPrefs]' order, to the first
  /// living type on its list that holds none yet; [suggest]: the migration's (Batal takes it back).
  void _bindByDefault({bool suggest = false, Set<Relic>? only}) {
    for (final relic in pusakaPrefs.keys) {
      final p = pusaka[relic];
      if (p == null || p.type != null || (only != null && !only.contains(relic))) continue;
      final type = _freeTypeFor(relic);
      if (type == null) continue;
      p
        ..type = type
        ..binds = max(p.binds, 1)
        ..suggested = suggest;
      _refitType(type);
    }
  }

  /// Where the default rule binds [relic]: the first living type on its [pusakaPrefs] list that holds no Pusaka; null:
  /// none (the Gudang).
  String? _freeTypeFor(Relic relic) =>
      pusakaPrefs[relic]?.where((t) => pusakaOf(t) == null && troops.any((u) => u.alive && u.type == t)).firstOrNull;

  /// A save's artefacts from before the Pusaka ([copies]: those in its bag and those its troops wore, taken off): the
  /// first of each kind owned at ★1, each further one a star more up to [starMax], past it paid back ([copyRefund] of its
  /// base price). Then the new ones are bound by default, as a suggestion. Whether there were any.
  bool _migratePusaka(List<Relic> copies) {
    if (copies.isEmpty) return false;
    final fresh = <Relic>{};
    for (final r in copies) {
      final p = pusaka[r];
      if (p == null) {
        pusaka[r] = OwnedPusaka();
        fresh.add(r);
      } else if (p.stars < starMax) {
        p.stars++;
      } else {
        gold += (basePrice(r) * copyRefund).round();
      }
    }
    _refitTroops(); // stars added to one already bound
    _bindByDefault(suggest: true, only: fresh);
    return true;
  }

  /// Every living troop of [type] gets its stats anew ([_refit]): a stat Pusaka came or went.
  void _refitType(String type) {
    for (final u in troops) {
      if (u.alive && u.type == type) _refit(u);
    }
  }

  /// This wave's tally of [relic] ([Game.pusakaWorth]).
  PusakaTally _tally(Relic relic) => pusakaWorth[relic] ??= PusakaTally();

  // The Legenda's rules (decisions-log 155).

  /// The oath taken this run (at most one: [Draft._offerable]), or null; of two (a test's), the first in [Relic] order.
  Relic? get oath {
    for (final r in _oaths) {
      if (pusaka.containsKey(r)) return r;
    }
    return null;
  }

  /// The oath taken waits, doing nothing until the army is back within it: Oath of One while more types than its own
  /// are alive (until Lepas jenis or the fight brings them down to [oathOneK].types: [oathWaiting]), Oath of the Few
  /// while more than [fewOathK].army troops are ([fewWaiting]).
  bool get oathWaits => switch (oath) {
        Relic.oathOfOne => typesAlive > oathOneK.types,
        Relic.fewOath => armySize > fewOathK.army,
        _ => false,
      };

  /// Oath of One is taken and works: its multiplier on, the type caps off ([Game.typeCapOf]).
  bool get oathOneWorks => pusaka.containsKey(Relic.oathOfOne) && !oathWaits;

  /// How many types have a troop alive (Oath of One and Alliance count them).
  int get typesAlive => {for (final u in troops) if (u.alive) u.type}.length;

  /// What the oath multiplies every troop's HP and damage (a healer's heal) by now: Oath of One's [oathOneK].k and Oath
  /// of the Few's [fewOathK].k while they work, Alliance's 1 + [allianceK].perType for each type with a troop alive (at
  /// most [allianceK].most); 1 with none, or an oath of fixed numbers ([Game.statsOf] reads it as the troops were last
  /// refit, [Game._oathK], with the oath itself, [Game._oathOn]).
  double get _oathKNow => switch (oath) {
        Relic.oathOfOne => oathWaits ? 1.0 : oathOneK.k,
        Relic.fewOath => oathWaits ? 1.0 : fewOathK.k,
        Relic.alliance => 1 + allianceK.perType * min(typesAlive, allianceK.most),
        _ => 1.0,
      };

  /// The oath or its multiplier moved (an oath was taken, a type died out or came back, a type was sent home, the army
  /// grew past Oath of the Few's size or came back within it): every living troop is refit to it ([Game._refitTroops]).
  /// Every tick, and after each such change between waves.
  void _oathWatch() {
    if (oath != _oathOn || _oathKNow != _oathK) _refitTroops();
  }

  /// [type]'s stats [s] under the oath the troops were last refit to ([Game._oathOn], [Game._oathK]): Oath of One's, the
  /// Few's and Alliance's HP and damage ×[Game._oathK]; Oath of the Wall's HP up and attack down; Blood Oath's attack up
  /// (a healer's heal not); Oath of the Vanguard's HP and attack up for a type that fights up close, attack or heal down
  /// for the rest. Oath of Kings and Oath of Spells change no stat here ([auraNow], [heroBoostNow], [skillCd]).
  Stats _oathStats(Stats s) => switch (_oathOn) {
        Relic.wallOath => s._with(hp: (s.hp * wallOathK.hp).round(), dmg: s.dmg * wallOathK.dmg),
        Relic.bloodOath => s.heals ? s : s._with(dmg: s.dmg * bloodOathK.dmg),
        Relic.vanguardOath => s.melee
            ? s._with(hp: (s.hp * vanguardOathK.melee).round(), dmg: s.dmg * vanguardOathK.melee)
            : s._with(dmg: s.dmg * vanguardOathK.back),
        _ => _oathK == 1 ? s : s._with(hp: (s.hp * _oathK).round(), dmg: s.dmg * _oathK),
      };

  /// What a living Hero's aura gives every other troop: [auraBoost], or under Oath of Kings its [kingsOathK].aura.
  double get auraNow => _oathOn == Relic.kingsOath ? kingsOathK.aura : auraBoost;

  /// What a Hero's rolled attributes are ×: [heroBoost], or under Oath of Kings its [kingsOathK].heroBoost.
  double get heroBoostNow => _oathOn == Relic.kingsOath ? kingsOathK.heroBoost : heroBoost;

  /// A troop skill's cooldown of [base] s as it is now (its own [Skill.cooldown], its awakening's
  /// [AwakenSkill.cooldownAt], a Hero's [HeroSkill.cooldown]): under Oath of Spells ×[spellOathK].cd, never under
  /// [cdFloor] nor over [base] (once a wave stays once a wave); else [base].
  double skillCd(double base) => _oathOn == Relic.spellOath ? min(base, max(cdFloor, base * spellOathK.cd)) : base;

  /// What a troop's normal attack (a blow, a shot, a healer's smite: [FxEngine._blowK]) is × for the oath: Oath of
  /// Spells' [spellOathK].blow, else 1.
  double get _oathBlowK => _oathOn == Relic.spellOath ? spellOathK.blow : 1.0;

  /// What a heal a troop gets in a wave is × for the oath ([Heal._healTroop]): Blood Oath's [bloodOathK].healIn, else 1.
  double get _oathHealK => _oathOn == Relic.bloodOath ? bloodOathK.healIn : 1.0;

  /// The bound Pusaka by name, with their type, stars and Ukir steps (once fed): what a wave starts with
  /// ([WaveStarted.pusaka]).
  Map<String, Map<String, Object>> get pusakaState => {
        for (final MapEntry(key: r, value: p) in pusaka.entries) r.name: {'type': ?p.type, 'stars': p.stars, if (p.ukir > 0) 'ukir': p.ukir},
      };

  // What the book shows of them (P1b: bag.dart, troop_row.dart, store_page.dart, the tooltips).

  /// The next wave the boss comes ([bossEvery]): the one being fought when it is a boss wave, else the next one.
  int get nextBossWave {
    final from = waveActive ? wave : wave + 1;
    return (from + bossEvery - 1) ~/ bossEvery * bossEvery;
  }

  /// The stats a troop of [type] that isn't a Hero fights with now ([Game._statsFor]), as the field's plates show
  /// them: its type's ([Game.statsOf]), times [auraBoost] while a Hero lives. Every "what you get" number in the book
  /// is this one: the Pasukan row and its tooltips, the Tas rows' previews and the field's drop popup (ui-hud.md
  /// "Field stats"). The owner's wave-86 Templar: 504 HP in [Game.statsOf], 580 here and on the row. Its speed is the walk
  /// it gets, at most [walkCap] ([Stats.walking], decisions-log 311).
  Stats fieldStats(String type) => (heroAlive ? statsOf(type).boosted(auraNow) : statsOf(type)).walking(type);

  /// The line a book tooltip adds while [fieldStats] has the Hero's aura in, "Hero aura x1.15"; null with no Hero. An
  /// item's tooltip says it in English ([itemAuraLine], decisions-log 168).
  String? get auraLine => heroAlive ? 'Hero aura x${_x(auraNow)}' : null;
  String? get itemAuraLine => heroAlive ? 'With Hero aura: ${_pct(auraNow)}' : null;

  /// How many blows of [wave]'s boss a troop of [type] with [hp] max HP lives through from full HP (critique H1): each
  /// blow is the necromancer boss's, the boss slot's reference ([bossStats] through [Omens.spawnStats]), less the defence it
  /// fights with ([fieldStats], [hitTaken]). A guard, a skill or a curse isn't counted.
  int bossBlowsLived(String type, num hp, int wave) {
    final hit = hitTaken(spawnStats(boss, Tier.boss, at: wave, tideStart: tideFrom).dmg, fieldStats(type).def);
    return max(0, (hp / hit).ceil() - 1);
  }

  /// What a tap on [type]'s row would do with Pusaka [relic] picked on the Tas page ([PusakaPreview]): [PusakaAction.lepas]
  /// on the type it is bound to, else a binding. The stats are tried on and taken back, nothing refit, no event.
  PusakaPreview pusakaPreview(Relic relic, String type) {
    if (relic.oath && pusaka.containsKey(relic)) return _oathPreview(type);
    final p = pusaka[relic], lepas = p != null && p.type == type;
    final action = lepas ? PusakaAction.lepas : (bindPrice(relic) == 0 ? PusakaAction.pasang : PusakaAction.pindah);
    final why = lepas ? whyNotUnbind(relic) : whyNotBind(relic, type), price = lepas ? 0 : bindPrice(relic);
    final alive = troops.where((u) => u.alive && u.type == type).length, bossWave = nextBossWave;
    if (p == null || !troopTypes.containsKey(type)) {
      return (why: why, action: action, price: price, alive: alive, stats: const [], blows: null, bossWave: bossWave);
    }
    final now = fieldStats(type), was = p.type, other = lepas ? null : pusakaOf(type);
    if (other != null) pusaka[other]!.type = null; // tried on, then taken back
    p.type = lepas ? null : type;
    final after = fieldStats(type);
    p.type = was;
    if (other != null) pusaka[other]!.type = type;
    final stats = [for (final k in StatKind.values) if (k.of(now) != k.of(after)) (k, k.of(now), k.of(after))];
    final blows = now.hp == after.hp ? null : (bossBlowsLived(type, now.hp, bossWave), bossBlowsLived(type, after.hp, bossWave));
    return (why: why, action: action, price: price, alive: alive, stats: stats, blows: blows, bossWave: bossWave);
  }

  /// [pusakaPreview] for the oath taken, on [type]'s row: nothing to bind ([PusakaAction.sumpah], no refusal: a tap says
  /// how it stands, [Game.pusakaWhere]). Its stats are the type's without the oath ▸ with it now, as its troops fight,
  /// and the boss's blows the same.
  PusakaPreview _oathPreview(String type) {
    final alive = troops.where((u) => u.alive && u.type == type).length, bossWave = nextBossWave;
    final now = fieldStats(type), on = _oathOn, k = _oathK;
    _oathOn = null; // tried off, then put back
    _oathK = 1;
    final without = fieldStats(type);
    _oathOn = on;
    _oathK = k;
    final stats = [for (final s in StatKind.values) if (s.of(without) != s.of(now)) (s, s.of(without), s.of(now))];
    final blows = now.hp == without.hp ? null : (bossBlowsLived(type, without.hp, bossWave), bossBlowsLived(type, now.hp, bossWave));
    return (why: null, action: PusakaAction.sumpah, price: 0, alive: alive, stats: stats, blows: blows, bossWave: bossWave);
  }

  /// What bound Pusaka [relic] gives its whole type now, in the book's words ([Game.relicInfo], critique M6), marked as
  /// now: how many troops it works on and its sum over them, e.g. "Now: 13 Templar, +4,511 HP, +121 HP/s"; asleep, that
  /// none lives. Only where the sum says more than the effect line (decisions-log 168: no line that repeats another): the
  /// Langka, Void Eye and Dragon Crown have none. An oath taken: what it gives the whole army now (Oath of One or the Few
  /// while it waits: nothing, its [Game.pusakaWhere] says so; an oath of fixed numbers, batch G-4's but the Few: none, its
  /// effect lines say it). Empty when it isn't bound.
  List<String> pusakaTotals(Relic relic) {
    if (relic.oath) {
      const moving = {Relic.oathOfOne, Relic.alliance, Relic.fewOath}; // the oaths whose multiplier moves ([_oathKNow])
      if (!pusaka.containsKey(relic) || !moving.contains(relic) || (relic == oath && oathWaits)) return const [];
      final pct = _pct(_oathK);
      return [relic == Relic.alliance ? 'Now: ${_count(min(typesAlive, allianceK.most), 'type')}, $pct' : 'Now: all troops, $pct'];
    }
    final p = pusaka[relic], type = p?.type;
    if (p == null || type == null) return const [];
    final name = troopTypeNames[type] ?? type, n = troops.where((u) => u.alive && u.type == type).length;
    if (n == 0) return ['Asleep: no $name alive'];
    // The type's stats with it and without it (tried on, then taken back), as its troops fight.
    final now = fieldStats(type);
    p.type = null;
    final without = fieldStats(type);
    p.type = type;
    final who = 'Now: $n $name';
    String share(double s) => '${(s * 100).round()}%';
    String perSec(double d) => thousands((n * d / StatKind.rate.of(now)).round());
    // By its first Fx (pusaka_catalog.dart): a stat's sum, the leaps' share, the saves.
    final fx = pusakaCatalog[relic]!.fx.first;
    return switch ((fx.on, fx.eff)) {
      (Trig.always, Eff.stat) when fx.stat == Stat.hp => [
          '$who, +${thousands(n * (now.hp - without.hp))} HP, +${thousands((n * (now.regen - without.regen)).round())} HP/s'
        ],
      (Trig.always, Eff.stat) when fx.stat == Stat.dmg => ['$who, +${perSec(now.dmg - without.dmg)} ${now.heals ? 'heal' : 'damage'}/s'],
      (Trig.landed, Eff.leap) => ['$who, +${share(pusakaCountAt(relic, p.stars) * pusakaAt(relic, p.stars, ukir: p.ukir))} damage in crowds'],
      (Trig.lethal, Eff.save) => ['Now: up to $n saves a wave'],
      _ => const [], // its effect line says it all
    };
  }

  /// Every tick: a save ([Eff.save], the Grail's) whose troop has lived [keptAfter] s since is kept; one whose troop
  /// fell is not. [end]: the wave is over, so every save whose troop lives is kept.
  void _watchGrail({bool end = false}) {
    if (_grailWatch.isEmpty) return;
    _grailWatch.removeWhere((w) {
      final (u, at, relic) = w;
      if (!u.alive) return true;
      if (!end && t - at < keptAfter) return false;
      _tally(relic).worth++;
      return true;
    });
  }
}

// Asah (P6, decisions-log 154; docs/loot-items-relics.md "Asah"): the owner, 2026-09-30: "duitnya itu aku bingung di
// buat untuk apa". Between waves a Pusaka owned gains a star for gold and [asahRelics] small relics from the bag (their
// sink, design §3.6), on the Tas page's facing page (bag.dart). One Asah per boss interval, across all Pusaka, so the
// chest's duplicate cards keep their worth (§3.7).

/// What an Asah costs in gold, by the stars it has now: to ★2, to ★3 (design §3.10).
const asahPrice = [60000, 150000];

/// How many small relics from the bag each Asah takes ([Asah.asahTake]).
const asahRelics = 10;

/// How many items from the bag an Asah also takes from wave [ukirFrom] on, by the stars it has now: to ★2, to ★3
/// ([Asah.asahItemTake]; item-artefact-design §6, owner decision 4, asked: its default "a", none, so Asah stays gold and
/// small relics; "b" is [20, 40]).
const asahItems = [0, 0];

/// Why a Pusaka can't be raised now ([Asah.whyNotAsah]), besides [assignRefusals].over and [pusakaRefusals].none, in the
/// design's order: a wave is on, an Asah was done in this boss interval already, the gold is short, the bag holds fewer
/// than [asahRelics] small relics (or spare items than [asahItems] asks), a Legenda (★1 only, design §3.4) or one at
/// [starMax] already.
const asahRefusals = (
  midWave: Words.onlyBetweenWaves,
  once: 'Already sharpened this round',
  gold: Words.notEnoughGold,
  relics: 'Not enough relics (need $asahRelics)',
  items: 'Not enough items', // in simple English, like every in-game text (the owner, 2026-10-03)
  legend: "A ${Words.legendary} can't be sharpened",
  maxed: 'Already ★$starMax',
);

/// The small relics [take] names ([Asah.asahTake]) in the UI's words, in the order taken: "Thorns 8, Fury 2".
String asahTakeLine(Map<Relic, int> take) => [for (final MapEntry(:key, :value) in take.entries) '${relicNames[key]} $value'].join(', ');

/// The boss interval that wave [w] (the last one fought) lies in, between waves: from wave 85's end up to wave 89's it is
/// 17, from wave 90's (the boss's) on 18. One Asah a boss interval ([asahRefusals].once).
int _asahInterval(int w) => w ~/ bossEvery;

/// The Asah's rules (the Tas page calls them).
extension Asah on Game {
  /// Whether an Asah was done in this boss interval already ([Game.asahAt]).
  /// A later interval's counts too: a wipe's trip back to a Town (wipe.dart) plays an interval again, never a second Asah.
  bool get asahDone => asahAt != null && _asahInterval(asahAt!) >= _asahInterval(wave);

  /// The wave whose end opens the next Asah while [asahDone]: the coming boss wave (after the Asah's own interval).
  int get asahAgainAt => (_asahInterval(max(wave, asahAt ?? 0)) + 1) * bossEvery;

  /// What raising [relic] a star costs now ([asahPrice] by its stars), or null when it can't rise: not owned, a Legenda,
  /// or at [starMax].
  int? asahPriceOf(Relic relic) {
    final p = pusaka[relic];
    if (p == null || relic.rarity == Rarity.legenda || p.stars >= starMax) return null;
    return asahPrice[p.stars - 1];
  }

  /// How many small relics the bag holds ([Relics.relicsInPlay]: those an Asah can take).
  int get asahRelicsInBag => relicsInPlay.fold(0, (n, r) => n + (relicBag[r] ?? 0));

  /// The small relics an Asah would take from the bag now, by kind, in the order taken: one at a time, the cheapest first
  /// (decisions-log 233, the design's decision 10): by craft gold ([Recipe.gold]: Fang and Thorns 300, Fury and Guard
  /// 400, the Strong four 1,000, Iron Will and Holy Charm 3,000, Giant Slayer 3,500), the dearer ones only once the cheaper
  /// are gone; among those of one price the kind the bag holds most of then (ties: [Relic] order), up to [asahRelics].
  /// The owner's wave-86 bag (Taring 17, Duri 29, Amarah 23, Pelindung 21) gives Duri 10. Fewer than [asahRelics] in all
  /// when the bag holds fewer.
  Map<Relic, int> get asahTake => _bagTake(asahRelics);

  /// [n] small relics from the bag as [asahTake] takes them (Lebur's, [leburRelics], the same way): one at a time, each
  /// from the kind the bag holds most of then among the cheapest kinds still held; fewer when the bag holds fewer.
  Map<Relic, int> _bagTake(int n) {
    final kinds = relicsInPlay, left = {for (final r in kinds) r: relicBag[r] ?? 0}, take = <Relic, int>{};
    int price(Relic r) => townRules.recipes[r.name]?.gold ?? 0; // its craft gold
    for (var i = 0; i < n; i++) {
      final held = [for (final r in kinds) if (left[r]! > 0) r];
      if (held.isEmpty) break;
      final cheapest = held.map(price).reduce(min);
      final most = held.where((r) => price(r) == cheapest).reduce((a, b) => left[b]! > left[a]! ? b : a);
      left[most] = left[most]! - 1;
      take[most] = (take[most] ?? 0) + 1;
    }
    return take;
  }

  /// The items an Asah of [relic] would also take from the bag now ([asahItems] by its stars, from wave [ukirFrom]), by
  /// kind: one at a time, each from the kind with the most spare then ([Ukir.ukirSpare]: [ukirKeep] keeps what a type
  /// on the field needs for its next Bangkit; ties in [Item] order); fewer when the bag has fewer. None by default.
  Map<Item, int> asahItemTake(Relic relic) {
    final take = <Item, int>{};
    if (asahPriceOf(relic) == null || !ukirOpen) return take; // no next star, or before Ukir opens
    final left = ukirSpare;
    for (var i = 0; i < asahItems[pusaka[relic]!.stars - 1]; i++) {
      final most = droppedItems.reduce((a, b) => left[b]! > left[a]! ? b : a);
      if (left[most] == 0) break;
      left[most] = left[most]! - 1;
      take[most] = (take[most] ?? 0) + 1;
    }
    return take;
  }

  /// Why [relic] can't gain a star now, in the UI's words, or null: after game over, not owned, then [asahRefusals] in
  /// their order. With no next star (a Legenda, or at [starMax]) there is no price, so the gold, the relics and the items
  /// aren't asked.
  String? whyNotAsah(Relic relic) {
    if (over) return assignRefusals.over;
    final p = pusaka[relic];
    if (p == null) return pusakaRefusals.none;
    if (waveActive) return asahRefusals.midWave;
    if (asahDone) return asahRefusals.once;
    if (asahPriceOf(relic) case final price?) {
      if (gold < price) return asahRefusals.gold;
      if (asahRelicsInBag < asahRelics) return asahRefusals.relics;
      if (ukirOpen && _itemsIn(asahItemTake(relic)) < asahItems[p.stars - 1]) return asahRefusals.items;
      return null;
    }
    return relic.rarity == Rarity.legenda ? asahRefusals.legend : asahRefusals.maxed;
  }

  /// Raises [relic] a star for [asahPriceOf], the small relics [asahTake] names (and the items [asahItemTake] names): the
  /// troops of its type refit at once ([Game.statsOf]: Dragon Heart's HP comes with it) and burst in gold, as the
  /// chest's pick does ([Draft.takeCard]); the boss interval's Asah is spent ([Game.asahAt]), and it is logged
  /// ([PusakaAsah]). Its Ukir stays ([OwnedPusaka.ukir]). False (nothing changes but the error sound) when [whyNotAsah]
  /// refuses.
  bool asah(Relic relic) {
    if (whyNotAsah(relic) != null) {
      sfx.add(Sfx.error);
      return false;
    }
    final p = pusaka[relic]!, cost = asahPriceOf(relic)!, taken = asahTake, items = asahItemTake(relic), type = p.type;
    gold -= cost;
    for (final MapEntry(key: r, value: n) in taken.entries) {
      relicBag[r] = relicBag[r]! - n;
    }
    for (final MapEntry(key: i, value: n) in items.entries) {
      inventory[i] = inventory[i]! - n;
    }
    p.stars++;
    asahAt = wave;
    if (type != null) {
      _refitType(type);
      for (final u in troops) {
        if (u.alive && u.type == type) impacts.add((u.pos, awakeFx('upgrade', maxAwaken))); // a Pusaka's burst is gold
      }
    }
    sfx.add(Sfx.clear);
    _emit(PusakaAsah(wave, t, relic: relic, stars: p.stars, type: type, cost: cost, relics: taken, items: items));
    return true;
  }
}

// Lebur (J3, decisions-log 164; docs/loot-items-relics.md "Lebur"): late in a run the chest's cards pile up in the
// Gudang with nothing to do (the owner's w86 save: 3 Pusaka there by w105). Between waves one in the Gudang is melted
// into another Pusaka owned, which gains [leburStars] for [leburPrice] by its stars, on the Tas page (bag.dart). The
// melted one (the fodder) is gone with its stars, and the chest may deal it again ([Draft._offerable]). No limit per
// boss interval ([leburUsesAsah]): the fodder, from chest cards and paid rerolls, is the limit, so a duplicate card
// keeps its worth.

/// What a Lebur costs in gold, by the target's stars now: to ★2, to ★3 (Asah's, [asahPrice]: 60k, 150k).
const leburPrice = asahPrice;

/// The stars a Lebur gives its target (never past [starMax]).
const leburStars = 1;

/// How many small relics from the bag a Lebur takes ([Lebur.leburTake]; Asah's [asahRelics] 10): none.
const leburRelics = 0;

/// Whether a Lebur spends the boss interval's Asah ([Game.asahAt]) and waits for it like one: no, the two are apart.
const leburUsesAsah = false;

/// Whether a Langka fodder feeds only a Langka target (owner decision 3's (b), "Langka hanya untuk Langka"; an Epik one
/// still feeds any): no, any fodder into any target.
const leburRarity = false;

/// Whether [fodder] may go into [target] by their rarities ([leburRarity]).
bool _leburRarityFits(Relic fodder, Relic target) => !leburRarity || fodder.rarity != Rarity.langka || target.rarity == Rarity.langka;

/// Why a Pusaka can't be melted now, or not into that target ([Lebur.whyNotLebur]), besides [assignRefusals].over and
/// [pusakaRefusals].none, in their order: the fodder isn't in the Gudang (bound, or an oath), a wave is on, the boss
/// interval's Asah is spent ([leburUsesAsah] only), the fodder is a Legenda, no Pusaka could take its star (the button's
/// own); then for a target: the fodder itself, a Legenda, at [starMax] already, a Langka fodder into another rarity
/// ([leburRarity] only), the
/// gold short, the bag short of small relics ([leburRelics] only).
const leburRefusals = (
  notGudang: 'Only an ${Words.artifact} in the ${Words.vault}',
  midWave: Words.onlyBetweenWaves,
  legend: "A ${Words.legendary} can't be melted",
  noTarget: 'No other ${Words.artifact} under ★$starMax',
  same: 'Same ${Words.artifact}',
  maxed: 'Already ★$starMax',
  rarity: '${Words.rare} only into ${Words.rare}',
  gold: Words.notEnoughGold,
  relics: 'Not enough relics (need $leburRelics)',
);

/// Lebur's rules (the Tas page calls them).
extension Lebur on Game {
  /// What a Lebur into [target] costs now ([leburPrice] by its stars), or null when it can't rise: not owned, a Legenda,
  /// or at [starMax].
  int? leburPriceOf(Relic target) {
    final p = pusaka[target];
    if (p == null || target.rarity == Rarity.legenda || p.stars >= starMax) return null;
    return leburPrice[p.stars - 1];
  }

  /// The small relics a Lebur would take from the bag now ([leburRelics], taken as [Asah.asahTake]): none.
  Map<Relic, int> get leburTake => _bagTake(leburRelics);

  /// What [fodder] could be melted into, in [Relic] order: every Pusaka owned but it and an oath (a Legenda's, a ★3's
  /// row is refused, [whyNotLebur]).
  List<Relic> leburTargets(Relic fodder) => [for (final r in Relic.values) if (r != fodder && !r.oath && pusaka.containsKey(r)) r];

  /// Why [fodder] can't be melted now, in the UI's words, or null; with [target], why not into it. After game over, not
  /// owned, then [leburRefusals] in their order. Without a target it also asks that some Pusaka could take the star
  /// (gold aside: the picker shows each price).
  String? whyNotLebur(Relic fodder, [Relic? target]) {
    if (over) return assignRefusals.over;
    final p = pusaka[fodder];
    if (p == null) return pusakaRefusals.none;
    if (p.type != null || fodder.oath) return leburRefusals.notGudang;
    if (waveActive) return leburRefusals.midWave;
    if (leburUsesAsah && asahDone) return asahRefusals.once;
    if (fodder.rarity == Rarity.legenda) return leburRefusals.legend;
    if (target == null) {
      final some = leburTargets(fodder).any((r) => leburPriceOf(r) != null && _leburRarityFits(fodder, r));
      return some ? null : leburRefusals.noTarget;
    }
    if (target == fodder) return leburRefusals.same;
    if (!pusaka.containsKey(target)) return pusakaRefusals.none;
    if (target.rarity == Rarity.legenda) return leburRefusals.legend;
    final price = leburPriceOf(target);
    if (price == null) return leburRefusals.maxed;
    if (!_leburRarityFits(fodder, target)) return leburRefusals.rarity;
    if (gold < price) return leburRefusals.gold;
    if (leburRelicsShort) return leburRefusals.relics;
    return null;
  }

  /// The bag holds fewer small relics than a Lebur takes ([leburRelics]).
  bool get leburRelicsShort => asahRelicsInBag < leburRelics;

  /// Melts [fodder] (in the Gudang) into [target] for [leburPriceOf] (and the small relics [leburTake] names): the fodder
  /// is gone with its stars, so the chest may deal it again ([Draft._offerable]); [target] gains [leburStars] and keeps
  /// the higher Ukir of the two ([ukirMelt]), its type's troops refit at once and burst in gold, as Asah's do
  /// ([Asah.asah]); the boss interval's Asah stays ([Game.asahAt] untouched, [leburUsesAsah]), and it is logged
  /// ([PusakaLebur]). False (nothing changes but the error sound) when [whyNotLebur] refuses.
  bool lebur(Relic fodder, Relic target) {
    if (whyNotLebur(fodder, target) != null) {
      sfx.add(Sfx.error);
      return false;
    }
    final p = pusaka[target]!, cost = leburPriceOf(target)!, taken = leburTake, type = p.type, lost = pusaka[fodder]!.stars;
    gold -= cost;
    for (final MapEntry(key: r, value: n) in taken.entries) {
      relicBag[r] = relicBag[r]! - n;
    }
    final melted = pusaka.remove(fodder)!.ukir;
    p.stars = min(starMax, p.stars + leburStars);
    _meltUkir(p, melted);
    if (leburUsesAsah) asahAt = wave;
    if (type != null) {
      _refitType(type);
      for (final u in troops) {
        if (u.alive && u.type == type) impacts.add((u.pos, awakeFx('upgrade', maxAwaken))); // a Pusaka's burst is gold
      }
    }
    sfx.add(Sfx.clear);
    _emit(PusakaLebur(wave, t, fodder: fodder, fodderStars: lost, relic: target, stars: p.stars, type: type, cost: cost, relics: taken));
    return true;
  }
}

// Ukir (item-artefact-design U2, decisions-log 183; docs/loot-items-relics.md "Ukir"): the owner, 2026-10-02, asked that
// items also make the artefacts stronger, so spare items stay useful into the late game (his w91 bag held 514, every
// troop item given). Between waves, from wave [ukirFrom], spare items fill a Pusaka's Ukir bar: a kind of its role
// ([roleItems]) gives [ukirMatch] points, any other [ukirAny]. Each full bar is a step ([ukirCost]) worth a share of a
// star ([ukirWorth]), five at most, so ★n+5 never reaches ★(n+1); [pusakaAt] reads the steps. All the Pusaka share one
// budget of [ukirPerBoss] points a boss interval. Each full star of worth fed in a run counts as a star-up for the hidden
// enemy buffs ([_omenStarUp]). The player sees it as "Carve" (decisions-log 196): the Bag's facing page of a Pusaka
// carves it with its Carve strip, an item's Give rows give that kind to one (bag.dart). Every number the owner may tune
// is one constant below.

/// Ukir opens once wave [ukirFrom] is fought ([Game.wave] the last one fought, or [Game.bestWon] after a wipe sent the game
/// back: [Ukir.ukirOpen]), between waves only ([ukirMidWave]).
const ukirFrom = 40, ukirMidWave = false;

/// The items each [UkirRole] counts as its own (a Pusaka's role is its row's [Art.role]); each kind is in exactly one.
const roleItems = <UkirRole, Set<Item>>{
  UkirRole.attack: {Item.sword, Item.bow, Item.gloves},
  UkirRole.guard: {Item.shield, Item.boots},
  UkirRole.life: {Item.potion, Item.staff},
};

/// The points one item gives a Pusaka's bar: a kind of its role [ukirMatch], any other kind [ukirAny].
const ukirMatch = 2, ukirAny = 1;

/// The points each step costs, in order (785 in all), and what each is worth in stars (0.8 in all): costs rise and worth
/// falls. Their length is the most steps: +5 worth 0.8 star (owner decision 1, asked; its default "a").
const ukirCost = [60, 90, 135, 200, 300], ukirWorth = [0.2, 0.2, 0.2, 0.1, 0.1];

/// The points all Pusaka together take in one boss interval (Asah's, [_asahInterval]), and the most one tap gives.
const ukirPerBoss = 180, ukirTap = 60;

/// A tap keeps back the items a type on the field still needs for its next Bangkit ([Ukir.ukirKept]).
const ukirKeep = true;

/// The named rules for a number that is the same at every star ([pusakaAt]), per star of Ukir worth: Fx number [fx]'s
/// number moves by [per]. God's Thunder's share of a leap rises by [thunderSharePerStar] (0.40 to 0.56 at +5), Dragon
/// Crown's cap falls by [crownPerStar] (0.60 to 0.48); batch G-1P's Legenda (decisions-log 231, catalog-design §3.3)
/// each move the number their `perStar` names (draft.dart): Wide Blows' and Ghost Step's their trade's attack (their
/// second Fx), the others their first's; batch G-2's eight (decisions-log 238) their first's (Soul Shelter's and Hex
/// Blade's a time), and batch G-3's three (decisions-log 243) their first's (Grave Seal's a time). Any other such number
/// stays.
const thunderSharePerStar = 0.2, crownPerStar = 0.15;
final ukirPerStar = <Relic, ({int fx, double per})>{
  Relic.godThunder: (fx: 0, per: thunderSharePerStar),
  Relic.dragonCrown: (fx: 0, per: -crownPerStar),
  Relic.loneWolf: (fx: 0, per: loneWolfK.perStar),
  Relic.martyrFlame: (fx: 0, per: martyrFlameK.perStar),
  Relic.wideBlows: (fx: 1, per: wideBlowsK.perStar),
  Relic.champion: (fx: 0, per: championK.perStar),
  Relic.vengeance: (fx: 0, per: vengeanceK.perStar),
  Relic.mirror: (fx: 0, per: mirrorK.perStar),
  Relic.ghostStep: (fx: 1, per: ghostStepK.perStar),
  Relic.iceGrip: (fx: 0, per: iceGripK.perStar),
  Relic.relicAltar: (fx: 0, per: relicAltarK.perStar),
  Relic.vowSilence: (fx: 0, per: vowSilenceK.perStar),
  Relic.rageTotem: (fx: 0, per: rageTotemK.perStar),
  Relic.guardianChain: (fx: 0, per: guardianChainK.perStar),
  Relic.phalanx: (fx: 0, per: phalanxK.perStar),
  Relic.phoenix: (fx: 0, per: phoenixK.perStar),
  Relic.soulShelter: (fx: 0, per: soulShelterK.perStar),
  Relic.manaFont: (fx: 0, per: manaFontK.perStar),
  Relic.hexBlade: (fx: 0, per: hexBladeK.perStar),
  Relic.glorySeeker: (fx: 0, per: glorySeekerK.perStar),
  Relic.vampireKiss: (fx: 0, per: vampireKissK.perStar),
  Relic.wrathPsalm: (fx: 0, per: wrathPsalmK.perStar),
  Relic.graveSeal: (fx: 0, per: graveSealK.perStar),
};

/// The Ukir worth fed in a run ([UkirRun.milli]) that counts as one star-up for the enemy buffs ([_omenStarUp]).
const ukirOmenStars = 1.0;

/// Whether a Pusaka in the Gudang takes Ukir too (owner decision 3, asked; its default "a": yes, bound or not).
const ukirGudang = true;

/// What a Lebur does with the fodder's Ukir ([Lebur.lebur], owner decision 2, asked): the target keeps the [higher] of
/// the two (its default "a"), adds them up to the last step ([sum], "b"), or keeps its own ([lost], "c"). The target
/// keeps its own bar's points. A sale always loses it: the Pusaka is gone.
enum UkirMelt { higher, sum, lost }

const ukirMelt = UkirMelt.higher;

/// Why a Pusaka can't take Ukir now ([Ukir.whyNotUkir]), besides [assignRefusals].over and [pusakaRefusals].none, in
/// the design's order: a wave is on, before wave [ukirFrom], an oath, (in the Gudang, only without [ukirGudang]), at its
/// last step, the boss interval's budget spent ([budget], then the wave that opens the next: "No points left: more at
/// wave 95"), no spare item gives a point. In the English glossary's words (english-text-design §3.7; the owner,
/// 2026-10-03: every in-game text in English): Ukir is "Carve", a Pusaka an "Artifact" ([Words]).
const ukirRefusals = (
  midWave: Words.onlyBetweenWaves,
  from: '${Words.carve} opens at wave $ukirFrom',
  oath: "An ${Words.oath} can't be carved",
  bound: 'Equipped ${Words.artifact}s only',
  full: '${Words.carve} is full',
  budget: 'No points left: more at wave',
  items: 'Not enough items',
);

/// A carved Pusaka's line in its tooltip and Carve's help ([Game.relicInfo], [Ukir.carveInfo]): its steps of the most,
/// and that they are not a star (decisions-log 196).
String ukirGist(int ukir) => '${Words.carve} $ukir of ${ukirCost.length}: not a star, a bit stronger.';

/// A Pusaka's Carve steps as its badge's gold tail says them ("★2+3": the "+3"), or null at none (decisions-log 196).
String? ukirMark(int ukir) => ukir > 0 ? '+$ukir' : null;

/// The stars [ukir] steps are worth: [ukirWorth]'s first [ukir] summed (0 at 0), to the thousandth, so 0.6 is 0.6.
double ukirWorthOf(int ukir) => ukirWorth.take(ukir.clamp(0, ukirCost.length)).fold(0, (n, w) => n + _milli(w)) / 1000;

/// [w] stars in thousandths of a star.
int _milli(double w) => (w * 1000).round();

/// How many items [take] holds in all.
int _itemsIn(Map<Item, int> take) => take.values.fold(0, (n, v) => n + v);

/// The run's Ukir ([Game.ukir]): the boss interval of the last feed ([iv], [_asahInterval]) and the points fed in it
/// ([pts]: the shared budget, [ukirPerBoss]), and the star worth fed in the run, in thousandths ([milli]: +200 or +100 a
/// step), which never falls (a sale included) and calls the star-up hook at each [ukirOmenStars] it passes. Saved once
/// fed ([fed]).
class UkirRun {
  int iv = 0, pts = 0, milli = 0;

  /// Anything was fed this run.
  bool get fed => pts > 0 || milli > 0;

  Map<String, int> toJson() => {'iv': iv, 'pts': pts, 'milli': milli};
}

/// Ukir's rules (the Bag's Carve strip and Give rows call them, bag.dart; [Game.ukirFill] for the probes).
extension Ukir on Game {
  /// The points the Pusaka may still take in this boss interval ([ukirPerBoss], shared by all). An interval played again
  /// after a wipe's trip back to a Town (wipe.dart) shares the later one's: never a second budget.
  int get ukirBudget => ukir.iv >= _asahInterval(wave) ? max(0, ukirPerBoss - ukir.pts) : ukirPerBoss;

  /// The wave whose end opens the next budget: the coming boss wave (as [Asah.asahAgainAt]).
  int get ukirAgainAt => (_asahInterval(max(wave, ukir.iv * bossEvery)) + 1) * bossEvery;

  /// Ukir is open ([ukirFrom]): by the wave, or the highest won after a wipe's trip back ([Game.bestWon]).
  bool get ukirOpen => max(wave, bestWon) >= ukirFrom;

  /// The items the types on the field (a troop of it alive) still need for their next Bangkit, by kind: what a tap keeps
  /// back ([ukirKeep]). A type at Bangkit 3 (its items' top) needs none.
  Map<Item, int> get ukirKept {
    final kept = <Item, int>{};
    for (final type in {for (final u in troops) if (u.alive) u.type}) {
      for (final MapEntry(key: item, value: need) in awakenShort(type).entries) {
        kept[item] = (kept[item] ?? 0) + need;
      }
    }
    return kept;
  }

  /// Every item kind monsters drop ([droppedItems]: never a forge item, decisions-log 245) with how many of it the bag
  /// holds past [ukirKept] (all of it without [ukirKeep]).
  Map<Item, int> get ukirSpare {
    final kept = ukirKeep ? ukirKept : const <Item, int>{};
    return {for (final i in droppedItems) i: max(0, (inventory[i] ?? 0) - (kept[i] ?? 0))};
  }

  /// The points [relic]'s bar still lacks for its next step; 0 at its last step, or not owned.
  int ukirLeft(Relic relic) => switch (pusaka[relic]) {
        final p? when p.ukir < ukirCost.length => ukirCost[p.ukir] - p.feed,
        _ => 0,
      };

  /// What one tap ([feedUkir]) on [relic] would take now: the [items] by kind, in the order taken, and the [points]
  /// they give. At most [ukirTap], the budget left ([ukirBudget]) and what its step lacks ([ukirLeft]), so no point
  /// spills. The items go one at a time from [ukirSpare]: its role's kinds ([roleItems], [ukirMatch] each) first, each
  /// from the kind with the most spare then (ties in [Item] order), then the other kinds ([ukirAny] each) the same way.
  /// A role's item is never split: with 1 point left another kind gives it, or the tap stops there. None for an oath.
  /// With [only] (a Give row's tap, U4: the player picks the kind) it takes that kind alone, by the same rules.
  ({Map<Item, int> items, int points}) ukirTake(Relic relic, {Item? only}) {
    final role = pusakaCatalog[relic]?.role, take = <Item, int>{};
    if (role == null) return (items: take, points: 0);
    final mine = roleItems[role]!, left = {for (final MapEntry(:key, :value) in ukirSpare.entries) key: only == null || key == only ? value : 0};
    var room = min(ukirTap, min(ukirBudget, ukirLeft(relic))), points = 0;
    Item? most(bool own) => droppedItems
        .where((i) => mine.contains(i) == own && left[i]! > 0)
        .fold<Item?>(null, (a, b) => a == null || left[b]! > left[a]! ? b : a);
    while (room > 0) {
      final pick = (room >= ukirMatch ? most(true) : null) ?? (room >= ukirAny ? most(false) : null);
      if (pick == null) break;
      final gain = mine.contains(pick) ? ukirMatch : ukirAny;
      left[pick] = left[pick]! - 1;
      take[pick] = (take[pick] ?? 0) + 1;
      points += gain;
      room -= gain;
    }
    return (items: take, points: points);
  }

  /// Why [relic] can't take Ukir now, in the UI's words, or null: after game over, not owned, then [ukirRefusals] in
  /// their order; with [only], whether that kind alone gives a point ([ukirTake]).
  String? whyNotUkir(Relic relic, {Item? only}) {
    if (over) return assignRefusals.over;
    final p = pusaka[relic];
    if (p == null) return pusakaRefusals.none;
    if (!ukirMidWave && waveActive) return ukirRefusals.midWave;
    if (!ukirOpen) return ukirRefusals.from;
    if (relic.oath || pusakaCatalog[relic]?.role == null) return ukirRefusals.oath;
    if (!ukirGudang && p.type == null) return ukirRefusals.bound;
    if (p.ukir >= ukirCost.length) return ukirRefusals.full;
    if (ukirBudget == 0) return '${ukirRefusals.budget} $ukirAgainAt';
    return ukirTake(relic, only: only).points == 0 ? ukirRefusals.items : null;
  }

  /// One tap: feeds [relic] the items [ukirTake] names, from the bag, for their points, out of the boss interval's
  /// budget ([UkirRun.pts]), logged ([UkirFed]). A full bar is a step ([OwnedPusaka.ukir], the bar empty again): the
  /// troops of its type refit at once ([pusakaAt] reads it) and burst in gold as an Asah's do, it is logged ([UkirStep]),
  /// and each [ukirOmenStars] of worth the run's feeding passes ([UkirRun.milli]) calls the star-up hook
  /// ([_omenStarUp]). False (nothing changes but the error sound) when [whyNotUkir] refuses. With [only], that kind
  /// alone (a Give row's tap).
  bool feedUkir(Relic relic, {Item? only}) {
    if (whyNotUkir(relic, only: only) != null) {
      sfx.add(Sfx.error);
      return false;
    }
    final (:items, :points) = ukirTake(relic, only: only);
    final p = pusaka[relic]!, type = p.type, iv = _asahInterval(wave);
    for (final MapEntry(key: i, value: n) in items.entries) {
      inventory[i] = inventory[i]! - n;
    }
    if (ukir.iv < iv) {
      ukir
        ..iv = iv
        ..pts = 0;
    }
    ukir.pts += points;
    p.feed += points;
    _emit(UkirFed(wave, t, relic: relic, items: items, points: points, type: type));
    if (p.feed < ukirCost[p.ukir]) {
      sfx.add(Sfx.magic);
      return true;
    }
    p
      ..feed = 0
      ..ukir += 1;
    final was = ukir.milli, per = _milli(ukirOmenStars);
    ukir.milli += _milli(ukirWorth[p.ukir - 1]);
    if (type != null) {
      _refitType(type);
      for (final u in troops) {
        if (u.alive && u.type == type) impacts.add((u.pos, awakeFx('upgrade', maxAwaken))); // a Pusaka's burst is gold
      }
    }
    sfx.add(Sfx.clear);
    final starUps = ukir.milli ~/ per - was ~/ per;
    _emit(UkirStep(wave, t, relic: relic, step: p.ukir, stars: p.stars, type: type, starUps: starUps));
    for (var n = 0; n < starUps; n++) {
      _omenStarUp(relic);
    }
    return true;
  }

  /// Carve's help for [relic] (its bar's tooltip on the Bag's facing page, decisions-log 196): what it does, the kinds of
  /// its role that count [ukirMatch] ([roleItems]), the others [ukirAny], what a full bar gives, the budget all share and
  /// what is left of it now, and its steps ([ukirGist]) once carved.
  (String, List<String>) carveInfo(Relic relic) {
    final mine = [for (final i in Item.values) if (roleItems[pusakaCatalog[relic]?.role]?.contains(i) ?? false) itemNames[i]!];
    final kinds = [for (final (n, name) in mine.indexed) n == 0 ? name : name.toLowerCase()];
    final named = kinds.length < 2 ? kinds.join() : '${kinds.sublist(0, kinds.length - 1).join(', ')} and ${kinds.last}';
    final steps = pusaka[relic]?.ukir ?? 0;
    return (Words.carve, [
      'Give spare items to this ${Words.artifact}.',
      if (named.isNotEmpty) '$named count $ukirMatch.',
      'Other items count $ukirAny.',
      'Full bar: a bit stronger.',
      '$ukirPerBoss points each boss, for all ${Words.artifact}s.',
      'Points left now: $ukirBudget',
      if (steps > 0) ukirGist(steps),
    ]);
  }

  /// What [relic]'s next Carve step changes, for the Bag's "Next: 40% ▸ 42% HP left" (decisions-log 196): in its effect
  /// lines ([Game.relicEffect]) now and one step on, the first word that differs, [now] and [after], and the rest of its
  /// line after it ([rest]); null at its last step, or when no word differs.
  ({String now, String after, String rest})? carveNext(Relic relic) {
    final p = pusaka[relic];
    if (p == null || p.ukir >= ukirCost.length) return null;
    final was = relicEffect(relic), next = relicEffect(relic, stars: p.stars, ukir: p.ukir + 1);
    for (var i = 0; i < min(was.length, next.length); i++) {
      final a = was[i].split(' '), b = next[i].split(' ');
      for (var j = 0; j < min(a.length, b.length); j++) {
        if (a[j] != b[j]) return (now: a[j], after: b[j], rest: b.sublist(j + 1).join(' '));
      }
    }
    return null;
  }

  /// [Game.ukirFill]: taps ([feedUkir]) the bound Pusaka ([bound] false: every one owned) until none takes more, each
  /// tap to the one with the fewest steps (ties in [Relic] order), so they rise together. The points fed.
  int _ukirFill({bool bound = true}) {
    var fed = 0;
    while (true) {
      final can = [for (final MapEntry(key: r, value: p) in pusaka.entries) if ((!bound || p.type != null) && whyNotUkir(r) == null) (r, p.ukir)];
      if (can.isEmpty) return fed;
      final (r, _) = can.reduce((a, b) => b.$2 < a.$2 || (b.$2 == a.$2 && b.$1.index < a.$1.index) ? b : a);
      fed += ukirTake(r).points;
      feedUkir(r);
    }
  }

  /// The Ukir steps [target] has after a Lebur of [fodder] into it ([ukirMelt]; the Lebur picker's gist).
  int leburUkir(Relic fodder, Relic target) => _melted(pusaka[target]?.ukir ?? 0, pusaka[fodder]?.ukir ?? 0);

  /// A Lebur's target with [own] Ukir steps, its fodder with [melted]: the steps it ends with ([ukirMelt]).
  int _melted(int own, int melted) => switch (ukirMelt) {
        UkirMelt.higher => max(own, melted),
        UkirMelt.sum => min(ukirCost.length, own + melted),
        UkirMelt.lost => own,
      };

  /// [melted] Ukir steps of a Lebur's fodder go into [p], its target, by [ukirMelt]; its bar keeps its points (none at
  /// its last step).
  void _meltUkir(OwnedPusaka p, int melted) {
    final to = _melted(p.ukir, melted);
    if (to == p.ukir) return;
    p.ukir = to;
    if (to >= ukirCost.length) p.feed = 0;
  }
}
