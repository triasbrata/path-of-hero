part of 'game.dart';

// The mini bosses' and the boss's own skills (#59 branch 3; docs/units-and-combat.md, "Monster skills"; the
// design in reports/monster-skills-design.md §3). A mini boss casts its type's signature stronger
// (monster_skills.dart) and its type's mini-boss skill too, a recurring one at least [bossSkillGap] after the
// other; a boss casts both, and its moment: once, when its HP first drops to half ([bossMomentK]). They wind up,
// pop and are cancelled like any monster skill ([MonsterSkills._monsterSkillTurn]); a cancelled moment winds up
// again a little later, so it always comes. The monsters a skill brings in (Split, Swarm, Grave Call) are raised
// minions like a necromancer's ([BossSkills._bringIn]): no gold, no score, no skills, and the stall watchdog
// doesn't count them.

/// A mini boss's two recurring skills: after one starts, the other waits at least this long (s).
const bossSkillGap = 3.0;

/// The boss's moment: once, when its HP is down to [bossMomentK].at of its max; a wind-up cancelled (a stun) is
/// tried again [bossMomentK].retry s later.
const bossMomentK = (at: 0.5, retry: 1.5);

/// How long a wide ring (3 tiles) takes to burst out and fade (s); a narrower one takes [ringTime].
const wideRingTime = 0.8;

/// The skeleton kinds (Grave Call raises them) and the orc kinds (Rally drives them).
const skeletonKinds = {'skeleton', 'skeleton_archer', 'armored_skeleton', 'greatsword_skeleton'};
const orcKinds = {'orc', 'orc_rider', 'elite_orc', 'armored_orc'};

/// Split (slime): as it dies it bursts into [splitK].slimes slimes of its wave (normal), [splitK].spread round
/// where it fell.
const splitK = (slimes: 3, spread: 10.0);

/// Screech (bat): with [screechK].crowd+ troops within [screechK].reach, their attacks come [screechK].pause× as
/// far apart (20% fewer) for [screechK].time s ([Status.daze]).
const screechK = (crowd: 3, reach: 2 * tile, pause: 1.25, time: 4.0);

/// Bone Shield (skeleton): the most hurt undead monster ([Stats.dark]) within [boneShieldK].reach below
/// [boneShieldK].hurt of its HP (itself too) takes [boneShieldK].cut less for [boneShieldK].time s.
const boneShieldK = (reach: 2 * tile, hurt: 0.5, cut: 0.4, time: 4.0);

/// Headbutt (orc): the nearest troop in reach takes [headbuttK].hit× its damage and a stun of [headbuttK].stun s
/// ([HeroMoves.stunTroop]: a Hero's half as long, then 4 s it can't be stunned again).
const headbuttK = (hit: 1.2, stun: 0.5);

/// Barbed Arrow (skeleton archer): at the nearest troop in range, an arrow of [barbedArrowK].hit× its damage;
/// the troop then bleeds [barbedArrowK].bleed× its damage every second, [barbedArrowK].time times. Arrow and
/// bleed are one cast under one cap ([CastBlows]): the bleed gets what the arrow left of it, and none when that
/// is less than [minHit] a tick.
const barbedArrowK = (hit: 1.0, bleed: 0.5, time: 4);

/// Frenzy (werewolf): once, when its HP drops below [frenzyK].below, its attacks come [frenzyK].pause× as far
/// apart (40% faster) for [frenzyK].time s, never under the attack floor ([minAttackInterval]).
const frenzyK = (below: 0.5, pause: 1 / 1.4, time: 6.0);

/// Bone Bash (armored skeleton): the nearest troop in reach takes [boneBashK].hit× its damage and is knocked
/// [boneBashK].shove back towards the base ([HeroMoves.knockBack]: a Hero half as far).
const boneBashK = (hit: 1.0, shove: tile);

/// Spear Throw (orc rider): at the nearest back-line troop (long range or a healer) within [spearThrowK].reach, a
/// spear of [spearThrowK].hit× its damage, flying at [spearThrowK].speed.
const spearThrowK = (reach: 5 * tile, hit: 1.5, speed: 220.0);

/// Bloodrage (elite orc): below [bloodrageK].below of its HP with a troop in reach, it heals [bloodrageK].share
/// of what it deals for [bloodrageK].time s ([Status.lifesteal]).
const bloodrageK = (below: 0.6, share: 0.3, time: 6.0);

/// Ground Slam (armored orc): with [groundSlamK].crowd+ troops within [groundSlamK].reach, [groundSlamK].hit× its
/// damage to each.
const groundSlamK = (crowd: 3, reach: 1.5 * tile, hit: 1.0);

/// Soul Rend (greatsword skeleton): with a troop in reach that has [soulRendK].mp MP to take, for
/// [soulRendK].time s each of its blows on a troop takes [soulRendK].mp MP too ([Status.soulRend]).
const soulRendK = (mp: 5.0, time: 6.0);

/// Thick Hide (werebear): once, when its HP drops below [thickHideK].below, it takes [thickHideK].cut less for
/// [thickHideK].time s.
const thickHideK = (below: 0.5, cut: 0.3, time: 6.0);

/// Soul Drain (necromancer): with a troop within [soulDrainK].reach, a beam to the one with the most HP there for
/// [soulDrainK].time s ([BeamLook.drain]): [soulDrainK].ticks drains of [soulDrainK].hit× its damage, a second apart,
/// each healing it [soulDrainK].heal of what it took. Either falling, or a stun or a shove on it, ends it.
const soulDrainK = (reach: 4 * tile, time: 3.0, ticks: 3, hit: 0.6, heal: 0.5);

/// Unholy Ward (healing necromancer): the most hurt monster in its range that was hit twice in the last
/// [unholyWardK].within s soaks [unholyWardK].soak× its heal for [unholyWardK].time s ([Status.absorb]).
const unholyWardK = (within: 2.0, soak: 2.0, time: 6.0);

/// Slime Tide (slime boss's moment): a slime puddle [slimeTideK].radius round where it stands (3 tiles across) for
/// [slimeTideK].time s: troops in it walk [slimeTideK].slow× as fast (40% slower), [slimeTideK].linger s after
/// they step out.
const slimeTideK = (radius: 1.5 * tile, time: 6.0, slow: 0.6, linger: 0.25);

/// Swarm (bat boss's moment): [swarmK].bats bats of its wave (normal) come in round it, [swarmK].spread away.
const swarmK = (bats: 4, spread: 14.0);

/// Grave Call (skeleton boss's moment): up to [graveCallK].most skeleton-kind monsters that fell this wave within
/// [graveCallK].reach of it ([Game.graves], nearest first) stand again, at [graveCallK].hp of their HP.
const graveCallK = (reach: 4 * tile, most: 4, hp: 0.25);

/// Rally (orc boss's moment): every orc-kind monster on the field ([orcKinds]) deals [rallyK].might× and attacks
/// [rallyK].pause× as far apart (20% faster) for [rallyK].time s.
const rallyK = (might: 1.25, pause: 1 / 1.2, time: 8.0);

/// Bone Rain (skeleton archer boss's moment): arrows fall for [boneRainK].time s round the troop in its range with
/// the most troops within [boneRainK].radius of it (2 tiles across): [boneRainK].hit× its damage to each troop there
/// every second.
const boneRainK = (radius: tile, time: 4.0, hit: 0.5);

/// Howl (werewolf boss's moment): every monster within [howlK].reach (itself too) walks [howlK].walk× as fast
/// ([Status.swift]) and attacks [howlK].pause× as far apart for [howlK].time s.
const howlK = (reach: 3 * tile, walk: 1.25, pause: 1 / 1.2, time: 6.0);

/// Iron March (armored skeleton boss's moment): for [ironMarchK].time s nothing slows it ([Status.steadfast]; a
/// boss is never stunned or shoved anyway) and it walks [ironMarchK].walk× as fast, in its steel ring.
const ironMarchK = (time: 8.0, walk: 1.3);

/// Second Wind (orc rider boss's moment): [secondWindK].heal of its max HP back, and it walks [secondWindK].walk×
/// as fast and attacks [secondWindK].pause× as far apart for [secondWindK].time s.
const secondWindK = (heal: 0.25, walk: 1.2, pause: 1 / 1.2, time: 6.0);

/// Skull Crusher (elite orc boss's moment): with a troop in reach, the nearest takes [skullCrusherK].hit× its
/// damage (the cap still holds) and a stun of [skullCrusherK].stun s.
const skullCrusherK = (hit: 3.0, stun: 0.8);

/// Earthshaker (armored orc boss's moment): [earthshakerK].hit× its damage to every troop within
/// [earthshakerK].reach, and a stun of [earthshakerK].stun s.
const earthshakerK = (reach: 3 * tile, hit: 1.2, stun: 0.5);

/// Grave Wave (greatsword skeleton boss's moment): a sword wave out from it towards the nearest troop (none:
/// straight at the base), [graveWaveK].length long at [graveWaveK].speed, [graveWaveK].hit× its damage to each
/// troop on its line ([LineShot]).
const graveWaveK = (length: 5 * tile, speed: 200.0, hit: 2.0);

/// Roar (werebear boss's moment): the troops within [roarK].reach deal [roarK].dealt× for [roarK].time s
/// ([Status.weaken]).
const roarK = (reach: 3 * tile, dealt: 0.75, time: 5.0);

/// Death Nova (necromancer boss's moment): [deathNovaK].hit× its damage to every troop within [deathNovaK].reach.
const deathNovaK = (reach: 2.5 * tile, hit: 1.5);

/// Last Rites (healing necromancer boss's moment): every monster within [lastRitesK].reach (itself too) gets
/// [lastRitesK].heal of its max HP back.
const lastRitesK = (reach: 3 * tile, heal: 0.2);

/// One cast's blows on each troop: the cap ([monsterSkillCapOf]) is per cast per troop, so a skill that lands
/// on a troop more than once (Barbed Arrow's arrow and bleed, Soul Drain's drains, Bone Rain's arrows) shares it
/// ([BossSkills._castBlow]).
class CastBlows {
  final _taken = <Unit, double>{};

  /// What this cast may still take from troop [o] (HP).
  double left(Unit o) => max(0.0, o.maxHp * monsterSkillCapOf(o) - (_taken[o] ?? 0));

  /// This cast took [hp] from troop [o] (or set that much of its cap aside for a blow worked out ahead).
  void add(Unit o, double hp) => _taken[o] = (_taken[o] ?? 0) + hp;
}

extension BossSkills on Game {
  /// [wantsMonsterSkill] for a mini-boss skill or a moment (a moment's HP rule is [_skillReady]'s).
  bool _wantsBossSkill(Unit u, MonsterSkill s) {
    switch (s) {
      case MonsterSkill.screech:
        return _troopsNear(u.pos, screechK.reach).length >= screechK.crowd;
      case MonsterSkill.boneShield:
        return _shieldable(u) != null;
      case MonsterSkill.headbutt || MonsterSkill.boneBash || MonsterSkill.skullCrusher:
        return _troopsNear(u.pos, u.stats.range).isNotEmpty;
      case MonsterSkill.barbedArrow:
        return _troopsNear(u.pos, u.stats.range).isNotEmpty;
      case MonsterSkill.frenzy:
        return u.hp < u.maxHp * frenzyK.below;
      case MonsterSkill.spearThrow:
        return _backLine(u) != null;
      case MonsterSkill.bloodrage:
        return u.hp < u.maxHp * bloodrageK.below && !under(u, Status.lifesteal) && _troopsNear(u.pos, u.stats.range).isNotEmpty;
      case MonsterSkill.groundSlam:
        return _troopsNear(u.pos, groundSlamK.reach).length >= groundSlamK.crowd;
      case MonsterSkill.soulRend:
        return !under(u, Status.soulRend) && _troopsNear(u.pos, u.stats.range).any((o) => o.mp >= soulRendK.mp);
      case MonsterSkill.thickHide:
        return u.hp < u.maxHp * thickHideK.below;
      case MonsterSkill.soulDrain:
        return _troopsNear(u.pos, soulDrainK.reach).isNotEmpty;
      case MonsterSkill.unholyWard:
        return _wardable(u) != null;
      default:
        return s.rank == MonsterRank.moment; // Split comes as it dies ([_monsterFell])
    }
  }

  /// A mini-boss skill or a moment [s] of monster [u] lands, its wind-up over.
  void _castBossSkill(Unit u, MonsterSkill s) {
    switch (s) {
      case MonsterSkill.screech:
        for (final o in _troopsNear(u.pos, screechK.reach)) {
          addEffect(o, Status.daze, screechK.time, k: screechK.pause, by: u, bad: true);
        }
        rings.add(Ring(u.pos, radius: screechK.reach, since: t, look: RingLook.pale));
        sfx.add(Sfx.magic);
      case MonsterSkill.boneShield:
        final o = _shieldable(u);
        if (o == null) return;
        _guard(o, boneShieldK.cut, boneShieldK.time);
        o.guardLook = RingLook.bone;
      case MonsterSkill.headbutt:
        final o = _strikeNearest(u, headbuttK.hit);
        if (o != null && o.alive) stunTroop(o, headbuttK.stun);
      case MonsterSkill.boneBash:
        final o = _strikeNearest(u, boneBashK.hit);
        if (o != null && o.alive) knockBack(o, boneBashK.shove);
      case MonsterSkill.barbedArrow:
        final o = _troopsNear(u.pos, u.stats.range).firstOrNull;
        if (o == null) return;
        // The arrow and the bleed share the cap: the arrow's damage is set aside first, the bleed gets what is left
        // (Pounce's rule, decision 109), in ticks of at least a blow's least ([minHit]; [hitTaken] takes no more).
        final cast = CastBlows();
        cast.add(o, _throw(u, o, barbedArrowK.hit, u.stats.shotSpeed, onHit: (h) {
          final k = min(u.stats.dmg * barbedArrowK.bleed, cast.left(h) / barbedArrowK.time);
          if (h.alive && k >= minHit) addEffect(h, Status.bleed, barbedArrowK.time + 0.5, k: k, by: u, n: barbedArrowK.time, bad: true);
        }));
      case MonsterSkill.frenzy:
        addEffect(u, Status.haste, frenzyK.time, k: frenzyK.pause);
        impacts.add((u.pos, 'upgrade'));
      case MonsterSkill.spearThrow:
        final o = _backLine(u);
        if (o == null) return;
        _throw(u, o, spearThrowK.hit, spearThrowK.speed, look: ShotLook.spear);
      case MonsterSkill.bloodrage:
        addEffect(u, Status.lifesteal, bloodrageK.time, k: bloodrageK.share);
      case MonsterSkill.groundSlam:
        u.attackedAt = t;
        impacts.add((u.pos, 'hit_${u.type}_big'));
        rings.add(Ring(u.pos, radius: groundSlamK.reach, since: t, look: RingLook.dust));
        for (final o in _troopsNear(u.pos, groundSlamK.reach)) {
          _skillBlow(u, o, groundSlamK.hit);
        }
        sfx.add(Sfx.hit);
      case MonsterSkill.soulRend:
        addEffect(u, Status.soulRend, soulRendK.time, k: soulRendK.mp);
      case MonsterSkill.thickHide:
        _guard(u, thickHideK.cut, thickHideK.time);
        u.guardLook = RingLook.brown;
      case MonsterSkill.soulDrain:
        final o = _troopsNear(u.pos, soulDrainK.reach).fold<Unit?>(null, (a, b) => a == null || b.hp > a.hp ? b : a);
        if (o == null) return;
        _drain(u, o);
      case MonsterSkill.unholyWard:
        final o = _wardable(u);
        if (o == null) return;
        u
          ..attackedAt = t
          ..swung = false;
        addEffect(o, Status.absorb, unholyWardK.time, k: _healOf(u) * unholyWardK.soak);
        impacts.add((o.pos, _fxOf(u, 'heal')));
        sfx.add(Sfx.magic);
      case MonsterSkill.slimeTide:
        zones.add(Zone(u, u.pos, since: t, duration: slimeTideK.time, radius: slimeTideK.radius, side: Side.troop, look: ZoneLook.slime,
            inside: (o) => addEffect(o, Status.slow, slimeTideK.linger, k: slimeTideK.slow, by: u, bad: true)));
        sfx.add(Sfx.magic);
      case MonsterSkill.swarm:
        for (var i = 0; i < swarmK.bats; i++) {
          final a = pi / 4 + 2 * pi * i / swarmK.bats;
          _bringIn(u, 'bat', Tier.normal, u.pos + Point(cos(a), sin(a)) * swarmK.spread);
        }
        sfx.add(Sfx.magic);
      case MonsterSkill.graveCall:
        final near = graves.where((o) => o.pos.distanceTo(u.pos) <= graveCallK.reach).toList()
          ..sort((a, b) => a.pos.distanceTo(u.pos).compareTo(b.pos.distanceTo(u.pos)));
        for (final o in near.take(graveCallK.most)) {
          graves.remove(o);
          o.gone = true; // its body goes as it stands again
          final m = _bringIn(u, o.type, o.tier, o.pos);
          m.hp = m.maxHp * graveCallK.hp;
        }
        sfx.add(Sfx.magic);
      case MonsterSkill.rally:
        for (final o in enemies.where((o) => o.alive && o.entered && orcKinds.contains(o.type))) {
          addEffect(o, Status.might, rallyK.time, k: rallyK.might, by: u);
          addEffect(o, Status.haste, rallyK.time, k: rallyK.pause, by: u);
          rings.add(Ring(o.pos, radius: tile, since: t, look: RingLook.red));
        }
        impacts.add((u.pos, 'hit_${u.type}_big'));
      case MonsterSkill.boneRain:
        final near = _troopsNear(u.pos, u.stats.range);
        if (near.isEmpty) return;
        final at = near.fold(near.first, (a, b) => _troopsNear(b.pos, boneRainK.radius).length > _troopsNear(a.pos, boneRainK.radius).length ? b : a);
        final cast = CastBlows();
        u.attackedAt = t;
        _face(u, at.pos.x - u.pos.x, 0);
        zones.add(Zone(u, at.pos, since: t, duration: boneRainK.time, radius: boneRainK.radius, side: Side.troop, look: ZoneLook.arrowRain,
            pulse: (o) => _castBlow(u, o, boneRainK.hit, cast)));
        sfx.add(Sfx.dagger);
      case MonsterSkill.howl:
        for (final o in _foesNear(u.pos, howlK.reach)) {
          addEffect(o, Status.swift, howlK.time, k: howlK.walk, by: u);
          addEffect(o, Status.haste, howlK.time, k: howlK.pause, by: u);
        }
        rings.add(Ring(u.pos, radius: howlK.reach, since: t, look: RingLook.grey, duration: wideRingTime));
      case MonsterSkill.ironMarch:
        addEffect(u, Status.steadfast, ironMarchK.time);
        addEffect(u, Status.swift, ironMarchK.time, k: ironMarchK.walk);
        _guard(u, 0, ironMarchK.time);
        u.guardLook = RingLook.steel;
      case MonsterSkill.secondWind:
        _healMonster(u, u.maxHp * secondWindK.heal, MonsterHeal.secondWind);
        addEffect(u, Status.swift, secondWindK.time, k: secondWindK.walk);
        addEffect(u, Status.haste, secondWindK.time, k: secondWindK.pause);
        impacts.add((u.pos, 'heal'));
        sfx.add(Sfx.magic);
      case MonsterSkill.skullCrusher:
        final o = _strikeNearest(u, skullCrusherK.hit);
        if (o != null && o.alive) stunTroop(o, skullCrusherK.stun);
      case MonsterSkill.earthshaker:
        u.attackedAt = t;
        impacts.add((u.pos, 'hit_${u.type}_big'));
        rings.add(Ring(u.pos, radius: earthshakerK.reach, since: t, look: RingLook.brown, duration: wideRingTime));
        for (final o in _troopsNear(u.pos, earthshakerK.reach)) {
          _skillBlow(u, o, earthshakerK.hit);
          if (o.alive) stunTroop(o, earthshakerK.stun);
        }
        sfx.add(Sfx.hit);
      case MonsterSkill.graveWave:
        final to = _troopsNear(u.pos, double.infinity).firstOrNull?.pos ?? Point(baseX, u.pos.y);
        u.attackedAt = t;
        _face(u, to.x - u.pos.x, 0);
        lineShots.add(LineShot(u, u.pos, to,
            dmg: u.stats.dmg * graveWaveK.hit, speed: graveWaveK.speed, length: graveWaveK.length, look: ShotLook.long));
        sfx.add(Sfx.sword);
      case MonsterSkill.roar:
        for (final o in _troopsNear(u.pos, roarK.reach)) {
          addEffect(o, Status.weaken, roarK.time, k: roarK.dealt, by: u, bad: true);
        }
        rings.add(Ring(u.pos, radius: roarK.reach, since: t, look: RingLook.dark, duration: wideRingTime));
      case MonsterSkill.deathNova:
        u.attackedAt = t;
        impacts.add((u.pos, 'hit_${u.type}_big'));
        rings.add(Ring(u.pos, radius: deathNovaK.reach, since: t, look: RingLook.dark));
        for (final o in _troopsNear(u.pos, deathNovaK.reach)) {
          _skillBlow(u, o, deathNovaK.hit);
        }
        sfx.add(Sfx.magic);
      case MonsterSkill.lastRites:
        for (final o in _foesNear(u.pos, lastRitesK.reach)) {
          _healMonster(o, o.maxHp * lastRitesK.heal, MonsterHeal.lastRites);
          impacts.add((o.pos, _fxOf(u, 'heal')));
        }
        sfx.add(Sfx.magic);
      default:
        return; // a signature is monster_skills.dart's; Split comes as it dies ([_monsterFell])
    }
  }

  /// [_hurt]: monster [u] just fell. A skeleton kind of the wave's own leaves a grave ([graves]); a slime mini
  /// boss or boss splits ([splitK]; not while its wave marches): the title pops over the first newcomer.
  void _monsterFell(Unit u) {
    if (skeletonKinds.contains(u.type) && u.raisedBy == null) graves.add(u);
    if (!monsterSkills || marching || !monsterSkillsOf(u).contains(MonsterSkill.split)) return;
    final slimes = [
      for (var i = 0; i < splitK.slimes; i++)
        _bringIn(u, 'slime', Tier.normal, u.pos + Point(cos(2 * pi * i / splitK.slimes), sin(2 * pi * i / splitK.slimes)) * splitK.spread),
    ];
    monsterCasts.add((slimes.first, MonsterSkill.split));
    _emit(MonsterSkillCast(wave, t, type: u.type, tier: u.tier, skill: MonsterSkill.split));
  }

  /// A monster of [type] and [tier] that a skill of [by] brings in at [at], rising for [riseTime]: a raised
  /// minion like a necromancer's ([Unit.raisedBy], [Game._summon]), so it pays no gold, scores nothing, casts
  /// nothing, and the stall watchdog doesn't count it.
  Unit _bringIn(Unit by, String type, Tier tier, Point<double> at) {
    final m = Unit(Side.enemy, type, spawnStats(type, tier, raised: true)._with(cost: 0), Point(at.x, at.y.clamp(4.0, fieldH - 2)))
      ..tier = tier
      ..raisedBy = by
      ..dir = by.dir
      ..busyFrom = t
      ..busyUntil = t + riseTime;
    raised.add(m);
    _omenSpawn(m);
    impacts.add((m.pos, tier == Tier.normal ? 'summon' : 'summon_${tier.name}'));
    return m;
  }

  /// Monster [u] strikes the nearest troop in its reach for [hit]× its damage ([_skillBlow]), its hit burst big;
  /// which, if any.
  Unit? _strikeNearest(Unit u, double hit) {
    final o = _troopsNear(u.pos, u.stats.range).firstOrNull;
    if (o == null) return null;
    u.attackedAt = t;
    _face(u, o.pos.x - u.pos.x, 0);
    impacts.add((o.pos, 'hit_${u.type}_big'));
    _skillBlow(u, o, hit);
    sfx.add(Sfx.hit);
    return o;
  }

  /// Soul Drain: a beam from [u] to troop [o] ([soulDrainK]) and its drains, half a second, a second and a half and
  /// so on from now; it ends when either falls, or [u] is stunned or shoved.
  void _drain(Unit u, Unit o) {
    final beam = Beam.between([u, o], since: t, duration: soulDrainK.time, look: BeamLook.drain), cast = CastBlows();
    beams.add(beam);
    sfx.add(Sfx.magic);
    for (var i = 0; i < soulDrainK.ticks; i++) {
      later((i + 0.5) * soulDrainK.time / soulDrainK.ticks, () {
        if (!beams.contains(beam)) return;
        if (!u.alive || !o.alive || t < u.stunUntil || u.move != null) {
          beams.remove(beam);
          return;
        }
        final before = o.hp;
        _castBlow(u, o, soulDrainK.hit, cast);
        _healMonster(u, (before - max(0.0, o.hp)) * soulDrainK.heal, MonsterHeal.drain);
      });
    }
  }

  /// [u]'s blow of [k]× its damage on troop [o], one of [cast]'s: all of them on [o] together take at most its cap
  /// ([CastBlows]). Nothing once that is used up.
  void _castBlow(Unit u, Unit o, double k, CastBlows cast) {
    final left = cast.left(o);
    if (left <= 0 || !o.alive) return;
    impacts.add((o.pos, 'hit_${u.type}'));
    final hp = o.hp;
    _hurt(o, u.stats.dmg * k, Hit.skill, u, left / o.maxHp);
    cast.add(o, hp - o.hp);
  }

  /// Monster [u] throws or shoots at troop [o]: [hit]× its damage (at most [monsterSkillCapOf] of its max HP) at
  /// [speed], drawn as [look], then [onHit]. The damage it carries.
  double _throw(Unit u, Unit o, double hit, double speed, {ShotLook look = ShotLook.plain, void Function(Unit)? onHit}) {
    final dmg = min(u.stats.dmg * hit, o.maxHp * monsterSkillCapOf(o));
    u.attackedAt = t;
    _face(u, o.pos.x - u.pos.x, 0);
    shots.add(Shot.special(u, o, u.pos, dmg: dmg, speed: speed, look: look, onHit: onHit));
    sfx.add(Sfx.hit);
    return dmg;
  }

  /// Bone Shield's monster: the most hurt undead one within [boneShieldK].reach of [u] below [boneShieldK].hurt of
  /// its HP (itself too) that no guard as strong covers yet.
  Unit? _shieldable(Unit u) => _leastHp(_foesNear(u.pos, boneShieldK.reach)
      .where((o) => o.stats.dark && o.hp < o.maxHp * boneShieldK.hurt && !(t < o.guardUntil && o.guardCut >= boneShieldK.cut)));

  /// Unholy Ward's monster: the most hurt one in [u]'s range hit twice in the last [unholyWardK].within s, with no
  /// soak on it yet but a Bayangan's ([Effect.omen]: the ward still lands on it when it is the stronger, [addEffect]).
  Unit? _wardable(Unit u) => _leastHp(_foesNear(u.pos, u.stats.range)
      .where((o) => t - o.hurtBefore <= unholyWardK.within && (effectOn(o, Status.absorb)?.omen ?? true)));

  /// The one of [units] with the least of its HP left, as a share.
  Unit? _leastHp(Iterable<Unit> units) => units.isEmpty ? null : units.reduce((a, b) => b.hp / b.maxHp < a.hp / a.maxHp ? b : a);

  /// Spear Throw's troop: the nearest back-line troop (long range or a healer) within [spearThrowK].reach of [u].
  Unit? _backLine(Unit u) => _troopsNear(u.pos, spearThrowK.reach).where((o) => o.stats.shotSpeed > 0 || o.stats.heals).firstOrNull;
}
