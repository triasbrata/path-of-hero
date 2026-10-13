part of 'game.dart';

// The Dungeon (decisions-log 336, 337; docs/dungeon-design.md): a mode entered from a Town where a party of up to three
// of the army's troops walks a side-view cave floor and fights in real time. It runs inside the run's own [Game]
// while it lasts ([Game.dungeon] non-null): the army's units, the Shadows, the Tavern's and the pocket's boosts and the
// oath are set aside, the party (copies of the picked troops, so the army is never touched) and the floor's monsters
// are [Game.units], and [Game.tick] hands every tick to [DungeonTrip._dungeonTick] instead of the waves. The fight
// shares the field's blows and shots ([Game._strike], [Game._hurt], the shots' flight), its relics and statuses; the
// decisions (who, where, when) are the Dungeon's own: each unit's gauge, the action given with its target, the 75%
// rule, the gambits, the monsters' temper, aggro and leash.
//
// M1 (decisions-log 337): floor 1 only, Attack (and the healer's Heal) only, Wait only (the UI stops the tick while the
// Action chain is open), the arrival save point offers Leave, the portal at the end goes back to the Town ("Floor
// cleared"), a wipe goes back too ("The party fell"). No loot, no mid-trip save (a save made during a trip writes the
// game as it was at the door: [Game.toJson]), no monster skills.

/// How a trip ended ([Game.tripNews]).
enum TripEnd { left, cleared, fell }

/// What an action does: an Attack (a healer's is its holy smite), the healer's Heal on an ally, Follow (none: back to
/// the leader).
enum ActKind { attack, heal, follow }

/// An action given to a unit with its [target]: by the player ([byPlayer]) or by its gambit [rule] (the rule's index).
class Act {
  Act(this.kind, this.target, {this.byPlayer = false, this.rule});
  final ActKind kind;
  final Unit? target;
  final bool byPlayer;
  final int? rule;
  bool get byGambit => rule != null;

  /// The same action on the same target.
  bool same(Act? o) => o != null && o.kind == kind && o.target == target;
}

/// A unit's own state in the Dungeon ([Dungeon.minds]), party member or monster. Not saved (a trip isn't, in M1).
class Mind {
  Mind({this.home = const Point(0, 0), this.room = -1});

  /// The gauge, 0 (just acted) .. 1 (full): it fills over the unit's turn time ([DungeonTrip.turnOf]), and may run a
  /// tick's share past 1, which the next turn keeps. [shown] is what the HUD draws.
  double gauge = 0;
  bool get full => gauge >= 1 - 1e-9;
  double get shown => min(1.0, gauge);

  /// The action being done (walked to, fired when full and in reach) and the one queued behind it (the 75% rule's one
  /// slot); the last one fired (a gambit's same rule keeps its target).
  Act? act, queued, last;

  /// When its action's target was lost ("target lost" shows in its row for [lostFor] s).
  double lostAt = double.negativeInfinity;

  /// When its gambits are read again (every [gambitEvery] s under [queueAt] of its gauge).
  double readAt = double.negativeInfinity;

  /// An Attack's second blow: on whom, when, and its share of the damage.
  Unit? blowOn;
  double blowAt = double.infinity, blowK = 0;

  /// Its path: the points left to walk, when it was asked and to where.
  List<Point<double>> path = const [];
  double pathAt = double.negativeInfinity;
  Point<double>? pathTo;

  /// A follower walking back to its spot (it starts past [followSlack], stops close to it).
  bool following = false;

  /// A party member knocked out: it lies where it fell until the trip ends (a Rest revives, M3).
  bool down = false;

  /// A monster: where it appeared (home), its room, its temper (aggressive: attacks on sight within [aggro]), hostile
  /// to the party now, walking home after giving up (mending), the member it goes for and the one that hit it last,
  /// and the last time it reached anyone (or was hit).
  Point<double> home;
  final int room;
  bool aggressive = false, hostile = false, homing = false;
  double aggro = 0;
  Unit? prey, hitBy;
  double reachedAt = double.negativeInfinity;
}

/// Turn time = 2 × the unit's attack time, at least this (s).
const turnMin = 1.0;

/// At this share of its gauge or more a new action is queued behind the current one; under it, it replaces it.
const queueAt = 0.75;

/// Gambits are read again this often (s) while the gauge is under [queueAt].
const gambitEvery = 0.5;

/// "target lost" shows this long (s).
const lostFor = 1.2;

/// An Attack's second blow comes this long (s) after the first, at most a quarter of the turn.
const blowGap = 0.25;

/// A follower's spot behind the leader: melee this far, long range and healers [followFar]; spread [followSpread]
/// apart in depth. Past [followSlack] from its spot it walks there; past [followSnap] from the leader it is put beside
/// it; it never chases a foe more than [chaseCap] from the leader.
const followMelee = 24.0, followFar = (44.0, 52.0), followSpread = 20.0, followSlack = 32.0, followSnap = 400.0, chaseCap = 160.0;

/// Foes the gambits see: within this of the leader.
const sight = 280.0;

/// The monsters' temper (the design's section 5): the aggressive types and their aggro radius; the neutral types (the
/// rest of the roster) attack only once hit, and these call their kind within [kinCall] when one is.
const aggroRadius = {
  'bat': 72.0,
  'skeleton': 96.0,
  'skeleton_archer': 128.0,
  'werewolf': 128.0,
  'armored_skeleton': 80.0,
  'orc_rider': 128.0,
  'greatsword_skeleton': 96.0,
  boss: 160.0,
};
const callsKin = {'orc', 'elite_orc', 'armored_orc'}, kinCall = 96.0;

/// A hostile monster gives up past [leash] from home or after [giveUpAfter] s without reaching anyone, and walks home
/// mending [mendShare] of its HP a second.
const leash = 320.0, giveUpAfter = 10.0, mendShare = 0.2;

/// A room's monsters appear when the leader comes within this of its left end, one or two at a time, the first after
/// [appearFirst] s and the next [appearGap] apart; never within [appearClear] of the room's entrance or a save point,
/// nor within [appearApart] of another unit; each stands [appearTime] s as it rises.
const spawnNear = 320.0, appearFirst = 0.4, appearGap = (1.5, 3.0), appearClear = 96.0, appearApart = 28.0, appearTime = 0.6;

/// The save point's light: the leader within this of it, with no monster hostile, may Leave. The portal takes the
/// leader within [portalReach].
const saveLight = 40.0, portalReach = 22.0;

/// After the last member falls, the trip ends this long (s) later ("The party fell").
const wipeDelay = 1.5;

/// The Dungeon's trip: its floor, the party, each unit's [Mind], the leader's input and the camera.
class Dungeon {
  Dungeon._(this.floor, this.seed, this.party, this._aside) : leader = party.first;

  final DungeonFloor floor;
  final int seed;

  /// The party in the party panel's order (copies of the picked troops: [DungeonTrip.enterDungeon]).
  final List<Unit> party;

  /// The member the player moves; the camera follows it.
  Unit leader;

  /// Each unit's state, party and monsters, in the order they came.
  final minds = <Unit, Mind>{};

  /// Each member's gambits (its type's defaults in M1).
  final rules = <Unit, List<Gambit>>{};

  /// The gambits on (G): every member's but the leader's run.
  bool gambits = true;

  /// The leader walks to its action's target by itself when the stick is let go (a setting turns it off, M2).
  bool autoWalk = true;

  /// The stick or WASD: the leader's walk, each axis -1..1 (0, 0: let go). The UI sets it each frame.
  Point<double> stick = const Point(0, 0);

  /// The view's width in world units (the UI sets it; tests keep this) and its left edge, which follows the leader
  /// ([DungeonTrip._aimCam]).
  double viewW = 400, cam = 0;

  /// The rooms whose monsters were called, and the appearances still due (when, the room, the type, the rank).
  final called = <int>{};
  final due = <(double, Room, String, Tier)>[];

  /// When the last member fell (the wipe's delay runs from it), and how the trip ended.
  double? wipedAt;
  TripEnd? end;

  /// When the trip began (game time), for the HUD's clock.
  double startedAt = 0;

  /// What was set aside at the door and comes back at the end ([DungeonTrip._endTrip]).
  final _Aside _aside;

  /// The game as it was at the door, for any save made during the trip ([Game.toJson]).
  String get saved => _aside.save;

  /// [u]'s rules: its own, else its type's defaults.
  List<Gambit> rulesOf(Unit u) => rules[u] ??= defaultGambits(u.type);

  /// Whether party member [u] stands (not knocked out).
  bool standing(Unit u) => u.side == Side.troop && u.alive && !(minds[u]?.down ?? true);

  /// The members standing, in the party's order.
  List<Unit> get standingParty => [for (final u in party) if (standing(u)) u];

  /// Whether monster [u] is hostile to the party now (not walking home).
  bool hostile(Unit u) {
    final m = minds[u];
    return m != null && m.hostile && !m.homing && u.alive;
  }

  /// Whether [u]'s gambits run now: the gambits on and [u] not the leader.
  bool rulesOn(Unit u) => gambits && u != leader && u.side == Side.troop;

  /// The hostile foes in sight of the leader, the gambits' foes.
  List<Unit> foesInSight(Game g) => [
        for (final u in g.units)
          if (u.side == Side.enemy && hostile(u) && u.pos.distanceTo(leader.pos) <= sight) u,
      ];

  /// The monsters hostile to the party (none: the save point's Leave shows).
  bool get anyHostile => minds.keys.any((u) => u.side == Side.enemy && hostile(u));
}

/// What the door set aside ([DungeonTrip.enterDungeon]), put back as it was when the trip ends.
class _Aside {
  _Aside(this.save);
  final String save;
  final units = <Unit>[], shots = <Shot>[], omens = <OmenKind>[], boosts = <RunningBoost>[], pocketBoosts = <PocketBoost>[];
  final later = <(double, void Function())>[];
  final worth = <Relic, PusakaTally>{}, relicWorth = <Relic, PusakaTally>{}, relicPairs = <String, RelicPair>{};
  final healQueue = <Unit>[];
  double t = 0, viewW = 0;
  int ids = 0, ticks = 0;
  Relic? oathOn;
  double oathK = 1;
}

/// A row of the live action panel ([DungeonTrip.liveRows]).
typedef LiveRow = ({Unit unit, Act? act, Act? queued, double gauge, bool lost});

extension DungeonTrip on Game {
  /// Why a trip can't start with [picks] now (null: it can): only in a Town, between waves, with 1 to
  /// [Dungeon]'s 3 living troops of the army.
  String? whyNotDungeon(List<Unit> picks) {
    if (dungeon != null) return Words.dungeonInside;
    if (!inTown) return Words.dungeonTownOnly;
    if (picks.isEmpty || picks.length > partyMost) return Words.dungeonPickParty;
    if (picks.any((u) => u.side != Side.troop || !u.alive || !units.contains(u))) return Words.dungeonPickParty;
    return null;
  }

  /// Goes into the Dungeon on floor [floor] (M1: 1) with [picks] (1 to [partyMost] living troops of the army; the first
  /// leads): the game as it is is kept for saves, the army and everything that belongs to waves is set aside, the
  /// party comes as copies at the floor's arrival save point. False when [whyNotDungeon] refuses.
  bool enterDungeon(List<Unit> picks, {int floor = 1}) {
    if (whyNotDungeon(picks) != null) return false;
    final aside = _Aside(jsonEncode(_toJson()))
      ..units.addAll(units)
      ..shots.addAll(shots)
      ..omens.addAll(omens)
      ..boosts.addAll(boosts)
      ..pocketBoosts.addAll(pocketBoosts)
      ..later.addAll(_later)
      ..worth.addAll(pusakaWorth)
      ..relicWorth.addAll(relicWorth)
      ..relicPairs.addAll(relicPairs)
      ..healQueue.addAll(healQueue)
      ..t = t
      ..viewW = viewW
      ..ids = Unit._ids
      ..ticks = _ticks
      ..oathOn = _oathOn
      ..oathK = _oathK;
    units.clear();
    shots.clear();
    omens.clear(); // no Shadows inside
    boosts.clear(); // the Tavern's boosts belong to waves
    pocketBoosts.clear();
    _later.clear();
    pusakaWorth.clear();
    relicWorth.clear();
    relicPairs.clear();
    healQueue.clear();
    _oathOn = null; // the oaths count the army: nothing inside
    final made = makeFloor(_dungeonSeed(), floor);
    final party = <Unit>[];
    for (final (i, o) in picks.indexed) {
      final c = Unit(Side.troop, o.type, o.stats, made.savePoint + Point(40.0 - 22 * i, (i.isEven ? 1.0 : -1.0) * 10 * i))
        ..name = o.name
        ..hero = o.hero
        ..heroStats = o.heroStats
        ..heroSkill = o.heroSkill
        ..revived = o.revived
        ..comboKey = o.comboKey
        ..entered = true;
      c.relics.addAll(o.relics);
      party.add(c);
      units.add(c);
    }
    for (final c in party) {
      // The army's numbers: everything that raises its type, a Hero's attributes, a Hero's aura when one is in the party.
      c
        ..stats = _statsFor(c)
        ..maxHp = c.stats.hp
        ..hp = c.stats.hp.toDouble()
        ..mp = c.stats.mp.toDouble();
    }
    final d = dungeon = Dungeon._(made, _dungeonSeedNow!, party, aside)..startedAt = t;
    for (final c in party) {
      d.minds[c] = Mind(home: c.pos);
      d.rulesOf(c);
    }
    d.cam = 0;
    sfx.add(Sfx.wave);
    return true;
  }

  /// The trip's floor seed for this Town ([Game.townCount]): rolled with [Game.dungeonDice] at its first trip and kept
  /// while the game lasts (not saved in M1: the Town's dungeon is M3's).
  int _dungeonSeed() {
    if (_dungeonSeedTown != townCount || _dungeonSeedNow == null) {
      _dungeonSeedTown = townCount;
      _dungeonSeedNow = dungeonDice.nextInt(1 << 30);
    }
    return _dungeonSeedNow!;
  }

  /// Unit [u]'s turn time: twice its time between attacks ([Game.attackEvery], with everything that changes it), at
  /// least [turnMin].
  double turnOf(Unit u) => max(turnMin, 2 * attackEvery(u));

  /// Each blow of [u]'s Attack: the field's blow × turn ÷ attack time ÷ 2 (two blows a turn), so its damage a second is
  /// the field's.
  double blowKOf(Unit u) => turnOf(u) / attackEvery(u) / 2;

  /// The MP a Heal costs [u]: the field's [healMp] a heal, times the field heals one turn holds.
  double healCostOf(Unit u) => healMp * turnOf(u) / attackEvery(u);

  /// Whether [u] can fire [a] at its target now: in reach (an Attack: [Engage.reaches]; a Heal: the healer's range).
  bool inReachOf(Unit u, Act a) {
    final o = a.target;
    if (o == null) return false;
    return a.kind == ActKind.heal ? o.pos.distanceTo(u.pos) <= u.stats.range : reaches(u, o);
  }

  // ---- the player's commands -------------------------------------------------------------------------------------

  /// Gives party member [u] [kind] on [target] from the player (the Action chain, a tap on a foe): under [queueAt] of
  /// its gauge it replaces the current action at once (the gauge kept); at or over it, it is queued behind it (one
  /// slot, a later one replacing the queued one, never the current). False when [u] can't take it.
  bool command(Unit u, ActKind kind, Unit target) {
    final d = dungeon;
    if (d == null || !d.standing(u) || !target.alive) return false;
    if (kind == ActKind.heal && (!u.stats.heals || target.side != Side.troop)) return false;
    if (kind == ActKind.attack && target.side != Side.enemy) return false;
    _give(u, d.minds[u]!, Act(kind, target, byPlayer: true));
    return true;
  }

  /// [a] given to [u] under the 75% rule.
  void _give(Unit u, Mind m, Act a) {
    if (m.act == null || m.gauge < queueAt) {
      m.act = a;
    } else {
      m.queued = a;
    }
  }

  /// The leader becomes the next ([step] 1) or previous (-1) standing member in the party's order, wrapping round.
  void switchLeader(int step) {
    final d = dungeon;
    if (d == null) return;
    final up = d.standingParty;
    if (up.length < 2) return;
    final i = up.indexOf(d.leader);
    lead(up[((i < 0 ? 0 : i) + step) % up.length]);
  }

  /// [u] leads now, if it stands.
  void lead(Unit u) {
    final d = dungeon;
    if (d == null || !d.standing(u) || d.leader == u) return;
    d.leader = u;
    d.minds[u]!.following = false;
  }

  /// G: every member's gambits on or off.
  void toggleGambits() {
    final d = dungeon;
    if (d != null) d.gambits = !d.gambits;
  }

  /// Whether the leader stands in the save point's light with no monster hostile: Leave shows.
  bool get atSavePoint {
    final d = dungeon;
    return d != null && d.end == null && d.standing(d.leader) && d.leader.pos.distanceTo(d.floor.savePoint) <= saveLight && !d.anyHostile;
  }

  /// Leave at the save point: back to the Town ([TripEnd.left]). False away from it.
  bool leaveDungeon() {
    if (!atSavePoint) return false;
    _endTrip(TripEnd.left);
    return true;
  }

  /// Ends the trip as [end] at once, wherever the party is: for tests and probes (a player leaves only at a save point,
  /// by the portal or by a wipe).
  void endTripNow(TripEnd end) {
    if (dungeon != null) _endTrip(end);
  }

  /// Puts a monster of [type] and [tier] on the floor at [at] now, as a room's would appear (no rising), its temper by
  /// its type: for tests and probes.
  Unit addDungeonFoe(String type, Point<double> at, {Tier tier = Tier.normal}) {
    final d = dungeon!, wave = depthWave(d.floor.number);
    final u = Unit(Side.enemy, type, enemyStats(type, tier, wave, tideStart: 1 << 30), at)
      ..tier = tier
      ..entered = true;
    final radius = aggroRadius[type] ?? 0.0;
    d.minds[u] = Mind(home: at, room: d.floor.roomAt(at.x).index)
      ..aggressive = radius > 0
      ..aggro = radius;
    units.add(u);
    return u;
  }

  /// The live action panel's rows: the party's members with an action (the leader's first), then the foes engaged
  /// with the party (hostile, an action given), the soonest to fire first. A row shows "target lost" for [lostFor] s.
  List<LiveRow> liveRows() {
    final d = dungeon;
    if (d == null) return const [];
    LiveRow row(Unit u, Mind m) => (unit: u, act: m.act, queued: m.queued, gauge: m.shown, lost: t - m.lostAt < lostFor);
    final party = [
      for (final u in [d.leader, ...d.party.where((o) => o != d.leader)])
        if (d.minds[u] case final m? when d.standing(u) && (m.act != null || t - m.lostAt < lostFor)) row(u, m),
    ];
    final foes = [
      for (final MapEntry(key: u, value: m) in d.minds.entries)
        if (u.side == Side.enemy && d.hostile(u) && m.act != null) row(u, m),
    ]..sort((a, b) => ((1 - a.gauge) * turnOf(a.unit)).compareTo((1 - b.gauge) * turnOf(b.unit)));
    return [...party, ...foes];
  }

  // ---- the tick ----------------------------------------------------------------------------------------------------

  /// The Dungeon's tick ([Game.tick] hands it every tick during a trip): the clock and the statuses, the rooms that
  /// call their monsters and the appearances due, each unit's turn (its decision, its walk, its gauge and its action),
  /// the separation, the shots, the falls, the end of the trip and the camera.
  void _dungeonTick(double dt) {
    final d = dungeon!;
    t += dt;
    _dt = dt;
    _ticks++;
    _tickEffects(dt);
    _callRooms(d);
    _appear(d);
    for (final u in units.toList()) {
      final m = d.minds[u];
      if (m == null) continue;
      if (u.dying >= 0) {
        u.dying = m.down ? min(u.dying + dt, deathTime - 1e-3) : u.dying + dt; // a member lies on its last frame
        continue;
      }
      if (u.stats.mpRegen > 0) u.mp = min(u.stats.mp.toDouble(), u.mp + u.stats.mpRegen * dt);
      if (u.stats.regen > 0) _healUnit(u, u.stats.regen * dt, HealSrc.regen);
      if (t < u.busyUntil || t < u.downUntil) {
        u.moving = false; // rising out of the ground, a heap of bones
        continue;
      }
      final stunned = t < u.stunUntil;
      // A stun stops the gauge. It may run over full by a tick's share, which the next turn keeps ([_fire]), so a turn
      // doesn't lose the tick that crossed it.
      if (!stunned) m.gauge = min(1.0 + dt / turnOf(u), m.gauge + dt / turnOf(u));
      _secondBlow(u, m);
      if (stunned) {
        u.moving = false;
        continue;
      }
      if (u.side == Side.troop) {
        _memberTurn(d, u, m, dt);
      } else {
        _monsterTurn(d, u, m, dt);
      }
    }
    _keepApart(d);
    _flyShots(dt);
    units.removeWhere((u) => u.side == Side.enemy && (u.gone || u.dying >= deathTime));
    d.minds.removeWhere((u, m) => u.side == Side.enemy && !units.contains(u));
    _aimCam(d);
    if (d.wipedAt case final w? when t - w >= wipeDelay) return _endTrip(TripEnd.fell);
    if (d.standing(d.leader) && d.leader.pos.distanceTo(d.floor.portal) <= portalReach) return _endTrip(TripEnd.cleared);
  }

  /// The rooms the leader nears call their monsters: each comes at a time rolled with [Game.dungeonDice], one or two
  /// at a time.
  void _callRooms(Dungeon d) {
    for (final r in d.floor.rooms) {
      if (r.monsters.isEmpty || d.called.contains(r.index) || d.leader.pos.x < r.x0 - spawnNear) continue;
      d.called.add(r.index);
      var at = t + appearFirst;
      for (var i = 0; i < r.monsters.length;) {
        final group = 1 + dungeonDice.nextInt(2);
        for (var j = 0; j < group && i < r.monsters.length; j++, i++) {
          d.due.add((at, r, r.monsters[i].$1, r.monsters[i].$2));
        }
        at += appearGap.$1 + dungeonDice.nextDouble() * (appearGap.$2 - appearGap.$1);
      }
    }
  }

  /// The appearances due now: each monster at a random free point of its room's band ([appearClear] from its entrance
  /// and the save point, [appearApart] from anyone), with the field's numbers at the floor's depth wave (no tide,
  /// Shadow or weakening inside), its temper by its type and the floor.
  void _appear(Dungeon d) {
    final now = [for (final e in d.due) if (e.$1 <= t + 1e-9) e];
    if (now.isEmpty) return;
    d.due.removeWhere(now.contains);
    final floor = d.floor.number, wave = depthWave(floor);
    for (final (_, room, type, tier) in now) {
      final at = _appearPoint(d, room);
      if (at == null) continue;
      final u = Unit(Side.enemy, type, enemyStats(type, tier, wave, tideStart: 1 << 30), at)
        ..tier = tier
        ..entered = true
        ..busyFrom = t
        ..busyUntil = t + appearTime;
      _face(u, d.leader.pos.x - at.x, 0);
      final m = d.minds[u] = Mind(home: at, room: room.index);
      final radius = aggroRadius[type] ?? (floor >= 10 && tier.index >= Tier.elite.index && type != necroHealer ? 96.0 : 0.0);
      m
        ..aggressive = radius > 0
        ..aggro = radius * (floor >= 15 ? 1.25 : 1);
      units.add(u);
      impacts.add((at, 'summon')); // the necromancer's ring on the ground as it rises
    }
  }

  /// A random free point of [room]'s band for a monster to appear at, or null after a few tries.
  Point<double>? _appearPoint(Dungeon d, Room room) {
    final entrance = Point(room.x0, room.midY);
    for (var i = 0; i < 40; i++) {
      final p = Point(room.x0 + 16 + dungeonDice.nextDouble() * (room.width - 32), bandTop + 8 + dungeonDice.nextDouble() * (room.depth - 16));
      if (!d.floor.grid.freeAt(p) || p.distanceTo(entrance) < appearClear || p.distanceTo(d.floor.savePoint) < appearClear) continue;
      if (units.any((o) => o.alive && o.pos.distanceTo(p) < appearApart)) continue;
      return Point(p.x.roundToDouble(), p.y.roundToDouble());
    }
    return null;
  }

  /// A member's turn: its action checked (a target lost drops it), its gambits read, its walk (the stick for the
  /// leader, its target, its spot behind the leader) and its action fired when the gauge is full and the target in
  /// reach.
  void _memberTurn(Dungeon d, Unit u, Mind m, double dt) {
    _dropLost(u, m);
    if (d.rulesOn(u)) _readRules(d, u, m);
    final a = m.act, lead = u == d.leader, stick = d.stick;
    final held = lead && (stick.x != 0 || stick.y != 0);
    if (held) {
      final len = stick.magnitude, dir = len > 1 ? stick * (1 / len) : stick;
      _step(d, u, dir, u.walkSpeed * _pace(u) * dt);
    } else if (a != null && a.target != null && (!lead || d.autoWalk)) {
      final far = !lead && a.target!.pos.distanceTo(d.leader.pos) > chaseCap; // it never chases that far from the leader
      if (far) {
        _follow(d, u, m, dt);
      } else if (!inReachOf(u, a)) {
        _walkTo(d, u, m, a.kind == ActKind.attack ? _reachSpot(u, a.target!) : a.target!.pos, dt);
      } else {
        u.moving = false;
        _face(u, a.target!.pos.x - u.pos.x, 0);
      }
    } else if (!lead) {
      _follow(d, u, m, dt);
    } else {
      u.moving = false;
    }
    if (a != null && m.full && m.blowOn == null && inReachOf(u, a)) _fire(d, u, m);
  }

  /// [u]'s action's target fell or went home: the action is dropped ("target lost"), the queued one comes next, else
  /// its gambits (if on) or the player.
  void _dropLost(Unit u, Mind m) {
    final o = m.act?.target;
    if (o == null) return;
    final d = dungeon!;
    final gone = !o.alive || (o.side == Side.enemy && (d.minds[o]?.homing ?? true)) || (o.side == Side.troop && !d.standing(o));
    if (!gone) return;
    m
      ..lostAt = t
      ..act = m.queued
      ..queued = null
      ..readAt = t;
  }

  /// Reads [u]'s gambits when it has no action, and every [gambitEvery] s while its gauge is under [queueAt]: a rule
  /// above the current one that fits replaces it (or takes the queue slot at [queueAt] or more), the same rule keeps
  /// its target while it holds; a command from the player is never replaced, current or queued.
  void _readRules(Dungeon d, Unit u, Mind m) {
    final a = m.act;
    if (a != null && (a.byPlayer || m.queued?.byPlayer == true)) return;
    if (a != null && (m.gauge >= queueAt || t < m.readAt)) return;
    m.readAt = t + gambitEvery;
    final pick = readGambits(u, keep: a ?? m.last);
    if (pick == null) {
      if (a != null && a.byGambit) m.act = null; // nothing fits any more: it follows
      return;
    }
    final (_, act) = pick;
    if (act.kind == ActKind.follow) {
      m.act = null;
      return;
    }
    if (act.same(a) && act.rule == a?.rule) return;
    _give(u, m, act);
  }

  /// [u] fires its action: an Attack's first blow now and its second [blowGap] later ([_secondBlow]); a Heal at once. A
  /// gambit's condition is checked again first: if it no longer holds, the rules are read again. Then the gauge empties
  /// and the next action comes: the queued one; else an Attack repeats while its member's gambits are off; else the
  /// gambits pick at once, or the member waits.
  void _fire(Dungeon d, Unit u, Mind m) {
    var a = m.act!;
    if (a.byGambit && d.rulesOn(u)) {
      final rule = d.rulesOf(u)[a.rule!];
      if (!gambitHolds(u, rule.when, a.target!)) {
        m.act = null;
        final pick = readGambits(u);
        if (pick == null || pick.$2.kind == ActKind.follow) return;
        m.act = a = pick.$2;
        if (!inReachOf(u, a)) return; // fires on arrival
      }
    }
    final o = a.target!;
    u.moving = false;
    _face(u, o.pos.x - u.pos.x, 0);
    final k = blowKOf(u);
    switch (a.kind) {
      case ActKind.heal:
        if (u.mp < healCostOf(u)) return; // short of MP: it waits for it
        _castHeal(u, o, k: 2 * k);
      case ActKind.attack:
        if (u.stats.heals) {
          _smite(u, o, k: k);
        } else {
          _strike(u, o, k: k);
        }
        m
          ..blowOn = o
          ..blowK = k
          ..blowAt = t + min(blowGap, turnOf(u) / 4);
      case ActKind.follow:
        break;
    }
    m
      ..gauge = max(0.0, m.gauge - 1)
      ..last = a;
    if (m.queued != null) {
      m
        ..act = m.queued
        ..queued = null;
    } else if (u.side == Side.enemy || ((a.kind == ActKind.attack || a.kind == ActKind.heal) && !d.rulesOn(u))) {
      if (a.kind == ActKind.heal && o.hp >= o.maxHp) m.act = null; // healed full: done
    } else {
      // The gambits pick the next at once (the same rule keeps its target), so its row never blinks out.
      final pick = readGambits(u, keep: a);
      m
        ..act = pick == null || pick.$2.kind == ActKind.follow ? null : pick.$2
        ..readAt = t + gambitEvery;
    }
  }

  /// An Attack's second blow, when due: on the same target if it still stands within reach (a little slack), else none.
  void _secondBlow(Unit u, Mind m) {
    final o = m.blowOn;
    if (o == null || t < m.blowAt) return;
    m
      ..blowOn = null
      ..blowAt = double.infinity;
    if (!o.alive || o.pos.distanceTo(u.pos) > u.stats.range + navCell) return;
    _face(u, o.pos.x - u.pos.x, 0);
    if (u.stats.heals) {
      _smite(u, o, k: m.blowK);
    } else {
      _strike(u, o, k: m.blowK);
    }
  }

  /// A monster's turn: walking home mends it; at peace an aggressive one looks for a member within its aggro radius;
  /// hostile, it goes for its prey (the member nearest it, or the one that hit it last) until its leash or
  /// [giveUpAfter] s without reaching anyone. A healer never starts a fight: it keeps near the nearest hostile monster
  /// and heals the most hurt one in its reach.
  void _monsterTurn(Dungeon d, Unit u, Mind m, double dt) {
    if (m.homing) {
      _healUnit(u, u.maxHp * mendShare * dt, HealSrc.regen);
      if (u.pos.distanceTo(m.home) <= 6) {
        m
          ..homing = false
          ..hostile = false
          ..prey = null
          ..hitBy = null
          ..act = null;
        u.moving = false;
      } else {
        _walkTo(d, u, m, m.home, dt);
      }
      return;
    }
    if (u.stats.heals) return _monsterHealer(d, u, m, dt);
    if (!m.hostile) {
      u.moving = false;
      if (!m.aggressive) return;
      Unit? near;
      var best = m.aggro;
      for (final o in d.party) {
        if (!d.standing(o)) continue;
        final dd = o.pos.distanceTo(u.pos);
        if (dd <= best) (near, best) = (o, dd);
      }
      if (near != null) _turnHostile(d, u, m, near);
      return;
    }
    if (u.pos.distanceTo(m.home) > leash || t - m.reachedAt > giveUpAfter) return _giveUp(u, m);
    var prey = m.prey;
    if (prey == null || !d.standing(prey)) {
      prey = null;
      var best = double.infinity;
      for (final o in d.party) {
        if (!d.standing(o)) continue;
        final dd = o.pos.distanceTo(u.pos);
        if (dd < best) (prey, best) = (o, dd);
      }
      m.prey = prey;
    }
    if (prey == null) {
      u.moving = false;
      m.act = null;
      return;
    }
    if (m.act?.target != prey) m.act = Act(ActKind.attack, prey);
    if (reaches(u, prey)) {
      m.reachedAt = t;
      u.moving = false;
      _face(u, prey.pos.x - u.pos.x, 0);
      if (m.full && m.blowOn == null) _fire(d, u, m);
    } else {
      _walkTo(d, u, m, _reachSpot(u, prey), dt);
    }
  }

  /// The monster healer's turn: near the nearest hostile monster, healing the most hurt monster in its reach.
  void _monsterHealer(Dungeon d, Unit u, Mind m, double dt) {
    Unit? ward, hurt;
    var best = double.infinity;
    for (final o in units) {
      if (o == u || o.side != Side.enemy || !d.hostile(o)) continue;
      final dd = o.pos.distanceTo(u.pos);
      if (dd < best) (ward, best) = (o, dd);
      if (dd <= u.stats.range && o.hp < o.maxHp && (hurt == null || o.hp / o.maxHp < hurt.hp / hurt.maxHp)) hurt = o;
    }
    m.act = hurt == null ? null : Act(ActKind.heal, hurt);
    if (ward != null && best > u.stats.range * 0.6) {
      _walkTo(d, u, m, ward.pos, dt);
    } else {
      u.moving = false;
    }
    if (hurt != null && m.full) {
      _castHeal(u, hurt, k: 2 * blowKOf(u));
      m.gauge = max(0.0, m.gauge - 1);
    }
  }

  /// Monster [u] turns on [prey]: hostile, its leash's clock from now.
  void _turnHostile(Dungeon d, Unit u, Mind m, Unit prey) {
    m
      ..hostile = true
      ..homing = false
      ..prey = prey
      ..reachedAt = t;
  }

  /// Monster [u] gives up: it walks home, mending; neutral again once there (an aggressive one aggressive again).
  void _giveUp(Unit u, Mind m) {
    m
      ..homing = true
      ..prey = null
      ..hitBy = null
      ..act = null
      ..path = const [];
  }

  /// A blow landed on [u] by [by] ([Game._hurt] calls it during a trip): a monster at peace (or walking home) turns
  /// hostile on its hitter, and an orc calls its kind within [kinCall].
  void _dungeonStruck(Unit u, Unit? by) {
    final d = dungeon!;
    if (u.side != Side.enemy || by == null || by.side != Side.troop) return;
    final m = d.minds[u];
    if (m == null) return;
    m.hitBy = by;
    if (!m.hostile || m.homing) _turnHostile(d, u, m, by);
    m
      ..prey = by
      ..reachedAt = t;
    if (!callsKin.contains(u.type)) return;
    for (final MapEntry(key: o, value: om) in d.minds.entries) {
      if (o == u || !o.alive || !callsKin.contains(o.type) || om.hostile || o.pos.distanceTo(u.pos) > kinCall) continue;
      _turnHostile(d, o, om, by);
    }
  }

  /// [u] fell during a trip ([Game._hurt] calls it at 0 HP, in place of the field's death): a member is knocked out (it
  /// lies there, the lead passes on, the last one starts the wipe's delay); a monster dies, paying nothing in M1 (no
  /// gold, loot, score or kill count: the wave run's dice and purse are never touched inside). Returns [dealt].
  double _dungeonFell(Unit u, Unit? by, double dealt) {
    final d = dungeon!;
    final m = d.minds[u];
    u
      ..hp = 0
      ..dying = 0
      ..moving = false;
    if (u.side == Side.enemy) {
      sfx.add(Sfx.kill);
      m?.act = null;
      return dealt;
    }
    sfx.add(Sfx.fall);
    if (m != null) {
      m
        ..down = true
        ..act = null
        ..queued = null
        ..blowOn = null;
    }
    if (d.leader == u) {
      final up = d.standingParty;
      if (up.isNotEmpty) d.leader = up.first;
    }
    if (d.standingParty.isEmpty) d.wipedAt ??= t;
    return dealt;
  }

  // ---- walking -----------------------------------------------------------------------------------------------------

  /// Where [u] stands to strike [o]: just inside its reach on its own side (a shooter at its hold), kept on the band.
  Point<double> _reachSpot(Unit u, Unit o) {
    final p = _reachPoint(u, o);
    return dungeon!.floor.grid.freeAt(p) ? p : o.pos;
  }

  /// Follower [u] keeps its spot behind the leader: past [followSnap] it is put beside the leader, past [followSlack]
  /// it walks back by a path until it is there.
  void _follow(Dungeon d, Unit u, Mind m, double dt) {
    final spot = followSpot(u), lead = d.leader;
    if (u.pos.distanceTo(lead.pos) > followSnap) {
      final (c, r) = d.floor.grid.nearestFree(spot) ?? d.floor.grid.cellOf(lead.pos);
      u.pos = WalkGrid.centre(c, r);
      m
        ..following = false
        ..path = const [];
      u.moving = false;
      return;
    }
    final far = u.pos.distanceTo(spot);
    if (far > followSlack) m.following = true;
    if (m.following && far > 4) {
      _walkTo(d, u, m, spot, dt);
    } else {
      m.following = false;
      u.moving = false;
    }
  }

  /// Follower [u]'s spot: behind the leader (away from its facing) by its role, melee [followMelee], long range and
  /// healers [followFar]; the followers [followSpread] apart in depth; on a free cell.
  Point<double> followSpot(Unit u) {
    final d = dungeon!, lead = d.leader;
    final others = [for (final o in d.party) if (o != lead && d.standing(o)) o];
    final i = others.indexOf(u), n = others.length;
    final back = u.line == 2 ? followMelee : (u.line == 1 ? followFar.$1 : followFar.$2);
    final lane = n <= 1 ? 0.0 : (i - (n - 1) / 2) * followSpread;
    final p = lead.pos + Point(-lead.dir * back, lane);
    final cell = d.floor.grid.nearestFree(p);
    return cell == null ? lead.pos : (d.floor.grid.freeAt(p) ? p : WalkGrid.centre(cell.$1, cell.$2));
  }

  /// [u] walks toward [to] at its walk speed: straight when in sight, else along its A* path (asked again at most every
  /// [navEvery] s, or when the goal moved more than [navRegoal]).
  void _walkTo(Dungeon d, Unit u, Mind m, Point<double> to, double dt) {
    final grid = d.floor.grid, speed = u.walkSpeed * _pace(u), stepLen = speed * dt;
    Point<double> next;
    if (grid.clear(u.pos, to)) {
      next = to;
      m.path = const [];
    } else {
      final stale = m.pathTo == null || m.pathTo!.distanceTo(to) > navRegoal || m.path.isEmpty;
      if (stale && t - m.pathAt >= navEvery) {
        m
          ..path = grid.path(u.pos, to) ?? const []
          ..pathAt = t
          ..pathTo = to;
      }
      while (m.path.isNotEmpty && m.path.first.distanceTo(u.pos) < 2) {
        m.path = m.path.sublist(1);
      }
      next = m.path.isNotEmpty ? m.path.first : to;
    }
    final dv = next - u.pos, len = dv.magnitude;
    if (len < 1e-6) {
      u.moving = false;
      return;
    }
    _step(d, u, dv * (1 / len), min(stepLen, len)); // to the point itself at the last step: never stops a hair short of reach
  }

  /// [u] takes a step of [len] along [dir], sliding along blocked cells; it faces the way it walks.
  void _step(Dungeon d, Unit u, Point<double> dir, double len) {
    final from = u.pos;
    u.pos = d.floor.grid.slide(from, dir * len);
    u.moving = u.pos != from;
    if (u.moving) {
      u
        ..heading = dir
        ..walkedAt = t;
      _face(u, dir.x, 0);
    }
  }

  /// Units keep apart as on the field ([Game._personalSpace]): two closer than it are pushed apart, half each, never
  /// onto a blocked cell.
  void _keepApart(Dungeon d) {
    final live = [for (final u in units) if (u.alive && t >= u.busyUntil) u];
    final grid = d.floor.grid;
    for (var i = 0; i < live.length; i++) {
      for (var j = i + 1; j < live.length; j++) {
        final a = live[i], b = live[j], dv = b.pos - a.pos, len = dv.magnitude;
        if (len >= Game._personalSpace) continue;
        final push = len > 0.01 ? dv * ((Game._personalSpace - len) / 2 / len) : Point(0.0, (Game._personalSpace / 2) * (i.isEven ? 1 : -1));
        final pa = a.pos - push, pb = b.pos + push;
        if (grid.freeAt(pa)) a.pos = pa;
        if (grid.freeAt(pb)) b.pos = pb;
      }
    }
  }

  /// The camera keeps the leader between 35% and 65% of the view's width, inside the floor's ends.
  void _aimCam(Dungeon d) {
    final w = d.viewW, x = d.leader.pos.x;
    d.cam = d.cam.clamp(x - 0.65 * w, x - 0.35 * w).clamp(0.0, max(0.0, d.floor.width - w));
  }

  // ---- the end -----------------------------------------------------------------------------------------------------

  /// The trip ends ([TripEnd]): the party's copies go, the set-aside army and everything set aside at the door come
  /// back as they were (the clock too, so the wave run goes on exactly as if no trip had been made), and the Town shows
  /// the news ([Game.tripNews]).
  void _endTrip(TripEnd end) {
    final d = dungeon!;
    final a = d._aside;
    d.end = end;
    units
      ..clear()
      ..addAll(a.units);
    shots
      ..clear()
      ..addAll(a.shots);
    omens
      ..clear()
      ..addAll(a.omens);
    boosts
      ..clear()
      ..addAll(a.boosts);
    pocketBoosts
      ..clear()
      ..addAll(a.pocketBoosts);
    _later
      ..clear()
      ..addAll(a.later);
    pusakaWorth
      ..clear()
      ..addAll(a.worth);
    relicWorth
      ..clear()
      ..addAll(a.relicWorth);
    relicPairs
      ..clear()
      ..addAll(a.relicPairs);
    healQueue
      ..clear()
      ..addAll(a.healQueue);
    impacts.clear();
    rings.clear();
    t = a.t;
    viewW = a.viewW;
    Unit._ids = a.ids;
    _ticks = a.ticks;
    _oathOn = a.oathOn;
    _oathK = a.oathK;
    dungeon = null;
    tripNews = (end: end, floor: d.floor.number);
    sfx.add(end == TripEnd.fell ? Sfx.lose : Sfx.clear);
  }
}

/// The most members a party takes.
const partyMost = 3;
