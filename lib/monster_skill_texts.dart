// What each monster skill does, in one line for its first-sighting splash (lib/foe_splash.dart; docs/ui-hud.md "Foe
// splash"; the owner, 2026-10-02: "dan ketika champion musuh (< mini boss) skill juga ada effectnya dan ada splash
// screennya"), and the hint under it: how to stop it. Pure Dart: the board draws them.
//
// - Very simple English with the item text's glossary (docs/ui-hud.md "In-game text": troop, type, HP, attack, damage,
//   heal, hit, wave, boss, monster, tile; here also "shield"), present tense, the skill's caster "it".
// - Every number comes from its skill's constant (none is written here: test/foe_splash_test.dart reads this file for
//   digits), and a line holds only numbers that are the same at every rank: a mini boss's stronger War Shout still
//   reads "hit harder", not "20%". It fits two lines of the splash on the 915x412 phone.

import 'game.dart';

/// [k] as whole percent: 0.3 → "30%".
String _pct(double k) => '${(k * 100).round()}%';

/// Seconds as the player reads them: 5.0 → "5", 2.5 → "2.5".
String _secs(double s) => s == s.roundToDouble() ? '${s.round()}' : '$s';

/// How much faster an attack pause of [pause]× makes the attacks come (1/1.4 → "40%"), or slower (1.25 → "20%").
String _rate(double pause) => _pct((1 / pause - 1).abs());

/// What skill [s] does, one line.
String monsterSkillText(MonsterSkill s) => switch (s) {
      MonsterSkill.warShout => 'Monsters near it hit harder for ${_secs(warShoutK.time)} seconds.',
      MonsterSkill.volley => 'Shoots arrows at your nearest troops at once.',
      MonsterSkill.shieldUp => 'Takes half damage from ranged troops for ${_secs(shieldUpK.time)} seconds.',
      MonsterSkill.brutalSwing => 'Hits every troop in its reach at once.',
      MonsterSkill.bulwark => 'Melee troops near it must fight it, and it takes ${_pct(bulwarkK.cut)} less damage.',
      MonsterSkill.bladeDance => 'Spins, cutting every troop close by.',
      MonsterSkill.massMend => 'Heals every hurt monster near it.',
      MonsterSkill.stickyGlob => 'Spits a glob that slows a back-line troop.',
      MonsterSkill.swoop => 'Flies over your front line to bite a back-line troop.',
      MonsterSkill.pounce => 'Leaps on a weak troop and makes it bleed.',
      MonsterSkill.trample => 'Charges through your line, pushing troops aside.',
      MonsterSkill.reassemble => 'Gets up again once after a killing blow.',
      MonsterSkill.maul => 'A huge blow that knocks a troop back.',
      MonsterSkill.curseOfFrailty => 'Troops near it take more damage for ${_secs(curseOfFrailtyK.time)} seconds.',
      MonsterSkill.split => 'Bursts into ${splitK.slimes} slimes when it dies.',
      MonsterSkill.screech => 'Troops near it attack ${_rate(screechK.pause)} slower for ${_secs(screechK.time)} seconds.',
      MonsterSkill.boneShield => 'A hurt undead near it takes ${_pct(boneShieldK.cut)} less damage for ${_secs(boneShieldK.time)} seconds.',
      MonsterSkill.headbutt => 'Hits a troop and stuns it.',
      MonsterSkill.barbedArrow => 'An arrow that makes a troop bleed.',
      MonsterSkill.frenzy => 'Below half HP, it attacks ${_rate(frenzyK.pause)} faster for ${_secs(frenzyK.time)} seconds.',
      MonsterSkill.boneBash => 'Hits a troop and knocks it back.',
      MonsterSkill.spearThrow => 'Throws a spear at a back-line troop.',
      MonsterSkill.bloodrage => 'When hurt, it heals ${_pct(bloodrageK.share)} of the damage it deals for ${_secs(bloodrageK.time)} seconds.',
      MonsterSkill.groundSlam => 'Hits every troop close by.',
      MonsterSkill.soulRend => 'For ${_secs(soulRendK.time)} seconds, each of its hits takes ${_secs(soulRendK.mp)} MP too.',
      MonsterSkill.thickHide => 'Below half HP, it takes ${_pct(thickHideK.cut)} less damage for ${_secs(thickHideK.time)} seconds.',
      MonsterSkill.soulDrain => 'A beam drains HP from one troop for ${_secs(soulDrainK.time)} seconds.',
      MonsterSkill.unholyWard => 'Shields a monster under attack for ${_secs(unholyWardK.time)} seconds.',
      MonsterSkill.slimeTide => 'A slime pool slows troops by ${_pct(1 - slimeTideK.slow)} for ${_secs(slimeTideK.time)} seconds.',
      MonsterSkill.swarm => 'Calls ${swarmK.bats} bats to fight.',
      MonsterSkill.graveCall => 'Raises up to ${graveCallK.most} fallen skeletons.',
      MonsterSkill.rally =>
        'Every orc hits ${_pct(rallyK.might - 1)} harder and ${_rate(rallyK.pause)} faster for ${_secs(rallyK.time)} seconds.',
      MonsterSkill.boneRain => 'Arrows rain on your troops for ${_secs(boneRainK.time)} seconds.',
      MonsterSkill.howl => 'Monsters near it move and attack faster for ${_secs(howlK.time)} seconds.',
      MonsterSkill.ironMarch => 'Nothing slows it for ${_secs(ironMarchK.time)} seconds, and it walks faster.',
      MonsterSkill.secondWind => 'Heals ${_pct(secondWindK.heal)} of its HP and speeds up.',
      MonsterSkill.skullCrusher => 'A huge blow that stuns a troop.',
      MonsterSkill.earthshaker => 'Hits and stuns every troop near it.',
      MonsterSkill.graveWave => 'A sword wave cuts every troop in a ${_secs(graveWaveK.length / tile)} tile line.',
      MonsterSkill.roar => 'Troops near it deal ${_pct(1 - roarK.dealt)} less damage for ${_secs(roarK.time)} seconds.',
      MonsterSkill.deathNova => 'Blasts every troop near it.',
      MonsterSkill.lastRites => 'Heals monsters near it by ${_pct(lastRitesK.heal)} of their max HP.',
    };

/// The splash's hint for [s] cast by a monster of [type] at rank [rank] (its banner's, foe_cut_in.dart's
/// `foeCutRank`): how to stop it while it winds up (a stun or a shove cancels a wind-up; the necromancer is never
/// stunned, a boss never stunned or shoved), Reassemble's answer (holy damage), or null where nothing stops it: a
/// boss's cast, and the skills that never wind up (Split, Frenzy, Thick Hide).
String? monsterSkillHint(MonsterSkill s, String type, Tier rank) {
  if (s == MonsterSkill.reassemble) return 'Holy damage stops it.';
  if (s.wind <= 0 || rank == Tier.boss) return null;
  return type == boss ? 'Shove it while it winds up.' : 'Stun or shove it while it winds up.';
}
