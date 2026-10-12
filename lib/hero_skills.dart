part of 'game.dart';

// Heroes' own skills (#48; docs/units-and-combat.md, "Hero skills"). A troop made a Hero also rolls one of its
// type's five ([heroSkillPool], with the [Game.heroes] dice after its attributes) and casts it by itself during
// a wave, like its #10 skill ([troopSkills]) but rarer and bigger: it costs MP, has a long cooldown and is ready
// again at every wave's start. What a skill leaves behind is a timed [Status] on a unit ([Unit.effects], the
// effect store); game.dart asks the store where damage, speed, targets and the like are worked out.
//
// A new skill plugs in here only: `built: true` on its [HeroSkill], a case in [HeroSkills.wantsHeroSkill] and
// [HeroSkills._castHeroSkill], its numbers as `<id>K`, and a new [Status] (with its hook) if it needs one.
// Resurrection also keeps [Unit.revived] and tells the UI through [Game.risen]; Slime Hex swaps a monster's
// stats while [Status.hex] lasts.

/// A Hero skill's icon (the nameplate, the book, the announcement): an item's or a relic's, or ui_icons.png's
/// heart, MP bolt or coin.
enum HeroMark { sword, shield, boots, bow, gloves, potion, staff, fang, thorns, fury, guard, heart, bolt, coin }

/// The 45 Hero skills, five per troop type, as the owner approved them ("setuju tapi pakai bahasa inggris": the
/// names and lines in English). Only [built] ones are rolled ([heroSkillPool]); all 45 are built (decisions-log 93).
/// [holds]: it moves, holds or redirects monsters, so it never casts while a stalled wave marches
/// ([Game.marching]). A [cooldown] of infinity is once a wave (the wave's start makes every Hero skill ready).
enum HeroSkill {
  // Soldier: the army's sergeant.
  warCry('soldier', 'War Cry', 15, 40, 'Troops nearby attack 25% faster for 6 s.', HeroMark.gloves, built: true),
  shieldBash('soldier', 'Shield Bash', 15, 30, 'A 2x shield blow that knocks a strong foe back and stuns it.', HeroMark.shield, built: true, holds: true),
  lastStand('soldier', 'Last Stand', 10, 45, 'Hurt, it stands its ground: 1.5x damage, and kills heal it.', HeroMark.fury, built: true),
  plunder('soldier', 'Plunder', 15, 40, 'For 8 s, monsters slain near it pay 50% more gold.', HeroMark.coin, built: true),
  parry('soldier', 'Parry', 15, 35, 'Blocks the next 3 melee blows and strikes back 1.5x.', HeroMark.guard, built: true),
  // Knight: the honourable protector.
  duel('knight', 'Duel of Honour', 20, 40, 'Challenges the strongest foe near: it fights only this knight.', HeroMark.sword, built: true, holds: true),
  cleave('knight', 'Cleave', 15, 25, 'One heavy 3x blow; a kill gives back half its MP.', HeroMark.sword, built: true),
  banner('knight', 'War Banner', 20, 45, 'Plants a banner: troops near it deal 20% more damage.', HeroMark.sword, built: true),
  shareWounds('knight', 'Shared Wounds', 20, 35, 'Takes half the wounds of a dying ally for 6 s.', HeroMark.heart, built: true),
  rescueLeap('knight', 'Guardian Leap', 20, 30, 'Leaps to guard the back line: a 2x blow and a stun.', HeroMark.boots, built: true, holds: true),
  // Swordsman: the killer.
  execute('swordsman', 'Execute', 15, 20, 'Slays a monster below 25% HP outright (not a boss).', HeroMark.sword, built: true),
  bloodlust('swordsman', 'Bloodlust', 20, 40, 'For 6 s, heals 40% of the damage it deals.', HeroMark.fang, built: true),
  whirlwind('swordsman', 'Whirlwind', 25, 35, 'Spins for 2 s, cutting every foe around it 4 times.', HeroMark.sword, built: true),
  deathLeap('swordsman', 'Death Leap', 20, 35, 'Leaps onto a monster healer or archer: a 2.5x blow.', HeroMark.boots, built: true),
  deepWound('swordsman', 'Deep Wound', 15, 25, 'A deep cut: the foe bleeds 4x damage over 4 s.', HeroMark.fury, built: true),
  // Archer: the marksman.
  snipe('archer', 'Snipe', 20, 30, 'Aims, then fires a 5x arrow far beyond its range.', HeroMark.bow, built: true),
  crippleShot('archer', 'Crippling Shot', 15, 25, 'A 1.5x arrow that slows the foe 50% for 5 s.', HeroMark.bow, holds: true, built: true),
  pierceShot('archer', 'Piercing Shot', 20, 30, 'One arrow through every foe in a line: 2x each.', HeroMark.bow, built: true),
  eagleEye('archer', 'Eagle Eye', 20, 40, '+40% range and +30% damage for 8 s.', HeroMark.bow, built: true),
  huntersMark('archer', 'Hunter\'s Mark', 15, 35, 'Marks a strong foe: it takes 25% more damage.', HeroMark.fury, built: true),
  // Lancer: the cavalry.
  charge('lancer', 'Cavalry Charge', 20, 35, 'Charges down its lane through every foe: 2x and a stun.', HeroMark.boots, built: true, holds: true),
  javelin('lancer', 'Javelin', 15, 25, 'Throws a spear at a distant foe: 2.5x damage.', HeroMark.sword, built: true),
  spearWall('lancer', 'Spear Wall', 15, 35, 'Holds its ground 5 s: foes coming in take 1.5x and stop.', HeroMark.shield, built: true, holds: true),
  sweep('lancer', 'Spear Sweep', 15, 25, 'A half-circle sweep that knocks the foes ahead back.', HeroMark.sword, built: true, holds: true),
  flurry('lancer', 'Flurry', 15, 25, 'Three lightning thrusts at a strong foe: 4x in all.', HeroMark.gloves, built: true),
  // Priest: the saint.
  blessing('priest', 'Blessing', 30, 40, 'Troops in reach heal 2% HP a second for 8 s.', HeroMark.potion, built: true),
  holyNova('priest', 'Holy Nova', 40, 35, 'Holy light burns every undead monster in reach.', HeroMark.staff, built: true),
  lightVeil('priest', 'Veil of Light', 25, 30, 'A veil of light soaks up damage for a badly hurt ally.', HeroMark.guard, built: true),
  revive('priest', 'Resurrection', 60, double.infinity, 'Once a wave, raises a fallen troop (not a Hero) at 30% HP.', HeroMark.heart, built: true),
  manaGift('priest', 'Gift of Mana', 30, 40, 'Gives 15 MP to every troop in reach.', HeroMark.bolt, built: true),
  // Armored axeman: the armored giant.
  giantRage('armored_axeman', 'Giant\'s Rage', 20, 45, 'Grows for 8 s: +50% max HP and a wider cleave.', HeroMark.heart, built: true),
  ironSkin('armored_axeman', 'Iron Skin', 15, 35, 'Takes 15% less damage and throws back 60% of melee blows.', HeroMark.thorns, built: true),
  axeThrow('armored_axeman', 'Axe Throw', 15, 30, 'Throws its axe out and back, hitting each foe twice.', HeroMark.sword, built: true),
  hook('armored_axeman', 'Chain Hook', 20, 35, 'Drags a monster archer or healer in and stuns it.', HeroMark.gloves, built: true, holds: true),
  quake('armored_axeman', 'Earthquake', 20, 40, 'Shakes the ground: foes around it are hurt and slowed 40%.', HeroMark.boots, built: true, holds: true),
  // Wizard: the archmage.
  chainLightning('wizard', 'Chain Lightning', 40, 30, 'Lightning that leaps through 5 foes in a row.', HeroMark.staff, built: true),
  frostStorm('wizard', 'Frost Storm', 50, 40, 'A 5 s frost storm: foes in it slow 50% and keep taking damage.', HeroMark.staff, built: true, holds: true),
  manaShield('wizard', 'Mana Shield', 20, 40, 'For 8 s, damage it takes drains its MP first.', HeroMark.bolt, built: true),
  curse('wizard', 'Curse of Weakness', 30, 35, 'Curses a strong foe: 40% less damage and slower steps.', HeroMark.staff, built: true, holds: true),
  slimeHex('wizard', 'Slime Hex', 50, 45, 'Turns a strong monster into a slime for 5 s.', HeroMark.staff, built: true, holds: true),
  // Knight templar: the paladin.
  judgement('knight_templar', 'Judgement', 25, 30, 'A holy blow: 2x, 4x against the undead.', HeroMark.sword, built: true),
  holyTaunt('knight_templar', 'Holy Taunt', 30, 40, 'Draws the monsters around to attack it, taking 25% less.', HeroMark.shield, built: true, holds: true),
  sacrifice('knight_templar', 'Sacrifice', 20, 30, 'Gives 25% of its HP to a dying ally.', HeroMark.heart, built: true),
  bastion('knight_templar', 'Bastion of Faith', 30, 45, 'For 5 s, no single blow takes more than 8% of its HP.', HeroMark.shield, built: true),
  exorcism('knight_templar', 'Exorcism', 30, 40, 'Destroys the raised skeletons around it.', HeroMark.staff, built: true);

  const HeroSkill(this.type, this.title, this.cost, this.cooldown, this.desc, this.mark, {this.built = false, this.holds = false});

  /// The troop type it belongs to; [title] its name on screen (`name` is the id the save keeps); [desc] one
  /// line saying what it does.
  final String type, title, desc;

  /// MP it costs.
  final int cost;

  /// Seconds before it can be cast again.
  final double cooldown;
  final HeroMark mark;
  final bool built, holds;
}

/// The Hero skills a Hero of [type] may roll: its [HeroSkill.built] ones, in the enum's order.
List<HeroSkill> heroSkillPool(String type) => [for (final s in HeroSkill.values) if (s.type == type && s.built) s];

/// A timed effect a Hero skill puts on a unit ([Unit.effects]), with what its strength [Effect.k] means. [base]
/// is the strength when it is absent (1 for a multiplier, 0 for a pool or share): the further from it, the
/// stronger. A [stat] one changes the troop's stats ([Game._statsFor]), so the troop is refit as it starts and
/// ends.
enum Status {
  /// The pause between attacks (and heals) ×k: 0.8 attacks 25% faster ([Game.attackEvery]).
  haste(1),

  /// Damage this unit deals ×k, before the target's defence ([Game._hurt]).
  might(1),

  /// Damage this unit deals ×k: a monster's (a Hero's curse), or a troop's (a monster's skill, #59).
  weaken(1),

  /// Damage this unit takes from the other side ×k, after its defence: a monster's from troops, a troop's from
  /// monsters (#59). A blow with no attacker (a bleed whose source fell) doesn't count.
  vulnerable(1),

  /// Range ×k.
  range(1, stat: true),

  /// Walking speed ×k ([Game._moveToward]); a marching monster ignores it.
  slow(1),

  /// Walking speed ×k, a monster's own skill's (Howl, Second Wind; boss_skills.dart): apart from [slow], so a
  /// troop's slow and a monster's speed-up each keep their own.
  swift(1),

  /// Walking speed ×k, a monster pinned by a lancer's Impale (awaken_skills.dart, #88): apart from [slow], so a pin
  /// and a slow each keep their own; [steadfast] and a march ignore it too. It still attacks and casts.
  impaled(1),

  /// The pause between attacks ×k, a monster's skill on a troop (Screech; boss_skills.dart): apart from
  /// [haste], so it doesn't undo a troop's own.
  daze(1),

  /// Each blow this monster lands on a troop takes k of its MP too (Soul Rend; boss_skills.dart).
  soulRend(0),

  /// Nothing slows this monster ([slow] doesn't count): Iron March (boss_skills.dart); a boss is never stunned or
  /// shoved anyway.
  steadfast(0),

  /// This unit heals k of the damage it deals.
  lifesteal(0),

  /// A melee blow on this unit sends k of it back at the attacker (like the thorns relic).
  reflect(0),

  /// k HP a second, back.
  heal(0),

  /// k damage every whole second, [Effect.n] times, from [Effect.by].
  bleed(0),

  /// An HP pool (k left) that soaks damage before HP.
  absorb(0),

  /// Damage comes off this unit's MP first, a point of MP a point of damage.
  manaShield(0),

  /// The next [Effect.n] melee blows do nothing; with k > 0 each is answered with k × this unit's damage.
  block(0),

  /// No blow takes more than k of its max HP.
  cap(1),

  /// [Effect.by] takes k of every blow this unit takes (before defence: each side's own defence and guards
  /// apply to its share).
  link(0),

  /// This unit's foe is [Effect.by] while that lives ([Game._nearestFoe]): a monster taunted by a Hero, a troop
  /// by a monster's Bulwark.
  taunt(0),

  /// This troop doesn't fall back to a healer ([Game._fallBackTo]).
  holdGround(0),

  /// Nothing shoves this unit (the separation step, like a healer mid-cast).
  noShove(0),

  /// Monsters killed within [plunderK].reach of this troop pay k more gold.
  plunder(0),

  /// In a duel with [Effect.by]: this unit deals it k× its damage and takes [duelK].cut less from it.
  duel(1),

  /// Every monster this troop kills gives it k of its max HP back.
  killHeal(0),

  /// Damage from long-range troops (archers and wizards, their skills too) ×k, after defence: a monster's
  /// Shield Up (monster_skills.dart).
  shotWard(1),

  /// Max HP ×k (gained at once; when it ends it only caps the HP, like [Game._refit]), splash ×[giantRageK].splash,
  /// drawn [giantRageK].size× as big.
  giant(1, stat: true),

  /// This monster is a slime ([slimeHexK]): a slime's stats for its wave, its own kept in [Effect.was] until
  /// it ends; its share of HP carries over both ways.
  hex(0),

  /// Damage this monster takes from troops ×k, after its defence: Void Eye's mark (pusaka.dart). Apart from
  /// [vulnerable], so it stacks with Hunter's Mark (×1.25 × 1.25), and a troop's Curse of Frailty never meets it.
  voidMark(1),

  /// This monster heals nothing: every heal it gets lands as 0 ([Heal._healMonster]), and a skeleton under it doesn't
  /// reassemble ([reassembleK]). A troop's (the catalog's `noHeal` Fx, step 0g: Grave Seal's), nothing gives it yet.
  noHeal(0),

  /// Damage this monster takes from troops ×k, after its defence: Vengeance Mark's on a monster that hurt a troop of its
  /// type (batch G-1P, pusaka_engine.dart). Apart from [voidMark] and [vulnerable], so the three stack; under it the
  /// monster hits harder with the Bayangan Spite, and Mark Ward shortens it (omen.dart).
  pusakaMark(1);

  const Status(this.base, {this.stat = false});
  final double base;
  final bool stat;
}

/// One [Status] on a unit: until [until] (game time), of strength [k], from [by] (the caster, when it
/// matters), with [n] uses or ticks left and the [next] tick's time; [was]: the stats it had before (a hex).
class Effect {
  double until, k, next;
  final Unit? by;
  final Stats? was;
  int n;

  /// A bad effect: a monster put it on this troop (step 0g: a troop's cleanse, [Cleanse.cleanse], ends it). Any other,
  /// a troop's, a Pusaka's or its own, is never one, whatever its [by] (a knight's duel names the monster).
  final bool bad;

  /// A Bayangan gave it (omen.dart; the v2 rules, step 0j): an omen might counts in the dealt cap ([Omens._omenDealt]),
  /// Unholy Ward ignores an omen absorb ([BossSkills._wardable]), and the HUD rings an omen haste. Strippable like any.
  final bool omen;

  /// Spellbreaker (awaken_skills.dart, #88) already halved what was left of it: never again.
  bool halved = false;
  Effect(this.until, this.k, {this.by, this.n = 0, this.next = 0, this.was, this.bad = false, this.omen = false});
}

// The numbers, one record per built skill (`<id>K`); "tile" distances like the #10 skills'.
//
// Since decisions-log 298 ("Spam penuh": the owner, 2026-10-09) a Hero casts whenever it has the MP, the cooldown is over
// and its skill has a target: every `crowd` is 1 (was 2-4), every `below` that waited for the caster's own low HP is
// 1.0 (hurt at all), and a foe's `worth` in HP is 0. What a skill names as its target stays (a strong foe, a dying
// or badly hurt ally, a fallen troop, a foe under 25% for Execute), and so does every `above` that keeps a Hero
// from leaping or giving HP while low itself.

/// A Hero's skill comes again after this share of its [HeroSkill.cooldown] (decisions-log 298; Resurrection's
/// infinite one stays once a wave).
const heroCdK = 0.5;

/// War Cry: with [crowd]+ troops within [reach] (itself too) that fought in the last 2 s, each of them attacks
/// with its pause ×[haste] for [time] s.
const warCryK = (reach: 3 * tile, crowd: 1, haste: 0.8, time: 6.0);

/// Plunder: with [crowd]+ foes within [reach], for [time] s every monster killed within [reach] of it pays
/// [bonus] more of its gold (rounded up; the raised skeletons still pay nothing).
const plunderK = (reach: 3 * tile, crowd: 1, bonus: 0.5, time: 8.0);

/// Cleave: at a foe in reach (one with at least [hit] × its damage in HP left first, else the nearest; any foe since
/// decisions-log 298), one blow for [hit] × its damage; a kill gives back [refund] of the MP it cost.
const cleaveK = (hit: 3.0, refund: 0.5);

/// Execute: a foe in reach below [below] of its HP, not the boss or a mini boss, dies at once.
const executeK = (below: 0.25);

/// Bloodlust: below [below] of its HP with [crowd]+ foes within [reach], it heals [share] of what it deals for
/// [time] s.
const bloodlustK = (reach: 2 * tile, crowd: 1, below: 1.0, share: 0.4, time: 6.0);

/// Deep Wound: at a foe in reach with at least [worth] × its damage in HP left and not bleeding yet, a cut for
/// [hit] × its damage, then [bleed] × its damage every second for [time] s.
const deepWoundK = (worth: 0.0, hit: 1.0, bleed: 1.0, time: 4);

/// Eagle Eye: a long-range monster (it shoots or heals) within [see] × its range but out of it: range ×[range]
/// and damage ×[might] for [time] s.
const eagleEyeK = (see: 1.4, range: 1.4, might: 1.3, time: 8.0);

/// Hunter's Mark: the elite-or-higher foe in range with the most HP that isn't marked takes [taken] × the
/// damage troops deal it (the boss [boss]) for [time] s.
const huntersMarkK = (taken: 1.25, boss: 1.15, time: 8.0);

/// Flurry: at an elite-or-higher foe in reach, thrusts for [hits] × its damage, [gap] s apart.
const flurryK = (hits: [1.0, 1.0, 2.0], gap: 0.2);

/// Blessing: with [crowd]+ troops in its reach below [hurt] of their HP, every troop in its reach gets [share]
/// of its max HP back a second for [time] s.
const blessingK = (crowd: 1, hurt: 1.0, share: 0.02, time: 8.0);

/// Holy Nova: with [crowd]+ dark monsters in its range (or the boss), each of them takes [hit] × its heal ×
/// [holyShare].
const holyNovaK = (crowd: 1, hit: 2.5);

/// Gift of Mana: with a foe on the field and [crowd]+ troops in its reach short of MP for their skill (the #10
/// skill, or the awakening skill when that costs more: [AwakenSkills.mpWanted]), every other troop in its reach gets
/// [mp] MP.
const manaGiftK = (crowd: 1, mp: 15.0);

/// Iron Skin: hit in the last [within] s with [crowd]+ foes in reach: [cut] less damage (a guard, like
/// Hold Fast) and melee blows [reflect]ed for [time] s.
const ironSkinK = (within: 1.0, crowd: 1, cut: 0.15, reflect: 0.6, time: 6.0);

/// Earthquake: with [crowd]+ foes within [reach], each takes [hit] × its damage and walks at [slow] (the boss
/// [boss]) for [time] s.
const quakeK = (reach: 3 * tile, crowd: 1, hit: 0.75, slow: 0.6, boss: 0.8, time: 4.0);

/// Curse of Weakness: the elite-or-higher foe in range with the most damage that isn't cursed deals [dealt] and
/// walks at [slow] (the boss [bossDealt], [bossSlow]) for [time] s.
const curseK = (dealt: 0.6, slow: 0.8, bossDealt: 0.8, bossSlow: 0.9, time: 8.0);

/// Judgement: at a foe in reach that is dark or elite or higher, one holy blow for [hit] × its damage, [dark]
/// × on a dark one.
const judgementK = (hit: 2.0, dark: 4.0);

/// Sacrifice: above [above] of its HP, it gives [share] of its HP to the most hurt troop within [reach] below
/// [below] of its own (no more than that one lacks).
const sacrificeK = (reach: 3 * tile, below: 0.25, above: 0.6, share: 0.25);

/// Exorcism: with [crowd]+ raised minions within [reach], each normal or elite one crumbles; a stronger one
/// takes [hit] × its damage.
const exorcismK = (reach: 3 * tile, crowd: 1, hit: 3.0);

// The guard and AI skills (branch 2c).

/// Last Stand: at or below [below] of its HP with a foe in reach, for [time] s it doesn't fall back to a
/// healer, deals [might] × its damage, and every kill gives it [heal] of its max HP back.
const lastStandK = (below: 1.0, might: 1.5, heal: 0.2, time: 6.0);

/// Parry: hit in the last [within] s with a melee foe in reach, for [time] s it blocks the next [blows] melee
/// blows (shots get through) and answers each with [answer] × its damage.
const parryK = (within: 1.0, blows: 3, answer: 1.5, time: 5.0);

/// Duel of Honour: the highest-ranked elite-or-higher foe within [reach] (the boss too; a tie: the most HP)
/// fights only the knight for [time] s, while it lives; the knight deals it [might] × and takes [cut] less
/// from it.
const duelK = (reach: 2 * tile, might: 1.5, cut: 0.3, time: 8.0);

/// Shared Wounds: above [above] of its own HP, it takes [share] of every blow the most hurt other troop within
/// [reach] takes, one below [below] of its HP that was hit in the last [within] s, for [time] s.
const shareWoundsK = (reach: 3 * tile, above: 0.5, below: 0.3, within: 1.0, share: 0.5, time: 6.0);

/// Whirlwind: with [crowd]+ foes within [reach], it spins: [hits] cuts [gap] s apart (the first at once), each
/// foe within [reach] taking [hit] × its damage a cut. Its own attacks wait meanwhile; it can still walk.
const whirlwindK = (reach: 1.5 * tile, crowd: 1, hit: 0.7, hits: 4, gap: 0.5);

/// Veil of Light: the most hurt troop in its reach below [below] of its HP that was hit in the last [within] s
/// and isn't veiled gets a veil soaking up [soak] × its heal of damage, for [time] s.
const lightVeilK = (below: 0.5, within: 1.0, soak: 4.0, time: 8.0);

/// Giant's Rage: with [crowd]+ foes within [reach], or below [below] of its HP with a foe in reach, for [time] s
/// its max HP is [hp]× (and it gains that HP), its splash [splash]×, and it is drawn [size]× as big.
const giantRageK = (reach: 2 * tile, crowd: 1, below: 1.0, hp: 1.5, splash: 1.5, size: 1.3, time: 8.0);

/// Mana Shield: a foe within [reach], or hit in the last [within] s: for [time] s what it takes comes off its MP
/// first.
const manaShieldK = (reach: 2 * tile, within: 1.0, time: 8.0);

/// Holy Taunt: another troop within [reach] below [below] of its HP that was hit in the last [within] s, or
/// [crowd]+ foes within [reach] fighting other troops: every monster within [reach] (not a healing necromancer,
/// nor a necromancer raising the dead) fights the Templar for [time] s, and it takes [cut] less meanwhile.
const holyTauntK = (reach: 3 * tile, below: 1.0, within: 1.0, crowd: 1, cut: 0.25, time: 5.0);

/// Bastion of Faith: the boss or a mini boss in reach, or below [below] of its HP with [crowd]+ foes in reach:
/// for [time] s no blow takes more than [cap] of its max HP, and nothing shoves it.
const bastionK = (below: 1.0, crowd: 1, cap: 0.08, time: 5.0);
// The rare two (branch 3).

/// Resurrection: once a wave, the troop that fell last within its reach (not a Hero, never revived before)
/// comes back while the army is under its cap ([Game.armyCap]): where it fell but no further forward than [ahead] past
/// the priest, with [hp] of its HP and no MP, rising over [riseTime].
const reviveK = (hp: 0.3, ahead: tile);

/// Slime Hex: the elite or high elite in range that hits hardest (not the boss, a mini boss, a necromancer or
/// a healing necromancer) is a [form] for [time] s: that monster's stats for the wave (normal tier), keeping its
/// own gold, rank and share of HP.
const slimeHexK = (form: 'slime', time: 5.0);

// Branch 2b: the skills built from the special shots and ground objects (hero_shots.dart).

/// War Banner: with [crowd]+ troops within [reach] (itself too) that fought in the last 2 s, a banner at its feet
/// for [time] s: every troop within [reach] of the banner deals [might] × damage (heals aren't raised; the
/// effect lingers [linger] s after a troop steps out).
const bannerK = (reach: 3 * tile, crowd: 1, might: 1.2, time: 10.0, linger: 0.25);

/// Snipe: a healing necromancer within [see] × its range, else the highest-ranked elite-or-higher foe there: it
/// aims [aim] s (no other shots), then fires one arrow for [hit] × its damage.
const snipeK = (see: 1.5, aim: 0.5, hit: 5.0);

/// Crippling Shot: a foe in range that is faster than the archer or within [near] of a troop healer, and not
/// slowed yet: an arrow for [hit] × its damage that slows it to [slow] (the boss [boss]) for [time] s.
const crippleShotK = (near: tile, hit: 1.5, slow: 0.5, boss: 0.75, time: 5.0);

/// Piercing Shot: with [crowd]+ foes within [lineWidth] of the line through its nearest foe, out to [reach] ×
/// its range, one arrow along it at [speed]: [hit] × its damage to each foe it passes.
const pierceShotK = (crowd: 1, reach: 2.0, speed: 320.0, hit: 2.0);

/// Javelin: none in its reach and a foe [from]–[to] away: a spear at the one with the most max HP, at [speed],
/// for [hit] × its damage.
const javelinK = (from: 2 * tile, to: 5 * tile, speed: 220.0, hit: 2.5);

/// Axe Throw: [crowd]+ foes within [lineWidth] of the line ahead out to [reach] (or [few]+ there and none in
/// its reach): the axe out [reach] and back at [speed] (1 s in all), [hit] × its damage each way.
const axeThrowK = (crowd: 1, few: 1, reach: 4 * tile, speed: 128.0, hit: 1.0);

/// Chain Lightning: with [crowd]+ foes in range, a bolt to the nearest that jumps [jumps] times, each within
/// [radius] of the last: [hit] × its damage to the first, [falloff] less at each jump.
const chainLightningK = (crowd: 1, jumps: 4, radius: 2 * tile, hit: 1.2, falloff: 0.15);

/// Frost Storm: a foe in range with [crowd]+ foes within [radius] of it (itself too): a frost field of [radius]
/// round it for [time] s. Foes inside walk at [slow] (the boss [boss]; it lingers [linger] s after they step
/// out) and take [hit] × its damage every second.
const frostStormK = (crowd: 1, radius: 2 * tile, time: 5.0, slow: 0.5, boss: 0.75, hit: 0.3, linger: 0.25);

/// The Hero skills' rules and effects, the effect store and its hooks (game.dart calls in from one line each).
extension HeroSkills on Game {
  /// [s] on [u] now, or null.
  Effect? effectOn(Unit u, Status s) {
    final e = u.effects[s];
    return e != null && t < e.until ? e : null;
  }

  /// Whether [s] is on [u] now.
  bool under(Unit u, Status s) => effectOn(u, s) != null;

  /// [s]'s strength on [u] now, else its [Status.base].
  double effectK(Unit u, Status s) => effectOn(u, s)?.k ?? s.base;

  /// Puts [s] on [u] for [time] s at strength [k] (from [by], with [n] uses or ticks, the first tick a second
  /// from now). A stronger one of its kind still running stays until it ends; one as strong is renewed. The time goes
  /// through the duration scaler, the one place a catalog rule makes effects end sooner or later ([FxEngine._effectTime]).
  /// [bad]: a monster puts it on troop [u] (its skill's), so a troop's cleanse ends it ([Cleanse.cleanse]). [omen]: a
  /// Bayangan gives it ([Effect.omen]). A pin a troop puts on a monster ([Status.impaled]) may be shrugged off (the
  /// Bayangan Unbowed, [Omens._omenShrug]).
  void addEffect(Unit u, Status s, double time, {double k = 1, Unit? by, int n = 0, bool bad = false, bool omen = false}) {
    assert(!bad || u.side == Side.troop, 'a bad effect is a monster\'s on a troop: ${s.name}');
    if (effectOn(u, s) case final old? when (old.k - s.base).abs() > (k - s.base).abs()) return;
    if (s == Status.impaled && by?.side == Side.troop && _omenShrug(u)) return; // Unbowed (omen.dart)
    u.effects[s] = Effect(t + _effectTime(u, s, time, by, omen: omen), k, by: by, n: n, next: t + 1, bad: bad, omen: omen);
    if (s.stat && u.side == Side.troop) _refit(u);
  }

  /// Runs [f] [delay] s from now, while the wave lasts (a wave's end drops what is left).
  void later(double delay, void Function() f) => _later.add((t + delay, f));

  /// Hero [u] rolls its skill from its pool ([heroSkillPool]) with the [heroes] dice; none while its type has
  /// none built.
  void _rollHeroSkill(Unit u) {
    final pool = heroSkillPool(u.type);
    u.heroSkill = pool.isEmpty ? null : pool[heroes.nextInt(pool.length)];
  }

  /// Every tick: what is due in [later], the heals and bleeds a second's share at a time, and the effects that
  /// ran out (a stat one refits its troop).
  void _tickEffects(double dt) {
    if (_later.isNotEmpty) {
      final due = [for (final l in _later) if (l.$1 <= t + 1e-9) l]..sort((a, b) => a.$1.compareTo(b.$1));
      _later.removeWhere(due.contains);
      for (final (_, f) in due) {
        f();
      }
    }
    for (final u in units) {
      if (u.effects.isEmpty) continue;
      if (!u.alive) {
        u.effects.removeWhere((s, _) => s != Status.hex); // it dies a slime
        continue;
      }
      // The share of this tick it lasted, so a heal of k for time s gives back exactly k × time.
      if (u.effects[Status.heal] case final e? when t - dt < e.until) _healUnit(u, e.k * min(dt, e.until - (t - dt)), HealSrc.overTime);
      if (u.effects[Status.bleed] case final e?) {
        while (e.n > 0 && t >= e.next - 1e-9 && u.alive) {
          e
            ..n -= 1
            ..next += 1;
          impacts.add((u.pos, 'hit_${e.by?.type ?? 'swordsman'}'));
          _hurt(u, e.k, Hit.bleed, !e.omen && e.by != null && e.by!.alive ? e.by : null); // a Bayangan's (Bat Venom's): from no one
        }
      }
      final ended = [for (final MapEntry(key: s, value: e) in u.effects.entries) if (t >= e.until || (s == Status.bleed && e.n <= 0)) s];
      for (final s in ended) {
        if (s == Status.hex) _unhex(u);
        u.effects.remove(s);
        if (s == Status.reflect && u.side == Side.troop) _fxReflectBack(u); // Mirror Shield's comes back (pusaka_engine.dart)
      }
      if (u.side == Side.troop && u.alive && ended.any((s) => s.stat)) _refit(u);
    }
  }

  /// When a wave ends (won, or lost to a wipe: wipe.dart) every effect ends with it, a troop's ward and a slot's Shield
  /// too (heal.dart, omen.dart), and what was left for [later] is dropped; so do the heals the Bayangan Trickle spreads
  /// and what a troop owes Heal Siphon (omen.dart).
  void _endEffects() {
    _later.clear();
    _risesDue = 0; // a Phoenix Plume's rise among them (wipe.dart)
    for (final u in units) {
      final stat = u.effects.keys.any((s) => s.stat);
      if (u.alive && u.effects.containsKey(Status.hex)) _unhex(u);
      u
        ..effects.clear()
        ..ward = 0
        ..shield = 0
        ..trickle.clear()
        ..siphonDue = 0;
      if (stat && u.alive && u.side == Side.troop) _refit(u);
    }
  }

  // The hooks game.dart calls.

  /// [_hurt] before the target's defence: the attacker's might (or a curse's weakness, or a duel with [u]), then
  /// a linked ally's share taken off (it takes that through its own defence, from the blow's own [src]; Shared Wounds',
  /// Guardian Chain's), unless that ally is already passing a share of this blow on ([Game._linking]). What is left
  /// for [u].
  double _beforeDefence(Unit u, double dmg, Unit? by, Hit src) {
    if (by != null && by.effects.isNotEmpty) {
      dmg *= effectK(by, Status.might) * effectK(by, Status.weaken);
      if (effectOn(by, Status.duel) case final e? when e.by == u) dmg *= e.k;
    }
    if (effectOn(u, Status.link) case final e? when e.by != null && e.by!.alive && e.by != u && !_linking.contains(e.by)) {
      _linking.add(u); // a link back to one already passing its share on takes it all: no loop (two links on each other)
      try {
        _fxLinked(e.by!, e, _hurt(e.by!, dmg * e.k, src)); // the blow's own source; Guardian Chain's counter
      } finally {
        _linking.remove(u);
      }
      dmg *= 1 - e.k;
    }
    return dmg;
  }

  /// [_hurt] after defence and guards: a mark (Hunter's, Void Eye's, Vengeance Mark's), a duel's cut, the cap on one blow, a block (null: the blow does
  /// nothing), then what a veil or the MP soak up. What [u] takes. A [bare] blow (the Bayangan Executioner's,
  /// [Omens._omenBare]) meets no duel's cut, cap over 0, block, veil or Mana Shield: only a mark and a cap-0 window (the
  /// Grail's save).
  double? _afterDefence(Unit u, double dmg, Unit? by, {bool bare = false}) {
    if (by != null && by.side != u.side) dmg *= effectK(u, Status.vulnerable) * effectK(u, Status.voidMark) * effectK(u, Status.pusakaMark); // a mark, Void Eye's, Vengeance Mark's
    if (by != null && by.stats.shotSpeed > 0) dmg *= effectK(u, Status.shotWard);
    if (effectOn(u, Status.duel) case final e? when by != null && e.by == by && !bare) dmg *= 1 - duelK.cut;
    if (effectOn(u, Status.cap) case final e? when !bare || e.k <= 0) {
      final capped = min(dmg, u.maxHp * e.k);
      if (e.by != null && e.by != u) _fxSheltered(e.by!, dmg - capped); // Soul Shelter's window, from a fallen troop
      dmg = capped;
    }
    if (bare) return dmg;
    if (effectOn(u, Status.block) case final e? when e.n > 0 && by != null && by.alive && by.stats.melee && by.side != u.side) {
      e.n -= 1;
      if (e.n == 0) u.effects.remove(Status.block);
      impacts.add((u.pos, 'hit_${u.type}'));
      if (e.k > 0) _hurt(by, u.stats.dmg * e.k, Hit.hitBack, u);
      return null;
    }
    if (effectOn(u, Status.absorb) case final e?) {
      final (lost, left) = _omenSoak(u, by, dmg, e.k); // a monster's blow breaks it sooner under Shieldbreak (omen.dart)
      e.k -= lost;
      dmg = left;
      if (e.k <= 0) u.effects.remove(Status.absorb);
    }
    if (under(u, Status.manaShield)) {
      final (lost, left) = _omenSoak(u, by, dmg, u.mp);
      u.mp -= lost;
      dmg = left;
    }
    return dmg;
  }

  /// [_hurt], once [u] took [dmg] ([dealt] of it off its HP) from [by]: [by]'s lifesteal (a Bayangan's, Blood Moon's,
  /// with its own tag) and, when the blow killed a monster, its kill heal; [u]'s reflect on a melee blow (no attacker,
  /// like the thorns: it doesn't bounce back and forth; its own wave-long one is Mirror Shield's, counted); and the MP a Soul
  /// Rend takes from a troop.
  void _answer(Unit u, double dmg, double dealt, Unit by) {
    if (effectOn(by, Status.lifesteal) case final e?) {
      if (e.omen && by.side == Side.enemy) {
        _healMonster(by, dealt * e.k, MonsterHeal.bloodMoon); // Blood Moon (omen.dart)
      } else {
        _healUnit(by, dealt * e.k, HealSrc.lifesteal); // a boss's Bloodrage too
      }
    }
    if (effectOn(by, Status.killHeal) case final e? when u.hp <= 0 && u.side == Side.enemy && by.alive) {
      _healUnit(by, by.maxHp * e.k, HealSrc.killHeal);
    }
    if (effectOn(u, Status.reflect) case final e? when by.stats.melee && by.side != u.side) {
      final back = _hurt(by, dmg * e.k, Hit.hitBack);
      if (e.by == u && u.side == Side.troop) _fxMirrored(u, back); // its own, the whole wave: Mirror Shield's counter
    }
    if (effectOn(by, Status.soulRend) case final e? when u.side == Side.troop) u.mp = max(0.0, u.mp - e.k);
  }

  /// [_hurt], monster [dead] just killed: the extra gold a plundering troop near it brings (one troop's, not
  /// added up), floated by the UI ([goldPops]).
  void _plunder(Unit dead) {
    if (dead.stats.cost <= 0) return;
    for (final o in troops) {
      final e = o.alive ? effectOn(o, Status.plunder) : null;
      if (e == null || o.pos.distanceTo(dead.pos) > plunderK.reach) continue;
      final bonus = (_omenGold(dead.stats.cost) * e.k).ceil(); // of its gold: less under the Bayangan Thrift (omen.dart)
      gold += bonus;
      goldPops.add((dead.pos, bonus));
      return;
    }
  }

  /// [_statsFor]: the stat effects on troop [u] over the stats [s] it would have.
  Stats _withEffects(Unit u, Stats s) {
    if (effectOn(u, Status.range) case final e?) s = s._with(range: s.range * e.k);
    if (effectOn(u, Status.giant) case final e?) s = s._with(hp: (s.hp * e.k).round(), splash: s.splash * giantRageK.splash);
    return s;
  }

  /// [_moveToward]: [u]'s walking speed is times this (a slow and an Impale's pin unless [Status.steadfast], a
  /// monster's speed-up; not while its wave marches).
  double _pace(Unit u) => u.effects.isEmpty || (marching && u.side == Side.enemy)
      ? 1.0
      : (under(u, Status.steadfast) ? 1.0 : effectK(u, Status.slow) * effectK(u, Status.impaled)) * effectK(u, Status.swift);

  /// [_nearestFoe]: who taunted [u] (a monster by a Hero, a troop by a monster's Bulwark), while it lives.
  Unit? _taunter(Unit u) {
    final by = effectOn(u, Status.taunt)?.by;
    return by != null && by.alive ? by : null;
  }

  /// Hero [u] casts its skill when it is built, its rule holds ([wantsHeroSkill]), it has the MP, its cooldown
  /// is over, and (for one that [HeroSkill.holds] monsters) the wave isn't marching. One cast a tick.
  bool _tryHeroSkill(Unit u) {
    final s = u.heroSkill;
    if (s == null || !_heroSkillReady(u) || u.mp < skillCost(u, s.cost) || !wantsHeroSkill(u)) return false;
    u
      ..mp -= skillCost(u, s.cost) // more under the Bayangan Spell Tax (omen.dart)
      ..heroSkillAt = t;
    heroCasts.add((u, s));
    _emit(HeroSkillCast(wave, t, name: u.name, type: u.type, skill: s));
    impacts.add((u.pos, awakeFx('upgrade', maxAwaken))); // the gold burst
    // Its strip's wind-up, then it lands (skill_strips.dart); Snipe lands now and its release comes on its aim's end.
    _windUp(u, WindKind.hero, heroSkillStrip(s), strikeAt: s == HeroSkill.snipe ? t + snipeK.aim : null);
    return true;
  }

  /// Hero [u]'s skill may be cast now, MP aside.
  bool _heroSkillReady(Unit u) {
    final s = u.heroSkill;
    return s != null && s.built && t - u.heroSkillAt >= skillCd(s.cooldown * heroCdK) && !(marching && s.holds); // Oath of Spells (pusaka.dart)
  }

  /// Hero [u] is saving up for its skill: ready and wanted, only short of MP (once it spent [spend]: a healer's heal,
  /// [Game._healWaits]). Its #10 skill, its awakening skill and its heals wait meanwhile.
  bool _savingUp(Unit u, [double spend = 0]) => _heroSkillReady(u) && u.mp - spend < skillCost(u, u.heroSkill!.cost) && wantsHeroSkill(u);

  /// Whether Hero [u]'s skill ([Unit.heroSkill]) would do something now, by its rule (MP, cooldown and the
  /// march aside).
  bool wantsHeroSkill(Unit u) {
    final inReach = _foesNear(u.pos, u.stats.range);
    switch (u.heroSkill) {
      case HeroSkill.warCry:
        return _alliesNear(u.pos, warCryK.reach).where((o) => t - o.attackedAt < Game._engagedFor).length >= warCryK.crowd;
      case HeroSkill.plunder:
        return _foesNear(u.pos, plunderK.reach).length >= plunderK.crowd;
      case HeroSkill.cleave:
        return inReach.isNotEmpty; // any foe (decisions-log 298); one that outlasts the blow first
      case HeroSkill.execute:
        return _executable(u) != null;
      case HeroSkill.bloodlust:
        return u.hp < u.maxHp * bloodlustK.below && _foesNear(u.pos, bloodlustK.reach).length >= bloodlustK.crowd;
      case HeroSkill.deepWound:
        return _woundable(u) != null;
      case HeroSkill.eagleEye:
        return !under(u, Status.range) &&
            _foesNear(u.pos, u.stats.range * eagleEyeK.see).any((o) => o.pos.distanceTo(u.pos) > u.stats.range && (o.stats.shotSpeed > 0 || o.stats.heals));
      case HeroSkill.huntersMark:
        return _markable(u) != null;
      case HeroSkill.flurry:
        return inReach.any(_strong);
      case HeroSkill.blessing:
        return _alliesNear(u.pos, u.stats.range).where((o) => o.hp < o.maxHp * blessingK.hurt).length >= blessingK.crowd;
      case HeroSkill.holyNova:
        final dark = inReach.where((o) => o.stats.dark).toList();
        return dark.length >= holyNovaK.crowd || dark.any((o) => o.tier == Tier.boss);
      case HeroSkill.manaGift:
        return enemies.any((o) => o.alive && o.entered) &&
            _alliesNear(u.pos, u.stats.range).where((o) => o != u && o.mp < mpWanted(o)).length >= manaGiftK.crowd; // #10 or awakening skill
      case HeroSkill.ironSkin:
        return t - u.hurtAt < ironSkinK.within && inReach.length >= ironSkinK.crowd;
      case HeroSkill.quake:
        return _foesNear(u.pos, quakeK.reach).length >= quakeK.crowd;
      case HeroSkill.curse:
        return _cursable(u) != null;
      case HeroSkill.judgement:
        return inReach.any((o) => o.stats.dark || _strong(o));
      case HeroSkill.sacrifice:
        return u.hp > u.maxHp * sacrificeK.above && _dying(u) != null;
      case HeroSkill.exorcism:
        return _foesNear(u.pos, exorcismK.reach).where((o) => o.raisedBy != null).length >= exorcismK.crowd;
      case HeroSkill.lastStand:
        return u.hp < u.maxHp * lastStandK.below && inReach.isNotEmpty;
      case HeroSkill.parry:
        return t - u.hurtAt < parryK.within && inReach.any((o) => o.stats.melee) && !under(u, Status.block);
      case HeroSkill.duel:
        return !under(u, Status.duel) && _challenger(u) != null;
      case HeroSkill.shareWounds:
        return u.hp > u.maxHp * shareWoundsK.above && _sharer(u) != null;
      case HeroSkill.whirlwind:
        return _foesNear(u.pos, whirlwindK.reach).length >= whirlwindK.crowd;
      case HeroSkill.lightVeil:
        return _veiled(u) != null;
      case HeroSkill.giantRage:
        return !under(u, Status.giant) &&
            (_foesNear(u.pos, giantRageK.reach).length >= giantRageK.crowd || (u.hp < u.maxHp * giantRageK.below && inReach.isNotEmpty));
      case HeroSkill.manaShield:
        return !under(u, Status.manaShield) && (t - u.hurtAt < manaShieldK.within || _foesNear(u.pos, manaShieldK.reach).isNotEmpty);
      case HeroSkill.holyTaunt:
        final near = _foesNear(u.pos, holyTauntK.reach);
        if (!near.any(_tauntable)) return false;
        return _alliesNear(u.pos, holyTauntK.reach).any((o) => o != u && o.hp < o.maxHp * holyTauntK.below && t - o.hurtAt < holyTauntK.within) ||
            near.where((o) => t - o.attackedAt < Game._engagedFor && _nearestFoe(o) != u).length >= holyTauntK.crowd;
      case HeroSkill.bastion:
        return !under(u, Status.cap) &&
            (inReach.any((o) => o.tier == Tier.boss || o.tier == Tier.miniBoss) || (u.hp < u.maxHp * bastionK.below && inReach.length >= bastionK.crowd));
      case HeroSkill.shieldBash || HeroSkill.sweep || HeroSkill.rescueLeap || HeroSkill.deathLeap || HeroSkill.charge || HeroSkill.hook || HeroSkill.spearWall:
        return _wantsMove(u); // hero_moves.dart
      case HeroSkill.revive:
        return !full && _revivable(u) != null;
      case HeroSkill.slimeHex:
        return _hexable(u) != null;
      case HeroSkill.banner:
        return _alliesNear(u.pos, bannerK.reach).where((o) => t - o.attackedAt < Game._engagedFor).length >= bannerK.crowd;
      case HeroSkill.snipe:
        return _snipeTarget(u) != null;
      case HeroSkill.crippleShot:
        return _crippleTarget(u) != null;
      case HeroSkill.pierceShot:
        return _pierceAim(u) != null;
      case HeroSkill.javelin:
        return inReach.isEmpty && _javelinTarget(u) != null;
      case HeroSkill.axeThrow:
        final n = _onAxeLine(u);
        return n >= axeThrowK.crowd || (n >= axeThrowK.few && inReach.isEmpty);
      case HeroSkill.chainLightning:
        return inReach.length >= chainLightningK.crowd;
      case HeroSkill.frostStorm:
        return _frostCentre(u) != null;
      default:
        return false; // no skill
    }
  }

  /// What Hero [u]'s skill does (the `<id>K` records hold the numbers). Every hit goes through [_hurt] with the
  /// Hero as the attacker, like a #10 skill's.
  void _castHeroSkill(Unit u) {
    final dmg = u.stats.dmg, inReach = _foesNear(u.pos, u.stats.range);
    switch (u.heroSkill!) {
      case HeroSkill.warCry:
        for (final o in _alliesNear(u.pos, warCryK.reach)) {
          addEffect(o, Status.haste, warCryK.time, k: warCryK.haste);
        }
        sfx.add(Sfx.magic);
      case HeroSkill.plunder:
        addEffect(u, Status.plunder, plunderK.time, k: plunderK.bonus);
        sfx.add(Sfx.magic);
      case HeroSkill.cleave:
        final o = inReach.firstWhere((o) => o.hp >= dmg * cleaveK.hit, orElse: () => inReach.first);
        impacts.add((o.pos, _fxOf(u, 'hit_knight_big')));
        _hurt(o, dmg * cleaveK.hit, Hit.skill, u);
        if (!o.alive) u.mp = min(u.stats.mp.toDouble(), u.mp + skillCost(u, HeroSkill.cleave.cost) * cleaveK.refund); // of what it paid
        sfx.add(Sfx.sword);
      case HeroSkill.execute:
        final o = _executable(u)!;
        impacts.add((o.pos, _fxOf(u, 'hit_swordsman_big')));
        _hurt(o, o.hp + o.stats.def, Hit.skill, u);
        sfx.add(Sfx.sword);
      case HeroSkill.bloodlust:
        addEffect(u, Status.lifesteal, bloodlustK.time, k: bloodlustK.share);
        sfx.add(Sfx.magic);
      case HeroSkill.deepWound:
        final o = _woundable(u)!;
        impacts.add((o.pos, _fxOf(u, 'hit_swordsman')));
        _hurt(o, dmg * deepWoundK.hit, Hit.skill, u);
        if (o.alive) addEffect(o, Status.bleed, deepWoundK.time + 0.5, k: dmg * deepWoundK.bleed, by: u, n: deepWoundK.time);
        sfx.add(Sfx.sword);
      case HeroSkill.eagleEye:
        addEffect(u, Status.range, eagleEyeK.time, k: eagleEyeK.range);
        addEffect(u, Status.might, eagleEyeK.time, k: eagleEyeK.might);
        sfx.add(Sfx.magic);
      case HeroSkill.huntersMark:
        final o = _markable(u)!;
        addEffect(o, Status.vulnerable, huntersMarkK.time, k: o.tier == Tier.boss ? huntersMarkK.boss : huntersMarkK.taken, by: u);
        sfx.add(Sfx.dagger);
      case HeroSkill.flurry:
        final o = inReach.firstWhere(_strong), last = flurryK.hits.length - 1;
        for (final (i, k) in flurryK.hits.indexed) {
          void thrust() {
            if (!o.alive || !u.alive) return;
            impacts.add((o.pos, _fxOf(u, 'hit_lancer${i == last ? '_big' : ''}')));
            _hurt(o, u.stats.dmg * k, Hit.skill, u);
            sfx.add(Sfx.sword);
          }

          i == 0 ? thrust() : later(i * flurryK.gap, thrust);
        }
      case HeroSkill.blessing:
        for (final o in _alliesNear(u.pos, u.stats.range)) {
          addEffect(o, Status.heal, blessingK.time, k: o.maxHp * blessingK.share);
          impacts.add((o.pos, _fxOf(u, 'heal')));
        }
        sfx.add(Sfx.magic);
      case HeroSkill.holyNova:
        for (final o in inReach.where((o) => o.stats.dark)) {
          impacts.add((o.pos, 'holy'));
          _holyHurt(o, _healOf(u) * holyNovaK.hit * holyShare, u, Hit.skill);
        }
        sfx.add(Sfx.magic);
      case HeroSkill.manaGift:
        for (final o in _alliesNear(u.pos, u.stats.range)) {
          if (o == u) continue;
          o.mp = min(o.stats.mp.toDouble(), o.mp + manaGiftK.mp);
          impacts.add((o.pos, awakeFx('heal', 1))); // the heal burst in MP blue
        }
        sfx.add(Sfx.magic);
      case HeroSkill.ironSkin:
        _guard(u, ironSkinK.cut, ironSkinK.time);
        addEffect(u, Status.reflect, ironSkinK.time, k: ironSkinK.reflect);
        sfx.add(Sfx.magic);
      case HeroSkill.quake:
        impacts.add((u.pos, _fxOf(u, 'hit_armored_axeman_big')));
        for (final o in _foesNear(u.pos, quakeK.reach)) {
          impacts.add((o.pos, _fxOf(u, 'hit_armored_axeman')));
          _hurt(o, dmg * quakeK.hit, Hit.skill, u);
          if (o.alive) addEffect(o, Status.slow, quakeK.time, k: o.tier == Tier.boss ? quakeK.boss : quakeK.slow, by: u);
        }
        sfx.add(Sfx.sword);
      case HeroSkill.curse:
        final o = _cursable(u)!, isBoss = o.tier == Tier.boss;
        addEffect(o, Status.weaken, curseK.time, k: isBoss ? curseK.bossDealt : curseK.dealt, by: u);
        addEffect(o, Status.slow, curseK.time, k: isBoss ? curseK.bossSlow : curseK.slow, by: u);
        impacts.add((o.pos, 'hit_$boss'));
        sfx.add(Sfx.magic);
      case HeroSkill.judgement:
        final o = inReach.firstWhere((o) => o.stats.dark || _strong(o));
        impacts.add((o.pos, 'holy'));
        impacts.add((o.pos, _fxOf(u, 'hit_knight_templar_big')));
        _holyHurt(o, dmg * (o.stats.dark ? judgementK.dark : judgementK.hit), u, Hit.skill);
        sfx.add(Sfx.sword);
      case HeroSkill.sacrifice:
        final o = _dying(u)!, give = min(u.hp * sacrificeK.share, o.maxHp - o.hp);
        u.hp -= give;
        _healTroop(o, give, HealSrc.sacrifice);
        impacts.add((o.pos, 'holy'));
        sfx.add(Sfx.magic);
      case HeroSkill.exorcism:
        for (final o in _foesNear(u.pos, exorcismK.reach).where((o) => o.raisedBy != null)) {
          impacts.add((o.pos, 'holy'));
          _hurt(o, o.tier.index <= Tier.elite.index ? o.hp + o.stats.def : dmg * exorcismK.hit, Hit.skill, u);
        }
        sfx.add(Sfx.magic);
      case HeroSkill.lastStand:
        addEffect(u, Status.holdGround, lastStandK.time);
        addEffect(u, Status.might, lastStandK.time, k: lastStandK.might);
        addEffect(u, Status.killHeal, lastStandK.time, k: lastStandK.heal);
        impacts.add((u.pos, awakeFx('upgrade', 2))); // the crimson burst
        sfx.add(Sfx.magic);
      case HeroSkill.parry:
        addEffect(u, Status.block, parryK.time, k: parryK.answer, n: parryK.blows);
        sfx.add(Sfx.sword);
      case HeroSkill.duel:
        final o = _challenger(u)!;
        addEffect(o, Status.taunt, duelK.time, by: u);
        addEffect(u, Status.duel, duelK.time, k: duelK.might, by: o);
        impacts.add((o.pos, _fxOf(u, 'hit_knight')));
        sfx.add(Sfx.sword);
      case HeroSkill.shareWounds:
        final o = _sharer(u)!;
        addEffect(o, Status.link, shareWoundsK.time, k: shareWoundsK.share, by: u);
        impacts.add((o.pos, 'holy'));
        sfx.add(Sfx.magic);
      case HeroSkill.whirlwind:
        u.cd = max(u.cd, whirlwindK.hits * whirlwindK.gap); // its own attacks wait while it spins
        void spin() {
          if (!u.alive) return;
          u.attackedAt = t; // the attack strip again, each cut
          for (final o in _foesNear(u.pos, whirlwindK.reach)) {
            impacts.add((o.pos, _fxOf(u, 'hit_swordsman')));
            _hurt(o, u.stats.dmg * whirlwindK.hit, Hit.skill, u);
          }
          sfx.add(Sfx.sword);
        }

        spin();
        for (var i = 1; i < whirlwindK.hits; i++) {
          later(i * whirlwindK.gap, spin);
        }
      case HeroSkill.lightVeil:
        final o = _veiled(u)!;
        addEffect(o, Status.absorb, lightVeilK.time, k: _healOf(u) * lightVeilK.soak);
        impacts.add((o.pos, _fxOf(u, 'heal')));
        sfx.add(Sfx.magic);
      case HeroSkill.giantRage:
        addEffect(u, Status.giant, giantRageK.time, k: giantRageK.hp); // a stat effect: refit, gaining the HP
        impacts.add((u.pos, awakeFx('upgrade', 2)));
        sfx.add(Sfx.magic);
      case HeroSkill.manaShield:
        addEffect(u, Status.manaShield, manaShieldK.time);
        impacts.add((u.pos, awakeFx('heal', 1))); // the heal burst in MP blue
        sfx.add(Sfx.magic);
      case HeroSkill.holyTaunt:
        for (final o in _foesNear(u.pos, holyTauntK.reach).where(_tauntable)) {
          addEffect(o, Status.taunt, holyTauntK.time, by: u);
        }
        _guard(u, holyTauntK.cut, holyTauntK.time);
        impacts.add((u.pos, 'holy'));
        sfx.add(Sfx.magic);
      case HeroSkill.bastion:
        addEffect(u, Status.cap, bastionK.time, k: bastionK.cap);
        // A longer stand already on it (Anchor's, the whole wave: pusaka_engine.dart) stays.
        if ((effectOn(u, Status.noShove)?.until ?? t) < t + bastionK.time) addEffect(u, Status.noShove, bastionK.time);
        impacts.add((u.pos, 'holy'));
        sfx.add(Sfx.magic);
      case HeroSkill.shieldBash || HeroSkill.sweep || HeroSkill.rescueLeap || HeroSkill.deathLeap || HeroSkill.charge || HeroSkill.hook || HeroSkill.spearWall:
        _castMove(u); // hero_moves.dart
      case HeroSkill.revive:
        final dead = _revivable(u)!, r = _newTroop(dead.type, Point(min(dead.pos.x, u.pos.x + reviveK.ahead), dead.pos.y), dead.name);
        r
          ..post = dead.post
          ..hp = r.maxHp * reviveK.hp
          ..mp = 0
          ..revived = true
          ..busyFrom = t
          ..busyUntil = t + riseTime; // it rises like a raised minion
        raised.add(r); // joins after the update loop
        fallen.remove(dead);
        _autoRose(dead); // Auto no longer buys it back (auto_replace.dart)
        risen.add(r);
        impacts
          ..add((r.pos, awakeFx('summon', maxAwaken))) // the summon circle in gold
          ..add((r.pos, 'holy'));
        sfx.add(Sfx.magic);
      case HeroSkill.slimeHex:
        final o = _hexable(u)!;
        if (!_omenShrug(o)) _hexInto(o, slimeHexK.time, u); // shrugged off under the Bayangan Unbowed (omen.dart)
        sfx.add(Sfx.magic);
      case HeroSkill.banner:
        zones.add(Zone(u, u.pos, since: t, duration: bannerK.time, radius: bannerK.reach, side: Side.troop, look: ZoneLook.banner,
            inside: (o) => addEffect(o, Status.might, bannerK.linger, k: bannerK.might, by: u)));
        sfx.add(Sfx.magic);
      case HeroSkill.snipe:
        final o = _snipeTarget(u)!, hit = dmg * snipeK.hit;
        u
          ..cd = max(u.cd, snipeK.aim) // aiming: no other shots
          ..attackedAt = t; // the draw
        later(snipeK.aim, () {
          if (!u.alive || !o.alive) return;
          shots.add(Shot.special(u, o, u.pos + const Point(0, -6), dmg: hit, speed: u.stats.shotSpeed, big: true, look: ShotLook.trail));
          sfx.add(Sfx.dagger);
        });
      case HeroSkill.crippleShot:
        final o = _crippleTarget(u)!;
        shots.add(Shot.special(u, o, u.pos + const Point(0, -6), dmg: dmg * crippleShotK.hit, speed: u.stats.shotSpeed, look: ShotLook.ice,
            onHit: (h) {
          if (h.alive) addEffect(h, Status.slow, crippleShotK.time, k: h.tier == Tier.boss ? crippleShotK.boss : crippleShotK.slow, by: u);
        }));
        u.attackedAt = t;
        sfx.add(Sfx.dagger);
      case HeroSkill.pierceShot:
        lineShots.add(LineShot(u, u.pos, _pierceAim(u)!,
            dmg: dmg * pierceShotK.hit, speed: pierceShotK.speed, length: u.stats.range * pierceShotK.reach, look: ShotLook.long));
        u.attackedAt = t;
        sfx.add(Sfx.dagger);
      case HeroSkill.javelin:
        final o = _javelinTarget(u)!;
        shots.add(Shot.special(u, o, u.pos + const Point(0, -6), dmg: dmg * javelinK.hit, speed: javelinK.speed, big: true, look: ShotLook.spear));
        u.attackedAt = t;
        sfx.add(Sfx.sword);
      case HeroSkill.axeThrow:
        lineShots.add(LineShot(u, u.pos, u.pos + const Point(1.0, 0.0),
            dmg: dmg * axeThrowK.hit, speed: axeThrowK.speed, length: axeThrowK.reach, boomerang: true, look: ShotLook.spin));
        u.attackedAt = t;
        sfx.add(Sfx.sword);
      case HeroSkill.chainLightning:
        chainStrike(u, inReach.first,
            dmg: dmg * chainLightningK.hit, jumps: chainLightningK.jumps, radius: chainLightningK.radius, falloff: chainLightningK.falloff);
        sfx.add(Sfx.magic);
      case HeroSkill.frostStorm:
        zones.add(Zone(u, _frostCentre(u)!.pos, since: t, duration: frostStormK.time, radius: frostStormK.radius, side: Side.enemy,
            look: ZoneLook.frost,
            inside: (o) => addEffect(o, Status.slow, frostStormK.linger, k: o.tier == Tier.boss ? frostStormK.boss : frostStormK.slow, by: u),
            pulse: (o) {
              impacts.add((o.pos, _fxOf(u, 'hit_wizard')));
              _hurt(o, dmg * frostStormK.hit, Hit.skill, u.alive ? u : null);
            }));
        sfx.add(Sfx.magic);
    }
  }

  /// Elite or higher (the boss too).
  static bool _strong(Unit o) => o.tier.index >= Tier.elite.index;

  /// Execute's target: the nearest foe in reach below [executeK].below of its HP, not the boss or a mini boss.
  Unit? _executable(Unit u) =>
      _foesNear(u.pos, u.stats.range).where((o) => o.hp < o.maxHp * executeK.below && o.tier != Tier.boss && o.tier != Tier.miniBoss).firstOrNull;

  /// Deep Wound's target: the nearest foe in reach worth it and not bleeding yet.
  Unit? _woundable(Unit u) =>
      _foesNear(u.pos, u.stats.range).where((o) => o.hp >= u.stats.dmg * deepWoundK.worth && !under(o, Status.bleed)).firstOrNull;

  /// Hunter's Mark's target: the elite-or-higher foe in range with the most HP that isn't marked yet.
  Unit? _markable(Unit u) => _most(_foesNear(u.pos, u.stats.range).where((o) => _strong(o) && !under(o, Status.vulnerable)), (o) => o.maxHp.toDouble());

  /// Curse of Weakness's target: the elite-or-higher foe in range with the most damage that isn't weakened as
  /// strongly as the curse would yet (a disarmed foe's milder weakness still takes a curse, #88).
  Unit? _cursable(Unit u) => _most(
      _foesNear(u.pos, u.stats.range)
          .where((o) => _strong(o) && effectK(o, Status.weaken) > (o.tier == Tier.boss ? curseK.bossDealt : curseK.dealt)),
      (o) => o.stats.dmg);

  /// Sacrifice's ally: the most hurt other troop within [sacrificeK].reach below [sacrificeK].below of its HP.
  Unit? _dying(Unit u) => _most(_alliesNear(u.pos, sacrificeK.reach).where((o) => o != u && o.hp < o.maxHp * sacrificeK.below), (o) => -o.hp / o.maxHp);

  /// Duel of Honour's foe: the highest-ranked elite-or-higher foe within [duelK].reach that a taunt turns
  /// ([_tauntable]); of a tie, the one with the most HP.
  Unit? _challenger(Unit u) => _most(_foesNear(u.pos, duelK.reach).where((o) => _strong(o) && _tauntable(o)), (o) => o.tier.index * 1e6 + o.hp);

  /// Shared Wounds' ally: the most hurt other troop within [shareWoundsK].reach below [shareWoundsK].below of its
  /// HP, hit in the last [shareWoundsK].within s and not linked yet.
  Unit? _sharer(Unit u) => _most(
      _alliesNear(u.pos, shareWoundsK.reach)
          .where((o) => o != u && o.hp < o.maxHp * shareWoundsK.below && t - o.hurtAt < shareWoundsK.within && !under(o, Status.link)),
      (o) => -o.hp / o.maxHp);

  /// Veil of Light's troop: the most hurt one in reach below [lightVeilK].below of its HP, hit in the last
  /// [lightVeilK].within s and not veiled yet.
  Unit? _veiled(Unit u) => _most(
      _alliesNear(u.pos, u.stats.range)
          .where((o) => o.hp < o.maxHp * lightVeilK.below && t - o.hurtAt < lightVeilK.within && !under(o, Status.absorb)),
      (o) => -o.hp / o.maxHp);

  /// Holy Taunt turns monster [o]: not a healing necromancer, nor a necromancer raising the dead.
  bool _tauntable(Unit o) => o.type != necroHealer && !(o.type == boss && t < o.busyUntil);
  /// Resurrection's troop: the one that fell last this wave within [u]'s reach, not a Hero, never revived, and of a type
  /// that may take one more ([typeRefusal]: not at its cap, decisions-log 201).
  Unit? _revivable(Unit u) => fallen.reversed
      .where((o) => !o.hero && !o.revived && o.pos.distanceTo(u.pos) <= u.stats.range && typeRefusal(o.type) == null)
      .firstOrNull;

  /// Slime Hex's monster: the elite or high elite in range that hits hardest and isn't hexed yet, not a
  /// necromancer or a healing necromancer ([_hexableType]).
  Unit? _hexable(Unit u) => _most(
      _foesNear(u.pos, u.stats.range)
          .where((o) => (o.tier == Tier.elite || o.tier == Tier.highElite) && _hexableType(o) && !o.effects.containsKey(Status.hex)),
      (o) => o.stats.dmg);

  /// Whether a hex may turn monster [o] into a slime by its type: never a necromancer nor a healing necromancer.
  bool _hexableType(Unit o) => o.type != boss && o.type != necroHealer;

  /// Monster [o] turns into a slime for [time] s from [by] (shorter under the Bayangan Unshaken, omen.dart): a slime's
  /// stats ([slimeHexK].form, a normal one's, keeping its gold), its own kept in [Effect.was] until [Status.hex] ends
  /// ([_unhex]). Slime Hex's, and Hex Blade's (batch G-2, pusaka_engine.dart).
  void _hexInto(Unit o, double time, Unit by) {
    final slime = spawnStats(slimeHexK.form, Tier.normal, skipBuff: o.skipBuffed)._with(cost: o.stats.cost);
    o.effects[Status.hex] = Effect(t + scaledEffectTime(time, _omenUnshaken(o, Status.hex)), 0, by: by, was: o.stats);
    _swapStats(o, slime);
  }

  /// A hexed monster [u] turns back ([Status.hex] ends, or its wave): its own stats again.
  void _unhex(Unit u) {
    if (u.effects[Status.hex]?.was case final was?) _swapStats(u, was);
  }

  /// Monster [u] fights with [s] from now on, keeping its share of HP, with a puff.
  void _swapStats(Unit u, Stats s) {
    final share = u.hp / u.maxHp;
    u
      ..stats = s
      ..maxHp = s.hp
      ..hp = share * s.hp;
    impacts.add((u.pos, 'summon'));
  }

  /// Snipe's target: the nearest healing necromancer within [snipeK].see × its range, else the highest-ranked
  /// elite-or-higher foe there (the most max HP of a rank).
  Unit? _snipeTarget(Unit u) {
    final seen = _foesNear(u.pos, u.stats.range * snipeK.see);
    return seen.where((o) => o.type == necroHealer).firstOrNull ?? _most(seen.where(_strong), (o) => o.tier.index * 1e6 + o.maxHp);
  }

  /// Crippling Shot's target: the nearest foe in range, not slowed yet, that is faster than [u] or within
  /// [crippleShotK].near of a troop healer.
  Unit? _crippleTarget(Unit u) {
    final healers = [for (final h in troops) if (h.alive && h.stats.heals) h];
    return _foesNear(u.pos, u.stats.range)
        .where((o) => !under(o, Status.slow) && (o.stats.speed > u.walkSpeed || healers.any((h) => h.pos.distanceTo(o.pos) <= crippleShotK.near)))
        .firstOrNull;
  }

  /// Where Piercing Shot aims: its nearest foe in range, when [pierceShotK].crowd+ foes are within [lineWidth]
  /// of the line through it out to [pierceShotK].reach × its range.
  Point<double>? _pierceAim(Unit u) {
    final first = _foesNear(u.pos, u.stats.range).firstOrNull;
    if (first == null) return null;
    final reach = u.stats.range * pierceShotK.reach, end = u.pos + _direction(first.pos - u.pos) * reach;
    final on = _foesNear(u.pos, reach + lineWidth).where((o) => _toSegment(o.pos, u.pos, end) <= lineWidth).length;
    return on >= pierceShotK.crowd ? first.pos : null;
  }

  /// Javelin's target: the foe [javelinK].from–[javelinK].to away with the most max HP.
  Unit? _javelinTarget(Unit u) =>
      _most(_foesNear(u.pos, javelinK.to).where((o) => o.pos.distanceTo(u.pos) >= javelinK.from), (o) => o.maxHp.toDouble());

  /// How many foes Axe Throw's line, ahead of [u] out to [axeThrowK].reach, passes within [lineWidth] of.
  int _onAxeLine(Unit u) {
    final end = u.pos + Point(axeThrowK.reach, 0.0);
    return _foesNear(u.pos, axeThrowK.reach + lineWidth).where((o) => _toSegment(o.pos, u.pos, end) <= lineWidth).length;
  }

  /// Frost Storm's centre: the foe in range with the most foes within [frostStormK].radius of it (itself too),
  /// when that is [frostStormK].crowd or more.
  Unit? _frostCentre(Unit u) {
    int around(Unit o) => _foesNear(o.pos, frostStormK.radius).length;
    return _most(_foesNear(u.pos, u.stats.range).where((o) => around(o) >= frostStormK.crowd), (o) => around(o).toDouble());
  }

  /// The one of [us] with the most [by] (the first of a tie), or null.
  static Unit? _most(Iterable<Unit> us, double Function(Unit) by) =>
      us.fold<Unit?>(null, (best, o) => best == null || by(o) > by(best) ? o : best);
}
