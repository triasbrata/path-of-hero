part of 'game.dart';

// #59 branch 2a (docs/units-and-combat.md, "Monster skills"): the four signature skills that ride the forced
// movement and the looks of hero_moves.dart / hero_shots.dart, monster on troop. A slime spits a glob that slows
// a back-line troop (Sticky Glob), a bat leaps over the front to bite one (Swoop), a werewolf leaps onto a hurt
// troop and leaves it bleeding (Pounce), an orc rider gallops through the troops ahead of it (Trample). A mini
// boss or a boss of the type casts each stronger. Like every monster skill they wind up first (a stun, a shove
// or a march cancels them; monster_skills.dart), and no blow of theirs takes more than [monsterSkillCap].
//
// monster_skills.dart sends these four here from one arm in each of its switches.

/// Sticky Glob (slime): at the nearest back-line troop (a healer or a long-range one) within [reach], a glob
/// flies at [speed]: [hit]× its damage, and for [time] s the troop walks at [slow]× its speed and attacks with
/// its pause ×1/[slow] ([Status.slow], [Status.haste]). A mini boss's or a boss's: [strongSlow] for
/// [strongTime] s.
const stickyGlobK = (reach: 4 * tile, speed: 120.0, hit: 0.8, slow: 0.7, time: 3.0, strongSlow: 0.6, strongTime: 4.0);

/// Swoop (bat): at the nearest back-line troop within [reach] and out of its own reach, it leaps over the front
/// to land beside it and bites [hit]× its damage (a mini boss's or a boss's: [strongHit]×), healing [heal] of
/// what the bite took.
const swoopK = (reach: 5 * tile, hit: 1.5, strongHit: 2.0, heal: 0.5);

/// Pounce (werewolf): at the troop within [reach] with the least of its HP left, below [below] of it (a Hero
/// below [heroBelow]), it leaps to land beside it and bites [hit]× its damage (a mini boss's or a boss's:
/// [strongHit]×); the troop then bleeds [bleed]× its damage every second, [time] times. Bite and bleed are one
/// cast under one cap ([monsterSkillCapOf]): the bleed gets what the bite left of it, and none when that is
/// less than [minHit] a tick.
const pounceK = (reach: 4 * tile, below: 0.5, heroBelow: 0.25, hit: 1.5, strongHit: 2.0, bleed: 0.3, time: 4);

/// Trample (orc rider): with a troop [near]–[far] ahead of it (towards the base), it gallops at [speed]× its
/// speed at the nearest back-line troop that far ahead (else the farthest troop there), through every troop
/// within [lane] of its way: [hit]× its damage to each (a mini boss's or a boss's: [strongHit]×, and a stun of
/// [strongStun] s), each shoved [shove] aside. It stops with its target in reach and fights on there.
const trampleK = (near: 2 * tile, far: 5 * tile, speed: 2.0, lane: 8.0, hit: 1.0, strongHit: 1.5, shove: tile / 2, strongStun: 0.5);

extension MonsterSkillMoves on Game {
  /// [MonsterSkills.wantsMonsterSkill] for the four here: whether monster [u]'s skill has a target now.
  bool _wantsMoveSkill(Unit u) => switch (monsterSkillOf(u)) {
        MonsterSkill.stickyGlob => _globTarget(u) != null,
        MonsterSkill.swoop => _swoopTarget(u) != null,
        MonsterSkill.pounce => _pounceTarget(u) != null,
        MonsterSkill.trample => _trampleTarget(u) != null,
        _ => false,
      };

  /// [MonsterSkills._castMonsterSkill] for the four here: monster [u]'s skill [s] lands, its wind-up over, at
  /// the target it has now (none left: nothing happens).
  void _castMoveSkill(Unit u, MonsterSkill s) {
    final strong = _bossRank(u);
    switch (s) {
      case MonsterSkill.stickyGlob:
        final o = _globTarget(u);
        if (o == null) return;
        final slow = strong ? stickyGlobK.strongSlow : stickyGlobK.slow, time = strong ? stickyGlobK.strongTime : stickyGlobK.time;
        u.attackedAt = t; // the spit: its attack strip
        _face(u, o.pos.x - u.pos.x, 0);
        shots.add(Shot.special(u, o, u.pos, dmg: min(u.stats.dmg * stickyGlobK.hit, o.maxHp * monsterSkillCapOf(o)), speed: stickyGlobK.speed,
            look: ShotLook.glob, onHit: (hit) {
          addEffect(hit, Status.slow, time, k: slow, by: u, bad: true);
          addEffect(hit, Status.haste, time, k: 1 / slow, by: u, bad: true);
        }));
        sfx.add(Sfx.hit);
      case MonsterSkill.swoop:
        final o = _swoopTarget(u);
        if (o == null) return;
        leap(u, beside(o, u.pos, besideGap), () => _bite(u, o, strong ? swoopK.strongHit : swoopK.hit, heal: swoopK.heal));
      case MonsterSkill.pounce:
        final o = _pounceTarget(u);
        if (o == null) return;
        leap(u, beside(o, u.pos, besideGap), () {
          final before = o.hp;
          if (!_bite(u, o, strong ? pounceK.strongHit : pounceK.hit) || !o.alive) return;
          // One cast, one cap: the bleed shares what the bite left of it, in ticks of at least a blow's least
          // ([minHit]; [hitTaken] takes no more than that).
          final k = min(u.stats.dmg * pounceK.bleed, (o.maxHp * monsterSkillCapOf(o) - (before - o.hp)) / pounceK.time);
          if (k >= minHit) addEffect(o, Status.bleed, pounceK.time + 0.5, k: k, by: u, n: pounceK.time, bad: true);
        });
      case MonsterSkill.trample:
        final o = _trampleTarget(u);
        if (o == null) return;
        final hit = strong ? trampleK.strongHit : trampleK.hit;
        charge(u, o, speed: trampleK.speed, lane: trampleK.lane, hit: 0, shove: trampleK.shove, onPass: (p) {
          _hurt(p, u.stats.dmg * hit, Hit.skill, u, monsterSkillCapOf(p)); // the charge shows the hooves' dust on it
          if (strong && p.alive) stunTroop(p, trampleK.strongStun);
        });
        sfx.add(Sfx.hit);
      default:
        break;
    }
  }

  /// Monster [u] lands on troop [o] with a bite of [k]× its damage (its big hit, at most the cap), healing [heal]
  /// of what it took. Whether it bit (both still alive when it lands).
  bool _bite(Unit u, Unit o, double k, {double heal = 0}) {
    if (!u.alive || !o.alive) return false;
    final before = o.hp;
    u.attackedAt = t;
    _face(u, o.pos.x - u.pos.x, 0);
    impacts.add((o.pos, 'hit_${u.type}_big'));
    _hurt(o, u.stats.dmg * k, Hit.skill, u, monsterSkillCapOf(o));
    if (heal > 0) _healMonster(u, (before - max(0.0, o.hp)) * heal, MonsterHeal.bite);
    sfx.add(Sfx.hit);
    return true;
  }

  /// Living back-line troops (healers and long-range) within [r] of monster [u], nearest first.
  List<Unit> _backLineNear(Unit u, double r) => [for (final o in _troopsNear(u.pos, r)) if (o.line < 2) o];

  /// Sticky Glob's troop: the nearest back-line one within [stickyGlobK].reach.
  Unit? _globTarget(Unit u) => _backLineNear(u, stickyGlobK.reach).firstOrNull;

  /// Swoop's troop: the nearest back-line one within [swoopK].reach and out of the bat's reach.
  Unit? _swoopTarget(Unit u) => _backLineNear(u, swoopK.reach).where((o) => o.pos.distanceTo(u.pos) > u.stats.range).firstOrNull;

  /// Pounce's troop: within [pounceK].reach, below [pounceK].below of its HP (a Hero [pounceK].heroBelow), the
  /// one with the least of it left (the nearest of those alike).
  Unit? _pounceTarget(Unit u) {
    Unit? best;
    for (final o in _troopsNear(u.pos, pounceK.reach)) {
      final share = o.hp / o.maxHp;
      if (share >= (o.hero ? pounceK.heroBelow : pounceK.below)) continue;
      if (best == null || share < best.hp / best.maxHp) best = o;
    }
    return best;
  }

  /// Trample's troop: among the troops [trampleK].near–[trampleK].far ahead of the rider (to its left), the
  /// nearest back-line one, else the farthest.
  Unit? _trampleTarget(Unit u) {
    final ahead = [
      for (final o in _troopsNear(u.pos, trampleK.far))
        if (o.pos.x < u.pos.x && o.pos.distanceTo(u.pos) >= trampleK.near) o
    ];
    return ahead.where((o) => o.line < 2).firstOrNull ?? ahead.lastOrNull;
  }
}
