part of 'game.dart';

// #48's special shots and ground objects (docs/units-and-combat.md, "Special shots and ground objects"): the
// pieces the Hero skills snipe, crippleShot, pierceShot, javelin, axeThrow, chainLightning, frostStorm and
// banner are built from. A [Shot] can carry its own speed, look and on-hit
// effect ([Shot.special]); a [LineShot] pierces everything along a line, or flies out and back; a chain
// jumps from foe to foe ([HeroShots.chainStrike]); a [Zone] on the ground acts on whoever stands in it; a
// [Beam] is a line the UI draws for a moment, and a [Ring] a ring bursting out on the ground. How they look is
// lib/hero_skill_fx.dart. The monsters' skills (#59, monster_skills.dart) use them too, with looks of their own
// (a slime's glob, its puddle, falling arrows, a draining beam, the rings' colours), and so do the troops' skills
// (#81, game.dart's [troopSkills]): each cast shows a look of its own (a ring, a beam, a zone that only shows), drawn
// by lib/skills.dart.

/// How the UI draws a special shot ([Shot.look], [LineShot.look]); the game only carries it.
enum ShotLook {
  /// The shooter's own arrow, or the wizard's magic (main.dart's wizard_fx.dart).
  plain,

  /// The arrow 1.5× as big.
  trail,

  /// The arrow tinted ice blue.
  ice,

  /// A long arrow.
  long,

  /// The arrow 1.6× as long, tinted steel grey: a spear.
  spear,

  /// A frame of the thrower's hit burst, spinning.
  spin,

  /// The slime's own hit burst's blob, flying (a slime's Sticky Glob, #59).
  glob,

  /// The arrow 1.3× as long in cool silver: Spellbreaker's (#88).
  silver,
}

/// How the UI draws a [Zone] on the ground.
enum ZoneLook {
  /// The summon circle in ice blue over a pale disc of its reach.
  frost,

  /// A red ribbon flag on a pole.
  banner,

  /// A green slime puddle with bubbles rising and popping (a slime's Slime Tide, #59).
  slime,

  /// Its reach faintly marked, with the skeleton archer's arrows falling into it all over (Bone Rain, #59).
  arrowRain,

  /// Its reach in the troops' pale blue, with the archer's own arrows falling into it once each, one after another
  /// (Arrow Rain, #81). It only shows: its arrows' damage is the archer's shots.
  volley,

  /// Holy ground (Consecration, #88): a rose-white disc, a rose rim drawing itself round, small crosses turning
  /// slowly and motes rising.
  consecrate,

  /// A hole in the world (Singularity, #88): an indigo rim over a faint indigo fill, three spiral arms of white
  /// specks turning inward, shrinking a little over its life.
  singularity,
}

/// How the UI draws a [Beam].
enum BeamLook {
  /// A jagged pale-blue line.
  lightning,

  /// A jagged yellow line: God's Thunder's leap (store.dart).
  thunder,

  /// A green line waving gently, with motes flowing along it from its last point to its first: life drawn from
  /// the target to the caster (the necromancer's Soul Drain, #59).
  drain,

  /// A straight steel shaft with a chartreuse tip, shooting from its first point (the lancer) to its last and
  /// back: Impale's lunge (#88).
  lunge,

  /// A straight spear-shaped streak, white on pale teal, shooting from its first point to its last: Piercing
  /// Thrust through its targets (#81).
  thrust,

  /// A magenta zigzag streak from its first point to its last, fading: a Phantom Rush dash (#88).
  rush,

  /// A mint ribbon from its first point (the priest) to its last (the troop it lifts), white motes flowing along it
  /// to the priest: Lifeline (#88).
  tether,
}

/// How the UI draws a bursting [Ring], and colours a guard ring ([Unit.guardLook]); the game only carries it. The
/// colours (pale to steel) are plain rings, a monster's shout or slam (#59). The rest are the troops' skills' own
/// looks (#81), the awakening skills' (#88) and three champions' landings (#59), each its own shape in its own colour.
enum RingLook {
  pale,
  grey,
  dark,
  dust,
  red,
  orange,
  bone,
  brown,
  steel,

  /// Hold Fast: a steel-blue ring closing in on the soldier's feet and a shield flashing before it; the soldier's
  /// guard ring in steel blue while it lasts.
  brace,

  /// Circle Slash: a white blade arc sweeping once round the knight.
  slash,

  /// Rampage: an ember ring and sparks bursting off the swordsman (its rage aura while Rampage lasts is drawn from
  /// [Unit.frenzyUntil]).
  rage,

  /// Healing Prayer: a mint ring over the prayer's reach.
  prayer,

  /// Healing Prayer: a column of mint light rising over a troop it heals.
  pillar,

  /// Crushing Blow: cracks running out through the ground from the axeman's feet, a dust ring and dust puffs.
  crack,

  /// Arcane Blast: a violet ring, a flash and sparks where the orb lands, over its splash.
  arcane,

  /// Holy Shield: a white ring over its reach; the guard ring of the troops it shields in white while it lasts.
  holy,

  /// Holy Shield: a white dome rising over a troop it shields.
  dome,

  /// Impale (#88), a broken wind-up: eight chartreuse shards bursting off the foe and a white flash.
  shatter,

  /// Spellbreaker (#88): a broken rune ring of six silver arcs spinning apart to the spread it strips, and
  /// graphite-edged shards flying off.
  dispel,

  /// Singularity (#88): a ring collapsing into the well's core, and a white flash as it bursts.
  implode,

  /// Disarm (#88): six iron shards bursting from the foe's weapon arm, a white-hot chevron flashing over them.
  shards,

  /// Unbroken (#88): a deep cyan ring bursting at the knight's feet and four chain links snapping outward at knee
  /// height.
  unchain,

  /// Phantom Rush (#88): an X slashed across a foe it cuts, magenta on a pale core.
  crossCut,

  /// Skyfall (#88): a white-hot flash where the axeman lands, two ash shockwaves and dark rubble chips flung out.
  crater,

  /// Lifeline (#88): five mint petals opening at the feet of the troop it set down.
  bloom,

  /// Brutal Swing (#59, a champion's landing): a red-white crescent sweeping round the elite orc over its reach.
  cleave,

  /// Blade Dance (#59): three white slashes spinning round the greatsword skeleton, one spin each cut.
  spin,

  /// Shield Up (#59): a steel shield before the armored skeleton, facing the troops, while its ward lasts
  /// ([Status.shotWard]).
  ward,
}

/// How long a [Ring] takes to burst out and fade, unless its maker says otherwise (s).
const ringTime = 0.6;

/// How far either side of its line a [LineShot] hits by default: half a tile.
const lineWidth = tile / 2;

/// How long a chain's [Beam] shows ([HeroShots.chainStrike]).
const chainBeamTime = 0.3;

/// A shot that flies a straight line instead of homing on one foe ([Game.lineShots]). It leaves [start]
/// towards a point and flies [length] at [speed], hurting every foe (a living unit of the other side) within
/// [width] of its path once as it passes: [dmg] through [Game._hurt] with [from]'s hit burst, then
/// [onHit]. A [boomerang] turns at the end of its line and flies back to its thrower (to [start] if the
/// thrower fell), hitting each foe on the way once more. Its path is on the ground, like the units'
/// positions; the UI draws it a little higher.
class LineShot {
  final Unit from;
  final Point<double> start, dir; // [dir]: the way out, a unit vector (ahead, to the right, if no way is given)
  final double dmg, speed, length, width;
  final bool boomerang;
  final ShotLook look;
  final void Function(Unit hit)? onHit;
  Point<double> pos;
  bool back = false; // a boomerang on its way home
  bool done = false;
  final hit = <Unit>{}; // those it hit on this leg

  LineShot(this.from, this.start, Point<double> towards,
      {required this.dmg,
      required this.speed,
      required this.length,
      this.width = lineWidth,
      this.boomerang = false,
      this.look = ShotLook.plain,
      this.onHit})
      : pos = start,
        dir = _direction(towards - start);

  /// Where it is heading now: the end of its line, or home.
  Point<double> get heading => back ? (from.alive ? from.pos : start) : start + dir * length;
}

/// A patch of ground that acts on whoever stands in it ([Game.zones]). Each living unit of [side] within
/// [radius] of [at] gets [inside] every tick and [pulse] every [every] s, the first pulse on the tick it is
/// placed ([since]), for [duration] (so [pulses] in all). It stays where it was placed and goes when its
/// time is up or the wave ends. One with neither only shows (Arrow Rain's, [ZoneLook.volley]).
class Zone {
  final Unit from;
  final Point<double> at;
  final double radius, since, until, every;
  final Side side;
  final ZoneLook look;
  final void Function(Unit u)? inside, pulse;
  final int pulses;
  int pulsed = 0;

  Zone(this.from, this.at,
      {required this.since,
      required double duration,
      required this.radius,
      required this.side,
      required this.look,
      this.every = 1,
      this.inside,
      this.pulse})
      : until = since + duration,
        pulses = (duration / every - 1e-9).ceil();

  bool covers(Unit u) => u.alive && u.side == side && u.pos.distanceTo(at) <= radius;
}

/// A line the UI draws for a moment ([Game.beams]): through [points] (on the ground, like the units'
/// positions), from [since] until [since] + its duration. One made [Beam.between] units runs through them
/// where they are now ([at]), and goes as soon as one of them falls.
class Beam {
  final List<Point<double>> points;
  final List<Unit>? follow;
  final double since, until;
  final BeamLook look;

  Beam(this.points, {required this.since, required double duration, this.look = BeamLook.lightning})
      : follow = null,
        until = since + duration;

  /// A beam through [units], following them as they move (a drain lasting seconds).
  Beam.between(List<Unit> units, {required this.since, required double duration, this.look = BeamLook.lightning})
      : follow = List.unmodifiable(units),
        points = [for (final u in units) u.pos],
        until = since + duration;

  /// The points it runs through now.
  List<Point<double>> get at => follow == null ? points : [for (final u in follow!) u.pos];

  /// A [Beam.between] whose unit fell: it goes.
  bool get broken => follow?.any((u) => !u.alive) ?? false;
}

/// A ring the UI draws bursting out on the ground ([Game.rings]): round [at], from nothing to [radius] across
/// its duration from [since], fading as it grows (a monster's shout or slam, #59), or a troop skill's look of
/// its own ([RingLook], #81). The game drops it when its time is up. One made [Ring.over] a unit stays on it as it
/// moves, and goes as soon as it falls.
class Ring {
  final Point<double> at;
  final Unit? follow;
  final double radius, since, until;
  final RingLook look;

  Ring(this.at, {required this.radius, required this.since, required this.look, double duration = ringTime})
      : follow = null,
        until = since + duration;

  /// A ring on [u], moving with it (a dome over a shielded troop, a column over a healed one).
  Ring.over(Unit u, {required this.radius, required this.since, required this.look, double duration = ringTime})
      : follow = u,
        at = u.pos,
        until = since + duration;

  /// Where it is now: on its unit, or where it was placed.
  Point<double> get centre => follow?.pos ?? at;

  /// A [Ring.over] whose unit fell: it goes.
  bool get broken => !(follow?.alive ?? true);
}

/// [d] as a unit vector; ahead (to the right) when it has no length.
Point<double> _direction(Point<double> d) {
  final m = d.magnitude;
  return m > 0 ? d * (1 / m) : const Point(1.0, 0.0);
}

extension HeroShots on Game {
  /// The units a chain jumps through ([chainStrike]): [first], then again and again the living unit of its
  /// side nearest the last one, within [radius] of it and not in the chain yet: [jumps] jumps at most, fewer
  /// when none is near enough.
  List<Unit> chainFrom(Unit first, {required int jumps, required double radius}) {
    final chain = [first];
    for (var i = 0; i < jumps; i++) {
      Unit? next;
      var best = double.infinity;
      for (final o in units) {
        if (o.side != first.side || !o.alive || chain.contains(o)) continue;
        final d = o.pos.distanceTo(chain.last.pos);
        if (d <= radius && d < best) (next, best) = (o, d);
      }
      if (next == null) break;
      chain.add(next);
    }
    return chain;
  }

  /// [from] strikes along a chain ([chainFrom]) through [first]: [dmg] to [first], and at each jump [falloff]
  /// less than at the one before (dmg × (1 − falloff)^i), each through [_hurt] with [from]'s hit burst. A
  /// [Beam] from [from] through them shows it for [chainBeamTime]. Returns the chain.
  List<Unit> chainStrike(Unit from, Unit first,
      {required double dmg, required int jumps, required double radius, required double falloff}) {
    final chain = chainFrom(first, jumps: jumps, radius: radius);
    for (final (i, o) in chain.indexed) {
      impacts.add((o.pos, _fxOf(from, 'hit_${from.type}')));
      _hurt(o, dmg * pow(1 - falloff, i), Hit.skill, from);
    }
    beams.add(Beam([from.pos, for (final o in chain) o.pos], since: t, duration: chainBeamTime));
    return chain;
  }

  /// Every tick, after the shots: the line shots fly, the zones act, and the beams and rings whose time is up or
  /// whose unit fell go.
  void _moveSpecials(double dt) {
    for (final s in lineShots) {
      _fly(s, dt);
    }
    lineShots.removeWhere((s) => s.done);
    zones.removeWhere((z) => t >= z.until);
    for (final z in zones) {
      final on = units.where(z.covers).toList();
      if (z.inside case final inside?) on.forEach(inside);
      for (; z.pulsed < z.pulses && z.since + z.pulsed * z.every <= t; z.pulsed++) {
        if (z.pulse case final pulse?) on.where((u) => u.alive).forEach(pulse);
      }
    }
    beams.removeWhere((b) => t >= b.until || b.broken);
    rings.removeWhere((r) => t >= r.until || r.broken);
  }

  /// [s] flies on for [dt]: along its line, and a boomerang home again. What is left of a step that reaches
  /// the end of the line goes on home.
  void _fly(LineShot s, double dt) {
    var step = s.speed * dt;
    while (!s.done && step > 1e-9) {
      final to = s.heading, d = s.pos.distanceTo(to);
      if (d > step + 1e-9) {
        // On its way.
        final next = s.pos + (to - s.pos) * (step / d);
        _sweep(s, s.pos, next);
        s.pos = next;
        return;
      }
      _sweep(s, s.pos, to);
      s.pos = to;
      step -= d;
      if (!s.boomerang || s.back) {
        s.done = true;
      } else {
        s.back = true; // the end of its line: home, hitting them all again
        s.hit.clear();
      }
    }
  }

  /// [s] passes from [a] to [b]: every foe within its width of that it hasn't hit on this leg is hit (by a
  /// monster's, a skill's blow: at most [monsterSkillCapOf] of its max HP).
  void _sweep(LineShot s, Point<double> a, Point<double> b) {
    for (final o in units.toList()) {
      if (o.side == s.from.side || !o.alive || s.hit.contains(o) || _toSegment(o.pos, a, b) > s.width) continue;
      s.hit.add(o);
      impacts.add((o.pos, _fxOf(s.from, 'hit_${s.from.type}')));
      _hurt(o, s.dmg, Hit.skill, s.from, s.from.side == Side.enemy ? monsterSkillCapOf(o) : null); // a monster's is a skill's: capped
      s.onHit?.call(o);
    }
  }
}
