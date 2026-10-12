part of 'game.dart';

// The small relics the Smithy crafts (decisions-log 227; town-design rev 2 §6; docs/loot-items-relics.md "Relics"). A
// small relic ([RelicScope.troop]) is held by ONE troop (a Hero two, different kinds), changes no stat and acts in the
// fight. Today's four (Fang, Thorns, Fury, Guard: the Basic tier) keep their rules in game.dart and pusaka_engine.dart;
// the seven here are new: Strong Sweep (save key cleave), Venom, Mana Siphon and Spirit Ward, Mighty Iron Will (lastStand),
// Giant Slayer and Holy Charm (blessing). Their numbers are town.json's `relics` ([TownRules.relics], read through
// [Relics.relicK]); their tier is their recipe's ([TownRules.recipes]). Monsters never drop them: the Smithy makes them
// (decisions-log 221).
//
// Where each acts (all existing sites): a troop's normal attack that lands, a blow ([Game._strike]) or a shot, and a
// healer's smite ([Game._smite]), call [Relics._relicLanded] (Sweep, Venom, Mana Siphon); a troop healer's heal
// ([Game._castHeal]) calls [Relics._relicHealed] (Mana Siphon); [Game._hurt] multiplies a normal attack's or a smite's
// blow on a mini boss or the boss ([Relics._slayerK]: Giant Slayer) and, once the blow has landed, asks
// [Relics._ironWill]; [Game.startWave] gives the wards ([Relics._spiritWards]); the heal funnel ([Heal._healTroop])
// makes a heal bigger ([Relics.charmK]: Holy Charm).
//
// The forge's nine (decisions-log 250; forge-design §5, §6), in every game (the forge comes with the Towns,
// decisions-log 296, 321): a normal attack or a smite as it is made ([Game._strike], [Game._smite]) is multiplied by [Relics._relicBlowK] (Shark
// Tooth, Grit, Ambush, Hot Streak, Avalanche, Afterglow, Reaper on a boss), so a shot carries it and so does all that
// reads the blow as fired (a splash, Sweep, Venom, God's Thunder's leaps); that product with the Fury beat and Giant
// Slayer is at most town.json's `combos.relicMost` ([Combos.relicMost]: the relics' cap; the Artifacts' own powers stay
// outside it). On landing [Relics._relicLanded] adds Chill's slow and Weak Spot's mark; [Game._hurt] asks [Relics._reap]
// (Reaper's end), counts what Weak Spot's mark and each pair did ([Relics._relicDealt]) and Hot Streak's kills
// ([Relics._relicKill]); a skill's cast charges Afterglow ([Relics._relicCast]). The hidden pairings
// ([Combos.secrets], described nowhere in the game) change a relic's numbers for a holder that has their partner
// ([Relics.relicKOf]). No card names a partner or a combo.

/// Every small relic ([RelicScope.troop]) but the forge's, in [Relic] order: today's four, then the Smithy's seven. The
/// forge's nine ([forgeRelics], decisions-log 245) come after them in a game with the Towns ([Relics.relicsInPlay]).
final smallRelics = [for (final r in Relic.values) if (r.scope == RelicScope.troop && !forgeRelics.contains(r)) r];

/// Who each small relic suits (town-design rev 2 §6): a hint in its texts ("Best on: …"), nothing refuses a type. A
/// troop type's key, or a few words for a group.
const relicBestOn = <Relic, List<String>>{
  Relic.fang: ['knight', 'knight_templar', 'lancer', 'swordsman'],
  Relic.thorns: ['knight', 'knight_templar', 'armored_axeman'],
  Relic.fury: ['archer', 'wizard', 'swordsman'],
  Relic.guard: ['front melee', 'Heroes'],
  Relic.cleave: ['soldier', 'knight', 'armored_axeman', 'knight_templar'],
  Relic.venom: ['archer', 'swordsman', 'lancer'],
  Relic.manaSiphon: ['wizard', 'priest', 'archer'],
  Relic.spiritWard: ['soldier', 'knight', 'lancer'],
  Relic.lastStand: ['front melee', 'Heroes'],
  Relic.giantSlayer: ['lancer', 'swordsman', 'archer'],
  Relic.blessing: ['knight', 'knight_templar', 'armored_axeman'],
  // The forge's nine (decisions-log 245; forge-design §5).
  Relic.chill: ['archer', 'swordsman', 'soldier'],
  Relic.sharkTooth: ['archer', 'swordsman', 'lancer'],
  Relic.grit: ['knight', 'armored_axeman', 'knight_templar'],
  Relic.ambush: ['lancer', 'knight', 'swordsman'],
  Relic.weakSpot: ['archer', 'wizard', 'priest'],
  Relic.hotStreak: ['soldier', 'armored_axeman', 'swordsman'],
  Relic.avalanche: ['armored_axeman', 'soldier', 'knight'],
  Relic.afterglow: ['wizard', 'archer', 'knight_templar'],
  Relic.reaper: ['archer', 'lancer', 'swordsman'],
};

/// The small relics' rules and words.
extension Relics on Game {
  /// The small relics in this game: all of them ([smallRelics], then the forge's nine, [forgeRelics]).
  List<Relic> get relicsInPlay => [...smallRelics, ...forgeRelics];

  /// The items in this game (decisions-log 245): all of [Item]. Every list of items the player sees (the Bag, the Shop,
  /// the guide) reads it.
  List<Item> get itemsInPlay => Item.values;

  /// Small relic [relic]'s number [key] (town.json `relics.<relic>.<key>`: Sweep's `share`, Venom's `secs`, …), its
  /// default when the rules lack it.
  double relicK(Relic relic, String key) => (townRules.relics[relic.name]?[key] ?? _townRelicNumbers[relic.name]![key]!).toDouble();

  /// Small relic [relic]'s tier: its Smithy recipe's (town.json `recipes`); a relic without one is Basic.
  RelicTier relicTier(Relic relic) => townRules.recipes[relic.name]?.tier ?? RelicTier.basic;

  /// The tier line of [relic]'s texts: "Strong relic".
  String relicTierLine(Relic relic) => '${Words.relicTiers[relicTier(relic).name]} ${Words.relic.toLowerCase()}';

  /// The "Best on: Knight, Templar, Lancer" line of [relic]'s texts ([relicBestOn]), or null for one without.
  String? relicBestLine(Relic relic) => switch (relicBestOn[relic]) {
        final types? => '${Words.bestOn}: ${types.map((t) => troopTypeNames[t] ?? '${t[0].toUpperCase()}${t.substring(1)}').join(', ')}',
        _ => null,
      };

  /// What one of the Smithy's seven or the forge's nine does, in the book's words, from the rules' numbers
  /// ([Game.relicEffect]).
  List<String> _newRelicEffect(Relic relic) {
    String share(double s) => '${(s * 100).round()}%';
    String n(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
    return switch (relic) {
      Relic.cleave => ['Hits 1 more monster near the target for ${share(relicK(relic, 'share'))}'],
      Relic.venom => ['Poisons: +${share(relicK(relic, 'share'))} of the hit over ${n(relicK(relic, 'secs'))} s'],
      Relic.manaSiphon => ['+${n(relicK(relic, 'mp'))} ${Words.mp} each hit or heal'],
      Relic.spiritWard => ['Shield ${share(relicK(relic, 'share'))} HP each wave'],
      Relic.lastStand => ['Once a wave: heals ${share(relicK(relic, 'heal'))} HP below ${share(relicK(relic, 'below'))}'],
      Relic.giantSlayer => ['x${n(relicK(relic, 'k'))} damage to mini boss and boss'],
      Relic.blessing => ['Heals on it +${share(relicK(relic, 'k') - 1)}'],
      // The forge's nine (decisions-log 245): each card says only its own effect.
      Relic.chill => [
          'Every ${_nth(relicK(relic, 'every').round())} hit slows ${share(relicK(relic, 'slow'))} for ${n(relicK(relic, 'secs'))} s'
              '${relicK(relic, 'bossShare') < 1 ? ' (bosses ${share(relicK(relic, 'bossShare') * relicK(relic, 'slow'))})' : ''}',
        ],
      Relic.sharkTooth => ['x${n(relicK(relic, 'k'))} damage to a bleeding or poisoned monster'],
      Relic.grit => ['x${n(relicK(relic, 'k'))} damage while under ${share(relicK(relic, 'below'))} HP'],
      Relic.ambush => ['x${n(relicK(relic, 'k'))} damage to a slowed, pinned, stunned or hexed monster'],
      Relic.weakSpot => [
          'Hits mark a monster ${n(relicK(relic, 'secs'))} s: it takes +${share(relicK(relic, 'taken') - 1)} from all'
              ' (bosses +${share(relicK(relic, 'boss') - 1)})',
        ],
      Relic.hotStreak => [
          'Each kill: +${share(relicK(relic, 'per'))} damage for ${n(relicK(relic, 'secs'))} s, up to ${relicK(relic, 'most').round()}',
        ],
      Relic.avalanche => [
          '+${share(relicK(relic, 'per'))} damage per other monster within ${n(relicK(relic, 'reach'))} tiles of its target, up to'
              ' ${relicK(relic, 'most').round()}',
        ],
      Relic.afterglow => ['After a skill, its next ${relicK(relic, 'hits').round()} hits deal x${n(relicK(relic, 'k'))}'],
      Relic.reaper => [
          'Ends a monster under ${share(relicK(relic, 'below'))} HP at once (bosses: x${n(relicK(relic, 'bossK'))} damage)',
        ],
      _ => const [],
    };
  }

  /// Troop [by]'s normal attack landed on monster [foe] with [dmg] (its blow or shot as fired, before [foe]'s defence:
  /// a fury's and its type's Artifacts' power in), [src] [Hit.normal], or a healer's smite ([Hit.smite]). Not on a blow
  /// the Bayangan Deflect turned away; a normal shot's splash counts once, on its target.
  /// - Sweep: the nearest other monster within its `reach` tiles of [foe] takes its `share` of [dmg] ([Hit.relic]: never
  ///   a hit of its own, so it never sweeps again, nor poisons). Blows and shots, not smites.
  /// - Venom: [foe] bleeds its `share` of [dmg] over its `secs` s, a tick a second ([Status.bleed], as Deep Wound's and
  ///   Bleeding Edge's); a stronger bleed already on it stays ([HeroSkills.addEffect]), so poisons never stack. Blows and
  ///   shots, not smites.
  /// - Mana Siphon: [by] gets its `mp` MP, never past its max.
  /// - Chill (the forge's): every its `every`th normal attack that lands slows [foe] its `slow` for its `secs` s
  ///   ([Status.slow]; a mini boss or the boss its `bossShare` of that), on its own count ([Unit.chillHits]).
  /// - Weak Spot (the forge's): a blow, shot or smite marks [foe] for its `secs` s: it takes its `taken` from every troop
  ///   (a mini boss or the boss its `boss`), as [Status.vulnerable] (Hunter's Mark's, so the stronger mark stays).
  void _relicLanded(Unit by, Unit foe, double dmg, Hit src) {
    if (by.side != Side.troop || foe.side != Side.enemy) return;
    if (src == Hit.normal && by.holds(Relic.cleave)) _sweep(by, foe, dmg);
    if (src == Hit.normal && by.holds(Relic.venom) && foe.alive) _venom(by, foe, dmg);
    if (by.holds(Relic.manaSiphon) && by.alive) _siphonMp(by);
    if (!foe.alive) return;
    if (src == Hit.normal && by.holds(Relic.chill)) _chill(by, foe);
    if (by.holds(Relic.weakSpot)) _weakSpot(by, foe);
  }

  /// Troop healer [by] healed a troop ([Game._castHeal]): Mana Siphon's MP.
  void _relicHealed(Unit by) {
    if (by.holds(Relic.manaSiphon) && by.alive) _siphonMp(by);
  }

  /// Sweep's hit: the nearest other monster within its `reach` of [foe]; its `targets` of them, nearest first (one, or
  /// a hidden pairing's more: [relicKOf]).
  void _sweep(Unit by, Unit foe, double dmg) {
    final reach = relicK(Relic.cleave, 'reach') * tile, targets = relicKOf(by, Relic.cleave, 'targets').round();
    final swept = <Unit>[];
    for (var i = 0; i < targets; i++) {
      Unit? next;
      var best = double.infinity;
      for (final o in units) {
        if (o == foe || o.side != Side.enemy || !o.alive || t < o.downUntil || swept.contains(o)) continue; // not a heap of bones (Reassemble)
        final d = o.pos.distanceTo(foe.pos);
        if (d <= reach && d < best) (next, best) = (o, d);
      }
      if (next == null) break;
      swept.add(next);
    }
    for (final next in swept) {
      impacts.add((next.pos, _fxOf(by, 'hit_${by.type}')));
      _hurt(next, dmg * relicK(Relic.cleave, 'share'), Hit.relic, by);
    }
  }

  void _venom(Unit by, Unit foe, double dmg) {
    final secs = relicK(Relic.venom, 'secs'), ticks = max(1, secs.round()), tick = dmg * relicKOf(by, Relic.venom, 'share') / ticks;
    if (tick > 0) addEffect(foe, Status.bleed, ticks + 0.5, k: tick, by: by, n: ticks);
  }

  void _siphonMp(Unit u) => u.mp = min(u.stats.mp.toDouble(), u.mp + relicK(Relic.manaSiphon, 'mp'));

  /// Giant Slayer's × on a blow of troop [by] on monster [u] ([Game._hurt], a normal attack's or a smite's, before
  /// defence): its `k` on a mini boss or the boss, else 1.
  double _slayerK(Unit by, Unit u) =>
      by.holds(Relic.giantSlayer) && u.side == Side.enemy && (u.tier == Tier.miniBoss || u.tier == Tier.boss) ? relicK(Relic.giantSlayer, 'k') : 1;

  /// Iron Will: a blow left troop [u] alive under its `below` share of its max HP: once a wave ([Unit.ironWillUsed],
  /// cleared at [Game.startWave]) it heals its `heal` share of its max HP at once, through the heal funnel
  /// ([HealSrc.lastStand]). A killing blow is the Grail's, never this.
  void _ironWill(Unit u) {
    if (u.ironWillUsed || !u.holds(Relic.lastStand) || u.hp >= u.maxHp * relicK(Relic.lastStand, 'below')) return;
    u.ironWillUsed = true;
    _healTroop(u, u.maxHp * relicK(Relic.lastStand, 'heal'), HealSrc.lastStand);
    impacts.add((u.pos, 'heal'));
  }

  /// Spirit Ward at a wave's start ([Game.startWave], after the Artifacts' `waveStart` Fx): each living troop holding one
  /// gets a shield of its `share` of its max HP ([Heal.giveWard], never past [wardMax]); it ends with the wave.
  void _spiritWards() {
    for (final u in troops) {
      if (u.alive && u.holds(Relic.spiritWard)) giveWard(u, u.maxHp * relicK(Relic.spiritWard, 'share'));
    }
  }

  /// Holy Charm's × on a heal from [src] landing on troop [u] ([Heal._healTroop], before Wound): its `k` when [u] holds
  /// one, else 1. Every heal but [u]'s own regen, and as Mercy Lily never the Grail's save or the after-wave heal (all
  /// its HP back anyway).
  double charmK(Unit u, HealSrc src) =>
      u.holds(Relic.blessing) && src != HealSrc.regen && src != HealSrc.grail && src != HealSrc.queue ? relicK(Relic.blessing, 'k') : 1;

  // The forge's nine (decisions-log 250; forge-design §5, §6).

  /// A mini boss or the boss: the "bosses" of the forge's relics' cards (Chill's and Weak Spot's half, Reaper's ×), as
  /// Giant Slayer's ([_slayerK]).
  bool _bossy(Unit u) => u.tier == Tier.miniBoss || u.tier == Tier.boss;

  /// Small relic [relic]'s number [key] for troop [u]: a hidden pairing's ([Combos.secrets], town.json `combos.secret`,
  /// described nowhere in the game) when [u] holds every relic it names and, when it names an Artifact, [u]'s type has
  /// that bound; else [relicK].
  double relicKOf(Unit u, Relic relic, String key) {
    if (u.relics.isNotEmpty) {
      for (final s in townRules.combos.secrets.values) {
        if (s.relic != relic || !s.holds.every(u.holds)) continue;
        if (s.set[key] case final v? when s.artifact == null || pusakaLevel(u, s.artifact!) > 0) return v.toDouble();
      }
    }
    return relicK(relic, key);
  }

  /// This wave's tally of the forge's relic [relic] ([Game.relicWorth]).
  PusakaTally _relicTally(Relic relic) => relicWorth[relic] ??= PusakaTally();

  /// What troop [u]'s normal attack or smite on monster [foe] is multiplied by as it is made ([Game._strike],
  /// [Game._smite]), [dmg] being the attack so far (its Artifacts' powers and the Fury beat in); the forge's nine, in
  /// [Relic] order:
  /// - Shark Tooth: its `k` on a bleeding or poisoned monster ([Status.bleed]: Venom's, Bleeding Edge's, a skill's).
  /// - Grit: its `k` while [u] is under its `below` share of its max HP.
  /// - Ambush: its `k` on a held monster ([FxEngine.foeHeld]: slowed, pinned, stunned or hexed).
  /// - Hot Streak: its `per` more for each stack a kill gave ([Unit.streak], [_relicKill]).
  /// - Avalanche: its `per` more for each other monster within its `reach` tiles of [foe] ([FxEngine.alliesNearOf]), at
  ///   most its `most`.
  /// - Afterglow: its `k` on each hit a skill charged ([Unit.glow], [_relicCast]), one spent.
  /// - Reaper: its `bossK` on a mini boss or the boss under its `below` share of max HP (it never ends one: [_reap]).
  /// Then the relics' cap: this × with the Fury beat's (its [furyHit] on every [furyEvery]th, as [FxEngine._attackK]
  /// makes it) and Giant Slayer's on [foe] ([_slayerK], put on where the blow lands) is at most [Combos.relicMost]; past
  /// it this × comes down, under 1 when those two alone pass it. The Artifacts' own powers stay outside it. Each relic's
  /// counter: the hits it powered and the damage it added before defence, cut down alike under the cap.
  double _relicBlowK(Unit u, Unit foe, double dmg) {
    if (foe.side != Side.enemy) return 1;
    final added = <(Relic, double)>[];
    var k = 1.0;
    void times(Relic r, double f) {
      if (f == 1) return;
      added.add((r, dmg * k * (f - 1)));
      k *= f;
    }

    if (u.holds(Relic.sharkTooth) && foe.effects.isNotEmpty && under(foe, Status.bleed)) times(Relic.sharkTooth, relicK(Relic.sharkTooth, 'k'));
    if (u.holds(Relic.grit) && u.hp < u.maxHp * relicK(Relic.grit, 'below')) times(Relic.grit, relicK(Relic.grit, 'k'));
    if (u.holds(Relic.ambush) && foeHeld(foe)) times(Relic.ambush, relicK(Relic.ambush, 'k'));
    if (u.holds(Relic.hotStreak)) {
      u.streak.removeWhere((end) => t >= end);
      times(Relic.hotStreak, 1 + relicK(Relic.hotStreak, 'per') * u.streak.length);
    }
    if (u.holds(Relic.avalanche)) {
      final near = min(alliesNearOf(foe, relicK(Relic.avalanche, 'reach') * tile), relicK(Relic.avalanche, 'most').round());
      times(Relic.avalanche, 1 + relicK(Relic.avalanche, 'per') * near);
    }
    if (u.glow > 0 && u.holds(Relic.afterglow)) {
      u.glow--;
      times(Relic.afterglow, relicK(Relic.afterglow, 'k'));
    }
    if (u.holds(Relic.reaper) && _bossy(foe) && foe.hp < foe.maxHp * relicK(Relic.reaper, 'below')) {
      times(Relic.reaper, relicK(Relic.reaper, 'bossK'));
    }
    final beat = u.holds(Relic.fury) && u.blows % furyEvery == 0 ? 1 + (furyHit - 1) * _relicK(u) : 1.0;
    final others = beat * _slayerK(u, foe), most = townRules.combos.relicMost, raw = k;
    if (others * k > most) k = most / others;
    final share = raw > 1 ? max(0.0, (k - 1) / (raw - 1)) : 0.0;
    for (final (r, d) in added) {
      _relicTally(r)
        ..uses += 1
        ..worth += d * share;
    }
    return k;
  }

  /// Chill: troop [by]'s normal attack landed on monster [foe]: on every its `every`th ([Unit.chillHits]; a hidden
  /// pairing's fewer, [relicKOf]) [foe] walks its `slow` slower for its `secs` s ([Status.slow]; a mini boss or the
  /// boss its `bossShare` of that); a stronger slow on it stays ([HeroSkills.addEffect]). Its counter: the slows it put.
  void _chill(Unit by, Unit foe) {
    if (++by.chillHits % max(1, relicKOf(by, Relic.chill, 'every').round()) != 0) return;
    final slow = relicK(Relic.chill, 'slow') * (_bossy(foe) ? relicK(Relic.chill, 'bossShare') : 1), was = foe.effects[Status.slow];
    addEffect(foe, Status.slow, relicK(Relic.chill, 'secs'), k: 1 - slow, by: by);
    if (!identical(foe.effects[Status.slow], was)) _relicTally(Relic.chill).uses++;
  }

  /// Weak Spot: troop [by]'s blow, shot or smite landed on monster [foe]: [foe] takes its `taken` (a mini boss or the
  /// boss its `boss`; a hidden pairing's more, [relicKOf]) from every troop for its `secs` s ([Status.vulnerable], the
  /// mark Hunter's Mark puts, so the stronger stays; Void Eye's and Vengeance Mark's are their own and multiply). Its
  /// counter: the marks it put, and the damage they added ([_relicDealt]).
  void _weakSpot(Unit by, Unit foe) {
    final k = _bossy(foe) ? relicKOf(by, Relic.weakSpot, 'boss') : relicKOf(by, Relic.weakSpot, 'taken'), was = foe.effects[Status.vulnerable];
    addEffect(foe, Status.vulnerable, relicK(Relic.weakSpot, 'secs'), k: k, by: by);
    final now = foe.effects[Status.vulnerable];
    if (identical(now, was)) return; // a stronger mark stays
    foe.weakMark = now;
    _relicTally(Relic.weakSpot).uses++;
  }

  /// Reaper ([Game._hurt], after every cut and soak): troop [by]'s normal attack or smite of [dmg] would leave monster
  /// [u] alive under its `below` share of its max HP: it ends [u], the blow taking all [u]'s HP. Never a mini boss or
  /// the boss (their × is in [_relicBlowK]). Its counter: the monsters it ended and the HP it took past the blow.
  double _reap(Unit by, Unit u, double dmg) {
    if (!by.holds(Relic.reaper) || _bossy(u) || u.hp - dmg >= u.maxHp * relicK(Relic.reaper, 'below')) return dmg;
    _relicTally(Relic.reaper)
      ..uses += 1
      ..worth += u.hp - dmg;
    impacts.add((u.pos, _fxOf(by, 'hit_${by.type}'))); // a second hit's burst on it
    return u.hp;
  }

  /// Troop [by] took [dealt] off monster [u] ([Game._hurt]): Weak Spot's counter gets what its mark on [u] added, and
  /// [by]'s pair ([Unit.comboKey]) the damage.
  void _relicDealt(Unit u, Unit by, double dealt) {
    if (dealt <= 0) return;
    if (u.weakMark case final m?) {
      if (identical(u.effects[Status.vulnerable], m) && t < m.until) {
        _relicTally(Relic.weakSpot).worth += dealt * (1 - 1 / m.k);
      } else {
        u.weakMark = null; // ran out, or another mark took its place
      }
    }
    if (by.comboKey case final key?) {
      (relicPairs[key] ??= RelicPair())
        ..ids.add(by.id)
        ..dealt += dealt;
    }
  }

  /// Hot Streak: troop [by] killed a monster ([Game._hurt]): a stack for its `secs` s, at most its `most` (the oldest
  /// gives way to a new one).
  void _relicKill(Unit by) {
    if (!by.holds(Relic.hotStreak)) return;
    final most = relicK(Relic.hotStreak, 'most').round();
    by.streak.removeWhere((end) => t >= end);
    if (most <= 0) return;
    if (by.streak.length >= most) by.streak.remove(by.streak.reduce(min));
    by.streak.add(t + relicK(Relic.hotStreak, 'secs'));
  }

  /// Afterglow: troop [u] cast a skill (a #10 skill, a Hero's, an awakening's): its next `hits` normal attacks are
  /// charged ([Unit.glow], spent in [_relicBlowK]); a new cast charges them anew.
  void _relicCast(Unit u) {
    if (u.holds(Relic.afterglow)) u.glow = relicK(Relic.afterglow, 'hits').round();
  }

  /// At a wave's start ([Game.startWave]): Afterglow's charges and Hot Streak's stacks are gone, the
  /// counters start afresh and each troop's pair key is taken ([comboKeyOf]).
  void _relicWave() {
    relicWorth.clear();
    relicPairs.clear();
    for (final u in troops) {
      u
        ..glow = 0
        ..comboKey = comboKeyOf(u);
      u.streak.clear();
    }
  }

  /// Troop [u]'s pair for the telemetry ([Game.relicPairs]): its relics' keys in [Relic] order joined by "+", then "@"
  /// and its type's Artifact when one is bound ("fury+giantSlayer", "chill@snareCord", "venom+sharkTooth@bleedingEdge");
  /// null when it wields fewer than two of those.
  String? comboKeyOf(Unit u) {
    final held = [...u.relics]..sort((a, b) => a.index.compareTo(b.index));
    final artifact = pusakaOf(u.type);
    if (held.length + (artifact == null ? 0 : 1) < 2) return null;
    return '${held.map((r) => r.name).join('+')}${artifact == null ? '' : '@${artifact.name}'}';
  }
}

/// What the troops wielding one pair ([Relics.comboKeyOf]) did in a wave ([Game.relicPairs], the telemetry's
/// `relicPairs`): which troops dealt damage ([ids], by [Unit.id]) and how much ([dealt]).
class RelicPair {
  final ids = <int>{};
  double dealt = 0;
}
