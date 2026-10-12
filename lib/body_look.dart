part of 'main.dart';

// Where a troop is drawn, and how it walks there (decisions-log 307; the owner, 2026-10-09: "ini beberapakali aku liat
// para army di pindahnya tidak natural langsung kaya lompat gitu", then "ketika auto buy troops juga aneh banget tropsnya
// harusnya animasi jalan ini kaya slide gitu"). The game moves a troop in steps the eye can't follow: the separation
// hands a troop the whole gap to each neighbour in one tick (36 world px in a 16 ms tick on the owner's wave-30 save),
// make-way stepped it aside at its own speed once for each troop passing (one walk step a tick in all since
// decisions-log 309), and a frame cut short at 0.1 s carries a fast troop 0.1 s of walking at once. None of that
// changes here: the drawing never moves the game (its positions, its fights, the w89 identity). The Board draws each
// troop at a [_Body] of its own that follows the troop's game position:
// - at the pace the troop walks, and on top of that whatever else moved it (a shove, a step aside, a monster's
//   knockback or hook) at [bodyRun] × its type's base walk speed at the least, faster the further behind it is
//   ([bodyCatch]), never more in a frame than a 30 fps frame gives ([bodyFrame]): a jump plays out as a few quick
//   steps and a stalled frame as a short catch-up, a fast troop's (boots, a Hero's speed) as slowly as a slow one's
//   (decisions-log 310: on 3× its own walk a booted knight's shove was drawn at 315 a second, a Hero knight's at 825);
// - exactly where the game has it while it makes a move of its own or is thrown ([_drawnExact]: a leap, Skyfall,
//   Phantom Rush, a charge, a Lifeline lift: their own looks); a new troop or one back from the dead where it stands,
//   one moved to a cell between waves ([Board._bodiesPut]) or moved while the game stood still (paused) at once, and
//   a dying one where it was drawn; a gap of [bodySnap] or more (no move the eye could follow) at once too;
// - with the walk strip whenever the drawn body moves ([bodyWalkAt] of its walk speed or more, for [bodyWalkHold] s
//   after), over the idle, flinch and attack strips and a skill strip's tail; a skill's wind-up, a stun, a rise and a
//   brace keep theirs, and a troop attacking in place moves no body;
// - its stride as quick as the body goes against its type's base speed ([troopTypes]), 1× to [bodyStride]×, from a
//   phase of its own, so the steps neither skate nor skip.
// The whole render sees a troop at its body ([Board._bodiesOn]): its bars, rings, guards, labels, plates, the Hero's
// spotlight, the off-view marker. Taps, pointing and loot dropped on a troop find it there too ([Board._at]). A troop's
// plain shot leaves from its drawn body and closes onto the game's path by its target.

/// The least a drawn body closes a gap a second, against its type's base walk speed, on top of the pace the troop walks
/// at (so its own walk is followed exactly). Against the troop's own walk speed until decisions-log 310.
const bodyRun = 3.0;

/// How fast a drawn body closes a gap at the least: the gap over this many seconds.
const bodyCatch = 0.3;

/// The most game time a drawn body moves in one frame, real seconds × the game's speed: a 30 fps frame's.
const bodyFrame = 1 / 30;

/// A gap this wide (world units) or more is no move the eye could follow: the body is there at once. A troop put
/// somewhere (moved to a cell, paused, back from the dead) is there at once however near; 3 tiles until decisions-log
/// 310.
const bodySnap = 10 * tile;

/// A drawn body moving at this share of its troop's walk speed or more walks; for this many game seconds after it moved.
const bodyWalkAt = 0.25, bodyWalkHold = 0.12;

/// The quickest a walk strip plays, against its type's base pace: 6× its 10 frames a second is a strip frame every
/// frame of a 60 fps screen (3× until decisions-log 310). No troop walks faster since decisions-log 311 ([walkMost]: a
/// Hero knight walked 275 against its 24 and slid its feet); only a body closing a gap on top of its walk does.
const bodyStride = walkMost;

/// A troop's drawn body between frames: where it is drawn ([at]), where the game had it ([game], while the render sees
/// [at]), how fast it went this frame (world units a game second), until when it walks, and its walk strip's phase
/// (frames).
class _Body {
  _Body(this.at)
      : game = at,
        seen = at;
  math.Point<double> at, game, seen; // [seen]: where the game had it at the last step
  double speed = 0, walkUntil = double.negativeInfinity, stride = 0;
  bool wasAlive = true, wasExact = false; // [wasExact]: drawn where the game had it for a move of its own last frame
}

extension _BodyLook on Board {
  /// Where troop [u] is drawn: its body, or the game's position while it has none (a monster, a troop not yet stepped).
  math.Point<double> _at(Unit u) => _bodies[u]?.at ?? u.pos;

  /// Once a frame after the game's tick: every troop's body follows its game position ([_Body], the rules above).
  void _bodiesStep(Game g) {
    if (!identical(g, _bodiesFor)) {
      _bodiesFor = g; // another game came in: every body starts where its troop stands
      _bodies.clear();
      _bodiesT = g.t;
    }
    final gdt = g.t - _bodiesT, step = math.min(gdt, bodyFrame * speed);
    _bodiesT = g.t;
    _bodies.removeWhere((u, _) => !g.units.contains(u));
    for (final u in g.units) {
      if (u.side != Side.troop) continue;
      final b = _bodies[u];
      if (b == null) {
        _bodies[u] = _Body(u.pos); // a new troop: where it stands
        continue;
      }
      final from = b.at, back = u.alive && !b.wasAlive;
      b.wasAlive = u.alive;
      if (u.dying >= 0) {
        b.speed = 0; // its death plays where it was drawn
        continue;
      }
      final d = u.pos - from, gap = d.magnitude, put = gdt <= 0 && u.pos != b.seen; // moved while the game stood: put there
      b.seen = u.pos;
      final exact = _drawnExact(u.move), landed = b.wasExact; // the tick a move of its own ends: where it lands
      b.wasExact = exact;
      if (exact || landed || back || put || gap >= bodySnap) {
        b.at = u.pos; // its own move or a throw (their own looks), back from the dead, or put somewhere: there at once
      } else if (gap > 0 && step > 0) {
        final base = troopTypes[u.type]?.speed ?? u.stats.speed;
        final pace = (u.moving ? u.vel.magnitude : 0.0) + math.max(bodyRun * base, gap / bodyCatch);
        final go = math.min(gap, pace * step);
        b.at = go >= gap ? u.pos : from + d * (go / gap);
      }
      final moved = (b.at - from).magnitude;
      b.speed = gdt > 0 ? moved / gdt : 0;
      if (u.move == null && gdt > 0 && b.speed >= bodyWalkAt * u.walkSpeed) b.walkUntil = g.t + bodyWalkHold;
      if (gdt > 0 && (u.moving || g.t < b.walkUntil)) {
        final base = troopTypes[u.type]?.speed ?? u.stats.speed;
        b.stride += gdt * _fps * (b.speed / base).clamp(1.0, bodyStride);
      }
    }
  }

  /// Whether a troop's move [m] ([Unit.move]) is drawn exactly where the game has it: one of its own (a charge, a leap,
  /// Skyfall, Phantom Rush's dashes) or a throw with its arc (a Lifeline lift). A slide or a drag it doesn't make (a
  /// monster's knockback, a hook) is drawn as a shove is, its body following (decisions-log 310).
  bool _drawnExact(Move? m) => switch (m) {
    Charge() => true,
    Carry(:final lift, :final look) => lift > 0 || look != CarryLook.plain,
    null => false,
  };

  /// Troops [us], just put somewhere by the player (moved to a cell between waves, a swap): drawn there at once.
  void _bodiesPut(Iterable<Unit> us) {
    for (final u in us) {
      if (_bodies[u] case final b?) b.at = b.seen = u.pos;
    }
  }

  /// Whether troop [u]'s body walks now: it moves, or moved a moment ago ([bodyWalkAt], [bodyWalkHold]).
  bool _bodyWalks(Game g, Unit u) => switch (_bodies[u]) { final b? => g.t < b.walkUntil, null => false };

  /// The walk strip's frame for troop [u]: its body's stride ([bodyStride]); a monster's by the game clock.
  int _strideFrame(Game g, Unit u) => switch (_bodies[u]) { final b? => b.stride.floor(), null => (g.t * _fps).floor() };

  /// The render sees every troop at its body ([_Body.at]); [_bodiesOff] puts the game's positions back.
  void _bodiesOn() {
    for (final MapEntry(key: u, value: b) in _bodies.entries) {
      b.game = u.pos;
      u.pos = b.at;
    }
  }

  void _bodiesOff() {
    for (final MapEntry(key: u, value: b) in _bodies.entries) {
      u.pos = b.game;
    }
  }

  /// Where troop [from]'s plain shot is drawn: from its drawn body, closing onto the game's path ([sh] at [at]) by
  /// where it flies ([to]: its target, or the spot its target went from, [Shot.aim]), as the share of the way it has gone.
  Offset _shotFrom(Unit from, math.Point<double> at, math.Point<double> to) {
    final b = _bodies[from];
    if (b == null || from.side != Side.troop) return Offset(at.x, at.y);
    final lag = b.at - b.game, toShooter = at.distanceTo(b.game), toTarget = at.distanceTo(to);
    final k = toShooter + toTarget <= 0 ? 0.0 : toTarget / (toShooter + toTarget);
    return Offset(at.x + lag.x * k, at.y + lag.y * k);
  }
}
