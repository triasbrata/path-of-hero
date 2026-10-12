part of 'game.dart';

// Bayangan, the enemy's hidden buffs (catalog step 0c, decisions-log 180; docs/loot-items-relics.md "Bayangan"). The
// owner, 2026-10-02: every Pusaka card from a Peti Bos is a double-edged sword. Taking it also gives the enemy a hidden
// buff, a Bayangan, revealed on the take. It answers a late game that was far too easy (w87-102: no troop fell on 16
// waves). From [omenFrom] each card of a chest hides a face, one [Game.omenDice] draw a card ([Omens._faces]). Taking
// the card gives the face's kind [omenMarks] levels by the card's rarity ([Omens._omenAdd]). A wave's falls ease them
// ([Omens._omenEase]), and an old save catches up on its Pusaka ([Omens.omenCatchUp]). What each kind does to the
// enemy (step 0d, decisions-log 188; docs/units-and-combat.md "Bayangan on the field") acts through the hooks here:
// every monster's stats through [Omens.spawnStats] (Haste, Mend, Lewati's skip buff), a slot's Shield at its spawn
// ([Omens._omenSpawn]), Armor, Thorns and the Shield's soak in [Game._hurt], Wound in the heal funnel (heal.dart), and
// Guard's extra monsters in the wave's queue ([Omens._omenQueue]). The kinds' data: lib/omen_catalog.dart. On in every
// build since the owner switched them on (decisions-log 319); while [omensOn] is off, no face is drawn, no save key is
// written, no event is sent and no hook acts: a monster's stats are exactly [enemyStats]'s.

/// Whether the Bayangan are in the game: on (the owner, 2026-10-12, decisions-log 319: "Nyalakan"). Off, no face is
/// drawn ([Game.omenDice] untouched), no save key is written and no event is sent, so a save loads and plays as before
/// them: the off path a test switches to (and back in its tearDown), or a probe with `--dart-define=OMENS=false`.
bool omensOn = const bool.fromEnvironment('OMENS', defaultValue: true);

/// The first wave whose chest's cards hide a Bayangan: a chest rolled earlier has no faces, and Lewati owes no skip buff.
const omenFrom = 20;

/// The levels a take gives, by the card's rarity: Langka 1, Epik 2, Legenda 3 (the owner's answer 1), which the card
/// shows as red "!" marks while the kind stays secret.
const omenMarks = {Rarity.langka: 1, Rarity.epik: 2, Rarity.legenda: 3};

/// The most levels one kind holds. A take's levels past it overflow to the next kind of the card's pool ([omenPlace]).
const omenCap = 4;

/// The most kinds with a level at once (the HUD's chips, 0h). While this many are held, a kind not held yet counts as
/// full.
const omenKindsMax = 8;

/// The most troop-side kinds ([OmenKind.troopSide]: rules on the troops, not the monsters) with a level at once. While
/// this many are held, a troop-side kind not held yet counts as full ([omenPlace]).
const omenTroopRulesMax = 4;

/// The taken floor ([Omens._omenTaken]): the product of every Bayangan damage-taken factor on one blow on a monster
/// never goes below it.
const omenTakenFloor = 0.5;

/// The dealt cap ([Omens._omenDealt]): a monster's blow on a troop with every Bayangan add on it is never more than this
/// × the blow without them.
const omenDealtMost = 1.6;

/// The acting faces ([Omens._faces]): on, a card's face comes only from the kinds that can act on the army
/// ([omenCanAct]). A probe's knob, like the caps above (catalog-bayangan-v2 §5.3's OMEN_ACT=0 arm turns it off).
const omenActFilter = true;

/// The share of the draws whose face answers the card: its Pusaka's [Art.counter] (the owner's answer 4: about 2 of 9).
const omenTilt = 2 / 9;

/// The Beban factor ([Game.omenFactor], frozen at a wave's start beside Beban): an army over the cap meets stronger
/// Bayangan, by armySize / armyCap (1 at or under it, at most [omenOverMax]: 48 troops over a cap of 32 is ×1.5). Then
/// × [omenScale], and × [omenAtCap] while the army is at or under the cap. The probe's knobs (0i).
const omenScale = 1.0, omenAtCap = 1.0, omenOverMax = 2.0;

/// The ease: at a won wave's end each full [omenEaseShare] of the troops that started it fallen (6 of 48, 4 of 32)
/// takes the newest level away, at most [omenEaseMax] a wave.
const omenEaseShare = 0.125, omenEaseMax = 2;

/// What the ease counts as the wave's falls ([Omens.omenFalls]): [falls] every troop that fell, one bought back mid-wave
/// (Auto Buy) and fallen again too, as designed (decisions-log 180); [starters] only the troops that started the wave
/// ([Game.omenStarters]), each once; [awakened] only the falls of a type at Awaken 1 or more, so cheap un-awakened
/// troops ease nothing. The knob for the owner's answer on the ease (decisions-log 319: an army that loses its fodder
/// every wave eased every Shadow away); [omenEaseMax] caps the levels a wave.
enum OmenEaseCount { falls, starters, awakened }

/// The ease's count ([OmenEaseCount]): the owner's answer, [OmenEaseCount.awakened] (decisions-log 318; [falls] until
/// then, so an army of cheap fodder eased every Shadow away the wave after its chest).
const omenEaseCount = OmenEaseCount.awakened;

/// An old save's catch-up ([Omens.omenCatchUp]): at most [omenCatchUpMax] levels owed, landing [omenCatchUpStep] a wave
/// (the owner's answer 3).
const omenCatchUpMax = 12, omenCatchUpStep = 2;

/// The Bayangan's teal (catalog-design §2.6's extras): Shield's chip.
const tintTeal = 0xFF3FD0C0;

/// The Bayangan's olive, dark green and dark red (catalog-design §2.6's extras): Drag's, Scar's and Gloat's chips.
const tintOlive = 0xFF8A9A3A, tintDarkGreen = 0xFF3F7F3F, tintDarkRed = 0xFFA0322D;

/// The boss's and the mini boss's share of their effective level for Armor and Haste ([Omens.omenK]): 1, the probe's
/// arm (OMEN_SLOT) halves it. Shield is theirs alone and Mend never theirs, so neither reads it.
const omenSlotShare = 1.0;

/// Thorns' cap: one blow sends back at most this share of the troop's max HP.
const omenThornsCap = 0.05;

/// Lewati's skip buff (the owner's rule, catalog-design §4.4): in the next wave the first [skipBuffShare] of its
/// monsters by spawn order (rounded; [Game.skipBuffN]) get [skipBuffK] more HP, damage, attack speed (the floors kept)
/// and walk speed. No die; the spawn gap is untouched.
const skipBuffShare = 0.3, skipBuffK = 0.10;

/// The owner's answer (2026-10-03): no Bayangan is shared. Each kind sits in exactly one tier's pool, 30 a tier. Until
/// the tiers' cut-over batches today's seven sat in every pool, and each cut-over took some out (the Langka one, batch
/// L-3, decisions-log 209: Armor, Mend, Barrier and Escort; the Epik one, E-3, 223: Haste, Spikes, Wound, Barrier and
/// Escort); the Legenda one (batch G-3, decisions-log 243) took Armor, Mend, Haste, Spikes and Wound out of the Legenda
/// pool and turned this on: test/omen_test.dart holds every kind to one tier. The levels an old save holds of a kind
/// stay and act whatever pool it left; a card never shows it nor overflows into it there.
const omenOneTier = true;

/// The Langka pool alone ([OmenKind.tiers]): today's Haste, Spikes and Wound (since the Legenda cut-over) and every
/// Langka data batch's kind.
const _langka = {Rarity.langka};

/// The Epik pool alone ([OmenKind.tiers]): today's Armor and Mend (since the Legenda cut-over) and every Epik data
/// batch's kind.
const _epik = {Rarity.epik};

/// The Legenda pool alone ([OmenKind.tiers]): today's Barrier and Escort (since the Epik cut-over) and every Legenda
/// data batch's kind.
const _legenda = {Rarity.legenda};

/// Brace's HP line: it cuts a troop's blow on a monster over this share of its max HP (before the blow).
const omenBraceAbove = 0.9;

/// Stubborn's HP line: it cuts a troop's blow on a monster under this share of its max HP (before the blow).
const omenStubbornBelow = 0.3;

/// Defiant's share on the boss and the mini boss (by rank, a raised one too): half.
const omenDefiantBoss = 0.5;

/// Avenge: a monster that dies gives the monsters within [omenAvengeReach] px of it an omen might for [omenAvengeTime] s.
const omenAvengeTime = 3, omenAvengeReach = tile;

/// Eager: a monster that comes on (not one raised) gets an omen might for this many s.
const omenEagerTime = 5;

/// Straggler: a monster with no other monster within this many tiles of it is alone.
const omenStragglerTiles = 2;

/// Pummel: every this many normal attacks of a monster ([Unit.blows]), one hits harder.
const omenPummelEvery = 3;

/// Sap: every this many normal attacks of a monster (on [Unit.blows], the count Pummel reads), the troop it hits deals
/// less damage for [omenSapTime] s.
const omenSapEvery = 4, omenSapTime = 2;

/// The longest a Bayangan's troop debuff ([OmenKind.debuff]: Sap, Bat Venom, Blight) lasts on a troop, s
/// (catalog-design §2.5).
const omenDebuffMax = 3;

/// Bat Venom: a bat's bite makes the troop it lands on lose a share of its max HP a second, this many s (a tick a
/// second, at most [omenDebuffMax]).
const omenBatVenomTime = 3;

/// The monster type whose bite carries Bat Venom.
const omenBatVenomType = 'bat';

/// Arrow Ward: a monster that comes on takes less from the troops that shoot for this many s.
const omenArrowWardTime = 6;

/// Enrage: a monster hits harder once this many s have passed since its first blow ([Unit.firstStrikeAt]).
const omenEnrageAfter = 10;

/// Counterspell: a troop's skill shields each high elite within [omenCounterspellReach] px of the caster for
/// [omenCounterspellTime] s, each at most once every [omenCounterspellEvery] s ([Unit.counterAt]).
const omenCounterspellTime = 3, omenCounterspellReach = 2.5 * tile, omenCounterspellEvery = 6;

/// Wear Down's guard (catalog-bayangan-v2 §6, Risk 1): what it adds to a monster's blow is at most this share of the
/// blow (after the monster's might), so a tank's big max HP never turns a weak hit into a big one; the dealt cap
/// ([omenDealtMost]) holds it with the rest. The design's fallback, if a probe finds the front falling: 0.35 (and max
/// 0.006).
const omenWearDownBlow = 0.5;

/// Zeal: a monster a monster healer's heal gave HP to deals more for this many s.
const omenZealTime = 3;

/// Muster: a boss or mini boss at or under [omenMusterAt] percent of its HP for the first time gives the monsters
/// within [omenMusterReach] px of it an omen might for [omenMusterTime] s; [omenMusterBit] is its bit on
/// [Unit.belowHp] ([FxEngine.belowOnce]: the Bayangan kinds' bits on a monster, one each).
const omenMusterAt = 60, omenMusterReach = 3 * tile, omenMusterTime = 5, omenMusterBit = 0;

/// Second Skin: a monster below a mini boss at or under [omenSecondSkinAt] percent of its HP for the first time gets an
/// omen absorb for [omenSecondSkinTime] s; [omenSecondSkinBit] is its bit on [Unit.belowHp].
const omenSecondSkinAt = 50, omenSecondSkinTime = 6, omenSecondSkinBit = 2;

/// Bile Sacs: a slime that dies hurts each troop within [omenBileReach] px of it, a troop at most once every
/// [omenBileEvery] s ([Unit.bileAt]).
const omenBileReach = tile, omenBileEvery = 0.5;

/// The monster types Blood Moon's lifesteal comes on with: the wolves and the bears.
const omenBloodMoonTypes = {'werewolf', 'werebear'};

/// Blood Moon: a wolf or a bear that comes on heals a share of what it deals for this many s.
const omenBloodMoonTime = 8;

/// Last Rage: a monster below a mini boss at or under [omenLastRageAt] percent of its HP for the first time gets an omen
/// might for [omenLastRageTime] s; [omenLastRageBit] is its bit on [Unit.belowHp].
const omenLastRageAt = 35, omenLastRageTime = 4, omenLastRageBit = 1;

/// Parting Gift: a monster that dies heals each monster below a mini boss within [omenPartingGiftReach] px of it, a
/// monster at most once every [omenPartingGiftEvery] s ([Unit.giftAt]).
const omenPartingGiftReach = 1.5 * tile, omenPartingGiftEvery = 1;

/// Captain: a monster with a living high elite (not itself) within this many px of it takes less from the troops.
const omenCaptainReach = 1.5 * tile;

/// Close Ranks: a monster that dies guards each monster within [omenCloseRanksReach] px of it for [omenCloseRanksTime] s.
const omenCloseRanksReach = tile, omenCloseRanksTime = 1.5;

/// Blindside: a troop that struck another monster less than this many s ago ([Unit.lastFoe]) is busy with it.
const omenBlindsideBusy = 1.5;

/// Triumph: a troop that falls hastens each monster below a mini boss within [omenTriumphReach] px of it for
/// [omenTriumphTime] s.
const omenTriumphReach = 2 * tile, omenTriumphTime = 3;

/// The monsters' pop red (skills.dart's `_monsterPop`, the chest's "!" marks): Triumph's chip.
const tintPop = 0xFFFF6B5E;

/// The Bayangan's rust (catalog-design §2.6's extras): Rust's and Spite's chips.
const tintRust = 0xFFC8641E;

/// Prey: a monster's blow on a troop under this percent of its max HP (before the blow) hits harder.
const omenPreyBelow = 30;

/// Herd Hunt: a monster's blow on a troop whose type has at least this many troops alive ([Game.aliveOf]) hits harder.
const omenHerdHuntAt = 10;

/// Heal Siphon: what a troop's heals in a wave owe ([Unit.siphonDue]) is paid every [omenHealSiphonEvery] s to the
/// nearest monster below a mini boss within [omenHealSiphonReach] px of it.
const omenHealSiphonReach = 3 * tile, omenHealSiphonEvery = 1;

/// The heals Trickle spreads over its time ([Heal._healTroop]): a healer's heal, Healing Prayer, Sacrifice and a
/// Pusaka's heal. The rescues (Unbroken, Lifeline), regen, the heal statuses, a fang's, the after-wave heal and the
/// Grail's save land at once.
const omenTrickled = {HealSrc.heal, HealSrc.prayer, HealSrc.sacrifice, HealSrc.pusaka};

/// Toll: a troop that kills a monster loses a share of its max HP, at most once every [omenTollEvery] s ([Unit.tollAt]),
/// never below [omenTollAbove] percent of it.
const omenTollEvery = 2, omenTollAbove = 25;

/// Blunt: on a silver, gold or boss monster, the part of a troop's blow past this percent of its max HP is cut. The
/// design's fallback (catalog-bayangan-v2 §6, Risk 2), if a probe finds the boss kill time too long: 30 (and max 0.2).
const omenBluntOver = 20;

/// Horde: every [omenHordePer] monsters alive on the field ([Omens._omenHorde]) is a step of its cut, at most
/// [omenHordeSteps] steps. The design's fallback (catalog-bayangan-v2 §6, Risk 5): max 0.04 a step.
const omenHordePer = 10, omenHordeSteps = 3;

/// Cover: a boss or mini boss with another living monster within this many px of it ([FxEngine.alliesNearOf], the
/// same-side count) takes less from the troops.
const omenCoverReach = 1.5 * tile;

/// Side Swing: a melee monster's normal attack on a troop also hits the nearest other troop within this many px of it.
const omenSideSwingReach = tile;

/// Adapt: the most hits in a row past the first that its cut counts ([Unit.adaptRun], the HUD's `{cap}`). The design's
/// fallback (catalog-bayangan-v2 §6, Risk 3), if a probe finds the front's runs too long: max 0.075 a step, then the run
/// counted per attacking troop, not per type.
const omenAdaptSteps = 3;

/// Spree: the most troop kills a silver or gold monster's damage counts ([Unit.troopKills], the HUD's `{cap}`). The
/// design's fallback (catalog-bayangan-v2 §6, Risk 4: the kill snowball with Gloat and Triumph): max 0.06 a kill.
const omenSpreeKills = 3;

/// Vultures: the monster ranks that pick the most hurt troop they reach, by its level L (L1-2 the high elites; L3-4 the
/// elites too; never the boss or a mini boss), and their rank words for the HUD's `{who}`.
const omenVulturesRanks = [
  {Tier.highElite},
  {Tier.highElite},
  {Tier.elite, Tier.highElite},
  {Tier.elite, Tier.highElite},
];

/// Vultures: a monster that shoots picks only among the troops within this many px of its current target.
const omenVulturesNear = 1.5 * tile;

/// Mana Burn: a monster's blow takes a troop's MP at most once every this many s ([Unit.burnAt]).
const omenManaBurnEvery = 0.5;

/// Backlash: a troop's skill raises each monster within [omenBacklashTiles] tiles of it for [omenBacklashTime] s, a
/// monster at most once every [omenBacklashEvery] s ([Unit.backlashAt]).
const omenBacklashTiles = 2, omenBacklashTime = 3, omenBacklashEvery = 1;

/// Last Gasp: the boss or a mini boss at or under [omenLastGaspAt] percent of its HP for the first time heals; its bit on
/// [Unit.belowHp] is [omenLastGaspBit].
const omenLastGaspAt = 40, omenLastGaspBit = 3;

/// Rider Rush: the monster type whose first hit on a troop hits harder ([Unit.rushed]).
const omenRiderRushType = 'orc_rider';

/// Dusk: the monsters hit harder from this many s after the wave's last crowd monster came on ([Omens._omenDusk]).
const omenDuskAfter = 30;

/// One thing in the army a kind may need to act ([OmenKind.needs]; catalog-bayangan-v2 §5.1's `needs` table), met when
/// the army has a source of it ([Omens.omenMet], read once a roll). [built]: today's code can answer it. One not built
/// is never met yet: the batch that brings its first kind builds it (test/omen_rules_test.dart holds every live kind's
/// needs to built ones).
enum OmenNeed {
  /// A living troop type with an MP skill (every type has one today), not under Vow of Silence (batch G-1P: it casts
  /// none).
  mpSkill(true),

  /// A Langka or Epik Pusaka bound to a living type with an Fx that works every few hits (every > 1: War Drum, Snare
  /// Cord, Challenge Letter; L-2P's Bleeding Edge, Shatter Shard, Riposte, Mana Leech, Spell Cutter; E-2P's Ember Brand
  /// and Warden's Horn). Not Twin Fury's: its every is the worn fury's ([Fx.furyBeat]).
  everyFx(true),

  /// A Langka or Epik Pusaka bound to a living type with an Fx on its own cooldown ([Fx.cooled]: Dulling Mail's, batch
  /// L-1P, the first; L-2P's Shatter Shard, Pain Crystal and Spell Cutter; E-2P's Funeral Pyre, Null Stone and Warden's
  /// Horn).
  cdFx(true),

  /// A troop shield source: a bound ward Fx (Watch Shield, Bone Buckler: L-2P; Aegis Seal: E-2P), or a Hero's Veil of
  /// Light (the troop absorb skill).
  troopShield(true),

  /// A heal source: a living healer type, a bound heal Fx, or regen (a bound regen Fx, a troop's regen).
  heal(true),

  /// A troop taunt source: a Hero's Duel of Honour or Holy Taunt, a bound taunt Fx (Challenge Letter on a melee type;
  /// Warden's Horn, E-2P).
  taunt(true),

  /// A might or haste source on troops: a Hero's War Cry, War Banner, Eagle Eye or Last Stand, a bound might or haste
  /// Fx on troops (Rune Gauntlet's, Fallen Flag's; Glory Seeker's, batch G-2).
  mightOrHaste(true),

  /// Vengeance Mark or Ember Brand bound (G-1P, E-2P): a bound mark Fx ([Eff.mark]; built with Ember Brand, the first
  /// of them in the catalog), or one that puts Vengeance Mark's [Status.pusakaMark] on a monster.
  spiteMark(true),

  /// A mark source: Void Eye bound (a mark Fx), a Hero's Hunter's Mark (the vulnerable skill). Ember Brand and
  /// Vengeance Mark come as mark Fx.
  mark(true),

  /// A troop slow source: a Hero's Crippling Shot, Earthquake, Frost Storm or Curse of Weakness, a bound slow Fx.
  slow(true),

  /// A troop hold source: the lancers' Impale (its pin, [Status.impaled]), a bound pin Fx.
  hold(true),

  /// A troop stun source: the axemen's Crushing Blow, the lancers' Impale (its stagger), a Hero's Shield Bash, Guardian
  /// Leap, Cavalry Charge, Spear Wall or Chain Hook.
  stun(true),

  /// A troop weaken source: a Hero's Curse of Weakness, the soldiers' Disarm, a bound weaken Fx on monsters.
  weaken(true),

  /// A troop hex source: a Hero's Slime Hex, a bound hex Fx (Hex Blade's, batch G-2).
  hex(true),

  /// An extra-hit source ([Hit.extra]): a troop whose blows splash, a bound leap or burst Fx (on the monsters near:
  /// Shatter Shard, L-2P; Funeral Pyre, E-2P; not a hit back).
  extraHit(true),

  /// A hit-back source ([Hit.hitBack]): worn thorns, a Hero's Parry or Iron Skin, a bound hit-back Fx (a burst on the
  /// attacker: Riposte, L-2P; a reflect on itself: Mirror Shield, G-1P).
  hitBack(true),

  /// A living healer type.
  healer(true),

  /// A living Hero.
  hero(true),

  /// An oath held.
  oath(true),

  /// A small relic worn by a living troop.
  smallRelic(true);

  const OmenNeed(this.built);
  final bool built;
}

/// Whether [kind] can act on an army that meets [met] ([Omens.omenMet], at the roll): it needs nothing, or one of its
/// [OmenKind.needs] is met. Pure. Today's seven always act.
bool omenCanAct(OmenKind kind, Set<OmenNeed> met) => kind.needs.isEmpty || kind.needs.any(met.contains);

/// What [kind] does at effective level [e]: [OmenKind.k]'s perE × [e], at most its max; 0 at no level. The one capped
/// share: the hooks read it ([Omens.omenK]) and the HUD shows it ([omenShown]), so the number shown is the number that
/// acts.
double omenShare(OmenKind kind, double e) => e > 0 ? min(kind.k.max, kind.k.perE * e) : 0;

/// A kind's HUD numbers ([omenShown]): `{x}` its share, `{n}` its count, `{who}` its rank word, `{cap}` its named total.
typedef OmenShown = ({double x, num n, String who, double cap});

/// What [kind]'s HUD line shows at level [level] and effective level [e] (the HUD's chips and tooltip, 0h fills the
/// line): `{x}` its share ([omenShare]), `{n}` its count by L ([OmenKind.byL]; 0 with none), `{who}` its rank word by L
/// ([OmenKind.who]; '' with none) and `{cap}` its named total, the share × its [OmenKind.steps]. Pure.
OmenShown omenShown(OmenKind kind, int level, double e) {
  final x = omenShare(kind, e);
  T? at<T>(List<T> byL) => level <= 0 || byL.isEmpty ? null : byL[min(level, byL.length) - 1];
  return (x: x, n: at(kind.byL) ?? 0, who: at(kind.who) ?? '', cap: x * kind.steps);
}

// The sources [Omens.omenMet] reads, by what gives them.

/// The Hero skills that are a source of a need: what each puts on a monster or a troop (hero_skills.dart, hero_moves.dart).
const _heroSkillNeeds = <HeroSkill, Set<OmenNeed>>{
  HeroSkill.warCry: {OmenNeed.mightOrHaste},
  HeroSkill.lastStand: {OmenNeed.mightOrHaste},
  HeroSkill.banner: {OmenNeed.mightOrHaste},
  HeroSkill.eagleEye: {OmenNeed.mightOrHaste},
  HeroSkill.shieldBash: {OmenNeed.stun},
  HeroSkill.rescueLeap: {OmenNeed.stun},
  HeroSkill.charge: {OmenNeed.stun},
  HeroSkill.spearWall: {OmenNeed.stun},
  HeroSkill.hook: {OmenNeed.stun},
  HeroSkill.parry: {OmenNeed.hitBack},
  HeroSkill.ironSkin: {OmenNeed.hitBack},
  HeroSkill.duel: {OmenNeed.taunt},
  HeroSkill.holyTaunt: {OmenNeed.taunt},
  HeroSkill.crippleShot: {OmenNeed.slow},
  HeroSkill.quake: {OmenNeed.slow},
  HeroSkill.frostStorm: {OmenNeed.slow},
  HeroSkill.curse: {OmenNeed.weaken, OmenNeed.slow},
  HeroSkill.slimeHex: {OmenNeed.hex},
  HeroSkill.huntersMark: {OmenNeed.mark},
  HeroSkill.lightVeil: {OmenNeed.troopShield},
};

/// The troop skills ([troopSkills]) that are a source of a need: the axemen's Crushing Blow stuns.
const _troopSkillNeeds = <String, Set<OmenNeed>>{
  'armored_axeman': {OmenNeed.stun},
};

/// The awakening skills that are a source of a need: Disarm weakens, Impale pins (a hold) or staggers (a stun).
const _awakenSkillNeeds = <AwakenSkill, Set<OmenNeed>>{
  AwakenSkill.disarm: {OmenNeed.weaken},
  AwakenSkill.impale: {OmenNeed.hold, OmenNeed.stun},
};

/// The statuses a bound Fx puts on monsters that are a source of a need.
const _statusNeeds = <Status, Set<OmenNeed>>{
  Status.slow: {OmenNeed.slow},
  Status.impaled: {OmenNeed.hold},
  Status.taunt: {OmenNeed.taunt},
  Status.weaken: {OmenNeed.weaken},
  Status.hex: {OmenNeed.hex},
};

/// Every [OmenKind.live] kind in its order: an old save's catch-up overflows along it ([Omens._omenWave]).
List<OmenKind> get omenOrder => [for (final k in OmenKind.values) if (k.live) k];

/// The kinds a card of [rarity] may hide, in their order, which the overflow follows too: the [OmenKind.live] kinds
/// whose [OmenKind.tiers] hold it.
List<OmenKind> omenPool(Rarity rarity) => [for (final k in OmenKind.values) if (k.live && k.tiers.contains(rarity)) k];

/// The kind that answers Pusaka [relic] on [type]: its row's [Art.counter], or on a healer type its [Art.healerCounter]
/// (Dawn Star on a priest: Heal Siphon, since the Epik cut-over).
OmenKind omenCounter(Relic relic, String? type) {
  final art = pusakaCatalog[relic]!;
  return (troopTypes[type]?.heals ?? false) ? art.healerCounter ?? art.counter : art.counter;
}

/// The face a card of [relic] on [type] shows for the draw [u] (0 to 1): below [omenTilt] its counter ([omenCounter]),
/// else a kind of its pool ([omenPool]) that can act on the army ([acts]: [omenCanAct] at the roll; none given: every
/// kind), each as likely. The same single [u] either way, so a card stays one draw. The tilt's counter is exempt: the
/// card itself is its condition. A counter outside the pool spreads the whole draw over the acting kinds; with none
/// acting, over the whole pool. Null for a Serpihan, or with an empty pool.
OmenKind? omenFace(Relic? relic, String? type, double u, [bool Function(OmenKind kind)? acts]) {
  if (relic == null) return null;
  final all = omenPool(relic.rarity), counter = omenCounter(relic, type);
  if (all.isEmpty) return null;
  final acting = acts == null ? all : [for (final k in all) if (acts(k)) k], pool = acting.isEmpty ? all : acting;
  if (!all.contains(counter)) return pool[min(pool.length - 1, (u * pool.length).floor())];
  if (u < omenTilt) return counter;
  return pool[min(pool.length - 1, ((u - omenTilt) / (1 - omenTilt) * pool.length).floor())];
}

/// Where [n] levels for [face] go, given the levels [held] (one entry a level), one entry a level placed: [face] while it
/// has room, then the next kind of [pool] after it (wrapping round to its start). A kind has room under [cap] levels; a
/// kind not held yet only while fewer than [kindsMax] kinds are, and a troop-side one ([OmenKind.troopSide]) only while
/// fewer than [troopMax] troop-side kinds are. Shorter than [n] when no kind has room: "penuh".
List<OmenKind> omenPlace(List<OmenKind> held, OmenKind face, List<OmenKind> pool, int n,
    {int cap = omenCap, int kindsMax = omenKindsMax, int troopMax = omenTroopRulesMax}) {
  final levels = <OmenKind, int>{};
  for (final k in held) {
    levels[k] = (levels[k] ?? 0) + 1;
  }
  final at = pool.indexOf(face);
  final order = [face, for (var j = 1; j <= pool.length; j++) if (pool[(at + j) % pool.length] case final k when k != face) k];
  final placed = <OmenKind>[];
  for (var i = 0; i < n; i++) {
    final to = order.where((k) {
      final l = levels[k] ?? 0;
      return l < cap && (l > 0 || (levels.length < kindsMax && (!k.troopSide || levels.keys.where((h) => h.troopSide).length < troopMax)));
    }).firstOrNull;
    if (to == null) break;
    levels[to] = (levels[to] ?? 0) + 1;
    placed.add(to);
  }
  return placed;
}

/// The Bayangan's rules.
extension Omens on Game {
  /// How many levels the enemy holds of [kind] ([Game.omens]).
  int omenLevel(OmenKind kind) => omens.where((k) => k == kind).length;

  /// [kind]'s effective level E in the wave being fought: its level × [Game.omenFactor]; 0 while [omensOn] is off. The
  /// hooks read it through [omenK].
  double omenE(OmenKind kind) => omensOn ? omenLevel(kind) * omenFactor : 0;

  /// What [kind] does in the wave being fought: [OmenKind.k]'s perE × E, at most its max, where E is its effective
  /// level ([omenE]) × [share] (a slot's [omenSlotShare] for Armor and Haste). 0 while [omensOn] is off or it has no level.
  double omenK(OmenKind kind, {double share = 1}) => omenShare(kind, omenE(kind) * share);

  /// Guard: how many guards each boss and mini boss brings, its count by its level L ([OmenKind.byL], ⌈perE × L⌉ at most
  /// its max: 1, 1, 2, 2; a count, so not E), as the HUD shows it ([omenShown]). 0 while [omensOn] is off.
  int get omenGuards => omensOn ? omenShown(OmenKind.guard, omenLevel(OmenKind.guard), 0).n.toInt() : 0;

  /// What the army meets now ([OmenNeed]; only the built ones), for [omenCanAct]: read once a roll ([_faces]), from the
  /// living troops (their types, small relics, splash and regen), their Heroes' skills (while [Game.heroSkills]), their
  /// types' skills (while [Game.skills]) and awakening skills (while [Game.awakenSkills]; none of the three, nor its MP
  /// skill, for a type under Vow of Silence), the oaths held and the Fx of the Pusaka bound to a living type (one that
  /// needs a melee holder, [If.melee], only on a type that fights up close).
  Set<OmenNeed> get omenMet {
    final met = <OmenNeed>{}, types = <String>{};
    for (final u in troops) {
      if (!u.alive) continue;
      types.add(u.type);
      if (u.relics.isNotEmpty) met.add(OmenNeed.smallRelic);
      if (u.relics.contains(Relic.thorns)) met.add(OmenNeed.hitBack);
      if (u.stats.heals) met.addAll(const {OmenNeed.healer, OmenNeed.heal});
      if (u.stats.regen > 0) met.add(OmenNeed.heal);
      if (u.stats.splash > 0) met.add(OmenNeed.extraHit);
      if (u.hero) met.add(OmenNeed.hero);
      if (u.hero && heroSkills && !_silent(u.type)) met.addAll(_heroSkillNeeds[u.heroSkill] ?? const {});
    }
    for (final type in types) {
      if (_silent(type)) continue; // under Vow of Silence it casts no skill (pusaka_engine.dart)
      if ((troopSkills[type]?.cost ?? 0) > 0) met.add(OmenNeed.mpSkill);
      if (skills) met.addAll(_troopSkillNeeds[type] ?? const {});
      if (awakenSkills && awakenLevel(type) > 0) met.addAll(_awakenSkillNeeds[awakenSkillOf(type)] ?? const {});
    }
    for (final MapEntry(key: r, value: p) in pusaka.entries) {
      if (r.oath) met.add(OmenNeed.oath);
      if (!types.contains(p.type)) continue; // in the Gudang, or on a type with none alive
      final art = pusakaCatalog[r]!, low = art.rarity == Rarity.langka || art.rarity == Rarity.epik;
      for (final fx in art.fx) {
        if (fx.when == If.melee && !(troopTypes[p.type]?.melee ?? false)) continue; // a melee holder's, on a type that shoots
        final onFoes = fx.to == To.foeHit || fx.to == To.nearFoes || fx.to == To.attacker;
        if (low && fx.every > 1 && !fx.furyBeat) met.add(OmenNeed.everyFx);
        if (low && fx.cooled) met.add(OmenNeed.cdFx);
        if (fx.eff == Eff.ward) met.add(OmenNeed.troopShield);
        // A heal Fx (not Mercy Lily's, which only raises the heals a troop gets), or a regen.
        if ((fx.eff == Eff.heal && !(fx.on == Trig.heals && fx.to == To.self)) || fx.regen > 0 || fx.stat == Stat.regen) met.add(OmenNeed.heal);
        if ((fx.eff == Eff.burst && fx.to == To.attacker) || fx.status == Status.reflect) {
          met.add(OmenNeed.hitBack); // a hit back (Riposte), a reflect (Mirror Shield)
        } else if (fx.eff == Eff.leap || (fx.eff == Eff.burst && fx.on != Trig.heals) || fx.stat == Stat.splash) {
          met.add(OmenNeed.extraHit); // a leap, a burst (Martyr's Flame's on a fall too), a splash (Wide Blows); Wrath Psalm's is a smite
        }
        if (fx.eff == Eff.mark || const {Status.voidMark, Status.vulnerable, Status.pusakaMark}.contains(fx.status)) met.add(OmenNeed.mark);
        if (fx.eff == Eff.mark || fx.status == Status.pusakaMark) met.add(OmenNeed.spiteMark); // Ember Brand, Vengeance Mark
        if (fx.eff == Eff.status && !onFoes && (fx.status == Status.might || fx.status == Status.haste)) met.add(OmenNeed.mightOrHaste);
        if (fx.eff == Eff.status && onFoes) met.addAll(_statusNeeds[fx.status] ?? const {});
      }
    }
    return met;
  }

  /// The Beban factor the HUD shows ([omenShownK]): the wave's own, frozen at its start ([Game.omenFactor]), or between
  /// waves the one the next wave would freeze with the army as it stands now.
  double get omenShownFactor => waveActive ? omenFactor : _omenFactorNow;

  /// [OmenKind.k]'s share at the shown factor ([omenShownFactor]): what [kind] does in the wave being fought, or between
  /// waves in the next one with the army as it stands. 0 while [omensOn] is off or it has no level.
  double omenShownK(OmenKind kind) => omenShare(kind, omensOn ? omenLevel(kind) * omenShownFactor : 0);

  /// [kind]'s line in the HUD's tooltip: "Armor 2: Monsters take 10% less damage." ([omenEffect]).
  String omenLine(OmenKind kind) => '${kind.title} ${omenLevel(kind)}: ${omenEffect(kind)}';

  /// What [kind] does now, [OmenKind.hud] filled from its HUD numbers ([omenShown] at its level and the shown factor,
  /// [omenShownFactor]; none while [omensOn] is off): "Monsters take 10% less damage.", "Each boss and mini boss brings
  /// 1 more strong monster.", Trickle's "... over 0.8s ..."; Grudge's `{type}` its target ([Game.grudgeType]: in a wave the one it hits, between waves
  /// the next wave's), "none" with none.
  String omenEffect(OmenKind kind) {
    final l = omensOn ? omenLevel(kind) : 0, v = omenShown(kind, l, l * omenShownFactor);
    return kind.hud
        .replaceAll('{x}', omenPercent(v.x))
        .replaceAll('{sec}', _omenNum(v.x, 2))
        .replaceAll('{n}', '${v.n}')
        .replaceAll('{s}', v.n == 1 ? '' : 's')
        .replaceAll('{es}', v.n == 1 ? '' : 'es')
        .replaceAll('{who}', v.who)
        .replaceAll('{cap}', omenPercent(v.cap))
        .replaceAll('{type}', troopTypePlurals[grudgeType] ?? 'none');
  }

  /// The HUD's tooltip over the Shadows' chips (omen_look.dart): its title and a line for each kind held ([omenLine]),
  /// in [OmenKind] order; while the army is over the cap the factor it is under ("Over the army cap (48/36): Shadows
  /// x1.33"; in a wave the troops that started it); an old save's catch-up still to come ("Late Shadow: 6 more, 2 each
  /// wave"); and Lewati's skip buff, owed or on ([skipNote]).
  (String, List<String>) get omenTip {
    final f = omenShownFactor, troops = waveActive ? omenTroops : armySize;
    return (
      'Monster ${Words.shadow}s',
      [
        for (final k in OmenKind.values)
          if (omenLevel(k) > 0) omenLine(k),
        if (armyMax != null && troops > armyCap && f > 1) 'Over the army cap ($troops/$armyCap): ${Words.shadow}s x${_omenNum(f, 2)}',
        if (omensOwed.isNotEmpty) 'Late ${Words.shadow}: ${omensOwed.length} more, $omenCatchUpStep each wave',
        if (skipBuffDue || waveSkipBuff) skipNote(now: waveSkipBuff && !skipBuffDue),
      ]
    );
  }

  /// Lewati's skip buff in words, for the next wave (on the chest, armed; the HUD's chip while it is owed) or [now], the
  /// wave it is on: "Skip: next wave, the first 30% of monsters get +10% to all".
  String skipNote({bool now = false}) =>
      '${Words.skip}: ${now ? 'this' : 'next'} wave, the first ${omenPercent(skipBuffShare)}% of monsters get +${omenPercent(skipBuffK)}% to all';

  /// The message once for an old save's catch-up ([Game.omenCaughtUp]): "Monsters answer your Artifacts: 12 Shadows
  /// come, 2 each wave".
  String get omenCatchUpNote =>
      'Monsters answer your ${Words.artifact}s: ${omensOwed.length} ${Words.shadow}s come, $omenCatchUpStep each wave';

  /// What a take gave the enemy, the levels [plan] placed ([omenPlace]), each kind at its level now: "Monsters got Armor
  /// 2", an overflow's "Monsters got Armor 4, Haste 1"; none placed (every kind full): "Monsters: full".
  String omenGotLine(List<OmenKind> plan) =>
      plan.isEmpty ? 'Monsters: full' : 'Monsters got ${[for (final k in {...plan}) '${k.title} ${omenLevel(k)}'].join(', ')}';

  /// The Shadows a monster's plate names among its kinds (plates.dart): Armor and Spikes, which every monster has while
  /// they are held. None while [omensOn] is off.
  List<String> get omenPlateKinds => [
        for (final k in const [OmenKind.armor, OmenKind.thorns])
          if (omensOn && omenLevel(k) > 0) k.title,
      ];

  /// A monster's stats as it comes on in the wave being fought, at every route a monster's stats are made by: the
  /// wave's queue ([Game.monster]), a necromancer's raised minions ([Game._summon], and [Game.decideSummon]'s count of
  /// them, which must match), a skill's bring-in ([BossSkills._bringIn]), Slime Hex's form, and the boss's blow a
  /// Dragon Crown tooltip counts ([Pusaka.bossBlowsLived]: another wave [at], from [tideStart]). [enemyStats] with this
  /// wave's tide ([Game.waveTideFrom]), then the Bayangan's stat hooks ([_omenStats]); Lewati's skip buff for one of
  /// the wave's first monsters ([skipBuff]). Exactly [enemyStats]'s while [omensOn] is off.
  Stats spawnStats(String type, Tier tier, {bool raised = false, bool skipBuff = false, int? at, int? tideStart}) =>
      _omenStats(enemyStats(type, tier, at ?? wave, raised: raised, tideStart: tideStart ?? waveTideFrom), type, tier,
          raised: raised, skipBuff: skipBuff);

  /// An old save's catch-up ([Game.omensOwed]): every owned Pusaka (the store's too) owes [omenMarks] × its stars
  /// levels of its counter ([omenCounter] on its type), dealt one level at a time round-robin in [Relic] order, at most
  /// [omenCatchUpMax]. The b86 save's five Epik at ★1 (since the Epik cut-over, decisions-log 223): Wear Down 2 (Dragon
  /// Heart), Heal Siphon 2 (Dawn Star on the priests), Mend 2, Prey 2 (the Grail), Armor 2.
  List<OmenKind> omenCatchUp() {
    final debts = [
      for (final r in Relic.values)
        if (pusaka[r] case final p?) (kind: omenCounter(r, p.type), n: omenMarks[r.rarity]! * p.stars),
    ];
    final owed = <OmenKind>[];
    for (var round = 0; owed.length < omenCatchUpMax && debts.any((d) => d.n > round); round++) {
      for (final d in debts) {
        if (d.n > round && owed.length < omenCatchUpMax) owed.add(d.kind);
      }
    }
    return owed;
  }

  // The rules' insides.

  /// The Bayangan's stat hooks on the stats [s] of a monster of [type] and [tier] ([spawnStats]; a [raised] one is no
  /// slot): Haste divides its attack pause by 1 + its share (the floors stay: [Game.attackEvery]), Mend gives it regen
  /// of its share of its max HP a second (never a slot's), Dark Hymn raises a healer's heal (its [Stats.dmg]) and Bone
  /// Arrows a skeleton archer's damage by 1 + their share, Old Bones a skeleton kind's HP ([skeletonKinds], any rank),
  /// Hardy an elite's and a high elite's HP (a raised one's too), Oathbane the boss's and a mini boss's HP while an oath
  /// is held (by rank, a raised one's too: [_omenOathbane]), and Lewati's skip buff ([skipBuff]) gives it [skipBuffK] more
  /// HP, damage, attack speed and walk speed. [s] itself while [omensOn] is off or nothing acts.
  Stats _omenStats(Stats s, String type, Tier tier, {bool raised = false, bool skipBuff = false}) {
    if (!omensOn) return s;
    final slot = _isSlot(tier, raised: raised);
    final haste = omenK(OmenKind.haste, share: slot ? omenSlotShare : 1), mend = slot ? 0.0 : omenK(OmenKind.mend);
    final hymn = s.heals ? omenK(OmenKind.darkHymn) : 0.0, arrows = type == 'skeleton_archer' ? omenK(OmenKind.boneArrows) : 0.0;
    final bones = skeletonKinds.contains(type) ? omenK(OmenKind.oldBones) : 0.0;
    final hardy = tier == Tier.elite || tier == Tier.highElite ? omenK(OmenKind.hardy) : 0.0;
    final oathbane = tier == Tier.boss || tier == Tier.miniBoss ? _omenOathbane() : 0.0;
    if (haste == 0 && mend == 0 && hymn == 0 && arrows == 0 && bones == 0 && hardy == 0 && oathbane == 0 && !skipBuff) return s;
    final up = skipBuff ? 1 + skipBuffK : 1.0;
    final hp = skipBuff || bones > 0 || hardy > 0 || oathbane > 0
        ? (s.hp * up * (1 + bones) * (1 + hardy) * (1 + oathbane)).round()
        : s.hp;
    return s._with(
        hp: hp,
        dmg: s.dmg * up * (1 + hymn) * (1 + arrows),
        speed: s.speed * up,
        rate: s.rate / ((1 + haste) * up),
        regen: s.regen + mend * hp);
  }

  /// Oathbane (in [_omenStats], the boss's or a mini boss's): its share while an oath is held ([Relic.oath]: one in
  /// [Game.pusaka]); 0 with none or with no level.
  double _omenOathbane() {
    final k = omenK(OmenKind.oathbane);
    return k > 0 && pusaka.keys.any((r) => r.oath) ? k : 0;
  }

  /// Whether a monster of [tier] is one of the wave's slots, its boss or mini boss: not one [raised] by a necromancer or
  /// a skill. Shield is theirs alone, Mend never theirs, and Armor and Haste count their [omenSlotShare].
  bool _isSlot(Tier tier, {bool raised = false}) => !raised && (tier == Tier.boss || tier == Tier.miniBoss);

  /// The Beban factor for the army as it stands now: armySize / armyCap (1 at or under it, at most [omenOverMax]) ×
  /// [omenScale], × [omenAtCap] at or under the cap. [_omenWave] freezes it for a wave.
  double get _omenFactorNow {
    final over = armyMax == null ? 1.0 : (armySize / max(1, armyCap)).clamp(1.0, omenOverMax);
    return over * omenScale * (over <= 1 ? omenAtCap : 1.0);
  }

  /// A monster [u] that just came on ([Game.monster], [Game._summon], [BossSkills._bringIn]; Slime Hex's swap is no
  /// spawn: [spawnStats] gives its form): a slot's Shield, [OmenKind.shield]'s share of its max HP that a blow breaks
  /// before its HP ([_shieldSoak]), gone at the wave's end ([HeroSkills._endEffects]); Eager's omen might for
  /// [omenEagerTime] s on one the wave brings (not one raised by a necromancer or a skill); Arrow Ward's omen shot
  /// ward for [omenArrowWardTime] s on any; Blood Moon's omen lifesteal for [omenBloodMoonTime] s on a wolf or a
  /// bear ([omenBloodMoonTypes]), healed with its own tag ([HeroSkills._answer], [MonsterHeal.bloodMoon]); and Unbowed's
  /// charges ([Unit.shrugs], [omenUnbowed]) on any.
  void _omenSpawn(Unit u) {
    if (!omensOn) return;
    u.shrugs = omenUnbowed;
    final raised = u.raisedBy != null;
    if (_isSlot(u.tier, raised: raised)) u.shield = u.maxHp * omenK(OmenKind.shield);
    final eager = raised ? 0.0 : omenK(OmenKind.eager);
    if (eager > 0) addEffect(u, Status.might, omenEagerTime.toDouble(), k: 1 + eager, omen: true);
    final ward = omenK(OmenKind.arrowWard);
    if (ward > 0) addEffect(u, Status.shotWard, omenArrowWardTime.toDouble(), k: 1 - ward, omen: true);
    final moon = omenBloodMoonTypes.contains(u.type) ? omenK(OmenKind.bloodMoon) : 0.0;
    if (moon > 0) addEffect(u, Status.lifesteal, omenBloodMoonTime.toDouble(), k: moon, omen: true);
  }

  /// Armor (in [_omenTaken], a troop's blow on monster [u], after its defence): the share of it [u] doesn't take, a
  /// slot's E counted at [omenSlotShare].
  double _omenArmor(Unit u) => omenK(OmenKind.armor, share: _isSlot(u.tier, raised: u.raisedBy != null) ? omenSlotShare : 1);

  /// The taken floor ([Game._hurt], blow [dmg] of [src] from [by] on monster [u], after its defence and its type's
  /// `struck` Fx, at Armor's site): what the blow is ×, the product of every Bayangan damage-taken factor on it, never
  /// below [omenTakenFloor]. Read once a blow. A troop's blow: Armor's, Brace's (over [omenBraceAbove] of its max HP),
  /// Stubborn's (under [omenStubbornBelow]), Bear Hide's (a werebear), Hard Shell's (a shield on it, [shielded]),
  /// Hunker's (a slow, a hold or a stun on it, [held]), Captain's (a high elite near it, [_captained]) and Grave Pact's
  /// (raised, [Unit.raisedBy], by one that lives), [u]'s HP read before the blow; Blunt's (the part of [dmg] past
  /// [omenBluntOver]% of a silver, gold or boss monster's max HP, as the blow's new / old), Horde's ([_omenHorde]: the
  /// monsters alive), Cover's (the boss or a mini boss with a monster next to it, [_omenCover]) and Adapt's (a normal or
  /// skill blow, by its run, [_omenAdapt]) and Holy Ward's (a troop healer's smite, [Hit.smite], on a skeleton kind). Any
  /// blow: Scatter's (an extra hit, [Hit.extra]), Thornproof's (a hit back, [Hit.hitBack]: worn thorns and Riposte name
  /// no attacker), Spell Ward's (a skill's blow, [Hit.skill], not a monster's: a troop's whose caster fell since names
  /// none) and a Bayangan's guard (Close Ranks') while it holds [u]'s
  /// guard slot ([Unit.guardOmen]; a monster skill's guard isn't counted, [Game._hurt] applies it after). The later data
  /// batches' taken-floor kinds (catalog-bayangan-v2 §3, "taken floor") multiply in here.
  double _omenTaken(Unit u, double dmg, Hit src, Unit? by) {
    var f = 1.0;
    if (by?.side == Side.troop) {
      f *= 1 - _omenArmor(u);
      if (u.hp > u.maxHp * omenBraceAbove) f *= 1 - omenK(OmenKind.brace);
      if (u.hp < u.maxHp * omenStubbornBelow) f *= 1 - omenK(OmenKind.stubborn);
      if (u.type == 'werebear') f *= 1 - omenK(OmenKind.bearHide);
      if (shielded(u)) f *= 1 - omenK(OmenKind.hardShell);
      if (held(u)) f *= 1 - omenK(OmenKind.hunker);
      final captain = omenK(OmenKind.captain);
      if (captain > 0 && _captained(u)) f *= 1 - captain;
      if (u.raisedBy?.alive ?? false) f *= 1 - omenK(OmenKind.gravePact);
      f *= _omenBlunt(u, dmg);
      f *= 1 - _omenHorde();
      f *= 1 - _omenCover(u);
      f *= 1 - _omenAdapt(u, by!, src);
      if (src == Hit.smite && skeletonKinds.contains(u.type)) f *= 1 - omenK(OmenKind.holyWard);
    }
    if (src == Hit.skill && by?.side != Side.enemy) f *= 1 - omenK(OmenKind.spellWard);
    if (src == Hit.extra) f *= 1 - omenK(OmenKind.scatter);
    if (src == Hit.hitBack) f *= 1 - omenK(OmenKind.thornproof);
    if (u.guardOmen && t < u.guardUntil) f *= 1 - u.guardCut;
    return max(omenTakenFloor, f);
  }

  /// The dealt cap ([Game._hurt], monster [by]'s blow [dmg] of [src] on troop [u], after [by]'s might and before [u]'s
  /// defence): the blow with every Bayangan add on it, never more than [omenDealtMost] × the blow without them. The add
  /// counts an omen might ([Effect.omen] on [by]'s [Status.might], already in [dmg]: the blow without it is [dmg] / its
  /// k), the dealt factors and Wear Down's share; a monster skill's might and the stat kinds (in [by]'s stats) aren't
  /// counted. Read once a blow. The dealt kinds (catalog-bayangan-v2 §3, "dealt cap") multiply or add to [up] here:
  /// Defiant's ([_omenDefiant]), Healer Hunt's (on a troop that heals), Straggler's ([_omenStraggler]), Grudge's (on a
  /// troop of [Game.grudgeType]), Pummel's (a normal attack [Game._strike] marked, [_omenPummel]), Enrage's ([by]
  /// [omenEnraged]), Envy's (on a troop with a boost, [_boosted]), Blindside's (on a troop busy with another monster,
  /// [_omenBlindside]), Prey's (on a troop under [omenPreyBelow]% of its max HP, read before the blow), Herd Hunt's (on
  /// a troop of a type with [omenHerdHuntAt] alive, [_omenHerdHunt]), Spite's ([by] under a troop's Pusaka mark,
  /// [_omenSpite]), Warlord's (while the wave's boss or mini boss lives, [_omenWarlord]), Spree's ([by]'s troop kills,
  /// [_omenSpree]), Hero Hunt's (on a Hero), Rider Rush's (an orc rider's first hit, [_omenRiderRush]), Dusk's (once the
  /// crowd is all in, [_omenDusk]) and Wear Down's share ([_omenWearDown], a normal attack's); Avenge's, Eager's, Zeal's,
  /// Muster's, Last Rage's and Backlash's are omen mights. The later batches' too.
  double _omenDealt(Unit u, double dmg, Hit src, Unit by) {
    final might = by.effects.isEmpty ? null : effectOn(by, Status.might);
    final base = might != null && might.omen && might.k > 0 ? dmg / might.k : dmg;
    var up = dmg;
    up *= 1 + _omenDefiant(u, by);
    if (u.stats.heals) up *= 1 + omenK(OmenKind.healerHunt);
    up *= 1 + _omenStraggler(by);
    if (u.type == grudgeType) up *= 1 + omenK(OmenKind.grudge);
    if (_pummeled && src == Hit.normal) up *= 1 + omenK(OmenKind.pummel);
    if (omenEnraged(by)) up *= 1 + omenK(OmenKind.enrage);
    up *= 1 + _omenEnvy(u);
    up *= 1 + _omenBlindside(u, by);
    if (u.hp < u.maxHp * omenPreyBelow / 100) up *= 1 + omenK(OmenKind.prey);
    up *= 1 + _omenHerdHunt(u);
    up *= 1 + _omenSpite(by);
    up *= 1 + _omenWarlord(by);
    up *= 1 + _omenSpree(by);
    if (u.hero) up *= 1 + omenK(OmenKind.heroHunt);
    up *= 1 + _omenRiderRush(by, src);
    up *= 1 + _omenDusk(by);
    if (src == Hit.normal) up += _omenWearDown(u, dmg);
    return up > base * omenDealtMost ? base * omenDealtMost : up;
  }

  /// Enrage: whether monster [u] hits harder now (in [_omenDealt]): [omenEnrageAfter] s or more since its first blow
  /// ([Unit.firstStrikeAt]), not the boss or a mini boss (by rank, a raised one too), with a level. The field rings it
  /// with its might's amber (skills.dart). False while [omensOn] is off.
  bool omenEnraged(Unit u) =>
      omensOn &&
      u.side == Side.enemy &&
      u.tier != Tier.boss &&
      u.tier != Tier.miniBoss &&
      t - u.firstStrikeAt >= omenEnrageAfter &&
      omenK(OmenKind.enrage) > 0;

  /// Envy (in [_omenDealt]): what a monster's blow on troop [u] gains while [u] has a damage or speed boost, a
  /// [Status.might] over 1 or a [Status.haste] under 1 from anything (a monster's slowing haste is none): its share; 0
  /// otherwise.
  double _omenEnvy(Unit u) {
    if (u.effects.isEmpty) return 0;
    final k = omenK(OmenKind.envy);
    if (k <= 0) return 0;
    final might = effectOn(u, Status.might), haste = effectOn(u, Status.haste);
    return (might != null && might.k > 1) || (haste != null && haste.k < 1) ? k : 0;
  }

  /// Herd Hunt (in [_omenDealt]): what a monster's blow on troop [u] gains while [omenHerdHuntAt] or more troops of
  /// [u]'s type are alive ([Game.aliveOf], [u] among them): its share; 0 otherwise or with no level.
  double _omenHerdHunt(Unit u) {
    final k = omenK(OmenKind.herdHunt);
    return k > 0 && aliveOf(u.type) >= omenHerdHuntAt ? k : 0;
  }

  /// Wear Down (in [_omenDealt], a monster's normal attack of [dmg] on troop [u], after the monster's might): what it
  /// adds, its share of [u]'s max HP, at most [omenWearDownBlow] × [dmg] (the Risk-1 guard); [u]'s defence takes it
  /// with the blow. 0 with no level.
  double _omenWearDown(Unit u, double dmg) {
    final k = omenK(OmenKind.wearDown);
    return k > 0 ? min(k * u.maxHp, omenWearDownBlow * dmg) : 0;
  }

  /// Spite (in [_omenDealt]): what monster [by]'s blow on a troop gains while a troop's Pusaka mark is on [by] (Ember
  /// Brand's one-hit mark, [Unit.emberMark], not run out; Vengeance Mark's [Status.pusakaMark], batch G-1P): its share; 0
  /// otherwise. Hunter's Mark's vulnerable and Void Eye's mark aren't read.
  double _omenSpite(Unit by) {
    final mark = by.emberMark;
    return (mark != null && t < mark.until) || (by.effects.isNotEmpty && under(by, Status.pusakaMark)) ? omenK(OmenKind.spite) : 0;
  }

  /// Warlord (in [_omenDealt]): what monster [by]'s blow on a troop gains while the wave's boss or mini boss lives (a
  /// living one of [Game.bossBarUnits]': entered, not raised; found at most once a tick, [Game._slotAlive]): its share; 0
  /// for the boss's or a mini boss's own blow (by rank), with none alive, or with no level. A raised minion's gains it.
  double _omenWarlord(Unit by) {
    if (by.tier == Tier.boss || by.tier == Tier.miniBoss) return 0;
    final k = omenK(OmenKind.warlord);
    if (k <= 0) return 0;
    if (_slotAliveTick != _ticks) {
      _slotAliveTick = _ticks;
      _slotAlive = enemies.any((o) => o.alive && o.entered && o.raisedBy == null && (o.tier == Tier.boss || o.tier == Tier.miniBoss));
    }
    return _slotAlive ? k : 0;
  }

  /// Spree (in [_omenDealt]): what monster [by]'s blow on a troop gains, its share × the troops it killed
  /// ([Unit.troopKills], at most [omenSpreeKills]; only a silver or gold one counts them, [_omenSpreeKill]); 0 with none.
  double _omenSpree(Unit by) => by.troopKills > 0 ? omenK(OmenKind.spree) * by.troopKills : 0;

  /// Spree ([Game._hurt], a troop fell to monster [by]): a silver or gold killer (by rank: never a normal one, a mini boss
  /// or the boss) counts the kill ([Unit.troopKills]), at most [omenSpreeKills], for its life. Nothing with no level.
  void _omenSpreeKill(Unit by) {
    if (by.side != Side.enemy || (by.tier != Tier.elite && by.tier != Tier.highElite) || omenK(OmenKind.spree) <= 0) return;
    by.troopKills = min(omenSpreeKills, by.troopKills + 1);
  }

  /// Rider Rush (in [_omenDealt]): what an orc rider's ([omenRiderRushType]) first normal or skill blow of [src] on a
  /// troop gains, its share, once a monster ([Unit.rushed], spent by that blow whatever becomes of it: a block, a
  /// cap); 0 for any later blow, another type's, or with no level (nothing spent then).
  double _omenRiderRush(Unit by, Hit src) {
    if (by.rushed || by.type != omenRiderRushType || (src != Hit.normal && src != Hit.skill)) return 0;
    final k = omenK(OmenKind.riderRush);
    if (k <= 0) return 0;
    by.rushed = true;
    return k;
  }

  /// Dusk (in [_omenDealt]): what monster [by]'s blow on a troop gains while Dusk has fallen ([Game.duskOn]): its share; 0
  /// for the boss's or a mini boss's own blow (by rank, a raised one too), before it falls, or with no level.
  double _omenDusk(Unit by) => duskOn && by.tier != Tier.boss && by.tier != Tier.miniBoss ? omenK(OmenKind.dusk) : 0;

  /// Dusk ([Game.tick], after its spawn, only while [omensOn] is on and Dusk has a level): the tick the wave's last crowd
  /// monster comes on ([Game._crowdLast], its place in the queue, [_omenCrowd]) is when the crowd is all in
  /// ([Game._crowdInAt]); from [omenDuskAfter] s later, the wave still on, Dusk has fallen ([Game.duskOn], until the next
  /// wave's start), and the battle log says so once ([OmenDusk]). It reads the queue and never moves the spawns.
  void _omenDuskTick() {
    if (!omensOn || duskOn) return;
    final k = omenK(OmenKind.dusk);
    if (k <= 0 || !waveActive) return; // between waves it waits for the next
    if (_crowdInAt == null && waveSpawned > _crowdLast) _crowdInAt = t;
    final from = _crowdInAt;
    if (from == null || t < from + omenDuskAfter) return;
    duskOn = true;
    _emit(OmenDusk(wave, t, level: omenLevel(OmenKind.dusk), share: k));
  }

  /// Dusk ([_omenQueue], the wave's queue made, Guard's monsters in it): the place of its last crowd monster, the last
  /// that isn't the boss or a mini boss, one of [escort] behind each of them (its escort) nor a Guard's
  /// ([Game._guardsAt]); -1 with none.
  int _omenCrowd(int escort) {
    final not = <int>{..._guardsAt};
    for (var i = 0; i < queue.length; i++) {
      if (_isSlot(queue[i].$2)) not.addAll([for (var k = 0; k <= escort; k++) i + k]);
    }
    for (var i = queue.length - 1; i >= 0; i--) {
      if (!not.contains(i)) return i;
    }
    return -1;
  }

  /// Last Gasp ([_omenBelow], a blow left monster [u] alive): the boss or a mini boss (by rank, a raised one too) at or
  /// under [omenLastGaspAt]% of its HP for the first time ([FxEngine.belowOnce], its bit [omenLastGaspBit]) heals its share
  /// of its max HP through the monster funnel ([MonsterHeal.lastGasp]: none under noHeal), the heal's sparkle on it when
  /// it gained HP; once. A blow that kills it gives none. Nothing with no level (the bit stays unused).
  void _omenLastGasp(Unit u) {
    final k = omenK(OmenKind.lastGasp);
    if (k <= 0 || !belowOnce(u, omenLastGaspAt / 100, omenLastGaspBit)) return;
    if (_healMonster(u, u.maxHp * k, MonsterHeal.lastGasp) > 0) impacts.add((u.pos, 'heal'));
  }

  /// Cover (in [_omenTaken], a troop's blow on monster [u]): its share while [u] is the boss or a mini boss (by rank, a
  /// raised one too) with another living monster on the field within [omenCoverReach] of it ([FxEngine.alliesNearOf],
  /// the same-side count, counted at most once a tick); 0 otherwise or with no level.
  double _omenCover(Unit u) {
    if (u.tier != Tier.boss && u.tier != Tier.miniBoss) return 0;
    final k = omenK(OmenKind.cover);
    return k > 0 && alliesNearOf(u, omenCoverReach) > 0 ? k : 0;
  }

  /// Adapt (in [_omenTaken], troop [by]'s blow of [src] on monster [u]): a normal or skill blow of the same troop type as
  /// the last one on [u] ([Unit.adaptType]) raises its run ([Unit.adaptRun]) by 1, at most [omenAdaptSteps]; another
  /// type's sets it to 0 and is remembered. What the blow loses: its share × the run. An extra hit, a bleed or a hit back
  /// neither counts nor loses anything (0), nor does any blow with no level.
  double _omenAdapt(Unit u, Unit by, Hit src) {
    if (src != Hit.normal && src != Hit.skill) return 0;
    final k = omenK(OmenKind.adapt);
    if (k <= 0) return 0;
    if (u.adaptType == by.type) {
      u.adaptRun = min(omenAdaptSteps, u.adaptRun + 1);
    } else {
      u
        ..adaptType = by.type
        ..adaptRun = 0;
    }
    return k * u.adaptRun;
  }

  /// Blunt (in [_omenTaken], a troop's blow of [dmg] on monster [u], after its defence): what the blow is ×, the part of
  /// it past [omenBluntOver]% of [u]'s max HP cut by its share, on a silver, gold or boss monster (by rank, a raised one
  /// too); 1 for a normal one, a blow at or under the line, or with no level.
  double _omenBlunt(Unit u, double dmg) {
    if (u.tier == Tier.normal) return 1;
    final k = omenK(OmenKind.blunt), line = u.maxHp * omenBluntOver / 100;
    return k > 0 && dmg > line ? (line + (dmg - line) * (1 - k)) / dmg : 1;
  }

  /// Horde (in [_omenTaken], a troop's blow on any monster, the boss and mini boss too): its share a step, a step every
  /// [omenHordePer] living monsters on the field (entered; counted at most once a tick, [Game._hordeN]), at most
  /// [omenHordeSteps]. 0 with no level.
  double _omenHorde() {
    final k = omenK(OmenKind.horde);
    if (k <= 0) return 0;
    if (_hordeTick != _ticks) {
      _hordeTick = _ticks;
      _hordeN = enemies.where((o) => o.alive && o.entered).length;
    }
    return k * min(omenHordeSteps, _hordeN ~/ omenHordePer);
  }

  /// Rust (the four worn-relic sites: fang's heal and thorns' hit back in [Game._hurt], guard's cut there, fury's beat in
  /// [FxEngine._attackK]): the share of what troop [u]'s small relic does that still works, 1 − its share; 1 on a monster
  /// or while [omensOn] is off.
  double _omenRust(Unit u) => omensOn && u.side == Side.troop ? 1 - omenK(OmenKind.rust) : 1;

  /// Executioner ([Game._hurt], a monster's blow on troop [u], read before the blow): whether [u] is under its share of
  /// its max HP (compared against the share less 1e-9), so the blow meets none of [u]'s shields, blocks and cuts: its
  /// worn guard's cut, a skill's guard, its `struck` cut Fx ([FxEngine._fxStruck]), a duel's cut, a block, an absorb,
  /// Mana Shield, a cap over 0 ([HeroSkills._afterDefence]), its `capped` Fx and its ward. Its defence, a mark, a cap-0
  /// window (the Grail's save) and the `struck` Fx's other rows still act. False with no level.
  bool _omenBare(Unit u) {
    final k = omenK(OmenKind.executioner);
    return k > 0 && u.hp < u.maxHp * (k - 1e-9);
  }

  /// Unbowed: how many holds, stuns or hexes each monster that comes on shrugs off ([Unit.shrugs]), by its level L
  /// ([OmenKind.byL]: 1, 1, 2, 2; a count, so not E); 0 at no level or while [omensOn] is off.
  int get omenUnbowed => omensOn ? omenShown(OmenKind.unbowed, omenLevel(OmenKind.unbowed), 0).n.toInt() : 0;

  /// Unbowed ([HeroSkills.addEffect]'s pin a troop puts on, [HeroMoves._stunFor], Slime Hex's cast): whether monster [u]
  /// shrugs off the hold, stun or hex about to land on it. One of its charges ([Unit.shrugs]) goes, the effect is skipped
  /// (a wind-up it has goes on: the stun that would break it never lands), and Hold Fast's steel shield flashes on it
  /// ([RingLook.brace]). A landed hex refills nothing: the charges come only as it comes on ([_omenSpawn]). False with
  /// none left, on a troop, or while [omensOn] is off.
  bool _omenShrug(Unit u) {
    if (!omensOn || u.shrugs <= 0 || u.side != Side.enemy) return false;
    u.shrugs--;
    rings.add(Ring.over(u, radius: 12, since: t, look: RingLook.brace, duration: skillLook.brace));
    return true;
  }

  /// Counterspell (beside [FxEngine._fxCast] at the three cast sites: a troop's #10 skill, its awakening skill, a
  /// Hero's): each living high elite within [omenCounterspellReach] of [caster] that hasn't had one for
  /// [omenCounterspellEvery] s ([Unit.counterAt]) gets an omen absorb of its share of its max HP for
  /// [omenCounterspellTime] s. One absorb at a time ([HeroSkills.addEffect]): a bigger one it has stays, and Unholy
  /// Ward's bigger ward still lands on it ([BossSkills._wardable]). Nothing with no level.
  void _omenCounterspell(Unit caster) {
    final k = omenK(OmenKind.counterspell);
    if (k <= 0) return;
    for (final o in _foesNear(caster.pos, omenCounterspellReach)) {
      if (o.tier != Tier.highElite || t - o.counterAt < omenCounterspellEvery) continue;
      o.counterAt = t;
      addEffect(o, Status.absorb, omenCounterspellTime.toDouble(), k: o.maxHp * k, omen: true);
    }
  }

  /// A troop's skill was cast (the three cast sites beside [FxEngine._fxCast]: its #10 skill, its awakening skill, a
  /// Hero's), only while [omensOn] is on: Counterspell's shields ([_omenCounterspell]) and Backlash's mights
  /// ([_omenBacklash]) on the monsters near [caster].
  void _omenCast(Unit caster) {
    _omenCounterspell(caster);
    _omenBacklash(caster);
  }

  /// Backlash ([_omenCast]): each living monster within [omenBacklashTiles] tiles of [caster] that hasn't had one for
  /// [omenBacklashEvery] s ([Unit.backlashAt]) gets an omen might of 1 + its share for [omenBacklashTime] s, the boss and
  /// a mini boss too. One might at a time ([HeroSkills.addEffect]): a stronger one it has stays. Nothing with no level.
  void _omenBacklash(Unit caster) {
    final k = omenK(OmenKind.backlash);
    if (k <= 0) return;
    for (final o in _foesNear(caster.pos, omenBacklashTiles * tile)) {
      if (t - o.backlashAt < omenBacklashEvery) continue;
      o.backlashAt = t;
      addEffect(o, Status.might, omenBacklashTime.toDouble(), k: 1 + k, omen: true);
    }
  }

  /// Renewal (after a troop's strip took a good effect or a guard off monster [u]: Spellbreaker's arrow and Null Stone's,
  /// [AwakenSkills._strip]; Spell Cutter's, [FxEngine._fxStrip]): the first time in its life ([Unit.renewed]) [u] gets a
  /// shield of its share of its max HP on the Barrier's soak ([Unit.shield], which a blow breaks before its HP and no
  /// strip takes; gone at the wave's end). Nothing while [omensOn] is off or with no level.
  void _omenRenewal(Unit u) {
    if (!omensOn || u.renewed || u.side != Side.enemy || !u.alive) return;
    final k = omenK(OmenKind.renewal);
    if (k <= 0) return;
    u
      ..renewed = true
      ..shield += u.maxHp * k;
  }

  /// Deathless ([Game._hurt], right after a blow took monster [u] from [before] HP to none, before the Pusaka's counters
  /// and the attacker's answers): a silver or gold monster (by rank, a raised one too) not saved yet ([Unit.omenSaved]) is
  /// left at 1 HP (or what it had, under 1) and takes no blow for its share in s: an omen cap at 0 ([Status.cap], as the
  /// Grail's save; no strip takes it), the holy flash on it. Whether it was saved: [Game._hurt] then counts what the
  /// blow took as [before] − its HP, and nothing of a death follows (no gold, drop or `loot` die). False with no level.
  bool _omenDeathless(Unit u, double before) {
    if (u.omenSaved || (u.tier != Tier.elite && u.tier != Tier.highElite)) return false;
    final k = omenK(OmenKind.deathless);
    if (k <= 0) return false;
    u
      ..omenSaved = true
      ..hp = min(1.0, before);
    addEffect(u, Status.cap, k, k: 0, omen: true);
    impacts.add((u.pos, 'holy'));
    return true;
  }

  /// Side Swing ([Game._hurt], melee monster [by]'s normal attack of [blow] (before the troop's defence) landed on troop
  /// [u]): the nearest other living troop on the field within [omenSideSwingReach] of [u] takes its share of [blow], from
  /// no one ([Hit.extra]: nothing answers it, and it never swings on), through its own defence, cuts and ward; [by]'s hit
  /// burst on it. Nothing with no troop near or no level.
  void _omenSideSwing(Unit u, Unit by, double blow) {
    final k = omenK(OmenKind.sideSwing);
    if (k <= 0) return;
    Unit? next;
    var near = double.infinity;
    for (final o in troops) {
      if (o == u || !o.alive || !o.entered) continue;
      final d = o.pos.distanceTo(u.pos);
      if (d <= omenSideSwingReach && d < near) (next, near) = (o, d);
    }
    if (next == null) return;
    impacts.add((next.pos, 'hit_${enemyTypes.containsKey(by.type) ? by.type : boss}')); // the necro healer has none of its own
    _hurt(next, blow * k, Hit.extra);
  }

  /// Mana Burn ([Game._hurt], a monster's normal or skill blow landed on troop [u], outside the effects, so a troop with
  /// none loses it too): [u] loses its share of its max MP, never below 0, at most once every [omenManaBurnEvery] s
  /// ([Unit.burnAt]). An instant loss, as Soul Rend's; nothing for a troop with no MP or with no level.
  void _omenManaBurn(Unit u) {
    if (u.stats.mp <= 0 || t - u.burnAt < omenManaBurnEvery) return;
    final k = omenK(OmenKind.manaBurn);
    if (k <= 0) return;
    u
      ..burnAt = t
      ..mp = max(0.0, u.mp - k * u.stats.mp);
  }

  /// Vultures ([Meet._monsterFoe], monster [u] not taunted, [near] the troop it would go for today): while its rank is
  /// one its level names ([omenVulturesRanks]), the troop with the lowest HP share among the living troops it reaches (a
  /// tie: the nearest; one that shoots, only those within [omenVulturesNear] of its current target). It keeps that one
  /// ([Unit.vultureFoe]) until it falls or leaves its reach, or until [u]'s next attack ([Unit.blows], counted by
  /// [_omenPummel]: [Unit.vultureBlows] is the count it was picked at), so a heal on it never makes it switch at once.
  /// Null (as today) for another rank, with no troop in its reach, or with no level. No die.
  Unit? _omenVultures(Unit u, Unit near) {
    final level = omenLevel(OmenKind.vultures);
    if (level <= 0 || !omenVulturesRanks[min(level, omenVulturesRanks.length) - 1].contains(u.tier)) return null;
    final held = u.vultureFoe, keep = held != null && held.alive && reaches(u, held);
    if (keep && u.vultureBlows == u.blows) return held;
    if (!reaches(u, near)) {
      u.vultureFoe = null; // the nearest out of its reach: none is in it
      return null;
    }
    final centre = keep ? held : near;
    Unit? best;
    var share = double.infinity, dist = double.infinity;
    for (final o in troops) {
      if (!o.alive || !reaches(u, o)) continue;
      if (u.stats.shotSpeed > 0 && o.pos.distanceTo(centre.pos) > omenVulturesNear) continue;
      final s = o.hp / o.maxHp, d = o.pos.distanceTo(u.pos);
      if (s < share - 1e-9 || (s <= share + 1e-9 && d < dist)) (best, share, dist) = (o, s, d);
    }
    u
      ..vultureFoe = best
      ..vultureBlows = u.blows;
    return best ?? near;
  }

  /// Zeal ([Heal._healMonster], a monster healer's heal or Mass Mend gave monster [u] HP): an omen might of 1 + its
  /// share for [omenZealTime] s. One might at a time ([HeroSkills.addEffect]): a stronger one it has stays.
  void _omenZeal(Unit u) {
    final k = omenK(OmenKind.zeal);
    if (k > 0) addEffect(u, Status.might, omenZealTime.toDouble(), k: 1 + k, omen: true);
  }

  /// [Game._hurt], a blow left monster [u] alive, only while [omensOn] is on: the kinds that answer its HP going under a
  /// line for the first time ([FxEngine.belowOnce], a bit each). A boss or mini boss (by rank, a raised one too): Muster's
  /// call ([_omenMuster]) and Last Gasp's heal ([_omenLastGasp]). Any other: Second Skin's omen absorb of its share of
  /// its max HP for [omenSecondSkinTime] s at [omenSecondSkinAt]% (one absorb at a time: a bigger one it has stays), and
  /// Last Rage's omen might of 1 + its share for [omenLastRageTime] s at [omenLastRageAt]% (the stronger might stays). A
  /// kind's bit is spent only with a level.
  void _omenBelow(Unit u) {
    if (u.tier == Tier.boss || u.tier == Tier.miniBoss) {
      _omenMuster(u);
      _omenLastGasp(u);
      return;
    }
    final skin = omenK(OmenKind.secondSkin);
    if (skin > 0 && belowOnce(u, omenSecondSkinAt / 100, omenSecondSkinBit)) {
      addEffect(u, Status.absorb, omenSecondSkinTime.toDouble(), k: u.maxHp * skin, omen: true);
    }
    final rage = omenK(OmenKind.lastRage);
    if (rage > 0 && belowOnce(u, omenLastRageAt / 100, omenLastRageBit)) {
      addEffect(u, Status.might, omenLastRageTime.toDouble(), k: 1 + rage, omen: true);
    }
  }

  /// Muster ([_omenBelow], a blow left monster [u] alive): a boss or mini boss (by rank, a raised one too) at or under
  /// [omenMusterAt]% of its HP for the first time ([FxEngine.belowOnce], its bit [omenMusterBit]) gives every other
  /// living monster within [omenMusterReach] of it an omen might of 1 + its share for [omenMusterTime] s, once. A blow
  /// that kills it gives none. Nothing with no level (the bit stays unused).
  void _omenMuster(Unit u) {
    if (u.tier != Tier.boss && u.tier != Tier.miniBoss) return;
    final k = omenK(OmenKind.muster);
    if (k <= 0 || !belowOnce(u, omenMusterAt / 100, omenMusterBit)) return;
    for (final o in _foesNear(u.pos, omenMusterReach)) {
      if (o != u) addEffect(o, Status.might, omenMusterTime.toDouble(), k: 1 + k, omen: true);
    }
  }

  /// Bile Sacs ([Game._hurt], monster [dead] just died): a slime hurts each living troop within [omenBileReach] of it for
  /// its share of the troop's max HP, from no one (nothing answers it), through the troop's defence and cuts
  /// ([Hit.extra]), a troop at most once every [omenBileEvery] s ([Unit.bileAt]); the slime's own hit burst shows on
  /// each. Nothing with no level.
  void _omenBile(Unit dead) {
    if (dead.type != 'slime') return;
    final k = omenK(OmenKind.bileSacs);
    if (k <= 0) return;
    for (final o in _alliesNear(dead.pos, omenBileReach)) {
      if (t - o.bileAt < omenBileEvery) continue;
      o.bileAt = t;
      impacts.add((o.pos, 'hit_slime'));
      _hurt(o, o.maxHp * k, Hit.extra);
    }
  }

  /// Parting Gift ([Game._hurt], monster [dead] just died): each living monster below a mini boss (by rank) within
  /// [omenPartingGiftReach] of it that lacks HP heals its share of its own max HP through the monster funnel
  /// ([MonsterHeal.partingGift], none under noHeal), a monster at most once every [omenPartingGiftEvery] s
  /// ([Unit.giftAt]). Nothing with no level.
  void _omenPartingGift(Unit dead) {
    final k = omenK(OmenKind.partingGift);
    if (k <= 0) return;
    for (final o in _foesNear(dead.pos, omenPartingGiftReach)) {
      if (o == dead || o.tier == Tier.boss || o.tier == Tier.miniBoss || o.hp >= o.maxHp || t - o.giftAt < omenPartingGiftEvery) continue;
      o.giftAt = t;
      _healMonster(o, o.maxHp * k, MonsterHeal.partingGift);
    }
  }

  /// Captain's aura (in [_omenTaken]): whether a living high elite other than monster [u] stands within
  /// [omenCaptainReach] of it, the same-side count of the high elites (one counts). The high elites on the field are
  /// found at most once a tick ([Game._captains]), each one's place read now.
  bool _captained(Unit u) {
    if (_captainsTick != _ticks) {
      _captainsTick = _ticks;
      _captains
        ..clear()
        ..addAll([for (final o in enemies) if (o.alive && o.entered && o.tier == Tier.highElite) o]);
    }
    for (final o in _captains) {
      if (o != u && o.alive && o.pos.distanceTo(u.pos) <= omenCaptainReach) return true;
    }
    return false;
  }

  /// Close Ranks ([Game._hurt]'s kill path, before the killer's `kill` Fx, so a burst it sets off meets the guard; none
  /// for a kill inside a burst or a leap, [Game._fxDepth]): monster [dead] just died, and each living monster within
  /// [omenCloseRanksReach] of it takes its share less for [omenCloseRanksTime] s: a guard ([Game._guard], the pale
  /// ring; the stronger guard stays, so it never stacks on a skill's) marked [Unit.guardOmen], which the taken floor
  /// counts ([_omenTaken]). Nothing with no level.
  void _omenCloseRanks(Unit dead) {
    final k = omenK(OmenKind.closeRanks);
    if (k <= 0) return;
    for (final o in _foesNear(dead.pos, omenCloseRanksReach)) {
      if (o != dead && _guard(o, k, omenCloseRanksTime)) o.guardOmen = true;
    }
  }

  /// Blindside (in [_omenDealt]): what monster [by]'s blow on troop [u] gains while [u] struck another monster less than
  /// [omenBlindsideBusy] s ago ([Unit.lastFoe], set by [Game._strike]; a healer never strikes): its share; 0 otherwise.
  double _omenBlindside(Unit u, Unit by) {
    final last = u.lastFoe;
    return last == null || last.foe == by || t - last.at >= omenBlindsideBusy ? 0 : omenK(OmenKind.blindside);
  }

  /// Triumph ([Game._hurt], troop [fell] just fell, to anyone or no one): each living monster below a mini boss (by rank)
  /// within [omenTriumphReach] of it gets an omen haste of 1 / (1 + its share) for [omenTriumphTime] s. One haste at a
  /// time ([HeroSkills.addEffect]): a stronger one it has (Frenzy's, Rally's, Howl's, Second Wind's) stays; the floors
  /// of [Game.attackEvery] hold; the field rings an omen haste mint (skills.dart). Nothing with no level.
  void _omenTriumph(Unit fell) {
    final k = omenK(OmenKind.triumph);
    if (k <= 0) return;
    for (final o in _foesNear(fell.pos, omenTriumphReach)) {
      if (o.tier != Tier.boss && o.tier != Tier.miniBoss) addEffect(o, Status.haste, omenTriumphTime.toDouble(), k: 1 / (1 + k), omen: true);
    }
  }

  /// Toll ([Game._hurt]'s kill path, after the killer's `kill` Fx and [BossSkills._monsterFell]): troop [by] killed a
  /// monster and loses its share of its max HP, at most what keeps it over [omenTollAbove]% of it, as a blow from no
  /// one ([Hit.hitBack]: nothing answers it, no Pusaka's Fx runs on it) through its defence, its cuts and its ward; the
  /// necromancer's skull bursts on it. At most once every [omenTollEvery] s a troop ([Unit.tollAt]); a troop at or under
  /// the line pays nothing (its clock unspent). Nothing for a fallen troop or with no level.
  void _omenToll(Unit by) {
    final k = omenK(OmenKind.toll), line = by.maxHp * omenTollAbove / 100;
    if (k <= 0 || !by.alive || by.hp <= line || t - by.tollAt < omenTollEvery) return;
    by.tollAt = t;
    impacts.add((by.pos, 'hit_necromancer'));
    _hurt(by, min(k * by.maxHp, by.hp - line), Hit.hitBack);
  }

  /// [Game.tick], after the effects, only while [omensOn] is on: Trickle's heals pay what is due ([_omenTrickle]), and
  /// every [omenHealSiphonEvery] s Heal Siphon's debts are paid ([_omenSiphon]).
  void _omenHeals() {
    if (!omensOn) return;
    for (final u in troops) {
      if (u.trickle.isNotEmpty) _omenTrickle(u);
    }
    if (t - _siphonAt < omenHealSiphonEvery) return;
    _siphonAt = t;
    _omenSiphon();
  }

  /// Trickle ([_omenHeals]): each heal spread on troop [u] ([TrickleHeal]) pays its rate for the time since it last paid,
  /// up to its own end, so the HP bar fills over the heal's time; one at its end is done. What lands stops at Scar's
  /// ceiling ([healCeil]), never lowering [u]'s HP, and never goes past its max HP. A fallen troop loses the rest.
  void _omenTrickle(Unit u) {
    if (!u.alive) {
      u.trickle.clear();
      return;
    }
    var pay = 0.0;
    for (final e in u.trickle) {
      final to = min(t, e.end);
      pay += e.rate * (to - e.paidTo);
      e.paidTo = to;
    }
    u.trickle.removeWhere((e) => e.paidTo >= e.end);
    if (pay > 0) u.hp = max(u.hp, min(healCeil(u), u.hp + pay));
  }

  /// HP troop [u] has still to come from Trickle's spread heals ([Unit.trickle]): what a new heal's past full counts
  /// against beside its HP ([Heal._healTroop]). 0 with none.
  double trickleLeft(Unit u) {
    var left = 0.0;
    for (final e in u.trickle) {
      left += e.rate * (e.end - e.paidTo);
    }
    return left;
  }

  /// Heal Siphon ([_omenHeals], once every [omenHealSiphonEvery] s): each troop's debt ([Unit.siphonDue]) goes to the
  /// nearest living monster below a mini boss within [omenHealSiphonReach] of it through the monster funnel
  /// ([MonsterHeal.siphon], none under noHeal), the heal's sparkle on it when it gained HP. A fallen troop's debt, and one
  /// with no such monster in reach, is dropped.
  void _omenSiphon() {
    for (final u in troops) {
      if (u.siphonDue <= 0) continue;
      final due = u.siphonDue;
      u.siphonDue = 0;
      if (!u.alive) continue;
      for (final o in _foesNear(u.pos, omenHealSiphonReach)) {
        if (o.tier == Tier.boss || o.tier == Tier.miniBoss) continue;
        if (_healMonster(o, due, MonsterHeal.siphon) > 0) impacts.add((o.pos, 'heal'));
        break;
      }
    }
  }

  /// Defiant (in [_omenDealt]): what monster [by]'s blow on troop [u] gains while [u]'s taunt holds [by] (a Hero's Duel
  /// or Holy Taunt, a taunt Fx; a monster's taunt is on the troop, never read): its share, the boss's and the mini
  /// boss's × [omenDefiantBoss]. 0 otherwise.
  double _omenDefiant(Unit u, Unit by) {
    if (by.effects.isEmpty || effectOn(by, Status.taunt)?.by != u) return 0;
    final k = omenK(OmenKind.defiant);
    return by.tier == Tier.boss || by.tier == Tier.miniBoss ? k * omenDefiantBoss : k;
  }

  /// Straggler (in [_omenDealt]): what monster [by]'s blow gains while no other monster stands within
  /// [omenStragglerTiles] tiles of it ([FxEngine.alliesNearOf], counted once a tick): its share; 0 with one near, on the
  /// boss or a mini boss (by rank, a raised one too), or with no level.
  double _omenStraggler(Unit by) {
    if (by.tier == Tier.boss || by.tier == Tier.miniBoss) return 0;
    final k = omenK(OmenKind.straggler);
    return k > 0 && alliesNearOf(by, omenStragglerTiles * tile) == 0 ? k : 0;
  }

  /// Feed ([Game._hurt], monster [by]'s blow took [dealt] off a troop): [by] heals its share of [dealt] through the
  /// monster funnel ([MonsterHeal.feed], none under noHeal); not the boss or a mini boss, as Mend's.
  void _omenFeed(Unit by, double dealt) {
    if (dealt <= 0 || _isSlot(by.tier, raised: by.raisedBy != null)) return;
    final k = omenK(OmenKind.feed);
    if (k > 0) _healMonster(by, dealt * k, MonsterHeal.feed);
  }

  /// Pummel ([Game._strike], monster [u]'s normal attack, only while [omensOn] is on): counts it on [Unit.blows], and
  /// whether it is a pummel, every [omenPummelEvery]th with a level, never the boss's or a mini boss's (by rank, a raised
  /// one too). [Game._pummeled] carries it to the blow's dealt cap ([_omenDealt]), a shot's [Shot.pummel] to its
  /// landing. A skill's blow is no attack: it never counts.
  bool _omenPummel(Unit u) =>
      ++u.blows % omenPummelEvery == 0 && u.tier != Tier.boss && u.tier != Tier.miniBoss && omenK(OmenKind.pummel) > 0;

  /// Sap ([Game._strike], monster [u]'s normal attack just counted by [_omenPummel]): whether it saps, every
  /// [omenSapEvery]th on that same count with a level (the boss's and a mini boss's too). [Game._sapped] carries it to
  /// the blow ([_omenSap]), a shot's [Shot.sap] to its landing. A skill's blow is no attack: it never counts.
  bool _omenSapBlow(Unit u) => u.blows % omenSapEvery == 0 && omenK(OmenKind.sap) > 0;

  /// Sap ([Game._hurt], monster [by]'s sapping normal attack landed on troop [u], not blocked): [u] deals × 1 − its share
  /// for [omenSapTime] s, at most [omenDebuffMax]: a weaken a monster put on it ([Effect.bad], so a troop's cleanse ends
  /// it: Salt Charm, Pure Water). One weaken at a time ([HeroSkills.addEffect]): a stronger one it has stays.
  void _omenSap(Unit u, Unit? by) => addEffect(u, Status.weaken, min(omenSapTime, omenDebuffMax).toDouble(),
      k: 1 - omenK(OmenKind.sap), by: by, bad: true, omen: true);

  /// Bat Venom ([Game._hurt], bat [by]'s normal attack landed on troop [u], not blocked, [u] alive): [u] loses its share
  /// of its max HP a second for [omenBatVenomTime] s, at most [omenDebuffMax]: a bleed a monster put on it ([Effect.bad],
  /// so a troop's cleanse ends it: Saint's Tear), a tick a second from no one ([Effect.omen]: nothing answers it, no
  /// Pusaka's Fx runs on it, no dealt kind raises it) through its defence and cuts, the bat's own hit burst on it. A bite
  /// on a troop the venom already holds runs it [omenBatVenomTime] s from now, its next tick kept (a bat bites more often
  /// than once a second); a stronger bleed it has (Pounce's, Barbed Arrow's) stays ([HeroSkills.addEffect]). Nothing with
  /// no level.
  void _omenVenom(Unit u, Unit by) {
    final k = omenK(OmenKind.batVenom);
    if (k <= 0) return;
    final ticks = min(omenBatVenomTime, omenDebuffMax), tick = u.maxHp * k;
    if (u.effects[Status.bleed] case final e? when e.omen && t < e.until && (e.k - tick).abs() < 1e-9) {
      e
        ..until = t + ticks + 0.5
        ..n = ticks;
      return;
    }
    addEffect(u, Status.bleed, ticks + 0.5, k: tick, by: by, n: ticks, bad: true, omen: true);
  }

  /// Blight ([Game._hurt], the boss's or a mini boss's (by rank) normal or skill blow landed on troop [u], not blocked,
  /// [u] alive): no heal lands on [u] in a wave for its time, at most [omenDebuffMax] s: a [Status.noHeal] a monster put
  /// on it ([Effect.bad], so a troop's cleanse ends it: Salt Charm, Saint's Tear), its heal ceiling its HP while it lasts
  /// ([healCeil], [blighted]). A new blow runs it from now. Nothing with no level.
  void _omenBlight(Unit u, Unit by) {
    final time = min(omenK(OmenKind.blight), omenDebuffMax.toDouble());
    if (time > 0) addEffect(u, Status.noHeal, time, by: by, bad: true, omen: true);
  }

  /// Whether troop [u] is under the Bayangan Blight now ([Status.noHeal] on a troop, [_omenBlight]): no heal lands on it
  /// in a wave ([Heal._healTroop], [healCeil]), and its body shows it olive (main.dart).
  bool blighted(Unit u) => u.side == Side.troop && u.effects.isNotEmpty && under(u, Status.noHeal);

  /// Gloat ([Game._hurt], a troop fell to [by]): [by], a living monster below a mini boss (by rank, a raised one too),
  /// heals its share of its max HP through the monster funnel ([MonsterHeal.gloat], none under noHeal).
  void _omenGloat(Unit by) {
    if (by.side != Side.enemy || !by.alive || by.tier == Tier.boss || by.tier == Tier.miniBoss) return;
    final k = omenK(OmenKind.gloat);
    if (k > 0) _healMonster(by, by.maxHp * k, MonsterHeal.gloat);
  }

  /// Rekindle ([MonsterSkills._castMonsterSkill], high elite [u]'s skill lands, its wind-up over): it heals its share of
  /// its max HP through the monster funnel ([MonsterHeal.rekindle], none under noHeal). A wind-up broken off never gets
  /// here, nor the boss's and the mini boss's skills ([BossSkills._castBossSkill]).
  void _omenRekindle(Unit u) {
    final k = omenK(OmenKind.rekindle);
    if (k > 0) _healMonster(u, u.maxHp * k, MonsterHeal.rekindle);
  }

  /// Grudge's tally ([Game._hurt], a monster fell to troop [by], only while [omensOn] is on): one kill for [by]'s type in
  /// the wave being fought ([Game._waveKills]).
  void _omenKill(Unit by) => _waveKills[by.type] = (_waveKills[by.type] ?? 0) + 1;

  /// A won wave's end ([Game.tick]): Grudge's target for the next wave ([Game.grudgeType]), this wave's top killer: the
  /// troop type whose troops killed the most monsters in it, a tie to the first in [troopTypes]' order; none (null) when
  /// no troop killed one. It holds until the next won wave's end. Nothing while [omensOn] is off.
  void _omenTopKiller() {
    if (!omensOn) return;
    String? top;
    for (final type in troopTypes.keys) {
      final n = _waveKills[type] ?? 0;
      if (n > 0 && (top == null || n > _waveKills[top]!)) top = type;
    }
    grudgeType = top;
  }

  /// Avenge ([Game._hurt], monster [dead] just died): each living monster within [omenAvengeReach] of it gets an omen
  /// might of 1 + its share for [omenAvengeTime] s. One might at a time ([HeroSkills.addEffect]): a stronger one it has
  /// (a War Shout's) stays.
  void _omenAvenge(Unit dead) {
    final k = omenK(OmenKind.avenge);
    if (k <= 0) return;
    for (final o in _foesNear(dead.pos, omenAvengeReach)) {
      if (o != dead) addEffect(o, Status.might, omenAvengeTime.toDouble(), k: 1 + k, omen: true);
    }
  }

  /// Shieldbreak ([Heal._wardSoak]; [HeroSkills._afterDefence]'s absorb and Mana Shield): a blow of [dmg] on troop [u]
  /// from [by] meets a shield holding [pool]: what the shield loses and what of the blow is left for the next. A
  /// monster's blow does × 1 + its share to the shield, and what is left of it past the shield lands as it was; any
  /// other blow, a monster's shield, or while [omensOn] is off: one for one.
  (double lost, double left) _omenSoak(Unit u, Unit? by, double dmg, double pool) {
    final m = omensOn && u.side == Side.troop && by?.side == Side.enemy ? 1 + omenK(OmenKind.shieldbreak) : 1.0;
    if (m == 1) {
      final soak = min(dmg, pool);
      return (soak, dmg - soak);
    }
    final hit = dmg * m, lost = min(hit, pool);
    return (lost, (hit - lost) / m);
  }

  /// Fade ([Game.tick], after the effects): each living troop's ward and absorb shrink by its share of what is left a
  /// second, a stunned or busy troop's too; Mana Shield's MP never. Nothing while [omensOn] is off or with no level.
  void _omenFade(double dt) {
    if (!omensOn) return;
    final k = omenK(OmenKind.fade);
    if (k <= 0) return;
    final keep = max(0.0, 1 - k * dt);
    for (final u in troops) {
      if (!u.alive) continue;
      if (u.ward > 0) u.ward *= keep;
      if (u.effects.isNotEmpty && effectOn(u, Status.absorb) != null) u.effects[Status.absorb]!.k *= keep;
    }
  }

  /// Drag ([FxEngine._fxGate]): how much longer Pusaka [relic]'s Fx on its own cooldown waits before its next, a Rare
  /// or Epic one's × 1 + its share; 1 for a Legendary one's, with no level, or while [omensOn] is off.
  double omenDrag(Relic relic) => omensOn && relic.rarity != Rarity.legenda ? 1 + omenK(OmenKind.drag) : 1;

  /// Scar: the HP a troop heal in a wave stops at on troop [u] ([Heal._healTroop]), its max HP × (1 − its share); every
  /// troop-heal target check reads it too (a priest's heal and Healing Prayer, Unbroken, Mourning Bell), so a healer
  /// passes over a troop at its ceiling. Under Blight ([blighted]) its HP now: no healer picks it and a Trickle payment
  /// gives it nothing ([_omenTrickle]). Its max HP between waves, with no level, or while [omensOn] is off.
  double healCeil(Unit u) {
    if (waveActive && blighted(u)) return u.hp; // Blight: nothing more while it lasts
    final k = omenK(OmenKind.scar);
    return k > 0 && waveActive ? u.maxHp * (1 - k) : u.maxHp.toDouble();
  }

  /// Spell Tax: the MP troop [u] pays for a skill of [base] MP (its #10 skill, its awakening skill, a Hero's: what it
  /// pays, what it saves for, Cleave's refund of it, what Gift of Mana tops it up to): × 1 + its share, never past its
  /// max MP (unless [base] already is). [base] itself while [omensOn] is off or with no level.
  double skillCost(Unit u, num base) {
    final k = omenK(OmenKind.spellTax);
    return k > 0 ? min(max(u.stats.mp.toDouble(), base.toDouble()), base * (1 + k)) : base.toDouble();
  }

  /// Spell Tax on the book's tooltips ([Game.mpInfo], [awakenLines]): the price troop [type]'s skill of [base] MP shows,
  /// as [skillCost] at the shown factor ([omenShownK]): in a wave what its troops pay, between waves what they will.
  double skillPrice(String type, num base) {
    final k = omenShownK(OmenKind.spellTax);
    return k > 0 ? min(max(fieldStats(type).mp.toDouble(), base.toDouble()), base * (1 + k)) : base.toDouble();
  }

  /// Off Beat: how many more hits a Rare or Epic Artifact's every-few-hits Fx waits ([FxEngine._everyOf]), by its level L
  /// ([OmenKind.byL]: 1, 1, 2, 2; a count, so not E); 0 at no level or while [omensOn] is off.
  int get omenOffBeat => omensOn ? omenShown(OmenKind.offBeat, omenLevel(OmenKind.offBeat), 0).n.toInt() : 0;

  /// Lingering (the duration scaler [FxEngine._effectTime]): how long a buff a monster gives monster [u] lasts, a kind
  /// Spellbreaker strips ([spellbreakerStrips]) not given by a troop: × 1 + its share. A Shadow's own ([omen]: Avenge's,
  /// Eager's) keeps its time. 1 for anything else, on a troop, or while [omensOn] is off.
  double _omenLinger(Unit u, Status s, Unit? by, {bool omen = false}) =>
      omensOn && !omen && u.side == Side.enemy && by?.side != Side.troop && spellbreakerStrips.contains(s)
          ? 1 + omenK(OmenKind.lingering)
          : 1;

  /// Sunder ([Game._hurt], [FxEngine._fxStruck]): the share of a cut on troop [u] (the small relic Guard's, a skill's
  /// guard, a Pusaka's `cut` Fx) that still cuts, 1 − its share; 1 on a monster or while [omensOn] is off.
  double _omenSunder(Unit u) => omensOn && u.side == Side.troop ? 1 - omenK(OmenKind.sunder) : 1;

  /// Mark Ward (the duration scaler [FxEngine._effectTime]): how long a mark on monster [u] lasts, Hunter's Mark's
  /// [Status.vulnerable] or Void Eye's [Status.voidMark], × 1 − its share (Ember Brand's one-hit mark, [Unit.emberMark],
  /// asks with [s] null: [FxEngine._fxMark]). 1 for anything else, on a troop, or while [omensOn] is off.
  double _omenMarkWard(Unit u, [Status? s]) => omensOn &&
          u.side == Side.enemy &&
          (s == null || s == Status.vulnerable || s == Status.voidMark || s == Status.pusakaMark)
      ? 1 - omenK(OmenKind.markWard)
      : 1;

  /// Unshaken (the duration scaler [FxEngine._effectTime], [HeroMoves._stunFor], Slime Hex): how long what a troop puts
  /// on monster [u] lasts, × 1 − its share for a slow, a hold ([Status.impaled]), a taunt, a weaken, a hex or a stun
  /// ([s] null); 1 for anything else, on a troop, or while [omensOn] is off.
  double _omenUnshaken(Unit u, Status? s) => omensOn &&
          u.side == Side.enemy &&
          (s == null || const {Status.slow, Status.impaled, Status.taunt, Status.weaken, Status.hex}.contains(s))
      ? 1 - omenK(OmenKind.unshaken)
      : 1;

  /// Quick Spells ([MonsterSkills._firstCast], [MonsterSkills._skillReady]): monster [u]'s cooldown for skill [s], a
  /// high elite's × 1 − its share. Both read it, so its first cast comes when it would, and every later one sooner.
  double _skillCooldown(Unit u, MonsterSkill s) =>
      omensOn && u.tier == Tier.highElite ? s.cooldown * (1 - omenK(OmenKind.quickSpells)) : s.cooldown;

  /// Thrift ([Game._hurt]'s kill gold, [HeroSkills._plunder]'s extra): the gold a monster of [cost] pays, × 1 − its
  /// share, rounded; [cost] itself while [omensOn] is off.
  int _omenGold(int cost) => omensOn ? (cost * (1 - omenK(OmenKind.thrift))).round() : cost;

  /// Deflect: the nth normal troop attack each monster cancels, by its level L ([OmenKind.byL]: 12, 8, 6, 5); 0 (none)
  /// at no level or while [omensOn] is off.
  int get omenDeflectEvery => omensOn ? omenShown(OmenKind.deflect, omenLevel(OmenKind.deflect), 0).n.toInt() : 0;

  /// Deflect ([Game._hurt], right after the heap check): a troop's normal attack ([Hit.normal]) on monster [u] counts
  /// one on [Unit.fxN] (monsters use it for nothing else), and every [omenDeflectEvery]th is cancelled: true, with the
  /// monster's own hit burst and [Game._deflected] raised, so [Game._strike] and a shot's landing run no `landed` Fx
  /// for it. Skills, extra hits, bleeds and hit-backs never count.
  bool _omenDeflect(Unit u) {
    final n = omenDeflectEvery;
    if (n <= 0 || ++u.fxN % n != 0) return false;
    _deflected = true;
    impacts.add((u.pos, 'hit_${enemyTypes.containsKey(u.type) ? u.type : boss}')); // the necro healer has none of its own
    return true;
  }

  /// Thorns ([Game._hurt]): melee troop [by] dealt [dmg] to a monster and takes [OmenKind.thorns]'s share of it back, at
  /// most [omenThornsCap] of its max HP, from no one (nothing answers it, so it never bounces), through its own defence.
  void _omenThorns(Unit by, double dmg) {
    final k = omenK(OmenKind.thorns);
    if (k > 0) _hurt(by, min(dmg * k, by.maxHp * omenThornsCap), Hit.hitBack);
  }

  /// A blow of [dmg] on monster [u] after every cut ([Game._hurt]): its Shield ([Unit.shield]) takes what it can first.
  /// What is left for its HP.
  double _shieldSoak(Unit u, double dmg) {
    final soak = min(dmg, u.shield);
    u.shield -= soak;
    return dmg - soak;
  }

  /// [Game.startWave], once the wave's queue is made. Guard: each boss and mini boss brings [omenGuards] high elites of
  /// the pool's strongest type ([poolOf]'s last) right behind its escort (#90, so the escort's link holds), as queue
  /// entries like any (tided, counted in [Game.waveTotal], casting, paying gold, dropping loot). They are marked by
  /// their place in the wave ([Game._guardsAt]): one comes on its slot's row with no row drawn ([Game.tick]), and no die
  /// is drawn here, so [Game.rng] and [Game.slots] stay paired with the wave without them. Then Lewati's skip buff
  /// counts its monsters ([Game.skipBuffN]): the first [skipBuffShare] of the whole queue, guards included; and while
  /// [omensOn] is on, Dusk finds where the crowd ends ([_omenCrowd]).
  void _omenQueue() {
    _guardsAt.clear();
    final g = omenGuards, escort = wave >= escortFrom ? escortHealers + escortSummoners : 0, type = poolOf(wave).last;
    for (var i = queue.length - 1; g > 0 && i >= 0; i--) {
      if (_isSlot(queue[i].$2)) queue.insertAll(i + 1 + escort, [for (var k = 0; k < g; k++) (type, Tier.highElite)]);
    }
    for (var i = 0; g > 0 && i < queue.length; i++) {
      if (_isSlot(queue[i].$2)) _guardsAt.addAll([for (var k = 1; k <= g; k++) i + escort + k]);
    }
    skipBuffN = waveSkipBuff ? (queue.length * skipBuffShare).round() : 0;
    _crowdLast = omensOn ? _omenCrowd(escort) : -1; // Dusk's: where the crowd ends
  }

  /// [Draft._roll]: the faces of [cards], one [Game.omenDice] draw a card, always [draftCards] draws a roll (a Serpihan
  /// and a chest before [omenFrom] draw theirs too, and show none). A face comes from the kinds that can act on the army
  /// as it is now ([omenMet], read once a roll; [omenCanAct]; [omenActFilter]), on the same single draw. Null while
  /// [omensOn] is off: no die drawn.
  List<OmenKind?>? _faces(List<Relic?> cards) {
    if (!omensOn) return null;
    final met = omenActFilter ? omenMet : null, faces = <OmenKind?>[];
    for (final r in cards) {
      final u = omenDice.nextDouble();
      faces.add(r != null && wave >= omenFrom ? omenFace(r, cardType(r), u, met == null ? null : (k) => omenCanAct(k, met)) : null);
    }
    return faces;
  }

  /// Where a take of Pusaka [relic]'s card with face [face] puts its levels ([omenMarks] by its rarity, through
  /// [omenPlace] in its pool's order); empty when every kind is full.
  List<OmenKind> _omenPlan(OmenKind face, Relic relic) => omenPlace(omens, face, omenPool(relic.rarity), omenMarks[relic.rarity]!);

  /// The enemy gets the levels [plan] placed ([omenPlace]), oldest first, and an [OmenGained] for each kind, [from] a
  /// chest's card ('chest', the chest of [chestWave]), the catch-up ('catchUp') or an Ukir star ('ukir').
  void _omenAdd(List<OmenKind> plan, String from, {int? chestWave}) {
    omens.addAll(plan);
    for (final k in {...plan}) {
      _emit(OmenGained(wave, t, omen: k, level: omenLevel(k), gained: plan.where((p) => p == k).length, from: from, chestWave: chestWave));
    }
  }

  /// A Pusaka gained a full star of worth outside the chest (Ukir's star-up): the take path without a face. Its
  /// counter ([omenCounter] on its type) gets [omenMarks] levels by its rarity, overflowing as a take's do. No die
  /// drawn. Nothing before [omenFrom], nor while [omensOn] is off.
  // Ukir's star-up calls it ([Ukir.feedUkir], item-artefact-design §2).
  void _omenStarUp(Relic relic) {
    if (!omensOn || wave < omenFrom || !relic.pusaka) return;
    _omenAdd(_omenPlan(omenCounter(relic, pusaka[relic]?.type), relic), 'ukir');
  }

  /// [Game.startWave], beside Beban's freeze: Grudge's tally and Dusk start afresh ([Game.duskOn]); Lewati's skip buff
  /// owed moves onto this wave ([Game.waveSkipBuff]); the Beban factor ([Game.omenFactor]) and the troops that start it
  /// ([Game.omenTroops]) are frozen for the wave; and from [omenFrom] the catch-up's next [omenCatchUpStep] levels land,
  /// once a wave number: none when a wave lost to a wipe is played again ([Game.lostWave], wipe.dart). Nothing else while
  /// [omensOn] is off.
  void _omenWave() {
    waveSkipBuff = false;
    _waveKills.clear(); // Grudge's tally starts afresh
    duskOn = false; // and Dusk waits for the crowd again
    _crowdInAt = null;
    if (!omensOn) return;
    waveSkipBuff = skipBuffDue;
    skipBuffDue = false;
    omenFactor = _omenFactorNow;
    omenTroops = armySize;
    omenStarters
      ..clear()
      ..addAll(troops.where((u) => u.alive));
    if (wave < omenFrom || lostWave == wave) return;
    final land = omensOwed.take(omenCatchUpStep).toList();
    omensOwed.removeRange(0, land.length);
    for (final k in land) {
      _omenAdd(omenPlace(omens, k, omenOrder, 1), 'catchUp');
    }
  }

  /// The wave's falls as the ease counts them ([how], [omenEaseCount] by default): every fall, the starters' each once
  /// ([Game.omenStarters]), or an awakened type's ([Game.awakenLevel] 1 or more).
  int omenFalls([OmenEaseCount how = omenEaseCount]) => switch (how) {
        OmenEaseCount.falls => fallen.length,
        OmenEaseCount.starters => (Set<Unit>.identity()..addAll(fallen.where(omenStarters.contains))).length,
        OmenEaseCount.awakened => fallen.where((u) => awakenLevel(u.type) > 0).length,
      };

  /// A won wave's end ([Game.tick]): each full [omenEaseShare] of the troops that started it ([Game.omenTroops]) fallen
  /// ([omenFalls]) takes the newest level away, at most [omenEaseMax], each an [OmenEased].
  void _omenEase() {
    if (!omensOn || omenTroops <= 0) return;
    final n = min(omenEaseMax, (omenFalls() / (omenTroops * omenEaseShare) + 1e-9).floor());
    for (var i = 0; i < n && omens.isNotEmpty; i++) {
      final k = omens.removeLast();
      _emit(OmenEased(wave, t, omen: k, level: omenLevel(k)));
    }
  }

  /// [WaveStarted.omens]: each kind held and its level, the frozen factor, the levels still owed and the skip buff;
  /// null while [omensOn] is off (no key in the record).
  Map<String, Object>? get _omenState => omensOn
      ? {
          'levels': {for (final k in OmenKind.values) if (omenLevel(k) > 0) k.name: omenLevel(k)},
          'factor': (omenFactor * 10000).round() / 10000,
          'owed': omensOwed.length,
          'skipBuff': waveSkipBuff,
        }
      : null;

  /// [Game.toJson]'s keys, only while [omensOn] is on: the levels always (an old save is one without them), the
  /// catch-up owed, the skip buff owed and Grudge's target ([Game.grudgeType]) when there are any.
  Map<String, Object> get _omenJson => omensOn
      ? {
          'omens': [for (final k in omens) k.name],
          if (omensOwed.isNotEmpty) 'omensOwed': [for (final k in omensOwed) k.name],
          if (skipBuffDue) 'skipBuffDue': true,
          'grudgeType': ?grudgeType,
        }
      : const {};

  /// [Game.fromJson], after the Pusaka and the chests: the levels, the catch-up owed, the skip buff owed and Grudge's
  /// target, by name (an unknown kind or type skipped). A save without `omens` is from before the Bayangan: with a
  /// Pusaka owned, its catch-up ([omenCatchUp]), which the UI announces once ([Game.omenCaughtUp]). Nothing while
  /// [omensOn] is off.
  void _loadOmens(Map<String, dynamic> j) {
    if (!omensOn) return;
    List<OmenKind> kinds(Object? names) => [
          for (final n in names is List ? names : const []) ?OmenKind.values.asNameMap()[n],
        ];
    if (j['omens'] case final List saved) {
      omens.addAll(kinds(saved));
      omensOwed.addAll(kinds(j['omensOwed']));
      skipBuffDue = j['skipBuffDue'] == true;
      if (j['grudgeType'] case final String type when troopTypes.containsKey(type)) grudgeType = type;
      return;
    }
    omensOwed.addAll(omenCatchUp());
    omenCaughtUp = omensOwed.isNotEmpty;
  }
}

/// A share as a percent for the Shadows' lines: 0.1 → "10", 0.009 → "0.9" (one decimal, none when whole); under 1%
/// two (Wear Down's 0.0015 → "0.15").
String omenPercent(double share) => _omenNum(share * 100, share < 0.01 ? 2 : 1);

/// [v] with at most [digits] decimals, the trailing zeros dropped: 1.5, 1.38, 2.
String _omenNum(double v, int digits) {
  final s = v.toStringAsFixed(digits);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}
