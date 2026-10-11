part of 'game.dart';

// Monsters' own skills (#59; docs/units-and-combat.md, "Monster skills"; the design and the owner's answers in
// reports/monster-skills-design.md). A monster type has a signature skill that its high elites and up cast by
// themselves during a wave, on a cooldown (monsters have no MP; the healing necromancer pays from its own).
// Every cast winds up first: the monster stands still with its title over it in red, and a stun, a shove or
// a march in that time cancels it (the troops' holds are the answer). A mini boss or a boss of the type casts
// it stronger and has its type's mini-boss skill too, and the boss its moment, once, at half its HP
// (lib/boss_skills.dart). A skill's blow on a troop takes at most [monsterSkillCap] of its max HP.
//
// A new skill plugs in here: its [MonsterSkill], a case in [MonsterSkills.wantsMonsterSkill] and
// [MonsterSkills._castMonsterSkill], and its numbers as `<id>K`. A later branch keeps its skills in a part file
// of its own, sent there from one arm in each switch (branch 2a: monster_skill_moves.dart; 2b:
// monster_skill_signatures.dart; branch 3, the mini-boss skills and the boss's moments: boss_skills.dart, the
// switches' last arms).

/// Which of a type's skills: its [signature] (from [Tier.highElite] up), its [miniBoss] skill (a mini boss's
/// and a boss's) or the boss's [moment] (once, [bossMomentK]).
enum MonsterRank { signature, miniBoss, moment }

/// The monster skills: their type, the English [title] the owner asked for, the [cooldown] and the [wind]-up
/// (s), and their [rank] ([monsterSkillsOf]); a once-only one's cooldown is infinite. The signatures first, then
/// the mini-boss skills and the moments (boss_skills.dart).
enum MonsterSkill {
  warShout('orc', 'War Shout', 14, 0.4),
  volley('skeleton_archer', 'Volley', 12, 0.6),
  shieldUp('armored_skeleton', 'Shield Up', 12, 0.3),
  brutalSwing('elite_orc', 'Brutal Swing', 10, 0.6),
  bulwark('armored_orc', 'Bulwark', 16, 0.4),
  bladeDance('greatsword_skeleton', 'Blade Dance', 14, 0.4),
  massMend(necroHealer, 'Mass Mend', 18, 0.6),

  // #59 branch 2a (monster_skill_moves.dart)
  stickyGlob('slime', 'Sticky Glob', 10, 0.4),
  swoop('bat', 'Swoop', 12, 0.4),
  pounce('werewolf', 'Pounce', 12, 0.4),
  trample('orc_rider', 'Trample', 15, 0.5),
  // #59 branch 2b (monster_skill_signatures.dart). Reassemble is passive: the killing blow sets it off.
  reassemble('skeleton', 'Reassemble', double.infinity, 0),
  maul('werebear', 'Maul', 12, 0.8),
  curseOfFrailty(boss, 'Curse of Frailty', 18, 0.6),

  // #59 branch 3 (boss_skills.dart): the mini-boss skills, then the boss's moments.
  split('slime', 'Split', double.infinity, 0, MonsterRank.miniBoss),
  screech('bat', 'Screech', 15, 0.5, MonsterRank.miniBoss),
  boneShield('skeleton', 'Bone Shield', 15, 0.4, MonsterRank.miniBoss),
  headbutt('orc', 'Headbutt', 12, 0.5, MonsterRank.miniBoss),
  barbedArrow('skeleton_archer', 'Barbed Arrow', 14, 0.5, MonsterRank.miniBoss),
  frenzy('werewolf', 'Frenzy', double.infinity, 0, MonsterRank.miniBoss),
  boneBash('armored_skeleton', 'Bone Bash', 14, 0.5, MonsterRank.miniBoss),
  spearThrow('orc_rider', 'Spear Throw', 12, 0.5, MonsterRank.miniBoss),
  bloodrage('elite_orc', 'Bloodrage', 20, 0.4, MonsterRank.miniBoss),
  groundSlam('armored_orc', 'Ground Slam', 14, 0.6, MonsterRank.miniBoss),
  soulRend('greatsword_skeleton', 'Soul Rend', 18, 0.4, MonsterRank.miniBoss),
  thickHide('werebear', 'Thick Hide', double.infinity, 0, MonsterRank.miniBoss),
  soulDrain(boss, 'Soul Drain', 20, 0.6, MonsterRank.miniBoss),
  unholyWard(necroHealer, 'Unholy Ward', 16, 0.4, MonsterRank.miniBoss),
  slimeTide('slime', 'Slime Tide', double.infinity, 0.6, MonsterRank.moment),
  swarm('bat', 'Swarm', double.infinity, 0.6, MonsterRank.moment),
  graveCall('skeleton', 'Grave Call', double.infinity, 0.8, MonsterRank.moment),
  rally('orc', 'Rally', double.infinity, 0.8, MonsterRank.moment),
  boneRain('skeleton_archer', 'Bone Rain', double.infinity, 0.8, MonsterRank.moment),
  howl('werewolf', 'Howl', double.infinity, 0.8, MonsterRank.moment),
  ironMarch('armored_skeleton', 'Iron March', double.infinity, 0.6, MonsterRank.moment),
  secondWind('orc_rider', 'Second Wind', double.infinity, 0.6, MonsterRank.moment),
  skullCrusher('elite_orc', 'Skull Crusher', double.infinity, 1.0, MonsterRank.moment),
  earthshaker('armored_orc', 'Earthshaker', double.infinity, 0.8, MonsterRank.moment),
  graveWave('greatsword_skeleton', 'Grave Wave', double.infinity, 0.8, MonsterRank.moment),
  roar('werebear', 'Roar', double.infinity, 0.8, MonsterRank.moment),
  deathNova(boss, 'Death Nova', double.infinity, 1.0, MonsterRank.moment),
  lastRites(necroHealer, 'Last Rites', double.infinity, 1.0, MonsterRank.moment);

  const MonsterSkill(this.type, this.title, this.cooldown, this.wind, [this.rank = MonsterRank.signature]);

  final String type, title;
  final double cooldown, wind;
  final MonsterRank rank;
}

/// A skill's cast takes at most this share of a troop's max HP, a Hero's less: no single cast kills outright. A
/// skill that strikes one troop several times in a cast (Blade Dance's cuts, Volley's arrows) shares it among
/// those hits (decision 110).
const monsterSkillCap = (troop: 0.35, hero: 0.25);

/// The share of troop [o]'s max HP one monster skill's blow may take ([monsterSkillCap]): for a blow worked
/// out ahead (a shot's damage) or a bleed's, where [MonsterSkills._skillBlow] doesn't apply it.
double monsterSkillCapOf(Unit o) => o.hero ? monsterSkillCap.hero : monsterSkillCap.troop;

/// A monster's first cast comes [firstCastAfter].from s after it comes on, plus a second for each place in the
/// wave's queue up to [firstCastAfter].steps − 1, so a wave's high elites don't all cast on arrival.
const firstCastAfter = (from: 2.0, steps: 4);

/// War Shout (orc): with [warShoutK].crowd+ monsters within [warShoutK].reach (itself too) that struck in the
/// last [warShoutK].fought s, each of them deals [warShoutK].might× (a mini boss's or boss's: [warShoutK].strong×)
/// for [warShoutK].time s.
const warShoutK = (crowd: 3, reach: 2 * tile, fought: 2.0, might: 1.2, strong: 1.3, time: 5.0);

/// Volley (skeleton archer): with [volleyK].crowd+ troops in range, [volleyK].arrows arrows at once (a mini
/// boss's or boss's: [volleyK].strong), each [volleyK].hit× its damage, at as many troops in range, nearest
/// first (again from the nearest when there are fewer).
const volleyK = (crowd: 2, arrows: 3, strong: 5, hit: 0.8);

/// Shield Up (armored skeleton): hit by a long-range troop in the last [shieldUpK].within s, it takes
/// [shieldUpK].ward× from long-range troops for [shieldUpK].time s ([Status.shotWard]); a mini boss's or boss's
/// covers the monsters within [shieldUpK].behind behind it too.
const shieldUpK = (within: 1.0, ward: 0.5, time: 4.0, behind: tile);

/// Brutal Swing (elite orc): with [brutalSwingK].crowd+ troops in reach, one swing at each of them for
/// [brutalSwingK].hit× its damage (a mini boss's or boss's: [brutalSwingK].strong×).
const brutalSwingK = (crowd: 2, hit: 1.2, strong: 1.5);

/// Bulwark (armored orc): with [bulwarkK].crowd+ troops in reach, or a monster within [bulwarkK].reach below
/// [bulwarkK].hurt of its HP, the melee troops within [bulwarkK].reach fight it for [bulwarkK].time s
/// ([Status.taunt]) and it takes [bulwarkK].cut less meanwhile; a mini boss's or boss's also sends back
/// [bulwarkK].reflect of every melee blow.
const bulwarkK = (crowd: 2, reach: 2 * tile, hurt: 0.5, time: 4.0, cut: 0.3, reflect: 0.3);

/// Blade Dance (greatsword skeleton): with [bladeDanceK].crowd+ troops within [bladeDanceK].reach, it spins:
/// [bladeDanceK].cuts cuts (a mini boss's or boss's: [bladeDanceK].strong) [bladeDanceK].gap s apart, each
/// [bladeDanceK].hit× its damage to every troop within [bladeDanceK].reach.
const bladeDanceK = (crowd: 2, reach: 1.5 * tile, hit: 0.7, cuts: 3, strong: 4, gap: 0.5);

/// Mass Mend (healing necromancer): with [massMendK].crowd+ monsters within [massMendK].reach below
/// [massMendK].hurt of their HP (itself too), every hurt monster there gets [massMendK].heal× its heal (a mini
/// boss's or boss's: [massMendK].strong×), for [massMendK].cost × [necroHealCost] MP. Its heals don't stack
/// either ([healWindow]): a monster in another healer's window neither counts nor gets one, and each one
/// healed opens its own.
const massMendK = (crowd: 2, reach: 2 * tile, hurt: 0.7, heal: 1.0, strong: 1.5, cost: 2);

/// The landing looks of the champions' weakest-looking skills (docs/ui-hud.md "A monster's skill"; they only show):
/// how long Brutal Swing's crescent and each of Blade Dance's spins take (s), and the radius of the red ring under each
/// troop a Volley aims at (a Rally's ring round an orc's). Shield Up's shield shows while its ward lasts
/// ([shieldUpK].time), Bulwark's orange ring [ringTime].
const landingLook = (cleave: 0.4, spin: 0.3, mark: tile);

/// [type]'s skill of [rank] (its signature unless given), if it has one built.
MonsterSkill? signatureOf(String type, [MonsterRank rank = MonsterRank.signature]) =>
    MonsterSkill.values.where((s) => s.type == type && s.rank == rank).firstOrNull;

/// Whether monster [u] casts skills at all: from high elite up, never a raised minion (a necromancer's, or one a
/// skill brought in), and not while it is a slime ([Status.hex], Slime Hex).
bool _castsSkills(Unit u) =>
    u.side == Side.enemy && u.raisedBy == null && u.tier.index >= Tier.highElite.index && !u.effects.containsKey(Status.hex);

/// The skill monster [u] casts as its type's signature ([_castsSkills]).
MonsterSkill? monsterSkillOf(Unit u) => _castsSkills(u) ? signatureOf(u.type) : null;

/// Every skill monster [u] casts ([_castsSkills]), the one it would take first first: the boss's moment, the
/// mini boss's (and boss's) skill, its signature.
List<MonsterSkill> monsterSkillsOf(Unit u) {
  if (!_castsSkills(u)) return const [];
  return [
    if (u.tier == Tier.boss) ?signatureOf(u.type, MonsterRank.moment),
    if (u.tier.index >= Tier.miniBoss.index) ?signatureOf(u.type, MonsterRank.miniBoss),
    ?signatureOf(u.type),
  ];
}

extension MonsterSkills on Game {
  /// A mini boss or a boss casts its skills stronger.
  bool _bossRank(Unit u) => u.tier == Tier.miniBoss || u.tier == Tier.boss;

  /// Living troops on the field within [r] of [p], nearest first.
  List<Unit> _troopsNear(Point<double> p, double r) =>
      _alliesNear(p, r)..sort((a, b) => a.pos.distanceTo(p).compareTo(b.pos.distanceTo(p)));

  /// [tick], at spawn: [u]'s first cast is [firstCastAfter] away, by its place in the wave; a mini boss's
  /// other skill's [bossSkillGap] after that. A once-only skill goes by its own rule. Its cooldown is the one
  /// [_skillReady] reads ([Omens._skillCooldown]: a high elite's shorter under the Bayangan Quick Spells), so the
  /// first cast comes when it would either way.
  void _firstCast(Unit u) {
    final first = t + firstCastAfter.from + waveSpawned % firstCastAfter.steps;
    for (final s in monsterSkillsOf(u).where((s) => s.cooldown.isFinite)) {
      if (s.rank == MonsterRank.signature) u.skillAt = first - _skillCooldown(u, s);
      if (s.rank == MonsterRank.miniBoss) u.bossSkillAt = first + bossSkillGap - _skillCooldown(u, s);
    }
  }

  /// [tick]: monster [u]'s turn with its skills. Winding up, it stands still until the cast lands; else it
  /// starts the first of its skills ([monsterSkillsOf]) that may start ([_skillReady], never while the wave
  /// marches) and that it wants ([wantsMonsterSkill]): its title pops, and that skill's cooldown runs from now,
  /// so a cancelled one waits too (the boss's moment is tried again, [bossMomentK]). Whether it did (it does
  /// nothing else this tick).
  bool _monsterSkillTurn(Unit u) {
    if (u.winding case final s?) {
      u.moving = false;
      if (t < u.windUntil) return true;
      u.winding = null;
      if (s.rank == MonsterRank.moment) u.momentDone = true;
      _castMonsterSkill(u, s);
      return true;
    }
    if (marching) return false;
    final s = monsterSkillsOf(u).where((s) => _skillReady(u, s) && wantsMonsterSkill(u, s)).firstOrNull;
    if (s == null) return false;
    u
      ..winding = s
      ..windUntil = t + s.wind
      ..castAt = t
      ..moving = false;
    if (s.rank == MonsterRank.signature) u.skillAt = t;
    if (s.rank == MonsterRank.miniBoss) u.bossSkillAt = t;
    monsterCasts.add((u, s));
    _playStrip(u, monsterSkillStrips[s], u.windUntil); // its skill strip, the blow on the land (skill_strips.dart)
    _emit(MonsterSkillCast(wave, t, type: u.type, tier: u.tier, skill: s));
    return true;
  }

  /// Whether monster [u]'s skill [s] may start (its rule aside): its cooldown over ([Omens._skillCooldown]), and a recurring one
  /// [bossSkillGap] after the monster last began any ([Unit.castAt]); the boss's moment once its HP is down to
  /// [bossMomentK].at, until it lands.
  bool _skillReady(Unit u, MonsterSkill s) => switch (s.rank) {
        MonsterRank.signature => t - u.skillAt >= _skillCooldown(u, s) && t - u.castAt >= bossSkillGap,
        MonsterRank.miniBoss => t - u.bossSkillAt >= _skillCooldown(u, s) && (!s.cooldown.isFinite || t - u.castAt >= bossSkillGap),
        MonsterRank.moment => !u.momentDone && t >= u.momentAt && u.hp <= u.maxHp * bossMomentK.at,
      };

  /// [tick]: [u]'s wind-up is cancelled (a stun, a shove, a march, Slime Hex); the boss's moment winds up again
  /// [bossMomentK].retry s later.
  void _cancelWind(Unit u) {
    if (u.winding?.rank == MonsterRank.moment) u.momentAt = t + bossMomentK.retry;
    u
      ..winding = null
      ..skillAnim = null; // its skill strip stops (skill_strips.dart)
  }

  /// Whether monster [u]'s skill [skill] (its signature, [monsterSkillOf], unless given) would do something
  /// now, by its rule (cooldown aside).
  bool wantsMonsterSkill(Unit u, [MonsterSkill? skill]) {
    switch (skill ?? monsterSkillOf(u)) {
      case null:
        return false;
      case MonsterSkill.warShout:
        return _foesNear(u.pos, warShoutK.reach).where((o) => t - o.attackedAt < warShoutK.fought).length >= warShoutK.crowd;
      case MonsterSkill.volley:
        return _troopsNear(u.pos, u.stats.range).length >= volleyK.crowd;
      case MonsterSkill.shieldUp:
        return t - u.rangedHitAt <= shieldUpK.within && !under(u, Status.shotWard);
      case MonsterSkill.brutalSwing:
        return _troopsNear(u.pos, u.stats.range).length >= brutalSwingK.crowd;
      case MonsterSkill.bulwark:
        return t >= u.guardUntil &&
            (_troopsNear(u.pos, u.stats.range).length >= bulwarkK.crowd ||
                _foesNear(u.pos, bulwarkK.reach).any((o) => o != u && o.hp < o.maxHp * bulwarkK.hurt));
      case MonsterSkill.bladeDance:
        return _troopsNear(u.pos, bladeDanceK.reach).length >= bladeDanceK.crowd;
      case MonsterSkill.massMend:
        return u.mp >= massMendK.cost * necroHealCost &&
            _foesNear(u.pos, massMendK.reach).where((o) => o.hp < o.maxHp * massMendK.hurt && !_healWindowed(o, u)).length >= massMendK.crowd;
      case MonsterSkill.stickyGlob || MonsterSkill.swoop || MonsterSkill.pounce || MonsterSkill.trample:
        return _wantsMoveSkill(u); // monster_skill_moves.dart
      case final s && (MonsterSkill.reassemble || MonsterSkill.maul || MonsterSkill.curseOfFrailty): // branch 2b
        return _wantsSignatureSkill(u, s);
      case final other:
        return _wantsBossSkill(u, other); // a mini-boss skill or a moment (boss_skills.dart)
    }
  }

  /// Who monster [u]'s skill would land on if its wind-up ended now (its tell, docs/ui-hud.md "A monster's
  /// skill"): the troops a single-target skill goes for, Volley's arrows' troops, Unholy Ward's monster, the troop
  /// Grave Wave's line runs at. The landing's own queries, read only and without dice, so drawing it changes
  /// nothing; empty when [u] winds up nothing or its skill picks no one ahead.
  List<Unit> windTargetsOf(Unit u) {
    final s = u.winding;
    if (s == null || !u.alive) return const [];
    Unit? nearest(double r) => _troopsNear(u.pos, r).firstOrNull;
    return switch (s) {
      MonsterSkill.volley => _troopsNear(u.pos, u.stats.range).take(_bossRank(u) ? volleyK.strong : volleyK.arrows).toList(),
      MonsterSkill.stickyGlob => [?_globTarget(u)],
      MonsterSkill.swoop => [?_swoopTarget(u)],
      MonsterSkill.pounce => [?_pounceTarget(u)],
      MonsterSkill.trample => [?_trampleTarget(u)],
      MonsterSkill.maul || MonsterSkill.headbutt || MonsterSkill.barbedArrow || MonsterSkill.boneBash || MonsterSkill.skullCrusher => [
          ?nearest(u.stats.range)
        ],
      MonsterSkill.spearThrow => [?_backLine(u)],
      MonsterSkill.soulDrain => [?_troopsNear(u.pos, soulDrainK.reach).fold<Unit?>(null, (a, b) => a == null || b.hp > a.hp ? b : a)],
      MonsterSkill.unholyWard => [?_wardable(u)],
      MonsterSkill.graveWave => [?nearest(double.infinity)],
      _ => const [],
    };
  }

  /// [u]'s blow of [k]× its damage on troop [o], one of the [hits] its cast strikes [o] with: at most that share
  /// of [monsterSkillCap] of its max HP, so the whole cast stays within the cap. Its type's hit burst shows on [o],
  /// the bigger one for a [big] blow (Brutal Swing's); the flag only changes the look.
  void _skillBlow(Unit u, Unit o, double k, {int hits = 1, bool big = false}) {
    impacts.add((o.pos, big ? 'hit_${u.type}_big' : 'hit_${u.type}'));
    _hurt(o, u.stats.dmg * k, Hit.skill, u, monsterSkillCapOf(o) / hits);
  }

  /// Monster [u]'s skill [s] lands, its wind-up over; a high elite heals under the Bayangan Rekindle (omen.dart).
  void _castMonsterSkill(Unit u, MonsterSkill s) {
    if (omensOn && u.tier == Tier.highElite) _omenRekindle(u);
    final strong = _bossRank(u);
    switch (s) {
      case MonsterSkill.warShout:
        impacts.add((u.pos, 'hit_${u.type}_big')); // its hit burst, bigger
        rings.add(Ring(u.pos, radius: warShoutK.reach, since: t, look: RingLook.red)); // the shout, bursting out
        for (final o in _foesNear(u.pos, warShoutK.reach)) {
          addEffect(o, Status.might, warShoutK.time, k: strong ? warShoutK.strong : warShoutK.might, by: u);
        }
      case MonsterSkill.volley:
        final near = _troopsNear(u.pos, u.stats.range);
        if (near.isEmpty) return;
        u.attackedAt = t;
        _face(u, near.first.pos.x - u.pos.x, 0);
        final arrows = strong ? volleyK.strong : volleyK.arrows, m = near.length;
        impacts.add((u.pos, 'hit_${u.type}')); // the volley loosed: its hit burst at it
        for (final o in near.take(arrows)) {
          rings.add(Ring.over(o, radius: landingLook.mark, since: t, look: RingLook.red)); // a red ring under each troop it aims at
        }
        for (var i = 0; i < arrows; i++) {
          // The troop's arrows this cast (the nearest get one more when they don't share out) share its cap.
          final o = near[i % m], on = arrows ~/ m + (i % m < arrows % m ? 1 : 0);
          shots.add(Shot(u, o, u.pos, Hit.skill, min(u.stats.dmg * volleyK.hit, o.maxHp * monsterSkillCapOf(o) / on)));
        }
        sfx.add(Sfx.hit);
      case MonsterSkill.shieldUp:
        for (final o in [u, if (strong) ..._foesNear(u.pos, shieldUpK.behind).where((o) => o != u && o.pos.x >= u.pos.x)]) {
          addEffect(o, Status.shotWard, shieldUpK.time, k: shieldUpK.ward, by: u);
          rings
            ..removeWhere((r) => r.follow == o && r.look == RingLook.ward)
            ..add(Ring.over(o, radius: tile / 2, since: t, look: RingLook.ward, duration: shieldUpK.time)); // its shield
        }
      case MonsterSkill.brutalSwing:
        u.attackedAt = t;
        rings.add(Ring.over(u, radius: u.stats.range, since: t, look: RingLook.cleave, duration: landingLook.cleave)); // the swing
        for (final o in _troopsNear(u.pos, u.stats.range)) {
          _skillBlow(u, o, strong ? brutalSwingK.strong : brutalSwingK.hit, big: true);
        }
        sfx.add(Sfx.hit);
      case MonsterSkill.bulwark:
        impacts.add((u.pos, 'hit_${u.type}_big')); // its hit burst, bigger
        rings.add(Ring(u.pos, radius: bulwarkK.reach, since: t, look: RingLook.orange)); // in the taunt's orange, out to its reach
        for (final o in _troopsNear(u.pos, bulwarkK.reach).where((o) => o.stats.melee)) {
          addEffect(o, Status.taunt, bulwarkK.time, by: u, bad: true);
        }
        u
          ..guardUntil = t + bulwarkK.time
          ..guardCut = bulwarkK.cut
          ..guardLook = RingLook.orange // its guard ring in the taunt's orange
          ..guardOmen = false; // a monster skill's guard, after the taken floor
        if (strong) addEffect(u, Status.reflect, bulwarkK.time, k: bulwarkK.reflect);
      case MonsterSkill.bladeDance:
        final cuts = strong ? bladeDanceK.strong : bladeDanceK.cuts;
        u.cd = max(u.cd, cuts * bladeDanceK.gap); // its own attacks wait while it spins
        void cut() {
          if (!u.alive || t < u.stunUntil || u.move != null) return; // a stunned or shoved one stops spinning
          u.attackedAt = t; // the attack strip again, each cut
          rings.add(Ring.over(u, radius: bladeDanceK.reach, since: t, look: RingLook.spin, duration: landingLook.spin)); // a spin
          for (final o in _troopsNear(u.pos, bladeDanceK.reach)) {
            _skillBlow(u, o, bladeDanceK.hit, hits: cuts); // the cuts share the cast's cap
          }
          sfx.add(Sfx.hit);
        }

        cut();
        for (var i = 1; i < cuts; i++) {
          later(i * bladeDanceK.gap, cut);
        }
      case MonsterSkill.massMend:
        u
          ..mp -= massMendK.cost * necroHealCost
          ..attackedAt = t
          ..swung = false;
        final heal = u.stats.dmg * (strong ? massMendK.strong : massMendK.heal);
        for (final o in _foesNear(u.pos, massMendK.reach).where((o) => o.hp < o.maxHp && !_healWindowed(o, u))) {
          _healMonster(o, heal, MonsterHeal.massMend);
          _openHealWindow(u, o);
          impacts.add((o.pos, _fxOf(u, 'heal')));
        }
        sfx.add(Sfx.magic);
      case MonsterSkill.stickyGlob || MonsterSkill.swoop || MonsterSkill.pounce || MonsterSkill.trample:
        _castMoveSkill(u, s); // monster_skill_moves.dart
      case MonsterSkill.reassemble || MonsterSkill.maul || MonsterSkill.curseOfFrailty: // branch 2b
        _castSignatureSkill(u, s);
      default:
        _castBossSkill(u, s); // a mini-boss skill or a moment (boss_skills.dart)
    }
  }
}
