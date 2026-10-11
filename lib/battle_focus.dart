part of 'game.dart';

// The battle point (#85; the owner: "center cam adalah battle field. battle field adalah titik pertemuan antara
// troops dengan enemy"): the view's centre ([Game.viewMid]) goes where the troops and the monsters actually hit
// each other, the heaviest group of contact midpoints ([BattleFocus.fights]). Before the sides touch it slides
// with our front line ([BattleFocus.troopFront]); it holds through lulls and the cheer, and never moves faster
// than [focusSpeed].

/// A unit is in contact while its nearest foe is within its reach + [contactSlack]. A shooter's contact point
/// weighs [contactRanged] (melee 1). Melee points more than [fightGap] apart are separate fights; a fight
/// counts from [minFight] (one melee pair, or 4 shooters).
const contactSlack = tile / 2, contactRanged = 0.5, fightGap = 3 * tile, minFight = 2.0;

/// A contact point is the midpoint of the pair, but never more than this from the foe: a long reach (bows
/// stack ×1.2 each, and late armies shot from 15–20 tiles before the long range's hold, [Engage.holdAt]) would
/// otherwise pull the fight's centre back off the line where they meet, and push the melee against the right edge. A
/// base archer's or wizard's point (reach + slack ≤ 80) is the plain midpoint.
const reachPull = 2.5 * tile;

/// The fight shown is kept until a rival weighs [switchRatio] times as much for [switchHold] s; after the last
/// contact the battle point holds [contactGrace] s before it goes back to following the front.
const switchRatio = 1.5, switchHold = 0.75, contactGrace = 1.0;

/// The troop front: the [frontTrim] quantile from the front, never more than [frontGap] ahead of the next troop
/// behind it. Before contact the aim leads it by at most [approachLead]; with no contact the front stays
/// [frontIn] inside both edges of the view.
const frontTrim = 0.25, frontGap = 2 * tile, approachLead = tile, frontIn = 3 * tile;

/// Mid-wave the view's centre ignores moves under [focusSlack] and never goes faster than [focusSpeed] (also in
/// the glide back after a win); [Game.cam] eases after it at [camEase]. A monster never spawns less than
/// [spawnClear] ahead of the foremost troop.
const focusSlack = tile / 2, focusSpeed = 6 * tile, camEase = 2.5, spawnClear = 4 * tile;

/// The rules the view bounds were tuned under a view about 1.5 tiles ahead of the fight: before #85 its centre
/// was halfway between the foremost troop and the nearest monster, and the foremost troop leads the clash. On a
/// view centred on the fight they sat that much nearer our rear: monsters spawned closer and the supports hung
/// further back, and 16% more troops fell a wave, from the same saved armies. So a monster spawns [spawnLead]
/// further past the right edge, and once the wave has shown a fight the supports' keep-up floor
/// ([Game._rearEdge]) and the catch-up trigger ([Game.speedTo]) sit [keepUpInset] inside the left edge
/// ([BattleFocus.keepUpShift]). Before that the old view was the rest view, further back than the approach's,
/// so the floor stays at the edge (decisions-log 123).
const spawnLead = 2 * tile, keepUpInset = 2 * tile;

/// The owner's two open choices (the spec's §10), each one change away:
/// - before the sides touch, the view slides with our front line, a tile left of centre (true), or goes straight
///   to where they are predicted to meet (false: part of the army off the left edge);
/// - with two fights at once, the view shows the bigger one ([FightPick.bigger]) or the front-most.
const approachFollowsFront = true;
const fightPick = FightPick.bigger;

enum FightPick { bigger, frontMost }

/// A contact's weight by the rank of the monster in it: a boss clash outweighs a stray pair.
double tierWeight(Tier t) => switch (t) {
      Tier.normal => 1.0,
      Tier.elite => 1.25,
      Tier.highElite => 1.5,
      Tier.miniBoss => 2.0,
      Tier.boss => 3.0,
    };

/// What the battle point is doing ([Game.meetMode]): between waves ([rest]); centring a fight ([contact]);
/// sliding with the front toward the next meeting ([approach]); following the army after monsters all behind
/// its front ([chase]); or holding still ([hold]: a pair parted a moment, no monster alive, no troop entered).
enum MeetMode { rest, approach, contact, hold, chase }

/// A unit in contact: the midpoint x [p] with its nearest foe, its weight [w], the foe's x [fx], whether it
/// shoots ([ranged]), and its id.
typedef ContactPoint = ({double p, double w, double fx, bool ranged, int id});

/// A group of contact points: their weighted mean x, their total weight, and the span of its melee points.
typedef Fight = ({double x, double w, double lo, double hi});

extension BattleFocus on Game {
  /// On the field for the battle point: alive, not in a hop's air or a charge, a troop only once entered. A
  /// monster counts whether or not it has entered: the camera never reads a flag the camera sets.
  bool _inBattle(Unit u) => u.alive && !_passesThrough(u) && (u.side == Side.enemy || u.entered);

  /// Every non-healer in battle whose nearest foe in battle (healers included; a tie to the lower id) is within
  /// its reach + [contactSlack] marks the midpoint x of the two (at most [reachPull] from the foe), weighted
  /// [contactRanged] for a shooter and by the [tierWeight] of the pair's monster. Each side is sorted by x once, and only foes within reach in x
  /// are looked at.
  List<ContactPoint> get contactPoints {
    final mine = <Unit>[], theirs = <Unit>[];
    for (final u in units) {
      if (_inBattle(u)) (u.side == Side.troop ? mine : theirs).add(u);
    }
    int byX(Unit a, Unit b) => a.pos.x != b.pos.x ? a.pos.x.compareTo(b.pos.x) : a.id.compareTo(b.id);
    mine.sort(byX);
    theirs.sort(byX);
    final pts = <ContactPoint>[];
    void mark(List<Unit> us, List<Unit> foes) {
      for (final u in us) {
        if (u.stats.heals) continue;
        final reach = u.stats.range + contactSlack;
        var i = 0, j = foes.length; // the first foe no further left than reach
        while (i < j) {
          final k = (i + j) >> 1;
          if (foes[k].pos.x < u.pos.x - reach) {
            i = k + 1;
          } else {
            j = k;
          }
        }
        Unit? near;
        var nearD = double.infinity;
        for (; i < foes.length && foes[i].pos.x <= u.pos.x + reach; i++) {
          final o = foes[i], d = o.pos.distanceTo(u.pos);
          if (d < nearD || (d == nearD && o.id < near!.id)) (near, nearD) = (o, d);
        }
        if (near == null || nearD > reach) continue;
        final shooter = u.stats.shotSpeed > 0, monster = u.side == Side.enemy ? u : near;
        pts.add((
          p: near.pos.x + ((u.pos.x - near.pos.x) / 2).clamp(-reachPull, reachPull),
          w: (shooter ? contactRanged : 1.0) * tierWeight(monster.tier),
          fx: near.pos.x,
          ranged: shooter,
          id: u.id,
        ));
      }
    }

    mark(mine, theirs);
    mark(theirs, mine);
    return pts;
  }

  /// The fights [pts] make, sorted by their span's left end. Melee points sorted by x are chained: a gap over
  /// [fightGap] starts a new fight, whose span comes from its melee points only. A shooter joins the fight
  /// whose span is nearest its target's x when within [fightGap] (a tie to the lower span), so shooters never
  /// chain two fights; the rest are chained among themselves into fights of shooters only.
  static List<Fight> fightsOf(List<ContactPoint> pts) {
    int byP(ContactPoint a, ContactPoint b) => a.p != b.p ? a.p.compareTo(b.p) : a.id.compareTo(b.id);
    List<List<ContactPoint>> chain(Iterable<ContactPoint> ps) {
      final groups = <List<ContactPoint>>[];
      for (final q in ps.toList()..sort(byP)) {
        if (groups.isEmpty || q.p - groups.last.last.p > fightGap) {
          groups.add([q]);
        } else {
          groups.last.add(q);
        }
      }
      return groups;
    }

    final melee = chain(pts.where((q) => !q.ranged));
    final spans = [for (final g in melee) (lo: g.first.p, hi: g.last.p)];
    final loose = <ContactPoint>[];
    for (final q in pts.where((q) => q.ranged).toList()..sort(byP)) {
      var best = -1, bestD = double.infinity;
      for (var i = 0; i < spans.length; i++) {
        final d = max(0.0, max(spans[i].lo - q.fx, q.fx - spans[i].hi));
        if (d < bestD) (best, bestD) = (i, d);
      }
      if (best >= 0 && bestD <= fightGap) {
        melee[best].add(q);
      } else {
        loose.add(q);
      }
    }
    Fight fight(List<ContactPoint> g, double lo, double hi) {
      var w = 0.0, wp = 0.0;
      for (final q in g) {
        w += q.w;
        wp += q.w * q.p;
      }
      return (x: wp / w, w: w, lo: lo, hi: hi);
    }

    return [
      for (var i = 0; i < melee.length; i++) fight(melee[i], spans[i].lo, spans[i].hi),
      for (final g in chain(loose)) fight(g, g.first.p, g.last.p),
    ]..sort((a, b) => a.lo.compareTo(b.lo));
  }

  /// This tick's fights ([fightsOf] of [contactPoints]).
  List<Fight> get fights => fightsOf(contactPoints);

  /// The troops that make the front: alive, entered, not healers, not falling back, not in a hop's air or a
  /// charge, and not still joining ([Unit.joining]); failing that, joining ones too; failing that, everyone
  /// alive and entered.
  List<Unit> get _troopBody {
    bool fighter(Unit u) => u.alive && u.entered && !u.stats.heals && !u.retreating && !_passesThrough(u);
    final settled = [for (final u in troops) if (fighter(u) && !u.joining) u];
    if (settled.isNotEmpty) return settled;
    final all = [for (final u in troops) if (fighter(u)) u];
    return all.isNotEmpty ? all : [for (final u in troops) if (u.alive && u.entered) u];
  }

  /// The front of [body]: the [frontTrim] quantile of their x from the front, never more than [frontGap] ahead
  /// of the next one behind it, so one runner doesn't drag it along. Null for nobody.
  static double? frontOf(List<Unit> body) {
    if (body.isEmpty) return null;
    final xs = [for (final u in body) u.pos.x]..sort((a, b) => b.compareTo(a));
    if (xs.length == 1) return xs.first;
    final p = (xs.length - 1) * frontTrim, i = p.floor(), f = p - i;
    return min(xs[i] + (xs[i + 1] - xs[i]) * f, xs[i + 1] + frontGap);
  }

  /// The troop front now ([frontOf] the troops that make it); null with no troop entered.
  double? get troopFront => frontOf(_troopBody);

  /// Where to aim with no fight on, the front at [ft] ([body] makes it; the view's centre now at [viewNow]).
  /// Sets [Game.meetMode]; null with no monster alive.
  /// - The monsters: alive, not in the air, not healers (failing that, with healers; failing that, all alive).
  /// - One at or ahead of the front: [MeetMode.approach], toward the one that meets the front first at their
  ///   stat speeds (a tie to the nearer, then the lower id). Already in reach of each other, their contact point;
  ///   else the pair's contact point at first contact (it stays put while both walk), no more than [approachLead]
  ///   ahead of the front unless the view already sits further on ([approachFollowsFront]).
  /// - All behind the front: [MeetMode.chase], the midpoint of the closest troop-monster pair in x.
  double? _approach(List<Unit> body, double ft, double viewNow) {
    var foes = [for (final m in enemies) if (m.alive && !_passesThrough(m) && !m.stats.heals) m];
    if (foes.isEmpty) foes = [for (final m in enemies) if (m.alive && !_passesThrough(m)) m];
    if (foes.isEmpty) foes = [for (final m in enemies) if (m.alive) m];
    if (foes.isEmpty) return null;
    final ahead = [for (final m in foes) if (m.pos.x >= ft) m];
    if (ahead.isEmpty) {
      meetMode = MeetMode.chase;
      (Unit, Unit)? pair;
      var gap = double.infinity;
      for (final u in body) {
        for (final m in foes) {
          final d = (m.pos.x - u.pos.x).abs();
          final (pu, pm) = pair ?? (u, m);
          final better = d < gap ||
              (d == gap && (m.pos.x > pm.pos.x || (m.pos.x == pm.pos.x && (u.id < pu.id || (u.id == pu.id && m.id < pm.id)))));
          if (better) (pair, gap) = ((u, m), d);
        }
      }
      return (pair!.$1.pos.x + pair.$2.pos.x) / 2;
    }
    meetMode = MeetMode.approach;
    // The front's own unit: the one nearest the front (a tie to the one further on, then the lower id).
    var lead = body.first;
    for (final u in body.skip(1)) {
      final d = (u.pos.x - ft).abs(), dl = (lead.pos.x - ft).abs();
      if (d < dl || (d == dl && (u.pos.x > lead.pos.x || (u.pos.x == lead.pos.x && u.id < lead.id)))) lead = u;
    }
    final vu = lead.stats.heals ? 0.0 : lead.walkSpeed; // a troop's capped ([walkCap])
    double reach(Unit m) => max(lead.stats.heals ? 0.0 : lead.stats.range, m.stats.range) + contactSlack;
    double tau(Unit m) {
      final gap = max(0.0, m.pos.x - ft - reach(m)), v = vu + m.stats.speed;
      return gap == 0 ? 0 : (v > 0 ? gap / v : double.infinity);
    }

    var next = ahead.first, nextTau = tau(next);
    for (final m in ahead.skip(1)) {
      final tm = tau(m);
      if (tm < nextTau || (tm == nextTau && (m.pos.x < next.pos.x || (m.pos.x == next.pos.x && m.id < next.id)))) (next, nextTau) = (m, tm);
    }
    // The contact point is [reachPull] at most from the monster, as in [contactPoints].
    final g = next.pos.x - ft, r = reach(next);
    if (g <= r) return next.pos.x - min(g / 2, reachPull);
    final v = vu + next.stats.speed, s = v > 0 ? vu / v : 0.5;
    final meet = ft + (g - r) * s + max(r / 2, r - reachPull);
    return approachFollowsFront ? min(meet, max(ft + approachLead, viewNow)) : meet;
  }

  /// Which of the [valid] fights to show ([fightPick]); [ref] is where the view aims now. The one shown
  /// (the fight whose span, padded by half a [fightGap], holds [Game.meetX]; the nearest of several) is kept
  /// until another has out-ranked it for [switchHold] s without a break: [switchRatio] times as heavy, or
  /// further forward.
  Fight _pickFight(List<Fight> valid, double ref) {
    int? inc;
    if (meetX case final m?) {
      for (var i = 0; i < valid.length; i++) {
        final f = valid[i];
        if (m < f.lo - fightGap / 2 || m > f.hi + fightGap / 2) continue;
        if (inc == null || (f.x - m).abs() < (valid[inc].x - m).abs()) inc = i; // sorted by lo: a tie keeps the lower
      }
    }
    var best = 0;
    for (var i = 1; i < valid.length; i++) {
      final (f, b) = (valid[i], valid[best]);
      final ahead = switch (fightPick) {
        FightPick.bigger => f.w > b.w ||
            (f.w == b.w && ((f.x - ref).abs() < (b.x - ref).abs() || ((f.x - ref).abs() == (b.x - ref).abs() && f.x > b.x))),
        FightPick.frontMost => f.x > b.x || (f.x == b.x && f.w > b.w),
      };
      if (ahead) best = i;
    }
    if (inc == null) {
      _rivalSince = null;
      return valid[best];
    }
    final rival = best != inc && (fightPick == FightPick.frontMost || valid[best].w >= switchRatio * valid[inc].w);
    if (!rival) {
      _rivalSince = null;
      return valid[inc];
    }
    _rivalSince ??= t;
    if (t - _rivalSince! < switchHold) return valid[inc];
    _rivalSince = null;
    return valid[best];
  }

  /// Sets [Game.meetX], where the view's centre heads, once a tick mid-wave (tests call it directly). In order:
  /// the fight shown ([_pickFight]); held for [contactGrace] after the last contact; held with no troop
  /// entered; else [_approach] (held with no monster alive). Without a fight it is kept where the troop front
  /// stays [frontIn] inside both edges of the view.
  void aim() {
    if (wave != _aimWave) {
      _aimWave = wave;
      meetX = fightX = _rivalSince = null;
      _contactAt = double.negativeInfinity;
    }
    final viewNow = viewMid.isNaN ? _restMid : viewMid;
    // A troop bought mid-wave counts for the front once it fights, or has come up to the others' front.
    final others = frontOf([
      for (final u in troops)
        if (u.alive && u.entered && !u.stats.heals && !u.retreating && !_passesThrough(u) && !u.joining) u
    ]);
    for (final u in troops) {
      if (u.joining && (_inFight(u) || (others != null && u.pos.x >= others - frontGap))) u.joining = false;
    }
    final valid = [for (final f in fights) if (f.w >= minFight) f];
    if (valid.isNotEmpty) {
      meetX = fightX = _pickFight(valid, meetX ?? viewNow).x;
      meetMode = MeetMode.contact;
      _contactAt = t;
      return;
    }
    _rivalSince = null;
    final body = _troopBody;
    if (body.isEmpty) {
      meetMode = MeetMode.hold; // only troops still marching in: hold, never back to the line
      return;
    }
    final ft = frontOf(body)!;
    double x;
    if (meetX != null && t - _contactAt < contactGrace) {
      meetMode = MeetMode.hold; // a pair parted a moment (a knockback, a hop, a charge)
      x = meetX!;
    } else if (_approach(body, ft, viewNow) case final a?) {
      x = a;
    } else {
      meetMode = MeetMode.hold; // no monster alive: between spawns, or the last one dying
      x = meetX ?? viewNow;
    }
    final lo = ft - viewW / 2 + frontIn, hi = ft + viewW / 2 - frontIn;
    meetX = lo <= hi ? x.clamp(lo, hi) : ft;
  }

  /// The view's centre between waves: the back line at the left edge, or further on when the front troop would
  /// walk off the right one.
  double get _restMid {
    final xs = [for (final u in troops) if (u.alive && u.entered) u.pos.x];
    return (xs.isEmpty ? baseX : max(baseX, xs.reduce(max) + 2 * tile - viewW)) + viewW / 2;
  }

  /// Where the view's centre heads now: mid-wave the battle point ([aim]); for [victoryTime] after a win where
  /// they fought (the cheer); else the rest view ([_restMid]).
  double get viewGoal {
    if (waveActive) return meetX ?? (viewMid.isNaN ? _restMid : viewMid);
    if (!viewMid.isNaN && t - victoryAt < victoryTime) return viewMid;
    return _restMid;
  }

  /// Each tick after the moves and the shoves: [Game.viewMid] goes after [viewGoal], mid-wave and in the one
  /// glide back after a win at most [focusSpeed] (mid-wave ignoring moves under [focusSlack]); setting up
  /// between waves (and on a new game or a load) straight there. [Game.cam] eases after it.
  void _aimView(double dt) {
    if (_wasActive && !waveActive) {
      _gliding = true; // the glide back to the rest view, once the cheer is over
      for (final u in troops) {
        u.joining = false;
      }
    }
    _wasActive = waveActive;
    if (waveActive) {
      aim();
    } else {
      meetMode = MeetMode.rest;
    }
    final goal = viewGoal;
    if (viewMid.isNaN || !(waveActive || _gliding)) {
      viewMid = goal;
    } else {
      final d = goal - viewMid, slack = waveActive ? focusSlack : 0.0, step = d.abs() - slack;
      if (step > 0) viewMid = step <= focusSpeed * dt ? goal - d.sign * slack : viewMid + d.sign * focusSpeed * dt;
      if (!waveActive && t - victoryAt >= victoryTime && viewMid == goal) _gliding = false;
    }
    cam += (viewMid - viewW / 2 - cam) * min(1.0, dt * camEase);
  }

  /// How far inside the view's left edge the keep-up floor and the catch-up trigger sit: [keepUpInset] mid-wave
  /// from the wave's first fight shown ([Game.fightX]) on, else none.
  double get keepUpShift => waveActive && _aimWave == wave && fightX != null ? keepUpInset : 0.0;

  /// Where a monster comes on: [spawnLead] past the view's right edge (+8), and never less than [spawnClear] ahead
  /// of the foremost troop (the view may hold a fight behind a troop that ran on).
  double get spawnX => max(cam + viewW + 8 + spawnLead,
      troops.where((o) => o.alive && o.entered).fold(double.negativeInfinity, (x, o) => max(x, o.pos.x)) + spawnClear);
}
