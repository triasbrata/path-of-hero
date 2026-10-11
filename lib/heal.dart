part of 'game.dart';

// The heal funnel (catalog step 0e, decisions-log 181; docs/units-and-combat.md "Heals"): every heal a troop gets lands
// in one place, [Heal._healTroop], tagged with where it came from ([HealSrc]). There Wound, a Bayangan (the enemy's
// hidden buff, omen.dart), cuts the troops' heals in a wave, never the Grail's save or the after-wave heal
// ([HealKind]), and Trickle, Scar and Heal Siphon act after it; the catalog's heal Pusaka read what a heal gave past
// full HP. A monster's heal is no troop heal: it
// lands in its own funnel, [Heal._healMonster] (step 0g, decisions-log 184), where [Status.noHeal] makes it 0; the sites
// both sides share go through [Heal._healUnit]. And the ward: a troop's shield, up to [wardMax] of its max HP, that a
// blow breaks before its HP ([Heal._wardSoak]) and that ends with the wave. The ward Fx grant it ([Heal.giveWard]: batch
// L-2P's Watch Shield at a wave's start, Bone Buckler on a kill; batch L-3's Full Cup from a healer's heal past full).

/// Where a troop's heal comes from: the tag of every [Heal._healTroop].
enum HealSrc {
  /// A troop healer's heal ([Game._castHeal]).
  heal,

  /// Healing Prayer, the priest's skill.
  prayer,

  /// [Status.heal], a share each second (Blessing, a Hero skill).
  overTime,

  /// [Status.lifesteal]: a share of the damage it deals (Bloodlust, a Hero skill).
  lifesteal,

  /// [Status.killHeal]: a share of its max HP for each kill (Last Stand, a Hero skill).
  killHeal,

  /// Sacrifice, a Hero skill: the HP another troop gives it.
  sacrifice,

  /// Unbroken, an awakening skill: itself and the troops near.
  unbroken,

  /// Lifeline, an awakening skill: the troop carried, when it is set down.
  lifeline,

  /// Its [Stats.regen], every tick (Dragon Heart's, Living Moss's), between waves too.
  regen,

  /// A worn fang ([Relic.fang]): a share of the damage it deals.
  fang,

  /// A Pusaka's `heal` Fx ([Eff.heal]: Blood Fang, Mourning Bell; Wolf Feast, Hidden Flask).
  pusaka,

  /// The after-wave heal ([Game.healQueue]): its full HP back, carried into the next wave or not.
  queue,

  /// The Grail's save ([FxEngine._fxLethal]): from nothing to its share of max HP.
  grail,

  /// Iron Will ([Relic.lastStand], relics.dart): once a wave, a share of its max HP when a blow leaves it low.
  lastStand,
}

/// What a heal is to Wound: one in a wave (Wound cuts it), between waves (the rest, and the after-wave heal even
/// carried into a wave), or the Grail's save. Wound cuts only the first ([Heal._healTroop]).
enum HealKind { inWave, between, grail }

/// Where a monster's heal comes from: the tag of every [Heal._healMonster].
enum MonsterHeal {
  /// A healing necromancer's heal ([Game._castHeal]).
  heal,

  /// Mass Mend, the healing necromancer's skill (monster_skills.dart).
  massMend,

  /// Last Rites, the healing necromancer boss's moment: the monsters near it.
  lastRites,

  /// Second Wind, the orc rider boss's moment: itself.
  secondWind,

  /// Soul Drain, the necromancer's skill: a share of what each drain takes.
  drain,

  /// Swoop, the bat's skill: a share of what the bite takes.
  bite,

  /// [Status.lifesteal]: a share of the damage it deals (Bloodrage).
  lifesteal,

  /// Its [Stats.regen], every tick (the Bayangan's Mend, while the omens are on: [Omens.spawnStats]).
  regen,

  /// [Status.heal], a share each second (no monster gets it yet).
  overTime,

  /// Reassemble, a skeleton's: it stands again from its heap of bones ([reassembleK]).
  reassemble,

  /// The Bayangan Feed: a share of what its blow took off a troop ([Omens._omenFeed]).
  feed,

  /// The Bayangan Gloat: a share of its max HP when it kills a troop ([Omens._omenGloat]).
  gloat,

  /// The Bayangan Rekindle: a high elite's share of its max HP when its skill lands ([Omens._omenRekindle]).
  rekindle,

  /// The Bayangan Parting Gift: a share of its max HP when a monster near it dies ([Omens._omenPartingGift]).
  partingGift,

  /// The Bayangan Blood Moon: a wolf's or a bear's omen lifesteal, a share of what it deals ([Omens._omenSpawn]).
  bloodMoon,

  /// The Bayangan Heal Siphon: a share of what the troops near it healed ([Omens._omenSiphon]).
  siphon,

  /// The Bayangan Last Gasp: the boss's or a mini boss's share of its max HP, once, at a line ([Omens._omenLastGasp]).
  lastGasp,
}

/// A troop heal the Bayangan Trickle spreads ([Heal._healTroop], [Unit.trickle]): it pays [rate] HP a second from
/// [paidTo], the time it last paid, until its own [end] ([Omens._omenTrickle]), so a newer heal never moves it. Not saved:
/// it ends with the wave.
class TrickleHeal {
  TrickleHeal(this.rate, this.end, this.paidTo);
  final double rate, end;
  double paidTo;
}

/// The funnel and the ward.
extension Heal on Game {
  /// What [src]'s heal is now: the Grail's save and the after-wave heal are always theirs; any other is in a wave while
  /// one is fought ([Game.waveActive]), else between waves (regen while they rest, a heal landing after the win).
  HealKind healKind(HealSrc src) => switch (src) {
        HealSrc.grail => HealKind.grail,
        HealSrc.queue => HealKind.between,
        _ => waveActive ? HealKind.inWave : HealKind.between,
      };

  /// Wound's factor on a troop's heals in a wave: 1 − perE × E of its effective level E, at most its `max` ([Omens.omenK]):
  /// 1 with no Wound or while the Bayangan are off; [Game.woundForce] in its place for a test or a probe.
  double get _woundK => woundForce ?? 1 - omenK(OmenKind.wound);

  /// Every heal troop [u] gets: [amount] HP from [src], never past its max HP; a Mercy Lily on its type makes it ×its k
  /// first while [u] is low, a Rage Totem ×its trade's k under 1 ([FxEngine._fxLily]: not the Grail's save nor the
  /// after-wave heal; [Game.onTroopHeal] still hears the [amount] asked, and Mercy Lily's counter gets what the × added).
  /// In a wave ([healKind]) Blood Oath's cost ([Pusaka._oathHealK], decisions-log 247) cuts it first. Then the Bayangan act in
  /// the funnel's order: Wound's factor ([_woundK]) cuts it first; Trickle spreads one of [omenTrickled]'s kinds over its
  /// time as its own entry ([TrickleHeal], paid by [Omens._omenTrickle]); Scar's ceiling stops it at 1 − its share of the
  /// max HP ([Omens.healCeil]), never lowering the HP [u] has (a spread heal's at each payment); under Blight
  /// ([Omens.blighted]) nothing lands, nothing goes past full and no `heals` Fx runs on it; and Heal Siphon owes its
  /// share of the HP it gives ([Unit.siphonDue]). Returns the heal past full HP (what it gave beyond the HP [u] lacked
  /// to its real max HP, a ceiling or not: the If `healPastFull`; a spread heal's counted against the HP and what is
  /// still to come, [Omens.trickleLeft]); a site reads the HP it gave as [Game._healGained] (a spread heal's in full at
  /// the call). [Game.onTroopHeal] hears each.
  double _healTroop(Unit u, double amount, HealSrc src) {
    assert(u.side == Side.troop, 'a monster heal in the troop funnel: $src');
    final lily = pusaka.isEmpty ? null : _fxLily(u, src); // Mercy Lily: a heal on a low troop of its type lands bigger (pusaka_engine.dart)
    // The factors first: [healKind] reads [Game.waveActive], a walk over the units.
    final asked = amount, k = _woundK, scar = omenK(OmenKind.scar), slow = omenK(OmenKind.trickle), siphon = omenK(OmenKind.healSiphon);
    final blight = omensOn && blighted(u), blood = _oathHealK; // the Bayangan Blight: nothing lands (omen.dart); Blood Oath's cost (pusaka.dart)
    if (lily != null) amount *= lily.k;
    if (u.relics.isNotEmpty) amount *= charmK(u, src); // Holy Charm: heals on it bigger (relics.dart)
    final inWave = (k != 1 || scar > 0 || slow > 0 || siphon > 0 || blight || blood != 1) && healKind(src) == HealKind.inWave;
    if (inWave && blood != 1) amount *= blood;
    if (inWave && k != 1) amount *= k;
    final full = u.maxHp.toDouble(), before = u.hp;
    final double past;
    final spread = inWave && slow > 0 && omenTrickled.contains(src) && !blight;
    if (inWave && blight) {
      past = 0;
      _healGained = 0;
    } else if (spread) {
      final to = u.hp + trickleLeft(u) + amount;
      past = to > full ? min(amount, to - full) : 0.0;
      u.trickle.add(TrickleHeal(amount / slow, t + slow, t));
      _healGained = amount - past;
    } else {
      final to = u.hp + amount;
      past = to > full ? to - full : 0.0;
      u.hp = inWave && scar > 0 ? max(u.hp, min(full * (1 - scar), to)) : min(full, to);
      _healGained = u.hp - before;
    }
    if (inWave && siphon > 0 && _healGained > 0) u.siphonDue += _healGained * siphon; // Heal Siphon (omen.dart)
    onTroopHeal?.call(u, src, asked, past);
    if (!spread) _healGained = u.hp - before; // what landed, read after a listener
    if (lily != null && lily.k > 1 && _healGained > 0) { // a trade (Rage Totem's, under 1) counts nothing
      _tally(lily.relic)
        ..uses += 1
        ..worth += _healGained * (1 - 1 / lily.k); // what its × added
    }
    return past;
  }

  /// A heal of [amount] on [u] at a site both sides share (a healer's heal, regen, the heal statuses): a troop's
  /// through its funnel ([_healTroop], tagged [src]), a monster's through its own ([_healMonster], its tag for [src]).
  /// Returns the troop's heal past full HP (a monster's: 0).
  double _healUnit(Unit u, double amount, HealSrc src) {
    if (u.side == Side.troop) return _healTroop(u, amount, src);
    _healMonster(u, amount, switch (src) {
      HealSrc.regen => MonsterHeal.regen,
      HealSrc.overTime => MonsterHeal.overTime,
      HealSrc.lifesteal => MonsterHeal.lifesteal,
      _ => MonsterHeal.heal, // a healing necromancer's; a troop's other heals never reach a monster
    });
    return 0;
  }

  /// Whether monster [u] heals nothing now ([Status.noHeal]).
  bool noHealOn(Unit u) => u.effects.isNotEmpty && under(u, Status.noHeal);

  /// Every heal monster [u] gets: [amount] HP from [src], never past its max HP (or, given [atLeast], up to that HP:
  /// Reassemble's stand); none while it is under [Status.noHeal] (a skeleton under it doesn't reassemble either:
  /// [MonsterSkillSignatures._reassembles]), and what it would have gained goes to the counter of the Pusaka that sealed
  /// it ([FxEngine._fxSealed]: Grave Seal's). A monster healer's heal or Mass Mend that gave HP brings the Bayangan
  /// Zeal's might ([Omens._omenZeal]). Returns the HP it gained. [Game.onMonsterHeal] hears each.
  double _healMonster(Unit u, double amount, MonsterHeal src, {double? atLeast}) {
    assert(u.side == Side.enemy, 'a troop heal in the monster funnel: $src');
    final before = u.hp, to = atLeast != null ? max(u.hp, atLeast) : min(u.maxHp.toDouble(), u.hp + amount);
    if (!noHealOn(u)) {
      u.hp = to;
    } else if (pusaka.isNotEmpty) {
      _fxSealed(u, to - before); // the heal a seal stopped (pusaka_engine.dart)
    }
    onMonsterHeal?.call(u, src, atLeast != null ? max(0.0, atLeast - before) : amount, u.hp - before);
    if (omensOn && u.hp > before && (src == MonsterHeal.heal || src == MonsterHeal.massMend)) _omenZeal(u); // Zeal (omen.dart)
    return u.hp - before;
  }

  /// Gives troop [u] [amount] HP of ward, its shield, up to [most] of its max HP (never past [wardMax]); a ward already
  /// over that stays. A Pusaka that added some ([from]) is the one whose shield it is now ([Unit.wardFrom]: its counter
  /// gets what the ward soaks). Returns what it added. Not saved; it ends with the wave ([HeroSkills._endEffects]).
  double giveWard(Unit u, double amount, {double most = wardMax, Relic? from}) {
    assert(u.side == Side.troop, 'a ward on a monster');
    final before = u.ward;
    u.ward = max(before, min(before + amount, u.maxHp * min(most, wardMax)));
    if (u.ward > before && from != null) u.wardFrom = from;
    return u.ward - before;
  }

  /// A blow of [dmg] on troop [u] from [by], after every cut ([Game._hurt]): its ward soaks what it can first (a
  /// monster's blow breaks it sooner under the Bayangan Shieldbreak, [Omens._omenSoak]). What is left for its HP.
  double _wardSoak(Unit u, double dmg, Unit? by) {
    final (lost, left) = _omenSoak(u, by, dmg, u.ward);
    u.ward -= lost;
    if (lost > 0) _fxWardSoaked(u, lost); // the counter of the Pusaka whose shield it is (pusaka_engine.dart)
    return left;
  }
}
