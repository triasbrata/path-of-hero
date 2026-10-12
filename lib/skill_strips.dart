part of 'game.dart';

// The skill strips (decisions-log 299; docs/units-and-combat.md "Skill strips"). The owner: "sama animasi attack 2 dan 3
// kenapa tidak di pakai ya, itu paadahal bisa di pakai untuk animation attack ketika skill". A skill's cast plays one of
// the Tiny RPG pack's other attack strips (tool/import_tiny_skills.py), `tiny_<type>_<anim>.png`, so that its blow
// (the [SkillStrip.strike] frame) shows when the skill lands. What a unit plays is [Unit.skillAnim]: set when a cast
// begins, drawn by the UI (main.dart's `_unit`), never read by the fight itself and never saved.

/// One skill's strip: `tiny_<type>_[anim].png` (100×100 frames at [skillStripFps], like every unit strip), its blow on
/// frame [strike]. A cast starts it at frame [entry] (the frames before it are near-idle ones), so its blow shows
/// ([strike] − [entry]) / [skillStripFps] s later; a longer wind-up (a monster's, [MonsterSkill.wind]) starts from an
/// earlier frame, 0 at the earliest, and holds that one until the rest fit ([skillStripFrame]).
class SkillStrip {
  final String anim;
  final int entry, strike;
  const SkillStrip(this.anim, this.entry, this.strike);
}

/// Frames a second of a skill strip: the units' own rate (main.dart's `_fps`).
const skillStripFps = 10.0;

/// What a cast plays ([Unit.skillAnim]): [strip] from [from], its blow at [strikeAt].
typedef SkillAnim = ({SkillStrip strip, double from, double strikeAt});

/// Each troop type's #10 skill ([troopSkills]) strip; its awakening skill ([AwakenSkill]) plays the same.
const troopSkillStrips = <String, SkillStrip>{
  'soldier': SkillStrip('attack2', 0, 3), // Hold Fast: a leap and an overhead chop
  'knight': SkillStrip('attack2', 0, 3), // Circle Slash: two sweeps, the first on 3
  'swordsman': SkillStrip('attack3', 2, 5), // Rampage: a flurry of thrusts
  'archer': SkillStrip('attack2', 6, 9), // Arrow Rain: the charged shot's glow, the release on 9
  'lancer': SkillStrip('attack2', 0, 2), // Piercing Thrust: a thrust with a blast of wind
  'priest': SkillStrip('attack2', 1, 4), // Healing Prayer: the pack's Attack, the staff raised (3) and pointed (4)
  'armored_axeman': SkillStrip('attack3', 4, 7), // Crushing Blow: the overhead slam into the ground
  'wizard': SkillStrip('attack2', 1, 4), // Arcane Blast: the staff overhead, then pointed
  'knight_templar': SkillStrip('attack2', 2, 5), // Holy Shield: the spear raised, then brought down
};

/// Each troop type's Hero skills' strip ([HeroSkill]), but for [_heroOwnStrips].
const heroSkillStrips = <String, SkillStrip>{
  'soldier': SkillStrip('attack2', 0, 3), // its attack 3 is a bow shot: no soldier skill shoots
  'knight': SkillStrip('attack3', 4, 7), // a flame-charged slash
  'swordsman': SkillStrip('attack2', 0, 3), // a three-cut combo (3, 7, 12)
  'archer': SkillStrip('attack2', 6, 9), // the charged shot
  'lancer': SkillStrip('attack3', 1, 4), // two fire thrusts, the second on 4
  'priest': SkillStrip('attack2', 1, 4),
  'armored_axeman': SkillStrip('attack2', 1, 4), // a spin
  'wizard': SkillStrip('attack2', 1, 4),
  'knight_templar': SkillStrip('attack3', 4, 7), // a sweep, then the spear smashed down on 7
};

/// The Hero skills with a strip of their own: Earthquake the axeman's slam; Snipe the whole draw, its release on its
/// aim's end ([snipeK]).
const _heroOwnStrips = <HeroSkill, SkillStrip>{
  HeroSkill.quake: SkillStrip('attack3', 4, 7),
  HeroSkill.snipe: SkillStrip('attack2', 4, 9),
};

/// Hero skill [s]'s strip.
SkillStrip? heroSkillStrip(HeroSkill s) => _heroOwnStrips[s] ?? heroSkillStrips[s.type];

/// The monsters' skills' strips, the blow on the land ([Unit.windUntil]). None for a passive one (Reassemble, Split,
/// Frenzy, Thick Hide), Shield Up (a guard: the armored skeleton has no strip for it) and Mass Mend (the healing
/// necromancer's own cast strip, as before). A skeleton archer has no second attack: its own attack strip.
const monsterSkillStrips = <MonsterSkill, SkillStrip>{
  MonsterSkill.warShout: SkillStrip('attack2', 0, 3), // its eyes go red
  MonsterSkill.volley: SkillStrip('attack', 0, 6),
  MonsterSkill.brutalSwing: SkillStrip('attack2', 0, 2), // a blood-red spin
  MonsterSkill.bulwark: SkillStrip('attack3', 0, 5), // a stomp that throws up spikes
  MonsterSkill.bladeDance: SkillStrip('attack3', 0, 4), // a quick thrust; the later cuts replay its attack strip
  MonsterSkill.stickyGlob: SkillStrip('attack', 0, 3), // the spit (its attack 2 draws a sword)
  MonsterSkill.swoop: SkillStrip('attack2', 0, 4), // wings folded, then the claws
  MonsterSkill.pounce: SkillStrip('attack2', 0, 7), // a crouch, a vanishing dash, the slash
  MonsterSkill.trample: SkillStrip('attack3', 0, 6), // the flail whirled round
  MonsterSkill.maul: SkillStrip('attack2', 0, 4), // two claws
  MonsterSkill.curseOfFrailty: SkillStrip('attack2', 0, 4), // a green orb from its hand
  MonsterSkill.screech: SkillStrip('attack2', 0, 4),
  MonsterSkill.boneShield: SkillStrip('block', 0, 1),
  MonsterSkill.headbutt: SkillStrip('attack2', 0, 3),
  MonsterSkill.barbedArrow: SkillStrip('attack', 0, 6),
  MonsterSkill.boneBash: SkillStrip('attack2', 0, 1), // the halberd whirled
  MonsterSkill.spearThrow: SkillStrip('attack2', 0, 5),
  MonsterSkill.bloodrage: SkillStrip('attack2', 0, 2),
  MonsterSkill.groundSlam: SkillStrip('attack3', 0, 5),
  MonsterSkill.soulRend: SkillStrip('attack2', 0, 6), // the greatsword raised, then slammed down
  MonsterSkill.soulDrain: SkillStrip('attack2', 0, 4),
  MonsterSkill.unholyWard: SkillStrip('attack2', 0, 4),
  MonsterSkill.slimeTide: SkillStrip('attack2', 0, 8), // a sword drawn from its body, then the cut
  MonsterSkill.swarm: SkillStrip('attack2', 0, 4),
  MonsterSkill.graveCall: SkillStrip('attack2', 0, 3),
  MonsterSkill.rally: SkillStrip('attack2', 0, 3),
  MonsterSkill.boneRain: SkillStrip('attack', 0, 6),
  MonsterSkill.howl: SkillStrip('attack2', 0, 7),
  MonsterSkill.ironMarch: SkillStrip('attack2', 0, 1),
  MonsterSkill.secondWind: SkillStrip('attack2', 0, 5),
  MonsterSkill.skullCrusher: SkillStrip('attack3', 0, 4), // the axe overhead, then down
  MonsterSkill.earthshaker: SkillStrip('attack3', 0, 5),
  MonsterSkill.graveWave: SkillStrip('attack2', 0, 6), // the slam's wave along the ground
  MonsterSkill.roar: SkillStrip('attack3', 0, 5), // a ground pound
  MonsterSkill.deathNova: SkillStrip('attack2', 0, 4),
  MonsterSkill.lastRites: SkillStrip('attack2', 0, 4),
};

/// Every skill strip a unit type plays: `tiny_<type>_<anim>.png` per (type, anim), for the loading (the necro healer's
/// are the boss's recoloured, main.dart).
Set<(String, String)> skillStripFiles() => {
      for (final MapEntry(:key, :value) in troopSkillStrips.entries) (key, value.anim),
      for (final MapEntry(:key, :value) in heroSkillStrips.entries) (key, value.anim),
      for (final s in _heroOwnStrips.keys) (s.type, _heroOwnStrips[s]!.anim),
      for (final MapEntry(:key, :value) in monsterSkillStrips.entries)
        if (value.anim != 'attack') (key.type, value.anim),
    };

/// The frame of [a]'s strip (of [frames] frames) showing at [now], or null before it starts and once it has played
/// out. Up to the blow its frames run at [skillStripFps] and end on [SkillStrip.strike] at [SkillAnim.strikeAt]: from
/// [SkillStrip.entry], or from an earlier frame when the wind-up is longer (0 at the earliest, held until the rest fit);
/// after it, on at the same rate.
int? skillStripFrame(SkillAnim a, int frames, double now) {
  final s = a.strip;
  if (now < a.from) return null;
  if (now >= a.strikeAt) {
    final f = s.strike + ((now - a.strikeAt) * skillStripFps + 1e-9).floor();
    return f < frames ? f : null;
  }
  final first = max(0, min(s.entry, s.strike - ((a.strikeAt - a.from) * skillStripFps + 1e-9).floor()));
  final begin = a.strikeAt - (s.strike - first) / skillStripFps;
  return (first + ((now - begin) * skillStripFps + 1e-9).floor()).clamp(first, s.strike);
}

/// Which of a troop's skills is winding up ([Unit.troopWind]).
enum WindKind { troop, awaken, hero }

/// A troop's skill winding up (decisions-log 299; the owner: "Ancang-ancang beneran", a real wind-up like the monsters'):
/// its [kind] (an awakening skill's [awaken] at [level]) lands at [until], on its strip's blow. An awakening skill's wind-up
/// claims what it aims at, [claims] (its foe, or the troops it lifts) and [at] (the spot of its ground, well or leap), so
/// the others of its type pick something else meanwhile (decisions-log 320, [AwakenSkills._awakenClaim]). Not saved: a save
/// holds no wave in progress.
typedef TroopWind = ({WindKind kind, AwakenSkill? awaken, int level, double until, List<Unit> claims, Point<double>? at});

/// The Hero skills without a wind-up here: Snipe aims first anyway ([snipeK].aim; its strip's release is timed to it), and
/// a move's movement is its build-up (hero_moves.dart).
const instantHeroSkills = {
  HeroSkill.snipe, HeroSkill.shieldBash, HeroSkill.sweep, HeroSkill.rescueLeap, HeroSkill.deathLeap, HeroSkill.charge,
  HeroSkill.hook, HeroSkill.spearWall,
};

/// A troop's skills' wind-up (decisions-log 299; docs/units-and-combat.md "Skill strips"), the monsters' rules: the MP and
/// the cooldown are paid as it begins, it stands still and does nothing else (no attack, heal, step or other cast) until
/// its strip's blow, and then the skill lands. A stun, a move (a knockback, a drag) or the wave's end cancels it, and its
/// target is picked again on the blow: none, and it fizzles. Nothing is refunded either way.
extension SkillWinds on Game {
  /// Troop [u] has paid for a skill ([kind]; an awakening one's [awaken] at [level]) and begins its [strip] ([_playStrip];
  /// its blow at [strikeAt] if given): it winds up for the strip's frames from its entry to its blow (0.2-0.3 s) and the
  /// skill lands then ([_troopWindTurn]). One with no strip, or a Hero skill of [instantHeroSkills], lands now, and so does
  /// every one in a game without the wind-ups ([Game.skillWinds]: a plain Game()'s, the tests'), its strip only shown.
  /// An awakening skill claims [claims] and [at] while it winds up ([TroopWind]).
  void _windUp(Unit u, WindKind kind, SkillStrip? strip,
      {AwakenSkill? awaken, int level = 0, double? strikeAt, List<Unit> claims = const [], Point<double>? at}) {
    _playStrip(u, strip, strikeAt);
    if (!skillWinds || strip == null || strip.strike <= strip.entry || (kind == WindKind.hero && instantHeroSkills.contains(u.heroSkill))) {
      _landTroopSkill(u, kind, awaken, level);
      return;
    }
    u
      ..troopWind = (kind: kind, awaken: awaken, level: level, until: t + (strip.strike - strip.entry) / skillStripFps, claims: claims, at: at)
      ..moving = false;
  }

  /// [tick]: troop [u] winding up ([Unit.troopWind]) stands still; on its blow its skill lands if it still has a target
  /// ([_landTroopSkill]). The tick is the wind-up's either way.
  void _troopWindTurn(Unit u) {
    final w = u.troopWind!;
    u.moving = false;
    if (t < w.until) return;
    u.troopWind = null;
    _landTroopSkill(u, w.kind, w.awaken, w.level, again: true);
  }

  /// [u]'s skill lands: its effect, then its type's `cast` Fx (pusaka_engine.dart), Afterglow's charged hits (relics.dart)
  /// and the Bayangan's answers to a cast (omen.dart). After a wind-up ([again]) its rule is asked again (MP and cooldown
  /// aside: [wantsSkill], [wantsAwakenSkill] (Impale by its target alone, its cooldown having just begun; Unbroken by a foe
  /// in reach alone, decisions-log 320: a knight healed back to full in the wind-up still lands it), [wantsHeroSkill]),
  /// and with nobody to land on it fizzles: none of that happens and its strip stops.
  void _landTroopSkill(Unit u, WindKind kind, AwakenSkill? s, int level, {bool again = false}) {
    if (again &&
        !switch (kind) {
          WindKind.troop => wantsSkill(u),
          WindKind.awaken => switch (s!) {
              AwakenSkill.impale => _impaleTarget(u) != null,
              AwakenSkill.unbroken => _foeInReach(u),
              _ => wantsAwakenSkill(u, s, level),
            },
          WindKind.hero => wantsHeroSkill(u),
        }) {
      u.skillAnim = null;
      return;
    }
    switch (kind) {
      case WindKind.troop:
        _castSkill(u);
      case WindKind.awaken:
        _castAwakenSkill(u, s!, level);
      case WindKind.hero:
        _castHeroSkill(u);
    }
    _fxCast(u); // its type's `cast` Fx (pusaka_engine.dart)
    if (u.relics.isNotEmpty) _relicCast(u); // Afterglow's charged hits (relics.dart)
    if (omensOn) _omenCast(u); // Counterspell's shields, Backlash's mights on the monsters near (omen.dart)
  }

  /// Troop [u]'s wind-up is cancelled (a stun, a move, the wave's end): nothing is refunded, and its strip stops.
  void _cancelTroopWind(Unit u) => u
    ..troopWind = null
    ..skillAnim = null;
}
