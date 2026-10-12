part of 'game.dart';

// The Bayangan's kinds, their data (decisions-log 180 and the data batches; docs/loot-items-relics.md "Bayangan"): each
// kind's title, icon, numbers, HUD line, tiers and needs. Their rules and hooks are lib/omen.dart.

/// A Bayangan kind, the enemy buff a Pusaka card hides (enemy-buff-design.md, catalog-design §2.1 and §4,
/// catalog-bayangan-v2 §3): today's seven, then the data batches' kinds of one tier each, in their pool's order (batch
/// L-1B: the first ten Langka; L-2B: the next ten among them; L-3B: six more; L-3: Sap, then the Langka cut-over; E-1B:
/// the first ten Epik; E-2B: ten more among them; E-3B: seven more; E-3: Bat Venom, then the Epik cut-over; G-1B: the
/// first ten Legenda; G-2B: ten more among them; G-3B: seven more among them; G-3: Blight, then the Legenda cut-over).
/// [title] is its name on the HUD and in the log (the English glossary's: Spikes, Barrier and Escort, as the small
/// relics Thorns and Guard and the item Shield keep theirs; the enum names stay for saves and telemetry). [icon] is an
/// existing image's cell (none drawn: Guard shows the wave's strongest monster, as its boss bar's portrait does,
/// omen_look.dart). [k] is what one effective level E does to the enemy and the most it does at any E, for the hooks
/// (0d); [hud] its line in the HUD's tooltip (0h). [tiers] are the chest rarities whose cards may hide it: a set, one
/// tier since the Legenda cut-over ([omenOneTier]: Armor and Mend Epik's, Haste, Spikes and Wound Langka's, Barrier
/// and Escort Legenda's; until the cut-overs the seven sat in all three). [live]: a data batch switched off is in no pool. The
/// Pusaka it answers are those whose row names it ([answers]). The v2 rules (step 0j, decisions-log 192): [troopSide] (a
/// rule on the troops, [omenTroopRulesMax]), [needs] (what in the army it needs to act, [omenCanAct]) and its HUD
/// numbers beside its share ([omenShown]): [byL], [who] and [steps]. [debuff]: a troop debuff, one a pool.
enum OmenKind {
  /// Troop damage to enemies ×(1 − perE × E). The Epik pool's alone since the Legenda cut-over (it left Langka's at the
  /// Langka one).
  armor('Armor', IconRef('item_shield.png'), (perE: 0.05, max: 0.4), 'Monsters take {x}% less damage.', tiers: _epik),

  /// Enemy attack pause ÷(1 + perE × E), the floors kept. The Langka pool's alone since the Legenda cut-over (it left
  /// Epik's at the Epik one).
  haste('Haste', IconRef('item_gloves.png'), (perE: 0.05, max: 0.4), 'Monsters attack {x}% faster.', tiers: _langka),

  /// Enemies heal perE × E of their max HP a second; not the boss or the mini boss. The Epik pool's alone since the
  /// Legenda cut-over (it left Langka's at the Langka one).
  mend('Mend', IconRef('item_potion.png'), (perE: 0.003, max: 0.024), 'Monsters heal {x}% HP a second. Not the boss or mini boss.',
      tiers: _epik),

  /// A melee troop takes perE × E of the damage it deals back (at most 5% of its max HP a blow). The Langka pool's alone
  /// since the Legenda cut-over (it left Epik's at the Epik one).
  thorns('Spikes', IconRef('relic_thorns.png'), (perE: 0.03, max: 0.24), 'When a troop hits a monster up close, it takes {x}% back.',
      tiers: _langka),

  /// Troop heals in a wave ×(1 − perE × E): not the Grail, nor the heals between waves. Troop-side. The Langka pool's
  /// alone since the Legenda cut-over (it left Epik's at the Epik one).
  wound('Wound', IconRef.ui(16, 0), (perE: 0.06, max: 0.5), 'Troop heals in a wave are {x}% less.',
      troopSide: true, tiers: _langka), // the half heart

  /// The boss and the mini boss come on with a shield of perE × E of their max HP. Out of the Langka and Epik pools
  /// since their cut-overs ([_legenda]).
  shield('Barrier', IconRef('relic_guard.png', tint: tintTeal), (perE: 0.05, max: 0.4),
      'Boss and mini boss start with a barrier of {x}% of their HP.', tiers: _legenda),

  /// Each boss and mini boss brings ⌈perE × L⌉ more high elites, at most max ([byL]: 1, 1, 2, 2): it counts by L, not E.
  /// Out of the Langka and Epik pools since their cut-overs ([_legenda]).
  guard('Escort', null, (perE: 0.5, max: 2), 'Each boss and mini boss brings {n} more strong monster{s}.', byL: [1, 1, 2, 2],
      tiers: _legenda),

  // Batches L-1B (decisions-log 204), L-2B (206), L-3B (208) and L-3 (209; catalog-bayangan-v2 §3.1): twenty-seven
  // Langka kinds, in the Langka pool's order (§2), so a take's overflow follows it.

  /// A troop's blow on a monster over [omenBraceAbove] of its max HP ×(1 − perE × E). In the taken floor.
  brace('Brace', IconRef.ui(224, 0), (perE: 0.05, max: 0.3), 'Monsters over 90% HP take {x}% less damage.', tiers: _langka), // the dark shield

  /// A troop's blow on a monster under [omenStubbornBelow] of its max HP ×(1 − perE × E). In the taken floor.
  stubborn('Stubborn', IconRef.ui(32, 0), (perE: 0.06, max: 0.3), 'Monsters under 30% HP take {x}% less damage.', tiers: _langka), // the dark heart

  /// Every cut a troop takes less by (the small relic Guard's, a skill's guard, a Pusaka's `cut`) ×(1 − perE × E).
  /// Troop-side.
  sunder('Sunder', IconRef('fx_hit_armored_orc.png', x: 128), (perE: 0.08, max: 0.5), 'Troop "less damage taken" effects are {x}% weaker.',
      troopSide: true, tiers: _langka), // the rock ring, f4

  /// A monster's blow on a troop does ×(1 + perE × E) to its shields (its ward, an absorb, Mana Shield's MP): they
  /// break sooner, and what is left of the blow past them lands as it was ([Omens._omenSoak]). Batch L-2B.
  shieldbreak('Shieldbreak', IconRef('fx_hit_elite_orc.png', x: 128, size: 64), (perE: 0.12, max: 0.6),
      'Monster hits do {x}% more to troop shields.', tiers: _langka, needs: {OmenNeed.troopShield}), // the crossed bones, f2

  /// A troop's slow, stun, hold (pin), taunt, weaken or hex on a monster lasts ×(1 − perE × E), at least
  /// [effectTimeFloor].
  unshaken('Unshaken', IconRef('item_boots.png', tint: tintSteel), (perE: 0.1, max: 0.5),
      'Slows, stuns, holds, taunts and weakens on monsters end {x}% sooner.',
      tiers: _langka, needs: {OmenNeed.slow, OmenNeed.hold, OmenNeed.stun, OmenNeed.taunt, OmenNeed.weaken, OmenNeed.hex}),

  /// A high elite's skill cooldown ×(1 − perE × E): its first cast at the same time, every later one sooner.
  quickSpells('Quick Spells', IconRef.ui(160, 16, tint: tintViolet), (perE: 0.05, max: 0.3), "Strong monsters' skills come back {x}% sooner.",
      tiers: _langka),

  /// A monster's kill gold ×(1 − perE × E), rounded (a plundering troop's extra too); drops and the `loot` dice untouched.
  thrift('Thrift', IconRef.ui(112, 0, tint: tintRed), (perE: 0.04, max: 0.3), 'Monsters give {x}% less gold.', tiers: _langka), // the half coin

  /// A buff a monster gives a monster (the kinds Spellbreaker strips, [spellbreakerStrips]; a Shadow's own aside) lasts
  /// ×(1 + perE × E): the duration scaler ([FxEngine._effectTime]). Batch L-2B.
  lingering('Lingering', IconRef('fx_hit_wizard.png', x: 144, size: 48), (perE: 0.1, max: 0.5), 'Monster buffs last {x}% longer.',
      tiers: _langka), // the violet orb, f3

  /// A monster that dies gives each monster within [omenAvengeReach] of it an omen might of 1 + perE × E for
  /// [omenAvengeTime] s (one might at a time: the stronger stays; Spellbreaker strips it). In the dealt cap. Batch L-2B.
  avenge('Avenge', IconRef('fx_hit_armored_skeleton.png', x: 48, size: 48, tint: tintRed), (perE: 0.04, max: 0.2),
      'When a monster dies, monsters next to it deal {x}% more damage for ${omenAvengeTime}s.', tiers: _langka), // the burst, f1

  /// A monster's blow on a troop heals it perE × E of the HP the blow took ([Heal._healMonster], [MonsterHeal.feed]);
  /// not the boss's or a mini boss's (as Mend's). Batch L-2B.
  feed('Feed', IconRef('relic_fang.png', tint: tintRed), (perE: 0.02, max: 0.15),
      'Monsters heal {x}% of the damage they deal. Not the boss or mini boss.', tiers: _langka),

  /// A monster's blow on a troop of last wave's top killer ([Game.grudgeType], [Omens._omenTopKiller]: the type whose
  /// troops killed the most monsters, a tie to the first in [troopTypes]' order; none after a wave with no troop kill)
  /// ×(1 + perE × E). In the dealt cap. Batch L-3B.
  grudge('Grudge', IconRef.ui(176, 80), (perE: 0.04, max: 0.25), "Monsters deal {x}% more damage to last wave's top killer: {type}.",
      tiers: _langka), // the red cross

  /// A troop's blow on a werebear ×(1 − perE × E). In the taken floor.
  bearHide('Bear Hide', IconRef('tiny_werebear_idle.png', x: 41, y: 38, size: 20), (perE: 0.06, max: 0.4), 'Werebears take {x}% less damage.',
      tiers: _langka), // its idle body, cut square

  /// A monster that comes on (one raised by a necromancer or a skill aside) gets an omen might of 1 + perE × E for
  /// [omenEagerTime] s (Spellbreaker strips it). In the dealt cap. Batch L-2B.
  eager('Eager', IconRef('fx_hit_knight.png', x: 96, size: 48, tint: tintRed), (perE: 0.05, max: 0.3),
      'New monsters deal {x}% more damage for ${omenEagerTime}s.', tiers: _langka), // the star burst, f2

  /// A monster's blow on a troop that heals ([Stats.heals]: a priest) ×(1 + perE × E). In the dealt cap. Batch L-2B.
  healerHunt('Healer Hunt', IconRef('item_staff.png', tint: tintRed), (perE: 0.04, max: 0.25), 'Monsters deal {x}% more damage to Priests.',
      tiers: _langka, needs: {OmenNeed.healer}),

  /// Every [omenSapEvery]th normal attack of a monster (on [Unit.blows], Pummel's count) makes the troop it hits deal ×(1
  /// − perE × E) for [omenSapTime] s ([Omens._omenSap]: a weaken a monster put on it, so a cleanse ends it). The Langka
  /// pool's troop debuff ([debuff]): no Pusaka names it, so the tilt never aims it. Batch L-3.
  sap('Sap', IconRef('item_sword.png', tint: tintDarkRed), (perE: 0.03, max: 0.2),
      'Every ${omenSapEvery}th monster hit makes a troop deal {x}% less damage for ${omenSapTime}s.', debuff: true, tiers: _langka),

  /// A troop's blow on a monster with a shield ([FxEngine.shielded]: an absorb, a shot ward, a Barrier or a guard)
  /// ×(1 − perE × E). In the taken floor.
  hardShell('Hard Shell', IconRef('fx_hit_knight_templar.png', x: 48, size: 48, tint: tintTeal), (perE: 0.05, max: 0.3),
      'Monsters with a shield take {x}% less damage.', tiers: _langka), // the halo ring, f1

  /// Every MP price of a troop's skill (its #10 skill's, its awakening skill's, a Hero's) ×(1 + perE × E), never past
  /// its max MP ([Omens.skillCost]): what it pays, what it saves for and the price its tooltips show. Troop-side. Batch
  /// L-2B.
  spellTax('Spell Tax', IconRef.ui(176, 0), (perE: 0.05, max: 0.3), 'Troop skills cost {x}% more MP.',
      troopSide: true, tiers: _langka, needs: {OmenNeed.mpSkill}), // the dark bolt

  /// A Rare or Epic Artifact's Fx that works every few hits (every > 1; not Twin Fury's, [Fx.furyBeat]) needs n more
  /// hits, n by L ([byL]: 1, 1, 2, 2; a count, so the Beban factor doesn't scale it): [FxEngine._everyOf]. A Legendary
  /// one's never. Troop-side. Batch L-2B.
  offBeat('Off Beat', IconRef('relic_warDrum.png', tint: tintViolet), (perE: 0, max: 0),
      '${Words.rare} and ${Words.epic} ${Words.artifact}s that work every few hits need {n} more hit{s}.',
      byL: [1, 1, 2, 2], troopSide: true, tiers: _langka, needs: {OmenNeed.everyFx}),

  /// A Rare or Epic Artifact's Fx on its own cooldown ([FxBound.cd]) waits ×(1 + perE × E) before its next
  /// ([FxEngine._fxGate]); a Legendary one's never, nor a once-a-wave Fx or a skill's cooldown. Troop-side. Batch L-3B.
  drag('Drag', IconRef.ui(64, 0, tint: tintOlive), (perE: 0.1, max: 0.5),
      '${Words.rare} and ${Words.epic} ${Words.artifact}s that work every few seconds wait {x}% longer.',
      troopSide: true, tiers: _langka, needs: {OmenNeed.cdFx}), // the half star

  /// In a wave a troop's heals stop at 1 − perE × E of its max HP ([Omens.healCeil]): a heal never lowers its HP, what
  /// it gives past full is still counted against its max HP, and a healer passes over a troop at its ceiling. Not the
  /// Grail's save nor the heals between waves. Troop-side. Batch L-3B.
  scar('Scar', IconRef.ui(0, 0, tint: tintDarkGreen), (perE: 0.05, max: 0.15), "In a wave, heals can't fill the last {x}% of a troop's HP.",
      troopSide: true, tiers: _langka, needs: {OmenNeed.heal}), // the heart

  /// Each monster cancels every nth of the normal troop attacks on it, n by L ([byL]: 12, 8, 6, 5): a count, so the
  /// Beban factor doesn't scale it, and no share. Out of the taken floor.
  deflect('Deflect', IconRef('fx_hit_swordsman.png', x: 256, size: 64, tint: tintSilver), (perE: 0, max: 0),
      'Each monster ignores every {n}th troop attack on it. Skills still land.', byL: [12, 8, 6, 5], tiers: _langka), // the crossed blades, f4

  /// A monster that kills a troop heals perE × E of its max HP ([Omens._omenGloat], [MonsterHeal.gloat]); not the boss or
  /// a mini boss (by rank), and nothing for a troop that falls to no one. Batch L-3B.
  gloat('Gloat', IconRef.ui(80, 16, tint: tintDarkRed), (perE: 0.05, max: 0.15),
      'A monster that kills a troop heals {x}% HP. Not the boss or mini boss.', tiers: _langka), // the cup

  /// A high elite heals perE × E of its max HP each time its skill lands ([Omens._omenRekindle], [MonsterHeal.rekindle]);
  /// a wind-up broken off heals nothing, and the boss's and the mini boss's skills never. Batch L-3B.
  rekindle('Rekindle', IconRef('fx_upgrade.png', x: 384, size: 64, tint: tintGreen), (perE: 0.03, max: 0.15),
      'A strong monster heals {x}% HP each time it uses a skill.', tiers: _langka), // the sword and plus, f6

  /// Every [omenPummelEvery]th normal attack of a monster ([Omens._omenPummel], on [Unit.blows]) ×(1 + perE × E) on the
  /// troop it hits; a skill's blow never counts. Not the boss's or a mini boss's (by rank). In the dealt cap. Batch L-3B.
  pummel('Pummel', IconRef('fx_hit_orc_rider.png', x: 192, size: 64, tint: tintRed), (perE: 0.1, max: 0.3),
      'Every ${omenPummelEvery}rd hit of a monster deals {x}% more. Not the boss or mini boss.', tiers: _langka), // the club, f3

  /// A troop's shields shrink each second by perE × E of what is left: its ward and an absorb's soak ([Omens._omenFade],
  /// stunned or busy too); Mana Shield's MP never. Troop-side. Batch L-2B.
  fade('Fade', IconRef.ui(208, 0, tint: tintViolet), (perE: 0.02, max: 0.08), 'Troop shields shrink by {x}% each second.',
      troopSide: true, tiers: _langka, needs: {OmenNeed.troopShield}), // the half shield

  /// A monster under a troop's taunt deals that troop ×(1 + perE × E), the boss and the mini boss [omenDefiantBoss] of
  /// it. In the dealt cap.
  defiant('Defiant', IconRef.ui(208, 32, tint: tintOrange), (perE: 0.06, max: 0.25),
      'A monster made to fight a troop deals it {x}% more. Bosses: half.', tiers: _langka, needs: {OmenNeed.taunt}),

  /// A monster's blow on a troop ×(1 + perE × E) while no other monster stands within [omenStragglerTiles] tiles of it
  /// ([FxEngine.alliesNearOf], the same-side count); not the boss's or a mini boss's (by rank). In the dealt cap. Batch
  /// L-2B.
  straggler('Straggler', IconRef('relic_fury.png', tint: tintOrange), (perE: 0.06, max: 0.3),
      'A monster alone (none within $omenStragglerTiles tiles) deals {x}% more. Not bosses.', tiers: _langka),

  // Batches E-1B (decisions-log 210), E-2B (212), E-3B (219) and E-3 (223; catalog-bayangan-v2 §3.2): twenty-eight Epik
  // kinds, in the Epik pool's order (§2) after today's Armor and Mend, Bat Venom in its place among them.

  /// A monster's blow on a troop under [omenPreyBelow]% of its max HP (before the blow) ×(1 + perE × E). In the dealt
  /// cap. Batch E-3B.
  prey('Prey', IconRef('fx_hit_swordsman.png', x: 256, size: 64, tint: tintRed), (perE: 0.06, max: 0.4),
      'Monsters deal {x}% more damage to troops under $omenPreyBelow% HP.', tiers: _epik), // the crossed blades, f4

  /// A monster healer's heal ([Stats.heals]: its [Stats.dmg], which its heal and Mass Mend read) ×(1 + perE × E): a stat
  /// kind ([Omens.spawnStats]), so outside the dealt cap.
  darkHymn('Dark Hymn', IconRef('item_staff.png', tint: tintDarkGreen), (perE: 0.08, max: 0.4), 'Monster healers heal {x}% more.',
      tiers: _epik),

  /// A skeleton archer's damage ×(1 + perE × E), its range kept: a stat kind ([Omens.spawnStats]), outside the dealt
  /// cap.
  boneArrows('Bone Arrows', IconRef('tiny_skeleton_archer_idle.png', x: 41, y: 38, size: 22), (perE: 0.08, max: 0.4),
      'Skeleton Archers deal {x}% more damage.', tiers: _epik), // its idle body, cut square

  /// A monster that comes on (a raised one too) takes ×(1 − perE × E) from the troops that shoot, arrows and spells, for
  /// [omenArrowWardTime] s: an omen shot ward ([Status.shotWard], [Omens._omenSpawn]; Spellbreaker strips it). Not in
  /// the taken floor.
  arrowWard('Arrow Ward', IconRef('item_bow.png', tint: tintOlive), (perE: 0.08, max: 0.5),
      'New monsters take {x}% less from arrows and spells for ${omenArrowWardTime}s.', tiers: _epik),

  /// A monster below a mini boss (by rank) at or under [omenSecondSkinAt]% of its HP for the first time gets an omen
  /// absorb of perE × E of its max HP for [omenSecondSkinTime] s ([Omens._omenBelow]; Spellbreaker strips it). Batch
  /// E-2B.
  secondSkin('Second Skin', IconRef.ui(208, 0, tint: tintTeal), (perE: 0.03, max: 0.2),
      'Monsters at half HP get a {x}% HP shield for ${omenSecondSkinTime}s, once. Not bosses.', tiers: _epik), // the half shield

  /// A slime that dies hurts each troop within [omenBileReach] of it for perE × E of its max HP, from no one, through
  /// its defence and cuts, a troop at most once every [omenBileEvery] s ([Omens._omenBile]). Batch E-2B.
  bileSacs('Bile Sacs', IconRef('tiny_slime_idle.png', x: 36, y: 39, size: 24, tint: tintGreen), (perE: 0.02, max: 0.12),
      'A Slime that dies hurts troops next to it for {x}% of their max HP.', tiers: _epik), // its idle body, cut square

  /// A werewolf or a werebear that comes on (a raised one too) heals perE × E of what it deals for [omenBloodMoonTime]
  /// s: an omen lifesteal ([Omens._omenSpawn]; Spellbreaker strips it), healed through the monster funnel
  /// ([MonsterHeal.bloodMoon]). Batch E-2B.
  bloodMoon('Blood Moon', IconRef('tiny_werewolf_idle.png', x: 41, y: 35, size: 28, tint: tintRed), (perE: 0.05, max: 0.3),
      'New Werewolves and Werebears heal {x}% of what they deal for ${omenBloodMoonTime}s.', tiers: _epik), // its idle body, cut square

  /// A mark a troop puts on a monster (Hunter's Mark's [Status.vulnerable], Void Eye's [Status.voidMark]; Ember Brand's
  /// when it comes) lasts ×(1 − perE × E), at least [effectTimeFloor]: the duration scaler ([FxEngine._effectTime]).
  /// Batch E-2B.
  markWard('Mark Ward', IconRef.ui(128, 0, tint: tintRed), (perE: 0.1, max: 0.5), 'Marks on monsters end {x}% sooner.',
      tiers: _epik, needs: {OmenNeed.mark}), // the dark disc

  /// A monster's blow on a troop whose type has [omenHerdHuntAt] or more troops alive ([Omens._omenHerdHunt])
  /// ×(1 + perE × E). In the dealt cap. Batch E-3B.
  herdHunt('Herd Hunt', IconRef('fx_hit_orc_rider.png', x: 192, size: 64), (perE: 0.04, max: 0.3),
      'Monsters deal {x}% more damage to a type with $omenHerdHuntAt+ troops alive.', tiers: _epik), // the club, f3

  /// A monster below a mini boss (by rank) at or under [omenLastRageAt]% of its HP for the first time gets an omen might
  /// of 1 + perE × E for [omenLastRageTime] s ([Omens._omenBelow]; Spellbreaker strips it). In the dealt cap. Batch E-2B.
  lastRage('Last Rage', IconRef('relic_fury.png'), (perE: 0.1, max: 0.4),
      'A monster under $omenLastRageAt% HP deals {x}% more damage for ${omenLastRageTime}s. Not bosses.', tiers: _epik),

  /// A monster that dies heals each monster below a mini boss (by rank) within [omenPartingGiftReach] of it perE × E of
  /// its max HP, through the monster funnel ([MonsterHeal.partingGift]), a monster at most once every
  /// [omenPartingGiftEvery] s ([Omens._omenPartingGift]). Batch E-2B.
  partingGift('Parting Gift', IconRef('tiny_fx_heal.png', x: 136, y: 32, size: 30, tint: tintViolet), (perE: 0.03, max: 0.15),
      'When a monster dies, monsters near it heal {x}% HP. Not bosses.', tiers: _epik), // the sparkle, f1

  /// A skeleton kind's ([skeletonKinds]) max HP ×(1 + perE × E), any rank, a raised one too: a stat kind
  /// ([Omens.spawnStats]), so outside the taken floor. Batch E-3B.
  oldBones('Old Bones', IconRef('tiny_skeleton_idle.png', x: 42, y: 35, size: 28), (perE: 0.08, max: 0.4), 'Skeletons have {x}% more HP.',
      tiers: _epik), // its idle body, cut square

  /// A bat's normal attack that lands on a troop makes it lose perE × E of its max HP a second for [omenBatVenomTime] s
  /// ([Omens._omenVenom]: a bleed a monster put on it, from no one, so a troop's cleanse ends it: Saint's Tear). The Epik
  /// pool's troop debuff ([debuff]): no Pusaka names it, so the tilt never aims it. Batch E-3.
  batVenom('Bat Venom', IconRef('tiny_bat_idle.png', x: 37, y: 32, size: 24, tint: tintGreen), (perE: 0.01, max: 0.04),
      'A Bat bite makes a troop lose {x}% max HP a second for ${omenBatVenomTime}s.', debuff: true, tiers: _epik), // its idle body, cut square

  /// A troop's blow on a raised monster ([Unit.raisedBy]: a necromancer's minion, Split's, Swarm's, Grave Call's) while
  /// the one that raised it lives ×(1 − perE × E). In the taken floor. Batch E-3B.
  gravePact('Grave Pact', IconRef('fx_hit_necromancer.png', x: 128, size: 64), (perE: 0.05, max: 0.3),
      'While its raiser lives, a raised monster takes {x}% less damage.', tiers: _epik), // the skull, f2

  /// A troop's blow on a monster with a living high elite (not itself) within [omenCaptainReach] of it ([Omens._captained],
  /// the same-side count of the high elites) ×(1 − perE × E). In the taken floor. Batch E-2B.
  captain('Captain', IconRef.ui(96, 16, tint: tintDarkRed), (perE: 0.04, max: 0.25), 'Monsters near a strong monster take {x}% less damage.',
      tiers: _epik), // the sword

  /// A monster's blow on a troop ×(1 + perE × E) once [omenEnrageAfter] s have passed since its first blow
  /// ([Omens.omenEnraged]: its might's amber ring shows it); not the boss's or a mini boss's (by rank). In the dealt cap.
  enrage('Enrage', IconRef('fx_hit_armored_axeman.png', x: 128, size: 64), (perE: 0.06, max: 0.3),
      'A monster that has fought for ${omenEnrageAfter}s deals {x}% more damage. Not bosses.', tiers: _epik), // the axe burst, f2

  /// A troop's heal in a wave owes perE × E of the HP it gives ([Unit.siphonDue], measured after Wound and Scar's
  /// ceiling; a Trickle heal's in full at the call), paid every [omenHealSiphonEvery] s to the nearest monster below a
  /// mini boss within [omenHealSiphonReach] of the troop through the monster funnel ([MonsterHeal.siphon]); none in
  /// reach: dropped ([Omens._omenSiphon]). Batch E-3B.
  healSiphon('Heal Siphon', IconRef('tiny_fx_heal.png', x: 136, y: 32, size: 30, tint: tintOlive), (perE: 0.05, max: 0.3),
      'The nearest monster (not a boss) gets {x}% of each troop heal.', tiers: _epik, needs: {OmenNeed.heal}), // the sparkle, f1

  /// A troop's blow on a monster that a slow, a hold or a stun holds ([FxEngine.held]) ×(1 − perE × E). In the taken
  /// floor.
  hunker('Hunker', IconRef('item_shield.png', tint: tintSteel), (perE: 0.05, max: 0.2), 'Slowed, held or stunned monsters take {x}% less damage.',
      tiers: _epik, needs: {OmenNeed.slow, OmenNeed.hold, OmenNeed.stun}),

  /// A troop's skill (its #10 skill, its awakening skill, a Hero's) shields each high elite within
  /// [omenCounterspellReach] of it: an omen absorb of perE × E of its max HP for [omenCounterspellTime] s, each at most
  /// once every [omenCounterspellEvery] s ([Omens._omenCounterspell]; Spellbreaker strips it, Unholy Ward's bigger ward
  /// still lands).
  counterspell('Counterspell', IconRef.ui(176, 16, tint: tintTeal), (perE: 0.03, max: 0.12),
      "A troop's skill shields strong monsters near it: {x}% HP for ${omenCounterspellTime}s.",
      tiers: _epik, needs: {OmenNeed.mpSkill}),

  /// A monster that dies (not inside a burst or a leap, [Game._fxDepth]) guards each monster within
  /// [omenCloseRanksReach] of it: perE × E less taken for [omenCloseRanksTime] s, a guard with [Unit.guardOmen] (the
  /// stronger guard stays, so it never stacks on a skill's), before the killer's `kill` Fx ([Omens._omenCloseRanks]). In
  /// the taken floor while it holds the guard slot. Batch E-2B.
  closeRanks('Close Ranks', IconRef('fx_hit_armored_orc.png', x: 128, tint: tintSteel), (perE: 0.04, max: 0.15),
      'Monsters next to one that dies take {x}% less damage for ${omenCloseRanksTime}s.', tiers: _epik), // the rock ring, f4

  /// A monster's normal attack on a troop also deals perE × E of the troop's max HP, at most [omenWearDownBlow] × the
  /// blow (after its might), before the troop's defence ([Omens._omenDealt]). In the dealt cap.
  wearDown('Wear Down', IconRef.ui(0, 0, tint: tintDarkRed), (perE: 0.0015, max: 0.01), "Monster hits also deal {x}% of the troop's max HP.",
      tiers: _epik), // the heart

  /// A monster's blow on a troop that struck another monster less than [omenBlindsideBusy] s ago ([Unit.lastFoe])
  /// ×(1 + perE × E). In the dealt cap. Batch E-2B.
  blindside('Blindside', IconRef('fx_hit_werewolf.png', x: 64, size: 64), (perE: 0.03, max: 0.15),
      'Monsters deal {x}% more damage to a troop fighting another monster.', tiers: _epik), // the claw, f1

  /// A monster's blow on a troop with a damage or speed boost (a [Status.might] over 1 or a [Status.haste] under 1,
  /// from anything) ×(1 + perE × E). In the dealt cap.
  envy('Envy', IconRef.ui(144, 48, tint: tintDarkRed), (perE: 0.04, max: 0.25),
      'Monsters deal {x}% more damage to troops with a damage or speed boost.', tiers: _epik, needs: {OmenNeed.mightOrHaste}),

  /// A troop's heal in a wave of [omenTrickled]'s kinds comes in over perE × E s, at most max s (seconds, not a share:
  /// the HUD's `{sec}`), each its own entry ([TrickleHeal], [Heal._healTroop]); the rest land at once. Troop-side.
  /// Batch E-3B.
  trickle('Trickle', IconRef('item_potion.png', tint: tintOlive), (perE: 0.4, max: 2),
      'Troop heals in a wave come in over {sec}s, not all at once.', troopSide: true, tiers: _epik, needs: {OmenNeed.heal}),

  /// A troop that kills a monster loses perE × E of its max HP, through its defence, at most once every [omenTollEvery]
  /// s and never below [omenTollAbove]% of it ([Omens._omenToll]). Troop-side. Batch E-3B.
  toll('Toll', IconRef('fx_hit_necromancer.png', x: 192, size: 64), (perE: 0.01, max: 0.04),
      'A troop that kills a monster loses {x}% of its max HP (not below $omenTollAbove%).',
      troopSide: true, tiers: _epik), // the skull, f3

  /// A monster that a monster healer's heal or Mass Mend gave HP gets an omen might of 1 + perE × E for [omenZealTime] s
  /// ([Omens._omenZeal]; the other monster heals never). In the dealt cap.
  zeal('Zeal', IconRef('item_staff.png', tint: tintGold), (perE: 0.05, max: 0.3),
      'Monsters healed by a monster healer deal {x}% more damage for ${omenZealTime}s.', tiers: _epik),

  /// A troop that falls hastens each monster below a mini boss (by rank) within [omenTriumphReach] of it: an omen haste
  /// of 1 / (1 + perE × E) for [omenTriumphTime] s ([Omens._omenTriumph]; one haste at a time, the stronger stays;
  /// Spellbreaker strips it; [Game.attackEvery]'s floors kept), its mint ring the field's. Batch E-2B.
  triumph('Triumph', IconRef('item_gloves.png', tint: tintPop), (perE: 0.05, max: 0.2),
      'A troop falls: monsters near it attack {x}% faster for ${omenTriumphTime}s. Not bosses.', tiers: _epik),

  /// A boss or mini boss (by rank) at or under [omenMusterAt]% of its HP for the first time gives every other monster
  /// within [omenMusterReach] of it an omen might of 1 + perE × E for [omenMusterTime] s ([Omens._omenMuster]). In the
  /// dealt cap.
  muster('Muster', IconRef('relic_dragonCrown.png', tint: tintRed), (perE: 0.05, max: 0.3),
      'At $omenMusterAt% HP, a boss or mini boss gives monsters near +{x}% damage for ${omenMusterTime}s.', tiers: _epik),

  // Batches G-1B (decisions-log 226), G-2B (236), G-3B (239) and G-3 (243; catalog-bayangan-v2 §3.3): twenty-eight
  // Legenda kinds, in the Legenda pool's order (§2) after today's Barrier and Escort, Blight in its place among them.

  /// A troop's skill blow on a monster ([Hit.skill]: its #10 skill's, its awakening skill's, a Hero's; Holy Nova's and
  /// Judgement's too, a caster fallen since or not) ×(1 − perE × E). In the taken floor. Batch G-3B.
  spellWard('Spell Ward', IconRef.ui(208, 16), (perE: 0.06, max: 0.36), 'Troop skills do {x}% less damage to monsters.',
      tiers: _legenda, needs: {OmenNeed.mpSkill}), // the orange book

  /// A troop's extra hit on a monster ([Hit.extra]: a splash past its target, a Pusaka's leap or burst) ×(1 − perE ×
  /// E). In the taken floor.
  scatter('Scatter', IconRef('fx_hit_orc.png', x: 40, size: 40, tint: tintSilver), (perE: 0.08, max: 0.4),
      'Extra hits (jumps, blasts, hits near the target) do {x}% less.', tiers: _legenda, needs: {OmenNeed.extraHit}), // the splash, f1

  /// A troop healer's smite ([Hit.smite]: a Priest's holy light on the undead) on a skeleton kind ([skeletonKinds], any
  /// rank) ×(1 − perE × E); Holy Nova's and Judgement's blows are skills (Spell Ward's). In the taken floor. Batch G-3B.
  holyWard('Holy Ward', IconRef('tiny_skeleton_idle.png', x: 42, y: 35, size: 28, tint: tintViolet), (perE: 0.06, max: 0.4),
      'Skeletons take {x}% less damage from Priests.', tiers: _legenda, needs: {OmenNeed.healer}), // its idle body, cut square

  /// A troop's blow on the boss or a mini boss (by rank) with another living monster within [omenCoverReach] of it
  /// ([Omens._omenCover], the same-side count) ×(1 − perE × E). In the taken floor. Batch G-2B.
  cover('Cover', IconRef('fx_hit_knight_templar.png', x: 48, size: 48, tint: tintRed), (perE: 0.05, max: 0.3),
      'Boss and mini boss take {x}% less damage with a monster next to them.', tiers: _legenda), // the halo ring, f1

  /// A monster's blow on a Hero ([Unit.hero]) ×(1 + perE × E). In the dealt cap. Batch G-3B.
  heroHunt('Hero Hunt', IconRef.ui(64, 16, tint: tintRed), (perE: 0.08, max: 0.5), 'Monsters deal {x}% more damage to Heroes.',
      tiers: _legenda, needs: {OmenNeed.hero}), // the crown

  /// A troop's hit back on a monster ([Hit.hitBack]: worn thorns, a reflect, a Parry's answer, Riposte's) ×(1 − perE ×
  /// E). In the taken floor.
  thornproof('Thornproof', IconRef('relic_thorns.png', tint: tintSilver), (perE: 0.12, max: 0.6),
      'Damage troops send back does {x}% less to monsters.', tiers: _legenda, needs: {OmenNeed.hitBack}),

  /// The boss's or a mini boss's (by rank, a raised one too) normal or skill blow that lands on a troop stops its heals in
  /// a wave for perE × E s, at most max s ([omenDebuffMax]; seconds, not a share: the HUD's `{sec}`): a [Status.noHeal]
  /// a monster put on it ([Omens._omenBlight]; [Effect.bad], so a troop's cleanse ends it), its heal ceiling its HP
  /// while it lasts ([Omens.healCeil]: no healer picks it, the heal funnel gives it nothing, [Heal._healTroop]; never the
  /// Grail's save nor the heals between waves), its body olive. The Legenda pool's troop debuff ([debuff]), and its heal
  /// penalty on the tilt: Vampire Kiss's counter. Batch G-3.
  blight('Blight', IconRef('fx_hit_slime.png', x: 399, y: 18, size: 30, tint: tintOlive), (perE: 0.75, max: 3),
      'A boss or mini boss hit stops heals on that troop for {sec}s.', debuff: true, tiers: _legenda), // the splat, f6

  /// A monster that a troop's strip took a good effect or its guard off (Spellbreaker's arrow, Null Stone's, Spell
  /// Cutter's) gets a shield of perE × E of its max HP, once a life ([Omens._omenRenewal], [Unit.renewed]): the Barrier's
  /// own soak ([Unit.shield]), which no strip takes. Batch G-2B.
  renewal('Renewal', IconRef('fx_hit_wizard.png', x: 144, size: 48, tint: tintTeal), (perE: 0.04, max: 0.25),
      'Once, a monster that loses its good effects gets a {x}% HP shield.', tiers: _legenda), // the orb, f3

  /// What a troop's worn small relics do ×(1 − perE × E) ([Omens._omenRust]): fang's heal, thorns' hit back, guard's cut
  /// and fury's extra on its beat. Troop-side.
  rust('Rust', IconRef.ui(48, 16, tint: tintRust), (perE: 0.1, max: 0.6), 'Small relics on troops work {x}% less.',
      troopSide: true, tiers: _legenda, needs: {OmenNeed.smallRelic}), // the wrench

  /// A melee monster's normal attack on a troop also hits the nearest other living troop within [omenSideSwingReach] of
  /// it for perE × E of the blow, from no one ([Hit.extra]: nothing answers it and it never swings on), through that
  /// troop's own defence and cuts ([Omens._omenSideSwing]). Batch G-2B.
  sideSwing('Side Swing', IconRef('fx_hit_greatsword_skeleton.png', x: 384, size: 64), (perE: 0.06, max: 0.3),
      'Monster up-close hits also hit the troop next to it for {x}%.', tiers: _legenda), // the sword sweep, f6

  /// While an oath is held ([Relic.oath]: Oath of One, Alliance), the boss's and a mini boss's max HP (by rank, a raised
  /// one too) ×(1 + perE × E): a stat kind ([Omens.spawnStats]), so outside the taken floor. Batch G-3B.
  oathbane('Oathbane', IconRef('relic_oathOfOne.png', tint: tintDarkRed), (perE: 0.06, max: 0.3),
      'While you hold an ${Words.oath}, boss and mini boss have {x}% more HP.', tiers: _legenda, needs: {OmenNeed.oath}),

  /// The wave's elite share is perE × E more on the same draw ([Game.startWave]'s rank): that many more of the normal
  /// monsters come silver; never a high elite more.
  veterans('Veterans', IconRef.ui(80, 0), (perE: 0.03, max: 0.15), '{x}% more monsters are silver (stronger).', tiers: _legenda), // the dark star

  /// The boss or a mini boss (by rank, a raised one too) at or under [omenLastGaspAt]% of its HP for the first time heals
  /// perE × E of its max HP through the monster funnel ([MonsterHeal.lastGasp]: Grave Seal's noHeal stops it), once
  /// ([Omens._omenLastGasp]). Batch G-3B.
  lastGasp('Last Gasp', IconRef('relic_lastStand.png', tint: tintDarkRed), (perE: 0.03, max: 0.15),
      'Once, at $omenLastGaspAt% HP, boss and mini boss heal {x}% HP.', tiers: _legenda), // Iron Will's heart, darkened

  /// An orc rider's ([omenRiderRushType]) first normal or skill blow on a troop ×(1 + perE × E), once a monster
  /// ([Unit.rushed], [Omens._omenRiderRush]). In the dealt cap. Batch G-3B.
  riderRush('Rider Rush', IconRef('tiny_orc_rider_idle.png', x: 37, y: 27, size: 32), (perE: 0.12, max: 0.5),
      "An Orc Rider's first hit deals {x}% more.", tiers: _legenda), // its idle body, cut square

  /// An elite's and a high elite's max HP ×(1 + perE × E), a raised one too: a stat kind ([Omens.spawnStats]), so
  /// outside the taken floor.
  hardy('Hardy', IconRef.ui(0, 0, tint: tintViolet), (perE: 0.05, max: 0.3), 'Silver and gold monsters have {x}% more HP.',
      tiers: _legenda), // the heart

  /// Each monster shrugs off the first n holds, stuns or hexes a troop puts on it, n by L ([byL]: 1, 1, 2, 2; a count, so
  /// the Beban factor doesn't scale it): [Unit.shrugs], set as it comes on ([Omens._omenShrug]).
  unbowed('Unbowed', IconRef.ui(208, 80, tint: tintSteel), (perE: 0, max: 0), 'Each monster ignores its first {n} hold{s}, stun{s} or hex{es}.',
      byL: [1, 1, 2, 2], tiers: _legenda, needs: {OmenNeed.hold, OmenNeed.stun, OmenNeed.hex}), // the no sign

  /// A monster's blow on a troop under perE × E of its max HP (before the blow) meets no shield, block or cut of the
  /// troop's ([Omens._omenBare]: its ward, an absorb, Mana Shield, a block, a guard, a cut Fx, a cap over 0); its
  /// defence and a cap-0 window (the Grail's save) still hold. Troop-side.
  executioner('Executioner', IconRef('fx_hit_necromancer.png', x: 192, size: 64, tint: tintDarkRed), (perE: 0.05, max: 0.2),
      'Troops under {x}% HP get no shield, block or "less damage taken".', troopSide: true, tiers: _legenda), // the skull, f3

  /// A monster's blow on a troop ×(1 + perE × E) while a troop's Pusaka mark is on it ([Omens._omenSpite]: Ember Brand's;
  /// Vengeance Mark's when it comes). In the dealt cap.
  spite('Spite', IconRef('fx_hit_werewolf.png', x: 64, size: 64, tint: tintRust), (perE: 0.06, max: 0.3),
      'Monsters marked by Vengeance Mark or Ember Brand deal {x}% more damage.', tiers: _legenda, needs: {OmenNeed.spiteMark}), // the claw, f1

  /// A silver or gold monster (by rank, a raised one too) that a blow would kill is left at 1 HP once a life
  /// ([Unit.omenSaved]) and takes no blow for perE × E s, at most max s (seconds, not a share: the HUD's `{sec}`): an
  /// omen cap at 0 ([Status.cap], the Grail's; no strip takes it), right after the blow's HP change, so killHeal and the
  /// Pusaka's counters see a blow that did not kill, and no gold or drop comes until its real death ([Omens._omenDeathless]).
  /// Batch G-2B.
  deathless('Deathless', IconRef.ui(80, 16, tint: tintTeal), (perE: 0.2, max: 1.2),
      'Silver and gold monsters survive 1 deadly hit: no damage for {sec}s.', tiers: _legenda), // the cup

  /// The part of a troop's blow past [omenBluntOver]% of a silver, gold or boss monster's max HP ×(1 − perE × E); a
  /// normal one's and a smaller blow untouched. In the taken floor (as the blow's new / old).
  blunt('Blunt', IconRef('relic_dragonCrown.png', tint: tintSteel), (perE: 0.06, max: 0.3),
      'Silver, gold and bosses take {x}% less of a hit past $omenBluntOver% of their HP.', tiers: _legenda),

  /// A troop's normal or skill blow on a monster ×(1 − perE × E × run): its run ([Unit.adaptRun]) is how many blows in a
  /// row past the first came from the same troop type, at most [omenAdaptSteps] ([steps], the HUD's `{cap}`); a blow of
  /// another type sets it to 0 ([Omens._omenAdapt]). Extra hits, bleeds and hit backs neither count nor take the cut. In
  /// the taken floor. Batch G-2B.
  adapt('Adapt', IconRef.ui(48, 16, tint: tintTeal), (perE: 0.02, max: 0.1),
      'Each hit in a row from one troop type does {x}% less, up to {cap}%.', steps: omenAdaptSteps, tiers: _legenda), // the wrench

  /// A monster's blow on a troop ×(1 + perE × E) while the wave's boss or mini boss lives ([Omens._omenWarlord]: a living
  /// one of [Game.bossBarUnits]', found once a tick); not the boss's or a mini boss's own (by rank), a raised minion's
  /// too. In the dealt cap. Batch G-2B.
  warlord('Warlord', IconRef('relic_warDrum.png', tint: tintDarkRed), (perE: 0.04, max: 0.25),
      'While a boss or mini boss lives, other monsters deal {x}% more damage.', tiers: _legenda),

  /// A silver or gold monster (by rank) that kills a troop counts it ([Unit.troopKills], at most [omenSpreeKills]:
  /// [steps], the HUD's `{cap}`), and its blows on troops are ×(1 + perE × E × its kills) for its life
  /// ([Omens._omenSpree]); a red ring under it shows it. In the dealt cap. Batch G-2B.
  spree('Spree', IconRef('fx_upgrade.png', x: 384, size: 64, tint: tintPop), (perE: 0.03, max: 0.1),
      'Each kill gives a silver or gold monster {x}% more damage, up to {cap}%.', steps: omenSpreeKills, tiers: _legenda), // the sword and plus, f6

  /// A monster of the ranks its level L names ([omenVulturesRanks]: L1-2 the high elites, L3-4 the elites too; never the
  /// boss or a mini boss; [who], the HUD's `{who}`) goes for the troop with the lowest HP share it reaches (a tie: the
  /// nearest; one that shoots, among those within [omenVulturesNear] of its current target), and keeps it until it falls
  /// or leaves its reach, or until its next attack ([Omens._omenVultures], [Meet._monsterFoe]). No number; no die. Batch
  /// G-2B.
  vultures('Vultures', IconRef.ui(16, 0, tint: tintOlive), (perE: 0, max: 0), '{who} monsters hit the most hurt troop they can reach.',
      who: ['Strong', 'Strong', 'Silver and gold', 'Silver and gold'], tiers: _legenda), // the half heart

  /// A monster's normal or skill blow on a troop with MP takes perE × E of its max MP (never below 0), a troop at most
  /// once every [omenManaBurnEvery] s ([Unit.burnAt], [Omens._omenManaBurn]): an instant loss, as Soul Rend's, outside
  /// the effects. Troop-side. Batch G-2B.
  manaBurn('Mana Burn', IconRef.ui(144, 0, tint: tintOrange), (perE: 0.005, max: 0.03), "Each monster hit takes {x}% of the troop's max MP.",
      troopSide: true, tiers: _legenda, needs: {OmenNeed.mpSkill}), // the bolt

  /// A monster's blow on a troop ×(1 + perE × E) from [omenDuskAfter] s after the wave's last crowd monster came on (not
  /// the boss or a mini boss, a Guard's or an escort: [Game.duskOn], [Omens._omenDusk]); not the boss's or a mini boss's
  /// own (by rank). It reads the wave's queue and never moves the spawns; a line in the battle log when it falls
  /// ([OmenDusk]). In the dealt cap. Batch G-3B.
  dusk('Dusk', IconRef.ui(64, 0, tint: tintViolet), (perE: 0.04, max: 0.3),
      '${omenDuskAfter}s after the crowd is all in, monsters (not bosses) deal {x}% more.', tiers: _legenda), // the half star

  /// A troop's skill (its #10 skill, its awakening skill, a Hero's) raises each monster within [omenBacklashTiles] tiles
  /// of it: an omen might of 1 + perE × E for [omenBacklashTime] s, a monster at most once every [omenBacklashEvery] s
  /// ([Unit.backlashAt], [Omens._omenBacklash]; one might at a time, the stronger stays; Spellbreaker strips it). In the
  /// dealt cap. Batch G-2B.
  backlash('Backlash', IconRef.ui(160, 0, tint: tintRed), (perE: 0.04, max: 0.25),
      'A troop skill: monsters within $omenBacklashTiles tiles deal {x}% more damage for ${omenBacklashTime}s.',
      tiers: _legenda, needs: {OmenNeed.mpSkill}), // the half bolt

  /// A troop's blow on a monster ×(1 − perE × E × steps), a step every [omenHordePer] monsters alive, at most
  /// [omenHordeSteps] ([steps], the HUD's `{cap}`; [Omens._omenHorde]); the boss and mini boss too. In the taken floor.
  horde('Horde', IconRef('fx_hit_orc.png', x: 40, size: 40, tint: tintRed), (perE: 0.015, max: 0.06),
      'Each $omenHordePer monsters alive make monsters take {x}% less damage, up to {cap}%.',
      steps: omenHordeSteps, tiers: _legenda); // the splash, f1

  const OmenKind(this.title, this.icon, this.k, this.hud,
      {this.troopSide = false,
      this.debuff = false,
      this.byL = const [],
      this.who = const [],
      this.steps = 0,
      required this.tiers,
      this.needs = const {}});

  final String title;
  final IconRef? icon;
  final ({double perE, double max}) k;

  /// Its line in the HUD's tooltip after its title and level ("Armor 2: ", [Omens.omenLine]): what it does now, its
  /// numbers from [omenShown] ([Omens.omenEffect]): `{x}` its share in percent (`{sec}` in seconds, Trickle's time),
  /// `{n}` its count and `{s}` / `{es}` that count's plural ending, `{who}` its rank word, `{cap}` its named total in percent;
  /// Grudge's `{type}` its target's name.
  final String hud;

  /// A rule on the troops (their heals, shields, Fx), not on the monsters: at most [omenTroopRulesMax] such kinds held at
  /// once ([omenPlace]).
  final bool troopSide;

  /// A troop debuff (catalog-design §2.5): a bad effect a monster puts on a troop, which a troop's cleanse ends, at most
  /// [omenDebuffMax] s. One a pool: Sap in Langka and Bat Venom in Epik, which no Pusaka names as its counter, so the
  /// tilt never aims them; Blight in Legenda, the pool's heal penalty on the tilt (Vampire Kiss's counter,
  /// catalog-bayangan-v2 §4).
  final bool debuff;

  /// Its count by level, L1 to L4 ([omenShown]'s `{n}`): a count goes by L, so the Beban factor doesn't scale it.
  final List<num> byL;

  /// What in the army it needs to act, any one of them ([omenCanAct]); none: it always acts. A face is drawn only from
  /// the kinds that can act ([Omens._faces]).
  final Set<OmenNeed> needs;

  /// Its rank word by level, L1 to L4 ([omenShown]'s `{who}`), in the English glossary's words: Vultures' (batch G-2B).
  final List<String> who;

  /// How many of its share stack at most ([omenShown]'s `{cap}`, the named total: a step, a kill; Horde's, Adapt's and
  /// Spree's 3); 0: none.
  final int steps;

  /// The chest rarities whose cards may hide it: one, its own tier's ([omenOneTier]; today's seven sat in every pool
  /// until the tiers' cut-overs).
  final Set<Rarity> tiers;

  // The same for every kind yet; a data batch switched off makes it an argument.
  final bool live = true;

  /// The Pusaka whose row names it as their counter ([Art.counter], or on a healer [Art.healerCounter]), in [Relic]
  /// order.
  List<Relic> get answers => [
        for (final MapEntry(key: r, value: a) in pusakaCatalog.entries)
          if (a.counter == this || a.healerCounter == this) r,
      ];
}
