part of 'game.dart';

// #59 branch 2b: the rest of the high elites' signature skills (docs/units-and-combat.md, "Monster skills",
// "Branch 2b"), plugged into monster_skills.dart by one arm in each of its switches: the werebear's Maul, the
// necromancer's Curse of Frailty, and the skeleton's Reassemble, which is passive: it answers the blow that
// would kill it ([MonsterSkillSignatures._reassembles], from [Game._hurt]) rather than being cast.

/// Reassemble: a skeleton of high elite rank or more ([monsterSkillOf]) that takes its first killing blow,
/// unless the blow is holy ([MonsterSkillSignatures._holyHurt]), falls into a heap of bones for [down] s
/// instead of dying ([Unit.downUntil]), then stands again at [stand] of its max HP (a mini boss or boss:
/// [strong]). A heap takes only holy damage, and any holy blow ends it for good; the troops' own attacks pass
/// it by.
const reassembleK = (down: 2.0, stand: 0.3, strong: 0.5);

/// Maul (werebear): with a troop in its reach, after its long wind-up (the tell) one blow at the nearest for
/// [hit]× its damage (a mini boss's or boss's: [strong]×; the cap still holds) that knocks it back [shove]
/// ([HeroMoves.knockBack]: a Hero half, a troop holding its ground not at all).
const maulK = (hit: 2.5, strong: 3.0, shove: tile);

/// Curse of Frailty (necromancer): with [crowd]+ troops within [reach], each of them takes [taken]× from
/// monsters for [time] s ([Status.vulnerable], by the necromancer; a mini boss's or boss's: [strong]×).
const curseOfFrailtyK = (crowd: 3, reach: 3 * tile, time: 5.0, taken: 1.15, strong: 1.2);

extension MonsterSkillSignatures on Game {
  /// Whether monster [u]'s branch-2b skill [s] (its signature, [monsterSkillOf]) would do something now, by its
  /// rule.
  bool _wantsSignatureSkill(Unit u, MonsterSkill s) => switch (s) {
        MonsterSkill.maul => _troopsNear(u.pos, u.stats.range).isNotEmpty,
        MonsterSkill.curseOfFrailty => _troopsNear(u.pos, curseOfFrailtyK.reach).length >= curseOfFrailtyK.crowd,
        MonsterSkill.reassemble => false, // passive: the killing blow sets it off ([_reassembles])
        _ => false,
      };

  /// Monster [u]'s branch-2b skill [s] lands, its wind-up over.
  void _castSignatureSkill(Unit u, MonsterSkill s) {
    final strong = _bossRank(u);
    switch (s) {
      case MonsterSkill.maul:
        final o = _troopsNear(u.pos, u.stats.range).firstOrNull; // it may have stepped away meanwhile
        if (o == null) return;
        u.attackedAt = t;
        _face(u, o.pos.x - u.pos.x, 0);
        impacts.add((o.pos, 'hit_${u.type}_big'));
        _skillBlow(u, o, strong ? maulK.strong : maulK.hit);
        knockBack(o, maulK.shove);
        sfx.add(Sfx.hit);
      case MonsterSkill.curseOfFrailty:
        final near = _troopsNear(u.pos, curseOfFrailtyK.reach);
        if (near.isEmpty) return;
        u
          ..attackedAt = t
          ..swung = false; // its cast strip
        for (final o in near) {
          addEffect(o, Status.vulnerable, curseOfFrailtyK.time, k: strong ? curseOfFrailtyK.strong : curseOfFrailtyK.taken, by: u, bad: true);
          impacts.add((o.pos, 'hit_${u.type}'));
        }
        sfx.add(Sfx.magic);
      case MonsterSkill.reassemble:
        return; // passive: never wound up
      default:
        return;
    }
  }

  /// [_hurt]: the blow that would kill monster [u] just landed. Whether it reassembles instead
  /// ([reassembleK]): once a life, never from a holy blow, never while it is a slime (Slime Hex), never with
  /// [Game.monsterSkills] off, never under [Status.noHeal] (its bones can't pull together: a troop's Grave Seal, whose
  /// mark the killing blow puts on first). Its HP stays above 0 while it lies, so nothing counts it as fallen; it pops
  /// its title and logs the cast. It stands again through the monster heal funnel ([Heal._healMonster]).
  bool _reassembles(Unit u) {
    if (!monsterSkills || _holy || u.reassembled || monsterSkillOf(u) != MonsterSkill.reassemble || noHealOn(u)) return false;
    final stand = u.maxHp * (_bossRank(u) ? reassembleK.strong : reassembleK.stand);
    u
      ..hp = min(1.0, stand)
      ..reassembled = true
      ..downUntil = t + reassembleK.down
      ..moving = false;
    _cancelWind(u); // a boss's moment it was winding up is tried again later
    monsterCasts.add((u, MonsterSkill.reassemble));
    _emit(MonsterSkillCast(wave, t, type: u.type, tier: u.tier, skill: MonsterSkill.reassemble));
    sfx.add(Sfx.hit);
    later(reassembleK.down, () {
      if (u.alive) _healMonster(u, 0, MonsterHeal.reassemble, atLeast: stand); // it stands again
    });
    return true;
  }

  /// [by]'s holy blow of [dmg] on [o] ([_hurt] with [Game._holy] on), from [src]: a troop healer's light on the undead
  /// ([Game._smite], [Hit.smite]), Holy Nova, Judgement ([Hit.skill]). It never lets a skeleton reassemble, and it ends a heap of bones for
  /// good. (Exorcism is holy too, but it only strikes raised minions, which never reassemble.)
  void _holyHurt(Unit o, double dmg, Unit by, Hit src) {
    _holy = true;
    _hurt(o, dmg, src, by);
    _holy = false;
  }
}
