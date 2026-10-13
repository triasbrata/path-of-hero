part of 'game.dart';

// Gambits (decisions-log 336, 337; docs/dungeon-design.md section 4): each party member's ordered rules
// "condition -> action", read from the top; the first whose condition finds a target and whose action can be paid is
// what the member does. M1 runs the types' default lists (no editor yet, M2): the rules whose action is a skill are
// there but never fit until M2 builds the skills inside.

/// Whom a condition looks at: the party, the foes or the member itself.
enum GambitSide { ally, foe, self }

/// A gambit's condition ([Gambit.when]), with its side and its words.
enum GambitIf {
  allyHp50(GambitSide.ally, 'HP < 50%'),
  allyHp70(GambitSide.ally, 'HP < 70%'),
  allyHp30(GambitSide.ally, 'HP < 30%'),
  allyDown(GambitSide.ally, 'knocked out'),
  allyHit(GambitSide.ally, 'being hit'),
  allyStunned(GambitSide.ally, 'stunned'),
  allyMp30(GambitSide.ally, 'MP < 30%'),
  allyLeader(GambitSide.ally, 'the leader'),
  foeNearest(GambitSide.foe, 'nearest'),
  foeLeaderTarget(GambitSide.foe, "the leader's target"),
  foeTargetingMe(GambitSide.foe, 'targeting me'),
  foeTargetingAlly(GambitSide.foe, 'targeting an ally'),
  foeLowestHp(GambitSide.foe, 'lowest HP'),
  foeHighestHp(GambitSide.foe, 'highest HP'),
  foeInReach(GambitSide.foe, 'in reach'),
  foeCrowd(GambitSide.foe, '3 or more close'),
  foeUndead(GambitSide.foe, 'undead'),
  foeShoots(GambitSide.foe, 'shoots'),
  foeElite(GambitSide.foe, 'elite or stronger'),
  foeHostile(GambitSide.foe, 'hostile'),
  selfHp30(GambitSide.self, 'HP < 30%'),
  selfHp50(GambitSide.self, 'HP < 50%'),
  selfMp50(GambitSide.self, 'MP ≥ 50%'),
  always(GambitSide.self, 'always');

  const GambitIf(this.side, this.words);
  final GambitSide side;
  final String words;
}

/// A gambit's action: an Attack, the healer's plain Heal, the member's type skill (M2: never fits in M1), Follow.
enum GambitDo { attack, heal, skill, follow }

/// One rule of a member's list: [when] → [act], switched on or off on its own.
class Gambit {
  Gambit(this.when, this.act, {this.on = true});
  final GambitIf when;
  final GambitDo act;
  bool on;

  @override
  String toString() => '${when.name}->${act.name}';
}

/// "3 or more close": foes within this of each other count as one crowd.
const gambitCrowd = 40.0;

/// "being hit": an ally hurt within this many seconds.
const gambitHitFor = 1.0;

/// A troop type's default rules (the design's table, section 4): what a troop starts with when it has none of its own.
List<Gambit> defaultGambits(String type) {
  Gambit g(GambitIf w, GambitDo a) => Gambit(w, a);
  const atk = GambitDo.attack, skill = GambitDo.skill;
  return switch (type) {
    'soldier' => [g(GambitIf.selfHp30, skill), g(GambitIf.foeTargetingAlly, atk), g(GambitIf.foeLeaderTarget, atk), g(GambitIf.foeNearest, atk)],
    'knight' => [g(GambitIf.foeCrowd, skill), g(GambitIf.foeTargetingAlly, atk), g(GambitIf.foeLeaderTarget, atk), g(GambitIf.foeNearest, atk)],
    'swordsman' => [g(GambitIf.foeElite, skill), g(GambitIf.foeLeaderTarget, atk), g(GambitIf.foeNearest, atk)],
    'archer' => [g(GambitIf.foeCrowd, skill), g(GambitIf.foeLowestHp, atk), g(GambitIf.foeLeaderTarget, atk), g(GambitIf.foeNearest, atk)],
    'lancer' => [g(GambitIf.foeCrowd, skill), g(GambitIf.foeLeaderTarget, atk), g(GambitIf.foeNearest, atk)],
    'priest' => [g(GambitIf.allyHp50, GambitDo.heal), g(GambitIf.allyHp70, skill), g(GambitIf.foeUndead, atk)],
    'armored_axeman' => [g(GambitIf.foeCrowd, skill), g(GambitIf.foeLeaderTarget, atk), g(GambitIf.foeNearest, atk)],
    'wizard' => [g(GambitIf.foeCrowd, skill), g(GambitIf.foeLeaderTarget, atk), g(GambitIf.foeNearest, atk)],
    'knight_templar' => [g(GambitIf.allyHit, skill), g(GambitIf.foeTargetingAlly, atk), g(GambitIf.foeNearest, atk)],
    _ => [g(GambitIf.foeNearest, atk)],
  };
}

/// The rules' reading (dungeon.dart calls it).
extension Gambits on Game {
  /// The first of [u]'s rules that fits now, as (its index, the action), or null when none does (it follows the
  /// leader). [keep]: the action it holds; the same rule keeps that target while its condition still holds for it.
  (int, Act)? readGambits(Unit u, {Act? keep}) {
    final d = dungeon!, rules = d.rulesOf(u);
    for (var i = 0; i < rules.length; i++) {
      final r = rules[i];
      if (!r.on || !gambitPaid(u, r.act)) continue;
      if (r.act == GambitDo.follow) return (i, Act(ActKind.follow, null, rule: i));
      if (keep != null && keep.rule == i && keep.target != null && gambitHolds(u, r.when, keep.target!)) {
        return (i, Act(keep.kind, keep.target, rule: i));
      }
      final target = gambitTarget(u, r.when, r.act);
      if (target == null) continue;
      return (i, Act(r.act == GambitDo.heal ? ActKind.heal : ActKind.attack, target, rule: i));
    }
    return null;
  }

  /// Whether [u] can pay for [act] now: an Attack always (a healer's is its smite), a Heal only a healer with its MP
  /// ([DungeonTrip.healCostOf]), a skill never in M1, Follow always.
  bool gambitPaid(Unit u, GambitDo act) => switch (act) {
        GambitDo.attack || GambitDo.follow => true,
        GambitDo.heal => u.stats.heals && u.mp >= healCostOf(u),
        GambitDo.skill => false, // the skills come inside in M2
      };

  /// The target condition [w] finds for [u]'s [act] now, or null. A foe condition looks only at the hostile foes in
  /// sight of the leader ([Dungeon.sight]): a neutral monster at peace is attacked only by the player's command. A self
  /// condition targets: [u] itself for a heal, else the nearest hostile foe.
  Unit? gambitTarget(Unit u, GambitIf w, GambitDo act) {
    final d = dungeon!;
    final allies = [for (final o in d.party) if (d.standing(o)) o];
    final foes = d.foesInSight(this);
    Unit? nearest(Iterable<Unit> xs) {
      Unit? best;
      var bd = double.infinity;
      for (final o in xs) {
        final dd = o.pos.distanceTo(u.pos);
        if (dd < bd) (best, bd) = (o, dd);
      }
      return best;
    }

    Unit? lowestShare(Iterable<Unit> xs) {
      Unit? best;
      for (final o in xs) {
        if (best == null || o.hp / o.maxHp < best.hp / best.maxHp) best = o;
      }
      return best;
    }

    switch (w.side) {
      case GambitSide.ally:
        final hits = allies.where((o) => gambitHolds(u, w, o));
        return w == GambitIf.allyLeader ? hits.firstOrNull : lowestShare(hits);
      case GambitSide.foe:
        final hits = foes.where((o) => gambitHolds(u, w, o)).toList();
        if (hits.isEmpty) return null;
        return switch (w) {
          GambitIf.foeLowestHp => lowestShare(hits),
          GambitIf.foeHighestHp => hits.reduce((a, b) => b.hp > a.hp ? b : a),
          _ => nearest(hits),
        };
      case GambitSide.self:
        if (!gambitHolds(u, w, u)) return null;
        return act == GambitDo.heal ? u : nearest(foes);
    }
  }

  /// Whether condition [w] holds for [o] as [u] reads it (a self condition reads [u] itself, whatever [o]).
  bool gambitHolds(Unit u, GambitIf w, Unit o) {
    final d = dungeon!;
    double share(Unit x) => x.hp / max(1, x.maxHp);
    if (w.side == GambitSide.ally && (o.side != Side.troop || (w != GambitIf.allyDown && !d.standing(o)))) return false;
    if (w.side == GambitSide.foe && (o.side != Side.enemy || !o.alive || !d.hostile(o))) return false;
    return switch (w) {
      GambitIf.allyHp50 => share(o) < 0.5,
      GambitIf.allyHp70 => share(o) < 0.7,
      GambitIf.allyHp30 => share(o) < 0.3,
      GambitIf.allyDown => d.minds[o]?.down ?? false,
      GambitIf.allyHit => t - o.hurtAt < gambitHitFor,
      GambitIf.allyStunned => t < o.stunUntil,
      GambitIf.allyMp30 => o.stats.mp > 0 && o.mp < o.stats.mp * 0.3,
      GambitIf.allyLeader => o == d.leader,
      GambitIf.foeNearest || GambitIf.foeHostile || GambitIf.foeLowestHp || GambitIf.foeHighestHp => true,
      GambitIf.foeLeaderTarget => d.minds[d.leader]?.act?.target == o,
      GambitIf.foeTargetingMe => d.minds[o]?.prey == u,
      GambitIf.foeTargetingAlly => d.minds[o]?.prey != null && d.minds[o]!.prey != u,
      GambitIf.foeInReach => reaches(u, o),
      GambitIf.foeCrowd => units.where((x) => x.side == Side.enemy && x.alive && x.pos.distanceTo(o.pos) <= gambitCrowd).length >= 3,
      GambitIf.foeUndead => o.stats.dark,
      GambitIf.foeShoots => o.stats.shotSpeed > 0,
      GambitIf.foeElite => o.tier.index >= Tier.elite.index,
      GambitIf.selfHp30 => share(u) < 0.3,
      GambitIf.selfHp50 => share(u) < 0.5,
      GambitIf.selfMp50 => u.stats.mp > 0 && u.mp >= u.stats.mp * 0.5,
      GambitIf.always => true,
    };
  }
}
