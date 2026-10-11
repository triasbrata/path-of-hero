part of 'main.dart';

// How #48's special shots and ground objects look (docs/ui-hud.md); their rules are lib/hero_shots.dart.
// Every look is cut from the packs' sheets (decisions-log 173: the owner wants the packs' art, not shapes drawn in
// code), drawn without smoothing ([_sheetFrame], [_groundCircle]). A special shot ([Shot.look], [LineShot.look])
// is the archer's arrow drawn bigger, longer or tinted, or a frame of the thrower's hit burst spinning. A chain
// ([Game.beams]) is a jagged pale-blue line from foe to foe. A zone ([Game.zones]) lies on the ground under
// everyone: the pack's ground circle over its reach in its colour (the frost field's ice blue), the banner a red
// ribbon flag on a pole. The monsters' skills (#59) add a slime's glob (its hit burst's blob), its puddle (the
// circle in slime green, the slime's splats bubbling in it), arrows falling on a zone (drawn over everyone,
// [_zoneSkies]), a green draining beam, and rings bursting out on the ground ([Game.rings]: the summon circle's ring
// in the [_ringColors]). The troops' skills' own looks (#81: Arrow Rain's zone, Piercing
// Thrust's beam, the rings of their own shapes) are lib/skills.dart's; the loops here hand them over.

const _ice = Color(0xFF9BE3FF), _steel = Color(0xFF6E7A88), _boltGlow = Color(0xFF6CC8FF), _boltCore = Color(0xFFF4FBFF);

/// A [BeamLook.thunder] beam's glow and core (God's Thunder, the store's artefact).
const _thunderGlow = Color(0xFFFFD84A), _thunderCore = Color(0xFFFFFBE0);
const _pole = Color(0xFF6B4A2B), _poleH = 26.0;

/// A slime's green: Slime Tide's circle ([_slimeTint]).
const _slime = Color(0xFF7CD64A);

/// A draining beam's green glow and pale core ([BeamLook.drain]).
const _drainGlow = Color(0xFF4CE06A), _drainCore = Color(0xFFD8FFD0);

/// Each [RingLook]'s colour: a bursting ring's ([Game.rings], [_ringTints]) and a monster's guard ring's ([Unit.guardLook]).
const _ringColors = {
  RingLook.pale: Color(0xFFE8F4FF),
  RingLook.grey: Color(0xFF9AA0A6),
  RingLook.dark: Color(0xFF2B2233),
  RingLook.dust: Color(0xFFC8A878),
  RingLook.red: Color(0xFFFF4A3D),
  RingLook.orange: Color(0xFFFF8A30),
  RingLook.bone: Color(0xFFEDE3C8),
  RingLook.brown: Color(0xFF8B5A2B),
  RingLook.steel: Color(0xFFB0BEC5),
  RingLook.brace: _braceBlue, // the troops' skills' own (#81, skills.dart)
  RingLook.slash: _blade,
  RingLook.rage: _ember,
  RingLook.prayer: _mint,
  RingLook.pillar: _mint,
  RingLook.crack: _dust,
  RingLook.arcane: _violet,
  RingLook.holy: _holyWhite,
  RingLook.dome: _holyWhite,
  RingLook.shatter: _impaleLime, // the awakening skills' (#88, skills.dart): Impale's, Spellbreaker's, Singularity's
  RingLook.dispel: _silver,
  RingLook.implode: _indigo,
  RingLook.shards: _iron, // the awakening skills' (#88, skills.dart)
  RingLook.unchain: _unbrokenCyan,
  RingLook.crossCut: _rushMagenta,
  RingLook.crater: _ash,
  RingLook.bloom: _mint,
  RingLook.cleave: _cleaveRed, // the champions' landings (#59, skills.dart)
  RingLook.spin: _blade,
  RingLook.ward: _wardGrey,
};

/// [_ringColors] as tints ([_tint]) of the summon circle's ring, made once.
final _ringTints = {for (final MapEntry(:key, :value) in _ringColors.entries) key: _tint(value)};

/// The pack's ground circle (tiny_fx_summon.png): frame 0 its front half appearing, frame 1 the whole ring (the
/// rest draw the star in it); its ring is [_circleW] px wide, centred on [_circleMid] of the 100 px frame.
const _circleW = 32.0, _circleMid = Offset(52, 56.5);

/// How many times its size the ground circle is drawn to span a reach of [radius] (as the wind-up's circle is).
double _circleScale(double radius) => 2 * radius / _circleW;

/// The ground circle's ring is drawn scaled to a reach up to [_stretchMax] times its size: wider, its pixels would be
/// that many times the units' and read as noise over the fight (decisions-log 177), so [Board._reachRing] lays it round
/// the reach in [_dashes] dashes at the units' pixel size instead, each a [_dashW]-px square of the circle's own ring.
const _stretchMax = 2.0, _dashes = 20, _dashW = 4.0;

/// The ground circle's ring from its middle ([_circleMid]), in frame px: to its outer edge, and to the middle of its
/// two rows (the dark outline and the paler row inside it).
const _circleEdge = Offset(16, 6.5), _ringMid = Offset(15, 5.5);

/// The angle on the ring's ellipse ([_circleEdge]) a share [s] of the way round it by arc length, 0 at its right end
/// and on through the front, so the dashes lie evenly round it: [_ringArc]'s angles, [_arcSteps] equal steps apart.
double _ringAngle(double s) {
  final i = (s % 1.0) * _arcSteps, k = i.floor();
  return _ringArc[k] + (_ringArc[k + 1] - _ringArc[k]) * (i - k);
}

const _arcSteps = 64;
final _ringArc = () {
  const n = 1024; // the arc length summed over n even angles, then the angle at each equal share of it
  final along = <double>[0];
  for (var i = 0; i < n; i++) {
    final a = 2 * math.pi * (i + 0.5) / n, dx = _circleEdge.dx * math.sin(a), dy = _circleEdge.dy * math.cos(a);
    along.add(along.last + math.sqrt(dx * dx + dy * dy) * 2 * math.pi / n);
  }
  final angles = <double>[];
  var j = 0;
  for (var k = 0; k <= _arcSteps; k++) {
    final want = along.last * k / _arcSteps;
    while (j < n - 1 && along[j + 1] < want) {
      j++;
    }
    angles.add(2 * math.pi * (j + ((want - along[j]) / (along[j + 1] - along[j])).clamp(0.0, 1.0)) / n);
  }
  return angles;
}();

/// The [count] dashes [Board._reachRing] lays round a reach of [radius], [turn] turns on: each one's [_dashW]-px
/// square in the ground circle's frame (frame px, on its pixels, round the middle of the ring's two rows there) and
/// where it goes (world units from the ring's middle on the ground), the same size: its outer edge pushed out to the
/// reach.
List<(Rect, Rect)> reachDashes(double radius, {double turn = 0, int count = _dashes}) {
  final push = math.max(0.0, _circleScale(radius) - 1), dashes = <(Rect, Rect)>[];
  for (var i = 0; i < count; i++) {
    final a = _ringAngle(i / count + turn), x = math.cos(a), y = math.sin(a);
    final at = Offset((_circleMid.dx + x * _ringMid.dx - _dashW / 2).roundToDouble(), (_circleMid.dy + y * _ringMid.dy - _dashW / 2).roundToDouble());
    final to = at - _circleMid + Offset(x * _circleEdge.dx, y * _circleEdge.dy) * push;
    dashes.add((at & const Size(_dashW, _dashW), to & const Size(_dashW, _dashW)));
  }
  return dashes;
}

/// The ground circle's ring's length round its outer edge ([_circleEdge], Ramanujan's), in frame px.
final _ringLength = () {
  const a = 16.0, b = 6.5; // [_circleEdge]
  return math.pi * (3 * (a + b) - math.sqrt((3 * a + b) * (a + 3 * b)));
}();

/// How many dashes lie round a reach of [radius] [step] world units apart (each [_dashW] long): close together, a ring
/// that must read whole (a wind-up's reach, [Board._windCircle]); [_dashes] at least.
int closeDashes(double radius, double step) => math.max(_dashes, (_circleScale(radius) * _ringLength / step).ceil());

/// Rings and puddles lie flat on the ground: this much as tall as they are wide, like the rings at the units'
/// feet.
const _groundFlat = 0.45;

/// The ground circle's frame [since] s into a look that keeps it: its front half, the whole ring, then its star
/// (frames 2 to 6) over and over, [fps] frames a second.
int _circleFrame(double since, {double fps = _fps}) {
  final f = (since * fps).floor();
  return f < 2 ? f : 2 + (f - 2) % 5;
}

/// The ground circle's ring only: its front half for the first frame, then the whole ring.
int _ringFrame(double since) => since * _fps < 1 ? 0 : 1;

/// The zones' circles' colours: Slime Tide's slime green and Arrow Rain's pale blue (a troop's pop's, [_troopPop]) as
/// [_tint]s, Bone Rain's dark red on [_circleTint]'s ramp (a tint turns it brown on the road).
final _slimeTint = _tint(_slime), _boneRainTint = _circleTint(const Color(0xFFB03030)), _volleyTint = _tint(_troopPop);

/// Slime Tide's bubbles ([Board._slimeSplats]): one for every [_splatPer] world units of its radius, each [_splatTime] s.
const _splatPer = 12.0, _splatTime = 1.1;

/// Looks taking turns on zone [z]'s ground ([ground], [since] s in): one for every [per] world units of its radius (2
/// at least), each [time] s on a spot of its own within [out] of its radius, then on a new spot: (where, how far into
/// its time). The spots go round by the golden angle and out by the golden ratio, the same every time (no dice).
Iterable<(Offset, double)> _zoneTurns(Zone z, Offset ground, double since, double per, double time, double out) sync* {
  const angle = 2.399963, ratio = 0.618034;
  final n = math.max(2, (z.radius / per).round());
  for (var i = 0; i < n; i++) {
    final cycle = since / time + i / n, k = i + cycle.floor() * n;
    final ang = k * angle, r = math.sqrt((k * ratio) % 1.0) * z.radius * out;
    yield (ground + Offset(math.cos(ang) * r, math.sin(ang) * r * _groundFlat), cycle % 1.0);
  }
}

/// Bone Rain's arrows ([ZoneLook.arrowRain]): one for every [_rainPer] world units of the zone's radius, each
/// falling [_rainHigh] over [_rainFall] s, then standing in the ground until its next fall ([_rainEvery] s in
/// all).
const _rainPer = 5.0, _rainHigh = 40.0, _rainFall = 0.3, _rainEvery = 0.7;

/// Shots and bursts recoloured ice blue (crippleShot's arrow, the frost field) and steel grey (the spear).
final _iceTint = _tint(_ice);
final _icePaint = Paint()
  ..filterQuality = FilterQuality.none
  ..colorFilter = _iceTint;
final _steelPaint = Paint()
  ..filterQuality = FilterQuality.none
  ..colorFilter = _tint(_steel);

/// Spellbreaker's arrow ([ShotLook.silver], #88) recoloured cool silver.
final _silverPaint = Paint()
  ..filterQuality = FilterQuality.none
  ..colorFilter = _tint(_silver);

/// A spinning shot ([ShotLook.spin]): which frame of the hit burst, how big (world units) and how fast it
/// turns (turns a second).
const _spinFrame = 2, _spinSize = 22.0, _spinRate = 3.0;

/// How long a zone fades in and out (s): [_zoneFade], or a quarter of a short one's time ([_zoneFadeOf]).
const _zoneFade = 0.4;

double _zoneFadeOf(Zone z) => math.min(_zoneFade, (z.until - z.since) / 4);

extension on Board {
  /// A special shot of [who] at [at] (world), pointing [angle] (radians), drawn by its [look].
  void _specialShot(Canvas c, Game g, ShotLook look, String who, Offset at, double angle) {
    final level = g.awakenLevel(who);
    c.save();
    c.translate(at.dx, at.dy);
    if (look == ShotLook.glob) {
      // A slime's glob: its hit burst's blob (fx_hit_slime.png's first two frames, by turns), at the burst's size,
      // facing the way it flies.
      c.restore();
      _sheetFrame(c, 'fx_hit_slime.png', (g.t * _fxFps).floor() % 2, at, _burstSize, _px, flip: math.cos(angle) < 0);
      return;
    }
    if (look == ShotLook.spin) {
      final name = 'fx_hit_$who.png', fs = _img(name).height.toDouble();
      c.rotate(g.t * _spinRate * 2 * math.pi);
      c.scale(_spinSize / fs);
      _frame(c, name, _spinFrame, Offset.zero, anchor: Offset(fs / 2, fs / 2), paint: _awakeFx(level));
      c.restore();
      return;
    }
    // (length, thickness) against the plain arrow, and its paint.
    final (long, thick, paint) = switch (look) {
      ShotLook.trail => (1.5, 1.5, _awakeFx(level)),
      ShotLook.ice => (1.0, 1.0, _icePaint),
      ShotLook.long => (1.6, 1.0, _awakeFx(level)),
      ShotLook.spear => (1.6, 1.0, _steelPaint),
      ShotLook.silver => (1.3, 1.0, _silverPaint),
      ShotLook.plain || ShotLook.spin || ShotLook.glob => (1.0, 1.0, _awakeFx(level)),
    };
    c.rotate(angle);
    final arrow = 'tiny_arrow_${_arrows.contains(who) ? who : 'archer'}.png';
    c.drawImageRect(_img(arrow), const Rect.fromLTWH(0, 0, 32, 32),
        Rect.fromCenter(center: Offset.zero, width: 32 * long, height: 32 * thick), paint);
    c.restore();
  }

  /// The line shots in flight, a little above the ground their path runs on, pointing the way they go.
  void _lineShots(Canvas c, Game g) {
    for (final s in g.lineShots) {
      final to = s.heading, at = Offset(s.pos.x, s.pos.y - 6);
      final angle = to == s.pos ? math.atan2(s.dir.y, s.dir.x) : math.atan2(to.y - s.pos.y, to.x - s.pos.x);
      _specialShot(c, g, s.look, s.from.type, at, angle);
    }
  }

  /// The beams at body height: a chain's lightning and God's Thunder's leaps, a jagged line through their points
  /// re-jagged every 0.05 s, fading out, pale blue or yellow for [BeamLook.thunder]; a drain ([_drainBeam]);
  /// Piercing Thrust's streak ([_thrustBeam]).
  void _beams(Canvas c, Game g) {
    for (final b in g.beams) {
      final points = b.at;
      if (b.look == BeamLook.drain) {
        _drainBeam(c, g, b, points);
        continue;
      }
      if (b.look == BeamLook.lunge) {
        _lungeBeam(c, g, b); // Impale's lunge (skills.dart, #88)
        continue;
      }
      if (b.look == BeamLook.thrust) {
        _thrustBeam(c, g, b); // Piercing Thrust's streak (skills.dart)
        continue;
      }
      if (b.look == BeamLook.rush) {
        _rushBeam(c, g, b); // a Phantom Rush dash (skills.dart, #88)
        continue;
      }
      if (b.look == BeamLook.tether) {
        _tetherBeam(c, g, b); // Lifeline's ribbon (skills.dart, #88)
        continue;
      }
      final (glow, core) = b.look == BeamLook.thunder ? (_thunderGlow, _thunderCore) : (_boltGlow, _boltCore);
      final a = ((b.until - g.t) / (b.until - b.since)).clamp(0.0, 1.0);
      final dice = math.Random(identityHashCode(b) ^ (g.t * 20).floor()), path = Path();
      for (final (i, p) in points.indexed) {
        final at = Offset(p.x, p.y - 6);
        if (i == 0) {
          path.moveTo(at.dx, at.dy);
          continue;
        }
        final from = Offset(points[i - 1].x, points[i - 1].y - 6), d = at - from, n = math.max(2, (d.distance / 6).round());
        final side = d.distance > 0 ? Offset(-d.dy, d.dx) / d.distance : Offset.zero;
        for (var k = 1; k < n; k++) {
          final q = from + d * (k / n) + side * ((dice.nextDouble() * 2 - 1) * 2.5);
          path.lineTo(q.dx, q.dy);
        }
        path.lineTo(at.dx, at.dy);
      }
      c.drawPath(path, Paint()
        ..color = glow.withValues(alpha: 0.6 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeJoin = StrokeJoin.round);
      c.drawPath(path, Paint()
        ..color = core.withValues(alpha: a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeJoin = StrokeJoin.round);
    }
  }

  /// A drain ([BeamLook.drain]) through [points]: a green line waving gently along each leg (glow under a pale
  /// core), with motes flowing along it from the last point to the first, fading in over its first 0.15 s and
  /// out over its last 0.3 s.
  void _drainBeam(Canvas c, Game g, Beam b, List<math.Point<double>> points) {
    final a = math.min(1.0, math.min((g.t - b.since) / 0.15, (b.until - g.t) / 0.3)).clamp(0.0, 1.0);
    final path = Path(), legs = <(Offset, Offset)>[];
    for (var i = 1; i < points.length; i++) {
      final from = Offset(points[i - 1].x, points[i - 1].y - 6), to = Offset(points[i].x, points[i].y - 6), d = to - from;
      final side = d.distance > 0 ? Offset(-d.dy, d.dx) / d.distance : Offset.zero, n = math.max(4, (d.distance / 2).round());
      legs.add((from, to));
      if (i == 1) path.moveTo(from.dx, from.dy);
      for (var k = 1; k <= n; k++) {
        final f = k / n, q = from + d * f + side * (math.sin(f * d.distance / 5 - g.t * 9) * 1.4 * math.sin(f * math.pi));
        path.lineTo(q.dx, q.dy);
      }
    }
    c.drawPath(path, Paint()
      ..color = _drainGlow.withValues(alpha: 0.55 * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeJoin = StrokeJoin.round);
    c.drawPath(path, Paint()
      ..color = _drainCore.withValues(alpha: 0.9 * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeJoin = StrokeJoin.round);
    // The motes: four to a leg, each from its end to its start and round again.
    for (final (from, to) in legs) {
      for (var k = 0; k < 4; k++) {
        final f = 1 - ((g.t * 1.4 + k / 4) % 1.0);
        c.drawCircle(Offset.lerp(from, to, f)!, 1.3, Paint()..color = _drainCore.withValues(alpha: a * math.sin(f * math.pi)));
      }
    }
  }

  /// The zones on the ground, under everyone, fading in and out ([_zoneFadeOf]), their alpha in their paints (no
  /// layer): the pack's ground circle over the zone's reach ([_circleScale]; a ring only, wider than [_stretchMax]
  /// times its size, in dashes at the units' pixel size: [_reachRing]), its front half first, then the whole ring: the
  /// frost field's in ice blue with its star turning in it ([_circleFrame]), Slime Tide's in slime green
  /// with the slime's own splats bubbling up in it ([_slimeSplats]), Bone Rain's in dark red, Arrow Rain's in the
  /// troops' pale blue (the arrows falling on them: [_zoneSkies]); the banner a red ribbon flag on a pole. The
  /// awakening skills' draw their own (#88, skills.dart).
  void _groundZones(Canvas c, Game g) {
    for (final z in g.zones) {
      if (z.look == ZoneLook.consecrate) {
        _consecration(c, g, z);
        continue;
      }
      if (z.look == ZoneLook.singularity) {
        _singularityWell(c, g, z);
        continue;
      }
      final a = math.min(1.0, math.min(g.t - z.since, z.until - g.t) / _zoneFadeOf(z)).clamp(0.0, 1.0);
      if (a <= 0) continue;
      final ground = Offset(z.at.x, z.at.y + 5), since = g.t - z.since;
      switch (z.look) {
        case ZoneLook.frost:
          _groundCircle(c, ground, _circleScale(z.radius), _circleFrame(since), _sheetPaint(_iceTint, a));
        case ZoneLook.slime:
          _reachRing(c, ground, z.radius, _ringFrame(since), _sheetPaint(_slimeTint, a));
          _slimeSplats(c, z, ground, since, a);
        case ZoneLook.arrowRain:
          _reachRing(c, ground, z.radius, _ringFrame(since), _sheetPaint(_boneRainTint, 0.8 * a));
        case ZoneLook.volley:
          _reachRing(c, ground, z.radius, _ringFrame(since), _sheetPaint(_volleyTint, 0.8 * a));
        case ZoneLook.consecrate || ZoneLook.singularity:
          break; // drawn above
        case ZoneLook.banner:
          // A pole, and a red ribbon flag (2/3 of its sprite size) flying from its top.
          c.drawLine(ground, ground - const Offset(0, _poleH), Paint()
            ..color = _pole.withValues(alpha: a)
            ..strokeWidth = 1.5);
          final flag = Board._ribbonClosed(Board._ribRed);
          c.drawImageRect(_img('ui_book_marks.png'), flag,
              Rect.fromLTWH(ground.dx + 0.5, ground.dy - _poleH, flag.width * 2 / 3, flag.height * 2 / 3), _sheetPaint(null, a));
      }
    }
  }

  /// Slime Tide's puddle's bubbles: fx_hit_slime.png's whole burst (its blob swelling, then splattering) at the hit
  /// bursts' size, on spots of its own in the zone, taking turns ([_zoneTurns]).
  void _slimeSplats(Canvas c, Zone z, Offset ground, double since, double a) {
    const name = 'fx_hit_slime.png';
    final n = _frames(name);
    for (final (at, p) in _zoneTurns(z, ground, since, _splatPer, _splatTime, 0.6)) {
      _sheetFrame(c, name, math.min(n - 1, (p * n).floor()), at - const Offset(0, 4), _burstSize, _sheetPaint(null, a));
    }
  }

  /// What falls on the zones, drawn over everyone ([ZoneLook.arrowRain]'s arrows): each arrow drops
  /// [_rainHigh] onto a spot of its own in the zone over [_rainFall] s, points down and slanted, then stands
  /// in the ground, fading, until its next fall on a new spot ([_rainEvery] s in all); the arrows take turns.
  /// Arrow Rain's ([ZoneLook.volley]) fall once each ([_volleyArrows]).
  void _zoneSkies(Canvas c, Game g) {
    for (final z in g.zones) {
      if (z.look == ZoneLook.volley) _volleyArrows(c, g, z);
      if (z.look != ZoneLook.arrowRain) continue;
      final a = math.min(1.0, math.min(g.t - z.since, z.until - g.t) / _zoneFadeOf(z)).clamp(0.0, 1.0);
      final n = math.max(4, (z.radius / _rainPer).round()), since = g.t - z.since;
      for (var i = 0; i < n; i++) {
        final cycle = since / _rainEvery + i / n, p = (cycle % 1.0) * _rainEvery, spot = math.Random(i * 7919 + cycle.floor() * 104729);
        final ang = spot.nextDouble() * 2 * math.pi, r = math.sqrt(spot.nextDouble()) * z.radius * 0.9;
        final ground = Offset(z.at.x + math.cos(ang) * r, z.at.y + 5 + math.sin(ang) * r * _groundFlat);
        final fall = (p / _rainFall).clamp(0.0, 1.0), fade = p < _rainFall ? 1.0 : 1 - (p - _rainFall) / (_rainEvery - _rainFall);
        _fallingArrow(c, 'tiny_arrow_skeleton_archer.png', ground, fall, Paint()..color = Colors.white.withValues(alpha: a * fade));
      }
    }
  }

  /// An arrow [fall] of the way down from [_rainHigh] onto [ground], pointing down and slanted: its head (the
  /// middle of its 32 px frame, 8 px ahead of it) comes down to the spot.
  void _fallingArrow(Canvas c, String image, Offset ground, double fall, Paint paint) {
    final head = ground - Offset(4 * (1 - fall), _rainHigh * (1 - fall) + 2);
    c.save();
    c.translate(head.dx, head.dy);
    c.rotate(math.pi / 2 - 0.25);
    c.drawImageRect(_img(image), const Rect.fromLTWH(0, 0, 32, 32), Rect.fromCenter(center: const Offset(-8, 0), width: 32, height: 32), paint);
    c.restore();
  }

  /// The rings bursting out on the ground ([Game.rings]), under everyone: the pack's ground circle's ring
  /// (tiny_fx_summon.png) over its radius ([_reachRing]: wider than [_stretchMax] times the circle, in dashes at the
  /// units' pixel size) in its [_ringColors], its front half first, then the whole ring, fading. A troop skill's look puts its own on the ground first ([_skillGround]), in place of this one
  /// or under it.
  void _groundRings(Canvas c, Game g) {
    for (final r in g.rings) {
      if (_skillGround(c, g, r)) continue;
      final p = ((g.t - r.since) / (r.until - r.since)).clamp(0.0, 1.0);
      _reachRing(c, Offset(r.centre.x, r.centre.y + 5), r.radius, p < 0.15 ? 0 : 1, Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = _ringTints[r.look]
        ..color = Colors.white.withValues(alpha: 0.95 * (1 - p)));
    }
  }

  /// Frame [f] of the pack's ground circle (tiny_fx_summon.png) centred on [ground], [k] times its size.
  void _groundCircle(Canvas c, Offset ground, double k, int f, Paint paint) {
    c.save();
    c.translate(ground.dx, ground.dy);
    c.scale(k);
    _frame(c, 'tiny_fx_summon.png', f, Offset.zero, anchor: _circleMid, paint: paint);
    c.restore();
  }

  /// The ground circle's ring (tiny_fx_summon.png's frame [f]: 0 its front half, 1 the whole ring) round a reach of
  /// [radius] on [ground] in [paint]. Up to [_stretchMax] times the circle's size it is the frame scaled to the reach
  /// ([_groundCircle]). Wider, or [dashed], its pixels stay the units' (1 world unit a sprite px): [_dashes] dashes lie
  /// evenly round the reach, [turn] turns on, each the [_dashW]-px square of the circle's own ring at that point of the
  /// way round, pushed out to the reach (decisions-log 177); [count] of them for a ring that must read whole
  /// ([closeDashes]).
  void _reachRing(Canvas c, Offset ground, double radius, int f, Paint paint, {double turn = 0, bool dashed = false, int count = _dashes}) {
    final k = _circleScale(radius);
    if (!dashed && k <= _stretchMax) {
      _groundCircle(c, ground, k, f, paint);
      return;
    }
    final img = _img('tiny_fx_summon.png'), fs = img.height.toDouble();
    for (final (from, to) in reachDashes(radius, turn: turn, count: count)) {
      c.drawImageRect(img, from.shift(Offset(f * fs, 0)), to.shift(ground), paint);
    }
  }

  /// Frame [f] of fx sheet [name] centred on [at], its frame [size] world units tall (a hit burst's [_burstSize]),
  /// mirrored with [flip].
  void _sheetFrame(Canvas c, String name, int f, Offset at, double size, Paint paint, {bool flip = false}) {
    final fs = _img(name).height.toDouble();
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(size / fs);
    _frame(c, name, f, Offset.zero, anchor: Offset(fs / 2, fs / 2), flip: flip, paint: paint);
    c.restore();
  }
}
