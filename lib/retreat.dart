import 'dart:convert';

// When a hurt troop falls back to a troop healer and when it goes back in (#32, #50; formation-and-navigation.md).
// Every number is in one patchable "brain" (assets/ai/retreat.json, [RetreatBrain]); the decision sits behind
// [RetreatPolicy] and reads only [RetreatFeatures], so a trained model could replace the rule
// ([RuleRetreatPolicy]) without touching the combat code (game.dart computes the features and acts on the
// answer).

/// The fall-back thresholds' defaults: at or below [retreatAt] of its HP a troop falls back until within
/// [retreatNear] of the healer's reach, and fights on at [returnAt] (the gap keeps it from flickering).
const retreatAt = 0.5, returnAt = 0.8, retreatNear = 0.5;

/// What a policy decides for a troop this tick.
enum RetreatAction {
  /// Fights as usual.
  fight,

  /// Falls back to the healer, striking nothing on the way.
  fallBack,

  /// Falls back, still striking a foe in its reach: a ranged troop, or a melee one that can't back off any
  /// further (cornered).
  fallBackFighting,
}

/// Everything the fall-back decision reads about one troop mid-wave, as plain numbers (what a trained model
/// would get too).
typedef RetreatFeatures = ({
  /// Falling back now.
  bool retreating,

  /// Its HP over its most.
  double hpShare,

  /// The share of its most HP it lost per second over the brain's [RetreatBrain.threatWindow].
  double dpsShare,

  /// Troop healers on the field (marched in and alive).
  int healers,

  /// Its distance to the nearest of them over that healer's reach.
  double healerReach,

  /// Seconds it has stood at that healer's spot ([RetreatBrain.retreatNear]) without a heal; 0 elsewhere.
  double waited,

  /// How many of those falling back to the same healer and standing at its spot have more of their HP left.
  int rank,

  /// Melee troops still fighting (not falling back).
  int frontFighters,

  /// Tiles between the back line and the nearest monster on the field (infinity with none).
  double foeToBase,

  /// A ranged troop (shoots).
  bool ranged,

  /// Tiles between it and the back line.
  double backRoom,
});

/// The fall-back decision.
abstract class RetreatPolicy {
  const RetreatPolicy();

  /// The numbers the combat code needs besides the decision (where a troop stops falling back, how long a
  /// window [RetreatFeatures.dpsShare] covers, whether the after-wave heals carry over).
  RetreatBrain get brain;

  RetreatAction decide(RetreatFeatures f);
}

/// The rule (decisions-log 96; each part below switched off by its 0 / false in the brain). With no troop
/// healer it fights on. A fighting troop falls back at [RetreatBrain.retreatAt], or sooner below
/// [RetreatBrain.doomMaxShare] when the damage it takes would fell it within [RetreatBrain.doomTime]. A
/// falling-back one goes back in at [RetreatBrain.returnAt], or from
/// [RetreatBrain.earlyReturnAt] (anything above [RetreatBrain.retreatAt] when the base is threatened) when
/// the line needs it (fewer than [RetreatBrain.lineMin] still fighting, or a monster within
/// [RetreatBrain.baseThreat] tiles of the back line) or when heals don't come (the healthiest one at the
/// healer, after [RetreatBrain.healWait] s there without one) — never into damage that would fell it, unless
/// the base is threatened. Falling back, a melee troop strikes only when cornered ([RetreatBrain.holdFire]).
class RuleRetreatPolicy extends RetreatPolicy {
  const RuleRetreatPolicy([this._brain]);

  final RetreatBrain? _brain;

  /// Its own brain, else the one loaded at start ([retreatBrain]).
  @override
  RetreatBrain get brain => _brain ?? retreatBrain;

  @override
  RetreatAction decide(RetreatFeatures f) {
    final b = brain;
    if (f.healers == 0) return RetreatAction.fight;
    final threatened = f.foeToBase < b.baseThreat;
    final doomed = b.doomTime > 0 && f.dpsShare * b.doomTime >= f.hpShare;
    if (!f.retreating) {
      final back = f.hpShare <= b.retreatAt || (doomed && f.hpShare < b.doomMaxShare && !threatened);
      return back ? _back(f) : RetreatAction.fight;
    }
    if (f.hpShare >= b.returnAt) return RetreatAction.fight;
    if (f.hpShare > b.retreatAt && threatened) return RetreatAction.fight; // nothing else helps
    if (f.hpShare >= b.earlyReturnAt && !doomed) {
      if (f.frontFighters < b.lineMin) return RetreatAction.fight; // the line is collapsing
      if (b.healWait > 0 && f.waited >= b.healWait && f.rank == 0) return RetreatAction.fight; // heals don't come
    }
    return _back(f);
  }

  RetreatAction _back(RetreatFeatures f) {
    final b = brain, cornered = f.healerReach <= b.retreatNear || f.backRoom < 1;
    return !b.holdFire || f.ranged || cornered ? RetreatAction.fallBackFighting : RetreatAction.fallBack;
  }
}

/// The fall-back brain: every threshold of [RuleRetreatPolicy] (and of the fall-back walk), patchable in
/// assets/ai/retreat.json ([parse]); a number that is missing or out of its range keeps its default here.
class RetreatBrain {
  /// The format [parse] reads; a file of another version is ignored (every default).
  static const version = 1;

  /// Falls back at or below this share of its HP ([retreatAt]).
  final double retreatAt;

  /// Goes back in at this share ([returnAt]).
  final double returnAt;

  /// Stops falling back within this share of the healer's reach ([retreatNear]).
  final double retreatNear;

  /// Seconds of damage [RetreatFeatures.dpsShare] averages over.
  final double threatWindow;

  /// Falls back sooner when that damage would fell it within this many seconds (0: never).
  final double doomTime;

  /// ... but only below this share of its HP.
  final double doomMaxShare;

  /// The least share an early return (the line, heals not coming) needs.
  final double earlyReturnAt;

  /// Goes back in when fewer melee troops than this still fight (0: never).
  final int lineMin;

  /// Tiles from the back line within which a monster threatens the base (0: never).
  final double baseThreat;

  /// Seconds at the healer without a heal before the healthiest one there goes back in (0: never).
  final double healWait;

  /// Falling back, a melee troop strikes only when cornered.
  final bool holdFire;

  /// A new wave doesn't drop the after-wave heals still to come: the healers go on with them.
  final bool carryHealQueue;

  /// The defaults are what ships (decisions-log 96's A/B): of #50's parts only the return when heals don't
  /// come is on. The others are off (0 / false); the A/B had them at doomTime 2, lineMin 2, baseThreat 2,
  /// holdFire and carryHealQueue true.
  const RetreatBrain({
    this.retreatAt = 0.5,
    this.returnAt = 0.8,
    this.retreatNear = 0.5,
    this.threatWindow = 2,
    this.doomTime = 0,
    this.doomMaxShare = 0.8,
    this.earlyReturnAt = 0.6,
    this.lineMin = 0,
    this.baseThreat = 0,
    this.healWait = 3,
    this.holdFire = false,
    this.carryHealQueue = false,
  });

  /// The rule before #50 (#32 alone): falls back at [retreatAt], back in at [returnAt], striking on the way.
  static const old = RetreatBrain(healWait: 0);

  /// The brain in [text] (assets/ai/retreat.json), or every default when it isn't a version-[version] object.
  static RetreatBrain parse(String text) {
    try {
      final j = jsonDecode(text);
      if (j is Map<String, dynamic> && j['version'] == version) return RetreatBrain.fromJson(j);
    } on FormatException {
      // not JSON: the defaults
    }
    return const RetreatBrain();
  }

  /// [j]'s numbers, each only when it is of the right kind and in its range.
  factory RetreatBrain.fromJson(Map<String, dynamic> j) {
    const d = RetreatBrain();
    double share(String k, double def) => switch (j[k]) { final num v when v >= 0 && v <= 1 => v.toDouble(), _ => def };
    double atLeast0(String k, double def) => switch (j[k]) { final num v when v >= 0 && v.isFinite => v.toDouble(), _ => def };
    bool flag(String k, bool def) => switch (j[k]) { final bool v => v, _ => def };
    var (back, ret) = (share('retreatAt', d.retreatAt), share('returnAt', d.returnAt));
    if (ret <= back) (back, ret) = (d.retreatAt, d.returnAt); // no gap: it would flicker
    final near = share('retreatNear', d.retreatNear);
    return RetreatBrain(
      retreatAt: back,
      returnAt: ret,
      retreatNear: near > 0 ? near : d.retreatNear,
      threatWindow: switch (j['threatWindow']) { final num v when v > 0 && v.isFinite => v.toDouble(), _ => d.threatWindow },
      doomTime: atLeast0('doomTime', d.doomTime),
      doomMaxShare: share('doomMaxShare', d.doomMaxShare),
      earlyReturnAt: share('earlyReturnAt', d.earlyReturnAt),
      lineMin: switch (j['lineMin']) { final int v when v >= 0 => v, _ => d.lineMin },
      baseThreat: atLeast0('baseThreat', d.baseThreat),
      healWait: atLeast0('healWait', d.healWait),
      holdFire: flag('holdFire', d.holdFire),
      carryHealQueue: flag('carryHealQueue', d.carryHealQueue),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'retreatAt': retreatAt,
        'returnAt': returnAt,
        'retreatNear': retreatNear,
        'threatWindow': threatWindow,
        'doomTime': doomTime,
        'doomMaxShare': doomMaxShare,
        'earlyReturnAt': earlyReturnAt,
        'lineMin': lineMin,
        'baseThreat': baseThreat,
        'healWait': healWait,
        'holdFire': holdFire,
        'carryHealQueue': carryHealQueue,
      };
}

/// The brain every [RuleRetreatPolicy] without its own uses: the defaults until the game loads
/// assets/ai/retreat.json at start (main.dart).
RetreatBrain retreatBrain = const RetreatBrain();
