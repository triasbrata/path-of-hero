part of 'game.dart';

// #84 (docs/formation-and-navigation.md, "Where melee stand to fight"): a melee troop with no foe in its reach
// walks to a spot around a monster from which it can hit, instead of into its allies' backs. Eight spots like a
// compass ([Spot]); the front ones are filled first and a troop flanks round to the back ones only when those
// are taken ([spotFill]). If the monster it goes for has none free, it takes one on the nearest monster that
// has; if no monster has, it waits just behind the fighters ([waitBack]) and steps into the first spot that
// frees. Each troop keeps its spot until it has to give it up ([Unit.spotOf], [Unit.spot]).

/// The eight spots around a monster, like a compass: its front faces the troops (left, towards the base), its
/// back the way it came. [dx], [dy]: the direction from the monster's centre (y grows downwards).
enum Spot {
  front(-1, 0),
  frontTop(-1, -1),
  top(0, -1),
  backTop(1, -1),
  back(1, 0),
  backBottom(1, 1),
  bottom(0, 1),
  frontBottom(-1, 1);

  const Spot(this.dx, this.dy);
  final double dx, dy;

  /// The unit vector from the monster's centre to this spot.
  Point<double> get dir {
    final len = sqrt(dx * dx + dy * dy);
    return Point(dx / len, dy / len);
  }
}

/// How many spots a monster has around it ([Spot]): the owner's compass of eight.
const spotCount = 8;

/// The order the spots are filled, a row at a time: the front first, then the two beside it, the top and the
/// bottom, the two behind those, and the back last. Within a row a troop takes the one nearer to it.
const spotFill = [
  [Spot.front],
  [Spot.frontTop, Spot.frontBottom],
  [Spot.top, Spot.bottom],
  [Spot.backTop, Spot.backBottom],
  [Spot.back],
];

/// A spot lies this far inside the troop's reach: in reach, and (at a soldier's reach, the separation's
/// [Game._personalSpace]) no deeper into the monster's body than a hair, so the troop doesn't shove it. It is
/// also the rounding a reach is given ([Engage.reaches]).
const spotSlack = 0.01;

/// Going round a monster to its spot, a troop keeps this far outside its own reach (a body: clear of the troops
/// already on spots), so it doesn't bump into them or stop half way to fight from a spot another holds.
const orbitGap = 12.0;

/// Going round, a troop steps in to its spot once it is within this angle of it, seen from the monster: it comes
/// in straight, between the troops on the spots beside it.
const stepInAt = pi / 12;

/// With every spot taken, a troop waits this far behind the front spot of the monster nearest to it, level with
/// it within a tile ([Engage._waitPoint]).
const waitBack = 1.5 * tile;

/// Where a shooter stands (decisions-log 199, units-and-combat.md "Long range hold"; the owner: not too far from the
/// fight, so its arrows and orbs don't fly long): no further from the foe it shoots than its shot flies in
/// [rangedFlight] s, never nearer than [rangedGap] (unless its reach is shorter), and within its reach
/// ([Engage.holdAt]). Bows and the wave's growth still lengthen its reach, so it still shoots further when a foe comes
/// at it or walks away; they no longer set where it stands. A troop shooter backs off a foe nearer than
/// [Game._kiteAt] of its hold, but never one [rangedGap] or further away ([Engage.kiteAt]): a ranged monster stands
/// that far at least once its reach allows (its own hold), so a troop doesn't back away from one that keeps stepping
/// up after it, the drift of decisions-log 153.
const rangedFlight = 0.5, rangedGap = 4 * tile;

extension Engage on Game {
  /// Every monster has one body today (the separation's [Game._personalSpace]), so a spot is that far from its
  /// centre at least, and as far as the troop reaches at most: a lancer, or a melee troop with bows, stands
  /// further out than a soldier.
  double spotRing(Unit u, Unit m) => max(Game._personalSpace, u.stats.range) - spotSlack;

  /// Whether [u] reaches [o]: within its reach, give or take [spotSlack]. The separation sets two bodies apart
  /// at exactly [Game._personalSpace], a melee unit's reach, give or take a rounding error: without the slack a
  /// unit a hair out stepped in again (and shoved) instead of striking.
  bool reaches(Unit u, Unit o) => o.pos.distanceTo(u.pos) <= u.stats.range + spotSlack;

  /// How far [u] stands from the foe it fights: a shooter's hold ([rangedFlight] of its shot's flight, at least
  /// [rangedGap], at most its reach), anyone else's reach. Both sides' shooters step up to it while they shoot.
  double holdAt(Unit u) => u.stats.shotSpeed > 0 ? min(u.stats.range, max(rangedGap, u.stats.shotSpeed * rangedFlight)) : u.stats.range;

  /// A troop shooter [u] backs off a foe nearer than this while it shoots (the kite): [Game._kiteAt] of its hold, and
  /// under [rangedGap] whatever its hold.
  double kiteAt(Unit u) => min(holdAt(u) * Game._kiteAt, rangedGap);

  /// Where troop [u] stands on spot [s] of monster [m].
  Point<double> spotPoint(Unit u, Unit m, Spot s) => m.pos + s.dir * spotRing(u, m);

  /// A melee troop that looks for a spot: mid-wave, on the field, not falling back.
  bool _seeksSpot(Unit u) => waveActive && u.side == Side.troop && u.alive && u.entered && u.line == 2 && !u.retreating;

  /// Two troops with spots of the same monster, each within half an [orbitGap] of its reach (on its spot, or
  /// stepping in to it): they stand closer than the separation's [Game._personalSpace] (eight spots at a
  /// soldier's reach are about 9 apart), so they don't shove each other.
  bool _spotMates(Unit a, Unit b) {
    final m = a.spotOf;
    if (m == null || a.spot == null || b.spot == null || b.spotOf != m || a.spot == b.spot) return false;
    return m.pos.distanceTo(a.pos) <= a.stats.range + orbitGap / 2 && m.pos.distanceTo(b.pos) <= b.stats.range + orbitGap / 2;
  }

  /// Once a tick, before anyone moves: which spot every melee troop holds or walks to ([Unit.spotOf],
  /// [Unit.spot]), or that it waits ([Unit.waiting]).
  ///
  /// 1. A troop with a foe in its reach fights it from where it stands, and holds the spot of that foe on its
  ///    side (the one it walked to, if it did), when one is free.
  /// 2. A troop walking to a spot keeps it while the monster lives and the spot is still open and not held by a
  ///    fighter.
  /// 3. Everyone else, nearest to a foe first, takes the first free spot in [spotFill] order on the monster
  ///    nearest to it that has one (a taunted troop only its taunter's), else waits.
  /// 4. Two troops walking to spots of one monster swap them when that makes their walks shorter, so their
  ///    paths don't cross.
  void _assignSpots() {
    final melee = <Unit>[];
    for (final u in troops) {
      if (_seeksSpot(u)) {
        melee.add(u);
      } else {
        u
          ..spotOf = null
          ..spot = null
          ..waiting = false;
      }
    }
    if (melee.isEmpty) return;
    // Not a heap of bones (Reassemble): the troops pass it by.
    final foes = [for (final e in enemies) if (e.alive && e.entered && t >= e.downUntil) e]..sort((a, b) => a.pos.x.compareTo(b.pos.x));
    final taken = <Unit, Set<Spot>>{};
    Set<Spot> takenOf(Unit m) => taken.putIfAbsent(m, () => {});
    final fighters = <(Unit, Unit)>[], rest = <Unit>[];
    for (final u in melee) {
      if (u.spotOf case final m? when !m.alive || !m.entered || t < m.downUntil) {
        u
          ..spotOf = null
          ..spot = null;
      }
      final f = _nearestFoe(u);
      if (f != null && reaches(u, f)) {
        fighters.add((u, f));
      } else {
        rest.add(u);
      }
    }
    // 1. Fighters: the spot they walked to first, then the free spot of their foe nearest their side of it.
    final unplaced = <(Unit, Unit)>[];
    for (final (u, f) in fighters) {
      u.waiting = false;
      if (u.spotOf == f && u.spot != null && takenOf(f).add(u.spot!)) continue;
      unplaced.add((u, f));
    }
    for (final (u, f) in unplaced) {
      final rel = u.pos - f.pos;
      Spot? best;
      var bestDot = double.negativeInfinity;
      for (final s in Spot.values) {
        if (takenOf(f).contains(s)) continue;
        final d = rel.x * s.dir.x + rel.y * s.dir.y;
        if (d > bestDot) (best, bestDot) = (s, d);
      }
      u
        ..spotOf = f
        ..spot = best;
      if (best != null) takenOf(f).add(best);
    }
    // 2. Walkers keep an open spot nobody fighting holds.
    final seekers = <Unit>[];
    for (final u in rest) {
      final m = u.spotOf, s = u.spot;
      if (m != null && s != null && !takenOf(m).contains(s) && _spotOpen(u, m, s, foes)) {
        takenOf(m).add(s);
        u.waiting = false;
      } else {
        seekers.add(u);
      }
    }
    // 3. The others pick, nearest to a foe first.
    final near = {for (final u in seekers) u: _nearestFoe(u)};
    seekers.sort((a, b) => (near[a]?.pos.distanceTo(a.pos) ?? double.infinity).compareTo(near[b]?.pos.distanceTo(b.pos) ?? double.infinity));
    for (final u in seekers) {
      u
        ..spotOf = null
        ..spot = null
        ..waiting = near[u] != null;
      final taunter = u.effects.isEmpty ? null : _taunter(u);
      final order = taunter != null ? [taunter] : ([...foes]..sort((a, b) => a.pos.distanceTo(u.pos).compareTo(b.pos.distanceTo(u.pos))));
      for (final m in order) {
        if (_freeSpot(u, m, takenOf(m), foes) case final s?) {
          u
            ..spotOf = m
            ..spot = s
            ..waiting = false;
          takenOf(m).add(s);
          break;
        }
      }
    }
    // 4. No crossing walks to one monster's spots.
    final walking = <Unit, List<Unit>>{};
    for (final u in rest) {
      if (u.spotOf case final m? when u.spot != null) walking.putIfAbsent(m, () => []).add(u);
    }
    for (final MapEntry(key: m, value: us) in walking.entries) {
      for (var i = 0; i < us.length; i++) {
        for (var j = i + 1; j < us.length; j++) {
          final a = us[i], b = us[j], sa = a.spot!, sb = b.spot!;
          final now = a.pos.distanceTo(spotPoint(a, m, sa)) + b.pos.distanceTo(spotPoint(b, m, sb));
          final swapped = a.pos.distanceTo(spotPoint(a, m, sb)) + b.pos.distanceTo(spotPoint(b, m, sa));
          if (swapped < now - 1 && _spotOpen(a, m, sb, foes) && _spotOpen(b, m, sa, foes)) {
            a.spot = sb;
            b.spot = sa;
          }
        }
      }
    }
  }

  /// The first free, open spot of [m] for [u] in [spotFill] order (the nearer one within a row), or null.
  Spot? _freeSpot(Unit u, Unit m, Set<Spot> taken, List<Unit> foes) {
    for (final row in spotFill) {
      Spot? best;
      var bestD = double.infinity;
      for (final s in row) {
        if (taken.contains(s) || !_spotOpen(u, m, s, foes)) continue;
        final d = spotPoint(u, m, s).distanceTo(u.pos);
        if (d < bestD) (best, bestD) = (s, d);
      }
      if (best != null) return best;
    }
    return null;
  }

  /// Whether [u] can stand on spot [s] of [m]: on the field's rows, not behind the back line nor off the view's
  /// right edge, and not inside another monster's body. [foes]: the monsters on the field, by x.
  bool _spotOpen(Unit u, Unit m, Spot s, List<Unit> foes) {
    final p = spotPoint(u, m, s);
    if (p.y < 4 || p.y > fieldH - 2 || p.x < _rearEdge + Game.clearOfLine || p.x > cam + viewW - tile / 2) return false;
    // The first monster no further left than a body from p (the list is sorted by x).
    var lo = 0, hi = foes.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      foes[mid].pos.x < p.x - Game._personalSpace ? lo = mid + 1 : hi = mid;
    }
    for (var i = lo; i < foes.length && foes[i].pos.x <= p.x + Game._personalSpace; i++) {
      final o = foes[i];
      if (o != m && o.pos.distanceTo(p) < Game._personalSpace) return false;
    }
    return true;
  }

  /// Where melee troop [u], with no foe in its reach, walks now: to its spot (going round the monster, outside
  /// its reach, when the spot is on the far side), or to where it waits for one. Null: it has neither (it walks
  /// at its nearest foe, as before #84).
  Point<double>? _meleeGoal(Unit u) {
    if (u.spotOf case final m? when u.spot != null) return _spotWay(u, m, u.spot!);
    return u.waiting ? _waitPoint(u) : null;
  }

  /// The next point on [u]'s way to spot [s] of [m]: the spot itself once it is lined up with it (within
  /// [stepInAt], seen from [m]); else the point [orbitGap] outside its reach in line with the spot when that is
  /// within an eighth of a turn; else an eighth of a turn round [m] towards it at that distance (the roomier way
  /// when the spot is straight across, and never off the field).
  Point<double> _spotWay(Unit u, Unit m, Spot s) {
    final goal = spotPoint(u, m, s), rel = u.pos - m.pos;
    if (rel.magnitude < 0.01) return goal;
    final at = atan2(rel.y, rel.x);
    var turn = atan2(s.dy, s.dx) - at;
    while (turn > pi) {
      turn -= 2 * pi;
    }
    while (turn <= -pi) {
      turn += 2 * pi;
    }
    if (turn.abs() <= stepInAt) return goal;
    final r = u.stats.range + orbitGap;
    Point<double> onField(Point<double> p) => Point(p.x, p.y.clamp(4.0, fieldH - 2));
    if (turn.abs() <= pi / 4) return onField(m.pos + s.dir * r);
    // Straight across: round the side with more room (a monster in the upper half is gone round below).
    var way = (turn.abs() > pi - 0.01) ? (m.pos.y < fieldH / 2 ? (rel.x < 0 ? -1.0 : 1.0) : (rel.x < 0 ? 1.0 : -1.0)) : turn.sign;
    Point<double> step(double way) => m.pos + Point(cos(at + way * pi / 4), sin(at + way * pi / 4)) * r;
    bool offField(Point<double> p) => p.y < 4 || p.y > fieldH - 2;
    if (offField(step(way)) && !offField(step(-way))) way = -way; // no room between it and the field's edge
    return onField(step(way));
  }

  /// Where [u] waits with every spot taken: [waitBack] behind the front spot of the monster nearest to it,
  /// level with it within a tile.
  Point<double> _waitPoint(Unit u) {
    final f = _nearestFoe(u)!;
    return Point(f.pos.x - spotRing(u, f) - waitBack, u.pos.y.clamp(f.pos.y - tile, f.pos.y + tile));
  }
}

extension Meet on Game {
  /// The troop monster [u] goes for (#84): the nearest ([Game._nearestFoe], a taunter first), unless that one
  /// is out of its reach and its way there runs into another troop: a troop less than a body
  /// ([Game._personalSpace]) off the line to it, before it. It doesn't squeeze past a troop it meets to get at
  /// one behind it, it fights the first it would bump into. A troop further off its way leaves a real gap, and
  /// it walks on through. Under the Bayangan Vultures a monster of its ranks, with a troop in its reach and no taunt,
  /// goes for the most hurt troop it reaches instead ([Omens._omenVultures]).
  Unit? _monsterFoe(Unit u) {
    final foe = _nearestFoe(u);
    if (foe == null || (u.effects.isNotEmpty && _taunter(u) != null)) return foe;
    if (omensOn) {
      if (_omenVultures(u, foe) case final prey?) return prey; // Vultures (omen.dart)
    }
    final d = foe.pos - u.pos, len = d.magnitude;
    if (reaches(u, foe) || len < 0.01) return foe;
    final dir = d * (1 / len);
    Unit? first;
    var firstAlong = len;
    for (final o in units) {
      if (o.side == u.side || !o.alive || o == foe) continue;
      final rel = o.pos - u.pos, along = rel.x * dir.x + rel.y * dir.y;
      if (along <= 0 || along >= firstAlong || (dir.x * rel.y - dir.y * rel.x).abs() >= Game._personalSpace) continue;
      (first, firstAlong) = (o, along);
    }
    return first ?? foe;
  }

  /// Where monster [u], out of its reach of [foe], walks: to just inside its reach of it on its side, not to
  /// its centre. A step at the centre went into the troop's body (a melee monster's reach is the separation's
  /// [Game._personalSpace]), and the shove that parted them pushed the troop back; a hair out of reach, the
  /// monster stepped in again: it drove the troop back without a blow (#84). A shooter walks to its hold
  /// ([Engage.holdAt]), not to the edge of its reach.
  Point<double> _reachPoint(Unit u, Unit foe) {
    final d = u.pos - foe.pos, len = d.magnitude;
    return len < 0.01 ? foe.pos : foe.pos + d * ((holdAt(u) - spotSlack) / len);
  }

  /// Two monsters closer than [Game._personalSpace], neither held ([Game._firm]), one walking and one standing
  /// (it fights, or can't move): the walker takes the whole push and slides round the other, as a troop that
  /// gives way does, so a crowd doesn't shove its front ones on into the troops and past them (#84). Whether
  /// it applied.
  bool _slideRound(Unit a, Unit b, double len) {
    if (a.side != Side.enemy || b.side != Side.enemy || a.moving == b.moving || _firm(a) || _firm(b)) return false;
    final (w, s) = a.moving ? (a, b) : (b, a);
    final away = w.pos - s.pos, gap = Game._personalSpace - len;
    final dy = away.y.abs() > 0.5 ? away.y.sign : (w.pos.y < fieldH / 2 ? 1.0 : -1.0);
    w.pos += Point(away.x.abs() > 0.5 ? away.x.sign * gap / 2 : 0.0, dy * gap);
    return true;
  }
}
