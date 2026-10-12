part of 'game.dart';

// The Pusaka catalog (catalog step 0b, decisions-log 178; docs/loot-items-relics.md "The Pusaka catalog and its
// engine"). The owner, 2026-10-02: "setidaknya perlu ada sekitar 30 untuk tiap tiernya" (about 30 artefacts and 30
// hidden enemy buffs a tier). So a Pusaka is data: one [Art] row in [pusakaCatalog], made of at most two [Fx] (what
// sets it off, an optional condition, what it does, to whom, and its numbers by stars), and the engine
// (pusaka_engine.dart) runs every row the same way. Every number is read from the named `*K` constant the row points
// at (pusaka.dart, draft.dart), through [pusakaAt]. The words a row shows come from one template per (trigger,
// effect) below ([fxLines], [fxGist]), so the item text is checked once per template, not once per Pusaka. The oaths
// (Oath of One, Alliance; batch G-4's six) stay bespoke rules (pusaka.dart): their rows hold no Fx. Nothing here draws a
// die.

/// What sets an [Fx] off (the catalog's 16 triggers, catalog-design §2.2), each at one place in the fight
/// (pusaka_engine.dart).
enum Trig {
  /// Always on: a stat in [Game.statsOf] (Dragon Heart, Dawn Star; Hawk Feather's range, Stone Coat's defence, Moonwell's
  /// MP regen).
  always,

  /// The whole army's (an oath's): bespoke rules (pusaka.dart), no Fx.
  army,

  /// A normal attack (a blow, a shot, a healer's smite), every [Fx.every]th on the attack counter [Unit.blows], which
  /// a worn fury shares (War Drum).
  attack,

  /// A normal attack's blow or shot landed on its target (God's Thunder).
  landed,

  /// A troop's blow on a monster, before the monster's defence.
  pierce,

  /// A blow on a troop of the type, after its defence (Iron Banner).
  struck,

  /// A blow on a troop of the type, after every other cut: the last (Dragon Crown).
  capped,

  /// A troop of the type took HP off a monster (Blood Fang, Void Eye).
  dealt,

  /// A troop of the type took HP from a monster; the attacker may be gone (null).
  hurtBy,

  /// A troop of the type took a killing blow (the Grail).
  lethal,

  /// A troop of the type fell (Mourning Bell).
  fell,

  /// A troop of the type killed a monster.
  kill,

  /// A heal of a troop healer of the type landed (on the troop healed, [To.healed], or the troops next to it); with
  /// [To.self], a heal landing on a troop of the type: the heal it gets (Mercy Lily's).
  heals,

  /// A troop of the type cast a skill (its own, its awakening's or a Hero's): Rune Gauntlet, Aegis Seal.
  cast,

  /// A wave starts: each living troop of the type (Watch Shield's shield, Anchor's stand).
  waveStart,

  /// A wave is won: each living troop of the type.
  waveEnd,
}

/// A condition on an [Fx], checked when its trigger fires, never inside [Game.statsOf] (catalog-design §2.2), for the
/// troop holding it and the monster in play ([FxEngine._fxWhen]). Built ([fxIfsBuilt], catalog step 0f): [hpBelow],
/// [hpAbove], [foeHpBelow], [foeHpAbove] (a share of max HP, [Fx.ifK]), [alliesNear] ([Fx.ifK] other troops within
/// [Fx.ifR]) and [firstOfTypeThisWave]; batch L-1P (decisions-log 205): [vsBoss] (the monster is the boss or a mini
/// boss), [foeShielded] (it holds a shield, [FxEngine.shielded]), [melee] (the holder fights up close) and [holds] (the
/// holder wears the small relic [Fx.ifRelic]); batch L-2P (decisions-log 207): [attackerMelee] (the monster hitting the
/// holder fights up close: Riposte's); batch L-3 (decisions-log 209): [healPastFull] (a `heals` Fx's heal went past the
/// troop's full HP: Full Cup's); batch E-1P (decisions-log 211): [foeHealer] (the monster is a healer: Healer Bane's),
/// [foeHeld] (it is held, [FxEngine.foeHeld]: Bully's Club's), [typesAlive] ([Fx.ifK] or more troop types alive: Unity
/// Ring's), [attackerRanged] (the monster hitting the holder shoots: Arrow Catcher's) and [hero] (the holder is a Hero:
/// Hero's Cloak's); batch G-1P (decisions-log 231): [fewOfType] ([Fx.ifK] or fewer troops of the holder's type alive:
/// Lone Wolf Pelt's) and [notHero] (the holder is no Hero: Champion's Mantle's trade); batch G-2 (decisions-log 238):
/// [foeHighElite] (the monster is a high elite, a mini boss or the boss: Glory Seeker's). Each other comes with the first
/// data batch that needs it, and pusaka_catalog_test.dart fails a row that uses one before.
enum If {
  vsBoss,
  attackerVsBoss,
  hpBelow,
  hpAbove,
  foeHpBelow,
  foeHpAbove,
  melee,
  ranged,
  healer,
  attackerRanged,
  attackerMelee,
  hero,
  notHero,
  holds,
  typesAlive,
  fewOfType,
  foeHeld,
  foeHealer,
  foeShielded,
  foeHighElite,
  alliesNear,
  firstOfTypeThisWave,
  healPastFull,
}

/// What an [Fx] does (catalog-design §2.2). Built: [stat] (HP, attack), [power], [cut], [cap], [heal], [status]
/// (Void Eye's mark), [leap], [save], and, with no row yet (step 0g), [cleanse] (a troop's: what monsters put on it
/// ends, [Cleanse.cleanse]) and [noHeal] (a monster's: [Status.noHeal]); batch L-2P's (decisions-log 207): [burst]
/// (extra damage on the monsters near, or a hit-back on the attacker), [ward] (a troop's shield, heal.dart), [mp], [gold]
/// and [strip] (a monster loses a good effect); batch L-3's (decisions-log 209): the first `cleanse` rows, and [heal] and
/// [ward] on new triggers ([fxBuilt]); batch E-1P's (decisions-log 211): [stat] on range, defence, walk speed and MP
/// regen, and [status] on a cast (a might) and on a blow dealt (a weaken); batch E-2P's (decisions-log 214): [mark]
/// (Ember Brand's one-hit mark, [Unit.emberMark]), and [burst], [strip], [status] and [ward] on new triggers or targets;
/// batch E-3P's (decisions-log 223): [heal] on a heal given or got, a wave's end, a skill cast and an attack, [mp] and
/// [status] on a heal given, and [cleanse] on a skill cast; batch G-1P's (decisions-log 231): [relicK] (the worn small
/// relics' work ×: Relic Altar), [skillGate] (no skill cast: Vow of Silence), [burst] on a fall, and [status] on new
/// triggers (a wave-long reflect, a struck block, a hold, a hurt-by mark); batch G-2's (decisions-log 238): [revive] (a
/// fallen troop back, Resurrection's way: Phoenix Plume), [mp] on a skill cast to the troops near, and [status] on new
/// targets (a link on the troops near, a cap at 0 after a fall, a hex, a might on the whole type after a kill); the others
/// come with their data batches.
enum Eff { stat, power, cut, cap, heal, ward, status, mark, leap, burst, save, mp, cooldown, gold, strip, cleanse, revive, noHeal, relicK, skillGate, roster }

/// Whom an [Fx] works on: the troop itself, its whole type, the troops within [Fx.r], the most hurt troop near, the
/// monster hit, the monsters within [Fx.r], the attacker, the troop a heal landed on (a `heals`
/// Fx's: Full Cup, Pure Water; batch L-3). [nearTroops] are the living troops within [Fx.r], the holder among them
/// (Heartbeat's, Bright Spring's, Saint's Tear's), but a fallen one (Mourning Bell's) and, after a heal, the troop healed
/// (Halo Lantern's: the [Fx.count] nearest it).
enum To { self, type, nearTroops, mostHurtNear, foeHit, nearFoes, attacker, healed }

/// The stat an [Eff.stat] changes: [hpDmg] is max HP and attack (a healer's heal) together, by one k (Vow of Silence's);
/// [splash] adds px to a normal attack's splash (Wide Blows').
enum Stat { hp, dmg, def, regen, mp, mpRegen, speed, range, splash, hpDmg }

/// The Ukir role of a Pusaka (item-artefact-design §2; pusaka.dart's Ukir): which items count twice on its bar
/// ([roleItems]).
enum UkirRole { attack, guard, life }

/// One effect line of a Pusaka: [on] (its trigger), [when] (its condition, with [ifK], a share of max HP or a count,
/// [ifR], its reach in px, and [ifRelic], the small relic [If.holds] asks about), [eff] on [to], and its numbers.
/// [k] is by stars, ★1 to ★3 (one number: the same at every star), read through [pusakaAt]; [boss] is [k] on the boss
/// (Tier.boss). [every]: the trigger's every Nth (0: each time); [furyBeat]: that Nth is a worn fury's ([furyEvery]:
/// Twin Fury), not its own, so the Bayangan that stretch an every-Nth Fx (Off Beat, L-2B) skip it and it is no
/// [OmenNeed.everyFx]. [count]: a whole number by stars, read through [pusakaCountAt] (God's Thunder's leaps; a `ward`
/// Fx's most, in its k's: Bone Buckler's; a `cleanse` Fx's bad effects ended: Salt Charm's). [r] a reach (px), [cd] its
/// own cooldown (s, [Unit.fxReady]; a strip or a cleanse, which has no strength, waits [k] s instead: Spell Cutter's,
/// Salt Charm's, by stars: [cdByStars]), [cap] a ceiling (a `ward` Fx's most, a share of max HP: Full Cup's), [time] how
/// long a status lasts (s; a taunt, which has no strength, lasts [k] s instead: Challenge Letter). [regen]: with
/// [Stat.hp], this share of the new max HP back every second (Dragon Heart). Every number comes from a named `*K`
/// constant.
class Fx {
  const Fx(this.on, this.eff, this.to,
      {this.when,
      this.ifK = 0,
      this.ifR = 0,
      this.ifRelic,
      this.every = 0,
      this.furyBeat = false,
      this.k = const [],
      this.boss,
      this.count = const [],
      this.r = 0,
      this.cd = 0,
      this.cap = 0,
      this.time = 0,
      this.regen = 0,
      this.stat,
      this.status});

  final Trig on;
  final If? when;
  final double ifK, ifR;
  final Relic? ifRelic;
  final Eff eff;
  final To to;
  final int every;
  final bool furyBeat;
  final List<double> k;
  final List<double>? boss;
  final List<int> count;
  final double r, cd, cap, time, regen;
  final Stat? stat;
  final Status? status;

  /// The key no two rows' first Fx share (catalog-design §3: each first-Fx key appears once).
  (Trig, If?, Eff, Stat?, Status?, To) get key => (on, when, eff, stat, status, to);

  /// Whether its k by stars is its cooldown (s), not a strength ([FxBound.cd]): a strip's (Spell Cutter's), and a
  /// cleanse's with a k (Salt Charm's, Pure Water's); neither has a strength.
  bool get cdByStars => eff == Eff.strip || (eff == Eff.cleanse && k.isNotEmpty);

  /// Whether it waits out its own cooldown between procs ([FxEngine._fxGate]): a [cd], or its k ([cdByStars]).
  bool get cooled => cd > 0 || cdByStars;
}

/// An icon: a [size]-px square cell of [sheet] (assets/images/) at [x], [y], tinted [tint] (ARGB; null: as drawn). A
/// Pusaka's is its cell of the Artifacts' atlas ([artifactIcon]), a small relic's its own file ([relicIcon]).
class IconRef {
  const IconRef(this.sheet, {this.x = 0, this.y = 0, this.size = 32, this.tint});

  /// ui_icons.png's 16 px icon at [x], [y].
  const IconRef.ui(this.x, this.y, {this.tint})
      : sheet = 'ui_icons.png',
        size = 16;

  final String sheet;
  final int x, y, size;
  final int? tint;
}

/// The icon tints by use (catalog-design §2.6, one table for every tier): attack red or orange, guard steel or silver,
/// life green or gold, utility violet, MP the MP bolt's blue (`_mpPaint`); a Pusaka's own icon is untinted.
const tintRed = 0xFFE0503C, tintOrange = 0xFFF08A3C, tintSteel = 0xFF8B9BB4, tintSilver = 0xFFC8D0DC;
const tintGreen = 0xFF5FCB6A, tintGold = 0xFFE8C547, tintViolet = 0xFFA97CF0, tintMp = 0xFF4DA6FF;

/// ui_icons.png's cells that mean something else on the screen (the coin, the sword, the gear, ...): never a Pusaka's.
const meaningCells = [(192, 0), (96, 0), (16, 16), (32, 16), (112, 16), (128, 16), (144, 32), (192, 16), (208, 48), (192, 32), (192, 48)];

/// One Pusaka (catalog-design §2.1): its [rarity], Ukir [role] (null: an oath, which takes no Ukir), [icon], at most two
/// [fx] (the second a trade or a rider; none: an oath's bespoke rules), the [epithet] of its build name ("Templar
/// Undying", [Pusaka.buildNameOf]; null: none, the oaths), the Bayangan kind that answers it ([counter]; on a healer
/// [healerCounter]), whether the Toko sells it ([store]) and whether it is in the game at all ([live]: a data batch
/// switched off is never dealt nor sold).
class Art {
  const Art(this.rarity, this.role, this.icon, {required this.fx, this.epithet, required this.counter, this.healerCounter, this.store = false, this.live = true});

  final Rarity rarity;
  final UkirRole? role;
  final IconRef icon;
  final List<Fx> fx;
  final String? epithet;
  final OmenKind counter;
  final OmenKind? healerCounter;
  final bool store, live;
}

/// Whether a new Epik is sold in the Toko too (owner decision 3, asked, not yet answered; the default: no, the chest
/// alone deals them and the Toko keeps today's five). Every new Epik row says `store: newEpikStore`.
const newEpikStore = false;

/// The words the templates use for a skill and its MP (owner decision 2, asked, not yet answered; the default: say
/// them).
const fxWords = (skill: 'skill', mp: 'MP');

/// Every Pusaka, in [Relic] order: the catalog's 90, 30 a rarity (the last six, batch G-4's oaths: decisions-log 247), the
/// first twelve the five Epik, the chest's four Langka and the first three Legenda. Final, not const: a row reads its numbers from the `*K` records' fields, which a const can't.
final pusakaCatalog = <Relic, Art>{
  // The five Epik: today's artefacts, sold in the Toko beside the chest's cards (store.dart, decisions-log 138).
  Relic.dragonHeart: Art(Rarity.epik, UkirRole.guard, artifactIcon('dragonHeart'), // a dark red heart
      store: true,
      epithet: 'Giant', // the giant: its HP
      counter: OmenKind.wearDown, // Wound until the Epik cut-over (decisions-log 223): a share of max HP grows with it
      fx: [Fx(Trig.always, Eff.stat, To.type, stat: Stat.hp, k: dragonHeartK.hp, regen: dragonHeartK.regen)]),
  Relic.dawnStar: Art(Rarity.epik, UkirRole.attack, artifactIcon('dawnStar'), // a gold morning star
      store: true,
      epithet: 'Dawn', // the dawn: its power
      counter: OmenKind.armor,
      healerCounter: OmenKind.healSiphon, // Wound until the Epik cut-over (decisions-log 223)
      fx: [Fx(Trig.always, Eff.stat, To.type, stat: Stat.dmg, k: dawnStarK.power)]),
  Relic.godThunder: Art(Rarity.epik, UkirRole.attack, artifactIcon('godThunder'), // a gold hammer
      store: true,
      epithet: 'Storm', // the storm: its blows leap
      counter: OmenKind.mend,
      fx: [Fx(Trig.landed, Eff.leap, To.nearFoes, k: [godThunderK.share], count: godThunderK.jumps, r: godThunderK.reach)]),
  Relic.grail: Art(Rarity.epik, UkirRole.life, artifactIcon('grail'), // a gold chalice
      store: true,
      epithet: 'Undying', // "Undying Templar": no blow kills it the first time
      counter: OmenKind.prey, // Haste until the Epik cut-over (decisions-log 223): a saved troop is left low
      fx: [Fx(Trig.lethal, Eff.save, To.self, k: grailK.hpLeft, time: grailK.time)]),
  Relic.voidEye: Art(Rarity.epik, UkirRole.attack, artifactIcon('voidEye'), // a violet slit eye
      store: true,
      epithet: 'Void', // the void: what it marks takes more
      counter: OmenKind.armor,
      fx: [Fx(Trig.dealt, Eff.status, To.foeHit, status: Status.voidMark, k: voidEyeK.taken, boss: voidEyeK.boss, time: voidEyeK.time)]),
  // The chest's Langka (draft.dart, decisions-log 152).
  Relic.ironBanner: Art(Rarity.langka, UkirRole.guard, artifactIcon('ironBanner'),
      epithet: 'Steel', // steel: it takes less
      counter: OmenKind.haste,
      fx: [Fx(Trig.struck, Eff.cut, To.self, k: ironBannerK)]),
  Relic.bloodFang: Art(Rarity.langka, UkirRole.life, artifactIcon('bloodFang'),
      epithet: 'Blood', // bloodthirsty: it drinks what it deals
      counter: OmenKind.wound,
      fx: [Fx(Trig.dealt, Eff.heal, To.self, k: bloodFangK)]),
  Relic.warDrum: Art(Rarity.langka, UkirRole.attack, artifactIcon('warDrum'),
      epithet: 'War', // the war drum: every third blow harder
      counter: OmenKind.thorns,
      fx: [Fx(Trig.attack, Eff.power, To.foeHit, every: warDrumK.every, k: warDrumK.hit)]),
  Relic.mourningBell: Art(Rarity.langka, UkirRole.life, artifactIcon('mourningBell'),
      epithet: 'Mourning', // mourning: its fallen heal the rest
      counter: OmenKind.wound,
      fx: [Fx(Trig.fell, Eff.heal, To.nearTroops, k: mourningBellK.heal, r: mourningBellK.reach)]),
  // The Legenda (pusaka.dart, decisions-log 155): Dragon Crown on a type; the oaths are the army's, bespoke, and no
  // type is named after them.
  Relic.dragonCrown: Art(Rarity.legenda, UkirRole.guard, artifactIcon('dragonCrown'),
      epithet: 'Crowned', // crowned: no blow fells it at once
      counter: OmenKind.shield,
      fx: [Fx(Trig.capped, Eff.cap, To.self, k: [crownCap])]),
  Relic.oathOfOne: Art(Rarity.legenda, null, artifactIcon('oathOfOne'), counter: OmenKind.guard, fx: []),
  Relic.alliance: Art(Rarity.legenda, null, artifactIcon('alliance'), counter: OmenKind.guard, fx: []),
  // Batch L-1P (draft.dart, decisions-log 205; catalog-design §3.1): ten more Langka from the chest, never in the Toko.
  // Their counters are catalog-bayangan-v2 §4's (batch L-1B's kinds and today's Spikes).
  Relic.titanBane: Art(Rarity.langka, UkirRole.attack, artifactIcon('titanBane'),
      live: liveL1P,
      epithet: 'Fearless', // fearless: it hits the boss harder
      counter: OmenKind.deflect,
      fx: [Fx(Trig.pierce, Eff.power, To.foeHit, when: If.vsBoss, k: titanBaneK)]),
  Relic.finishingBlade: Art(Rarity.langka, UkirRole.attack, artifactIcon('finishingBlade'),
      live: liveL1P,
      epithet: 'Ruthless', // ruthless: it finishes the weak
      counter: OmenKind.stubborn,
      fx: [Fx(Trig.pierce, Eff.power, To.foeHit, when: If.foeHpBelow, ifK: finishingBladeK.below, k: finishingBladeK.hit)]),
  Relic.firstCut: Art(Rarity.langka, UkirRole.attack, artifactIcon('firstCut'),
      live: liveL1P,
      epithet: 'Keen', // keen: its first cuts bite
      counter: OmenKind.brace,
      fx: [Fx(Trig.pierce, Eff.power, To.foeHit, when: If.foeHpAbove, ifK: firstCutK.above, k: firstCutK.hit)]),
  Relic.shellCracker: Art(Rarity.langka, UkirRole.attack, artifactIcon('shellCracker'),
      live: liveL1P,
      epithet: 'Breaching', // it breaches shields
      counter: OmenKind.hardShell,
      fx: [Fx(Trig.attack, Eff.power, To.foeHit, when: If.foeShielded, k: shellCrackerK)]),
  Relic.twinFury: Art(Rarity.langka, UkirRole.attack, artifactIcon('twinFury'),
      live: liveL1P,
      epithet: 'Furious', // a fury on a fury
      counter: OmenKind.thorns,
      fx: [Fx(Trig.attack, Eff.power, To.foeHit, when: If.holds, ifRelic: Relic.fury, every: furyEvery, furyBeat: true, k: twinFuryK)]),
  Relic.steadyStance: Art(Rarity.langka, UkirRole.guard, artifactIcon('steadyStance'),
      live: liveL1P,
      epithet: 'Steady', // steady while whole
      counter: OmenKind.sunder,
      fx: [Fx(Trig.struck, Eff.cut, To.self, when: If.hpAbove, ifK: steadyStanceK.above, k: steadyStanceK.cut)]),
  Relic.turtleShell: Art(Rarity.langka, UkirRole.guard, artifactIcon('turtleShell'),
      live: liveL1P,
      epithet: 'Turtle', // into its shell when hurt
      counter: OmenKind.sunder,
      fx: [Fx(Trig.struck, Eff.cut, To.self, when: If.hpBelow, ifK: turtleShellK.below, k: turtleShellK.cut)]),
  Relic.dullingMail: Art(Rarity.langka, UkirRole.guard, artifactIcon('dullingMail'),
      live: liveL1P,
      epithet: 'Dulling', // it dulls the blades that hit it
      counter: OmenKind.unshaken,
      fx: [
        Fx(Trig.hurtBy, Eff.status, To.attacker,
            status: Status.weaken,
            k: dullingMailK.dealt,
            boss: bossShare(dullingMailK.dealt, dullingMailK.boss),
            time: dullingMailK.time,
            cd: dullingMailK.cd),
      ]),
  Relic.challengeLetter: Art(Rarity.langka, UkirRole.guard, artifactIcon('challengeLetter'),
      live: liveL1P,
      epithet: 'Bold', // it calls them out
      counter: OmenKind.defiant,
      fx: [
        Fx(Trig.attack, Eff.status, To.foeHit,
            when: If.melee,
            status: Status.taunt,
            every: challengeLetterK.every,
            k: challengeLetterK.time, // a taunt's k is its time
            boss: bossShare(challengeLetterK.time, challengeLetterK.boss, base: 0)),
      ]),
  Relic.snareCord: Art(Rarity.langka, UkirRole.attack, artifactIcon('snareCord'), // utility (attack)
      live: liveL1P,
      epithet: 'Snaring', // it snares what it hits
      counter: OmenKind.unshaken,
      fx: [
        Fx(Trig.attack, Eff.status, To.foeHit,
            status: Status.slow,
            every: snareCordK.every,
            k: snareCordK.slow,
            boss: bossShare(snareCordK.slow, snareCordK.boss),
            time: snareCordK.time),
      ]),
  // Batch L-2P (draft.dart, decisions-log 207; catalog-design §3.1): ten more Langka from the chest, never in the Toko.
  // Their counters are catalog-bayangan-v2 §4's (batch L-2B's kinds, L-1B's Brace, today's Spikes and Thrift).
  Relic.momentum: Art(Rarity.langka, UkirRole.attack, artifactIcon('momentum'),
      live: liveL2P,
      epithet: 'Rushing', // it rushes from one kill to the next
      counter: OmenKind.avenge,
      fx: [Fx(Trig.kill, Eff.power, To.self, k: momentumK)]),
  Relic.bleedingEdge: Art(Rarity.langka, UkirRole.attack, artifactIcon('bleedingEdge'),
      live: liveL2P,
      epithet: 'Rending', // its cuts keep bleeding
      counter: OmenKind.offBeat,
      fx: [
        Fx(Trig.attack, Eff.status, To.foeHit,
            status: Status.bleed, every: bleedingEdgeK.every, k: bleedingEdgeK.share, time: bleedingEdgeK.time),
      ]),
  Relic.shatterShard: Art(Rarity.langka, UkirRole.attack, artifactIcon('shatterShard'),
      live: liveL2P,
      epithet: 'Shattering', // its blows shatter onto the next monster
      counter: OmenKind.brace,
      fx: [
        Fx(Trig.landed, Eff.burst, To.nearFoes,
            every: shatterShardK.every, k: shatterShardK.share, r: shatterShardK.reach, cd: shatterShardK.cd),
      ]),
  Relic.painCrystal: Art(Rarity.langka, UkirRole.guard, artifactIcon('painCrystal'), // utility (guard)
      live: liveL2P,
      epithet: 'Crystal', // its pain turns to MP
      counter: OmenKind.spellTax,
      fx: [Fx(Trig.struck, Eff.mp, To.self, k: painCrystalK.mp, cd: painCrystalK.cd)]),
  Relic.watchShield: Art(Rarity.langka, UkirRole.guard, artifactIcon('watchShield'),
      live: liveL2P,
      epithet: 'Watchful', // shielded before the first blow
      counter: OmenKind.fade,
      fx: [Fx(Trig.waveStart, Eff.ward, To.self, k: watchShieldK)]),
  Relic.boneBuckler: Art(Rarity.langka, UkirRole.guard, artifactIcon('boneBuckler'),
      live: liveL2P,
      epithet: 'Bone', // it wears its kills
      counter: OmenKind.shieldbreak,
      fx: [Fx(Trig.kill, Eff.ward, To.self, k: boneBucklerK.add, count: [boneBucklerK.stack])]),
  Relic.riposte: Art(Rarity.langka, UkirRole.guard, artifactIcon('riposte'),
      live: liveL2P,
      epithet: 'Parrying', // it answers the blades that hit it
      counter: OmenKind.thorns,
      fx: [Fx(Trig.hurtBy, Eff.burst, To.attacker, when: If.attackerMelee, every: riposteK.every, k: riposteK.share)]),
  Relic.manaLeech: Art(Rarity.langka, UkirRole.life, artifactIcon('manaLeech'), // utility (life)
      live: liveL2P,
      epithet: 'Leeching', // it drinks MP from its blows
      counter: OmenKind.spellTax,
      fx: [Fx(Trig.attack, Eff.mp, To.self, every: manaLeechK.every, k: manaLeechK.mp)]),
  Relic.lootersPouch: Art(Rarity.langka, UkirRole.attack, artifactIcon('lootersPouch'), // utility (attack)
      live: liveL2P,
      epithet: 'Greedy', // it loots what it kills
      counter: OmenKind.thrift,
      fx: [Fx(Trig.kill, Eff.gold, To.self, k: lootersPouchK)]),
  Relic.spellCutter: Art(Rarity.langka, UkirRole.attack, artifactIcon('spellCutter'), // utility (attack)
      live: liveL2P,
      epithet: 'Dispelling', // it cuts the spells monsters wear
      counter: OmenKind.lingering,
      fx: [Fx(Trig.attack, Eff.strip, To.foeHit, every: spellCutterK.every, k: spellCutterK.cd)]), // a strip's k is its cooldown
  // Batch L-3 (draft.dart, decisions-log 209; catalog-design §3.1): the last six Langka from the chest, never in the
  // Toko. Their counters are catalog-bayangan-v2 §4's (L-1B's Quick Spells, L-3B's Grudge, Scar, Pummel and Drag, and
  // today's Wound).
  Relic.saltCharm: Art(Rarity.langka, UkirRole.guard, artifactIcon('saltCharm'),
      live: liveL3P,
      epithet: 'Warding', // it wards off what monsters put on it
      counter: OmenKind.quickSpells,
      fx: [Fx(Trig.struck, Eff.cleanse, To.self, k: saltCharmK.cd, count: [saltCharmK.clears])]), // a cleanse's k is its cooldown
  Relic.wolfFeast: Art(Rarity.langka, UkirRole.life, artifactIcon('wolfFeast'),
      live: liveL3P,
      epithet: 'Ravenous', // it feeds on what it kills
      counter: OmenKind.grudge,
      fx: [Fx(Trig.kill, Eff.heal, To.self, k: wolfFeastK)]),
  Relic.fullCup: Art(Rarity.langka, UkirRole.life, artifactIcon('fullCup'),
      live: liveL3P,
      epithet: 'Brimming', // its heals brim over into shields
      counter: OmenKind.scar,
      fx: [Fx(Trig.heals, Eff.ward, To.healed, when: If.healPastFull, k: fullCupK.share, cap: fullCupK.most)]),
  Relic.hiddenFlask: Art(Rarity.langka, UkirRole.life, artifactIcon('hiddenFlask'),
      live: liveL3P,
      epithet: 'Prudent', // it keeps a flask for the worst
      counter: OmenKind.pummel,
      fx: [Fx(Trig.struck, Eff.heal, To.self, when: If.hpBelow, ifK: hiddenFlaskK.below, k: hiddenFlaskK.heal)]),
  Relic.livingMoss: Art(Rarity.langka, UkirRole.life, artifactIcon('livingMoss'),
      live: liveL3P,
      epithet: 'Mossy', // moss grows over its wounds
      counter: OmenKind.wound,
      fx: [
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.regen, k: livingMossK.regen),
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.dmg, k: [livingMossK.dmg]), // the trade
      ]),
  Relic.pureWater: Art(Rarity.langka, UkirRole.life, artifactIcon('pureWater'),
      live: liveL3P,
      epithet: 'Pure', // its heals wash off what monsters put on
      counter: OmenKind.drag,
      fx: [Fx(Trig.heals, Eff.cleanse, To.healed, k: pureWaterK.cd, count: [pureWaterK.clears])]), // a cleanse's k is its cooldown
  // Batch E-1P (draft.dart, decisions-log 211; catalog-design §3.2): the first ten new Epik, from the chest, never in the
  // Toko ([newEpikStore]). Their counters are catalog-bayangan-v2 §4's (batch E-1B's kinds).
  Relic.healerBane: Art(Rarity.epik, UkirRole.attack, artifactIcon('healerBane'),
      store: newEpikStore,
      live: liveE1P,
      epithet: 'Merciless', // it hunts the monsters' healers
      counter: OmenKind.darkHymn,
      fx: [Fx(Trig.attack, Eff.power, To.foeHit, when: If.foeHealer, k: healerBaneK)]),
  Relic.bullyClub: Art(Rarity.epik, UkirRole.attack, artifactIcon('bullyClub'),
      store: newEpikStore,
      live: liveE1P,
      epithet: 'Cruel', // it hits the held ones harder
      counter: OmenKind.hunker,
      fx: [Fx(Trig.attack, Eff.power, To.foeHit, when: If.foeHeld, k: bullyClubK)]),
  Relic.unityRing: Art(Rarity.epik, UkirRole.attack, artifactIcon('unityRing'),
      store: newEpikStore,
      live: liveE1P,
      epithet: 'United', // strong while the army is many types
      counter: OmenKind.muster,
      fx: [Fx(Trig.attack, Eff.power, To.foeHit, when: If.typesAlive, ifK: unityRingK.types.toDouble(), k: unityRingK.hit)]),
  Relic.runeGauntlet: Art(Rarity.epik, UkirRole.attack, artifactIcon('runeGauntlet'),
      store: newEpikStore,
      live: liveE1P,
      epithet: 'Runic', // its skills charge its blows
      counter: OmenKind.envy,
      fx: [Fx(Trig.cast, Eff.status, To.self, status: Status.might, k: runeGauntletK.might, time: runeGauntletK.time)]),
  Relic.hawkFeather: Art(Rarity.epik, UkirRole.attack, artifactIcon('hawkFeather'), // utility (attack)
      store: newEpikStore,
      live: liveE1P,
      epithet: 'Hawk', // it reaches farther
      counter: OmenKind.arrowWard,
      fx: [
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.range, k: hawkFeatherK.range),
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.dmg, k: [hawkFeatherK.dmg]), // the trade
      ]),
  Relic.witherroot: Art(Rarity.epik, UkirRole.guard, artifactIcon('witherroot'),
      store: newEpikStore,
      live: liveE1P,
      epithet: 'Withering', // what it hits withers
      counter: OmenKind.zeal,
      fx: [
        Fx(Trig.dealt, Eff.status, To.foeHit,
            status: Status.weaken, k: witherrootK.dealt, boss: witherrootK.boss, time: witherrootK.time),
      ]),
  Relic.arrowCatcher: Art(Rarity.epik, UkirRole.guard, artifactIcon('arrowCatcher'),
      store: newEpikStore,
      live: liveE1P,
      epithet: 'Arrowproof', // the arrows fall short
      counter: OmenKind.boneArrows,
      fx: [Fx(Trig.struck, Eff.cut, To.self, when: If.attackerRanged, k: arrowCatcherK)]),
  Relic.stoneCoat: Art(Rarity.epik, UkirRole.guard, artifactIcon('stoneCoat'),
      store: newEpikStore,
      live: liveE1P,
      epithet: 'Stone', // hard and slow as stone
      counter: OmenKind.enrage,
      fx: [
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.def, k: [for (final d in stoneCoatK.def) d * shieldDef]),
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.speed, k: [stoneCoatK.speed]), // the trade
      ]),
  Relic.heroCloak: Art(Rarity.epik, UkirRole.guard, artifactIcon('heroCloak'),
      store: newEpikStore,
      live: liveE1P,
      epithet: 'Cloaked', // its Hero wears the cloak
      counter: OmenKind.wearDown,
      fx: [Fx(Trig.struck, Eff.cut, To.self, when: If.hero, k: heroCloakK)]),
  Relic.moonwell: Art(Rarity.epik, UkirRole.life, artifactIcon('moonwell'), // utility (life)
      store: newEpikStore,
      live: liveE1P,
      epithet: 'Moonlit', // the moon fills its MP
      counter: OmenKind.counterspell,
      fx: [
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.mpRegen, k: moonwellK.mpRegen),
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.hp, k: [moonwellK.hp]), // the trade
      ]),
  // Batch E-2P (draft.dart, decisions-log 214; catalog-design §3.2): seven more new Epik, from the chest, never in the
  // Toko ([newEpikStore]). Their counters are catalog-bayangan-v2 §4's (batch E-2B's kinds, and today's Mend).
  Relic.emberBrand: Art(Rarity.epik, UkirRole.attack, artifactIcon('emberBrand'),
      store: newEpikStore,
      live: liveE2P,
      epithet: 'Ember', // its embers mark what the others finish
      counter: OmenKind.markWard,
      fx: [Fx(Trig.attack, Eff.mark, To.foeHit, every: emberBrandK.every, k: emberBrandK.hit, time: emberBrandK.time)]),
  Relic.funeralPyre: Art(Rarity.epik, UkirRole.attack, artifactIcon('funeralPyre'),
      store: newEpikStore,
      live: liveE2P,
      epithet: 'Burning', // its kills burn the monsters near
      counter: OmenKind.closeRanks,
      fx: [Fx(Trig.kill, Eff.burst, To.nearFoes, k: funeralPyreK.share, r: funeralPyreK.reach, cd: funeralPyreK.cd)]),
  Relic.nullStone: Art(Rarity.epik, UkirRole.attack, artifactIcon('nullStone'), // utility (attack)
      store: newEpikStore,
      live: liveE2P,
      epithet: 'Null', // what hits it loses its spells
      counter: OmenKind.mend,
      fx: [Fx(Trig.hurtBy, Eff.strip, To.attacker, k: nullStoneK.cd)]), // a strip's k is its cooldown
  Relic.fallenFlag: Art(Rarity.epik, UkirRole.attack, artifactIcon('fallenFlag'),
      store: newEpikStore,
      live: liveE2P,
      epithet: 'Rallying', // its fallen rally the troops near
      counter: OmenKind.triumph,
      fx: [
        Fx(Trig.fell, Eff.status, To.nearTroops,
            status: Status.might, k: fallenFlagK.might, time: fallenFlagK.time, r: fallenFlagK.reach),
      ]),
  Relic.aegisSeal: Art(Rarity.epik, UkirRole.guard, artifactIcon('aegisSeal'),
      store: newEpikStore,
      live: liveE2P,
      epithet: 'Aegis', // its skills seal it in a shield
      counter: OmenKind.counterspell,
      fx: [Fx(Trig.cast, Eff.ward, To.self, k: aegisSealK)]),
  Relic.wardensHorn: Art(Rarity.epik, UkirRole.guard, artifactIcon('wardensHorn'),
      store: newEpikStore,
      live: liveE2P,
      epithet: 'Warden', // its horn calls the monsters near onto it
      counter: OmenKind.blindside,
      fx: [
        Fx(Trig.attack, Eff.status, To.nearFoes,
            when: If.melee,
            status: Status.taunt,
            every: wardensHornK.every,
            k: wardensHornK.time, // a taunt's k is its time
            boss: bossShare(wardensHornK.time, 0, base: 0), // none on the boss
            r: wardensHornK.reach,
            cd: wardensHornK.cd),
      ]),
  Relic.anchor: Art(Rarity.epik, UkirRole.guard, artifactIcon('anchor'),
      store: newEpikStore,
      live: liveE2P,
      epithet: 'Anchored', // no monster moves it
      counter: OmenKind.bileSacs,
      fx: [
        Fx(Trig.waveStart, Eff.status, To.self, status: Status.noShove), // the whole wave: no number by stars
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.speed, k: anchorK.speed), // the trade, lighter by stars
      ]),
  // Batch E-3P (draft.dart, decisions-log 223; catalog-design §3.2): the last eight new Epik, from the chest, never in the
  // Toko ([newEpikStore]). Their counters are catalog-bayangan-v2 §4's (batch E-1B's Counterspell and Envy, E-3B's Heal
  // Siphon, Prey and Herd Hunt).
  Relic.manaHymn: Art(Rarity.epik, UkirRole.life, artifactIcon('manaHymn'), // utility (life)
      store: newEpikStore,
      live: liveE3P,
      epithet: 'Hymnal', // its hymn fills the MP of those it heals
      counter: OmenKind.counterspell,
      fx: [Fx(Trig.heals, Eff.mp, To.healed, k: manaHymnK)]),
  Relic.saintTear: Art(Rarity.epik, UkirRole.life, artifactIcon('saintTear'), // utility (life)
      store: newEpikStore,
      live: liveE3P,
      epithet: 'Saintly', // its skills wash off what monsters put on
      counter: OmenKind.counterspell,
      fx: [Fx(Trig.cast, Eff.cleanse, To.nearTroops, k: saintTearK.cd, r: saintTearK.reach)]), // a cleanse's k is its cooldown; no count: all
  Relic.braveSong: Art(Rarity.epik, UkirRole.life, artifactIcon('braveSong'),
      store: newEpikStore,
      live: liveE3P,
      epithet: 'Brave', // those it heals fight braver
      counter: OmenKind.envy,
      fx: [Fx(Trig.heals, Eff.status, To.healed, status: Status.might, k: braveSongK.might, time: braveSongK.time)]),
  Relic.haloLantern: Art(Rarity.epik, UkirRole.life, artifactIcon('haloLantern'),
      store: newEpikStore,
      live: liveE3P,
      epithet: 'Haloed', // its heals glow onto the troops next to them
      counter: OmenKind.healSiphon,
      fx: [Fx(Trig.heals, Eff.heal, To.nearTroops, k: haloLanternK.share, count: [haloLanternK.most], r: haloLanternK.reach)]),
  Relic.hearth: Art(Rarity.epik, UkirRole.life, artifactIcon('hearth'),
      store: newEpikStore,
      live: liveE3P,
      epithet: 'Hearty', // a hot meal after each wave
      counter: OmenKind.prey,
      fx: [Fx(Trig.waveEnd, Eff.heal, To.self, k: hearthK)]),
  Relic.heartbeat: Art(Rarity.epik, UkirRole.life, artifactIcon('heartbeat'),
      store: newEpikStore,
      live: liveE3P,
      epithet: 'Pulsing', // its blows beat a heal into the troops near
      counter: OmenKind.herdHunt,
      fx: [Fx(Trig.attack, Eff.heal, To.nearTroops, every: heartbeatK.every, k: heartbeatK.heal, r: heartbeatK.reach)]),
  Relic.mercyLily: Art(Rarity.epik, UkirRole.life, artifactIcon('mercyLily'),
      store: newEpikStore,
      live: liveE3P,
      epithet: 'Merciful', // the heals it gets when low land bigger
      counter: OmenKind.prey,
      fx: [Fx(Trig.heals, Eff.heal, To.self, when: If.hpBelow, ifK: mercyLilyK.below, k: mercyLilyK.heal)]),
  Relic.brightSpring: Art(Rarity.epik, UkirRole.life, artifactIcon('brightSpring'),
      store: newEpikStore,
      live: liveE3P,
      epithet: 'Bright', // its skills well up as a heal
      counter: OmenKind.healSiphon,
      fx: [Fx(Trig.cast, Eff.heal, To.nearTroops, k: brightSpringK.heal, r: brightSpringK.reach)]),
  // Batch G-1P (draft.dart, decisions-log 231; catalog-design §3.3): the first ten new Legenda, from the chest like Dragon
  // Crown, never in the Toko; ★1 only, Carve moves the one number [ukirPerStar] names. Each a rule with a real cost: a
  // condition, or a trade. Their counters are catalog-bayangan-v2 §4's (batch G-1B's kinds).
  Relic.loneWolf: Art(Rarity.legenda, UkirRole.attack, artifactIcon('loneWolf'),
      live: liveG1P,
      epithet: 'Lone', // strong while few
      counter: OmenKind.blunt,
      fx: [Fx(Trig.attack, Eff.power, To.foeHit, when: If.fewOfType, ifK: loneWolfK.few.toDouble(), k: [loneWolfK.power])]),
  Relic.martyrFlame: Art(Rarity.legenda, UkirRole.attack, artifactIcon('martyrFlame'),
      live: liveG1P,
      epithet: 'Martyred', // its fallen burn the monsters near
      counter: OmenKind.veterans,
      fx: [
        Fx(Trig.fell, Eff.burst, To.nearFoes, k: [martyrFlameK.share], r: martyrFlameK.reach),
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.hp, k: [martyrFlameK.hp]), // the trade
      ]),
  Relic.wideBlows: Art(Rarity.legenda, UkirRole.attack, artifactIcon('wideBlows'),
      live: liveG1P,
      epithet: 'Sweeping', // its blows sweep the monsters near
      counter: OmenKind.scatter,
      fx: [
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.splash, k: [wideBlowsK.splash]),
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.dmg, k: [wideBlowsK.dmg]), // the trade, lighter by Carve
      ]),
  Relic.champion: Art(Rarity.legenda, UkirRole.attack, artifactIcon('champion'),
      live: liveG1P,
      epithet: 'Champion', // its Heroes lead
      counter: OmenKind.horde,
      fx: [
        Fx(Trig.attack, Eff.power, To.foeHit, when: If.hero, k: [championK.hero]),
        Fx(Trig.attack, Eff.power, To.foeHit, when: If.notHero, k: [championK.rest]), // the trade
      ]),
  Relic.vengeance: Art(Rarity.legenda, UkirRole.attack, artifactIcon('vengeance'),
      live: liveG1P,
      epithet: 'Vengeful', // what hurts it is marked
      counter: OmenKind.spite,
      fx: [
        Fx(Trig.hurtBy, Eff.status, To.attacker,
            status: Status.pusakaMark, k: [vengeanceK.taken], boss: [vengeanceK.boss], time: vengeanceK.time),
        Fx(Trig.struck, Eff.cut, To.self, k: [1 - vengeanceK.selfTaken]), // the trade: a cut under 0, more taken
      ]),
  Relic.mirror: Art(Rarity.legenda, UkirRole.guard, artifactIcon('mirror'),
      live: liveG1P,
      epithet: 'Mirrored', // it sends the blows back
      counter: OmenKind.thornproof,
      fx: [
        Fx(Trig.waveStart, Eff.status, To.self, status: Status.reflect, k: [mirrorK.share]), // the whole wave
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.dmg, k: [mirrorK.dmg]), // the trade
      ]),
  Relic.ghostStep: Art(Rarity.legenda, UkirRole.guard, artifactIcon('ghostStep'),
      live: liveG1P,
      epithet: 'Ghostly', // the blows pass through it
      counter: OmenKind.executioner,
      fx: [
        Fx(Trig.struck, Eff.status, To.self, status: Status.block, every: ghostStepK.every), // no number by stars
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.dmg, k: [ghostStepK.dmg]), // the trade, lighter by Carve
      ]),
  Relic.iceGrip: Art(Rarity.legenda, UkirRole.guard, artifactIcon('iceGrip'), // utility (guard)
      live: liveG1P,
      epithet: 'Frozen', // its blows freeze the monsters in place
      counter: OmenKind.unbowed,
      fx: [
        Fx(Trig.attack, Eff.status, To.foeHit,
            status: Status.impaled,
            every: iceGripK.every,
            k: [iceGripK.hold], // a hold's k is its time
            boss: [iceGripK.bossSlow], // the boss and a mini boss: slowed instead, for [Fx.time]
            time: iceGripK.bossTime),
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.dmg, k: [iceGripK.dmg]), // the trade
      ]),
  Relic.relicAltar: Art(Rarity.legenda, UkirRole.attack, artifactIcon('relicAltar'), // utility (attack)
      live: liveG1P,
      epithet: 'Hallowed', // its small relics work harder
      counter: OmenKind.rust,
      fx: [
        Fx(Trig.always, Eff.relicK, To.type, k: [relicAltarK.k]), // at the four worn-relic sites: only a troop that wears one
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.hp, k: [relicAltarK.hp]), // the trade
      ]),
  Relic.vowSilence: Art(Rarity.legenda, UkirRole.attack, artifactIcon('vowSilence'),
      live: liveG1P,
      epithet: 'Silent', // it swore off its skills
      counter: OmenKind.hardy,
      fx: [
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.hpDmg, k: [vowSilenceK.k]),
        Fx(Trig.always, Eff.skillGate, To.type), // the trade: no skill cast
      ]),
  // Batch G-2 (draft.dart, decisions-log 238; catalog-design §3.3): eight more new Legenda, from the chest like Dragon
  // Crown, never in the Toko; ★1 only, Carve moves the one number [ukirPerStar] names. Their counters are
  // catalog-bayangan-v2 §4's (batch G-1B's Unbowed, G-2B's kinds).
  Relic.rageTotem: Art(Rarity.legenda, UkirRole.attack, artifactIcon('rageTotem'),
      live: liveG2,
      epithet: 'Raging', // it hits harder when hurt
      counter: OmenKind.vultures,
      fx: [
        Fx(Trig.attack, Eff.power, To.foeHit, when: If.hpBelow, ifK: rageTotemK.below, k: [rageTotemK.power]),
        Fx(Trig.heals, Eff.heal, To.self, k: [rageTotemK.healIn]), // the trade: the heals it gets ×, under 1
      ]),
  Relic.guardianChain: Art(Rarity.legenda, UkirRole.guard, artifactIcon('guardianChain'),
      live: liveG2,
      epithet: 'Guardian', // it takes the blows of those near
      counter: OmenKind.sideSwing,
      fx: [
        Fx(Trig.attack, Eff.status, To.nearTroops,
            status: Status.link,
            every: guardianChainK.every,
            k: [guardianChainK.share],
            time: guardianChainK.time,
            r: guardianChainK.reach), // the cost: the share it takes is its own
      ]),
  Relic.phalanx: Art(Rarity.legenda, UkirRole.guard, artifactIcon('phalanx'),
      live: liveG2,
      epithet: 'Serried', // strong shoulder to shoulder
      counter: OmenKind.sideSwing,
      fx: [
        Fx(Trig.struck, Eff.cut, To.self, when: If.alliesNear, ifK: phalanxK.near.toDouble(), ifR: phalanxK.reach, k: [phalanxK.cut]),
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.dmg, k: [phalanxK.dmg]), // the trade
      ]),
  Relic.phoenix: Art(Rarity.legenda, UkirRole.life, artifactIcon('phoenix'),
      live: liveG2,
      epithet: 'Phoenix', // it rises from its fall
      counter: OmenKind.spree,
      fx: [
        Fx(Trig.fell, Eff.revive, To.self, when: If.firstOfTypeThisWave, k: [phoenixK.hpLeft], time: phoenixK.delay),
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.hp, k: [phoenixK.hp]), // the trade
      ]),
  Relic.soulShelter: Art(Rarity.legenda, UkirRole.life, artifactIcon('soulShelter'),
      live: liveG2,
      epithet: 'Sheltering', // its fallen shelter the troops near
      counter: OmenKind.sideSwing,
      fx: [
        Fx(Trig.fell, Eff.status, To.nearTroops,
            status: Status.cap,
            k: [soulShelterK.time], // a cap at 0 has no strength: its k is its time
            r: soulShelterK.reach,
            cd: soulShelterK.cd), // the whole type's ([FxEngine._fxTypeGate])
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.dmg, k: [soulShelterK.dmg]), // the trade
      ]),
  Relic.manaFont: Art(Rarity.legenda, UkirRole.life, artifactIcon('manaFont'), // utility (life)
      live: liveG2,
      epithet: 'Wellspring', // its skills fill the MP of those near
      counter: OmenKind.backlash,
      fx: [
        Fx(Trig.cast, Eff.mp, To.nearTroops, k: [manaFontK.share], r: manaFontK.reach),
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.mpRegen, k: [manaFontK.mpRegen]), // the trade
      ]),
  Relic.hexBlade: Art(Rarity.legenda, UkirRole.attack, artifactIcon('hexBlade'), // utility (attack)
      live: liveG2,
      epithet: 'Hexing', // what it hits turns to slime
      counter: OmenKind.unbowed,
      fx: [
        Fx(Trig.attack, Eff.status, To.foeHit,
            status: Status.hex,
            every: hexBladeK.every,
            k: [hexBladeK.time], // a hex has no strength: its k is its time
            cd: hexBladeK.cd),
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.dmg, k: [hexBladeK.dmg]), // the trade
      ]),
  Relic.glorySeeker: Art(Rarity.legenda, UkirRole.attack, artifactIcon('glorySeeker'),
      live: liveG2,
      epithet: 'Glorious', // its great kills lift the whole type
      counter: OmenKind.deathless,
      fx: [
        Fx(Trig.kill, Eff.status, To.type, when: If.foeHighElite, status: Status.might, k: [glorySeekerK.might], time: glorySeekerK.time),
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.dmg, k: [glorySeekerK.dmg]), // the trade
      ]),
  // Batch G-3 (draft.dart, decisions-log 243; catalog-design §3.3): the last three new Legenda but the oaths, from the
  // chest like Dragon Crown, never in the Toko; ★1 only, Carve moves the one number [ukirPerStar] names. Their counters
  // are catalog-bayangan-v2 §4's: the batch's own Blight, G-3B's Holy Ward, G-1B's Hardy.
  Relic.vampireKiss: Art(Rarity.legenda, UkirRole.life, artifactIcon('vampireKiss'),
      live: liveG3,
      epithet: 'Vampiric', // what it drinks heals the others
      counter: OmenKind.blight,
      fx: [
        Fx(Trig.dealt, Eff.heal, To.mostHurtNear, k: [vampireKissK.share], r: vampireKissK.reach),
        Fx(Trig.heals, Eff.heal, To.self, k: [vampireKissK.healIn]), // the trade: the heals it gets ×, under 1
      ]),
  Relic.wrathPsalm: Art(Rarity.legenda, UkirRole.life, artifactIcon('wrathPsalm'),
      live: liveG3,
      epithet: 'Wrathful', // its heals smite
      counter: OmenKind.holyWard,
      fx: [
        Fx(Trig.heals, Eff.burst, To.nearFoes, k: [wrathPsalmK.share], r: wrathPsalmK.reach, cd: wrathPsalmK.cd),
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.dmg, k: [wrathPsalmK.heal]), // the trade: a healer's heal
      ]),
  Relic.graveSeal: Art(Rarity.legenda, UkirRole.attack, artifactIcon('graveSeal'), // utility (attack)
      live: liveG3,
      epithet: 'Grim', // what it hits can't mend
      counter: OmenKind.hardy,
      fx: [
        Fx(Trig.dealt, Eff.noHeal, To.foeHit, k: [graveSealK.time]), // a noHeal has no strength: its k is its time
        Fx(Trig.always, Eff.stat, To.type, stat: Stat.dmg, k: [graveSealK.dmg]), // the trade
      ]),
  // Batch G-4 (pusaka.dart, decisions-log 247; catalog-design §3.3): the last six Legenda, all oaths, from the chest like
  // Oath of One: the whole army's, bespoke rules with no Fx, no Carve and no build name. Their counters are
  // catalog-bayangan-v2 §4's: the core Guard, G-3B's Dusk, Oathbane, Rider Rush, Hero Hunt and Spell Ward.
  Relic.fewOath: Art(Rarity.legenda, null, artifactIcon('fewOath'), live: liveG4, counter: OmenKind.guard, fx: []),
  Relic.wallOath: Art(Rarity.legenda, null, artifactIcon('wallOath'), live: liveG4, counter: OmenKind.dusk, fx: []),
  Relic.bloodOath: Art(Rarity.legenda, null, artifactIcon('bloodOath'), live: liveG4, counter: OmenKind.oathbane, fx: []),
  Relic.vanguardOath: Art(Rarity.legenda, null, artifactIcon('vanguardOath'), live: liveG4, counter: OmenKind.riderRush, fx: []),
  Relic.kingsOath: Art(Rarity.legenda, null, artifactIcon('kingsOath'), live: liveG4, counter: OmenKind.heroHunt, fx: []),
  Relic.spellOath: Art(Rarity.legenda, null, artifactIcon('spellOath'), live: liveG4, counter: OmenKind.spellWard, fx: []),
};

/// [relic]'s icon: its row's ([Art.icon]), a small relic's own `relic_<name>.png`.
IconRef relicIcon(Relic relic) => pusakaCatalog[relic]?.icon ?? IconRef('relic_${relic.name}.png');

/// The Fx the engine runs (pusaka_engine.dart), by trigger and effect: a row with any other waits for its batch
/// (pusaka_catalog_test.dart fails it), and the engine throws on one ([_unbuilt]).
bool fxBuilt(Fx fx) => switch ((fx.on, fx.eff)) {
      (Trig.always, Eff.stat) =>
        const {Stat.hp, Stat.dmg, Stat.regen, Stat.range, Stat.def, Stat.speed, Stat.mpRegen, Stat.splash, Stat.hpDmg}.contains(fx.stat),
      (Trig.attack, Eff.power) || (Trig.landed, Eff.leap) || (Trig.struck, Eff.cut) || (Trig.capped, Eff.cap) => true,
      (Trig.dealt, Eff.heal) => fx.to == To.self || fx.to == To.mostHurtNear, // the most hurt troop near: Vampire Kiss's (G-3)
      (Trig.dealt, Eff.status) => (fx.status == Status.voidMark || fx.status == Status.weaken) && fx.to == To.foeHit,
      (Trig.lethal, Eff.save) => fx.to == To.self,
      (Trig.fell, Eff.heal) => fx.to == To.nearTroops,
      (Trig.struck, Eff.cleanse) => fx.to == To.self, // step 0g: no row yet (Salt Charm's)
      (Trig.dealt, Eff.noHeal) => fx.to == To.foeHit, // step 0g; its row: Grave Seal's (G-3)
      // Batch L-1P (decisions-log 205): a blow's power on a monster (Titan Bane, Finishing Blade, First Cut), a status
      // an attack puts on the monster it hits (Snare Cord's slow, Challenge Letter's taunt), and one a blow on the troop
      // puts on its attacker (Dulling Mail's weaken).
      (Trig.pierce, Eff.power) => fx.to == To.foeHit,
      (Trig.attack, Eff.status) => (fx.to == To.foeHit && const {Status.slow, Status.taunt, Status.bleed, Status.impaled, Status.hex}.contains(fx.status)) ||
          (fx.to == To.nearFoes && fx.status == Status.taunt) ||
          (fx.to == To.nearTroops && fx.status == Status.link),
      (Trig.hurtBy, Eff.status) => fx.to == To.attacker && (fx.status == Status.weaken || fx.status == Status.pusakaMark),
      // Batch L-2P (decisions-log 207): an attack's bleed, MP or strip (Bleeding Edge, Mana Leech, Spell Cutter), a landed
      // blow's burst on the monsters near its target (Shatter Shard), a blow's MP to the troop it hurt (Pain Crystal), a
      // hit back at the attacker (Riposte), a shield at a wave's start or a kill (Watch Shield, Bone Buckler), a kill's
      // next-hit power and gold (Momentum, Looter's Pouch).
      (Trig.attack, Eff.mp) || (Trig.struck, Eff.mp) => fx.to == To.self,
      (Trig.attack, Eff.strip) => fx.to == To.foeHit,
      (Trig.landed, Eff.burst) => fx.to == To.nearFoes,
      (Trig.hurtBy, Eff.burst) => fx.to == To.attacker,
      (Trig.waveStart, Eff.ward) || (Trig.kill, Eff.ward) => fx.to == To.self,
      (Trig.kill, Eff.power) || (Trig.kill, Eff.gold) => fx.to == To.self,
      // Batch L-3 (decisions-log 209): a kill's heal (Wolf Feast), a blow's heal once a wave when low (Hidden Flask; the
      // `always` regen above: Living Moss), and a healer's heal that also shields or cleanses the troop healed (Full Cup,
      // Pure Water); Salt Charm is the `struck` cleanse of step 0g, on its own cooldown.
      (Trig.kill, Eff.heal) || (Trig.struck, Eff.heal) => fx.to == To.self,
      (Trig.heals, Eff.ward) || (Trig.heals, Eff.cleanse) => fx.to == To.healed,
      // Batch E-1P (decisions-log 211): a skill cast's might on the troop that cast it (Rune Gauntlet); the `always`
      // range, defence, walk speed and MP regen above (Hawk Feather, Stone Coat, Moonwell) and the weaken a blow puts on
      // the monster it hit (Witherroot's `dealt`); the rest are today's powers and cuts on new conditions.
      (Trig.cast, Eff.status) => fx.to == To.self && fx.status == Status.might,
      // Batch E-2P (decisions-log 214): an attack's one-hit mark that another type spends (Ember Brand), a taunt an
      // attack puts on the monsters near its holder (Warden's Horn, above), a kill's burst on the monsters near the dead
      // one (Funeral Pyre), a strip of the monster that hit the troop (Null Stone), a fall's might on the troops near
      // (Fallen Flag), a wave-long stand against shoves (Anchor; its walk speed is the `always` speed above) and a
      // skill cast's shield (Aegis Seal).
      (Trig.attack, Eff.mark) => fx.to == To.foeHit,
      (Trig.kill, Eff.burst) => fx.to == To.nearFoes,
      (Trig.hurtBy, Eff.strip) => fx.to == To.attacker,
      (Trig.fell, Eff.status) => fx.to == To.nearTroops && (fx.status == Status.might || fx.status == Status.cap), // a cap: Soul Shelter's (G-2)
      (Trig.waveStart, Eff.status) => fx.to == To.self && (fx.status == Status.noShove || fx.status == Status.reflect),
      (Trig.cast, Eff.ward) => fx.to == To.self,
      // Batch E-3P (decisions-log 223): a healer's heal that also gives the troop healed MP or a might, or heals the troops
      // next to it (Mana Hymn, Brave Song, Halo Lantern); a heal a low troop of the type gets that lands bigger (Mercy
      // Lily: `heals` on itself); a heal at a won wave's end (Hearth); a skill cast that heals or cleanses the troops near
      // (Bright Spring, Saint's Tear); an attack's heal on the troops near (Heartbeat).
      (Trig.heals, Eff.mp) => fx.to == To.healed,
      (Trig.heals, Eff.status) => fx.to == To.healed && fx.status == Status.might,
      (Trig.heals, Eff.heal) => fx.to == To.nearTroops || (fx.to == To.self && (fx.when == If.hpBelow || fx.when == null)),
      (Trig.waveEnd, Eff.heal) => fx.to == To.self,
      (Trig.cast, Eff.heal) || (Trig.cast, Eff.cleanse) => fx.to == To.nearTroops,
      (Trig.attack, Eff.heal) => fx.to == To.nearTroops,
      // Batch G-1P (decisions-log 231): the worn small relics' work × (Relic Altar), no skill cast (Vow of Silence; its HP
      // and attack are the `always` hpDmg above, Wide Blows' splash the `always` splash), a fall's burst on the monsters
      // near (Martyr's Flame), every few blows on it one that misses (Ghost Step: a `struck` block); the rest are a
      // wave-long reflect (Mirror Shield, above), a hold an attack puts on the monster it hits (Ice Grip, above), a mark
      // on the monster that hurt it (Vengeance Mark, above; its trade a `struck` cut under 0) and powers on new
      // conditions (Lone Wolf Pelt, Champion's Mantle).
      (Trig.always, Eff.relicK) || (Trig.always, Eff.skillGate) => fx.to == To.type,
      (Trig.fell, Eff.burst) => fx.to == To.nearFoes,
      (Trig.struck, Eff.status) => fx.to == To.self && fx.status == Status.block,
      // Batch G-2 (decisions-log 238): a link an attack puts on the troops near (Guardian Chain: Shared Wounds' link, to
      // its holder), a cap at 0 a fall puts on the troops near on the type's cooldown (Soul Shelter), a fallen troop back
      // (Phoenix Plume: Resurrection's way), a skill cast's MP to the troops near (Mana Font), a hex an attack puts on
      // the monster it hits (Hex Blade: Slime Hex's), a strong kill's might on the whole type (Glory Seeker); the rest
      // are a power while low (Rage Totem, its trade the `heals` on itself under 1, above) and a cut in a crowd (Phalanx).
      (Trig.fell, Eff.revive) => fx.to == To.self,
      (Trig.cast, Eff.mp) => fx.to == To.nearTroops,
      (Trig.kill, Eff.status) => fx.to == To.type && fx.status == Status.might,
      // Batch G-3 (decisions-log 243): a healer's heal that also smites the monsters next to the troop healed (Wrath
      // Psalm); the rest are a blow's heal on the most hurt troop near (Vampire Kiss, its trade the `heals` on itself under
      // 1, above) and step 0g's noHeal on the monster hit (Grave Seal, above).
      (Trig.heals, Eff.burst) => fx.to == To.nearFoes,
      _ => false,
    };

/// The conditions the engine checks ([FxEngine._fxWhen]); each other comes with its batch. Batch L-1P's (decisions-log
/// 205): [If.vsBoss], [If.foeShielded], [If.melee] and [If.holds]; batch L-2P's (decisions-log 207): [If.attackerMelee];
/// batch L-3's (decisions-log 209): [If.healPastFull]; batch E-1P's (decisions-log 211): [If.foeHealer], [If.foeHeld],
/// [If.typesAlive], [If.attackerRanged] and [If.hero]; batch G-1P's (decisions-log 231): [If.fewOfType] and [If.notHero];
/// batch G-2's (decisions-log 238): [If.foeHighElite].
const fxIfsBuilt = {
  If.hpBelow, If.hpAbove, If.foeHpBelow, If.foeHpAbove, If.alliesNear, If.firstOfTypeThisWave, //
  If.vsBoss, If.foeShielded, If.melee, If.holds, If.attackerMelee, If.healPastFull, //
  If.foeHealer, If.foeHeld, If.typesAlive, If.attackerRanged, If.hero, //
  If.fewOfType, If.notHero, If.foeHighElite,
};

/// An Fx the engine (or a template) doesn't run yet: a row came before its batch.
StateError _unbuilt(Fx fx) => StateError('Fx ${fx.on.name} → ${fx.eff.name}${fx.when == null ? '' : ' [${fx.when!.name}]'} '
    '(${fx.stat?.name ?? fx.status?.name ?? fx.to.name}) is not built yet: it comes with its data batch');

/// The statuses a mark Fx puts on a monster that make it take more from every troop ([Game._afterDefence]): their
/// bonus damage is the marking Pusaka's counter ([FxEngine._fxCounters]). Void Eye's, Vengeance Mark's (batch G-1P).
const _takenMarks = {Status.voidMark, Status.pusakaMark};

/// Each Pusaka that marks with a [_takenMarks] status, with it, in [Relic] order.
final fxMarks = [
  for (final MapEntry(key: r, value: a) in pusakaCatalog.entries)
    for (final fx in a.fx)
      if (fx.eff == Eff.status && _takenMarks.contains(fx.status)) (fx.status!, r),
];

/// What a Pusaka's wave counter ([PusakaTally]) counts, by its first Fx's effect: damage (or heal) it [added], damage it
/// [keptOff] (a cut's, a cap's, a shield's soak; what a link took for the troops near, what a fall's shelter kept off;
/// the monster heals a noHeal stopped: Grave Seal),
/// HP it [healed] (a heal's, a regen's), deadly blows it [saves] (and how many of those troops lived on; the fallen it
/// brought back: Phoenix Plume), blows its troops [survived] that would have felled them without it, the times it
/// [applied] a status that adds no damage of its own (a slow, a weaken, a taunt, a strip, a cleanse's bad effects ended,
/// a might a skill gave: its uses, no worth; and the attacks a range made from past the old one), the MP it gave ([mana])
/// or the gold it brought ([gold]).
enum FxFamily { added, keptOff, healed, saves, survived, applied, mana, gold }

/// [relic]'s counter family ([FxFamily]); null: none (an oath, a small relic).
FxFamily? fxFamily(Relic relic) => switch (pusakaCatalog[relic]?.fx.firstOrNull) {
      null => null,
      Fx(eff: Eff.save) => FxFamily.saves,
      Fx(eff: Eff.stat, stat: Stat.hp) => FxFamily.survived,
      Fx(eff: Eff.stat, stat: Stat.regen) => FxFamily.healed, // Living Moss
      Fx(eff: Eff.stat, stat: Stat.def) => FxFamily.keptOff, // Stone Coat: what its defence kept off
      Fx(eff: Eff.stat, stat: Stat.mpRegen) => FxFamily.mana, // Moonwell: the MP its quicker regen gave
      Fx(eff: Eff.stat, stat: Stat.range) => FxFamily.applied, // Hawk Feather: its attacks from past its old range
      Fx(eff: Eff.cleanse) => FxFamily.applied, // Salt Charm, Pure Water
      Fx(eff: Eff.cut || Eff.cap || Eff.ward) => FxFamily.keptOff,
      Fx(eff: Eff.heal) => FxFamily.healed,
      Fx(eff: Eff.mp) => FxFamily.mana,
      Fx(eff: Eff.gold) => FxFamily.gold,
      Fx(eff: Eff.strip) => FxFamily.applied,
      Fx(eff: Eff.status, status: Status.bleed) => FxFamily.added, // the bleed it adds
      Fx(eff: Eff.status, status: Status.block) => FxFamily.keptOff, // Ghost Step: the blows that missed
      Fx(eff: Eff.status, status: Status.reflect) => FxFamily.added, // Mirror Shield: what it sent back
      Fx(eff: Eff.status, status: Status.link || Status.cap) => FxFamily.keptOff, // Guardian Chain, Soul Shelter: what it kept off the troops near
      Fx(eff: Eff.revive) => FxFamily.saves, // Phoenix Plume: the troops it brought back
      Fx(eff: Eff.noHeal) => FxFamily.keptOff, // Grave Seal: the monster heals it stopped
      Fx(eff: Eff.status, :final status) when !_takenMarks.contains(status) => FxFamily.applied,
      _ => FxFamily.added,
    };

/// The Pusaka whose first Fx raises its type's max HP (Dragon Heart; Vow of Silence, with its attack): the HP cell's
/// tooltip names it ([Game.hpInfo]).
bool fxRaisesHp(Relic relic) => switch (pusakaCatalog[relic]?.fx.firstOrNull) {
      Fx(on: Trig.always, eff: Eff.stat, stat: Stat.hp || Stat.hpDmg) => true,
      _ => false,
    };

// The words: one template per (trigger, effect), in the item text's simple English (decisions-log 168; ui-hud.md
// "In-game text"), from the row's own numbers.

/// What Pusaka [relic] (not an oath) does at [stars] and [ukir] steps, in the book's words ([Game.relicEffect]): each
/// Fx's lines.
List<String> fxLines(Relic relic, int stars, {int ukir = 0}) {
  final fx = pusakaCatalog[relic]!.fx;
  return [for (var i = 0; i < fx.length; i++) ..._fxLines(relic, stars, ukir, i, fx[i])];
}

/// The first sentence of an effect's [lines] ([Game.relicEffect]) on one line: a card cuts a long sentence where it
/// will, so a line that starts with a small letter, a sign or a digit ("within 2 tiles …", "-20% walk speed …") goes on
/// the one before; one with a capital starts the next sentence. The Bag's detail says it ("When one dies, all troops
/// within 2 tiles heal 10% max HP", not "When one dies, all troops").
String firstSentence(List<String> lines) {
  final out = [lines.first];
  for (final line in lines.skip(1)) {
    if (!RegExp(r'^[a-z0-9+\-]').hasMatch(line)) break;
    out.add(line);
  }
  return out.join(' ');
}

List<String> _fxLines(Relic r, int stars, int ukir, int i, Fx fx) {
  String share(double s) => '${(s * 100).round()}%';
  double k({bool boss = false}) => pusakaAt(r, stars, boss: boss, fx: i, ukir: ukir);
  int n() => fx.count.isEmpty ? 0 : pusakaCountAt(r, stars, fx: i);
  return switch ((fx.on, fx.eff)) {
    // Batch G-3's (decisions-log 243). Their trades read on from the line before ([firstSentence]): Vampire Kiss's heals
    // (Rage Totem's line below), Wrath Psalm's and Grave Seal's attack or heal.
    (Trig.dealt, Eff.heal) when fx.to == To.mostHurtNear => [
        '${share(k())} of its damage heals the most',
        'hurt other troop within ${_count(fx.r / tile, 'tile')}',
      ],
    (Trig.heals, Eff.burst) => [
        'Its heals also strike monsters',
        '${_near(fx.r)} the troop healed: ${share(k())}',
        'of the heal, at most every ${_num(fx.cd)}s',
      ],
    // Batch G-2's (decisions-log 238). Their trades read on from the line before ([firstSentence]): the attack, max HP
    // and MP regen ones below, Rage Totem's heals here; a cooldown says "at most once every" on its own line, so the trade
    // still reads on.
    (Trig.attack, Eff.power) when fx.when == If.hpBelow => ['Under ${share(fx.ifK)} HP: ${_pct(k())} damage'],
    (Trig.heals, Eff.heal) when fx.to == To.self && fx.when == null => ['but heals on it ${_pct(k())}'], // a trade: under 1
    (Trig.attack, Eff.status) when fx.status == Status.link => [
        'Every ${_nth(fx.every)} hit, for ${_num(fx.time)}s: it takes',
        '${share(k())} of the damage on troops of',
        'other types within ${_count(fx.r / tile, 'tile')}',
      ],
    (Trig.struck, Eff.cut) when fx.when == If.alliesNear => [
        '${_num(fx.ifK)} or more troops within',
        '${_count(fx.ifR / tile, 'tile')}: ${_pct(1 - k())} damage taken',
      ],
    (Trig.fell, Eff.revive) => ["Once a wave, the type's first", 'to die (not a Hero) comes back', 'after ${_num(fx.time)}s at ${share(k())} HP'],
    (Trig.fell, Eff.status) when fx.status == Status.cap => [
        'When one dies: troops within',
        '${_count(fx.r / tile, 'tile')} take no damage for ${_num(k())}s,', // a cap at 0's k is its time
        'at most once every ${_num(fx.cd)}s',
      ],
    (Trig.cast, Eff.mp) => [
        'After it uses a ${fxWords.skill}: other',
        'troops within ${_count(fx.r / tile, 'tile')} get',
        '${share(k())} of their max ${fxWords.mp}',
      ],
    (Trig.attack, Eff.status) when fx.status == Status.hex => [
        'Every ${_nth(fx.every)} hit turns the monster',
        'into a slime for ${_num(k())}s (no bosses),', // a hex's k is its time
        'at most once every ${_num(fx.cd)}s',
      ],
    (Trig.kill, Eff.status) when fx.status == Status.might => [
        'When it kills a gold monster',
        'or a boss: this type ${_pct(k())}',
        'damage for ${_num(fx.time)}s',
      ],
    // Batch G-1P's (decisions-log 231). A Legenda's cost reads on from the line before ([firstSentence]): the trades
    // (Wide Blows', Mirror Shield's, Ghost Step's, Ice Grip's attack; Martyr's Flame's and Relic Altar's max HP) are the
    // templates below, the others start with "but" here.
    (Trig.attack, Eff.power) when fx.when == If.fewOfType => ['While ${_num(fx.ifK)} or fewer of this type live:', '${_pct(k())} damage'],
    (Trig.attack, Eff.power) when fx.when == If.hero => ["This type's Heroes: ${_pct(k())} damage"],
    (Trig.attack, Eff.power) when fx.when == If.notHero => ['but the others: ${_pct(k())} damage'],
    (Trig.fell, Eff.burst) => ['When one dies: monsters within', '${_count(fx.r / tile, 'tile')} take ${share(k())} of its max HP'],
    (Trig.always, Eff.stat) when fx.stat == Stat.splash => ['Every hit also hits monsters', '${_near(k())} the target'],
    (Trig.always, Eff.stat) when fx.stat == Stat.hpDmg => ['${_pct(k())} HP and attack'],
    (Trig.always, Eff.skillGate) => ['but it never uses ${fxWords.skill}s'],
    (Trig.always, Eff.relicK) => ['Relics on this type work ${_pct(k())}'],
    (Trig.hurtBy, Eff.status) when fx.status == Status.pusakaMark => [
        'A monster that hits it takes',
        '${_pct(k())} damage for ${_num(fx.time)}s (boss ${_pct(k(boss: true))})',
      ],
    (Trig.struck, Eff.cut) when fx.when == null && fx.k.first < 0 => ['but it takes ${_pct(1 - k())} damage'], // a cut under 0
    (Trig.waveStart, Eff.status) when fx.status == Status.reflect => ['Monsters that hit it up close', 'take ${share(k())} of the hit back'],
    (Trig.struck, Eff.status) when fx.status == Status.block => ['Every ${_nth(fx.every)} hit on it misses'],
    (Trig.attack, Eff.status) when fx.status == Status.impaled => [
        'Every ${_nth(fx.every)} hit holds the monster',
        'for ${_num(k())}s (bosses: ${_pct(k(boss: true))} speed)',
      ],
    // Batch E-3P's (decisions-log 223).
    (Trig.heals, Eff.mp) => ['Its heals also give ${_share1(k())} max ${fxWords.mp}'],
    (Trig.cast, Eff.cleanse) => [
        'After it uses a ${fxWords.skill}: it and troops',
        'within ${_count(fx.r / tile, 'tile')} lose their bad effects',
        'Every ${_num(k())}s at most', // a cleanse's k is its cooldown
      ],
    (Trig.heals, Eff.status) when fx.status == Status.might => ['Troops it heals: ${_pct(k())} damage', 'for ${_num(fx.time)}s'],
    (Trig.heals, Eff.heal) when fx.to == To.nearTroops => [
        'Its heals also heal ${_count(n(), 'troop')}',
        'next to that one, ${share(k())} as much',
      ],
    (Trig.waveEnd, Eff.heal) => ['At wave end: heals it', 'up to ${share(min(1.0, k()))} of its max HP'], // a carved ★3 stops at full
    (Trig.attack, Eff.heal) => ['Every ${_nth(fx.every)} hit: troops within', '${_count(fx.r / tile, 'tile')} heal ${_share1(k())} max HP'],
    (Trig.heals, Eff.heal) when fx.to == To.self && fx.when == If.hpBelow => ['Under ${share(fx.ifK)} HP: ${_pct(k())} heal on it'],
    (Trig.cast, Eff.heal) => [
        'After it uses a ${fxWords.skill}: it and troops',
        'within ${_count(fx.r / tile, 'tile')} heal ${_share1(k())} max HP',
      ],
    // Batch E-2P's (decisions-log 214). Anchor's trade is Stone Coat's walk speed line below.
    (Trig.attack, Eff.mark) => [
        'Every ${_nth(fx.every)} hit marks the monster',
        'for ${_num(fx.time)}s: the next hit on it from',
        'another type does x${_x(k())} damage',
      ],
    (Trig.kill, Eff.burst) => [
        'When it kills, monsters ${_near(fx.r)}',
        'the one it killed take ${share(k())} of that hit',
        'Every ${_num(fx.cd)}s at most',
      ],
    (Trig.hurtBy, Eff.strip) => [
        'When a monster hits it, that monster',
        'loses its good effects (bosses: half time)',
        'Every ${_num(k())}s at most', // a strip's k is its cooldown
      ],
    (Trig.attack, Eff.status) when fx.status == Status.taunt && fx.to == To.nearFoes => [
        'Every ${_nth(fx.every)} up-close hit: monsters',
        'within ${_count(fx.r / tile, 'tile')} must fight it for ${_num(k())}s',
        '${k(boss: true) > 0 ? '' : 'Not the boss. '}Every ${_num(fx.cd)}s at most',
      ],
    (Trig.fell, Eff.status) when fx.status == Status.might => [
        'When one dies, troops within ${_count(fx.r / tile, 'tile')}',
        'get ${_pct(k())} damage for ${_num(fx.time)}s',
      ],
    (Trig.waveStart, Eff.status) when fx.status == Status.noShove => ["Monsters can't push it back"],
    (Trig.cast, Eff.ward) => ['After it uses a ${fxWords.skill}:', 'a shield of ${share(min(wardMax, k()))} max HP'], // a carved ★3 stops at the most
    // Batch E-1P's (decisions-log 211). A trade (k under 1: Hawk Feather's attack, Stone Coat's walk speed, Moonwell's
    // max HP) reads on from the line before ([firstSentence]), as Living Moss's does.
    (Trig.attack, Eff.power) when fx.when == If.foeHealer => ['${_pct(k())} damage to monster healers'],
    (Trig.attack, Eff.power) when fx.when == If.foeHeld => ['${_pct(k())} damage to a monster', 'that is slowed, held, stunned or hexed'],
    (Trig.attack, Eff.power) when fx.when == If.typesAlive => ['${_num(fx.ifK)} or more types alive:', '${_pct(k())} damage'],
    (Trig.cast, Eff.status) when fx.status == Status.might => ['After it uses a ${fxWords.skill}:', '${_pct(k())} damage for ${_num(fx.time)}s'],
    (Trig.always, Eff.stat) when fx.stat == Stat.range => ['${_pct(k())} range'],
    (Trig.always, Eff.stat) when fx.stat == Stat.def => ['-${_x(k())} damage taken per hit'],
    (Trig.always, Eff.stat) when fx.stat == Stat.speed => ['${k() < 1 ? 'but ' : ''}${_pct(k())} walk speed'],
    (Trig.always, Eff.stat) when fx.stat == Stat.mpRegen => [
        k() < 1 ? 'but its ${fxWords.mp} comes back ${share(1 - k())} slower' : '${fxWords.mp} comes back ${share(k() - 1)} faster',
      ], // under 1: a trade (Mana Font's)
    (Trig.dealt, Eff.status) when fx.status == Status.weaken => [
        'Monsters it hits deal ${_pct(k())} damage',
        'for ${_num(fx.time)}s (boss ${_pct(k(boss: true))})',
      ],
    (Trig.struck, Eff.cut) when fx.when == If.attackerRanged => ['${_pct(1 - k())} damage taken', 'from monsters that shoot'],
    (Trig.struck, Eff.cut) when fx.when == If.hero => ["This type's Hero: ${_pct(1 - k())} damage taken"],
    // Batch L-3's (decisions-log 209).
    (Trig.kill, Eff.heal) => ['Each kill heals it ${share(k())} max HP'],
    (Trig.heals, Eff.ward) when fx.when == If.healPastFull => [
        'Its heals past full HP:',
        '${share(k())} of that becomes a shield',
        'up to ${share(min(wardMax, fx.cap))} max HP',
      ],
    (Trig.struck, Eff.heal) when fx.when == If.hpBelow => ['Once a wave, under ${share(fx.ifK)} HP:', 'heals ${share(k())} max HP'],
    (Trig.always, Eff.stat) when fx.stat == Stat.regen => ['Heals ${_share1(k())} max HP every second'],
    (Trig.heals, Eff.cleanse) => [
        'Its heals also clear ${_count(n(), 'bad effect')}',
        'Every ${_num(k())}s at most', // a cleanse's k is its cooldown
      ],
    // Batch L-2P's (decisions-log 207).
    (Trig.kill, Eff.power) => ['After a kill: next hit x${_x(k())} damage'],
    (Trig.attack, Eff.status) when fx.status == Status.bleed => [
        'Every ${_nth(fx.every)} hit: the monster bleeds',
        '${share(k())} of that hit over ${_num(fx.time)}s',
      ],
    (Trig.landed, Eff.burst) => ['Every ${_nth(fx.every)} hit: monsters ${_near(fx.r)}', 'the target take ${share(k())} of it'],
    (Trig.struck, Eff.mp) => ['When hit: +${_share1(k())} max ${fxWords.mp}', 'Every ${_num(fx.cd)}s at most'],
    (Trig.waveStart, Eff.ward) => ['Each wave starts with a shield', 'of ${share(min(wardMax, k()))} max HP'], // a carved ★3 stops at the most
    (Trig.kill, Eff.ward) => ['Each kill: +${share(k())} max HP shield', 'up to ${share(_wardMost(k(), fx, r, stars, i))}'],
    (Trig.hurtBy, Eff.burst) when fx.when == If.attackerMelee => [
        'Every ${_nth(fx.every)} up-close hit on it:',
        'hits back for ${share(k())} of its attack',
      ],
    (Trig.attack, Eff.mp) => ['Every ${_nth(fx.every)} hit: +${_share1(k())} max ${fxWords.mp}'],
    (Trig.kill, Eff.gold) => ['Monsters it kills give ${_pct(k())} gold'],
    (Trig.attack, Eff.strip) => [
        'Every ${_nth(fx.every)} hit: the monster loses',
        '1 good effect (bosses: half its time)',
        'Every ${_num(k())}s at most', // a strip's k is its cooldown
      ],
    (Trig.always, Eff.stat) when fx.stat == Stat.hp => [
        '${k() < 1 ? 'but ' : ''}${_pct(k())} max HP',
        if (fx.regen > 0) 'Heals ${share(fx.regen)} max HP every second',
      ],
    // A trade (k under 1: Living Moss's) is the cost of the line before, so it reads on from it ([firstSentence]).
    (Trig.always, Eff.stat) when fx.stat == Stat.dmg => ['${k() < 1 ? 'but ' : ''}${_pct(k())} attack or heal'],
    (Trig.attack, Eff.power) when fx.when == If.foeShielded => ['${_pct(k())} damage to a monster with a shield'],
    (Trig.attack, Eff.power) when fx.when == If.holds && fx.ifRelic == Relic.fury => [
        'With ${relicNames[Relic.fury]}: its x$furyHit hit',
        'does x${_x(k())} more',
      ],
    (Trig.attack, Eff.power) when fx.when == null => ['x${_x(k())} damage every ${_nth(fx.every)} hit'],
    (Trig.pierce, Eff.power) when fx.when == If.vsBoss => ['${_pct(k())} damage to the boss and mini boss'],
    (Trig.pierce, Eff.power) when fx.when == If.foeHpBelow => ['${_pct(k())} damage to monsters under ${share(fx.ifK)} HP'],
    (Trig.pierce, Eff.power) when fx.when == If.foeHpAbove => ['${_pct(k())} damage to monsters over ${share(fx.ifK)} HP'],
    (Trig.attack, Eff.status) when fx.status == Status.slow && fx.when == null => [
        'Every ${_nth(fx.every)} hit: the monster',
        '${_pct(k())} walk speed for ${_num(fx.time)}s (boss ${_pct(k(boss: true))})',
      ],
    (Trig.attack, Eff.status) when fx.status == Status.taunt && fx.when == If.melee => [
        'Every ${_nth(fx.every)} up-close hit: the monster',
        'must fight it for ${_num(k())}s (boss ${_num(k(boss: true))}s)',
      ],
    (Trig.hurtBy, Eff.status) when fx.status == Status.weaken => [
        'When hit: that monster deals',
        '${_pct(k())} damage for ${_num(fx.time)}s (boss ${_pct(k(boss: true))})',
      ],
    (Trig.landed, Eff.leap) => [
        'Each hit also hits ${pusakaCountAt(r, stars, fx: i)} more monsters',
        'within ${_count(fx.r / tile, 'tile')}, for ${share(k())} damage',
      ],
    (Trig.struck, Eff.cut) when fx.when == If.hpAbove => ['Over ${share(fx.ifK)} HP: ${_pct(1 - k())} damage taken'],
    (Trig.struck, Eff.cut) when fx.when == If.hpBelow => ['Under ${share(fx.ifK)} HP: ${_pct(1 - k())} damage taken'],
    (Trig.struck, Eff.cut) when fx.when == null => ['${_pct(1 - k())} damage taken'],
    (Trig.capped, Eff.cap) => ['No hit takes over ${share(k())} max HP'],
    (Trig.dealt, Eff.heal) => ['Heals ${share(k())} of damage dealt'],
    (Trig.dealt, Eff.status) when fx.status == Status.voidMark => [
        'Marks monsters it hits for ${_num(fx.time)}s',
        'Marked: ${_pct(k())} damage taken (boss ${_pct(k(boss: true))})',
      ],
    (Trig.lethal, Eff.save) => ['Once a wave: survive 1 deadly hit', 'Left at ${share(k())} HP, no damage for ${_num(fx.time)}s'],
    (Trig.fell, Eff.heal) => ['When one dies, all troops', 'within ${_count(fx.r / tile, 'tile')} heal ${share(k())} max HP'],
    (Trig.struck, Eff.cleanse) => [
        _cleansed('When hit', n()),
        if (fx.cdByStars) 'Every ${_num(k())}s at most', // its k is its cooldown (Salt Charm's)
      ],
    (Trig.dealt, Eff.noHeal) => ["Monsters it hits can't heal for ${_num(k())}s"], // a noHeal's k is its time
    _ => throw _unbuilt(fx),
  };
}

/// A `cleanse` Fx's words: after [when], how many bad effects it clears ([n], its [Fx.count]; 0, none given: all).
String _cleansed(String when, int n) => '$when: clears ${n == 0 ? 'its bad effects' : _count(n, 'bad effect')}';

/// A share in percent to one decimal at most, without ".0": 0.03 → "3%", 0.045 → "4.5%" (an MP Fx's).
String _share1(double s) => '${_num((s * 1000).round() / 10)}%';

/// The monsters a reach of [r] px takes in, after "monsters": "next to" (a tile), else "within N tiles of".
String _near(double r) => r <= tile ? 'next to' : 'within ${_count(r / tile, 'tile')} of';

/// The most shield a `ward` Fx with its add [k] at [stars] builds up: [k] × its [Fx.count] (kills' worth: Bone
/// Buckler's), never past [wardMax]; one without a count gives [k] once.
double _wardMost(double k, Fx fx, Relic r, int stars, int i) => min(wardMax, fx.count.isEmpty ? k : k * pusakaCountAt(r, stars, fx: i));

/// What Pusaka [relic] (not an oath) does at [stars] and [ukir] steps, in a few words for a Tas row ([pusakaGist]): its
/// first Fx's.
String fxGist(Relic relic, int stars, {int ukir = 0}) {
  final fx = pusakaCatalog[relic]!.fx.first;
  String share(double s) => '${(s * 100).round()}%';
  double k({bool boss = false}) => pusakaAt(relic, stars, boss: boss, ukir: ukir);
  return switch ((fx.on, fx.eff)) {
    // Batch G-3's (decisions-log 243).
    (Trig.dealt, Eff.heal) when fx.to == To.mostHurtNear => 'Hits: ${share(k())} to most hurt',
    (Trig.heals, Eff.burst) => 'Heals smite near: ${share(k())}',
    // Batch G-2's (decisions-log 238).
    (Trig.attack, Eff.power) when fx.when == If.hpBelow => 'Under ${share(fx.ifK)}: ${_pct(k())} damage',
    (Trig.attack, Eff.status) when fx.status == Status.link => 'Every ${_nth(fx.every)}: takes ${share(k())} for near',
    (Trig.struck, Eff.cut) when fx.when == If.alliesNear => '${_num(fx.ifK)}+ near: ${_pct(1 - k())} taken',
    (Trig.fell, Eff.revive) => 'First to die: back at ${share(k())}',
    (Trig.fell, Eff.status) when fx.status == Status.cap => 'Death: near safe ${_num(k())}s',
    (Trig.cast, Eff.mp) => 'Skill: near +${share(k())} ${fxWords.mp}',
    (Trig.attack, Eff.status) when fx.status == Status.hex => 'Every ${_nth(fx.every)}: slime ${_num(k())}s',
    (Trig.kill, Eff.status) when fx.status == Status.might => 'Gold kill: type ${_pct(k())}',
    // Batch G-1P's (decisions-log 231).
    (Trig.attack, Eff.power) when fx.when == If.fewOfType => '${_num(fx.ifK)} or fewer: ${_pct(k())}',
    (Trig.attack, Eff.power) when fx.when == If.hero => 'Heroes: ${_pct(k())} damage',
    (Trig.fell, Eff.burst) => 'Death: ${share(k())} HP to near',
    (Trig.always, Eff.stat) when fx.stat == Stat.splash => 'Hits splash near target',
    (Trig.always, Eff.stat) when fx.stat == Stat.hpDmg => '${_pct(k())} HP, no ${fxWords.skill}s',
    (Trig.always, Eff.relicK) => 'Relics ${_pct(k())}',
    (Trig.hurtBy, Eff.status) when fx.status == Status.pusakaMark => 'Attacker takes ${_pct(k())}',
    (Trig.waveStart, Eff.status) when fx.status == Status.reflect => 'Up close: ${share(k())} back',
    (Trig.struck, Eff.status) when fx.status == Status.block => 'Every ${_nth(fx.every)} hit misses',
    (Trig.attack, Eff.status) when fx.status == Status.impaled => 'Every ${_nth(fx.every)}: hold ${_num(k())}s',
    // Batch E-3P's (decisions-log 223).
    (Trig.heals, Eff.mp) => 'Heal: +${_share1(k())} ${fxWords.mp}',
    (Trig.cast, Eff.cleanse) => 'Skill: clears near, every ${_num(k())}s',
    (Trig.heals, Eff.status) when fx.status == Status.might => 'Heal: ${_pct(k())} damage',
    (Trig.heals, Eff.heal) when fx.to == To.nearTroops => 'Heal: ${share(k())} to ${pusakaCountAt(relic, stars)} near',
    (Trig.waveEnd, Eff.heal) => 'Wave end: up to ${share(min(1.0, k()))} HP',
    (Trig.attack, Eff.heal) => 'Every ${_nth(fx.every)}: near heal ${_share1(k())}',
    (Trig.heals, Eff.heal) when fx.to == To.self && fx.when == If.hpBelow => 'Under ${share(fx.ifK)}: ${_pct(k())} heal',
    (Trig.cast, Eff.heal) => 'Skill: near heal ${_share1(k())}',
    // Batch E-2P's (decisions-log 214).
    (Trig.attack, Eff.mark) => 'Mark: x${_x(k())} every ${_nth(fx.every)}',
    (Trig.kill, Eff.burst) => 'Kill: ${share(k())} to near',
    (Trig.hurtBy, Eff.strip) => 'Strips attacker, every ${_num(k())}s',
    (Trig.attack, Eff.status) when fx.status == Status.taunt && fx.to == To.nearFoes => 'Every ${_nth(fx.every)}: near must fight it',
    (Trig.fell, Eff.status) when fx.status == Status.might => 'Death: near ${_pct(k())} damage',
    (Trig.waveStart, Eff.status) when fx.status == Status.noShove => "Can't be pushed back",
    (Trig.cast, Eff.ward) => 'Skill: ${share(min(wardMax, k()))} HP shield',
    // Batch E-1P's (decisions-log 211).
    (Trig.attack, Eff.power) when fx.when == If.foeHealer => '${_pct(k())} vs healers',
    (Trig.attack, Eff.power) when fx.when == If.foeHeld => '${_pct(k())} vs held',
    (Trig.attack, Eff.power) when fx.when == If.typesAlive => '${_num(fx.ifK)}+ types: ${_pct(k())}',
    (Trig.cast, Eff.status) when fx.status == Status.might => 'Skill: ${_pct(k())} for ${_num(fx.time)}s',
    (Trig.always, Eff.stat) when fx.stat == Stat.range => '${_pct(k())} range',
    (Trig.always, Eff.stat) when fx.stat == Stat.def => '-${_x(k())} damage a hit',
    (Trig.always, Eff.stat) when fx.stat == Stat.mpRegen => '${fxWords.mp} ${share(k() - 1)} faster',
    (Trig.dealt, Eff.status) when fx.status == Status.weaken => 'Monsters hit: ${_pct(k())} damage',
    (Trig.struck, Eff.cut) when fx.when == If.attackerRanged => '${_pct(1 - k())} from shots',
    (Trig.struck, Eff.cut) when fx.when == If.hero => 'Hero: ${_pct(1 - k())} taken',
    // Batch L-3's (decisions-log 209).
    (Trig.kill, Eff.heal) => 'Kill: heals ${share(k())} HP',
    (Trig.heals, Eff.ward) => 'Extra heal: ${share(k())} shield',
    (Trig.struck, Eff.heal) when fx.when == If.hpBelow => 'Under ${share(fx.ifK)}: heals ${share(k())}',
    (Trig.always, Eff.stat) when fx.stat == Stat.regen => 'Heals ${_share1(k())} HP a second',
    (Trig.heals, Eff.cleanse) => 'Heal clears 1, every ${_num(k())}s',
    // Batch L-2P's (decisions-log 207).
    (Trig.kill, Eff.power) => 'Kill: next hit x${_x(k())}',
    (Trig.attack, Eff.status) when fx.status == Status.bleed => 'Bleed ${share(k())} every ${_nth(fx.every)}',
    (Trig.landed, Eff.burst) => '${share(k())} to near, every ${_nth(fx.every)}',
    (Trig.struck, Eff.mp) => 'Hit: +${_share1(k())} ${fxWords.mp}',
    (Trig.waveStart, Eff.ward) => 'Wave shield ${share(min(wardMax, k()))} HP',
    (Trig.kill, Eff.ward) => 'Kill: +${share(k())} shield, max ${share(_wardMost(k(), fx, relic, stars, 0))}',
    (Trig.hurtBy, Eff.burst) => 'Hits back ${share(k())}, every ${_nth(fx.every)}',
    (Trig.attack, Eff.mp) => '+${_share1(k())} ${fxWords.mp} every ${_nth(fx.every)}',
    (Trig.kill, Eff.gold) => '${_pct(k())} kill gold',
    (Trig.attack, Eff.strip) => 'Strips 1 every ${_nth(fx.every)}',
    (Trig.always, Eff.stat) when fx.stat == Stat.hp => '${_pct(k())} max HP',
    (Trig.always, Eff.stat) when fx.stat == Stat.dmg => '${_pct(k())} attack',
    (Trig.attack, Eff.power) when fx.when == If.foeShielded => '${_pct(k())} vs shields',
    (Trig.attack, Eff.power) when fx.when == If.holds && fx.ifRelic == Relic.fury => '${relicNames[Relic.fury]} hit x${_x(k())}',
    (Trig.attack, Eff.power) when fx.when == null => 'x${_x(k())} every ${_nth(fx.every)} hit',
    (Trig.pierce, Eff.power) when fx.when == If.vsBoss => '${_pct(k())} vs boss',
    (Trig.pierce, Eff.power) when fx.when == If.foeHpBelow => '${_pct(k())} under ${share(fx.ifK)} HP',
    (Trig.pierce, Eff.power) when fx.when == If.foeHpAbove => '${_pct(k())} over ${share(fx.ifK)} HP',
    (Trig.attack, Eff.status) when fx.status == Status.slow => '${_pct(k())} speed every ${_nth(fx.every)}',
    (Trig.attack, Eff.status) when fx.status == Status.taunt => 'Every ${_nth(fx.every)}: must fight it ${_num(k())}s',
    (Trig.hurtBy, Eff.status) when fx.status == Status.weaken => 'Attacker ${_pct(k())} damage',
    (Trig.landed, Eff.leap) => 'Hits ${pusakaCountAt(relic, stars)} more, ${share(k())}',
    (Trig.struck, Eff.cut) when fx.when == If.hpAbove => 'Over ${share(fx.ifK)}: ${_pct(1 - k())} taken',
    (Trig.struck, Eff.cut) when fx.when == If.hpBelow => 'Under ${share(fx.ifK)}: ${_pct(1 - k())} taken',
    (Trig.struck, Eff.cut) when fx.when == null => '${_pct(1 - k())} damage taken',
    (Trig.capped, Eff.cap) => 'Max ${share(k())} HP a hit',
    (Trig.dealt, Eff.heal) => 'Heals ${share(k())} of damage',
    (Trig.dealt, Eff.status) when fx.status == Status.voidMark => 'Mark: ${_pct(k())} (boss ${_pct(k(boss: true))})',
    (Trig.lethal, Eff.save) => 'Lives 1 deadly hit a wave',
    (Trig.fell, Eff.heal) => 'Death heals near troops ${share(k())}',
    (Trig.struck, Eff.cleanse) => _cleansed('Hit', fx.count.isEmpty ? 0 : pusakaCountAt(relic, stars)),
    (Trig.dealt, Eff.noHeal) => 'Hit: no heals ${_num(k())}s',
    _ => throw _unbuilt(fx),
  };
}

// The band (anti-creep, catalog-design §2.4): what one Fx may give, by what it gives and its rarity, at ★1 / ★2 / ★3:
// today's ranges. pusaka_catalog_test.dart fails a row outside its band.

/// What an Fx's gain is measured against ([fxBand]).
enum Band {
  /// The mean damage added a hit: (k − 1) / every (War Drum; Dawn Star's attack).
  power,

  /// Max HP added: k − 1 (Dragon Heart).
  hp,

  /// Damage taken cut: k (Iron Banner).
  cut,

  /// HP healed, a share of the damage dealt (Blood Fang).
  healDealt,

  /// HP healed, a share of max HP an event (Mourning Bell).
  healMaxHp,

  /// Heal output added: k − 1 (Dawn Star on a healer).
  healOutput,

  /// Damage taken added by a mark: k − 1 (Void Eye).
  mark,

  /// Leap damage a hit: share × leaps (God's Thunder).
  leap,

  /// HP left after a deadly blow (the Grail).
  save,

  /// A shield, a share of max HP ([wardMax]).
  ward,
}

/// The band: by [Band] and rarity, the most an Fx gives at ★1 / ★2 / ★3 (the design's numbers, two decimals). A
/// Legenda has none: a rule and a real cost instead.
const fxBand = <Band, Map<Rarity, List<double>>>{
  Band.power: {Rarity.langka: [0.17, 0.25, 0.33], Rarity.epik: [0.30, 0.45, 0.60]},
  Band.hp: {Rarity.epik: [0.6, 1.2, 2.0]},
  Band.cut: {Rarity.langka: [0.15, 0.20, 0.25], Rarity.epik: [0.20, 0.25, 0.30]},
  Band.healDealt: {Rarity.langka: [0.10, 0.15, 0.20]},
  // An Epik heal of max HP an event (batch E-3P's Heartbeat and Bright Spring, decisions-log 223) no bigger than the
  // Langka's (Mourning Bell's): catalog-design §2.4 names no Epik one.
  Band.healMaxHp: {Rarity.langka: [0.20, 0.25, 0.30], Rarity.epik: [0.20, 0.25, 0.30]},
  Band.healOutput: {Rarity.epik: [0.30, 0.45, 0.60]},
  Band.mark: {Rarity.epik: [0.25, 0.35, 0.45]},
  Band.leap: {Rarity.epik: [0.8, 1.2, 1.6]},
  Band.save: {Rarity.epik: [0.3, 0.4, 0.5]},
  Band.ward: {Rarity.langka: [wardMax, wardMax, wardMax], Rarity.epik: [wardMax, wardMax, wardMax]},
};

/// The biggest shield an Fx may give, a share of max HP (one value for every rarity).
const wardMax = 0.20;

/// A hold an Fx puts on a monster ([Status.impaled], Ice Grip's): its walking speed × this, so it can't walk; it still
/// attacks and casts, as under Impale's pin.
const fxHoldWalk = 0.0;

/// A condition, or a trade (a second Fx with k under 1), lets an Fx go this much past its band.
const condBonus = 1.25, tradeBonus = 1.25;

/// The conditions that earn no [condBonus]: the slot waves hold most of the falls (0.58-0.92), so they barely narrow.
const hardConds = {If.vsBoss, If.attackerVsBoss, If.hero, If.typesAlive};

/// An every-Nth power Fx's k at ★1 / ★2 / ★3 is at most War Drum's, and so is a kill's one charge (Momentum's) and an
/// every-Nth one-hit mark's (Ember Brand's).
const perProcMax = [1.5, 1.75, 2.0];

/// What no band measures (each gets a probe arm in its batch instead): these stats, statuses and effects.
const fxBandExempt = (
  stats: {Stat.range, Stat.def, Stat.mp, Stat.mpRegen, Stat.splash, Stat.regen}, // regen: Living Moss's (batch L-3)
  statuses: {Status.slow, Status.impaled, Status.hex, Status.taunt, Status.noShove, Status.reflect, Status.link, Status.block},
  effs: {Eff.strip, Eff.cleanse, Eff.gold, Eff.revive, Eff.relicK, Eff.skillGate, Eff.mp, Eff.cooldown, Eff.roster},
);

/// The [Band] [fx] is measured against, and its gain at [k] (its number at a star) and [count] (its whole number):
/// null when no band measures it ([fxBandExempt], a cap, a trade's own line with k under 1).
(Band, double)? fxGain(Fx fx, double k, int count) {
  if (fxBandExempt.effs.contains(fx.eff) || fxBandExempt.stats.contains(fx.stat) || fxBandExempt.statuses.contains(fx.status)) return null;
  return switch (fx.eff) {
    Eff.power when fx.on == Trig.kill => null, // one charge a kill (Momentum): a proc, at most War Drum's ([perProcMax])
    Eff.power => (Band.power, (k - 1) / max(1, fx.every)),
    Eff.status when fx.status == Status.bleed => (Band.power, k / max(1, fx.every)), // the bleed's share of a hit, a hit
    // A kill's burst (Funeral Pyre): one a kill at most, on its own cooldown, a proc no per-hit band measures (its share
    // never past the hit itself; a probe arm places it).
    Eff.burst when fx.on == Trig.kill => null,
    Eff.burst => (Band.power, k / max(1, fx.every)), // its share of a hit on one monster, a hit
    Eff.stat when fx.stat == Stat.hp && k >= 1 => (Band.hp, k - 1),
    Eff.stat when fx.stat == Stat.dmg && k >= 1 => (Band.power, k - 1),
    Eff.cut => (Band.cut, k),
    Eff.heal when fx.on == Trig.dealt => (Band.healDealt, k),
    Eff.heal when fx.on == Trig.heals && fx.to == To.self => (Band.healOutput, k - 1), // a heal got, × k (Mercy Lily)
    Eff.heal when fx.on == Trig.heals => (Band.healOutput, k * max(1, count)), // its share of a heal, to each of its troops (Halo Lantern)
    // A heal between waves (Hearth's, up to a share of max HP at a won wave's end): no fight heal any band measures, and
    // the after-wave heal fills a hurt troop anyway while a healer stands (a probe arm places it).
    Eff.heal when fx.on == Trig.waveEnd => null,
    Eff.heal => (Band.healMaxHp, k),
    Eff.status when _takenMarks.contains(fx.status) => (Band.mark, k - 1),
    Eff.status when fx.status == Status.might => (Band.power, k - 1), // a skill's might (Rune Gauntlet): its power while on
    // A one-hit mark every Nth hit that another type spends (Ember Brand): weighed as an every-Nth power, at most War
    // Drum's a proc ([perProcMax]).
    Eff.mark when fx.every > 1 => (Band.power, (k - 1) / fx.every),
    Eff.mark => (Band.mark, k - 1),
    Eff.leap => (Band.leap, k * count),
    Eff.save => (Band.save, k),
    Eff.ward => (Band.ward, fx.cap > 0 ? fx.cap : k * max(1, count)), // the most it gives: its cap (Full Cup), or [Fx.count] kills' worth (Bone Buckler)
    _ => null,
  };
}
