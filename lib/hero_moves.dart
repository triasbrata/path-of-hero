part of 'game.dart';

// The Hero skills' movement (#48; docs/units-and-combat.md, "Forced movement"). A unit can be carried
// rather than walk ([Unit.move]): a monster knocked back or dragged, a troop leaping or charging, and the other
// way round for the monsters' skills (#59: a monster leaping or charging at the troops, a troop knocked back;
// a troop stunned within limits, [HeroMoves.stunTroop]). While carried it does nothing else (it still takes
// blows), nobody shoves it, and a troop doesn't step aside for anyone; hopping or charging, it passes through
// the others. A troop can also brace ([Unit.brace]): it doesn't move and nothing shoves it, and it meets each
// foe that comes into its reach once.
//
// The seven movement Hero skills (branch 2a: Shield Bash, Spear Sweep, Guardian Leap, Death Leap, Cavalry
// Charge, Chain Hook, Spear Wall) are here too, their rules ([HeroMoves._wantsMove]), what they do
// ([HeroMoves._castMove]) and their numbers (`<id>K`); hero_skills.dart sends them here from one case each.

/// How long a knockback's slide, a leap's hop and a drag take (s), and how high a hop rises at its middle
/// (world units).
const slideTime = 0.15, hopTime = 0.35, dragTime = 0.3, hopHeight = 10.0;

/// A charge that hasn't reached its target after this long (s) gives up.
const chargeMaxTime = 2.0;

/// Where a leap lands and a drag ends: this far from the unit it goes to (a personal space).
const besideGap = 12.0;

/// Shield Bash (soldier): at the nearest elite-or-higher foe in reach but the boss, or while below [below] of
/// its HP at the nearest foe in reach: [hit] × its damage, a knockback of [shove] and a stun of [stun] s (a
/// mini boss half of both; the boss only the blow).
const shieldBashK = (below: 1.0, hit: 2.0, shove: tile, stun: 1.5);

/// Spear Sweep (lancer): with [crowd]+ foes ahead (towards the monsters) in its reach, each foe ahead within its
/// reach + [extra] takes [hit] × its damage and is knocked back [shove].
const sweepK = (crowd: 1, extra: tile / 2, hit: 1.0, shove: tile);

/// Guardian Leap (knight): a foe within [guard] of a troop healer or long-range troop, within [reach] of the
/// knight but out of its own reach, while the knight is above [above] of its HP: it leaps beside it, [hit] ×
/// its damage and a stun of [stun] s.
const rescueLeapK = (guard: tile, reach: 5 * tile, above: 0.4, hit: 2.0, stun: 1.0);

/// Death Leap (swordsman): a healing necromancer or skeleton archer within [reach] but out of its own reach,
/// while the swordsman is above [above] of its HP: it leaps beside it, [hit] × its damage, and fights on there.
const deathLeapK = (reach: 5 * tile, above: 0.4, hit: 2.5);

/// Cavalry Charge (lancer): nothing nearer than [near], and a foe [near]–[far] away and ahead with no troop
/// within [lane] of the way there: it charges the farthest such at [speed] × its speed, down through the
/// nearer ones; each other foe within [lane] of its path takes [pass] × its damage and is shoved [shove]
/// aside; the target [hit] × and a stun of [stun] s.
const chargeK = (near: 3 * tile, far: 6 * tile, speed: 3.0, lane: 8.0, pass: 1.0, shove: tile / 2, hit: 2.0, stun: 1.0);

/// Chain Hook (armored axeman): a skeleton archer or healing necromancer [near]–[far] away and out of its
/// reach, never the boss or a mini boss: dragged beside the axeman, then [hit] × its damage and a stun of
/// [stun] s.
const hookK = (near: 2 * tile, far: 5 * tile, hit: 1.0, stun: 1.0);

/// Spear Wall (lancer): with [crowd]+ foes within [reach] ahead and none in its reach, it braces [time] s; each
/// foe coming into its reach meanwhile takes [hit] × its damage and a stun of [stun] s.
const spearWallK = (crowd: 1, reach: 3 * tile, time: 5.0, hit: 1.5, stun: 1.0);

/// A Hero takes this share of a monster's shove (#59): half, as a stun on it lasts half ([troopStunK]).
const heroShoveShare = 0.5;

/// A monster's stun on a troop (#59) lasts at most [most] s, on a Hero [hero] of that; then the troop can't be
/// stunned again for [immune] s ([Unit.stunImmuneUntil]), so no stun-lock.
const troopStunK = (most: 0.8, hero: 0.5, immune: 4.0);

/// A forced move of a unit ([Unit.move]).
sealed class Move {
  /// How high the unit is off the ground at game time [t]: a hop's arc, 0 on the ground.
  double liftAt(double t) => 0;
}

/// How the UI draws a carried unit besides its hop ([Carry.look]); the game only carries it.
enum CarryLook {
  /// Only the unit, its hop's arc and its shadow on the ground.
  plain,

  /// Two magenta afterimages trailing it (Phantom Rush's dashes, #88).
  ghost,

  /// A dark landing shadow swelling where it comes down (Skyfall's leap, #88).
  skyfall,
}

/// Carried from [from] to [to] between game times [start] and [end]: a slide, a drag (by [by], who pulls it),
/// or with a [lift] a hop. [onEnd] runs when it gets there. [look] is for the drawing only; [radius] is how wide
/// what it lands on is ([CarryLook.skyfall]'s shadow).
class Carry extends Move {
  Carry(this.from, this.to, this.start, this.end, {this.lift = 0, this.onEnd, this.by, this.look = CarryLook.plain, this.radius = 0});
  final Point<double> from, to;
  final double start, end, lift, radius;
  final void Function()? onEnd;
  final Unit? by;
  final CarryLook look;

  /// How far along it is at game time [t], 0 to 1.
  double progress(double t) => end <= start ? 1 : ((t - start) / (end - start)).clamp(0.0, 1.0);

  @override
  double liftAt(double t) {
    final p = progress(t);
    return lift * 4 * p * (1 - p);
  }
}

/// Galloping at [target] at [speed] until the charger has it in reach ([onArrive]) or it is [until].
/// Every other foe within [lane] of its path is met once: [hit] × the charger's damage (none at 0), then
/// [onPass] on it (a skill's own blow or hold), then shoved [shove] aside ([Game.knockBack]).
class Charge extends Move {
  Charge(this.target, this.speed, this.until, {required this.lane, required this.hit, required this.shove, this.onArrive, this.onPass});
  final Unit target;
  final double speed, until, lane, hit, shove;
  final void Function()? onArrive;
  final void Function(Unit)? onPass;
  final passed = <Unit>{};
}

/// A troop bracing until [until] ([Unit.brace]); [onMeet] runs once for each foe that comes into its reach.
class Brace {
  Brace(this.until, [this.onMeet]);
  final double until;
  final void Function(Unit)? onMeet;
  final met = <Unit>{};
}

/// How much of a shove [o] takes: a monster boss none, a mini boss half, the rest all of it; a Hero
/// [heroShoveShare], any other troop all of it.
double shoveShare(Unit o) => o.side == Side.troop
    ? (o.hero ? heroShoveShare : 1.0)
    : switch (o.tier) { Tier.boss => 0.0, Tier.miniBoss => 0.5, _ => 1.0 };

/// Distance from [p] to the segment from [a] to [b].
double _toSegment(Point<double> p, Point<double> a, Point<double> b) {
  final ab = b - a, len2 = ab.x * ab.x + ab.y * ab.y;
  if (len2 == 0) return p.distanceTo(a);
  final k = (((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / len2).clamp(0.0, 1.0);
  return p.distanceTo(a + ab * k);
}

extension HeroMoves on Game {
  /// Knocks [o] [dist] along [dir] over [slideTime], by its [shoveShare]. [dir] defaults to away from its
  /// foes: a monster away from the base, a troop towards it. A monster never ends out past the right edge
  /// ([rightLimit]), a troop never behind the back line ([_troopRear]); one already past it isn't pushed
  /// further out. A troop holding its ground ([_shoveProof]) isn't moved. Whether it moves at all.
  bool knockBack(Unit o, double dist, [Point<double>? dir]) {
    final way = dir ?? Point(o.side == Side.enemy ? 1.0 : -1.0, 0.0), d = dist * shoveShare(o), len = way.magnitude;
    if (!o.alive || d <= 0 || len == 0) return false;
    if (_shoveProof(o)) {
      _fxStood(o); // Anchor's counter (pusaka_engine.dart)
      return false;
    }
    final to = o.pos + way * (d / len);
    final x = o.side == Side.enemy ? min(to.x, max(rightLimit, o.pos.x)) : max(to.x, min(_troopRear, o.pos.x));
    o.move = Carry(o.pos, _onField(Point(x, to.y)), t, t + slideTime);
    return true;
  }

  /// A troop that a monster's shove or drag doesn't move: carried already, braced, or under [Status.noShove].
  /// A monster always moves (the boss by its [shoveShare]).
  bool _shoveProof(Unit o) => o.side == Side.troop && (_held(o) || (o.effects.isNotEmpty && under(o, Status.noShove)));

  /// How far back a shove or a drag may take a troop: the back line (the view's left edge once the line stays
  /// behind, [_rearEdge]), less the gap an entered troop keeps from it.
  double get _troopRear => _rearEdge + Game.clearOfLine;

  /// Unit [u] (a troop's Hero skill, a monster's skill) leaps to [to] in a [hopTime] hop; [onLand] runs as it
  /// lands.
  void leap(Unit u, Point<double> to, [void Function()? onLand]) {
    _face(u, to.x - u.pos.x, 0);
    u.move = Carry(u.pos, _onField(to), t, t + hopTime, lift: hopHeight, onEnd: onLand);
  }

  /// Drags [o] to [to] over [dragTime] (pulled [by] someone, for the drawing): never the boss, nor a troop
  /// holding its ground ([_shoveProof]), and a troop never behind the back line ([_troopRear]). [onEnd] runs
  /// when it gets there. Whether it moves.
  bool drag(Unit o, Point<double> to, {void Function()? onEnd, Unit? by}) {
    if (!o.alive || o.tier == Tier.boss) return false;
    if (_shoveProof(o)) {
      _fxStood(o); // Anchor's counter (pusaka_engine.dart)
      return false;
    }
    final end = o.side == Side.troop ? Point(max(to.x, min(_troopRear, o.pos.x)), to.y) : to;
    o.move = Carry(o.pos, _onField(end), t, t + dragTime, onEnd: onEnd, by: by);
    return true;
  }

  /// Stuns monster [o] for [time] s (it stands frozen, [Unit.stunUntil]): never the necromancer, as with
  /// Crushing Blow; a mini boss half as long; shorter under the Bayangan Unshaken ([Omens._omenUnshaken], at least
  /// [effectTimeFloor], as the duration scaler); none while it shrugs one off under the Bayangan Unbowed
  /// ([Omens._omenShrug]).
  void _stunFor(Unit o, double time) {
    if (o.type == boss || o.tier == Tier.boss) return;
    if (_omenShrug(o)) return; // Unbowed (omen.dart)
    o.stunUntil = max(o.stunUntil, t + scaledEffectTime(time * (o.tier == Tier.miniBoss ? 0.5 : 1), _omenUnshaken(o, null)));
  }

  /// A monster's skill stuns troop [o] (#59): it stands frozen ([Unit.stunUntil], as a stunned monster does)
  /// for [time] s, at most [troopStunK].most, a Hero [troopStunK].hero of that. Then it can't be stunned again
  /// for [troopStunK].immune s ([Unit.stunImmuneUntil]); meanwhile a stun does nothing. Whether it took.
  bool stunTroop(Unit o, double time) {
    if (!o.alive || time <= 0 || t < o.stunImmuneUntil) return false;
    o.stunUntil = max(o.stunUntil, t + min(time, troopStunK.most) * (o.hero ? troopStunK.hero : 1));
    o.stunImmuneUntil = o.stunUntil + troopStunK.immune;
    return true;
  }

  /// Unit [u] (a troop's Hero skill, a monster's skill) charges [target] at [speed] × its own ([Charge]):
  /// every other foe within [lane] of its path takes [hit] × its damage (none at 0), then [onPass] on it,
  /// and is shoved [shove] aside, away from the path. Having the target in reach, it stops and [onArrive]
  /// runs; if the target dies first, it takes [chargeMaxTime] or it is stunned (#59), it just stops.
  void charge(Unit u, Unit target,
      {required double speed,
      required double lane,
      required double hit,
      required double shove,
      void Function()? onArrive,
      void Function(Unit)? onPass}) {
    u.move = Charge(target, u.stats.speed * speed, t + chargeMaxTime, lane: lane, hit: hit, shove: shove, onArrive: onArrive, onPass: onPass);
  }

  /// Troop [u] braces for [time] s: it doesn't move and nothing shoves it; [onMeet] runs once for each foe
  /// that comes into its reach meanwhile (those already in it at once).
  void brace(Unit u, double time, [void Function(Unit)? onMeet]) => u.brace = Brace(t + time, onMeet);

  /// Whether [u] is bracing now: a brace holds only during a wave.
  bool braced(Unit u) => waveActive && t < (u.brace?.until ?? double.negativeInfinity);

  /// The spot [gap] from [target] on the side towards [from]: where a leap or a drag ends.
  Point<double> beside(Unit target, Point<double> from, double gap) {
    final d = from - target.pos, len = d.magnitude;
    return _onField(len < 0.01 ? target.pos - Point(gap, 0.0) : target.pos + d * (gap / len));
  }

  /// [p] inside the field's rows, where the separation step keeps every unit.
  Point<double> _onField(Point<double> p) => Point(p.x, p.y.clamp(4.0, fieldH - 2));

  /// Carried or braced: it holds its ground against shoves and doesn't step aside ([Game._firm]).
  bool _held(Unit u) => u.move != null || braced(u);

  /// In a hop's air or charging: it bumps into nobody and nobody into it (a charge meets those on its path
  /// itself).
  bool _passesThrough(Unit u) => switch (u.move) { Carry(:final lift) => lift > 0, Charge() => true, null => false };

  /// Every tick for a living unit, before anything else it does. A braced one meets the foes that came into
  /// its reach. A carried one goes along its move and does nothing else: true.
  bool _moves(Unit u, double dt) {
    if (u.brace case final b?) {
      if (!braced(u)) {
        u.brace = null;
      } else if (b.onMeet case final meet?) {
        for (final o in _foesNear(u.pos, u.stats.range)) {
          if (b.met.add(o)) meet(o);
        }
      }
    }
    switch (u.move) {
      case null:
        return false;
      case final Carry m:
        final p = m.progress(t);
        u
          ..pos = m.from + (m.to - m.from) * p
          ..moving = false;
        if (p >= 1) {
          u.move = null;
          m.onEnd?.call();
        }
      case final Charge m:
        if (!m.target.alive || t >= m.until || t < u.stunUntil) {
          u.move = null; // it just stops (a stunned one where it is), and carries on as usual this very tick
          return false;
        }
        final d = m.target.pos - u.pos, len = d.magnitude;
        if (len <= u.stats.range) {
          u
            ..move = null
            ..moving = false;
          m.onArrive?.call();
          return true;
        }
        final from = u.pos, dir = d * (1 / len), perp = Point(-dir.y, dir.x);
        u
          ..pos += dir * min(len, m.speed * dt)
          ..moving = true
          ..heading = dir;
        _face(u, d.x, d.y);
        for (final o in units.toList()) {
          if (o.side == u.side || o == m.target || !o.alive || !o.entered || m.passed.contains(o) || _toSegment(o.pos, from, u.pos) > m.lane) {
            continue;
          }
          m.passed.add(o);
          impacts.add((o.pos, 'hit_orc_rider')); // hooves' dust
          if (m.hit > 0) _hurt(o, u.stats.dmg * m.hit, Hit.skill, u);
          if (o.alive) m.onPass?.call(o);
          // Aside: to whichever side of the path it stands; dead on the line, towards the field's middle.
          final lat = dir.x * (o.pos.y - u.pos.y) - dir.y * (o.pos.x - u.pos.x);
          final side = lat.abs() > 0.5 ? lat.sign : (perp.y * (fieldH / 2 - o.pos.y) >= 0 ? 1.0 : -1.0);
          knockBack(o, m.shove, perp * side);
        }
    }
    return true;
  }

  // The seven movement Hero skills.

  /// Whether Hero [u]'s movement skill would do something now ([HeroSkills.wantsHeroSkill]).
  bool _wantsMove(Unit u) => switch (u.heroSkill) {
        HeroSkill.shieldBash => _bashTarget(u) != null,
        HeroSkill.sweep => _foesAhead(u, u.stats.range).length >= sweepK.crowd,
        HeroSkill.rescueLeap => u.hp > u.maxHp * rescueLeapK.above && _rescueTarget(u) != null,
        HeroSkill.deathLeap => u.hp > u.maxHp * deathLeapK.above && _deathLeapTarget(u) != null,
        HeroSkill.charge => _chargeTarget(u) != null,
        HeroSkill.hook => _hookTarget(u) != null,
        HeroSkill.spearWall =>
          !braced(u) && _foesNear(u.pos, u.stats.range).isEmpty && _foesAhead(u, spearWallK.reach).length >= spearWallK.crowd,
        _ => false,
      };

  /// What Hero [u]'s movement skill does ([HeroSkills._castHeroSkill]). Every blow goes through [_hurt] with the
  /// Hero as the attacker, a leap's and a hook's when it lands.
  void _castMove(Unit u) {
    final dmg = u.stats.dmg;
    switch (u.heroSkill) {
      case HeroSkill.shieldBash:
        final o = _bashTarget(u)!;
        impacts.add((o.pos, _fxOf(u, 'hit_soldier_big')));
        _hurt(o, dmg * shieldBashK.hit, Hit.skill, u);
        if (o.alive) {
          knockBack(o, shieldBashK.shove);
          _stunFor(o, shieldBashK.stun);
        }
        sfx.add(Sfx.sword);
      case HeroSkill.sweep:
        for (final o in _foesAhead(u, u.stats.range + sweepK.extra)) {
          impacts.add((o.pos, _fxOf(u, 'hit_lancer_big')));
          _hurt(o, dmg * sweepK.hit, Hit.skill, u);
          if (o.alive) knockBack(o, sweepK.shove);
        }
        sfx.add(Sfx.sword);
      case HeroSkill.rescueLeap:
        final o = _rescueTarget(u)!;
        leap(u, beside(o, u.pos, besideGap), () => _landOn(u, o, 'hit_knight_big', rescueLeapK.hit, rescueLeapK.stun));
      case HeroSkill.deathLeap:
        final o = _deathLeapTarget(u)!;
        leap(u, beside(o, u.pos, besideGap), () => _landOn(u, o, 'hit_swordsman_big', deathLeapK.hit, 0));
      case HeroSkill.charge:
        final o = _chargeTarget(u)!;
        charge(u, o,
            speed: chargeK.speed,
            lane: chargeK.lane,
            hit: chargeK.pass,
            shove: chargeK.shove,
            onArrive: () => _landOn(u, o, 'hit_lancer_big', chargeK.hit, chargeK.stun));
      case HeroSkill.hook:
        final o = _hookTarget(u)!;
        drag(o, beside(u, o.pos, besideGap), by: u, onEnd: () => _landOn(u, o, 'hit_armored_axeman', hookK.hit, hookK.stun));
        u.move = Carry(u.pos, u.pos, t, t + dragTime); // it stands while it pulls
        sfx.add(Sfx.dagger);
      case HeroSkill.spearWall:
        brace(u, spearWallK.time, (o) => _landOn(u, o, 'hit_lancer', spearWallK.hit, spearWallK.stun));
        sfx.add(Sfx.magic);
      default:
        break;
    }
  }

  /// Hero [u]'s blow at [o] when a move gets there: [hit] × its damage with the [fx] burst, then a stun of
  /// [stun] s ([_stunFor]). Nothing when either is gone by then.
  void _landOn(Unit u, Unit o, String fx, double hit, double stun) {
    if (!u.alive || !o.alive) return;
    impacts.add((o.pos, _fxOf(u, fx)));
    _hurt(o, u.stats.dmg * hit, Hit.skill, u);
    if (o.alive && stun > 0) _stunFor(o, stun);
    sfx.add(Sfx.sword);
  }

  /// Living monsters on the field within [r] of [u] and ahead of it (towards the monsters, to the right),
  /// nearest first.
  List<Unit> _foesAhead(Unit u, double r) => [for (final o in _foesNear(u.pos, r)) if (o.pos.x >= u.pos.x) o];

  /// Shield Bash's foe: the nearest elite-or-higher one in reach but the boss; else, below [shieldBashK].below
  /// of its HP, the nearest in reach.
  Unit? _bashTarget(Unit u) {
    final inReach = _foesNear(u.pos, u.stats.range);
    return inReach.where((o) => HeroSkills._strong(o) && o.tier != Tier.boss).firstOrNull ??
        (u.hp < u.maxHp * shieldBashK.below ? inReach.firstOrNull : null);
  }

  /// Guardian Leap's foe: the nearest within [rescueLeapK].reach of [u] and out of its reach that is within
  /// [rescueLeapK].guard of a troop healer or long-range troop.
  Unit? _rescueTarget(Unit u) {
    final back = [for (final o in troops) if (o != u && o.alive && o.entered && o.line < 2) o];
    if (back.isEmpty) return null;
    return _foesNear(u.pos, rescueLeapK.reach)
        .where((o) => o.pos.distanceTo(u.pos) > u.stats.range && back.any((b) => b.pos.distanceTo(o.pos) <= rescueLeapK.guard))
        .firstOrNull;
  }

  /// Death Leap's foe: the nearest healing necromancer or skeleton archer within [deathLeapK].reach and out of
  /// [u]'s reach.
  Unit? _deathLeapTarget(Unit u) => _foesNear(u.pos, deathLeapK.reach)
      .where((o) => (o.type == necroHealer || o.type == 'skeleton_archer') && o.pos.distanceTo(u.pos) > u.stats.range)
      .firstOrNull;

  /// Cavalry Charge's foe: with no foe nearer than [chargeK].near (it isn't in a fight), the farthest foe ahead
  /// up to [chargeK].far that no other troop stands within [chargeK].lane of the way to (the charge runs
  /// through the nearer ones on its path).
  Unit? _chargeTarget(Unit u) {
    if (_foesNear(u.pos, chargeK.near).isNotEmpty) return null;
    bool clear(Unit o) => !troops.any((b) => b != u && b.alive && b.entered && _toSegment(b.pos, u.pos, o.pos) <= chargeK.lane);
    return _foesNear(u.pos, chargeK.far).reversed.where((o) => o.pos.x > u.pos.x && clear(o)).firstOrNull;
  }

  /// Chain Hook's foe: the nearest skeleton archer or healing necromancer [hookK].near–[hookK].far away and out
  /// of [u]'s reach, never the boss or a mini boss, and not being moved already.
  Unit? _hookTarget(Unit u) => _foesNear(u.pos, hookK.far).where((o) {
        final d = o.pos.distanceTo(u.pos);
        return (o.type == 'skeleton_archer' || o.type == necroHealer) &&
            o.tier != Tier.boss &&
            o.tier != Tier.miniBoss &&
            o.move == null &&
            d >= hookK.near &&
            d > u.stats.range;
      }).firstOrNull;
}
