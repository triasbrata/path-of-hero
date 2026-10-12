part of 'main.dart';

// How the troops' skills look (docs/ui-hud.md); the skills themselves are in game.dart ([troopSkills],
// [Game.wantsSkill]) and hero_skills.dart (a Hero's own, [HeroSkill]). A cast pops its skill's name over the
// caster ([Game.casts]; a Hero's own in gold and bigger, [Game.heroCasts]), and each troop skill shows a look of
// its own (#81), a ring, beam or zone the cast leaves in the game ([RingLook], [BeamLook.thrust],
// [ZoneLook.volley]) in a colour of its own, never the Hero skills' gold nor the monsters' red, each cut from the
// packs' sheets (decisions-log 173): Hold Fast the ground circle's ring closing in and the UI pack's shield
// flashing, Circle Slash the greatsword skeleton's slash sweeping round the knight, Rampage an ember burst and the
// orc's flames as an aura while it lasts, Arrow Rain the archer's arrows falling on its targets, Piercing Thrust
// the lancer's thrust streak through its line, Healing Prayer a mint ring and the heal over each troop it heals,
// Crushing Blow a dust burst, Arcane Blast the pack's ice star (wizard_fx.dart) and a violet ring where it lands, Holy Shield a white ring
// and the templar's ring over each troop it shields ([_skillGround], [_skillsAbove]). A guarded unit stands in a
// ring (Hold Fast's steel blue, Holy Shield's white); a stunned monster (Crushing Blow) freezes mid-flinch
// ([Board._unit]); a skill's bigger hit is drawn bigger (the burst's `_big` suffix). What a skill leaves on a unit
// ([Unit.effects]) shows as small icons over a troop ([_effectMarks]) and coloured rings at a unit's feet
// ([_effectRings]: all of a monster's; a troop's with no icon, what monsters' skills leave on it, #59), a line
// ties a duel's, Shared Wounds' or a taunt's pair ([_effectLines]), a raging giant is drawn bigger
// ([giantRageK].size); Plunder's extra gold floats up where it was paid. A monster's guard ring takes its
// skill's colour ([Unit.guardLook]). A monster's skill (#59, monster_skills.dart) pops its title in red as it
// winds up ([Game.monsterCasts]), its tell on the field until the cast lands ([_windTells]); five champions' skills
// land with a look of their own ([landingLook]: Brutal Swing's crescent, Blade Dance's spin, Shield Up's shield in
// [_skillsAbove]; Volley's and Bulwark's rings and bursts).

/// A burst name's suffix for a skill's bigger hit, and how much bigger it is drawn.
const _bigFx = '_big', _bigScale = 1.4;

/// How long a skill's name shows over its caster (game clock, so it waits while paused).
const _popTime = 1.2;

/// A Hero's own skill pops in the crown's gold, this much bigger.
const _heroPop = Color(0xFFFFC93C), _heroPopScale = 1.25;

/// Whose skill a pop names: a troop's (pale blue), a Hero's own (gold, bigger), a monster's (red, [_monsterPop]) or
/// a troop's awakening skill (#88: pale blue like a troop's, with its level's numeral, "Disarm II"); or a troop
/// healer's "No MP" (decisions-log 297, in the MP bar's blue, [_noMpPop]).
enum _PopKind { troop, hero, monster, awaken, noMp }

/// "No MP" over a troop healer a heal found short of MP ([Game.noMp]): the MP bar's blue, lighter.
const _noMpPop = Color(0xFF7FB8FF);

/// A monster's skill pops, and its wind-up circle fills, in this red.
const _monsterPop = Color(0xFFFF6B5E);

/// How a monster skill's wind-up shows on the field ([windTells]; docs/ui-hud.md "A monster's skill"), every
/// part of it from the sheets in assets/ (the owner: no shapes drawn in code). Every kind but [none] puts the
/// summon circle (tiny_fx_summon.png) on the ground in red, forming as the wind-up runs, its rim in the caster's
/// rank colour.
enum WindTell {
  /// The circle as wide as the skill's reach ([windReachOf]): a skill on everyone round it.
  area,

  /// The circle at its feet, and a red marker (ui_icons.png's ▼) over each one it will land on
  /// ([MonsterSkills.windTargetsOf]).
  target,

  /// The circle at its feet, and red arrows (ui_icons.png's) along its way: Trample's charge, Grave Wave's line.
  lane,

  /// The circle at its feet only: a skill on itself, or one that calls monsters in.
  self,

  /// Nothing: no wind-up (Reassemble and Split go off as it falls).
  none,
}

/// Every monster skill's wind-up tell ([WindTell]).
const windTells = {
  MonsterSkill.warShout: WindTell.area,
  MonsterSkill.volley: WindTell.target,
  MonsterSkill.shieldUp: WindTell.self,
  MonsterSkill.brutalSwing: WindTell.area,
  MonsterSkill.bulwark: WindTell.area,
  MonsterSkill.bladeDance: WindTell.area,
  MonsterSkill.massMend: WindTell.area,
  MonsterSkill.stickyGlob: WindTell.target,
  MonsterSkill.swoop: WindTell.target,
  MonsterSkill.pounce: WindTell.target,
  MonsterSkill.trample: WindTell.lane,
  MonsterSkill.reassemble: WindTell.none,
  MonsterSkill.maul: WindTell.target,
  MonsterSkill.curseOfFrailty: WindTell.area,
  MonsterSkill.split: WindTell.none,
  MonsterSkill.screech: WindTell.area,
  MonsterSkill.boneShield: WindTell.area,
  MonsterSkill.headbutt: WindTell.target,
  MonsterSkill.barbedArrow: WindTell.target,
  MonsterSkill.frenzy: WindTell.self,
  MonsterSkill.boneBash: WindTell.target,
  MonsterSkill.spearThrow: WindTell.target,
  MonsterSkill.bloodrage: WindTell.self,
  MonsterSkill.groundSlam: WindTell.area,
  MonsterSkill.soulRend: WindTell.self,
  MonsterSkill.thickHide: WindTell.self,
  MonsterSkill.soulDrain: WindTell.target,
  MonsterSkill.unholyWard: WindTell.target,
  MonsterSkill.slimeTide: WindTell.self,
  MonsterSkill.swarm: WindTell.self,
  MonsterSkill.graveCall: WindTell.self,
  MonsterSkill.rally: WindTell.self,
  MonsterSkill.boneRain: WindTell.self,
  MonsterSkill.howl: WindTell.area,
  MonsterSkill.ironMarch: WindTell.self,
  MonsterSkill.secondWind: WindTell.self,
  MonsterSkill.skullCrusher: WindTell.target,
  MonsterSkill.earthshaker: WindTell.area,
  MonsterSkill.graveWave: WindTell.lane,
  MonsterSkill.roar: WindTell.area,
  MonsterSkill.deathNova: WindTell.area,
  MonsterSkill.lastRites: WindTell.area,
};

/// The radius monster [u]'s skill [s] reaches round it, its circle's half width: an area skill's reach (its
/// `<id>K.reach`, Brutal Swing's the monster's own reach), else the circle at its feet's.
double windReachOf(Unit u, MonsterSkill s) => switch (s) {
      MonsterSkill.warShout => warShoutK.reach,
      MonsterSkill.brutalSwing => u.stats.range,
      MonsterSkill.bulwark => bulwarkK.reach,
      MonsterSkill.bladeDance => bladeDanceK.reach,
      MonsterSkill.massMend => massMendK.reach,
      MonsterSkill.curseOfFrailty => curseOfFrailtyK.reach,
      MonsterSkill.screech => screechK.reach,
      MonsterSkill.boneShield => boneShieldK.reach,
      MonsterSkill.groundSlam => groundSlamK.reach,
      MonsterSkill.howl => howlK.reach,
      MonsterSkill.earthshaker => earthshakerK.reach,
      MonsterSkill.roar => roarK.reach,
      MonsterSkill.deathNova => deathNovaK.reach,
      MonsterSkill.lastRites => lastRitesK.reach,
      _ => _circleW / 2,
    };

/// The skills whose circle isn't red with a rank rim: (its fill, its rim; none: the rank's). Mass Mend's heals
/// in the drain's green; Bulwark's rim in the taunt's orange, Curse of Frailty's in the curse's dark.
const _windColors = <MonsterSkill, (Color, Color?)>{
  MonsterSkill.massMend: (Color(0xFF4CE06A), null),
  MonsterSkill.bulwark: (_monsterPop, Color(0xFFFF8A30)),
  MonsterSkill.curseOfFrailty: (_monsterPop, Color(0xFF2B2233)),
};

/// The wind-up circle's alpha as its wind-up begins and as it lands ([Board._windCircle]).
const windTellAlpha = (from: 0.7, to: 1.0);

/// The wind-up circle at a monster's feet is the pack's ground circle at its own size ([_circleW] wide: 1 world unit a
/// sprite px, as the units), its frames one by one (the circle drawn, then filled: [_summonFrames]). An area's reach
/// at least [_windRingFrom] times that gets a ring of its own round the circle.
const _summonFrames = 7, _windRingFrom = 1.4;

/// A wind-up's reach over twice the circle's size is ringed by its dashes this many world units apart ([closeDashes]):
/// 4 long, so end to end, one solid ring that reads as a warning.
const _windDashStep = 4.0;

/// ui_icons.png's visible pixels: the big ▼ in red (a troop a skill will land on) and green (a monster it will
/// shield), drawn [_windMarkK] world units a sprite px (a unit's bar's, [barK]); and the big red arrows pointing left and
/// right (a lane).
const _markRed = Rect.fromLTWH(51, 211, 10, 9), _markGreen = Rect.fromLTWH(51, 195, 10, 9), _windMarkK = barK;
const _laneLeft = Rect.fromLTWH(99, 162, 10, 12), _laneRight = Rect.fromLTWH(147, 162, 10, 12);

/// A lane's arrows: one every [_laneStep] world units, [_laneK] world units a sprite px, squashed to [_laneFlat]
/// of their height so they lie on the ground.
const _laneStep = 12.0, _laneK = 0.8, _laneFlat = 0.6;

/// A boss's moment's red edges ([Board._momentVignette]): how long (s, game clock), how red at first, and how deep
/// (a share of the screen's shorter side).
const momentVignette = (time: 0.4, alpha: 0.45, depth: 0.12);
const _momentRed = Color(0xFFFF4A3D);

/// The summon circle's greens by brightness ([_ramp]): its darker fill green (5C943B) and its main one (A0EB70).
/// Its outline is 0.25, its palest 0.92.
const _summonLum = (lo: 0.47, hi: 0.78);

/// The ground circle (tiny_fx_summon.png) in colour [c] (the wind-up circle's fill, Bone Rain's zone): the circle's
/// greens mapped by brightness onto a ramp through the colour, the darker green at 55% of it and the main green at all
/// of it (the outline near black, the palest clipping towards white), so the pattern stays and reads as that colour on
/// the tan road ([_tint] lifts a red to salmon or brown there). Made once each.
final _circleTints = <Color, ColorFilter>{};
ColorFilter _circleTint(Color c) => _circleTints.putIfAbsent(c, () => _ramp(Color.lerp(Colors.black, c, 0.55)!, c, _summonLum.lo, _summonLum.hi));

/// Recolours by brightness: a pixel as bright as [lo] (0..1) becomes [dark], one as bright as [hi] becomes [light],
/// in between in a line (and past them, until the channels clip); alpha kept.
ColorFilter _ramp(Color dark, Color light, double lo, double hi) {
  const lum = [0.299, 0.587, 0.114];
  List<double> row(double d, double l) {
    final k = (l - d) * 255 / (hi - lo);
    return [for (final w in lum) k * w / 255, 0, d * 255 - k * lo];
  }

  return ColorFilter.matrix([...row(dark.r, light.r), ...row(dark.g, light.g), ...row(dark.b, light.b), 0, 0, 0, 1, 0]);
}

/// The wind-up circle's rim, by colour: the outline frame's outer row only (its darkest pixels, the circle's own
/// outline; its paler inner row goes) flat in the colour. Made once each.
final _windRims = <Color, ColorFilter>{};
ColorFilter _windRim(Color c) => _windRims.putIfAbsent(c, () {
      // alpha' = 10·alpha − 11·brightness − 1593 (0..255): the outline (brightness 64) stays whole, the next green (87)
      // and anything see-through goes.
      const k = -11.0;
      return ColorFilter.matrix([
        0, 0, 0, 0, c.r * 255, //
        0, 0, 0, 0, c.g * 255,
        0, 0, 0, 0, c.b * 255,
        k * 0.299, k * 0.587, k * 0.114, 10, -1593,
      ]);
    });

/// Singularity's well ([Board._singularityWell]): its rim's dashes turn this many turns a second; a pull's ring is
/// drawn in from the reach to [_wellCore] (the ground circle's own half width, its core) over [_wellPullTime] s, and
/// [_wellPulls] take turns.
const _wellTurn = 0.15, _wellCore = _circleW / 2, _wellPullTime = 0.9, _wellPulls = 2;

/// A troop's skill pops in this pale blue, the colour of a plain guard ring and Arrow Rain's zone too.
const _troopPop = Color(0xFFBFE6FF);

/// The troops' skills' own colours (#81): Hold Fast's steel blue, Circle Slash's blade white (its ring) and pale blue
/// (its slash), Rampage's embers, Healing Prayer's mint, Arcane Blast's violet, Holy Shield's white, Piercing Thrust's
/// teal, Crushing Blow's dust.
const _braceBlue = Color(0xFF7FB2E5), _blade = Color(0xFFF4FAFF), _bladeGlow = Color(0xFF9FD8FF);
const _ember = Color(0xFFFF7A2E), _mint = Color(0xFF8CFFB4);
const _violet = Color(0xFFB46CFF), _holyWhite = Color(0xFFFFFAEB);
const _thrustGlow = Color(0xFF6FE8D8), _dust = Color(0xFFC8A878);

/// The awakening skills' colours (#88), all in this one table so none comes near another or a skill's of before
/// (the #10 skills', the Hero skills' gold, the monsters' red): each skill's main colour and its second (an edge, a
/// core, a fill). Disarm iron with a white-hot edge; Unbroken deep cyan with a pale core; Phantom Rush magenta with a
/// pale core; Spellbreaker cool silver with a graphite edge; Impale chartreuse with a steel shaft; Lifeline the
/// priest's mint ([_mint]) with white motes; Skyfall ash shockwaves and a white-hot flash; Singularity indigo with
/// white; Consecration rose with a pale rose.
/// Pull a colour out as a const of its own (like [_iron]) where a const needs it ([_ringColors]).
const awakenColors = <AwakenSkill, (Color, Color)>{
  AwakenSkill.disarm: (_iron, _whiteHot),
  AwakenSkill.unbroken: (_unbrokenCyan, _unbrokenCore),
  AwakenSkill.phantomRush: (Color(0xFFFF4FD8), Color(0xFFFFD0F4)),
  AwakenSkill.spellbreaker: (_silver, _graphite),
  AwakenSkill.impale: (_impaleLime, _shaftSteel),
  AwakenSkill.lifeline: (_mint, Colors.white),
  AwakenSkill.skyfall: (Color(0xFFD8D2C4), Color(0xFFFFF6E0)),
  AwakenSkill.singularity: (_indigo, Colors.white),
  AwakenSkill.consecration: (_rose, _roseFill),
};
const _iron = Color(0xFF4B5563), _whiteHot = Color(0xFFFFF3DC); // Disarm
const _impaleLime = Color(0xFFD4FF3F), _shaftSteel = Color(0xFFE8EEF2); // Impale
const _silver = Color(0xFFD6E4FF), _graphite = Color(0xFF3A4150); // Spellbreaker
const _indigo = Color(0xFF5A4FCF); // Singularity
const _unbrokenCyan = Color(0xFF1FB8E0), _unbrokenCore = Color(0xFFD8F6FF); // Unbroken
const _rose = Color(0xFFFF8FC4), _roseFill = Color(0xFFFFE1EF); // Consecration
const _rushMagenta = Color(0xFFFF4FD8); // Phantom Rush, as in [awakenColors]
const _ash = Color(0xFFD8D2C4); // Skyfall

/// The troops' skills' looks' sheets in their colours (#81): the ground circle's ring in Hold Fast's steel blue, the
/// greatsword skeleton's white slash dyed Circle Slash's pale blue ([_dye]), the werebear's red bits and the orc's
/// flames in Rampage's ember, the heal in Healing Prayer's mint, the armored orc's ring of bits in Crushing Blow's
/// dust, the templar's gold ring in Holy Shield's white, the lancer's white streak dyed Piercing Thrust's teal.
final _braceTint = _tint(_braceBlue), _bladeDye = _dye(_bladeGlow), _emberTint = _tint(_ember), _mintTint = _tint(_mint);
final _dustTint = _tint(_dust), _holyWhiteTint = _tint(_holyWhite), _thrustDye = _dye(_thrustGlow);

/// The awakening skills' looks' sheets in their colours (#88): Impale's chartreuse shards and lunge ([_dye]: white
/// sheets), Disarm's iron, Unbroken's cyan, Phantom Rush's magenta, Spellbreaker's silver rune circle, Singularity's
/// indigo, Skyfall's ash (a dye: the armored orc's orange bits, darker than Crushing Blow's dust tint), Consecration's
/// rose.
final _limeDye = _dye(_impaleLime), _ironTint = _tint(_iron), _cyanDye = _dye(_unbrokenCyan), _rushDye = _dye(_rushMagenta);
final _silverTint = _tint(_silver), _indigoTint = _tint(_indigo), _indigoDye = _dye(_indigo), _ashDye = _dye(_ash);
final _roseTint = _tint(_rose);

/// The champions' landing looks' colours (#59): Brutal Swing's crescent (the armored axeman's sweep) a white blade with a
/// deep red edge ([_cleaveTint]); Shield Up's ward the steel shield's grey. Blade Dance's spin is the greatsword
/// skeleton's own white slash as it is.
const _cleaveRed = Color(0xFF9A0F18), _wardGrey = Color(0xFF9AA0A6);

/// Brutal Swing's crescent recoloured by brightness ([_ramp]): its dark outline (0.24 to 0.30) deep red, its reds and
/// oranges (0.45 and up) near white, so it stands apart from the red claw marks of the big hits it lands.
final _cleaveTint = _ramp(_cleaveRed, Colors.white, 0.30, 0.52);

/// Shield Up's shield ([RingLook.ward]): ui_icons.png's steel shield at [_windMarkK] world units a sprite px (the bars'
/// and the wind-up marks' scale), popping in from 1.5× its size over its first [_wardPop] s.
const _wardPop = 0.15;

/// Blade Dance's slashes: their frames this many times its reach tall, as Circle Slash's blade, so the spin runs round
/// the troops it cuts. Brutal Swing's crescent is as big as the big hits it lands (`_bigScale` × [_burstSize]), half its
/// reach ahead of the elite orc, so it sweeps over the troops rather than the orc.
const _sweepK = 2.2;

/// Consecration's heals ([Board._consecration]): one for every [_crossPer] world units of its radius, each [_crossTime] s.
const _crossPer = 12.0, _crossTime = 1.2;

/// Rampage's aura's frames of fx_hit_orc.png: its flames standing, looped.
const _rageFlames = [1, 2, 3, 2];

/// A sheet's paint: [filter] (a [_tint] or [_dye], or none) at [alpha], unsmoothed.
Paint _sheetPaint(ColorFilter? filter, double alpha) => Paint()
  ..filterQuality = FilterQuality.none
  ..colorFilter = filter
  ..color = Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0));

/// ui_icons.png's steel shield (Hold Fast's flash).
const _icSteelShield = Offset(192, 0);

/// Phantom Rush's afterimages: the swordsman's body flat magenta.
const _rushFilter = ColorFilter.mode(_rushMagenta, BlendMode.srcIn);

/// A phantom's body ([isPhantom], decisions-log 320): its own frame at [_phantomAlpha], and over it the same frame flat
/// magenta at [_phantomWashAlpha], the afterimages' colour, so the swordsman reads as a ghost while no blow lands on it.
const _phantomAlpha = 0.55, _phantomWashAlpha = 0.4;
final _phantomBody = _sheetPaint(null, _phantomAlpha), _phantomWash = _sheetPaint(_rushFilter, _phantomWashAlpha);

/// Where a streak starts and ends in its sheet's 64 px frame ([Board._streak]): fx_hit_lancer.png's thrust (its first
/// frame to its last) and fx_hit_soldier.png's slash (its third frame's).
const _thrustRun = (Offset(3, 19), Offset(61, 46)), _rushRun = (Offset(20, 18), Offset(48, 45));

/// A unit's ground shadow in its 100 px frame (`tiny_<type>_shadow.png`): its middle and how wide it is.
const _shadowMid = Offset(50.5, 57.5), _shadowW = 15.0;

/// A raging swordsman's outline: flat ember ([_rageLine]).
const _rageFilter = ColorFilter.mode(_ember, BlendMode.srcIn);

/// The icon over a troop while a Hero skill's [Status] is on it (add one for a new status).
const _effectMarks = {
  Status.haste: HeroMark.gloves,
  Status.might: HeroMark.sword,
  Status.range: HeroMark.bow,
  Status.lifesteal: HeroMark.fang,
  Status.reflect: HeroMark.thorns,
  Status.heal: HeroMark.potion,
  Status.absorb: HeroMark.guard,
  Status.block: HeroMark.guard,
  Status.cap: HeroMark.shield,
  Status.manaShield: HeroMark.bolt,
  Status.plunder: HeroMark.coin,
  Status.holdGround: HeroMark.fury,
  Status.link: HeroMark.heart,
  Status.duel: HeroMark.sword,
  Status.giant: HeroMark.heart,
};

/// The line from a troop under a skill's [Status] to its [Effect.by], at their feet: a duel's (the knight to its
/// foe) in gold, Shared Wounds' (the ally to the knight taking its wounds) pale gold, a taunt's (a troop to the
/// monster that taunted it, #59) orange.
const _effectLines = {Status.duel: Color(0xFFFFC93C), Status.link: Color(0xFFFFF0B0), Status.taunt: Color(0xFFFF8A30)};

/// The ring at a unit's feet while a skill's [Status] is on it (add one for a new status; on a troop only one with
/// no icon, [_statusRings]): slowed ice blue, cursed or weakened purple, marked red, taunted orange, bleeding
/// crimson, dazed (Screech) pale cream, pinned by Impale chartreuse (dashed, with the lance stuck through it, #88; a
/// hold of another type's, Ice Grip's, without the lance), Void Eye's mark violet (pusaka.dart), Vengeance Mark's rose;
/// a monster's own: War Shout's might amber, Shield Up's ward steel grey, a speed-up (Howl, Second Wind, Iron March)
/// mint, Soul Rend's MP blue, Bloodrage's lifesteal dark crimson, Unholy Ward's soak teal (boss_skills.dart); and a
/// Bayangan's haste (Triumph, omen.dart) mint too, only that one: a monster skill's haste stays ringless.
const _effectRings = {
  Status.slow: Color(0xFF9FE3FF),
  Status.weaken: Color(0xFFB07CFF),
  Status.vulnerable: Color(0xFFFF4040),
  Status.taunt: Color(0xFFFF8A30),
  Status.bleed: Color(0xFFE8203A),
  Status.might: Color(0xFFFFB300),
  Status.shotWard: Color(0xFFB0BEC5),
  Status.daze: Color(0xFFF5EFC8),
  Status.swift: Color(0xFF7CFFB2),
  Status.haste: Color(0xFF7CFFB2),
  Status.soulRend: Color(0xFF4FA3FF),
  Status.lifesteal: Color(0xFF9E1030),
  Status.absorb: Color(0xFF3FD0C0),
  Status.impaled: _impaleLime,
  Status.voidMark: Color(0xFFA040FF),
  Status.pusakaMark: Color(0xFFFF5FA0), // Vengeance Mark's (pusaka_engine.dart): rose
};

extension on Board {
  /// Every frame: the troops that just cast pop their skill's name, each skill on a troop's first cast of a wave
  /// ([FirstCasts], decisions-log 298: they cast far more often; its look shows on every cast); a Hero's cast its
  /// cut-in, at most once every [heroCutEvery] s a Hero and [heroCutGap] s after any other ([HeroCutGate]); a healer
  /// short of MP its "No MP"; old or dead casters' names go.
  void _drainCasts(Game g) {
    for (final u in g.casts) {
      if (troopSkills[u.type] case final s? when _firstCasts.first((u, _PopKind.troop), g.wave)) _pops.add((u, s.name, g.t, _PopKind.troop));
    }
    g.casts.clear();
    for (final (u, s) in g.heroCasts) {
      if (_firstCasts.first((u, _PopKind.hero), g.wave)) _pops.add((u, s.title, g.t, _PopKind.hero)); // a Hero's own skill (#48)
      if (_settings.heroCutIns && _heroCutGate.admit(u, _clock)) _cutIns.add((u, s), _clock); // and its cut-in (hero_cast.dart)
    }
    g.heroCasts.clear();
    for (final u in g.noMp) {
      _pops.add((u, Words.noMp, g.t, _PopKind.noMp)); // a heal found it short of MP (decisions-log 297)
    }
    g.noMp.clear();
    for (final (u, s) in g.monsterCasts) {
      _pops.add((u, s.title, g.t, _PopKind.monster)); // a monster's skill (#59)
      if (s.rank == MonsterRank.moment) _momentAt = g.t; // a boss's moment: the field's edges flash red
      _foeCast(g, u, s); // and a champion's its banner (foe_cut_in.dart)
    }
    g.monsterCasts.clear();
    for (final (u, s, level) in g.awakenCasts) {
      if (_firstCasts.first((u, _PopKind.awaken), g.wave)) _pops.add((u, s.titleAt(level), g.t, _PopKind.awaken)); // an awakening skill (#88), cast or just unlocked
    }
    g.awakenCasts.clear();
    for (final (at, n) in g.goldPops) {
      _goldPops.add((at, n, g.t));
    }
    g.goldPops.clear();
    _matPopsIn(g); // a material dropped (town_look.dart)
    for (final u in g.risen.where((u) => u.alive)) {
      // Resurrection: the one Hero skill that speaks. Not for one fallen again since: its army may be wiped, whose
      // message stands (wipe.dart).
      showMessage('${u.name} rises again!');
    }
    g.risen.clear();
    _pops.removeWhere((p) => g.t - p.$3 >= _popTime || !p.$1.alive);
    _goldPops.removeWhere((p) => g.t - p.$3 >= _popTime);
  }

  /// A Hero skill's icon ([HeroMark]) in [to]: an item's or a relic's, or ui_icons.png's heart, MP bolt or coin.
  void _heroMarkIcon(Canvas c, HeroMark m, Rect to) {
    switch (m) {
      case HeroMark.heart:
        c.drawImageRect(_img('ui_icons.png'), _heartIcon, to, _px);
      case HeroMark.bolt:
        c.drawImageRect(_img('ui_icons.png'), _boltIcon, to, _mpPaint);
      case HeroMark.coin:
        _uiIcon(c, Board._icCoin, to);
      default:
        _icon(c, Item.values.asNameMap()[m.name] ?? Relic.values.byName(m.name), to);
    }
  }

  /// The icons of the Hero skills' effects on troop [u] ([_effectMarks]), a row of small ones centred on
  /// [at] (just above its bars and crown); its ward (a Pusaka's shield, heal.dart: Watch Shield, Bone Buckler) shows
  /// the guard's, as an absorb does.
  void _statusMarks(Canvas c, Game g, Unit u, Offset at) {
    if ((u.effects.isEmpty && u.ward <= 0) || u.side != Side.troop) return;
    // A haste that slows (a monster's Sticky Glob, #59) is no gloves: its slow's ring shows it ([_statusRings]).
    final marks = {
      for (final s in u.effects.keys)
        if (_effectMarks[s] case final m? when g.under(u, s) && !(s == Status.haste && g.effectK(u, s) > 1)) m,
      if (u.ward > 0) HeroMark.guard,
    }.toList();
    const size = 5.0, gap = 1.0;
    var x = at.dx - (marks.length * (size + gap) - gap) / 2;
    for (final m in marks) {
      _heroMarkIcon(c, m, Rect.fromLTWH(x, at.dy - size, size, size));
      x += size + gap;
    }
  }

  /// The rings of the effects on [u] ([_effectRings]) at its feet, one inside another, pulsing like a guard's:
  /// all of a monster's, and a troop's that have no icon over it ([_effectMarks]), which are what the monsters'
  /// skills leave on it (#59: slowed, weakened, marked, taunted, bleeding); and inside them the Bayangan Spree's red
  /// ([_monsterPop]) on a monster that has killed a troop under it (omen.dart).
  void _statusRings(Canvas c, Game g, Unit u, Offset ground) {
    final barrier = u.shield > 0; // a slot's Barrier (omen_look.dart) shows Unholy Ward's teal soak ring
    final enraged = g.omenEnraged(u); // the Bayangan Enrage (omen.dart) shows War Shout's amber might ring
    final spree = u.troopKills > 0 && g.omenK(OmenKind.spree) > 0; // the Bayangan Spree (omen.dart): its kills' red ring
    if ((u.effects.isEmpty && !barrier && !enraged && !spree) || !u.alive) return;
    var i = 0;
    Rect ringAt(int i) => Rect.fromCenter(center: ground - const Offset(0, 1), width: 18.0 - 3 * i, height: 8.0 - 1.2 * i);
    Paint paintOf(Color color, int i) => Paint()
      ..color = color.withValues(alpha: 0.6 + 0.25 * math.sin(_fieldClock * 6 + u.id + i))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final MapEntry(key: s, value: color) in _effectRings.entries) {
      final own = (barrier && s == Status.absorb) || (enraged && s == Status.might);
      if (!(g.under(u, s) || own) || (u.side == Side.troop && _effectMarks.containsKey(s))) continue;
      if (s == Status.haste && !g.effectOn(u, s)!.omen) continue; // a monster skill's haste: no ring
      final ring = ringAt(i), paint = paintOf(color, i);
      if (s == Status.impaled) {
        _impaleRing(c, g, u, ring, ground, paint); // Impale's pin: dashed, the lance through the foe
      } else {
        c.drawOval(ring, paint);
      }
      i++;
    }
    if (spree) c.drawOval(ringAt(i), paintOf(_monsterPop, i));
  }

  /// Impale's pin on monster [u] ([Status.impaled]): its ring in [paint] dashed, ten dashes round [ring], turning
  /// slowly; and the lance stuck slanting through its body, its butt low on the lancer's side and its chartreuse
  /// head high on the other, drawn under the body so that the body hides the middle of it. A hold another troop type put
  /// on (Ice Grip's, pusaka_engine.dart) shows the ring alone.
  void _impaleRing(Canvas c, Game g, Unit u, Rect ring, Offset ground, Paint paint) {
    for (var k = 0; k < 10; k++) {
      c.drawArc(ring, k * math.pi / 5 + _fieldClock * 0.8, math.pi / 10, false, paint);
    }
    final by = g.effectOn(u, Status.impaled)?.by;
    if (by != null && by.type != 'lancer') return; // no lance: a hold, not Impale's pin
    final back = (by?.pos.x ?? u.pos.x - 1) < u.pos.x ? -1.0 : 1.0;
    final butt = ground + Offset(10 * back, -3), head = ground + Offset(-8 * back, -16), along = (head - butt) / (head - butt).distance;
    c.drawLine(butt, head - along * 3, Paint()
      ..color = _shaftSteel
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round);
    final side = Offset(-along.dy, along.dx) * 1.6, neck = head - along * 3.5;
    c.drawPath(
        Path()
          ..moveTo(head.dx, head.dy)
          ..lineTo(neck.dx + side.dx, neck.dy + side.dy)
          ..lineTo(neck.dx - side.dx, neck.dy - side.dy)
          ..close(),
        Paint()..color = _impaleLime);
  }

  /// The lines of the Hero skills' effects that tie two units ([_effectLines]), under every sprite, pulsing.
  void _statusLines(Canvas c, Game g) {
    for (final u in g.troops) {
      if (u.effects.isEmpty || !u.alive) continue;
      for (final MapEntry(key: s, value: color) in _effectLines.entries) {
        final to = g.effectOn(u, s)?.by;
        if (to == null || !to.alive) continue;
        final a = 0.45 + 0.2 * math.sin(_fieldClock * 6 + u.id);
        c.drawLine(Offset(u.pos.x, u.pos.y + 4), Offset(to.pos.x, to.pos.y + 4), Paint()
          ..color = color.withValues(alpha: a)
          ..strokeWidth = 0.8);
      }
    }
  }

  /// How far monster [u] is into its wind-up ([Unit.winding]): 0 as it begins, 1 as it lands (a skill with no
  /// wind-up, Frenzy's or Thick Hide's, is at 1 at once).
  double _windDone(Game g, Unit u) {
    final s = u.winding!;
    return s.wind <= 0 ? 1.0 : (1 - (u.windUntil - g.t) / s.wind).clamp(0.0, 1.0);
  }

  /// The wind-up tells on the ground ([windTells]), under everyone ([_windCircle]): each winding monster's summon
  /// circle at its feet, in red (or its skill's colour), forming frame by frame as the wind-up runs and filling in;
  /// an area skill's reach ringed by the circle's outline frame as wide as it (over twice the circle's size, in dashes
  /// end to end at the units' pixel size; a reach under [_windRingFrom] the circle's width: the filled circle itself
  /// that wide instead). Each one's outline in its rank's colour. Its marks
  /// and a lane's arrows go over everyone ([_windMarks]).
  void _windTells(Canvas c, Game g) {
    for (final u in g.enemies) {
      final s = u.winding;
      if (s == null || !u.alive) continue;
      final tell = windTells[s]!, p = _windDone(g, u), ground = Offset(u.pos.x, u.pos.y + 5 + _shadowMid.dy - _feet.dy); // on its shadow
      if (tell == WindTell.none) continue;
      final (fill, rim) = _windColors[s] ?? (_monsterPop, null);
      final edge = rim ?? _tierBar[u.tier]?.$1 ?? _monsterPop;
      final strong = u.tier.index >= Tier.miniBoss.index, reach = tell == WindTell.area ? 2 * windReachOf(u, s) : _circleW;
      final ring = reach >= _windRingFrom * _circleW;
      if (ring) _windCircle(c, ground, reach, p, fill, edge, strong: strong, seed: u.id, ring: true);
      _windCircle(c, ground, ring ? _circleW : reach, p, fill, edge, strong: strong, seed: u.id);
    }
  }

  /// The summon circle (tiny_fx_summon.png) [width] wide on [ground], [p] of the way into a wind-up: its frames one
  /// by one (the circle drawn, then filled) in [fill] ([_circleTint]), or as a [ring] its outline frames only (the half
  /// drawn, then the whole) flat in [fill] ([_reachRing]: over twice the circle's size in dashes [_windDashStep] apart);
  /// its alpha rising over [windTellAlpha]; once drawn, its outline's outer row in [edge]
  /// ([_windRim]), a mini boss's or boss's ([strong]) pulsing.
  void _windCircle(Canvas c, Offset ground, double width, double p, Color fill, Color edge,
      {required bool strong, int seed = 0, bool ring = false}) {
    final f = math.min(ring ? 1 : _summonFrames - 1, (p * _summonFrames).floor()), a = windTellAlpha.from + (windTellAlpha.to - windTellAlpha.from) * p;
    // A ring flat, so it stands out on the road; over twice the circle's size round the reach in dashes end to end at
    // the units' pixel size ([_reachRing], decisions-log 177), so it still reads whole.
    final k = width / _circleW, count = closeDashes(width / 2, _windDashStep);
    void draw(int frame, Paint paint) =>
        ring ? _reachRing(c, ground, width / 2, frame, paint, count: count) : _groundCircle(c, ground, k, frame, paint);
    draw(f, _sheetPaint(ring ? _flat(fill) : _circleTint(fill), a));
    if (f >= 1) draw(1, _sheetPaint(_windRim(edge), strong ? 0.65 + 0.35 * math.sin(_fieldClock * 12 + seed) : 0.95));
  }

  /// A lane skill's way ([WindTell.lane]): red arrows (ui_icons.png's) lying along it every [_laneStep], over the
  /// troops in it, pointing
  /// the way it goes, lighting up one after another out from the monster; Trample's to the troop it charges,
  /// Grave Wave's [graveWaveK].length towards the troop its line runs at (none: the base).
  void _windLane(Canvas c, Game g, Unit u, MonsterSkill s, double p) {
    final target = g.windTargetsOf(u).firstOrNull?.pos;
    if (target == null && s != MonsterSkill.graveWave) return;
    final from = Offset(u.pos.x, u.pos.y + 5), aim = target ?? math.Point(g.baseX, u.pos.y), d = Offset(aim.x - u.pos.x, aim.y - u.pos.y);
    if (d.distance < 1) return;
    final length = s == MonsterSkill.graveWave ? graveWaveK.length : d.distance, along = d / d.distance, n = (length / _laneStep).floor();
    final icon = d.dx < 0 ? _laneLeft : _laneRight;
    for (var k = 1; k <= n; k++) {
      final lit = ((_fieldClock * 3 - k / n) % 1.0), at = from + along * (k * _laneStep);
      final a = (0.45 + 0.55 * (1 - lit)) * (0.6 + 0.4 * p);
      c.drawImageRect(_img('ui_icons.png'), icon, Rect.fromCenter(center: at, width: icon.width * _laneK, height: icon.height * _laneK * _laneFlat),
          Paint()
            ..filterQuality = FilterQuality.none
            ..color = Colors.white.withValues(alpha: a));
    }
  }

  /// Over everyone: a red marker (ui_icons.png's ▼ at [_windMarkK], bobbing) over each troop a winding monster's skill
  /// will land on ([Game.windTargetsOf]), above its bars (and a Hero's crown); a green one over the monster an
  /// Unholy Ward will shield; and a lane's arrows ([_windLane]), over the troops in its way.
  void _windMarks(Canvas c, Game g) {
    for (final u in g.enemies) {
      final s = u.winding;
      if (s == null || !u.alive) continue;
      if (windTells[s] == WindTell.lane) _windLane(c, g, u, s, _windDone(g, u));
      if (windTells[s] != WindTell.target) continue;
      for (final o in g.windTargetsOf(u)) {
        final lift = o.move?.liftAt(g.t) ?? 0.0, top = unitBar(o.pos.x, o.pos.y - lift, mp: o.stats.mp > 0).box.top - (o.hero ? 9 : 0);
        final icon = o.side == Side.enemy ? _markGreen : _markRed, bob = math.sin(_fieldClock * 8 + o.id).abs() * 1.5;
        final w = icon.width * _windMarkK, h = icon.height * _windMarkK;
        c.drawImageRect(_img('ui_icons.png'), icon, Rect.fromLTWH(o.pos.x - w / 2, top - 1 - h - bob, w, h), _px);
      }
    }
  }

  /// A boss's moment winding up: the edges of the [field] (on the screen) flash red for [momentVignette].time s
  /// (game clock), deepest at its start, over the field and under the HUD ([Board._momentAt]).
  void _momentVignette(Canvas c, Game g, Rect field) {
    final since = g.t - _momentAt;
    if (since < 0 || since >= momentVignette.time) return;
    final a = momentVignette.alpha * (1 - since / momentVignette.time), d = momentVignette.depth * field.shortestSide;
    final edge = _momentRed.withValues(alpha: a), clear = _momentRed.withValues(alpha: 0);
    final Rect(:left, :top, :right, :bottom) = field;
    for (final (r, from, to) in [
      (Rect.fromLTRB(left, top, right, top + d), Offset(left, top), Offset(left, top + d)),
      (Rect.fromLTRB(left, bottom - d, right, bottom), Offset(left, bottom), Offset(left, bottom - d)),
      (Rect.fromLTRB(left, top, left + d, bottom), Offset(left, top), Offset(left + d, top)),
      (Rect.fromLTRB(right - d, top, right, bottom), Offset(right, top), Offset(right - d, top)),
    ]) {
      c.drawRect(r, Paint()..shader = ui.Gradient.linear(from, to, [edge, clear]));
    }
  }

  /// A guarded unit's ring at its feet, pulsing, fading out over its last half second.
  void _guardRing(Canvas c, Game g, Unit u, Offset ground) {
    final left = u.guardUntil - g.t;
    if (left <= 0 || !u.alive) return;
    final a = math.min(1.0, left / 0.5) * (0.55 + 0.25 * math.sin(_fieldClock * 6 + u.id));
    final color = _ringColors[u.guardLook] ?? _troopPop; // pale blue, or its skill's ([Unit.guardLook]: #59, #81)
    c.drawOval(Rect.fromCenter(center: ground - const Offset(0, 1), width: 16, height: 7), Paint()
      ..color = color.withValues(alpha: a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
  }

  /// The skills' names over their casters' bars, rising and fading (screen space, over the field). A name
  /// that would cover one already drawn goes up above it.
  void _castPops(Canvas c, Game g, Offset o, double s) {
    final base = (6 * s).clamp(16.0, 26.0), taken = <Rect>[];
    for (final (u, name, t0, kind) in _pops) {
      final p = (g.t - t0) / _popTime, fade = p > 0.7 ? (1 - p) / 0.3 : 1.0, size = kind == _PopKind.hero ? base * _heroPopScale : base;
      var box = Rect.fromCenter(
          center: o + Offset(u.pos.x - camX, backdropH + u.pos.y - 30 - 8 * p) * s, width: _textWidth(name, size) + 4, height: size + 2);
      while (taken.any((r) => r.overlaps(box))) {
        box = box.shift(Offset(0, -box.height));
      }
      taken.add(box);
      _text(c, name, box.center, size: size, anchor: Anchor.center,
          color: switch (kind) {
            _PopKind.troop || _PopKind.awaken => _troopPop,
            _PopKind.hero => _heroPop,
            _PopKind.monster => _monsterPop,
            _PopKind.noMp => _noMpPop,
          }
              .withValues(alpha: fade),
          outline: _dark.withValues(alpha: fade));
    }
    // Plunder's extra gold: "+N" after a coin, rising from where it was paid.
    for (final (at, n, t0) in _goldPops) {
      final p = (g.t - t0) / _popTime, fade = p > 0.7 ? (1 - p) / 0.3 : 1.0, size = base * 0.8;
      final mid = o + Offset(at.x - camX, backdropH + at.y - 14 - 10 * p) * s;
      _uiIcon(c, Board._icCoin, Rect.fromCenter(center: mid - Offset(size * 0.6, 0), width: size, height: size));
      _text(c, '+$n', mid, size: size, color: _heroPop.withValues(alpha: fade), outline: _dark.withValues(alpha: fade));
    }
    _matPopsDraw(c, g, o, s); // town_look.dart: a dropped material hopping onto its pile
  }

  /// A troop skill's ring's part on the ground (#81), under everyone ([_groundRings]). True when it takes the
  /// plain ring's place (or has none: its look stands over everyone, [_skillsAbove]); false when the plain ring is
  /// drawn (Rampage's, Healing Prayer's, Holy Shield's, Crushing Blow's and Arcane Blast's reach) or it is a plain
  /// ring.
  bool _skillGround(Canvas c, Game g, Ring r) {
    final p = ((g.t - r.since) / (r.until - r.since)).clamp(0.0, 1.0), grow = 1 - (1 - p) * (1 - p), a = 1 - p;
    final ground = Offset(r.centre.x, r.centre.y + 5);
    switch (r.look) {
      case RingLook.brace:
        // Hold Fast: the ground circle's ring in steel blue closing in on the soldier's feet from twice its size,
        // and gone.
        _groundCircle(c, ground, _circleScale(r.radius) * (2 - grow), 1, _sheetPaint(_braceTint, a));
        return true;
      case RingLook.crack:
        // Crushing Blow: fx_hit_armored_orc.png's ring of dust bursting out over its reach round the axeman, on the
        // ground under everyone (from its 4th frame: the first three are a solid puff); the plain dust ring over it.
        _sheetAt(c, 'fx_hit_armored_orc.png', p, ground - const Offset(0, 4), 2 * r.radius, _sheetPaint(_dustTint, 1), first: 3);
        return false;
      case RingLook.slash || RingLook.pillar || RingLook.dome || RingLook.shatter || RingLook.shards || RingLook.crossCut || RingLook.bloom:
        // They stand over everyone ([_skillsAbove]): Circle Slash's blade, Healing Prayer's and Lifeline's heals, Holy
        // Shield's ring, Impale's and Disarm's shards, Phantom Rush's X (Disarm's weaken ring marks the ground).
        return true;
      case RingLook.cleave || RingLook.spin || RingLook.ward:
        return true; // a champion's landing (#59): Brutal Swing's crescent, Blade Dance's spin, Shield Up's shield, over everyone
      case RingLook.crater:
        // Skyfall: the same ring of bits as Crushing Blow's, in ash, over its radius where the axeman lands, under
        // everyone; the plain ash ring over it.
        _sheetAt(c, 'fx_hit_armored_orc.png', p, ground - const Offset(0, 4), 2 * r.radius, _sheetPaint(_ashDye, 1), first: 3);
        return false;
      case RingLook.dispel:
        // Spellbreaker: the ground circle with its star (tiny_fx_summon.png's last frames, a rune circle) over the
        // spread it strips, in silver, fading.
        _groundCircle(c, ground, _circleScale(r.radius), 2 + (p * 5).floor().clamp(0, 4), _sheetPaint(_silverTint, a));
        return true;
      case RingLook.implode:
        // Singularity's end: the well's ring of dashes in indigo ([_reachRing]) collapsing from its edge into its core,
        // faster as it goes and turning (the burst from its core over the last 30%: [_skillsAbove]).
        if (p < 0.7) {
          final q = p / 0.7;
          _reachRing(c, ground, _wellCore + (r.radius - _wellCore) * (1 - q * q), 1, _sheetPaint(_indigoTint, 0.5 + 0.5 * q),
              turn: q / 2, dashed: true);
        }
        return true;
      default:
        return false; // a plain ring: a monster's, or Rampage's, Healing Prayer's and Holy Shield's burst
    }
  }

  /// The troop skills' rings' parts that stand up (#81), over everyone and the hit bursts, each a pack sheet's frames
  /// over the ring's time ([_sheetAt]): Hold Fast's shield, Circle Slash's blade, Rampage's sparks, Healing Prayer's
  /// heals and Holy Shield's rings; the awakening skills' (#88) Impale's and Disarm's shards, Unbroken's burst,
  /// Phantom Rush's X, Lifeline's heal and Singularity's last burst; the champions' landings (#59) Brutal Swing's
  /// crescent, Blade Dance's spin and Shield Up's shield.
  void _skillsAbove(Canvas c, Game g) {
    for (final r in g.rings) {
      final p = ((g.t - r.since) / (r.until - r.since)).clamp(0.0, 1.0), at = r.centre;
      final dir = (r.follow?.dir ?? 1) < 0 ? -1.0 : 1.0, fade = p < 0.5 ? 1.0 : (1 - p) / 0.5;
      final body = Offset(at.x, at.y - 6), feet = Offset(at.x, at.y + 5);
      switch (r.look) {
        case RingLook.brace:
          // ui_icons.png's steel shield flashing before the soldier's body the way it faces, at half its pixels
          // (as the Hero's crown), popping in from 1.5× its size.
          final k = p < 0.2 ? 1.5 - 2.5 * p : 1.0, w = 8 * k;
          _uiIcon(c, _icSteelShield, Rect.fromCenter(center: Offset(at.x + 6 * dir, at.y - 7), width: w, height: w), _sheetPaint(null, fade));
        case RingLook.slash:
          // fx_hit_greatsword_skeleton.png's sweeping slash round the knight at its waist, the way it faces, a little
          // wider than its reach, in the blade's pale blue.
          _sheetAt(c, 'fx_hit_greatsword_skeleton.png', p, body + Offset(4 * dir, 0), 2.2 * r.radius, _sheetPaint(_bladeDye, 1), flip: dir < 0);
        case RingLook.rage:
          // fx_hit_werebear.png's bits bursting off the swordsman's body, in ember.
          _sheetAt(c, 'fx_hit_werebear.png', p, body, 2 * r.radius, _sheetPaint(_emberTint, 1));
        case RingLook.pillar:
          // The pack's heal (tiny_fx_heal.png) over the troop at its feet, in mint, slower than a plain heal.
          final n = _frames('tiny_fx_heal.png');
          _frame(c, 'tiny_fx_heal.png', math.min(n - 1, (p * n).floor()), feet, paint: _sheetPaint(_mintTint, fade));
        case RingLook.dome:
          // fx_hit_knight_templar.png's ring (the templar's own hit) round the troop, in white (from its 3rd frame:
          // the first two are a filled disc that would hide it).
          _sheetAt(c, 'fx_hit_knight_templar.png', p, body, 2.8 * r.radius, _sheetPaint(_holyWhiteTint, fade), first: 2);
        case RingLook.shatter:
          // Impale's break: fx_hit_skeleton.png's white shards bursting off the foe's body, at the sheet's own pixels,
          // in chartreuse.
          _sheetAt(c, 'fx_hit_skeleton.png', p, Offset(at.x, at.y - 7), 64, _sheetPaint(_limeDye, 1));
        case RingLook.shards:
          // Disarm: the same shards, half as big, bursting from the foe's weapon arm (the side facing the soldier, at
          // body height), in iron.
          _sheetAt(c, 'fx_hit_skeleton.png', p, Offset(at.x + 3 * dir, at.y - 8), _burstSize, _sheetPaint(_ironTint, 1));
        case RingLook.unchain:
          // Unbroken: fx_hit_armored_skeleton.png's ring of spikes bursting round the knight at knee height (from its 4th
          // frame: the first three are a star over its body), in cyan (its cyan ring at its feet under it).
          _sheetAt(c, 'fx_hit_armored_skeleton.png', p, Offset(at.x, at.y - 2), 2.4 * r.radius, _sheetPaint(_cyanDye, 1), first: 3);
        case RingLook.crossCut:
          // Phantom Rush: fx_hit_swordsman.png's X slashed across the foe's body (from its 4th frame: the first three are
          // a solid cross), in magenta.
          _sheetAt(c, 'fx_hit_swordsman.png', p, Offset(at.x, at.y - 7), _burstSize, _sheetPaint(_rushDye, 1), flip: dir < 0, first: 3);
        case RingLook.bloom:
          // Lifeline: the pack's heal (tiny_fx_heal.png) at the troop's feet as it lands, in mint.
          _frame(c, 'tiny_fx_heal.png', math.min(3, (p * 4).floor()), feet, paint: _sheetPaint(_mintTint, fade));
        case RingLook.implode when p >= 0.7:
          // Singularity's end: fx_hit_wizard.png's burst from the well's core over the last 30%, in indigo.
          _sheetAt(c, 'fx_hit_wizard.png', (p - 0.7) / 0.3, Offset(at.x, at.y), _burstSize, _sheetPaint(_indigoDye, 1));
        case RingLook.cleave:
          // Brutal Swing: fx_hit_armored_axeman.png's crescent sweeping before the elite orc at its waist, the way it
          // faces, white with a deep red edge.
          _sheetAt(c, 'fx_hit_armored_axeman.png', p, body + Offset(dir * r.radius / 2, 0), _burstSize * _bigScale, _sheetPaint(_cleaveTint, 1),
              flip: dir < 0);
        case RingLook.spin:
          _bladeSpin(c, body, _sweepK * r.radius, p);
        case RingLook.ward when r.follow != null && g.under(r.follow!, Status.shotWard):
          // Shield Up: ui_icons.png's steel shield before the armored skeleton's body the way it faces (at the troops),
          // popping in, gently pulsing while the ward lasts and fading over its last half second.
          final since = g.t - r.since, k = since < _wardPop ? 1.5 - 0.5 * since / _wardPop : 1.0, w = 16 * _windMarkK * k;
          final a = math.min(1.0, (r.until - g.t) / 0.5) * (0.85 + 0.15 * math.sin(_fieldClock * 5 + r.follow!.id));
          _uiIcon(c, _icSteelShield, Rect.fromCenter(center: Offset(at.x + 8 * dir, at.y - 7), width: w, height: w), _sheetPaint(null, a));
        default:
          break;
      }
    }
  }

  /// Blade Dance's spin ([RingLook.spin]), [p] of the way through one cut: the greatsword skeleton's own slash
  /// (fx_hit_greatsword_skeleton.png, its frames over the spin, [size] world units tall) three times round its [body], a
  /// third of a turn apart, the three turning a third of a turn together, white as the sheet is.
  void _bladeSpin(Canvas c, Offset body, double size, double p) {
    const name = 'fx_hit_greatsword_skeleton.png';
    final fs = _img(name).height.toDouble(), n = _frames(name), f = math.min(n - 1, (p * n).floor());
    for (var k = 0; k < 3; k++) {
      c.save();
      c.translate(body.dx, body.dy);
      c.rotate((k + p) * 2 * math.pi / 3);
      c.scale(size / fs);
      _frame(c, name, f, Offset.zero, anchor: Offset(fs / 2, fs / 2));
      c.restore();
    }
  }

  /// Phantom Rush's afterimages ([CarryLook.ghost]): while the swordsman [u] dashes, two copies of its body in flat
  /// magenta trail it along its dash, at 0.3 and 0.6 of the dash behind it, fainter the further back. [k] is its
  /// sprites' key, [flip] its facing.
  void _afterimages(Canvas c, Game g, Unit u, String k, bool flip) {
    final m = u.move;
    if (m is! Carry || m.look != CarryLook.ghost || !u.alive) return;
    final p = m.progress(g.t);
    for (final (lag, a) in [(0.3, 0.5), (0.6, 0.28)]) {
      final at = m.from + (m.to - m.from) * math.max(0.0, p - lag);
      if (at.distanceTo(u.pos) < 1.5) continue;
      _frame(c, '${k}_walk.png', (g.t * _fps).floor(), Offset(at.x, at.y + 5), flip: flip, paint: Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = _rushFilter
        ..color = Colors.white.withValues(alpha: a));
    }
  }

  /// Skyfall's landing shadow ([CarryLook.skyfall]) on the ground, under everyone: while the axeman is in the air, its
  /// own ground shadow (tiny_armored_axeman_shadow.png) where it comes down, darkening as it falls and growing with
  /// the radius it will hit (40% of it, then all), in whole scales of the units' pixels up to [_stretchMax]
  /// (decisions-log 177): its own size, then twice it.
  void _landingShadows(Canvas c, Game g) {
    for (final u in g.troops) {
      final m = u.move;
      if (m is! Carry || m.look != CarryLook.skyfall || !u.alive) continue;
      final p = m.progress(g.t), k = (2 * m.radius * (0.4 + 0.6 * p) / _shadowW).roundToDouble().clamp(1.0, _stretchMax);
      c.save();
      c.translate(m.to.x, m.to.y + 5);
      c.scale(k);
      _frame(c, 'tiny_${u.type}_shadow.png', 0, Offset.zero, anchor: _shadowMid, paint: _sheetPaint(null, 0.45 + 0.55 * p));
      c.restore();
    }
  }

  /// A Phantom Rush dash's streak ([BeamLook.rush]) at body height: fx_hit_soldier.png's slash (its first three frames,
  /// the ones slashing the same way) laid from where it set off to where it cut ([_streak]), in magenta.
  void _rushBeam(Canvas c, Game g, Beam b) => _streak(c, g, b, 'fx_hit_soldier.png', _rushRun, _sheetPaint(_rushDye, 1), frames: 3);

  /// Lifeline's ribbon ([BeamLook.tether]) from the priest to the troop it lifts, at body height (the troop's in the
  /// air with it): a mint ribbon waving gently round a white core, with white motes flowing along it to the priest;
  /// it comes in over 0.1 s and fades over its last 0.3 s.
  void _tetherBeam(Canvas c, Game g, Beam b) {
    final a = math.min(1.0, math.min((g.t - b.since) / 0.1, (b.until - g.t) / 0.3)).clamp(0.0, 1.0);
    final ends = [for (final (i, p) in b.at.indexed) Offset(p.x, p.y - 6 - (b.follow?[i].move?.liftAt(g.t) ?? 0))];
    final from = ends.first, to = ends.last, d = to - from;
    if (d.distance < 1 || a <= 0) return;
    final side = Offset(-d.dy, d.dx) / d.distance, n = math.max(6, (d.distance / 3).round()), path = Path()..moveTo(from.dx, from.dy);
    for (var k = 1; k <= n; k++) {
      final f = k / n, q = from + d * f + side * (math.sin(f * d.distance / 6 - g.t * 8) * 1.6 * math.sin(f * math.pi));
      path.lineTo(q.dx, q.dy);
    }
    c.drawPath(path, Paint()
      ..color = _mint.withValues(alpha: 0.6 * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeJoin = StrokeJoin.round);
    c.drawPath(path, Paint()
      ..color = Colors.white.withValues(alpha: 0.85 * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round);
    for (var k = 0; k < 5; k++) {
      final f = 1 - ((g.t * 1.8 + k / 5) % 1.0); // from the troop's end to the priest's
      c.drawCircle(Offset.lerp(from, to, f)!, 1.2, Paint()..color = Colors.white.withValues(alpha: a * math.sin(f * math.pi)));
    }
  }

  /// Consecration's holy ground ([ZoneLook.consecrate]), under everyone, its alpha in its paints: the pack's ground
  /// circle over its reach in rose, drawing itself (its front half, then the whole ring) and then its star turning
  /// slowly ([_circleFrame]), and the pack's heal (tiny_fx_heal.png, its crosses rising) in rose on spots of its own
  /// on it, taking turns ([_zoneTurns]); it comes in over 0.15 s and fades over its last 0.5 s.
  void _consecration(Canvas c, Game g, Zone z) {
    final since = g.t - z.since, a = math.min(1.0, math.min(since / 0.15, (z.until - g.t) / 0.5)).clamp(0.0, 1.0);
    if (a <= 0) return;
    final ground = Offset(z.at.x, z.at.y + 5), paint = _sheetPaint(_roseTint, a), n = _frames('tiny_fx_heal.png');
    _groundCircle(c, ground, _circleScale(z.radius), _circleFrame(since, fps: _fps / 2), paint);
    for (final (at, p) in _zoneTurns(z, ground, since, _crossPer, _crossTime, 0.6)) {
      _frame(c, 'tiny_fx_heal.png', math.min(n - 1, (p * n).floor()), at, paint: paint);
    }
  }

  /// Singularity's well ([ZoneLook.singularity]), under everyone, its alpha in its paint, all at the units' pixel size
  /// (decisions-log 177): the pack's ground circle's ring in indigo round its reach in dashes turning slowly
  /// ([_reachRing]); [_wellPulls] more such rings drawn in from the reach to the core, faster as they near it and
  /// turning on, one after another (the pull); and at its core the circle itself at its own size, drawing itself and
  /// then its star churning fast ([_circleFrame]). It comes in over 0.15 s and goes in its last 0.2 s (its end:
  /// [RingLook.implode]).
  void _singularityWell(Canvas c, Game g, Zone z) {
    final since = g.t - z.since, a = math.min(1.0, math.min(since / 0.15, (z.until - g.t) / 0.2)).clamp(0.0, 1.0);
    if (a <= 0) return;
    final ground = Offset(z.at.x, z.at.y + 5), paint = _sheetPaint(_indigoTint, a), turn = since * _wellTurn;
    _reachRing(c, ground, z.radius, _ringFrame(since), paint, turn: turn, dashed: true);
    for (var i = 0; i < _wellPulls; i++) {
      final q = (since / _wellPullTime + i / _wellPulls) % 1.0;
      _reachRing(c, ground, _wellCore + (z.radius - _wellCore) * (1 - q * q), 1, _sheetPaint(_indigoTint, a * math.sin(math.pi * q)),
          turn: turn + q * q / 2, dashed: true);
    }
    _groundCircle(c, ground, 1, _circleFrame(since, fps: 2 * _fps), paint);
  }

  /// Impale's lunge ([BeamLook.lunge]) at body height: the lancer's own thrust streak (fx_hit_lancer.png, as Piercing
  /// Thrust's) laid from the lancer to the foe ([_streak]), in chartreuse.
  void _lungeBeam(Canvas c, Game g, Beam b) {
    final points = b.at;
    if (points.first.distanceTo(points.last) < 4) return;
    _streak(c, g, b, 'fx_hit_lancer.png', _thrustRun, _sheetPaint(_limeDye, 1));
  }

  /// Piercing Thrust's streak ([BeamLook.thrust]) at body height: fx_hit_lancer.png's thrust streak laid along the line
  /// from the lancer to the end of its reach ([_streak]), dyed teal.
  void _thrustBeam(Canvas c, Game g, Beam b) => _streak(c, g, b, 'fx_hit_lancer.png', _thrustRun, _sheetPaint(_thrustDye, 1));

  /// Beam [b]'s look as fx sheet [name]'s frames over its time (its first [frames], or all), at body height, the
  /// sheet's [run] (where its streak starts and ends in its frame) turned and stretched onto the beam's first point and
  /// its last.
  void _streak(Canvas c, Game g, Beam b, String name, (Offset, Offset) run, Paint paint, {int? frames}) {
    final points = b.at, from = Offset(points.first.x, points.first.y - 6), to = Offset(points.last.x, points.last.y - 6), d = to - from;
    final (start, end) = run;
    if (d.distance < 1) return;
    final p = ((g.t - b.since) / (b.until - b.since)).clamp(0.0, 1.0), along = end - start, n = frames ?? _frames(name);
    c.save();
    c.translate(from.dx, from.dy);
    c.rotate(d.direction - along.direction);
    c.scale(d.distance / along.distance);
    _frame(c, name, math.min(n - 1, (p * n).floor()), Offset.zero, anchor: start, paint: paint);
    c.restore();
  }

  /// Arrow Rain's arrows ([ZoneLook.volley]): the archer's own (in its awakening's colour), one after another over
  /// the first half of the zone's time, each falling [_rainHigh] onto a spot of its own over [_rainFall] s and then
  /// standing in the ground, fading out by the zone's end.
  void _volleyArrows(Canvas c, Game g, Zone z) {
    final n = math.max(4, (z.radius / _rainPer).round()), time = z.until - z.since, dice = math.Random(identityHashCode(z));
    final level = g.awakenLevel(z.from.type), tint = level > 0 ? _tint(_fxColor(level)) : null;
    for (var i = 0; i < n; i++) {
      final ang = dice.nextDouble() * 2 * math.pi, r = math.sqrt(dice.nextDouble()) * z.radius * 0.9;
      final start = z.since + i * time / 2 / n, p = g.t - start;
      if (p < 0) continue;
      final ground = Offset(z.at.x + math.cos(ang) * r, z.at.y + 5 + math.sin(ang) * r * _groundFlat);
      final landed = start + _rainFall, fade = g.t < landed ? 1.0 : ((z.until - g.t) / (z.until - landed)).clamp(0.0, 1.0);
      _fallingArrow(c, 'tiny_arrow_archer.png', ground, (p / _rainFall).clamp(0.0, 1.0), Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = tint
        ..color = Colors.white.withValues(alpha: fade));
    }
  }

  /// How far into Rampage's last half second [u] is: 1 while it rages, down to 0 as it ends; 0 when it doesn't.
  double _rageLeft(Game g, Unit u) => u.alive && g.t < u.frenzyUntil ? math.min(1.0, (u.frenzyUntil - g.t) / 0.5) : 0;

  /// Rampage's aura while it lasts ([Unit.frenzyUntil]), behind the swordsman's body: fx_hit_orc.png's flames rising
  /// out of the ground (its middle frames, [_rageFlames], over and over) at its feet in ember, at the hit bursts' size;
  /// fading out over its last half second.
  void _rageGlow(Canvas c, Game g, Unit u, Offset feet) {
    final fade = _rageLeft(g, u);
    if (fade == 0) return;
    const name = 'fx_hit_orc.png', fs = 40.0; // its flames' foot on the frame's bottom row
    final f = _rageFlames[((_fieldClock * _fxFps).floor() + u.id) % _rageFlames.length];
    c.save();
    c.translate(feet.dx, feet.dy + 1);
    c.scale(_burstSize / fs);
    _frame(c, name, f, Offset.zero, anchor: const Offset(fs / 2, fs), paint: _sheetPaint(_emberTint, 0.85 * fade));
    c.restore();
  }

  /// A raging swordsman's outline (drawn round its body like awakening's, [_awakeLine]) in ember, flickering;
  /// null when it doesn't rage.
  Paint? _rageLine(Game g, Unit u) {
    final fade = _rageLeft(g, u);
    return fade == 0
        ? null
        : (Paint()
          ..filterQuality = FilterQuality.none
          ..colorFilter = _rageFilter
          ..color = Colors.white.withValues(alpha: fade * (0.75 + 0.25 * math.sin(_fieldClock * 20 + u.id))));
  }


  /// The frame of fx sheet [name] at progress [p] (0..1) of a look's time, from its frame [first] to its last,
  /// centred on [at], its frame [size] world units tall ([_sheetFrame]).
  void _sheetAt(Canvas c, String name, double p, Offset at, double size, Paint paint, {bool flip = false, int first = 0}) {
    final n = _frames(name) - first;
    _sheetFrame(c, name, first + math.min(n - 1, (p * n).floor()), at, size, paint, flip: flip);
  }
}
